# Cycle 53

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 53 taught

**Design the change around the guard, and the guard stays silent.** The road now climbs.
`board.gd` carries a warning that several constants are reasoned from its exact route, so
the new corners were chosen to hold both invariants — 31 steps over 32 cells, 1984 px plus
two 64 px brackets = **2112 px, identical to the old road**. Checked with a twenty-line
script *before* the file was edited. `SIMULTANEOUS_PEST_CEILING`'s "3.5 pests per cell"
reasoning was undisturbed and its guard test passed untouched.

Everything that depends on the road's *shape* moved, exactly as that warning predicts by
name: two dead-ground counts, two garden placement lists, one split cell. All five were
**re-derived, not re-fitted** — the cob-coverage model was validated against the old list
first (it confirms the old seven cobs covered 32 of 32 on the old route) before being used
to build the new one.

**Coverage is not engagement.** Six cobs reach all 32 road cells and a pest still crossed
unfought, because a cob shoots only the furthest-along pest in range. The seventh cob is
for overlap, not reach — and that distinction was invisible until the six-cob version was
actually run.

**The reshape is worth less than what it proved.** The cost of changing the road is now
known and written down, and the invariant trick is reusable. A `PATH_CORNERS` that varied
per level, with the garden lists derived at test time the way they were derived by hand
this cycle, turns "another road" into a data change (`-m9u2`).

## Where things stand

Fifty-five beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **556/556**, 12208 assertions; lint 0/0; eight house checkers and the mirror
all exit 0; reach 1/1. Eleven skills. Upstream gh#44 and gh#46 open.

## Waiting on the user

**Weather has no counter-play** (`plant-tower-defense-oo7e`) — the only genuinely blocked
item, unchanged for many cycles. Water tiles plus a real counter, a cheaper counter needing
no terrain, or weather stays a difficulty modifier.

The game itself moved this cycle for the first time in five: the board is a serpentine with
a real vertical leg, and a quarter of the pest walk animation that had never rendered in a
real game now renders every wave. `-a6rf` (a cue for covered-but-contested ground),
`-g8kc` (tint ground nothing can use) and `-f5z6` (deaths that differ by what killed them)
are the next player-facing ones ready.

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
