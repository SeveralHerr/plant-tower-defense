# Cycle 77

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 77 taught

**The denominator was the finding.** `tools/citation_check.py` — the six-line script that
had been retyped in seven separate cycles — resolves all 175 citations in `kanban.md` and
reports zero problems. That reads as a clean file and is a statement about **74 of its 323
entries**. The other 249 make claims about the code with no coordinates at all, and are
invisible to this checker, to every other checker, and to anything that could be automated.
The tool was one line away from shipping without saying so.

**Three further findings, and only one came from the exit code.**
- Reading the *landed lines* instead: `kanban.md` cited `game/plant.gd:172` as
  `add_child(_sprite)` — true when cycle 70 wrote it, and cycle 71's `Sway` pivot pushed it
  34 lines down. It still resolves, onto a health-bar comment. **Resolution is mechanical;
  support is not**, and the tool says so in its own `NOT COVERED`.
- The continuation shorthand this file invented — `` (`game/sfx.gd:86`, `:91`) `` — was
  invisible to its own audit: 44 of them, a third again on top of the 130 first counted.
  Teaching the checker to bind them found a bare `:331` in a sentence whose nearest
  preceding citation was a 183-line file. No reader would catch that; the prose names the
  right file twice.
- Two bugs in the tool, both from **using it rather than reading it**. Mutating one branch
  made the next line traceback instead of exiting 2. And running it *without* `--quiet` —
  the mode that prints source, and therefore the mode the first three runs never used —
  died on an em-dash. `house-static-checker` now opens with: run it once in the mode you do
  not intend to use.

## Where things stand

A hundred and four beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked
on gh#43). Suite 573/573, 12551 assertions; **eleven** checkers clean. Thirteen skills.
Upstream gh#44, gh#49, gh#50 open.

Step 5's one change: the continuation-binding rule now sits beside the citation rule in
step 3, because a shorthand a document invents for itself is a shorthand no tool knows.

## Waiting on the user

**`-oo7e` — weather has no counter-play.** Unchanged for many cycles. `-t0vy` is the
smaller question that does not need it answered first: whatever weather does, the player
should be able to see it doing it.

**`-h5w6` — what should moving a plant cost?**

**`-ogxu` — should a budget floor keep a reserve?** Three HUD rows are at floor because each
was ratcheted down in the commit that spent it; every one was the right local move, and
together they made a HUD with no slack that nobody chose.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself. `-orcl` is the half of the citation audit no tool can do — read all
182 landed lines once and record the rot rate, which is the only evidence anyone will ever
have about how fast citations here go stale. `-knpc` still blocks `-1490` and `-lp97`.

**Nine standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI findings
baseline is **empty** (`-v9px`). Any harness operation should start by checking which version
the skill's paths point at. **Never hand-edit `AGENTS.md`** — run
`python tools/mirror_check.py --fix`. **`pause` right after `launch`**, but **unpause before
`findings`**, and **capture `scene-tree` before `quit`** or the ledger row loses its reach.
**Run `run_json_check.py` BEFORE `verify_ledger record`.** **Cut `kanban.md` by line number,
never by heading.** **Never put backticks in a `bd` description passed through bash.** And
**`set-game-speed` takes its scale positionally**, not as `--scale`.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/citation_check.py` answers "do this file's citations still land, and how much of it
cites nothing"; `python tools/devtools.py cmd budgets` prices the **seven** couplings;
`list-commands --offline` answers "does this verb exist" with no game running. Live plant
ids are catalogue ids — `corn_cobbler`, not `corn` — and a plant is selected by a real
click, which `cmd touch_press`/`touch_release` at its `global_position` will deliver. To
walk a sub-second tween: `pause` **before** creating it, then `step-time --seconds 0.03
--then-pause`. Bump the number at the top of this file every time you refill.
