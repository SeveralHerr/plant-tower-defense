# Cycle 43

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 43 taught

**A check that fires hardest at projects which have already fixed the problem.** The HUD
now goes inert behind every overlay — `focus_mode: 0`, `mouse_filter: 2`, verified on a
live tree — which is the correct and documented fix for the defect `findings` surfaced last
cycle. And `findings` still reported all twelve overlaps, because `interactive_overlap`
treats a `Button` as interactive by *class*: neither property excludes it.

So the only way to quiet a correct fix is a baseline, and a baseline keyed on
(rule, node path) will also hide a *genuine* overlap arriving later at the same pair.
Baselined anyway — after reading all twelve, which are one class — and filed as
[gh#42](https://github.com/SeveralHerr/godot-selftest-harness/issues/42) with the proposal
that the check skip controls unreachable by both channels.

**And the upstream loop closed.** gh#39, gh#40 and gh#41 — the three issues filed earlier
this session — are all **closed**, and this machine's plugin cache is now **0.42.0** while
this project still runs 0.38.0. Four releases of fixes are sitting unused, and cycle 37's
entire gap reconciliation was judged against 0.38.0, so every still-open `[G-NNN]` was
assessed against a harness that is now stale. Filed as `plant-tower-defense-ny3h` (P2), to
be done as its own cycle — the refresh touches every harness file and wants a clean
before/after suite count.

## Where things stand

Twenty-seven beads ready. Suite 552/552 with 12107 assertions; lint 0/0; mirror identical;
gap ledger clean; **`findings` clean again**; the real save's md5 unchanged for the seventh
consecutive session. Eight skills, backlog empty.

## Waiting on the user

Unchanged: **weather has no counter-play** (`plant-tower-defense-oo7e`). Water tiles and a
real counter, a cheaper counter needing no terrain, or weather stays a difficulty modifier.
Filed, not started, because building the wrong one of the three is expensive.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`,
checked by `python tools/mirror_check.py`) for the loop itself.

**Two standing notes.** `user://ui_findings_baseline.json` now carries twelve accepted
overlaps that are only acceptable while both controls are unreachable — re-read it rather
than carrying it forward blindly, especially after gh#42 lands. And the harness refresh
(`-ny3h`) should come before any further gap work, since the open gaps were judged against
0.38.0.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the seven couplings. Bump the number at the top of
this file every time you refill.
