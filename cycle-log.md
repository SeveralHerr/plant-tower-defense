# Cycle 63

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 63 taught

**The message corpus is checked three ways now**, and the third is the sign flipped: a
producer that IS priced and can no longer be produced, because its last caller was deleted.
The row's budget reports the widest string in the corpus, so a dead producer sets a ceiling
the game cannot reach — a permanent tax on every future message for a sentence no player
will ever see.

**It found nothing, and that is the honest result to record.** All seven producers have
callers. A drift guard that is clean the day it is written is the normal case; the fixture
is the whole of its evidence, which is why it got four cases rather than one. The subtle
one: a producer called only from *elsewhere in the HUD* is reachable text, not dead.

**Writing it caught two defects, both mine, both from the fixture.** The rule printed a
`waive:` hint and ignored waivers entirely, because the lookup lived inside the other
rule's loop. And adding the rule broke the two older fixtures — correctly, since minimal
stubs declare producers with no callers. Running all three fixtures every time is what
caught that; running only the new one would have shipped a checker whose own test suite was
two-thirds red.

**And the loop noticed itself drifting.** Cycles 60 and 61 both worked the HUD message row;
62 and 63 both worked one Python checker. Each was the honest next thing, because finishing
a piece of work is what exposes the next piece of it. Step 6 already forces one *filed* item
to come from outside the neighbourhood; nothing forced the **work** to vary. It does now.

## Where things stand

Eighty-two beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on gh#43).
Suite **562/562**, 12277 assertions; lint 0/0; nine checkers clean. Eleven skills. Upstream
gh#44 and gh#46 open.

Two `overkill` ledger rows in a row, both deliberate: a static checker's verification is its
fixture and its mutation sweep, and launching the game "to have a runtime row" would make
the ledger worth less, not more.

## Waiting on the user

**`-oo7e` — weather has no counter-play.** Unchanged for many cycles.

**`-h5w6` — what should moving a plant cost?** The preview shows a player exactly what
repositioning would do, and the game then charges full price to act on it.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself. **Next cycle should take something away from the HUD and away from
`tools/`** — that is now a rule in step 2, and `-fqj2` (audit kanban's oldest sections) or
`-f5z6` (deaths that differ by what killed them) are both a long way from either.

**Five standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI findings
baseline is **empty** (`-v9px`) — every `ui_layout` finding gates as NEW until it is
re-captured, and it should be checked rather than banked. Any harness operation should start
by checking which version the skill's paths point at. **Never hand-edit `AGENTS.md`** — run
`python tools/mirror_check.py --fix`. And **`pause` right after `launch`**, remembering it is
a tool and a hazard in one command.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **five** couplings (`-a6bq` to re-read them all);
`list-commands --offline` answers "does this verb exist" with no game running. Bump the
number at the top of this file every time you refill.
