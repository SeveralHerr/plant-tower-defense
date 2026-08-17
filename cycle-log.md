# Cycle 37

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 37 taught

**Every number in the request was wrong, and the cheap way of getting them is what made
them wrong.** The bead said "reconcile the 61 open gaps". `grep -c "status: open"` returns
65 — a count of *lines*. The file holds 69 status lines over **49 distinct ids, 44 of them
actually open**, because the log records a status per entry and a gap fixed in cycle 12
still carries its cycle-4 `open` line. Three ids stated both readings at once.
`tools/gap_ledger.py` derives the status from the last mention; old entries are left alone,
since rewriting one would falsify what was true the day it was written.

**A citation is not a fix.** 43 of this project's ids appear somewhere in the installed
0.38.0 — but 29 of those are only in the harness's own copy of this log, put there by
`upstream_gaps.py`. Exactly **14 are cited in harness code**, in the past tense, which is
what a fix reads like. Counting the 43 would have closed 29 gaps nothing had acted on.

**And a code citation is not sufficient either.** `G-044` is named in `import_check.py`
and is still open at `seen: 7` — the citation describes a mitigation this project has
watched fail. Open gaps went 44 → 34, each with its evidence stated rather than implied.

The thing worth keeping: I was one edit from writing a false claim into the new tool's own
docstring — that seven ids sat on "no gaps this turn" notes. **Zero do.** That number came
from a throwaway regex that walked forward into the next entry's id line. Writing the tool
is what caught it, because a tool has to state its rule and a grep does not.

## Where things stand

Sixteen beads ready, none blocked. Open gaps 34, derived rather than grepped. Suite
544/544, lint 0/0, mirror identical. Eight skills, backlog empty. No game code changed this
cycle — it was entirely the loop's own bookkeeping, and it was overdue by seven cycles.

## Waiting on the user

Unchanged and still the one that matters: **weather has no counter-play**
(`plant-tower-defense-oo7e`). Water tiles and a real counter, a cheaper counter needing no
terrain, or weather stays a difficulty modifier. Three very different costs; building the
wrong one is expensive, so it is filed and not started.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`,
checked by `python tools/mirror_check.py`) for the loop itself. `python tools/gap_ledger.py
--open` is now the answer to "which harness gaps are open". Bump the number at the top of
this file every time you refill.
