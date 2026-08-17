# Cycle 30

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to pick the loop back up. **Never write a work checklist
here.** `bd ready` is the checklist.

## What cycle 30 taught

A guard that names things by hand can only see what someone remembered to name. The suite
had been writing the developer's real `user://highscore.save` for an unknown number of
cycles, and `test_no_test_persists_through_the_players_own_save` reported clean the whole
time — its needle list names RunConfig's own methods, and both writers went in through the
game (`Game.bank_score()` and `Game._unhandled_input()`), so the rule never matched. The
fix that lasts is not a longer list: `tools/save_persist_check.py` derives the reaching set
backwards from `_save()` to a fixpoint over every non-test script, and asks for the
redirect once per test *script*, in `setup()`. The per-*function* version of the same rule
was written first and produced 62 findings over a suite that provably writes nothing —
every write along those chains is conditional, so "can reach the writer" is not "writes",
and a rule that fires on every test hosting `game.tscn` is a rule people learn to waive.

The related lesson, cheaper to state: the real save survived by suite order. One test filed
320 over the real record; a later, unrelated test happened to save the restored in-memory
values back on top, which is why the file's bytes were identical and only its mtime moved.
"The evidence looks fine" and "nothing went wrong" are not the same claim.

`kanban-staleness-audit` also exists now, after being named as missing three separate times
without being built. That is what step 0 is for, and it worked on its first run.

## Where things stand

Six beads ready, none blocked, drawn from the kanban backlog, the skills-to-create list,
this cycle's harness gaps and this cycle's workflow change. The suite is 535/535 with 11706
assertions and writes zero `user://` files. Upstream issue
[gh#39](https://github.com/SeveralHerr/godot-selftest-harness/issues/39) carries two harness
gaps ([G-052], [G-053]); nothing is fixed there yet, and a fix reaches this machine only
after a merge, a version bump and a `/plugin update`.

## Waiting on the user

Nothing is blocking. Two things are worth a decision when you next look:

- **The idea backlog has 30 cycles of accumulated features and no expressed preference
  between them.** The four asked for directly by name (animate everything, more waves and
  bosses, the bomb dandelion, pest facing) are all shipped or in flight; everything else is
  grown rather than requested, so which of it you actually want is a taste call the loop
  cannot make. Say the word on any of them and it jumps the queue.
- **`kanban.md` is 1800 lines and says at its own top that roughly half is stale.** The
  audit procedure now exists as a skill. Running it end to end is a few cycles of work that
  produces no game, so it has not been started without you asking.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself. Bump the number at the top of this file every time you refill.
