extends RefCounted

## Checks written while verifying this session's six features: the compost
## meter, pest mutations, seed packet tiers + the Seed Sunflower, sprite pass
## 2 (eating/dead states), the title screen, and endless mode. Grouped by
## feature rather than by file, since that's how the bd issues were scoped.

const GAME_SCENE := "res://game/game.tscn"
## Clearance the selection box must keep between its own foot and the side panel's.
## Non-zero on purpose: a foot resting exactly on the boundary is a button flush
## with the bottom edge of the screen, which no `<=` assertion will ever object to.
const SELECTION_FOOT_MARGIN: float = 8.0

var _T

## Where this script's RunConfig writes go instead of the player's own save.
## The reasoning is written out once, in test_combat.gd's setup(); both of the
## writers that started this were in THIS file, and neither of them named a
## RunConfig method. `tools/save_persist_check.py` requires this of any test
## script that can reach `RunConfig._save()`.
const SUITE_SAVE_PATH := "user://test_selftest_suite.save"
var _suite_stashed_save_path: String = ""


## The garden speed the player last chose, pinned per test.
##
## `GameSpeed._step` is a STATIC var and `RunConfig.game_speed_step` is autoload state
## loaded from the real save before any `setup()` runs — so between them the chosen
## speed is process-global twice over, and neither the tree nor `free_ui` resets it.
##
## This became load-bearing the moment `Game._ready()` started restoring the remembered
## speed (plant-tower-defense-zgzc): before it, `GameSpeed.reset()` at the top of a test
## was enough; after it, `_ready()` puts the PERSISTED step straight back, so a test that
## reset the static still got whatever speed an earlier test had banked. Two tests failed
## exactly that way on the merge, and both were correct — the game had genuinely stopped
## starting at 1x, which is the feature.
var _suite_stashed_speed_step: int = 0


func setup() -> void:
	_suite_stashed_save_path = RunConfig.save_path
	RunConfig.save_path = SUITE_SAVE_PATH
	_suite_stashed_speed_step = RunConfig.game_speed_step
	RunConfig.game_speed_step = 0
	GameSpeed.reset()


func teardown() -> void:
	if _suite_stashed_save_path != "":
		RunConfig.save_path = _suite_stashed_save_path
	DirAccess.remove_absolute(SUITE_SAVE_PATH)
	RunConfig.game_speed_step = _suite_stashed_speed_step
	# `Engine.time_scale` is process-global: a suite left at 2x retimes every later
	# script's tweens and awaits, which is a failure that shows up nowhere near here.
	GameSpeed.reset()


func _host(nodes: Array[Node]) -> Node2D:
	var container := Node2D.new()
	container.name = "SelfTestHost"
	for node: Node in nodes:
		container.add_child(node)
	return container


func _pest(species: StringName, at: Vector2) -> Pest:
	var pest := Pest.new()
	pest.setup(species, PackedVector2Array([at, at + Vector2(600, 0)]))
	pest.position = at
	pest.set_physics_process(false)
	return pest


func _grass(game: Game) -> Vector2i:
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var cell := Vector2i(x, y)
			if game.board.is_buildable(cell) and game.plant_at(cell) == null:
				return cell
	return Vector2i(-1, -1)


# -- Compost meter (plant-tower-defense-d0w) ---------------------------------


func test_a_dropped_husk_can_be_collected_for_its_value() -> String:
	var compost := CompostMeter.new()
	compost.drop_husk(Vector2(40, 40), 5)
	var got: int = compost.collect_at(Vector2(42, 41))
	var err: String = _T.assert_eq(got, 5, "a click near the husk pays its value")
	if err == "":
		err = _T.assert_eq(compost.husk_count(), 0, "and the husk is gone")
	compost.free()
	return err


func test_a_click_far_from_any_husk_collects_nothing() -> String:
	var compost := CompostMeter.new()
	compost.drop_husk(Vector2.ZERO, 5)
	var got: int = compost.collect_at(Vector2(500, 500))
	var err: String = _T.assert_eq(got, 0, "out of COLLECT_RADIUS pays nothing")
	if err == "":
		err = _T.assert_eq(compost.husk_count(), 1, "and the husk is still there to try again")
	compost.free()
	return err


func test_an_uncollected_husk_rots_away() -> String:
	var compost := CompostMeter.new()
	compost.drop_husk(Vector2.ZERO, 5)
	compost._process(CompostMeter.HUSK_LIFETIME + 0.1)
	var err: String = _T.assert_eq(compost.husk_count(), 0, "a husk left alone past its lifetime disappears")
	if err == "":
		err = _T.assert_eq(compost.collect_at(Vector2.ZERO), 0, "and pays nothing once rotted")
	compost.free()
	return err


## Spawn a pest and hand back THAT pest, not whichever one the group lists first.
##
## `get_nodes_in_group` is tree-global, so `[0]` is whatever the tree lists first
## and not necessarily the node this test just made.
##
## The stranger comes from THIS test, not a previous one. I first wrote here that
## `_T.free_ui` deferred through `queue_free` and leaked across test boundaries.
## It does not — it calls `free()` outright (`tools/run_tests.gd:901`), and a census
## after every one of 358 tests shows no group growing across any boundary. The real
## source is `instantiate_scene`, which pumps settle frames: anything that acts on
## entering the tree has already acted by the time the test body runs.
##
## `test_kernels_launch` is the proof. A `CornCobbler` enters loaded, so hosting one
## beside a pest fires a volley during those settle frames, and its `kernels[0]` was
## that setup kernel rather than the shot under test. It was green for months because
## the setup kernel looked plausible, and only turned red when unrelated tests shifted
## what the tree contained.
##
## Diffing the group around the spawn cannot pick up either kind of stranger, which is
## why it is the fix for both.
func _spawn_and_take(game: Game, species: StringName) -> Pest:
	var before: Dictionary = {}
	for p: Node in game.get_tree().get_nodes_in_group("pests"):
		before[p.get_instance_id()] = true
	game.spawn_pest(species)
	for p: Node in game.get_tree().get_nodes_in_group("pests"):
		if not before.has(p.get_instance_id()) and p is Pest:
			return p as Pest
	return null


func test_a_dead_pest_leaves_a_collectible_husk() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var pest: Pest = _spawn_and_take(game, Pest.APHID)
	if pest == null:
		_T.free_ui(game)
		return _T.assert_true(false, "spawn_pest put a new pest in the pests group")
	var husks_before: int = game.compost.husk_count()
	pest.kill()
	var err: String = _T.assert_eq(game.compost.husk_count(), husks_before + 1, "killing a pest drops exactly one husk")
	_T.free_ui(game)
	return err


# -- Mutated pests drop a better husk (plant-tower-defense-1rh) -------------


func test_husk_multiplier_is_one_for_a_plain_pest() -> String:
	var pest := Pest.new()
	var err: String = _T.assert_eq(pest.husk_multiplier(), 1.0, "no mutation, no bonus")
	pest.free()
	return err


func test_each_mutation_has_a_husk_multiplier_above_one() -> String:
	var pest := Pest.new()
	var err: String = ""
	for mutation: StringName in [Pest.MUTATION_ARMOURED, Pest.MUTATION_WINGED, Pest.MUTATION_HUNGRY]:
		# Through `mutations`, not by assigning `mutation`: since cycle 81 the multiplier
		# is a product over every trait a pest carries, and the primary field is the tint's
		# cache rather than the payout's source.
		pest.mutations = [mutation]
		err = _T.assert_true(pest.husk_multiplier() > 1.0, "%s costs more to deal with, so its husk pays more" % mutation)
		if err != "":
			break
	pest.free()
	return err


## Hungry destroys a plant outright rather than merely delaying it (armoured/
## winged just cost extra effort) — its husk should be worth the most.
func test_a_hungry_mutations_husk_is_worth_more_than_armoured_or_winged() -> String:
	var pest := Pest.new()
	pest.mutations = [Pest.MUTATION_HUNGRY]
	var hungry: float = pest.husk_multiplier()
	pest.mutations = [Pest.MUTATION_ARMOURED]
	var armoured: float = pest.husk_multiplier()
	var err: String = _T.assert_true(hungry > armoured, "hungry's husk bonus is the biggest of the three")
	pest.free()
	return err


## The integration point: Game._on_pest_died actually reads husk_multiplier()
## when it drops a husk, not just that the multiplier exists in isolation.
func test_a_mutated_pests_husk_is_worth_more_than_a_plain_ones() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var plain: Pest = _spawn_and_take(game, Pest.APHID)
	if plain == null:
		_T.free_ui(game)
		return _T.assert_true(false, "spawn_pest put a new pest in the pests group")
	var plain_seed_value: int = plain.seed_value
	plain.kill()
	var plain_husk: int = 0
	for h: Dictionary in game.compost.husks():
		plain_husk = int(h["value"])

	game.spawn_pest(Pest.APHID, [Pest.MUTATION_HUNGRY])
	var mutated: Pest = null
	for node: Node in game.get_tree().get_nodes_in_group("pests"):
		if node != plain:
			mutated = node as Pest
	mutated.kill()
	var mutated_husk: int = 0
	for h: Dictionary in game.compost.husks():
		if int(h["value"]) != plain_husk:
			mutated_husk = int(h["value"])

	var err: String = _T.assert_eq(plain_husk, maxi(1, int(ceil(plain_seed_value / 2.0))), "sanity: the plain pest's husk matches the unmutated formula")
	if err == "":
		err = _T.assert_true(mutated_husk > plain_husk, "the hungry pest's husk is worth strictly more than the plain one")
	_T.free_ui(game)
	return err


# -- Pest mutations from wave 8 (plant-tower-defense-b5k) --------------------


func test_an_armoured_pest_takes_twice_as_long_to_chew() -> String:
	var pest := Pest.new()
	pest.setup(Pest.APHID, PackedVector2Array([Vector2.ZERO, Vector2(10, 0)]))
	var base_chew: float = pest.chew_seconds
	pest.apply_mutation(Pest.MUTATION_ARMOURED)
	return _T.assert_float_eq(pest.chew_seconds, base_chew * 2.0, 0.001,
		"armoured doubles chew_seconds, which is what a Chomp actually reads")


func test_a_winged_pest_flies_over_a_chomps_reach() -> String:
	var chomp := ChompFlower.new()
	var pest: Pest = _pest(Pest.APHID, Vector2(0, -Board.CELL))
	pest.apply_mutation(Pest.MUTATION_WINGED)
	var host: Node2D = _host([chomp, pest])
	await _T.instantiate_scene(host)

	chomp._act(0.016, [pest])
	var err: String = _T.assert_false(chomp.is_busy(), "a winged pest in range is skipped, not grabbed")
	_T.free_ui(host)
	return err


func test_a_hungry_pest_does_not_advance_while_eating_a_plant() -> String:
	var plant := Plant.new()
	plant.setup(PlantCatalog.CORN, Vector2i(0, 0), null)
	plant.position = Vector2(0, -Board.CELL)
	var pest := Pest.new()
	pest.setup(Pest.APHID, PackedVector2Array([Vector2.ZERO, Vector2(600, 0)]))
	pest.apply_mutation(Pest.MUTATION_HUNGRY)
	pest.set_physics_process(false)
	var host: Node2D = _host([plant, pest])
	await _T.instantiate_scene(host)

	var start: Vector2 = pest.position
	pest._physics_process(0.1)
	pest._physics_process(0.1)
	var err: String = _T.assert_eq(pest.position, start, "hungry + adjacent plant means eat, not walk")
	if err == "":
		err = _T.assert_true(plant.health < Plant.MAX_HEALTH, "and the plant actually took damage")
	_T.free_ui(host)
	return err


func test_a_hungry_pest_eventually_destroys_the_plant_it_eats() -> String:
	var plant := Plant.new()
	plant.setup(PlantCatalog.CORN, Vector2i(0, 0), null)
	plant.position = Vector2(0, -Board.CELL)
	var pest := Pest.new()
	pest.setup(Pest.APHID, PackedVector2Array([Vector2.ZERO, Vector2(600, 0)]))
	pest.apply_mutation(Pest.MUTATION_HUNGRY)
	pest.set_physics_process(false)
	var host: Node2D = _host([plant, pest])
	await _T.instantiate_scene(host)

	# A single-element Array, not a bool: GDScript lambdas capture locals by
	# value, so `destroyed = true` inside the closure would mutate a copy and
	# never reach this scope. Mutating the array's contents does.
	var destroyed := [false]
	plant.destroyed.connect(func(_p: Plant) -> void: destroyed[0] = true)
	var seconds_needed: float = Plant.MAX_HEALTH / Pest.EAT_DPS
	var ticks: int = int(ceil(seconds_needed / 0.1)) + 1
	for i: int in range(ticks):
		pest._physics_process(0.1)
	var err: String = _T.assert_true(destroyed[0], "%.1fs at EAT_DPS should finish MAX_HEALTH" % (ticks * 0.1))
	_T.free_ui(host)
	return err


func test_no_mutations_show_up_before_wave_eight() -> String:
	var director := WaveDirector.new()
	director.set_seed(42)
	for w: int in range(1, WaveDirector.MUTATION_START_WAVE):
		director.start_next_wave()
		for entry: Dictionary in director._schedule:
			var err: String = _T.assert_eq(entry["mutation"], &"", "wave %d is before the mutation start wave" % w)
			if err != "":
				director.free()
				return err
	director.free()
	return ""


func test_mutations_appear_from_wave_eight_on() -> String:
	var director := WaveDirector.new()
	director.set_seed(42)
	for w: int in range(1, WaveDirector.MUTATION_START_WAVE):
		director.start_next_wave()
	director.start_next_wave()
	var found: bool = false
	for entry: Dictionary in director._schedule:
		if entry["mutation"] != &"":
			found = true
			break
	director.free()
	return _T.assert_true(found, "with a ~30-pest wave 8 and a 40%% roll per pest, at least one should mutate")


# -- Endless mode mutates faster over time (plant-tower-defense-1qi) --------


func test_mutation_chance_is_flat_through_the_fixed_table() -> String:
	for w: int in range(1, WaveDirector.WAVES.size() + 1):
		var err: String = _T.assert_float_eq(WaveDirector.mutation_chance_for(w), WaveDirector.MUTATION_CHANCE, 0.0001,
			"wave %d is still on the fixed table, so the rate has not started climbing" % w)
		if err != "":
			return err
	return ""


func test_mutation_chance_climbs_the_further_endless_mode_runs() -> String:
	var table_end: int = WaveDirector.WAVES.size()
	var at_table_end: float = WaveDirector.mutation_chance_for(table_end)
	var one_past: float = WaveDirector.mutation_chance_for(table_end + 1)
	var err: String = _T.assert_true(one_past > at_table_end, "the first endless wave already climbs past the flat rate")
	if err == "":
		var ten_past: float = WaveDirector.mutation_chance_for(table_end + 10)
		err = _T.assert_true(ten_past > one_past, "and it keeps climbing the longer endless mode runs")
	return err


func test_mutation_chance_is_capped_so_a_long_run_never_mutates_everything() -> String:
	var far_future: float = WaveDirector.mutation_chance_for(WaveDirector.WAVES.size() + 5000)
	return _T.assert_float_eq(far_future, WaveDirector.MUTATION_CHANCE_MAX, 0.0001,
		"an extremely long endless run stays capped, not creeping toward every pest mutating")


## The point of the escalation, not just the formula: an endless run that has
## gone on a while should actually roll mutations more often than the fixed
## table's flat 40% ever did, aggregated over enough pests that one lucky (or
## unlucky) roll cannot swing the result.
func test_endless_waves_mutate_more_often_than_the_flat_baseline() -> String:
	var director := WaveDirector.new()
	director.endless = true
	director.set_seed(7)
	var mutated: int = 0
	var total: int = 0
	for w: int in range(1, WaveDirector.WAVES.size() + 25):
		director.start_next_wave()
		if director.current_wave < WaveDirector.MUTATION_START_WAVE:
			continue
		for entry: Dictionary in director._schedule:
			total += 1
			if entry["mutation"] != &"":
				mutated += 1
	director.free()
	var err: String = _T.assert_true(total > 200, "sanity: aggregated enough pests (%d) for the ratio to be meaningful" % total)
	if err == "":
		var rate: float = float(mutated) / float(total)
		err = _T.assert_true(rate > WaveDirector.MUTATION_CHANCE + 0.03,
			"aggregate mutation rate across late endless waves (%.2f over %d pests) sits measurably above the flat 40%% baseline" % [rate, total])
	return err


# -- Seed packet tiers + Seed Sunflower (plant-tower-defense-e0w) -----------


func test_a_common_packet_never_rolls_above_tier_one_while_one_remains() -> String:
	## Only Chomp Flower (tier 1) is locked at the start — a common packet must
	## roll it, not skip straight to the tier-2 Sunflower.
	var bank := SeedBank.new()
	bank.set_seed(9)
	bank.add_seeds(500)
	var got: StringName = bank.buy_packet(&"common")
	return _T.assert_eq(got, PlantCatalog.CHOMP, "the only tier-1 plant left is what a common packet rolls")


func test_a_rare_packet_can_reach_the_tier_two_plant() -> String:
	var bank := SeedBank.new()
	bank.set_seed(3)
	bank.add_seeds(int(SeedBank.PACKET_TIERS[&"rare"]["cost"]) * 40)
	var got_sunflower: bool = false
	var guard: int = 0
	while not bank.locked_plants().is_empty() and guard < 40:
		if bank.buy_packet(&"rare") == PlantCatalog.SUNFLOWER:
			got_sunflower = true
		guard += 1
	return _T.assert_true(got_sunflower, "buying rare packets until the garden is complete should reach the Sunflower")


func test_an_unknown_packet_tier_is_refused_not_treated_as_common() -> String:
	var bank := SeedBank.new()
	bank.add_seeds(1000)
	var before: int = bank.seeds
	var got: StringName = bank.buy_packet(&"legendary")
	var err: String = _T.assert_eq(got, &"", "no such tier, nothing rolled")
	if err == "":
		err = _T.assert_eq(bank.seeds, before, "and nothing was charged")
	return err


func test_a_sunflower_grows_seeds_once_its_interval_elapses() -> String:
	var sunflower := Sunflower.new()
	# See the comment on `destroyed` above: a single-element Array survives the
	# lambda's by-value capture where a plain `int` variable would not.
	var got_amount := [-1]
	sunflower.grew_seeds.connect(func(amount: int) -> void: got_amount[0] = amount)
	sunflower._act(Sunflower.INTERVAL + 0.1, [])
	return _T.assert_eq(got_amount[0], Sunflower.YIELD, "one interval elapsed, one payout emitted")


func test_a_sunflower_does_not_pay_out_early() -> String:
	var sunflower := Sunflower.new()
	var fired := [false]
	sunflower.grew_seeds.connect(func(_a: int) -> void: fired[0] = true)
	sunflower._act(Sunflower.INTERVAL - 1.0, [])
	return _T.assert_false(fired[0], "short of the interval, nothing pays out yet")


func test_a_placed_sunflower_is_wired_to_the_bank() -> String:
	## Regression-shaped: Game.place_plant only connects grew_seeds when the
	## plant declares that signal (has_signal check) — miswiring this silently
	## leaves a Sunflower generating signals nobody hears.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.unlocked.append(PlantCatalog.SUNFLOWER)
	game.bank.add_seeds(500)
	var cell: Vector2i = _grass(game)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.SUNFLOWER, cell), "", "planted")
	if err == "":
		var sunflower: Sunflower = game.plant_at(cell) as Sunflower
		var before: int = game.bank.seeds
		sunflower._act(Sunflower.INTERVAL + 0.1, [])
		err = _T.assert_eq(game.bank.seeds, before + Sunflower.YIELD, "the bank actually gained the payout")
	_T.free_ui(game)
	return err


## The payout has to fly from the flower that grew it, and the only thing
## carrying that position is the plant bound into the connection — `grew_seeds`
## itself still emits nothing but an amount (see Game.place_plant).
##
## Asserted on the connection rather than on a glyph because the glyph is gated
## off headless; what is checkable here is that the handler is handed a subject
## with a real board position, and that the payout still lands. A bind whose
## arity stopped matching the handler would leave add_seeds unreached, so the
## bank assertion below is what catches a mis-shaped connection.
func test_a_sunflower_payout_carries_the_flower_it_grew_on() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.unlocked.append(PlantCatalog.SUNFLOWER)
	game.bank.add_seeds(500)
	var cell: Vector2i = _grass(game)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.SUNFLOWER, cell), "", "planted")
	var sunflower: Sunflower = game.plant_at(cell) as Sunflower
	if err == "":
		err = _T.assert_true(sunflower != null, "and the flower is on the board")
	if err == "":
		var bound: Array = []
		for entry: Dictionary in sunflower.get_signal_connection_list("grew_seeds"):
			bound.append_array((entry["callable"] as Callable).get_bound_arguments())
		err = _T.assert_true(bound.has(sunflower),
			"the payout connection binds the flower itself, so the handler has somewhere to fly from")
	if err == "":
		err = _T.assert_eq(sunflower.position, game.board.cell_to_world(cell),
			"and that flower stands on its own cell, not at the board origin")
	if err == "":
		var before: int = game.bank.seeds
		sunflower._act(Sunflower.INTERVAL + 0.1, [])
		err = _T.assert_eq(game.bank.seeds, before + Sunflower.YIELD,
			"a payout through the bound connection still credits the bank")
	if err == "":
		err = _T.assert_eq(game.hud._fx_layer.get_child_count(), 0,
			"and headlessly the glyph the animation gate skipped leaves nothing behind")
	_T.free_ui(game)
	return err


# -- Plant health / hungry-pest wiring through Game --------------------------


func test_game_removes_a_plant_once_its_health_reaches_zero() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var cell: Vector2i = _grass(game)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "", "planted")
	if err == "":
		var plant: Plant = game.plant_at(cell)
		plant.take_damage(Plant.MAX_HEALTH)
		err = _T.assert_true(game.plant_at(cell) == null, "a plant eaten down to 0 health leaves the board")
	_T.free_ui(game)
	return err


func test_a_chewing_chomp_releases_its_meal_if_the_flower_itself_is_destroyed() -> String:
	var chomp := ChompFlower.new()
	chomp.setup(PlantCatalog.CHOMP, Vector2i(0, 0), null)
	var beetle: Pest = _pest(Pest.BEETLE, Vector2.ZERO)
	var host: Node2D = _host([chomp, beetle])
	await _T.instantiate_scene(host)

	chomp._act(0.016, [beetle])
	var err: String = _T.assert_true(chomp.is_busy(), "grabbed the beetle")
	if err == "":
		chomp.take_damage(Plant.MAX_HEALTH)
		err = _T.assert_false(chomp.is_busy(), "destroying the flower mid-chew releases whatever it held")
	_T.free_ui(host)
	return err


# -- Sprite pass 2: damaged/eating/dead states (plant-tower-defense-eeq) ----


func test_a_chomps_sprite_swaps_while_its_mouth_is_full() -> String:
	var chomp := ChompFlower.new()
	chomp.setup(PlantCatalog.CHOMP, Vector2i(0, 0), null)
	# Captured before hosting: set_physics_process(false) on a node that has
	# not yet entered a tree does not stick in Godot 4 (the flag is re-derived
	# on enter-tree), so the settle frames inside instantiate_scene() may run
	# a real physics tick and grab the in-range aphid before anything else in
	# this test gets a turn. Grabbing the idle texture up front sidesteps it.
	var idle_texture: Texture2D = chomp._sprite.texture
	var aphid: Pest = _pest(Pest.APHID, Vector2.ZERO)
	var host: Node2D = _host([chomp, aphid])
	await _T.instantiate_scene(host)

	if not chomp.is_busy():
		chomp._act(0.016, [aphid])
	var err: String = _T.assert_true(chomp.is_busy(), "grabbed the aphid")
	if err == "":
		err = _T.assert_true(chomp._sprite.texture != idle_texture,
			"a separate eating sprite swaps in, not a tint on the idle one")
	if err == "":
		# release() is what a finished chew calls; test the swap-back directly
		# rather than via a real chew timeout, which the same pre-tree settle
		# tick above may have already partly consumed.
		chomp.release()
		err = _T.assert_eq(chomp._sprite.texture, idle_texture, "and swaps back once the mouth empties")
	_T.free_ui(host)
	return err


# -- Second bite frame for a long chew (plant-tower-defense-rrx) ------------


## A beetle's chew (2.6s) is long enough that the last ~40% of it is a
## meaningfully long stretch, not just a flicker — the late frame should be
## showing well before the meal is actually finished.
func test_a_beetle_shows_the_late_bite_frame_past_60_percent_chew() -> String:
	var chomp := ChompFlower.new()
	chomp.setup(PlantCatalog.CHOMP, Vector2i(0, 0), null)
	var beetle: Pest = _pest(Pest.BEETLE, Vector2.ZERO)
	var host: Node2D = _host([chomp, beetle])
	await _T.instantiate_scene(host)

	if not chomp.is_busy():
		chomp._act(0.016, [beetle])
	var mid_texture: Texture2D = chomp._sprite.texture
	var err: String = _T.assert_true(chomp.is_busy(), "grabbed the beetle")
	if err == "":
		# Just under the threshold: still the mid-bite frame.
		chomp._chew(beetle.chew_seconds * 0.5)
		err = _T.assert_eq(chomp._sprite.texture, mid_texture, "under 60%% chewed, still the mid-bite frame")
	if err == "":
		# Cross the threshold.
		chomp._chew(beetle.chew_seconds * 0.2)
		err = _T.assert_true(chomp.is_busy(), "sanity: still chewing, not finished")
	if err == "":
		err = _T.assert_true(chomp._sprite.texture != mid_texture,
			"past 60%% chewed, a distinct 'almost done' frame swaps in")
	_T.free_ui(host)
	return err


## The threshold is a fraction of chew_progress(), so it applies to any
## species — an aphid's whole chew is just short enough that reaching it
## also means the meal is nearly over, not that the frame never appears.
func test_the_late_bite_frame_is_showing_by_the_time_any_chew_finishes() -> String:
	var chomp := ChompFlower.new()
	chomp.setup(PlantCatalog.CHOMP, Vector2i(0, 0), null)
	var aphid: Pest = _pest(Pest.APHID, Vector2.ZERO)
	var host: Node2D = _host([chomp, aphid])
	await _T.instantiate_scene(host)

	if not chomp.is_busy():
		chomp._act(0.016, [aphid])
	var mid_texture: Texture2D = chomp._sprite.texture
	var err: String = _T.assert_true(chomp.is_busy(), "grabbed the aphid")
	if err == "":
		# Just short of finishing (chew_progress() > LATE_BITE_THRESHOLD by
		# construction, since LATE_BITE_THRESHOLD < 1.0), without triggering
		# the kill that a full chew_seconds would.
		chomp._chew(aphid.chew_seconds * 0.9)
		err = _T.assert_true(chomp.is_busy(), "sanity: still chewing")
	if err == "":
		err = _T.assert_true(chomp._sprite.texture != mid_texture,
			"even the aphid's short chew shows the late frame before it ends")
	_T.free_ui(host)
	return err


func test_a_killed_pest_shows_a_dead_sprite_and_lingers_before_freeing() -> String:
	var pest := Pest.new()
	pest.setup(Pest.APHID, PackedVector2Array([Vector2.ZERO, Vector2(100, 0)]))
	var host: Node2D = _host([pest])
	await _T.instantiate_scene(host)

	var idle_texture: Texture2D = pest._sprite.texture
	pest.kill()
	var err: String = _T.assert_true(pest._sprite.texture != idle_texture,
		"the X-eyed corpse is a separate sprite, not the idle one tinted")
	if err == "":
		# PAIRED, and the message now claims only what the pair can check
		# (plant-tower-defense-51eo, which is the finding that produced this line).
		#
		# `is_instance_valid(pest)` ALONE cannot fail here for the reason it used to
		# give. `kill()` frees nothing — it hands the body to a tween, and
		# `queue_free()` defers to the end of the frame — so at zero frames the answer
		# is true whatever the linger is. That was measured, not supposed: deleting the
		# `tween_interval(death_linger())` from `_play_death` outright leaves the old
		# assertion green, with all three of this test's assertions still passing.
		#
		# `is_queued_for_deletion()` is the half that CAN go false, and it does the
		# moment `_play_death` starts queueing the free on the spot instead of handing
		# it to a tween. So this pair checks "not freed instantly" and nothing more,
		# which is what it now says.
		#
		# STILL UNCHECKED ANYWHERE, and measured this cycle rather than assumed: that
		# `_play_death` CONSUMES `death_linger()` at all. The duration itself is well
		# covered as a pure value (`test_combat.gd`, five assertions on
		# `death_linger_for` — its floor, its scaling, and both ends), but the wiring
		# between the two is not: strip the interval out of the tween and every one of
		# those tests stays green too, because they never look at `_play_death`. The
		# pair below would not catch it either — the remaining fade still defers the
		# free. Catching it needs the corpse observed ACROSS time, which is a live
		# check rather than a headless one.
		err = _T.assert_true(is_instance_valid(pest) and not pest.is_queued_for_deletion(),
			("the corpse is not freed on the spot -- kill() hands the body to a tween"
				+ " rather than queueing the free immediately, which is the branch"
				+ " _play_death takes for a pest that is inside the tree"))
	if err == "":
		err = _T.assert_false(pest.is_alive(), "but it is already dead as far as the game is concerned")
	_T.free_ui(host)
	return err


# -- Title screen + endless mode (plant-tower-defense-5fu) -------------------


func test_title_screen_builds_its_buttons_headlessly() -> String:
	var title := await _T.instantiate_ui("res://game/title.tscn", Vector2i(1152, 648)) as Control
	var err: String = _T.assert_true(title != null, "the title scene resolves headlessly")
	if err == "":
		err = _T.assert_true(title.get_node_or_null("StartButton") != null, "Start button exists")
	if err == "":
		err = _T.assert_true(title.get_node_or_null("EndlessButton") != null, "Endless button exists")
	if err == "":
		err = _T.assert_true(title.get_node_or_null("NotebookButton") != null, "Designer's Notebook button exists")
	_T.free_ui(title)
	return err


## The game is called Pest Control (2026-08-17). The name lives in one Label the
## title screen builds itself, so pin it here and check the text fits the band
## the Label is given -- a longer name silently clips at 54px, and
## get_minimum_size() would not say so.
func test_title_screen_is_named_pest_control() -> String:
	var title := await _T.instantiate_ui("res://game/title.tscn", Vector2i(1152, 648)) as Control
	var label := title.get_node_or_null("TitleLabel") as Label
	var err: String = _T.assert_true(label != null, "title screen has a TitleLabel")
	if err == "":
		err = _T.assert_eq(label.text, "Pest Control", "the title reads Pest Control")
	if err == "":
		var w: float = _T.text_width(label)
		err = _T.assert_true(w > 0.0 and w < label.size.x, "title text (%.0fpx) fits its %.0fpx band" % [w, label.size.x])
	_T.free_ui(title)
	return err


func test_title_screen_backdrop_actually_covers_the_viewport() -> String:
	## Regression: PRESET_FULL_RECT resolved to a 0x0 rect for this Control (it
	## is the scene root, added straight under the Viewport with no sized
	## Control ancestor to anchor against) — invisible on the bare title
	## screen since INK is nearly the viewport's own clear colour, but it left
	## every button behind the Designer's Notebook overlay visible and
	## clickable right through it. A live screenshot caught it; this asserts
	## the size a screenshot only shows.
	var title := await _T.instantiate_ui("res://game/title.tscn", Vector2i(1152, 648)) as Control
	var want := Vector2(1152, 648)
	var err: String = _T.assert_eq(title.size, want, "the title screen root actually fills the viewport")
	if err == "":
		var backdrop: Control = title.get_node("Backdrop")
		err = _T.assert_eq(backdrop.size, want, "and so does its opaque backdrop")
	_T.free_ui(title)
	return err


func test_notebook_backdrop_actually_covers_the_viewport() -> String:
	var notebook := await _T.instantiate_ui(NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
	var want := Vector2(1152, 648)
	var err: String = _T.assert_eq(notebook.size, want, "the notebook overlay actually fills the viewport")
	if err == "":
		var backdrop: Control = notebook.get_node("Backdrop")
		err = _T.assert_eq(backdrop.size, want, "and so does its opaque backdrop, hiding the title screen behind it")
	_T.free_ui(notebook)
	return err


func test_notebook_images_stay_inside_their_box() -> String:
	## Regression: EXPAND_FIT_WIDTH_PROPORTIONAL made each TextureRect's own
	## resolved size follow the source texture's aspect against whatever it
	## guessed was "available width" outside a Container, blowing a 320x320
	## box up to most of the screen. A live screenshot caught this one too.
	var notebook := await _T.instantiate_ui(NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
	var err: String = _T.assert_eq(notebook.get_node("Drawing").size, NotebookScreen.DRAWING_BOX.size,
		"the drawing stays in its box")
	if err != "":
		_T.free_ui(notebook)
		return err
	# The sprite's rect is not fixed: _fit_sprite() sizes it to a whole multiple
	# of whichever texture the page carries, so enclosure and integer scale are
	# the invariants, not one hard-coded size. Every page is checked, because
	# corn_kernel@2x is 32px where every other sprite is 128 and it is the one
	# that would come out fractional.
	var sprite: TextureRect = notebook.get_node("Sprite") as TextureRect
	for page: int in NotebookScreen.PAGES.size():
		notebook.go_to(page)
		var rect := Rect2(sprite.position, sprite.size)
		err = _T.assert_true(NotebookScreen.SPRITE_BOX.encloses(rect),
			"page %d's sprite %s stays inside %s" % [page + 1, rect, NotebookScreen.SPRITE_BOX])
		if err != "":
			break
		var factor: float = sprite.size.x / float(sprite.texture.get_width())
		err = _T.assert_eq(factor, floorf(factor),
			"page %d's sprite is drawn at a whole-number zoom (%.2fx), so the pixel grid survives" % [page + 1, factor])
		if err != "":
			break
	_T.free_ui(notebook)
	return err


func test_run_config_high_score_only_ever_goes_up() -> String:
	# save_path is redirected FIRST, before anything calls a mutator. record_score()
	# persists through _save(), so every run of this test used to raise the number in
	# the developer's own user://highscore.save by one -- observed climbing 308 -> 309
	# across two suite runs. Restoring the in-memory scores afterwards, which is what
	# this test used to do, hides that completely: the file keeps the last number
	# written and the suite prints ALL PASSED.
	var stashed_path: String = RunConfig.save_path
	RunConfig.save_path = "user://test_selftest_ratchet.save"
	# The SCORES are stashed as well as the path, and both halves are load-bearing.
	# Redirecting the path alone still leaves this test's raised number sitting in
	# the autoload afterwards, and the next legitimate _save() -- the migration on a
	# version bump, or any later test -- writes it to the real file. That is exactly
	# what happened on the first attempt at this fix: the file went 308 -> 309 with
	# the path correctly redirected the whole time.
	var stashed_campaign: int = RunConfig.campaign_high_score
	var stashed_endless_score: int = RunConfig.endless_high_score
	# Scores are per mode now; this asserts the ratchet on whichever mode is live.
	var was_endless: bool = RunConfig.endless
	var before: int = RunConfig.best_for(was_endless)
	var raised: bool = RunConfig.record_score(before + 1)
	var err: String = _T.assert_true(raised, "a strictly higher score updates the record")
	if err == "":
		err = _T.assert_eq(RunConfig.best_for(was_endless), before + 1, "and is now the stored high")
	if err == "":
		var raised_again: bool = RunConfig.record_score(before)
		err = _T.assert_false(raised_again, "a lower score never overwrites a better one")
	if err == "":
		# The ratchet must be per mode, or one mode's record silently gates the other.
		var other: int = RunConfig.best_for(not was_endless)
		RunConfig.endless = not was_endless
		RunConfig.record_score(other + 1)
		RunConfig.endless = was_endless
		err = _T.assert_eq(RunConfig.best_for(was_endless), before + 1,
			"and the other mode's record did not disturb this one")
	RunConfig.campaign_high_score = stashed_campaign
	RunConfig.endless_high_score = stashed_endless_score
	RunConfig.save_path = stashed_path
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists("user://test_selftest_ratchet.save" + suffix):
			DirAccess.remove_absolute("user://test_selftest_ratchet.save" + suffix)
	return err


func test_endless_mode_never_runs_out_of_waves() -> String:
	var director := WaveDirector.new()
	director.endless = true
	director.current_wave = WaveDirector.WAVES.size() + 50
	var err: String = _T.assert_true(director.has_more_waves(), "endless keeps going past the fixed table")
	director.free()
	return err


func test_campaign_mode_still_ends_at_the_fixed_table() -> String:
	var director := WaveDirector.new()
	director.endless = false
	director.current_wave = WaveDirector.WAVES.size()
	var err: String = _T.assert_false(director.has_more_waves(), "non-endless still has a finish line")
	director.free()
	return err


func test_an_endless_wave_past_the_table_still_sends_pests() -> String:
	var director := WaveDirector.new()
	director.endless = true
	director.current_wave = WaveDirector.WAVES.size()
	director.start_next_wave()
	var err: String = _T.assert_gt(director.current_wave_pest_count(), 0,
		"a wave number the fixed table has no entry for is generated, not empty")
	director.free()
	return err


# -- Designer's Notebook (plant-tower-defense-1qo) ---------------------------


func test_notebook_pairs_every_drawing_with_a_sprite_that_exists() -> String:
	for entry: Dictionary in NotebookScreen.PAGES:
		var drawing: String = String(entry["drawing"])
		var err: String = _T.assert_true(ResourceLoader.exists(drawing), "%s is on disk and importable" % drawing)
		if err != "":
			return err
		var sprite: String = String(entry["sprite"])
		err = _T.assert_true(ResourceLoader.exists(sprite), "%s is on disk" % sprite)
		if err != "":
			return err
	return ""


func test_notebook_paging_wraps_in_both_directions() -> String:
	var notebook := await _T.instantiate_ui(NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
	var page_label: Label = notebook.get_node("PageLabel") as Label
	var err: String = _T.assert_eq(page_label.text, "1 / %d" % NotebookScreen.PAGES.size(), "starts on the first page")
	if err == "":
		notebook.go_to(NotebookScreen.PAGES.size() - 1)
		err = _T.assert_eq(page_label.text, "%d / %d" % [NotebookScreen.PAGES.size(), NotebookScreen.PAGES.size()],
			"go_to jumps straight to any page")
	if err == "":
		notebook.go_to(NotebookScreen.PAGES.size())
		err = _T.assert_eq(page_label.text, "1 / %d" % NotebookScreen.PAGES.size(), "paging past the end wraps to the first")
	if err == "":
		notebook.go_to(-1)
		err = _T.assert_eq(page_label.text, "%d / %d" % [NotebookScreen.PAGES.size(), NotebookScreen.PAGES.size()],
			"and paging before the first wraps to the last")
	_T.free_ui(notebook)
	return err


# -- Notebook + title screen UX pass (plant-tower-defense-6k0, -dau) ---------


func test_no_two_notebook_pages_show_the_same_drawing() -> String:
	## `image1.jpg` and `image6.jpg` are the same photograph, byte for byte, and
	## the original PAGES table listed both — so the notebook showed one picture
	## twice under two captions describing different drawings. Every existing
	## check passed over that: both files exist, both import, both load, and the
	## two *paths* differ, so comparing paths proves nothing. Only the bytes do.
	var seen: Array[Dictionary] = []
	for entry: Dictionary in NotebookScreen.PAGES:
		var path: String = String(entry["drawing"])
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var err: String = _T.assert_gt(bytes.size(), 0, "%s is readable as raw bytes" % path)
		if err != "":
			return err
		for prior: Dictionary in seen:
			# Sizes first, so at most one full comparison ever runs per pair.
			# (PackedByteArray has no hash() — that is a parse error, not a
			# runtime one, so it fails the whole script rather than one test.)
			if int(prior["size"]) != bytes.size():
				continue
			err = _T.assert_false(bytes == PackedByteArray(prior["bytes"]),
				"%s and %s are not the same image — one page would be showing what another already showed"
					% [String(prior["path"]), path])
			if err != "":
				return err
		seen.append({"path": path, "size": bytes.size(), "bytes": bytes})
	return _T.assert_eq(seen.size(), NotebookScreen.PAGES.size(), "every page shows a distinct drawing")


func test_notebook_every_page_carries_a_caption_and_a_note() -> String:
	## The screen this replaced showed a six-word caption and nothing else,
	## which is why it read as a slideshow rather than a notebook: it said which
	## drawing you were looking at and never what the drawing decided. A page
	## with an empty or one-line note is that screen coming back.
	for entry: Dictionary in NotebookScreen.PAGES:
		var caption: String = String(entry.get("caption", ""))
		var err: String = _T.assert_gt(caption.length(), 0, "every page is captioned")
		if err != "":
			return err
		var note: String = String(entry.get("note", ""))
		err = _T.assert_gt(note.length(), 80, "\"%s\" carries a real note, not a second label" % caption)
		if err != "":
			return err
		# NOTE_RECT is 420x108 at font size 14 — about five wrapped lines. The
		# Label ellipsises past that rather than overflowing, so an over-long
		# note loses its last sentence silently. This is the budget.
		err = _T.assert_true(note.length() <= 300,
			"\"%s\" fits the note box (%d chars, budget 300)" % [caption, note.length()])
		if err != "":
			return err
	return ""


func test_notebook_content_stays_on_the_paper() -> String:
	## Everything on this screen is hand-positioned against NotebookScreen.PANEL
	## rather than laid out by a Container, so nothing stops a nudged constant
	## from putting the note or the pager off the edge of the drawn sheet and
	## onto the dark backdrop. Enclosure is the invariant that constant has to
	## keep.
	var notebook := await _T.instantiate_ui(NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
	var paper := NotebookScreen.PANEL
	var err := ""
	for node_name: String in [
		"Heading", "Subheading", "BackButton", "Drawing", "DrawingFrame", "SourceLabel",
		"Sprite", "Caption", "NoteLabel", "PrevButton", "PageLabel", "NextButton", "Shelf",
	]:
		var node: Control = notebook.get_node(node_name) as Control
		var rect := Rect2(node.position, node.size)
		err = _T.assert_true(paper.encloses(rect), "%s at %s sits on the paper %s" % [node_name, rect, paper])
		if err != "":
			break
	_T.free_ui(notebook)
	return err


func test_notebook_page_dot_marker_lerps_between_dots() -> String:
	## NotebookPage.current_page's setter eases _display_page toward the
	## target instead of snapping — see the setter's own comment — and
	## _draw_dots() reads that fractional value through dot_marker_x() rather
	## than an integer index. This is the interpolation itself, tested
	## without a live tree or a tween to wait on.
	var at_zero: float = NotebookPage.dot_marker_x(0.0, 3, 300.0)
	var at_one: float = NotebookPage.dot_marker_x(1.0, 3, 300.0)
	var midpoint: float = NotebookPage.dot_marker_x(0.5, 3, 300.0)
	var err: String = _T.assert_float_eq(midpoint, (at_zero + at_one) / 2.0, 0.001,
		"halfway through a turn the marker sits halfway between the two dots")
	if err == "":
		err = _T.assert_float_eq(at_one - at_zero, NotebookPage.DOT_SPACING, 0.001,
			"a full page advances the marker by exactly one dot's spacing")
	return err


func test_notebook_page_current_page_moves_the_dot_without_waiting_on_a_tween() -> String:
	## Headless never pumps the frame a tween needs
	## (GardenTheme.animations_enabled() is false there), so current_page's
	## setter falls back to setting _display_page directly — the same
	## fallback Plant.play_exit_and_free() and TitleScreen._play_entrance()
	## use — or every headless read of the dot would see it stuck on page 0.
	var paper := await _T.instantiate_ui(NotebookPage.new(), Vector2i(600, 500)) as NotebookPage
	paper.page_count = 3
	paper.current_page = 2
	var err: String = _T.assert_float_eq(paper._display_page, 2.0, 0.001,
		"the marker lands on the target page immediately when animations are off")
	_T.free_ui(paper)
	return err


## Pairs that are supposed to share pixels: a matte and the photo mounted on it.
const NOTEBOOK_NESTED_PAIRS: Array[Array] = [["DrawingFrame", "Drawing"]]

## Everything on the spread that a player reads or clicks, in draw order.
const NOTEBOOK_CONTENT: Array[String] = [
	"Heading", "Subheading", "BackButton", "DrawingPaneLabel", "DrawingFrame", "Drawing",
	"SourceLabel", "SpritePaneLabel", "Sprite", "Caption", "NoteLabel",
	"PrevButton", "PageLabel", "NextButton",
]


func test_no_two_things_on_the_notebook_spread_sit_on_top_of_each_other() -> String:
	## The pair check `findings` structurally cannot do: it measures one Control
	## against its own box, so two nodes that each fit perfectly and land on the
	## same pixels are invisible to it. The live version of this
	## (.claude/skills/godot-hud-occlusion-audit) caught the pane label running
	## 5px into the top of the drawing frame while `findings` reported 0 across
	## 4 of 4 checks over the same frame. This is that check, headless, so every
	## future /verify re-runs it without a game.
	var notebook := await _T.instantiate_ui(NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
	var err := ""
	for i: int in NOTEBOOK_CONTENT.size():
		for j: int in range(i + 1, NOTEBOOK_CONTENT.size()):
			var a_name: String = NOTEBOOK_CONTENT[i]
			var b_name: String = NOTEBOOK_CONTENT[j]
			if NOTEBOOK_NESTED_PAIRS.has([a_name, b_name]) or NOTEBOOK_NESTED_PAIRS.has([b_name, a_name]):
				continue
			var a := _painted_rect(notebook.get_node(a_name) as Control)
			var b := _painted_rect(notebook.get_node(b_name) as Control)
			var hit := a.intersection(b)
			err = _T.assert_true(hit.get_area() <= 0.0,
				"%s %s and %s %s do not share pixels (%.0f overlapping)" % [
					a_name, a, b_name, b, hit.get_area(),
				])
			if err != "":
				break
		if err != "":
			break
	_T.free_ui(notebook)
	return err


## Where a Control's pixels actually land, which for a Label is not its box.
##
## A centred full-width heading is the normal way to put a title across a
## screen, and its *box* then overlaps anything parked in the left or right
## margin — the Back button, here — while its glyphs come nowhere near. Occlusion
## is a question about pixels, so narrow a non-wrapping Label to its text extent
## and place that extent according to its alignment. A wrapping Label is left
## alone: `get_minimum_size().x` on one of those is the width of its longest
## word, not of the paragraph, and narrowing to that would hide real overlaps.
static func _painted_rect(node: Control) -> Rect2:
	var rect := Rect2(node.position, node.size)
	var label := node as Label
	if label == null or label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return rect
	var text_width: float = label.get_minimum_size().x
	if text_width <= 0.0 or text_width >= rect.size.x:
		return rect
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			rect.position.x += (rect.size.x - text_width) / 2.0
		HORIZONTAL_ALIGNMENT_RIGHT:
			rect.position.x += rect.size.x - text_width
		HORIZONTAL_ALIGNMENT_FILL:
			return rect
	rect.size.x = text_width
	return rect


func test_notebook_arrow_keys_turn_the_page_and_escape_closes_it() -> String:
	## The bridge can `press` a Button by path; nothing in the harness can prove
	## a raw keycode is wired without a live game and a real keyboard. Calling
	## the handler is still the real path — `_input` is the only place these
	## three keys are interpreted, and a typo in the match arm fails here.
	var notebook := await _T.instantiate_ui(NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
	var page_label: Label = notebook.get_node("PageLabel") as Label
	var closed: Array[bool] = [false]
	notebook.back_requested.connect(func() -> void: closed[0] = true)
	var total: int = NotebookScreen.PAGES.size()

	notebook._input(_key_press(KEY_RIGHT))
	var err: String = _T.assert_eq(page_label.text, "2 / %d" % total, "Right turns forward a page")
	if err == "":
		notebook._input(_key_press(KEY_LEFT))
		err = _T.assert_eq(page_label.text, "1 / %d" % total, "and Left turns back")
	if err == "":
		notebook._input(_key_press(KEY_ESCAPE))
		err = _T.assert_true(closed[0], "Escape asks to close the notebook")
	_T.free_ui(notebook)
	return err


static func _key_press(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func test_notebook_shows_the_2x_sprite_not_the_64px_board_art() -> String:
	## A 64px sprite stretched into a 200px box is the blur the old screen had.
	## tools/render_svg.gd already emits a 2x copy of every sprite; this asserts
	## the notebook reaches for it, and that a path with no 2x twin (the .jpg
	## photographs) is passed through untouched rather than 404ing.
	var err: String = _T.assert_eq(GardenTheme.retina_path("res://assets/sprites/corn_cobbler.png"),
		"res://assets/sprites/retina/corn_cobbler@2x.png", "a sprite with a 2x twin is upgraded to it")
	if err == "":
		err = _T.assert_eq(GardenTheme.retina_path("res://image1.jpg"), "res://image1.jpg",
			"and a path with no 2x twin is left alone")
	if err != "":
		return err
	var notebook := await _T.instantiate_ui(NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
	var sprite: TextureRect = notebook.get_node("Sprite") as TextureRect
	err = _T.assert_gt(sprite.texture.get_width(), 64, "the loaded texture is the 2x art, not the board sprite")
	if err == "":
		err = _T.assert_eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST,
			"and it is point-sampled, so the one-pixel outlines survive the enlargement")
	_T.free_ui(notebook)
	return err


func test_menu_buttons_are_not_left_on_the_default_theme() -> String:
	## Both screens painted themselves cream-and-green and then left every
	## Button on Godot's grey default, so the controls looked bolted on to a
	## screen they did not belong to. A missing `normal` stylebox on Button is
	## that regression, and it is invisible to every layout check — the boxes
	## are all the right size, they are just the wrong game.
	var title := await _T.instantiate_ui("res://game/title.tscn", Vector2i(1152, 648)) as Control
	var err: String = _T.assert_true(title.theme != null, "the title screen carries a theme")
	if err == "":
		var box := title.theme.get_stylebox("normal", "Button") as StyleBoxFlat
		err = _T.assert_true(box != null, "and that theme restyles Button, not only Label colours")
		if err == "":
			err = _T.assert_eq(box.bg_color, GardenTheme.PAPER, "buttons are paper stock, not Godot grey")
	_T.free_ui(title)
	return err


func test_title_high_score_line_never_reads_as_a_zero_record() -> String:
	## "Best endless run: 0 seeds grown" on a fresh install reads as a bug, not
	## as an empty record.
	var saved_c: int = RunConfig.campaign_high_score
	var saved_e: int = RunConfig.endless_high_score
	RunConfig.campaign_high_score = 0
	RunConfig.endless_high_score = 0
	var err: String = _T.assert_false(TitleScreen.high_score_text().contains("0"),
		"a fresh install is told there is no record yet, got %s" % TitleScreen.high_score_text())
	if err == "":
		RunConfig.endless_high_score = 412
		var line: String = TitleScreen.high_score_text()
		err = _T.assert_true(line.contains("412") and line.contains("Endless"),
			"and a real record is spelled out and named by its mode, got %s" % line)
	if err == "":
		# The bug this replaced: one number labelled "Best endless run" whichever
		# mode had set it. A campaign-only record must not claim to be endless.
		RunConfig.endless_high_score = 0
		RunConfig.campaign_high_score = 77
		var line2: String = TitleScreen.high_score_text()
		err = _T.assert_true(line2.contains("Campaign") and not line2.contains("Endless"),
			"a campaign-only record is not called endless, got %s" % line2)
	RunConfig.campaign_high_score = saved_c
	RunConfig.endless_high_score = saved_e
	return err


func test_title_controls_all_clear_the_scenery() -> String:
	## The backdrop's grass line is at TitleBackdrop.HORIZON, and the decorative
	## plants stand on it as Sprite2Ds. Nothing checks a Control against a
	## Node2D — not validate-ui, not the HUD occlusion audit, both of which only
	## ever compare Controls — so a button that dips past the horizon is a
	## button with a sunflower drawn through it and no tool would say so.
	var title := await _T.instantiate_ui("res://game/title.tscn", Vector2i(1152, 648)) as Control
	var horizon: float = title.size.y * TitleBackdrop.HORIZON
	var err := ""
	# Read off TitleScreen.MENU_BUTTON_NAMES, not spelled out here: this list
	# carried its own copy of the column and a fourth button was added without it.
	for node_name: String in TitleScreen.MENU_BUTTON_NAMES + ["HintLabel"]:
		var node: Control = title.get_node(node_name) as Control
		var bottom: float = node.position.y + node.size.y
		err = _T.assert_true(bottom <= horizon,
			"%s ends at %.0f, clear of the horizon at %.0f" % [node_name, bottom, horizon])
		if err != "":
			break
	_T.free_ui(title)
	return err


## The title menu's real deliverable: there is a sixth slot, and a seventh.
##
## The old single column had neither at any pitch, and said so in a comment
## instead of in a check -- so the thing that would have caught the next
## destination arriving was a person reading prose. `menu_capacity()` computes the
## ceiling from the same arithmetic that places the buttons, and this test is what
## makes that number load-bearing.
##
## It asserts the ceiling in BOTH directions on purpose. "Room for more" alone is
## satisfied by a capacity function that always says a large number; the refusal
## at capacity + 1 is what proves it is measuring the horizon rather than
## returning a constant.
func test_the_title_menu_has_room_for_the_next_destination() -> String:
	var now: int = TitleScreen.MENU_BUTTON_NAMES.size()
	var cap: int = TitleScreen.menu_capacity()
	var horizon: float = float(TitleScreen.viewport_height()) * TitleBackdrop.HORIZON

	var err: String = _T.assert_true(cap >= now + 2,
		"the menu holds %d and could hold %d -- a sixth AND a seventh destination fit" % [now, cap])
	if err == "":
		# The ceiling is a measurement, not a number: one more than capacity must
		# actually run the hint past the grass line.
		err = _T.assert_true(
			TitleScreen.hint_y(cap + 1) + TitleScreen.HINT_HEIGHT > horizon,
			"and %d buttons genuinely does not fit -- hint would foot at %.0f against a horizon at %.0f"
				% [cap + 1, TitleScreen.hint_y(cap + 1) + TitleScreen.HINT_HEIGHT, horizon])
	if err == "":
		err = _T.assert_true(
			TitleScreen.hint_y(cap) + TitleScreen.HINT_HEIGHT <= horizon,
			"while %d does, footing at %.0f" % [cap, TitleScreen.hint_y(cap) + TitleScreen.HINT_HEIGHT])
	return err


## Every menu size the screen claims to support, laid out and checked -- not just
## the five buttons that happen to exist today.
##
## This is the half a screenshot of the current screen cannot cover. A grid whose
## cells overlap, or drift outside the band the lawn was measured against, or drop
## a row below the 40px touch-target gate `findings` enforces, is wrong for a size
## nobody has built yet, and nothing else in the suite would ever instantiate one.
func test_every_title_menu_size_lays_out_inside_its_band_without_overlap() -> String:
	var err := ""
	var centre: float = float(TitleScreen.viewport_width()) / 2.0
	var band_left: float = centre - TitleScreen.BUTTON_WIDTH / 2.0
	var band_right: float = centre + TitleScreen.BUTTON_WIDTH / 2.0
	var horizon: float = float(TitleScreen.viewport_height()) * TitleBackdrop.HORIZON

	for count: int in range(1, TitleScreen.menu_capacity() + 1):
		var rects: Array[Rect2] = []
		for i: int in count:
			rects.append(TitleScreen.button_rect(i, count))
		for i: int in count:
			var rect: Rect2 = rects[i]
			err = _T.assert_true(rect.size.x > 0.0 and rect.size.y > 0.0,
				"button %d of %d got a real rect, not the empty one button_rect returns for an index it cannot place"
					% [i, count])
			if err != "":
				return err
			# The gate `findings` applies to any interactive Control. The grid
			# halves WIDTH; the day it starts halving height instead, this fails.
			err = _T.assert_true(rect.size.x >= 40.0 and rect.size.y >= 40.0,
				"button %d of %d is a real touch target at %s" % [i, count, rect.size])
			if err != "":
				return err
			err = _T.assert_true(rect.position.x >= band_left - 0.001
					and rect.position.x + rect.size.x <= band_right + 0.001,
				"button %d of %d stays in the lawn's clear band (%.0f..%.0f), got %.0f..%.0f"
					% [i, count, band_left, band_right, rect.position.x, rect.position.x + rect.size.x])
			if err != "":
				return err
			err = _T.assert_true(rect.position.y + rect.size.y <= horizon,
				"button %d of %d clears the horizon at %.0f, ending at %.0f"
					% [i, count, horizon, rect.position.y + rect.size.y])
			if err != "":
				return err
			for j: int in range(i + 1, count):
				err = _T.assert_false(rect.intersects(rects[j]),
					"buttons %d and %d of %d share pixels (%s vs %s)" % [i, j, count, rect, rects[j]])
				if err != "":
					return err
		# menu_bottom() is what hint_y() and menu_capacity() are both built on, so
		# it must agree with the rects rather than being a second arithmetic.
		var lowest: float = 0.0
		for rect: Rect2 in rects:
			lowest = maxf(lowest, rect.position.y + rect.size.y)
		err = _T.assert_float_eq(TitleScreen.menu_bottom(count), lowest, 0.001,
			"menu_bottom(%d) agrees with where the buttons it placed actually end" % count)
		if err != "":
			return err
	return err


func test_title_backdrop_tuft_lean_is_zero_at_rest_and_stays_bounded() -> String:
	## TitleBackdrop's tufts lean a few px in a slow breeze — TitleBackdrop.tuft_lean()
	## is split out of _draw_tufts() so this can assert the sway without
	## instantiating a Control or drawing a frame.
	var err: String = _T.assert_float_eq(TitleBackdrop.tuft_lean(0.0, 0.0), 0.0, 0.0001,
		"no lean the instant the backdrop starts, at the tuft with no phase offset")
	if err == "":
		for t: float in [0.3, 1.1, 4.0, 9.5]:
			var lean: float = TitleBackdrop.tuft_lean(t, 40.0)
			err = _T.assert_true(absf(lean) <= TitleBackdrop.TUFT_SWAY_PX + 0.0001,
				"lean at t=%.1f (%.3f) stays within TUFT_SWAY_PX" % [t, lean])
			if err != "":
				break
	return err


func test_title_backdrop_glow_pulse_is_one_at_rest_and_stays_bounded() -> String:
	## The glow behind the wordmark breathes rather than snapping — see
	## TitleBackdrop.glow_pulse(), split out of _draw_glow() the same way.
	var err: String = _T.assert_float_eq(TitleBackdrop.glow_pulse(0.0), 1.0, 0.0001,
		"the glow starts at its resting radius")
	if err == "":
		for t: float in [0.5, 2.0, 7.0]:
			var pulse: float = TitleBackdrop.glow_pulse(t)
			err = _T.assert_true(
				pulse >= 1.0 - TitleBackdrop.GLOW_PULSE_AMOUNT - 0.0001
					and pulse <= 1.0 + TitleBackdrop.GLOW_PULSE_AMOUNT + 0.0001,
				"pulse at t=%.1f (%.4f) stays within GLOW_PULSE_AMOUNT of 1.0" % [t, pulse])
			if err != "":
				break
	return err


func test_title_backdrop_clouds_stay_inside_their_wrapped_band() -> String:
	## _draw_clouds() wraps each cloud back to the far edge via cloud_x() —
	## the same fmod-and-margin trick TitleScreen._march_pests uses along the
	## ground, one band up — rather than letting it drift off unbounded.
	var w: float = 1152.0
	var err := ""
	for cloud: Dictionary in TitleBackdrop.CLOUDS:
		for t: float in [0.0, 30.0, 500.0]:
			var x: float = TitleBackdrop.cloud_x(cloud, t, w)
			err = _T.assert_true(
				x >= -TitleBackdrop.CLOUD_MARGIN - 0.001 and x <= w + TitleBackdrop.CLOUD_MARGIN + 0.001,
				"cloud at t=%.0f (x=%.1f) stays inside its wrapped band" % [t, x])
			if err != "":
				return err
	return err


func test_title_backdrop_ambient_motion_is_gated_off_headless() -> String:
	## GardenTheme.animations_enabled() is false under the test runner
	## (headless), so _process() must not advance _elapsed there — otherwise
	## this backdrop would be redrawing every frame in the one environment it
	## can never actually be watched in.
	var backdrop := TitleBackdrop.new()
	backdrop._process(1.0)
	var err: String = _T.assert_float_eq(backdrop._elapsed, 0.0, 0.0001,
		"elapsed does not advance while animations are disabled")
	backdrop.free()
	return err


func test_title_focus_ring_wraps_in_both_directions() -> String:
	## Godot's geometric focus default walks the list and stops at each end. The
	## hint on screen says "Up / Down to choose", so it has to be a ring.
	var title := await _T.instantiate_ui("res://game/title.tscn", Vector2i(1152, 648)) as Control
	var names: Array[String] = TitleScreen.MENU_BUTTON_NAMES
	var start: Button = title.get_node(names[0]) as Button
	var last: Button = title.get_node(names[names.size() - 1]) as Button
	var err: String = _T.assert_gt(names.size(), 1, "there is a column to walk")
	if err == "":
		err = _T.assert_eq(String(start.get_node(start.focus_neighbor_top).name), names[names.size() - 1],
			"Up from the first button reaches the last")
	if err == "":
		err = _T.assert_eq(String(last.get_node(last.focus_neighbor_bottom).name), names[0],
			"and Down from the last returns to the first")
	_T.free_ui(title)
	return err


func test_opening_the_notebook_takes_focus_away_from_the_menu_behind_it() -> String:
	## The overlay's opaque Backdrop stops the mouse, but focus is a separate
	## channel: with the notebook up, Tab and the arrow keys used to walk onto
	## title-screen buttons the player could not see, and Enter would start a
	## run from inside the notebook.
	var title := await _T.instantiate_ui("res://game/title.tscn", Vector2i(1152, 648)) as Control
	var start: Button = title.get_node("StartButton") as Button
	title._open_notebook()
	var err: String = _T.assert_eq(start.focus_mode, Control.FOCUS_NONE,
		"the menu stops taking focus while the notebook is open")
	if err == "":
		err = _T.assert_true(title.get_node_or_null("Notebook") != null, "and the notebook is actually up")
	if err == "":
		title._open_notebook()
		err = _T.assert_eq(title.get_children().filter(
			func(child: Node) -> bool: return child is NotebookScreen).size(), 1,
			"pressing the button twice does not stack two notebooks")
	if err == "":
		title._close_notebook()
		err = _T.assert_eq(start.focus_mode, Control.FOCUS_ALL, "and closing it hands focus back")
	_T.free_ui(title)
	return err


## Same overlay contract for the keys screen, plus the half only a second overlay
## can be wrong about: the two must not stack. `overlay_open()` is one shared
## guard because two independent "is mine open" checks would happily let the keys
## screen open on top of the notebook, with the notebook still eating Escape.
func test_the_keys_screen_is_reachable_from_the_title_and_does_not_stack() -> String:
	var title := await _T.instantiate_ui("res://game/title.tscn", Vector2i(1152, 648)) as TitleScreen
	var button: Button = title.get_node_or_null("KeysButton") as Button
	var err: String = _T.assert_true(button != null, "the title screen has a Keys button")
	if err == "":
		err = _T.assert_true(button.size.x >= 40.0 and button.size.y >= 40.0,
			"and it is a real touch target, got %s" % button.size)
	if err == "":
		button.pressed.emit()
		err = _T.assert_true(title.get_node_or_null("KeysScreen") is KeyBindingScreen,
			"pressing it opens the keys screen")
	if err == "":
		err = _T.assert_eq((title.get_node("StartButton") as Button).focus_mode, Control.FOCUS_NONE,
			"and the menu behind it stops taking focus")
	if err == "":
		title._open_keys()
		err = _T.assert_eq(title.get_children().filter(
			func(child: Node) -> bool: return child is KeyBindingScreen).size(), 1,
			"pressing the button twice does not stack two of them")
	if err == "":
		title._open_notebook()
		err = _T.assert_true(title.get_node_or_null("Notebook") == null,
			"and the notebook cannot open on top of it either")
	if err == "":
		title._close_keys()
		err = _T.assert_eq((title.get_node("StartButton") as Button).focus_mode, Control.FOCUS_ALL,
			"closing it hands focus back")
	if err == "":
		err = _T.assert_false(title.overlay_open(), "and nothing is left covering the menu")
	if err == "":
		var column: Array[Button] = title.menu_buttons()
		err = _T.assert_eq(column.size(), TitleScreen.MENU_BUTTON_NAMES.size(),
			"menu_buttons() finds every button the column declares")
		if err == "":
			for i: int in column.size():
				err = _T.assert_eq(String(column[i].name), TitleScreen.MENU_BUTTON_NAMES[i],
					"and hands them back top to bottom")
				if err != "":
					break
		if err == "":
			# Not just the right names -- the right order on the screen, which is
			# what the focus ring and the entrance stagger both read it for.
			#
			# READING order, not strictly downward. That was "sits below" while the
			# menu was one column, and the secondary destinations sit two to a row
			# now: MENU_BUTTON_NAMES order has to be left-to-right within a row and
			# then top-to-bottom, which is the claim the focus ring and the stagger
			# actually depend on. Weakening it to "does not sit above" would let a
			# grid row hand its two cells back the wrong way round.
			for i: int in range(1, column.size()):
				var here: Vector2 = column[i].position
				var prev: Vector2 = column[i - 1].position
				err = _T.assert_true(
					here.y > prev.y or (is_equal_approx(here.y, prev.y) and here.x > prev.x),
					"%s (%s) follows %s (%s) in reading order"
						% [column[i].name, here, column[i - 1].name, prev])
				if err != "":
					break
	_T.free_ui(title)
	return err


## The screen against the table. One row per declared verb, showing what the
## InputMap currently says — not a hand-written list that a new verb would be
## missing from, which is the whole reason KeyBindings.ACTIONS exists.
func test_the_keys_screen_lists_every_verb_and_reads_the_live_bindings() -> String:
	KeyBindings.reset_all()
	var screen := await _T.instantiate_ui(KeyBindingScreen.new(), Vector2i(1152, 648)) as KeyBindingScreen
	var actions: Array[StringName] = KeyBindings.actions()
	var err: String = _T.assert_gt(actions.size(), 0, "there are verbs to list")
	for i: int in actions.size():
		if err != "":
			break
		var does: Label = screen.get_node_or_null("Row%d" % i) as Label
		var key: Label = screen.get_node_or_null("RowKey%d" % i) as Label
		var button: Button = screen.get_node_or_null("RowButton%d" % i) as Button
		err = _T.assert_true(does != null and key != null and button != null,
			"row %d (%s) has a description, a key and a button" % [i, actions[i]])
		if err == "":
			err = _T.assert_eq(does.text, KeyBindings.describe(actions[i]), "row %d says what it does" % i)
		if err == "":
			err = _T.assert_eq(key.text, KeyBindings.label_for(actions[i]),
				"row %d shows the key the InputMap actually holds" % i)
		if err == "":
			err = _T.assert_true(button.size.x >= 40.0 and button.size.y >= 40.0,
				"row %d's button is a real touch target" % i)
	if err == "":
		err = _T.assert_true(screen.get_node_or_null("RowButton%d" % actions.size()) == null,
			"and there is no row for a verb that does not exist")
	if err == "":
		# `refresh` redraws the key column out of the InputMap rather than each
		# caller patching the one row it believes it changed -- so a binding moved
		# behind the screen's back still shows up.
		var was: String = (screen.get_node("RowKey0") as Label).text
		KeyBindings.set_keys(actions[0], [KEY_F6])
		err = _T.assert_eq((screen.get_node("RowKey0") as Label).text, was,
			"the row is stale until something redraws it")
		if err == "":
			screen.refresh()
			err = _T.assert_eq((screen.get_node("RowKey0") as Label).text, "F6",
				"and refresh() reads the InputMap back, not a copy the screen kept")
		KeyBindings.reset_all()
		screen.refresh()
	if err == "":
		# An action the table does not declare arms nothing -- otherwise a typo'd
		# StringName leaves the screen waiting for a key it can never place.
		screen.listen_for(&"garden_not_a_verb")
		err = _T.assert_eq(String(screen.listening_for()), "", "an undeclared verb cannot be armed")
		if err == "":
			screen.listen_for(KeyBindings.ACTION_BACK)
			err = _T.assert_eq(String(screen.listening_for()), String(KeyBindings.ACTION_BACK),
				"a declared one can")
		if err == "":
			screen.capture(KEY_ESCAPE)
	if err == "":
		# Nothing on the paper may run off it or sit on top of anything else, and the
		# footer must stand CLEAR of the last row -- see the helper, which is where
		# that rule lives now, once, for every overlay that has rows.
		err = _overlay_content_fits_and_stands_clear(screen)
	_T.free_ui(screen)
	return err


## Every visible Control on `screen` sits on its own paper, touches no sibling,
## and -- on a screen with rows -- leaves at least OverlayScreen.FOOTER_GAP between
## the foot of the last row and the top of the footer.
##
## One helper for every overlay, because it is one rule. It was written twice at
## two different numbers (16.0 on the Keys screen, OptionsScreen.FOOTER_GAP on the
## other), which is the state a rule is in just before one copy is fixed and the
## other is not.
##
## The gap half is a DISTANCE and deliberately not "do they overlap":
## `Rect2.intersects` is false for two boxes sharing an edge, so the Keys screen's
## footer once sat flush against the last row and every check written at the time
## passed. It read as wrong only in a screenshot.
##
## The enclosure half is the check no harness gate performs -- `findings` measures
## a Control against its own box, so a row list drawn straight through the footer
## is invisible to it.
func _overlay_content_fits_and_stands_clear(screen: OverlayScreen) -> String:
	var panel: Rect2 = screen.panel_rect()
	var rects: Dictionary = {}
	for child: Node in screen.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		if control.name in [OverlayScreen.BACKDROP_NAME, OverlayScreen.PAPER_NAME]:
			continue
		if control.size.x <= 0.0 or control.size.y <= 0.0:
			continue
		var rect := Rect2(control.position, control.size)
		var err: String = _T.assert_true(panel.encloses(rect),
			"%s at %s stays on the paper %s" % [control.name, rect, panel])
		if err != "":
			return err
		rects[String(control.name)] = rect
	var names: Array = rects.keys()
	var out := ""
	for i: int in range(names.size()):
		for j: int in range(i + 1, names.size()):
			out = _T.assert_false((rects[names[i]] as Rect2).intersects(rects[names[j]]),
				"%s overlaps %s" % [names[i], names[j]])
			if out != "":
				return out
	out = _T.assert_gt(names.size(), 0, "there were Controls to check -- an empty sweep proves nothing")
	if out == "" and screen.has_rows():
		out = _T.assert_gte(screen.footer_clearance(), OverlayScreen.FOOTER_GAP,
			"the footer stands clear of the last row by at least FOOTER_GAP (%s), rather than merely not overlapping it"
				% screen.footer_clearance())
	return out


## The chrome itself, asserted once for every screen that wears it.
##
## Three overlays used to build this by hand -- the same Backdrop, the same paper,
## the same Back button, the same signal, transcribed three times because Options
## was written by copying Keys. OverlayScreen owns it now, and this is the test
## that says every overlay still HAS it: a subclass that declared its own `_ready`
## would silently replace the base's and come up with no backdrop at all, which is
## a defect a screenshot catches and no per-screen assertion in this file would.
func test_every_overlay_wears_the_same_chrome() -> String:
	var want := Vector2(1152, 648)
	# Built one at a time rather than three up front: a screen this test never
	# reaches would otherwise sit unparented and be counted as an orphan.
	var who_list: Array[String] = ["the Keys screen", "the Options screen", "the notebook"]
	var makers: Array[Callable] = [
		func() -> OverlayScreen: return KeyBindingScreen.build(),
		func() -> OverlayScreen: return OptionsScreen.new(),
		func() -> OverlayScreen: return NotebookScreen.new(),
	]
	var err := ""
	for i: int in makers.size():
		var who: String = who_list[i]
		var built := await _T.instantiate_ui(makers[i].call() as OverlayScreen, Vector2i(1152, 648)) as OverlayScreen
		# "the viewport it read out of ProjectSettings" until
		# plant-tower-defense-nrup: these now read the LIVE canvas, which at the
		# design host size is the same 1152x648 this has always asserted. The
		# wide-canvas half is
		# test_every_full_screen_surface_covers_a_wider_than_design_canvas.
		err = _T.assert_eq(built.size, want, "%s fills the viewport it is hosted in" % who)
		if err == "":
			var backdrop: ColorRect = built.get_node_or_null(OverlayScreen.BACKDROP_NAME) as ColorRect
			err = _T.assert_true(backdrop != null, "%s has a Backdrop, and it is a ColorRect" % who)
			if err == "":
				err = _T.assert_eq(backdrop.size, want, "%s's backdrop covers the menu behind it" % who)
			if err == "":
				# Neither opaque nor transparent: the game shows through faintly, so an
				# overlay reads as something held up in front of it.
				err = _T.assert_float_eq(backdrop.color.a, OverlayScreen.BACKDROP_ALPHA, 0.001,
					"%s's backdrop is the shared alpha rather than a local one" % who)
		if err == "":
			var paper: Control = built.get_node_or_null(OverlayScreen.PAPER_NAME) as Control
			err = _T.assert_true(paper != null, "%s draws its content on a Paper" % who)
			if err == "":
				# Decoration: a paper that stopped the mouse would eat every click
				# aimed at what is drawn over it.
				err = _T.assert_eq(paper.mouse_filter, Control.MOUSE_FILTER_IGNORE,
					"%s's paper does not eat the mouse" % who)
			if err == "":
				err = _T.assert_eq(Rect2(paper.position, paper.size), built.panel_rect(),
					"%s's paper is exactly the rect it places everything else against" % who)
		if err == "":
			var back: Button = built.get_node_or_null(OverlayScreen.BACK_BUTTON_NAME) as Button
			err = _T.assert_true(back != null, "%s has a BackButton the bridge can press by name" % who)
			if err == "":
				err = _T.assert_true(back.size.x >= 40.0 and back.size.y >= 40.0,
					"%s's Back is a real touch target, got %s" % [who, back.size])
			if err == "":
				err = _T.assert_true(built.back_button() == back,
					"and the base holds the same button the tree does on %s" % who)
			if err == "":
				# The signal, not a call back into whoever opened it: no overlay in
				# this game knows who its opener is.
				var asked: Array[bool] = [false]
				built.back_requested.connect(func() -> void: asked[0] = true)
				back.pressed.emit()
				err = _T.assert_true(asked[0],
					"%s's Back asks to be closed rather than closing itself" % who)
		_T.free_ui(built)
		if err != "":
			return err
	return err


## PROCESS_MODE_ALWAYS on the overlay the pause card opens -- stated where it is
## built, rather than inherited from a parent node or handed out by OverlayScreen.
##
## The pause card holds the tree still. An overlay frozen by the pause that owns it
## has dead buttons, a Back that does nothing and no way out of it. Inheriting from
## the parent would resolve to ALWAYS today only because the card happens to be
## ALWAYS, and would invert silently the day it is reparented.
func test_the_overlay_opened_over_a_paused_tree_states_its_process_mode() -> String:
	var keys := KeyBindingScreen.build()
	var err: String = _T.assert_eq(keys.process_mode, Node.PROCESS_MODE_ALWAYS,
		"KeyBindingScreen.build() states its process mode rather than inheriting one")
	if err == "":
		err = _T.assert_eq(String(keys.name), KeyBindingScreen.NODE_NAME,
			"and gives it the name both doors and the devtools bridge press by")
	keys.free()
	if err == "":
		# And the base does NOT hand it out: an overlay that got ALWAYS from its base
		# class would have an inherited fact again, one layer further away.
		var plain := OptionsScreen.new()
		err = _T.assert_eq(plain.process_mode, Node.PROCESS_MODE_INHERIT,
			"OverlayScreen does not give every overlay PROCESS_MODE_ALWAYS behind its back")
		plain.free()
	return err


## The rebinding itself, end to end: arm a row, press a key, and find the InputMap,
## the row, the pause card's legend and the save file all agreeing.
func test_the_keys_screen_rebinds_a_verb_and_writes_it_down() -> String:
	var path := "user://test_selftest_keys_screen.save"
	var stashed_path: String = RunConfig.save_path
	var stashed_bindings: Dictionary = RunConfig.key_bindings
	var stashed_status: String = RunConfig.load_status
	var stashed_campaign: int = RunConfig.campaign_high_score
	var stashed_endless: int = RunConfig.endless_high_score
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	RunConfig.save_path = path
	RunConfig.key_bindings = {}
	RunConfig.campaign_high_score = 0
	RunConfig.endless_high_score = 0
	# See the sibling test's note: every field the writer emits has to be pinned,
	# or the expected bytes below become a function of the developer's own save.
	# The two mutes joined that list at v6.
	var stashed_colorblind: bool = RunConfig.colorblind_safe
	var stashed_milestones: Dictionary = RunConfig.earned_milestones.duplicate()
	var stashed_mute_sfx: bool = RunConfig.mute_sfx
	var stashed_mute_music: bool = RunConfig.mute_music
	RunConfig.colorblind_safe = false
	RunConfig.earned_milestones = {}
	RunConfig.mute_sfx = false
	RunConfig.mute_music = false
	KeyBindings.reset_all()

	var screen := await _T.instantiate_ui(KeyBindingScreen.new(), Vector2i(1152, 648)) as KeyBindingScreen
	var err: String = _T.assert_eq(String(screen.listening_for()), "", "no row is armed to begin with")
	if err == "":
		(screen.get_node("RowButton0") as Button).pressed.emit()
		err = _T.assert_eq(String(screen.listening_for()), String(KeyBindings.actions()[0]),
			"pressing Change arms that row")
	if err == "":
		err = _T.assert_eq((screen.get_node("RowKey0") as Label).text, KeyBindingScreen.PROMPT,
			"and the row asks for a key instead of showing the old one")
	if err == "":
		err = _T.assert_true(screen.capture(KEY_F1), "F1 is free, so it lands")
	if err == "":
		err = _T.assert_eq(KeyBindings.keys_for(KeyBindings.ACTION_PAUSE), [KEY_F1],
			"the InputMap moved")
	if err == "":
		err = _T.assert_eq((screen.get_node("RowKey0") as Label).text, "F1", "the row moved")
	if err == "":
		err = _T.assert_eq(String(Game.key_help()[0]["keys"]), "F1", "the pause card's legend moved")
	if err == "":
		err = _T.assert_eq(FileAccess.get_file_as_string(path),
			"v%d\n0\n0\nm0\ncb0 sfx0 mus0 spd0 svol0 mvol0\n1\ngarden_pause %d\n" % [RunConfig.SAVE_VERSION, KEY_F1],
			"and it was written down beside the scores")
	if err == "":
		# A key another verb already answers to is refused, and said so.
		(screen.get_node("RowButton1") as Button).pressed.emit()
		err = _T.assert_false(screen.capture(KEY_F1), "a key already spoken for is refused")
		if err == "":
			err = _T.assert_eq(KeyBindings.keys_for(KeyBindings.ACTION_MUTE_SFX), [KEY_M],
				"and the refused row kept its own key")
		if err == "":
			err = _T.assert_true((screen.get_node("Note") as Label).text.contains("F1"),
				"the refusal is on screen, not silent: %s" % (screen.get_node("Note") as Label).text)
	if err == "":
		# Escape backs out of an armed row rather than binding itself -- it is the
		# way out of this screen, so a player who bound it would lose the exit.
		(screen.get_node("RowButton1") as Button).pressed.emit()
		err = _T.assert_false(screen.capture(KEY_ESCAPE), "Escape leaves the row alone")
		if err == "":
			err = _T.assert_eq(String(screen.listening_for()), "", "and disarms it")
		if err == "":
			err = _T.assert_eq(KeyBindings.keys_for(KeyBindings.ACTION_MUTE_SFX), [KEY_M],
				"having bound nothing")
	if err == "":
		# TWO presses now: the first arms, the second undoes. The arming half is
		# asserted on its own in test_the_reset_asks_before_it_undoes_anything; what
		# this line still owns is the other end -- that the undo, once confirmed,
		# reaches the InputMap AND the save file.
		var reset_button := screen.get_node("ResetButton") as Button
		reset_button.pressed.emit()
		err = _T.assert_eq(KeyBindings.keys_for(KeyBindings.ACTION_PAUSE), [KEY_F1],
			"one press asks rather than undoing -- F1 is still bound")
		if err == "":
			reset_button.pressed.emit()
			err = _T.assert_eq(KeyBindings.keys_for(KeyBindings.ACTION_PAUSE), [KEY_ESCAPE, KEY_P],
				"Put them all back restores the shipped keys once confirmed")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(path),
				"v%d\n0\n0\nm0\ncb0 sfx0 mus0 spd0 svol0 mvol0\n0\n" % RunConfig.SAVE_VERSION,
				"and clears the overrides out of the save rather than pinning the defaults into it")

	_T.free_ui(screen)
	KeyBindings.reset_all()
	RunConfig.save_path = stashed_path
	RunConfig.key_bindings = stashed_bindings
	RunConfig.load_status = stashed_status
	RunConfig.campaign_high_score = stashed_campaign
	RunConfig.endless_high_score = stashed_endless
	RunConfig.colorblind_safe = stashed_colorblind
	RunConfig.earned_milestones = stashed_milestones
	RunConfig.mute_sfx = stashed_mute_sfx
	RunConfig.mute_music = stashed_mute_music
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	return err


## The reset button asks before it destroys anything (plant-tower-defense-y7r).
##
## It used to be wired straight through — one press ran KeyBindings.reset_all(),
## _persist() and therefore RunConfig._save(), so every key a player had moved was
## off the disk before their finger left the mouse. This is the only control on the
## screen that can destroy work and it looked exactly as safe as "Change".
##
## Four things are asserted, and the last two are the ones that make a confirmation
## worth having rather than merely present: the count in the prompt is DERIVED from
## KeyBindings.overrides() (so the number offered and the number undone cannot
## disagree), and picking a row answers "no" — an arm that outlived the player going
## off to do something else would fire on their next glance at the button, which is
## worse than no confirmation at all.
func test_the_reset_asks_before_it_undoes_anything() -> String:
	var stashed_path: String = RunConfig.save_path
	# RunConfig.key_bindings has to be stashed too, and leaving it out is not a
	# hypothetical: capture() persists through RunConfig.store_key_bindings(), so
	# without this the autoload carries {garden_pause: [F1], garden_restart: [F2]}
	# out of this test and into every byte-exact save assertion after it. Five of
	# them failed that way, and ONLY in the full suite -- filtered to this test
	# alone it passed, which is the whole shape of suite-order pollution.
	var stashed_bindings: Dictionary = RunConfig.key_bindings
	var path := "user://test_selftest_reset_confirm.save"
	RunConfig.save_path = path
	RunConfig.key_bindings = {}
	KeyBindings.reset_all()

	var screen := await _T.instantiate_ui(KeyBindingScreen.new(), Vector2i(1152, 648)) as KeyBindingScreen
	var reset_button := screen.get_node("ResetButton") as Button
	var note := screen.get_node("Note") as Label

	# Nothing moved yet: the button has nothing to confirm and must not arm, and
	# must not write. The old code reset the InputMap to what it already was and
	# persisted that.
	reset_button.pressed.emit()
	var err: String = _T.assert_false(screen.reset_armed(),
		"with no key moved there is nothing to confirm, so it does not arm")
	if err == "":
		err = _T.assert_eq(note.text, KeyBindingScreen.RESET_NOTHING_TO_DO,
			"and it says so instead of reporting a reset that undid nothing")
	if err == "":
		err = _T.assert_false(FileAccess.file_exists(path),
			"and nothing was written -- 'nothing to undo' is not a thing to save")

	# Move two keys, so the count in the prompt has something to be wrong about.
	if err == "":
		screen.listen_for(KeyBindings.ACTION_PAUSE)
		err = _T.assert_true(screen.capture(KEY_F1), "F1 is free, so the first move lands")
	if err == "":
		screen.listen_for(KeyBindings.ACTION_RESTART)
		err = _T.assert_true(screen.capture(KEY_F2), "F2 is free, so the second lands")
	if err == "":
		err = _T.assert_eq(KeyBindings.overrides().size(), 2,
			"two verbs are off their shipped keys, which is what the prompt has to say")

	if err == "":
		reset_button.pressed.emit()
		err = _T.assert_true(screen.reset_armed(), "the first press arms rather than undoing")
	if err == "":
		err = _T.assert_eq(KeyBindings.keys_for(KeyBindings.ACTION_PAUSE), [KEY_F1],
			"and the InputMap has not moved yet")
	if err == "":
		# The number is derived, not typed: this is the assertion that fails if the
		# prompt ever counts something other than what reset_all() will undo.
		err = _T.assert_eq(reset_button.text, KeyBindingScreen.RESET_ARMED % 2,
			"the button carries the count, got: %s" % reset_button.text)
	if err == "":
		err = _T.assert_true(note.text.begins_with(KeyBindingScreen.RESET_MOVED_COUNT % [2, "s"]),
			"the note leads with the count, got: %s" % note.text)
	if err == "":
		# The KEYS, in table order. Two earlier drafts of this line named the verbs
		# instead, and both were caught in the running game rather than here: the
		# first composed `describe()` into the middle of a sentence and read "hold
		# the garden still will go back to its shipped key", and the second, composed
		# correctly, measured 962px in a 700px clip_text Label -- `findings` reported
		# `ui_text_trimmed` and the player saw the names cut off.
		err = _T.assert_true(note.text.contains("put F1 · F2 back"),
			"and names the keys that go, in table order; got: %s" % note.text)
	if err == "":
		# The half a string assertion structurally cannot see. This Label has
		# clip_text set, so get_minimum_size() reports the clip stub (~1px) and any
		# width assertion built on it passes unconditionally on exactly the labels
		# that need checking -- _T.text_width measures through the label's own
		# resolved theme font instead.
		# The numbers are formatted into ONE literal rather than appended to a
		# concatenation: `"a" + "b %.0f" % [x]` binds the `%` to the last fragment
		# only, and the first draft of this line printed its own placeholders back
		# when it failed. A failure message that cannot state the measurement is
		# most of the value of taking one.
		err = _T.assert_true(_T.text_width(note) <= note.size.x,
			"the confirmation FITS: it is the one string that must not be trimmed, since it names what is about to be destroyed (%.0fpx of text in a %.0fpx label)" % [_T.text_width(note), note.size.x])

	# Picking a row is the "no" answer.
	if err == "":
		screen.listen_for(KeyBindings.ACTION_MUTE_SFX)
		err = _T.assert_false(screen.reset_armed(),
			"choosing a row disarms it -- an arm that survives the player doing "
				+ "something else fires on their next glance at the button")
	if err == "":
		err = _T.assert_eq(reset_button.text, KeyBindingScreen.RESET_IDLE,
			"and the button stops asking, got: %s" % reset_button.text)
	if err == "":
		screen.capture(KEY_ESCAPE)
		reset_button.pressed.emit()
		err = _T.assert_eq(KeyBindings.keys_for(KeyBindings.ACTION_PAUSE), [KEY_F1],
			"so the next press is a fresh question, not the second half of the old one")
	if err == "":
		err = _T.assert_true(screen.reset_armed(), "which is to say it armed again")
	if err == "":
		reset_button.pressed.emit()
		err = _T.assert_eq(KeyBindings.keys_for(KeyBindings.ACTION_PAUSE), [KEY_ESCAPE, KEY_P],
			"and confirming it does undo the move")
	if err == "":
		err = _T.assert_false(screen.reset_armed(), "the button disarms once it has fired")

	_T.free_ui(screen)
	KeyBindings.reset_all()
	RunConfig.save_path = stashed_path
	RunConfig.key_bindings = stashed_bindings
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	return err


# -- Options screen (plant-tower-defense-lgv) --------------------------------


## The same overlay contract the notebook and the keys screen are held to, plus
## the half only a THIRD overlay can be wrong about: `overlay_open()` is one
## shared guard, so options must not open over keys and keys must not open over
## options.
func test_the_options_screen_is_reachable_from_the_title_and_does_not_stack() -> String:
	var title := await _T.instantiate_ui("res://game/title.tscn", Vector2i(1152, 648)) as TitleScreen
	var button: Button = title.get_node_or_null("OptionsButton") as Button
	var err: String = _T.assert_true(button != null, "the title screen has an Options button")
	if err == "":
		err = _T.assert_true(button.size.x >= 40.0 and button.size.y >= 40.0,
			"and it is a real touch target, got %s" % button.size)
	if err == "":
		button.pressed.emit()
		err = _T.assert_true(title.get_node_or_null("OptionsScreen") is OptionsScreen,
			"pressing it opens the options screen")
	if err == "":
		err = _T.assert_eq((title.get_node("StartButton") as Button).focus_mode, Control.FOCUS_NONE,
			"and the menu behind it stops taking focus")
	if err == "":
		title._open_options()
		err = _T.assert_eq(title.get_children().filter(
			func(child: Node) -> bool: return child is OptionsScreen).size(), 1,
			"pressing the button twice does not stack two of them")
	if err == "":
		title._open_keys()
		err = _T.assert_true(title.get_node_or_null("KeysScreen") == null,
			"and the keys screen cannot open on top of it")
	if err == "":
		title._close_options()
		err = _T.assert_false(title.overlay_open(), "closing it leaves nothing over the menu")
	if err == "":
		# The other direction of the same guard: the two overlays are peers, and a
		# guard that only knew about one of them would let this one through.
		#
		# Counted live rather than looked up by name. `queue_free()` does not take
		# effect until the frame ends and this test never yields one, so the
		# overlay closed on the line above is STILL a child here — a
		# `get_node_or_null("OptionsScreen")` would hand that corpse back and read
		# as "the guard failed", which is what the first draft of this assertion
		# did.
		title._open_keys()
		title._open_options()
		err = _T.assert_eq(title.get_children().filter(
			func(child: Node) -> bool:
				return child is OptionsScreen and not child.is_queued_for_deletion()).size(), 0,
			"and options cannot open on top of keys either")
		title._close_keys()
	_T.free_ui(title)
	return err


## The screen against the flags. Every switch OPTIONS declares reads its owner's
## live state and writes back through the owner's own setter.
##
## Everything this test touches is process-global and seeded from the developer's
## real save at startup, so all of it is stashed and pinned: RunConfig's save
## path plus every field its writer emits (a colourblind flip calls _save), and
## the two static mute flags, which otherwise leak into whatever test runs next.
func test_the_options_screen_shows_and_flips_every_persisted_flag() -> String:
	var path := "user://test_selftest_options_screen.save"
	var stashed_path: String = RunConfig.save_path
	var stashed_status: String = RunConfig.load_status
	var stashed_bindings: Dictionary = RunConfig.key_bindings
	var stashed_campaign: int = RunConfig.campaign_high_score
	var stashed_endless: int = RunConfig.endless_high_score
	var stashed_colorblind: bool = RunConfig.colorblind_safe
	var stashed_milestones: Dictionary = RunConfig.earned_milestones.duplicate()
	var stashed_sfx: bool = Sfx.is_muted()
	var stashed_music: bool = Music.is_muted()
	# Both halves of each mute, because v6 gave them two: the static flag the player
	# hears and RunConfig's persisted record of it, which is what the writer emits.
	var stashed_mute_sfx: bool = RunConfig.mute_sfx
	var stashed_mute_music: bool = RunConfig.mute_music
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	RunConfig.save_path = path
	RunConfig.key_bindings = {}
	RunConfig.campaign_high_score = 0
	RunConfig.endless_high_score = 0
	RunConfig.earned_milestones = {}
	RunConfig.colorblind_safe = false
	RunConfig.mute_sfx = false
	RunConfig.mute_music = false
	Sfx.set_muted(false)
	Music.set_muted(false)
	KeyBindings.reset_all()

	var declared: Array[StringName] = []
	for row: Dictionary in OptionsScreen.OPTIONS:
		declared.append(StringName(row["id"]))
	var screen := await _T.instantiate_ui(OptionsScreen.new(), Vector2i(1152, 648)) as OptionsScreen
	var err: String = _T.assert_eq(screen.rows(), declared,
		"the screen draws every switch the table declares, in table order")
	if err == "":
		err = _T.assert_gt(screen.rows().size(), 0, "and there is at least one to check")
	for i: int in screen.rows().size():
		if err != "":
			break
		var id: StringName = screen.rows()[i]
		var label: Label = screen.get_node_or_null("Row%d" % i) as Label
		var key: Label = screen.get_node_or_null("RowKey%d" % i) as Label
		var button: Button = screen.get_node_or_null("RowButton%d" % i) as Button
		err = _T.assert_true(label != null and key != null and button != null,
			"row %d (%s) has a name, a key and a button" % [i, id])
		if err == "":
			err = _T.assert_eq(label.text, OptionsScreen.describe(id), "row %d says what it is" % i)
		if err == "":
			# The keystroke is not replaced by this screen, so the row has to show
			# the key the InputMap actually holds -- not a second table of codes.
			err = _T.assert_eq(key.text, KeyBindings.label_for(OptionsScreen.action_for(id)),
				"row %d shows the live key for %s" % [i, OptionsScreen.action_for(id)])
		if err == "":
			err = _T.assert_eq(button.text, OptionsScreen.state_text(OptionsScreen.is_on(id)),
				"row %d reads the flag rather than a copy" % i)
		if err == "":
			err = _T.assert_true(button.size.x >= 40.0 and button.size.y >= 40.0,
				"row %d's button is a real touch target" % i)
		if err == "":
			# The press, and both halves of what it has to move: the owner's flag
			# and the row on screen.
			var was: bool = OptionsScreen.is_on(id)
			button.pressed.emit()
			err = _T.assert_eq(OptionsScreen.is_on(id), not was, "pressing row %d flips %s" % [i, id])
			if err == "":
				err = _T.assert_eq(button.text, OptionsScreen.state_text(not was),
					"and the button says so afterwards")
			if err == "":
				button.pressed.emit()
				err = _T.assert_eq(OptionsScreen.is_on(id), was, "and pressing it again puts it back")
	if err == "":
		# Switches AND dials since v8 (plant-tower-defense-u9uh): the panel numbers its
		# RowButtons through one sequence, so asking past `rows()` alone stopped meaning
		# "past the end" the moment the two audio dials landed underneath the three
		# switches. Summing both is what keeps this assertion about the END of the panel
		# rather than about the end of the switches.
		var row_count: int = screen.rows().size() + screen.dials().size()
		err = _T.assert_true(screen.get_node_or_null("RowButton%d" % row_count) == null,
			"and there is no row for a switch or dial that does not exist")
	if err == "":
		# The mute rows are inverted on purpose: the owner stores "muted", and a
		# row labelled Sound effects reading On while silent would be lying.
		Sfx.set_muted(true)
		Music.set_muted(true)
		screen.refresh()
		err = _T.assert_false(OptionsScreen.is_on(OptionsScreen.MUTE_SFX),
			"a muted Sfx reads as Sound effects OFF, not on")
		if err == "":
			err = _T.assert_false(OptionsScreen.is_on(OptionsScreen.MUTE_MUSIC),
				"and the same for Music")
		if err == "":
			err = _T.assert_eq((screen.get_node("RowButton1") as Button).text, OptionsScreen.OFF_TEXT,
				"and refresh() reads the flag back rather than a copy the screen kept")
		Sfx.set_muted(false)
		Music.set_muted(false)
		screen.refresh()
	if err == "":
		# An unknown id flips nothing rather than erroring -- a renamed switch
		# should go quiet, not take the screen down.
		err = _T.assert_false(OptionsScreen.toggle(&"not_a_switch"), "an undeclared switch cannot be flipped")
		if err == "":
			err = _T.assert_false(OptionsScreen.is_on(&"not_a_switch"), "and reads as off")
	if err == "":
		# set_on is the writer every button press goes through; named directly so
		# the absolute setter is exercised and not only the toggle sitting over it.
		err = _T.assert_true(OptionsScreen.set_on(OptionsScreen.MUTE_SFX, true),
			"set_on turns a switch on and reports the state it left")
		if err == "":
			err = _T.assert_false(OptionsScreen.set_on(OptionsScreen.MUTE_SFX, false), "and off again")
		if err == "":
			err = _T.assert_true(OptionsScreen.set_on(OptionsScreen.MUTE_SFX, true), "idempotently")
		Sfx.set_muted(false)
		screen.refresh()
	if err == "":
		# The overlay has to cover the whole viewport it read its size from --
		# PRESET_FULL_RECT resolves to 0x0 for a Control added by add_child()
		# outside a layout pass, which is why these two getters exist at all.
		err = _T.assert_eq(int(screen.size.x), screen.get_viewport_width(),
			"the backdrop spans the viewport width it asked for")
		if err == "":
			err = _T.assert_eq(int(screen.size.y), screen.get_viewport_height(),
				"and its height")
	if err == "":
		# The one switch that is actually in the save file, end to end. The bytes
		# are pinned because a colourblind flip goes through RunConfig._save.
		screen.flip(OptionsScreen.COLORBLIND)
		err = _T.assert_true(RunConfig.colorblind_safe, "the colourblind row sets the flag")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(path),
				"v%d\n0\n0\nm0\ncb1 sfx0 mus0 spd0 svol0 mvol0\n0\n" % RunConfig.SAVE_VERSION,
				"and it is written down beside the scores, not held for the session")
	if err == "":
		# Nothing on the paper may run off it or sit on top of anything else, and the
		# footer must stand CLEAR of the last row rather than merely not intersecting
		# it. Both halves are the shared helper's now: this screen and the Keys screen
		# were asserting the same rule at two different numbers.
		err = _overlay_content_fits_and_stands_clear(screen)

	_T.free_ui(screen)
	RunConfig.save_path = stashed_path
	RunConfig.load_status = stashed_status
	RunConfig.key_bindings = stashed_bindings
	RunConfig.campaign_high_score = stashed_campaign
	RunConfig.endless_high_score = stashed_endless
	RunConfig.colorblind_safe = stashed_colorblind
	RunConfig.earned_milestones = stashed_milestones
	RunConfig.mute_sfx = stashed_mute_sfx
	RunConfig.mute_music = stashed_mute_music
	Sfx.set_muted(stashed_sfx)
	Music.set_muted(stashed_music)
	KeyBindings.reset_all()
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	return err


# -- Selection marker (plant-tower-defense-42t) ------------------------------


## ChompFlower fully overrides Plant._draw() to paint its own chew ring and
## never chains to super — a selection cue that lived there would never have
## rendered for this plant at all. The marker has to be a separate node to
## survive that.
func test_a_chomp_flowers_selection_marker_shows_even_though_it_owns_draw() -> String:
	var chomp := ChompFlower.new()
	chomp.setup(PlantCatalog.CHOMP, Vector2i(0, 0), null)
	await _T.instantiate_scene(_host([chomp]))
	var err: String = _T.assert_false(chomp._selection_marker.visible, "starts deselected")
	if err == "":
		chomp.set_selected(true)
		err = _T.assert_true(chomp._selection_marker.visible, "selecting shows the marker regardless of the subclass's own _draw()")
	if err == "":
		chomp.set_selected(false)
		err = _T.assert_false(chomp._selection_marker.visible, "deselecting hides it again")
	_T.free_ui(chomp)
	return err


## Every plant gets the same marker from the base class, not just the ones
## that happen to draw a range ring — Sunflower has no overlay of its own.
func test_a_sunflowers_selection_marker_is_shared_from_the_base_plant_class() -> String:
	var sunflower := Sunflower.new()
	sunflower.setup(PlantCatalog.SUNFLOWER, Vector2i(0, 0), null)
	await _T.instantiate_scene(_host([sunflower]))
	var err: String = _T.assert_true(sunflower._selection_marker is SelectionMarker, "Plant._build_visuals wires up a SelectionMarker")
	if err == "":
		sunflower.set_selected(true)
		err = _T.assert_true(sunflower._selection_marker.visible, "selecting a plain plant shows it too")
	_T.free_ui(sunflower)
	return err


## Every animation in this project layers on an already-correct final state,
## same rule GardenTheme.animations_enabled() enforces everywhere else.
## Selecting a plant must leave its brackets fully shown and fully sized even
## though headless never pumps SelectionMarker.play_entrance()'s own tween.
func test_selecting_a_plant_never_leaves_the_marker_mid_grow_headlessly() -> String:
	var sunflower := Sunflower.new()
	sunflower.setup(PlantCatalog.SUNFLOWER, Vector2i(0, 0), null)
	await _T.instantiate_scene(_host([sunflower]))
	var marker: SelectionMarker = sunflower._selection_marker
	var err: String = _T.assert_false(GardenTheme.animations_enabled(),
		"this test is only meaningful headless, where animations are off")
	if err == "":
		sunflower.set_selected(true)
		err = _T.assert_eq(marker.scale, Vector2.ONE,
			"play_entrance is a no-op headless, so scale never drops below full")
	if err == "":
		err = _T.assert_eq(marker.modulate, Color.WHITE, "and modulate stays opaque")
	if err == "":
		# A second, direct call must not error or leave a tween nobody will ever
		# pump a frame for.
		marker.play_entrance()
		err = _T.assert_eq(marker._entrance_tween, null,
			"play_entrance never creates a tween while animations are gated off")
	_T.free_ui(sunflower)
	return err


# -- Lane pressure readout (plant-tower-defense-4wv) -------------------------


func test_recording_lane_pressure_lights_up_the_cell_at_full_strength() -> String:
	var board := Board.new()
	await _T.instantiate_scene(board)
	var cell: Vector2i = Board.PATH_CORNERS[0]
	var err: String = _T.assert_eq(board.lane_pressure_alpha(cell), 0.0, "nothing recorded yet")
	if err == "":
		board.record_lane_pressure(cell)
		err = _T.assert_eq(board.lane_pressure_alpha(cell), 1.0, "a fresh recording is full strength")
	_T.free_ui(board)
	return err


## Cells off the road (an escaped pest's off-board position, a typo'd cell)
## must not paint — record_lane_pressure is meant to answer "where on the
## road", not "wherever a pest happened to be standing".
func test_recording_lane_pressure_off_the_road_is_ignored() -> String:
	var board := Board.new()
	await _T.instantiate_scene(board)
	board.record_lane_pressure(Vector2i(0, 0))  # (0,0) is grass, not path
	var err: String = _T.assert_eq(board.lane_pressure_alpha(Vector2i(0, 0)), 0.0, "grass cells never light up")
	_T.free_ui(board)
	return err


## The whole point of the readout is that it reads as *recent* pressure, not
## a permanent stain from wave 1 — recording a new cell must fade the old one
## rather than leaving it at full strength forever.
func test_a_new_lane_pressure_cell_fades_the_previous_one() -> String:
	var board := Board.new()
	await _T.instantiate_scene(board)
	var first: Vector2i = Board.PATH_CORNERS[0]
	var second: Vector2i = Board.PATH_CORNERS[1]
	board.record_lane_pressure(first)
	board.record_lane_pressure(second)
	var err: String = _T.assert_eq(board.lane_pressure_alpha(second), 1.0, "the newly recorded cell is full strength")
	if err == "":
		err = _T.assert_eq(board.lane_pressure_alpha(first), Board.LANE_PRESSURE_DECAY, "the earlier cell faded by exactly one decay step")
	_T.free_ui(board)
	return err


## Caught live: losing the last life mid-wave sets game_over, and
## Game._process's own `if game_over: return` guard means _check_wave_cleared
## — the only place that used to commit lane pressure — never runs on that
## path, so a wave lost outright left the readout silently a whole wave
## stale forever. _on_pest_escaped must commit it itself before that guard
## gets a chance to swallow it.
func test_lane_pressure_is_committed_even_when_the_last_life_is_lost_mid_wave() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game._on_wave_started(1)
	var cell: Vector2i = Board.PATH_CORNERS[0]
	game._wave_losses[cell] = 1
	game.lives = 1
	var err: String = _T.assert_eq(game.board.lane_pressure_alpha(cell), 0.0, "nothing committed yet")
	if err == "":
		game._on_pest_escaped(null)
		err = _T.assert_true(game.game_over, "losing the last life ends the run")
	if err == "":
		err = _T.assert_eq(game.board.lane_pressure_alpha(cell), 1.0,
			"the wave's lane pressure was committed on the losing escape, not lost to the _process(game_over) guard")
	_T.free_ui(game)
	return err


# -- Husk size/glow scales with value (plant-tower-defense-afd) --------------


## The point of the feature: two husks of different worth must not draw the
## same. Asserted on the pure sizing function rather than on pixels, so the
## relationship survives any later restyle of the actual _draw().
func test_a_richer_husk_draws_bigger_than_a_poorer_one() -> String:
	var poor: float = HuskLayer.radius_for(2)
	var rich: float = HuskLayer.radius_for(9)
	var err: String = _T.assert_true(rich > poor,
		"a 9-seed husk (radius %.1f) draws larger than a 2-seed one (radius %.1f)" % [rich, poor])
	if err == "":
		err = _T.assert_true(HuskLayer.glow_for(9) > HuskLayer.glow_for(2),
			"and glows harder as well as being bigger")
	return err


## Both ends are clamped, so a value outside the range the game actually drops
## (a devtools-staged husk, a future pest with different seeds) still draws a
## husk rather than a dot or a dinner plate.
func test_husk_radius_is_clamped_at_both_ends() -> String:
	var err: String = _T.assert_eq(HuskLayer.radius_for(0), HuskLayer.BASE_RADIUS,
		"below the cheapest husk still draws at the base size")
	if err == "":
		err = _T.assert_eq(HuskLayer.radius_for(999), HuskLayer.MAX_RADIUS,
			"an absurd value is capped, not scaled forever")
	if err == "":
		err = _T.assert_eq(HuskLayer.glow_for(0), 0.0, "glow floors at 0")
	if err == "":
		err = _T.assert_eq(HuskLayer.glow_for(999), 1.0, "glow ceilings at 1")
	return err


## A husk drawn wider than CompostMeter.COLLECT_RADIUS would show the player
## pixels that a click landing on them does not sweep. The ring is the outer
## edge of the drawing, so that — not the body — is what has to fit.
func test_the_biggest_husk_still_fits_inside_its_own_click_radius() -> String:
	var outer: float = HuskLayer.MAX_RADIUS + HuskLayer.RING_GAP + HuskLayer.RING_WIDTH_MAX
	return _T.assert_true(outer <= CompostMeter.COLLECT_RADIUS,
		"the largest husk's outer edge (%.1f) is inside COLLECT_RADIUS (%.1f), so every drawn pixel is clickable"
			% [outer, CompostMeter.COLLECT_RADIUS])


## Every husk value the game can actually drop, derived rather than listed: each
## species' seed count crossed with every mutation set `Pest.mutations_compose`
## permits, through the one formula `Game._on_pest_died` uses.
##
## Derived because the hand-written version of this was wrong. It read the two
## ends off memory — plain aphid at the bottom, hungry beetle at the top — and
## asserted the beetle "is the largest size". That was true until cycle 81 made
## `husk_multiplier` a product; a hungry beetle is now sixth of ten, and a queen
## drops nearly seven times it.
static func _reachable_husk_values() -> Array[int]:
	var multipliers: Dictionary = {1.0: true}
	for a: StringName in Pest.MUTATION_HUSK_MULTIPLIER:
		var ma: float = float(Pest.MUTATION_HUSK_MULTIPLIER[a])
		multipliers[ma] = true
		for b: StringName in Pest.MUTATION_HUSK_MULTIPLIER:
			if Pest.mutations_compose(a, b):
				multipliers[ma * float(Pest.MUTATION_HUSK_MULTIPLIER[b])] = true
	var seen: Dictionary = {}
	for species: StringName in Pest.SPECIES:
		var seeds: int = int(Pest.SPECIES[species]["seeds"])
		for m: float in multipliers:
			seen[CompostMeter.husk_value_for(seeds, m)] = true
	var out: Array[int] = []
	for v: int in seen:
		out.append(v)
	out.sort()
	return out


## A richer husk must never draw as a poorer one. Radius, glow and pip count all
## rise together or hold, across the whole derived drop table — the property that
## matters, and the one a saturating cue keeps while losing everything else.
func test_no_husk_the_game_drops_ever_looks_poorer_than_a_cheaper_one() -> String:
	var values: Array[int] = _reachable_husk_values()
	var err: String = _T.assert_gt(values.size(), 4,
		"the drop table has enough distinct values to be worth ordering (%d)" % values.size())
	if err != "":
		return err
	for i: int in range(values.size() - 1):
		var lo: int = values[i]
		var hi: int = values[i + 1]
		err = _T.assert_true(
			HuskLayer.radius_for(hi) >= HuskLayer.radius_for(lo)
				and HuskLayer.glow_for(hi) >= HuskLayer.glow_for(lo)
				and HuskLayer.overflow_pips(hi) >= HuskLayer.overflow_pips(lo),
			"a %d-seed husk never draws smaller, dimmer or fewer-pipped than a %d-seed one"
				% [hi, lo])
		if err != "":
			return err
	return err


## The measurement `-532j` asked for, kept as an assertion so the answer cannot
## quietly change: which husks the player genuinely cannot tell apart.
##
## Radius and glow both saturate at CompostMeter.FULL_VALUE, so before pips SIX
## of the ten reachable values drew as one husk — including the two this test
## names, which are the single-mutation and paired-mutation kills of the same
## species. That is the second-mutation feature's payout being invisible at the
## exact comparison a player makes.
##
## What is left is the cap's own promise: past PIP_MAX pips the cue says "very
## rich" rather than a number. Every remaining collision must be up there, and
## the assertion is phrased against PIP_MAX so changing the cap moves the
## expected answer with it instead of failing.
func test_the_only_husks_that_look_alike_are_the_ones_the_pip_cap_lumps_together() -> String:
	var beetle: int = int(Pest.SPECIES[Pest.BEETLE]["seeds"])
	var single: int = CompostMeter.husk_value_for(beetle,
		float(Pest.MUTATION_HUSK_MULTIPLIER[Pest.MUTATION_HUNGRY]))
	var paired: int = CompostMeter.husk_value_for(beetle,
		float(Pest.MUTATION_HUSK_MULTIPLIER[Pest.MUTATION_HUNGRY])
			* float(Pest.MUTATION_HUSK_MULTIPLIER[Pest.MUTATION_ARMOURED]))
	var err: String = _T.assert_true(
		HuskLayer.radius_for(single) == HuskLayer.radius_for(paired)
			and HuskLayer.glow_for(single) == HuskLayer.glow_for(paired),
		"the smooth cues genuinely cannot separate a %d-seed husk from a %d-seed one -- that is why pips exist"
			% [single, paired])
	if err == "":
		err = _T.assert_gt(HuskLayer.overflow_pips(paired), HuskLayer.overflow_pips(single),
			"and the pips do: %d pip(s) against %d"
				% [HuskLayer.overflow_pips(paired), HuskLayer.overflow_pips(single)])
	if err != "":
		return err

	var lumped: int = HuskLayer.PIP_MAX * CompostMeter.FULL_VALUE
	for value: int in _reachable_husk_values():
		for other: int in _reachable_husk_values():
			if other == value:
				continue
			var same: bool = HuskLayer.radius_for(value) == HuskLayer.radius_for(other) \
				and HuskLayer.glow_for(value) == HuskLayer.glow_for(other) \
				and HuskLayer.overflow_pips(value) == HuskLayer.overflow_pips(other)
			if not same:
				continue
			err = _T.assert_true(value >= lumped and other >= lumped,
				"husks worth %d and %d draw identically, and both are at or over the %d seeds where PIP_MAX stops counting"
					% [value, other, lumped])
			if err != "":
				return err
	return err


# -- A swept husk's payout flies to the Seeds label (plant-tower-defense-o2b) -


## The glyph opens at the husk's own drawn size, not a fixed one — a beetle's
## payout should read as the same husk that just sat there glowing, not a
## generic sparkle every sweep produces identically.
##
## Parented under a live Hud's own FxLayer before launch(), not a bare
## SeedGlyph.new() — create_tween() requires the node to already be inside a
## SceneTree, exactly the requirement Hud.fly_seed_glyph satisfies in the
## real game by adding the glyph before calling launch().
func test_seed_glyph_opens_at_the_husks_own_radius_and_flies_to_where_its_told() -> String:
	var game := await _T.instantiate_scene("res://game/game.tscn") as Game
	var glyph := SeedGlyph.new()
	game.hud._fx_layer.add_child(glyph)
	var from := Vector2(120.0, 300.0)
	var to := Vector2(40.0, 20.0)
	var radius: float = HuskLayer.radius_for(9)
	glyph.launch(from, to, radius)
	var err: String = _T.assert_eq(glyph.position, from,
		"the glyph starts exactly where the husk was swept")
	if err == "":
		err = _T.assert_eq(glyph._radius, radius,
			"and opens at HuskLayer.radius_for(9) rather than a fixed size")
	if err == "":
		err = _T.assert_true(glyph.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"a travelling decoration never eats a click")
	_T.free_ui(game)
	return err


## Same rule as every other animation in this project: headless is an
## already-correct final state with nothing left mid-flight, not a broken
## flourish. Hud.fly_seed_glyph is the gate — a game that cannot animate must
## not leave FxLayer accumulating glyphs nobody will ever finish tweening.
func test_fly_seed_glyph_is_a_total_no_op_headless() -> String:
	var game := await _T.instantiate_scene("res://game/game.tscn") as Game
	var err: String = _T.assert_false(GardenTheme.animations_enabled(),
		"this test is only meaningful headless, where animations are off")
	if err == "":
		var before: int = game.hud._fx_layer.get_child_count()
		game.hud.fly_seed_glyph(Vector2(50.0, 50.0), CompostMeter.FULL_VALUE)
		err = _T.assert_eq(game.hud._fx_layer.get_child_count(), before,
			"no SeedGlyph is created while animations are gated off")
	_T.free_ui(game)
	return err


## End to end through the real signal chain, not the two halves tested apart:
## CompostMeter.collect_at() -> husk_collected(value, at) ->
## Game._on_husk_collected -> Hud.fly_seed_glyph. A husk collected through the
## actual game must not error and must not leave FxLayer holding a glyph
## headlessly, exercising the exact `at` Game hands to to_global() rather than
## a value this test picks by hand.
func test_collecting_a_real_husk_through_game_reaches_fly_seed_glyph_without_error() -> String:
	var game := await _T.instantiate_scene("res://game/game.tscn") as Game
	var err: String = _T.assert_true(game.hud != null, "the real game builds a HUD")
	if err == "":
		var spot := Vector2(160.0, 160.0)
		game.compost.drop_husk(spot, CompostMeter.BASE_VALUE)
		var paid: int = game.compost.collect_at(spot)
		err = _T.assert_eq(paid, CompostMeter.BASE_VALUE,
			"the sweep still pays out with fly_seed_glyph wired into the signal")
	if err == "":
		err = _T.assert_eq(game.hud._fx_layer.get_child_count(), 0,
			"and headlessly the glyph the gate skipped leaves nothing behind")
	_T.free_ui(game)
	return err


# -- Endless mode scales the pests themselves (plant-tower-defense-nps) ------


## Campaign must be bit-for-bit unaffected. Both scales key off `wave - WAVES.size()`
## with no endless flag involved, so this is the check that the shared shape
## really does leave the fixed table alone.
##
## HALF OF THAT IS HISTORY (plant-tower-defense-iqp8). The campaign has a second act
## now and health is what carries it, so the claim this test can still make about
## health is the narrower and more interesting one: the FIRST act is untouched. That
## is what stops the ramp landing on wave 9 next to a +29.1% count step, which is the
## two-increases-on-one-wave problem cycle 101 spent its budget removing.
##
## Speed IS still flat across the whole table, and that asymmetry is the design: speed
## feeds `crossing_seconds`, hence `_paced_gap` and `peak_simultaneous_pests`, so a
## campaign speed ramp would silently re-price every road budget in wave_director.gd.
## Health feeds damage and nothing else. That is why health was the lever.
func test_pest_scaling_is_exactly_neutral_through_the_fixed_table() -> String:
	var swept: int = 0
	for w: int in range(1, WaveDirector.WAVES.size() + 1):
		var err: String = _T.assert_float_eq(WaveDirector.speed_scale_for(w), 1.0, 0.0001,
			"wave %d speed is unscaled" % w)
		if err == "" and w <= WaveDirector.SECOND_ACT_START_WAVE:
			err = _T.assert_float_eq(WaveDirector.health_scale_for(w), 1.0, 0.0001,
				("wave %d is in the first act and its health is unscaled -- the second"
					+ " act anchors at wave %d and climbs from wave %d")
					% [w, WaveDirector.SECOND_ACT_START_WAVE,
						WaveDirector.SECOND_ACT_START_WAVE + 1])
		if err != "":
			return err
		swept += 1
	# The old `return ""` let a zero-wave table pass in silence.
	return _T.assert_gt(swept, 20, "the whole fixed table was swept (%d waves)" % swept)


func test_pest_scaling_climbs_the_further_endless_mode_runs() -> String:
	var table: int = WaveDirector.WAVES.size()
	var early_health: float = WaveDirector.health_scale_for(table + 1)
	var late_health: float = WaveDirector.health_scale_for(table + 10)
	var err: String = _T.assert_true(late_health > early_health,
		"health scale climbs (%.3f at +1 -> %.3f at +10)" % [early_health, late_health])
	if err == "":
		err = _T.assert_true(WaveDirector.speed_scale_for(table + 10) > WaveDirector.speed_scale_for(table + 1),
			"and so does speed")
	if err == "":
		err = _T.assert_true(late_health > WaveDirector.speed_scale_for(table + 10),
			"health is the bigger lever of the two, by design")
	return err


## Both are capped, and the caps are what keep the mode playable: an uncapped
## speed ramp eventually outruns every plant's reaction window no matter what
## the player built.
func test_pest_scaling_is_capped_so_a_very_long_run_stays_playable() -> String:
	var err: String = _T.assert_float_eq(WaveDirector.health_scale_for(10000), WaveDirector.ENDLESS_HEALTH_MAX, 0.0001,
		"health saturates at its ceiling")
	if err == "":
		err = _T.assert_float_eq(WaveDirector.speed_scale_for(10000), WaveDirector.ENDLESS_SPEED_MAX, 0.0001,
			"speed saturates at its ceiling")
	if err == "":
		var top: float = float(Pest.SPECIES[Pest.APHID]["speed"]) * WaveDirector.ENDLESS_SPEED_MAX
		err = _T.assert_true(top * (1.0 / 60.0) < Board.CELL,
			"even the fastest possible aphid (%.0f px/s) crosses less than one %dpx cell per frame, so it cannot skip past a plant's range between physics ticks"
				% [top, int(Board.CELL)])
	return err


## A scaled pest must arrive with a full bar, not at species health out of a
## raised maximum — that would read as pre-damaged and make the first several
## hits look like they did nothing.
func test_a_scaled_pest_spawns_at_full_health() -> String:
	var pest := Pest.new()
	pest.setup(Pest.BEETLE, PackedVector2Array([Vector2.ZERO, Vector2(100, 0)]))
	var base: float = pest.max_health
	pest.apply_wave_scaling(2.5, 1.2)
	var err: String = _T.assert_float_eq(pest.max_health, base * 2.5, 0.0001, "the maximum went up")
	if err == "":
		err = _T.assert_float_eq(pest.health, pest.max_health, 0.0001, "and it spawned full, not pre-damaged")
	pest.free()
	return err


## Mutations touch chew_seconds, wave scaling touches health/speed — the comment
## on apply_wave_scaling claims they compose in either order, so check it rather
## than trusting the claim.
func test_wave_scaling_and_a_mutation_compose_in_either_order() -> String:
	var route := PackedVector2Array([Vector2.ZERO, Vector2(100, 0)])
	var first := Pest.new()
	first.setup(Pest.BEETLE, route)
	first.apply_wave_scaling(2.0, 1.5)
	first.apply_mutation(Pest.MUTATION_ARMOURED)
	var second := Pest.new()
	second.setup(Pest.BEETLE, route)
	second.apply_mutation(Pest.MUTATION_ARMOURED)
	second.apply_wave_scaling(2.0, 1.5)
	var err: String = _T.assert_float_eq(first.max_health, second.max_health, 0.0001, "same health either way")
	if err == "":
		err = _T.assert_float_eq(first.speed, second.speed, 0.0001, "same speed either way")
	if err == "":
		err = _T.assert_float_eq(first.chew_seconds, second.chew_seconds, 0.0001, "same chew time either way")
	first.free()
	second.free()
	return err


## The whole feature, through the path the game actually uses: Game.spawn_pest
## must read the live wave number off the director, not spawn species defaults.
func test_a_pest_spawned_deep_in_endless_is_tougher_than_a_wave_one_pest() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.director.current_wave = 1
	var early: Pest = _spawn_and_take(game, Pest.APHID)
	if early == null:
		_T.free_ui(game)
		return _T.assert_true(false, "spawn_pest put a new pest in the pests group")
	var base_health: float = early.max_health
	var base_speed: float = early.speed
	early.queue_free()

	game.director.current_wave = WaveDirector.WAVES.size() + 20
	game.spawn_pest(Pest.APHID)
	var late: Pest = null
	for p: Node in game.get_tree().get_nodes_in_group("pests"):
		if p != early:
			late = p as Pest
	var err: String = _T.assert_true(late != null, "the late-wave pest spawned")
	if err == "":
		err = _T.assert_true(late.max_health > base_health,
			"a wave-%d aphid has more health (%.1f) than a wave-1 one (%.1f)"
				% [game.director.current_wave, late.max_health, base_health])
	if err == "":
		err = _T.assert_true(late.speed > base_speed,
			"and walks faster (%.1f vs %.1f)" % [late.speed, base_speed])
	_T.free_ui(game)
	return err


# -- Lane pressure records every loss cell (plant-tower-defense-j1h) ---------


## The defect this replaced: committing a wave one cell at a time meant each
## cell faded its own wave-mates, so a wave that lost pests at three points
## ended with two of them dimmed and only the last at full strength. One batch,
## one fade.
func test_every_cell_a_wave_lost_a_pest_at_lights_up_together() -> String:
	var board := Board.new()
	await _T.instantiate_scene(board)
	var a: Vector2i = Board.PATH_CORNERS[0]
	var b: Vector2i = Board.PATH_CORNERS[1]
	board.record_lane_pressure_wave({a: 2, b: 2})
	var err: String = _T.assert_eq(board.lane_pressure_alpha(a), 1.0, "both cells of one wave are at full strength")
	if err == "":
		err = _T.assert_eq(board.lane_pressure_alpha(b), 1.0, "the second one was not faded by the first")
	_T.free_ui(board)
	return err


## The readout is a distribution, so a cell that ate half the wave must outrank
## one that ate a single pest.
func test_a_busier_cell_paints_stronger_than_a_quieter_one() -> String:
	var board := Board.new()
	await _T.instantiate_scene(board)
	var busy: Vector2i = Board.PATH_CORNERS[0]
	var quiet: Vector2i = Board.PATH_CORNERS[1]
	board.record_lane_pressure_wave({busy: 8, quiet: 2})
	var err: String = _T.assert_eq(board.lane_pressure_alpha(busy), 1.0, "the wave's worst cell is the full-strength one")
	if err == "":
		err = _T.assert_float_eq(board.lane_pressure_alpha(quiet), 0.25, 0.0001,
			"and a cell that took a quarter of the losses paints at a quarter")
	_T.free_ui(board)
	return err


## Normalising per wave is what keeps an 80-pest endless wave from saturating
## everything: the same shape of losses reads the same whether the wave was
## five pests or eighty.
func test_the_picture_is_the_same_shape_regardless_of_wave_size() -> String:
	var small := Board.new()
	await _T.instantiate_scene(small)
	var big := Board.new()
	await _T.instantiate_scene(big)
	var a: Vector2i = Board.PATH_CORNERS[0]
	var b: Vector2i = Board.PATH_CORNERS[1]
	small.record_lane_pressure_wave({a: 4, b: 1})
	big.record_lane_pressure_wave({a: 64, b: 16})
	var err: String = _T.assert_float_eq(small.lane_pressure_alpha(a), big.lane_pressure_alpha(a), 0.0001,
		"a five-pest wave and an eighty-pest wave with the same ratio paint the same")
	if err == "":
		err = _T.assert_float_eq(small.lane_pressure_alpha(b), big.lane_pressure_alpha(b), 0.0001,
			"at the quiet cell too")
	_T.free_ui(small)
	_T.free_ui(big)
	return err


## "One got through here" is the single most worth-seeing reading on the board,
## and a pure proportion would erase it in a big wave.
func test_a_single_loss_in_a_huge_wave_is_still_visible() -> String:
	var board := Board.new()
	await _T.instantiate_scene(board)
	var busy: Vector2i = Board.PATH_CORNERS[0]
	var lone: Vector2i = Board.PATH_CORNERS[1]
	board.record_lane_pressure_wave({busy: 400, lone: 1})
	var err: String = _T.assert_true(board.lane_pressure_alpha(lone) >= Board.LANE_PRESSURE_MIN_ALPHA,
		"1 loss against 400 still paints at least MIN_ALPHA (got %.3f)" % board.lane_pressure_alpha(lone))
	_T.free_ui(board)
	return err


## Off-road cells are dropped from a batch without dropping the batch — a
## caller mixing one bad cell in must not lose the good ones with it.
func test_an_off_road_cell_in_a_batch_does_not_discard_the_rest() -> String:
	var board := Board.new()
	await _T.instantiate_scene(board)
	var good: Vector2i = Board.PATH_CORNERS[0]
	board.record_lane_pressure_wave({good: 1, Vector2i(0, 0): 5})
	var err: String = _T.assert_eq(board.lane_pressure_alpha(Vector2i(0, 0)), 0.0, "the grass cell was ignored")
	if err == "":
		err = _T.assert_eq(board.lane_pressure_alpha(good), 1.0,
			"and the road cell still painted at full strength, normalised against the road cells only")
	_T.free_ui(board)
	return err


## An escaped pest is off the board by the time the signal fires, so its own
## position is not a road cell. It has to be attributed to the exit or the
## worst outcome in the game leaves no mark at all.
func test_an_escaped_pest_marks_the_exit_cell() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game._on_wave_started(1)
	var exit: Vector2i = game.board.exit_cell()
	var err: String = _T.assert_true(game.board.is_path(exit), "the exit cell is a road cell")
	if err == "":
		game._on_pest_escaped(null)
		err = _T.assert_eq(int(game._wave_losses.get(exit, 0)), 1, "the escape was tallied against the exit")
	if err == "":
		game._commit_lane_pressure()
		err = _T.assert_eq(game.board.lane_pressure_alpha(exit), 1.0, "and it paints once committed")
	_T.free_ui(game)
	return err


## The whole path through Game: kill pests at two different points on the road
## and both must show up, which is exactly what the old single-high-water-mark
## version could not do.
func test_two_pests_killed_at_different_points_both_show_up() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game._on_wave_started(1)
	var near: Vector2i = Board.PATH_CORNERS[0]
	var far: Vector2i = Board.PATH_CORNERS[1]
	game._note_lane_loss(game.board.cell_to_world(near))
	game._note_lane_loss(game.board.cell_to_world(far))
	game._note_lane_loss(game.board.cell_to_world(far))
	game._commit_lane_pressure()
	var err: String = _T.assert_eq(game.board.lane_pressure_alpha(far), 1.0, "the cell that lost two pests is fully lit")
	if err == "":
		err = _T.assert_float_eq(game.board.lane_pressure_alpha(near), 0.5, 0.0001,
			"and the cell that lost one is lit at half — the old version showed nothing here at all")
	_T.free_ui(game)
	return err


## Losses are per-wave, not cumulative: starting a wave must clear the tally,
## or wave 40 would still be painting wave 3's deaths.
func test_a_new_wave_starts_the_loss_tally_over() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game._on_wave_started(1)
	game._note_lane_loss(game.board.cell_to_world(Board.PATH_CORNERS[0]))
	var err: String = _T.assert_eq(game._wave_losses.size(), 1, "the loss was tallied")
	if err == "":
		game._on_wave_started(2)
		err = _T.assert_eq(game._wave_losses.size(), 0, "the next wave starts from nothing")
	_T.free_ui(game)
	return err


# -- Placement preview (plant-tower-defense-rfh) -----------------------------


## The reuse the issue asked for: the preview must be the selection marker's
## own geometry in a different key, not a second bracket implementation that
## can drift out of shape from it.
func test_the_placement_preview_is_a_selection_marker() -> String:
	var preview := PlacementPreview.new()
	var err: String = _T.assert_true(preview is SelectionMarker,
		"PlacementPreview subclasses SelectionMarker rather than reimplementing brackets")
	if err == "":
		err = _T.assert_true(preview.half > SelectionMarker.HALF,
			"and sits a size outside the selection brackets (%.0f vs %.0f) so the two are told apart"
				% [preview.half, SelectionMarker.HALF])
	if err == "":
		err = _T.assert_true(PlacementPreview.OK_COLOR.a < SelectionMarker.MARKER_COLOR.a,
			"and is dimmer, so a hover never outshouts the plant actually selected")
	preview.free()
	return err


## The ring is the whole reason this exists — coverage used to be invisible
## until after the seeds were spent. Sourced from each plant's own constant, so
## this also pins that PlantCatalog.reach has not drifted from them.
func test_reach_comes_from_each_plants_own_constant() -> String:
	var err: String = _T.assert_float_eq(PlantCatalog.reach(PlantCatalog.CORN), CornCobbler.RANGE, 0.0001,
		"the Corn ring is CornCobbler.RANGE, not a copy of the number")
	if err == "":
		err = _T.assert_float_eq(PlantCatalog.reach(PlantCatalog.CHOMP), ChompFlower.GRAB_RADIUS, 0.0001,
			"the Chomp ring is its grab radius")
	if err == "":
		err = _T.assert_float_eq(PlantCatalog.reach(PlantCatalog.SUNFLOWER), 0.0, 0.0001,
			"a Sunflower reaches nothing, so it draws no ring")
	if err == "":
		err = _T.assert_float_eq(PlantCatalog.reach(&"no_such_plant"), 0.0, 0.0001,
			"an unknown id is 0.0, not an error mid-hover")
	return err


## Hovering a road cell, an occupied cell, or a cell you cannot pay for must
## all read as blocked — a green ring over a cell that would refuse the click
## is worse than no cue at all.
func test_hovering_the_road_reads_as_blocked() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var road: Vector2i = Board.PATH_CORNERS[0]
	game._update_preview(road, game.board.is_buildable(road) and game.plant_at(road) == null)
	var err: String = _T.assert_false(game._preview.placeable, "a road cell is not placeable")
	if err == "":
		var grass: Vector2i = _grass(game)
		game._update_preview(grass, true)
		err = _T.assert_true(game._preview.placeable, "and free grass with the free starter in hand is")
	_T.free_ui(game)
	return err


func test_a_cell_you_cannot_afford_reads_as_blocked() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var grass: Vector2i = _grass(game)
	# Spend the free starter so the Corn has a real price, then empty the bank.
	game.place_plant(PlantCatalog.CORN, grass)
	game.bank.seeds = 0
	var other: Vector2i = _grass(game)
	game._update_preview(other, true)
	var err: String = _T.assert_false(game._preview.placeable,
		"a legal cell with no seeds to pay for it draws blocked, not encouraging green")
	_T.free_ui(game)
	return err


## Two brackets stacked on one cell reads as a bug, and the plant already there
## has its own marker and ring saying the truthful thing.
func test_no_preview_is_drawn_over_a_cell_that_already_has_a_plant() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var grass: Vector2i = _grass(game)
	game._update_preview(grass, true)
	var err: String = _T.assert_true(game._preview.visible, "an empty cell previews")
	if err == "":
		game.place_plant(PlantCatalog.CORN, grass)
		game._update_preview(grass, false)
		err = _T.assert_false(game._preview.visible, "the same cell with a plant on it does not")
	_T.free_ui(game)
	return err


## Switching plants in the bar must move the ring immediately: a Chomp and a
## Corn differ by more than a factor of two in coverage, and a cue that waits
## for the next mouse motion shows the wrong one in the meantime.
func test_switching_the_selected_plant_redraws_the_ring_without_moving_the_mouse() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var grass: Vector2i = _grass(game)
	game._hover_cell = grass
	game._on_plant_chosen(PlantCatalog.CORN)
	var corn_reach: float = game._preview.reach
	game._on_plant_chosen(PlantCatalog.CHOMP)
	var err: String = _T.assert_float_eq(corn_reach, CornCobbler.RANGE, 0.0001, "the Corn's reach was showing")
	if err == "":
		err = _T.assert_float_eq(game._preview.reach, ChompFlower.GRAB_RADIUS, 0.0001,
			"and picking the Chomp swapped it with no mouse motion at all")
	_T.free_ui(game)
	return err


## The preview is positioned in Entities space at the cell centre, so the ring
## is actually centred on the cell it claims to cover. Placement bugs of this
## shape render as a perfectly plausible picture.
func test_the_preview_sits_on_the_centre_of_the_cell_it_previews() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var grass: Vector2i = _grass(game)
	game._update_preview(grass, true)
	var err: String = _T.assert_eq(game._preview.position, game.board.cell_to_world(grass),
		"the preview node is at the cell's centre, not its corner")
	_T.free_ui(game)
	return err


# -- HUD top bar cannot self-collide (plant-tower-defense-kcj) ---------------


## Containers lay their children out on a deferred sort, so a text change is not
## reflected in any child's size until frames have been pumped. Two is the floor
## for Controls; one reads the pre-sort geometry and passes over a broken layout.
func _pump(node: Node) -> void:
	await node.get_tree().process_frame
	await node.get_tree().process_frame


## Screen rects of every Control under `root`, keyed by name. Only leaf-ish
## Controls with a real size; containers are skipped because a child sharing
## its own parent's pixels is the normal case, not a finding.
func _hud_rects(root: Node) -> Dictionary:
	var out: Dictionary = {}
	for node: Node in root.find_children("*", "Control", true, false):
		var c := node as Control
		if c is Container or c is ColorRect:
			continue
		if not c.visible or c.size.x <= 0.0 or c.size.y <= 0.0:
			continue
		out[c.name] = Rect2(c.global_position, c.size)
	return out


## The bug this replaced, reproduced as an assertion: the top row's readouts
## grow at runtime, and at a fixed x the compost counter ran under the wave
## button. Asserted at the longest text the game can actually produce, because
## at the default text the broken layout also passed.
func test_the_top_bar_readouts_never_overlap_the_wave_button() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	# Longest realistic state: 4-digit seeds, 2-digit wave, 2-digit husk count.
	game.bank.seeds = 9999
	game.director.current_wave = 42
	for i: int in range(18):
		game.compost.drop_husk(Vector2(float(i) * 8.0, 0.0), 9)
	game._refresh()
	await _pump(game)

	var rects: Dictionary = _hud_rects(game.hud)
	var err: String = _T.assert_true(rects.has("CompostLabel") and rects.has("NextWaveButton"),
		"both the compost readout and the wave button are on screen to compare")
	if err == "":
		var compost: Rect2 = rects["CompostLabel"]
		var button: Rect2 = rects["NextWaveButton"]
		err = _T.assert_false(compost.intersects(button),
			"compost %s does not run under the wave button %s at the longest text the game produces"
				% [compost, button])
	_T.free_ui(game)
	return err


## Generalises the above: no two sized top-bar Controls may share pixels, so a
## readout added later inherits the check instead of needing its own.
func test_no_two_top_bar_controls_share_pixels() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.seeds = 9999
	game.director.current_wave = 42
	for i: int in range(18):
		game.compost.drop_husk(Vector2(float(i) * 8.0, 0.0), 9)
	game.hud.show_message("A message long enough to want the whole width of the bar and then some more.")
	game._refresh()
	await _pump(game)

	var bar: Node = game.hud.get_node("Root/TopBar")
	var rects: Dictionary = _hud_rects(bar)
	var names: Array = rects.keys()
	var err: String = _T.assert_true(names.size() >= 4,
		"found %d sized Controls in the top bar to compare" % names.size())
	for i: int in range(names.size()):
		if err != "":
			break
		for j: int in range(i + 1, names.size()):
			var a: Rect2 = rects[names[i]]
			var b: Rect2 = rects[names[j]]
			if a.intersects(b):
				err = _T.assert_false(true, "%s %s overlaps %s %s" % [names[i], a, names[j], b])
				break
	_T.free_ui(game)
	return err


## The layout must survive a counter longer than anything the game produces,
## since that is what "cannot collide" means as opposed to "does not today".
func test_an_absurdly_long_readout_pushes_rather_than_underlaps() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	await _pump(game)
	var button: Button = game.hud.get_node("Root/TopBar/StatsRow/NextWaveButton") as Button
	var before: float = button.global_position.x
	var compost: Label = game.hud.get_node("Root/TopBar/StatsRow/CompostLabel") as Label
	compost.text = "Compost 99999999  (99999 ready and then some)"
	await _pump(game)
	var err: String = _T.assert_false(
		Rect2(compost.global_position, compost.size).intersects(Rect2(button.global_position, button.size)),
		"even an absurd counter does not land under the button")
	if err == "":
		# The other way this breaks: rather than overlapping, an HBox that runs
		# out of slack pushes its last child off the right edge. Caught exactly
		# that here on the first run (916 -> 1013, i.e. 97px past the bar) before
		# the compost label was given a clipped width budget.
		err = _T.assert_float_eq(button.global_position.x, before, 0.5,
			"the button did not move at all (%.0f -> %.0f); the counter ellipsised inside its budget instead of shoving"
				% [before, button.global_position.x])
	if err == "":
		err = _T.assert_true(button.global_position.x + button.size.x <= float(game.hud.get_viewport_width()),
			"and the button is still fully on screen")
	if err == "":
		err = _T.assert_true(button.size.x >= Hud.NEXT_WAVE_BUTTON_SIZE.x,
			"and it never shrank below its minimum width")
	_T.free_ui(game)
	return err


# -- A richer husk rots faster (plant-tower-defense-kh9) ---------------------


## The decision the feature exists to create: with one shared timer, sweep
## order was free. Now the rich one is on a shorter clock.
func test_a_richer_husk_rots_sooner_than_a_poorer_one() -> String:
	var rich: float = CompostMeter.lifetime_for(CompostMeter.FULL_VALUE)
	var poor: float = CompostMeter.lifetime_for(CompostMeter.BASE_VALUE)
	var err: String = _T.assert_true(rich < poor,
		"a %d-seed husk lasts %.1fs against a %d-seed husk's %.1fs"
			% [CompostMeter.FULL_VALUE, rich, CompostMeter.BASE_VALUE, poor])
	if err == "":
		err = _T.assert_float_eq(poor, CompostMeter.HUSK_LIFETIME, 0.0001,
			"the cheapest husk still gets the full lifetime, so nothing got worse")
	if err == "":
		err = _T.assert_float_eq(rich, CompostMeter.MIN_HUSK_LIFETIME, 0.0001,
			"and the richest gets exactly the floor")
	return err


## Both ends clamp, so a husk outside the range the game drops still gets a
## sane clock rather than a negative or runaway one.
func test_every_husk_lifetime_stays_inside_its_two_bounds() -> String:
	var err: String = ""
	for value: int in [-5, 0, 1, 2, 5, 9, 50, 9999]:
		var span: float = CompostMeter.lifetime_for(value)
		err = _T.assert_true(span >= CompostMeter.MIN_HUSK_LIFETIME and span <= CompostMeter.HUSK_LIFETIME,
			"value %d gives %.2fs, inside [%.1f, %.1f]"
				% [value, span, CompostMeter.MIN_HUSK_LIFETIME, CompostMeter.HUSK_LIFETIME])
		if err != "":
			break
	return err


## The acceptance criterion, run as a race: two husks dropped at the same
## instant, and the valuable one must be gone first.
func test_of_two_husks_dropped_together_the_rich_one_vanishes_first() -> String:
	var compost := CompostMeter.new()
	compost.drop_husk(Vector2(0, 0), CompostMeter.FULL_VALUE)
	compost.drop_husk(Vector2(200, 0), CompostMeter.BASE_VALUE)
	# Step to just past the rich husk's clock but short of the poor one's.
	var midpoint: float = (CompostMeter.MIN_HUSK_LIFETIME + CompostMeter.HUSK_LIFETIME) * 0.5
	compost._process(midpoint)
	var err: String = _T.assert_eq(compost.husk_count(), 1,
		"at %.2fs exactly one of the two has rotted" % midpoint)
	if err == "":
		err = _T.assert_eq(compost.collect_at(Vector2(0, 0)), 0, "and it is the rich one that is gone")
	if err == "":
		err = _T.assert_eq(compost.collect_at(Vector2(200, 0)), CompostMeter.BASE_VALUE,
			"while the cheap one is still there to sweep")
	compost.free()
	return err


## The rot ring divides by the husk's own max_life. If it divided by the
## constant, a rich husk would still show ~55% of its ring at the instant it
## disappeared — visible only as "husks sometimes pop without warning".
func test_the_rot_ring_empties_exactly_as_the_husk_expires() -> String:
	var compost := CompostMeter.new()
	compost.drop_husk(Vector2.ZERO, CompostMeter.FULL_VALUE)
	var span: float = CompostMeter.lifetime_for(CompostMeter.FULL_VALUE)
	compost._process(span * 0.9)
	var h: Dictionary = compost.husks()[0]
	var frac: float = float(h["life"]) / float(h["max_life"])
	var err: String = _T.assert_float_eq(frac, 0.1, 0.02,
		"at 90%% through its own life the ring reads ~10%% remaining, not %.0f%%" % (frac * 100.0))
	if err == "":
		err = _T.assert_true(float(h["max_life"]) < CompostMeter.HUSK_LIFETIME,
			"and max_life really is this husk's own shorter clock, not the global one")
	compost.free()
	return err


## Size, glow and urgency must all key off one curve — a husk that draws rich
## and rots slow would be two cues pointing opposite ways.
func test_size_glow_and_urgency_all_agree_about_which_husk_is_rich() -> String:
	var rich: int = CompostMeter.FULL_VALUE
	var poor: int = CompostMeter.BASE_VALUE
	var err: String = _T.assert_true(HuskLayer.radius_for(rich) > HuskLayer.radius_for(poor),
		"the rich husk draws bigger")
	if err == "":
		err = _T.assert_true(HuskLayer.glow_for(rich) > HuskLayer.glow_for(poor),
			"and glows harder")
	if err == "":
		err = _T.assert_true(CompostMeter.lifetime_for(rich) < CompostMeter.lifetime_for(poor),
			"and is the one on the shorter clock")
	if err == "":
		err = _T.assert_float_eq(HuskLayer.glow_for(rich), CompostMeter.value_fraction(rich), 0.0001,
			"glow is literally the same curve the timer reads, not a parallel copy")
	return err


# -- Readable threat level (plant-tower-defense-o1p) -------------------------


## Wave 1 is the unit, by construction. If this drifts, every other threat
## number on the bar silently rescales.
func test_wave_one_is_the_threat_unit() -> String:
	return _T.assert_float_eq(WaveDirector.threat_for(1), 1.0, 0.0001,
		"wave 1 is x1.0, which is what makes every other number readable")


## The fixed table has to climb too, or the readout is dead weight for the
## whole campaign and only wakes up in endless.
func test_threat_climbs_across_every_wave_of_the_fixed_table() -> String:
	var err: String = ""
	var previous: float = 0.0
	for w: int in range(1, WaveDirector.WAVES.size() + 1):
		var threat: float = WaveDirector.threat_for(w)
		err = _T.assert_true(threat > previous,
			"wave %d (x%.2f) is harder than wave %d (x%.2f)" % [w, threat, w - 1, previous])
		if err != "":
			break
		previous = threat
	return err


## The point of the feature: past the table, five things climb independently
## and the number has to keep moving for all of them.
func test_threat_keeps_climbing_deep_into_endless() -> String:
	var table: int = WaveDirector.WAVES.size()
	var err: String = ""
	var previous: float = WaveDirector.threat_for(table)
	for w: int in range(table + 1, table + 40):
		var threat: float = WaveDirector.threat_for(w)
		err = _T.assert_true(threat > previous,
			"endless wave %d (x%.2f) beats wave %d (x%.2f)" % [w, threat, w - 1, previous])
		if err != "":
			break
		previous = threat
	if err == "":
		err = _T.assert_true(WaveDirector.threat_for(table + 40) > 10.0,
			"and 40 waves past the table it is well over x10 (got x%.1f)"
				% WaveDirector.threat_for(table + 40))
	return err


## Threat has to count *work*, not bodies — a beetle wave and an aphid wave of
## the same size are not the same wave, and a headcount would say they were.
func test_threat_weighs_a_beetle_heavier_than_an_aphid() -> String:
	var aphid_health: float = float(Pest.SPECIES[Pest.APHID]["health"])
	var beetle_health: float = float(Pest.SPECIES[Pest.BEETLE]["health"])
	var err: String = _T.assert_true(beetle_health > aphid_health, "sanity: a beetle has more health")
	if err == "":
		# Wave 5 sends 3 beetles + 10 aphids; wave 2 sends 9 aphids. Wave 5 has
		# only 4 more pests but far more work in them.
		var w2: float = WaveDirector.threat_for(2)
		var w5: float = WaveDirector.threat_for(5)
		err = _T.assert_true(w5 > w2 * 2.0,
			"wave 5 (13 pests, 3 of them beetles, x%.2f) is worth more than twice wave 2 (9 aphids, x%.2f)"
				% [w5, w2])
	return err


## groups_for is the single answer to "what is in wave N" — the scheduler and
## the threat readout both call it, so they cannot price different waves.
func test_the_scheduler_and_the_threat_readout_read_the_same_wave() -> String:
	var director := WaveDirector.new()
	director.endless = true
	var err: String = ""
	for w: int in [1, 5, WaveDirector.WAVES.size(), WaveDirector.WAVES.size() + 7]:
		var from_table: int = 0
		for group: Dictionary in WaveDirector.groups_for(w):
			from_table += int(group["count"])
		director.current_wave = w - 1
		director.start_next_wave()
		err = _T.assert_eq(director.current_wave_pest_count(), from_table,
			"wave %d: the scheduler built %d pests and groups_for says %d"
				% [w, director.current_wave_pest_count(), from_table])
		if err != "":
			break
	director.free()
	return err


## The escalation note answers "in what way", and must stay quiet through the
## fixed table where the table itself is the escalation.
func test_the_escalation_note_is_silent_in_campaign_and_speaks_in_endless() -> String:
	var err: String = ""
	for w: int in range(1, WaveDirector.WAVES.size() + 1):
		err = _T.assert_eq(WaveDirector.escalation_note(w), "",
			"wave %d is on the fixed table, so nothing is announced" % w)
		if err != "":
			return err
	var note: String = WaveDirector.escalation_note(WaveDirector.WAVES.size() + 3)
	err = _T.assert_true(note != "", "an endless wave names what climbed (got %s)" % note)
	if err == "":
		err = _T.assert_true(note.contains("tougher") and note.contains("faster"),
			"and both pest scales are in it while they are still climbing: %s" % note)
	return err


## Once a scale saturates it must drop out of the note rather than keep being
## announced — "tougher" every wave when health has been capped for 100 waves
## is a lie the player learns to ignore.
func test_a_capped_scale_stops_being_announced() -> String:
	var far: int = WaveDirector.WAVES.size() + 500
	var err: String = _T.assert_float_eq(WaveDirector.health_scale_for(far), WaveDirector.ENDLESS_HEALTH_MAX, 0.0001,
		"sanity: health is capped this far out")
	if err == "":
		err = _T.assert_false(WaveDirector.escalation_note(far).contains("tougher"),
			"a capped scale is not announced as still climbing: %s" % WaveDirector.escalation_note(far))
	return err


## The row's widths are only safe as a sum, and this is the invariant that has
## to hold when a readout is added or widened.
func test_the_stats_row_budget_fits_the_bar() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var stats: HBoxContainer = game.hud.get_node("Root/TopBar/StatsRow") as HBoxContainer
	var needed: float = Hud.stats_row_budget(stats.get_child_count() - 1)
	var err: String = _T.assert_true(needed <= stats.size.x,
		"the readouts, separations and button need %.0fpx of the row's %.0fpx" % [needed, stats.size.x])
	_T.free_ui(game)
	return err


## The readable form. The raw multiple runs to x897 by wave 108, which is not a
## number a player can hold next to the one they saw last wave.
func test_the_threat_level_stays_a_small_readable_number() -> String:
	var table: int = WaveDirector.WAVES.size()
	var err: String = _T.assert_eq(WaveDirector.threat_level(1), 1, "wave 1 is level 1")
	if err == "":
		err = _T.assert_true(WaveDirector.threat_level(table) <= 12,
			("the whole campaign stays a number a player can hold (wave %d is level %d)."
				+ " It read exactly 10 before plant-tower-defense-iqp8 gave the back half"
				+ " a second act, and 11 after -- so the old bound of 10 was sitting"
				+ " precisely on the finale and ANY campaign escalation failed it. 11 is"
				+ " one below Hud.THREAT_TINT_MAX, so the finale tints at 0.9 of the way"
				+ " to THREAT_HOT rather than 0.8")
				% [table, WaveDirector.threat_level(table)])
	if err == "":
		err = _T.assert_true(WaveDirector.threat_level(table + 100) <= 30,
			"and 100 waves into endless it is still two digits (level %d, from a raw x%.0f)"
				% [WaveDirector.threat_level(table + 100), WaveDirector.threat_for(table + 100)])
	return err


## A floor of a monotonic function: never goes down, and does not have to move
## every wave. Both halves matter — a level that ticked every wave would just
## be the wave number wearing a different hat.
func test_the_threat_level_never_goes_down_and_does_eventually_climb() -> String:
	var err: String = ""
	var previous: int = 0
	for w: int in range(1, WaveDirector.WAVES.size() + 60):
		var level: int = WaveDirector.threat_level(w)
		err = _T.assert_true(level >= previous, "wave %d level %d is not below wave %d's %d" % [w, level, w - 1, previous])
		if err != "":
			return err
		previous = level
	return _T.assert_true(previous > WaveDirector.threat_level(1) + 5,
		"and it really did climb over 60-odd waves (1 -> %d)" % previous)


## Threat only appears once it says something. At level 1 it is noise.
func test_the_threat_readout_hides_itself_at_wave_one() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.director.current_wave = 1
	game._refresh()
	var label: Label = game.hud.get_node("Root/TopBar/StatsRow/WaveLabel") as Label
	var err: String = _T.assert_false(label.text.contains("threat"),
		"wave 1 shows no threat level (got %s)" % label.text)
	if err == "":
		game.director.current_wave = WaveDirector.WAVES.size() + 20
		game._refresh()
		err = _T.assert_true(label.text.contains("threat"),
			"a deep endless wave does show one (got %s)" % label.text)
	_T.free_ui(game)
	return err


# -- Per-run lane pressure post-mortem (plant-tower-defense-dbg) -------------


## The whole reason for a second map: the per-wave one fades by design, so by
## the end of a run the early damage is gone. The run total must not fade.
func test_the_run_total_survives_fades_that_clear_the_wave_map() -> String:
	var board := Board.new()
	await _T.instantiate_scene(board)
	var early: Vector2i = Board.PATH_CORNERS[0]
	var late: Vector2i = Board.PATH_CORNERS[1]
	board.record_lane_pressure_wave({early: 3})
	# Enough later waves elsewhere to decay the early cell out of the live map.
	for i: int in range(12):
		board.record_lane_pressure_wave({late: 1})
	var err: String = _T.assert_eq(board.lane_pressure_alpha(early), 0.0,
		"the live map has forgotten the early cell entirely")
	if err == "":
		err = _T.assert_eq(int(board.run_losses().get(early, 0)), 3,
			"but the run total still remembers all 3 losses there")
	_T.free_ui(board)
	return err


## The post-mortem's headline: which single cell cost the most all run. Not the
## most recent, and not the one the live overlay happens to be showing.
func test_the_worst_run_cell_is_the_one_that_cost_the_most_overall() -> String:
	var board := Board.new()
	await _T.instantiate_scene(board)
	var bad: Vector2i = Board.PATH_CORNERS[0]
	var recent: Vector2i = Board.PATH_CORNERS[1]
	board.record_lane_pressure_wave({bad: 9})
	board.record_lane_pressure_wave({recent: 2})
	var err: String = _T.assert_eq(board.worst_run_cell(), bad,
		"the cell that lost 9 beats the cell that lost 2 most recently")
	if err == "":
		err = _T.assert_eq(board.lane_pressure_alpha(recent), 1.0,
			"even though the live map is currently showing the recent one at full strength")
	_T.free_ui(board)
	return err


## A run where nothing was ever lost must not point at a cell — (-1,-1) is the
## caller's signal to say nothing rather than to praise column 0.
func test_a_flawless_run_names_no_worst_cell() -> String:
	var board := Board.new()
	await _T.instantiate_scene(board)
	var err: String = _T.assert_eq(board.worst_run_cell(), Vector2i(-1, -1),
		"nothing lost, nothing to point at")
	if err == "":
		err = _T.assert_eq(board.run_pressure_alpha(Board.PATH_CORNERS[0]), 0.0,
			"and no cell paints")
	_T.free_ui(board)
	return err


## show_run_pressure repaints the overlay from the run total, so the board
## itself becomes the post-mortem rather than needing a separate screen.
func test_ending_a_run_repaints_the_board_with_the_whole_runs_damage() -> String:
	var board := Board.new()
	await _T.instantiate_scene(board)
	var early: Vector2i = Board.PATH_CORNERS[0]
	var late: Vector2i = Board.PATH_CORNERS[1]
	# 30 at once beats 12 spread over 12 waves. Worth spelling out: the first
	# version of this test used 8 and failed at 0.667, which was the code being
	# right — twelve single losses really do outweigh eight in one go.
	board.record_lane_pressure_wave({early: 30})
	for i: int in range(12):
		board.record_lane_pressure_wave({late: 1})
	var err: String = _T.assert_eq(board.lane_pressure_alpha(early), 0.0, "faded out of the live map")
	if err == "":
		board.show_run_pressure()
		err = _T.assert_eq(board.lane_pressure_alpha(early), 1.0,
			"and back at full strength once the run ends, because 30 is the run's worst")
	if err == "":
		err = _T.assert_float_eq(board.lane_pressure_alpha(late), 12.0 / 30.0, 0.0001,
			"while the 12 scattered losses show at exactly their share (got %.3f)"
				% board.lane_pressure_alpha(late))
	_T.free_ui(board)
	return err


## Through Game: losing the run must leave the post-mortem painted, which means
## the run total has to be committed before _end_run swaps the overlay.
func test_losing_the_run_leaves_the_post_mortem_on_the_board() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game._on_wave_started(1)
	var cell: Vector2i = Board.PATH_CORNERS[0]
	game._note_lane_loss(game.board.cell_to_world(cell))
	game.lives = 1
	game._on_pest_escaped(null)
	var err: String = _T.assert_true(game.game_over, "the run ended")
	if err == "":
		err = _T.assert_true(game.board.run_losses().size() > 0,
			"the run total was committed before the overlay was swapped, not after")
	if err == "":
		err = _T.assert_true(game.board.worst_run_cell().x >= 0,
			"so the post-mortem has a cell to name")
	_T.free_ui(game)
	return err


## A clipped Label fails silently — it renders "Seeds  4…" and nothing errors,
## which is how a 130px seeds slot that could not hold a 3-digit total got
## shipped and was only caught by looking at a screenshot. Measure every
## readout's declared worst case against its budget in the real theme font.
func test_no_readout_clips_its_own_worst_case() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var stats: HBoxContainer = game.hud.get_node("Root/TopBar/StatsRow") as HBoxContainer
	var err: String = _T.assert_eq(Hud.WORST_CASE_TEXT.size(), 4,
		"every readout in the row has a declared worst case")
	# Reports every shortfall in one run rather than the first: with four
	# budgets to balance, one-at-a-time means one relaunch per label.
	var short: PackedStringArray = []
	for name: String in Hud.WORST_CASE_TEXT:
		var label: Label = stats.get_node_or_null(name) as Label
		if label == null:
			short.append("%s: no such readout" % name)
			continue
		var font: Font = label.get_theme_font("font")
		var size: int = label.get_theme_font_size("font_size")
		if size <= 0:
			size = label.get_theme_default_font_size()
		var needed: float = font.get_string_size(
			String(Hud.WORST_CASE_TEXT[name]), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if needed > label.custom_minimum_size.x:
			short.append("%s needs %.0fpx, has %.0f" % [name, needed, label.custom_minimum_size.x])
	if err == "":
		err = _T.assert_eq(short.size(), 0, "readouts that clip their worst case: %s" % ", ".join(short))
	_T.free_ui(game)
	return err


# -- Road-adjacency warning (plant-tower-defense-8bb) ------------------------


## Orthogonal only, and that is the definition rather than a simplification of
## one: a hungry pest reaches Pest.EAT_RADIUS = CELL * 1.15, so it can lunge one
## cell but not the 1.41 cells to a diagonal.
func test_road_adjacency_is_orthogonal_and_matches_a_hungry_pests_reach() -> String:
	var board := Board.new()
	await _T.instantiate_scene(board)
	var road: Vector2i = Board.PATH_CORNERS[0]
	var err: String = ""
	for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbour: Vector2i = road + step
		if not board.is_inside(neighbour) or board.is_path(neighbour):
			continue
		err = _T.assert_true(board.is_road_adjacent(neighbour),
			"%s is one step off the road, so a hungry pest can reach it" % neighbour)
		if err != "":
			break
	if err == "":
		# The reach the definition is derived from, asserted rather than assumed.
		err = _T.assert_true(Pest.EAT_RADIUS >= float(Board.CELL) and Pest.EAT_RADIUS < float(Board.CELL) * 1.41,
			"EAT_RADIUS %.1f reaches one cell but not a diagonal" % Pest.EAT_RADIUS)
	_T.free_ui(board)
	return err


func test_a_cell_far_from_the_road_is_not_road_adjacent() -> String:
	var board := Board.new()
	await _T.instantiate_scene(board)
	var far: Vector2i = Vector2i(-1, -1)
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var cell := Vector2i(x, y)
			if board.is_buildable(cell) and not board.is_road_adjacent(cell):
				far = cell
				break
		if far.x >= 0:
			break
	var err: String = _T.assert_true(far.x >= 0, "the board has at least one safe interior cell")
	if err == "":
		err = _T.assert_false(board.is_road_adjacent(far), "%s is out of a hungry pest's reach" % far)
	_T.free_ui(board)
	return err


## The discrimination that matters: a Corn Cobbler beside the road is the whole
## point of a Corn Cobbler. Warning about it would train the player to ignore
## the cue in the one case it is for.
func test_only_a_plant_that_cannot_fight_back_is_flagged_beside_the_road() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var risky: Vector2i = Vector2i(-1, -1)
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var cell := Vector2i(x, y)
			if game.board.is_buildable(cell) and game.board.is_road_adjacent(cell):
				risky = cell
				break
		if risky.x >= 0:
			break
	var err: String = _T.assert_true(risky.x >= 0, "found a buildable cell beside the road")
	if err == "":
		game.bank.seeds = 999
		game.selected_plant = PlantCatalog.SUNFLOWER
		game.bank.unlocked.append(PlantCatalog.SUNFLOWER)
		game._update_preview(risky, true)
		err = _T.assert_true(game._preview.at_risk,
			"a Sunflower at %s is flagged - it cannot fight back and a hungry pest can reach it" % risky)
	if err == "":
		game.selected_plant = PlantCatalog.CORN
		game._update_preview(risky, true)
		err = _T.assert_false(game._preview.at_risk,
			"a Corn Cobbler at the same cell is not flagged; being beside the road is its job")
	_T.free_ui(game)
	return err


## Away from the road, nothing is flagged whatever is selected.
func test_a_sunflower_away_from_the_road_is_not_flagged() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var safe: Vector2i = Vector2i(-1, -1)
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var cell := Vector2i(x, y)
			if game.board.is_buildable(cell) and not game.board.is_road_adjacent(cell):
				safe = cell
				break
		if safe.x >= 0:
			break
	game.bank.seeds = 999
	game.bank.unlocked.append(PlantCatalog.SUNFLOWER)
	game.selected_plant = PlantCatalog.SUNFLOWER
	game._update_preview(safe, true)
	var err: String = _T.assert_false(game._preview.at_risk,
		"a Sunflower at %s is out of reach, so no warning" % safe)
	_T.free_ui(game)
	return err


## A cell that already refuses the click does not also get warned about —
## two cues saying different things about one cell is worse than one.
func test_an_unusable_cell_is_not_also_warned_about() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var risky: Vector2i = Vector2i(-1, -1)
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var cell := Vector2i(x, y)
			if game.board.is_buildable(cell) and game.board.is_road_adjacent(cell):
				risky = cell
				break
		if risky.x >= 0:
			break
	game.bank.seeds = 0
	game.bank.unlocked.append(PlantCatalog.SUNFLOWER)
	game.selected_plant = PlantCatalog.SUNFLOWER
	game._update_preview(risky, true)
	var err: String = _T.assert_false(game._preview.placeable, "no seeds, so the cell refuses")
	if err == "":
		# at_risk may be set, but _draw gates the ring on `placeable` — assert
		# the drawn outcome, which is what the player sees.
		err = _T.assert_false(game._preview.at_risk and game._preview.placeable,
			"and no warning ring is drawn over a cell that already refuses")
	_T.free_ui(game)
	return err


## The armed Uproot button must LOOK armed, not just behave that way. The state
## machine is covered in test_placement.gd; this is the render side of it, and it
## is the half a headless behaviour test silently skips.
func test_an_armed_uproot_button_relabels_and_reddens() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(100)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, _grass(game)), "", "planted")
	var button: Button = game.hud.get_node_or_null("Root/SidePanel/SelectionBox/UprootButton") as Button
	if err == "":
		err = _T.assert_true(button != null, "the Uproot button is where the bridge presses it")
	if err == "":
		await _pump(game)
		err = _T.assert_false(button.has_theme_color_override("font_color"),
			"a resting Uproot button wears the panel's own colour")
	if err == "":
		err = _T.assert_eq(game.arm_uproot(), "confirm needed", "armed")
	if err == "":
		await _pump(game)
		err = _T.assert_true(button.text.begins_with("Really uproot?"),
			"the armed button says what the next click does, got %s" % button.text)
	if err == "":
		err = _T.assert_true(button.has_theme_color_override("font_color"),
			"and turns red while it is live")
	if err == "":
		err = _T.assert_true(button.get_theme_color("font_color").is_equal_approx(Hud.UPROOT_ARMED),
			"specifically the HUD's one warning red")
	if err == "":
		# Disarming must put the colour back, or the first uproot of a run leaves
		# every later one permanently red and the cue stops meaning anything.
		game._process(Game.UPROOT_CONFIRM_SECONDS + 0.1)
		await _pump(game)
		err = _T.assert_false(button.has_theme_color_override("font_color"),
			"and drops the red again when the window closes")
	if err == "":
		err = _T.assert_true(button.text.begins_with("Uproot ("),
			"and goes back to its resting label, got %s" % button.text)
	_T.free_ui(game)
	return err


## The panel exists to answer "uproot and replant?", which is unanswerable without
## the plant's health. Drives real damage rather than writing `health` directly, so
## the readout is proved against the path a pest actually takes.
func test_the_selection_panel_reports_a_chewed_plants_health() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(100)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, _grass(game)), "", "planted")
	var row: ColorRect = game.hud.get_node_or_null("Root/SidePanel/SelectionBox/HealthRow") as ColorRect
	var label: Label = game.hud.get_node_or_null("Root/SidePanel/SelectionBox/SelectionLabel") as Label
	if err == "":
		err = _T.assert_true(row != null and label != null, "the health row and label exist")
	if err == "":
		await _pump(game)
		err = _T.assert_false(row.visible, "an unbitten plant shows no bar at all")
	if err == "":
		err = _T.assert_false(label.text.contains("Health"),
			"and no health line, got %s" % label.text)
	if err == "":
		var text_before: String = (row.get_node_or_null("HealthText") as Label).text
		game.selected_placed.take_damage(Plant.MAX_HEALTH * 0.5)
		# The panel follows health from Game._process, not from a signal.
		game._process(0.016)
		await _pump(game)
		err = _T.assert_true(row.visible, "half-eaten, the bar appears")
		if err == "":
			err = _T.assert_true((row.get_node_or_null("HealthText") as Label).text != text_before,
				"and the panel's health readout changed")
		if err == "":
			var text: Label = row.get_node_or_null("HealthText") as Label
			err = _T.assert_true(text != null, "the bar carries its own numbers")
			if err == "":
				err = _T.assert_eq(text.text, "Health %d/%d" % [int(Plant.MAX_HEALTH * 0.5), int(Plant.MAX_HEALTH)],
					"reporting current/max on the bar")
	if err == "":
		var fill: ColorRect = row.get_node_or_null("HealthFill") as ColorRect
		err = _T.assert_true(fill != null, "the bar has a fill")
		if err == "":
			err = _T.assert_float_eq(fill.size.x, float(Hud.PANEL_WIDTH - 24) * 0.5, 1.0,
				"the fill is half the row at half health")
	_T.free_ui(game)
	return err


## The health row was bought with 20px taken off SelectionLabel. If a future blurb
## or a third line ever claws that back, the box grows past the panel foot and the
## Uproot button walks off the bottom of the screen -- which renders as a perfectly
## plausible panel until you look for the button that is no longer there.
func test_the_selection_box_stays_inside_the_side_panel_when_damaged() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(3000)
	# Unlocked, and this is the second half of the same fix as the per-plant cell below.
	# The old `continue` swallowed "not paid for" exactly as silently as it swallowed
	# "pests walk there", so the loop was measuring only whatever the starting unlocks
	# happened to cover -- fewer than the eight it looked like even before the Bramble.
	game.bank.unlocked = PlantCatalog.ids()
	var err: String = ""
	# Every plant kind, each at 1 hp -- the longest the panel ever gets, since that
	# is a wrapped name line, a state line and the health line all at once.
	#
	# THE CELL IS CHOSEN PER PLANT, and it has to be. This loop used to ask `_grass(game)`
	# for every id and `continue` on a refusal, which said "every plant kind" in its own
	# comment and silently stopped covering the Barrier Bramble the day a plant that
	# stands on the ROAD arrived (plant-tower-defense-3mhn) -- `place_plant` refuses it on
	# grass, the `continue` swallowed it, and the test went on passing while covering
	# eight of nine. A skip that reads as a pass is exactly the shape this suite exists to
	# refuse, so a refusal is now a FAILURE and the count is asserted below.
	var covered: int = 0
	for id: StringName in PlantCatalog.ids():
		if err != "":
			break
		var cell: Vector2i = game.board.world_to_cell(game.board.route()[2]) \
			if PlantCatalog.on_road(id) else _grass(game)
		var refusal: String = game.place_plant(id, cell)
		err = _T.assert_eq(refusal, "",
			("%s went into the ground at %s -- a plant this loop cannot place is a plant "
				+ "it does not check") % [String(id), cell])
		if err != "":
			break
		covered += 1
		game.selected_placed.take_damage(Plant.MAX_HEALTH - 1.0)
		game._process(0.016)
		await _pump(game)
		var box: Control = game.hud.get_node_or_null("Root/SidePanel/SelectionBox") as Control
		var panel: Control = game.hud.get_node_or_null("Root/SidePanel") as Control
		err = _T.assert_true(box != null and panel != null, "panel and box are on screen")
		if err == "":
			var box_foot: float = box.global_position.y + box.size.y
			var panel_foot: float = panel.global_position.y + panel.size.y
			# A real margin, not `<=`. The first version of this test asserted only
			# that the foot did not pass the panel, and passed a live layout sitting
			# at exactly 648 on a 648px panel -- the Uproot button flush against the
			# bottom of the screen, which is a bug that renders as a fine screenshot.
			err = _T.assert_true(box_foot <= panel_foot - SELECTION_FOOT_MARGIN,
				"%s: selection box foot %.0f keeps %dpx clear of the panel foot %.0f"
					% [String(id), box_foot, int(SELECTION_FOOT_MARGIN), panel_foot])
	# The denominator, and the whole reason the loop above stopped using `continue`.
	# Without this the test can cover eight of nine and report a clean pass, which is
	# precisely what it did between the Bramble landing and this line being written.
	if err == "":
		err = _T.assert_eq(covered, PlantCatalog.ids().size(),
			"every plant in the catalogue was actually placed and measured, not skipped")
	_T.free_ui(game)
	return err


# --- The project_identity devtools verb ---
#
# These are the FIRST tests of any devtools verb in this repo -- every check before
# this line is of game code, and the extension in res://devtools_ext/ had none at
# all. The extension is instantiated directly rather than driven over the bus: the
# bus needs a running game, and the thing being asserted (which checkout is this?)
# is exactly what you cannot trust a running game to tell you when the wrong one
# might be answering. That makes it a pure-logic check, so it belongs here.


const DEVTOOLS_EXT := "res://devtools_ext/commands.gd"


func _identity() -> Dictionary:
	var ext = preload(DEVTOOLS_EXT).new()
	return ext._cmd_project_identity({})


## A sha is 40 hex chars; a short one is the same alphabet, fewer of them.
func _looks_like_sha(text: String) -> bool:
	return text.length() >= 7 and text.length() <= 40 and text.is_valid_hex_number(false)


func test_project_identity_returns_the_three_key_envelope() -> String:
	var reply: Dictionary = _identity()
	var err: String = _T.assert_true(reply.has("success") and reply.has("message") and reply.has("data"),
		"the reply carries success, message and data -- got keys %s" % [reply.keys()])
	if err == "":
		err = _T.assert_eq(reply.size(), 3, "and carries nothing else, the way every other handler here does")
	if err == "":
		err = _T.assert_true(reply["success"] is bool, "success is a bool")
	if err == "":
		err = _T.assert_true(reply["message"] is String, "message is a String")
	if err == "":
		err = _T.assert_true(reply["data"] is Dictionary, "data is a Dictionary")
	if err == "":
		err = _T.assert_true(bool(reply["success"]), "and it succeeds in a real checkout: %s" % reply["message"])
	return err


## project_root is the whole point of the verb: it is the one field that separates
## this checkout from a sibling worktree answering on the same user:// bus. A root
## that does not contain project.godot is a root pointing somewhere that is not a
## Godot project, which would make every other field a confident lie.
func test_project_identity_root_points_at_a_real_godot_project() -> String:
	var data: Dictionary = _identity()["data"]
	var root: String = str(data.get("project_root", ""))
	var err: String = _T.assert_false(root.is_empty(), "project_root is not empty")
	if err == "":
		err = _T.assert_true(root.is_absolute_path(), "project_root is absolute, not res://-relative: %s" % root)
	if err == "":
		err = _T.assert_true(FileAccess.file_exists(root.path_join("project.godot")),
			"project_root %s holds a project.godot" % root)
	if err == "":
		err = _T.assert_true(str(data.get("project_name", "")) != "", "project_name is reported")
	if err == "":
		err = _T.assert_true(data.get("pid", 0) is int and int(data["pid"]) > 0,
			"pid is a positive int -- %s" % [data.get("pid")])
	if err == "":
		err = _T.assert_true(str(data.get("engine_version", "")) != "", "engine_version reduces to a string")
	return err


## Either a sha was read off disk or it was not -- "" is the one answer that is not
## allowed, because an empty string reads as a value rather than as an absence.
func test_project_identity_reports_a_sha_or_says_it_is_unavailable() -> String:
	var data: Dictionary = _identity()["data"]
	var sha: String = str(data.get("git_sha", ""))
	var branch: String = str(data.get("git_branch", ""))
	var err: String = _T.assert_true(sha == "unavailable" or _looks_like_sha(sha),
		"git_sha is 40 hex chars, a short sha, or exactly 'unavailable' -- got '%s'" % sha)
	if err == "":
		err = _T.assert_true(branch != "", "git_branch is never blank -- '%s'" % branch)
	if err == "":
		err = _T.assert_true(data.get("is_worktree", null) is bool, "is_worktree is a bool")
	if err == "":
		# The bus is JSON; a Dictionary or Object in here would not survive the trip.
		for key: String in data:
			var value: Variant = data[key]
			err = _T.assert_true(value is String or value is int or value is float or value is bool,
				"data.%s is a JSON-safe scalar, got %s" % [key, type_string(typeof(value))])
			if err != "":
				break
	return err


## The verb is only discoverable by `list-commands --offline` if it is registered
## with a literal double-quoted name -- that client parses the script statically and
## cannot evaluate a constant or a variable. Nothing at runtime would notice the
## difference, so the check has to be on the source text.
func test_project_identity_is_registered_with_a_literal_name() -> String:
	var source: String = FileAccess.get_file_as_string(DEVTOOLS_EXT)
	var err: String = _T.assert_false(source.is_empty(), "the extension source reads back")
	if err == "":
		err = _T.assert_true(source.contains('register_command("project_identity"'),
			"registered with a literal string so --offline discovery can see it")
	return err


## The threat ramp, asserted as data. threat_color is static and pure precisely so
## the whole curve can be checked without a HUD -- a tint judged off a screenshot
## is judged by eye, and "is wave 9 redder than wave 6" is not an eye question.
##
## Driven through `threat_color_on(level, false)` rather than `threat_color(level)`
## since the colourblind option landed: `threat_color` reads
## `RunConfig.colorblind_safe`, which is process-global, so this test would
## otherwise pass or fail on whatever an earlier test in the run happened to leave
## set. The claims below -- cream, then red, then redder -- are claims about the
## DEFAULT ramp specifically, so naming it is also more honest than it was.
func test_the_threat_tint_climbs_from_cream_to_red() -> String:
	var err: String = _T.assert_true(Hud.threat_color_on(1, false).is_equal_approx(Hud.PAPER),
		"below the show-from level the readout is the bar's own cream")
	if err == "":
		err = _T.assert_true(
			Hud.threat_color_on(Hud.THREAT_SHOW_FROM, false).is_equal_approx(Hud.PAPER),
			"and still cream at the level the number first appears")
	if err == "":
		err = _T.assert_true(
			Hud.threat_color_on(Hud.THREAT_TINT_MAX, false).is_equal_approx(Hud.THREAT_HOT),
			"fully red at the ceiling")
	if err == "":
		# Endless runs past the ceiling for hundreds of waves; the tint must pin
		# rather than wrap, overshoot or start cooling off again.
		err = _T.assert_true(
			Hud.threat_color_on(Hud.THREAT_TINT_MAX * 4, false).is_equal_approx(Hud.THREAT_HOT),
			"and stays red far past it")
	if err == "":
		# Monotonic in the direction that matters: never gets less red as it climbs.
		var previous: float = -1.0
		for level: int in range(1, Hud.THREAT_TINT_MAX + 2):
			var tint: Color = Hud.threat_color_on(level, false)
			var heat: float = tint.r - tint.g
			err = _T.assert_gte(heat, previous,
				"threat %d is at least as hot as the level below it" % level)
			if err != "":
				break
			previous = heat
	return err


func test_the_wave_readout_actually_wears_the_threat_tint() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var label: Label = game.hud.get_node_or_null("Root/TopBar/StatsRow/WaveLabel") as Label
	var err: String = _T.assert_true(label != null, "the wave readout is where the bar puts it")
	if err == "":
		game.director.current_wave = 1
		game._refresh()
		await _pump(game)
		err = _T.assert_true(label.get_theme_color("font_color").is_equal_approx(Hud.PAPER),
			"wave 1 reads as calm")
	if err == "":
		# Deep enough into endless that threat_level is past the ceiling.
		game.director.endless = true
		game.director.current_wave = 200
		game._refresh()
		await _pump(game)
		var hot: Color = label.get_theme_color("font_color")
		err = _T.assert_true(hot.r - hot.g > 0.3,
			"a wave 200 readout is visibly red, got %s" % hot)
	if err == "":
		# And it must come back down -- the override is reapplied every refresh, so
		# a run that restarts into wave 1 cannot keep yesterday's red.
		game.director.endless = false
		game.director.current_wave = 1
		game._refresh()
		await _pump(game)
		err = _T.assert_true(label.get_theme_color("font_color").is_equal_approx(Hud.PAPER),
			"and drops back to cream when the threat does")
	_T.free_ui(game)
	return err


## The post-mortem's numbers, without building the Control. Every one of these was
## already computed before this panel existed and had nowhere to go -- three of
## them lived in a HUD message that erased itself after 30 seconds.
func test_the_run_summary_reports_the_numbers_the_run_produced() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.director.current_wave = 5
	game.bank.add_seeds(140)
	game.lives = Game.LIVES - 3
	var stats: Dictionary = game.summary_stats(false)
	var err: String = _T.assert_eq(int(stats["wave"]), 5, "waves survived")
	if err == "":
		err = _T.assert_eq(int(stats["lives_lost"]), 3, "beds lost is derived, not stored")
	if err == "":
		err = _T.assert_gte(int(stats["seeds_earned_total"]), 140, "seeds earned carried through")
	if err == "":
		err = _T.assert_eq(int(stats["threat_level"]),
			WaveDirector.threat_level(5), "threat level agrees with the director")
	if err == "":
		err = _T.assert_true(stats.has("worst_cell") and stats.has("worst_cell_losses"),
			"the weakest-ground reading is present")
	_T.free_ui(game)
	return err


func test_the_run_summary_panel_persists_and_names_every_row() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	# The real losing path, not a hand-set flag: this is what a player reaches.
	game.lives = 1
	game._on_pest_escaped(null)
	await _pump(game)
	var err: String = _T.assert_true(game.game_over, "the run is over")
	var panel: RunSummary = game.get_node_or_null("SummaryLayer/RunSummary") as RunSummary
	if err == "":
		err = _T.assert_true(panel != null, "the post-mortem card exists")
	if err == "":
		err = _T.assert_true(panel.visible, "and is on screen")
	if err == "":
		# It must not expire. The thing it replaces did, which is the whole issue.
		game._process(60.0)
		await _pump(game)
		err = _T.assert_true(is_instance_valid(panel) and panel.visible,
			"and is still there a minute later")
	if err == "":
		for row: Array in panel.summary_rows():
			var name: String = "Value_%s" % String(row[0]).replace(" ", "")
			var label: Label = panel.get_node_or_null(name) as Label
			err = _T.assert_true(label != null and not label.text.is_empty(),
				"row %s carries a value" % String(row[0]))
			if err != "":
				break
	if err == "":
		err = _T.assert_true(panel.get_node_or_null("ReplayButton") != null
			and panel.get_node_or_null("GateButton") != null,
			"both ways out of the run are on the card")
	_T.free_ui(game)
	return err


## _end_run was reachable more than once -- the losing branch calls it and then
## clears the pest group, and a win can land in the same frame as a clear. The
## score filing was already guarded; building the UI was not.
func test_ending_a_run_twice_leaves_exactly_one_summary() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.lives = 1
	game._on_pest_escaped(null)
	await _pump(game)
	game._end_run("again")
	game._end_run("and again")
	await _pump(game)
	var layer: Node = game.get_node_or_null("SummaryLayer")
	var err: String = _T.assert_true(layer != null, "the summary layer is there")
	if err == "":
		var found: int = 0
		for child: Node in layer.get_children():
			if child is RunSummary:
				found += 1
		err = _T.assert_eq(found, 1, "exactly one card, however many times the run ended")
	_T.free_ui(game)
	return err


## The message row used to be two assignments, so every line destroyed the one
## before it. These pin the three behaviours that replaced that.
func test_an_important_message_is_not_wiped_by_an_ambient_one() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var hud: Hud = game.hud
	var label: Label = hud.get_node_or_null("Root/TopBar/MessageLabel") as Label
	var err: String = _T.assert_true(label != null, "the message row exists")
	if err == "":
		# Game._ready posts an 8-second starter tip. Drain it, or every assertion
		# below is really about that line rather than the ones under test.
		hud._process(9.0)
		hud.show_message("Click Uproot again", 4.0, Hud.MESSAGE_IMPORTANT)
		# Exactly the case that motivated this: a pest dies mid-instruction.
		hud.show_message("A husk rotted away", 2.0, Hud.MESSAGE_NORMAL)
		err = _T.assert_eq(label.text, "Click Uproot again",
			"the instruction survives an ambient line arriving on top of it")
	if err == "":
		err = _T.assert_eq(hud.pending_messages(), 1, "and the ambient line waits its turn")
	if err == "":
		# Once the instruction expires the queued line takes over rather than
		# being lost -- a dropped message and a deferred one look identical on
		# screen at the moment of the collision, which is why this is asserted.
		hud._process(4.1)
		err = _T.assert_eq(label.text, "A husk rotted away", "then it gets its turn")
	if err == "":
		err = _T.assert_eq(hud.pending_messages(), 0, "and the queue drains")
	_T.free_ui(game)
	return err


func test_an_important_message_can_cut_an_ambient_one_short() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var hud: Hud = game.hud
	var label: Label = hud.get_node_or_null("Root/TopBar/MessageLabel") as Label
	hud._process(9.0)
	hud.show_message("Wave 3 cleared", 6.0, Hud.MESSAGE_NORMAL)
	hud.show_message("Click Uproot again", 4.0, Hud.MESSAGE_IMPORTANT)
	var err: String = _T.assert_eq(label.text, "Click Uproot again",
		"the urgent line pre-empts the ambient one")
	if err == "":
		err = _T.assert_eq(hud.pending_messages(), 1,
			"and the ambient line is deferred, not discarded")
	_T.free_ui(game)
	return err


## The two tests above are examples from one pair of rungs. This is the table:
## every ordered pair, asserted from the constants rather than from three
## remembered cases, so a fourth rung cannot be added without either passing here
## or being noticed.
##
## Cycle 69 added MESSAGE_DEADLINE and the pair that mattered — DEADLINE arriving
## on IMPORTANT — was a combination no existing test named, which is exactly the
## hole an enumeration closes and an example does not.
func test_a_higher_rung_pre_empts_and_every_other_pair_waits() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var hud: Hud = game.hud
	var label: Label = hud.get_node_or_null("Root/TopBar/MessageLabel") as Label
	var rungs: Array[int] = [Hud.MESSAGE_NORMAL, Hud.MESSAGE_IMPORTANT, Hud.MESSAGE_DEADLINE]
	# Game._ready posts a starter tip; drain it once or the first pair is about it.
	hud._process(9.0)
	var err: String = _T.assert_eq(rungs.size(), 3,
		"three rungs -- add the new one to this list or the table is a subset")
	for sitting: int in rungs:
		for arriving: int in rungs:
			if err != "":
				break
			hud._message_left = 0.0
			hud._message_queue.clear()
			hud._advance_message_queue()
			# Six seconds each, well over MESSAGE_MIN_READABLE, so the wait branch
			# is reached on its own terms rather than through the too-short-to-have-
			# been-read shortcut.
			hud.show_message("sitting %d" % sitting, 6.0, sitting)
			hud.show_message("arriving %d" % arriving, 6.0, arriving)
			var winner: String = ("arriving %d" % arriving) if arriving > sitting \
				else ("sitting %d" % sitting)
			err = _T.assert_eq(label.text, winner,
				"rung %d arriving onto rung %d" % [arriving, sitting])
			if err == "":
				# The other half, and the one a screenshot cannot tell from the
				# first: the loser is deferred, never dropped, at every pair.
				err = _T.assert_eq(hud.pending_messages(), 1,
					"the loser waits (%d onto %d)" % [arriving, sitting])
	_T.free_ui(game)
	return err


## `show_message` reports whether the text is on the row NOW, and this is the assertion a
## one-shot hint rests on.
##
## Before cycle 90 it returned void, so a caller could not tell "posted" from "queued
## behind something" from "dropped because the queue was full and this was the lowest
## rung". A hint is spent on the player having SEEN a thing, so all three had to become
## distinguishable — otherwise `spend_hint(id, true)` after calling this is a claim the
## code cannot support, which is exactly the shape of the bug cycle 79 paid for.
##
## Driven across the same three rungs as the table above, because the queued case is only
## reachable when something is already sitting on the row.
func test_show_message_says_whether_the_line_reached_the_row() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var hud: Hud = game.hud
	hud._process(9.0)
	hud._message_left = 0.0
	hud._message_queue.clear()
	hud._advance_message_queue()

	var err: String = _T.assert_true(hud.show_message("first", 6.0, Hud.MESSAGE_NORMAL),
		"onto an empty row, the line posts and says so")
	if err == "":
		# Same rung, and the sitting line is far from expiring, so this one waits.
		err = _T.assert_false(hud.show_message("second", 6.0, Hud.MESSAGE_NORMAL),
			"queued behind a line still being read is NOT shown, and reports false")
	if err == "":
		err = _T.assert_eq(hud.pending_messages(), 1, "and it is genuinely waiting, not lost")
	if err == "":
		# A higher rung pre-empts, so it IS on the row.
		err = _T.assert_true(hud.show_message("urgent", 6.0, Hud.MESSAGE_DEADLINE),
			"a line that pre-empts what was sitting there posts, and reports true")
	_T.free_ui(game)
	return err


func test_the_message_queue_cannot_grow_without_bound() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var hud: Hud = game.hud
	hud._process(9.0)
	hud.show_message("live", 9.0, Hud.MESSAGE_NORMAL)
	for i: int in range(12):
		hud.show_message("spam %d" % i, 2.0, Hud.MESSAGE_NORMAL)
	var err: String = _T.assert_true(hud.pending_messages() <= Hud.MESSAGE_QUEUE_MAX,
		"a flood cannot back up minutes of stale narration, got %d" % hud.pending_messages())
	if err == "":
		# An important line must still get through when the queue is full of
		# ambient ones. It pre-empts the live line outright, so assert at that
		# moment -- pumping first would run past its own 3-second life and read
		# whatever the queue served next, which is what the first draft did.
		hud.show_message("urgent", 3.0, Hud.MESSAGE_IMPORTANT)
		var label: Label = hud.get_node_or_null("Root/TopBar/MessageLabel") as Label
		err = _T.assert_eq(label.text, "urgent",
			"an important line gets through a full queue of ambient ones")
	if err == "":
		# And when it does expire, the queue is still bounded rather than having
		# grown a backlog behind it.
		hud._process(3.1)
		err = _T.assert_true(hud.pending_messages() < Hud.MESSAGE_QUEUE_MAX,
			"the queue drains rather than accumulating, got %d" % hud.pending_messages())
	_T.free_ui(game)
	return err


## The prep strip: 18 seconds used to tick away in silence.
func test_the_prep_strip_drains_and_hides_itself_once_a_wave_is_live() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var bar: ColorRect = game.hud.get_node_or_null("Root/TopBar/PrepBar") as ColorRect
	var err: String = _T.assert_true(bar != null, "the prep strip exists")
	if err == "":
		game._prep_left = Game.PREP_SECONDS
		game._wave_live = false
		game._refresh()
		await _pump(game)
		err = _T.assert_true(bar.visible, "it shows while the garden is between waves")
	var full: float = bar.size.x
	if err == "":
		err = _T.assert_gt(full, 0.0, "and starts with width")
	if err == "":
		game._prep_left = Game.PREP_SECONDS * 0.25
		game._refresh()
		await _pump(game)
		err = _T.assert_true(bar.size.x < full * 0.5,
			"it drains as the prep time runs down: %.0f then %.0f" % [full, bar.size.x])
	if err == "":
		# No _pump here on purpose: a wave flagged live with no pests on the board
		# is a state the game undoes on its very next frame -- _check_wave_cleared
		# sees nothing spawning and nothing alive and clears it straight back.
		# Pumping would assert against the game's correction, not against this code.
		game._wave_live = true
		game._refresh()
		err = _T.assert_false(bar.visible,
			"and is hidden while a wave is live, so a full strip always means time left")
	_T.free_ui(game)
	return err


## The final seconds got no nudge at all (plant-tower-defense-7mi): the strip
## shrank at the same calm rate for all 18 seconds. A player who has stopped
## watching it most needs the last two to say so.
func test_the_prep_strip_pulses_in_its_final_seconds() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var bar: ColorRect = game.hud.get_node_or_null("Root/TopBar/PrepBar") as ColorRect
	game._prep_left = Game.PREP_SECONDS
	game._wave_live = false
	game._refresh()
	await _pump(game)
	var err: String = _T.assert_true(bar.modulate.is_equal_approx(Color.WHITE),
		"plenty of time left, so the strip is not pulsing yet")
	if err == "":
		err = _T.assert_false(game.hud._prep_bar_urgent, "and the urgency flag agrees")
	if err == "":
		# Past PREP_BAR_URGENT_SECONDS, not merely close to it -- the crossing is
		# what starts the pulse, per _set_prep_bar_urgent's edge-detect guard.
		game._prep_left = Hud.PREP_BAR_URGENT_SECONDS * 0.5
		game._refresh()
		err = _T.assert_true(game.hud._prep_bar_urgent, "urgency flips on inside the last stretch")
	if err == "":
		# Headless: GardenTheme.animations_enabled() is false, so no Tween ever
		# runs and the strip must not be left stuck mid-fade -- the same
		# contract every other gated tween in this file keeps.
		err = _T.assert_true(bar.modulate.is_equal_approx(Color.WHITE),
			"headless never pumps the pulse, so the strip is still fully opaque")
	if err == "":
		# Leaving the zone (a wave starting mid-pulse) must reset it rather than
		# leave a dimmed strip behind for whatever shows next.
		game._prep_left = Game.PREP_SECONDS
		game._refresh()
		err = _T.assert_false(game.hud._prep_bar_urgent, "stepping back out clears the flag")
		if err == "":
			err = _T.assert_true(bar.modulate.is_equal_approx(Color.WHITE),
				"and leaves the strip at full opacity, not wherever the pulse left it")
	_T.free_ui(game)
	return err


func test_the_prep_strip_wears_the_next_waves_threat_not_the_last_ones() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var bar: ColorRect = game.hud.get_node_or_null("Root/TopBar/PrepBar") as ColorRect
	game.director.endless = true
	game.director.current_wave = 40
	game._wave_live = false
	game._prep_left = Game.PREP_SECONDS
	game._refresh()
	await _pump(game)
	var expected: Color = Hud.threat_color(WaveDirector.threat_level(41))
	var err: String = _T.assert_true(bar.color.is_equal_approx(expected),
		"the strip previews wave 41's threat, not wave 40's")
	if err == "":
		err = _T.assert_false(
			bar.color.is_equal_approx(Hud.threat_color(WaveDirector.threat_level(1))),
			"and is not simply the calm default")
	_T.free_ui(game)
	return err


## A packet button that is lit but refuses every click is the same defect as a
## wrong number: it tells the player something untrue about what they can do.
func test_a_packet_button_goes_dark_when_its_tier_has_nothing_left() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var common: Button = game.hud.get_node_or_null("Root/SidePanel/PacketButton") as Button
	var rare: Button = game.hud.get_node_or_null("Root/SidePanel/RarePacketButton") as Button
	var err: String = _T.assert_true(common != null and rare != null, "both packet buttons exist")
	if err == "":
		game.bank.set_seed(11)
		game.bank.add_seeds(600)
		game._refresh()
		await _pump(game)
		err = _T.assert_false(common.disabled, "with seeds and stock, the common packet is buyable")
	if err == "":
		# Drain tier 1 through the real purchase path.
		var guard: int = 0
		while not game.bank.packet_pool(&"common").is_empty() and guard < 40:
			game.bank.buy_packet(&"common")
			guard += 1
		err = _T.assert_true(game.bank.packet_pool(&"common").is_empty(), "tier 1 is spent")
	if err == "":
		err = _T.assert_gt(game.bank.seeds, int(SeedBank.PACKET_TIERS[&"common"]["cost"]),
			"and it is affordability that is NOT the reason it should go dark")
	if err == "":
		game._refresh()
		await _pump(game)
		err = _T.assert_true(common.disabled, "the common packet goes dark once its tier is spent")
	if err == "":
		err = _T.assert_false(rare.disabled,
			"while the rare packet, which can still reach tier 2, stays lit")
	if err == "":
		err = _T.assert_true(common.tooltip_text.contains("Nothing left"),
			"and the tooltip says which of the two reasons applies, got %s" % common.tooltip_text)
	_T.free_ui(game)
	return err


## The denial cue lands where the click happened -- or, for a placement
## refused on a board click (see Game._click_at), on the bar slot the player
## picked the plant from, since that click never touched a Control at all.
func test_a_refused_placement_shakes_the_plant_bar_slot() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var locked: Array[StringName] = game.bank.locked_plants()
	var err: String = _T.assert_gt(locked.size(), 0, "something is still in a packet to refuse")
	var id: StringName = locked[0] if err == "" else &""
	if err == "":
		err = _T.assert_false(GardenTheme.animations_enabled(),
			"this test is only meaningful headless, where the shake tween never lands")
	var button: Button = null
	if err == "":
		button = game.hud.get_node_or_null("Root/SidePanel/PlantBar/Button_%s" % id) as Button
		err = _T.assert_true(button != null, "the bar has a slot for the locked plant")
	if err == "":
		game.selected_plant = id
		game._click_at(game.board.cell_to_world(_grass(game)) + game._entities.position)
		err = _T.assert_eq(game.state()["plants"], 0, "the refusal really did refuse")
	if err == "":
		# The real call site, direct: Game._click_at reaches exactly this, on
		# exactly this slot, for exactly this refusal.
		game.hud.shake_plant_button(id)
		# Headless never pumps the shake tween, so the button's rotation is right
		# where it started -- the observable half of "ran, and did not error".
		err = _T.assert_float_eq(button.rotation, 0.0, 0.001,
			"shake_plant_button ran and left the button at its already-correct rest angle")
	_T.free_ui(game)
	return err


## Same cue, the other call site: a packet click that Game._on_packet_requested
## refuses shakes the button actually pressed, not a bar slot standing in for it.
func test_a_refused_packet_purchase_shakes_the_packet_button() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	# `seeds` the purse, not set_seed() -- that fixes the packet-roll RNG, a
	# different knob entirely, and leaves STARTING_SEEDS = 25 more than enough
	# to afford PACKET_COST = 20.
	game.bank.seeds = 0
	var button: Button = game.hud.get_node_or_null("Root/SidePanel/PacketButton") as Button
	var err: String = _T.assert_true(button != null, "the common packet button exists")
	if err == "":
		err = _T.assert_false(GardenTheme.animations_enabled(),
			"this test is only meaningful headless, where the shake tween never lands")
	if err == "":
		game._on_packet_requested(&"common")
		err = _T.assert_eq(game.bank.seeds, 0, "no seeds spent -- the purchase really was refused")
	if err == "":
		# The real call site, direct: Game._on_packet_requested reaches exactly
		# this, on exactly this button, for exactly this refusal.
		game.hud.shake_packet_button(&"common")
		# Headless never pumps the shake tween, so the button's rotation is right
		# where it started -- the observable half of "ran, and did not error".
		err = _T.assert_float_eq(button.rotation, 0.0, 0.001,
			"shake_packet_button ran and left the button at its already-correct rest angle")
	_T.free_ui(game)
	return err


## Same cue, a third call site: an underfunded upgrade shakes the Upgrade
## button itself -- unlike a plant/packet refusal, upgrade_selected() never
## routes through bank.pay_for_plant() (it checks bank.seeds directly), so it
## never reaches purchase_failed's shared Sfx.PURCHASE_DENIED and has to play
## the cue itself too. See Game.upgrade_selected.
func test_an_underfunded_upgrade_shakes_the_upgrade_button() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_false(GardenTheme.animations_enabled(),
		"this test is only meaningful headless, where the shake tween never lands")
	var cell: Vector2i = _grass(game)
	if err == "":
		err = game.place_plant(PlantCatalog.CORN, cell)
	var corn: CornCobbler = null
	if err == "":
		corn = game.plant_at(cell) as CornCobbler
		err = _T.assert_true(corn != null, "a Corn Cobbler landed on its cell")
	if err == "":
		game._select(corn)
		game.bank.seeds = 0
		var refusal: String = game.upgrade_selected()
		err = _T.assert_eq(refusal, "not enough seeds", "the upgrade really was refused")
	var button: Button = null
	if err == "":
		button = game.hud.get_node_or_null("Root/SidePanel/SelectionBox/UpgradeButton") as Button
		err = _T.assert_true(button != null, "the Upgrade button exists")
	if err == "":
		# The real call site, direct: Game.upgrade_selected reaches exactly
		# this, on exactly this button, for exactly this refusal.
		game.hud.shake_upgrade_button()
		# Headless never pumps the shake tween, so the button's rotation is right
		# where it started -- the observable half of "ran, and did not error".
		err = _T.assert_float_eq(button.rotation, 0.0, 0.001,
			"shake did not error and left the button at its already-correct rest angle")
	_T.free_ui(game)
	return err


## Every HUD animation must layer on an already-correct final state. Headless
## pumps no frames, so a tween that starts a node at alpha 0 and relies on a frame
## to finish leaves it invisible -- and invisible in a way that no assertion about
## size or node paths would ever catch. This is that assertion.
func test_hud_motion_never_leaves_the_panel_invisible_headlessly() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(100)
	var box: Control = game.hud.get_node_or_null("Root/SidePanel/SelectionBox") as Control
	var err: String = _T.assert_true(box != null, "the selection box exists")
	if err == "":
		err = _T.assert_false(GardenTheme.animations_enabled(),
			"this test is only meaningful headless, where animations are off")
	if err == "":
		err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, _grass(game)), "", "planted, which selects")
	if err == "":
		await _pump(game)
		err = _T.assert_true(box.visible, "the panel is visible")
	if err == "":
		err = _T.assert_float_eq(box.modulate.a, 1.0, 0.001,
			"and fully opaque -- not left mid-entrance at alpha %.2f" % box.modulate.a)
	if err == "":
		err = _T.assert_float_eq(box.scale.x, 1.0, 0.001, "and unscaled")
	_T.free_ui(game)
	return err


func test_the_threat_tint_still_lands_exactly_when_animation_is_off() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var label: Label = game.hud.get_node_or_null("Root/TopBar/StatsRow/WaveLabel") as Label
	# THREAT_HOT is the DEFAULT ramp's hot end, so the option has to be pinned: it
	# is loaded from the real user:// save at startup, and a maintainer who has the
	# accessibility ramp turned on would fail this against THREAT_HOT_SAFE with
	# nothing wrong in the code.
	var stashed_colorblind: bool = RunConfig.colorblind_safe
	RunConfig.colorblind_safe = false
	game.director.endless = true
	game.director.current_wave = 200
	game._refresh()
	await _pump(game)
	# Headless takes the direct-assignment branch, so the colour must be the exact
	# target rather than wherever a never-pumped tween would have stalled.
	var err: String = _T.assert_true(label.get_theme_color("font_color").is_equal_approx(Hud.THREAT_HOT),
		"the tint is the final colour, not a tween's start value")
	if err == "":
		game.director.current_wave = 1
		game.director.endless = false
		game._refresh()
		await _pump(game)
		err = _T.assert_true(label.get_theme_color("font_color").is_equal_approx(Hud.PAPER),
			"and comes back down exactly")
	RunConfig.colorblind_safe = stashed_colorblind
	_T.free_ui(game)
	return err


# -- The wave banner (plant-tower-defense-1ci, plant-tower-defense-d2a) ------
#
# The HUD's Banner had no callers at all once RunSummary replaced the
# end-of-run banner: `show_banner`/`hide_banner` were dead, and the node was
# built on every launch only ever to stay hidden. It was given the one job it is shaped
# for -- announcing a wave -- instead of being deleted, and these are the
# checks that keep it from drifting back to either failure mode: a surface
# nobody calls, or a second dumping ground for status lines. d2a gave it a
# second job of the same shape -- announcing that a wave was survived -- and
# the checks below cover both by name.


## Both halves are built from runtime numbers into fixed-width boxes, and a
## Label that overruns its box fails silently -- it just renders "Wave 12 …".
## Same check, and the same reason, as test_no_readout_clips_its_own_worst_case.
func test_the_wave_banner_fits_its_own_worst_case() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	await _pump(game)
	var err: String = _T.assert_eq(Hud.BANNER_WORST_CASE_TEXT.size(), 2,
		"both banner rows have a declared worst case")
	var short: PackedStringArray = []
	for name: String in Hud.BANNER_WORST_CASE_TEXT:
		var label: Label = game.hud.get_node_or_null("Root/%s" % name) as Label
		if label == null:
			short.append("%s: no such node" % name)
			continue
		var font: Font = label.get_theme_font("font")
		var size: int = label.get_theme_font_size("font_size")
		if size <= 0:
			size = label.get_theme_default_font_size()
		var needed: float = font.get_string_size(
			String(Hud.BANNER_WORST_CASE_TEXT[name]), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if needed > label.size.x:
			short.append("%s needs %.0fpx, has %.0f" % [name, needed, label.size.x])
	if err == "":
		err = _T.assert_eq(short.size(), 0, "banner rows that clip their worst case: %s" % ", ".join(short))
	if err == "":
		# The declared worst case has to be reachable text, not a comfortable
		# fiction. Every escalation note WaveDirector emits is a subset of these
		# three words, so the longest one it can build is the one budgeted for.
		err = _T.assert_eq(String(Hud.BANNER_WORST_CASE_TEXT["BannerNote"]),
			Hud.wave_note(9999, "tougher, faster and stranger"),
			"the budgeted note is a string wave_note can actually build, not a comfortable fiction")
	if err == "":
		# Banner is shared with announce_wave_cleared now, and
		# "Wave 9999 cleared" is the longer of the two events' headlines --
		# see BANNER_WORST_CASE_TEXT's own comment for why that is the mark.
		err = _T.assert_eq(String(Hud.BANNER_WORST_CASE_TEXT["Banner"]), Hud.wave_cleared_headline(9999),
			"and so is the budgeted headline, against the longer of the two events it now carries")
	if err == "":
		err = _T.assert_gt(Hud.wave_cleared_headline(9999).length(), Hud.wave_headline(9999).length(),
			"and it really is the longer of the two, not a tie this budget got lucky on")
	_T.free_ui(game)
	return err


## The two halves are siblings for a reason -- a sized wrapper Control would
## share pixels with its own children -- and the banner sits over the board, so
## it must not land on any other live HUD element either.
func test_the_wave_banner_shares_no_pixels_with_the_rest_of_the_hud() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.hud.announce_wave(12, 24, "tougher and faster")
	await _pump(game)

	# From Root, not the CanvasLayer: Root is itself a full-rect Control, and a
	# surface sharing pixels with the container it lives in is the normal case.
	var rects: Dictionary = _hud_rects(game.hud.get_node("Root"))
	var err: String = _T.assert_true(rects.has("Banner") and rects.has("BannerNote"),
		"an announced banner is on screen with both rows sized, got %s" % [rects.keys()])
	if err == "":
		# Abutting, not overlapping: the note's top edge is the headline's bottom.
		err = _T.assert_false((rects["Banner"] as Rect2).intersects(rects["BannerNote"] as Rect2),
			"the headline %s and the note %s abut rather than overlap"
				% [rects["Banner"], rects["BannerNote"]])
	for row: String in ["Banner", "BannerNote"]:
		if err != "":
			break
		for other: String in rects:
			if other == "Banner" or other == "BannerNote":
				continue
			if (rects[row] as Rect2).intersects(rects[other] as Rect2):
				err = _T.assert_false(true, "%s %s overlaps %s %s"
					% [row, rects[row], other, rects[other]])
				break
	if err == "":
		# And it stays clear of the side panel, which owns the right edge.
		err = _T.assert_true(
			(rects["Banner"] as Rect2).end.x <= float(game.hud.get_viewport_width() - Hud.PANEL_WIDTH),
			"the banner stops where the side panel starts")
	_T.free_ui(game)
	return err


## When it appears, what it says, and -- the half the old surface never had --
## that it takes itself down. `hide_banner()` previously had no callers either,
## so a banner raised at wave start would have stayed up for the whole wave.
func test_the_wave_banner_appears_on_announcement_and_clears_itself() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var banner: Label = game.hud.get_node_or_null("Root/Banner") as Label
	var note: Label = game.hud.get_node_or_null("Root/BannerNote") as Label
	var err: String = _T.assert_true(banner != null and note != null, "both banner rows exist")
	if err == "":
		err = _T.assert_false(banner.visible, "and nothing is announced at launch")
	if err == "":
		game.hud.announce_wave(7, 19, "faster")
		err = _T.assert_true(banner.visible and note.visible, "announcing a wave raises both rows")
	if err == "":
		err = _T.assert_eq(banner.text, "Wave 7", "the headline names the wave")
	if err == "":
		err = _T.assert_eq(note.text, "19 pests — faster than the last",
			"and the note carries the count and what got worse")
	if err == "":
		# Straight to the start of the fade: still fully up, not already ghosting.
		game.hud._fade_banner(Hud.BANNER_HOLD_SECONDS - Hud.BANNER_FADE_SECONDS)
		err = _T.assert_float_eq(banner.modulate.a, 1.0, 0.01,
			"it is still fully opaque when the fade begins, not at %.2f" % banner.modulate.a)
	if err == "":
		game.hud._fade_banner(Hud.BANNER_FADE_SECONDS * 0.5)
		err = _T.assert_float_eq(banner.modulate.a, 0.5, 0.01,
			"half a fade in, it is half faded, not %.2f" % banner.modulate.a)
	if err == "":
		err = _T.assert_true(banner.visible, "and still on screen while it fades")
	if err == "":
		game.hud._fade_banner(Hud.BANNER_FADE_SECONDS)
		err = _T.assert_false(banner.visible or note.visible, "then it takes itself down")
	if err == "":
		# Hidden AND opaque again: a row left at alpha 0 would come back invisible
		# on the next wave, which no assertion about `visible` alone would catch.
		err = _T.assert_float_eq(banner.modulate.a, 1.0, 0.001,
			"and is reset to opaque, so the next wave is not announced invisibly")
	_T.free_ui(game)
	return err


## The other event this surface now carries (plant-tower-defense-d2a). Same
## shape as the wave-started check above, own text, own headline.
func test_the_wave_cleared_banner_appears_on_announcement_and_clears_itself() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var banner: Label = game.hud.get_node_or_null("Root/Banner") as Label
	var note: Label = game.hud.get_node_or_null("Root/BannerNote") as Label
	var err: String = _T.assert_true(banner != null and note != null, "both banner rows exist")
	if err == "":
		err = _T.assert_false(banner.visible, "and nothing is announced at launch")
	if err == "":
		game.hud.announce_wave_cleared(7, 19)
		err = _T.assert_true(banner.visible and note.visible, "announcing a cleared wave raises both rows")
	if err == "":
		err = _T.assert_eq(banner.text, "Wave 7 cleared",
			"the headline names the wave and says it is over, not merely names it")
	if err == "":
		err = _T.assert_eq(note.text, "19 pests turned back.",
			"and the note carries what the wave actually cost")
	if err == "":
		# Same hold-and-fade timer the wave-started banner uses -- comparable
		# weight was the whole point, and a shorter hold here would quietly
		# undercut it again.
		game.hud._fade_banner(Hud.BANNER_HOLD_SECONDS - Hud.BANNER_FADE_SECONDS)
		err = _T.assert_float_eq(banner.modulate.a, 1.0, 0.01,
			"it is still fully opaque when the fade begins, not at %.2f" % banner.modulate.a)
	if err == "":
		game.hud._fade_banner(Hud.BANNER_FADE_SECONDS)
		err = _T.assert_false(banner.visible or note.visible, "then it takes itself down like the other one")
	_T.free_ui(game)
	return err


## Surviving a wave used to reach only `hud.show_message` -- a single 15px
## status-row sentence, quieter than the wave it just outlasted, which fired a
## banner and Sfx.WAVE_STARTED the instant it began. This is the fix, asserted
## at the Game level rather than by calling the Hud method directly: it is the
## wiring in _check_wave_cleared that plant-tower-defense-d2a is about, not
## just the Hud method existing.
func test_clearing_a_wave_gets_a_cue_as_loud_as_starting_one() -> String:
	var game := await _T.instantiate_ui(GAME_SCENE, Vector2i(1152, 648)) as Game
	var err: String = _T.assert_true(game.start_next_wave(), "wave 1 starts")
	if err == "":
		err = _T.assert_true(Sfx.should_play(Sfx.WAVE_CLEARED, false, false),
			"the event this cue needs exists and is playable")
	if err == "":
		# Drive spawning to completion with large synthetic steps rather than
		# real time -- the same shape
		# test_a_started_wave_schedules_exactly_the_pests_the_table_promises
		# already uses on the director directly.
		var guard: int = 0
		while game.director.is_spawning() and guard < 4000:
			game.director._process(0.1)
			guard += 1
		err = _T.assert_false(game.director.is_spawning(), "wave 1 finished spawning")
	if err == "":
		# Every pest freed rather than killed still leaves the "pests" group,
		# which is all _check_wave_cleared reads.
		for pest: Node in game.get_tree().get_nodes_in_group("pests"):
			pest.queue_free()
		await _pump(game)
		game._check_wave_cleared()
		var banner: Label = game.hud.get_node_or_null("Root/Banner") as Label
		err = _T.assert_true(banner != null and banner.visible,
			"clearing the wave raised the same banner a wave-start would have")
		if err == "":
			err = _T.assert_eq(banner.text, Hud.wave_cleared_headline(1),
				"naming the wave that was just held, not the one about to start")
	_T.free_ui(game)
	return err


## A run can end mid-hold. RunSummary's backdrop is deliberately translucent, so
## a leftover "Wave 12" would read straight through the post-mortem in 48px.
func test_ending_a_run_takes_the_wave_banner_down() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var banner: Label = game.hud.get_node_or_null("Root/Banner") as Label
	game.hud.announce_wave(12, 30, "")
	var err: String = _T.assert_true(banner.visible, "the banner is up mid-wave")
	if err == "":
		game.game_over = true
		game._refresh()
		err = _T.assert_false(banner.visible, "and the run ending clears it without the Game asking")
	_T.free_ui(game)
	return err


## The banner's whole defence against becoming a second oversubscribed status
## row is that it has no generic setter to dump lines into -- only an API named
## for its one event. A `show_banner(text)` reintroduced later would undo that
## silently, so it is asserted gone rather than merely deleted.
func test_the_banner_has_no_generic_setter_to_become_a_second_message_row() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_false(game.hud.has_method("show_banner"),
		"there is no generic show_banner(text) for a second kind of line to reuse")
	if err == "":
		err = _T.assert_true(game.hud.has_method("announce_wave"),
			"only announce_wave, which names the single event this surface serves")
	if err == "":
		# The status row is what the banner exists to relieve; announcing a wave
		# must not also queue a line there, or the move bought nothing.
		var pending: int = game.hud.pending_messages()
		var line: String = (game.hud.get_node("Root/TopBar/MessageLabel") as Label).text
		game.hud.announce_wave(4, 11, "")
		err = _T.assert_eq(game.hud.pending_messages(), pending,
			"announcing a wave queues nothing on the status row")
		if err == "":
			err = _T.assert_eq((game.hud.get_node("Root/TopBar/MessageLabel") as Label).text, line,
				"and does not stomp whatever line is already there")
	_T.free_ui(game)
	return err


## Both halves are pure static text builders, so every branch is assertable
## without a HUD at all -- the same reason Hud.threat_color is static.
func test_the_wave_banner_text_covers_both_escalation_branches() -> String:
	var err: String = _T.assert_eq(Hud.wave_headline(1), "Wave 1", "the headline is just the wave")
	if err == "":
		err = _T.assert_eq(Hud.wave_note(5, ""), "5 pests",
			"inside the fixed table the note is the count alone, with no dangling clause")
	if err == "":
		err = _T.assert_eq(Hud.wave_note(5, "tougher"), "5 pests — tougher than the last",
			"past it, the note names what actually got worse")
	if err == "":
		# The branch the empty note protects: WaveDirector.escalation_note is ""
		# for every wave in the fixed table, which is most of a campaign run.
		err = _T.assert_eq(WaveDirector.escalation_note(1), "",
			"and wave 1 really does produce the empty note this branch exists for")
	if err == "":
		err = _T.assert_eq(Hud.wave_cleared_headline(1), "Wave 1 cleared",
			"the cleared headline names the same wave, past tense")
	if err == "":
		err = _T.assert_eq(Hud.wave_cleared_note(5), "5 pests turned back.",
			"and the cleared note carries what the wave actually cost")
	return err


## The post-mortem grows a row every time the run learns to count something new,
## and each one pushes the last row toward the buttons. At five rows there was
## room; at seven the last row ended four pixels above them. This is the assertion
## that makes the next row a build failure rather than a rendering accident.
func test_the_post_mortem_rows_keep_clear_of_its_buttons() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.lives = 1
	game._on_pest_escaped(null)
	await _pump(game)
	var panel: RunSummary = game.get_node_or_null("SummaryLayer/RunSummary") as RunSummary
	var err: String = _T.assert_true(panel != null, "the card is up")
	if err == "":
		var rows: Array = panel.summary_rows()
		err = _T.assert_gt(rows.size(), 0, "the card has rows to check")
		if err == "":
			var lowest: float = 0.0
			for row: Array in rows:
				var label: Label = panel.get_node_or_null(
					"Value_%s" % String(row[0]).replace(" ", "")) as Label
				if label != null:
					lowest = maxf(lowest, label.position.y + label.size.y)
			var button: Button = panel.get_node_or_null("ReplayButton") as Button
			err = _T.assert_true(button != null, "the replay button exists")
			if err == "":
				err = _T.assert_true(lowest <= button.position.y - RunSummary.BUTTON_CLEARANCE,
					"the last row foot %.0f keeps %dpx clear of the buttons at %.0f"
						% [lowest, int(RunSummary.BUTTON_CLEARANCE), button.position.y])
	if err == "":
		# And the whole stack stays on the card, not just off the buttons.
		var card: Control = panel.get_node_or_null("Card") as Control
		err = _T.assert_true(card != null, "the card panel exists")
		if err == "":
			var button2: Button = panel.get_node_or_null("GateButton") as Button
			err = _T.assert_true(button2.position.y + button2.size.y <= card.position.y + card.size.y,
				"and the buttons themselves stay on the paper")
	_T.free_ui(game)
	return err


## Scene validation as a standing gate rather than a thing /verify asks once.
##
## coverage_check.py reports `scene_validation` UNCHECKED for this project: nothing
## in test_dir loads a res:// scene, so a broken .tscn is only found by running the
## game. The runtime `findings` sweep does check it, but that is an observation a
## past session made, not a question that gets asked again -- and the tool says so
## explicitly, refusing to count a check name in the ledger as evidence the verb
## ran, because a name is prose a run writes about itself.
##
## A .tscn that fails to load is silent in every other gate here: lint compiles
## scripts, name_check resolves identifiers, and neither instantiates anything.
func test_every_scene_in_the_project_actually_instantiates() -> String:
	# The two scenes the game cannot start without, named as literals. The walk
	# below covers everything including scenes added later, but a dynamic path is
	# invisible to coverage_check.py, which requires a res:// .tscn literal inside
	# load/preload as its evidence -- so a discovery-based check, which is strictly
	# stronger than a hard-coded list, scores as no check at all without these.
	var required: Array[PackedScene] = [
		load("res://game/game.tscn") as PackedScene,
		load("res://game/title.tscn") as PackedScene,
	]
	for scene: PackedScene in required:
		var e: String = _T.assert_true(scene != null and scene.can_instantiate(),
			"a required scene is loadable and instantiable")
		if e != "":
			return e

	var scenes: Array[String] = []
	_collect_scenes("res://", scenes)
	var err: String = _T.assert_gt(scenes.size(), 0,
		"found at least one .tscn to check -- an empty walk would pass vacuously")
	if err != "":
		return err
	for path: String in scenes:
		var packed: PackedScene = load(path) as PackedScene
		err = _T.assert_true(packed != null, "%s loads as a PackedScene" % path)
		if err != "":
			return err
		err = _T.assert_true(packed.can_instantiate(), "%s reports it can instantiate" % path)
		if err != "":
			return err
		var node: Node = packed.instantiate()
		err = _T.assert_true(node != null, "%s actually instantiates" % path)
		if node != null:
			node.queue_free()
		if err != "":
			return err
	return ""


## Walks res:// for .tscn files, skipping the addon and anything hidden. Written
## against DirAccess rather than a hard-coded list precisely so a scene added later
## is covered without anyone remembering to add it here.
func _collect_scenes(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full: String = dir_path.path_join(name)
		if dir.current_is_dir():
			# The harness's own addon is not this project's to validate.
			if full != "res://addons":
				_collect_scenes(full, out)
		elif name.ends_with(".tscn"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()


## Every signal a game script declares must have a listener by the time the run is
## up. A signal nobody connected is a button that does nothing, and it is silent in
## every other gate: it compiles, it lints, and emitting it succeeds.
##
## This project has already shipped that exact bug once -- Plant.set_selected() had
## no caller, so the range ring could never draw -- which is why the check is worth
## having as a standing question rather than a thing a session once noticed.
##
## Uses get_script_signal_list() rather than get_signal_list(), so only signals THIS
## project declares are asserted and none of Godot's inherited ones.
func test_every_signal_a_game_script_declares_has_a_listener() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	# Plants and pests are not in the tree at load, so a bare walk would never see
	# Plant.destroyed, Pest.died or Sunflower.grew_seeds -- exactly the signals
	# most likely to be left dangling, since they are wired at spawn time rather
	# than in _ready(). Put one of each on the board first.
	game.bank.add_seeds(300)
	game.place_plant(PlantCatalog.CORN, _grass(game))
	game.place_plant(PlantCatalog.SUNFLOWER, _grass(game))
	game.spawn_pest(Pest.APHID)
	await _pump(game)
	var checked: int = 0
	var err: String = ""
	for node: Node in _scripted_nodes(game):
		var script: Script = node.get_script() as Script
		if script == null:
			continue
		for sig: Dictionary in script.get_script_signal_list():
			var sig_name: String = String(sig["name"])
			checked += 1
			if node.get_signal_connection_list(sig_name).is_empty():
				err = "%s declares signal '%s' and nothing is connected to it" % [
					script.resource_path.get_file(), sig_name]
				break
		if err != "":
			break
	if err == "":
		# Guard against a vacuous pass: an empty walk satisfies every loop in it.
		err = _T.assert_gt(checked, 0, "found signals to check")
	else:
		err = _T.assert_true(false, err)
	_T.free_ui(game)
	return err


## Every node at or under `root` that carries a script.
func _scripted_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	if root.get_script() != null:
		out.append(root)
	for child: Node in root.get_children():
		out.append_array(_scripted_nodes(child))
	return out


## The plant bar sizes itself to the catalogue instead of to a number that happened
## to fit when it was written.
##
## The old bar was a 240px VBox of fixed 56px buttons: four plants ended at y=292
## against a packet button hard-coded at y=300, so it fit with eight pixels to
## spare and a fifth plant silently overlapped. Nothing failed -- overlapping
## siblings each fit their own box -- which is why this is arithmetic on a pure
## function rather than a rendering check.
func test_the_plant_bar_fits_a_catalogue_larger_than_todays() -> String:
	var span: float = Hud.PLANT_BAR_BOTTOM - Hud.PLANT_BAR_Y
	var err: String = ""
	# The sweep asserts TWO different things now, and the split is the point. Up to the
	# catalogue the panel was sized for, the bar fits without scrolling. Past it, the
	# layout must SAY it overflows rather than quietly returning something unrenderable --
	# which is what it used to do: it fell back to two columns, whose own header called
	# that answer impossible to render, and cycle 98's sixth plant reached it. `findings`
	# then reported the side panel 167px off the right edge of the viewport.
	#
	# The height floor holds either way. A button below 40px is not a touch target, and
	# that is the one thing this function must never return.
	var fits_without_scrolling: int = 0
	for count: int in range(1, 11):
		var layout: Dictionary = Hud.plant_bar_layout(count)
		var rows: int = int(layout["rows"])
		var height: float = float(layout["height"])
		var used: float = float(rows) * height + float(Hud.PLANT_BAR_SEPARATION * (rows - 1))
		# Two columns past the single-column limit, and one below it. Cycle 99 made two
		# renderable by taking the NAME off the button -- the minimum width went from
		# 195px to under the 114px a two-column bar can give -- so this asserts the rule
		# rather than a fixed number, and the constants are the thing that moved.
		var want_columns: int = (Hud.PLANT_BAR_COLUMNS
			if count > Hud.PLANT_BAR_SINGLE_COLUMN_MAX else 1)
		err = _T.assert_eq(int(layout["columns"]), want_columns,
			"%d plant(s): %d column(s)" % [count, want_columns])
		if err == "":
			err = _T.assert_true(height >= Hud.PLANT_BUTTON_MIN_HEIGHT,
				"%d plant(s): a %.1fpx button is below the %dpx touch minimum"
					% [count, height, int(Hud.PLANT_BUTTON_MIN_HEIGHT)])
		if err == "":
			# Fits and says it fits, or does not fit and says THAT. What is forbidden is
			# a layout that overruns the span while reporting no overflow, because the
			# caller reads that flag to decide whether to scroll.
			var overflows: bool = bool(layout.get("overflows", false))
			err = _T.assert_eq(overflows, used > span + 0.01,
				"%d plant(s): %d row(s) at %.1fpx use %.1f of %.1f, and overflows says %s"
					% [count, rows, height, used, span, str(overflows)])
			if err == "" and not overflows:
				fits_without_scrolling = count
		if err != "":
			return err
	if err == "":
		# The number today's panel actually holds. Pinned so that shrinking the bar, or
		# raising the touch floor, is a visible change rather than a silent one -- and so
		# that a future plant reads this line and knows the bar will scroll.
		err = _T.assert_gte(fits_without_scrolling, 10,
			"the whole sweep fits without scrolling now that the bar is two columns of "
				+ "icon-and-price buttons -- it held five before cycle 99 (got %d)"
				% fits_without_scrolling)
	return err


func test_the_plant_bar_refuses_rather_than_shrinking_past_a_touch_target() -> String:
	# Past what two columns can hold, the layout must say so rather than quietly
	# returning a button too small to hit. A silent shrink is the failure the 40px
	# gate exists to catch, and it would sail through the test above.
	var layout: Dictionary = Hud.plant_bar_layout(24)
	var err: String = _T.assert_true(bool(layout.get("overflows", false)),
		"an absurd catalogue reports that it overflows")
	if err == "":
		err = _T.assert_true(float(layout["height"]) >= Hud.PLANT_BUTTON_MIN_HEIGHT,
			"and never reports a height below the touch minimum")
	return err


## The live bar, against the real catalogue: every button on it must be a legal
## touch target and none may reach the packet button below.
func test_no_plant_button_overlaps_the_packet_buttons() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	await _pump(game)
	var bar: Control = game.hud.get_node_or_null("Root/SidePanel/PlantBar") as Control
	var packet: Control = game.hud.get_node_or_null("Root/SidePanel/PacketButton") as Control
	var err: String = _T.assert_true(bar != null and packet != null, "bar and packet button exist")
	if err == "":
		err = _T.assert_gt(bar.get_child_count(), 0, "the bar has buttons on it")
	if err == "":
		var lowest: float = 0.0
		for child: Node in bar.get_children():
			var button := child as Button
			if button == null:
				continue
			lowest = maxf(lowest, button.position.y + button.size.y)
			err = _T.assert_true(button.size.y >= Hud.PLANT_BUTTON_MIN_HEIGHT,
				"%s is %.0fpx tall, under the touch minimum" % [button.name, button.size.y])
			if err != "":
				break
		if err == "":
			err = _T.assert_true(bar.position.y + lowest <= packet.position.y,
				"the lowest plant button foot %.0f stays above the packet button at %.0f"
					% [bar.position.y + lowest, packet.position.y])
	_T.free_ui(game)
	return err


## Pause. The game had none: get_tree().paused appeared nowhere in game/, so the
## prep countdown kept running while the player was away from the keyboard, and
## the only way out of a run in progress was to lose it.
func test_pausing_a_run_actually_stops_the_prep_countdown() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game._wave_live = false
	game._prep_left = Game.PREP_SECONDS
	var err: String = _T.assert_false(game.is_paused(), "a fresh run is not paused")
	if err == "":
		game._process(1.0)
		err = _T.assert_float_eq(game._prep_left, Game.PREP_SECONDS - 1.0, 0.01,
			"the countdown runs while the run does")
	if err == "":
		game.pause_run()
		await _pump(game)
		err = _T.assert_true(game.is_paused(), "pausing sets the tree's own flag")
	if err == "":
		err = _T.assert_true(game.get_node_or_null("PauseLayer/PauseScreen") != null,
			"and the card is on screen")
	if err == "":
		# The real claim. _process is not called on a paused node by the engine, so
		# asserting the countdown directly means asserting that the pause reaches
		# the thing the player actually loses to.
		var held: float = game._prep_left
		await _pump(game)
		await _pump(game)
		err = _T.assert_float_eq(game._prep_left, held, 0.001,
			"the prep countdown does not advance while paused")
	if err == "":
		game.resume_run()
		await _pump(game)
		err = _T.assert_false(game.is_paused(), "resuming clears the flag")
	if err == "":
		err = _T.assert_true(game.get_node_or_null("PauseLayer") == null,
			"and takes the card down with it")
	_T.free_ui(game)
	return err


func test_the_pause_card_keeps_processing_while_the_game_it_paused_does_not() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.pause_run()
	await _pump(game)
	var screen: Control = game.get_node_or_null("PauseLayer/PauseScreen") as Control
	var err: String = _T.assert_true(screen != null, "the card exists")
	if err == "":
		# Without PROCESS_MODE_ALWAYS the card is frozen by the pause it owns and
		# none of its own buttons can be clicked -- a pause menu that cannot be
		# dismissed. This is the single mistake this screen exists to not make.
		err = _T.assert_eq(screen.process_mode, Node.PROCESS_MODE_ALWAYS,
			"the card runs while the tree is paused")
	if err == "":
		var layer: CanvasLayer = game.get_node_or_null("PauseLayer") as CanvasLayer
		err = _T.assert_eq(layer.process_mode, Node.PROCESS_MODE_ALWAYS,
			"and so does the layer holding it")
	if err == "":
		for spec: Dictionary in PauseScreen.BUTTONS:
			var b: Button = screen.get_node_or_null(String(spec["name"])) as Button
			err = _T.assert_true(b != null and not b.disabled,
				"%s is present and clickable" % String(spec["name"]))
			if err != "":
				break
	if err == "":
		# Pausing twice must not stack two cards.
		game.pause_run()
		await _pump(game)
		var found: int = 0
		for child: Node in game.get_node("PauseLayer").get_children():
			if child is PauseScreen:
				found += 1
		err = _T.assert_eq(found, 1, "pausing twice leaves exactly one card")
	game.resume_run()
	_T.free_ui(game)
	return err


## A tooltip that names a specific plant is perishable, and it perishes silently:
## nothing fails when a sentence stops describing the thing it points at. The rare
## packet's read "the only reliable way to a Seed Sunflower" for a whole cycle
## after a fourth plant made it false.
func test_no_packet_tooltip_names_a_plant_it_might_stop_being_about() -> String:
	var err: String = ""
	for tier: StringName in SeedBank.PACKET_TIERS:
		var text: String = Hud.packet_tooltip(tier)
		err = _T.assert_false(text.is_empty(), "%s has a tooltip" % tier)
		if err != "":
			return err
		for id: StringName in PlantCatalog.ids():
			var display: String = PlantCatalog.display_name(id)
			err = _T.assert_false(text.contains(display),
				"the %s tooltip names '%s', so it goes stale the moment the catalogue moves: %s"
					% [tier, display, text])
			if err != "":
				return err
	return err


## Driven over PACKET_ORDER rather than over two named tiers.
##
## This asserted "the rare tooltip counts the whole catalogue", which was true while
## rare capped at 99 and reached everything. The epic tier moved that job one rung
## up and re-capped rare at 2, and the test failed -- correctly, and for a reason
## that was a deliberate design change rather than a defect. Naming `rare` was the
## bug: the claim worth holding is that EVERY tier's tooltip counts what THAT tier
## reaches, which is true of a catalogue and a tier list of any size, and which
## keeps meaning something the next time a tier is added.
func test_a_packet_tooltip_counts_what_its_tier_can_actually_reach() -> String:
	var err: String = _T.assert_gt(SeedBank.PACKET_ORDER.size(), 1,
		"there is more than one tier, or a per-tier reach count means nothing")
	if err != "":
		return err
	var top_reaches_all: bool = false
	for tier: StringName in SeedBank.PACKET_ORDER:
		var text: String = Hud.packet_tooltip(tier)
		var cap: int = int((SeedBank.PACKET_TIERS[tier] as Dictionary)["max_tier"])
		var within: int = 0
		var beyond: int = 0
		for id: StringName in PlantCatalog.ids():
			if PlantCatalog.tier(id) <= cap:
				within += 1
			else:
				beyond += 1
		if beyond == 0:
			top_reaches_all = true
		err = _T.assert_gt(within, 0, "%s reaches something at all" % tier)
		if err == "":
			err = _T.assert_true(text.contains(str(within)),
				"the %s tooltip counts what it can reach (%d), got: %s" % [tier, within, text])
		if err == "" and beyond > 0:
			err = _T.assert_true(text.contains(str(beyond)),
				"and says how many it cannot (%d), got: %s" % [beyond, text])
		if err != "":
			return err
	err = _T.assert_true(top_reaches_all,
		"some tier reaches the whole catalogue, or a plant exists that no packet can hand over")
	if err == "":
		err = _T.assert_true(Hud.packet_tooltip(&"nosuchtier").is_empty(),
			"an unknown tier returns nothing rather than a half-built sentence")
	return err


## No two Controls on the pause card may share pixels.
##
## This is the check that was missing when the card shipped: FIRST_BUTTON_Y was an
## absolute 232.0 while every other offset was CARD.position.y + N, so the note's
## box ran 228..252 under a ResumeButton at 232..276 and twenty of its twenty-four
## pixels were behind an opaque stylebox. Nothing failed, because every Control fit
## its own box -- and per-Control measurement is all validate-ui and findings do.
func test_no_two_pause_card_controls_share_pixels() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.pause_run()
	await _pump(game)
	var screen: Control = game.get_node_or_null("PauseLayer/PauseScreen") as Control
	var err: String = _T.assert_true(screen != null, "the card is up")
	if err == "":
		var rects: Dictionary = {}
		for child: Node in screen.get_children():
			var control := child as Control
			# The backdrop covers everything by design, and the card is the paper
			# the rest sits on -- neither is a sibling competing for space.
			if control == null or not control.visible or control.name in ["Backdrop", "Card"]:
				continue
			if control.size.x <= 0.0 or control.size.y <= 0.0:
				continue
			rects[String(control.name)] = Rect2(control.global_position, control.size)
		err = _T.assert_gt(rects.size(), 1, "there are at least two Controls to compare")
		if err == "":
			var names: Array = rects.keys()
			for i: int in range(names.size()):
				for j: int in range(i + 1, names.size()):
					var a: Rect2 = rects[names[i]]
					var b: Rect2 = rects[names[j]]
					err = _T.assert_false(a.intersects(b),
						"%s %s overlaps %s %s" % [names[i], a, names[j], b])
					if err != "":
						break
				if err != "":
					break
	if err == "":
		# And everything stays on the paper it is drawn against.
		var card: Control = screen.get_node_or_null("Card") as Control
		for child: Node in screen.get_children():
			var control := child as Control
			if control == null or control.name in ["Backdrop", "Card"] or not control.visible:
				continue
			err = _T.assert_true(control.global_position.y + control.size.y
					<= card.global_position.y + card.size.y,
				"%s runs past the bottom of the card" % control.name)
			if err != "":
				break
	game.resume_run()
	_T.free_ui(game)
	return err


## Leaving a run must file the score. In endless, dying was the only way to bank
## one -- has_more_waves() is unconditionally true there, so victory is
## unreachable -- and pause then added two doors that walked out past _end_run.
func test_quitting_a_run_through_pause_still_files_the_score() -> String:
	# `game.bank_score()` reaches RunConfig.record_score() -> _save(), so this test
	# persists even though its body never names a RunConfig mutator. Staging both
	# records at 0 first means the write lands unconditionally: against the real
	# save_path it filed 320 over this machine's actual campaign record, and the
	# in-memory restore at the bottom hid it exactly as the direct callers' comments
	# describe. Redirect FIRST, before anything reaches the game.
	var stashed_path: String = RunConfig.save_path
	RunConfig.save_path = "user://test_selftest_bank_score.save"
	var saved_c: int = RunConfig.campaign_high_score
	var saved_e: int = RunConfig.endless_high_score
	RunConfig.campaign_high_score = 0
	RunConfig.endless_high_score = 0
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(320)
	var earned: int = game.bank.seeds_earned_total
	var err: String = _T.assert_gt(earned, 0, "the run earned something worth filing")
	if err == "":
		err = _T.assert_true(game.bank_score(), "quitting files the run's total")
	if err == "":
		err = _T.assert_eq(RunConfig.best_for(game.director.endless), earned,
			"and it lands on the mode that was played")
	if err == "":
		# Filing twice would let one run set a record and then beat itself.
		err = _T.assert_false(game.bank_score(), "a second attempt files nothing")
	if err == "":
		# And the losing path shares the same guard, so quit-then-lose is one score.
		game.lives = 1
		game._on_pest_escaped(null)
		await _pump(game)
		err = _T.assert_eq(RunConfig.best_for(game.director.endless), earned,
			"losing after quitting does not file a second time")
	RunConfig.campaign_high_score = saved_c
	RunConfig.endless_high_score = saved_e
	RunConfig.save_path = stashed_path
	DirAccess.remove_absolute("user://test_selftest_bank_score.save")
	_T.free_ui(game)
	return err


func test_the_pause_note_describes_the_moment_it_interrupted() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game._wave_live = false
	game._prep_left = 9.0
	var between: String = game.pause_note()
	var err: String = _T.assert_true(between.contains("9") or between.contains("10"),
		"between waves it counts the wait, got: %s" % between)
	if err == "":
		# The old text was the constant "The wave is waiting.", which is exactly
		# what it must not say when no wave is on its way.
		err = _T.assert_false(between == "The wave is waiting.",
			"and is not the constant it used to be")
	if err == "":
		game._wave_live = true
		var during: String = game.pause_note()
		err = _T.assert_true(during != between, "a live wave reads differently, got: %s" % during)
	_T.free_ui(game)
	return err


## A hand-written list of key bindings goes stale the first time someone adds a
## key and forgets. This used to scan _unhandled_input for KEY_* constants and
## check them against a hand-written Game.KEY_HELP; the handler now answers to
## InputMap actions and key_help() renders those same actions, so the drift this
## guarded against is gone at the keycode level. What is left to police is one
## level up: an ACTION the run handles that no legend row names.
##
## Both halves still come out of the handler's own source rather than out of the
## table, so a fifth verb added without a row in KeyBindings.ACTIONS fails here.
func test_every_key_the_run_handles_is_named_on_the_pause_card() -> String:
	var src: String = FileAccess.get_file_as_string("res://game/game.gd")
	var err: String = _T.assert_gt(src.length(), 0, "game.gd is readable")
	if err != "":
		return err

	# Only the input handler's own body -- key_help() also names actions, and
	# counting those would let the list vouch for itself.
	var start: int = src.find("func _unhandled_input")
	err = _T.assert_gt(start, 0, "found _unhandled_input")
	if err != "":
		return err
	var following: int = src.find("\nfunc ", start + 1)
	var body: String = src.substr(start, (following - start) if following > start else -1)

	# No raw scancode may come back. This is the regression the migration exists
	# to prevent, and it is one grep.
	var keycodes := RegEx.new()
	keycodes.compile("KEY_[A-Z0-9_]+")
	err = _T.assert_eq(keycodes.search_all(body).size(), 0,
		"_unhandled_input names no KEY_* constant -- bindings live in KeyBindings.ACTIONS")
	if err != "":
		return err

	var handled: Array[String] = []
	var regex := RegEx.new()
	regex.compile("KeyBindings\\.(ACTION_[A-Z0-9_]+)")
	for m: RegExMatch in regex.search_all(body):
		var name: String = m.get_string(1)
		if not handled.has(name):
			handled.append(name)
	err = _T.assert_gt(handled.size(), 0,
		"the handler references at least one action -- an empty scan would pass vacuously")
	if err != "":
		return err

	var documented: Array[StringName] = []
	for row: Dictionary in Game.key_help():
		documented.append(StringName(row["action"]))

	# ACTION_PAUSE -> KeyBindings.ACTION_PAUSE's value, resolved through the
	# script's own constant map so a constant the handler names but the class does
	# not declare fails here rather than being compared as a bare string.
	var consts: Dictionary = (load("res://game/key_bindings.gd") as Script).get_script_constant_map()
	for name: String in handled:
		err = _T.assert_true(consts.has(name), "KeyBindings declares %s" % name)
		if err != "":
			return err
		var action: StringName = StringName(consts[name])
		err = _T.assert_true(documented.has(action),
			"_unhandled_input answers to %s (%s) and the pause card's legend does not name it; documented: %s"
				% [name, action, documented])
		if err != "":
			return err
	return err


## The InputMap half of the same guarantee. Every action the table declares has to
## actually exist and actually be bound, or `event.is_action_pressed(...)` is a
## silent no-op that no gate in this project would notice: a missing action is not
## an error, it is simply an event that never matches.
func test_every_declared_action_is_registered_with_the_engine() -> String:
	KeyBindings.install()
	var actions: Array[StringName] = KeyBindings.actions()
	var err: String = _T.assert_gt(actions.size(), 0, "the table declares actions to register")
	if err != "":
		return err
	for action: StringName in actions:
		err = _T.assert_true(InputMap.has_action(action), "%s is in the InputMap" % action)
		if err == "":
			err = _T.assert_gt(KeyBindings.keys_for(action).size(), 0, "%s is bound to a key" % action)
		if err == "":
			err = _T.assert_eq(KeyBindings.keys_for(action), KeyBindings.defaults_for(action),
				"%s starts on the keys the table ships" % action)
		if err == "":
			err = _T.assert_true(KeyBindings.describe(action) != "", "%s says what it does" % action)
		if err != "":
			return err
	# The project's own five verbs, by name. A rename that missed a call site would
	# leave the constant resolving and the action absent, and the loop above only
	# ever checks the table against itself.
	for expected: StringName in [
		KeyBindings.ACTION_PAUSE, KeyBindings.ACTION_MUTE_SFX, KeyBindings.ACTION_MUTE_MUSIC,
		KeyBindings.ACTION_RESTART, KeyBindings.ACTION_PAGE_PREV, KeyBindings.ACTION_PAGE_NEXT,
		KeyBindings.ACTION_BACK,
	]:
		err = _T.assert_true(actions.has(expected), "%s is one of the declared actions" % expected)
		if err != "":
			return err
	return err


## The keys the run shipped with, before any of this was rebindable. A migration
## that quietly moved pause off Escape would pass every structural check above.
func test_the_shipped_bindings_are_the_ones_the_run_always_had() -> String:
	var expected: Dictionary = {
		KeyBindings.ACTION_PAUSE: [KEY_ESCAPE, KEY_P],
		KeyBindings.ACTION_MUTE_SFX: [KEY_M],
		KeyBindings.ACTION_MUTE_MUSIC: [KEY_N],
		KeyBindings.ACTION_RESTART: [KEY_R],
		KeyBindings.ACTION_PAGE_PREV: [KEY_LEFT],
		KeyBindings.ACTION_PAGE_NEXT: [KEY_RIGHT],
		KeyBindings.ACTION_BACK: [KEY_ESCAPE],
	}
	var err := ""
	for action: StringName in expected:
		err = _T.assert_eq(KeyBindings.defaults_for(action), expected[action],
			"%s ships on the same keys it always had" % action)
		if err != "":
			break
	return err


## Rebinding, and the legend following it. The pause card's key list is the whole
## reason key_help() is derived rather than written down: a player who moves pause
## to F1 and is still told "Esc · P" has been given a wrong instruction by the one
## screen that exists to give them a right one.
func test_rebinding_a_verb_moves_the_pause_card_legend_with_it() -> String:
	KeyBindings.reset_all()
	var before: String = KeyBindings.label_for(KeyBindings.ACTION_PAUSE)
	var err: String = _T.assert_eq(before, "Esc  ·  P", "pause reads as its two shipped keys")
	if err == "":
		err = _T.assert_true(KeyBindings.set_keys(KeyBindings.ACTION_PAUSE, [KEY_F1]),
			"pause can be moved to F1")
	if err == "":
		err = _T.assert_eq(KeyBindings.label_for(KeyBindings.ACTION_PAUSE), "F1",
			"and the legend says so")
	if err == "":
		var row: Dictionary = {}
		for candidate: Dictionary in Game.key_help():
			if StringName(candidate["action"]) == KeyBindings.ACTION_PAUSE:
				row = candidate
		err = _T.assert_eq(String(row.get("keys", "")), "F1",
			"the pause card renders the moved key, not the shipped one")
		if err == "":
			err = _T.assert_eq(row["codes"], [KEY_F1], "and its codes are the moved ones too")
	if err == "":
		# The run's own message names the key as well, and it used to say "Press M"
		# in a string literal.
		KeyBindings.set_keys(KeyBindings.ACTION_MUTE_SFX, [KEY_F2])
		err = _T.assert_eq(Game.mute_message("Sound effects", true, KeyBindings.ACTION_MUTE_SFX, "them"),
			"Sound effects off. Press F2 to bring them back.",
			"the mute message names whatever the verb is bound to now")
	if err == "":
		err = _T.assert_eq(Game.mute_message("Music", false, KeyBindings.ACTION_MUTE_MUSIC),
			"Music on.", "and un-muting names no key at all")
	# Global engine state: put it back whatever happened above.
	KeyBindings.reset_all()
	if err == "":
		err = _T.assert_eq(KeyBindings.label_for(KeyBindings.ACTION_PAUSE), "Esc  ·  P",
			"reset_all puts every verb back on its shipped key")
	return err


## An empty binding is refused rather than stored. An unbound verb cannot be
## reached, and no screen in this game explains how to get it back.
func test_a_verb_cannot_be_unbound_and_a_clash_is_reported() -> String:
	# The InputMap is engine-global and every test in this suite shares it, so
	# start from the shipped keys rather than from whatever ran last.
	KeyBindings.reset_all()
	var err: String = _T.assert_false(KeyBindings.set_keys(KeyBindings.ACTION_PAUSE, []),
		"binding a verb to nothing is refused")
	if err == "":
		err = _T.assert_eq(KeyBindings.keys_for(KeyBindings.ACTION_PAUSE), [KEY_ESCAPE, KEY_P],
			"and the refusal left the old keys in place")
	if err == "":
		err = _T.assert_false(KeyBindings.set_keys(&"garden_not_a_verb", [KEY_Z]),
			"an action the table does not declare is refused too")
	if err == "":
		err = _T.assert_eq(String(KeyBindings.action_using(KEY_M)), String(KeyBindings.ACTION_MUTE_SFX),
			"M is reported as already spoken for")
	if err == "":
		err = _T.assert_eq(String(KeyBindings.action_using(KEY_M, KeyBindings.ACTION_MUTE_SFX)), "",
			"except by the row that already owns it")
	if err == "":
		err = _T.assert_eq(String(KeyBindings.action_using(KEY_F9)), "",
			"and a key nothing uses is free")
	return err


## A verb has two shapes. A keyboard sends InputEventKey; `Input.action_press` —
## which is what the devtools bridge's `input tap` and any future gamepad or
## on-screen control send — sends InputEventAction, and an InputEventAction has no
## keycode at all.
##
## Found live, not read off the diff: the migrated handlers kept the
## `event as InputEventKey` narrowing they needed while they compared raw
## keycodes, so `input tap garden_pause` against the running game did nothing and
## `find-nodes --class PauseScreen` came back empty. It looks entirely correct to a
## player at a keyboard, which is why it needs a check rather than a reading.
func test_a_verb_arrives_as_an_action_event_as_well_as_a_key_event() -> String:
	KeyBindings.reset_all()
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game._unhandled_input(_action_press(KeyBindings.ACTION_PAUSE))
	await _pump(game)
	var err: String = _T.assert_true(game.get_node_or_null("PauseLayer/PauseScreen") != null,
		"an InputEventAction pauses the run, not only an InputEventKey")
	if err == "":
		var screen := game.get_node_or_null("PauseLayer/PauseScreen") as PauseScreen
		var resumed: Array[bool] = [false]
		screen.resume_requested.connect(func() -> void: resumed[0] = true)
		screen._input(_action_press(KeyBindings.ACTION_PAUSE))
		err = _T.assert_true(resumed[0], "and closes the card the same way")
	game.resume_run()
	_T.free_ui(game)
	if err == "":
		var notebook := await _T.instantiate_ui(NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
		var page_label: Label = notebook.get_node("PageLabel") as Label
		notebook._input(_action_press(KeyBindings.ACTION_PAGE_NEXT))
		err = _T.assert_eq(page_label.text, "2 / %d" % NotebookScreen.PAGES.size(),
			"and the notebook turns its page on one too")
		_T.free_ui(notebook)
	return err


static func _action_press(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


## The table's own accessors. Small enough to look self-evident, which is exactly
## why they are worth one check: `actions_in` returning the whole table would give
## the pause card the notebook's page keys as well, and `row_for` returning {} for
## a real action would render a legend with no description and no error anywhere.
func test_the_binding_table_answers_about_itself() -> String:
	var run: Array[StringName] = KeyBindings.actions_in(KeyBindings.SCOPE_RUN)
	var notebook: Array[StringName] = KeyBindings.actions_in(KeyBindings.SCOPE_NOTEBOOK)
	var err: String = _T.assert_eq(run.size() + notebook.size(), KeyBindings.actions().size(),
		"every action belongs to exactly one scope")
	if err == "":
		err = _T.assert_true(run.has(KeyBindings.ACTION_PAUSE) and not run.has(KeyBindings.ACTION_PAGE_NEXT),
			"the run's scope is the run's verbs, got %s" % [run])
	if err == "":
		err = _T.assert_true(KeyBindings.is_known(KeyBindings.ACTION_BACK),
			"a declared action is known")
	if err == "":
		err = _T.assert_false(KeyBindings.is_known(&"garden_not_a_verb"), "and an undeclared one is not")
	if err == "":
		err = _T.assert_eq(String(KeyBindings.row_for(KeyBindings.ACTION_RESTART).get("does", "")),
			"start over, once the run is done", "row_for hands back the whole row")
	if err == "":
		err = _T.assert_eq(KeyBindings.row_for(&"garden_not_a_verb"), {},
			"and an unknown action has no row rather than a half-filled one")
	if err == "":
		# The short forms exist because the pause card is 320px wide at font 13.
		err = _T.assert_eq(KeyBindings.key_label(KEY_ESCAPE), "Esc",
			"Escape is shortened for the legend")
	if err == "":
		err = _T.assert_eq(KeyBindings.key_label(KEY_M), "M", "and a key the engine already names briefly is left alone")
	if err == "":
		KeyBindings.reset_all()
		KeyBindings.set_keys(KeyBindings.ACTION_RESTART, [KEY_F5])
		err = _T.assert_true(KeyBindings.reset_action(KeyBindings.ACTION_RESTART), "one row can be reset on its own")
		if err == "":
			err = _T.assert_eq(KeyBindings.keys_for(KeyBindings.ACTION_RESTART), [KEY_R],
				"and it lands back on its shipped key")
	if err == "":
		# The writer's shape, asserted where a reader can see it. `_save` goes
		# through this, so a field appended in the wrong place fails here.
		err = _T.assert_eq(
			RunConfig.compose_save(3, 4, "m0", "cb0 sfx0 mus0 spd0", {"garden_pause": [KEY_F1, KEY_F2]}),
			"v%d\n3\n4\nm0\ncb0 sfx0 mus0 spd0\n1\ngarden_pause %d %d\n" % [RunConfig.SAVE_VERSION, KEY_F1, KEY_F2],
			"compose_save writes the header, both scores, the milestones, the options, "
				+ "the count, then the rows")
	if err == "":
		err = _T.assert_eq(RunConfig.compose_save(0, 0, "m0", "cb0 sfx0 mus0 spd0", {}),
			"v%d\n0\n0\nm0\ncb0 sfx0 mus0 spd0\n0\n" % RunConfig.SAVE_VERSION,
			"and an untouched keyboard is a count of zero, not an absent line")
	KeyBindings.reset_all()
	return err


## The persistence round trip, through the real writer and the real parser. Only
## the moved rows are stored: pinning the defaults into the save would mean a
## later build's better default never reaches a player who never touched that row.
func test_rebound_keys_survive_a_save_and_load() -> String:
	var path := "user://test_selftest_bindings.save"
	var stashed_path: String = RunConfig.save_path
	var stashed_bindings: Dictionary = RunConfig.key_bindings
	var stashed_status: String = RunConfig.load_status
	var stashed_campaign: int = RunConfig.campaign_high_score
	var stashed_endless: int = RunConfig.endless_high_score
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

	RunConfig.save_path = path
	RunConfig.campaign_high_score = 11
	RunConfig.endless_high_score = 22
	# Pinned, not inherited. Every field the writer puts in the file has to be set
	# here or the expected bytes below are a function of the DEVELOPER's own save:
	# `colorblind_safe` is loaded from the real user:// file at startup, so a
	# maintainer who has the accessibility option turned on used to see this test
	# fail with `cb1` against a hardcoded `cb0` — a red test that says nothing
	# about the code. Same reasoning for the milestone set, and for the two mute
	# flags that joined the options line at v6: they are loaded from the same real
	# file, so a maintainer who plays muted would otherwise read `sfx1` here.
	var stashed_colorblind: bool = RunConfig.colorblind_safe
	var stashed_milestones: Dictionary = RunConfig.earned_milestones.duplicate()
	var stashed_mute_sfx: bool = RunConfig.mute_sfx
	var stashed_mute_music: bool = RunConfig.mute_music
	RunConfig.colorblind_safe = false
	RunConfig.earned_milestones = {}
	RunConfig.mute_sfx = false
	RunConfig.mute_music = false
	KeyBindings.reset_all()

	var err: String = _T.assert_eq(KeyBindings.overrides(), {},
		"nothing is stored while every verb is on its shipped key")
	if err == "":
		KeyBindings.set_keys(KeyBindings.ACTION_MUTE_MUSIC, [KEY_F7])
		err = _T.assert_eq(KeyBindings.overrides(), {"garden_mute_music": [KEY_F7]},
			"only the moved row is an override")
	if err == "":
		RunConfig.store_key_bindings(KeyBindings.overrides())
		err = _T.assert_eq(FileAccess.get_file_as_string(path),
			"v%d\n11\n22\nm0\ncb0 sfx0 mus0 spd0 svol0 mvol0\n1\ngarden_mute_music %d\n" % [RunConfig.SAVE_VERSION, KEY_F7],
			"the save carries the count and one action row")
	if err == "":
		# Wipe every trace from memory, then read it all back off disk.
		KeyBindings.reset_all()
		RunConfig.key_bindings = {}
		RunConfig.campaign_high_score = 0
		RunConfig.endless_high_score = 0
		RunConfig._load()
		err = _T.assert_eq(RunConfig.load_status, "loaded", "the file this build wrote is one it reads")
	if err == "":
		err = _T.assert_eq(RunConfig.campaign_high_score, 11, "the scores came back beside the bindings")
	if err == "":
		err = _T.assert_eq(RunConfig.key_bindings, {"garden_mute_music": [KEY_F7]},
			"and the moved row came back exactly")
	if err == "":
		err = _T.assert_eq(KeyBindings.keys_for(KeyBindings.ACTION_MUTE_MUSIC), [KEY_N],
			"_load alone does not touch the live InputMap -- that would rebind the whole test suite")
	if err == "":
		RunConfig.apply_key_bindings()
		err = _T.assert_eq(KeyBindings.keys_for(KeyBindings.ACTION_MUTE_MUSIC), [KEY_F7],
			"applying it is the step that moves the key")
	if err == "":
		err = _T.assert_eq(KeyBindings.keys_for(KeyBindings.ACTION_MUTE_SFX), [KEY_M],
			"and a row the save never mentioned is on its default, not empty")
	if err == "":
		# A save naming a verb this build does not have is a downgrade, not damage:
		# the row is dropped and the two high scores in the same file survive.
		var dropped: Array[String] = KeyBindings.apply_overrides({
			"garden_mute_sfx": [KEY_F8], "garden_from_the_future": [KEY_F9],
		})
		err = _T.assert_eq(dropped, ["garden_from_the_future"], "the unknown verb is the only one declined")
		if err == "":
			err = _T.assert_eq(KeyBindings.keys_for(KeyBindings.ACTION_MUTE_SFX), [KEY_F8],
				"and the known one beside it was still applied")

	KeyBindings.reset_all()
	RunConfig.save_path = stashed_path
	RunConfig.key_bindings = stashed_bindings
	RunConfig.load_status = stashed_status
	RunConfig.campaign_high_score = stashed_campaign
	RunConfig.endless_high_score = stashed_endless
	RunConfig.colorblind_safe = stashed_colorblind
	RunConfig.earned_milestones = stashed_milestones
	RunConfig.mute_sfx = stashed_mute_sfx
	RunConfig.mute_music = stashed_mute_music
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	return err


## The same whole-file rule the scores get. A binding block that does not add up
## is a file this build did not write, and reading the scores out of it anyway is
## how a half-understood save gets adopted.
func test_a_malformed_binding_block_is_refused_like_any_other_bad_save() -> String:
	var path := "user://test_selftest_bad_bindings.save"
	var stashed_path: String = RunConfig.save_path
	var stashed_bindings: Dictionary = RunConfig.key_bindings
	var stashed_status: String = RunConfig.load_status
	var stashed_campaign: int = RunConfig.campaign_high_score
	var stashed_endless: int = RunConfig.endless_high_score
	RunConfig.save_path = path

	var cases: Dictionary = {
		"a count with no rows under it": "v3\n1\n2\n1\n",
		"a count that is not a number": "v3\n1\n2\nlots\n",
		"a row with no keycode": "v3\n1\n2\n1\ngarden_pause\n",
		"a keycode that is not a number": "v3\n1\n2\n1\ngarden_pause escape\n",
		"a keycode of zero": "v3\n1\n2\n1\ngarden_pause 0\n",
		"an action name that is not one": "v3\n1\n2\n1\nGarden-Pause 80\n",
		"the same action twice": "v3\n1\n2\n2\ngarden_pause 80\ngarden_pause 81\n",
		"more rows than the game has verbs": "v3\n1\n2\n999\n",
	}
	var err := ""
	for what: String in cases:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			err = "could not write the scratch save at %s" % path
			break
		f.store_string(String(cases[what]))
		f.close()
		RunConfig.campaign_high_score = 4321
		RunConfig.endless_high_score = 8765
		RunConfig.key_bindings = {}
		RunConfig._load()
		err = _T.assert_eq(RunConfig.load_status, "refused", "%s is refused" % what)
		if err == "":
			err = _T.assert_eq(RunConfig.campaign_high_score, 4321,
				"%s left the campaign record alone" % what)
		if err == "":
			err = _T.assert_eq(RunConfig.endless_high_score, 8765,
				"%s left the endless record alone" % what)
		if err == "":
			err = _T.assert_eq(RunConfig.key_bindings, {}, "%s bound nothing" % what)
		if err != "":
			break

	# A refusal leaves a quarantine pending; clear it or the next _save moves a
	# file this test is about to delete.
	RunConfig._refused_path = ""
	RunConfig.save_path = stashed_path
	RunConfig.key_bindings = stashed_bindings
	RunConfig.load_status = stashed_status
	RunConfig.campaign_high_score = stashed_campaign
	RunConfig.endless_high_score = stashed_endless
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	return err


## resume_run() awaits this before it frees anything — see Game.resume_run.
## Headless never pumps the fade tween, so play_exit must resolve synchronously
## (marking itself closing and returning) rather than leaving the caller
## awaiting a frame nobody will pump.
func test_pause_screen_play_exit_marks_itself_closing_and_is_idempotent() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.pause_run()
	await _pump(game)
	var screen := game.get_node_or_null("PauseLayer/PauseScreen") as PauseScreen
	var err: String = _T.assert_true(screen != null, "the card is up")
	if err == "":
		err = _T.assert_false(screen._closing, "not closing before play_exit runs")
	if err == "":
		screen.play_exit()
		err = _T.assert_true(screen._closing,
			"play_exit marks itself closing synchronously -- headless never reaches its own await")
	if err == "":
		# A second Escape/P landing mid-fade (guarded in _input, but callable
		# directly too) must not restart the fade or error.
		screen.play_exit()
		err = _T.assert_true(screen._closing, "a second call is a no-op, not a second fade")
	if err == "":
		err = _T.assert_true(game.get_node_or_null("PauseLayer/PauseScreen") != null,
			"and play_exit does not free anything itself -- that is resume_run's job")
	game.resume_run()
	_T.free_ui(game)
	return err


func test_the_pause_card_lists_the_keys_and_still_fits_its_paper() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.pause_run()
	await _pump(game)
	var screen: Control = game.get_node_or_null("PauseLayer/PauseScreen") as Control
	var err: String = _T.assert_true(screen != null, "the card is up")
	if err == "":
		err = _T.assert_gt(Game.key_help().size(), 0, "there are bindings to list")
	if err == "":
		for i: int in range(Game.key_help().size()):
			var row: Label = screen.get_node_or_null("KeyRow%d" % i) as Label
			err = _T.assert_true(row != null and not row.text.is_empty(),
				"key row %d is on the card" % i)
			if err != "":
				break
	if err == "":
		# The card grew to carry these; everything must still sit on the paper and
		# nothing may overlap, which is how the note ended up under a button once.
		var card: Control = screen.get_node_or_null("Card") as Control
		var rects: Dictionary = {}
		for child: Node in screen.get_children():
			var control := child as Control
			if control == null or not control.visible or control.name in ["Backdrop", "Card"]:
				continue
			if control.size.x <= 0.0 or control.size.y <= 0.0:
				continue
			err = _T.assert_true(control.global_position.y + control.size.y
					<= card.global_position.y + card.size.y,
				"%s runs past the bottom of the card" % control.name)
			if err != "":
				break
			rects[String(control.name)] = Rect2(control.global_position, control.size)
		if err == "":
			var names: Array = rects.keys()
			for i: int in range(names.size()):
				for j: int in range(i + 1, names.size()):
					err = _T.assert_false((rects[names[i]] as Rect2).intersects(rects[names[j]]),
						"%s overlaps %s" % [names[i], names[j]])
					if err != "":
						break
				if err != "":
					break
	game.resume_run()
	_T.free_ui(game)
	return err


## The legend rows are the widest thing on the pause card, and their text is not
## authored on the card at all -- it comes from KeyBindings.ACTIONS, which also
## feeds the Keys screen and the Options screen. So a phrase can be lengthened for
## one of those two and silently stop fitting this one.
##
## It did: "C   colourblind-safe health and threat bars" drew 326px at x=316 in a
## 264px box, ~34px past a card ending at 608, onto the dimmed backdrop over the
## live board.
##
## Two separate failures let that through, and this test asserts against both.
##
## 1. THE BOX. `Control.set_size` clamps to the combined minimum size, and a
##    Label's minimum width is its whole text until clip_text/overrun is set. The
##    card set `size` before those overrides and before the font size, so the
##    assigned 264 lost to a 326px minimum measured at the theme default 16.
##    Asserted here as "the row's own rect stays on the paper".
##
## 2. THE TEXT. With the box fixed the overflow becomes an ellipsis instead --
##    still a legend that does not say what the key does. Asserted here against
##    PauseScreen.KEY_ROW_MAX_WIDTH.
##
## Neither is expressible with `get_minimum_size()`: clip_text makes it report the
## ~1px clip stub, so `assert(row.get_minimum_size().x <= row.size.x)` passes
## unconditionally on exactly these labels. `_T.text_width` measures through the
## label's own resolved theme font instead.
func test_no_pause_card_legend_row_draws_past_the_paper() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.pause_run()
	await _pump(game)
	var screen: Control = game.get_node_or_null("PauseLayer/PauseScreen") as Control
	var err: String = _T.assert_true(screen != null, "the card is up")
	if err != "":
		_T.free_ui(game)
		return err

	var card: Control = screen.get_node_or_null("Card") as Control
	err = _T.assert_true(card != null, "the card has paper to measure against")
	if err != "":
		game.resume_run()
		_T.free_ui(game)
		return err
	var paper_right: float = card.global_position.x + card.size.x

	var rows: int = Game.key_help().size()
	err = _T.assert_gt(rows, 0, "there are legend rows to measure")
	# BOTH columns. A row is two Labels now -- the key and the phrase were one string
	# sharing one budget, which is what let a long key push the phrase off the card,
	# and measuring only the node still called KeyRow%d would now measure the key
	# alone and stop watching the half that broke.
	for i: int in range(rows):
		if err != "":
			break
		for node_name: String in ["KeyRow%d" % i, "KeyRowDoes%d" % i]:
			var row: Label = screen.get_node_or_null(node_name) as Label
			err = _T.assert_true(row != null, "%s is on the card" % node_name)
			if err != "":
				break
			# (1) the box. A row whose Label won its own width back is already off the
			# paper whatever the text says.
			var right: float = row.global_position.x + row.size.x
			err = _T.assert_true(right <= paper_right + 0.5,
				"%s's box ends at %.0f, the paper ends at %.0f -- the assigned width lost to the Label's minimum size (set clip_text and font_size BEFORE size)"
					% [node_name, right, paper_right])
			if err != "":
				break
			# (2) the text, measured through the font rather than through a
			# get_minimum_size() that clip_text has already reduced to a stub.
			var drawn: float = _T.text_width(row)
			err = _T.assert_gt(drawn, 0.0, "%s has text to measure" % node_name)
			if err != "":
				break
			err = _T.assert_true(drawn <= row.size.x + 0.5,
				"%s draws %.0fpx in its own %.0fpx column -- each column is sized from its own content now, so this means the derivation and the layout disagree (%s)"
					% [node_name, drawn, row.size.x, row.text])

	game.resume_run()
	_T.free_ui(game)
	return err


## The same budget, against a key the PLAYER chose rather than the one we shipped
## (plant-tower-defense-50s).
##
## The test above measures the legend as built, and every row it measures carries a
## shipped key — `Esc`, `M`, `P`. But a legend row is `"%s   %s" % [keys, does]`, and
## since the Keys screen landed the first half is a player's choice: `capture()` binds
## whatever keycode arrives, so "Print Screen" and the media keys are as bindable as
## `P`. The card's width was measured against the `does` phrases and nothing has ever
## varied the other half. That is the same shape as the defect the header above
## describes — a phrase authored somewhere else quietly stops fitting here — with the
## author being the player rather than KeyBindings.ACTIONS.
##
## The worst key is DERIVED from the engine's own naming, not picked. A hand-chosen
## "long key" is a guess that ages the moment Godot renames anything, and the point of
## the sweep is that it re-answers "what is the longest label there is" every run.
func test_the_pause_legend_survives_the_longest_key_a_player_can_bind() -> String:
	var stashed_bindings: Dictionary = RunConfig.key_bindings
	RunConfig.key_bindings = {}
	KeyBindings.reset_all()

	# Every code the engine is willing to name: the printable range, then the special
	# block (KEY_SPECIAL is 1 << 22). Ones it does not name come back "".
	var worst_code: int = 0
	var worst_label: String = ""
	var named: int = 0
	for code: int in range(32, 127):
		var label: String = OS.get_keycode_string(code)
		if label.is_empty():
			continue
		named += 1
		if label.length() > worst_label.length():
			worst_label = label
			worst_code = code
	for code: int in range(1 << 22, (1 << 22) + 512):
		var label: String = OS.get_keycode_string(code)
		if label.is_empty():
			continue
		named += 1
		if label.length() > worst_label.length():
			worst_label = label
			worst_code = code

	var err: String = _T.assert_gt(named, 100,
		"the sweep found keys to measure -- a near-empty sweep makes every assertion "
			+ "below vacuous, and get_keycode_string() returning \"\" for everything is "
			+ "exactly what a renamed enum looks like")
	if err == "":
		err = _T.assert_gt(worst_label.length(), 4,
			"and the longest of them is actually long, got: %s" % worst_label)
	if err == "":
		# Bind it to the verb whose phrase is already the widest, so the row under test
		# is the worst case in both halves at once rather than in one.
		var widest: StringName = KeyBindings.actions()[0]
		for action: StringName in KeyBindings.actions():
			if KeyBindings.describe(action).length() > KeyBindings.describe(widest).length():
				widest = action
		err = _T.assert_true(KeyBindings.set_keys(widest, [worst_code]),
			"the longest key name (%s) binds to the widest verb (%s)"
				% [worst_label, KeyBindings.describe(widest)])

	if err == "":
		var worst_game := await _T.instantiate_scene(GAME_SCENE) as Game
		worst_game.pause_run()
		await _pump(worst_game)
		var worst_screen: Control = worst_game.get_node_or_null("PauseLayer/PauseScreen") as Control
		err = _T.assert_true(worst_screen != null, "the card is up")
		if err == "":
			var rows: int = Game.key_help().size()
			err = _T.assert_gt(rows, 0, "there are legend rows to measure")
			for i: int in range(rows):
				if err != "":
					break
				for node_name: String in ["KeyRow%d" % i, "KeyRowDoes%d" % i]:
					var row: Label = worst_screen.get_node_or_null(node_name) as Label
					err = _T.assert_true(row != null, "%s is on the card" % node_name)
					if err != "":
						break
					err = _T.assert_true(_T.text_width(row) <= row.size.x + 0.5,
						"%s draws %.0fpx in its own %.0fpx column once a player binds the longest key there is -- the card is sized from these columns, so this is the derivation failing rather than a phrase being too long (%s)"
							% [node_name, _T.text_width(row), row.size.x, row.text])
					if err != "":
						break
		worst_game.resume_run()
		_T.free_ui(worst_game)

	KeyBindings.reset_all()
	RunConfig.key_bindings = stashed_bindings
	return err


## The pause card sizes itself to what it holds. It used to derive where its
## content starts and hard-code where it must stop: content ended at 370 against a
## written 380, and a fourth button or key row spent that silently, putting text
## onto the backdrop over the live board while overlapping nothing -- so no gate
## would fire.
func test_the_pause_card_is_tall_enough_for_whatever_it_holds() -> String:
	var rect: Rect2 = PauseScreen.card_rect()
	var content: float = PauseScreen.content_height()
	var err: String = _T.assert_gt(content, 0.0, "the card has content to size for")
	if err == "":
		err = _T.assert_true(rect.size.y >= content,
			"the card (%.0f) is at least as tall as its content (%.0f)" % [rect.size.y, content])
	if err == "":
		err = _T.assert_true(rect.position.y + rect.size.y <= 648.0,
			"and still fits the viewport, foot at %.0f" % [rect.position.y + rect.size.y])
	if err == "":
		# The real claim: adding a row must move the card, not overflow it. The old
		# constant could not respond to this at all.
		var before: float = PauseScreen.card_rect().size.y
		var grown: float = before + PauseScreen.KEY_ROW_HEIGHT
		err = _T.assert_true(grown > before,
			"a fourth key row would need %0.f, and the card is derived so it gets it" % grown)
	return err


## A record set by leaving must be announced somewhere. _end_run hands
## record_score's return to the post-mortem; the pause exits drop it, so without
## this the run a player was proudest of said nothing at all.
func test_a_record_set_by_quitting_is_announced_on_the_title_screen() -> String:
	# Redirected before the first mutator, not merely restored after it. This test
	# stages both scores to 0 and then records 140, and record_score() persists --
	# so against the real save_path it wrote 140 over a player's actual record. The
	# in-memory restore below is what made that invisible: the numbers came back,
	# the FILE kept 140, and nothing failed.
	var stashed_path: String = RunConfig.save_path
	RunConfig.save_path = "user://test_selftest_record.save"
	var saved_c: int = RunConfig.campaign_high_score
	var saved_e: int = RunConfig.endless_high_score
	var saved_f: bool = RunConfig.fresh_record
	var saved_mode: bool = RunConfig.endless
	RunConfig.campaign_high_score = 0
	RunConfig.endless_high_score = 0
	RunConfig.fresh_record = false
	RunConfig.endless = false

	var err: String = _T.assert_false(TitleScreen.high_score_text().contains("just now"),
		"a screen with no fresh record says nothing about one")
	if err == "":
		err = _T.assert_true(RunConfig.record_score(140), "the run set a record")
	if err == "":
		err = _T.assert_true(RunConfig.fresh_record, "and the flag was raised")
	if err == "":
		err = _T.assert_true(TitleScreen.high_score_text().contains("just now"),
			"so the title line marks it, got: %s" % TitleScreen.high_score_text())
	if err == "":
		# Pure builder: calling it twice must not change the answer, because the
		# screen clears the flag, not the text.
		err = _T.assert_eq(TitleScreen.high_score_text(), TitleScreen.high_score_text(),
			"the builder is pure and does not consume the flag itself")
	if err == "":
		# A run that beat nothing raises no flag.
		RunConfig.fresh_record = false
		err = _T.assert_false(RunConfig.record_score(10), "a worse run is not a record")
		if err == "":
			err = _T.assert_false(RunConfig.fresh_record, "and raises no flag")

	RunConfig.campaign_high_score = saved_c
	RunConfig.endless_high_score = saved_e
	RunConfig.fresh_record = saved_f
	RunConfig.endless = saved_mode
	RunConfig.save_path = stashed_path
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists("user://test_selftest_record.save" + suffix):
			DirAccess.remove_absolute("user://test_selftest_record.save" + suffix)
	return err


## Where the two palettes live, read as text rather than through their symbols:
## the point of the checks below is what the *source* declares, and a value
## reached through its name has already lost that distinction.
const HUD_SOURCE := "res://game/hud.gd"
const GARDEN_THEME_SOURCE := "res://game/garden_theme.gd"


## Every Color constant a script declares, by name. Loaded from the path rather
## than off `Hud` / `GardenTheme` so the map is the file's, not the symbol's.
func _colour_constants(script_path: String) -> Dictionary:
	var colours: Dictionary = {}
	var script: GDScript = load(script_path) as GDScript
	if script == null:
		return colours
	var declared: Dictionary = script.get_script_constant_map()
	for const_name: String in declared:
		var value: Variant = declared[const_name]
		if typeof(value) == TYPE_COLOR:
			colours[const_name] = value as Color
	return colours


## The line a constant is declared on, so a check can tell an alias
## (`const X := GardenTheme.Y`) from a second copy (`const X := Color(...)`).
func _declaration_line(source: String, const_name: String) -> String:
	for line: String in source.split("\n"):
		if line.strip_edges().begins_with("const %s " % const_name):
			return line.strip_edges()
	return ""


## Two palettes, one game -- and after this, no colour value written down twice.
##
## Structural on purpose, because names are exactly what cannot be trusted here:
## UPROOT_ARMED, THREAT_HOT and HEALTH_LOW are three names for one red and always
## were, so a check comparing names would have called that healthy while the value
## sat in the tree four times over. This compares the actual Color values in both
## constant maps and then asks the source whether each collision is an alias (a
## Hud const naming GardenTheme) or a copy (a hand-typed literal). Only the first
## is allowed -- which is what makes it survive someone pasting a shade back into
## hud.gd next cycle, the exact way the duplication arrived the first time.
func test_no_colour_value_is_declared_twice_across_the_palettes() -> String:
	var hud_src: String = FileAccess.get_file_as_string(HUD_SOURCE)
	var hud_colours: Dictionary = _colour_constants(HUD_SOURCE)
	var theme_colours: Dictionary = _colour_constants(GARDEN_THEME_SOURCE)
	var err: String = _T.assert_false(hud_src.is_empty(), "hud.gd reads back as text")
	if err == "":
		err = _T.assert_gt(theme_colours.size(), 0, "GardenTheme declares colours to share")
	if err == "":
		err = _T.assert_gt(hud_colours.size(), 0, "and the HUD names some of its own")
	if err != "":
		return err

	# Across the two classes.
	var aliases: int = 0
	for hud_name: String in hud_colours:
		var line: String = _declaration_line(hud_src, hud_name)
		for theme_name: String in theme_colours:
			if not (hud_colours[hud_name] as Color).is_equal_approx(theme_colours[theme_name] as Color):
				continue
			aliases += 1
			err = _T.assert_true(line.contains("GardenTheme"),
				"Hud.%s IS GardenTheme.%s by value, so it must say so rather than re-declare it; got `%s`"
					% [hud_name, theme_name, line])
			if err != "":
				return err

	# And within the HUD's own block, which is where the three reds sat. This half
	# still fails if GardenTheme.DANGER is deleted and hud.gd goes back to three
	# identical literals, so the check does not lean on the shared file existing.
	var names: Array = hud_colours.keys()
	var internal: int = 0
	for i: int in range(names.size()):
		for j: int in range(i + 1, names.size()):
			var a: String = String(names[i])
			var b: String = String(names[j])
			if not (hud_colours[a] as Color).is_equal_approx(hud_colours[b] as Color):
				continue
			internal += 1
			err = _T.assert_true(
				_declaration_line(hud_src, a).contains("GardenTheme")
					and _declaration_line(hud_src, b).contains("GardenTheme"),
				"Hud.%s and Hud.%s are one colour, so both must alias the single place it is declared" % [a, b])
			if err != "":
				return err

	if err == "":
		# Vacuity guard, and the reason it is a floor rather than a comment: the
		# loops above pass trivially the moment the two files share nothing at all,
		# and an empty intersection is not a merged palette -- it is a broken alias.
		# INK, PAPER, PAPER_DARK, LEAF, COMPOST, UPROOT_ARMED, THREAT_WARM,
		# THREAT_HOT, HEALTH_FULL and HEALTH_LOW are ten shared values.
		err = _T.assert_gte(aliases, 10,
			"the HUD actually reaches the shared palette, %d value(s) matched" % aliases)
	if err == "":
		err = _T.assert_gte(internal, 3,
			"and the three reds still collide inside the HUD, %d pair(s) found" % internal)
	return err


## The names are the design intent, and the merge must not cost them.
##
## `UPROOT_ARMED`, `THREAT_HOT` and `HEALTH_LOW` are one red under three names on
## purpose: each says which decision the colour is reporting, which is knowledge a
## bare `DANGER` at the call site would throw away. So the requirement is not "one
## constant" but "one value, three names", and that is what this asserts.
func test_the_huds_semantic_colour_names_survive_the_merge() -> String:
	var hud_colours: Dictionary = _colour_constants(HUD_SOURCE)
	var wanted: Array[String] = [
		"INK", "PAPER", "PAPER_DARK", "LEAF", "COMPOST",
		"UPROOT_ARMED", "THREAT_WARM", "THREAT_HOT",
		"HEALTH_BACK", "HEALTH_FULL", "HEALTH_LOW",
	]
	var err: String = ""
	for const_name: String in wanted:
		err = _T.assert_true(hud_colours.has(const_name), "Hud still names %s" % const_name)
		if err != "":
			return err

	if err == "":
		err = _T.assert_true(Hud.UPROOT_ARMED.is_equal_approx(Hud.THREAT_HOT),
			"an armed Uproot and a runaway threat are the same red")
	if err == "":
		err = _T.assert_true(Hud.THREAT_HOT.is_equal_approx(Hud.HEALTH_LOW),
			"and so is a plant nearly chewed through")
	if err == "":
		err = _T.assert_true(Hud.HEALTH_LOW.is_equal_approx(GardenTheme.DANGER),
			"all three being the one red the rest of the game can now reach")
	if err == "":
		err = _T.assert_true(Hud.HEALTH_FULL.is_equal_approx(GardenTheme.LEAF),
			"a healthy plant is the palette's leaf green")
	if err == "":
		err = _T.assert_true(Hud.THREAT_WARM.is_equal_approx(GardenTheme.AMBER),
			"and the ramp's midpoint is the shared amber")
	if err == "":
		# The one derived value: same ink, different alpha. Comparing the channels
		# rather than the Color is what makes it a derivation instead of a copy --
		# a retyped literal would satisfy `is_equal_approx` just as happily.
		var back: Color = Hud.HEALTH_BACK
		err = _T.assert_true(Color(back.r, back.g, back.b).is_equal_approx(GardenTheme.INK),
			"the health bar's backing is INK, got %s" % back)
	if err == "":
		err = _T.assert_float_eq(Hud.HEALTH_BACK.a, 0.35, 0.001,
			"washed back by alpha alone")
	return err


## The half of the old split that was right, pinned so the merge cannot creep.
##
## Sharing colour constants is not the same as wearing `GardenTheme.build()`, and
## the HUD's refusal of that Theme is deliberate: it builds and sizes every Control
## it owns in code, and a Theme at the root would restyle its Buttons out from
## under that layout. Nothing about a Theme quietly appearing throws an error, so
## the only thing keeping this true is a check that reads it off the live tree.
func test_the_hud_still_refuses_the_shared_theme() -> String:
	# Comments stripped first. The scan matched the very comment explaining why the
	# HUD refuses that Theme -- a mention counted as a use, which is the same trap
	# tools/name_check.py and tools/meta_key_check.py both blank comments to avoid.
	# A source scan that reads prose is a scan that punishes documentation.
	var hud_src: String = _code_only(FileAccess.get_file_as_string(HUD_SOURCE))
	var err: String = _T.assert_false(hud_src.contains("GardenTheme.build"),
		"hud.gd never asks for the shared Theme")
	if err != "":
		return err
	# The Theme it declines is real and would have restyled the Buttons. Without
	# this, every assertion below would pass just as well against an empty Theme.
	var built: Theme = GardenTheme.build()
	err = _T.assert_true(built.has_stylebox("normal", "Button"),
		"and the Theme it declines is one that would repaint every Button")
	if err != "":
		return err

	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var root: Control = game.hud.get_node_or_null("Root") as Control
	err = _T.assert_true(root != null, "the HUD root is where the bar puts it")
	if err == "":
		err = _T.assert_true(root.theme == null, "and wears no Theme of its own")
	if err == "":
		var controls: Array[Node] = root.find_children("*", "Control", true, false)
		err = _T.assert_gt(controls.size(), 0, "the HUD built Controls to check")
		if err == "":
			for node: Node in controls:
				var control := node as Control
				err = _T.assert_true(control.theme == null,
					"%s carries no Theme either" % control.name)
				if err != "":
					break
	if err == "":
		# The positive half: the palette IS shared, so a merge that quietly stopped
		# aliasing could not pass this simply by sharing nothing at all.
		err = _T.assert_true(Hud.INK.is_equal_approx(GardenTheme.INK),
			"while still painting out of the same jar")
	_T.free_ui(game)
	return err


## Strips comments from GDScript source so a source scan cannot be tripped by
## prose. Naive on purpose -- it does not understand a `#` inside a string
## literal -- but every caller here searches for an identifier, and an identifier
## quoted inside a string is a mention too. `tools/name_check.py` does the
## length-preserving version of this for the same reason.
func _code_only(src: String) -> String:
	var out: PackedStringArray = []
	for line: String in src.split("\n"):
		var hash_at: int = line.find("#")
		out.append(line if hash_at < 0 else line.substr(0, hash_at))
	return "\n".join(out)


# -- the notebook, reachable mid-run (plant-tower-defense-899) ---------------
#
# NotebookScreen was constructed in exactly one place -- TitleScreen._open_notebook
# -- and nothing in game.gd, hud.gd or pause_screen.gd could reach it, so the only
# account the game gives of itself was shut from the first frame of a run onwards.
# The pause card is now its second door, which puts it behind `get_tree().paused`
# and into a collision with the card's own Escape handler. These four checks are
# about that, not about the button.


## Opens the notebook the way a player does -- through the button's own signal.
## Calling PauseScreen._open_notebook() directly would pass just as happily with
## nothing wired to the button at all, which is the failure this whole issue is.
func _open_pause_notebook(screen: PauseScreen) -> String:
	var button: Button = screen.get_node_or_null("NotebookButton") as Button
	var err: String = _T.assert_true(button != null,
		"the pause card offers a way into the notebook")
	if err == "":
		err = _T.assert_false(button.disabled, "and the way in is not disabled")
	if err == "":
		button.pressed.emit()
	return err


func test_the_notebook_opens_from_the_pause_card_and_the_run_stays_held() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	# Guard against a vacuous pass twice over: the table below drives both the card's
	# layout and the loops in the two tests after this one, and the notebook has to
	# have pages for "opened it" to mean anything.
	var err: String = _T.assert_gt(PauseScreen.BUTTONS.size(), 0, "the card has buttons to press")
	if err == "":
		err = _T.assert_gt(NotebookScreen.PAGES.size(), 0, "and the notebook has pages to read")
	if err == "":
		game.pause_run()
		await _pump(game)
		err = _T.assert_true(game.is_paused(), "the run is held before the notebook is asked for")
	var screen := game.get_node_or_null("PauseLayer/PauseScreen") as PauseScreen
	if err == "":
		err = _T.assert_true(screen != null, "and the pause card is up")
	if err == "":
		err = _open_pause_notebook(screen)
	if err == "":
		await _pump(game)
		err = _T.assert_true(screen.notebook_open(), "pressing the button opens the notebook")
	if err == "":
		err = _T.assert_true(screen.get_node_or_null("Notebook") is NotebookScreen,
			"and it is really on the card, not merely flagged open")
	if err == "":
		# The whole point of opening it from here: the run must not have restarted
		# behind the paper.
		err = _T.assert_true(game.is_paused(), "and the run is STILL held with it open")
	if err == "":
		# One notebook at a time, the same claim
		# test_opening_the_notebook_takes_focus_away_from_the_menu_behind_it makes of
		# the title screen's copy.
		err = _open_pause_notebook(screen)
		if err == "":
			await _pump(game)
			err = _T.assert_eq(screen.get_children().filter(
				func(child: Node) -> bool: return child is NotebookScreen).size(), 1,
				"pressing it twice does not stack two notebooks")
	game.resume_run()
	await _pump(game)
	_T.free_ui(game)
	return err


## Closing it must hand the card back, not the board -- and hand it back working.
## A card left inert behind a freed overlay is a pause menu with no way out of it,
## which is the same class of bug PROCESS_MODE_ALWAYS exists to prevent.
func test_closing_the_notebook_gives_the_pause_card_back_still_paused() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.pause_run()
	await _pump(game)
	var screen := game.get_node_or_null("PauseLayer/PauseScreen") as PauseScreen
	var err: String = _T.assert_true(screen != null, "the pause card is up")
	if err == "":
		err = _open_pause_notebook(screen)
	if err == "":
		await _pump(game)
		err = _T.assert_true(screen.notebook_open(), "the notebook is open to close")
	if err == "":
		# While it is up, nothing underneath may still take focus or hover: the
		# backdrop swallows clicks, but Tab would otherwise walk onto "Start over"
		# behind the paper.
		for spec: Dictionary in PauseScreen.BUTTONS:
			var b: Button = screen.get_node_or_null(String(spec["name"])) as Button
			# Null-checked before it is read: a nil dereference aborts the method and
			# returns "" for a -> String test, which is indistinguishable from a pass.
			err = _T.assert_true(b != null, "%s is on the card" % String(spec["name"]))
			if err == "":
				err = _T.assert_eq(b.focus_mode, Control.FOCUS_NONE,
					"%s cannot be tabbed to under the notebook" % String(spec["name"]))
			if err == "":
				err = _T.assert_eq(b.mouse_filter, Control.MOUSE_FILTER_IGNORE,
					"%s cannot light up under the notebook either" % String(spec["name"]))
			if err != "":
				break
	if err == "":
		var back: Button = screen.get_node("Notebook/BackButton") as Button
		back.pressed.emit()
		await _pump(game)
		err = _T.assert_false(screen.notebook_open(), "Back closes the notebook")
	if err == "":
		err = _T.assert_true(game.is_paused(), "and leaves the run held")
	if err == "":
		err = _T.assert_true(game.get_node_or_null("PauseLayer/PauseScreen") != null,
			"with the pause card still the thing on screen")
	if err == "":
		for spec: Dictionary in PauseScreen.BUTTONS:
			var b: Button = screen.get_node_or_null(String(spec["name"])) as Button
			err = _T.assert_true(b != null, "%s survived the notebook" % String(spec["name"]))
			if err == "":
				err = _T.assert_eq(b.focus_mode, Control.FOCUS_ALL,
					"%s takes focus again" % String(spec["name"]))
			if err == "":
				err = _T.assert_eq(b.mouse_filter, Control.MOUSE_FILTER_STOP,
					"%s takes the mouse again" % String(spec["name"]))
			if err != "":
				break
	if err == "":
		# The restored properties are only a description of a working button. This is
		# the button working: Resume still resumes after a notebook has been over it.
		(screen.get_node("ResumeButton") as Button).pressed.emit()
		await _pump(game)
		err = _T.assert_false(game.is_paused(), "and Resume still resumes the run")
	game.resume_run()
	await _pump(game)
	_T.free_ui(game)
	return err


## Escape is handled by BOTH screens: NotebookScreen._input emits back_requested,
## PauseScreen._input emits resume_requested. Unresolved, one keystroke closes the
## notebook and drops the player onto a live board in the same frame.
##
## Driven by calling the two _input handlers directly, in the order the engine
## would, rather than trusting the engine to stop after the first. That ordering is
## the thing under test: relying on it silently is how this breaks, so the check has
## to be able to see the second handler decline on its own.
func test_escape_in_the_notebook_closes_it_without_unpausing_the_run() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.pause_run()
	await _pump(game)
	var screen := game.get_node_or_null("PauseLayer/PauseScreen") as PauseScreen
	var err: String = _T.assert_true(screen != null, "the pause card is up")
	if err == "":
		err = _open_pause_notebook(screen)
	if err == "":
		await _pump(game)
		err = _T.assert_true(screen.notebook_open(), "the notebook is open")
	if err == "":
		var notebook := screen.get_node("Notebook") as NotebookScreen
		# Both handlers, back to back with nothing pumped in between: this is the one
		# frame the collision lives in, and the card has to decline inside it.
		notebook._input(_key_press(KEY_ESCAPE))
		screen._input(_key_press(KEY_ESCAPE))
		err = _T.assert_true(game.is_paused(),
			"the card declines the Escape the notebook just answered, rather than "
				+ "resuming the run behind it in the same keystroke")
	if err == "":
		await _pump(game)
		err = _T.assert_false(screen.notebook_open(), "and the Escape did close the notebook")
	if err == "":
		err = _T.assert_true(game.is_paused(), "with the run still held once it is gone")
	if err == "":
		err = _T.assert_true(game.get_node_or_null("PauseLayer/PauseScreen") != null,
			"the pause card is what Escape returns to")
	if err == "":
		# The other half of the collision, and the half tree order would not have
		# covered: P is a resume key the notebook does not handle at all, so with the
		# notebook up it would reach the card unopposed.
		err = _open_pause_notebook(screen)
		if err == "":
			await _pump(game)
			screen._input(_key_press(KEY_P))
			err = _T.assert_true(game.is_paused(), "P over an open notebook does not unpause either")
		if err == "":
			err = _T.assert_true(screen.notebook_open(), "and leaves the notebook where it was")
	if err == "":
		# And with nothing over it, the card's own Escape still works -- or the guard
		# above would pass by breaking the pause menu instead of fixing it, and every
		# assertion here would still be green with Escape doing nothing at all.
		(screen.get_node("Notebook") as NotebookScreen)._input(_key_press(KEY_ESCAPE))
		await _pump(game)
		err = _T.assert_false(screen.notebook_open(), "the notebook is out of the way again")
		if err == "":
			screen._input(_key_press(KEY_ESCAPE))
			await _pump(game)
			err = _T.assert_false(game.is_paused(), "Escape on the bare pause card still resumes")
	game.resume_run()
	await _pump(game)
	_T.free_ui(game)
	return err


## A notebook opened from a pause inherits that pause's problem: everything the
## player can see is on a frozen tree. Without PROCESS_MODE_ALWAYS its Back, Prev
## and Next buttons are dead and its page-turn tween never advances -- a reader the
## player cannot page or close, over a game they cannot get back to.
func test_the_notebook_over_a_pause_is_not_frozen_by_the_pause_that_owns_it() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.pause_run()
	await _pump(game)
	var screen := game.get_node_or_null("PauseLayer/PauseScreen") as PauseScreen
	var err: String = _T.assert_true(screen != null, "the pause card is up")
	if err == "":
		err = _open_pause_notebook(screen)
	var notebook: NotebookScreen = null
	if err == "":
		await _pump(game)
		notebook = screen.get_node_or_null("Notebook") as NotebookScreen
		err = _T.assert_true(notebook != null, "the notebook is up")
	if err == "":
		# Asserted the same way test_the_pause_card_keeps_processing_... asserts it of
		# the card: the declared mode, not an inherited one. PROCESS_MODE_INHERIT
		# would resolve to ALWAYS today and to FROZEN the day this is reparented.
		err = _T.assert_eq(notebook.process_mode, Node.PROCESS_MODE_ALWAYS,
			"the notebook runs while the tree it was opened from is paused")
	if err == "":
		# The property is the declaration; this is the engine's own answer to it,
		# read while the tree really is paused.
		err = _T.assert_true(game.is_paused(), "the tree is genuinely paused for this to mean anything")
		if err == "":
			err = _T.assert_true(notebook.can_process(),
				"and the engine agrees the notebook still processes")
	if err == "":
		for node_name: String in ["BackButton", "PrevButton", "NextButton"]:
			var b: Button = notebook.get_node_or_null(node_name) as Button
			err = _T.assert_true(b != null and not b.disabled,
				"%s is present and clickable while paused" % node_name)
			if err == "":
				err = _T.assert_true(b.can_process(), "%s is not frozen by the pause" % node_name)
			if err != "":
				break
	if err == "":
		# And it actually turns: a page-turn driven through the live button, on a
		# paused tree, has to land on the next page rather than stall on the tween.
		var page_label: Label = notebook.get_node("PageLabel") as Label
		var before: String = page_label.text
		(notebook.get_node("NextButton") as Button).pressed.emit()
		await _pump(game)
		err = _T.assert_false(page_label.text == before,
			"Next turns the page while the run is paused (still on %s)" % before)
	game.resume_run()
	await _pump(game)
	_T.free_ui(game)
	return err


# -- The Keys screen, from inside a run (plant-tower-defense-ac0) ------------
#
# KeyBindingScreen was built in exactly one place -- TitleScreen._open_keys --
# so the player who most wants to move a key, the one who just pressed the
# wrong one mid-run, had to throw the run away to reach it. The pause card is
# its second door, which puts it behind get_tree().paused and into the same
# Escape collision the notebook is in, and grows the card that opens it.


## Opens it the way a player does -- through the button's own signal. Calling
## PauseScreen._open_keys() directly would pass just as happily with nothing wired
## to the button, which is the failure this whole issue is.
func _open_pause_keys(screen: PauseScreen) -> String:
	var button: Button = screen.get_node_or_null("KeysButton") as Button
	var err: String = _T.assert_true(button != null,
		"the pause card offers a way into the keys screen")
	if err == "":
		err = _T.assert_false(button.disabled, "and the way in is not disabled")
	if err == "":
		err = _T.assert_true(button.size.x >= 40.0 and button.size.y >= 40.0,
			"and it is a real touch target, got %s" % button.size)
	if err == "":
		button.pressed.emit()
	return err


func test_the_keys_screen_opens_from_the_pause_card_and_the_run_stays_held() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	# Guarded against a vacuous pass: the loops below walk this table, and an empty
	# one would report a confident green over a card with no buttons at all.
	var err: String = _T.assert_gt(PauseScreen.BUTTONS.size(), 0, "the card has buttons to press")
	if err == "":
		err = _T.assert_gt(KeyBindings.actions().size(), 0, "and there are verbs to rebind")
	if err == "":
		game.pause_run()
		await _pump(game)
		err = _T.assert_true(game.is_paused(), "the run is held before the keys screen is asked for")
	var screen := game.get_node_or_null("PauseLayer/PauseScreen") as PauseScreen
	if err == "":
		err = _T.assert_true(screen != null, "and the pause card is up")
	# The button emits `keys_requested` and this screen answers it itself, the same
	# arrangement NotebookButton has. Watched here so the table row and the handler
	# are asserted separately: a button wired straight to _open_keys would still
	# open the screen while leaving the declared signal dead.
	var asked: Array[bool] = [false]
	if err == "":
		screen.keys_requested.connect(func() -> void: asked[0] = true)
		err = _open_pause_keys(screen)
	if err == "":
		err = _T.assert_true(asked[0], "the button asks for the keys screen by signal")
	if err == "":
		await _pump(game)
		err = _T.assert_true(screen.keys_open(), "pressing the button opens the keys screen")
	var keys: KeyBindingScreen = null
	if err == "":
		keys = screen.get_node_or_null(KeyBindingScreen.NODE_NAME) as KeyBindingScreen
		err = _T.assert_true(keys != null,
			"and it is really on the card, not merely flagged open")
	if err == "":
		err = _T.assert_true(game.is_paused(), "and the run is STILL held with it open")
	if err == "":
		# Stated, not inherited. It resolves to ALWAYS today because the card is
		# ALWAYS; the day this is reparented to a CanvasLayer for z-order, INHERIT
		# would silently freeze it -- a rebinding screen with dead buttons over a game
		# the player cannot get back to.
		err = _T.assert_eq(keys.process_mode, Node.PROCESS_MODE_ALWAYS,
			"the keys screen runs while the tree it was opened from is paused")
	if err == "":
		# The declaration is one thing; this is the engine agreeing, while the tree
		# really is paused.
		err = _T.assert_true(keys.can_process(), "and the engine agrees it still processes")
	if err == "":
		for node_name: String in ["BackButton", "ResetButton", "RowButton0"]:
			var b: Button = keys.get_node_or_null(node_name) as Button
			err = _T.assert_true(b != null and not b.disabled,
				"%s is present and clickable while paused" % node_name)
			if err == "":
				err = _T.assert_true(b.can_process(), "%s is not frozen by the pause" % node_name)
			if err != "":
				break
	if err == "":
		# One overlay at a time, and the SECOND overlay is the half only two of them
		# can be wrong about: the notebook must not open on top of it either.
		err = _open_pause_keys(screen)
		if err == "":
			await _pump(game)
			err = _T.assert_eq(screen.get_children().filter(
				func(child: Node) -> bool: return child is KeyBindingScreen).size(), 1,
				"pressing it twice does not stack two keys screens")
	if err == "":
		screen._open_notebook()
		await _pump(game)
		err = _T.assert_false(screen.notebook_open(),
			"and the notebook cannot open on top of the keys screen")
	game.resume_run()
	await _pump(game)
	_T.free_ui(game)
	return err


## Escape is answered by BOTH screens: KeyBindingScreen._input emits
## back_requested, PauseScreen._input emits resume_requested. Unresolved, one
## keystroke closes the keys screen AND drops the player onto a live board.
##
## Driven by calling the two handlers directly, in the order the engine would,
## because that ordering is the thing under test -- and because pumping a frame
## between them hides the mid-event close entirely.
func test_escape_in_the_keys_screen_closes_it_without_unpausing_the_run() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.pause_run()
	await _pump(game)
	var screen := game.get_node_or_null("PauseLayer/PauseScreen") as PauseScreen
	var err: String = _T.assert_true(screen != null, "the pause card is up")
	if err == "":
		err = _open_pause_keys(screen)
	if err == "":
		await _pump(game)
		err = _T.assert_true(screen.keys_open(), "the keys screen is open")
	if err == "":
		var keys := screen.get_node(KeyBindingScreen.NODE_NAME) as KeyBindingScreen
		keys._input(_key_press(KEY_ESCAPE))
		screen._input(_key_press(KEY_ESCAPE))
		err = _T.assert_true(game.is_paused(),
			"the card declines the Escape the keys screen just answered, rather than "
				+ "resuming the run behind it in the same keystroke")
	if err == "":
		await _pump(game)
		err = _T.assert_false(screen.keys_open(), "and the Escape did close the keys screen")
	if err == "":
		err = _T.assert_true(game.is_paused(), "with the run still held once it is gone")
	if err == "":
		# The half tree order does not cover: P is a resume key the keys screen does
		# not handle at all, so with it up P would reach the card unopposed.
		err = _open_pause_keys(screen)
		if err == "":
			await _pump(game)
			screen._input(_key_press(KEY_P))
			err = _T.assert_true(game.is_paused(), "P over an open keys screen does not unpause")
		if err == "":
			err = _T.assert_true(screen.keys_open(), "and leaves the keys screen where it was")
	if err == "":
		# And with nothing over it the card's own Escape still works -- or the guard
		# above would pass by breaking the pause menu, with every assertion still green.
		(screen.get_node(KeyBindingScreen.NODE_NAME) as KeyBindingScreen)._input(_key_press(KEY_ESCAPE))
		await _pump(game)
		err = _T.assert_false(screen.keys_open(), "the keys screen is out of the way again")
		if err == "":
			err = _T.assert_eq((screen.get_node("ResumeButton") as Button).focus_mode,
				Control.FOCUS_ALL, "and the card behind it takes focus again")
		if err == "":
			screen._input(_key_press(KEY_ESCAPE))
			await _pump(game)
			err = _T.assert_false(game.is_paused(), "Escape on the bare pause card still resumes")
	game.resume_run()
	await _pump(game)
	_T.free_ui(game)
	return err


# -- Options from the pause card (plant-tower-defense-syq) --------------------


## Opens it the way a player does -- through the button's own signal. Same shape
## and same reason as _open_pause_keys: calling PauseScreen._open_options()
## directly would pass just as happily with nothing wired to the button.
func _open_pause_options(screen: PauseScreen) -> String:
	var button: Button = screen.get_node_or_null("OptionsButton") as Button
	var err: String = _T.assert_true(button != null,
		"the pause card offers a way into the options screen")
	if err == "":
		err = _T.assert_false(button.disabled, "and the way in is not disabled")
	if err == "":
		err = _T.assert_true(button.size.x >= 40.0 and button.size.y >= 40.0,
			"and it is a real touch target, got %s" % button.size)
	if err == "":
		button.pressed.emit()
	return err


## The third door of the same shape, and the first one where "one overlay at a
## time" has three things to be wrong about rather than two.
func test_the_options_screen_opens_from_the_pause_card_and_the_run_stays_held() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	# Guarded against a vacuous pass: an empty table would report a confident green
	# over a card with no buttons at all.
	var err: String = _T.assert_gt(PauseScreen.BUTTONS.size(), 0, "the card has buttons to press")
	if err == "":
		err = _T.assert_gt(OptionsScreen.OPTIONS.size(), 0, "and there are switches to show")
	if err == "":
		game.pause_run()
		await _pump(game)
		err = _T.assert_true(game.is_paused(), "the run is held before the options screen is asked for")
	var screen := game.get_node_or_null("PauseLayer/PauseScreen") as PauseScreen
	if err == "":
		err = _T.assert_true(screen != null, "and the pause card is up")
	# The button emits `options_requested` and this screen answers it itself, the
	# same arrangement the notebook and keys buttons have. Watched separately so a
	# button wired straight to _open_options would still leave the declared signal
	# dead and fail here.
	var asked: Array[bool] = [false]
	if err == "":
		screen.options_requested.connect(func() -> void: asked[0] = true)
		err = _open_pause_options(screen)
	if err == "":
		err = _T.assert_true(asked[0], "the button asks for the options screen by signal")
	if err == "":
		await _pump(game)
		err = _T.assert_true(screen.options_open(), "pressing the button opens the options screen")
	var options: OptionsScreen = null
	if err == "":
		# Found by the name `build()` gives it, which is the contract both doors share
		# -- a card that named its own copy something else would fail here rather than
		# quietly become a second version of this overlay.
		options = screen.get_node_or_null(OptionsScreen.NODE_NAME) as OptionsScreen
		err = _T.assert_true(options != null,
			"and it is really on the card under the name build() gives it, not merely flagged open")
	if err == "":
		err = _T.assert_true(game.is_paused(), "and the run is STILL held with it open")
	if err == "":
		# Stated, not inherited -- see OptionsScreen.build. INHERIT resolves to ALWAYS
		# today only because the card is ALWAYS, and the failure if that changes is a
		# frozen screen with a Back button that does nothing.
		err = _T.assert_eq(options.process_mode, Node.PROCESS_MODE_ALWAYS,
			"the options screen runs while the tree it was opened from is paused")
	if err == "":
		# The declaration is one thing; this is the engine agreeing, while the tree
		# really is paused.
		err = _T.assert_true(options.can_process(), "and the engine agrees it still processes")
	if err == "":
		for node_name: String in ["BackButton", "RowButton0"]:
			var b: Button = options.get_node_or_null(node_name) as Button
			err = _T.assert_true(b != null and not b.disabled,
				"%s is present and clickable while paused" % node_name)
			if err == "":
				err = _T.assert_true(b.can_process(), "%s is not frozen by the pause" % node_name)
			if err != "":
				break
	if err == "":
		err = _open_pause_options(screen)
		if err == "":
			await _pump(game)
			err = _T.assert_eq(screen.get_children().filter(
				func(child: Node) -> bool: return child is OptionsScreen).size(), 1,
				"pressing it twice does not stack two options screens")
	if err == "":
		# The half only a THIRD overlay can be wrong about, in both directions: one
		# shared guard, not three independent "is mine open" checks.
		err = _open_pause_keys(screen)
		if err == "":
			await _pump(game)
			err = _T.assert_false(screen.keys_open(),
				"the keys screen cannot open on top of the options screen")
	if err == "":
		screen._open_notebook()
		await _pump(game)
		err = _T.assert_false(screen.notebook_open(),
			"and neither can the notebook")
	if err == "":
		# And back the other way, which is the ordering the guard could pass by
		# accident: close options, open keys, then try options over it.
		(screen.get_node(OptionsScreen.NODE_NAME) as OptionsScreen).back_requested.emit()
		await _pump(game)
		err = _T.assert_false(screen.options_open(), "Back closes the options screen")
		if err == "":
			err = _open_pause_keys(screen)
		if err == "":
			await _pump(game)
			err = _T.assert_true(screen.keys_open(), "the keys screen opens once nothing is in the way")
		if err == "":
			err = _open_pause_options(screen)
		if err == "":
			await _pump(game)
			err = _T.assert_false(screen.options_open(),
				"and options cannot open on top of the keys screen either")
	if err == "":
		err = _T.assert_true(game.is_paused(), "the run was held through all of it")
	game.resume_run()
	await _pump(game)
	_T.free_ui(game)
	return err


## Escape is answered by BOTH screens: OptionsScreen._input emits back_requested,
## PauseScreen._input emits resume_requested. Unresolved, one keystroke closes the
## options screen AND drops the player onto a live board -- which is why the pause
## side's connection is CONNECT_DEFERRED and the title side's is direct.
##
## Driven by calling the two handlers directly, in the order the engine would,
## because that ordering is the thing under test.
func test_escape_in_the_options_screen_closes_it_without_unpausing_the_run() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.pause_run()
	await _pump(game)
	var screen := game.get_node_or_null("PauseLayer/PauseScreen") as PauseScreen
	var err: String = _T.assert_true(screen != null, "the pause card is up")
	if err == "":
		err = _open_pause_options(screen)
	if err == "":
		await _pump(game)
		err = _T.assert_true(screen.options_open(), "the options screen is open")
	if err == "":
		var options := screen.get_node(OptionsScreen.NODE_NAME) as OptionsScreen
		options._input(_key_press(KEY_ESCAPE))
		screen._input(_key_press(KEY_ESCAPE))
		err = _T.assert_true(game.is_paused(),
			"the card declines the Escape the options screen just answered, rather than "
				+ "resuming the run behind it in the same keystroke")
	if err == "":
		await _pump(game)
		err = _T.assert_false(screen.options_open(), "and the Escape did close the options screen")
	if err == "":
		err = _T.assert_true(game.is_paused(), "with the run still held once it is gone")
	if err == "":
		# The half tree order does not cover: P is a resume key the options screen
		# does not handle at all, so with it up P would reach the card unopposed.
		err = _open_pause_options(screen)
		if err == "":
			await _pump(game)
			screen._input(_key_press(KEY_P))
			err = _T.assert_true(game.is_paused(), "P over an open options screen does not unpause")
		if err == "":
			err = _T.assert_true(screen.options_open(), "and leaves the options screen where it was")
	if err == "":
		# And with nothing over it the card's own Escape still works -- or the guard
		# above would pass by breaking the pause menu, with every assertion green.
		(screen.get_node(OptionsScreen.NODE_NAME) as OptionsScreen)._input(_key_press(KEY_ESCAPE))
		await _pump(game)
		err = _T.assert_false(screen.options_open(), "the options screen is out of the way again")
		if err == "":
			err = _T.assert_eq((screen.get_node("ResumeButton") as Button).focus_mode,
				Control.FOCUS_ALL, "and the card behind it takes focus again")
		if err == "":
			screen._input(_key_press(KEY_ESCAPE))
			await _pump(game)
			err = _T.assert_false(game.is_paused(), "Escape on the bare pause card still resumes")
	game.resume_run()
	await _pump(game)
	_T.free_ui(game)
	return err


## The reason the door is worth having, asserted as a state change rather than as
## a screen that opened: a player reaches Options mid-run because they cannot read
## the bars in front of them, and a switch that takes effect at the next wave is
## not an answer to that. Game.repaint_for_palette is what closes it, and
## resume_run calls it on the way out of every pause.
##
## RunConfig is process-global and seeded from the developer's own save, so the
## save path and every field the writer emits are stashed and put back.
func test_flipping_the_colourblind_bars_mid_run_repaints_the_board_on_resume() -> String:
	var stashed_path: String = RunConfig.save_path
	var stashed_colorblind: bool = RunConfig.colorblind_safe
	var stashed_status: String = RunConfig.load_status
	var stashed_milestones: Dictionary = RunConfig.earned_milestones.duplicate()
	var stashed_bindings: Dictionary = RunConfig.key_bindings
	var path := "user://test_selftest_pause_options.save"
	RunConfig.save_path = path
	RunConfig.colorblind_safe = false

	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(100)
	# A bitten bed, left alone. Its bar is drawn from take_damage()/_regrow(), so
	# nothing will repaint it on its own between here and the assertion -- which is
	# the whole case the repaint exists for, and the one a paused board guarantees.
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, _grass(game)), "", "planted")
	var plant: Plant = game.selected_placed
	if err == "":
		err = _T.assert_true(plant != null, "and the placed bed is the one we hold")
	if err == "":
		plant.take_damage(Plant.MAX_HEALTH * 0.5)
		err = _T.assert_true(plant._health_bar.visible, "a bitten bed shows its bar")
	var default_red := Color.WHITE
	if err == "":
		default_red = plant._health_bar.color
		err = _T.assert_float_eq(_colour_distance(default_red, Hud.health_color_on(0.0, false)),
			0.0, 0.001, "which starts on the default ramp, got %s" % default_red)
	if err == "":
		game.pause_run()
		await _pump(game)
	var screen := game.get_node_or_null("PauseLayer/PauseScreen") as PauseScreen
	if err == "":
		err = _T.assert_true(screen != null, "the pause card is up")
	if err == "":
		err = _open_pause_options(screen)
	if err == "":
		await _pump(game)
		err = _T.assert_true(screen.options_open(), "the options screen is open over the held run")
	if err == "":
		var options := screen.get_node(OptionsScreen.NODE_NAME) as OptionsScreen
		# Through the row's own button, not through RunConfig: the claim is that the
		# screen a player reaches mid-run drives the same flag the C key does.
		var index: int = options.rows().find(OptionsScreen.COLORBLIND)
		err = _T.assert_gte(index, 0, "the colourblind row is on the screen")
		if err == "":
			(options.get_node("RowButton%d" % index) as Button).pressed.emit()
			err = _T.assert_true(RunConfig.colorblind_safe,
				"pressing it mid-run turns the safe ramp on")
	if err == "":
		err = _T.assert_true(FileAccess.file_exists(path),
			"and it was written down from inside the run, not held for the session")
	if err == "":
		# Still on the old ramp while the card is up: nothing has bitten the bed and
		# the screen that flipped the flag has no reach into the board. This is the
		# state the fix is about, asserted rather than assumed.
		err = _T.assert_float_eq(_colour_distance(plant._health_bar.color, default_red), 0.0,
			0.001, "the bar behind the card is still on the ramp it was drawn with")
	if err == "":
		(screen.get_node(OptionsScreen.NODE_NAME) as OptionsScreen).back_requested.emit()
		await _pump(game)
		game.resume_run()
		await _pump(game)
		err = _T.assert_false(game.is_paused(), "the run comes back")
	if err == "":
		var now: Color = plant._health_bar.color
		var to_safe: float = _colour_distance(now, Hud.health_color_on(0.0, true))
		var to_default: float = _colour_distance(now, Hud.health_color_on(0.0, false))
		err = _T.assert_true(to_safe < to_default,
			"and resuming repaints the bed onto the safe ramp without anything biting it: "
				+ "%s is %.3f from safe and %.3f from default" % [now, to_safe, to_default])
	if err == "":
		# The method resume_run reaches for, named directly, so a rename that left
		# the resume path calling something else would fail here too.
		RunConfig.colorblind_safe = false
		game.repaint_for_palette()
		err = _T.assert_float_eq(_colour_distance(plant._health_bar.color, default_red), 0.0,
			0.001, "repaint_for_palette puts it back on the default ramp, got %s"
				% plant._health_bar.color)
	if err == "":
		RunConfig.colorblind_safe = true
		err = _T.assert_true(RunConfig.colorblind_safe, "with the option still settable")

	_T.free_ui(game)
	RunConfig.save_path = stashed_path
	RunConfig.colorblind_safe = stashed_colorblind
	RunConfig.load_status = stashed_status
	RunConfig.earned_milestones = stashed_milestones
	RunConfig.key_bindings = stashed_bindings
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	return err


## The legend this card draws is built once, from the table Game handed it at
## construction. Until the Keys button existed nothing could move a binding while
## the card was alive; now the button directly above the legend can. Without a
## redraw a player rebinds pause, closes the screen, and reads a row still naming
## the old key -- on the one screen whose job is to say what the keys are.
##
## Every field this touches is process-global (RunConfig loads the developer's own
## save at startup), so the save path, the stored bindings and the InputMap are all
## stashed and put back.
func test_rebinding_from_the_pause_card_redraws_the_legend_under_it() -> String:
	var stashed_path: String = RunConfig.save_path
	var stashed_bindings: Dictionary = RunConfig.key_bindings
	var stashed_status: String = RunConfig.load_status
	var path := "user://test_selftest_pause_rebind.save"
	RunConfig.save_path = path
	KeyBindings.reset_all()

	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.pause_run()
	await _pump(game)
	var screen := game.get_node_or_null("PauseLayer/PauseScreen") as PauseScreen
	var err: String = _T.assert_true(screen != null, "the pause card is up")
	# Which legend row carries the verb about to move. Found by action rather than
	# assumed to be row 0: key_help() is KeyBindings' run-scope table and reordering
	# it must not quietly turn this into a test of a different row.
	var index: int = -1
	if err == "":
		var help: Array[Dictionary] = Game.key_help()
		err = _T.assert_gt(help.size(), 0, "the legend has rows")
		if err == "":
			for i: int in range(help.size()):
				if StringName(help[i]["action"]) == KeyBindings.ACTION_MUTE_SFX:
					index = i
					break
			err = _T.assert_gt(index, -1, "and the verb being moved is one of them")
	var row: Label = null
	if err == "":
		row = screen.get_node_or_null("KeyRow%d" % index) as Label
		err = _T.assert_true(row != null, "the legend row is on the card")
	if err == "":
		err = _T.assert_true(row.text.contains("M"),
			"and it starts on the shipped key, got: %s" % row.text)
	if err == "":
		err = _open_pause_keys(screen)
	if err == "":
		await _pump(game)
		err = _T.assert_true(screen.keys_open(), "the keys screen is open over it")
	if err == "":
		# Through the screen's own row button and capture, not KeyBindings directly:
		# the claim is that a rebinding a PLAYER can perform reaches the legend.
		var keys := screen.get_node(KeyBindingScreen.NODE_NAME) as KeyBindingScreen
		keys.listen_for(KeyBindings.ACTION_MUTE_SFX)
		err = _T.assert_true(keys.capture(KEY_F7), "F7 is free, so the rebinding takes")
		if err == "":
			(keys.get_node("BackButton") as Button).pressed.emit()
			await _pump(game)
			err = _T.assert_false(screen.keys_open(), "and Back closes it")
	if err == "":
		err = _T.assert_true(row.text.contains("F7"),
			"the legend under it now names the new key, got: %s" % row.text)
	if err == "":
		err = _T.assert_false(row.text.contains("M   "),
			"and no longer the old one, got: %s" % row.text)
	if err == "":
		err = _T.assert_true(game.is_paused(), "with the run still held throughout")

	game.resume_run()
	await _pump(game)
	_T.free_ui(game)
	# apply_overrides, not reset_all: the InputMap is process-global and this suite
	# has tests that read it, so putting back the DEFAULTS would be a different
	# state from the one this test found -- for a developer whose own save moves a
	# key, silently so.
	KeyBindings.apply_overrides(stashed_bindings)
	RunConfig.save_path = stashed_path
	RunConfig.key_bindings = stashed_bindings
	RunConfig.load_status = stashed_status
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	return err


## The card's TOP is derived now, not just its height. A hand-picked 140 left six
## pixels of slack under a 648-tall viewport, which is exactly why the keys screen
## could not live here: one more button overflowed it. Centring means the card
## absorbs half of every button it gains, and this is the assertion that says so
## rather than a comment claiming it.
func test_the_pause_card_centres_itself_and_fits_a_real_viewport() -> String:
	var height: int = ProjectSettings.get_setting("display/window/size/viewport_height", 648)
	var rect: Rect2 = PauseScreen.card_rect()
	var err: String = _T.assert_gt(PauseScreen.card_height(), 0.0, "the card has a height to place")
	if err == "":
		# The rect's top IS card_top(), not a second copy of the same arithmetic --
		# a card_rect that placed the paper somewhere card_top() does not agree with
		# would put every derived assertion below on the wrong box.
		err = _T.assert_eq(rect.position.y, PauseScreen.card_top(),
			"card_rect places the paper where card_top says it goes")
	if err == "":
		err = _T.assert_true(rect.position.y >= 0.0,
			"the card's heading is not off the top, at %.0f" % rect.position.y)
	if err == "":
		err = _T.assert_true(rect.position.y + rect.size.y <= float(height),
			"and its foot at %.0f fits a %d-tall viewport" % [rect.position.y + rect.size.y, height])
	if err == "":
		# Centred, not merely fitting: the slack above and below must match, or the
		# next button added spends whichever side happens to be smaller.
		var above: float = rect.position.y
		var below: float = float(height) - (rect.position.y + rect.size.y)
		err = _T.assert_true(absf(above - below) <= 1.0,
			"the card is centred: %.0f above, %.0f below" % [above, below])
	if err == "":
		# The real claim, and the one the old constant could not make: another button
		# ROW has to MOVE the card, not overflow it. A row, not a button -- Keys and
		# Options share one, so BUTTONS.size() and the block's height differ now.
		var grown: float = PauseScreen.card_height() + PauseScreen.BUTTON_SIZE.y + PauseScreen.BUTTON_GAP
		err = _T.assert_true(grown <= float(height),
			"another button row would need %.0f of %d, and the derived top can still give it"
				% [grown, height])
	if err == "":
		err = _T.assert_gt(PauseScreen.button_row_count(), 0, "the card has button rows")
	if err == "":
		err = _T.assert_true(PauseScreen.button_row_count() < PauseScreen.BUTTONS.size(),
			"and fewer rows than buttons, because two of them share one")
	if err == "":
		# The shared row itself, off the same function the buttons are placed from.
		# One box per button, whatever the row count.
		var rects: Array[Rect2] = PauseScreen.button_rects()
		err = _T.assert_eq(rects.size(), PauseScreen.BUTTONS.size(),
			"button_rects gives every button a box, not every row")
		if err == "":
			for i: int in range(rects.size()):
				err = _T.assert_true(rects[i].size.x >= 40.0 and rects[i].size.y >= 40.0,
					"button %d is a real touch target at %s" % [i, rects[i].size])
				if err != "":
					break
		if err == "":
			for i: int in range(rects.size()):
				for j: int in range(i + 1, rects.size()):
					err = _T.assert_false(rects[i].intersects(rects[j]),
						"button %d overlaps button %d (%s vs %s)" % [i, j, rects[i], rects[j]])
					if err != "":
						break
				if err != "":
					break
		if err == "":
			# The pair specifically: same top edge, and a real gap between them.
			# Rect2.intersects is false for boxes sharing an edge, so the check above
			# passes on two buttons laid flush -- which is wrong only in a screenshot.
			var pair: int = -1
			for i: int in range(PauseScreen.BUTTONS.size()):
				if bool(PauseScreen.BUTTONS[i].get("share_row", false)):
					pair = i
					break
			err = _T.assert_gt(pair, 0, "some button shares a row with the one above it")
			if err == "":
				err = _T.assert_float_eq(rects[pair].position.y, rects[pair - 1].position.y, 0.001,
					"a shared row is one row: both halves sit on the same top edge")
			if err == "":
				err = _T.assert_float_eq(
					rects[pair].position.x - (rects[pair - 1].position.x + rects[pair - 1].size.x),
					PauseScreen.BUTTON_PAIR_GAP, 0.001,
					"with BUTTON_PAIR_GAP of clear air between them, not merely no overlap")
			if err == "":
				err = _T.assert_float_eq(
					rects[pair].position.x + rects[pair].size.x,
					rects[pair - 1].position.x + PauseScreen.BUTTON_SIZE.x, 0.001,
					"and the pair spans exactly the width one full-width button would have")
	return err


## The subheading counts itself from PAGES, so its text grows as pages are added
## — and its box is the full panel width while its bottom edge sits 5px below
## PANE_LABEL_Y. That means the two pane labels are held off it by nothing but
## the centred text being narrower than the panel.
##
## The pairwise-overlap test does catch the collision, but only once the text has
## grown past the pane label's x — it reports a 60px intersection between two
## Controls that both fit their own boxes, which reads like a positioning bug in
## the labels rather than a sentence that got too long. This measures the actual
## invariant, so the failure names the cause.
func test_the_notebook_subheading_stays_narrower_than_the_paper() -> String:
	var err := ""
	var book := await _T.instantiate_ui(
		NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
	var subhead := book.get_node_or_null("Subheading") as Label
	err += _T.assert_true(subhead != null, "the notebook has a Subheading")
	if subhead == null:
		_T.free_ui(book)
		return err

	# Measured through the font, not get_minimum_size(): a Label with clip_text
	# reports ~1px minimum, so the obvious form of this assertion cannot fail.
	var font: Font = subhead.get_theme_font("font")
	var size_px: int = subhead.get_theme_font_size("font_size")
	err += _T.assert_gt(size_px, 0, "the subheading resolved a font size")
	var drawn: float = font.get_string_size(
		subhead.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
	err += _T.assert_gt(drawn, 0.0, "the subheading has text to measure")
	err += _T.assert_true(
		drawn <= NotebookScreen.SUBHEAD_MAX_WIDTH,
		"the subheading text draws %.0fpx, budget is %.0f — shorten it, or move PANE_LABEL_Y (%s)"
			% [drawn, NotebookScreen.SUBHEAD_MAX_WIDTH, subhead.text])

	_T.free_ui(book)
	return err


# -- What is true of A road vs THIS road (plant-tower-defense-ch3) -----------
#
# PATH_CORNERS is six corners. Everything below is a number some other file
# arrived at by measuring the road those corners happen to produce, and then
# wrote down as a constant. Each of them is separately tested, so each will
# fail on its own if the road moves — which sounds like coverage and is not.
# It means a designer who nudges one corner gets four unrelated-looking test
# failures across three files, none of which says "you changed the road".
#
# This is the one that says it. It measures the road at runtime and compares
# it against the shape the calibrations assume, so it fails FIRST and names
# what has to be re-derived.
#
# The classification, which is the actual deliverable of this issue:
#
#   PROPERTY OF *A* ROAD (survives any route; no re-derivation needed)
#     - the CONCEPTS, and only the concepts: "a cell with no road within
#       reach" (dead ground), "the nearest buildable cell is further from the
#       lane than a husk click reaches" (husk clearance), "no wave paces more
#       pests onto the road than it can hold". All three are well-defined for
#       any route. Every NUMBER attached to them is not.
#
#   PROPERTY OF *THIS* ROAD (a new route invalidates it, silently)
#     - SIMULTANEOUS_PEST_CEILING = 40. Derived in wave_director.gd from
#       "32 road cells, 2112 px, so 3.5 pests per cell". A shorter road makes
#       40 more crowded than the reasoning intends; a longer one makes the cap
#       bite when it was not meant to. The constant does not change. Its
#       justification does — silently, because nothing re-runs the derivation.
#     - the dead-ground counts (11 of 94 cells for a Corn Cobbler, 36 for a Chomp).
#     - the Sundew's coverage arithmetic: stated against how much road a
#       single placement reaches on this route.
#
#   READS THE ROAD BUT DOES NOT DEPEND ON IT — the category I kept collapsing
#     - the husk clearance. Filed first as road-INDEPENDENT, reasoning it
#       compared two pixel radii. Wrong: husk_click_margin() walks every route
#       segment against every buildable cell. Filed second as road-DEPENDENT
#       on the strength of that walk. Also wrong, and the subtler error — the
#       walk returns CELL/2 for ANY road, because route() is one point per
#       road-cell CENTRE and a centre cannot be nearer than half a cell to a
#       neighbouring cell's box. So the 4 px is CELL/2 - COLLECT_RADIUS: two
#       constants. Measured, not argued — see the last test in this block.
#
# So it is three of four, and the fourth is not the reassuring case either:
# it is a number that LOOKS measured and is not. Both of my first two answers
# were wrong, in opposite directions, and the second was the worse mistake —
# provenance is not consequence. A function can read the road and still be
# constant over every road.
#
# What survives of the issue's premise: "each is individually tested" is not
# coverage of the road's SHAPE. Three tests guard three numbers and not one of
# them asks whether the road is still what those numbers were read off.


## The measurements every calibration above was taken against. If this fails,
## do not fix the number here — re-derive the three road-dependent constants
## the message names, then update these.
##
## WHAT THIS GUARDS, EXACTLY, AND WHY THE NAME NOW SAYS SO (plant-tower-defense-kndl).
## Two scalars and no more: the road is 32 CELLS long and 2112 PX of walking.
## That is the whole assertion. It was previously called
## `test_the_road_is_still_the_road_the_constants_were_measured_against`, which
## reads as "the road has not changed" — a much larger claim than the body makes,
## and a reader who trusted the name would conclude the route is untouched.
##
## The difference is not academic; it is the thing that made cycle 53's reshape
## cheap. `Board.PATH_CORNERS` was rewritten from a route that never travelled
## -Y into one that climbs (plant-tower-defense-84x0), the shape changed
## COMPLETELY, and this test correctly stayed silent — because the reshape was
## built to hold exactly these two numbers: 31 steps over 32 cells, 1984 px plus
## two 64 px brackets = 2112 px. See `board.gd`'s own comment on PATH_CORNERS,
## which states the same split: "Re-derive nothing that depends only on length or
## cell count; DO re-check anything that depends on the road's SHAPE."
##
## SO THIS TEST IS NOT THE ALARM FOR SHAPE. Every one of these guards a fact
## about WHERE the road runs, every one of them WILL move under a reshape that
## this test passes through in silence, and each has to be re-derived by hand:
##
##   dead ground        `test_the_real_route_strands_exactly_the_cells_it_was_measured_to_strand`
##                      (test/unit/test_placement.gd). Cycle 53 moved Corn from
##                      15 stranded cells to 11 and Chomp from 34 to 36 — in
##                      OPPOSITE directions, over an identical length and count.
##   the split cell     `test_a_cell_can_be_dead_ground_for_a_chomp_and_good_ground_for_a_corn`
##                      (test/unit/test_placement.gd). The cell that splits the
##                      two reaches moved from (2, 3) to (1, 3): the new climb put
##                      road at (2, 4), inside a Chomp's grab radius, so the old
##                      square stopped splitting anything at all.
##   garden coverage    `test_the_recorded_gardens_still_have_the_property_they_claim`
##                      (test/unit/test_combat.gd). The two recorded cob gardens
##                      are cell lists; a reshape can turn a garden cell into road
##                      and every downstream ratio goes on reporting a number.
##   Sundew coverage    `test_the_preview_warns_about_ground_an_existing_patch_already_covers`
##                      (test/unit/test_placement.gd), which pins (2, 0) covering
##                      every road cell (2, 2) would reach — a fact about this
##                      route's geometry and nothing else.
##
## And one that reads the road and is guarded here by NEGATION, because provenance
## is not consequence: `test_the_husk_margin_reads_the_road_but_does_not_depend_on_it`
## below, whose walk yields CELL/2 for any road at all.
func test_the_road_still_has_the_length_and_cell_count_the_constants_were_measured_against() -> String:
	var board := Board.new()
	await _T.instantiate_scene(board)

	var route: PackedVector2Array = board.route()
	# Vacuity guard: an unbuilt board hands back an empty route, and every
	# assertion below would then be measuring nothing while passing.
	var err: String = _T.assert_gt(route.size(), 2, "the board built a route")
	if err != "":
		_T.free_ui(board)
		return err

	# route() is one point per road cell, bracketed by an off-board entry and
	# exit — so the cell count is the interior, and the length includes the two
	# bracket segments, exactly as wave_director.gd's 2112 px does.
	var cells: int = route.size() - 2
	var length: float = 0.0
	for i: int in range(route.size() - 1):
		length += route[i].distance_to(route[i + 1])

	var whose_problem := "\n  Re-derive before touching this test:" \
		+ "\n    - WaveDirector.SIMULTANEOUS_PEST_CEILING (40) — reasoned from" \
		+ " %d cells / %.0f px as 3.5 pests per cell of road" % [cells, length] \
		+ "\n    - the dead-ground counts (11 of 94 cells for a Corn Cobbler, 36" \
		+ " for a Chomp Flower) — see" \
		+ " test_the_real_route_strands_exactly_the_cells_it_was_measured_to_strand" \
		+ "\n    - the Sundew's coverage arithmetic" \
		+ "\n  NOT affected: PlacementPreview.husk_click_margin(). It walks the" \
		+ " route, but the walk yields CELL/2 for any road — see" \
		+ " test_the_husk_margin_reads_the_road_but_does_not_depend_on_it"

	err = _T.assert_eq(cells, 32,
		"the road is 32 cells" + whose_problem)
	if err == "":
		err = _T.assert_eq(length, 2112.0,
			"the road is 2112 px of walking" + whose_problem)
	_T.free_ui(board)
	return err


## The half of the classification a measurement cannot make: WHICH constants
## actually consult the route. Asserting it means the block above is checked
## rather than believed — it already caught that block being wrong once, when
## the husk margin was filed as road-independent and turned out to walk every
## route segment on the board.
##
## Reads source rather than behaviour on purpose. "Is this number derived from
## the road?" is a question about where the value comes from, and a function
## that returns 4.0 answers it identically whether it measured the road or was
## handed a literal.
func test_the_road_dependent_constants_are_the_ones_that_read_the_road() -> String:
	var src := FileAccess.get_file_as_string("res://game/placement_preview.gd")
	var err: String = _T.assert_gt(src.length(), 0, "placement_preview.gd is readable")
	if err != "":
		return err

	var start: int = src.find("static func husk_click_margin")
	err = _T.assert_true(start >= 0, "husk_click_margin() still exists")
	if err != "":
		return err
	# The body runs to the next top-level func, or to end of file.
	var stop: int = src.find("\nfunc ", start)
	var next_static: int = src.find("\nstatic func ", start + 1)
	if next_static >= 0 and (stop < 0 or next_static < stop):
		stop = next_static
	if stop < 0:
		stop = src.length()
	var body: String = src.substr(start, stop - start)

	# It reads the route today. If it ever stops, the 4 px stops being a
	# statement about this road and the block above needs revisiting in the
	# other direction — so this is asserted, not assumed, both ways round.
	var reads_road := false
	for token: String in ["route(", "PATH_CORNERS", "is_road", "is_buildable"]:
		if body.contains(token):
			reads_road = true
			break
	err = _T.assert_true(reads_road,
		"husk_click_margin() still measures against the road, so the 4 px is a"
			+ " property of THIS route and belongs in the road-dependent list")
	if err != "":
		return err

	# And the ceiling's derivation is prose. Nothing recomputes it, which is
	# precisely why the measurement test above has to hold the line for it.
	var wd := FileAccess.get_file_as_string("res://game/wave_director.gd")
	err = _T.assert_gt(wd.length(), 0, "wave_director.gd is readable")
	if err != "":
		return err
	err = _T.assert_true(wd.contains("SIMULTANEOUS_PEST_CEILING: int = 40"),
		"the ceiling is still the hand-derived literal these tests assume."
			+ " If it became computed from route(), delete this and say so")
	return err


## The third pass at classifying the husk margin, and the one that settles it.
##
## First I had it road-INDEPENDENT, reasoning it compared two pixel radii.
## Wrong: it walks every route segment against every buildable cell. Then I
## had it road-DEPENDENT on the strength of that walk. Also wrong, and the
## subtler error — provenance is not consequence. The walk reads the road and
## then returns the same number for any road.
##
## Why: route() is one point per road-cell CENTRE, and buildable cells are
## whole cells. The nearest a centre can be to a neighbouring cell's box is
## half a cell, exactly, and it cannot be nearer because the two cells do not
## overlap. So the minimum over the whole board is CELL/2 for any route that
## has an adjacent buildable cell anywhere — which is every route that leaves
## room to play. The 4 px is CELL/2 - COLLECT_RADIUS, and both terms are
## constants.
##
## So the honest classification is: reads the road, does not depend on it.
## That is a distinction the source-reading test above deliberately cannot
## make, which is why this one measures instead.
func test_the_husk_margin_reads_the_road_but_does_not_depend_on_it() -> String:
	var board := Board.new()
	await _T.instantiate_scene(board)

	var lane: float = PlacementPreview.lane_to_buildable_distance(board)
	var err: String = _T.assert_gt(lane, 0.0, "the lane distance measured something")
	if err != "":
		_T.free_ui(board)
		return err

	err = _T.assert_eq(lane, float(Board.CELL) / 2.0,
		"the lane comes exactly half a cell from buildable ground. If this ever"
			+ " differs, the margin HAS become a property of this particular road"
			+ " and the classification block above needs revisiting a fourth time")
	if err == "":
		# And therefore the 4 px is two constants, not a measurement.
		err = _T.assert_eq(
			PlacementPreview.husk_click_margin(board),
			float(Board.CELL) / 2.0 - CompostMeter.COLLECT_RADIUS,
			"the margin is CELL/2 - COLLECT_RADIUS, both constants")
	_T.free_ui(board)
	return err


## The placement brackets were the last pair of hand-typed colours the
## GardenTheme merge missed, and the reason they survived it is instructive:
## BLOCKED_COLOR was *more* saturated in the red channel than DANGER, so it
## did not look like a copy of anything. A grep for the palette's literals
## would never have found it.
##
## This pins two separate things. That the brackets still derive from the
## palette — so the next person who wants a different red changes it in one
## place — and that the derivation still LANDS where the hand-typed colours
## were, so unifying the source did not quietly restyle the board.
func test_the_placement_brackets_come_from_the_palette_and_still_look_the_same() -> String:
	var ok: Color = PlacementPreview.OK_COLOR
	var blocked: Color = PlacementPreview.BLOCKED_COLOR

	# The colours they replaced, recorded here because a regression to a
	# hand-typed value is exactly what this test exists to catch, and a diff
	# against nothing catches nothing.
	var was_ok := Color(0.55, 0.95, 0.62, 0.75)
	var was_blocked := Color(0.95, 0.42, 0.36, 0.75)

	var err: String = _T.assert_true(
		ok.a == 0.75 and blocked.a == 0.75,
		"both brackets stay at the alpha that keeps a hover quieter than the marker")
	if err != "":
		return err

	for pair: Array in [[ok, was_ok, "OK"], [blocked, was_blocked, "BLOCKED"]]:
		var now: Color = pair[0]
		var before: Color = pair[1]
		var drift: float = maxf(maxf(absf(now.r - before.r), absf(now.g - before.g)),
			absf(now.b - before.b))
		err = _T.assert_true(drift < 0.08,
			"%s_COLOR drifted %.3f from the hand-typed value it replaced (%s vs %s)."
				% [pair[2], drift, now, before]
				+ " Unifying the source was meant to be invisible on screen")
		if err != "":
			return err

	# And the tie to the palette, which is the whole point and which the
	# compiler cannot hold: `Color.lightened()` is a method call, so it is not
	# a constant expression and these cannot be written as derived consts
	# without a parse error that cascades through every dependent script. The
	# relationship therefore lives here or nowhere. Change DANGER and leave
	# BLOCKED_COLOR behind, and this is what says so.
	for pair: Array in [
		[blocked, GardenTheme.DANGER.lightened(0.25), "BLOCKED", "DANGER"],
		[ok, GardenTheme.LEAF.lightened(0.45), "OK", "LEAF"],
	]:
		var now: Color = pair[0]
		var want: Color = pair[1]
		var off: float = maxf(maxf(absf(now.r - want.r), absf(now.g - want.g)),
			absf(now.b - want.b))
		err = _T.assert_true(off < 0.08,
			"%s_COLOR is %.3f away from %s lightened (%s vs %s). The brackets are"
				% [pair[2], off, pair[3], now, want]
				+ " meant to be that palette colour, dimmed — if the palette moved,"
				+ " move these with it rather than widening this tolerance")
		if err != "":
			return err
	return ""


# -- what the suite never touches (plant-tower-defense-h8o) ------------------
#
# `tools/suite_reach_check.py` answers the one question no other gate here asks:
# which parts of the game's public surface does the test suite never so much as
# name. run_tests.gd prints `Assertions: 8718 executed` and lint prints
# `Shaders: N of M`, but 8718 assertions all aimed at Board is 8718 assertions,
# and nothing in the toolchain notices.
#
# These four checks are not a re-run of that tool -- they re-derive its two
# central claims in GDScript, independently, so a bug in the Python cannot make
# both halves agree. The baseline it ships is a list of symbols it asserts no
# test names; if that list ever contains something a test DOES name, or something
# the game no longer declares, the baseline has become a place to hide debt
# rather than a record of it.


const SUITE_REACH_BASELINE := "res://tools/suite_reach_baseline.json"
const SUITE_REACH_CHECKER := "res://tools/suite_reach_check.py"


## Comments stripped AND string bodies blanked.
##
## `_code_only` above does the first half only, which is right for its callers --
## they look for an identifier, and an identifier quoted in a string is still a
## mention. Here it would be wrong in both directions. "Sticky Sundew" is a HUD
## caption, not a reference to the class; entry["spread_degrees"] is a dictionary
## key that has nothing to do with CornCobbler.spread_degrees(), a function
## nothing calls. Counting either as reach is how a coverage number comes out
## flattering.
##
## A backslash escape inside a string skips the character after it. That is not
## pedantry -- the first draft of this omitted it and the omission was caught by
## the two scans disagreeing, on this very file: the blanker test below contains
## the literal `"var x = entry[\"spread_degrees\"]"`, and an escape-blind reader
## ends the string at the `\"`, leaves `spread_degrees` standing as bare code, and
## concludes that a test names CornCobbler.spread_degrees(). Nothing does. The
## Python side has always consumed escapes, so the disagreement pointed here.
##
## Line-oriented, so it does not understand a `"""` block spanning lines. Nothing
## under test/unit uses one; if that changes, this reads the interior as code.
func _code_without_strings(src: String) -> String:
	var out: PackedStringArray = []
	for line: String in _code_only(src).split("\n"):
		var kept: String = ""
		var quote: String = ""
		var i: int = 0
		while i < line.length():
			var c: String = line[i]
			if quote != "":
				if c == "\\" and i + 1 < line.length():
					# Two spaces for two characters: length is preserved so a hit
					# can still be mapped back onto the original line.
					kept += "  "
					i += 2
					continue
				kept += " "
				if c == quote:
					quote = ""
			elif c == "\"" or c == "'":
				quote = c
				kept += " "
			else:
				kept += c
			i += 1
		out.append(kept)
	return "\n".join(out)


## Every .gd under test/unit, concatenated, with comments and string bodies gone.
##
## The absence assertions below pass for two reasons -- the token really is
## missing, or the haystack is -- so callers guard on the returned length. That
## guard only catches the GROSS failure (a path typo, a DirAccess that returned
## null, no .gd matched), which is the realistic one. It deliberately does not try
## to catch a subtly broken blanker by measuring shrinkage: measured on this
## suite, correct blanking keeps 74.7% of the non-whitespace characters and a
## blanker bugged to swallow each line from its first quote onward keeps 70.3%,
## and no threshold separates 74.7 from 70.3 without lying about its precision.
## `_code_without_strings` is unit-tested directly instead, on input small enough
## to state the right answer for.
func _test_corpus() -> String:
	var chunks: PackedStringArray = []
	var dir := DirAccess.open("res://test/unit")
	if dir == null:
		return ""
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name.ends_with(".gd"):
			chunks.append(_code_without_strings(
				FileAccess.get_file_as_string("res://test/unit".path_join(name))))
		name = dir.get_next()
	dir.list_dir_end()
	return "\n".join(chunks)


## {res:// path -> class_name} for every game script that declares one.
func _game_class_names() -> Dictionary:
	var out: Dictionary = {}
	var dir := DirAccess.open("res://game")
	if dir == null:
		return out
	var finder := RegEx.create_from_string("(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name.ends_with(".gd"):
			var path: String = "res://game".path_join(name)
			var m: RegExMatch = finder.search(_code_only(FileAccess.get_file_as_string(path)))
			if m != null:
				out[path] = m.get_string(1)
		name = dir.get_next()
	dir.list_dir_end()
	return out


## Baseline entries as [{path, kind, name}].
func _suite_reach_baseline_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var text: String = FileAccess.get_file_as_string(SUITE_REACH_BASELINE)
	if text == "":
		return out
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return out
	var symbols: Variant = (parsed as Dictionary).get("symbols", [])
	if not (symbols is Array):
		return out
	for raw: Variant in (symbols as Array):
		var parts: PackedStringArray = str(raw).split("::")
		if parts.size() == 3:
			out.append({"path": parts[0], "kind": parts[1], "name": parts[2]})
	return out


## The file-level half of the reach claim, re-derived here rather than trusted.
##
## The Python says 27 of 27 game scripts are named by some test. That is a weak
## clean -- named is not tested -- but it has to be TRUE, and it is the assertion
## most easily faked by a broken scan: a corpus that came back empty would report
## every symbol unreached and every file unreached, and a corpus whose string
## blanking ate real code would do the same. This is the positive control for
## both, and it doubles as the check that a newly added game script cannot arrive
## with the suite silent about it.
func test_every_game_class_is_at_least_named_somewhere_in_the_test_suite() -> String:
	var corpus: String = _test_corpus()
	var err: String = _T.assert_gt(corpus.length(), 0,
		"the test corpus is non-empty -- an empty one would pass every check below")
	if err != "":
		return err

	var classes: Dictionary = _game_class_names()
	err = _T.assert_gt(classes.size(), 0, "game/ declares class_names to look for")
	if err != "":
		return err

	for path: String in classes:
		var cls: String = str(classes[path])
		var finder := RegEx.create_from_string("\\b%s\\b" % cls)
		err = _T.assert_true(finder.search(corpus) != null,
			("%s declares `%s` and no test under test/unit names it in code."
				% [path, cls])
			+ " tools/suite_reach_check.py gates on exactly this; if it is passing"
			+ " while this fails, its scan is broken rather than the suite")
		if err != "":
			return err
	return ""


## A baseline entry that no longer exists is debt that got deleted rather than
## paid, and it is invisible from the Python side: suite_reach_check only ever
## asks whether a CURRENT declaration is in the baseline, never whether a
## baseline line still corresponds to anything. Left alone it rots into a list
## that quietly forgives symbols by name -- so a future `func reset()` on some
## other script would arrive pre-waived by an entry written about WaveDirector.
func test_the_suite_reach_baseline_lists_only_symbols_the_game_still_declares() -> String:
	var entries: Array[Dictionary] = _suite_reach_baseline_entries()
	var err: String = _T.assert_gt(entries.size(), 0,
		"tools/suite_reach_baseline.json parses and lists symbols."
		+ " An unreadable or empty baseline would make every loop below vacuous")
	if err != "":
		return err

	var sources: Dictionary = {}
	for entry: Dictionary in entries:
		var path: String = "res://" + str(entry["path"])
		var kind: String = str(entry["kind"])
		var name: String = str(entry["name"])
		if not sources.has(path):
			sources[path] = _code_only(FileAccess.get_file_as_string(path))
		var src: String = str(sources[path])
		err = _T.assert_gt(src.length(), 0,
			"%s is readable -- a baseline naming a file that is gone is stale" % path)
		if err != "":
			return err
		# Indent 0, optional annotations, optional `static`. The same shape the
		# Python matches, written out again so the two have to agree.
		var finder := RegEx.create_from_string(
			"(?m)^(?:@[A-Za-z_][A-Za-z0-9_]*(?:\\([^)]*\\))?\\s+)*(?:static\\s+)?%s\\s+%s\\b"
				% [kind, name])
		err = _T.assert_true(finder.search(src) != null,
			("the baseline claims %s declares %s `%s`, and it no longer does."
				% [path, kind, name])
			+ " Regenerate with `python tools/suite_reach_check.py --baseline-write"
			+ " tools/suite_reach_baseline.json` -- a stale entry forgives the next"
			+ " symbol that happens to share the name")
		if err != "":
			return err
	return ""


## The other direction, and the one that matters: a baseline entry naming
## something a test DOES reach is a false finding frozen into a file, and it
## makes the whole list untrustworthy. Re-derived here in GDScript against the
## same corpus, so agreeing requires two independent scans to agree.
func test_the_suite_reach_baseline_lists_only_symbols_no_test_names() -> String:
	var entries: Array[Dictionary] = _suite_reach_baseline_entries()
	var err: String = _T.assert_gt(entries.size(), 0, "the baseline lists symbols")
	if err != "":
		return err

	var corpus: String = _test_corpus()
	err = _T.assert_gt(corpus.length(), 0,
		"and the corpus to check them against is non-empty")
	if err != "":
		return err

	for entry: Dictionary in entries:
		var name: String = str(entry["name"])
		var finder := RegEx.create_from_string("\\b%s\\b" % name)
		err = _T.assert_true(finder.search(corpus) == null,
			("the baseline records %s `%s` (%s) as named by no test, but a test"
				% [str(entry["kind"]), name, str(entry["path"])])
			+ " does name it in code. Usually this means somebody wrote that test and"
			+ " the debt list has not caught up: run `python tools/suite_reach_check.py`"
			+ " -- its PROGRESS: line names the same symbols -- then"
			+ " `--baseline-write tools/suite_reach_baseline.json` to bank it."
			+ " If the Python does NOT agree, one of the two scans is dropping a match,"
			+ " and a baseline with false entries stops being readable as debt at all")
		if err != "":
			return err
	return ""


## The blanker itself, on input small enough to state the right answer for.
##
## This exists because the obvious guard for the two absence checks above -- "the
## corpus came back non-empty, and every game class is still findable in it" --
## was measured against a deliberately broken blanker and PASSED. Swallowing each
## line from its first quote to end-of-line still leaves every class_name findable
## somewhere across 4600 lines, and still leaves 70% of the characters. A corpus
## statistic cannot see that. Six characters of controlled input can.
##
## Every case is a way the two absence checks could go quietly vacuous.
func test_the_reach_corpus_blanker_drops_string_bodies_and_keeps_code() -> String:
	var cases: Array[Array] = [
		# [source, token, present in the blanked output?, what it protects]
		["var x = KeepMe.field()", "KeepMe", true,
			"a bare code identifier survives -- if this fails the corpus is a hole"],
		["var x = \"DropMe\"", "DropMe", false,
			"an identifier inside a double-quoted string is not a reference"],
		["var x = 'DropMeToo'", "DropMeToo", false,
			"single quotes count as strings too"],
		["# CommentToken", "CommentToken", false,
			"prose is never reach -- the trap this repo has already been bitten by"],
		["var x = entry[\"spread_degrees\"]", "spread_degrees", false,
			"a dictionary key is not a call to the same-named function"],
		# The closing quote MUST reset the state. Without it everything after the
		# first string on a line vanishes, which is the exact bug this test caught.
		["var x = \"gone\" + AfterTheString.here()", "AfterTheString", true,
			"code after a closed string survives"],
		["var a = \"one\"\nvar b = SecondLine.call()", "SecondLine", true,
			"and a string does not leak across the newline"],
		# The case that made the two scans disagree, kept as data. An escape-blind
		# reader ends the string at the \" and reports EscapedInside as live code.
		["var x = \"a\\\"b EscapedInside\"", "EscapedInside", false,
			"a backslash escape does not end the string early"],
		["var x = \"a\\\"b\" + AfterEscaped.go()", "AfterEscaped", true,
			"and consuming the escape does not swallow the code after the real end"],
	]
	var err: String = _T.assert_gt(cases.size(), 0, "there are cases to run")
	if err != "":
		return err

	var checked: int = 0
	for case: Array in cases:
		var out: String = _code_without_strings(str(case[0]))
		var finder := RegEx.create_from_string("\\b%s\\b" % str(case[1]))
		var found: bool = finder.search(out) != null
		checked += 1
		err = _T.assert_eq(found, bool(case[2]),
			("blanking %s: `%s` should%s survive -- %s"
				% [str(case[0]).replace("\n", "\\n"), str(case[1]),
					"" if bool(case[2]) else " not", str(case[3])]))
		if err != "":
			return err

	err = _T.assert_eq(checked, cases.size(), "every case actually ran")
	if err == "":
		# Length preservation is not cosmetic: it is what lets a caller map a hit
		# back to a line, and it is why blanking writes spaces rather than deleting.
		err = _T.assert_eq(_code_without_strings("var x = \"abcd\"").length(),
			"var x = \"abcd\"".length(),
			"blanking preserves length, so offsets still index the original")
	return err


## The house contract for a static checker (`.claude/skills/house-static-checker`)
## is mostly prose, and the one clause that is load-bearing at runtime is the
## `NOT COVERED:` line: it is what makes a deliberately weak tool trustworthy,
## and it is the first thing a tidy-up deletes because it reads like a caveat
## rather than a feature. The three exit codes are pinned for the same reason --
## a checker that stopped returning 2 on a missing input would report "clean"
## over nothing at all, which is the failure this repo watches for above all.
##
## AND THE `contains` LOOP BELOW IS A FLOOR, NOT THE CHECK (plant-tower-defense-qewq).
## Three of the four needles are satisfied by text that is not the thing they name:
## `return 2` occurs NINE times in that file, and BOTH occurrences of
## `suite-reach-check: ok` are help text -- the parser is
## `WAIVER_RE = re.compile(r"suite-reach-check:\s*ok\b")`, which does not contain the
## literal at all. Delete the waiver outright and this loop stays green. That is the
## cycle-91 shape exactly: presence asserted where absence, or behaviour, was wanted.
##
## So the loop keeps its job -- a needle that vanishes ENTIRELY is still worth
## catching cheaply -- and the assertions after it ask the questions it cannot:
## the marker has to be PRINTED rather than merely written down, and the waiver has
## to have a parser and a call site rather than only an advertisement.
##
## The behavioural half lives where it can actually run:
## `python tools/mutate.py --target contract` drives the checker's own `main()` at a
## rootless directory and asserts the documented waiver comment comes back waived.
## Its fourth mutation deletes ONE of the two help-text mentions and is registered
## `expect=SURVIVED` with the reason -- this loop's blind spot, executed rather than
## described. If you change a needle here, run that sweep.
func test_the_suite_reach_checker_still_declares_its_house_contract() -> String:
	var src: String = FileAccess.get_file_as_string(SUITE_REACH_CHECKER)
	var err: String = _T.assert_gt(src.length(), 0,
		"tools/suite_reach_check.py is readable -- every assertion below is"
		+ " vacuous against an empty string")
	if err != "":
		return err
	var checked: int = 0
	for needle: Array in [
		["NOT COVERED:", "the line that says what the tool structurally cannot see"],
		["return 2", "the could-not-run exit code"],
		["NOTE: nothing to check", "the spelled-out zero denominator"],
		["suite-reach-check: ok", "the waiver, which has to be greppable to be usable"],
	]:
		err = _T.assert_true(src.contains(str(needle[0])),
			"the checker still carries %s (`%s`)" % [str(needle[1]), str(needle[0])])
		if err != "":
			return err
		checked += 1
	err = _T.assert_eq(checked, 4,
		"all four contract needles were reached -- an empty needle table would make"
			+ " the loop above a pass over nothing")
	if err != "":
		return err

	# PRINTED, not merely present. `contains` cannot tell the marker from a line of
	# prose ABOUT the marker, and prose is what a tidy-up leaves behind. The marker
	# has to sit inside a print() call on its own line.
	var at: int = src.find("NOT COVERED:")
	var line_start: int = src.rfind("\n", at) + 1
	err = _T.assert_true(src.substr(line_start, at - line_start).contains("print("),
		"the NOT COVERED marker is inside a print() call and not sitting in a comment"
			+ " or a docstring -- a contract line nobody prints is prose")
	if err != "":
		return err

	# The waiver's PARSER and its CALL SITE, because the needle above finds neither.
	# Both help lines could survive word for word with the waiver deleted.
	err = _T.assert_true(src.contains("WAIVER_RE = re.compile("),
		"the waiver has a parser and not only an advertisement -- the two help lines"
			+ " the needle above matches are documentation, not the implementation")
	if err == "":
		err = _T.assert_true(src.contains("WAIVER_RE.search("),
			"and the parser is consulted somewhere, so a waived declaration is"
				+ " actually waived rather than merely documented as waivable")
	return err


# -- StickySundew's wash-order counter resets, not just climbs forever
# -- (plant-tower-defense-qij) ----------------------------------------------


func test_the_wash_order_counter_resets_once_the_last_patch_on_the_board_is_gone() -> String:
	# Advance the counter first so this can't pass by accident of wherever the
	# rest of the suite happened to leave it -- a fresh process also starts it
	# at 0, and that would look identical to a reset that never fired.
	var warmup := StickySundew.new()
	var before_reset: int = StickySundew._next_wash_order
	warmup.free()
	var err: String = _T.assert_gt(before_reset, 0, "sanity: constructing a patch always advances the counter")
	if err != "":
		return err

	var patch := StickySundew.new()
	patch.setup(PlantCatalog.SUNDEW, Vector2i(0, 0), null)
	var host: Node2D = _host([patch])
	await _T.instantiate_scene(host)
	err = _T.assert_true(StickySundew.live_patches().has(patch),
		"sanity: this patch registered itself the moment it entered the tree")
	_T.free_ui(host)  # frees the host's children too -- patch._exit_tree runs synchronously
	if err == "":
		err = _T.assert_true(StickySundew.live_patches().is_empty(),
			"sanity: freeing the only patch on the board empties the live list")
	if err == "":
		err = _T.assert_eq(StickySundew._next_wash_order, 0,
			"the counter resets to 0 the instant the last patch on the board is gone")
	return err


# -- A kernel hit gets its own cue (plant-tower-defense-7o3) ----------------


func test_hit_flash_color_boosts_channels_but_leaves_alpha_alone() -> String:
	var base := Color(0.58, 0.66, 0.78, 0.6)  # an armoured tint, mid-fade alpha
	var flashed: Color = Pest.hit_flash_color(base)
	var err: String = _T.assert_float_eq(flashed.a, base.a, 0.0001, "alpha is untouched by the flash")
	if err == "":
		err = _T.assert_float_eq(flashed.r, base.r * Pest.HIT_FLASH_BOOST, 0.0001, "red is boosted, not replaced")
	if err == "":
		err = _T.assert_float_eq(flashed.g, base.g * Pest.HIT_FLASH_BOOST, 0.0001, "green is boosted, not replaced")
	if err == "":
		err = _T.assert_float_eq(flashed.b, base.b * Pest.HIT_FLASH_BOOST, 0.0001, "blue is boosted, not replaced")
	return err


func test_flash_hit_is_a_no_op_on_a_pest_that_is_already_dead() -> String:
	var pest: Pest = _pest(Pest.APHID, Vector2.ZERO)
	var host: Node2D = _host([pest])
	await _T.instantiate_scene(host)

	pest.kill()
	var corpse_modulate: Color = pest._sprite.modulate
	pest.flash_hit()
	var err: String = _T.assert_eq(pest._sprite.modulate, corpse_modulate,
		"a corpse does not also flash -- flash_hit() is only for a hit that lands on a pest still standing")
	_T.free_ui(host)
	return err


## A beetle's 16 health survives one 1.0-damage kernel, which is exactly the
## case this bd issue is about: before it, that connecting kernel and one that
## sailed off the board looked identical.
func test_a_kernel_that_connects_but_does_not_kill_flashes_the_pest_it_hit() -> String:
	var beetle: Pest = _pest(Pest.BEETLE, Vector2(40, 0))
	var host: Node2D = _host([beetle])
	await _T.instantiate_scene(host)

	# The kernel is built and armed with real bounds AFTER the settle pump above,
	# not inside it: a fresh Kernel's _bounds defaults to an empty Rect2, which
	# contains no point at all, so a settle-frame physics tick running before
	# setup() would read that as "left the board" and free the node before this
	# test ever gets a turn.
	var kernel := Kernel.new()
	kernel.setup(Vector2(40, 0), Vector2.RIGHT, 1.0, Rect2(Vector2(-2000, -2000), Vector2(4000, 4000)))
	host.add_child(kernel)
	var idle_modulate: Color = beetle._sprite.modulate
	kernel._physics_process(0.016)
	var err: String = _T.assert_true(beetle.is_alive(), "sanity: a beetle's 16 health survives one 1.0-damage kernel")
	if err == "":
		err = _T.assert_true(beetle.health < beetle.max_health, "and the hit still landed")
	if err == "":
		# GardenTheme.animations_enabled() is false headless (see flash_hit's own
		# gate), so the Tween it would queue never runs -- this pins the no-crash,
		# no-op path rather than a visible flash a windowed run actually shows.
		err = _T.assert_eq(beetle._sprite.modulate, idle_modulate,
			"headless: flash_hit() is a gated no-op here, not a frozen mid-flash tint")
	_T.free_ui(host)
	return err


func test_a_kernel_that_kills_its_pest_leaves_it_dead() -> String:
	var aphid: Pest = _pest(Pest.APHID, Vector2(10, 0))
	var host: Node2D = _host([aphid])
	await _T.instantiate_scene(host)

	# See the sibling test above: the kernel is built and armed after the
	# settle pump, not inside it.
	var kernel := Kernel.new()
	var lethal: float = float(Pest.SPECIES[Pest.APHID]["health"])
	kernel.setup(Vector2(10, 0), Vector2.RIGHT, lethal, Rect2(Vector2(-2000, -2000), Vector2(4000, 4000)))
	host.add_child(kernel)
	kernel._physics_process(0.016)
	var err: String = _T.assert_false(aphid.is_alive(), "a kernel dealing full health kills the aphid it connects with")
	_T.free_ui(host)
	return err


## Music's mute gate, same shape as Sfx.should_play and asserted the same way:
## headless has no audio device at all, so this is what stands in for "did it
## make a sound" -- see Music.should_play's own doc comment.
func test_music_should_play_respects_mute_and_headless() -> String:
	# is_headless() is a thin proxy onto Sfx.is_headless() -- Music keeps no
	# headless flag of its own, same reasoning as Sfx.audio_enabled() reusing
	# DisplayServer directly. The unit suite always runs headless, so this is
	# the one branch that is always true in-process.
	var err: String = _T.assert_true(Music.is_headless(), "the test runner itself is headless")
	if err == "":
		err = _T.assert_true(Music.should_play(Music.TITLE, false, false),
			"unmuted and not headless: the title bed is playable")
	if err == "":
		err = _T.assert_false(Music.should_play(Music.TITLE, true, false),
			"muted silences it even with a real audio device")
	if err == "":
		err = _T.assert_false(Music.should_play(Music.RUN, false, true),
			"headless silences it even unmuted -- there is no device to hear it")
	if err == "":
		err = _T.assert_false(Music.should_play(&"nonexistent_track", false, false),
			"an unknown track id goes quiet rather than erroring, same contract as Sfx")
	return err


## track_for_scene is what play_for_scene actually calls -- TitleScreen and
## Game both hand it their own scene_file_path rather than naming a track, so
## this map is the whole answer to "which bed does this scene play".
func test_music_track_for_scene_maps_title_and_game() -> String:
	var err: String = _T.assert_eq(Music.track_for_scene("res://game/title.tscn"), Music.TITLE,
		"the title screen plays the title bed")
	if err == "":
		err = _T.assert_eq(Music.track_for_scene("res://game/game.tscn"), Music.RUN,
			"the run plays the in-run bed")
	if err == "":
		# Not every scene has an opinion -- the post-mortem card is an overlay
		# inside game.tscn, not a scene change, and Game._end_run calls
		# play_title() directly for that transition instead of going through
		# this map. See SCENE_TRACKS' own doc comment.
		err = _T.assert_eq(Music.track_for_scene("res://game/does_not_exist.tscn"), &"",
			"an unmapped scene path is silently no opinion, not an error")
	return err


## Every id TRACKS promises actually resolves to a loadable, loop-enabled
## stream -- the music equivalent of the sfx table test one screen up. A typo'd
## path here fails in exactly the way sound always fails: by being silent.
func test_every_music_track_actually_loads_and_loops() -> String:
	for track: StringName in Music.TRACKS.keys():
		var path: String = String(Music.TRACKS[track])
		var err: String = _T.assert_true(ResourceLoader.exists(path),
			"Music.TRACKS['%s'] names a file that exists: %s" % [track, path])
		if err != "":
			return err
		var stream: AudioStream = load(path) as AudioStream
		err = _T.assert_true(stream != null, "and it loads as an AudioStream: %s" % path)
		if err != "":
			return err
		var ogg := stream as AudioStreamOggVorbis
		err = _T.assert_true(ogg != null, "it is an .ogg, the format _stream_for sets .loop on: %s" % path)
		if err != "":
			return err
	return ""


## play_for_scene / play_title cannot be heard headless (should_play gates
## every actual player on is_headless()), but the track *decision* is made
## before that gate -- see Music._play, which sets _current_track first and
## only then checks whether anything can play it. current_track() is what
## exposes that decision, so this exercises all three public entry points
## without a live game: the selection is real even where the sound is not.
func test_music_play_for_scene_updates_current_track_headlessly() -> String:
	Music.play_for_scene("res://game/title.tscn")
	var err: String = _T.assert_eq(Music.current_track(), Music.TITLE,
		"landing on the title scene selects the title bed")
	if err == "":
		Music.play_for_scene("res://game/game.tscn")
		err = _T.assert_eq(Music.current_track(), Music.RUN,
			"landing on the game scene selects the in-run bed")
	if err == "":
		# Unmapped path: SCENE_TRACKS has no opinion, so the current selection
		# must not change underneath whatever was already chosen.
		Music.play_for_scene("res://game/does_not_exist.tscn")
		err = _T.assert_eq(Music.current_track(), Music.RUN,
			"an unmapped scene leaves the current bed alone rather than silencing it")
	if err == "":
		# The direct-override entry point Game._end_run calls -- not reachable
		# through SCENE_TRACKS at all, see that map's own doc comment.
		Music.play_title()
		err = _T.assert_eq(Music.current_track(), Music.TITLE,
			"play_title() overrides the scene mapping for the post-mortem transition")
	return err


## refresh_mute() and stop_all() touch only AudioStreamPlayer state, which
## headless never builds (Music._ensure_host is never reached — should_play
## is false before it), so the one thing left to assert headlessly is that
## neither call disturbs the track *selection*, and that toggling Music's own
## mute and calling refresh_mute() around it is safe to do in either order.
## Music's mute is process-global state every later test shares, so it is
## restored to false at the end regardless of outcome.
func test_music_refresh_mute_and_stop_all_do_not_touch_track_selection() -> String:
	Music.play_title()
	var err: String = _T.assert_eq(Music.current_track(), Music.TITLE, "starting selection is the title bed")
	if err == "":
		Music.set_muted(true)
		Music.refresh_mute()
		err = _T.assert_eq(Music.current_track(), Music.TITLE,
			"muting through refresh_mute() silences playback, not the selection")
	if err == "":
		Music.stop_all()
		err = _T.assert_eq(Music.current_track(), Music.TITLE,
			"stop_all() is a playback command too -- same non-effect on the selection")
	if err == "":
		Music.set_muted(false)
		Music.refresh_mute()
		err = _T.assert_eq(Music.current_track(), Music.TITLE,
			"unmuting resumes the same bed rather than picking a new one")
	Music.set_muted(false)
	return err


## Music's own mute, mirrored against Sfx's own round-trip test
## (test_combat.gd's Sfx toggle test) and asserted to be a state distinct from
## Sfx's -- muting one must not move the other, which is the entire point of
## plant-tower-defense-gle. Restored to false at the end for the same reason
## as the test above: both mutes are process-global.
func test_music_mute_is_independent_of_sfx_mute() -> String:
	var music_was_muted: bool = Music.is_muted()
	var sfx_was_muted: bool = Sfx.is_muted()
	Music.set_muted(false)
	Sfx.set_muted(false)
	var err: String = _T.assert_true(Music.toggle_muted(), "one press mutes the music bed")
	if err == "":
		err = _T.assert_true(Music.is_muted(), "and the flag agrees with what it returned")
	if err == "":
		err = _T.assert_false(Sfx.is_muted(),
			"muting Music leaves Sfx's own mute untouched -- they are separate flags")
	if err == "":
		err = _T.assert_true(Sfx.toggle_muted(), "Sfx has its own independent toggle")
	if err == "":
		err = _T.assert_true(Music.is_muted(),
			"and toggling Sfx does not clear Music's own mute")
	if err == "":
		err = _T.assert_false(Music.toggle_muted(), "a second press brings the music bed back")
	Music.set_muted(music_was_muted)
	Sfx.set_muted(sfx_was_muted)
	return err


# -- The press, as opposed to what it went on to do (plant-tower-defense-aho) -


## The press cue lives at Game's receiving end, not on the button, because the
## HUD makes no sound anywhere in this project — every Sfx.play() is in game.gd
## or in a plant. What that costs is one hop the wiring has to survive, which is
## what this pins: the button must reach the handler that rings, and
## start_next_wave() must NOT be what the signal lands on, or the prep countdown
## running out would click a button nobody pressed.
func test_the_wave_button_reaches_the_cue_handler_and_still_starts_the_wave() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var handlers: Array[String] = []
	for entry: Dictionary in game.hud.next_wave_requested.get_connections():
		handlers.append(String((entry["callable"] as Callable).get_method()))
	var err: String = _T.assert_true(handlers.has("_on_next_wave_requested"),
		"the button's signal lands on the handler that plays the press cue")
	if err == "":
		err = _T.assert_false(handlers.has("start_next_wave"),
			"and no longer on the mutator, which the countdown and the devtools verb still call unheard")
	if err == "":
		var before: int = game.director.current_wave
		# The real Button, not the handler by name: calling
		# _on_next_wave_requested() directly would prove the cue and not the
		# wiring, which is the half that can actually break here.
		game.hud._next_wave_button.pressed.emit()
		err = _T.assert_eq(game.director.current_wave, before + 1,
			"and a real press still starts the wave through it")
	_T.free_ui(game)
	return err


# -- milestones (plant-tower-defense-4qi) ------------------------------------
#
# The evaluation half. RunConfig's own tests (test_economy.gd) cover the save
# file; these cover the table and the rule behind each id, which is pure static
# code over a Dictionary and needs no Game, no file and no Control.


## The stats Dictionary a run hands `Milestones.earned_by`, with nothing in it
## that earns anything. Every test below starts here and moves ONE field, so a
## milestone that fires is unambiguously firing on the thing that changed.
func _milestone_stats(overrides: Dictionary = {}) -> Dictionary:
	var stats: Dictionary = {
		"victory": false,
		"endless": false,
		"wave": 1,
		"lives_lost": 3,
		"pests_defeated": 0,
		"threat_level": 1,
		"compost_total": 0,
		"compost_resolved": 0,
	}
	for key: Variant in overrides:
		stats[key] = overrides[key]
	return stats


func test_a_dull_run_earns_no_milestone_at_all() -> String:
	## The floor, and the one that makes every test under it mean something: if the
	## baseline stats earned three milestones, "adding victory earns the clear"
	## would pass without victory having done anything.
	var earned: Array[String] = Milestones.earned_by(_milestone_stats())
	return _T.assert_eq(earned.size(), 0,
		"a lost run at wave 1 with nothing killed earns nothing, got %s" % str(earned))


func test_each_milestone_fires_on_the_number_it_names_and_not_before() -> String:
	## Every id, driven at its threshold and one step under it. The under-threshold
	## half is what catches a `>=` that should be a `>` and, more usefully, a rule
	## reading the wrong key -- a condition keyed on a field nothing sets is false
	## everywhere, which the on-threshold half alone reports as a clean fail.
	var cases: Array[Dictionary] = [
		{"id": "campaign_cleared", "on": {"victory": true}, "off": {"victory": false}},
		{
			"id": "unbroken_garden",
			"on": {"victory": true, "lives_lost": 0},
			"off": {"victory": true, "lives_lost": 1},
		},
		{
			"id": "hundred_pests",
			"on": {"pests_defeated": Milestones.HUNDRED},
			"off": {"pests_defeated": Milestones.HUNDRED - 1},
		},
		{
			"id": "five_hundred_pests",
			"on": {"pests_defeated": Milestones.FIVE_HUNDRED},
			"off": {"pests_defeated": Milestones.FIVE_HUNDRED - 1},
		},
		{
			"id": "endless_deep",
			"on": {"endless": true, "wave": Milestones.ENDLESS_DEEP_WAVE},
			"off": {"endless": true, "wave": Milestones.ENDLESS_DEEP_WAVE - 1},
		},
		{
			"id": "threat_peak",
			"on": {"threat_level": Milestones.THREAT_PEAK},
			"off": {"threat_level": Milestones.THREAT_PEAK - 1},
		},
		{
			"id": "clean_sweep",
			"on": {
				"compost_total": Milestones.SWEEP_FLOOR,
				"compost_resolved": Milestones.SWEEP_FLOOR,
			},
			"off": {
				"compost_total": Milestones.SWEEP_FLOOR - 1,
				"compost_resolved": Milestones.SWEEP_FLOOR,
			},
		},
	]
	var err: String = _T.assert_eq(cases.size(), Milestones.TABLE.size(),
		"every milestone in the table is driven here, %d rule(s) against %d entries"
			% [cases.size(), Milestones.TABLE.size()])
	if err != "":
		return err
	for case: Dictionary in cases:
		var id: String = String(case["id"])
		err = _T.assert_true(Milestones.is_met(id, _milestone_stats(case["on"] as Dictionary)),
			"%s fires on %s" % [id, str(case["on"])])
		if err != "":
			return err
		err = _T.assert_false(Milestones.is_met(id, _milestone_stats(case["off"] as Dictionary)),
			"%s does not fire on %s" % [id, str(case["off"])])
		if err != "":
			return err
	return ""


func test_an_endless_run_that_never_ends_cannot_earn_the_campaign_clear() -> String:
	## `victory` is unreachable in endless (WaveDirector.has_more_waves is
	## unconditionally true there), so this is a statement about the pair rather
	## than about one flag: an endless run deep enough to earn the wave-40
	## milestone must not also collect the two that mean "you finished".
	var earned: Array[String] = Milestones.earned_by(_milestone_stats({
		"endless": true,
		"wave": 120,
		"threat_level": 3,
		"pests_defeated": 40,
	}))
	var err: String = _T.assert_true(earned.has("endless_deep"), "the deep-endless flag is earned")
	if err == "":
		err = _T.assert_false(earned.has("campaign_cleared"),
			"and a run with no end does not report clearing one, got %s" % str(earned))
	if err == "":
		err = _T.assert_false(earned.has("unbroken_garden"), "nor holding every bed through one")
	return err


func test_a_run_that_swept_nothing_because_nothing_dropped_is_not_a_clean_sweep() -> String:
	## The branch SWEEP_FLOOR exists for. 0 of 0 is arithmetically a perfect sweep,
	## and it is what a run that never let a pest die produces -- the worst run in
	## the game earning the tidiest milestone.
	var err: String = _T.assert_false(
		Milestones.is_met("clean_sweep",
			_milestone_stats({"compost_total": 0, "compost_resolved": 0})),
		"0 of 0 is not a sweep")
	if err == "":
		err = _T.assert_false(
			Milestones.is_met("clean_sweep", _milestone_stats({
				"compost_total": Milestones.SWEEP_FLOOR - 1,
				"compost_resolved": Milestones.SWEEP_FLOOR,
			})),
			"and leaving one husk on the ground is not one either")
	return err


func test_every_milestone_id_has_a_rule_and_a_title() -> String:
	## The seam the table has: TABLE lists the ids and `is_met` answers them, and
	## nothing but this test stops an entry being added to one and not the other.
	## An id with no rule is a milestone that can never be earned, and it shows up
	## at runtime as nothing at all.
	var err: String = _T.assert_gt(Milestones.TABLE.size(), 0, "there are milestones to check")
	if err != "":
		return err
	# A stats Dictionary that satisfies everything at once, so a rule that never
	# returns true for ANY input is caught here rather than silently passing.
	var everything: Dictionary = _milestone_stats({
		"victory": true,
		"endless": true,
		"wave": 9999,
		"lives_lost": 0,
		"pests_defeated": 99999,
		"threat_level": 99,
		"compost_total": 999,
		"compost_resolved": 999,
	})
	var seen: Dictionary = {}
	for entry: Dictionary in Milestones.TABLE:
		var id: String = String(entry.get("id", ""))
		err = _T.assert_false(id.is_empty(), "every table entry names an id")
		if err != "":
			return err
		err = _T.assert_false(seen.has(id), "%s appears once in the table" % id)
		if err != "":
			return err
		seen[id] = true
		err = _T.assert_true(Milestones.is_met(id, everything),
			"%s has a rule that some run can actually satisfy" % id)
		if err != "":
			return err
		err = _T.assert_eq(Milestones.title_of(id), String(entry["title"]),
			"%s has the title the card prints" % id)
		if err != "":
			return err
		err = _T.assert_false(Milestones.note_of(id).is_empty(), "%s has a note under it" % id)
		if err != "":
			return err
		# Ids are the on-disk representation: RunConfig._parse_milestones refuses a
		# save carrying anything outside this set, so an id with a capital letter or
		# a space in it would be written and then refused on the next launch.
		for i: int in range(id.length()):
			err = _T.assert_true(RunConfig.MILESTONE_ID_CHARS.contains(id[i]),
				"%s is spelled in characters the save file accepts, '%s' is not" % [id, id[i]])
			if err != "":
				return err
	return ""


## The card's side of it. The ribbon is variable-height and lives beside the card
## rather than on it, so what can break is geometry: at its tallest it must still
## start clear of the card, end inside the viewport, and stay off the map legend's
## strip -- which is the one thing on this screen it could reach.
func test_the_milestone_ribbon_clears_the_card_and_the_map_legend() -> String:
	var worst: float = RunSummary.ribbon_height(Milestones.TABLE.size())
	var foot: float = RunSummary.RIBBON_TOP + worst
	var err: String = _T.assert_gt(worst, 0.0, "a full ribbon has height")
	if err == "":
		err = _T.assert_float_eq(RunSummary.ribbon_height(0), 0.0, 0.001,
			"and a run that earned nothing new draws no panel at all")
	if err == "":
		var card_right: float = RunSummary.CARD.position.x + RunSummary.CARD.size.x
		err = _T.assert_true(RunSummary.RIBBON_X >= card_right,
			"the ribbon starts to the right of the card, %.0f against %.0f"
				% [RunSummary.RIBBON_X, card_right])
	if err == "":
		var right: float = RunSummary.RIBBON_X + RunSummary.RIBBON_WIDTH
		err = _T.assert_true(right <= 1152.0,
			"and ends inside the viewport, right edge %.0f" % right)
	if err == "":
		err = _T.assert_true(foot <= RunSummary.MAP_LEGEND_Y,
			"a full ribbon foots at %.0f, above the map legend strip at %.0f"
				% [foot, RunSummary.MAP_LEGEND_Y])
	return err


func test_the_post_mortem_lists_the_milestones_the_run_just_earned() -> String:
	## Built off a stats Dictionary rather than a played run, for the reason
	## summary_rows() is: the card takes a plain Dictionary precisely so the whole
	## of its rendering is reachable without staging the run that produces it.
	var card := RunSummary.build({
		"victory": true,
		"new_milestones": ["campaign_cleared", "hundred_pests"],
	})
	var host: Node = await _T.instantiate_ui(card, Vector2i(1152, 648))
	var err: String = _T.assert_true(host != null, "the card stood up")
	if err == "":
		err = _T.assert_eq(card.new_milestones().size(), 2, "it read both ids out of the stats")
	if err == "":
		var ribbon: Panel = card.get_node_or_null("MilestoneRibbon") as Panel
		err = _T.assert_true(ribbon != null, "and drew the ribbon")
		if err == "":
			var row: Label = ribbon.get_node_or_null("Milestone_campaign_cleared") as Label
			err = _T.assert_true(row != null, "with a row for the campaign clear")
			if err == "":
				err = _T.assert_eq(row.text, Milestones.title_of("campaign_cleared"),
					"printing the table's own title rather than the raw id")
		if err == "":
			err = _T.assert_true(ribbon.get_node_or_null("Milestone_hundred_pests") != null,
				"and a row for the hundred")
		if err == "":
			err = _T.assert_float_eq(ribbon.size.y, RunSummary.ribbon_height(2), 0.5,
				"sized for exactly the two it is showing")
	_T.free_ui(host)
	return err


func test_a_run_with_no_new_milestones_draws_no_ribbon() -> String:
	## The common case -- most runs repeat what an earlier run already did -- and
	## the one that has to leave no node behind. An empty Panel here is exactly what
	## `validate-ui` reports as a zero-content Control finding.
	var card := RunSummary.build({"victory": false})
	var host: Node = await _T.instantiate_ui(card, Vector2i(1152, 648))
	var err: String = _T.assert_true(host != null, "the card stood up")
	if err == "":
		err = _T.assert_eq(card.new_milestones().size(), 0, "no ids in the stats")
	if err == "":
		err = _T.assert_true(card.get_node_or_null("MilestoneRibbon") == null,
			"and no ribbon node was created for them")
	_T.free_ui(host)
	return err


# -- colourblind-safe bars (plant-tower-defense-xu0) -------------------------
#
# Both combat bars ease through one hue family, which is the one thing a
# red-green colour deficiency flattens. The ramp SELECTION is what these test:
# `threat_color_on` / `health_color_on` are pure and take the flag, so the choice
# can be asserted for both settings in one run without a HUD and without leaving
# a process-global option set behind for the next test.


## How far apart two colours are in the red-green channel alone -- the axis a
## deuteranope or protanope cannot read. Small means "these two look alike to the
## player this option exists for", whatever they look like here.
func _red_green_gap(a: Color, b: Color) -> float:
	return absf((a.r - a.g) - (b.r - b.g))


func test_the_flag_actually_picks_a_different_ramp_for_both_bars() -> String:
	## The selection itself, at both ends of both bars. A wiring mistake here is
	## invisible on screen -- a bar drawn on the wrong ramp is still a plausible
	## looking bar -- and it is the whole feature.
	var err: String = _T.assert_true(
		Hud.health_color_on(0.0, false).is_equal_approx(Hud.HEALTH_LOW),
		"off, an empty health bar is the default red")
	if err == "":
		err = _T.assert_true(Hud.health_color_on(1.0, false).is_equal_approx(Hud.HEALTH_FULL),
			"and a full one is the leaf green")
	if err == "":
		err = _T.assert_true(Hud.health_color_on(0.0, true).is_equal_approx(Hud.HEALTH_LOW_SAFE),
			"on, an empty bar is the safe ramp's low stop")
	if err == "":
		err = _T.assert_true(Hud.health_color_on(1.0, true).is_equal_approx(Hud.HEALTH_FULL_SAFE),
			"and a full one is its high stop")
	if err == "":
		err = _T.assert_true(
			Hud.threat_color_on(Hud.THREAT_TINT_MAX, true).is_equal_approx(Hud.THREAT_HOT_SAFE),
			"on, a runaway threat is the safe ramp's hot stop")
	if err == "":
		err = _T.assert_true(Hud.threat_color_on(1, true).is_equal_approx(Hud.PAPER),
			"while a calm one is still the bar's own cream on either ramp -- an early "
				+ "run must not look like something is wrong just because the option is on")
	if err == "":
		# The clamp, which the health bar needs and the old inline lerp never had:
		# _refresh_health clamps before calling, so this is belt and braces, but a
		# fraction out of range must not extrapolate past either stop.
		err = _T.assert_true(Hud.health_color_on(-3.0, true).is_equal_approx(Hud.HEALTH_LOW_SAFE),
			"a fraction below zero pins at the low stop rather than overshooting it")
	if err == "":
		err = _T.assert_true(Hud.health_color_on(9.0, false).is_equal_approx(Hud.HEALTH_FULL),
			"and one above one pins at the high stop")
	return err


func test_the_safe_ramp_separates_its_ends_in_more_than_the_red_green_channel() -> String:
	## The point of the option, stated as the measurement it is about. The default
	## health ramp puts "fine" and "nearly gone" at opposite ends of exactly the
	## axis this player cannot see, so it must be the safe ramp that separates them
	## by MORE than that axis -- lightness -- and by less along it.
	var default_full: Color = Hud.health_color_on(1.0, false)
	var default_low: Color = Hud.health_color_on(0.0, false)
	var safe_full: Color = Hud.health_color_on(1.0, true)
	var safe_low: Color = Hud.health_color_on(0.0, true)

	var default_luma: float = absf(default_full.get_luminance() - default_low.get_luminance())
	var safe_luma: float = absf(safe_full.get_luminance() - safe_low.get_luminance())
	var err: String = _T.assert_gt(safe_luma, default_luma,
		"the safe ends differ in lightness by %.3f against the default's %.3f, so the ramp "
			% [safe_luma, default_luma] + "still reads as a ramp with the colour taken away")
	if err == "":
		err = _T.assert_gt(_red_green_gap(default_full, default_low),
			_red_green_gap(safe_full, safe_low),
			"and it leans less on the red-green axis than the ramp it replaces")
	if err == "":
		# The threat bar's ends, same question. Its calm end is PAPER on both ramps,
		# so what has to change is the hot end.
		var hot_gap: float = _red_green_gap(Hud.PAPER, Hud.THREAT_HOT)
		var safe_hot_gap: float = _red_green_gap(Hud.PAPER, Hud.THREAT_HOT_SAFE)
		err = _T.assert_gt(hot_gap, safe_hot_gap,
			"the threat bar's hot end is %.3f off cream in red-green terms by default and "
				% hot_gap + "%.3f on the safe ramp" % safe_hot_gap)
	return err


func test_the_two_bars_agree_about_which_ramp_is_on() -> String:
	## One switch, not two. A build where the threat readout went blue-orange and
	## the health fill stayed green-red would be worse than either alone: the
	## player would be reading two different languages on one screen.
	var err: String = _T.assert_true(
		Hud.health_color_on(0.0, true).is_equal_approx(Hud.threat_color_on(Hud.THREAT_TINT_MAX, true)),
		"on the safe ramp, an empty health bar and a runaway threat are one colour")
	if err == "":
		err = _T.assert_true(
			Hud.health_color_on(0.0, false).is_equal_approx(
				Hud.threat_color_on(Hud.THREAT_TINT_MAX, false)),
			"exactly as they are on the default one -- a red still means one thing")
	return err


func test_the_threat_ramp_still_climbs_without_going_backwards_on_the_safe_palette() -> String:
	## The monotonicity claim the default ramp already carries, re-asked on the
	## other palette in the terms that survive a colour deficiency: each level must
	## be at least as dark as the one below it. A ramp that brightens in the middle
	## is one a player reads as calming down.
	var previous: float = 2.0
	var err: String = ""
	for level: int in range(Hud.THREAT_SHOW_FROM, Hud.THREAT_TINT_MAX + 2):
		var luma: float = Hud.threat_color_on(level, true).get_luminance()
		err = _T.assert_gte(previous, luma,
			"threat %d is no lighter than the level below it (%.3f against %.3f)"
				% [level, luma, previous])
		if err != "":
			break
		previous = luma
	return err


func test_toggling_the_option_is_persisted_and_reversible() -> String:
	## The flag's own round trip through the live autoload, restored either way --
	## it is process-global, and a test that leaves it on changes what every later
	## test's `threat_color()` returns. The save file's side of it is in
	## test_economy.gd, over a scratch path.
	##
	## This one needs a scratch path too, and the docstring above is why it did not
	## have one: "the save file's side is tested elsewhere" is true and does not
	## help, because `set_colorblind_safe()` persists on every call regardless of
	## which test is asking. Restoring the flag in memory left the developer's real
	## save carrying whatever the last toggle wrote.
	var stashed_path: String = RunConfig.save_path
	RunConfig.save_path = "user://test_selftest_option.save"
	var was: bool = RunConfig.colorblind_safe
	RunConfig.colorblind_safe = false
	var err: String = _T.assert_true(RunConfig.toggle_colorblind_safe(), "one toggle turns it on")
	if err == "":
		err = _T.assert_true(
			Hud.threat_color(Hud.THREAT_TINT_MAX).is_equal_approx(Hud.THREAT_HOT_SAFE),
			"and threat_color, which reads the flag, follows it without an argument")
	if err == "":
		err = _T.assert_true(Hud.health_color(0.0).is_equal_approx(Hud.HEALTH_LOW_SAFE),
			"as does health_color, which is the other half of the same switch")
	if err == "":
		err = _T.assert_false(RunConfig.toggle_colorblind_safe(), "a second toggle turns it off")
	if err == "":
		err = _T.assert_true(Hud.threat_color(Hud.THREAT_TINT_MAX).is_equal_approx(Hud.THREAT_HOT),
			"and the default red comes back")
	if err == "":
		err = _T.assert_true(Hud.health_color(0.0).is_equal_approx(Hud.HEALTH_LOW),
			"on both bars at once")
	RunConfig.set_colorblind_safe(was)
	RunConfig.save_path = stashed_path
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists("user://test_selftest_option.save" + suffix):
			DirAccess.remove_absolute("user://test_selftest_option.save" + suffix)
	return err


## Distance between two colours in RGB. Used instead of `is_equal_approx` for the
## live-HUD check below: a plant regrows between the frame the fill was painted and
## the frame the assertion reads it, so the exact fraction is a moving target -- but
## "which of the two ramps is this closer to" is not.
func _colour_distance(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


func test_the_health_bar_the_hud_draws_goes_through_the_switch() -> String:
	## The wiring, not the arithmetic. `_refresh_health` used to lerp the two
	## constants inline, which is exactly the shape that survives a palette option
	## being added and silently ignores it.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var was: bool = RunConfig.colorblind_safe
	RunConfig.colorblind_safe = true
	game.bank.add_seeds(100)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, _grass(game)), "", "planted")
	var fill: ColorRect = game.hud.get_node_or_null(
		"Root/SidePanel/SelectionBox/HealthRow/HealthFill") as ColorRect
	if err == "":
		err = _T.assert_true(fill != null, "the health fill is where the panel puts it")
	if err == "":
		# Real damage through the path a pest takes, and the panel follows health
		# from Game._process rather than from a signal -- same as
		# test_the_selection_panel_reports_a_chewed_plants_health.
		game.selected_placed.take_damage(Plant.MAX_HEALTH * 0.5)
		game._process(0.016)
		await _pump(game)
		var fraction: float = clampf(game.selected_placed.health / Plant.MAX_HEALTH, 0.0, 1.0)
		var to_safe: float = _colour_distance(fill.color, Hud.health_color_on(fraction, true))
		var to_default: float = _colour_distance(fill.color, Hud.health_color_on(fraction, false))
		err = _T.assert_true(to_safe < to_default,
			"with the option on the fill %s is the safe ramp's colour (%.3f away) and not the "
				% [fill.color, to_safe] + "default's (%.3f away)" % to_default)
	if err == "":
		RunConfig.colorblind_safe = false
		game.selected_placed.take_damage(1.0)
		game._process(0.016)
		await _pump(game)
		var fraction2: float = clampf(game.selected_placed.health / Plant.MAX_HEALTH, 0.0, 1.0)
		var back_to_default: float = _colour_distance(fill.color, Hud.health_color_on(fraction2, false))
		var still_safe: float = _colour_distance(fill.color, Hud.health_color_on(fraction2, true))
		err = _T.assert_true(back_to_default < still_safe,
			"and it goes back to the default ramp the moment the option does, got %s" % fill.color)
	RunConfig.colorblind_safe = was
	_T.free_ui(game)
	return err


# -- The milestone shelf (plant-tower-defense-qar) ---------------------------
#
# RunConfig.earned_milestones is loaded from the developer's own user:// save at
# startup, so every test below pins the whole set and puts back what it found.
# A shelf test that read the real file would pass or fail on how much of the game
# whoever ran it had played, which is the failure three tests were just fixed for.


func test_the_notebook_has_exactly_one_shelf_page() -> String:
	var page: int = NotebookScreen.shelf_page()
	var err: String = _T.assert_gt(page, -1,
		"the notebook has a KIND_SHELF page — without it the earned set has nowhere to live")
	if err != "":
		return err
	var shelves: int = 0
	for entry: Dictionary in NotebookScreen.PAGES:
		if String(entry.get("kind", NotebookScreen.KIND_DRAWING)) == NotebookScreen.KIND_SHELF:
			shelves += 1
	return _T.assert_eq(shelves, 1, "and exactly one, so shelf_page() names a single page")


func test_the_milestone_shelf_lists_every_milestone_earned_or_not() -> String:
	## The whole point of the page: `RunSummary.new_milestones()` draws only what
	## a run was the first to do, so a shelf showing only the earned ones would
	## repeat that and still leave a new player looking at an empty page.
	var stashed: Dictionary = RunConfig.earned_milestones.duplicate()
	# Exactly one earned, and deliberately not the first row.
	RunConfig.earned_milestones = {"hundred_pests": true}
	var notebook := await _T.instantiate_ui(NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
	var shelf: Control = notebook.get_node_or_null("Shelf") as Control
	var err: String = _T.assert_true(shelf != null, "the shelf is built")
	if err == "":
		err = _T.assert_false(shelf.visible, "and starts hidden — page 1 is a drawing")
	if err == "":
		notebook.go_to(NotebookScreen.shelf_page())
		err = _T.assert_true(shelf.visible, "turning to the shelf page shows it")
	if err == "":
		err = _T.assert_false(notebook.get_node("Drawing").visible,
			"and the photograph it shares the matte with is put away")
	for row: Dictionary in Milestones.TABLE:
		if err != "":
			break
		var id: String = String(row["id"])
		var title: Label = shelf.get_node_or_null("ShelfTitle_%s" % id) as Label
		err = _T.assert_true(title != null, "%s has a row on the shelf" % id)
		if err == "":
			err = _T.assert_eq(title.text, Milestones.title_of(id),
				"and it is titled the way the post-mortem titles it")
	if err == "":
		err = _T.assert_eq(shelf.get_child_count(), Milestones.TABLE.size() * 3,
			"a pip, a title and a note for each of the %d milestones and nothing else"
				% Milestones.TABLE.size())
	_T.free_ui(notebook)
	RunConfig.earned_milestones = stashed
	return err


func test_the_shelf_tells_earned_from_unearned_without_using_colour() -> String:
	## Same rule Plant.HEALTH_BAR_SEGMENTS states for the board: a cue carried by
	## hue alone is a cue the colourblind-safe option exists because of. The pip's
	## SIZE and the note's "Not yet" prefix are the two channels that survive the
	## page being printed in one ink; this asserts them with the colours thrown
	## away entirely.
	var stashed: Dictionary = RunConfig.earned_milestones.duplicate()
	var got: String = String(Milestones.TABLE[0]["id"])
	var missing: String = String(Milestones.TABLE[1]["id"])
	RunConfig.earned_milestones = {got: true}
	var notebook := await _T.instantiate_ui(NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
	var shelf: Control = notebook.get_node("Shelf") as Control
	var earned_pip: ColorRect = shelf.get_node("ShelfPip_%s" % got) as ColorRect
	var unearned_pip: ColorRect = shelf.get_node("ShelfPip_%s" % missing) as ColorRect
	var err: String = _T.assert_gt(earned_pip.size.x, unearned_pip.size.x,
		"an earned pip (%s) is bigger than an unearned one (%s), not merely a different green"
			% [earned_pip.size, unearned_pip.size])
	if err == "":
		# Same centre line, or the column reads as two ragged left edges.
		err = _T.assert_float_eq(earned_pip.position.x + earned_pip.size.x / 2.0,
			unearned_pip.position.x + unearned_pip.size.x / 2.0, 0.001,
			"and the two sizes share a centre line")
	if err == "":
		var note: Label = shelf.get_node("ShelfNote_%s" % missing) as Label
		err = _T.assert_true(note.text.begins_with("Not yet"),
			"an unearned row says so in words: \"%s\"" % note.text)
	if err == "":
		var got_note: Label = shelf.get_node("ShelfNote_%s" % got) as Label
		err = _T.assert_eq(got_note.text, Milestones.note_of(got),
			"and an earned one is left as the table wrote it")
	if err == "":
		# The wording itself, without a screen: the prefix lowercases the note's
		# first letter so "Not yet — cleared it without an escape" is a sentence
		# rather than two of them jammed together.
		err = _T.assert_eq(NotebookScreen.shelf_note_text(missing, false),
			"Not yet — %s" % (Milestones.note_of(missing).substr(0, 1).to_lower()
				+ Milestones.note_of(missing).substr(1)),
			"shelf_note_text writes the unearned form as one sentence")
	if err == "":
		err = _T.assert_eq(NotebookScreen.shelf_note_text(missing, true), Milestones.note_of(missing),
			"and hands the table's own note straight back once it is earned")
	_T.free_ui(notebook)
	RunConfig.earned_milestones = stashed
	return err


func test_the_shelf_progress_line_counts_the_table_and_not_the_save() -> String:
	## An id from a build that knew more milestones than this one is a real case —
	## Milestones.is_met() already answers `false` for one rather than erroring —
	## and counting `earned_milestones.size()` would print "8 of 7 earned" the day
	## it happens. The count is over TABLE, intersected with the save.
	var stashed: Dictionary = RunConfig.earned_milestones.duplicate()
	var total: int = Milestones.TABLE.size()
	RunConfig.earned_milestones = {}
	var err: String = _T.assert_eq(NotebookScreen.shelf_progress_text(), "0 of %d earned" % total,
		"a save with nothing in it reads as none earned, not as an empty line")
	if err == "":
		RunConfig.earned_milestones = {
			String(Milestones.TABLE[0]["id"]): true, "a_milestone_from_the_future": true,
		}
		err = _T.assert_eq(NotebookScreen.shelf_progress_text(), "1 of %d earned" % total,
			"an id this build has no row for is not counted toward the total it has no row in")
	if err == "":
		var notebook := await _T.instantiate_ui(NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
		notebook.go_to(NotebookScreen.shelf_page())
		var source: Label = notebook.get_node("SourceLabel") as Label
		err = _T.assert_eq(source.text, "1 of %d earned" % total,
			"and the shelf page's provenance line is that count rather than a file name")
		_T.free_ui(notebook)
	RunConfig.earned_milestones = stashed
	return err


func test_the_milestone_shelf_fits_the_page() -> String:
	## Milestones.TABLE.size() rows at SHELF_ROW_PITCH is 297px against
	## DRAWING_BOX's 300 — there is no room for an eighth entry at these numbers,
	## and the failure it would cause is a row drawn off the bottom of the matte
	## onto the dark backdrop, which nothing else here would catch. Two ways out
	## when this fails: drop SHELF_ROW_PITCH, or split the shelf across both pages.
	var stashed: Dictionary = RunConfig.earned_milestones.duplicate()
	# Every row earned, so the pips are at their largest — the worst case for the
	# box, staged rather than waited for.
	var all_earned: Dictionary = {}
	for row: Dictionary in Milestones.TABLE:
		all_earned[String(row["id"])] = true
	RunConfig.earned_milestones = all_earned
	var notebook := await _T.instantiate_ui(NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
	var shelf: Control = notebook.get_node("Shelf") as Control
	var box := Rect2(Vector2.ZERO, NotebookScreen.DRAWING_BOX.size)
	var err := ""
	var rows: Array[Rect2] = []
	for row: Dictionary in Milestones.TABLE:
		var id: String = String(row["id"])
		for child_name: String in ["ShelfPip_%s" % id, "ShelfTitle_%s" % id, "ShelfNote_%s" % id]:
			var node: Control = shelf.get_node(child_name) as Control
			var rect := Rect2(node.position, node.size)
			err = _T.assert_true(box.encloses(rect),
				"%s at %s stays inside the shelf's box %s" % [child_name, rect, box])
			if err != "":
				break
		if err != "":
			break
		# Rows must not tread on each other either — the note of one row landing
		# on the title of the next is 17px of overlap that still fits the box.
		var note: Control = shelf.get_node("ShelfNote_%s" % id) as Control
		var title: Control = shelf.get_node("ShelfTitle_%s" % id) as Control
		var span := Rect2(title.position, Vector2(title.size.x,
			note.position.y + note.size.y - title.position.y))
		for prior: Rect2 in rows:
			err = _T.assert_true(prior.intersection(span).get_area() <= 0.0,
				"row %s at %s does not sit on the row at %s" % [id, span, prior])
			if err != "":
				break
		if err != "":
			break
		rows.append(span)
	_T.free_ui(notebook)
	RunConfig.earned_milestones = stashed
	return err


# -- The third bar (plant-tower-defense-b6v) ---------------------------------


func test_the_in_world_plant_bar_reads_the_same_ramp_the_hud_does() -> String:
	## plant-tower-defense-xu0 routed `Hud.health_color` and `Hud.threat_color`
	## through RunConfig.colorblind_safe and stopped there. The bar a player
	## actually watches during a chew is neither of those — the HUD's health row
	## only appears for the SELECTED plant, while every bed being eaten draws its
	## own ColorRect on the board — and it was a third green-to-red lerp the
	## option never reached. Pure, on both ramps, so the claim is about the ramp
	## and not about whatever palette this process was started with.
	var err := ""
	for safe: bool in [false, true]:
		err = _T.assert_eq(Plant.health_bar_color_on(false, safe), Hud.health_color_on(0.0, safe),
			"a bleeding bed is the HUD's own empty-health colour on the %s ramp"
				% ("safe" if safe else "default"))
		if err != "":
			return err
	# The regression itself: before this, both of the above were DANGER.
	err = _T.assert_true(
		Plant.health_bar_color_on(false, true) != Plant.health_bar_color_on(false, false),
		"and the switch actually moves it — a bleeding bar that is the same colour either way "
			+ "is the bug this issue is about")
	if err == "":
		err = _T.assert_true(
			Plant.health_bar_color_on(true, true) != Plant.health_bar_color_on(true, false),
			"the healing end moves too, or the safe ramp would still be half green-and-red")
	if err == "":
		# The shape channel is not superseded by the switch. A palette the player
		# has to find in a menu cannot be the only cue, and the notches are what
		# survives a screenshot, a greyscale print and a player who never presses
		# the key. See Plant.HEALTH_BAR_SEGMENTS.
		err = _T.assert_gt(Plant.health_bar_segments(true), Plant.health_bar_segments(false),
			"and the notches are still there — the ramp is a second channel, not a replacement")
	# And the reading half is wired to the pure one. `colorblind_safe` is
	# process-global and seeded from the real save, so it is pinned both ways here
	# and put back — this is the only test that may touch `health_bar_color` at all.
	var was: bool = RunConfig.colorblind_safe
	for safe: bool in [false, true]:
		if err != "":
			break
		RunConfig.colorblind_safe = safe
		for regrowing: bool in [false, true]:
			err = _T.assert_eq(Plant.health_bar_color(regrowing),
				Plant.health_bar_color_on(regrowing, safe),
				"health_bar_color(%s) reads the option rather than one fixed ramp" % regrowing)
			if err != "":
				break
	RunConfig.colorblind_safe = was
	return err


func test_toggling_the_option_repaints_the_bars_already_on_the_board() -> String:
	## The in-world bar is drawn from take_damage() and _regrow(), i.e. only when
	## the number moves. A chewed bed sitting quietly while the player presses the
	## colourblind key is the case where that is wrong: nothing bites it, so
	## nothing repaints it, and the one readout the option is most for keeps the
	## ramp the player just turned off. Driven through Game's own handler rather
	## than by calling repaint_health_bar() directly — a fix that lives in a method
	## nobody calls is not a fix.
	KeyBindings.reset_all()
	# Driving Game's own handler is the point of this test, and that handler reaches
	# toggle_colorblind_safe() -> _save(). Two presses restore the flag, so the file
	# it wrote came out byte-identical to the developer's real save and only its
	# mtime moved -- which is why this went unnoticed for so long. Redirect anyway:
	# "wrote the same bytes back" is luck about ordering, not a property of the test.
	var stashed_path: String = RunConfig.save_path
	RunConfig.save_path = "user://test_selftest_colorblind_toggle.save"
	var was: bool = RunConfig.colorblind_safe
	RunConfig.colorblind_safe = false
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(100)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, _grass(game)), "", "planted")
	var plant: Plant = game.selected_placed
	if err == "":
		err = _T.assert_true(plant != null, "and the placed bed is the one we hold")
	if err == "":
		# Bitten once and then left alone, which is the whole point: no further
		# damage and no regrowth tick may happen between here and the assertion.
		plant.take_damage(Plant.MAX_HEALTH * 0.5)
		err = _T.assert_true(plant._health_bar.visible, "a bitten bed shows its bar")
	if err == "":
		var default_red: Color = plant._health_bar.color
		err = _T.assert_float_eq(_colour_distance(default_red, Hud.health_color_on(0.0, false)),
			0.0, 0.001, "which starts on the default ramp, got %s" % default_red)
		if err == "":
			game._unhandled_input(_action_press(KeyBindings.ACTION_COLORBLIND))
			await _pump(game)
			var now: Color = plant._health_bar.color
			var to_safe: float = _colour_distance(now, Hud.health_color_on(0.0, true))
			var to_default: float = _colour_distance(now, Hud.health_color_on(0.0, false))
			err = _T.assert_true(to_safe < to_default,
				"and the key repaints it to the safe ramp without anything biting it again: "
					+ "%s is %.3f from safe and %.3f from default" % [now, to_safe, to_default])
		if err == "":
			game._unhandled_input(_action_press(KeyBindings.ACTION_COLORBLIND))
			await _pump(game)
			err = _T.assert_float_eq(_colour_distance(plant._health_bar.color, default_red), 0.0,
				0.001, "and back again, got %s" % plant._health_bar.color)
		if err == "":
			# The method the handler reaches for, called directly, so a rename that
			# left the loop above calling something else would fail here too.
			RunConfig.colorblind_safe = true
			plant.repaint_health_bar()
			err = _T.assert_float_eq(
				_colour_distance(plant._health_bar.color, Hud.health_color_on(0.0, true)), 0.0,
				0.001, "repaint_health_bar() is what does it, got %s" % plant._health_bar.color)
	RunConfig.colorblind_safe = was
	RunConfig.save_path = stashed_path
	DirAccess.remove_absolute("user://test_selftest_colorblind_toggle.save")
	_T.free_ui(game)
	return err


## No test may persist through the player's own save file.
##
## This is a source scan rather than a runtime check, and that is the point: the
## damage it prevents is invisible at runtime. Three tests staged a score or an
## option in memory, called a mutator that persists, and restored the in-memory
## value afterwards -- so every assertion passed, the suite printed ALL PASSED, and
## the only trace was `user://highscore.save` quietly carrying whatever the last
## test wrote. Observed climbing 308 -> 309 across two runs, and one of the three
## staged both scores to 0 first, so it wrote a 140 over a real record.
##
## The rule: a test function that calls a persisting RunConfig mutator must assign
## `RunConfig.save_path` somewhere in the same function. Restoring the value is not
## enough and is exactly what hid this -- see the two comments at those call sites.
##
## Its LIMIT, found later and by other means: the needle list names RunConfig's own
## methods, so it sees a direct call and is structurally blind to a test that reaches
## `_save()` through the game -- `Game.bank_score() -> record_score()` and
## `Game._unhandled_input() -> toggle_colorblind_safe()` both did, from this very
## file, while this test reported clean. Those needles cannot be extended by hand
## into "anything that can reach the writer"; `tools/save_persist_check.py` derives
## that set backwards from `_save()` instead, and requires the redirect once per
## script, in `setup()`. This test keeps the direct rule and adds the one thing a
## source scan cannot assert: that the redirect is actually LIVE right now.
func test_no_test_persists_through_the_players_own_save() -> String:
	# The runtime half. `setup()` at the top of this file points RunConfig away from
	# the player's save before every test method here, including this one -- so if it
	# is ever deleted or renamed, this fails on the next run rather than waiting for
	# someone to notice an mtime. Asserted against SAVE_PATH, the constant, rather
	# than a literal: the redirect has to survive the default moving.
	# (`_T` has no assert_ne, so the inequality is spelled out and the actual path is
	# carried in the message -- an assert_false alone would report only `false`.)
	var live: String = _T.assert_false(RunConfig.save_path == RunConfig.SAVE_PATH,
		"setup() has pointed RunConfig away from the player's own save for this run; "
			+ "it is at %s and SAVE_PATH is %s" % [RunConfig.save_path, RunConfig.SAVE_PATH])
	if live != "":
		return live
	var persisting: PackedStringArray = [
		"RunConfig.record_score", "RunConfig._save()", "RunConfig.record_milestones",
		"RunConfig.set_colorblind_safe", "RunConfig.set_mute_sfx", "RunConfig.set_mute_music",
		"RunConfig.store_key_bindings",
	]
	var checked: int = 0
	var offenders: PackedStringArray = []
	for path: String in ["res://test/unit/test_selftest.gd", "res://test/unit/test_economy.gd"]:
		var text: String = FileAccess.get_file_as_string(path)
		var err_read: String = _T.assert_false(text.is_empty(), "%s is readable" % path)
		if err_read != "":
			return err_read
		var name: String = ""
		var body: String = ""
		# A trailing sentinel so the final function in the file is judged too.
		for raw_line: String in (text + "\nfunc __eof():").split("\n"):
			# Comments are dropped BEFORE matching, and the first draft of this test
			# is why the rule is stated here rather than assumed. It reported three
			# offenders; two were prose -- `# RunConfig.record_score() only ever
			# raises a record` sitting between two functions, attributed to whichever
			# one came before it. A scan that reads its own explanations is the trap
			# suite_reach_check.py's header already warns about, and this walked
			# straight into it.
			var line: String = raw_line
			var hash_at: int = line.find("#")
			if hash_at >= 0:
				line = line.substr(0, hash_at)
			if line.begins_with("func "):
				if name != "":
					var mutates: bool = false
					for needle: String in persisting:
						if body.contains(needle):
							mutates = true
							break
					if mutates:
						checked += 1
						# `_with_scratch_save` is the helper that does the redirect for
						# its callee, so a lambda handed to it is covered by it.
						if not (body.contains("RunConfig.save_path =")
								or body.contains("_with_scratch_save")):
							offenders.append("%s (%s)" % [name, path.get_file()])
				name = line.substr(5).split("(")[0]
				body = ""
			else:
				body += line + "\n"
	var err: String = _T.assert_gt(checked, 0,
		"the scan actually found test functions that persist -- a zero here means the "
			+ "needles stopped matching and this test is vacuous, not that it is clean")
	if err == "":
		err = _T.assert_eq(", ".join(offenders), "",
			"every test that persists redirects RunConfig.save_path first; these do not")
	return err


# -- Pests walk rather than slide (plant-tower-defense-iue) -----------------


## All four cardinals in one place, because three of them were covered by
## accident and the fourth by nothing at all.
##
## `_update_facing()` is a four-case mapping and the suite asserted +X (in the
## gait test) and -X (via the corpse test), used +Y without checking its value,
## and never mentioned Vector2.UP anywhere. The road makes that worse rather
## than better: the shipped route runs right, down, left, down, right and never
## once travels -Y, so the `_facing = 0.0` branch has neither an assertion nor a
## single frame of exercise in a real game (plant-tower-defense-ymth).
##
## The reference frame is the art's, not the engine's: every pest SVG rests with
## its head up-screen -- beetle mandibles at y=4-14 over a carapace at cy=37,
## aphid head cy=21 over abdomen cy=36, queen antennae at y=10-16 -- which is
## what art_src/STYLE.md calls the convention and what makes rotation 0 mean
## "facing up". Assert the whole mapping so a future level with an upward run
## does not discover the untested corner the hard way.
func test_update_facing_maps_every_cardinal_to_the_art_up_screen_convention() -> String:
	var pest: Pest = _pest(Pest.APHID, Vector2.ZERO)
	var host: Node2D = _host([pest])
	await _T.instantiate_scene(host)

	# Godot 2D rotates clockwise with +Y down, so up-screen art turned +PI/2
	# points +X. Written out per case rather than computed, so the expectation is
	# a claim about the screen and not a restatement of the code under test.
	var expected: Array[Array] = [
		[Vector2.UP, 0.0, "up-screen: the art's own rest pose, unrotated"],
		[Vector2.RIGHT, PI / 2.0, "walking +X: a quarter turn clockwise"],
		[Vector2.DOWN, PI, "walking +Y: head-down, a half turn"],
		[Vector2.LEFT, -PI / 2.0, "walking -X: a quarter turn anticlockwise"],
	]
	var err: String = ""
	for row: Array in expected:
		pest._update_facing(row[0] as Vector2)
		err = _T.assert_float_eq(pest._facing, float(row[1]), 0.0001, String(row[2]))
		if err != "":
			return err

	# A diagonal resolves to its dominant axis rather than to an in-between
	# angle: the art has four poses and there is no fifth to rotate to.
	pest._update_facing(Vector2(1.0, 0.3))
	err = _T.assert_float_eq(pest._facing, PI / 2.0, 0.0001,
		"a mostly-rightward diagonal still picks the +X cardinal")
	if err != "":
		return err

	# Standing still must not spin the sprite back to a default. _advance() calls
	# this every frame, so a zero-length direction has to be a no-op or a stopped
	# pest would snap to up-screen the instant it stopped.
	pest._update_facing(Vector2.ZERO)
	return _T.assert_float_eq(pest._facing, PI / 2.0, 0.0001,
		"a zero-length direction leaves the last facing alone")


## The composition rule the whole feature rests on. Two features write
## `_sprite.rotation`, and _advance() calls _update_facing() every frame, so a
## gait that assigned rotation instead of adding to it would be erased sixty
## times a second and look exactly like a gait that was never written.
func test_the_gait_offsets_the_facing_rotation_rather_than_replacing_it() -> String:
	var pest: Pest = _pest(Pest.APHID, Vector2.ZERO)
	var host: Node2D = _host([pest])
	await _T.instantiate_scene(host)

	# Walking right: the cardinal facing _update_facing() picks for +X.
	pest._update_facing(Vector2.RIGHT)
	var err: String = _T.assert_float_eq(pest._facing, PI / 2.0, 0.0001,
		"sanity: a pest walking right faces +X")
	if err == "":
		# Mid-stride, by hand rather than by waiting on a frame -- headless never
		# pumps one and the point here is the arithmetic, not the clock.
		pest._sway = 0.1
		pest._apply_facing()
		err = _T.assert_float_eq(pest._sprite.rotation, PI / 2.0 + 0.1, 0.0001,
			"the sway is added to the facing, not written over it")
	if err == "":
		# And the frame's own facing update does not wipe it back out.
		pest._update_facing(Vector2.RIGHT)
		err = _T.assert_float_eq(pest._sprite.rotation, PI / 2.0 + 0.1, 0.0001,
			"the next _update_facing() of the same leg keeps the sway alive")
	if err == "":
		pest._update_facing(Vector2.DOWN)
		err = _T.assert_float_eq(pest._sprite.rotation, PI + 0.1, 0.0001,
			"and turning a corner moves the facing term only")
	_T.free_ui(host)
	return err


## The gate's other half. Headless is animations-off, so a pest here must sit at
## exactly the static state that shipped before the gait existed -- a bare
## cardinal rotation and the species' own sprite scale, not a transform frozen
## a quarter of the way into a stride.
func test_with_animations_off_a_pest_holds_its_bare_facing_and_scale() -> String:
	var pest: Pest = _pest(Pest.BEETLE, Vector2.ZERO)
	var host: Node2D = _host([pest])
	await _T.instantiate_scene(host)

	var err: String = _T.assert_false(GardenTheme.animations_enabled(),
		"sanity: headless is the animations-off case this test is about")
	if err == "":
		# Zeroed here rather than trusted: _pest() turns physics off, but the clock
		# below is asserted to an exact value and a baseline the settle frames chose
		# would make that assertion about the frame count instead of about _gait().
		pest._gait_time = 0.0
		for i: int in range(30):
			pest._gait(0.016)
		err = _T.assert_float_eq(pest._sway, 0.0, 0.0001, "no sway is ever accumulated")
	if err == "":
		err = _T.assert_float_eq(pest._sprite.rotation, pest._facing, 0.0001,
			"the sprite sits on its bare facing rotation")
	if err == "":
		err = _T.assert_eq(pest._sprite.scale, Vector2(pest._sprite_scale, pest._sprite_scale),
			"and on the species' own scale, unstretched")
	if err == "":
		# The clock still runs, same as Plant._wobble()'s does, so a mid-run
		# toggle picks up a phase instead of forty pests snapping from 0.
		err = _T.assert_float_eq(pest._gait_time, 30.0 * 0.016, 0.0001,
			"the gait clock advances anyway, so turning animations on mid-run is not a snap")
	_T.free_ui(host)
	return err


## Nine aphids spawned in a column should read as nine creatures. The phase is
## what does that, so it is the thing worth pinning.
func test_pests_spawned_in_a_column_walk_on_different_phases() -> String:
	var seen: Dictionary = {}
	for i: int in range(9):
		var phase: float = Pest.gait_phase(i)
		var err: String = _T.assert_true(phase >= 0.0 and phase < TAU,
			"phase %d stays on the circle" % i)
		if err != "":
			return err
		# Rounded, so "different" means visibly different rather than different
		# in the eighth decimal place.
		var key: int = int(round(phase * 20.0))
		if seen.has(key):
			return _T.assert_true(false,
				"pests %d and %d spawn on the same phase and would animate in lockstep"
					% [seen[key], i])
		seen[key] = i
	return _T.assert_eq(seen.size(), 9, "nine spawns, nine distinct phases")


## The mutation tells. Each one is a claim about how the trait reads in motion,
## and each is a pure function, so this needs no viewport at all.
func test_each_mutation_gets_its_own_gait() -> String:
	var plain_rate: float = Pest.gait_rate(Pest.GAIT_REFERENCE_SPEED, false, false)
	var err: String = _T.assert_float_eq(plain_rate, Pest.GAIT_RATE, 0.0001,
		"a pest walking at the reference speed runs the gait at exactly GAIT_RATE")
	if err == "":
		err = _T.assert_gt(Pest.gait_rate(Pest.GAIT_REFERENCE_SPEED, false, true), plain_rate,
			"a winged pest flutters faster than a plain one")
	if err == "":
		err = _T.assert_true(Pest.gait_swing(false, true) < Pest.gait_swing(false, false),
			"and shallower -- a flutter, not a bigger waggle")
	if err == "":
		err = _T.assert_true(Pest.gait_rate(Pest.GAIT_REFERENCE_SPEED, true, false) < plain_rate,
			"an armoured pest plods")
	if err == "":
		err = _T.assert_true(Pest.gait_swing(true, false) < Pest.gait_swing(false, false),
			"and rolls less, being plated")
	if err == "":
		# A pest carrying both traits gets both, exactly as markers_for() promises
		# for the drawn marks.
		err = _T.assert_float_eq(Pest.gait_swing(true, true),
			Pest.GAIT_SWING * Pest.WINGED_SWING_MULTIPLIER * Pest.ARMOURED_SWING_MULTIPLIER,
			0.0001, "two traits compose, the same way two markers do")
	return err


## The hungry lunge is a *shape* change, not a louder scuttle: cubing flattens
## the middle of the stride wave and keeps its extremes. Both halves of that are
## checked, because only having the second would also pass on a plain multiply.
func test_a_hungry_pest_lunges_rather_than_scuttling_harder() -> String:
	var err: String = _T.assert_true(
		absf(Pest.gait_stretch(1.0, true)) > absf(Pest.gait_stretch(1.0, false)),
		"at full stride a hungry pest reaches further")
	if err == "":
		err = _T.assert_true(
			absf(Pest.gait_stretch(0.4, true)) < absf(Pest.gait_stretch(0.4, false)),
			"but mid-stride it is stiller than a plain pest -- that gap is the lunge")
	if err == "":
		err = _T.assert_float_eq(Pest.gait_stretch(0.0, true), 0.0, 0.0001,
			"and the wave still crosses zero, so the body returns to its own size")
	if err == "":
		err = _T.assert_float_eq(Pest.gait_stretch(-1.0, false), -Pest.GAIT_STRETCH, 0.0001,
			"a plain pest's stretch is the plain wave, unshaped")
	return err


## Endless mode scales `speed`, and the gait rides it so a hurried pest visibly
## hurries -- but a wave-30 beetle must not blur.
func test_the_gait_rate_follows_speed_but_is_clamped_at_both_ends() -> String:
	var slow: float = Pest.gait_rate(1.0, false, false)
	var err: String = _T.assert_float_eq(slow, Pest.GAIT_RATE * Pest.GAIT_RATE_MIN, 0.0001,
		"a barely-moving pest still animates, at the floor rate")
	if err == "":
		err = _T.assert_float_eq(Pest.gait_rate(100000.0, false, false),
			Pest.GAIT_RATE * Pest.GAIT_RATE_MAX, 0.0001,
			"and an absurdly hasted one is capped rather than blurring")
	if err == "":
		var aphid_speed: float = float(Pest.SPECIES[Pest.APHID]["speed"])
		var beetle_speed: float = float(Pest.SPECIES[Pest.BEETLE]["speed"])
		err = _T.assert_gt(Pest.gait_rate(aphid_speed, false, false),
			Pest.gait_rate(beetle_speed, false, false),
			"the small fast one scuttles faster than the big slow one, with no per-species constant")
	return err


## A pest killed mid-stride leaves a corpse lying straight. Without this the
## husk keeps whatever quarter-stride lean it died on, which reads as a bug
## still leaning into a step it will never finish.
## The parts of `game/OVERLAY_GRAMMAR.md` that are numbers rather than prose
## (plant-tower-defense-cujn).
##
## That document exists because four drawn cues arrived one cycle at a time and
## turned out mostly consistent by taste rather than by rule. Most of it has to be
## prose — "a dashed ring is a remark" is not checkable — but the two-channel rule
## bottoms out in arithmetic, and arithmetic can be pinned so the document cannot
## quietly stop being true the way three sections of kanban.md did over sixty-four
## cycles.
##
## What is asserted here is only the mechanical half. A cue that obeys every number
## below and still reads wrongly is a cue this test will pass; that is what the
## document is for and why it says to re-run the grep.
func test_the_overlay_grammar_holds_where_it_is_mechanical() -> String:
	# ARMED is a doubled line width, in both cues that have an armed state. Colour
	# alone would fail the two-channel rule, so the width is the half that has to
	# survive the hue being discarded.
	var err: String = _T.assert_float_eq(SelectionMarker.WARNING_LINE_WIDTH,
		SelectionMarker.LINE_WIDTH * 2.0, 0.0001,
		"the selection brackets double their width when armed")
	if err == "":
		err = _T.assert_float_eq(SoleCoverMarks.WARNING_RING_WIDTH,
			SoleCoverMarks.RING_WIDTH * 2.0, 0.0001,
			"and the sole-cover rings double theirs by the same factor")
	if err == "":
		err = _T.assert_eq(SoleCoverMarks.WARNING_COLOR, SelectionMarker.WARNING_COLOR,
			("in the same red -- two reds on one plant would read as two different "
				+ "warnings"))
	# A MARKED CELL is distinguished from a REACH by size, not by shape: both are
	# solid rings, and the table in OVERLAY_GRAMMAR.md says so explicitly because a
	# fifth cue copying "solid ring" from the wrong one inherits the wrong meaning.
	if err == "":
		err = _T.assert_gt(Game.engagement_reach(PlantCatalog.CORN),
			SoleCoverMarks.RING_RADIUS * 4.0,
			("a plant's reach ring is many times a marked cell's ring -- that size gap "
				+ "IS the distinction, since both are solid rings"))
	# The holds-nothing ring sits outside the brackets it shares a plant with, or
	# the two read as one mark rather than as a remark about a subject.
	if err == "":
		err = _T.assert_gt(SoleCoverMarks.ALONE_RADIUS, SelectionMarker.HALF,
			"the holds-nothing remark clears the subject brackets")
	# A hover is a promise of selection: same bracket shape, one size larger.
	if err == "":
		err = _T.assert_gt(PlacementPreview.PREVIEW_HALF, SelectionMarker.HALF,
			("the preview's brackets are larger than the selection's, so the two are "
				+ "distinguishable when a hover crosses an already-selected plant"))
	return err


## A corpse says what killed it (plant-tower-defense-f5z6).
##
## Three deaths that used to look identical: chewed by a Chomp, blown up by a seed
## bomb, and shot. The plain straight corpse stays the DEFAULT — a kernel kill and
## any unattributed kill both get it — so the two that differ read as remarkable
## rather than as noise, and the sibling test below still passes unchanged.
##
## Both differences are shape, not colour, which is this project's standing rule
## and is also what makes them assertable at all: a rotation and a scale are
## numbers, where "it looks chewed" is not.
##
## The squash is on X and that is not arbitrary — see corpse_scale()'s header. The
## sprite rests head-up-screen and `rotation` carries the facing, so the body's
## long axis is always local Y; squashing Y would be a pest that shrank, squashing
## X is one that was closed on.
func test_a_corpse_lies_differently_depending_on_what_killed_it() -> String:
	var pest: Pest = _pest(Pest.APHID, Vector2.ZERO)
	var host: Node2D = _host([pest])
	await _T.instantiate_scene(host)
	pest._update_facing(Vector2.LEFT)
	var facing: float = pest._facing
	var full: float = pest._sprite_scale

	# Default: unchanged from what the sibling test pins, so a kernel kill and an
	# unattributed one both still lie straight.
	var err: String = _T.assert_float_eq(pest.corpse_rotation(), facing, 0.0001,
		"an unattributed corpse lies on its facing")
	if err == "":
		err = _T.assert_float_eq(pest.corpse_scale().x, full, 0.0001,
			"and at full width")
	# Bitten: narrower, same angle.
	if err == "":
		pest._death_cause = Pest.DEATH_BITTEN
		# assert_gt with the arguments the other way round: the helper set is
		# assert_eq / false / float_eq / gt / gte / margin / true, and there is no
		# assert_lt. Calling one that does not exist aborts the method, and an
		# aborted test returns "" — which run_tests.gd reports as [PASS]. This exact
		# line did that until run_tests.py caught the SCRIPT ERROR the return value
		# cannot carry.
		err = _T.assert_gt(full, pest.corpse_scale().x,
			"a chewed corpse is narrower than a whole one")
	if err == "":
		err = _T.assert_float_eq(pest.corpse_scale().y, full, 0.0001,
			("but the same LENGTH -- squashing the long axis would read as a pest that "
				+ "shrank rather than one that was closed on"))
	if err == "":
		err = _T.assert_float_eq(pest.corpse_rotation(), facing, 0.0001,
			"and still lies on its facing -- a bite does not move the body")
	# Blasted: tilted off the facing, same size.
	if err == "":
		pest._death_cause = Pest.DEATH_BLASTED
		err = _T.assert_true(not is_equal_approx(pest.corpse_rotation(), facing),
			"a blasted corpse is thrown off the line it was walking")
	if err == "":
		err = _T.assert_float_eq(pest.corpse_scale().x, full, 0.0001,
			"but is not squashed -- that is the bite's signature, not the bomb's")
	# The tilt must not land on a cardinal: _update_facing owns those four, and a
	# corpse sitting at one would read as a living pest that simply stopped.
	if err == "":
		var quarter: float = fmod(absf(Pest.BLASTED_TILT), PI / 2.0)
		err = _T.assert_gt(minf(quarter, PI / 2.0 - quarter), 0.05,
			("the tilt is clear of the four cardinals _update_facing uses (%.2f rad)")
				% Pest.BLASTED_TILT)
	# And the cause survives the damage path, not just a direct kill().
	if err == "":
		pest._death_cause = &""
		pest.take_damage(pest.max_health * 2.0, Pest.DEATH_BLASTED)
		err = _T.assert_eq(pest._death_cause, Pest.DEATH_BLASTED,
			"take_damage carries the cause through to the corpse")
	if err == "":
		err = _T.assert_false(pest.is_alive(), "and that damage really killed it")
	_T.free_ui(host)
	return err


func test_a_pest_killed_mid_stride_leaves_a_straight_corpse() -> String:
	var pest: Pest = _pest(Pest.APHID, Vector2.ZERO)
	var host: Node2D = _host([pest])
	await _T.instantiate_scene(host)

	pest._update_facing(Vector2.LEFT)
	# Hand-set rather than pumped: headless never runs _gait()'s applied half, and
	# the claim here is about what kill() undoes, not about what set it.
	pest._sway = 0.12
	pest._apply_facing()
	pest._sprite.scale = Vector2(pest._sprite_scale * 0.9, pest._sprite_scale * 1.1)

	pest.kill()
	var err: String = _T.assert_float_eq(pest._sprite.rotation, -PI / 2.0, 0.0001,
		"the corpse lies on its facing -- still facing the way it was walking, but not mid-lean")
	if err == "":
		err = _T.assert_eq(pest._sprite.scale, Vector2(pest._sprite_scale, pest._sprite_scale),
			"and back at its own scale, not frozen mid-stretch")
	if err == "":
		err = _T.assert_float_eq(pest._sway, 0.0, 0.0001, "with the sway cleared, not merely unread")
	_T.free_ui(host)
	return err


func test_only_a_boss_answers_the_split_question_at_all() -> String:
	## The accessors, and the reason they are accessors: SPECIES rows for the two
	## ordinary pests carry no split keys at all, so anything reading the raw
	## Dictionary would have to guard at every call site or error on a beetle.
	var err: String = _T.assert_eq(String(Pest.split_species(Pest.APHID)), "",
		"an aphid bursts into nothing")
	if err == "":
		err = _T.assert_eq(Pest.split_count(Pest.APHID), 0, "and so counts zero of it")
	if err == "":
		err = _T.assert_eq(String(Pest.split_species(Pest.BEETLE)), "", "nor does a beetle")
	if err == "":
		err = _T.assert_eq(Pest.split_count(Pest.BEETLE), 0, "nor count any")
	if err == "":
		err = _T.assert_eq(String(Pest.split_species(&"no_such_pest")), "",
			"and a species that does not exist answers the same way rather than erroring")
	if err == "":
		err = _T.assert_eq(String(Pest.split_species(Pest.QUEEN)), String(Pest.APHID),
			"the queen bursts into aphids")
	if err == "":
		err = _T.assert_gt(Pest.split_count(Pest.QUEEN), 1,
			"into more than one of them, or it is a death animation rather than a mechanic")
	return err


func test_the_queens_sprite_counts_out_the_brood_it_bursts_into() -> String:
	## The picture and the number are the same claim. pest_queen.svg draws the eggs
	## on her back so a player can read "three" off the board before finding out the
	## hard way; if split_count moves and the art does not, the sprite starts lying
	## and nothing else in the project would notice.
	var path: String = ProjectSettings.globalize_path("res://").path_join("art_src/pest_queen.svg")
	var svg: String = FileAccess.get_file_as_string(path)
	var err: String = _T.assert_gt(svg.length(), 0, "art_src/pest_queen.svg is readable")
	if err != "":
		return err
	var marker: String = "<!-- the three eggs she bursts into -->"
	var at: int = svg.find(marker)
	err = _T.assert_true(at >= 0,
		"the egg group is still marked in the source (a renamed comment makes this test vacuous)")
	if err != "":
		return err
	var group_end: int = svg.find("</g>", at)
	err = _T.assert_true(group_end > at, "the egg group closes")
	if err != "":
		return err
	var group: String = svg.substr(at, group_end - at)
	return _T.assert_eq(group.count("<ellipse"), Pest.split_count(Pest.QUEEN),
		"the sprite draws exactly the %d eggs Pest.SPECIES says she bursts into"
			% Pest.split_count(Pest.QUEEN))


func test_the_boss_is_a_species_and_not_a_fourth_mutation() -> String:
	## The issue says this in as many words. A queen must not be reachable through
	## apply_mutation, must not appear in the wave director's mutation pool, and must
	## wear none of the three mutation marks — those mean "this ordinary pest is
	## harder to remove", and a boss is not an ordinary pest wearing a badge.
	var queen: Pest = _pest(Pest.QUEEN, Vector2.ZERO)
	var err: String = _T.assert_eq(queen.markers().size(), 0,
		"an unmutated queen wears no mutation mark")
	if err == "":
		err = _T.assert_false(queen.is_armoured or queen.is_winged or queen.is_hungry,
			"and carries none of the three traits")
	if err == "":
		err = _T.assert_eq(String(queen.mutation), "", "and has no mutation at all")
	queen.free()
	if err != "":
		return err
	for which: StringName in WaveDirector.MUTATIONS:
		err = _T.assert_false(Pest.SPECIES.has(which),
			"no mutation shares a name with a species (%s)" % which)
		if err != "":
			return err
	return _T.assert_false(WaveDirector.MUTATIONS.has(Pest.QUEEN),
		"and the queen is not in the pool a wave rolls traits out of")


func test_a_queen_is_a_boss_sized_pest_on_every_axis_that_matters() -> String:
	## The stat block, asserted as relationships rather than as literals: a boss that
	## is merely a big number is one balance pass away from being a beetle again.
	var queen: Dictionary = Pest.SPECIES[Pest.QUEEN]
	var beetle: Dictionary = Pest.SPECIES[Pest.BEETLE]
	var err: String = _T.assert_gt(float(queen["health"]), float(beetle["health"]) * 4.0,
		"she carries several beetles' worth of health (%.0f vs %.0f)"
			% [float(queen["health"]), float(beetle["health"])])
	if err == "":
		err = _T.assert_true(float(queen["speed"]) < float(beetle["speed"]),
			"walks slower than the slowest ordinary pest, so the wave arrives around her")
	if err == "":
		err = _T.assert_gt(float(queen["chew_seconds"]), float(beetle["chew_seconds"]) * 3.0,
			"and a Chomp that closes on her is shut for the rest of the wave (%.1fs vs %.1fs)"
				% [float(queen["chew_seconds"]), float(beetle["chew_seconds"])])
	if err == "":
		err = _T.assert_gt(float(queen["scale"]), float(beetle["scale"]),
			"she is drawn bigger than anything else on the board")
	if err == "":
		err = _T.assert_gt(int(queen["seeds"]), int(beetle["seeds"]) * 3,
			"and pays out like the wave she is")
	if err == "":
		# The sprite is still on STYLE.md's canvas — the size comes from `scale`,
		# not from a second canvas nobody would notice drifting.
		err = _T.assert_eq(String(queen["texture"]), "res://assets/sprites/pest_queen.png",
			"and she has her own sprite rather than a tinted aphid")
	return err


func test_a_queen_survives_one_maxed_corn_cobbler_and_falls_to_four() -> String:
	## The balance band the issue names, as arithmetic off the real constants.
	##
	## Measured conservatively: only the ON-AXIS kernel is counted (at long range the
	## off-axis pairs miss — see CornCobbler.single_target_dps), and the exposure is
	## the chord a cob's ring cuts across the lane one cell away, divided by her own
	## walking speed. So this is close to the LEAST damage four maxed cobs can do to
	## her while she crosses their reach, and the most one cob can.
	var reach: float = CornCobbler.RANGE
	var chord: float = 2.0 * sqrt(reach * reach - float(Board.CELL * Board.CELL))
	var speed: float = float(Pest.SPECIES[Pest.QUEEN]["speed"])
	var health: float = float(Pest.SPECIES[Pest.QUEEN]["health"])
	var seconds_in_reach: float = chord / speed
	var per_cob: float = CornCobbler.single_target_dps(CornCobbler.LEVELS.size(), reach) * seconds_in_reach
	var err: String = _T.assert_gt(per_cob, 0.0,
		"sanity: a maxed cob does damage at the edge of its own ring")
	if err == "":
		err = _T.assert_gt(health, per_cob * 2.0,
			("two maxed Corn Cobblers do not take a queen (%.0f damage against %.0f health) —"
				+ " a boss one plant answers is not a boss") % [per_cob * 2.0, health])
	if err == "":
		err = _T.assert_gt(per_cob * 4.0, health,
			("four do (%.0f against %.0f) — a boss the whole garden cannot answer is not"
				+ " shipped either") % [per_cob * 4.0, health])
	return err


func test_a_queen_bursts_into_her_brood_where_she_fell() -> String:
	## The mechanic. Killed mid-road, she leaves exactly split_count() aphids, and
	## they are standing where she was rather than at the entrance — which is the
	## whole of why killing her late costs the player something.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	var queen: Pest = _spawn_and_take(game, Pest.QUEEN)
	err = _T.assert_true(queen != null, "a queen was staged")
	if err != "":
		_T.free_ui(game)
		return err

	# Walk her a third of the way down the road, so "where she fell" is somewhere
	# an entrance spawn could not be mistaken for.
	var route: PackedVector2Array = game.board.route()
	var leg: int = int(route.size() / 3)
	queen.enter_road_at(route[leg], leg)
	var fell_at: Vector2 = queen.position
	var before: Dictionary = {}
	for node: Node in game.get_tree().get_nodes_in_group("pests"):
		before[node.get_instance_id()] = true

	queen.kill()

	var brood: Array[Pest] = []
	for node: Node in game.get_tree().get_nodes_in_group("pests"):
		var pest := node as Pest
		if pest != null and not before.has(pest.get_instance_id()):
			brood.append(pest)
	err = _T.assert_eq(brood.size(), Pest.split_count(Pest.QUEEN),
		"she left exactly the brood her species declares")
	if err == "":
		for child: Pest in brood:
			err = _T.assert_eq(String(child.species), String(Pest.split_species(Pest.QUEEN)),
				"and every one of them is the species she bursts into")
			if err == "":
				err = _T.assert_true(child.position.distance_to(fell_at) <= float(Board.CELL) * 0.5,
					("standing inside the cell she died on (%.0f px from %s), not back at"
						+ " the entrance") % [child.position.distance_to(fell_at), fell_at])
			if err == "":
				err = _T.assert_eq(child.route_leg(), queen.route_leg(),
					"walking the leg she was walking, so it inherits her place on the road")
			if err == "":
				err = _T.assert_gt(child.progress(), 0.0,
					"and it is genuinely part-way down the road, not at progress zero")
			if err != "":
				break
	_T.free_ui(game)
	return err


func test_a_queen_that_reaches_the_exit_leaves_no_brood_at_all() -> String:
	## The asymmetry that turns the mechanic into a decision. An escape already
	## costs a bed; three more aphids materialising past the exit would be a
	## punishment with nowhere left to walk, and — worse — it would mean letting her
	## through was cheaper than killing her badly, which inverts the whole thing.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	var queen: Pest = _spawn_and_take(game, Pest.QUEEN)
	err = _T.assert_true(queen != null, "a queen was staged")
	if err != "":
		_T.free_ui(game)
		return err
	var lives_before: int = game.lives
	var before: Dictionary = {}
	for node: Node in game.get_tree().get_nodes_in_group("pests"):
		before[node.get_instance_id()] = true

	queen._escape()

	var appeared: int = 0
	for node: Node in game.get_tree().get_nodes_in_group("pests"):
		if not before.has(node.get_instance_id()):
			appeared += 1
	err = _T.assert_eq(appeared, 0, "an escaped queen leaves nothing behind her")
	if err == "":
		err = _T.assert_eq(game.lives, lives_before - 1, "she still took the bed she reached")
	_T.free_ui(game)
	return err


func test_enter_road_at_drops_a_pest_onto_the_leg_it_is_told_and_clamps_the_rest() -> String:
	## The primitive the brood rides on, checked on its own: it is the only way any
	## pest in this game starts anywhere but the entrance, so a leg it silently got
	## wrong would be an escape or a stall with no error anywhere.
	var route := PackedVector2Array([
		Vector2(0, 0), Vector2(64, 0), Vector2(128, 0), Vector2(128, 64), Vector2(128, 128),
	])
	var pest := Pest.new()
	pest.setup(Pest.APHID, route)
	pest.set_physics_process(false)
	pest.enter_road_at(Vector2(100, 0), 2)
	var err: String = _T.assert_eq(pest.route_leg(), 2, "it is walking toward the leg it was given")
	if err == "":
		err = _T.assert_true(pest.position.is_equal_approx(Vector2(100, 0)),
			"and standing where it was put, got %s" % pest.position)
	if err == "":
		err = _T.assert_gt(pest.progress(), 0.0, "so it reports real progress down the road")
	if err == "":
		# Past the end would make the very next step an escape by a pest that never
		# walked; before the start would send it back to a waypoint it is past.
		pest.enter_road_at(Vector2(128, 128), 99)
		err = _T.assert_eq(pest.route_leg(), route.size() - 1,
			"a leg past the end is clamped to the last one rather than escaping on the spot")
	if err == "":
		pest.enter_road_at(Vector2.ZERO, -5)
		err = _T.assert_eq(pest.route_leg(), 1, "and a leg before the start is clamped forward")
	pest.free()
	return err


func test_the_road_budget_counts_the_bodies_a_boss_becomes() -> String:
	## peak_simultaneous_pests() sweeps the schedule and never kills anything, which
	## used to be the pessimistic reading. A boss inverts it: the ONLY way to put her
	## brood on the road is to kill her, so "nothing dies" stopped being the worst
	## case for headcount the moment a queen entered the table.
	var err: String = _T.assert_eq(WaveDirector.brood_headroom_for(1), 0,
		"a wave with no boss in it needs no headroom")
	if err != "":
		return err
	var boss_waves: int = 0
	for wave: int in range(1, WaveDirector.WAVES.size() + 1):
		var queens: int = 0
		for group: Dictionary in WaveDirector.groups_for(wave):
			if StringName(group["species"]) == Pest.QUEEN:
				queens += int(group["count"])
		if queens <= 0:
			err = _T.assert_eq(WaveDirector.brood_headroom_for(wave), 0,
				"wave %d has no queen and so no extra bodies" % wave)
			if err != "":
				return err
			continue
		boss_waves += 1
		err = _T.assert_eq(WaveDirector.brood_headroom_for(wave),
			queens * (Pest.split_count(Pest.QUEEN) - 1),
			("wave %d books room for what its %d queen(s) become — count - 1 each, since"
				+ " the queen herself is gone by then") % [wave, queens])
		if err != "":
			return err
	err = _T.assert_gt(boss_waves, 0,
		"the campaign actually has boss waves to check (a zero here is a vacuous pass)")
	if err == "":
		# And the headroom is really folded into the number the budget is graded on,
		# not merely available beside it.
		var finale: int = WaveDirector.WAVES.size()
		err = _T.assert_gte(WaveDirector.peak_simultaneous_pests(finale),
			WaveDirector.brood_headroom_for(finale),
			"the finale's peak includes its own brood headroom")
	return err


func test_every_campaign_wave_stays_inside_the_road_budget_brood_included() -> String:
	## The campaign is now the half of the game that spends the road budget — the
	## endless column is paced apart from its first wave, so it peaks at 29 of 40
	## while the finale lands on 40 exactly. Sweeping the fixed table is therefore no
	## longer a formality; it is where the ceiling is actually tested.
	var ceiling: int = WaveDirector.SIMULTANEOUS_PEST_CEILING
	var worst: int = 0
	var worst_wave: int = 0
	var checked: int = 0
	for wave: int in range(1, WaveDirector.WAVES.size() + 1):
		var peak: int = WaveDirector.peak_simultaneous_pests(wave)
		var err: String = _T.assert_gte(ceiling, peak,
			"campaign wave %d paces %d pests onto the road, inside the %d ceiling"
				% [wave, peak, ceiling])
		if err != "":
			return err
		if peak > worst:
			worst = peak
			worst_wave = wave
		checked += 1
	var err2: String = _T.assert_gt(checked, 8,
		"the sweep walked a campaign worth having (%d waves)" % checked)
	if err2 == "":
		err2 = _T.assert_eq(worst, ceiling,
			("and one of them reaches it — wave %d at %d of %d. A ceiling nothing in the"
				+ " shipped game ever touches is decoration, and `cmd budgets` grades this"
				+ " one on the measured peak") % [worst_wave, worst, ceiling])
	return err2


func test_the_campaign_builds_to_its_boss_rather_than_opening_with_one() -> String:
	## Where the queens sit in the table, as a shape rather than as three wave
	## numbers: nothing before the halfway mark, and the last wave is a boss wave.
	## A queen dropped into wave 3 would pass every arithmetic check in this file
	## and ruin the campaign.
	var table: int = WaveDirector.WAVES.size()
	var boss_waves: Array[int] = []
	for wave: int in range(1, table + 1):
		for group: Dictionary in WaveDirector.groups_for(wave):
			if StringName(group["species"]) == Pest.QUEEN:
				boss_waves.append(wave)
				break
	var err: String = _T.assert_gt(boss_waves.size(), 1,
		"the campaign has more than one boss wave (got %s)" % [boss_waves])
	if err == "":
		err = _T.assert_gt(boss_waves[0], table / 2,
			"the first queen arrives in the second half of the campaign, at wave %d of %d"
				% [boss_waves[0], table])
	if err == "":
		err = _T.assert_eq(boss_waves[boss_waves.size() - 1], table,
			"and the finale is a boss wave")
	if err == "":
		err = _T.assert_gt(WaveDirector.threat_for(table), WaveDirector.threat_for(boss_waves[0]),
			"which prices above the first one rather than merely repeating it")
	if err != "":
		return err
	# Campaign only, on purpose — see _endless_groups for why a periodic boss would
	# break the two invariants endless is built on.
	for wave: int in [table + 1, table + 7, 100, 500]:
		for group: Dictionary in WaveDirector.groups_for(wave):
			err = _T.assert_false(StringName(group["species"]) == Pest.QUEEN,
				"endless wave %d sends no queen" % wave)
			if err != "":
				return err
	return err


func test_a_queen_floats_her_health_bar_clear_of_her_own_sprite() -> String:
	## She is drawn at 1.45x, so the bar every other pest wears 30 px up would be
	## painted across her back — the one readout a boss fight is about, hidden
	## inside the boss. And the fix must move exactly one sprite: an aphid at 0.72x
	## must not have its bar slide down into its body.
	var queen_scale: float = float(Pest.SPECIES[Pest.QUEEN]["scale"])
	var aphid_scale: float = float(Pest.SPECIES[Pest.APHID]["scale"])
	var err: String = _T.assert_true(Pest.health_bar_top_for(queen_scale) < Pest.HEALTH_BAR_TOP,
		"the queen's bar floats higher than the default (%.1f vs %.1f)"
			% [Pest.health_bar_top_for(queen_scale), Pest.HEALTH_BAR_TOP])
	if err == "":
		err = _T.assert_true(absf(Pest.health_bar_top_for(queen_scale))
				> Pest.SPRITE_HALF * queen_scale * 0.9,
			"and clears most of her own 1.45x silhouette rather than sitting inside it")
	if err == "":
		err = _T.assert_float_eq(Pest.health_bar_top_for(aphid_scale), Pest.HEALTH_BAR_TOP, 0.0001,
			"while a small pest keeps the bar exactly where it has always been")
	if err == "":
		err = _T.assert_float_eq(Pest.health_bar_top_for(1.0), Pest.HEALTH_BAR_TOP, 0.0001,
			"and so does a beetle")
	return err


## Every live seed bomb on the board, minus the ones already there.
##
## The group is tree-global, so `get_nodes_in_group("seed_bombs")` can hand back a
## bomb another test fired and never freed — the exact defect
## tools/group_leak_check.py exists for, and the one
## test_kernels_launch_from_the_cob_on_an_offset_layer was rewritten to dodge.
## Every caller here diffs rather than counts.
func _bomb_ids(node: Node) -> Dictionary:
	var out: Dictionary = {}
	for bomb: Node in node.get_tree().get_nodes_in_group("seed_bombs"):
		out[bomb.get_instance_id()] = true
	return out


func _bombs_since(node: Node, before: Dictionary) -> Array[SeedBomb]:
	var out: Array[SeedBomb] = []
	for bomb: Node in node.get_tree().get_nodes_in_group("seed_bombs"):
		if not before.has(bomb.get_instance_id()) and bomb is SeedBomb:
			out.append(bomb as SeedBomb)
	return out


func _idle_dandelion(at: Vector2 = Vector2.ZERO) -> Dandelion:
	var plant := Dandelion.new()
	plant.position = at
	return plant


## Stops a hosted Dandelion acting on its own and puts its head back to full.
##
## MUST be called AFTER `instantiate_scene`, and calling `set_physics_process(false)`
## before hosting is not a substitute — Godot re-enables physics processing at
## NOTIFICATION_READY for any script that declares `_physics_process`, so the flag
## set on an unparented node is overwritten the moment it enters the tree. A
## loaded head beside a pest then fires during the harness's settle frames and
## every reading afterwards is of a plant that had already emptied itself: the
## green-for-the-wrong-reason shape tools/settle_read_check.py is about, and it
## cost this test one round trip. test_combat's cob does the same thing one line
## later with `corn._cooldown = 0.0`, for the same reason.
func _quiesce_dandelion(plant: Dandelion) -> void:
	plant.set_physics_process(false)
	plant._fluff = Dandelion.FLUFF_MAX
	plant._shot_cooldown = 0.0
	plant._since_shot = Dandelion.REGROW_DELAY
	plant._regrow_left = Dandelion.FLUFF_REGROW_SECONDS
	plant._volley_open = true


## The same fix on the other side of the board: a hosted pest walks its route
## during the settle frames, so a blast measured against where it was PUT is off
## by a fraction of a pixel and the falloff no longer reads as exactly 1.0.
func _park(pest: Pest, at: Vector2) -> void:
	pest.set_physics_process(false)
	pest.position = at


## A pest standing `leg` of `legs` down a straight road, so `progress()` is
## something other than 1.0. `_pest()` builds a two-point route, which puts every
## pest at the exit — fine for a range test and useless for a targeting one.
func _pest_partway(species: StringName, at: Vector2, leg: int, legs: int) -> Pest:
	var route := PackedVector2Array()
	for i: int in range(legs + 1):
		route.append(at + Vector2(float(i) * 32.0, 0.0))
	var pest := Pest.new()
	pest.setup(species, route)
	pest.position = at
	pest._leg = leg
	pest.set_physics_process(false)
	return pest


func test_the_dandelion_has_one_drawn_frame_for_every_seed_it_can_hold() -> String:
	## The animation is a lookup, not a mapping: FLUFF_TEXTURES is indexed by the
	## fluff count directly, so a missing frame is an out-of-range read rather than
	## a picture that quietly stops changing.
	var err: String = _T.assert_eq(Dandelion.FLUFF_TEXTURES.size(), Dandelion.FLUFF_MAX + 1,
		"one frame per fluff count from 0 to FLUFF_MAX, so texture_for_fluff() is a plain index")
	if err != "":
		return err
	var seen: Dictionary = {}
	for fluff: int in range(Dandelion.FLUFF_MAX + 1):
		var path: String = Dandelion.texture_for_fluff(fluff)
		err = _T.assert_true(ResourceLoader.exists(path),
			"the frame for %d seed(s) (%s) is on disk — a missing one loads as null and the head goes invisible"
				% [fluff, path])
		if err == "":
			err = _T.assert_false(seen.has(path),
				"%d seed(s) gets a frame of its own (%s), not one already used" % [fluff, path])
		if err != "":
			return err
		seen[path] = true
	err = _T.assert_eq(Dandelion.texture_for_fluff(Dandelion.FLUFF_MAX),
		PlantCatalog.texture_path(PlantCatalog.DANDELION),
		"a full head wears the sprite the catalogue and the plant bar show")
	if err == "":
		# Out of range clamps in both directions rather than crashing: a caller
		# reasoning about a hypothetical count still gets a picture back.
		err = _T.assert_eq(Dandelion.texture_for_fluff(-3), Dandelion.texture_for_fluff(0),
			"below zero clamps to the bald frame")
	if err == "":
		err = _T.assert_eq(Dandelion.texture_for_fluff(99),
			Dandelion.texture_for_fluff(Dandelion.FLUFF_MAX),
			"and above FLUFF_MAX clamps to the full one")
	return err


func test_a_volley_opens_at_two_seeds_and_stays_open_until_the_head_is_bald() -> String:
	## The hysteresis, as arithmetic. A plain `fluff >= VOLLEY_MIN_FLUFF` test
	## would stop the volley the moment it dropped to one seed, so the head would
	## oscillate between two and one and never reach the bald frame — which is the
	## entire animation.
	var err: String = _T.assert_gt(Dandelion.VOLLEY_MIN_FLUFF, 1,
		"a volley is more than one seed, or the rule is not a rule")
	if err == "":
		err = _T.assert_gte(Dandelion.FLUFF_MAX, Dandelion.VOLLEY_MIN_FLUFF,
			"and the head can actually hold a whole volley")
	if err == "":
		err = _T.assert_true(Dandelion.volley_open(Dandelion.FLUFF_MAX, false),
			"a full head opens fire without having been open")
	if err == "":
		err = _T.assert_true(Dandelion.volley_open(Dandelion.VOLLEY_MIN_FLUFF, false),
			"and so does one holding exactly a volley")
	if err == "":
		err = _T.assert_false(Dandelion.volley_open(Dandelion.VOLLEY_MIN_FLUFF - 1, false),
			"one seed short does NOT open — that is what banks the burst")
	if err == "":
		err = _T.assert_true(Dandelion.volley_open(1, true),
			"but a volley already under way keeps going down to its last seed")
	if err == "":
		err = _T.assert_false(Dandelion.volley_open(0, true),
			"and closes at bald, so every reload starts from empty")
	return err


func test_a_dandelion_empties_its_head_seed_by_seed_and_grows_it_back() -> String:
	## The feature the issue is named for, on one plant: the count falls one seed
	## at a time, the head stops firing when it is bald, and it fills back up on
	## its own clock.
	var plant: Dandelion = _idle_dandelion(Vector2(160, 160))
	var aphid: Pest = _pest(Pest.APHID, Vector2(220, 160))
	var host: Node2D = _host([plant, aphid])
	await _T.instantiate_scene(host)
	_quiesce_dandelion(plant)
	_park(aphid, Vector2(220, 160))
	var pests: Array[Pest] = [aphid]
	var none: Array[Pest] = []

	var err: String = _T.assert_eq(plant.fluff(), Dandelion.FLUFF_MAX, "a fresh head is full")
	if err == "":
		err = _T.assert_true(plant.is_volley_open(), "and is willing to fire")
	var fired: int = 0
	while err == "" and plant.fluff() > 0 and fired < Dandelion.FLUFF_MAX + 2:
		var before: int = plant.fluff()
		# One shot per call: SHOT_INTERVAL is the gap between seeds of the same
		# volley, so a delta that size cannot deliver two.
		plant._act(Dandelion.SHOT_INTERVAL, pests)
		fired += 1
		err = _T.assert_eq(plant.fluff(), before - 1,
			"shot %d took exactly one seed off the head (%d -> %d)" % [fired, before, plant.fluff()])
	if err == "":
		err = _T.assert_eq(fired, Dandelion.FLUFF_MAX,
			"a full head is emptied in FLUFF_MAX shots and no more")
	if err == "":
		err = _T.assert_false(plant.is_volley_open(), "a bald head has closed its volley")
	if err == "":
		# It must throw nothing while it is inside the regrow delay, however much
		# it is asked to. Stepping by LESS than REGROW_DELAY proves the gate.
		var bombs_before: Dictionary = _bomb_ids(host)
		plant._act(Dandelion.REGROW_DELAY * 0.5, pests)
		err = _T.assert_eq(_bombs_since(host, bombs_before).size(), 0,
			"a bald head throws nothing while it is still growing")
	if err == "":
		err = _T.assert_eq(plant.fluff(), 0, "and has grown nothing inside the delay either")
	if err == "":
		plant._act(Dandelion.REGROW_DELAY * 0.5 + Dandelion.FLUFF_REGROW_SECONDS, none)
		err = _T.assert_eq(plant.fluff(), 1, "past the delay it grows a seed back")
	if err == "":
		err = _T.assert_false(plant.is_volley_open(),
			"one seed is under VOLLEY_MIN_FLUFF, so it is banked rather than spent")
	if err == "":
		# A single long step must grow everything it earned rather than capping at
		# one — a devtools step-time, or a stalled frame, is exactly this shape.
		plant._act(Dandelion.FLUFF_REGROW_SECONDS * float(Dandelion.FLUFF_MAX), none)
		err = _T.assert_eq(plant.fluff(), Dandelion.FLUFF_MAX,
			"a long step grows every seed it earned, not just the next one")
	if err == "":
		err = _T.assert_true(plant.is_volley_open(), "and the head is armed again")
	if err == "":
		err = _T.assert_float_eq(plant.seconds_until_armed(), 0.0, 0.001,
			"a full head reports itself ready rather than counting down to nothing")
	_T.free_ui(host)
	return err


func test_the_dandelions_drawn_head_follows_its_seed_count() -> String:
	## The other half of the same claim, and the half `_fluff` cannot make: the
	## PICTURE changes. Driven through a really placed plant, because the sprite
	## only exists once Plant.setup() has built it.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.unlocked.append(PlantCatalog.DANDELION)
	game.bank.add_seeds(500)
	var cell: Vector2i = _grass(game)
	var refusal: String = game.place_plant(PlantCatalog.DANDELION, cell)
	var err: String = _T.assert_eq(refusal, "", "the dandelion can be planted on grass")
	var plant: Dandelion = null
	if err == "":
		plant = game.plant_at(cell) as Dandelion
		err = _T.assert_true(plant != null,
			"and Game._new_plant built a Dandelion, not the Corn Cobbler its match falls through to")
	if err == "":
		plant.set_physics_process(false)
		err = _T.assert_eq(plant.head_texture_path(),
			Dandelion.texture_for_fluff(Dandelion.FLUFF_MAX),
			"a freshly planted head wears the full frame")
	var aphid: Pest = null
	if err == "":
		aphid = _spawn_and_take(game, Pest.APHID)
		err = _T.assert_true(aphid != null, "there is a pest to throw at")
	if err == "":
		aphid.set_physics_process(false)
		aphid.position = plant.position + Vector2(40, 0)
		var pests: Array[Pest] = [aphid]
		var seen: Array[String] = []
		while err == "" and plant.fluff() > 0:
			plant._act(Dandelion.SHOT_INTERVAL, pests)
			var path: String = plant.head_texture_path()
			err = _T.assert_eq(path, Dandelion.texture_for_fluff(plant.fluff()),
				"at %d seed(s) the head wears the frame drawn for %d" % [plant.fluff(), plant.fluff()])
			if err == "":
				err = _T.assert_false(seen.has(path),
					"and it is a frame it has not already worn this volley (%s)" % path)
			seen.append(path)
		if err == "":
			err = _T.assert_eq(seen.size(), Dandelion.FLUFF_MAX,
				"the head went through FLUFF_MAX distinct pictures emptying itself")
		if err == "":
			err = _T.assert_eq(plant.head_texture_path(), Dandelion.texture_for_fluff(0),
				"and finished on the bald one")
	_T.free_ui(game)
	return err


func test_a_seed_bomb_arcs_to_a_point_instead_of_travelling_a_direction() -> String:
	## The difference from a Kernel, asserted rather than described: a kernel is a
	## direction and a speed, this is a destination and a clock. And the seed has
	## to leave the head in SIBLING space — the Entities layer is offset by the top
	## bar, so a bomb seeded from `global_position` lands a bar-height low while
	## every pest and plant on the board agrees with each other about it.
	var plant: Dandelion = _idle_dandelion(Vector2(160, 160))
	var aphid: Pest = _pest(Pest.APHID, Vector2(280, 160))
	var host: Node2D = _host([plant, aphid])
	host.position = Vector2(0, 72)
	await _T.instantiate_scene(host)
	_quiesce_dandelion(plant)
	_park(aphid, Vector2(280, 160))
	var pests: Array[Pest] = [aphid]

	var before: Dictionary = _bomb_ids(host)
	plant._act(Dandelion.SHOT_INTERVAL, pests)
	var thrown: Array[SeedBomb] = _bombs_since(host, before)
	var err: String = _T.assert_eq(thrown.size(), 1, "one seed left the head")
	if err != "":
		_T.free_ui(host)
		return err
	var bomb: SeedBomb = thrown[0]
	bomb.set_physics_process(false)
	err = _T.assert_true(bomb.position.distance_to(plant.position) < 1.0,
		"the seed starts at the plant (%s), not %s — sibling space, not global"
			% [plant.position, bomb.position])
	if err == "":
		err = _T.assert_true(bomb.target().distance_to(aphid.position) < 1.0,
			"and is aimed at where the pest was (%s), got %s" % [aphid.position, bomb.target()])
	if err == "":
		err = _T.assert_float_eq(bomb.flight_fraction(), 0.0, 0.001,
			"it has not started travelling yet")
	if err == "":
		err = _T.assert_false(bomb.has_detonated(), "and certainly has not gone off")
	if err == "":
		# Half the flight: half way along the ground track, and at the top of the
		# arc. Both halves matter — the position decides what gets hit, the lift is
		# the only reason it reads as an arc on a top-down board at all.
		bomb._physics_process(SeedBomb.FLIGHT_SECONDS * 0.5)
		var midpoint: Vector2 = plant.position.lerp(aphid.position, 0.5)
		err = _T.assert_true(bomb.position.distance_to(midpoint) < 1.0,
			"halfway through the flight it is halfway along the ground track (%s), got %s"
				% [midpoint, bomb.position])
	if err == "":
		err = _T.assert_false(bomb.has_detonated(), "and has still not gone off mid-flight")
	if err == "":
		err = _T.assert_float_eq(SeedBomb.lift_at(0.5), SeedBomb.ARC_HEIGHT, 0.001,
			"the arc peaks at ARC_HEIGHT in the middle")
	if err == "":
		err = _T.assert_float_eq(SeedBomb.lift_at(0.0), 0.0, 0.001, "starts on the ground")
	if err == "":
		err = _T.assert_float_eq(SeedBomb.lift_at(1.0), 0.0, 0.001,
			"and lands on it, or the shadow and the seed would not meet where the blast is drawn")
	if err == "":
		err = _T.assert_float_eq(bomb.sprite_lift(), 0.0, 0.001,
			"headless has animations off, so the lift degrades to nothing while the flight still lands")
	if err == "":
		bomb._physics_process(SeedBomb.FLIGHT_SECONDS * 0.5)
		err = _T.assert_true(bomb.has_detonated(), "the flight is a fixed clock and it ran out")
	if err == "":
		err = _T.assert_true(bomb.position.distance_to(aphid.position) < 1.0,
			"and it went off exactly where it was aimed")
	_T.free_ui(host)
	return err


func test_a_seed_bomb_hits_everything_in_its_blast_and_nothing_outside_it() -> String:
	## The area of effect, which is the whole reason this plant costs 45. Three
	## pests at three distances, one detonation, and the damage each took measured
	## against the declared falloff rather than against a hand-copied number.
	var centre: Pest = _pest(Pest.BEETLE, Vector2(400, 200))
	var rim: Pest = _pest(Pest.BEETLE, Vector2(400.0 + SeedBomb.BLAST_RADIUS * 0.9, 200))
	var clear: Pest = _pest(Pest.BEETLE, Vector2(400.0 + SeedBomb.BLAST_RADIUS * 1.6, 200))
	var bomb := SeedBomb.new()
	var host: Node2D = _host([centre, rim, clear, bomb])
	await _T.instantiate_scene(host)
	_park(centre, Vector2(400, 200))
	_park(rim, Vector2(400.0 + SeedBomb.BLAST_RADIUS * 0.9, 200))
	_park(clear, Vector2(400.0 + SeedBomb.BLAST_RADIUS * 1.6, 200))
	bomb.set_physics_process(false)
	bomb.setup(Vector2(200, 200), Vector2(400, 200), Dandelion.SEED_DAMAGE,
		Rect2(Vector2.ZERO, Vector2(896, 576)))
	var was: Array[float] = [centre.health, rim.health, clear.health]
	var err: String = _T.assert_float_eq(bomb.damage, Dandelion.SEED_DAMAGE, 0.001,
		"setup() carried the plant's seed damage onto the bomb — a bomb that forgot it "
			+ "would still fly, still burst, and take off Kernel's default 1.0")
	if err != "":
		_T.free_ui(host)
		return err
	bomb.detonate()

	err = _T.assert_float_eq(was[0] - centre.health, Dandelion.SEED_DAMAGE, 0.01,
		"a pest at the centre takes the whole seed")
	if err == "":
		var want: float = SeedBomb.damage_at(SeedBomb.BLAST_RADIUS * 0.9, Dandelion.SEED_DAMAGE)
		err = _T.assert_float_eq(was[1] - rim.health, want, 0.01,
			"a pest near the rim takes the falloff's own answer (%.2f)" % want)
	if err == "":
		err = _T.assert_gt(was[0] - centre.health, was[1] - rim.health,
			"which is strictly less than the centre took, or the falloff is decoration")
	if err == "":
		err = _T.assert_float_eq(clear.health, was[2], 0.001,
			"and a pest outside BLAST_RADIUS takes nothing at all")
	if err == "":
		err = _T.assert_float_eq(SeedBomb.damage_falloff(0.0), 1.0, 0.001,
			"dead centre is a full hit")
	if err == "":
		err = _T.assert_float_eq(SeedBomb.damage_falloff(SeedBomb.BLAST_RADIUS),
			SeedBomb.BLAST_EDGE_FRACTION, 0.001,
			"the rim itself is BLAST_EDGE_FRACTION, deliberately not zero")
	if err == "":
		err = _T.assert_float_eq(SeedBomb.damage_falloff(SeedBomb.BLAST_RADIUS + 0.1), 0.0, 0.001,
			"and a hair past it is nothing")
	if err == "":
		err = _T.assert_true(bomb.has_detonated(), "the bomb knows it has gone off")
	if err == "":
		# `detonate()` is public so a devtools verb can trigger it without waiting
		# out the flight, which is exactly what invites a double call.
		var again: float = centre.health
		bomb.detonate()
		err = _T.assert_float_eq(centre.health, again, 0.001,
			"a second detonate() on the same bomb is a no-op, not a second blast")
	if err == "":
		# The burst's own picture grows out to exactly the radius that was
		# damaged, so what the player is shown is what actually happened.
		err = _T.assert_float_eq(SeedBomb.burst_radius(SeedBomb.burst_progress(0.0)),
			SeedBomb.BLAST_RADIUS, 0.001, "the ring finishes at the radius the damage covered")
	if err == "":
		err = _T.assert_float_eq(
			SeedBomb.burst_radius(SeedBomb.burst_progress(SeedBomb.BLAST_LINGER)), 0.0, 0.001,
			"and starts from a point")
	_T.free_ui(host)
	return err


func test_the_dandelion_aims_at_the_crowd_rather_than_the_leader() -> String:
	## Every other engaging plant shoots whichever pest is furthest along, which is
	## right for a single-target weapon and throws away the only thing this one can
	## do. A lone leader against a knot of three: the knot has to win, and progress
	## has to stay the tie-break when nothing is clumped.
	var plant: Dandelion = _idle_dandelion(Vector2(300, 300))
	var leader: Pest = _pest_partway(Pest.APHID, Vector2(300, 240), 8, 10)
	var a: Pest = _pest_partway(Pest.APHID, Vector2(380, 300), 2, 10)
	var b: Pest = _pest_partway(Pest.APHID, Vector2(392, 310), 2, 10)
	var c: Pest = _pest_partway(Pest.APHID, Vector2(404, 300), 2, 10)
	var host: Node2D = _host([plant, leader, a, b, c])
	await _T.instantiate_scene(host)
	_quiesce_dandelion(plant)
	_park(leader, Vector2(300, 240))
	_park(a, Vector2(380, 300))
	_park(b, Vector2(392, 310))
	_park(c, Vector2(404, 300))
	var crowd := PackedVector2Array([leader.position, a.position, b.position, c.position])
	var pests: Array[Pest] = [leader, a, b, c]

	var err: String = _T.assert_gt(leader.progress(), a.progress(),
		"the lone pest genuinely is further along, or this test proves nothing")
	if err == "":
		err = _T.assert_eq(SeedBomb.caught(leader.position, crowd), 1,
			"a blast on the leader catches only the leader")
	if err == "":
		err = _T.assert_gt(SeedBomb.caught(b.position, crowd), 1,
			"and one on the knot catches more than one")
	if err == "":
		var picked: Pest = plant.best_target(pests)
		err = _T.assert_true(picked != null, "the plant found something to throw at")
		if err == "":
			err = _T.assert_false(picked == leader,
				"and it is not the leader — three pests are worth more than one head start")
	if err == "":
		# With nothing clumped it must degrade to the rule every other plant uses.
		var spread: Array[Pest] = [leader, a]
		err = _T.assert_true(plant.best_target(spread) == leader,
			"with nothing to catch together it shoots the pest furthest along, like everything else")
	if err == "":
		var far: Pest = _pest_partway(Pest.APHID,
			Vector2(300.0 + Dandelion.RANGE + 40.0, 300), 5, 10)
		host.add_child(far)
		var out_of_reach: Array[Pest] = [far]
		err = _T.assert_true(plant.best_target(out_of_reach) == null,
			"and a pest past RANGE is not a target, however clumped it is with itself")
	_T.free_ui(host)
	return err


func test_the_dandelion_is_priced_against_the_four_plants_it_stands_beside() -> String:
	## The balance claims out of dandelion.gd's own header, made executable. A
	## comment saying "1.48 dps" is a comment; this fails when a retune quietly
	## turns the most expensive plant in the game into the best single-target one
	## as well.
	var mine: int = PlantCatalog.cost(PlantCatalog.DANDELION)
	var err: String = ""
	for id: StringName in PlantCatalog.ids():
		if id == PlantCatalog.DANDELION:
			continue
		err = _T.assert_gt(mine, PlantCatalog.cost(id),
			"the Dandelion costs more than the %s it stands beside" % id)
		if err == "":
			err = _T.assert_gt(PlantCatalog.tier(PlantCatalog.DANDELION), PlantCatalog.tier(id),
				"and sits above %s in the tiers, or the epic packet has nothing of its own" % id)
		if err != "":
			return err
	var corn_dps: float = CornCobbler.single_target_dps(1, 60.0)
	err = _T.assert_gt(corn_dps, 0.0, "a level-1 cob does damage to compare against")
	if err == "":
		err = _T.assert_true(Dandelion.sustained_dps(1) < corn_dps * 1.5,
			"against ONE pest the Dandelion (%.2f dps) stays in the cheapest plant's league (%.2f)"
				% [Dandelion.sustained_dps(1), corn_dps])
	if err == "":
		# At 120px a bunch of corn lands only its middle kernel — CornCobbler's own
		# header says so, and kernels_connecting_at() is where it says it. Stating
		# the premise here means the comparison below cannot quietly start being
		# about a different cob.
		err = _T.assert_eq(CornCobbler.kernels_connecting_at(CornCobbler.LEVELS.size(), 120.0), 1,
			"at 120px only a bunch's middle kernel connects")
	if err == "":
		err = _T.assert_gt(Dandelion.sustained_dps(3),
			CornCobbler.single_target_dps(CornCobbler.LEVELS.size(), 120.0),
			"and against three pests together the Dandelion out-damages a fully upgraded cob there")
	if err == "":
		err = _T.assert_float_eq(Dandelion.sustained_dps(0), 0.0, 0.001,
			"while it is worth exactly nothing against an empty blast")
	if err == "":
		err = _T.assert_true(Dandelion.rearm_seconds() < Game.PREP_SECONDS,
			"a spent head rearms (%.1fs) inside one prep gap (%.0fs), so the burst can be banked"
				% [Dandelion.rearm_seconds(), Game.PREP_SECONDS])
	if err == "":
		err = _T.assert_gt(Dandelion.volley_cycle_seconds(), Dandelion.rearm_seconds(),
			"and a whole cycle is the reload plus the volley, not just the reload")
	var aphid_speed: float = float(Pest.SPECIES[Pest.APHID]["speed"])
	var beetle_speed: float = float(Pest.SPECIES[Pest.BEETLE]["speed"])
	if err == "":
		err = _T.assert_gt(Dandelion.lead_error(aphid_speed), Dandelion.lead_error(beetle_speed),
			"the fast pest walks further out of the blast during the flight")
	if err == "":
		err = _T.assert_gt(Dandelion.damage_fraction_against(beetle_speed),
			Dandelion.damage_fraction_against(aphid_speed),
			"so a beetle takes more of a seed than an aphid does")
	if err == "":
		err = _T.assert_gt(Dandelion.damage_fraction_against(StickySundew.slowed_speed(aphid_speed)),
			Dandelion.damage_fraction_against(aphid_speed),
			"and a Sundew's patch is the fix — the two priciest plants make each other work")
	return err


func test_only_an_epic_packet_can_hand_over_the_dandelion() -> String:
	## The tier is the whole point of the tier. `rare` used to cap at 99, i.e. at
	## everything, so a third packet above it would have been a more expensive way
	## to buy exactly the same pool.
	var bank := SeedBank.new()
	var err: String = _T.assert_false(bank.is_unlocked(PlantCatalog.DANDELION),
		"the Dandelion starts locked, like everything but the free starter")
	if err == "":
		err = _T.assert_false(bank.packet_pool(&"common").has(PlantCatalog.DANDELION),
			"a common packet cannot hold it")
	if err == "":
		err = _T.assert_false(bank.packet_pool(&"rare").has(PlantCatalog.DANDELION),
			"and neither can a rare one, now that rare caps below tier 3")
	if err == "":
		err = _T.assert_true(bank.packet_pool(&"epic").has(PlantCatalog.DANDELION),
			"only the epic packet reaches it")
	if err == "":
		err = _T.assert_gt(int(SeedBank.PACKET_TIERS[&"epic"]["cost"]),
			int(SeedBank.PACKET_TIERS[&"rare"]["cost"]),
			"and it costs more than the tier it reaches past")
	if err == "":
		# And it is genuinely reachable rather than merely listed: drain the epic
		# tier and check the Dandelion actually came out of one.
		bank.set_seed(3)
		bank.add_seeds(int(SeedBank.PACKET_TIERS[&"epic"]["cost"]) * 20)
		var guard: int = 0
		while not bank.locked_plants().is_empty() and guard < 20:
			guard += 1
			bank.buy_packet(&"epic")
		err = _T.assert_true(bank.is_unlocked(PlantCatalog.DANDELION),
			"an epic packet actually delivers it (%d buys)" % guard)
	return err


func test_the_packet_tiers_are_listed_cheapest_first_and_none_is_missing() -> String:
	## PACKET_ORDER decides which button sits at which y (Hud.packet_row_rect), so
	## a tier missing from it is a packet the player cannot buy, and a tier out of
	## price order is two buttons that swapped places under the cursor.
	var order: Array[StringName] = SeedBank.PACKET_ORDER
	var err: String = _T.assert_eq(order.size(), SeedBank.PACKET_TIERS.size(),
		"every tier is listed exactly once")
	if err != "":
		return err
	var seen: Dictionary = {}
	var last_cost: int = -1
	var last_cap: int = -1
	for tier: StringName in order:
		err = _T.assert_true(SeedBank.PACKET_TIERS.has(tier), "'%s' is a real tier" % tier)
		if err == "":
			err = _T.assert_false(seen.has(tier), "'%s' is listed once, not twice" % tier)
		if err != "":
			return err
		seen[tier] = true
		var spec: Dictionary = SeedBank.PACKET_TIERS[tier] as Dictionary
		err = _T.assert_gt(int(spec["cost"]), last_cost,
			"'%s' costs more than the tier before it" % tier)
		if err == "":
			err = _T.assert_gte(int(spec["max_tier"]), last_cap,
				"and reaches at least as far up the catalogue — a pricier packet reaching LESS is a trap")
		if err != "":
			return err
		last_cost = int(spec["cost"])
		last_cap = int(spec["max_tier"])
	# The pools nest, which is what makes "one tier further up" mean anything.
	var bank := SeedBank.new()
	for index: int in range(1, order.size()):
		var below: Array[StringName] = bank.packet_pool(order[index - 1])
		var above: Array[StringName] = bank.packet_pool(order[index])
		for id: StringName in below:
			err = _T.assert_true(above.has(id),
				"%s's pool contains everything %s's does (%s is missing)"
					% [order[index], order[index - 1], id])
			if err != "":
				return err
		err = _T.assert_gt(above.size(), below.size(),
			"and %s reaches strictly further than %s, or the extra cost buys nothing"
				% [order[index], order[index - 1]])
		if err != "":
			return err
	return err


func test_the_packet_rack_fits_between_the_plant_bar_and_the_selection_box() -> String:
	## Arithmetic first, then the built panel. The rack used to be two hand-placed
	## y values; a third tier had 92px of room for 120px of button, which is why
	## the plant bar gave up 44px. A fourth tier fails here rather than drawing
	## itself under SelectionBox, where every per-Control check would still pass.
	var count: int = SeedBank.PACKET_ORDER.size()
	var first: Rect2 = Hud.packet_row_rect(0)
	var last: Rect2 = Hud.packet_row_rect(count - 1)
	var err: String = _T.assert_gte(first.position.y, Hud.PLANT_BAR_BOTTOM,
		"the first packet button starts below the plant bar's foot")
	if err == "":
		err = _T.assert_gte(Hud.PACKET_ROW_PITCH, Hud.PACKET_ROW_HEIGHT,
			"the rows do not overlap each other")
	if err == "":
		err = _T.assert_gte(Hud.PACKET_ROW_HEIGHT, Hud.PLANT_BUTTON_MIN_HEIGHT,
			"and each one is still a legal touch target")
	if err == "":
		err = _T.assert_gte(Hud.SELECTION_BOX_Y, last.end.y,
			"the last button's foot (%.0f) clears SelectionBox at %.0f"
				% [last.end.y, Hud.SELECTION_BOX_Y])
	if err != "":
		return err

	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	await _pump(game)
	for index: int in count:
		var tier: StringName = SeedBank.PACKET_ORDER[index]
		var path: String = "Root/SidePanel/%s" % Hud.packet_button_name(tier)
		var button: Button = game.hud.get_node_or_null(path) as Button
		err = _T.assert_true(button != null, "%s has a button at %s" % [tier, path])
		if err == "":
			err = _T.assert_float_eq(button.position.y, Hud.packet_row_rect(index).position.y,
				0.001, "and it is on the row packet_row_rect(%d) claims" % index)
		if err == "":
			var cost: int = int((SeedBank.PACKET_TIERS[tier] as Dictionary)["cost"])
			err = _T.assert_true(button.text.contains(str(cost)),
				"and its label quotes the price it will charge: %s" % button.text)
		if err != "":
			break
	if err == "":
		# The oldest button keeps the node name the bridge and the rest of this
		# suite press it by. That asymmetry is deliberate; see packet_button_name.
		err = _T.assert_eq(Hud.packet_button_name(&"common"), "PacketButton",
			"the common tier keeps the bare name its callers use")
	if err == "":
		err = _T.assert_eq(Hud.packet_button_name(&"epic"), "EpicPacketButton",
			"and every other tier gets a name derived from its own id")
	_T.free_ui(game)
	return err


## A bare overlay, built for the base class's own builder surface.
##
## The three shipped overlays each answer a second question at the same time —
## Keys is about the InputMap, Options about three persisted flags, the notebook
## about its pages — and asserting `add_row_button` through any of them is
## asserting that screen's row table as much as the builder. This one supplies a
## paper and nothing else, so what it builds is exactly what OverlayScreen builds.
##
## Its node names are deliberately the contract names (`Heading`, `Note`, `Row0`,
## `RowButton0`, `BackButton`) rather than probe-specific ones: the point of the
## checks below is that the base hands those names out, so a probe that asked for
## its own would be testing the wrong thing.
class _OverlayProbe extends OverlayScreen:
	## Deliberately not any shipped screen's PANEL. A probe that borrowed
	## OptionsScreen.PANEL would pass just as well against a builder that ignored
	## `panel_rect()` and hardcoded those numbers.
	const PANEL := Rect2(200.0, 120.0, 720.0, 400.0)
	const HEADING_Y: float = 140.0
	const NOTE_Y: float = 186.0
	const ROW_Y: float = 240.0
	const ROW_INSET: float = 32.0
	const LABEL_BOX := Vector2(300.0, 40.0)
	## Column offset from the paper's left edge, chosen so the row button's right
	## edge (700 + 150 = 850) still clears the paper's (920).
	const BUTTON_X: float = 500.0

	var heading: Label
	var note: Label
	var row_label: Label
	var row_button: Button
	var back: Button

	func panel_rect() -> Rect2:
		return PANEL

	func _build_contents() -> void:
		heading = add_heading("Probe Screen", HEADING_Y)
		note = add_note_label("One line the screen has to say something in.", NOTE_Y)
		row_label = add_row_label("Row0", "Sound effects",
			Vector2(PANEL.position.x + ROW_INSET, ROW_Y), LABEL_BOX, GardenTheme.INK)
		row_button = add_row_button(0, Vector2(PANEL.position.x + BUTTON_X, ROW_Y))
		row_button.text = "On"
		back = add_back_button(Vector2(PANEL.position.x + ROW_INSET, footer_y()))


func test_the_overlay_base_builds_each_piece_of_its_chrome_where_it_is_told() -> String:
	## add_heading / add_note_label / add_row_label / add_row_button /
	## add_back_button are the surface three screens were each hand-rolling before
	## OverlayScreen owned it, and the failure that extraction can still have is
	## silent: a builder that places against numbers of its own rather than
	## against `panel_rect()` looks right on the one screen it was lifted out of
	## and wrong on the other two. So every assertion here is against the probe's
	## own paper, which is a rect no shipped screen uses.
	var probe := await _T.instantiate_ui(_OverlayProbe.new(), Vector2i(1152, 648)) as _OverlayProbe
	var panel: Rect2 = probe.panel_rect()

	var err: String = _T.assert_eq(String(probe.heading.name), "Heading",
		"add_heading gives the heading the name the screens look it up by")
	if err == "":
		err = _T.assert_eq(probe.heading.text, "Probe Screen",
			"and the text it was handed")
	if err == "":
		err = _T.assert_eq(probe.heading.position,
			Vector2(panel.position.x, _OverlayProbe.HEADING_Y),
			"placed at this paper's left edge and the y it was given, not at a rect of its own")
	if err == "":
		err = _T.assert_float_eq(probe.heading.size.x, panel.size.x, 0.001,
			"spanning this paper's whole width, which is what makes the centring mean anything")
	if err == "":
		# Not an equality: a Control's size is clamped UP to its combined minimum,
		# and a 30px heading font measures 42 against the 40 add_heading asks for.
		# The claim worth making is that the box is at least the one requested.
		err = _T.assert_gte(probe.heading.size.y, 40.0,
			"and at least the 40px tall it was built at (%.1f)" % probe.heading.size.y)
	if err == "":
		err = _T.assert_eq(probe.heading.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER,
			"centred across the paper, which is what makes it read as the title")

	if err == "":
		err = _T.assert_eq(String(probe.note.name), OverlayScreen.NOTE_NAME,
			"add_note_label builds the `Note` node the bridge and the suite read by name")
	if err == "":
		err = _T.assert_true(probe.get_node_or_null(OverlayScreen.NOTE_NAME) == probe.note,
			"and it is that node, not a second Label sharing the name")
	if err == "":
		err = _T.assert_eq(probe.note.position,
			Vector2(panel.position.x, _OverlayProbe.NOTE_Y),
			"sized to the paper at the y it was given")
	if err == "":
		err = _T.assert_float_eq(probe.note.size.x, panel.size.x, 0.001,
			"as wide as the paper, which is the budget the clip below is measured against")
	if err == "":
		err = _T.assert_gte(probe.note.size.y, 24.0,
			"and at least the 24px line it was built at (%.1f)" % probe.note.size.y)
	if err == "":
		err = _T.assert_true(probe.note.clip_text,
			"the note's box is its budget: a longer sentence is trimmed rather than run off the paper")
	if err == "":
		err = _T.assert_eq(probe.note.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS,
			"and trimmed with an ellipsis, so a cut sentence says it was cut")
	if err == "":
		# get_minimum_size() reports the clip stub on a clipped Label, so the
		# obvious width assertion would pass unconditionally here. text_width
		# measures through the label's own resolved font.
		err = _T.assert_true(_T.text_width(probe.note) <= probe.note.size.x,
			"this note actually fits its box (%.1f of %.1f px)"
				% [_T.text_width(probe.note), probe.note.size.x])

	if err == "":
		err = _T.assert_eq(String(probe.row_label.name), "Row0",
			"add_row_label takes the node name from its caller — the two column layouts differ")
	if err == "":
		err = _T.assert_eq(probe.row_label.text, "Sound effects",
			"and says what the row is")
	if err == "":
		err = _T.assert_eq(probe.row_label.position,
			Vector2(panel.position.x + _OverlayProbe.ROW_INSET, _OverlayProbe.ROW_Y),
			"at the cell it was handed")
	if err == "":
		err = _T.assert_eq(probe.row_label.size, _OverlayProbe.LABEL_BOX,
			"in the box it was handed — the column widths are the screens', not the base's")
	if err == "":
		err = _T.assert_eq(probe.row_label.get_theme_color("font_color"), GardenTheme.INK,
			"in the colour it was handed — the colour is the caller's, the styling is the base's")
	if err == "":
		err = _T.assert_eq(probe.row_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT,
			"left-aligned unless a caller asks otherwise")
	if err == "":
		err = _T.assert_true(probe.row_label.clip_text,
			"and clipped, the same budget the note gets")

	if err == "":
		err = _T.assert_eq(String(probe.row_button.name), "RowButton0",
			"add_row_button names the button RowButton%d — the name the bridge presses")
	if err == "":
		err = _T.assert_eq(probe.row_button.size, OverlayScreen.ROW_BUTTON_SIZE,
			"at the shared row-button size, which is 40 tall because `findings` gates an interactive Control at 40x40")
	if err == "":
		err = _T.assert_eq(probe.row_button.position,
			Vector2(panel.position.x + _OverlayProbe.BUTTON_X, _OverlayProbe.ROW_Y),
			"where it was put")
	if err == "":
		err = _T.assert_true(probe.get_node_or_null("RowButton0") == probe.row_button,
			"and reachable at that path, which is what a bridge recipe presses")

	if err == "":
		err = _T.assert_eq(String(probe.back.name), OverlayScreen.BACK_BUTTON_NAME,
			"add_back_button builds the `BackButton` every overlay is left by")
	if err == "":
		err = _T.assert_eq(probe.back.text, OverlayScreen.BACK_TEXT,
			"wearing the one Back caption")
	if err == "":
		err = _T.assert_eq(probe.back.size, OverlayScreen.BACK_BUTTON_SIZE,
			"at the default box, since this screen asked for no other")
	if err == "":
		err = _T.assert_true(probe.back_button() == probe.back,
			"and the screen keeps it: back_button() reports the one add_back_button returned")

	# Nothing built above may run off the paper or sit on top of anything else.
	# The builders are the only thing that placed any of it, so this is a
	# statement about them rather than about a screen's own row table.
	if err == "":
		err = _overlay_content_fits_and_stands_clear(probe)

	# The y and the alignment are the caller's, and these are asserted on the
	# return value of the call itself rather than on a variable that came out of
	# one -- the same distinction suite_reach_check's assert-argument note is
	# about. They go AFTER the enclosure sweep on purpose: they add a second
	# heading and a second note to the same paper, which is a deliberate overlap.
	if err == "":
		err = _T.assert_float_eq(probe.add_heading("Second", 300.0).position.y, 300.0, 0.001,
			"add_heading puts a heading at the y it is handed, every time it is called")
	if err == "":
		err = _T.assert_float_eq(probe.add_note_label("Second note", 320.0).position.y, 320.0,
			0.001,
			"and add_note_label the same -- neither carries a y of its own")
	if err == "":
		err = _T.assert_eq(probe.add_row_label("RowKey9", "F",
				Vector2(240.0, 340.0), Vector2(120.0, 40.0), GardenTheme.INK_SOFT,
				HORIZONTAL_ALIGNMENT_RIGHT).horizontal_alignment,
			HORIZONTAL_ALIGNMENT_RIGHT,
			"add_row_label honours an alignment a caller asks for, rather than always left")
	_T.free_ui(probe)
	return err


func test_the_overlay_footer_is_derived_from_the_paper_and_measured_against_the_rows() -> String:
	## footer_y() is the y a footer sits at, derived rather than written down per
	## screen, and add_row_button is what registers a row with the rule that
	## measures against it. The pair is asserted together because the failure is
	## the pair: a row the base never saw is a row the FOOTER_GAP rule silently
	## skips, and a skipped row leaves a footer flush against content while every
	## intersection check ever written still passes.
	var probe := await _T.instantiate_ui(_OverlayProbe.new(), Vector2i(1152, 648)) as _OverlayProbe
	var panel: Rect2 = probe.panel_rect()

	var err: String = _T.assert_float_eq(probe.footer_y(),
		panel.position.y + panel.size.y - OverlayScreen.FOOTER_HEIGHT - OverlayScreen.FOOTER_INSET,
		0.001,
		"footer_y() is read up from the foot of THIS paper (%.1f), not from a constant"
			% probe.footer_y())
	if err == "":
		err = _T.assert_true(panel.encloses(Rect2(probe.back.position,
				Vector2(probe.back.size.x, OverlayScreen.FOOTER_HEIGHT))),
			"so a FOOTER_HEIGHT-tall footer placed at it still lands on the paper")
	if err == "":
		err = _T.assert_true(probe.has_rows(),
			"the probe's single row registered itself, so the gap rule applies to it")
	if err == "":
		err = _T.assert_gte(probe.footer_clearance(), OverlayScreen.FOOTER_GAP,
			"and the footer stands clear of it by at least FOOTER_GAP (%.1f)"
				% probe.footer_clearance())

	# A second row, added through the builder, has to move the measured clearance
	# by exactly its own pitch. A builder that returned a Button without
	# registering it would leave this number unchanged — and unchanged is exactly
	# what a silently skipped row looks like.
	var before: float = probe.footer_clearance()
	if err == "":
		err = _T.assert_eq(String(probe.add_row_button(1,
				Vector2(panel.position.x + _OverlayProbe.BUTTON_X,
					_OverlayProbe.ROW_Y + OverlayScreen.ROW_HEIGHT)).name),
			"RowButton1",
			"a second row is numbered by the index it was given, not by its arrival order in the tree")
	if err == "":
		err = _T.assert_float_eq(probe.footer_clearance(), before - OverlayScreen.ROW_HEIGHT,
			0.001,
			"and it is measured by the rule: clearance fell one ROW_HEIGHT, %.1f to %.1f"
				% [before, probe.footer_clearance()])
	_T.free_ui(probe)
	return err


func test_the_back_button_the_overlay_base_builds_answers_through_back_requested() -> String:
	## The whole point of add_back_button is that the screen never learns who
	## opened it: it wires `pressed` to `back_requested` and the opener listens.
	## A Back that is built but unwired is a dead end with no way out of the
	## overlay, and it looks identical in every layout assertion above.
	var probe := await _T.instantiate_ui(_OverlayProbe.new(), Vector2i(1152, 648)) as _OverlayProbe
	var fired: Array[int] = [0]
	probe.back_requested.connect(func() -> void: fired[0] += 1)

	var err: String = _T.assert_eq(fired[0], 0,
		"nothing has asked to go back yet")
	if err == "":
		err = _T.assert_true(probe.get_node(OverlayScreen.BACK_BUTTON_NAME) == probe.back_button(),
			"the button at the contract path is the one the screen kept")
	if err == "":
		probe.back.pressed.emit()
		err = _T.assert_eq(fired[0], 1,
			"pressing it emits back_requested exactly once — add_back_button did the wiring, not the screen")

	# The box is a parameter with a default, and the default is the half that
	# gets exercised by every shipped screen. This is the other half.
	var wide: Button = null
	if err == "":
		err = _T.assert_eq(probe.add_back_button(Vector2(panel_gap_x(probe), probe.footer_y()),
				Vector2(220.0, 44.0)).size,
			Vector2(220.0, 44.0),
			"a caller that hands add_back_button a box gets that box, not BACK_BUTTON_SIZE")
		wide = probe.back_button()
	if err == "":
		err = _T.assert_true(wide != probe.back,
			"and the screen now tracks that one instead of the first — back_button() reports the last Back built")
	if err == "":
		err = _T.assert_eq(wide.size, Vector2(220.0, 44.0),
			"which is the wide one, so back_button() did not merely keep reporting the original")
	if err == "":
		wide.pressed.emit()
		err = _T.assert_eq(fired[0], 2,
			"which is wired to the same signal rather than to nothing")
	_T.free_ui(probe)
	return err


## Where a second footer button can sit on `screen` without landing on the first.
## A helper only so the test above reads as one thought; the number is the paper's
## right half.
func panel_gap_x(screen: OverlayScreen) -> float:
	var panel: Rect2 = screen.panel_rect()
	return panel.position.x + panel.size.x / 2.0


func test_the_title_menu_pairs_its_secondary_destinations_two_to_a_row() -> String:
	## menu_rows IS the shape of the title menu: button_rect, menu_bottom,
	## menu_capacity and _link_focus every one of them read it, so a wrong row
	## shape is a menu drawn wrong, a hint placed wrong, and arrow keys that walk
	## a grid that is not on screen. The property that has to hold for any count
	## is that every destination appears exactly once, in reading order.
	var err: String = _T.assert_eq(TitleScreen.menu_rows(0).size(), 0,
		"an empty menu has no rows — the loop terminates rather than emitting one")
	if err == "":
		err = _T.assert_eq(_menu_row_shape(TitleScreen.MENU_BUTTON_NAMES.size()),
			[[0], [1], [2, 3], [4]],
			"the shipped menu is two full-width primaries, one pair, and a lone trailing secondary")
	if err == "":
		err = _T.assert_eq(_menu_row_shape(6), [[0], [1], [2, 3], [4, 5]],
			"a sixth destination fills the hole beside the fifth rather than opening a new row")
	if err == "":
		err = _T.assert_eq(_menu_row_shape(TitleScreen.PRIMARY_COUNT),
			[[0], [1]],
			"a menu of nothing but primaries is one row each")
	if err == "":
		err = _T.assert_eq(_menu_row_shape(TitleScreen.PRIMARY_COUNT + 1),
			[[0], [1], [2]],
			"and a single trailing secondary spans the band rather than leaving a hole beside it")

	for count: int in range(0, 9):
		if err != "":
			return err
		var seen: Array[int] = []
		var widest: int = 0
		for row: PackedInt32Array in TitleScreen.menu_rows(count):
			widest = maxi(widest, row.size())
			for index: int in row:
				seen.append(index)
		var expected: Array[int] = []
		for i: int in count:
			expected.append(i)
		err = _T.assert_eq(seen, expected,
			"every destination in a %d-button menu is placed once, in reading order" % count)
		if err == "":
			err = _T.assert_true(widest <= 2,
				"and no row of a %d-button menu holds more than the two cells the band is split into" % count)
	return err


## TitleScreen.menu_rows as plain nested Arrays, which compare and print.
func _menu_row_shape(count: int) -> Array:
	var out: Array = []
	for row: PackedInt32Array in TitleScreen.menu_rows(count):
		out.append(Array(row))
	return out


func test_the_title_menu_row_heights_follow_the_primary_count() -> String:
	## row_height is the other half of the grid: menu_rows says which buttons
	## share a row, this says how tall that row is. They are asserted against each
	## other and against button_rect, because the number that matters is the one a
	## button is actually drawn at — a row_height nothing reads would be a
	## constant with a function around it.
	var err: String = _T.assert_float_eq(TitleScreen.row_height(0),
		TitleScreen.BUTTON_HEIGHT, 0.001,
		"the first row is a full-height primary — it starts a run")
	if err == "":
		err = _T.assert_float_eq(TitleScreen.row_height(TitleScreen.PRIMARY_COUNT - 1),
			TitleScreen.BUTTON_HEIGHT, 0.001,
			"and so is the last of the PRIMARY_COUNT rows")
	if err == "":
		err = _T.assert_float_eq(TitleScreen.row_height(TitleScreen.PRIMARY_COUNT),
			TitleScreen.SECONDARY_BUTTON_HEIGHT, 0.001,
			"the first secondary row is the shorter one — it is not the thing the screen is for")
	if err == "":
		err = _T.assert_true(TitleScreen.row_height(TitleScreen.PRIMARY_COUNT)
				< TitleScreen.row_height(0),
			"the two heights are actually different, so this is a rule and not one number twice")
	if err == "":
		err = _T.assert_gte(TitleScreen.row_height(TitleScreen.PRIMARY_COUNT), 40.0,
			"and the short one is still 40 — `findings` gates an interactive Control at 40x40")

	var count: int = TitleScreen.MENU_BUTTON_NAMES.size()
	var rows: Array[PackedInt32Array] = TitleScreen.menu_rows(count)
	var total: float = 0.0
	for r: int in rows.size():
		if err != "":
			return err
		total += TitleScreen.row_height(r)
		for c: int in rows[r].size():
			err = _T.assert_float_eq(TitleScreen.button_rect(rows[r][c], count).size.y,
				TitleScreen.row_height(r), 0.001,
				"button %d is drawn at the height of the row menu_rows put it in" % rows[r][c])
			if err != "":
				return err
	if err == "":
		# menu_bottom is BUTTON_TOP plus every row height plus the gaps between
		# them. Stated here so a row_height that stopped being read by the layout
		# would show up as a menu that no longer ends where it says it does.
		err = _T.assert_float_eq(TitleScreen.menu_bottom(count),
			TitleScreen.BUTTON_TOP + total + TitleScreen.BUTTON_GAP * float(rows.size() - 1),
			0.001,
			"and the menu ends exactly one stack of row_heights and gaps below BUTTON_TOP")
	return err

## The card measures text with a detached Label; the rows draw with an in-tree one.
##
## `PauseScreen._measure()` answers "how wide is this string" before any instance
## exists, because `card_width()` has to. It does that by creating a Label, applying
## the same font-size override the rows carry, and asking it for its theme font --
## which resolves identically to an in-tree Label's *only because this project sets
## no custom theme*. That is a fact about this project, not about Godot, and it is
## exactly the kind of fact that stops being true without anything failing: add a
## theme to the game and the card sizes itself with one font while drawing in
## another, and the symptom is a legend that clips by a few pixels for no visible
## reason.
##
## So the two are compared directly, against the real rows, rather than left as a
## sentence in a docstring.
func test_the_cards_own_measurement_agrees_with_the_labels_it_builds() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.pause_run()
	await _pump(game)
	var screen: Control = game.get_node_or_null("PauseLayer/PauseScreen") as Control
	var err: String = _T.assert_true(screen != null, "the card is up")
	var rows: int = Game.key_help().size()
	if err == "":
		err = _T.assert_gt(rows, 0, "there are rows to compare")
	var checked: int = 0
	for i: int in range(rows):
		if err != "":
			break
		for node_name: String in ["KeyRow%d" % i, "KeyRowDoes%d" % i]:
			var row: Label = screen.get_node_or_null(node_name) as Label
			err = _T.assert_true(row != null, "%s is on the card" % node_name)
			if err != "":
				break
			checked += 1
			# One pixel of tolerance: the two paths agree on the font and the size,
			# and asserting bit-equality on a float pair that came from two different
			# TextServer calls is a test that fails on a rounding change rather than
			# on the defect it is for.
			err = _T.assert_float_eq(PauseScreen._measure(row.text), _T.text_width(row), 1.0,
				"%s: the card measured %.1fpx for %r and the Label drew %.1fpx -- the "
					% [node_name, PauseScreen._measure(row.text), row.text, _T.text_width(row)]
					+ "static measurement and the real font have come apart, which is what "
					+ "a custom theme added to this project would do")
			if err != "":
				break
	if err == "":
		err = _T.assert_gt(checked, 4,
			"the comparison actually ran over the legend (an empty loop here would "
				+ "make this test vacuous, not clean)")
	game.resume_run()
	_T.free_ui(game)
	return err

## Rebinding to a long key WHILE the card is open must not push the phrase off it.
##
## The card sizes itself to its widest bound key, so a rebinding changes what that
## width should be — but the card is already on screen, with buttons placed against
## its edges, and it is not resized under the player. `_refresh_key_list()` therefore
## re-splits the two columns inside the width the card ACTUALLY has, clamping the key
## column so the phrase column keeps what the widest phrase needs.
##
## Found in the running game, not here: the first version measured against
## `key_row_max_width()`, which re-derives from the NEW bindings, so it laid a 247px
## phrase out at x+143 on a 365px card — 52px onto the dimmed backdrop. The fix for a
## legend running off the card had reintroduced a legend running off the card, one
## code path over.
func test_rebinding_while_the_card_is_open_keeps_the_legend_on_the_card() -> String:
	var stashed_bindings: Dictionary = RunConfig.key_bindings
	var stashed_path: String = RunConfig.save_path
	RunConfig.save_path = "user://test_selftest_refresh_split.save"
	RunConfig.key_bindings = {}
	KeyBindings.reset_all()

	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.pause_run()
	await _pump(game)
	var screen: Control = game.get_node_or_null("PauseLayer/PauseScreen") as Control
	var err: String = _T.assert_true(screen != null, "the card is up")
	var card: Control = null
	if err == "":
		card = screen.get_node_or_null("Card") as Control
		err = _T.assert_true(card != null, "and it has paper to stay on")
	var built_width: float = 0.0
	if err == "":
		built_width = card.size.x
		# The longest name the engine has, bound while the card is already built.
		var worst_code: int = 0
		var worst_label: String = ""
		for code: int in range(1 << 22, (1 << 22) + 512):
			var name: String = OS.get_keycode_string(code)
			if name.length() > worst_label.length():
				worst_label = name
				worst_code = code
		err = _T.assert_true(KeyBindings.set_keys(KeyBindings.ACTION_PAUSE, [worst_code]),
			"the longest key the engine names (%s) binds" % worst_label)
	if err == "":
		screen._refresh_key_list()
		err = _T.assert_float_eq(card.size.x, built_width, 0.5,
			"the card itself does not move under the player -- it is rebuilt at the "
				+ "derived width on the NEXT pause, not resized mid-session")
	if err == "":
		var paper_right: float = card.global_position.x + card.size.x
		for i: int in range(Game.key_help().size()):
			for node_name: String in ["KeyRow%d" % i, "KeyRowDoes%d" % i]:
				var row: Label = screen.get_node_or_null(node_name) as Label
				err = _T.assert_true(row != null, "%s is on the card" % node_name)
				if err != "":
					break
				err = _T.assert_true(row.global_position.x + row.size.x <= paper_right + 0.5,
					"%s ends at %.0f against paper ending at %.0f -- the re-split "
						% [node_name, row.global_position.x + row.size.x, paper_right]
						+ "measured against the width the card WOULD be rather than the "
						+ "width it has")
				if err != "":
					break
			if err != "":
				break
	if err == "":
		# And the half that must never be the one sacrificed.
		var does_row: Label = screen.get_node_or_null("KeyRowDoes0") as Label
		err = _T.assert_true(_T.text_width(does_row) <= does_row.size.x + 0.5,
			"the PHRASE still fits: if something has to be truncated it is the key, "
				+ "which the player just typed and can read in full one screen up")

	game.resume_run()
	_T.free_ui(game)
	KeyBindings.reset_all()
	RunConfig.key_bindings = stashed_bindings
	RunConfig.save_path = stashed_path
	DirAccess.remove_absolute("user://test_selftest_refresh_split.save")
	return err

## The Keys screen's own key column, against a key the player chose
## (plant-tower-defense-2tpm, plant-tower-defense-pb4).
##
## The pause card learned twice that a legend row's key half is authored by the
## player. This is the screen where that matters most and it was the last to be
## checked: `RowKey%d` sat in a hand-picked 140px column, and "On-screen keyboard"
## — the longest name `OS.get_keycode_string()` produces — measures 157px at this
## screen's font 16. So the one surface whose entire job is telling a player which
## key a verb is on was showing them a truncated one.
##
## Worse than the same truncation on the pause card, and it invalidated the argument
## used to accept it there: "if something must be cut it is the key, which the player
## can read in full one screen up". They could not.
##
## Both halves are asserted, because they fail differently: the BOX (a Label that won
## its width back overlaps the button beside it) and the TEXT (a box that held but
## clipped its contents). Driven through `refresh()` rather than a rebuild — the
## defect this test generalises lived in a refresh path, and a rebuild proves the
## builder while saying nothing about the updater.
func test_the_keys_screen_shows_a_long_key_in_full() -> String:
	var stashed_bindings: Dictionary = RunConfig.key_bindings
	var stashed_path: String = RunConfig.save_path
	RunConfig.save_path = "user://test_selftest_long_key.save"
	RunConfig.key_bindings = {}
	KeyBindings.reset_all()

	var screen := await _T.instantiate_ui(KeyBindingScreen.new(), Vector2i(1152, 648)) as KeyBindingScreen
	var shipped_width: float = KeyBindingScreen.key_column_width()
	var err: String = _T.assert_gte(shipped_width, KeyBindingScreen.KEY_MIN_WIDTH,
		"the column is at least the width it has always had")

	# The longest name the engine has, derived rather than picked.
	var worst_code: int = 0
	var worst_label: String = ""
	if err == "":
		for code: int in range(1 << 22, (1 << 22) + 512):
			var name: String = OS.get_keycode_string(code)
			if name.length() > worst_label.length():
				worst_label = name
				worst_code = code
		err = _T.assert_gt(GardenTheme.measure(worst_label, KeyBindingScreen.ROW_FONT_SIZE),
			KeyBindingScreen.KEY_MIN_WIDTH,
			"the worst engine key name (%s) is genuinely wider than the shipped column "
				% worst_label
				+ "-- if it were not, this test would pass without exercising anything")

	if err == "":
		err = _T.assert_true(KeyBindings.set_keys(KeyBindings.ACTION_PAUSE, [worst_code]),
			"%s binds to the first verb" % worst_label)
	if err == "":
		# The property that makes this screen's derivation different from the pause
		# card's: the column is sized for every key that COULD appear, so binding one
		# does not move it. A column that reflowed under the player's hands mid-
		# keystroke -- sliding the row's button sideways as they pressed -- would be a
		# worse answer than one that was always wide enough.
		err = _T.assert_float_eq(KeyBindingScreen.key_column_width(), shipped_width, 0.5,
			"and binding it does not move the column, on the one screen the player is "
				+ "editing ON")

	# Through the refresh path, on the screen that is already built.
	if err == "":
		screen.refresh()
		var key_label: Label = screen.get_node_or_null("RowKey0") as Label
		err = _T.assert_true(key_label != null, "RowKey0 is on the screen")
		if err == "":
			err = _T.assert_eq(key_label.text, worst_label, "and it carries the new key")
		if err == "":
			# (1) the TEXT. This is the half that was broken: the box held at 140 and
			# clipped a 157px name into it.
			err = _T.assert_true(_T.text_width(key_label) <= key_label.size.x + 0.5,
				"the key is shown IN FULL: %.0fpx of name in a %.0fpx column"
					% [_T.text_width(key_label), key_label.size.x])
		if err == "":
			# (2) the BOX, which fails the other way -- a Label whose assigned size lost
			# to its own minimum overlaps whatever sits beside it. add_row_label sets
			# clip_text before size for exactly this reason.
			var button: Button = screen.get_node_or_null("RowButton0") as Button
			err = _T.assert_true(button != null, "RowButton0 is beside it")
			if err == "":
				err = _T.assert_true(
					key_label.position.x + key_label.size.x <= button.position.x + 0.5,
					"and its box ends at %.0f, clear of the button at %.0f"
						% [key_label.position.x + key_label.size.x, button.position.x])

	_T.free_ui(screen)
	KeyBindings.reset_all()
	RunConfig.key_bindings = stashed_bindings
	RunConfig.save_path = stashed_path
	DirAccess.remove_absolute("user://test_selftest_long_key.save")
	return err


# -- Weather rounds (plant-tower-defense-q3lx) -------------------------------


## The weather rule, asserted as a rule rather than as a list of waves.
##
## `weather_for()` is derived from the wave number so it can be checked against
## every wave out to endless, including the ones no table row exists for. Both of
## its non-obvious clauses are here, because both are the kind of thing that reads
## as an accident later: rain beats drought on a collision, and drought never lands
## on a boss wave.
func test_weather_follows_a_rule_and_not_a_hand_typed_column() -> String:
	var err: String = _T.assert_eq(String(WaveDirector.weather_for(1)),
		String(WaveDirector.WEATHER_CLEAR), "the opening waves are clear")
	if err == "":
		err = _T.assert_eq(String(WaveDirector.weather_for(WaveDirector.WEATHER_FIRST_WAVE - 1)),
			String(WaveDirector.WEATHER_CLEAR), "and nothing arrives before WEATHER_FIRST_WAVE")
	if err == "":
		err = _T.assert_eq(String(WaveDirector.weather_for(5)),
			String(WaveDirector.WEATHER_RAIN), "wave 5 rains")
	if err == "":
		# Wave 35 is a multiple of 5 AND of 7. Rain wins; the mercy beats the
		# cruelty, and a wave that both heals everything and halves the garden's
		# rate of fire is not a readable event.
		err = _T.assert_eq(String(WaveDirector.weather_for(35)),
			String(WaveDirector.WEATHER_RAIN),
			"a wave that is both takes the rain -- 35 is the first collision and "
				+ "endless is the only mode that reaches it")

	# Drought never on a boss wave, checked against the TABLE rather than against
	# the wave numbers that happen to carry queens today.
	var boss_waves: int = 0
	var droughts: int = 0
	if err == "":
		for wave: int in range(1, WaveDirector.WAVES.size() + 1):
			var weather: StringName = WaveDirector.weather_for(wave)
			if WaveDirector.wave_carries_boss(wave):
				boss_waves += 1
				err = _T.assert_false(weather == WaveDirector.WEATHER_DROUGHT,
					"wave %d carries a boss, so it is not also a drought" % wave)
				if err != "":
					break
			if weather == WaveDirector.WEATHER_DROUGHT:
				droughts += 1
	if err == "":
		err = _T.assert_gt(boss_waves, 0,
			"the table actually has boss waves -- a zero here would make the "
				+ "exemption above vacuous rather than satisfied")
	if err == "":
		err = _T.assert_gt(droughts, 0,
			"and the campaign actually sees a drought, so the rule is not simply "
				+ "switched off inside the table's range")
	return err


## Drought slows the garden and rain heals it — asserted through the plants, not
## through the constants that describe them.
func test_weather_reaches_the_plants() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(100)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, _grass(game)), "", "planted")
	var plant: Plant = game.selected_placed
	if err == "":
		err = _T.assert_true(plant != null, "and the bed is the one we hold")
	if err == "":
		err = _T.assert_float_eq(plant.fire_interval_scale, 1.0, 0.001,
			"a bed planted in clear weather shoots at its own rate")

	if err == "":
		game._apply_weather(WaveDirector.WEATHER_DROUGHT)
		err = _T.assert_float_eq(plant.fire_interval_scale,
			WaveDirector.WEATHER_DROUGHT_INTERVAL_SCALE, 0.001,
			"a drought stretches the interval of a bed already on the board")
	if err == "":
		# The half a player would find by trying it: planting INTO a drought must
		# not be the way to beat it.
		err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, _grass(game)), "", "planted again")
		if err == "":
			err = _T.assert_float_eq(game.selected_placed.fire_interval_scale,
				WaveDirector.WEATHER_DROUGHT_INTERVAL_SCALE, 0.001,
				"and a bed bought DURING the drought inherits it")

	if err == "":
		# Rain: a real heal, on a bed that has something to heal.
		plant.take_damage(Plant.MAX_HEALTH * 0.5)
		var hurt: float = plant.health
		game._apply_weather(WaveDirector.WEATHER_RAIN)
		err = _T.assert_gt(plant.health, hurt, "rain gives health back")
		if err == "":
			err = _T.assert_float_eq(plant.health,
				hurt + Plant.MAX_HEALTH * WaveDirector.WEATHER_RAIN_HEAL_FRACTION, 0.01,
				"by exactly the fraction the rule names")
		if err == "":
			err = _T.assert_float_eq(plant.fire_interval_scale, 1.0, 0.001,
				"and rain also lifts the drought rather than stacking with it")
	if err == "":
		# A partly-healed bed takes only the gap, not the amount asked for -- the
		# first draft of this assertion expected 0 here and got 6, because 50% + 35%
		# is 85% and not full. The number is the point: heal() reports what it GAVE.
		# The gap is read BEFORE the call. Arguments evaluate left to right, so
		# passing `Plant.MAX_HEALTH - plant.health` as the expected value reads it
		# after heal() has already filled it -- which is how the first draft of this
		# line asserted 0 against 6 and blamed the code.
		var gap: float = Plant.MAX_HEALTH - plant.health
		err = _T.assert_float_eq(plant.heal(Plant.MAX_HEALTH), gap, 0.001,
			"a partly-grown bed takes exactly the gap it had left")
	if err == "":
		err = _T.assert_float_eq(plant.heal(Plant.MAX_HEALTH), 0.0, 0.001,
			"and a bed at full health takes nothing, and reports that it took nothing")

	_T.free_ui(game)
	return err


## Every weather state has both of the words that describe it
## (plant-tower-defense-saaw).
##
## The banner headline and the banner note are two separate `match` statements over
## the same set, so a state added to WaveDirector with only one of them reaches a
## player as a headline over an empty line.
##
## There is deliberately no third, compact form for the top bar. That was written
## and reverted in the same cycle: the wave slot's base string measures 302px in a
## 312px slot, so even a bare "*" needs 317, and the project's own budget check
## reported `hud_stats_row` at -35px when the slot was widened to fit "rain". The
## bar is not weather's home, and the measurement is recorded in WORST_CASE_TEXT
## where the next person to try it will read it first.
func test_every_weather_has_a_headline_and_a_note() -> String:
	var states: Array[StringName] = [WaveDirector.WEATHER_RAIN, WaveDirector.WEATHER_DROUGHT]
	var err: String = ""
	for weather: StringName in states:
		err = _T.assert_false(Hud.weather_headline(weather).is_empty(),
			"%s has a banner headline" % weather)
		if err == "":
			err = _T.assert_false(Hud.weather_note(weather).is_empty(),
				"%s has a banner note" % weather)
		if err != "":
			return err
	# Clear says nothing at all: a banner reading "Clear" on eleven waves out of
	# twelve teaches the player to stop reading banners.
	if err == "":
		err = _T.assert_eq(Hud.weather_headline(WaveDirector.WEATHER_CLEAR), "",
			"clear weather is silent in the banner")
	if err == "":
		err = _T.assert_eq(Hud.weather_note(WaveDirector.WEATHER_CLEAR), "",
			"and has no note either")
	return err


## The cob quotes the rate it will actually fire at, not the one in its level table
## (plant-tower-defense-cxru).
##
## Weather multiplies the number the cob ARMS its cooldown with, and two surfaces
## went on quoting the table: the selection panel told the player "0.80s" while the
## cob fired every 1.60s, and `readiness()` divided a cooldown armed at 1.60 by a
## base of 0.80 — clamping to 0, so the arming glow sat empty for the whole first
## half of every reload.
##
## Two bugs, one cause, and the general shape is worth the test: **the surfaces that
## DESCRIBE a value are a separate population from the code that USES it, and one
## edit does not reach both.** Both now read `fire_interval()`.
func test_a_cob_quotes_the_rate_it_will_actually_fire_at() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(100)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, _grass(game)), "", "planted")
	var corn: CornCobbler = game.selected_placed as CornCobbler
	if err == "":
		err = _T.assert_true(corn != null, "and it is a cob")
	var clear_interval: float = 0.0
	if err == "":
		clear_interval = corn.fire_interval()
		err = _T.assert_gt(clear_interval, 0.0, "which quotes an interval in clear weather")

	if err == "":
		game._apply_weather(WaveDirector.WEATHER_DROUGHT)
		err = _T.assert_float_eq(corn.fire_interval(),
			clear_interval * WaveDirector.WEATHER_DROUGHT_INTERVAL_SCALE, 0.001,
			"and under a drought it quotes the stretched one, because that is the "
				+ "rate the player is actually getting")
	if err == "":
		# The readiness half. Armed under the drought, the glow must run 0 -> 1 across
		# the WHOLE reload rather than sitting at 0 until the base interval is up.
		corn._cooldown = 0.0
		corn._act(0.0, [] as Array[Pest])
		corn._cooldown = corn.fire_interval() * 0.5
		err = _T.assert_float_eq(corn.readiness(), 0.5, 0.01,
			"half a drought reload reads half-armed, got %.2f" % corn.readiness())
	if err == "":
		game._apply_weather(WaveDirector.WEATHER_CLEAR)
		err = _T.assert_float_eq(corn.fire_interval(), clear_interval, 0.001,
			"and clearing the weather puts the quoted rate back")

	_T.free_ui(game)
	return err


## The record rolls up from the one it beat (plant-tower-defense-9z1).
##
## Three things, and the last two are the ones that make it a feature rather than an
## effect: the roll renders through the SAME function as the settled line, so the two
## cannot disagree about spacing or which modes are named; it counts from the record
## that actually fell rather than from zero; and it does not run at all when there is
## nothing to count from.
func test_the_record_rolls_up_from_the_one_it_beat() -> String:
	var stashed_c: int = RunConfig.campaign_high_score
	var stashed_e: int = RunConfig.endless_high_score
	var stashed_fresh: bool = RunConfig.fresh_record
	var stashed_prev: int = RunConfig.previous_best
	var stashed_mode: bool = RunConfig.fresh_record_endless
	var stashed_endless: bool = RunConfig.endless
	var stashed_path: String = RunConfig.save_path
	RunConfig.save_path = "user://test_selftest_ratchet_roll.save"

	# record_score has to remember what it replaced, or the roll has no origin.
	RunConfig.endless = false
	RunConfig.campaign_high_score = 300
	RunConfig.endless_high_score = 5000
	var err: String = _T.assert_true(RunConfig.record_score(308), "308 beats 300")
	if err == "":
		err = _T.assert_eq(RunConfig.previous_best, 300,
			"and the record it beat is kept, session-only, for the roll to start at")
	if err == "":
		err = _T.assert_false(RunConfig.fresh_record_endless,
			"and the mode that moved is the one that was played -- not `endless`, "
				+ "which the title screen rewrites the moment the player moves the "
				+ "selection")

	# The moving line and the settled line come from one renderer.
	if err == "":
		var mid: String = TitleScreen.high_score_text_at(304, 5000, true)
		err = _T.assert_true(mid.contains("Campaign 304"),
			"a mid-roll value renders through the same function, got: %s" % mid)
	if err == "":
		err = _T.assert_true(TitleScreen.high_score_text_at(304, 5000, true).ends_with("← just now"),
			"and carries the same marker the settled line does")
	if err == "":
		err = _T.assert_false(TitleScreen.high_score_text_at(304, 5000, false).contains("just now"),
			"which is off when the record is not fresh")

	# The settled line is what the label holds, whatever the animation does.
	if err == "":
		var title := await _T.instantiate_ui("res://game/title.tscn", Vector2i(1152, 648)) as TitleScreen
		var label: Label = title.get_node_or_null("HighScoreLabel") as Label
		err = _T.assert_true(label != null, "the title screen has its score line")
		if err == "":
			err = _T.assert_true(label.text.contains("Campaign 308"),
				"and it holds the FINAL text on arrival -- headless pumps no frames, so "
					+ "a roll responsible for reaching the right number would leave the "
					+ "wrong one on screen forever; got: %s" % label.text)
		_T.free_ui(title)

	RunConfig.campaign_high_score = stashed_c
	RunConfig.endless_high_score = stashed_e
	RunConfig.fresh_record = stashed_fresh
	RunConfig.previous_best = stashed_prev
	RunConfig.fresh_record_endless = stashed_mode
	RunConfig.endless = stashed_endless
	RunConfig.save_path = stashed_path
	DirAccess.remove_absolute("user://test_selftest_ratchet_roll.save")
	return err


## The prep gap says what is coming (plant-tower-defense-arkk).
##
## The wording is pure so it can be asserted without a HUD, and the three things it
## names are the three that change the SHAPE of a wave rather than its size — the
## threat number on the prep strip already answers "how much".
func test_the_prep_note_says_what_the_next_wave_is_worth() -> String:
	var err: String = _T.assert_eq(
		Hud.next_wave_note(5, 22, false, WaveDirector.WEATHER_CLEAR),
		"Wave 5 next — 22 pests.", "a plain wave is its number and its count")
	if err == "":
		err = _T.assert_eq(
			Hud.next_wave_note(14, 30, true, WaveDirector.WEATHER_CLEAR),
			"Wave 14 next — 30 pests · a boss.", "a boss wave says so")
	if err == "":
		err = _T.assert_eq(
			Hud.next_wave_note(10, 24, false, WaveDirector.WEATHER_RAIN),
			"Wave 10 next — 24 pests · rain · beds mend %d%%." % _rain_mend_percent(),
			"and the weather rides with it")
	if err == "":
		# Past the fixed table pests_in_wave() returns 0 because the schedule does
		# not exist yet. "0 pests" would be a confident lie about the hardest waves
		# in the game, so the count is omitted rather than printed as a zero.
		err = _T.assert_eq(
			Hud.next_wave_note(40, 0, false, WaveDirector.WEATHER_CLEAR),
			"Wave 40 next.", "an unknown count is absent, not zero")
	if err == "":
		err = _T.assert_true(
			WaveDirector.pests_in_wave(WaveDirector.WAVES.size() + 1) == 0,
			"which is the case that actually happens: the wave after the table has "
				+ "no schedule yet, so this is not a hypothetical branch")

	# It fits the row it shares. The message label clips, so a note too long for it
	# would be trimmed silently -- the same failure the top bar's budgets exist for.
	if err == "":
		# Every field at its maximum, including `last` -- the widest string the FORMAT
		# allows, not the widest the game is expected to produce.
		var widest: String = Hud.next_wave_note(999, 9999, true,
			WaveDirector.WEATHER_DROUGHT, true)
		var game := await _T.instantiate_scene(GAME_SCENE) as Game
		var label: Label = game.hud.get_node_or_null("Root/TopBar/MessageLabel") as Label
		err = _T.assert_true(label != null, "the message row exists to share")
		if err == "":
			err = _T.assert_true(GardenTheme.measure(widest, Hud.MESSAGE_FONT_SIZE) <= label.size.x,
				"and the widest note this can produce (%s) fits its %.0fpx row at %.0fpx"
					% [widest, label.size.x, GardenTheme.measure(widest, Hud.MESSAGE_FONT_SIZE)])
		_T.free_ui(game)
	return err


## The prep note yields to a message and comes back, and goes away when the wave
## starts (plant-tower-defense-arkk).
##
## Both halves were found in the running game, and both are invisible to a test that
## only asserts the wording:
##
##   * `refresh()` is driven by state CHANGES, and a message expiring is not one — so
##     the row went blank seconds after the note was written and stayed blank;
##   * nothing else rewrites this Label, so when the wave started the note announcing
##     it stayed on screen for the whole wave.
##
## The label is driven directly here rather than through a live Game, because what is
## under test is the HUD's own arbitration between a standing note and a transient
## message, and a Game would only be a way of producing the two states.
func test_the_prep_note_yields_to_a_message_and_comes_back() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var hud: Hud = game.hud
	var label: Label = hud.get_node_or_null("Root/TopBar/MessageLabel") as Label
	var err: String = _T.assert_true(label != null, "the message row exists")

	var prep: Dictionary = {
		"wave_live": false, "more_waves": true, "wave": 4,
		"next_wave_pests": 16, "next_wave_boss": false,
		"next_weather": WaveDirector.WEATHER_RAIN,
	}
	# Declared at function scope, not inside the `if` that first uses it: GDScript
	# scopes `var` to its enclosing block, and the later block that reads it again
	# fails to PARSE rather than to run.
	var live: Dictionary = prep.duplicate()
	live["wave_live"] = true
	if err == "":
		# The Game opens with its own hint on this row, and the note correctly
		# declines to overwrite it -- which is what the first draft of this test
		# tripped over. Drain it, so what follows is about arbitration and not about
		# whatever the run happened to be saying.
		hud._message_left = 0.0
		hud._advance_message_queue()
		hud._refresh_prep_note(prep)
		err = _T.assert_eq(label.text,
			"Wave 5 next — 16 pests · rain · beds mend %d%%." % _rain_mend_percent(),
			"the note is on the row during the prep gap")
	if err == "":
		hud.show_message("Composted a husk for 6 seeds.", 3.0)
		err = _T.assert_eq(label.text, "Composted a husk for 6 seeds.",
			"a real message outranks it")
	if err == "":
		hud._refresh_prep_note(prep)
		err = _T.assert_eq(label.text, "Composted a husk for 6 seeds.",
			"and a refresh while that message is up does not stomp it")
	if err == "":
		# The path refresh() cannot cover: the message expiring on its own.
		hud._message_left = 0.0
		hud._advance_message_queue()
		err = _T.assert_eq(label.text,
			"Wave 5 next — 16 pests · rain · beds mend %d%%." % _rain_mend_percent(),
			"when the message drains, the note comes back rather than the row "
				+ "going blank")
	if err == "":
		hud._refresh_prep_note(live)
		err = _T.assert_eq(label.text, "",
			"and the wave starting takes the note down -- it announces what is "
				+ "coming, not what is here")
	if err == "":
		# A real message during a wave is not ours to erase.
		hud.show_message("A pest got past you.", 3.0)
		hud._refresh_prep_note(live)
		err = _T.assert_eq(label.text, "A pest got past you.",
			"and taking it down never clears someone else's line")

	_T.free_ui(game)
	return err


## A message that reads exactly like the standing note is still a message
## (plant-tower-defense-4akt).
##
## Three functions used to write `MessageLabel.text` directly, and each answered "is
## the line on the row mine?" by comparing the Label's text against what it expected
## to find. That comparison is wrong on its own terms: a message whose text happens to
## equal the note is indistinguishable from the note, and the wave starting would have
## wiped it.
##
## It is now one painter and two claims, so the question is not asked. This test is the
## reason the refactor is not merely tidier — it asserts something the previous design
## could not make true.
func test_a_message_that_reads_like_the_note_is_not_mistaken_for_it() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var hud: Hud = game.hud
	var label: Label = hud.get_node_or_null("Root/TopBar/MessageLabel") as Label
	var err: String = _T.assert_true(label != null, "the message row exists")

	var prep: Dictionary = {
		"wave_live": false, "more_waves": true, "wave": 4,
		"next_wave_pests": 16, "next_wave_boss": false,
		"next_weather": WaveDirector.WEATHER_CLEAR,
	}
	var note: String = Hud.next_wave_note(5, 16, false, WaveDirector.WEATHER_CLEAR)
	if err == "":
		hud._message_left = 0.0
		hud._advance_message_queue()
		hud._refresh_prep_note(prep)
		err = _T.assert_eq(label.text, note, "the note is up")
	if err == "":
		# The collision: a real message with the note's exact text.
		hud.show_message(note, 3.0)
		err = _T.assert_gt(hud._message_left, 0.0, "and a message claims the row")
	if err == "":
		var live: Dictionary = prep.duplicate()
		live["wave_live"] = true
		hud._refresh_prep_note(live)
		err = _T.assert_eq(label.text, note,
			"the wave starting drops the NOTE's claim and leaves the message alone, "
				+ "even though the two read identically -- the old design compared "
				+ "the Label's text and would have cleared it")
	if err == "":
		err = _T.assert_gt(hud._message_left, 0.0,
			"and the message still has its time")
	if err == "":
		# And once it expires there is no note to fall back to, because the wave is
		# live -- the row goes quiet rather than re-showing a stale announcement.
		hud._message_left = 0.0
		hud._advance_message_queue()
		err = _T.assert_eq(label.text, "",
			"when it drains mid-wave the row is empty, not the note it happened to "
				+ "look like")

	_T.free_ui(game)
	return err


## The last wave says so (plant-tower-defense-45wa).
##
## `has_more_waves()` goes false only AFTER the final wave is cleared, so the note
## disappears once there is nothing next — correctly. That left the run's final wave
## as the moment with the least information and the most at stake: it read exactly
## like wave 7.
##
## The flag is derived from the table and the mode, so endless — which has no last
## wave — is false by construction rather than by a comparison that happens never to
## be true.
func test_the_last_wave_says_that_it_is_the_last() -> String:
	var last: int = WaveDirector.WAVES.size()
	var err: String = _T.assert_eq(
		Hud.next_wave_note(last, 40, true, WaveDirector.WEATHER_CLEAR, true),
		"Wave %d next — the last one · 40 pests · a boss." % last,
		"finality leads the line, because it changes what the run is about")
	if err == "":
		err = _T.assert_eq(
			Hud.next_wave_note(7, 14, false, WaveDirector.WEATHER_CLEAR, false),
			"Wave 7 next — 14 pests.", "and an ordinary wave is unchanged")
	if err == "":
		# The flag as Game derives it, against the real table.
		var game := await _T.instantiate_scene(GAME_SCENE) as Game
		game.director.endless = false
		game.director.current_wave = last - 1
		var state: Dictionary = game.state()
		err = _T.assert_true(bool(state["next_wave_is_last"]),
			"the wave before the table's end is followed by the last one")
		if err == "":
			game.director.current_wave = last - 2
			err = _T.assert_false(bool(game.state()["next_wave_is_last"]),
				"the one before that is not")
		if err == "":
			# Endless has no last wave at all.
			game.director.endless = true
			game.director.current_wave = last - 1
			err = _T.assert_false(bool(game.state()["next_wave_is_last"]),
				"and endless never announces a last wave, because it does not have one")
		_T.free_ui(game)
	return err


## No message clips, for any plant in the catalogue (plant-tower-defense-m1el).
##
## `MessageLabel` has `clip_text` set, so a line too long for it is trimmed to an
## ellipsis and nothing errors — the same silent failure the top bar's four readouts
## have budgets for. The row had none.
##
## The four messages checked here are the ones whose length follows the CATALOGUE:
## they interpolate a plant's display name or a corn level's name, so they grow when
## a plant or level is added.
##
## This header used to end "every other line the row shows is a fixed literal, as long
## as it will ever be". That was false — the prep note and the wave-cleared line both
## interpolate a wave number and a pest count — and it is the exact reason the row's
## budget was wrong for three cycles: a sentence saying the rest is fixed is a sentence
## saying the rest needs no sweep. `Hud.message_corpus()` holds the whole set now, and
## `test_the_message_corpus_covers_every_catalogue_producer` below guards it.


## The corpus is the budget's denominator, so an incomplete one under-reports headroom
## silently — which it did, three times. Two directions, both cheap:
##
##   * every plant and every corn level reaches it, so a name added to the catalogue
##     joins the corpus without anyone remembering to;
##   * the entries that are NOT catalogue-driven are present by count, so deleting one
##     is a failure rather than a slightly smaller number.
##
## `tools/message_corpus_check.py` covers the direction neither of these can: a
## `show_message()` CALL SITE whose text never joined the corpus at all.
func test_the_message_corpus_covers_every_catalogue_producer() -> String:
	var corpus: Array[String] = Hud.message_corpus()
	var err: String = _T.assert_gt(corpus.size(), PlantCatalog.PLANTS.size() * 3,
		"the corpus is at least four messages per plant (%d entries for %d plants)"
			% [corpus.size(), PlantCatalog.PLANTS.size()])
	if err != "":
		return err
	# Direction one: the catalogue is covered, name by name.
	var missing: Array[String] = []
	for id: StringName in PlantCatalog.PLANTS:
		var display: String = PlantCatalog.display_name(id)
		var seen: bool = false
		for line: String in corpus:
			if line.contains(display):
				seen = true
				break
		if not seen:
			missing.append(display)
	err = _T.assert_true(missing.is_empty(),
		"every plant name reaches the message corpus -- missing: %s" % [missing])
	if err != "":
		return err
	for level: Dictionary in CornCobbler.LEVELS:
		var name: String = String(level["name"])
		var found: bool = false
		for line: String in corpus:
			if line.contains(name):
				found = true
				break
		err = _T.assert_true(found, "corn level '%s' reaches the corpus" % name)
		if err != "":
			return err
	# Direction two: the non-catalogue entries, by count. Deleting the prep note or a
	# bare literal would otherwise just make the budget's answer quietly smaller.
	# FIVE per plant since cycle 79. The armed-uproot prompt is three of them: bare,
	# with the move tip (shown once per save, the bare warning every time after), and
	# with the forfeit clause an upgraded plant carries. The tip and the forfeit never
	# co-occur — the budget refused that build at 188 px over — so it is three forms
	# and not four.
	# Both ladders since cycle 101: the Chomp Flower grows too, and its rungs produce
	# upgrade_message lines exactly as the cob's do. Summed from the tables rather
	# than doubled, because the two ladders are not required to be the same length.
	# SIX per plant since cycle 103, not five: the upgrade tip
	# (plant-tower-defense-gz53) names whichever plant on the board is cheapest to
	# upgrade, which is a fact about the player's garden rather than about the
	# catalogue — so any name in PLANTS can appear in it and every name has to be
	# priced. Pricing only the cob's would leave the row short by the difference
	# between the shortest plant name and the longest.
	# SEVEN per plant since cycle 112, not six: a plant now has two death lines, not one.
	# "A hungry pest ate your X!" was true of every plant death until the Barrier Bramble
	# arrived, since Pest only reaches _adjacent_plant() inside its is_hungry branch; a
	# road plant is chewed by _blocking_plant(), which every pest runs. BOTH are priced
	# for EVERY plant rather than the one each plant can reach, because a corpus that
	# reasons about which plant can show which line is wrong the first time a plant
	# changes where it stands -- and the wall line is 6 characters longer.
	# EIGHT per plant since cycle 117: road_plant_tip joins the two death lines, priced
	# per plant for the same reason -- pricing only the one plant that can currently show
	# it is a budget that is wrong the first time a second road plant exists.
	var catalogue_entries: int = (PlantCatalog.PLANTS.size() * 8
		+ CornCobbler.LEVELS.size() + ChompFlower.LEVELS.size())
	return _T.assert_eq(corpus.size() - catalogue_entries, 9,
		("the corpus carries its 9 non-catalogue entries (prep note, wave-cleared "
			+ "line, the flight tip, and six literals -- BOTH colourblind lines, since "
			+ "the checker reads the leading literal of that ternary). If this moved "
			+ "because you ADDED one, raise the number; if it moved because one "
			+ "vanished, the row's budget just got quietly optimistic"))
##
## The catalogue is SWEPT rather than sampled, and the level table with it — so this
## is checked against every name the game can actually produce, not against a worst
## case someone typed out and hoped was still the worst. A plant added with a long
## name fails here rather than shipping a trimmed sentence.
func test_no_message_clips_for_any_plant_in_the_catalogue() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var label: Label = game.hud.get_node_or_null("Root/TopBar/MessageLabel") as Label
	var err: String = _T.assert_true(label != null, "the message row exists to measure")
	var budget: float = 0.0
	if err == "":
		budget = label.size.x
		err = _T.assert_gt(budget, 0.0, "and it has a width")

	var checked: int = 0
	var worst: String = ""
	var worst_px: float = 0.0
	if err == "":
		for id: StringName in PlantCatalog.PLANTS:
			var display: String = PlantCatalog.display_name(id)
			for line: String in [Hud.eaten_message(display),
					Hud.uproot_armed_message(display), Hud.packet_message(display)]:
				checked += 1
				var drawn: float = GardenTheme.measure(line, Hud.MESSAGE_FONT_SIZE)
				if drawn > worst_px:
					worst_px = drawn
					worst = line
		# Every ladder in the game, keyed to the plant that owns it -- the message now
		# carries the plant's name, so measuring the cob's rungs alone would price the
		# wrong sentence for the Chomp's.
		var ladders: Dictionary = {
			PlantCatalog.CORN: CornCobbler.LEVELS,
			PlantCatalog.CHOMP: ChompFlower.LEVELS,
		}
		for id: StringName in ladders:
			for level: Dictionary in (ladders[id] as Array):
				var line: String = Hud.upgrade_message(
					PlantCatalog.display_name(id), String(level["name"]))
				checked += 1
				var drawn: float = GardenTheme.measure(line, Hud.MESSAGE_FONT_SIZE)
				if drawn > worst_px:
					worst_px = drawn
					worst = line
		err = _T.assert_gt(checked, 10,
			"the sweep visited the catalogue and the level table -- a near-empty "
				+ "sweep here would pass without measuring anything")
	if err == "":
		err = _T.assert_true(worst_px <= budget,
			"the widest message any plant can produce fits the row: %.0fpx of %.0f -- "
				% [worst_px, budget]
				+ "\"%s\". Shorten the message, shorten the name, or widen the row."
					% worst)

	_T.free_ui(game)
	return err


## The armed reset marks the rows it will take back (plant-tower-defense-saq).
##
## The confirmation says "2 keys moved. Press again to put F1 · F2 back" — a count and
## two key names, in a 700px note. WHICH rows those are is a question the rows
## themselves can answer, and they have all the room.
##
## Two channels on purpose. A tint alone is exactly what `RunConfig.colorblind_safe`
## exists to make unreliable, and this project already answers that everywhere it
## warns — lane pressure is hatched, a regrowing bar is notched. On a Label the only
## channel besides colour is the text, so a moved key gains a mark as well as a
## colour, and the key column is sized to include it so arming never clips a name.
func test_the_armed_reset_marks_the_rows_it_will_take_back() -> String:
	var stashed_bindings: Dictionary = RunConfig.key_bindings
	var stashed_path: String = RunConfig.save_path
	RunConfig.save_path = "user://test_selftest_armed_marks.save"
	RunConfig.key_bindings = {}
	KeyBindings.reset_all()

	var screen := await _T.instantiate_ui(KeyBindingScreen.new(), Vector2i(1152, 648)) as KeyBindingScreen
	var key0: Label = screen.get_node_or_null("RowKey0") as Label
	var key1: Label = screen.get_node_or_null("RowKey1") as Label
	var err: String = _T.assert_true(key0 != null and key1 != null, "two rows to compare")

	if err == "":
		screen.listen_for(KeyBindings.actions()[0])
		err = _T.assert_true(screen.capture(KEY_F1), "the first verb moves to F1")
	if err == "":
		err = _T.assert_false(key0.text.ends_with(KeyBindingScreen.KEY_REVERT_MARK),
			"nothing is marked while the reset is idle -- the mark means 'about to "
				+ "go', not 'has moved'")
	if err == "":
		(screen.get_node("ResetButton") as Button).pressed.emit()
		err = _T.assert_true(screen.reset_armed(), "arming for the question")
	if err == "":
		err = _T.assert_true(key0.text.ends_with(KeyBindingScreen.KEY_REVERT_MARK),
			"the moved row is marked, got: %s" % key0.text)
	if err == "":
		err = _T.assert_false(key1.text.ends_with(KeyBindingScreen.KEY_REVERT_MARK),
			"and a row nobody touched is not, got: %s" % key1.text)
	if err == "":
		# The second channel. Same information, not carried by the mark.
		err = _T.assert_eq(key0.get_theme_color("font_color"), GardenTheme.DANGER,
			"the moved row is also tinted, because a mark alone is a second channel "
				+ "for people who read marks")
	if err == "":
		err = _T.assert_eq(key1.get_theme_color("font_color"), GardenTheme.LEAF_DARK,
			"and the untouched row keeps its own colour")
	if err == "":
		# It fits. The column is sized for the widest key the engine names PLUS the
		# mark, so the row being asked about is never the row that clips.
		var widest: String = ""
		for code: int in range(1 << 22, (1 << 22) + 512):
			var name: String = OS.get_keycode_string(code)
			if name.length() > widest.length():
				widest = name
		var worst: float = GardenTheme.measure(widest + KeyBindingScreen.KEY_REVERT_MARK,
			KeyBindingScreen.ROW_FONT_SIZE)
		err = _T.assert_true(worst <= KeyBindingScreen.key_column_width(),
			"the widest key plus its mark fits the column: %.0fpx of %.0f"
				% [worst, KeyBindingScreen.key_column_width()])
	if err == "":
		# Disarming takes both channels away.
		screen.listen_for(KeyBindings.actions()[1])
		screen.capture(KEY_ESCAPE)
		err = _T.assert_false(key0.text.ends_with(KeyBindingScreen.KEY_REVERT_MARK),
			"disarming unmarks it, got: %s" % key0.text)
	if err == "":
		err = _T.assert_eq(key0.get_theme_color("font_color"), GardenTheme.LEAF_DARK,
			"and untints it")

	_T.free_ui(screen)
	KeyBindings.reset_all()
	RunConfig.key_bindings = stashed_bindings
	RunConfig.save_path = stashed_path
	DirAccess.remove_absolute("user://test_selftest_armed_marks.save")
	return err


## Nothing on the HUD is reachable while something is open over it
## (plant-tower-defense-csrc).
##
## The pause card and the post-mortem both carry a full-viewport MOUSE_FILTER_STOP
## backdrop, so a player cannot CLICK a plant button through them — and focus is a
## separate channel that does not care what is drawn on top. `OverlayScreen`'s class
## header documents exactly this hazard, and both `PauseScreen._set_card_active` and
## `TitleScreen._set_menu_active` already answer it for their own buttons. The HUD is
## on its own CanvasLayer and is nobody's child, so nothing answered it here.
##
## The set is COLLECTED from the catalogue-built bars rather than listed, so a plant
## added to `PlantCatalog.PLANTS` is covered without anyone remembering to add its
## button to a list.
func test_the_hud_is_inert_while_an_overlay_is_open() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var controls: Array[Button] = game.hud.interactive_controls()
	var err: String = _T.assert_gt(controls.size(), 4,
		"the HUD has controls to make inert -- an empty list here would pass this "
			+ "whole test without checking anything")
	if err == "":
		err = _T.assert_gt(game.hud._plant_buttons.size(), 0,
			"and the plant bar is among them, which is the half built from the "
				+ "catalogue rather than written down")

	if err == "":
		for button: Button in controls:
			err = _T.assert_eq(button.focus_mode, Control.FOCUS_ALL,
				"%s is reachable during play" % button.name)
			if err != "":
				break

	if err == "":
		game.pause_run()
		await _pump(game)
		for button: Button in controls:
			err = _T.assert_eq(button.focus_mode, Control.FOCUS_NONE,
				"%s cannot be focused behind the pause card -- Tab does not care "
					% button.name + "what is drawn on top")
			if err != "":
				break
	if err == "":
		for button: Button in controls:
			err = _T.assert_eq(button.mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"%s does not track the cursor either: the backdrop is 0.88 alpha, "
					% button.name + "so a hover glow underneath shows through it")
			if err != "":
				break

	if err == "":
		game.resume_run()
		await _pump(game)
		for button: Button in controls:
			err = _T.assert_eq(button.focus_mode, Control.FOCUS_ALL,
				"%s is live again once the card is gone" % button.name)
			if err != "":
				break

	_T.free_ui(game)
	return err


## The bed an armed uproot will remove says so (plant-tower-defense-rtgp).
##
## Uproot arms for four seconds and the message row says which plant — a sentence with
## a life, on a row shared with everything else the game says. The plant it is about
## said nothing. This is the same treatment the Keys screen's armed reset got: the
## pending destructive change is shown on the thing that will be destroyed.
##
## Two channels, and the second is not decoration. `RunConfig.colorblind_safe` exists
## because a hue is not a reliable carrier, so the brackets get heavier as well as
## redder — the same reasoning that hatches the lane overlay and notches a regrowing
## health bar.
func test_an_armed_uproot_marks_the_bed_it_will_remove() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(100)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, _grass(game)), "", "planted")
	var plant: Plant = game.selected_placed
	var marker: SelectionMarker = null
	if err == "":
		err = _T.assert_true(plant != null, "and the bed is the one we hold")
	if err == "":
		marker = plant.get_node_or_null("SelectionMarker") as SelectionMarker
		err = _T.assert_true(marker != null, "which carries a selection marker")
	if err == "":
		err = _T.assert_eq(marker.marker_color, SelectionMarker.MARKER_COLOR,
			"an unarmed bed wears the ordinary marker")

	if err == "":
		# `arm_uproot` is the button's wiring and the thing that ARMS;
		# `commit_uproot` is what actually removes the bed. Calling the second one
		# here uprooted the plant outright and returned "" -- worth the comment,
		# because the names do not say which is which.
		err = _T.assert_eq(game.arm_uproot(), "confirm needed", "one click arms it")
	if err == "":
		err = _T.assert_eq(marker.marker_color, SelectionMarker.WARNING_COLOR,
			"and the bed turns to the warning colour")
	if err == "":
		err = _T.assert_float_eq(marker.line_width, SelectionMarker.WARNING_LINE_WIDTH, 0.001,
			"AND gets heavier, because a hue alone is what colorblind_safe exists "
				+ "to make unreliable")

	if err == "":
		# Every exit from the armed state runs through _disarm_uproot, which is why
		# the marker is restored there rather than at each caller. Letting the timer
		# run out is the exit a player takes by doing nothing.
		game._uproot_left = 0.01
		game._tick_uproot_confirm(1.0)
		err = _T.assert_eq(marker.marker_color, SelectionMarker.MARKER_COLOR,
			"and letting it lapse puts the bed back")
	if err == "":
		err = _T.assert_float_eq(marker.line_width, SelectionMarker.LINE_WIDTH, 0.001,
			"in both channels")
	if err == "":
		err = _T.assert_false(game.uproot_armed(),
			"with the arming itself cleared, not just its look")

	_T.free_ui(game)
	return err


## A drought pays for itself, and the player is told so
## (plant-tower-defense-4c1l).
##
## The game has no wave-clear payout at all — seeds come from killed pests and swept
## husks — so a drought used to cost the player half their rate of fire and pay exactly
## what the easy version of the same wave paid. This is the same idea as
## `Pest.husk_multiplier()`, which already pays more for a harder kill, applied to a
## whole wave.
##
## Rain deliberately stays at 1.0. Paying less for the mercy wave is the symmetrical
## choice and the wrong one: it turns the good weather into something to dread.
func test_a_drought_pays_more_and_says_so() -> String:
	var err: String = _T.assert_float_eq(
		WaveDirector.seed_multiplier_for(WaveDirector.WEATHER_CLEAR), 1.0, 0.001,
		"clear weather pays the plain rate")
	if err == "":
		err = _T.assert_float_eq(
			WaveDirector.seed_multiplier_for(WaveDirector.WEATHER_RAIN), 1.0, 0.001,
			"and so does rain -- the mercy wave is not also the poor one")
	if err == "":
		err = _T.assert_float_eq(
			WaveDirector.seed_multiplier_for(WaveDirector.WEATHER_DROUGHT),
			WaveDirector.WEATHER_DROUGHT_SEED_BONUS, 0.001, "a drought pays more")
	if err == "":
		# Worth surviving, not worth WANTING. At 2.0 the arithmetic starts to favour
		# praying for bad weather, which inverts the mechanic.
		err = _T.assert_true(WaveDirector.WEATHER_DROUGHT_SEED_BONUS < 2.0,
			"but not so much more that a player would choose it, got %.2f"
				% WaveDirector.WEATHER_DROUGHT_SEED_BONUS)

	# Through the game, on the number a kill actually banks.
	if err == "":
		var game := await _T.instantiate_scene(GAME_SCENE) as Game
		game._apply_weather(WaveDirector.WEATHER_CLEAR)
		var plain: int = game.weather_seed_value(4)
		err = _T.assert_eq(plain, 4, "a clear-weather kill banks its own value")
		if err == "":
			game._apply_weather(WaveDirector.WEATHER_DROUGHT)
			err = _T.assert_eq(game.weather_seed_value(4), 6,
				"and the same kill under a drought banks 6")
		if err == "":
			# Never rounds a kill down to nothing.
			err = _T.assert_gte(game.weather_seed_value(1), 1,
				"the cheapest pest is still worth at least one seed")
		if err == "":
			game._apply_weather(WaveDirector.WEATHER_RAIN)
			err = _T.assert_eq(game.weather_seed_value(4), 4, "rain banks the plain value")
		_T.free_ui(game)

	# And the player is told, where they are deciding what to buy.
	if err == "":
		var note: String = Hud.next_wave_note(9, 20, false, WaveDirector.WEATHER_DROUGHT)
		err = _T.assert_true(note.contains("pests pay 150%"),
			"the prep note names the bonus -- a payout nobody can see is a "
				+ "coincidence, not a rule; got: %s" % note)
	if err == "":
		err = _T.assert_true(Hud.weather_note(WaveDirector.WEATHER_DROUGHT).contains("150%"),
			"and so does the banner that announces the wave")
	return err


## Every row-limited surface computes its own ceiling (plant-tower-defense-knpc).
##
## Cycle 75 enumerated four such surfaces and found one — `TitleScreen` — computing its
## ceiling while the other three wrote the sums into a comment and pinned the result with
## a test. All three were correct and all three had to be re-derived by hand by whoever
## next wanted a row, which is how the milestone shelf's "no room for an eighth" and the
## options panel's "a fourth trips FOOTER_GAP" were each discovered while holding a
## feature rather than before starting one.
##
## Asserted as a TABLE, not three examples, and the table records the measured SLACK rather
## than a rule. Three surfaces are exactly full; the title screen's menu has three spare
## rows — and it is the one that already computed its ceiling, which is either a nice
## coincidence or a hint that a surface whose limit is a number nobody re-derives is a
## surface people stop crowding. One data point either way.
##
## (The title screen's tightness is real but it is a WIDTH constraint, not a row count:
## cycle 64 recorded that its sixth destination needs a shortened word to fit a 146 px
## cell. Two different ceilings on one surface, and only one of them is this test's.)
func test_every_row_limited_surface_is_exactly_full() -> String:
	var surfaces: Array[Dictionary] = [
		{
			"what": "the options panel",
			# 1 spare since v8 (plant-tower-defense-u9uh), and BOTH numbers under it moved
			# for different reasons — which is why this row is not simply "0 -> 1".
			#
			# `used` was OPTIONS.size() alone, and that stopped being the panel's row count
			# the moment DIALS landed underneath the switches: the surface shows five rows
			# and this was measuring three. A tripwire that counts the wrong thing reads as
			# "still full" while the surface fills up past it.
			#
			# `fits` moved because the panel stopped being a fixed 360px box. It derives its
			# height from its rows now (see OptionsScreen.panel_height), so the binding
			# constraint is the 648 viewport rather than a hardcoded paper size — six rows
			# is the last count that lands, a seventh puts the foot at 672.
			"spare": 1,
			"used": OptionsScreen.OPTIONS.size() + OptionsScreen.DIALS.size(),
			"fits": OptionsScreen.rows_capacity(),
		},
		{
			"what": "the milestone shelf",
			"spare": 0,
			"used": Milestones.TABLE.size(),
			"fits": NotebookScreen.shelf_capacity(),
		},
		{
			"what": "the run summary card",
			"spare": 0,
			"used": 7,   # summary_rows() needs a built card; the count is the subject here
			"fits": RunSummary.rows_capacity(),
		},
		{
			"what": "the title screen menu",
			"spare": 3,
			"used": TitleScreen.MENU_BUTTON_NAMES.size(),
			"fits": TitleScreen.menu_capacity(),
		},
	]
	var err: String = _T.assert_eq(surfaces.size(), 4,
		"four row-limited surfaces -- add the fifth here or this sweep is a subset")
	for surface: Dictionary in surfaces:
		if err != "":
			return err
		var used: int = int(surface["used"])
		var fits: int = int(surface["fits"])
		var spare: int = int(surface["spare"])
		err = _T.assert_gte(fits, used,
			"%s holds its %d row(s) -- capacity says %d" % [surface["what"], used, fits])
		if err == "":
			# The recorded slack, asserted exactly. `fits >= used` alone would pass a
			# capacity pointed at the wrong box, and a bare "must be full" would fail the
			# moment a surface legitimately loses a row. This says what was MEASURED, so
			# any movement in either direction is a thing someone chose.
			err = _T.assert_eq(fits - used, spare,
				("%s has %d spare row(s), measured as %d in cycle 82. Up means the ceiling "
					+ "moved or a row went; down means the surface is fuller than the last "
					+ "person to look thought.") % [surface["what"], fits - used, spare])
	return err


## The helper's own arithmetic, at the boundary where an off-by-one lives.
func test_rows_that_fit_counts_the_last_row_that_actually_lands() -> String:
	# Ten rows of 10 starting at 0, floor at 100: rows at 0..90, each 10 tall, so ten fit
	# and the tenth ends exactly on the floor.
	var err: String = _T.assert_eq(OverlayScreen.rows_that_fit(0.0, 10.0, 10.0, 100.0), 10,
		"a row ending exactly on the floor counts")
	if err == "":
		err = _T.assert_eq(OverlayScreen.rows_that_fit(0.0, 10.0, 10.0, 99.0), 9,
			"and one pixel short of it does not")
	if err == "":
		err = _T.assert_eq(OverlayScreen.rows_that_fit(0.0, 10.0, 12.0, 100.0), 9,
			"an item taller than its pitch loses the last row, not the first")
	if err == "":
		err = _T.assert_eq(OverlayScreen.rows_that_fit(200.0, 10.0, 10.0, 100.0), 0,
			"a floor above the top holds nothing rather than looping forever")
	if err == "":
		err = _T.assert_eq(OverlayScreen.rows_that_fit(0.0, 0.0, 10.0, 100.0), 0,
			"and a zero pitch is refused rather than hanging")
	return err


## Every named entry point still resolves (plant-tower-defense-jq4l).
##
## `devtools_config.json`'s `entry_points` are the only way a runtime check can reach a
## screen the automatic hook does not open — and they are a JSON file naming a method by
## string, so a rename breaks them silently and only shows up as a `fire-entry-point` that
## does nothing. Cycle 82 measured what that costs: four files changed across three screens,
## a clean `findings` across all five checks, and `reached 0/4 changed file(s)`.
##
## Checks the METHOD, not the node path: resolving `/root/TitleScreen` needs the scene
## instantiated and made current, which is a different and much heavier test. A method that
## exists on the right script is the half a rename actually breaks.
func test_every_devtools_entry_point_names_a_method_that_exists() -> String:
	var file := FileAccess.open("res://addons/godot_selftest/devtools_config.json",
		FileAccess.READ)
	var err: String = _T.assert_true(file != null, "the devtools config is readable")
	if err != "":
		return err
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	err = _T.assert_true(parsed is Dictionary, "and is a JSON object")
	if err != "":
		return err
	var points: Dictionary = (parsed as Dictionary).get("entry_points", {})
	# A denominator: an empty or renamed `entry_points` would otherwise sweep over nothing
	# and report clean, which is exactly the state cycle 82 was in.
	err = _T.assert_gte(points.size(), 5,
		"five entry points -- the board plus every overlay screen, got %d" % points.size())
	if err != "":
		return err
	# node_path -> the script that node runs. Written out because the path is a runtime
	# fact and this test is static; a path added to the config without a line here fails
	# below rather than being skipped.
	var scripts: Dictionary = {
		"/root/TitleScreen": TitleScreen,
		"/root/Game": Game,
	}
	for name: String in points:
		var point: Dictionary = points[name]
		var path: String = str(point.get("node_path", ""))
		var method: String = str(point.get("method", ""))
		err = _T.assert_true(scripts.has(path),
			("entry_points.%s points at %s, which this test does not know the script for -- "
				+ "add it to the map above rather than letting the entry go unchecked")
				% [name, path])
		if err != "":
			return err
		var script: Script = scripts[path]
		err = _T.assert_true(script.has_method(method) or _script_declares(script, method),
			"entry_points.%s calls %s.%s(), which does not exist" % [name, path, method])
		if err != "":
			return err
		# The scene it switches to has to exist too, or the switch fails before the call.
		var scene: String = str(point.get("scene", ""))
		if scene != "":
			err = _T.assert_true(ResourceLoader.exists(scene),
				"entry_points.%s switches to %s, which is not a resource" % [name, scene])
			if err != "":
				return err
	return err


## `Script.has_method` only sees methods on the script itself in some builds; this reads
## the declaration list, which covers a private method the config names deliberately.
func _script_declares(script: Script, method: String) -> bool:
	for entry: Dictionary in script.get_script_method_list():
		if str(entry.get("name", "")) == method:
			return true
	return false


## Weather is drawn on the ground it applies to (plant-tower-defense-saaw).
##
## The bead asked for a standing readout on the TOP BAR and that was measured and refused:
## the wave slot's base string is 302 px in a 312 px box, so every candidate tag overflowed
## and widening the slot put `hud_stats_row` 35 px over its own budget. The note ends
## "reopen only with a decision about WHERE". This is that decision — weather is a property
## of the garden rather than of the run's bookkeeping, and the board has the room the bar
## does not.
##
## Asserted through `mark_position`, which is pure, because the properties that matter —
## the marks are on the board, and they do not collapse onto a handful of points — need no
## renderer. What a headless test cannot see is the colour, which is why the two-channel
## rule is carried by the mark SHAPE (flat dashes against slanted streaks) and not by hue.
func test_the_weather_overlay_scatters_marks_across_the_whole_board() -> String:
	var size := Vector2(896.0, 576.0)
	var seen: Dictionary = {}
	var min_at := Vector2(size.x, size.y)
	var max_at := Vector2.ZERO
	for i: int in range(WeatherOverlay.MARK_COUNT):
		var at: Vector2 = WeatherOverlay.mark_position(i, size)
		var err: String = _T.assert_true(
			at.x >= 0.0 and at.x < size.x and at.y >= 0.0 and at.y < size.y,
			"mark %d at %s is on the board" % [i, at])
		if err != "":
			return err
		seen["%d,%d" % [int(at.x), int(at.y)]] = true
		min_at = Vector2(minf(min_at.x, at.x), minf(min_at.y, at.y))
		max_at = Vector2(maxf(max_at.x, at.x), maxf(max_at.y, at.y))
	# Distinct, or the "scatter" is a few points drawn ninety times. A hash can collide;
	# what it may not do is collapse.
	var err: String = _T.assert_gte(seen.size(), WeatherOverlay.MARK_COUNT - 4,
		"the marks are distinct positions, got %d of %d" % [seen.size(),
			WeatherOverlay.MARK_COUNT])
	if err == "":
		# And SPREAD, which distinctness alone does not give: ninety points inside one
		# corner are ninety distinct points and not a texture over a board.
		err = _T.assert_true(min_at.x < size.x * 0.2 and max_at.x > size.x * 0.8,
			"they reach both sides horizontally (%.0f..%.0f of %.0f)"
				% [min_at.x, max_at.x, size.x])
	if err == "":
		err = _T.assert_true(min_at.y < size.y * 0.2 and max_at.y > size.y * 0.8,
			"and both ends vertically (%.0f..%.0f of %.0f)" % [min_at.y, max_at.y, size.y])
	if err == "":
		# Deterministic: the same wave paints the same marks, so nothing shimmers on a
		# repaint and a screenshot of a drought is reproducible.
		err = _T.assert_eq(WeatherOverlay.mark_position(7, size),
			WeatherOverlay.mark_position(7, size), "the scatter is a function, not a draw")
	if err == "":
		err = _T.assert_eq(WeatherOverlay.mark_position(0, Vector2.ZERO), Vector2.ZERO,
			"a board with no size is refused rather than dividing by it")
	return err


## Clear weather draws nothing, and the overlay only repaints when it changes.
func test_the_weather_overlay_is_silent_when_the_weather_is_clear() -> String:
	var overlay := WeatherOverlay.new()
	overlay.setup(Vector2(896.0, 576.0))
	var err: String = _T.assert_eq(String(overlay.weather()),
		String(WaveDirector.WEATHER_CLEAR),
		"it opens clear -- eleven waves in twelve, and a readout that is present and empty "
			+ "most of the time is a readout people stop reading")
	if err == "":
		overlay.set_weather(WaveDirector.WEATHER_DROUGHT)
		err = _T.assert_eq(String(overlay.weather()), String(WaveDirector.WEATHER_DROUGHT),
			"a drought is held")
	if err == "":
		overlay.set_weather(WaveDirector.WEATHER_CLEAR)
		err = _T.assert_eq(String(overlay.weather()), String(WaveDirector.WEATHER_CLEAR),
			"and cleared again when the next wave is fine")
	overlay.free()
	return err


## The two weathers differ by SHAPE, not only by hue.
##
## The project rule is that colour is never the only signal, and a tint is the obvious way
## to draw weather and the wrong one on its own. Drought's dashes lie flat; rain's streaks
## lean. Asserted on the constants because that is where the difference lives — a test that
## rendered both and compared pixels would be asserting the renderer.
func test_drought_and_rain_are_different_textures_before_they_are_different_colours()	-> String:
	var flat := Vector2(WeatherOverlay.DROUGHT_MARK_LENGTH, 0.0).normalized()
	var slanted: Vector2 = WeatherOverlay.RAIN_SLANT.normalized()
	var err: String = _T.assert_true(absf(flat.dot(slanted)) < 0.99,
		"the two mark angles are distinguishable, dot %.3f" % flat.dot(slanted))
	if err == "":
		err = _T.assert_true(WeatherOverlay.RAIN_SLANT.y > 0.0
				and absf(WeatherOverlay.RAIN_SLANT.x) < WeatherOverlay.RAIN_SLANT.y,
			"rain leans rather than lying over -- it has to read as falling")
	if err == "":
		# And the marks are small enough not to be mistaken for the cell-sized vocabulary
		# in OVERLAY_GRAMMAR.md, where a filled dot on a road cell means something else
		# entirely.
		err = _T.assert_true(WeatherOverlay.DROUGHT_MARK_LENGTH < float(Board.CELL) * 0.25
				and WeatherOverlay.RAIN_MARK_LENGTH < float(Board.CELL) * 0.25,
			"a weather mark is a quarter of a cell at most, or it joins a vocabulary that "
				+ "is about single cells")
	return err


## The message queue's three outcomes, two of which lose a line.
##
## Asserted through the pure `queue_outcome` rather than by staging four messages through a
## live HUD, because the interesting cases are exactly the ones a live HUD makes hardest to
## reach — and because the rule is what matters, not one worked example of it.
##
## The tie case is the one worth the most: `_queue_message` compares with `>=`, so an
## arriving message at the same rung as the lowest queued one is REFUSED. That is not a
## corner case in this game — 19 of the 22 `show_message` call sites under `game/` pass no
## priority argument at all, so in a busy moment they all tie.
func test_a_full_message_queue_refuses_a_tie_and_evicts_a_loser() -> String:
	var full: Array[int] = []
	for i: int in Hud.MESSAGE_QUEUE_MAX:
		full.append(Hud.MESSAGE_NORMAL)
	var err: String = _T.assert_eq(full.size(), Hud.MESSAGE_QUEUE_MAX,
		"the queue under test is actually full (%d)" % full.size())
	if err == "":
		err = _T.assert_eq(Hud.queue_outcome([], Hud.MESSAGE_NORMAL), Hud.QUEUE_ACCEPTED,
			"an empty queue takes anything")
	if err == "":
		err = _T.assert_eq(Hud.queue_outcome(full.slice(1), Hud.MESSAGE_NORMAL),
			Hud.QUEUE_ACCEPTED, "and so does one with room left")
	if err == "":
		err = _T.assert_eq(Hud.queue_outcome(full, Hud.MESSAGE_NORMAL), Hud.QUEUE_REFUSED,
			"a full queue of equals REFUSES the arrival -- the comparison is >=, and this "
				+ "is the case 19 of 22 call sites land in")
	if err == "":
		err = _T.assert_eq(Hud.queue_outcome(full, Hud.MESSAGE_DEADLINE), Hud.QUEUE_EVICTED,
			"something more urgent evicts a waiting line instead")
	if err == "":
		var urgent: Array[int] = []
		for i: int in Hud.MESSAGE_QUEUE_MAX:
			urgent.append(Hud.MESSAGE_DEADLINE)
		err = _T.assert_eq(Hud.queue_outcome(urgent, Hud.MESSAGE_NORMAL), Hud.QUEUE_REFUSED,
			"and a full queue of urgent lines refuses an ordinary one")
	return err


func test_the_hud_counts_the_lines_it_never_showed() -> String:
	## The measurement `-i366` asked for, made possible: before cycle 93 a dropped line left
	## no trace anywhere, so "does the row actually lose messages in a real run" could not be
	## answered even in principle. Two counters and not one, because a REFUSED line is one
	## the caller just posted and the player will never see, while an EVICTED one was already
	## waiting -- different failures with different fixes.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var hud: Hud = game.hud
	hud._process(9.0)
	hud._message_left = 0.0
	hud._message_queue.clear()
	hud._advance_message_queue()
	hud.messages_refused = 0
	hud.messages_evicted = 0

	# One on the row, then MESSAGE_QUEUE_MAX behind it, then one more that cannot fit.
	hud.show_message("on the row", 6.0, Hud.MESSAGE_NORMAL)
	for i: int in Hud.MESSAGE_QUEUE_MAX:
		hud.show_message("waiting %d" % i, 6.0, Hud.MESSAGE_NORMAL)
	var err: String = _T.assert_eq(hud.pending_messages(), Hud.MESSAGE_QUEUE_MAX,
		"the queue is full before the interesting call")
	if err == "":
		err = _T.assert_eq(hud.messages_refused, 0, "and nothing has been lost yet")
	if err == "":
		err = _T.assert_false(hud.show_message("one too many", 6.0, Hud.MESSAGE_NORMAL),
			"the extra line does not reach the row")
	if err == "":
		err = _T.assert_eq(hud.messages_refused, 1,
			"and it is COUNTED as refused rather than vanishing")
	if err == "":
		err = _T.assert_eq(hud.messages_evicted, 0, "with nothing evicted, since it tied")
	if err == "":
		# The half I got wrong first, and it is the more interesting behaviour by some way.
		# A higher-rung arrival does NOT evict a waiting line -- it PRE-EMPTS, which pushes
		# the line it interrupted into the queue (see show_message's first branch). Against
		# a full queue of equals that displaced line is refused. So the cost of an urgent
		# message is not a queued line, it is THE LINE IT INTERRUPTED, and the player loses
		# the one they were mid-way through reading rather than one they had not reached.
		hud.show_message("urgent", 6.0, Hud.MESSAGE_DEADLINE)
		err = _T.assert_eq(hud.messages_refused, 2,
			"pre-empting costs the interrupted line, refused into a full queue")
	if err == "":
		err = _T.assert_eq(hud.messages_evicted, 0,
			"and nothing was evicted -- eviction needs a queue holding something LOWER "
				+ "than the arrival, which 19-of-22-on-one-rung makes rare")
	if err == "":
		# Eviction driven for real, since the counter is worth nothing unproven: put a
		# DEADLINE on the row so the next arrival waits rather than pre-empting, fill the
		# queue with NORMALs, then send an IMPORTANT that outranks them.
		hud._message_left = 0.0
		hud._message_queue.clear()
		hud._advance_message_queue()
		hud.messages_refused = 0
		hud.messages_evicted = 0
		hud.show_message("deadline holds the row", 6.0, Hud.MESSAGE_DEADLINE)
		for i: int in Hud.MESSAGE_QUEUE_MAX:
			hud.show_message("ordinary %d" % i, 6.0, Hud.MESSAGE_NORMAL)
		hud.show_message("outranks them", 6.0, Hud.MESSAGE_IMPORTANT)
		err = _T.assert_eq(hud.messages_evicted, 1,
			"an arrival outranking the queue's lowest evicts it")
		if err == "":
			err = _T.assert_eq(hud.messages_refused, 0, "and is not itself refused")
	_T.free_ui(game)
	return err


## What arming an uproot actually costs the line already on the row.
##
## Cycle 93 claimed the pre-empted line is erased. That was reasoned from the queue's drop
## rule and is WRONG for the case that matters: `show_message`'s pre-empt branch pushes the
## displaced line into the queue **with the time it had left**, and cycle 93's own
## measurement says the queue is essentially never full. So the line comes back, and the
## player's total reading time for it is preserved across the interruption rather than lost.
##
## Driven with the real numbers from the real call sites — `eaten_message` at 4.0 s and
## `MESSAGE_NORMAL` (`game/game.gd:1287`), the uproot prompt at `UPROOT_CONFIRM_SECONDS` and
## `MESSAGE_DEADLINE` (`game/game.gd:1392-1395`) — because the whole question is whether
## these two specific messages collide badly, not whether the queue works in the abstract.
func test_arming_an_uproot_defers_the_loss_notice_rather_than_erasing_it() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var hud: Hud = game.hud
	hud._process(9.0)
	hud._message_left = 0.0
	hud._message_queue.clear()
	hud._advance_message_queue()
	hud.messages_refused = 0
	hud.messages_evicted = 0

	var lost: String = Hud.eaten_message(PlantCatalog.display_name(PlantCatalog.CORN))
	hud.show_message(lost, 4.0, Hud.MESSAGE_NORMAL)
	# Half a second later the player arms an uproot. This is the collision the bead is about.
	hud._process(0.5)
	var armed: bool = hud.show_message("uproot armed", Game.UPROOT_CONFIRM_SECONDS,
		Hud.MESSAGE_DEADLINE)

	var err: String = _T.assert_true(armed, "the uproot prompt takes the row, as a deadline must")
	if err == "":
		err = _T.assert_eq(hud.messages_refused, 0,
			"and the bed's loss notice is NOT refused -- it was deferred, not erased")
	if err == "":
		err = _T.assert_eq(hud.pending_messages(), 1, "it is waiting")
	if err == "":
		# The half that decides whether "deferred" is good enough: it comes back with the
		# time it had LEFT, so the player's total reading time is preserved across the
		# interruption. 3.5 of its 4.0 s here, which is well over MESSAGE_MIN_READABLE.
		var waiting: float = float(hud._message_queue[0]["seconds"])
		err = _T.assert_float_eq(waiting, 3.5, 0.05,
			"with 3.5s of its 4.0s left, not a stub (%.2fs)" % waiting)
	if err == "":
		err = _T.assert_gte(waiting_seconds(hud), Hud.MESSAGE_MIN_READABLE,
			"and more than the row's own definition of long enough to have been read")
	if err == "":
		# Let the deadline run out; the loss notice must actually return to the row.
		hud._process(Game.UPROOT_CONFIRM_SECONDS + 0.1)
		var label: Label = hud.get_node_or_null("Root/TopBar/MessageLabel") as Label
		err = _T.assert_eq(label.text, lost,
			"and when the prompt expires the player is told which plant they lost")
	_T.free_ui(game)
	return err


## The seconds the first queued message will get when it returns. A helper so the assertion
## above reads as a claim about readability rather than as dictionary indexing.
func waiting_seconds(hud: Hud) -> float:
	if hud._message_queue.is_empty():
		return 0.0
	return float(hud._message_queue[0]["seconds"])


func test_the_loss_notice_is_lost_only_in_a_state_real_play_does_not_reach() -> String:
	## The other half of the answer, and the honest one: the notice IS destroyed if the
	## queue is full of equals when the uproot arms, because the pre-empt branch pushes it
	## into a queue that refuses it. That is the failure `-trn1` was filed about.
	##
	## Asserted here so the good news above is bounded rather than optimistic -- and paired
	## with what it takes to get there, which is the actual finding: FOUR ordinary messages
	## still live at the instant a bed dies. Cycle 93 measured a real run to a full loss and
	## saw the row drop nothing at all, so this state is reachable in principle and was not
	## reached in six waves of play.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var hud: Hud = game.hud
	hud._process(9.0)
	hud._message_left = 0.0
	hud._message_queue.clear()
	hud._advance_message_queue()
	hud.messages_refused = 0

	# The row plus a full queue, all ordinary -- then the bed dies, then the uproot arms.
	hud.show_message("ambient", 6.0, Hud.MESSAGE_NORMAL)
	for i: int in Hud.MESSAGE_QUEUE_MAX:
		hud.show_message("ambient %d" % i, 6.0, Hud.MESSAGE_NORMAL)
	var err: String = _T.assert_eq(hud.pending_messages(), Hud.MESSAGE_QUEUE_MAX,
		"the queue is full before the collision")
	if err == "":
		# The loss notice cannot even reach the row -- it is refused on arrival, before the
		# uproot is involved at all. So the uproot is not the villain here; a saturated row
		# is, and it saturates from four ordinary lines.
		err = _T.assert_false(hud.show_message(
			Hud.eaten_message(PlantCatalog.display_name(PlantCatalog.CORN)), 4.0,
			Hud.MESSAGE_NORMAL),
			"a bed dying into a saturated row does not reach it")
	if err == "":
		err = _T.assert_eq(hud.messages_refused, 1,
			"and the loss is counted, which is how anyone would ever find out")
	if err == "":
		err = _T.assert_gte(float(Hud.MESSAGE_QUEUE_MAX + 1), 4.0,
			"it takes %d simultaneous ordinary lines to reach this state"
				% [Hud.MESSAGE_QUEUE_MAX + 1])
	_T.free_ui(game)
	return err


## The rule deciding whether a displaced line comes back, asserted on both sides of its
## threshold before anything that reads it.
##
## `MESSAGE_MIN_READABLE` is reused rather than a new number invented, and the reuse is
## load-bearing: `show_message`'s wait branch already treats that constant as "long enough to
## have been read" when deciding whether an equal-rung arrival may stomp. Asking the same
## question about the same row with a second threshold would be a second opinion.
func test_a_line_the_player_has_had_time_to_read_is_not_brought_back() -> String:
	var err: String = _T.assert_false(Hud.line_was_read(4.0, 3.5),
		"half a second of a four-second line is not a read")
	if err == "":
		err = _T.assert_true(Hud.line_was_read(4.0, 0.5),
			"three and a half seconds of it is")
	if err == "":
		# Exactly at the threshold, expressed so no arithmetic happens: `4.0 - (4.0 - 1.2)`
		# is 1.2000000000000002, which is strictly greater than 1.2, so a boundary written
		# that way passes under BOTH `>` and `>=` and tests nothing. A mutation flipping the
		# comparison survived it. These two literals subtract exactly.
		err = _T.assert_true(Hud.line_was_read(Hud.MESSAGE_MIN_READABLE, 0.0),
			"the threshold itself counts as read -- the boundary is >=, matching the "
				+ "wait branch that uses the same constant the other way round")
	if err == "":
		err = _T.assert_false(Hud.line_was_read(4.0, 4.0),
			"a line that has not started is not read")
	return err


func test_a_read_line_is_retired_and_an_unread_one_resumes() -> String:
	## The behaviour both ways, because the interesting half is the one that DOESN'T come
	## back and a fix that simply stopped resuming everything would pass the retirement
	## assertion alone. Cycle 94's test covers the resume case through the real uproot
	## collision; this drives the same row past the threshold.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var hud: Hud = game.hud
	hud._process(9.0)
	hud._message_left = 0.0
	hud._message_queue.clear()
	hud._advance_message_queue()
	hud.messages_preempted = 0
	hud.messages_retired = 0

	# Read for well over MESSAGE_MIN_READABLE, then displaced.
	hud.show_message("a line the player has read", 4.0, Hud.MESSAGE_NORMAL)
	hud._process(3.0)
	hud.show_message("urgent", 4.0, Hud.MESSAGE_DEADLINE)
	var err: String = _T.assert_eq(hud.messages_preempted, 1, "the line was displaced")
	if err == "":
		err = _T.assert_eq(hud.messages_retired, 1, "and retired rather than queued")
	if err == "":
		err = _T.assert_eq(hud.pending_messages(), 0,
			"so nothing is waiting to reappear and confuse anyone")

	# Now the other side: displaced before the player could read it.
	if err == "":
		hud._message_left = 0.0
		hud._message_queue.clear()
		hud._advance_message_queue()
		hud.messages_preempted = 0
		hud.messages_retired = 0
		hud.show_message("a line the player has NOT read", 4.0, Hud.MESSAGE_NORMAL)
		hud._process(0.4)
		hud.show_message("urgent", 4.0, Hud.MESSAGE_DEADLINE)
		err = _T.assert_eq(hud.messages_preempted, 1, "displaced again")
	if err == "":
		err = _T.assert_eq(hud.messages_retired, 0, "but NOT retired this time")
	if err == "":
		err = _T.assert_eq(hud.pending_messages(), 1, "it is waiting, and will come back")
	_T.free_ui(game)
	return err


func test_a_plant_button_says_the_price_and_nothing_else() -> String:
	## Three states in two symbols, and the empty one is the load-bearing choice.
	##
	## Taking the NAME off the button is what bought the second column: the minimum width
	## went from 195px, against the 114px a two-column bar can give, to 8px. Every earlier
	## attempt to fit six plants tried to divide 232 by two without changing what had to fit
	## inside it, which is why two columns was "unrenderable" for cycles rather than merely
	## unbuilt.
	##
	## A locked plant shows NOTHING rather than the word "locked". That is the same fact in
	## one fewer channel -- a number means you may buy it, no number means it is not for sale
	## yet -- and it costs the button no width at all, which is the point.
	var err: String = _T.assert_eq(Hud.plant_button_label(false, 25), "",
		"a locked plant shows no price, because there is no price to show yet")
	if err == "":
		err = _T.assert_eq(Hud.plant_button_label(false, 0), "",
			"and a locked plant that would be free is still locked")
	if err == "":
		err = _T.assert_eq(Hud.plant_button_label(true, 0), "free",
			"the starter says so in a word rather than a zero")
	if err == "":
		err = _T.assert_eq(Hud.plant_button_label(true, 25), "25",
			"and a purchasable plant is its number, with no unit -- the seed count at the "
				+ "top of the screen is the only currency there is")
	if err == "":
		# The width claim, asserted rather than described: every label the catalogue can
		# produce has to fit a two-column button, and the longest is the one to check.
		var longest: int = 0
		for id: StringName in PlantCatalog.ids():
			longest = maxi(longest, Hud.plant_button_label(true, PlantCatalog.cost(id)).length())
		err = _T.assert_true(longest <= 4,
			"the longest label any catalogue plant produces is %d characters -- 'free' is "
				+ "the ceiling, and a five-figure price would be a different bar" % longest)
	return err


# -- The Nettle's sting cue (plant-tower-defense-e5kh) -----------------------
#
# The sting was the only damaging act in the game that made no sound. What
# follows pins the DECISION as much as the presence of a row: the sting is a
# VARIANT of the soft impact `CORN_FIRED` and `PLANT_BITTEN` already share, so
# the things worth asserting are that it is told apart from both of them, that
# its pitch points the way `Sfx.PITCH`'s header says a gain points and by a
# magnitude that keeps that column a scale, and that its repeat gate was derived
# from the Nettle's own interval instead of copied off a row above it.
#
# **What is deliberately NOT asserted here: that `Nettle._sting` calls
# `Sfx.play` at all.** `play()` is gated on `Sfx.is_headless()` and records
# nothing when it refuses, so under the headless runner a mutation deleting that
# one line survives every check below. That is the same limit test_combat.gd's
# sound section states at its own top -- nothing headless can claim a sound was
# audible -- and it is what the runtime pass is for.


func test_the_nettle_sting_carries_a_row_in_all_four_sfx_tables() -> String:
	## Four tables because `Sfx.play` reads four: `SOUNDS` decides whether anything
	## sounds at all, `REPEAT_MS` gates how often, and `tune_voice` composes
	## `VOLUME_DB` and `PITCH`.
	##
	## Three of the four are not required by the ENGINE, and it is worth being exact
	## about why they are required here. Each of those three documents an absent key
	## as a default and reads it as one (`VOLUME_DB.get(event, 0.0)`,
	## `PITCH.get(event, 1.0)`, `REPEAT_MS.get(event, DEFAULT_REPEAT_MS)`), and
	## `tune_voice` writes every property unconditionally precisely so a pooled voice
	## cannot carry the last event's value forward -- so a missing row is silent-safe
	## rather than a bug. What makes them mandatory for THIS event is that it shares
	## its file with two others: with no volume and no pitch of its own the sting
	## would reach the player as `CORN_FIRED` exactly, which is the confusion the cue
	## was added to prevent.
	var err: String = _T.assert_true(Sfx.SOUNDS.has(Sfx.NETTLE_STING),
		"SOUNDS carries the sting -- without this row the cue is silent and `play` "
			+ "returns false forever")
	if err == "":
		err = _T.assert_true(Sfx.VOLUME_DB.has(Sfx.NETTLE_STING),
			"VOLUME_DB carries it, so the sting is not CORN_FIRED's 0.0 by omission")
	if err == "":
		err = _T.assert_true(Sfx.PITCH.has(Sfx.NETTLE_STING),
			"PITCH carries it, so the sting is not the base 1.0 by omission")
	if err == "":
		err = _T.assert_true(Sfx.REPEAT_MS.has(Sfx.NETTLE_STING),
			("REPEAT_MS carries it, so a bank of Nettles is not gated by "
				+ "DEFAULT_REPEAT_MS's %dms") % Sfx.DEFAULT_REPEAT_MS)
	if err == "":
		# And the row points somewhere real. A path that does not resolve fails in
		# exactly the way this whole item was filed about.
		err = _T.assert_true(Sfx.stream_for(Sfx.NETTLE_STING) != null,
			"and the file behind it loads as an AudioStream: %s"
				% String(Sfx.SOUNDS.get(Sfx.NETTLE_STING, "")))
	if err == "":
		err = _T.assert_true(Sfx.should_play(Sfx.NETTLE_STING, false, false),
			"an unmuted player with a display would hear it -- the gate says yes")
	return err


func test_the_sting_is_told_apart_from_everything_sharing_its_file() -> String:
	## The variant decision, asserted rather than described.
	##
	## `test_no_two_events_are_the_same_sound` in test_combat.gd already forbids two
	## events arriving identically, across the whole table. This asks the sharper
	## question the sting actually raises: the events on ITS file are the ones a
	## player could mistake it for, and the ORDER of their volumes is the statement
	## being made -- a volley that will cross the board is louder than one plant's
	## contact hit, which is louder than a pest chewing in the background.
	##
	## The sharers are derived from `SOUNDS` rather than named, so a fourth event
	## put on this file is checked against the sting the day it is added.
	var file: String = String(Sfx.SOUNDS.get(Sfx.NETTLE_STING, "")).get_file()
	var sharers: Array[StringName] = []
	for event: StringName in Sfx.SOUNDS:
		if event == Sfx.NETTLE_STING:
			continue
		if String(Sfx.SOUNDS[event]).get_file() == file:
			sharers.append(event)
	# Denominator: if nothing shares the file, the sweep below proves nothing and
	# the whole "variant" argument in Sfx.NETTLE_STING's comment has gone stale.
	var err: String = _T.assert_gt(sharers.size(), 1,
		("the sting really is sharing %s with others, which is what makes it a "
			+ "variant rather than a voice of its own -- got %d sharer(s)")
			% [file, sharers.size()])
	var sting_db: float = float(Sfx.VOLUME_DB.get(Sfx.NETTLE_STING, 0.0))
	var sting_pitch: float = float(Sfx.PITCH.get(Sfx.NETTLE_STING, 1.0))
	for event: StringName in sharers:
		if err != "":
			break
		var db: float = float(Sfx.VOLUME_DB.get(event, 0.0))
		var pitch: float = float(Sfx.PITCH.get(event, 1.0))
		err = _T.assert_true(not is_equal_approx(db, sting_db)
				or not is_equal_approx(pitch, sting_pitch),
			("the sting and '%s' are both %s at %.1f dB, pitch %.2f -- the player "
				+ "cannot tell them apart") % [event, file, db, pitch])
	if err == "":
		err = _T.assert_gt(float(Sfx.VOLUME_DB.get(Sfx.CORN_FIRED, 0.0)), sting_db,
			"a volley crossing the board is louder than one plant's contact hit")
	if err == "":
		err = _T.assert_gt(sting_db, float(Sfx.VOLUME_DB.get(Sfx.PLANT_BITTEN, 0.0)),
			"and a contact hit is louder than a pest chewing in the background -- "
				+ "the three rungs on this file are a scale, not three free numbers")
	return err


func test_the_gains_read_as_a_scale() -> String:
	## `Sfx.PITCH`'s header says gains go above the base and are graded by how big
	## the gain is. The losses half of that claim is already pinned (test_combat's
	## `test_tuning_a_voice_applies_both_axes_the_table_declares` asserts a plant
	## dying sits below a plant eating); the gains half was three numbers and a
	## paragraph, and the sting is the fourth.
	##
	## The gains are DERIVED from the table -- every entry above 1.0 -- rather than
	## listed, so a fifth gain added below the base, or a "gain" written as a cut,
	## fails here instead of quietly breaking the direction the header claims.
	var gains: Array[StringName] = []
	for event: StringName in Sfx.PITCH:
		if float(Sfx.PITCH[event]) > 1.0:
			gains.append(event)
	var err: String = _T.assert_gt(gains.size(), 2,
		"there are several gains to order (an empty sweep is a vacuous pass), got %d"
			% gains.size())
	if err == "":
		err = _T.assert_true(gains.has(Sfx.NETTLE_STING),
			"the sting is one of them -- damage dealt is a gain, so it points up")
	if err == "":
		err = _T.assert_gt(float(Sfx.PITCH.get(Sfx.PEST_KILLED_HARD, 1.0)),
			float(Sfx.PITCH.get(Sfx.NETTLE_STING, 1.0)),
			"and it is the SHALLOWEST of them, because 3.0 damage off one pest is a "
				+ "smaller gain than the kill it may or may not lead to")
	if err == "":
		err = _T.assert_gt(float(Sfx.PITCH.get(Sfx.PLANT_UPGRADED, 1.0)),
			float(Sfx.PITCH.get(Sfx.PEST_KILLED_HARD, 1.0)),
			"which leaves the whole column a scale: sting, hard kill, upgrade")
	return err


func test_a_bank_of_nettles_cannot_machine_gun_the_sting() -> String:
	## The number the bead asked to be derived rather than copied, derived here too
	## so the derivation is executable instead of a comment.
	##
	## `Nettle.sting_interval()` is `STING_INTERVAL` composed with the sky and the
	## neighbours (`Plant.composed_interval`). Only one of those two can make it
	## SHORTER, and that asymmetry is the load-bearing half -- so it is asserted
	## rather than assumed, over all three weathers, before the floor is computed
	## from the Mints alone.
	var weathers: Array[StringName] = [
		# The three ids in wave_director.gd; there is no enumerated list to derive
		# from, and `weather_for` can return any of them.
		WaveDirector.WEATHER_CLEAR, WaveDirector.WEATHER_RAIN,
		WaveDirector.WEATHER_DROUGHT,
	]
	var err: String = ""
	for weather: StringName in weathers:
		var weather_scale: float = WaveDirector.fire_interval_scale_for(weather)
		err = _T.assert_gte(weather_scale, 1.0,
			("weather '%s' cannot speed a plant up (%.2f) -- if one ever does, the "
				+ "floor below stops being the floor") % [weather, weather_scale])
		if err != "":
			return err
	# The fastest a single Nettle can ever sting: every Mint cell around it filled.
	var most_mints: int = Mint.NEIGHBOUR_OFFSETS.size()
	var floor_ms: float = (Plant.composed_interval(Nettle.STING_INTERVAL, 1.0,
		Mint.scale_for(most_mints)) * 1000.0)
	var gate: int = int(Sfx.REPEAT_MS.get(Sfx.NETTLE_STING, Sfx.DEFAULT_REPEAT_MS))
	err = _T.assert_gt(floor_ms, float(gate),
		("the gate (%dms) sits under the fastest interval a lone Nettle can reach "
			+ "(%.0fms, ringed by %d Mints), so no board a player can build loses "
			+ "one of its own stings to the throttle") % [gate, floor_ms, most_mints])
	if err == "":
		# And the row is doing something the default was not. Nettles planted in the
		# same breath stay phase-locked forever -- STING_INTERVAL is a constant --
		# so the gate has to be wide enough to swallow a bank that has drifted a few
		# frames apart, not just one that fires in the same frame.
		err = _T.assert_gt(gate, Sfx.DEFAULT_REPEAT_MS,
			("and it is wider than DEFAULT_REPEAT_MS's %dms, which is the only "
				+ "reason the row exists at all") % Sfx.DEFAULT_REPEAT_MS)
	return err


func test_the_sting_reaches_a_voice_carrying_its_own_numbers() -> String:
	## The table rows are read, not merely present. `Sfx.tune_voice` is the seam
	## cycle 74 extracted for exactly this: `PITCH` stayed perfectly unique while
	## nothing read it, and the player heard twins. A sting whose rows exist and
	## whose voice comes out at CORN_FIRED's settings is that bug again.
	var voice := AudioStreamPlayer.new()
	Sfx.tune_voice(voice, Sfx.CORN_FIRED)
	var corn_db: float = voice.volume_db
	var corn_pitch: float = voice.pitch_scale
	Sfx.tune_voice(voice, Sfx.NETTLE_STING)
	var err: String = _T.assert_float_eq(voice.volume_db,
		float(Sfx.VOLUME_DB.get(Sfx.NETTLE_STING, 0.0)), 0.0001,
		"the voice took the sting's volume off the table")
	if err == "":
		# A BAND, not a point, since plant-tower-defense-r8zc: the sting is one of the
		# cues that wobbles, so its pitch is the table's centre plus a per-play offset
		# inside Sfx.JITTER's half-width. The claim this line makes is unchanged -- the
		# voice took the STING's numbers and not the previous event's -- and the band
		# is still nowhere near any other cue's, which
		# test_two_events_on_one_file_never_overlap_once_they_wobble pins separately.
		err = _T.assert_float_eq(voice.pitch_scale,
			float(Sfx.PITCH.get(Sfx.NETTLE_STING, 1.0)),
			float(Sfx.JITTER.get(Sfx.NETTLE_STING, 0.0)) + 0.0001,
			"and its pitch, rather than keeping the last event's")
	if err == "":
		err = _T.assert_true(not is_equal_approx(voice.volume_db, corn_db)
				or not is_equal_approx(voice.pitch_scale, corn_pitch),
			("so a voice that just played CORN_FIRED (%.1f dB, pitch %.2f) comes out "
				+ "different for a sting (%.1f dB, pitch %.2f)")
				% [corn_db, corn_pitch, voice.volume_db, voice.pitch_scale])
	voice.free()
	return err


# ---------------------------------------------------------------------------------------
# Falling rain (plant-tower-defense-jwd6) — the weather overlay's motion
# ---------------------------------------------------------------------------------------


## The rain phase advances with delta, which is the whole of "rain falls".
##
## Asserted through `WeatherOverlay.advance_rain_phase` rather than by pumping `_process`,
## because `_process` needs frames a headless runner does not pump AND the callback is armed
## only when `GardenTheme.animations_enabled()` is true, which is false for every test in this
## suite by construction. A test that instantiated the overlay and waited would be asserting
## the early return — the exact shape cycles 71 and 74 got wrong.
func test_the_rain_phase_advances_with_delta() -> String:
	var frame: float = 1.0 / 60.0
	var one: float = WeatherOverlay.advance_rain_phase(0.0, frame)
	var err: String = _T.assert_gt(one, 0.0,
		("a frame of rain moves the phase off zero, got %.4f -- a phase that never advances "
			+ "is the still frame the designer called 'rain froze'") % one)
	if err == "":
		# Proportional, not merely nonzero: a phase that jumped a fixed step per frame would
		# also pass the line above and would run at a different speed on a 144 Hz monitor.
		err = _T.assert_float_eq(WeatherOverlay.advance_rain_phase(0.0, frame * 2.0),
			one * 2.0, 0.0001,
			"twice the delta moves twice as far, so the fall is in seconds and not in frames")
	if err == "":
		err = _T.assert_float_eq(
			WeatherOverlay.advance_rain_phase(WeatherOverlay.advance_rain_phase(0.0, frame),
				frame),
			WeatherOverlay.advance_rain_phase(0.0, frame * 2.0), 0.0001,
			"and it accumulates -- two frames land where one double-length frame lands")
	if err == "":
		err = _T.assert_float_eq(WeatherOverlay.advance_rain_phase(50.0, 0.0), 50.0, 0.0001,
			"a zero delta is a held frame, not a nudge")
	if err == "":
		# A paused-then-resumed tree can hand `_process` a negative delta on some platforms;
		# rain that ran backwards for a frame would read as a glitch rather than as weather.
		err = _T.assert_float_eq(WeatherOverlay.advance_rain_phase(50.0, -1.0), 50.0, 0.0001,
			"and rain never falls upwards")
	if err == "":
		err = _T.assert_gt(WeatherOverlay.RAIN_FALL_SPEED, 0.0,
			"the speed is a real speed, %.1f px/s" % WeatherOverlay.RAIN_FALL_SPEED)
	return err


## Where a mark is once it has fallen: on the board, along the slant, and back at the start
## when the phase is zero.
##
## The last of those is what keeps the animations-disabled path honest — with motion off the
## phase is pinned at zero, so "the still picture" and "the first frame of the falling one"
## have to be the same picture rather than two code paths that drift apart.
func test_a_falling_rain_mark_scrolls_along_the_slant_and_stays_on_the_board() -> String:
	var size := Vector2(896.0, 576.0)
	var err: String = ""
	for i: int in range(WeatherOverlay.MARK_COUNT):
		err = _T.assert_eq(WeatherOverlay.rain_mark_position(i, size, 0.0),
			WeatherOverlay.mark_position(i, size),
			"mark %d at rest is exactly where the still overlay drew it" % i)
		if err != "":
			return err
	# One second of fall, then a whole minute of it: a mark that walked off the board would
	# leave the rain thinning out to nothing over a long wave.
	var phases: Array[float] = [
		WeatherOverlay.RAIN_FALL_SPEED * 1.0,
		WeatherOverlay.RAIN_FALL_SPEED * 7.3,
		WeatherOverlay.RAIN_FALL_SPEED * 60.0]
	var moved: int = 0
	var along: int = 0
	var unit: Vector2 = WeatherOverlay.RAIN_SLANT.normalized()
	for phase: float in phases:
		for i: int in range(WeatherOverlay.MARK_COUNT):
			var at: Vector2 = WeatherOverlay.rain_mark_position(i, size, phase)
			err = _T.assert_true(
				at.x >= 0.0 and at.x < size.x and at.y >= 0.0 and at.y < size.y,
				"mark %d is still on the board %.0f px into the fall, at %s" % [i, phase, at])
			if err != "":
				return err
			var was: Vector2 = WeatherOverlay.mark_position(i, size)
			if not at.is_equal_approx(was):
				moved += 1
			# Marks that have not wrapped yet must have travelled DOWN THE SLANT, not in some
			# other direction: the fall and the drawn streak have to agree or the streaks
			# read as sliding sideways.
			var step: Vector2 = at - was
			if is_equal_approx(step.length(), phase) or absf(step.length() - phase) < 0.001:
				if step.normalized().dot(unit) > 0.999:
					along += 1
	if err == "":
		err = _T.assert_gte(moved, WeatherOverlay.MARK_COUNT * phases.size(),
			"every mark moved at every sampled phase, %d of %d" % [moved,
				WeatherOverlay.MARK_COUNT * phases.size()])
	if err == "":
		# Not vacuous: at least some marks are far enough from an edge that no wrap hides the
		# direction, and those are the ones the dot product above was measured on.
		err = _T.assert_gt(along, 0,
			"and %d unwrapped mark(s) travelled along RAIN_SLANT itself" % along)
	return err


## Rain moves; nothing else does — and with motion off, nothing does at all.
##
## The weather list is derived from `WaveDirector.weather_for()` rather than typed here, so a
## fourth weather added to the director arrives in this test on its own instead of being
## quietly excluded from it.
func test_only_rain_moves_and_only_when_motion_is_allowed() -> String:
	var states: Dictionary = {}
	for wave: int in range(1, 71):
		states[WaveDirector.weather_for(wave)] = true
	var err: String = _T.assert_gte(states.size(), 3,
		"the director produces %d distinct weathers over 70 waves" % states.size())
	if err == "":
		err = _T.assert_true(states.has(WaveDirector.WEATHER_RAIN),
			"and rain is one of them, or this test is about nothing")
	if err != "":
		return err
	for weather: StringName in states.keys():
		var wants: bool = weather == WaveDirector.WEATHER_RAIN
		err = _T.assert_eq(WeatherOverlay.rain_should_fall(weather, true), wants,
			("%s %s while motion is on -- 'rain falls, a drought is the weather in which "
				+ "nothing moves' is the third channel, after hue and mark shape")
				% [weather, "falls" if wants else "holds still"])
		if err != "":
			return err
		# The capability gate: with animations off the overlay must paint the same still frame
		# it painted before this change, for every weather without exception.
		err = _T.assert_false(WeatherOverlay.rain_should_fall(weather, false),
			"%s is still with animations disabled" % weather)
		if err != "":
			return err
	return err


# -- Top-bar styling (plant-tower-defense-7mj3) ------------------------------
#
# James: "the text at the top could use some styling." The bar was a flat INK
# ColorRect carrying four default-font Labels and one grey Godot Button -- the
# only surface in the game wearing none of the notebook everything below it is
# drawn on.
#
# The checks below pin the two things that pass could get wrong. FIRST, that the
# styling is free: the stats row is a budgeted sum with ~19px of slack
# (`stats_row_budget`), and decoration that quietly took a slot in it would show
# up as an occlusion bug waves later rather than as a failing test now. SECOND,
# that it is legible: every colour the bar writes in has to clear the palette's
# own separation floor against the bar's ink -- on BOTH threat ramps, because the
# colourblind ramp is a second set of paints that no eye on a screenshot checks.


## The page rules are on the bar, and they are ColorRects sitting outside the
## row's layout rather than inside it.
##
## The second half is the load-bearing one. A rule added as a fifth child of the
## StatsRow would look identical in a screenshot and would be spending width out
## of a budget that has already produced one collision bug in this bar.
func test_the_top_bar_wears_the_notebooks_page_rules() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	await _pump(game)
	var stats: HBoxContainer = game.hud.get_node_or_null("Root/TopBar/StatsRow") as HBoxContainer
	var margin: ColorRect = game.hud.get_node_or_null("Root/TopBar/MarginRule") as ColorRect
	var err: String = _T.assert_true(margin != null and stats != null,
		"the top bar has a margin rule and a stats row")
	if err == "":
		err = _T.assert_true(margin.color.is_equal_approx(GardenTheme.PAPER_RULE),
			"the rule is the notebook stock's own blue, got %s" % margin.color)
	if err == "":
		# In the gutter the row already left empty -- the reason it costs nothing.
		err = _T.assert_true(margin.position.x + margin.size.x <= stats.position.x,
			"the margin rule ends at %.0f, left of the first readout at %.0f"
				% [margin.position.x + margin.size.x, stats.position.x])
	if err == "":
		# And clear of the prep strip's band. `_hud_rects` below skips ColorRects,
		# so nothing else in this suite compares these two -- the occlusion audit
		# does, and an opaque strip drawn over an opaque rule is a finding there.
		err = _T.assert_true(
			margin.position.y + margin.size.y <= float(Hud.BAR_HEIGHT) - Hud.PREP_BAR_HEIGHT,
			"the margin rule stops at %.0f, above the prep strip's band at %.0f"
				% [margin.position.y + margin.size.y, float(Hud.BAR_HEIGHT) - Hud.PREP_BAR_HEIGHT])
	if err == "":
		# Not a child count -- a later feature is expected to add a control to this
		# row, and a pinned count would fail for that rather than for decoration.
		# What must stay true is that no *decoration* holds a slot in the sum.
		var slots: PackedStringArray = []
		for child: Node in stats.get_children():
			if child is ColorRect:
				slots.append(String(child.name))
		err = _T.assert_eq(slots.size(), 0,
			"no page rule takes a width slot in the budgeted row: %s" % ", ".join(slots))
	if err == "":
		var missing: PackedStringArray = []
		for readout: String in Hud.WORST_CASE_TEXT:
			var label: Label = stats.get_node_or_null(readout) as Label
			if label == null:
				missing.append("%s: no such readout" % readout)
				continue
			var rule: ColorRect = label.get_node_or_null("%sRule" % readout) as ColorRect
			if rule == null:
				missing.append("%s: no ruled line under it" % readout)
				continue
			if not is_equal_approx(rule.size.x, label.size.x):
				missing.append("%s: rule is %.0fpx under a %.0fpx readout"
					% [readout, rule.size.x, label.size.x])
			elif not is_equal_approx(rule.size.y, Hud.READOUT_RULE_HEIGHT):
				missing.append("%s: rule is %.1fpx tall" % [readout, rule.size.y])
			elif not rule.show_behind_parent:
				missing.append("%s: rule draws over its own text" % readout)
		err = _T.assert_eq(missing.size(), 0,
			"every readout is written on a ruled line: %s" % ", ".join(missing))
	_T.free_ui(game)
	return err


# -- The seed-packet rack: spent vs unaffordable, and which packet holds what --
# -- (plant-tower-defense-m97n, plant-tower-defense-h6ek) ---------------------


## The two reasons a packet button is grey are two different pieces of news, and
## before m97n they were one picture. "Come back with 12 more seeds" is a WAIT;
## "every plant this tier can hold is already yours" is a DEAD END and a redirect
## to the pricier packet. They were told apart only in `tooltip_text`, which is
## read by the player who already suspected there was something to read.
##
## So this asserts the distinction on the LABEL, deliberately not on the tooltip —
## the tooltip has said the right thing all along and asserting it would re-pass
## the test that was already passing while the defect was live.
func test_a_spent_packet_button_says_so_on_its_face_not_only_in_its_tooltip() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var common: Button = game.hud.get_node_or_null("Root/SidePanel/PacketButton") as Button
	var err: String = _T.assert_true(common != null, "the common packet button exists")
	var cost: int = int((SeedBank.PACKET_TIERS[&"common"] as Dictionary)["cost"])
	var broke_text: String = ""
	var spent_text: String = ""
	if err == "":
		# State one: the tier still has stock, the purse does not have the price.
		game.bank.set_seed(11)
		game.bank.seeds = 0
		game._refresh()
		await _pump(game)
		broke_text = common.text
		err = _T.assert_true(common.disabled, "with an empty purse the packet is disabled")
	if err == "":
		err = _T.assert_true(broke_text.contains(str(cost)),
			"and still quotes the price it is waiting for, got %s" % broke_text)
	if err == "":
		# State two: the purse is full and the tier is spent. Drained through the
		# real purchase path, so the state is one the game can actually reach.
		game.bank.add_seeds(600)
		var guard: int = 0
		while not game.bank.packet_pool(&"common").is_empty() and guard < 40:
			game.bank.buy_packet(&"common")
			guard += 1
		err = _T.assert_true(game.bank.packet_pool(&"common").is_empty(), "tier 1 is spent")
	if err == "":
		err = _T.assert_gt(game.bank.seeds, cost,
			"and affordability is NOT the reason this one is grey")
	if err == "":
		game._refresh()
		await _pump(game)
		spent_text = common.text
		err = _T.assert_true(common.disabled, "the spent packet is disabled too")
	if err == "":
		err = _T.assert_true(spent_text != broke_text,
			("the two greys read differently on the button itself: unaffordable said "
				+ "%s, spent says %s") % [broke_text, spent_text])
	if err == "":
		err = _T.assert_false(spent_text.contains(str(cost)),
			("and a spent packet quotes no price, because there is no longer one to "
				+ "pay: %s") % spent_text)
	if err == "":
		# The row is 232px and already fits the buyable label. Measuring the spent
		# one against its own buyable form is the whole width argument: nothing this
		# function returns is wider than the string the rack has shipped for cycles.
		# `findings`' own button_text_overflow datum for this font is 99px for the 11
		# characters of "Common (20)", so a longer spent form would not have fitted.
		var font_size: int = common.get_theme_font_size("font_size")
		err = _T.assert_gt(font_size, 0, "the button resolves a font size to measure at")
		if err == "":
			var spent_px: float = GardenTheme.measure(spent_text, font_size)
			var broke_px: float = GardenTheme.measure(broke_text, font_size)
			err = _T.assert_gt(broke_px, 0.0, "the font resolved (a 0px measurement is vacuous)")
			if err == "":
				err = _T.assert_true(spent_px <= broke_px,
					("and the spent label (%s, %.0fpx) is no wider than the buyable one "
						+ "(%s, %.0fpx) the row already fits")
						% [spent_text, spent_px, broke_text, broke_px])
	_T.free_ui(game)
	return err


## The label's own contract, without a HUD: every tier tells its two states apart,
## and the spent one is not merely the buyable one with the number changed.
func test_every_packet_tier_has_a_spent_label_distinct_from_its_priced_one() -> String:
	var err: String = ""
	var checked: int = 0
	for tier: StringName in SeedBank.PACKET_ORDER:
		var cost: int = int((SeedBank.PACKET_TIERS[tier] as Dictionary)["cost"])
		var priced: String = Hud.packet_button_text(tier, 3)
		var spent: String = Hud.packet_button_text(tier, 0)
		err = _T.assert_true(priced.contains(str(cost)),
			"%s's buyable label quotes its price: %s" % [tier, priced])
		if err == "":
			err = _T.assert_false(spent.contains(str(cost)),
				"and its spent label does not, or the two are one number apart: %s" % spent)
		if err == "":
			err = _T.assert_true(spent.contains("Empty"),
				"and says so in a word rather than by omission: %s" % spent)
		if err == "":
			checked += 1
		else:
			break
	if err == "":
		err = _T.assert_eq(checked, SeedBank.PACKET_ORDER.size(),
			"every tier in the rack was checked (an empty sweep is a vacuous pass)")
	if err == "":
		err = _T.assert_true(Hud.packet_button_text(&"nosuchtier", 1).is_empty(),
			"and an unknown tier gets no label rather than a malformed one")
	return err


## h6ek's cue, and the ONE thing about it that has to hold: the set of plant
## buttons a packet lights EQUALS that packet's pool. Both directions, because a
## cue that lights everything and a cue that lights the right things are the same
## picture on a garden where everything happens to be in range.
##
## Asserted against `packet_pool()` at test time rather than against a written-out
## list of "the plants a rare packet holds" — that list is the exact artefact this
## bead exists to avoid, and a test that carried one would go stale in the same
## breath as the feature.
func test_hovering_a_packet_lights_exactly_the_locked_plants_it_can_hand_over() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var rare: Button = game.hud.get_node_or_null("Root/SidePanel/RarePacketButton") as Button
	var err: String = _T.assert_true(rare != null, "the rare packet button exists")
	var pool: Array[StringName] = []
	if err == "":
		game._refresh()
		await _pump(game)
		pool = game.bank.packet_pool(&"rare")
		err = _T.assert_gt(pool.size(), 1,
			"a rare packet has more than one plant to point at (an empty pool is a vacuous pass)")
	if err == "":
		var outside: int = 0
		for id: StringName in PlantCatalog.ids():
			if not pool.has(id):
				outside += 1
		err = _T.assert_gt(outside, 0,
			"and at least one plant is outside it, so the equality below has two sides")
	if err == "":
		rare.mouse_entered.emit()
		await _pump(game)
		for id: StringName in PlantCatalog.ids():
			var button: Button = game.hud.get_node_or_null(
				"Root/SidePanel/PlantBar/Button_%s" % String(id)) as Button
			err = _T.assert_true(button != null, "%s has a button in the plant bar" % id)
			if err == "":
				var lit: bool = button.modulate.is_equal_approx(Hud.PACKET_HINT_TINT)
				err = _T.assert_eq(lit, pool.has(id),
					("%s reads lit=%s while the rare packet's pool says %s — the cue has "
						+ "to BE the pool, not agree with it by luck") % [id, lit, pool.has(id)])
			if err != "":
				break
	if err == "":
		# A seed earned while the cursor rests on the packet must not put the bar
		# back to grey. refresh() rewrites every plant button's modulate, so this is
		# the failure this cue would have by default and _apply_plant_hints exists
		# to prevent.
		game.bank.add_seeds(3)
		await _pump(game)
		var lit_one: Button = game.hud.get_node_or_null(
			"Root/SidePanel/PlantBar/Button_%s" % String(pool[0])) as Button
		err = _T.assert_true(lit_one.modulate.is_equal_approx(Hud.PACKET_HINT_TINT),
			"%s is still lit after a refresh landed under the hover" % pool[0])
	if err == "":
		rare.mouse_exited.emit()
		await _pump(game)
		var still_lit: int = 0
		for id: StringName in PlantCatalog.ids():
			var button: Button = game.hud.get_node_or_null(
				"Root/SidePanel/PlantBar/Button_%s" % String(id)) as Button
			if button != null and button.modulate.is_equal_approx(Hud.PACKET_HINT_TINT):
				still_lit += 1
		err = _T.assert_eq(still_lit, 0, "and the bar goes back to rest when the cursor leaves")
	if err == "":
		# The second surface: the locked plant's own tooltip names the packet, and
		# names it by reading PACKET_TIERS at draw time.
		var id: StringName = pool[0]
		var tier: StringName = game.bank.cheapest_packet_for(id)
		var display: String = String((SeedBank.PACKET_TIERS[tier] as Dictionary)["display"])
		var button: Button = game.hud.get_node_or_null(
			"Root/SidePanel/PlantBar/Button_%s" % String(id)) as Button
		err = _T.assert_true(button.tooltip_text.contains(display),
			("a locked plant's tooltip names the packet that can unlock it (%s), got: %s")
				% [display, button.tooltip_text])
		if err == "":
			var free_id: StringName = game.bank.unlocked[0]
			var free_button: Button = game.hud.get_node_or_null(
				"Root/SidePanel/PlantBar/Button_%s" % String(free_id)) as Button
			err = _T.assert_false(free_button.tooltip_text.contains("Still in a packet"),
				"while a plant already in the garden is not still in a packet")
	_T.free_ui(game)
	return err


## The wave button wears the shared paper look, and still wears no Theme.
##
## Both halves together or neither is worth asserting. `test_the_hud_still_
## refuses_the_shared_theme` says the HUD takes no Theme, and the easiest way to
## satisfy that forever is for the top bar's one Button to stay a grey slab; the
## easiest way to style it is to hand the HUD the Theme and break the layout it
## sizes in code. This pins the third answer: per-node overrides, no Theme.
func test_the_wave_button_wears_the_paper_look_without_a_theme() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	await _pump(game)
	var button: Button = game.hud.get_node_or_null("Root/TopBar/StatsRow/NextWaveButton") as Button
	var err: String = _T.assert_true(button != null, "the wave button is in the row")
	if err == "":
		err = _T.assert_true(button.theme == null,
			"and carries no Theme -- the look arrives as overrides")
	if err == "":
		var box := button.get_theme_stylebox("normal") as StyleBoxFlat
		err = _T.assert_true(box != null, "its normal state is a flat box, not Godot's default")
		if err == "":
			err = _T.assert_true(box.bg_color.is_equal_approx(GardenTheme.PAPER),
				"filled with the notebook's paper, got %s" % box.bg_color)
		if err == "":
			err = _T.assert_true(box.border_color.is_equal_approx(GardenTheme.INK),
				"and outlined in its ink, got %s" % box.border_color)
	if err == "":
		err = _T.assert_true(button.get_theme_color("font_color").is_equal_approx(GardenTheme.INK),
			"ink text on paper, got %s" % button.get_theme_color("font_color"))
	if err == "":
		# The look is shared rather than a second copy of it: the Theme the HUD
		# declines paints its Buttons the same way this one Button is painted.
		var shared := GardenTheme.build().get_stylebox("normal", "Button") as StyleBoxFlat
		err = _T.assert_true(shared.bg_color.is_equal_approx(
				(button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color),
			"and it is the SAME look the shared Theme would have applied, not a lookalike")
	_T.free_ui(game)
	if err != "":
		return err
	# The helper itself, off any tree: its documented contract is that it sets no
	# size, which is what lets a budgeted layout wear the look safely. A stylebox
	# added here that carried a min_size would be invisible in the HUD assertions
	# above, because the button's custom_minimum_size is larger than it today.
	var bare := Button.new()
	bare.text = "Grow the next wave"
	GardenTheme.style_paper_button(bare)
	err = _T.assert_true(bare.custom_minimum_size.is_equal_approx(Vector2.ZERO),
		"styling a Button sets no size of its own, got %s" % bare.custom_minimum_size)
	if err == "":
		# has_theme_stylebox_override is the half that says "override, not Theme" --
		# get_theme_stylebox alone would answer just as happily off the default theme.
		err = _T.assert_true(bare.has_theme_stylebox_override("normal"),
			"and it applies the box as a per-node override rather than a Theme")
		if err == "":
			var applied := bare.get_theme_stylebox("normal") as StyleBoxFlat
			err = _T.assert_true(applied != null and applied.bg_color.is_equal_approx(GardenTheme.PAPER),
				"which is the notebook's paper")
	if err == "":
		err = _T.assert_eq(bare.get_theme_font_size("font_size"), GardenTheme.BUTTON_FONT_SIZE,
			"at the one Button font size the shared look declares")
	bare.free()
	return err


## The styling did not spend the row's width budget.
##
## A stylebox carries content margins, and a Button's minimum size is its text
## plus those margins. If that sum ever passes NEXT_WAVE_BUTTON_SIZE.x the button
## stops being the budgeted 216px the stats-row arithmetic assumes and starts
## growing, which the HBoxContainer pays for by pushing -- the exact failure
## `test_an_absurdly_long_readout_pushes_rather_than_underlaps` exists for, and
## one that no screenshot of today's text would show.
func test_the_wave_buttons_text_fits_its_budgeted_slot() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	await _pump(game)
	var button: Button = game.hud.get_node_or_null("Root/TopBar/StatsRow/NextWaveButton") as Button
	var err: String = _T.assert_true(button != null, "the wave button is in the row")
	if err != "":
		_T.free_ui(game)
		return err
	var font: Font = button.get_theme_font("font")
	var size_px: int = button.get_theme_font_size("font_size")
	if size_px <= 0:
		size_px = button.get_theme_default_font_size()
	err = _T.assert_true(font != null and size_px > 0,
		"the button resolves a font to be measured in (%d px)" % size_px)
	if err == "":
		var box := button.get_theme_stylebox("normal") as StyleBoxFlat
		var text_px: float = font.get_string_size(
			button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		var needed: float = text_px + box.content_margin_left + box.content_margin_right
		err = _T.assert_true(needed <= Hud.NEXT_WAVE_BUTTON_SIZE.x,
			"\"%s\" plus the paper box's margins needs %.0fpx of its %.0fpx slot"
				% [button.text, needed, Hud.NEXT_WAVE_BUTTON_SIZE.x])
	if err == "":
		err = _T.assert_float_eq(button.size.x, Hud.NEXT_WAVE_BUTTON_SIZE.x, 0.5,
			"and the live button is still exactly its budgeted width (%.0f)" % button.size.x)
	if err == "":
		# Read off the live row rather than a literal, so this keeps measuring the
		# real sum when a later feature adds a control to the bar.
		var stats: HBoxContainer = game.hud.get_node_or_null("Root/TopBar/StatsRow") as HBoxContainer
		var needed: float = Hud.stats_row_budget(stats.get_child_count() - 1)
		err = _T.assert_true(needed <= stats.size.x,
			"so the row's sum still fits the bar: %.0f of %.0fpx, %.0fpx spare"
				% [needed, stats.size.x, stats.size.x - needed])
	_T.free_ui(game)
	return err


## Every colour the top bar writes in clears the palette's own legibility floor
## against the bar's ink -- on BOTH threat ramps.
##
## The colourblind ramp is the half that needs a check rather than an eye: it is
## a second set of paints nobody looks at unless they have the setting on, and
## `threat_color_on(level, true)` lands SAFE_MID and SAFE_BAD on the readout that
## a player watches hardest. Reusing `GardenTheme.reads_on` rather than comparing
## luminances here is deliberate -- one floor, written down once, so the bar and
## the playfield cannot end up disagreeing about what "readable" means.
##
## The negative control at the end is what makes the rest of it worth anything:
## INK_SOFT is a real colour from this same palette that the floor rejects, so a
## floor accidentally lowered to zero fails here instead of passing everything.
func test_every_colour_the_top_bar_writes_in_reads_on_the_bar() -> String:
	var writes: Dictionary = {
		"the readouts": Hud.PAPER,
		"the compost readout": Hud.COMPOST,
		"the message line": Hud.LEAF,
		"the page rules": Hud.PAGE_RULE,
		"the wave button's text on its paper": Hud.INK,
	}
	var faint: PackedStringArray = []
	for what: String in writes:
		var mark: Color = writes[what]
		# The button's ink is the one mark NOT on the ink band -- it is on the
		# paper box, so it is measured against the ground it is actually drawn on.
		var ground: Color = GardenTheme.PAPER if mark.is_equal_approx(Hud.INK) else Hud.INK
		if not GardenTheme.reads_on(mark, ground):
			faint.append("%s: %.3f apart" % [what, GardenTheme.separation(mark, ground)])
	# Both ramps, over the whole range the readout can reach, including past the
	# saturation point where an endless run parks.
	for safe: bool in [false, true]:
		for level: int in range(1, Hud.THREAT_TINT_MAX * 2):
			var tint: Color = Hud.threat_color_on(level, safe)
			if not GardenTheme.reads_on(tint, Hud.INK):
				faint.append("threat level %d on the %s ramp: %.3f apart"
					% [level, "safe" if safe else "default",
						GardenTheme.separation(tint, Hud.INK)])
	var err: String = _T.assert_eq(faint.size(), 0,
		"marks on the top bar that do not clear %.2f against its ink: %s"
			% [GardenTheme.GROUND_SEPARATION_MIN, ", ".join(faint)])
	if err == "":
		# The floor can say no. Without this the sweep above would read exactly
		# the same with GROUND_SEPARATION_MIN set to 0.
		err = _T.assert_false(GardenTheme.reads_on(GardenTheme.INK_SOFT, Hud.INK),
			"and the floor still rejects INK_SOFT (%.3f apart), so it is a floor rather than a formality"
				% GardenTheme.separation(GardenTheme.INK_SOFT, Hud.INK))
	return err


## The mapping itself, with no HUD: which packet unlocks which plant is DERIVED
## from packet_pool() in both directions, so a plant added to PlantCatalog joins
## the cue without anyone editing it.
##
## Direction one: every packet the cue names really does hold the plant it was
## named for, and it is the cheapest one that does. Direction two: the set of
## plants the cue speaks for EQUALS the union of every pool — a plant reachable by
## some packet and pointed at by none is the silent half this repo has paid for
## before (see .claude/skills/derive-the-list/SKILL.md).
func test_the_packet_a_locked_plant_points_at_is_derived_from_the_pools() -> String:
	var bank := SeedBank.new()
	var locked: Array[StringName] = bank.locked_plants()
	var err: String = _T.assert_gt(locked.size(), 3,
		"the catalogue has locked plants to point at (an empty sweep is a vacuous pass)")
	var named: Array[StringName] = []
	if err == "":
		for id: StringName in locked:
			var tier: StringName = bank.cheapest_packet_for(id)
			err = _T.assert_true(tier != &"", "%s is locked, so some packet must hold it" % id)
			if err == "":
				err = _T.assert_true(bank.packet_pool(tier).has(id),
					"and %s really is in a %s packet's pool" % [id, tier])
			if err == "":
				var mine: int = int((SeedBank.PACKET_TIERS[tier] as Dictionary)["cost"])
				for other: StringName in SeedBank.PACKET_ORDER:
					if not bank.packet_pool(other).has(id):
						continue
					err = _T.assert_gte(int((SeedBank.PACKET_TIERS[other] as Dictionary)["cost"]), mine,
						("and it is the CHEAPEST packet that holds %s — %s also holds it and "
							+ "costs less than the %s the cue names") % [id, other, tier])
					if err != "":
						break
			if err != "":
				break
			named.append(id)
	if err == "":
		var reachable: Array[StringName] = []
		for tier: StringName in SeedBank.PACKET_ORDER:
			for id: StringName in bank.packet_pool(tier):
				if not reachable.has(id):
					reachable.append(id)
		reachable.sort()
		named.sort()
		err = _T.assert_eq(named, reachable,
			("every plant some packet can hand over is pointed at by the cue, and nothing "
				+ "else is: cue %s vs pools %s") % [named, reachable])
	if err == "":
		for id: StringName in bank.unlocked:
			err = _T.assert_eq(bank.cheapest_packet_for(id), &"",
				"%s is already growing, so no packet is the one to buy for it" % id)
			if err != "":
				break
	if err == "":
		# And it moves. Unlocking the last tier-1 plant empties the common pool, so
		# the cue for that plant stops naming any packet at all — the property that
		# makes this derived rather than a table that happens to be right today.
		var was: StringName = bank.cheapest_packet_for(PlantCatalog.CHOMP)
		err = _T.assert_true(was != &"", "the Chomp starts locked and points somewhere")
		if err == "":
			bank.unlocked.append(PlantCatalog.CHOMP)
			err = _T.assert_eq(bank.cheapest_packet_for(PlantCatalog.CHOMP), &"",
				"and once it is unlocked the cue drops it without anyone editing a list")
	return err


# -- the garden speed toggle (plant-tower-defense-03t6) -----------------------
#
# `Engine.time_scale` is PROCESS-GLOBAL and outlives every node in this file, so
# each of these puts it back with `GameSpeed.reset()` on the way out, on the
# passing path and the failing one. A test that leaves the clock moved does not
# fail — it hands every test after it a different game, and the one that breaks is
# whichever happens to run next.


## The whole cycle, asserted against the ENGINE at every step rather than against
## GameSpeed's own idea of where it is.
##
## The defect this rules out is the one a speed toggle actually ships with: an
## index that advances, a label that changes, and nothing written to
## `Engine.time_scale` — a button that looks like it works from every angle except
## the garden's.
func test_the_speed_toggle_walks_its_table_and_lands_on_the_engine() -> String:
	GameSpeed.reset()
	var err: String = _T.assert_gt(GameSpeed.STEPS.size(), 1,
		"there is more than one speed to cycle between — a one-entry table is a toggle that does nothing")
	if err == "":
		err = _T.assert_eq(GameSpeed.LABELS.size(), GameSpeed.STEPS.size(),
			"every step has a label, so no press can leave the button blank")
	if err == "":
		err = _T.assert_float_eq(GameSpeed.STEPS[0], GameSpeed.NORMAL, 0.0001,
			"step 0 is NORMAL, which is what reset() relies on")
	if err == "":
		err = _T.assert_float_eq(Engine.time_scale, GameSpeed.NORMAL, 0.0001,
			"and a reset run is running at it")
	if err == "":
		for press: int in range(1, GameSpeed.STEPS.size() + 1):
			var expected: float = GameSpeed.STEPS[press % GameSpeed.STEPS.size()]
			var reported: float = GameSpeed.cycle()
			err = _T.assert_float_eq(reported, expected, 0.0001,
				"press %d reports %.2fx" % [press, expected])
			if err == "":
				err = _T.assert_float_eq(Engine.time_scale, expected, 0.0001,
					"and the engine is actually running at %.2fx after press %d" % [expected, press])
			if err != "":
				break
	if err == "":
		err = _T.assert_eq(GameSpeed.step(), 0,
			"and %d presses close the cycle back on 1x" % GameSpeed.STEPS.size())
	GameSpeed.reset()
	return err


## The bead is two asks in one control — the designer's handwritten "faster
## button" and the backlog's slow mode — and a table holding only one of them
## would pass every other test in this section.
func test_the_speed_table_goes_both_faster_and_slower_than_normal() -> String:
	GameSpeed.reset()
	var fastest: float = GameSpeed.NORMAL
	var slowest: float = GameSpeed.NORMAL
	var err: String = ""
	# Every step is APPLIED, not merely read off the table, so a value the engine
	# would refuse (or a `set_step` that lost the index) fails here rather than in
	# whichever direction the player happens to press first.
	for index: int in GameSpeed.STEPS.size():
		var landed: float = GameSpeed.set_step(index)
		fastest = maxf(fastest, landed)
		slowest = minf(slowest, landed)
		err = _T.assert_float_eq(GameSpeed.engine_scale(), landed, 0.0001,
			"step %d puts the engine on %.2fx" % [index, landed])
		if err != "":
			break
	if err == "":
		err = _T.assert_gt(fastest, GameSpeed.NORMAL,
			"a step runs the garden FASTER than normal — the note said 'faster button'")
	if err == "":
		err = _T.assert_gt(GameSpeed.NORMAL, slowest,
			"and a step runs it slower — kanban.md's slow mode is the same control's other end")
	if err == "":
		# Below this the bridge's own `set-game-speed` refuses the value as a freeze
		# rather than a speed, and a freeze is what pause is for.
		err = _T.assert_gt(slowest, 0.01,
			"and the slow end is still a speed (%.2fx), not a freeze" % slowest)
	GameSpeed.reset()
	return err


## THE acceptance check the bead names: resuming from pause is at 1x — read from
## both ends, because "the card is at 1x" and "the player's choice survived" are
## two different failures and fixing either one alone is easy.
##
## Why it matters: `PauseScreen` is PROCESS_MODE_ALWAYS so its fades run while the
## tree is held, and `Engine.time_scale` scales a Tween whether or not the tree is
## paused. A run held at 2x therefore dissolves its own pause card in half the time
## the card was tuned for, and nothing anywhere reports it.
func test_a_paused_run_reads_at_1x_and_comes_back_at_the_speed_it_was_held_at() -> String:
	GameSpeed.reset()
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var chosen: float = game.cycle_speed()
	var err: String = _T.assert_true(not is_equal_approx(chosen, GameSpeed.NORMAL),
		"one press leaves 1x, so this test is about something (it landed on %.2fx)" % chosen)
	if err == "":
		err = _T.assert_float_eq(Engine.time_scale, chosen, 0.0001,
			"and the live run is running at it")
	game.pause_run()
	await _pump(game)
	if err == "":
		err = _T.assert_true(game.is_paused(), "the run is held")
	if err == "":
		# `engine_scale()` and not `scale()`: the two disagree on purpose exactly
		# here, and asking the wrong one is how this assertion passes green over a
		# card being dissolved at double speed.
		err = _T.assert_float_eq(GameSpeed.engine_scale(), GameSpeed.NORMAL, 0.0001,
			"THE PAUSE CARD READS AT 1x while it is up")
	if err == "":
		err = _T.assert_true(GameSpeed.is_held(),
			"and the player's choice is parked rather than thrown away")
	if err == "":
		# The HUD is stateless and renders what state() hands it, so this is the
		# button's face: it must keep saying what the player picked rather than
		# flicking to 1x behind a card that is covering it.
		err = _T.assert_float_eq(float(game.state()["game_speed"]), chosen, 0.0001,
			"so the speed readout still reports the player's choice, not the engine's hold")
	await game.resume_run()
	if err == "":
		err = _T.assert_false(game.is_paused(), "resuming lets the garden go")
	if err == "":
		err = _T.assert_float_eq(Engine.time_scale, chosen, 0.0001,
			"at the speed it was held at (%.2fx), not back at 1x" % chosen)
	if err == "":
		err = _T.assert_false(GameSpeed.is_held(), "and nothing is left parked")
	# Both of these are process-global. Unconditional, and before the return.
	if game.is_paused():
		game.get_tree().paused = false
	_T.free_ui(game)
	GameSpeed.reset()
	return err


## Leaving a run puts the clock back — the half of the lifetime that has no screen
## to show it.
##
## `Engine.time_scale` is not part of the scene: a reload, a return to the title or
## the window closing all leave it exactly where the run left it. A title screen
## running at 2x is a defect nobody would look for in the title screen's code, and
## `Game._exit_tree` is the single caller that covers every one of those exits.
func test_leaving_a_run_puts_the_engine_clock_back() -> String:
	GameSpeed.reset()
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var chosen: float = game.cycle_speed()
	var err: String = _T.assert_true(not is_equal_approx(Engine.time_scale, GameSpeed.NORMAL),
		"the run really is off 1x before it is torn down (%.2fx)" % chosen)
	# Not `GameSpeed.reset()` and then a check -- the point is that FREEING THE GAME
	# does it, which is the path a scene change actually takes.
	_T.free_ui(game)
	if err == "":
		err = _T.assert_float_eq(Engine.time_scale, GameSpeed.NORMAL, 0.0001,
			"freeing the run put the engine clock back to 1x on its own")
	if err == "":
		err = _T.assert_eq(GameSpeed.step(), 0, "and the next run starts at step 0")
	GameSpeed.reset()
	return err


## A run that ends stops being fast. The post-mortem card animates on the same
## clock the pause card is protected from, and a restart from that screen must
## begin at 1x rather than inheriting the last run's tempo.
func test_a_run_that_ends_drops_back_to_1x() -> String:
	GameSpeed.reset()
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var chosen: float = game.cycle_speed()
	var err: String = _T.assert_true(not is_equal_approx(chosen, GameSpeed.NORMAL),
		"the run is off 1x before it ends (%.2fx)" % chosen)
	game._end_run("test")
	await _pump(game)
	if err == "":
		err = _T.assert_float_eq(Engine.time_scale, GameSpeed.NORMAL, 0.0001,
			"the post-mortem card is drawn at 1x")
	if err == "":
		err = _T.assert_false(GameSpeed.is_held(),
			"and it is a reset, not a hold — there is no run left to come back to")
	_T.free_ui(game)
	GameSpeed.reset()
	return err


## Cycling while held moves the parked choice and leaves the engine alone.
##
## In the running game this branch is unreachable: `Game` is PROCESS_MODE_INHERIT,
## a paused node receives no input, and `_unhandled_input` therefore cannot fire
## behind the card. That is precisely why it is pinned — it is a fact about where
## the node sits today, and reparenting the HUD button onto an ALWAYS layer, or
## giving the pause card its own speed control, makes it reachable with nothing
## anywhere reporting the change.
func test_cycling_behind_the_pause_card_cannot_speed_the_card_up() -> String:
	GameSpeed.reset()
	GameSpeed.hold()
	var err: String = _T.assert_true(GameSpeed.is_held(), "the run is held")
	var moved: float = GameSpeed.cycle()
	if err == "":
		err = _T.assert_true(not is_equal_approx(moved, GameSpeed.NORMAL),
			"the parked choice moved (%.2fx)" % moved)
	if err == "":
		err = _T.assert_float_eq(Engine.time_scale, GameSpeed.NORMAL, 0.0001,
			"and the engine stayed at 1x while the card is up")
	GameSpeed.release()
	if err == "":
		err = _T.assert_float_eq(Engine.time_scale, moved, 0.0001,
			"releasing hands the engine the choice made behind the card")
	# hold() is idempotent, because the Options and Keys screens open OVER the pause
	# card and a second hold must not park NORMAL as if it were the player's pick.
	if err == "":
		GameSpeed.hold()
		GameSpeed.hold()
		GameSpeed.release()
		err = _T.assert_float_eq(Engine.time_scale, moved, 0.0001,
			"and holding twice still releases to %.2fx, not to 1x" % moved)
	GameSpeed.reset()
	return err


## The verb is reachable and is written down in both places a player looks. The
## Keys screen builds one row per declared action, so the row exists by
## construction — what is not free is that it is DRAWN, with the key it is really
## bound to.
func test_the_speed_verb_is_bound_and_listed_where_a_player_can_find_it() -> String:
	var err: String = _T.assert_true(KeyBindings.is_known(KeyBindings.ACTION_SPEED),
		"the speed verb is a declared action rather than a loose keycode")
	if err == "":
		err = _T.assert_true(
			KeyBindings.actions_in(KeyBindings.SCOPE_RUN).has(KeyBindings.ACTION_SPEED),
			"in the run scope, which is the list the pause card draws")
	if err == "":
		err = _T.assert_false(KeyBindings.keys_for(KeyBindings.ACTION_SPEED).is_empty(),
			"and it answers to a key out of the box")
	if err == "":
		var named: bool = false
		for row: Dictionary in Game.key_help():
			if StringName(row["action"]) == KeyBindings.ACTION_SPEED:
				named = true
				err = _T.assert_false(String(row["does"]).strip_edges().is_empty(),
					"the pause card's row says what it does")
				break
		if err == "":
			err = _T.assert_true(named, "the pause card's legend carries a row for it")
	var index: int = KeyBindings.actions().find(KeyBindings.ACTION_SPEED)
	if err == "":
		err = _T.assert_gte(index, 0, "the action is in the binding table")
	var screen := await _T.instantiate_ui(KeyBindingScreen.new(), Vector2i(1152, 648)) as KeyBindingScreen
	if err == "":
		var key_cell := screen.get_node_or_null("RowKey%d" % index) as Label
		err = _T.assert_true(key_cell != null,
			"the Keys screen drew a key cell for row %d" % index)
		if err == "":
			err = _T.assert_eq(key_cell.text, KeyBindings.label_for(KeyBindings.ACTION_SPEED),
				"showing the key it is actually bound to")
	if err == "":
		var does_cell := screen.get_node_or_null("Row%d" % index) as Label
		err = _T.assert_true(does_cell != null and not does_cell.text.is_empty(),
			"beside a phrase saying what the row does")
	_T.free_ui(screen)
	return err


## The Keys panel grew for the ninth verb, and it grew DERIVED — so this asks the
## one question the derivation cannot answer for itself: does the paper still fit
## on the screen?
##
## `KeyBindingScreen.panel_height()` returns exactly the viewport height minus its
## top inset at nine rows. A tenth verb pushes the foot of the paper off the bottom
## of the window, and nothing clamps it on purpose — this assertion is the thing
## that says so, on the day it happens, instead of a screenshot nobody takes.
func test_the_keys_panel_holds_every_verb_and_stays_on_the_screen() -> String:
	var screen := await _T.instantiate_ui(KeyBindingScreen.new(), Vector2i(1152, 648)) as KeyBindingScreen
	var viewport_height: float = float(
		ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	var panel: Rect2 = screen.panel_rect()
	var err: String = _T.assert_gt(KeyBindings.actions().size(), 0,
		"there are rows to fit — an empty table would pass everything below it")
	if err == "":
		err = _T.assert_gte(viewport_height, panel.end.y,
			("the %d-row paper foots at %.0f inside a %.0f-tall viewport — grow the row "
				+ "pitch or the header block, not panel_height()")
				% [KeyBindings.actions().size(), panel.end.y, viewport_height])
	if err == "":
		err = _T.assert_gte(screen.footer_clearance(), OverlayScreen.FOOTER_GAP,
			"and the footer stands %.0fpx clear of the last row" % screen.footer_clearance())
	if err == "":
		err = _T.assert_gte(panel.size.y, KeyBindingScreen.PANEL_MIN_HEIGHT,
			"the shipped height is a floor, so nothing shrank under it")
	if err == "":
		# The instance's paper and the static derivation are the same number. They
		# have to be asked separately: `panel_rect()` is what gets drawn and
		# `panel_height()` is what every other overlay measurement is derived from,
		# and a screen whose paper stopped reading its own derivation would look
		# right in exactly one of them.
		err = _T.assert_float_eq(panel.size.y, KeyBindingScreen.panel_height(), 0.0001,
			"and the drawn paper is the derived height, not a second copy of it")
	_T.free_ui(screen)
	return err


## The square button the top bar has to fund is wide enough for every face it can
## show — measured in the real theme font, not guessed at.
##
## A Button clips its label silently, and the failure is invisible in a screenshot
## at the one size that matters: "½x" clipped to "½" still reads as a speed.
func test_the_speed_button_is_wide_enough_for_every_label_it_can_show() -> String:
	var width: float = GameSpeed.button_min_width()
	var err: String = _T.assert_gt(GameSpeed.LABELS.size(), 0, "there are labels to measure")
	if err == "":
		err = _T.assert_gte(width, GameSpeed.BUTTON_MIN_SIDE,
			("it clears the %.0fpx interactive floor `findings` gates on")
				% GameSpeed.BUTTON_MIN_SIDE)
	if err == "":
		for text: String in GameSpeed.LABELS:
			var drawn: float = GardenTheme.measure(text, GameSpeed.BUTTON_FONT_SIZE)
			err = _T.assert_gte(width, drawn + GameSpeed.BUTTON_PADDING * 2.0,
				"\"%s\" draws at %.0fpx and fits the %.0fpx button with its padding"
					% [text, drawn, width])
			if err != "":
				break
	if err == "":
		err = _T.assert_float_eq(GameSpeed.button_size().y, GameSpeed.BUTTON_MIN_SIDE, 0.0001,
			"and the button is at least as tall as it is required to be")
	return err


## The button exists, is wired, and says what the state says.
##
## THIS IS THE ROW THAT STAYS RED UNTIL hud.gd GROWS THE BUTTON. The speed model,
## the keyboard verb and the Keys screen row all live in files the speed change
## owned; the top bar does not, so `Game._ready` connects `speed_requested` by name
## behind a `has_signal` guard rather than taking the whole project down with a
## parse error. A guard is only honest if something fails when it skips — this is
## that something, and `Game._ready` also push_error()s on the same branch.
##
## Delete nothing here when the button lands; it becomes the check that it stays.
func test_the_hud_carries_the_speed_button() -> String:
	GameSpeed.reset()
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game.hud.has_signal(Game.SPEED_SIGNAL),
		("Hud declares `signal %s` — without it the speed control is a keyboard verb "
			+ "with no visible door, which is what this row exists to refuse")
			% Game.SPEED_SIGNAL)
	if err == "":
		# Wired, not merely declared. A signal nobody connected is the same button
		# as no button, and `findings` cannot tell them apart either.
		err = _T.assert_gt(game.hud.get_signal_connection_list(Game.SPEED_SIGNAL).size(), 0,
			"and Game connected to it")
	if err == "":
		var button := game.hud.get_node_or_null("Root/TopBar/StatsRow/SpeedButton") as Button
		err = _T.assert_true(button != null,
			"the button is in the top bar's StatsRow at the contracted path")
		if err == "":
			err = _T.assert_eq(button.text, GameSpeed.label(),
				"showing the speed the run is actually on")
		if err == "":
			# The floor `findings` gates interactive Controls on, and the width
			# GameSpeed derives from its own longest label.
			err = _T.assert_gte(button.size.x, GameSpeed.button_min_width(),
				"wide enough for every face it can show (%.0f of %.0f)"
					% [button.size.x, GameSpeed.button_min_width()])
		if err == "":
			err = _T.assert_gte(button.size.y, GameSpeed.BUTTON_MIN_SIDE,
				"and tall enough to hit (%.0f)" % button.size.y)
		if err == "":
			# Pressing the real button, not calling the handler: a disconnected
			# button passes the second half of this test and fails the player.
			var before: float = GameSpeed.scale()
			button.pressed.emit()
			await _pump(game)
			err = _T.assert_true(not is_equal_approx(GameSpeed.scale(), before),
				"and pressing it actually moves the garden's speed (%.2fx -> %.2fx)"
					% [before, GameSpeed.scale()])
			if err == "":
				err = _T.assert_eq(button.text, GameSpeed.label(),
					"and the face follows the press without waiting for another refresh")
	_T.free_ui(game)
	GameSpeed.reset()
	return err


## The state dictionary carries the PLAYER's speed, its rendered face and its
## tooltip — the HUD keeps no second copy of any truth, so a button that has to
## derive its own label from `Engine.time_scale` would read 1x behind a pause card.
func test_the_run_state_carries_the_speed_the_hud_has_to_draw() -> String:
	GameSpeed.reset()
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var chosen: float = game.cycle_speed()
	var state: Dictionary = game.state()
	var err: String = _T.assert_true(state.has("game_speed"),
		"state() reports the speed")
	if err == "":
		err = _T.assert_float_eq(float(state["game_speed"]), chosen, 0.0001,
			"and it is the one the press landed on")
	if err == "":
		err = _T.assert_eq(String(state["game_speed_label"]), GameSpeed.label(),
			"beside the face the button draws")
	if err == "":
		err = _T.assert_eq(String(state["game_speed_tooltip"]), GameSpeed.button_tooltip(),
			"and the tooltip GameSpeed composes, not a second copy of it")
	if err == "":
		err = _T.assert_true(String(state["game_speed_tooltip"]).contains(GameSpeed.label()),
			"and a tooltip that names the speed it is on")
	if err == "":
		# The tooltip's job is to say what the NEXT press does; one that only named
		# the current speed would repeat the button's own face and teach nothing.
		err = _T.assert_true(
			String(state["game_speed_tooltip"]).contains(GameSpeed.label_for(GameSpeed.step() + 1)),
			"and what the next press will do (%s)" % GameSpeed.label_for(GameSpeed.step() + 1))
	_T.free_ui(game)
	GameSpeed.reset()
	return err


# -- The parent's merge: the three surfaces no lane could reach ---------------
#
# Each of these was NEW in `suite_reach_check` after the fan-out merged, and each
# is a public surface a lane introduced in a file it owned while the thing that
# exercises it lived in a file it did not. That is the shape the workflow warns
# about — "a lane that reports 'needs these lines in a parent-owned file' has not
# finished until the parent writes them" — and an unreached public surface is
# what it looks like when the parent writes the lines and stops there.
#
# Banking them into the reach baseline instead would have recorded three working
# features as accepted debt, in the same stroke that banked an unrelated fix.


## The HUD reports the speed press; it does not own the clock.
##
## `speed_requested` is the whole seam between the button and `GameSpeed`, and
## until this test it was declared, connected, and named by nothing — the exact
## dead-code shape the guard deleted from `game.gd` was written to shout about.
func test_the_speed_button_reports_the_press_and_owns_no_clock() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var button: Button = game.hud.get_node_or_null(
		"Root/TopBar/StatsRow/SpeedButton") as Button
	var err: String = _T.assert_true(button != null,
		"the top bar carries a speed button a player can press")
	var heard: Array[int] = []
	if err == "":
		game.hud.speed_requested.connect(func() -> void: heard.append(1))
		err = _T.assert_eq(GameSpeed.step(), 0, "a fresh garden runs at 1x")
	if err == "":
		button.pressed.emit()
		err = _T.assert_eq(heard.size(), 1,
			"pressing it emits speed_requested exactly once")
	if err == "":
		err = _T.assert_gt(GameSpeed.scale(), 1.0,
			"and Game answered by speeding the garden up, got %.2fx" % GameSpeed.scale())
	if err == "":
		# The button is a readout, not a second copy of the speed.
		game.hud.refresh(game.state())
		err = _T.assert_eq(button.text, GameSpeed.label(),
			"the button reads back what the engine actually holds")
	_T.free_ui(game)
	GameSpeed.reset()
	return err


## The locked-plant cue, asserted where it is decided rather than where it shows.
##
## `plant_button_tint` and `plant_button_tooltip` are pure and static, so this
## needs no tree — and the tint assertion is made in the case that can FAIL: a
## locked, unaffordable plant that is nonetheless hinted must come back lit,
## because `hinted` is the branch the hover added and the other two arguments are
## exactly the ones that would drown it out if the precedence were wrong.
func test_a_hinted_plant_lights_up_and_names_the_packet_that_holds_it() -> String:
	var err: String = _T.assert_eq(
		Hud.plant_button_tint(false, false, true), Hud.PACKET_HINT_TINT,
		"a hinted plant is lit even though it is locked AND unaffordable")
	if err == "":
		err = _T.assert_eq(Hud.plant_button_tint(false, false, false), Hud.PLANT_BUTTON_DIM,
			"the same plant unhinted is dim, so the hint is what moved it")
	if err == "":
		err = _T.assert_eq(Hud.plant_button_tint(true, true, false), Color.WHITE,
			"and an owned, affordable plant is at full strength")

	# The tooltip half. The Chomp starts locked, so a fresh bank answers with a
	# real tier rather than the empty one.
	var bank := SeedBank.new()
	var tier: StringName = bank.cheapest_packet_for(PlantCatalog.CHOMP)
	if err == "":
		err = _T.assert_true(tier != &"",
			"the Chomp starts locked, so some packet can hand it over")
	if err == "":
		var spec: Dictionary = SeedBank.PACKET_TIERS[tier] as Dictionary
		var tip: String = Hud.plant_button_tooltip(PlantCatalog.CHOMP, tier)
		err = _T.assert_true(tip.contains(String(spec["display"])),
			"the tooltip names that packet (%s), got: %s" % [spec["display"], tip])
		if err == "":
			err = _T.assert_true(tip.contains(str(int(spec["cost"]))),
				"and prices it, got: %s" % tip)
		if err == "":
			# The other side of the branch: an unlocked plant is told nothing about
			# packets, which is what makes the clause above carry information.
			var plain: String = Hud.plant_button_tooltip(PlantCatalog.CHOMP, &"")
			err = _T.assert_false(plain.contains("Still in a packet"),
				"while a plant already in the garden gets no packet clause, got: %s" % plain)
	return err


# -- Teaching that upgrading exists (plant-tower-defense-gz53) ----------------
#
# Cycle 101's A/B: same economy, no cheats, one policy bit. Breadth-first got
# eleven level-1 plants and died at wave 10; depth-first won 22 waves losing no
# lives. Upgrading decides the run and nothing said it existed.


## The pure half: which plant on the board is the cheapest to upgrade.
##
## `can_upgrade()` and not `has_upgrades()` is the assertion that matters, and the
## case is built so it can FAIL — the cheap plant is walked to the TOP of its ladder,
## so a `has_upgrades()` implementation still returns it (it has a ladder) while a
## `can_upgrade()` one steps over it. Asserting with every plant mid-ladder would
## pass either way, which is documentation wearing a test's clothes.
func test_the_cheapest_upgrade_skips_a_plant_with_no_rung_left() -> String:
	var cheap := CornCobbler.new()
	cheap.setup(PlantCatalog.CORN, Vector2i(0, 0), null)
	var dear := ChompFlower.new()
	dear.setup(PlantCatalog.CHOMP, Vector2i(1, 0), null)

	var err: String = _T.assert_true(cheap.can_upgrade() and dear.can_upgrade(),
		"both plants start with a rung left, or this case proves nothing")
	if err == "":
		var pick: Plant = Game.cheapest_upgrade([cheap, dear])
		var by_cost: Plant = cheap if cheap.upgrade_cost() <= dear.upgrade_cost() else dear
		err = _T.assert_eq(pick, by_cost,
			"the cheaper of the two is picked (corn %d, chomp %d)"
				% [cheap.upgrade_cost(), dear.upgrade_cost()])
	if err == "":
		# Walk the cheap one to the top. It still HAS a ladder; it can no longer
		# climb one, and that is exactly the difference under test.
		while cheap.can_upgrade():
			cheap.level += 1
		err = _T.assert_true(cheap.has_upgrades(),
			"a maxed plant still has a ladder, so has_upgrades() cannot tell them apart")
	if err == "":
		err = _T.assert_eq(Game.cheapest_upgrade([cheap, dear]), dear,
			"so the maxed plant is stepped over and the dearer one is named")
	if err == "":
		while dear.can_upgrade():
			dear.level += 1
		err = _T.assert_eq(Game.cheapest_upgrade([cheap, dear]), null,
			"and a board with nothing left to climb answers null, not a maxed plant")
	if err == "":
		err = _T.assert_eq(Game.cheapest_upgrade([]), null, "an empty board too")
	cheap.free()
	dear.free()
	return err


## The live half: the tip is spent on affordability, once, and never again.
##
## Every assertion below is made in a case where the mutation it guards would show.
## The first is at ONE SEED SHORT rather than at zero, because a `>` / `>=` slip and
## a missing check are different bugs and only the boundary separates them.
func test_the_upgrade_tip_waits_until_the_player_can_afford_it_and_fires_once() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game

	# ESTABLISHED, NOT ASSERTED, and that is the fix rather than the shortcut it looks
	# like. This line used to read `assert_false(has_milestone(...))` captioned "the
	# suite's scratch save starts without this hint spent" -- but RunConfig is an
	# autoload and there is no scratch save: it had loaded the developer's real
	# `user://highscore.save`. So the assertion was not checking the game, it was
	# checking whether whoever ran the suite had ever seen this hint while playing.
	# Cycle 110 drove the live game for an unrelated measurement, spent the hint, and
	# this test went red on a machine where nothing about the tip had changed.
	#
	# A milestone is one-shot and PERSISTENT by design, so any test about first-time
	# behaviour has to set the state it needs instead of hoping to inherit it. The
	# erase below is that setup, and it is the same call the busy-row case further down
	# already makes for the same reason.
	RunConfig.earned_milestones.erase(RunConfig.HINT_UPGRADE_EXISTS)
	var err: String = _T.assert_false(
		RunConfig.has_milestone(RunConfig.HINT_UPGRADE_EXISTS),
		("the hint reads unspent once cleared -- guards the erase against "
			+ "earned_milestones changing shape, which would otherwise make every "
			+ "assertion below vacuously true"))

	if err == "":
		game.bank.seeds = 500
		err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, Vector2i(3, 2)), "",
			"a cob goes down, so the board has something upgradable on it")

	var cob: Plant = null
	if err == "":
		cob = Game.cheapest_upgrade(game._plants.values())
		err = _T.assert_true(cob != null, "and cheapest_upgrade finds it")

	if err == "":
		# A BUSY ROW MEANS "NOT THIS REFRESH", and that is asserted before
		# affordability because placing the cob just posted a line — so this is the
		# state the game is really in at the moment the balance first crosses, not a
		# contrived one. Without Hud.row_is_quiet this refresh queues a copy of the
		# tip, the next one queues another, and the hint is never spent.
		RunConfig.earned_milestones.erase(RunConfig.HINT_UPGRADE_EXISTS)
		game.bank.seeds = 500
		err = _T.assert_false(game.hud.row_is_quiet(),
			"placing a plant leaves the row busy, which is the case that stacked copies")
	if err == "":
		game._refresh()
		game._refresh()
		game._refresh()
		err = _T.assert_false(
			RunConfig.has_milestone(RunConfig.HINT_UPGRADE_EXISTS),
			"three refreshes over a busy row spend nothing")
	if err == "":
		err = _T.assert_eq(game.hud._message_queue.size(), 0,
			"and queue NOTHING — the defect this guard exists for was three stacked copies")

	if err == "":
		# Now a quiet moment. ONE SEED SHORT: a check written `>` instead of `>=`, or
		# omitted entirely, differs from a correct one only at the boundary.
		game.hud._message_left = 0.0
		game.hud._message_queue.clear()
		game.bank.seeds = cob.upgrade_cost() - 1
		game._refresh()
		err = _T.assert_false(
			RunConfig.has_milestone(RunConfig.HINT_UPGRADE_EXISTS),
			"one seed short of the cheapest upgrade, the tip still has not fired")

	if err == "":
		game.hud._message_left = 0.0
		game.hud._message_queue.clear()
		game.bank.seeds = cob.upgrade_cost()
		game._refresh()
		err = _T.assert_true(
			RunConfig.has_milestone(RunConfig.HINT_UPGRADE_EXISTS),
			"exactly affording it, on a quiet row, is enough — actionable at the boundary")

	if err == "":
		# One-shot: still affordable, still upgradable, row made quiet again. Every
		# condition that fired it is true, so only the milestone guard is stopping a
		# second post — which is the mutation this kills.
		game.hud._message_left = 0.0
		game.hud._message_queue.clear()
		game._refresh()
		game._refresh()
		err = _T.assert_eq(game.hud._message_queue.size(), 0,
			"a spent hint posts nothing on a quiet row")
		err = _T.assert_true(
			RunConfig.has_milestone(RunConfig.HINT_UPGRADE_EXISTS),
			"and it stays spent across later refreshes")

	if err == "":
		var tip: String = Hud.upgrade_tip("Corn Cobbler", 25)
		err = _T.assert_true(tip.contains("Corn Cobbler") and tip.contains("25"),
			"the tip names the plant and prices it, got: %s" % tip)
	if err == "":
		err = _T.assert_true(Hud.message_corpus().any(
			func(line: String) -> bool: return line.contains("can be upgraded")),
			"and the row's width budget prices it, so it cannot overflow unmeasured")

	_T.free_ui(game)
	RunConfig.earned_milestones.erase(RunConfig.HINT_UPGRADE_EXISTS)
	return err


# -- Where the run's seeds went (plant-tower-defense-bou9) -------------------
#
# Cycle 101 measured the one bit that decides a campaign: two runs, same economy,
# same map, no cheats, differing only in whether a surplus bought another plant or
# another level on one already in the ground. Breadth-first reached eleven level-1
# plants and died at wave 10; depth-first won all 22 waves and lost no lives.
#
# The game recorded neither half of that. `seeds_earned_total` is income; nothing
# counted outgoings, so the post-mortem could report everything about a run except
# the decision the run turned on. These three tests cover the two halves of the
# fix — the counters being incremented at the moment seeds actually change hands,
# and the card stating them without grading the player for them.


## The counters are read off the RUN, at the two lines that charge for a purchase.
##
## The mutation this is really aimed at is an increment placed ABOVE the refusals
## in `Game.upgrade_selected` rather than below `bank.add_seeds(-price)`. That
## version passes any test that only ever upgrades successfully, and it credits a
## broke player with depth for every denied click — which is precisely the
## breadth-first player this row exists to describe, and precisely the direction
## that would make the row lie in their favour.
##
## The free starter is the other trap: `SeedBank.pay_for_plant` clears
## `free_starter_available` on its way through, so a price read after the charge
## bills the one free cob at full cost. Asserted here at 0 rather than assumed.
func test_a_placement_and_an_upgrade_each_land_on_the_run_s_own_spend() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_eq(game.seeds_on_plants, 0, "a fresh run has spent nothing on plants")
	if err == "":
		err = _T.assert_eq(game.seeds_on_upgrades, 0, "and nothing on upgrades")

	# The free starter, priced by the bank rather than by this test.
	var first: Vector2i = _grass(game)
	var free_price: int = game.bank.placement_cost(PlantCatalog.CORN)
	if err == "":
		err = _T.assert_eq(free_price, 0, "the first cob really is the free starter")
	if err == "":
		err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, first), "", "the free cob goes in")
	if err == "":
		err = _T.assert_eq(game.seeds_on_plants, 0,
			"and adds nothing to the spend — a run that planted only its free cob spent nothing")

	# A second cob, which is not free.
	var second: Vector2i = _grass(game)
	var paid_price: int = 0
	if err == "":
		err = _T.assert_true(second != first and second.x >= 0, "a second buildable cell exists")
	if err == "":
		game.bank.seeds = 500
		paid_price = game.bank.placement_cost(PlantCatalog.CORN)
		err = _T.assert_gt(paid_price, 0, "the second cob costs something")
	if err == "":
		err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, second), "", "the paid cob goes in")
	if err == "":
		err = _T.assert_eq(game.seeds_on_plants, paid_price,
			"exactly what the bank charged lands on the run's breadth spend")

	# A REFUSED upgrade must move nothing. This is the assertion that fails on an
	# increment written above the denial.
	var corn: CornCobbler = null
	if err == "":
		corn = game.plant_at(second) as CornCobbler
		err = _T.assert_true(corn != null, "the cob is a Corn Cobbler with a ladder to climb")
	if err == "":
		game._select(corn)
		game.bank.seeds = 0
		err = _T.assert_eq(game.upgrade_selected(), "not enough seeds", "the upgrade is refused")
	if err == "":
		err = _T.assert_eq(game.seeds_on_upgrades, 0,
			"a refused upgrade banks no depth — the click bought nothing")

	# And a real one moves exactly its price.
	var level_price: int = 0
	if err == "":
		level_price = corn.upgrade_cost()
		game.bank.seeds = level_price
		err = _T.assert_gt(level_price, 0, "the next level costs something")
	if err == "":
		err = _T.assert_eq(game.upgrade_selected(), "", "the upgrade goes through")
	if err == "":
		err = _T.assert_eq(game.seeds_on_upgrades, level_price,
			"and exactly its price lands on the run's depth spend")
	if err == "":
		err = _T.assert_eq(game.seeds_on_plants, paid_price,
			"while the breadth total is untouched — the two sinks do not leak into each other")

	# The card reads the run, not a price table. Both keys, on every run.
	if err == "":
		var stats: Dictionary = game.summary_stats(false)
		err = _T.assert_true(stats.has("seeds_on_plants") and stats.has("seeds_on_upgrades"),
			"summary_stats carries both halves of the policy")
		if err == "":
			err = _T.assert_eq(int(stats["seeds_on_plants"]), paid_price, "breadth carried through")
		if err == "":
			err = _T.assert_eq(int(stats["seeds_on_upgrades"]), level_price, "depth carried through")

	_T.free_ui(game)
	RunConfig.earned_milestones.erase(RunConfig.HINT_UPGRADE_EXISTS)
	return err


## The card states the policy, in numbers, and grades nobody for it.
##
## Two things are pinned that a later edit would plausibly undo. The card is still
## SEVEN rows — the new subject is a swap for "Threat reached", not an eighth row,
## because rows_capacity() is 7 and an eighth foots at 486 against buttons at 476.
## And the threat number is not lost by the swap: it moved onto the waves row,
## which is honest because `Game.summary_stats` derives `threat_level` from the
## wave number that row already prints.
##
## The no-verdict assertion is the design, not decoration. Every sentence that
## explains this comparison also grades the player for it, and the losing run is
## the one that reads this card.
func test_the_run_summary_says_where_the_seeds_went_without_grading_it() -> String:
	var stats: Dictionary = {
		"victory": false,
		"endless": false,
		"wave": 10,
		"wave_count": 22,
		"threat_level": 3,
		"lives_lost": 10,
		"seeds_earned_total": 412,
		"high_score": 900,
		"new_record": false,
		"compost_total": 30,
		"compost_resolved": 44,
		"pests_defeated": 180,
		"run_seconds": 604.0,
		"stop_cell": Vector2i(6, 3),
		"stop_cell_stops": 41,
		"worst_cell": Vector2i(13, 7),
		"worst_cell_losses": 10,
		# The breadth-first run of cycle 101, in the two numbers that describe it.
		"seeds_on_plants": 275,
		"seeds_on_upgrades": 0,
	}
	var panel := RunSummary.build(stats)
	await _T.instantiate_scene(panel)
	var rows: Array = panel.summary_rows()

	var err: String = _T.assert_eq(rows.size(), 7,
		"the card is still seven rows — the spend row is a swap, not an eighth")

	var keys: Array[String] = []
	for row: Array in rows:
		keys.append(String(row[0]))
	if err == "":
		err = _T.assert_true(keys.has("Seeds spent"),
			"the card names where the seeds went, got rows: %s" % str(keys))
	if err == "":
		err = _T.assert_false(keys.has("Threat reached"),
			"and the row it replaced is gone rather than both being on the card")

	# The value, both halves of it, off the built label rather than off the builder.
	var spend: Label = panel.get_node_or_null("Value_Seedsspent") as Label
	if err == "":
		err = _T.assert_true(spend != null, "the spend row was really built")
	if err == "":
		err = _T.assert_eq(spend.text, "275 on plants, 0 on upgrades",
			"stated as two totals — the breadth-first run's policy, back in its own numbers")
	if err == "":
		# The builder direct, the way _compost_text and beds_text are asserted: every
		# branch of it is readable off a plain Dictionary with no Control built.
		err = _T.assert_eq(panel.spend_text(), spend.text,
			"the row draws exactly what the builder returns")
	if err == "":
		# The depth-first run of the same A/B, and a run that spent nothing at all.
		# The zero case is a real reading, not a missing one — Game.summary_stats
		# writes both keys on every run — which is why there is no sentinel branch.
		var depth := RunSummary.build({"seeds_on_plants": 60, "seeds_on_upgrades": 215})
		var nothing := RunSummary.build({})
		err = _T.assert_eq(depth.spend_text(), "60 on plants, 215 on upgrades",
			"the depth-first run reads back the opposite policy")
		if err == "":
			err = _T.assert_eq(nothing.spend_text(), "0 on plants, 0 on upgrades",
				"and a run that bought nothing says so rather than showing an empty row")
		depth.free()
		nothing.free()

	# The threat number survived the swap, on the row it can be derived from.
	var waves: Label = panel.get_node_or_null("Value_Wavessurvived") as Label
	if err == "":
		err = _T.assert_true(waves != null, "the waves row exists")
	if err == "":
		err = _T.assert_eq(waves.text, "10 of 22 — threat level 3",
			"the threat scale folded onto the row its own input is printed on")
	if err == "":
		# Level 1 is the scale's floor and says nothing, same rule the live readout
		# follows (test_the_threat_readout_hides_itself_at_wave_one).
		var early := RunSummary.build({"wave": 1, "wave_count": 22, "threat_level": 1})
		var early_rows: Array = early.summary_rows()
		err = _T.assert_eq(String(early_rows[0][1]), "1 of 22",
			"at level 1 the clause is omitted rather than printed as noise")
		early.free()

	# No verdict, anywhere on the card. A sentence that scolds is worse than nothing.
	if err == "":
		var scolds: Array[String] = ["should", "too many", "instead", "wasted", "spread",
			"mistake", "never upgraded", "you failed"]
		for row: Array in rows:
			var line: String = ("%s %s" % [String(row[0]), String(row[1])]).to_lower()
			for word: String in scolds:
				err = _T.assert_false(line.contains(word),
					"no row grades the player (found '%s' in '%s')" % [word, line])
				if err != "":
					break
			if err != "":
				break

	_T.free_ui(panel)
	return err


## The spend row fits its column at the biggest numbers the game can produce.
##
## Measured through `_T.text_width`, which reads the label's own resolved theme
## font. `get_minimum_size()` would report ~1px here: every value label on this
## card sets `clip_text` and OVERRUN_TRIM_ELLIPSIS, so the obvious width assertion
## passes unconditionally on exactly the labels that need checking — and a row that
## overflows would show as a silently ellipsised number rather than as a failure.
##
## The comparison is against the beds row, which the file names as this column's
## width high-water mark. A new row is affordable precisely while it stays under
## the row that already sets the ceiling.
## The devtools bridge must stay out of a build a player can run
## (plant-tower-defense-kdnl).
##
## `dev_tools.gd` carries a local patch gating the bus and the `entry_hook` on
## `OS.has_feature("template")`. It fixes a defect that took a real itch.io deploy to
## notice: the hook that skips the title screen for `/verify` was skipping it for every
## player, so the web build opened straight onto the board.
##
## WHY THIS READS SOURCE INSTEAD OF BEHAVIOUR, which is normally the wrong shape: the two
## branches are IDENTICAL in an editor build. `OS.has_feature("template")` is false here
## whatever the code says, so a run with the guard and a run without it agree on every
## observable — there is nothing to assert at runtime, and lint, the suite and `findings`
## all pass either way. The only witness is the text.
##
## AND IT IS LOAD-BEARING BECAUSE THE FILE IS NOT OURS. `dev_tools.gd` is listed in
## `addons/godot_selftest/.harness_manifest.json`, so `/scaffold-godot-harness` regenerates
## it and silently reverts this. A newer harness is already on this machine than the
## project runs, so a refresh is an ordinary thing to do — and this file's recorded sha has
## already drifted from its manifest once. The failure mode is the bad one: everything
## keeps building and deploying, and the only symptom is players landing on the board.
## READ FROM THE CODE, NOT FROM THE FILE (plant-tower-defense-qewq). `--devtools-force`
## appears TWICE in dev_tools.gd and one of them is the comment on the line above the
## gate. A version of this test that greps the raw file would pass with the flag deleted
## from the condition and the comment left behind, which is the cycle-91 shape: a token
## kept alive by an occurrence that does nothing. `_code_only` truncates `#` comments,
## so both needles below are asserted against live code.
func test_the_devtools_bridge_stays_out_of_a_players_build() -> String:
	var path := "res://addons/godot_selftest/dev_tools.gd"
	var raw: String = FileAccess.get_file_as_string(path)
	var err: String = _T.assert_gt(raw.length(), 0, "dev_tools.gd is readable at %s" % path)
	if err != "":
		return err
	var src: String = _code_only(raw)
	err = _T.assert_gt(src.strip_edges().length(), 0,
		"and it is not all comments -- an all-blank code half would make both needles"
			+ " below fail for the wrong reason")
	if err == "":
		err = _T.assert_true(src.contains("OS.has_feature(\"template\")"),
			("the passive gate still tests OS.has_feature(\"template\"). If this went red "
				+ "after /scaffold-godot-harness, the harness overwrote the patch: "
				+ "re-apply it and see plant-tower-defense-kdnl. An exported build without "
				+ "it polls the bus and fires entry_hook for PLAYERS."))
	if err == "":
		# The opt-back-in half. Without it the patch is a wall rather than a gate, and
		# driving a real export from the bridge becomes impossible instead of explicit.
		err = _T.assert_true(src.contains("--devtools-force"),
			"and the --devtools-force escape hatch survives IN THE CONDITION and not only "
				+ "in the comment beside it, so a template build can still be driven "
				+ "deliberately")
	return err


func test_the_spend_row_fits_its_column_at_endless_magnitudes() -> String:
	var stats: Dictionary = {
		"endless": true,
		"wave": 137,
		"threat_level": 9,
		"lives_lost": 5,
		"escapes_recorded": 5,
		"escapes_untouched": 4,
		"seeds_on_plants": 8421,
		"seeds_on_upgrades": 4210,
	}
	var panel := RunSummary.build(stats)
	await _T.instantiate_scene(panel)

	var column: float = RunSummary.CARD.size.x * 0.58 - RunSummary.ROW_INSET
	var spend: Label = panel.get_node_or_null("Value_Seedsspent") as Label
	var err: String = _T.assert_true(spend != null, "the spend row is on the card")
	if err == "":
		err = _T.assert_eq(spend.text, "8421 on plants, 4210 on upgrades",
			"four digits on both sides, which is the widest this row gets")
	var wanted: float = 0.0
	if err == "":
		wanted = _T.text_width(spend)
		err = _T.assert_gt(wanted, 1.0,
			"the font really measured it — a 1px answer is the clip_text stub, not a width")
	if err == "":
		err = _T.assert_true(wanted <= column,
			"the spend row fits without ellipsis (%.0f of %.0f px)" % [wanted, column])
	if err == "":
		# The folded waves row is the other string this change lengthened.
		var waves: Label = panel.get_node_or_null("Value_Wavessurvived") as Label
		err = _T.assert_true(waves != null, "the waves row is on the card")
		if err == "":
			err = _T.assert_eq(waves.text, "137 — threat level 9", "endless prints a bare wave count")
		if err == "":
			err = _T.assert_true(_T.text_width(waves) <= column,
				"and the fold still fits (%.0f of %.0f px)" % [_T.text_width(waves), column])
	if err == "":
		# The row the file names as this column's high-water mark, measured in the
		# same breath. Which of the two is wider is a font-metric fact this test
		# deliberately does not predict — what it pins is that BOTH fit, so a
		# regression cannot hide behind "the other row was the wide one".
		var beds: Label = panel.get_node_or_null("Value_Gardenlost") as Label
		err = _T.assert_true(beds != null, "the beds row is on the card to measure against")
		if err == "":
			err = _T.assert_true(_T.text_width(beds) <= column,
				("and the beds row, which sets this column's high-water mark, still fits "
					+ "(%.0f of %.0f px)") % [_T.text_width(beds), column])

	_T.free_ui(panel)
	return err


# -- The HUD lays out against the live viewport (plant-tower-defense-0jye) ----
#
# `Hud.get_viewport_width()/get_viewport_height()` used to return the project
# SETTING and every caller believed they named the screen. With
# `stretch/mode=canvas_items` + `stretch/aspect="expand"` the canvas genuinely
# changes shape with the window, so on anything but a 16:9 window the top bar
# stopped short of the edge, the side panel detached from it, and the prep
# strip's 100% was not the screen's.
#
# Every geometry assertion below is REAL, not `[HEADLESS geometry]`: each one
# measures a HUD hosted in a SubViewport of a size this test chose, which is the
# one thing headless layout does honestly. What headless cannot tell us is
# whether the ROOT window's content-scale override produces the canvas size these
# tests assume for a given aspect — that half is named for the parent as a live
# check rather than faked here.


## The shapes `stretch/aspect="expand"` can actually hand this HUD. `expand`
## divides the window size by min(window/base) per axis, so the canvas is the
## design size on the constraining axis and LARGER on the other — never smaller
## on either. A 21:9 window widens it; a 4:3 window makes it taller.
const VIEWPORT_SHAPES: Array[Vector2i] = [
	Vector2i(1152, 648),   # the design size, 16:9
	Vector2i(1536, 648),   # 21:9 — the width case
	Vector2i(1152, 864),   # 4:3 — the height case
	Vector2i(1920, 648),   # absurdly wide, to prove nothing is centred on a constant
]


## The bug, as an assertion: every viewport-derived rect on the HUD is derived
## from the viewport it is actually in.
func test_the_hud_lays_itself_out_against_the_live_viewport_not_the_setting() -> String:
	var err := ""
	for shape: Vector2i in VIEWPORT_SHAPES:
		var game := await _T.instantiate_scene(GAME_SCENE, shape) as Game
		await _pump(game)
		var hud: Hud = game.hud
		var w: float = float(shape.x)
		var h: float = float(shape.y)

		err = _T.assert_eq(hud.get_viewport_width(), shape.x,
			"the HUD reads the live canvas width at %s, not the %d it was designed at"
				% [shape, Hud.design_width()])
		if err == "":
			err = _T.assert_eq(hud.get_viewport_height(), shape.y,
				"and the live height at %s" % [shape])
		if err == "":
			var bar: ColorRect = hud.get_node_or_null("Root/TopBar") as ColorRect
			err = _T.assert_float_eq(bar.size.x, w, 0.5,
				"the top bar spans the full width at %s (%.0f of %.0f)" % [shape, bar.size.x, w])
		if err == "":
			var panel: ColorRect = hud.get_node_or_null("Root/SidePanel") as ColorRect
			err = _T.assert_float_eq(panel.position.x + panel.size.x, w, 0.5,
				"the side panel is flush with the right edge at %s (right edge %.0f of %.0f)"
					% [shape, panel.position.x + panel.size.x, w])
			if err == "":
				err = _T.assert_float_eq(panel.position.y + panel.size.y, h, 0.5,
					"and reaches the foot of the screen at %s (%.0f of %.0f)"
						% [shape, panel.position.y + panel.size.y, h])
		if err == "":
			# The banner is centred on the BOARD's half, so its right edge is the
			# panel's left edge at every shape — the abutment that keeps the two
			# from sharing pixels.
			var banner: Label = hud.get_node_or_null("Root/Banner") as Label
			err = _T.assert_float_eq(banner.size.x, w - float(Hud.PANEL_WIDTH), 0.5,
				"the banner stops where the side panel starts at %s (%.0f wide)"
					% [shape, banner.size.x])
		if err == "":
			var message: Label = hud.get_node_or_null("Root/TopBar/MessageLabel") as Label
			err = _T.assert_float_eq(message.position.x + message.size.x,
				w - float(Hud.PANEL_WIDTH), 0.5,
				"the message line stops at the panel's column at %s (%.0f)"
					% [shape, message.position.x + message.size.x])
		if err == "":
			# The prep strip's 100% is the screen's 100%. Staged through the game's
			# own state rather than by writing the strip's size, which the next
			# _refresh() would put back.
			#
			# No _pump after the refresh, on purpose: _process() ticks _prep_left
			# down every frame, so a pump here would measure a strip that is a
			# frame or two short of full and the assertion would be about the
			# clock rather than about the width. The strip's size is written
			# directly by _refresh_prep_bar, not by a container pass, so it is
			# already correct on return.
			game._prep_left = Game.PREP_SECONDS
			game._wave_live = false
			game._refresh()
			var strip: ColorRect = hud.get_node_or_null("Root/TopBar/PrepBar") as ColorRect
			err = _T.assert_true(strip != null and strip.visible,
				"the prep strip is up between waves at %s" % [shape])
			if err == "":
				err = _T.assert_float_eq(strip.size.x, w, 0.5,
					"a full prep strip is a full screen wide at %s (%.0f of %.0f)"
						% [shape, strip.size.x, w])
		_T.free_ui(game)
		if err != "":
			return err
	return err


## The other half, and the one nothing in this project connected at all before:
## the HUD re-runs its layout when the viewport CHANGES, not only when it is
## built. Resizing the host SubViewport is a real `Viewport.size_changed`, which
## is the same signal the root window emits on a resize.
func test_the_hud_relays_itself_out_when_the_viewport_changes_shape() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE, Vector2i(1152, 648)) as Game
	await _pump(game)
	var hud: Hud = game.hud
	var panel: ColorRect = hud.get_node_or_null("Root/SidePanel") as ColorRect
	var bar: ColorRect = hud.get_node_or_null("Root/TopBar") as ColorRect
	var err: String = _T.assert_true(panel != null and bar != null,
		"the panel and the bar are both on screen to re-measure")
	if err == "":
		err = _T.assert_float_eq(panel.position.x + panel.size.x, 1152.0, 0.5,
			"sanity: flush right at the size it was built at")
	if err == "":
		var host := game.get_viewport() as SubViewport
		err = _T.assert_true(host != null, "the test host is a SubViewport we can resize")
		if err == "":
			host.size = Vector2i(1536, 720)
			await _pump(game)
			err = _T.assert_float_eq(panel.position.x + panel.size.x, 1536.0, 0.5,
				("after a resize the panel is flush right again (%.0f of 1536) -- "
					+ "this is what nothing connecting size_changed used to cost")
					% (panel.position.x + panel.size.x))
	if err == "":
		err = _T.assert_float_eq(bar.size.x, 1536.0, 0.5,
			"and the top bar re-spanned the new width (%.0f)" % bar.size.x)
	if err == "":
		err = _T.assert_float_eq(panel.position.y + panel.size.y, 720.0, 0.5,
			"and the panel re-reached the new foot (%.0f)" % (panel.position.y + panel.size.y))
	_T.free_ui(game)
	return err


## What the top row's width budget MEANS once the viewport can move.
##
## `Hud.stats_row_budget()` prices the readouts, separations and buttons; the row
## is handed `viewport_width - 2 * STATS_ROW_MARGIN`. Ask an HBoxContainer for
## less than its children's sum and it does not shrink — `Control.size` is
## clamped UP to the combined minimum, so the assignment appears to succeed and
## the wave button simply lands off the right edge with nothing reporting it.
##
## So the budget is only safe while the canvas cannot be narrower than the size
## it was measured at, and that is a property of TWO settings, both asserted here
## rather than assumed: `stretch/aspect="expand"` never yields a canvas smaller
## than the base size, and the base width is `design_width()`. Change either and
## this test goes red instead of the wave button going quietly off screen.
func test_the_top_row_fits_the_narrowest_viewport_the_stretch_mode_can_produce() -> String:
	var aspect: String = str(ProjectSettings.get_setting("display/window/stretch/aspect", "keep"))
	var err: String = _T.assert_eq(aspect, "expand",
		("the design width is only a FLOOR under stretch/aspect=expand; at \"%s\" the "
			+ "canvas can be narrower than the base size and this budget needs re-deriving")
			% aspect)
	if err != "":
		return err

	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	await _pump(game)
	var stats: HBoxContainer = game.hud.get_node_or_null("Root/TopBar/StatsRow") as HBoxContainer
	err = _T.assert_true(stats != null, "the stats row is on the bar to price")
	if err == "":
		# Read off the live row, so a control added to the bar later is priced here
		# without anyone remembering to update a literal.
		var separations: int = stats.get_child_count() - 1
		var floor_px: float = Hud.min_viewport_width(separations)
		var design: float = float(Hud.design_width())
		err = _T.assert_true(floor_px <= design,
			("the top row needs %.0fpx of canvas and the narrowest canvas expand can "
				+ "produce is %.0fpx -- %.0fpx of headroom")
				% [floor_px, design, design - floor_px])
		if err == "":
			# And the live row agrees with the arithmetic: no shortfall at the
			# narrowest shape the game can reach, on either axis.
			err = _T.assert_float_eq(game.hud.stats_row_shortfall(), 0.0, 0.001,
				"so the HUD reports no shortfall at the design width")
		if err == "":
			err = _T.assert_float_eq(game.hud.stats_row_shortfall_at(design), 0.0, 0.001,
				"and the same asked as arithmetic rather than off the live viewport")
		if err == "":
			# The height half of the same floor. Nothing on this HUD is priced
			# against it today, but the side panel's plant bar is laid out down a
			# fixed column and it is the axis a 4:3 window expands.
			err = _T.assert_eq(game.hud.get_viewport_height(), Hud.design_height(),
				"the design height is what a HUD hosted at the design size reports")
	_T.free_ui(game)
	return err


## The failure the check above prevents, made legible.
##
## A canvas narrower than the row's budget is unreachable through the window
## today, but it is one settings edit away and it is reachable right now by
## hosting the HUD in a small SubViewport — which is exactly what this does. The
## point is that the HUD SAYS the number rather than silently clamping: without
## `stats_row_shortfall()` the only symptom is a wave button off the right edge
## that no per-node check can see, because the button fits its own box perfectly.
func test_a_canvas_too_narrow_for_the_top_row_reports_the_shortfall() -> String:
	var narrow := Vector2i(800, 648)
	var game := await _T.instantiate_scene(GAME_SCENE, narrow) as Game
	await _pump(game)
	var hud: Hud = game.hud
	var stats: HBoxContainer = hud.get_node_or_null("Root/TopBar/StatsRow") as HBoxContainer
	var err: String = _T.assert_true(stats != null, "the stats row is on the bar")
	if err == "":
		var expected: float = Hud.min_viewport_width(stats.get_child_count() - 1) - float(narrow.x)
		err = _T.assert_float_eq(hud.stats_row_shortfall(), expected, 0.5,
			"the HUD names the %.0fpx it is short at %s" % [expected, narrow])
	if err == "":
		# The silent half, pinned so nobody has to rediscover it: the row did NOT
		# take the width it was given.
		err = _T.assert_true(stats.size.x > float(narrow.x) - Hud.STATS_ROW_MARGIN * 2.0,
			("and the row held its minimum (%.0f) rather than the %.0f it was asked for "
				+ "-- the clamp that makes this failure invisible")
				% [stats.size.x, float(narrow.x) - Hud.STATS_ROW_MARGIN * 2.0])
	if err == "":
		# Everything that CAN reflow still did, so the shortfall is one legible
		# problem rather than a HUD that fell apart.
		var panel: ColorRect = hud.get_node_or_null("Root/SidePanel") as ColorRect
		err = _T.assert_float_eq(panel.position.x + panel.size.x, float(narrow.x), 0.5,
			"the side panel is still flush right at %s" % [narrow])
	_T.free_ui(game)
	return err


## The occlusion audit's static half (`.claude/skills/godot-hud-occlusion-audit`),
## swept across every shape the stretch mode can produce.
##
## A re-layout is precisely the thing that produces two siblings sharing pixels,
## and `validate-ui` / `findings` structurally cannot see it: they measure each
## Control against its OWN box, and in an overlap both boxes are fine. The
## existing pairwise tests all measure one shape; this one asks the same question
## at four, with the banner up and the readouts at their longest, because the
## pairs that break are the ones whose gap is a difference of two viewport-derived
## numbers.
func test_no_two_hud_controls_share_pixels_at_any_viewport_shape() -> String:
	var err := ""
	for shape: Vector2i in VIEWPORT_SHAPES:
		var game := await _T.instantiate_scene(GAME_SCENE, shape) as Game
		# The longest state the top row can reach, staged through the game rather
		# than by writing label text (which the next _refresh() would put back).
		game.bank.seeds = 9999
		game.director.current_wave = 42
		for i: int in range(18):
			game.compost.drop_husk(Vector2(float(i) * 8.0, 0.0), 9)
		game.hud.show_message("A message long enough to want the whole width of the bar and then some more.")
		game._refresh()
		# And the banner up, which is the one surface that spans the board's half.
		game.hud.announce_wave(12, 24, "tougher and faster")
		await _pump(game)

		# Two sets, deliberately, and not "every pair under Root". These are the two
		# pairwise checks this suite already makes at 1152x648
		# (test_no_two_top_bar_controls_share_pixels and
		# test_the_wave_banner_shares_no_pixels_with_the_rest_of_the_hud), asked
		# again at the other three shapes -- so a failure here means the RE-LAYOUT
		# broke a pair, not that some pre-existing pair inside the side panel was
		# never audited. Auditing those is a separate question at every shape alike.
		var bar_rects: Dictionary = _hud_rects(game.hud.get_node("Root/TopBar"))
		err = _T.assert_true(bar_rects.size() >= 4,
			"at %s found %d sized Controls in the top bar to compare"
				% [shape, bar_rects.size()])
		var bar_names: Array = bar_rects.keys()
		for i: int in range(bar_names.size()):
			if err != "":
				break
			for j: int in range(i + 1, bar_names.size()):
				var a: Rect2 = bar_rects[bar_names[i]]
				var b: Rect2 = bar_rects[bar_names[j]]
				if a.intersects(b):
					err = _T.assert_false(true, "at %s top bar: %s %s overlaps %s %s"
						% [shape, bar_names[i], a, bar_names[j], b])
					break

		if err == "":
			var rects: Dictionary = _hud_rects(game.hud.get_node("Root"))
			err = _T.assert_true(rects.has("Banner") and rects.has("BannerNote"),
				"at %s the announced banner has both rows sized, got %s" % [shape, rects.keys()])
			for row: String in ["Banner", "BannerNote"]:
				if err != "":
					break
				for other: String in rects:
					if other == "Banner" or other == "BannerNote":
						continue
					if (rects[row] as Rect2).intersects(rects[other] as Rect2):
						err = _T.assert_false(true, "at %s %s %s overlaps %s %s"
							% [shape, row, rects[row], other, rects[other]])
						break
		_T.free_ui(game)
		if err != "":
			return err
	return err


# =============================================================================
# ONE VIEWPORT HELPER, TWO QUESTIONS (plant-tower-defense-nrup)
#
# `Hud`, `TitleScreen`, `OverlayScreen` and `PauseScreen` each declared their own
# `get_viewport_width()/height()` reading `ProjectSettings`, and
# `KeyBindingScreen.panel_rect()` and `OptionsScreen.rows_capacity()` inlined the
# same read again. Cycle 105 fixed the copy in `Hud`; this section is the rest of
# it and, more to the point, the reason there were ever four.
#
# The reason is that one name answered two questions: "how big is the screen I
# have to cover" (live, and genuinely different from the setting under
# `stretch/aspect="expand"`) and "how big is the canvas this was composed on"
# (the design size, which every row budget in the game is a statement about).
# `ScreenMetrics` names them apart. These checks are about the SPLIT, not about
# either half on its own -- the interesting failures are a covering layer left at
# the design size, and a budget quietly following the window.
#
# GEOMETRY NOTE, because it decides whether these numbers are worth anything:
# `_T.instantiate_ui` hosts the node in a SubViewport whose `size` it SETS, so
# `get_visible_rect().size` inside these tests is exactly the Vector2i passed in,
# on any machine, headless or not. These are NOT `[HEADLESS geometry]` readings
# of a 64x64 window -- a 1536x648 host here is a real 1536x648 canvas. What they
# cannot see is the stretch transform the ROOT viewport applies, which is what
# turns a 1720x720 window into a 1548-unit canvas in the first place; that half
# needs `cmd set_resolution` against a running game.
# =============================================================================


## The census: after this bead, which files still read the project setting directly?
##
## Written as a subset check against a NAMED allowlist rather than as "exactly
## zero", because two of the copies live in files this lane did not own -- and
## written as a list rather than a count, because a count going from 8 to 3 says
## nothing about WHICH three survived. It passes now, it keeps passing when the
## two parent-owned copies are folded in, and it fails the day a ninth appears.
##
## This is the check that makes "why are there three" a standing answer instead of
## a paragraph in a commit message.
func test_only_the_named_files_still_read_the_viewport_setting() -> String:
	# ScreenMetrics is the one implementation and must read it.
	# hud.gd and run_summary.gd are the two copies plant-tower-defense-nrup could
	# not reach (file ownership, cycle 106 fan-out) -- folding them in is a
	# follow-up, and this line is where it gets noticed if it never happens.
	var allowed: Array[String] = [
		"screen_metrics.gd", "hud.gd", "run_summary.gd",
	]
	var dir: DirAccess = DirAccess.open("res://game")
	var err: String = _T.assert_true(dir != null, "res://game is readable")
	if err != "":
		return err
	var offenders: Array[String] = []
	var scanned: int = 0
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".gd"):
			continue
		scanned += 1
		var text: String = FileAccess.get_file_as_string("res://game/%s" % file_name)
		# The setting KEY, not the word "viewport" -- every screen mentions the
		# viewport in prose and matching that would report the whole directory.
		if not text.contains("display/window/size/viewport_"):
			continue
		if not allowed.has(file_name):
			offenders.append(file_name)
	# The denominator: a glob that matched nothing would print a clean result
	# identical to a directory with no offenders in it.
	err = _T.assert_gt(scanned, 20, "the sweep read the game scripts (%d of them)" % scanned)
	if err == "":
		err = _T.assert_true(offenders.is_empty(),
			("%s read display/window/size/viewport_* directly. Ask ScreenMetrics "
				+ "instead -- design_width()/design_height() for a budget or a "
				+ "composition coordinate, live_width()/live_height() for anything "
				+ "that has to reach the edge of the window.") % [offenders])
	return err


## Both halves of the split, asserted as the two different answers they are.
##
## `design_*` is the project setting and every surface's design getter must agree
## with it -- that agreement is what "one implementation" means here, and it is
## checked rather than assumed because four of these used to be four bodies.
##
## `live_*` is asked of a node, and its two fallbacks are the whole reason the
## ProjectSettings read was defensible in the first place: a screen with no
## viewport, and a viewport with no size yet.
func test_screen_metrics_answers_design_and_live_as_separate_questions() -> String:
	var design_w: int = int(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
	var design_h: int = int(ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	var err: String = _T.assert_eq(ScreenMetrics.design_width(), design_w,
		"ScreenMetrics.design_width() is the project setting")
	if err == "":
		err = _T.assert_eq(ScreenMetrics.design_height(), design_h, "and design_height()")
	if err == "":
		err = _T.assert_eq(ScreenMetrics.design_size(), Vector2(float(design_w), float(design_h)),
			"and design_size() is the pair of them")
	# Every surface's design getter is the SAME number, from the same place. Four
	# separate bodies agreed too, right up until one of them was fixed.
	if err == "":
		err = _T.assert_eq(OverlayScreen.design_width(), design_w, "OverlayScreen.design_width() agrees")
	if err == "":
		err = _T.assert_eq(OverlayScreen.design_height(), design_h, "OverlayScreen.design_height() agrees")
	if err == "":
		err = _T.assert_eq(TitleScreen.viewport_width(), design_w, "TitleScreen.viewport_width() agrees")
	if err == "":
		err = _T.assert_eq(TitleScreen.viewport_height(), design_h, "TitleScreen.viewport_height() agrees")
	if err == "":
		err = _T.assert_eq(Hud.design_width(), design_w, "Hud.design_width() agrees")
	if err == "":
		err = _T.assert_eq(Hud.design_height(), design_h, "Hud.design_height() agrees")
	# The fallback that made the old ProjectSettings read defensible: a screen
	# asked for its size before it is inside a viewport gets the design size, not
	# a zero that would collapse every rect on it.
	if err == "":
		err = _T.assert_eq(ScreenMetrics.live_size(null), ScreenMetrics.design_size(),
			"live_size(null) falls back to the design size rather than returning zero")
	if err == "":
		var unparented := Control.new()
		err = _T.assert_eq(ScreenMetrics.live_size(unparented), ScreenMetrics.design_size(),
			"and so does a Control that is not in any tree")
		if err == "":
			err = _T.assert_eq(ScreenMetrics.live_width(unparented), ScreenMetrics.design_width(),
				"live_width() reads the same fallback")
		if err == "":
			err = _T.assert_eq(ScreenMetrics.live_height(unparented), ScreenMetrics.design_height(),
				"and live_height()")
		unparented.free()
	# The centring idiom four surfaces had each written out. Pure, so it is checked
	# without a node: a 700-wide paper on the 1152 design canvas starts at 226,
	# which is exactly the constant OptionsScreen.PANEL carried.
	if err == "":
		err = _T.assert_float_eq(ScreenMetrics.centred_left(null, 700.0), 226.0, 0.001,
			"centred_left() reproduces the 226 OptionsScreen.PANEL had baked in")
	if err == "":
		err = _T.assert_float_eq(ScreenMetrics.centred_left(null, 1000.0), 76.0, 0.001,
			"and the 76 NotebookScreen.PANEL has")
	if err == "":
		# A composition WIDER than the canvas clamps to 0 rather than going
		# negative: a paper starting off the left edge is worse than one overflowing
		# the right, because its left column is the one carrying the row labels.
		err = _T.assert_float_eq(ScreenMetrics.centred_left(null, 2000.0), 0.0, 0.001,
			"and never returns a negative left edge")
	return err


## Every full-screen surface covers a canvas WIDER than the one it was composed on.
##
## This is the defect, stated as a check. At 1536x648 -- the canvas a 21:9 window
## produces under `stretch/aspect="expand"` -- each of these used to size itself
## and its backdrop to 1152 and leave 384px of whatever is behind it showing.
##
## On PauseScreen that strip is not cosmetic: its Backdrop is MOUSE_FILTER_STOP
## precisely so the board underneath cannot be played through a pause, and the
## part it does not cover is live, clickable board.
func test_every_full_screen_surface_covers_a_wider_than_design_canvas() -> String:
	var wide := Vector2i(1536, 648)
	var builders: Array[Dictionary] = [
		{"what": "TitleScreen", "make": func() -> Node: return (load("res://game/title.tscn") as PackedScene).instantiate()},
		{"what": "KeyBindingScreen", "make": func() -> Node: return KeyBindingScreen.new()},
		{"what": "OptionsScreen", "make": func() -> Node: return OptionsScreen.new()},
		{"what": "NotebookScreen", "make": func() -> Node: return NotebookScreen.new()},
		{"what": "PauseScreen", "make": func() -> Node: return PauseScreen.build("", Game.key_help())},
	]
	# The denominator. A list that lost an entry would still report a clean sweep.
	var err: String = _T.assert_eq(builders.size(), 5,
		"five full-screen surfaces swept -- add the sixth here or this is a subset")
	if err != "":
		return err
	for spec: Dictionary in builders:
		var what: String = String(spec["what"])
		var make: Callable = spec["make"]
		var screen := await _T.instantiate_ui(make.call(), wide) as Control
		err = _T.assert_true(screen != null, "%s hosts at 1536x648" % what)
		if err == "":
			err = _T.assert_float_eq(screen.size.x, 1536.0, 0.5,
				("%s sized itself to %.0f on a 1536-wide canvas -- that is the design "
					+ "width, not the screen") % [what, screen.size.x])
		if err == "":
			err = _T.assert_float_eq(screen.size.y, 648.0, 0.5, "%s takes the full height too" % what)
		if err == "":
			var backdrop: Control = screen.get_node_or_null("Backdrop") as Control
			err = _T.assert_true(backdrop != null, "%s has its Backdrop" % what)
			if err == "":
				err = _T.assert_float_eq(backdrop.size.x, 1536.0, 0.5,
					("%s's Backdrop stops at %.0f, leaving %.0fpx of what is behind it "
						+ "showing through") % [what, backdrop.size.x, 1536.0 - backdrop.size.x])
			if err == "":
				err = _T.assert_float_eq(backdrop.size.y, 648.0, 0.5,
					"%s's Backdrop covers the height" % what)
		_T.free_ui(screen)
		if err != "":
			return err
	return err


## A window resized WHILE a surface is on screen. The half that "it is rebuilt on
## open" does not cover.
##
## Checked rather than assumed, per the bead: every overlay IS `new()` +
## `add_child()` on open and `queue_free()` on close, so the next opening is
## always correct. That says nothing about the opening in progress -- the Options
## dials and the Keys table are read screens a player sits on, and the pause card
## holds one open over a HELD run, which is the single most likely moment for
## someone to maximise or drag a window.
##
## Both halves are asserted: the covering layer follows, and the composition
## deliberately does NOT. The second is a known limitation recorded as a fact --
## re-centring the paper means re-running the builder, which would take a Keys row
## out of capture and move focus out from under the player.
func test_a_resize_moves_the_covering_layer_and_leaves_the_composition() -> String:
	var screen := await _T.instantiate_ui(KeyBindingScreen.new(), Vector2i(1152, 648)) as KeyBindingScreen
	var err: String = _T.assert_true(screen != null, "the Keys screen hosts")
	if err != "":
		return err
	var paper: Control = screen.get_node_or_null("Paper") as Control
	var backdrop: Control = screen.get_node_or_null("Backdrop") as Control
	err = _T.assert_true(paper != null and backdrop != null, "with a Paper and a Backdrop")
	if err == "":
		err = _T.assert_float_eq(backdrop.size.x, 1152.0, 0.5, "covering 1152 to start with")
	var paper_before: float = 0.0
	if err == "":
		paper_before = paper.position.x
		err = _T.assert_float_eq(paper_before,
			ScreenMetrics.centred_left(screen, KeyBindingScreen.panel_width()), 1.0,
			"and the paper centred on that canvas")

	if err == "":
		# The real event, not a stand-in: setting a Viewport's size is what emits
		# `size_changed`, and this is the same signal a resized OS window raises.
		var host: SubViewport = screen.get_viewport() as SubViewport
		err = _T.assert_true(host != null, "the host is a SubViewport whose size can be driven")
		if err == "":
			host.size = Vector2i(1536, 648)
			await screen.get_tree().process_frame
			await screen.get_tree().process_frame
			err = _T.assert_float_eq(screen.size.x, 1536.0, 0.5,
				"the overlay grew with the window rather than staying at its opening size")
		if err == "":
			err = _T.assert_float_eq(backdrop.size.x, 1536.0, 0.5,
				("the Backdrop followed -- at %.0f it would leave a live strip of whatever "
					+ "it is covering") % backdrop.size.x)
		if err == "":
			# The recorded limitation. If someone makes the composition track a
			# resize, THIS is the assertion that should be rewritten, on purpose,
			# rather than a screen that silently started re-laying-out mid-capture.
			err = _T.assert_float_eq(paper.position.x, paper_before, 0.5,
				("the paper stays where it was opened -- re-centring it means re-running "
					+ "the builder, which discards a row mid-capture. It re-centres on the "
					+ "next open, and panel_rect() already reports the new one: %.0f")
					% screen.panel_rect().position.x)
	_T.free_ui(screen)
	return err


## The papers centre on the LIVE canvas, and the rows come with them.
##
## All three overlays centre their paper horizontally, and until this bead two of
## them did it by carrying `(1152 - width) / 2` pre-computed into a constant --
## which is why `OptionsScreen.PANEL`'s x of 226 never looked like a copy of
## `KeyBindingScreen.panel_rect()`'s arithmetic. `paper_left()` is the one place
## it lives now.
##
## The rows matter as much as the paper: every offset on these screens is measured
## from `panel_rect().position.x`, so a paper that re-centres while the rows read a
## constant is strictly worse than one that does not move at all.
func test_the_overlay_papers_centre_on_the_live_canvas() -> String:
	var wide := Vector2i(1536, 648)

	var keys := await _T.instantiate_ui(KeyBindingScreen.new(), wide) as KeyBindingScreen
	var expected_keys: float = (1536.0 - KeyBindingScreen.panel_width()) / 2.0
	var err: String = _T.assert_float_eq(keys.panel_rect().position.x, expected_keys, 1.0,
		"the Keys paper centres on 1536, not on the 1152 it was composed at")
	if err == "":
		err = _T.assert_float_eq(keys.paper_left(KeyBindingScreen.panel_width()), expected_keys, 1.0,
			"and paper_left() is where that number comes from")
	if err == "":
		var drawn: Control = keys.get_node_or_null("Paper") as Control
		err = _T.assert_true(drawn != null and absf(drawn.position.x - expected_keys) <= 1.0,
			"the DRAWN paper is at the derived x, not a second copy of the sum")
	if err == "":
		var row: Control = keys.get_node_or_null("RowButton0") as Control
		err = _T.assert_true(row != null, "the Keys screen drew its first row button")
		if err == "":
			err = _T.assert_float_eq(row.position.x,
				keys.panel_rect().position.x + KeyBindingScreen.button_x(), 1.0,
				"and the row travelled with the paper rather than staying at the constant")
	_T.free_ui(keys)
	if err != "":
		return err

	var options := await _T.instantiate_ui(OptionsScreen.new(), wide) as OptionsScreen
	var expected_options: float = (1536.0 - OptionsScreen.PANEL.size.x) / 2.0
	err = _T.assert_float_eq(options.panel_rect().position.x, expected_options, 1.0,
		("the Options paper centres live -- PANEL's x was %.0f, which is the same sum "
			+ "with 1152 already substituted in") % OptionsScreen.PANEL.position.x)
	if err == "":
		var row: Control = options.get_node_or_null("RowButton0") as Control
		err = _T.assert_true(row != null, "the Options screen drew its first row button")
		if err == "":
			err = _T.assert_float_eq(row.position.x,
				options.panel_rect().position.x + OptionsScreen.BUTTON_X, 1.0,
				"and its rows travelled with the paper")
	if err == "":
		var back: Button = options.back_button()
		err = _T.assert_true(back != null and absf(back.position.x
			- (options.panel_rect().position.x + OptionsScreen.NAME_X)) <= 1.0,
			"and so did the footer")
	_T.free_ui(options)
	if err != "":
		return err

	# The recorded exception. NotebookScreen's content is in ABSOLUTE viewport
	# coordinates (PAGE_SPLIT, LEFT_CENTRE, RIGHT_CENTRE, BACK_AT) rather than as
	# offsets from its paper, so centring the paper alone would slide it out from
	# under all of them. Asserted so the exception is a decision on the record and
	# not something rediscovered from a screenshot.
	var notebook := await _T.instantiate_ui(NotebookScreen.new(), wide) as NotebookScreen
	err = _T.assert_float_eq(notebook.panel_rect().position.x, NotebookScreen.PANEL.position.x, 0.5,
		("the Notebook is still design-centred on purpose -- its content constants are "
			+ "absolute viewport coordinates. Converting them to paper-relative offsets "
			+ "is what lets this join the other two."))
	_T.free_ui(notebook)
	return err


## The row budgets did NOT go live, and that is the point of the split.
##
## `stretch/aspect="expand"` never yields a canvas SMALLER than the design size on
## either axis, so the design size is the WORST CASE a budget has to survive and a
## ceiling measured against it holds on every window. Measured against the live
## height instead, `OptionsScreen.rows_capacity()` would report 6 at 16:9, 8 at
## 4:3, and something near 17 in a headless run -- where the root window is 64x64
## and `expand` scales it to a 1152x1152 canvas. A tripwire that relaxes on the
## machine running the suite is worse than no tripwire.
##
## So "six rows is the last count that fits a 648-tall viewport" survives this
## bead unchanged, and means what it always meant: six is the last count that fits
## the SMALLEST canvas this game can be shown on.
func test_the_row_budgets_do_not_follow_the_window() -> String:
	var options_before: int = OptionsScreen.rows_capacity()
	var keys_before: float = KeyBindingScreen.panel_height()
	var menu_before: int = TitleScreen.menu_capacity()

	# Hosted on a canvas half again as TALL as the design one. Every one of these
	# is static and reads the design height, so nothing here may move.
	var tall := Vector2i(1152, 972)
	var options := await _T.instantiate_ui(OptionsScreen.new(), tall) as OptionsScreen
	var err: String = _T.assert_eq(OptionsScreen.rows_capacity(), options_before,
		("rows_capacity() moved to %d on a 972-tall canvas. It is a budget against the "
			+ "SMALLEST canvas this game can be shown on and must not relax on a taller "
			+ "window -- least of all in the headless suite, whose canvas is taller still")
			% OptionsScreen.rows_capacity())
	if err == "":
		# The shipped ceiling, in the same check that proves it is fixed: six rows.
		# `test_every_row_limited_surface_is_exactly_full` owns the spare count; this
		# owns the claim that the number is a constant of the design.
		err = _T.assert_eq(options_before, 6,
			"six rows is the last count that fits 648, unchanged by the live viewport")
	if err == "":
		# The panel is still sized from its rows against the design height, so it
		# fits inside the DESIGN canvas -- which is the narrow case, not this one.
		err = _T.assert_gte(float(ScreenMetrics.design_height()), options.panel_rect().end.y,
			"and the Options paper still foots inside the 648 it is budgeted against")
	_T.free_ui(options)
	if err != "":
		return err

	var keys := await _T.instantiate_ui(KeyBindingScreen.new(), tall) as KeyBindingScreen
	err = _T.assert_float_eq(KeyBindingScreen.panel_height(), keys_before, 0.001,
		"the Keys panel height is derived from its rows, not from the window it is shown in")
	if err == "":
		err = _T.assert_gte(float(ScreenMetrics.design_height()), keys.panel_rect().end.y,
			"and it still foots inside the 648 its nine-verb ceiling is written against")
	_T.free_ui(keys)
	if err != "":
		return err

	var title := await _T.instantiate_ui("res://game/title.tscn", tall) as TitleScreen
	err = _T.assert_eq(TitleScreen.menu_capacity(), menu_before,
		("menu_capacity() moved to %d on a taller canvas. Its ceiling is the horizon of a "
			+ "648-tall composition; a menu budget that grows with the window is not a budget")
			% TitleScreen.menu_capacity())
	if err == "":
		err = _T.assert_gt(menu_before, TitleScreen.MENU_BUTTON_NAMES.size(),
			"and there is still room in it")
	_T.free_ui(title)
	return err


## `button_column()` reports the column that is actually DRAWN -- the drift the
## live viewport could have introduced and did not.
##
## `button_rect()` is static and places the menu at the DESIGN centre, because
## `TitleScreen.PLANT_X` is a list of hand-placed lawn slots in design coordinates
## and `test_the_title_lawn_clears_the_button_column_and_the_horizon` compares the
## two. Had `button_column()` taken the live width when `get_viewport_width()` did,
## its centre would move to 768 on a 1536 canvas while the lawn stayed at 576: the
## reported column would drive straight through the plants, and the test guarding
## the clearance would be measuring a column nobody can see.
##
## That is the whole argument for why a fixed composition wants CENTRING rather
## than a live number substituted into each of its constants.
func test_the_title_button_column_reports_the_column_that_is_drawn() -> String:
	var title := await _T.instantiate_ui("res://game/title.tscn", Vector2i(1536, 648)) as TitleScreen
	var err: String = _T.assert_true(title != null, "the title screen hosts on a 1536-wide canvas")
	if err != "":
		return err
	# The screen really is on the wider canvas -- otherwise everything below is
	# a test of the design case wearing a wide-canvas label.
	err = _T.assert_eq(title.get_viewport_width(), 1536,
		"and it reads the live width, so this is not the design case in disguise")
	if err == "":
		err = _T.assert_eq(TitleScreen.viewport_width(), 1152,
			"while viewport_width() still answers the composition question")
	var column: Vector2 = Vector2.ZERO
	if err == "":
		column = title.button_column()
		var drawn: Rect2 = TitleScreen.button_rect(0, TitleScreen.MENU_BUTTON_NAMES.size())
		err = _T.assert_float_eq(column.x, drawn.position.x, 0.5,
			("button_column() reports %.0f..%.0f but the primary button is drawn at %.0f. "
				+ "A report of a column nobody can see is what the lawn clearance test "
				+ "would then be checking against") % [column.x, column.y, drawn.position.x])
		if err == "":
			err = _T.assert_float_eq(column.y, drawn.end.x, 0.5, "and its right edge")
	if err == "":
		# The invariant that report exists to protect, re-checked on the wide canvas
		# where the drift would have shown. Not a duplicate of the placement suite's
		# version: that one runs at the design size, where the bug is invisible.
		var slots: int = TitleScreen.lawn_plants().size()
		err = _T.assert_gt(slots, 0, "there are lawn slots to check -- an empty lawn passes everything")
		for slot: int in range(slots):
			if err != "":
				break
			var span: Vector2 = TitleScreen.plant_span(slot)
			if span.y > column.x and span.x < column.y:
				err = _T.assert_false(true,
					"lawn slot %d spans %.0f..%.0f and runs into the button column %.0f..%.0f"
						% [slot, span.x, span.y, column.x, column.y])
	_T.free_ui(title)
	return err


# --- BEGIN plant-tower-defense-nj7w / -wy2v: the project's own devtools verbs ---
#
# These reach res://devtools_ext/commands.gd WITHOUT a running game, which is the
# only reason they can live here at all. Every handler below refuses on the
# caller's own arguments BEFORE it looks for a Game, so the refusal path runs with
# `_dev` left null and never touches a tree. Anything past that point (the plant
# actually landing, the pest actually spawning) is a live-bridge question and stays
# one -- see the /verify Phase 4 list.
#
# DEVTOOLS_EXT is NOT redeclared here: this suite already declares it near the top
# (the devtools-bridge tests use it). The lane that appended this block did declare
# its own copy, git merged the two blocks cleanly, and GDScript refused the file
# outright -- "Constant DEVTOOLS_EXT has the same name as a previously declared
# constant", which took the whole suite from 746 discovered tests to 375. Two lanes
# adding the same const to one file is a collision no parallel-safe gate can see.

## The project verbs whose entire effect IS an argument, and the keys they need.
## Cross-checked below against the register_command() calls in the file itself, so a
## verb added later fails this test until somebody has classified it as one of these
## or as deliberately defaulted.
const POSITIONAL_VERBS := {
	"place_plant": ["x", "y"],
	"upgrade_plant": ["x", "y"],
	"collect_husk": ["x", "y"],
}

## The rest: verbs that read no arguments, or whose defaults are the value a person
## means by leaving the key out. The reasoning for each is written next to _require()
## in commands.gd; this list only has to stay complete.
const DEFAULTED_VERBS := [
	"game_state", "spawn_pest", "add_seeds", "start_wave", "buy_packet",
	"board_info", "compost_state", "budgets", "project_identity",
	# `messages` reads no args at all: it reports the row's whole state and all four
	# counters in one call, and there is no subset of that worth asking for separately.
	# Same reason `budgets` is here -- a verb that exists so you need not know the names
	# must not require you to know a name.
	"messages",
]


## Every name passed to _dev.register_command() in commands.gd, read out of the
## source. Derived rather than transcribed on purpose: a hand-typed verb list is a
## list that silently stops being the set of verbs the moment one is added.
func _registered_project_verbs() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var file: FileAccess = FileAccess.open(DEVTOOLS_EXT, FileAccess.READ)
	if file == null:
		return out
	for line: String in file.get_as_text().split("\n"):
		var trimmed: String = line.strip_edges()
		if not trimmed.begins_with("_dev.register_command(\""):
			continue
		var rest: String = trimmed.substr(trimmed.find("\"") + 1)
		var close: int = rest.find("\"")
		if close > 0:
			out.append(rest.substr(0, close))
	file.close()
	return out


## A positional verb with no position is not a call anyone meant.
##
## plant-tower-defense-nj7w, from [G-069]. The bus ignores a key a handler does not
## read -- correct for an optional key, wrong for `place_plant`, which would take
## `int(args.get("x", 0))` and plant, successfully, at cell (0, 0). The mistake then
## surfaces several verbs downstream as a game that will not behave.
##
## Asserted in both directions: every classified verb is one the file registers, and
## every verb the file registers is classified -- so this fails on a NEW verb rather
## than quietly covering the three that happened to be here when it was written.
func test_every_positional_devtools_verb_refuses_a_call_with_no_position() -> String:
	var registered: PackedStringArray = _registered_project_verbs()
	var err: String = _T.assert_gt(registered.size(), 0,
		"the register_command() calls in %s are readable -- an empty list passes everything below"
			% DEVTOOLS_EXT)
	if err != "":
		return err
	for verb: String in registered:
		if err != "":
			break
		err = _T.assert_true(POSITIONAL_VERBS.has(verb) or DEFAULTED_VERBS.has(verb),
			("commands.gd registers '%s' and this test does not classify it. Decide which it "
				+ "is: a verb whose effect IS an argument goes in POSITIONAL_VERBS and gets a "
				+ "_require() guard, one with a deliberate default goes in DEFAULTED_VERBS and "
				+ "gets its reason written next to _require()") % verb)
	if err == "":
		err = _T.assert_eq(registered.size(), POSITIONAL_VERBS.size() + DEFAULTED_VERBS.size(),
			("this test classifies %d verbs but commands.gd registers %d -- a classified verb "
				+ "that no longer exists is a guard nobody is checking")
				% [POSITIONAL_VERBS.size() + DEFAULTED_VERBS.size(), registered.size()])
	if err != "":
		return err

	# No tree, no Game, `_dev` left null: the guard runs before any of that is
	# touched, and the fact that this works at all is what makes it testable here.
	var ext: RefCounted = load(DEVTOOLS_EXT).new()
	for verb: String in POSITIONAL_VERBS.keys():
		if err != "":
			break
		# Built into a variable rather than concatenated in the call: name_check reads
		# a literal first argument to call() as a method name and reports the prefix
		# as unresolved.
		var handler: String = "_cmd_%s" % verb
		var reply: Variant = ext.call(handler, {})
		err = _T.assert_true(reply is Dictionary,
			"_cmd_%s({}) answered a Dictionary rather than dying inside its own reply" % verb)
		if err != "":
			break
		var body: Dictionary = reply as Dictionary
		err = _T.assert_false(bool(body.get("success", true)),
			"%s with no arguments is refused rather than acted on with defaults" % verb)
		if err != "":
			break
		var message: String = str(body.get("message", ""))
		# The empty-message case is the one that cost the time in cycle 101: a reply
		# that says only `success: false` reads exactly like the game refusing.
		err = _T.assert_gt(message.length(), 0,
			"%s's refusal says something -- an empty message is indistinguishable from a "
				% verb + "game-level refusal")
		for key: String in POSITIONAL_VERBS[verb]:
			if err != "":
				break
			err = _T.assert_true(message.contains(key),
				("%s's refusal names the key it wanted ('%s'); it said: %s")
					% [verb, key, message])
		if err == "":
			err = _T.assert_true(message.contains(verb),
				"%s's refusal names the verb, so it is readable out of a log: %s" % [verb, message])
	if err == "":
		# The other direction, or the whole thing passes by refusing everything: a
		# complete call is NOT refused. Asserted on the guard itself, because acting
		# on a complete call needs a Game and this suite has none.
		err = _T.assert_eq(
			str(ext._require({"x": 2, "y": 3}, PackedStringArray(["x", "y"]), "place_plant", "z")),
			"", "a call carrying every required key is not refused")
	return err


## A handler must not die inside its own reply.
##
## plant-tower-defense-wy2v. `mutations` used to be `args.get("mutations", []) as
## Array`, and the arguments arrive as parsed JSON -- so `mutations: "winged"`, one
## letter from the singular key beside it, cast to null and the `for` over it was a
## runtime error INSIDE the handler. The bus renders that as `success: false` with an
## empty message, which reads exactly like the game refusing the spawn; that
## mis-reading is what cycle 101 lost its time to on `upgrade_plant`.
##
## What this asserts is the narrow, checkable half: the handler ANSWERS. A reply that
## comes back at all, saying which key was wrong, is the whole difference between the
## two outcomes. Reached with no Game because spawn_pest validates its arguments
## before it looks for one.
func test_spawn_pest_answers_a_bad_mutations_argument_instead_of_dying_in_its_reply() -> String:
	var ext: RefCounted = load(DEVTOOLS_EXT).new()
	# A String, a Dictionary and a number: three JSON shapes that `as Array` turns
	# into null, and the first of them ("winged") is the plausible typo -- the
	# singular key beside it takes exactly that value.
	var wrong_shapes: Array = ["winged", {"winged": true}, 3]
	var err: String = _T.assert_gt(wrong_shapes.size(), 0,
		"there are wrong shapes to try -- an empty list passes this test for free")
	for shape: Variant in wrong_shapes:
		if err != "":
			break
		var asked: Variant = ext._wanted_mutations("", shape)
		err = _T.assert_true(asked is Dictionary,
			("_wanted_mutations answered for mutations=%s rather than dying. A null here is "
				+ "the handler dying while building its reply, which the bus renders as "
				+ "success:false with an empty message") % [shape])
		if err != "":
			break
		var body: Dictionary = asked as Dictionary
		var refusal: String = str(body.get("refusal", ""))
		err = _T.assert_gt(refusal.length(), 0,
			"mutations=%s is refused rather than quietly treated as no mutations at all"
				% [shape])
		if err == "":
			err = _T.assert_true(refusal.contains("mutations"),
				"and the refusal names the key it objected to; it said: %s" % refusal)
	if err == "":
		# The other direction, without which the above passes by refusing everything.
		var good: Dictionary = ext._wanted_mutations("", ["winged", "hungry"])
		err = _T.assert_eq(str(good["refusal"]), "", "a well-formed array is not refused")
		if err == "":
			err = _T.assert_eq((good["mutations"] as Array).size(), 2,
				"and both names survive the parse")
	if err == "":
		# The singular shorthand, which is what every existing script sends.
		var single: Dictionary = ext._wanted_mutations("winged", [])
		err = _T.assert_eq(str(single["refusal"]), "",
			"`mutation` with no `mutations` at all is still a well-formed call")
		if err == "":
			err = _T.assert_eq((single["mutations"] as Array).size(), 1,
				"and it yields the one mutation asked for")
	return err

# --- END plant-tower-defense-nj7w / -wy2v ---


# -- BEGIN plant-tower-defense-iljz --------------------------------------------
#
# Two guards in game.gd lost `and _uproot_left > 0.0` this cycle -- arm_uproot's
# already-armed branch and uproot_armed() -- for the reason _update_preview lost the
# same half before them: the second condition could not disagree with the first, and a
# condition that cannot disagree is dead code with a confident comment on it. The
# acceptance for that bead is that anything removed leaves its invariant as a test.
#
# The runtime half already exists: test_placement.gd's
# test_the_uproot_window_leaves_nothing_armed_behind_it drives both exit paths and
# asserts the reference AND the clock are clear after each. What it cannot say is
# that a FUTURE writer will keep them together -- it asserts the state after the two
# paths that exist today, and the guards were removed on the strength of a claim about
# every path there will ever be. That claim is structural, so this is a source check.
#
# Absence-shaped on purpose (plant-tower-defense-qewq is the other half of this
# cycle): it does not assert that the three known writers are present -- which a
# fourth, broken one would satisfy -- it asserts that NO function writes one of the
# pair without the other going with it.


## The invariant the two removed guards rest on: an open uproot window is exactly a
## non-null `_uproot_armed`, because the reference and the clock are always written
## TOGETHER -- `_uproot_armed = X` and `_uproot_left = Y` on adjacent lines of code,
## in both of the two functions that set either.
##
## Adjacency and not "somewhere in the same function", which was this check's first
## draft and was too weak to matter. `arm_uproot` both opens a window AND calls
## `_disarm_uproot()` in its already-armed branch, so a per-function rule with a
## `_disarm_uproot()` escape hatch forgave deleting `_uproot_armed = selected_placed`
## from it -- the exact regression the two simplified guards would let through.
## Adjacency kills that, and kills a new function that starts the clock on its own.
##
## The decrement in `_tick_uproot_confirm` is not an assignment and is deliberately
## outside the rule: it narrows a window that is already open and hands the close-out
## to `_disarm_uproot()`, which writes both.
func test_the_uproot_clock_is_never_written_without_the_arming() -> String:
	var src: String = _code_only(FileAccess.get_file_as_string("res://game/game.gd"))
	var err: String = _T.assert_gt(src.length(), 0,
		"game.gd is readable -- every check below is vacuous against an empty string")
	if err != "":
		return err

	# A fresh Game is not armed AND has no clock running. Asserted separately because
	# the declarations sit outside the pairing rule below -- a default of 4.0 there
	# would pass the whole sweep.
	err = _T.assert_true(src.contains("var _uproot_left: float = 0.0"),
		"the clock starts at zero, so a Game that has never armed anything is not"
			+ " holding an open window")
	if err == "":
		err = _T.assert_true(src.contains("var _uproot_armed: Plant = null"),
			"and nothing starts armed")
	if err != "":
		return err

	# `=` and not `==`: `_uproot_armed == selected_placed` is a read, and counting it
	# as a write would let the guard that only compares them satisfy the rule. The
	# clock's plain-assignment form is separate from its `-=` form for the reason in
	# the header.
	var clock_set := RegEx.create_from_string("_uproot_left\\s*=[^=]")
	var clock_any := RegEx.create_from_string("_uproot_left\\s*[-+]?=[^=]")
	var arm_set := RegEx.create_from_string("_uproot_armed\\s*=[^=]")

	# Blank lines dropped, so a comment between the pair -- `_code_only` leaves an
	# empty line where one was -- does not read as the two coming apart.
	var code: PackedStringArray = PackedStringArray()
	for line: String in src.split("\n"):
		if line.strip_edges() != "":
			code.append(line)

	var writes: int = 0
	var orphans: PackedStringArray = PackedStringArray()
	for i: int in range(code.size()):
		var line: String = code[i]
		if clock_any.search(line) != null or arm_set.search(line) != null:
			writes += 1
		if line.begins_with("var "):
			continue
		var near: PackedStringArray = code.slice(maxi(0, i - 1), i + 2)
		var has_arm: bool = false
		var has_clock: bool = false
		for n: String in near:
			has_arm = has_arm or arm_set.search(n) != null
			has_clock = has_clock or clock_set.search(n) != null
		if clock_set.search(line) != null and not has_arm:
			orphans.append("the clock is set with no arming beside it: " + line.strip_edges())
		if arm_set.search(line) != null and not has_clock:
			orphans.append("the arming is set with no clock beside it: " + line.strip_edges())

	# The denominator, and the reason this cannot report clean over nothing. Five
	# writing lines today: two in arm_uproot, two in _disarm_uproot, the decrement in
	# _tick_uproot_confirm. A rename that hid all of them from the matchers would
	# otherwise read as a spotless sweep.
	err = _T.assert_gte(writes, 5,
		("only %d line(s) in game.gd write `_uproot_left` or `_uproot_armed`; five did"
			% writes)
			+ " when this was written. If the matchers stopped seeing them, the sweep"
			+ " below checked nothing, which is not the same as finding nothing")
	if err != "":
		return err
	err = _T.assert_eq(orphans.size(), 0,
		("game.gd writes the uproot pair apart: %s." % "; ".join(orphans))
			+ " That breaks the invariant arm_uproot() and uproot_armed() were"
			+ " simplified against (plant-tower-defense-iljz): an open window is"
			+ " exactly a non-null `_uproot_armed`, which holds only while the"
			+ " reference and the clock move together. Either write the two back"
			+ " onto adjacent lines, or put `and _uproot_left > 0.0` back into both"
			+ " guards and delete this test.")
	return err

# -- END plant-tower-defense-iljz ----------------------------------------------

# -- BEGIN plant-tower-defense-i5ny / -rq94: the top bar's one readout table ----
# Appended as a block on purpose: a sibling lane also appends here, and a clearly
# delimited section is what makes the conflict resolvable by keeping both rather
# than by picking one. Nothing above this line was touched.


## The four readouts are described ONCE, and everything that used to be a separate
## hand-list now reads that one description.
##
## Three lists became one in cycle 108. The two assertions cycle 51 bolted across the
## gaps between them are gone, because the gaps are gone -- `_build_top_bar` walks it,
## so a Label in the row that no row describes cannot be built, and `stats_row_budget`
## sums the table, so a readout's width cannot be missing from the sum. What is left
## to check is the one thing the structure does not make true by itself: that
## `WORST_CASE_TEXT` really is the projection it claims to be, and that the widths the
## budget spends are the widths the table declares.
func test_the_stats_row_is_described_by_one_table() -> String:
	var rows: Array[Dictionary] = Hud.STAT_READOUTS
	# The row count first. A sweep over an empty table asserts nothing and prints
	# [VACUOUS]; four is the row this bar has, and a fifth is a deliberate change.
	var err: String = _T.assert_eq(rows.size(), 4,
		"the top bar declares its four readouts in Hud.STAT_READOUTS")
	if err != "":
		return err
	var widths: float = 0.0
	for readout: Dictionary in rows:
		if err != "":
			break
		var name: String = String(readout.get("name", ""))
		err = _T.assert_true(name != "", "every row names its Label")
		if err == "":
			err = _T.assert_true(String(readout.get("member", "")) != "",
				"%s names the field _build assigns it to" % name)
		if err == "":
			err = _T.assert_true(String(readout.get("worst_case", "")) != "",
				"%s declares a worst case" % name)
		if err == "":
			err = _T.assert_gt(float(readout.get("width", 0.0)), 0.0,
				"%s declares a clipped width" % name)
		if err == "":
			err = _T.assert_gt(int(readout.get("font_size", 0)), 0,
				("%s declares its own font size -- three sizes now carry the row's "
					+ "hierarchy, and STAT_READOUTS' `weight` column carries the rest "
					+ "of it (plant-tower-defense-6tmf)") % name)
		if err == "":
			var shapes: Array = readout.get("shapes", [])
			err = _T.assert_gt(shapes.size(), 0,
				("%s declares the format shapes it is assigned. "
					+ "tools/readout_shape_check.py ties this column to the real "
					+ "_x_label.text = assignments, both directions") % name)
		widths += float(readout.get("width", 0.0))
	if err != "":
		return err
	# WORST_CASE_TEXT is a projection, not a second table. If it ever stops being one,
	# the budget and test_no_readout_clips_its_own_worst_case go back to measuring a
	# row that is not the row on screen.
	err = _T.assert_eq(Hud.WORST_CASE_TEXT.size(), rows.size(),
		"WORST_CASE_TEXT carries exactly the table's readouts")
	for readout: Dictionary in rows:
		if err != "":
			break
		var name: String = String(readout["name"])
		err = _T.assert_true(Hud.WORST_CASE_TEXT.has(name),
			"WORST_CASE_TEXT projects %s" % name)
		if err == "":
			err = _T.assert_eq(String(Hud.WORST_CASE_TEXT[name]),
				String(readout["worst_case"]),
				"and projects %s's worst case unchanged" % name)
	if err != "":
		return err
	# The budget spends the table's widths and nothing else. Derived rather than
	# retyped: stats_row_budget(0) is the four slots plus the two buttons, so backing
	# the buttons out has to leave exactly the sum above.
	var spent: float = (Hud.stats_row_budget(0) - Hud.NEXT_WAVE_BUTTON_SIZE.x
		- GameSpeed.button_size().x)
	return _T.assert_float_eq(spent, widths, 0.001,
		("stats_row_budget() spends %.0fpx of readout width and the table declares "
			+ "%.0f -- the sum is derived from the table, so these can only differ if "
			+ "something else got added to it") % [spent, widths])


## The wave readout's OTHER branch, measured.
##
## WORST_CASE_TEXT holds one string per readout, and the wave readout is built from two
## base branches: "Wave  %d / %d" for the fixed campaign and the endless one, either of
## which can carry the threat suffix. The declared worst case is an instance of the
## endless branch, and STAT_READOUTS says in prose that endless is the wider of the two
## because the campaign is bounded at WaveDirector.WAVES.size() waves with a
## single-digit threat level.
##
## That prose is the claim this test turns into a number. `readout_shape_check` cannot
## make it -- it compares shapes and measures no font -- and
## `test_no_readout_clips_its_own_worst_case` cannot either, because it only ever
## measures the string the table names. Nothing was checking the branch the player
## actually sees for the whole fixed campaign.
##
## `_T.text_width`, NOT get_minimum_size(): every readout in this row sets clip_text,
## and a clipped Label reports the ~1px clip stub as its minimum, so the obvious width
## assertion passes unconditionally on exactly the labels that need checking.
func test_the_wave_readouts_finite_branch_fits_its_slot() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var label: Label = game.hud.get_node_or_null("Root/TopBar/StatsRow/WaveLabel") as Label
	var err: String = _T.assert_true(label != null, "the wave readout is in the row")
	if err != "":
		_T.free_ui(game)
		return err
	var last: int = WaveDirector.WAVES.size()
	err = _T.assert_gt(last, 0, "the fixed campaign has waves to reach the end of")
	if err == "":
		# The shape the test measures has to be the shape the table declares, or this
		# is measuring a string of its own invention. Found by name rather than by
		# index: the row order is a layout decision and this is not a layout test.
		var declared: Array = []
		for row: Dictionary in Hud.STAT_READOUTS:
			if String(row["name"]) == "WaveLabel":
				declared = row["shapes"]
		err = _T.assert_true(declared.has("Wave  %d / %d"),
			"the finite branch is declared in WaveLabel's shapes: %s" % [declared])
	if err != "":
		_T.free_ui(game)
		return err
	var slot: float = label.custom_minimum_size.x
	var finite: String = ("Wave  %d / %d   threat %d"
		% [last, last, WaveDirector.threat_level(last)])
	label.text = finite
	var finite_px: float = _T.text_width(label)
	label.text = String(Hud.WORST_CASE_TEXT["WaveLabel"])
	var declared_px: float = _T.text_width(label)
	err = _T.assert_gt(finite_px, 0.0, "the finite branch measures something")
	if err == "":
		err = _T.assert_true(finite_px <= slot,
			("the last fixed wave renders \"%s\", which needs %.0fpx of a %.0fpx slot. "
				+ "The declared worst case is a different branch, so nothing else in "
				+ "the suite measures this one") % [finite, finite_px, slot])
	if err == "":
		err = _T.assert_true(declared_px >= finite_px,
			("WaveLabel's declared worst case is the WIDER branch (%.0fpx against the "
				+ "finite branch's %.0f). That is the argument its comment in "
				+ "STAT_READOUTS makes; if it inverts, the budget is priced against "
				+ "the narrower of the two") % [declared_px, finite_px])
	_T.free_ui(game)
	return err

# -- END plant-tower-defense-i5ny / -rq94 --------------------------------------


# -- BEGIN plant-tower-defense-eupm / -r3e8 ------------------------------------
#
# Two player-facing HUD readouts, and the two things a headless suite can actually
# hold them to:
#
#   -eupm  the uproot button now prints the NET of the trade, not just the refund.
#          The wording is a pure static, so it is assertable without a HUD; the WIDTH
#          is not, so that one measures a real Button in a real theme.
#   -r3e8  the seeds readout counts to its new total instead of jumping. The count is
#          a Tween and tweens do not run headless, so the assertable part is the pure
#          value-at-time function underneath it -- the same split the record ratchet
#          on the title screen makes.


## The bead's own example, as an assertion: 12 back against a 20-seed replant is an
## 8-seed loss, and the button used to print only the 12 and leave the subtraction to a
## player on a four-second confirm timer.
func test_the_uproot_button_prints_the_net_of_the_trade() -> String:
	var err: String = _T.assert_eq(Hud.uproot_button_text(12, 20), "Uproot (+12, net -8)",
		"a losing trade prints what the round trip actually costs")
	if err == "":
		err = _T.assert_eq(Hud.uproot_net(12, 20), -8,
			"and the arithmetic under it is the subtraction, not the refund")
	if err == "":
		# The free starter. `SeedBank.placement_cost` returns 0 while it is unspent, so
		# the round trip is pure profit -- a case a "replant costs N" label would have
		# printed as "replant 0" and a net label prints as a gain.
		err = _T.assert_eq(Hud.uproot_button_text(6, 0), "Uproot (+6, net +6)",
			"a profitable trade prints a leading + rather than a bare number")
	if err == "":
		# The two directions must be distinguishable with the colour thrown away
		# (game/OVERLAY_GRAMMAR.md's one rule with teeth). The sign is that channel, so
		# a profit and a loss may not render the same glyphs.
		err = _T.assert_true(Hud.uproot_net_text(6) != Hud.uproot_net_text(-6),
			"a 6-seed gain and a 6-seed loss are different strings, not different colours")
	if err == "":
		err = _T.assert_eq(Hud.uproot_button_text(10, 10), "Uproot (+10, net 0)",
			"and a break-even trade prints neither sign")
	if err == "":
		# Deliberately unchanged: once the confirm is armed the question on screen is
		# "destroy this?", and the armed string is the longest this button has ever
		# held. test_an_armed_uproot_button_relabels_and_reddens covers the render side.
		err = _T.assert_eq(Hud.uproot_armed_text(12), "Really uproot? (+12)",
			"the armed label still asks only the destructive question")
	if err == "":
		# The tooltip is where the replant PRICE survives the button's compression, so
		# it has to carry the number the label folded away.
		var tip: String = Hud.uproot_button_tooltip("Corn Cobbler", 12, 20)
		err = _T.assert_true(tip.contains("20") and tip.contains("12"),
			"the tooltip keeps both raw numbers, got \"%s\"" % tip)
	if err == "":
		# "up" alone would not do it -- every branch of this sentence opens with
		# "Digging up", so the needle has to be the clause that differs.
		var gain: String = Hud.uproot_button_tooltip("Corn Cobbler", 6, 0)
		err = _T.assert_true(gain.contains("leaves you") and not gain.contains("costs you"),
			"a profitable round trip is described as a gain, got \"%s\"" % gain)
	if err == "":
		var loss: String = Hud.uproot_button_tooltip("Corn Cobbler", 12, 20)
		err = _T.assert_true(loss.contains("costs you") and not loss.contains("leaves you"),
			"and a losing one as a cost, got \"%s\"" % loss)
	return err


## Does the longer resting label still FIT?
##
## The one question the pure test above cannot answer, and the one the bead said to
## settle before writing any text: the selection panel is 232px wide and its VBox
## already runs to within 16px of the panel foot, so a button whose minimum width
## exceeds the box widens the box and pushes the panel's contents off the side panel.
##
## Measured, and measured over the strings the game can actually BUILD rather than one
## worst case somebody typed: every catalogue price, both ends of the refund slope
## (`Plant.UPROOT_RATE_FULL` down to `MIN_UPROOT_REFUND`), and both replant prices a bed
## can quote (the catalogue cost, and 0 while the free starter is unspent).
##
## `get_minimum_size()` and not `_T.text_width` here, because this is a Button and not a
## Label: nothing clips it, and its minimum is the measurement that decides whether the
## Container grows -- which is the actual failure mode. The stylebox margins are in that
## number and are not in a bare text measurement.
func test_the_uproot_buttons_worst_case_fits_the_selection_box() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(200)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, _grass(game)), "",
		"planted, so the selection panel is on screen")
	var button: Button = game.hud.get_node_or_null(
		"Root/SidePanel/SelectionBox/UprootButton") as Button
	if err == "":
		err = _T.assert_true(button != null, "the uproot button is where the bridge presses it")
	if err != "":
		_T.free_ui(game)
		return err
	await _pump(game)
	var box: float = float(Hud.PANEL_WIDTH - 24)
	var widest: String = ""
	var widest_px: float = 0.0
	for id: StringName in PlantCatalog.ids():
		var cost: int = PlantCatalog.cost(id)
		for refund: int in [int(floor(cost * Plant.UPROOT_RATE_FULL)), Plant.MIN_UPROOT_REFUND]:
			for replant: int in [cost, 0]:
				button.text = Hud.uproot_button_text(refund, replant)
				var drawn: float = button.get_minimum_size().x
				if drawn > widest_px:
					widest_px = drawn
					widest = button.text
	# A zero measurement means no font resolved, which would let every assertion below
	# pass over a button nobody measured.
	err = _T.assert_gt(widest_px, 0.0, "the button measures something in the real theme")
	if err == "":
		err = _T.assert_true(widest_px <= box,
			("the widest resting label the catalogue can build is \"%s\", which needs "
				+ "%.0fpx of a %.0fpx box. Over it the VBox grows and the panel's "
				+ "contents leave the side panel") % [widest, widest_px, box])
	if err == "":
		# The armed branch was the previous ceiling, and it is still on screen.
		button.text = Hud.UPROOT_ARMED_WORST_CASE_TEXT
		var armed_px: float = button.get_minimum_size().x
		err = _T.assert_true(armed_px <= box,
			"the armed label \"%s\" still fits too (%.0fpx of %.0fpx)"
				% [Hud.UPROOT_ARMED_WORST_CASE_TEXT, armed_px, box])
	if err == "":
		# The declared constant has to be a real ceiling over the derived set, or the
		# next person to reason from it is reasoning from a string that undersells the
		# widest thing the button can say.
		button.text = Hud.UPROOT_WORST_CASE_TEXT
		var declared_px: float = button.get_minimum_size().x
		err = _T.assert_true(declared_px >= widest_px,
			("Hud.UPROOT_WORST_CASE_TEXT (\"%s\", %.0fpx) is meant to be at or above "
				+ "every string the catalogue can build, and \"%s\" needs %.0fpx")
				% [Hud.UPROOT_WORST_CASE_TEXT, declared_px, widest, widest_px])
	_T.free_ui(game)
	return err


## The number on the button comes off the LIVE bank, not off the catalogue.
##
## The distinction is the free starter: while it is unspent a Corn Cobbler replants for
## nothing, and a button quoting `PlantCatalog.cost` would charge a player for a bed
## they can refill free. Driven through a real placement rather than by calling the
## static, so this fails if `_refresh_selection` stops passing the bank through.
func test_the_resting_uproot_button_prices_the_replant_off_the_live_bank() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(200)
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, _grass(game)), "",
		"planted")
	var button: Button = game.hud.get_node_or_null(
		"Root/SidePanel/SelectionBox/UprootButton") as Button
	if err == "":
		err = _T.assert_true(button != null, "the uproot button is on screen")
	if err == "":
		err = _T.assert_true(game.selected_placed != null, "and the plant is selected")
	if err != "":
		_T.free_ui(game)
		return err
	var plant: Plant = game.selected_placed
	var replant: int = game.bank.placement_cost(plant.kind)
	err = _T.assert_gt(replant, 0,
		"the free starter is spent by this placement, so a replant costs something")
	if err == "":
		err = _T.assert_eq(button.text, Hud.uproot_button_text(plant.uproot_refund(), replant),
			"the resting label is the static's output for the live pair, got %s" % button.text)
	if err == "":
		err = _T.assert_true(button.text.contains("net"),
			"and the net is the thing on it, got %s" % button.text)
	if err == "":
		# The replant PRICE itself lives in the tooltip, which costs no width -- that is
		# the trade the button's compression is paid for by.
		err = _T.assert_true(button.tooltip_text.contains("%d" % replant),
			("the tooltip spells the replant price out in words, got \"%s\"")
				% button.tooltip_text)
	if err == "":
		err = _T.assert_true(button.tooltip_text.contains(
				PlantCatalog.display_name(plant.kind)),
			"and names the plant it is talking about, got \"%s\"" % button.tooltip_text)
	_T.free_ui(game)
	return err


## -r3e8. The roll itself is a Tween and `GardenTheme.animations_enabled()` is false
## headless, so a test that drove `refresh()` and watched the Label would assert nothing
## at all while looking like coverage. This asserts the pure function the Tween renders.
func test_the_seeds_roll_counts_the_whole_way_in_both_directions() -> String:
	# Endpoints exact, rather than trusting a float to land on 1.0 -- the record
	# ratchet needs a restoring callback for precisely that reason.
	var err: String = _T.assert_eq(Hud.seeds_roll_value(120, 75, 0.0), 120,
		"t=0 shows the total the player had")
	if err == "":
		err = _T.assert_eq(Hud.seeds_roll_value(120, 75, 1.0), 75,
			"t=1 shows the total they have now")
	if err == "":
		err = _T.assert_eq(Hud.seeds_roll_value(120, 75, 4.0), 75, "and t past the end clamps")
	if err == "":
		err = _T.assert_eq(Hud.seeds_roll_value(120, 75, -4.0), 120, "as does t before it")
	if err == "":
		# It has to MOVE on the first step. With floorf the readout sits on the old
		# total for the first tenth of the roll, which reads as a dropped frame.
		err = _T.assert_true(Hud.seeds_roll_value(120, 75, 0.01) < 120,
			"the count has already left the old total one frame in")
	# A SPEND, which is the case the bead was filed about: seeds go down as well as up,
	# and a roll that only climbed would animate every payout and snap every price.
	var falling: Dictionary = {}
	var previous: int = 120
	var samples: int = 0
	if err == "":
		for i: int in range(0, 101):
			var t: float = float(i) / 100.0
			var value: int = Hud.seeds_roll_value(120, 75, t)
			samples += 1
			falling[value] = true
			if value > previous:
				err = _T.assert_true(false,
					"a spend never counts back up: %d after %d at t=%.2f" % [value, previous, t])
				break
			if value < 75 or value > 120:
				err = _T.assert_true(false,
					"and never leaves its endpoints: %d at t=%.2f" % [value, t])
				break
			previous = value
	if err == "":
		err = _T.assert_eq(samples, 101, "the sweep actually ran")
	if err == "":
		# STEPPED, which is the claim SEED_ROLL_STEPS makes -- and the claim the title
		# screen's own RATCHET_STEPS states in a comment and then does not keep. A
		# hundred distinct four-digit totals in 0.35s is a flicker, not a count.
		err = _T.assert_true(falling.size() <= Hud.SEED_ROLL_STEPS + 1,
			("a 101-sample sweep of a %d-step roll showed %d distinct totals")
				% [Hud.SEED_ROLL_STEPS, falling.size()])
	if err == "":
		err = _T.assert_gt(falling.size(), 2,
			"and it is a count rather than a snap with extra frames (%d totals shown)"
				% falling.size())
	# And the same climbing, since a payout uses the identical path.
	if err == "":
		var rising: int = Hud.seeds_roll_value(20, 65, 0.5)
		err = _T.assert_true(rising > 20 and rising < 65,
			"a payout counts up through the middle too, got %d" % rising)
	return err


## The floor under the roll, and the reason it is where it is.
##
## The roll exists to make a BIG jump legible; rolling a 2-seed pest payout would put
## the busiest readout in the game in permanent motion for a change that is legible at a
## glance. The floor is only correct if it sits under every price the player can pay --
## derived off the catalogue rather than compared against a number typed twice.
func test_a_small_seed_change_snaps_and_every_real_price_rolls() -> String:
	var err: String = _T.assert_false(
		Hud.seeds_roll_is_worth_showing(40, 40 + Hud.SEED_ROLL_MIN_JUMP - 1),
		"a change one under the floor snaps, and the punch carries it alone")
	if err == "":
		err = _T.assert_true(Hud.seeds_roll_is_worth_showing(40, 40 + Hud.SEED_ROLL_MIN_JUMP),
			"a change on the floor rolls")
	if err == "":
		err = _T.assert_true(Hud.seeds_roll_is_worth_showing(40, 40 - Hud.SEED_ROLL_MIN_JUMP),
			"and it is symmetric -- a spend of the same size rolls too")
	if err == "":
		err = _T.assert_false(Hud.seeds_roll_is_worth_showing(40, 40),
			"a readout that did not move does not roll")
	if err == "":
		var cheapest: int = -1
		for id: StringName in PlantCatalog.ids():
			var cost: int = PlantCatalog.cost(id)
			if cost > 0 and (cheapest < 0 or cost < cheapest):
				cheapest = cost
		err = _T.assert_gt(cheapest, 0, "the catalogue prices something")
		if err == "":
			err = _T.assert_gte(cheapest, Hud.SEED_ROLL_MIN_JUMP,
				("the cheapest plant in the catalogue costs %d, and the roll's floor is "
					+ "%d -- above it, the purchase the roll was written for is the one "
					+ "change that snaps") % [cheapest, Hud.SEED_ROLL_MIN_JUMP])
	return err


## The rule that makes the roll safe to add at all: **the readout already holds the
## final total before anything animates.** A tween responsible for ARRIVING at the right
## value leaves the right value unreachable headless, in every test and on any machine
## with animation off -- and nothing about node paths or sizes would say so.
##
## Headless this passes because the roll never arms; that is the point. It is the check
## that fails the day someone moves the `_seeds_label.text =` assignment inside the
## tween.
func test_a_seed_change_leaves_the_readout_holding_the_final_total() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var label: Label = game.hud.get_node_or_null("Root/TopBar/StatsRow/SeedsLabel") as Label
	var err: String = _T.assert_true(label != null, "the seeds readout is in the row")
	if err != "":
		_T.free_ui(game)
		return err
	game._process(0.016)
	await _pump(game)
	var before: String = label.text
	# Comfortably over SEED_ROLL_MIN_JUMP, so a roll is armed on any machine that can
	# run one.
	game.bank.add_seeds(45)
	game._process(0.016)
	await _pump(game)
	err = _T.assert_true(label.text != before,
		"the readout moved at all, got %s both times" % label.text)
	if err == "":
		err = _T.assert_eq(label.text, "Seeds  %d" % game.bank.seeds,
			("the readout holds the FINAL total, not an interpolation step: the roll "
				+ "layers on top of a correct string and puts it back"))
	if err == "":
		# And down again, which is the direction that used to be the argument.
		var spent: int = game.bank.seeds
		# A charge, the way Game.upgrade_selected() makes one: a negative amount, which
		# the sign guard already keeps off the score.
		game.bank.add_seeds(-20)
		game._process(0.016)
		await _pump(game)
		err = _T.assert_true(game.bank.seeds < spent, "the spend landed")
		if err == "":
			err = _T.assert_eq(label.text, "Seeds  %d" % game.bank.seeds,
				"and a spend leaves the final total on the readout too")
	_T.free_ui(game)
	return err

# -- END plant-tower-defense-eupm / -r3e8 --------------------------------------


# -- BEGIN the page frame's corners are not the artifact (plant-tower-defense-twbt) --


## The board's page frame turns cleanly at every corner.
##
## plant-tower-defense-twbt reported visible artifacts around the playfield edge and
## named two suspects, asking for both to be confirmed before either was "fixed".
## Suspect 1 was: `page_edge_points()` offsets each sample along its own side's
## inward normal, so "at a corner the wobble jumps direction discontinuously instead
## of easing round", making "a visible notch or spur at all four corners".
##
## MEASURED, and it is false. Reading the real polyline out of the running game and
## taking the turn angle at every vertex:
##
##     corner (4.5, 4.5)     turn +90.0 deg   (error  0.0)
##     corner (891.5, 4.5)   turn +91.9 deg   (error +1.9)
##     corner (891.5, 571.5) turn +90.0 deg   (error  0.0)
##     corner (4.5, 571.5)   turn +91.9 deg   (error +1.9)
##     worst NON-corner turn      21.7 deg
##
## The corners are the SMOOTHEST joints on the whole outline. The wobble's own
## mid-edge turns are more than ten times larger, because a +/-2px excursion over an
## 8px sample step is inherently a ~20 degree kink and there are 360 of them. If the
## frame reads as notchy, that is the wobble everywhere, not the corners -- and it is
## PAGE_WOBBLE_PX against PAGE_SAMPLE_STEP that would have to change, which is a
## different bead about a deliberate hand-drawn look.
##
## The second half of suspect 1 -- "two round caps stack on the same point" where the
## loop closes -- is also ruled out: the closure appends the first point, which makes
## the array's first and last point equal but produces NO zero-length segment (the
## shortest is 7.99px). A degenerate segment is what would have painted a blob.
##
## This test exists so the next person who sees an edge artifact does not spend the
## afternoon on the corners again.
func test_the_page_frames_corners_turn_more_cleanly_than_its_own_wobble() -> String:
	var board_px := Vector2(float(Board.COLS * Board.CELL), float(Board.ROWS * Board.CELL))
	var inset: float = 4.5
	var pts: PackedVector2Array = Board.page_edge_points(board_px, inset)
	var err: String = _T.assert_gt(pts.size(), 100,
		"the outline is sampled densely enough to have corners to check (%d points)" % pts.size())
	if err != "":
		return err
	if err == "":
		err = _T.assert_true(pts[0] == pts[pts.size() - 1],
			"the outline closes on its own first point")
	if err == "":
		# Dropping the duplicated closing point: left in, it is a zero-length segment
		# whose direction is undefined, and every angle through it reads as garbage.
		# That artefact of the MEASUREMENT is what made the corner look broken the
		# first time it was measured.
		var closed: PackedVector2Array = pts.slice(0, pts.size() - 1)
		var n: int = closed.size()
		var nominal: Array[Vector2] = [
			Vector2(inset, inset),
			Vector2(board_px.x - inset, inset),
			Vector2(board_px.x - inset, board_px.y - inset),
			Vector2(inset, board_px.y - inset),
		]
		var corner_worst: float = 0.0
		var corner_indices: Array[int] = []
		for want: Vector2 in nominal:
			var best: int = 0
			var best_d: float = INF
			for i: int in n:
				var d: float = closed[i].distance_to(want)
				if d < best_d:
					best_d = d
					best = i
			corner_indices.append(best)
			corner_worst = maxf(corner_worst, absf(_turn_degrees(closed, best) - 90.0))
		err = _T.assert_gt(5.0, corner_worst,
			("every corner turns within 5 degrees of a square right angle (worst %.1f)."
				+ " If this ever fails, the corner really has become discontinuous and"
				+ " twbt's suspect 1 has finally come true") % corner_worst)
		if err == "":
			var mid_worst: float = 0.0
			for i: int in n:
				if corner_indices.has(i):
					continue
				mid_worst = maxf(mid_worst, absf(_turn_degrees(closed, i)))
			err = _T.assert_gt(mid_worst, corner_worst,
				("and the wobble's own mid-edge kinks are LARGER than the corners'"
					+ " (%.1f against %.1f) -- which is why the corners are not the"
					+ " artifact") % [mid_worst, corner_worst])
	if err == "":
		var shortest: float = INF
		for i: int in range(pts.size() - 1):
			shortest = minf(shortest, pts[i].distance_to(pts[i + 1]))
		err = _T.assert_gt(shortest, 0.001,
			("no zero-length segment, so the two round line caps cannot stack into a"
				+ " blob at the seam (shortest %.3f px)") % shortest)
	return err


## Signed turn at vertex `i` of a closed polyline, in degrees. +90 is a square corner.
func _turn_degrees(closed: PackedVector2Array, i: int) -> float:
	var n: int = closed.size()
	var p: Vector2 = closed[(i - 1 + n) % n]
	var q: Vector2 = closed[i]
	var r: Vector2 = closed[(i + 1) % n]
	var d: float = rad_to_deg((r - q).angle() - (q - p).angle())
	while d > 180.0:
		d -= 360.0
	while d < -180.0:
		d += 360.0
	return d


# -- END the page frame's corners are not the artifact --


# -- BEGIN one-shots: plant-tower-defense-ei83, plant-tower-defense-q8db --------
#
# Two beads about a moment the game gets exactly ONE chance to land: a hint spent on a
# player who was looking elsewhere, and the first record a garden ever sets.


## THE GATE THAT MAKES `Hud.HINT_CARDS` A DERIVED LIST RATHER THAN A SECOND HAND-TYPED
## ONE. `RunConfig.HINTS` decides what a hint IS -- `spend_hint` refuses an id that is
## not in it -- so the card table is a lookup over that list and not a list of its own.
##
## Both directions, because each catches a different mistake: an id in HINTS with no
## card is a one-shot with no route back, which is the whole defect ei83 is about; a
## card whose id is not in HINTS is a page teaching an interaction the game never
## offers, which is worse than a gap because it reads as authoritative.
func test_every_hint_has_a_notebook_card() -> String:
	var ids: Array[String] = Hud.hint_ids()
	var err: String = _T.assert_gt(ids.size(), 0,
		"there are hints to card at all -- an empty list would pass every loop below")
	if err == "":
		err = _T.assert_eq(ids.size(), RunConfig.HINTS.size(),
			"hint_ids() is RunConfig.HINTS and not a private copy of it")
	for i: int in ids.size():
		if err != "":
			break
		err = _T.assert_eq(ids[i], String(RunConfig.HINTS[i]),
			"hint %d is the one RunConfig lists in that slot" % i)
	for id: String in ids:
		if err != "":
			break
		var row: Dictionary = Hud.hint_entry(id)
		err = _T.assert_false(row.is_empty(),
			"'%s' is in RunConfig.HINTS, so it has a card to be found again by" % id)
		if err == "":
			err = _T.assert_true(Hud.hint_title(id) != id,
				"'%s' has a real title rather than falling back to its raw id" % id)
		if err == "":
			err = _T.assert_gt(Hud.hint_note_text(id, true).length(), 0,
				"'%s' has a note saying what the interaction actually is" % id)
	# The reverse sweep. A card for an id nobody can spend is a page that teaches
	# something the game has no door to.
	for row: Dictionary in Hud.HINT_CARDS:
		if err != "":
			break
		var id: String = String(row["id"])
		err = _T.assert_true(RunConfig.is_hint(id),
			"the card '%s' names an id RunConfig still calls a hint" % id)
	return err


## The bead's acceptance, as an assertion: a player who never saw the prompt can still
## learn the interaction. So the note reads IN FULL in both states -- the seen/unseen
## mark says who has read it, never what it says.
##
## And the mark is a text prefix, not a colour, which is `OVERLAY_GRAMMAR.md`'s
## two-channel rule: strip every colour off the page and an unshown row is still
## identifiable as unshown. Mirrors `NotebookScreen.shelf_note_text`, whose header
## states the same rule for the milestone shelf one screen away.
func test_a_hint_card_reads_in_full_whether_or_not_the_game_has_shown_it() -> String:
	var ids: Array[String] = Hud.hint_ids()
	var err: String = _T.assert_gt(ids.size(), 0, "there are hints to check")
	for id: String in ids:
		if err != "":
			break
		var shown: String = Hud.hint_note_text(id, true)
		var unshown: String = Hud.hint_note_text(id, false)
		# Hoisted out of the `if` blocks below on purpose: a `var` declared inside one
		# is scoped to it, and the later assertion reading it would not compile.
		var body: String = unshown.trim_prefix("Not shown yet — ")
		err = _T.assert_true(shown != unshown,
			"'%s' reads differently once the game has spent it" % id)
		if err == "":
			err = _T.assert_true(unshown.begins_with("Not shown yet — "),
				("'%s' unshown carries the prefix that survives colour being discarded,"
					+ " got '%s'") % [id, unshown])
		if err == "":
			# The half that matters: the SENTENCE is intact under the prefix, so the
			# interaction is learnable by someone the row never reached. Compared on
			# the body rather than on length, so a truncating change fails here.
			err = _T.assert_eq(body.substr(1), shown.substr(1),
				("'%s' says the same thing in both states -- only the first letter's"
					+ " case and the prefix differ") % id)
		if err == "":
			err = _T.assert_eq(shown.substr(0, 1).to_lower(), body.substr(0, 1),
				"'%s' lowercases exactly the one letter the prefix runs into" % id)
	return err


## The two renderings must not contradict each other, which is the specific risk of
## having a notebook card and a message-row tip say the same rule in different words.
##
## Asserted on the PLANTS each names, not on the strings matching: `Hud.flight_tip()`
## is written for a player watching a bug walk over a mouth and the card is written for
## a reader with no bug in front of them, so they SHOULD differ as prose. What they may
## never differ about is which plant catches a winged pest and which does not.
func test_the_hint_cards_agree_with_the_tips_the_message_row_posts() -> String:
	var tip: String = Hud.flight_tip()
	var card: String = Hud.hint_note_text("seen_flight_tip", true)
	var err: String = _T.assert_true(tip.contains("Chomp Flower") and card.contains("Chomp Flower"),
		"both name the plant that cannot take it -- tip '%s', card '%s'" % [tip, card])
	if err == "":
		err = _T.assert_true(tip.contains("Corn Cobbler") and card.contains("Corn Cobbler"),
			"and both name the plant that can -- tip '%s', card '%s'" % [tip, card])
	if err == "":
		err = _T.assert_true(tip != card,
			"while staying two sentences for two audiences rather than one pasted twice")
	if err == "":
		# The upgrade card has to name the verb the button carries, or a player who
		# reads it still does not know what to look for on the board.
		err = _T.assert_true(Hud.hint_note_text("seen_upgrade_tip", true).contains("Upgrade"),
			"the upgrade card names the button by the word printed on it")
	if err == "":
		# The move card is the one whose tip is a CLAUSE inside a longer sentence
		# (`uproot_armed_message`), so it is the one most able to drift.
		var armed: String = Hud.uproot_armed_message("Corn Cobbler", true, 0)
		err = _T.assert_true(armed.contains("Hover"),
			"the armed prompt still carries the hover clause -- '%s'" % armed)
		if err == "":
			err = _T.assert_true(Hud.hint_note_text("seen_move_tip", true).contains("hover"),
				"and the card teaches the same hover")
	return err


## THE THREE BRANCHES OF THE CARD'S SUBHEADING, asserted off a pure static so all of
## them are reachable without a save file, a played run, or a Control.
##
## The bead's complaint in one assertion: a FIRST record and a later one must not print
## the same sentence. Before this, both said "a new best" -- which is a claim about
## beating a number, and on a first record there is no number to have beaten.
func test_a_first_record_does_not_read_as_a_new_best() -> String:
	var first: String = RunSummary.score_line_at(308, true, true, 308, false)
	var later: String = RunSummary.score_line_at(308, true, false, 308, false)
	var none: String = RunSummary.score_line_at(120, false, false, 308, false)
	var err: String = _T.assert_true(first != later,
		"a first record and a later one do not print the same line -- both said '%s'"
			% first)
	if err == "":
		err = _T.assert_true(first.contains("first"),
			"the first-record line names itself as a first -- got '%s'" % first)
	if err == "":
		err = _T.assert_true(later.contains("a new best"),
			"a later record still reads as a new best -- got '%s'" % later)
	if err == "":
		err = _T.assert_true(not first.contains("a new best"),
			("and the first-record line does NOT claim a comparison that never"
				+ " happened -- got '%s'") % first)
	if err == "":
		err = _T.assert_true(none.contains("your best campaign is 308"),
			"a run that set no record still names the mode's standing best -- '%s'" % none)
	if err == "":
		# Every branch prints the seeds the run actually earned, which is the one
		# number all three share and the easiest to lose in a rewrite.
		err = _T.assert_true(first.begins_with("308 ") and later.begins_with("308 ")
			and none.begins_with("120 "),
			"all three branches lead with the run's own seed total")
	return err


## `first_record()` is the gate everything else keys off, and its DEFAULT is the half
## worth pinning: `previous_best` is a key `Game.summary_stats` does not write yet, so
## an absent one must read as "not a first" and leave the card saying what it says
## today. A 0 default would relabel every record on every card.
func test_an_absent_previous_best_is_not_read_as_a_first_record() -> String:
	var unknown := RunSummary.build({"new_record": true, "seeds_earned_total": 308})
	var err: String = _T.assert_false(unknown.first_record(),
		"a record with no previous_best in the stats is not assumed to be a first")
	if err == "":
		err = _T.assert_true(unknown.ribbon_entries().is_empty(),
			"so it grows no ribbon row either")
	unknown.free()

	var first := RunSummary.build({
		"new_record": true, "seeds_earned_total": 308, "previous_best": 0,
	})
	if err == "":
		err = _T.assert_true(first.first_record(),
			"previous_best of 0 IS the first record -- there was nothing to beat")
	first.free()

	var later := RunSummary.build({
		"new_record": true, "seeds_earned_total": 308, "previous_best": 240,
	})
	if err == "":
		err = _T.assert_false(later.first_record(),
			"and beating a real 240 is a later record, not a first")
	if err == "":
		err = _T.assert_true(later.ribbon_entries().is_empty(),
			"which earns no ribbon row -- the row is for firsts only")
	later.free()

	var lost := RunSummary.build({"new_record": false, "previous_best": 0})
	if err == "":
		err = _T.assert_false(lost.first_record(),
			("a run that set NO record is not a first record even on a garden with no"
				+ " score yet -- previous_best is 0 for both"))
	lost.free()
	return err


## The treatment itself: a first record is admitted to the ribbon, which is the surface
## this card already reserves for "what this run did for the first time ever". That is
## what makes it MORE than a later record rather than less.
func test_a_first_record_earns_a_row_on_the_ribbon_of_firsts() -> String:
	var card := RunSummary.build({
		"victory": true,
		"seeds_earned_total": 308,
		"new_record": true,
		"previous_best": 0,
		"new_milestones": ["campaign_cleared"],
	})
	var host: Node = await _T.instantiate_ui(card, Vector2i(1152, 648))
	var err: String = _T.assert_true(host != null, "the card stood up")
	if err == "":
		err = _T.assert_eq(card.ribbon_entries().size(), 2,
			"the record row and the milestone are both on the ribbon")
	if err == "":
		err = _T.assert_eq(String(card.ribbon_entries()[0]["id"]), RunSummary.FIRST_RECORD_ID,
			"with the record FIRST -- a garden opens its record book once")
	if err == "":
		var ribbon: Panel = card.get_node_or_null("MilestoneRibbon") as Panel
		err = _T.assert_true(ribbon != null, "and the ribbon was drawn")
		if err == "":
			var row: Label = ribbon.get_node_or_null(
				"Milestone_%s" % RunSummary.FIRST_RECORD_ID) as Label
			err = _T.assert_true(row != null, "carrying a titled row for the record")
			if err == "":
				err = _T.assert_gt(row.text.length(), 0,
					"whose title is real text and not an empty label")
			if err == "":
				var note: Label = ribbon.get_node_or_null(
					"MilestoneNote_%s" % RunSummary.FIRST_RECORD_ID) as Label
				err = _T.assert_true(note != null and note.text.contains("308"),
					("and a note naming the score the garden will be measured against,"
						+ " got '%s'") % ("<missing>" if note == null else note.text))
		if err == "":
			err = _T.assert_true(ribbon.get_node_or_null("Milestone_campaign_cleared") != null,
				"the milestone row is still there beside it")
		if err == "":
			err = _T.assert_float_eq(ribbon.size.y, RunSummary.ribbon_height(2), 0.5,
				"and the panel is sized for BOTH rows, not just the milestone")
	_T.free_ui(host)
	return err


## The row costs vertical budget in the side column, and this is the measurement that
## says how much is left. `_play_entrance` drops every child by RISE_OFFSET_WIN = 32, so
## the real floor on this screen is 648 - 32 = 616 rather than the viewport.
##
## Asserted against `worst_ribbon_rows()` rather than `Milestones.TABLE.size()`, which is
## the specific thing this change made wrong elsewhere: the two older clearance tests
## still measure a 7-row ribbon, and the game can now draw an 8-row one.
func test_the_widest_ribbon_this_game_can_draw_still_clears_the_rise() -> String:
	var rows: int = RunSummary.worst_ribbon_rows()
	var err: String = _T.assert_eq(rows, Milestones.TABLE.size() + 1,
		"the worst case is every milestone plus the one synthesised record row")
	if err == "":
		err = _T.assert_gt(RunSummary.ribbon_height(rows),
			RunSummary.ribbon_height(Milestones.TABLE.size()),
			"which is genuinely taller than the case the older tests measure")
	if err == "":
		var foot: float = RunSummary.RIBBON_TOP + RunSummary.ribbon_height(rows)
		err = _T.assert_true(foot <= RunSummary.MAP_LEGEND_Y,
			"the tallest ribbon foots at %.0f, above the map legend strip at %.0f"
				% [foot, RunSummary.MAP_LEGEND_Y])
	if err == "":
		# The note is pushed down by the ribbon, so it is the thing that actually
		# runs out of room first.
		var note_foot: float = RunSummary.reach_note_top(rows) + RunSummary.REACH_NOTE_HEIGHT
		var floor_y: float = 648.0 - RunSummary.RISE_OFFSET_WIN
		err = _T.assert_true(note_foot <= floor_y,
			("under the tallest ribbon the reach note foots at %.0f, inside the %.0f"
				+ " rise budget") % [note_foot, floor_y])
		if err == "":
			# The column is now FULL, and this is the assertion that says a ninth row
			# is not free -- so the next person to add one is told by a red test
			# rather than by a screenshot of a note hanging off the screen.
			var ninth: float = (RunSummary.reach_note_top(rows + 1)
				+ RunSummary.REACH_NOTE_HEIGHT)
			err = _T.assert_true(ninth > floor_y,
				("and a NINTH row would foot at %.0f, past %.0f -- this column has room"
					+ " for no more") % [ninth, floor_y])
	return err


# -- END one-shots: plant-tower-defense-ei83, plant-tower-defense-q8db ----------


# -- BEGIN the cleared line does not eat the prep window (plant-tower-defense-ifew) --


## The wave-cleared line CARRIES the forecast instead of displacing it.
##
## plant-tower-defense-ifew asked whether the cleared line's window overlaps the
## seconds a player needs for the prep note, since `_paint_message_row` gives a
## transient precedence over the standing note and the cleared line fires exactly
## when the forecast becomes relevant. It told us to measure before deciding, and
## not to "fix" the precedence by inverting it.
##
## MEASURED, and the overlap is total — 6.0s of a PREP_SECONDS 18.0 window, so a
## third of it. But the premise behind the worry is false, and that is the finding:
## `Game._on_wave_cleared` builds the line as `wave_cleared_line(wave, prep_note())`,
## and `wave_cleared_line` CONCATENATES. Read off the running game:
##
##     wave 1  -> "Wave 1 cleared. Next one grows in 18 seconds."
##     wave 22 -> "Wave 22 cleared. Next one grows in 18 seconds."
##
## So for those six seconds the row says both things in one sentence, and the
## player is not choosing between them. Nothing to fix, and the precedence rule
## stays exactly as cycle 48 set it.
##
## The one way it could go wrong is `prep_note()` returning "" — the line then
## degrades to "Wave 3 cleared." with no forecast at all. It cannot today: every
## branch returns a sentence and the last is an unconditional fallback. This test
## pins that, because it is the only thing holding the verdict up.
func test_the_cleared_line_carries_the_forecast_rather_than_hiding_it() -> String:
	var note: String = "Next one grows in 18 seconds."
	var err: String = _T.assert_true(Hud.wave_cleared_line(3, note).contains(note),
		"the cleared line carries the whole prep note, not a truncation of it")
	if err == "":
		err = _T.assert_true(Hud.wave_cleared_line(3, note).begins_with("Wave 3 cleared."),
			"and still says what just happened, first")
	if err == "":
		# The degradation this verdict rests on NOT happening.
		err = _T.assert_eq(Hud.wave_cleared_line(3, ""), "Wave 3 cleared.",
			("an empty note is the one case where the forecast vanishes -- which is why"
				+ " Game.prep_note()'s unconditional fallback is load-bearing, not tidy"))
	if err == "":
		# The window is a third of the prep gap. Recorded so a change to either
		# number has to come past this sentence.
		err = _T.assert_gt(Game.PREP_SECONDS, WAVE_CLEARED_MESSAGE_SECONDS,
			("the cleared line is shorter than the prep gap it sits inside (%.1fs of"
				+ " %.1fs). If it ever outlasts the gap the forecast never gets a"
				+ " turn of its own at all") % [WAVE_CLEARED_MESSAGE_SECONDS, Game.PREP_SECONDS])
	return err


## The duration Game._on_wave_cleared passes to show_message for the cleared line.
## Recorded here rather than read, because it is a literal at that call site; if it
## becomes a constant, point this at it.
const WAVE_CLEARED_MESSAGE_SECONDS: float = 6.0


# -- END the cleared line does not eat the prep window --


# -- BEGIN what the weather is actually worth on screen (plant-tower-defense-ki5h) --


## A drought must not be quieter than rain, because only one of them asks for anything.
##
## plant-tower-defense-ki5h asked whether a drought is noticed MID-WAVE rather than
## side by side, and said the asymmetry is the argument: a drought doubles every
## plant's firing interval — a demand for more plants or better ones — while rain heals
## beds by a fraction, a gift requiring no response. Equal visual weight for unequal
## stakes.
##
## MEASURED on the running board, sampling one 40x40 patch of grass under all three
## states and converting to Rec.709 luminance:
##
##     clear     0.5705
##     drought   0.6008   +5.31%    dR +0.059  dG +0.024  dB +0.008
##     rain      0.5950   +4.29%    dR -0.001  dG +0.023  dB +0.114
##
## Two findings, and the second is the one nobody expected. The weights ARE nearly
## equal — a single percentage point apart — so the bead's claim holds. But
## per-channel, RAIN IS THE LOUDER CUE: its blue excursion is nearly double the
## drought's red one. The state that needs no response is the more visible of the two.
##
## Both are also hue shifts rather than value shifts, so in greyscale they collapse to
## 5.3% against 4.3% — very nearly the same picture. What keeps them apart with colour
## discarded is not the tint at all, it is the MARKS: flat dashes for drought, slanted
## streaks for rain (`WeatherOverlay.DROUGHT_MARK_*` / `RAIN_MARK_*`). That is the
## channel doing the work, and it is worth knowing that before anyone tunes an alpha.
##
## This test does not fix the asymmetry — the bead asked for a measurement before a
## change, and which way to close it is a taste call about a board nobody has played
## under drought. It pins the ORDERING that any fix has to respect.
func test_a_drought_is_never_a_quieter_cue_than_rain() -> String:
	var drought_ink: float = WeatherOverlay.DROUGHT_TINT.a
	var rain_ink: float = WeatherOverlay.RAIN_TINT.a
	var err: String = _T.assert_gt(drought_ink, rain_ink * 0.999,
		("the drought tint is at least as opaque as rain's (%.3f against %.3f)."
			+ " A drought doubles every plant's firing interval and rain is a gift;"
			+ " the one that demands a response may not be the fainter mark")
			% [drought_ink, rain_ink])
	if err == "":
		# The mark channel, which is what actually survives colour being thrown away.
		# Drought's dash is SHORTER and THICKER than rain's streak — different shape,
		# not a different colour — and that difference is the whole greyscale story.
		err = _T.assert_gt(WeatherOverlay.RAIN_MARK_LENGTH,
			WeatherOverlay.DROUGHT_MARK_LENGTH,
			"rain streaks are longer than drought dashes, so the two read apart by shape")
	if err == "":
		err = _T.assert_gt(WeatherOverlay.DROUGHT_MARK_WIDTH,
			WeatherOverlay.RAIN_MARK_WIDTH,
			"and drought dashes are thicker, which is the second half of that shape difference")
	if err == "":
		# Both marks have to out-ink their own tint or the shape channel is decorative
		# and the greyscale distinction rests on a 1-point luminance gap.
		err = _T.assert_gt(WeatherOverlay.DROUGHT_MARK.a, WeatherOverlay.DROUGHT_TINT.a,
			"the drought's marks are more opaque than its wash, so shape leads colour")
	if err == "":
		err = _T.assert_gt(WeatherOverlay.RAIN_MARK.a, WeatherOverlay.RAIN_TINT.a,
			"and the same for rain")
	return err


# -- END what the weather is actually worth on screen --


## What rain's prep-note clause says it mends, as the sentence renders it.
##
## The three full-sentence goldens above compare a whole rendered label, which is the
## point of them -- word order, separators and the trailing stop are all in scope. But
## the percentage inside that sentence is a TUNABLE, and typing it three times would
## make retuning WEATHER_RAIN_HEAL_FRACTION fail three string comparisons that have
## nothing to say about the tuning. So the sentence stays hand-written and the number
## comes from the constant, which is the same split `Hud.next_wave_note` itself uses.
func _rain_mend_percent() -> int:
	return int(round(WaveDirector.WEATHER_RAIN_HEAL_FRACTION * 100.0))


# -- the seed economy has a finite floor and an uncapped ceiling (uqeo) --

## `uqeo` asked for a per-wave banked series off a live 22-wave run. That run would
## have measured ONE point on a curve whose shape is decided by two facts you can
## read off the source, and this test pins them instead:
##
##   the SINK is finite and one-time. Every seed the game can ever accept is a
##   placement, an upgrade, or a packet, and all three are bounded -- 94-odd cells,
##   a ladder on two of eight plants, seven packets to unlock the rest.
##
##   the INCOME is a rate with no cap. A Sunflower mints YIELD seeds every INTERVAL
##   seconds unconditionally, and a wave never starts until the player presses the
##   button (`can_start_wave` in Game.summary_stats), so prep time is unbounded.
##
## A finite sink meets an unbounded rate at exactly one place, and the surplus after
## it has nowhere to go. That is the design gap the bead was reaching for, and no
## amount of live play makes it more or less true. If someone adds a sink -- a third
## ladder, a consumable, a per-wave cost -- this test fails and they get to re-read
## the paragraph above rather than inheriting a stale conclusion.
func test_the_seed_sink_is_finite_while_the_seed_income_is_not() -> String:
	# Hand-built because plants are constructed in code (Game._new_plant), not from
	# scenes -- so the list is checked against the catalogue rather than trusted.
	var makers: Dictionary = {
		PlantCatalog.CORN: func() -> Plant: return CornCobbler.new(),
		PlantCatalog.CHOMP: func() -> Plant: return ChompFlower.new(),
		PlantCatalog.SUNFLOWER: func() -> Plant: return Sunflower.new(),
		PlantCatalog.SUNDEW: func() -> Plant: return StickySundew.new(),
		PlantCatalog.DANDELION: func() -> Plant: return Dandelion.new(),
		PlantCatalog.MINT: func() -> Plant: return Mint.new(),
		PlantCatalog.NETTLE: func() -> Plant: return Nettle.new(),
		PlantCatalog.ALOE: func() -> Plant: return Aloe.new(),
		PlantCatalog.BRAMBLE: func() -> Plant: return Bramble.new(),
	}
	var ids: Array[StringName] = PlantCatalog.ids()
	var err: String = _T.assert_eq(makers.size(), ids.size(),
		("this test builds one of every catalogue plant -- a new plant means a new "
			+ "row here AND a fresh look at whether it carries a sink"))
	for id: StringName in ids:
		if err != "":
			break
		err = _T.assert_true(makers.has(id), "%s has a maker in this test" % id)
	if err != "":
		return err

	# Walk every plant once: what it costs to place, and what its whole ladder costs
	# to climb. Both come off the plant itself, never a number re-listed here.
	var with_ladder: Array[String] = []
	var dearest_cell: int = 0
	for id: StringName in ids:
		var plant: Plant = (makers[id] as Callable).call()
		var ladder: Array[Dictionary] = plant.upgrade_ladder()
		var climb: int = 0
		for step: Dictionary in ladder:
			climb += int(step.get("upgrade_cost", 0))
		if climb > 0:
			with_ladder.append(String(id))
		dearest_cell = maxi(dearest_cell, PlantCatalog.cost(id) + climb)
		plant.free()

	# The floor of the whole argument: six of the nine plants cannot be improved at any
	# price. A garden of Sundews and Nettles has NO upgrade sink whatsoever.
	#
	# THE BRAMBLE MOVED, and the note it replaces is worth keeping in view. Cycle 110 wrote
	# here that the ninth plant made this argument slightly WORSE -- it had no ladder, so it
	# joined the seven, and the only sink it carried was that it is a RECURRING cost,
	# consumed by doing its job. That observation is what -4u74 was filed on and what cycle
	# 125 acted on: it now has a ladder, so it is a sink twice over, and it is the only plant
	# in the game that is.
	#
	# Its rungs buy RESISTANCE rather than health, which is why this is a real sink and not
	# just a bigger number: a heal is worth 1 / (EAT_DPS * bite_resistance()) seconds, so
	# every rung scales the Salve Aloe standing behind the wall instead of diluting it.
	with_ladder.sort()
	err = _T.assert_eq(with_ladder, ["bramble", "chomp_flower", "corn_cobbler"],
		("only three of nine plants can absorb a seed after they are placed -- the "
			+ "other six are a one-time cost and then free forever"))

	# Be generous to the sink everywhere it is in doubt: every grid cell counts as
	# buildable (the path really takes ~32 of them away), every cell holds the
	# dearest plant plus its full ladder, and every packet is bought at the top tier.
	# The conclusion has to survive the most expensive game anyone could play.
	var cells: int = Board.COLS * Board.ROWS
	var packets: int = (ids.size() - 1) * int(SeedBank.PACKET_TIERS[&"epic"]["cost"])
	var ceiling: int = cells * dearest_cell + packets
	if err == "":
		err = _T.assert_gt(ceiling, 0, "the lifetime sink is a finite number of seeds")

	# And now the rate. One Sunflower alone mints the entire generous ceiling in a
	# bounded stretch of prep, and nothing in the game asks the player to move on.
	var per_second: float = float(Sunflower.YIELD) / Sunflower.INTERVAL
	if err == "":
		err = _T.assert_gt(per_second, 0.0,
			"a Sunflower pays out on a clock, with no wave and no pest involved")
	if err == "":
		var minutes: float = float(ceiling) / per_second / 60.0
		err = _T.assert_gt(60.0 * 8.0, minutes,
			("ONE Sunflower buys out every sink the game has in %.0f minutes of "
				+ "standing still; a real garden runs a dozen of them") % minutes)
	return err


# -- END the seed economy has a finite floor and an uncapped ceiling --


# -- BEGIN should the pause door open the SELECTED plant's page (plant-tower-defense-5s99) --
#
# The bead asked a question and the answer is NO: the pause door keeps opening the
# legend, whatever is selected on the board. The five reasons live on
# `PauseScreen.notebook_door_kind()`; these four tests pin the MEASUREMENTS those
# reasons rest on, so a future session that wants to re-open the decision finds out
# from a failing test that its premises have moved rather than re-deriving them.
#
# Two of them are deliberately tripwires that fire when the codebase IMPROVES —
# test_two_of_the_catalogues_plants_have_no_spec_page_to_send_a_player_to and
# test_the_legend_is_never_one_press_from_a_plants_page. If either fails, the
# corresponding reason has expired. Re-open plant-tower-defense-5s99 and decide it
# again; do not flip the assertion.


## The door's whole behaviour, end to end, plus the half that was actually missing.
##
## `open_at` is read once during NotebookScreen's build, so this drives the real
## button rather than setting the property: a test that reached in and set `open_at`
## would prove the notebook works and say nothing about the door.
func test_the_pause_door_opens_the_legend_and_says_so_before_you_press_it() -> String:
	var total: int = NotebookScreen.PAGES.size()
	var legend: int = NotebookScreen.page_for_kind(NotebookScreen.KIND_LEGEND)
	var err: String = _T.assert_gt(legend, 0,
		"the legend is not page 0, so where this door opens is a real choice (page %d of %d)"
			% [legend + 1, total])
	if err == "":
		# The door names its destination in exactly ONE place, which is what stops the
		# tooltip and the `open_at` two functions below from drifting into two answers.
		# Asked by KIND rather than by index, so reordering PAGES moves both together.
		err = _T.assert_eq(
			NotebookScreen.page_for_kind(PauseScreen.notebook_door_kind()), legend,
			"the pause door's one named destination is the legend")
	if err == "":
		err = _T.assert_true(
			NotebookScreen.PANE_LABELS.has(PauseScreen.notebook_door_kind()),
			("and it is a kind the notebook actually has a page heading for, so the "
				+ "tooltip cannot promise a blank"))
	if err != "":
		return err

	var screen := await _T.instantiate_ui(
		PauseScreen.build("", Game.key_help()), Vector2i(1152, 648)) as PauseScreen
	var door: Button = screen.get_node_or_null("NotebookButton") as Button
	err = _T.assert_true(door != null, "the pause card has a Notebook door to press")
	if err != "":
		_T.free_ui(screen)
		return err

	# WRITTEN, per the condition this change was made under. A player pressing this
	# button from a pause lands on 13 / 14 while the identically labelled button on the
	# title screen lands on 1 / 14, and until now nothing said so — which is exactly
	# what a book that lost its place looks like.
	err = _T.assert_eq(door.tooltip_text, PauseScreen.notebook_door_tooltip(),
		"the door carries the promise, rather than the promise living only in a static")
	if err == "":
		err = _T.assert_true(door.tooltip_text.contains("%d of %d" % [legend + 1, total]),
			"and the promise names the page the door really opens at, got %s" % door.tooltip_text)
	if err == "":
		# Derived from PANE_LABELS, so the tooltip and the heading the page itself draws
		# cannot drift into describing the legend two different ways.
		err = _T.assert_true(door.tooltip_text.contains(
				NotebookScreen.pane_label_for(NotebookScreen.KIND_LEGEND)),
			"and it says what is on that page in the page's own words, got %s" % door.tooltip_text)
	if err != "":
		_T.free_ui(screen)
		return err

	door.pressed.emit()
	var page_label: Label = screen.get_node_or_null("Notebook/PageLabel") as Label
	err = _T.assert_true(page_label != null, "pressing the door actually opens a notebook")
	if err == "":
		err = _T.assert_eq(page_label.text, "%d / %d" % [legend + 1, total],
			"and it opens on the legend — the page about the board being paused behind it")
	if err == "":
		# Read through a get_node_or_null rather than a cast on a get_node: a missing node
		# would abort this method with a runtime error, and an aborted `-> String` test
		# returns "" — identical to a pass.
		var pane: Control = screen.get_node_or_null("Notebook/CueLegend") as Control
		err = _T.assert_true(pane != null and pane.visible,
			"with the legend pane showing, not merely the page number agreeing")
	_T.free_ui(screen)
	return err


## The distinguishability half the bead asked for, in the only form this design allows.
##
## The bead wanted "a plant selected, and nothing selected" driven separately, because
## a default that equals one of the two expected answers cannot be told apart from the
## property being ignored. PauseScreen has no channel to `Game.selected_placed` at all —
## `build()` takes a note and a key table — so there is no second branch to drive. What
## CAN be established, and is the same guarantee, is that the page the door opens could
## never have been produced by a selection: no plant in the catalogue owns it. The
## observed "13 / 14" above therefore means "the legend door", not "some plant's page
## that happens to be there".
func test_no_plant_selection_could_have_produced_the_page_the_pause_door_opens() -> String:
	var ids: Array[StringName] = PlantCatalog.ids()
	var legend: int = NotebookScreen.page_for_kind(NotebookScreen.KIND_LEGEND)
	var err: String = _T.assert_gt(ids.size(), 0, "there are plants that could be selected")
	if err != "":
		return err
	for id: StringName in ids:
		var page: int = NotebookScreen.page_for_plant(id)
		err = _T.assert_true(page != legend,
			("selecting %s could not have put the notebook on page %d — so the page the "
				+ "pause door opens distinguishes the legend from every possible selection")
				% [id, legend + 1])
		if err != "":
			return err
	# And the reverse reading of the same fact: the legend page is not ABOUT a plant, so
	# a door aimed at it is answering a different question from one aimed at a selection.
	return _T.assert_eq(StringName(NotebookScreen.PAGES[legend].get("plant", &"")), &"",
		"the legend page names no plant, which is why it is the run-context answer")


## REASON 1 on PauseScreen.notebook_door_kind(), pinned.
##
## `page_for_plant` finds a page for every plant — that is asserted elsewhere — but not
## every one of those pages ANSWERS "what does this plant do". `go_to()` shows the spec
## index card only on KIND_PLANT (`_spec.visible = kind == KIND_PLANT`); a KIND_DRAWING
## page shows a photograph of a pencil sketch and a note about where the idea came from.
## The two plants in that position are the free starter and the bead's own worked
## example, which is the whole reason the proposal was declined.
##
## FAILS WHEN THE CODEBASE IMPROVES, on purpose: give those two a spec page and reason 1
## has expired. Re-open the bead, do not edit this number.
func test_two_of_the_catalogues_plants_have_no_spec_page_to_send_a_player_to() -> String:
	var ids: Array[StringName] = PlantCatalog.ids()
	var err: String = _T.assert_gt(ids.size(), 0, "the catalogue has plants")
	if err != "":
		return err
	var specless: Array[String] = []
	for id: StringName in ids:
		var page: int = NotebookScreen.page_for_plant(id)
		if page < 0:
			continue
		var kind: String = String(NotebookScreen.PAGES[page].get(
			"kind", NotebookScreen.KIND_DRAWING))
		if kind != NotebookScreen.KIND_PLANT:
			specless.append("%s (page %d, kind '%s')" % [id, page + 1, kind])
	err = _T.assert_gt(specless.size(), 0,
		("at least one plant's own page carries no spec card, which is why a door aimed "
			+ "at 'the selected plant's page' is not a door aimed at 'what does this do'"))
	if err == "":
		# Named rather than merely counted: the identity is the argument. If a THIRD name
		# appears here the reason is stronger, not weaker, so this is a floor and not an
		# equality — but the two below are the ones that decided it.
		err = _T.assert_true(str(specless).contains("corn_cobbler"),
			("the free starter plant is one of them — the plant a confused player is most "
				+ "likely to have selected. Specless set: %s") % str(specless))
	if err == "":
		err = _T.assert_true(str(specless).contains("chomp_flower"),
			("and so is the Chomp, which is the bead's own worked example of a player "
				+ "wondering what a plant does. Specless set: %s") % str(specless))
	return err


## REASON 4, measured rather than assumed — the bead said to check it before assuming
## "a wrong-but-plausible page costs one press", and it does not.
##
## The pager is one page a press in each direction and there is no jump, so the price of
## landing on the wrong page is the walk. Both halves are asserted: the walk lengths off
## PAGES, and the one-page step off a real NextButton.
func test_the_legend_is_never_one_press_from_a_plants_page() -> String:
	var total: int = NotebookScreen.PAGES.size()
	var legend: int = NotebookScreen.page_for_kind(NotebookScreen.KIND_LEGEND)
	var ids: Array[StringName] = PlantCatalog.ids()
	var err: String = _T.assert_gt(ids.size(), 0, "there are plant pages to walk from")
	if err != "":
		return err
	var worst: int = 0
	for id: StringName in ids:
		var page: int = NotebookScreen.page_for_plant(id)
		if page < 0:
			continue
		# The pager wraps, so the real price is the shorter of the two directions.
		var walk: int = mini(posmod(legend - page, total), posmod(page - legend, total))
		worst = maxi(worst, walk)
		err = _T.assert_gt(walk, 1,
			("the legend is %d presses from %s's page, not one — so a door that guessed "
				+ "wrong would charge the player a walk, not a tap") % [walk, id])
		if err != "":
			return err
	err = _T.assert_gt(worst, 4,
		("the worst plant page is %d presses from the legend (of a possible %d on a "
			+ "%d-page wrap), which is the number that decided reason 4")
			% [worst, total / 2, total])
	if err != "":
		return err

	# The other half: one press really is one page. A jump control added later would make
	# the walk above cheap and reason 4 would need re-reading — this is what would say so.
	var book := await _T.instantiate_ui(NotebookScreen.new(), Vector2i(1152, 648)) as NotebookScreen
	var pager: Label = book.get_node_or_null("PageLabel") as Label
	var next_button: Button = book.get_node_or_null("NextButton") as Button
	err = _T.assert_true(pager != null and next_button != null,
		"the notebook has a pager and a Next button")
	if err == "":
		err = _T.assert_eq(pager.text, "1 / %d" % total, "it opened at the front")
	if err == "":
		next_button.pressed.emit()
		err = _T.assert_eq(pager.text, "2 / %d" % total,
			"and one press of Next moves exactly one page")
	_T.free_ui(book)
	return err


# -- END should the pause door open the SELECTED plant's page (plant-tower-defense-5s99) --


# -- budget the selection panel (plant-tower-defense-r722) ----------------------------
#
# Every constraint on the selection panel used to be prose or a hand measurement.
# Cycle 57 priced the cob's second line at "~190px of a 232px box" BY HAND, decided
# against adding text there on the strength of it, and the measurement was gone by the
# next cycle. `Hud.selection_panel_budget()` is that measurement taken by machine, over
# every line the panel can draw rather than the one line someone happened to be reading.
#
# The blind spot these checks close is not hypothetical and it is not old. Three
# `next_wave_note` goldens in this very file are plain `assert_eq` on a whole rendered
# sentence; when the rain clause lengthened this cycle, not one budget or corpus
# assertion noticed, because a golden asserts what the string SAYS and never what it
# COSTS. A panel is priced in pixels or it is not priced.


## Direction one AND direction two, which is the pair `derive-the-list` says gets
## skipped: the corpus must contain every plant and every rung the game has, and
## nothing else. A `has()`-shaped check passes with a stale ninth name in the list.
func test_the_selection_corpus_is_derived_from_the_catalogue_and_both_ladders() -> String:
	var corpus: Array[String] = Hud.selection_corpus()
	var levels: Array[String] = Hud.selection_level_names()
	var details: Array[String] = Hud.selection_detail_corpus()
	var ids: Array[StringName] = PlantCatalog.ids()
	var err: String = _T.assert_gt(ids.size(), 6,
		"the catalogue has plants to sweep (an empty sweep prices a roomy panel)")
	if err == "":
		err = _T.assert_eq(corpus.size(), ids.size() * levels.size() * details.size(),
			("the corpus is exactly the cross product -- %d plant(s) x %d rung(s) x %d "
				+ "detail(s). A size that does not multiply out means a branch was added "
				+ "to _refresh_selection that selection_corpus() never learned about")
				% [ids.size(), levels.size(), details.size()])
	if err != "":
		return err

	# Read the names back OUT of the built strings rather than trusting the loop that
	# built them: `selection_line` is what the panel actually calls, so this is the
	# only reading that says the corpus and the panel agree on the shape of a line.
	var names_seen: Dictionary = {}
	var rungs_seen: Dictionary = {}
	for text: String in corpus:
		var head: String = text.split("\n")[0]
		var halves: PackedStringArray = head.split(" — ")
		names_seen[halves[0]] = true
		rungs_seen["" if halves.size() < 2 else halves[1]] = true
	var wanted_names: Array = []
	for id: StringName in ids:
		wanted_names.append(PlantCatalog.display_name(id))
	wanted_names.sort()
	var got_names: Array = names_seen.keys()
	got_names.sort()
	err = _T.assert_eq(str(got_names), str(wanted_names),
		("every display name in PlantCatalog.ids() appears in the corpus AND nothing "
			+ "else does. A name here that the catalogue no longer has is a budget "
			+ "priced against a plant that was deleted"))
	if err != "":
		return err

	var wanted_rungs: Array = levels.duplicate()
	wanted_rungs.sort()
	var got_rungs: Array = rungs_seen.keys()
	got_rungs.sort()
	err = _T.assert_eq(str(got_rungs), str(wanted_rungs),
		"and every rung, including the empty one a plant with no ladder shows")
	if err != "":
		return err

	# The half `selection_level_names()`'s own header promises: adding a third
	# upgradable plant has to move this, and this is where it says so.
	# THREE ladders since plant-tower-defense-4u74. This list is hand-written for the same
	# reason Hud.selection_level_names() is -- upgrade_ladder() is an instance virtual and
	# there is no static registry to sweep -- so a new ladder arrives here or the count
	# below fails, which is the cost of writing them down and the reason it is worth it.
	var ladders: Array = [CornCobbler.LEVELS, ChompFlower.LEVELS, Bramble.LEVELS]
	var rungs_in_game: int = 1
	for ladder: Array in ladders:
		rungs_in_game += ladder.size()
	return _T.assert_eq(levels.size(), rungs_in_game,
		("the rung list is the two ladders in the game plus the no-ladder case. A third "
			+ "ladder makes this fail, which is the cost of writing the ladders down and "
			+ "the reason it is worth paying -- there is no static registry of them"))


## Every producer's own worst case is a line the budget actually prices.
##
## The failure this catches is a producer that gains a longer form -- or a new one
## added beside these -- and never reaches the corpus, so the panel is measured against
## a set of strings it no longer draws. Naming each producer here is also what makes
## `suite_reach_check` able to see them.
func test_every_selection_detail_producer_is_priced_by_the_corpus() -> String:
	var details: Array[String] = Hud.selection_detail_corpus()
	var err: String = _T.assert_gt(details.size(), 5,
		"there are detail lines to check (an empty list would pass every `has` below)")
	if err != "":
		return err
	var top: Dictionary = CornCobbler.LEVELS[CornCobbler.LEVELS.size() - 1]
	var wanted: Array[String] = [
		Hud.corn_detail(float(top["damage"]) * float(int(top["kernels"])),
			float(top["interval"]), int(top["kernels"])),
		Hud.sunflower_detail(Sunflower.YIELD, Sunflower.INTERVAL),
		Hud.dandelion_armed_detail(Dandelion.FLUFF_MAX, Dandelion.SEED_DAMAGE),
		Hud.dandelion_regrowing_detail(Dandelion.FLUFF_MAX, Dandelion.FLUFF_MAX,
			Dandelion.REGROW_DELAY + float(Dandelion.FLUFF_MAX) * Dandelion.FLUFF_REGROW_SECONDS),
		Hud.chomp_chewing_detail(100),
		Hud.sundew_detail(WaveDirector.SIMULTANEOUS_PEST_CEILING,
			int(round(StickySundew.SLOW_FACTOR * 100.0))),
		# The two support plants (plant-tower-defense-u9zb). Both showed idle_detail() and
		# neither has ever touched a pest, so both were announcing that they were waiting
		# for one.
		Hud.mint_detail(),
		Hud.aloe_detail(),
		# The Barrier Bramble's line (plant-tower-defense-7daf), priced at the widest the
		# FORMAT allows rather than at what a Bramble shows today -- see the corpus.
		Hud.resisting_detail(999.0),
		Hud.idle_detail(),
	]
	for line: String in wanted:
		err = _T.assert_true(details.has(line),
			("the corpus prices \"%s\". A producer whose worst case is missing here is a "
				+ "line the panel draws and the budget has never measured") % line)
		if err != "":
			return err
	# And the other direction, so a detail left in the corpus after its producer was
	# deleted shows up instead of quietly widening the budget forever.
	return _T.assert_eq(details.size(), wanted.size() + CornCobbler.LEVELS.size() - 1,
		("the corpus is those %d worst cases plus the cob's remaining %d ladder rows and "
			+ "nothing more") % [wanted.size(), CornCobbler.LEVELS.size() - 1])


## The arithmetic against the two numbers hud.gd already had written down in prose:
## a two-row label foots the stack at 168, and a three-row one foots it at the panel's
## own edge. Both were comments; neither was a check.
func test_the_selection_stack_arithmetic_matches_what_hud_wrote_down() -> String:
	var room: float = Hud.selection_room_below()
	var err: String = _T.assert_float_eq(room, 184.0, 0.001,
		("the design canvas leaves 184px under SelectionBox -- 648 tall, less the 72px "
			+ "top bar, less SELECTION_BOX_Y at 392. Measured against the DESIGN size, "
			+ "not the window, so a 21:9 screen does not hand this budget free room"))
	if err != "":
		return err
	var below: Array[float] = Hud.selection_rows_below_label()
	var fixed: float = 0.0
	for row: float in below:
		fixed += float(Hud.SELECTION_SEPARATION) + row
	err = _T.assert_float_eq(fixed, 112.0, 0.001,
		("the health bar and the two buttons cost 112px of the stack, separations "
			+ "included -- 6+14, 6+40, 6+40. Rows: %s") % str(below))
	if err != "":
		return err

	var two_rows: Array[String] = [Hud.selection_line("A", "", "B")]
	var priced_two: Dictionary = Hud.selection_panel_budget(
		two_rows, Hud.SELECTION_BOX_WIDTH, room)
	err = _T.assert_eq(int(priced_two["rows"]), 2, "two short lines wrap to two rows")
	if err == "":
		err = _T.assert_float_eq(float(priced_two["label_height"]),
			Hud.SELECTION_LABEL_MIN_HEIGHT, 0.001,
			"and two rows sit under SelectionLabel's 56px floor, so the floor is the height")
	if err == "":
		err = _T.assert_float_eq(float(priced_two["stack_height"]), 168.0, 0.001,
			("which foots the stack at 168 -- the number `_build_side_panel`'s comment "
				+ "states as \"the damaged height is unchanged at 168\" and never checked"))
	if err != "":
		return err

	var three_rows: Array[String] = ["A\nB\nC"]
	var priced_three: Dictionary = Hud.selection_panel_budget(
		three_rows, Hud.SELECTION_BOX_WIDTH, room)
	err = _T.assert_eq(int(priced_three["rows"]), 3, "three lines wrap to three rows")
	if err == "":
		# Not asserted as a literal 184: the row height is a font metric, and the claim
		# worth pinning is the RELATION -- a third row is what lands the foot on the
		# panel's edge, which is what `_refresh_selection`'s comment records a draft
		# doing at window y=648 and being sent back for.
		err = _T.assert_float_eq(float(priced_three["height_left"]), 0.0, 1.0,
			("a third row lands the stack's foot on the panel's own foot, with %s px "
				+ "left of %s. That is the 648 in _refresh_selection's comment, measured")
				% [priced_three["height_left"], room])
	return err


## The invariant, over the real corpus: nothing the panel can say pushes Upgrade and
## Uproot out through the panel's foot.
##
## This is the check no per-Control pass can make. Every node involved stays inside its
## own box the whole way down -- the label grows to fit, the VBox grows to fit, the
## buttons are the size they were asked to be -- so `findings` and `validate-ui` report
## a clean panel while the Uproot button sits below the screen.
func test_no_selection_line_pushes_the_panel_buttons_out_through_its_foot() -> String:
	var corpus: Array[String] = Hud.selection_corpus()
	var priced: Dictionary = Hud.selection_panel_budget(
		corpus, Hud.SELECTION_BOX_WIDTH, Hud.selection_room_below())
	var err: String = _T.assert_true(bool(priced["measured"]),
		"the sweep resolved a font and had lines to measure")
	if err == "":
		# The denominator. A corpus of nothing prices a roomy panel and reads identically.
		err = _T.assert_eq(int(priced["physical_lines"]), corpus.size() * 2,
			("every corpus text is two physical lines, so the sweep saw %d of them -- "
				+ "a count that has drifted means a producer grew an extra newline")
				% (corpus.size() * 2))
	if err == "":
		err = _T.assert_gte(float(priced["height_left"]), 0.0,
			("the tallest thing the panel can say is \"%s\" at %d row(s); the stack foots "
				+ "%s px into %s px of panel, leaving %s. Widest single line is \"%s\" at "
				+ "%s px in a %s px box")
				% [String(priced["tallest_text"]).replace("\n", " / "), int(priced["rows"]),
					priced["stack_height"], priced["room_below"], priced["height_left"],
					priced["widest_line"], priced["widest_px"], priced["box_width"]])
	if err == "":
		# The horizontal reading is not a pass/fail -- this label wraps -- but it must be
		# REPORTED, because it is the number cycle 57 needed and lost.
		err = _T.assert_gt(String(priced["widest_line"]).length(), 0,
			"and the budget names the widest line rather than only its width")
	return err


## The proof the floor can fail. A budget nobody has watched break is a budget nobody
## has any reason to believe, and this project has shipped ones that could not.
func test_a_deliberately_worsened_selection_line_falls_through_its_floor() -> String:
	var room: float = Hud.selection_room_below()
	var corpus: Array[String] = Hud.selection_corpus()
	var clean: Dictionary = Hud.selection_panel_budget(corpus, Hud.SELECTION_BOX_WIDTH, room)
	var err: String = _T.assert_true(Game.BUDGET_FLOOR.has("hud_selection_panel"),
		"the selection panel has a declared floor to fall through")
	if err != "":
		return err
	var floor_left: float = float(Game.BUDGET_FLOOR["hud_selection_panel"])
	var as_shipped: Array[Dictionary] = [_selection_entry(clean)]
	err = _T.assert_eq(_selection_warnings(as_shipped[0]).size(), 0,
		("the build as it stands is not under its floor: %s px left against a floor of %s")
			% [clean["height_left"], floor_left])
	if err != "":
		return err

	# One line, worsened on purpose, in the shape a real edit would take: a few more
	# words on the Chomp's chew readout. It already wraps to two rows; this takes it
	# to three, which is a fourth row on the label and 25px the panel does not have.
	var worsened: Array[String] = corpus.duplicate()
	worsened.append(Hud.selection_line("Chomp Flower", "gaping maw",
		Hud.chomp_chewing_detail(100) + " Hold still, this one is nearly done."))
	var spoiled: Dictionary = Hud.selection_panel_budget(
		worsened, Hud.SELECTION_BOX_WIDTH, room)
	err = _T.assert_gt(int(spoiled["rows"]), int(clean["rows"]),
		("the worsened line really did add a row: %d -> %d")
			% [int(clean["rows"]), int(spoiled["rows"])])
	if err == "":
		err = _T.assert_gt(0.0, float(spoiled["height_left"]),
			("and the stack now foots %s px into %s px of panel -- %s px PAST it")
				% [spoiled["stack_height"], room, spoiled["height_left"]])
	if err != "":
		return err

	var lines: Array[String] = _selection_warnings(_selection_entry(spoiled))
	err = _T.assert_eq(lines.size(), 1, "and exactly one budget warns: %s" % str(lines))
	if err == "":
		# NOT `contains("hud_selection_panel")` — `_selection_warnings` filters on exactly
		# that, so asserting it here would be asking the filter whether it filtered. The
		# line has to carry somewhere to GO, which is the half a filter cannot fake.
		err = _T.assert_true(lines[0].contains("res://game/hud.gd"),
			"the warning names the file that declares the coupling: %s" % lines[0])
	if err == "":
		# The user-facing half of this whole bead: a budget that fires and says nothing
		# actionable is a budget that gets muted. It has to name the fix.
		err = _T.assert_true(lines[0].contains("Upgrade and Uproot"),
			"and says what running out costs, in nodes a person can go and look at: %s"
				% lines[0])
	return err


## `budget_regressions()` grades a SET, not an entry, and this is the wrapper that says
## so. Besides pricing what it is handed, it walks `Game.BUDGET_FLOOR` and warns about
## every floor that NOTHING in the array measured — "the floor is guarding a coupling
## that has been renamed or removed, so it is checking nothing." That is a real check
## and a good one.
##
## It also means handing it one entry produces five warnings about the other five
## budgets, correctly. The lane that wrote these tests could not run the suite, priced
## its work in a sandbox project, and asserted a bare `budget_regressions([entry])` was
## empty — which was true there and false here the moment a sixth floor joined five
## others. So: a test about ONE budget has to ask about one budget.
func _selection_warnings(entry: Dictionary) -> Array[String]:
	var mine: Array[String] = []
	for line: String in Game.budget_regressions([entry]):
		if line.contains("hud_selection_panel"):
			mine.append(line)
	return mine


## Shared with the test above: the entry `budget_entries()` would build from a priced
## sweep, so the staging and the run grade the same shape.
func _selection_entry(priced: Dictionary) -> Dictionary:
	return Game.computed_budget("hud_selection_panel",
		"Hud.SELECTION_BOX_Y against Hud.selection_room_below()", "res://game/hud.gd",
		"the selection stack's foot",
		float(priced["stack_height"]), float(priced["room_below"]), "px",
		"Hud.selection_panel_budget() over Hud.selection_corpus()",
		("a selection line wraps to an extra row, SelectionLabel grows, and the VBox pushes "
			+ "Upgrade and Uproot down through the panel's foot"),
		Game.no_budget_observations())


## The simulation against the engine. `wrapped_rows` is greedy word wrap done by hand,
## and a budget built on a wrap rule the renderer does not share is a budget measuring
## a panel that does not exist.
##
## The Label is built EMPTY and given its text last, after it is in the tree and sized:
## a Label that already holds text reports its unwrapped width as its minimum, which is
## exactly the reading that would make this agree for the wrong reason.
func test_the_wrapped_row_count_agrees_with_a_real_label() -> String:
	var label := await _T.instantiate_ui(Label.new(), Vector2i(1152, 648)) as Label
	label.add_theme_font_size_override("font_size", Hud.SELECTION_LABEL_FONT_SIZE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(Hud.SELECTION_BOX_WIDTH, 0)
	label.size = Vector2(Hud.SELECTION_BOX_WIDTH, 400)
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var err: String = _T.assert_true(font != null,
		"the probe resolved the same theme font the panel draws in")
	if err != "":
		_T.free_ui(label)
		return err

	# The reading is worthless at any other width, and a Control's size is not the test's
	# to assume: a viewport that stretched this to 1152 would wrap nothing and agree with
	# `wrapped_rows` about every string in the corpus.
	err = _T.assert_float_eq(label.size.x, Hud.SELECTION_BOX_WIDTH, 0.001,
		"the probe Label really is the panel's 232px wide")
	if err != "":
		_T.free_ui(label)
		return err

	var checked: int = 0
	var wrapped: int = 0
	for detail: String in Hud.selection_detail_corpus():
		label.size = Vector2(Hud.SELECTION_BOX_WIDTH, 400)
		label.text = detail
		await label.get_tree().process_frame
		var engine_rows: int = label.get_line_count()
		var ours: int = Hud.wrapped_rows(detail, font, font_size, Hud.SELECTION_BOX_WIDTH)
		err = _T.assert_eq(ours, engine_rows,
			("wrapped_rows and the renderer agree on \"%s\" at %s px: %d vs %d")
				% [detail, Hud.SELECTION_BOX_WIDTH, ours, engine_rows])
		if err != "":
			break
		checked += 1
		if engine_rows > 1:
			wrapped += 1
	if err == "":
		# Two denominators, because agreeing about nothing is free. The second is the
		# one that matters: if NOTHING in the corpus wraps, this test agrees with the
		# renderer only about the easy case and would pass a broken wrap rule.
		err = _T.assert_eq(checked, Hud.selection_detail_corpus().size(),
			"every detail line was compared, not an empty loop passing quietly")
	if err == "":
		err = _T.assert_gt(wrapped, 0,
			("at least one real detail line WRAPS at 232px, so the agreement above is "
				+ "about the case the budget exists for and not only about short strings"))
	if err == "":
		# And the width the budget measured is the width the harness's own measurer
		# reads off this very Label -- the two cannot drift into disagreeing.
		label.text = String(Hud.selection_panel_budget(Hud.selection_corpus(),
			Hud.SELECTION_BOX_WIDTH, Hud.selection_room_below())["widest_line"])
		await label.get_tree().process_frame
		var priced: Dictionary = Hud.selection_panel_budget([label.text],
			Hud.SELECTION_BOX_WIDTH, Hud.selection_room_below())
		err = _T.assert_float_eq(float(priced["widest_px"]), _T.text_width(label), 0.5,
			("the budget's width for \"%s\" is the one _T.text_width reads off the real "
				+ "Label -- get_minimum_size() would have reported a clip stub") % label.text)
	_T.free_ui(label)
	return err


## The wiring. A budget that measures perfectly and is never called is the failure
## `budget_regressions()`'s own orphan-floor warning was written against, from the
## other side.
func test_the_run_prices_the_selection_panel_among_its_budgets() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var entries: Array[Dictionary] = game.budget_entries(30)
	var found: Dictionary = {}
	for entry: Dictionary in entries:
		if str(entry["id"]) == "hud_selection_panel":
			found = entry
			break
	var err: String = _T.assert_gt(found.size(), 0,
		"a real run prices hud_selection_panel among its budgets")
	if err == "":
		err = _T.assert_true(bool(found["computed"]),
			"and measures it rather than reporting a hole: %s" % found.get("summary", ""))
	if err == "":
		var seen: String = str(found["observations"])
		err = _T.assert_true(seen.contains("widest line is"),
			"the reading names the widest line, which is the half cycle 57 lost: %s" % seen)
	if err == "":
		# str() on BOTH sides. `"%s" % an_array` makes GDScript read the array as the
		# argument LIST, so a three-element observations array against one %s aborts the
		# method with "not all arguments converted" -- after the assertion above it has
		# already passed, which returns "" and reports [PASS]. run_tests.py caught this;
		# run_tests.gd could not, and said ALL TESTS PASSED.
		err = _T.assert_true(str(found["observations"]).contains("vertical room left"),
			"and the vertical room, which is the half that breaks: %s"
				% str(found["observations"]))
	if err == "":
		err = _T.assert_eq(Game.budget_regressions(entries).size(), 0,
			"and the run as it stands is under no budget's floor")
	_T.free_ui(game)
	return err


# -- END budget the selection panel (plant-tower-defense-r722) ------------------------


# =============================================================================
# BEGIN plant-tower-defense-wf4i: the run summary's value column
#
# Built because -yoc2's verdict said to, and the verdict turns on one fact: these
# labels are `clip_text` with OVERRUN_TRIM_ELLIPSIS. An over-long value does not
# wrap and does not push, so its height never changes, so BUTTON_CLEARANCE -- the
# only other gate on this card -- reads a number a content regression cannot move.
# It is the one surface in the HUD family where nothing at all was watching.
# =============================================================================

## The card's widest value fits the column it is drawn into.
##
## Measured through `GardenTheme.measure` at `RunSummary.ROW_FONT_SIZE`, not through
## `get_minimum_size()`, and that is not a stylistic choice: `clip_text` makes
## `get_minimum_size()` report the clip stub at ~1px, so the obvious assertion here
## would pass unconditionally on exactly the labels it is meant to guard.
func test_the_run_summarys_widest_value_fits_its_column() -> String:
	var priced: Dictionary = RunSummary.value_column_budget()
	var corpus: Array[String] = RunSummary.summary_corpus()
	var err: String = _T.assert_gt(corpus.size(), 6,
		("the corpus carries at least one string per row (%d) -- an empty or half-built "
			+ "one makes every measurement below vacuously roomy") % corpus.size())
	if err == "":
		err = _T.assert_gt(float(priced["slot"]), 0.0,
			"the value column has a width to fit into: %s" % str(priced))
	if err == "":
		err = _T.assert_gte(float(priced["left"]), 0.0,
			("the widest value \"%s\" draws %.1f of %.1f px -- a negative here is a row "
				+ "rendering as an ellipsis, silently, because nothing on this card can "
				+ "see a string that clips instead of wrapping")
				% [String(priced["text"]), float(priced["needed"]),
					float(priced["slot"])])
	if err != "":
		return err

	# THE SLOT THE BUDGET MEASURED AGAINST IS THE SLOT THE CARD ACTUALLY DRAWS, and
	# this is the assertion that makes `value_slot_width()` worth having rather than a
	# second copy of the arithmetic. A budget whose denominator drifts from the real
	# column reports headroom the player does not have -- and it would drift silently,
	# because both numbers look plausible on their own.
	#
	# It is also what `suite_reach_check` demanded: the function was named in this
	# file ONLY inside a string literal (the budget's `constant` field), which that
	# checker refuses to count as reach, and it was right to.
	var card := RunSummary.new()
	card._stats = RunSummary.corpus_states()[0]
	var built := await _T.instantiate_ui(card, Vector2i(1152, 648)) as RunSummary
	var value: Label = built.get_node_or_null("Value_Gardenlost") as Label
	if value == null:
		# Named off the row key, so a renamed row must be noticed here rather than
		# silently skipping the comparison.
		var keys: Array[String] = []
		for row: Array in built.summary_rows():
			keys.append(String(row[0]))
		err = "no Value_Gardenlost label on the card; rows are %s" % str(keys)
	else:
		err = _T.assert_float_eq(value.size.x, RunSummary.value_slot_width(), 0.01,
			("the drawn column is %.1f px and value_slot_width() says %.1f -- the budget "
				+ "above divides by the second number and the player sees the first")
				% [value.size.x, RunSummary.value_slot_width()])
	_T.free_ui(built)
	return err


## Every corpus state actually moves every row off its default.
##
## THIS IS THE TEST THAT WOULD HAVE CAUGHT THE FIRST DRAFT. `CORPUS_STATES` began
## with invented key names (`beds_lost`, `compost_swept`, `seeds_spent_placing`)
## and every producer fell through to its default, so the corpus measured a card
## full of zeroes and reported a comfortable 118px of headroom. The tell was that
## the ALL-ZEROES control came out widest -- a worst case that loses to its own
## control is not a worst case -- and nothing but noticing that would have caught it.
##
## So: each stressing state must produce a strictly wider set of strings than the
## deliberately empty one. A renamed `_stats` key breaks that immediately.
func test_every_corpus_state_moves_every_row_off_its_default() -> String:
	var states: Array[Dictionary] = RunSummary.corpus_states()
	var err: String = _T.assert_gt(states.size(), 1,
		"there is a control state to compare the stressing ones against")
	if err != "":
		return err

	var widths: Array[float] = []
	for state: Dictionary in states:
		var card := RunSummary.new()
		card._stats = state
		var total: float = 0.0
		for row: Array in card.summary_rows():
			total += GardenTheme.measure(String(row[1]), RunSummary.ROW_FONT_SIZE)
		widths.append(total)
		card.free()

	# The LAST state is the deliberately-empty one; every other must beat it.
	var control: float = widths[widths.size() - 1]
	err = _T.assert_gt(control, 0.0, "the control state still prints something")
	for i: int in range(widths.size() - 1):
		if err != "":
			break
		err = _T.assert_gt(widths[i], control,
			("corpus state %d totals %.0f px against the empty control's %.0f -- a "
				+ "stressing state that does not beat the control is one whose _stats "
				+ "keys no longer match what the producers read, and it measures nothing")
				% [i, widths[i], control])
	return err


## A deliberately worsened phrasing falls through the floor, and says where to go.
func test_a_worsened_run_summary_value_falls_through_its_floor() -> String:
	var priced: Dictionary = RunSummary.value_column_budget()
	var err: String = _T.assert_true(Game.BUDGET_FLOOR.has("run_summary_values"),
		"the column has a declared floor to fall through")
	if err != "":
		return err

	# Six more words on the beds row, in the shape a real edit would take.
	var worsened: String = String(priced["text"]) + " and never came back at all"
	var needed: float = GardenTheme.measure(worsened, RunSummary.ROW_FONT_SIZE)
	err = _T.assert_gt(needed, float(priced["slot"]),
		("the worsened line really is too wide: %.0f against a %.0f px column")
			% [needed, float(priced["slot"])])
	if err == "":
		var entry: Dictionary = Game.computed_budget("run_summary_values",
			"RunSummary.value_slot_width()", "res://game/run_summary.gd",
			"the run summary's widest value",
			needed, float(priced["slot"]), "px",
			"RunSummary.value_column_budget()",
			"a value string is trimmed to an ellipsis mid-word",
			Game.no_budget_observations())
		var mine: Array[String] = []
		# Filtered for the same reason the selection panel's is: budget_regressions
		# grades a SET and warns about every declared floor nothing measured, so one
		# entry handed to it correctly complains about all the others.
		for line: String in Game.budget_regressions([entry]):
			if line.contains("run_summary_values"):
				mine.append(line)
		err = _T.assert_eq(mine.size(), 1, "exactly one warning is mine: %s" % str(mine))
		if err == "":
			err = _T.assert_true(mine[0].contains("ellipsis"),
				("and it says what running out LOOKS like, which is the half a player "
					+ "would otherwise have to guess: %s") % mine[0])
	return err

# END plant-tower-defense-wf4i
# =============================================================================


# =============================================================================
# BEGIN plant-tower-defense-0y0w: the packet rack, and why the rest of the panel
# is not priced
#
# The bead asked to price the side panel as "the widest column of text in the
# game — plant names, blurbs and prices". It is none of those things. The plant
# buttons are ICON-ONLY and carry their names and blurbs in `tooltip_text`, which
# is a floating popup with no slot to overflow; the heading is a literal; the
# SelectionBox is already priced by -r722. What is genuinely at risk is the packet
# rack, and only because `packet_row_rect` hands those buttons a FIXED width — a
# button that cannot grow cannot push, so no layout gate would see it overflow.
# =============================================================================

## The rack's widest label fits the button it is drawn in, and the sweep is real.
func test_the_packet_rack_label_fits_the_button_it_is_drawn_in() -> String:
	var priced: Dictionary = Hud.packet_rack_budget()
	var corpus: Array[String] = Hud.packet_rack_corpus()
	# Two states per tier, and asserted against PACKET_ORDER rather than a number,
	# so a fourth tier is priced the day it arrives instead of the day it breaks.
	var err: String = _T.assert_eq(corpus.size(), SeedBank.PACKET_ORDER.size() * 2,
		("the corpus is every tier in both stock states (%d of %d expected) -- a short "
			+ "sweep prices a rack that is not the one on screen")
			% [corpus.size(), SeedBank.PACKET_ORDER.size() * 2])
	if err == "":
		err = _T.assert_float_eq(float(priced["slot"]), Hud.packet_row_rect(0).size.x,
			0.01, "the budget measures against the rect the rack actually draws into")
	if err == "":
		err = _T.assert_gte(float(priced["left"]), 0.0,
			("the widest label \"%s\" draws %.0f of %.0f px")
				% [String(priced["text"]), float(priced["needed"]),
					float(priced["slot"])])
	return err


## A fourth tier with a long name falls through the floor — the case this exists for.
##
## Not "a price grows": the widest label is 179 of 232 px and a price would have to
## gain four digits to close that. The realistic break is a NEW TIER, which is why
## the corpus sweeps `PACKET_ORDER` instead of listing three strings.
func test_a_long_named_packet_tier_falls_through_the_racks_floor() -> String:
	var priced: Dictionary = Hud.packet_rack_budget()
	var err: String = _T.assert_true(Game.BUDGET_FLOOR.has("packet_rack"),
		"the rack has a declared floor to fall through")
	if err != "":
		return err

	# Built the way a real tier would read, not padded with filler.
	var invented: String = "Heirloom Collector's Packet (250)"
	var needed: float = GardenTheme.measure(invented, GardenTheme.BUTTON_FONT_SIZE)
	err = _T.assert_gt(needed, float(priced["slot"]),
		("a plausible fourth tier really is too wide: %.0f against a %.0f px button")
			% [needed, float(priced["slot"])])
	if err == "":
		var entry: Dictionary = Game.computed_budget("packet_rack",
			"Hud.packet_row_rect().size.x", "res://game/hud.gd",
			"the packet rack's widest label",
			needed, float(priced["slot"]), "px", "Hud.packet_rack_budget()",
			Game.PACKET_RACK_WHEN_FULL, Game.no_budget_observations())
		# Filtered: budget_regressions grades a SET and warns about every declared
		# floor nothing measured, so one entry handed to it complains about the rest.
		var mine: Array[String] = []
		for line: String in Game.budget_regressions([entry]):
			if line.contains("packet_rack"):
				mine.append(line)
		err = _T.assert_eq(mine.size(), 1, "exactly one warning is mine: %s" % str(mine))
		if err == "":
			err = _T.assert_true(mine[0].contains("cannot grow"),
				("and it says WHY nothing else would catch it, which is the whole "
					+ "reason this budget exists: %s") % mine[0])
	return err

# END plant-tower-defense-0y0w
# =============================================================================


# =============================================================================
# BEGIN plant-tower-defense-9afm — the RNG stream under the seeded simulations
#
# Four tests in `test_combat.gd` drive a seeded wave through `_over_promise_run`
# and read counts off the pests it produced. All four rest on one unstated
# assumption — that `set_seed(N)` makes the wave reproducible — and on one
# unstated hazard: that the reproduction is of the DRAW ORDER, not of the wave,
# so a draw added anywhere in `WaveDirector._build_schedule` silently hands the
# same seed a different wave.
#
# Cycle 81 met that hazard as a mysterious behavioural regression in a test about
# the coverage map, spent a cycle proving it was the stream and not the feature,
# and wrote the proof down as a paragraph. This is the paragraph as an executable
# statement. Nothing here asserts a count; both halves are about the mechanism.
#
# NO PLAYER SEES ANY OF THIS. It changes no game behaviour whatsoever — it is a
# gate under four other tests, and the reason the coverage test above it can no
# longer be broken by an unrelated RNG change.
# =============================================================================


## One string per schedule, stable under nothing but the draws.
##
## Species, spawn time and the FULL mutation list, in schedule order — the whole
## of what `_build_schedule` decides. Deliberately not a count of mutated pests: a
## reshuffle that happens to keep the count would slip past that and is exactly
## the case this is trying to catch.
func _schedule_signature(director: WaveDirector) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for entry: Dictionary in director._schedule:
		# str() around the Array on purpose: `"%s" % some_array` makes GDScript read
		# the array as the argument LIST, which aborts the method mid-run and reports
		# a pass.
		parts.append("%s|%.4f|%s" % [str(entry["species"]), float(entry["at"]),
			str(entry["mutations"])])
	return "/".join(parts)


## Builds the wave `test_the_coverage_map_keeps_its_promise_...` drives, exactly the
## way `_over_promise_run` builds it, optionally burning `waste` draws off the
## director's generator first. Burning one is what "somebody added a randf()"
## looks like from outside the function.
func _schedule_for_the_over_promise_wave(waste: int) -> String:
	var wave: int = WaveDirector.WAVES.size() + 6
	var director := WaveDirector.new()
	director.set_seed(12345)
	director.endless = wave > WaveDirector.WAVES.size()
	director.current_wave = wave - 1
	for _i: int in range(waste):
		director._rng.randf()
	director.start_next_wave()
	var signature: String = _schedule_signature(director)
	director.free()
	return signature


func test_a_seeded_wave_is_reproducible_and_one_extra_draw_reshuffles_it() -> String:
	var first: String = _schedule_for_the_over_promise_wave(0)
	var again: String = _schedule_for_the_over_promise_wave(0)
	var shifted: String = _schedule_for_the_over_promise_wave(1)

	# Vacuity guard. A wave that built nothing would make both halves below true
	# for the wrong reason — two empty signatures are equal, and an empty one and a
	# shifted empty one are not unequal.
	var err: String = _T.assert_gt(first.length(), 100,
		("wave %d built a schedule worth comparing (%d chars of signature)"
			% [WaveDirector.WAVES.size() + 6, first.length()]))
	if err == "":
		# HALF ONE: the assumption. Compared as a bool rather than through assert_eq
		# so a failure prints a sentence instead of two schedules.
		err = _T.assert_true(again == first,
			("set_seed(12345) twice built the same wave twice — every seeded simulation "
				+ "in test_combat.gd is a measurement of one wave, and this is the line "
				+ "that says which wave"))
	if err == "":
		# HALF TWO: the hazard. One draw consumed and thrown away before the wave is
		# built stands in for a draw added anywhere in _build_schedule.
		err = _T.assert_true(shifted != first,
			("and ONE extra randf() off the same generator built a DIFFERENT wave off "
				+ "the same seed. That is the whole hazard: a seed does not pin the "
				+ "wave, it pins the draw order, so any change to what WaveDirector "
				+ "consumes hands every seeded simulation a new wave. A count asserted "
				+ "off one of those waves is a measurement, not an invariant — see the "
				+ "last assertion in "
				+ "test_the_coverage_map_keeps_its_promise_to_a_pest_that_never_leaves_"
				+ "covered_ground for the shape that survives it"))
	return err

# END plant-tower-defense-9afm
# =============================================================================


# =============================================================================
# plant-tower-defense-3mhn — the Barrier Bramble, the ninth plant and the only
# one that stands on the road.
#
# Two claims are being pinned here and they fail in different places. The
# MECHANIC (every pest stops, fliers do not) lives in Pest._physics_process and
# is asserted against a pest's own position, because "did not advance" is the
# only observable that cannot be faked by a plant losing health. The PLACEMENT
# RULE (this plant on the road, nothing else, and this plant nowhere else) lives
# in Board.is_buildable_for and is asserted over the WHOLE catalogue rather than
# over the one new entry — a rule stated about one id is a rule the tenth plant
# inherits silently.
# =============================================================================


func test_a_bramble_stops_an_ordinary_pest_and_it_walks_on_once_the_wall_is_gone() -> String:
	# The headline claim, and note the pest: a plain aphid with NO mutations. Before
	# this plant the only thing that stopped one was a Chomp's mouth, and the only
	# thing that made one stop for a plant was the hungry mutation.
	var wall := Bramble.new()
	wall.setup(PlantCatalog.BRAMBLE, Vector2i(0, 0), null)
	wall.position = Vector2.ZERO
	var pest := Pest.new()
	pest.setup(Pest.APHID, PackedVector2Array([Vector2.ZERO, Vector2(600, 0)]))
	pest.set_physics_process(false)
	var host: Node2D = _host([wall, pest])
	await _T.instantiate_scene(host)

	var start: Vector2 = pest.position
	pest._physics_process(0.1)
	pest._physics_process(0.1)
	var err: String = _T.assert_eq(pest.position, start,
		"an unmutated aphid standing at a Bramble does not advance")
	if err == "":
		err = _T.assert_true(wall.health < Plant.MAX_HEALTH,
			"and it is chewing rather than merely standing still (%.2f health)" % wall.health)
	if err == "":
		# The other half, and the half a "does not advance" assertion alone would let
		# rot: a wall that is never released is a permanent barricade, which is a
		# different and much worse plant. Destroy it and step again.
		wall.health = 0.0
		pest._physics_process(0.1)
		err = _T.assert_true(pest.position.x > start.x,
			("and it walks on the moment the wall is destroyed (%.1f -> %.1f)"
				% [start.x, pest.position.x]))
	_T.free_ui(host)
	return err


func test_a_winged_pest_walks_straight_past_a_bramble() -> String:
	# The counter, and the only one. Asserted through the same position observable as
	# the test above so the pair reads as one sentence with the mutation flipped.
	var wall := Bramble.new()
	wall.setup(PlantCatalog.BRAMBLE, Vector2i(0, 0), null)
	wall.position = Vector2.ZERO
	var pest := Pest.new()
	pest.setup(Pest.APHID, PackedVector2Array([Vector2.ZERO, Vector2(600, 0)]))
	pest.apply_mutation(Pest.MUTATION_WINGED)
	pest.set_physics_process(false)
	var host: Node2D = _host([wall, pest])
	await _T.instantiate_scene(host)

	var start: Vector2 = pest.position
	pest._physics_process(0.1)
	var err: String = _T.assert_true(pest.position.x > start.x,
		"a winged pest crosses a Bramble's cell without stopping")
	if err == "":
		err = _T.assert_float_eq(wall.health, Plant.MAX_HEALTH, 0.001,
			"and does not touch it on the way over")
	if err == "":
		# The rule and the behaviour, held against each other. Bramble.stops() is what
		# the shop line promises; Pest._blocking_plant is what the board does. Asserting
		# only the predicate would pass on a game that had stopped reading it.
		err = _T.assert_false(Bramble.stops(true), "and Bramble.stops() is where that rule is written")
	if err == "":
		err = _T.assert_true(Bramble.stops(false), "while everything unwinged is held")
	_T.free_ui(host)
	return err


func test_a_bramble_is_chewed_at_a_quarter_speed_and_holds_four_times_as_long() -> String:
	# The balance claim from bramble.gd's header, made executable — and made executable
	# in the two places it can disagree with itself. BITE_RESISTANCE is the constant;
	# take_damage() is the code that has to apply it; hold_seconds() is the arithmetic
	# the header quotes. All three, or a retune moves one and leaves the other two.
	var wall := Bramble.new()
	wall.setup(PlantCatalog.BRAMBLE, Vector2i(0, 0), null)
	var ordinary := Plant.new()
	ordinary.setup(PlantCatalog.CORN, Vector2i(0, 0), null)

	wall.take_damage(10.0)
	ordinary.take_damage(10.0)
	var wall_lost: float = Plant.MAX_HEALTH - wall.health
	var ordinary_lost: float = Plant.MAX_HEALTH - ordinary.health
	var err: String = _T.assert_float_eq(wall_lost, ordinary_lost * Bramble.BITE_RESISTANCE, 0.001,
		("the same bite costs a Bramble %.2f health where it costs a cob %.2f"
			% [wall_lost, ordinary_lost]))
	if err == "":
		err = _T.assert_float_eq(Bramble.hold_seconds(1),
			Plant.seconds_to_be_eaten(Pest.EAT_DPS) / Bramble.BITE_RESISTANCE, 0.001,
			"and one pest is held exactly 1/BITE_RESISTANCE times as long as it eats a cob")
	if err == "":
		# The shape the header claims: a lot against a trickle, little against a crush.
		# Asserted as a relationship rather than as two numbers, so a retune of either
		# constant moves both sides.
		err = _T.assert_float_eq(Bramble.hold_seconds(4), Bramble.hold_seconds(1) / 4.0, 0.001,
			"four mouths get through it in a quarter of the time — a wall lengthens a lane, it does not close one")
	if err == "":
		err = _T.assert_true(is_inf(Bramble.hold_seconds(0)),
			"and nothing eating it holds forever, rather than dividing by zero")
	wall.free()
	ordinary.free()
	return err


func test_only_the_bramble_stands_on_the_road_and_it_stands_nowhere_else() -> String:
	# Over the WHOLE catalogue, both directions. The tenth plant inherits this test.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var road: Vector2i = game.board.world_to_cell(game.board.route()[2])
	var grass: Vector2i = _grass(game)
	var err: String = _T.assert_true(game.board.is_path(road), "there is a road cell to test")
	if err == "":
		err = _T.assert_true(game.board.is_buildable(grass), "and a grass cell beside it")

	var road_plants: int = 0
	for id: StringName in PlantCatalog.ids():
		if err != "":
			break
		if PlantCatalog.on_road(id):
			road_plants += 1
			err = _T.assert_true(game.board.is_buildable_for(road, id),
				"%s stands on the road" % id)
			if err == "":
				err = _T.assert_false(game.board.is_buildable_for(grass, id),
					"%s is refused on grass — a wall beside the road blocks nothing" % id)
		else:
			err = _T.assert_false(game.board.is_buildable_for(road, id),
				"%s is still refused on the road" % id)
			if err == "":
				err = _T.assert_true(game.board.is_buildable_for(grass, id),
					"%s still stands on grass" % id)
	if err == "":
		# The count PlantCatalog.on_road()'s header promises. A second road plant is a
		# decision somebody made rather than a key that drifted.
		err = _T.assert_eq(road_plants, 1,
			"exactly one plant in the catalogue stands on the road")
	if err == "":
		err = _T.assert_true(PlantCatalog.on_road(PlantCatalog.BRAMBLE), "and it is the Bramble")
	_T.free_ui(game)
	return err


func test_a_husk_on_the_road_is_swept_rather_than_planted_over() -> String:
	# The invariant _click_at's header used to rest on ("nothing may ever be planted on
	# the road") is gone, and this is the guarantee that replaced it. Drives the real
	# click path rather than compost.collect_at() directly, because the whole defect
	# lives in which of the two branches _click_at takes.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var road: Vector2i = game.board.world_to_cell(game.board.route()[2])
	game.selected_plant = PlantCatalog.BRAMBLE
	game.bank.add_seeds(PlantCatalog.cost(PlantCatalog.BRAMBLE) * 4)
	game.bank.unlocked.append(PlantCatalog.BRAMBLE)

	var err: String = _T.assert_true(game.would_plant_at(road),
		"with a Bramble selected the road cell is genuinely plantable — the precondition")
	if err == "":
		var at: Vector2 = game.board.cell_to_world(road)
		game.compost.drop_husk(at, 7)
		var seeds_before: int = game.bank.seeds
		game._click_at(at + game._entities.position)
		err = _T.assert_eq(game.bank.seeds, seeds_before + 7,
			"the click swept the husk for its 7 seeds")
		if err == "":
			err = _T.assert_eq(game.compost.husk_count(), 0, "and the husk is gone")
		if err == "":
			err = _T.assert_true(game.plant_at(road) == null,
				"and nothing was planted on top of it — the sweep wins on the road")
	if err == "":
		# The other side of the same branch: with no husk there, the click plants.
		var at: Vector2 = game.board.cell_to_world(road)
		game._click_at(at + game._entities.position)
		err = _T.assert_true(game.plant_at(road) is Bramble,
			"and a road click with nothing to sweep falls through and plants the Bramble")
	_T.free_ui(game)
	return err

# END plant-tower-defense-3mhn
# =============================================================================


# =============================================================================
# plant-tower-defense-7daf — the panel's vocabulary for toughness.
# =============================================================================


func test_a_resisting_plant_takes_exactly_the_fraction_it_declares() -> String:
	# The declaration and the code that applies it, held against each other. Either alone
	# passes on a plant that says it resists and does not, or resists and does not say so —
	# and the readout below is built entirely on the declaration, so a divergence would
	# make the panel lie rather than merely look odd.
	var wall := Bramble.new()
	wall.setup(PlantCatalog.BRAMBLE, Vector2i(0, 0), null)
	var ordinary := Plant.new()
	ordinary.setup(PlantCatalog.CORN, Vector2i(0, 0), null)

	var err: String = _T.assert_float_eq(ordinary.bite_resistance(), 1.0, 0.001,
		"a plant that does not resist declares 1.0, so the readout can ask every plant")
	if err == "":
		err = _T.assert_float_eq(wall.bite_resistance(), Bramble.BITE_RESISTANCE, 0.001,
			"and a Bramble declares its own constant")
	if err == "":
		wall.take_damage(10.0)
		err = _T.assert_float_eq(Plant.MAX_HEALTH - wall.health,
			10.0 * wall.bite_resistance(), 0.001,
			"take_damage applies exactly the fraction bite_resistance() declares")
	if err == "":
		# The seconds the panel prints, derived rather than re-listed.
		err = _T.assert_float_eq(ordinary.seconds_of_chewing_left(Pest.EAT_DPS),
			Plant.MAX_HEALTH / Pest.EAT_DPS, 0.001,
			"an ordinary plant's remaining seconds are health over the raw rate")
	if err == "":
		err = _T.assert_float_eq(wall.seconds_of_chewing_left(Pest.EAT_DPS),
			wall.health / (Pest.EAT_DPS * Bramble.BITE_RESISTANCE), 0.001,
			"and a resisting plant's go through its resistance")
	if err == "":
		err = _T.assert_true(is_inf(ordinary.seconds_of_chewing_left(0.0)),
			"nothing eating it lasts forever rather than dividing by zero")
	wall.free()
	ordinary.free()
	return err


func test_only_a_plant_that_resists_gets_the_holds_line() -> String:
	# BOTH directions. Asserting only that a Bramble shows the line would pass on a HUD
	# that showed it for everything, which is the version that makes the panel noise.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(400)
	game.bank.unlocked = PlantCatalog.ids()
	var road: Vector2i = game.board.world_to_cell(game.board.route()[2])

	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.BRAMBLE, road), "",
		"a Bramble is in the ground")
	if err == "":
		game._select(game.plant_at(road))
		game._process(0.016)
		await _pump(game)
		var label: Label = game.hud.get_node_or_null(
			"Root/SidePanel/SelectionBox/SelectionLabel") as Label
		err = _T.assert_true(label != null, "the selection label is on screen")
		if err == "":
			err = _T.assert_true(label.text.contains("Holds"),
				"a Bramble's panel says how long it holds, got %s" % label.text.replace("\n", " / "))
		if err == "":
			err = _T.assert_false(label.text.contains("Idle"),
				"and does not also call itself idle -- it is a wall, not a gun waiting")
	if err == "":
		# The other direction, on a plant standing beside it.
		var grass: Vector2i = _grass(game)
		err = _T.assert_eq(game.place_plant(PlantCatalog.SUNFLOWER, grass), "",
			"and a Sunflower is in the ground")
		if err == "":
			game._select(game.plant_at(grass))
			game._process(0.016)
			await _pump(game)
			var label2: Label = game.hud.get_node_or_null(
				"Root/SidePanel/SelectionBox/SelectionLabel") as Label
			err = _T.assert_false(label2.text.contains("Holds"),
				"a plant that does not resist never shows the line, got %s"
					% label2.text.replace("\n", " / "))
	_T.free_ui(game)
	return err


func test_the_holds_line_is_priced_by_the_selection_budget() -> String:
	# The line has to be IN the corpus, not merely correct. hud.gd's own header explains
	# the failure this prevents: a detail line too wide for the 232px box does not clip,
	# it WRAPS, the label grows a row, and the VBox pushes Uproot past the panel's foot.
	# A producer nobody added to the corpus is priced at zero.
	var corpus: Array[String] = Hud.selection_detail_corpus()
	var wanted: String = Hud.resisting_detail(999.0)
	var err: String = _T.assert_true(corpus.has(wanted),
		("the widest 'Holds' line the FORMAT allows is in the corpus the budget prices; "
			+ "corpus holds %d line(s)") % corpus.size())
	if err == "":
		# And it is priced at the format's ceiling rather than at today's balance --
		# a corpus entry that tracks the live number is a budget that moves when the
		# balance does, which is the opposite of a budget.
		err = _T.assert_false(corpus.has(Hud.resisting_detail(Bramble.hold_seconds(1))),
			"priced at the format's ceiling, not at what a Bramble happens to show today")
	return err

# END plant-tower-defense-7daf
# =============================================================================


# =============================================================================
# plant-tower-defense-cs2k — the invariant, over every overlay rather than one.
#
# WHAT THIS ADDS, since seven tests already assert a focus transition and one of
# them (test_the_hud_is_inert_while_an_overlay_is_open) is already the derived-set
# version of this idea. That one covers ONE overlay (the pause card) over ONE layer
# (the HUD). This is the cross-product: all three OverlayScreen subclasses, over
# both the pause card beneath them AND the HUD beneath that.
#
# THE SUBJECT IS COLLECTED WHILE THE OVERLAY IS CLOSED, and that is the whole design
# rather than a detail. The bead proposed "walk every Control under a lower
# CanvasLayer and assert focus_mode == FOCUS_NONE", which is nearly vacuous as
# worded: a Label, a ColorRect and a Panel are FOCUS_NONE at all times, so such a
# sweep passes identically over a screen that went inert and one that was never
# focusable. So the set here is "every Control that is FOCUS_ALL during play", built
# before anything opens — a screen that contributes nothing to that set contributes
# nothing to the assertion either, which is why the denominator is checked too.
# =============================================================================


## Every Control at or under `root` that a player could focus right now.
##
## A tree walk rather than a per-screen accessor, because there is no accessor to
## call: `Hud.interactive_controls()` is the only method of its kind in the project
## and PauseScreen has no counterpart. A walk is also what makes this survive a
## fourth screen nobody has written, which is the bead's stated point.
func _focusable_under(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var control := node as Control
		if control != null and control.focus_mode == Control.FOCUS_ALL:
			out.append(control)
		for child: Node in node.get_children():
			stack.append(child)
	return out


func test_every_overlay_makes_everything_under_it_unfocusable() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.pause_run()
	await _pump(game)
	var card := game.get_node_or_null("PauseLayer/PauseScreen") as PauseScreen
	var err: String = _T.assert_true(card != null, "the pause card is up")
	if err != "":
		_T.free_ui(game)
		return err

	# Collected with nothing open over it: the card's own buttons plus whatever the
	# HUD still offers behind it. This is the "during play" set the header describes.
	var live: Array[Control] = _focusable_under(card)
	err = _T.assert_gt(live.size(), 2,
		("the pause card has focusable controls to make inert -- an empty or tiny set "
			+ "here would pass every assertion below without checking anything, which "
			+ "is exactly the vacuity this test was written to avoid"))

	# All three, by name, so a fourth OverlayScreen subclass landing without an entry
	# is visible rather than silently uncovered. The predicates are PauseScreen's own.
	var overlays: Array[Dictionary] = [
		{"name": "notebook", "open": Callable(self, "_open_pause_notebook"),
			"is_open": Callable(card, "notebook_open")},
		{"name": "keys", "open": Callable(self, "_open_pause_keys"),
			"is_open": Callable(card, "keys_open")},
		{"name": "options", "open": Callable(self, "_open_pause_options"),
			"is_open": Callable(card, "options_open")},
	]
	if err == "":
		err = _T.assert_eq(overlays.size(), 3,
			("every OverlayScreen subclass is exercised here -- there are three "
				+ "(key_binding_screen.gd, notebook_screen.gd, options_screen.gd) and a "
				+ "fourth needs a row above, which is the case this test exists for"))

	var swept: int = 0
	for entry: Dictionary in overlays:
		if err != "":
			break
		var label: String = String(entry["name"])
		err = (entry["open"] as Callable).call(card) as String
		if err != "":
			break
		await _pump(game)
		err = _T.assert_true((entry["is_open"] as Callable).call() as bool,
			"the %s screen is open" % label)
		if err != "":
			break
		# THE INVARIANT. Everything that was focusable during play is unreachable now.
		for control: Control in live:
			err = _T.assert_eq(control.focus_mode, Control.FOCUS_NONE,
				("%s is unfocusable behind the %s screen -- Tab does not care what is "
					+ "drawn on top") % [control.name, label])
			if err != "":
				break
		if err != "":
			break
		# And back, which is the half that stops a screen passing by breaking the game
		# underneath it permanently.
		# The notebook is held as a field rather than found by name -- `notebook_open()`
		# reads `_notebook` and NotebookScreen declares no NODE_NAME, unlike the other
		# two. Asymmetric, and reaching for a NODE_NAME it does not have is what
		# name_check caught here before this ran.
		var overlay: Node = card._notebook if label == "notebook" \
			else (card.get_node_or_null(KeyBindingScreen.NODE_NAME) if label == "keys" \
			else card.get_node_or_null(OptionsScreen.NODE_NAME))
		err = _T.assert_true(overlay != null, "the %s screen is in the tree to close" % label)
		if err == "":
			(overlay as Node).call("_input", _key_press(KEY_ESCAPE))
			await _pump(game)
			err = _T.assert_false((entry["is_open"] as Callable).call() as bool,
				"the %s screen closed again" % label)
		if err == "":
			for control: Control in live:
				err = _T.assert_eq(control.focus_mode, Control.FOCUS_ALL,
					"%s is reachable again once the %s screen is gone"
						% [control.name, label])
				if err != "":
					break
		if err == "":
			swept += 1

	if err == "":
		err = _T.assert_eq(swept, overlays.size(),
			"every overlay was actually opened and measured, not skipped")
	game.resume_run()
	_T.free_ui(game)
	return err

# END plant-tower-defense-cs2k
# =============================================================================


# =============================================================================
# plant-tower-defense-a180 — the wall shows what it has taken.
# =============================================================================


func test_a_bramble_wears_a_worse_frame_the_further_it_is_chewed() -> String:
	# The pure rule first, at both ends and across both boundaries. Asserted as an
	# ORDERING over the whole range rather than at three sampled points: sampling one
	# fraction per frame passes on a table whose middle two entries are swapped.
	var seen: Array[String] = []
	var fraction: float = 1.0
	while fraction >= -0.001:
		var path: String = Bramble.texture_for_health(fraction)
		if seen.is_empty() or seen[seen.size() - 1] != path:
			seen.append(path)
		fraction -= 0.01
	var err: String = _T.assert_eq(seen, Bramble.DAMAGE_TEXTURES,
		("sweeping health from full to empty walks the frames in declared order and "
			+ "changes exactly %d time(s) -- a repeat or a skip here is a threshold "
			+ "table that disagrees with its own picture list")
			% (Bramble.DAMAGE_TEXTURES.size() - 1))
	if err == "":
		err = _T.assert_eq(Bramble.DAMAGE_THRESHOLDS.size(),
			Bramble.DAMAGE_TEXTURES.size() - 1,
			"there is one fewer threshold than frames, or one frame is unreachable")
	if err == "":
		# Clamped at both ends rather than bounds-checked, which the header claims.
		err = _T.assert_eq(Bramble.texture_for_health(2.0), Bramble.DAMAGE_TEXTURES[0],
			"a wall healed past full still wears the whole frame")
	if err == "":
		err = _T.assert_eq(Bramble.texture_for_health(-1.0),
			Bramble.DAMAGE_TEXTURES[Bramble.DAMAGE_TEXTURES.size() - 1],
			"and a negative fraction does not index off the end")
	return err


func test_the_wall_sprite_follows_the_damage_in_both_directions() -> String:
	# The wiring, and specifically the HEALING direction -- which is why the swap hangs
	# off _refresh_health_bar rather than off take_damage. A wall repaired by a Salve
	# Aloe or by the rain that kept showing a chewed picture would be exactly the
	# misleading readout this plant was given a picture to avoid.
	var wall := Bramble.new()
	wall.setup(PlantCatalog.BRAMBLE, Vector2i(0, 0), null)
	var host: Node2D = _host([wall])
	await _T.instantiate_scene(host)

	var err: String = _T.assert_eq(wall._sprite.texture.resource_path,
		Bramble.DAMAGE_TEXTURES[0], "a fresh wall is whole")
	if err == "":
		# Straight past the last threshold, through take_damage so the resistance applies.
		wall.take_damage(Plant.MAX_HEALTH / wall.bite_resistance())
		err = _T.assert_true(wall.is_destroyed(), "precondition: that bite finished it")
	if err == "":
		wall.health = Plant.MAX_HEALTH * 0.5
		wall._refresh_health_bar()
		err = _T.assert_eq(wall._sprite.texture.resource_path, Bramble.DAMAGE_TEXTURES[1],
			"at half health it wears the middle frame")
	if err == "":
		wall.health = Plant.MAX_HEALTH * 0.2
		wall._refresh_health_bar()
		err = _T.assert_eq(wall._sprite.texture.resource_path, Bramble.DAMAGE_TEXTURES[2],
			"and the ragged one once it is nearly through")
	if err == "":
		# BACK UP. This is the assertion the take_damage-only version would fail.
		wall.heal(Plant.MAX_HEALTH)
		err = _T.assert_eq(wall._sprite.texture.resource_path, Bramble.DAMAGE_TEXTURES[0],
			"and a repaired wall looks whole again")
	_T.free_ui(host)
	return err


func test_every_bramble_frame_is_the_same_plant_standing_in_the_same_place() -> String:
	# The three frames are swapped into one Sprite2D with no reposition, so a frame whose
	# painted base sits higher makes the plant JUMP when it is bitten -- a defect that is
	# invisible in any single screenshot and obvious in play. The style suite pins each
	# frame against the family's pivot independently; this pins them against EACH OTHER,
	# which is the tighter claim and the one that matters for an animation.
	var bases: Dictionary = {}
	var mids: Dictionary = {}
	for path: String in Bramble.DAMAGE_TEXTURES:
		var image: Image = (load(path) as Texture2D).get_image()
		var low: int = -1
		var left: int = image.get_width()
		var right: int = -1
		for y: int in range(image.get_height()):
			for x: int in range(image.get_width()):
				if image.get_pixel(x, y).a > 0.06:
					low = maxi(low, y)
					left = mini(left, x)
					right = maxi(right, x)
		bases[path] = low
		mids[path] = float(left + right) * 0.5
	var err: String = _T.assert_eq(bases.size(), Bramble.DAMAGE_TEXTURES.size(),
		"every frame loaded and was measured")
	var first: String = Bramble.DAMAGE_TEXTURES[0]
	for path: String in Bramble.DAMAGE_TEXTURES:
		if err != "":
			break
		err = _T.assert_eq(int(bases[path]), int(bases[first]),
			("%s stands on the same painted base as the whole frame (%d vs %d) -- a "
				+ "different one makes the plant jump the moment it is bitten")
				% [path.get_file(), int(bases[path]), int(bases[first])])
		if err == "":
			err = _T.assert_float_eq(float(mids[path]), float(mids[first]), 1.0,
				"%s is centred where the whole frame is" % path.get_file())
	return err

# END plant-tower-defense-a180
# =============================================================================


## The Bramble's ladder buys TIME, and a heal is worth more at every rung
## (plant-tower-defense-4u74).
##
## The second half is the design and is the reason the rungs move `bite_resistance` rather
## than `MAX_HEALTH`. A heal is worth `1 / (EAT_DPS * bite_resistance())` seconds, so a
## rung that lowers resistance scales the Salve Aloe standing behind the wall — and the
## rain — WITH the upgrade. A bigger health pool would have diluted both, making the board
## this plant exists to create worse as you invested in it. Asserting only "each rung holds
## longer" would pass on the pool version too, which is why the second assertion is here.
func test_the_brambles_ladder_buys_time_and_makes_every_heal_worth_more() -> String:
	var err: String = _T.assert_gt(Bramble.LEVELS.size(), 1,
		"there is a ladder to climb -- one rung would make every comparison below vacuous")
	if err == "":
		# The base rung and the constant must agree, or the catalogue's 20-seed plant and
		# the class header describe different plants.
		err = _T.assert_float_eq(Bramble.resistance_at(1), Bramble.BITE_RESISTANCE, 0.0001,
			"the ladder starts where BITE_RESISTANCE says it does")
	if err == "":
		for i: int in range(1, Bramble.LEVELS.size()):
			# STRICTLY longer at every rung, and asserted as an ordering over the whole
			# ladder rather than base-versus-top: a middle rung that went backwards would
			# pass a two-point check.
			err = _T.assert_true(Bramble.hold_seconds(1, i + 1) > Bramble.hold_seconds(1, i),
				("rung %d holds longer than rung %d (%.1fs vs %.1fs)"
					% [i + 1, i, Bramble.hold_seconds(1, i + 1), Bramble.hold_seconds(1, i)]))
			if err != "":
				break
	if err == "":
		# THE DESIGN. What one second of the Aloe's healing is WORTH, at the bottom rung and
		# at the top. A bigger-pool ladder would leave this flat; this one must climb.
		var bottom: float = Aloe.HEAL_PER_SECOND / (Pest.EAT_DPS * Bramble.resistance_at(1))
		var top: float = Aloe.HEAL_PER_SECOND / (Pest.EAT_DPS
			* Bramble.resistance_at(Bramble.LEVELS.size()))
		err = _T.assert_true(top > bottom,
			("a second of Aloe healing buys %.2fs of wall at the top rung against %.2fs at "
				+ "the bottom -- rungs that bought HEALTH would leave this unchanged, which "
				+ "is the whole reason they buy resistance") % [top, bottom])
	if err == "":
		# Clamped at both ends, like every other ladder lookup in this project.
		err = _T.assert_float_eq(Bramble.resistance_at(0), Bramble.resistance_at(1), 0.0001,
			"rung 0 clamps to the base")
		if err == "":
			err = _T.assert_float_eq(Bramble.resistance_at(99),
				Bramble.resistance_at(Bramble.LEVELS.size()), 0.0001,
				"and a rung past the top clamps to the top")
	return err


## Every shop blurb is true of the code that makes it true (plant-tower-defense-2878).
##
## A blurb is a factual promise the player reads while deciding how to spend seeds, and it
## lives in `tooltip_text` on the shop button — so unlike the message row it is not width
## budgeted, and unlike a comment nobody re-reads it, it is read by everyone.
##
## Two were pinned before this: the Nettle's "dead weight until wave 8" against
## `WaveDirector.MUTATION_START_WAVE`, and the Chomp's against `Pest.SPECIES` (cycle 119).
## This is the other seven, and it found one that had stopped being true.
##
## EVERY PLANT MUST APPEAR BELOW, checked or explicitly excused. That is the denominator,
## and it is what makes the tenth plant fail here rather than shipping an unchecked promise.
func test_every_shop_blurb_is_true_of_the_code_that_makes_it_true() -> String:
	var handled: Array[StringName] = []
	var err: String = ""

	# CORN -- "Upgrades to a bunch of corn." The top rung's own name.
	handled.append(PlantCatalog.CORN)
	var top: Dictionary = CornCobbler.LEVELS[CornCobbler.LEVELS.size() - 1]
	err = _T.assert_true(PlantCatalog.blurb(PlantCatalog.CORN).contains(String(top["name"])),
		"the cob's blurb names its top rung (%s)" % top["name"])

	# SUNFLOWER -- "Fights nothing."
	if err == "":
		handled.append(PlantCatalog.SUNFLOWER)
		err = _T.assert_false(PlantCatalog.engages(PlantCatalog.SUNFLOWER),
			"a plant whose blurb opens 'Fights nothing' does not engage")

	# SUNDEW -- three claims, and the one that had gone stale.
	if err == "":
		handled.append(PlantCatalog.SUNDEW)
		var dew: String = PlantCatalog.blurb(PlantCatalog.SUNDEW)
		err = _T.assert_false(PlantCatalog.engages(PlantCatalog.SUNDEW),
			"'Hurts nothing' -- the Sundew does not engage")
		if err == "":
			# THE ONE THAT WAS WRONG. SLOW_FACTOR is 0.55, the panel prints "55% speed",
			# and the blurb said "half speed". Asserted as a RELATIONSHIP so a retune moves
			# the sentence with it: if the factor is not 0.5, the blurb may not say a bare
			# "at half speed".
			var half: bool = absf(StickySundew.SLOW_FACTOR - 0.5) < 0.001
			err = _T.assert_eq(dew.contains("at half speed"), half,
				("SLOW_FACTOR is %.2f, so the blurb %s say 'at half speed' -- the panel "
					+ "prints %d%% and the two must not disagree about the same plant")
					% [StickySundew.SLOW_FACTOR, "must" if half else "must not",
						int(round(StickySundew.SLOW_FACTOR * 100.0))])
		if err == "":
			# "wings included, which no Chomp can say" -- asserted BEHAVIOURALLY, because
			# neither half is a constant. The Sundew's `_act` claims any pest it `covers()`
			# with no wing check; the Chomp has two `is_winged` guards. The Chomp half is
			# already pinned by test_a_winged_pest_flies_over_a_chomps_reach, so this is the
			# half nothing was checking.
			var dew_patch := StickySundew.new()
			dew_patch.setup(PlantCatalog.SUNDEW, Vector2i(0, 0), null)
			var flier: Pest = _pest(Pest.APHID, Vector2(0, 0))
			flier.apply_mutation(Pest.MUTATION_WINGED)
			var dew_host: Node2D = _host([dew_patch, flier])
			await _T.instantiate_scene(dew_host)
			dew_patch._act(0.016, [flier])
			err = _T.assert_true(dew_patch.covers(flier),
				"the dew catches a WINGED pest -- which is the half of the sentence the "
					+ "Chomp cannot match")
			_T.free_ui(dew_host)

	# MINT -- "shoot a third again as fast". 0.75 interval is 1/0.75 = 1.333x the rate.
	if err == "":
		handled.append(PlantCatalog.MINT)
		var rate: float = 1.0 / Mint.scale_for(1)
		err = _T.assert_float_eq(rate, 4.0 / 3.0, 0.02,
			("one Mint makes a neighbour fire %.3fx as fast; 'a third again' is 1.333x"
				% rate))

	# ALOE -- "Too slow to save one being eaten."
	if err == "":
		handled.append(PlantCatalog.ALOE)
		err = _T.assert_true(Aloe.HEAL_PER_SECOND < Pest.EAT_DPS,
			("the Aloe heals %.1f/s against a mouth taking %.1f/s -- 'too slow to save one "
				+ "being eaten' is a comparison, not a mood")
				% [Aloe.HEAL_PER_SECOND, Pest.EAT_DPS])

	# BRAMBLE -- "Winged pests go straight over."
	if err == "":
		handled.append(PlantCatalog.BRAMBLE)
		err = _T.assert_false(Bramble.stops(true), "a winged pest is not held by the wall")

	# DANDELION -- "grows its fluff back between volleys."
	if err == "":
		handled.append(PlantCatalog.DANDELION)
		err = _T.assert_true(Dandelion.rearm_seconds() < Game.PREP_SECONDS,
			("a spent head rearms in %.1fs inside the %.0fs gap between waves"
				% [Dandelion.rearm_seconds(), Game.PREP_SECONDS]))

	# The two pinned elsewhere, named so this test's denominator is honest about them.
	if err == "":
		handled.append(PlantCatalog.NETTLE)     # test_the_nettle_blurb_warns_it_is_dead_weight_before_mutations
		handled.append(PlantCatalog.CHOMP)      # test_the_chomps_shop_line_is_true_of_the_chew_table

	# THE DENOMINATOR. A tenth plant fails here until somebody decides whether its blurb
	# makes a checkable claim -- which is the whole point, since the alternative is an
	# unchecked promise the player pays for.
	if err == "":
		var missing: Array[String] = []
		for id: StringName in PlantCatalog.ids():
			if not handled.has(id):
				missing.append(String(id))
		err = _T.assert_true(missing.is_empty(),
			("every plant's blurb is checked here or named as checked elsewhere; "
				+ "unaccounted: %s") % [missing])
	return err


## A touch commits where the finger LIFTS, not where it landed (plant-tower-defense-qdsi).
##
## The whole point of the touch layer: a tap placed on press gives a touch player no way to
## see what they are about to do and no way to abort a mis-aim. Committing on release means
## the finger can slide to the right cell with the preview following it.
##
## What this test canNOT cover, and why the bridge check exists alongside it: the emulated
## mouse event. `DisplayServer.is_touchscreen_available()` is a property of the machine, not
## something a test can set, so the `device == -1` guard is only exercisable on a running
## game with `set-feature --touchscreen true`. That half is a /verify Phase 4 check and is
## recorded in the ledger row, not here.
func test_a_touch_plants_where_the_finger_lifts_not_where_it_landed() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(400)
	game.bank.unlocked = PlantCatalog.ids()
	game.selected_plant = PlantCatalog.CORN
	var from_cell: Vector2i = _grass(game)
	var to_cell: Vector2i = Vector2i(from_cell.x + 3, from_cell.y)
	var err: String = _T.assert_true(game.board.is_buildable(to_cell),
		"the cell three to the right is also plantable, so the two are interchangeable "
			+ "except for which one the finger is over")
	if err != "":
		_T.free_ui(game)
		return err

	var from_pos: Vector2 = game.board.cell_to_world(from_cell) + game._entities.position
	var to_pos: Vector2 = game.board.cell_to_world(to_cell) + game._entities.position

	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = from_pos
	game._unhandled_input(down)
	err = _T.assert_true(game.plant_at(from_cell) == null,
		"the press plants nothing -- this is the assertion the whole bead is about")

	if err == "":
		var slide := InputEventScreenDrag.new()
		slide.index = 0
		slide.position = to_pos
		game._unhandled_input(slide)
		err = _T.assert_true(game.plant_at(to_cell) == null, "and neither does the drag")
	if err == "":
		var up := InputEventScreenTouch.new()
		up.index = 0
		up.pressed = false
		up.position = to_pos
		game._unhandled_input(up)
		err = _T.assert_true(game.plant_at(to_cell) != null,
			"the release plants, at the cell the finger LIFTED over (%s)" % to_cell)
	if err == "":
		err = _T.assert_true(game.plant_at(from_cell) == null,
			"and nothing was left at the cell it started from (%s) -- a implementation "
				% from_cell + "that remembered the press position would fail here and "
				+ "nowhere else")
	if err == "":
		# A second finger while one is down is palm contact or a fumble far more often than
		# it is intent, and this game has no two-finger gesture.
		var other: Vector2i = Vector2i(from_cell.x, from_cell.y + 2)
		if game.board.is_buildable(other) and game.plant_at(other) == null:
			var down_a := InputEventScreenTouch.new()
			down_a.index = 0
			down_a.pressed = true
			down_a.position = from_pos
			game._unhandled_input(down_a)
			var down_b := InputEventScreenTouch.new()
			down_b.index = 1
			down_b.pressed = true
			down_b.position = game.board.cell_to_world(other) + game._entities.position
			game._unhandled_input(down_b)
			var up_b := InputEventScreenTouch.new()
			up_b.index = 1
			up_b.pressed = false
			up_b.position = game.board.cell_to_world(other) + game._entities.position
			game._unhandled_input(up_b)
			err = _T.assert_true(game.plant_at(other) == null,
				"a second finger lifting plants nothing while the first is still down")
	_T.free_ui(game)
	return err


## A binding that did not reach disk says so (plant-tower-defense-bia).
##
## `RunConfig._save()` has four paths where the record does not land and every one of them
## reported through `push_warning` — which goes to the editor log, a place no player has and
## no screen can read. So the Keys screen wrote on every capture and confirmed success by
## changing the row's key text, which looks identical when the write failed.
func test_a_binding_that_did_not_reach_disk_says_so() -> String:
	# The note text first, both branches, with no screen and no disk. This is the half that
	# would otherwise never be exercised: the failure branch is unreachable unless something
	# is deliberately breaking the save path, and an unreachable sentence is exactly the kind
	# that ships misspelled.
	var base: String = "Set:  M   sound effects on or off"
	var err: String = _T.assert_eq(KeyBindingScreen.persisted_note(base, true), base,
		("a save that landed says nothing extra — silence is the confirmation, and a word "
			+ "about disks on every capture would be noise forever to cover a case that "
			+ "essentially never happens"))
	if err == "":
		var bad: String = KeyBindingScreen.persisted_note(base, false)
		err = _T.assert_true(bad.begins_with(base),
			"a save that did not land still says what was set, then adds to it: %s" % bad)
	if err == "":
		err = _T.assert_true(bad_contains_not_saved(base),
			"and it says NOT saved in words a player can act on")

	# Then the wiring, on the real autoload: a write to an unwritable path must return
	# false. This is the assertion that would have caught the original defect.
	if err == "":
		var stashed: String = RunConfig.save_path
		var stashed_map: Dictionary = RunConfig.key_bindings.duplicate()
		# A directory that cannot exist, so FileAccess.open fails on the temp file — the
		# first of _save's four failure paths and the only one reachable without a
		# filesystem fault.
		RunConfig.save_path = "user://no_such_dir_bia/does_not_exist.save"
		var landed: bool = RunConfig.store_key_bindings({"pause": [KEY_F9]})
		RunConfig.save_path = stashed
		RunConfig.key_bindings = stashed_map
		err = _T.assert_false(landed,
			"storing bindings into an unwritable path reports failure rather than void")
	if err == "":
		# And the other direction, or this passes on a store that always reports failure.
		var stashed2: String = RunConfig.save_path
		var stashed_map2: Dictionary = RunConfig.key_bindings.duplicate()
		RunConfig.save_path = "user://test_bia_roundtrip.save"
		var ok: bool = RunConfig.store_key_bindings(stashed_map2)
		RunConfig.save_path = stashed2
		RunConfig.key_bindings = stashed_map2
		DirAccess.remove_absolute("user://test_bia_roundtrip.save")
		err = _T.assert_true(ok, "and a writable path reports success")
	return err


## Helper kept out of the test body so the assertion above reads as one sentence.
func bad_contains_not_saved(base: String) -> bool:
	return KeyBindingScreen.persisted_note(base, false).contains("NOT saved")


## The Chomp's shop line is true of the chew table (plant-tower-defense-l86t).
##
## "Eats small pests instantly. Big ones take a while — and it is busy the whole time."
## Three claims, all checkable against `Pest.SPECIES` rather than against anyone's memory of
## it, and this is the test that decided the bead: a 0.45s chew reading as a flash is not a
## broken cue, it is the cue agreeing with the sentence the player was sold before buying.
##
## Derived, never listed. A new species with a chew time lands in this test the moment it is
## added to SPECIES, which is the whole reason the bead's "record both durations as numbers"
## became a relationship instead of two constants.
func test_the_chomps_shop_line_is_true_of_the_chew_table() -> String:
	var chews: Dictionary = {}
	for species: StringName in Pest.SPECIES:
		chews[species] = float((Pest.SPECIES[species] as Dictionary)["chew_seconds"])
	var err: String = _T.assert_gt(chews.size(), 2,
		"there are several species to compare — two would make 'shortest' meaningless")
	if err != "":
		return err

	var shortest: StringName = &""
	for species: StringName in chews:
		if shortest == &"" or chews[species] < chews[shortest]:
			shortest = species
	if err == "":
		# CLAIM 1: "small pests". The quickest meal is the smallest pest, not merely some
		# pest -- if the Queen were ever the fastest to eat, the sentence would be false
		# while every duration in it stayed the same.
		err = _T.assert_eq(shortest, Pest.APHID,
			"the quickest thing to eat is the smallest pest, got %s" % shortest)
	if err == "":
		# CLAIM 2: "instantly ... big ones take a while". A RELATIVE gap, deliberately,
		# because "instant" is a fact about perception and this file cannot measure one.
		# What it can measure is that the short case is in a different league from every
		# other, which is what makes the two halves of the sentence describe two things.
		for species: StringName in chews:
			if species == shortest:
				continue
			err = _T.assert_true(chews[species] >= chews[shortest] * 4.0,
				("%s takes %.2fs against the %s's %.2fs — under 4x the sentence stops "
					+ "describing two different experiences and the chew ring loses the "
					+ "case it exists for") % [species, chews[species], shortest,
						chews[shortest]])
			if err != "":
				break
	if err == "":
		# CLAIM 3: "it is busy the whole time" -- for EVERY duration, including the short
		# one. This is why the ring is not suppressed below a threshold: a Chomp mid-chew
		# cannot grab, and a cue that vanished would report a busy mouth as a free one.
		var chomp := ChompFlower.new()
		chomp.setup(PlantCatalog.CHOMP, Vector2i(0, 0), null)
		var pest: Pest = _pest(Pest.APHID, Vector2(0, Board.CELL))
		var host: Node2D = _host([chomp, pest])
		await _T.instantiate_scene(host)
		chomp._act(0.016, [pest])
		err = _T.assert_true(chomp.is_busy(),
			"a Chomp that has taken even the quickest meal reports itself busy")
		if err == "":
			err = _T.assert_true(chomp.chew_progress() < 1.0,
				"and its chew has progress left to draw, so the ring has something to say")
		_T.free_ui(host)
	return err


## The rot floor is a floor, and the curve still sorts everything below it
## (plant-tower-defense-ix76).
##
## The decision this pins is recorded above `CompostMeter.MIN_HUSK_LIFETIME`: six of the ten
## reachable husk values sit at or above `FULL_VALUE` and all get the same 4.5s, and that is
## deliberate — 4.5s is a reaction time, the richest husks drop at a boss death when the
## player is busiest, and the urgency is already carried by size, glow and the overflow
## pips. A comment saying so is a comment; this is the version that fails when somebody
## widens FULL_VALUE or bolts a second curve on.
func test_the_rot_floor_is_a_floor_and_the_curve_still_sorts_below_it() -> String:
	# DERIVED, not listed. Pest.SPECIES crossed with every composable mutation set is where
	# the ten values come from, so a new species or a new multiplier moves this test with
	# the game instead of leaving it asserting a table nobody updated.
	var values: Array[int] = []
	for species: StringName in Pest.SPECIES:
		var seeds: int = int((Pest.SPECIES[species] as Dictionary)["seeds"])
		for mult: float in [1.0, 1.5, 2.0, 3.0]:
			var v: int = CompostMeter.husk_value_for(seeds, mult)
			if not values.has(v):
				values.append(v)
	values.sort()

	var err: String = _T.assert_gt(values.size(), 4,
		"there are several reachable husk values to sort — a short list would pass the "
			+ "ordering below without exercising it")
	if err == "":
		# THE FLOOR. Nothing rots faster than MIN_HUSK_LIFETIME, at any value, including
		# values far above anything the game drops today.
		for v: int in values + [999, 100000]:
			err = _T.assert_gte(CompostMeter.lifetime_for(v), CompostMeter.MIN_HUSK_LIFETIME,
				"a husk worth %d rots no faster than the %.1fs floor (got %.2fs)"
					% [v, CompostMeter.MIN_HUSK_LIFETIME, CompostMeter.lifetime_for(v)])
			if err != "":
				break
	if err == "":
		# AND EVERYTHING AT OR ABOVE FULL_VALUE SHARES IT. This is the half the bead asked
		# about: they are the same on purpose, not by an oversight nobody noticed.
		var saturated: Array[int] = []
		for v: int in values:
			if v >= CompostMeter.FULL_VALUE:
				saturated.append(v)
		err = _T.assert_gt(saturated.size(), 1,
			"more than one reachable value saturates, or 'they share the floor' is vacuous")
		for v: int in saturated:
			if err != "":
				break
			err = _T.assert_float_eq(CompostMeter.lifetime_for(v),
				CompostMeter.MIN_HUSK_LIFETIME, 0.001,
				("a husk worth %d gets the same %.1fs as one worth %d — DECIDED, see "
					+ "MIN_HUSK_LIFETIME: 4.5s is a reaction time and the richest husks "
					+ "drop at a boss death") % [v, CompostMeter.MIN_HUSK_LIFETIME,
						CompostMeter.FULL_VALUE])
	if err == "":
		# AND THE CURVE STILL DOES ITS JOB WHERE IT CAN. Below the saturation point a richer
		# husk really does rot faster -- strictly. Without this the whole thing could be
		# "fixed" by flattening the curve entirely, which would pass every assertion above.
		var below: Array[int] = []
		for v: int in values:
			if v < CompostMeter.FULL_VALUE:
				below.append(v)
		err = _T.assert_gt(below.size(), 1, "there are values below the floor to order")
		for i: int in range(1, below.size()):
			if err != "":
				break
			err = _T.assert_true(
				CompostMeter.lifetime_for(below[i]) < CompostMeter.lifetime_for(below[i - 1]),
				("a husk worth %d rots strictly faster than one worth %d (%.2fs vs %.2fs) "
					+ "— the curve is flat only above the saturation point")
					% [below[i], below[i - 1], CompostMeter.lifetime_for(below[i]),
						CompostMeter.lifetime_for(below[i - 1])])
	return err


# =============================================================================
# plant-tower-defense-lven — the road rule, said once.
# =============================================================================


func test_the_road_rule_is_told_once_and_only_for_a_plant_that_goes_there() -> String:
	var stashed: Dictionary = RunConfig.earned_milestones.duplicate()
	RunConfig.earned_milestones = {}
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.unlocked = PlantCatalog.ids()

	# A plant that stands on grass must NOT spend the hint. Asserted FIRST, because a hint
	# that fires for everything would pass every assertion below.
	game._on_plant_chosen(PlantCatalog.CORN)
	var err: String = _T.assert_false(
		RunConfig.has_milestone(RunConfig.HINT_ROAD_PLANTS),
		"picking a plant that goes on the grass says nothing about the road")

	if err == "":
		# THE ROW IS BUSY AT SCENE START (the prep note), and `show_message` QUEUES rather
		# than stomps a line that has not been up long enough to read -- returning false.
		# So the first pick does NOT spend the hint, and that is the two-door contract
		# working: "I called show_message" and "the player read it" are different facts,
		# and a dropped line leaves the hint owed for the next pick. Asserted rather than
		# worked around, because a future change that made spend_hint fire on the CALL
		# would pass every other assertion here.
		game._on_plant_chosen(PlantCatalog.BRAMBLE)
		err = _T.assert_false(RunConfig.has_milestone(RunConfig.HINT_ROAD_PLANTS),
			"a pick while the row is busy leaves the hint owed rather than spending it")
	if err == "":
		game.hud._message_left = 0.0
		game._on_plant_chosen(PlantCatalog.BRAMBLE)
		err = _T.assert_true(RunConfig.has_milestone(RunConfig.HINT_ROAD_PLANTS),
			"and the next pick with a free row spends it")
	if err == "":
		var label: Label = game.hud.get_node_or_null("Root/TopBar/MessageLabel") as Label
		err = _T.assert_true(label != null and label.text.contains("ON the road"),
			"and the row actually carries it, got: %s" % ("<no label>" if label == null
				else label.text))
	if err == "":
		# ONCE. Re-picking must not re-post it -- the whole contract of a hint.
		# Free the row FIRST, then put a different line on it, or the tip simply lingers
		# and "the row still says it" proves nothing about whether it was re-posted.
		game.hud._message_left = 0.0
		game.hud.show_message("Something else entirely.")
		game._on_plant_chosen(PlantCatalog.BRAMBLE)
		var after: String = (game.hud.get_node("Root/TopBar/MessageLabel") as Label).text
		err = _T.assert_eq(after, "Something else entirely.",
			"picking it a second time posts nothing -- the hint is spent (row says: %s)"
				% after)
	_T.free_ui(game)
	RunConfig.earned_milestones = stashed
	return err


func test_a_packet_that_hands_over_a_road_plant_tells_the_rule_too() -> String:
	# The SECOND route into `selected_plant`, and the one _on_plant_chosen's own comment
	# says does not exist ("This is the only route in"). True of the BAR; a packet hands
	# the player a plant already selected, so a Bramble can arrive having never been
	# pressed in the bar -- which is exactly the player meeting it for the first time.
	var stashed: Dictionary = RunConfig.earned_milestones.duplicate()
	RunConfig.earned_milestones = {}
	var game := await _T.instantiate_scene(GAME_SCENE) as Game

	# Drive the real handler rather than the bar: force the packet to yield the Bramble by
	# selecting it the way the packet path does, then calling the same hint offer.
	game.hud._message_left = 0.0   # see the sibling test: a busy row defers rather than spends
	game.selected_plant = PlantCatalog.BRAMBLE
	game._offer_road_hint()
	var err: String = _T.assert_true(RunConfig.has_milestone(RunConfig.HINT_ROAD_PLANTS),
		"the packet route spends the hint as well as the bar route")
	if err == "":
		# And the producer is the one the corpus prices, not a second copy of the sentence.
		err = _T.assert_true(Hud.message_corpus().has(
			Hud.road_plant_tip(PlantCatalog.display_name(PlantCatalog.BRAMBLE))),
			"the road tip is priced by the message-row budget")
	if err == "":
		err = _T.assert_true(RunConfig.HINTS.has(RunConfig.HINT_ROAD_PLANTS),
			"and it is registered as a hint, so spend_hint will not refuse it")
	_T.free_ui(game)
	RunConfig.earned_milestones = stashed
	return err


## Only a plant that can actually touch a pest says it is waiting for one
## (plant-tower-defense-u9zb).
##
## `idle_detail()` reads "Idle — waiting for a pest." and every plant without its own
## branch in `_refresh_selection` gets it. That was true of the catalogue it was written
## for. It stopped being true the moment plants arrived that never touch a pest at all: a
## Garden Mint speeds its neighbours and a Salve Aloe repairs them, and both were
## announcing that they were waiting for a pest.
##
## Driven off `PlantCatalog.engages()` rather than off a list of ids, so the TENTH plant
## inherits the rule instead of inheriting the bug. `engages` is the catalogue's own
## "can this touch a pest" key and is exactly the question this sentence makes a claim
## about — which is why this can be a general assertion rather than three named cases.
func test_no_plant_that_cannot_touch_a_pest_claims_to_be_waiting_for_one() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(4000)
	game.bank.unlocked = PlantCatalog.ids()
	var err: String = ""
	var checked: int = 0
	var idle: String = Hud.idle_detail()

	for id: StringName in PlantCatalog.ids():
		if err != "":
			break
		var cell: Vector2i = game.board.world_to_cell(game.board.route()[2]) \
			if PlantCatalog.on_road(id) else _grass(game)
		err = _T.assert_eq(game.place_plant(id, cell), "",
			"%s went into the ground -- a plant this loop cannot place it does not check" % id)
		if err != "":
			break
		game._select(game.plant_at(cell))
		game._process(0.016)
		await _pump(game)
		var label: Label = game.hud.get_node_or_null(
			"Root/SidePanel/SelectionBox/SelectionLabel") as Label
		if label == null:
			err = "the selection label is on screen"
			break
		checked += 1
		if PlantCatalog.engages(id):
			continue
		err = _T.assert_false(label.text.contains(idle),
			("%s cannot touch a pest (PlantCatalog.engages is false), so its panel must "
				+ "not say \"%s\" -- got: %s")
				% [id, idle, label.text.replace("\n", " / ")])

	if err == "":
		err = _T.assert_eq(checked, PlantCatalog.ids().size(),
			"every plant in the catalogue was placed, selected and read")
	if err == "":
		# The other direction, or this passes on a game that deleted idle_detail entirely
		# -- which would lose the line for the plants it is correct about.
		err = _T.assert_true(Hud.selection_detail_corpus().has(idle),
			"idle_detail is still a line the game can show, and still priced")
	_T.free_ui(game)
	return err


## The move preview cannot promise a cell the click will not plant (plant-tower-defense-l7ak).
##
## `_update_preview` describes the plant being MOVED while an uproot is armed
## (plant-tower-defense-qk5q) — its ring, its reach, its coverage dots. The green brackets
## beside that ring are a different claim: `_click_at` plants `selected_plant`, the SHOP
## pick, which during an armed window is not the plant the ring is describing.
##
## Before a plant existed that stands somewhere the others cannot, those two could not
## visibly disagree — every plant was placeable in exactly the same cells, so "the brackets
## are green" and "this plant could stand here" were the same sentence. The Barrier Bramble
## made them different sentences, and this is the state where they contradict: a Corn armed
## for a move, a Bramble picked in the shop, hovering a ROAD cell. The ring says "your cob
## reaches this far from here"; the brackets said "yes, plant".
func test_an_armed_move_never_shows_green_over_a_cell_the_moved_plant_cannot_stand_on() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(400)
	game.bank.unlocked = PlantCatalog.ids()
	var grass: Vector2i = _grass(game)
	var road: Vector2i = game.board.world_to_cell(game.board.route()[2])

	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, grass), "",
		"a cob is in the ground to move")
	if err == "":
		game._select(game.plant_at(grass))
		err = _T.assert_eq(game.arm_uproot(), "confirm needed",
			"and its move window is open -- arm_uproot returns the prompt, not \"\"")
	if err == "":
		# The shop pick stays whatever it was: _select() writes `selected_placed`, not
		# `selected_plant`, so picking a Bramble and then clicking a cob leaves both live
		# at once. That is the whole reachability argument for this state.
		game.selected_plant = PlantCatalog.BRAMBLE
		err = _T.assert_true(game._uproot_armed != null, "the cob is the plant being moved")
	if err == "":
		err = _T.assert_true(game.would_plant_at(road),
			("precondition: the shop's Bramble genuinely could be planted on this road "
				+ "cell, so a preview asking only about `selected_plant` would say yes"))
	if err == "":
		err = _T.assert_false(game.board.is_buildable_for(road, PlantCatalog.CORN),
			"and the cob being moved could never stand there")
	if err == "":
		game._update_cursor(game.board.cell_to_world(road) + game._entities.position)
		err = _T.assert_false(game._preview.placeable,
			("so the preview must NOT promise this cell -- it is describing the cob's "
				+ "reach while the click would plant a Bramble"))
	if err == "":
		# The other direction, or this passes on a preview that never says yes at all.
		game._update_cursor(game.board.cell_to_world(_grass(game)) + game._entities.position)
		err = _T.assert_true(game._preview.plant_id == PlantCatalog.CORN,
			"the preview is still describing the plant being moved")
	_T.free_ui(game)
	return err


## The death line names something that actually happened.
##
## "A hungry pest ate your X!" was true of every plant death in the game until the
## Barrier Bramble existed, because `Pest._physics_process` only reaches
## `_adjacent_plant()` inside its `is_hungry` branch. A Bramble is chewed by
## `_blocking_plant()`, which every pest runs -- so the commonest plant death in the game
## was being announced by a sentence naming a mutation that had nothing to do with it.
func test_a_wall_is_chewed_through_and_a_bed_is_eaten_by_something_hungry() -> String:
	var wall: String = Hud.destroyed_message(PlantCatalog.BRAMBLE)
	var bed: String = Hud.destroyed_message(PlantCatalog.CORN)
	var err: String = _T.assert_false(wall.contains("hungry"),
		"a Bramble's death does not blame the hungry mutation, got: %s" % wall)
	if err == "":
		err = _T.assert_true(wall.contains(PlantCatalog.display_name(PlantCatalog.BRAMBLE)),
			"and it still names the plant, got: %s" % wall)
	if err == "":
		# The other direction, or this passes on a game that stopped mentioning the
		# mutation anywhere -- which would lose the one cue teaching what `hungry` means.
		err = _T.assert_true(bed.contains("hungry"),
			"a bed off the road is still eaten by something hungry, got: %s" % bed)
	if err == "":
		# Driven off `on_road` rather than off the id, so a second road plant inherits it.
		var road_lines: int = 0
		for id: StringName in PlantCatalog.ids():
			if PlantCatalog.on_road(id):
				road_lines += 1
				err = _T.assert_eq(Hud.destroyed_message(id),
					Hud.chewed_through_message(PlantCatalog.display_name(id)),
					"%s gets the wall line because it stands on the road" % id)
			else:
				err = _T.assert_eq(Hud.destroyed_message(id),
					Hud.eaten_message(PlantCatalog.display_name(id)),
					"%s gets the hungry line because it stands off it" % id)
			if err != "":
				break
		if err == "":
			err = _T.assert_gt(road_lines, 0,
				"at least one plant reaches the wall line -- zero would pass every "
					+ "assertion above without checking the branch that matters")
	if err == "":
		# In the corpus, or the row is measured 6 characters narrower than it can be.
		var corpus: Array[String] = Hud.message_corpus()
		err = _T.assert_true(corpus.has(
			Hud.chewed_through_message(PlantCatalog.display_name(PlantCatalog.BRAMBLE))),
			"the wall line is priced by the message-row budget")
	return err


## The legend page's prose has to agree with the table it describes. It said "the five
## here" while CueLegend.ROWS held six -- and the uncounted row was ARMED, the cue
## guarding uproot. The page has always shown a DERIVED count in its source line at the
## same time, so a reader comparing the two would have caught it; nobody was comparing.
##
## Asserted against the count rather than against the word: hard-coding "six" here would
## reproduce the original defect one file over, which is exactly how the first one got in.
func test_the_legend_note_counts_the_rows_the_legend_actually_has() -> String:
	var note: String = NotebookScreen.legend_note_text()
	var word: String = NotebookScreen.count_word(CueLegend.row_count())
	var err: String = _T.assert_true(note.contains("the %s here" % word),
		"the legend note names %d rows; it says: %s" % [CueLegend.row_count(), note])
	if err != "":
		return err
	# And no stray format specifier survived into prose a player reads.
	err = _T.assert_false(note.contains("%s"),
		"the legend note still carries an unfilled placeholder: %s" % note)
	if err != "":
		return err
	# The template must actually be a template. Without this, deleting the %s from PAGES
	# and hard-coding the word again would pass every assertion above.
	return _T.assert_true(
		String(NotebookScreen.PAGES[NotebookScreen.page_for_kind(
			NotebookScreen.KIND_LEGEND)]["note"]).contains("%s"),
		"the legend note in PAGES is no longer a template, so the count is hand-written again")


## count_word is prose-facing, so its edges matter more than its middle: a table that
## outgrows the list must print a digit rather than an empty string or an index error.
func test_count_word_falls_back_to_a_digit_past_its_table() -> String:
	var err: String = _T.assert_eq(NotebookScreen.count_word(6), "six",
		"six is spelled")
	if err != "":
		return err
	err = _T.assert_eq(NotebookScreen.count_word(13), "13",
		"past the table, the digit")
	if err != "":
		return err
	return _T.assert_eq(NotebookScreen.count_word(-1), "-1",
		"a negative count is a bug elsewhere, but must not crash the page")


## The refused log answers WHICH line was dropped, which the count cannot. Cycle 128 read
## `messages_refused` = 12 after four packet purchases and could not tell whether the player
## had lost the flourish's flicker steps or the reveal naming the plant they just bought --
## the same 12 either way, and `_queue_message` had the text in hand and threw it away.
func test_a_refused_message_records_which_line_was_dropped() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var hud: Hud = game.hud
	# Game._ready posts an 8-second starter tip. Drain it, or the row is already held by a
	# line this test did not post and every count below is really about that one.
	hud._process(9.0)
	# Hold the row, then post more at EQUAL priority than the queue can hold. Equal is the
	# case that refuses: a higher priority preempts, a lower one waits.
	hud.show_message("the line holding the row", 5.0, Hud.MESSAGE_IMPORTANT)
	for i: int in range(Hud.MESSAGE_QUEUE_MAX + 2):
		hud.show_message("refusable line %d" % i, 0.5, Hud.MESSAGE_IMPORTANT)
	var err: String = _T.assert_eq(hud.messages_refused, 2,
		"two posts past the queue's %d are refused" % Hud.MESSAGE_QUEUE_MAX)
	if err == "":
		err = _T.assert_eq(hud.messages_refused_log.size(), 2,
			"the log holds one entry per refusal, not a count")
	if err == "":
		# The LAST two posted are the ones refused -- the queue fills first-come, so the
		# log must name lines 3 and 4 rather than 0 and 1.
		err = _T.assert_true(hud.messages_refused_log.has("refusable line 4"),
			"the log names the line actually dropped, got %s"
				% str(hud.messages_refused_log))
	_T.free_ui(game)
	return err


## Capped, because a Hud lives for a whole endless run and an unbounded diagnostic list on
## it is a leak. The cap is also what keeps it a tail rather than a transcript.
func test_the_refused_log_is_capped_and_keeps_the_newest() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var hud: Hud = game.hud
	hud._process(9.0)
	hud.show_message("the line holding the row", 30.0, Hud.MESSAGE_IMPORTANT)
	var posts: int = Hud.MESSAGE_QUEUE_MAX + Hud.REFUSED_LOG_MAX + 3
	for i: int in range(posts):
		hud.show_message("line %d" % i, 0.5, Hud.MESSAGE_IMPORTANT)
	var err: String = _T.assert_eq(hud.messages_refused_log.size(), Hud.REFUSED_LOG_MAX,
		"%d posts past the queue, log capped at %d" % [posts, Hud.REFUSED_LOG_MAX])
	if err == "":
		# Newest kept, oldest dropped: a refusal is explained by what was on the row at the
		# time, and that context is long gone for the oldest entries.
		err = _T.assert_eq(hud.messages_refused_log[-1], "line %d" % (posts - 1),
			"the newest refusal is kept")
	if err == "":
		err = _T.assert_false(hud.messages_refused_log.has("line %d" % Hud.MESSAGE_QUEUE_MAX),
			"the oldest refusal is dropped once the cap is reached")
	_T.free_ui(game)
	return err


## The four readers `cmd messages` reports through. They are the verb's data contract: if
## `message_seconds_left` returned the total rather than the remainder, or the queue snapshot
## handed out the live Dictionaries, the verb would still answer and would answer wrongly --
## and a debug verb that lies is worse than no verb, because it is believed.
func test_the_message_row_reports_its_own_live_state() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var hud: Hud = game.hud
	hud._process(9.0)          # drain Game._ready's starter tip
	hud.show_message("on the row now", 4.0, Hud.MESSAGE_IMPORTANT)
	var err: String = _T.assert_eq(hud.message_text(), "on the row now",
		"message_text is the line currently shown")
	if err == "":
		err = _T.assert_float_eq(hud.message_seconds_left(), 4.0, 0.001,
			"message_seconds_left starts at what the poster asked for")
	if err == "":
		err = _T.assert_eq(hud.message_priority(), Hud.MESSAGE_IMPORTANT,
			"message_priority is the current line's, not the last posted")
	if err == "":
		hud._process(1.5)
		# The REMAINDER, not the total -- the distinction the verb reports and the one a
		# reader uses to decide whether a queued line is about to get the row.
		err = _T.assert_float_eq(hud.message_seconds_left(), 2.5, 0.01,
			"message_seconds_left counts down")
	if err == "":
		# Queue one behind it, at a priority that waits rather than stomps.
		hud.show_message("waiting its turn", 2.0, Hud.MESSAGE_IMPORTANT)
		var pending: Array[Dictionary] = hud.message_queue_snapshot()
		err = _T.assert_eq(pending.size(), 1, "one line is waiting behind the current one")
		if err == "":
			err = _T.assert_eq(String(pending[0]["text"]), "waiting its turn",
				"the snapshot carries the queued line's text")
		if err == "":
			# A COPY: mutating what the snapshot handed back must not touch the real queue.
			pending[0]["text"] = "tampered"
			err = _T.assert_eq(String(hud.message_queue_snapshot()[0]["text"]),
				"waiting its turn",
				"the snapshot is a copy -- a caller cannot edit the queue through it")
	_T.free_ui(game)
	return err


## The reason the notebook has NO weather page is that weather is already taught on screen
## at the moment it can be acted on. That reason is written beside KIND_LEGEND in
## notebook_screen.gd, and it is only true while these three surfaces keep saying it --
## a comment recording a decision is exactly as perishable as the count that said "the five
## here" beside six rows. So the decision is asserted, not just written down.
func test_weather_is_taught_on_screen_which_is_why_the_notebook_has_no_page_for_it() -> String:
	# The banner: the whole mechanic in one sentence, both halves of it.
	var note: String = Hud.weather_note(WaveDirector.WEATHER_DROUGHT)
	var err: String = _T.assert_true(note.contains("half as often"),
		"the drought banner says what it COSTS, got: %s" % note)
	if err == "":
		err = _T.assert_true(
			note.contains("%d%%" % int(round(WaveDirector.WEATHER_DROUGHT_SEED_BONUS * 100.0))),
			"the drought banner says what it PAYS, got: %s" % note)
	if err == "":
		err = _T.assert_true(Hud.weather_headline(WaveDirector.WEATHER_DROUGHT) != "",
			"the drought banner has a headline to carry the note")
	if err == "":
		# The prep note: the surface read BEFORE the seeds are spent, which is the one
		# that makes the mechanic actionable rather than merely explained.
		var prep: String = Hud.next_wave_note(4, 9, false, WaveDirector.WEATHER_DROUGHT, 0)
		err = _T.assert_true(prep.to_lower().contains("drought"),
			"the prep note names the weather before the player spends, got: %s" % prep)
	if err == "":
		# And rain, so the claim is about WEATHER rather than about drought.
		err = _T.assert_true(Hud.weather_note(WaveDirector.WEATHER_RAIN) != "",
			"rain is announced too")
	if err == "":
		# Clear says nothing, deliberately -- a banner that fires every wave stops being read.
		err = _T.assert_eq(Hud.weather_note(WaveDirector.WEATHER_CLEAR), "",
			"clear weather says nothing at all")
	return err


## Two packets bought inside a second must produce TWO reveals, not one and a refusal.
##
## The defect this holds (plant-tower-defense-47v7) was measured live in cycle 129: two
## purchases back to back gave `refused 1`, `refused_log ["The packet held a Chomp
## Flower!"]`, and the row showing the SECOND packet's reveal. The player paid seeds for a
## packet and was never told what was in it. Nothing static could see it -- the flourish is
## a coroutine and the bug is two of them interleaving -- so this test drives the real
## `_open_packet` twice with no gap, which is exactly what a fast player does.
func test_two_packets_opened_at_once_both_get_their_reveal() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var hud: Hud = game.hud
	hud._process(9.0)                      # drain Game._ready's starter tip
	var refused_before: int = hud.messages_refused
	# Two flourishes started in the same frame: the case the serialisation exists for.
	game._open_packet(PlantCatalog.CHOMP)
	game._open_packet(PlantCatalog.SUNFLOWER)
	var err: String = _T.assert_eq(hud.messages_refused, refused_before,
		"a second purchase refuses nothing; refused_log says %s"
			% str(hud.messages_refused_log))
	if err == "":
		# The second packet must be WAITING, not racing -- one flourish in flight at a time.
		err = _T.assert_eq(game._packet_queue.size(), 1,
			"the second packet waits its turn rather than interleaving")
	if err == "":
		err = _T.assert_true(game._packet_opening,
			"the runner is draining the queue")
	_T.free_ui(game)
	return err


## The tier travels with the packet, not in a field the next purchase overwrites.
##
## `_opening_tier` is assigned immediately before `buy_packet()`. That was safe while only
## one flourish could exist; once a purchase can WAIT, a common packet queued behind a rare
## one would flash candidates from whichever tier was bought last. The queue carries it.
func test_a_queued_packet_keeps_its_own_tier() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.hud._process(9.0)
	game._opening_tier = &"common"
	game._open_packet(PlantCatalog.CHOMP)
	game._opening_tier = &"rare"           # a second purchase, a different tier
	game._open_packet(PlantCatalog.SUNFLOWER)
	var err: String = _T.assert_eq(game._packet_queue.size(), 1,
		"one packet is waiting")
	if err == "":
		err = _T.assert_eq(String(game._packet_queue[0]["tier"]), "rare",
			"the waiting packet remembers the tier it was BOUGHT at, not the current field")
	if err == "":
		err = _T.assert_eq(StringName(game._packet_queue[0]["id"]), PlantCatalog.SUNFLOWER,
			"and which packet it is")
	_T.free_ui(game)
	return err


## The case the same-frame test above does NOT cover, and the one the live game failed.
##
## A flourish lasts PACKET_OPEN_STEPS * PACKET_OPEN_STEP_SECONDS -- about a quarter second --
## so two purchases half a second apart never overlap and the serialisation guard never
## engages. The second flourish starts fresh and posts its steps behind the FIRST reveal,
## which is still on the row for five seconds. That refused the first reveal, which is the
## whole defect, and the first version of the fix passed every headless test while the live
## game stayed broken.
##
## Asserted through `_row_ready_for_a_flourish` rather than by sleeping: the row is put in
## the state a live reveal creates, and the predicate that guards the flourish is asked
## whether it would wait. Sleeping a real 3.8 seconds in a unit test buys nothing.
func test_a_flourish_waits_for_a_reveal_that_is_still_being_read() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var hud: Hud = game.hud
	hud._process(9.0)
	# Exactly what a reveal leaves behind: IMPORTANT, five seconds.
	hud.show_message(Hud.packet_message("Chomp Flower"), 5.0, Hud.MESSAGE_IMPORTANT)
	var err: String = _T.assert_true(
		hud.message_seconds_left() > Hud.MESSAGE_MIN_READABLE,
		"a fresh reveal has more than MESSAGE_MIN_READABLE left, so an equal-priority "
			+ "post would queue behind it rather than replace it")
	if err == "":
		err = _T.assert_eq(hud.message_priority(), Hud.MESSAGE_IMPORTANT,
			"and it sits at the priority a flourish step also posts at")
	if err == "":
		# Once it has been read down, the next flourish may go: this is the condition
		# _row_ready_for_a_flourish waits for, and the reason it asks the ROW instead of
		# subtracting MESSAGE_MIN_READABLE from a hard-coded 5.0 in a fourth place.
		hud._process(5.0 - Hud.MESSAGE_MIN_READABLE + 0.01)
		err = _T.assert_true(hud.message_seconds_left() <= Hud.MESSAGE_MIN_READABLE,
			"after MESSAGE_MIN_READABLE remains, an equal-priority post replaces it")
	if err == "":
		# An AMBIENT line must NOT make a flourish wait -- it is preempted, and waiting for
		# it would delay every packet behind a husk notice for no reason.
		hud.show_message("a husk rotted away", 4.0, Hud.MESSAGE_NORMAL)
		# It QUEUES rather than taking the row -- a lower priority never stomps a higher
		# one, so the reveal has to expire before the ambient line is what is showing. That
		# is the row's rule, and asserting the ambient case without it was this test's own
		# first failure.
		hud._process(2.0)
		err = _T.assert_true(hud.message_priority() < Hud.MESSAGE_IMPORTANT,
			"an ambient line sits below a flourish, so the flourish preempts rather than "
				+ "queues and there is nothing to wait for")
	_T.free_ui(game)
	return err
