extends RefCounted

## Placement, against a real Game rather than a stub — the refusal strings are
## what the HUD prints and what the devtools `place_plant` verb returns, so they
## are part of the interface.

const GAME_SCENE := "res://game/game.tscn"

var _T


func _grass(game: Game) -> Vector2i:
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var cell := Vector2i(x, y)
			if game.board.is_buildable(cell) and game.plant_at(cell) == null:
				return cell
	return Vector2i(-1, -1)


func _road(game: Game) -> Vector2i:
	return game.board.world_to_cell(game.board.route()[2])


func test_the_first_corn_cobbler_is_free_and_the_second_is_not() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	var before: int = game.bank.seeds
	err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, _grass(game)), "", "the free starter goes in")
	if err == "":
		err = _T.assert_eq(game.bank.seeds, before, "and cost nothing")
	if err == "":
		err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, _grass(game)), "", "a second one goes in")
	if err == "":
		err = _T.assert_eq(game.bank.seeds, before - PlantCatalog.cost(PlantCatalog.CORN),
			"and was charged for")
	_T.free_ui(game)
	return err


func test_nothing_can_be_planted_on_the_road() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, _road(game)), "pests walk there",
		"the road refuses plants, by name")
	if err == "":
		err = _T.assert_eq(game.state()["plants"], 0, "and nothing was planted anyway")
	_T.free_ui(game)
	return err


func test_a_cell_holds_one_plant() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var cell: Vector2i = _grass(game)
	game.bank.add_seeds(100)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "", "first plant goes in")
	if err == "":
		err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "something is already growing there",
			"the second is refused")
	_T.free_ui(game)
	return err


func test_a_locked_plant_cannot_be_placed_even_with_seeds() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(500)
	var locked: Array[StringName] = game.bank.locked_plants()
	var err: String = _T.assert_gt(locked.size(), 0, "something is still in a packet")
	if err == "":
		err = _T.assert_eq(game.place_plant(locked[0], _grass(game)), "not paid for",
			"a locked plant is refused at the till")
	_T.free_ui(game)
	return err


func test_a_packet_makes_its_plant_placeable() -> String:
	## The full loop the doc describes: seeds -> packet -> plant on the board.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.set_seed(99)
	game.bank.add_seeds(500)
	var got: StringName = game.bank.buy_packet()
	var err: String = _T.assert_true(got != &"", "the packet held a plant")
	if err == "":
		err = _T.assert_eq(game.place_plant(got, _grass(game)), "", "and it can now be planted")
	if err == "":
		err = _T.assert_eq(game.state()["plants"], 1, "the board knows about it")
	_T.free_ui(game)
	return err


func test_uprooting_frees_the_cell_and_returns_some_seeds() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(100)
	var cell: Vector2i = _grass(game)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "", "planted")
	if err == "":
		var seeds_before: int = game.bank.seeds
		err = _T.assert_eq(game.uproot_selected(), "", "uprooting the selected plant succeeds")
		if err == "":
			err = _T.assert_gt(game.bank.seeds, seeds_before, "some seeds came back")
		if err == "":
			err = _T.assert_true(game.plant_at(cell) == null, "the cell is free again")
	_T.free_ui(game)
	return err


## The button path, not the mutator underneath it. `uproot_selected` above stays
## deliberately unguarded; everything a player can click goes through this.
func test_one_uproot_click_only_arms_and_a_second_commits() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(100)
	var cell: Vector2i = _grass(game)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "", "planted")
	if err == "":
		var seeds_before: int = game.bank.seeds
		err = _T.assert_eq(game.request_uproot(), "confirm needed", "the first click refuses")
		if err == "":
			err = _T.assert_true(game.plant_at(cell) != null, "the plant is still in the ground")
		if err == "":
			err = _T.assert_eq(game.bank.seeds, seeds_before, "and nothing was refunded yet")
		if err == "":
			err = _T.assert_true(game.uproot_armed(), "but the button is armed")
		if err == "":
			err = _T.assert_eq(game.request_uproot(), "", "the second click commits")
		if err == "":
			err = _T.assert_true(game.plant_at(cell) == null, "the cell is free")
		if err == "":
			err = _T.assert_gt(game.bank.seeds, seeds_before, "and the refund landed exactly once")
		if err == "":
			err = _T.assert_false(game.uproot_armed(), "the arming did not survive the commit")
	_T.free_ui(game)
	return err


