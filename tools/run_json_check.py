#!/usr/bin/env python3
r"""Check a /verify run.json against the keys the installed ledger actually reads.

WHY THIS EXISTS (plant-tower-defense-knzv). `verify_ledger.py record` builds its row
from a fixed set of `run.get("...")` lookups and **silently ignores every other key**.
Nothing tells you: not the tool, not `--help`, not the output. Twice a cycle wrote a
run.json with plausible-but-wrong names and got a well-formed row that under-reported a
clean run -- `verdict: unknown`, `lint: null`, `tests: null` -- which is the exact
"well-formed zeros" failure `.devtools/verify-runs.jsonl` exists to prevent, in the file
that exists to prevent it. Upstream gh#46 is fixed at 0.47.0 with a difflib suggestion;
this project pins 0.38.0 on purpose (gh#43), so the gap is real here and this is the fix
available here.

WHICH GATE WOULD HAVE CAUGHT IT AND WHY IT DOES NOT. None. `name_check.py` resolves
GDScript identifiers, not JSON keys. Lint and the test suite never open `.devtools/`.
`verify_ledger record` is the only reader and its whole defect is that it says nothing.
This is a checker rather than a test because the input is a file written by hand, once
per run, minutes before it is consumed and discarded.

THE KEY LIST IS DERIVED, NOT TYPED. It is scraped from the installed
`tools/verify_ledger.py` -- every `run.get("key")` in the file -- so a harness upgrade
that adds or renames a key updates this checker for free. A hand-written copy here would
be a second source of truth about a tool whose entire problem is drift between what you
write and what it reads.

Usage:
    python tools/run_json_check.py [PATH]        # default .devtools/run.json
    python tools/run_json_check.py --fixture     # the synthetic fixture; proves it can FAIL

Exit 0 clean, 1 findings, 2 could not run.

    fixture:   `python tools/run_json_check.py --fixture`. KEPT, not written and
               deleted -- eight cases over a SYNTHETIC ledger source (so the expected
               key set is fixed and this fixture cannot drift when the harness
               upgrades), plus one case that runs the derivation against the REAL
               installed tools/verify_ledger.py. Cases: a clean run.json / an unknown
               key near-matching a real one / a flat `lint: 0` where a dict is wanted /
               a missing `verdict` / an illegal found[].phase / `{}` (three quiet-
               default findings AND the EMPTY note) / a JSON array instead of an object
               (exit 2) / an absent file (exit 2).
               Every case asserts the FINDING COUNT, not just the exit code: a rule that
               stops firing while another still fires leaves the gate at 1 and looks
               clean. `group_leak_check` shipped exactly that shape.
    mutations: 5, all RED, restore clean. Measured 2026-08-18; baseline 0 failure(s),
               and the failure counts below are what each mutation actually produced.
               `QUIET_DEFAULTS` -> `()` in the
                 missing-key loop                  -> 2 failures. missing_verdict and
                                                      empty_object both fall to 0
                                                      findings and exit 0. Note the
                                                      "the run.json is EMPTY" NOTE still
                                                      prints -- the denominator survives
                                                      the rule that fills it
               `cutoff=0.5` -> `cutoff=0.99`       -> 1 failure, and THE COUNT DOES NOT
                                                      MOVE: unknown_key still reports
                                                      `findings=1 exit=1`. Only the
                                                      separate "Did you mean 'verdict'?"
                                                      assertion goes red. This is the
                                                      whole argument for asserting named
                                                      evidence beside the count
               `EXPECTED_SHAPE.items()` -> `{}.items()`
                                                   -> 1 failure. wrong_shape falls to
                                                      0 findings and exit 0
               `not isinstance(run, dict)` -> `run is None`
                                                   -> not_an_object raises
                                                      `TypeError: list indices must be
                                                      integers` out of the shape loop.
                                                      A crash, not a quiet pass, but the
                                                      fixture is what makes it visible
               `run.get\(` -> `run.get \(` in
                 accepted_keys                     -> 14 failures. The real ledger yields
                                                      0 keys, so every case exits 2.
                                                      not_an_object and absent_file keep
                                                      the RIGHT exit code for the WRONG
                                                      reason and are caught only by their
                                                      needle assertions
"""

