#!/usr/bin/env python3
r"""Run every parallel-safe checker in tools/, deriving the list instead of retyping it.

WHY. `.claude/skills/cycle/SKILL.md` carries a hand-maintained list of the
stdlib checkers, and every cycle it got retyped into a shell for-loop. That is a
per-cycle transcription of a list that already exists in prose -- the same
disease the workflow cured for the work queue when it made `bd` the only place
items live. Two consequences, both real: a new `tools/*_check.py` that nobody
adds to the block is invisible and never runs, and a hand-typed loop can omit
one silently, which no exit code catches because the omitted checker never
reports anything.

THE DERIVATION RULE, and why it is not the obvious one.
plant-tower-defense-iezf proposed `glob('tools/*_check.py')`. That matcher steps
over `tools/check_devtools_log.py` -- a real tool whose name puts `check` at the
FRONT. It is not a repo checker (it is a Claude Code Stop hook, correctly
excluded here) so the glob happens to give the right answer today, for the wrong
reason, and would give the wrong one the moment somebody writes
`check_something_real.py`. `.claude/skills/derive-the-list/SKILL.md` names this
exactly: "ask what a member would look like that your matcher would step over".

So the rule is the house contract itself, not the filename:

  A parallel-safe checker is a `tools/*.py` whose SOURCE declares a
  `NOT COVERED:` line -- the one thing every checker in this repo is required to
  print, per .claude/skills/house-static-checker/SKILL.md.

That rule is self-maintaining: a new checker written to the house contract joins
this run the moment it is saved, without editing any list.

THE TWO EXCLUSION LISTS ARE TRIPWIRES, NOT CONVENIENCE.
`derive-the-list` has a section on when the hand-typing IS the check, and both
lists below are that case. They are small, they carry a reason each, and
changing one is supposed to cost a moment's thought:

  * NOT_PARALLEL_SAFE -- tools that meet the contract but open the Godot project
    and write `.godot/`. Two of those at once corrupt each other's run, so they
    are the parent's to run once, serially, after a fan-out lands.
  * NOT_A_CHECKER -- tools with no `NOT COVERED:` line that are known not to be
    checkers. This list exists so the third category can gate: any `tools/*.py`
    that is neither derived nor listed is reported as UNCLASSIFIED and fails the
    run. Without it a new tool could be silently neither, which is the original
    bug wearing different clothes.

# fixture:   a tools/ dir with a contract-following checker / a checker with no
#            NOT COVERED line / a NOT_PARALLEL_SAFE entry / an unlisted stray
# mutations: drop the UNCLASSIFIED report        -> a stray tools/*.py stops
#              failing the run, which is the exact hole this replaces
#            let NOT_PARALLEL_SAFE fall through  -> import_check.py joins the
#              thread pool and races the engine gates
#            glob `*_check.py` instead of the
#              NOT COVERED contract              -> bead_prose_check.py and the
#              rest still run, but check_devtools_log.py silently changes
#              category. Read the CLASSIFIED line, not the finding count.
"""

import argparse
import concurrent.futures
import subprocess
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
REPO = TOOLS.parent

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(errors="replace")

# The house contract's own marker. Every checker in this repo prints one.
CONTRACT_MARKER = "NOT COVERED"

# Meets the contract, but opens the project / writes .godot/. The parent runs
# these once, serially, after a fan-out lands. See the fan-out rule in
# .claude/skills/cycle/SKILL.md.
NOT_PARALLEL_SAFE = {
    "import_check.py": "opens the Godot project and writes .godot/; two at once corrupt "
                       "each other's run",
    "citation_relocate.py": "a FIXER, not a check: it re-points citations at the line "
                       "their CITED file's old text moved to via git diff hunks, and "
                       "WRITES the citing file with --write. Genuinely owes its NOT "
                       "COVERED line (a house tool per the house-static-checker "
                       "contract), so it sits here rather than in NOT_A_CHECKER, same "
                       "shape as import_check.py above -- unlike citation_rebind.py, "
                       "which resolved the same collision by dropping its marker "
                       "instead. Needs --base, so run bare it exits 2 on its own "
                       "argparse -- harmless today, not a guarantee.",
}

