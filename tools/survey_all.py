#!/usr/bin/env python3
"""Run every survey under .claude/surveys/ and report what ran of what exists.

plant-tower-defense-98h3. Run from the repo root:

    python tools/survey_all.py            # run them all
    python tools/survey_all.py --quiet    # one line per survey
    python tools/survey_all.py --strict   # a survey that COULD NOT RUN gates too
    python tools/survey_all.py --self-check   # prove this runner can fail

WHY THIS EXISTS. `.claude/surveys/` held three scripts and nothing ran any of them.
`tools/check_all.py` exists precisely to make "a checker was written and silently never
ran" impossible -- it classifies every `tools/*.py` and fails on an unclassified one -- and
its own summary line, `CLASSIFIED 28 tools/*.py ... 0 unclassified`, is true and says
nothing whatever about a directory it never looks in. So the surveys were the exact failure
`check_all.py` was built to prevent, one directory over.

WHY A SECOND RUNNER RATHER THAN A SECOND DISCOVERY ROOT IN check_all.py. Measured before
deciding, which changed the answer -- the bead that asked for this assumed the three files
were interchangeable and they are three different kinds:

    heredoc_survey.py           exit 0   29.7 s    sweeps the WHOLE git history
    heredoc_survey_controls.py  exit 0    0.12 s   the fixture proving the sweep can fail
    flourish_peak.py            exit 2    2.3 s    needs a RUNNING GAME on the bus

`check_all.py` is the per-cycle, parallel-safe, no-game pool. Folding these in would put a
30-second history sweep on every cycle to re-answer a question about the past, and would
put a verb that needs a live game into a pool whose defining property is that it needs no
project at all. They are different questions on different clocks:

    check_all.py  ->  "is the tree clean NOW"        every cycle, seconds
    survey_all.py ->  "how often has this HAPPENED"  deliberately, when it matters

EXIT CODES, and read the middle one carefully:

    0  every survey that ran was clean
    1  a survey reported findings -- or, under --strict, one could not run
    2  this runner could not run (no surveys directory, or nothing in it)

A survey exiting 2 does NOT gate by default, and that is a deliberate choice rather than
laxity. `flourish_peak.py` needs a game on the bus and the honest, common case is running
this with no game up; a gate that is red whenever nobody launched Godot is the
permanently-red gate `.claude/skills/house-static-checker/SKILL.md` argues is worse than no
gate. But it is NAMED on every run with the survey's own reason, never dropped from the
count -- being silently absent is the entire defect this file exists to fix, so the one
thing it may never do is round a survey that did not run down to nothing.
"""

import argparse
import subprocess
import sys
import time
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
REPO = TOOLS.parent
SURVEYS = REPO / ".claude" / "surveys"

# Discovery is BY DIRECTORY, not by the `NOT COVERED` marker `check_all.py` uses, and the
# difference is load-bearing rather than a shortcut. Two of the three surveys do not carry
# that line -- `heredoc_survey.py` and `heredoc_survey_controls.py` were written before the
# house contract was, and marker-based discovery would have silently found one of three
# while printing a confident denominator. That is the same class of bug as the one being
# fixed, so the rule here is "everything in the directory is a survey", and a file that is
# not one has to be named below rather than quietly skipped.
NOT_A_SURVEY: dict[str, str] = {}


def discover() -> list[Path]:
    return sorted(p for p in SURVEYS.glob("*.py") if p.name not in NOT_A_SURVEY)