from __future__ import annotations

import difflib
import io
import json
import re
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEDGER = ROOT / "tools" / "verify_ledger.py"
DEFAULT_RUN = ROOT / ".devtools" / "run.json"

# Keys `record` accepts but whose absence it papers over with a default rather than a
# warning. `checks` and `found` it does warn about; these three it does not, and each
# one silently null is a row that under-reports a run that went fine.
QUIET_DEFAULTS = ("verdict", "lint", "tests")

# Shapes, for the keys where a plausible wrong shape exists. `lint`/`tests`/`runtime` are
# nested objects and the tempting mistake is a flat `lint_exit: 0`; `checks`/`found` are
# lists of objects.
EXPECTED_SHAPE = {
    "checks": list,
    "found": list,
    "lint": dict,
    "tests": dict,
    "runtime": dict,
    "value": str,
    "verdict": str,
    "harness": str,
    "cheaper_alternative": str,
    "expected": str,
}


def accepted_keys(source: str) -> set[str]:
    """Every top-level key `record` reads out of the run object."""
    return set(re.findall(r'\brun\.get\(\s*"([a-z_]+)"', source))


def found_phases(source: str) -> list[str]:
    """The legal `found[].phase` values, from the tuple the ledger validates against."""
    m = re.search(r'^FOUND_PHASES\s*=\s*\(([^)]*)\)', source, re.M)
    if not m:
        return []
    return re.findall(r'"([a-z]+)"', m.group(1))


# ---------------------------------------------------------------------------
# The synthetic fixture.
#
# Driven through the real main() over real files on disk rather than by poking the
# rule functions, so deleting a call site fails here even with the helper intact.
#
# The ledger is SYNTHETIC for eight of the nine cases. That is deliberate: this
# checker's whole job is to derive a key list from an installed file that upstream
# may change under it, so a fixture written against the real ledger would move every
# time the harness moves and would stop being a statement about the RULES. The ninth
# case is the one that keeps the derivation honest against the real file.
# ---------------------------------------------------------------------------

FIXTURE_LEDGER = '''#!/usr/bin/env python3
"""A stand-in for the installed verify_ledger.py, only as far as this checker reads it."""

FOUND_PHASES = ("lint", "tests", "runtime")


def record(run):
    row = {
        "verdict": run.get("verdict", "unknown"),
        "lint": run.get("lint"),
        "tests": run.get("tests"),
        "runtime": run.get("runtime"),
        "checks": run.get("checks") or [],
        "found": run.get("found") or [],
        "value": run.get("value"),
        "harness": run.get("harness"),
        "expected": run.get("expected"),
        "cheaper_alternative": run.get("cheaper_alternative"),
    }
    return row
'''

CLEAN_RUN = {
    "verdict": "pass",
    "lint": {"exit": 0},
    "tests": {"exit": 0, "failed": 0},
    "runtime": {"reach": []},
    "checks": [],
    "found": [{"phase": "lint"}],
    "value": "warranted",
    "harness": "0.38.0",
    "expected": "a clean gate",
    "cheaper_alternative": "reading the diff",
}

# (label, run.json content or None for "no file", want_findings, want_exit)
# `None` for want_findings means the run never got as far as printing a count.
FIXTURE_CASES = [
    ("clean", CLEAN_RUN, 0, 0),
    ("unknown_key", dict(CLEAN_RUN, verdictt="pass"), 1, 1),
    ("wrong_shape", dict(CLEAN_RUN, lint=0), 1, 1),
    ("missing_verdict", {k: v for k, v in CLEAN_RUN.items() if k != "verdict"}, 1, 1),
    ("bad_phase", dict(CLEAN_RUN, found=[{"phase": "elevenses"}]), 1, 1),
    ("empty_object", {}, 3, 1),
    ("not_an_object", ["verdict", "pass"], None, 2),
    ("absent_file", None, None, 2),
]


