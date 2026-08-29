#!/usr/bin/env python3
r"""loop_bound_check.py - a `while` in test/ whose termination depends on the CODE
UNDER TEST making progress, with no cap of its own.

WHY THIS EXISTS (plant-tower-defense-x44s, cycle 150's reader-mutation sweep).

Mutating `level += 1` out of `Plant.upgrade()` -- a one-line defect a refactor could
plausibly introduce -- made four test loops spin forever:

    while corn.upgrade():                         test_combat.gd (fixed, 1a3ac67)
    while not cob.is_max_level():                 test_selftest.gd (fixed, 1a3ac67)
    while err == "" and not corn.is_max_level():  test_placement.gd (fixed, 1a3ac67)
    while err == "" and chomp.can_upgrade():       test_combat.gd (fixed, 1a3ac67)

The runner is SIGTERMed and reports NOTHING: no exit code worth reading, no failing
test named, an empty log if stdout was buffered. That is strictly worse than a
failing test, and during a mutation sweep it is indistinguishable from a mutation
that never applied.

Measuring the fixed corpus for this bead (2026-08-29) found the class was NOT
extinguished by the four fixes above. Three more instances of the exact same shape
were sitting in the suite, unguarded, when this tool was written:

    while cheap.can_upgrade(): cheap.level += 1     test_selftest.gd:14401
    while dear.can_upgrade(): dear.level += 1        test_selftest.gd:14409
    while err == "" and plant.fluff() > 0:           test_selftest.gd:10397
    while not bank.locked_plants().is_empty():       test_economy.gd:99

The fourth carries its own comment recording that it has ALREADY spun forever twice
in this project's history, on two different mutations, and been re-pinned each
time rather than given a hard cap. That is the case for a standing checker rather
than a one-off fix: the pattern recurs faster than anyone remembers to grep for it
by hand.

THE CONVENTION THIS CHECKS FOR.

Elsewhere in the suite, the same shape is written with a hard cap alongside the
domain condition: `guard < 4000`, `waited < 30`, `pumped < 20`, `again < 120`,
`climbs < CornCobbler.LEVELS.size() + 2`. A loop is BOUNDED when its condition
contains a comparison (`<`, `<=`, `>`, `>=`) where a BARE local identifier -- not a
method call, not a dotted property chain -- sits against a bound that is visibly
finite: a numeric literal, or an ALL_CAPS constant (`WAVE_FRAME_CEILING`). That is
deliberately narrower than "any inequality anywhere in the condition": `frame <
max_frames`, `i < line.length()`, `i + 1 < segments.size()`, `page <
screen.total_pages()`, `plant.fluff() > 0` and `target.x > 0` all contain a `<` or
`>` and none names a hard cap -- either the bound is itself a live variable, or the
comparison's LHS is a method call / dotted access rather than a plain counter. Those
are not findings by default; DO NOT try to auto-classify them as safe either. Some
of them (a `DirAccess.get_next()` walk, a `while true:` with an inner `break`, a
`get_base_script()` chain, a greedy-cover loop that `break`s the moment it stops
making progress) are legitimate and finite for reasons this tool cannot see -- data
size, engine structure, an explicit escape. Those need a WAIVER, not a rewrite:

    # loop-bound-check: ok - <reason>

on the loop's own line. THIS TOOL DOES NOT TRY TO PROVE TERMINATION. The question is
"is there a bound", not "does it terminate" -- the second is undecidable and the
first is the whole value asked for.

WHICH EXISTING GATE WOULD HAVE CAUGHT THIS, AND WHY IT DOES NOT.

  * `name_check.py` / `import_check.py` / `lint_project.gd` all resolve identifiers
    and type-check. `while corn.upgrade():` is perfectly valid GDScript; nothing
    about it fails to compile.
  * `run_tests.gd` / `run_tests.py` catch a VACUOUS pass (zero assertions) and an
    aborted coroutine. Neither describes a hang: the process is SIGTERMed from
    outside and the runner never gets to print anything at all.
  * A runtime census cannot help either -- the defect is dormant until a mutation
    (or an equally small refactor) breaks the specific method the loop is trusting
    to make progress, and by definition nothing in the current tree exercises that.

Parallel-safe by construction: opens no project, writes nothing to `.godot/`, takes
no lock. Exit codes follow the house contract: 0 clean, 1 findings, 2 could not run.

    fixture:   `python tools/loop_bound_check.py --fixture`. KEPT, driven through
               the real main() over a temp project. Seven synthetic functions: an
               unguarded boolean-progress loop / the same loop with a hard-capped
               counter alongside it / a container-size bound (needs a waiver, not
               auto-passed) / a waived `while true:` with an inner break / the
               waiver marker quoted inside a STRING LITERAL on the loop's own
               line, which must NOT waive (cycle 126's citation_check.py incident,
               same shape, different tool) / an ALL_CAPS named-constant bound,
               which must auto-pass with no waiver at all / a bound against a
               plain local variable with no visible ceiling of its own
               (`frame < cap`), which must still be a finding. Baseline
               (4 finding(s), 1 waived, exit 1), and each function is asserted by
               name so a count staying put cannot hide one rule going silent
               while another double-fires.
    mutations: 4, all RED, restore clean. Measured 2026-08-29; baseline 0 failure(s).
               Read the FINDING COUNT, not just the exit code.
               drop the `#+[ \t]*` anchor
                 from WAIVER_RE                -> RED. The marker quoted inside a
                                                   string on the loop's own line now
                                                   waives it with no `#` in front:
                                                   findings 4 -> 3, waived 1 -> 2,
                                                   exit code unchanged at 1 -- a
                                                   checker can lose a finding
                                                   without moving its gate.
               `WAIVER_RE.search(raw_line)`
                 -> reads the comment-blanked  -> RED. The waiver is a COMMENT and
                    line instead                  the classifier runs on blanked
                                                    source, so the legitimately
                                                    waived `while true:` fires:
                                                    findings 4 -> 5, waived 1 -> 0.
               `ALLCAPS_RE` disabled            -> RED. The named-constant bound
                                                   loses its free pass and becomes a
                                                   finding nobody asked for:
                                                   findings 4 -> 5.
               `is_bounded` treats ANY          -> RED. `frame < cap` -- a bare
                 comparison as sufficient         counter against another bare
                 (drop the digit/ALLCAPS          variable with no ceiling of its
                 requirement)                     own -- is wrongly auto-passed:
                                                   findings 4 -> 3. (The
                                                   container-size case does NOT
                                                   move under this mutation --
                                                   `i + 1 < segments.size()` never
                                                   matches CMP_RE at all, LHS is not
                                                   a bare identifier -- which is why
                                                   the variable-bound case above was
                                                   added: a mutation that changes
                                                   nothing is not a survivor.)
"""

