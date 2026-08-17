extends RefCounted

## Plants versus bugs — the two behaviours the drawings actually specify.
##
## Corn: "one cob firing one kernel" upgrading to a spread labelled "bunch of
## corn". Chomp: "eats small pests easily, takes a while eating bigger pests".
## The second one is a balance lever, not a flavour note, so the occupancy is
## asserted here rather than assumed.

var _T

## Where this script's RunConfig writes go instead of the player's own save.
## See setup() below.
const SUITE_SAVE_PATH := "user://test_combat_suite.save"
var _suite_stashed_save_path: String = ""


## Point RunConfig away from `user://highscore.save` for every test in this file.
##
## Not a precaution: a run of this suite provably wrote the developer's real save,
## found by instrumenting `RunConfig._save()` with `get_stack()`. Neither writer
## named a RunConfig method — one went `Game.bank_score() -> record_score()`, the
## other `Game._unhandled_input() -> toggle_colorblind_safe()` — so the source scan
## that guards direct calls could not see either, and the second happened to write
## the same bytes back, leaving only an mtime as evidence.
##
## The redirect lives here rather than in each test because every write along those
## chains is CONDITIONAL (a score above the record, a fresh milestone, an actual
## change), so which tests write is not knowable by reading them, and a test written
## next month inherits this without knowing it exists. Enforced by
## `tools/save_persist_check.py`, which derives the reaching set from `_save()`
## backwards rather than from a list anyone has to maintain.
func setup() -> void:
	_suite_stashed_save_path = RunConfig.save_path
	RunConfig.save_path = SUITE_SAVE_PATH


func teardown() -> void:
	if _suite_stashed_save_path != "":
		RunConfig.save_path = _suite_stashed_save_path
	DirAccess.remove_absolute(SUITE_SAVE_PATH)


func _host(nodes: Array[Node]) -> Node2D:
	var container := Node2D.new()
	container.name = "CombatHost"
	for node: Node in nodes:
		container.add_child(node)
	return container


func _pest(species: StringName, at: Vector2) -> Pest:
	var pest := Pest.new()
	pest.setup(species, PackedVector2Array([at, at + Vector2(600, 0)]))
	pest.position = at
	pest.set_physics_process(false)
	return pest


# -- Chomp Flower -----------------------------------------------------------


func test_a_chomp_holds_a_beetle_far_longer_than_an_aphid() -> String:
	## This ratio IS the balance: a beetle that walks into a Chomp buys the lane
	## seconds, and buys the player's other lanes nothing.
	var aphid: float = float(Pest.SPECIES[Pest.APHID]["chew_seconds"])
	var beetle: float = float(Pest.SPECIES[Pest.BEETLE]["chew_seconds"])
	return _T.assert_gt(beetle, aphid * 3.0,
		"a beetle should occupy the mouth several times as long as an aphid (%.2fs vs %.2fs)" % [beetle, aphid])


func test_a_chomp_can_reach_the_lane_it_is_planted_beside() -> String:
	## Regression: a Chomp stands on grass, the pest walks the middle of the road,
	## so the nearest they ever get is exactly one cell. A grab radius under CELL
	## makes the plant inert — and inert looks exactly like "no pest in range".
	var chomp := ChompFlower.new()
	var pest: Pest = _pest(Pest.APHID, Vector2(0, -Board.CELL))
	var host: Node2D = _host([chomp, pest])
	await _T.instantiate_scene(host)

	var pests: Array[Pest] = [pest]
	chomp._act(0.016, pests)
	var err: String = _T.assert_true(chomp.is_busy(),
		"a pest one full cell away (%d px) is inside a %.0f px reach" % [Board.CELL, ChompFlower.GRAB_RADIUS])
	if err == "":
		err = _T.assert_true(ChompFlower.GRAB_RADIUS < Board.CELL * 2.0,
			"but not so far it eats out of the lane two cells over")
	_T.free_ui(host)
	return err


func test_a_chewing_chomp_holds_the_pest_still() -> String:
	var chomp := ChompFlower.new()
	var beetle: Pest = _pest(Pest.BEETLE, Vector2.ZERO)
	var host: Node2D = _host([chomp, beetle])
	await _T.instantiate_scene(host)

	var pests: Array[Pest] = [beetle]
	chomp._act(0.016, pests)
	var err: String = _T.assert_true(chomp.is_busy(), "the flower grabbed the beetle in range")
	if err == "":
		err = _T.assert_true(beetle.held_by == chomp, "the beetle knows what has hold of it")
	if err == "":
		var before: Vector2 = beetle.position
		beetle.set_physics_process(true)
		beetle._physics_process(0.5)
		err = _T.assert_eq(beetle.position, before, "a held pest does not advance down the road")
	_T.free_ui(host)
	return err


func test_a_busy_chomp_ignores_everything_else_in_reach() -> String:
	var chomp := ChompFlower.new()
	var beetle: Pest = _pest(Pest.BEETLE, Vector2.ZERO)
	var aphid: Pest = _pest(Pest.APHID, Vector2(6, 0))
	var host: Node2D = _host([chomp, beetle, aphid])
	await _T.instantiate_scene(host)

	var pests: Array[Pest] = [beetle, aphid]
	chomp._act(0.016, pests)
	chomp._act(0.016, pests)
	var err: String = _T.assert_true(aphid.held_by == null,
		"the second pest walks straight past an occupied mouth — this is the whole cost of a Chomp")
	if err == "":
		err = _T.assert_true(aphid.is_alive(), "and is still alive to prove it")
	_T.free_ui(host)
	return err


func test_a_chomp_swallows_its_meal_and_frees_up() -> String:
	var chomp := ChompFlower.new()
	var aphid: Pest = _pest(Pest.APHID, Vector2.ZERO)
	var host: Node2D = _host([chomp, aphid])
	await _T.instantiate_scene(host)

	var pests: Array[Pest] = [aphid]
	chomp._act(0.016, pests)
	chomp._act(aphid.chew_seconds + 0.01, pests)
	var err: String = _T.assert_false(aphid.is_alive(), "the aphid was eaten")
	if err == "":
		err = _T.assert_false(chomp.is_busy(), "and the mouth is free again")
	_T.free_ui(host)
	return err


func test_a_pest_shot_out_of_the_mouth_does_not_wedge_the_flower_shut() -> String:
	## A kernel can kill whatever the Chomp is holding. If Pest.kill() did not
	## call back into release(), the flower would stay busy forever with a freed
	## instance — a bug that looks exactly like "that plant stopped working".
	var chomp := ChompFlower.new()
	var beetle: Pest = _pest(Pest.BEETLE, Vector2.ZERO)
	var host: Node2D = _host([chomp, beetle])
	await _T.instantiate_scene(host)

	var pests: Array[Pest] = [beetle]
	chomp._act(0.016, pests)
	var err: String = _T.assert_true(chomp.is_busy(), "the beetle is in the mouth")
	if err == "":
		beetle.take_damage(beetle.max_health)
		err = _T.assert_false(chomp.is_busy(), "killing the held pest releases the flower")
	_T.free_ui(host)
	return err


# -- Corn Cobbler -----------------------------------------------------------


func test_the_corn_ladder_gets_strictly_wider_each_level() -> String:
	var corn := CornCobbler.new()
	var previous: int = 0
	for level: int in range(1, corn.max_level() + 1):
		corn.level = level
		var kernels: int = corn.kernels_per_shot()
		var err: String = _T.assert_gt(kernels, previous,
			"level %d (%s) fires more kernels than level %d" % [level, corn.level_name(), level - 1])
		if err != "":
			corn.free()
			return err
		previous = kernels
	var last: String = corn.level_name()
	corn.free()
	return _T.assert_eq(last, "bunch", "the top of the ladder is the doc's 'bunch of corn'")


func test_upgrading_stops_at_the_top_and_costs_nothing_there() -> String:
	var corn := CornCobbler.new()
	while corn.upgrade():
		pass
	var err: String = _T.assert_true(corn.is_max_level(), "the ladder terminates")
	if err == "":
		err = _T.assert_eq(corn.upgrade_cost(), 0, "a fully grown cob has no price to quote")
	if err == "":
		err = _T.assert_false(corn.upgrade(), "and refuses to grow further")
	corn.free()
	return err


func test_a_headless_upgrade_does_not_queue_a_flourish_tween() -> String:
	## _upgrade_flourish() is gated on GardenTheme.animations_enabled(), which is
	## always false headless -- unlike _build_visuals()'s pop-in and _recoil(),
	## which only check is_inside_tree(). Attach to a real tree so that guard is
	## exercised too (unattached, as the test above leaves it, is_inside_tree()
	## alone would already have skipped it), and prove the flourish queues
	## nothing by reading scale immediately before and after upgrade() with no
	## frame between the two reads -- only a Tween already ticking could move it.
	var corn := CornCobbler.new()
	corn.setup(PlantCatalog.CORN, Vector2i(0, 0), null)
	var host: Node2D = _host([corn])
	await _T.instantiate_scene(host)
	var before: Vector2 = corn._sprite.scale
	var err: String = _T.assert_true(corn.upgrade(), "the upgrade itself still lands")
	if err == "":
		err = _T.assert_eq(corn.level, 2, "and the level moved")
	if err == "":
		err = _T.assert_eq(corn._sprite.scale, before,
			"no new Tween was queued -- animations_enabled() is false headless")
	_T.free_ui(host)
	return err


func test_a_shot_puts_the_declared_number_of_kernels_on_the_board() -> String:
	var corn := CornCobbler.new()
	corn.level = corn.max_level()
	var aphid: Pest = _pest(Pest.APHID, Vector2(80, 0))
	var host: Node2D = _host([corn, aphid])
	await _T.instantiate_scene(host)

	# The cob starts loaded, so hosting it next to a pest already fires one volley
	# during the settle frames. Count the delta across one more shot, not the total.
	var before: int = host.get_tree().get_nodes_in_group("kernels").size()
	var pests: Array[Pest] = [aphid]
	corn._act(1.0, pests)
	var fired: int = host.get_tree().get_nodes_in_group("kernels").size() - before
	var err: String = _T.assert_eq(fired, corn.kernels_per_shot(),
		"a 'bunch of corn' shot puts %d kernels in the air" % corn.kernels_per_shot())
	_T.free_ui(host)
	return err


func test_kernels_launch_from_the_cob_on_an_offset_layer() -> String:
	## Regression: the entities layer sits below the top bar, so a kernel seeded
	## from `global_position` into a SIBLING's space starts a whole bar-height
	## below the cob and misses everything. Every pest and plant agreed with each
	## other, so nothing failed — the corn just quietly never hit anything.
	var corn := CornCobbler.new()
	corn.position = Vector2(160, 160)
	var aphid: Pest = _pest(Pest.APHID, Vector2(220, 160))
	var host: Node2D = _host([corn, aphid])
	host.position = Vector2(0, 72)
	await _T.instantiate_scene(host)

	var pests: Array[Pest] = [aphid]
	# The group is global to the tree, so it can hold kernels another test fired
	# and never freed. Taking kernels[0] therefore measured whichever kernel
	# happened to be first, and this test passed or failed on the order the suite
	# ran in: green in a full run, red on its own, at HEAD and with any change
	# that shifted the order. Diff the group instead, so it can only ever measure
	# the kernel this cob just launched.
	var before: Dictionary = {}
	for k: Node in host.get_tree().get_nodes_in_group("kernels"):
		before[k.get_instance_id()] = true
	corn._act(1.0, pests)
	var fired: Array[Kernel] = []
	for k: Node in host.get_tree().get_nodes_in_group("kernels"):
		if not before.has(k.get_instance_id()) and k is Kernel:
			fired.append(k as Kernel)
	var err: String = _T.assert_gt(fired.size(), 0, "the cob fired")
	if err == "":
		var kernel: Kernel = fired[0]
		err = _T.assert_true(kernel.position.distance_to(corn.position) < 1.0,
			"the kernel starts at the cob (%s), not %s" % [corn.position, kernel.position])
	_T.free_ui(host)
	return err


func test_corn_shoots_the_pest_closest_to_escaping() -> String:
	## Nearest-target is the obvious implementation and the wrong one: leaking a
	## pest costs a life, so the one furthest along always matters most.
	var corn := CornCobbler.new()
	var route := PackedVector2Array([
		Vector2(0, 0), Vector2(40, 0), Vector2(80, 0), Vector2(120, 0), Vector2(160, 0),
	])
	var near := Pest.new()
	near.setup(Pest.APHID, route)
	near.position = Vector2(20, 0)
	near.set_physics_process(false)
	var far := Pest.new()
	far.setup(Pest.APHID, route)
	far.position = Vector2(150, 0)
	far.set_physics_process(false)
	# 3, not 4. The route has five points, so `_leg >= _route.size()` at 5 -- but
	# `_advance` reaches that check during the settle frames `instantiate_scene`
	# pumps, and at leg 4 the pest is on its final step: it escaped and freed itself
	# before this test ever looked at it. `target == far` then compared two freed
	# references and passed, so the rule this test is named for has never actually
	# been checked. Leg 3 is the last leg a pest can sit on and still be here.
	far._leg = 3

	var host: Node2D = _host([corn, near, far])
	await _T.instantiate_scene(host)
	# Asserted, not assumed, and this is the assertion that would have caught a
	# harness regression as a FAILURE rather than as an access violation: under
	# harness 0.42.0 one of these is already freed by this line. Plant's own guard
	# now skips a stale entry, which is right for a shipped game and would leave this
	# test quietly targeting whichever pest survived -- so the test says out loud
	# that both are still here before it asks which one is chosen.
	var err_alive: String = _T.assert_true(
		is_instance_valid(near) and is_instance_valid(far),
		"both pests survived the settle frames -- if this fails, the hosting freed "
			+ "one of them and the targeting answer below is about a set of one")
	if err_alive != "":
		_T.free_ui(host)
		return err_alive
	var candidates: Array[Pest] = [near, far]
	var target: Pest = corn._furthest_along_in_range(candidates, CornCobbler.RANGE)
	var err: String = _T.assert_true(target == far,
		"targets the pest at progress %.2f, not the closer one at %.2f" % [far.progress(), near.progress()])
	_T.free_ui(host)
	return err


func test_corn_readiness_fades_out_on_fire_and_recovers_over_the_reload() -> String:
	## Pure math first: readiness_at() is exactly what _draw_muzzle_fan's fade reads.
	var err: String = _T.assert_float_eq(CornCobbler.readiness_at(0.0, 0.8), 1.0, 0.0001,
		"no cooldown left reads as fully armed")
	if err == "":
		err = _T.assert_float_eq(CornCobbler.readiness_at(0.8, 0.8), 0.0, 0.0001,
			"a freshly fired cob reads as just-fired")
	if err == "":
		err = _T.assert_float_eq(CornCobbler.readiness_at(0.4, 0.8), 0.5, 0.0001,
			"halfway through the reload reads as half-armed")
	if err != "":
		return err

	## Then driven through the real _act(), the way Sunflower's yield_progress()
	## test proves its gauge against the wiring rather than the algebra alone —
	## this is the clock _draw_muzzle_fan's fade actually reads.
	var corn := CornCobbler.new()
	var aphid: Pest = _pest(Pest.APHID, Vector2(80, 0))
	var host: Node2D = _host([corn, aphid])
	await _T.instantiate_scene(host)
	corn.set_physics_process(false)
	corn._cooldown = 0.0

	var pests: Array[Pest] = [aphid]
	corn._act(1.0, pests)
	var interval: float = corn.fire_interval()
	err = _T.assert_float_eq(corn.readiness(), 0.0, 0.0001, "firing resets readiness to 0")
	var no_pests: Array[Pest] = []
	if err == "":
		for i: int in range(6):
			corn._act(interval / 6.0, no_pests)
			var expected: float = clampf(float(i + 1) / 6.0, 0.0, 1.0)
			err = _T.assert_float_eq(corn.readiness(), expected, 0.0001,
				"step %d of the reload reads %.4f, matching elapsed/interval" % [i, corn.readiness()])
			if err != "":
				break
	_T.free_ui(host)
	return err


# -- Waves ------------------------------------------------------------------


func test_every_wave_in_the_table_sends_someone() -> String:
	var director := WaveDirector.new()
	var count: int = director.wave_count()
	var err: String = _T.assert_gt(count, 0, "there is a wave table at all")
	if err != "":
		director.free()
		return err
	for wave: int in range(1, count + 1):
		err = _T.assert_gt(WaveDirector.pests_in_wave(wave), 0, "wave %d sends at least one pest" % wave)
		if err != "":
			director.free()
			return err
	director.free()
	return ""


func test_the_waves_get_harder() -> String:
	var director := WaveDirector.new()
	var first: int = WaveDirector.pests_in_wave(1)
	var last: int = WaveDirector.pests_in_wave(director.wave_count())
	director.free()
	return _T.assert_gt(last, first * 2,
		"the last wave (%d pests) is more than twice the first (%d)" % [last, first])


func test_a_started_wave_schedules_exactly_the_pests_the_table_promises() -> String:
	## The HUD tells the player "Wave 3 — 9 pests" straight off the table, so a
	## schedule that disagrees with it is a lie on screen.
	var director := WaveDirector.new()
	var host: Node2D = _host([director])
	await _T.instantiate_scene(host)

	var spawned: Array[StringName] = []
	director.spawn_requested.connect(func(species: StringName, _mutation: StringName) -> void: spawned.append(species))
	director.start_next_wave()
	var guard: int = 0
	while director.is_spawning() and guard < 4000:
		director._process(0.1)
		guard += 1
	var err: String = _T.assert_eq(spawned.size(), WaveDirector.pests_in_wave(1),
		"wave 1 spawned what the table advertises")
	_T.free_ui(host)
	return err


# -- Mutation cues ----------------------------------------------------------
#
# A mutation used to be a tint and nothing else, and two of the three change
# what the player has to do about the bug. These assert the marker SET rather
# than pixels: Pest.markers_for() is the whole input to Pest._draw(), so a cue
# that disappeared from the screen would have to disappear from here first.


func test_a_plain_pest_wears_no_mutation_marker() -> String:
	## The baseline every other marker is read against. If an unmutated pest wore
	## anything, the marks below would be decoration instead of a warning.
	var aphid: Pest = _pest(Pest.APHID, Vector2.ZERO)
	var err: String = _T.assert_eq(aphid.markers().size(), 0,
		"an ordinary bug is unmarked, which is what makes a marked one mean something")
	aphid.free()
	return err


func test_each_mutation_wears_a_mark_no_other_mutation_wears() -> String:
	## Shape, not hue — so the distinction survives a colour-blind player and a
	## greyscale screenshot, neither of which a tint comparison would.
	var by_mutation: Dictionary = {
		Pest.MUTATION_ARMOURED: Pest.markers_for(true, false, false),
		Pest.MUTATION_WINGED: Pest.markers_for(false, true, false),
		Pest.MUTATION_HUNGRY: Pest.markers_for(false, false, true),
	}
	var already_used: Array[StringName] = []
	for which: StringName in by_mutation:
		var marks: Array[StringName] = by_mutation[which]
		var err: String = _T.assert_eq(marks.size(), 1,
			"'%s' draws exactly one mark" % which)
		if err != "":
			return err
		err = _T.assert_false(already_used.has(marks[0]),
			"'%s' wears '%s', which no other mutation already wears" % [which, marks[0]])
		if err != "":
			return err
		already_used.append(marks[0])
	return ""


func test_a_pest_carrying_two_mutations_wears_both_marks() -> String:
	## `mutation` only remembers the last trait applied, so a marker set derived
	## from it would silently drop one. The flags are the truth; markers() reads
	## those, the same place ChompFlower reads `is_winged` from.
	var beetle: Pest = _pest(Pest.BEETLE, Vector2.ZERO)
	beetle.apply_mutation(Pest.MUTATION_WINGED)
	beetle.apply_mutation(Pest.MUTATION_HUNGRY)
	var marks: Array[StringName] = beetle.markers()
	var err: String = _T.assert_eq(marks.size(), 2,
		"two traits on the bug means two marks on the bug")
	if err == "":
		err = _T.assert_true(marks.has(Pest.MARKER_WINGS),
			"the wings survive a second mutation being applied over them")
	if err == "":
		err = _T.assert_true(marks.has(Pest.MARKER_JAWS), "and the jaws are there too")
	beetle.free()
	return err


func test_the_winged_pest_a_chomp_cannot_grab_says_so_with_a_shape() -> String:
	## The rule and its cue asserted in one place. A Chomp declines a winged pest
	## in silence, which from the player's chair is indistinguishable from a
	## broken plant unless the bug itself is wearing something that explains it.
	var chomp := ChompFlower.new()
	var pest: Pest = _pest(Pest.APHID, Vector2(0, -Board.CELL))
	pest.apply_mutation(Pest.MUTATION_WINGED)
	var host: Node2D = _host([chomp, pest])
	await _T.instantiate_scene(host)

	var pests: Array[Pest] = [pest]
	chomp._act(0.016, pests)
	var err: String = _T.assert_false(chomp.is_busy(),
		"a Chomp that would have grabbed a plain pest at this range cannot close on a winged one")
	if err == "":
		err = _T.assert_true(pest.markers().has(Pest.MARKER_WINGS),
			"so the pest carries wings — the only warning the player gets before building a Chomp wall")
	_T.free_ui(host)
	return err


func test_a_hungry_pest_wears_jaws_because_a_bed_dies_in_seconds() -> String:
	## The number is why the cue exists: EAT_DPS against a full-health plant is
	## a bed gone before the player can finish reacting to the colour.
	var beetle: Pest = _pest(Pest.BEETLE, Vector2.ZERO)
	beetle.apply_mutation(Pest.MUTATION_HUNGRY)
	var seconds_to_eat_a_bed: float = Plant.MAX_HEALTH / Pest.EAT_DPS
	var err: String = _T.assert_true(seconds_to_eat_a_bed < 3.0,
		"a hungry pest destroys a full-health plant in %.2fs" % seconds_to_eat_a_bed)
	if err == "":
		err = _T.assert_true(beetle.markers().has(Pest.MARKER_JAWS),
			"which is why it wears a jaw mark and not just a red tint")
	beetle.free()
	return err


func test_every_mutation_the_game_can_roll_has_a_non_colour_cue() -> String:
	## The guard for the fourth mutation. MUTATION_HUSK_MULTIPLIER is the
	## canonical list of traits a wave can roll, so a new one added there without
	## a marker would ship as a hue and nothing else — the exact state this fixed.
	var err: String = _T.assert_gt(Pest.MUTATION_HUSK_MULTIPLIER.size(), 0,
		"there are mutations to check at all")
	if err != "":
		return err
	for which: StringName in Pest.MUTATION_HUSK_MULTIPLIER:
		var pest: Pest = _pest(Pest.APHID, Vector2.ZERO)
		pest.apply_mutation(which)
		err = _T.assert_eq(pest.markers().size(), 1,
			"'%s' is drawn as a shape, not only tinted" % which)
		pest.free()
		if err != "":
			return err
	return ""


# -- Sound ------------------------------------------------------------------
#
# The game shipped with no audio at all, so these assert the two things that are
# observable without a listener: that the table Sfx plays from points at files
# that really exist and really load, and that the gate deciding whether to play
# says what it should. Nothing here claims a sound was AUDIBLE — that is not
# observable headlessly, and a test that pretended otherwise would pass in
# exactly the situation this issue was filed about.


func test_every_sound_the_game_can_play_actually_loads() -> String:
	## The test the issue asks for by name. A typo'd path fails in the most
	## literal way sound can fail — silently — and it fails identically to the
	## bug being fixed here, so nothing downstream would ever catch it.
	var err: String = _T.assert_gt(Sfx.SOUNDS.size(), 0,
		"there is a sound table to check at all")
	if err != "":
		return err
	for event: StringName in Sfx.SOUNDS:
		var path: String = String(Sfx.SOUNDS[event])
		err = _T.assert_true(ResourceLoader.exists(path),
			"'%s' points at a file that exists: %s" % [event, path])
		if err != "":
			return err
		var stream: AudioStream = Sfx.stream_for(event)
		err = _T.assert_true(stream != null,
			"'%s' loads as an AudioStream, not just as a path that resolves (%s)" % [event, path])
		if err != "":
			return err
	return ""


func test_every_event_id_the_call_sites_use_is_in_the_table() -> String:
	## The other half of the same guard. The constants are what game.gd and
	## plant.gd actually pass, so a constant without a table row is a call site
	## that compiles, runs, returns false and makes no sound forever.
	var used: Array[StringName] = [
		Sfx.PLANT_PLACED, Sfx.PLANT_BITTEN, Sfx.PLANT_DESTROYED,
		Sfx.PEST_KILLED, Sfx.PEST_ESCAPED,
		Sfx.HUSK_COLLECTED, Sfx.HUSK_ROTTED,
		Sfx.WAVE_STARTED, Sfx.WAVE_CLEARED, Sfx.UPROOT_ARMED,
		Sfx.RUN_WON, Sfx.RUN_LOST, Sfx.PURCHASE_DENIED,
		Sfx.PLANT_UPGRADED, Sfx.PLANT_UPROOTED,
		Sfx.CORN_FIRED, Sfx.CHOMP_BITE, Sfx.SUNDEW_CLAIM,
		# The Bomb Dandelion's pair. Two ids and not one because the seed
		# leaving the head and the bomb bursting happen SeedBomb.FLIGHT_SECONDS
		# and up to Dandelion.RANGE apart — see Sfx.DANDELION_PUFF.
		Sfx.DANDELION_PUFF, Sfx.SEED_BOMB_BURST,
		Sfx.SEEDS_GROWN, Sfx.BUTTON_PRESSED,
	]
	for event: StringName in used:
		var err: String = _T.assert_true(Sfx.SOUNDS.has(event),
			"'%s' has a sound behind it" % event)
		if err != "":
			return err
	return _T.assert_eq(used.size(), Sfx.SOUNDS.size(),
		"and the table holds nothing the game never plays")


func test_playing_an_unknown_event_is_a_silent_no_op() -> String:
	## Sound is decoration on a game that has to keep running without it, so a
	## renamed or mistyped cue id must go quiet rather than take the frame with
	## it. `play()` returns false; nothing errors.
	var err: String = _T.assert_false(Sfx.should_play(&"no_such_cue", false, false),
		"an unknown event never reaches a voice, even unmuted with a display")
	if err == "":
		err = _T.assert_false(Sfx.play(&"no_such_cue"),
			"and play() reports that it did nothing instead of raising")
	if err == "":
		err = _T.assert_true(Sfx.stream_for(&"no_such_cue") == null,
			"there is no stream behind it to find")
	return err


func test_muting_suppresses_every_event_in_the_table() -> String:
	## Asserted against should_play() rather than against anything audible: it is
	## the whole decision play() makes, as a pure function, so it is the state
	## that drives playback and the only honest thing to assert headlessly.
	var err: String = _T.assert_gt(Sfx.SOUNDS.size(), 0, "there are events to mute")
	if err != "":
		return err
	for event: StringName in Sfx.SOUNDS:
		err = _T.assert_true(Sfx.should_play(event, false, false),
			"'%s' would play for a listening player" % event)
		if err != "":
			return err
		err = _T.assert_false(Sfx.should_play(event, true, false),
			"'%s' is suppressed by mute" % event)
		if err != "":
			return err
		err = _T.assert_false(Sfx.should_play(event, false, true),
			"'%s' is suppressed headless, which is why this suite is quiet" % event)
		if err != "":
			return err
	return ""


func test_the_mute_toggle_is_a_real_switch_and_leaves_no_sound_running() -> String:
	## The player-facing half (Game binds it to M). Restores the flag on every
	## path — a test that left the game muted would silence every run after it.
	var was_muted: bool = Sfx.is_muted()
	Sfx.set_muted(false)
	var err: String = _T.assert_true(Sfx.toggle_muted(), "one press mutes")
	if err == "":
		err = _T.assert_true(Sfx.is_muted(), "and the flag agrees with what it returned")
	if err == "":
		err = _T.assert_false(Sfx.audio_enabled(), "so nothing is allowed to make a noise")
	if err == "":
		err = _T.assert_eq(Sfx.voices_playing(), 0, "and muting stopped whatever was sounding")
	if err == "":
		err = _T.assert_false(Sfx.play(Sfx.PEST_KILLED), "a cue fired while muted plays nothing")
	if err == "":
		err = _T.assert_false(Sfx.toggle_muted(), "a second press brings it back")
	Sfx.set_muted(was_muted)
	return err


