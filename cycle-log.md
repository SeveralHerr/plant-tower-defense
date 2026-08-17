# Cycle 82

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 82 taught

**`reach` refused a verdict I would have written from impression.** Four files changed
across the options screen, the notebook and the summary card; the launch reported
`0 finding(s) across 5 of 5 checks` and every screen built. Clean by every visible measure —
and `reached 0/4 changed file(s)`, because the session sat on the board and **nothing
navigates**. `entry_points` has exactly one entry. So a clean runtime pass on an unreached
diff is a statement about the game, not about the change, and it looks identical to a real
one until you read the row. Step 2 now says to decide how you will reach a screen *before*
launching.

**And the measurement had a finding in it.** Three of the four row-limited surfaces are
exactly full — options 3 of 3, shelf 7 of 7, summary 7 of 7, every hand-written comment
confirmed to the row. The fourth, `TitleScreen`, reports **8 against 5 used** — and it is
the one that already *computed* its ceiling rather than writing the sums in prose. One data
point, filed as `-1y2w` with its confound named, but the mechanism is plausible: a ceiling
you must re-derive is one you meet while already holding a feature.

The test records **measured slack per surface** rather than asserting fullness. A bare
`fits >= used` passes a capacity pointed at the wrong box — proved by mutation: dropping
`FOOTER_GAP` from the options floor satisfies it and fails the slack assertion.

## Carried from cycle 81

The check a bead demanded before building turned the design around: armoured+winged is
**redundant, not lethal**, since armoured's only effect is a Chomp chew time a winged pest
never incurs. And when a seeded simulation changes, consume the draws without applying the
effect — that separates a moved stream from a moved behaviour.

## Carried from cycle 80

A live check against persisted state can return a real answer to the wrong question — the
developer's own save had the milestone earned, so it read `true` before and after. Assert
the precondition before driving a one-shot, and clear it only under
`launch --snapshot-userstate`.

## Where things stand

A hundred and nineteen beads ready. Still on harness **0.38.0** deliberately (`-ny3h`
blocked on gh#43). Suite **582/582**, 12638 assertions; lint 0/0; eleven checkers clean;
findings **0/5 with scene validation included**. Thirteen skills. Upstream gh#44, gh#49,
gh#50 open.

Step 5's one change is in step 2: a diff confined to a screen the entry hook does not open
reaches nothing, and the run looks clean while doing it.

## Waiting on the user

**`-oo7e` — weather has no counter-play.** `-t0vy` is the smaller question that does not
need it answered first: whatever weather does, the player should be able to see it doing it.

**`-h5w6` — what should moving a plant cost?**

**`-ogxu` — should a budget floor keep a reserve?** Three HUD rows are at floor because each
was ratcheted down in the commit that spent it; every one was the right local move, and
together they made a HUD with no slack that nobody chose.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself. `-orcl` is the half of the citation audit no tool can do — read the
landed lines once and record the rot rate. `-knpc` blocks `-1490` and `-lp97`; `-ip4n` blocks `-l86t`; `-0q3q` blocks `-ei83`;
`-9afm` is the fragility cycle 81 worked around rather than fixed; `-jq4l` (named
entry points for every screen) is a config edit that unblocks `-iiyg` and would have made
this cycle's runtime pass mean something. The cheapest real win on the board is `-0q3q`: hints and achievements share
one dictionary and have opposite triggers, which is what let cycle 79 burn a hint unseen.

**Nine standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI findings
baseline is **empty** (`-v9px`). Any harness operation should start by checking which version
the skill's paths point at. **Never hand-edit `AGENTS.md`** — run
`python tools/mirror_check.py --fix`. **`pause` right after `launch`**, but **unpause before
`findings`**, and **capture `scene-tree` before `quit`** or the ledger row loses its reach.
**Run `run_json_check.py` BEFORE `verify_ledger record`.** **Cut `kanban.md` by line number,
never by heading.** **Never put backticks in a `bd` description passed through bash.** And
**`set-game-speed` takes its scale positionally**, not as `--scale`.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/citation_check.py` answers "do this file's citations still land, and how much of it
cites nothing"; `python tools/devtools.py cmd budgets` prices the **seven** couplings;
`list-commands --offline` answers "does this verb exist" with no game running. Live plant
ids are catalogue ids — `corn_cobbler`, not `corn`; **a Chomp must be unlocked before it
can be planted** (`set-state /root/Game/SeedBank unlocked` to a JSON array does it); and a
plant is selected by a real click, which `cmd touch_press`/`touch_release` at its
`global_position` will deliver. To walk a sub-second tween: `pause` **before** creating it,
then `step-time --seconds 0.03 --then-pause`; to verify a fix to a once-per-save behaviour,
`launch --snapshot-userstate` **before** clearing the flag, or the run writes the
developer's real save. Bump the number at the top of this file every
time you refill.
