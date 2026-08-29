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
  the campaign. Checked for one sample board on every `/verify`; the complete matrix is
  gated (see below) because it is expensive.

## Fast vs full

The `test_fast_*` methods run on every `/verify` (`python tools/run_tests.py`, no
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
PTD_PLAYTEST_FULL_SWEEP=1 python tools/run_tests.py -- --file test_playtest_sweep --filter playtest_sweep_full
```

```powershell
# PowerShell
$env:PTD_PLAYTEST_FULL_SWEEP=1; python tools/run_tests.py -- --file test_playtest_sweep --filter playtest_sweep_full
```

Run the full sweep whenever a balance edit specifically touches wave pacing, difficulty
profiles, or plant pricing/reach — the fast tier's single sample board cannot catch a
regression on a road it never plays.

## A genuine finding from building this gate

Surveyed across the whole corpus x difficulty matrix on one seed: the thickened garden
(`RunSim.POLICY_THICKEN`) clears every single board on every difficulty with full lives
remaining and hundreds to thousands of seeds still unspent. Harsh is no harder than
gentle for it. That is a real balance signal — the difficulty label currently changes
nothing for the strongest tested defense — and it is why this gate checks NOT-TRIVIAL
against the floor garden (greedy) rather than against the winning one: a standing gate
that is permanently red proves nothing about the next regression. Worth its own
follow-up bead if the gap between "a floor garden loses" and "a strong garden wins
trivially, at every difficulty" should be narrowed.
