# Cycle 66

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 66 taught

**I claimed a bead built on a claim I had written, and the claim was false.** Cycle 65's
kanban entry said "death has a sound, a corpse and a linger; escape has none of the three".
Every part of the escape half is wrong: `Sfx.PEST_ESCAPED` plays (`game.gd:911`),
`_note_lane_loss` tints the exit cell (`:910`), and `_punch_readout(_lives_label)` fires on
the changed count (`hud.gd:1072-1073`).

The entry followed the cycle-31 rule to the letter — it cited a `file:line`. For the half I
checked. **One citation makes a whole entry read as sourced**, and the side asserted to be
empty is precisely the one that needed opening. That is now a rule of its own: an entry
that compares two things needs a citation for both halves.

The entry was corrected in place rather than deleted, because the mistake is the useful
part.

**And the budgets, unread since cycle 52, came back as seven rather than five** — the
standing note in this file was stale again. Zero regressions, but **three sit exactly at
their declared floor**: `husk_click` 4 of 32, `hud_readouts` 10 of 171, `hud_stats_row` 19
of 1112. The floors ratchet down to the measurement on purpose, so that is the system
working — and it means the HUD has no room on three rows out of four. The only slack is
`hud_message_row`, 121 against a floor of 40, and cycle 61 spent 185 px of it.

**One evidence string read two ways.** `hud_readouts` said "over each live readout", which
parses as measuring the *current* text — a budget that passes because the counter happens
to say "Seeds 25". It sweeps `WORST_CASE_TEXT` against the live slot. I misread my own
project's string before opening the line.

## Where things stand

Eighty-seven beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **563/563**, 12287 assertions; lint 0/0; `findings` 0 across 4 of 5, run
unpaused per cycle 65's rule. Eleven skills. Upstream gh#44 and gh#46 open.

**Seven budgets, not five.** `husk_click`, `hud_readouts`, `hud_message_row`,
`hud_stats_row`, `pest_road_ceiling`, `notebook_subhead`, `road_shape`.

## Waiting on the user

**`-oo7e` — weather has no counter-play.** Unchanged for many cycles.

**`-h5w6` — what should moving a plant cost?** The preview shows a player exactly what
repositioning would do, and the game then charges full price to act on it.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself. Step 2 says take work away from the last two cycles' subsystem — those
were pest death and pest escape, so pick something else.

**Six standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI findings
baseline is **empty** (`-v9px`). Any harness operation should start by checking which
version the skill's paths point at. **Never hand-edit `AGENTS.md`** — run
`python tools/mirror_check.py --fix`. **`pause` right after `launch`**, but **unpause before
`findings`**. And **cut `kanban.md` by line number, never by heading**.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **seven** couplings and three of them are at
their floor; `list-commands --offline` answers "does this verb exist" with no game running.
Bump the number at the top of this file every time you refill.
