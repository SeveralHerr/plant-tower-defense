# Cycle 101

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

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

**`-iqp8` — should the campaign's back half escalate at all?** New this cycle, and the biggest
open design question. Derived from all 22 rows: after wave 9 the campaign averages **+6% threat
a wave for thirteen waves**, and pest counts sit between 26 and 37 the whole way. That is
structural rather than sloppy table-writing — `health_scale_for` returns exactly 1.0 for every
campaign wave and `mutation_chance_for` returns a flat constant, both by the same `over <= 0`
early return, so every escalation axis the game owns is endless-only *by construction*. Either
the campaign is a 22-wave tutorial that hands you to endless (in which case a flawless run is
the correct ending) or it wants a real second act. Both are defensible; the wrong one is
expensive to reverse, so nothing was changed.

**`-uqeo` — the seed surplus has no sink.** The winning run finished holding 1129 seeds with
nothing to buy, while the first seven waves bottomed the bank at 0, 1, 1, 3 and 4. Broke while
the decisions are live, rich once they are settled. **Re-measure before designing anything** —
that run predates the Chomp's ladder, so the surplus had exactly one plant to sink into.

**`-ogxu` — should a budget floor keep a reserve?** Three HUD rows are at floor because each
was ratcheted down in the commit that spent it; every one was the right local move, and
together they made a HUD with no slack that nobody chose.

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
