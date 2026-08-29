extends RefCounted

## THE GATE THAT FAILS WHEN `tools/run_sim.gd` AND `game/game.gd` STOP AGREEING.
##
## `run_sim.gd` says in its own header that "the economy below is a re-derivation of
## `Game`'s, not a call into it", and every branch that moves seeds cites the `game.gd`
## function it mirrors by name (grep `^## Mirrors` -- ten comments naming eleven Game
## methods today). Until this file existed, nothing checked a single one of those
## citations. That is worse than having no check, because `docs/playtest-runs.jsonl` is
## committed, diffed and read by a tuning pass as though it described the game.
##
## WHAT THIS DOES. It plays ONE wave twice -- once through `RunSim`, once through a
## hosted `res://game/game.tscn` hand-stepped at the SAME fixed dt, on the same seed,
## with the same garden -- and asserts the pair agree on the eight numbers the mirror is
## responsible for (`AXES` below). A single wave is enough: every mirrored function fires
## inside one.
##
## WHY THE GAME SIDE IS HAND-STEPPED RATHER THAN LEFT TO RUN. `RunSim`'s header argues
## that awaiting real frames makes a run "reproducible only up to how busy the machine
## was". That is true of both sides, so both sides get the same treatment: the hosted
## Game's `process_mode` is set to DISABLED the moment it is up, and this file then calls
## the very same methods `RunSim._step_frame` calls, in the very same order, at the same
## `RunSim.DT`. Nothing in the tree runs a frame this file did not drive. Three facts a
## hand-stepped Game needs, all measured rather than assumed (bead xca3 records them):
##
##   * `queue_free()` NEVER LANDS, because the tree runs no frame between two steps. So
##     this frees the dead itself, at the end of the frame that produced them, exactly as
##     `RunSim._collect_garbage` does.
##   * A TWEEN IS STEPPED BY THE SceneTree, not by any node, and `Pest._play_death` frees
##     its corpse through one on BOTH sides of the `GardenTheme.animations_enabled()`
##     gate. A driver that waited for that callback would watch wave 1 never end. The
##     point above is what makes waiting unnecessary.
##   * `Game._process` STARTS THE NEXT WAVE ITSELF at prep zero (`game.gd:519-521`). This
##     file never calls `Game._process` at all -- see the next paragraph -- so it asks for
##     the wave itself, once, and there is no double-start to guard against.
##
## WHY NOT `Game._process(dt)`. Because `RunSim` has no counterpart to three of the five
## things in it: `_apply_aloe_healing`, `_tick_uproot_confirm` and the prep countdown.
## Calling it would make this a comparison of two DRIVERS, and the first Aloe anybody
## plants would fail a gate that is supposed to be about the mirrored economy. So the
## Game side calls the same pieces `RunSim._step_frame` calls -- the plants, the kernels,
## the pests, the compost, the sweep, `_tick_cross_breeding` -- and nothing else.
##
## WHAT IS DELIBERATELY *NOT* CLAIMED HERE, since a check that reports clean must say what
## it would have missed (`.claude/skills/scope-vs-claim`):
##
##   * `frames` is not compared. The two loops break on the same CONDITION but a
##     one-frame difference in when a corpse leaves the group is not a defect in the
##     mirror, and asserting it would make this gate fail for driver reasons.
##   * The sweep itself is not the mirror. `RunSim._sweep` carries no `## Mirrors`
##     comment -- it is perfect play, on purpose -- so both sides sweep the same way here
##     (`collect_at` then `add_seeds`, which is `game.gd:3178-3180` with the click
##     geometry taken off). What `seeds_from_husks` gates is the HUSK VALUE, which is
##     dropped by the mirrored `_on_pest_died` on both sides.
##   * `_click_at` is not used for the sweep, and that is not laziness: its own guard
##     rejects `local.y < 0` and `local.x > board_size().x`, and `Board._build_route`
##     brackets the road with an off-board entry and exit whose husks `collect_at` sweeps
##     happily. Routing through the click would compare two drivers' screen arithmetic.
##
## EVERY AXIS IS EXERCISED BY AT LEAST ONE SCENARIO, and the scenarios exist for that
## reason rather than for variety -- eight axes that all read 0 == 0 is the vacuous pass
## this harness warns about loudest. `defended` reaches the kills, the husks and a
## Sunflower's growth; `walled` reaches the escapes, the beds and a plant lost, by putting
## a Barrier Bramble on the road with nothing at all defending it.
##
## THE GARDENS ARE DERIVED, not typed (`.claude/skills/derive-the-list`): every cell comes
## out of `Board.is_buildable_for` and `PlacementPreview.covered_road_cell_list` against a
## real `Board`, so a board reshaped tomorrow is played on its new shape rather than
## refused at a cell that used to be grass. Both sides are handed the SAME derived cells,
## and both sides assert every placement was accepted -- a refusal is a failure here, not
## a garden quietly one plant smaller on one side.