# No NOT COVERED line, and correctly so. Each entry is a claim that this file is
# not a checker -- if that stops being true, delete the entry and give the tool
# its contract line.
SELF = "check_all.py"

# A house tool that OWES a `NOT COVERED:` line (it is a tool in this repo) but is a RUNNER
# rather than a checker: it runs other things and reports their exit codes. Marker-based
# discovery cannot tell the two apart, because a runner's contract line looks exactly like
# a checker's -- so runners are named here.
#
# This started as `if name == SELF` for check_all.py alone. `survey_all.py` arriving
# (plant-tower-defense-98h3) demonstrated why one name was not enough: it was discovered as
# a checker on its first run and DID run clean, because with no game on the bus its own
# gate correctly declined to fire. The cost was invisible and real -- every check_all run
# was silently spending ~30s inside heredoc_survey.py's whole-git-history sweep, in a pool
# whose entire promise is that it is the fast parallel-safe one.
RUNNERS = {SELF, "survey_all.py"}

NOT_A_CHECKER = {
    "citation_rebind.py": "a FIXER, not a check: it re-points drifted citations at the "
                          "line their text moved to, and it WRITES kanban.md. It owes a "
                          "NOT COVERED line because it is a house tool, and that line is "
                          "exactly what marker-based discovery reads as a contract -- so "
                          "it was run as a checker on its first pass and exited 2 on its "
                          "own argparse, because it needs --against and --report. A tool "
                          "that cannot run without arguments can never be a checker here",
    "repo_walk.py": "a library, not a tool: the shared directory-exclusion rule the "
                    "rooted checkers import so a nested .claude/worktrees/ checkout "
                    "cannot change their denominators. Has no main() and prints nothing",
    "check_devtools_log.py": "a Claude Code Stop hook, not a repo checker -- it advises "
                             "about log-devtools.md and never gates",
    "devtools.py": "the bridge client; needs a running game",
    "mutate.py": "a mutation harness, not a check: it WRITES tools/*.py in the working "
                 "tree and puts them back, so it must never run in the parallel pool "
                 "beside a checker reading the same file. Run it by hand: "
                 "`python tools/mutate.py`",
    "run_tests.py": "opens the project and writes .godot/; the parent's, not a fan-out's",
    "upstream_gaps.py": "files gap reports upstream; writes to the network, not a check",
    "verify_ledger.py": "reads and appends the verify ledger; a record, not a check",
}

# A checker whose exit 2 has a known, benign cause the runner can detect for
# itself. Named rather than exempted: the runner reports the condition it found.
# Flags a checker needs in order to cover everything it CAN cover. A checker whose wider
# mode is opt-in runs in its narrow mode here forever otherwise -- citation_check read
# kanban.md and nothing else for eleven cycles while ~500 citations accumulated in bead
# prose, and adding the mode without adding this line would have changed nothing about what
# the pool actually checks. Keep these to coverage flags; never put a suppression here.
CHECKER_ARGS = {
    "citation_check.py": ["--beads"],
}

CONDITIONAL_SKIP = {
    "run_json_check.py": (
        REPO / ".devtools" / "run.json",
        "no .devtools/run.json yet -- the normal state at the start of a cycle, "
        "before /verify has recorded a run",
    ),
}


