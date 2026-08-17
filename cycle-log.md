# Cycle 84

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 84 taught

**The refusal held the answer.** I claimed a bead asking for a standing weather readout,
checked the code, found none — and found mid-cycle that the identical request had been filed
in **cycle 17** (`-saaw`), measured, and refused. Its notes carry every candidate string's
width against the 312 px wave slot: `"  rain"` 366, `"  dry"` 357, a bare `"*"` 317, and a
widened slot putting `hud_stats_row` 35 px over budget. My own `-t0vy` was a duplicate; I had
verified only that the code lacked the feature, never that the queue already held the
question **and its answer**.

Every candidate failing by 5-54 px is not a tuning problem. It is the bar saying weather does
not belong to it — so weather went on **the board**, which is the surface it is actually
about and the one with room. Photographed clear, drought and rain in one region: saturated
green, duller with flat dashes, cooler with slanted streaks. Two channels, shape before hue.

`verify-bd-item`'s `confirm` step now says to **search the queue as well as the code**: the
code tells you a feature is absent, only the queue tells you whether that absence is an
oversight or a decision.

## Carried from cycle 83

Every screen is reachable now — five named `entry_points` — and all four overlay screens
were clean on their first-ever runtime pass. They are also **static**, which is the case a
layout checker finds least, so that is evidence the checks work rather than that the game is
checked.

## Carried from cycle 82

`reach` refused a verdict impression would have given: a clean pass across five checks with
`reached 0/4 changed file(s)`, because nothing navigates. Three of four row-limited surfaces
are exactly full — the fourth being the only one that already *computed* its ceiling.

## Where things stand

A hundred and twenty-five beads ready. Still on harness **0.38.0** deliberately (`-ny3h`
blocked on gh#43). Suite **586/586**, 12758 assertions; lint 0/0; eleven checkers clean;
findings 0/4. Thirteen skills. Upstream gh#44, gh#49, gh#50 open.

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
`-9afm` is the fragility cycle 81 worked around rather than fixed; `-ki5h` is the follow-up to this cycle: a drought is
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
