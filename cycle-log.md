# Cycle 89

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 89 taught

**A test can pass over nothing, and `[VACUOUS]` cannot see it.** `-0q3q` gave `RunConfig` two
doors — `spend_hint(id, shown)` and `record_milestones` — which refuse each other's ids, so a
hint can no longer be recorded by a code path that never rendered it. `shown` is a *required
argument*, which is the whole design: the old shape was an `if` around `record_milestones`, and
an `if` is something the next hint's author can simply not write.

The finding was in my own test. A derived disjointness check asserted `Milestones.TABLE.has(id)`
over the hint ids — and `TABLE` is an `Array[Dictionary]` keyed by `"id"`, so comparing a String
against Dictionaries is false for every id in the game. **Green, and about nothing.**
`[VACUOUS]` could not catch it because real assertions ran; it surfaced only because
`String(dict)` crashed two lines later, i.e. by luck. **A claim about membership needs the
collection's SHAPE read, not just its name resolved** — that is now
`kanban-idea-pass`'s fifth rule, and the correct idiom was already at
`notebook_screen.gd:505`.

**Two tools earned their keep and one denominator lied.** `suite_reach_check` fired on `is_hint`
as public-and-unnamed — my three tests drove it through both guards and never asserted the
deciding function, which is exactly the seam the change exists to create. And `run_tests.gd`
reported `Total: 531 | Passed: 531 | Failed: 0` on a run that had lost 64 tests to a parse
error, with `Suite: 7 test script(s)` still reading 7. `run_tests.py` caught it. Filed as gh#52,
which reconciliation made much sharper: 0.54.0 already collects the load-failure list and prints
it in one branch that a full run never reaches.

## Carried from cycle 88

**A cue can be present, correct, and out of range.** Ten reachable husk values, and `radius_for`
and `glow_for` both saturate at 9 — six of the ten drew as one husk. `overflow_pips` counts where
the lerp ran out. And **a legibility fix that quietly changes a balance number is two changes**:
`FULL_VALUE` was left alone because `lifetime_for` reads the same fraction.

## Carried from cycle 87

**Don't ask whether you can perceive the effect; ask what the last readable value before it
is.** A muted session verified a new kill sound end to end, because the voice pool is real
nodes — and caught `Voice0` being retuned across two kills, the pooled-voice staleness cycle
74 argued for and never watched.

## Where things stand

A hundred and one beads ready. Suite **596/596**, 12847 assertions; lint 0/0; eleven checkers
clean. No launch this cycle, on purpose and argued in the ledger's `skipped` field — the changed
call site is already driven by a hosted `game.tscn` in the headless suite. **Fifteen skills** —
`kanban-idea-pass` built this cycle and used the same hour, which caught a citation of mine
landing on a doc comment. Upstream gh#44, **gh#51 and gh#52** open; gh#49 and gh#50 closed and
fixed, which moved `-6e2e` off upstream and onto the pin. Still on harness **0.38.0**
deliberately (`-ny3h`, gh#43).

**The player-facing steer is standing, and this cycle bent it.** Cycles 84-88 each shipped
something a player sees; 89 shipped a persistence guard, which a player will never notice. The
sentence step 2 owes: **the hint it protects is one a player was already losing** — cycle 79
burned the move tip unseen, and the fix then was to one call site rather than to the class, so
the next hint was set up to go the same way. `-2ker` is the player-facing half and is filed.
`-a155` is still the cheap half of the board-check problem — transform properties, no pixels.

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
claimed on a claim that was wrong. `-knpc` blocks `-1490` and `-lp97`; `-ip4n` blocks `-l86t`.
`-ei83` is now unblocked and sharpened: a missed hint is a real queryable state, but it cannot be
solved by adding the id to `Milestones.TABLE` — the shelf counts earned off TABLE, so a foreign
id breaks that guard. `-9afm` is the fragility cycle 81 worked around rather than fixed. Two big
ones filed recently and both still untouched: `-bxhg` (the drawn grammar has ten rows and the
game teaches none of them, and both surfaces that look like they could host a legend are the
wrong shape) and `-2ker` (the second one-shot hint, with the three candidate moments already
enumerated and the constraint that rules out the vague ones). `-u4tr` is ready to close — its
work was done in the cycle that filed it.

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
