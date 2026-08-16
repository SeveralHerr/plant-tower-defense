# todo

**Cycle 14 of 30.** Bump this each time you refill the Items list. See the Workflow
block in `CLAUDE.md` — this list is refilled, never left fully ticked.

## Items

- [ ] **842 — Show lane pressure during prep, not after the run.**
  `LanePressureOverlay` paints how far pests got, decayed once per wave, so it is a
  readout of the wave that *just ended* — shown during the eighteen seconds you spend
  deciding what to build for the wave that has not started. `Board.run_pressure_alpha`
  exists and `show_run_pressure()` reveals it exactly once, at the moment the run is
  already over. The number that would inform a purchase is the one held back until
  purchasing has stopped.

- [ ] **a1k — Put `husk_click_margin()` in `board_info` so the budget is visible before
  a test fails.** It exists because the husk-versus-placement conflict is four pixels
  from being real, and a test asserts the clearance stays positive. Nothing tells a
  designer moving `PATH_CORNERS` or `COLLECT_RADIUS` that they are spending it — they
  find out from a failing test, with no indication that four pixels was the whole
  budget.

- [ ] **e0m — Give the board a second warning channel so red is not carrying three
  meanings.** `GardenTheme.DANGER` now paints lane pressure ("pests got this far"), the
  plant health bar ("this plant is dying") and an armed Uproot ("you are about to
  destroy this") — three different sentences in one hue at three alphas. Unifying the
  *value* was right; the open question is whether colour alone should carry all three.
  Add a shape or hatch channel.

- [ ] **ch3 — Separate what is true of *a* road from what is true of *this* road.**
  `PATH_CORNERS` produces 32 road cells and 2112px of walking, and four things are
  calibrated against that specific route: the endless road budget's pests-per-cell, the
  Sundew's coverage arithmetic, the dead-ground count of 15 of 94 cells, and the husk
  clearance. Each is individually tested, which is good — but a second route would move
  all four at once, and nothing says which are properties of a road and which of this
  one.

- [ ] **Add cool new features or concrete improvements** (UX, game juice, animations,
  enhancements, or full features) to `kanban.md`.
