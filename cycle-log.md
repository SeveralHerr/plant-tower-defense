# Cycle 47

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 47 taught

**`arm_uproot` and `commit_uproot`.** The pair was `request_uproot` (arms a four-second
confirm) and `uproot_selected` (destroys the bed and returns `""`, which is this API's
success value). Neither name carried the destructive word — "request" sounds like the safe
one and is; "selected" names the *subject* rather than the *action*. Last cycle I called
the wrong one while testing the other, and a plant was simply gone with nothing failing.

The rule now lives in the header: **when two functions differ in destructiveness, the names
must differ in the destructive word.** 30 references, `553/553` on both sides — a pure
rename is proved by the count matching, not by the tests passing.

**And a comment named a caller that does not exist.** Both headers claimed the unguarded
mutator is reached by "the devtools verbs and the placement tests". There is no devtools
verb. Worse: I rewrote one of those headers *during this rename* and preserved the false
half before checking it. Corrected in both places; the file's other three verb claims were
verified and are true.

That is the cycle's real lesson — **a comment that cites something is an assertion**, and
citing it while editing is not the same as checking it. `list-commands --offline` settled
it in one command with no game running.

## Where things stand

Thirty-three beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on
gh#43). Suite 553/553 with 12183 assertions; lint 0/0; mirror identical; gap ledger clean;
`findings` clean; the real save's md5 unchanged. Eight skills, backlog empty.

The ledger row for this cycle is **`overkill`**, honestly — the suite did the work and the
launch confirmed two return values the tests already assert.

## Waiting on the user

Unchanged: **weather has no counter-play** (`plant-tower-defense-oo7e`). Water tiles and a
real counter, a cheaper counter needing no terrain, or weather stays a difficulty modifier.
Filed, not started, because building the wrong one of the three is expensive.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`,
checked by `python tools/mirror_check.py`) for the loop itself.

**Three standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI
baseline carries twelve overlaps acceptable only while both controls are unreachable. Any
harness operation should start by checking which version the skill's paths point at.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the seven couplings; `python tools/devtools.py
list-commands --offline` answers "does this verb exist" with no game running. Bump the
number at the top of this file every time you refill.
