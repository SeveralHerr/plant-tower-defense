#!/usr/bin/env python3
"""gap_ledger.py - `log-devtools.md` records a gap's status once per ENTRY, so a gap
mentioned four times has four status lines and nothing says which one is current.

WHY THIS EXISTS, and what was actually wrong.

The harness log's format asks every entry that touches a gap to restate its id:

    - [G-044] status: open | seen: 7 | harness: 0.38.0

That is right for the entry -- it says what was true that day -- and it makes the
FILE unable to answer "which gaps are open". Measured at the point this was written:
69 status lines over 49 distinct ids, of which **44 are currently open** -- and
three ids (G-024, G-030, G-033) carry an earlier `open` line AND a later `fixed`
one, so both readings sit in the file at once. A `grep -c "status: open"` returns
65, which is a count of LINES that was being read as a count of gaps: the bead
asking for this reconciliation said 61, and every number in that sentence needed
re-deriving before any of it could be acted on.

Two more things the same scan found:

  * **`G-001` is used twice for two unrelated gaps** -- once by the file's own format
    template at the top (`<what was missing>`, harness 0.7.0) and once by a real
    finding about `--set` wiping a value (0.18.0). The workflow says ids are stable
    and never reused; this is the file breaking its own rule, and it happened because
    the template is indistinguishable from an entry to anything reading the file.
  * A claim this tool nearly shipped, and did not: that seven ids sat on "no gaps
    this turn" notes. They do not -- **zero** of them do, checked directly. That
    number came from a throwaway regex that matched a "no gaps" heading and then
    walked forward into the NEXT entry's id line, and it was one edit from being
    written here as rationale. Writing the tool is what caught it, because a tool
    has to state its rule and a grep does not.

The rule this tool applies: **a gap's status is its LAST mention in file order.**
Entries are appended chronologically, so the newest line is the current one, and any
earlier line that disagrees is history rather than a contradiction. That turns an
unanswerable question into a derived one.

Nothing else in the toolchain can see this:

  * every other checker here reads `.gd`, `.tscn`, `.svg` or `.py`. A markdown log
    disagreeing with itself is not a defect any of them has a category for.
  * `upstream_gaps.py` (harness) copies entries into the harness repo. It moves text;
    it does not decide which status is current.
  * a human reading the file sees, for any one gap, a plausible and complete entry.
    The contradiction only exists between entries, hundreds of lines apart.

Parallel-safe by construction: reads one markdown file, opens no project, writes
nothing. **Advisory**: exit 0 unless it could not run at all (2). What it reports --
superseded `open` lines -- is history that must not be rewritten, so there is nothing
for a reader to action and a gate would only teach them to skip it.

    fixture:   template above the first entry / one id fixed in a later entry than it
               was opened in / one id opened and never closed
    mutations: drop the `i < first_entry` skip -> the template's id is counted, ids +1
               `current.setdefault(...)` instead of `current[...] = row` (first write
               wins) -> the fixed id reads `open` again and superseded drops to 0

THE `seen:` FIELD, AND WHY IT IS NOT THE MENTION COUNT.

The workflow says "hitting a known gap again bumps its `seen:` count", and the bead
asking for this (`plant-tower-defense-rks4`) reasoned that since this tool already
parses every mention of every id, **counting them IS the seen count**. It is not, and
the file says so: `G-009` is FILED at `seen: 4` on its first line (467), goes to 5
(514), and is restated at 5 (564). Four sightings happened before anyone wrote the id
down. So mentions are a FLOOR on `seen:`, never an equality, and deriving the field
outright would have reported 32 disagreements of which four (`G-009`, `G-010`, `G-028`,
`G-076`) are the format working correctly.

What CAN be derived is the floor being violated, and that is what this checks:

  * **understated** -- the current line declares fewer sightings than there are lines
    mentioning the id. A gap cannot have been seen fewer times than it was written
    about. 15 ids are in this state, and they are the bead's real finding: an entry
    re-described the gap without bumping the field.
  * **decreasing** -- `seen:` going DOWN between two mentions. Zero today; it is here
    because it is the shape a bad bulk edit would take, and nothing else would see it.
  * **absent** -- a current line carrying no `seen:` at all. 12 ids, all from the one
    bulk reconciliation block at 3969-3979 that marked eleven gaps fixed against the
    installed 0.38.0. Reported separately and NOT as a defect: a status change is a
    legitimate mention that is not a sighting.

`G-000` is excluded: it is the "no gaps this turn" sentinel (`status: n/a | seen: 0`),
not a gap. Parsing it needed the status group widened: a bare word-character class
matched `n` and silently turned "n/a" into a status of its own.

    fixture:   an id filed above its mention count (G-009) / an id re-mentioned without
               a bump (G-024) / a current line with no seen: field / the n/a sentinel
    mutations: `<` -> `!=` in the understated test -> G-009's legitimate 5-over-3
               batches back as a finding, understated 15 -> 19
               drop the n/a exclusion -> G-000 reads understated (1 mention, seen 0)
               count mentions from `current` instead of `history` -> every id has
               exactly one, understated drops to 0 and the check reports clean
"""

