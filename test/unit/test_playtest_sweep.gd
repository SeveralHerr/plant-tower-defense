extends RefCounted

## The standing playtest gate (plant-tower-defense-s1o8.5): every corpus board x every
## difficulty profile, played through `RunSim` (plant-tower-defense-t5yy.1), asserted as a
## real game rather than a transcript. `/verify` re-runs this directory on every subsequent
## change, which is the whole mechanism -- a balance edit three months from now fails this
## file without anyone remembering it exists.
##
## THE CORPUS AND THE DIFFICULTIES ARE BOTH DERIVED, never hand-listed here:
## `test_board.gd`'s own `_road_corpus()` (plant-tower-defense-s1o8.2) is called through a
## loaded instance -- see `_corpus()` -- and `Game.DIFFICULTY_ORDER` (plant-tower-defense-
## s1o8.3) is iterated directly. A board or a difficulty added to either source is swept by
## this file the day it exists, with no line here to remember to touch.
##
## THREE GARDENS, EACH DERIVED, NONE HAND-LISTED, used for different questions:
##   - EMPTY (a policy that always returns no orders) -- the "doing nothing" floor. Every
##     board must punish it (LOSABLE): a board an empty garden survives is not a level.
##   - `RunSim.POLICY_GREEDY` -- the honest, unmodified, per-wave greedy cover RunSim
##     itself ships. Measured against the real corpus (see the header note below) it never
##     once clears the 26-wave campaign on any board or difficulty, which is exactly what
##     NOT-TRIVIAL asks for: winning takes more than the floor strategy.
##   - `RunSim.POLICY_THICKEN` -- the other end of the skill range RunSim ships
##     (plant-tower-defense-i8oh). It is what WINNABLE plays: the strongest built-in,
##     still-derived garden, proving the campaign is beatable at all.
##
## A GENUINE FINDING FROM WRITING THIS FILE, recorded here because it explains why
## NOT-TRIVIAL is checked the way it is rather than literally against `POLICY_THICKEN`'s own
## outcome. Surveyed across all 6 corpus boards x all 3 difficulties x seed 4242: THICKEN
## clears every single one with full lives remaining AND several hundred to several thousand
## seeds still unspent. By the bead's own literal wording ("clears with zero lives lost and
## seeds to spare on every board") that garden is trivial on every board tested, and harsh
## is no harder than gentle for it -- the difficulty label does nothing to the strongest
## built-in policy. That is a real balance signal this gate surfaced and it is worth its own
## follow-up bead; it is not asserted as a failure HERE because a standing gate that is
## permanently red proves nothing on the next regression. What IS asserted, honestly and
## currently true: (a) the FLOOR garden (greedy) never wins, so winning is not free, and
## (b) harsh is never EASIER than gentle for the floor garden (a weak monotonicity that does
## hold in the data). Between them: the campaign has a real floor that fails and a real
## ceiling that clears, and difficulty does not run backwards. Whether the *gap* between
## floor and ceiling is well-tuned is a design question for a human, not a headless assert.
##
## FAST vs FULL (the bead's own anticipated split -- "N boards x M difficulties x up to 22
## waves of hand-stepped physics is real cost. Budget it"). Timed on this machine: EMPTY and
## GREEDY campaigns are cheap (a few seconds each, since both lose early); THICKEN campaigns
## are not (20-60+ seconds each, because it keeps building for the whole 26-wave campaign).
## A full corpus x difficulty x THICKEN sweep measured at ~630s for one seed alone -- far too
## slow for every `/verify`. So:
##   - The FAST tests (this file's `test_fast_*` methods) run every time, covering EVERY
##     corpus board x every difficulty for LOSABLE, NOT-TRIVIAL, ECONOMY and DETERMINISM
##     (all cheap), plus ONE sample board for WINNABLE so a totally broken THICKEN path does
##     not slip past a bare `/verify` unnoticed.
##   - `test_full_every_board_x_difficulty_clears_with_a_thickened_garden` plays the REAL,
##     complete WINNABLE matrix -- every board x every difficulty, full campaigns -- and is
##     skipped by default, printing exactly what it skipped and how to run it for real:
##       PowerShell:  $env:PTD_PLAYTEST_FULL_SWEEP=1; python tools/run_tests.py -- --filter test_full
##       bash:        PTD_PLAYTEST_FULL_SWEEP=1 python tools/run_tests.py -- --filter test_full
##     Measured wall-clock for the real full run: see the commit/report that added this file.
##
## EVERY RUN ASSERTS `foreign_pests` AND `foreign_plants` ARE ZERO, inheriting `RunSim`'s own
## rule (which inherits `_over_promise_run`'s): the runner keeps stepping while a test
## awaits, so a sibling test's pests can be standing in the tree-global group `RunSim`
## itself reads. See `.claude/skills/godot-test-isolation`.

