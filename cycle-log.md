# Cycle 57

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 57 taught

**An empty answer has to look like an answer.** A selected plant with no sole-cover rings
means something useful — everything it reaches is also held by something else, so it can be
dug up and replanted and the road loses nothing. It rendered as *silence*, which is
indistinguishable from "nothing is selected" and from "the cue is broken". That is not
hypothetical: cycle 55 spent ten minutes hunting a bug in a hover cue that was correctly
drawing nothing.

So the answer is always a ring now, and only its **position** changes. Out on the road,
those cells depend on you. Around the plant, nothing does.

**And the bead's design was killed by reading the file it would have touched.** It asked
for a line in the selection panel. `hud.gd` records that a third line once pushed
SelectionBox's foot to exactly the panel's own 648 and was caught by the clearance gate,
and its VBox comment says the stack already runs to within 16 px of the panel foot.
Measured before writing anything: the cob's second line is ~190 px of a 232 px box, and the
label autowraps. **The requested design would have reproduced a failure the file already
documents.**

That is two cycles running where the codebase's own prose — written by whoever hit the
limit, at the line that constrains it — was the decisive input rather than any tool.

## Where things stand

Sixty-seven beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **559/559**, 12246 assertions; lint 0/0; eight house checkers, the mirror and
`suite_reach` all clean. Eleven skills. Upstream gh#44 and gh#46 open.

Cycle 56's workflow change worked immediately: no self-declared duplicate bead was filed
this cycle, for the first time in five.

## Waiting on the user

**Weather has no counter-play** (`plant-tower-defense-oo7e`) — the only genuinely blocked
item, unchanged for many cycles. Water tiles plus a real counter, a cheaper counter needing
no terrain, or weather stays a difficulty modifier.

Four cycles of player-facing work have gone in. The strongest thing ready now is `-j46n`:
arming an uproot is the exact moment the game knows a *move* is being considered, and it
currently changes only a button's text — the rings could show which cells go bare if you
confirm, using data that already exists. Then `-b7v5`, `-iqf2`, `-vxq6`, `-dgu5`, `-tzz7`,
`-a6rf`, `-g8kc`, `-f5z6`.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself.

**Five standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI
baseline carries twelve overlaps acceptable only while both controls are unreachable. Any
harness operation should start by checking which version the skill's paths point at.
**Never hand-edit `AGENTS.md`** — run `python tools/mirror_check.py --fix`. And **`pause`
right after `launch`** — three cycles running, that is what has made every visual result
trustworthy.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **five** couplings (and `-a6bq` is filed to
re-read them, unread since cycle 52); `list-commands --offline` answers "does this verb
exist" with no game running. Bump the number at the top of this file every time you refill.
