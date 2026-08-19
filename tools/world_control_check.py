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

    fixture:   `python tools/world_control_check.py --fixture`. KEPT, not written and
               deleted -- the mutations below are what you re-run after every edit to
               this file, and they need something to run against. Nine synthetic
               scripts over a temp project, driven through the real main(): two
               Controls and no IGNORE (the case that proves this can FAIL) / two with
               one IGNORE (the half-fixed state) / an IGNORE that exists only in a
               COMMENT / a world base reached through a project class_name / the sweep
               helper / two silenced one at a time / a CanvasLayer (screen space, must
               not enter the denominator at all) / world space with no Controls.
               Baseline (8, 6, 4, exit 1) -- BOTH denominators are asserted, and each
               file is asserted by NAME. The counts alone can be right for the wrong
               reasons: four findings is also what you get if the sweep rule breaks and
               comment stripping breaks together.
    mutations: 5, all RED, restore clean. Measured 2026-08-18; baseline 0 failure(s).
               Read the FINDING COUNT, not the exit code -- four of the five below
               leave the exit code at 1 while changing what the tool found.
               `strip_comments(src, KEEP)` -> `src`
                                                -> 2 failures. bad_comment_only.gd goes
                                                   clean, findings 4 -> 3, EXIT STILL 1
               `if SWEEP_RE.search(code)` ->
                 `if False and ...`             -> 2 failures. good_sweep.gd fires,
                                                   findings 4 -> 5, EXIT STILL 1
               `ignores < ctors` -> `ignores < 1`
                                                -> 2 failures. bad_half.gd goes clean --
                                                   one IGNORE silences five rects, the
                                                   half-fixed state this refuses.
                                                   findings 4 -> 3, EXIT STILL 1
               drop resolve_space's `if base in declared`
                 recursion                      -> 4 failures, and the only mutation
                                                   that moves the DENOMINATORS: 8 -> 7
                                                   world scripts, 6 -> 5 building
                                                   Controls, findings 4 -> 3
               `KEEP` -> `BLANK` in strip_comments
                                                -> 2 failures. String bodies vanish, so
                                                   SWEEP_RE's `"Control"` argument stops
                                                   matching and good_sweep.gd fires.
                                                   This is why KEEP is load-bearing and
                                                   not a copy-paste from another checker
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


# ---------------------------------------------------------------------------
# The synthetic fixture. This tool shipped without one for its whole life, which made
# the three rules that can REMOVE a finding -- the sweep escape hatch, the per-node
# IGNORE count, and comment stripping -- the least guarded things in the file. All
# three fail quiet: the finding leaves the list and the exit code follows it down to
# 0, so a broken rule and a clean repo print the same thing.
#
# Driven through the real main() over a temp project rather than by poking the regexes,
# so deleting a call site fails here even with the pattern intact.
#
# KEPT rather than written-and-deleted: the mutations in the module docstring are what
# you re-run after every edit to this file, and they need something to re-run against.
FIXTURE_FILES = {
    # extends a world base, builds two Controls, silences neither. THE case that
    # proves this checker can fail.
    "game/bad_bare.gd": '''extends Node2D


func _ready() -> void:
\tvar bar := ColorRect.new()
\tvar fill := ColorRect.new()
\tadd_child(bar)
\tadd_child(fill)
''',
    # The half-fixed state: one of two silenced. A count is the only honest test a
    # regex has here, and this is the case that needs it.
    "game/bad_half.gd": '''extends Node2D


func _ready() -> void:
\tvar bar := ColorRect.new()
\tbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
\tvar fill := ColorRect.new()
\tadd_child(bar)
\tadd_child(fill)
''',
    # MOUSE_FILTER_IGNORE appears ONCE and only inside a comment. If comment
    # stripping stops working this file goes clean, which is the exact way a text
    # scan produces a confident finding about nothing -- in reverse.
    "game/bad_comment_only.gd": '''extends Node2D


func _ready() -> void:
\t# TODO: set mouse_filter = Control.MOUSE_FILTER_IGNORE on this one
\tvar bar := ColorRect.new()
\tadd_child(bar)
''',
    # Reaches a world base through a project class_name, two hops from the engine.
    "game/fixture_base.gd": '''class_name FixtureWorldBase
extends Node2D


func _ready() -> void:
\tpass
''',
    "game/bad_derived.gd": '''extends FixtureWorldBase


func _ready() -> void:
\tvar label := Label.new()
\tadd_child(label)
''',
    # The sweep: one helper that owns every Control this node will ever have.
    "game/good_sweep.gd": '''extends Node2D


func _ready() -> void:
\tvar bar := ColorRect.new()
\tvar fill := ColorRect.new()
\tadd_child(bar)
\tadd_child(fill)
\tfor c in find_children("*", "Control", true, false):
\t\tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
''',
    # Silenced one at a time, and the count matches.
    "game/good_each.gd": '''extends Node2D


func _ready() -> void:
\tvar bar := ColorRect.new()
\tbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
\tvar fill := ColorRect.new()
\tfill.mouse_filter = Control.MOUSE_FILTER_IGNORE
\tadd_child(bar)
\tadd_child(fill)
''',
    # Screen space. A Control under a CanvasLayer is where STOP is usually correct,
    # so this must not even enter the world-space denominator.
    "game/good_screen.gd": '''extends CanvasLayer


func _ready() -> void:
\tvar panel := Panel.new()
\tadd_child(panel)
''',
    # World space, no Controls. Counted in world_scripts, not in checked -- the pair
    # of denominators is what says whether the second number is small because the
    # repo is clean or because the first rule stopped matching.
    "game/no_controls.gd": '''extends Node2D


func _ready() -> void:
\tvar spr := Sprite2D.new()
\tadd_child(spr)
''',
}