const GAME_SCENE := "res://game/game.tscn"

## The one dt both sides step at. Read off `RunSim` rather than restated, so a driver that
## changes its own step carries this gate with it.
const DT: float = RunSim.DT

## One seed for all three streams on both sides -- `Game.set_run_seed` pins them in one
## call, `RunSim` does the same by hand off `roll_seed`.
const ROLL_SEED: int = 4242

## The same ceiling `RunSim` defaults to, stated here so the Game side blows at the same
## place rather than hanging. A wave that spends it is a FAILURE that names the wave.
const WAVE_FRAME_CEILING: int = 30000

## The purse both sides open on, well past what either garden costs, so a placement can
## only ever be refused for a reason about the CELL. Overwrites the difficulty's float on
## both sides at the same point in the sequence (after the wave's `earned_start` is
## captured, and `seeds` is not `seeds_earned_total`, so no income is invented).
const PURSE: int = 400

## THE EIGHT NUMBERS THE MIRROR IS RESPONSIBLE FOR, and the only place they are listed.
##
## Both sides return a Dictionary whose key set must BE this list, asserted in both
## directions before anything is compared -- so an axis dropped from a tally is a failure
## naming the axis rather than a comparison that quietly runs seven times.
const AXES: Array[StringName] = [
	&"seeds_earned",
	&"seeds_from_kills",
	&"seeds_from_growth",
	&"seeds_from_husks",
	&"lives_lost",
	&"killed",
	&"escaped",
	&"plants_lost",
]

var _T

## Where this script's RunConfig writes go instead of the player's own save. Hosting
## `game.tscn` at all can reach `RunConfig._save()` through the game's own code, on a
## condition no reader can evaluate; `tools/save_persist_check.py` requires this of any
## test script that can. The reasoning is written out once, in `test_combat.gd`'s setup().
const SUITE_SAVE_PATH := "user://test_mirror_parity_suite.save"
var _suite_stashed_save_path: String = ""


func setup() -> void:
	_suite_stashed_save_path = RunConfig.save_path
	RunConfig.save_path = SUITE_SAVE_PATH


func teardown() -> void:
	if _suite_stashed_save_path != "":
		RunConfig.save_path = _suite_stashed_save_path
	DirAccess.remove_absolute(SUITE_SAVE_PATH)


# -- the gardens, derived from a real Board -----------------------------------


## The buildable cell a Corn Cobbler covers the most road from, ties broken by scan order.
##
## Strictly `>`, so the first cell of a tie wins and two runs on one board pick the same
## one. Read off `covered_road_cell_list` and `Game.engagement_reach` -- the same pair
## `Game.covered_road_cells` and `RunSim.covered_road_cells` both read -- rather than off
## a cell typed in here, which would be a claim about the shipped snake.
func _best_cover_cell(board: Board, id: StringName) -> Vector2i:
	var reach: float = Game.engagement_reach(id)
	var best := Vector2i(-1, -1)
	var best_cover: int = 0
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var cell := Vector2i(x, y)
			if not board.is_buildable_for(cell, id):
				continue
			var cover: int = PlacementPreview.covered_road_cell_list(board, cell, reach).size()
			if cover > best_cover:
				best_cover = cover
				best = cell
	return best


## The first cell in scan order `id` may legally stand in, skipping `taken`.
func _first_cell_for(board: Board, id: StringName, taken: Array[Vector2i]) -> Vector2i:
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var cell := Vector2i(x, y)
			if taken.has(cell):
				continue
			if board.is_buildable_for(cell, id):
				return cell
	return Vector2i(-1, -1)


