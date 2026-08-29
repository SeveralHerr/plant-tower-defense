#!/usr/bin/env python3
r"""board_check.py - every road in the corpus is playable before anyone plays it.

WHY THIS EXISTS (plant-tower-defense-s1o8.2), and what it would have caught already.

`Board.set_road()` (game/board.gd) makes the pests' route a parameter instead of a
single hardcoded `PATH_CORNERS`. Nothing about a legal *route* -- axis-aligned,
in-bounds, non-degenerate segments, which is all `set_road()` itself checks -- says
anything about whether that route is a *playable board*. Three properties of
game/board.gd fail INVISIBLY for a route `set_road()` accepts without complaint,
exactly the class of defect this repo writes a `tools/*.py` checker for rather than
a runtime assertion, because every one of the three is a property of DATA the engine
never has to execute to know is wrong:

  * Board.GRASS_EDGE_TILE (game/board.gd:172) maps a 4-bit neighbour mask to a kit
    tile, and covers only single-side and adjacent-two-side dirt -- its own comment
    says the kit ships no tile for opposite-side or three-side dirt, so those masks
    fall back to plain grass with NOTHING erroring. A road that leaves a one-cell-
    wide grass band between two road rows (or columns) produces exactly those masks.
    This checker FOUND ONE: the s1o8.1 "long serpentine" road shipped with its five
    full-width rows two apart, which leaves a one-row band with dirt above AND below
    it (mask 0b0101, "opposite sides") -- see test/unit/test_board.gd's ROAD_LONG
    for the fix (rows three apart instead of two) and its own header for the story.
  * a road that eats too much of the 14x9 / 94-cell field leaves too few plantable
    cells for a garden to mean anything.
  * a road can seal off a pocket of grass between itself and the board's own edge --
    and a pocket small enough to matter is, by construction, surrounded by road on
    3 of its 4 sides for at least one of its cells, which is the SAME missing-mask
    condition above wearing a different name. See `MIN_POCKET_SIZE` below.

WHAT THIS DOES vs test/unit/test_board.gd. The GDScript suite asks whether each
corpus road is INTERNALLY consistent -- does the walker agree with the arithmetic,
does dead ground match the geometry, is there a playable placement for every
reaching plant. None of that requires running Godot; it is arithmetic over the same
corners `Board.set_road()` takes. This tool re-derives Board's own connectivity and
tiling rules in stdlib Python against the SAME corpus data (parsed out of the real
`.gd` source below, never a hand-copied second list) and is therefore runnable with
no engine, in parallel, in a fan-out where only `name_check.py` would otherwise run.

Nothing else in the toolchain can see any of this:
  * `name_check.py` resolves identifiers; a `Vector2i` literal that produces a bad
    mask is perfectly valid GDScript.
  * `lint_project.gd` / the suite compile and run the code; the road's SHAPE is data,
    not a type error, and the fallback-to-grass branch of `_texture_for` never fails
    an assertion -- it just draws the wrong tile.
  * a reader of `board.gd`: this repo has already shipped the exact defect class in
    the corpus once (see ROAD_LONG above), from a human reading the shape and not
    noticing a one-cell gap.

Parallel-safe by construction: opens no project, writes nothing to `.godot/`, takes
no lock, imports nothing but stdlib and `gdsource` (also stdlib-only). Exit codes
follow the house contract: 0 clean, 1 findings, 2 could not run.

    fixture:   `--self-test` builds small synthetic corpora in memory (never files
               on disk) and confirms each of the five rules fires on exactly the
               road built to trip it, and that a clean road trips none of them.
               See `SELF_TEST_CASES` below.
    mutations: 5, run by monkeypatching `analyze_road`/`build_path` in a throwaway
               script (there is no tools/mutate.py entry for this tool yet) and
               re-running `self_test()`. All RED, each naming exactly the case
               built for the disabled rule, restore clean:
                 drop the "connected" finding -> "closed loop" case: fired []
                 drop the "edge" finding      -> "interior" case: fired []
                 drop the "mask" finding      -> "1-cell band" case: fired []
                 drop the "pocket" finding    -> "sealed bridge" case: fired
                   ['mask'] only (this fixture co-fires mask -- see its own case
                   comment; the assertion is membership, not exclusivity, so the
                   mutation is still caught by the missing 'pocket')
                 drop the "floor" finding     -> "dense comb" case: fired []
    denominator: prints how many roads were parsed out of the corpus and how many
               of the five rules were evaluated per road; a corpus that failed to
               parse at all (a renamed function, a moved file) is a REFUSAL (exit 2),
               never a silent zero-road pass.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gdsource  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOARD_GD = os.path.join(ROOT, "game", "board.gd")
TEST_BOARD_GD = os.path.join(ROOT, "test", "unit", "test_board.gd")

# The dirt<->grass fallback this whole tool exists to catch: a pocket of grass small
# enough that at least one of its cells is very likely to touch road on 3 (or all 4)
# sides is also small enough that no player would call it a usable bed. 4 is the
# smallest size a 2-cell-wide trapped strip can be (see game/board.gd's own
# ROAD_LONG-fix story in the module docstring above): a 1- or 2-cell pocket is
# guaranteed to produce an opposite-side or three-side mask GRASS_EDGE_TILE does not
# ship; a 3-cell pocket usually does too. Below this, refuse; at or above it, the
# separate neighbour-mask check is what actually decides whether the shape rendered.
MIN_POCKET_SIZE = 4

# Roughly half the 126-cell (14x9) field must stay buildable. The corpus today
# ranges 80..112 plantable cells; this is a floor far below that, not a target --
# see the bead: "a road that eats too much of the field leaves too few plantable
# cells", not "the field must look like today's roads".
MIN_PLANTABLE = 60


# ---------------------------------------------------------------------------
# Board's own rules, re-derived (never re-implemented by import -- this tool must
# work with no engine present).

def sign(v: int) -> int:
    return (v > 0) - (v < 0)


def validate_structure(cols, rows, corners):
    """Mirror of Board.set_road()'s own refusals. Returns "" or the reason."""
    if len(corners) < 2:
        return "a road needs at least two corners"
    for i, at in enumerate(corners):
        if not (0 <= at[0] < cols and 0 <= at[1] < rows):
            return "corner %d %s is off a %dx%d board" % (i, at, cols, rows)
    for i in range(len(corners) - 1):
        fr, to = corners[i], corners[i + 1]
        if fr == to:
            return "corners %d and %d are the same cell %s" % (i, i + 1, fr)
        if fr[0] != to[0] and fr[1] != to[1]:
            return "segment %d %s -> %s is diagonal; the walker would never arrive" % (
                i, fr, to)
    return ""