from __future__ import annotations

import argparse
import os
import re
import sys

import gdsource
import repo_walk

# One `while COND:` per matched line. Comment-only "while" (prose, e.g. "gone on a
# while") never reaches this: it runs on comment-BLANKED source, and a genuine
# multi-line condition (line continuation) is out of scope -- see NOT COVERED.
WHILE_RE = re.compile(r'^[ \t]*while[ \t]+(?P<cond>.+):[ \t]*$', re.M)

# A comparison whose LEFT side is a bare local identifier -- not a method call
# (`plant.fluff()`), not a dotted property (`target.x`), not an arithmetic
# expression (`i + 1`). The negative lookbehind refuses a start immediately after a
# word character or a dot, so `.size` and `fluff()` can never anchor a match here;
# only a token that begins fresh (after whitespace, `(`, `not`, `and`, `or`, or the
# start of the condition) counts as a counter.
CMP_RE = re.compile(
    r'(?<![\w.])(?P<lhs>[A-Za-z_][A-Za-z0-9_]*)[ \t]*(?P<op><=|>=|<|>)[ \t]*'
    r'(?P<rhs>.*?)(?=[ \t]+and[ \t]+|[ \t]+or[ \t]+|$)'
)
DIGIT_RE = re.compile(r'\d')
# A named ceiling written in SCREAMING_SNAKE_CASE (WAVE_FRAME_CEILING, FLUFF_MAX):
# treated as equivalent to a literal N, because it is one, just spelled once.
ALLCAPS_RE = re.compile(r'\b[A-Z][A-Z0-9_]*[A-Z0-9]\b')

