# Cycle 106

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 106 taught

**A screenshot from James beat every gate this project owns.** The playfield sat hard left
on a wide window with all the extra canvas in one grey gutter, while `findings`, lint, 741
tests and 16 checkers were green over it — because every one of them measures the design
size, and every test hosts the board at the origin. The cheapest detector in the toolkit is
still a person looking at the game.

**Two bugs were stacked and fixing the first exposed the second.** Before cycle 105 the side
panel sat at a hardcoded `1152 - PANEL_WIDTH` and the board at `x = 0`. Both were wrong and
they hid each other, because the panel's error happened to sit exactly where the board's
gutter would have been. Agreeing at the design size is not evidence of anything.

**Then moving the board exposed a third.** `_click_at` compared an absolute `screen_pos.x`
against a board-LOCAL width — correct for exactly as long as the board started at x=0. A
centred board silently ate every click on its rightmost 117px **while drawing them
perfectly**. No picture of that can ever be wrong; it was found by reading the guard.

**The same shape, one screen over.** `PauseScreen`'s Backdrop is `MOUSE_FILTER_STOP`
precisely so the board cannot be played through a pause — and at 1152 on a 1548 canvas it
stopped 396px short, leaving live clickable board over a held run. A correctness bug wearing
a layout bug's clothes.

**"Three copies" was eight.** The count was the finding: one name was answering two
different questions — how big is the screen I must cover, and how big is the canvas this was
composed on — and half the callers are `static` on purpose, so `ProjectSettings` was the
only implementation that could serve them. At 16:9 the two answers are identical, which is
why it drifted invisibly for so long.

**A boss that the targeting rule refuses to shoot.** Every damaging plant fires at the pest
furthest along the road; the Nurse Beetle walks behind the front and heals everything near
her. The Queen asks *where do I want it to die*; the Nurse asks *does my garden own anything
that can hit the back of a wave*. It cost 48 points of beetle and displaced nothing — the
finale is byte-for-byte the row it has been for four species running.

**Closes are honest now; clause-by-clause answers still are not.** 40 of 146 closed beads
carry the literal reason `'Closed'` — all under the old id scheme, all unauditable, since
the evidence was never written. Under the current scheme it is **97 of 97 with a real
reason**. But a real reason is necessary and not sufficient: `-1d07` has a good close that
leaves one acceptance clause unanswered and another only partly. The prototype gate flagged
122 of 146, which is a permanently-red gate and therefore no gate at all — so the answer is
`-txme`, making the close *start* from the acceptance rather than adding another instruction.

## What cycle 105 taught

**The eighth plant, and the file that had already written down how to fit it.** The Salve
Aloe is the first thing in the game that undoes damage — before it, `Plant.health` only
ever fell, and the sole exception was the rain, which is the weather's doing and arrives
every fifth wave whether you need it or not. It cannot save a plant under attack and that
ceiling is the design: 3.0 HP/s against a mouth taking a full-health plant down in 2.86s.
Verified live at 10.0 → 20.4 → 35.4 health.

**`-ibvb` names four hand-lists a new plant must join. There are five.** The fifth is
`TitleScreen.PLANT_X`, caught as `Expected 7 >= 8` — and its own header had already done the
arithmetic and named the fix in advance: *"That is the day to drop PLANT_SCALE or go to two
rows."* Dropped 1.7 → 1.5, which fits four 96px canvases per band with 42px spare and funds
the ninth plant too. A comment that predicts its own failure is worth more than a test that
reports it, because it also says what to do.

**Read the denominator, again, and this time it was mine.** My first Aloe tests used
`GAME_SCENE`, which `test_combat.gd` does not declare. The parse error took the whole script
down and the suite reported **`Total: 564` against 705** — 141 tests silently absent, exit
2. The exit code alone would have read as an ordinary failure.

