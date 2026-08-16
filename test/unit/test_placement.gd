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


## The placement preview's own node, by the path Game builds it at. Reached
## rather than rebuilt because the dead-zone cue resolves its Board from its own
## siblings, and a preview constructed in isolation would never exercise that.
func _preview(game: Game) -> PlacementPreview:
	return game.get_node_or_null("Entities/PlacementPreview") as PlacementPreview


## The measurement plant-tower-defense-61k is built on, pinned against the real
## route rather than against a fixture: of 94 buildable cells, 15 cover no road
## at a Corn Cobbler's reach and 34 cover none at a Chomp Flower's. If a future
## PATH_CORNERS change strands more ground than that, this is the line that says
## so — the numbers are the point, not an implementation detail of the cue.
func test_the_real_route_strands_exactly_the_cells_it_was_measured_to_strand() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var corn_reach: float = PlantCatalog.reach(PlantCatalog.CORN)
	var chomp_reach: float = PlantCatalog.reach(PlantCatalog.CHOMP)
	# The catalog is the single source of truth the cue reads; these pin it to
	# the plants' own constants, so a balance change cannot quietly decouple the
	# warning from the gun.
	var err: String = _T.assert_float_eq(corn_reach, CornCobbler.RANGE, 0.001,
		"the previewed corn reach is the cobbler's own RANGE")
	if err == "":
		err = _T.assert_float_eq(chomp_reach, ChompFlower.GRAB_RADIUS, 0.001,
			"and the previewed chomp reach is the flower's own GRAB_RADIUS")
	if err != "":
		_T.free_ui(game)
		return err
	var buildable: int = 0
	var dead_corn: int = 0
	var dead_chomp: int = 0
	var corn_covered_total: int = 0
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var cell := Vector2i(x, y)
			if not game.board.is_buildable(cell):
				continue
			buildable += 1
			var corn_cover: int = PlacementPreview.covered_road_cells(game.board, cell, corn_reach)
			corn_covered_total += corn_cover
			if corn_cover == 0:
				dead_corn += 1
			if PlacementPreview.covered_road_cells(game.board, cell, chomp_reach) == 0:
				dead_chomp += 1
	err = _T.assert_eq(buildable, 94, "the route leaves 94 buildable cells")
	if err == "":
		# Vacuity guards, ahead of the exact counts: a walk that found no ground
		# at all, or a coverage function answering zero everywhere, would
		# otherwise be indistinguishable from a board with nothing wrong on it.
		err = _T.assert_gt(corn_covered_total, 0, "and some of them do cover road")
	if err == "":
		err = _T.assert_gt(dead_corn, 0, "and some of them cover none at all")
	if err == "":
		err = _T.assert_eq(dead_corn, 15, "15 cells are dead ground for a Corn Cobbler")
	if err == "":
		err = _T.assert_eq(dead_chomp, 34, "and 34 are dead ground for a Chomp Flower")
	if err == "":
		err = _T.assert_gt(dead_chomp, dead_corn,
			"the shorter reach strands strictly more of the board")
	_T.free_ui(game)
	return err


## Dead ground is a property of the plant, not of the cell — which is the whole
## reason the cue cannot be baked into the board. (2, 3) is legal and empty, and
## six road cells sit inside a Corn Cobbler's reach of it; a Chomp Flower
## standing on the same square can touch none of them.
func test_a_cell_can_be_dead_ground_for_a_chomp_and_good_ground_for_a_corn() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var split := Vector2i(2, 3)
	var corn_reach: float = PlantCatalog.reach(PlantCatalog.CORN)
	var chomp_reach: float = PlantCatalog.reach(PlantCatalog.CHOMP)
	var err: String = _T.assert_true(game.board.is_buildable(split),
		"(2, 3) is somewhere a plant may actually stand")
	if err == "":
		err = _T.assert_eq(PlacementPreview.covered_road_cells(game.board, split, corn_reach), 6,
			"a Corn Cobbler there covers six road cells")
	if err == "":
		err = _T.assert_eq(PlacementPreview.covered_road_cells(game.board, split, chomp_reach), 0,
			"and a Chomp Flower on the very same cell covers none")
	# And the live node agrees with the static measurement, per plant, with
	# nothing but its own position and reach to go on.
	var preview: PlacementPreview = _preview(game)
	if err == "":
		err = _T.assert_true(preview != null, "the game built a placement preview")
	if err == "":
		preview.position = game.board.cell_to_world(split)
		preview.placeable = true
		preview.reach = chomp_reach
		err = _T.assert_true(preview.shows_dead_zone(), "the preview marks it dead for a chomp")
	if err == "":
		preview.reach = corn_reach
		err = _T.assert_false(preview.shows_dead_zone(),
			"and marks the identical cell fine for a corn")
	_T.free_ui(game)
	return err


