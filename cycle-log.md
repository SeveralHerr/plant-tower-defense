# Cycle 40

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 40 taught

**Fix the ownership before adding to it.** `-45wa` would have added a fourth condition to
a Label that already had three writers, each answering "is this line mine?" by comparing
the Label's own text. Doing the refactor first made the feature a one-line branch instead
of a fourth convention to keep in agreement.

The refactor is one painter and two claims: `_paint_message_row()` is the only assignment
to that Label, a transient message wins while it has time left, and the standing note is
the floor. **`547/547` before and `547/547` after is the whole proof that nothing moved** —
a stronger statement than any assertion I could have written about the refactor itself. The
one new test is the part that is not merely tidier: a message reading *exactly* like the
note now survives the wave starting, which the old text comparison could not make true.

**And the last wave says so**: `Wave 16 next — the last one · 36 pests · a queen.`
Finality leads, because it is the one fact there that changes what the run is about.

**The ledger row is `overkill`, and that is the honest verdict.** The last three cycles
were `warranted`, and a run of them is exactly what makes this one go unwritten. The suite
did this work; the launch confirmed one string.

## Where things stand

Twenty beads ready, none blocked. Suite 549/549 with 12053 assertions; lint 0/0; mirror
identical; gap ledger clean; `findings` clean; the real save's md5 unchanged for the fourth
consecutive session. Eight skills, backlog empty.

## Waiting on the user

Unchanged: **weather has no counter-play** (`plant-tower-defense-oo7e`). Water tiles and a
real counter, a cheaper counter needing no terrain, or weather stays a difficulty modifier.
Filed, not started, because building the wrong one of the three is expensive.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`,
checked by `python tools/mirror_check.py`) for the loop itself. `python tools/gap_ledger.py
--open` answers "which harness gaps are open". Bump the number at the top of this file
every time you refill.
