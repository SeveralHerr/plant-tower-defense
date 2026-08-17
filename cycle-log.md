# Cycle 33

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to pick the loop back up. **Never write a work checklist
here.** `bd ready` is the checklist.

## What cycle 33 taught

**Every UI test here builds a screen, asserts, and frees it — so "the state changed while
the screen was open" was an untested class.** The pause card now derives its own width
from its widest legend row, which made it 365px for the shipped keys, narrower than any of
the three hand-picked widths it has had. The refresh path measured against
`key_row_max_width()`, which re-derives from the *new* bindings — so rebinding a key while
the card was open laid the columns out for the card that rebinding **would** produce and
put a 247px phrase 52px off the 365px card that exists. The fix for a legend running off
the card had reintroduced a legend running off the card, one code path over, and the
headless suite was green over the whole thing. It took rebinding through the bridge and
reading the geometry back.

That is filed as its own item (`plant-tower-defense-2tpm`): the notebook, the options screen
and the HUD all have refresh paths and none has a test that changes something underneath an
open screen.

**Second lesson, cheaper:** three hand-picked widths in a row, each correct until the thing
it measured changed, is the same story `card_height()` stopped telling two constants above
it. Four more panels in this project are still hand-picked rectangles.

**And [G-054] happened again — with the mitigation in use.** `launch --snapshot-userstate`
was passed, the snapshot was taken correctly, and after `quit` the developer's save still
carried the run's write; a later bare `quit` restored from that same snapshot properly. The
machinery works and the ending quit skipped it. Reported on
[gh#40](https://github.com/SeveralHerr/godot-selftest-harness/issues/40) with the evidence,
along with the smaller ask it argues for on its own: `quit` should say what it did with the
snapshot every time, including "nothing", and exit non-zero when it was asked to restore and
could not.

## Where things stand

Eleven beads ready, none blocked. Suite 539/539 with 11979 assertions; lint 0/0; mirror
identical; the real save's md5 is back to its cycle-30 value. `.claude/skills/` holds
eight and the skills-to-create backlog is still empty. Three harness gaps upstream
([gh#39](https://github.com/SeveralHerr/godot-selftest-harness/issues/39),
[gh#40](https://github.com/SeveralHerr/godot-selftest-harness/issues/40)); nothing fixed
there yet.

## Waiting on the user

Nothing is blocking. The two standing decisions are unchanged — no expressed preference
between 33 cycles of backlog entries, and `kanban.md` (~1930 lines) still says at its own
top that roughly half of it is stale, with the audit skill only ever run on whatever is in
the way.

Last cycle flagged that the pause card had grown to 440px for every player. That is
resolved rather than waiting: it is 365 now, and it grows only for someone who actually
binds a long key name.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`,
checked by `python tools/mirror_check.py`) for the loop itself. Bump the number at the top
of this file every time you refill.