func test_an_armed_uproot_disarms_itself_and_leaves_the_plant() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(100)
	var cell: Vector2i = _grass(game)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "", "planted")
	if err == "":
		err = _T.assert_eq(game.request_uproot(), "confirm needed", "armed")
	if err == "":
		# Pumped by hand: the runner advances frames, not wall clock, so a window
		# measured in seconds never expires on its own here.
		game._process(Game.UPROOT_CONFIRM_SECONDS + 0.1)
		err = _T.assert_false(game.uproot_armed(), "the window closed")
	if err == "":
		err = _T.assert_true(game.plant_at(cell) != null, "and the plant survived it")
	if err == "":
		# The click after a timeout must arm again rather than fall through to a
		# commit — that is the misclick the whole gate exists to stop.
		err = _T.assert_eq(game.request_uproot(), "confirm needed", "the next click re-arms")
	if err == "":
		err = _T.assert_true(game.plant_at(cell) != null, "still in the ground")
	_T.free_ui(game)
	return err


func test_selecting_another_plant_cancels_a_pending_uproot() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(200)
	var first: Vector2i = _grass(game)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, first), "", "first planted")
	if err == "":
		err = _T.assert_eq(game.request_uproot(), "confirm needed", "armed on the first")
	if err == "":
		var second: Vector2i = _grass(game)
		err = _T.assert_true(second != first, "there is a second free cell")
		if err == "":
			err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, second), "", "second planted")
		if err == "":
			# place_plant auto-selects, so this is the real "clicked elsewhere" path.
			err = _T.assert_false(game.uproot_armed(), "the arming did not follow the selection")
		if err == "":
			err = _T.assert_eq(game.request_uproot(), "confirm needed",
				"and a click on the new plant arms rather than digging it up")
		if err == "":
			err = _T.assert_true(game.plant_at(second) != null, "the second plant is still there")
		if err == "":
			err = _T.assert_true(game.plant_at(first) != null, "and so is the first")
	_T.free_ui(game)
	return err


func test_a_wave_puts_pests_on_the_board() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game.start_next_wave(), "wave 1 starts")
	if err == "":
		err = _T.assert_eq(game.state()["wave"], 1, "and the HUD's wave number moves")
	if err == "":
		# Drive the director's schedule directly: a real wave takes ~10 seconds of
		# wall clock and the runner pumps frames, not time.
		var guard: int = 0
		while game.director.is_spawning() and guard < 4000:
			game.director._process(0.1)
			guard += 1
		err = _T.assert_eq(game.state()["pests_alive"], WaveDirector.pests_in_wave(1),
			"every pest the table promised is on the road")
	_T.free_ui(game)
	return err


## The Corn Cobbler's muzzle fan — the per-level drawing on the board.
##
## Upgrading already moved `level` and already relabelled the selection panel, so
## asserting either of those passes on the version of the code where paying 45
## seeds changed nothing you could see. These assert the geometry that gets
## drawn instead, and that it is derived from LEVELS rather than eyeballed.
func test_each_corn_cobbler_level_draws_a_visibly_different_muzzle_fan() -> String:
	var widths: Array[float] = []
	var err: String = ""
	for lvl: int in range(1, CornCobbler.LEVELS.size() + 1):
		var pips: PackedVector2Array = CornCobbler.muzzle_pips(lvl)
		err = _T.assert_eq(pips.size(), int(CornCobbler.LEVELS[lvl - 1]["kernels"]),
			"level %d draws one pip per kernel it fires" % lvl)
		if err != "":
			return err
		# Pips packed tighter than their own width merge into a single blob, which
		# is the "level 2 looks exactly like level 1" complaint all over again.
		for i: int in range(pips.size() - 1):
			err = _T.assert_gte(pips[i].distance_to(pips[i + 1]),
				CornCobbler.pip_outer_radius() * 2.0,
				"level %d holds pips %d and %d far enough apart to count" % [lvl, i, i + 1])
			if err != "":
				return err
		widths.append(pips[0].distance_to(pips[pips.size() - 1]))
	for i: int in range(widths.size()):
		for j: int in range(i + 1, widths.size()):
			err = _T.assert_gt(absf(widths[j] - widths[i]), 4.0,
				"level %d and level %d are not the same picture" % [i + 1, j + 1])
			if err != "":
				return err
	return ""


