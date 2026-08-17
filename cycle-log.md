# Cycle 55

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 55 taught

**The bead's design was wrong twice, and reading the code it proposed to change is what
showed it.** `-ivoq` asked for a denser tint on the road where two or more plants reach.

`lane_pressure_overlay.gd` documents that the road's permanent paint is out of channels —
hue on DANGER, alpha on how much pressure a cell took, orientation on
aimed-versus-unaimed — and argues explicitly that a density or a second hue would cost the
property the hatch exists for. And worse: **"redundant" is the wrong frame for a cob.**
`shows_redundant_coverage()` exists but is about Sundew patches, where a second patch
genuinely buys nothing. A cob engages one pest at a time, so a second cob over identical
cells is worth real money — cycle 54 measured that as five cobs losing a pest where seven
do not. A redundancy mark for cobs would have been actively false.

So the cue shipped is the true statement instead: **a dot on every road cell inside the
ring that nothing standing already covers.** Hover-time, transient, spending none of the
overlay's channels. With one cob down, hovering beside it offers three newly-defended
cells and hovering out on the climb offers eight.

**And the screenshot that looked broken was right.** My first live check hovered `(6, 2)`
— which is road — so `_draw()` correctly returned before the dots. Nothing was wrong with
the drawing; the check was aimed at a cell the cue deliberately says nothing about. That
near-miss surfaced a real inconsistency: the predicate answered for an unplaceable cell
while the drawing skipped it. It checks `placeable` now, as `shows_dead_zone()` does.

**Then reviewing my own work found a defect worth fixing rather than filing.** The dots
were pushed only on hover, so a garden change under a still cursor left them stale — a
plant eaten mid-wave, an uproot committing. For a cue read as "spend seeds here" that is
the one unacceptable error. `_refresh()` pushes it now, proved live: eight dots drop to two
when a second cob lands, cursor unmoved.

## Where things stand

Sixty beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on gh#43).
Suite **558/558**, 12231 assertions; lint 0/0; eight house checkers and the mirror all
exit 0. Eleven skills. Upstream gh#44 and gh#46 open.

## Waiting on the user

**Weather has no counter-play** (`plant-tower-defense-oo7e`) — the only genuinely blocked
item, unchanged for many cycles. Water tiles plus a real counter, a cheaper counter needing
no terrain, or weather stays a difficulty modifier.

Player-facing work continues to stack up and is now the majority of the ready queue:
`-nx9o` (what a *selected* plant uniquely holds — the mirror of this cycle's cue, and the
depth read `-ivoq` actually wanted), `-dgu5` (a reach-par on the run summary, now cheap
because `_cover_greedily` computes it), `-tzz7`, `-a6rf`, `-g8kc`, `-f5z6`.

## Restarting

`bd ready` for the work, this file for the context, `CLAUDE.md` (mirrored in `AGENTS.md`)
for the loop itself.

**Five standing notes.** The harness is pinned at 0.38.0 on purpose (gh#43). The UI
baseline carries twelve overlaps acceptable only while both controls are unreachable. Any
harness operation should start by checking which version the skill's paths point at.
**Never hand-edit `AGENTS.md`** — run `python tools/mirror_check.py --fix`. And **`pause`
right after `launch`**: a game left running is a moving value the size of the whole board,
and this cycle lost a screenshot to a run that ended while I was reading code.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the **five** couplings; `list-commands --offline`
answers "does this verb exist" with no game running. Bump the number at the top of this
file every time you refill.