## The two scenarios, or a `problem` naming the cell that could not be derived.
##
## Built against a throwaway `Board` so the cells exist before either side is started, and
## handed to both sides unchanged. A `Board` builds its path on demand and does not need a
## tree for it (`board.gd:92`), which is why this can run before anything is hosted.
func _scenarios() -> Dictionary:
	var board := Board.new()
	var corn: Vector2i = _best_cover_cell(board, PlantCatalog.CORN)
	var taken: Array[Vector2i] = [corn]
	var sun: Vector2i = _first_cell_for(board, PlantCatalog.SUNFLOWER, taken)
	taken.append(sun)
	var nothing_taken: Array[Vector2i] = []
	var wall: Vector2i = _first_cell_for(board, PlantCatalog.BRAMBLE, nothing_taken)
	board.free()

	var missing: PackedStringArray = PackedStringArray()
	if corn == Vector2i(-1, -1):
		missing.append("no buildable cell covers any road for a %s" % PlantCatalog.CORN)
	if sun == Vector2i(-1, -1):
		missing.append("no buildable cell is left for a %s" % PlantCatalog.SUNFLOWER)
	if wall == Vector2i(-1, -1):
		missing.append("no cell accepts a %s, so nothing can be put in a lane" % PlantCatalog.BRAMBLE)
	if not missing.is_empty():
		return {"problem": "; ".join(missing)}

	var defended_unlocks: Array[StringName] = PlantCatalog.starting_unlocks()
	defended_unlocks.append(PlantCatalog.SUNFLOWER)
	var walled_unlocks: Array[StringName] = PlantCatalog.starting_unlocks()
	walled_unlocks.append(PlantCatalog.BRAMBLE)

	return {"scenarios": [
		{
			"name": "defended",
			"unlocks": defended_unlocks,
			"garden": [
				{"id": PlantCatalog.CORN, "cell": corn},
				{"id": PlantCatalog.SUNFLOWER, "cell": sun},
			],
			# What this scenario is here to REACH. A zero on any of these means the wave
			# did not exercise the branch, and the pair agreeing on nothing is not a pass.
			"floors": [&"killed", &"seeds_from_kills", &"seeds_from_husks", &"seeds_from_growth"],
		},
		{
			"name": "walled",
			"unlocks": walled_unlocks,
			# A wall in the lane and NOTHING shooting: every pest stops to chew, the
			# Bramble goes (plants_lost), and then they all walk out (escaped, lives_lost).
			"garden": [
				{"id": PlantCatalog.BRAMBLE, "cell": wall},
			],
			"floors": [&"escaped", &"lives_lost", &"plants_lost"],
		},
	]}


# -- side one: the mirror ------------------------------------------------------


## One wave through `RunSim`, on the scenario's garden, disposed before it returns.
##
## The garden is installed through the POLICY seam rather than by reaching into the sim,
## because `bank` does not exist until `play()` builds it and the policy is the one hook
## that runs after that and before the prep window. It fires once and then returns
## nothing, which is how `_run_policy` knows to stop asking.
func _sim_side(scenario: Dictionary) -> Dictionary:
	var host := Node2D.new()
	host.name = "MirrorParityHost"
	await _T.instantiate_scene(host)

	var sim := RunSim.new()
	sim.wave_ceiling = 1
	sim.frame_ceiling_per_wave = WAVE_FRAME_CEILING
	sim.difficulty = Game.DIFFICULTY_STANDARD
	sim.endless = false
	sim.roll_seed = ROLL_SEED
	sim.sweep_husks = true

	var garden: Array = scenario["garden"]
	var unlocks: Array[StringName] = scenario["unlocks"]
	var once: Dictionary = {"spent": false}
	sim.policy = func(s: RunSim) -> Array:
		if bool(once["spent"]):
			return []
		once["spent"] = true
		s.bank.seeds = PURSE
		s.bank.unlocked = unlocks.duplicate()
		var orders: Array = []
		for entry: Dictionary in garden:
			orders.append({"op": RunSim.OP_PLANT, "id": entry["id"], "cell": entry["cell"]})
		return orders

	var records: Array[Dictionary] = sim.play(host)
	var out: Dictionary = {
		"axes": {},
		"foreign": sim.foreign_pests + sim.foreign_plants,
		"failure": sim.failure,
		"summary": sim.summary_line(),
		"records": records.size(),
		"spawned": -1,
		"placed": -1,
	}
	if records.size() == 1:
		var r: Dictionary = records[0]
		out["axes"] = {
			&"seeds_earned": int(r[&"seeds_earned"]),
			&"seeds_from_kills": int(r[&"seeds_from_kills"]),
			&"seeds_from_growth": int(r[&"seeds_from_growth"]),
			&"seeds_from_husks": int(r[&"seeds_from_husks"]),
			&"lives_lost": int(r[&"lives_start"]) - int(r[&"lives_end"]),
			&"killed": int(r[&"killed"]),
			&"escaped": int(r[&"escaped"]),
			&"plants_lost": int(r[&"plants_lost"]),
		}
		out["spawned"] = int(r[&"spawned"])
		out["placed"] = int(r[&"plants_placed"])
	# The host first and the sim's own four nodes second: a plant still standing holds the
	# Board this is about to free. `test_playtest._play` keeps the same order for the same
	# reason.
	_T.free_ui(host)
	sim.dispose()
	return out