func test_a_husk_left_to_rot_says_so_instead_of_vanishing() -> String:
	## The silent-death case the whole sound pass exists for. An expired husk used
	## to erase itself with no cue at all, so "you were too slow" and "there was
	## never a husk there" were the same event from the player's chair.
	var meter := CompostMeter.new()
	var rotted: Array[int] = []
	meter.husk_rotted.connect(func(value: int) -> void: rotted.append(value))
	meter.drop_husk(Vector2.ZERO, CompostMeter.FULL_VALUE)
	meter._process(CompostMeter.lifetime_for(CompostMeter.FULL_VALUE) + 0.1)

	var err: String = _T.assert_eq(rotted.size(), 1, "the rotted husk announced itself")
	if err == "":
		err = _T.assert_eq(rotted[0], CompostMeter.FULL_VALUE,
			"and said what the player just threw away")
	if err == "":
		err = _T.assert_eq(meter.husk_count(), 0,
			"a listener reading the board inside the signal sees the husk already gone")
	if err == "":
		err = _T.assert_true(Sfx.SOUNDS.has(Sfx.HUSK_ROTTED),
			"and there is a cue behind it — the signal alone would still be silent")
	meter.free()
	return err


func test_a_swept_husk_never_reports_itself_as_rotted() -> String:
	## The two payouts must not be confusable: a husk the player collected paying
	## the "you were too slow" cue would be worse than the silence it replaced.
	var meter := CompostMeter.new()
	var rotted: Array[int] = []
	var collected: Array[int] = []
	meter.husk_rotted.connect(func(value: int) -> void: rotted.append(value))
	meter.husk_collected.connect(func(value: int, _at: Vector2) -> void: collected.append(value))
	meter.drop_husk(Vector2.ZERO, CompostMeter.BASE_VALUE)
	var paid: int = meter.collect_at(Vector2.ZERO)
	meter._process(CompostMeter.HUSK_LIFETIME + 1.0)

	var err: String = _T.assert_eq(paid, CompostMeter.BASE_VALUE, "the sweep paid out")
	if err == "":
		err = _T.assert_eq(collected.size(), 1, "and rang the collected cue once")
	if err == "":
		err = _T.assert_eq(rotted.size(), 0,
			"and never rings the rot cue, however long the meter runs afterwards")
	meter.free()
	return err


func test_a_grown_payout_shares_the_swept_ones_coins_but_not_its_level() -> String:
	## The two seed cues are deliberately the same sample: seeds arriving are
	## seeds arriving. What separates them is the trim — a sweep answers a click
	## the player made, a Sunflower pays out on its own clock every six seconds
	## per flower — so a table that ever levelled them would put ambience at the
	## volume of an answer. Asserted here because the difference lives entirely
	## in VOLUME_DB and nothing else would ever read it.
	var err: String = _T.assert_eq(Sfx.SOUNDS.get(Sfx.SEEDS_GROWN),
		Sfx.SOUNDS.get(Sfx.HUSK_COLLECTED), "both payouts wear the same coins")
	if err == "":
		err = _T.assert_gt(float(Sfx.VOLUME_DB.get(Sfx.HUSK_COLLECTED, 0.0)),
			float(Sfx.VOLUME_DB.get(Sfx.SEEDS_GROWN, 0.0)),
			"and the grown one sits under the swept one rather than level with it")
	if err == "":
		err = _T.assert_gt(int(Sfx.REPEAT_MS.get(Sfx.SEEDS_GROWN, Sfx.DEFAULT_REPEAT_MS)),
			Sfx.DEFAULT_REPEAT_MS,
			"with a wider repeat gap, so a row of flowers coming due together rings once")
	return err


func test_a_button_press_is_the_quietest_thing_the_game_says() -> String:
	## A press is punctuation, not an event. It shares its stream with the husk
	## rotting away out on the board, and it fires in the same frame as
	## WAVE_STARTED's bell (Game.start_next_wave reaches wave_started
	## synchronously), so anything but the lowest trim in the table would put a
	## click on top of the announcement it is meant to sit under. The refusal
	## cue is checked here too: a denied press must still be the buzz alone.
	var err: String = _T.assert_gt(float(Sfx.VOLUME_DB.get(Sfx.HUSK_ROTTED, 0.0)),
		float(Sfx.VOLUME_DB.get(Sfx.BUTTON_PRESSED, 0.0)),
		"the press sits under the rot cue it borrows its stream from")
	if err == "":
		err = _T.assert_gt(float(Sfx.VOLUME_DB.get(Sfx.WAVE_STARTED, 0.0)),
			float(Sfx.VOLUME_DB.get(Sfx.BUTTON_PRESSED, 0.0)),
			"and under the bell it sounds in the same frame as")
	if err == "":
		err = _T.assert_true(Sfx.SOUNDS.get(Sfx.BUTTON_PRESSED) != Sfx.SOUNDS.get(Sfx.PURCHASE_DENIED),
			"a press and a refusal are never the same sample")
	return err


# -- Seed Sunflower yield gauge (plant-tower-defense-6m2) --------------------


func test_a_fresh_sunflowers_gauge_is_empty_and_is_brimming_just_before_a_payout() -> String:
	## The two ends of the readout. Asserted on the state that _draw() consumes,
	## not on pixels: `progress_at` is what decides the height of the column, so
	## a wrong number here is a wrong picture there by construction.
	var err: String = _T.assert_float_eq(Sunflower.progress_at(0.0), 0.0, 0.0001,
		"the instant a payout lands the gauge is empty")
	if err == "":
		err = _T.assert_float_eq(Sunflower.progress_at(Sunflower.INTERVAL * 0.5), 0.5, 0.0001,
			"halfway through the interval it is half full")
	if err == "":
		err = _T.assert_gt(Sunflower.progress_at(Sunflower.INTERVAL - 0.05), 0.99,
			"and a frame before the next payout it is all but full")
	if err == "":
		err = _T.assert_float_eq(Sunflower.progress_at(Sunflower.INTERVAL), 1.0, 0.0001,
			"exactly at the payout it reads full, never past it")
	if err == "":
		err = _T.assert_float_eq(Sunflower.progress_at(Sunflower.INTERVAL * 3.0), 1.0, 0.0001,
			"and a frame long enough to overshoot clamps rather than overflowing the column")
	if err == "":
		var fresh := Sunflower.new()
		err = _T.assert_float_eq(fresh.yield_progress(), 0.0, 0.0001,
			"a just-planted Sunflower starts its first interval empty, not full")
		fresh.free()
	return err


func test_the_sunflower_gauge_never_runs_backwards_inside_an_interval() -> String:
	## A gauge that dips is read as "the payout got further away", which is the
	## one thing this readout must never say. Sampled across the whole interval
	## rather than at the ends, because clamping bugs hide in the middle.
	var steps: int = 60
	var previous: float = -1.0
	for i: int in range(steps + 1):
		var elapsed: float = Sunflower.INTERVAL * (float(i) / float(steps))
		var progress: float = Sunflower.progress_at(elapsed)
		var err: String = _T.assert_gte(progress, previous,
			"the gauge at %.2fs (%.3f) is never behind where it was at the sample before (%.3f)"
				% [elapsed, progress, previous])
		if err != "":
			return err
		previous = progress
	return _T.assert_float_eq(previous, 1.0, 0.0001,
		"and the last sample of the interval is a full column")


func test_the_sunflower_gauge_is_the_same_clock_as_the_panels_countdown() -> String:
	## The failure this exists to stop: a board readout keeping its own timer and
	## slowly disagreeing with "Next %d seeds in %.0fs" in the selection panel.
	## Driven through the real _act() so it is the wiring under test, not the
	## algebra — the panel calls seconds_until_next_yield(), the column calls
	## yield_progress(), and they must describe one clock.
	var sunflower := Sunflower.new()
	sunflower.setup(PlantCatalog.SUNFLOWER, Vector2i(0, 0), null)
	var host: Node2D = _host([sunflower])
	await _T.instantiate_scene(host)
	# Both after entering the tree: Godot turns physics processing back on when a
	# node with _physics_process() enters, so a pre-emptive set_physics_process()
	# would not stick, and whatever frames instantiate_scene pumped are cleared
	# off the clock here so the steps below are the only time that passes.
	sunflower.set_physics_process(false)
	sunflower._timer = 0.0

	var err: String = ""
	var no_pests: Array[Pest] = []
	for i: int in range(30):
		sunflower._act(Sunflower.INTERVAL / 12.0, no_pests)
		var seconds: float = sunflower.seconds_until_next_yield()
		var expected: float = 1.0 - seconds / Sunflower.INTERVAL
		err = _T.assert_float_eq(sunflower.yield_progress(), expected, 0.0001,
			"step %d: the column (%.4f) agrees with the panel's %.2fs remaining"
				% [i, sunflower.yield_progress(), seconds])
		if err != "":
			break
	_T.free_ui(host)
	return err


func test_a_payout_empties_the_sunflower_gauge_instead_of_leaving_it_full() -> String:
	## _bloom() fires at the payout and, headlessly, its tweens are skipped —
	## GardenTheme.animations_enabled() is false with no renderer. The gauge must
	## therefore come back to empty on its own rather than because a Tween landed,
	## or every headless payout would leave a full gold column painted on a plant
	## that has already paid.
	var sunflower := Sunflower.new()
	sunflower.setup(PlantCatalog.SUNFLOWER, Vector2i(0, 0), null)
	var host: Node2D = _host([sunflower])
	await _T.instantiate_scene(host)
	sunflower.set_physics_process(false)
	sunflower._timer = 0.0

	var paid: Array[int] = []
	sunflower.grew_seeds.connect(func(amount: int) -> void: paid.append(amount))
	var no_pests: Array[Pest] = []
	sunflower._act(Sunflower.INTERVAL - 0.1, no_pests)
	var err: String = _T.assert_gt(sunflower.yield_progress(), 0.98, "the gauge fills up to the payout")
	if err == "":
		sunflower._act(0.2, no_pests)
		err = _T.assert_eq(paid.size(), 1, "one interval, one payout")
	if err == "":
		err = _T.assert_true(sunflower.yield_progress() < 0.05,
			"and the column drops back to (nearly) empty rather than sticking at full — it read %.3f"
				% sunflower.yield_progress())
	if err == "":
		err = _T.assert_true(sunflower.yield_gauge_rect().size.y < Sunflower.GAUGE_HEIGHT * 0.05,
			"which is what the drawn rect is measured from")
	if err == "":
		err = _T.assert_float_eq(sunflower._bloom_flash, 0.0, 0.0001,
			"and the payout flash is left at its resting value, not stuck bright by a tween that never ran")
	if err == "":
		sunflower._act(Sunflower.INTERVAL * 0.5, no_pests)
		err = _T.assert_gt(sunflower.yield_progress(), 0.4,
			"the clock keeps running after a payout instead of stopping at the first one")
	_T.free_ui(host)
	return err


func test_the_sunflower_gauge_clears_the_health_bar_the_brackets_and_the_chew_ring() -> String:
	## Everything the column has to share a 64 px cell with. The sprite clearance
	## is the load-bearing one: Node2D draws its own canvas item *under* its
	## children, so a gauge inside the flower's silhouette is not dim, it is
	## invisible — and invisible looks exactly like "the feature is not there".
	var trough: Rect2 = Sunflower.gauge_trough_rect()
	var health_bar := Rect2(-16, -34, 32, 5)
	var err: String = _T.assert_false(trough.grow(1.0).intersects(health_bar),
		"the gauge %s never overlaps the health bar %s" % [trough, health_bar])
	if err == "":
		err = _T.assert_true(Rect2(-32, -32, 64, 64).encloses(trough.grow(1.0)),
			"and stays inside its own cell rather than spilling onto the neighbour's")
	if err == "":
		err = _T.assert_true(trough.end.x < -SelectionMarker.HALF,
			"and sits outside the selection brackets' arms (%.0f vs %.0f)" % [trough.end.x, -SelectionMarker.HALF])
	if err == "":
		# sunflower.svg: the petal tips reach r = 26 from the centre.
		var petal_tip_radius: float = 26.0
		for corner: Vector2 in [trough.position, Vector2(trough.end.x, trough.position.y),
				Vector2(trough.position.x, trough.end.y), trough.end]:
			err = _T.assert_gte(corner.length(), petal_tip_radius,
				"corner %s is clear of the sprite the gauge would otherwise be drawn behind" % corner)
			if err != "":
				break
	if err == "":
		# The chew ring is the readout this one must not be mistaken for. It is a
		# stroked circle of at most CHEW_RING_RADIUS; the gauge is a straight
		# column that starts well outside it, so the two never share a pixel even
		# on adjacent cells' worth of glance.
		var nearest_corner := Vector2(trough.end.x, trough.position.y)
		err = _T.assert_gt(nearest_corner.length(), ChompFlower.CHEW_RING_RADIUS,
			"and even its nearest corner (%.1f px out) lives outside the Chomp's %.0f px chew ring"
				% [nearest_corner.length(), ChompFlower.CHEW_RING_RADIUS])
	if err == "":
		err = _T.assert_float_eq(Sunflower.gauge_fill_rect(1.0).size.y, Sunflower.GAUGE_HEIGHT, 0.0001,
			"a full gauge fills the trough exactly")
	if err == "":
		err = _T.assert_float_eq(Sunflower.gauge_fill_rect(1.0).position.y, trough.position.y, 0.0001,
			"topping out at the trough's own top edge")
	if err == "":
		err = _T.assert_float_eq(Sunflower.gauge_fill_rect(0.0).position.y, Sunflower.GAUGE_BOTTOM, 0.0001,
			"and an empty one is a zero-height line at the bottom, so the column grows upward")
	return err


# -- Idle sway (plant-tower-defense-04x) -------------------------------------
#
# _wobble_time used to be declared and never read or written anywhere in the
# file. Headless never runs the gated half (GardenTheme.animations_enabled()
# reads DisplayServer.get_name(), which is "headless" for this whole suite),
# so what is testable here is the clock itself and the per-cell phase it is
# read against — not the rotation a player would actually see.


func test_the_idle_sway_clock_advances_every_physics_frame_even_headless() -> String:
	## The clock keeps ticking whether or not anything is gated on it, so it
	## stays meaningful rather than frozen at 0 for a plant's whole life.
	var plant := Plant.new()
	plant.setup(PlantCatalog.CORN, Vector2i(0, 0), null)
	var err: String = _T.assert_float_eq(plant._wobble_time, 0.0, 0.0001,
		"a freshly planted bed hasn't swayed yet")
	if err == "":
		plant._wobble(0.5)
		plant._wobble(0.25)
		err = _T.assert_float_eq(plant._wobble_time, 0.75, 0.0001,
			"and the clock is the plain sum of every step handed to it")
	plant.free()
	return err


func test_the_idle_sway_stays_off_the_pivot_headless() -> String:
	## The gate itself: headless is exactly where GardenTheme.animations_enabled()
	## reads false, so no amount of elapsed time should move anything here — the
	## one place this suite can watch the gate without a live display.
	##
	## Both channels, because there are two now: the sway rotates and the breathe
	## scales, and a gate that stopped only one would leave every plant on a
	## headless run quietly pulsing.
	var plant := Plant.new()
	plant.setup(PlantCatalog.CORN, Vector2i(0, 0), null)
	for _i: int in range(120):
		plant._wobble(1.0 / 60.0)
	var err: String = _T.assert_float_eq(plant._sway_pivot.rotation, 0.0, 0.0001,
		"two seconds of headless ticks turned the pivot by %.4f rad, not 0"
			% plant._sway_pivot.rotation)
	if err == "":
		err = _T.assert_eq(plant._sway_pivot.scale, Vector2.ONE,
			"and left its scale alone, got %s" % plant._sway_pivot.scale)
	plant.free()
	return err


## The reason the pivot exists, asserted rather than left to the header.
##
## Five event flourishes tween `_sprite.scale` back to Vector2.ONE — the planting
## pop, the exit shrink, the Sunflower's payout, the cob's recoil and upgrade, the
## Chomp's bite. If the idle breathe wrote that same property they would overwrite
## each other every frame in whichever order happened to run.
##
## **Only the structure is assertable here**, and knowing why is the point: past
## its gate `_wobble` does nothing headless, so pumping it and then reading
## `_sprite.scale` is a test of an unreached branch. The first draft of this did
## exactly that and a mutation aiming the breathe straight at `_sprite.scale`
## survived it. What a headless suite CAN see is that the sprite hangs off the
## pivot — the one relationship that makes the two transforms multiply rather than
## collide, and the one an `add_child` typo undoes. The behaviour itself is a
## runtime check.
func test_the_sprite_hangs_off_the_sway_pivot_not_the_plant() -> String:
	var plant := Plant.new()
	plant.setup(PlantCatalog.CORN, Vector2i(3, 5), null)
	var err: String = _T.assert_eq(plant._sprite.get_parent(), plant._sway_pivot,
		"the sprite hangs off the pivot, or the sway moves nothing a player sees")
	if err == "":
		err = _T.assert_eq(plant._sway_pivot.get_parent(), plant,
			"and the pivot off the plant, so the sway does not move the health bar with it")
	plant.free()
	return err


## The breathe's shape, through the pure function `_wobble` reads — the half of the
## gated body a headless suite can actually reach.
func test_the_breathe_narrows_and_lengthens_around_a_plant_that_stays_its_own_size() -> String:
	var widest: float = 0.0
	var tallest: float = 0.0
	var err: String = ""
	# A whole breathe period and a bit, sampled finely enough to catch both extremes.
	for i: int in range(200):
		var at: Vector2 = Plant.breathe_scale(float(i) * 0.05)
		widest = maxf(widest, at.x)
		tallest = maxf(tallest, at.y)
		# The two axes are mirrored about 1.0 at every instant, which is what makes
		# it a breathe rather than a pulse: area is held, the plant does not inflate.
		err = _T.assert_float_eq(at.x + at.y, 2.0, 0.0001,
			"the two axes stay mirrored about 1.0, got %s" % at)
		if err != "":
			return err
	if err == "":
		err = _T.assert_float_eq(tallest, 1.0 + Plant.BREATHE_AMOUNT, 0.0005,
			"it reaches its full lengthening somewhere in a period, got %.4f" % tallest)
	if err == "":
		# Both extremes, because a breathe alternates: half the cycle is tall and
		# narrow, the other half is short and wide. The first draft of this asserted
		# the plant "never gets wider than its own sprite" and was simply wrong about
		# the shape it had just been written to describe.
		err = _T.assert_float_eq(widest, 1.0 + Plant.BREATHE_AMOUNT, 0.0005,
			"and its full widening at the other end of the cycle, got %.4f" % widest)
	if err == "":
		# Subtle on purpose: this runs on every placed plant every frame for a
		# whole run, and it is half Pest.GAIT_STRETCH because a plant is standing
		# still. A breathe you can measure by eye at one plant is a twitchy garden
		# at fifteen.
		err = _T.assert_true(Plant.BREATHE_AMOUNT < Pest.GAIT_STRETCH,
			"a standing plant breathes less than a walking bug stretches (%.3f vs %.3f)"
				% [Plant.BREATHE_AMOUNT, Pest.GAIT_STRETCH])
	if err == "":
		# And a floor in PIXELS rather than in BREATHE_AMOUNT. Every assertion
		# above is expressed relative to the constant, so setting it to 0.0 left
		# them all true and that mutation SURVIVED — a subtle animation and no
		# animation are the same picture to a test that only checks proportions.
		# A plant sprite is 64x64, so this says the edge must move half a pixel,
		# which is the least that can be called motion.
		err = _T.assert_gte(Plant.BREATHE_AMOUNT * 32.0, 0.5,
			"the breathe moves the sprite's edge at all, got %.2f px"
				% (Plant.BREATHE_AMOUNT * 32.0))
	return err


func test_the_idle_sway_phase_differs_between_neighbouring_cells() -> String:
	## Pure, so it is assertable without a tree at all. A bed of identical
	## plants swaying in lockstep would read as one rigid slab rather than a
	## garden — TitleScreen's own decorative lawn avoids exactly this by
	## phasing its sprites off their array index; a planted Plant has no
	## index, so `cell` stands in for one.
	var a: float = Plant._wobble_phase(Vector2i(0, 0))
	var b: float = Plant._wobble_phase(Vector2i(1, 0))
	var c: float = Plant._wobble_phase(Vector2i(0, 1))
	var err: String = _T.assert_false(is_equal_approx(a, b),
		"neighbouring columns land on different phases (%.3f vs %.3f)" % [a, b])
	if err == "":
		err = _T.assert_false(is_equal_approx(a, c),
			"neighbouring rows land on different phases too (%.3f vs %.3f)" % [a, c])
	return err


# -- Regrowth: the answer to a hungry pest (plant-tower-defense-aoq) ----------
#
# Plant.take_damage was the only writer of `health` in the whole project, so a bed
# a hungry pest chewed and did not finish was damaged for the rest of the run —
# and since uproot_refund() started sliding with remaining health, it could not
# even be scrapped back to par. Plant.REGROWTH_* is the answer, and it lives on
# Plant rather than on a fifth catalogue plant.
#
# The load-bearing half of these is the pair that says what regrowth must NOT do.
# A heal that saved a bed mid-bite would delete the mutation, so the first test
# below drives a real hungry Pest against a real Plant and pins the time-to-death
# at exactly what it was before any of this existed.


func test_a_hungry_pest_eats_a_bed_in_exactly_the_time_it_always_did() -> String:
	## The guard on the entire mechanic. A pest mid-meal calls take_damage() every
	## physics frame and every one of those resets the quiet clock, so regrowth
	## contributes zero for the whole meal. Driven through Pest._physics_process
	## rather than through take_damage() directly, so it is the real eating path
	## being timed and not a re-implementation of it.
	var plant := Plant.new()
	plant.setup(PlantCatalog.CORN, Vector2i(0, 0), null)
	var beetle: Pest = _pest(Pest.BEETLE, Vector2(0, -Board.CELL))
	beetle.apply_mutation(Pest.MUTATION_HUNGRY)
	var host: Node2D = _host([plant, beetle])
	await _T.instantiate_scene(host)
	# Entering the tree turns physics processing back on for anything that defines
	# _physics_process, so the settle frames have already fed the beetle. Both are
	# switched off and the bed put back to full, so the steps below are the only
	# time that passes and the only damage that lands.
	beetle.set_physics_process(false)
	plant.set_physics_process(false)
	plant.health = Plant.MAX_HEALTH
	plant._quiet_time = Plant.REGROWTH_DELAY

	var eaten: Array[Plant] = []
	plant.destroyed.connect(func(p: Plant) -> void: eaten.append(p))

	var step: float = 1.0 / 60.0
	var elapsed: float = 0.0
	var guard: int = 0
	while not plant.is_destroyed() and guard < 1200:
		# Both halves of a real frame, in the order Plant._physics_process runs
		# them: the bed tries to grow, the bug eats.
		plant._regrow(step)
		beetle._physics_process(step)
		elapsed += step
		guard += 1

	var expected: float = Plant.seconds_to_be_eaten(Pest.EAT_DPS)
	var err: String = _T.assert_true(plant.is_destroyed(),
		"a hungry pest still destroys a bed with regrowth in the build")
	if err == "":
		err = _T.assert_float_eq(elapsed, expected, step * 2.0,
			"and takes %.3fs to do it — the same %.3fs it took before regrowth existed"
				% [elapsed, expected])
	if err == "":
		err = _T.assert_eq(eaten.size(), 1, "and says so exactly once")
	if err == "":
		err = _T.assert_float_eq(plant.seconds_until_regrowth(), Plant.REGROWTH_DELAY, 0.0001,
			"the quiet clock never got off zero during the meal, which is why none of it grew back")
	_T.free_ui(host)
	return err


func test_regrowth_could_not_out_heal_a_hungry_pest_even_if_it_were_never_gated() -> String:
	## Belt and braces on the test above. That one asserts the DELAY does its job;
	## this one asserts the RATE is chosen so that even a version of this mechanic
	## with no delay at all would still lose the bed — so a future change that
	## shortens or removes REGROWTH_DELAY cannot silently turn the mutation into a
	## non-event, it has to fail here first.
	var bare: float = Plant.seconds_to_be_eaten(Pest.EAT_DPS)
	var err: String = _T.assert_true(bare < 3.0,
		"a bed still dies in %.2fs, which is what the jaw marker warns about" % bare)
	if err == "":
		err = _T.assert_gt(Pest.EAT_DPS, Plant.REGROWTH_RATE * 8.0,
			"a hungry pest out-eats regrowth by at least 8 to 1 (%.1f dps vs %.1f hp/s)"
				% [Pest.EAT_DPS, Plant.REGROWTH_RATE])
	if err == "":
		var ungated: float = Plant.seconds_to_be_eaten(Pest.EAT_DPS - Plant.REGROWTH_RATE)
		err = _T.assert_true(ungated < bare * 1.25,
			"and an ungated heal would stretch the meal from %.2fs only to %.2fs, never survive it"
				% [bare, ungated])
	return err


func test_a_chewed_bed_grows_back_on_its_own_once_nothing_is_biting_it() -> String:
	## The mechanic doing what it says, driven through _physics_process on a real
	## catalogue plant rather than through _regrow on the base class. That is the
	## point of the test: `_act` is the hook every subclass overrides and none of
	## them chain to super, so a heal wired into the wrong hook would exist on
	## Plant and on nothing the player can actually plant.
	var corn := CornCobbler.new()
	corn.setup(PlantCatalog.CORN, Vector2i(0, 0), null)
	var host: Node2D = _host([corn])
	await _T.instantiate_scene(host)
	corn.set_physics_process(false)
	corn.health = Plant.MAX_HEALTH
	corn._quiet_time = Plant.REGROWTH_DELAY

	var half: float = Plant.MAX_HEALTH * 0.5
	corn.take_damage(half)
	var err: String = _T.assert_float_eq(corn.health, half, 0.0001, "half the bed is gone")
	if err == "":
		err = _T.assert_false(corn.is_regrowing(),
			"and it is not growing back the same frame it was bitten")
	if err == "":
		err = _T.assert_float_eq(corn.seconds_until_regrowth(), Plant.REGROWTH_DELAY, 0.0001,
			"the whole delay is owed again from the last bite")

	var step: float = 1.0 / 60.0
	if err == "":
		for _i: int in range(int(Plant.REGROWTH_DELAY / step)):
			corn._physics_process(step)
		err = _T.assert_float_eq(corn.health, half, 0.05,
			"nothing has grown back by the delay boundary — it read %.3f" % corn.health)
	if err == "":
		corn._physics_process(step)
		err = _T.assert_true(corn.is_regrowing(),
			"one frame past the delay and the bed is recovering")
	if err == "":
		err = _T.assert_gt(corn.health, half, "with health that has actually moved up")
	if err == "":
		# seconds_to_full_from() is what the panel would quote; run that long and
		# the plant must actually be whole, or the readout is a lie.
		var owed: float = Plant.seconds_to_full_from(half)
		for _i: int in range(int(owed / step) + 2):
			corn._physics_process(step)
		err = _T.assert_float_eq(corn.health, Plant.MAX_HEALTH, 0.0001,
			"and after the %.1fs it quoted, the bed is whole again" % owed)
	if err == "":
		err = _T.assert_false(corn.is_regrowing(), "a whole bed has stopped regrowing")
	if err == "":
		err = _T.assert_false(corn._health_back.visible,
			"and puts its bar away again, the same way it kept it hidden before the first bite")
	if err == "":
		# On both ramps, and through the pure half: `health_bar_color` reads
		# RunConfig.colorblind_safe, which is process-global and seeded from the
		# real save file, so the single-call form would be asserting whichever
		# palette the machine happened to be carrying.
		err = _T.assert_true(
			Plant.health_bar_color_on(true, false) != Plant.health_bar_color_on(false, false),
			"a regrowing bar is a different colour from a hurt one — the only cue the mechanic has")
		if err == "":
			err = _T.assert_true(
				Plant.health_bar_color_on(true, true) != Plant.health_bar_color_on(false, true),
				"and still is on the colourblind-safe ramp, where both ends were replaced")
	_T.free_ui(host)
	return err


