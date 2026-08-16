# todo

**Cycle 28 of 30.** Bump this each time you refill the Items list. See the Workflow
block in `CLAUDE.md` — this list is refilled, never left fully ticked.

> Cycle 27 shipped all four items across three parallel worktree agents: `ac0` (the
> Keys screen got a second door from the pause card), `qar` (a milestone shelf page in
> the notebook, every entry earned or not, with three non-colour channels), `b6v` (the
> in-world plant health bar joined the other two on the colourblind-safe ramp), and
> `lgv` (an Options screen reading and writing all three persisted flags). The harness
> was bumped twice, 0.25.0 → 0.32.0 → 0.33.0. Final state 488/488.
>
> **Three things worth carrying forward.** The `b6v` agent found what its own issue
> did not name: routing the colour through the switch alone would leave an
> already-chewed plant on the old ramp until something bit it again, so it added a
> repaint. The `lgv` agent caught an assertion of its own that would have *passed for
> the wrong reason* — `queue_free()` does not land inside a unit-test frame, so its
> "screen is gone" check was reading the just-closed corpse — and rewrote it to count
> live children. And a partial `--import` produced 11 false failures that read exactly
> like a branch regression; it proved they predated its change by stashing to HEAD
> rather than chasing them.
>
> Upstream: filed SeveralHerr/godot-selftest-harness#33 — a live pass silently writes
> the developer's real `user://` save, and because `RunConfig` loads it at autoload
> startup that leaked into the *headless* suite earlier this session and failed three
> tests, looking for all the world like the harness upgrade had broken something.
>
> This cycle's items are the two ideas from cycle 27's kanban block plus the three
> follow-up beads the agents filed against their own work.

## Items

- [ ] **q7b — Three overlays build the same chrome three times.** Keys, Options and the
  notebook each hand-roll `Backdrop`/`Paper`/`BackButton`/`back_requested`, and state
  the same footer-GAP rule twice. Extract an `OverlayScreen` base; keep the node-path
  contracts, which the bridge and `test_selftest.gd` press by name.

- [ ] **v6c — Persist the two mute flags beside `colorblind_safe`.** The Options screen
  now shows all three in one list, which makes it visible that two of them forget on
  restart. Bump v5→v6, migrate forward, keep the single `compose_save` shape, add
  round-trip and reads-forward tests. **Read `RunConfig.SAVE_VERSION`'s header first** —
  v3/v4 are refused because two agents each minted one, and this must not become the
  second instance of that.

- [ ] **syq — Reach the Options screen mid-run from the pause card.** Exactly the
  `ac0` shape one screen along. `PauseScreen.card_top()` now centres the card and
  absorbs half of each row it gains, so the room is there — but re-check it against a
  real viewport rather than assuming.

- [ ] **neg — The longest pause-card legend row draws past the paper.** `KeyRow4` reads
  `316,553 326x26` against a card ending at x=608: the Label's minimum size beats its
  assigned 264 width, so "colourblind-safe health and threat bars" spills ~34px onto
  the backdrop. Nothing gates it — the layout test checks vertical fit and pairwise
  overlap only, and `clip_text` makes `get_minimum_size()` useless for the obvious
  width assertion.

- [ ] **w5k — The title column has no sixth slot at any price.** Five buttons, every
  constant at its floor (heights 44/40 against a 40 touch-target gate, gap 8). Decide
  the shape before the next destination needs one.

- [ ] **Add cool new features or concrete improvements** (UX, game juice, animations,
  enhancements, or full features) to `kanban.md`.
