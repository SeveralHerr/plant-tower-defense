# Cycle 79

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 79 taught

**A budget refusal changed the feature instead of the number, and that is the system
working rather than failing.** Adding a "your upgrades are not refunded" clause to the
armed-uproot prompt looked free — `hud_message_row` was the one HUD budget with real slack.
`check_budgets` refused the build at **1064 px against an 876 px row**, 188 px over, and
named the exact worst-case string: the move tip and the forfeit clause together on the
longest plant name. So the two extras are mutually exclusive and the one about money wins.
`Game.BUDGET_FLOOR` was not touched — which is the whole point of `-ogxu`'s open question,
answered once in practice.

**Writing the kanban entry found a bug the tests did not.** The move tip fires on the first
arm ever and records its milestone in the same breath; the forfeit clause now displaces it.
A player whose first uproot is on an upgraded cob never sees the tip and the milestone is
spent anyway — and that is the *likely* case, since uprooting something cheap is not a
decision worth a prompt. Filed as `-np1d`. The entry was written to describe a design
constraint and turned into a defect report halfway through.

**And a `ui_layout` finding appeared that the workflow's existing warning did not cover.**
It fires on a *paused* tree, per cycles 60 and 65; this one was unpaused, immediately after
a row text change. Relaunch, settle 90 frames, re-run — zero; re-trigger, settle, re-run —
zero. Step 2 now says to do that rather than to guess, because the UI baseline is empty and
**the re-run is the baseline**.

## Carried from cycle 78

An exception in a grammar is often a missing row: the Chomp's chew ring stopped being an
exception by becoming the second instance of *partial arc = time remaining*, the first
being a husk's rot timer that the original census had excluded. And a check that could not
run is recorded `blocked` — `verify_ledger` downgrades the row `pass → partial` on its own,
which is a better headline than a pass with a footnote.

## Where things stand

A hundred and eleven beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked
on gh#43). Suite **575/575**, 12583 assertions; lint 0/0; eleven checkers clean; findings
0/4 after settling. Thirteen skills. Upstream gh#44, gh#49, gh#50 open.

Step 5's one change is in step 2: when a `ui_layout` finding appears, settle and re-run
before believing it *and* before dismissing it — zero twice is a transient, the same finding
twice is real.

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
landed lines once and record the rot rate. `-knpc` blocks `-1490` and `-lp97`. `-ip4n`
blocks `-l86t`: photograph a chew mid-sweep, then ask whether 0.45 s is long enough for a
readout to say anything at all.

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
ids are catalogue ids — `corn_cobbler`, not `corn`; **a Chomp must be unlocked before it
can be planted** (`set-state /root/Game/SeedBank unlocked` to a JSON array does it); and a
plant is selected by a real click, which `cmd touch_press`/`touch_release` at its
`global_position` will deliver. To walk a sub-second tween: `pause` **before** creating it,
then `step-time --seconds 0.03 --then-pause`. Bump the number at the top of this file every
time you refill.
