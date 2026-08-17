# Cycle 54

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 54 taught

**The plan was to derive five recorded road figures. Deriving two of them was correct and
deriving the other three was measurably wrong.**

The walled mouth list and the buildable count are *rules* — "one mouth beside every road
cell", "every in-bounds cell is road or buildable" — with no judgement in them. Derived,
and the next road costs nothing for either.

The two cob gardens are not. Deriving them by the same greedy set cover produced a
**better cover** — five cobs reach all 32 road cells where seven are recorded — and broke
two tests, because what those gardens encode is calibrated **firepower**, not coverage. A
cob shoots only the furthest-along pest in range, so a minimal cover is a weaker garden
than a redundant one over the same cells. `derive-the-list` says exactly this: *if the
membership is a taste call, it is not derivable — stop rather than inventing a rule that
fits today's list.*

So they stay recorded and gained what was actually missing:
`test_the_recorded_gardens_still_have_the_property_they_claim`, which asserts every plant
can stand where it is put and that each garden reaches what it claims to. That turns a
recorded list into a **cache** rather than a second source of truth — and three mutations
kill it, including the exact cycle-53 defect where a garden cell had become road.

**And a near-miss worth remembering.** A heredoc stripped the leading `#` from four comment
lines, `test_placement.gd` stopped compiling, and the suite printed
`Total: 490 | Passed: 490 | Failed: 0 | ALL TESTS PASSED`. Sixty-seven tests silently
absent, reported as a clean run. The denominator and exit `2` are what caught it — the two
things the harness prints for precisely this. Fourth occurrence, so it is now a rule in the
workflow rather than a note in the log.

## Where things stand

Fifty-eight beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **557/557**, 12225 assertions; lint 0/0; eight house checkers and the mirror
all exit 0. Eleven skills. Upstream gh#44 and gh#46 open.

A second road is now a data change **plus two numbers** — `dead_corn` and `dead_chomp`,
left recorded on purpose. They are derivable, but their value is that a human is made to
look when the board's playability moves, and last cycle they moved in opposite directions.

## Waiting on the user

**Weather has no counter-play** (`plant-tower-defense-oo7e`) — the only genuinely blocked
item and unchanged for many cycles. Water tiles plus a real counter, a cheaper counter
needing no terrain, or weather stays a difficulty modifier.

Player-facing work is stacked and ready: `-ivoq` (draw coverage *depth*, since a cell
covered once and a cell covered three times look identical and behave completely
differently), `-dgu5` (a reach-par on the run summary), `-tzz7` (dead ground before you buy
the plant), `-a6rf`, `-g8kc`, `-f5z6`.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself.

**Four standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI
baseline carries twelve overlaps acceptable only while both controls are unreachable. Any
harness operation should start by checking which version the skill's paths point at. And
**never hand-edit `AGENTS.md`** — run `python tools/mirror_check.py --fix`.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **five** couplings; `list-commands --offline`
answers "does this verb exist" with no game running. Bump the number at the top of this
file every time you refill.
