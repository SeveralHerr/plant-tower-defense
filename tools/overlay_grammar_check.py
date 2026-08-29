#!/usr/bin/env python3
r"""Does every drawn-overlay cue in game/*.gd have an entry in OVERLAY_GRAMMAR.md?

WHY THIS EXISTS. `game/OVERLAY_GRAMMAR.md` says its own table is "derived from the draw
calls rather than remembered" and records the derivation recipe in its own text:

    grep -n "draw_arc(\|draw_circle(\|draw_line(\|draw_rect(" game/*.gd

That recipe has a structural blind spot, and the document says so itself, twice, in its
own "How this was derived" section: `Board.mark_dead_ground` and `Board.mark_road_answer`
paint `Line2D` CHILDREN pooled into a member array, and call none of the four `draw_*`
functions the recipe greps for -- board.gd's own header explains why: "a `_draw()` here
would be a cue no gate could ever see" headlessly. A census run from that recipe alone
undercounts the board's own cues, silently, and `game/cue_legend.gd`'s own audit trail
records this having been reported once before and left unfixed (plant-tower-defense-ktti).

So this checker walks `game/*.gd` for BOTH shapes of cue-painting:

    SHAPE 1 -- the four calls the existing recipe already greps for: `draw_arc(`,
               `draw_circle(`, `draw_line(`, `draw_rect(`. Scoped to exactly those four,
               on purpose: that is the recipe OVERLAY_GRAMMAR.md documents today, and
               widening it (to `draw_polyline`, say -- the OTHER blind spot that
               document's own derivation section names) is a separate, already-recorded
               gap, not this one. See NOT COVERED.

    SHAPE 2 -- `Line2D.new()` assigned into something that reads as a POOL: a class
               MEMBER VARIABLE, an ARRAY `.append()`, or a DICTIONARY value. This is the
               shape the grep cannot see at all, and it is the whole reason this tool
               exists rather than a wider grep. See `classify_line2d_site` for exactly
               which of those three sub-shapes it recognises, and NOT COVERED for the
               one it deliberately does not chase (a Line2D built in one function and
               pooled into a member var by a DIFFERENT function through a return value).

For every painter found, either shape, this checks whether OVERLAY_GRAMMAR.md's "What
each shape means" table's Instances column names it -- by the painter's own function
name, or by its file's bare name, because the table demonstrably keys entries both ways
(`` `Plant.draw_reach_ring` `` versus `` `placement_preview.gd` (at risk) ``). A painter
named by NEITHER key is a FINDING: a cue the grammar's own stated derivation recipe
cannot see, sitting undocumented.

WHY THE FILE-NAME KEY MATTERS AND IS NOT JUST A FALLBACK. Measured against the real
corpus (2026-08-29): `Board.mark_dead_ground` and `Board.mark_road_answer` are each a
thin public wrapper that decides WHETHER to redraw and defers the actual `Line2D.new()`
work to a private helper (`_redraw_dead_ground`, `_redraw_road_answer`). The grammar's
Instances column names the PUBLIC wrapper; this tool's shape-2 scan necessarily finds the
`Line2D.new()` call inside the PRIVATE helper, because that is where the literal call
sits. A function-name-only match would report both of the two real instances this bead is
about as findings -- the exact false positive that would make this checker untrustworthy
on the one file it exists to check. The file-name key is what closes that gap, checked
against the real file below.

WHICH GATE WOULD HAVE CAUGHT THIS: none. `name_check` resolves `Line2D` and `.append()`
happily; lint compiles the file; the unit suite asserts whatever a human remembered to
write. Nothing else reads a doc's own citation table against the source it claims to
derive from.

# fixture:   game/covered.gd -- a `draw_*` painter plus FOUR pool shapes (array-append,
#            direct member-assign, member-assign one step removed through a local, and a
#            dictionary value), each cited by exact function name in the fixture grammar
#            doc; a FIFTH, undocumented function whose only Line2D is returned to its
#            caller rather than pooled (must NOT be flagged: no append, no dict value, no
#            member assignment). game/uncovered.gd -- a `draw_*` painter and a Line2D
#            array-append pool cited NOWHERE, named with a sentinel token ("zorbat") that
#            appears in neither file nor grammar doc, so a match would mean the checker
#            is matching the wrong thing rather than genuinely finding the citation.
# mutations: (verified 2026-08-29 -- see self_test() for the runnable harness; every
#            number below was read from an actual run, not predicted)
#            drop the file-basename fallback, function-name only -> both known-good real
#              instances (mark_dead_ground, mark_road_answer) go from covered to FINDING,
#              because the literal Line2D.new() sites live in `_redraw_*` helpers the
#              grammar never names. Verified against the REAL corpus: `scan('.')` then
#              matching by function name alone reports 2 pool findings where the real
#              check (file-name fallback included) reports 0.
#            drop the member-assign branch in classify_line2d_site -> self-test FAILS on
#              2 of its 5 assertions: pool painters found drops 5 -> 4 and the excluded
#              count rises 1 -> 2 (mark_pool_via_var's Line2D, assigned to a member
#              through a local one line later, is no longer classified as a pool -- it
#              silently joins the excluded count, NOT the findings list, which is why
#              the exact-findings assertion still passes: a dropped branch here costs a
#              missed cue, not a false accusation)
#            drop the dict-value branch in classify_line2d_site -> the same two
#              assertions fail, same shape: mark_pool_dict's Line2D moves from the pool
#              count to the excluded count
#            drop the array-append branch                       -> real-corpus run: 2 ->
#              0 pool painters found, exactly the two `_redraw_*` helpers (mark_dead_
#              ground's and mark_road_answer's) this tool exists to see
#            reintroduce the newline-crossing LINE2D_ASSIGN_RE (see its own comment)
#                                                                 -> real-corpus run: 2 ->
#              0 pool painters found. `else:` immediately above `mark = Line2D.new()` is
#              swallowed whole as a fabricated multi-line type annotation on "else"
#              itself, and the real assignment is never seen
#            widen SHAPE 1 to include draw_polyline             -> pest.gd gains a
#              painter (`_draw_fought_mark`'s rim marker) already covered by the
#              file-name key, so the finding count does not move -- recorded as a
#              near-equivalent mutation on TODAY's corpus, not a reason to believe the
#              branch is inert
"""

