# todo

**Cycle 23 of 30.** Bump this each time you refill the Items list. See the Workflow
block in `CLAUDE.md` — this list is refilled, never left fully ticked.

> Cycle 22 shipped all five items: `o0u` (Corn Cobbler upgrades squash-and-recover on
> the sprite plus a new `Sfx.PLANT_UPGRADED`, reusing `_recoil()`'s shape), `01b`
> (both plant exit paths — eaten and uprooted — now tween the sprite to zero via
> `Plant.play_exit_and_free()`, and uproot got its own `Sfx.PLANT_UPROOTED`), `5dy`
> (`Game.BUDGET_SPENT_BY_DESIGN`, a state distinct from plain "spent" for
> `pest_road_ceiling`, which is spent to the pixel by construction), `73y` (HUD
> readout widths re-proportioned to a flat +10px margin each, funded by trimming
> `STATS_SEPARATION` 14→10 rather than by shrinking any one readout — row headroom
> 8px→19), and `gzm` (`cmd budgets` degrades per entry instead of refusing wholesale
> with no Game in the tree; `road_shape` now stands up its own throwaway `Board`).
> Four new juice ideas went into `kanban.md`'s cycle 22 block. This cycle's items are
> three of those four, plus two pulled from the standing backlog (one of them
> James's own direct ask about pest facing).

> **Paused here at the user's request after cycle 22.** Nothing below is started;
> `129`, `3t9`, `9ti`, `d2a`, `wfq` are filed and ready, along with the kanban-addition
> item. Resume by working the checklist below, starting wherever's convenient — none
> of them depend on each other.

## Items

- [ ] **129 — Pests never turn to face the direction they're walking.** Sprites are
  drawn up-screen per the art style convention, but `pest.gd` has no
  rotation/flip_h/flip_v logic anywhere — a pest walking down, left, or right the
  road still renders facing up-screen the whole way. Requested directly by James.

- [ ] **3t9 — A pest corpse pops out of existence instead of fading.** `_play_death()`
  (pest.gd:484-505) holds the dead-eyes texture for `DEATH_LINGER` (0.35s,
  pest.gd:136) at full opacity, then frees on the spot — nothing tweens
  `modulate.a`. Every other exit in this game fades; this is the one death every
  wave produces dozens of, and it is the one left un-eased.

- [ ] **9ti — RunSummary's entrance does not know whether the run was won or lost.**
  `_build_heading()` (run_summary.gd:144-153) picks a different heading and colour
  for victory, but `_play_entrance()` (run_summary.gd:462-470) rises every Control
  by the same offset over the same duration regardless — no branch on `won`
  anywhere in it.

- [ ] **d2a — Clearing a wave gets a single status-row sentence; starting one gets a
  banner and a sound.** `_check_wave_cleared()` (game.gd:322-338) calls
  `hud.show_message(...)` and nothing else; `_on_wave_started` plays
  `Sfx.WAVE_STARTED` into a 48px banner (game.gd:272, hud.gd:1044-1053). The wave a
  player survives currently announces itself more quietly than the wave about to
  attack them.

- [ ] **wfq — A seed packet's gamble resolves in the same frame it is bought.**
  `SeedBank`'s own header calls a purchase "a gamble... that reads as suspense"
  (seed_bank.gd:8-10), but `buy_packet()` (seed_bank.gd:176-197) deducts, rolls and
  emits `plant_unlocked` in one synchronous call with no beat in between.

- [ ] **Add cool new features or concrete improvements** (UX, game juice, animations,
  enhancements, or full features) to `kanban.md`.
