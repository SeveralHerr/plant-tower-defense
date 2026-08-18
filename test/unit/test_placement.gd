extends RefCounted

## Placement, against a real Game rather than a stub — the refusal strings are
## what the HUD prints and what the devtools `place_plant` verb returns, so they
## are part of the interface.

const GAME_SCENE := "res://game/game.tscn"

var _T

## Where this script's RunConfig writes go instead of the player's own save.
## The reasoning is written out once, in test_combat.gd's setup(); the short
## version is that hosting `game.tscn` at all can reach `RunConfig._save()`
## through the game's own code, on a condition no reader can evaluate.
## `tools/save_persist_check.py` requires this of any test script that can.
const SUITE_SAVE_PATH := "user://test_placement_suite.save"
var _suite_stashed_save_path: String = ""


func setup() -> void:
	_suite_stashed_save_path = RunConfig.save_path
	RunConfig.save_path = SUITE_SAVE_PATH


func teardown() -> void:
	if _suite_stashed_save_path != "":
		RunConfig.save_path = _suite_stashed_save_path
	DirAccess.remove_absolute(SUITE_SAVE_PATH)


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


func test_a_headless_reveal_names_the_plant_it_actually_unlocked() -> String:
	## GardenTheme.animations_enabled() reads false for this whole suite, so
	## Game._on_plant_unlocked takes its instant branch and never touches the
	## flourish below — this pins that the instant path still lands on the
	## right banner, the same text the animated path ends on too.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_false(GardenTheme.animations_enabled(),
		"this test is only meaningful headless, where the flourish never runs")
	if err == "":
		game.bank.set_seed(99)
		game.bank.add_seeds(500)
		var got: StringName = game.bank.buy_packet()
		err = _T.assert_true(got != &"", "the packet held a plant")
	if err == "":
		var got: StringName = game.bank.unlocked[game.bank.unlocked.size() - 1]
		err = _T.assert_eq(game.hud._message_label.text,
			"The packet held a %s!" % PlantCatalog.display_name(got),
			"the banner named the plant the packet actually held, with no beat in between")
	_T.free_ui(game)
	return err


## Game._open_packet is the flourish itself, called directly (bypassing the
## animations_enabled() gate _on_plant_unlocked puts in front of it) since
## nothing headless ever takes that branch through the signal. What is
## assertable without a screen: it lands on the real pick, and it does so
## after actually waiting — not by short-circuiting the steps it claims to run.
func test_the_packet_flourish_lands_on_the_real_pick_after_flashing_candidates() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var locked: Array[StringName] = game.bank.locked_plants()
	var err: String = _T.assert_gt(locked.size(), 1,
		"more than one candidate is locked, so there is something else to flash")
	if err == "":
		var id: StringName = locked[0]
		# Mirrors what buy_packet() itself already did by the time it emits
		# plant_unlocked: the pick is unlocked before anyone is told about it.
		game.bank.unlocked.append(id)
		game._opening_tier = &"rare"
		var started: int = Time.get_ticks_msec()
		await game._open_packet(id)
		var elapsed_ms: int = Time.get_ticks_msec() - started
		err = _T.assert_gte(elapsed_ms,
			int(Game.PACKET_OPEN_STEP_SECONDS * Game.PACKET_OPEN_STEPS * 1000) - 20,
			"the flourish actually waited through its own steps (%dms), not just its final one" % elapsed_ms)
		if err == "":
			err = _T.assert_eq(game.hud._message_label.text,
				"The packet held a %s!" % PlantCatalog.display_name(id),
				"and landed on the real pick, not whatever it was flashing")
	_T.free_ui(game)
	return err


## The fallback the header promises: a packet with nothing else left in its
## pool still has PACKET_OPEN_STEPS to fill, and every one of them has to show
## something rather than an empty line.
func test_the_packet_flourish_falls_back_to_the_real_pick_with_an_empty_pool() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	# Unlock everything else so packet_pool(_opening_tier) comes back empty.
	for id: StringName in PlantCatalog.ids():
		if not game.bank.unlocked.has(id):
			game.bank.unlocked.append(id)
	var pool: Array[StringName] = game.bank.packet_pool(&"rare")
	var err: String = _T.assert_eq(pool.size(), 0, "nothing else is left to flash")
	if err == "":
		var id: StringName = PlantCatalog.CORN
		game._opening_tier = &"rare"
		await game._open_packet(id)
		err = _T.assert_eq(game.hud._message_label.text,
			"The packet held a %s!" % PlantCatalog.display_name(id),
			"an empty pool still lands on the real pick instead of erroring or going blank")
	_T.free_ui(game)
	return err


func test_uprooting_frees_the_cell_and_returns_some_seeds() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(100)
	var cell: Vector2i = _grass(game)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "", "planted")
	if err == "":
		var seeds_before: int = game.bank.seeds
		err = _T.assert_eq(game.commit_uproot(), "", "uprooting the selected plant succeeds")
		if err == "":
			err = _T.assert_gt(game.bank.seeds, seeds_before, "some seeds came back")
		if err == "":
			err = _T.assert_true(game.plant_at(cell) == null, "the cell is free again")
	_T.free_ui(game)
	return err


func test_a_plant_eaten_down_to_nothing_still_frees_the_node_headless() -> String:
	## _on_plant_destroyed used to end in a bare queue_free() too. It now goes
	## through the same Plant.play_exit_and_free() uproot does, so this pins the
	## other of the two silent-vanish call sites: destroyed.emit() still lands
	## while the plant is fully alive (take_damage checks is_destroyed() first,
	## not after), and the cell is freed and the node queued the same frame.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(100)
	var cell: Vector2i = _grass(game)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "", "planted")
	if err == "":
		var plant: Plant = game.plant_at(cell)
		plant.take_damage(Plant.MAX_HEALTH)
		err = _T.assert_true(game.plant_at(cell) == null, "the cell is free again")
		if err == "":
			err = _T.assert_true(is_instance_valid(plant) and plant.is_queued_for_deletion(),
				"queue_free() still ran immediately -- headless never queues the exit tween")
	_T.free_ui(game)
	return err


func test_uprooting_plays_its_own_cue_and_still_frees_the_node_headless() -> String:
	## commit_uproot() used to end in a bare queue_free() with no Sfx.play()
	## call anywhere in the function. It now routes through
	## Plant.play_exit_and_free(), which is gated on
	## GardenTheme.animations_enabled() the same way _build_visuals()'s pop-in
	## is -- always false headless, so this must still queue_free() on the
	## spot rather than waiting on a Tween nobody headless will ever pump.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(100)
	var cell: Vector2i = _grass(game)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "", "planted")
	if err == "":
		var plant: Plant = game.plant_at(cell)
		err = _T.assert_true(Sfx.should_play(Sfx.PLANT_UPROOTED, false, false),
			"a cue is registered for a deliberate uproot")
		if err == "":
			err = _T.assert_eq(game.commit_uproot(), "", "uprooted")
		if err == "":
			err = _T.assert_true(is_instance_valid(plant) and plant.is_queued_for_deletion(),
				"queue_free() still ran immediately -- headless never queues the exit tween")
	_T.free_ui(game)
	return err


## The button path, not the mutator underneath it. `commit_uproot` above stays
## deliberately unguarded; everything a player can click goes through this.
func test_one_uproot_click_only_arms_and_a_second_commits() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(100)
	var cell: Vector2i = _grass(game)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "", "planted")
	if err == "":
		var seeds_before: int = game.bank.seeds
		err = _T.assert_eq(game.arm_uproot(), "confirm needed", "the first click refuses")
		if err == "":
			err = _T.assert_true(game.plant_at(cell) != null, "the plant is still in the ground")
		if err == "":
			err = _T.assert_eq(game.bank.seeds, seeds_before, "and nothing was refunded yet")
		if err == "":
			err = _T.assert_true(game.uproot_armed(), "but the button is armed")
		if err == "":
			err = _T.assert_eq(game.arm_uproot(), "", "the second click commits")
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
		err = _T.assert_eq(game.arm_uproot(), "confirm needed", "armed")
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
		err = _T.assert_eq(game.arm_uproot(), "confirm needed", "the next click re-arms")
	if err == "":
		err = _T.assert_true(game.plant_at(cell) != null, "still in the ground")
	_T.free_ui(game)
	return err


## The armed prompt is the only line in the game with a clock running behind it,
## and until cycle 69 it could be made to arrive after its own window shut.
##
## `show_message` defers an incoming line behind one of EQUAL priority that has
## more than `MESSAGE_MIN_READABLE` left (game/hud.gd:1431). Three call sites emit
## `MESSAGE_IMPORTANT`, and the longest-lived of them is the packet reveal at five
## seconds (game/game.gd:1464) — so a reveal landing first held the prompt for up
## to 5.0 - 1.2 = 3.8s of a 4.0s window. The ring lit on the plant the whole time;
## the sentence saying what to do with it did not.
##
## Measured that way rather than argued: this test was written against the old
## priority and failed reading the reveal's text, which is what turned a design
## question into a defect.
func test_an_armed_prompt_outranks_a_line_that_is_merely_important() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(100)
	var cell: Vector2i = _grass(game)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "", "planted")
	var label: Label = game.hud.get_node_or_null("Root/TopBar/MessageLabel") as Label
	if err == "":
		err = _T.assert_true(label != null, "the message row is where the HUD put it")
	if err == "":
		# Drain first. Planting posts its own line, so without this the queue count
		# below reads 2 and the test fails describing the setup rather than the
		# collision -- which is what the first run of it did.
		game.hud._message_left = 0.0
		game.hud._message_queue.clear()
		game.hud._advance_message_queue()
		# A real reveal, at the real duration, straight from _reveal_plant_unlock.
		game.hud.show_message(Hud.packet_message("Chomp Flower"), 5.0, Hud.MESSAGE_IMPORTANT)
		err = _T.assert_eq(game.arm_uproot(), "confirm needed", "the uproot arms")
	if err == "":
		err = _T.assert_true(label.text.contains("it will not grow back"),
			("the prompt goes up the instant the window opens, not when the row "
				+ "happens to be free -- got %s") % label.text)
	if err == "":
		# Displaced, not discarded: the reveal is a real beat and still owes the
		# player its remaining time once the decision is over.
		err = _T.assert_eq(game.hud.pending_messages(), 1,
			"and the reveal it cut short is waiting, not dropped")
	if err == "":
		game.hud._process(Game.UPROOT_CONFIRM_SECONDS + 0.1)
		err = _T.assert_true(label.text.contains("Chomp Flower"),
			"which it gets back when the window shuts -- got %s" % label.text)
	_T.free_ui(game)
	return err


func test_selecting_another_plant_cancels_a_pending_uproot() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(200)
	var first: Vector2i = _grass(game)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, first), "", "first planted")
	if err == "":
		err = _T.assert_eq(game.arm_uproot(), "confirm needed", "armed on the first")
	if err == "":
		var second: Vector2i = _grass(game)
		err = _T.assert_true(second != first, "there is a second free cell")
		if err == "":
			err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, second), "", "second planted")
		if err == "":
			# place_plant auto-selects, so this is the real "clicked elsewhere" path.
			err = _T.assert_false(game.uproot_armed(), "the arming did not follow the selection")
		if err == "":
			err = _T.assert_eq(game.arm_uproot(), "confirm needed",
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


## The fan's SECOND channel, which the width test above does not touch.
##
## `_draw_muzzle_fan` draws the spread arc only when there is more than one kernel
## (`game/corn_cobbler.gd:165-169`), so level 1 is a lone pip and every level above
## it is pips-plus-arc. That is a difference of kind rather than of size, and it is
## what makes two cobs tell apart at a glance rather than by comparing widths —
## measured in cycle 70 on the live board, where a level 1 and a level 3 sitting
## two cells apart read as "one dot" and "a bow of dots".
##
## Asserted across every level rather than at the boundary: the rule is `iff`, and
## a rule stated at one end is half a rule. If LEVELS grows a fourth entry with one
## kernel, this fails and should.
##
## It asserts `spread_arc_span`, which is the function `_draw_muzzle_fan` actually
## reads. The first draft asserted `kernel_angle_offsets` instead and a mutation to
## the draw site's own `if` SURVIVED it — the test was a restatement of a function
## nothing about the arc depended on. That survivor is why `spread_arc_span` exists
## and why the draw site now has no branch of its own.
func test_only_a_single_kernel_level_draws_no_spread_arc() -> String:
	var err: String = _T.assert_gt(CornCobbler.LEVELS.size(), 1,
		"there is a ladder to have a shape at all")
	for lvl: int in range(1, CornCobbler.LEVELS.size() + 1):
		if err != "":
			return err
		var kernels: int = int(CornCobbler.LEVELS[lvl - 1]["kernels"])
		var span: float = CornCobbler.spread_arc_span(lvl)
		err = _T.assert_eq(span > 0.0, kernels > 1,
			"level %d draws an arc exactly when it fires more than one kernel" % lvl)
		if err != "" or kernels < 2:
			continue
		# And the arc spans the shot, not a decorative constant: its two ends are
		# the outermost kernels, so the drawn width IS the spread the cob fires
		# through. A fan that grew on its own schedule would be a badge.
		err = _T.assert_float_eq(span,
			deg_to_rad(float(CornCobbler.LEVELS[lvl - 1]["spread_degrees"])), 0.001,
			"level %d's arc spans its own spread" % lvl)
	return err


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
## route rather than against a fixture: of 94 buildable cells, 11 cover no road
## at a Corn Cobbler's reach and 36 cover none at a Chomp Flower's. If a future
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
	# Derived, not recorded (plant-tower-defense-m9u2): every in-bounds cell is
	# either road or buildable, so this is arithmetic and holds for ANY road. It was
	# the literal 94 until the road was reshaped, at which point it happened to stay
	# 94 — the new route has the same cell count — and would have gone on reading as
	# a verified number while verifying nothing about the new shape.
	var road_cells: int = game.board.road_cells().size()
	err = _T.assert_eq(buildable, Board.COLS * Board.ROWS - road_cells,
		("every in-bounds cell is road or buildable: %d + %d should be %d")
			% [buildable, road_cells, Board.COLS * Board.ROWS])
	if err == "":
		# Vacuity guards, ahead of the exact counts: a walk that found no ground
		# at all, or a coverage function answering zero everywhere, would
		# otherwise be indistinguishable from a board with nothing wrong on it.
		err = _T.assert_gt(corn_covered_total, 0, "and some of them do cover road")
	if err == "":
		err = _T.assert_gt(dead_corn, 0, "and some of them cover none at all")
	if err == "":
		# Both counts were re-derived when the road grew its climb
		# (plant-tower-defense-84x0), and they moved in OPPOSITE directions, which
		# is the interesting part rather than an inconvenience:
		#
		#   corn  15 -> 11   the new route folds back on itself, so a 176 px ring
		#                    reaches road from more of the board
		#   chomp 34 -> 36   the same folding opens two larger clearings the 74 px
		#                    grab radius cannot reach out of
		#
		# So the reshape made the board friendlier to the long reach and harsher to
		# the short one. The relation asserted below is unchanged and now holds by a
		# wider margin, which is the claim that actually matters.
		err = _T.assert_eq(dead_corn, 11, "11 cells are dead ground for a Corn Cobbler")
	if err == "":
		err = _T.assert_eq(dead_chomp, 36, "and 36 are dead ground for a Chomp Flower")
	if err == "":
		err = _T.assert_gt(dead_chomp, dead_corn,
			"the shorter reach strands strictly more of the board")
	_T.free_ui(game)
	return err


## Dead ground is a property of the plant, not of the cell — which is the whole
## reason the cue cannot be baked into the board. (1, 3) is legal and empty, and
## six road cells sit inside a Corn Cobbler's reach of it; a Chomp Flower
## standing on the same square can touch none of them.
##
## The cell moved one column west when the road grew its climb
## (plant-tower-defense-84x0): the new route runs up column 2, which puts road at
## (2, 4) directly under the old (2, 3) — well inside a Chomp's grab radius, so
## that square stopped splitting the two reaches at all. (1, 3) covers the same
## six cells for a cob, so the sentence above is unchanged rather than re-fitted.
func test_a_cell_can_be_dead_ground_for_a_chomp_and_good_ground_for_a_corn() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var split := Vector2i(1, 3)
	var corn_reach: float = PlantCatalog.reach(PlantCatalog.CORN)
	var chomp_reach: float = PlantCatalog.reach(PlantCatalog.CHOMP)
	var err: String = _T.assert_true(game.board.is_buildable(split),
		"(1, 3) is somewhere a plant may actually stand")
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
## The move tip is shown once, ever, and the bare warning every time after.
##
## It costs 185 px of the message row's headroom, so paying it on every uproot
## forever was the wrong trade — and a hint that appears once is more likely to be
## read than one that has become wallpaper. Both halves matter and fail
## differently: never showing it makes a finished feature undiscoverable, and
## showing it twice means the flag is not being written.
##
## The warning itself is in BOTH forms, which is the part a refactor would break
## quietly — the sentence standing between a player and an irreversible act must
## not be the thing that gets shortened to make room for the tip.
func test_the_move_tip_is_shown_once_and_the_warning_every_time() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	# The suite's save is redirected in setup(), so this writes nothing real; clear
	# the flag so the test does not depend on whether an earlier test armed one.
	RunConfig.earned_milestones.erase(RunConfig.HINT_MOVE_PREVIEW)
	var here := Vector2i(1, 3)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, here), "", "a cob goes in")
	if err == "":
		game.selected_placed = game.plant_at(here)
		err = _T.assert_eq(game.arm_uproot(), "confirm needed", "and the uproot arms")
	var label: Label = game.hud.get_node_or_null("Root/TopBar/MessageLabel") as Label
	if err == "":
		err = _T.assert_true(label != null, "the message row is where the HUD put it")
	if err == "":
		err = _T.assert_true(label.text.contains("Hover to compare"),
			"the first arm ever carries the move tip -- got %s" % label.text)
	if err == "":
		# ON THE FIRST ARM TOO, which is the case a mutation caught this test missing.
		# Asserting the warning only on the second arm proves nothing: with_tip is
		# false there, so the warning is present however the tip is composed. The
		# failure this guards is the tip REPLACING the warning rather than joining
		# it, and that only ever happens on the arm where the tip appears.
		err = _T.assert_true(label.text.contains("it will not grow back"),
			("and the warning ALONGSIDE it, not instead of it -- got %s") % label.text)
	if err == "":
		err = _T.assert_true(RunConfig.has_milestone(RunConfig.HINT_MOVE_PREVIEW),
			"and writes the flag down, or it is not a one-shot at all")
	# Second arm, same session: warning only.
	#
	# The row has to be DRAINED first. show_message queues, and the armed prompt is
	# MESSAGE_IMPORTANT with a four-second life — so without this the second read
	# returns the FIRST message still on screen and the test fails describing a
	# stale row rather than a wrong one. That is the whole of cycle 48's precedence
	# rule, met again from the test side.
	if err == "":
		game.hud._message_left = 0.0
		game.hud._advance_message_queue()
		game._disarm_uproot()
		game.selected_placed = game.plant_at(here)
		err = _T.assert_eq(game.arm_uproot(), "confirm needed", "arming a second time")
	if err == "":
		err = _T.assert_false(label.text.contains("Hover to compare"),
			"drops the tip -- got %s" % label.text)
	if err == "":
		err = _T.assert_true(label.text.contains("it will not grow back"),
			("but NEVER the warning. That sentence stands between the player and an "
				+ "irreversible act -- got %s") % label.text)
	RunConfig.earned_milestones.erase(RunConfig.HINT_MOVE_PREVIEW)
	_T.free_ui(game)
	return err


## The invariant the move preview leans on: an open uproot window is exactly a
## non-null `_uproot_armed`, on every exit path there is.
##
## _update_preview used to check `_uproot_armed if _uproot_left > 0.0` and no
## mutation could kill the second half, because _disarm_uproot() nulls the first
## whenever the window closes. Rather than keep a condition that cannot disagree —
## the dead-code-with-a-confident-comment shape this repo has paid for before — the
## guard was dropped and the invariant written down here instead.
##
## Timer expiry is driven directly rather than waited for: a test that sleeps four
## seconds is testing the clock.
func test_the_uproot_window_leaves_nothing_armed_behind_it() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var here := Vector2i(1, 3)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, here), "", "a cob goes in")
	if err == "":
		game.selected_placed = game.plant_at(here)
		err = _T.assert_eq(game.arm_uproot(), "confirm needed", "and the uproot arms")
	if err == "":
		err = _T.assert_true(game._uproot_armed != null, "so something is armed")
	# Expiry: one tick longer than the whole window.
	if err == "":
		game._tick_uproot_confirm(Game.UPROOT_CONFIRM_SECONDS + 1.0)
		err = _T.assert_true(game._uproot_armed == null,
			"and letting the window expire leaves nothing armed")
	if err == "":
		# settle-read-check: ok - not an ambient read. arm_uproot() above sets this to
		# UPROOT_CONFIRM_SECONDS and the tick driven directly overhead subtracts more
		# than the whole window, so the value is one this test wrote and then spent.
		# Asserted separately from `_uproot_armed` on purpose: _disarm_uproot clears
		# the reference AND the clock, and a version that cleared only the reference
		# would leave a dead timer counting down over the next selection.
		err = _T.assert_true(game._uproot_left <= 0.0, "nor any time on the clock")
	# The cob is still standing — an expired window CANCELS, it does not uproot —
	# so the other exit path can be driven on the same plant.
	if err == "":
		err = _T.assert_true(game.plant_at(here) != null,
			"the expired window cancelled rather than uprooting")
	if err == "":
		game.selected_placed = game.plant_at(here)
		err = _T.assert_eq(game.arm_uproot(), "confirm needed", "and it arms again")
	if err == "":
		err = _T.assert_eq(game.arm_uproot(), "", "the second press commits")
	if err == "":
		err = _T.assert_true(game._uproot_armed == null, "and leaves nothing armed either")
	_T.free_ui(game)
	return err


## While an uproot is armed the player is weighing a MOVE, so the hover stops
## describing the shop's selection and starts describing the plant being moved.
##
## Three states, because the middle one is useless if the window cannot close:
## before arming the preview is the shop plant, during it is the moved plant, and
## after it lapses it is the shop plant again. Cycle 46 nearly filed a defect
## against a correctly-lapsed uproot window, which is why the third state is here
## rather than assumed.
##
## The subtle half is `covered_now`. The plant being moved has to be left OUT of
## what counts as already covered, because it is about to stop covering it —
## otherwise every cell it currently holds reads as "already defended" and the
## preview reports the destination as buying almost nothing, worst exactly where
## the move matters most.
func test_an_armed_uproot_turns_the_hover_into_a_move_preview() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var here := Vector2i(1, 3)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, here), "",
		"a cob to move goes in at %s" % here)
	if err != "":
		_T.free_ui(game)
		return err
	var cob: Plant = game.plant_at(here)
	var preview: PlacementPreview = game.get_node_or_null("Entities/PlacementPreview")
	if err == "":
		err = _T.assert_true(preview != null, "the preview node is where the game put it")
	# A shop selection whose reach differs from the cob's, or the assertions below
	# cannot tell the two subjects apart.
	if err == "":
		game.selected_plant = PlantCatalog.CHOMP
		err = _T.assert_true(not is_equal_approx(
			PlantCatalog.reach(PlantCatalog.CHOMP), PlantCatalog.reach(PlantCatalog.CORN)),
			"the two plants have different reaches, so the preview's subject is readable")
	var elsewhere := Vector2i(11, 5)
	if err == "":
		game._update_preview(elsewhere, true)
		err = _T.assert_true(is_equal_approx(preview.reach, PlantCatalog.reach(PlantCatalog.CHOMP)),
			"unarmed, the hover describes the SHOP's selection")
	if err == "":
		game.selected_placed = cob
		err = _T.assert_eq(game.arm_uproot(), "confirm needed", "the uproot arms")
	if err == "":
		game._update_preview(elsewhere, true)
		err = _T.assert_true(is_equal_approx(preview.reach, PlantCatalog.reach(PlantCatalog.CORN)),
			"armed, it describes the plant being MOVED instead")
	if err == "":
		err = _T.assert_eq(preview.plant_id, PlantCatalog.CORN,
			"and says so explicitly rather than leaving it to be inferred from the radius")
	# The exclusion, which is the half that would fail silently.
	if err == "":
		var held: Array[Vector2i] = PlacementPreview.covered_road_cell_list(
			game.board, here, Game.engagement_reach(PlantCatalog.CORN))
		err = _T.assert_gt(held.size(), 0, "the cob holds road, or the check below is empty")
		if err == "":
			var still_claimed: Array[Vector2i] = []
			for cell: Vector2i in held:
				if preview.covered_now.has(cell):
					still_claimed.append(cell)
			err = _T.assert_true(still_claimed.is_empty(),
				("the moved plant's own cells are NOT counted as already covered -- it is "
					+ "about to stop covering them. Still claimed: %s") % [still_claimed])
	if err == "":
		game._disarm_uproot()
		game._update_preview(elsewhere, true)
		err = _T.assert_true(is_equal_approx(preview.reach, PlantCatalog.reach(PlantCatalog.CHOMP)),
			"and once the window closes the hover goes back to the shop's selection")
	_T.free_ui(game)
	return err


## "What does the garden lose if this one goes?" — the selected half of the same
## question the hover dots answer for a purchase.
##
## Both directions matter and they fail differently. Claiming a cell that another
## plant also holds overstates what an uproot would cost; dropping a cell nothing
## else holds hides the only reason to keep the plant where it is.
##
## The rings are on a node of their own rather than on the SelectionMarker, and the
## reason is checkable rather than stylistic: play_entrance() tweens the marker's
## scale from 0.55, and these marks sit whole cells from the plant's origin, so
## they would slide on every selection. See SoleCoverMarks' header.
func test_a_selected_plant_marks_only_the_road_nothing_else_covers() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var here := Vector2i(1, 3)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, here), "",
		"the first cob goes in at %s" % here)
	if err != "":
		_T.free_ui(game)
		return err
	var alone: Plant = game.plant_at(here)
	var reaches: Array[Vector2i] = PlacementPreview.covered_road_cell_list(
		game.board, here, Game.engagement_reach(PlantCatalog.CORN))
	if err == "":
		err = _T.assert_gt(reaches.size(), 1,
			"a cob on %s reaches more than one road cell, so there is something to mark" % here)
	if err == "":
		err = _T.assert_eq(game.sole_cover_cells(alone).size(), reaches.size(),
			"the only plant in the garden solely holds everything it reaches")
	# A second cob overlapping it takes cells out of the first one's answer without
	# the first plant changing at all.
	if err == "":
		var beside := Vector2i(0, 5)
		err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, beside), "",
			"a second cob goes in at %s" % beside)
		if err == "":
			var shared: int = 0
			for cell: Vector2i in PlacementPreview.covered_road_cell_list(
					game.board, beside, Game.engagement_reach(PlantCatalog.CORN)):
				if reaches.has(cell):
					shared += 1
			err = _T.assert_gt(shared, 0,
				"the two cobs overlap, or this test measures nothing")
			if err == "":
				err = _T.assert_eq(game.sole_cover_cells(alone).size(),
					reaches.size() - shared,
					"and the first cob now solely holds only what the second cannot reach")
	# Selection drives visibility, and deselecting EMPTIES rather than merely hides:
	# a plant reselected later must not flash the previous garden's rings.
	if err == "":
		var marks: SoleCoverMarks = alone.sole_cover_marks()
		err = _T.assert_true(marks != null, "the plant built its marks node")
		if err == "":
			alone.set_selected(true)
			err = _T.assert_true(marks.visible, "selecting shows them")
		if err == "":
			var some := PackedVector2Array([Vector2(10.0, 10.0)])
			err = _T.assert_true(marks.set_points(some), "new points repaint")
		if err == "":
			err = _T.assert_false(marks.set_points(PackedVector2Array([Vector2(10.0, 10.0)])),
				("the same points do NOT repaint -- this is driven from _refresh(), which "
					+ "fires on every seed payout"))
		if err == "":
			alone.set_selected(false)
			err = _T.assert_false(marks.visible, "deselecting hides them")
		if err == "":
			err = _T.assert_eq(marks.points.size(), 0, "and empties them")
	# The empty state draws a ring on the plant instead of drawing nothing, so
	# "no cells depend on this" never looks like "the cue is broken" — the
	# confusion cycle 55 spent ten minutes on with the hover dots. That only works
	# if the ring is legible as a separate statement rather than as a fatter
	# bracket, which is a geometric claim and therefore checkable.
	if err == "":
		err = _T.assert_gt(SoleCoverMarks.ALONE_RADIUS, SelectionMarker.HALF,
			("the holds-nothing ring (%.0f) sits outside the selection brackets (%.0f), "
				+ "or the two read as one mark")
				% [SoleCoverMarks.ALONE_RADIUS, SelectionMarker.HALF])
	if err == "":
		err = _T.assert_gt(Game.engagement_reach(PlantCatalog.CORN),
			SoleCoverMarks.ALONE_RADIUS,
			"and far inside the plant's own range ring, so it is not a second reach")
	# Arming an uproot escalates the rings with the brackets: the same cells, with
	# the tense changed from "these depend on you" to "these go bare if you
	# confirm". Both halves of the toggle, because a warning that cannot be undone
	# is worse than one that never fired.
	if err == "":
		var marks: SoleCoverMarks = alone.sole_cover_marks()
		alone.set_uproot_armed(true)
		err = _T.assert_true(marks.warning, "arming an uproot warns the rings")
		if err == "":
			err = _T.assert_eq(SoleCoverMarks.WARNING_COLOR, SelectionMarker.WARNING_COLOR,
				("and in the SAME red as the brackets -- two reds on one plant would read "
					+ "as two different warnings"))
		if err == "":
			err = _T.assert_gt(SoleCoverMarks.WARNING_RING_WIDTH, SoleCoverMarks.RING_WIDTH,
				("and thicker, so the escalation survives the colour being thrown away -- "
					+ "the two-channel rule this project holds everywhere else"))
		# The asymmetry, which is the part most likely to be "tidied" away later: a
		# plant holding nothing alone costs the road nothing to uproot, so its ring
		# must NOT redden. That is the one case where uprooting is free, and it is
		# the case the ring was added to announce.
		if err == "":
			marks.set_points(PackedVector2Array([Vector2(64.0, 64.0)]))
			err = _T.assert_eq(marks.ring_color(), SoleCoverMarks.WARNING_COLOR,
				"armed with cells to lose, the rings are red")
		if err == "":
			marks.set_points(PackedVector2Array())
			err = _T.assert_eq(marks.ring_color(), SoleCoverMarks.MARK_COLOR,
				("armed with NOTHING to lose, they are not -- reddening the holds-nothing "
					+ "ring would warn about the one uproot that costs the road nothing"))
		if err == "":
			err = _T.assert_true(is_equal_approx(marks.ring_width(), SoleCoverMarks.RING_WIDTH),
				"and not thickened either, for the same reason")
		if err == "":
			alone.set_uproot_armed(false)
			err = _T.assert_false(marks.warning, "and letting it lapse takes the warning off")
		# Directly, because the header claims idempotence and that is a claim about
		# calling it twice — which the route through set_uproot_armed never does.
		if err == "":
			marks.set_warning(true)
			err = _T.assert_true(marks.warning, "set_warning arms it on its own")
		if err == "":
			marks.set_warning(true)
			err = _T.assert_true(marks.warning, "and arming an armed one is a no-op, not a toggle")
		if err == "":
			marks.set_warning(false)
			err = _T.assert_false(marks.warning, "and it disarms")
	_T.free_ui(game)
	return err


