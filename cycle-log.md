# Cycle 45

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 45 taught

**A test can run its assertion every time and check nothing.**
`test_corn_shoots_the_pest_closest_to_escaping` sets `far._leg = 4` on a five-point route
— the last leg — so the pest reaches the end and frees *itself* during the settle frames
`instantiate_scene` pumps. `assert_true(target == far)` then compares two references to the
same freed object, which is true. Green for many cycles, counted in
`Assertions: 12143 executed`, and it had never once checked the furthest-along rule it is
named for.

It was found by adding **one liveness assertion** while tidying up after last cycle's crash
— and it fails on 0.38.0, where the whole suite is green. This was never about the harness.
Fixed, then proven by planting a nearest-target implementation and watching it fail with
real numbers: `targets the pest at progress 0.75, not the closer one at 0.25`. That failure
was unreachable before, because both operands were nothing.

**Two things pulled in opposite directions and both are right.** `_furthest_along_in_range`
now skips invalid entries — a targeting routine should not crash a shipped game on a stale
reference — and that would have turned this defect into a *quiet* wrong answer. So the game
guards and the test asserts. The doc comment says so, because a later reader would
reasonably delete one of them.

**And the audit's conclusion was not to build a checker.** Nine tests create a self-freeing
mover and name it after an `await`; exactly one put its mover near the end of its life. A
gate firing nine times for one real defect is the ratio people learn to waive, so the rule
went into `godot-test-isolation` as a question to ask. Deciding *not* to automate is a
legitimate audit outcome and is written down so the same audit is not re-run by someone who
assumes it never happened.

## Where things stand

Thirty beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on gh#43).
Suite 552/552 with 12143 assertions; lint 0/0; mirror identical; gap ledger clean;
`findings` clean. Eight skills, backlog empty.

## Waiting on the user

Unchanged: **weather has no counter-play** (`plant-tower-defense-oo7e`). Water tiles and a
real counter, a cheaper counter needing no terrain, or weather stays a difficulty modifier.
Filed, not started, because building the wrong one of the three is expensive.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`,
checked by `python tools/mirror_check.py`) for the loop itself.

**Three standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI
baseline carries twelve overlaps acceptable only while both controls are unreachable. Any
harness operation should start by checking which version the skill's paths point at.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the seven couplings. Bump the number at the top of
this file every time you refill.
