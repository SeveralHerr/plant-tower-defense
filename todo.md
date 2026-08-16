# todo

**Cycle 25 of 30.** Bump this each time you refill the Items list. See the Workflow
block in `CLAUDE.md` — this list is refilled, never left fully ticked.

> Cycle 24 shipped 5 items via three more parallel git-worktree-isolated subagents:
> `7o3` (a kernel hit now flashes the pest it connects with, `Pest.flash_hit()`),
> `qij` (`StickySundew._next_wash_order` resets once the board's last patch is gone),
> `yzt` (the title screen backdrop gained drifting clouds, swaying tufts, and a
> breathing glow — all gated behind `animations_enabled()`), `9o6` (the notebook's
> page-counter dot now eases toward the target page instead of snapping ahead of the
> turn tween), and `btq` (a real music system — two crossfading Kenney "Music Loops"
> tracks, title/in-run beds, `Sfx`'s mute toggle now silences both). All three
> worktree branches merged clean into `main`; two real merge conflicts, both in
> append-only files two sessions wrote to at the same tail (`log-devtools.md` twice,
> `test/unit/test_selftest.gd` once) — resolved by keeping both sides' content, no
> code lost. Full `/verify` on the merged result: 432/432 tests, clean lint/import,
> live-bridge pass with zero runtime errors, screenshot-confirmed the new ambient
> motion actually renders. Three new juice ideas went into `kanban.md`'s cycle 24
> block, all grown directly from what this cycle just shipped (a partial cue,
> `flash_hit()` only wired to one of three attackers, music's binary volume); this
> cycle's five items are those three plus two pulled forward from the original
> cycle-20/cycle-12 idea backlog that had never been filed.

## Items

- [ ] **1hr — `Pest.flash_hit()` exists and only `Kernel` ever calls it.** A ranged
  kernel hit now flashes the pest it connects with; `ChompFlower._bite()` and
  `StickySundew._claim()` land real damage/kills with no visual tell at all. Call it
  from both at the moment damage lands.

- [ ] **32u — A refused plant upgrade has no denial cue, unlike plant/packet
  purchases.** `Game.upgrade_selected()` (game.gd:1012-1026) still answers an
  underfunded upgrade with only `hud.show_message()` — the exact gap `8kx` closed
  for the other two purchase paths.

- [ ] **gle — Music has exactly one volume: on or off.** `Music.BASE_VOLUME_DB` is a
  fixed constant; the only control anywhere is `Sfx.set_muted()`/`KEY_M`, silencing
  SFX and music together. At minimum, give Music its own mute/volume state.

- [ ] **o2b — A swept husk's seeds appear on the HUD with no visual connection to
  where it was collected.** `Game._click_at` hands the value straight to
  `bank.add_seeds()`; only a queued caption connects the click to the Seeds stat
  changing. A seed glyph flying from the husk's position to the label would carry
  the payout across the screen.

- [ ] **4lv — Three warning colours on the board are the same red at different
  alphas.** Lane pressure, a dying plant's health bar, and an armed Uproot all
  resolve through `GardenTheme.DANGER` — worth a second channel (shape, hatch, tick
  mark) so alpha alone doesn't have to carry three different meanings.

- [ ] **Add cool new features or concrete improvements** (UX, game juice, animations,
  enhancements, or full features) to `kanban.md`.