import argparse
import glob
import os
import re
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gdsource  # noqa: E402  (see WHY THIS EXISTS in gdsource.py's own docstring)

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(errors="replace")

# SHAPE 1. Exactly the four terms OVERLAY_GRAMMAR.md's own recipe greps for -- not a
# wider set. See the module docstring's "Scoped to exactly those four" note.
DRAW_CALL_RE = re.compile(r"\b(draw_arc|draw_circle|draw_line|draw_rect)\s*\(")

# A class member variable, declared at column 0 (this repo's style keeps every method
# body indented, so an unindented `var NAME` is a field, never a local). Deliberately
# blind to a member declared inside a nested `class` block -- see NOT COVERED.
MEMBER_VAR_RE = re.compile(r"^var\s+(\w+)", re.M)

# A top-level function declaration. `^`-anchored for the same reason as MEMBER_VAR_RE:
# an indented `func` is a lambda or a nested class's method, neither of which this
# models. `re.M` so `^` means line-start, not string-start.
FUNC_RE = re.compile(r"^(?:static\s+)?func\s+(\w+)\s*\(", re.M)

# `Line2D.new()` as the WHOLE right-hand side of a one-line assignment: `var x := ...`,
# `x = ...`, or `x: Line2D = ...`. Anchored to the START of the (stripped) line and to
# its END, on purpose -- an earlier draft anchored only at the assignment operator and
# let the `(?::\s*\w+\s*)?=` branch's free-floating `\s*` cross a newline, so `else:`
# immediately above an unrelated `mark = Line2D.new()` line was swallowed whole as if
# "else" were the assignment target with a multi-line type annotation. Measured on
# board.gd: that bug produced 0 pool painters where 2 are real. Real GDScript
# assignments in this codebase do not wrap a bare RHS across lines, so the same-line
# anchor costs nothing observed and buys back the correctness.
LINE2D_ASSIGN_RE = re.compile(
    r"(?m)^[ \t]*(?:var[ \t]+)?(?P<lhs>(?:self\.)?[A-Za-z_]\w*)[ \t]*"
    r"(?::=|(?::[ \t]*\w+[ \t]*)?=)[ \t]*Line2D\.new\(\)[ \t]*$")

