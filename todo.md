# todo

**Cycle 19 of 30.** Bump this each time you refill the Items list. See the Workflow
block in `CLAUDE.md` — this list is refilled, never left fully ticked.

## Items

- [ ] **1av — Assert what `Pest.died` and `escaped` carry.** 15 signals still have
  nothing asserting their payload, down from 17. `Pest.died` is the highest-value one
  left: it is the income path with the most wiring under it — `Game._on_pest_died` drops
  the husk, banks the seeds and notes the lane loss. `escaped` is its pair. Assert what
  the signal carries and which paths fire it; merely *naming* it satisfies the reach gate
  while proving nothing.

- [ ] **zsb — Find tests that read state straight after `instantiate_scene`.**
  `test_hosting_a_loaded_cob` asserted a volley had fired by the time `instantiate_scene`
  returned. That frame count is unspecified, so the test was order-dependent — green two
  cycles, red the moment unrelated tests shifted timing. Any test reading a group or a
  live property straight after `instantiate_scene` without awaiting a *condition* has the
  same exposure. A checker for that shape would name them.

- [ ] **egu — Tell the player unaimed ground still gets kills.** Coverage is now measured
  in both directions and neither number is in the game. Under-promise: 7 kills on unaimed
  ground at up to 202px, because a kernel flies until it leaves the board. Over-promise at
  the pest: **zero of 116**. The board says "unaimed", which is exactly right — but a
  player never learns that unaimed ground still gets kills, which is the thing that would
  stop them over-buying cover.

- [ ] **4p1 — Distinguish naming a symbol from checking it.** `suite_reach_check`
  concedes *"naming is a floor, not exercise"* — a test writing `WaveDirector.reset()` and
  asserting nothing counts as reach. The honest upgrade is not a stricter name match but a
  second signal: whether the symbol appears inside an `assert_*` argument, or only in a
  statement. That separates "called it" from "checked it" without pretending to understand
  the test.

- [ ] **Add cool new features or concrete improvements** (UX, game juice, animations,
  enhancements, or full features) to `kanban.md`.
