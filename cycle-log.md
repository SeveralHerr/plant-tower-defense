# Cycle 48

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 48 taught

**A budget over part of its row always reports more headroom than it has.** Drought now
pays 150% on seed drops and the prep note says so before the wave commits — that was the
bead. The finding was underneath it: `_budget_hud_message_row` measured the four
plant-name messages and never the prep note that *shares that row*, and the note at 570px
is now the widest thing on it against the messages' 534. It had been wrong by 36px for
seven cycles while reporting green, because a budget that sweeps a subset cannot report
anything else. Three of its own description strings still said "catalogue", describing the
corpus it had before this change.

**And I nearly filed a defect against working code for the third time this session.**
`MessageLabel.text` read empty three times while `_idle_message` held the correct note. It
was correct: a transient message outranks the standing note and `_message_left` was 0.43.
Repetition is not determinism — all three reads landed inside the same half-second. `pause`
first, then drain the queue, and it reads right every time.

Three incidents is past the bar for building the skill instead of naming it again, so
`.claude/skills/read-a-moving-value/` now exists. Its cheapest form is one question asked
before writing "this does not work": **what was moving when I read it?**

## Where things stand

Thirty-seven beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite 554/554 with 12193 assertions; lint 0/0; mirror identical; `findings` clean;
the real save's md5 unchanged. **Nine** skills now.

This cycle's ledger row is degraded on purpose and left that way: it says `reached 0/0
changed file(s)` because I recorded it after committing, and rewriting a row to look
better is how a ledger stops being a record. The workflow change fixes the cause.

## Waiting on the user

Unchanged and now more pointed: **weather has no counter-play** (`plant-tower-defense-oo7e`).
Water tiles and a real counter, a cheaper counter needing no terrain, or weather stays a
difficulty modifier. Cycle 48 made it sharper by giving drought an upside — rain is now the
only weather with a downside and nothing to want about it (`-kmjp`), and that rebalance is
downstream of the counter-play decision, so it should not be done first.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`,
checked by `python tools/mirror_check.py`) for the loop itself.

**Four standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI
baseline carries twelve overlaps acceptable only while both controls are unreachable. Any
harness operation should start by checking which version the skill's paths point at. And
**sync `AGENTS.md` by generating it from `CLAUDE.md`, never by retyping** — hand-editing
desynced them again this cycle, on the commit that added a rule about being careful.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the seven couplings; `python tools/devtools.py
list-commands --offline` answers "does this verb exist" with no game running. Bump the
number at the top of this file every time you refill.
