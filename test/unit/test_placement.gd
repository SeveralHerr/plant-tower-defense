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


# -- Sticky Sundew (plant-tower-defense-fdm) ---------------------------------
#
# The fourth plant, and the first that acts on more than one pest at a time. Its
# whole mechanic is a number on a pest (`speed`) being turned down and put back,
# which is exactly the kind of thing that looks fine on screen while leaving the
# board permanently sticky — so most of what follows drives the patch by hand and
# asserts the arithmetic rather than watching a bug walk.


## A Sundew built directly onto the entities layer rather than through
## `Game.place_plant`. Deliberate: everything below is about the mechanic, and
## routing it through the catalogue would make every one of these tests also a
## test of Game._new_plant's match statement. That claim gets its own test, at the
## bottom, so a missing line there fails one test with the fix in the message
## instead of failing nine with the same one.
func _sundew_at(game: Game, cell: Vector2i) -> StickySundew:
	var sundew := StickySundew.new()
	game.get_node("Entities").add_child(sundew)
	sundew.setup(PlantCatalog.SUNDEW, cell, game.board)
	return sundew


## A live aphid standing where you put it, in the same space the plants are in.
## Built through `Pest.setup` so it carries the species' real speed — the number
## under test is the one the game spawns with, not a fixture's.
func _pest_at(game: Game, where: Vector2, mutation: StringName = &"") -> Pest:
	var pest := Pest.new()
	game.get_node("Entities").add_child(pest)
	pest.setup(Pest.APHID, game.board.route())
	if mutation != &"":
		pest.apply_mutation(mutation)
	pest.position = where
	return pest


## Every id, every field the HUD and the packet reveal read off it. A plant added
## to PLANTS but left out of ORDER never appears in the shop; one with no blurb
## prints an empty reveal card; one whose texture was never rendered draws
## nothing at all and reports no error while doing it.
func test_every_catalogue_entry_is_complete_and_orderly() -> String:
	var ids: Array[StringName] = PlantCatalog.ids()
	var err: String = _T.assert_eq(ids.size(), PlantCatalog.PLANTS.size(),
		"ORDER lists every plant in PLANTS — one missing is a plant no shop row shows")
	if err != "":
		return err
	var seen: Array[StringName] = []
	for id: StringName in ids:
		err = _T.assert_false(seen.has(id), "%s appears in ORDER exactly once" % id)
		if err != "":
			return err
		seen.append(id)
		err = _T.assert_true(PlantCatalog.has(id), "%s has a catalogue entry" % id)
		if err == "":
			err = _T.assert_gt(PlantCatalog.display_name(id).length(), 0,
				"%s has a display name" % id)
		if err == "":
			err = _T.assert_true(PlantCatalog.display_name(id) != String(id),
				"%s's display name is written for a player, not left as the id" % id)
		if err == "":
			err = _T.assert_gt(PlantCatalog.blurb(id).length(), 0,
				"%s has a blurb — the shop row and the packet reveal both print it" % id)
		if err == "":
			err = _T.assert_gt(PlantCatalog.cost(id), 0, "%s costs seeds" % id)
		if err == "":
			err = _T.assert_gte(PlantCatalog.tier(id), 1, "%s sits in a packet tier" % id)
		if err == "":
			err = _T.assert_gte(PlantCatalog.reach(id), 0.0,
				"%s answers the reach question with a real number" % id)
		var texture: String = PlantCatalog.texture_path(id)
		if err == "":
			err = _T.assert_true(texture.begins_with("res://assets/sprites/")
				and texture.ends_with(".png"),
				"%s points at a rendered sprite, got '%s'" % [id, texture])
		if err == "":
			# test_sprite_style.gd gates the sprites it has been told about; a brand
			# new plant is by definition not in that list yet, so this is the only
			# thing standing between "the SVG was authored" and "the PNG exists".
			err = _T.assert_true(FileAccess.file_exists(texture),
				"%s's sprite is on disk — run tools/render_svg.gd if it is not" % id)
		if err != "":
			return err
	return err