# -- side two: the game itself -------------------------------------------------


## One wave through a hosted `game.tscn`, hand-stepped at `DT` on the same garden.
func _game_side(scenario: Dictionary) -> Dictionary:
	var out: Dictionary = {
		"axes": {},
		"foreign": -1,
		"failure": "",
		"summary": "",
		"records": 0,
		"spawned": -1,
		"placed": -1,
	}
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	if game == null:
		out["failure"] = "%s did not host" % GAME_SCENE
		return out

	# THE TREE STOPS STEPPING ITSELF, HERE AND FOR EVERYTHING UNDER IT. process_mode is
	# inherited, so a Pest, a Plant or a Kernel added by the game's own code minutes from
	# now arrives disabled too -- which is the whole reason this is one line instead of a
	# hunt for every node type the game can build. Calling `_physics_process` by hand is
	# unaffected: it is a method, and a disabled node still answers to one.
	game.process_mode = Node.PROCESS_MODE_DISABLED

	# `_T.instantiate_scene` ticks two settle frames before it returns, and `Game._process`
	# ran on both of them with a REAL delta. Two things it moved that this run reads are
	# put back: the cross-breeding clock (which decides when a sport lands) and the three
	# random streams. `set_run_seed` is the one call that knows how many streams a run has.
	var profile: Dictionary = Game.difficulty_profile(Game.DIFFICULTY_STANDARD)
	game.starting_lives = int(profile["lives"])
	game.lives = game.starting_lives
	game.prep_seconds = float(profile["prep_seconds"])
	game.director.endless = false
	game.set_run_seed(ROLL_SEED)
	game._cross_clock = 0.0
	game._prep_left = game.prep_seconds

	# Counted rather than assumed clean, the rule `RunSim` and `_over_promise_run` both
	# follow: the runner keeps stepping while a test awaits, so a sibling test's pests can
	# be standing in the tree-global groups that `Kernel._physics_process` and
	# `Plant._live_pests` read. Taken before this run plants anything of its own.
	# settle-read-check: ok - counted here, asserted zero by the caller.
	var tree: SceneTree = game.get_tree()
	out["foreign"] = (tree.get_nodes_in_group("pests").size()
		+ tree.get_nodes_in_group("plants").size())

	var tally: Dictionary = {
		&"seeds_earned": 0,
		&"seeds_from_kills": 0,
		&"seeds_from_growth": 0,
		&"seeds_from_husks": 0,
		&"lives_lost": 0,
		&"killed": 0,
		&"escaped": 0,
		&"plants_lost": 0,
	}
	var spawned: Dictionary = {"count": 0}
	var seen: Dictionary = {}
	var pests: Array[Pest] = []
	var kernels: Array[Kernel] = []

	# COUNTED OFF THE SCHEDULE, not off the children of `_entities`, and the difference is
	# a boss's brood: `RunSim._play_one_wave` increments `spawned` in its own
	# `spawn_requested` handler and `_new_pest` does not, so a queen that bursts adds three
	# pests to the road and nothing to this number. A census of new Pest nodes would count
	# them, and the wave-cleared condition below reads this against
	# `current_wave_pest_count()`.
	game.director.spawn_requested.connect(func(_species: StringName, _mutations: Array) -> void:
		spawned["count"] = int(spawned["count"]) + 1)

	# Before the purse is set and before anything is planted, for the same reason
	# `RunSim._begin_wave` captures it there: the wave owns the shopping that precedes it.
	var earned_start: int = game.bank.seeds_earned_total

	var unlocks: Array[StringName] = scenario["unlocks"]
	game.bank.seeds = PURSE
	game.bank.unlocked = unlocks.duplicate()
	var placed: int = 0
	for entry: Dictionary in scenario["garden"] as Array:
		var refusal: String = game.place_plant(entry["id"] as StringName, entry["cell"] as Vector2i)
		if refusal != "":
			out["failure"] = "the game refused %s at %s: %s" % [
				entry["id"], entry["cell"], refusal]
			_T.free_ui(game)
			return out
		placed += 1
	out["placed"] = placed
	_adopt(game, seen, tally, pests)

	# The prep window, stepped for real. `Plant._regrow` and `Sunflower._act` both run off
	# it, and the seconds come from the difficulty profile -- the same count of frames
	# `RunSim._step_prep` takes, off the same number.
	var prep_frames: int = int(round(game.prep_seconds / DT))
	for i: int in range(prep_frames):
		_step_game_frame(game, tally, seen, pests, kernels)

	# The wave itself. `Game.start_next_wave()` reaches `WaveDirector.wave_started`
	# synchronously, so `_on_wave_started` has applied this wave's weather to every
	# standing plant before the first frame below -- exactly where `RunSim._play_one_wave`
	# calls `_apply_weather`.
	if not game.start_next_wave():
		out["failure"] = "the game refused to start a wave at all"
		_T.free_ui(game)
		return out
	var frame: int = 0
	while frame < WAVE_FRAME_CEILING:
		frame += 1
		game.director._process(DT)
		# Immediately, so a pest spawned by that call is connected before anything can
		# shoot it: a kill counted by nobody is indistinguishable from a kill that did not
		# happen.
		_adopt(game, seen, tally, pests)
		_step_game_frame(game, tally, seen, pests, kernels)
		if game.lives <= 0:
			break
		if int(spawned["count"]) >= game.director.current_wave_pest_count() and _live(pests) == 0:
			break
	if frame >= WAVE_FRAME_CEILING:
		out["failure"] = ("wave %d spent its whole %d-frame ceiling without clearing "
			+ "(%d of %d spawned, %d still walking)") % [
				game.director.current_wave, WAVE_FRAME_CEILING, int(spawned["count"]),
				game.director.current_wave_pest_count(), _live(pests)]
		_T.free_ui(game)
		return out

	tally[&"seeds_earned"] = game.bank.seeds_earned_total - earned_start
	tally[&"lives_lost"] = game.starting_lives - game.lives
	out["axes"] = tally
	out["records"] = 1
	out["spawned"] = int(spawned["count"])
	out["summary"] = "Game: wave %d over %d frame(s) | lives %d/%d | seeds earned %d" % [
		game.director.current_wave, frame, game.lives, game.starting_lives,
		int(tally[&"seeds_earned"])]
	_T.free_ui(game)
	return out