## The dots say "this is the road this purchase newly defends", so the two ways of
## being wrong are opposite and both matter: marking ground that is already covered
## sells a plant that buys nothing, and failing to mark bare ground hides the only
## thing the purchase is actually for.
##
## The empty answer is deliberately NOT a warning. A cob engages one pest at a time,
## so a second cob over cells another already reaches is worth real money — measured
## in test_combat as the difference between a five-cob garden that lets a pest
## through and a seven-cob garden that does not. "No dots" means "you are buying
## depth rather than reach", which is a purchase, not a mistake.
func test_the_preview_dots_only_the_road_a_purchase_would_newly_defend() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var preview := PlacementPreview.new()
	preview.board = game.board
	preview.reach = PlantCatalog.reach(PlantCatalog.CORN)
	var here := Vector2i(1, 3)
	preview.position = game.board.cell_to_world(here)
	# Stated rather than assumed, the same way the sibling test below does it: a
	# PATH_CORNERS change that moved this cell should fail here loudly instead of
	# turning every assertion into a test of an empty list.
	var reaches: Array[Vector2i] = PlacementPreview.covered_road_cell_list(
		game.board, here, preview.reach)
	var err: String = _T.assert_gt(reaches.size(), 1,
		"a cob on %s reaches more than one road cell, so there is something to dot" % here)

	if err == "":
		preview.covered_now = {}
		err = _T.assert_eq(preview.new_cover_cells().size(), reaches.size(),
			"over an empty garden every cell it reaches is newly defended")
	if err == "":
		# The "buying depth, not reach" case: everything it reaches is already held.
		var all_held: Dictionary = {}
		for cell: Vector2i in reaches:
			all_held[cell] = true
		preview.covered_now = all_held
		err = _T.assert_eq(preview.new_cover_cells().size(), 0,
			("with every cell already covered there is nothing NEW to mark -- and that "
				+ "is not a warning, it is a cob bought for depth"))
	if err == "":
		# And the partial case, which is the one a player actually hovers into.
		var some_held: Dictionary = {}
		some_held[reaches[0]] = true
		preview.covered_now = some_held
		var left: Array[Vector2i] = preview.new_cover_cells()
		err = _T.assert_eq(left.size(), reaches.size() - 1,
			"holding one of the %d cells leaves the rest marked" % reaches.size())
		if err == "":
			err = _T.assert_false(left.has(reaches[0]),
				"and the held cell %s is not among them" % reaches[0])
	if err == "":
		# An illegal cell answers empty however much road it would reach, the same
		# rule shows_dead_zone() obeys. _draw() returns before the dots on a blocked
		# cell, so a predicate that still listed cells there could only mislead.
		preview.covered_now = {}
		preview.placeable = false
		err = _T.assert_eq(preview.new_cover_cells().size(), 0,
			"a cell the click already refuses marks nothing, however much it reaches")
		preview.placeable = true
	preview.free()
	_T.free_ui(game)
	return err


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
	err = _T.assert_false(preview.shows_redundant_patch_coverage(),
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
		err = _T.assert_true(preview.shows_redundant_patch_coverage(),
			"so hovering (2, 2) is marked as a second patch over the same road")
	if err == "":
		err = _T.assert_false(preview.shows_dead_zone(),
			"and is not ALSO called dead ground — it does cover road, just somebody else's")
	if err == "":
		# Told rather than inferred: the one-line call-site change has to agree
		# with the fallback, not quietly switch the cue off.
		preview.plant_id = PlantCatalog.SUNDEW
		err = _T.assert_true(preview.shows_redundant_patch_coverage(),
			"and says the same thing when the caller names the plant outright")
	if err == "":
		preview.plant_id = PlantCatalog.CORN
		preview.reach = PlantCatalog.reach(PlantCatalog.CORN)
		err = _T.assert_false(preview.shows_redundant_patch_coverage(),
			"a Corn Cobbler on that cell is not redundant — guns stack, dew does not")
	if err == "":
		preview.plant_id = PlantCatalog.SUNDEW
		preview.reach = reach
		preview.position = game.board.cell_to_world(extended)
		err = _T.assert_eq(preview.covering_patch_count(), 0,
			"one cell along, the existing patch no longer covers everything")
	if err == "":
		err = _T.assert_false(preview.shows_redundant_patch_coverage(),
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
	err = _T.assert_true(patch != null and preview.shows_redundant_patch_coverage(),
		"(2, 2) is redundant ground while a patch stands on (2, 0)")
	if err == "":
		preview.placeable = false
		err = _T.assert_false(preview.shows_redundant_patch_coverage(),
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
		err = _T.assert_false(preview.shows_redundant_patch_coverage(),
			"and never also marked redundant — no cell can wear both marks")
	# And the cue cycle 8 shipped is untouched for the plant it was built for.
	if err == "":
		preview.plant_id = PlantCatalog.CORN
		preview.reach = PlantCatalog.reach(PlantCatalog.CORN)
		err = _T.assert_true(preview.shows_dead_zone(),
			"a Corn Cobbler on (13, 0) is dead ground exactly as before")
	if err == "":
		err = _T.assert_false(preview.shows_redundant_patch_coverage(),
			"with no second mark added on top of it")
	_T.free_ui(game)
	return err


# -- What a Sundew redraw walks (plant-tower-defense-fp5) ---------------------
#
# Every patch used to find its neighbours by walking its own siblings — and a
# Sundew's siblings under Entities are every PEST on the board (Game.spawn_pest
# parents them there) as well as every other plant. So the cost of drawing one
# patch scaled with the number of bugs, and `_refresh_droplets` queues a redraw
# every time the bead size moves, which is driven by how many bugs are stuck in
# the patch. The scan is now a class-level list maintained on enter/exit.
#
# None of what follows may change what is drawn: the tests above pin the wash
# geometry, the refcounted slow and the paint order, and they are untouched.


## The patches the class-level list holds for ONE board. `live_patches()` is
## static, and the runner keeps every test's scene in the same process, so a
## global count would be a claim about the whole suite rather than about this
## test's board.
func _patches_on(game: Game) -> Array[StickySundew]:
	var out: Array[StickySundew] = []
	var entities: Node = game.get_node("Entities")
	for patch: StickySundew in StickySundew.live_patches():
		if patch.get_parent() == entities:
			out.append(patch)
	return out


## Sundews that are actually children of the entities layer, found the slow way —
## the denominator the list is checked against.
func _sundew_children(game: Game) -> int:
	var n: int = 0
	for child: Node in game.get_node("Entities").get_children():
		if child is StickySundew:
			n += 1
	return n


## The cost claim, structurally rather than by timing: what a patch walks to work
## out its share of the wash is bounded by the number of PATCHES, and a board
## filling up with pests does not move that number by one.
##
## Asserted as a count and as an unchanged answer, because the failure it guards
## is invisible either way — the old scan drew exactly the same picture, it just
## paid one pass over every bug on the board to do it, sixty times a second, in
## the frames where there are the most bugs to pass over.
func test_a_patch_walks_only_patches_however_many_pests_are_on_the_board() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var entities: Node = game.get_node("Entities")
	var cell: Vector2i = _grass(game)
	var here: Vector2 = game.board.cell_to_world(cell)
	var first: StickySundew = _sundew_at(game, cell)
	var second: StickySundew = _sundew_at(game, cell)
	second.position += Vector2(Board.CELL, 0.0)
	var quiet_offsets: PackedVector2Array = second.shared_ground_offsets()
	var quiet_children: int = entities.get_child_count()
	var err: String = _T.assert_eq(_patches_on(game).size(), 2,
		"an empty board's list holds the two patches")
	if err == "":
		err = _T.assert_eq(quiet_offsets.size(), 1,
			"and the later patch is dividing its ground with the earlier one")
	if err != "":
		_T.free_ui(game)
		return err
	var swarm: int = 20
	for i: int in range(swarm):
		_pest_at(game, here + Vector2(float(i) * 3.0, 0.0))
	# The premise of the whole issue, stated rather than assumed: if pests ever
	# stopped being siblings of the plants, every assertion below would still pass
	# while testing nothing at all.
	var pest_siblings: int = 0
	for child: Node in entities.get_children():
		if child is Pest:
			pest_siblings += 1
	err = _T.assert_gte(pest_siblings, swarm,
		"the pests really are siblings of the patches — the sibling scan walked every one")
	if err == "":
		err = _T.assert_gte(entities.get_child_count(), quiet_children + swarm,
			"so the thing the old scan measured itself against grew by the whole swarm")
	if err == "":
		err = _T.assert_eq(_patches_on(game).size(), 2,
			"while the list a redraw walks still holds exactly the two patches")
	if err == "":
		err = _T.assert_eq(_patches_on(game).size(), _sundew_children(game),
			"which is one entry per Sundew on the board and nothing else")
	if err == "":
		err = _T.assert_gt(entities.get_child_count(), _patches_on(game).size() * 5,
			"and is now a small fraction of what walking the siblings would cost")
	if err == "":
		err = _T.assert_eq(second.sibling_patches().size(), 1,
			"the patch beside it is still the only neighbour it can see")
	if err == "":
		err = _T.assert_eq(first.sibling_patches().size(), 1,
			"and the same both ways round")
	if err == "":
		# Same answer, not just a cheaper one.
		var busy_offsets: PackedVector2Array = second.shared_ground_offsets()
		err = _T.assert_eq(busy_offsets.size(), quiet_offsets.size(),
			"a board full of bugs divides the ground exactly as an empty one did")
		if err == "":
			for i: int in range(busy_offsets.size()):
				err = _T.assert_float_eq(busy_offsets[i].distance_to(quiet_offsets[i]), 0.0, 0.001,
					"offset %d is the one the empty board produced" % i)
				if err != "":
					break
	_T.free_ui(game)
	return err


## The sibling set itself, at nought, one and two other patches. A cache that is
## merely cheap and slightly wrong would repaint a lens twice or leave a crescent
## unwashed, which is the bug the union was built to kill.
func test_a_patch_sees_every_other_patch_and_only_the_other_patches() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var cell: Vector2i = _grass(game)
	var first: StickySundew = _sundew_at(game, cell)
	var err: String = _T.assert_eq(first.sibling_patches().size(), 0,
		"the only patch on the board has no neighbours")
	if err == "":
		err = _T.assert_eq(_patches_on(game).size(), 1, "and the list agrees there is one patch")
	if err == "":
		err = _T.assert_eq(first.shared_ground_offsets().size(), 0,
			"so it washes its whole disc")
	var second: StickySundew = null
	if err == "":
		second = _sundew_at(game, cell)
		second.position += Vector2(Board.CELL, 0.0)
		err = _T.assert_eq(first.sibling_patches().size(), 1, "a second patch is one neighbour")
	if err == "":
		err = _T.assert_true(first.sibling_patches()[0] == second, "and it is the one just planted")
	if err == "":
		err = _T.assert_true(second.sibling_patches()[0] == first, "seen from the other side too")
	var third: StickySundew = null
	if err == "":
		third = _sundew_at(game, cell)
		third.position += Vector2(0.0, Board.CELL)
		err = _T.assert_eq(first.sibling_patches().size(), 2, "a third patch is two neighbours")
	if err == "":
		var seen: Array[StickySundew] = first.sibling_patches()
		err = _T.assert_true(seen.has(second) and seen.has(third),
			"and they are the other two patches, not this one twice")
	if err == "":
		err = _T.assert_false(first.sibling_patches().has(first),
			"no patch is ever its own neighbour — it would clip its own disc away")
	if err == "":
		err = _T.assert_eq(_patches_on(game).size(), 3, "the list holds all three")
	if err == "":
		err = _T.assert_eq(_patches_on(game).size(), _sundew_children(game),
			"which is exactly the Sundews standing on the board")
	_T.free_ui(game)
	return err


## The way a cache like this goes wrong: a patch is eaten or uprooted, the node is
## freed, and the list keeps handing it out. Reading `position` off it is a crash
## rather than a wrong picture, and the survivor would go on painting around a
## disc that is not there — the unwashed crescent `rewash_neighbourhood` exists to
## prevent, made permanent.
func test_a_freed_patch_leaves_no_ghost_in_the_patch_list() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var cell: Vector2i = _grass(game)
	var first: StickySundew = _sundew_at(game, cell)
	var second: StickySundew = _sundew_at(game, cell)
	second.position += Vector2(Board.CELL * 0.5, 0.0)
	# Before, so this cannot pass on a list that was empty the whole time.
	var err: String = _T.assert_eq(second.sibling_patches().size(), 1,
		"the survivor can see the patch that is about to go")
	if err == "":
		err = _T.assert_eq(second.shared_ground_offsets().size(), 1,
			"and is handing it the ground they share")
	if err == "":
		err = _T.assert_eq(_patches_on(game).size(), 2, "two patches are on the list")
	if err != "":
		_T.free_ui(game)
		return err
	first.free()
	err = _T.assert_eq(_patches_on(game).size(), 1, "freeing one leaves one on the list")
	if err == "":
		err = _T.assert_true(_patches_on(game)[0] == second, "and it is the survivor")
	if err == "":
		err = _T.assert_eq(second.sibling_patches().size(), 0,
			"which now sees no neighbour at all, ghost or otherwise")
	if err == "":
		err = _T.assert_eq(second.shared_ground_offsets().size(), 0,
			"so it takes its whole disc back")
	if err == "":
		var alone: Array[PackedVector2Array] = StickySundew.wash_polygons(
			second.shared_ground_offsets())
		err = _T.assert_eq(alone.size(), 1, "and washes one shape")
		if err == "":
			err = _T.assert_eq(alone[0].size(), StickySundew.WASH_SEGMENTS,
				"that shape being the whole disc again")
	if err == "":
		err = _T.assert_eq(_sundew_children(game), 1,
			"the board really did lose a Sundew — the list is not just agreeing with itself")
	_T.free_ui(game)
	return err


## The picture is unchanged. The offsets a live patch hands `wash_polygons` are
## still its neighbours' real positions, and what comes back is still exactly what
## the pure function above produces for that arrangement — the function itself,
## and the test that pins its geometry, are untouched by this change.
func test_the_patch_list_draws_the_same_wash_the_sibling_scan_drew() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var cell: Vector2i = _grass(game)
	var first: StickySundew = _sundew_at(game, cell)
	var second: StickySundew = _sundew_at(game, cell)
	second.position += Vector2(Board.CELL, 0.0)
	# A crowd standing in both, because "unchanged" has to hold on the board state
	# the old scan was slowest on.
	for i: int in range(12):
		_pest_at(game, game.board.cell_to_world(cell) + Vector2(float(i) * 4.0, 0.0))
	var expected := PackedVector2Array([Vector2(-Board.CELL, 0.0)])
	var err: String = _T.assert_eq(first.shared_ground_offsets().size(), 0,
		"the earlier patch gives away no ground — it got there first")
	if err == "":
		var got: PackedVector2Array = second.shared_ground_offsets()
		err = _T.assert_eq(got.size(), 1, "the later one divides with exactly one neighbour")
		if err == "":
			err = _T.assert_float_eq(got[0].distance_to(expected[0]), 0.0, 0.001,
				"at the offset the two patches actually stand at")
	if err != "":
		_T.free_ui(game)
		return err
	var drawn: Array[PackedVector2Array] = StickySundew.wash_polygons(
		second.shared_ground_offsets())
	var reference: Array[PackedVector2Array] = StickySundew.wash_polygons(expected)
	err = _T.assert_eq(drawn.size(), reference.size(),
		"the live patch fills the same number of shapes as the pure model")
	if err == "":
		err = _T.assert_gt(drawn.size(), 0, "and there is a shape there to compare")
	for p: int in range(drawn.size()):
		if err != "":
			break
		err = _T.assert_eq(drawn[p].size(), reference[p].size(),
			"shape %d has the model's vertex count" % p)
		if err != "":
			break
		for v: int in range(drawn[p].size()):
			err = _T.assert_float_eq(drawn[p][v].distance_to(reference[p][v]), 0.0, 0.001,
				"shape %d vertex %d is where the model puts it" % [p, v])
			if err != "":
				break
	if err == "":
		# Vacuity guard: a wash that gave nothing away would also match a model
		# fed the same nothing, so pin that the disc really was carved.
		var painted: float = 0.0
		for part: PackedVector2Array in drawn:
			painted += _poly_area(part)
		var whole: float = _poly_area(StickySundew.patch_outline())
		err = _T.assert_gt(whole, painted + 1000.0,
			"and a real share of the disc was handed to the earlier patch")
		if err == "":
			err = _T.assert_gt(painted, 0.0, "while the later patch still washes ground of its own")
	_T.free_ui(game)
	return err


## Paint order. Which patch owns a lens is decided by `_wash_order` and by nothing
## else, so a cached list must not be able to change it — and the offsets have to
## come back in one settled order, because they are applied as a sequence of clips
## and a union assembled differently each frame is a union that flickers.
func test_the_patch_list_hands_the_wash_its_neighbours_in_paint_order() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var cell: Vector2i = _grass(game)
	var here: Vector2 = game.board.cell_to_world(cell)
	var a: StickySundew = _sundew_at(game, cell)
	var b: StickySundew = _sundew_at(game, cell)
	b.position = here + Vector2(Board.CELL, 0.0)
	# Planted third, and far enough away to share no ground with anything. On the
	# list, absent from the offsets: it is the distance test that excludes it, not
	# the list forgetting it exists.
	var far: StickySundew = _sundew_at(game, cell)
	far.position = here + Vector2(0.0, StickySundew.SAP_RADIUS * 4.0)
	var c: StickySundew = _sundew_at(game, cell)
	c.position = here + Vector2(0.0, Board.CELL)
	var err: String = _T.assert_eq(c.sibling_patches().size(), 3,
		"the newest patch can see all three of the others")
	if err == "":
		err = _T.assert_eq(far.sibling_patches().size(), 3,
			"and the distant one is on the list like everybody else")
	if err == "":
		err = _T.assert_gt(far.position.distance_to(c.position), StickySundew.SAP_RADIUS * 2.0,
			"but shares no ground with it")
	var offsets := PackedVector2Array()
	if err == "":
		offsets = c.shared_ground_offsets()
		err = _T.assert_eq(offsets.size(), 2,
			"so only the two overlapping patches claim ground from it")
	if err == "":
		err = _T.assert_float_eq(offsets[0].distance_to(a.position - c.position), 0.0, 0.001,
			"the oldest patch is clipped first")
	if err == "":
		err = _T.assert_float_eq(offsets[1].distance_to(b.position - c.position), 0.0, 0.001,
			"and the next oldest second")
	if err == "":
		# The order the offsets arrive in is the order of the ranks, not of
		# anything that can shift under the node — which is the property the
		# comment on `_wash_order` is about.
		var ranks: Array[StickySundew] = c.sibling_patches()
		for i: int in range(ranks.size() - 1):
			err = _T.assert_gt(ranks[i + 1]._wash_order, ranks[i]._wash_order,
				"neighbour %d is strictly older than neighbour %d" % [i, i + 1])
			if err != "":
				break
	if err == "":
		err = _T.assert_gt(c._wash_order, a._wash_order,
			"and every one of them is older than the patch reading them")
	if err == "":
		# The total order is a fact about the pair, so both sides have to agree on
		# it: whatever ground c gives to a, a must never give back to c.
		err = _T.assert_eq(a.shared_ground_offsets().size(), 0,
			"the first patch planted owes nobody any ground")
	if err == "":
		err = _T.assert_eq(b.shared_ground_offsets().size(), 1,
			"the second owes the first, and only the first")
	if err == "":
		err = _T.assert_eq(far.shared_ground_offsets().size(), 0,
			"and the distant patch washes its whole disc, sharing with nothing")
	_T.free_ui(game)
	return err


# -- A husk versus the click that would have planted (plant-tower-defense-0wg) -
#
# CompostMeter.COLLECT_RADIUS is 28, so a husk claims a 56 px sweep target on a
# 64 px cell — 87.5% of its width — and Game._click_at ran that sweep first and
# returned on any hit. A click on a cell the placement preview had just drawn
# green composted instead of planting, and the preview said nothing about it,
# because PlacementPreview does not know husks exist.
#
# The fix is precedence rather than a fifth preview state: **a click that would
# plant, plants — a husk only takes clicks that were never going to plant
# anything.** Game.would_plant_at() is that predicate, and the preview's own
# `placeable` flag now reads it, so green is a promise rather than a hint.
#
# The reason this does not make husks hard to harvest is measured rather than
# hoped for — see the margin test at the bottom of this block.


## A click at a point in board space, through the same handler the mouse reaches.
## Offset by the entities layer's own position rather than by a second copy of
## Hud.BAR_HEIGHT, so a top bar that changes height cannot quietly aim every one
## of these one row out and turn the block below into a test of nothing.
func _click_world(game: Game, at: Vector2) -> void:
	game._click_at(at + game._entities.position)


## `n` distinct buildable, empty cells. `_grass()` answers with the first one
## every time, which is the same cell twice for as long as nothing is planted.
func _free_grass(game: Game, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var cell := Vector2i(x, y)
			if game.board.is_buildable(cell) and game.plant_at(cell) == null:
				out.append(cell)
				if out.size() >= n:
					return out
	return out


## A click point inside the sweep radius of a husk dropped at `centre`, and still
## inside `centre`'s own cell. Deliberately off-centre: a click landing exactly on
## the husk would make the "is it really in range" guard trivially true, and that
## guard is the only thing standing between these tests and a set of placement
## assertions that pass because the husk was never a factor at all. Every caller
## asserts both properties rather than trusting this.
func _sweep_point(centre: Vector2) -> Vector2:
	return centre + Vector2(CompostMeter.COLLECT_RADIUS - 4.0, 0.0)


## The conflict itself, forced onto the board, then clicked twice.
##
## One cell, one husk, one click point. The first click plants, because the cell
## was legal, empty and paid for. The second sweeps, because the cell now holds a
## plant and there was nothing left to plant. Nothing about the click moved
## between them — precedence did all of the work, which is what makes this an
## assertion about the rule rather than about two different situations.
func test_a_husk_never_takes_a_click_that_would_have_planted() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var cells: Array[Vector2i] = _free_grass(game, 2)
	var err: String = _T.assert_eq(cells.size(), 2, "two free cells to work with")
	if err != "":
		_T.free_ui(game)
		return err
	# Burn the free starter somewhere else first, so the placement under test costs
	# real seeds and "did that click plant or did it compost" is visible in the
	# purse as well as on the board.
	game.place_plant(PlantCatalog.CORN, cells[0])
	game.bank.add_seeds(200)
	var cell: Vector2i = cells[1]
	var centre: Vector2 = game.board.cell_to_world(cell)
	var aim: Vector2 = _sweep_point(centre)
	var husk_value: int = 5
	game.compost.drop_husk(centre, husk_value)
	err = _T.assert_gte(CompostMeter.COLLECT_RADIUS, aim.distance_to(centre),
		"the click really is inside the husk's sweep radius — without this the rest proves nothing")
	if err == "":
		err = _T.assert_eq(game.board.world_to_cell(aim), cell, "and inside the cell it aims at")
	if err == "":
		err = _T.assert_eq(game.compost.husk_count(), 1, "with exactly one husk on the ground")
	if err == "":
		err = _T.assert_true(game.would_plant_at(cell),
			"and the preview would draw that cell green — legal, empty and paid for")
	if err != "":
		_T.free_ui(game)
		return err
	var seeds_before: int = game.bank.seeds
	_click_world(game, aim)
	err = _T.assert_true(game.plant_at(cell) != null, "so the click planted rather than composted")
	if err == "":
		err = _T.assert_eq(game.compost.husk_count(), 1,
			"and left the husk lying there for a click that is not planting")
	if err == "":
		err = _T.assert_eq(game.compost.total_collected, 0, "nothing was swept at all")
	if err == "":
		err = _T.assert_eq(game.bank.seeds, seeds_before - PlantCatalog.cost(PlantCatalog.CORN),
			"the purse paid for a plant rather than being paid for a husk")
	if err != "":
		_T.free_ui(game)
		return err
	# Same cell, same husk, same click point. The only thing that changed is that
	# something is growing there now, so the click has nothing to plant.
	err = _T.assert_false(game.would_plant_at(cell), "the cell has stopped being a placement")
	if err == "":
		seeds_before = game.bank.seeds
		_click_world(game, aim)
		err = _T.assert_eq(game.compost.husk_count(), 0, "so the identical click sweeps the husk")
	if err == "":
		err = _T.assert_eq(game.bank.seeds, seeds_before + husk_value, "and is paid for it")
	if err == "":
		err = _T.assert_eq(game.compost.total_collected, husk_value, "exactly once")
	if err == "":
		err = _T.assert_true(game.plant_at(cell) != null, "with the plant still standing there")
	_T.free_ui(game)
	return err


## Harvesting on the road — which is where every husk the game itself drops
## actually lands, so this is the harvest, not an edge case of it.
##
## Run with a full purse and a plant in hand on purpose: that is the exact
## configuration a "placement wins the click" rule stands accused of breaking, and
## the road is why it cannot. Nothing may ever be planted on a lane cell, so
## would_plant_at() is false there however rich the player is.
func test_a_husk_on_the_road_is_still_one_click_to_sweep() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(999)
	game.selected_plant = PlantCatalog.CORN
	var road: Vector2i = _road(game)
	var centre: Vector2 = game.board.cell_to_world(road)
	var aim: Vector2 = _sweep_point(centre)
	var husk_value: int = 7
	game.compost.drop_husk(centre, husk_value)
	var err: String = _T.assert_gte(CompostMeter.COLLECT_RADIUS, aim.distance_to(centre),
		"the click is inside the sweep radius")
	if err == "":
		err = _T.assert_eq(game.board.world_to_cell(aim), road, "and on the road cell it aims at")
	if err == "":
		err = _T.assert_true(game.bank.can_afford(PlantCatalog.CORN),
			"with seeds in hand and a plant selected — the case the new rule has to survive")
	if err == "":
		err = _T.assert_false(game.would_plant_at(road),
			"but no click on the lane ever plants, so sweeping is all it can mean")
	if err != "":
		_T.free_ui(game)
		return err
	var seeds_before: int = game.bank.seeds
	_click_world(game, aim)
	err = _T.assert_eq(game.compost.husk_count(), 0, "one click swept it")
	if err == "":
		err = _T.assert_eq(game.bank.seeds, seeds_before + husk_value, "and paid the seeds out")
	if err == "":
		err = _T.assert_eq(game.state()["plants"], 0, "with nothing planted on the lane")
	_T.free_ui(game)
	return err


## The other two ways a click on buildable ground fails to be a placement, both on
## grass, both still the husk's. Nothing selected, and nothing in the purse:
## between them and the occupied cell in the first test, that is every branch of
## would_plant_at() a player reaches by playing.
func test_a_husk_on_grass_is_swept_by_any_click_that_was_not_going_to_plant() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var cells: Array[Vector2i] = _free_grass(game, 3)
	var err: String = _T.assert_eq(cells.size(), 3, "three free cells to work with")
	if err != "":
		_T.free_ui(game)
		return err
	# Nothing in hand: PlantCatalog.has() is false for the empty id, so there is no
	# plant for the click to prefer and the husk gets it.
	var idle: Vector2i = cells[0]
	var idle_centre: Vector2 = game.board.cell_to_world(idle)
	var idle_aim: Vector2 = _sweep_point(idle_centre)
	game.compost.drop_husk(idle_centre, 3)
	game.selected_plant = &""
	err = _T.assert_gte(CompostMeter.COLLECT_RADIUS, idle_aim.distance_to(idle_centre),
		"the click is inside the sweep radius")
	if err == "":
		err = _T.assert_eq(game.board.world_to_cell(idle_aim), idle,
			"and inside the cell it aims at")
	if err == "":
		err = _T.assert_true(game.board.is_buildable(idle),
			"on ground a plant could perfectly well stand on")
	if err == "":
		err = _T.assert_false(game.would_plant_at(idle), "with nothing selected to put there")
	if err == "":
		var before: int = game.bank.seeds
		_click_world(game, idle_aim)
		err = _T.assert_eq(game.compost.husk_count(), 0, "so the husk takes the click")
		if err == "":
			err = _T.assert_eq(game.bank.seeds, before + 3, "and pays out")
		if err == "":
			err = _T.assert_true(game.plant_at(idle) == null, "leaving the cell empty")
	if err != "":
		_T.free_ui(game)
		return err
	# Broke. The cell is legal and empty and a plant is selected; the seeds are the
	# only thing missing, and that alone hands the click to the husk.
	game.place_plant(PlantCatalog.CORN, cells[1])
	game.selected_plant = PlantCatalog.CORN
	game.bank.seeds = 0
	var skint: Vector2i = cells[2]
	var skint_centre: Vector2 = game.board.cell_to_world(skint)
	var skint_aim: Vector2 = _sweep_point(skint_centre)
	game.compost.drop_husk(skint_centre, 4)
	err = _T.assert_false(game.bank.can_afford(PlantCatalog.CORN), "the purse is empty")
	if err == "":
		err = _T.assert_gte(CompostMeter.COLLECT_RADIUS, skint_aim.distance_to(skint_centre),
			"the click is inside the sweep radius")
	if err == "":
		err = _T.assert_eq(game.board.world_to_cell(skint_aim), skint,
			"and inside the cell it aims at")
	if err == "":
		err = _T.assert_true(game.board.is_buildable(skint), "which is buildable and empty")
	if err == "":
		err = _T.assert_false(game.would_plant_at(skint), "and still refuses the plant")
	if err == "":
		_click_world(game, skint_aim)
		err = _T.assert_eq(game.compost.husk_count(), 0, "so the husk takes that click too")
	if err == "":
		err = _T.assert_eq(game.bank.seeds, 4, "paying the seeds that buy the next plant")
	if err == "":
		err = _T.assert_true(game.plant_at(skint) == null, "with the cell still empty")
	_T.free_ui(game)
	return err


## Why none of the three tests above can happen by itself, as a number.
##
## The conflict had to be forced onto the board because the game cannot produce
## it: pests only ever walk Board.route(), which is one point per road cell centre
## bracketed by two off-board tails, so a husk's centre is always at least
## CELL / 2 = 32 px from the nearest buildable cell and the 28 px sweep never
## reaches it. That is four pixels of clearance, which is exactly why this is a
## gate and not a remark — a COLLECT_RADIUS of 33, or a pest that can be knocked
## off the lane, turns a latent bug into a live one, and PlacementPreview would
## then need the husk cue this issue deliberately did not add.
func test_no_husk_the_game_can_drop_lands_within_a_click_of_buildable_ground() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	# The inputs first: the margin is a subtraction, and a build where either of
	# these had drifted would still hand back a plausible-looking number.
	var err: String = _T.assert_float_eq(CompostMeter.COLLECT_RADIUS, 28.0, 0.001,
		"a husk sweeps at 28 px")
	if err == "":
		err = _T.assert_eq(Board.CELL, 64,
			"on a 64 px cell — a 56 px target, 87.5% of the cell's width")
	if err == "":
		err = _T.assert_gt(float(Board.CELL) * 0.5, CompostMeter.COLLECT_RADIUS,
			"and the sweep is narrower than half a cell, which is the whole reason this holds")
	if err != "":
		_T.free_ui(game)
		return err
	# husk_click_margin() answers 0.0 for a board it could not walk, so an empty
	# route or an empty field fails here rather than sailing through.
	var margin: float = PlacementPreview.husk_click_margin(game.board)
	err = _T.assert_gt(margin, 0.0, "no husk can be swept from ground a plant may stand on")
	if err == "":
		err = _T.assert_float_eq(margin, float(Board.CELL) * 0.5 - CompostMeter.COLLECT_RADIUS,
			0.001, "the clearance is exactly half a cell less the sweep radius — 4 px")
	if err != "":
		_T.free_ui(game)
		return err
	# The same claim as behaviour rather than as a measurement: walk the route and
	# check that no point a click could sweep a husk from is standing on buildable
	# ground. The rim is where the sweep disc reaches furthest and no 64 px cell
	# fits inside a 56 px disc, so rim plus centre is the whole question.
	var route: PackedVector2Array = game.board.route()
	err = _T.assert_gt(route.size(), 2, "the route has segments to walk")
	if err != "":
		_T.free_ui(game)
		return err
	var checked: int = 0
	for i: int in range(route.size() - 1):
		if err != "":
			break
		for s: int in range(5):
			if err != "":
				break
			var husk: Vector2 = route[i].lerp(route[i + 1], float(s) / 4.0)
			for step: int in range(17):
				var probe: Vector2 = husk
				if step > 0:
					var angle: float = TAU * float(step - 1) / 16.0
					probe += Vector2.from_angle(angle) * CompostMeter.COLLECT_RADIUS
				checked += 1
				err = _T.assert_false(game.board.is_buildable(game.board.world_to_cell(probe)),
					"a click at %s sweeps a husk at %s while standing on buildable %s"
						% [probe, husk, game.board.world_to_cell(probe)])
				if err != "":
					break
	if err == "":
		err = _T.assert_gt(checked, 500,
			"and that walk really covered the lane — %d sample clicks" % checked)
	_T.free_ui(game)
	return err


## The other half of the rule: the brackets and the click now read the same
## predicate, so green is a promise rather than a hint.
##
## Walked over every cell of the board rather than over one happy cell, because
## agreeing about a single legal empty square is precisely what the two separate
## expressions did before they became one call.
func test_the_green_brackets_promise_exactly_what_a_click_will_do() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var green: int = 0
	var blocked: int = 0
	var err: String = ""
	for y: int in range(Board.ROWS):
		if err != "":
			break
		for x: int in range(Board.COLS):
			var cell := Vector2i(x, y)
			var free: bool = game.board.is_buildable(cell) and game.plant_at(cell) == null
			game._update_preview(cell, free)
			var promised: bool = game.would_plant_at(cell)
			err = _T.assert_eq(game._preview.placeable, promised,
				"the preview over %s draws exactly what a click there would do" % cell)
			if err != "":
				break
			if promised:
				green += 1
			else:
				blocked += 1
	if err == "":
		err = _T.assert_gt(green, 0, "some of the board reads as a placement")
	if err == "":
		err = _T.assert_gt(blocked, 0, "and some of it does not — the road, at the very least")
	if err == "":
		err = _T.assert_eq(green + blocked, Board.ROWS * Board.COLS, "every cell was walked")
	if err != "":
		_T.free_ui(game)
		return err
	# And the promise is kept, both ways round.
	var cell: Vector2i = _grass(game)
	err = _T.assert_true(game.would_plant_at(cell), "the first free cell promises a placement")
	if err == "":
		err = _T.assert_eq(game.place_plant(game.selected_plant, cell), "",
			"and place_plant agrees, with no refusal at all")
	if err == "":
		err = _T.assert_false(game.would_plant_at(cell),
			"the same cell stops promising the moment something grows on it")
	if err == "":
		err = _T.assert_false(game.would_plant_at(_road(game)), "and the road never promised")
	if err == "":
		game.bank.seeds = 0
		var still_green: int = 0
		for y: int in range(Board.ROWS):
			for x: int in range(Board.COLS):
				if game.would_plant_at(Vector2i(x, y)):
					still_green += 1
		err = _T.assert_eq(still_green, 0,
			"and an empty purse turns the whole board off, which is what the click does too")
	_T.free_ui(game)
	return err


# -- The title lawn and the notebook vs the catalogue (plant-tower-defense-6mv) -
#
# Both screens named their plants outright and both were written when the
# catalogue was shorter, so the Sticky Sundew was absent from the first thing a
# new player sees and neither tier-2 plant appeared anywhere in the only screen
# that explains anything. Everything below is asserted against PlantCatalog.ids()
# rather than against a count, so the next plant fails these tests instead of
# quietly going unmentioned.


## The decorations, in the order the lawn planted them. Read off the nodes rather
## than off PLANT_X, so this measures what got built.
func _lawn_sprites(title: Control) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for child: Node in title.get_children():
		var sprite := child as Sprite2D
		if sprite != null and sprite.has_meta("plant"):
			out.append(sprite)
	return out


func test_the_title_lawn_shows_every_plant_in_the_catalogue() -> String:
	var title := await _T.instantiate_ui("res://game/title.tscn", Vector2i(1152, 648)) as TitleScreen
	var err: String = _T.assert_true(title != null, "the title scene resolves headlessly")
	if err != "":
		return err
	var ids: Array[StringName] = PlantCatalog.ids()
	var sprites: Array[Sprite2D] = _lawn_sprites(title)
	# Vacuity guards ahead of everything: an empty catalogue, or a lawn that built
	# no sprites at all, would otherwise satisfy every "each id is present" loop
	# below without asserting a thing.
	err = _T.assert_gt(ids.size(), 0, "the catalogue has plants to put on the lawn")
	if err == "":
		err = _T.assert_gt(sprites.size(), 0, "and the lawn actually built decorations")
	if err == "":
		err = _T.assert_gte(TitleScreen.PLANT_X.size(), ids.size(),
			"there is a hand-placed slot for every plant — add an x to TitleScreen.PLANT_X, clear of the button column and measured in INK, not canvases (see PLANT_X's seventh-slot note)")
	if err == "":
		err = _T.assert_eq(sprites.size(), ids.size(),
			"the lawn stands one of each catalogue plant, counted from the catalogue rather than written out")
	if err != "":
		_T.free_ui(title)
		return err
	var standing: Array[StringName] = []
	for sprite: Sprite2D in sprites:
		standing.append(StringName(sprite.get_meta("plant")))
	for id: StringName in ids:
		err = _T.assert_true(standing.has(id),
			"%s is on the title lawn — the list is derived from PlantCatalog.ids(), got %s" % [id, standing])
		if err != "":
			break
		# And it is that plant's own art, not a second copy of a neighbour's: the
		# old lawn drew the Corn Cobbler twice and no Sundew at all.
		var shown: Sprite2D = sprites[standing.find(id)]
		err = _T.assert_eq(shown.texture.resource_path, PlantCatalog.texture_path(id),
			"%s is drawn with the sprite the catalogue points at" % id)
		if err != "":
			break
	if err == "":
		# PLANT_ART_WIDTH is a written-down number that plant_span() reasons about
		# without loading anything. This is what stops it drifting off the art.
		err = _T.assert_float_eq(float(sprites[0].texture.get_width()), TitleScreen.PLANT_ART_WIDTH, 0.001,
			"TitleScreen.PLANT_ART_WIDTH is the real board sprite width")
	_T.free_ui(title)
	return err


## Two constraints the file states and nothing else checks. The buttons are
## Controls and the lawn is Sprite2Ds, so no UI tool compares them — a decoration
## parked under the Start button is a sunflower drawn through a label with
## nothing to say so. The horizon is the other half: the scenery starts at
## TitleBackdrop.HORIZON and no interactive row may dip into it.
func test_the_title_lawn_clears_the_button_column_and_the_horizon() -> String:
	var title := await _T.instantiate_ui("res://game/title.tscn", Vector2i(1152, 648)) as TitleScreen
	var sprites: Array[Sprite2D] = _lawn_sprites(title)
	var column: Vector2 = title.button_column()
	var err: String = _T.assert_gt(sprites.size(), 0, "there are decorations to check")
	if err == "":
		err = _T.assert_gt(column.y, column.x, "and the buttons occupy a real column")
	if err != "":
		_T.free_ui(title)
		return err
	for i: int in sprites.size():
		var sprite: Sprite2D = sprites[i]
		var id: StringName = StringName(sprite.get_meta("plant"))
		# The span the constant claims and the span the built node actually covers
		# have to be the same thing before either is worth checking against a button.
		var half: float = float(sprite.texture.get_width()) * sprite.scale.x / 2.0
		var drawn := Vector2(sprite.position.x - half, sprite.position.x + half)
		var span: Vector2 = TitleScreen.plant_span(i)
		err = _T.assert_float_eq(drawn.x, span.x, 0.001, "%s covers the x span plant_span(%d) claims" % [id, i])
		if err == "":
			err = _T.assert_float_eq(drawn.y, span.y, 0.001, "and ends where it claims")
		if err == "":
			err = _T.assert_true(drawn.y < column.x or drawn.x > column.y,
				"%s at x %s stays out of the button column %s" % [id, drawn, column])
		if err != "":
			break
	if err != "":
		_T.free_ui(title)
		return err
	var horizon: float = title.size.y * TitleBackdrop.HORIZON
	err = _T.assert_gt(horizon, 0.0, "the backdrop has a horizon to clear")
	# Read off TitleScreen.MENU_BUTTON_NAMES, not spelled out here: this list
	# carried its own copy of the column and a fourth button was added without it.
	for node_name: String in TitleScreen.MENU_BUTTON_NAMES + ["HintLabel"]:
		if err != "":
			break
		var node: Control = title.get_node(node_name) as Control
		err = _T.assert_gte(horizon, node.position.y + node.size.y,
			"%s ends above the horizon at %.0f" % [node_name, horizon])
	_T.free_ui(title)
	return err


## The gap this issue was filed for: a grep for `sunflower` or `sundew` across
## notebook_screen.gd returned nothing, so the two plants unlocked latest and
## understood least appeared nowhere in the only screen that explains anything.
## Keyed on PlantCatalog.ids() rather than on a page count, so the fifth plant
## fails here with the fix in the message.
func test_the_notebook_has_a_page_for_every_plant_in_the_catalogue() -> String:
	var ids: Array[StringName] = PlantCatalog.ids()
	var err: String = _T.assert_gt(ids.size(), 0, "the catalogue has plants to explain")
	if err == "":
		err = _T.assert_gt(NotebookScreen.PAGES.size(), 0, "and the notebook has pages")
	if err != "":
		return err
	var claimed: Array[int] = []
	for id: StringName in ids:
		var page: int = NotebookScreen.page_for_plant(id)
		err = _T.assert_gte(page, 0,
			"%s has a notebook page — add one to NotebookScreen.PAGES, kind KIND_PLANT if it was never drawn on paper" % id)
		if err != "":
			return err
		err = _T.assert_false(claimed.has(page), "%s has a page of its own, not one already spoken for" % id)
		if err != "":
			return err
		claimed.append(page)
		var entry: Dictionary = NotebookScreen.PAGES[page]
		err = _T.assert_eq(String(entry["caption"]), PlantCatalog.display_name(id),
			"%s's page is captioned with the name the shop uses" % id)
		if err == "":
			err = _T.assert_eq(String(entry["sprite"]), PlantCatalog.texture_path(id),
				"%s's page shows the sprite the catalogue points at" % id)
		if err != "":
			return err
	err = _T.assert_eq(claimed.size(), ids.size(), "one page per plant was actually walked")
	if err != "":
		return err
	# The other direction: a `plant` key naming something the catalogue has never
	# heard of is a page about a plant that does not exist, and page_for_plant()
	# would never find it.
	var named: int = 0
	for entry: Dictionary in NotebookScreen.PAGES:
		var id: StringName = StringName(entry.get("plant", &""))
		if id == &"":
			continue
		named += 1
		err = _T.assert_true(PlantCatalog.has(id), "the page keyed to '%s' names a real catalogue plant" % id)
		if err != "":
			return err
	return _T.assert_eq(named, ids.size(), "every keyed page is one of the plants, and every plant is keyed")


## PAGES got longer, and three separate things count it: the "%d / %d" label,
## NotebookPage.page_count behind the dots, and go_to()'s modulo. A page added to
## the table and missed by any one of those is a page you cannot reach, or cannot
## see you are on.
func test_the_notebook_pager_dots_and_wrap_agree_with_the_page_count() -> String:
	var notebook := await _T.instantiate_ui(NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
	var total: int = NotebookScreen.PAGES.size()
	var label: Label = notebook.get_node("PageLabel") as Label
	var paper: NotebookPage = notebook.get_node("Paper") as NotebookPage
	var err: String = _T.assert_gt(total, NotebookScreen.drawing_pages().size(),
		"the notebook holds more than its drawings now — otherwise this walks the old table")
	if err == "":
		err = _T.assert_eq(paper.page_count, total, "the dots count every page, not the five photographs")
	if err == "":
		err = _T.assert_eq(label.text, "1 / %d" % total, "and the pager opens on the first of that many")
	var walked: int = 0
	for page: int in total:
		if err != "":
			break
		notebook.go_to(page)
		walked += 1
		err = _T.assert_eq(label.text, "%d / %d" % [page + 1, total], "page %d labels itself" % [page + 1])
		if err == "":
			err = _T.assert_eq(paper.current_page, page, "and fills its own dot")
	if err == "":
		err = _T.assert_eq(walked, total, "every page was actually turned to")
	if err == "":
		notebook.go_to(total)
		err = _T.assert_eq(label.text, "1 / %d" % total, "Next off the last page wraps to the first")
	if err == "":
		err = _T.assert_eq(paper.current_page, 0, "and the dots wrapped with it")
	if err == "":
		notebook.go_to(-1)
		err = _T.assert_eq(label.text, "%d / %d" % [total, total], "Prev off the first wraps to the last")
	if err == "":
		err = _T.assert_eq(paper.current_page, total - 1, "and so did the dots")
	if err == "":
		# _direction divides by the page count to pick the shorter way round, so it
		# is the third thing a changed page count can quietly break — a wrap that
		# nudges the wrong way is a page turn that reads backwards.
		err = _T.assert_float_eq(NotebookScreen._direction(total - 1, 0), 1.0, 0.001,
			"wrapping past the end still nudges forwards")
	if err == "":
		err = _T.assert_float_eq(NotebookScreen._direction(0, total - 1), -1.0, 0.001,
			"and wrapping before the start still nudges backwards")
	_T.free_ui(notebook)
	return err


## The two newest plants were designed in this repo, not on paper, so their pages
## have no photograph to show and the left half becomes an index card built out of
## PlantCatalog instead. Exactly one of Drawing and SpecLabel is up at a time, the
## card says what the catalogue says, and it fits the box — a card that overflows
## is silently ellipsised, which is how a plant's whole blurb would disappear with
## nothing on screen to say so.
func test_the_notebook_plant_pages_fit_their_card() -> String:
	var notebook := await _T.instantiate_ui(NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
	var drawing: Control = notebook.get_node("Drawing") as Control
	var spec: Label = notebook.get_node("SpecLabel") as Label
	var source: Label = notebook.get_node("SourceLabel") as Label
	var err: String = _T.assert_true(NotebookScreen.PANEL.encloses(Rect2(spec.position, spec.size)),
		"the spec card sits on the paper, not off the edge of the sheet")
	var font: Font = spec.get_theme_font("font")
	if err == "":
		err = _T.assert_true(font != null, "and the card has a font to measure against")
	if err != "":
		_T.free_ui(notebook)
		return err
	var font_size: int = spec.get_theme_font_size("font_size")
	var drawn_pages: int = 0
	var plant_pages: int = 0
	var shelf_pages: int = 0
	var legend_pages: int = 0
	var hint_pages: int = 0
	for page: int in NotebookScreen.PAGES.size():
		if err != "":
			break
		notebook.go_to(page)
		var entry: Dictionary = NotebookScreen.PAGES[page]
		var kind: String = String(entry.get("kind", NotebookScreen.KIND_DRAWING))
		if kind == NotebookScreen.KIND_DRAWING:
			drawn_pages += 1
			err = _T.assert_true(drawing.visible, "page %d shows the photograph it has" % [page + 1])
			if err == "":
				err = _T.assert_false(spec.visible, "and does not also stack a spec card on it")
			continue
		if kind == NotebookScreen.KIND_SHELF:
			# The third thing the left page can hold, and it is about no plant at
			# all — see NotebookScreen.KIND_SHELF. Only the exclusivity of the
			# three is this test's business; the shelf's own contents are asserted
			# in test_selftest.gd.
			shelf_pages += 1
			err = _T.assert_false(drawing.visible, "page %d is the shelf, not a photograph" % [page + 1])
			if err == "":
				err = _T.assert_false(spec.visible, "and not a spec card either")
			if err == "":
				err = _T.assert_true((notebook.get_node("Shelf") as Control).visible,
					"the shelf itself is what the left page shows")
			continue
		if kind == NotebookScreen.KIND_LEGEND:
			# The fourth, and it arrived by tripping this chain's `else` -- which meant
			# PLANT, so the legend page was asserted to name a real plant and reported as
			# a broken plant page. That is the same latent defect the production
			# `go_to` had (there the `else` meant SHELF), fixed there with
			# NotebookScreen.PANE_LABELS. Kept as a branch here rather than a table
			# because a test's business is the exclusivity, not the content: the left
			# page holds exactly one of five things, and each branch asserts the panes
			# it could most plausibly be confused with are down.
			legend_pages += 1
			err = _T.assert_false(drawing.visible, "page %d is the legend, not a photograph" % [page + 1])
			if err == "":
				err = _T.assert_false(spec.visible, "and not a spec card")
			if err == "":
				err = _T.assert_false((notebook.get_node("Shelf") as Control).visible,
					"and not the shelf")
			if err == "":
				err = _T.assert_true((notebook.get_node("CueLegend") as Control).visible,
					"the legend itself is what the left page shows")
			continue
		if kind == NotebookScreen.KIND_HINTS:
			# The fifth (plant-tower-defense-ei83). Added as a branch for the reason the
			# legend's comment above gives: without one it falls through to the plant
			# case, and a page about no plant at all gets reported as a broken plant
			# page rather than as a missing branch. The denominator below is what makes
			# a SIXTH kind say so instead.
			hint_pages += 1
			err = _T.assert_false(drawing.visible, "page %d is the hints page, not a photograph" % [page + 1])
			if err == "":
				err = _T.assert_false(spec.visible, "and not a spec card")
			if err == "":
				err = _T.assert_false((notebook.get_node("Shelf") as Control).visible,
					"and not the shelf")
			if err == "":
				err = _T.assert_false((notebook.get_node("CueLegend") as Control).visible,
					"and not the legend")
			if err == "":
				err = _T.assert_true((notebook.get_node("Hints") as Control).visible,
					"the hints pane itself is what the left page shows")
			continue
		plant_pages += 1
		var id: StringName = StringName(entry.get("plant", &""))
		err = _T.assert_true(PlantCatalog.has(id), "page %d names a real plant" % [page + 1])
		if err == "":
			err = _T.assert_false(drawing.visible,
				"page %d has no drawing, and does not pretend to one" % [page + 1])
		if err == "":
			err = _T.assert_true(spec.visible, "so the spec card is what the left page shows")
		if err == "":
			err = _T.assert_true(spec.text.contains("%d seeds" % PlantCatalog.cost(id)),
				"the card prints %s's real cost off the catalogue, got: %s" % [id, spec.text])
		if err == "":
			err = _T.assert_true(spec.text.contains(PlantCatalog.blurb(id)),
				"and the whole blurb the shop row prints, got: %s" % spec.text)
		if err == "":
			err = _T.assert_true(source.text.contains(String(entry["drawing"]).get_file()),
				"the provenance line still names the file, got: %s" % source.text)
		if err == "":
			err = _T.assert_true(source.text.contains("never on paper"),
				"and says outright that there is no drawing, got: %s" % source.text)
		if err == "":
			# The budget. NoteLabel's problem, one page to the left: clip_text turns
			# an overlong card into a trimmed one rather than a visible overflow, so
			# nothing on screen would report the missing sentence.
			var needed: Vector2 = font.get_multiline_string_size(
				spec.text, HORIZONTAL_ALIGNMENT_LEFT, spec.size.x, font_size)
			err = _T.assert_gte(spec.size.y, needed.y,
				"%s's card wraps to %.0fpx in a %.0fpx box — trim it or grow SPEC_BOX" % [
					id, needed.y, spec.size.y,
				])
	if err == "":
		err = _T.assert_gt(plant_pages, 0,
			"at least one page is a plant page, or the loop above asserted nothing")
	if err == "":
		err = _T.assert_gt(drawn_pages, 0, "and at least one is still a photograph of paper")
	if err == "":
		err = _T.assert_eq(shelf_pages, 1,
			"and exactly one is the shelf — four kinds of left page, every page exactly one of them")
	if err == "":
		err = _T.assert_eq(legend_pages, 1, "and exactly one is the cue legend")
	if err == "":
		err = _T.assert_eq(hint_pages, 1, "and exactly one is the hints page")
	if err == "":
		# The denominator, which is what makes the five counts above mean anything: a
		# sixth kind added without a branch here would fall through to the plant case and
		# be counted as a plant page, so the sum is the only thing that notices.
		err = _T.assert_eq(drawn_pages + plant_pages + shelf_pages + legend_pages + hint_pages,
			NotebookScreen.PAGES.size(),
			"every page was classified — %d + %d + %d + %d + %d of %d" % [
				drawn_pages, plant_pages, shelf_pages, legend_pages, hint_pages,
				NotebookScreen.PAGES.size()])
	if err == "":
		err = _T.assert_eq(drawn_pages, NotebookScreen.drawing_pages().size(),
			"drawing_pages() counts the same pages the screen treats as drawings")
	if err == "":
		# Every catalogue plant can be given a card, not only the two that have one
		# today — the builder reads PlantCatalog, so a future plant page is content
		# and prose, never a layout problem.
		for id: StringName in PlantCatalog.ids():
			err = _T.assert_gt(NotebookScreen.plant_spec(id).length(), 0,
				"%s can be written onto a spec card" % id)
			if err != "":
				break
	_T.free_ui(notebook)
	return err


# --- The husk click budget, as a number a designer can read before it breaks ---
#
# test_no_husk_the_game_can_drop_lands_within_a_click_of_buildable_ground above
# proves the 4 px clearance exists. These prove it is VISIBLE: that the
# board_info devtools verb prints both terms of the subtraction it comes from,
# and that what it prints is the same value the gate asserts on rather than a
# second copy of it that can quietly disagree.


const DEVTOOLS_EXT := "res://devtools_ext/commands.gd"


## board_info as the bus would hand it back. The extension is instantiated
## directly and pointed at the hosted Game -- the bus needs a running game, and
## nothing in this reply needs one, so it stays a pure-logic check.
func _board_info(game: Game) -> Dictionary:
	var ext = preload(DEVTOOLS_EXT).new()
	ext._dev = game
	return ext._cmd_board_info({})


## The readout cannot drift from the thing it reports, and it shows its working.
##
## A verb that printed "husk_click_margin: 4.0" and nothing else would be a fact
## with no scale attached: 4 out of what? So both terms are asserted present AND
## asserted to actually subtract to the reported result. The failure this catches
## is the one that leaves no trace on screen -- a board_info that goes on printing
## a hand-copied 32 and 28 after the geometry moved underneath it.
func test_board_info_prints_the_husk_click_budget_as_a_subtraction() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	err = _T.assert_true(game.board != null, "and brought its board with it")
	if err != "":
		_T.free_ui(game)
		return err
	var reply: Dictionary = _board_info(game)
	err = _T.assert_true(reply.has("success") and reply.has("message") and reply.has("data"),
		"board_info keeps the three-key envelope -- got %s" % [reply.keys()])
	if err == "":
		err = _T.assert_eq(reply.size(), 3, "and carries nothing else")
	if err == "":
		err = _T.assert_true(reply["data"] is Dictionary, "data is a Dictionary")
	if err == "":
		err = _T.assert_true(bool(reply["success"]),
			"and it succeeds against a real Game: %s" % reply["message"])
	if err != "":
		_T.free_ui(game)
		return err
	var data: Dictionary = reply["data"]
	var wanted: Array[String] = [
		"husk_lane_to_buildable",
		"husk_collect_radius",
		"husk_click_margin",
		"husk_click_margin_measured",
		"husk_click_budget",
	]
	err = _T.assert_eq(wanted.size(), 5, "there are five budget fields to look for")
	for key: String in wanted:
		if err != "":
			break
		err = _T.assert_true(data.has(key),
			"board_info reports %s -- got %s" % [key, data.keys()])
	if err != "":
		_T.free_ui(game)
		return err
	var lane: float = float(data["husk_lane_to_buildable"])
	var sweep: float = float(data["husk_collect_radius"])
	var shown: float = float(data["husk_click_margin"])
	var margin: float = PlacementPreview.husk_click_margin(game.board)
	err = _T.assert_float_eq(shown, margin, 0.001,
		"the margin printed (%.3f) is the margin the gate asserts on (%.3f)" % [shown, margin])
	if err == "":
		err = _T.assert_float_eq(lane - sweep, margin, 0.001,
			"lane %.3f - sweep %.3f = %.3f, so the subtraction on screen is the real one"
				% [lane, sweep, margin])
	if err == "":
		err = _T.assert_float_eq(sweep, CompostMeter.COLLECT_RADIUS, 0.001,
			"the sweep term is CompostMeter.COLLECT_RADIUS itself, not a literal beside it")
	if err == "":
		err = _T.assert_float_eq(lane, PlacementPreview.lane_to_buildable_distance(game.board),
			0.001, "and the lane term is lane_to_buildable_distance() itself")
	if err == "":
		err = _T.assert_true(bool(data["husk_click_margin_measured"]),
			"a real board reports a MEASURED margin, so an unmeasurable 0.0 cannot pass for clearance")
	if err == "":
		err = _T.assert_gt(margin, 0.0,
			"and the budget still has something left in it -- %.1f px" % margin)
	if err == "":
		err = _T.assert_true(str(reply["message"]).contains("%.1f" % margin),
			"the one-line message carries the margin too, for a reader who never opens data: %s"
				% reply["message"])
	if err == "":
		# It crosses the bus as JSON; a Dictionary or Object in here would not survive.
		for key: String in data:
			var value: Variant = data[key]
			err = _T.assert_true(value is String or value is int or value is float or value is bool,
				"data.%s is a JSON-safe scalar, got %s" % [key, type_string(typeof(value))])
			if err != "":
				break
	_T.free_ui(game)
	return err


## The prose quotes the geometry, rather than remembering it.
##
## The summary is the half a designer actually reads, and a sentence is exactly
## the kind of thing that goes on saying "4 px clear" for a year after the road
## moved. Every number in it is formatted from the same dictionary it ships with,
## so this asserts the digits are present rather than trusting the wording.
func test_the_husk_budget_summary_quotes_the_numbers_it_was_computed_from() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	err = _T.assert_true(game.board != null, "and brought its board with it")
	if err != "":
		_T.free_ui(game)
		return err
	var budget: Dictionary = PlacementPreview.husk_click_budget(game.board)
	err = _T.assert_true(budget.has("summary") and budget.has("margin")
		and budget.has("lane_to_buildable") and budget.has("collect_radius"),
		"the budget carries both terms, the result and the prose -- got %s" % [budget.keys()])
	if err != "":
		_T.free_ui(game)
		return err
	var summary: String = str(budget["summary"])
	err = _T.assert_gt(summary.length(), 0, "the summary is a real sentence")
	var terms: Array[String] = [
		"%.1f" % float(budget["lane_to_buildable"]),
		"%.1f" % float(budget["collect_radius"]),
		"%.1f" % float(budget["margin"]),
	]
	if err == "":
		err = _T.assert_eq(terms.size(), 3, "there are three numbers to find in it")
	for term: String in terms:
		if err != "":
			break
		err = _T.assert_true(summary.contains(term),
			"the summary prints %s px -- got: %s" % [term, summary])
	if err == "":
		err = _T.assert_float_eq(float(budget["margin"]),
			PlacementPreview.husk_click_margin(game.board), 0.001,
			"and the budget's own margin is husk_click_margin(), not a recomputation of it")
	_T.free_ui(game)
	return err


## An unmeasurable board must not be able to impersonate a measured one.
##
## husk_click_margin() answers 0.0 for a board it could not walk, which is the
## value that FAILS its gate -- fine for a gate, useless for a readout, because a
## reader seeing "lane 0.0" would conclude the lane runs straight over plantable
## ground. So the budget reports -1.0 and says UNMEASURED in words.
func test_the_husk_budget_never_reports_an_unmeasurable_board_as_clearance() -> String:
	var blind: Dictionary = PlacementPreview.husk_click_budget(null)
	var err: String = _T.assert_true(blind.has("measured") and blind.has("lane_to_buildable")
		and blind.has("margin") and blind.has("summary"),
		"even the blind answer carries every field -- got %s" % [blind.keys()])
	if err != "":
		return err
	err = _T.assert_false(bool(blind["measured"]), "a null board measured nothing")
	if err == "":
		err = _T.assert_float_eq(float(blind["lane_to_buildable"]), -1.0, 0.001,
			"and reports -1.0, never 0.0 -- 0.0 is a real distance, and it is the defect")
	if err == "":
		err = _T.assert_float_eq(PlacementPreview.lane_to_buildable_distance(null), -1.0, 0.001,
			"the lane term says the same on its own")
	if err == "":
		err = _T.assert_float_eq(float(blind["margin"]),
			PlacementPreview.husk_click_margin(null), 0.001,
			"the margin is still exactly what the gate would see, which is the failing 0.0")
	if err == "":
		err = _T.assert_true(str(blind["summary"]).contains("UNMEASURED"),
			"and the prose refuses to read as a measurement -- got: %s" % blind["summary"])
	return err


# --- The `budgets` verb: every declared coupling, with what is left of it ---
#
# Four constants in this project carry a "moving me costs you X" doc comment and
# every X lives in a different file. `budgets` is the index of that set, and the
# whole value of it is that each number is COMPUTED from the same call the gate
# asserts on rather than transcribed out of the comment beside it. So these tests
# do not check that a key exists -- they call the real source themselves and
# assert the readout agrees with it, because a verb that quietly drifts from the
# thing it reports is worse than no verb: it is a fifth stale copy wearing the
# authority of a measurement.


## `budgets` as the bus would hand it back, with the extension pointed at the
## hosted Game the same way _board_info() above does.
func _budgets(game: Game, args: Dictionary) -> Dictionary:
	var ext = preload(DEVTOOLS_EXT).new()
	ext._dev = game
	return ext._cmd_budgets(args)


## One entry out of the reply, or {} if the verb never reported it. Returning an
## empty Dictionary rather than null keeps the caller's vacuity guard a size
## check instead of a null check, which is the one people forget.
func _budget_entry(data: Dictionary, id: String) -> Dictionary:
	if not data.has("budgets"):
		return {}
	for entry: Dictionary in (data["budgets"] as Array):
		if str(entry["id"]) == id:
			return entry
	return {}


## Everything in `data` has to survive JSON on its way across the bus.
func _budget_value_is_wire_safe(value: Variant) -> bool:
	if value is String or value is int or value is float or value is bool:
		return true
	if value is Array:
		for item: Variant in (value as Array):
			if not _budget_value_is_wire_safe(item):
				return false
		return true
	if value is Dictionary:
		var dict: Dictionary = value as Dictionary
		for key: Variant in dict:
			if not (key is String):
				return false
			if not _budget_value_is_wire_safe(dict[key]):
				return false
		return true
	return false


## The shape of the report, and the denominator that makes it readable.
##
## The failure this guards is a check quietly vanishing from a consolidated
## report: a `budgets` that dropped the notebook entry would print a shorter,
## cleaner list and nothing would say a coupling had stopped being watched. So
## every id is named here, and every entry is asserted to carry the whole
## contract rather than whichever half its own branch happened to fill in.
func test_the_budgets_verb_reports_every_declared_coupling() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	var reply: Dictionary = _budgets(game, {"waves": 30})
	err = _T.assert_true(reply.has("success") and reply.has("message") and reply.has("data"),
		"budgets keeps the three-key envelope -- got %s" % [reply.keys()])
	if err == "":
		err = _T.assert_eq(reply.size(), 3, "and carries nothing else")
	if err == "":
		err = _T.assert_true(bool(reply["success"]),
			"and succeeds against a real Game: %s" % reply["message"])
	if err != "":
		_T.free_ui(game)
		return err
	var data: Dictionary = reply["data"]

	# Each of the four commented constants, plus the split of WORST_CASE_TEXT
	# into "does a readout fit its slot" and "do the slots fit the row" -- those
	# are two different budgets and widening one spends the other -- plus the
	# message row, which is measured against the catalogue rather than a written
	# worst case (plant-tower-defense-m1el).
	#
	# **This list is hand-written on purpose and adding a budget is SUPPOSED to break
	# it.** Deriving it from the same table the verb reads would make the assertion
	# tautological: the verb would be reporting what the verb reports. What it is for
	# is the other direction -- a budget declared and never wired into `budget_entries`
	# is invisible everywhere else, and a budget wired in that nobody meant to add
	# shows up here as a number that moved.
	var wanted: Array[String] = [
		"husk_click",
		"notebook_subhead",
		"hud_readouts",
		"hud_message_row",
		"hud_stats_row",
		"pest_road_ceiling",
		"road_shape",
	]
	err = _T.assert_eq(wanted.size(), 7, "there are seven budgets to look for")
	if err == "":
		err = _T.assert_eq(int(data["count"]), wanted.size(),
			"the verb reports exactly that many -- got %d" % int(data["count"]))
	if err != "":
		_T.free_ui(game)
		return err

	var contract: Array[String] = [
		"id", "constant", "declared_in", "computed", "spends", "spent", "ceiling",
		"headroom", "units", "state", "measured_by", "summary", "when_it_runs_out",
		"observations",
	]
	for id: String in wanted:
		var entry: Dictionary = _budget_entry(data, id)
		err = _T.assert_gt(entry.size(), 0, "budgets reports %s" % id)
		if err != "":
			break
		for key: String in contract:
			err = _T.assert_true(entry.has(key), "%s carries %s -- got %s" % [id, key, entry.keys()])
			if err != "":
				break
		if err != "":
			break
		# The half a bare key check misses: a "budget" with no summary and no
		# advice is a row in a table, not a readout.
		err = _T.assert_gt(str(entry["summary"]).length(), 0, "%s has a summary sentence" % id)
		if err == "":
			err = _T.assert_gt(str(entry["when_it_runs_out"]).length(), 0,
				"%s says what breaks when it runs out" % id)
		if err == "":
			err = _T.assert_gt(str(entry["constant"]).length(), 0, "%s names its constant" % id)
		if err == "":
			err = _T.assert_true(FileAccess.file_exists(str(entry["declared_in"])),
				"%s points at a file that exists: %s" % [id, entry["declared_in"]])
		if err != "":
			break
	if err == "":
		for key: Variant in data:
			err = _T.assert_true(_budget_value_is_wire_safe(data[key]),
				"data.%s survives JSON, got %s" % [key, type_string(typeof(data[key]))])
			if err != "":
				break
	_T.free_ui(game)
	return err


## The verdict, and the denominator behind it.
##
## `computed` vs `uncomputed` is the honest half of this verb: five of the six
## couplings have a ceiling that can be subtracted from and one does not, and a
## report that hid that ratio would read as six measurements. So the two are
## asserted to add up to the count, and the one described entry is asserted to be
## the road -- not whichever entry happened to fail to measure this run.
func test_the_budgets_verdicts_add_up_to_the_budgets_reported() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	var data: Dictionary = _budgets(game, {"waves": 30})["data"]
	var entries: Array = data["budgets"] as Array
	err = _T.assert_gt(entries.size(), 0, "the verb reported something to grade")
	if err != "":
		_T.free_ui(game)
		return err
	var computed: int = 0
	var spent: int = 0
	var spent_by_design: int = 0
	var tight: int = 0
	var described: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		var state: String = str(entry["state"])
		if bool(entry["computed"]):
			computed += 1
			# A computed entry's three numbers must actually subtract.
			err = _T.assert_float_eq(float(entry["headroom"]),
				float(entry["ceiling"]) - float(entry["spent"]), 0.001,
				"%s: %s - %s really is the headroom it prints" % [
					entry["id"], entry["ceiling"], entry["spent"]])
			if err != "":
				break
			if state == "spent":
				spent += 1
			elif state == Game.BUDGET_SPENT_BY_DESIGN:
				spent_by_design += 1
			elif state == "tight":
				tight += 1
			else:
				err = _T.assert_eq(state, "ok", "%s has a known verdict" % entry["id"])
				if err != "":
					break
		else:
			described.append("%s(%s)" % [entry["id"], state])
			# -1.0, never 0.0: 0.0 is a real headroom and it is the worst one
			# there is, so an entry that measured nothing must not be able to
			# impersonate a budget that is exactly spent.
			err = _T.assert_float_eq(float(entry["headroom"]), -1.0, 0.001,
				"%s reports -1.0 rather than a headroom it never measured" % entry["id"])
			if err == "":
				err = _T.assert_float_eq(float(entry["ceiling"]), -1.0, 0.001,
					"%s reports no ceiling either" % entry["id"])
			if err != "":
				break
	if err == "":
		err = _T.assert_eq(computed, int(data["computed"]),
			"the computed tally matches the entries -- %d walked, %d reported"
				% [computed, int(data["computed"])])
	if err == "":
		err = _T.assert_eq(entries.size() - computed, int(data["uncomputed"]),
			"and so does the uncomputed one")
	if err == "":
		err = _T.assert_eq(spent, int(data["spent"]), "and the spent tally")
	if err == "":
		err = _T.assert_eq(spent_by_design, int(data["spent_by_design"]),
			"and the spent-by-design tally")
	if err == "":
		err = _T.assert_eq(tight, int(data["tight"]), "and the tight tally")
	if err == "":
		# Named, not counted: "one entry could not be measured" is a very
		# different report from "one coupling has no number by nature".
		err = _T.assert_eq(", ".join(described), "road_shape(described)",
			"the only entry without a number is the road, and it is described rather than unmeasured")
	if err == "":
		err = _T.assert_gt(str(data["tightest"]).length(), 0,
			"and the report names its tightest budget")
	_T.free_ui(game)
	return err


## The husk entry is husk_click_budget(), not a second copy of it.
##
## This is the whole point of the verb stated as an assertion: `spent` is
## CompostMeter.COLLECT_RADIUS, `ceiling` is the distance the lane keeps from
## buildable ground, and `headroom` is the number the husk gate fails on. Any one
## of those being a literal typed beside the verb would pass a "has the key"
## check and fail this one.
func test_the_budgets_husk_entry_is_the_margin_the_gate_asserts_on() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null and game.board != null,
		"the main scene loads and brought its board")
	if err != "":
		return err
	var entry: Dictionary = _budget_entry(_budgets(game, {"waves": 30})["data"], "husk_click")
	err = _T.assert_gt(entry.size(), 0, "budgets reports husk_click")
	if err != "":
		_T.free_ui(game)
		return err
	var live: Dictionary = PlacementPreview.husk_click_budget(game.board)
	err = _T.assert_true(bool(entry["computed"]),
		"a real board gives a measured budget: %s" % entry["summary"])
	if err == "":
		err = _T.assert_float_eq(float(entry["spent"]), CompostMeter.COLLECT_RADIUS, 0.001,
			"what is being spent is COLLECT_RADIUS itself (%.1f), not a literal beside it"
				% float(entry["spent"]))
	if err == "":
		err = _T.assert_float_eq(float(entry["ceiling"]),
			PlacementPreview.lane_to_buildable_distance(game.board), 0.001,
			"the ceiling is lane_to_buildable_distance() itself (%.1f)" % float(entry["ceiling"]))
	if err == "":
		err = _T.assert_float_eq(float(entry["headroom"]),
			PlacementPreview.husk_click_margin(game.board), 0.001,
			"and the headroom is husk_click_margin(), the number the gate fails on (%.1f)"
				% float(entry["headroom"]))
	if err == "":
		# It must not contradict board_info, which prints the same subtraction.
		err = _T.assert_float_eq(float(entry["headroom"]), float(live["margin"]), 0.001,
			"so budgets and board_info cannot report different clearances for one board")
	if err == "":
		err = _T.assert_gt(float(entry["headroom"]), 0.0,
			"and there is still something left in it -- %.1f px" % float(entry["headroom"]))
	if err == "":
		# Not pinned to the literal "tight": lowering COLLECT_RADIUS is a real fix
		# and must not fail a test. What must hold is that a budget this close to
		# its end is never reported as a clean pass -- 4 px of 32 is the case the
		# verdict exists for, and "ok" there is the readout lying by omission.
		var fraction: float = float(entry["headroom"]) / float(entry["ceiling"])
		if fraction < 0.15:
			err = _T.assert_true(str(entry["state"]) == "tight" or str(entry["state"]) == "spent",
				"%.0f px of %.0f (%.0f%% left) is not a clean pass -- got '%s'"
					% [float(entry["headroom"]), float(entry["ceiling"]), fraction * 100.0,
						entry["state"]])
		else:
			err = _T.assert_eq(str(entry["state"]), "ok",
				"%.0f%% left reads as ok" % (fraction * 100.0))
	if err == "":
		err = _T.assert_true(str(entry["summary"]).contains("%d" % int(float(entry["headroom"]))),
			"and the one-line summary carries the number: %s" % entry["summary"])
	_T.free_ui(game)
	return err


## The notebook entry measures the sentence the screen actually builds.
##
## Independently re-measured here: the test instantiates its own NotebookScreen
## and reads the Subheading's own text through its own resolved theme font, then
## asserts the verb agrees. A verb that had transcribed 268 out of the comment
## would pass every structural check and fail this the day the sentence changes,
## which is exactly the day it matters.
func test_the_budgets_notebook_entry_measures_the_sentence_the_screen_draws() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	var entry: Dictionary = _budget_entry(_budgets(game, {"waves": 30})["data"], "notebook_subhead")
	err = _T.assert_gt(entry.size(), 0, "budgets reports notebook_subhead")
	if err != "":
		_T.free_ui(game)
		return err
	err = _T.assert_true(bool(entry["computed"]),
		"the subheading was measured even though no notebook is open: %s" % entry["summary"])
	if err != "":
		_T.free_ui(game)
		return err

	var book := await _T.instantiate_ui(
		NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
	var subhead := book.get_node_or_null("Subheading") as Label
	err = _T.assert_true(subhead != null, "an independently built notebook has a Subheading")
	if err != "":
		_T.free_ui(book)
		_T.free_ui(game)
		return err
	# Through the font, not get_minimum_size(): a clip_text Label reports ~1px,
	# so the obvious form of this comparison cannot fail.
	var font: Font = subhead.get_theme_font("font")
	var size_px: int = subhead.get_theme_font_size("font_size")
	err = _T.assert_true(font != null, "and resolved a theme font to measure in")
	if err == "":
		err = _T.assert_gt(size_px, 0, "and a font size")
	if err != "":
		_T.free_ui(book)
		_T.free_ui(game)
		return err
	var drawn: float = font.get_string_size(
		subhead.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
	err = _T.assert_gt(drawn, 0.0, "the subheading has text to measure")
	if err == "":
		err = _T.assert_float_eq(float(entry["spent"]), drawn, 0.5,
			"the verb reports the width the screen really draws (%.1f vs %.1f)"
				% [float(entry["spent"]), drawn])
	if err == "":
		err = _T.assert_float_eq(float(entry["ceiling"]), NotebookScreen.SUBHEAD_MAX_WIDTH, 0.001,
			"against SUBHEAD_MAX_WIDTH itself")
	if err == "":
		err = _T.assert_true(str(entry["observations"]).contains(subhead.text),
			"and quotes the sentence it measured: %s" % [entry["observations"]])
	if err == "":
		err = _T.assert_gt(float(entry["headroom"]), 0.0,
			"the sentence still fits, with %.0f px to spare" % float(entry["headroom"]))
	_T.free_ui(book)
	_T.free_ui(game)
	return err


## The two HUD entries, each re-measured off the live row.
##
## They are separate budgets on purpose and the test says why: the fix for a
## readout that clips is to widen its slot, and that width is spent out of the
## row's total. Reporting only one of the two would let a reader "fix" the first
## by breaking the second.
func test_the_budgets_hud_entries_are_measured_off_the_live_stats_row() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null and game.hud != null,
		"the main scene loads with its HUD")
	if err != "":
		return err
	var stats := game.hud.get_node_or_null("Root/TopBar/StatsRow") as HBoxContainer
	err = _T.assert_true(stats != null, "and the stats row is where the verb looks for it")
	if err != "":
		_T.free_ui(game)
		return err
	var data: Dictionary = _budgets(game, {"waves": 30})["data"]

	# --- the row's own sum ---
	var row: Dictionary = _budget_entry(data, "hud_stats_row")
	err = _T.assert_gt(row.size(), 0, "budgets reports hud_stats_row")
	if err == "":
		err = _T.assert_true(bool(row["computed"]), "and measured it: %s" % row["summary"])
	if err == "":
		err = _T.assert_float_eq(float(row["spent"]),
			Hud.stats_row_budget(stats.get_child_count() - 1), 0.001,
			"the row's spend is Hud.stats_row_budget() itself (%.1f)" % float(row["spent"]))
	if err == "":
		err = _T.assert_float_eq(float(row["ceiling"]), stats.size.x, 0.001,
			"against the live row's own width (%.1f)" % stats.size.x)
	if err == "":
		err = _T.assert_gt(float(row["headroom"]), 0.0,
			"and the row still fits, by %.0f px" % float(row["headroom"]))
	if err != "":
		_T.free_ui(game)
		return err

	# --- the tightest readout in it ---
	var readouts: Dictionary = _budget_entry(data, "hud_readouts")
	err = _T.assert_gt(readouts.size(), 0, "budgets reports hud_readouts")
	if err == "":
		err = _T.assert_true(bool(readouts["computed"]), "and measured it: %s" % readouts["summary"])
	if err == "":
		err = _T.assert_gt(Hud.WORST_CASE_TEXT.size(), 0,
			"there are declared worst cases to re-measure")
	if err != "":
		_T.free_ui(game)
		return err
	# Re-derive the worst slot the same way the row is actually rendered, and
	# assert the verb picked that one. A verb reporting the ROOMIEST readout
	# would look identical in every structural check and be exactly backwards.
	var worst_name: String = ""
	var worst_needed: float = 0.0
	var worst_slot: float = 0.0
	var worst_left: float = INF
	var measured: int = 0
	for readout: String in Hud.WORST_CASE_TEXT:
		var label := stats.get_node_or_null(readout) as Label
		if label == null:
			continue
		var slot_font: Font = label.get_theme_font("font")
		var slot_size: int = label.get_theme_font_size("font_size")
		if slot_font == null or slot_size <= 0:
			continue
		measured += 1
		var needed: float = slot_font.get_string_size(
			String(Hud.WORST_CASE_TEXT[readout]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, slot_size).x
		var slot: float = label.custom_minimum_size.x
		if slot - needed < worst_left:
			worst_left = slot - needed
			worst_name = readout
			worst_needed = needed
			worst_slot = slot
	err = _T.assert_eq(measured, Hud.WORST_CASE_TEXT.size(),
		"every declared readout is a Label in the row (%d of %d)"
			% [measured, Hud.WORST_CASE_TEXT.size()])
	if err == "":
		err = _T.assert_gt(worst_needed, 0.0, "and the worst of them measures something")
	if err == "":
		err = _T.assert_float_eq(float(readouts["spent"]), worst_needed, 0.5,
			"the verb prices the TIGHTEST readout (%s needs %.1f), got %.1f"
				% [worst_name, worst_needed, float(readouts["spent"])])
	if err == "":
		err = _T.assert_float_eq(float(readouts["ceiling"]), worst_slot, 0.001,
			"against that readout's own clipped width")
	if err == "":
		err = _T.assert_true(str(readouts["spends"]).contains(worst_name),
			"and names it, so the reader knows which slot to widen: %s" % readouts["spends"])
	if err == "":
		# Every readout, not only the worst: the point of the index is that the
		# whole set is visible without opening hud.gd.
		err = _T.assert_eq((readouts["observations"] as Array).size(), Hud.WORST_CASE_TEXT.size(),
			"and lists all %d readouts, not only the tightest" % Hud.WORST_CASE_TEXT.size())
	_T.free_ui(game)
	return err


## The pest ceiling is swept, not sampled.
##
## The peak lands early -- at the campaign finale, wave 16, where two queens,
## their brood headroom, a full swarm and a beetle column are all priced onto the
## road at once -- so a verb that probed one late wave would report the road at
## 29 of 40 and be wrong in the reassuring direction. The sweep is re-run here
## over the same range and compared.
func test_the_budgets_pest_ceiling_is_the_worst_wave_in_its_own_sweep() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	var sweep: int = 25
	var entry: Dictionary = _budget_entry(
		_budgets(game, {"waves": sweep})["data"], "pest_road_ceiling")
	err = _T.assert_gt(entry.size(), 0, "budgets reports pest_road_ceiling")
	if err != "":
		_T.free_ui(game)
		return err
	var worst: int = 0
	var worst_wave: int = 0
	for wave: int in range(1, sweep + 1):
		var peak: int = WaveDirector.peak_simultaneous_pests(wave)
		if peak > worst:
			worst = peak
			worst_wave = wave
	err = _T.assert_gt(worst, 0, "the sweep really walked the curve -- wave %d peaks at %d"
		% [worst_wave, worst])
	if err == "":
		err = _T.assert_true(bool(entry["computed"]), "the entry was measured: %s" % entry["summary"])
	if err == "":
		err = _T.assert_float_eq(float(entry["spent"]), float(worst), 0.001,
			"the verb reports the worst wave in the sweep (%d at wave %d), got %.0f"
				% [worst, worst_wave, float(entry["spent"])])
	if err == "":
		err = _T.assert_float_eq(float(entry["ceiling"]),
			float(WaveDirector.SIMULTANEOUS_PEST_CEILING), 0.001,
			"against SIMULTANEOUS_PEST_CEILING itself")
	if err == "":
		err = _T.assert_true(str(entry["measured_by"]).contains("%d" % sweep),
			"and says how far it swept, since a headroom off a short sweep is a smaller claim: %s"
				% entry["measured_by"])
	if err == "":
		err = _T.assert_gt(float(entry["headroom"]), -0.0001,
			"the road is still inside its ceiling -- %.0f of %.0f"
				% [float(entry["spent"]), float(entry["ceiling"])])
	_T.free_ui(game)
	return err


## The road entry refuses to invent a headroom, and measures anyway.
##
## PATH_CORNERS' three dependents are prose reasoned against the road, not
## ceilings the road approaches, so there is nothing to subtract. The failure
## worth guarding is a future edit "completing" the table by giving it a number:
## that would be the fifth stale copy this verb exists to prevent, wearing the
## authority of a measurement. What it must do instead is report what the road
## measures NOW, which is what the prose would have to be re-derived against.
func test_the_road_budget_reports_measurements_rather_than_a_made_up_headroom() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null and game.board != null,
		"the main scene loads and brought its board")
	if err != "":
		return err
	var entry: Dictionary = _budget_entry(_budgets(game, {"waves": 30})["data"], "road_shape")
	err = _T.assert_gt(entry.size(), 0, "budgets reports road_shape")
	if err != "":
		_T.free_ui(game)
		return err
	err = _T.assert_false(bool(entry["computed"]),
		"the road has no ceiling to subtract from, and says so rather than printing one")
	if err == "":
		err = _T.assert_eq(str(entry["state"]), "described",
			"and it is DESCRIBED, not 'unmeasured' -- the difference is whether a number exists")
	if err == "":
		err = _T.assert_float_eq(float(entry["headroom"]), -1.0, 0.001,
			"headroom is -1.0, never 0.0 -- 0.0 would read as a budget exactly spent")
	if err != "":
		_T.free_ui(game)
		return err

	var observations: Array = entry["observations"] as Array
	err = _T.assert_gt(observations.size(), 0,
		"having no headroom does not excuse having nothing to say")
	if err != "":
		_T.free_ui(game)
		return err
	var text: String = "\n".join(PackedStringArray(observations))
	# The live measurements, re-derived here. These are the numbers the three
	# couplings would have to be re-derived against, so they have to be the
	# CURRENT road rather than the one the comments were written against.
	var cells: int = game.board.path_cell_count()
	err = _T.assert_gt(cells, 0, "the board built a road to measure")
	if err == "":
		err = _T.assert_true(text.contains("%d cells" % cells),
			"the observations quote the road's real length in cells (%d): %s" % [cells, text])
	if err != "":
		_T.free_ui(game)
		return err
	var buildable: int = 0
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			if game.board.is_buildable(Vector2i(x, y)):
				buildable += 1
	err = _T.assert_gt(buildable, 0, "and left ground to plant on")
	if err == "":
		err = _T.assert_true(text.contains("%d buildable cells" % buildable),
			"and quote the buildable count the dead-ground reasoning is stated against (%d): %s"
				% [buildable, text])
	if err == "":
		# The dead-ground count is the one dependent that CAN be recomputed, and
		# the reason it is an observation rather than a headroom: it has no
		# ceiling, only a previously-recorded value living in another test.
		var reach: float = PlantCatalog.reach(PlantCatalog.CORN)
		err = _T.assert_gt(reach, 0.0, "the Corn Cobbler has a reach to measure dead ground at")
		if err == "":
			var dead: int = 0
			for y: int in range(Board.ROWS):
				for x: int in range(Board.COLS):
					var cell := Vector2i(x, y)
					if not game.board.is_buildable(cell):
						continue
					if PlacementPreview.covered_road_cells(game.board, cell, reach) == 0:
						dead += 1
			err = _T.assert_true(text.contains("%d of the %d buildable cells" % [dead, buildable]),
				"and quote the live dead-ground count (%d of %d): %s" % [dead, buildable, text])
	if err == "":
		err = _T.assert_true(text.contains("Sundew"),
			"and admit outright that the Sundew's arithmetic is prose nothing here can check: %s"
				% text)
	_T.free_ui(game)
	return err


## One budget at a time, and a refusal that names the alternatives.
##
## An unknown id answering success with an empty list is the failure mode: a
## reader who asked for "husk" would conclude the husk budget had been retired
## rather than that they had mistyped it.
func test_the_budgets_verb_filters_by_id_and_refuses_an_unknown_one() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	var one: Dictionary = _budgets(game, {"id": "husk_click", "waves": 30})
	err = _T.assert_true(bool(one["success"]), "a known id succeeds")
	if err == "":
		err = _T.assert_eq(int((one["data"] as Dictionary)["count"]), 1,
			"and reports exactly the one asked for")
	if err == "":
		var only: Array = (one["data"] as Dictionary)["budgets"] as Array
		err = _T.assert_gt(only.size(), 0, "with an entry in it")
		if err == "":
			err = _T.assert_eq(str((only[0] as Dictionary)["id"]), "husk_click",
				"and it is the right one")
	if err == "":
		var missing: Dictionary = _budgets(game, {"id": "husk", "waves": 30})
		err = _T.assert_false(bool(missing["success"]),
			"a mistyped id FAILS rather than reporting an empty, clean-looking set")
		if err == "":
			err = _T.assert_true(str(missing["message"]).contains("husk_click"),
				"and the refusal names the ids that do exist: %s" % missing["message"])
	_T.free_ui(game)
	return err


## plant-tower-defense-gzm: the verb used to refuse outright with no Game in
## the tree, which is backwards for notebook_subhead in particular -- it is
## about a title-screen subscreen, and requiring a run just to read it is
## exactly the wrong direction. Now it degrades per entry instead.
func test_the_budgets_verb_degrades_per_entry_with_no_game_in_the_tree() -> String:
	var host := Node2D.new()
	await _T.instantiate_scene(host)
	# Precondition, and the only reason anything below this line means anything.
	#
	# The verb reaches its Game through `_dev.get_tree().get_first_node_in_group(
	# "game")`, which is TREE-GLOBAL: it does not care that `host` is the node
	# handed to the extension. One Game anywhere in the tree -- left by another
	# test, or made by this one's own settle frames -- sends `_cmd_budgets` down
	# the *measured* path, and every assertion below would then pass while
	# proving nothing whatever about degrading.
	#
	# Read as a SET and pin the count at exactly zero. `get_first_node_in_group`
	# is "whichever one the engine lists first" and cannot tell one stranger from
	# five, so it can never state the property this test depends on; and a
	# `> 0`-shaped test of the same idea is precisely the reasoning that leaves
	# this class of test green for the wrong reason (see the godot-test-isolation
	# skill, and tools/group_leak_check.py, which enforces this rule).
	var in_group: Array[Node] = host.get_tree().get_nodes_in_group("game")
	var found: PackedStringArray = PackedStringArray()
	for n: Node in in_group:
		found.append("%s (%s)" % [n.get_path(), n.get_class()])
	var err: String = _T.assert_eq(in_group.size(), 0,
		"nothing is in the 'game' group before this test starts. A Game left in"
		+ " the tree makes the verb answer from the measured path and every"
		+ " assertion below passes for the wrong reason. Found: [%s]"
			% ", ".join(found))
	if err != "":
		_T.free_ui(host)
		return err
	var ext = preload(DEVTOOLS_EXT).new()
	ext._dev = host
	var reply: Dictionary = ext._cmd_budgets({})
	err = _T.assert_true(bool(reply["success"]),
		"the verb answers even with nothing in the 'game' group: %s" % reply["message"])
	var data: Dictionary = reply.get("data", {}) as Dictionary
	if err == "":
		var notebook: Dictionary = _budget_entry(data, "notebook_subhead")
		err = _T.assert_true(bool(notebook.get("computed", false)),
			"notebook_subhead still answers -- it builds its own throwaway SubViewport")
	if err == "":
		var road: Dictionary = _budget_entry(data, "road_shape")
		err = _T.assert_eq(str(road.get("state", "")), Game.BUDGET_DESCRIBED,
			"road_shape still answers too -- Board's own statics self-heal outside any tree")
	if err == "":
		for id: String in ["husk_click", "hud_readouts", "hud_stats_row", "pest_road_ceiling"]:
			var entry: Dictionary = _budget_entry(data, id)
			err = _T.assert_gt(entry.size(), 0, "%s is still named in the reply" % id)
			if err == "":
				err = _T.assert_false(bool(entry.get("computed", true)),
					"%s degrades to unmeasured rather than taking the whole reply down: %s"
						% [id, entry.get("summary", "")])
			if err != "":
				break
	_T.free_ui(host)
	return err


## Every plant must SAY whether it can touch a pest.
##
## `PlantCatalog.engages()` defaults a missing key to false, which is the safe
## direction — over-reporting a coverage hole nags, where promising cover that
## does not exist costs beds. But defaulting is not deciding, and the whole point
## of moving this out of `Game.ENGAGING_PLANTS` was to put the answer beside the
## plant so it cannot be forgotten. A fifth plant that omits the key would
## silently inherit "false" and read as a hole forever.
##
## Checks the raw entry, not `engages()`, because `engages()` is exactly the
## function that hides the difference between "declared false" and "never said".
func test_every_plant_declares_whether_it_engages() -> String:
	var ids: Array[StringName] = PlantCatalog.ids()
	var err: String = _T.assert_gt(ids.size(), 0, "the catalogue has plants to check")
	if err != "":
		return err

	var checked: int = 0
	for id: StringName in ids:
		var e: Dictionary = PlantCatalog.entry(id)
		err = _T.assert_true(e.has("engages"),
			"%s declares an \"engages\" key. Add one: true if it can damage or hold"
				% id + " a pest, false if it cannot. Do not let it default")
		if err != "":
			return err
		err = _T.assert_true(typeof(e["engages"]) == TYPE_BOOL,
			"%s's \"engages\" is a bool, not %s" % [id, type_string(typeof(e["engages"]))])
		if err != "":
			return err
		checked += 1
	return _T.assert_eq(checked, ids.size(), "every plant was asked")


## The distinction that makes `engages` a separate key from `reach`.
##
## A Sundew has a real SAP_RADIUS — a patch touching no road is as useless as a
## cob that can shoot none, so the dead-ground cue needs it — and it damages
## nothing. Anything deriving coverage from `reach()` calls a lane walled in dew
## defended. This pins that the two disagree on at least one plant, so a later
## simplification that collapses them fails here rather than in a coverage map.
func test_reach_and_engages_are_not_the_same_question() -> String:
	var ids: Array[StringName] = PlantCatalog.ids()
	var err: String = _T.assert_gt(ids.size(), 0, "the catalogue has plants to check")
	if err != "":
		return err

	var disagreeing: Array[StringName] = []
	var agreeing: Array[StringName] = []
	for id: StringName in ids:
		if PlantCatalog.reach(id) <= 0.0:
			continue
		if PlantCatalog.engages(id):
			agreeing.append(id)
		else:
			disagreeing.append(id)
	err = _T.assert_gt(disagreeing.size(), 0,
		"at least one plant reaches without engaging, which is why these are two"
			+ " keys. If this ever becomes empty, check it is because the plant"
			+ " changed and not because the keys were collapsed")
	if err == "":
		err = _T.assert_true(disagreeing.has(PlantCatalog.SUNDEW),
			"and the Sundew is one of them (found %s)" % [disagreeing])
	if err == "":
		# BOTH directions, or `engages()` returning false for everything satisfies
		# the assertion above with every plant on the board (plant-tower-defense-qewq).
		# A one-sided disagreement is what a collapsed key looks like.
		err = _T.assert_gt(agreeing.size(), 0,
			("every plant with reach came back not-engaging (%d of them). That is not"
				% disagreeing.size())
				+ " two keys disagreeing, it is `engages` answering false for"
				+ " everything -- check PlantCatalog.engages before believing the"
				+ " assertion above")
	return err


## `Game.engaging_plants()` is a one-line wrapper over `PlantCatalog.engaging_ids()`,
## and a wrapper is exactly the shape that drifts: the coverage code reads the Game
## side, every test read the Game side, and the catalogue side was reachable only
## transitively — which suite_reach_check caught the moment it shipped.
##
## Naming both and asserting they agree pins the wrapper as a wrapper. It also pins
## catalogue ORDER, since coverage iterates this and a set would make the map's
## iteration order depend on dictionary insertion.
func test_the_catalogue_and_the_game_agree_on_who_engages() -> String:
	var from_catalogue: Array[StringName] = PlantCatalog.engaging_ids()
	var from_game: Array[StringName] = Game.engaging_plants()
	var err: String = _T.assert_gt(from_catalogue.size(), 0,
		"some plant engages, or every assertion below is vacuous")
	if err == "":
		err = _T.assert_eq(from_catalogue.size(), from_game.size(),
			"both sides name the same number of engaging plants")
	if err != "":
		return err

	var checked: int = 0
	for i: int in range(from_catalogue.size()):
		err = _T.assert_eq(from_catalogue[i], from_game[i],
			"and in the same order at %d — coverage iterates this, so order is not free" % i)
		if err != "":
			return err
		checked += 1
	if err == "":
		err = _T.assert_eq(checked, from_catalogue.size(), "every entry was compared")
	if err == "":
		# The order claim, against the source of truth rather than against itself.
		var expected: Array[StringName] = []
		for id: StringName in PlantCatalog.ORDER:
			if PlantCatalog.engages(id):
				expected.append(id)
		err = _T.assert_eq(from_catalogue, expected,
			"and it is catalogue ORDER, not dictionary insertion order")
	return err


## The coverage sentence must not promise more than the map knows.
##
## It used to read "Nothing covers the last N% of the road." That is false, and
## measurably so: Kernel._physics_process flies until the kernel leaves the board
## and kills the first pest it touches, aimed at or not — 7 kills were measured on
## unaimed ground at 202 px and 192 px from the nearest cob, outside its 176 px
## ring. Things die on ground "nothing covers".
##
## The claim the map can actually support is about AIM, and it is the same word the
## board's own mark uses: `unaimed`, deliberately never `unreachable`. A player told
## "nothing covers" over-buys cover for ground already taking kills.
##
## This is a wording test, which is unusual and worth defending: the sentence is the
## only place the coverage map talks to a player, and the difference between the two
## verbs is the difference between a true statement and a false one. Pinning the
## formatter is the only thing that stops a later edit reaching for the shorter word.
func test_the_coverage_sentence_claims_aim_and_not_protection() -> String:
	var note: String = Game.coverage_note_for(0.4)
	var err: String = _T.assert_gt(note.length(), 0,
		"a partial frontier produces a sentence at all")
	if err != "":
		return err

	err = _T.assert_true(note.contains("aimed"),
		"the sentence is about aim: %s" % note)
	if err == "":
		err = _T.assert_false(note.contains("covers"),
			"and not about cover, which kernels overshoot: %s" % note)
	if err == "":
		# Nothing that would read as "you are safe" or "nothing can hurt them".
		for word: String in ["protect", "safe", "unreachable", "cannot reach"]:
			err = _T.assert_false(note.to_lower().contains(word),
				"and does not claim \"%s\" — a kernel that leaves the board kills"
					% word + " on unaimed ground: %s" % note)
			if err != "":
				return err

	# And the declared worst case is the formatter's own output, not a literal
	# somebody has to remember to re-copy when the wording changes. This is what
	# caught the width spend when "covers" became "is aimed at".
	if err == "":
		err = _T.assert_true(
			Game.COVERAGE_NOTE_WORST_CASE.contains(Game.coverage_note_for(0.001)),
			"the worst case still contains what the formatter builds (%s vs %s)"
				% [Game.COVERAGE_NOTE_WORST_CASE, Game.coverage_note_for(0.001)])
	return err


## The cue legend, which exists because `game/OVERLAY_GRAMMAR.md` documents ten drawn
## shapes and is referenced only from GDScript comments — a language the game speaks and
## teaches to nobody.
func test_the_legend_names_as_many_shapes_as_the_grammar_documents() -> String:
	## The claim on the page is "5 of the board's 10", and the 10 is a constant in a
	## format string — exactly the kind of number nobody re-checks. This parses the
	## document's own table so the constant fails when a grammar row is added, which
	## matters because that row gets added by someone editing markdown who will never
	## open `notebook_screen.gd`.
	var text: String = FileAccess.get_file_as_string(NotebookScreen.OVERLAY_GRAMMAR_PATH)
	var err: String = _T.assert_gt(text.length(), 0,
		"the grammar document is readable at %s" % NotebookScreen.OVERLAY_GRAMMAR_PATH)
	if err != "":
		return err
	# Scoped to the "What each shape means" SECTION, not to the whole file. The first
	# version counted every pipe-prefixed line in the document, which was right while the
	# file held one table -- and cycle 97 added a second (the per-row channel enumeration,
	# whose header also begins "| Shape"). It reported 20 shapes and would have printed
	# that number to the player. Counting a SECTION rather than a file is the fix, and a
	# test catching its own source document being edited is the whole reason it exists.
	var start: int = text.find("## What each shape means")
	if _T.assert_gt(start, 0, "the shapes section is findable -- a rename would leave this"
			+ " counting something else entirely") != "":
		return "the shapes section is findable"
	var section: String = text.substr(start)
	var stop: int = section.find("\n## ", 1)
	if stop > 0:
		section = section.substr(0, stop)
	var rows: int = 0
	for line: String in section.split("\n"):
		var trimmed: String = line.strip_edges()
		if not trimmed.begins_with("|"):
			continue
		if trimmed.begins_with("| Shape") or trimmed.begins_with("|---"):
			continue
		rows += 1
	err = _T.assert_eq(rows, NotebookScreen.OVERLAY_GRAMMAR_SHAPES,
		"OVERLAY_GRAMMAR.md documents %d shapes and OVERLAY_GRAMMAR_SHAPES says %d -- "
			% [rows, NotebookScreen.OVERLAY_GRAMMAR_SHAPES]
			+ "the legend page prints that number to the player")
	if err == "":
		err = _T.assert_true(CueLegend.row_count() <= rows,
			"the legend teaches %d of them, which cannot exceed what exists"
				% CueLegend.row_count())
	return err


func test_every_legend_row_has_a_shape_the_legend_can_draw() -> String:
	## Derived over ROWS rather than checked on one, and it asserts the two halves that
	## can drift apart independently: a row whose `shape` no branch of `_draw` handles
	## draws nothing at all -- silently, because a `match` with no default is not an error
	## -- and a row missing its text is a swatch with nothing beside it.
	# DERIVED from the source, not a hand-list. The first version of this test kept its own
	# copy of the drawable shapes and had to be edited by the same person adding a row --
	# which is no assertion at all, and it fired on the sixth row for exactly that reason.
	# Two things are checked because they fail apart: a `match` arm can dispatch to nothing
	# and a painter can exist with nothing calling it. A `match` with no default is silent
	# about both.
	var source: String = FileAccess.get_file_as_string("res://game/cue_legend.gd")
	var err: String = _T.assert_gt(source.length(), 0, "the legend script is readable")
	if err == "":
		err = _T.assert_gt(CueLegend.ROWS.size(), 0, "there are rows to check")
	if err != "":
		return err
	if err != "":
		return err
	var seen: Array[String] = []
	for row: Dictionary in CueLegend.ROWS:
		var shape: String = String(row["shape"])
		err = _T.assert_true(source.contains("SHAPE_%s:" % shape.to_upper()),
			"'%s' has a `match` arm in _draw()" % shape)
		if err == "":
			err = _T.assert_true(source.contains("func _draw_%s(" % shape),
				"'%s' has a painter for that arm to call" % shape)
		if err == "":
			err = _T.assert_false(seen.has(shape), "'%s' appears once, not twice" % shape)
		if err == "":
			err = _T.assert_gt(String(row["means"]).length(), 0,
				"'%s' says what it means" % shape)
		if err == "":
			err = _T.assert_gt(String(row["where"]).length(), 0,
				"'%s' says where it is seen" % shape)
		if err != "":
			return err
		seen.append(shape)
	return err


func test_the_legend_swatches_borrow_the_real_cues_constants() -> String:
	## A legend is a second drawing of something the board already draws, so it is a
	## second source of truth by construction. The part that CAN be made structural is
	## the constants, and this is what holds it: every value the swatches key off is read
	## from the cue's own script, so a colour or width changed on the board moves the
	## legend with it. If someone inlines a number here, this test is what notices.
	var source: String = FileAccess.get_file_as_string("res://game/cue_legend.gd")
	var err: String = _T.assert_gt(source.length(), 0, "the legend script is readable")
	if err != "":
		return err
	# Each entry is a constant the swatches must be reading, paired with the cue it
	# belongs to -- named in the message so a failure says which cue went unshared.
	var borrowed: Dictionary = {
		"SelectionMarker.MARKER_COLOR": "the selection brackets' colour",
		"SelectionMarker.LINE_WIDTH": "their line weight",
		"SelectionMarker.ARM": "their arm-to-half ratio",
		"SoleCoverMarks.ALONE_DASHES": "the dashed ring's dash count",
		"SoleCoverMarks.RING_WIDTH": "its width",
		"HuskLayer.BRIGHT_RING": "the rot clock's colour",
		"PlacementPreview.NEW_COVER_DOT": "the gained-cell dot's size",
	}
	for token: String in borrowed:
		err = _T.assert_true(source.contains(token),
			"the legend reads %s (%s) rather than a number that looked similar"
				% [token, borrowed[token]])
		if err != "":
			return err

	# `contains` is a floor and it is not enough on its own: it proves a token appears
	# SOMEWHERE. The first version of this test passed a mutation that inlined
	# `Color(1.0, 0.95, 0.35, 0.9)` into one of the two draw_line calls in _draw_subject,
	# because the other call kept the token alive. So the real property is asserted
	# directly -- no swatch painter names a colour literal at all. Every colour a swatch
	# draws with has to arrive as `Something.CONSTANT`.
	var swatches: int = source.find("func _draw_subject")
	err = _T.assert_gt(swatches, 0, "the swatch painters are findable in the source")
	if err != "":
		return err
	var painters: String = source.substr(swatches)
	err = _T.assert_false(painters.contains("Color("),
		"no swatch painter builds a Color literal -- a legend that hardcodes a hue stops "
			+ "tracking the cue the moment the cue is retuned, and that is exactly the "
			+ "drift this page cannot afford")
	return err


func test_the_legend_fits_the_page_it_is_drawn_on() -> String:
	## The same budget the milestone shelf lives under, and the same failure mode: the
	## pane is a fixed 300px matte and the rows are pitched, so a sixth row is a layout
	## change rather than a content one. `content_bottom` is pure, so this needs no
	## viewport -- but the pane is built for real below to prove the labels land inside
	## it too, which the arithmetic alone cannot say.
	# The pitch itself first, since content_bottom() is derived from it and would hide a
	# broken one: rows march down the pane at a constant gap, in order, none overlapping.
	# suite_reach_check named row_center_y as public-and-unasserted, which is how this got
	# written -- content_bottom() calling it is not the same as a test naming it.
	var err: String = ""
	for i: int in range(CueLegend.ROWS.size() - 1):
		var gap: float = CueLegend.row_center_y(i + 1) - CueLegend.row_center_y(i)
		err = _T.assert_float_eq(gap, CueLegend.ROW_PITCH, 0.001,
			"rows %d and %d are ROW_PITCH apart" % [i, i + 1])
		if err != "":
			return err
	if err == "":
		err = _T.assert_gte(CueLegend.row_center_y(0), CueLegend.SWATCH_RADIUS,
			"the first swatch's top edge is on the pane, not above it")
	if err != "":
		return err
	# assert_gte with the operands the other way up: the helper set has no assert_lte.
	err = _T.assert_gte(NotebookScreen.DRAWING_BOX.size.y,
		CueLegend.content_bottom(),
		"the last legend row's text ends at %.0fpx inside a %.0fpx matte -- another row "
			% [CueLegend.content_bottom(), NotebookScreen.DRAWING_BOX.size.y]
			+ "needs ROW_PITCH cut or the page split")
	if err != "":
		return err
	var notebook := await _T.instantiate_ui(NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
	var legend: Control = notebook.get_node("CueLegend") as Control
	var box := Rect2(Vector2.ZERO, legend.size)
	for row: Dictionary in CueLegend.ROWS:
		var means: Label = legend.get_node_or_null(
			"LegendMeans_%s" % String(row["shape"])) as Label
		err = _T.assert_true(means != null,
			"'%s' has its meaning label" % String(row["shape"]))
		if err == "":
			err = _T.assert_true(box.encloses(Rect2(means.position, means.size)),
				"'%s' meaning label sits inside the pane" % String(row["shape"]))
		if err == "":
			err = _T.assert_gt(_T.text_width(means), 0.0,
				"'%s' meaning label has measurable text" % String(row["shape"]))
		if err == "":
			err = _T.assert_gte(means.size.x, _T.text_width(means),
				"'%s' meaning fits its box without the ellipsis (%.0f of %.0f px)"
					% [String(row["shape"]), _T.text_width(means), means.size.x])
		if err != "":
			break
	_T.free_ui(notebook)
	return err


func test_every_kind_of_notebook_page_has_a_pane_heading() -> String:
	## Derived over the kinds PAGES actually uses, not over PANE_LABELS' own keys -- a
	## table checked against itself is a tautology, and the failure this guards is a kind
	## that reaches `go_to` with no row.
	##
	## It exists because a mutation deleting KIND_LEGEND's row survived everything else:
	## `pane_label_for` returns "" for an unknown kind, which is deliberate (better a
	## blank heading than the neighbouring kind's, which is what the old if/elif/else
	## chain gave), but blank is only better if something notices. This is that something.
	var kinds: Array[String] = []
	for entry: Dictionary in NotebookScreen.PAGES:
		var kind: String = String(entry.get("kind", NotebookScreen.KIND_DRAWING))
		if not kinds.has(kind):
			kinds.append(kind)
	var err: String = _T.assert_gt(kinds.size(), 1,
		"the notebook has more than one kind of page (%d)" % kinds.size())
	if err != "":
		return err
	for kind: String in kinds:
		err = _T.assert_gt(NotebookScreen.pane_label_for(kind).length(), 0,
			"'%s' pages have a heading for the left pane -- a kind with no PANE_LABELS "
				% kind + "row draws a blank heading, which is safe and silent")
		if err != "":
			return err
	return err


func test_the_notebook_opens_where_its_caller_asked() -> String:
	## `open_at` is read once during the build, so it has to be set before `add_child` --
	## a test that set it afterwards would pass on the default and prove nothing. Both
	## values are driven: 0 is the title screen's and is also the default, so asserting
	## only the legend case would not distinguish "the property works" from "the property
	## is ignored and page 0 happens to be right".
	var legend_page: int = NotebookScreen.page_for_kind(NotebookScreen.KIND_LEGEND)
	var err: String = _T.assert_gt(legend_page, 0,
		"the legend is not page 0, so opening there is a real difference (page %d)"
			% legend_page)
	if err != "":
		return err

	# Read through PageLabel, which is the idiom three existing notebook tests use and
	# keeps `_page` private -- a public accessor added for one test is public surface the
	# orphan pass would then list.
	var total: int = NotebookScreen.PAGES.size()
	var front := await _T.instantiate_ui(NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
	err = _T.assert_eq((front.get_node("PageLabel") as Label).text, "1 / %d" % total,
		"with nothing asked for, the notebook opens on the drawings")
	_T.free_ui(front)
	if err != "":
		return err

	var asked := NotebookScreen.new()
	asked.open_at = legend_page
	var deep := await _T.instantiate_ui(asked, Vector2i(1152, 648)) as NotebookScreen
	err = _T.assert_eq((deep.get_node("PageLabel") as Label).text,
		"%d / %d" % [legend_page + 1, total],
		"asked for the legend, it opens on the legend")
	if err == "":
		err = _T.assert_true((deep.get_node("CueLegend") as Control).visible,
			"and the legend pane is the thing showing, not merely the page number")
	_T.free_ui(deep)
	return err


func test_page_for_kind_survives_the_pages_being_reordered() -> String:
	## The reason `page_for_kind` exists rather than a literal 9 in `PauseScreen`. It is
	## asserted against every kind PAGES actually uses, and against the ordering rather
	## than against an index -- an index assertion would have to be edited by the same
	## person who breaks it, which is no assertion at all.
	var kinds: Array[String] = []
	for entry: Dictionary in NotebookScreen.PAGES:
		var kind: String = String(entry.get("kind", NotebookScreen.KIND_DRAWING))
		if not kinds.has(kind):
			kinds.append(kind)
	var err: String = _T.assert_gt(kinds.size(), 1, "there is more than one kind to find")
	if err != "":
		return err
	for kind: String in kinds:
		var at: int = NotebookScreen.page_for_kind(kind)
		err = _T.assert_eq(
			String(NotebookScreen.PAGES[at].get("kind", NotebookScreen.KIND_DRAWING)), kind,
			"page_for_kind('%s') lands on a '%s' page, wherever PAGES has moved it" % [kind, kind])
		if err != "":
			return err
	# The fallback, which the pause screen depends on being harmless: an unknown kind opens
	# the front of the book rather than erroring or landing past the end.
	err = _T.assert_eq(NotebookScreen.page_for_kind("no_such_kind"), -1,
		"an absent kind answers -1 rather than pointing at page 0, so a caller that needs "
			+ "to fail can, and the one that would rather open the front clamps it itself")
	if err == "":
		# shelf_page() is page_for_kind(KIND_SHELF) since cycle 92 -- it was the same
		# search written first, for one kind. Asserted so the delegation cannot be quietly
		# unwound back into a second copy.
		err = _T.assert_eq(NotebookScreen.shelf_page(),
			NotebookScreen.page_for_kind(NotebookScreen.KIND_SHELF),
			"shelf_page() and page_for_kind(KIND_SHELF) are the same answer")
	return err


# -- The Prickly Nettle (plant-tower-defense-l4ke) ---------------------------
#
# The seventh plant, and the first that refuses a target. Everything below is
# driven off `Nettle`'s own constants and off `Pest.mutations` rather than off
# numbers copied out of them, because the whole plant is one rule — "only what
# the mutations changed" — and a test that restates the rule in its own words is
# a second copy of it.


## A bare host for a plant and some pests, with no Game around them.
##
## Deliberately not `_grass(game)` + `place_plant`: everything in this block except
## `test_planting_a_nettle_does_not_silently_plant_corn` is about the targeting rule, and a
## real board would put a road, a wave, weather and whatever else is in the "pests" group
## between the assertion and the thing it is about. `tools/group_leak_check.py` exists
## because a test that reads a tree-global group measures nodes it did not create; every
## pest below is built here and handed to `_act` as an array, so the group is never asked.
func _nettle_host(nodes: Array[Node]) -> Node2D:
	var container := Node2D.new()
	container.name = "NettleHost"
	for node: Node in nodes:
		container.add_child(node)
	return container


## A pest of `species` sitting at `at`, with its own walking switched off.
func _still_pest(species: StringName, at: Vector2, route: PackedVector2Array) -> Pest:
	var pest := Pest.new()
	pest.setup(species, route)
	pest.position = at
	pest.set_physics_process(false)
	return pest


## A Nettle that does not act on its own.
##
## `set_physics_process(false)` is load-bearing rather than tidy. `Plant._physics_process`
## calls `_act` with `_live_pests()`, which reads the tree-wide "pests" group — so the settle
## frames `_T.instantiate_scene` pumps would land stings before any assertion below ran, and
## an exact-health assertion would then be measuring the settle rather than the call. That is
## the failure `tools/settle_read_check.py` is named for.
##
## `setup()` is skipped for the same reason `test_corn_shoots_the_pest_closest_to_escaping`
## skips it: it builds visuals, which loads the sprite, which makes a targeting test depend
## on a PNG having been rendered. `kind` is set by hand because `uproot_refund` and the
## catalogue lookups read it.
func _idle_nettle() -> Nettle:
	var nettle := Nettle.new()
	nettle.kind = PlantCatalog.NETTLE
	nettle.set_physics_process(false)
	return nettle


## THE acceptance criterion, both halves in one board: a mutated pest in reach loses health
## and a plain one standing on the same spot provably does not.
##
## Both pests are at the same position and the same species, so the ONLY thing that differs
## between them is the mutation — which means a Nettle that simply hit everything, or one
## whose reach was wrong, or one that never fired at all, each fails this differently and
## none of them passes it.
func test_a_nettle_stings_a_mutated_pest_and_provably_not_a_plain_one() -> String:
	var route := PackedVector2Array([Vector2(0, 0), Vector2(400, 0)])
	var nettle: Nettle = _idle_nettle()
	# Well inside RANGE, and the SAME cell for both, so "it stung the closer one" cannot be
	# the explanation for either result.
	var plain: Pest = _still_pest(Pest.APHID, Vector2(60, 0), route)
	var mutated: Pest = _still_pest(Pest.APHID, Vector2(60, 0), route)
	var host: Node2D = _nettle_host([nettle, plain, mutated])
	await _T.instantiate_scene(host)

	var err: String = _T.assert_true(mutated.apply_mutation(Pest.MUTATION_ARMOURED),
		"the armoured mutation actually landed on the pest under test")
	if err == "":
		# Vacuity guard: two pests that both died in the settle frames, or a sting worth
		# nothing, would satisfy a "did not lose health" assertion without asserting a thing.
		err = _T.assert_gt(Nettle.STING_DAMAGE, 0.0, "a sting is worth something to begin with")
	if err == "":
		err = _T.assert_true(is_instance_valid(plain) and is_instance_valid(mutated)
			and plain.is_alive() and mutated.is_alive(),
			"both pests survived the settle frames -- if this fails the answers below are "
				+ "about a set of one")
	if err != "":
		_T.free_ui(host)
		return err

	var plain_before: float = plain.health
	var mutated_before: float = mutated.health
	# One call, one sting: `_act` arms `_cooldown` to a full interval afterwards, so a
	# single delta cannot produce two. The array is a typed local rather than a literal
	# argument -- `_act` takes Array[Pest], and an untyped literal handed straight to a
	# typed-array parameter is a conversion the runtime is entitled to refuse.
	var board_of_two: Array[Pest] = [plain, mutated]
	nettle._act(0.016, board_of_two)

	err = _T.assert_float_eq(plain.health, plain_before, 0.0001,
		"the plain aphid standing in the same cell took nothing at all (%.2f, was %.2f)"
			% [plain.health, plain_before])
	if err == "":
		# Written as `before > after` because the harness ships no assert_lt --
		# tools/run_tests.gd:749 has assert_gt and assert_gte and no counterpart.
		err = _T.assert_gt(mutated_before, mutated.health,
			"and the armoured one beside it did lose health (%.2f, was %.2f)"
				% [mutated.health, mutated_before])
	if err == "":
		# The other direction, and the one that catches "it stung once and then gave up":
		# keep pumping a whole board with nothing but plain pests on it and nothing may
		# ever happen. Sixty intervals is far past any cooldown the plant can bar_arm.
		var only_plain: Pest = _still_pest(Pest.APHID, Vector2(60, 0), route)
		host.add_child(only_plain)
		var lone: Nettle = _idle_nettle()
		host.add_child(lone)
		var board_of_one: Array[Pest] = [only_plain]
		for _i: int in 60:
			lone._act(Nettle.STING_INTERVAL, board_of_one)
		err = _T.assert_float_eq(only_plain.health, only_plain.max_health, 0.0001,
			"and %d intervals of a plain pest sitting in reach still costs it nothing" % 60)
	_T.free_ui(host)
	return err


## The refusal is asked as "does this pest carry ANY mutation", not as two named flags.
##
## The bead that asked for this plant named armoured and winged. A two-flag test is a
## hand-list, and it goes stale in the one direction nothing would catch: the day a fourth
## mutation is added, a plant whose blurb says it stings what the mutations changed silently
## stops covering it. So the rule reads `Pest.mutations`, the set the roll
## actually produced, and this test walks `WaveDirector.MUTATIONS` rather than naming any of
## them — a mutation added to that list without a decision here fails right here.
func test_the_nettle_stings_every_mutation_the_wave_table_can_roll() -> String:
	var route := PackedVector2Array([Vector2(0, 0), Vector2(400, 0)])
	var err: String = _T.assert_gt(WaveDirector.MUTATIONS.size(), 1,
		"there is more than one mutation, or 'every mutation' means nothing")
	if err != "":
		return err
	var pests: Array[Node] = []
	var built: Array[Pest] = []
	for which: StringName in WaveDirector.MUTATIONS:
		var pest: Pest = _still_pest(Pest.APHID, Vector2(60, 0), route)
		pests.append(pest)
		built.append(pest)
	var plain: Pest = _still_pest(Pest.APHID, Vector2(60, 0), route)
	pests.append(plain)
	var host: Node2D = _nettle_host(pests)
	await _T.instantiate_scene(host)

	for i: int in WaveDirector.MUTATIONS.size():
		var which: StringName = WaveDirector.MUTATIONS[i]
		err = _T.assert_true(built[i].apply_mutation(which),
			"the %s mutation lands on its pest" % which)
		if err == "":
			err = _T.assert_true(Nettle.can_sting(built[i]),
				"a %s pest is something the Nettle will fight" % which)
		if err != "":
			_T.free_ui(host)
			return err
	err = _T.assert_false(Nettle.can_sting(plain),
		"and an unmutated pest is not, which is the whole plant")
	if err == "":
		# `stingable` is the filter as `_act` uses it, and it must agree with `can_sting`
		# item by item rather than being a second implementation of the same rule.
		var candidates: Array[Pest] = built.duplicate()
		candidates.append(plain)
		var kept: Array[Pest] = Nettle.stingable(candidates)
		err = _T.assert_eq(kept.size(), built.size(),
			"stingable() keeps exactly the mutated ones out of %d candidates" % candidates.size())
		if err == "":
			err = _T.assert_false(kept.has(plain), "and the plain pest is not among them")
	if err == "":
		# A freed or null entry is refused rather than crashing the game, the same guard
		# Plant._furthest_along_in_range carries and for the reason its header gives.
		err = _T.assert_false(Nettle.can_sting(null), "a null candidate is refused, not dereferenced")
	_T.free_ui(host)
	return err


## The Nettle writes NO new selection rule, and this is what says so.
##
## The bead asked whether a target filter belongs on the plant or on a shared helper, because
## CornCobbler picks through `Plant._furthest_along_in_range` and Dandelion through its own
## `best_target` (game/dandelion.gd:205) — a third rule would be the point at which "how a
## plant chooses" wants to be one named thing. The answer taken is that there are two
## questions here, not one: WHICH pests may be hit (new, `stingable`) and WHICH of those is
## hit first (unchanged, shared). This asserts the second half is literally the cob's own
## function operating on the filtered set, so the composition cannot quietly become a copy.
func test_the_nettle_targets_through_the_same_rule_the_cob_uses() -> String:
	var route := PackedVector2Array([
		Vector2(0, 0), Vector2(30, 0), Vector2(60, 0), Vector2(90, 0), Vector2(120, 0),
	])
	var nettle: Nettle = _idle_nettle()
	var behind: Pest = _still_pest(Pest.APHID, Vector2(30, 0), route)
	var ahead: Pest = _still_pest(Pest.APHID, Vector2(90, 0), route)
	# The pest FURTHEST along and unmutated: the trap answer. A plant that used the shared
	# rule and forgot the filter picks this one, and a plant that filtered but ranked by
	# distance picks `behind`.
	var decoy: Pest = _still_pest(Pest.APHID, Vector2(100, 0), route)
	# Leg 3 rather than 4, for the reason test_combat's own targeting test writes out: at
	# leg 4 a pest is on its final step and frees itself during the settle frames.
	ahead._leg = 3
	decoy._leg = 3
	behind._leg = 1
	var host: Node2D = _nettle_host([nettle, behind, ahead, decoy])
	await _T.instantiate_scene(host)

	var err: String = _T.assert_true(ahead.apply_mutation(Pest.MUTATION_WINGED), "the leader is winged")
	if err == "":
		err = _T.assert_true(behind.apply_mutation(Pest.MUTATION_WINGED), "and so is the straggler")
	if err == "":
		err = _T.assert_true(is_instance_valid(decoy) and decoy.is_alive(),
			"the unmutated decoy is still on the board to be refused")
	if err == "":
		err = _T.assert_gt(ahead.progress(), behind.progress(),
			"the leader really is further along (%.2f vs %.2f)" % [ahead.progress(), behind.progress()])
	if err != "":
		_T.free_ui(host)
		return err

	# The decoy comes FIRST and ties `ahead` on progress, which is what gives it teeth:
	# `_furthest_along_in_range` replaces its best only on a strict `>`, so a Nettle that
	# lost its filter keeps whichever tied pest it saw first. Ordered the other way round the
	# decoy would be silently harmless and this test would pass on a plant that stings
	# everything.
	var candidates: Array[Pest] = [decoy, behind, ahead]
	var chosen: Pest = nettle._furthest_along_in_range(Nettle.stingable(candidates), Nettle.RANGE)
	err = _T.assert_true(chosen == ahead,
		"the Nettle stings the mutated pest closest to escaping, not the nearer one and not "
			+ "the unmutated leader")
	if err == "":
		# And it is the SAME function, not a lookalike: a cob handed the already-filtered
		# set answers identically. If this ever diverges, a third selection rule has been
		# written without anyone saying so.
		var cob := CornCobbler.new()
		host.add_child(cob)
		var cob_pick: Pest = cob._furthest_along_in_range(Nettle.stingable(candidates), Nettle.RANGE)
		err = _T.assert_true(cob_pick == chosen,
			"a CornCobbler handed the same filtered set picks the same pest -- the filter "
				+ "composes with the shared selector rather than replacing it")
	_T.free_ui(host)
	return err


## The blurb has to say the plant is dead weight before the mutations start, and it has to say
## it against the wave the game actually starts them on.
##
## The number cannot be interpolated — `PlantCatalog.PLANTS` is a const Dictionary, so the
## blurb is a literal. This is what stops the literal and `WaveDirector.MUTATION_START_WAVE`
## drifting apart: move the wave and the shop's promise fails here rather than quietly
## becoming a lie about a plant that costs 40 seeds.
func test_the_nettle_blurb_warns_it_is_dead_weight_before_mutations() -> String:
	var blurb: String = PlantCatalog.blurb(PlantCatalog.NETTLE)
	var err: String = _T.assert_gt(blurb.length(), 0, "the Nettle has a blurb at all")
	if err == "":
		err = _T.assert_true(blurb.contains("wave %d" % WaveDirector.MUTATION_START_WAVE),
			"it names wave %d, the wave WaveDirector actually starts mutations on, rather than a number typed into this test: %s"
				% [WaveDirector.MUTATION_START_WAVE, blurb])
	if err == "":
		# The warning itself, not merely the number. A blurb that mentions wave 8 while
		# selling the plant as good from the first frame would pass the line above.
		var warned: bool = false
		for phrase: String in ["Dead weight", "dead weight", "useless", "does nothing"]:
			if blurb.contains(phrase):
				warned = true
				break
		err = _T.assert_true(warned,
			"and says outright that it is worth nothing before then -- a plant that is inert "
				+ "for seven waves and does not advertise it is a trap: %s" % blurb)
	if err == "":
		# The reach the placement preview draws, read off the plant's own constant. A copied
		# number here is a ring that lies about coverage.
		err = _T.assert_float_eq(PlantCatalog.reach(PlantCatalog.NETTLE), Nettle.RANGE, 0.0001,
			"PlantCatalog.reach() answers with Nettle.RANGE and not a hand-copied number")
	if err == "":
		err = _T.assert_true(PlantCatalog.engages(PlantCatalog.NETTLE),
			"the Nettle declares that it can touch a pest, or a lane it covers reads as bare")
	return err


## A specialist must never be a strict upgrade on the generalist it stands beside.
##
## `Nettle.sustained_dps()` is higher than a level-1 cob's — it has to be, or paying four
## times the price for a plant that refuses most targets would be pointless. What must NOT
## happen is that it also wins per seed, because then the right move against a plain wave
## would be to buy Nettles and wait, and the refusal would stop being a cost.
##
## Both sides are computed from the classes rather than quoted: `CornCobbler.single_target_dps`
## already exists for exactly this comparison, and it is measured at a distance a Nettle can
## actually reach, since comparing a 112px plant to a cob's 176px ring at 170px would be
## comparing it to a cob that is out of the argument.
func test_the_nettle_never_out_earns_a_cob_per_seed() -> String:
	var at: float = Nettle.RANGE * 0.5
	var cob_dps: float = CornCobbler.single_target_dps(1, at)
	var err: String = _T.assert_gt(cob_dps, 0.0,
		"a level-1 cob lands something at %.0fpx, or there is nothing to compare against" % at)
	if err == "":
		err = _T.assert_gt(Nettle.sustained_dps(), cob_dps,
			"the Nettle out-damages a cob against what it will actually fight (%.2f vs %.2f)"
				% [Nettle.sustained_dps(), cob_dps])
	if err == "":
		var nettle_per_seed: float = Nettle.sustained_dps() / float(PlantCatalog.cost(PlantCatalog.NETTLE))
		var cob_per_seed: float = cob_dps / float(PlantCatalog.cost(PlantCatalog.CORN))
		err = _T.assert_gt(cob_per_seed, nettle_per_seed,
			("and still loses per seed (%.3f against the cob's %.3f) -- a specialist that "
				+ "wins on both counts makes the refusal free, and free is not a cost")
				% [nettle_per_seed, cob_per_seed])
	if err == "":
		# The weather/neighbour seam, asserted through the plant rather than trusted: a
		# Nettle that hand-multiplied its own interval would still pass every targeting test
		# above and would be silently wiped by the next weather change (game/plant.gd:129).
		var nettle: Nettle = _idle_nettle()
		nettle.fire_interval_scale = 2.0
		nettle.neighbour_interval_scale = 0.75
		err = _T.assert_float_eq(nettle.sting_interval(),
			Plant.composed_interval(Nettle.STING_INTERVAL, 2.0, 0.75), 0.0001,
			"sting_interval() composes the sky and the neighbours through Plant.composed_interval")
		nettle.free()
	return err


## The `_new_plant` arm, and the reason it is worth a test of its own: `Game._new_plant`'s
## default arm returns a CornCobbler, so a catalogue entry with no arm is planted, paid for,
## selected and drawn — as CORN. Nothing errors and nothing in the HUD disagrees.
func test_planting_a_nettle_does_not_silently_plant_corn() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(500)
	# Seeds are not enough: pay_for_plant also refuses a plant the run has not unlocked,
	# and a tier-2 plant is not unlocked at start. Without this the test fails on "not
	# paid for" and reads as a pricing bug rather than a setup one.
	game.bank.unlocked = [PlantCatalog.CORN, PlantCatalog.NETTLE] as Array[StringName]
	var cell: Vector2i = _grass(game)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.NETTLE, cell), "",
		"a Nettle is buyable and placeable on grass")
	if err == "":
		var planted: Plant = game.plant_at(cell)
		err = _T.assert_true(planted != null, "and something is standing in that cell")
		if err == "":
			err = _T.assert_true(planted is Nettle,
				"and it is a Nettle -- _new_plant's default arm hands back a CornCobbler, so "
					+ "a missing match arm plants corn and says nothing: got %s"
					% planted.get_class())
		if err == "":
			err = _T.assert_eq(planted.kind, PlantCatalog.NETTLE,
				"and it knows what it is, which is what the selection panel reads")
	_T.free_ui(game)
	return err


## The page frame's claim is that the playfield is printed on the same stock as the
## notebook — not that it is a similar cream. That is only true for as long as the
## two colours and the hairline weight are READ OFF `GardenTheme.paper_panel()`
## rather than copied beside it, so this asserts the identity rather than a
## resemblance: a second hand-typed cream would pass any "is it cream" assertion
## and would be exactly the drift the frame exists to close.
func test_the_boards_page_frame_is_cut_from_the_notebooks_own_paper() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	var stock: StyleBoxFlat = GardenTheme.paper_panel()
	var edge := game.board.get_node_or_null("PageEdge") as Line2D
	var rule := game.board.get_node_or_null("PageRule") as Line2D
	err = _T.assert_true(edge != null and rule != null,
		"the board built both halves of its page frame")
	if err == "":
		err = _T.assert_true(edge.default_color.is_equal_approx(stock.bg_color),
			"the cream band is the notebook's own page fill, not a second cream: got %s "
				% edge.default_color + "against %s" % stock.bg_color)
	if err == "":
		err = _T.assert_true(rule.default_color.is_equal_approx(stock.border_color),
			"the ruled line is the notebook's own hairline colour: got %s " % rule.default_color
				+ "against %s" % stock.border_color)
	if err == "":
		err = _T.assert_float_eq(rule.width, float(stock.border_width_left), 0.001,
			"and is ruled at the notebook's own hairline weight")
	if err == "":
		err = _T.assert_float_eq(edge.width, Board.PAGE_EDGE_WIDTH, 0.001,
			"the cream band is as wide as the constant that documents what it costs")
	# The order argument in _build_page_frame's header, asserted rather than
	# commented: the frame is over the ground and under the readout painted on it.
	# Swap the two and the pressure hatch on an edge road cell disappears under
	# chrome, which no colour or geometry assertion here would notice.
	if err == "":
		var overlay_index: int = -1
		var frame_index: int = -1
		for child: Node in game.board.get_children():
			if child is LanePressureOverlay:
				overlay_index = child.get_index()
			elif child.name == "PageRule":
				frame_index = child.get_index()
		err = _T.assert_true(frame_index >= 0 and overlay_index > frame_index,
			"the pressure hatch is painted after the frame, so the frame can only dim "
				+ "ground: frame at %d, overlay at %d" % [frame_index, overlay_index])
	_T.free_ui(game)
	return err


## The two questions a decorative border has to answer before it is allowed near a
## playfield: does it close, and does it stay out of the way.
##
## Both are asked of the pure function rather than of a rendered frame, which is
## the only way "the loop has no notch at its seam" is assertable at all — a 1px
## gap where a `Line2D` meets itself is invisible in a screenshot and permanent.
func test_the_page_frames_edge_closes_and_keeps_off_the_playable_interior() -> String:
	var board_px := Vector2(float(Board.COLS * Board.CELL), float(Board.ROWS * Board.CELL))
	var inset: float = Board.PAGE_EDGE_WIDTH * 0.5
	var points: PackedVector2Array = Board.page_edge_points(board_px, inset)
	var err: String = _T.assert_gt(points.size(), 4, "the edge is sampled, not a bare rectangle")
	if err == "":
		err = _T.assert_true(points[0].is_equal_approx(points[points.size() - 1]),
			"the loop closes on itself -- Line2D has no closed flag, so the last point has "
				+ "to repeat the first or the seam leaves a notch: got %s and %s"
				% [points[0], points[points.size() - 1]])
	if err != "":
		return err

	# Every point must sit within (inset + wobble) of one of the four edges. That is
	# the claim that bounds what the frame costs the player: PAGE_EDGE_WIDTH + BORDER
	# = 9px of a 64px cell, on the outermost row and column only.
	var reach: float = inset + Board.PAGE_WOBBLE_PX + 0.001
	var worst: float = 0.0
	var worst_at := Vector2.ZERO
	for point: Vector2 in points:
		var to_edge: float = minf(
			minf(point.x, board_px.x - point.x), minf(point.y, board_px.y - point.y))
		if to_edge > worst:
			worst = to_edge
			worst_at = point
	err = _T.assert_true(worst <= reach,
		"no sampled point wanders further than %.2fpx into the field; the worst is %s at %.2fpx"
			% [reach, worst_at, worst])
	if err == "":
		# And the other direction: a wobble that swung further out than the board is
		# wide would be clipped on the left and bottom and hidden under the HUD on
		# the top and right, which is a frame that is silently only half drawn.
		var outside: int = 0
		for point: Vector2 in points:
			var depth: float = minf(
				minf(point.x, board_px.x - point.x), minf(point.y, board_px.y - point.y))
			if depth < -Board.PAGE_WOBBLE_PX - 0.001:
				outside += 1
		err = _T.assert_eq(outside, 0,
			"and none of it wanders off the board by more than the wobble it is allowed")
	if err == "":
		# The seam is continuous because the cycle count is a whole number, not
		# because the perimeter happened to divide. Assert the property, so a future
		# fractional cycle count fails here rather than at a screenshot.
		err = _T.assert_float_eq(Board.page_wobble(0.0), Board.page_wobble(1.0), 0.0001,
			"the wobble is periodic over exactly one circuit")
	if err == "":
		var over: int = 0
		for i: int in 41:
			if absf(Board.page_wobble(float(i) / 40.0)) > Board.PAGE_WOBBLE_PX + 0.0001:
				over += 1
		err = _T.assert_eq(over, 0,
			"and never wanders further than PAGE_WOBBLE_PX in either direction")
	return err


## A mark drawn in the lawn's own hue is invisible, no gate in this project compares
## a mark against the ground under it, and it has already happened once. This is that
## comparison, and the half that matters is the last assertion: a check nobody has
## watched fail is a check nobody knows the shape of.
func test_nothing_the_board_paints_over_it_is_the_lawns_own_hue() -> String:
	var stock: StyleBoxFlat = GardenTheme.paper_panel()
	# Measured in greyscale on purpose -- OVERLAY_GRAMMAR.md's one rule with teeth
	# is that a cue must survive its colour being discarded, and a mark that only
	# separates from the grass by hue does not.
	var err: String = _T.assert_true(GardenTheme.reads_on_ground(stock.bg_color),
		"the page frame's cream separates from both grounds: %.3f from grass, %.3f from dirt"
			% [GardenTheme.separation(stock.bg_color, GardenTheme.GROUND_GRASS),
				GardenTheme.separation(stock.bg_color, GardenTheme.GROUND_DIRT)])
	if err == "":
		err = _T.assert_true(GardenTheme.reads_on_ground(stock.border_color),
			"and so does its ruled ink line: %.3f from grass, %.3f from dirt"
				% [GardenTheme.separation(stock.border_color, GardenTheme.GROUND_GRASS),
					GardenTheme.separation(stock.border_color, GardenTheme.GROUND_DIRT)])
	if err == "":
		# The cue this project already paints on the road, so the gate is measured
		# against something that shipped rather than only against what this cycle
		# added. Opaque only: reads_on_ground says nothing about alpha and says so.
		err = _T.assert_true(GardenTheme.reads_on_ground(GardenTheme.DANGER),
			"and so does the one warning red the road is hatched in: %.3f from grass"
				% GardenTheme.separation(GardenTheme.DANGER, GardenTheme.GROUND_GRASS))
	if err == "":
		# The proof the gate can fail. GROUND_GRASS aliases LEAF because the kit's
		# grass IS #2ECC71, so a plant drawn in LEAF -- which is exactly what shipped
		# once -- separates from the lawn by nothing at all.
		err = _T.assert_float_eq(
			GardenTheme.separation(GardenTheme.LEAF, GardenTheme.GROUND_GRASS), 0.0, 0.001,
			"LEAF is the lawn's own hue, to the last decimal the kit was sampled at")
	if err == "":
		err = _T.assert_false(GardenTheme.reads_on_ground(GardenTheme.LEAF),
			"so the gate rejects a mark drawn in LEAF -- the defect it exists for, and the "
				+ "one it would be worthless without rejecting")
	if err == "":
		err = _T.assert_gt(GardenTheme.GROUND_SEPARATION_MIN, 0.0,
			"and the floor it rejects against is a real number, not a disabled check")
	return err


# -- message row: is any caller stacking duplicates into the queue? ------------
#
# The audit these belong to is `docs/message_trigger_audit.md`: all 17
# `show_message()` call sites under `game/`, classified EDGE vs LEVEL. The reading
# concluded that exactly one is level-triggered with a condition that persists
# (`_maybe_teach_upgrading`, already guarded by `Hud.row_is_quiet`). These two tests
# are what stop that from being only a reading.
#
# `Hud.messages_refused` counts ONLY the terminal symptom -- a message arriving at a
# queue already holding MESSAGE_QUEUE_MAX entries whose lowest priority ties or beats
# it. That is precisely the fourth copy of a stacking one-shot. It does NOT count an
# ordinary queued line, so a non-zero reading is evidence of stacking rather than of
# a merely busy row.
#
# WHY BOTH TESTS AND NOT JUST THE FIRST. A zero from a counter can mean "nothing
# stacked" or "this counter never moves in a headless suite", and those are different
# facts. The second test drives the counter deliberately BEFORE the first one's zero
# is worth anything -- the `scope-vs-claim` rule about a denominator that can be zero
# for more than one reason.


## The ambient reading: a Game driven through a realistic run, and both loss counters
## off the end of it.
##
## Frames are advanced by calling `_process` with an explicit delta, the pattern the
## uproot tests above already use. That is load-bearing rather than stylistic: with no
## frames pumped, `_message_left` never decays, every line after the first queues, and
## the counters would report a stacking defect that is really just a stopped clock.
func test_a_realistic_run_refuses_no_messages_and_evicts_none() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null and game.hud != null,
		"the run has a HUD, without which show_message is never reached at all")
	if err != "":
		_T.free_ui(game)
		return err
	# The opening hint posted from _ready() is already on the row. Let it expire, so
	# what follows is measured against a quiet row rather than against startup.
	game.hud._process(20.0)

	# `RunConfig.earned_milestones` is autoload state loaded from the real save BEFORE
	# setup() redirected save_path, so whether the upgrade hint fires at all otherwise
	# depends on the developer's own progress and on which tests ran first. Pinned here
	# so this run is the same run every time; restored at the end.
	var stashed_hint: bool = RunConfig.has_milestone(RunConfig.HINT_UPGRADE_EXISTS)
	RunConfig.earned_milestones.erase(RunConfig.HINT_UPGRADE_EXISTS)

	game.bank.add_seeds(500)
	var planted: int = 0
	for i: int in range(6):
		var cell: Vector2i = _grass(game)
		if cell == Vector2i(-1, -1):
			break
		if game.place_plant(PlantCatalog.CORN, cell) == "":
			planted += 1
		# A second and a half of row time between beats, the way a player's clicks are
		# spaced -- not zero, which would be a stopped clock, and not minutes.
		game.hud._process(1.5)
	err = _T.assert_gt(planted, 0, "the run actually planted something to narrate")

	if err == "":
		# An upgrade, a refused upgrade, an armed uproot and its cancellation -- four
		# more call sites, two of them refusals.
		var occupied: Vector2i = _grass_with_plant(game)
		if occupied != Vector2i(-1, -1):
			game._select(game.plant_at(occupied))
			# The REFUSAL first and the success second, deliberately. Upgrading first
			# could take the plant to the top of its ladder, and the second call would
			# then return "already fully grown" -- a different branch, posting no
			# message at all, and the refusal call site would go unreached while this
			# test still passed.
			#
			# Emptied with add_seeds, NOT bank.set_seed(0): that one fixes the packet
			# RNG and leaves the balance untouched, so the upgrade would quietly
			# succeed and this beat would exercise nothing.
			var stashed_seeds: int = game.bank.seeds
			game.bank.add_seeds(-stashed_seeds, false)
			var denied: String = game.upgrade_selected()
			game.hud._process(4.0)
			err = _T.assert_eq(denied, "not enough seeds",
				"the broke-player refusal at game.gd:1460 was actually reached")
			if err == "":
				game.bank.add_seeds(stashed_seeds + 200)
				var bought: String = game.upgrade_selected()
				game.hud._process(4.0)
				err = _T.assert_eq(bought, "", "and the success line at game.gd:1470 too")
			if err == "":
				var armed: String = game.arm_uproot()
				game.hud._process(4.0)
				err = _T.assert_eq(armed, "confirm needed",
					"and the uproot prompt at game.gd:1534, which then expires below")
			if err == "":
				# The confirm window expires unclicked, which is the "Uproot
				# cancelled." post at game.gd:1582 -- the other per-frame call site
				# that is edge-triggered only because _disarm_uproot latches it.
				game._process(Game.UPROOT_CONFIRM_SECONDS + 0.1)
				game.hud._process(4.0)
				err = _T.assert_false(game.uproot_armed(),
					"and the window closed rather than staying armed")

	if err == "":
		# Waves, which is where _refresh runs hardest: every spawn, death and clear
		# funnels through it, and a level-triggered caller would stack here or nowhere.
		for wave: int in range(3):
			game.start_next_wave()
			for tick: int in range(40):
				game._process(0.25)
				game.hud._process(0.25)
			for pest: Node in game.get_tree().get_nodes_in_group("pests"):
				var p := pest as Pest
				if p != null and is_instance_valid(p):
					p.queue_free()
			for tick: int in range(20):
				game._process(0.25)
				game.hud._process(0.25)

	if err == "":
		err = _T.assert_eq(game.hud.messages_refused, 0,
			("no line was refused across the whole run -- refused=%d evicted=%d "
				+ "preempted=%d, over 3 wave(s) with %d plant(s) placed. A non-zero "
				+ "refusal here is a caller stacking copies into a full queue.")
				% [game.hud.messages_refused, game.hud.messages_evicted,
					game.hud.messages_preempted, planted])
	if err == "":
		err = _T.assert_eq(game.hud.messages_evicted, 0,
			"and nothing already waiting was pushed out to make room: evicted=%d"
				% game.hud.messages_evicted)
	if stashed_hint:
		RunConfig.earned_milestones[RunConfig.HINT_UPGRADE_EXISTS] = true
	else:
		RunConfig.earned_milestones.erase(RunConfig.HINT_UPGRADE_EXISTS)
	_T.free_ui(game)
	return err


func _grass_with_plant(game: Game) -> Vector2i:
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var cell := Vector2i(x, y)
			if game.plant_at(cell) != null:
				return cell
	return Vector2i(-1, -1)


## The control for the test above, and the assertion that `row_is_quiet` does the job
## it was added for.
##
## Three parts, in order, because each one is worthless without the one before it:
##   1. the counter CAN move -- post past MESSAGE_QUEUE_MAX at a busy row by hand and
##      watch `messages_refused` rise. A zero above means nothing without this.
##   2. an UNGUARDED level-triggered caller stacks -- the shape the audit is hunting,
##      reproduced directly, so "stacking" is a thing this suite has actually seen.
##   3. the guarded one does NOT -- `_refresh` called repeatedly with the hint's
##      condition true and the row busy adds nothing to the queue and spends no hint.
## A damaged plant beside a Salve Aloe gains health as the game runs
## (plant-tower-defense-ibvb).
##
## Drives the real `Game._process` path rather than calling `heal()` directly, because the
## thing that could silently be wrong is the WIRING — `_apply_aloe_healing` never reached,
## or reaching only the Aloe itself. The pure halves (`Aloe.reaches`, `Aloe.heal_for`) are
## asserted in `test_combat.gd`; this is the one that needs a whole board.
func test_a_damaged_plant_beside_an_aloe_gains_health_as_the_game_runs() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.seeds = 500
	game.bank.unlocked.append(PlantCatalog.ALOE)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, Vector2i(3, 2)), "",
		"a cob goes down")
	if err == "":
		err = _T.assert_eq(game.place_plant(PlantCatalog.ALOE, Vector2i(4, 2)), "",
			"and an Aloe beside it")
	var cob: Plant = null
	if err == "":
		cob = game._plants.get(Vector2i(3, 2)) as Plant
		err = _T.assert_true(cob != null, "the cob is on the board")
	if err == "":
		cob.health = 10.0
		err = _T.assert_true(cob.health < Plant.MAX_HEALTH, "and it is damaged to begin with")
	if err == "":
		game._process(1.0)
		err = _T.assert_float_eq(cob.health, 10.0 + Aloe.HEAL_PER_SECOND, 0.01,
			"one second of game time mends it by exactly HEAL_PER_SECOND, got %.2f"
				% cob.health)
	if err == "":
		# The ceiling. Nothing over-heals, however long the garden sits quiet.
		for _i: int in range(60):
			game._process(1.0)
		err = _T.assert_float_eq(cob.health, Plant.MAX_HEALTH, 0.01,
			"and it stops at MAX_HEALTH rather than climbing past it, got %.2f" % cob.health)
	_T.free_ui(game)
	return err


## A click lands on the cell it is over, wherever the board has been centred.
##
## The playfield is centred in the space the HUD leaves it, so `_entities.position` is no
## longer `(0, BAR_HEIGHT)` on any window that is not the design size. `_click_at` maps a
## SCREEN position to a cell, and its guard used to compare `screen_pos.x` against
## `board.board_size().x` — an absolute coordinate against a board-local width. Correct for
## exactly as long as the board started at x = 0.
##
## THE CASE THAT CAN FAIL is the rightmost column at a non-zero offset: with the board at
## x = 117 the old guard rejected every click past screen x 896, which is the last two
## columns, while the board drew them perfectly. A screenshot cannot show a strip that
## silently stops responding, and asserting only the centre cell would pass on both.
func test_a_click_lands_on_its_cell_wherever_the_board_is_centred() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.seeds = 500
	var offset := Vector2(117.0, 72.0)
	game._entities.position = offset

	# The last column the board has, which is the one the old guard ate.
	var target := Vector2i(Board.COLS - 1, Board.ROWS - 1)
	var screen: Vector2 = offset + game.board.cell_to_world(target)
	# Walk left along the bottom row to the first plantable cell that is STILL past the old
	# guard's threshold. Derived rather than hardcoded: the road's shape decides which cells
	# are plantable and it has been reshaped before.
	while target.x > 0 and not game.would_plant_at(target):
		target.x -= 1
	screen = offset + game.board.cell_to_world(target)

	var err: String = _T.assert_true(screen.x > game.board.board_size().x,
		("the probe really is past the old guard's threshold (%.0f > %.0f), or this test "
			+ "passes without exercising the bug at all") % [screen.x, game.board.board_size().x])
	if err == "":
		err = _T.assert_true(game.plant_at(target) == null, "the target cell starts empty")
	if err == "":
		# The real door: _click_at takes a SCREEN position and is where the guard lives.
		# Asserting world_to_cell alone would pass with the guard still broken.
		game.selected_plant = PlantCatalog.CORN
		game._click_at(screen)
		err = _T.assert_true(game.plant_at(target) != null,
			("a click at screen %s plants on cell %s — with the old absolute-x guard this "
				+ "returned early and nothing happened") % [screen, target])
	if err == "":
		# The left gutter is dead space, not column -2. `world_to_cell` answers honestly
		# and `is_inside` is what refuses it — asserted so a future guard cannot start
		# treating the gutter as playable.
		var gutter: Vector2 = Vector2(10.0, offset.y + 10.0)
		var gutter_cell: Vector2i = game.board.world_to_cell(gutter - game._entities.position)
		err = _T.assert_false(game.board.is_inside(gutter_cell),
			"a click in the left gutter is off the board, got cell %s" % gutter_cell)
	if err == "":
		# And the design size is unchanged: no offset, same answers as before this landed.
		game._entities.position = Vector2(0.0, Hud.BAR_HEIGHT)
		var mid := Vector2i(3, 2)
		var at: Vector2 = Vector2(0.0, Hud.BAR_HEIGHT) + game.board.cell_to_world(mid)
		err = _T.assert_eq(game.board.world_to_cell(at - game._entities.position), mid,
			"and the un-centred board still maps exactly as it always did")
	_T.free_ui(game)
	return err


func test_row_is_quiet_is_what_stops_a_level_triggered_caller_stacking() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null and game.hud != null, "the run has a HUD")
	if err != "":
		_T.free_ui(game)
		return err
	var hud: Hud = game.hud
	hud._process(20.0)

	# 1. The instrument works. A long line holds the row, then MESSAGE_QUEUE_MAX + 2
	# arrivals at equal priority: three queue, the rest tie and are refused.
	hud.show_message("holding the row", 30.0)
	for i: int in range(Hud.MESSAGE_QUEUE_MAX + 2):
		hud.show_message("arrival %d" % i, 3.0)
	err = _T.assert_eq(hud.pending_messages(), Hud.MESSAGE_QUEUE_MAX,
		"the queue filled to its maximum of %d" % Hud.MESSAGE_QUEUE_MAX)
	if err == "":
		err = _T.assert_eq(hud.messages_refused, 2,
			"and the 2 that did not fit were REFUSED and counted -- which is the proof "
				+ "that a zero from this counter elsewhere is a result and not a dead gauge")

	# 2. and 3. share a board: one upgradable plant the player can afford.
	var stacked: int = -1
	var guarded: int = -1
	var hint_was_spent: bool = false
	var stashed_hint: bool = RunConfig.has_milestone(RunConfig.HINT_UPGRADE_EXISTS)
	if err == "":
		RunConfig.earned_milestones.erase(RunConfig.HINT_UPGRADE_EXISTS)
		game.bank.add_seeds(500)
		var cell: Vector2i = _grass(game)
		err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "",
			"a corn cobbler is in the ground for the hint to talk about")
		if err == "":
			var plant: Plant = game.plant_at(cell)
			err = _T.assert_true(plant != null and plant.can_upgrade(),
				"and it has a rung left to climb, so the hint's condition is reachable")
		if err == "":
			err = _T.assert_true(Game.cheapest_upgrade(game._plants.values()) != null,
				"and the hint's own finder agrees there is something to upgrade")

	if err == "":
		# 2. UNGUARDED: what _maybe_teach_upgrading did before row_is_quiet existed.
		# The row is deliberately busy and the condition is deliberately still true,
		# which is the whole definition of level-triggered.
		# Drain to a genuinely quiet row FIRST. Posting a holder while the previous
		# one is still up would queue the holder instead of taking the row, and every
		# count after it would be off by that one entry.
		hud._message_queue.clear()
		hud._process(60.0)
		hud.messages_refused = 0
		hud.show_message("holding the row again", 30.0)
		for i: int in range(6):
			hud.show_message(Hud.upgrade_tip("Corn Cobbler", 10))
		stacked = hud.pending_messages()
		err = _T.assert_gt(stacked, 1,
			("an UNGUARDED level-triggered caller stacks: %d copies of one one-shot "
				+ "sat in the queue at once, and %d more were refused outright")
				% [stacked, hud.messages_refused])

	if err == "":
		# 3. GUARDED: the real funnel, same busy row, same persisting condition.
		hud._message_queue.clear()
		hud._process(60.0)
		hud.messages_refused = 0
		hud.show_message("holding the row a third time", 30.0)
		err = _T.assert_false(hud.row_is_quiet(),
			"the row is busy, which is the only state in which this test says anything")
		if err == "":
			for i: int in range(6):
				game._refresh()
			guarded = hud.pending_messages()
			hint_was_spent = RunConfig.has_milestone(RunConfig.HINT_UPGRADE_EXISTS)
			err = _T.assert_eq(guarded, 0,
				("but the GUARDED caller queued nothing across 6 refreshes with the "
					+ "condition still true -- %d queued, against %d for the unguarded "
					+ "shape on the same board") % [guarded, stacked])
		if err == "":
			err = _T.assert_eq(hud.messages_refused, 0, "and refused nothing either")
		if err == "":
			err = _T.assert_false(hint_was_spent,
				"and the one-shot is still OWED rather than burnt on a line the player "
					+ "never read -- which is the point of asking before offering")

	if stashed_hint:
		RunConfig.earned_milestones[RunConfig.HINT_UPGRADE_EXISTS] = true
	else:
		RunConfig.earned_milestones.erase(RunConfig.HINT_UPGRADE_EXISTS)
	_T.free_ui(game)
	return err


# -- The redundancy cue is patch-only (plant-tower-defense-y1gh) --------------


## What the rename in plant-tower-defense-y1gh asserts rather than merely
## documents: shows_redundant_patch_coverage() fires for a PATCH and for nothing
## else the catalog offers.
##
## test_a_second_patch_over_the_same_road_is_worth_exactly_nothing already checks
## the Corn Cobbler case by hand. Corn is the plant a reader thinks of, which is
## exactly why checking only it is thin — previewing_non_stacking_patch() falls
## back to comparing `reach` against StickySundew.SAP_RADIUS whenever no plant_id
## is set, so any FUTURE plant sharing that reach would silently inherit a warning
## built for dew. Sweeping PlantCatalog.ids() covers a plant on the day it is
## added to the catalog with no edit here: `derive-the-list` over the source of
## truth instead of a hand-typed set of "the ones that matter".
##
## Why the answer must be no for a gun: stacking is the OPPOSITE of redundant for
## a cob. Cycle 54 measured a five-cob garden reaching all 32 road cells letting a
## pest through where the recorded seven cobs over that same road do not (commit
## a00ada2, test_combat.gd's _whole_road_garden). A cue that fired on cobs would
## be steering the player into the losing garden.
func test_only_a_patch_is_ever_marked_redundant_over_covered_road() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var preview: PlacementPreview = _preview(game)
	var err: String = _T.assert_true(preview != null, "the game built a placement preview")
	if err != "":
		_T.free_ui(game)
		return err
	# The same redundant ground the hand-written tests above stand on: a patch on
	# (2, 0) already covers every road cell a patch on (2, 2) would reach.
	var patch: StickySundew = _sundew_at(game, Vector2i(2, 0))
	preview.placeable = true
	preview.at_risk = false
	preview.position = game.board.cell_to_world(Vector2i(2, 2))
	preview.plant_id = PlantCatalog.SUNDEW
	preview.reach = PlantCatalog.reach(PlantCatalog.SUNDEW)
	# Positive control FIRST, and it is load-bearing: without it every assert_false
	# below would pass just as happily against a cue that had stopped firing for
	# anything at all.
	err = _T.assert_true(patch != null and preview.shows_redundant_patch_coverage(),
		"a Sundew on (2, 2) IS marked, so the sweep below is reading a live cue")
	var swept: int = 0
	for id: StringName in PlantCatalog.ids():
		if err != "":
			break
		if id == PlantCatalog.SUNDEW:
			continue
		preview.plant_id = id
		preview.reach = PlantCatalog.reach(id)
		swept += 1
		err = _T.assert_false(preview.shows_redundant_patch_coverage(),
			("%s is not a patch, so it is never marked redundant -- not even on the "
				+ "one cell that IS redundant for dew, because a second gun over "
				+ "covered road is depth and depth is what wins the wave") % id)
	if err == "":
		err = _T.assert_gt(swept, 1,
			"and the catalog offered more than one non-patch plant to sweep")
	_T.free_ui(game)
	return err


# =============================================================================
# BEGIN plant flourish timings -- plant-tower-defense-w71c
#
# Two checks, and deliberately neither of them names a call site. The first says
# every plant tween's duration is a NAME; the second says those names form
# out-and-back pairs with the relationship two class headers already claim in
# prose. Twenty-four per-call-site assertions would all go stale together the
# first time a gesture is retimed, which is why the issue asked for the pair.
#
# Both derive their inputs. The family is `Plant` plus whatever extends it, read
# off DirAccess; the pairs are whatever `*_OUT_SECONDS` / `*_BACK_SECONDS` the
# family declares. A tenth plant, or a seventh pair, joins the sweep by existing
# rather than by someone remembering to add it here -- see
# `.claude/skills/derive-the-list/SKILL.md`, whose whole point is that the bug is
# never a wrong entry, it is a missing one the test cannot see past the end of.
#
# Nothing here instantiates anything. These are pure reads of source text and of
# constants, so there is no Control to pump frames for and no tree-global group
# to be handed another test's node out of.
# =============================================================================


## Line-comment lines dropped, so a header that talks ABOUT a tween is never
## scanned as one. Full-line comments only, which is all this corpus has -- a `#`
## inside a string on a tween line would be a false negative and there are none.
func _lines_without_comments(text: String) -> String:
	var kept: PackedStringArray = []
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		kept.append(line)
	return "\n".join(kept)


## {res:// path -> source text} for `Plant` and every game script that extends it.
func _plant_family_sources() -> Dictionary:
	var out: Dictionary = {}
	var dir := DirAccess.open("res://game")
	if dir == null:
		return out
	var subclass := RegEx.create_from_string("(?m)^extends\\s+Plant\\s*$")
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.ends_with(".gd"):
			var path: String = "res://game".path_join(entry)
			var text: String = FileAccess.get_file_as_string(path)
			if entry == "plant.gd" or subclass.search(text) != null:
				out[path] = text
		entry = dir.get_next()
	dir.list_dir_end()
	return out


## The duration argument of every `tween_property` / `tween_method` /
## `tween_interval` in one script, as the raw source token.
##
## Walks brackets from each call's opening paren and takes what follows the last
## comma at depth 1, so `Vector2(1.12, 1.12), 0.12` yields `0.12` and not `1.12)`.
## That is the granularity trap `derive-the-list` names: the thing being counted
## can appear more than once in a statement, so this counts brackets rather than
## commas on a line. Quoted regions are stepped over so a `"scale"` cannot
## unbalance the walk, and the walk crosses newlines so a call split over several
## lines is not silently missed -- `game/hud.gd:1867` is one of those, outside this
## family today but exactly the member a line-oriented matcher would step over.
##
## All three verbs take their duration LAST (`tween_property(o, p, to, secs)`,
## `tween_method(c, from, to, secs)`, `tween_interval(secs)`), and chained setters
## like `.set_delay()` sit outside the matched paren, so the last top-level
## argument is the duration in every case.
func _tween_durations(text: String) -> Array[String]:
	var out: Array[String] = []
	var code: String = _lines_without_comments(text)
	var finder := RegEx.create_from_string("tween_(?:property|method|interval)\\s*\\(")
	for m: RegExMatch in finder.search_all(code):
		var i: int = m.get_end() - 1
		var depth: int = 0
		var last_comma: int = -1
		var quote: String = ""
		while i < code.length():
			var c: String = code[i]
			if quote != "":
				if c == "\\":
					i += 2
					continue
				if c == quote:
					quote = ""
			elif c == "\"" or c == "'":
				quote = c
			elif c == "(" or c == "[" or c == "{":
				depth += 1
			elif c == ")" or c == "]" or c == "}":
				depth -= 1
				if depth == 0:
					break
			elif c == "," and depth == 1:
				last_comma = i
			i += 1
		if i >= code.length():
			continue
		var arg_start: int = m.get_end() if last_comma < 0 else last_comma + 1
		out.append(code.substr(arg_start, i - arg_start).strip_edges())
	return out


## Every plant tween's duration is a name, not a number.
##
## The other half of the acceptance for plant-tower-defense-w71c, and the half that
## has to keep holding: naming eleven -- twenty-one, as it turned out -- literals
## once is a commit, and this is what stops the twenty-second arriving. Two
## denominators guard it, because a scan that found no files and a scan that found
## no tweens both report exactly what a clean codebase reports.
func test_no_plant_tween_carries_a_bare_duration_literal() -> String:
	var sources: Dictionary = _plant_family_sources()
	var err: String = _T.assert_gte(sources.size(), 9,
		("the plant family scan found %d scripts -- Plant plus its eight subclasses "
			+ "is the floor, and a scan that found fewer is measuring nothing")
			% sources.size())
	if err != "":
		return err

	var number := RegEx.create_from_string("^[+-]?(?:[0-9]+\\.?[0-9]*|\\.[0-9]+)$")
	var checked: int = 0
	var bare: PackedStringArray = []
	for path: String in sources:
		for token: String in _tween_durations(sources[path]):
			checked += 1
			if number.search(token) != null:
				bare.append("%s -> %s" % [path, token])

	err = _T.assert_gte(checked, 20,
		("the sweep examined %d tween durations across the family; there were 24 when "
			+ "this was written. A matcher that quietly stopped matching reports the "
			+ "same clean result as a codebase with nothing left to find")
			% checked)
	if err != "":
		return err
	return _T.assert_eq(", ".join(bare), "",
		("a plant tween is still carrying a bare duration literal, which is the one "
			+ "kind of constant no gate in this project can check the VALUE of -- "
			+ "nothing headless renders a frame, so a wrong duration is invisible "
			+ "everywhere except a pair of eyes on the running game: %s")
			% ", ".join(bare))


## {prefix -> {"out": float, "back": float}} for one script's text.
##
## Pairing is per-file because a gesture's two halves are declared together in the
## class that plays it. That is also what keeps the family's three colliding bare
## const names (RANGE, REACH, RING_WIDTH -- none of them durations) from ever being
## resolved against the wrong class here.
func _out_and_back_pairs(text: String) -> Dictionary:
	var out: Dictionary = {}
	var finder := RegEx.create_from_string(
		"(?m)^const\\s+([A-Z][A-Z0-9_]*)_(OUT|BACK)_SECONDS\\s*:\\s*float\\s*=\\s*([0-9.]+)\\s*$")
	for m: RegExMatch in finder.search_all(_lines_without_comments(text)):
		var prefix: String = m.get_string(1)
		if not out.has(prefix):
			out[prefix] = {}
		out[prefix][m.get_string(2).to_lower()] = m.get_string(3).to_float()
	return out


## The out-and-back pairs, and the claim two class headers make about them.
##
## `CornCobbler._upgrade_flourish`'s header says its gesture is `_recoil`'s "pushed
## further and held longer"; `ChompFlower._on_upgraded`'s says the same of its own
## `_bite`. Both were prose, and prose does not fail. This is the assertion form:
## the flourish tier out-lasts the twitch tier on BOTH halves.
##
## Around it, the sweep every declared pair has to survive -- both halves present,
## both inside the family's band, and the return slower than the strike. The
## planting pop is the single deliberate exception to that last rule and is
## asserted AS an exception rather than excluded from the sweep, so bringing it
## into line with the other five has to be a decision someone makes here.
func test_the_flourish_tier_is_pushed_further_and_held_longer_than_the_twitch() -> String:
	var sources: Dictionary = _plant_family_sources()
	var pairs: Dictionary = {}
	for path: String in sources:
		var found: Dictionary = _out_and_back_pairs(sources[path])
		for prefix: String in found:
			pairs[prefix] = found[prefix]

	var err: String = _T.assert_gte(pairs.size(), 6,
		("the family declares %d out-and-back pairs; there were six when this was "
			+ "written -- TWITCH and FLOURISH on Plant, PLANTING_POP on Plant, "
			+ "BITE_LUNGE and BITE_SQUASH on ChompFlower, PUFF on Dandelion. A sweep "
			+ "that found fewer is not reading the constants it claims to")
			% pairs.size())
	if err != "":
		return err

	for prefix: String in pairs:
		var pair: Dictionary = pairs[prefix]
		err = _T.assert_eq(pair.size(), 2,
			("%s_* is half a pair -- it declares %s and nothing else. Both directions "
				+ "or neither: a gesture with a named strike and a bare return is the "
				+ "exact state this pass existed to remove")
				% [prefix, str(pair.keys())])
		if err == "":
			for half: String in pair:
				var value: float = pair[half]
				err = _T.assert_true(value >= 0.04 and value <= 0.20,
					("%s_%s_SECONDS is %.3f, outside the 0.04..0.20 band every plant "
						+ "flourish sits in. A rename that pointed a bite at "
						+ "Aloe.PULSE_SECONDS (3.4) passes every other check in this "
						+ "file and freezes the flower for three and a half seconds")
						% [prefix, half.to_upper(), value])
				if err != "":
					break
		if err == "" and prefix == "PLANTING_POP":
			err = _T.assert_true(pair["out"] > pair["back"],
				("PLANTING_POP is the family's one arrival rather than a strike: the "
					+ "sprite starts at 0.4 and has to be SEEN growing, so its out "
					+ "(%.2f) is deliberately longer than its back (%.2f). Asserted on "
					+ "purpose, so that bringing it into line with the other five is a "
					+ "decision rather than a number that drifted")
					% [pair["out"], pair["back"]])
		elif err == "":
			err = _T.assert_true(pair["back"] > pair["out"],
				("%s snaps out in %.2f and eases home in %.2f -- a return no slower "
					+ "than its strike reads as a rewind, not a recovery")
					% [prefix, pair["out"], pair["back"]])
		if err != "":
			return err

	# Read through the class rather than out of the scan for this last part: it is
	# the pair the rest of the family BORROWS, so it has to still be there after the
	# file is parsed and not merely present in its text. `Nettle._sting_twitch` and
	# `CornCobbler._recoil` are both on TWITCH_*; `CornCobbler._upgrade_flourish`,
	# `ChompFlower._on_upgraded` and the Sunflower's payout pop are all on FLOURISH_*.
	err = _T.assert_gt(Plant.FLOURISH_OUT_SECONDS, Plant.TWITCH_OUT_SECONDS,
		("an upgrade's snap (%.2f) is wider than a shot's (%.2f) -- 'pushed further "
			+ "and held longer', which CornCobbler._upgrade_flourish's header has "
			+ "claimed in prose for cycles with nothing able to fail on it")
			% [Plant.FLOURISH_OUT_SECONDS, Plant.TWITCH_OUT_SECONDS])
	if err == "":
		err = _T.assert_gt(Plant.FLOURISH_BACK_SECONDS, Plant.TWITCH_BACK_SECONDS,
			("and held longer coming home too -- %.2f against %.2f. Both halves, "
				+ "because a tier that was wider but quicker would be a flinch "
				+ "rather than a flourish")
				% [Plant.FLOURISH_BACK_SECONDS, Plant.TWITCH_BACK_SECONDS])
	return err

# END plant flourish timings -- plant-tower-defense-w71c
# =============================================================================


# =============================================================================
# BEGIN the lawn stands on the ground at any viewport height
#
# WHY THIS TEST EXISTS, written out because the defect it guards is invisible to
# every other check in this project.
#
# A player reported the title screen's bugs "no longer aligned" on a phone. They
# were not misaligned with each other: the whole lawn had come unstuck from the
# world. `TitleBackdrop` painted its grass at `live_height * HORIZON` while
# `TitleScreen.PLANT_BASE_Y` (514) and `PEST_BASE_Y` (606) are absolute design
# pixels, so the two agreed only at the design height of 648. On the reported
# 1152x2048 viewport the grass line sat at 1515 and the plants at 514 — the lawn
# a thousand pixels up in the sky.
#
# Nothing caught it, and the reasons are worth naming so this test is not the
# only thing standing there:
#
#   * `findings` / `validate-ui` measure Controls. The lawn is Sprite2D, and
#     _build_scenery's own header says that is deliberate — "a Node2D is simply
#     not what those checks look at, which is the honest way to say this is not
#     UI". Correct reasoning, and the hole this went through.
#   * every test and capture in this project runs at one aspect ratio. A bug
#     that needs a second one to appear had nowhere to appear.
#
# So this asks the backdrop where its own bands are rather than multiplying
# HORIZON by a height of its choosing — that third multiplication is what the
# bug WAS, and a test that did it again would agree with whichever copy it
# happened to mirror.
# =============================================================================


## The lawn's footing is the same at every viewport height, not just at 648.
func test_the_title_lawn_stands_on_the_ground_at_any_viewport_height() -> String:
	var backdrop := TitleBackdrop.new()
	backdrop.ground_height = float(TitleScreen.viewport_height())

	# The design height first, then the reported phone, then two between. A
	# single extra height would have caught this one; the spread is here so the
	# next constant that is secretly absolute has somewhere to fail.
	var heights: Array[int] = [648, 900, 1400, 2048]
	var design_grass_gap: float = -1.0
	var design_soil_gap: float = -1.0
	var checked: int = 0
	var err: String = ""

	for h: int in heights:
		backdrop.size = Vector2(1152.0, float(h))
		var grass: float = backdrop.grass_line_y()
		var soil: float = backdrop.soil_line_y()
		var off: float = backdrop.ground_offset()
		var plant_y: float = TitleScreen.PLANT_BASE_Y + off
		var pest_y: float = TitleScreen.PEST_BASE_Y + off
		checked += 1

		if err == "":
			err = _T.assert_gt(plant_y, grass,
				("at %dpx tall the plants stand ON the grass, not above it " % h)
					+ ("(plant %.1f, grass line %.1f). A plant above the grass line " % [plant_y, grass])
					+ "is the lawn floating in the sky -- the constant is absolute "
					+ "and the ground is not.")
		if err == "":
			err = _T.assert_gt(soil, plant_y,
				("and at %dpx the plants are still on the grass band rather than " % h)
					+ ("down on the soil (plant %.1f, soil line %.1f)" % [plant_y, soil]))
		if err == "":
			err = _T.assert_gt(pest_y, soil,
				("and at %dpx the bugs march on the SOIL, which is the band in " % h)
					+ ("front (bug %.1f, soil line %.1f)" % [pest_y, soil]))
		if err == "":
			err = _T.assert_gt(float(h), soil,
				("and at %dpx the ground is on screen at all (soil line %.1f)" % [h, soil]))
		if err != "":
			return err

		# The footing is not merely valid at each height, it is the SAME footing.
		# Four independent "is it on the grass" checks would all pass on a lawn
		# that drifted a little further onto the grass at every size.
		if design_grass_gap < 0.0:
			design_grass_gap = plant_y - grass
			design_soil_gap = pest_y - soil
			continue
		err = _T.assert_float_eq(plant_y - grass, design_grass_gap, 0.001,
			("the plants keep the design's own footing at %dpx: %.1f px onto the " % [h, plant_y - grass])
				+ "grass, the same as at 648. A composition that survives one "
				+ "height and slides at another has two anchors, not one.")
		if err == "":
			err = _T.assert_float_eq(pest_y - soil, design_soil_gap, 0.001,
				("and the bugs keep theirs at %dpx: %.1f px onto the soil"
					% [h, pest_y - soil]))
		if err != "":
			return err

	if err == "":
		err = _T.assert_eq(checked, heights.size(),
			"every height in the list was actually measured")
	if err == "":
		# ground_anchor() is the composition height the bands are measured
		# against. Named here because a backdrop that quietly fell back to its
		# own size.y is precisely the bug, and it would look identical above.
		backdrop.size = Vector2(1152.0, 2048.0)
		err = _T.assert_float_eq(backdrop.ground_anchor(),
			float(TitleScreen.viewport_height()), 0.001,
			"the bands are measured against the composition, not the window")
	backdrop.free()
	return err


## The screen actually hands the backdrop's shift to its lawn.
##
## Separate from the test above on purpose. That one proves the ARITHMETIC is
## coherent; this proves the two halves are WIRED. Both were needed, because the
## bug was not a wrong formula — it was two correct formulas that never met.
func test_the_title_screen_gives_its_lawn_the_backdrops_own_shift() -> String:
	var title := await _T.instantiate_ui("res://game/title.tscn", Vector2i(1152, 648)) as TitleScreen
	var err: String = _T.assert_true(title != null, "the title scene resolves headlessly")
	if err != "":
		return err
	var backdrop := title.get_node_or_null("Backdrop") as TitleBackdrop
	if err == "":
		err = _T.assert_true(backdrop != null, "and it built a backdrop to stand the lawn on")
	if err == "":
		err = _T.assert_float_eq(backdrop.ground_height,
			float(TitleScreen.viewport_height()), 0.001,
			("the screen told the backdrop which height the composition is. Left at"
				+ " -1 the backdrop measures its own stretched size and the lawn"
				+ " floats -- that is the whole defect, and this is the one line"
				+ " that prevents it."))
	if err == "":
		err = _T.assert_float_eq(title.lawn_offset(), backdrop.ground_offset(), 0.001,
			("and the lawn takes the ground's own shift rather than a second"
				+ " one of its own. Two shifts is how they came apart."))
	_T.free_ui(title)
	return err


# END the lawn stands on the ground at any viewport height
# =============================================================================


# =============================================================================
# BEGIN the top bar's four readouts are four different treatments
# (plant-tower-defense-6tmf)
# =============================================================================


## The four readouts are four DIFFERENT kinds of thing, and until 6tmf they were four
## near-identical strings: 26/26/26/20 with no other difference between them, on one
## flat INK slab.
##
## What that fix has to be is a set of treatments no two readouts share, and that is
## exactly what this asserts — off `Hud.STAT_READOUTS` itself rather than against a
## hand-written list of the four, so a fifth readout added later cannot quietly rejoin
## the undifferentiated line by copying an existing pair.
##
## Pure: no HUD, no viewport. The table is the declaration, and the live test below is
## the separate question of whether the row actually wears what the table declares.
func test_no_two_top_bar_readouts_share_a_typographic_treatment() -> String:
	var rows: Array[Dictionary] = Hud.STAT_READOUTS
	var err: String = _T.assert_gt(rows.size(), 1,
		"there are at least two readouts to tell apart")
	if err != "":
		return err
	# name -> "size/weight". Built rather than compared pairwise so the failure names
	# both offenders instead of "two of them clash".
	var seen: Dictionary = {}
	var clashes: PackedStringArray = []
	var checked: int = 0
	for row: Dictionary in rows:
		var name: String = String(row.get("name", ""))
		err = _T.assert_true(row.has("weight"),
			("%s declares its stroke weight. It is a column and not a function of "
				+ "font_size because two readouts share a size") % name)
		if err != "":
			return err
		err = _T.assert_gte(int(row["weight"]), Hud.READOUT_WEIGHT_PLAIN,
			"%s's weight is not negative" % name)
		if err != "":
			return err
		var treatment: String = "%dpx / weight %d" % [int(row["font_size"]), int(row["weight"])]
		if seen.has(treatment):
			clashes.append("%s and %s are both %s" % [String(seen[treatment]), name, treatment])
		seen[treatment] = name
		checked += 1
	err = _T.assert_eq(checked, rows.size(),
		"every declared readout was measured for a treatment (%d of %d)"
			% [checked, rows.size()])
	if err == "":
		err = _T.assert_eq(clashes.size(), 0,
			("no two readouts are drawn the same. That is the whole of 6tmf: four "
				+ "kinds of thing reading as one line. %s") % ", ".join(clashes))
	if err == "":
		# And the ladder is a ladder, not four settings that happen to differ. The
		# widest span has to be a real one -- a row of 26/26/25/24 would pass the
		# clash check above and still look like one undifferentiated line.
		var smallest: int = 9999
		var largest: int = 0
		for row: Dictionary in rows:
			smallest = mini(smallest, int(row["font_size"]))
			largest = maxi(largest, int(row["font_size"]))
		err = _T.assert_gte(largest - smallest, 6,
			("the size ladder spans %d px (%d to %d) -- a hierarchy nobody can see "
				+ "at a glance is not one") % [largest - smallest, smallest, largest])
	return err


## And the row on screen actually wears what the table declares.
##
## Two separate claims, because they failed apart before the table existed: the
## DECLARATION above is drift-proof by construction, and this is the wiring. A
## `weight` column nothing reads would pass every check above it.
##
## The width guard at the end is the one thing no existing check makes. An outline of
## N px puts N px either side of the drawn glyphs, and both
## `test_no_readout_clips_its_own_worst_case` and `cmd budgets` measure the bare string
## through `Font.get_string_size()` — neither sees an outline pushing a full-width
## readout into its ellipsis. `_T.text_width`, never `get_minimum_size()`: every
## readout here sets `clip_text`, so the obvious assertion passes unconditionally on
## exactly the labels that need checking.
func test_every_readout_wears_its_declared_size_and_weight_and_still_fits() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var stats: HBoxContainer = game.hud.get_node_or_null("Root/TopBar/StatsRow") as HBoxContainer
	var err: String = _T.assert_true(stats != null, "the stats row is where the HUD puts it")
	if err != "":
		_T.free_ui(game)
		return err
	var wrong: PackedStringArray = []
	var overflow: PackedStringArray = []
	var measured: int = 0
	for row: Dictionary in Hud.STAT_READOUTS:
		var name: String = String(row["name"])
		var label: Label = stats.get_node_or_null(name) as Label
		if label == null:
			wrong.append("%s: not in the row at all" % name)
			continue
		measured += 1
		var size_px: int = label.get_theme_font_size("font_size")
		if size_px != int(row["font_size"]):
			wrong.append("%s: drawn at %dpx, declared %d" % [name, size_px, int(row["font_size"])])
		var weight: int = label.get_theme_constant("outline_size")
		if weight != int(row["weight"]):
			wrong.append("%s: weight %d drawn, %d declared" % [name, weight, int(row["weight"])])
		# The outline is the readout's OWN colour, so the glyphs thicken instead of
		# gaining a halo. Checked against the live font colour rather than against the
		# table's, because the wave readout's colour moves at runtime -- see
		# _ease_threat_tint, which writes the pair together for exactly this reason.
		var fill: Color = label.get_theme_color("font_color")
		var edge: Color = label.get_theme_color("font_outline_color")
		if not edge.is_equal_approx(fill):
			wrong.append("%s: outlined in %s around %s text -- that is a halo, not weight"
				% [name, edge, fill])
		# And the widest thing it can ever hold, drawn at that weight, inside its slot.
		var restore: String = label.text
		label.text = String(row["worst_case"])
		var drawn: float = _T.text_width(label) + 2.0 * float(weight)
		label.text = restore
		if drawn > label.custom_minimum_size.x:
			overflow.append("%s: \"%s\" draws %.0fpx at weight %d, slot is %.0f"
				% [name, String(row["worst_case"]), drawn, weight, label.custom_minimum_size.x])
	err = _T.assert_eq(measured, Hud.STAT_READOUTS.size(),
		"every declared readout is a Label in the row (%d of %d)"
			% [measured, Hud.STAT_READOUTS.size()])
	if err == "":
		err = _T.assert_eq(wrong.size(), 0,
			"every readout is drawn as the table declares it: %s" % ", ".join(wrong))
	if err == "":
		err = _T.assert_eq(overflow.size(), 0,
			("a weight is drawn OUTSIDE the glyphs, so a readout can clip on an outline "
				+ "that no width check measures: %s") % ", ".join(overflow))
	_T.free_ui(game)
	return err


# END the top bar's four readouts are four different treatments
# =============================================================================


# =============================================================================
# BEGIN an important message looks important (plant-tower-defense-xvub)
# =============================================================================


## The rule, with no row to hold it.
##
## Static and pure, so the four interesting cases are reachable without staging four
## messages through a live HUD -- including the last one, which a live row makes
## awkward: an EXPIRED deadline line is not stressed, because the row has fallen
## through to the standing prep note and the note is ambient however urgent the line
## it replaced was.
func test_a_line_is_stressed_by_its_rung_and_only_while_it_is_up() -> String:
	var err: String = _T.assert_false(Hud.message_is_stressed(3.0, Hud.MESSAGE_NORMAL),
		"a husk line is ambient")
	if err == "":
		err = _T.assert_true(Hud.message_is_stressed(3.0, Hud.MESSAGE_IMPORTANT),
			"a packet reveal is not")
	if err == "":
		err = _T.assert_true(Hud.message_is_stressed(3.0, Hud.MESSAGE_DEADLINE),
			("and the armed-uproot prompt least of all -- DEADLINE is stressed by `>=` "
				+ "rather than by naming two rungs, so a rung added above it inherits "
				+ "the emphasis"))
	if err == "":
		err = _T.assert_false(Hud.message_is_stressed(0.0, Hud.MESSAGE_DEADLINE),
			("an EXPIRED deadline line is ambient: the row has fallen back to the "
				+ "standing prep note, which is nobody's emergency"))
	return err


## MESSAGE_IMPORTANT used to control queue PRIORITY and nothing else, so the
## armed-uproot prompt -- a four-second irreversible decision -- was drawn exactly like
## "Composted a husk for 3 seeds."
##
## The acceptance is that the two are told apart WITH COLOUR THROWN AWAY, and this
## asserts it in the strongest available form: the two states are asserted to be the
## SAME colour, so there is no hue to discard in the first place, and the distinction
## is then read off two channels that survive greyscale -- stroke weight, and the
## presence of the margin mark.
func test_an_important_line_is_told_from_an_ambient_one_without_colour() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var label: Label = game.hud.get_node_or_null("Root/TopBar/MessageLabel") as Label
	var mark: ColorRect = game.hud.get_node_or_null("Root/TopBar/MessageLabel/MessageMark") as ColorRect
	var err: String = _T.assert_true(label != null and mark != null,
		"the message row and its margin mark are where the HUD puts them")
	if err != "":
		_T.free_ui(game)
		return err
	# Drain whatever the opening state posted, so the two lines below are the only two
	# the row is asked about. The same drain the uproot tests above use.
	game.hud._message_left = 0.0
	game.hud._message_queue.clear()
	game.hud._advance_message_queue()

	game.hud.show_message("Composted a husk for 3 seeds.", 3.0, Hud.MESSAGE_NORMAL)
	var ambient_text: String = label.text
	var ambient_weight: int = label.get_theme_constant("outline_size")
	var ambient_colour: Color = label.get_theme_color("font_color")
	var ambient_mark: bool = mark.visible

	# The real line, at the real rung, from the real caller's shape: Game arms the
	# uproot with MESSAGE_DEADLINE, which outranks the husk line and takes the row now.
	game.hud.show_message("Uproot again to confirm. It will not grow back.",
		4.0, Hud.MESSAGE_DEADLINE)
	var urgent_text: String = label.text
	var urgent_weight: int = label.get_theme_constant("outline_size")
	var urgent_colour: Color = label.get_theme_color("font_color")
	var urgent_mark: bool = mark.visible

	err = _T.assert_true(ambient_text.contains("Composted") and urgent_text.contains("Uproot"),
		("both lines actually reached the row -- a state read off a row showing "
			+ "something else measures nothing (got \"%s\" then \"%s\")")
			% [ambient_text, urgent_text])
	if err == "":
		# The load-bearing assertion. If this ever fails the row has started leaning on
		# hue, and every other assertion here becomes a description of a cue a
		# greyscale reader cannot see.
		err = _T.assert_true(urgent_colour.is_equal_approx(ambient_colour),
			("the two lines are the SAME colour (%s vs %s), so the distinction below "
				+ "is not a colour one") % [urgent_colour, ambient_colour])
	if err == "":
		err = _T.assert_gt(urgent_weight, ambient_weight,
			"channel one, WEIGHT: the urgent line's strokes are thicker (%d against %d)"
				% [urgent_weight, ambient_weight])
	if err == "":
		err = _T.assert_false(ambient_mark, "channel two, THE MARK: absent beside a husk line")
	if err == "":
		err = _T.assert_true(urgent_mark, "and present beside the armed-uproot prompt")
	if err == "":
		# And it goes away again. A cue that latches on is a cue that stops meaning
		# anything the second time the player sees it.
		game.hud._message_left = 0.0
		game.hud._message_queue.clear()
		game.hud._advance_message_queue()
		err = _T.assert_false(mark.visible,
			"and both channels drop when the row falls back to its standing note")
	if err == "":
		err = _T.assert_eq(label.get_theme_constant("outline_size"), ambient_weight,
			"including the weight")
	_T.free_ui(game)
	return err


## The mark costs the row NOTHING, which is the constraint that chose it.
##
## The message row is the tight one -- `PREP_NOTE_WORST_CASE` is pinned against its
## width in `test_selftest.gd` -- so an emphasis cue holding a slot in it would be
## spending width the row does not have. It is a ColorRect child of the Label with
## negative offsets, the same trick `_readout_rule` uses upstairs: drawn in the gutter
## between the page's margin rule and the text, which is space nothing was using.
func test_the_message_mark_is_drawn_outside_the_row_it_marks() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var label: Label = game.hud.get_node_or_null("Root/TopBar/MessageLabel") as Label
	var mark: ColorRect = game.hud.get_node_or_null("Root/TopBar/MessageLabel/MessageMark") as ColorRect
	var rule: ColorRect = game.hud.get_node_or_null("Root/TopBar/MarginRule") as ColorRect
	var err: String = _T.assert_true(label != null and mark != null and rule != null,
		"the message row, its mark and the page's margin rule are all built")
	if err != "":
		_T.free_ui(game)
		return err
	# Show it first: an anchored child's rect is only worth reading once the row has
	# been laid out, and a hidden node measuring (0, 0) would satisfy every bound below
	# by being nothing at all.
	game.hud.show_message("Uproot again to confirm.", 4.0, Hud.MESSAGE_DEADLINE)
	err = _T.assert_true(mark.visible, "the mark is up for a deadline line")
	if err == "":
		err = _T.assert_float_eq(mark.size.x, Hud.MESSAGE_MARK_WIDTH, 0.001,
			"and the anchors resolved to a real box rather than to nothing")
	if err == "":
		# Local space: `position` is relative to the Label, so a right edge at or left
		# of zero IS the claim "this is drawn outside the row's own box".
		err = _T.assert_true(mark.position.x + mark.size.x <= 0.0,
			("the mark's right edge sits at %.1f in the row's own space -- at or left "
				+ "of 0, so it holds no width in the row it marks")
				% [mark.position.x + mark.size.x])
	if err == "":
		err = _T.assert_gte(mark.global_position.x, rule.global_position.x + rule.size.x,
			("and it starts at %.1f, clear of the page's margin rule which ends at "
				+ "%.1f -- touching, never overlapping")
				% [mark.global_position.x, rule.global_position.x + rule.size.x])
	if err == "":
		# Parented to the Label and not to the bar, which is what makes the two claims
		# above true for free at every viewport width: the mark follows the row's rect
		# through `_apply_viewport_layout()` rather than carrying a second copy of that
		# arithmetic. A mark parented to TopBar would pass both bounds above at 1152
		# and drift at any other width.
		err = _T.assert_eq(String(mark.get_parent().name), String(label.name),
			"the mark hangs off the row it marks, not off the bar (parent: %s)"
				% mark.get_parent().name)
	_T.free_ui(game)
	return err


# END an important message looks important
# =============================================================================


# =============================================================================
# BEGIN plant-tower-defense-fjqp: the uproot window, drawn
#
# Appended as a delimited block on purpose: sibling lanes append here too, and a
# named section is what makes a conflict resolvable by keeping both rather than by
# picking one. Nothing above this line was touched.
#
# The cue is a partial arc at a fixed radius sweeping closed — OVERLAY_GRAMMAR.md's
# existing row for TIME REMAINING, third instance after a husk's rot timer and a
# Chomp's chew. It is drawn by SelectionMarker._draw_uproot_window() and fed by
# Game._push_uproot_clock(). Headless never runs a _draw() at all, so the sweep lives
# in the pure static SelectionMarker.uproot_arc_end() and everything below asserts
# either that static or the two numbers pushed into the marker that feed it.


func test_the_uproot_arc_closes_as_the_confirm_window_runs_out() -> String:
	## ACCEPTANCE, second half: the drawn fraction tracks `_uproot_left` rather than
	## merely existing. Both halves are here — the pure sweep arithmetic with no board
	## at all, then a real Game driven through a real arming so the numbers the arc is
	## drawn FROM are the numbers the timer that fires counts DOWN.
	##
	## The runtime half is what a "draw a constant full circle whenever armed" would
	## survive, and the pure half is what "return the right angle from a function
	## nothing pushes into" would survive. Neither alone is the acceptance.
	var full: float = SelectionMarker.uproot_arc_end(
		Game.UPROOT_CONFIRM_SECONDS, Game.UPROOT_CONFIRM_SECONDS)
	var err: String = _T.assert_float_eq(full, SelectionMarker.UPROOT_RING_START + TAU,
		0.0001, "a window with all four seconds left is a whole circle")
	if err == "":
		err = _T.assert_float_eq(
			SelectionMarker.uproot_arc_end(
				Game.UPROOT_CONFIRM_SECONDS * 0.5, Game.UPROOT_CONFIRM_SECONDS),
			SelectionMarker.UPROOT_RING_START + TAU * 0.5, 0.0001,
			"half the window left is half a circle, which is the whole claim")
	if err == "":
		err = _T.assert_float_eq(
			SelectionMarker.uproot_arc_end(0.0, Game.UPROOT_CONFIRM_SECONDS),
			SelectionMarker.UPROOT_RING_START, 0.0001,
			"an expired window is an arc of no length, not a ring")
	if err == "":
		# The last tick of a real window overshoots zero by whatever `delta` was, and a
		# window of zero is what an unarmed marker holds — a division rather than a
		# clamp turns the first into a backwards sweep and the second into INF.
		err = _T.assert_float_eq(SelectionMarker.uproot_arc_end(-0.3, 4.0),
			SelectionMarker.UPROOT_RING_START, 0.0001, "and so is an overshot one")
	if err == "":
		err = _T.assert_float_eq(SelectionMarker.uproot_arc_end(1.0, 0.0),
			SelectionMarker.UPROOT_RING_START, 0.0001,
			"and so is a window that was never opened, rather than a division by zero")
	if err == "":
		err = _T.assert_float_eq(SelectionMarker.uproot_arc_end(99.0, 4.0),
			SelectionMarker.UPROOT_RING_START + TAU, 0.0001,
			"and a clock somehow over its own window is one circle, not several")
	if err != "":
		return err

	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(100)
	err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, _grass(game)), "", "planted")
	var marker: SelectionMarker = null
	if err == "":
		var plant: Plant = game.selected_placed
		err = _T.assert_true(plant != null, "and the bed is selected")
		if err == "":
			marker = plant.get_node_or_null("SelectionMarker") as SelectionMarker
			err = _T.assert_true(marker != null, "and carries a selection marker")
	if err == "":
		# Nothing armed draws no clock, which is the state every plant on the board is
		# in on every frame but four seconds of the whole run.
		err = _T.assert_float_eq(marker.uproot_window, 0.0, 0.0001,
			"an unarmed bed holds no window")
	if err == "":
		err = _T.assert_eq(game.arm_uproot(), "confirm needed", "one click arms it")
	if err == "":
		# On the ARMING frame, not on the first tick after it: a clock whose first
		# drawn frame is already short reads as time the player has somehow spent.
		err = _T.assert_float_eq(marker.uproot_left, Game.UPROOT_CONFIRM_SECONDS,
			0.0001, "and the arc opens full on the arming frame itself")
	if err == "":
		err = _T.assert_float_eq(marker.uproot_window, Game.UPROOT_CONFIRM_SECONDS,
			0.0001, "against the window the timer that fires actually uses")
	# The tracking claim: drive the same tick the real _process drives and require the
	# marker to have MOVED to the game's own remaining time. A cue pushed once at
	# arming and never again passes every assertion above and fails this one.
	var early: float = 0.0
	if err == "":
		early = SelectionMarker.uproot_arc_end(marker.uproot_left, marker.uproot_window)
		game._tick_uproot_confirm(1.0)
		err = _T.assert_float_eq(marker.uproot_left, Game.UPROOT_CONFIRM_SECONDS - 1.0,
			0.0001, "a second of the window spent leaves a second less on the arc")
	if err == "":
		err = _T.assert_float_eq(marker.uproot_left, game._uproot_left, 0.0001,
			("and it is the SAME number the timer counts, not a second clock: "
				+ "marker %.3f vs game %.3f") % [marker.uproot_left, game._uproot_left])
	if err == "":
		var late: float = SelectionMarker.uproot_arc_end(
			marker.uproot_left, marker.uproot_window)
		err = _T.assert_gt(early, late,
			("so the arc closes rather than merely existing: %.3f rad of sweep became "
				+ "%.3f") % [early - SelectionMarker.UPROOT_RING_START,
					late - SelectionMarker.UPROOT_RING_START])
	# Letting it lapse is the exit a player takes by doing nothing, and it is the one
	# that must not leave a red arc promising a click that would now do something else.
	if err == "":
		game._tick_uproot_confirm(Game.UPROOT_CONFIRM_SECONDS)
		err = _T.assert_false(game.uproot_armed(), "the window closes")
	if err == "":
		err = _T.assert_float_eq(marker.uproot_window, 0.0, 0.0001,
			"and takes the arc with it")
	if err == "":
		err = _T.assert_float_eq(marker.uproot_left, 0.0, 0.0001, "in both numbers")
	_T.free_ui(game)
	return err


