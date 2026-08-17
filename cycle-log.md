# Cycle 32

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to pick the loop back up. **Never write a work checklist
here.** `bd ready` is the checklist.

## What cycle 32 taught

**A test can be complete for a game that no longer exists, and it looks nothing like a
stale test.** `test_no_pause_card_legend_row_draws_past_the_paper` has measured the pause
legend's width budget for cycles and is careful, well-documented and correct. It measures
the legend *as built* — and every row it has ever measured carried a key we shipped. A
legend row is `"%s   %s" % [keys, does]`; the card's width was sized against the `does`
phrases, and the moment the Keys screen landed, the other half became the player's choice.
Sweeping every key `OS.get_keycode_string()` will name gives "On-screen keyboard", which
beside the widest verb drew **384px into a 304px box** — 80px of legend onto the dimmed
backdrop over a live board. The card is 440 now, and the new test re-derives the worst key
from the engine every run rather than pinning today's answer.

**The mirror is a gate now, and it caught one immediately.** `tools/mirror_check.py`
compares the Workflow block in `CLAUDE.md` and `AGENTS.md` — a block that has been silently
deleted from `AGENTS.md` twice, the second time by the commit that wrote the note warning
about it. The commit registering the tool added its line to a list *inside* that block, so
the checker reported `153 lines` against `152` before the sync. An unplanted catch, on its
first real use, made by someone who knew about the problem.

**And mutating a checker found a bug in the checker.** Removing `mirror_check`'s CRLF
normalisation left the CRLF fixture passing anyway — `open()` in text mode was silently
doing the same job, so the line was dead code with a comment claiming it was load-bearing.
`newline=""` makes the claim true. Feeding a checker bad input would never have shown that;
only breaking the checker did.

Smaller, and worth keeping: the "cite a `file:line`" rule added last cycle caught its first
bad entry within minutes — a proposed scope filter for `Game.key_help()` that has existed
at `game/game.gd:50` all along. Thirty seconds, because writing the citation meant opening
the function.

## Where things stand

Nine beads ready, none blocked. Suite 537/537 with 11741 assertions; lint 0/0; `findings`
clean; the real save's md5 is unchanged since cycle 30. `.claude/skills/` holds eight, and
the skills-to-create backlog has been empty since `who-wrote-this-file` landed this cycle.
Three harness gaps are upstream — [gh#39](https://github.com/SeveralHerr/godot-selftest-harness/issues/39)
(G-052, G-053) and [gh#40](https://github.com/SeveralHerr/godot-selftest-harness/issues/40)
(G-054); nothing is fixed there yet. G-054's flag was used in anger this cycle
(`launch --snapshot-userstate`) and worked exactly as documented.

## Waiting on the user

Nothing is blocking. Two standing decisions, unchanged:

- **The idea backlog is 32 cycles deep with no expressed preference between its entries.**
  The four you asked for by name are shipped or in flight; the rest is grown rather than
  requested, so which of it you actually want is a taste call the loop cannot make.
- **`kanban.md` is ~1900 lines and says at its own top that roughly half is stale.** The
  audit skill exists and gets used on whatever is in the way, never on the file as a whole.
  Running it end to end is a few cycles that produce no game, so it waits on your word.

One thing worth knowing rather than deciding: the pause card is now 440px wide for every
player, sized for a key almost nobody will bind. `plant-tower-defense-kbq` is filed to measure it instead. If a
wider card bothers you on sight, say so and it jumps.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`,
now checked by `python tools/mirror_check.py`) for the loop itself. Bump the number at the
top of this file every time you refill.
