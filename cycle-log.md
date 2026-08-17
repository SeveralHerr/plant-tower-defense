# Cycle 61

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 61 taught

**The move tip is shown once, and the acceptance criterion I wrote for it was wrong.**
The tip rides the first uproot ever armed and never again; `RunConfig`'s milestone set is
the flag, which needed no `SAVE_VERSION` bump because `record_milestones` already had
exactly the right semantics. Verified rather than assumed that a non-achievement id is
invisible to the player: the notebook's shelf and its "N of M earned" count both iterate
`Milestones.TABLE`, and that function's own header says so deliberately.

The bead said `cmd budgets` should fall back to ~570 px. It reports **755, `tight`,
unchanged — and correctly.** The corpus now prices *both* forms of the prompt, and the tip
form is still the widest thing the row can ever hold. **A budget measures the worst case
the format allows, not the common case.** The one-shot changes frequency, not the ceiling.
The change is still right, for a better reason: a hint shown once is more likely to be read
than one that has become wallpaper. But "we get 185 px back" was never true, and shipping
that claim would have confused whoever took the next budget reading.

**A mutation survived and this time the test was at fault.** Replacing the warning with the
tip went unnoticed, because I asserted the warning only on the *second* arm — where the tip
is absent and the warning is present however it is composed. The assertion could not fail
in the case I put it in, while the docstring claimed it guarded exactly that. That is now a
rule in `house-static-checker`: **assert a property where it can fail, not where it holds
regardless.**

## Where things stand

Seventy-eight beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **562/562**, 12276 assertions; lint 0/0; nine checkers clean; `findings` 0
across 4 of 5 checks. Eleven skills. Upstream gh#44 and gh#46 open.

Cycle 60's new rule — run `findings` before quitting a launched game — paid on its first
outing, confirming the UI baseline is genuinely empty rather than merely absent.

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