def build_path(corners):
    """Mirror of Board._build_path()/_add_path_cell(): walk each segment one cell at
    a time, skipping a cell already visited (Board does the same -- see
    Board.road_cell_count's own docstring on what a self-crossing road does to the
    two counts disagreeing). Returns (cells_in_walk_order, formula_cell_count)."""
    cells = []
    seen = set()
    for i in range(len(corners) - 1):
        fr, to = corners[i], corners[i + 1]
        step = (sign(to[0] - fr[0]), sign(to[1] - fr[1]))
        at = fr
        while at != to:
            if at not in seen:
                seen.add(at)
                cells.append(at)
            at = (at[0] + step[0], at[1] + step[1])
    last = corners[-1]
    if last not in seen:
        seen.add(last)
        cells.append(last)
    steps = sum(abs(b[0] - a[0]) + abs(b[1] - a[1]) for a, b in zip(corners, corners[1:]))
    return cells, steps + 1


def neighbour_masks(cols, rows, road_cells):
    """Mirror of Board._texture_for()'s mask math for every grass cell the road
    borders. bit0=up bit1=right bit2=down bit3=left, matching game/board.gd exactly."""
    road_set = set(road_cells)
    masks = set()
    for y in range(rows):
        for x in range(cols):
            if (x, y) in road_set:
                continue
            mask = 0
            if (x, y - 1) in road_set:
                mask |= 0b0001
            if (x + 1, y) in road_set:
                mask |= 0b0010
            if (x, y + 1) in road_set:
                mask |= 0b0100
            if (x - 1, y) in road_set:
                mask |= 0b1000
            masks.add(mask)
    return masks