func test_regrowth_only_counts_the_part_of_a_step_past_the_delay() -> String:
	## The boundary, on the pure function. A step that straddles the threshold must
	## grow its tail and not the whole of itself, or a single long frame (a devtools
	## step-time, a stalled physics tick) hands back seconds the plant never waited.
	var err: String = _T.assert_float_eq(Plant.regrowth_in_step(0.0, 1.0), 0.0, 0.0001,
		"a step entirely inside the delay grows nothing")
	if err == "":
		err = _T.assert_float_eq(Plant.regrowth_in_step(Plant.REGROWTH_DELAY - 1.0, 1.0), 0.0, 0.0001,
			"and one that ends exactly on the threshold still grows nothing")
	if err == "":
		err = _T.assert_float_eq(Plant.regrowth_in_step(Plant.REGROWTH_DELAY - 0.5, 2.0),
			1.5 * Plant.REGROWTH_RATE, 0.0001,
			"a 2s step straddling the threshold grows the 1.5s of itself that was past it, not all 2s")
	if err == "":
		err = _T.assert_float_eq(Plant.regrowth_in_step(Plant.REGROWTH_DELAY, 1.0),
			Plant.REGROWTH_RATE, 0.0001,
			"and a step entirely past it grows at the full rate")
	if err == "":
		err = _T.assert_float_eq(Plant.regrowth_in_step(Plant.REGROWTH_DELAY, 0.0), 0.0, 0.0001,
			"a zero-length step grows nothing, however long the quiet has been")
	if err == "":
		# Sixty small steps and one big one describe the same second of quiet.
		var lumped: float = Plant.regrowth_in_step(Plant.REGROWTH_DELAY, 1.0)
		var split: float = 0.0
		for _i: int in range(60):
			split += Plant.regrowth_in_step(Plant.REGROWTH_DELAY, 1.0 / 60.0)
		err = _T.assert_float_eq(split, lumped, 0.0001,
			"and the rate does not depend on the frame rate (%.4f split vs %.4f lumped)" % [split, lumped])
	return err


func test_a_wrecked_bed_costs_more_than_one_quiet_gap_between_waves() -> String:
	## The cost, stated against the clock the player actually experiences:
	## Game.PREP_SECONDS is the gap between a cleared wave and the next one, and it
	## is the only window in which nothing is biting. Regrowth is priced so one gap
	## never buys a whole bed back — otherwise chewing a plant is free and the
	## uproot-refund slope in Plant.uproot_refund() has nothing left to decide.
	var one_gap: float = Plant.regrowth_in_step(0.0, Game.PREP_SECONDS)
	var err: String = _T.assert_true(one_gap < Plant.MAX_HEALTH * 0.5,
		"one clean %.0fs gap returns %.0f hp, under half of a %.0f hp bed"
			% [Game.PREP_SECONDS, one_gap, Plant.MAX_HEALTH])
	if err == "":
		err = _T.assert_gt(one_gap, 0.0,
			"but more than nothing, or the delay has swallowed the whole intermission")
	if err == "":
		err = _T.assert_gt(Plant.seconds_to_full_from(1.0), Game.PREP_SECONDS,
			"a bed left at 1 hp needs longer than one gap (%.1fs vs %.0fs) to be whole"
				% [Plant.seconds_to_full_from(1.0), Game.PREP_SECONDS])
	if err == "":
		err = _T.assert_true(Plant.seconds_to_full_from(1.0) < Game.PREP_SECONDS * 2.0,
			"but not longer than two, or waiting is never the answer and this is decoration")
	if err == "":
		err = _T.assert_true(
			Plant.seconds_to_full_from(1.0) > Plant.seconds_to_full_from(Plant.MAX_HEALTH * 0.5),
			"and a wreck always costs more patience than a scratch")
	if err == "":
		err = _T.assert_float_eq(Plant.seconds_to_full_from(Plant.MAX_HEALTH), 0.0, 0.0001,
			"a plant that was never bitten owes no wait at all")
	return err


func test_a_bed_that_was_eaten_never_grows_back_out_of_the_ground() -> String:
	## The other end of the mechanic. Game frees the node on `destroyed`, so a
	## resurrection would normally be unobservable — but a Plant sitting at 0 for
	## even one extra frame before that lands must stay at 0, or "destroyed" becomes
	## a state the plant can leave and every listener downstream is wrong.
	var plant := Plant.new()
	plant.setup(PlantCatalog.CORN, Vector2i(0, 0), null)
	plant.take_damage(Plant.MAX_HEALTH)
	var err: String = _T.assert_true(plant.is_destroyed(), "the bed is gone")
	if err == "":
		for _i: int in range(int((Plant.REGROWTH_DELAY + Plant.MAX_HEALTH / Plant.REGROWTH_RATE) * 60.0) + 60):
			plant._regrow(1.0 / 60.0)
		err = _T.assert_float_eq(plant.health, 0.0, 0.0001,
			"and stays gone however long the board is quiet — it read %.3f" % plant.health)
	if err == "":
		err = _T.assert_false(plant.is_regrowing(), "a destroyed plant is never 'recovering'")
	plant.free()
	return err


# -- The corn ladder is a ladder (plant-tower-defense-axt) --------------------
#
# The bug these exist for: a spread costs real damage, because Kernel's hit test is
# a HIT_RADIUS circle around the pest's centre and an off-axis kernel's closest
# approach is `distance * sin(offset)`. When each level re-spaced its kernels from
# scratch (1 -> 2 -> 5 over 0 -> 14 -> 52 degrees) an upgrade MOVED shots instead of
# adding them, and two levels came out strictly worse than the level below:
#
#   * level 2's +/-7 deg pair stopped connecting at 148 px, so from 148 px to the
#     edge of its own 176 px ring it did 0.00 dps where level 1 did 1.25;
#   * level 3 past 80 px landed only its middle kernel — 1.61 dps against level 2's
#     2.78, for the most expensive upgrade in the game.
#
# The fix is structural, not a nudge: a fixed 13 deg step and odd kernel counts, so
# every level's firing angles are a superset of the level below's. The first test is
# the acceptance criterion (never worse at any range); the second is the property
# that makes it hold for arrangements the first one never samples.


func test_a_corn_upgrade_is_never_worse_at_any_range_the_cob_can_shoot() -> String:
	## The load-bearing one. Swept across the whole of RANGE at 1 px, because the
	## regression lived in bands: the old level 3 was fine out to 80 px and lost to
	## the cheaper level 2 from 81 px onward, so any test that sampled one range had
	## even odds of reporting the ladder healthy.
	var levels: int = CornCobbler.LEVELS.size()
	var err: String = _T.assert_gt(levels, 1, "there is a ladder to compare at all")
	if err != "":
		return err
	var steps: int = int(CornCobbler.RANGE)
	var samples: int = 0
	for i: int in range(steps + 1):
		var distance: float = CornCobbler.RANGE * float(i) / float(steps)
		var previous: float = CornCobbler.single_target_dps(1, distance)
		for level: int in range(2, levels + 1):
			var here: float = CornCobbler.single_target_dps(level, distance)
			err = _T.assert_gte(here, previous,
				"at %.0f px level %d does %.3f dps to one pest, never less than level %d's %.3f"
					% [distance, level, here, level - 1, previous])
			if err != "":
				return err
			previous = here
		samples += 1
	err = _T.assert_gt(samples, 100, "the sweep actually walked the ring (%d samples)" % samples)
	if err != "":
		return err

	# Non-decreasing is the floor. At the three ranges a player can name, the upgrade
	# has to be a real gain — a ladder that merely ties everywhere would pass the
	# sweep above and still be worth nobody's 45 seeds.
	var named: Dictionary = {
		"point blank": float(Board.CELL),
		"mid range": CornCobbler.RANGE * 0.5,
		"the edge of the ring": CornCobbler.RANGE,
	}
	for label: String in named:
		var distance: float = named[label]
		for level: int in range(2, levels + 1):
			err = _T.assert_gt(CornCobbler.single_target_dps(level, distance),
				CornCobbler.single_target_dps(level - 1, distance),
				"at %s (%.0f px) level %d (%.3f dps) beats level %d (%.3f dps), not merely ties it"
					% [label, distance, level, CornCobbler.single_target_dps(level, distance),
						level - 1, CornCobbler.single_target_dps(level - 1, distance)])
			if err != "":
				return err

	# The two filed cases, named so a reintroduction reads as itself in the failure.
	if err == "":
		err = _T.assert_gt(CornCobbler.single_target_dps(3, 100.0),
			CornCobbler.single_target_dps(2, 100.0),
			"the 45-seed level out-damages the 20-seed one at 100 px — it used to do 1.61 against 2.78")
	if err == "":
		err = _T.assert_gt(CornCobbler.single_target_dps(2, CornCobbler.RANGE),
			CornCobbler.single_target_dps(1, CornCobbler.RANGE),
			"and level 2 still connects at the edge of its own ring, where a +/-7 deg pair did not")
	return err


func test_every_corn_level_fires_through_every_angle_the_level_below_does() -> String:
	## The property the test above is a consequence of, asserted directly because it
	## is the thing that generalises: if level N fires through every angle level N-1
	## does, plus more, no faster interval and no lower damage, then level N hits at
	## least whatever level N-1 would have hit — at every range and against ANY
	## arrangement of pests, including the ones no test enumerates.
	var levels: int = CornCobbler.LEVELS.size()
	var err: String = _T.assert_gt(levels, 1, "there is a ladder to compare at all")
	if err != "":
		return err
	var tolerance: float = 0.0001
	var compared: int = 0
	for level: int in range(1, levels + 1):
		var offsets: PackedFloat32Array = CornCobbler.kernel_angle_offsets(level)
		var entry: Dictionary = CornCobbler.LEVELS[level - 1]

		# Odd counts, so there is always a kernel on the aim line. This is what stops
		# a level from doing literally nothing to the pest it picked: an even fan has
		# every kernel off-axis, and off-axis kernels all run out of reach.
		err = _T.assert_eq(offsets.size() % 2, 1,
			"level %d fires an odd number of kernels (%d), so one of them is on the aim line"
				% [level, offsets.size()])
		if err != "":
			return err
		err = _T.assert_float_eq(offsets[offsets.size() >> 1], 0.0, tolerance,
			"level %d's middle kernel flies straight at what the cob aimed at" % level)
		if err != "":
			return err

		# The spread is the step times the gaps, not a number somebody typed. A
		# retune that widens the arc without re-nesting the angles fails here.
		err = _T.assert_float_eq(float(entry["spread_degrees"]), CornCobbler.spread_for(level), 0.001,
			"level %d's %.1f deg spread is %d gaps of %.1f deg"
				% [level, float(entry["spread_degrees"]), offsets.size() - 1, CornCobbler.KERNEL_STEP_DEGREES])
		if err != "":
			return err

		if level == 1:
			continue
		var below: PackedFloat32Array = CornCobbler.kernel_angle_offsets(level - 1)
		var previous: Dictionary = CornCobbler.LEVELS[level - 2]
		for kept: float in below:
			var found: bool = false
			for offset: float in offsets:
				if absf(offset - kept) <= tolerance:
					found = true
					break
			err = _T.assert_true(found,
				"level %d still fires through %.1f deg, which level %d fired through — an upgrade adds shots, it does not move them"
					% [level, rad_to_deg(kept), level - 1])
			if err != "":
				return err
			compared += 1
		err = _T.assert_gt(offsets.size(), below.size(),
			"and adds kernels on top of them (%d vs %d)" % [offsets.size(), below.size()])
		if err == "":
			err = _T.assert_gte(float(previous["interval"]), float(entry["interval"]),
				"level %d never fires slower than level %d (%.2fs vs %.2fs)"
					% [level, level - 1, float(entry["interval"]), float(previous["interval"])])
		if err == "":
			err = _T.assert_gte(float(entry["damage"]), float(previous["damage"]),
				"and never hits softer (%.2f vs %.2f)" % [float(entry["damage"]), float(previous["damage"])])
		if err != "":
			return err
	return _T.assert_gt(compared, 0,
		"there were inherited angles to check, rather than an empty ladder passing quietly")


func test_the_corn_spread_still_widens_with_every_level() -> String:
	## The guard on the cheap fix. "Level 3 is worse against one pest" has an obvious
	## and terrible answer — delete the spread — and it would pass every dps test in
	## this file. The spray is the plant's whole identity and the muzzle fan draws
	## `spread_degrees` directly, so a ladder that stopped widening would be a board
	## on which the 45-seed upgrade is invisible again.
	var levels: int = CornCobbler.LEVELS.size()
	var err: String = _T.assert_gt(levels, 1, "there is a ladder to widen")
	if err != "":
		return err
	for level: int in range(2, levels + 1):
		var here: float = float(CornCobbler.LEVELS[level - 1]["spread_degrees"])
		var below: float = float(CornCobbler.LEVELS[level - 2]["spread_degrees"])
		err = _T.assert_gt(here, below,
			"level %d sprays through %.0f deg, wider than level %d's %.0f" % [level, here, level - 1, below])
		if err != "":
			return err
	# And the widening has to be worth drawing: a fan that grew by a degree a level
	# would satisfy the loop above and still look identical on a 64 px cell.
	var widest: float = float(CornCobbler.LEVELS[levels - 1]["spread_degrees"])
	return _T.assert_gt(widest, CornCobbler.KERNEL_STEP_DEGREES * 2.0,
		"and the top of the ladder is a genuine spray (%.0f deg), not a nudge" % widest)


func test_a_corn_upgrade_clears_a_cluster_at_least_as_fast_as_the_level_below() -> String:
	## The other half of the acceptance criterion. The single-target sweep only ever
	## puts one pest on the aim line; these put pests where a wide volley is supposed
	## to earn its keep, including arrangements that reward nobody in particular, so
	## "level 3 is a crowd sidegrade" cannot quietly mean "level 3 is worse".
	var levels: int = CornCobbler.LEVELS.size()
	var err: String = _T.assert_gt(levels, 1, "there is a ladder to compare at all")
	if err != "":
		return err
	var clusters: Array = [
		PackedFloat32Array([0.0]),
		PackedFloat32Array([-13.0, 0.0, 13.0]),
		PackedFloat32Array([-26.0, -13.0, 0.0, 13.0, 26.0]),
		PackedFloat32Array([8.0, 30.0]),
		PackedFloat32Array([-20.0, 5.0, 22.0]),
	]
	var checks: int = 0
	for angles: PackedFloat32Array in clusters:
		for i: int in range(1, 18):
			var distance: float = CornCobbler.RANGE * float(i) / 17.0
			var previous: float = _corn_cluster_dps(1, distance, angles)
			for level: int in range(2, levels + 1):
				var here: float = _corn_cluster_dps(level, distance, angles)
				err = _T.assert_gte(here, previous,
					"against pests at %s deg, %.0f px out, level %d does %.3f dps — never less than level %d's %.3f"
						% [angles, distance, level, here, level - 1, previous])
				if err != "":
					return err
				previous = here
				checks += 1
	return _T.assert_gt(checks, 50,
		"the cluster sweep actually compared something (%d comparisons)" % checks)


func test_a_real_corn_volley_lands_exactly_what_the_dps_table_promises() -> String:
	## The anti-tautology test. Everything above is computed from LEVELS through
	## CornCobbler.single_target_dps(), so a model that quietly disagreed with the
	## kernels the cob actually fires would let the whole section pass while the game
	## kept the bug. This one fires real Kernels from a real cob through real physics
	## frames and reads the damage off the pest.
	var err: String = _T.assert_gte(CornCobbler.LEVELS.size(), 3, "there is a level 3 to fire")
	if err != "":
		return err
	var far_three: float = await _corn_volley_damage(3, 110.0)
	var far_two: float = await _corn_volley_damage(2, 110.0)
	var near_three: float = await _corn_volley_damage(3, 30.0)

	err = _T.assert_float_eq(far_three,
		float(CornCobbler.kernels_connecting_at(3, 110.0)) * float(CornCobbler.LEVELS[2]["damage"]), 0.001,
		"one level 3 volley at 110 px landed %.2f damage, which is what the table says it should" % far_three)
	if err == "":
		err = _T.assert_float_eq(far_two,
			float(CornCobbler.kernels_connecting_at(2, 110.0)) * float(CornCobbler.LEVELS[1]["damage"]), 0.001,
			"and one level 2 volley landed %.2f" % far_two)
	if err == "":
		# The filed complaint, measured rather than modelled. Per volley AND per
		# second, because level 3 also fires faster and both have to point the
		# same way for the upgrade to be worth buying.
		err = _T.assert_gt(far_three, far_two,
			"a level 3 volley hurts a lone pest at 110 px more than a level 2 volley (%.2f vs %.2f)"
				% [far_three, far_two])
	if err == "":
		err = _T.assert_gt(far_three / float(CornCobbler.LEVELS[2]["interval"]),
			far_two / float(CornCobbler.LEVELS[1]["interval"]),
			"and more per second too (%.3f vs %.3f dps)"
				% [far_three / float(CornCobbler.LEVELS[2]["interval"]),
					far_two / float(CornCobbler.LEVELS[1]["interval"])])
	if err == "":
		# And the wide kernels are not decoration: inside 41 px the whole bunch
		# connects, which is the crowd-clearing half of what the level is for.
		err = _T.assert_gt(near_three, far_three * 4.0,
			"the same volley at 30 px lands %.2f — every kernel of the bunch connects up close" % near_three)
	return err


## Damage per second a level puts into a group of pests all `distance` px out, at
## `angles` degrees either side of the aim line. Each kernel dies on the first pest
## it touches, so a kernel scores at most once and a pest can be struck by several —
## which makes "hits" the count of kernels that pass within HIT_RADIUS of anything.
func _corn_cluster_dps(level: int, distance: float, angles: PackedFloat32Array) -> float:
	var entry: Dictionary = CornCobbler.LEVELS[level - 1]
	var hits: int = 0
	for offset: float in CornCobbler.kernel_angle_offsets(level):
		for pest_angle: float in angles:
			if Kernel.connects(distance, offset - deg_to_rad(pest_angle)):
				hits += 1
				break
	return float(hits) * float(entry["damage"]) / float(entry["interval"])


## Fires exactly one volley from a real cob at a real beetle `distance` px away and
## returns the damage that actually landed. Only the kernels created by that volley
## are stepped, so the shot the cob fires while the scene settles cannot be counted.
func _corn_volley_damage(level: int, distance: float) -> float:
	var corn := CornCobbler.new()
	corn.level = level
	corn.position = Vector2(200, 200)
	# Parked outside RANGE for the settle frames. A loaded cob fires the instant it
	# has a target, and up close that volley can kill the beetle before the
	# measurement starts — at which point resetting `health` would hand back a
	# corpse, since `_alive` does not come back with it.
	var beetle: Pest = _pest(Pest.BEETLE, Vector2(200.0 + CornCobbler.RANGE * 3.0, 200.0))
	var host: Node2D = _host([corn, beetle])
	await _T.instantiate_scene(host)
	# Entering the tree switches physics processing back on for anything that defines
	# _physics_process, so the bug has walked itself down the road. Both are put back
	# by hand here, and only now does the beetle come inside the ring.
	corn.set_physics_process(false)
	beetle.set_physics_process(false)
	beetle.position = Vector2(200.0 + distance, 200.0)
	beetle.health = beetle.max_health
	var stale: Array[int] = []
	for node: Node in host.get_tree().get_nodes_in_group("kernels"):
		stale.append(node.get_instance_id())

	var pests: Array[Pest] = [beetle]
	corn._act(1.0, pests)
	# No frames are pumped, so a kernel that hit stays in the group with its free
	# still queued — stepping it again would score twice off one kernel.
	var step: float = 1.0 / 60.0
	for _frame: int in range(60):
		for node: Node in host.get_tree().get_nodes_in_group("kernels"):
			if stale.has(node.get_instance_id()) or node.is_queued_for_deletion():
				continue
			var kernel := node as Kernel
			if kernel != null:
				kernel._physics_process(step)
	var dealt: float = beetle.max_health - beetle.health
	_T.free_ui(host)
	return dealt


# -- Endless is a composition ramp, not a headcount (plant-tower-defense-efv) --
#
# The filed defect, re-derived off the constants AS THEY WERE when the fixed table
# was eight waves long: the aphid gap floored at wave 22, the beetle gap at 28,
# mutation chance at 31, health at 42 and speed at 48. Every one of those is
# `WAVES.size() + n`, so all five moved eight waves later when the campaign grew to
# sixteen (plant-tower-defense-74a) — which is exactly why the test below derives
# the wave it measures instead of writing 49 down. From the first wave past them
# the only endless scale still moving was `count`, and nothing capped it —
# 166 pests at wave 48, 376 at 108, 1748 at 500. Against the real 2112 px road and
# the capped speeds an aphid crosses in 16.9 s, so a 0.16 s gap alone puts 106 of
# them on the board; sweeping the whole schedule the peak was 115 alive at once by
# wave 40, on a 32-cell road. Difficulty had become quantity, which is the exact
# thing the ENDLESS_HEALTH_STEP header says those scales exist to prevent.
#
# The fix is a road budget plus a mix that keeps rotating: the swarm is pinned at
# its share and every later wave buys one more beetle instead. These assert the
# ceiling, the axis that replaced count, and — the load-bearing one — that the
# threat readout still prices the new ramp, since a difficulty that comes out of
# composition is invisible to any formula that only reads per-pest multipliers.


func test_an_endless_wave_never_fills_the_road_past_the_stated_ceiling() -> String:
	## The acceptance criterion. Swept rather than sampled, because the worst wave
	## is not the deepest one: it is the campaign finale (wave 16), where two
	## queens, the brood they can burst into, a full swarm and a beetle column are
	## all on the road together, and every endless wave after it is paced further
	## apart. A test that only looked at wave 100 would find the road at 29 of 40
	## and miss the one wave that spends the whole budget.
	var ceiling: int = WaveDirector.SIMULTANEOUS_PEST_CEILING
	var err: String = _T.assert_gt(ceiling, 0, "there is a ceiling to check against")
	if err != "":
		return err
	var checked: int = 0
	var worst: int = 0
	var worst_wave: int = 0
	for wave: int in range(1, 301):
		var peak: int = WaveDirector.peak_simultaneous_pests(wave)
		err = _T.assert_gte(ceiling, peak,
			"wave %d puts at most %d pests on the road at once, inside the %d ceiling"
				% [wave, peak, ceiling])
		if err != "":
			return err
		if peak > worst:
			worst = peak
			worst_wave = wave
		checked += 1
	# And it holds arbitrarily far out, which is the half a 300-wave sweep cannot
	# claim — the pacing is derived from the crossing time, so it has no horizon.
	for wave: int in [500, 1000, 5000]:
		var deep_peak: int = WaveDirector.peak_simultaneous_pests(wave)
		err = _T.assert_gte(ceiling, deep_peak,
			"wave %d is still inside the ceiling (%d of %d)" % [wave, deep_peak, ceiling])
		if err != "":
			return err
		checked += 1
	err = _T.assert_gt(checked, 100, "the sweep really walked the curve (%d waves)" % checked)
	if err == "":
		# The named number stated in wave_director.gd, asserted rather than trusted.
		err = _T.assert_gte(ceiling, WaveDirector.peak_simultaneous_pests(100),
			"wave 100 — the wave the issue was filed about — peaks at %d"
				% WaveDirector.peak_simultaneous_pests(100))
	if err == "":
		# A ceiling nothing ever approaches is not a constraint, it is decoration.
		# Before this change the same sweep peaked at 115.
		err = _T.assert_gt(worst, ceiling / 2,
			"and the ceiling is a real constraint — the worst wave (%d) reaches %d of %d"
				% [worst_wave, worst, ceiling])
	return err


func test_the_spawn_pacing_measures_the_road_the_pests_actually_walk() -> String:
	## The pacing is `crossing time / share`, so every number above rests on the
	## director's idea of the road being the road. It derives that from
	## Board.PATH_CORNERS rather than from a real Board, which is fast and pure and
	## would go silently wrong the day the path shape changed — so this walks the
	## polyline Board really hands the pests and compares.
	var board := Board.new()
	var route: PackedVector2Array = board.route()
	var walked: float = 0.0
	for i: int in range(route.size() - 1):
		walked += route[i].distance_to(route[i + 1])
	board.free()

	var slow: float = WaveDirector.crossing_seconds(Pest.BEETLE, 1)
	var quick: float = WaveDirector.crossing_seconds(Pest.APHID, 1)
	var err: String = _T.assert_gt(route.size(), 2, "the board handed back a real route")
	if err == "":
		err = _T.assert_float_eq(WaveDirector.route_length(), walked, 0.001,
			"the director prices a %.0f px walk, which is the %.0f px Board actually lays out"
				% [WaveDirector.route_length(), walked])
	if err == "":
		err = _T.assert_gt(slow, quick,
			"a beetle is longer on the road than an aphid (%.1fs vs %.1fs), which is why it costs more of the budget"
				% [slow, quick])
	if err == "":
		err = _T.assert_float_eq(quick, walked / float(Pest.SPECIES[Pest.APHID]["speed"]), 0.001,
			"and an unscaled aphid's crossing is just the walk over its own speed")
	if err == "":
		# Endless speeds the pests up, which shortens the crossing, which lets the
		# same share of road take them closer together. The pacing has to move with
		# it or it prices wave 100 at wave 9's speeds.
		err = _T.assert_gt(WaveDirector.crossing_seconds(Pest.APHID, 1),
			WaveDirector.crossing_seconds(Pest.APHID, 100),
			"a wave-100 aphid crosses faster (%.1fs) than a wave-1 one (%.1fs)"
				% [WaveDirector.crossing_seconds(Pest.APHID, 100),
					WaveDirector.crossing_seconds(Pest.APHID, 1)])
	return err


func test_endless_still_gets_harder_after_every_per_pest_scale_has_capped() -> String:
	## The other half of the acceptance criterion, and the reason the fix could not
	## just be "cap the count": with a ceiling on the road AND a ceiling on every
	## per-pest multiplier, a wave with nothing left to grow is a wave the player's
	## board beats forever. The first block pins that all of the old scales really
	## are dead by then, so the climb below cannot be coming from them.
	##
	## `late` is DERIVED rather than the literal 49 it used to be. Every cap lands
	## at `WAVES.size() + n` — health at +34, speed at +40, mutation at +23 — so
	## growing the fixed table from eight waves to sixteen moved all three eight
	## waves later, and a hard-coded 49 would have gone on measuring a wave where
	## health was still visibly climbing while reporting that it had stopped.
	var late: int = _first_wave_with_every_scale_capped()
	var far: int = 500
	var err0: String = _T.assert_gt(late, WaveDirector.WAVES.size(),
		"there is a wave past the table where every per-pest scale has saturated")
	if err0 != "":
		return err0
	var err: String = _T.assert_float_eq(WaveDirector.health_scale_for(far),
		WaveDirector.health_scale_for(late), 0.0001, "health has stopped by wave %d" % late)
	if err == "":
		err = _T.assert_float_eq(WaveDirector.speed_scale_for(far),
			WaveDirector.speed_scale_for(late), 0.0001, "so has speed")
	if err == "":
		err = _T.assert_float_eq(WaveDirector.mutation_chance_for(far),
			WaveDirector.mutation_chance_for(late), 0.0001, "so has the mutation rate")
	if err != "":
		return err

	var steps: int = 0
	var previous: float = WaveDirector.threat_for(late - 1)
	for wave: int in range(late, 301):
		var threat: float = WaveDirector.threat_for(wave)
		err = _T.assert_gt(threat, previous,
			"wave %d (x%.1f) is harder than wave %d (x%.1f) with every multiplier already capped"
				% [wave, threat, wave - 1, previous])
		if err != "":
			return err
		previous = threat
		steps += 1
	err = _T.assert_gt(steps, 100, "the climb was actually walked (%d waves)" % steps)
	if err == "":
		# The design constraint, stated as the number it is: wave 500 must not merely
		# tie wave 100 to four decimal places.
		err = _T.assert_gt(WaveDirector.threat_for(500), WaveDirector.threat_for(100) * 4.0,
			"wave 500 (x%.0f) is several times wave 100 (x%.0f), not a rounding error above it"
				% [WaveDirector.threat_for(500), WaveDirector.threat_for(100)])
	if err == "":
		err = _T.assert_gte(WaveDirector.threat_level(500), WaveDirector.threat_level(100) + 3,
			"and the player-facing level moved with it (%d -> %d)"
				% [WaveDirector.threat_level(100), WaveDirector.threat_level(500)])
	return err


