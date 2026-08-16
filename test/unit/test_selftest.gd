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
		pest.mutation = mutation
		err = _T.assert_true(pest.husk_multiplier() > 1.0, "%s costs more to deal with, so its husk pays more" % mutation)
		if err != "":
			break
	pest.free()
	return err


## Hungry destroys a plant outright rather than merely delaying it (armoured/
## winged just cost extra effort) — its husk should be worth the most.
func test_a_hungry_mutations_husk_is_worth_more_than_armoured_or_winged() -> String:
	var pest := Pest.new()
	pest.mutation = Pest.MUTATION_HUNGRY
	var hungry: float = pest.husk_multiplier()
	pest.mutation = Pest.MUTATION_ARMOURED
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

	game.spawn_pest(Pest.APHID, Pest.MUTATION_HUNGRY)
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
		err = _T.assert_true(is_instance_valid(pest), "the corpse lingers on screen instead of vanishing instantly")
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
		err = _T.assert_eq(built.size, want, "%s fills the viewport it read out of ProjectSettings" % who)
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
			"v%d\n0\n0\nm0\ncb0 sfx0 mus0\n1\ngarden_pause %d\n" % [RunConfig.SAVE_VERSION, KEY_F1],
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
		(screen.get_node("ResetButton") as Button).pressed.emit()
		err = _T.assert_eq(KeyBindings.keys_for(KeyBindings.ACTION_PAUSE), [KEY_ESCAPE, KEY_P],
			"Put them all back restores the shipped keys")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(path),
				"v%d\n0\n0\nm0\ncb0 sfx0 mus0\n0\n" % RunConfig.SAVE_VERSION,
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
		err = _T.assert_true(screen.get_node_or_null("RowButton%d" % screen.rows().size()) == null,
			"and there is no row for a switch that does not exist")
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
				"v%d\n0\n0\nm0\ncb1 sfx0 mus0\n0\n" % RunConfig.SAVE_VERSION,
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