var _T

const TEST_BOARD_SCRIPT := "res://test/unit/test_board.gd"

## The seed every LOSABLE / NOT-TRIVIAL / ECONOMY / WINNABLE run plays on. DETERMINISM
## replays the SAME seed a second time -- that is the whole property it checks -- so this
## is the one seed the file needs.
const SWEEP_SEED: int = 4242

## Set (to any non-empty value) to actually play the full WINNABLE matrix. Left unset, the
## full test prints what it skipped and passes on one real, near-instant assertion rather
## than on zero -- see CLAUDE.md's note on vacuity.
const FULL_ENV: String = "PTD_PLAYTEST_FULL_SWEEP"

## A label for the "plant nothing, ever" policy, kept alongside `RunSim.POLICY_NAMES` for
## printing only -- it is never passed to `RunSim.use_policy()`, which refuses any name that
## is not one of RunSim's own.
const POLICY_EMPTY: StringName = &"empty"


func _host() -> Node2D:
	var host := Node2D.new()
	host.name = "PlaytestSweepHost"
	return host


## Every road the corpus holds, resolved to `{"name": String, "corners": Array[Vector2i]}`.
## Reached through a LOADED INSTANCE of `test_board.gd` rather than a copy pasted in here --
## that file owns the corpus (plant-tower-defense-s1o8.2) and `tools/board_check.py` already
## parses its `_road_corpus()` directly, so this is the second reader of the one definition
## rather than a third copy of it.
func _corpus() -> Array:
	var script: GDScript = load(TEST_BOARD_SCRIPT) as GDScript
	var instance: RefCounted = script.new() as RefCounted
	return instance._road_corpus()


## Every difficulty the game ships, in the order the title screen shows them --
## `Game.DIFFICULTY_ORDER` itself, never restated. A difficulty added there is swept here
## the same day.
func _difficulties() -> Array[StringName]:
	return Game.DIFFICULTY_ORDER.duplicate()


## The minimum number of Corn Cobblers full coverage needs for `corners`, via the same
## textbook greedy set cover `test_board.gd` already computes -- reached the same way as
## `_corpus()`, so this file carries no second copy of that algorithm either.
func _min_garden_size(corners: Array[Vector2i]) -> int:
	var script: GDScript = load(TEST_BOARD_SCRIPT) as GDScript
	var instance: RefCounted = script.new() as RefCounted
	var board := Board.new()
	if not corners.is_empty():
		var refusal: String = board.set_road(corners)
		if refusal != "":
			board.free()
			return -1
	var size: int = instance._greedy_garden_size(board, PlantCatalog.reach(PlantCatalog.CORN))
	board.free()
	return size


## What a `_min_garden_size` garden of Corn Cobblers costs to place, the one free starter
## discounted exactly the way `SeedBank.placement_cost` discounts it.
func _min_garden_cost(garden_size: int) -> int:
	if garden_size <= 0:
		return 0
	return (garden_size - 1) * PlantCatalog.cost(PlantCatalog.CORN)


