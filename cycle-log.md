# Cycle 38

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 38 taught

**The game got its first tested animation.** A new high score now rolls up from the record
it beat instead of appearing — verified in the running game at 5% speed, reading
`Campaign 301` → `302` → `303` and settling exactly on 308. Three things make it a feature
rather than an effect: it rolls from the record that actually fell (`RunConfig.previous_best`,
session-only), the moving line and the settled line come from one pure renderer, and the
label holds the final text *before* the tween exists — because headless pumps no frames, so
an animation responsible for reaching the right state leaves the wrong state on screen in
every test.

**And I muted the tool that was answering me.** Four sampling attempts showed a static
label and I started doubting the feature. The cause was `press --node .../PlayButton` — the
button is called `StartButton`, and the verb had been printing `Node not found` with exit 1
the whole time. I had written `> /dev/null 2>&1` on it and never read the code. I was one
step from filing "`press` reports success on a node that does not exist" as a harness gap;
it does no such thing, and I checked before writing it down. **Check the tool is actually
silent before filing a gap about its silence.**

The second half of the cycle went to the local `house-static-checker` skill: an
advisory-vs-gate rule (if the reader cannot action it, it is a NOTE and the tool exits 0)
and a "keep the mutations in the docstring" rule — suggested four times, and this cycle was
the fourth re-derivation of the same patches. Last cycle I said I would file that upstream;
it is a *local* skill, so the fix was an edit, which is better.

## Where things stand

Eighteen beads ready, none blocked. Suite 545/545 with 12028 assertions; lint 0/0; mirror
identical; gap ledger clean; the real save's md5 unchanged. Eight skills, backlog empty.

## Waiting on the user

Unchanged: **weather has no counter-play** (`plant-tower-defense-oo7e`). Water tiles and a
real counter, a cheaper counter needing no terrain, or weather stays a difficulty modifier.
Filed, not started, because building the wrong one of the three is expensive.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`,
checked by `python tools/mirror_check.py`) for the loop itself. `python tools/gap_ledger.py
--open` answers "which harness gaps are open". Bump the number at the top of this file
every time you refill.
