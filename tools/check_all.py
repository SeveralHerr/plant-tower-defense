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
}

# No NOT COVERED line, and correctly so. Each entry is a claim that this file is
# not a checker -- if that stops being true, delete the entry and give the tool
# its contract line.
SELF = "check_all.py"

NOT_A_CHECKER = {
    "check_devtools_log.py": "a Claude Code Stop hook, not a repo checker -- it advises "
                             "about log-devtools.md and never gates",
    "devtools.py": "the bridge client; needs a running game",
    "run_tests.py": "opens the project and writes .godot/; the parent's, not a fan-out's",
    "upstream_gaps.py": "files gap reports upstream; writes to the network, not a check",
    "verify_ledger.py": "reads and appends the verify ledger; a record, not a check",
}

# A checker whose exit 2 has a known, benign cause the runner can detect for
# itself. Named rather than exempted: the runner reports the condition it found.
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
        if name == SELF:
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

    # Conditional skips, detected rather than exempted.
    skipped = {}
    for name, (probe, why) in CONDITIONAL_SKIP.items():
        if name in checkers and not probe.exists():
            skipped[name] = why
    to_run = [c for c in checkers if c not in skipped]

    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        futures = [pool.submit(run_one, name, []) for name in to_run]
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
    print("check_all: ran %d of %d discovered parallel-safe checker(s) -- "
          "%d clean, %d with findings, %d could not run"
          % (len(results), discovered, len(clean), len(found), len(broke)))
    print("           CLASSIFIED %d tools/*.py: %d checker(s), %d not parallel-safe, "
          "%d known non-checker(s), %d unclassified"
          % (len(list(TOOLS.glob('*.py'))), discovered, len(unparallel),
             len(NOT_A_CHECKER), len(unclassified)))

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

    if found or unclassified:
        return 1
    if broke or (args.strict and skipped):
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
