#!/usr/bin/env python3
"""Check a /verify run.json against the keys the installed ledger actually reads.

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

Exit 0 clean, 1 findings, 2 could not run.
"""

from __future__ import annotations

import difflib
import json
import re
import sys
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


def main(argv: list[str]) -> int:
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