def plantable_components(cols, rows, road_cells):
    """4-connected components of every buildable (non-road) cell."""
    road_set = set(road_cells)
    buildable = set((x, y) for y in range(rows) for x in range(cols) if (x, y) not in road_set)
    seen = set()
    comps = []
    for start in buildable:
        if start in seen:
            continue
        stack, comp = [start], set()
        while stack:
            c = stack.pop()
            if c in comp:
                continue
            comp.add(c)
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (c[0] + d[0], c[1] + d[1])
                if n in buildable and n not in comp:
                    stack.append(n)
        seen |= comp
        comps.append(comp)
    return comps


# ---------------------------------------------------------------------------
# One road, all five rules.

def analyze_road(name, corners, cols, rows, mask_set, min_plantable, min_pocket):
    """[(rule, message)] for every finding against one road. Empty means clean."""
    findings = []

    reason = validate_structure(cols, rows, corners)
    if reason:
        # A road that fails structural validation cannot be walked at all -- every
        # other rule below assumes a legal path, so report this alone and stop.
        return [("structure", "%s: not a legal road -- %s" % (name, reason))]

    cells, formula = build_path(corners)

    if len(cells) != formula:
        findings.append(("connected",
            "%s: not a single simple path -- the walk visits %d distinct cell(s) but "
            "its corners imply %d; the road crosses or doubles back on itself"
            % (name, len(cells), formula)))

    entry, exit_ = corners[0], corners[-1]
    for label, cell in (("entry", entry), ("exit", exit_)):
        on_edge = cell[0] in (0, cols - 1) or cell[1] in (0, rows - 1)
        if not on_edge:
            findings.append(("edge",
                "%s: %s %s is not on a board edge (x in {0,%d} or y in {0,%d})"
                % (name, label, cell, cols - 1, rows - 1)))

    masks = neighbour_masks(cols, rows, cells)
    missing = sorted(masks - mask_set)
    if missing:
        findings.append(("mask",
            "%s: produces neighbour mask(s) %s with no entry in GRASS_EDGE_TILE -- "
            "those grass cells render as plain grass, not an edged transition"
            % (name, [format(m, "#06b") for m in missing])))

    plantable = cols * rows - len(cells)
    if plantable < min_plantable:
        findings.append(("floor",
            "%s: only %d of %d cells stay buildable (floor is %d)"
            % (name, plantable, cols * rows, min_plantable)))

    comps = plantable_components(cols, rows, cells)
    small = sorted(len(c) for c in comps if len(c) < min_pocket)
    if small:
        findings.append(("pocket",
            "%s: %d isolated plantable pocket(s) below the %d-cell floor, sized %s"
            % (name, len(small), min_pocket, small)))

    return findings


def analyze_corpus(roads, cols, rows, mask_set, min_plantable=MIN_PLANTABLE,
                    min_pocket=MIN_POCKET_SIZE):
    """(findings, per_road) over every road. `roads` is [(name, corners), ...]."""
    findings = []
    per_road = {}
    for name, corners in roads:
        road_findings = analyze_road(name, corners, cols, rows, mask_set,
                                      min_plantable, min_pocket)
        per_road[name] = road_findings
        findings.extend(road_findings)
    return findings, per_road


# ---------------------------------------------------------------------------
# Parsing the real corpus out of the real .gd source. No hand-copied second list:
# `test_board.gd`'s own `_road_corpus()` function is what test/unit/test_board.gd
# actually sweeps, so this reads THAT function rather than every `const ROAD_*` in
# the file -- a constant defined but never added to `_road_corpus()` is not part of
# the corpus the suite tests, and must not be part of the corpus this validates.

VECTOR2I = re.compile(r"Vector2i\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)")
CONST_ARRAY = re.compile(
    r"const\s+(\w+)\s*:\s*Array\[Vector2i\]\s*=\s*\[(.*?)\]", re.DOTALL)
CONST_INT = re.compile(r"const\s+(\w+)\s*:\s*int\s*=\s*(\d+)")
GRASS_EDGE_TILE_BLOCK = re.compile(
    r"const\s+GRASS_EDGE_TILE\s*:\s*Dictionary\s*=\s*\{(.*?)\n\}", re.DOTALL)
