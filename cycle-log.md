# Cycle 59

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 59 taught

**A surviving mutation was the finding, and it was a finding about the code.** The arming
guard read `_uproot_armed if _uproot_left > 0.0`, and nothing could kill the second half —
`_disarm_uproot()` nulls the first on every exit path there is. The default reading of a
survivor is "the test is too weak"; here the test was fine and the *code* could not change
any behaviour. Strengthening the test would have locked in a redundancy and called it
coverage. Removed, and the invariant it stood in for is a test now. That is the second time
this repo has found dead code by mutating and watching nothing go red — `mirror_check`'s
CRLF normalisation was the first — so it is in `house-static-checker`.

**The move preview is finished.** Arming an uproot reddens the rings on what a move costs;
hovering a destination during that window now shows what it buys, with the moved plant
excluded from "already covered" — because it is about to stop covering it. Without that
exclusion the destination reports as buying almost nothing, worst exactly where the move
matters most. Cost and gain on one screen.

**And writing the invariant test corrected an assumption:** an expired uproot window
**cancels** rather than uprooting. The first draft planted a second cob and failed on
"something is already growing there".

## Where things stand

Seventy-two beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **561/561**, 12269 assertions; lint 0/0; nine checkers clean including
`settle_read`. Eleven skills. Upstream gh#44 and gh#46 open.

## Waiting on the user

**Weather has no counter-play** (`plant-tower-defense-oo7e`) — unchanged, and still the
only genuinely blocked item.

A second one has appeared that is a real decision rather than a bug: **`-h5w6`, what a move
should cost.** The preview now shows a player exactly what repositioning a plant would do,
and the game then charges them full price to act on it — they must uproot, re-select and
re-buy. Free moves make placement mistakes costless; full price makes the preview cruel;
the refund-minus-cost difference is the middle and is already computed. Worth deciding on
purpose.

The most valuable buildable item is **`-j80m`**: the move tool works and nothing tells the
player it exists. The only hint is a button reading "Really uproot?", which says the
opposite of what the feature does.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself.

**Five standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI
baseline carries twelve overlaps acceptable only while both controls are unreachable. Any
harness operation should start by checking which version the skill's paths point at.
**Never hand-edit `AGENTS.md`** — run `python tools/mirror_check.py --fix`. And **`pause`
right after `launch`** — five cycles running, that is what has made every visual result
trustworthy.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **five** couplings (`-a6bq` is filed to re-read
them, unread since cycle 52); `list-commands --offline` answers "does this verb exist" with
no game running. Bump the number at the top of this file every time you refill.
