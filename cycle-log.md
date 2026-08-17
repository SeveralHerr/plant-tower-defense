# Cycle 96

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 96 taught

**"Drive it in a real run" is not the same as "exercise it".** `-gtne` asked how often the
message row displaces a line the player is reading. Six waves, 54 kills, eight lives lost, 257
seconds, `run_seconds` moving as a witness: **zero**. That number is accurate and worthless —
all three call sites that can displace a line are **player actions** (arming an uproot, the two
steps of opening a seed packet), and a run driven by starting waves contains none of them. One
`arm_uproot` produced the count on the first try.

**A zero inherits the blind spot of the scenario that produced it**, which means cycle 93's
answer to `-i366` is now weaker than it read: same shape of run, same absence of player
actions, and a full queue needs exactly the producers that were missing. `-gd27` re-measures
it, cheaply, because the counters are still there.

So the fix shipped: a line that has had `MESSAGE_MIN_READABLE` seconds is **retired** when
displaced rather than queued. The player read it; bringing back the tail teaches nothing and is
what made the same sentence appear twice. A line displaced before that still comes back
unchanged. `MESSAGE_MIN_READABLE` is reused rather than a second threshold invented — the wait
branch already treats it as "long enough to have been read", and a second number would be a
second opinion.

**And a green test that asserted nothing.** `line_was_read(4.0, 4.0 - MESSAGE_MIN_READABLE)`
computes `1.2000000000000002`, so the "exactly at the threshold" case passed under both `>=`
and `>`. Only a mutation found it. **An at-the-boundary case must be constructed, not
computed.**

## Carried from cycle 95

**A premise can be wrong in the direction that makes work look EXPENSIVE**, and that failure
has no natural discoverer — the response to "too costly" is to not do it, which produces no
evidence. Price it with arithmetic before believing it.

## Carried from cycle 94

**A correct citation under a wrong sentence is more expensive than no citation** — it is what
stops the next reader checking. Read what the cited line DOES, not just that it is the line
you meant.

## Where things stand

A hundred beads ready. Suite **613/613**, 13007 assertions; lint 0/0; eleven checkers clean;
`findings` **0 across 5 of 5**. The latest ledger row is **`partial`, not `pass`** — the first
in nine cycles — because one live check lost its precondition and was recorded `blocked` rather
than green. Fifteen skills. Upstream gh#44 and **gh#51–gh#56** open. Still on harness **0.38.0**
deliberately (`-ny3h`, gh#43).

**The player-facing steer is standing.** 90 made a Chomp explain itself; 91 gave the board's
drawn language a page; 92 put it one press from a paused run; 93-94 closed two worries with
measurements; 95 taught the ARMED cue; 96 stopped the row showing the same sentence twice. The
sharpest remaining player-facing threads are `-5s99` (the pause door could open the SELECTED
plant's page — both pieces already exist) and `-wenx` (whether any untaught cue earns the
legend's layout cost, one grep each).

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
