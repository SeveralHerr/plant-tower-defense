# Cycle 86

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 86 taught

**A bitten plant flinches now** — the third word of the standing animation ask, after sway
and breathe. Every idle motion in the game was a continuous sinusoid, so nothing on the board
was ever startled: a bed being eaten looked exactly like one that was not, and the only tell
was a health bar the player has to already be looking at.

**Re-arming beat modelling a duration.** A hungry pest calls `take_damage` every physics
frame, so the flinch is re-armed rather than accumulated — a sustained shudder while eaten and
a decay afterwards, out of three lines and no state machine. That per-frame call was already
load-bearing for `_quiet_time` and for the bite sound's throttle; it did a third job for free.
**A per-frame trigger you already have beats a duration you have to model.**

**And the same seam bit for the second cycle running.** A mutation replacing the flinch term
at the draw site with `0.0` passes every headless test, because they assert the pure function
and not the rotation it feeds — precisely how cycle 85's coordinate bug shipped. Closed by
hand with numbers: sway alone holds the pivot within ±0.014 rad, a bite swings it to **+0.130**
and decays. `-a155` splits the cheap half out of `-6e2e`: **a property read beats a pixel probe
wherever the drawn thing is a transform**, and only `draw_*` canvas cues need sampling.

## Carried from cycle 85

A user's screenshot found what 587 tests could not: sole-cover rings drawing **72 px high**
because `cell_to_world` is board-local and `to_local` measures from the viewport. Enumerating
its callers found a second instance in the placement preview. **Nothing checks the board** —
`ui_layout` reads Control rects and every board cue is a `Node2D` draw call.

## Carried from cycle 84

Weather is drawn on the ground it applies to, after the top bar was found to have refused it
in cycle 17 **with the measurement attached**. A refusal with numbers is a design document,
and `verify-bd-item`'s `confirm` now searches the queue as well as the code.

## Where things stand

A hundred and twenty-seven beads ready. Still on harness **0.38.0** deliberately (`-ny3h`
blocked on gh#43). Suite **589/589**, 12790 assertions; lint 0/0; eleven checkers clean;
findings 0/4; FPS 122.3. Thirteen skills. Upstream gh#44, gh#49, gh#50 open.

**The user asked twice for player-facing work**, so `-6e2e` was claimed and released rather
than done — still the right P1, still earned, but it is tooling. Cycles 84, 85 and 86 all
shipped something a player sees.

**The workflow gained an intent line this cycle, written by the user**: keep it simple and
meaningful, reflect on game/tools/workflow/skills, and — asked for directly — **bias step 2
toward what a player would notice**. A cycle shipping nothing player-facing now owes a
sentence saying why. Step 5 spent its change on a DELETION, per the same instruction: the
step-0 parenthetical about a `STILL REAL` heading that never existed is gone.

## Waiting on the user

**`-oo7e` — weather has no counter-play.** `-t0vy` is the smaller question that does not
need it answered first: whatever weather does, the player should be able to see it doing it.

**`-h5w6` — what should moving a plant cost?**

**`-ogxu` — should a budget floor keep a reserve?** Three HUD rows are at floor because each
was ratcheted down in the commit that spent it; every one was the right local move, and
together they made a HUD with no slack that nobody chose.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself. `-orcl` is the half of the citation audit no tool can do — read the
landed lines once and record the rot rate. `-knpc` blocks `-1490` and `-lp97`; `-ip4n` blocks `-l86t`; `-0q3q` blocks `-ei83`;
`-9afm` is the fragility cycle 81 worked around rather than fixed; `-a155` is the cheap half of the board-check problem and the one to do first: read the
transform properties, no pixels. `-6e2e` keeps the expensive half, which is where cycle 85's
shipped bug actually lived. `-ki5h` follows
cycle 84: a drought is
distinguishable side by side, which is not the same as being noticed mid-wave. `-d3el`
still wants the reachable screens driven into the states that actually reflow. The cheapest real win on the board is `-0q3q`: hints and achievements share
one dictionary and have opposite triggers, which is what let cycle 79 burn a hint unseen.

**Nine standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI findings
baseline is **empty** (`-v9px`). Any harness operation should start by checking which version
the skill's paths point at. **Never hand-edit `AGENTS.md`** — run
`python tools/mirror_check.py --fix`. **`pause` right after `launch`**, but **unpause before `findings`** — except the pause card, which is a
paused state and settles fine because process frames still tick — and **capture `scene-tree` before `quit`** or the ledger row loses its reach.
**Run `run_json_check.py` BEFORE `verify_ledger record`.** **Cut `kanban.md` by line number,
never by heading.** **Write a `bd` description to a file and pass `--body-file`** — `-d "..."` goes through
the shell and backticks are command substitution. And
**`set-game-speed` takes its scale positionally**, not as `--scale`.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/citation_check.py` answers "do this file's citations still land, and how much of it
cites nothing"; `python tools/devtools.py cmd budgets` prices the **seven** couplings;
`list-commands --offline` answers "does this verb exist" with no game running. Live plant
ids are catalogue ids — `corn_cobbler`, not `corn`; **a Chomp must be unlocked before it
can be planted** (`set-state /root/Game/SeedBank unlocked` to a JSON array does it); and a
plant is selected by a real click, which `cmd touch_press`/`touch_release` at its
`global_position` will deliver. To walk a sub-second tween: `pause` **before** creating it,
then `step-time --seconds 0.03 --then-pause`; to verify a fix to a once-per-save behaviour,
`launch --snapshot-userstate` **before** clearing the flag, or the run writes the
developer's real save. Bump the number at the top of this file every
time you refill.