# The house waiver idiom. Requires a reason (`- text` or `: text`) the way
# script_entry_check.py and settle_read_check.py do, so `# loop-bound-check: ok`
# with nothing after it is not itself accepted as documentation of anything.
WAIVER_RE = re.compile(r"#+[ \t]*loop-bound-check:\s*ok\b\s*[-:]\s*\S")

# For attributing a finding to the enclosing function, cosmetic only -- not used to
# scope the scan (every `while` in the file is checked regardless of which function
# it sits in).
FUNC_RE = re.compile(r'^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)', re.M)


def is_bounded(condition: str) -> bool:
    """True if the condition names a comparison against a visible finite bound."""
    for m in CMP_RE.finditer(condition):
        rhs = m.group("rhs")
        if DIGIT_RE.search(rhs) or ALLCAPS_RE.search(rhs):
            return True
    return False


def gd_files(root: str) -> list[str]:
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        # This tool is invoked with --tests pointed at test/unit specifically, so a
        # nested worktree checkout cannot be under it today. Shared rule anyway --
        # see tools/repo_walk.py's own docstring for the measured incident.
        repo_walk.prune(dirpath, dirnames, root)
        for fn in sorted(filenames):
            if fn.endswith(".gd"):
                found.append(os.path.join(dirpath, fn))
    return sorted(found)


def scan_text(raw: str, rel: str):
    """(loops, findings) for one file's raw text.

    loops: [(line_no, condition, bounded, waived)] for every `while` found.
    findings: the finding strings for the unwaived, unbounded ones.
    """
    code = gdsource.strip_comments(raw, gdsource.KEEP)
    raw_lines = raw.splitlines()

    # [(line_no, name)] of every function start, walked to attribute each `while`
    # to its enclosing function -- cosmetic, but a finding naming the function is
    # how a fixture (or a human) tells two findings apart without re-deriving line
    # numbers, and it is how check_all-style output reads elsewhere in this repo.
    func_starts = [(code.count("\n", 0, m.start()) + 1, m.group(1))
                   for m in FUNC_RE.finditer(code)]

    def enclosing_func(line_no: int) -> str:
        name = "<top-level>"
        for start, fname in func_starts:
            if start <= line_no:
                name = fname
            else:
                break
        return name

    loops = []
    findings = []
    for m in WHILE_RE.finditer(code):
        line_no = code.count("\n", 0, m.start()) + 1
        condition = m.group("cond").rstrip()
        bounded = is_bounded(condition)
        raw_line = raw_lines[line_no - 1] if 0 <= line_no - 1 < len(raw_lines) else ""
        waived = WAIVER_RE.search(raw_line) is not None
        loops.append((line_no, condition, bounded, waived))
        if bounded or waived:
            continue
        fname = enclosing_func(line_no)
        findings.append(
            "%s:%d %s() while %s:\n"
            "    Nothing in this condition names a hard cap -- no bare counter is "
            "compared against a literal or an ALL_CAPS constant. If it terminates "
            "at all, it does so because the code under test makes progress, which "
            "is exactly the property a mutation or a refactor can silently break "
            "(plant-tower-defense-x44s: this shape has already hung a run four "
            "times in this project's history).\n"
            "    fix: add a local counter and cap it in the condition, e.g. "
            "`guard < 4000` -- see test_economy.gd:241 or test_combat.gd:195 for "
            "the pattern already in this suite.\n"
            "    waive: add `# loop-bound-check: ok - <reason>` on the loop's own "
            "line, if it is finite for a reason this tool cannot see (a directory "
            "walk, a `while true:` with an inner break, a container-size bound, an "
            "engine structure walk)."
            % (rel, line_no, fname, condition)
        )
    return loops, findings


