#!/usr/bin/env python3
r"""upstream_gaps_status_check.py - regression check for plant-tower-defense-0p99.

`tools/upstream_gaps.py` pools OPEN gaps from a project's `log-devtools.md` into a
destination log. `log-devtools.md` is append-only, so one gap id legitimately carries
several status lines over time (open, then open again, then fixed) on separate blocks
hundreds of lines apart. The tool used to decide whether to skip a gap by reading the
status on the block CURRENTLY being iterated, which selects a gap from an earlier open
block even after a LATER block closed it -- measured on this project's own log at the
time this was written: 5 ids (G-024, G-030, G-033, G-077, G-078) the per-block filter
still selected as open despite a later block marking them fixed. It now resolves each
id's status from its LAST mention in file order instead -- the rule `gap_ledger.py`
already documents ("last write wins: entries are chronological") -- without touching
the separate, deliberately-per-block collision/suffixed-id machinery (`G-027b`) that
tells two different gaps apart when two sessions mint the same id number.

No existing gate can see a resolution-rule regression here: `name_check.py` and
`import_check.py` type-check GDScript, not Python call graphs; `check_all.py` runs this
file *as* a checker but has no opinion on what any one checker asserts; and the tool's
own dry run over the real log only ever reports what today's rule already decided --
running it again after a regression prints a wrong number with just as much confidence
as the right one. Only a synthetic fixture with a known-correct answer can tell the two
apart.

This is a fixture-only checker: there is no live corpus to scan for this defect class
(a resolution rule inside one function's own logic, not a pattern any other repo file
can exhibit), so it just imports `tools/upstream_gaps.py` and calls its public
`upstream()` against text built in memory. Parallel-safe: reads and writes only inside
a `tempfile.TemporaryDirectory`, opens no project, touches no network despite the
module under test being named for pushing gaps to one -- `dry_run=True` never writes
even its own temp destination file.

    fixture:   an id open in an EARLIER block and fixed in a LATER one, both blocks
               carrying `seen: 1` (the exact shape G-024's real entries have, and the
               shape the collision heuristic below also keys off of) / a different id
               open throughout, alone / a genuine same-id-text collision -- two blocks
               for one id number, unrelated topics, both `status: open` and `seen: 1`
    mutations: revert the status filter to read `gap["fields"].get("status", "open")`
               (the pre-fix per-block value) instead of the precomputed per-id latest
               -> the fixed-then-reopened id reappears in `appended`, RED
               drop the `latest_status_by_id` precompute entirely and inline the
               per-block read where it is consumed -> same RED
               feed every block (not just the ones already passing a per-block open
               filter) into the collision/dedup loop -> the closed id's `seen: 1`
               `fixed` block collides with its own `seen: 1` `open` block and the loop
               either drops one silently or mints a bogus suffix for it, RED
               skip the still-open collision fixture's second block by treating the
               precomputed id-level status as authoritative for suffixing too (rather
               than the untouched per-block dedup) -> the collision fixture's second
               gap vanishes instead of landing on `test:G-070b`, RED
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import upstream_gaps as ug  # noqa: E402  (import after sys.path setup, deliberately)

# NOT COVERED: this proves the STATUS FILTER's resolution rule on a synthetic fixture
# only. It does not check the collision heuristic's OWN correctness beyond "unaffected
# by this change" (that heuristic, and its known real limits -- e.g. a genuine
# collision where one side is fixed and the other stays open under the same id text --
# are documented in tools/upstream_gaps.py's own comment and are out of scope here). It
# does not run against the real project log-devtools.md (that log changes every cycle,
# which would make this either flaky or a check of history rather than of the rule),
# and it does not compile or import-check anything -- only import_check.py and
# lint_project.gd do that, and neither is parallel-safe.

FIXTURE = """## Format section

- Gap: **<what was missing>**
  - [G-000] status: n/a | seen: 0 | harness: 0.1.0

## 2026-01-01 - a gap opens, and later gets fixed