func test_the_beetle_column_is_the_axis_that_replaced_the_headcount() -> String:
	## Which axis is doing the work, asserted directly. The swarm holds its size
	## forever and the column grows every single wave — so a later wave is not more
	## pests, it is the same road spent on heavier ones.
	var table: int = WaveDirector.WAVES.size()
	var first: Array = WaveDirector.groups_for(table + 1)
	var err: String = _T.assert_eq(first.size(), 2, "an endless wave is still a swarm and a column")
	if err != "":
		return err
	var checked: int = 0
	var previous_beetles: int = 0
	for wave: int in range(table + 1, 301):
		var groups: Array = WaveDirector.groups_for(wave)
		var aphids: int = int(groups[0]["count"])
		var beetles: int = int(groups[1]["count"])
		err = _T.assert_eq(aphids, WaveDirector.ENDLESS_APHID_SHARE,
			"wave %d's swarm is still exactly its road share (%d)" % [wave, aphids])
		if err == "":
			err = _T.assert_gt(beetles, previous_beetles,
				"and its column is one beetle deeper than wave %d's (%d vs %d)"
					% [wave - 1, beetles, previous_beetles])
		if err != "":
			return err
		previous_beetles = beetles
		checked += 1
	err = _T.assert_gt(checked, 100, "the sweep compared something (%d waves)" % checked)
	if err != "":
		return err

	# The rotation, as the player would describe it: the wave stops being mostly
	# aphids and becomes mostly beetles.
	var early: float = _beetle_fraction(table + 1)
	var deep: float = _beetle_fraction(500)
	err = _T.assert_true(early < 0.5,
		"the first endless wave is still mostly swarm (%.0f%% beetle)" % [early * 100.0])
	if err == "":
		err = _T.assert_gt(deep, 0.9,
			"and wave 500 is almost all column (%.0f%% beetle)" % [deep * 100.0])
	if err == "":
		# The player-facing half. This line used to go silent at exactly the wave
		# the ramp stopped, which reads as "nothing got worse".
		err = _T.assert_true(WaveDirector.escalation_note(500).contains("heavier"),
			"and the wave-start note still names what changed at wave 500 (got '%s')"
				% WaveDirector.escalation_note(500))
	if err == "":
		err = _T.assert_eq(WaveDirector.escalation_note(WaveDirector.WAVES.size()), "",
			"while the campaign says nothing, the way it always did")
	return err


func test_the_threat_readout_prices_the_composition_ramp_exactly() -> String:
	## The subtle one. Difficulty now comes out of what a wave is made of, and
	## _raw_threat weighs a wave by species health — so the two either agree or the
	## number on the bar is a lie. Past wave 48 every multiplier is pinned, so the
	## whole of a wave-to-wave threat rise must be the one beetle that got added,
	## and that is checkable to the decimal rather than as "it went up".
	var reference: float = float(WaveDirector.pests_in_wave(1)) * float(Pest.SPECIES[Pest.APHID]["health"])
	var err: String = _T.assert_gt(reference, 0.0, "wave 1 is a real reference to measure against")
	if err != "":
		return err
	var compared: int = 0
	for wave: int in [60, 100, 137, 250, 499]:
		var mutations: float = 1.0 + WaveDirector.mutation_chance_for(wave) * WaveDirector.MUTATION_THREAT_WEIGHT
		var scales: float = WaveDirector.health_scale_for(wave) * WaveDirector.speed_scale_for(wave) * mutations
		var added: float = float(Pest.SPECIES[Pest.BEETLE]["health"]) * float(WaveDirector.ENDLESS_BEETLE_STEP)
		var one_beetle: float = added * scales / reference
		var measured: float = WaveDirector.threat_for(wave + 1) - WaveDirector.threat_for(wave)
		err = _T.assert_float_eq(measured, one_beetle, 0.001,
			"wave %d -> %d moves the threat by x%.3f, which is exactly the beetle it added (x%.3f)"
				% [wave, wave + 1, measured, one_beetle])
		if err != "":
			return err
		compared += 1
	err = _T.assert_gt(compared, 3, "several waves were priced (%d)" % compared)
	if err != "":
		return err

	# And the ranking holds the other way round: a heavier mix always prices above
	# a lighter one, so the tint and the readout cannot invert against the board.
	var previous: float = 0.0
	var ranked: int = 0
	for wave: int in range(1, 301):
		var threat: float = WaveDirector.threat_for(wave)
		err = _T.assert_gt(threat, previous,
			"wave %d (x%.2f) never prices below wave %d (x%.2f)" % [wave, threat, wave - 1, previous])
		if err != "":
			return err
		previous = threat
		ranked += 1
	if err == "":
		err = _T.assert_gt(ranked, 100, "the ranking sweep ran (%d waves)" % ranked)
	if err == "":
		err = _T.assert_float_eq(WaveDirector.threat_for(1), 1.0, 0.0001,
			"and wave 1 is still the unit the whole scale is quoted in")
	if err == "":
		# The pacing must stay invisible to the price. It only ever loosens a wave,
		# so a threat that noticed it would report the road budget as a nerf.
		var groups: Array = WaveDirector.groups_for(100)
		err = _T.assert_gt(float(groups[1]["gap"]), 0.5,
			"wave 100's column really is paced out (%.2fs between beetles, past the 0.5s the curve asks for)"
				% float(groups[1]["gap"]))
	return err


func test_the_fixed_campaign_is_untouched_by_the_road_budget() -> String:
	## Endless and campaign share this file, and the road budget is written in terms
	## of `wave - WAVES.size()`, so campaign is untouched by construction rather than
	## by a mode flag. Asserted anyway, against the literal table, because "by
	## construction" is a claim about code that someone edits next week.
	##
	## The list is the campaign's headcount wave by wave, and it is the reason this
	## test earns its keep: waves 12, 14 and 16 send a queen, and a queen is ONE
	## pest in the schedule that becomes four bodies on the road. A table read that
	## quietly stopped counting her — or started counting her brood — shows up here
	## as a number, before it shows up as a wave that overruns the road budget.
	var expected: Array[int] = [5, 9, 9, 14, 13, 19, 19, 29, 26, 32, 30, 23, 35, 29, 35, 36]
	var err: String = _T.assert_eq(WaveDirector.WAVES.size(), expected.size(),
		"the campaign is still sixteen waves long")
	if err != "":
		return err
	for wave: int in range(1, expected.size() + 1):
		err = _T.assert_eq(WaveDirector.pests_in_wave(wave), expected[wave - 1],
			"wave %d still sends %d pests" % [wave, expected[wave - 1]])
		if err == "":
			err = _T.assert_float_eq(WaveDirector.health_scale_for(wave), 1.0, 0.0001,
				"and an unscaled pest")
		if err == "":
			err = _T.assert_float_eq(WaveDirector.speed_scale_for(wave), 1.0, 0.0001,
				"at an unscaled speed")
		if err == "":
			err = _T.assert_float_eq(WaveDirector.mutation_chance_for(wave),
				WaveDirector.MUTATION_CHANCE, 0.0001, "at the flat campaign mutation rate")
		if err != "":
			return err

	# The groups themselves, not just the headcount: the pacing rewrote how gaps are
	# chosen, and a campaign wave whose spacing had drifted would still send the
	# right number of pests.
	var groups: Array = WaveDirector.groups_for(WaveDirector.WAVES.size())
	var table: Array = WaveDirector.WAVES[WaveDirector.WAVES.size() - 1]
	err = _T.assert_eq(groups.size(), table.size(),
		"the last campaign wave is still the %d groups the table writes down" % table.size())
	if err != "":
		return err
	var compared: int = 0
	for i: int in range(table.size()):
		var built: Dictionary = groups[i]
		var written: Dictionary = table[i]
		err = _T.assert_eq(String(built["species"]), String(written["species"]),
			"group %d is still %s" % [i, written["species"]])
		if err == "":
			err = _T.assert_eq(int(built["count"]), int(written["count"]), "of the same size")
		if err == "":
			err = _T.assert_float_eq(float(built["gap"]), float(written["gap"]), 0.0001,
				"at the gap the table writes down (%.2fs)" % float(written["gap"]))
		if err == "":
			err = _T.assert_float_eq(float(built["lead"]), float(written["lead"]), 0.0001,
				"after the lead the table writes down")
		if err != "":
			return err
		compared += 1
	err = _T.assert_gt(compared, 0, "there were groups to compare, not an empty table passing quietly")
	if err == "":
		err = _T.assert_eq(WaveDirector.peak_simultaneous_pests(WaveDirector.WAVES.size()),
			WaveDirector.SIMULTANEOUS_PEST_CEILING,
			("and the campaign finale is sized to land ON the ceiling rather than under it —"
				+ " it is the wave that spends the road budget now (see"
				+ " SIMULTANEOUS_PEST_CEILING), so a row edited without re-checking the peak"
				+ " shows up here first"))
	return err


## The first wave at which health, speed and the mutation rate have all reached
## their caps — i.e. the first wave past which nothing per-pest is still moving.
##
## Searched rather than written down, because the answer is a function of the
## table's length and three step/max pairs, and all four of those are things a
## balance pass edits. Returns 0 when no such wave exists inside the search,
## which the caller asserts on rather than quietly treating as wave 0.
func _first_wave_with_every_scale_capped() -> int:
	var table: int = WaveDirector.WAVES.size()
	for wave: int in range(table + 1, table + 400):
		if not is_equal_approx(WaveDirector.health_scale_for(wave), WaveDirector.ENDLESS_HEALTH_MAX):
			continue
		if not is_equal_approx(WaveDirector.speed_scale_for(wave), WaveDirector.ENDLESS_SPEED_MAX):
			continue
		if not is_equal_approx(WaveDirector.mutation_chance_for(wave), WaveDirector.MUTATION_CHANCE_MAX):
			continue
		return wave
	return 0


## What fraction of `wave`'s bodies are beetles. The composition ramp, as one
## number — a wave that is 24% beetle and one that is 96% beetle are the same
## shape and completely different fights.
func _beetle_fraction(wave: int) -> float:
	var beetles: int = 0
	var total: int = 0
	for group: Dictionary in WaveDirector.groups_for(wave):
		var count: int = int(group["count"])
		total += count
		if StringName(group["species"]) == Pest.BEETLE:
			beetles += count
	return 0.0 if total == 0 else float(beetles) / float(total)


# -- Compost has a denominator now (plant-tower-defense-g3l) -------------------
#
# "Compost swept 12" was the one row on the post-mortem that was neither a total
# nor a bound: 12 out of 13 is a clean run and 12 out of 60 is a lane the player
# never looked at, and the card said "12" to both. CompostMeter.husk_rotted was
# already being emitted (the sound pass added it) and Game._on_husk_rotted played
# a cue and incremented nothing, so the missed half was thrown away every frame.
#
# What counts as MISSED: a husk that rotted, counted in seeds, at the instant it
# rots. What is EXCLUDED, deliberately: a husk still lying on the ground. It has
# not been missed — the player may be one click from it — and the run can end
# with husks dropped moments earlier that were never collectable, because
# Game._on_pest_escaped takes the last bed and builds the card in the same frame.
# So the denominator is total_resolved() = swept + rotted, every husk in it one
# whose story is over, which makes the fraction honest mid-run too.
#
# Seeds and not husk counts, because the numerator has always been seeds and a
# husk is worth BASE_VALUE..FULL_VALUE — the rich husk is also the fastest to rot
# (lifetime_for), so counting heads would score "swept the cheap one, let the
# richest rot" as a 50% run when most of the board's value was thrown away.


func test_a_husk_that_rots_on_the_real_timer_counts_as_compost_the_player_missed() -> String:
	## Driven through the meter's own countdown while it sits in a live tree —
	## never by calling a handler or emitting husk_rotted by hand. A counter wired
	## to the signal instead of to the expiry would pass a hand-fired test and
	## still lose every husk in a run where nothing happened to be listening.
	var meter := CompostMeter.new()
	meter.name = "CompostMeter"
	await _T.instantiate_scene(meter)
	var value: int = CompostMeter.FULL_VALUE
	meter.drop_husk(Vector2.ZERO, value)

	var err: String = _T.assert_true(meter.is_processing(),
		"the meter is hosted and processing, so the countdown below is the engine's own")
	if err == "":
		err = _T.assert_eq(meter.total_rotted, 0, "nothing has rotted yet")
	if err == "":
		err = _T.assert_eq(meter.total_resolved(), 0, "so nothing has resolved yet either")

	# Real frames first: this is what proves the engine drives the countdown at
	# all, rather than the test being the only thing that ever moves it.
	if err == "":
		var before_life: float = float((meter.husks()[0] as Dictionary)["life"])
		await meter.get_tree().process_frame
		await meter.get_tree().process_frame
		err = _T.assert_true(float((meter.husks()[0] as Dictionary)["life"]) < before_life,
			"the husk's life ran down on its own across two real frames (from %.4f)" % before_life)

	# Then the rest of the span in steps, none of which could jump it alone: the
	# countdown has to accumulate or nothing rots.
	var steps: int = 0
	if err == "":
		var step: float = CompostMeter.MIN_HUSK_LIFETIME / 10.0
		for i: int in 12:
			meter._process(step)
			steps += 1
			if i == 4:
				err = _T.assert_eq(meter.total_rotted, 0,
					"half a lifetime in, a husk still on the ground is not yet missed")
				if err != "":
					break
	if err == "":
		err = _T.assert_gt(steps, 0, "the countdown really was stepped, not an empty loop passing quietly")
	if err == "":
		err = _T.assert_eq(meter.husk_count(), 0, "the husk rotted off the board")
	if err == "":
		err = _T.assert_eq(meter.total_rotted, value, "and its seeds landed on the missed pile")
	if err == "":
		err = _T.assert_eq(meter.total_collected, 0, "with nothing credited as swept")
	if err == "":
		err = _T.assert_eq(meter.total_resolved(), value,
			"so the card can say 0 of %d instead of a bare 0" % value)
	_T.free_ui(meter)
	return err


func test_a_husk_swept_before_it_rots_never_lands_on_the_missed_pile() -> String:
	## The confusable case: a husk swept at the last possible moment must be
	## counted once, as swept, and must not also show up in the missed half — a
	## denominator built by adding a drop counter to a rot counter would
	## double-count it and report "9 of 18" for one husk.
	var meter := CompostMeter.new()
	var value: int = CompostMeter.BASE_VALUE
	meter.drop_husk(Vector2.ZERO, value)
	# One step short of rotting: as close to lost as a sweep can get.
	meter._process(CompostMeter.lifetime_for(value) - 0.05)

	var err: String = _T.assert_eq(meter.husk_count(), 1, "the husk is still there to sweep")
	if err == "":
		err = _T.assert_eq(meter.collect_at(Vector2.ZERO), value, "and the sweep paid out")
	if err == "":
		meter._process(CompostMeter.HUSK_LIFETIME + 1.0)
		err = _T.assert_eq(meter.total_rotted, 0,
			"a swept husk never rots, however long the meter runs afterwards")
	if err == "":
		err = _T.assert_eq(meter.total_collected, value, "it sits on the swept pile")
	if err == "":
		err = _T.assert_eq(meter.total_resolved(), value,
			"counted exactly once in the denominator — a clean %d of %d"
				% [meter.total_collected, meter.total_resolved()])
	meter.free()
	return err


func test_the_missed_compost_survives_the_run_and_reaches_the_card() -> String:
	## End to end through the real game: two husks, one swept and one rotted, then
	## the losing path a player actually reaches. A counter that is right inside
	## the meter and never reaches summary_stats() fixes nothing the issue is about.
	var game := await _T.instantiate_scene("res://game/game.tscn") as Game
	var err: String = _T.assert_true(game != null, "the game scene loaded")
	if err != "":
		return err

	var swept_value: int = CompostMeter.BASE_VALUE
	var rotted_value: int = CompostMeter.FULL_VALUE
	var spot := Vector2(100.0, 100.0)
	game.compost.drop_husk(spot, swept_value)
	err = _T.assert_eq(game.compost.collect_at(spot), swept_value, "the first husk is swept")
	if err == "":
		game.compost.drop_husk(Vector2(400.0, 300.0), rotted_value)
		game.compost._process(CompostMeter.lifetime_for(rotted_value) + 0.1)
		err = _T.assert_eq(game.compost.husk_count(), 0, "and the second one is left to rot")
	if err == "":
		# The real losing path, same as the post-mortem tests in test_selftest.
		game.lives = 1
		game._on_pest_escaped(null)
		await game.get_tree().process_frame
		await game.get_tree().process_frame
		err = _T.assert_true(game.game_over, "the run is over")

	var expected: String = "%d of %d" % [swept_value, swept_value + rotted_value]
	if err == "":
		var stats: Dictionary = game.summary_stats(false)
		err = _T.assert_true(stats.has("compost_resolved"),
			"summary_stats carries the denominator (Game needs `\"compost_resolved\": compost.total_resolved(),` beside compost_total)")
		if err == "":
			err = _T.assert_eq(int(stats["compost_total"]), swept_value,
				"the numerator is still what was swept")
		if err == "":
			err = _T.assert_eq(int(stats["compost_resolved"]), swept_value + rotted_value,
				"and the denominator is everything that resolved, swept and rotted alike")
	if err == "":
		var panel: RunSummary = game.get_node_or_null("SummaryLayer/RunSummary") as RunSummary
		err = _T.assert_true(panel != null, "the post-mortem card is up")
		if err == "":
			var label: Label = panel.get_node_or_null("Value_Compostswept") as Label
			err = _T.assert_true(label != null, "and still carries a compost row")
			if err == "":
				err = _T.assert_eq(label.text, expected,
					"which now reads as a fraction the player can grade themselves against")
	_T.free_ui(game)
	return err


func test_the_compost_fraction_costs_the_post_mortem_card_no_height() -> String:
	## Why this is a fold and not an eighth row. Rows step by ROW_HEIGHT + ROW_GAP
	## = 38 from FIRST_ROW_Y = 186, so the seventh row foots at 448 against buttons
	## at 476 — 28px of slack, of which BUTTON_CLEARANCE claims 16. An eighth row
	## would foot at 486, ten pixels *below* the top of the buttons, and ROW_GAP has
	## already been cut once (8 to 4) to fit the seventh. The clearance gate lives
	## in test_selftest; this asserts the same geometry against the widest compost
	## fraction a long endless run can actually produce, plus the row count that
	## makes the fold a fold.
	var stats: Dictionary = {
		"victory": false,
		"endless": true,
		"wave": 46,
		"wave_count": 8,
		"threat_level": 9,
		"lives_lost": 5,
		"seeds_earned_total": 8421,
		"high_score": 8421,
		"new_record": true,
		"compost_total": 1994,
		"compost_resolved": 2887,
		"pests_defeated": 1372,
		"run_seconds": 2754.0,
		"worst_cell": Vector2i(7, 4),
		"worst_cell_losses": 3,
		# The held-ground row reads these two now, not the pair above; a card
		# built without them renders the "no ground held them" branch and stops
		# being the widest row, which is what the last assertion here is about.
		"stop_cell": Vector2i(13, 7),
		"stop_cell_stops": 137,
	}
	var panel := RunSummary.build(stats)
	await _T.instantiate_scene(panel)
	var rows: Array = panel.summary_rows()

	var err: String = _T.assert_eq(rows.size(), 7,
		"the card is still seven rows — the denominator was folded into one, not given its own")
	var compost: Label = panel.get_node_or_null("Value_Compostswept") as Label
	if err == "":
		err = _T.assert_true(compost != null, "the compost row is on the card")
	if err == "":
		err = _T.assert_eq(compost.text, "1994 of 2887",
			"showing the fraction, four digits and all")

	# Height: the same measurement the selftest clearance gate makes.
	if err == "":
		var lowest: float = 0.0
		var measured: int = 0
		for row: Array in rows:
			var label: Label = panel.get_node_or_null(
				"Value_%s" % String(row[0]).replace(" ", "")) as Label
			if label != null:
				lowest = maxf(lowest, label.position.y + label.size.y)
				measured += 1
		err = _T.assert_eq(measured, rows.size(),
			"every row was really measured — a missing label would make the clearance below meaningless")
		if err == "":
			var button: Button = panel.get_node_or_null("ReplayButton") as Button
			err = _T.assert_true(button != null, "the replay button exists to measure against")
			if err == "":
				err = _T.assert_true(lowest <= button.position.y - RunSummary.BUTTON_CLEARANCE,
					"the last row foot %.0f keeps %dpx clear of the buttons at %.0f"
						% [lowest, int(RunSummary.BUTTON_CLEARANCE), button.position.y])

	# Width: the reason the fold was affordable in the first place. The value
	# column is 335px and this row is nowhere near the one that sets the card's
	# width, so the fraction never reaches clip_text / OVERRUN_TRIM_ELLIPSIS.
	var column: float = RunSummary.CARD.size.x * 0.58 - RunSummary.ROW_INSET
	if err == "":
		# Measured off the font, NOT off get_minimum_size(): every value label sets
		# clip_text, and a clipping Label reports a minimum width of 1px by design,
		# so all three comparisons below would have passed for free.
		var font: Font = compost.get_theme_font("font")
		var font_size: int = compost.get_theme_font_size("font_size")
		err = _T.assert_true(font != null, "the row has a font to measure with")
		if err == "":
			var wanted: float = font.get_string_size(
				compost.text, HORIZONTAL_ALIGNMENT_RIGHT, -1, font_size).x
			err = _T.assert_gt(wanted, 1.0,
				"the font really measured the fraction — a 1px answer is the clip_text stub, not a width")
			if err == "":
				err = _T.assert_true(wanted <= column,
					"the fraction fits its column without ellipsis (%.0f of %.0f px)" % [wanted, column])
			if err == "":
				var worst: Label = panel.get_node_or_null("Value_Whereyouheldthem") as Label
				err = _T.assert_true(worst != null, "the held-ground row exists")
				if err == "":
					var widest: float = font.get_string_size(
						worst.text, HORIZONTAL_ALIGNMENT_RIGHT, -1, font_size).x
					err = _T.assert_gt(widest, wanted,
						"and the held-ground row, not compost, still sets the card's width (%.0f vs %.0f px)"
							% [widest, wanted])
					if err == "":
						# Which the old version of this test never asked: it proved
						# the compost fraction fitted and that a different row was
						# wider, leaving the row that actually sets the high-water
						# mark unmeasured against the column it has to fit inside.
						err = _T.assert_true(widest <= column,
							"and the widest row itself fits the column (%.0f of %.0f px)"
								% [widest, column])
	_T.free_ui(panel)
	return err


func test_a_card_with_no_denominator_falls_back_to_the_bare_tally() -> String:
	## The absent-key branch. `compost_resolved` defaults to -1 rather than to the
	## numerator on purpose: a stats dictionary that predates the denominator must
	## degrade to the number it always showed, not invent a perfect "12 of 12" it
	## has no evidence for — while a run that really did sweep everything still
	## gets to say so.
	var missing := RunSummary.build({"compost_total": 12})
	var perfect := RunSummary.build({"compost_total": 12, "compost_resolved": 12})
	var partial := RunSummary.build({"compost_total": 12, "compost_resolved": 31})
	var empty := RunSummary.build({"compost_total": 0, "compost_resolved": 0})

	var err: String = _T.assert_eq(missing._compost_text(), "12",
		"no denominator, no fraction — the row reads as it always did")
	if err == "":
		err = _T.assert_eq(perfect._compost_text(), "12 of 12",
			"a genuine clean sweep is allowed to say so")
	if err == "":
		err = _T.assert_eq(partial._compost_text(), "12 of 31",
			"and a run that let two thirds rot cannot hide behind the numerator")
	if err == "":
		err = _T.assert_eq(empty._compost_text(), "0",
			"a run where no husk ever resolved reads 0, not a nonsense 0 of 0")
	missing.free()
	perfect.free()
	partial.free()
	empty.free()
	return err


## _build_heading already picks a different heading text and colour for
## victory; the entrance must agree rather than rising every Control by the
## same offset regardless of `won` (plant-tower-defense-9ti). `_play_entrance`
## is called directly rather than through `_ready()`, the same way
## `test_the_wave_banner_appears_on_announcement_and_clears_itself` reaches
## `_fade_banner` directly -- headless never pumps the tween's frame, so the
## position right after the call is the pre-tween offset, which is exactly
## the number this test needs to tell the two branches apart.
func test_the_entrance_rise_agrees_with_the_heading_about_won() -> String:
	var win := RunSummary.build({"victory": true})
	await _T.instantiate_ui(win, Vector2i(1152, 648))
	var loss := RunSummary.build({"victory": false})
	await _T.instantiate_ui(loss, Vector2i(1152, 648))

	var win_heading: Label = win.get_node_or_null("Heading") as Label
	var loss_heading: Label = loss.get_node_or_null("Heading") as Label
	var err: String = _T.assert_true(win_heading != null and loss_heading != null,
		"both cards built a heading")
	if err == "":
		var win_rest: float = win_heading.position.y
		var loss_rest: float = loss_heading.position.y
		win._play_entrance()
		loss._play_entrance()
		var win_offset: float = win_heading.position.y - win_rest
		var loss_offset: float = loss_heading.position.y - loss_rest
		err = _T.assert_float_eq(win_offset, RunSummary.RISE_OFFSET_WIN, 0.01,
			"a win rises by its own offset, not the loss offset (%.1f)" % win_offset)
		if err == "":
			err = _T.assert_float_eq(loss_offset, RunSummary.RISE_OFFSET_LOSS, 0.01,
				"and a loss rises by its own, distinct offset (%.1f)" % loss_offset)
		if err == "":
			err = _T.assert_true(not is_equal_approx(win_offset, loss_offset),
				"win and loss must not have quietly ended up with the same motion")
	_T.free_ui(win)
	_T.free_ui(loss)
	return err


# -- Lane pressure during prep (issue 842) ----------------------------------


## The reading the prep window is built on. Depth is a mean weighted by how many
## pests stopped at each cell, not an average over the cells that happen to be
## lit, and the difference is the whole point: four pests killed at the gate and
## sixteen killed at the exit is a run in trouble, while "one lit cell at each
## end" reads as a tidy 50% either way.
func test_the_run_depth_is_weighted_by_losses_not_by_lit_cells() -> String:
	var board := Board.new()
	await _T.instantiate_scene(board)
	var err: String = _T.assert_true(board != null, "the board stood up")
	if err != "":
		return err
	err = _T.assert_gt(board.path_cell_count(), 0, "the road has cells to measure along")
	if err != "":
		_T.free_ui(board)
		return err

	var entry: Vector2i = Board.PATH_CORNERS[0]
	var last_cell: Vector2i = board.exit_cell()
	err = _T.assert_eq(board.path_index(entry), 0, "the first corner is the head of the road")
	if err == "":
		err = _T.assert_eq(board.path_index(last_cell), board.path_cell_count() - 1,
			"and exit_cell() is its tail")
	if err == "":
		err = _T.assert_float_eq(board.run_depth(), -1.0, 0.001,
			"a board that has recorded nothing reports -1, not a 0% it did not earn")
	if err == "":
		board.record_lane_pressure_wave({entry: 4})
		err = _T.assert_float_eq(board.last_wave_depth(), 0.0, 0.001,
			"a wave killed dead on the entry cell really is 0% down the road")
	if err == "":
		board.record_lane_pressure_wave({last_cell: 4})
		err = _T.assert_float_eq(board.last_wave_depth(), 1.0, 0.001,
			"and the next wave, stopped at the exit, is 100%")
	if err == "":
		err = _T.assert_float_eq(board.run_depth(), 0.5, 0.001,
			"four at each end averages to the middle of the road")
	if err == "":
		# The assertion an unweighted mean fails: still two lit cells, still one
		# at each end, but four times as many pests reached the far one.
		board.record_lane_pressure_wave({last_cell: 12})
		err = _T.assert_float_eq(board.run_depth(), 0.8, 0.001,
			"4 at the gate against 16 at the exit is 80% down, not 50%")
	_T.free_ui(board)
	return err


## A wave that lost nothing never reaches record_lane_pressure_wave's body, so
## it neither fades the road nor replaces the last-wave reading. The prep line
## and the tint therefore always describe the SAME wave -- the last one that drew
## blood -- which is the property that stops the sentence contradicting the paint.
func test_a_clean_wave_leaves_both_the_tint_and_the_prep_reading_alone() -> String:
	var board := Board.new()
	await _T.instantiate_scene(board)
	var err: String = _T.assert_true(board != null, "the board stood up")
	if err != "":
		return err
	var last_cell: Vector2i = board.exit_cell()
	board.record_lane_pressure_wave({last_cell: 3})
	var before: float = board.last_wave_depth()
	err = _T.assert_float_eq(before, 1.0, 0.001, "the wave that broke through reads 100%")
	if err == "":
		# A wave nobody lost a pest to, and one whose losses are all off-road.
		var nothing: Dictionary = {}
		var off_road: Dictionary = {Vector2i(0, 0): 9}
		board.record_lane_pressure_wave(nothing)
		board.record_lane_pressure_wave(off_road)
		err = _T.assert_float_eq(board.last_wave_depth(), before, 0.001,
			"a wave that stopped nothing on the road cannot rewrite the reading")
	if err == "":
		err = _T.assert_float_eq(board.lane_pressure_alpha(last_cell), 1.0, 0.001,
			"and the tint it left is not faded by a wave that recorded nothing")
	_T.free_ui(board)
	return err