func test_the_uproot_arc_is_a_third_channel_and_not_a_second_red_mark() -> String:
	## Arming this bed ALREADY changed two things before this cue existed: the brackets
	## go WARNING_COLOR at WARNING_LINE_WIDTH, and SoleCoverMarks escalates with them.
	## Both are binary. The defect the bead names is not "nothing marks an armed plant"
	## — it is that nothing anywhere counts the four seconds down. So the test that
	## matters is that the new mark carries TIME while the old ones stay exactly as
	## binary as they were: three cues saying the same one thing would be the failure.
	##
	## The geometry bounds are here too, because both of them are what stops this arc
	## being read as one of the cues it sits on top of, and neither survives being left
	## as a sentence in a header.
	var err: String = _T.assert_gt(SelectionMarker.HALF,
		SelectionMarker.UPROOT_RING_RADIUS,
		("the clock (%.0f) draws strictly inside the brackets (%.0f) -- the arms lie on "
			+ "|x| = HALF and |y| = HALF, so a smaller circle crosses none of them")
			% [SelectionMarker.UPROOT_RING_RADIUS, SelectionMarker.HALF])
	if err == "":
		# The load-bearing one. A Chomp Flower can be armed for uproot while its mouth
		# is full, and its chew ring is the OTHER instance of this same grammar row at
		# this same scale. Same radius would leave hue as the only thing telling two
		# closing arcs apart, which is the one rule OVERLAY_GRAMMAR.md gives teeth.
		err = _T.assert_gt(ChompFlower.CHEW_RING_RADIUS,
			SelectionMarker.UPROOT_RING_RADIUS,
			("and strictly inside the Chomp's chew ring (%.0f vs %.0f), so a Chomp armed "
				+ "mid-meal shows two concentric clocks rather than two reds")
				% [SelectionMarker.UPROOT_RING_RADIUS, ChompFlower.CHEW_RING_RADIUS])
	if err == "":
		# And clear of the plant's own cell, so a clock never draws into the square
		# next door where it would read as a mark on somebody else's bed.
		err = _T.assert_gt(float(Board.CELL) * 0.5,
			SelectionMarker.UPROOT_RING_RADIUS + SelectionMarker.UPROOT_RING_WIDTH * 0.5,
			"and inside the plant's own cell")
	if err != "":
		return err

	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(100)
	err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, _grass(game)), "", "planted")
	var marker: SelectionMarker = null
	if err == "":
		marker = game.selected_placed.get_node_or_null("SelectionMarker") as SelectionMarker
		err = _T.assert_true(marker != null, "the bed carries a marker")
	if err == "":
		err = _T.assert_eq(game.arm_uproot(), "confirm needed", "the uproot arms")
	# Halfway through the window: the two binary channels are still saying exactly what
	# they said at zero seconds, which is the point — they cannot say this.
	if err == "":
		game._tick_uproot_confirm(Game.UPROOT_CONFIRM_SECONDS * 0.5)
		err = _T.assert_eq(marker.marker_color, SelectionMarker.WARNING_COLOR,
			"half a window in, the brackets are still just red")
	if err == "":
		err = _T.assert_float_eq(marker.line_width, SelectionMarker.WARNING_LINE_WIDTH,
			0.001, "and still just heavy -- neither channel has moved, and neither can")
	if err == "":
		var sweep: float = SelectionMarker.uproot_arc_end(
			marker.uproot_left, marker.uproot_window) - SelectionMarker.UPROOT_RING_START
		err = _T.assert_float_eq(sweep, TAU * 0.5, 0.02,
			("while the arc has: %.2f rad of sweep left, which is the half-window the "
				+ "colour and the weight structurally cannot carry") % sweep)
	# Directly from here on, the way SoleCoverMarks' idempotence is pinned above: the
	# route through Game only ever calls these in one order, and the promises the
	# marker's own headers make are about being called any way at all.
	if err == "":
		marker.set_uproot_window(-0.4, Game.UPROOT_CONFIRM_SECONDS)
		err = _T.assert_float_eq(marker.uproot_left, 0.0, 0.0001,
			("a window overshot past zero floors there rather than sweeping backwards "
				+ "-- the last tick of a real window overshoots by whatever delta was"))
	if err == "":
		marker.set_uproot_window(Game.UPROOT_CONFIRM_SECONDS, Game.UPROOT_CONFIRM_SECONDS)
		marker.set_warning(false)
		err = _T.assert_float_eq(marker.uproot_window, 0.0, 0.0001,
			("and disarming closes the arc from inside set_warning, which is the ONE "
				+ "call every exit from the armed state already runs through"))
	if err == "":
		err = _T.assert_eq(marker.marker_color, SelectionMarker.MARKER_COLOR,
			"alongside the two channels it was already putting back")
	_T.free_ui(game)
	return err