GRASS_EDGE_TILE_KEY = re.compile(r"(0b[01]+)\s*:")
ROAD_CORPUS_FUNC = re.compile(
    r"func\s+_road_corpus\s*\(\s*\)\s*->\s*Array\s*:(.*?)(?=\nfunc\s|\Z)", re.DOTALL)
CORPUS_ENTRY = re.compile(r'\{\s*"name"\s*:\s*"([^"]*)"\s*,\s*"corners"\s*:\s*([\w.]+)\s*\}')


def _read(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def parse_int_consts(text):
    code = gdsource.strip_comments(text, gdsource.KEEP)
    return {m.group(1): int(m.group(2)) for m in CONST_INT.finditer(code)}


def parse_vector_array_consts(text):
    """{const_name: [(x, y), ...]}, including an EMPTY list for `const X: Array[Vector2i]
    = []` (the ROAD_DEFAULT sentinel in test_board.gd)."""
    code = gdsource.strip_comments(text, gdsource.KEEP)
    out = {}
    for m in CONST_ARRAY.finditer(code):
        body = m.group(2)
        out[m.group(1)] = [(int(a), int(b)) for a, b in VECTOR2I.findall(body)]
    return out


def parse_grass_edge_tile_masks(text):
    code = gdsource.strip_comments(text, gdsource.KEEP)
    m = GRASS_EDGE_TILE_BLOCK.search(code)
    if not m:
        return None
    return {int(k, 2) for k in GRASS_EDGE_TILE_KEY.findall(m.group(1))}


def parse_road_corpus(board_text, test_text):
    """[(name, corners)] exactly as test_board.gd's `_road_corpus()` builds it.

    Resolves each entry's "corners" token against the constants declared in BOTH
    files -- `Board.PATH_CORNERS` lives in board.gd, every `ROAD_*` lives in
    test_board.gd. A token that resolves to neither is a parse failure (refusal,
    not a skipped road): a corpus this tool silently drops one road from is worse
    than one that refuses to run at all.
    """
    consts = {}
    consts.update(parse_vector_array_consts(board_text))
    for name, corners in parse_vector_array_consts(test_text).items():
        consts[name] = corners
    # `Board.PATH_CORNERS` is qualified in the source; also index it bare.
    if "PATH_CORNERS" in consts:
        consts["Board.PATH_CORNERS"] = consts["PATH_CORNERS"]

    code = gdsource.strip_comments(test_text, gdsource.KEEP)
    func_match = ROAD_CORPUS_FUNC.search(code)
    if not func_match:
        raise LookupError("could not find func _road_corpus() -> Array: in %s" % TEST_BOARD_GD)
    body = func_match.group(1)

    roads = []
    for entry in CORPUS_ENTRY.finditer(body):
        display_name, token = entry.group(1), entry.group(2)
        # `ROAD_DEFAULT` resolves to an empty list in test_board.gd itself, meaning
        # "use Board.PATH_CORNERS" -- Board.road_corners()'s own contract. Mirror it
        # rather than special-case "default" by NAME, so a renamed entry still works.
        corners = consts.get(token)
        if corners is None:
            raise LookupError(
                "_road_corpus() names corners token %r, which is not a const Array["
                "Vector2i] in game/board.gd or test/unit/test_board.gd" % token)
        if not corners and token != "Board.PATH_CORNERS":
            corners = consts.get("Board.PATH_CORNERS", corners)
        roads.append((display_name, corners))
    if not roads:
        raise LookupError(
            "_road_corpus() parsed with 0 entries -- the {\"name\": ..., \"corners\": "
            "...} pattern found nothing in its body")
    return roads


def load_real_corpus():
    board_text = _read(BOARD_GD)
    test_text = _read(TEST_BOARD_GD)
    ints = parse_int_consts(board_text)
    for needed in ("COLS", "ROWS"):
        if needed not in ints:
            raise LookupError("could not find const %s: int = ... in %s" % (needed, BOARD_GD))
    mask_set = parse_grass_edge_tile_masks(board_text)
    if mask_set is None:
        raise LookupError("could not find const GRASS_EDGE_TILE: Dictionary = ... in %s"
                           % BOARD_GD)
    roads = parse_road_corpus(board_text, test_text)
    return roads, ints["COLS"], ints["ROWS"], mask_set


# ---------------------------------------------------------------------------
# --self-test: synthetic corpora, never files on disk. One road per rule, built to
# trip exactly that rule and no other where it can be helped (see the skill's own
# warning about a fixture that co-fires two rules and hides one of them).

def _self_test_masks():
    # The real house set, so the mask-coverage case demonstrates the actual rule
    # rather than an easier toy one: single-side and adjacent-two-side dirt only.
    return {0b0000, 0b0001, 0b0010, 0b0100, 0b1000, 0b0011, 0b0110, 0b1100, 0b1001}


# (case name, expected rule, corners) on an 8x6 board (cols=8, rows=6).
SELF_TEST_CASES = [
    ("clean straight road", None,
     [(0, 2), (7, 2)]),

    ("closed loop revisits its own start", "connected",
     [(0, 0), (3, 0), (3, 3), (0, 3), (0, 0)]),

    ("both ends land in the interior", "edge",
     [(2, 2), (5, 2)]),

    ("two full-width rows one apart trap a 1-cell grass band", "mask",
     [(0, 0), (7, 0), (7, 2), (0, 2), (0, 4), (7, 4)]),

    ("a bridge sealed against the board's own bottom edge", "pocket",
     [(0, 5), (2, 5), (2, 2), (4, 2), (4, 5), (7, 5)]),
]

# A road built specifically to breach a tight plantable floor -- the floor is a
# PARAMETER (unlike the other four rules), so this case is checked with its own
# call rather than folded into SELF_TEST_CASES, which all share one floor of 0.
FLOOR_CASE = ("a dense comb eats nearly the whole board", "floor",
              [(0, 0), (7, 0), (7, 1), (0, 1), (0, 2), (7, 2), (7, 3), (0, 3),
               (0, 4), (7, 4)])


def self_test(verbose=True):
    """Return the number of failures. Every case names the ONE rule it exists to
    trip; a GOOD case must trip nothing, and each BAD case must trip its own rule
    -- not merely raise the finding count, per the house skill's warning that a
    count alone cannot tell a silently-skipped rule from a working one."""
    fails = 0
    cols, rows = 8, 6
    mask_set = _self_test_masks()

    def say(line):
        if verbose:
            print(line)

    say("board_check --self-test: %dx%d synthetic board, house GRASS_EDGE_TILE mask set"
        % (cols, rows))

    for label, expected_rule, corners in SELF_TEST_CASES:
        findings = analyze_road(label, corners, cols, rows, mask_set,
                                 min_plantable=0, min_pocket=MIN_POCKET_SIZE)
        rules_fired = {rule for rule, _ in findings}
        if expected_rule is None:
            ok = not findings
            (print if not ok else say)(
                "  %-4s %-45s expected clean, got %s"
                % ("ok" if ok else "FAIL", label, sorted(rules_fired) or "[]"))
        else:
            ok = expected_rule in rules_fired
            (print if not ok else say)(
                "  %-4s %-45s expected '%s', fired %s"
                % ("ok" if ok else "FAIL", label, expected_rule, sorted(rules_fired)))
            if not ok:
                for rule, msg in findings:
                    print("         %s: %s" % (rule, msg))
        if not ok:
            fails += 1

    label, expected_rule, corners = FLOOR_CASE
    findings = analyze_road(label, corners, cols, rows, mask_set,
                             min_plantable=20, min_pocket=MIN_POCKET_SIZE)
    rules_fired = {rule for rule, _ in findings}
    ok = expected_rule in rules_fired
    (print if not ok else say)(
        "  %-4s %-45s expected '%s' (min_plantable=20), fired %s"
        % ("ok" if ok else "FAIL", label, expected_rule, sorted(rules_fired)))
    if not ok:
        fails += 1

    total_cases = len(SELF_TEST_CASES) + 1
    print("")
    print("board_check --self-test: %d case(s), %d failure(s)" % (total_cases, fails))
    if total_cases == 0:
        print("NOTE: nothing to check -- SELF_TEST_CASES is empty. An empty self-test "
              "is not a clean self-test.")
    return fails


# ---------------------------------------------------------------------------

def run_real(verbose=True):
    """Return (exit_code, findings, per_road) over the real corpus, or (2, [], {})
    on a parse failure -- a road this tool cannot find is a refusal, not a pass."""
    try:
        roads, cols, rows, mask_set = load_real_corpus()
    except (OSError, LookupError) as exc:
        print("REFUSAL: could not load the real road corpus -- %s" % exc)
        return 2, [], {}

    findings, per_road = analyze_corpus(roads, cols, rows, mask_set)

    rule_names = ("structure", "connected", "edge", "mask", "floor", "pocket")
    by_rule = {r: 0 for r in rule_names}
    for rule, _ in findings:
        by_rule[rule] = by_rule.get(rule, 0) + 1

    for name, corners in roads:
        road_findings = per_road[name]
        status = "clean" if not road_findings else "%d finding(s)" % len(road_findings)
        if verbose:
            print("  %-20s %3d corner(s)  %s" % (name, len(corners), status))
        for rule, msg in road_findings:
            print("    FINDING [%s] %s" % (rule, msg))
            if rule == "structure":
                print("      fix: correct the corner list so set_road() would accept it "
                      "(see game/board.gd's set_road() header for the four refusals)")
            elif rule == "connected":
                print("      fix: reshape the corners so the walk never revisits a cell "
                      "-- a road must not cross or double back on itself")
            elif rule == "edge":
                print("      fix: move the entry/exit corner onto x in {0, COLS-1} or "
                      "y in {0, ROWS-1}")
            elif rule == "mask":
                print("      fix: widen the grass band between parallel road runs to at "
                      "least two cells (see ROAD_LONG's own header in test_board.gd for "
                      "the worked example), or add the tile+mask entry to GRASS_EDGE_TILE "
                      "if the kit actually ships one")
            elif rule == "floor":
                print("      fix: shorten the road or widen its gaps so more of the "
                      "field stays buildable")
            elif rule == "pocket":
                print("      fix: widen the gap between the two road runs that seal the "
                      "pocket, or route one of them so it does not end flush against the "
                      "board's own edge")

    print("")
    print("board_check: %d road(s) in the corpus, %d rule(s) each, %d finding(s) "
          "(%s)" % (len(roads), len(rule_names), len(findings),
                    ", ".join("%s=%d" % (r, by_rule[r]) for r in rule_names)))
    if not roads:
        print("NOTE: nothing to check -- the corpus parsed to 0 roads. That is a clean "
              "result only if _road_corpus() is genuinely empty, which it should never be.")
    return (1 if findings else 0), findings, per_road


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--self-test", action="store_true",
                     help="run the synthetic good/bad fixture instead of the real corpus")
    ap.add_argument("--quiet", "-q", action="store_true",
                     help="summary and NOT COVERED line only, no per-road/per-case lines")
    ap.add_argument("-v", "--verbose", action="store_true",
                     help="accepted for symmetry with other tools' --self-test; the "
                          "default already prints per-case lines")
    args = ap.parse_args(argv)

    if args.self_test:
        fails = self_test(verbose=not args.quiet)
        code = 1 if fails else 0
    else:
        code, _findings, _per_road = run_real(verbose=not args.quiet)

    print("")
    print("NOT COVERED: this reads game/board.gd and test/unit/test_board.gd as TEXT and "
          "re-derives Board's connectivity/tiling rules in Python; it does not run Godot "
          "and does not compile anything -- only import_check.py and lint_project.gd do "
          "that, and neither is parallel-safe. It cannot see: whether the KIT ACTUALLY "
          "SHIPS the PNG a GRASS_EDGE_TILE entry names (it trusts the dictionary, not the "
          "file on disk); whether Board.set_road()'s own GDScript refusals still match "
          "validate_structure() above if that method is edited without this file moving "
          "with it (the fixture in --self-test tests the RULES here, not that agreement); "
          "whether any GDScript test actually EXERCISES a corpus road at runtime (that is "
          "test/unit/test_board.gd's job, via _road_corpus(), which this tool parses but "
          "never runs); and any property of the corpus this tool was not told to check -- "
          "reachability from a specific game state, pest pathing speed, or anything that "
          "needs the engine's own physics or AI running.")
    return code


if __name__ == "__main__":
    sys.exit(main())