from __future__ import annotations

import argparse
import os
import re
import sys

LOG = "log-devtools.md"
STATUS_RE = re.compile(
    r"\[(?P<id>G-\d+)\]\s*status:\s*(?P<status>[\w/]+)"
    r"(?:[^\n]*?seen:\s*(?P<seen>\d+))?"
    r"(?:[^\n]*?harness:\s*(?P<harness>[\d.]+))?")
ENTRY_RE = re.compile(r"^## (\d{4}-\d{2}-\d{2})(.*)$")
OPEN = "open"
# `- Gap: no gaps this turn` entries still owe a [G-NNN] line, and they spend this id
# with `status: n/a | seen: 0`. It is bookkeeping saying a gap was looked for and not
# found -- excluded from every count here, because it is not a gap.
SENTINEL = "n/a"


def parse(path: str):
    """[(id, status, harness, line_no, entry, seen)] in file order."""
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        lines = fh.read().replace("\r\n", "\n").split("\n")
    # The format template lives above the first dated entry. It is prose ABOUT the
    # format, not a record, and counting it is how G-001 came to name two things.
    first_entry = next((i for i, l in enumerate(lines) if ENTRY_RE.match(l)), None)
    out = []
    entry = "(before the first dated entry)"
    for i, line in enumerate(lines):
        m_entry = ENTRY_RE.match(line)
        if m_entry:
            entry = m_entry.group(1) + m_entry.group(2)[:48]
        m = STATUS_RE.search(line)
        if not m:
            continue
        if first_entry is not None and i < first_entry:
            continue  # the template
        seen = m.group("seen")
        out.append((m.group("id"), m.group("status"), m.group("harness") or "?",
                    i + 1, entry, None if seen is None else int(seen)))
    return out


