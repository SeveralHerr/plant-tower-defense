# Cycle 95

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 95 taught

**A wrong premise can make work look more expensive than it is, and that is the version
nobody catches.** `-1wx0` said the legend's five rows sat at the edge of the 300 px matte, so
a sixth needed `ROW_PITCH` cut or a second page. Derived from `CueLegend`'s own constants
instead of eyeballed: five end at **248**, six at **294**, seven at **340**. It fit at the
existing pitch and cost nothing but the row. The last three cycles found premises that made
work look *necessary*; this one nearly bought a second page nobody needed.

So the legend teaches six of ten now, and the sixth is the ARMED cue — the only one guarding
an action that cannot be undone. Its swatch is deliberately row one's brackets at
`WARNING_LINE_WIDTH` in danger red, because that IS the grammar: doubled width means the mark
you already know, thicker. The screenshot is the check that matters and the two rows read as
a pair.

**And a test kept its own copy of what the code supports.** The drawable-shapes check held a
hand-written array, so adding the sixth row broke the test that same edit was meant to
satisfy — **a test maintained by whoever breaks it is not an assertion.** Now derived from the
source, checking two things that fail apart: the `match` arm, and a painter for it to call.

**Cycle 91 also closed `-bxhg` with one acceptance clause unmet** and nothing noticed for four
cycles. `verify-bd-item` now says to answer the acceptance clause by clause when closing;
`-pc3m` is the audit that says how big the hole is.

## Carried from cycle 94

**A correct citation under a wrong sentence is more expensive than no citation** — it is what
stops the next reader checking. Read what the cited line DOES, not just that it is the line
you meant.

## Carried from cycle 93

**"Zero because nothing happened" and "zero because nothing is happening at all" are the same
read.** Pair an expected zero with a witness that must move — `run_seconds`, a monotonic tally
— or read the whole `state()`, which carries one for free.

## Where things stand

A hundred beads ready. Suite **611/611**, 12997 assertions; lint 0/0; eleven checkers clean;
`findings` **0 across 5 of 5**; reach 1/1. Fifteen skills. Upstream gh#44 and **gh#51–gh#56**
open; gh#49/gh#50 fixed. Still on harness **0.38.0** deliberately (`-ny3h`, gh#43).

**The player-facing steer is standing and cycle 95 kept the promise cycle 94 made.** 90 made a
Chomp explain itself; 91 gave the board's drawn language a page; 92 put that page one press
from a paused run; 93 and 94 closed two worries with measurements and shipped nothing visible;
95 taught the ARMED cue — the one guarding the only irreversible act. **The legend is now
finished-shaped rather than unfinished**: six rows end at 294 of a 300 px matte, so a seventh
is a layout decision, and `-wenx` asks whether any of the four remaining cues deserves that
cost (one of them, the weather, provably does not — the game says it in words three times).

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