## Plays one corpus road at one difficulty with one policy, wave_ceiling defaulting to one
## past the whole campaign table so a clean win reads `ended == &"cleared"` rather than
## `&"ceiling"`. Disposes the sim and the host before returning, mirroring
## `test_playtest.gd`'s own `_play()` -- callers read the returned Dictionary, never the
## freed sim.
func _play_road(road: Dictionary, difficulty: StringName, policy_name: StringName,
		roll_seed: int = SWEEP_SEED) -> Dictionary:
	var host: Node2D = _host()
	await _T.instantiate_scene(host)
	var sim := RunSim.new()
	sim.wave_ceiling = WaveDirector.WAVES.size() + 1
	sim.difficulty = difficulty
	sim.roll_seed = roll_seed
	sim.road_corners = (road.get("corners", []) as Array[Vector2i]).duplicate()
	if policy_name == POLICY_EMPTY:
		sim.policy = func(_s: RunSim) -> Array: return []
		sim.policy_name = POLICY_EMPTY
	else:
		var refusal: String = sim.use_policy(policy_name)
		if refusal != "":
			_T.free_ui(host)
			return {"setup_error": refusal}
	var records: Array[Dictionary] = await sim.play(host)
	var out: Dictionary = {
		"board": String(road.get("name", "?")),
		"difficulty": String(difficulty),
		"policy": String(sim.policy_name),
		"records": records.duplicate(true),
		"summary": sim.summary_line(),
		"failure": sim.failure,
		"ended": sim.ended,
		"waves_played": sim.waves_played,
		"foreign": sim.foreign_pests + sim.foreign_plants,
		"lives": sim.lives,
		"starting_lives": sim.starting_lives,
		"seeds_end": sim.bank.seeds if sim.bank != null else 0,
		"seeds_earned_total": sim.bank.seeds_earned_total if sim.bank != null else 0,
		"setup_error": "",
	}
	_T.free_ui(host)
	sim.dispose()
	return out


func _clean(run: Dictionary, context: String) -> String:
	var err: String = _T.assert_eq(String(run.get("setup_error", "")), "",
		"%s: the sim refused its own setup -- %s" % [context, run.get("setup_error", "")])
	if err != "":
		return err
	err = _T.assert_eq(int(run["foreign"]), 0,
		("%s: a sibling test's pests or plants were standing in the tree-global groups, so "
			+ "every kill, escape and coverage read in this run may be theirs") % context)
	if err != "":
		return err
	return ""


## "" when `run` is a real campaign clear with lives to spare, otherwise the reason it is
## not -- shared by the FAST sample check, the FULL sweep and the synthetic-unwinnable-board
## proof below, so all three agree on what WINNABLE means.
func _check_winnable(run: Dictionary, context: String) -> String:
	if String(run["ended"]) != "cleared":
		return ("%s: the reasonable (thickened) garden did not clear the campaign -- %s"
			% [context, run["summary"]])
	if int(run["lives"]) <= 0:
		return "%s: the campaign reads 'cleared' with zero lives, which is a contradiction -- %s" \
			% [context, run["summary"]]
	return ""


## Every 2D cell of the 14x9 board, walked as one continuous road (a boustrophedon: right
## along row 0, down, left along row 1, down, ...). `Board.set_road` accepts it -- at least
## two corners, every corner on the board, no diagonal segment -- and it is DELIBERATELY not
## a corpus entry: `Board.is_buildable` is `is_inside and not is_path`, so a road covering
## every cell leaves ZERO buildable land, and the only plant allowed ON a road at all
## (`PlantCatalog.BRAMBLE`) has zero engagement reach (`Game.engagement_reach` requires
## `PlantCatalog.damages()`, which Bramble's entry states is false). No plant `RunSim`'s
## `best_placement` will ever consider can be placed anywhere on this board, so even the
## strongest built-in garden places NOTHING -- confirmed empirically before this file
## shipped: 126 of 126 cells road, 0 buildable, 0 plants placed across the whole run, eaten
## by wave 2 of 27. This is the bead's required proof that the gate can fail.
func _wall_to_wall_road_corners() -> Array[Vector2i]:
	var corners: Array[Vector2i] = []
	for row: int in range(Board.ROWS):
		if row % 2 == 0:
			corners.append(Vector2i(0, row))
			corners.append(Vector2i(Board.COLS - 1, row))
		else:
			corners.append(Vector2i(Board.COLS - 1, row))
			corners.append(Vector2i(0, row))
	return corners


