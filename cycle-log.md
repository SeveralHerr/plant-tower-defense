# Cycle 71

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 71 taught

**An enumeration over the wrong set is worse than an example, because it looks
exhaustive.** Cycle 70 filed `-e1u3` — "give one plant idle motion" — and justified it by
enumerating every `create_tween()` call on every plant, finding all eight event-driven.
The enumeration was complete and correct and about the wrong set: `Plant._wobble` has
swayed every plant since the first playable build, and `Pest._gait` gives every pest a walk
cycle. Both are `_process`-driven sinusoids, invisible to a census of tweens. **Search for
the property the feature would move, not for the API you imagine it using** — that rule is
now step 3's, and it is the third member of a family (cite a `file:line`; a pattern needs
the enumeration; an absence needs the right set).

What was genuinely missing was narrow: a plant had one animation channel and a pest had
two. `Plant.breathe_scale` is that second channel, and it lives on a new `Sway` pivot
because `_sprite.scale` already has five event owners that all tween back to `Vector2.ONE`.
Idle motion on the parent, flourishes on the sprite: they multiply instead of fighting.

**Two mutations survived and both were about the test, not the code.** Pointing the breathe
straight at `_sprite.scale` passed, because past its `animations_enabled()` gate `_wobble`
does nothing headless — a test that pumps it and reads what moved is testing an unreached
branch. And `BREATHE_AMOUNT = 0.0` passed every assertion, because every assertion was
written *relative to* `BREATHE_AMOUNT`: **a subtle animation and no animation are the same
picture to a test that only checks proportions.** The fix was an absolute floor in pixels.

## Where things stand

Ninety-nine beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite **570/570**, 12543 assertions; lint 0/0; nine checkers clean; findings 0/4.
Twelve skills. Upstream gh#44 and gh#49 open.

## Waiting on the user

**`-oo7e` — weather has no counter-play.** Unchanged for many cycles.

**`-h5w6` — what should moving a plant cost?**

**`-ogxu` — should a budget floor keep a reserve?** Three HUD rows are at floor because each
was ratcheted down in the commit that spent it; every one was the right local move, and
together they made a HUD with no slack that nobody chose.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself. The last three cycles were the message row, the plants' drawing and
the plants' animation — step 2 says look elsewhere. `-hnhn` (audit the rest of the
user's own requested-features list, two of which have now been checked and both were wrong)
and `-4lnu` (a harness verb this project has never used in 71 cycles) are both filed and
both outside.

**Eight standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI
findings baseline is **empty** (`-v9px`). Any harness operation should start by checking
which version the skill's paths point at. **Never hand-edit `AGENTS.md`** — run
`python tools/mirror_check.py --fix`. **`pause` right after `launch`**, but **unpause before
`findings`**, and **capture `scene-tree` before `quit`** or the ledger row loses its reach.
**Cut `kanban.md` by line number, never by heading.** **Never put backticks in a `bd`
description passed through bash** — command substitution eats the word silently. And
**`set-game-speed` takes its scale positionally**, not as `--scale`.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **seven** couplings; `list-commands --offline`
answers "does this verb exist" with no game running. Live plant ids are catalogue ids —
`corn_cobbler`, not `corn` — and a plant is selected by a real click, which
`cmd touch_press`/`touch_release` at its `global_position` will deliver. Bump the number at
the top of this file every time you refill.