## The three branches of the sentence, plus the band edge. Pure and static, so
## every branch is assertable without standing up a HUD.
func test_the_prep_line_names_which_way_the_front_moved() -> String:
	var err: String = _T.assert_eq(Hud.prep_depth_note(0.80, 0.60),
		"Pests got 80% down the road — deeper than the run's 60%.",
		"a wave that got further than usual says so")
	if err == "":
		err = _T.assert_eq(Hud.prep_depth_note(0.40, 0.60),
			"Pests got 40% down the road — shallower than the run's 60%.",
			"and a wave held short of usual says that instead")
	if err == "":
		err = _T.assert_eq(Hud.prep_depth_note(0.62, 0.60),
			"Pests got 62% down the road, the run's usual depth.",
			"two points of drift is noise, and the line refuses to dress it as news")
	if err == "":
		# The edge, spelled out: the band is inclusive, so a move of exactly
		# PREP_DEPTH_BAND is still "usual". Left unpinned, a later tweak to the
		# comparison flips this without failing anything.
		err = _T.assert_eq(Hud.prep_depth_note(0.60 + Hud.PREP_DEPTH_BAND, 0.60),
			"Pests got 65% down the road, the run's usual depth.",
			"a move of exactly the band is still inside it")
	if err == "":
		err = _T.assert_eq(Hud.prep_depth_note(0.0, 0.0),
			"Pests got 0% down the road, the run's usual depth.",
			"0% is a real reading -- the best one in the game -- and must not be silence")
	if err == "":
		err = _T.assert_eq(Hud.prep_depth_note(-1.0, -1.0), "",
			"but 'nothing recorded' is silence, and that is a different thing")
	if err == "":
		err = _T.assert_eq(Hud.wave_cleared_line(7, ""), "Wave 7 cleared.",
			"an empty note leaves no trailing space behind the full stop")
	return err


