# todo

**Cycle 22 of 30.** Bump this each time you refill the Items list. See the Workflow
block in `CLAUDE.md` — this list is refilled, never left fully ticked.

> Cycle 21 shipped all four items: `c03` (PauseScreen rise-in/fade-out, borrowing
> RunSummary's own constants), `t5l` (seeds/lives/compost readouts scale-punch on
> change, reusing `_ease_threat_tint`'s kill-and-restart shape), `yx0` (selection
> brackets grow in instead of snapping, `PlacementPreview` deliberately left instant),
> and `8kx` (a refused purchase now shakes the control reached for and plays
> `Sfx.PURCHASE_DENIED`). Four new juice ideas went into `kanban.md`'s cycle 21 block.
> This cycle's items are the three small standing tasks from `cmd budgets` that were
> already filed and still open, plus two fresh ones pulled straight from cycle 21's
> kanban pass.

## Items

- [ ] **5dy — `SIMULTANEOUS_PEST_CEILING` is fully spent and nothing said so.**
  `cmd budgets` reports the pest road ceiling at 40 of 40, 0 left, state 'spent' — by
  construction, since the group shares sum to it exactly. Decide whether 'spent by
  design' deserves a state distinct from 'spent because you ran out'.

- [ ] **73y — Two HUD budgets sit within 8px of their ceilings.** `cmd budgets` reports
  `hud_readouts` at 161 of 168px and `hud_stats_row` at 1104 of 1112px, both 'tight' by
  the verb's own <15% threshold. The row sum is the coupling: widening any one readout
  is paid out of it. Worth re-proportioning before the next readout is added rather
  than after.

- [ ] **gzm — `cmd budgets` refuses to answer without a Game in the tree.** It returns
  'no Game in the tree' on the title screen, but two of its six entries don't need one:
  `notebook_subhead` builds its own SubViewport and `road_shape` reads Board statics.
  Degrade per entry instead of refusing wholesale.

- [ ] **o0u — Corn Cobbler upgrades have no moment of their own.** `upgrade()`
  (corn_cobbler.gd:290-297) bumps `level` and redraws — a static fact the muzzle fan
  picks up next paint, not a cue at the instant the seeds are spent. Contrast
  `ChompFlower._bite()`, which squashes its sprite on every single meal.

- [ ] **01b — A plant leaving the board always vanishes silently.** Both the eaten path
  (`Game._on_plant_destroyed`) and the uprooted path (`Game.uproot_selected`) end in a
  bare `plant.queue_free()` with no exit animation; uproot has no `Sfx.play()` call at
  all. Neither tweens the sprite out the way placement tweens one in.

- [ ] **Add cool new features or concrete improvements** (UX, game juice, animations,
  enhancements, or full features) to `kanban.md`.