## The complaint this plant was built to answer. With exactly one tier-2 plant in
## the catalogue the rare packet was a 45-seed button that worked once per run and
## was a strictly worse common packet forever after — the catalogue was the
## constraint, not the packet system. A packet is meant to be a gamble, and a
## gamble needs at least two outcomes.
func test_the_rare_packet_holds_more_than_one_thing_now() -> String:
	var bank := SeedBank.new()
	var common_cap: int = int(SeedBank.PACKET_TIERS[&"common"]["max_tier"])
	var above: Array[StringName] = []
	for id: StringName in PlantCatalog.ids():
		if PlantCatalog.tier(id) > common_cap:
			above.append(id)
	var err: String = _T.assert_gt(above.size(), 1,
		"more than one plant sits above the common cap, so a rare packet rolls rather than dispenses — got %s"
			% [above])
	if err == "":
		err = _T.assert_true(above.has(PlantCatalog.SUNDEW), "and the Sticky Sundew is one of them")
	if err == "":
		err = _T.assert_gte(int(SeedBank.PACKET_TIERS[&"rare"]["max_tier"]),
			PlantCatalog.tier(PlantCatalog.SUNDEW), "a rare packet can reach it")
	if err == "":
		err = _T.assert_gt(bank.packet_pool(&"rare").size(), bank.packet_pool(&"common").size(),
			"and reaches strictly more of a fresh catalogue than a common one does")
	# Priced as the dearest thing you can put in the ground, because it is the only
	# one that multiplies everything else already covering that road.
	if err == "":
		err = _T.assert_gt(PlantCatalog.cost(PlantCatalog.SUNDEW),
			PlantCatalog.cost(PlantCatalog.SUNFLOWER),
			"it costs more than the other tier-2 pull")
	if err == "":
		err = _T.assert_gt(PlantCatalog.cost(PlantCatalog.SUNDEW), SeedBank.STARTING_SEEDS,
			"and more than the opening purse, so a run never begins with one")
	return err


## The mechanic, both directions. The second half is the half that matters: a slow
## applied and never handed back is a permanently slower board with nothing on
## screen to explain it, which reads as balance rather than as a bug.
func test_the_sundew_patch_slows_a_pest_and_hands_its_speed_back() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var cell: Vector2i = _grass(game)
	var sundew: StickySundew = _sundew_at(game, cell)
	var pest: Pest = _pest_at(game, game.board.cell_to_world(cell) + Vector2(Board.CELL, 0.0))
	var crowd: Array[Pest] = [pest]
	var base: float = pest.speed
	var err: String = _T.assert_gt(base, 0.0, "the aphid arrives with a speed to lose")
	if err == "":
		err = _T.assert_true(sundew.covers(pest), "and is standing in the dew")
	if err == "":
		sundew.apply_patch(crowd)
		err = _T.assert_float_eq(pest.speed, StickySundew.slowed_speed(base), 0.001,
			"a caught pest walks at the model's speed, not its own")
	if err == "":
		err = _T.assert_gt(base, pest.speed, "which is slower than it arrived")
	if err == "":
		err = _T.assert_eq(sundew.stuck_count(), 1, "and the patch knows it holds one")
	if err == "":
		err = _T.assert_true(StickySundew.is_slowed(pest), "the pest agrees it is stuck")
	if err == "":
		# Out the far side. The slow is a place, not a debuff with a timer.
		pest.position += Vector2(StickySundew.SAP_RADIUS * 2.0, 0.0)
		err = _T.assert_false(sundew.covers(pest), "it has walked clear of the patch")
	if err == "":
		sundew.apply_patch(crowd)
		err = _T.assert_float_eq(pest.speed, base, 0.001,
			"leaving hands back exactly the speed it came in with")
	if err == "":
		err = _T.assert_eq(sundew.stuck_count(), 0, "and the patch is empty again")
	_T.free_ui(game)
	return err