## MessageLabel clips with an ellipsis, so a prep line that outgrows the status
## row renders trimmed and nothing complains. Measured off the resolved theme
## font, NOT get_minimum_size(): the label sets clip_text, and a clipping Label
## reports a 1px minimum by design, which would make this assertion pass for any
## string anyone ever wrote.
func test_the_wave_cleared_line_fits_the_status_row() -> String:
	var game := await _T.instantiate_ui("res://game/game.tscn", Vector2i(1152, 648)) as Game
	var err: String = _T.assert_true(game != null, "the game scene loaded")
	if err != "":
		return err
	err = _T.assert_true(game.hud != null, "the run has a HUD")
	if err != "":
		_T.free_ui(game)
		return err
	var label: Label = game.hud.get_node_or_null("Root/TopBar/MessageLabel") as Label
	err = _T.assert_true(label != null, "the status row exists")
	if err == "":
		# Pinned to the formatters rather than to the literal. A reworded note
		# that nobody copies into the constant is exactly how a silent clip ships.
		# 0.948 against 1.0 is the widest branch that is actually reachable:
		# "shallower" needs to be under the run by more than the band, so a 100%
		# wave can never take it, and 0.948 rounds up to the 95 declared.
		err = _T.assert_eq(Hud.PREP_NOTE_WORST_CASE,
			Hud.wave_cleared_line(9999, Hud.prep_depth_note(0.948, 1.0)),
			"the declared worst case is the line the formatters actually build")
	if err == "":
		var font: Font = label.get_theme_font("font")
		err = _T.assert_true(font != null, "the row has a font to measure with")
		if err == "":
			var size_px: int = label.get_theme_font_size("font_size")
			if size_px <= 0:
				size_px = label.get_theme_default_font_size()
			var drawn: float = font.get_string_size(
				Hud.PREP_NOTE_WORST_CASE, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
			err = _T.assert_gt(drawn, 1.0,
				"the font really measured the line -- a 1px answer is the clip_text stub, not a width")
			if err == "":
				err = _T.assert_gt(label.size.x, 1.0,
					"and the row has a real width to measure against")
			if err == "":
				err = _T.assert_true(drawn <= label.size.x,
					"the worst-case prep line fits the status row without ellipsis (%.0f of %.0f px)"
						% [drawn, label.size.x])
	_T.free_ui(game)
	return err


## End to end through the real run: the reading has to leave the Board, survive
## Game's fallback and come back as the sentence the player reads. Asserting the
## depth arithmetic alone would pass just as happily with the wiring cut.
func test_the_prep_window_reports_the_run_and_not_only_the_countdown() -> String:
	var game := await _T.instantiate_scene("res://game/game.tscn") as Game
	var err: String = _T.assert_true(game != null, "the game scene loaded")
	if err != "":
		return err
	err = _T.assert_true(game.board != null, "the run has a board")
	if err != "":
		_T.free_ui(game)
		return err
	err = _T.assert_gt(game.board.path_cell_count(), 0, "with a road to measure along")
	if err == "":
		# Nothing stopped anywhere yet, so there is no depth and the window falls
		# back to the countdown -- the only case where restating the prep strip is
		# worth a whole line.
		err = _T.assert_eq(game.prep_note(),
			"Next one grows in %d seconds." % int(Game.PREP_SECONDS),
			"a run that has stopped nothing has nothing to report")
	var entry: Vector2i = Board.PATH_CORNERS[0]
	var last_cell: Vector2i = game.board.exit_cell()
	if err == "":
		err = _T.assert_gt(game.board.path_index(last_cell), game.board.path_index(entry),
			"the exit really is further down the road than the entry")
	if err == "":
		var first: Dictionary = {entry: 5}
		var second: Dictionary = {last_cell: 5}
		game.board.record_lane_pressure_wave(first)
		game.board.record_lane_pressure_wave(second)
		err = _T.assert_eq(game.prep_note(),
			"Pests got 100% down the road — deeper than the run's 50%.",
			"and once two waves are on record the window says which way the front moved")
	if err == "":
		err = _T.assert_eq(Hud.wave_cleared_line(2, game.prep_note()),
			"Wave 2 cleared. Pests got 100% down the road — deeper than the run's 50%.",
			"which is what the status row actually receives")
	_T.free_ui(game)
	return err


# -- The post-mortem's chokepoint row (issue dwv) ----------------------------


## The inversion, staged end to end through a real run.
##
## Twelve pests killed on one cell and three walked out at the exit. The killing
## cell wins the loss map, which is correct and unchanged — and the card used to
## head that number "Weakest ground", naming the player's best turret as the one
## thing in the garden to tear out. Nothing about the data was wrong; the sentence
## over it was the inverse of the data.
func test_a_defended_chokepoint_is_not_reported_as_weak_ground() -> String:
	var game := await _T.instantiate_scene("res://game/game.tscn") as Game
	var err: String = _T.assert_true(game != null, "the game scene loaded")
	if err != "":
		return err
	err = _T.assert_true(game.board != null, "the run has a board to record against")
	if err != "":
		_T.free_ui(game)
		return err
	var choke: Vector2i = Board.PATH_CORNERS[1]
	var way_out: Vector2i = game.board.exit_cell()
	err = _T.assert_true(game.board.is_path(choke) and game.board.is_path(way_out),
		"both cells under test are road — an off-road cell is dropped and every count below would be 0")
	if err == "":
		err = _T.assert_true(choke != way_out,
			"and the chokepoint is not itself the exit, or the two readings cannot disagree")
	if err != "":
		_T.free_ui(game)
		return err

	game._on_wave_started(1)
	var kills: int = 12
	for i: int in range(kills):
		game._note_lane_loss(game.board.cell_to_world(choke))
	# The real losing path: the third escape takes the last bed, and that is what
	# commits both tallies to the board.
	game.lives = 3
	for i: int in range(3):
		game._on_pest_escaped(null)
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	err = _T.assert_true(game.game_over, "the run ended, so the wave's tallies were committed")
	if err != "":
		_T.free_ui(game)
		return err

	# The map is untouched. Depth and the painted road want kills and escapes
	# summed, and these are the assertions that say the fix did not quietly
	# change what the overlay is showing.
	err = _T.assert_eq(int(game.board.run_losses().get(choke, 0)), kills,
		"the loss map still counts all %d kills at the chokepoint" % kills)
	if err == "":
		err = _T.assert_eq(game.board.worst_run_cell(), choke,
			"and the painted map still peaks there")
	if err == "":
		err = _T.assert_eq(game.board.stops_at(choke), kills,
			"every one of those was a pest stopped for good")
	if err == "":
		err = _T.assert_eq(game.board.stops_at(way_out), 0,
			"while the exit stopped nothing at all — its three losses all walked out")
	if err == "":
		err = _T.assert_eq(game.board.worst_stop_cell(), choke,
			"so the cell that did the defending is the one the card gets")

	var stats: Dictionary = game.summary_stats(false)
	if err == "":
		err = _T.assert_true(stats.has("stop_cell") and stats.has("stop_cell_stops"),
			"summary_stats carries the held-ground reading")
	if err == "":
		err = _T.assert_eq(stats["stop_cell"], choke, "and it is the chokepoint")
	if err == "":
		err = _T.assert_eq(int(stats["stop_cell_stops"]), kills, "with the kills it really made")

	var panel: RunSummary = game.get_node_or_null("SummaryLayer/RunSummary") as RunSummary
	if err == "":
		err = _T.assert_true(panel != null, "the post-mortem card is up")
	if err == "":
		var rows: Array = panel.summary_rows()
		err = _T.assert_gt(rows.size(), 0, "the card has rows to read")
		if err == "":
			# The label itself, not only the number under it. "Weakest ground" over
			# a chokepoint is the whole defect; a card that names the right cell
			# under the wrong heading still tells the player to dig it up.
			for row: Array in rows:
				var key: String = String(row[0])
				err = _T.assert_false(key.to_lower().contains("weak"),
					"no row calls a cell weak (found '%s')" % key)
				if err != "":
					break
	if err == "":
		var value: Label = panel.get_node_or_null("Value_Whereyouheldthem") as Label
		err = _T.assert_true(value != null, "the held-ground row is on the card")
		if err == "":
			err = _T.assert_eq(value.text, "column %d, row %d — %d held"
				% [choke.x + 1, choke.y + 1, kills],
				"and it reads as work the ground did, not as ground that failed")
		if err == "":
			err = _T.assert_false(value.text.contains("lost"),
				"nothing on this row describes the chokepoint as a loss")
	_T.free_ui(game)
	return err


## The other half, and the reason a relabel alone would not have been enough.
##
## Escapes all land on one cell — Game._on_pest_escaped attributes every one of
## them to exit_cell(), because an escaped pest's own position is off the board —
## so a run that bleeds out hands the exit a loss count it earned by not
## fighting. Under the old heading that cell was "weakest ground": true, but the
## same cell every run, which is no reading at all. Under a bare relabel it would
## have become "where they stopped", which is false. It stopped nothing — and
## "stopped" is the tint's own word for its own reading anyway, which is why the
## row now says "held".
func test_escapes_cannot_buy_the_exit_a_chokepoint_it_never_earned() -> String:
	var game := await _T.instantiate_scene("res://game/game.tscn") as Game
	var err: String = _T.assert_true(game != null, "the game scene loaded")
	if err != "":
		return err
	err = _T.assert_true(game.board != null, "the run has a board")
	if err != "":
		_T.free_ui(game)
		return err
	var choke: Vector2i = Board.PATH_CORNERS[1]
	var way_out: Vector2i = game.board.exit_cell()
	err = _T.assert_true(game.board.is_path(choke) and choke != way_out,
		"the chokepoint is real road and is not the exit")
	if err != "":
		_T.free_ui(game)
		return err

	game._on_wave_started(1)
	var kills: int = 4
	# Every life, so the run ends on the escapes themselves rather than on a
	# shortened `lives`. Forcing lives down to make game over arrive sooner also
	# desynchronises the beds row, which counts LIVES - lives and therefore
	# reports the whole garden lost however few pests actually walked out.
	var escapes: int = Game.LIVES
	for i: int in range(kills):
		game._note_lane_loss(game.board.cell_to_world(choke))
	for i: int in range(escapes):
		game._on_pest_escaped(null)
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	err = _T.assert_true(game.game_over, "the run ended and committed its tallies")
	if err != "":
		_T.free_ui(game)
		return err

	err = _T.assert_eq(int(game.board.run_escapes().get(way_out, 0)), escapes,
		"all %d escapes were recorded against the exit" % escapes)
	if err == "":
		err = _T.assert_eq(game.board.worst_run_cell(), way_out,
			"which is enough to make the exit the reddest cell on the map (%d beats %d)"
				% [escapes, kills])
	if err == "":
		err = _T.assert_eq(game.board.stops_at(way_out), 0,
			"and yet it stopped nothing — every loss there walked out of it")
	if err == "":
		err = _T.assert_eq(game.board.worst_stop_cell(), choke,
			"so the row names the cell that actually fought, not the one that leaked")
	if err == "":
		var stats: Dictionary = game.summary_stats(false)
		err = _T.assert_eq(stats["worst_cell"], way_out,
			"the map's peak is still reported, because the road under the card is painted from it")
		if err == "":
			err = _T.assert_eq(stats["stop_cell"], choke,
				"while the row's cell is the one that stopped the most")
	if err == "":
		var value: Label = game.get_node_or_null(
			"SummaryLayer/RunSummary/Value_Whereyouheldthem") as Label
		err = _T.assert_true(value != null, "the held-ground row is on the card")
		if err == "":
			err = _T.assert_eq(value.text, "column %d, row %d — %d held"
				% [choke.x + 1, choke.y + 1, kills],
				"naming the chokepoint and its real work, not the exit and its leak")
	if err == "":
		# The escapes are not missing from the card, they are on the row that
		# measures them directly. This is why the fix costs no eighth row.
		var beds: Label = game.get_node_or_null("SummaryLayer/RunSummary/Value_Gardenlost") as Label
		err = _T.assert_true(beds != null, "the beds-lost row exists")
		if err == "":
			err = _T.assert_eq(beds.text, "%d of %d beds" % [escapes, Game.LIVES],
				"and it is where the escapes are reported, once")
	_T.free_ui(game)
	return err


## Board-level, no Game: what stops_at subtracts, and what it refuses to.
func test_a_cells_stops_are_its_losses_minus_the_pests_that_walked_out() -> String:
	var board := Board.new()
	await _T.instantiate_scene(board)
	var err: String = _T.assert_true(board != null, "the board stood up")
	if err != "":
		return err
	err = _T.assert_gt(board.path_cell_count(), 0, "with a road to record against")
	if err != "":
		_T.free_ui(board)
		return err

	var held: Vector2i = Board.PATH_CORNERS[0]
	var leaked: Vector2i = board.exit_cell()
	var grass := Vector2i(0, 0)
	err = _T.assert_false(board.is_path(grass), "(0,0) is grass, as the pressure tests rely on")
	if err == "":
		err = _T.assert_eq(board.worst_stop_cell(), Vector2i(-1, -1),
			"an empty board points nowhere — not at column 0")
	if err == "":
		board.record_lane_pressure_wave({held: 5, leaked: 4})
		board.record_escapes({leaked: 3})
		err = _T.assert_eq(board.stops_at(held), 5, "a cell with no escapes keeps all its losses")
	if err == "":
		err = _T.assert_eq(board.stops_at(leaked), 1,
			"and a cell that let 3 of 4 walk out is credited with the one it kept")
	if err == "":
		err = _T.assert_eq(board.worst_stop_cell(), held, "5 stops beats 1")
	if err == "":
		err = _T.assert_eq(board.worst_run_cell(), held,
			"and the loss map, which sums the two, is untouched by any of this")
	if err == "":
		# The floor. record_escapes is documented as a companion to
		# record_lane_pressure_wave rather than a replacement, and a caller that
		# ignores that must not make a cell report a negative amount of defending.
		board.record_escapes({leaked: 99})
		err = _T.assert_eq(board.stops_at(leaked), 0,
			"more escapes than losses floors at zero rather than going negative")
	if err == "":
		board.record_escapes({grass: 7})
		err = _T.assert_eq(int(board.run_escapes().get(grass, 0)), 0,
			"an escape off the road is dropped, the same filter the pressure map applies")
	if err == "":
		err = _T.assert_eq(board.stops_at(grass), 0, "so grass still stopped nothing")
	_T.free_ui(board)
	return err


## The empty branch, which is the one that used to lie hardest. "nothing got past
## you" is a claim about escapes read off an empty measurement of kills: the run
## that reaches it most often is the one that never stopped a single pest, and
## the card congratulated it.
func test_a_run_that_stopped_nothing_is_not_congratulated() -> String:
	var barren := RunSummary.build({"lives_lost": 10})
	var err: String = _T.assert_true(barren != null, "the card built without any held ground")
	if err != "":
		return err
	var text: String = barren._stop_cell_text()
	err = _T.assert_eq(text, "nowhere — no ground held them",
		"an absent measurement says so")
	if err == "":
		err = _T.assert_false(text.contains("past you"),
			"and never claims a clean run it has no evidence for")
	barren.free()

	if err == "":
		var real := RunSummary.build({"stop_cell": Vector2i(6, 3), "stop_cell_stops": 41})
		err = _T.assert_true(real != null, "the card built with one")
		if err == "":
			err = _T.assert_eq(real._stop_cell_text(), "column 7, row 4 — 41 held",
				"and a chokepoint gets named one-based, like every coordinate the player sees")
		real.free()
	return err


## The row's key grew from "Weakest ground" to "Where they stopped" to "Where you
## held them" — each rename longer than the last — and the key
## and value boxes overlap by 36px by construction: the key spans ROW_INSET to
## 0.42w + ROW_INSET while the value starts at 0.42w. Left-aligned key against
## right-aligned value, so that overlap is only a collision if the key's own text
## runs into it — which is a thing a longer key can newly do.
func test_no_post_mortem_key_runs_into_its_own_value_column() -> String:
	var stats: Dictionary = {
		"victory": false,
		"endless": false,
		"wave": 8,
		"wave_count": 8,
		"threat_level": 5,
		"lives_lost": 6,
		"seeds_earned_total": 940,
		"high_score": 1200,
		"compost_total": 17,
		"compost_resolved": 31,
		"pests_defeated": 214,
		"run_seconds": 640.0,
		"worst_cell": Vector2i(13, 7),
		"worst_cell_losses": 9,
		"stop_cell": Vector2i(13, 7),
		"stop_cell_stops": 137,
	}
	var panel := RunSummary.build(stats)
	await _T.instantiate_scene(panel)
	var rows: Array = panel.summary_rows()
	var err: String = _T.assert_eq(rows.size(), 7,
		"still seven rows — this fix bought no eighth, which would foot at 486 against buttons at 476")
	if err != "":
		_T.free_ui(panel)
		return err

	var checked: int = 0
	for row: Array in rows:
		var flat: String = String(row[0]).replace(" ", "")
		var key: Label = panel.get_node_or_null("Row_%s" % flat) as Label
		var value: Label = panel.get_node_or_null("Value_%s" % flat) as Label
		if key == null or value == null:
			err = "row '%s' is missing a label" % String(row[0])
			break
		# Measured off the resolved theme font, NOT get_minimum_size(): the value
		# labels set clip_text and report a 1px minimum, and a width gate built
		# that way passes unconditionally.
		var font: Font = key.get_theme_font("font")
		var font_size: int = key.get_theme_font_size("font_size")
		if font == null:
			err = "row '%s' has no font to measure with" % String(row[0])
			break
		var drawn: float = font.get_string_size(
			key.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		err = _T.assert_gt(drawn, 1.0,
			"the font really measured '%s' — a 1px answer is a stub, not a width" % key.text)
		if err != "":
			break
		var budget: float = value.position.x - key.position.x
		err = _T.assert_true(drawn <= budget,
			"key '%s' is %.0fpx and has %.0fpx before the value column starts"
				% [key.text, drawn, budget])
		if err != "":
			break
		checked += 1
	if err == "":
		err = _T.assert_eq(checked, rows.size(),
			"every row was really measured — a short loop is what makes a width gate vacuous")
	_T.free_ui(panel)
	return err


# -- The post-mortem card against the road it floats over --------------------


## plant-tower-defense-e34, staged end to end.
##
## The card names a cell out of `stop_cell` (losses minus escapes) while the road
## under it is painted from the RAW loss map, whose peak on a bleeding run is the
## exit. Both are correct and a player wants both. What there was no way to know
## was that they are two different questions — an unlabelled picture sitting next
## to a number reads as a picture that number captions.
##
## The fix is a caption, not a collapse: `RunSummary.map_legend_text` names the
## reddest cell out of `worst_cell`, which is the same value the paint is made
## from, so the sentence and the tint cannot drift apart.
func test_the_post_mortem_captions_the_red_road_instead_of_letting_it_read_as_the_row() -> String:
	var game := await _T.instantiate_scene("res://game/game.tscn") as Game
	var err: String = _T.assert_true(game != null, "the game scene loaded")
	if err != "":
		return err
	err = _T.assert_true(game.board != null, "the run has a board to record against")
	if err != "":
		_T.free_ui(game)
		return err

	var choke: Vector2i = Board.PATH_CORNERS[1]
	var way_out: Vector2i = game.board.exit_cell()
	err = _T.assert_true(game.board.is_path(choke) and game.board.is_path(way_out),
		"both cells under test are road — an off-road cell is dropped and every count below is 0")
	if err == "":
		err = _T.assert_true(choke != way_out,
			"and they are different cells, or the mismatch this test is about cannot exist")
	if err != "":
		_T.free_ui(game)
		return err

	# The bleeding run. Every life spent, so the beds row and the escape count
	# agree — forcing `lives` down instead desynchronises them (LIVES - lives).
	game._on_wave_started(1)
	var kills: int = 4
	var escapes: int = Game.LIVES
	for i: int in range(kills):
		game._note_lane_loss(game.board.cell_to_world(choke))
	for i: int in range(escapes):
		game._on_pest_escaped(null)
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	err = _T.assert_true(game.game_over, "the run ended and committed its tallies")
	if err != "":
		_T.free_ui(game)
		return err

	# The precondition the whole issue rests on, asserted rather than assumed:
	# the reddest cell and the named cell really are different here.
	err = _T.assert_eq(game.board.worst_run_cell(), way_out,
		"the paint peaks at the exit (%d escapes beat %d kills)" % [escapes, kills])
	if err == "":
		err = _T.assert_eq(game.board.worst_stop_cell(), choke,
			"while the row's cell is the one that actually fought")
	if err != "":
		_T.free_ui(game)
		return err

	var panel: RunSummary = game.get_node_or_null("SummaryLayer/RunSummary") as RunSummary
	err = _T.assert_true(panel != null, "the post-mortem card is up")
	if err != "":
		_T.free_ui(game)
		return err

	var legend: Label = panel.get_node_or_null("MapLegend") as Label
	err = _T.assert_true(legend != null,
		"the road under the card carries a caption when there is paint on it")
	if err != "":
		_T.free_ui(game)
		return err
	err = _T.assert_gt(legend.text.length(), 0, "and the caption is not an empty label")

	var red_here: String = "column %d, row %d" % [way_out.x + 1, way_out.y + 1]
	var held_here: String = "column %d, row %d" % [choke.x + 1, choke.y + 1]
	if err == "":
		err = _T.assert_true(legend.text.contains(red_here),
			"the caption names the reddest cell (%s), which is what the player can see" % red_here)
	if err == "":
		err = _T.assert_false(legend.text.contains(held_here),
			"and does not name the held cell — that is the card's job, and duplicating it here is how the two readings get confused again")
	if err == "":
		err = _T.assert_true(legend.text.to_lower().contains("how far they got"),
			"and it states which question the paint answers, not merely which cell won it")

	# The other half of the pair: the row still names the cell that fought, and
	# says nothing about the exit.
	var value: Label = panel.get_node_or_null("Value_Whereyouheldthem") as Label
	if err == "":
		err = _T.assert_true(value != null, "the held-ground row is on the card")
	if err == "":
		err = _T.assert_true(value.text.contains(held_here),
			"the row names the cell that held (%s)" % held_here)
	if err == "":
		err = _T.assert_false(value.text.contains(red_here),
			"and never the reddest one, which held nothing")
	if err == "":
		# The word collision that made this readable as one reading. Board.depth_of
		# documents the mixed map's own contents as "every pest that STOPPED there",
		# so a row headed "where they stopped" described the paint at least as well
		# as it described this number.
		var keys: Array = panel.summary_rows()
		err = _T.assert_gt(keys.size(), 0, "the card has rows to read")
		if err == "":
			var checked: int = 0
			for row: Array in keys:
				err = _T.assert_false(String(row[0]).to_lower().contains("stopped"),
					"no row borrows the tint's own word for a different measurement (found '%s')"
						% String(row[0]))
				if err != "":
					break
				checked += 1
			if err == "":
				err = _T.assert_eq(checked, keys.size(), "and every row key was really read")
	_T.free_ui(game)
	return err


## Where the caption is allowed to sit, in numbers rather than by eye.
##
## Three things can be underneath it and only one of them is acceptable. The
## card's paper foots at 552 and its drop shadow reaches further; the road's last
## row is screen y 520..584 once Hud.BAR_HEIGHT is added, and a caption covering
## THAT would hide the exact tint it exists to explain; and the viewport ends at
## 648. Grass row 8 is the gap all three leave, and that is where it goes.
func test_the_map_legend_clears_the_card_the_road_and_the_bottom_of_the_screen() -> String:
	# A Board that never entered the tree, queried directly. exit_cell() is asked
	# FIRST on purpose: it used to be the one public query on Board that did not
	# build the road lazily, so this call answered (-1, -1) and every geometry
	# number below would have been measured against a cell that does not exist —
	# a whole test passing on nothing, which is the failure mode is_path()'s own
	# docstring was written about.
	var probe := Board.new()
	var way_out: Vector2i = probe.exit_cell()
	var err: String = _T.assert_true(way_out.x >= 0 and way_out.y >= 0,
		"an untreed Board still knows its exit (%s) rather than answering (-1, -1)" % str(way_out))
	if err == "":
		err = _T.assert_gt(probe.path_cell_count(), 0, "and it really has a road")
	if err == "":
		err = _T.assert_true(probe.is_path(way_out), "whose last cell is that exit")
	probe.free()
	if err != "":
		return err

	var panel := RunSummary.build({
		"victory": false,
		"endless": false,
		"wave": 6,
		"wave_count": 8,
		"threat_level": 4,
		"lives_lost": Game.LIVES,
		"seeds_earned_total": 512,
		"high_score": 900,
		"compost_total": 8,
		"compost_resolved": 20,
		"pests_defeated": 61,
		"run_seconds": 402.0,
		# The disagreeing pair, which is the branch that produces the long text.
		"worst_cell": way_out,
		"worst_cell_losses": Game.LIVES,
		"stop_cell": Vector2i(9, 1),
		"stop_cell_stops": 24,
	})
	await _T.instantiate_ui(panel, Vector2i(1152, 648))
	var legend: Label = panel.get_node_or_null("MapLegend") as Label
	err = _T.assert_true(legend != null, "the caption is on the screen")
	if err != "":
		_T.free_ui(panel)
		return err

	var top: float = legend.position.y
	var foot: float = legend.position.y + legend.size.y
	err = _T.assert_gt(legend.size.y, 0.0, "the caption has a box to measure")

	# 1. Clear of the card, drop shadow included. Read off the stylebox rather
	#    than hardcoded: a designer raising shadow_size must fail here, not ship a
	#    caption sitting in a smudge.
	if err == "":
		var box: StyleBoxFlat = GardenTheme.paper_panel()
		err = _T.assert_true(box != null, "the card's stylebox is readable")
		if err == "":
			var shadow_foot: float = (RunSummary.CARD.position.y + RunSummary.CARD.size.y
				+ box.shadow_offset.y + float(box.shadow_size))
			err = _T.assert_true(top >= shadow_foot,
				"the caption starts at %.0f, below the card's shadow at %.0f" % [top, shadow_foot])

	# 2. Clear of the road. This is the one that matters: the caption explains the
	#    tint, so covering any of it is the failure mode with no visible symptom.
	if err == "":
		var road_foot: float = float(Hud.BAR_HEIGHT + (way_out.y + 1) * Board.CELL)
		err = _T.assert_true(top >= road_foot,
			"the caption starts at %.0f, below the last road row which ends at %.0f"
				% [top, road_foot])

	# 3. On the screen at all.
	if err == "":
		var screen: float = float(ProjectSettings.get_setting(
			"display/window/size/viewport_height", 648))
		err = _T.assert_true(foot <= screen,
			"and it foots at %.0f inside a %.0f-tall viewport" % [foot, screen])

	# 4. The text fits the box it was given. Measured through the resolved theme
	#    font, NOT get_minimum_size(): every measurement of a Label on this card
	#    has to be, and this one is a Label whose text is by far the longest string
	#    the screen renders.
	if err == "":
		var font: Font = legend.get_theme_font("font")
		var font_size: int = legend.get_theme_font_size("font_size")
		err = _T.assert_true(font != null, "the caption has a font to measure with")
		if err == "":
			var drawn: float = font.get_string_size(
				legend.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
			err = _T.assert_gt(drawn, 1.0,
				"the font really measured the caption — a 1px answer is a stub, not a width")
			if err == "":
				err = _T.assert_true(drawn <= legend.size.x,
					"the caption fits its %.0fpx strip (%.0fpx drawn)" % [legend.size.x, drawn])

	# 5. And it collides with nothing else the card put on screen. The Backdrop is
	#    the whole viewport by design, so it is the one exemption.
	if err == "":
		var legend_rect := Rect2(legend.position, legend.size)
		var compared: int = 0
		for child: Node in panel.get_children():
			var other := child as Control
			if other == null or other == legend or other.name == "Backdrop":
				continue
			var rect := Rect2(other.position, other.size)
			err = _T.assert_false(legend_rect.intersects(rect),
				"the caption does not overlap '%s' at (%.0f, %.0f) %.0fx%.0f"
					% [other.name, rect.position.x, rect.position.y, rect.size.x, rect.size.y])
			if err != "":
				break
			compared += 1
		if err == "":
			err = _T.assert_gt(compared, 0,
				"and there was really something to compare against — an empty loop is what makes an overlap gate vacuous")
	_T.free_ui(panel)
	return err


## The two branches that are not "the cells disagree".
##
## A run that lost nothing anywhere gets no caption at all, because
## Board.show_run_pressure() early-returns on an empty loss map and there is no
## red road to explain. A run whose reddest cell IS the named cell still gets one:
## "these are the same cell" is a reading, and saying nothing leaves the player to
## assume it holds next run, when it will not.
func test_the_caption_appears_only_where_there_is_paint_to_caption() -> String:
	var blank := RunSummary.build({"compost_total": 3})
	var err: String = _T.assert_true(blank != null, "a card built from a run with no losses")
	if err != "":
		return err
	err = _T.assert_eq(blank.map_legend_text(), "",
		"says nothing about a road that was never painted")
	blank.free()

	if err == "":
		var agreeing := RunSummary.build({
			"worst_cell": Vector2i(6, 3),
			"worst_cell_losses": 9,
			"stop_cell": Vector2i(6, 3),
			"stop_cell_stops": 9,
		})
		err = _T.assert_true(agreeing != null, "a card whose two cells agree")
		if err == "":
			var text: String = agreeing.map_legend_text()
			err = _T.assert_gt(text.length(), 0, "still captions the paint")
			if err == "":
				err = _T.assert_false(text.contains("column"),
					"without naming a second cell the player would then go looking for")
			if err == "":
				err = _T.assert_true(text.to_lower().contains("how far they got"),
					"and still says which question the paint answers")
		agreeing.free()

	if err == "":
		var differing := RunSummary.build({
			"worst_cell": Vector2i(13, 7),
			"worst_cell_losses": 10,
			"stop_cell": Vector2i(6, 3),
			"stop_cell_stops": 9,
		})
		err = _T.assert_true(differing != null, "and a card whose cells disagree")
		if err == "":
			err = _T.assert_true(differing.map_legend_text().contains("column 14, row 8"),
				"names the reddest cell one-based, like every coordinate the player sees")
		differing.free()
	return err


## The worst run there is, which is also the one where the card and the road are
## furthest apart: every pest walked out and nothing was stopped anywhere.
##
## `stop_cell` is (-1, -1), so the row reads "nowhere". The road, meanwhile, is at
## its reddest — ten escapes stacked on the exit. A player reading "nowhere" over
## a glowing exit corner has the strongest possible reason to think the card is
## broken, so this is precisely the run the caption must not sit out.
func test_a_run_that_held_nothing_is_still_told_what_the_red_road_is() -> String:
	var game := await _T.instantiate_scene("res://game/game.tscn") as Game
	var err: String = _T.assert_true(game != null, "the game scene loaded")
	if err != "":
		return err
	err = _T.assert_true(game.board != null, "the run has a board")
	if err != "":
		_T.free_ui(game)
		return err
	var way_out: Vector2i = game.board.exit_cell()
	err = _T.assert_true(game.board.is_path(way_out), "the exit is real road")
	if err != "":
		_T.free_ui(game)
		return err

	game._on_wave_started(1)
	# No kills at all. Every life, through the real escape path.
	for i: int in range(Game.LIVES):
		game._on_pest_escaped(null)
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	err = _T.assert_true(game.game_over, "the run ended")
	if err != "":
		_T.free_ui(game)
		return err

	err = _T.assert_eq(game.board.worst_stop_cell(), Vector2i(-1, -1),
		"nothing was held anywhere, so there is no cell to name")
	if err == "":
		err = _T.assert_eq(game.board.worst_run_cell(), way_out,
			"while the loss map is at its reddest on the exit")

	var panel: RunSummary = game.get_node_or_null("SummaryLayer/RunSummary") as RunSummary
	if err == "":
		err = _T.assert_true(panel != null, "the post-mortem card is up")
	if err != "":
		_T.free_ui(game)
		return err

	var value: Label = panel.get_node_or_null("Value_Whereyouheldthem") as Label
	if err == "":
		err = _T.assert_true(value != null, "the held-ground row is on the card")
	if err == "":
		err = _T.assert_eq(value.text, "nowhere — no ground held them",
			"the row says so plainly rather than congratulating the run")
	if err == "":
		# The old empty branch said "nothing was stopped" — the tint's own word,
		# on the one run where the tint is loudest. That is the exact sentence a
		# player would have read as a caption for the red corner.
		err = _T.assert_false(value.text.contains("stopped"),
			"and does not describe an empty kill count with the paint's own verb")
	if err == "":
		var legend: Label = panel.get_node_or_null("MapLegend") as Label
		err = _T.assert_true(legend != null,
			"the caption fires on the run that needs it most, not only when a cell was held")
		if err == "":
			err = _T.assert_true(legend.text.contains(
				"column %d, row %d" % [way_out.x + 1, way_out.y + 1]),
				"and it names the exit, which is the one cell the player can actually see")
	if err == "":
		# The escapes are still reported once, as beds, exactly as before.
		var beds: Label = panel.get_node_or_null("Value_Gardenlost") as Label
		err = _T.assert_true(beds != null, "the beds-lost row exists")
		if err == "":
			err = _T.assert_eq(beds.text, "%d of %d beds" % [Game.LIVES, Game.LIVES],
				"and reports the whole garden lost, once")
	_T.free_ui(game)
	return err


# -- What an escape leaves behind -------------------------------------------


## Stands up a real run, loses the whole garden through the real escape path with
## real pests, and hands back the beds row the post-mortem printed for it.
##
## `fought` is the only difference between the two runs: whether anything in the
## garden ever reached the bugs on their way down. Returns [error, row_text] —
## GDScript has no out-params, and a helper that returned only the text would
## report a failed setup as an empty string, which is exactly the shape of a
## vacuous pass.
##
## Every bed goes, driven by the escapes themselves rather than by forcing
## `lives`: the beds row computes LIVES - lives, so a shortened `lives` would
## report the whole garden lost however few pests actually walked out.
func _staged_escape_run(fought: bool) -> Array:
	var game := await _T.instantiate_scene("res://game/game.tscn") as Game
	if game == null:
		return ["the game scene did not load", ""]
	game._on_wave_started(1)
	var staged: int = 0
	for i: int in range(Game.LIVES):
		var bug: Pest = _pest(Pest.APHID, Vector2.ZERO)
		if fought:
			# Half a kernel. The claim is that the garden reached it, not that
			# the garden nearly won — an aphid has 3 health and walks on.
			bug.take_damage(0.5)
		game._on_pest_escaped(bug)
		# Never added to the tree, so it is in no group and the losing frame's
		# call_group("pests", "queue_free") cannot reach it. Ours to free.
		bug.free()
		staged += 1
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	if staged != Game.LIVES:
		_T.free_ui(game)
		return ["only %d of %d escapes were staged" % [staged, Game.LIVES], ""]
	if not game.game_over:
		_T.free_ui(game)
		return ["the run did not end on its own escapes", ""]
	var beds: Label = game.get_node_or_null("SummaryLayer/RunSummary/Value_Gardenlost") as Label
	if beds == null:
		_T.free_ui(game)
		return ["the post-mortem card has no beds row", ""]
	var text: String = beds.text
	_T.free_ui(game)
	return ["", text]


## plant-tower-defense-2z8, staged end to end and both ways.
##
## The two runs the issue contrasts, made identical in everything the card could
## previously see: the same ten beds, lost through the same exit cell, in the
## same wave. Board._run_escapes files every one of them against exit_cell()
## because the pest is off the board by then — that is deliberate, it is what
## makes stops_at() a subtraction, and it means the spatial half of an escape is
## a CONSTANT. So the distinction cannot be carried by a cell, and had to be
## carried by something the pest itself knew.
##
## What it knew: whether anything ever reached it. Corn is the only damage in the
## game (a Sundew slows and does not hurt, a Sunflower never touches a pest) and
## it shoots whatever is furthest along the road, so a pest that reached the exit
## untouched was never in range of anything — a hole in the coverage — while one
## that was fought and got there anyway means the coverage was there and short.
## More plants versus a bigger plant: the two things a player can buy.
func test_a_leak_through_a_gap_and_a_leak_of_stragglers_no_longer_read_alike() -> String:
	var gap: Array = await _staged_escape_run(false)
	var err: String = _T.assert_eq(String(gap[0]), "", "the untouched run staged cleanly")
	if err != "":
		return err
	var stragglers: Array = await _staged_escape_run(true)
	err = _T.assert_eq(String(stragglers[0]), "", "the fought run staged cleanly")
	if err != "":
		return err

	var gap_text: String = String(gap[1])
	var straggler_text: String = String(stragglers[1])
	err = _T.assert_gt(gap_text.length(), 0, "the untouched run printed a beds row")
	if err == "":
		err = _T.assert_gt(straggler_text.length(), 0, "and so did the fought one")
	if err == "":
		err = _T.assert_true(gap_text != straggler_text,
			"two runs that lost the identical %d beds no longer read the same ('%s' vs '%s')"
				% [Game.LIVES, gap_text, straggler_text])
	if err == "":
		err = _T.assert_eq(gap_text, "%d of %d beds — %d walked in untouched"
			% [Game.LIVES, Game.LIVES, Game.LIVES],
			"the gap run counts the pests that walked the whole road unopposed")
	if err == "":
		err = _T.assert_eq(straggler_text, "%d of %d beds — all were fought"
			% [Game.LIVES, Game.LIVES],
			"and the straggler run says the garden reached every one of them and came up short")
	if err == "":
		# The bed count itself is untouched. This row is the escape count and has
		# been since the card shipped; the clause is evidence appended to it, not
		# a replacement for it.
		var stem: String = "%d of %d beds" % [Game.LIVES, Game.LIVES]
		err = _T.assert_true(gap_text.begins_with(stem) and straggler_text.begins_with(stem),
			"and neither run stopped reporting the beds it always reported")
	return err


## The reading itself, at the pest, with no run around it.
##
## Two ways the garden engages a bug, and they are the whole list. A kernel that
## lands is the obvious one. The other is a Chomp, which deals no damage at all
## and is wired to release() on `destroyed` — so a Chomp eaten out from under its
## meal hands back a live pest at full health that had very much been fought.
## Reading health alone would call that one a stroll through an empty lane.
func test_a_pest_knows_whether_the_garden_ever_reached_it() -> String:
	var clean: Pest = _pest(Pest.APHID, Vector2.ZERO)
	var err: String = _T.assert_true(clean != null, "there is a pest to ask")
	if err != "":
		return err
	err = _T.assert_false(clean.was_engaged(),
		"a pest fresh off the entry cell has been touched by nothing")
	if err == "":
		clean.take_damage(0.0)
		err = _T.assert_false(clean.was_engaged(),
			"and a zero-damage hit is not a hit — 'something reached it' has to mean something landed")
	if err == "":
		clean.take_damage(1.0)
		err = _T.assert_true(clean.was_engaged(), "while one kernel that lands is enough")
	if err == "":
		err = _T.assert_true(clean.is_alive(),
			"and it is still walking, which is the only case this reading is ever taken in")
	clean.free()

	if err == "":
		var held: Pest = _pest(Pest.BEETLE, Vector2.ZERO)
		err = _T.assert_true(held != null, "there is a beetle for the mouth")
		if err == "":
			err = _T.assert_false(held.was_engaged(), "ungrabbed, it has been touched by nothing")
		if err == "":
			var mouth := ChompFlower.new()
			held.held_by = mouth
			held._physics_process(0.016)
			held.held_by = null
			err = _T.assert_true(held.was_engaged(),
				"a pest a Chomp held was fought, though the Chomp never damaged it")
			if err == "":
				err = _T.assert_float_eq(held.health, held.max_health, 0.001,
					"and its health cannot say so — unharmed by that measure, engaged by this one")
			mouth.free()
		held.free()
	return err


## The branch that keeps the row honest, and the one the existing suite leans on:
## Game._on_pest_escaped is called with null by every test that stages a losing
## run without bugs on the board, and _note_escape counts such an escape in
## NEITHER tally. An unobserved pest is not evidence of a pest that was fought,
## so the row degrades to the bare bed count it has always printed rather than
## announcing "all were fought" about pests nothing ever looked at.
func test_the_beds_row_says_only_what_the_run_actually_watched() -> String:
	var err: String = _T.assert_gt(Game.LIVES, 4,
		"the fixtures below need a garden with beds to spare")
	if err != "":
		return err
	var seen: int = Game.LIVES - 4

	var unwatched := RunSummary.build({"lives_lost": Game.LIVES})
	err = _T.assert_true(unwatched != null, "a card for a run whose escapes carried no pest")
	if err != "":
		return err
	var bare: String = unwatched.beds_text()
	err = _T.assert_eq(bare, "%d of %d beds" % [Game.LIVES, Game.LIVES],
		"prints the bed count it always printed and nothing else")
	if err == "":
		err = _T.assert_false(bare.contains("fought"),
			"and never claims a fight it has no evidence for")
	unwatched.free()

	if err == "":
		var gap := RunSummary.build({
			"lives_lost": Game.LIVES,
			"escapes_recorded": Game.LIVES,
			"escapes_untouched": seen,
		})
		err = _T.assert_true(gap != null, "a card for a run leaking through a hole")
		if err == "":
			err = _T.assert_eq(gap.beds_text(), "%d of %d beds — %d walked in untouched"
				% [Game.LIVES, Game.LIVES, seen],
				"counts the ones nothing ever reached")
		gap.free()

	if err == "":
		var shortfall := RunSummary.build({
			"lives_lost": Game.LIVES,
			"escapes_recorded": Game.LIVES,
			"escapes_untouched": 0,
		})
		err = _T.assert_true(shortfall != null,
			"a card for a run that fought them all and still lost")
		if err == "":
			var text: String = shortfall.beds_text()
			err = _T.assert_eq(text, "%d of %d beds — all were fought"
				% [Game.LIVES, Game.LIVES],
				"says the coverage was there — the opposite purchase from the branch above")
			if err == "":
				# Not "0 walked in untouched". A zero on a results card reads as a
				# missing measurement, and this branch carries a reading a player
				# would act on.
				err = _T.assert_false(text.contains("0 walked"),
					"and does not phrase the strongest reading on the row as a zero")
		shortfall.free()
	return err


## Height was never available (an eighth row foots at 486 against buttons at
## 476), so this reading was folded into an existing row and is paid for in width
## instead. The beds row is now the card's widest value, which the held-ground
## row used to be — so it is the row the column has to be measured against, and
## this is that measurement.
##
## Measured through the resolved theme font. Every value Label on this card sets
## clip_text, and a clipping Label reports a 1px minimum width by design, so a
## gate built on get_minimum_size() would pass for any string of any length.
func test_the_worst_case_beds_row_still_fits_its_column() -> String:
	# The worst case built by the formatter rather than written out: every bed
	# lost, every escape read, and not one of them ever touched.
	var panel := RunSummary.build({
		"lives_lost": Game.LIVES,
		"escapes_recorded": Game.LIVES,
		"escapes_untouched": Game.LIVES,
		"wave": 8,
		"wave_count": 8,
		"threat_level": 5,
		"pests_defeated": 214,
		"run_seconds": 640.0,
		"compost_total": 127,
		"compost_resolved": 214,
		"stop_cell": Vector2i(13, 7),
		"stop_cell_stops": 137,
	})
	await _T.instantiate_scene(panel)
	var err: String = _T.assert_true(panel != null, "the card stood up")
	if err != "":
		return err
	var beds: Label = panel.get_node_or_null("Value_Gardenlost") as Label
	err = _T.assert_true(beds != null, "with a beds row on it")
	if err != "":
		_T.free_ui(panel)
		return err
	err = _T.assert_eq(beds.text, panel.beds_text(),
		"and the row on screen is the string the formatter builds, not a second copy of the format")
	if err != "":
		_T.free_ui(panel)
		return err

	var font: Font = beds.get_theme_font("font")
	var font_size: int = beds.get_theme_font_size("font_size")
	err = _T.assert_true(font != null, "the row has a font to measure with")
	if err != "":
		_T.free_ui(panel)
		return err
	var column: float = RunSummary.CARD.size.x * 0.58 - RunSummary.ROW_INSET
	var drawn: float = font.get_string_size(
		beds.text, HORIZONTAL_ALIGNMENT_RIGHT, -1, font_size).x
	err = _T.assert_gt(drawn, 1.0,
		"the font really measured '%s' — a 1px answer is the clip_text stub, not a width" % beds.text)
	if err == "":
		err = _T.assert_gt(column, 1.0, "and there is a real column to measure it against")
	if err == "":
		err = _T.assert_true(drawn <= column,
			"the worst-case beds row fits without ellipsis (%.0f of %.0f px)" % [drawn, column])

	var rows: Array = panel.summary_rows()
	var measured: int = 0
	if err == "":
		err = _T.assert_gt(rows.size(), 1, "there are sibling rows to compare it against")
	if err == "":
		for row: Array in rows:
			var value: Label = panel.get_node_or_null(
				"Value_%s" % String(row[0]).replace(" ", "")) as Label
			if value == null:
				err = "row '%s' has no value label" % String(row[0])
				break
			var wide: float = font.get_string_size(
				value.text, HORIZONTAL_ALIGNMENT_RIGHT, -1, font_size).x
			err = _T.assert_gt(wide, 1.0,
				"row '%s' really measured — a 1px answer is the clip_text stub" % String(row[0]))
			if err != "":
				break
			err = _T.assert_true(wide <= drawn,
				"the beds row is the card's widest value, so it is the one worth gating: '%s' is %.0fpx against its %.0fpx"
					% [value.text, wide, drawn])
			if err != "":
				break
			measured += 1
	if err == "":
		err = _T.assert_eq(measured, rows.size(),
			"every row was really measured — a short loop is what makes a width gate vacuous")
	_T.free_ui(panel)
	return err


# -- Where the garden cannot reach (issue jrj) -------------------------------
#
# The map is DERIVED — board plus placed plants — and the observed version was
# considered and rejected. The first two tests below are that rejection written
# down as numbers rather than as a paragraph, because the observed version is the
# one that looks obvious and somebody will propose it again.


## The list of plants that can touch a pest, and the one place it is allowed to
## disagree with PlantCatalog.reach().
##
## A Sticky Sundew has a reach and cannot engage anything — it "deals no damage
## whatsoever" by its own doc comment, and Pest._ever_engaged is set by exactly
## two things, neither of which is dew. So a coverage map built on reach() would
## call a stretch of road walled in Sundews "defended", which is the opposite of
## what a player would do with it. This is that divergence, pinned.
##
## The loop is the part that matters: it grades every id in the catalogue, so a
## fifth plant fails here rather than silently defaulting into one answer or the
## other.
func test_every_plant_that_can_touch_a_pest_is_named_as_one() -> String:
	var ids: Array[StringName] = PlantCatalog.ids()
	var err: String = _T.assert_gt(ids.size(), 0, "there is a catalogue to grade")
	if err == "":
		err = _T.assert_gt(Game.engaging_plants().size(), 0,
			"and something in it can fight — an empty list would make every map below all holes")
	if err != "":
		return err

	# Named positively, and named exactly. A new plant landing in the catalogue
	# has to be decided about here; it must not inherit an answer.
	if err == "":
		err = _T.assert_eq(Game.engaging_plants().size(), 3,
			"three plants in this catalogue can touch a pest, and the list says which")
	if err == "":
		err = _T.assert_true(Game.engaging_plants().has(PlantCatalog.CORN),
			"a kernel that lands is one of the things that set Pest._ever_engaged")
	if err == "":
		err = _T.assert_true(Game.engaging_plants().has(PlantCatalog.CHOMP),
			"and a Chomp holding a pest still is another")
	if err == "":
		err = _T.assert_true(Game.engaging_plants().has(PlantCatalog.DANDELION),
			"and a seed bomb bursting on one is the third — SeedBomb.detonate() calls take_damage")
	if err != "":
		return err

	# The divergence itself, on the one plant it exists for.
	err = _T.assert_gt(PlantCatalog.reach(PlantCatalog.SUNDEW), 0.0,
		"the Sundew has a reach the placement cue rightly warns about")
	if err == "":
		err = _T.assert_float_eq(Game.engagement_reach(PlantCatalog.SUNDEW), 0.0, 0.0001,
			"and none at all by the only measure a coverage map may use — dew never touches a pest")
	if err != "":
		return err

	var graded: int = 0
	for id: StringName in ids:
		var engages: float = Game.engagement_reach(id)
		if Game.engaging_plants().has(id):
			err = _T.assert_float_eq(engages, PlantCatalog.reach(id), 0.0001,
				"%s engages at the catalogue's own radius rather than at a second copy of it" % id)
		else:
			err = _T.assert_float_eq(engages, 0.0, 0.0001,
				"%s cannot touch a pest, so it covers no road however far it reaches" % id)
		if err != "":
			break
		graded += 1
	if err == "":
		err = _T.assert_eq(graded, ids.size(),
			"every plant in the catalogue was graded — a short loop is what makes this vacuous")
	if err == "":
		# The two numbers are the subclasses' own, not re-listed here.
		err = _T.assert_float_eq(Game.engagement_reach(PlantCatalog.CORN), CornCobbler.RANGE,
			0.0001, "the cob engages at its firing range")
	if err == "":
		err = _T.assert_float_eq(Game.engagement_reach(PlantCatalog.CHOMP),
			ChompFlower.GRAB_RADIUS, 0.0001, "and the flower at the reach of its mouth")
	return err


## Why there is no observed coverage map, as a contradiction rather than an
## opinion.
##
## Pest._ever_engaged is monotone: a kernel that lands sets it and nothing clears
## it. Sample that flag per road cell and it marks a PREFIX of the road — every
## cell after first contact reports "the garden reached here", including cells
## nothing in the garden can reach at all. The two holes that actually cost beds,
## a gap in the middle and an uncovered run to the exit, are exactly the two it
## cannot see, because both lie after first contact.
##
## Staged against the real road and a real reach so the blindness is a number: the
## flag calls every road cell reached while the cob beside the entry can touch
## four of them.
func test_the_engagement_flag_can_only_ever_mark_a_prefix_of_the_road() -> String:
	var probe := Board.new()
	var road: Array[Vector2i] = probe.road_cells()
	var route: PackedVector2Array = probe.route()
	var err: String = _T.assert_gt(road.size(), 2, "the probe board has a road to walk")
	if err == "":
		err = _T.assert_eq(route.size(), road.size() + 2,
			"whose route is one point per road cell plus the two off-board tails")
	if err != "":
		probe.free()
		return err

	# A Corn Cobbler on the grass beside the entry: real cell, real range.
	var post := Vector2i(1, 0)
	err = _T.assert_true(probe.is_buildable(post), "the cob's cell is plantable ground")
	var reached: Array[Vector2i] = PlacementPreview.covered_road_cell_list(
		probe, post, CornCobbler.RANGE)
	if err == "":
		err = _T.assert_gt(reached.size(), 0,
			"and it really reaches road — a zero here would make every count below vacuous")
	if err == "":
		err = _T.assert_true(reached.size() < road.size(),
			"but not all of it (%d of %d), or there is no hole to be blind to"
				% [reached.size(), road.size()])
	if err != "":
		probe.free()
		return err

	var pest := Pest.new()
	pest.setup(Pest.APHID, route)
	pest.set_physics_process(false)
	err = _T.assert_false(pest.was_engaged(), "a pest at the entry has been touched by nothing")
	if err == "":
		# One kernel, once, at the very start. Everything below is what the flag
		# goes on to claim about the rest of the walk on the strength of that hit.
		pest.take_damage(1.0)
		err = _T.assert_true(pest.was_engaged(), "one kernel that lands is enough to set it")
	if err == "":
		err = _T.assert_true(pest.is_alive(),
			"and the pest survived it, which is the only case this reading is taken in")
	if err != "":
		pest.free()
		probe.free()
		return err

	# Walk it cell by cell, stopping one waypoint short of the off-board exit so
	# _advance() never fires _escape() and frees the node mid-loop.
	var claimed: int = 0
	var visited: Dictionary = {}
	for i: int in range(road.size()):
		pest._advance(pest.position.distance_to(route[i + 1]))
		visited[probe.world_to_cell(pest.position)] = true
		if pest.was_engaged():
			claimed += 1
	err = _T.assert_eq(claimed, road.size(),
		"the flag claims the garden reached every one of the %d road cells" % road.size())
	if err == "":
		# The guard that stops the loop above being N samples of one cell.
		err = _T.assert_eq(visited.size(), road.size(),
			"and it really walked %d distinct cells to be asked on" % road.size())
	if err == "":
		err = _T.assert_true(pest.is_alive(),
			"and the walk stopped short of the exit rather than freeing the pest mid-count")
	if err == "":
		err = _T.assert_gt(claimed, reached.size(),
			("so an observed map over-reports by %d cells: it calls %d of the road reached "
				+ "where the garden can touch %d") % [
					claimed - reached.size(), claimed, reached.size(),
				])
	if err == "":
		# The exit is the cell that matters, and it is the cell the flag is most
		# confidently wrong about: nothing can touch it, and every pest that ever
		# took a hit walks over it reporting that something did.
		err = _T.assert_false(reached.has(probe.exit_cell()),
			"the cob cannot touch the exit cell, which is where the beds are lost")
	pest.free()
	probe.free()
	return err


## The derived map, through a real run: it answers while the game is being played,
## it moves when a plant goes in, and it refuses to count a plant that cannot
## fight.
func test_the_garden_can_say_which_road_it_cannot_reach() -> String:
	var game := await _T.instantiate_scene("res://game/game.tscn") as Game
	var err: String = _T.assert_true(game != null, "the game scene loaded")
	if err != "":
		return err
	err = _T.assert_true(game.board != null, "the run has a board")
	if err != "":
		_T.free_ui(game)
		return err
	var road: Array[Vector2i] = game.board.road_cells()
	err = _T.assert_gt(road.size(), 0, "with a road to have holes in")
	if err != "":
		_T.free_ui(game)
		return err

	# An empty garden: every cell is a hole, and the frontier says "nothing", which
	# is a different claim from "the entry cell".
	err = _T.assert_eq(game.uncovered_road_cells().size(), road.size(),
		"an empty garden reaches none of the %d road cells" % road.size())
	if err == "":
		err = _T.assert_float_eq(game.coverage_frontier(), -1.0, 0.0001,
			"and the frontier is 'nothing covered', not 'the entry cell covered'")
	if err == "":
		err = _T.assert_eq(game.coverage_note(), "",
			"but the line stays silent: an empty field is not a hole in the coverage")
	if err != "":
		_T.free_ui(game)
		return err

	var post := Vector2i(1, 0)
	err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, post), "",
		"the free starter cob goes in beside the entry")
	if err != "":
		_T.free_ui(game)
		return err
	var reached: Array[Vector2i] = PlacementPreview.covered_road_cell_list(
		game.board, post, CornCobbler.RANGE)
	err = _T.assert_gt(reached.size(), 0, "and it covers road")
	if err == "":
		err = _T.assert_true(reached.size() < road.size(), "though not all of it")
	if err != "":
		_T.free_ui(game)
		return err

	var holes: Array[Vector2i] = game.uncovered_road_cells()
	err = _T.assert_eq(holes.size(), road.size() - reached.size(),
		"the hole map is the road minus what the cob reaches (%d of %d)"
			% [road.size() - reached.size(), road.size()])
	if err == "":
		err = _T.assert_true(holes.has(game.board.exit_cell()),
			"and the exit cell is in it, which is the hole that costs beds")
	if err == "":
		err = _T.assert_false(holes.has(Board.PATH_CORNERS[0]),
			"while the entry cell is not — the cob is standing next to it")
	if err == "":
		err = _T.assert_float_eq(game.coverage_frontier(),
			float(game.board.path_index(reached[reached.size() - 1])) / float(road.size() - 1),
			0.0001, "and the frontier is the deepest cell the cob reaches")
	if err == "":
		err = _T.assert_gt(game.coverage_note().length(), 0,
			"so now there is a sentence to say")
	if err != "":
		_T.free_ui(game)
		return err

	# The claim engaging_plants() exists for, in the live map rather than in the
	# constant: a Sundew laid over road the cob cannot reach buys no coverage,
	# because dew never touches a pest. Built directly rather than bought — the
	# purchase path needs an unlock and thirty seeds, and neither is under test.
	var dew_cell := Vector2i(4, 0)
	err = _T.assert_true(game.board.is_buildable(dew_cell), "there is grass for a patch")
	if err != "":
		_T.free_ui(game)
		return err
	var dew_road: Array[Vector2i] = PlacementPreview.covered_road_cell_list(
		game.board, dew_cell, StickySundew.SAP_RADIUS)
	var fresh: int = 0
	for cell: Vector2i in dew_road:
		if not reached.has(cell):
			fresh += 1
	err = _T.assert_gt(fresh, 0,
		"the patch really lies over road the cob cannot reach (%d cells), or this proves nothing"
			% fresh)
	if err != "":
		_T.free_ui(game)
		return err

	var before: int = holes.size()
	var dew := StickySundew.new()
	game._entities.add_child(dew)
	dew.setup(PlantCatalog.SUNDEW, dew_cell, game.board)
	game._plants[dew_cell] = dew
	err = _T.assert_eq(game.uncovered_road_cells().size(), before,
		("a Sundew over %d cells of fresh road closes none of them — it slows, it never "
			+ "touches, and a map that counted it would call that lane defended") % fresh)
	if err == "":
		# And the same kind of ground under a plant that CAN fight does close.
		var chomp_cell := Vector2i(4, 2)
		err = _T.assert_true(game.board.is_buildable(chomp_cell), "there is grass for a mouth")
		if err == "":
			var chomp_road: Array[Vector2i] = PlacementPreview.covered_road_cell_list(
				game.board, chomp_cell, ChompFlower.GRAB_RADIUS)
			var chomp_fresh: int = 0
			for cell: Vector2i in chomp_road:
				if not reached.has(cell):
					chomp_fresh += 1
			err = _T.assert_gt(chomp_fresh, 0, "the mouth reaches road the cob does not")
			if err == "":
				var mouth := ChompFlower.new()
				game._entities.add_child(mouth)
				mouth.setup(PlantCatalog.CHOMP, chomp_cell, game.board)
				game._plants[chomp_cell] = mouth
				err = _T.assert_eq(game.uncovered_road_cells().size(), before - chomp_fresh,
					"which closes exactly the %d cells it can reach" % chomp_fresh)
	_T.free_ui(game)
	return err


## The formatter on its own. Three silences and two sentences, and the silences
## are the half worth pinning: each is a state a percentage would misdescribe.
func test_the_coverage_line_is_silent_when_there_is_nothing_to_say() -> String:
	var err: String = _T.assert_eq(Game.coverage_note_for(-1.0), "",
		"nothing planted is the absence of a garden, not a hole in one — the board says it louder")
	if err == "":
		err = _T.assert_eq(Game.coverage_note_for(1.0), "",
			"a garden reaching the exit cell has no tail to report")
	if err == "":
		err = _T.assert_eq(Game.coverage_note_for(0.999), "",
			"and a tail that rounds to 0% is a broken-looking readout, not good news")
	if err == "":
		err = _T.assert_eq(Game.coverage_note_for(0.0),
			"Nothing is aimed at the last 100% of the road.",
			"a garden covering only the entry cell leaves the whole road open")
	if err == "":
		err = _T.assert_eq(Game.coverage_note_for(0.5),
			"Nothing is aimed at the last 50% of the road.",
			"and half a road covered says so as a depth, the one spatial variable this road has")
	return err


## End to end: the same wave, the same board, and the sentence changes because the
## garden did.
##
## The precedence rule is a comparison and not a threshold — the coverage line
## takes the row exactly when the wave's pests were stopped, on average, further
## down the road than the garden can reach. That is the wave where the hole is the
## explanation for what just happened.
func test_the_prep_window_names_the_hole_when_the_wave_got_past_it() -> String:
	var game := await _T.instantiate_scene("res://game/game.tscn") as Game
	var err: String = _T.assert_true(game != null, "the game scene loaded")
	if err != "":
		return err
	err = _T.assert_true(game.board != null, "the run has a board")
	if err != "":
		_T.free_ui(game)
		return err
	var road: Array[Vector2i] = game.board.road_cells()
	var entry: Vector2i = Board.PATH_CORNERS[0]
	var way_out: Vector2i = game.board.exit_cell()
	err = _T.assert_gt(road.size(), 1, "there is a road with two ends")
	if err == "":
		err = _T.assert_true(game.board.is_path(entry) and game.board.is_path(way_out),
			"and both ends of it are road, or every depth below is dropped")
	if err != "":
		_T.free_ui(game)
		return err

	# A wave that walked the whole way out, with nothing planted.
	game.board.record_lane_pressure_wave({way_out: 5})
	err = _T.assert_float_eq(game.board.last_wave_depth(), 1.0, 0.0001,
		"the wave was lost at the exit, which is 100% down the road")
	if err == "":
		err = _T.assert_eq(game.prep_note(),
			"Pests got 100% down the road, the run's usual depth.",
			"an empty garden still gets the depth note — the coverage line never claims a field nobody planted")
	if err != "":
		_T.free_ui(game)
		return err

	# The same recorded wave, now with a cob in the ground near the entry.
	var post := Vector2i(1, 0)
	err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, post), "", "the cob goes in")
	if err != "":
		_T.free_ui(game)
		return err
	var frontier: float = game.coverage_frontier()
	err = _T.assert_true(frontier > 0.0 and frontier < 1.0,
		"the cob reaches some of the road and not the end of it (frontier %.3f)" % frontier)
	if err == "":
		var tail: int = int(round((1.0 - frontier) * 100.0))
		err = _T.assert_eq(game.prep_note(),
			"Nothing is aimed at the last %d%% of the road." % tail,
			"and now the same wave is explained by the hole it walked out through")
	if err == "":
		err = _T.assert_eq(game.prep_note(), game.coverage_note(),
			"which is the coverage line itself and not a second copy of the format")
	if err != "":
		_T.free_ui(game)
		return err

	# A wave stopped inside the covered stretch is not the hole's story, so the
	# depth comparison takes the row back.
	game.board.record_lane_pressure_wave({entry: 5})
	err = _T.assert_float_eq(game.board.last_wave_depth(), 0.0, 0.0001,
		"the second wave died on the entry cell")
	if err == "":
		err = _T.assert_true(game.board.last_wave_depth() <= frontier,
			"which is inside the ground the cob covers, so the hole is not what happened")
	if err == "":
		err = _T.assert_eq(game.prep_note(),
			"Pests got 0% down the road — shallower than the run's 50%.",
			"and the window goes back to comparing this wave against the run")
	if err == "":
		# The line the status row actually receives, which is what a clip would
		# eat: the assertion above is on a fragment nothing renders on its own.
		err = _T.assert_eq(Hud.wave_cleared_line(3, game.prep_note()),
			"Wave 3 cleared. Pests got 0% down the road — shallower than the run's 50%.",
			"through the same formatter the prep window hands the HUD")
	_T.free_ui(game)
	return err


