# Cycle 91

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 91 taught

**Searching for the wrong noun answers a question you did not ask.** The board has spoken a
documented ten-shape language since cycle 67 and taught it to nobody; `CueLegend` now teaches
five of the ten, each swatch drawn with the real cue's own constants. The bead said this
needed a screen of its own, because a cycle-88 entry — mine — had grepped
`notebook_screen.gd` for "husk" and "compost", found nothing, and concluded the file was a
design-history artefact. The grep was correct. The claim was about the file's **shape**, and
the answer was thirteen lines from the top: `KIND_SHELF` is documented as "about the player
rather than about the game". A fourth kind shipped in an afternoon.

**Both mutations survived their first guard, and each survival was a finding about the
test.** `source.contains(token)` passed while a `Color` literal was inlined into one of two
`draw_line` calls — the other kept the token alive. Deleting a `PANE_LABELS` row passed
because nothing asserted the resulting heading was non-empty. One shape both times:
**a guard asserting the PRESENCE of a good thing where it needed the ABSENCE of the bad
one.** `house-static-checker` already states this rule, for Python checkers; `-qewq` asks how
widely it bites in the tests.

**And the seam paid before the mutation did.** `NotebookScreen.pane_label_for` replaced an
`if/elif/else` whose `else` MEANT one kind, so a fourth kind would have taken the third's
heading and left the third correct. The identical defect was then found sitting in the *test*
for the same code. That closed `-jmxb`: `extract-a-testable-seam` no longer says to wait for
a survival.

## Carried from cycle 90

**A stable error shape reads as a stable result.** Fourteen identical `Node not found`
replies were a typo in one path segment, not fourteen empty reads. Never type a node path.

## Carried from cycle 89

**A test can pass over nothing, and `[VACUOUS]` cannot see it.** `Milestones.TABLE.has(id)` on
an `Array[Dictionary]` is false for every id in the game. A claim about membership needs the
collection's SHAPE read, not just its name resolved.

## Where things stand

A hundred beads ready. Suite **605/605**, 12945 assertions; lint 0/0; eleven checkers clean;
`findings` **0 across 5 of 5** on the notebook screen; reach 2/2. Fifteen skills, two of them
corrected this cycle by their own failures. Upstream gh#44, **gh#51–gh#54** open — four filed
in four cycles, every one reconciled against the installed 0.54.0 first, which is what made
three of them sharper than the observation that started them. gh#49 and gh#50 are fixed, which
moved `-6e2e` off upstream and onto the pin. Still on harness **0.38.0** deliberately
(`-ny3h`, gh#43).

**The player-facing steer is standing and cycles 90-91 are squarely on it.** 84-88 each
shipped something a player sees; 89 shipped a persistence guard and owed a sentence for it; 90
spent that guard on a Chomp explaining itself; 91 gave the board's drawn language a page that
teaches it. The three sharpest threads left are all player-facing: `-czz4` (the legend is nine
Next presses from the front), `-1wx0` (the doubled-width ARMED cue — the one guarding the only
irreversible act — is among the five the legend does NOT teach) and `-i366` (nineteen of
twenty-two message-row calls share one rung, and a tie drops the newer line).

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
the loop itself. **Confirm a bead's premise before claiming it** — it is step 2's first move
now, and in cycle 90 it is where the design actually happened. `-g1o4` (P1) is that sweep over
the whole open queue. `-knpc` blocks `-1490` and `-lp97`; `-ip4n` blocks `-l86t`; `-q1xs` blocks
`-vvxn`. `-ei83` is unblocked and sharpened: a missed hint is now a real queryable state, but it
cannot be solved by adding the id to `Milestones.TABLE` — the shelf counts earned off TABLE, so
a foreign id breaks that guard. `-9afm` is the fragility cycle 81 worked around rather than
fixed. `-bxhg` is the big untouched one: the drawn grammar has ten rows and the game teaches
none of them, and both surfaces that look like they could host a legend are the wrong shape.

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