# ---------------------------------------------------------------------------
# The synthetic fixture. Driven through the real main() over a temp project, so
# deleting a call site (not just breaking a regex) fails here too. Six functions:
# an unguarded boolean-progress loop (the defect class itself) / the same shape
# WITH a hard-capped counter alongside it (must NOT fire) / a container-size bound
# that must stay a CANDIDATE rather than being auto-passed / a `while true:` with
# an inner break, waived / the waiver marker quoted inside a string literal, which
# must NOT waive the function beside it / a named ALL_CAPS ceiling, which must
# auto-pass with no waiver at all.
FIXTURE_SOURCE = '''extends Node


func test_bad_unguarded_progress() -> String:
\tvar corn := CornCobbler.new()
\twhile corn.upgrade():
\t\tpass
\treturn ""


func test_good_capped_counter() -> String:
\tvar corn := CornCobbler.new()
\tvar climbs := 0
\twhile corn.upgrade() and climbs < 40:
\t\tclimbs += 1
\treturn ""


func test_bad_container_size_needs_a_waiver() -> String:
\tvar i := 0
\twhile i + 1 < segments.size():
\t\ti += 1
\treturn ""


func test_good_while_true_waived() -> String:
\tvar from := 0
\twhile true:  # loop-bound-check: ok - DirAccess-style scan with its own break.
\t\tvar at := from
\t\tif at < 0:
\t\t\tbreak
\t\tfrom += 1
\treturn ""


func test_bad_marker_named_in_a_string_is_not_a_waiver() -> String:
\tvar needles: Array = []
\twhile needles.size() > 0 and str(needles) != "loop-bound-check: ok - not a real waiver":
\t\tneedles.pop_back()
\treturn ""


func test_good_allcaps_ceiling() -> String:
\tvar frame := 0
\twhile frame < WAVE_FRAME_CEILING:
\t\tframe += 1
\treturn ""


func test_bad_variable_bound_without_ceiling() -> String:
\tvar frame := 0
\tvar cap := 40
\twhile frame < cap:
\t\tframe += 1
\treturn ""
'''

# (findings, waived, exit code). Seven loops, four findings.
FIXTURE_EXPECT = (4, 1, 1)


