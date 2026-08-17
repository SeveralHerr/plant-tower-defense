# Cycle 69

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 69 taught

**A question with two halves can have two different answers, and stopping at the first one
would have closed the bead wrongly.** `-z6l7` asked whether the message queue may defer an
important message at all. It may never defer one behind an *ambient* line — `show_message`
pre-empts outright on higher priority, and two tests already pinned that, so "never, by
construction" is the honest answer to the question as asked. It may defer one behind
another *important* line, for up to `5.0 - MESSAGE_MIN_READABLE` = 3.8 seconds. The
armed-uproot prompt's whole window is 4.0. So the sentence telling the player they have
four seconds could arrive with 0.2 of them left, behind a packet reveal.

`MESSAGE_DEADLINE` is a third rung and its comment is careful about what it means: not
*more important*, but *expires*. Deferring a line whose subject is already counting down
elsewhere does not postpone the message, it shortens it.

**The runtime pass earned its launch on something the headless test could not touch.**
`arm_uproot` returned `nothing is selected` live, because the test sets `selected_placed`
by planting and a player sets it by clicking. Driving the real click through touch
emulation is what proved the path reachable.

**And the second test is a table, not a third example** — all nine ordered pairs of rungs,
driven off the constants. The pair that mattered was a combination no existing test named.
That is cycle 68's rule applied to tests instead of prose.

## Where things stand

Ninety-four beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **567/567**, 12330 assertions; lint 0/0; nine checkers clean; findings 0/4.
Eleven skills. Upstream gh#44 open; **gh#46 is CLOSED and fixed at 0.47.0** — we still hit
it because of the pin, which is why `-knzv` is now P1.

The workflow gained one rule: **the reach snapshot is due before `quit`, not before the
commit.** This cycle quit the game and then had to relaunch and re-drive the whole scenario
to record a ledger row it had already earned.

## Waiting on the user

**`-oo7e` — weather has no counter-play.** Unchanged for many cycles.

**`-h5w6` — what should moving a plant cost?**

**`-ogxu` — should a budget floor keep a reserve?** Three HUD rows are at floor because each
was ratcheted down in the commit that spent it; every one was the right local move, and
together they made a HUD with no slack that nobody chose.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself. Step 2 says take work away from the last two cycles' subsystem — those
were drawn overlays and the message row.

**Six standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI findings
baseline is **empty** (`-v9px`). Any harness operation should start by checking which
version the skill's paths point at. **Never hand-edit `AGENTS.md`** — run
`python tools/mirror_check.py --fix`. **`pause` right after `launch`**, but **unpause before
`findings`**. And **cut `kanban.md` by line number, never by heading**.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **seven** couplings and says how many are at
floor; `list-commands --offline` answers "does this verb exist" with no game running. The
live game's plant ids are catalogue ids — `corn_cobbler`, not `corn`. Bump the number at
the top of this file every time you refill.