## MessageLabel clips with an ellipsis, so a coverage line that outgrows the
## status row renders trimmed and nothing complains. Measured off the resolved
## theme font, NOT get_minimum_size(): the label sets clip_text and a clipping
## Label reports a 1px minimum by design.
##
## Two gates, not one. The line has to fit the row, and it has to stay NARROWER
## than Hud.PREP_NOTE_WORST_CASE — that constant is declared as the worst case the
## status row can be handed, and a new branch quietly overtaking it would leave
## the declaration guarding the wrong string.
func test_the_coverage_note_fits_the_status_row() -> String:
	# The widest reachable frontier is 0.0, and it is not hypothetical: a lone
	# Chomp on (0, 0) reaches the road cell 64px below it and misses the next at
	# 90.5px, which is one covered cell at path index 0.
	var probe := Board.new()
	var lone: Array[Vector2i] = PlacementPreview.covered_road_cell_list(
		probe, Vector2i(0, 0), ChompFlower.GRAB_RADIUS)
	var err: String = _T.assert_eq(lone.size(), 1,
		"a Chomp on (0, 0) covers exactly one road cell")
	if err == "":
		err = _T.assert_eq(probe.path_index(lone[0]), 0,
			"and it is the entry cell, so a frontier of 0.0 is a garden somebody can really build")
	probe.free()
	if err != "":
		return err

	var game := await _T.instantiate_ui("res://game/game.tscn", Vector2i(1152, 648)) as Game
	err = _T.assert_true(game != null, "the game scene loaded")
	if err != "":
		return err
	err = _T.assert_true(game.hud != null, "the run has a HUD")
	if err != "":
		_T.free_ui(game)
		return err
	var label: Label = game.hud.get_node_or_null("Root/TopBar/MessageLabel") as Label
	err = _T.assert_true(label != null, "the status row exists")
	if err == "":
		# Pinned to the formatter, not to the literal. A reworded line nobody
		# copies into the constant is exactly how a silent clip ships.
		err = _T.assert_eq(Game.COVERAGE_NOTE_WORST_CASE,
			Hud.wave_cleared_line(9999, Game.coverage_note_for(0.0)),
			"the declared worst case is the line the formatter actually builds")
	if err != "":
		_T.free_ui(game)
		return err

	var font: Font = label.get_theme_font("font")
	err = _T.assert_true(font != null, "the row has a font to measure with")
	if err != "":
		_T.free_ui(game)
		return err
	var size_px: int = label.get_theme_font_size("font_size")
	if size_px <= 0:
		size_px = label.get_theme_default_font_size()
	var drawn: float = font.get_string_size(
		Game.COVERAGE_NOTE_WORST_CASE, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	err = _T.assert_gt(drawn, 1.0,
		"the font really measured the line — a 1px answer is the clip_text stub, not a width")
	if err == "":
		err = _T.assert_gt(label.size.x, 1.0, "and the row has a real width to measure against")
	if err == "":
		err = _T.assert_true(drawn <= label.size.x,
			"the worst-case coverage line fits the status row without ellipsis (%.0f of %.0f px)"
				% [drawn, label.size.x])
	if err == "":
		var declared: float = font.get_string_size(
			Hud.PREP_NOTE_WORST_CASE, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		err = _T.assert_gt(declared, 1.0, "Hud's declared worst case measured too")
		if err == "":
			err = _T.assert_true(drawn <= declared,
				("and stays under Hud.PREP_NOTE_WORST_CASE (%.0f of %.0f px), which is still the "
					+ "widest thing the status row can be handed") % [drawn, declared])
	_T.free_ui(game)
	return err


# -- which red means fought, and which means nobody is looking (5lv) ---------
#
# Two maps of the same 32 road cells, and until now the board painted them with
# one brush. LanePressureOverlay says how far pests got; Game.coverage_frontier()
# says how far the garden can reach. They disagree constantly — driven live with
# four cobs at the entry, 3 of 6, then 3 of 7, then 4 of 11 pressured cells were
# cells nothing was aimed at — and they agree perfectly when the garden is good,
# which is the signal profile a mark wants: silent until there is a purchase to
# make. With a road covered end to end the off-aim set was empty for seven
# straight waves, and went to 32 of 32 on the wave that ate every cob.
#
# The channel is stripe ORIENTATION, and the cases below are written to pin the
# two things that make it worth having. It is not colour: the two cells assert
# equal alpha and the same GardenTheme.DANGER, and are still told apart. It is
# not density: the mirrored texture inks the same 57% and leaves the same 43%
# bare, which is the gap Game._update_cursor's flat wash has to be read through.


## The whole comparison, on a real run, in the one place it was missing: two road
## cells, the same recorded pressure, the same tint — and different stripes.
func test_the_road_marks_pressured_ground_the_garden_is_not_aimed_at() -> String:
	var game := await _T.instantiate_scene("res://game/game.tscn") as Game
	var err: String = _T.assert_true(game != null, "the game scene loaded")
	if err != "":
		return err
	err = _T.assert_true(game.board != null, "the run has a board")
	if err != "":
		_T.free_ui(game)
		return err

	var post := Vector2i(1, 0)
	err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, post), "",
		"the free starter cob goes in beside the entry")
	if err != "":
		_T.free_ui(game)
		return err
	var reached: Array[Vector2i] = PlacementPreview.covered_road_cell_list(
		game.board, post, CornCobbler.RANGE)
	err = _T.assert_gt(reached.size(), 0,
		"and it reaches road — with nothing aimed anywhere there are no two states to tell apart")
	if err != "":
		_T.free_ui(game)
		return err
	var near: Vector2i = reached[0]
	var far: Vector2i = game.board.exit_cell()
	err = _T.assert_true(game.board.is_path(near) and game.board.is_path(far),
		"both cells are road, so both can carry pressure")
	if err == "":
		err = _T.assert_false(reached.has(far),
			"and the cob cannot reach the exit cell %s, which is the whole point of the pair" % far)
	if err != "":
		_T.free_ui(game)
		return err

	# Placing the plant is what told the board. No extra call here on purpose:
	# if Game._refresh() ever stops pushing coverage, this is where it shows.
	err = _T.assert_false(game.board.is_unaimed(near),
		"the cob's own ground %s is marked as ground something points at" % near)
	if err == "":
		err = _T.assert_true(game.board.is_unaimed(far),
			"and the exit cell %s is marked as ground nothing does" % far)
	if err != "":
		_T.free_ui(game)
		return err

	# Board.is_unaimed() reads the Board's own copy, which it keeps so a Board that
	# never entered the tree can still answer. The node that actually paints is a
	# separate object, and a mark that reached one and not the other would pass
	# every assertion above while drawing nothing at all.
	var overlay: LanePressureOverlay = null
	for child: Node in game.board.get_children():
		var found := child as LanePressureOverlay
		if found != null:
			overlay = found
	err = _T.assert_true(overlay != null, "the board built its pressure overlay")
	if err == "":
		err = _T.assert_true(overlay.unaimed.has(far),
			"and the node holding the brush knows %s is off aim" % far)
	if err == "":
		err = _T.assert_false(overlay.unaimed.has(near),
			"and knows %s is not — the Board's copy and the painter's agree" % near)
	if err != "":
		_T.free_ui(game)
		return err

	# Equal counts, so both cells normalise to the same alpha — identical colour,
	# identical opacity, and a greyscale screenshot still separates them.
	game.board.record_lane_pressure_wave({near: 2, far: 2})
	var near_alpha: float = game.board.lane_pressure_alpha(near)
	var far_alpha: float = game.board.lane_pressure_alpha(far)
	err = _T.assert_gt(near_alpha, 0.0, "the near cell is painted at all")
	if err == "":
		err = _T.assert_float_eq(far_alpha, near_alpha, 0.0001,
			("and the far cell is painted at exactly the same strength (%.3f), so nothing below "
				+ "this line can be passing on a difference in red") % near_alpha)
	if err != "":
		_T.free_ui(game)
		return err

	var checked: int = 0
	for pair: Array in [[near, 1.0], [far, -1.0]]:
		var cell: Vector2i = pair[0]
		var want: float = float(pair[1])
		var segments: PackedVector2Array = LanePressureOverlay.hatch_segments(
			cell, game.board.is_unaimed(cell))
		err = _T.assert_gt(segments.size(), 0, "cell %s hatches at all" % cell)
		if err != "":
			break
		var i: int = 0
		while i + 1 < segments.size():
			var span: Vector2 = segments[i + 1] - segments[i]
			checked += 1
			err = _T.assert_gt(span.x * span.y * want, 0.0,
				("stripe %s -> %s in cell %s leans the way that cell's coverage says it should "
					+ "(aimed stripes fall one way, off-aim stripes the other)")
					% [segments[i], segments[i + 1], cell])
			i += 2
			if err != "":
				break
		if err != "":
			break
	if err == "":
		err = _T.assert_gt(checked, 8,
			"both cells contributed several stripes each — one stripe is a line, not a texture")
	_T.free_ui(game)
	return err


## The texture pair on its own, sampled. Same ink, same gaps, different mask —
## which is the claim that stops somebody "improving" the off-aim state into a
## denser hatch and quietly spending the 43% the cursor is read through.
func test_the_off_aim_hatch_spends_no_more_ink_than_the_aimed_one() -> String:
	var cell := Vector2i(4, 1)
	var origin: Vector2 = Vector2(cell) * float(Board.CELL)
	var aimed_ink: int = 0
	var off_ink: int = 0
	var differ: int = 0
	var samples: int = 0
	for sy: int in range(1, Board.CELL, 3):
		for sx: int in range(1, Board.CELL, 3):
			samples += 1
			var point: Vector2 = origin + Vector2(float(sx), float(sy))
			var aimed: bool = LanePressureOverlay.is_hatched(point, false)
			var off: bool = LanePressureOverlay.is_hatched(point, true)
			if aimed:
				aimed_ink += 1
			if off:
				off_ink += 1
			if aimed != off:
				differ += 1
	var err: String = _T.assert_gt(samples, 100,
		"the sweep visited the cell (an empty sweep passes vacuously)")
	if err == "":
		err = _T.assert_gt(aimed_ink, 0, "the aimed texture inks something")
	if err == "":
		err = _T.assert_gt(off_ink, 0, "and so does the off-aim one")
	if err == "":
		err = _T.assert_true(absi(aimed_ink - off_ink) * 20 <= samples,
			("the two textures spend the same ink (%d vs %d of %d samples). A denser off-aim "
				+ "hatch would read as a second, deeper red rather than as a second channel")
				% [aimed_ink, off_ink, samples])
	if err == "":
		err = _T.assert_gt(float(samples - off_ink) / float(samples), 0.2,
			("and the off-aim texture leaves a real share of the cell bare (%d of %d): that gap "
				+ "is what the cursor's flat DANGER wash is read through")
				% [samples - off_ink, samples])
	if err == "":
		err = _T.assert_gt(float(differ) / float(samples), 0.25,
			("while disagreeing over %d of %d sample points — the difference is WHERE the ink "
				+ "sits, which is the one thing left that neither hue nor alpha is carrying")
				% [differ, samples])
	return err


## The mark teaches itself, and this is the mechanism: buy a plant that covers a
## leaking stretch and the stripes under it rotate on the spot, in the prep
## window, with the pressure map still on screen. No legend, no tutorial line.
func test_planting_a_cob_rotates_the_stripes_under_the_ground_it_now_covers() -> String:
	var game := await _T.instantiate_scene("res://game/game.tscn") as Game
	var err: String = _T.assert_true(game != null, "the game scene loaded")
	if err != "":
		return err
	err = _T.assert_true(game.board != null, "the run has a board")
	if err != "":
		_T.free_ui(game)
		return err
	var road: Array[Vector2i] = game.board.road_cells()
	err = _T.assert_gt(road.size(), 0, "there is a road to mark")
	if err != "":
		_T.free_ui(game)
		return err

	# Game._ready() refreshes once, and an empty garden aims at nothing.
	var unaimed_before: int = 0
	for cell: Vector2i in road:
		if game.board.is_unaimed(cell):
			unaimed_before += 1
	err = _T.assert_eq(unaimed_before, road.size(),
		"an empty garden leaves all %d road cells off aim before a single plant goes in"
			% road.size())
	if err != "":
		_T.free_ui(game)
		return err

	var post := Vector2i(1, 0)
	var reached: Array[Vector2i] = PlacementPreview.covered_road_cell_list(
		game.board, post, CornCobbler.RANGE)
	err = _T.assert_gt(reached.size(), 0, "a cob at %s would reach road" % post)
	if err == "":
		err = _T.assert_true(reached.size() < road.size(), "though not the whole of it")
	if err == "":
		err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, post), "", "and the cob goes in")
	if err != "":
		_T.free_ui(game)
		return err

	var flipped: int = 0
	for cell: Vector2i in reached:
		if not game.board.is_unaimed(cell):
			flipped += 1
	err = _T.assert_eq(flipped, reached.size(),
		("every one of the %d cells the cob reaches stopped being off aim the moment it landed "
			+ "— that flip IS the legend") % reached.size())
	if err == "":
		var still: int = 0
		for cell: Vector2i in road:
			if game.board.is_unaimed(cell):
				still += 1
		err = _T.assert_eq(still, road.size() - reached.size(),
			"and nothing else moved: %d cells are still off aim" % (road.size() - reached.size()))
	if err != "":
		_T.free_ui(game)
		return err

	# The repaint economy. This runs on every seed payout; a redraw per call would
	# repaint the whole road several times a second to show the same picture.
	err = _T.assert_false(game.board.mark_unaimed_road(game.uncovered_road_cells()),
		"a refresh that changed no plants reports no change, so it repaints nothing")
	if err == "":
		err = _T.assert_true(game.board.mark_unaimed_road(road),
			"while a set that really moved is reported as moved")
	if err == "":
		err = _T.assert_true(game.board.is_unaimed(reached[0]),
			"and took effect: %s is off aim again" % reached[0])
	if err != "":
		_T.free_ui(game)
		return err

	# Ground that is not road is dropped, the same filter the pressure map applies:
	# the overlay only ever draws road, so a mark elsewhere can never be cleared.
	var grass: Array[Vector2i] = [post]
	err = _T.assert_false(game.board.is_path(post), "%s is grass, not road" % post)
	if err == "":
		err = _T.assert_true(game.board.mark_unaimed_road(grass),
			"handing the board a set of one grass cell is a change from the whole road")
	if err == "":
		err = _T.assert_false(game.board.is_unaimed(post),
			"but the grass cell itself is dropped rather than marked")
	_T.free_ui(game)
	return err


## The caveat, executable. game.gd's coverage block used to call the derived map
## an upper bound on what happened. It is not a bound in either direction: a
## Kernel flies until it leaves the board and kills the first pest it touches,
## whoever it was aimed at, so a cob kills on ground its own ring never covered.
##
## Found by driving a real run, not by reading: four cobs at the entry over four
## waves put 7 kills on cells the coverage map calls off aim — (6, 1) at 202 px
## and (3, 5) at 192 px from the nearest cob, against a 176 px ring. This is that
## case reduced to one cob, one kernel and one aphid, on a straight stretch of
## road the cob can fire along.
##
## The pair moved when the road grew its climb (plant-tower-defense-84x0): (2, 7)
## is a corner of the new route and no longer grass at all. (0, 7) fires east
## along row 7, which the new road runs from x=2 to x=9 — same shape of claim,
## and the assertions below re-derive every number from the cells themselves
## rather than restating one.
func test_a_kernel_can_kill_on_ground_the_coverage_map_calls_unaimed() -> String:
	var probe := Board.new()
	var post := Vector2i(0, 7)
	var beyond := Vector2i(4, 7)
	var err: String = _T.assert_true(probe.is_buildable(post),
		"%s is grass a cob can stand on" % post)
	if err == "":
		err = _T.assert_true(probe.is_path(beyond), "%s is road a pest can stand on" % beyond)
	if err != "":
		probe.free()
		return err
	var from: Vector2 = probe.cell_to_world(post)
	var to: Vector2 = probe.cell_to_world(beyond)
	err = _T.assert_float_eq(from.y, to.y, 0.001,
		"the cob sits level with the stretch of road it is firing down, so the shot is one line")
	if err == "":
		err = _T.assert_gt(from.distance_to(to), CornCobbler.RANGE,
			("and %s is %.0f px away, outside the cob's %.0f px ring")
				% [beyond, from.distance_to(to), CornCobbler.RANGE])
	if err == "":
		var reached: Array[Vector2i] = PlacementPreview.covered_road_cell_list(
			probe, post, CornCobbler.RANGE)
		err = _T.assert_gt(reached.size(), 0, "the cob covers some road, so the map is readable")
		if err == "":
			err = _T.assert_false(reached.has(beyond),
				"and the coverage map agrees it does not cover %s" % beyond)
	var bounds := Rect2(Vector2.ZERO, probe.board_size())
	probe.free()
	if err != "":
		return err

	var pest: Pest = _pest(Pest.APHID, to)
	var host: Node2D = _host([pest])
	await _T.instantiate_scene(host)
	# The kernel joins AFTER the settle frames, and its physics is switched off on
	# the same statement it enters on. Two things go wrong when it is hosted up
	# front instead, and both were seen here rather than reasoned about:
	#
	#   - an unconfigured Kernel carries a default Rect2() for bounds, so it is
	#     outside its own bounds on frame one and frees itself. The
	#     `Nonexistent function 'setup' in base 'previously freed'` that follows
	#     aborts the method and returns "", which the runner printed as [PASS].
	#   - set_physics_process(false) called before the tree does NOT stick: Godot
	#     turns it back on at entry, and the kernel flew 56 px on the settle
	#     frames — measured, as `Expected 160.0 but got 216.0`.
	#
	# Nothing below awaits, so no physics frame runs that this test did not drive.
	var kernel := Kernel.new()
	kernel.setup(from, Vector2.RIGHT, 1.0, bounds)
	host.add_child(kernel)
	kernel.set_physics_process(false)
	err = _T.assert_true(is_instance_valid(kernel),
		"the kernel survived being added to the tree — a freed one aborts this test into a pass")
	if err == "":
		err = _T.assert_float_eq(kernel.position.x, from.x, 0.001,
			"and has not flown anywhere on its own, so every pixel below is one this test drove")
	if err != "":
		_T.free_ui(host)
		return err
	var before: float = pest.health
	err = _T.assert_gt(before, 0.0, "the aphid starts with health to lose")
	if err == "":
		var steps: int = 0
		# 240 frames at 420 px/s is 1680 px, twice the width of the board.
		while steps < 240 and pest.health >= before:
			kernel._physics_process(1.0 / 60.0)
			steps += 1
		err = _T.assert_gt(steps, 0, "the kernel was actually stepped")
		if err == "":
			err = _T.assert_true(pest.health < before,
				("the kernel killed into %s after %d frames, which the coverage map calls ground "
					+ "nothing is aimed at (%.1f health left of %.1f). 'Off aim' means no plant has "
					+ "this cell in reach — it never meant nothing can die here")
					% [beyond, steps, pest.health, before])
	_T.free_ui(host)
	return err


# -- how far the coverage map over-promises ----------------------------------