def run_fixture() -> int:
    """Return the failure count. Prints what it compared, never just a verdict."""
    import io
    import shutil
    import tempfile

    root = tempfile.mkdtemp(prefix="loop_bound_fixture_")
    fails = 0
    try:
        with open(os.path.join(root, "project.godot"), "w", encoding="utf-8") as fh:
            fh.write("config_version=5\n")
        test_dir = os.path.join(root, "test", "unit")
        os.makedirs(test_dir)
        with open(os.path.join(test_dir, "test_fixture.gd"), "w",
                  encoding="utf-8", newline="") as fh:
            fh.write(FIXTURE_SOURCE)

        old_argv, old_stdout = sys.argv, sys.stdout
        sys.argv = ["loop_bound_check.py", "--root", root, "--tests", "test/unit"]
        sys.stdout = io.StringIO()
        try:
            code = main()
            out = sys.stdout.getvalue()
        finally:
            sys.argv, sys.stdout = old_argv, old_stdout

        found = out.count("  FINDING: ")
        m = re.search(r"(\d+) waived", out)
        waived = int(m.group(1)) if m else -1
        want_found, want_waived, want_code = FIXTURE_EXPECT

        for label, got, want in (("finding(s)", found, want_found),
                                 ("waived", waived, want_waived),
                                 ("exit code", code, want_code)):
            ok = got == want
            if not ok:
                fails += 1
            print("  %-6s %-12s %s (want %s)" % ("ok" if ok else "FAIL", label, got, want))

        for needle, should_fire in (
                ("test_bad_unguarded_progress", True),
                ("test_good_capped_counter", False),
                ("test_bad_container_size_needs_a_waiver", True),
                ("test_good_while_true_waived", False),
                ("test_bad_marker_named_in_a_string_is_not_a_waiver", True),
                ("test_good_allcaps_ceiling", False),
                ("test_bad_variable_bound_without_ceiling", True)):
            fired = needle in out
            ok = fired == should_fire
            if not ok:
                fails += 1
            print("  %-6s %-56s fired=%s (want %s)"
                  % ("ok" if ok else "FAIL", needle, fired, should_fire))
    finally:
        shutil.rmtree(root, ignore_errors=True)

    print("loop_bound_check fixture: 7 synthetic while loop(s), %d failure(s). The "
          "fifth case is cycle 126's citation_check.py incident, same shape, "
          "different tool: a waiver marker quoted inside a STRING LITERAL on the "
          "loop's own line must not waive it. The seventh names a variable bound "
          "with no visible ceiling (`frame < cap`), which stays a finding -- this "
          "tool does not chase what `cap` was set to." % fails)
    print("  NOT COVERED: the fixture exercises the bare-counter rule, the ALLCAPS "
          "ceiling rule, and the waiver (including the quoted-marker trap) over "
          "seven hand-written loops. It does not exercise a multi-line condition or "
          "a second `while` nested inside the one under test.")
    return fails


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="project root (default: cwd)")
    ap.add_argument("--tests", default="test/unit",
                    help="test tree to scan (default: test/unit)")
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--fixture", action="store_true",
                    help="run the synthetic fixture and exit; proves this checker "
                         "can FAIL, and that a marker quoted in a string does not "
                         "waive")
    args = ap.parse_args()

    if args.fixture:
        return 2 if run_fixture() else 0

    root = os.path.abspath(args.root)
    if not os.path.isfile(os.path.join(root, "project.godot")):
        print("loop_bound_check: no project.godot at %s - cannot run." % root,
              file=sys.stderr)
        return 2

    test_root = os.path.join(root, args.tests)
    if not os.path.isdir(test_root):
        print("loop_bound_check: no test tree at %s - cannot run." % test_root,
              file=sys.stderr)
        return 2

    paths = gd_files(test_root)
    if not paths:
        print("loop_bound_check: no .gd files under %s - cannot run. Nothing was "
              "checked; this is not a pass." % test_root, file=sys.stderr)
        return 2

    scripts = 0
    total_loops = 0
    bounded_loops = 0
    waived_loops = 0
    findings: list[str] = []

    for path in paths:
        try:
            with open(path, "r", encoding="utf-8") as fh:
                raw = fh.read()
        except (OSError, UnicodeDecodeError) as exc:
            print("loop_bound_check: cannot read %s (%s) - cannot run." % (path, exc),
                  file=sys.stderr)
            return 2
        scripts += 1
        rel = os.path.relpath(path, root).replace("\\", "/")
        loops, file_findings = scan_text(raw, rel)
        total_loops += len(loops)
        bounded_loops += sum(1 for (_, _, bounded, _) in loops if bounded)
        waived_loops += sum(1 for (_, _, bounded, waived) in loops
                             if waived and not bounded)
        findings.extend(file_findings)

    if not args.quiet:
        print("loop_bound_check: %d test script(s), %d while loop(s) found, %d of "
              "those classified BOUNDED by convention, %d waived, %d finding(s)"
              % (scripts, total_loops, bounded_loops, waived_loops, len(findings)))
        if total_loops == 0:
            print("  NOTE: nothing to check -- no `while` loop exists anywhere "
                  "under %s. A zero denominator looks exactly like a pass and is "
                  "not one." % args.tests)
        print("  NOT COVERED: this reads source, not a running tree, and does not "
              "try to prove termination -- only whether the condition names a "
              "visible hard cap. It cannot see a bound established several lines "
              "earlier and referenced by an opaque variable name (`frame < "
              "max_frames`, `page < screen.total_pages()`), a condition split "
              "across lines by a line continuation, or a loop whose real cap lives "
              "inside a helper function it calls. Those are neither auto-passed "
              "nor silently ignored -- they surface as findings needing a human's "
              "waiver, same as a genuine bug would, which is the deliberately "
              "conservative direction for a checker whose whole job is catching a "
              "hang nothing else in this toolchain can see. Nor does it compile "
              "anything -- only import_check.py and lint_project.gd do that, and "
              "neither is parallel-safe.")
    for f in findings:
        print("  FINDING: %s" % f)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
