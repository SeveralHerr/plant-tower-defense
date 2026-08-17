# Cycle 70

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 70 taught

**A bead whose acceptance names evidence a commit cannot produce will outlive its own
implementation.** `-6cqi` asked that two cobs at different upgrade levels be
distinguishable on the board "and a screenshot proves it". The code half shipped in the
cycle that filed it, twelve cycles ago, complete with a test enumerating every level pair.
The evidence half needed a running game and a rendered frame, so the bead sat in `bd ready`
looking exactly like work nobody had started. That rule is now in step 6.

**And the run that closed it was worth having.** The mutation I ran on the test I had just
written **survived**: it asserted `kernel_angle_offsets`, and breaking the `if` at the draw
site left it green — the test restated a function the arc did not depend on, and would have
passed on a build where every level drew an arc. `CornCobbler.spread_arc_span` exists
because of that survivor, and `_draw_muzzle_fan` now has no branch of its own: at level 1
the arc's two ends coincide and `draw_arc` draws nothing. That claim about an engine API was
verified on the running game, not assumed — three points on the circle a degenerate arc
would have traced read pure grass.

The measurement also found something not worth fixing blind: **a plant's `_draw()` renders
behind its own sprite**, because `_sprite` is a child. The same cob pip reads `#ffc500` at
one aim and leaf green at another. Enumerated for all five plants in `kanban.md`; three
draw a cue wholly inside the sprite's box and only one has been checked.

## Where things stand

Ninety-seven beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **568/568**, 12336 assertions; lint 0/0; nine checkers clean; findings 0/4.
Twelve skills. Upstream gh#44 open, **gh#49 newly filed** (`sample-pixels` can describe a
region but cannot assert a colour is in it — the only visual question the harness cannot
reach); gh#46 is closed and fixed at 0.47.0, which we do not run.

## Waiting on the user

**`-oo7e` — weather has no counter-play.** Unchanged for many cycles.

**`-h5w6` — what should moving a plant cost?**

**`-ogxu` — should a budget floor keep a reserve?** Three HUD rows are at floor because each
was ratcheted down in the commit that spent it; every one was the right local move, and
together they made a HUD with no slack that nobody chose.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself. The last two cycles were the message row and the plants' own drawing,
so step 2 says look elsewhere — `-e1u3` (idle motion, the user's own standing ask) is filed
and is deliberately outside.

**Seven standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI
findings baseline is **empty** (`-v9px`). Any harness operation should start by checking
which version the skill's paths point at. **Never hand-edit `AGENTS.md`** — run
`python tools/mirror_check.py --fix`. **`pause` right after `launch`**, but **unpause before
`findings`**, and **capture `scene-tree` before `quit`** or the ledger row loses its reach.
**Cut `kanban.md` by line number, never by heading.** And **never put backticks in a `bd`
description passed through bash** — they are command substitution and the word vanishes
silently, which is how `-e1u3` lost one.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **seven** couplings; `list-commands --offline`
answers "does this verb exist" with no game running. Live plant ids are catalogue ids —
`corn_cobbler`, not `corn` — and a plant is selected by a real click, which
`cmd touch_press`/`touch_release` at its `global_position` will deliver. Bump the number at
the top of this file every time you refill.
