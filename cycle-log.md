# Cycle 67

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 67 taught

**`cmd budgets` now ends "3 of 7 at floor (husk_click, hud_readouts, hud_stats_row)".**
Cycle 66 worked that out by comparing seven headrooms against seven floors by hand, which
is why fourteen cycles passed without anyone noticing three rows of the HUD had run out.
The verb printed every number and not the one arithmetic step between them and the question
anyone actually has.

The distinction is why it needed its own function: **`tight` is a fraction of a budget's
own ceiling** — `hud_message_row` reports tight at 121 px while holding 81 px above its
floor — **`at floor` is resting on the declared floor**, and **`under floor` is through
it**, which `budget_regressions()` already owns and which is excluded here rather than
counted twice.

**Reading the live verb caught what the arithmetic was happy with.** The first version said
*4* of 7, including `pest_road_ceiling` — floor `0.0`, headroom 0, resting there by
construction. It qualified honestly and could never be anything else, so every future
reading would carry one permanent entry while burying the three that are at floor because
somebody *spent* them. The headline already counts `spent_by_design` separately, so it was
reporting one budget twice. No staged test fixture would have shown that: the offending
floor is a real declared `0.0`.

**And a surviving mutation was a real gap, not dead code.** Removing the `computed` guard
changed nothing, because the test never staged an unmeasured budget —
`budget_regressions()` calls that "a hole in the check, not a pass", so counting it
at-floor would report the HUD as fuller than anyone has established.

## Where things stand

Eighty-nine beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **564/564**, 12299 assertions; lint 0/0; nine checkers clean; `findings` 0
across 4 of 5 unpaused. Eleven skills. Upstream gh#44 and gh#46 open.

## Waiting on the user

**`-oo7e` — weather has no counter-play.** Unchanged for many cycles.

**`-h5w6` — what should moving a plant cost?** The preview shows a player exactly what
repositioning would do, and the game then charges full price to act on it.

A third is now worth your eye, though it is not blocking: **`-ogxu` — should a budget floor
keep a reserve?** Three HUD rows are at floor because each was ratcheted down in the commit
that spent it. Every one of those was the correct local move, and they add up to a HUD with
no slack that nobody chose.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself. Step 2 says take work away from the last two cycles' subsystem — those
were budgets and pest escape.

**Six standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI findings
baseline is **empty** (`-v9px`). Any harness operation should start by checking which
version the skill's paths point at. **Never hand-edit `AGENTS.md`** — run
`python tools/mirror_check.py --fix`. **`pause` right after `launch`**, but **unpause before
`findings`**. And **cut `kanban.md` by line number, never by heading**.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **seven** couplings and now says how many are at
floor; `list-commands --offline` answers "does this verb exist" with no game running. Bump
the number at the top of this file every time you refill.
