# Cycle 87

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 87 taught

**"Unobservable" was a claim about the medium, not about the pipeline.** A hard-won kill now
sounds like one — `PEST_KILLED_HARD`, the same impact pitched 1.12 at −1.5 dB, routed by the
pest's own `husk_multiplier()` so a fourth mutation is audible the day it is added. I nearly
skipped the runtime pass on the reasoning that a muted session cannot verify a sound.

It can. The voice pool is **real nodes** under `/root/SfxPool`, so the whole path reads back:
a 3.0× pest tuned `Voice0` to `pitch_scale 1.12` at `-1.5 dB`, exactly the table row. And the
plain kill afterwards **reused `Voice0`** and retuned it to 1.0 at −3.0 — the pooled-voice
staleness hazard `tune_voice` writes unconditionally to prevent, argued in cycle 74 and never
once watched until now. **Don't ask whether you can perceive the effect; ask what the last
readable value before it is.**

**And the seam pattern has four instances, so it stopped being a lesson.** `spread_arc_span`,
`uproot_shows_tip`, `tune_voice` and now `kill_event_for` all exist because a mutation
survived a test that asserted the *inputs* to a decision rather than the decision. Three were
earned the expensive way; this one was taken after a single survival. `-jmxb` rewrites the
skill to lead with the pre-emptive question — **before writing a ternary at a call site, ask
whether a test could name the thing that decides.**

## Carried from cycle 86

A bitten plant flinches — the third word of the animation ask. **A per-frame trigger you
already have beats a duration you have to model**: `take_damage` is called every physics
frame by an eating pest, so re-arming gives a sustained shudder and a decay in three lines.

## Carried from cycle 85

A user's screenshot found what 587 tests could not: cues drawing **72 px high** because
`cell_to_world` is board-local and `to_local` measures from the viewport. **Nothing checks
the board** — `ui_layout` reads Control rects and every board cue is a `Node2D` draw call.

## Where things stand

A hundred and twenty-nine beads ready. Still on harness **0.38.0** deliberately (`-ny3h`
blocked on gh#43). Suite **591/591**, 12809 assertions; lint 0/0; eleven checkers clean;
findings 0/4. Thirteen skills. Upstream gh#44, gh#49, gh#50 open.

**The player-facing steer is standing.** Cycles 84-87 all shipped something a player sees:
weather on the ground, a coordinate fix a player reported, a flinch, a harder kill sound.
`-6e2e` and `-a155` are the board-check P1s, both released rather than done.

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