**Two tests failed at the audio merge and neither was wrong** — both had had their subject
moved underneath them. A save fixture pinned to `SAVE_VERSION` rather than to the version
whose *shape* it tests goes stale on every bump, and the failure it produces points at the
parser instead of at itself. And the exactly-full tripwire counted `OPTIONS.size()` alone,
so it measured three rows on a panel that now shows five: a tripwire counting the wrong set
reads as "still full" while the surface fills up past it.

**`set_resolution` answered what no headless test in this project can.** Lane 0jye said so
plainly and handed it over as a named check rather than claiming it. Three resizes settled
it: a 1720×720 window gives a 1548-wide canvas with the side panel at x 1292 (1292 + 256 =
1548, still pinned), and 1024×768 gives 1152×792 — the width floor the whole stats-row
budget silently rests on, confirmed rather than reasoned about.

## What cycle 104 taught

**The merge found a bug in a fix I had already called done.** Cycle 102 stopped
`citation_check` walking into `.claude/worktrees/` by testing `"worktrees" in path.parts` —
an ABSOLUTE path. Run from inside a lane, whose own path *is* `.claude/worktrees/…`, that
discards the entire repo: the parent read `298 resolved`, a lane read `260` and 38 bogus
advisories. Same asymmetry as the original defect, pointing the other way, and **invisible
from whichever side you happen to be standing on**. Only running the fan-out produces both
viewpoints at once. Exclusions are now relative to the tool's own root, in `repo_walk.py`,
imported rather than copied — and the sweep that found it enumerated every tree-walking
tool instead of fixing the one that complained.

**Read the denominator, not the verdict.** `check_all` exited 0 on every run through that
entire defect. The only thing that ever moved was `19 world-space script(s)` → `38` and
`298 resolved` → `260`. Filed `-G-123`: a `--compare-to` mode would make "run it twice
under different conditions and diff the numbers" a standing check rather than something
done by hand.

**Two tests failed on a merge and both were right.** The garden remembers its speed now, so
the game has genuinely stopped starting at 1x. `GameSpeed._step` is static and
`RunConfig.game_speed_step` is autoload state loaded from the real save *before any
`setup()` runs* — process-global twice over. A `GameSpeed.reset()` at the top of a test
stopped being enough the moment `_ready()` began restoring the saved step.

**An autoload beats `setup()`, and no checker can see it.** The first suite run after the
v6→v7 save bump rewrote the developer's real `highscore.save`. Nothing was lost, and the
migration is what the game would have done anyway — but `save_persist_check` is clean by
construction there, because no *test function* is in the chain. `-58u7`.

**Beads rot, and the rot is measurable.** A derived scan found **139 open beads carrying an
absence claim**. Sixteen were resolved against the code; two had premises that were now
entirely false and closed without a line written — one would have had somebody building a
boss that already has 80 health, two sprites and 26 wave appearances. **123 were not
reached**, and saying so is the point: a sweep that does not state where it stopped reads
as complete.

## What cycle 103 taught

**The game finally says that upgrading exists.** Cycle 101 measured that upgrading decides
the run — same economy, no cheats, one policy bit; breadth-first died at wave 10, depth-first
won 22 waves losing no lives — and nothing in the game mentioned it except a refusal and a
confirmation, both reached only by someone who had already found the button. There is now a
third one-shot hint, fired the first time the player can afford the cheapest upgrade **on
their own board**: verified live at the boundary, false at 19 seeds and true at 20, which was
that cob's exact `upgrade_cost()`. And the Shield Bug, spawnable by name since cycle 100 and
met by nobody, now debuts in wave 15 — 4 of them, confirmed on a live census.

**A hint on a funnel is not a hint on an event, and the difference is invisible until you
read the return contract.** `show_message` returns false on a busy row but **queues** the
text rather than dropping it. That is right for `_on_flight_ignored`, which fires once per
winged pest. It is wrong for anything offered from `_refresh`, where the condition stays
true — every later refresh stacks another copy, so a one-shot would have shown up to
`MESSAGE_QUEUE_MAX` times. `Hud.row_is_quiet()` exists now, and the tip asks before
offering.

