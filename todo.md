# todo

**Cycle 30 of 30.** Bump this each time you refill the Items list. See the Workflow
block in `CLAUDE.md` — this list is refilled, never left fully ticked.

> **Paused here at the user's request, at the end of cycle 29.** Nothing below is
> started. The recurring `/loop` job was cancelled deliberately, not lost.

## Where cycle 29 got to

**All four of the owner's direct asks are shipped.** They had sat in `kanban.md` under
"Requested directly by James — not grown, asked for" while twenty-odd cycles of derived
polish went past them; that was the wrong priority order and cycle 29 was spent
correcting it.

- `129` — pests face the direction they walk (cardinal snap, one term).
- `iue` — pests have a gait: a yaw waggle plus a body-axis squash off one accumulated
  clock, per-pest phase, with per-mutation tells (winged flutters, armoured plods,
  hungry lunges). Two `sin()` per pest per frame; measured 125 FPS with nine on the road.
- `74a` — sixteen campaign waves and the **Aphid Queen**, whose mechanic is that she
  bursts into three aphids *at the spot she falls*, so where a kill lands starts
  mattering. An escaped queen deliberately leaves nothing.
- `2gd` — the **Bomb Dandelion** in a new **epic** packet tier: a magazine rather than a
  fire rate, aims at the biggest cluster rather than the leader, throws an arcing bomb
  that detonates in a 46px blast, and visibly loses fluff as it empties.

Also this cycle: `fvv` (the overlay/title builder surface got real tests — 8 reach
findings closed by testing, not by `--baseline-write`), `uay` (the group-first-match
read), and the harness moved 0.25.0 → 0.38.0 across five bumps.

## Two things worth reading before resuming

**The runner changed under us.** `CLAUDE.md` now says to run `python tools/run_tests.py`,
**not** the bare `run_tests.gd` — a test that aborts mid-method after one real assertion
is reported `[PASS]` by the `.gd` runner (harness gh#27). Most of cycle 29's merge
verification used the bare runner; the final pass re-ran everything through the wrapper
and the numbers held, but the wrapper is the gate now.

**A merge in this repo is not a union.** Twice this cycle a mechanical union of two
conflicted sides spliced an incoming block into the *middle* of an existing function.
GDScript said "Not all code paths return a value", the suite fell from 519 to 251, and it
still printed `ALL PASSED`. The reliable shape when `test_selftest.gd` conflicts: confirm
the incoming side is a pure tail append against the merge base, then splice that exact
block onto ours — and check every test function still has a `return` before believing the
runner.

## Items

- [ ] **lqk — The suite still rewrites the real `highscore.save`, byte-identically.**
  Content is provably safe (same size, same md5; only mtime moves), so this is not the
  data-loss class `csl` fixed — but something still writes the developer's save during a
  headless run. `test_no_test_persists_through_the_players_own_save` cannot see it,
  because it only checks that a test which *calls* a mutator also assigns `save_path`.

- [ ] **Pick 3–5 more out of `kanban.md`'s backlog and file them.** The idea backlog is
  long and current; cycles 20–28's blocks are all still unstarted apart from what was
  pulled forward.

- [ ] **Add cool new features or concrete improvements** (UX, game juice, animations,
  enhancements, or full features) to `kanban.md`.
