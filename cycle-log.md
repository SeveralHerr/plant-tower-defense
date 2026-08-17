# Cycle 83

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 83 taught

**Three overlay screens had never been looked at by a runtime check, in 83 cycles, and all
three are clean.** They are reachable now — five named `entry_points` instead of one, each
carrying `scene` because the entry hook navigates to the board before anything can ask for
the title's overlays. The notebook, the key screen, the options panel and the pause card
each report 0 findings across `ui_layout`, `ui_reachable`, `signal_unconnected` and
`performance`.

That is a result and it bounds itself: **those screens are static.** They build once from
constants and nothing reflows on them, which is the case a layout checker finds least. The
clean sweep is evidence the checks work, not evidence the game is checked — `-d3el` files
the follow-up, which is to drive them into their *moving* states.

**Entry points do not compose, and the verb reports success anyway.** Firing `keys` while
the notebook is open does nothing: `_open_keys` returns early on `overlay_open()`, so the
method was called and did return. Caught by `first-frame` naming the same topmost Control
three times, not by any error.

**And the third eaten word settled a two-cycle argument with myself.** A standing note told
me not to put backticks in a `bd` description; I did it in cycles 76, 78 and now 83. A note
ignored three times is the wrong countermeasure — `bd create --body-file PATH` exists, and a
file written with an editor tool never touches a shell.

## Carried from cycle 82

`reach` refused a verdict impression would have given: a clean pass across five checks with
`reached 0/4 changed file(s)`, because nothing navigates. And three of four row-limited
surfaces are exactly full — the fourth being the only one that already *computed* its
ceiling.

## Carried from cycle 81

A bead's "check this before building" instruction turned a design around: armoured+winged
is **redundant, not lethal**. And when a seeded simulation changes, consume the draws
without applying the effect — that separates a moved stream from a moved behaviour.

## Where things stand

A hundred and twenty-three beads ready. Still on harness **0.38.0** deliberately (`-ny3h`
blocked on gh#43). Suite **583/583**, 12656 assertions; lint 0/0; eleven checkers clean;
findings 0 on all four overlay screens. Thirteen skills. Upstream gh#44, gh#49, gh#50 open.

Step 5's one change is in step 6: **write a bead description to a file and pass
`--body-file`**, never `-d "..."`. Three words have been eaten by shell backticks this
session, every time after a note told me not to.

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
`-9afm` is the fragility cycle 81 worked around rather than fixed; `-d3el` is the follow-up to this cycle: the screens are
reachable now, so drive them into the states that actually reflow. The cheapest real win on the board is `-0q3q`: hints and achievements share
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