func test_the_uproot_arc_is_actually_painted_and_the_marker_is_its_only_clock() -> String:
	## The hole a pure static leaves. `uproot_arc_end` can be exactly right and called
	## by nothing, and every assertion above still passes: headless has no renderer, so
	## no test in this suite can watch a `_draw()` run. This is the source check that
	## says the paint call is wired to the arithmetic the rest of the section pins.
	##
	## Structural, so it survives the numbers being retuned: it does not care what the
	## radius is, only that the sweep the arc is drawn with is the function and not a
	## literal, and that `_draw` reaches the painter at all.
	var src: String = FileAccess.get_file_as_string("res://game/selection_marker.gd")
	var err: String = _T.assert_gt(src.length(), 0,
		"selection_marker.gd is readable -- every check below is vacuous otherwise")
	if err != "":
		return err
	var painter: int = src.find("func _draw_uproot_window(")
	err = _T.assert_gt(painter, 0, "there is a painter for the confirm arc")
	if err == "":
		err = _T.assert_true(src.contains("_draw_uproot_window()"),
			"and `_draw()` calls it, rather than it being a function nothing paints")
	if err == "":
		var body: String = src.substr(painter)
		err = _T.assert_true(body.contains("uproot_arc_end("),
			("the painter's sweep comes from uproot_arc_end() -- a literal angle here "
				+ "would leave the tested static describing an arc nobody draws"))
		if err == "":
			err = _T.assert_true(body.contains("draw_arc("),
				"through a draw_arc, which is the grammar row this cue claims")
	if err == "":
		# The other half of "one clock": SelectionMarker must not count. A `_process`
		# on this node subtracting its own delta would drift against Game's timer, and
		# the drift would be invisible until the arc and the button disagreed.
		err = _T.assert_false(src.contains("func _process("),
			("SelectionMarker runs no clock of its own -- Game._push_uproot_clock feeds "
				+ "it, and a second countdown here is one that can disagree with the "
				+ "timer that actually decides whether the next click destroys a bed"))
	if err == "":
		var game_src: String = FileAccess.get_file_as_string("res://game/game.gd")
		err = _T.assert_true(game_src.contains("func _push_uproot_clock("),
			"and Game is the thing that feeds it")
	return err