## Two patches over one pest. Both failure modes are silent and both are balance
## bugs rather than crashes, which is why they are pinned by arithmetic: a slow
## that stacks is a stun as soon as you can afford three Sundews, and a base speed
## saved per-plant strands the pest at 55% of 55% forever once both let go.
func test_two_overlapping_sundew_patches_slow_a_pest_once_not_twice() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var cell: Vector2i = _grass(game)
	var first: StickySundew = _sundew_at(game, cell)
	var second: StickySundew = _sundew_at(game, cell)
	second.position += Vector2(Board.CELL, 0.0)
	var pest: Pest = _pest_at(game, game.board.cell_to_world(cell) + Vector2(Board.CELL * 0.5, 0.0))
	var crowd: Array[Pest] = [pest]
	var base: float = pest.speed
	var err: String = _T.assert_true(first.covers(pest) and second.covers(pest),
		"the pest is standing in both patches at once")
	if err == "":
		first.apply_patch(crowd)
		second.apply_patch(crowd)
		err = _T.assert_eq(StickySundew.slow_sources(pest), 2, "two patches are claiming it")
	if err == "":
		err = _T.assert_float_eq(pest.speed, StickySundew.slowed_speed(base), 0.001,
			"but it is slowed once, not squared — a stacking slow is a stun")
	if err == "":
		first.release_all()
		err = _T.assert_float_eq(pest.speed, StickySundew.slowed_speed(base), 0.001,
			"one patch letting go leaves the other one's dew on it")
	if err == "":
		err = _T.assert_eq(StickySundew.slow_sources(pest), 1, "with one claim outstanding")
	if err == "":
		second.release_all()
		err = _T.assert_float_eq(pest.speed, base, 0.001,
			"and the last one hands back the speed the pest was born with, not the slowed one")
	if err == "":
		err = _T.assert_false(StickySundew.is_slowed(pest), "nothing is holding it now")
	_T.free_ui(game)
	return err


## A hungry pest eats the Sundew, or the player uproots it, and the patch stops
## existing while pests are still standing in it. Freeing the node has to be a
## release, or that lane stays sticky for the rest of the run.
func test_a_sundew_that_leaves_the_board_unsticks_what_it_was_holding() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var cell: Vector2i = _grass(game)
	var sundew: StickySundew = _sundew_at(game, cell)
	var pest: Pest = _pest_at(game, game.board.cell_to_world(cell))
	var crowd: Array[Pest] = [pest]
	var base: float = pest.speed
	sundew.apply_patch(crowd)
	var err: String = _T.assert_float_eq(pest.speed, StickySundew.slowed_speed(base), 0.001,
		"the pest is stuck to begin with")
	if err == "":
		sundew.free()
		err = _T.assert_float_eq(pest.speed, base, 0.001,
			"a patch that stops existing lets go of what it was holding")
	if err == "":
		err = _T.assert_false(StickySundew.is_slowed(pest),
			"and leaves no claim behind on a pest with nothing left to explain it")
	_T.free_ui(game)
	return err