## Precedence: an illegal cell gets one refusal, not a refusal plus a critique.
## The geometry still says the cell is dead — that is what makes this a test of
## the rule rather than of a cell that happens to be fine anyway.
func test_an_illegal_cell_is_never_also_marked_dead_ground() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var dead := Vector2i(13, 0)
	var preview: PlacementPreview = _preview(game)
	var err: String = _T.assert_true(preview != null, "the game built a placement preview")
	if err == "":
		preview.position = game.board.cell_to_world(dead)
		preview.reach = PlantCatalog.reach(PlantCatalog.CORN)
		preview.placeable = true
		err = _T.assert_false(preview.covers_road(),
			"(13, 0) is out of a Corn Cobbler's reach of the road")
	if err == "":
		err = _T.assert_true(preview.shows_dead_zone(), "so a legal hover there is marked dead")
	if err == "":
		# Road, occupied and unaffordable all arrive here as the same flag.
		preview.placeable = false
		err = _T.assert_false(preview.shows_dead_zone(),
			"but an illegal hover draws only the refusal, never both cues")
	if err == "":
		err = _T.assert_false(preview.covers_road(),
			"the geometry is unchanged — legality is what suppressed the mark")
	_T.free_ui(game)
	return err


## The other half of the precedence rule: the dead-zone mark and the at-risk
## dashes test opposite sides of `reach > 0`, so nothing that fires one can fire
## the other. A Seed Sunflower is never dead ground; it was never going to shoot.
func test_a_plant_with_no_reach_is_warned_about_but_never_called_dead_ground() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var preview: PlacementPreview = _preview(game)
	var err: String = _T.assert_true(preview != null, "the game built a placement preview")
	if err == "":
		err = _T.assert_float_eq(PlantCatalog.reach(PlantCatalog.SUNFLOWER), 0.0, 0.001,
			"the sunflower reaches nothing by design")
	var beside := Vector2i(-1, -1)
	var stranded := Vector2i(-1, -1)
	if err == "":
		for y: int in range(Board.ROWS):
			for x: int in range(Board.COLS):
				var cell := Vector2i(x, y)
				if not game.board.is_buildable(cell):
					continue
				if beside == Vector2i(-1, -1) and game.board.is_road_adjacent(cell):
					beside = cell
				var chomp: float = PlantCatalog.reach(PlantCatalog.CHOMP)
				var cover: int = PlacementPreview.covered_road_cells(game.board, cell, chomp)
				if stranded == Vector2i(-1, -1) and cover == 0:
					stranded = cell
		err = _T.assert_true(beside != Vector2i(-1, -1), "a cell beside the road exists")
		if err == "":
			err = _T.assert_true(stranded != Vector2i(-1, -1),
				"and so does a cell no chomp could ever reach the road from")
	for cell: Vector2i in [beside, stranded]:
		if err != "":
			break
		preview.position = game.board.cell_to_world(cell)
		preview.placeable = true
		preview.reach = PlantCatalog.reach(PlantCatalog.SUNFLOWER)
		preview.at_risk = game.board.is_road_adjacent(cell)
		err = _T.assert_false(preview.shows_dead_zone(),
			"a sunflower on %s is never dead ground" % cell)
		if err == "":
			err = _T.assert_true(preview.covers_road(),
				"the coverage question is meaningless for it, and answers benignly")
	if err == "":
		preview.position = game.board.cell_to_world(beside)
		preview.reach = PlantCatalog.reach(PlantCatalog.CORN)
		preview.at_risk = false
		err = _T.assert_false(preview.shows_dead_zone(),
			"and a cobbler beside the road, which is the point of a cobbler, is not marked either")
	_T.free_ui(game)
	return err