# END plant-tower-defense-fjqp: the uproot window, drawn
# =============================================================================


# =============================================================================
# BEGIN plant-tower-defense-om5f: the sway rotates about the stem

## Alpha above which a pixel counts as painted. Deliberately NOT test_sprite_style.gd's
## `OPAQUE` of 250, which asks "is this pixel solid" — the question here is "is there any
## ink at all in this row", so an antialiased edge counts. The answer is insensitive to
## the exact number anyway: sweeping this from 8 to 128 moves two of the eight bases by a
## pixel and never moves the family's median off 25 or its worst deviation off 2.
const OM5F_OPAQUE_ALPHA: float = 8.0 / 255.0

## How far a single plant's painted base may sit from `Plant.STEM_PIVOT_Y`. The
## family's own bases span 3 px (+24 to +27), so the median is at worst 2 px from
## any of them; this is that spread, not a slack budget.
const OM5F_BASELINE_SPREAD: float = 2.0

## The plant sprites are 64 px, so the sprite's own centre is 32 px above its bottom
## edge. Written out here rather than read off a texture because it is the number the
## OLD pivot used, and the point of the comparison below is what changed.
const OM5F_SPRITE_HALF: float = 32.0


## The bead in one assertion: the point the sway turns about is the base of the plant,
## and it does not move.
##
## Asserted as the FIXED POINT of the transform the game actually builds, not as a node
## position, because there is no node position to read — `Plant.sway_transform`'s header
## has the whole reason, and the short version is that pushing `_sway_pivot.position`
## down would make `Vector2.ZERO` the wrong home for the two gestures that tween
## `_sprite.position` back to it. The fixed point is the pivot, and it is the same call
## `_wobble` makes rather than a restatement of it, which is what a headless suite can
## hold: everything past `animations_enabled()` is an early return here.
##
## A mutation putting `STEM_PIVOT_Y` back to 0 moves the base by the full
## `STEM_PIVOT_Y * sin(angle)` and fails on the first angle.
func test_the_sway_turns_about_the_stem_and_the_base_stays_put() -> String:
	var base := Vector2(0.0, Plant.STEM_PIVOT_Y)
	var angles: Array[float] = [
		Plant.WOBBLE_RADIANS,
		-Plant.WOBBLE_RADIANS,
		Plant.WOBBLE_RADIANS + Plant.FLINCH_RADIANS,
	]
	var err: String = _T.assert_gt(angles.size(), 0,
		"there are angles to sweep -- an empty list here is a vacuous pass")
	if err != "":
		return err
	for angle: float in angles:
		var landed: Vector2 = Plant.sway_transform(angle, Vector2.ONE) * base
		err = _T.assert_float_eq(landed.distance_to(base), 0.0, 0.0001,
			("at %.3f rad the base of the stem has moved to %s, %.3f px off the soil it "
				+ "was planted in -- a plant hinges at the ground or it is a balloon on "
				+ "a string") % [angle, landed, landed.distance_to(base)])
		if err != "":
			return err
	return err


