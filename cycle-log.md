# Cycle 52

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 52 taught

**If the number does not move, you have not verified anything.** Widening the message
row's corpus by five previously-unswept strings left the budget reporting 570 of 876 px —
identical to what a completely broken sweep produces. "The new inputs are included and are
narrower" and "the new inputs are silently not included" are the same number. Proved by
mutating a corpus entry to an absurd string (`570 → 1068`, `ok → spent`) and restoring.
That is the second cycle running where a budget fix was unfalsifiable from its own output,
so it is now written into `verify-bd-item`.

**The root cause of three cycles of budget defects was that nobody had written the set
down.** `_budget_hud_message_row` was wrong in cycles 41, 48 and 51, and each fix was
correct about the producer in front of it and silent about the rest. My own cycle-51
comment claimed eight `show_message()` call sites; there are fourteen.
`Hud.message_corpus()` is the set now, and `tools/message_corpus_check.py` ties every call
site to it — five are waived, each with a reason.

**The fixture found two bugs in the new checker within minutes**, both invisible from
reading it: corpus literals read from the blanked source (`1 literal(s)` for a corpus of
five), and an argument span taken from raw text, so a comma *inside* the opening hint cut
it in half and reported it missing from a corpus it was sitting in. Both are kept as
permanent mutations.

Three of this cycle's four findings were in my own work from the last two cycles. That is
not a bad sign — it is what an audit looks like when the audit tool is new.

## Where things stand

Fifty-two beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **556/556**, 12207 assertions; lint 0/0; **eight** house checkers all exit 0;
mirror identical. Eleven skills. Upstream: gh#44 and gh#46 open, both commented with
sharper fixes than they were filed with.

## Waiting on the user

**Weather has no counter-play** (`plant-tower-defense-oo7e`) — still the only genuinely
blocked item, and unchanged for many cycles. Water tiles plus a real counter, a cheaper
counter needing no terrain, or weather stays a difficulty modifier. `-kmjp` (what rain
pays) is downstream of whichever you pick.

Worth knowing: the last four cycles have been almost entirely correctness and tooling.
That is where the work led, and it found real defects every time — but `-uhno` (message
durations), `-f5z6` (deaths that differ by what killed them) and `-84x0` (a road that
climbs) are the player-facing ones sitting ready if you would rather see the game move.

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
