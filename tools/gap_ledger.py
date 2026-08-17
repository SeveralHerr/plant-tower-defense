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
"""

from __future__ import annotations

import argparse
import os
import re
import sys

LOG = "log-devtools.md"
STATUS_RE = re.compile(
    r"\[(?P<id>G-\d+)\]\s*status:\s*(?P<status>\w+)"
    r"(?:[^\n]*?seen:\s*(?P<seen>\d+))?"
    r"(?:[^\n]*?harness:\s*(?P<harness>[\d.]+))?")
ENTRY_RE = re.compile(r"^## (\d{4}-\d{2}-\d{2})(.*)$")
OPEN = "open"


def parse(path: str):
    """[(id, status, harness, line_no, entry)] in file order."""
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
        out.append((m.group("id"), m.group("status"), m.group("harness") or "?",
                    i + 1, entry))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="project root (default: cwd)")
    ap.add_argument("--open", action="store_true", help="list the currently-open gaps")
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
    if not args.quiet:
        print("gap_ledger: %d status line(s), %d distinct id(s), %d currently open, "
              "%d superseded"
              % (len(rows), len(current), len(open_ids), len(notes)))
        if len(current) == 0:
            print("  NOTE: nothing to check -- no ids found in the dated entries.")
        print("  NOT COVERED: this reads statuses, not the harness. It cannot tell you "
              "whether an open gap has since been FIXED upstream -- that needs the "
              "installed version opened and the claim re-checked, which is the actual "
              "reconciliation work and is a human job. It also trusts file order as "
              "chronological order (true while entries are appended) and does not "
              "notice an id used for two unrelated gaps unless their statuses differ.")
        if notes:
            print("  NOTE: %d id(s) have an earlier `open` line above their current "
                  "status -- history, not a contradiction, and left in place on "
                  "purpose: %s" % (len(notes), "; ".join(notes)))
    if args.open:
        print("\ncurrently open, oldest first:")
        for gid in open_ids:
            rec = current[gid]
            print("  %-7s harness %-7s line %-6d %s" % (gid, rec[2], rec[3], rec[4]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
