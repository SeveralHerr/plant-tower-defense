# Cycle 50

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 50 taught

**The same lesson arrived twice in one hour wearing different clothes.** Cycle 49 ended by
writing into `house-static-checker` that a mutation which never applied is not a mutation
that survived. Cycle 50 then ran a sweep against the *test suite* — mutating game code
rather than a checker — and recorded all three mutations as killed. They had not run:
`run_tests.py` takes `--filter` only after `--`, so argparse exited **2** every time, and
`if returncode:` is true for 2. This repo's whole convention is that `2` means *nothing was
verified*.

It was caught only because the **restore** run also came back non-zero, which it had no
business doing. The fix is to read the exit code specifically rather than its truthiness —
`0 SURVIVED / 1 RED / 2 BROKEN RUN` — and to print the denominator (`Selected: 3 of 555`)
beside each verdict. Redone properly, all three mutations killed the test for the right
reasons.

**And a user request turned out to be already shipped, but only the running game could
say so.** "Fix enemy facing direction" is correct in both halves: all four cardinals read
back live, and every pest SVG rests head-up-screen per `STYLE.md:14`. What the runtime pass
bought that reading the code could not: **the road never travels -Y.** Thirty-four route
points, right/down/left/down/right, so the `_facing = 0.0` branch has never executed in a
real game, and `Vector2.UP` was in no test. Three of four cardinals were covered by
accident; the fourth by nothing. Now asserted.

## Where things stand

Forty-four beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **555/555**, 12199 assertions. Ten skills. The seven house checkers were
audited for the truncation defect found in `mirror_check` last cycle: six are immune by
construction, and the one weak spot — an autoload map that returned empty silently — now
reports its count.

## Waiting on the user

**Weather has no counter-play** (`plant-tower-defense-oo7e`) — unchanged, and the only
thing genuinely blocked. Water tiles and a real counter, a cheaper counter needing no
terrain, or weather stays a difficulty modifier. `-kmjp` (what rain pays) is downstream of
it.

Closed this cycle, so it is off your list: **"fix enemy facing direction"** already ships.
Verified on screen, not from the code — the art convention and all four rotations check
out. If it still looks wrong to you, say so and it becomes a bug report about a specific
species rather than a feature request.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself.

**Four standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI
baseline carries twelve overlaps acceptable only while both controls are unreachable. Any
harness operation should start by checking which version the skill's paths point at. And
**never hand-edit `AGENTS.md`** — run `python tools/mirror_check.py --fix`.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the seven couplings; `list-commands --offline`
answers "does this verb exist" with no game running. Bump the number at the top of this
file every time you refill.
