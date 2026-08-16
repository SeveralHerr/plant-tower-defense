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

# Findings quote the node's own text, and UI text is not ASCII - a "< Prev"
# button becomes "‹ Prev" the moment anyone styles it. On Windows the default
# stdout encoding is cp1252, which raises UnicodeEncodeError *while printing a
# finding*: the check does its job, then dies on the way out with a traceback
# and a non-zero exit that looks like a crash rather than a result.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

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

# Godot's HorizontalAlignment enum, used to work out where a Label's glyphs sit
# inside a box that is usually much wider than they are.
ALIGN_LEFT, ALIGN_CENTER, ALIGN_RIGHT, ALIGN_FILL = 0, 1, 2, 3


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


def encloses(outer: dict, inner: dict) -> bool:
    """True when `outer` fully contains `inner`, edges touching allowed."""
    return (
        outer["x"] <= inner["x"]
        and outer["y"] <= inner["y"]
        and outer["x"] + outer["w"] >= inner["x"] + inner["w"]
        and outer["y"] + outer["h"] >= inner["y"] + inner["h"]
    )


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
                sreply = devtools(repo, "get-state", "--node", node["path"],
                                  "--property", "horizontal_alignment",
                                  "--property", "autowrap_mode")
            except RuntimeError as exc:
                print("could not run: %s" % exc, file=sys.stderr)
                return 2
            mres = mreply.get("data", {}).get("result")
            text_w = float(mres.get("x", 0.0)) if isinstance(mres, dict) else 0.0
            props = sreply.get("data", {}).get("properties", sreply.get("data", {}))
            align = int(props.get("horizontal_alignment", 0) or 0)
            wraps = int(props.get("autowrap_mode", 0) or 0) != 0
            if text_w > rect["w"]:
                rect["w"] = text_w
                painted = True
            elif text_w > 0 and not wraps and align != ALIGN_FILL:
                # Narrow the rect to where the glyphs actually are.
                #
                # A centred full-width Label is the standard way to put a
                # heading across a screen, and its *box* then overlaps every
                # button parked in the left or right margin while its text
                # comes nowhere near them. Reporting the box is reporting a
                # collision that does not exist on screen - and occlusion is a
                # question about pixels, so measure the pixels.
                #
                # Only when the Label does not wrap: get_minimum_size().x on an
                # autowrapping Label is the width of its longest *word*, not of
                # the paragraph, and narrowing to that would hide real overlaps.
                if align == ALIGN_CENTER:
                    rect["x"] += (rect["w"] - text_w) / 2.0
                elif align == ALIGN_RIGHT:
                    rect["x"] += rect["w"] - text_w
                rect["w"] = text_w
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
            # Draw order decides which of the pair is the victim.
            #
            # `measured` is built by a pre-order walk, and that *is* Godot's
            # draw order for a Control tree: a CanvasItem paints itself, then
            # its children in child order. So `b` is on top of `a`, always,
            # and only `b` can hide anything.
            #
            # Without this the check reports every full-screen backdrop against
            # every label in front of it. A dim ColorRect sibling drawn first is
            # the normal way to build an overlay, and it produced one finding
            # per readable node on this project's notebook screen - thirteen of
            # them, all false, which is more than enough noise to bury a real
            # one. An opaque node that is *behind* the text is not occluding it.
            #
            # (Assumes no z_index/top_level reordering under the layer. Those
            # exist; nothing in this project's UI uses them, and a node that
            # does will simply not be reported rather than reported wrongly.)
            if b["type"] not in OPAQUE_TYPES:
                continue
            # ...and something has to be underneath worth seeing.
            if not (a["text"] or a["type"] in OPAQUE_TYPES):
                continue
            # A textless rect that fully contains the node on top of it is a
            # background, and a background is never the victim. Overlay dims,
            # panels, mattes and photo frames are all built exactly this way -
            # a full-rect ColorRect drawn first with the content laid on top -
            # so without this every single readable node reports against the
            # backdrop it is deliberately sitting on. On this project's notebook
            # that was six of nine findings; on any screen with a dim layer it
            # is O(n) noise hiding the one finding that matters.
            if not a["text"] and encloses(a["rect"], b["rect"]):
                continue
            # `a` is the covered node and `b` the one drawn over it. The key
            # names predate the draw-order rule and are kept so existing
            # --json consumers do not break.
            findings.append({
                "a": a["path"], "a_type": a["type"], "a_text": a["text"],
                "b": b["path"], "b_type": b["type"], "b_text": b["text"],
                "covered": a["path"], "covered_by": b["path"],
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
            print("  %s %r" % (f["b_type"], f["b_text"] or f["b"]))
            print("    is drawn over %s %r, hiding %.0f px (%.0f%% of the smaller)"
                  % (f["a_type"], f["a_text"] or f["a"], f["overlap_px"], f["fraction_of_smaller"] * 100))
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