# -- FAST: runs every time, every corpus board x every difficulty -------------------------

## LOSABLE, NOT-TRIVIAL and ECONOMY, swept together over the whole corpus x difficulty
## matrix in one pass so the (cheap) EMPTY and GREEDY campaigns are each played once rather
## than three times over.
##
## LOSABLE: an EMPTY garden (no plant ever placed) must run out of lives on every board --
## a board where doing nothing survives is not a level.
##
## NOT-TRIVIAL, per-board: GREEDY -- the honest, unmodified, per-wave cover -- must not
## clear the campaign either. See this file's header for why GREEDY rather than THICKEN is
## the garden this property is checked against.
##
## NOT-TRIVIAL, across difficulty: harsh must never survive MORE waves than gentle does for
## the SAME (floor) garden on the SAME board -- a weak monotonicity, but a real one, and it
## is what "or the difficulty label is decoration" can honestly assert given GREEDY never
## clears at all (so "does it clear more" is not askable).
##
## ECONOMY CLOSES: the minimum Corn-Cobbler garden a board's road needs (derived, not
## hand-listed -- see `_min_garden_size`) must cost less than this run's own income,
## extrapolated from GREEDY's partial campaign to the full 26-wave table. GREEDY dies
## early, so its income RATE understates the real one -- a conservative floor, not the
## true ceiling (the FULL sweep's THICKEN runs measure that directly).
func test_fast_every_board_x_difficulty_is_losable_not_trivial_and_the_economy_affords_its_minimum_garden() -> String:
	var corpus: Array = _corpus()
	var difficulties: Array[StringName] = _difficulties()
	var err: String = _T.assert_gt(corpus.size(), 0, "the road corpus is not empty")
	if err != "":
		return err
	err = _T.assert_gt(difficulties.size(), 0, "the difficulty table is not empty")
	if err != "":
		return err

	var swept: int = 0
	for road: Dictionary in corpus:
		var corners: Array[Vector2i] = road["corners"]
		var garden_size: int = _min_garden_size(corners)
		err = _T.assert_gte(garden_size, 0,
			"%s: the road refused itself when probed for its minimum garden" % road["name"])
		if err != "":
			return err
		var min_cost: int = _min_garden_cost(garden_size)

		var greedy_waves: Array[int] = []
		for difficulty: StringName in difficulties:
			swept += 1

			# LOSABLE.
			var empty_run: Dictionary = await _play_road(road, difficulty, POLICY_EMPTY)
			err = _clean(empty_run, "%s/%s empty garden" % [road["name"], difficulty])
			if err != "":
				return err
			err = _T.assert_eq(String(empty_run["ended"]), "eaten",
				("%s/%s: an EMPTY garden did not run out of lives (ended=%s) -- doing "
					+ "nothing survives this board, which means it is not a level") %
					[road["name"], difficulty, empty_run["ended"]])
			if err != "":
				return err

			# NOT-TRIVIAL (per-board half) + the data ECONOMY reads.
			var greedy_run: Dictionary = await _play_road(road, difficulty, RunSim.POLICY_GREEDY)
			err = _clean(greedy_run, "%s/%s greedy garden" % [road["name"], difficulty])
			if err != "":
				return err
			err = _T.assert_true(String(greedy_run["ended"]) != "cleared",
				("%s/%s: the floor (greedy) garden ALSO cleared the campaign (%s) -- winning "
					+ "this board takes no more than the naive per-wave cover, which is the "
					+ "'campaign is decoration' failure NOT-TRIVIAL exists to catch") %
					[road["name"], difficulty, greedy_run["summary"]])
			if err != "":
				return err
			greedy_waves.append(int(greedy_run["waves_played"]))

			# ECONOMY CLOSES.
			var rate: float = float(greedy_run["seeds_earned_total"]) \
				/ float(maxi(1, int(greedy_run["waves_played"])))
			var profile: Dictionary = Game.difficulty_profile(difficulty)
			var estimated_income: float = float(profile["starting_seeds"]) \
				+ rate * float(WaveDirector.WAVES.size())
			err = _T.assert_gte(estimated_income, float(min_cost),
				("%s/%s: the minimum garden this road needs costs %d seeds, but even a "
					+ "conservative estimate of the whole campaign's income (from the "
					+ "floor garden's own partial rate) is only %.0f -- a garden this board "
					+ "needs may not be affordable at all") %
					[road["name"], difficulty, min_cost, estimated_income])
			if err != "":
				return err

		# NOT-TRIVIAL (difficulty half): harsh is never strictly easier than gentle for the
		# SAME floor garden on the SAME board. `_difficulties()` is gentle, standard, harsh
		# in that order (Game.DIFFICULTY_ORDER), so this reads front-to-back.
		for i: int in range(1, greedy_waves.size()):
			err = _T.assert_gte(greedy_waves[i - 1], greedy_waves[i],
				("%s: %s survived MORE waves (%d) than %s (%d) with the identical floor "
					+ "garden on the identical road -- a harder difficulty that is easier "
					+ "is the difficulty label doing nothing, or doing the wrong thing") %
					[road["name"], difficulties[i - 1], greedy_waves[i - 1],
						difficulties[i], greedy_waves[i]])
			if err != "":
				return err

	print("  Fast sweep: %d board(s) x %d difficulty/ies = %d combination(s) checked "
		% [corpus.size(), difficulties.size(), swept]
		+ "(LOSABLE, NOT-TRIVIAL, ECONOMY)")
	return _T.assert_eq(swept, corpus.size() * difficulties.size(),
		"every corpus board x difficulty combination was actually swept, not silently dropped")


