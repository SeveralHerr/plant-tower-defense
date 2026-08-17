# Cycle 58

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 58 taught

**The rings change tense.** Arming an uproot is the one moment the game knows a *move* is
being weighed, and the sole-cover rings already held the answer to what it costs — they
are exactly the cells nothing else covers. Arming reddens them: "these depend on you"
becomes "these go bare if you confirm", with no new computation. Same red and the same
doubling as the selection brackets, taken from their constants so the two cannot drift.

**The asymmetry is the interesting part.** The holds-nothing ring is deliberately *not*
reddened. The brackets warn because the action is destructive, which is true whatever the
coverage looks like; these rings warn about what is **lost**, and when the set is empty
nothing is. Reddening it would raise a false alarm about the single case where uprooting is
free — the case that ring was added one cycle ago to announce. It is a predicate with a
test rather than a branch in `_draw()`, because it is the part most likely to be tidied
away later.

**And the suite was right twice in one breath.** The new test covers two symbols sitting on
the reach debt baseline, so `suite_reach` demanded a re-bank — while reporting **1 NEW**
uncovered symbol at the same time. `--baseline-write` rewrites the whole file, so acting on
the cheerful "PROGRESS: re-run to lock the improvement in" would have banked a regression
under an improvement, silently and permanently. It was safe only because both numbers print
together. That generalises, and it is now in `house-static-checker`: **if acting on one
number could bury another, print both at the point of invitation.**

## Where things stand

Seventy beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on gh#43).
Suite **559/559**, 12250 assertions; lint 0/0; eight house checkers and the mirror clean.
Eleven skills. Upstream gh#44 and gh#46 open.

## Waiting on the user

**Weather has no counter-play** (`plant-tower-defense-oo7e`) — the only genuinely blocked
item, unchanged for many cycles. Water tiles plus a real counter, a cheaper counter needing
no terrain, or weather stays a difficulty modifier.

Five cycles of player-facing work have gone in and the uproot flow is now nearly a move
tool. `-qk5q` completes it: while an uproot is armed the game knows both the plant's kind
and that a move is being weighed, so hovering a destination in that window could preview
*this* plant at *that* cell — two existing cues becoming one move preview, with no new
computation. Then `-6cqi` (two cobs at different levels look identical on the board — the
same shape of gap the coverage work just closed), `-b7v5`, `-iqf2`, `-vxq6`, `-dgu5`,
`-tzz7`, `-a6rf`, `-g8kc`, `-f5z6`.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself.

**Five standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI
baseline carries twelve overlaps acceptable only while both controls are unreachable. Any
harness operation should start by checking which version the skill's paths point at.
**Never hand-edit `AGENTS.md`** — run `python tools/mirror_check.py --fix`. And **`pause`
right after `launch`** — four cycles running, that is what has made every visual result
trustworthy.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **five** couplings (`-a6bq` is filed to re-read
them, unread since cycle 52); `list-commands --offline` answers "does this verb exist" with
no game running. Bump the number at the top of this file every time you refill.
