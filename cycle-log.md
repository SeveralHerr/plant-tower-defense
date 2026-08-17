# Cycle 73

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 73 taught

**Eighteen frames.** A pest killed headless does free — the bead's worry was unfounded —
but it takes 18 process frames against the **2** that `UI_SETTLE_FRAMES` pumps. So any test
that kills a pest and reads the tree a frame or two later sees a corpse still there and
would reasonably call it a leak. Ten `.kill()` call sites sit in that window. The number,
not the verdict, is what got pinned.

Reading `Pest._play_death` produced the *wrong* expectation, which is the honest argument
for running it: whether a Tween interval elapses in a suite that "pumps no frames" is
exactly the kind of thing source is ambiguous about and a runner is not.

**And an enumeration was silently short again — a new way this time.** I counted sound call
sites with a `sed` substitution, which captures one match per line, and concluded `RUN_LOST`
was declared and never played. It is played, inside a ternary that also names `RUN_WON`.
Cycle 71's failure was the wrong *mechanism*; this was the right mechanism with a matcher
that steps over a second token on the same line. Both are now in `derive-the-list`: **before
trusting a census, ask what a member would look like that your matcher would step over.**

Re-run properly, the census produced the cycle's best finding anyway: **22 named sounds over
11 files**, and two pairs identical in file *and* volume — `PEST_ESCAPED` with
`PURCHASE_DENIED`, `PLANT_DESTROYED` with `CHOMP_BITE`. A lost life sounds exactly like a
refused purchase.

## Where things stand

A hundred and four beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **571/571**, 12546 assertions; lint 0/0; nine checkers clean. Twelve skills.
Upstream gh#44, gh#49, gh#50 open.

The workflow steps held this cycle — no change to `CLAUDE.md`. The lesson was a technique,
so it went into `derive-the-list` where techniques live.

## Waiting on the user

**`-oo7e` — weather has no counter-play.** Unchanged for many cycles.

**`-h5w6` — what should moving a plant cost?**

**`-ogxu` — should a budget floor keep a reserve?** Three HUD rows are at floor because each
was ratcheted down in the commit that spent it; every one was the right local move, and
together they made a HUD with no slack that nobody chose.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself. `-1fzh` (assert the sound table has no accidental twins) is deliberately
filed to be done *before* `-2r8g` (fix them), because the failing test is a better
specification of that work than its own description.

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