## Wires every Pest and Plant the game has built since the last call.
##
## The counting happens OUT HERE rather than inside `Game`, and each number is read from
## the narrowest thing that carries it: `died` and `escaped` off the pest, `destroyed` and
## `grew_seeds` off the plant, `weather_seed_value` off the game itself. That last one is
## a CALL INTO the function `Game._on_pest_died` uses to pay the kill, not a second copy
## of the arithmetic -- and the identity `kills + growth + husks == earned` is asserted
## afterwards, which is what would catch a Game that stopped banking what it quoted.
func _adopt(game: Game, seen: Dictionary, tally: Dictionary, pests: Array[Pest]) -> void:
	for node: Node in game._entities.get_children():
		var id: int = node.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		var pest := node as Pest
		if pest != null:
			pest.set_physics_process(false)
			pests.append(pest)
			# `seeds_after_yield` FIRST, then the weather scale, in that order -- it is the
			# order `Game._on_pest_died` pays in, and the two do not commute once the
			# integer floor is involved. This tally reads 1.0 today because the scenarios
			# pin DIFFICULTY_STANDARD, whose yield is exactly the identity; without the
			# call it would silently under-report the moment anyone points this gate at
			# gentle or harsh, which is the failure the gate exists to catch happening
			# inside the gate itself.
			pest.died.connect(func(dead: Pest) -> void:
				var paid: int = game.weather_seed_value(
					Game.seeds_after_yield(dead.seed_value, game.seed_yield))
				tally[&"killed"] = int(tally[&"killed"]) + 1
				tally[&"seeds_from_kills"] = int(tally[&"seeds_from_kills"]) + paid)
			pest.escaped.connect(func(_gone: Pest) -> void:
				tally[&"escaped"] = int(tally[&"escaped"]) + 1)
			continue
		var plant := node as Plant
		if plant != null:
			plant.set_physics_process(false)
			plant.destroyed.connect(func(_lost: Plant) -> void:
				tally[&"plants_lost"] = int(tally[&"plants_lost"]) + 1)
			# Duck-typed exactly as `Game._install_plant` wires it: a future economy plant
			# only has to declare the signal to be counted here.
			if plant.has_signal("grew_seeds"):
				plant.connect("grew_seeds", func(amount: int) -> void:
					var grown: int = Game.seeds_after_yield(amount, game.seed_yield)
					tally[&"seeds_from_growth"] = int(tally[&"seeds_from_growth"]) + grown)


