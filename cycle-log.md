# Cycle 51

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 51 taught

**A skill is an essay until you point it at code you did not write it about.**
`scope-vs-claim` was built this cycle — the idea that a check *covers* a scope in code and
*states* one in prose, and that nothing compares the two, so the code can fail and the
sentence cannot. Turned on the budget system immediately, it found four things in about
twenty minutes:

- `_budget_hud_message_row` was still missing **five of eight** `show_message()` producers,
  a full cycle after I "fixed" it. Last cycle's fix added exactly the one I happened to be
  looking at — the same mistake, one layer along.
- `WORST_CASE_TEXT` was asserted in one direction only: a readout added to the row with no
  declaration was invisible to the test *and* to the budget that sweeps the same table.
- `stats_row_budget()` holds a **second** hand-list of the same four readouts, and nothing
  knew it was a second list. There are in fact three.
- And a stale sentence in **this file**: the standing note said `cmd budgets` "prices the
  seven couplings". `BUDGET_FLOOR` has five keys and `budget_entries` builds five.

That last one is the argument in miniature. The sentence had been read every cycle for
weeks and was never once wrong enough to notice.

**The other lesson: a fix whose number does not move proves nothing on its own.** Widening
the message-row sweep left it at 570 of 876 px, because the prep note still wins. That
result is identical to the one a completely broken sweep would produce. Settled by
mutating a producer to an enormous string — `spent 570 → 1065`, `state ok → spent` — and
restoring.

## Where things stand

Forty-eight beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **555/555**, 12201 assertions; lint 0/0; mirror identical. **Eleven** skills.
Two upstream issues open from this project: gh#44 and gh#46.

The workflow gained one rule: **build a skill and use it the same cycle**, on real code,
before the cycle ends. A skill built and never applied fails the same way one identified
and never built does.

## Waiting on the user

**Weather has no counter-play** (`plant-tower-defense-oo7e`) — still the only thing
genuinely blocked, and unchanged. Water tiles and a real counter, a cheaper counter needing
no terrain, or weather stays a difficulty modifier. `-kmjp` (what rain pays) sits
downstream of whichever you pick.

Nothing else needs you. "Fix enemy facing direction" was closed last cycle as already
shipped, verified on screen.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself.

**Four standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI
baseline carries twelve overlaps acceptable only while both controls are unreachable. Any
harness operation should start by checking which version the skill's paths point at. And
**never hand-edit `AGENTS.md`** — run `python tools/mirror_check.py --fix`.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **five** couplings; `list-commands --offline`
answers "does this verb exist" with no game running. Bump the number at the top of this
file every time you refill.
