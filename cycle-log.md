# Cycle 72

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 72 taught

**A technique that works one time in four teaches you it works.** Cycle 71 caught a 0.15 s
tween on its third poll and concluded polling was viable-ish. Run cleanly this cycle, four
consecutive reads straight after firing `CornCobbler._recoil` all return `Vector2.ONE` —
four well-formed answers, every one the landed value, **which is exactly what a tween that
never ran looks like**. Polling a sub-second tween does not fail loudly; it returns a
plausible number.

`step-time --then-pause` walks it deterministically: 0.920 → 0.900 → 0.940 → 0.980, two
independent runs agreeing to six decimals. The non-obvious part is the first line — **pause
before creating the tween**, because `--then-pause` lifts a pre-existing pause for its own
step and re-freezes after, so a tween born frozen advances only by the steps you ask for.
It works on tweens at all because `_cmd_step_time` waits on the process clock as well as the
physics one. All of that is now in `read-a-moving-value` with both output blocks.

**And the bead's premise was wrong**, in the way that has now happened three cycles running:
I filed it claiming the verb had never been used, and `log-devtools.md:3378` records it. So
step 6 gained the rule that step 3's citation discipline applies to bead descriptions too —
that is where a claim gets acted on, cycles later, by someone who trusts it because it looks
like a finding.

## Where things stand

A hundred and two beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite 570/570, 12543 assertions as of cycle 71; this cycle changed no game code.
Twelve skills. Upstream gh#44, gh#49 and **gh#50** open — the last is new: Phase 0.5's
triage table classifies a run by its diff, and an experiment inverts that, because the diff
is the run's *output*. Following it literally this cycle would have logged a session that
answered a real question as `overkill — avoided`.

## Waiting on the user

**`-oo7e` — weather has no counter-play.** Unchanged for many cycles.

**`-h5w6` — what should moving a plant cost?**

**`-ogxu` — should a budget floor keep a reserve?** Three HUD rows are at floor because each
was ratcheted down in the commit that spent it; every one was the right local move, and
together they made a HUD with no slack that nobody chose.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself. The last four cycles were the message row, plant drawing, plant
animation and tooling — `-hnhn` (audit the rest of the user's own requested-features list)
and `-35mu` (the waves-and-bosses entry, drifted on both halves) are the two filed items
furthest from all of it.

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
`cmd touch_press`/`touch_release` at its `global_position` will deliver. Bump the number at
the top of this file every time you refill.