def run_fixture() -> int:
    """Return the failure count. Prints what it compared, never just a verdict."""
    global LEDGER
    fails = 0
    real_ledger = LEDGER
    tmp = Path(tempfile.mkdtemp(prefix="run_json_fixture_"))
    try:
        LEDGER = tmp / "verify_ledger.py"
        LEDGER.write_text(FIXTURE_LEDGER, encoding="utf-8")

        for label, content, want_findings, want_exit in FIXTURE_CASES:
            run_path = tmp / ("%s.json" % label)
            if content is None:
                argv = ["run_json_check.py", str(tmp / "there-is-no-such-file.json")]
            else:
                run_path.write_text(json.dumps(content), encoding="utf-8")
                argv = ["run_json_check.py", str(run_path)]

            old_out, old_err = sys.stdout, sys.stderr
            sys.stdout = io.StringIO()
            sys.stderr = io.StringIO()
            try:
                code = main(argv)
                out = sys.stdout.getvalue() + sys.stderr.getvalue()
            finally:
                sys.stdout, sys.stderr = old_out, old_err

            m = re.search(r"(\d+) finding\(s\)", out)
            got_findings = int(m.group(1)) if m else None
            ok_exit = code == want_exit
            ok_count = got_findings == want_findings
            if not (ok_exit and ok_count):
                fails += 1
            print("  %-6s %-16s findings=%s (want %s)  exit=%d (want %d)"
                  % ("ok" if ok_exit and ok_count else "FAIL", label,
                     got_findings, want_findings, code, want_exit))

            # The counts above can be right for the wrong reason, so name the
            # evidence each case exists for. `unknown_key` is the one that matters
            # most: the finding fires whether or not difflib suggested anything, so
            # the hint needs its own assertion or a broken cutoff is invisible.
            for needle, should in (
                    ("Did you mean 'verdict'?", label == "unknown_key"),
                    ("the run.json is EMPTY", label == "empty_object"),
                    ("is a list, not an object", label == "not_an_object"),
                    ("no run.json at", label == "absent_file")):
                seen = needle in out
                if seen != should:
                    fails += 1
                    print("  FAIL   %-16s %r seen=%s (want %s)"
                          % (label, needle, seen, should))
    finally:
        LEDGER = real_ledger
        for child in tmp.iterdir():
            child.unlink()
        tmp.rmdir()

    # The one case that must run against the REAL installed ledger: everything above
    # is a statement about the rules, and none of it would notice upstream renaming
    # `run.get("x")` into something this regex cannot see. That failure mode is an
    # exit 2 by design, so a fixture that never looks at the real file cannot tell
    # you the derivation still works.
    if real_ledger.is_file():
        source = real_ledger.read_text(encoding="utf-8", errors="replace")
        derived = accepted_keys(source)
        phases = found_phases(source)
        for label, got, want in (("keys derived from the REAL ledger", len(derived), 8),
                                 ("found phases", len(phases), 1)):
            ok = got >= want
            if not ok:
                fails += 1
            print("  %-6s %-34s %d (want >= %d)"
                  % ("ok" if ok else "FAIL", label, got, want))
        for key in ("verdict", "lint", "tests"):
            ok = key in derived
            if not ok:
                fails += 1
            print("  %-6s QUIET_DEFAULTS key %-10s derived from the real ledger: %s"
                  % ("ok" if ok else "FAIL", key, ok))
    else:
        fails += 1
        print("  FAIL   no installed tools/verify_ledger.py -- the derivation half of "
              "this fixture could not run, which is not a pass")

    print("run_json_check fixture: %d case(s) over a synthetic ledger plus the real "
          "derivation, %d failure(s). Every case asserts the FINDING COUNT beside the "
          "exit code, because three of the rules here gate at 1 and a rule that "
          "silently stopped firing would leave the exit code exactly where it was."
          % (len(FIXTURE_CASES), fails))
    print("  NOT COVERED: the fixture exercises the rules over hand-written run.json "
          "objects. It says nothing about whether THIS checkout's .devtools/run.json is "
          "right, and a clean fixture is a statement about the rules, not about the "
          "corpus. It also cannot see a `record` that reads a key some way other than "
          "`run.get(\"...\")` -- that is what the real-ledger case above is for, and it "
          "only counts keys, it does not prove none were missed.")
    return fails