## One physics frame over the hosted game, in the order `RunSim._step_frame` established:
## plants, then the kernels they launched, then the pests, then the ground.
##
## A kernel is held back a frame the way a node added mid-physics is in a real tree --
## `known` is read BEFORE the new ones are adopted, which is the whole of that rule.
func _step_game_frame(game: Game, tally: Dictionary, seen: Dictionary,
		pests: Array[Pest], kernels: Array[Kernel]) -> void:
	for cell: Vector2i in game._plants.keys():
		var plant := game._plants[cell] as Plant
		if plant == null or not is_instance_valid(plant) or plant.is_destroyed():
			continue
		plant._physics_process(DT)
	var known: int = kernels.size()
	for node: Node in game._entities.get_children():
		var fresh := node as Kernel
		if fresh != null and not kernels.has(fresh):
			fresh.set_physics_process(false)
			kernels.append(fresh)
	for i: int in range(known):
		var shot: Kernel = kernels[i]
		if not is_instance_valid(shot) or shot.is_queued_for_deletion():
			continue
		shot._physics_process(DT)
	# A boss's brood is built inside `_on_pest_died`, which fires from inside the kernel
	# step above -- so it is adopted here, in time to be walked on the frame it was born,
	# which is what `RunSim` does by appending to its own list at construction.
	_adopt(game, seen, tally, pests)
	for pest: Pest in pests.duplicate():
		if is_instance_valid(pest) and pest.is_alive():
			pest._physics_process(DT)
	game.compost._process(DT)
	_sweep(game, tally)
	game._tick_cross_breeding(DT)
	_collect_garbage(game, pests, kernels)


## Every husk within reach of itself, swept, and the seeds banked -- `game.gd:3178-3180`
## without the click geometry, which is the same pair `RunSim._sweep` runs.
func _sweep(game: Game, tally: Dictionary) -> void:
	for husk: Dictionary in game.compost.husks():
		var value: int = game.compost.collect_at(husk["position"] as Vector2)
		if value <= 0:
			continue
		game.bank.add_seeds(value)
		tally[&"seeds_from_husks"] = int(tally[&"seeds_from_husks"]) + value