# (world_scripts, scripts building Controls, findings, exit code)
FIXTURE_EXPECT = (8, 6, 4, 1)

# Which files must be named in the output, and which must not. The three counts above
# can all be right for the wrong reasons: four findings is also what you get if the
# sweep rule breaks and comment stripping breaks at the same time.
FIXTURE_FIRES = {
    "game/bad_bare.gd": True,
    "game/bad_half.gd": True,
    "game/bad_comment_only.gd": True,
    "game/bad_derived.gd": True,
    "game/good_sweep.gd": False,
    "game/good_each.gd": False,
    "game/good_screen.gd": False,
    "game/no_controls.gd": False,
    "game/fixture_base.gd": False,
}


def run_fixture() -> int:
    """Return the failure count. Prints what it compared, never just a verdict."""
    import io
    import shutil
    import tempfile

    root = tempfile.mkdtemp(prefix="world_control_fixture_")
    fails = 0
    try:
        with open(os.path.join(root, "project.godot"), "w", encoding="utf-8") as fh:
            fh.write("config_version=5\n")
        for rel, body in FIXTURE_FILES.items():
            path = os.path.join(root, *rel.split("/"))
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8", newline="") as fh:
                fh.write(body)

        old_argv, old_stdout = sys.argv, sys.stdout
        sys.argv = ["world_control_check.py", "--root", root]
        sys.stdout = io.StringIO()
        try:
            code = main()
            out = sys.stdout.getvalue()
        finally:
            sys.argv, sys.stdout = old_argv, old_stdout

        m = re.search(r"(\d+) world-space script\(s\), (\d+) of them build Controls, "
                      r"(\d+) finding\(s\)", out)
        got = (int(m.group(1)), int(m.group(2)), int(m.group(3)), code) if m \
            else (-1, -1, out.count("  FINDING: "), code)
        labels = ("world-space scripts", "of them build Controls", "finding(s)",
                  "exit code")
        for label, g, w in zip(labels, got, FIXTURE_EXPECT):
            ok = g == w
            if not ok:
                fails += 1
            print("  %-6s %-24s %s (want %s)" % ("ok" if ok else "FAIL", label, g, w))

        for rel, should_fire in FIXTURE_FIRES.items():
            fired = ("%s:" % rel) in out
            ok = fired == should_fire
            if not ok:
                fails += 1
            print("  %-6s %-28s fired=%s (want %s)"
                  % ("ok" if ok else "FAIL", rel, fired, should_fire))
    finally:
        shutil.rmtree(root, ignore_errors=True)

    print("world_control_check fixture: %d synthetic script(s), %d failure(s). Both "
          "denominators are asserted, not just the finding count: a rule that stops "
          "matching world-space scripts at all reports `0 world-space script(s) ... 0 "
          "finding(s)`, which exits 0 and reads as a clean repo. That is the failure "
          "this pair of numbers exists to catch."
          % (len(FIXTURE_FILES), fails))
    print("  NOT COVERED: the fixture exercises the space resolver, the sweep escape "
          "hatch, the IGNORE count and comment stripping over nine hand-written "
          "scripts. It says nothing about this repo's real scripts, and a clean "
          "fixture is a statement about the rules, not about the corpus. It also does "
          "not cover .tscn-authored Controls, which this tool cannot see at all.")
    return fails


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="project root (default: cwd)")
    ap.add_argument("--ignore", action="append", default=[],
                    help="path prefix to skip, repeatable")
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--fixture", action="store_true",
                    help="run the synthetic fixture and exit; proves this checker can "
                         "FAIL, and that the sweep, the IGNORE count and comment "
                         "stripping each still remove exactly what they should")
    args = ap.parse_args()

    if args.fixture:
        return 2 if run_fixture() else 0

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
