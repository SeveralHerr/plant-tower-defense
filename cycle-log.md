# Cycle 65

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 65 taught

**A corpse can say what killed it.** Bitten is squashed *across* the body — a Chomp closes
on the whole pest, so the corpse is narrower, not shorter. Blasted is tilted off its facing
— a bomb throws the body off the line it was walking. Everything else keeps the straight
corpse, deliberately: the plain one should be the common case, so the two that differ read
as remarkable rather than as noise.

**`_T.assert_lt` does not exist, and my test called it.** The call aborted the method and
`run_tests.gd` reported `[PASS]`, because an aborted coroutine returns `""` — identical to a
genuine pass. `run_tests.py` caught the `SCRIPT ERROR` the return value cannot carry,
exactly as its docs describe. **The tell in the numbers is the thing to remember: same test
count, assertions 12279 → 12287 after the fix.** A cycle that adds a test and no assertions
is the shape to look for.

**And the ledger sent me back to do the verification properly.** The first run reached
**1/3**: every kill went through `kill()` directly, so *neither edited call site was ever
loaded*. Driving a real Chomp bite — plant one, spawn aphids, poll for `_death_cause=bitten`
— took it to 2/3. `game/seed_bomb.gd` is still unreached at runtime and is named as such
rather than glossed.

## Where things stand

Eighty-six beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **563/563**, 12287 assertions; lint 0/0; nine checkers clean; `findings` 0
across 4 of 5. Eleven skills. Upstream gh#44 and gh#46 open.

The `findings` rule from cycle 60 gained a clause: **run it unpaused.** Two false alarms
now — a panel caught mid-entrance-fade in cycle 60, a label whose HBox had not finished
laying out in this one. `pause` freezes containers as readily as tweens.

## Waiting on the user

**`-oo7e` — weather has no counter-play.** Unchanged for many cycles.

**`-h5w6` — what should moving a plant cost?** The preview shows a player exactly what
repositioning would do, and the game then charges full price to act on it.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself. Step 2 now says take work away from the last two cycles' subsystem —
this one was pest death, so pick something else.

**Six standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI findings
baseline is **empty** (`-v9px`). Any harness operation should start by checking which
version the skill's paths point at. **Never hand-edit `AGENTS.md`** — run
`python tools/mirror_check.py --fix`. **`pause` right after `launch`**, but **unpause before
`findings`**. And **cut `kanban.md` by line number, never by heading** — the section
headings are not unique and `uniq -d` will not tell you.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **five** couplings (`-a6bq` to re-read them all);
`list-commands --offline` answers "does this verb exist" with no game running. Bump the
number at the top of this file every time you refill.
