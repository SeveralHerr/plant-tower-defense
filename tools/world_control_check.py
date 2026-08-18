#!/usr/bin/env python3
"""world_control_check.py - a Control over the playfield deletes clicks, silently.

Why this exists. A `Control` parented to a `Node2D` is a GUI root: its ancestor chain
holds no Control, so it registers with the viewport on `NOTIFICATION_ENTER_CANVAS` and is
picked in *world space* with the parent's transform applied. The viewport's GUI pass runs
before unhandled input. So a `Control` with the default `MOUSE_FILTER_STOP` sitting over
the board calls `set_input_as_handled()` on a hit, and `Game._unhandled_input` never runs.

The click is not misrouted. It is deleted, and nothing anywhere reports it.

That happened here twice before this tool existed. `Plant`'s two health-bar `ColorRect`s
ate clicks on the plant's own cell *and* two pixels of the cell above; `Pest`'s two ate
the click that collects a husk, which is unrecoverable because every husk lands on the
road and `Game._click_at` routes road cells only to `compost.collect_at`. Both shipped
for months. The second time, the defect was even *documented* in a comment beside the fix
for a neighbouring node ("the two bars beside them predate it and are left as they are")
without being fixed.

Nothing in the toolchain can see it:

  * `tools/name_check.py` resolves identifiers. `mouse_filter` resolves; whether it was
    ever assigned is not a name question.
  * `lint_project.gd` and `tools/import_check.py` type-check. A default value is not a
    type error.
  * `tools/coverage_check.py` has a `ui_reachable` class, and `reachable-ui` /
    `findings` do check whether an interactive Control is blocked. But they ask about
    Controls that want clicks and cannot get them. This is the mirror image: a Control
    that does NOT want clicks and takes them anyway, from a Node2D that is not a Control
    at all and so is not in that check's world.
  * the project's own live test enumerates world-space Controls in a running tree, which
    is the right check and catches only what is ON SCREEN while it runs. A Control that
    appears on a boss wave, or in a menu that test never opens, is invisible to it.

So this asks the question statically, over the source, with no engine: does every script
that lives in world space and builds a Control make that Control click-through?

Parallel-safe by construction. It opens no project, writes nothing to `.godot/`, and
takes no lock, so N agents can run it at once on the same checkout - which matters,
because `name_check.py` is otherwise the only gate a fan-out agent gets, and it cannot
see this class of defect at all.

Exit codes follow the house contract: 0 clean, 1 findings, 2 could not run.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

import gdsource
import repo_walk

# Engine classes that place their children in world space. A Control whose nearest
# non-Control ancestor is one of these is a GUI root picked against the world transform.
WORLD_BASES = {
    "Node2D", "Sprite2D", "AnimatedSprite2D", "Area2D", "CharacterBody2D",
    "RigidBody2D", "StaticBody2D", "AnimatableBody2D", "PhysicsBody2D", "CollisionObject2D",
    "Path2D", "PathFollow2D", "TileMap", "TileMapLayer", "CanvasGroup", "Polygon2D",
    "Line2D", "Marker2D", "Camera2D", "ParallaxLayer", "CPUParticles2D", "GPUParticles2D",
}

# Anything deriving from Control. A Control inside a Control is NOT a GUI root of its
# own, and a Control under a CanvasLayer is screen-space, where STOP is usually correct.
CONTROL_BASES = {
    "Control", "ColorRect", "Label", "RichTextLabel", "Panel", "PanelContainer",
    "Button", "TextureButton", "LinkButton", "CheckBox", "CheckButton", "OptionButton",
    "MenuButton", "TextureRect", "NinePatchRect", "ProgressBar", "TextureProgressBar",
    "LineEdit", "TextEdit", "CodeEdit", "ItemList", "Tree", "TabBar", "TabContainer",
    "VBoxContainer", "HBoxContainer", "GridContainer", "MarginContainer",
    "CenterContainer", "PanelContainer", "ScrollContainer", "SplitContainer",
    "AspectRatioContainer", "FlowContainer", "BoxContainer", "Container",
    "ReferenceRect", "VSeparator", "HSeparator", "VSlider", "HSlider", "SpinBox",
}

NEUTRAL_BASES = {"Node", "CanvasItem", "RefCounted", "Object", "Resource"}

CTOR_RE = re.compile(r"\b([A-Z][A-Za-z0-9_]*)\.new\s*\(")
EXTENDS_RE = re.compile(r"^\s*extends\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
CLASSNAME_RE = re.compile(r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
IGNORE_RE = re.compile(r"MOUSE_FILTER_IGNORE")
# A helper that walks find_children and sets the filter for everything it owns. This is
# the fix that survives someone adding a sixth Control without reading the rule.
SWEEP_RE = re.compile(r"find_children\s*\([^)]*[\"']Control[\"']", re.S)


# Comments blanked, string bodies KEPT (gdsource.KEEP), so a rule is never satisfied
# by prose. The project has been bitten by the other version of this: a test that
# scanned source for a token matched the comment explaining why the token was absent.
#
# Bodies are KEPT because SWEEP_RE below matches `find_children(..., "Control", ...)`
# and the class name it needs is a string literal. The local `strip_code` this
# replaces was byte-for-byte the same code as group_leak_check's `strip_comments`, and
# its docstring claimed it removed string bodies. It never has, in any revision --
# which would have made SWEEP_RE match nothing. The doc was wrong, not the code, and
# nothing could say so while the claim and the implementation sat in the same file
# with no test between them. `python tools/gdsource.py` is now that test.


def resolve_space(base: str, declared: dict[str, str], seen: set[str] | None = None) -> str:
    """world / screen / unknown, following project class_names to an engine base."""
    seen = seen or set()
    if base in seen:
        return "unknown"          # a cycle; refuse rather than guess
    seen.add(base)
    if base in WORLD_BASES:
        return "world"
    if base in CONTROL_BASES or base == "CanvasLayer":
        return "screen"
    if base in NEUTRAL_BASES:
        return "unknown"
    if base in declared:
        return resolve_space(declared[base], declared, seen)
    return "unknown"


def gd_files(root: str, ignore: list[str]) -> list[str]:
    found = []
    # This walk is rooted at the REPO ROOT (--root defaults to "."), so it is one
    # of the two in tools/ that a nested .claude/worktrees/ checkout doubles.
    # Measured: 19 world-space script(s) became 38 with one fake lane planted.
    for dirpath, dirnames, filenames in os.walk(root):
        repo_walk.prune(dirpath, dirnames, root)
        for fn in filenames:
            if not fn.endswith(".gd"):
                continue
            path = os.path.join(dirpath, fn)
            rel = os.path.relpath(path, root).replace("\\", "/")
            if any(rel.startswith(p) for p in ignore):
                continue
            found.append(path)
    return found


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="project root (default: cwd)")
    ap.add_argument("--ignore", action="append", default=[],
                    help="path prefix to skip, repeatable")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    root = os.path.abspath(args.root)
    if not os.path.isfile(os.path.join(root, "project.godot")):
        print("world_control_check: no project.godot at %s - cannot run." % root,
              file=sys.stderr)
        return 2

    ignore = args.ignore + ["addons/", "tools/", "test/"]
    paths = gd_files(root, ignore)
    if not paths:
        print("world_control_check: no .gd files under %s - cannot run." % root,
              file=sys.stderr)
        return 2

    sources: dict[str, str] = {}
    declared: dict[str, str] = {}
    for p in paths:
        try:
            with open(p, "r", encoding="utf-8") as fh:
                sources[p] = fh.read()
        except (OSError, UnicodeDecodeError) as exc:
            print("world_control_check: cannot read %s (%s) - cannot run." % (p, exc),
                  file=sys.stderr)
            return 2
        cn = CLASSNAME_RE.search(sources[p])
        ex = EXTENDS_RE.search(sources[p])
        if cn and ex:
            declared[cn.group(1)] = ex.group(1)

    findings = []
    world_scripts = 0
    checked = 0
    for p in sorted(sources):
        code = gdsource.strip_comments(sources[p], gdsource.KEEP)
        ex = EXTENDS_RE.search(code)
        if not ex:
            continue
        if resolve_space(ex.group(1), declared) != "world":
            continue
        world_scripts += 1

        built = sorted({m.group(1) for m in CTOR_RE.finditer(code)} & CONTROL_BASES)
        if not built:
            continue
        checked += 1

        rel = os.path.relpath(p, root).replace("\\", "/")
        if SWEEP_RE.search(code):
            continue
        # No sweep. Then EVERY constructed Control must be individually silenced, and
        # a count is the only honest test available to a regex: one IGNORE for five
        # rects is the half-fixed state this tool exists to refuse.
        ignores = len(IGNORE_RE.findall(code))
        ctors = sum(1 for m in CTOR_RE.finditer(code) if m.group(1) in CONTROL_BASES)
        if ignores < ctors:
            findings.append(
                "%s: extends %s (world space) and builds %d Control(s) [%s] but sets "
                "MOUSE_FILTER_IGNORE only %d time(s). A Control over the playfield is a "
                "GUI root and swallows the click before _unhandled_input runs.\n"
                "    fix: sweep them in one place -- "
                "for c in find_children(\"*\", \"Control\", true, false): "
                "c.mouse_filter = Control.MOUSE_FILTER_IGNORE"
                % (rel, ex.group(1), ctors, ", ".join(built), ignores))

    if not args.quiet:
        print("world_control_check: %d world-space script(s), %d of them build Controls, "
              "%d finding(s)" % (world_scripts, checked, len(findings)))
        if checked == 0:
            # A denominator of zero is the failure mode this house style exists to
            # prevent: it looks exactly like a pass.
            print("  NOTE: nothing to check -- no world-space script builds a Control. "
                  "That is a clean result only if you expected none.")
        print("  NOT COVERED: this reads source, not a running tree. It cannot see a "
              "Control added by a .tscn, nor one whose filter is set through a variable "
              "it cannot follow. Pair it with the live enumeration test.")
    for f in findings:
        print("  FINDING: %s" % f)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