# The two sub-shapes SHAPE 2 can also take with no intermediate local at all: pushed
# straight into an append or a dict slot. Not observed in the real corpus today (both
# real instances go through a local first), kept because the bead names "a member var,
# an array append, or a dictionary value" as the three shapes and a direct one is a
# plain reading of "array append"/"dictionary value" that costs two lines to recognise.
DIRECT_APPEND_RE = re.compile(r"\.append\(\s*Line2D\.new\(\)\s*\)")
DIRECT_DICT_RE = re.compile(r"\b\w+\[[^\]\n]*\]\s*=\s*Line2D\.new\(\)")


def func_bounds(code):
    """[(start, end, name)] for every top-level function in already-blanked `code`."""
    starts = [(m.start(), m.group(1)) for m in FUNC_RE.finditer(code)]
    out = []
    for i, (start, name) in enumerate(starts):
        end = starts[i + 1][0] if i + 1 < len(starts) else len(code)
        out.append((start, end, name))
    return out


def line_of(code, pos):
    return code.count("\n", 0, pos) + 1


def find_draw_painters(code, rel):
    """[{rel, func, line, kinds}] -- one per function containing >=1 of the four calls.

    Grouped by FUNCTION, not by call: a `_draw()` naming three cues is one painter per
    the shape-1 census, same granularity OVERLAY_GRAMMAR.md's own table already uses for
    most of its entries (a whole file or a whole function, rarely one call site).
    """
    out = []
    for start, end, name in func_bounds(code):
        body = code[start:end]
        kinds = sorted(set(m.group(1) for m in DRAW_CALL_RE.finditer(body)))
        if not kinds:
            continue
        first = DRAW_CALL_RE.search(body)
        out.append({"rel": rel, "func": name,
                     "line": line_of(code, start + first.start()), "kinds": kinds})
    return out


def classify_line2d_site(rest_of_body, bare_name, member_vars):
    """Which of the three documented pool shapes claims `bare_name`, if any.

    `rest_of_body` is the function's text AFTER the `Line2D.new()` assignment -- a
    variable can only be pooled by code that runs after it exists. Returns a short shape
    label, or None when nothing in the rest of this SAME function reads as a sink for it
    -- which is the honest answer for a Line2D that is only ever returned to a caller
    (`board.gd`'s own page-frame border, `placement_preview.gd`'s `_new_cue_line`
    factory) rather than pooled here. See NOT COVERED for why "in this SAME function"
    is a real, named limit and not an oversight.
    """
    if re.search(r"\.append\(\s*" + re.escape(bare_name) + r"\s*\)", rest_of_body):
        return "array-append"
    if re.search(r"\b\w+\[[^\]\n]*\]\s*=\s*" + re.escape(bare_name) + r"\b",
                 rest_of_body):
        return "dict-value"
    if member_vars:
        alt = "|".join(re.escape(v) for v in member_vars)
        if re.search(r"\b(?:" + alt + r")\s*=\s*" + re.escape(bare_name) + r"\b",
                     rest_of_body):
            return "member-assign"
    return None


def find_pool_painters(code, rel):
    """([{rel, func, line, shape}], excluded_count).

    `excluded_count` is every `Line2D.new()` assignment site that did NOT read as a pool
    -- printed as its own denominator rather than folded silently into "0 pool painters
    here", per the house rule that a number acted on must show what it does not count.
    """
    member_vars = set(MEMBER_VAR_RE.findall(code))
    painters = []
    excluded = 0
    for start, end, name in func_bounds(code):
        body = code[start:end]
        for m in LINE2D_ASSIGN_RE.finditer(body):
            lhs = m.group("lhs")
            bare = lhs[len("self."):] if lhs.startswith("self.") else lhs
            line = line_of(code, start + m.start())
            if bare in member_vars:
                painters.append({"rel": rel, "func": name, "line": line,
                                  "shape": "member-assign"})
                continue
            shape = classify_line2d_site(body[m.end():], bare, member_vars)
            if shape:
                painters.append({"rel": rel, "func": name, "line": line, "shape": shape})
            else:
                excluded += 1
        for m in DIRECT_APPEND_RE.finditer(body):
            painters.append({"rel": rel, "func": name,
                              "line": line_of(code, start + m.start()),
                              "shape": "direct-append"})
        for m in DIRECT_DICT_RE.finditer(body):
            painters.append({"rel": rel, "func": name,
                              "line": line_of(code, start + m.start()),
                              "shape": "direct-dict"})
    return painters, excluded


