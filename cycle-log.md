# Cycle 92

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 92 taught

**Confirming a bead can find a better option than the three it lists.** `-czz4` said the cue
legend was nine presses of Next from the front of the notebook and offered three fixes.
Confirming it found that `PauseScreen` **already** had a Notebook button and its own
`_open_notebook` — so "add a route" was not the work, and the nine presses were the whole of
it. The two doors are asking different questions: somebody who stopped a wave is staring at a
mark they do not recognise, somebody browsing from the title screen is not looking at a board
at all. `NotebookScreen.open_at` lets the context pay the nine presses instead of the player.

**A default that equals one of the two expected answers cannot be distinguished from the
property being ignored.** `open_at` defaults to 0 and the title screen wants 0, so a test
asserting only the legend case would pass against a build that ignores `open_at` entirely.
Both doors are driven, in the tests and at runtime, for that reason alone.

**And the helper I was about to write already existed.** `page_for_kind` turned out to be
`shelf_page()` generalised — the same search over `PAGES`, written cycles earlier, for the
same stated reason. Nothing catches that: two functions with different names doing one search
resolve every name, compile and pass. A grep for the *shape* before writing the function is
what found it, and that is now in `verify-bd-item`'s confirm step. Three cycles running, the
thing about to be built already partly existed.

## Carried from cycle 91

**Searching for the wrong noun answers a question you did not ask.** A grep for "husk" in a
file answered what it *contains*; the claim was about its **shape**, and `KIND_SHELF` was
thirteen lines from the top. Also: both mutations survived their first guard, each because
the guard asserted the PRESENCE of a good thing where it needed the ABSENCE of the bad one.

## Carried from cycle 90

**A stable error shape reads as a stable result.** Fourteen identical `Node not found`
replies were a typo in one path segment, not fourteen empty reads. Never type a node path.

## Where things stand

A hundred beads ready. Suite **607/607**, 12956 assertions; lint 0/0; eleven checkers clean;
`findings` **0 across 5 of 5**; reach 2/2 across two sessions. Fifteen skills. Upstream gh#44
and **gh#51–gh#54** open; gh#49 and gh#50 fixed, which moved `-6e2e` off upstream and onto the
pin. Still on harness **0.38.0** deliberately (`-ny3h`, gh#43).
**Two things are OWED upstream and blocked on nothing but a working GitHub** (HTTP 503, twice):
the gh#54 comment parked at `.devtools/pending-gh54-comment.md`, and filing `[G-067]`. `-he1l`
carries both.

**The player-facing steer is standing, and cycles 90-92 are all on it.** 90 made a Chomp
explain itself; 91 gave the board's drawn language a page that teaches it; 92 put that page one
press from a paused run. **91 and 92 both worked the notebook, which overrides step 2's
vary-the-subsystem rule** — the steer outranks it and the file now says so, but a third
consecutive notebook cycle would be a pattern rather than a call. `-1wx0` is the strongest
remaining player-facing item and is *also* the notebook (the doubled-width ARMED cue, the one
guarding the only irreversible act, is among the five the legend does NOT teach); `-i366` is
the strongest one that is not.

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

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`) for
the loop itself. **Confirm a bead's premise before claiming it** — step 2's first move, and for
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

**Eleven standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI findings
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
Write the file, then `--body-file` or `"$(cat PATH)"`. And **`set-game-speed` takes its
scale positionally**, not as `--scale`.

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