## One driven wave over the real Board, the real plants, the real Kernel and the
## real WaveDirector schedule, sampled every physics frame.
##
## Nothing here awaits after the host is up, so the engine runs no physics frame
## this loop did not drive: every node is stepped by hand, in tree order, at a
## fixed dt. `queue_free()` therefore never lands, which is why kernels are
## dropped on `is_queued_for_deletion()` and pests on `is_alive()` rather than on
## `is_instance_valid()`.
func _over_promise_run(wave: int, corn_cells: Array, chomp_cells: Array,
		corn_level: int, roll_seed: int, max_frames: int) -> Dictionary:
	var dt: float = 1.0 / 60.0
	var board := Board.new()
	var route: PackedVector2Array = board.route()

	var host := Node2D.new()
	host.name = "OverPromiseHost"
	await _T.instantiate_scene(host)
	# The ONE await in this function, and the one place another test can get in:
	# the runner keeps stepping while a test yields, so a sibling test's pests can
	# be standing in the tree by the time this returns — and `pests` is a
	# tree-global group that Plant._live_pests() and Kernel._physics_process both
	# read. A cob shooting somebody else's aphid would answer stays this run never
	# staged. Counted rather than assumed clean; the tests assert it is zero.
	# settle-read-check: ok - counted here, asserted zero by every caller. The
	# guard is one frame up the stack and a function-scoped rule cannot see it.
	var foreign: int = host.get_tree().get_nodes_in_group("pests").size()

	var plants: Array[Plant] = []
	var covers: Array[Dictionary] = []
	var is_corn: Array[bool] = []
	for cell: Vector2i in corn_cells:
		var cob := CornCobbler.new()
		host.add_child(cob)
		cob.set_physics_process(false)
		cob.setup(PlantCatalog.CORN, cell, board)
		cob.level = corn_level
		plants.append(cob)
		is_corn.append(true)
	for cell: Vector2i in chomp_cells:
		var jaw := ChompFlower.new()
		host.add_child(jaw)
		jaw.set_physics_process(false)
		jaw.setup(PlantCatalog.CHOMP, cell, board)
		plants.append(jaw)
		is_corn.append(false)
	for i: int in range(plants.size()):
		var reach: float = Game.engagement_reach(plants[i].kind)
		var one: Dictionary = {}
		for road: Vector2i in PlacementPreview.covered_road_cell_list(board, plants[i].cell, reach):
			one[road] = true
		covers.append(one)

	# The derived map, exactly as Game.covered_road_cells() builds it.
	var covered: Dictionary = {}
	var corn_covered: Dictionary = {}
	# A Dictionary, not an int: a GDScript lambda captures a local by VALUE, so a
	# counter reassigned inside `remap` would never be seen out here — and the two
	# maps below are only kept in step because .clear() mutates the shared object
	# rather than rebinding the name.
	var standing: Dictionary = {"alive": -1}
	var remap := func() -> void:
		# Exactly Game.covered_road_cells(): a destroyed plant takes its coverage off
		# the board with it, which matters here because a hungry pest eats cobs.
		var alive: int = 0
		for plant: Plant in plants:
			if not plant.is_destroyed():
				alive += 1
		if alive == int(standing["alive"]):
			return
		standing["alive"] = alive
		covered.clear()
		corn_covered.clear()
		for i: int in range(plants.size()):
			if plants[i].is_destroyed():
				continue
			for road: Vector2i in covers[i]:
				covered[road] = true
				if is_corn[i]:
					corn_covered[road] = true
	remap.call()
	var covered_at_start: int = covered.size()

	var director := WaveDirector.new()
	director.set_seed(roll_seed)
	director.endless = wave > WaveDirector.WAVES.size()
	director.current_wave = wave - 1
	var pending: Array[Dictionary] = []
	director.spawn_requested.connect(func(species: StringName, mutation: StringName) -> void:
		pending.append({"species": species, "mutation": mutation}))
	director.start_next_wave()

	var pests: Array[Pest] = []
	var kernels: Array[Kernel] = []
	var episodes: Dictionary = {}
	var walked_covered: Dictionary = {}
	var walked_bare: Dictionary = {}
	var touched_ever: Dictionary = {}
	var escaped_ids: Dictionary = {}

	var tally: Dictionary = {
		"covered_cells": covered_at_start, "road_cells": board.road_cells().size(),
		"foreign_pests": foreign,
		"spawned": 0, "winged": 0, "killed": 0, "escaped": 0, "escaped_engaged": 0,
		"frames": 0, "plants_eaten": 0,
		"stays": 0, "unanswered": 0,
		"answered": 0, "answered_in_reach": 0, "answered_aimed": 0,
		"blind_winged": 0, "out_of_reach": 0, "busy": 0, "slow": 0,
		"pests_on_covered": 0, "pests_untouched": 0, "pests_untouched_escaped": 0,
		"pests_all_covered": 0, "pests_all_covered_untouched": 0,
		"uncovered_stays": 0, "uncovered_touched": 0,
	}

	var close_episode := func(ep: Dictionary, pest: Pest) -> void:
		if not bool(ep["covered"]):
			tally["uncovered_stays"] = int(tally["uncovered_stays"]) + 1
			if bool(ep["touched"]):
				tally["uncovered_touched"] = int(tally["uncovered_touched"]) + 1
			return
		tally["stays"] = int(tally["stays"]) + 1
		if bool(ep["touched"]):
			tally["answered"] = int(tally["answered"]) + 1
			if bool(ep["in_reach"]):
				tally["answered_in_reach"] = int(tally["answered_in_reach"]) + 1
			if bool(ep["aimed"]):
				tally["answered_aimed"] = int(tally["answered_aimed"]) + 1
			return
		tally["unanswered"] = int(tally["unanswered"]) + 1
		if pest.is_winged and not bool(ep["corn_here"]):
			tally["blind_winged"] = int(tally["blind_winged"]) + 1
		elif not bool(ep["in_reach"]):
			tally["out_of_reach"] = int(tally["out_of_reach"]) + 1
		elif not bool(ep["aimed"]):
			tally["busy"] = int(tally["busy"]) + 1
		else:
			tally["slow"] = int(tally["slow"]) + 1

	var frame: int = 0
	while frame < max_frames:
		frame += 1
		# 1. the schedule
		director._process(dt)
		for entry: Dictionary in pending:
			var pest := Pest.new()
			host.add_child(pest)
			pest.set_physics_process(false)
			pest.setup(StringName(entry["species"]), route)
			pest.apply_wave_scaling(
				WaveDirector.health_scale_for(wave), WaveDirector.speed_scale_for(wave))
			if StringName(entry["mutation"]) != &"":
				pest.apply_mutation(StringName(entry["mutation"]))
			pests.append(pest)
			tally["spawned"] = int(tally["spawned"]) + 1
			if pest.is_winged:
				tally["winged"] = int(tally["winged"]) + 1
		pending.clear()

		var live: Array[Pest] = []
		var health_before: Dictionary = {}
		for pest: Pest in pests:
			if pest.is_alive():
				live.append(pest)
				health_before[pest.get_instance_id()] = pest.health

		# 2. plants, then any kernel they just launched â€” held back a frame, the
		#    way a node added mid-physics is in a real tree.
		var known: int = kernels.size()
		for plant: Plant in plants:
			if plant.is_destroyed():
				continue
			plant._physics_process(dt)
		remap.call()
		for node: Node in host.get_children():
			var fresh := node as Kernel
			if fresh != null and not kernels.has(fresh):
				fresh.set_physics_process(false)
				kernels.append(fresh)
		# 3. the kernels that were already flying
		var still: Array[Kernel] = []
		for i: int in range(known):
			var shot: Kernel = kernels[i]
			if not is_instance_valid(shot) or shot.is_queued_for_deletion():
				continue
			shot._physics_process(dt)
			if not shot.is_queued_for_deletion():
				still.append(shot)
		for i: int in range(known, kernels.size()):
			still.append(kernels[i])
		kernels = still
		# 4. the pests
		for pest: Pest in live:
			if pest.is_alive():
				pest._physics_process(dt)

		# 5. the reading
		for pest: Pest in live:
			var id: int = pest.get_instance_id()
			var touched: bool = pest.health < float(health_before[id]) or pest.held_by != null
			if touched:
				touched_ever[id] = true
			if not pest.is_alive():
				if episodes.has(id):
					close_episode.call(episodes[id], pest)
					episodes.erase(id)
				if pest.is_queued_for_deletion():
					tally["escaped"] = int(tally["escaped"]) + 1
					escaped_ids[id] = true
					if pest.was_engaged():
						tally["escaped_engaged"] = int(tally["escaped_engaged"]) + 1
				else:
					tally["killed"] = int(tally["killed"]) + 1
				continue
			var cell: Vector2i = board.world_to_cell(pest.global_position)
			if episodes.has(id) and Vector2i(episodes[id]["cell"]) != cell:
				close_episode.call(episodes[id], pest)
				episodes.erase(id)
			if not episodes.has(id):
				episodes[id] = {
					"cell": cell, "covered": covered.has(cell), "corn_here": corn_covered.has(cell),
					"touched": false, "aimed": false, "in_reach": false,
				}
			var ep: Dictionary = episodes[id]
			ep["touched"] = bool(ep["touched"]) or touched
			if not bool(ep["covered"]):
				# Road only. The route is bracketed by an off-board entry and exit
				# tail, and a cell nothing could ever be planted beside is not the
				# map promising anything.
				if board.is_path(cell):
					walked_bare[id] = true
				continue
			walked_covered[id] = true
			for i: int in range(plants.size()):
				if not covers[i].has(cell) or plants[i].is_destroyed():
					continue
				var gap: float = pest.global_position.distance_to(plants[i].global_position)
				if is_corn[i]:
					if gap > CornCobbler.RANGE:
						continue
					ep["in_reach"] = true
					if pest == _furthest_along_within(live, plants[i], CornCobbler.RANGE):
						ep["aimed"] = true
				else:
					if gap > ChompFlower.GRAB_RADIUS:
						continue
					ep["in_reach"] = true
					var jaw := plants[i] as ChompFlower
					if not pest.is_winged and not jaw.is_busy():
						ep["aimed"] = true
		tally["frames"] = frame
		if int(tally["spawned"]) >= director.current_wave_pest_count() and live.is_empty():
			break

	for id: Variant in episodes:
		var leftover: Pest = instance_from_id(int(id)) as Pest
		if leftover != null:
			close_episode.call(episodes[id], leftover)

	for id: Variant in walked_covered:
		tally["pests_on_covered"] = int(tally["pests_on_covered"]) + 1
		var whole_walk: bool = not walked_bare.has(id)
		if whole_walk:
			tally["pests_all_covered"] = int(tally["pests_all_covered"]) + 1
		if touched_ever.has(id):
			continue
		tally["pests_untouched"] = int(tally["pests_untouched"]) + 1
		if whole_walk:
			tally["pests_all_covered_untouched"] = int(tally["pests_all_covered_untouched"]) + 1
		if escaped_ids.has(id):
			tally["pests_untouched_escaped"] = int(tally["pests_untouched_escaped"]) + 1

	for plant: Plant in plants:
		if plant.is_destroyed():
			tally["plants_eaten"] = int(tally["plants_eaten"]) + 1
	_T.free_ui(host)
	board.free()
	director.free()
	return tally


## Whichever live pest inside `radius` of `plant` is furthest along â€” the exact
## rule Plant._furthest_along_in_range picks a Corn's target by, re-derived here
## so the reading does not depend on reaching into the plant's private state.
func _furthest_along_within(live: Array[Pest], plant: Plant, radius: float) -> Pest:
	var best: Pest = null
	var best_progress: float = -1.0
	for pest: Pest in live:
		if pest.global_position.distance_to(plant.global_position) > radius:
			continue
		var p: float = pest.progress()
		if p > best_progress:
			best_progress = p
			best = pest
	return best


## DERIVED FROM THE ROAD, not typed against one (plant-tower-defense-m9u2).
##
## Reshaping the road in cycle 53 cost three hand-typed coordinate lists, and one
## of them failed in the way that is worst: `Vector2i(10, 3)` had become ROAD, so
## that placement would have been refused and quietly turned a six-plant garden
## into a five-plant one, with every downstream ratio still reporting a number.
##
## These are the derivations that were run by hand that day, promoted into the
## suite. `derive-the-list` calls this the "derive at check time" case exactly:
## the rule is total, cheap, and needs no human judgement — "the cells that cover
## the road" is a fact about the board, not a taste call. The next road costs
## nothing here.
##
## Deterministic on purpose: ties break on the lowest (y, x), so one board always
## yields one garden and a seeded run stays reproducible.
static func _cover_greedily(probe: Board, reach: float, target: int) -> Array:
	var road: Array[Vector2i] = probe.road_cells()
	var want: int = road.size() if target < 0 else target
	var uncovered: Dictionary = {}
	for cell: Vector2i in road:
		uncovered[cell] = true
	var reaches: Dictionary = {}
	for x: int in range(Board.COLS):
		for y: int in range(Board.ROWS):
			var at := Vector2i(x, y)
			if not probe.is_buildable(at):
				continue
			var hit: Array[Vector2i] = PlacementPreview.covered_road_cell_list(probe, at, reach)
			if not hit.is_empty():
				reaches[at] = hit
	var garden: Array = []
	while road.size() - uncovered.size() < want and not reaches.is_empty():
		var best: Vector2i = Vector2i(-1, -1)
		var best_gain: int = 0
		for at: Vector2i in reaches:
			var gain: int = 0
			for cell: Vector2i in reaches[at]:
				if uncovered.has(cell):
					gain += 1
			# Strictly-greater keeps the FIRST cell at a given gain, and `reaches`
			# is filled in (x, y) order, so the tie-break is stable without a sort.
			if gain > best_gain:
				best_gain = gain
				best = at
		if best_gain == 0:
			break
		garden.append(best)
		for cell: Vector2i in reaches[best]:
			uncovered.erase(cell)
		reaches.erase(best)
	return garden


## The cell that reaches the most road currently covered by exactly one plant.
## Coverage is not engagement — a cob shoots only the furthest-along pest in
## range, so a cell covered once is covered by a plant that may already be busy.
## The six-cob cover let one escape in thirty-four cross unfought; this is the
## seventh cob, derived rather than picked.
static func _reinforce_thinnest(probe: Board, garden: Array, reach: float) -> Vector2i:
	var depth: Dictionary = {}
	for cell: Vector2i in probe.road_cells():
		depth[cell] = 0
	for at: Vector2i in garden:
		for cell: Vector2i in PlacementPreview.covered_road_cell_list(probe, at, reach):
			depth[cell] = int(depth[cell]) + 1
	var thin: Array[Vector2i] = []
	for cell: Vector2i in depth:
		if int(depth[cell]) == 1:
			thin.append(cell)
	var best: Vector2i = Vector2i(-1, -1)
	var best_gain: int = 0
	for x: int in range(Board.COLS):
		for y: int in range(Board.ROWS):
			var at := Vector2i(x, y)
			if not probe.is_buildable(at) or garden.has(at):
				continue
			var gain: int = 0
			for cell: Vector2i in PlacementPreview.covered_road_cell_list(probe, at, reach):
				if thin.has(cell):
					gain += 1
			if gain > best_gain:
				best_gain = gain
				best = at
	return best


## RECORDED, not derived — and the reason is the interesting half.
##
## The first attempt at plant-tower-defense-m9u2 derived this by greedy set cover
## and got a BETTER cover: five cobs reach all 32 road cells where the recorded
## seven do. It also broke two tests, because what these gardens are for is not
## coverage — it is a calibrated amount of FIREPOWER. A cob shoots only the
## furthest-along pest in range, so a minimal cover is a weaker garden than a
## redundant one covering the same cells, and every ratio downstream moves.
##
## `derive-the-list` names this exactly: "if the membership is a taste call, it is
## not derivable and this recipe does not apply. Stop here rather than inventing a
## rule that fits today's list." Seven cobs is a taste call. So these stay written
## down, and `test_the_recorded_gardens_still_have_the_property_they_claim` is what
## keeps them honest — the recorded list is a CACHE, and that test is what makes it
## a cache rather than a second source of truth about the road.
##
## The walled list below IS derived, because "one mouth beside every road cell" is
## a rule with no judgement in it.
func _whole_road_garden() -> Array:
	return [Vector2i(0, 0), Vector2i(4, 2), Vector2i(11, 2),
		Vector2i(5, 5), Vector2i(8, 5), Vector2i(3, 6), Vector2i(8, 6)]


## A garden a player actually has by the last campaign wave: six plants covering
## most of the road but not all of it — deliberately short, which is what makes it
## a real garden rather than the positive control above. Recorded for the same
## reason as the garden above; see that comment.
func _mixed_garden() -> Array:
	return [Vector2i(12, 1), Vector2i(3, 2), Vector2i(8, 3),
		Vector2i(5, 6), Vector2i(0, 7), Vector2i(9, 8)]


## What the two recorded gardens above CLAIM, checked against the road as it is.
##
## Cycle 53 reshaped the road and both lists went stale silently — one of them had
## a cell that had become road, so its placement would have been refused and the
## garden would have been one plant smaller with every ratio still reporting a
## number. This is the assertion that turns that into a failure with a name.
##
## It deliberately does NOT assert the lists themselves. It asserts the properties
## the tests below rely on: every plant can actually stand where it is put, the
## whole-road garden reaches all of the road, and the mixed garden reaches most but
## not all of it.
func test_the_recorded_gardens_still_have_the_property_they_claim() -> String:
	var probe := Board.new()
	var road: int = probe.road_cells().size()
	var err: String = _T.assert_gt(road, 2, "the probe board built a road to measure against")
	for pair: Array in [["whole-road", _whole_road_garden()], ["mixed", _mixed_garden()]]:
		if err != "":
			break
		for at: Vector2i in pair[1]:
			err = _T.assert_true(probe.is_buildable(at),
				("the %s garden's %s is somewhere a plant may actually stand — a cell that "
					+ "has become road is refused at placement, and the garden is quietly "
					+ "one plant smaller") % [pair[0], at])
			if err != "":
				break
	if err == "":
		var whole: Dictionary = {}
		for at: Vector2i in _whole_road_garden():
			for cell: Vector2i in PlacementPreview.covered_road_cell_list(
					probe, at, CornCobbler.RANGE):
				whole[cell] = true
		err = _T.assert_eq(whole.size(), road,
			("the whole-road garden reaches every one of the %d road cells — that is what "
				+ "makes coverage_note() silent over it, which every over-promise reading "
				+ "below depends on") % road)
	if err == "":
		var mixed: Dictionary = {}
		for at: Vector2i in _mixed_garden():
			for cell: Vector2i in PlacementPreview.covered_road_cell_list(
					probe, at, CornCobbler.RANGE):
				mixed[cell] = true
		err = _T.assert_true(mixed.size() < road and mixed.size() > road / 2,
			("the mixed garden reaches most of the road but NOT all of it (%d of %d) — a "
				+ "garden that covered everything would make it a second copy of the "
				+ "positive control") % [mixed.size(), road])
	probe.free()
	return err


## THE measurement plant-tower-defense-4no was filed for, and it comes back zero.
##
## The map over-promises in the obvious way: a Corn shoots only the pest furthest
## along, so a cob covering eight cells is busy with one of them and the other
## seven get nothing. That is real and it is measured below — 65% of the stays on
## covered ground in this run (739 of 1129) see nothing touch the pest at all.
## What it is not is a promise the map broke, and this is the run that says so.
##
## Six waves into endless over the seven-cob garden loses half the wave: 24 of 48
## walk out (re-measured after the fixed table grew to sixteen waves — it was 17
## of 34 when the same offset was wave 14). If "covered" over-promised, this is
## the run where a player would be misled
## — the board says every cell is answered and the beds go anyway. It does not.
## Every pest that reached the exit had been fought, and every pest that spent its
## WHOLE walk inside covered ground was touched. The pests that got out untouched
## in the wider sweep (68 of them, over 14 driven runs and four gardens) had every
## one walked at least one cell the map already marks `unaimed` — so the mark was
## right about them, and it was right about them before they died.
##
## Read together with the sibling test below, which runs a wave the garden wins
## outright and gets the same 66% off the same predicate: the "in reach and did
## not act" reading is loud everywhere and quiet nowhere, so nothing can be built
## on it. That is why this issue closes with a number rather than a readout.
func test_the_coverage_map_keeps_its_promise_to_a_pest_that_never_leaves_covered_ground() -> String:
	# Six waves past the fixed table, written as an offset rather than as the
	# literal 14 it used to be. The table grew from eight waves to sixteen
	# (plant-tower-defense-74a), and wave 14 stopped being an endless wave at all
	# — the run turned into a campaign wave the garden mostly wins, which silently
	# takes away the "the garden is LOSING it" premise every assertion below
	# depends on. The offset is what this measurement was always about.
	var run: Dictionary = await _over_promise_run(WaveDirector.WAVES.size() + 6,
		_whole_road_garden(), [], 1, 12345, 40000)
	var err: String = _T.assert_eq(int(run["foreign_pests"]), 0,
		"no other test's pests were standing in the tree, so every stay below is one this run staged")
	if err != "":
		return err
	err = _T.assert_eq(int(run["covered_cells"]), int(run["road_cells"]),
		"the garden covers every one of the %d road cells, so the board warns about nothing"
			% int(run["road_cells"]))
	if err == "":
		# Conservation, and the whole run's vacuity guard in one line: a wave that
		# lost pests down a crack would make every ratio below unreadable.
		err = _T.assert_eq(int(run["killed"]) + int(run["escaped"]), int(run["spawned"]),
			"every one of the %d pests was accounted for as killed or escaped" % int(run["spawned"]))
	if err == "":
		err = _T.assert_gt(int(run["frames"]), 600,
			"and the wave was really driven, not stopped on frame one")
	if err == "":
		err = _T.assert_gt(int(run["escaped"]), int(run["spawned"]) / 3,
			("and the garden is LOSING it — %d of %d walked out, which is the only state "
				+ "an over-promise could cost anything in")
				% [int(run["escaped"]), int(run["spawned"])])
	if err == "":
		err = _T.assert_gt(int(run["stays"]), 100,
			"there are %d stays on covered ground to read" % int(run["stays"]))
	if err == "":
		# The loud half. Stated first so the quiet half below cannot be read as the
		# predicate having found nothing.
		err = _T.assert_gt(int(run["unanswered"]) * 2, int(run["stays"]),
			("%d of %d stays on covered ground (%.0f%%) saw nothing touch the pest — the "
				+ "over-promise IS there at the cell")
				% [int(run["unanswered"]), int(run["stays"]),
					100.0 * float(run["unanswered"]) / float(run["stays"])])
	if err == "":
		err = _T.assert_gt(int(run["pests_all_covered"]), 9,
			("and %d pests spent their whole road walk inside it, which is what the claim "
				+ "below is a claim about") % int(run["pests_all_covered"]))
	if err == "":
		err = _T.assert_eq(int(run["pests_all_covered_untouched"]), 0,
			("yet not one of those %d went untouched. 'Covered' is not a promise that a pest "
				+ "is shot on every cell — it is a promise that something reaches it, and over "
				+ "this run it was kept every time")
				% int(run["pests_all_covered"]))
	if err == "":
		err = _T.assert_eq(int(run["escaped_engaged"]), int(run["escaped"]),
			("and all %d escapes had been fought on the way down, so the beds were lost to "
				+ "throughput and not to a hole the map was hiding") % int(run["escaped"]))
	return err


## The control, and the reason nothing is built on the predicate.
##
## Wave 4 over the mixed garden is a clean sweep — 14 spawned, 14 killed, nothing
## escapes, no plant is even bitten. The board is as right as a board can be. Ask
## "was a plant in reach of this cell and idle" anyway and two thirds of the
## covered ground answers yes, which is the same reading the losing run above
## gives. A cue that says the same thing in a flawless wave and a catastrophic one
## is not a cue.
##
## The split is what the reading is actually made of: `busy` is a cob that fired
## at a different pest during the stay, `slow` is one that had THIS pest picked and
## had not landed a shot yet. Both are the fire rate and the targeting rule, which
## the player already buys against (upgrade the cob, plant another). Neither is
## ground nothing can reach, which is the only thing `unaimed` claims.
func test_the_in_reach_and_idle_reading_is_just_as_loud_in_a_wave_the_garden_sweeps() -> String:
	var run: Dictionary = await _over_promise_run(4, _mixed_garden(),
		[Vector2i(4, 2), Vector2i(4, 6)], 1, 12345, 40000)
	var err: String = _T.assert_eq(int(run["foreign_pests"]), 0,
		"no other test's pests were standing in the tree while this wave ran")
	if err != "":
		return err
	err = _T.assert_eq(int(run["killed"]), int(run["spawned"]),
		"every one of the %d pests died on the board" % int(run["spawned"]))
	if err == "":
		err = _T.assert_eq(int(run["escaped"]), 0, "and nothing reached the exit")
	if err == "":
		err = _T.assert_eq(int(run["plants_eaten"]), 0, "and no bed was even lost")
	if err == "":
		err = _T.assert_gt(int(run["stays"]), 20,
			"with %d stays on covered ground to read" % int(run["stays"]))
	if err == "":
		err = _T.assert_gt(int(run["unanswered"]) * 2, int(run["stays"]),
			("and the predicate still flags %d of %d (%.0f%%) — in a wave that lost nothing")
				% [int(run["unanswered"]), int(run["stays"]),
					100.0 * float(run["unanswered"]) / float(run["stays"])])
	if err == "":
		err = _T.assert_eq(int(run["pests_untouched"]), 0,
			"while the reading that means something — a pest nothing ever touched — is 0")
	if err == "":
		err = _T.assert_gt(int(run["busy"]), int(run["slow"]) * 3,
			("and %d of the %d flags are a cob aimed at a different pest against %d that are "
				+ "the fire rate: this is throughput, not reach")
				% [int(run["busy"]), int(run["unanswered"]), int(run["slow"])])
	if err == "":
		err = _T.assert_eq(int(run["out_of_reach"]), 0,
			("and none of it is the map's own geometry — every stay it calls covered really "
				+ "did put the pest inside a covering plant's radius"))
	return err


## The third mechanism the issue named, and the one that IS a structural
## over-promise: a Chomp cannot close on a winged pest at all, so a road cell
## covered by mouths alone is covered by nothing the moment wings arrive.
##
## It is also the one that never happens. Corn is the free starter and the only
## damage in the game, its ring is 176 px against the mouth's 73.6, and every road
## cell a Chomp can reach is a cell a cob two lanes away also reaches — so a
## chomp-only cell takes a garden with no Corn in it, which is the garden below
## and is not a garden anybody has. Measured across the six Corn gardens in this
## sweep: ONE blind stay in 1,177. Machinery for it would be machinery for nobody.
func test_a_winged_pest_only_outruns_the_map_in_a_garden_with_no_corn_in_it() -> String:
	var mouths: Array = [Vector2i(2, 0), Vector2i(5, 0), Vector2i(8, 0), Vector2i(8, 3),
		Vector2i(5, 5), Vector2i(2, 6), Vector2i(5, 6), Vector2i(9, 6), Vector2i(12, 6)]
	var jaws_only: Dictionary = await _over_promise_run(8, [], mouths, 1, 12345, 40000)
	var err: String = _T.assert_eq(int(jaws_only["foreign_pests"]), 0,
		"no other test's pests were standing in the tree while the mouths ran")
	if err != "":
		return err
	err = _T.assert_gt(int(jaws_only["winged"]), 0,
		"wave 8 really sent winged pests (%d of %d), or nothing below is a measurement"
			% [int(jaws_only["winged"]), int(jaws_only["spawned"])])
	if err == "":
		err = _T.assert_gt(int(jaws_only["stays"]), 20,
			"and they walked %d stays on ground the mouths call covered" % int(jaws_only["stays"]))
	if err == "":
		err = _T.assert_gt(int(jaws_only["blind_winged"]) * 2, int(jaws_only["unanswered"]),
			("in a garden of mouths the blind-to-wings case is the over-promise: %d of the %d "
				+ "unanswered stays") % [int(jaws_only["blind_winged"]), int(jaws_only["unanswered"])])

	var with_corn: Dictionary = await _over_promise_run(8, _mixed_garden(),
		[Vector2i(4, 2), Vector2i(4, 6)], 1, 12345, 40000)
	if err == "":
		err = _T.assert_eq(int(with_corn["foreign_pests"]), 0,
			"nor while the mixed garden ran")
	if err == "":
		err = _T.assert_gt(int(with_corn["winged"]), 0,
			"the same wave sends wings at the mixed garden too (%d of %d)"
				% [int(with_corn["winged"]), int(with_corn["spawned"])])
	if err == "":
		err = _T.assert_gt(int(with_corn["unanswered"]), 20,
			"and it flags %d unanswered stays to look through" % int(with_corn["unanswered"]))
	if err == "":
		err = _T.assert_true(int(with_corn["blind_winged"]) <= 2,
			("but put two cobs anywhere near those mouths and the case all but vanishes: %d "
				+ "blind stays of %d unanswered. A 176 px ring covers everything a 73.6 px "
				+ "mouth does, so a chomp-only cell needs a garden with no Corn in it")
				% [int(with_corn["blind_winged"]), int(with_corn["unanswered"])])
	if err != "":
		return err

	# The positive control, and the reason the zero in the sibling test is a
	# reading rather than a broken detector. A mouth beside every road cell: the
	# map calls the entire road covered, and a winged pest crosses the whole of it
	# with nothing able to close on it. Same harness, same predicate, non-zero — so
	# `pests_all_covered_untouched` is not stuck at 0.
	#
	# Derived, not typed (plant-tower-defense-m9u2). This was thirty-one hardcoded
	# cells against the pre-climb road and twenty-six against the current one; it is
	# now whatever the road needs, and the assertion below reads `road_cells` rather
	# than a literal so it cannot disagree with the garden it was built from.
	var walled_probe := Board.new()
	var walled: Array = _cover_greedily(walled_probe, ChompFlower.GRAB_RADIUS, -1)
	walled_probe.free()
	var err_walled: String = _T.assert_gt(walled.size(), 0,
		"the derivation found somewhere to put a mouth at all")
	if err_walled != "":
		return err_walled
	var walled_run: Dictionary = await _over_promise_run(8, [], walled, 1, 12345, 40000)
	err = _T.assert_eq(int(walled_run["foreign_pests"]), 0,
		"nor while the walled road ran")
	if err == "":
		err = _T.assert_eq(int(walled_run["covered_cells"]), int(walled_run["road_cells"]),
			"a mouth beside every road cell covers all %d of them" % int(walled_run["road_cells"]))
	if err == "":
		err = _T.assert_gt(int(walled_run["pests_all_covered"]), 0,
			"and pests really walked the whole road inside it (%d of %d)"
				% [int(walled_run["pests_all_covered"]), int(walled_run["spawned"])])
	if err == "":
		err = _T.assert_gt(int(walled_run["pests_all_covered_untouched"]), 0,
			("and %d of them came out untouched — the coverage map CAN over-promise, and this "
				+ "is what it looks like when it does. Every zero this file reports elsewhere "
				+ "is measured by the same counter that fires here")
				% int(walled_run["pests_all_covered_untouched"]))
	return err
