# todo

**Cycle 17 of 30.** Bump this each time you refill the Items list. See the Workflow
block in `CLAUDE.md` — this list is refilled, never left fully ticked.

## Items

- [ ] **2yz — Sweep `test/` for other group reads taken by index.** P1.
  `test_kernels_launch` read `kernels[0]` out of a tree-global group and measured a
  *leaked* object every run — green for months, red the moment four unrelated tests were
  appended. Nothing enumerates the other group reads (`pests`, `husks`, `kernels`,
  `plants`); any taken by index has the same defect. A sweep for
  `get_nodes_in_group(...)[0]` across `test/` finds the rest in one pass.

- [ ] **02k — Tests leak nodes into groups and nothing notices.** The root cause under
  2yz: a test that builds a `Kernel` and never frees it leaves it in the group for every
  later test. `_T.free_ui` is called on hosts, but a kernel spawned by `_act` is parented
  to the host's *parent*, not the host. A per-test assertion that group counts return to
  where they started would catch the whole class.

- [ ] **8fg — Warn at startup when a budget crosses its own tight threshold.**
  `cmd budgets` reports tight/spent from outside, but nothing inside the game reacts —
  and it currently says three tight, one spent. A startup `push_warning` means the next
  person to spend one hears about it on the next run rather than on the next audit.
  Reuses the entries the verb already computes.

- [ ] **jrj — Map where the garden never reached, not just that it didn't.**
  `was_engaged()` answers one question at one instant, at the exit. The same flag sampled
  per road cell would say *where* the garden stopped reaching — the coverage-hole map the
  post-mortem's "walked in untouched" line only aggregates. Genuinely different from lane
  pressure: pressure says where they got to; this says where nothing could touch them.

- [ ] **Add cool new features or concrete improvements** (UX, game juice, animations,
  enhancements, or full features) to `kanban.md`.
