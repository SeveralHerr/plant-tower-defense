#!/usr/bin/env python3
"""Report HUD Controls whose screen rects overlap each other.

Drives the godot-selftest-harness devtools bus against a *running* game. See
SKILL.md next to this file for why this check is not the same as validate-ui's.

Exit codes follow the harness contract: 0 clean, 1 findings, 2 could not run.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys

# A Control that paints a solid background over whatever is behind it. An
# overlap involving one of these hides the other node rather than merely
# sharing space with it, which is what makes the pair worth reporting.
OPAQUE_TYPES = {
    "Button", "TextureButton", "OptionButton", "MenuButton", "CheckBox",
    "CheckButton", "LinkButton", "Panel", "PanelContainer", "ColorRect",
    "TextureRect", "NinePatchRect", "LineEdit", "TextEdit", "ProgressBar",
}

# Anything a player is meant to read or click. Two of these overlapping is a
# finding even when neither is opaque, because they compete for the same pixels.
CONTENT_TYPES = OPAQUE_TYPES | {"Label", "RichTextLabel"}


def devtools(repo: str, *args: str) -> dict:
    """One bus call. Returns the parsed reply, or raises RuntimeError."""
    proc = subprocess.run(
        [sys.executable, os.path.join("tools", "devtools.py"), "--json", *args],
        capture_output=True, text=True, cwd=repo,
    )
    if not proc.stdout.strip():
        raise RuntimeError(
            "devtools %s produced no output (exit %d): %s"
            % (" ".join(args), proc.returncode, proc.stderr.strip()[:300])
        )
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        raise RuntimeError(
            "devtools %s did not return JSON: %s" % (" ".join(args), proc.stdout[:300])
        )


def walk(node: dict, out: list) -> None:
    out.append(node)
    for child in node.get("children", []):
        walk(child, out)


def find_layer(root: dict, name: str) -> dict | None:
    stack = [root]
    while stack:
        node = stack.pop()
        if node.get("name") == name:
            return node
        stack.extend(node.get("children", []))
    return None


def overlap_area(a: dict, b: dict) -> float:
    w = min(a["x"] + a["w"], b["x"] + b["w"]) - max(a["x"], b["x"])
    h = min(a["y"] + a["h"], b["y"] + b["h"]) - max(a["y"], b["y"])
    return w * h if w > 0 and h > 0 else 0.0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--layer", help="HUD layer node name (default: devtools_config hud_layer_name)")
    ap.add_argument("--repo", default=".", help="project root (default: cwd)")
    ap.add_argument("--min-fraction", type=float, default=0.04,
                    help="ignore overlaps smaller than this share of the smaller rect (default 0.04)")
    ap.add_argument("--json", action="store_true", help="emit findings as JSON")
    args = ap.parse_args()

    repo = os.path.abspath(args.repo)
    layer_name = args.layer
    if not layer_name:
        cfg_path = os.path.join(repo, "addons", "godot_selftest", "devtools_config.json")
        try:
            with open(cfg_path, encoding="utf-8") as fh:
                layer_name = json.load(fh).get("hud_layer_name", "HUD")
        except OSError as exc:
            print("could not run: no --layer and no readable %s (%s)" % (cfg_path, exc), file=sys.stderr)
            return 2

    try:
        tree = devtools(repo, "scene-tree")
    except RuntimeError as exc:
        print("could not run: %s" % exc, file=sys.stderr)
        print("Is the game running? `python tools/devtools.py launch`", file=sys.stderr)
        return 2

    root = tree.get("data", tree)
    layer = find_layer(root, layer_name)
    if layer is None:
        print("could not run: no node named %r in the live tree - pass --layer" % layer_name, file=sys.stderr)
        return 2

    nodes: list = []
    walk(layer, nodes)

    # One node-bounds call per candidate. node-bounds is the only source of
    # *screen* rects with ancestor CanvasLayer transforms applied; a Control's
    # own `position`/`size` are layer-local and will happily agree with each
    # other while the two nodes overlap on screen.
    measured = []
    for node in nodes:
        if node.get("type") not in CONTENT_TYPES:
            continue
        try:
            reply = devtools(repo, "node-bounds", node["path"])
        except RuntimeError as exc:
            print("could not run: %s" % exc, file=sys.stderr)
            return 2
        data = reply.get("data", {})
        if not data.get("visible", False):
            continue
        rect = data.get("global_rect")
        if not rect or rect.get("w", 0) <= 0 or rect.get("h", 0) <= 0:
            continue
        rect = dict(rect)
        painted = False
        # A Label whose text is wider than its box does not grow the box - it
        # paints straight past it. That is the *whole* bug this checker exists
        # for and it is invisible to a rect comparison: the compost counter's
        # rect stopped 156px short of the button it was visibly running under.
        # get_minimum_size().x is the text's own width for a non-wrapping
        # Label, so it is the extent actually on screen.
        if node.get("type") in ("Label", "RichTextLabel"):
            try:
                mreply = devtools(repo, "run-method", "--node", node["path"],
                                  "--method", "get_minimum_size", "--args", "[]")
            except RuntimeError as exc:
                print("could not run: %s" % exc, file=sys.stderr)
                return 2
            mres = mreply.get("data", {}).get("result")
            if isinstance(mres, dict) and float(mres.get("x", 0.0)) > rect["w"]:
                rect["w"] = float(mres["x"])
                painted = True
        measured.append({
            "path": node["path"],
            "type": node["type"],
            "text": (data.get("text") or "").strip(),
            "rect": rect,
            "painted_past_box": painted,
        })

    if not measured:
        print("could not run: no visible sized Controls under %r" % layer_name, file=sys.stderr)
        return 2

    findings = []
    for i, a in enumerate(measured):
        for b in measured[i + 1:]:
            # A child inside its own container is supposed to share pixels.
            if a["path"].startswith(b["path"] + "/") or b["path"].startswith(a["path"] + "/"):
                continue
            area = overlap_area(a["rect"], b["rect"])
            if area <= 0:
                continue
            smaller = min(a["rect"]["w"] * a["rect"]["h"], b["rect"]["w"] * b["rect"]["h"])
            fraction = area / smaller if smaller else 0.0
            if fraction < args.min_fraction:
                continue
            # Only report when something readable or clickable is at stake.
            opaque = a["type"] in OPAQUE_TYPES or b["type"] in OPAQUE_TYPES
            readable = bool(a["text"]) or bool(b["text"])
            if not (opaque and readable):
                continue
            findings.append({
                "a": a["path"], "a_type": a["type"], "a_text": a["text"],
                "b": b["path"], "b_type": b["type"], "b_text": b["text"],
                "overlap_px": round(area, 1),
                "fraction_of_smaller": round(fraction, 3),
                "via_overflow": a["painted_past_box"] or b["painted_past_box"],
            })

    findings.sort(key=lambda f: -f["fraction_of_smaller"])

    if args.json:
        print(json.dumps({"layer": layer_name, "measured": len(measured), "findings": findings}, indent=2))
    else:
        print("hud-occlusion: %d finding(s) across %d visible Control(s) under %r"
              % (len(findings), len(measured), layer_name))
        for f in findings:
            print("  %s %r" % (f["a_type"], f["a_text"] or f["a"]))
            print("    overlaps %s %r by %.0f px (%.0f%% of the smaller)"
                  % (f["b_type"], f["b_text"] or f["b"], f["overlap_px"], f["fraction_of_smaller"] * 100))
            if f["via_overflow"]:
                print("    (the collision is text painted PAST its own box - the rects alone do not touch,")
                print("     so widening the box is not the fix; the layout has to stop them competing)")
            print("    %s\n    %s" % (f["a"], f["b"]))
        if not findings:
            print("Note: a clean run means no two measured Controls overlap *right now*. "
                  "Text that only collides once a counter reaches two digits needs that "
                  "state staged first - see SKILL.md.")

    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
