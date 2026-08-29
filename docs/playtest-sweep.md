# The playtest sweep: run this after any balance edit

`plant-tower-defense-s1o8.5`. `test/unit/test_playtest_sweep.gd` is a standing headless
gate that plays every corpus road (`test_board.gd`'s `_road_corpus()`,
plant-tower-defense-s1o8.2) against every difficulty profile (`Game.DIFFICULTY_ORDER`,
plant-tower-defense-s1o8.3) through `RunSim`, the whole-campaign driver
(plant-tower-defense-t5yy.1). **This is the check to run after touching `WaveDirector`'s
tables, `Game.DIFFICULTIES`, `PlantCatalog` prices/reach, or anything else that shifts the
game's balance** — a change that makes a board unwinnable, trivially winnable, or
unlosable is exactly what it looks for.

## What it checks, per corpus board x difficulty

- **Losable** — a garden that plants nothing runs out of lives. A board that survives an
  empty garden is not a level.
- **Not trivial** — the honest, unmodified per-wave greedy cover (`RunSim.POLICY_GREEDY`)
  does not also clear the campaign, and a harder difficulty never survives more waves than
  an easier one for that same garden. Winning has to take more than the floor strategy.
- **Economy closes** — the minimum Corn-Cobbler garden a road's coverage needs
  (`test_board.gd`'s own greedy-set-cover, `_greedy_garden_size`) costs less than a
  conservative estimate of what the run can earn.
- **Deterministic** — the same seed on the same board and difficulty produces the
  identical wave-by-wave record set twice.
- **Winnable** — the strongest built-in garden (`RunSim.POLICY_THICKEN`) actually clears
  the campaign. Checked for one sample board on every suite run; the complete matrix is
  gated (see below) because it is expensive.

## Fast vs full

The `test_fast_*` methods run on every suite run (`python tools/run_tests.py`, no
selector) — every corpus board x every difficulty, all cheap policies, plus one sample
board played to a real win. Measured on this machine: roughly 2.5 minutes added to the
suite.

The full WINNABLE matrix — every board x every difficulty played to a complete win with
the thickened garden — is the slow part (one such campaign alone measured 20-60+ seconds,
and there are as many as there are corpus boards x difficulties). It is gated behind an
environment variable and skipped by default, printing what it skipped rather than
silently doing nothing:

```bash
# bash
PTD_PLAYTEST_FULL_SWEEP=1 python tools/run_tests.py -- --file test_playtest_sweep --filter test_full
```

```powershell
# PowerShell
$env:PTD_PLAYTEST_FULL_SWEEP=1; python tools/run_tests.py -- --file test_playtest_sweep --filter test_full
```

(`--filter` matches against the method name or the script filename — `playtest_sweep_full`
matches neither and selects nothing at all, exit 2 "SELECTED NOTHING"; `test_full` is the
prefix the one full-sweep method, `test_full_every_board_x_difficulty_clears_with_a_thickened_garden`,
actually starts with. Found and fixed while confirming plant-tower-defense-fmzu's premise —
this file and `test_playtest_sweep.gd`'s own header previously both recommended the command
that fails.)

Run the full sweep whenever a balance edit specifically touches wave pacing, difficulty
profiles, or plant pricing/reach — the fast tier's single sample board cannot catch a
regression on a road it never plays.

## A genuine finding from building this gate — RESOLVED as an accepted decision (plant-tower-defense-fmzu)

Surveyed across the whole corpus x difficulty matrix on one seed: the thickened garden
(`RunSim.POLICY_THICKEN`) clears every single board on every difficulty with full lives
remaining and hundreds to thousands of seeds still unspent. Harsh is no harder than
gentle for it. That is a real balance signal — the difficulty label currently changes
nothing for the strongest tested defense — and it is why this gate checks NOT-TRIVIAL
against the floor garden (greedy) rather than against the winning one: a standing gate
that is permanently red proves nothing about the next regression.

**plant-tower-defense-fmzu investigated whether to re-tune `Game.DIFFICULTIES` so THICKEN
would feel the difference, and decided the gap is acceptable as designed, for reasons the
repo's own history already lays out:**

- **`seed_yield` already separates the ROOM from the ECONOMY, and the economy already
  binds for the garden that spends everything it has.** Before `seed_yield` existed
  (plant-tower-defense-i8oh), all three difficulties were IDENTICAL under THICKEN down to
  the digit — 5735 seeds earned each, zero lives lost, on the shared ceiling. `seed_yield`
  fixed that: under THICKEN today the three difficulties earn and build genuinely
  different amounts (125, 116 and 79 plants over the same 22 waves —
  `test_the_three_profiles_end_a_run_differently_and_not_only_start_it_differently` in
  `test/unit/test_playtest.gd` pins this every suite run). The selector is not decoration;
  it measurably changes how much garden a THICKEN policy can afford to build.
- **What it does not change is whether that garden is *enough*, because THICKEN's own
  stopping rule is board coverage, not the wallet.** `RunSim.thicken_cover` (`tools/run_sim.gd`)
  keeps buying the single best per-seed placement every round until no open cell offers
  positive coverage gain, then falls through to packets and upgrades — it only ever stops
  because the *board* ran out of useful places to spend, never because harsh's smaller
  purse ran out first. Every corpus road's minimum defensible garden (`_min_garden_size`
  in `test/unit/test_board.gd`) is small enough that even harsh's constrained economy
  clears it early and then has surplus seeds with nothing better to do — which is exactly
  the "hundreds to thousands unspent" reported above. Making a strategy like that feel the
  economy would require either a much larger minimum garden (a road/reach change, out of
  this bead's scope) or a harder wave curve (see below) — not a further squeeze on
  `seed_yield`, `lives`, `prep_seconds` or `starting_seeds` alone.
- **The lever that WOULD bind for the ceiling garden — the wave curve itself — is
  deliberately out of `DIFFICULTIES`' scope, and already has its own open, unclaimed bead:
  plant-tower-defense-jyaq, "A wave-strength multiplier, re-verified against the
  strictly-rising curve".** It was cut from `DIFFICULTIES`' own scope
  (plant-tower-defense-s1o8.3) for a specific, documented reason:
  `WaveDirector._raw_threat` prices the whole 26-wave campaign plus the endless tail, and
  `threat_for()` is asserted to rise strictly wave over wave out to wave 300
  (`test_the_second_act_never_lets_the_threat_curve_fall`). A per-difficulty strength
  scale on `health_scale_for`/`speed_scale_for`/`current_wave_pest_count` has to be
  re-verified against that property across the whole table rather than layered in beside
  it — real, separate balance work with its own ripple, not a same-session fix to a
  four-key `Dictionary` literal.
- **This gate is scoped correctly as-is.** NOT-TRIVIAL is checked against the FLOOR
  (greedy) garden, which harsh already never survives more waves on than gentle does
  (`test_fast_every_board_x_difficulty_is_losable_not_trivial_and_the_economy_affords_its_minimum_garden`).
  WINNABLE is checked against the CEILING (thicken) garden, which is an upper bound
  proving the campaign is beatable at all, not a design target for "difficulty should
  matter here too" — that target is the floor/average garden, exactly where NOT-TRIVIAL
  already gates it.

No code changed for this bead. If plant-tower-defense-jyaq ever lands a per-difficulty
wave-curve scale, re-run the full sweep
(`PTD_PLAYTEST_FULL_SWEEP=1 python tools/run_tests.py -- --file test_playtest_sweep --filter test_full`)
and check whether harsh now costs the thickened garden something gentle does not — lives
lost, waves survived short of the ceiling, or seeds left unspent are the three numbers
this file already has plumbing to compare.