- Gap: **thing was missing** - real evidence here, seen once.
  - [G-060] status: open | seen: 1 | harness: 0.10.0
  - Improvement: fix it

## 2026-01-02 - a different, unrelated gap that stays open

- Gap: **another missing thing, never touched again**
  - [G-080] status: open | seen: 1 | harness: 0.10.0
  - Improvement: fix this one too

## 2026-01-03 - two different findings mint the same id number (a real collision)

- Gap: **totally unrelated finding that happens to reuse G-070's number first**
  - [G-070] status: open | seen: 1 | harness: 0.11.0
  - Improvement: something entirely different

- Gap: **the second, different finding under the SAME id text, same cycle**
  - [G-070] status: open | seen: 1 | harness: 0.11.0
  - Improvement: something else again

## 2026-01-10 - the first gap from 01-01 is fixed, same seen count as when opened

- Gap: **[G-060] status: fixed** - the original thing was fixed upstream.
  - [G-060] status: fixed | seen: 1 | harness: 0.12.0
"""


def _run_upstream(fixture_text: str):
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        source = tmp / "project" / "log-devtools.md"
        source.parent.mkdir()
        source.write_text(fixture_text, encoding="utf-8")
        dest = tmp / "dest-log-devtools.md"
        dest.write_text("", encoding="utf-8")
        return ug.upstream(source, dest, "test", include_fixed=False, dry_run=True)


def main() -> int:
    try:
        result = _run_upstream(FIXTURE)
    except Exception as exc:  # pragma: no cover - "could not run", not a finding
        print("upstream_gaps_status_check: could not run upstream_gaps.upstream(): %r"
              % (exc,), file=sys.stderr)
        return 2

    appended = set(result["appended"])
    suffixed = result["suffixed"]
    skipped = result["skipped"]

    print("upstream_gaps_status_check: fixture has 5 gap block(s) (4 real ids, one "
          "id number reused by 2 unrelated blocks); %d appended, %d suffixed, "
          "%d skipped" % (len(appended), len(suffixed), len(skipped)))

    findings = []

    # RULE 1: an id fixed in a LATER block must not be selected as open, even though
    # an EARLIER block for the same id said "open" -- the bug this checker exists for.
    if "test:G-060" in appended:
        findings.append(
            "test:G-060 was appended as open, but its LAST block (file order) marks "
            "it fixed -- the status filter read the earlier open block instead of "
            "the id's latest mention")
    if not any(s.startswith("G-060 ") and "fixed" in s for s in skipped):
        findings.append(
            "test:G-060 should be reported skipped with its resolved status "
            "'fixed', not silently dropped or resolved as something else: "
            "skipped=%r" % (skipped,))

    # RULE 2: an unrelated gap that is open throughout is unaffected.
    if "test:G-080" not in appended:
        findings.append(
            "test:G-080 is open in its only block and should be appended; it was "
            "not -- the fix over-reached past the one id it should touch")

    # RULE 3: the collision heuristic (deliberately per-block, untouched by this fix)
    # still tells the two unrelated G-070 findings apart rather than merging or
    # dropping one -- a resolution-rule fix that reached into the dedup loop would
    # break this.
    if "test:G-070" not in appended or "test:G-070b" not in appended:
        findings.append(
            "the two unrelated G-070 findings (genuine same-id-text collision, both "
            "open, both seen: 1) should both survive as test:G-070 and test:G-070b; "
            "got appended=%r, suffixed=%r" % (sorted(appended), suffixed))
    if not any("G-070" in s and "G-070b" in s for s in suffixed):
        findings.append(
            "expected a suffixed-id note recording the G-070 collision; got %r"
            % (suffixed,))

    if findings:
        print("%d finding(s):" % len(findings))
        for f in findings:
            print("  FINDING: %s" % f)
        return 1

    print("0 finding(s) -- status filter resolves per id's latest block; "
          "collision/suffixed-id identity machinery unaffected.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
