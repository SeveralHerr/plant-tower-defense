# Cycle 36

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to pick the loop back up. **Never write a work checklist
here.** `bd ready` is the checklist.

## What cycle 36 taught

**A rule that modifies a value does not reach the surfaces that describe it.** Last
cycle's weather multiplied the interval a cob arms its cooldown with, and two readouts
went on quoting the level table: the selection panel said "0.80s" while the cob fired
every 1.60s, and `readiness()` divided a cooldown armed at 1.60 by a base of 0.80 — so the
arming glow sat empty for the whole first half of every reload under a drought. Two bugs,
one cause, and the second was found while fixing the first. The fix is not two patches;
`fire_interval()` is the effective interval now and is the only place either surface asks.

**And the project refused a feature on measurement, which is the part worth keeping.** The
bead asked for a standing weather readout on the top bar. The wave slot's base string is
302px in a 312px slot, so *every* candidate tag overflowed — `"  rain"` 366, `" ~"` 324, a
bare `"*"` 317. Widening the slot made this project's own budget check report
`hud_stats_row` at **-35px**: the row overflowing, shoving the wave button off the bar.
Written and reverted inside one cycle, with the numbers left in `Hud.WORST_CASE_TEXT` so
the next attempt reads them first.

That is a gate nobody ran on purpose doing better work than the runtime pass would have.
**No bridge this cycle** — every claim, including the pixel widths, was settled headlessly,
because this project measures text through the real theme font rather than by eye.

## Where things stand

Fifteen beads ready, none blocked. Suite 544/544 with 12020 assertions; lint 0/0; mirror
identical; every declared budget back above its floor. Eight skills, backlog empty.

## Waiting on the user

Two things, and the first is unchanged and still the one that matters:

- **Weather has no counter-play** (`plant-tower-defense-oo7e`, blocked on your decision).
  Water tiles and a real counter, a cheaper counter needing no terrain, or weather stays a
  difficulty modifier. Three very different costs; building the wrong one is expensive.
- **The top bar is full.** Measured this cycle: 10px of slack in the wave slot, 19px in the
  row. The next feature wanting a permanent readout needs a second bar row
  (`plant-tower-defense-bn2c`), which is real work and worth doing before it is urgent
  rather than during. Not blocking anything today.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`,
checked by `python tools/mirror_check.py`) for the loop itself. Bump the number at the top
of this file every time you refill.