## Frees the corpses and the spent kernels this frame produced.
##
## At the END of the frame and never inside a signal handler: `died` fires from inside
## `Kernel._physics_process`, and freeing the pest there would pull the node out from
## under the loop iterating it. A plant that was eaten is deliberately LEFT standing --
## `Game._on_plant_destroyed` has already taken it out of `_plants` and called
## `play_exit_and_free()`, and every reader left (`Pest._blocking_plant`,
## `Pest._adjacent_plant`, `_refresh_neighbour_buffs`) asks `is_destroyed()` first. It
## goes with the scene at teardown.
func _collect_garbage(game: Game, pests: Array[Pest], kernels: Array[Kernel]) -> void:
	var still: Array[Kernel] = []
	for shot: Kernel in kernels:
		if not is_instance_valid(shot):
			continue
		if shot.is_queued_for_deletion():
			_detach_and_free(shot)
			continue
		still.append(shot)
	kernels.assign(still)
	var walking: Array[Pest] = []
	for pest: Pest in pests:
		if not is_instance_valid(pest):
			continue
		if pest.is_alive():
			walking.append(pest)
			continue
		_detach_and_free(pest)
	pests.assign(walking)


## Off the tree and gone, in that order and asking for the parent rather than assuming it.
## `Game._new_pest` and `CornCobbler` both parent to `Entities` today, but a node freed
## while still parented leaves its group membership visible for the rest of the frame --
## which is exactly the reading `Plant._live_pests` and `Game._check_wave_cleared` make.
func _detach_and_free(node: Node) -> void:
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.free()


func _live(pests: Array[Pest]) -> int:
	var n: int = 0
	for pest: Pest in pests:
		if is_instance_valid(pest) and pest.is_alive():
			n += 1
	return n


# -- the gate ------------------------------------------------------------------


## Neither side may be measuring somebody else's garden, and both must have played.
func _sound(side: String, run: Dictionary, expected_placed: int) -> String:
	# THE DRIVER'S OWN COMPLAINT FIRST. Every other field is unset on a run that refused
	# to start, so checking the census ahead of this would report a contaminated tree for
	# a game that never hosted.
	var err: String = _T.assert_eq(String(run["failure"]), "",
		"%s: the driver stopped the run itself -- %s" % [side, String(run["summary"])])
	if err != "":
		return err
	err = _T.assert_eq(int(run["foreign"]), 0,
		("%s: a sibling test's pests or plants were standing in the tree-global groups, "
			+ "so every kill, every escape and every coverage read in this run may be "
			+ "theirs") % side)
	if err != "":
		return err
	err = _T.assert_eq(int(run["records"]), 1,
		"%s: one wave was asked for and %d came back" % [side, int(run["records"])])
	if err != "":
		return err
	return _T.assert_eq(int(run["placed"]), expected_placed,
		("%s: the garden was not planted in full -- %d of %d cells took a plant, so the "
			+ "two sides are not playing the same board") % [side, int(run["placed"]),
				expected_placed])