def classify():
    """Return (checkers, unparallel, skipped_reasons, unclassified)."""
    checkers, unparallel, unclassified = [], [], []
    for path in sorted(TOOLS.glob("*.py")):
        name = path.name
        # This file carries a NOT COVERED line because it is a house tool and
        # owes one, but it is a RUNNER, not a checker. Without this branch it
        # discovers itself and recurses. Its own first run reported exactly that
        # as an UNCLASSIFIED contradiction, which is the classifier working.
        if name in RUNNERS:
            continue
        try:
            src = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            unclassified.append((name, "could not be read"))
            continue

        declares = CONTRACT_MARKER in src

        if name in NOT_PARALLEL_SAFE:
            unparallel.append((name, NOT_PARALLEL_SAFE[name]))
            continue
        if name in NOT_A_CHECKER:
            if declares:
                unclassified.append(
                    (name, "listed as NOT_A_CHECKER but its source declares a "
                           "'%s' line -- one of the two is wrong" % CONTRACT_MARKER))
            continue
        if declares:
            checkers.append(name)
        else:
            unclassified.append(
                (name, "no '%s' line and not on either exclusion list. If it is a "
                       "checker, give it its contract line; if it is not, add it to "
                       "NOT_A_CHECKER with a reason." % CONTRACT_MARKER))
    return checkers, unparallel, unclassified