## The threat the plant was designed against. A Chomp Flower is forbidden from
## closing on a winged pest at all (ChompFlower._nearest_free_pest skips it), so
## before this plant a lane walled with mouths did precisely nothing to a flier.
## Both plants stand on the same cell here, so this is the mouth declining rather
## than the mouth being out of range.
func test_the_sundew_catches_the_winged_pest_a_chomp_is_forbidden_to_grab() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var cell: Vector2i = _grass(game)
	var sundew: StickySundew = _sundew_at(game, cell)
	var chomp := ChompFlower.new()
	game.get_node("Entities").add_child(chomp)
	chomp.setup(PlantCatalog.CHOMP, cell, game.board)
	var pest: Pest = _pest_at(game, game.board.cell_to_world(cell), Pest.MUTATION_WINGED)
	var crowd: Array[Pest] = [pest]
	var base: float = pest.speed
	var err: String = _T.assert_true(pest.is_winged, "the pest really is winged")
	if err == "":
		err = _T.assert_gt(ChompFlower.GRAB_RADIUS,
			pest.global_position.distance_to(chomp.global_position),
			"and stands well inside a Chomp Flower's grab radius")
	if err == "":
		chomp._act(0.016, crowd)
		err = _T.assert_false(chomp.is_busy(),
			"which the Chomp is still not allowed to close on")
	if err == "":
		err = _T.assert_true(pest.held_by == null, "nothing has hold of it")
	if err == "":
		sundew.apply_patch(crowd)
		err = _T.assert_float_eq(pest.speed, StickySundew.slowed_speed(base), 0.001,
			"but the dew is on the ground it is flying over, so the Sundew has it anyway")
	if err == "":
		err = _T.assert_gt(StickySundew.crossing_time_multiplier(), 1.0,
			"and every gun covering that road gets strictly longer to shoot it")
	_T.free_ui(game)
	return err


## The board readout, as pure geometry. The beads are the only thing telling the
## player where the patch ends before they spend 30 seeds putting a cob next to
## it, so a ring that drifted off SAP_RADIUS would be a lie the placement preview
## could not catch.
func test_the_dew_beads_ring_the_patch_and_swell_as_it_fills() -> String:
	var beads: PackedVector2Array = StickySundew.droplet_points()
	var err: String = _T.assert_eq(beads.size(), StickySundew.DROPLETS,
		"one bead per DROPLETS")
	if err != "":
		return err
	var step: float = beads[0].distance_to(beads[1])
	for i: int in range(beads.size()):
		err = _T.assert_float_eq(beads[i].length(), StickySundew.SAP_RADIUS, 0.01,
			"bead %d sits on the rim of the patch it is advertising" % i)
		if err == "":
			err = _T.assert_float_eq(beads[i].distance_to(beads[(i + 1) % beads.size()]), step, 0.01,
				"bead %d is spaced like every other" % i)
		if err != "":
			return err
		# Symmetric about the vertical axis, like the sprite and like the kit.
		var mirrored := Vector2(-beads[i].x, beads[i].y)
		var closest: float = INF
		for other: Vector2 in beads:
			closest = minf(closest, other.distance_to(mirrored))
		err = _T.assert_float_eq(closest, 0.0, 0.01, "bead %d has a mirror across the axis" % i)
		if err != "":
			return err
	err = _T.assert_float_eq(StickySundew.droplet_radius(0), StickySundew.DROPLET_IDLE, 0.001,
		"an empty patch draws idle beads")
	if err == "":
		err = _T.assert_float_eq(StickySundew.droplet_radius(StickySundew.DROPLET_SWELL_AT),
			StickySundew.DROPLET_FULL, 0.001, "a working one draws them full size")
	if err == "":
		err = _T.assert_float_eq(StickySundew.droplet_radius(99), StickySundew.DROPLET_FULL, 0.001,
			"and never past it, however many bugs are wading through")
	for n: int in range(1, StickySundew.DROPLET_SWELL_AT + 1):
		if err != "":
			break
		err = _T.assert_gt(StickySundew.droplet_radius(n), StickySundew.droplet_radius(n - 1),
			"catching pest %d swells the beads past catching %d" % [n, n - 1])
	return err