def run_one(path: Path, timeout: int) -> dict:
    started = time.monotonic()
    try:
        proc = subprocess.run(
            [sys.executable, str(path)],
            cwd=str(REPO), capture_output=True, text=True,
            errors="replace", timeout=timeout,
        )
        code, out = proc.returncode, (proc.stdout or "") + (proc.stderr or "")
    except subprocess.TimeoutExpired:
        code, out = 2, "timed out after %ds" % timeout
    except OSError as exc:
        code, out = 2, "could not be executed: %s" % exc
    return {
        "name": path.name,
        "exit": code,
        "seconds": time.monotonic() - started,
        "output": out.rstrip(),
        # The survey's own last non-empty line. For an exit 2 that is its reason, which is
        # the thing this runner must not invent for it -- a survey that cannot run says
        # WHY in that line, and paraphrasing it into a bare "could not run" would throw
        # away the only actionable half.
        "last_line": next((ln for ln in reversed(out.splitlines()) if ln.strip()), ""),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--quiet", action="store_true",
                    help="one line per survey instead of its full output")
    ap.add_argument("--strict", action="store_true",
                    help="a survey that COULD NOT RUN (exit 2) gates as well")
    ap.add_argument("--timeout", type=int, default=600,
                    help="per-survey timeout in seconds (default 600; the history "
                         "sweep takes ~30s and a slow machine is not a finding)")
    ap.add_argument("--self-check", action="store_true",
                    help="run the synthetic fixture that proves this runner can fail")
    args = ap.parse_args()

    if args.self_check:
        return self_check()

    if not SURVEYS.is_dir():
        print("survey_all: could not run -- no %s" % SURVEYS.relative_to(REPO))
        print(not_covered())
        return 2

    found = discover()
    if not found:
        # A zero denominator says so IN WORDS. `0 surveys, all clean` is the exact shape
        # this whole file exists to make impossible.
        print("survey_all: could not run -- %s exists but holds no .py survey. "
              "That is not a clean run; it is an empty one."
              % SURVEYS.relative_to(REPO))
        print(not_covered())
        return 2

    results = [run_one(p, args.timeout) for p in found]

    clean = [r for r in results if r["exit"] == 0]
    findings = [r for r in results if r["exit"] == 1]
    could_not = [r for r in results if r["exit"] not in (0, 1)]

    for r in results:
        label = {0: "clean", 1: "FINDINGS"}.get(r["exit"], "COULD NOT RUN")
        print("--- %-30s %-14s %6.2fs" % (r["name"], label, r["seconds"]))
        if not args.quiet and r["output"]:
            for line in r["output"].splitlines():
                print("      " + line)

    print()
    print("survey_all: ran %d of %d discovered survey(s) -- %d clean, %d with findings, "
          "%d could not run"
          % (len(results), len(found), len(clean), len(findings), len(could_not)))

    # Named, with the survey's OWN reason, every run. Never folded into the count and
    # dropped: a survey that did not run is the defect this file was written for.
    for r in could_not:
        print("  COULD NOT RUN: %s (exit %d) -- %s"
              % (r["name"], r["exit"], r["last_line"] or "no output"))
    if could_not and not args.strict:
        print("  (not gating; --strict makes a could-not-run fail the command. See this "
              "file's header for why the default is the other way.)")

    if NOT_A_SURVEY:
        for name, why in sorted(NOT_A_SURVEY.items()):
            print("  NOT A SURVEY: %s -- %s" % (name, why))

    print(not_covered())

    if findings:
        return 1
    if could_not and args.strict:
        return 1
    return 0


def not_covered() -> str:
    return (
        "NOT COVERED: this runs the surveys; it does not survey anything itself, so it "
        "inherits every blind spot in every NOT COVERED line above and adds two of its "
        "own. (1) It discovers BY DIRECTORY, so it cannot tell a survey from any other "
        ".py file dropped in .claude/surveys/ -- it would run it and report its exit code "
        "as a survey result. (2) It trusts each survey's exit code completely: a survey "
        "that reports clean over an empty input set, or that exits 0 having asserted "
        "nothing, is counted here as clean. Whether a survey ASKS a useful question is not "
        "a thing this file can see -- read the per-survey output, not this summary line."
    )


def self_check() -> int:
    """Prove this runner can fail, and that it distinguishes the three exit codes.

    .claude/skills/house-static-checker/SKILL.md: the fixture is not optional, and a
    positive control that cannot fail is worse than none. So this builds synthetic surveys
    with KNOWN exit codes in a temp directory, points the runner's discovery at them, and
    asserts the classification and the gate -- including the case that must NOT gate.
    """
    import tempfile
    global SURVEYS

    failures = []
    real = SURVEYS
    with tempfile.TemporaryDirectory() as tmp:
        SURVEYS = Path(tmp)
        cases = {
            "survey_clean.py": ("print('nothing to report')\nraise SystemExit(0)\n", 0),
            "survey_finds.py": ("print('2 hit(s)')\nraise SystemExit(1)\n", 1),
            "survey_blocked.py": ("print('no game on the bus.')\nraise SystemExit(2)\n", 2),
        }
        for name, (src, _) in cases.items():
            (SURVEYS / name).write_text(src, encoding="utf-8")

        got = {r["name"]: r["exit"] for r in (run_one(p, 60) for p in discover())}
        for name, (_, want) in cases.items():
            if got.get(name) != want:
                failures.append("%s: expected exit %d, runner saw %r"
                                % (name, want, got.get(name)))

        # The gate itself, in both directions. A findings survey MUST gate; a
        # could-not-run survey must NOT, unless --strict. Asserting only the first would
        # pass on a runner that gated on everything, which is the permanently-red gate.
        if len(discover()) != 3:
            failures.append("discovery found %d of 3 synthetic surveys" % len(discover()))

        (SURVEYS / "survey_finds.py").unlink()
        remaining = {r["name"]: r["exit"] for r in (run_one(p, 60) for p in discover())}
        if 1 in remaining.values():
            failures.append("removing the findings survey left a findings exit behind")
        if 2 not in remaining.values():
            failures.append("the could-not-run survey vanished from the results")

        # An empty directory must be exit 2 and say so, NOT a clean run over nothing.
        for p in discover():
            p.unlink()
        if discover():
            failures.append("temp directory did not empty")

    SURVEYS = real
    if failures:
        print("survey_all --self-check: %d FAILURE(S)" % len(failures))
        for f in failures:
            print("  " + f)
        return 1
    print("survey_all --self-check: 4 assertion(s) passed -- the runner distinguishes "
          "clean / findings / could-not-run, discovery counts what it finds, and a "
          "removed survey stops being reported.")
    print(not_covered())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