**A file became a writer of the developer's real save without one line of it changing.**
`save_persist_check` printed
`place_plant() -> _refresh() -> _maybe_teach_upgrading() -> spend_hint() -> _save()` and
named the two tests in `test_board.gd` that walk it — before a single test had been run.
That is the argument for a project growing its own checkers in one line.

**And the harness's own safety net did not catch.** `launch --snapshot-userstate` did not
restore, so the run left `m1:seen_upgrade_tip` in James's real save — meaning he would never
have seen the hint this cycle exists to add. Put back by hand (`m0`, scores 3454/5008
intact) and filed as `-zzx3`: the flag's failure mode is currently indistinguishable from
its success.

**Two things to know about the fan-out.** The lane's worktree branched from an *older*
commit than `main`, so it worked without cycle 102 in its tree and correctly reported that a
command its brief named did not exist — it said so rather than assuming, which is the only
reason that was caught. **Check a lane's base.** And a concurrent session is working in this
same checkout; its in-flight edits to `dev_tools.gd` and the itch workflow were swept into
this cycle's merge commit. Both are correct and wanted, but `dev_tools.gd` is
harness-managed and one `/scaffold-godot-harness` from vanishing silently — `-kdnl`.

## What cycle 102 taught

**Five lanes, in worktrees this time, and the isolation worked exactly as advertised — while
introducing a trap nobody predicted.** Rain that falls, directional bite and sting, a styled
top bar, spent packets that read spent, packets that point at their plants, and a player-facing
speed toggle, all at once. Not one lane reported a sibling's file, which is the whole reason
`-l638` existed. But agent worktrees live *inside* the repo and `rglob` does not read
`.gitignore`, so `citation_check` turned every bare citation in `kanban.md` into a six-way
ambiguity — **visible only to the parent**, because a lane inside its own worktree has no
nested copies. A finding count that depends on which process is asking is worse than no count.

**The honest price of a worktree is that a lane compiles NOTHING.** `--require-compile` is the
documented escape and it does not work there — two lanes hit it independently and got
`Identifier "WaveDirector" not declared` and `Could not find base class "Plant"` on lines
unchanged from main, because a fresh checkout has no class cache. So five lanes reported green
having never parsed a line, and the parent found: two tests that were green by construction,
a top bar with no room for the button it was handed, three public surfaces no test named, and
a checker reporting nonsense. **None was a lane's mistake.** `merge-the-fanout` is now a skill,
because that procedure had been re-derived from scratch twice in three cycles.

**A merge can delete a test with no compile error.** Git hoists a shared suffix below the
`>>>>>>>` marker when both lanes' last function ends the same way — twice here it was
`_T.free_ui(game)` / `return err` — so removing the three marker lines silently truncates one
side's final test. GDScript accepts a function whose last statement is an assignment. The only
thing that catches it is arithmetic: 329 base + 3 + 4 + 4 = 340, and the merged file had 340.

**"The plant was right and the assertion was wrong."** Two lane tests asserted "this plant has
not attacked yet" with the prey already in range. `_act()` runs on every settle frame, so the
Chomp had eaten and the Nettle had stung before the precondition was read — the failure
message even carried that exact aphid's lunge vector at full `LUNGE_DISTANCE`. There is no
"has not bitten anything" state for a flower sitting on top of its lunch.

**Let the thing that measures do the measuring.** The speed button needed 67px the top bar did
not have. Instead of arithmetic: set the constant absurdly low, run the one test that checks
it, read the number out of the failure. "Grow the next wave" needs 202px of its 216px slot;
"Next wave" needs 120. The row ended with *more* headroom than it started with — 19px to 38 —
while gaining a control.

**And `reach` disagreed with a button I had watched work.** `game_speed.gd` is a static utility
no node carries, so it is invisible to `scripts-seen` however much of it ran. Filed as
`-v3ji`: a file that CANNOT be seen and a file that WAS NOT loaded are opposite results, and
today they print identically.

## What cycle 101 taught