def seen_findings(history: dict) -> tuple:
    """(understated, decreasing, absent) over the per-id mention lists.

    `seen:` counts SIGHTINGS and a gap can be filed already at 4 of them, so the
    mention count is a floor rather than the value -- see the module docstring.
    """
    understated, decreasing, absent = [], [], []
    for gid, rows in history.items():
        if all(r[1] == SENTINEL for r in rows):
            continue
        mentions = len(rows)
        declared = rows[-1][5]
        if declared is None:
            absent.append((gid, mentions, rows[-1][3]))
        elif declared < mentions:
            understated.append((gid, mentions, declared, rows[-1][3]))
        high = None
        for row in rows:
            if row[5] is None:
                continue
            if high is not None and row[5] < high:
                decreasing.append((gid, high, row[5], row[3]))
            high = row[5] if high is None else max(high, row[5])
    key = lambda t: int(t[0].split("-")[1])
    return sorted(understated, key=key), sorted(decreasing, key=key), sorted(absent, key=key)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="project root (default: cwd)")
    ap.add_argument("--open", action="store_true", help="list the currently-open gaps")
    ap.add_argument("--seen", action="store_true",
                    help="list the ids whose seen: count is below their mention count")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    path = os.path.join(os.path.abspath(args.root), LOG)
    if not os.path.isfile(path):
        print("gap_ledger: no %s at %s - cannot run." % (LOG, args.root), file=sys.stderr)
        return 2
    rows = parse(path)
    if not rows:
        print("gap_ledger: no [G-NNN] status lines in %s - cannot run. Nothing was "
              "checked; this is not a pass." % LOG, file=sys.stderr)
        return 2

    current: dict[str, tuple] = {}
    history: dict[str, list] = {}
    for row in rows:
        current[row[0]] = row          # last write wins: entries are chronological
        history.setdefault(row[0], []).append(row)

    open_ids = sorted((g for g, r in current.items() if r[1] == OPEN),
                      key=lambda g: int(g.split("-")[1]))

    # Superseded lines are NOTES, not findings, and that distinction is deliberate.
    #
    # They are inherent to the format: a gap fixed in cycle 12 will always have its
    # cycle-4 `open` line above it, and the right response is to leave it there --
    # rewriting an old entry would falsify what was true the day it was written. A
    # check that reports something nobody can ever clear is a check people learn to
    # ignore, which is the state validate-ui was in before it grew a baseline.
    #
    # So this tool is ADVISORY: exit 0 unless it genuinely could not run. Its value is
    # the derived count and the --open list, not a gate.
    notes: list[str] = []
    for gid, rec in sorted(current.items(), key=lambda kv: int(kv[0].split("-")[1])):
        if rec[1] == OPEN:
            continue
        stale = [r for r in history[gid] if r[1] == OPEN]
        if stale:
            notes.append("%s is `%s` (line %d) with %d earlier `open` line(s)"
                         % (gid, rec[1], rec[3], len(stale)))
    understated, decreasing, absent = seen_findings(history)
    if not args.quiet:
        print("gap_ledger: %d status line(s), %d distinct id(s), %d currently open, "
              "%d superseded"
              % (len(rows), len(current), len(open_ids), len(notes)))
        print("  seen: %d id(s) declare fewer sightings than they have mentions, "
              "%d decrease, %d carry no seen: on their current line"
              % (len(understated), len(decreasing), len(absent)))
        if len(current) == 0:
            print("  NOTE: nothing to check -- no ids found in the dated entries.")
        print("  NOT COVERED: this reads statuses, not the harness. It cannot tell you "
              "whether an open gap has since been FIXED upstream -- that needs the "
              "installed version opened and the claim re-checked, which is the actual "
              "reconciliation work and is a human job. It also trusts file order as "
              "chronological order (true while entries are appended) and does not "
              "notice an id used for two unrelated gaps unless their statuses differ. "
              "On `seen:` it checks only the FLOOR -- a gap seen ten times and mentioned "
              "twice is indistinguishable here from one seen twice, because the "
              "sightings that did not get written down leave no trace in this file.")
        if notes:
            print("  NOTE: %d id(s) have an earlier `open` line above their current "
                  "status -- history, not a contradiction, and left in place on "
                  "purpose: %s" % (len(notes), "; ".join(notes)))
    if args.open:
        print("\ncurrently open, oldest first:")
        for gid in open_ids:
            rec = current[gid]
            print("  %-7s harness %-7s line %-6d %s" % (gid, rec[2], rec[3], rec[4]))
    if args.seen:
        print("\nseen: below its mention floor -- an entry re-described the gap without")
        print("bumping the field. Fix by bumping the CURRENT line; never rewrite an old one.")
        for gid, mentions, declared, line in understated:
            print("  %-7s declared %-3d mentioned %-3d line %d" % (gid, declared, mentions, line))
        if decreasing:
            print("\nseen: DECREASES between mentions -- a count went down, which nothing legitimate does:")
            for gid, high, low, line in decreasing:
                print("  %-7s %d -> %d at line %d" % (gid, high, low, line))
        print("\nno seen: on the current line (%d) -- reported, not a defect: a status" % len(absent))
        print("change is a mention that is not a sighting.")
        print("  %s" % ", ".join(g for g, _, _ in absent))
    return 0


if __name__ == "__main__":
    sys.exit(main())
