# Cycle 74

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 74 taught

**Writing the derived check before the fix found five collisions where a hand-read had
found two.** The two beads were filed split and ordered on purpose last cycle — gate first,
fix second, because a failing test naming the collisions is a better specification than a
description is. It named `PLANT_UPGRADED`/`WAVE_STARTED` after the first two were fixed, and
re-deriving every `(file, volume, pitch)` triple at once turned up two more. My hand-read
had enumerated all ten shared files correctly and then compared volumes for only a *sample*
of them — the third distinct way a census of mine has come up short in five cycles.

**Volume alone would have answered the wrong question.** A quieter version of a sound is the
same event, smaller — which is exactly what `WAVE_CLEARED` means by wearing `RUN_WON`'s
jingle at −9.0, and exactly not what an escape means beside a refused purchase. So `PITCH`
is a third axis with a direction: **losses go lower, gains go higher, the routine half of a
pair keeps the base.**

**And the mutation that mattered survived the first version.** Deleting the pitch line from
`play()` left `PITCH` perfectly unique and the player hearing twins — the table check
asserts the tables, not that anything reads them. `play()` is gated off headless, so nothing
in the suite could see it. That is the second time in three cycles the fix was to move the
assertion to a **seam** rather than strengthen it in place, so
`.claude/skills/extract-a-testable-seam/` is now built rather than noticed a third time.

## Where things stand

A hundred and two beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **573/573**, 12551 assertions; lint 0/0; nine checkers clean; findings 0/4.
**Thirteen skills.** Upstream gh#44, gh#49, gh#50 open.

The workflow steps held — no `CLAUDE.md` change. The lesson was a technique and became a
skill, which is what the workflow already says to do with those.

## Waiting on the user

**`-oo7e` — weather has no counter-play.** Unchanged for many cycles.

**`-h5w6` — what should moving a plant cost?**

**`-ogxu` — should a budget floor keep a reserve?** Three HUD rows are at floor because each
was ratcheted down in the commit that spent it; every one was the right local move, and
together they made a HUD with no slack that nobody chose.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself. `-1490` blocks `-u9uh` deliberately: the options panel is exactly full
(three rows, 48 px of gap, and a fourth row leaves 0 against a `FOOTER_GAP` of 24), so
"add a volume control" is a panel-geometry decision before it is an audio one — and the
milestone shelf taught this project that choosing the way out while holding a feature is the
expensive order.

**Eight standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI
findings baseline is **empty** (`-v9px`). Any harness operation should start by checking
which version the skill's paths point at. **Never hand-edit `AGENTS.md`** — run
`python tools/mirror_check.py --fix`. **`pause` right after `launch`**, but **unpause before
`findings`**, and **capture `scene-tree` before `quit`** or the ledger row loses its reach.
**Cut `kanban.md` by line number, never by heading.** **Never put backticks in a `bd`
description passed through bash** — command substitution eats the word silently. And
**`set-game-speed` takes its scale positionally**, not as `--scale`.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **seven** couplings; `list-commands --offline`
answers "does this verb exist" with no game running. Live plant ids are catalogue ids —
`corn_cobbler`, not `corn` — and a plant is selected by a real click, which
`cmd touch_press`/`touch_release` at its `global_position` will deliver. To walk a
sub-second tween: `pause` **before** creating it, then `step-time --seconds 0.03
--then-pause` (see `read-a-moving-value`). Bump the number at the top of this file every
time you refill.