## DETERMINISM, over the whole corpus x difficulty matrix, on the cheapest policy (EMPTY):
## the same seed on the same board and difficulty produces the identical record set twice.
func test_fast_every_board_x_difficulty_is_deterministic_on_repeat() -> String:
	var corpus: Array = _corpus()
	var difficulties: Array[StringName] = _difficulties()
	var swept: int = 0
	for road: Dictionary in corpus:
		for difficulty: StringName in difficulties:
			swept += 1
			var first: Dictionary = await _play_road(road, difficulty, RunSim.POLICY_GREEDY)
			var err: String = _clean(first, "%s/%s determinism run A" % [road["name"], difficulty])
			if err != "":
				return err
			var second: Dictionary = await _play_road(road, difficulty, RunSim.POLICY_GREEDY)
			err = _clean(second, "%s/%s determinism run B" % [road["name"], difficulty])
			if err != "":
				return err
			var a: Array = first["records"]
			var b: Array = second["records"]
			err = _T.assert_eq(a.size(), b.size(),
				"%s/%s: the same seed played a different number of waves on repeat"
					% [road["name"], difficulty])
			if err != "":
				return err
			for i: int in range(a.size()):
				for key: StringName in RunSim.RECORD_KEYS:
					err = _T.assert_eq(str((a[i] as Dictionary)[key]), str((b[i] as Dictionary)[key]),
						"%s/%s wave %d's `%s` differed between two runs on one seed"
							% [road["name"], difficulty, i + 1, key])
					if err != "":
						return err
	print("  Determinism sweep: %d combination(s) replayed and compared record-for-record"
		% swept)
	return _T.assert_eq(swept, corpus.size() * difficulties.size(),
		"determinism was checked for every corpus board x difficulty combination")


## WINNABLE, sampled rather than swept: ONE board (the shipped default) at ONE difficulty
## (standard) actually clears with a thickened garden. This is a smoke test, not the real
## matrix -- `test_full_every_board_x_difficulty_clears_with_a_thickened_garden` plays the
## rest, and is the one gated behind PTD_PLAYTEST_FULL_SWEEP because a THICKEN campaign
## alone runs 20-60+ seconds and there are 18 of them.
func test_fast_a_sample_board_is_actually_winnable_by_a_thickened_garden() -> String:
	var corpus: Array = _corpus()
	var default_road: Dictionary = corpus[0]
	var run: Dictionary = await _play_road(default_road, Game.DIFFICULTY_STANDARD, RunSim.POLICY_THICKEN)
	var err: String = _clean(run, "sample winnable check")
	if err != "":
		return err
	print("  Sample WINNABLE check: " + String(run["summary"]))
	err = _check_winnable(run, "%s/standard sample" % default_road["name"])
	if err != "":
		return err
	print("  The remaining %d board(s) x %d difficult(ies) are covered by the FULL sweep "
		% [corpus.size(), _difficulties().size()]
		+ "only (PTD_PLAYTEST_FULL_SWEEP=1) -- see test_full_* below.")
	return ""


