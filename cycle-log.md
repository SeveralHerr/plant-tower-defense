# Cycle 90

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 90 taught

**Confirming a bead's premise is where the design happens.** `-2ker` asked for the second
one-shot hint: a Chomp declines a winged pest with a bare `continue`, so a mouth sitting still
next to a bug is indistinguishable from a broken plant. Confirming that also turned up the
thing that reshaped the whole change — **`show_message` returned `void` while being perfectly
capable of dropping a line**, since `_queue_message` discards the new entry on a priority tie
with a full queue. So "I called `show_message`" and "the player read it" were one expression.
That is cycle 79's bug one level further down.

It returns a bool now, deliberately `false` for a *queued* line rather than optimistic about
it, because a queued line can still be dropped later. A `false` leaves the hint owed and the
next flier offers it again — a retry path a hint spent on the call could never have.

**And the mutation pass demanded the test that mattered.** Replacing `posted` with a literal
`true` at the call site survives every other test in the change: the predicate fires, the
signal emits, the message appears in the ordinary case. The only observable difference is a
busy row. `test_the_flight_hint_is_not_spent_when_the_row_was_too_busy` exists because that
mutation would otherwise have lived.

**Two observation errors read as one defect.** The live run appeared to show the hint never
firing. I had polled `/root/Game/Hud/...` when the node is `/root/Game/HUD/...`, so fourteen
`Node not found` replies read as fourteen empty rows — and by the time the path was right, the
hint had already been spent on the first attempt and was correctly doing nothing. **A stable
error shape reads as a stable result.** Filed upstream as gh#53.

## Carried from cycle 89

**A test can pass over nothing, and `[VACUOUS]` cannot see it.** `Milestones.TABLE.has(id)` on
an `Array[Dictionary]` is false for every id in the game. A claim about membership needs the
collection's SHAPE read, not just its name resolved.

## Carried from cycle 88

**A cue can be present, correct, and out of range.** Ten reachable husk values, and `radius_for`
and `glow_for` both saturate at 9 — six of the ten drew as one husk. `overflow_pips` counts where
the lerp ran out. And **a legibility fix that quietly changes a balance number is two changes**:
`FULL_VALUE` was left alone because `lifetime_for` reads the same fraction.

## Where things stand

A hundred and three beads ready. Suite **600/600**, 12863 assertions; lint 0/0; eleven checkers
clean; `findings` **0 across 5 of 5**; reach 3/4 +1 implicit, nothing unreached. Fifteen skills.
Upstream gh#44, **gh#51, gh#52 and gh#53** open — three filed in three cycles, each reconciled
against the installed 0.54.0 first, which is what made two of them sharper than the observation
that started them. gh#49 and gh#50 are closed and fixed, which moved `-6e2e` off upstream and
onto the pin. Still on harness **0.38.0** deliberately (`-ny3h`, gh#43).

**The player-facing steer is standing and cycle 90 is squarely on it.** 84-88 each shipped
something a player sees; 89 shipped a persistence guard and owed a sentence for it; 90 spends
that guard on the thing it was built for — a Chomp now says why it is ignoring a bug, in one
sentence, once ever. `-a155` is still the cheap half of the board-check problem (transform
properties, no pixels) and `-i366` is the sharpest new player-facing thread: nineteen of
twenty-two message-row calls share one rung, and a tie drops the newer line.

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
**Write a `bd` description to a file and pass `--body-file`** — `-d "..."` goes through the
shell and backticks are command substitution. And **`set-game-speed` takes its scale
positionally**, not as `--scale`.

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
