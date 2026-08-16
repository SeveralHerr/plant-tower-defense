# todo

**Cycle 15 of 30.** Bump this each time you refill the Items list. See the Workflow
block in `CLAUDE.md` — this list is refilled, never left fully ticked.

## Items

- [ ] **dwv — The post-mortem calls your best chokepoint your weakest ground.** P1.
  `Game._note_lane_loss` fires from `_on_pest_died` (every kill, at the pest's position)
  as well as `_on_pest_escaped`, so `_run_losses` counts kills, not damage. That is
  correct for `LanePressureOverlay`, whose own doc says "how far did pests get" — a kill
  at cell 30 of 40 *is* pressure. But `run_summary.gd:201 _worst_cell_text()` labels the
  highest-count cell "Weakest ground — N lost there", so a well-defended chokepoint is
  reported to the player as their weakest ground, every run. The advice is not merely
  useless, it is inverted.

- [ ] **ygh — A damaged plant's health bar eats clicks on the playfield.** P1.
  `Plant._health_back` and `_health_bar` are `ColorRect`s with the default
  `MOUSE_FILTER_STOP`, parked over the board. A damaged plant therefore carries a 32×5
  strip that swallows clicks meant for the cell underneath.

- [ ] **6t4 — Name the husk budget where the road is actually edited.** `board_info`
  now reports it, but reaching that needs a running game, a launched bridge, and knowing
  the verb exists. A designer dragging `Board.PATH_CORNERS` is in `board.gd` in an
  editor, where nothing mentions it. Add a `##` line above `PATH_CORNERS` and above
  `CompostMeter.COLLECT_RADIUS` naming the budget and what spends it.

- [ ] **dhs — `BLOCKED_COLOR` is a hand-typed near-red the palette merge missed.**
  `PlacementPreview.BLOCKED_COLOR` is `Color(0.95, 0.42, 0.36, 0.75)`. It should
  probably alias `GardenTheme.DANGER` — but note it draws brackets, already a shape
  channel, so this is a value change finishing the merge, not a legibility fix.

- [ ] **Add cool new features or concrete improvements** (UX, game juice, animations,
  enhancements, or full features) to `kanban.md`.