## A Sundew fires nothing but it does reach, so unlike a Seed Sunflower the
## dead-ground cue applies to it — and the number the preview draws has to be the
## plant's own constant rather than a second copy that can drift off it.
func test_a_sundews_previewed_reach_is_the_patch_it_actually_sticks_to() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var reach: float = PlantCatalog.reach(PlantCatalog.SUNDEW)
	var err: String = _T.assert_float_eq(reach, StickySundew.SAP_RADIUS, 0.001,
		"the previewed reach is the sundew's own SAP_RADIUS, not a second number")
	if err == "":
		err = _T.assert_gt(reach, float(Board.CELL),
			"over a cell, or it could never touch the lane it stands beside")
	if err == "":
		err = _T.assert_gt(reach, ChompFlower.GRAB_RADIUS,
			"wider than a Chomp Flower's grab, so it covers a stretch of road rather than a spot")
	if err == "":
		err = _T.assert_gt(CornCobbler.RANGE, reach,
			"and narrower than a Corn Cobbler's range, so it can never blanket a cob's whole field of fire")
	var covered: int = 0
	var stranded: int = 0
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var cell := Vector2i(x, y)
			if not game.board.is_buildable(cell):
				continue
			if PlacementPreview.covered_road_cells(game.board, cell, reach) == 0:
				stranded += 1
			else:
				covered += 1
	if err == "":
		err = _T.assert_gt(covered, 0, "some buildable ground puts road under the dew")
	if err == "":
		err = _T.assert_gt(stranded, 0,
			"and some of it is dead ground for a sundew too, which is what the cue is for")
	_T.free_ui(game)
	return err


## The one line for this plant that lives outside plant_catalog.gd: the match
## statement in Game._new_plant. Everything else can be right and a placed Sticky
## Sundew will still silently be a Corn Cobbler without it — same sprite lookup,
## same health bar, same refund, no error anywhere.
func test_the_catalogue_id_for_a_sundew_builds_a_sticky_sundew() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(500)
	game.bank.unlocked.append(PlantCatalog.SUNDEW)
	var cell: Vector2i = _grass(game)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.SUNDEW, cell), "",
		"an unlocked, paid-for sundew goes into the ground")
	if err == "":
		err = _T.assert_true(game.plant_at(cell) is StickySundew,
			"and it is a StickySundew — add `PlantCatalog.SUNDEW: return StickySundew.new()` to Game._new_plant")
	_T.free_ui(game)
	return err


# -- Two Sundews on one stretch of road (plant-tower-defense-3lu) -------------
#
# The slow does not stack, and must not: a stacking slow is a stun as soon as you
# can afford three, which deletes the Chomp Flower's whole reason to exist.
# Everything below leaves that rule alone and goes after the two things that were
# telling the player the opposite — a wash that composited darker where patches
# overlapped, and a preview that drew an encouraging ring over ground an existing
# patch already covered.


