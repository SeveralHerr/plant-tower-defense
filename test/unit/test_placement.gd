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
			"there is a hand-placed slot for every plant — add an x to TitleScreen.PLANT_X, in x 60-371 or x 781-1092")
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
			# page holds exactly one of four things, and this asserts the other three
			# are down.
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
		# The denominator, which is what makes the four counts above mean anything: a
		# fifth kind added without a branch here would fall through to the plant case and
		# be counted as a plant page, so the sum is the only thing that notices.
		err = _T.assert_eq(drawn_pages + plant_pages + shelf_pages + legend_pages,
			NotebookScreen.PAGES.size(),
			"every page was classified — %d + %d + %d + %d of %d" % [
				drawn_pages, plant_pages, shelf_pages, legend_pages,
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
	# ...and the other direction, which is the one that can go quietly wrong.
	# The loop above walks WORST_CASE_TEXT, so it can only ever fail when a
	# DECLARED readout is missing from the row. A readout added to the row with no
	# declaration is invisible to it, to the hud_readouts budget that sweeps the
	# same table, and to every structural check -- the budget would keep reporting
	# the widest of the four it knows about while a fifth clipped on screen.
	# Same defect the message row shipped twice (plant-tower-defense-mxlt).
	if err == "":
		var undeclared: Array[String] = []
		for child in stats.get_children():
			var stat := child as Label
			if stat != null and not Hud.WORST_CASE_TEXT.has(stat.name):
				undeclared.append(String(stat.name))
		err = _T.assert_true(undeclared.is_empty(),
			("every Label in the row is declared in WORST_CASE_TEXT -- undeclared: %s. "
				+ "Add its worst case there, or the budget measures a row it cannot see "
				+ "all of.") % [undeclared])
	# The row is described by TWO independent hand-lists of the same four
	# readouts: WORST_CASE_TEXT above, and the constants Hud.stats_row_budget()
	# sums (SEEDS + WAVE + LIVES + COMPOST_LABEL_WIDTH). The check above closes
	# the first; a fifth readout would still slip past the second, and
	# hud_stats_row would go on reporting a row narrower than the one on screen.
	# Derive the sum from the Labels themselves so the constants have to agree.
	if err == "":
		var laid_out: float = 0.0
		for child in stats.get_children():
			var stat := child as Label
			if stat != null:
				laid_out += stat.custom_minimum_size.x
		var declared_widths: float = (Hud.SEEDS_LABEL_WIDTH + Hud.WAVE_LABEL_WIDTH
			+ Hud.LIVES_LABEL_WIDTH + Hud.COMPOST_LABEL_WIDTH)
		err = _T.assert_float_eq(laid_out, declared_widths, 0.5,
			("stats_row_budget()'s four width constants add up to the row that is "
				+ "actually laid out (%.0f declared vs %.0f on screen) -- a readout "
				+ "added to the row without a constant makes the budget measure a "
				+ "narrower row than exists") % [declared_widths, laid_out])
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
	for id: StringName in ids:
		if PlantCatalog.reach(id) > 0.0 and not PlantCatalog.engages(id):
			disagreeing.append(id)
	err = _T.assert_gt(disagreeing.size(), 0,
		"at least one plant reaches without engaging, which is why these are two"
			+ " keys. If this ever becomes empty, check it is because the plant"
			+ " changed and not because the keys were collapsed")
	if err == "":
		err = _T.assert_true(disagreeing.has(PlantCatalog.SUNDEW),
			"and the Sundew is one of them (found %s)" % [disagreeing])
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