def run_one(name, extra_args):
    proc = subprocess.run(
        [sys.executable, str(TOOLS / name)] + extra_args,
        cwd=str(REPO), capture_output=True, text=True, errors="replace",
    )
    return name, proc.returncode, proc.stdout, proc.stderr


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--quiet", action="store_true",
                    help="print each checker's verdict line only, not its full output")
    ap.add_argument("--strict", action="store_true",
                    help="a conditionally-skipped checker also gates")
    ap.add_argument("--jobs", type=int, default=8,
                    help="how many to run at once (they are parallel-SAFE by construction)")
    args = ap.parse_args(argv)

    checkers, unparallel, unclassified = classify()
    discovered = len(checkers)

    if discovered == 0:
        print("check_all: CANNOT RUN -- discovered 0 parallel-safe checker(s) in %s. "
              "An empty run is not a clean run; the derivation rule (a source "
              "containing a '%s' line) matched nothing, which means either tools/ is "
              "empty or the contract marker changed." % (TOOLS, CONTRACT_MARKER))
        return 2

    # A CHECKER_ARGS key naming something the pool does not run is a coverage flag that
    # silently does nothing -- the same class of defect the flags exist to fix. Report it
    # rather than letting it rot: a rename would otherwise quietly narrow the pool back.
    stray = sorted(k for k in CHECKER_ARGS if k not in checkers)
    if stray:
        print("check_all: CANNOT RUN -- CHECKER_ARGS names %s, which the pool does not "
              "run. The flag(s) would be silently dropped. Fix the name or drop the entry."
              % ", ".join(stray))
        return 2

    # Conditional skips, detected rather than exempted.
    skipped = {}
    for name, (probe, why) in CONDITIONAL_SKIP.items():
        if name in checkers and not probe.exists():
            skipped[name] = why
    to_run = [c for c in checkers if c not in skipped]

    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        futures = [pool.submit(run_one, name, CHECKER_ARGS.get(name, []))
                   for name in to_run]
        for fut in concurrent.futures.as_completed(futures):
            results.append(fut.result())
    results.sort(key=lambda r: r[0])

    clean = [r for r in results if r[1] == 0]
    found = [r for r in results if r[1] == 1]
    broke = [r for r in results if r[1] not in (0, 1)]

    for name, code, out, err in results:
        verdict = {0: "clean", 1: "FINDINGS"}.get(code, "COULD NOT RUN (exit %d)" % code)
        print("--- %-28s %s" % (name, verdict))
        if not args.quiet and (code != 0 or not args.quiet):
            body = (out or "").rstrip()
            if body:
                print(body)
            if err.strip():
                print("[stderr] " + err.strip())

    print("")
    # plant-tower-defense-h3jz asked, of this exact line: should the top-line summary
    # also surface each gate's OWN slice ratio (name_check's "N of M root names",
    # svg_style_check's "N of N sprites", etc.)? Answered here rather than done:
    # NO, out of scope for this line. Those ratios have no common unit -- colours,
    # call sites, sprites, root names -- so folding 29 of them into one summary line
    # would either mean picking one field per checker by name (this runner would
    # have to know every checker's internal shape, the exact coupling the
    # NOT-COVERED marker discovery above exists to avoid) or dumping all of them
    # onto one line, which is the "coverage score" plant-tower-defense-h3jz says not
    # to build. This line's own denominator is a different question anyway -- how
    # many of the discovered checkers RAN, not how big any one checker's slice was
    # -- and non-quiet mode already prints every checker's full stdout, ratio line
    # included, right above its own "--- name.py" verdict. `--quiet` hides those on
    # purpose, the same way it hides everything else about a clean run.
    print("check_all: ran %d of %d discovered parallel-safe checker(s) -- "
          "%d clean, %d with findings, %d could not run"
          % (len(results), discovered, len(clean), len(found), len(broke)))
    # Every category is named and the numbers ADD UP to the glob. `runner(s)` is here
    # because it has to be: when RUNNERS grew from one name to two, the line printed
    # 19 + 1 + 7 = 27 of 29 and looked exactly as authoritative as it does now. A
    # classifier whose own summary silently loses two files is the bug it was written to
    # catch, so the total is asserted rather than trusted -- see the SUM MISMATCH line.
    total = len(list(TOOLS.glob("*.py")))
    named = discovered + len(unparallel) + len(NOT_A_CHECKER) + len(RUNNERS) + len(unclassified)
    print("           CLASSIFIED %d tools/*.py: %d checker(s), %d not parallel-safe, "
          "%d known non-checker(s), %d runner(s), %d unclassified"
          % (total, discovered, len(unparallel), len(NOT_A_CHECKER),
             len(RUNNERS), len(unclassified)))
    if named != total:
        print("           SUM MISMATCH: %d file(s) accounted for against %d on disk -- a "
              "category is missing from this line, so the counts above cannot be trusted"
              % (named, total))

    for name, why in skipped.items():
        print("SKIPPED: %s -- %s" % (name, why))
        print("         (named, not dropped: it is counted out of the denominator above. "
              "Re-run with --strict to gate on it.)")
    for name, why in unparallel:
        print("NOT RUN HERE: %s -- %s" % (name, why))
    for name, code, out, err in broke:
        print("COULD NOT RUN: %s exited %d. A 2 means nothing was verified by it, "
              "which is not the same as clean." % (name, code))
    for name, why in unclassified:
        print("UNCLASSIFIED: %s -- %s" % (name, why))

    print("NOT COVERED: this runs the checkers; it does not check anything itself, so it "
          "inherits every blind spot in every NOT COVERED line above and adds one of its "
          "own -- it classifies by reading source for a marker, so a tool that prints the "
          "contract line without honouring the exit-code contract is counted as a checker "
          "and its exit code trusted. It compiles nothing: only import_check.py and "
          "lint_project.gd do that, and neither is parallel-safe, which is why neither "
          "runs here.")
    print("NOT COVERED, and this is the SHAPE of the blind spot rather than another "
          "item in it: every gate here asks about NAMES, and none asks whether a CALL "
          "is well-formed. name_check resolves types, class_names, autoloads, preload "
          "paths and method names inside string literals; suite_reach_check counts "
          "whether a symbol is NAMED by a test; gate_aim_check counts whether a colour "
          "is NAMED in an assertion. So `x.no_such_method()` on a statically typed `x` "
          "is clean HERE, clean to import_check, and clean to lint_project.gd at 0 "
          "errors and 0 warnings -- measured in cycle 160 with three mutations, on a "
          "project type, on an engine type with the API index live, and inside game/ to "
          "rule out a scan root. It fails at runtime and nowhere else. Enabling Godot's "
          "own gdscript/warnings/unsafe_method_access in project.godot does NOT close "
          "it: lint's compile check is load()-based (tools/lint_project.gd:693) and a "
          "script with that call still loads and instantiates, so the warning never "
          "reaches the exit code. Recorded so the cheap fix is not re-tried. "
          "plant-tower-defense-zlm2.")

    if found or unclassified:
        return 1
    if broke or (args.strict and skipped):
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
