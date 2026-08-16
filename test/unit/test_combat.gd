extends RefCounted

## Plants versus bugs — the two behaviours the drawings actually specify.
##
## Corn: "one cob firing one kernel" upgrading to a spread labelled "bunch of
## corn". Chomp: "eats small pests easily, takes a while eating bigger pests".
## The second one is a balance lever, not a flavour note, so the occupancy is
## asserted here rather than assumed.

var _T


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
	corn._act(1.0, pests)
	var kernels: Array[Node] = host.get_tree().get_nodes_in_group("kernels")
	var err: String = _T.assert_gt(kernels.size(), 0, "the cob fired")
	if err == "":
		var kernel := kernels[0] as Kernel
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
	far._leg = 4

	var host: Node2D = _host([corn, near, far])
	await _T.instantiate_scene(host)
	var candidates: Array[Pest] = [near, far]
	var target: Pest = corn._furthest_along_in_range(candidates, CornCobbler.RANGE)
	var err: String = _T.assert_true(target == far,
		"targets the pest at progress %.2f, not the closer one at %.2f" % [far.progress(), near.progress()])
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
