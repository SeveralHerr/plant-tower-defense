# Cycle 49

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 49 taught

**A fixture written to test one thing found a defect in something else.** `mirror_check`
scoped its comparison between a `# workflow` heading and an end marker, and that marker
list contained `\n---\n` — ordinary markdown. Feed it a block containing a horizontal
rule and *both* files stop at the rule: two 21-character stubs compare identical and the
tool reports clean over a fraction of the text. That is the empty-denominator failure the
house checker contract exists to prevent, sitting inside the checker that enforces it.
The fixture case that found it was written expecting to test the post-write re-check.

The general form is worth carrying: **every checker that scopes by a text marker can
silently measure a stub**, and the guard is the denominator rule already in the skill,
applied to the input instead of the output.

**And step 0's skills bullet paid for the first time.** It caught `verify-bd-item` named
as missing in two separate cycles and never built — with cycle 48's degraded ledger row
as proof it was needed, since that is exactly the dropped step it predicted. The bullet
had been a write-only list for 33 cycles. Reading it at the *start* of a cycle is what
changed.

## Where things stand

Forty-one beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on gh#43).
Mirror identical and now **generated rather than retyped** — `mirror_check.py --fix`
exists and this cycle's own `AGENTS.md` was produced by it. **Ten** skills.

No game was launched this cycle and no ledger row written: everything touched was
`.claude/skills/`, `tools/`, or markdown. Phase 0.5 tier (a), logged as `overkill —
avoided` rather than left silent.

## Waiting on the user

Unchanged: **weather has no counter-play** (`plant-tower-defense-oo7e`). Water tiles and a
real counter, a cheaper counter needing no terrain, or weather stays a difficulty
modifier. Giving drought an upside last cycle made rain the only weather with nothing to
want about it (`-kmjp`), and that rebalance is downstream of this decision.

One thing worth your eye, not a blocker: **"fix enemy facing direction"** — one of the
four things you asked for directly — looks like it already ships. `_update_facing()` picks
all four cardinals, `_apply_facing()` composes them with the gait, and a test asserts it.
Filed as `-ymth` to be checked on screen rather than closed from the code, because you
asked about what the screen looked like and the code implementing a thing is not evidence
the screen shows it. If it still looks wrong, the defect is probably one species' art not
resting up-screen — a much smaller job than it reads as.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself.

**Four standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI
baseline carries twelve overlaps acceptable only while both controls are unreachable. Any
harness operation should start by checking which version the skill's paths point at. And
**never hand-edit `AGENTS.md`** — run `python tools/mirror_check.py --fix`, which
generates it and re-checks from disk.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the seven couplings; `python tools/devtools.py
list-commands --offline` answers "does this verb exist" with no game running. Bump the
number at the top of this file every time you refill.