**The game got played, and it has exactly one difficulty event.** Two full campaigns, same
economy, no cheats, differing in a single policy bit — spend surplus on NEW plants or on the
plants already down. Breadth-first reached eleven level-1 plants and **died at wave 10**.
Depth-first **won all 22 waves without losing a life** (591 pests, 1129 spare seeds at the
end). Both had all seven plants by wave 7, so the catalogue is not the difference.

**Upgrading decides the run and nothing teaches it.** The button exists only while a placed
plant is selected, and every mention of upgrading in the game is either a reply to a player
who already found it (a refusal, a confirmation) or a notebook caption they must go and open.
Filed as `-gz53`, and it is the highest-value item on the board.

**A cliff and a plateau, both derived rather than felt.** Wave 8 was carrying a +45.9% count
step *and* the mutation multiplier's +24.0% — `MUTATION_START_WAVE` is 8 — for **+80.9%** in
one wave, where every wave from 9 to 22 steps +2.0% to +13.6%. Two independent difficulty
increases on the same wave, so there was nowhere in the campaign a player met a mutation at a
density they could read. Wave 8's counts now hold wave 7's peak spawn rate exactly: the
mutation is the only new thing there. Measured after: the breadth policy that died at wave 10
reached **wave 17**. That was the cycle's one tuning, out of a budget of three — two robot
policies are not enough evidence to spend the other two, and the rest is filed (`-iqp8`,
`-uqeo`) rather than guessed.

**Three lanes again, and this time the parent owed them wiring, not just a merge.** The
upgrade lane correctly refused to touch `hud.gd`/`game.gd` and listed seven exact edits it
needed there. Skipping them would have shipped a Chomp Flower whose ladder no player could
reach — three files of dead code with every gate green.

**A lane's checkers see the other lanes.** Parallel-*safe* is not parallel-*isolated*: they
read the working tree, and in one checkout that tree holds every sibling's half-finished
edits. One lane got 12 NEW findings in three files it had never opened. It caught that itself;
the same race in reverse hands a lane a clean exit it did not earn, silently. `-l638`.

**And runtime caught what nothing headless could.** `cmd upgrade_plant` on a Chomp answered
`success: false` with an *empty message* — indistinguishable from the game refusing — while
the upgrade had actually landed. The debug verb cast the result to `CornCobbler` and died
inside its own reply. It had been correct for every cycle in which corn was the only plant
with a ladder, and became wrong with no edit to the file.

## What cycle 100 taught

**The first parallel cycle. Three agents, three lanes, and every failure lived in a seam none
of them could see.** A campaign (16 → **22 waves**), a pest species (the **Shield Bug**, whose
plate bounces a Corn Cobbler's kernels and not a Dandelion's seed) and a plant (the **Prickly
Nettle**, which stings only mutated pests) all shipped at once. Each agent ran all eleven
parallel-safe checkers clean in its own lane. **The merge failed five times.**

A golden headcount array and a hardcoded endless wave pair, broken by another lane's growth. A
deliberate "a new plant must be decided about here" gate asserting exactly three engaging
plants. A placement test that funded a purchase but never unlocked the plant. A notebook note
119 characters over budget. **None was a mistake by the agent that caused it** — each was a
fact about a file it was correctly forbidden to open. The parent pass is where parallel work
integrates, and its cost scales with the number of lanes rather than the size of any one.

**Two bead premises were wrong again, both mine, both found by the agent opening the code.**
"Growing the campaign is an afternoon" — no: three assertions chain to cap any finale at 436.7
base health and wave 16 was already 418, so seven appended waves had **one beetle** of headroom
between them. The six went in *front* of the finale instead. And "nothing SPLITS" — the queen
has split into aphids since the boss landed.

**A magic number derived from a constant outlives the constant and reads as deliberate.** The
endless ramp test priced waves `[60, 100, …]` and said "past wave 48"; both were correct at 16
waves and silently wrong at 22. It now *finds* the first pinned wave instead.

## Carried from cycle 99

**When a container cannot hold its contents, the arithmetic has two sides and only one usually
gets examined.** The plant bar took six plants — and now seven — because a button's minimum
width fell from 195px to 8px, not because the bar changed.