## The other half of the same change, and the half a player actually sees: pinning the
## base does not shrink the motion, it moves all of it to the top.
##
## A point `d` from the pivot travels `d * sin(angle)` sideways. About the waist the top
## of a 64 px sprite was 32 px out; about the stem it is `32 + STEM_PIVOT_Y` = 57 px out,
## so the same unchanged `WOBBLE_RADIANS` buys 1.78x the visible swing. The comparison is
## against a bare `rotated()`, which is exactly what `_sway_pivot.rotation` used to be.
func test_the_head_swings_further_than_it_did_about_the_waist() -> String:
	var top := Vector2(0.0, -OM5F_SPRITE_HALF)
	var angle: float = Plant.WOBBLE_RADIANS
	var about_stem: Vector2 = Plant.sway_transform(angle, Vector2.ONE) * top
	var about_waist: Vector2 = top.rotated(angle)
	var err: String = _T.assert_float_eq(absf(about_stem.x),
		(OM5F_SPRITE_HALF + Plant.STEM_PIVOT_Y) * sin(angle), 0.001,
		("the top of the sprite swings the full stem-to-crown radius, got %.3f px"
			% absf(about_stem.x)))
	if err == "":
		err = _T.assert_gt(absf(about_stem.x), absf(about_waist.x) * 1.5,
			("and that is a real gain over the old centre pivot: %.3f px against %.3f px "
				+ "for the same %.3f rad") % [absf(about_stem.x), absf(about_waist.x), angle])
	return err


