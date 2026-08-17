# Cycle 80

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 80 taught

**A live check against persisted state can return a real answer to the wrong question.**
Verifying that a first-ever uproot no longer burns the move-tip one-shot, I armed one and
read the milestone: `true` before, `true` after. Not a fix and not a bug — the developer's
own save had earned that flag in some earlier cycle, so the check could not distinguish
anything and read exactly like a pass. **Assert the precondition before driving a
one-shot**; that is now step 3b of `read-a-moving-value`.

The fix was `--snapshot-userstate`, used for the first time in eighty cycles: relaunch,
clear `earned_milestones` in the running game, drive both paths, and `quit` reports
`userstate: restored 1 file(s)`. Without it the run would have left the developer's save
cleared, which the harness warns shows up later as unrelated headless failures.

**And `suite_reach_check` paid for itself on a two-line function.** The new
`Hud.uproot_shows_tip` was exercised through `arm_uproot` and named by no test, which the
checker flagged as NEW. Naming it directly turned one behavioural example into all four
combinations of a two-input predicate — and three of the four say no, so the example had
been proving almost nothing.

## Carried from cycle 79

A budget refusal changed the FEATURE rather than the number: the armed-uproot prompt's tip
and its new forfeit clause measured 1064 px against an 876 px row, so they are mutually
exclusive and the one about money wins. `Game.BUDGET_FLOOR` was not touched.

## Carried from cycle 78

An exception in a grammar is often a missing row: the Chomp's chew ring stopped being an
exception by becoming the second instance of *partial arc = time remaining*, the first
being a husk's rot timer that the original census had excluded. And a check that could not
run is recorded `blocked` — `verify_ledger` downgrades the row `pass → partial` on its own,
which is a better headline than a pass with a footnote.

## Where things stand

A hundred and fourteen beads ready. Still on harness **0.38.0** deliberately (`-ny3h`
blocked on gh#43). Suite **576/576**, 12596 assertions; lint 0/0; eleven checkers clean;
findings 0/4; reach 2/2. Thirteen skills. Upstream gh#44, gh#49, gh#50 open.

No workflow change this cycle — the steps held. The lesson was a technique and went into
`read-a-moving-value` as step 3b.

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
landed lines once and record the rot rate. `-knpc` blocks `-1490` and `-lp97`; `-ip4n` blocks `-l86t`; `-0q3q`
blocks `-ei83`. The cheapest real win on the board is `-0q3q`: hints and achievements share
one dictionary and have opposite triggers, which is what let cycle 79 burn a hint unseen.

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
then `step-time --seconds 0.03 --then-pause`; to verify a fix to a once-per-save behaviour,
`launch --snapshot-userstate` **before** clearing the flag, or the run writes the
developer's real save. Bump the number at the top of this file every
time you refill.