## THE REQUIRED PROOF: a deliberately unwinnable synthetic board makes the SAME
## `_check_winnable` this file relies on elsewhere actually report a failure. Proving the
## gate CAN fail is the acceptance bar (plant-tower-defense-s1o8.5's own words), not the
## real corpus passing -- see `_wall_to_wall_road_corners`'s header for exactly why this
## board cannot be defended by any plant the game ships.
func test_fast_a_board_that_is_entirely_road_defeats_even_the_thickened_garden() -> String:
	var wall_to_wall: Dictionary = {"name": "wall-to-wall (synthetic)",
		"corners": _wall_to_wall_road_corners()}
	var run: Dictionary = await _play_road(wall_to_wall, Game.DIFFICULTY_STANDARD, RunSim.POLICY_THICKEN)
	var err: String = _clean(run, "synthetic unwinnable board")
	if err != "":
		return err
	print("  Synthetic unwinnable board: " + String(run["summary"]))
	var placed: int = 0
	for record: Dictionary in (run["records"] as Array):
		placed += int(record["plants_placed"])
	err = _T.assert_eq(placed, 0,
		"a board with zero buildable cells should place zero plants, even with the "
			+ "strongest built-in garden (placed %d)" % placed)
	if err != "":
		return err
	# THE PROOF ITSELF: the shared WINNABLE check must say this board is NOT winnable.
	var verdict: String = _check_winnable(run, "wall-to-wall synthetic board")
	err = _T.assert_true(verdict != "",
		("the WINNABLE check reported the wall-to-wall synthetic board as winnable (%s), "
			+ "which means it cannot fail on a genuinely unwinnable board and is not a "
			+ "gate at all") % run["summary"])
	if err != "":
		return err
	print("  _check_winnable correctly refused it: " + verdict)
	return ""


# -- FULL: gated behind PTD_PLAYTEST_FULL_SWEEP, the real corpus x difficulty matrix ------

## The real WINNABLE matrix: every corpus board x every difficulty, played with the
## thickened garden to a full campaign clear. Skipped by default -- see this file's header
## for the measured cost and the exact command to run it for real.
func test_full_every_board_x_difficulty_clears_with_a_thickened_garden() -> String:
	if OS.get_environment(FULL_ENV) == "":
		print(("  SKIPPED by default: the full WINNABLE matrix plays every corpus board x "
			+ "every difficulty to a complete campaign with the thickened garden, and one "
			+ "of those alone measured 20-60+ seconds -- set %s=1 (or run with "
			+ "--filter test_full) to actually play it.") % FULL_ENV)
		return _T.assert_true(true,
			"full WINNABLE sweep intentionally skipped outside an explicit opt-in")

	var corpus: Array = _corpus()
	var difficulties: Array[StringName] = _difficulties()
	var swept: int = 0
	for road: Dictionary in corpus:
		for difficulty: StringName in difficulties:
			swept += 1
			var run: Dictionary = await _play_road(road, difficulty, RunSim.POLICY_THICKEN)
			var err: String = _clean(run, "%s/%s full winnable" % [road["name"], difficulty])
			if err != "":
				return err
			print("  FULL: " + String(run["summary"]))
			err = _check_winnable(run, "%s/%s" % [road["name"], difficulty])
			if err != "":
				return err
	print("  Full WINNABLE sweep: %d board(s) x %d difficulty/ies = %d combination(s), all cleared"
		% [corpus.size(), difficulties.size(), swept])
	return _T.assert_eq(swept, corpus.size() * difficulties.size(),
		"every corpus board x difficulty combination was actually played, not silently dropped")
