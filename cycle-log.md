# Cycle 99

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 99 taught

**When a container cannot hold its contents, the arithmetic has two sides and only one of
them usually gets examined.** Three cycles tried to fit two columns of plant buttons into a
232px bar by dividing the bar differently, and `hud.gd`'s header was right every time that it
could not be rendered. Nobody measured the other side: `get_minimum_size()` on a plant button
was **195x31** against the 114px two columns can give. Taking the NAME off took it to **8x8**.

So six plants now sit in two columns of three, with room for four more, and `findings` is 0
across 5 of 5 on the board that reported seven gating findings last cycle. **Garden Mint is
buyable** — place a Corn, read `fire_interval()` 0.8, put a Mint beside it, read 0.6.

**The side effect was better than the fix.** Icons went from 32px to 69px and the bar reads as
a seed-packet tray rather than a list of labelled rows, which is the design brief's own
framing. The name lives in the tooltip and on the selection panel; a locked plant shows no
price instead of the word "locked". **A constraint that forces content out of a cramped
surface is not obviously a loss** — what went was the least useful of three things, a name
beside a picture of the thing.

## Carried from cycle 98

**Ask the layout function at N+1 before building the thing.** A sixth plant was built whole
before anyone called `plant_bar_layout(6)` — one line, pure, and it knew. Also: a branch a
file documents as broken is worse than no branch, because it reads as handled.

## Carried from cycle 97

**A checker's finding that contradicts what you can plainly see is the one most worth
believing** — everything cheaper has already agreed with you, so the disagreement is the
information. Bisect your own change before auditing the tool.

## Where things stand

A hundred beads ready. Suite **617/617**, 13122 assertions; lint 0/0; eleven checkers clean;
`findings` **0 across 5 of 5, exit 0**. Fifteen skills. Still on harness **0.38.0**
deliberately (`-ny3h`, gh#43).

**HIGH GEAR FROM CYCLE 100, asked for directly: more levels, more work in parallel.** Step 2
now carries the fan-out rule and its safety gate — only `name_check.py` and the eleven project
checkers are parallel-safe, so agents write code and run those; the engine gates and the
runtime pass are the parent's, once, after they land, and each agent gets disjoint files.
The level work is filed and deliberately disjoint: **`-l4ke`** (Nettle, now unblocked — the
plant files), **the campaign bead** (`wave_director.gd` only) and **the new-species bead**
(`pest.gd` and art). Those three can run at once. `-wtyj` (make the play screen read as the
same notebook) is the other big P1 and touches the board, so it is a fourth lane.

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