def main(argv: list[str]) -> int:
    if len(argv) > 1 and argv[1] == "--fixture":
        return 2 if run_fixture() else 0
    path = Path(argv[1]) if len(argv) > 1 else DEFAULT_RUN
    if not LEDGER.is_file():
        print("run_json_check: cannot read %s -- nothing to derive the key list from."
              % LEDGER, file=sys.stderr)
        return 2
    source = LEDGER.read_text(encoding="utf-8", errors="replace")
    known = accepted_keys(source)
    phases = found_phases(source)
    if not known:
        print("run_json_check: found no `run.get(\"...\")` calls in %s -- the ledger's "
              "shape changed and this checker's derivation is stale, which is a finding "
              "about THIS FILE, not a clean run." % LEDGER.name, file=sys.stderr)
        return 2
    if not path.is_file():
        print("run_json_check: no run.json at %s. Nothing to check -- pass a path, or "
              "write the file before recording a ledger row." % path, file=sys.stderr)
        return 2
    try:
        run = json.loads(path.read_text(encoding="utf-8"))
    except (ValueError, OSError) as exc:
        print("run_json_check: %s is not readable JSON: %s" % (path, exc), file=sys.stderr)
        return 2
    if not isinstance(run, dict):
        print("run_json_check: %s is a %s, not an object." % (path, type(run).__name__),
              file=sys.stderr)
        return 2

    findings: list[str] = []

    for key in sorted(run):
        if key in known:
            continue
        near = difflib.get_close_matches(key, sorted(known), n=1, cutoff=0.5)
        hint = (" Did you mean %r?" % near[0]) if near else ""
        findings.append(
            "FINDING: unknown key %r -- verify_ledger reads it nowhere, so it will be "
            "dropped without a word and the row will not carry it.%s\n"
            "  fix: use one of %s.\n"
            "  waive: delete the key; there is no way to make the ledger keep it."
            % (key, hint, ", ".join(sorted(known))))

    for key, want in EXPECTED_SHAPE.items():
        if key in run and not isinstance(run[key], want):
            findings.append(
                "FINDING: %r is a %s, expected %s -- `record` will store it as-is and "
                "every reader of the ledger will mis-parse it.\n"
                "  fix: see .devtools/run.json in any recent commit for a worked example.\n"
                "  waive: none; the shape is what the readers assume."
                % (key, type(run[key]).__name__, want.__name__))

    for key in QUIET_DEFAULTS:
        if key not in run:
            findings.append(
                "FINDING: %r is absent -- `record` defaults it silently, so the row will "
                "read as an unknown/blank run rather than as the clean one it was.\n"
                "  fix: add it. `verdict` is pass|partial|fail; `lint` and `tests` are "
                "objects (e.g. {\"exit\": 0, \"failed\": 0}).\n"
                "  waive: omit deliberately only for an aborted run, and say so in the "
                "log-devtools entry." % key)

    if phases:
        for i, item in enumerate(run.get("found") or []):
            if not isinstance(item, dict):
                continue
            phase = item.get("phase")
            if phase is not None and phase not in phases:
                findings.append(
                    "FINDING: found[%d].phase is %r, not one of %s -- the ledger records "
                    "it as null.\n  fix: pick the phase the finding surfaced in.\n"
                    "  waive: none." % (i, phase, ", ".join(phases)))

    print("run_json_check: %d key(s) in %s, %d accepted by the installed verify_ledger, "
          "%d finding(s)" % (len(run), path.name, len(known), len(findings)))
    if not run:
        print("NOTE: the run.json is EMPTY. That is a clean result only if you expected "
              "to record a row carrying no evidence at all.")
    for line in findings:
        print(line)
    print("NOT COVERED: this reads a JSON file against a regex over the ledger's source. "
          "It cannot tell you whether the VALUES are true -- a `verdict: pass` on a failed "
          "run passes here. Nor does it see `--no-reach`, the scene-tree capture, or "
          "anything the ledger derives for itself. And its key list is only as good as the "
          "`run.get(\"...\")` idiom staying in use upstream; if that changes, this exits 2 "
          "rather than reporting clean.")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
