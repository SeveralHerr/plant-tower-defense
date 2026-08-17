# Cycle 39

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 39 taught

**The prep gap now says what is coming** — `Wave 14 next — 29 pests · a queen.` It names
the three things that change the shape of a wave rather than its size, and it lives in the
message row as that row's idle state, because the top bar is measurably full and "here is
what is coming" is the same kind of thing as "composted a husk for 6 seeds".

**Both defects in it were one omission, and only runtime could see either.** The note
needed writing *and unwriting*, and only the writing was implemented: it never survived a
message expiring (`refresh()` is driven by state changes, and a message expiring is not
one), and it never came down when the wave started (nothing else rewrites that Label, so
the note announcing a wave stayed up for the whole wave). A test that asserts a pure
formatter can see neither. The suite now drives a message to expiry and a wave to starting,
written from what the running game showed rather than from what I imagined would break.

**A backtick in a `bd --description` was executed by the shell**, not stripped. The standing
lesson in `log.md` says backticks "get stripped"; this one ran `last` as a command and
truncated the field. Re-filed through Python's `subprocess` with no shell at all, which is
the actual fix — the lesson was one severity level too mild.

## Where things stand

Nineteen beads ready, none blocked. Suite 547/547 with 12042 assertions; lint 0/0; mirror
identical; gap ledger clean; `findings` clean; the real save's md5 unchanged. Eight skills,
backlog empty.

## Waiting on the user

Unchanged: **weather has no counter-play** (`plant-tower-defense-oo7e`). Water tiles and a
real counter, a cheaper counter needing no terrain, or weather stays a difficulty modifier.
Filed, not started, because building the wrong one of the three is expensive.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`,
checked by `python tools/mirror_check.py`) for the loop itself. `python tools/gap_ledger.py
--open` answers "which harness gaps are open". Bump the number at the top of this file
every time you refill.