## Nothing about a plant that is not currently swaying moved, which is the promise that
## makes this bead safe to land in a lane of its own.
##
## Three separate zeroes, each load-bearing for something in a file this lane does not
## own, and each of them still zero:
##
##   * `sway_transform(0, ONE)` is the identity, so a headless run and a player with
##     animations off see the board they saw yesterday, to the pixel.
##   * `_sprite.position` is still the origin, which is where `ChompFlower._bite()` and
##     `Nettle._sting_twitch()` both send the sprite home to.
##   * `_sprite.offset` is still zero, which is what keeps all five scale flourishes
##     scaling about the sprite's centre. `Sprite2D.offset` is multiplied by the node's
##     own `scale`, so a counterweight parked there would start the planting pop
##     `0.6 * STEM_PIVOT_Y` px underground.
func test_a_plant_standing_still_is_exactly_where_it_always_was() -> String:
	var err: String = _T.assert_eq(Plant.sway_transform(0.0, Vector2.ONE),
		Transform2D.IDENTITY,
		("a plant at rest carries no transform at all, got %s"
			% Plant.sway_transform(0.0, Vector2.ONE)))
	var plant := Plant.new()
	plant.setup(PlantCatalog.CORN, Vector2i(3, 5), null)
	if err == "":
		err = _T.assert_eq(plant._sway_pivot.transform, Transform2D.IDENTITY,
			("and a freshly built one carries none either, got %s"
				% plant._sway_pivot.transform))
	if err == "":
		err = _T.assert_eq(plant._sprite.position, Vector2.ZERO,
			("the sprite's home is still the origin -- ChompFlower._bite() and "
				+ "Nettle._sting_twitch() both tween `position` back to Vector2.ZERO, and "
				+ "a sprite parked anywhere else would be yanked there by every bite"))
	if err == "":
		err = _T.assert_eq(plant._sprite.offset, Vector2.ZERO,
			("and its offset is still zero -- Sprite2D.offset rides `scale`, so the "
				+ "counterweight the issue proposed putting there would drag the planting "
				+ "pop underground and collapse the exit shrink into the soil"))
	plant.free()
	return err


## The risk this bead carried, settled with arithmetic instead of a screenshot.
##
## `ChompFlower._bite()` tweens `_sprite.position` by `LUNGE_DISTANCE` at its meal and
## `Nettle._sting_twitch()` by `STING_THRUST_PX` at its victim, both in the sway pivot's
## frame and both deliberately: the header on the first says the lunge leaning by at most
## `FLINCH_RADIANS` "leans the lunge without ever pointing it at the wrong neighbour".
##
## Moving the pivot could have changed the frame those offsets are applied in. It does
## not, and the reason is structural rather than lucky: a child's local translation is
## mapped by its parent's BASIS, and this bead changed only the ORIGIN. So the assertion
## is equality against the transform the pivot used to carry — the same rotation, the
## same breathe, origin zero — rather than a tolerance anyone has to argue about.
func test_the_lunge_and_the_sting_land_exactly_where_they_did_before() -> String:
	var angle: float = Plant.WOBBLE_RADIANS + Plant.FLINCH_RADIANS
	var breathe: Vector2 = Plant.breathe_scale(0.25)
	var moved: Transform2D = Plant.sway_transform(angle, breathe)
	var waist := Transform2D(angle, breathe, 0.0, Vector2.ZERO)
	var here := Vector2(320.0, 320.0)
	var offsets: Array[Vector2] = [
		ChompFlower.lunge_offset(here, here + Vector2(64.0, 0.0)),
		ChompFlower.lunge_offset(here, here + Vector2(-64.0, 64.0)),
		Nettle.sting_thrust_offset(here, here + Vector2(0.0, -64.0)),
		Nettle.sting_thrust_offset(here, here + Vector2(64.0, 64.0)),
	]
	var err: String = _T.assert_gt(offsets.size(), 0,
		"there are gestures to check -- an empty list here is a vacuous pass")
	if err != "":
		return err
	for offset: Vector2 in offsets:
		var after: Vector2 = moved.basis_xform(offset)
		var before: Vector2 = waist.basis_xform(offset)
		err = _T.assert_float_eq(after.distance_to(before), 0.0, 0.00001,
			("a %.1f px gesture aimed %s lands at %s under the stem pivot and landed at "
				+ "%s under the waist pivot -- moving the pivot must not move where a "
				+ "lunge points") % [offset.length(), offset, after, before])
		if err != "":
			return err
	# And the lean the Chomp's header claims is still bounded by the sway angle, which is
	# the property that stops a bite pointing at the wrong neighbour.
	var aimed: Vector2 = offsets[0]
	err = _T.assert_true(absf(moved.basis_xform(aimed).angle_to(aimed)) <= angle + 0.0001,
		("and the lean is still at most the sway angle itself (%.3f rad), got %.3f"
			% [angle, absf(moved.basis_xform(aimed).angle_to(aimed))]))
	return err


## What makes `STEM_PIVOT_Y` a measurement rather than a taste: it is re-derived from the
## PNGs on disk every run, and new art that moves the family's baseline fails here.
##
## The issue proposed 32 px, the sprite's half-height. That is the bottom of the FILE,
## not the bottom of the plant — none of the eight arts reaches its own bottom edge, so a
## pivot there would hinge every bed from a point in transparent padding, several pixels
## underground. The bases actually land at +24 (nettle, mint, aloe), +25 (corn_cobbler,
## sticky_sundew) and +27 (chomp_flower, sunflower, dandelion).
##
## Decoded straight off disk with `load_png_from_buffer`, the way test_sprite_style.gd
## does it and for the same reason: a stale import cannot make a wrong pivot pass.
func test_the_stem_pivot_is_the_bottom_of_the_art_not_the_bottom_of_the_png() -> String:
	var bases: Dictionary = {}
	for id: StringName in PlantCatalog.ORDER:
		var path: String = PlantCatalog.texture_path(id)
		if not FileAccess.file_exists(path):
			return "%s: no PNG at '%s' -- every measurement below would be vacuous" % [id, path]
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
			return "%s: '%s' did not decode as a PNG" % [id, path]
		var bottom: int = -1
		for y: int in range(img.get_height()):
			for x: int in range(img.get_width()):
				if img.get_pixel(x, y).a > OM5F_OPAQUE_ALPHA:
					bottom = y
					break
		if bottom < 0:
			return "%s: '%s' is entirely transparent" % [id, path]
		# Row `bottom` spans [bottom, bottom + 1) in texture pixels, and a centred
		# Sprite2D puts the texture's middle on the node's origin.
		bases[String(id)] = float(bottom + 1) - float(img.get_height()) * 0.5
	var err: String = _T.assert_eq(bases.size(), PlantCatalog.ORDER.size(),
		"every plant in the catalogue was measured, or this sweep has a hole in it")
	if err != "":
		return err
	var worst: float = 0.0
	var deepest: float = -1000.0
	for name: String in bases:
		worst = maxf(worst, absf(float(bases[name]) - Plant.STEM_PIVOT_Y))
		deepest = maxf(deepest, float(bases[name]))
	err = _T.assert_true(worst <= OM5F_BASELINE_SPREAD,
		("the worst plant's painted base is %.1f px from STEM_PIVOT_Y (%.1f), past the "
			+ "%.1f px the family's own spread allows. Measured bases: %s. Retune the "
			+ "constant or the art -- do not leave the pivot hinging in padding")
			% [worst, Plant.STEM_PIVOT_Y, OM5F_BASELINE_SPREAD, bases])
	if err == "":
		err = _T.assert_gt(OM5F_SPRITE_HALF - deepest, 3.0,
			("and no plant's art reaches the PNG's own bottom edge at +%.0f -- the "
				+ "deepest stops at %.1f, which is why the pivot is not the half-height "
				+ "the issue guessed at") % [OM5F_SPRITE_HALF, deepest])
	return err


## The regression this bead could have introduced and did not: the sway must still move
## the sprite and nothing else.
##
## The health bar, its backing, the regrowth notches, the selection marker and the sole
## cover marks are all children of the PLANT, not of the pivot, so none of them swings.
## Pinned here rather than left to `_build_visuals`'s call order because a pivot that has
## just been given a point to turn about is exactly the pivot somebody reparents a cue
## onto next, and a health bar rocking about the soil line is a bug the suite would
## otherwise never see — headless runs no `_draw()` and never opens the animation gate.
func test_the_sway_still_carries_the_sprite_and_nothing_else() -> String:
	var plant := Plant.new()
	plant.setup(PlantCatalog.CORN, Vector2i(3, 5), null)
	var err: String = _T.assert_eq(plant._sway_pivot.get_child_count(), 1,
		("the sprite is the only thing riding the sway; anything else parented here "
			+ "now rocks about the soil line with it, got %d children"
			% plant._sway_pivot.get_child_count()))
	if err == "":
		err = _T.assert_eq(plant._sway_pivot.get_child(0), plant._sprite,
			"and the one thing riding it is the sprite")
	if err == "":
		err = _T.assert_eq(plant._health_bar.get_parent(), plant,
			"the health bar hangs off the plant, so it stays level while the plant leans")
	if err == "":
		err = _T.assert_eq(plant._health_back.get_parent(), plant, "and its backing")
	if err == "":
		err = _T.assert_gt(plant._health_notches.size(), 0,
			"there are regrowth notches to check -- none would be a vacuous pass")
	if err == "":
		for notch: ColorRect in plant._health_notches:
			err = _T.assert_eq(notch.get_parent(), plant, "and every regrowth notch")
			if err != "":
				break
	if err == "":
		err = _T.assert_eq(plant._selection_marker.get_parent(), plant,
			"and the selection marker, which is drawn around the cell and not the plant")
	if err == "":
		err = _T.assert_eq(plant._sole_cover_marks.get_parent(), plant,
			"and the sole cover marks, which sit whole cells away")
	plant.free()
	return err

# END plant-tower-defense-om5f: the sway rotates about the stem
# =============================================================================


# =============================================================================
# BEGIN plant-tower-defense-tzz7 / plant-tower-defense-g8kc
#   tzz7: surface dead ground before the player is holding a plant
#   g8kc: mark ground no plant the player owns can use
#
# The argument for why these are one cue and not two is in placement_preview.gd's
# matching block. The part that has to be MEASURED rather than argued is here:
# the dead sets are nested, so g8kc's set is always inside tzz7's, so two marks
# on one cell is the guaranteed case rather than an edge case -- and two bars at
# DEAD_BAR_ANGLE is already the redundancy cue's picture.
#
# Everything below is a pure static or a node read. `GardenTheme.animations_enabled()`
# is false for the whole suite and headless paints no frame, so the marks are
# Line2D children with real `points` and these tests assert where the ink lands
# without a `_draw()` ever running.
# =============================================================================

## Cells dead for the whole catalogue's longest reach -- recorded so a road
## reshape has to come past this list, the way the 11 and the 36 already do.
## Bottom-right corner: the road's last leg runs along row 3 to the east edge and
## turns nothing back down, so the corner under it is out of even a 192 px throw.
## ROW-MAJOR -- sorted by y then x, which is the order dead_ground_cells() walks
## the board in. Recorded here column-first the first time and caught on the first
## real run: the SET was right and only the order was wrong, which an equality
## assertion cannot tell apart from a wrong answer.
const G8KC_DEAD_FOR_EVERYTHING: Array[Vector2i] = [
	Vector2i(13, 7), Vector2i(12, 8), Vector2i(13, 8),
]


func _cells_to_text(cells: Array[Vector2i]) -> String:
	var parts: Array[String] = []
	for cell: Vector2i in cells:
		parts.append("(%d,%d)" % [cell.x, cell.y])
	return "[" + ", ".join(parts) + "]"


func _same_cells(actual: Array[Vector2i], expected: Array[Vector2i], what: String) -> String:
	var err: String = _T.assert_eq(actual.size(), expected.size(),
		("%s: %d cells, expected %d. got %s want %s")
			% [what, actual.size(), expected.size(), _cells_to_text(actual),
				_cells_to_text(expected)])
	if err != "":
		return err
	for i: int in range(expected.size()):
		err = _T.assert_eq(actual[i], expected[i],
			"%s: cell %d of %d" % [what, i, expected.size()])
		if err != "":
			return err
	return ""


## tzz7's acceptance, and the only version of it worth having: the board-wide
## answer is not merely plausible, it is the SAME answer the hover cue gives,
## plant by plant, cell by cell, across the whole catalogue.
##
## Driven through the live PlacementPreview node rather than through
## covers_road() directly, because shows_dead_zone() is what a player actually
## sees and it carries the legality term the geometry does not.
func test_the_board_wide_dead_ground_matches_the_hover_cue_plant_by_plant() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var preview: PlacementPreview = _preview(game)
	var err: String = _T.assert_true(preview != null, "the game built a placement preview")
	if err != "":
		_T.free_ui(game)
		return err
	preview.board = game.board
	preview.placeable = true
	var plants_with_dead_ground: int = 0
	for id: StringName in PlantCatalog.ids():
		var reach: float = PlantCatalog.reach(id)
		preview.reach = reach
		preview.plant_id = id
		var by_hover: Array[Vector2i] = []
		for y: int in range(Board.ROWS):
			for x: int in range(Board.COLS):
				var cell := Vector2i(x, y)
				if not game.board.is_buildable(cell):
					continue
				preview.position = game.board.cell_to_world(cell)
				if preview.shows_dead_zone():
					by_hover.append(cell)
		var by_board: Array[Vector2i] = PlacementPreview.dead_ground_cells(game.board, reach)
		if not by_hover.is_empty():
			plants_with_dead_ground += 1
		err = _same_cells(by_board, by_hover,
			("the board cue and the hover cue disagree for %s (reach %.1f)")
				% [PlantCatalog.display_name(id), reach])
		if err != "":
			break
	if err == "":
		# Vacuity guard. Every plant answering "no dead ground anywhere" would
		# make the comparison above pass on eight empty lists.
		err = _T.assert_gt(plants_with_dead_ground, 0,
			"at least one plant in the catalogue has dead ground to disagree about")
	_T.free_ui(game)
	return err


## The measurement the whole one-cue design rests on: dead ground is MONOTONE in
## reach, so the dead sets nest, so g8kc's set is inside tzz7's for every plant
## the player owns and a cell can never want two marks.
##
## Also the place the max-reach shortcut is allowed to be a coincidence.
## dead_for_every_reaching_plant() does a genuine intersection; this asserts it
## equals dead_ground_cells(longest_reach), which is the property that would
## quietly stop holding the day a reach stops being a plain radius.
func test_the_dead_sets_are_nested_so_the_two_cues_can_never_be_two_marks() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var ids: Array[StringName] = PlantCatalog.ids()
	# Reaching plants only, shortest first, and keyed on the REACH rather than on
	# the plant: two plants at the same radius make one rung of the ladder, not
	# two. A Sunflower has no reach and so no dead ground at all -- it is not part
	# of this ordering, it is outside it.
	var named: Dictionary = {}
	var rungs: Array[float] = []
	for id: StringName in PlacementPreview.reaching_ids(ids):
		var r: float = PlantCatalog.reach(id)
		if not named.has(r):
			named[r] = PlantCatalog.display_name(id)
			rungs.append(r)
	rungs.sort()
	var err: String = _T.assert_gt(rungs.size(), 1,
		"there are at least two distinct reaches to nest -- one would be vacuous")
	if err == "":
		for i: int in range(rungs.size() - 1):
			var shorter: Array[Vector2i] = PlacementPreview.dead_ground_cells(
				game.board, rungs[i])
			var longer: Array[Vector2i] = PlacementPreview.dead_ground_cells(
				game.board, rungs[i + 1])
			var escaped: Array[Vector2i] = []
			for cell: Vector2i in longer:
				if not shorter.has(cell):
					escaped.append(cell)
			err = _T.assert_eq(escaped.size(), 0,
				("dead ground for %s (%.1f px) must be inside dead ground for %s (%.1f px); "
					+ "these escaped: %s. The nesting is what stops the resting cue and the "
					+ "hover cue ever wanting two bars on one cell")
					% [named[rungs[i + 1]], rungs[i + 1], named[rungs[i]], rungs[i],
						_cells_to_text(escaped)])
			if err != "":
				break
	if err == "":
		err = _T.assert_float_eq(PlacementPreview.longest_reach(ids), Dandelion.RANGE, 0.001,
			"the catalogue's longest reach is the Bomb Dandelion's throw")
	if err == "":
		err = _same_cells(
			PlacementPreview.dead_for_every_reaching_plant(game.board, ids),
			PlacementPreview.dead_ground_cells(game.board, PlacementPreview.longest_reach(ids)),
			("the intersection over every reaching plant equals the longest reach's own "
				+ "dead set -- if this parts, the nesting above has stopped holding and "
				+ "the cheap answer has started lying"))
	if err == "":
		err = _same_cells(
			PlacementPreview.dead_for_every_reaching_plant(game.board, ids),
			G8KC_DEAD_FOR_EVERYTHING,
			("the cells dead for every reaching plant in the catalogue. Three, in the "
				+ "bottom-right corner. Re-derive if PATH_CORNERS moves"))
	_T.free_ui(game)
	return err


## g8kc's acceptance, in its own words: the resting cue is derived from the
## catalogue's maximum reach, and it SHRINKS when a longer-reach plant unlocks.
##
## Note which unlock does nothing. Adding the Chomp Flower -- 73.6 px, the
## shortest reach in the game -- moves the count not at all, because the set is
## an intersection and the longest reach already owns it. That is the assertion
## worth having: a test that only unlocked the Dandelion would pass on a cue that
## took the union by mistake.
func test_the_resting_cue_shrinks_as_a_longer_reach_unlocks() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var owned: Array[StringName] = PlantCatalog.starting_unlocks()
	var err: String = _T.assert_eq(owned.size(), 1,
		"a run starts owning exactly one plant, got %s" % [owned])
	if err == "":
		err = _T.assert_eq(owned[0], PlantCatalog.CORN, "and it is the Corn Cobbler")
	if err == "":
		err = _T.assert_eq(
			PlacementPreview.dead_for_every_reaching_plant(game.board, owned).size(), 11,
			("with only a Corn Cobbler owned the board marks its 11 dead cells -- the same "
				+ "11 test_the_real_route_strands_exactly_the_cells_it_was_measured_to_strand "
				+ "measures"))
	if err == "":
		owned.append(PlantCatalog.CHOMP)
		err = _T.assert_eq(
			PlacementPreview.dead_for_every_reaching_plant(game.board, owned).size(), 11,
			("unlocking the Chomp Flower changes nothing: 36 cells are dead for a 73.6 px "
				+ "grab, but the resting cue is an INTERSECTION, so a shorter reach can only "
				+ "ever re-mark ground the longer one already marked"))
	if err == "":
		owned.append(PlantCatalog.DANDELION)
		err = _T.assert_eq(
			PlacementPreview.dead_for_every_reaching_plant(game.board, owned).size(), 3,
			("unlocking the Bomb Dandelion's 192 px throw shrinks it to 3 -- the cue got "
				+ "SMALLER because the garden got stronger, which is the whole claim"))
	if err == "":
		# The mode switch, both ways, which is what makes this one cue rather than two.
		err = _same_cells(
			PlacementPreview.board_dead_cells(game.board, &"", owned),
			PlacementPreview.dead_for_every_reaching_plant(game.board, owned),
			"nothing hovered: the board shows what nothing the player owns can use")
	if err == "":
		err = _same_cells(
			PlacementPreview.board_dead_cells(game.board, PlantCatalog.CHOMP, owned),
			PlacementPreview.dead_ground_cells(game.board,
				PlantCatalog.reach(PlantCatalog.CHOMP)),
			("a Chomp Flower hovered in the shop: the board answers about the CHOMP, all 36 "
				+ "cells of it, not about the garden"))
	if err == "":
		err = _T.assert_eq(
			PlacementPreview.board_dead_cells(game.board, PlantCatalog.DANDELION, owned).size(),
			3,
			("and hovering a longer reach than anything owned answers about THAT plant, 3 "
				+ "cells -- not the union with the resting 3, and not the resting 11 either"))
	_T.free_ui(game)
	return err


## The finding, pinned so nobody re-reads g8kc's title as the truth. The bead says
## "ground no plant in the catalogue can use ... it is scenery, permanently". It is
## not scenery. It is the best Seed Sunflower ground on the board, and the
## Sunflower's own blurb sends the player there: "plant it somewhere the lane
## doesn't need".
##
## So the cue speaks for the plants whose dead-ground question means anything --
## the ones with a reach -- and the test that would have caught a cue calling
## those three cells unusable is this one.
func test_the_resting_cue_never_calls_sunflower_ground_scenery() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_float_eq(PlantCatalog.reach(PlantCatalog.SUNFLOWER), 0.0, 0.001,
		"a Seed Sunflower reaches nothing")
	if err == "":
		err = _T.assert_eq(PlacementPreview.dead_ground_cells(game.board,
			PlantCatalog.reach(PlantCatalog.SUNFLOWER)).size(), 0,
			("so no cell is dead ground for one -- covers_road() answers true at reach 0 and "
				+ "the board-wide cue inherits that rather than re-deciding it"))
	if err == "":
		err = _T.assert_false(
			PlacementPreview.reaching_ids(PlantCatalog.ids()).has(PlantCatalog.SUNFLOWER),
			"and it is dropped from the population the resting cue speaks for")
	if err == "":
		err = _T.assert_eq(
			PlacementPreview.reaching_ids(PlantCatalog.ids()).size(), PlantCatalog.ids().size() - 1,
			("the Sunflower is the ONLY entry dropped -- if a second reachless plant is added "
				+ "this cue quietly stops speaking for it too, and that should be a decision"))
	if err == "":
		var scenery := Vector2i(13, 8)
		err = _T.assert_true(
			PlacementPreview.dead_for_every_reaching_plant(game.board,
				PlantCatalog.ids()).has(scenery),
			"(13, 8) is dead for every reaching plant in the catalogue")
	if err == "":
		# And it is legal ground, which is what makes the "scenery" reading wrong
		# rather than merely imprecise.
		err = _T.assert_true(game.board.is_buildable(Vector2i(13, 8)),
			"and a plant may still stand there, which is why the mark is not 'unusable'")
	_T.free_ui(game)
	return err


## The grammar, asserted rather than argued: the board's mark IS the hover bar's
## stroke, so a cell carrying both shows one bar and never the two parallel bars
## that mean "redundant patch".
##
## Headless never runs `_draw()`, so this reads the Line2D children the Board
## actually builds. Their endpoints are the same two points `_draw_dead_bar()`
## passes to draw_line(), offset to the cell -- which is the only way to check a
## cue whose whole defence is "these two marks coincide".
func test_the_board_mark_and_the_hover_bar_are_one_stroke_not_two() -> String:
	var board := Board.new()
	# NOT named `arm`: suite_reach_check matches by bare token, and
	# SelectionMarker declares an unreached `arm` that a local of that name
	# silently credits -- which is a false entry in the debt list, not a test.
	var bar_arm: Vector2 = PlacementPreview.dead_bar_arm()
	var cells: Array[Vector2i] = PlacementPreview.dead_ground_cells(board,
		PlantCatalog.reach(PlantCatalog.CORN))
	var err: String = _T.assert_gt(cells.size(), 0,
		"there is dead ground to mark -- an empty set would make every check below vacuous")
	if err == "":
		err = _T.assert_true(board.mark_dead_ground(cells, bar_arm,
			PlacementPreview.board_dead_color(), PlacementPreview.DEAD_BAR_WIDTH),
			"marking a fresh board reports the set as changed")
	if err == "":
		err = _same_cells(board.dead_ground_marked(), cells,
			"the board holds exactly the cells it was handed")
	var lines: Array[Line2D] = board.dead_ground_mark_lines()
	if err == "":
		err = _T.assert_eq(lines.size(), cells.size(),
			("one visible mark per dead cell -- %d marks for %d cells"
				% [lines.size(), cells.size()]))
	if err == "":
		for i: int in range(cells.size()):
			var centre: Vector2 = board.cell_to_world(cells[i])
			var pts: PackedVector2Array = lines[i].points
			err = _T.assert_eq(pts.size(), 2,
				"mark %d is a straight two-point stroke, not a shape" % i)
			if err == "":
				err = _T.assert_float_eq(pts[0].distance_to(centre - bar_arm), 0.0, 0.001,
					"mark %d starts where _draw_dead_bar() would start" % i)
			if err == "":
				err = _T.assert_float_eq(pts[1].distance_to(centre + bar_arm), 0.0, 0.001,
					"mark %d ends where _draw_dead_bar() would end" % i)
			if err == "":
				# The claim in one number: the mark and the hover bar are the same
				# line, so their perpendicular separation is zero. The redundancy cue
				# is the same stroke at REDUNDANT_BAR_GAP apart, and a nonzero gap
				# here would be that cue said by accident.
				err = _T.assert_float_eq(
					((pts[0] + pts[1]) * 0.5).distance_to(centre), 0.0, 0.001,
					("mark %d is centred on the cell, so it lies ON the hover bar rather "
						+ "than beside it -- any separation at all is the redundant-patch "
						+ "cue drawn by mistake") % i)
			if err == "":
				err = _T.assert_float_eq(lines[i].width, PlacementPreview.DEAD_BAR_WIDTH, 0.001,
					"mark %d is the dead bar's own width" % i)
			if err != "":
				break
	if err == "":
		err = _T.assert_gt(PlacementPreview.REDUNDANT_BAR_GAP, 0.0,
			("and the picture it must not become is a real one: two bars "
				+ "REDUNDANT_BAR_GAP apart on this same angle"))
	if err == "":
		# Colour is the channel the grammar says may not carry meaning alone, so
		# the ambient mark is allowed to be dimmer -- but only dimmer.
		err = _T.assert_float_eq(PlacementPreview.board_dead_color().a,
			PlacementPreview.BOARD_DEAD_ALPHA, 0.001,
			"the ambient mark is the dead slate at BOARD_DEAD_ALPHA")
	if err == "":
		err = _T.assert_gt(PlacementPreview.DEAD_COLOR.a, PlacementPreview.BOARD_DEAD_ALPHA,
			("and it is the quieter of the two: up to 36 ambient marks sit under one "
				+ "focused hover bar, so the hovered cell has to win"))
	board.free()
	return err


