# Cycle 44

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 44 taught

**The harness refresh was attempted, proven to regress, and reverted.** The install itself
was flawless — correct upgrade detection, no `.bak` (nothing had been locally edited), every
`.uid` present, every project-owned config key kept, and all nine project-authored checkers
under `tools/` untouched. Then the suite **segfaulted**: exit `3221225477`, three runs out
of three, always at the same test.

**The bisect is the whole story, and it cost two commands.** With the project's own code
held constant: 0.38.0 → `552/552`; 0.42.0 → segfault; 0.38.0 restored → `552/552`. Filed
upstream as [gh#43](https://github.com/SeveralHerr/godot-selftest-harness/issues/43) with
the reproduction, and two observations offered as *data rather than diagnosis* — I did not
prove a mechanism and said so.

**Without the before-measurement this reads as "the refresh broke my game."** `552/552,
12142 assertions` was written down before the installer ran, and that is the only reason
the next hour went into a bug report instead of into `plant.gd`. Cycle 40 said a test count
is a proof if you take it on both sides; this is the cycle that collected on it.

Also worth knowing: **the scaffold skill loads from a plugin cache pinned at 0.33.0** — five
versions behind this project. Running it as written would have downgraded everything. The
installer's own guard refuses that, and the skill documents `--plugin-root` for the case,
which is how this ran 0.42.0's installer instead.

## Where things stand

Twenty-nine beads ready. Still on harness **0.38.0**, deliberately. Suite 552/552 with
12142 assertions; lint 0/0; mirror identical; gap ledger clean; `findings` clean. Eight
skills, backlog empty.

`plant-tower-defense-ny3h` (the refresh) is **blocked on gh#43** and says so — do not retry
until that closes or 0.43+ ships. The gap re-audit that depends on it stays pending with it.

## Waiting on the user

Unchanged: **weather has no counter-play** (`plant-tower-defense-oo7e`). Water tiles and a
real counter, a cheaper counter needing no terrain, or weather stays a difficulty modifier.
Filed, not started, because building the wrong one of the three is expensive.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`,
checked by `python tools/mirror_check.py`) for the loop itself.

**Three standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI
baseline carries twelve overlaps acceptable only while both controls are unreachable. And
any harness operation should start by checking which version the skill's paths point at —
the cache pin is not the project's version and may be either older or newer.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the seven couplings. Bump the number at the top of
this file every time you refill.
