# Cycle 62

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 62 taught

**A checker can answer the right question about the wrong set.** `message_corpus_check`
verified that every `show_message()` call site resolves to the corpus. It never asked
whether every string a producer can *emit* is in the corpus — and a producer with N bool
parameters emits 2^N strings, of which the budget prices only the ones somebody typed. That
is the same subset-pricing defect the corpus was built in cycle 52 to end, one level down.

**It found a live instance on its first run.** `next_wave_note` takes two bools and the
corpus priced one of four. Waived rather than padded — but only after *reading the body*:
both flags only ever `parts.append()` and neither substitutes, so `(true, true)` strictly
dominates. The waiver names the two lines that make that true and says what would
invalidate it.

**And my own waiver was not detected**, because I wrote the reason in the comment block
above the call while the checker read only the call's own line. A reason worth reading is
usually several lines long, so it accepts both now — and refuses to let a waiver drift down
across intervening code, which is its own fixture case and its own mutation.

**The ledger row is `overkill`, deliberately.** No game was launched and none was needed;
the fixture and the mutation sweep are a static checker's whole verification. Sixty-two
cycles in, all four `value` verdicts have been used, and this is the one that keeps the
record trustworthy — a run that adds nothing is not evidence.

## Where things stand

Seventy-nine beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **562/562**, 12277 assertions; lint 0/0; nine checkers clean. Eleven skills.
Upstream gh#44 and gh#46 open.

## Waiting on the user

**`-oo7e` — weather has no counter-play.** Unchanged for many cycles.

**`-h5w6` — what should moving a plant cost?** The preview shows a player exactly what
repositioning would do, and the game then charges full price to act on it. Free moves make
placement mistakes costless; full price makes the preview cruel; refund-minus-cost is the
middle and is already computed.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself.

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
