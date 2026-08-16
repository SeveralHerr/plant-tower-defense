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
		Sfx.WAVE_STARTED, Sfx.UPROOT_ARMED,
		Sfx.RUN_WON, Sfx.RUN_LOST,
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
	meter.husk_collected.connect(func(value: int) -> void: collected.append(value))
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
		err = _T.assert_true(Plant.health_bar_color(true) != Plant.health_bar_color(false),
			"a regrowing bar is a different colour from a hurt one — the only cue the mechanic has")
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
# The filed defect, re-derived off the constants: the aphid gap floors at wave 22,
# the beetle gap at 28, mutation chance at 31, health at 42 and speed at 48. From
# wave 49 the only endless scale still moving was `count`, and nothing capped it —
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
	## is not the deepest one: the peak lands at wave 20, where the swarm and the
	## column are both still small enough to sit on the road together at their
	## natural spacing, and a test that only looked at wave 100 would miss it.
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
	## board beats forever. The first block pins that all four of the old scales
	## really are dead past wave 48, so the climb below cannot be coming from them.
	var late: int = 49
	var far: int = 500
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


func test_the_fixed_eight_wave_campaign_is_untouched_by_the_road_budget() -> String:
	## Endless and campaign share this file, and the road budget is written in terms
	## of `wave - WAVES.size()`, so campaign is untouched by construction rather than
	## by a mode flag. Asserted anyway, against the literal table, because "by
	## construction" is a claim about code that someone edits next week.
	var expected: Array[int] = [5, 9, 9, 14, 13, 19, 19, 29]
	var err: String = _T.assert_eq(WaveDirector.WAVES.size(), expected.size(),
		"the campaign is still eight waves long")
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
	err = _T.assert_eq(groups.size(), table.size(), "wave 8 is still two groups")
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
		err = _T.assert_gte(WaveDirector.SIMULTANEOUS_PEST_CEILING,
			WaveDirector.peak_simultaneous_pests(WaveDirector.WAVES.size()),
			"and the hardest campaign wave was always inside the ceiling anyway (%d)"
				% WaveDirector.peak_simultaneous_pests(WaveDirector.WAVES.size()))
	return err


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
				var worst: Label = panel.get_node_or_null("Value_Weakestground") as Label
				err = _T.assert_true(worst != null, "the weakest-ground row exists")
				if err == "":
					var widest: float = font.get_string_size(
						worst.text, HORIZONTAL_ALIGNMENT_RIGHT, -1, font_size).x
					err = _T.assert_gt(widest, wanted,
						"and weakest ground, not compost, still sets the card's width (%.0f vs %.0f px)"
							% [widest, wanted])
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