func test_the_mirror_and_the_game_agree_on_one_wave() -> String:
	var built: Dictionary = _scenarios()
	var err: String = _T.assert_false(built.has("problem"),
		"the gardens could not be derived from a real Board: %s" % String(built.get("problem", "")))
	if err != "":
		return err
	var scenarios: Array = built["scenarios"]
	err = _T.assert_gt(scenarios.size(), 0,
		"there is a scenario to play -- a loop over an empty list is the vacuous pass")
	if err != "":
		return err
	err = _T.assert_eq(AXES.size(), 8,
		"the bead names eight numbers the mirror is responsible for and AXES lists %d"
			% AXES.size())
	if err != "":
		return err

	# Which axes any scenario actually MOVED. Printed at the end beside the ones that
	# stayed at zero on both sides, because "the pair agreed" and "the pair agreed about
	# nothing" print identically otherwise.
	var exercised: Dictionary = {}

	for scenario: Dictionary in scenarios:
		var label: String = String(scenario["name"])
		var expected_placed: int = (scenario["garden"] as Array).size()

		# SEQUENTIALLY, never overlapped. `plants` and `pests` are TREE-GLOBAL groups that
		# `Plant._live_pests` and `Pest._blocking_plant` both read, so two hosted gardens
		# in one tree shoot at each other's bugs. See .claude/skills/godot-test-isolation.
		var mirror: Dictionary = await _sim_side(scenario)
		err = _sound("%s/RunSim" % label, mirror, expected_placed)
		if err != "":
			return err
		var real: Dictionary = await _game_side(scenario)
		err = _sound("%s/Game" % label, real, expected_placed)
		if err != "":
			return err

		print("  [%s] %s" % [label, String(mirror["summary"])])
		print("  [%s] %s" % [label, String(real["summary"])])

		# THE TABLE IS CHECKED BEFORE IT IS READ, in both directions and on both sides: an
		# axis a tally forgot to fill would otherwise be compared as a missing key against
		# a missing key, which is the quietest way for this gate to stop asking.
		var mirror_axes: Dictionary = mirror["axes"]
		var real_axes: Dictionary = real["axes"]
		for axis: StringName in AXES:
			err = _T.assert_true(mirror_axes.has(axis),
				"[%s] RunSim's tally is missing the `%s` axis" % [label, axis])
			if err != "":
				return err
			err = _T.assert_true(real_axes.has(axis),
				"[%s] the Game's tally is missing the `%s` axis" % [label, axis])
			if err != "":
				return err
		err = _T.assert_eq(mirror_axes.size(), AXES.size(),
			"[%s] RunSim's tally carries an axis AXES does not name: %s vs %s"
				% [label, mirror_axes.keys(), AXES])
		if err != "":
			return err
		err = _T.assert_eq(real_axes.size(), AXES.size(),
			"[%s] the Game's tally carries an axis AXES does not name: %s vs %s"
				% [label, real_axes.keys(), AXES])
		if err != "":
			return err

		# The premise, ahead of the claim: two wave schedules that sent different numbers
		# of pests would make every axis below a comparison of two different waves.
		err = _T.assert_eq(int(real["spawned"]), int(mirror["spawned"]),
			("[%s] the two sides did not even send the same wave -- RunSim spawned %d and "
				+ "the game spawned %d, so nothing below is a claim about the mirror")
				% [label, int(mirror["spawned"]), int(real["spawned"])])
		if err != "":
			return err

		# THE CLAIM.
		for axis: StringName in AXES:
			var mine: int = int(mirror_axes[axis])
			var theirs: int = int(real_axes[axis])
			if mine != 0 or theirs != 0:
				exercised[axis] = true
			err = _T.assert_eq(mine, theirs,
				("[%s] `%s` DRIFTED: tools/run_sim.gd made it %d and game/game.gd made it "
					+ "%d on the same wave, the same seed and the same garden. The `## "
					+ "Mirrors` comment naming this branch is now a citation of something "
					+ "that no longer agrees, and every number in docs/playtest-runs.jsonl "
					+ "that depends on it describes RunSim rather than the game.")
					% [label, axis, mine, theirs])
			if err != "":
				return err

		# What this scenario was built to reach. Agreement on a wave where nothing
		# happened is the pass this harness warns about loudest.
		for axis: StringName in scenario["floors"] as Array:
			err = _T.assert_gt(int(real_axes[axis]),  0,
				("[%s] the scenario exists to exercise `%s` and the wave never moved it, "
					+ "so the two sides agreed about nothing on that axis") % [label, axis])
			if err != "":
				return err

		# The split must ACCOUNT for the total on the GAME side too. `test_playtest`
		# already pins this for RunSim; without it here, a game that stopped banking a
		# kill it still quoted through `weather_seed_value` would read clean above.
		err = _T.assert_eq(
			int(real_axes[&"seeds_from_kills"]) + int(real_axes[&"seeds_from_growth"])
				+ int(real_axes[&"seeds_from_husks"]),
			int(real_axes[&"seeds_earned"]),
			("[%s] the game's three income columns do not add up to what its bank says it "
				+ "earned -- a fourth source moved seeds without being counted") % label)
		if err != "":
			return err

	var idle: PackedStringArray = PackedStringArray()
	for axis: StringName in AXES:
		if not exercised.has(axis):
			idle.append(String(axis))
	print("  Mirror parity: %d of %d axes moved across %d scenario(s)%s" % [
		exercised.size(), AXES.size(), scenarios.size(),
		("" if idle.is_empty() else " | NEVER MOVED: " + ", ".join(idle))])
	return _T.assert_eq(idle.size(), 0,
		("every axis must be moved by at least one scenario or the pair is agreeing about "
			+ "zero: %s never moved") % ", ".join(idle))
