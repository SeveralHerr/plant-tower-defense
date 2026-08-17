# Cycle 31

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to pick the loop back up. **Never write a work checklist
here.** `bd ready` is the checklist.

## What cycle 31 taught

**A backlog entry makes two claims, and only one of them is free.** "Here is an idea" costs
nothing; "the game does not do this yet" is an assertion about code. Cycle 30 wrote five
entries from inside `run_config.gd` without opening a screen, and three were wrong — one
proposed the milestone shelf, which ships in full and is deliberately in the notebook for a
measured reason (the title's button column is full to the inch), one rested on a false claim
about `fresh_record`, one over-claimed its scope. The shelf one became a bead that was
claimed and worked before anyone read the code. Step 3 now requires a `file:line` per entry,
and this cycle's four all carry one.

**The other lesson cost more.** Verifying the new reset confirmation through the live bridge,
`capture()` persisted — and wrote the developer's real `user://highscore.save`. The next
suite run loaded it and five byte-exact save assertions failed, twenty minutes and two tools
away from the cause. That is the same hazard cycle 30 spent itself fixing, arriving from the
bridge instead of the suite: the suite half is now gated by a derived checker and per-script
`setup()` redirects, and the bridge half has no guard and cannot have that one. Filed as
[gh#40](https://github.com/SeveralHerr/godot-selftest-harness/issues/40) — `launch` should
snapshot `user://` by default.

Both of the run's other findings came from *reading the screen in the running game*: the
confirmation first read "hold the garden still will go back to its shipped key", and then,
correctly worded, measured 962px in a 700px `clip_text` label. The headless test passed on
both, because `contains(describe(...))` is true of a garbled sentence and
`get_minimum_size()` reports ~1px on a clipped label.

## Where things stand

Seven beads ready, none blocked. The suite is 536/536 with 11726 assertions and writes zero
`user://` files; lint 0/0; the real save's md5 is what it was at the start of cycle 30. Two
skills were built across these two cycles (`kanban-staleness-audit`, `derive-the-list`),
which clears the skills-to-create backlog entirely for the first time. Three harness gaps are
upstream: [gh#39](https://github.com/SeveralHerr/godot-selftest-harness/issues/39) (G-052,
G-053) and gh#40 (G-054). Nothing is fixed there yet — a fix reaches this machine only after
a merge, a version bump and a `/plugin update`.

## Waiting on the user

Nothing is blocking. Two standing decisions, unchanged from last cycle and still worth your
word when you look:

- **The idea backlog is 30 cycles deep with no expressed preference between its entries.**
  The four you asked for by name are shipped or in flight; everything else is grown rather
  than requested, so which of it you actually want is a taste call the loop cannot make.
- **`kanban.md` is ~1850 lines and says at its own top that roughly half is stale.** The
  audit procedure is now a skill and was used in anger this cycle, but only on the entries
  that happened to be in the way. Running it over the whole file is a few cycles that
  produce no game, so it has not been started without you asking.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself. Bump the number at the top of this file every time you refill.
