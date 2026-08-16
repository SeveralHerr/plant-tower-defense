# todo

**Cycle 18 of 30.** Bump this each time you refill the Items list. See the Workflow
block in `CLAUDE.md` — this list is refilled, never left fully ticked.

## Items

- [ ] **h8o — No gate says how much of the game the suite never touches.** `run_tests`
  prints `Suite: 7 script(s)` and `Assertions: N`; the checkers print `N of M`; lint
  prints `Shaders: N of M`. Nothing prints which `.gd` files are never loaded by *any*
  test. The bridge already has `scripts-seen` and nothing compares it against the file
  list. This is the one denominator the project lacks, and it is the one that says where
  the suite is blind.

- [ ] **5lv — Tell the player which red means fought and which means unreachable.**
  `coverage_frontier()` says how far the garden can reach; `LanePressureOverlay` says how
  far pests got. The prep line compares them once, to pick a sentence. The board never
  does — a player sees red tint and cannot tell "they got here and we fought" from "they
  got here and nothing could touch them", which is the whole distinction the coverage work
  just established. Note: a third red *surface* is ruled out; the hatch-versus-wash
  separation exists so the cursor can be read over the tint.

- [ ] **4no — Measure how far coverage over-promises.** The derived map is an upper
  bound: a Corn shoots only the furthest-along pest, a busy Chomp grabs nothing, a winged
  pest is unreachable by a Chomp at all. So "covered" over-promises exactly when a player
  is losing. An *observed* map was correctly rejected because `_ever_engaged` is monotone
  — but a per-cell record of "something was in range and did not fire" is **not** monotone
  and would measure the over-promise directly.

- [ ] **cjd — Let a plant declare whether it engages.** `Game.ENGAGING_PLANTS` is a
  positive list of CORN and CHOMP two files away from the plants. A fifth plant fails a
  test, which is the right failure, but it fails *after* someone has written the plant.
  Careful: `PlantCatalog.reach()` is **not** this — it returns `SAP_RADIUS` for the
  Sundew, correctly, for the dead-ground cue, and a Sundew engages nothing.

- [ ] **Add cool new features or concrete improvements** (UX, game juice, animations,
  enhancements, or full features) to `kanban.md`.
