# Cycle 56

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 56 taught

**The garden can be read now, from both sides.** Cycle 55's hover dots answer "what would
this purchase add". This cycle's rings answer the mirror: **what would the garden lose if
this plant went**. A lone cob at `(8, 5)` rings eight road cells; plant a second at
`(8, 6)` and the first drops to **zero** with nothing clicked — everything it held is
backed up, so it can be uprooted and moved for free. A range ring could never show that,
because it is identical whether the plant is the only thing holding that road or one of
three.

**The interesting engineering was where NOT to put it, and the file answered twice.** Not
in `Plant._draw()`, which `CornCobbler` and `ChompFlower` fully override without calling
super — the trap `SelectionMarker`'s header documents, and the reason the Chomp once
shipped with no selection cue at all. And not in `SelectionMarker` either, the obvious
home: `play_entrance()` tweens that node's `scale` from 0.55, and these marks sit whole
cells from the plant's origin, so every selection would slide them inward and out again.
Brackets 22 px from centre do not care; a mark 320 px away does. A third sibling node it
is — which is precisely the reasoning that created `SelectionMarker` in the first place.

**And the suite caught the one thing missing before I could.**
`test_every_game_class_is_at_least_named_somewhere_in_the_test_suite` refused the new class
within seconds of it existing.

## Where things stand

Sixty-three beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **559/559**, 12244 assertions; lint 0/0; eight house checkers and the mirror
all exit 0. Eleven skills. Upstream gh#44 and gh#46 open.

## Waiting on the user

**Weather has no counter-play** (`plant-tower-defense-oo7e`) — the only genuinely blocked
item, unchanged for many cycles. Water tiles plus a real counter, a cheaper counter needing
no terrain, or weather stays a difficulty modifier.

Three cycles of player-facing work have gone in and the queue has more: `-r7pz` (say
"nothing depends on this one" when the rings are empty — an empty render is the hardest
state to read, which cycle 55 proved the hard way), `-b7v5` (name the
coverage-is-not-engagement mechanic on the run summary, since the player currently learns
it only by losing), `-iqf2`, `-vxq6`, `-dgu5`, `-tzz7`, `-a6rf`, `-g8kc`, `-f5z6`.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself.

**Five standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI
baseline carries twelve overlaps acceptable only while both controls are unreachable. Any
harness operation should start by checking which version the skill's paths point at.
**Never hand-edit `AGENTS.md`** — run `python tools/mirror_check.py --fix`. And **`pause`
right after `launch`**: cycle 55 lost a screenshot to a run that ended mid-read, and this
cycle's 8-to-0 result is trustworthy precisely because the board was frozen between the two
reads.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **five** couplings; `list-commands --offline`
answers "does this verb exist" with no game running. Bump the number at the top of this
file every time you refill.