def parse_instances_blob(grammar_path):
    """The concatenated Instances-column text of the FIRST table carrying that header.

    OVERLAY_GRAMMAR.md has TWO tables ("What each shape means" and, further down, "The
    channel that is not colour") and only the first has an Instances column at all --
    matching on the header text itself, rather than assuming it is the file's first
    table, is what keeps this from silently reading the wrong one if a table is ever
    inserted above it. Returns (blob, row_count); (None, 0) if no such table is found,
    which the caller treats as "could not run", not as "zero citations".
    """
    try:
        text = open(grammar_path, "r", encoding="utf-8", errors="replace").read()
    except OSError:
        return None, 0
    lines = text.splitlines()
    header = None
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("|") and stripped.endswith("|") and "Instances" in line:
            header = i
            break
    if header is None:
        return None, 0
    # header+1 is expected to be the `|---|---|---|` separator; tolerate its absence
    # rather than assuming it, and just start reading table rows at header+1 if the
    # very next line is not itself a pipe row (defensive, cheap, never hit today).
    i = header + 1
    if i < len(lines) and set(lines[i].strip()) <= set("|-: "):
        i += 1
    cells = []
    while i < len(lines) and lines[i].strip().startswith("|"):
        row = lines[i].strip().strip("|").split("|")
        if row:
            cells.append(row[-1])
        i += 1
    return "\n".join(cells), len(cells)


def named_in(blob, token):
    return re.search(r"\b" + re.escape(token) + r"\b", blob) is not None


def gd_files(root):
    # Flat, non-recursive, matching OVERLAY_GRAMMAR.md's own recipe exactly
    # (`game/*.gd`). A recursive walk would need tools/repo_walk.py's nested-checkout
    # guard against `.claude/worktrees/`; a single-level glob at `<root>/game/*.gd`
    # cannot reach in there at all, so this needs no exclusion list. See NOT COVERED.
    return sorted(glob.glob(os.path.join(root, "game", "*.gd")))


