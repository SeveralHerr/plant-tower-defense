# Cycle 46

The narrative half of the loop. `bd` is the work queue and the only place items live —
their status, priority, blockers and close reasons are real fields there. This file holds
what `bd` structurally cannot: which cycle we are on, what the last one taught, what is
waiting on the user, and how to restart. **Never write a work checklist here.** `bd ready`
is the checklist.

## What cycle 46 taught

**The bed an armed uproot will remove now says so** — red brackets at double weight, for
the four seconds the confirm window is open, restored in `_disarm_uproot` (the one place
the arming is cleared, which is why the marker is put back there rather than at its four
callers). Two channels, because `colorblind_safe` exists precisely to make a hue
unreliable, and this project already hatches its lane overlay and notches its regrow bars
for the same reason.

**The marker had no name**, so its path was `@SelectionMarker@31` — addressable from no
test and no bridge command, in a project whose `OverlayScreen` header says outright that
node paths are a contract. Named now. There are 123 `add_child` calls in `game/` against 93
`.name =` assignments, and nothing distinguishes *deliberately anonymous* from *nobody
thought about it*.

**The runtime question the suite cannot ask** was the one worth launching for: a running
tree holds **two** `SelectionMarker`s — the bed's and the placement preview's — and only
the armed bed's may change. `find-nodes --class SelectionMarker --property marker_color
--property line_width` answered both in one call.

**And I nearly filed a defect against my own working code, again.** The first screenshot
showed a yellow marker; `_uproot_left` was `0.0`, the four-second window had lapsed between
the arm call and the capture, and the restore had correctly run. The picture was right and
the capture was late — the same mistake as cycle 38's banner, with the same fix
(`set_game_speed 0.05`).

## Where things stand

Thirty-two beads ready. Still on harness **0.38.0** deliberately (`-ny3h` blocked on gh#43).
Suite 553/553 with 12183 assertions; lint 0/0; mirror identical; gap ledger clean;
`findings` clean; the real save's md5 unchanged. Eight skills, backlog empty.

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

**And one new hazard, filed at P2:** `request_uproot` arms and `uproot_selected` removes.
The names do not say which is which, and calling the wrong one destroys a bed silently.

`python tools/gap_ledger.py --open` answers "which harness gaps are open"; `python
tools/devtools.py cmd budgets` prices the seven couplings. Bump the number at the top of
this file every time you refill.
