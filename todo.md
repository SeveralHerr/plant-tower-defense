# todo

**Cycle 21 of 30.** Bump this each time you refill the Items list. See the Workflow
block in `CLAUDE.md` — this list is refilled, never left fully ticked.

> Cycle 20 closed out three items: `4p1` shipped (the reach gate now distinguishes
> naming a symbol from co-occurring with an `_T.assert_*` call), the self-test harness
> was refreshed 0.23.0 → 0.24.0 (marketplace + plugin cache had drifted), and 20 new
> juice/UX ideas were added to `kanban.md`'s backlog across plants, pests, HUD,
> economy and meta systems. This cycle's five items are pulled straight from that
> pass — all small, single-plant-or-screen game-juice items with an exact file/line
> pointer already in hand, so none of them need a research pass before starting.

## Items

- [x] **88o — Corn Cobbler needs a readiness readout.** `_cooldown` (corn_cobbler.gd:88)
  is read by nothing outside `_act()`. Sunflower's payout gauge and Chomp's shrinking
  chew ring both already solve this for their own plant; Corn Cobbler is the one plant
  whose "about to fire" moment is invisible.

- [ ] **c03 — `PauseScreen` has no entrance or exit motion.** Its own header calls it
  "shaped after `RunSummary`" for being a card over a live board, but `RunSummary` and
  `TitleScreen` both rise their content in and `PauseScreen` has no `create_tween`
  anywhere in the file — it is also the screen reached for most often, mid-run, under
  time pressure.

- [ ] **t5l — HUD readouts snap instead of punching on change.** `Hud.refresh()`
  overwrites the seeds/lives/compost labels' `.text` outright every call, while the
  same file already eases the wave label's colour with a proper `Tween` in
  `_ease_threat_tint`. Give the three highest-frequency feedback moments (a kill
  payout, a life lost, a husk composted) the motion vocabulary this file has already
  proven out on one label.

- [ ] **yx0 — Selecting a plant has no motion.** `Plant.set_selected()` flips
  `_selection_marker.visible` directly and the brackets snap to full size — no tween,
  unlike the sprite's own 0.4x pop-in on placement. The one deliberate click a player
  makes to inspect a plant's state is currently the one motion-free interaction on the
  board.

- [ ] **8kx — A refused purchase has a sentence and no other feedback.**
  `purchase_failed` reaches only `hud.show_message(reason)`. `Sfx.SOUNDS` has an entry
  for nearly everything else that happens on the board except a purchase bouncing off
  — add a shake on the clicked control plus a denial cue.

- [ ] **Add cool new features or concrete improvements** (UX, game juice, animations,
  enhancements, or full features) to `kanban.md`.