## Carried from cycle 98

**Ask the layout function at N+1 before building the thing.** A sixth plant was built whole
before anyone called `plant_bar_layout(6)` — one line, pure, and it knew. Also: a branch a
file documents as broken is worse than no branch, because it reads as handled.

## Where things stand

Suite **654/654**, 13566 assertions; lint 0/0; import clean; eleven checkers clean; `findings`
**0 across 5 of 5, exit 0**. Fifteen skills. Upstream gh#44 and gh#51–57 open. Still on harness
**0.38.0** deliberately (`-ny3h`, gh#43).

**The game has 22 waves, seven plants, four pest species — and now two plants that grow.** The
Chomp Flower has a three-rung ladder (bud → toothy maw → gaping maw) behind a generic `Plant`
surface: a plant is upgradeable iff its ladder is non-empty, so the third one is a const plus
one override with no branch anywhere else. The playfield wears the notebook's own paper as a
wobbling page frame, and `GardenTheme.reads_on_ground()` is now a real gate against the failure
that let the Mint be drawn in the lawn's exact hue in cycle 98. The Nettle stings audibly.

**The loop is paused here at the user's request** ("let's wrap up this loop and be one for
awhile"), at the end of a clean cycle rather than mid-item. Nothing is half-finished: every
lane merged, every gate green, the queue refilled.

**Parallel is the default.** Step 2 carries the rule, its gate list, the shared-registry case,
the merge budget, and now two more: a lane's checker findings outside its own files are not
its findings, and the parent owes each lane the parent-owned wiring it was forbidden to write.
`-pdri` (Shield Bug into a wave) is still open — cycle 101 held `wave_director.gd` for the
tuning, so that lane waited.

## Waiting on the user

**`-ix76` — should a 60-seed husk rot faster than a 9-seed one?** New this cycle and flagged
with `bd human`. Both husks give the player 4.5 seconds, because `lifetime_for` saturates
where the drawing used to. Either 4.5s is a floor on reaction time and the pips are the whole
fix, or the richest drop should be the one you can least afford to miss. The two answers want
opposite code, so this is not a thing to pick by whichever is easier.

**`-oo7e` — weather has no counter-play.**

**`-h5w6` — what should moving a plant cost?**

**`-ogxu` — should a budget floor keep a reserve?** Three HUD rows are at floor because each
was ratcheted down in the commit that spent it; every one was the right local move, and
together they made a HUD with no slack that nobody chose.

## Answered by the user, and now ordinary work

Both of cycle 101's questions were put to James and answered on 2026-08-17. The answers are
recorded in the beads themselves, which is where the next cycle will read them — logged only,
nothing started.

**`-iqp8` — the campaign gets a real second act.** Retitled from "Decide: should it escalate
at all", because it is no longer a question. Waves 9-22 should climb so the plants unlocked at
wave 7 have something to be needed for. The reading this rules out is "a flawless 22/22 is the
correct ending for a tutorial campaign", which was live until now. The bead carries the
starting point: `health_scale_for` is the one-function lever, rewriting fourteen wave rows is
the expensive path, `mutation_chance_for` is the other flat axis and a different feel, and
whatever lands has to keep `threat_for` rising strictly — priced offline against `_raw_threat`
before editing, the way cycle 101's wave-8 tuning was.

**`-uqeo` — re-measure the seed surplus before designing any sink.** Not blocked on James any
more; blocked on a number. The 1129-seed figure came from a run predating the Chomp Flower's
ladder, so it had one plant to sink into and now has two — the sink roughly doubled between
the measurement and today. The bead says exactly what the re-run must produce so the two are
comparable: the per-wave banked series, the per-wave low-water mark (the early game bottomed
at 0, 1, 1, 3 and 4, which a boundary reading hides), and a depth-first policy, since that is
where the recorded series came from.

## Restarting

`bd ready` for the work, this file for the context, `/cycle` (`.claude/skills/cycle/SKILL.md`)
for the loop itself — `CLAUDE.md` and `AGENTS.md` now carry only a pointer to it. **Confirm a bead's premise before claiming it** — step 2's first move, and for
three cycles running it is where the design happened rather than a correctness check: it found
a wrong absence claim (90), a wrong claim about a file's shape (91), and a whole option the
bead had not listed (92). It now also says to grep for the HELPER you are about to write.
`-g1o4` (P1) is that sweep over the whole open queue. `-knpc` blocks `-1490` and `-lp97`;
`-ip4n` blocks `-l86t`; `-q1xs` blocks `-vvxn`. `-ei83` is unblocked and sharpened: a missed
hint is a real queryable state, but it cannot be solved by adding the id to `Milestones.TABLE`
— the shelf counts earned off TABLE, so a foreign id breaks that guard. `-9afm` is the
fragility cycle 81 worked around rather than fixed. `-qewq` is the one I most want answered:
two mutations survived their first guard in one cycle, both because the guard checked for the
presence of a good thing rather than the absence of the bad one, and the sweep decides whether
that is in the codebase or was just in me.

**Twelve standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI findings
baseline is **empty** (`-v9px`). Any harness operation should start by checking which version
the skill's paths point at — and **reconcile a gap against the INSTALLED version, not the
pinned one** (`gap-reconcile`); two were already fixed. **Never hand-edit `AGENTS.md`** — run
`python tools/mirror_check.py --fix`. **NEVER TYPE A NODE PATH** — get it from `find-nodes
--class X --where name=Y` or `scene-tree`. This project's HUD node is `/root/Game/HUD` while
its class is `Hud`, so the wrong guess is the natural one, and a path miss reports only the
path: fourteen identical `Node not found` replies read as fourteen empty reads (gh#53).
**`pause` right after `launch`**, but **unpause before `findings`** — except the pause card —
and **capture `scene-tree` before `quit`** or the ledger row loses its reach. **A paused tree
does not repaint**: anything drawing from `_process` holds its old frame, so a change made
while paused needs `run-method --method queue_redraw` on the drawing node (`-rvvt`).
**Run `run_json_check.py` BEFORE `verify_ledger record`.** **Cut `kanban.md` by line number,
never by heading**, and **take a citation's line number only after the code edits are final** —
cycle 90 rebound the same two three times because its own comments kept moving them.
**No prose in ANY `bd` field as a shell argument** — not `create -d`, not `close --reason`,
not `update --notes`. Backticks are command substitution: the word vanishes and leaves a
still-grammatical sentence, which is why four cycles have now done it (76, 78, 83, 91).
Write the file, then `--body-file` or `"$(cat PATH)"`. **Durable means TRACKED** —
`.devtools/*` is gitignored (`.gitignore:8`, one exception for `verify-runs.jsonl`), so
anything owed to a future cycle goes in a bead body or a committed file; `git check-ignore -v
PATH` answers it in one command. And **`set-game-speed` takes its scale positionally**, not as
`--scale`.

`python tools/gap_ledger.py --open` answers "which harness gaps are open" as a fact about the
log, not about the harness; `python tools/citation_check.py` answers "do this file's citations
still land"; `python tools/devtools.py cmd budgets` prices the **seven** couplings;
`list-commands --offline` answers "does this verb exist" with no game running. Live plant ids
are catalogue ids — `corn_cobbler`, not `corn`; **a Chomp must be unlocked before it can be
planted** (`set-state /root/Game/SeedBank unlocked` to a JSON array does it); and a plant is
selected by a real click, which `cmd touch_press`/`touch_release` at its `global_position`
will deliver. `run_tests.py` takes its own flags **after `--`** (`-- --filter husk`), which is
how a mutation pass runs in seconds instead of a minute. To walk a sub-second tween: `pause`
**before** creating it, then `step-time --seconds 0.03 --then-pause`; to verify a fix to a
once-per-save behaviour, `launch --snapshot-userstate` **before** clearing the flag, or the
run writes the developer's real save. Bump the number at the top of this file every time you
refill.