## The pool, because this cue redraws on every shop hover and Game._refresh()
## fires on every seed payout. A mark set that queue_free()d and rebuilt would
## read as node churn on `performance --by-type`, which is the only signal an
## in-tree accumulation gives.
func test_remarking_dead_ground_reuses_its_marks_instead_of_growing_the_board() -> String:
	var board := Board.new()
	# NOT named `arm`: suite_reach_check matches by bare token, and
	# SelectionMarker declares an unreached `arm` that a local of that name
	# silently credits -- which is a false entry in the debt list, not a test.
	var bar_arm: Vector2 = PlacementPreview.dead_bar_arm()
	var colour: Color = PlacementPreview.board_dead_color()
	var width: float = PlacementPreview.DEAD_BAR_WIDTH
	var wide: Array[Vector2i] = PlacementPreview.dead_ground_cells(board,
		PlantCatalog.reach(PlantCatalog.CHOMP))
	var narrow: Array[Vector2i] = PlacementPreview.dead_ground_cells(board,
		PlantCatalog.reach(PlantCatalog.DANDELION))
	var err: String = _T.assert_eq(wide.size(), 36, "36 cells are dead for a Chomp Flower")
	if err == "":
		err = _T.assert_eq(narrow.size(), 3, "and 3 for a Bomb Dandelion")
	if err == "":
		board.mark_dead_ground(wide, bar_arm, colour, width)
	var layer: Node2D = board.get_node_or_null(Board.DEAD_GROUND_LAYER) as Node2D
	if err == "":
		err = _T.assert_true(layer != null, "marking built the marks layer")
	var pool: int = layer.get_child_count() if layer != null else -1
	if err == "":
		err = _T.assert_eq(pool, 36, "one Line2D per marked cell, %d built" % pool)
	if err == "":
		err = _T.assert_false(board.mark_dead_ground(wide, bar_arm, colour, width),
			("re-marking the identical set reports no change, so Game._refresh() on every "
				+ "seed payout does not rebuild the pool several times a second"))
	if err == "":
		err = _T.assert_true(board.mark_dead_ground(narrow, bar_arm, colour, width),
			"shrinking the set does report a change")
	if err == "":
		err = _T.assert_eq(layer.get_child_count(), pool,
			("and shrinks by HIDING, not by freeing: the pool is still %d nodes" % pool))
	if err == "":
		err = _T.assert_eq(board.dead_ground_mark_lines().size(), 3,
			"with only 3 of them visible")
	if err == "":
		err = _T.assert_true(board.mark_dead_ground(wide, bar_arm, colour, width),
			"growing back reports a change")
	if err == "":
		err = _T.assert_eq(layer.get_child_count(), pool,
			("and reuses the hidden marks rather than adding 36 more -- the pool is still "
				+ "%d nodes after a full shrink-and-grow cycle" % pool))
	if err == "":
		err = _T.assert_eq(board.dead_ground_mark_lines().size(), 36,
			"with all 36 visible again")
	if err == "":
		# A road cell is not ground a plant can be dead on, so it is dropped the way
		# mark_unaimed_road() drops non-road.
		var road: Array[Vector2i] = [board.road_cells()[0]]
		board.mark_dead_ground(road, bar_arm, colour, width)
		err = _T.assert_false(board.is_dead_ground(road[0]),
			"a mark handed a road cell drops it rather than rendering it")
	if err == "":
		err = _T.assert_eq(board.dead_ground_mark_lines().size(), 0,
			"leaving nothing visible, which is also how the cue is cleared")
	board.free()
	return err

# END plant-tower-defense-tzz7 / plant-tower-defense-g8kc
# =============================================================================


## The hover actually reaches the board.
##
## The cue and its trigger were built in different places — the marks in a lane that
## owned `board.gd`/`placement_preview.gd`, the hover in `hud.gd` and `game.gd`,
## which that lane was forbidden. A cue nothing turns on is the failure this project
## has shipped before, and it is invisible: every gate passes, the marks are correct,
## and no player ever sees one.
##
## So this asserts the JOIN, not the ends. `suite_reach_check` reported
## `plant_hovered` as public-and-unnamed the moment the signal landed, which is what
## sent this test here (plant-tower-defense-tzz7).
func test_the_shop_hover_is_wired_to_the_boards_dead_ground() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the game scene resolves headlessly")
	if err != "":
		return err
	if err == "":
		# Named as CODE, not as a string: suite_reach_check blanks string bodies, so
		# has_signal("plant_hovered") reads as a caption and credits nothing. Its own
		# NOT COVERED line says so, and it kept reporting this signal unreached until
		# the reference below became an identifier.
		err = _T.assert_true(game.hud.plant_hovered.get_name() == &"plant_hovered",
			"the HUD declares the hover signal the board's marks listen for")
	if err == "":
		err = _T.assert_true(
			game.hud.plant_hovered.is_connected(Callable(game, "_on_plant_hovered")),
			("and Game is actually listening -- without this connection the marks are"
				+ " correct, every gate passes, and no player ever sees one"))
	if err == "":
		# And the join carries a value, not just a wire: hovering a long-reach plant
		# must change which cells are marked away from the resting set.
		var resting: Array[Vector2i] = PlacementPreview.board_dead_cells(
			game.board, &"", game.bank.unlocked)
		var hovered: Array[Vector2i] = PlacementPreview.board_dead_cells(
			game.board, PlantCatalog.CHOMP, game.bank.unlocked)
		err = _T.assert_true(resting != hovered,
			("hovering the Chomp asks a different question than the resting board"
				+ " (%d cells against %d)") % [hovered.size(), resting.size()])
	_T.free_ui(game)
	return err


# =============================================================================
# BEGIN plant-tower-defense-a6rf: covered is not served.
#
# The cue's own argument lives in game/placement_preview.gd's a6rf block; this
# is what holds it up. Everything here runs with NO frame drawn and NO wave
# running, which is the requirement rather than a convenience:
# GardenTheme.animations_enabled() is false for the whole suite and headless
# paints no `_draw()`, so "which cells would be marked" has to be answerable off
# the derivation and off the Line2D children the Board actually builds.
# =============================================================================

## A gun on (4, 2) is the smallest garden that says anything: a cob there reaches
## ten road cells and is the only thing covering any of them, so nine of the ten
## are behind something in its own queue and one -- its deepest -- is not.
##
## Recorded rather than derived, and guarded below by re-deriving what it claims:
## the cell must still be buildable and the coverage must still be ten, or the
## nine stops meaning what it says. Same discipline as test_combat.gd's
## test_the_recorded_gardens_still_have_the_property_they_claim, which exists
## because cycle 53 reshaped the road and two recorded gardens went stale in
## silence.
const A6RF_LONE_GUN := Vector2i(4, 2)
const A6RF_LONE_GUN_COVERS: int = 10
const A6RF_LONE_GUN_DEFERS: int = 9
## The deepest road cell that gun reaches -- the one cell of the ten a pest is
## actually shot at on, because nothing the gun covers is further along.
const A6RF_LONE_GUN_SERVES := Vector2i(3, 4)

## The seven-cob garden test_combat.gd records as reaching every one of the 32
## road cells. Copied rather than shared because that list is a method on another
## suite; the copy is guarded by re-asserting the property it is copied FOR (all
## 32 covered), so a road reshape fails here with a name instead of quietly
## measuring a different garden.
const A6RF_WHOLE_ROAD_GARDEN: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(4, 2), Vector2i(11, 2),
	Vector2i(5, 5), Vector2i(8, 5), Vector2i(3, 6), Vector2i(8, 6),
]
## 24 of the 32. THE number this cue is worth judging on: a garden that reaches
## every cell of the road still leaves three quarters of it standing behind
## something in the queue of the very guns covering it, and that is the 84% the
## instrumented run measured, stated as ground rather than as a percentage.
const A6RF_WHOLE_ROAD_DEFERS: int = 24


## One gun and one list of reaches, built the way Game will build them.
func _a6rf_guns(cells: Array[Vector2i], id: StringName) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for _cell: Vector2i in cells:
		out.append(Game.engagement_reach(id))
	return out


## The whole claim, on the smallest garden that can carry it.
func test_the_deferred_cue_names_the_road_every_gun_covering_it_looks_past() -> String:
	var board := Board.new()
	var guns: Array[Vector2i] = [A6RF_LONE_GUN]
	var err: String = _T.assert_true(board.is_buildable(A6RF_LONE_GUN),
		"the recorded gun cell is still ground a plant may stand on")
	var covers: Array[Vector2i] = PlacementPreview.covered_road_cell_list(board,
		A6RF_LONE_GUN, Game.engagement_reach(PlantCatalog.CORN))
	if err == "":
		err = _T.assert_eq(covers.size(), A6RF_LONE_GUN_COVERS,
			("the recorded gun still reaches %d road cells -- every count below is "
				+ "measured against that") % A6RF_LONE_GUN_COVERS)
	var deferred: Array[Vector2i] = PlacementPreview.deferred_road_cells(board, guns,
		_a6rf_guns(guns, PlantCatalog.CORN))
	if err == "":
		err = _T.assert_eq(deferred.size(), A6RF_LONE_GUN_DEFERS,
			("%d of the %d cells it covers are behind something in its own queue -- "
				+ "one pest further along inside the same ring and each of them is "
				+ "shot at by nothing") % [A6RF_LONE_GUN_DEFERS, A6RF_LONE_GUN_COVERS])
	if err == "":
		err = _T.assert_false(deferred.has(A6RF_LONE_GUN_SERVES),
			("and %s is NOT marked: it is the deepest road the gun reaches, so a pest "
				+ "standing there is the furthest along in range and gets shot")
				% A6RF_LONE_GUN_SERVES)
	if err == "":
		# The complement, stated as a count so the pair cannot both drift.
		err = _T.assert_eq(covers.size() - deferred.size(), 1,
			"exactly one of the ten is served first, which is one per gun")
	if err == "":
		# Not a claim about uncovered road. That is the off-aim hatch's subject and
		# the two sets must never overlap, or the board says both "nothing reaches
		# here" and "something reaches here but looks past you" on one cell.
		var reached: Dictionary = {}
		for cell: Vector2i in covers:
			reached[cell] = true
		var strays: int = 0
		for cell: Vector2i in deferred:
			if not reached.has(cell):
				strays += 1
		err = _T.assert_eq(strays, 0,
			("every deferred cell is a COVERED cell -- %d of %d were not, which would "
				+ "put this mark on the hatch's ground") % [strays, deferred.size()])
	if err == "":
		err = _T.assert_eq(board.road_cells().size() - covers.size(), 22,
			("and 22 road cells are covered by nothing at all in this garden, which is "
				+ "the hatch's set and is disjoint from the 9 above"))
	board.free()
	return err


## The tutorial, asserted: a second gun behind the first takes a cell OFF the
## warning list, because the two no longer share a deeper cell to look at.
##
## (6, 3) is deferred by the lone cob on (4, 2) -- (6, 4) is further along and
## inside that cob's ring. Add a cob on (7, 2) and (6, 3) is covered by both,
## while (6, 4) is inside only the new one's ring, so no single pest can pull
## both guns away and the mark clears. This is the thing a player is meant to
## learn by watching, and it is why the cue is shown during prep.
func test_a_second_gun_behind_the_first_clears_a_deferred_cell() -> String:
	var board := Board.new()
	var subject := Vector2i(6, 3)
	var alone: Array[Vector2i] = [A6RF_LONE_GUN]
	var paired: Array[Vector2i] = [A6RF_LONE_GUN, Vector2i(7, 2)]
	var err: String = _T.assert_true(board.is_buildable(paired[1]),
		"the second gun's cell is still ground a plant may stand on")
	var before: Array[Vector2i] = PlacementPreview.deferred_road_cells(board, alone,
		_a6rf_guns(alone, PlantCatalog.CORN))
	if err == "":
		err = _T.assert_true(before.has(subject),
			("%s is deferred with one gun -- the positive control, without which the "
				+ "assertion below passes against a cue that stopped firing entirely")
				% subject)
	var after: Array[Vector2i] = PlacementPreview.deferred_road_cells(board, paired,
		_a6rf_guns(paired, PlantCatalog.CORN))
	if err == "":
		err = _T.assert_false(after.has(subject),
			("and NOT deferred once a second gun covers it, because no single pest can "
				+ "pull both guns off it any more"))
	if err == "":
		err = _T.assert_true(before != after,
			"so the marked set moves when the garden does, which is what Game._refresh"
				+ " repushes it for")
	board.free()
	return err


## Empty is a real answer, and this is the garden that gives it.
##
## A Chomp Flower on (4, 2) reaches exactly one road cell, so that cell is the
## deepest road it holds and there is nothing further along for it to look at.
## Nothing is marked -- not because the cue failed to run, which is what the
## positive control on the same cell rules out.
func test_a_gun_that_holds_only_its_deepest_cell_defers_nothing() -> String:
	var board := Board.new()
	var guns: Array[Vector2i] = [A6RF_LONE_GUN]
	var chomp: Array[Vector2i] = PlacementPreview.covered_road_cell_list(board,
		A6RF_LONE_GUN, Game.engagement_reach(PlantCatalog.CHOMP))
	var err: String = _T.assert_eq(chomp.size(), 1,
		"a Chomp on (4, 2) reaches exactly one road cell")
	if err == "":
		err = _T.assert_eq(PlacementPreview.deferred_road_cells(board, guns,
			_a6rf_guns(guns, PlantCatalog.CHOMP)).size(), 0,
			("so it defers nothing -- there is no road further along inside its own "
				+ "ring for it to turn towards"))
	if err == "":
		err = _T.assert_gt(PlacementPreview.deferred_road_cells(board, guns,
			_a6rf_guns(guns, PlantCatalog.CORN)).size(), 0,
			("and the SAME cell with a cob's reach does defer -- so the zero above is a "
				+ "measurement and not a cue that has stopped running"))
	if err == "":
		var none: Array[Vector2i] = []
		err = _T.assert_eq(PlacementPreview.deferred_road_cells(board, none,
			PackedFloat32Array()).size(), 0,
			"a garden with no guns defers nothing, which is the empty-board answer")
	if err == "":
		err = _T.assert_eq(PlacementPreview.deferred_road_cells(null, guns,
			_a6rf_guns(guns, PlantCatalog.CORN)).size(), 0,
			"and a null board answers empty rather than reporting the whole road")
	board.free()
	return err


## The number worth judging the cue on, on a garden that has already won the
## coverage argument.
func test_the_whole_road_garden_still_defers_three_quarters_of_the_road() -> String:
	var board := Board.new()
	var road: int = board.road_cells().size()
	var err: String = _T.assert_eq(road, 32,
		"the road is still 32 cells, which every count here is a fraction of")
	for at: Vector2i in A6RF_WHOLE_ROAD_GARDEN:
		if err != "":
			break
		err = _T.assert_true(board.is_buildable(at),
			("the recorded garden's %s is somewhere a plant may still stand -- a cell "
				+ "that has become road would make this a smaller garden with every "
				+ "number still reporting") % at)
	var reach: float = Game.engagement_reach(PlantCatalog.CORN)
	if err == "":
		var union: Dictionary = {}
		for at: Vector2i in A6RF_WHOLE_ROAD_GARDEN:
			for cell: Vector2i in PlacementPreview.covered_road_cell_list(board, at, reach):
				union[cell] = true
		err = _T.assert_eq(union.size(), road,
			("the recorded garden still reaches every one of the %d road cells -- that "
				+ "property is the whole reason it is the garden this is measured on")
				% road)
	if err == "":
		var deferred: Array[Vector2i] = PlacementPreview.deferred_road_cells(board,
			A6RF_WHOLE_ROAD_GARDEN,
			_a6rf_guns(A6RF_WHOLE_ROAD_GARDEN, PlantCatalog.CORN))
		err = _T.assert_eq(deferred.size(), A6RF_WHOLE_ROAD_DEFERS,
			("%d of the %d road cells are deferred even though all %d are covered -- "
				+ "this is the board half of RunSummary.reach_note_text(), and if it "
				+ "ever reads 0 the cue has been deleted rather than satisfied")
				% [A6RF_WHOLE_ROAD_DEFERS, road, road])
	if err == "":
		err = _T.assert_eq(road - A6RF_WHOLE_ROAD_DEFERS, 8,
			("leaving 8 cells served first against 7 guns -- roughly one apiece, which "
				+ "is the arithmetic the mechanic actually has"))
	board.free()
	return err


## The ink, read off the Line2D children the Board builds rather than off a
## `_draw()` no headless run ever calls.
##
## This is the assertion that would have caught the mark drawn 72 px out of place
## that this repo has already shipped: it pairs each bar's points against
## Board.lane_bar_points() at that cell's own centre, so a bar in the right shape
## in the wrong place fails.
func test_the_board_draws_one_bar_across_the_lane_per_deferred_cell() -> String:
	var board := Board.new()
	var guns: Array[Vector2i] = [A6RF_LONE_GUN]
	# NOT named `arm`: suite_reach_check matches by bare token and SelectionMarker
	# declares an unreached `arm` that a local of that name silently credits.
	var arm_px: float = PlacementPreview.DEFERRED_BAR_ARM
	var ink: Color = PlacementPreview.deferred_road_color()
	var width: float = PlacementPreview.DEFERRED_BAR_WIDTH
	var cells: Array[Vector2i] = PlacementPreview.deferred_road_cells(board, guns,
		_a6rf_guns(guns, PlantCatalog.CORN))
	var err: String = _T.assert_eq(cells.size(), A6RF_LONE_GUN_DEFERS,
		"there is deferred road to mark -- an empty set makes every check below vacuous")
	if err == "":
		err = _T.assert_true(board.mark_deferred_road(cells, arm_px, ink, width),
			"marking a fresh board reports the set as changed")
	if err == "":
		err = _same_cells(board.deferred_road_marked(), cells,
			"the board holds exactly the cells it was handed, in walk order")
	var lines: Array[Line2D] = board.deferred_road_mark_lines()
	if err == "":
		err = _T.assert_eq(lines.size(), cells.size(),
			"one visible bar per deferred cell -- %d bars for %d cells"
				% [lines.size(), cells.size()])
	if err == "":
		for i: int in range(cells.size()):
			var axis: Vector2 = board.lane_axis(cells[i])
			var want: PackedVector2Array = Board.lane_bar_points(
				board.cell_to_world(cells[i]), axis, arm_px)
			var got: PackedVector2Array = lines[i].points
			err = _T.assert_eq(got.size(), 2, "bar %d is a two-point stroke" % i)
			if err == "":
				err = _T.assert_true(got[0].is_equal_approx(want[0])
					and got[1].is_equal_approx(want[1]),
					("bar %d lands on %s's own centre: drew %s..%s, wanted %s..%s")
						% [i, cells[i], got[0], got[1], want[0], want[1]])
			if err == "":
				# ACROSS the lane, which is the channel that survives the colour being
				# thrown away: nothing else this board draws is square to the road.
				err = _T.assert_float_eq((got[1] - got[0]).normalized().dot(axis), 0.0,
					0.001, "bar %d is square to the lane at %s" % [i, cells[i]])
			if err == "":
				err = _T.assert_float_eq(got[0].distance_to(got[1]), arm_px * 2.0, 0.001,
					"bar %d is %.0f px long" % [i, arm_px * 2.0])
			if err == "":
				err = _T.assert_float_eq(lines[i].width, width, 0.001,
					"bar %d carries the cue's width" % i)
			if err != "":
				break
	var pool: int = 0
	if err == "":
		var layer: Node2D = board.get_node_or_null(Board.DEFERRED_ROAD_LAYER) as Node2D
		err = _T.assert_true(layer != null,
			"the marks live on their own layer, added last so they sit over the hatch")
		if err == "":
			pool = layer.get_child_count()
			err = _T.assert_eq(pool, cells.size(), "the pool is %d nodes" % cells.size())
	if err == "":
		err = _T.assert_false(board.mark_deferred_road(cells, arm_px, ink, width),
			("re-marking the identical set reports no change, so Game._refresh() on "
				+ "every seed payout does not rebuild the pool several times a second"))
	if err == "":
		var narrow: Array[Vector2i] = [cells[0]]
		err = _T.assert_true(board.mark_deferred_road(narrow, arm_px, ink, width),
			"shrinking the set does report a change")
		if err == "":
			err = _T.assert_eq(board.deferred_road_mark_lines().size(), 1,
				"and shrinks by HIDING: one bar visible")
		if err == "":
			var layer: Node2D = board.get_node_or_null(Board.DEFERRED_ROAD_LAYER) as Node2D
			err = _T.assert_eq(layer.get_child_count(), pool,
				"with the pool still %d nodes rather than freed and rebuilt" % pool)
	if err == "":
		err = _T.assert_true(board.is_deferred_road(cells[0]),
			"and the read-back answers from the Board's own copy, not from the layer")
	if err == "":
		# Buildable ground is not ground a pest queues on, so it is dropped the way
		# mark_dead_ground() drops road.
		var grass: Array[Vector2i] = [Vector2i(0, 0)]
		board.mark_deferred_road(grass, arm_px, ink, width)
		err = _T.assert_false(board.is_deferred_road(grass[0]),
			"a mark handed buildable ground drops it rather than rendering it")
		if err == "":
			err = _T.assert_eq(board.deferred_road_mark_lines().size(), 0,
				"leaving nothing visible, which is also how the cue is cleared")
	board.free()
	return err


## The two-channel rule, mechanically. This cue and the dead-ground bar are the
## same grammar row ("straight line through a box = a STATE"), so what separates
## them has to be something a greyscale screenshot still shows.
func test_the_deferred_bar_is_a_different_mark_from_the_dead_ground_bar() -> String:
	var dead: Vector2 = PlacementPreview.dead_bar_arm()
	# ORIENTATION. The dead bar is a diagonal; every bar this cue draws is square
	# to a road that only ever steps orthogonally, so it is axis-aligned everywhere.
	var err: String = _T.assert_true(absf(dead.x) > 0.5 and absf(dead.y) > 0.5,
		"the dead-ground bar is a diagonal (%s), which is the orientation this cue "
			% dead + "deliberately does not use")
	var board := Board.new()
	var checked: int = 0
	if err == "":
		for cell: Vector2i in board.road_cells():
			var axis: Vector2 = board.lane_axis(cell)
			checked += 1
			err = _T.assert_true(absf(axis.x) < 0.001 or absf(axis.y) < 0.001,
				("the lane at %s runs on an axis (%s) -- an averaged direction would be "
					+ "diagonal at the road's four corners and the bar would stop being "
					+ "distinguishable there") % [cell, axis])
			if err == "":
				err = _T.assert_float_eq(axis.length(), 1.0, 0.001,
					"and it is a unit vector at %s" % cell)
			if err != "":
				break
	if err == "":
		err = _T.assert_eq(checked, board.road_cells().size(),
			"every one of the %d road cells was checked" % board.road_cells().size())
	if err == "":
		err = _T.assert_eq(board.lane_axis(Vector2i(0, 0)), Vector2.ZERO,
			"and buildable ground has no lane direction at all")
	# LENGTH and INK. The deferred set is the denser of the two -- 24 cells of 32
	# against dead ground's 36 of 94 -- so it has to be the lighter mark per cell
	# or the road reads as covered in warnings.
	if err == "":
		var mine: float = PlacementPreview.DEFERRED_BAR_ARM * 2.0 \
			* PlacementPreview.DEFERRED_BAR_WIDTH
		var theirs: float = PlacementPreview.PREVIEW_HALF * 2.0 \
			* PlacementPreview.DEAD_BAR_WIDTH
		err = _T.assert_gt(theirs, mine * 2.0,
			("the deferred bar inks %.0f px^2 against the dead bar's %.0f -- less than "
				+ "half, which is what keeps 24 of them quieter than 36 of those")
				% [mine, theirs])
	# And it is thinner than one off-aim hatch stripe, so a lone bar can never read
	# as a hatch that lost the rest of itself.
	if err == "":
		err = _T.assert_gt(LanePressureOverlay.HATCH_WIDTH,
			PlacementPreview.DEFERRED_BAR_WIDTH,
			"a deferred bar is thinner than one hatch stripe")
	board.free()
	return err


## The mark has to survive the ground it is drawn on, which is the dirt tile and
## not the lawn -- GardenTheme.reads_on_ground() exists because a mark has already
## disappeared into the playfield here once.
func test_the_deferred_bar_reads_on_the_road_it_is_drawn_on() -> String:
	var ink: Color = PlacementPreview.deferred_road_color()
	var err: String = _T.assert_true(GardenTheme.reads_on_ground(Color(ink, 1.0)),
		"the deferred ink clears the luminance floor against both tile hues")
	if err == "":
		err = _T.assert_true(GardenTheme.reads_on(Color(ink, 1.0), GardenTheme.GROUND_DIRT),
			"and against the dirt tile specifically, which is the only ground it lands on")
	if err == "":
		# Louder than the dead marks and deliberately so: those sit on plain grass,
		# this sits under the lane-pressure hatch and, during a wave, under the pests.
		err = _T.assert_gt(PlacementPreview.DEFERRED_ALPHA,
			PlacementPreview.BOARD_DEAD_ALPHA,
			"and is carried at a higher alpha than the dead marks on the grass")
	if err == "":
		err = _T.assert_float_eq(ink.a, PlacementPreview.DEFERRED_ALPHA, 0.001,
			"which is the alpha the colour actually ships with")
	return err


## The cue and its trigger live in different files, and a cue nothing turns on is
## a failure this project has shipped before: every gate passes, the marks are
## correct, and no player ever sees one. So this asserts the JOIN.
##
## It goes RED until Game._refresh() calls into the board's deferred marks. That
## is the point of it -- see test_the_shop_hover_is_wired_to_the_boards_dead_ground
## above, which exists for the same reason and was written the same way.
func test_the_deferred_cue_is_wired_to_the_game() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the game scene resolves headlessly")
	if err != "":
		return err
	if err == "":
		err = _T.assert_eq(game.board.deferred_road_marked().size(), 0,
			"an empty garden has nothing standing behind anything, so nothing is marked")
	if err == "":
		err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, A6RF_LONE_GUN), "",
			"the free starter cob goes in on the recorded gun cell")
	if err == "":
		# place_plant() ends in _refresh(), which is the funnel the marks hang off.
		err = _T.assert_eq(game.board.deferred_road_marked().size(),
			A6RF_LONE_GUN_DEFERS,
			("and the board is marked the moment it lands -- %d cells. A zero here is "
				+ "the wiring, not the derivation: PlacementPreview.deferred_road_cells "
				+ "is asserted directly above and Game._refresh() is what pushes it")
				% A6RF_LONE_GUN_DEFERS)
	if err == "":
		err = _T.assert_eq(game.board.deferred_road_mark_lines().size(),
			A6RF_LONE_GUN_DEFERS,
			"with a visible bar on each of them")
	_T.free_ui(game)
	return err

# END plant-tower-defense-a6rf
# =============================================================================


# =============================================================================
# BEGIN plant-tower-defense-ei83 — the notebook's hints page
#
# A hint is shown exactly once per save and then spent, so the page that gives it
# back has one job and two states, and the two states are the whole test. The
# sentences themselves live in `Hud.HINT_CARDS` and are asserted there
# (test_selftest.gd:15583+); nothing below restates one, it only asserts that the
# page prints what that table says and that what it prints fits the paper.


## The hint list is what the page is rendered off, so the page's own capacity is the
## thing that has to move when the list does.
##
## `hints_capacity()` is 3 against 3 today, which is the same deliberate tightness
## `test_the_milestone_shelf_fits_the_page` guards on the shelf: a FOURTH hint does not
## fit at HINT_ROW_PITCH and must either drop the pitch or split the page, and this is
## what says so rather than the fourth row quietly drawing below the matte.
func test_the_hints_page_has_room_for_every_hint_the_game_can_spend() -> String:
	var wanted: int = Hud.hint_ids().size()
	var err: String = _T.assert_gt(wanted, 0,
		"there are hints to give back — a page rendered off an empty list asserts nothing")
	if err == "":
		err = _T.assert_gte(NotebookScreen.hints_capacity(), wanted,
			("%d hints at HINT_ROW_PITCH %.0f need more than DRAWING_BOX's %.0fpx "
				+ "(capacity %d). Drop the pitch or split the page — do not let the last "
				+ "row draw off the matte")
				% [wanted, NotebookScreen.HINT_ROW_PITCH, NotebookScreen.DRAWING_BOX.size.y,
					NotebookScreen.hints_capacity()])
	if err == "":
		# The bottom of the last row, computed the way `_build_hints` places it.
		var last: float = NotebookScreen.SHELF_ROW_TOP \
			+ float(wanted - 1) * NotebookScreen.HINT_ROW_PITCH \
			+ NotebookScreen.SHELF_TITLE_HEIGHT + NotebookScreen.HINT_NOTE_HEIGHT
		err = _T.assert_gte(NotebookScreen.DRAWING_BOX.size.y, last,
			"the last hint row bottoms out at %.0fpx inside a %.0fpx matte" % [
				last, NotebookScreen.DRAWING_BOX.size.y])
	return err


## The provenance line, counted off the hint list rather than off the save.
##
## Same failure the shelf's version guards and the same reason it can happen: an id
## left in `earned_milestones` by a build that knew a hint this one does not would print
## "4 of 3 seen" if the numerator came from the save.
func test_the_hints_progress_line_counts_the_hint_list_and_not_the_save() -> String:
	var stashed: Dictionary = RunConfig.earned_milestones.duplicate()
	var ids: Array[String] = Hud.hint_ids()
	var total: int = ids.size()
	RunConfig.earned_milestones = {}
	var err: String = _T.assert_eq(NotebookScreen.hints_progress_text(), "0 of %d seen" % total,
		"a save with nothing spent reads as none seen")
	if err == "":
		RunConfig.earned_milestones = {ids[0]: true, "a_hint_from_the_future": true}
		err = _T.assert_eq(NotebookScreen.hints_progress_text(), "1 of %d seen" % total,
			"an id this build has no hint row for is not counted toward the total")
	if err == "":
		# And an ACHIEVEMENT in the save is not a hint either — the two contracts share
		# one dictionary, so counting the dictionary would count milestones as hints.
		RunConfig.earned_milestones = {String(Milestones.TABLE[0]["id"]): true}
		err = _T.assert_eq(NotebookScreen.hints_progress_text(), "0 of %d seen" % total,
			"and a milestone sitting in the same dictionary is not a hint that was seen")
	RunConfig.earned_milestones = stashed
	return err


## The page itself, in both states at once: one hint spent, the rest not.
##
## What it asserts, in the order that matters. The rows say what `Hud` says — the page
## must never teach a rule the message row words differently, which is why the titles
## and notes are compared against `Hud.hint_title` / `Hud.hint_note_text` rather than
## against strings written here. The unseen state survives the colour being thrown
## away: the pip is a different SIZE and the note carries a "Not shown yet — " prefix,
## so a reader who cannot separate the greens still reads which is which. And the note
## of an unseen hint is drawn at the SAME alpha as a seen one, because it is the row a
## player most needs to read — the state is in the prefix, never in the legibility.
func test_the_notebook_hints_page_gives_back_a_hint_that_was_never_shown() -> String:
	var stashed: Dictionary = RunConfig.earned_milestones.duplicate()
	var ids: Array[String] = Hud.hint_ids()
	var err: String = _T.assert_gt(ids.size(), 1,
		"there is more than one hint, so the two states can both be on screen at once")
	if err != "":
		RunConfig.earned_milestones = stashed
		return err
	var seen_id: String = ids[0]
	var unseen_id: String = ids[ids.size() - 1]
	RunConfig.earned_milestones = {seen_id: true}

	var notebook := await _T.instantiate_ui(NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
	var at: int = NotebookScreen.page_for_kind(NotebookScreen.KIND_HINTS)
	err = _T.assert_gt(at, -1, "the notebook has a hints page at all")
	if err != "":
		_T.free_ui(notebook)
		RunConfig.earned_milestones = stashed
		return err
	notebook.go_to(at)
	var hints: Control = notebook.get_node("Hints") as Control
	var source: Label = notebook.get_node("SourceLabel") as Label

	err = _T.assert_true(hints.visible, "and turning to it puts the hints pane up")
	if err == "":
		err = _T.assert_eq(source.text, "1 of %d seen" % ids.size(),
			"with the provenance line saying how much of the page is news, got: %s" % source.text)
	if err == "":
		err = _T.assert_eq(NotebookScreen.pane_label_for(NotebookScreen.KIND_HINTS),
			(notebook.get_node("DrawingPaneLabel") as Label).text,
			"and the left pane relabelled itself off PANE_LABELS rather than keeping the last page's")

	# Every hint has a row, the row says what Hud says, and the row fits the paper.
	var rows: int = 0
	for id: String in ids:
		if err != "":
			break
		var title := hints.get_node_or_null("HintTitle_%s" % id) as Label
		var note := hints.get_node_or_null("HintNote_%s" % id) as Label
		var pip := hints.get_node_or_null("HintPip_%s" % id) as ColorRect
		err = _T.assert_true(title != null and note != null and pip != null,
			"'%s' has a row on the page — a hint with no row is one the player still cannot find" % id)
		if err != "":
			break
		rows += 1
		var shown: bool = id == seen_id
		err = _T.assert_eq(title.text, Hud.hint_title(id),
			"'%s' is titled off Hud.HINT_CARDS, not off a second copy of the sentence" % id)
		if err == "":
			err = _T.assert_eq(note.text, Hud.hint_note_text(id, shown),
				"and its note is Hud's, in the tense that matches whether it was spent")
		if err == "":
			# The title is clip_text, so get_minimum_size() would report ~1px here and
			# the assertion could not fail. Measured through the resolved theme font.
			err = _T.assert_gte(title.size.x, _T.text_width(title),
				"'%s' titles itself inside its column (%.0f of %.0fpx)" % [
					id, _T.text_width(title), title.size.x])
		if err == "":
			var font: Font = note.get_theme_font("font")
			var font_size: int = note.get_theme_font_size("font_size")
			err = _T.assert_true(font != null and font_size > 0,
				"the note resolved a theme font to measure in")
			if err == "":
				# The note WRAPS, which is the one way this page differs from the shelf,
				# so the budget is a height and not a width. clip_text trims an overlong
				# note silently — on the page whose whole job is carrying the instruction.
				var needed: Vector2 = font.get_multiline_string_size(
					note.text, HORIZONTAL_ALIGNMENT_LEFT, note.size.x, font_size)
				err = _T.assert_gte(note.size.y, needed.y,
					"'%s' wraps to %.0fpx in a %.0fpx box — trim the card or grow HINT_NOTE_HEIGHT"
						% [id, needed.y, note.size.y])
		if err == "":
			var bottom: float = note.position.y + note.size.y
			err = _T.assert_gte(NotebookScreen.DRAWING_BOX.size.y, bottom,
				"'%s' row bottoms out at %.0fpx inside the %.0fpx matte" % [
					id, bottom, NotebookScreen.DRAWING_BOX.size.y])
	if err == "":
		err = _T.assert_eq(rows, ids.size(), "every hint in RunConfig.HINTS was checked")

	# The two states, side by side, with the colour thrown away.
	if err == "":
		var seen_note := hints.get_node("HintNote_%s" % seen_id) as Label
		var unseen_note := hints.get_node("HintNote_%s" % unseen_id) as Label
		err = _T.assert_true(unseen_note.text.begins_with("Not shown yet"),
			"a hint the game never showed says so in words: \"%s\"" % unseen_note.text)
		if err == "":
			err = _T.assert_false(seen_note.text.begins_with("Not shown yet"),
				"and one it did show is left as the card wrote it: \"%s\"" % seen_note.text)
		if err == "":
			# The bead's acceptance, stated as an assertion: the interaction is readable
			# to a player who never saw the prompt. The unshown row is the FULL card with
			# a prefix, not a locked stub.
			err = _T.assert_true(unseen_note.text.ends_with(Hud.hint_note_text(unseen_id, true)
					.substr(1)),
				"and the whole card is still there behind the prefix — nothing is hidden "
					+ "behind having seen it: \"%s\"" % unseen_note.text)
		if err == "":
			err = _T.assert_float_eq(
				unseen_note.get_theme_color("font_color").a,
				seen_note.get_theme_color("font_color").a, 0.001,
				"an unseen hint is not whispered — it is the row that most needs reading")
	if err == "":
		var seen_pip := hints.get_node("HintPip_%s" % seen_id) as ColorRect
		var unseen_pip := hints.get_node("HintPip_%s" % unseen_id) as ColorRect
		err = _T.assert_gt(seen_pip.size.x, unseen_pip.size.x,
			"the pip is a SIZE difference (%s vs %s), not merely a different green"
				% [seen_pip.size, unseen_pip.size])
		if err == "":
			err = _T.assert_float_eq(seen_pip.position.x + seen_pip.size.x / 2.0,
				unseen_pip.position.x + unseen_pip.size.x / 2.0, 0.001,
				"and the two sizes share a centre line, so the column reads as one column")
	_T.free_ui(notebook)
	RunConfig.earned_milestones = stashed
	return err

# END plant-tower-defense-ei83
# =============================================================================
