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


func test_a_dead_pest_leaves_a_collectible_husk() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.spawn_pest(Pest.APHID)
	var pest: Pest = game.get_tree().get_nodes_in_group("pests")[0] as Pest
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
	game.spawn_pest(Pest.APHID)
	var plain: Pest = game.get_tree().get_nodes_in_group("pests")[0] as Pest
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
		"Sprite", "Caption", "NoteLabel", "PrevButton", "PageLabel", "NextButton",
	]:
		var node: Control = notebook.get_node(node_name) as Control
		var rect := Rect2(node.position, node.size)
		err = _T.assert_true(paper.encloses(rect), "%s at %s sits on the paper %s" % [node_name, rect, paper])
		if err != "":
			break
	_T.free_ui(notebook)
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
	for node_name: String in ["StartButton", "EndlessButton", "NotebookButton", "HintLabel"]:
		var node: Control = title.get_node(node_name) as Control
		var bottom: float = node.position.y + node.size.y
		err = _T.assert_true(bottom <= horizon,
			"%s ends at %.0f, clear of the horizon at %.0f" % [node_name, bottom, horizon])
		if err != "":
			break
	_T.free_ui(title)
	return err


func test_title_focus_ring_wraps_in_both_directions() -> String:
	## Godot's geometric focus default walks the list and stops at each end. The
	## hint on screen says "Up / Down to choose", so it has to be a ring.
	var title := await _T.instantiate_ui("res://game/title.tscn", Vector2i(1152, 648)) as Control
	var start: Button = title.get_node("StartButton") as Button
	var last: Button = title.get_node("NotebookButton") as Button
	var err: String = _T.assert_eq(String(start.get_node(start.focus_neighbor_top).name), "NotebookButton",
		"Up from the first button reaches the last")
	if err == "":
		err = _T.assert_eq(String(last.get_node(last.focus_neighbor_bottom).name), "StartButton",
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
	game.spawn_pest(Pest.APHID)
	var early: Pest = game.get_tree().get_nodes_in_group("pests")[0] as Pest
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
func test_the_threat_tint_climbs_from_cream_to_red() -> String:
	var err: String = _T.assert_true(Hud.threat_color(1).is_equal_approx(Hud.PAPER),
		"below the show-from level the readout is the bar's own cream")
	if err == "":
		err = _T.assert_true(Hud.threat_color(Hud.THREAT_SHOW_FROM).is_equal_approx(Hud.PAPER),
			"and still cream at the level the number first appears")
	if err == "":
		err = _T.assert_true(Hud.threat_color(Hud.THREAT_TINT_MAX).is_equal_approx(Hud.THREAT_HOT),
			"fully red at the ceiling")
	if err == "":
		# Endless runs past the ceiling for hundreds of waves; the tint must pin
		# rather than wrap, overshoot or start cooling off again.
		err = _T.assert_true(Hud.threat_color(Hud.THREAT_TINT_MAX * 4).is_equal_approx(Hud.THREAT_HOT),
			"and stays red far past it")
	if err == "":
		# Monotonic in the direction that matters: never gets less red as it climbs.
		var previous: float = -1.0
		for level: int in range(1, Hud.THREAT_TINT_MAX + 2):
			var heat: float = Hud.threat_color(level).r - Hud.threat_color(level).g
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
	_T.free_ui(game)
	return err


# -- The wave banner (plant-tower-defense-1ci) -------------------------------
#
# The HUD's Banner had no callers at all once RunSummary replaced the
# end-of-run banner: `show_banner`/`hide_banner` were dead, and the node was
# built on every launch only ever to stay hidden. It was given the one job it is shaped
# for -- announcing a wave -- instead of being deleted, and these are the
# checks that keep it from drifting back to either failure mode: a surface
# nobody calls, or a second dumping ground for status lines.


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
		err = _T.assert_eq(String(Hud.BANNER_WORST_CASE_TEXT["Banner"]), Hud.wave_headline(9999),
			"and so is the budgeted headline")
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
## key and forgets. This reads the KEY_* constants out of Game's own source and
## asserts KEY_HELP covers every one, so adding a binding without documenting it
## fails the build rather than quietly shipping an undiscoverable verb.
func test_every_key_the_run_handles_is_named_on_the_pause_card() -> String:
	var src: String = FileAccess.get_file_as_string("res://game/game.gd")
	var err: String = _T.assert_gt(src.length(), 0, "game.gd is readable")
	if err != "":
		return err

	# Only the input handler's own body -- the table itself also mentions KEY_*,
	# and counting those would let the list vouch for itself.
	var start: int = src.find("func _unhandled_input")
	err = _T.assert_gt(start, 0, "found _unhandled_input")
	if err != "":
		return err
	var following: int = src.find("\nfunc ", start + 1)
	var body: String = src.substr(start, (following - start) if following > start else -1)

	var handled: Array[String] = []
	var regex := RegEx.new()
	regex.compile("KEY_[A-Z0-9_]+")
	for m: RegExMatch in regex.search_all(body):
		var name: String = m.get_string()
		if not handled.has(name):
			handled.append(name)
	err = _T.assert_gt(handled.size(), 0,
		"the handler references at least one key -- an empty scan would pass vacuously")
	if err != "":
		return err

	var documented: Array[String] = []
	for row: Dictionary in Game.KEY_HELP:
		for code: int in (row["codes"] as Array):
			documented.append(OS.get_keycode_string(code).to_upper())

	for name: String in handled:
		var bare: String = name.substr(4)  # KEY_ESCAPE -> ESCAPE
		err = _T.assert_true(documented.has(bare),
			"_unhandled_input answers to %s and KEY_HELP does not mention it; documented: %s"
				% [name, documented])
		if err != "":
			return err
	return err


func test_the_pause_card_lists_the_keys_and_still_fits_its_paper() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.pause_run()
	await _pump(game)
	var screen: Control = game.get_node_or_null("PauseLayer/PauseScreen") as Control
	var err: String = _T.assert_true(screen != null, "the card is up")
	if err == "":
		err = _T.assert_gt(Game.KEY_HELP.size(), 0, "there are bindings to list")
	if err == "":
		for i: int in range(Game.KEY_HELP.size()):
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
	return err
