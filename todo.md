# todo

**Cycle 26 of 30.** Bump this each time you refill the Items list. See the Workflow
block in `CLAUDE.md` — this list is refilled, never left fully ticked.

> Cycle 25 shipped 4 items via a third round of three parallel git-worktree-isolated
> subagents: `gle` (Music got its own independent mute — `KEY_N`, separate from
> `KEY_M`'s Sfx mute), `1hr` (`Pest.flash_hit()` now fires from `ChompFlower._bite()`
> and `StickySundew._claim()`, not just `Kernel`), `32u` (an underfunded upgrade now
> shakes the Upgrade button and plays `Sfx.PURCHASE_DENIED`, matching plant/packet
> refusals), and `o2b` (a swept husk flies a `SeedGlyph` from its board position to
> the Seeds label). `4lv` (the three-warning-colours idea) turned out to already be
> fixed by an earlier commit — the assigned agent caught this via investigation
> rather than re-implementing, fixed the stale kanban entry instead, and closed the
> bd issue with the explanation. All three worktree branches merged clean into
> `main`; two more append-only-tail conflicts in `log-devtools.md`, resolved the same
> way as every prior cycle (keep both entries). Full `/verify` on the merged result:
> 437/437 tests, live-bridge pass, zero runtime errors. One more harness gap found
> and filed upstream: a silent `OS.alert()` modal from an incomplete `--import` looks
> identical to the already-documented malformed-launch hang — SeveralHerr/godot-selftest-harness#31
> — and the local `godot-devtools-concurrent-launch` skill was updated in place to
> tell the two apart. Two new juice ideas went into `kanban.md`'s cycle 25 block; this
> cycle's five items are those two plus three pulled forward from the original idea
> backlog (cycles 11 and 18) that had never been filed.

## Items

- [ ] **14w — A Sunflower's payout has no sound and no visual glyph.**
  `Game._on_plant_grew_seeds` (game.gd:1013-1014) is one bare line —
  `bank.add_seeds(amount)` — while a swept husk now gets both a sound and a
  `fly_seed_glyph()`. The plant whose entire job is paying seeds is the quieter of
  the two seed-income events.

- [ ] **aho — Starting a wave has no sound of its own.** `_next_wave_button.pressed`
  (hud.gd:486) just emits a signal; `Sfx.WAVE_STARTED` only plays once the wave
  actually starts moments later. The one deliberate click that begins the danger is
  the one press in the whole attack chain with no feedback of its own.

- [ ] **9zn — No `InputMap` — five keys are raw scancode checks, no settings
  screen.** `project.godot` has no `[input]` section; every binding (`R`, `Escape`/`P`,
  `M`, `N`, plus the notebook's own three) is an inline `key.keycode ==` check.
  `Game.KEY_HELP` only ever renders as a legend, never a configurable one.

- [ ] **4qi — No milestones/achievements — `RunSummary`'s totals die with the
  scene.** Everything `summary_rows()` computes vanishes the instant the title
  screen loads; `RunConfig` only ever persists two high scores. A small persisted
  set of milestone flags, checked once at `_end_run`, is most of the feature.

- [ ] **xu0 — A colorblind-safe palette swap for the two red-lerp health/threat
  bars.** The plant health bar and `threat_color()` both ease through the same
  red-family ramp by hue alone — the two combat bars a player watches hardest.

- [ ] **Add cool new features or concrete improvements** (UX, game juice, animations,
  enhancements, or full features) to `kanban.md`.
