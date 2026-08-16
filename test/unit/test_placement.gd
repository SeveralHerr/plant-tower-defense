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