## The fidelity claim: the fan is not a decoration that happens to grow, it is
## the firing table. Every pip sits on the angle its own kernel launches on.
func test_the_muzzle_fan_is_drawn_on_the_angles_the_kernels_are_fired_on() -> String:
	var err: String = ""
	# Deliberately off-axis: a fan that only lines up while aiming right would
	# pass at an aim of 0 and be wrong on every real shot.
	var aim: float = deg_to_rad(35.0)
	for lvl: int in range(1, CornCobbler.LEVELS.size() + 1):
		var entry: Dictionary = CornCobbler.LEVELS[lvl - 1]
		var offsets: PackedFloat32Array = CornCobbler.kernel_angle_offsets(lvl)
		err = _T.assert_eq(offsets.size(), int(entry["kernels"]),
			"level %d fires the kernel count in the table" % lvl)
		if err != "":
			return err
		var span: float = rad_to_deg(offsets[offsets.size() - 1] - offsets[0])
		err = _T.assert_float_eq(span, float(entry["spread_degrees"]), 0.01,
			"level %d spans exactly the table's spread_degrees" % lvl)
		if err == "":
			err = _T.assert_float_eq(offsets[0] + offsets[offsets.size() - 1], 0.0, 0.0001,
				"level %d fans symmetrically about where it aims" % lvl)
		if err != "":
			return err
		var pivot: Vector2 = CornCobbler.muzzle_pivot(aim)
		var pips: PackedVector2Array = CornCobbler.muzzle_pips(lvl, aim)
		for i: int in range(pips.size()):
			var ray: Vector2 = pips[i] - pivot
			err = _T.assert_float_eq(ray.length(), CornCobbler.FAN_LENGTH, 0.01,
				"level %d pip %d sits on the fan" % [lvl, i])
			if err == "":
				err = _T.assert_float_eq(wrapf(ray.angle() - (aim + offsets[i]), -PI, PI), 0.0,
					0.0005, "level %d pip %d is on kernel %d's own firing angle" % [lvl, i, i])
			if err != "":
				return err
	return ""


## The fan turns to follow whatever the cob last shot at, so "it fits" has to
## hold at every aim, not just the one the screenshot was taken at. A pip that
## wanders off its own cell is drawing on the neighbouring plant's.
func test_the_muzzle_fan_stays_inside_its_cell_at_every_aim() -> String:
	var limit: float = Board.CELL * 0.5 - CornCobbler.pip_outer_radius()
	var err: String = ""
	for step: int in range(24):
		var aim: float = TAU * float(step) / 24.0
		for lvl: int in range(1, CornCobbler.LEVELS.size() + 1):
			for pip: Vector2 in CornCobbler.muzzle_pips(lvl, aim):
				err = _T.assert_gte(limit, pip.length(),
					"level %d aiming %d deg keeps its pips on its own cell" % [lvl, int(rad_to_deg(aim))])
				if err != "":
					return err
	return ""


## And the same thing on a real plant on a real board, walked through the upgrade
## path the player actually pays for.
func test_upgrading_a_planted_cobbler_changes_what_it_draws() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(500)
	var cell: Vector2i = _grass(game)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "", "planted")
	var corn: CornCobbler = null
	if err == "":
		corn = game.plant_at(cell) as CornCobbler
		err = _T.assert_true(corn != null, "and it is a Corn Cobbler")
	var upgrades: int = 0
	while err == "" and not corn.is_max_level():
		var before: PackedVector2Array = corn.muzzle_pip_positions()
		err = _T.assert_true(corn.upgrade(), "level %d buys the next level" % corn.level)
		if err != "":
			break
		upgrades += 1
		var after: PackedVector2Array = corn.muzzle_pip_positions()
		err = _T.assert_eq(after.size(), corn.kernels_per_shot(),
			"level %d draws its new kernel count" % corn.level)
		if err == "":
			err = _T.assert_gt(after.size(), before.size(), "which is more pips than before")
		if err == "":
			err = _T.assert_gt(after[after.size() - 1].distance_to(after[0]),
				before[before.size() - 1].distance_to(before[0]),
				"and the fan is wider, so the board shows what the seeds bought")
	if err == "":
		err = _T.assert_eq(upgrades, CornCobbler.LEVELS.size() - 1,
			"every level above the first was actually walked through")
	_T.free_ui(game)
	return err
