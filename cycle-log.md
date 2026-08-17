# Cycle 94

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 94 taught

**A correct citation under a wrong sentence is more expensive than no citation.** Cycle 93
wrote that arming an uproot destroys the line the player is reading, and cited
`game/hud.gd:1462` — the right line, the pre-empt branch, genuinely the one that fires. The
two lines under it *queue* the displaced message rather than dropping it. I had reasoned from
the other branch, eight lines away, and the citation made the claim read as checked. It cost
this whole cycle to disprove, and `citation_check` says in its own output that it cannot see
this: it proves a line exists, never that the line supports the claim.

So the answer to `-trn1` is **already fine**. The pre-empted line comes back with the time it
had left — 3.5 s of its 4.0 after a half-second interruption, well over `MESSAGE_MIN_READABLE`
— so total reading time is preserved rather than lost. Verified against the real paths: a real
plant killed, a real `arm_uproot`, then `step-time --seconds 4.05 --then-pause` and the row
reads "A hungry pest ate your Corn Cobbler!" again. It is destroyed only when the queue is
full of equals, which needs four simultaneous ordinary lines and which cycle 93's six-wave run
never reached. Both cases are tested now, so the good news is bounded rather than optimistic.

**And the fix creates the next question.** A resumed line is marked in no way — same text,
same styling — so a player who loses a bed and arms an uproot sees that sentence twice, four
seconds apart, with nothing saying one plant died rather than two. `-gtne`, and its most
interesting option *shortens* the row's work: do not resume a line that already had its 1.2 s.

## Carried from cycle 93

**"Zero because nothing happened" and "zero because nothing is happening at all" are the same
read.** Pair an expected zero with a witness that must move — `run_seconds`, a monotonic tally
— or read the whole `state()`, which carries one for free.

## Carried from cycle 92

**Confirming a bead can find a better option than the three it lists**, and three cycles
running the thing about to be built already partly existed. Grep for the HELPER, not only the
bead's claim.

## Where things stand

A hundred beads ready. Suite **611/611**, 12981 assertions; lint 0/0; eleven checkers clean;
`findings` **0 across 5 of 5**. Fifteen skills. Upstream gh#44 and **gh#51–gh#55** open;
gh#49/gh#50 fixed. Still on harness **0.38.0** deliberately (`-ny3h`, gh#43).

**The player-facing steer is standing, and cycles 93-94 both spent it on measurements that
closed worries instead of shipping changes.** 90 made a Chomp explain itself; 91 gave the
board's drawn language a page; 92 put that page one press from a paused run; 93 found the
message row drops nothing; 94 found that arming an uproot defers rather than erases. The
sentence step 2 owes for 94: **the worry it closed was one I had written into `kanban.md` the
cycle before, and it would otherwise have become a change to the most carefully worded message
in the game.** Two measurement cycles in a row is enough, though — 95 takes something that
ships. `-gtne` is the sharpest player-facing thread (a resumed line looks like a second event)
and `-1wx0` remains the strongest untouched one (the doubled-width ARMED cue, the one guarding
the only irreversible act, is among the five the legend does not teach).

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
