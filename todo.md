# todo

**Cycle 24 of 30.** Bump this each time you refill the Items list. See the Workflow
block in `CLAUDE.md` — this list is refilled, never left fully ticked.

> Cycle 23 shipped 8 items in one go, at the user's explicit request to fan out
> further — three parallel git-worktree-isolated subagents instead of the usual one:
> `129` (pest facing, cardinal-snapped rotation off each route leg), `3t9` (pest
> corpse fades `modulate.a` instead of popping), `9ti` (RunSummary's entrance
> branches on `won` — a faster overshoot rise for a win, a heavier plain rise for a
> loss), `d2a` (wave-clear gets its own banner + `Sfx.WAVE_CLEARED`, not just a
> status-row line), `7mi` (the prep bar pulses once under 2s left), `04x` (`Plant`'s
> dead `_wobble_time` field now drives idle sway), `y62` (Corn Cobbler, Chomp Flower
> and Sticky Sundew each sound their own attack instead of relying on the pest's
> reaction cue), and `wfq` (a packet purchase gets a short flicker through
> candidates before the reveal banner). All three worktree branches merged into
> `main` cleanly (one real conflict, in `log-devtools.md`'s append-only tail — kept
> both entries); a full `/verify` on the merged result stayed at 416/416 with no
> new findings. Two real harness gaps were found and filed upstream along the way
> (`launch -- --devtools-session X` silently fails to wire the bus; `GODOT_USERDATA`
> does not actually isolate `user://` despite what this project's own generated
> CLAUDE.md implies) — SeveralHerr/godot-selftest-harness#28 — plus a local skill,
> `.claude/skills/godot-devtools-concurrent-launch/SKILL.md`, so the next fan-out
> session hits the fix on the first try instead of losing time to it again. Four new
> juice ideas went into `kanban.md`'s cycle 23 block; this cycle's items are exactly
> those four.

## Items

- [ ] **7o3 — A kernel hit and a kernel miss both just vanish.** `Kernel._physics_process`
  (kernel.gd:60-72) calls `queue_free()` identically whether it left the board or
  just landed a hit — no impact flash, spark, or distinct vanish either way. Every
  plant now sounds its own attack and every pest death fades; this is the one link
  between them with nothing marking a connect.

- [ ] **yzt — The title screen has zero motion anywhere.** `TitleBackdrop`'s six
  `_draw_*` functions are all static geometry, no `Tween` in the file. The first
  screen every player sees is now the only one with no idle motion at all, against
  everything else this project has been busy adding.

- [ ] **btq — No music system exists, only one-shot SFX.** `Sfx.SOUNDS` is entirely
  footsteps/impacts/stingers; nothing loops. A bigger ask than the others here —
  stand up a title theme + in-run bed at minimum, respecting the existing mute
  toggle.

- [ ] **9o6 — Notebook page dots snap while the page turns with a tween.**
  `NotebookPage.current_page`'s setter is a bare `queue_redraw()`; the dot jumps to
  the new page a full tween ahead of `_play_turn()`'s own fade.

- [ ] **Add cool new features or concrete improvements** (UX, game juice, animations,
  enhancements, or full features) to `kanban.md`.
