# Cycle 41

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 41 taught

**The measurement was the finding, not a defect.** The message row now has a budget, and it
reports `534 of 876 px — 342 px left`. I had expected it to be tight: two cycles of the top
bar being full had me assuming the same here, and a 55-character plant name did not clip —
it took roughly 85. That number is the point of *declaring* the budget rather than only
writing a test. "Roomy" is exactly what everyone assumed about the wave slot until it had
10px left, and now the difference between the two is written down instead of re-guessed.

**Four of the row's nineteen messages are data rather than prose.** They interpolate a plant
name or a corn level name, so they grow when the *content* grows — the rest are fixed
literals, as long as they will ever be. Those four moved to static builders on `Hud` for one
reason: a test can then sweep the whole catalogue through them, so the budget is checked
against every name the game can produce rather than against a worst case someone typed out
and hoped was still the worst. Planted an ~85-character name and watched it fail at
`998px of 876`.

**And I nearly broke a good test by making it "better".** The budgets-count assertion is a
hand-written list of names, and adding a budget is *supposed* to break it — it caught mine
at `Expected 6 but got 7`. My first instinct was to derive that list from the same table the
verb reads, which would have made the assertion tautological: the verb reporting what the
verb reports. Left hand-written, now with a comment saying why.

## Where things stand

Twenty-two beads ready, none blocked. Suite 550/550 with 12085 assertions; lint 0/0; mirror
identical; gap ledger clean; `findings` clean; the real save's md5 unchanged for the fifth
consecutive session. Seven declared budgets, all above their floors. Eight skills, backlog
empty.

## Waiting on the user

Unchanged: **weather has no counter-play** (`plant-tower-defense-oo7e`). Water tiles and a
real counter, a cheaper counter needing no terrain, or weather stays a difficulty modifier.
Filed, not started, because building the wrong one of the three is expensive.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`,
checked by `python tools/mirror_check.py`) for the loop itself. `python tools/gap_ledger.py
--open` answers "which harness gaps are open"; `python tools/devtools.py cmd budgets` prices
the seven couplings. Bump the number at the top of this file every time you refill.
