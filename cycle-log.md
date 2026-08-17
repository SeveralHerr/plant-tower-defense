# Cycle 81

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 81 taught

**The check the bead demanded turned the design around.** `-1d07` said to find out whether
an armoured *and* winged pest is unkillable **before** building pairs. It is the opposite:
`MUTATION_ARMOURED`'s only effect on play is doubling a Chomp's chew time, and a winged
pest cannot be grabbed by a Chomp at all — so the pair is **redundant, not lethal**, and
would have paid 1.5 × 1.5 for a trait it cannot use. A payout bug wearing a difficulty
costume. `MUTATION_EXCLUSIONS` states that as data so a fourth mutation forces its author
to classify its pairs.

**And an assertion that had read as an invariant for many cycles was a coincidence of one
RNG draw.** Adding a single `randf()` per mutated pest moved the over-promise simulation's
`escaped_engaged` from 34-of-34 to 20-of-34. Isolated rather than guessed: with the draws
still consumed and the second mutation *never applied*, the failure is byte-identical — so
the stream moved and the behaviour did not. **When a seeded simulation changes, consume the
draws without applying the effect**; that separates "my change broke a test" from "my
change reshuffled a draw the test was asserting", which are different problems.

The derivable claim beside it — `pests_all_covered_untouched == 0` — was untouched and
still passes, which is the evidence for which kind of assertion survives.

## Carried from cycle 80

A live check against persisted state can return a real answer to the wrong question: the
developer's own save had the milestone earned, so it read `true` before and after. Assert
the precondition before driving a one-shot, and clear it only under
`launch --snapshot-userstate`.

## Carried from cycle 79

A budget refusal changed the FEATURE rather than the number: the armed-uproot prompt's tip
and its forfeit clause measured 1064 px against an 876 px row, so they are mutually
exclusive and the one about money wins. `Game.BUDGET_FLOOR` was not touched.

## Where things stand

A hundred and seventeen beads ready. Still on harness **0.38.0** deliberately (`-ny3h`
blocked on gh#43). Suite **580/580**, 12624 assertions; lint 0/0; eleven checkers clean;
findings 0/4. Thirteen skills. Upstream gh#44, gh#49, gh#50 open.

No workflow change — the steps held. The technique went into `log-devtools.md` rather than
a skill because it is one paragraph and belongs beside the run that produced it.

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
`-9afm` is the fragility cycle 81 worked around rather than fixed. The cheapest real win on the board is `-0q3q`: hints and achievements share
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