def scan(root):
    """(draw_painters, pool_painters, excluded_count, files_scanned)."""
    draw_painters, pool_painters = [], []
    excluded_total = 0
    files = gd_files(root)
    for path in files:
        rel = "game/" + os.path.basename(path)
        try:
            raw = open(path, "r", encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        code = gdsource.strip_comments(raw, strings=gdsource.BLANK)
        draw_painters += find_draw_painters(code, rel)
        pool, excluded = find_pool_painters(code, rel)
        pool_painters += pool
        excluded_total += excluded
    return draw_painters, pool_painters, excluded_total, files


def check(root, grammar_path, quiet=False, strict=False):
    """Run the real check against `root`. Returns an exit code (0/1/2).

    SHAPE 2 findings gate by default; SHAPE 1 findings are printed but advisory unless
    `strict`. This is not a weaker version of the same rule -- it is a different rule for
    a different failure mode, and OVERLAY_GRAMMAR.md's own text is why: "Most of what the
    grep turns up are sprites drawing themselves ... and are not cues," a judgement call
    the document makes by hand, not by grep. Measured on the real corpus: SHAPE 1 finds
    21 uncited `draw_*` functions, and every one of them is inside a file that document's
    own prose already names as a sprite rather than a cue (`sunflower.gd`, `seed_glyph.gd`,
    `title_backdrop.gd`, `notebook_page.gd`) or a file drawing a MINIATURE of an existing
    cue for the notebook's teaching page rather than the cue itself (`cue_legend.gd`,
    whose whole job is drawing icons FOR the grammar, not painting one). A hard gate on
    that set would be permanently red for a reason that has nothing to do with this
    bead -- exactly the outcome `.claude/skills/house-static-checker/SKILL.md` warns
    against ("a permanently-red gate is worse than no gate"), and the same shape this
    project already chose for `gate_aim_check.py --strict`. SHAPE 2 has no such ambiguity
    observed: every real Line2D-pool painter today already carries a citation, so its
    default is the hard gate the bead actually asks for, proven able to fire by the
    fixture's synthetic sentinel case.
    """
    draw_painters, pool_painters, excluded, files = scan(root)

    if not files:
        print("overlay_grammar_check: CANNOT RUN -- no game/*.gd found under %r. An "
              "empty scan is not a clean one." % root)
        return 2

    blob, rows = parse_instances_blob(grammar_path)
    if blob is None:
        print("overlay_grammar_check: CANNOT RUN -- could not find a markdown table "
              "with an 'Instances' column header in %s. Either the file is missing or "
              "its table format changed enough that this parser no longer recognises "
              "it; re-derive the header match rather than assume the old shape." %
              grammar_path)
        return 2

    draw_findings = []
    covered_draw = 0
    for p in draw_painters:
        ok = named_in(blob, p["func"]) or named_in(blob, os.path.basename(p["rel"]))
        if ok:
            covered_draw += 1
        else:
            draw_findings.append(p)

    pool_findings = []
    covered_pool = 0
    for p in pool_painters:
        ok = named_in(blob, p["func"]) or named_in(blob, os.path.basename(p["rel"]))
        if ok:
            covered_pool += 1
        else:
            pool_findings.append(p)

    file_count = len(set(p["rel"] for p in draw_painters + pool_painters))
    print("overlay_grammar_check: %d game/*.gd file(s) scanned; %d row(s) read from "
          "OVERLAY_GRAMMAR.md's Instances column" % (len(files), rows))
    print("  SHAPE 1 (draw_arc/circle/line/rect): %d painter(s) across %d file(s), "
          "%d with a grammar Instances entry, %d without (ADVISORY -- see below; "
          "--strict gates these too)"
          % (len(draw_painters), len(set(p["rel"] for p in draw_painters)),
             covered_draw, len(draw_findings)))
    print("  SHAPE 2 (Line2D.new() pooled): %d painter(s) across %d file(s), %d with a "
          "grammar Instances entry, %d without (GATES) (%d other Line2D.new() site(s) "
          "seen and NOT counted as a pool -- see NOT COVERED)"
          % (len(pool_painters), len(set(p["rel"] for p in pool_painters)),
             covered_pool, len(pool_findings), excluded))
    print("  %d gating finding(s), %d advisory finding(s), across %d file(s) scanned"
          % (len(pool_findings), len(draw_findings), file_count))

    if not quiet:
        for p in pool_findings:
            print("  FINDING: %s:%d %s [line2d_pool(%s)] -- named by neither its "
                  "function nor its file anywhere in OVERLAY_GRAMMAR.md's Instances "
                  "column"
                  % (p["rel"], p["line"], p["func"], p["shape"]))
            print("    fix: add an Instances-column reference to this function (by "
                  "name or file:line) under an EXISTING row of the 'What each shape "
                  "means' table in %s -- file it under the row whose SHAPE this cue "
                  "actually draws, the way `board.gd`'s mark_dead_ground/mark_road_answer "
                  "and placement_preview.gd's a6rf precedent do, rather than adding a "
                  "new row (a new row fails "
                  "test_the_legend_names_as_many_shapes_as_the_grammar_documents)."
                  % grammar_path)
        for p in draw_findings:
            print("  NOTE (advisory): %s:%d %s [draw_call] not named in the Instances "
                  "column -- often correct: many draw_* hits are a sprite drawing "
                  "itself, not a cue, which is a judgement call OVERLAY_GRAMMAR.md's "
                  "own text makes by hand rather than by grep. Re-run with --strict to "
                  "gate on these too." % (p["rel"], p["line"], p["func"]))

    print("NOT COVERED: this cannot tell whether an Instances-column entry that DOES "
          "name a painter is actually CORRECT -- only that some text naming the "
          "function or the file appears somewhere in the column. A stale citation "
          "pointing at the wrong function in the right file reads as covered. Shape 1 "
          "is scoped to the exact four calls OVERLAY_GRAMMAR.md's own recipe greps for "
          "(draw_arc/draw_circle/draw_line/draw_rect); draw_polyline and every other "
          "draw_* variant are out of scope here, the same blind spot that document's "
          "own derivation section already names for the ungrepped recipe -- widening "
          "this one is a separate change. Shape 2 recognises exactly three pooling "
          "idioms applied WITHIN THE SAME FUNCTION as the Line2D.new() call: a direct "
          "member-variable assignment, an array .append(), and a dictionary value "
          "assignment. It does NOT follow a Line2D through a return value into a "
          "different function's member-var assignment -- placement_preview.gd's "
          "_new_cue_line() factory (built once at _ready(), assigned to _reach_ring / "
          "_dead_lock_mark / _redundant_bar_a / _redundant_bar_b by its CALLERS, not by "
          "itself) is exactly this shape and is invisible to this tool. It assumes one "
          "flat class per file with every func at column 0; a nested `class` block's "
          "members and methods are invisible to both the MEMBER_VAR_RE and FUNC_RE "
          "scans. It reads game/*.gd non-recursively, matching the grammar doc's own "
          "recipe, so a cue painted from a differently-named directory is not walked at "
          "all. It reads source, not a running tree, and compiles nothing -- only "
          "import_check.py and lint_project.gd do that, and neither is parallel-safe.")

    return 1 if (pool_findings or (strict and draw_findings)) else 0


# ---------------------------------------------------------------------------
# The fixture. Two files: one whose painters ARE cited (by exact function name) in a
# tiny synthetic grammar doc, and one whose painters are named with a sentinel token
# ("zorbat") that appears in neither the grammar doc nor anywhere it could accidentally
# be credited. Kept small and un-self-describing on purpose -- see house-static-checker's
# note on a fixture that labels its own planted defect disarming the very rule it exists
# to test.

FIXTURE_COVERED_GD = """\
extends Node2D

var _cover_marks: Array[Line2D] = []
var _direct_mark: Line2D = null
var _via_var_mark: Line2D = null
var _slot_marks: Dictionary = {}

func _draw_something() -> void:
\tdraw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 12, Color.WHITE, 2.0, true)


func mark_pool_good(cells: Array) -> void:
\tfor cell in cells:
\t\tvar ring := Line2D.new()
\t\tring.points = PackedVector2Array()
\t\t_cover_marks.append(ring)


## Direct member-variable assignment: the Line2D.new() line's own left-hand side
## is a class member, no intermediate local at all -- the shape find_pool_painters()
## classifies BEFORE ever calling classify_line2d_site().
func mark_pool_direct() -> void:
\t_direct_mark = Line2D.new()
\t_direct_mark.width = 2.0


## Member-variable assignment ONE STEP removed: the Line2D goes into a local first,
## and only LATER in the same function does that local reach a class member. This is
## classify_line2d_site()'s third branch, distinct from both the direct case above and
## the array-append case below.
func mark_pool_via_var() -> void:
\tvar temp = Line2D.new()
\ttemp.width = 3.0
\t_via_var_mark = temp


## Dictionary value: classify_line2d_site()'s second branch.
func mark_pool_dict(cells: Array) -> void:
\tfor cell in cells:
\t\tvar slot = Line2D.new()
\t\t_slot_marks[cell] = slot


func _decoy_border() -> Line2D:
\tvar deco := Line2D.new()
\tadd_child(deco)
\treturn deco
"""

FIXTURE_UNCOVERED_GD = """\
extends Node2D

var _zorbat_pool: Array[Line2D] = []

func _draw_hidden_rune() -> void:
\tdraw_rect(Rect2(Vector2.ZERO, Vector2(4, 4)), Color.WHITE)


func mark_sentinel_zorbat(cells: Array) -> void:
\tfor cell in cells:
\t\tvar beam = Line2D.new()
\t\t_zorbat_pool.append(beam)
"""

FIXTURE_GRAMMAR_MD = """\
# Drawn-overlay grammar (fixture)

| Shape | Means | Instances |
|---|---|---|
| Solid ring | a REACH | `covered.gd` (`_draw_something`) |
| Small ring | a MARK | `covered.gd` (`mark_pool_good`, one Line2D per cell), `mark_pool_direct`, `mark_pool_via_var`, `mark_pool_dict` |
"""


def self_test(quiet=False):
    """Build the fixture tree, run `check` against it, and confirm the exact findings.

    Asserts WHICH findings came back (both must name game/uncovered.gd, one draw_call
    and one line2d_pool), not merely how many -- a count alone cannot distinguish "found
    the right two" from "found two wrong ones", per house-static-checker's own warning
    about counting rather than naming.
    """
    fails = 0
    with tempfile.TemporaryDirectory() as tmp:
        game_dir = os.path.join(tmp, "game")
        os.makedirs(game_dir)
        with open(os.path.join(game_dir, "covered.gd"), "w", encoding="utf-8") as fh:
            fh.write(FIXTURE_COVERED_GD)
        with open(os.path.join(game_dir, "uncovered.gd"), "w", encoding="utf-8") as fh:
            fh.write(FIXTURE_UNCOVERED_GD)
        grammar_path = os.path.join(tmp, "OVERLAY_GRAMMAR.md")
        with open(grammar_path, "w", encoding="utf-8") as fh:
            fh.write(FIXTURE_GRAMMAR_MD)

        draw_painters, pool_painters, excluded, files = scan(tmp)
        blob, rows = parse_instances_blob(grammar_path)

        def say(line):
            if not quiet:
                print(line)

        say("self-test: %d draw painter(s), %d pool painter(s), %d excluded "
            "Line2D.new() site(s), %d grammar row(s) parsed"
            % (len(draw_painters), len(pool_painters), excluded, rows))

        want_draw = 2
        ok = len(draw_painters) == want_draw
        fails += 0 if ok else 1
        say("  %-4s draw painters found == %d (got %d)"
            % ("ok" if ok else "FAIL", want_draw, len(draw_painters)))

        want_pool = 5
        ok = len(pool_painters) == want_pool
        fails += 0 if ok else 1
        say("  %-4s pool painters found == %d (got %d)"
            % ("ok" if ok else "FAIL", want_pool, len(pool_painters)))

        ok = excluded == 1
        fails += 0 if ok else 1
        say("  %-4s excluded (non-pool) Line2D.new() site == 1 (the _decoy_border "
            "return-only case) (got %d)" % ("ok" if ok else "FAIL", excluded))

        findings = []
        for p in draw_painters:
            if not (named_in(blob, p["func"]) or named_in(blob, os.path.basename(p["rel"]))):
                findings.append(("draw_call", p["rel"], p["func"]))
        for p in pool_painters:
            if not (named_in(blob, p["func"]) or named_in(blob, os.path.basename(p["rel"]))):
                findings.append(("line2d_pool", p["rel"], p["func"]))

        want = {("draw_call", "game/uncovered.gd", "_draw_hidden_rune"),
                ("line2d_pool", "game/uncovered.gd", "mark_sentinel_zorbat")}
        got = set(findings)
        ok = got == want
        fails += 0 if ok else 1
        say("  %-4s findings are EXACTLY %s (got %s)"
            % ("ok" if ok else "FAIL", sorted(want), sorted(got)))

        # covered.gd must produce NO findings at all -- the positive control.
        covered_findings = [f for f in findings if f[1] == "game/covered.gd"]
        ok = covered_findings == []
        fails += 0 if ok else 1
        say("  %-4s game/covered.gd has zero findings (got %r)"
            % ("ok" if ok else "FAIL", covered_findings))

    print("")
    print("overlay_grammar_check self-test: %d failure(s)" % fails)
    return fails


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="repo root (default: cwd)")
    ap.add_argument("--grammar", default=None,
                     help="path to OVERLAY_GRAMMAR.md (default: <root>/game/"
                          "OVERLAY_GRAMMAR.md)")
    ap.add_argument("--quiet", action="store_true",
                     help="denominators and NOT COVERED only, no per-finding lines")
    ap.add_argument("--self-test", action="store_true",
                     help="run the synthetic fixture instead of scanning the real repo")
    ap.add_argument("--strict", action="store_true",
                     help="also gate on SHAPE 1 (draw_*) findings, not just SHAPE 2 "
                          "(Line2D pools) -- see check()'s own docstring for why this "
                          "is opt-in")
    args = ap.parse_args(argv)

    if args.self_test:
        fails = self_test(quiet=args.quiet)
        print("NOT COVERED: this exercises the checker's own logic against a synthetic "
              "fixture; it says nothing about the real repo's current coverage. Run "
              "without --self-test for that.")
        return 1 if fails else 0

    grammar_path = args.grammar or os.path.join(args.root, "game", "OVERLAY_GRAMMAR.md")
    return check(args.root, grammar_path, quiet=args.quiet, strict=args.strict)


if __name__ == "__main__":
    sys.exit(main())
