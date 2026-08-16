# todo

**Cycle 16 of 30.** Bump this each time you refill the Items list. See the Workflow
block in `CLAUDE.md` — this list is refilled, never left fully ticked.

## Items

- [ ] **cl6 — A budgets verb that prints every declared coupling with its headroom.**
  Four constants now carry "moving me costs you X" comments: `PATH_CORNERS`,
  `COLLECT_RADIUS`, `SUBHEAD_MAX_WIDTH` and the HUD's `WORST_CASE_TEXT` budgets. Each
  warns about a coupling that lives in another file, and a person only finds the warning
  by editing that exact line. A devtools verb printing every declared budget with its
  current headroom makes the set visible *before* someone goes looking.

- [ ] **e34 — The post-mortem names a cell the road under it may not be reddest at.**
  `stop_cell` is losses-minus-escapes; the tint under the translucent summary card is
  still painted from raw losses. On a bleeding run the named cell and the reddest cell
  genuinely differ. That is correct and documented, but a player looking from the number
  to the picture is told nothing. Either the card points at its own cell, or the tint
  under it switches to stops.

- [ ] **2z8 — An escape records nothing about how it happened.** `_on_pest_escaped`
  files every escape against `Board.exit_cell()`, because the pest's own position is
  off-board by the time the signal fires. Eight beetles through one gap and eight
  stragglers spread over forty waves produce byte-identical evidence. The pest knows
  where it entered the exit cell from, how long it survived, and what it walked past
  untouched.

- [ ] **htt — Nothing stops the sixth world-space Control forgetting the rule.**
  `Plant` and `Pest` each grew a `_make_world_controls_click_through()`, deliberately
  duplicated rather than shared. Two copies of a rule with no third enforcement. The
  test enumerates the live tree, so it *would* catch a new offender — but only one on
  screen during that test. A Control that appears only on a boss wave, or in a menu the
  test never opens, is invisible to it.

- [ ] **Add cool new features or concrete improvements** (UX, game juice, animations,
  enhancements, or full features) to `kanban.md`.