## The sizing constants are pinned to real drops, so this checks the two ends
## the game can actually produce still land at distinguishable sizes: a plain
## aphid husk and a hungry beetle's.
func test_the_husks_the_game_really_drops_span_the_size_range() -> String:
	var aphid: int = maxi(1, int(ceil(int(Pest.SPECIES[Pest.APHID]["seeds"]) / 2.0)))
	var beetle_value: float = int(Pest.SPECIES[Pest.BEETLE]["seeds"]) / 2.0
	var beetle: int = maxi(1, int(ceil(beetle_value * float(Pest.MUTATION_HUSK_MULTIPLIER[Pest.MUTATION_HUNGRY]))))
	var err: String = _T.assert_eq(HuskLayer.radius_for(aphid), HuskLayer.BASE_RADIUS,
		"a plain aphid husk (%d seeds) is the baseline size" % aphid)
	if err == "":
		err = _T.assert_eq(HuskLayer.radius_for(beetle), HuskLayer.MAX_RADIUS,
			"a hungry beetle husk (%d seeds) is the largest size" % beetle)
	if err == "":
		err = _T.assert_eq(HuskLayer.glow_for(beetle), 1.0, "and glows at full brightness")
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
func test_pest_scaling_is_exactly_neutral_through_the_fixed_table() -> String:
	for w: int in range(1, WaveDirector.WAVES.size() + 1):
		var err: String = _T.assert_float_eq(WaveDirector.health_scale_for(w), 1.0, 0.0001,
			"wave %d health is unscaled" % w)
		if err == "":
			err = _T.assert_float_eq(WaveDirector.speed_scale_for(w), 1.0, 0.0001,
				"wave %d speed is unscaled" % w)
		if err != "":
			return err
	return ""


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
		err = _T.assert_true(WaveDirector.threat_level(table) <= 10,
			"the whole campaign fits in single digits (wave %d is level %d)"
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
		err = _T.assert_eq(game.request_uproot(), "confirm needed", "armed")
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
	game.bank.add_seeds(300)
	var err: String = ""
	# Every plant kind, each at 1 hp -- the longest the panel ever gets, since that
	# is a wrapped name line, a state line and the health line all at once.
	for id: StringName in PlantCatalog.ids():
		if err != "":
			break
		var cell: Vector2i = _grass(game)
		if game.place_plant(id, cell) != "":
			continue
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
	for count: int in range(1, 11):
		var layout: Dictionary = Hud.plant_bar_layout(count)
		var rows: int = int(layout["rows"])
		var height: float = float(layout["height"])
		var used: float = float(rows) * height + float(Hud.PLANT_BAR_SEPARATION * (rows - 1))
		err = _T.assert_true(used <= span + 0.01,
			"%d plant(s): %d row(s) at %.1fpx use %.1f of %.1f available"
				% [count, rows, height, used, span])
		if err == "":
			err = _T.assert_true(height >= Hud.PLANT_BUTTON_MIN_HEIGHT,
				"%d plant(s): a %.1fpx button is below the %dpx touch minimum"
					% [count, height, int(Hud.PLANT_BUTTON_MIN_HEIGHT)])
		if err == "":
			err = _T.assert_false(bool(layout.get("overflows", false)),
				"%d plant(s) still fits without the bar needing to scroll" % count)
		if err != "":
			return err
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


func test_a_packet_tooltip_counts_what_its_tier_can_actually_reach() -> String:
	var common: String = Hud.packet_tooltip(&"common")
	var rare: String = Hud.packet_tooltip(&"rare")
	var cap: int = int((SeedBank.PACKET_TIERS[&"common"] as Dictionary)["max_tier"])
	var within: int = 0
	var beyond: int = 0
	for id: StringName in PlantCatalog.ids():
		if PlantCatalog.tier(id) <= cap:
			within += 1
		else:
			beyond += 1
	var err: String = _T.assert_gt(within, 0, "there is something at or below the common cap")
	if err == "":
		err = _T.assert_gt(beyond, 0, "and something above it, or the tiers mean nothing")
	if err == "":
		err = _T.assert_true(common.contains(str(within)),
			"the common tooltip counts what it can reach (%d), got: %s" % [within, common])
	if err == "":
		err = _T.assert_true(common.contains(str(beyond)),
			"and says how many it cannot (%d), got: %s" % [beyond, common])
	if err == "":
		err = _T.assert_true(rare.contains(str(PlantCatalog.ids().size())),
			"the rare tooltip counts the whole catalogue (%d), got: %s"
				% [PlantCatalog.ids().size(), rare])
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
			RunConfig.compose_save(3, 4, "m0", "cb0 sfx0 mus0", {"garden_pause": [KEY_F1, KEY_F2]}),
			"v%d\n3\n4\nm0\ncb0 sfx0 mus0\n1\ngarden_pause %d %d\n" % [RunConfig.SAVE_VERSION, KEY_F1, KEY_F2],
			"compose_save writes the header, both scores, the milestones, the options, "
				+ "the count, then the rows")
	if err == "":
		err = _T.assert_eq(RunConfig.compose_save(0, 0, "m0", "cb0 sfx0 mus0", {}),
			"v%d\n0\n0\nm0\ncb0 sfx0 mus0\n0\n" % RunConfig.SAVE_VERSION,
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
			"v%d\n11\n22\nm0\ncb0 sfx0 mus0\n1\ngarden_mute_music %d\n" % [RunConfig.SAVE_VERSION, KEY_F7],
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
	for i: int in range(rows):
		if err != "":
			break
		var row: Label = screen.get_node_or_null("KeyRow%d" % i) as Label
		err = _T.assert_true(row != null, "KeyRow%d is on the card" % i)
		if err != "":
			break
		# (1) the box. A row whose Label won its own width back is already off the
		# paper whatever the text says.
		var right: float = row.global_position.x + row.size.x
		err = _T.assert_true(right <= paper_right + 0.5,
			"KeyRow%d's box ends at %.0f, the paper ends at %.0f -- the assigned width lost to the Label's minimum size (set clip_text and font_size BEFORE size)"
				% [i, right, paper_right])
		if err != "":
			break
		# (2) the text, measured through the font rather than through a
		# get_minimum_size() that clip_text has already reduced to a stub.
		var drawn: float = _T.text_width(row)
		err = _T.assert_gt(drawn, 0.0, "KeyRow%d has text to measure" % i)
		if err != "":
			break
		err = _T.assert_true(drawn <= PauseScreen.KEY_ROW_MAX_WIDTH,
			"KeyRow%d draws %.0fpx, budget is %.0f -- shorten the 'does' phrase in KeyBindings.ACTIONS, or widen the card (%s)"
				% [i, drawn, PauseScreen.KEY_ROW_MAX_WIDTH, row.text])

	game.resume_run()
	_T.free_ui(game)
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
#     - the dead-ground count (15 of 94 cells).
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
func test_the_road_is_still_the_road_the_constants_were_measured_against() -> String:
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
		+ "\n    - the dead-ground count (15 of 94 cells)" \
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
func test_the_suite_reach_checker_still_declares_its_house_contract() -> String:
	var src: String = FileAccess.get_file_as_string(SUITE_REACH_CHECKER)
	var err: String = _T.assert_gt(src.length(), 0,
		"tools/suite_reach_check.py is readable -- every assertion below is"
		+ " vacuous against an empty string")
	if err != "":
		return err
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
	return ""


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
func test_no_test_persists_through_the_players_own_save() -> String:
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


# -- The Aphid Queen, and eight more waves to meet her in (plant-tower-defense-74a) --
#
# The boss is deliberately NOT a fourth mutation and deliberately not "a beetle
# with more health". What makes her a different fight is that she bursts into
# three aphids AT THE SPOT SHE FALLS, so killing her is a decision about WHERE
# rather than about whether — the only thing on this board that makes the player
# care where a kill lands. Everything below is that claim, and the arithmetic
# under it, made checkable without a running game.


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
	## while wave 16 lands on 40 exactly. Sweeping the fixed table is therefore no
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