## Shoelace, absolute. The wash is checked by area because "the lens is not
## painted twice" is a claim about how much ground got covered, and a walk over
## the vertices alone cannot tell a crescent from a whole disc.
func _poly_area(poly: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		total += a.x * b.y - b.x * a.y
	return absf(total) * 0.5


## The rule this whole issue is careful NOT to change, pinned before anything
## that could change it. Two patches over one pest hold it at SLOW_FACTOR, and
## the arithmetic that says so is the same arithmetic the new preview cue is
## drawn from — so a future balance pass that makes a second patch worth
## something moves this test and that cue together, instead of leaving the cue
## warning about a purchase that has become worth making.
func test_a_second_patch_over_the_same_road_is_worth_exactly_nothing() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var cell: Vector2i = _grass(game)
	var first: StickySundew = _sundew_at(game, cell)
	var second: StickySundew = _sundew_at(game, cell)
	second.position += Vector2(Board.CELL * 0.5, 0.0)
	var pest: Pest = _pest_at(game, game.board.cell_to_world(cell))
	var crowd: Array[Pest] = [pest]
	var base: float = pest.speed
	var stacked: float = StickySundew.slowed_speed(StickySundew.slowed_speed(base))
	var err: String = _T.assert_true(first.covers(pest) and second.covers(pest),
		"the pest is standing in both patches at once")
	if err == "":
		first.apply_patch(crowd)
		second.apply_patch(crowd)
		err = _T.assert_eq(StickySundew.slow_sources(pest), 2, "both patches are claiming it")
	if err == "":
		err = _T.assert_float_eq(pest.speed, StickySundew.slowed_speed(base), 0.001,
			"and it still walks at one patch's speed — 0.55 of base, never 0.30")
	if err == "":
		# Without this, the assert above would also pass on a build where
		# SLOW_FACTOR is 1.0 and both numbers are just the pest's own speed.
		err = _T.assert_gt(absf(pest.speed - stacked), 1.0,
			"a stacking slow would be a visibly different number, so that claim bites")
	# The same fact as arithmetic. crossing_time_multiplier() had no caller
	# outside a test before this: the plant computed the number that explains its
	# own price and then never showed it to anything.
	if err == "":
		err = _T.assert_float_eq(StickySundew.added_crossing_time_multiplier(0),
			StickySundew.crossing_time_multiplier(), 0.001,
			"the first patch on a stretch of road is worth the plant's whole multiplier")
	if err == "":
		err = _T.assert_gt(StickySundew.added_crossing_time_multiplier(0), 1.0,
			"which is strictly more time under every gun covering that road")
	for already: int in range(1, 4):
		if err != "":
			break
		err = _T.assert_float_eq(StickySundew.added_crossing_time_multiplier(already), 1.0,
			0.0001, "patch %d over that same road adds nothing at all" % [already + 1])
	_T.free_ui(game)
	return err


## Half one, and the primary fix: the wash used to draw the opposite of the test
## above. Every patch filled its own disc at PATCH_COLOR's alpha 0.10, and alpha
## blending is not idempotent — two of them over the same grass composite to an
## effective 0.19, so the lens where two patches met came out nearly twice as
## strong as either patch alone. Asserted as geometry, because "it looks about
## right" is exactly the check that let it ship: no patch may paint one square
## pixel of ground an earlier patch already owns.
func test_two_overlapping_patches_wash_the_ground_they_share_exactly_once() -> String:
	var whole: Array[PackedVector2Array] = StickySundew.wash_polygons(PackedVector2Array())
	var err: String = _T.assert_eq(whole.size(), 1, "a patch with no neighbours fills one shape")
	if err == "":
		err = _T.assert_eq(whole[0].size(), StickySundew.WASH_SEGMENTS,
			"and that shape is its whole disc")
	if err != "":
		return err
	var full_area: float = _poly_area(whole[0])
	err = _T.assert_gt(full_area, 0.0, "with real area in it to give away")
	if err == "":
		# Geometry2D hands an outer boundary back wound one way and a hole the
		# other. The disc has to be wound like an outer, or _draw_wash's hole
		# guard would throw away the very shapes it exists to keep.
		err = _T.assert_false(Geometry2D.is_polygon_clockwise(StickySundew.patch_outline()),
			"the patch outline is wound the way Geometry2D returns an outer boundary")
	if err != "":
		return err
	var apart := PackedVector2Array([Vector2(StickySundew.SAP_RADIUS * 2.0 + 1.0, 0.0)])
	var kept: Array[PackedVector2Array] = StickySundew.wash_polygons(apart)
	err = _T.assert_eq(kept.size(), 1, "a patch that overlaps nothing keeps its whole disc")
	if err == "":
		err = _T.assert_float_eq(_poly_area(kept[0]), full_area, 1.0,
			"exactly the disc, not a re-cut copy of it")
	if err != "":
		return err
	# One cell apart: how two Sundews flanking the same lane actually sit.
	var offset := Vector2(Board.CELL, 0.0)
	var share: Array[PackedVector2Array] = StickySundew.wash_polygons(
		PackedVector2Array([offset]))
	err = _T.assert_gt(share.size(), 0, "the later patch still has ground of its own to wash")
	if err != "":
		return err
	var painted: float = 0.0
	for part: PackedVector2Array in share:
		painted += _poly_area(part)
		for point: Vector2 in part:
			err = _T.assert_gte(point.distance_to(offset), StickySundew.SAP_RADIUS - 0.5,
				"no corner of the later patch's wash reaches inside the earlier patch's disc")
			if err != "":
				return err
	err = _T.assert_gt(painted, 0.0, "and it painted that ground rather than giving up entirely")
	if err == "":
		err = _T.assert_gt(full_area, painted + 1000.0,
			"while handing back a real share of the disc — the lens is painted once, not twice")
	if err == "":
		# Dropped on the identical spot, the second patch paints nothing at all,
		# which is the honest picture of what the second thirty seeds bought.
		var on_top: Array[PackedVector2Array] = StickySundew.wash_polygons(
			PackedVector2Array([Vector2.ZERO]))
		var left: float = 0.0
		for part: PackedVector2Array in on_top:
			left += _poly_area(part)
		err = _T.assert_float_eq(left, 0.0, 1.0, "a patch on the very same spot washes nothing")
	return err


## Half two, on the real board. (2, 0) and (2, 2) sit on opposite sides of the
## row-1 lane and cover the identical three road cells — sixty seeds for one
## stretch of sticky road, which is the purchase this cue exists to talk a player
## out of. (3, 2) is one cell along and picks up (4, 1) as well, so it is a second
## patch worth buying and must draw nothing.
func test_the_preview_warns_about_ground_an_existing_patch_already_covers() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var reach: float = PlantCatalog.reach(PlantCatalog.SUNDEW)
	var here := Vector2i(2, 0)
	var doubled := Vector2i(2, 2)
	var extended := Vector2i(3, 2)
	var mine: Array[Vector2i] = PlacementPreview.covered_road_cell_list(game.board, here, reach)
	var same: Array[Vector2i] = PlacementPreview.covered_road_cell_list(game.board, doubled, reach)
	var more: Array[Vector2i] = PlacementPreview.covered_road_cell_list(game.board, extended, reach)
	# The board geometry the rest of this rides on, stated rather than assumed: a
	# PATH_CORNERS change that moved these cells should fail here, loudly, rather
	# than quietly turning every assertion below into a test of nothing.
	var err: String = _T.assert_eq(mine.size(), 3, "a patch on (2, 0) covers three road cells")
	if err == "":
		err = _T.assert_eq(same.size(), 3, "and one on (2, 2) covers three of them too")
	if err == "":
		err = _T.assert_gt(more.size(), 0, "while (3, 2) covers road as well")
	if err != "":
		_T.free_ui(game)
		return err
	for road: Vector2i in same:
		err = _T.assert_true(mine.has(road), "(2, 2) covers %s, and so does (2, 0)" % road)
		if err != "":
			_T.free_ui(game)
			return err
	var new_road: int = 0
	for road: Vector2i in more:
		if not mine.has(road):
			new_road += 1
	err = _T.assert_gt(new_road, 0, "but (3, 2) reaches road that (2, 0) never touches")
	var preview: PlacementPreview = _preview(game)
	if err == "":
		err = _T.assert_true(preview != null, "the game built a placement preview")
	if err != "":
		_T.free_ui(game)
		return err
	preview.placeable = true
	preview.at_risk = false
	preview.reach = reach
	preview.position = game.board.cell_to_world(doubled)
	# Before and after, so a cue that simply fired on everything could not pass.
	err = _T.assert_false(preview.shows_redundant_coverage(),
		"with nothing planted yet, (2, 2) is ground worth covering")
	if err == "":
		err = _T.assert_eq(preview.covering_patch_count(), 0, "and no patch is covering it")
	if err != "":
		_T.free_ui(game)
		return err
	var patch: StickySundew = _sundew_at(game, here)
	err = _T.assert_true(patch != null, "a real Sundew is standing on (2, 0)")
	if err == "":
		err = _T.assert_true(preview.previewing_non_stacking_patch(),
			"the preview works out it is previewing a patch from the reach alone")
	if err == "":
		err = _T.assert_eq(preview.covering_patch_count(), 1,
			"and finds the one patch already covering every road cell (2, 2) would")
	if err == "":
		err = _T.assert_true(preview.shows_redundant_coverage(),
			"so hovering (2, 2) is marked as a second patch over the same road")
	if err == "":
		err = _T.assert_false(preview.shows_dead_zone(),
			"and is not ALSO called dead ground — it does cover road, just somebody else's")
	if err == "":
		# Told rather than inferred: the one-line call-site change has to agree
		# with the fallback, not quietly switch the cue off.
		preview.plant_id = PlantCatalog.SUNDEW
		err = _T.assert_true(preview.shows_redundant_coverage(),
			"and says the same thing when the caller names the plant outright")
	if err == "":
		preview.plant_id = PlantCatalog.CORN
		preview.reach = PlantCatalog.reach(PlantCatalog.CORN)
		err = _T.assert_false(preview.shows_redundant_coverage(),
			"a Corn Cobbler on that cell is not redundant — guns stack, dew does not")
	if err == "":
		preview.plant_id = PlantCatalog.SUNDEW
		preview.reach = reach
		preview.position = game.board.cell_to_world(extended)
		err = _T.assert_eq(preview.covering_patch_count(), 0,
			"one cell along, the existing patch no longer covers everything")
	if err == "":
		err = _T.assert_false(preview.shows_redundant_coverage(),
			"so a patch that extends the sticky road is not warned about")
	if err == "":
		err = _T.assert_false(preview.shows_dead_zone(), "and is not dead ground either")
	_T.free_ui(game)
	return err


## Precedence, all four rules over one board. An illegal cell gets exactly one
## refusal; dead ground keeps the cue cycle 8 gave it; and the two marks are
## mutually exclusive by construction — opposite sides of "does it cover any road
## at all" — rather than by an `elif` somebody can delete.
func test_the_redundancy_mark_never_lands_on_top_of_another_cue() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var reach: float = PlantCatalog.reach(PlantCatalog.SUNDEW)
	var preview: PlacementPreview = _preview(game)
	var err: String = _T.assert_true(preview != null, "the game built a placement preview")
	if err != "":
		_T.free_ui(game)
		return err
	var patch: StickySundew = _sundew_at(game, Vector2i(2, 0))
	preview.plant_id = PlantCatalog.SUNDEW
	preview.reach = reach
	preview.at_risk = false
	# Rule 1 over rule 4: the cell really is redundant, and the refusal still wins.
	preview.position = game.board.cell_to_world(Vector2i(2, 2))
	preview.placeable = true
	err = _T.assert_true(patch != null and preview.shows_redundant_coverage(),
		"(2, 2) is redundant ground while a patch stands on (2, 0)")
	if err == "":
		preview.placeable = false
		err = _T.assert_false(preview.shows_redundant_coverage(),
			"but an illegal hover draws only the refusal, never both cues")
	if err == "":
		err = _T.assert_eq(preview.covering_patch_count(), 1,
			"the geometry is unchanged — legality is what suppressed the mark")
	# Rule 3 over rule 4: dead ground covers no road at all, so there is no
	# covered road for an existing patch to already own.
	var dead := Vector2i(13, 0)
	if err == "":
		preview.placeable = true
		preview.position = game.board.cell_to_world(dead)
		err = _T.assert_eq(PlacementPreview.covered_road_cells(game.board, dead, reach), 0,
			"(13, 0) puts no road at all under a Sundew's dew")
	if err == "":
		err = _T.assert_true(preview.shows_dead_zone(), "so it is still marked dead ground")
	if err == "":
		err = _T.assert_false(preview.shows_redundant_coverage(),
			"and never also marked redundant — no cell can wear both marks")
	# And the cue cycle 8 shipped is untouched for the plant it was built for.
	if err == "":
		preview.plant_id = PlantCatalog.CORN
		preview.reach = PlantCatalog.reach(PlantCatalog.CORN)
		err = _T.assert_true(preview.shows_dead_zone(),
			"a Corn Cobbler on (13, 0) is dead ground exactly as before")
	if err == "":
		err = _T.assert_false(preview.shows_redundant_coverage(),
			"with no second mark added on top of it")
	_T.free_ui(game)
	return err
