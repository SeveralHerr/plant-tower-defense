# Cycle 88

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 88 taught

**A cue can be present, correct, and out of range.** `-532j` asked for a measurement before
a build, and the measurement was the whole finding. `Pest.SPECIES` crossed with every
composable mutation set drops ten husk values — {2, 3, 5, 7, 9, 14, 20, 30, 40, 60} — and
`radius_for` and `glow_for` **both saturate at `FULL_VALUE = 9`**. Six of the ten rendered as
one husk, including the comparison the second-mutation feature exists to produce: a beetle's
hungry kill (9) against its armoured-and-hungry kill (14), the same circle at the same
brightness. Nobody had broken anything; cycle 81 made `husk_multiplier` a product and pushed
the ceiling to 60 without re-reading a curve tuned when 9 was the top.

The fix counts instead of lerping — `overflow_pips`, one pip per whole `FULL_VALUE` over,
capped at three, silent at 9. A count because no brightness ramp resolves 6.6×, and because
`FULL_VALUE` could not simply be widened: `lifetime_for` reads the same fraction, so that
would have slowed every husk's rot as a side effect. **A legibility fix that quietly changes
a balance number is two changes.**

**And the ordering bug was in the loop itself.** `-beq1` claimed nothing says a pest carries
two traits. It was shipped **by the cycle that filed it** — `markers_for` returns one mark
per flag twenty lines below the `_tint` call the claim was read from, and the test the
acceptance asked for was written the same day. That is the fourth bead claimed on a false
premise, and step 2 had said "claim the bd issue, write the code" for 88 cycles while
`verify-bd-item`, the skill written for exactly this sequence, says `confirm → claim →
implement`. Step 5 spent its one change fixing that contradiction.

## Carried from cycle 87

**Don't ask whether you can perceive the effect; ask what the last readable value before it
is.** A muted session verified a new kill sound end to end, because the voice pool is real
nodes — and caught `Voice0` being retuned across two kills, the pooled-voice staleness cycle
74 argued for and never watched.

## Carried from cycle 85

A user's screenshot found what 587 tests could not: cues drawing **72 px high** because
`cell_to_world` is board-local. **Nothing checks the board** — and cycle 88 hit the same
coordinate class again, its own first two screenshots empty because `drop_husk` takes an
Entities-local position while `screenshot --region` takes screen space.

## Where things stand

A hundred beads ready. Suite **592/592**, 12824 assertions; lint 0/0; eleven checkers clean;
findings **0 across 5 of 5**; reach 3/3. **Fourteen skills** — `gap-reconcile` built this
cycle, after `log.md` turned out to have named it twice while pre-flight reported otherwise.
Upstream gh#44 open; **gh#49 and gh#50 are now closed and fixed**, which unblocked `-6e2e`
from upstream onto the pin. Still on harness **0.38.0** deliberately (`-ny3h`, gh#43).

**The player-facing steer is standing.** Cycles 84-88 each shipped something a player sees:
weather on the ground, a reported coordinate bug, a flinch, a harder kill sound, a husk that
says how rich it is. `-a155` is still the cheap half of the board-check problem — transform
properties, no pixels — and the one to do first.

## Waiting on the user

**`-ix76` — should a 60-seed husk rot faster than a 9-seed one?** New this cycle and flagged
with `bd human`. Both husks give the player 4.5 seconds, because `lifetime_for` saturates
where the drawing used to. Either 4.5s is a floor on reaction time and the pips are the whole
fix, or the richest drop should be the one you can least afford to miss. The two answers want
opposite code, so this is not a thing to pick by whichever is easier.

**`-oo7e` — weather has no counter-play.**

**`-h5w6` — what should moving a plant cost?**

**`-ogxu` — should a budget floor keep a reserve?** Three HUD rows are at floor because each
was ratcheted down in the commit that spent it; every one was the right local move, and
together they made a HUD with no slack that nobody chose.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`) for
the loop itself. **Confirm a bead's premise before claiming it** — `-g1o4` is the sweep that
does this for the whole open queue, filed this cycle at P1 because four beads have now been
claimed on a claim that was wrong. `-knpc` blocks `-1490` and `-lp97`; `-ip4n` blocks `-l86t`;
`-0q3q` blocks `-ei83` and is the cheapest real win on the board — hints and achievements
share one dictionary and have opposite triggers, which is what let cycle 79 burn a hint
unseen. `-9afm` is the fragility cycle 81 worked around rather than fixed. `-bxhg` is new and
big: the drawn grammar has ten rows and the game teaches none of them, and both surfaces that
look like they could host a legend are the wrong shape.

**Ten standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI findings
baseline is **empty** (`-v9px`). Any harness operation should start by checking which version
the skill's paths point at — and **reconcile a gap against the INSTALLED version, not the
pinned one** (`gap-reconcile`); two of them were already fixed. **Never hand-edit
`AGENTS.md`** — run `python tools/mirror_check.py --fix`. **`pause` right after `launch`**,
but **unpause before `findings`** — except the pause card — and **capture `scene-tree` before
`quit`** or the ledger row loses its reach. **A paused tree does not repaint**: anything
drawing from `_process` holds its old frame, so a change made while paused needs
`run-method --method queue_redraw` on the drawing node (`-rvvt` turns that into one verb).
**Run `run_json_check.py` BEFORE `verify_ledger record`.** **Cut `kanban.md` by line number,
never by heading.** **Write a `bd` description to a file and pass `--body-file`** — `-d "..."`
goes through the shell and backticks are command substitution. And **`set-game-speed` takes
its scale positionally**, not as `--scale`.

`python tools/gap_ledger.py --open` answers "which harness gaps are open" as a fact about the
log, not about the harness; `python tools/citation_check.py` answers "do this file's citations
still land"; `python tools/devtools.py cmd budgets` prices the **seven** couplings;
`list-commands --offline` answers "does this verb exist" with no game running. Live plant ids
are catalogue ids — `corn_cobbler`, not `corn`; **a Chomp must be unlocked before it can be
planted** (`set-state /root/Game/SeedBank unlocked` to a JSON array does it); and a plant is
selected by a real click, which `cmd touch_press`/`touch_release` at its `global_position`
will deliver. `run_tests.py` takes its own flags **after `--`** (`-- --filter husk`), which is
how a mutation pass runs in seconds instead of a minute. To walk a sub-second tween: `pause`
**before** creating it, then `step-time --seconds 0.03 --then-pause`; to verify a fix to a
once-per-save behaviour, `launch --snapshot-userstate` **before** clearing the flag, or the
run writes the developer's real save. Bump the number at the top of this file every time you
refill.
