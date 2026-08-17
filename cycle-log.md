# Cycle 34

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to pick the loop back up. **Never write a work checklist
here.** `bd ready` is the checklist.

## What cycle 34 taught

**A fix applied where it was found, rather than where it lives, leaves the defect in the
shared thing.** `OverlayScreen.add_row_label` — the helper two screens build every row
through — set `size` before `clip_text`, which is the exact ordering trap
`PauseScreen._build_key_list` documents at length having been bitten by. It was fixed at
that one call site. Measured, not assumed: size-first gives a **373px box for an assigned
140**; clip-first holds.

**And the pause card's reasoning was resting on a screen that was wrong.** Last cycle
allowed truncating a key name on the card because "the player can read it in full one
screen up". They could not: the Keys screen's `RowKey%d` sat in a hand-picked 140px column
and the longest name the engine produces measures 157px, so the one surface whose entire
job is saying which key a verb is on showed "On-screen keybo...". Both screens derive their
key column now — from **different sets, on purpose**: the card from the current bindings,
because it is rebuilt each time it opens; the Keys screen from every key the engine can
name, because it is the screen the player is editing on and a column that reflowed under
their hands mid-keystroke would be worse than one always wide enough.

**The structural one, and the reason step 6 changed.** Cycles 30–34 shipped one
player-facing change and eleven correctness or tooling ones. The cause is not taste: the
queue is refilled from what the last cycle's work exposed, and step 3's cite-a-`file:line`
rule — which is right, and has now caught four bad entries — makes citing easiest for the
file already open. So the loop keeps finding real work three feet from where it just stood.
Step 6 now requires one item per cycle from outside that neighbourhood.

Running that rule immediately paid: `kanban.md`'s "Grown straight from the brief" section
said "Not filed as beads yet — these are the ones worth building", and **all four entries
were already built**. A whole section reading as an open backlog that was a Done list.

## Where things stand

Eleven beads ready, none blocked. Suite 540/540 with 11988 assertions; lint 0/0; mirror
identical; `findings` clean; the real save's md5 unchanged. Eight skills, backlog empty.
Three harness gaps upstream ([gh#39](https://github.com/SeveralHerr/godot-selftest-harness/issues/39),
[gh#40](https://github.com/SeveralHerr/godot-selftest-harness/issues/40)) — G-054 behaved
this cycle: `--snapshot-userstate` restored on quit and the md5 came back identical, so the
earlier miss looks like a one-off rather than something systematic.

## Waiting on the user

Nothing is blocking, and one thing is worth your word now that it is measured rather than
suspected: **the loop has been improving its own correctness far faster than it has been
adding to the game.** Five cycles, one player-facing change. Everything shipped was real —
the suite was overwriting your save, two screens were truncating text, a backlog section
was fiction — but none of it is something you would notice while playing.

Step 6's new rule pushes against that from inside, and the first item it produced is
`plant-tower-defense-q3lx` (weather rounds: a rain wave that heals, a drought wave that
halves fire rate near water). If you would rather the loop spent its cycles on features and
let the correctness work queue up, say so and it will.

`kanban.md` is ~1930 lines and still says at its own top that roughly half is stale. One
section is now audited end to end; it was 100% stale.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`,
checked by `python tools/mirror_check.py`) for the loop itself. Bump the number at the top
of this file every time you refill.
