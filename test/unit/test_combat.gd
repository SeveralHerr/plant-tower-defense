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


## Stage a pest where a Chomp will actually close on it.
##
## Since plant-tower-defense-q9h4 a Chomp refuses anything it has not yet let PAST
## (`ChompFlower.GRAB_LEAD`), and `_pest()` above walks every pest +X. So a test that
## stages its prey level with the flower is now a test of an idle plant: it does not fail
## honestly, it passes or fails for a reason it never meant to state, which is worse.
##
## This offsets along that same heading by the lead plus a margin and changes nothing
## else. Where a test's claim IS a distance, it stages by hand instead and says so.
func _prey(species: StringName, at: Vector2) -> Pest:
	return _pest(species, at + Vector2(ChompFlower.GRAB_LEAD + 4.0, 0.0))


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
	##
	## The floor moved with plant-tower-defense-q9h4 and this test moved with it. A pest
	## has to be GRAB_LEAD past the stem before the mouth will close, and that lead is
	## spent along the road while the cell of separation is spent across it — so the
	## reach a working Chomp actually needs is the hypotenuse of the two, not CELL. Staged
	## by hand rather than through `_prey()` because that hypotenuse is this test's claim.
	var chomp := ChompFlower.new()
	var across: float = float(Board.CELL)
	var along: float = ChompFlower.GRAB_LEAD + 4.0
	var pest: Pest = _pest(Pest.APHID, Vector2(along, -across))
	var host: Node2D = _host([chomp, pest])
	await _T.instantiate_scene(host)

	var pests: Array[Pest] = [pest]
	chomp._act(0.016, pests)
	var needed: float = sqrt(across * across + along * along)
	var err: String = _T.assert_true(chomp.is_busy(),
		("a pest one full cell across the lane (%d px) and %.0f px past the stem is %.1f "
			+ "px away, inside a %.0f px reach") % [Board.CELL, along, needed,
				ChompFlower.GRAB_RADIUS])
	if err == "":
		err = _T.assert_true(ChompFlower.GRAB_RADIUS > needed,
			("and the reach clears that hypotenuse with room, not by a hair — %.1f "
				+ "against %.1f. Under it the plant is inert, and inert looks exactly "
				+ "like 'no pest in range'") % [ChompFlower.GRAB_RADIUS, needed])
	if err == "":
		err = _T.assert_true(ChompFlower.GRAB_RADIUS < Board.CELL * 2.0,
			"but not so far it eats out of the lane two cells over")
	_T.free_ui(host)
	return err


func test_a_chewing_chomp_holds_the_pest_still() -> String:
	var chomp := ChompFlower.new()
	var beetle: Pest = _prey(Pest.BEETLE, Vector2.ZERO)
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
	var beetle: Pest = _prey(Pest.BEETLE, Vector2.ZERO)
	var aphid: Pest = _prey(Pest.APHID, Vector2(6, 0))
	var host: Node2D = _host([chomp, beetle, aphid])
	await _T.instantiate_scene(host)

	var pests: Array[Pest] = [beetle, aphid]
	chomp._act(0.016, pests)
	chomp._act(0.016, pests)
	# Staged through `_prey` rather than `_pest`, and that is not cosmetic: with both
	# bugs level with the stem this test went on PASSING after q9h4 while the flower
	# grabbed neither of them, so "the second pest walks past an occupied mouth" was
	# true of a mouth that was never occupied.
	var err: String = _T.assert_true(chomp.held_pest() == beetle,
		"the nearer bug is in the mouth, so there IS an occupied mouth to test")
	if err == "":
		err = _T.assert_true(aphid.held_by == null,
		"the second pest walks straight past an occupied mouth — this is the whole cost of a Chomp")
	if err == "":
		err = _T.assert_true(aphid.is_alive(), "and is still alive to prove it")
	_T.free_ui(host)
	return err


func test_a_chomp_swallows_its_meal_and_frees_up() -> String:
	var chomp := ChompFlower.new()
	var aphid: Pest = _prey(Pest.APHID, Vector2.ZERO)
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
	var beetle: Pest = _prey(Pest.BEETLE, Vector2.ZERO)
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
	# GUARDED, like every other loop in this suite (`guard < 4000`, `waited < 30`). This
	# one climbed until upgrade() returned false, which is a termination condition owned by
	# the code under test -- so a defect that stopped `level` advancing would hang here and
	# take the WHOLE SUITE with it rather than failing. Found in cycle 150 by mutating
	# `level += 1` away and watching the runner get SIGTERMed at 6m40s
	# (plant-tower-defense-4uts). The bound is the ladder's own length plus slack, so it
	# still exercises every rung.
	var climbs: int = 0
	while corn.upgrade() and climbs < CornCobbler.LEVELS.size() + 2:
		climbs += 1
	var err: String = _T.assert_true(corn.is_max_level(),
		"the ladder terminates (after %d climb(s))" % climbs)
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
	# ONE WHOLE RELOAD, read off the cob rather than the 1.0 that stood here. The
	# settle frames above run `_act` themselves, so the cooldown is already armed by the
	# time this line runs and the tick has to clear a full `fire_interval()` -- which a
	# hard-coded 1.0 did only while level 1's interval happened to be under it. At 1.14,
	# tried and rejected for this cob, that literal turned this into "the cob fired:
	# Expected 0 > 0" -- a failure about the fixture that reads exactly like the aiming
	# regression the test is actually for.
	corn._act(corn.fire_interval() + 0.01, pests)
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
	#
	# Both halves of that — `route.size() - 1` is the model's last leg, `route.size() - 2`
	# is the last one a hosted test may park on — are asserted against `Pest._advance`
	# by test_the_last_leg_of_a_route_is_the_one_a_pest_escapes_off at the foot of this
	# file, so the 3 below is a consequence of a checked rule rather than a number
	# somebody counted off a route literal.
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
	# THE LAST SWARM, not the last row. The campaign's final row is one Cutworm and
	# nothing else, so read literally this test asks whether 1 pest is more than twice 5
	# -- and the answer "no" says nothing about whether the campaign ramps, because that
	# row's difficulty is one body's LENGTH and not its headcount. `last_swarm_wave` is
	# the derivation that names it (see its header on why it is not the number 26), so
	# appending or removing another solo boss moves this with it.
	var last_swarm: int = WaveDirector.last_swarm_wave()
	var last: int = WaveDirector.pests_in_wave(last_swarm)
	director.free()
	return _T.assert_gt(last, first * 2,
		"the last swarm, wave %d (%d pests), is more than twice the first (%d)"
			% [last_swarm, last, first])


func test_a_started_wave_schedules_exactly_the_pests_the_table_promises() -> String:
	## The HUD tells the player "Wave 3 — 9 pests" straight off the table, so a
	## schedule that disagrees with it is a lie on screen.
	var director := WaveDirector.new()
	var host: Node2D = _host([director])
	await _T.instantiate_scene(host)

	var spawned: Array[StringName] = []
	director.spawn_requested.connect(func(species: StringName, _mutations: Array) -> void: spawned.append(species))
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


## The flight hint's own condition, all four combinations, before anything that reads it.
##
## Two inputs is four cases and only one says yes, so a single worked example would prove
## almost nothing — and the interesting case is the one that says NO with a winged pest
## present: a Chomp with something it CAN eat in reach is not confusing, because the
## player watches the mouth close on that one. The hint is for the mouth that sits still.
func test_a_chomp_is_only_puzzling_when_everything_in_reach_flies() -> String:
	var err: String = _T.assert_true(ChompFlower.idle_only_because_of_flight(1, 0),
		"one winged pest and nothing else in reach: the mouth sits still for a reason "
			+ "nothing on screen explains")
	if err == "":
		err = _T.assert_false(ChompFlower.idle_only_because_of_flight(1, 1),
			"a grabbable pest alongside it means the plant visibly works -- no hint needed")
	if err == "":
		err = _T.assert_false(ChompFlower.idle_only_because_of_flight(0, 1),
			"a grabbable pest alone is the ordinary case")
	if err == "":
		err = _T.assert_false(ChompFlower.idle_only_because_of_flight(0, 0),
			"an empty reach is not puzzling, it is quiet")
	return err


func test_a_chomp_walked_over_by_a_flier_says_so_exactly_once() -> String:
	## End to end through the game's OWN path, which is why the connection is made before
	## the tree comes up. `Plant._physics_process` calls `_act(delta, _live_pests())` every
	## frame (`game/plant.gd:368`), so the settle frames are what fire this — and the first
	## draft of this test connected afterwards, watched zero emissions, and looked like a
	## broken signal. It was the opposite: the edge had already been spent, unheard, before
	## the listener existed.
	##
	## Asserting across those frames is the stronger claim in both directions. It proves
	## the wiring rather than a hand-call, and **`== 1` over an unknown number of physics
	## frames IS the rising-edge assertion** — a level-triggered signal would report one
	## per frame, which is what would put this sentence on the message row sixty times a
	## second.
	RunConfig.earned_milestones.erase(RunConfig.HINT_CHOMP_IGNORES_FLIGHT)
	var chomp := ChompFlower.new()
	var pest: Pest = _pest(Pest.APHID, Vector2(0, -Board.CELL))
	pest.apply_mutation(Pest.MUTATION_WINGED)
	var posted: Array[String] = []
	chomp.flight_ignored.connect(func() -> void: posted.append("said"))
	var host: Node2D = _host([chomp, pest])
	await _T.instantiate_scene(host)

	# Reset explicitly, and the reason is worth more than the line: `Plant._physics_process`
	# calls `_act(delta, _live_pests())` every frame, so the settle frames MAY already have
	# spent the edge — and how many physics frames a headless settle actually ticks is not
	# something a unit test should encode. Clearing both sides makes the two calls below
	# the only ones that can count, whatever the helper did.
	chomp._flight_noted = false
	posted.clear()
	var pests: Array[Pest] = [pest]
	chomp._act(0.016, pests)
	var err: String = _T.assert_eq(posted.size(), 1,
		"a Chomp walked over by a flier emits flight_ignored (d=%.1f, reach %.1f)"
			% [pest.global_position.distance_to(chomp.global_position),
				ChompFlower.GRAB_RADIUS])
	if err == "":
		err = _T.assert_false(chomp.is_busy(),
			"and it is genuinely idle -- the signal is not firing beside a working mouth")
	if err == "":
		# The pest has not moved, so the condition is still true. This is the rising-edge
		# assertion: level-triggered, it would emit again, and the same sentence would
		# reach the message row on every physics frame the pest spends in reach.
		chomp._act(0.016, pests)
		err = _T.assert_eq(posted.size(), 1,
			"and not again while the same pest is still standing over it")
	if err == "":
		err = _T.assert_true(Hud.flight_tip().contains("Corn"),
			"the sentence names the plant that CAN hit it -- a rule with no counter-play "
				+ "is a complaint")
	_T.free_ui(host)
	RunConfig.earned_milestones.erase(RunConfig.HINT_CHOMP_IGNORES_FLIGHT)
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
	##
	## THIS LIST STAYS HAND-TYPED ON PURPOSE (plant-tower-defense-xc07). Deriving it
	## from `Sfx.SOUNDS` is the obvious move and it is the wrong one: SOUNDS is what it
	## is being compared against, so a derived list would assert that the table equals
	## itself. `.claude/skills/derive-the-list/SKILL.md` has the case -- when deriving
	## removes the second side, the hand-typing IS the check, and the cost of updating
	## it is the feature, because paying it is what makes someone notice the set moved.
	## Ten commits have paid it (34f436b, 2a162f3, 388db1a, 6117da4, 075fce9, a2f91d9,
	## 6dbbe19, 5e6f766, 488b687, 5a7bfe8) and it has never once been stale, because
	## the size assertion at the bottom will not let it be.
	##
	## What this test CANNOT see is the third side: whether any of these ids is still
	## reached from a real `Sfx.play(` call site, and whether a cue played from one has
	## a row at all when nobody thought to add it here. `Sfx.play()` is gated off
	## headless, so no test can watch a call site; `python tools/sfx_call_check.py`
	## scans game/ for that half and holds both directions.
	var used: Array[StringName] = [
		Sfx.PLANT_PLACED, Sfx.PLANT_BITTEN, Sfx.PLANT_DESTROYED,
		# Both kill ids: game.gd picks between them on husk_multiplier(), so a table row
		# missing for either is a kill that makes no sound for a whole class of pest.
		Sfx.PEST_KILLED, Sfx.PEST_KILLED_HARD, Sfx.PEST_ESCAPED,
		Sfx.HUSK_COLLECTED, Sfx.HUSK_ROTTED,
		Sfx.WAVE_STARTED, Sfx.WAVE_CLEARED, Sfx.UPROOT_ARMED,
		Sfx.RUN_WON, Sfx.RUN_LOST, Sfx.PURCHASE_DENIED,
		Sfx.PLANT_UPGRADED, Sfx.PLANT_UPROOTED,
		Sfx.CORN_FIRED, Sfx.CHOMP_BITE, Sfx.SUNDEW_CLAIM,
		# The Nettle's sting -- a fourth attacking plant's own act, and a variant of
		# CORN_FIRED's soft impact rather than a voice of its own (see Sfx.NETTLE_STING).
		Sfx.NETTLE_STING,
		# The Bomb Dandelion's pair. Two ids and not one because the seed
		# leaving the head and the bomb bursting happen SeedBomb.FLIGHT_SECONDS
		# and up to Dandelion.RANGE apart — see Sfx.DANDELION_PUFF.
		Sfx.DANDELION_PUFF, Sfx.SEED_BOMB_BURST,
		Sfx.SEEDS_GROWN, Sfx.BUTTON_PRESSED,
		# The plant bar's own cue, split off BUTTON_PRESSED when the bar became a
		# drag as well as a click — see Sfx.PLANT_CHOSEN and Game._on_plant_chosen.
		Sfx.PLANT_CHOSEN,
	]
	for event: StringName in used:
		var err: String = _T.assert_true(Sfx.SOUNDS.has(event),
			"'%s' has a sound behind it" % event)
		if err != "":
			return err
	return _T.assert_eq(used.size(), Sfx.SOUNDS.size(),
		"and the table holds nothing the game never plays")


# -- the ambience bed -------------------------------------------------------


## The bed is deliberately outside `SOUNDS`, and that absence is load-bearing:
## `test_every_event_id_the_call_sites_use_is_in_the_table` asserts the table holds
## nothing the game never plays, and a loop is never played by `Sfx.play()`. So the
## file has to be checked somewhere, and this is that somewhere — otherwise the one
## sound in the project with no table row is also the one with no test.
func test_the_bed_is_not_a_cue_and_still_loads() -> String:
	for event: StringName in Sfx.SOUNDS:
		var err: String = _T.assert_true(String(Sfx.SOUNDS[event]) != Sfx.AMBIENCE_SOUND,
			("'%s' points at the ambience bed. A loop with an event id is a cue nothing "
				+ "fires: `play()` would start it, the repeat gate would throttle it and "
				+ "the next kill would steal its voice") % event)
		if err != "":
			return err
	var err: String = _T.assert_true(ResourceLoader.exists(Sfx.AMBIENCE_SOUND),
		"Sfx.AMBIENCE_SOUND names a file that exists: %s" % Sfx.AMBIENCE_SOUND)
	if err != "":
		return err
	var stream: AudioStream = Sfx.ambience_stream()
	err = _T.assert_true(stream != null, "and it loads: %s" % Sfx.AMBIENCE_SOUND)
	if err == "":
		err = _T.assert_gt(stream.get_length(), 0.0,
			"and it has a length — a zero-length bed is silence with a voice held open")
	return err


## The half of the bed that lives in the .import rather than in any .gd file, which is
## exactly why it needs an assertion: `edit/loop_mode=2` is one line in a generated file
## that a re-import can drop, and losing it does not break anything loudly. (2 is Forward.
## The importer's enum starts at "Detect From WAV", so its 1 means DISABLED — writing the
## obvious 1 there imports a bed that silently does not loop, which is what this caught.) It downgrades
## the bed to `Sfx._on_ambience_finished` re-firing the voice, which restarts the footfalls
## with a seam every %.2f seconds for the whole of every wave.
func test_the_bed_loops_rather_than_restarting_with_a_seam() -> String:
	var stream: AudioStream = Sfx.ambience_stream()
	var err: String = _T.assert_true(stream != null, "the bed loads at all")
	if err != "":
		return err
	var wav := stream as AudioStreamWAV
	err = _T.assert_true(wav != null,
		"the bed is the AudioStreamWAV whose loop_mode the .import sets, got %s"
			% stream.get_class())
	if err == "":
		err = _T.assert_true(Sfx.ambience_stream_loops(),
			("%s came back with loop_mode == LOOP_DISABLED — its .import lost "
				+ "`edit/loop_mode=2`, and the bed will restart with an audible seam "
				+ "every %.2fs instead of running unbroken")
				% [Sfx.AMBIENCE_SOUND, stream.get_length()])
	return err


## The bed's decision, over the whole grid of what can silence it. Hand-typed
## expectations rather than a recomputed `walkers > 0 and not muted and not headless`,
## which would assert the implementation against itself.
func test_should_loop_ambience_answers_the_whole_truth_table() -> String:
	# walkers, muted, headless, expected
	var cases: Array = [
		[0, false, false, false],
		[1, false, false, true],
		[5, false, false, true],
		[1, true, false, false],
		[1, false, true, false],
		[1, true, true, false],
		[0, true, false, false],
		[0, false, true, false],
		# A count that has gone negative is a bug in the caller, not permission to
		# run the bed forever.
		[-1, false, false, false],
	]
	for case: Array in cases:
		var err: String = _T.assert_eq(
			Sfx.should_loop_ambience(int(case[0]), bool(case[1]), bool(case[2])),
			bool(case[3]),
			"should_loop_ambience(walkers=%d, muted=%s, headless=%s)"
				% [int(case[0]), case[1], case[2]])
		if err != "":
			return err
	return _T.assert_eq(cases.size(), 9, "the grid is the whole grid, not a sample")


## What the board wants survives a mute, and that is the whole reason `_ambience_wanted`
## exists as state rather than being recomputed. A wave is asked for exactly once per
## spawn: without this, unmuting mid-wave leaves the garden silent until the next pest
## walks on, which can be a wave away.
func test_a_mute_silences_the_bed_without_the_board_changing_its_mind() -> String:
	var stashed_muted: bool = Sfx.is_muted()
	var stashed_wanted: bool = Sfx.ambience_wanted()
	Sfx.set_muted(false)
	var sounding: bool = Sfx.set_ambience(true)
	var err: String = _T.assert_true(Sfx.ambience_wanted(),
		"the board asked for the bed")
	if err == "":
		# Headless is the runner's own state and the gate is documented to hold there,
		# so "wanted but not sounding" is the CORRECT answer here, not a failure.
		err = _T.assert_false(sounding,
			"and headless it is wanted without sounding — Sfx.audio_enabled()'s gate")
	if err == "":
		err = _T.assert_false(Sfx.ambience_playing(), "so no voice is carrying it")
	if err == "":
		Sfx.set_muted(true)
		err = _T.assert_true(Sfx.ambience_wanted(),
			"a mute silences the bed and leaves the board's answer alone")
	if err == "":
		Sfx.set_muted(false)
		err = _T.assert_true(Sfx.ambience_wanted(),
			"so unmuting has something to bring back")
	if err == "":
		Sfx.set_ambience(false)
		err = _T.assert_false(Sfx.ambience_wanted(),
			"and an empty board is the only thing that clears it")
	Sfx.set_muted(stashed_muted)
	Sfx.set_ambience(stashed_wanted)
	return err


## The bed follows PESTS THAT WALK, not nodes in the "pests" group, and the two
## disagree for `Pest.DEATH_LINGER` after every kill. Staged through the real game so
## the corpse is a real corpse: `Pest.kill()` clears `_alive` and emits `died`, and the
## node stays in the group until it frees itself a third of a second later.
##
## Without the split, the garden would keep making walking noises after the wave that
## cleared it — audible on every single wave, and invisible to any test that counted
## the group.
func test_the_bed_counts_walkers_not_corpses() -> String:
	var game := await _T.instantiate_scene("res://game/game.tscn") as Game
	var err: String = _T.assert_true(game != null, "the game scene loaded")
	if err != "":
		return err
	game.spawn_pest(Pest.APHID)
	game.spawn_pest(Pest.APHID)
	err = _T.assert_eq(game.walking_pests(), 2, "two pests are on the road")
	if err == "":
		var pests: Array[Node] = game.get_tree().get_nodes_in_group("pests")
		err = _T.assert_eq(pests.size(), 2, "and both are in the group")
		if err == "":
			var victim := pests[0] as Pest
			var corpse_id: int = victim.get_instance_id()
			victim.kill()
			# By IDENTITY against a set captured before the kill, not by count. A count
			# read zero frames after `kill()` cannot be false — the body is handed to a
			# tween and `queue_free` defers to the end of the frame, so "still 2" is
			# guaranteed by the frame count rather than by the behaviour being asserted.
			# The id is what makes this a claim: THIS corpse is still in the group, which
			# is exactly what walking_pests() has to see past.
			var ids: Array[int] = []
			for node: Node in game.get_tree().get_nodes_in_group("pests"):
				ids.append(node.get_instance_id())
			err = _T.assert_true(ids.has(corpse_id),
				"the corpse itself is still in the group while it lies there")
			if err == "":
				err = _T.assert_eq(game.walking_pests(), 1,
					("but only one pest is still walking — a bed counting the group "
						+ "would keep the garden noisy for Pest.DEATH_LINGER after "
						+ "every kill, on every wave"))
			if err == "":
				(pests[1] as Pest).kill()
				err = _T.assert_eq(game.walking_pests(), 0,
					"and the last kill empties the road, corpses and all")
	_T.free_ui(game)
	return err


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
	## The guard on the entire mechanic, and it is a tighter guard than it looks
	## since the chop landed. A pest mid-meal used to call take_damage() on every
	## physics frame, which pinned the quiet clock at zero by brute force; it now
	## lands three strikes about 1.07s apart (Pest.chop_period()), so the clock
	## actually RUNS between them and only Plant.REGROWTH_DELAY's 6s margin is
	## keeping regrowth out of the meal. This is the test that fails if either
	## number moves far enough for a bed to start healing between bites.
	##
	## The 2.86s it pins is Pest.chop_period()'s whole reason for being the number
	## it is: the cadence is solved so the THIRD strike lands exactly when the old
	## per-frame drain would have finished the plant. Driven through
	## Pest._physics_process rather than through take_damage() directly, so it is
	## the real eating path being timed and not a re-implementation of it.
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
	# And the beetle's swing with them. The settle frames advanced its chop clock
	# by about 0.14s, which would land the first strike early and make the elapsed
	# time below shorter than the cadence actually is — a version of this test that
	# skipped this line measured 2.717s against the 2.857s the pest really takes.
	beetle._chop_clock = 0.0
	beetle._chop_target = null

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


## THE CADENCE IS DERIVED, and this is the test that says so. Every number here is
## re-solved from `Plant.MAX_HEALTH` and `Pest.EAT_DPS` rather than typed, so a retune of
## either moves the chop with it instead of leaving the constants pointing at a rhythm
## that used to be right.
func test_the_chop_cadence_is_solved_from_the_rate_it_replaced() -> String:
	var err: String = _T.assert_float_eq(
		Pest.chop_damage() * float(Pest.CHOPS_TO_FELL), Plant.MAX_HEALTH, 0.0001,
		"three chops fell a full bed exactly, with no rounding slack left over")
	if err == "":
		# The last strike of the three, in absolute seconds from the moment the pest
		# engages: CHOPS_TO_FELL - 1 whole cycles plus the fraction into the last one.
		var last_strike: float = (float(Pest.CHOPS_TO_FELL - 1) + Pest.CHOP_STRIKE_AT) \
			* Pest.chop_period()
		err = _T.assert_float_eq(last_strike, Plant.MAX_HEALTH / Pest.EAT_DPS, 0.0001,
			("and the last of them lands at %.3fs -- the instant the per-frame drain "
				+ "this replaced would have finished the plant, which is the whole "
				+ "reason this is a legibility change and not a balance change")
				% last_strike)
	if err == "":
		# The gift the player actually gets, and the reason "chops less often" is true
		# of the FIGHT and not only of the animation.
		var window: float = Pest.CHOP_STRIKE_AT * Pest.chop_period()
		err = _T.assert_gt(window, 0.5,
			("a bed loses nothing for the first %.2fs, which is a window to answer in "
				+ "rather than a frame") % window)
	if err == "":
		# Against the plant's own recovery clock. Six seconds of quiet is what keeps
		# regrowth out of a meal now that the bites have gaps between them at all.
		err = _T.assert_gt(Plant.REGROWTH_DELAY, Pest.chop_period() * 2.0,
			("and the gap between chops (%.2fs) stays well inside REGROWTH_DELAY "
				+ "(%.1fs), so a bed still cannot heal between bites")
				% [Pest.chop_period(), Plant.REGROWTH_DELAY])
	if err == "":
		# The wilt is derived from EAT_DPS and the chop is derived from the same
		# number, so the two land in a fixed relationship: the plant is under the
		# threshold after the second chop and holds the pose through the third's
		# entire wind-up rather than flashing it.
		var after_two: float = (Plant.MAX_HEALTH - 2.0 * Pest.chop_damage()) / Plant.MAX_HEALTH
		err = _T.assert_true(after_two < Plant.wilt_threshold(),
			("two chops in, the bed is at %.3f of full and visibly wilting (threshold "
				+ "%.3f) with a whole wind-up left to watch")
				% [after_two, Plant.wilt_threshold()])
	return err


## A frame long enough to span a whole cycle owes the plant two chops. Pure, because the
## suite cannot produce a real 2.5s physics frame and the machine that can is the one
## nobody is watching.
func test_a_long_frame_owes_the_plant_every_chop_it_spanned() -> String:
	var period: float = Pest.chop_period()
	var strike: float = Pest.CHOP_STRIKE_AT * period
	var err: String = _T.assert_eq(Pest.chop_strikes_between(0.0, strike - 0.001, period), 0,
		"nothing lands before the strike phase")
	if err == "":
		err = _T.assert_eq(Pest.chop_strikes_between(0.0, strike + 0.001, period), 1,
			"one lands on it")
	if err == "":
		err = _T.assert_eq(Pest.chop_strikes_between(0.0, period * 3.0, period), 3,
			"and a frame spanning three whole cycles owes three -- a bite rate that "
				+ "quietly halved itself under load would be a difficulty setting "
				+ "nobody chose")
	if err == "":
		err = _T.assert_eq(Pest.chop_strikes_between(0.5, 0.5, period), 0,
			"a frame with no time in it costs nothing")
	if err == "":
		err = _T.assert_eq(Pest.chop_strikes_between(0.0, 5.0, 0.0), 0,
			"and a period of zero is a pest that never chops, not a divide by zero")
	return err


## The lump. This is the behaviour the bead was actually about: the damage arrives as
## THREE events a player can point at, not as sixty invisible ones a second.
func test_a_hungry_pest_bites_in_lumps_a_player_can_count() -> String:
	var plant := Plant.new()
	plant.setup(PlantCatalog.CORN, Vector2i(0, 0), null)
	var beetle: Pest = _pest(Pest.BEETLE, Vector2(0, -Board.CELL))
	beetle.apply_mutation(Pest.MUTATION_HUNGRY)
	var host: Node2D = _host([plant, beetle])
	await _T.instantiate_scene(host)
	beetle.set_physics_process(false)
	plant.set_physics_process(false)
	plant.health = Plant.MAX_HEALTH
	beetle._chop_clock = 0.0
	beetle._chop_target = null

	# Every frame on which the bed lost anything, and how much. A drizzle produces
	# one entry per frame; a chop produces exactly CHOPS_TO_FELL.
	var bites: Array[float] = []
	var step: float = 1.0 / 60.0
	var last: float = plant.health
	var guard: int = 0
	while not plant.is_destroyed() and guard < 600:
		beetle._physics_process(step)
		if plant.health < last - 0.0001:
			bites.append(last - plant.health)
			last = plant.health
		guard += 1

	var err: String = _T.assert_eq(bites.size(), Pest.CHOPS_TO_FELL,
		("the bed lost health on exactly %d frames, not on every frame it was being "
			+ "eaten on") % Pest.CHOPS_TO_FELL)
	if err == "":
		for i: int in range(bites.size()):
			err = _T.assert_float_eq(bites[i], Pest.chop_damage(), 0.0001,
				"and chop %d landed a whole chop_damage()" % (i + 1))
			if err != "":
				break
	if err == "":
		err = _T.assert_true(plant.is_destroyed(), "three of them still fell the bed")
	_T.free_ui(host)
	return err


## The same cadence against a Bramble, and the reason to check both is that they were two
## copies of one line before. A wall chewed on a different rhythm from a bed, for no
## stated reason, is exactly what sharing `_chop` between them prevents.
func test_a_wall_is_chopped_on_the_same_beat_a_bed_is() -> String:
	var wall := Bramble.new()
	wall.setup(PlantCatalog.BRAMBLE, Vector2i(0, 0), null)
	# ON the road, which is the whole of what a Bramble is -- Bramble.STOP_RADIUS is
	# 0.6 of a cell, so the pest has to be standing on top of it, not one cell off.
	wall.position = Vector2.ZERO
	# Plain, NOT hungry: a wall stops every pest, which is what the plant sells.
	var beetle: Pest = _pest(Pest.BEETLE, Vector2.ZERO)
	var host: Node2D = _host([wall, beetle])
	await _T.instantiate_scene(host)
	beetle.set_physics_process(false)
	wall.set_physics_process(false)
	wall.health = Plant.MAX_HEALTH
	beetle._chop_clock = 0.0
	beetle._chop_target = null

	var err: String = ""
	var step: float = 1.0 / 60.0
	var elapsed: float = 0.0
	while elapsed < Pest.CHOP_STRIKE_AT * Pest.chop_period() - step:
		beetle._physics_process(step)
		elapsed += step
	err = _T.assert_float_eq(wall.health, Plant.MAX_HEALTH, 0.0001,
		"the wall loses nothing through the wind-up either")
	if err == "":
		err = _T.assert_true(beetle.is_chopping(), "but the pest is plainly swinging at it")
	if err == "":
		beetle._physics_process(step * 2.0)
		# Scaled by the wall's resistance on the way in, exactly as the per-frame
		# amount it replaced was -- the cadence changed, the wall's answer did not.
		var expected: float = Pest.chop_damage() * wall.bite_resistance()
		err = _T.assert_float_eq(Plant.MAX_HEALTH - wall.health, expected, 0.0001,
			"and then one whole chop lands, resisted the way a Bramble resists")
	_T.free_ui(host)
	return err


## The chop moves the PICTURE. Everything that decides what happens to a pest reads
## `position`, and a lunge that hauled the node one cell off the road would silently take
## a chopping pest out of every cob's line of fire -- the nerf `_carry_offset`'s header
## refuses for the same reason.
##
## Driven through the live pest and read at the SEAM. `_gait` writes `_sprite.position`
## behind `GardenTheme.animations_enabled()`, which is false headless, so the sprite write
## itself is not reachable here; `gait_compute`'s "reach" is the value it writes and the
## composition is asserted in test_selftest.gd. What is left for the running game is the
## one line `_sprite.position = _carry_offset + Vector2.UP.rotated(aim_facing()) * reach`,
## and .claude/skills/assert-an-animation is the reason it is only one line.
func test_a_chopping_pest_swings_through_its_whole_cycle_and_never_moves() -> String:
	var plant := Plant.new()
	plant.setup(PlantCatalog.CORN, Vector2i(0, 0), null)
	plant.position = Vector2(0, -Board.CELL)
	var beetle: Pest = _pest(Pest.BEETLE, Vector2.ZERO)
	beetle.apply_mutation(Pest.MUTATION_HUNGRY)
	var host: Node2D = _host([plant, beetle])
	await _T.instantiate_scene(host)
	beetle.set_physics_process(false)
	beetle._chop_clock = 0.0
	beetle._chop_target = null
	plant.health = Plant.MAX_HEALTH

	var stood_at: Vector2 = beetle.position
	var reached: Array[float] = []
	var step: float = 1.0 / 60.0
	var err: String = ""
	for _i: int in range(int(ceil(Pest.chop_period() / step))):
		beetle._physics_process(step)
		if beetle.position != stood_at:
			err = "the pest walked while it was chopping: %s" % beetle.position
			break
		# The value `_gait` puts on the sprite, read through the same call it makes.
		reached.append(float(Pest.chop_pose(beetle.swing_phase())["reach"]))
	if err == "":
		var furthest: float = reached[0]
		var nearest: float = reached[0]
		for value: float in reached:
			furthest = maxf(furthest, value)
			nearest = minf(nearest, value)
		err = _T.assert_float_eq(furthest, Pest.CHOP_LUNGE, 0.35,
			"one cycle of a live pest reaches CHOP_LUNGE px towards the bed")
		if err == "":
			err = _T.assert_true(nearest < -Pest.CHOP_REAR * 0.9,
				("and pulls about CHOP_REAR px away from it first (%.2f) -- so the "
					+ "clock the sprite reads is really turning, not stuck at a pose")
					% nearest)
	if err == "":
		err = _T.assert_eq(beetle.position, stood_at,
			"and after a whole swing it is still standing exactly where it stopped")
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
	## is not the deepest one: it is the campaign finale (wave 22 since cycle 100), where two
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
	# BOARD.NEW() VERDICT: PINS the shipped board -- WaveDirector.route_length()
	# hardcodes Board.PATH_CORNERS internally with no road parameter, so this
	# comparison is only meaningful against the default board.
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
	# DERIVED, not a magic list. The waves below used to be [60, 100, 137, 250, 499] and
	# the docstring said "past wave 48" -- both true when the fixed table was 16 waves and
	# both wrong the moment it grew to 22, because every endless landmark keys off
	# `wave - WAVES.size()`. Wave 60 stopped being past the speed cap and the rise stopped
	# being one beetle, which is how this failed.
	#
	# So the first pinned wave is found rather than written: scan upward until all three
	# multipliers have stopped moving, then price from there. The table can grow again and
	# this follows it.
	var pinned: int = WaveDirector.WAVES.size() + 1
	while pinned < 4000:
		var a_m: float = WaveDirector.mutation_chance_for(pinned)
		var a_h: float = WaveDirector.health_scale_for(pinned)
		var a_s: float = WaveDirector.speed_scale_for(pinned)
		if (is_equal_approx(a_m, WaveDirector.mutation_chance_for(pinned + 1))
				and is_equal_approx(a_h, WaveDirector.health_scale_for(pinned + 1))
				and is_equal_approx(a_s, WaveDirector.speed_scale_for(pinned + 1))):
			break
		pinned += 1
	# assert_gt with the operands the other way up: the helper set has no assert_lt.
	err = _T.assert_gt(4000, pinned,
		"the endless multipliers pin somewhere -- if they never do, this test cannot price "
			+ "a single beetle and the ramp is unbounded")
	if err != "":
		return err
	var compared: int = 0
	for wave: int in [pinned, pinned + 40, pinned + 77, pinned + 190, pinned + 439]:
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
	var previous_wave: int = 0
	var ranked: int = 0
	for wave: int in range(1, 301):
		# The solo boss row is exempt, and `boss_solo_wave` is where the whole argument
		# lives: `_raw_threat` sums count x health, so that row reads 1800 against the
		# last swarm's 424 -- honest about what walks in and wrong about what the garden
		# has to do, since `Cutworm.ZONE_HIDE` means most of what the board fires at it
		# lands at 0.15. SKIPPED rather than special-cased, so the sweep still compares
		# the wave before it with the wave after and the seam stays covered.
		if WaveDirector.boss_solo_wave(wave):
			continue
		var threat: float = WaveDirector.threat_for(wave)
		err = _T.assert_gt(threat, previous,
			"wave %d (x%.2f) never prices below wave %d (x%.2f)"
				% [wave, threat, previous_wave, previous])
		if err != "":
			return err
		previous = threat
		previous_wave = wave
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
	# Twenty-two since cycle 100. The six new waves went in FRONT of the finale, not after
	# it, which is why the last entry is 36 and not something larger: three assertions in
	# this suite chain to cap any campaign finale at 436.7 base health, and wave 16 was
	# already at 418. Seven appended waves would have had 18.7 points to share -- one
	# beetle. See WaveDirector.WAVES for the arithmetic.
	# Wave 8 fell 29 -> 21 in cycle 101. It is MUTATION_START_WAVE, and it was
	# carrying a +45.9% count step AND the mutation multiplier's +24.0% in the same
	# wave, for +80.9% where every wave from 9 to 22 steps +2.0% to +13.6%. The
	# counts now hold wave 7's peak spawn rate exactly, so the mutation is the only
	# new thing on that wave. Re-derived, not adjusted until green.
	#
	# Waves 15 (35 -> 37) and 21 (37 -> 38) moved when the Shield Bug entered the
	# table (plant-tower-defense-pdri): 15 traded 2 beetles for 4 plated bugs and 21
	# traded 2 for 3. Both re-derived against an offline replica of _raw_threat and
	# peak_simultaneous_pests before the rows were written -- the replica was itself
	# checked by reproducing THIS array, the finale's 40-of-40 peak and endless's 29
	# first. The finale is deliberately unmoved: it is the only row with no road
	# slack and only 18.7 points of health under the seam bound.
	#
	# Waves 17 (35 -> 33) and 19 (33 -> 31) moved when the Nurse Beetle entered the
	# table (plant-tower-defense-gsai). Each row traded THREE beetles for ONE Nurse,
	# which is 48 points of base health out and 48 points back in, so both rows still
	# price at exactly what they did before (339 and 372) and the threat curve from
	# wave 1 to wave 300 is unmoved -- the campaign got harder in two places and the
	# number on the bar did not, because `_raw_threat` cannot see an aura any more
	# than it can see a plate. Re-derived against an offline replica of `_raw_threat`
	# and `peak_simultaneous_pests` before the rows were written, and the replica was
	# itself validated by reproducing THIS array, the finale's 40-of-40 peak, the
	# 436.7 seam bound and endless's 29 first. The finale is unmoved for the fourth
	# species running: it is the only row with no road slack.
	#
	# Waves 23-26 are the coda (plant-tower-defense-vyov), APPENDED after wave 22
	# rather than inserted in front of it -- WAVES' own header has the "why", and
	# the four-way departure from every growth before it is the reason wave 22 is
	# still 36 in this list even though it is no longer the last entry. 23 and 25
	# carry NO QUEEN — test_the_nurse_beetle_lands_late_and_never_shares_a_wave_
	# with_the_queen forbids it, the same invariant waves 17 and 19 already hold
	# — so they lose the queen's `brood_headroom_for` slack (2 per queen) and pay
	# for it in walking headcount instead: 23 is beetle column + Nurse + aphid
	# swarm at 39 pests (queen-free counterpart of 17/19's shape, scaled to the
	# coda) and 25 is the same shape plus 4 Shield Bugs at 33. 24 keeps the
	# finale's two queens (no Nurse in that row, so no conflict) and trades 4
	# aphids and 2 beetles for 4 Shield Bugs, at 34. 26 -- the new finale -- is
	# the old finale's shape with a third queen, traded beetles for aphids, also
	# 34. Re-derived against the same offline replica as the three growths
	# above, itself re-validated by reproducing this array, the OLD finale's
	# 40-of-40 peak now sitting at an interior wave for the first time, the NEW
	# finale's own 40-of-40, the 436.7 seam bound (headroom now 12.7, not 18.7)
	# and endless's first wave still outpricing the new finale.
	#
	# Waves 6 (19 -> 24) and 7 (19 -> 25) grew when the Leafhopper and the Locust
	# entered the table (plant-tower-defense-4zyb): five hoppers appended to wave 6
	# and six locusts appended to wave 7, both LAST in their wave and both ADDED
	# rather than traded, since neither debut had a beetle or an aphid to displace
	# without re-deriving a row the shieldbug/nurse precedent did not need to touch.
	# wave_director.gd's own note on each row has the base-health arithmetic
	# (96 -> 121 and 122 -> 146) that keeps threat_for rising strictly through both;
	# neither wave sits inside the second act's pinned range (10-22), so nothing else
	# in this file needed re-deriving.
	#
	# THIS LIST STAYS RECORDED AND MUST NOT BE DERIVED. Its only possible source of
	# truth is WAVES itself, so `expected[i] = pests_in_wave(i)` would assert a
	# tautology and pass unconditionally -- the exact "recorded list that is RIGHT"
	# case in .claude/skills/derive-the-list. It earns its keep by being a SECOND,
	# independently typed statement of the campaign's shape, so an accidental edit
	# to a row shows up here as a number a human has to agree with. The property
	# assertions below (unscaled health, speed and mutation rate; the finale's group
	# shape) are the other half the skill asks for.
	#
	# Wave 27 is 1, and it is the only entry in this list that is not a swarm
	# (plant-tower-defense-rn4p). ONE PEST: the Cutworm's body already occupies fifteen
	# of the road's thirty-two cells, so anything walking with it would be walking INSIDE
	# it. It spends none of the road budget and that is the point -- the difficulty is one
	# body's length, not the count -- which is why the property assertions below sweep it
	# like any other row while the SEAM checks in this suite exempt it by name through
	# `boss_solo_wave`.
	var expected: Array[int] = [
		5, 9, 9, 14, 13, 24, 25, 21, 26, 32, 30, 23, 35, 29, 37,
		37, 33, 32, 31, 36, 38, 36, 39, 34, 33, 34, 1,
	]
	var err: String = _T.assert_eq(WaveDirector.WAVES.size(), expected.size(),
		"the campaign is still %d waves long" % expected.size())
	if err != "":
		return err
	for wave: int in range(1, expected.size() + 1):
		err = _T.assert_eq(WaveDirector.pests_in_wave(wave), expected[wave - 1],
			"wave %d still sends %d pests" % [wave, expected[wave - 1]])
		if err == "":
			# Was "an unscaled pest" for every campaign wave. plant-tower-defense-iqp8
			# gave the campaign a second act on exactly this axis, so the property is
			# now the ramp itself rather than its absence -- derived from the two
			# constants that define it, so this row cannot drift from health_scale_for
			# without one of them being edited on purpose.
			var climbed: int = clampi(wave, WaveDirector.SECOND_ACT_START_WAVE,
				WaveDirector.WAVES.size()) - WaveDirector.SECOND_ACT_START_WAVE
			err = _T.assert_float_eq(WaveDirector.health_scale_for(wave),
				pow(1.0 + WaveDirector.CAMPAIGN_HEALTH_STEP, float(climbed)), 0.0001,
				"and a pest scaled by %d compounded second-act steps" % climbed)
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
		# The last SWARM, not the last row: the Cutworm's row peaks at 1 of 40 and spends
		# none of the road budget, which is the point of it -- the difficulty is one body's
		# length. `last_swarm_wave` names the row this claim was always about.
		err = _T.assert_eq(
			WaveDirector.peak_simultaneous_pests(WaveDirector.last_swarm_wave()),
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
	# BOARD.NEW() VERDICT: PINS the shipped board -- the weighted-mean formula is
	# road-general, but this reads Board.PATH_CORNERS[0] directly rather than a
	# corpus-supplied corner, so the site itself pins the default road's entry cell.
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
	# BOARD.NEW() VERDICT: PINS the shipped board (non-road) -- relies on Vector2i(0,0)
	# being grass under the default layout for its "off-road" probe.
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
	# BOARD.NEW() VERDICT: PINS the shipped board -- reads Board.PATH_CORNERS[0]
	# directly and relies on Vector2i(0,0) being grass under the default layout.
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
	# BOARD.NEW() VERDICT: PINS the shipped board (non-road) -- this is a UI pixel
	# layout check (caption clears the card/road-row/viewport bottom); the board is
	# only a probe for a valid exit cell, not a road-shape claim.
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
		err = _T.assert_eq(Game.engaging_plants().size(), 5,
			"five plants in this catalogue can touch a pest, and the list says which")
	if err == "":
		err = _T.assert_true(Game.engaging_plants().has(PlantCatalog.CORN),
			"a kernel that lands is one of the things that set Pest._ever_engaged")
	if err == "":
		# Nettle, added cycle 100. Decided about here rather than inherited: it damages,
		# so it engages -- even though it damages only mutated pests and is dead weight
		# before wave 8. "Can touch a pest" is a question about capability, not about how
		# often the capability is useful, and the coverage maps below read it that way.
		err = _T.assert_true(Game.engaging_plants().has(PlantCatalog.NETTLE),
			"the Nettle stings, so it counts even though it stings only mutations")
	if err == "":
		err = _T.assert_true(Game.engaging_plants().has(PlantCatalog.CHOMP),
			"and a Chomp holding a pest still is another")
	if err == "":
		err = _T.assert_true(Game.engaging_plants().has(PlantCatalog.DANDELION),
			"and a seed bomb bursting on one is the third — SeedBomb.detonate() calls take_damage")
	if err == "":
		# Bramble, added with the ninth plant. Decided about here rather than inherited,
		# and it is the entry that most looks like it should be false: it does no damage
		# at all, ever. The key's rule is "damage OR HOLD" and the Chomp is already in
		# this list for holding rather than for hurting, so a plant every pest has to
		# stop and chew through is in it for the same reason.
		err = _T.assert_true(Game.engaging_plants().has(PlantCatalog.BRAMBLE),
			"a Bramble holds every pest that walks into it, which is what the Chomp is here for")
	if err != "":
		return err

	# The divergence itself, on the two plants it exists for — and they point OPPOSITE
	# ways, which is the thing worth pinning. If either key were ever quietly derived
	# from the other, exactly one of these two pairs would still pass.
	err = _T.assert_gt(PlantCatalog.reach(PlantCatalog.SUNDEW), 0.0,
		"the Sundew has a reach the placement cue rightly warns about")
	if err == "":
		err = _T.assert_float_eq(Game.engagement_reach(PlantCatalog.SUNDEW), 0.0, 0.0001,
			"and none at all by the only measure a coverage map may use — dew never touches a pest")
	if err == "":
		err = _T.assert_true(PlantCatalog.engages(PlantCatalog.BRAMBLE),
			"the Bramble is the mirror: it engages,")
	if err == "":
		err = _T.assert_float_eq(PlantCatalog.reach(PlantCatalog.BRAMBLE), 0.0, 0.0001,
			"and reaches nothing at all — it acts on the cell it is standing on")
	if err == "":
		err = _T.assert_float_eq(Game.engagement_reach(PlantCatalog.BRAMBLE), 0.0, 0.0001,
			"so it contributes no coverage to a map built on reach, which is correct")
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
	# BOARD.NEW() VERDICT: PINS the shipped board -- staged against the real
	# (default) road with a hardcoded cob cell Vector2i(1, 0); the docstring above
	# says so explicitly ("staged against the real road and a real reach").
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
	# BOARD.NEW() VERDICT: PINS the shipped board -- (0,0)'s 64px/90.5px distances
	# to the road are specific to the default layout; also a non-road UI-text-fit
	# gate underneath.
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
		while i + 1 < segments.size():  # loop-bound-check: ok - bounded by the segment list's own size, not by the code under test.
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
	# BOARD.NEW() VERDICT: PINS the shipped board -- post/beyond are hand-picked
	# cells re-derived by hand each time the default road's shape moves (see the
	# docstring above: "the pair moved when the road grew its climb").
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
## `road_corners` is the road this run walks; empty means `Board.PATH_CORNERS`, which is what
## every caller before cycle 170 wanted and still gets by omitting it
## (plant-tower-defense-s1o8.1). A whole-wave simulation is the only place the corpus can
## answer "does this road PLAY", as opposed to "is it shaped legally", and it could not be
## asked at all while this helper built its board with no road.
##
## A REFUSED ROAD RETURNS `road_refusal` AND NOTHING ELSE, rather than falling back to the
## default. A caller that passes a road it believes is legal and silently gets the default
## snake would be measuring the shipped board and reporting it as the corpus — the failure
## would be a number that looks plausible, on the one axis where a plausible number is
## indistinguishable from a right one. `road_refusal` is `""` on every normal return, so a
## caller can assert on it without knowing whether it passed a road.
func _over_promise_run(wave: int, corn_cells: Array, chomp_cells: Array,
		corn_level: int, roll_seed: int, max_frames: int,
		road_corners: Array[Vector2i] = []) -> Dictionary:
	var dt: float = 1.0 / 60.0
	# BOARD.NEW() VERDICT: PROPERTY -- this helper already takes `road_corners` and
	# refuses (rather than silently defaulting) a bad one, so a caller can drive a
	# whole-wave simulation over any corpus road; see callers below for defaults.
	var board := Board.new()
	if not road_corners.is_empty():
		var refusal: String = board.set_road(road_corners)
		if refusal != "":
			board.free()
			return {"road_refusal": refusal}
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
	director.spawn_requested.connect(func(species: StringName, mutations: Array) -> void:
		pending.append({"species": species, "mutations": mutations}))
	director.start_next_wave()

	var pests: Array[Pest] = []
	var kernels: Array[Kernel] = []
	var episodes: Dictionary = {}
	var walked_covered: Dictionary = {}
	var walked_bare: Dictionary = {}
	var touched_ever: Dictionary = {}
	var escaped_ids: Dictionary = {}
	var escaped_unengaged_ids: Dictionary = {}

	var tally: Dictionary = {
		"road_refusal": "",
		"covered_cells": covered_at_start, "road_cells": board.road_cells().size(),
		"foreign_pests": foreign,
		"spawned": 0, "winged": 0, "killed": 0, "escaped": 0, "escaped_engaged": 0,
		# The escape-side pair the callers assert on instead of a count of engagements.
		# `escaped_unengaged` is every pest that reached the exit wearing no fought mark;
		# `escaped_unengaged_all_covered` is the subset of those whose WHOLE road walk was
		# on ground the map was still covering at the moment they stood on it. The second
		# is the one an over-promise would show up in, and it is draw-independent in a way
		# a floor on the first can never be — see the caller's argument.
		"escaped_unengaged": 0, "escaped_unengaged_all_covered": 0,
		# The schedule signature. Not asserted anywhere: it exists so that when a premise
		# guard below goes red, the message can say whether the WAVE changed rather than
		# leaving a reader to conclude the garden did. Any draw added to
		# WaveDirector._build_schedule moves these two numbers.
		"mutated": 0, "double_mutated": 0,
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
	while frame < max_frames:  # loop-bound-check: ok - max_frames is a caller-supplied int, a hard cap by construction.
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
			for which: Variant in entry["mutations"]:
				pest.apply_mutation(StringName(which))
			pests.append(pest)
			tally["spawned"] = int(tally["spawned"]) + 1
			# Read off the schedule entry rather than off the pest's own flags: the
			# entry is exactly what _build_schedule emitted, which is what the draws
			# decided. apply_mutation() is a step further downstream and would fold a
			# species rule into a number that is only useful as a signature of the roll.
			var traits: int = (entry["mutations"] as Array).size()
			if traits >= 1:
				tally["mutated"] = int(tally["mutated"]) + 1
			if traits >= 2:
				tally["double_mutated"] = int(tally["double_mutated"]) + 1
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
						escaped_unengaged_ids[id] = true
						tally["escaped_unengaged"] = int(tally["escaped_unengaged"]) + 1
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
		# Counted BEFORE the untouched `continue` below on purpose. `was_engaged()` and
		# this test's own `touched_ever` are near-twins but not the same predicate — a
		# hit the Shield Bug's plate ate marks the pest engaged and drops no health —
		# so an unfought escapee must be counted off its own set rather than inferred
		# from the untouched one.
		if whole_walk and escaped_unengaged_ids.has(id):
			tally["escaped_unengaged_all_covered"] = int(tally["escaped_unengaged_all_covered"]) + 1
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
	while road.size() - uncovered.size() < want and not reaches.is_empty():  # loop-bound-check: ok - breaks below on best_gain == 0, and every other pass erases an entry from `reaches`.
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
	# BOARD.NEW() VERDICT: PINS the shipped board -- _whole_road_garden() and
	# _mixed_garden() are recorded, taste-based cell lists for the default road
	# ("not derivable", per the docstring above them), so this checks the default
	# board specifically.
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
## walk out (re-measured after the fixed table grew to sixteen waves, and again at
## twenty-two in cycle 100 — it was 17
## of 34 when the same offset was wave 14). If "covered" over-promised, this is
## the run where a player would be misled
## — the board says every cell is answered and the beds go anyway. It does not.
## Every pest that spent its WHOLE walk inside covered ground was touched, and every
## escape that went unfought had walked ground the map had already stopped covering
## — a cob it was relying on had been eaten out from under the promise. The pests
## that got out untouched in the wider sweep (68 of them, over 14 driven runs and
## four gardens) had every one walked at least one cell the map already marks
## `unaimed` — so the mark was right about them, and it was right about them before
## they died.
##
## It used to say "every pest that reached the exit had been fought" here, and that
## sentence was a count off one RNG stream rather than a property of the map. See
## the last assertion in the body: the paragraph there is the whole argument, and it
## is the reason this test cannot be broken by adding a draw to WaveDirector.
##
## Read together with the sibling test below, which runs a wave the garden wins
## outright and gets the same 66% off the same predicate: the "in reach and did
## not act" reading is loud everywhere and quiet nowhere, so nothing can be built
## on it. That is why this issue closes with a number rather than a readout.
## The driven wave takes a ROAD now, and the parameter is proved by USE rather than by
## existing (plant-tower-defense-s1o8.1).
##
## `_over_promise_run` built its board with no road until cycle 170, which meant the one
## place in the suite that runs a whole wave over real plants, real kernels and the real
## schedule could only ever run it over the shipped snake. A road corpus that cannot be
## driven answers "is this shaped legally" and never "does this PLAY", and the second
## question is the one a player would notice.
##
## Two things asserted, and the second is the one that matters: a DIFFERENT road produces
## a different road-cell count, so the parameter is reaching the board rather than being
## accepted and dropped. A test that only checked the refusal would pass on a helper that
## validated the road and then built the default anyway — which is precisely the failure
## the helper's own header says would be indistinguishable from a right answer.
func test_a_driven_wave_can_be_run_over_a_road_that_is_not_the_shipped_one() -> String:
	# A straight run across row 4. Legal, and nothing like the default's switchback.
	var straight: Array[Vector2i] = [Vector2i(0, 4), Vector2i(13, 4)]
	var default_run: Dictionary = await _over_promise_run(2, [], [], 1, 4242, 600)
	var err: String = _T.assert_eq(String(default_run.get("road_refusal", "missing")), "",
		"a run that passes no road is not refused, and reports so rather than omitting it")
	if err == "":
		err = _T.assert_gt(int(default_run.get("road_cells", 0)), 0,
			"the default run walked a real road")
	var straight_run: Dictionary = {}
	if err == "":
		straight_run = await _over_promise_run(2, [], [], 1, 4242, 600, straight)
		err = _T.assert_eq(String(straight_run.get("road_refusal", "missing")), "",
			"a legal non-default road is accepted by the driven wave")
	if err == "":
		# THE assertion. Same seed, same garden, same wave — only the road differs, so a
		# difference here can only have come from the road reaching the board.
		err = _T.assert_true(
			int(straight_run.get("road_cells", -1)) != int(default_run.get("road_cells", -2)),
			("the straight road walks a different number of cells from the default "
				+ "(%d vs %d) -- equal counts here would mean the road was validated and "
				+ "then thrown away") % [int(straight_run.get("road_cells", -1)),
					int(default_run.get("road_cells", -2))])
	if err == "":
		err = _T.assert_eq(int(straight_run.get("road_cells", -1)), 14,
			"and it is the 14 cells a full row of a 14-wide board implies")
	# The guard gates: a diagonal segment is the road that would HANG `_build_path`, and
	# the helper must refuse it rather than quietly walking the default.
	if err == "":
		var diagonal: Array[Vector2i] = [Vector2i(0, 0), Vector2i(5, 5)]
		var refused: Dictionary = await _over_promise_run(2, [], [], 1, 4242, 600, diagonal)
		err = _T.assert_true(String(refused.get("road_refusal", "")).contains("diagonal"),
			("a diagonal road is refused BY NAME rather than run, since walking it is an "
				+ "infinite loop: got '%s'") % String(refused.get("road_refusal", "")))
	if err == "":
		err = _T.assert_eq(int(
			(await _over_promise_run(2, [], [], 1, 4242, 600,
				[Vector2i(0, 0), Vector2i(5, 5)])).get("road_cells", -1)), -1,
			"and a refused run carries no measurements at all, so nothing downstream can "
				+ "read a zero as a result")
	return err


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
		# THE STREAM-FRAGILE PREMISE, and the one place in this test where an RNG change
		# in WaveDirector can still turn a line red. It is a premise and not the claim:
		# "this seed produces a losing wave" is a fact about one schedule, so the message
		# carries the schedule's signature and says what to suspect first. A reader who
		# arrives here because a draw moved should re-pick the seed, not go looking for a
		# hole in the coverage map.
		err = _T.assert_gt(int(run["escaped"]), int(run["spawned"]) / 3,
			("and the garden is LOSING it — %d of %d walked out, which is the only state "
				+ "an over-promise could cost anything in. IF THIS IS THE RED LINE, read "
				+ "the schedule before the garden: this wave rolled %d mutated pests and "
				+ "%d doubly-mutated ones, and ANY draw added to or removed from "
				+ "WaveDirector._build_schedule reshuffles every roll after it, so the "
				+ "same seed stops producing the same wave. A different-but-valid wave "
				+ "the garden happens to win is a stream change, not a coverage failure")
				% [int(run["escaped"]), int(run["spawned"]),
					int(run["mutated"]), int(run["double_mutated"])])
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
		# NOT A COUNT OF HOW MANY ESCAPES WERE FOUGHT. A count lived on this line for
		# most of this file's history and it was a measurement wearing an assertion's
		# clothes. plant-tower-defense-9afm is about that, not about the number.
		#
		# THE HISTORY, because it is the evidence and not an anecdote. The line asserted
		# `escaped_engaged == escaped` for many cycles and read as an invariant. Cycle 81
		# added the second-mutation roll (`SECOND_MUTATION_START_WAVE`, one extra
		# `randf()` per mutated pest, and a second `randi_range` behind it) and the count
		# fell to 20 of 34. That was DEMONSTRATED to be the stream and not the feature:
		# with the draws still consumed and the second mutation never actually applied,
		# the failure was byte-identical. Nothing about doubly-mutated pests caused it; a
		# different-but-equally-valid wave did. Cycle 81 replaced the equality with a
		# half floor, which was honest and was still a quantity taken off one schedule.
		#
		# Those numbers were measured when WAVES had sixteen rows and `WAVES.size() + 6`
		# was wave 22. The table has 22 rows today, so this run is wave 28 and spawns a
		# different, larger wave — the header's counts are the re-measured ones. The
		# arithmetic in a paragraph going stale under it is itself the argument against
		# asserting a count here.
		#
		# WHAT IS ASSERTED INSTEAD, and why a reshuffle cannot move it. An implication
		# over pests rather than a count of them: no pest walked out unfought having
		# spent its WHOLE road walk on ground the map was still covering. That is
		# universally quantified over whatever the schedule happened to be, so a draw
		# added anywhere in `_build_schedule` changes WHICH pests are examined and never
		# whether the sentence holds. It is the only shape of claim a seeded 34-or-48-pest
		# simulation can carry safely, and it is the same shape as
		# `pests_all_covered_untouched` above — the one assertion here that cycle 81 left
		# untouched, which is the evidence that derivable claims are the durable ones.
		#
		# It is a live cross-check and not a restatement. `_ever_engaged` is the game's
		# flag and `touched_ever` is this test's own reading, and they are different
		# predicates: engagement is a superset, because a hit the Shield Bug's plate ate
		# marks the pest and drops no health. This line goes red exactly when a damage or
		# hold path stops marking the pest — a real defect, since the fought ring the
		# player sees is painted off that same flag. The superset is not assumed here; it
		# is asserted by `test_the_engagement_flag_can_only_ever_mark_a_prefix_of_the_road`
		# (damage that lands sets it), `test_a_pest_knows_whether_the_garden_ever_reached_it`
		# (a Chomp's hold sets it) and
		# `test_a_shield_bug_ignores_a_whole_stream_of_kernels_and_then_stops_ignoring_them`
		# (a shot that achieved nothing still sets it).
		#
		# REJECTED — a private RandomNumberGenerator for this simulation. There is
		# exactly one consumer of `WaveDirector._rng` and it is `_build_schedule`, so a
		# second generator isolates nothing: the reshuffle comes from the SHAPE of
		# consumption, not from a competing reader. And a test driving an RNG the game
		# does not use is a test of a wave no player can meet.
		#
		# REJECTED — N seeds and a distribution. It would genuinely work, and it
		# multiplies a forty-thousand-frame simulation by N in a helper five tests in
		# this file already call once each.
		#
		# REJECTED — recording the schedule as a fixture so a reshuffle reads as a diff.
		# Right shape, wrong cost: wave 28 is generated rather than tabled, so the
		# fixture is dozens of rows nobody can re-derive by reading and it has to be
		# regenerated from the game every time WAVES grows. The signature in the LOSING
		# guard above is the cheap tenth of this idea that was kept.
		#
		# NO PLAYER SEES ANY OF THIS. Nothing about the garden, the wave or the coverage
		# map changed; this test asserts a different sentence about the same run.
		err = _T.assert_eq(int(run["escaped_unengaged_all_covered"]), 0,
			("and of the %d escapes, the %d that went unfought had every one of them "
				+ "walked ground the map had already stopped covering — not one crossed "
				+ "a whole covered road untouched. The beds were lost to throughput, and "
				+ "where they were lost to a hole, the map had stopped promising that "
				+ "cell first")
				% [int(run["escaped"]), int(run["escaped_unengaged"])])
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
	# BOARD.NEW() VERDICT: PINS the shipped board -- the cover derivation itself is
	# road-general, but this is one driven wave-simulation demonstration against
	# the freshly-constructed default board, not swept across the corpus, because
	# _over_promise_run is expensive to run per-road.
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


## Does a pest killed headless ever free itself? (plant-tower-defense-j8ey)
##
## `Plant.play_exit_and_free` frees on the spot when animations are gated off, and
## two tests in `test_placement.gd` exist because that bug shipped twice.
## `Pest._play_death` takes the other route: it guards `is_inside_tree()`, then in
## BOTH branches queues `tween_interval(DEATH_LINGER)` and a
## `tween_callback(queue_free)` — so headless it depends on a Tween's interval
## elapsing rather than on an early return, and a Tween needs process frames.
##
## This is the object the game creates most, so "does the corpse ever leave" is
## worth knowing rather than assuming in either direction. The assertion is the
## honest one: a pest killed IN the tree is eventually freed. What the measurement
## is really pinning is the number of frames that takes.
func test_a_pest_killed_headless_is_eventually_freed() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var host := Node2D.new()
	tree.root.add_child(host)
	var pest: Pest = _pest(Pest.APHID, Vector2(100, 100))
	host.add_child(pest)
	var err: String = _T.assert_true(is_instance_valid(pest), "the pest is in the tree")
	if err == "":
		pest.kill()
		# Generous: DEATH_LINGER is 0.35s and a headless process frame is short,
		# so this is an upper bound on frames rather than a prediction.
		# Two frames is what `_pump` gives and roughly what `instantiate_scene`
		# settles with, so this is the window a test author actually operates in.
		# DEATH_LINGER is 0.35s; a frame would have to be 175ms for two to cover it.
		await tree.process_frame
		await tree.process_frame
		err = _T.assert_true(is_instance_valid(pest) and not pest.is_queued_for_deletion(),
			"a corpse is still on the board two frames after the kill, unlike a plant")
		if err == "":
			var frames: int = 2
			while is_instance_valid(pest) and not pest.is_queued_for_deletion() and frames < 600:
				await tree.process_frame
				frames += 1
			err = _T.assert_true(frames < 600,
				"but it does leave -- 600 frames was not enough, which means it never does")
	host.free()
	return err


## No two events may be the same sound (plant-tower-defense-1fzh).
##
## 24 named beats share 13 audio files, which is deliberate and fine — a palette
## with eleven voices is a palette. What is not fine is two events arriving at the
## player identically, and `Sfx.play` composes exactly three things: the stream
## from `SOUNDS`, `VOLUME_DB.get(event, 0.0)` and `PITCH.get(event, 1.0)`. So the
## triple (file, volume, pitch) IS what the player hears, and this asserts it is
## unique. Add a fourth thing to `play()` and this key must grow with it — which is
## the one way this check can go quietly wrong.
##
## **A fourth thing HAS arrived and this key deliberately did not grow.** `Sfx.JITTER`
## moves each play off its `PITCH` centre, so this triple is now a statement about the
## CENTRES — still the right claim, and still the only thing forbidding a duplicate row.
## The half it can no longer see is asserted next door, by
## `test_two_events_on_one_file_never_overlap_once_they_wobble`, which keys on the
## RANGES. Two checks, two claims; do not fold them (plant-tower-defense-r8zc).
##
## **There is no waiver list, on purpose.** The one sharing anybody reasoned about —
## `WAVE_CLEARED` reusing `RUN_WON`'s jingle — passes because it was already trimmed
## to −9.0 against −4.0, and the comment at `game/sfx.gd:95` says that trim is the
## point. A deliberate reuse that differentiates itself needs no exception; one that
## does not is the bug. Encoding the rule that way keeps the justification beside the
## entry it justifies rather than in a list here that drifts from it.
##
## Derived from the two const Dictionaries, so adding an event cannot forget to
## update a list somewhere.
func test_no_two_events_are_the_same_sound() -> String:
	# Denominator first: a sweep over an empty table would pass beautifully.
	var err: String = _T.assert_gt(Sfx.SOUNDS.size(), 20,
		"the table is populated (an empty sweep is a vacuous pass), got %d" % Sfx.SOUNDS.size())
	if err != "":
		return err
	var seen: Dictionary = {}
	for event: StringName in Sfx.SOUNDS:
		var key: String = "%s @ %.1f dB, pitch %.2f" % [
			str(Sfx.SOUNDS[event]).get_file(),
			float(Sfx.VOLUME_DB.get(event, 0.0)),
			float(Sfx.PITCH.get(event, 1.0)),
		]
		if seen.has(key):
			return _T.assert_eq(str(event), str(seen[key]),
				("'%s' and '%s' are both %s -- the player cannot tell them apart. "
					+ "Share the file if you like, but differentiate the volume the way "
					+ "WAVE_CLEARED differentiates itself from RUN_WON.") % [
					event, seen[key], key])
		seen[key] = event
	# And the pairs really were distinct rather than the loop having collapsed them:
	# one key per event, or the sweep proved nothing about the table it walked.
	return _T.assert_eq(seen.size(), Sfx.SOUNDS.size(),
		"every event contributed its own (file, volume, pitch) key")


## The other half, and the one the table check cannot see.
##
## `test_no_two_events_are_the_same_sound` asserts the TABLES are unique. It says
## nothing about whether anything reads them — a mutation deleting the pitch line
## from `play()` survived it, leaving `PITCH` perfectly unique and the player
## hearing twins. `play()` is gated off headless, so the assertable seam is
## `Sfx.tune_voice`, which is the one place every voice property is written.
func test_tuning_a_voice_applies_both_axes_the_table_declares() -> String:
	var voice := AudioStreamPlayer.new()
	# These two USED to share `chop.ogg`, which is why they were picked: pitch was the only
	# thing separating them. `CHOMP_BITE` has had its own `chomper-bite.wav` since
	# plant-tower-defense-tnwd, so the pair now differs in file as well — the assertion
	# below is unaffected (it reads `PITCH`, not the stream) and the pair is kept because
	# the DIRECTION is the point: a plant dying is pitched under a plant eating, which is
	# the PITCH table's own rule that losses go lower.
	Sfx.tune_voice(voice, Sfx.PLANT_DESTROYED)
	var loss_pitch: float = voice.pitch_scale
	var loss_db: float = voice.volume_db
	Sfx.tune_voice(voice, Sfx.CHOMP_BITE)
	var err: String = _T.assert_true(loss_pitch < voice.pitch_scale,
		"a plant dying is pitched below a plant eating, got %.2f vs %.2f"
			% [loss_pitch, voice.pitch_scale])
	if err == "":
		err = _T.assert_float_eq(loss_db, float(Sfx.VOLUME_DB.get(Sfx.PLANT_DESTROYED, 0.0)),
			0.0001, "and the volume came off the table too, not a constant")
	if err == "":
		# The reuse hazard the pooled voices create: an event with no entry must
		# RESET the property, not inherit the last event's. This is why every
		# property is written unconditionally.
		Sfx.tune_voice(voice, Sfx.PEST_ESCAPED)
		Sfx.tune_voice(voice, Sfx.CHOMP_BITE)
		err = _T.assert_float_eq(voice.pitch_scale, 1.0, 0.0001,
			"a voice borrowed by an untuned event goes back to 1.0, got %.2f"
				% voice.pitch_scale)
	voice.free()
	return err


## The chew ring sweeps; it does not shrink (plant-tower-defense-xej7).
##
## It used to do the opposite, and the opposite is backwards: a shrinking ring is
## smallest exactly when its news is most urgent, and `Node2D` paints below its
## children so the last of it vanished behind the flower's own sprite. `HuskLayer`
## has always done it the other way — fixed radius, swept angle — and this pins that
## the Chomp now speaks the same vocabulary.
##
## Asserted through `chew_arc_end`, which is what `_draw` reads. The radius is a
## constant now, so "it does not vary with progress" is a claim about the DRAW SITE
## rather than about a function; what a headless test can hold is that the constant
## exists and the sweep is the only thing moving.
func test_the_chew_ring_sweeps_rather_than_shrinking() -> String:
	var full: float = ChompFlower.chew_arc_end(0.0)
	var err: String = _T.assert_float_eq(full, TAU, 0.0001,
		"a mouth that just closed shows the whole ring, got %.4f" % full)
	if err == "":
		# Strictly monotone down across the whole chew, which is the half a single
		# before/after pair cannot see.
		var previous: float = full
		for i: int in range(1, 21):
			var here: float = ChompFlower.chew_arc_end(float(i) / 20.0)
			err = _T.assert_true(here < previous,
				"the sweep only ever closes; at %d%% it went %.4f -> %.4f"
					% [i * 5, previous, here])
			if err != "":
				return err
			previous = here
	if err == "":
		err = _T.assert_float_eq(ChompFlower.chew_arc_end(1.0), 0.0, 0.0001,
			"and an emptied mouth draws nothing at all")
	if err == "":
		# Legible near the end, in PIXELS rather than in radians — an assertion
		# written in the units of the thing under test passes when the thing is
		# zeroed, which is how a mutation survived in cycle 71. At 90% chewed the
		# remaining arc must still be a mark a player can see.
		var tail_px: float = ChompFlower.chew_arc_end(0.9) * ChompFlower.CHEW_RING_RADIUS
		err = _T.assert_gte(tail_px, 8.0,
			"90%% through a chew leaves %.1f px of arc, which is the moment it matters most"
				% tail_px)
	if err == "":
		# The radius is fixed, so it must sit in the band the two neighbours leave:
		# outside the flower's head, inside the Sunflower gauge's nearest corner
		# (26.0, asserted above), inside half a cell.
		err = _T.assert_true(ChompFlower.CHEW_RING_RADIUS > 16.0
				and ChompFlower.CHEW_RING_RADIUS < 26.0,
			"the ring clears the head without reaching the gauge, got %.1f"
				% ChompFlower.CHEW_RING_RADIUS)
	if err == "":
		err = _T.assert_true(
			ChompFlower.CHEW_RING_RADIUS + ChompFlower.CHEW_RING_WIDTH * 0.5
				<= float(Board.CELL) * 0.5,
			"and stays inside its own cell, got %.1f against %d"
				% [ChompFlower.CHEW_RING_RADIUS + ChompFlower.CHEW_RING_WIDTH * 0.5,
					Board.CELL / 2])
	return err


## Every ordered pair of mutations, classified (plant-tower-defense-1d07).
##
## Three traits is nine ordered pairs and only one of them is excluded, so a single worked
## example would have proved almost nothing — and the pair that IS excluded is excluded for
## a mechanical reason rather than a balance opinion, which is the thing worth pinning.
##
## `MUTATION_ARMOURED`'s only effect on play is doubling a Chomp's chew time, and a winged
## pest cannot be grabbed by a Chomp at all. So armoured-winged is armoured in name, in
## husk payout, and in nothing else. The bead worried the pair might be UNKILLABLE; it is
## the opposite, and checking before building is what turned the design around.
##
## The traits are DERIVED from `Pest.MUTATION_HUSK_MULTIPLIER` rather than retyped
## (plant-tower-defense-xc07). That dictionary is the set `apply_mutation` will accept —
## it refuses anything without a row (`game/pest.gd:852`) — so it is the game's own answer
## to "every mutation there is", and the copy that used to sit here was a second one. The
## size assertion that used to follow the copy went with it: once the traits come out of
## the table, "the copy is as long as the table" is `n == n`, so it is replaced below by a
## floor on how much this test is allowed to shrink to.
##
## Order does not matter to anything below: the double loop visits every ordered pair
## whichever way round the traits come out, `excluded` is decided by identity rather than
## by index, and `composed` is a count. (Godot dictionaries iterate in insertion order
## anyway, so this is stable — but the test does not lean on that.)
##
## What stays hand-written is the `excluded` expression, deliberately. Deriving it from
## `Pest.MUTATION_EXCLUSIONS` would leave `mutations_compose` compared against the list
## `mutations_compose` reads, and the assertion would have one side. Someone adding a pair
## has to come here and say so, which is the point.
func test_every_mutation_pair_states_whether_it_composes() -> String:
	var traits: Dictionary = Pest.MUTATION_HUSK_MULTIPLIER
	# The denominator. An empty derivation would run zero assertions below, and a sweep
	# over nothing reads exactly like a sweep that passed.
	var err: String = _T.assert_gte(traits.size(), 3,
		"the game declares at least the three traits this test was written for, got %d"
			% traits.size())
	if err != "":
		return err
	var composed: int = 0
	for a: StringName in traits:
		for b: StringName in traits:
			var excluded: bool = (a == b) \
				or (a == Pest.MUTATION_ARMOURED and b == Pest.MUTATION_WINGED) \
				or (a == Pest.MUTATION_WINGED and b == Pest.MUTATION_ARMOURED)
			err = _T.assert_eq(Pest.mutations_compose(a, b), not excluded,
				"%s beside %s" % [a, b])
			if err != "":
				return err
			if not excluded:
				composed += 1
	# Four ordered pairs compose (hungry with each of the other two, both ways round).
	# A denominator, so an exclusion list that swallowed everything would not read clean.
	return _T.assert_eq(composed, 4,
		"four ordered pairs compose, not %d -- an exclusion list that grew silently would "
			% composed + "otherwise make this whole sweep pass over nothing")


## A second mutation composes onto the first, and the payout follows it.
func test_a_second_mutation_composes_onto_the_first() -> String:
	var pest: Pest = _pest(Pest.APHID, Vector2(50, 50))
	var err: String = _T.assert_true(pest.apply_mutation(Pest.MUTATION_HUNGRY),
		"the first trait applies")
	if err == "":
		err = _T.assert_true(pest.apply_mutation(Pest.MUTATION_WINGED),
			"and a composing second one does too")
	if err == "":
		err = _T.assert_true(pest.is_hungry and pest.is_winged,
			"both flags are live, so both mechanics are")
	if err == "":
		# The cache-and-source invariant the two fields carry.
		err = _T.assert_eq(String(pest.mutation), String(pest.mutations[0]),
			"the primary is the first applied, which is the tint the sprite wears")
	if err == "":
		err = _T.assert_float_eq(pest.husk_multiplier(),
			float(Pest.MUTATION_HUSK_MULTIPLIER[Pest.MUTATION_HUNGRY])
				* float(Pest.MUTATION_HUSK_MULTIPLIER[Pest.MUTATION_WINGED]), 0.0001,
			"and the husk pays for BOTH -- reading the primary alone would have paid for one")
	if err == "":
		err = _T.assert_false(pest.apply_mutation(Pest.MUTATION_HUNGRY),
			"the same trait twice is refused, or a payout doubles for nothing")
	if err == "":
		err = _T.assert_eq(pest.mutations.size(), 2, "and the refusal changed nothing")
	pest.free()
	return err


## The excluded pair is refused at the pest, not only at the roll.
func test_an_armoured_pest_refuses_wings_and_keeps_its_chew_time() -> String:
	var pest: Pest = _pest(Pest.BEETLE, Vector2(50, 50))
	var before: float = pest.chew_seconds
	var err: String = _T.assert_true(pest.apply_mutation(Pest.MUTATION_ARMOURED), "armoured")
	if err == "":
		err = _T.assert_float_eq(pest.chew_seconds, before * 2.0, 0.0001,
			"which is the whole of what armoured does to play")
	if err == "":
		err = _T.assert_false(pest.apply_mutation(Pest.MUTATION_WINGED),
			"and wings are refused, because they would make that doubling unreachable")
	if err == "":
		err = _T.assert_false(pest.is_winged, "the refusal left no flag behind")
	if err == "":
		err = _T.assert_float_eq(pest.husk_multiplier(),
			float(Pest.MUTATION_HUSK_MULTIPLIER[Pest.MUTATION_ARMOURED]), 0.0001,
			"nor a payout for a trait it does not carry")
	pest.free()
	return err


## A pair is late and rare (plant-tower-defense-1d07).
##
## Both ends, because "rare" without a floor is indistinguishable from "never" and this
## roll sits behind another roll, so its real frequency is a product.
func test_a_second_mutation_is_rare_and_late() -> String:
	var err: String = _T.assert_gt(WaveDirector.SECOND_MUTATION_START_WAVE,
		WaveDirector.MUTATION_START_WAVE + WaveDirector.WAVES.size() / 2,
		"pairs start a good while after single mutations do")
	if err == "":
		# The product, at the first wave they can happen and at the endless cap.
		var at_start: float = WaveDirector.mutation_chance_for(
			WaveDirector.SECOND_MUTATION_START_WAVE) * WaveDirector.SECOND_MUTATION_CHANCE
		err = _T.assert_true(at_start < 0.05,
			"a pair is under 5%% of pests when they begin, got %.3f" % at_start)
		if err == "":
			var at_cap: float = WaveDirector.MUTATION_CHANCE_MAX \
				* WaveDirector.SECOND_MUTATION_CHANCE
			err = _T.assert_true(at_cap > 0.0 and at_cap < 0.12,
				"and still an event rather than a texture at the cap, got %.3f" % at_cap)
	if err == "":
		# No pair can be scheduled before its wave, whatever the draw.
		var director := WaveDirector.new()
		director.set_seed(4242)
		director.endless = true
		director.current_wave = WaveDirector.SECOND_MUTATION_START_WAVE - 2
		director.start_next_wave()
		var paired: int = 0
		for entry: Dictionary in director._schedule:
			if (entry["mutations"] as Array).size() > 1:
				paired += 1
		err = _T.assert_eq(paired, 0, "no pair one wave early")
		if err == "":
			err = _T.assert_gt(director._schedule.size(), 10,
				"and the schedule was really populated, or that zero means nothing")
		director.free()
	return err


## A bitten plant flinches, and further than it sways (plant-tower-defense-c3h3).
##
## The third word of the standing animation ask, after sway and breathe. Every idle motion
## in this game was a continuous sinusoid, so nothing on the board was ever startled — a bed
## being eaten looked exactly like one that was not, and the only tell was a health bar the
## player has to be looking at.
##
## Asserted through `flinch_amount`, which is pure, because everything in `_wobble` past the
## `animations_enabled()` gate is unreachable headless. And the size assertion is in PIXELS:
## an assertion written as a multiple of `FLINCH_RADIANS` passes when `FLINCH_RADIANS` is
## zero, which is exactly the mutation that survived in cycle 71.
func test_a_bitten_plant_flinches_further_than_it_sways() -> String:
	var err: String = _T.assert_float_eq(Plant.flinch_amount(Plant.FLINCH_SECONDS), 1.0,
		0.0001, "the instant of a bite is full flinch")
	if err == "":
		err = _T.assert_float_eq(Plant.flinch_amount(0.0), 0.0, 0.0001,
			"and it is gone once the window closes")
	if err == "":
		# Monotone down across the whole window, which a before/after pair cannot see.
		var previous: float = 1.0
		for i: int in range(1, 17):
			var left: float = Plant.FLINCH_SECONDS * (1.0 - float(i) / 16.0)
			var here: float = Plant.flinch_amount(left)
			err = _T.assert_true(here < previous,
				"the flinch only decays; at %.3fs left it went %.3f -> %.3f"
					% [left, previous, here])
			if err != "":
				return err
			previous = here
	if err == "":
		err = _T.assert_float_eq(Plant.flinch_amount(Plant.FLINCH_SECONDS * 4.0), 1.0,
			0.0001, "and a re-arm mid-flinch is clamped rather than stacking")
	if err == "":
		# It has to out-read the idle sway or it is not a flinch, it is a mood.
		err = _T.assert_true(Plant.FLINCH_RADIANS > Plant.WOBBLE_RADIANS * 2.0,
			"a flinch is clearly bigger than the sway (%.3f vs %.3f rad)"
				% [Plant.FLINCH_RADIANS, Plant.WOBBLE_RADIANS])
	if err == "":
		# The absolute floor, in pixels, on the corner of a 64x64 sprite. Every assertion
		# above is relative to FLINCH_RADIANS and would pass with it set to 0.0.
		var swing_px: float = sin(Plant.FLINCH_RADIANS) * (float(Board.CELL) * 0.5)
		err = _T.assert_gte(swing_px, 2.0,
			"the sprite's corner actually moves, got %.2f px" % swing_px)
	if err == "":
		# And the flinch is faster than the sway, or the two read as one larger sway.
		err = _T.assert_true(Plant.FLINCH_RATE > Plant.WOBBLE_RATE * 8.0,
			"a flinch is a shake, not a lean (%.1f vs %.2f)"
				% [Plant.FLINCH_RATE, Plant.WOBBLE_RATE])
	return err


## Damage arms it; a zero-damage call does not.
##
## Same shape as the `_quiet_time` rule beside it: a 0-damage call is not a bite. Driven
## through `take_damage` and read off the field, which is the half that does not need the
## animation gate open.
func test_only_a_real_bite_arms_the_flinch() -> String:
	var plant := Plant.new()
	plant.setup(PlantCatalog.CORN, Vector2i(1, 1), null)
	var err: String = _T.assert_float_eq(plant._flinch_left, 0.0, 0.0001,
		"a freshly planted bed is not flinching")
	if err == "":
		plant.take_damage(0.0)
		err = _T.assert_float_eq(plant._flinch_left, 0.0, 0.0001,
			"a zero-damage call is not a bite -- the same rule _quiet_time follows")
	if err == "":
		plant.take_damage(3.0)
		err = _T.assert_float_eq(plant._flinch_left, Plant.FLINCH_SECONDS, 0.0001,
			"a real bite arms the whole window")
	if err == "":
		# Decays on the clock, and OUTSIDE the animations gate -- headless is exactly
		# where that gate is shut, so this pumping at all is the assertion.
		plant._wobble(Plant.FLINCH_SECONDS * 0.5)
		err = _T.assert_true(plant._flinch_left > 0.0
				and plant._flinch_left < Plant.FLINCH_SECONDS,
			"and half a window later it is half spent, got %.3f" % plant._flinch_left)
	if err == "":
		plant._wobble(Plant.FLINCH_SECONDS)
		err = _T.assert_float_eq(plant._flinch_left, 0.0, 0.0001,
			"then bottoms out at zero rather than going negative")
	if err == "":
		# A pest mid-meal calls take_damage every physics frame, so the shudder is
		# sustained rather than one twitch. This is that, expressed as a loop.
		for _i: int in range(5):
			plant.take_damage(1.0)
			plant._wobble(1.0 / 60.0)
		err = _T.assert_true(plant._flinch_left > Plant.FLINCH_SECONDS * 0.9,
			"a plant being eaten stays flinching, got %.3f" % plant._flinch_left)
	plant.free()
	return err


## A hard-won kill sounds like one (plant-tower-defense-tgoc).
##
## `Sfx.PEST_KILLED` was one event for every death: an aphid you sneezed on and a hungry
## armoured beetle that soaked four volleys arrived at the player as the same impact at the
## same volume. The game already prices that difference twice — `husk_multiplier()` pays a
## premium per trait, and cycle 74 gave the mixer a direction — so the fix is a second id
## sitting ABOVE the plain kill, not a new sound.
##
## The threshold is the pest's own price rather than a list of which mutations count, which
## is what makes a fourth mutation audible the day it is added.
func test_a_harder_kill_is_pitched_above_a_plain_one() -> String:
	var plain: float = float(Sfx.PITCH.get(Sfx.PEST_KILLED, 1.0))
	var hard: float = float(Sfx.PITCH.get(Sfx.PEST_KILLED_HARD, 1.0))
	var err: String = _T.assert_true(hard > plain,
		"a harder kill sits above the plain one (%.2f vs %.2f) -- it is a bigger gain, and "
			% [hard, plain] + "the PITCH table's rule is that gains go up")
	if err == "":
		# Modest, because a kill is the most frequent sound in the game. An absolute
		# ceiling, not a multiple of the constant: a wide interval turns a wave into a
		# melody, and "1.5x the base" would still pass at any base.
		err = _T.assert_true(hard - plain < 0.25,
			"but not by an interval you could hum, got %.2f" % (hard - plain))
	if err == "":
		# The same impact, deliberately: a hard kill is the same EVENT landing harder.
		err = _T.assert_eq(String(Sfx.SOUNDS[Sfx.PEST_KILLED_HARD]),
			String(Sfx.SOUNDS[Sfx.PEST_KILLED]),
			"and it is the same stream -- a different file would say a different thing "
				+ "happened, and what happened is a kill")
	if err == "":
		# Which means the twin check is the only thing keeping them apart. If this ever
		# fails, the two kills have collapsed into one sound.
		var voice := AudioStreamPlayer.new()
		Sfx.tune_voice(voice, Sfx.PEST_KILLED)
		var plain_db: float = voice.volume_db
		var plain_pitch: float = voice.pitch_scale
		Sfx.tune_voice(voice, Sfx.PEST_KILLED_HARD)
		err = _T.assert_true(voice.pitch_scale != plain_pitch or voice.volume_db != plain_db,
			"the composed voices differ, or the player hears one sound for both")
		voice.free()
	return err


## The threshold is the price, not a list of mutations.
##
## Reading `husk_multiplier()` rather than checking `mutations.is_empty()` is what makes a
## fourth trait audible without anyone editing `_on_pest_died`. Asserted over every trait
## the game has plus a pair, because a single example would not show that the rule scales.
##
## "Every trait the game has" is read off `Pest.MUTATION_HUSK_MULTIPLIER` rather than
## retyped (plant-tower-defense-xc07) — a third trait named here was a third place a fourth
## mutation would have to be added by hand, and the sentence above would have gone on
## claiming "every" while the sweep covered three of four. Order is irrelevant: each
## iteration builds and frees its own pest and asserts the same thing about it.
func test_every_mutation_makes_a_kill_count_as_hard() -> String:
	var plain: Pest = _pest(Pest.APHID, Vector2(50, 50))
	var err: String = _T.assert_float_eq(plain.husk_multiplier(), 1.0, 0.0001,
		"a plain pest prices at 1.0, which is what keeps it on the plain sound")
	plain.free()
	if err != "":
		return err
	# The denominator: a derivation that came back empty would skip the loop entirely and
	# still return the pair's assertions below, which is a shrunk test that reads clean.
	err = _T.assert_gte(Pest.MUTATION_HUSK_MULTIPLIER.size(), 3,
		"there are at least the three traits this sweep was written for, got %d"
			% Pest.MUTATION_HUSK_MULTIPLIER.size())
	if err != "":
		return err
	for mutation: StringName in Pest.MUTATION_HUSK_MULTIPLIER:
		var pest: Pest = _pest(Pest.BEETLE, Vector2(50, 50))
		pest.apply_mutation(mutation)
		err = _T.assert_true(pest.husk_multiplier() > 1.0,
			"%s prices above 1.0, so it reaches the harder sound" % mutation)
		pest.free()
		if err != "":
			return err
	# And a pair, which prices higher again -- the same read covers it with no extra branch.
	var paired: Pest = _pest(Pest.APHID, Vector2(50, 50))
	paired.apply_mutation(Pest.MUTATION_HUNGRY)
	paired.apply_mutation(Pest.MUTATION_WINGED)
	err = _T.assert_true(paired.husk_multiplier() > 1.5,
		"a doubly-mutated pest prices higher still, got %.2f" % paired.husk_multiplier())
	if err == "":
		err = _T.assert_eq(String(Sfx.kill_event_for(paired.husk_multiplier())),
			String(Sfx.PEST_KILLED_HARD), "and it earns the harder sound")
	paired.free()
	if err != "":
		return err
	# The DECISION, not just its input. A ternary at the call site survived a mutation that
	# routed every kill to the hard sound; this is the seam that closes it, and the boundary
	# is where the routing lives.
	err = _T.assert_eq(String(Sfx.kill_event_for(1.0)), String(Sfx.PEST_KILLED),
		"a plain pest at exactly 1.0 stays on the plain sound")
	if err == "":
		err = _T.assert_eq(String(Sfx.kill_event_for(1.0001)),
			String(Sfx.PEST_KILLED_HARD), "and anything priced above it does not")
	if err == "":
		err = _T.assert_eq(String(Sfx.kill_event_for(0.5)), String(Sfx.PEST_KILLED),
			"nor does a hypothetical discount, which would otherwise read as harder")
	return err


# -- Garden Mint: the plant that acts on plants -------------------------------


func test_mint_stacks_multiplicatively_and_floors_at_none() -> String:
	## The buff rule, pure and without a board. `pow` rather than a table, so the answer for
	## three is a real answer rather than an off-the-end guess -- and deliberately unclamped:
	## four Mints around one Corn is a silly board that costs 100 seeds and gives up four
	## shooting cells, and the game does not need a rule the player cannot see.
	var err: String = _T.assert_float_eq(Mint.scale_for(0), 1.0, 0.0001,
		"no Mint next door changes nothing")
	if err == "":
		err = _T.assert_float_eq(Mint.scale_for(1), Mint.NEIGHBOUR_SCALE, 0.0001,
			"one Mint is one multiplication")
	if err == "":
		err = _T.assert_float_eq(Mint.scale_for(2),
			Mint.NEIGHBOUR_SCALE * Mint.NEIGHBOUR_SCALE, 0.0001, "two stack")
	if err == "":
		err = _T.assert_float_eq(Mint.scale_for(-1), 1.0, 0.0001,
			"and a negative count is floored rather than inverting the buff into a curse")
	if err == "":
		err = _T.assert_true(Mint.NEIGHBOUR_SCALE < 1.0,
			"the scale is BELOW one -- an interval is the reciprocal of a rate, so a "
				+ "number above one would slow the neighbours down")
	return err


func test_mint_reaches_four_orthogonal_cells_and_no_diagonal() -> String:
	## The shape of the reach, asserted against the ring that draws it. A diagonal neighbour
	## is 90px away against a 64px cell, so a ring at Mint.REACH would not contain it -- a cue
	## that does not contain what it affects is the defect cycle 85 shipped.
	var cells: Array[Vector2i] = Mint.neighbours_of(Vector2i(3, 4))
	var err: String = _T.assert_eq(cells.size(), 4, "four neighbours, not eight")
	for cell: Vector2i in cells:
		if err != "":
			break
		var delta: Vector2i = cell - Vector2i(3, 4)
		err = _T.assert_eq(absi(delta.x) + absi(delta.y), 1,
			"%s is orthogonally adjacent" % [delta])
		if err == "":
			# The ring must actually contain the cell centre it claims.
			err = _T.assert_true(Vector2(delta * int(Board.CELL)).length() <= Mint.REACH + 0.01,
				"and the drawn ring reaches it (%.0fpx of %.0f)"
					% [Vector2(delta * int(Board.CELL)).length(), Mint.REACH])
	if err == "":
		err = _T.assert_true(Vector2(Vector2i(1, 1) * int(Board.CELL)).length() > Mint.REACH,
			"while a diagonal is outside the ring, which is why it is not a neighbour")
	return err


func test_the_weather_and_a_neighbour_compose_rather_than_overwrite() -> String:
	## `Plant.composed_interval` exists because `Game._apply_weather` ASSIGNS
	## `fire_interval_scale` for every plant on every weather change. A second source of
	## the same multiplier folded into that field would be wiped the next time the weather
	## turned, and nothing would say so -- the plants keep firing, at the wrong rate.
	##
	## So the two factors live in separate fields and meet here. Asserted as arithmetic
	## because that is what it is: the bug this prevents is a SECOND event overwriting a
	## first, and a function that multiplies its arguments cannot have that bug.
	var base: float = 0.8
	var drought: float = WaveDirector.fire_interval_scale_for(WaveDirector.WEATHER_DROUGHT)
	var err: String = _T.assert_gt(drought, 1.0,
		"a drought lengthens the interval, which is what makes it a penalty")
	if err == "":
		err = _T.assert_float_eq(Plant.composed_interval(base, 1.0, 1.0), base, 0.0001,
			"neither factor engaged leaves the base alone")
	if err == "":
		err = _T.assert_float_eq(Plant.composed_interval(base, drought, 1.0),
			base * drought, 0.0001, "weather alone is the weather's multiplier")
	if err == "":
		err = _T.assert_float_eq(Plant.composed_interval(base, 1.0, Mint.NEIGHBOUR_SCALE),
			base * Mint.NEIGHBOUR_SCALE, 0.0001, "a neighbour alone is the neighbour's")
	if err == "":
		# The case that matters: both at once, neither winning.
		err = _T.assert_float_eq(Plant.composed_interval(base, drought, Mint.NEIGHBOUR_SCALE),
			base * drought * Mint.NEIGHBOUR_SCALE, 0.0001,
			"and together they multiply -- a drought beside a Mint is slower than the Mint "
				+ "alone and faster than the drought alone, rather than one replacing the other")
	if err == "":
		err = _T.assert_true(
			Plant.composed_interval(base, drought, Mint.NEIGHBOUR_SCALE) < base * drought,
			"which is to say the buff survives the weather")
	return err


# -- The Shield Bug's plate (plant-tower-defense-4du6) -----------------------
#
# ONE SENTENCE, and it is what every assertion below is trying to pin: a Shield
# Bug's plate eats up to `shell_absorb` off each of its first `shell_hits` hits,
# so a Corn Cobbler's stream of small kernels bounces off it entirely while a
# Dandelion's bigger seed and a Chomp's mouth do not care -- which asks the player
# to change WHICH plant answers the lane rather than where they aim it.
#
# Every pest before this one differed from the others only in how much damage it
# needed, so "is my garden strong enough" was the only question the roster ever
# asked. These tests exist because that claim is a relationship between three
# files -- `Pest.SPECIES`, `CornCobbler.LEVELS` and `Dandelion.SEED_DAMAGE` -- and
# a balance pass on any one of them can quietly turn this species back into a
# beetle with nothing failing.


## The most damage a single Corn Cobbler kernel ever does, DERIVED from the level
## table rather than written down.
##
## The claim the tests below make is about every level of the cob, so a hardcoded
## 1.4 would keep passing on the day someone adds a fourth level that outguns the
## plate -- which is exactly the failure the species is designed not to have.
func _top_kernel_damage() -> float:
	var top: float = 0.0
	for level: Dictionary in CornCobbler.LEVELS:
		top = maxf(top, float(level["damage"]))
	return top


## The band `shell_absorb` was chosen to sit in, asserted against the two plants
## that define it rather than against the number in the species row.
func test_the_shield_bugs_plate_is_priced_between_a_corn_kernel_and_a_dandelion_seed() -> String:
	var absorb: float = Pest.shell_absorb(Pest.SHIELDBUG)
	var top_kernel: float = _top_kernel_damage()
	var err: String = _T.assert_gt(absorb, top_kernel,
		"the plate out-eats the BEST corn kernel in the table (%.2f vs %.2f), so no level of cob gets through it"
			% [absorb, top_kernel])
	if err == "":
		err = _T.assert_gt(Dandelion.SEED_DAMAGE, absorb,
			"and a centred dandelion seed out-hits the plate (%.2f vs %.2f), so the big shot always spills through"
				% [Dandelion.SEED_DAMAGE, absorb])
	if err == "":
		err = _T.assert_float_eq(Pest.damage_through_shell(top_kernel, absorb, 1), 0.0, 0.0001,
			"a kernel against a plate with a block left reaches nothing at all")
	if err == "":
		err = _T.assert_gt(Pest.damage_through_shell(Dandelion.SEED_DAMAGE, absorb, 1), 0.0,
			"a seed against the same plate still reaches the bug")
	if err == "":
		# The other end: with the blocks spent the function must be the identity,
		# or the plate would go on taxing a bug it has already come off.
		err = _T.assert_float_eq(Pest.damage_through_shell(top_kernel, absorb, 0), top_kernel, 0.0001,
			"and once the blocks are gone a kernel lands in full")
	return err


## The test that fails if the plate does nothing. Six kernels in a row must move
## the health bar by exactly zero, and the seventh must move it by a whole kernel.
func test_a_shield_bug_ignores_a_whole_stream_of_kernels_and_then_stops_ignoring_them() -> String:
	var bug: Pest = _pest(Pest.SHIELDBUG, Vector2.ZERO)
	var kernel: float = _top_kernel_damage()
	var blocks: int = Pest.shell_hits(Pest.SHIELDBUG)
	var err: String = _T.assert_gt(blocks, 0, "sanity: a Shield Bug spawns with a plate on")
	if err == "":
		err = _T.assert_eq(bug.shell_blocks, blocks,
			"and setup() seeded the live count straight off the species row")
	for i: int in range(blocks):
		if err != "":
			break
		bug.take_damage(kernel)
		err = _T.assert_float_eq(bug.health, bug.max_health, 0.0001,
			"kernel %d of %d bounced off entirely (health %.2f of %.2f)"
				% [i + 1, blocks, bug.health, bug.max_health])
	if err == "":
		err = _T.assert_eq(bug.shell_blocks, 0,
			"and every one of them still cost a block -- the plate counts HITS, not damage")
	if err == "":
		bug.take_damage(kernel)
		err = _T.assert_float_eq(bug.health, bug.max_health - kernel, 0.0001,
			"the next kernel lands in full, so the plate delays a cob rather than immunising against it")
	if err == "":
		err = _T.assert_true(bug.was_engaged(),
			"and a shot that achieved nothing still counts as the garden engaging this pest")
	bug.free()
	return err


## The axis the species exists for, asserted as the comparison a player actually
## makes: the same number of hits from the two plants, side by side.
func test_the_plate_costs_a_stream_of_small_shots_everything_and_a_big_shot_only_part() -> String:
	var blocks: int = Pest.shell_hits(Pest.SHIELDBUG)
	var absorb: float = Pest.shell_absorb(Pest.SHIELDBUG)
	var kernel: float = _top_kernel_damage()
	var shot: Pest = _pest(Pest.SHIELDBUG, Vector2.ZERO)
	var bombed: Pest = _pest(Pest.SHIELDBUG, Vector2(200, 0))
	for _i: int in range(blocks):
		shot.take_damage(kernel)
		bombed.take_damage(Dandelion.SEED_DAMAGE)
	var err: String = _T.assert_true(shot.is_alive() and bombed.is_alive(),
		"sanity: neither of them dies inside the plate's own lifetime, or the comparison below is measuring a corpse")
	if err == "":
		err = _T.assert_float_eq(shot.max_health - shot.health, 0.0, 0.0001,
			"%d corn kernels against the plate did nothing whatsoever" % blocks)
	if err == "":
		err = _T.assert_float_eq(bombed.max_health - bombed.health,
			float(blocks) * (Dandelion.SEED_DAMAGE - absorb), 0.0001,
			"while %d dandelion seeds each put %.2f through it" % [blocks, Dandelion.SEED_DAMAGE - absorb])
	if err == "":
		err = _T.assert_eq(shot.shell_blocks, bombed.shell_blocks,
			"and both plates are equally worn, because a block is spent per HIT -- "
				+ "that asymmetry IS the species, and a plate counting damage would not have it")
	shot.free()
	bombed.free()
	return err


## The branch must not leak. Every other species takes its damage in full, and
## exactly one row in SPECIES carries a plate at all.
func test_the_plate_belongs_to_exactly_one_species_and_leaves_the_others_alone() -> String:
	var plated: Array[StringName] = []
	for which: StringName in Pest.SPECIES:
		if Pest.shell_absorb(which) > 0.0:
			plated.append(which)
	var err: String = _T.assert_eq(plated.size(), 1,
		"exactly one species carries a plate (found %s)" % [plated])
	if err == "":
		err = _T.assert_eq(String(plated[0]), String(Pest.SHIELDBUG), "and it is the Shield Bug")
	if err == "":
		# shell_hits() reads shell_absorb() first on purpose: a row naming a hit
		# count and no amount must be unplated, not a plate that eats nothing while
		# still swallowing six of the player's shots.
		err = _T.assert_eq(Pest.shell_hits(Pest.APHID), 0,
			"an unplated species reports no blocks either, rather than a count with nothing behind it")
	for which: StringName in Pest.SPECIES:
		if err != "" or which == Pest.SHIELDBUG:
			continue
		var pest: Pest = _pest(which, Vector2.ZERO)
		pest.take_damage(1.0)
		err = _T.assert_float_eq(pest.max_health - pest.health, 1.0, 0.0001,
			"%s takes a 1.0 hit in full -- the plate branch never fires for a species without one" % which)
		pest.free()
	return err


## The legibility half. A blocked hit and a landed hit both call flash_hit(), so
## without two peaks the player watching six kernels bounce sees six ordinary hits
## and concludes the health bar is broken.
func test_a_blocked_hit_flashes_dark_where_a_landed_hit_flashes_bright() -> String:
	var base := Color(0.58, 0.66, 0.78, 0.6)  # an armoured tint, mid-fade alpha
	var blocked: Color = Pest.shell_flash_color(base)
	var landed: Color = Pest.hit_flash_color(base)
	var err: String = _T.assert_float_eq(blocked.a, base.a, 0.0001,
		"alpha is untouched, exactly as hit_flash_color leaves it")
	if err == "":
		err = _T.assert_gt(base.r, blocked.r, "a hit the plate ate dims the sprite")
	if err == "":
		err = _T.assert_gt(landed.r, base.r, "a hit that landed brightens it")
	if err == "":
		# OVERLAY_GRAMMAR.md's rule with teeth: the cue must survive its colour
		# being thrown away. These two peaks sit on opposite sides of the pest's own
		# tint in LUMINANCE, so a greyscale screenshot separates them too.
		err = _T.assert_gt(landed.get_luminance(), blocked.get_luminance(),
			"and the two peaks are still different with the colour discarded (%.3f vs %.3f)"
				% [landed.get_luminance(), blocked.get_luminance()])
	return err


## The plate must never make the free starter plant useless, only slow. Driven with
## the WEAKEST kernel in the table -- level 1, the cob every run begins with.
func test_a_single_starter_cob_can_still_kill_a_shield_bug_it_just_pays_the_plate_first() -> String:
	var kernel: float = float(CornCobbler.LEVELS[0]["damage"])
	var bug: Pest = _pest(Pest.SHIELDBUG, Vector2.ZERO)
	# Hosted rather than bare: a lethal take_damage() runs _play_death(), which
	# queue_free()s a pest that is not inside a tree -- and this test still has to
	# read is_alive() off it afterwards. Inside a tree it takes the tween path
	# instead, which headless never pumps. Same reason as
	# test_a_kernel_that_kills_its_pest_leaves_it_dead in test_selftest.gd.
	var host: Node2D = _host([bug])
	await _T.instantiate_scene(host)

	var expected: int = Pest.shell_hits(Pest.SHIELDBUG) + int(ceil(bug.max_health / kernel))
	var fired: int = 0
	while bug.is_alive() and fired < expected * 4:
		bug.take_damage(kernel)
		fired += 1
	var err: String = _T.assert_false(bug.is_alive(),
		"the starter cob's weakest kernel does eventually kill it -- the plate is a delay, never an immunity")
	if err == "":
		err = _T.assert_eq(fired, expected,
			"and the delay is exactly the plate: %d shots to strip it plus %d to kill what is under it"
				% [Pest.shell_hits(Pest.SHIELDBUG), expected - Pest.shell_hits(Pest.SHIELDBUG)])
	_T.free_ui(host)
	return err


## The endless ramp grows the bug and not the plate, which is the deliberate half
## of the design: a six-hit tax is a wall at wave 10 and a formality by wave 30,
## where a scaling one would be a trait that grows without bound.
func test_endless_wave_scaling_grows_a_shield_bug_but_never_its_plate() -> String:
	var bug: Pest = _pest(Pest.SHIELDBUG, Vector2.ZERO)
	var strength: float = bug.shell_strength
	var blocks: int = bug.shell_blocks
	var health: float = bug.max_health
	bug.apply_wave_scaling(3.0, 2.0)
	var err: String = _T.assert_float_eq(bug.max_health, health * 3.0, 0.0001,
		"health rides the endless ramp like every other species")
	if err == "":
		err = _T.assert_float_eq(bug.shell_strength, strength, 0.0001, "the plate's bite does not")
	if err == "":
		err = _T.assert_eq(bug.shell_blocks, blocks, "and neither does its hit count")
	if err == "":
		err = _T.assert_float_eq(bug.shell_strength, Pest.shell_absorb(Pest.SHIELDBUG), 0.0001,
			"which is still the value setup() read off the species row")
	bug.free()
	return err


# -- The upgrade ladder, for any plant --------------------------------------
#
# `Plant.upgrade_ladder()` and the pure statics around it, which replaced
# `selected_placed as CornCobbler` at both call sites. The tests below are in three
# groups on purpose:
#
#   * the LADDER ARITHMETIC, asserted on the statics, including the case the old
#     cob-only code never had — a plant with no ladder at all;
#   * WHO HAS ONE, enumerated over the whole catalogue, so a plant added with a
#     ladder (or without one) is decided about here rather than inheriting an answer;
#   * the CHOMP's ladder, which is the second one in the game and therefore the only
#     evidence that the surface is not shaped around the first.


## The empty ladder is the case worth having a test for: six of the seven plants in
## the catalogue answer it, and every one of the accessors has to survive it without
## a caller writing a guard. `ladder_row` indexing `ladder[-1]` is the specific bug —
## a `clampi(for_level - 1, 0, size - 1)` written straight from the cob's version does
## exactly that, and it takes the frame with it.
func test_a_plant_with_no_ladder_answers_every_upgrade_question_without_a_guard() -> String:
	var flower := Sunflower.new()
	var err: String = _T.assert_false(flower.has_upgrades(),
		"a Sunflower does not grow — this is what the Upgrade button is gated on")
	if err == "":
		err = _T.assert_eq(flower.max_level(), 1, "so its ladder is one rung long")
	if err == "":
		err = _T.assert_true(flower.is_max_level(), "and it is born at the top of it")
	if err == "":
		err = _T.assert_false(flower.can_upgrade(), "there is nothing above it to buy")
	if err == "":
		err = _T.assert_eq(flower.upgrade_cost(), 0, "so there is no price to quote")
	if err == "":
		err = _T.assert_eq(flower.level_name(), "", "and no level name to print")
	if err == "":
		err = _T.assert_eq(flower.upgrade_spent(), 0, "an uproot forfeits nothing")
	if err == "":
		err = _T.assert_true(flower.level_row().is_empty(),
			"and the stat lookup hands back an empty row rather than indexing off the end")
	if err == "":
		err = _T.assert_false(flower.upgrade(), "upgrading it is refused")
	if err == "":
		err = _T.assert_eq(flower.level, 1, "and changed nothing when it was")
	flower.free()
	return err


## The arithmetic, on the statics, at both ends and past both ends. `ladder_row` is
## reached by every stat lookup in every upgradeable plant, so a level that has run
## off either end of the table has to land on a row rather than on a crash.
func test_the_ladder_statics_clamp_at_both_ends_and_price_the_top_at_nothing() -> String:
	var ladder: Array[Dictionary] = CornCobbler.LEVELS
	var none: Array[Dictionary] = []
	var err: String = _T.assert_eq(Plant.ladder_level_name(ladder, 0),
		String(ladder[0]["name"]), "level 0 reads the bottom row rather than the last one")
	if err == "":
		err = _T.assert_eq(Plant.ladder_level_name(ladder, 99),
			String(ladder[ladder.size() - 1]["name"]), "and a level past the top reads the top row")
	if err == "":
		err = _T.assert_true(Plant.ladder_row(none, 1).is_empty(),
			"an empty ladder has no rows to read")
	if err == "":
		err = _T.assert_eq(Plant.ladder_level_name(none, 1), "", "and no names")
	if err == "":
		err = _T.assert_eq(Plant.ladder_upgrade_cost(none, 1), 0, "and nothing to sell")
	if err == "":
		err = _T.assert_eq(Plant.ladder_spend(none, 3), 0, "and nothing sunk into it")
	if err == "":
		err = _T.assert_eq(Plant.ladder_upgrade_cost(ladder, ladder.size()), 0,
			"the top of a real ladder is priced at nothing too — there is no rung above it")
	if err == "":
		err = _T.assert_eq(Plant.ladder_spend(ladder, 1), 0, "nothing is sunk into a level-1 plant")
	if err == "":
		err = _T.assert_eq(Plant.ladder_spend(ladder, 2), int(ladder[0]["upgrade_cost"]),
			"one rung up is one payment")
	return err


## The shim and the general case cannot drift.
##
## `CornCobbler.upgrade_spend(for_level)` survives as a static because `Hud.message_corpus`
## asks the CLASS for the ladder's maximum, which no instance can answer. That leaves two
## functions computing one number, which is the shape this project has been bitten by
## before (`spread_for` versus the `spread_degrees` column), so it is pinned rather than
## trusted — swept over every level plus one past the top.
func test_the_cobs_own_spend_static_is_the_generic_one() -> String:
	var err: String = ""
	for level: int in range(1, CornCobbler.LEVELS.size() + 2):
		err = _T.assert_eq(CornCobbler.upgrade_spend(level),
			Plant.ladder_spend(CornCobbler.LEVELS, level),
			"level %d: the cob's static and Plant.ladder_spend agree" % level)
		if err != "":
			return err
	return _T.assert_eq(CornCobbler.upgrade_spend(CornCobbler.LEVELS.size()), 65,
		"and the cob's ladder still totals the 20 + 45 the uproot prompt quotes")


## Which plants grow, named exactly, over the catalogue the game can actually build.
##
## Built through `Game.new_plant` rather than through a list of classes written here,
## because the question is about what a PLACED plant does and `new_plant`'s match is
## what decides that (test_placement has three tests about that match alone). A plant
## added to `PlantCatalog` therefore reaches this test whether or not anyone remembers
## it exists — and has to be decided about here, positively, like
## `test_every_plant_that_can_touch_a_pest_is_named_as_one` a few hundred lines up.
##
## Deliberately NOT derived from a key in `PlantCatalog`: the ladder is a const in the
## class whose behaviour reads it, so "does this plant grow" has exactly one answer and
## a catalogue key would be a second one that a table edit could falsify.
func test_exactly_two_plants_in_the_catalogue_grow_and_the_rest_are_born_finished() -> String:
	var game := await _T.instantiate_scene("res://game/game.tscn") as Game
	var upgradeable: Array[StringName] = []
	var err: String = ""
	for id: StringName in PlantCatalog.ids():
		var plant: Plant = Game.new_plant(id)
		if plant == null:
			err = "Game.new_plant built nothing for %s" % id
			break
		if plant.has_upgrades():
			upgradeable.append(id)
			# Every row of every ladder in the game, checked where the ladders are
			# enumerated rather than in each plant's own test: a row missing "name"
			# prints an empty level in the selection panel, and a row missing
			# "upgrade_cost" is a free upgrade.
			for row: Dictionary in plant.upgrade_ladder():
				if not row.has("name") or String(row["name"]) == "":
					err = "%s has a ladder row with no name" % id
				elif not row.has("upgrade_cost"):
					err = "%s has a ladder row that does not say what the next one costs" % id
			var top: int = plant.upgrade_ladder().size()
			if err == "" and Plant.ladder_upgrade_cost(plant.upgrade_ladder(), top) != 0:
				err = "%s prices a rung above its own top level" % id
		plant.free()
		if err != "":
			break
	if err == "":
		# THREE since plant-tower-defense-4u74. Decided here rather than inherited: the
		# Barrier Bramble is the first RECURRING cost in the game -- it is consumed by
		# doing its job -- so "spend more on this one so you replace it less often" is a
		# seed sink the economy did not previously offer anywhere. Its rungs buy
		# RESISTANCE, not health, so the Salve Aloe behind the wall scales with the
		# upgrade instead of being diluted by it.
		err = _T.assert_eq(upgradeable.size(), 3,
			("three plants in this catalogue grow, and the list below says which — got %s. "
			+ "A new id missing from Game.new_plant's match falls through to a CornCobbler "
			+ "and arrives here wearing the cob's ladder, so check that arm before the ladder")
				% str(upgradeable))
	if err == "":
		err = _T.assert_true(upgradeable.has(PlantCatalog.CORN),
			"the Corn Cobbler, whose ladder the design doc draws")
	if err == "":
		err = _T.assert_true(upgradeable.has(PlantCatalog.CHOMP),
			"and the Chomp Flower, which is the second one and the proof the surface is generic")
	_T.free_ui(game)
	return err


# -- The Chomp Flower's ladder ----------------------------------------------


## Monotone in both columns, which is what makes "an upgrade can never lose" true for
## this plant the way `KERNEL_STEP_DEGREES` makes it true for the cob. Also pins level
## 1 to the flower that shipped: the table holds SCALES, so this is arithmetic rather
## than a promise, and a hand-typed absolute would be exactly the drift it prevents.
func test_the_chomp_ladder_only_ever_reaches_further_and_chews_faster() -> String:
	var err: String = _T.assert_float_eq(ChompFlower.grab_radius_for(1), ChompFlower.GRAB_RADIUS,
		0.0001, "level 1 is the flower that shipped, exactly")
	if err == "":
		err = _T.assert_float_eq(ChompFlower.chew_seconds_for(1, 2.6), 2.6, 0.0001,
			"and takes exactly as long over a beetle as it always did")
	if err != "":
		return err
	for level: int in range(2, ChompFlower.LEVELS.size() + 1):
		err = _T.assert_gt(ChompFlower.grab_radius_for(level),
			ChompFlower.grab_radius_for(level - 1),
			"level %d closes on something level %d let past" % [level, level - 1])
		if err == "":
			err = _T.assert_gt(ChompFlower.chew_seconds_for(level - 1, 2.6),
				ChompFlower.chew_seconds_for(level, 2.6),
				"and gives the lane back sooner than level %d does" % [level - 1])
		if err != "":
			return err
	return _T.assert_true(
		ChompFlower.grab_radius_for(ChompFlower.LEVELS.size()) < Board.CELL * 2.0,
		"and the top of the ladder still only covers the lane it is beside (%.1f px)"
			% ChompFlower.grab_radius_for(ChompFlower.LEVELS.size()))


## The reach half, through `_act` rather than through the number — the seam is only
## worth anything if the grab actually reads it. One pest each, at the same distance,
## which is a distance the bud cannot reach and the gaping mouth can.
func test_a_gaping_chomp_grabs_a_pest_the_bud_lets_walk_past() -> String:
	var gap: float = 80.0
	var bud := ChompFlower.new()
	var gaping := ChompFlower.new()
	gaping.level = ChompFlower.LEVELS.size()
	# Both offsets along the pest's own heading (+X) rather than across it, so `gap` is
	# still exactly the distance this test is about AND clears `GRAB_LEAD` — which a
	# purely sideways offset never can, however far away it is.
	var near: Pest = _pest(Pest.APHID, Vector2(gap, 0))
	var far: Pest = _pest(Pest.APHID, Vector2(gap, 2.0 * gap))
	var host: Node2D = _host([bud, gaping, near, far])
	await _T.instantiate_scene(host)
	# Two flowers rather than one upgraded between the two reads: a mouth that has
	# already closed on something stays closed, so a single flower would answer the
	# second question with the first question's meal.
	gaping.position = Vector2(0, 2.0 * gap)
	# `Plant._physics_process` feeds `_act` the whole "pests" GROUP, which is
	# tree-global — so an ambient frame would let either flower grab either pest and
	# the reads below would be about whatever the settle happened to do. Every `_act`
	# in this test is called by hand, with the one pest it is a question about.
	bud.set_physics_process(false)
	gaping.set_physics_process(false)

	var err: String = _T.assert_true(gap > ChompFlower.grab_radius_for(1)
			and gap < ChompFlower.grab_radius_for(ChompFlower.LEVELS.size()),
		"%.0f px is between the two reaches, which is the only distance this test says anything at"
			% gap)
	if err == "":
		var for_bud: Array[Pest] = [near]
		bud._act(0.016, for_bud)
		err = _T.assert_false(bud.is_busy(), "the bud cannot reach it")
	if err == "":
		var for_gaping: Array[Pest] = [far]
		gaping._act(0.016, for_gaping)
		err = _T.assert_true(gaping.is_busy(),
			"and the gaping mouth closes on a pest at the same distance")
	if err == "":
		# The instance accessor by name, not only through `_act`. Both flowers, so a
		# `grab_radius()` that ignored `level` and returned the constant would fail
		# here even though the grab above happened to succeed.
		err = _T.assert_float_eq(bud.grab_radius(), ChompFlower.GRAB_RADIUS, 0.0001,
			"a bud answers the catalogue's reach")
	if err == "":
		err = _T.assert_gt(gaping.grab_radius(), bud.grab_radius(),
			"and an upgraded flower answers a longer one")
	_T.free_ui(host)
	return err


## The chew half, through `_grab` and `_chew` rather than through the number.
func test_a_gaping_chomp_gives_the_lane_back_before_a_bud_would() -> String:
	var beetle_chew: float = float(Pest.SPECIES[Pest.BEETLE]["chew_seconds"])
	var bud := ChompFlower.new()
	var gaping := ChompFlower.new()
	gaping.level = ChompFlower.LEVELS.size()
	var one: Pest = _prey(Pest.BEETLE, Vector2.ZERO)
	var two: Pest = _prey(Pest.BEETLE, Vector2(0, 400))
	var host: Node2D = _host([bud, gaping, one, two])
	await _T.instantiate_scene(host)
	gaping.position = Vector2(0, 400)
	# Same reason as the reach test above: the group `_physics_process` reads is
	# tree-global, and both beetles are in it.
	bud.set_physics_process(false)
	gaping.set_physics_process(false)

	var step: float = ChompFlower.chew_seconds_for(ChompFlower.LEVELS.size(), beetle_chew) + 0.01
	var for_bud: Array[Pest] = [one]
	var for_gaping: Array[Pest] = [two]
	bud._act(0.016, for_bud)
	gaping._act(0.016, for_gaping)
	var err: String = _T.assert_true(bud.is_busy() and gaping.is_busy(),
		"both mouths closed on a beetle")
	if err == "":
		bud._act(step, for_bud)
		gaping._act(step, for_gaping)
		err = _T.assert_false(gaping.is_busy(), "the gaping mouth has swallowed it and is free")
	if err == "":
		err = _T.assert_true(bud.is_busy(),
			"while the bud is still chewing the same beetle %.2fs in" % step)
	if err == "":
		# THE DIFFERENCE IS A NUMBER, and that is the bite rework rather than a weakened
		# claim. A beetle has 16 health against a meal worth `meal_damage()`, so BOTH
		# survive: the Chomp is a body blocker above that line and always was described as
		# one -- what changed is that it now actually is. So what the faster mouth bought
		# is a lane given back sooner and a beetle that walks out already chewed, while the
		# bud is still holding its own with fewer bites in it.
		err = _T.assert_false(ChompFlower.dies_in_the_mouth(
			float(Pest.SPECIES[Pest.BEETLE]["health"])),
			"a beetle is a meal the mouth cannot finish, which is what this pair measures")
	if err == "":
		err = _T.assert_true(one.is_alive() and two.is_alive(),
			"neither beetle is eaten -- above meal_damage the Chomp buys time, not a kill")
	if err == "":
		err = _T.assert_gt(one.health, two.health,
			("the beetle the gaping mouth finished with is %.1f health down where the"
				+ " bud's is only %.1f -- the difference the upgrade bought, in the units"
				+ " it is now paid in") % [two.max_health - two.health,
					one.max_health - one.health])
	_T.free_ui(host)
	return err


## The one balance claim in the ladder, named with the number it is measured against.
##
## `Pest.SPECIES[QUEEN]`'s 11-second chew is documented at `game/pest.gd:145` as the
## whole trade for eating a queen: the mouth is shut for the rest of the wave. A chew
## scale that bought that out would be an upgrade deleting a mechanic rather than
## improving a plant, so the floor is asserted here where the ladder can be retuned.
func test_a_queen_still_shuts_even_a_gaping_mouth_for_most_of_a_wave() -> String:
	var queen: float = float(Pest.SPECIES[Pest.QUEEN]["chew_seconds"])
	var err: String = _T.assert_float_eq(queen, 11.0, 0.0001,
		"the queen's chew is the 11s game/pest.gd:145 does its arithmetic on")
	if err == "":
		var top: float = ChompFlower.chew_seconds_for(ChompFlower.LEVELS.size(), queen)
		err = _T.assert_gt(top, 7.0,
			"a fully grown Chomp is still shut for %.1fs after eating her — the trade survives the ladder"
				% top)
	return err


## The crown's count and its nesting. Level 1 wears none, and every level's teeth are
## every lower level's teeth plus one pair further out — the readout may grow, it may
## never rearrange, which is the rule `CornCobbler.KERNEL_STEP_DEGREES` exists for.
func test_the_fang_crown_adds_a_pair_per_level_and_never_moves_the_teeth_below() -> String:
	var err: String = _T.assert_eq(ChompFlower.fang_points(1).size(), 0,
		"a plain flower wears no crown at all — an unupgraded plant is not decorated")
	if err != "":
		return err
	for level: int in range(2, ChompFlower.LEVELS.size() + 1):
		var here: PackedFloat32Array = ChompFlower.fang_offsets(level)
		var below: PackedFloat32Array = ChompFlower.fang_offsets(level - 1)
		err = _T.assert_eq(here.size(), 2 * (level - 1),
			"level %d wears %d teeth" % [level, 2 * (level - 1)])
		if err == "":
			err = _T.assert_eq(ChompFlower.fang_points(level).size(), here.size(),
				"and draws one per angle")
		if err != "":
			return err
		for was: float in below:
			var kept: bool = false
			for now: float in here:
				if absf(now - was) < 0.0001:
					kept = true
			err = _T.assert_true(kept,
				"level %d still wears the tooth level %d had at %.1f deg"
					% [level, level - 1, rad_to_deg(was)])
			if err != "":
				return err
	return err


## The crown's geometry, against the three things it has to clear. Every one of these
## is a way for the cue to be invisible rather than wrong, which is the failure mode a
## screenshot catches and a passing test does not.
func test_the_fang_crown_clears_the_sprite_the_chew_ring_and_its_own_cell() -> String:
	var inner: float = ChompFlower.FANG_RADIUS - ChompFlower.FANG_SIZE - ChompFlower.FANG_RIM_WIDTH
	var outer: float = ChompFlower.FANG_RADIUS + ChompFlower.FANG_SIZE + ChompFlower.FANG_RIM_WIDTH
	# The petal ring: ellipses centred 17 px out with ry 6 and a 2 px stroke. Node2D
	# paints _draw() BELOW its children, so a tooth inside this is not dim, it is gone.
	var petals: float = 24.0
	var err: String = _T.assert_gt(inner, petals,
		"a tooth's inner edge (%.1f) is outside the petal ring (%.1f) — Node2D paints _draw() under the sprite"
			% [inner, petals])
	if err == "":
		err = _T.assert_gt(inner, ChompFlower.CHEW_RING_RADIUS + ChompFlower.CHEW_RING_WIDTH * 0.5,
			"and outside the chew ring, so the level readout and the meal readout never share a pixel")
	if err == "":
		err = _T.assert_gt(float(Board.CELL) * 0.5, outer,
			"and inside its own cell (%.1f px against %d)" % [outer, Board.CELL / 2])
	if err != "":
		return err
	for level: int in range(1, ChompFlower.LEVELS.size() + 1):
		for tooth: Vector2 in ChompFlower.fang_points(level):
			err = _T.assert_float_eq(tooth.length(), ChompFlower.FANG_RADIUS, 0.001,
				"every tooth sits on the crown's own radius")
			if err == "":
				# The two leaves are drawn at 55 and 125 degrees, i.e. below the middle,
				# and reach r = 31 — the only part of this sprite that would swallow a
				# tooth this far out.
				err = _T.assert_true(tooth.y < 0.0,
					"and in the top half, clear of the leaves (level %d, tooth at %.1f, %.1f)"
						% [level, tooth.x, tooth.y])
			if err != "":
				return err
	return err


## The instance surface on the second plant that has one — the same walk the cob's
## `test_upgrading_stops_at_the_top_and_costs_nothing_there` takes, on a Chomp, because
## a generic ladder that only works for the class it was extracted from is not generic.
func test_a_chomp_climbs_its_ladder_and_stops_at_the_top() -> String:
	var chomp := ChompFlower.new()
	var err: String = _T.assert_true(chomp.has_upgrades(), "a Chomp grows")
	if err == "":
		err = _T.assert_eq(chomp.level_name(), "bud", "and starts as a bud")
	if err == "":
		err = _T.assert_eq(chomp.upgrade_spent(), 0, "with nothing sunk into it yet")
	if err == "":
		err = _T.assert_gt(chomp.upgrade_cost(), 0, "and a price on the next rung")
	var climbed: int = 0
	var paid: int = 0
	# Bounded by the counter it already keeps, for the reason the cob's twin in
	# test_placement.gd now is: `can_upgrade()` belongs to the code under test, so a defect
	# there hangs the suite instead of failing it (plant-tower-defense-4uts).
	while err == "" and chomp.can_upgrade() and climbed < ChompFlower.LEVELS.size() + 2:
		paid += chomp.upgrade_cost()
		if not chomp.upgrade():
			err = "upgrade() refused a rung can_upgrade() had just offered"
		climbed += 1
	if err == "":
		err = _T.assert_eq(climbed, ChompFlower.LEVELS.size() - 1, "the ladder terminates")
	if err == "":
		err = _T.assert_eq(chomp.level_name(), "gaping maw", "at a gaping maw")
	if err == "":
		err = _T.assert_eq(chomp.upgrade_cost(), 0, "which has no price to quote")
	if err == "":
		err = _T.assert_eq(chomp.upgrade_spent(), paid,
			"and forfeits, on an uproot, exactly what was paid into it")
	if err == "":
		err = _T.assert_false(chomp.upgrade(), "and refuses to grow further")
	chomp.free()
	return err


## The same guard the cob has, on the flourish this plant added. Headless is always
## animations-off, so a Tween queued here would never run — and the level, the reach,
## the chew scale and the crown all have to be right without it.
func test_a_headless_chomp_upgrade_does_not_queue_a_flourish_tween() -> String:
	var chomp := ChompFlower.new()
	chomp.setup(PlantCatalog.CHOMP, Vector2i(0, 0), null)
	var host: Node2D = _host([chomp])
	await _T.instantiate_scene(host)
	var before: Vector2 = chomp._sprite.scale
	var err: String = _T.assert_true(chomp.upgrade(), "the upgrade itself still lands")
	if err == "":
		err = _T.assert_eq(chomp.level, 2, "and the level moved")
	if err == "":
		err = _T.assert_eq(chomp._sprite.scale, before,
			"no new Tween was queued -- animations_enabled() is false headless")
	_T.free_ui(host)
	return err


# -- Directional attack animations (plant-tower-defense-v104) ----------------
#
# The designer's note asked for "better attack animations for chomp flower and prickly
# nettle". Both were ~0.15s of uniform whole-sprite scale, which is symmetric: a Chomp
# biting a beetle on its left and one on its right drew the same picture, and so did a
# Nettle stinging nothing at all while a cob three cells away landed a kernel. What both
# gained is a DIRECTION -- a lunge, a lean, a fan of spokes -- and a direction is the one
# thing about an animation that can be flatly wrong while still rendering as a perfectly
# plausible frame. That is this project's documented 2D-placement failure mode, so every
# check below asserts the VECTOR, never that something merely moved.
#
# All of it lives past `GardenTheme.animations_enabled()`, which is false for every test
# in this suite by construction, so the composition was pulled out into pure statics
# (`ChompFlower.lunge_offset`, `Nettle.sting_lean_skew`, `Nettle.spark_spoke_ends`) and
# recorded into fields written ABOVE the gate (`_bite_lunge`, `_sting_lean`,
# `_spark_ends`). The seam tests below assert the arithmetic; the reach tests drive the
# real attack path (`_grab`, `_sting`) and assert the recorded field, so deleting the
# composition from the attack goes red instead of silently aiming at the origin.


## Every side, not just one: a sign error that happens to be right for a pest on the
## right is wrong for the other three, and one sample cannot tell them apart.
func test_a_chomps_lunge_points_at_the_meal_from_every_side() -> String:
	var flower := Vector2(300.0, 200.0)
	var meals: Dictionary = {
		"right": flower + Vector2(64.0, 0.0),
		"left": flower + Vector2(-64.0, 0.0),
		"below": flower + Vector2(0.0, 71.0),
		"above": flower + Vector2(0.0, -71.0),
		"down-left": flower + Vector2(-40.0, 55.0),
	}
	var err: String = ""
	for side: String in meals:
		var meal: Vector2 = meals[side]
		var lunge: Vector2 = ChompFlower.lunge_offset(flower, meal)
		var toward: Vector2 = (meal - flower).normalized()
		err = _T.assert_float_eq(lunge.length(), ChompFlower.LUNGE_DISTANCE, 0.001,
			"a %s meal is lunged at by exactly LUNGE_DISTANCE, got %.3f"
				% [side, lunge.length()])
		if err != "":
			break
		# The direction assertion proper: a unit-length dot of 1.0 is "the same way", and
		# nothing else scores 1.0 -- a lunge pointing away scores -1, a perpendicular one 0.
		err = _T.assert_float_eq(lunge.normalized().dot(toward), 1.0, 0.0001,
			"and points AT it, not away or across (%s: lunge %s, toward %s)"
				% [side, lunge, toward])
		if err != "":
			break
	if err == "":
		# Under half a cell, so a lunging flower never draws itself into its neighbour's
		# square -- LUNGE_DISTANCE's own header states this and nothing executed it.
		err = _T.assert_true(ChompFlower.LUNGE_DISTANCE < Board.CELL * 0.5,
			"and the lunge stays inside the flower's own cell (%.1f vs %.1f)"
				% [ChompFlower.LUNGE_DISTANCE, Board.CELL * 0.5])
	if err == "":
		# `_nearest_free_pest` accepts a pest at distance 0, so this input is reachable
		# and a normalize() on it would be a NaN riding into a Tween.
		err = _T.assert_eq(ChompFlower.lunge_offset(flower, flower), Vector2.ZERO,
			"a meal already on top of the flower is lunged at nowhere, not at NaN")
	return err


## The reach half: the real grab path composes the lunge, whatever the animation gate says.
func test_a_chomps_bite_records_a_lunge_toward_the_meal() -> String:
	var chomp := ChompFlower.new()
	chomp.setup(PlantCatalog.CHOMP, Vector2i(0, 0), null)
	chomp.position = Vector2.ZERO
	# Left and slightly up, so a sign error on either axis is a different answer.
	#
	# Spawned OUT of reach and walked in afterwards. `instantiate_scene` pumps
	# settle frames, `_act()` runs on every one of them, and a Chomp with a meal
	# already in range eats it during the settle -- so the precondition below read
	# a lunge of (-6.615, -2.290), which is this exact aphid at full
	# LUNGE_DISTANCE. The plant was right and the assertion was wrong: there is no
	# "has not bitten anything" state for a flower sitting on top of its lunch.
	var aphid: Pest = _pest(Pest.APHID, Vector2(-2000.0, -18.0))
	var host: Node2D = _host([chomp, aphid])
	await _T.instantiate_scene(host)
	var err: String = _T.assert_eq(chomp._bite_lunge, Vector2.ZERO,
		"a flower that has not bitten anything is not mid-lunge")
	aphid.position = Vector2(-52.0, -18.0)
	if err == "":
		# The real path: _grab() is what _act() calls, and _bite() is inside it.
		chomp._grab(aphid)
		err = _T.assert_true(chomp.is_busy(), "the grab landed")
	if err == "":
		var toward: Vector2 = (aphid.global_position - chomp.global_position).normalized()
		err = _T.assert_float_eq(chomp._bite_lunge.normalized().dot(toward), 1.0, 0.0001,
			"and the bite recorded a lunge at the aphid (%s, toward %s)"
				% [chomp._bite_lunge, toward])
	if err == "":
		err = _T.assert_float_eq(chomp._bite_lunge.length(), ChompFlower.LUNGE_DISTANCE,
			0.001, "at full LUNGE_DISTANCE, got %.3f" % chomp._bite_lunge.length())
	_T.free_ui(host)
	return err


## The gate, on the tween this bead added `animations_enabled()` to.
##
## `_bite` used to guard on sprite-and-tree only while `_on_upgraded` beside it guarded on
## all three, and `_on_upgraded`'s header claimed to be gated "exactly as every cosmetic
## Tween in this class" -- a sentence one function in the same file falsified. The lunge is
## the reason to settle it rather than leave it: the tween now owns `_sprite.position`, and
## a queued-but-never-stepped position Tween on a headless run is a sprite that is not
## where the rest of the suite reads it.
func test_a_headless_chomp_bite_queues_no_lunge_tween() -> String:
	var chomp := ChompFlower.new()
	chomp.setup(PlantCatalog.CHOMP, Vector2i(0, 0), null)
	var beetle: Pest = _pest(Pest.BEETLE, Vector2(48.0, 0.0))
	var host: Node2D = _host([chomp, beetle])
	await _T.instantiate_scene(host)
	var was_at: Vector2 = chomp._sprite.position
	var was_scaled: Vector2 = chomp._sprite.scale
	chomp._grab(beetle)
	var err: String = _T.assert_eq(chomp._sprite.position, was_at,
		"the sprite is still home -- animations_enabled() is false headless")
	if err == "":
		err = _T.assert_eq(chomp._sprite.scale, was_scaled,
			"and unsquashed, the same gate the upgrade flourish has always had")
	if err == "":
		# And the half that is NOT cosmetic still happened, which is the whole point of
		# composing above the gate rather than inside the tween.
		err = _T.assert_true(chomp._bite_lunge != Vector2.ZERO,
			"while the lunge VECTOR was still composed, gate or no gate")
	_T.free_ui(host)
	return err


## Which side, and how much: a sign flip here aims the plant at nobody and still renders.
func test_a_nettle_leans_at_the_side_its_victim_is_on() -> String:
	var plant := Vector2(120.0, 400.0)
	# Godot skews about the local Y axis, so a point at (0, -h) moves to (+h*sin, ...):
	# positive skew leans the sprite's TOP to the right. This asserts the screen, not a
	# convention -- see Nettle.sting_lean_skew's header for the derivation.
	var right: float = Nettle.sting_lean_skew(plant, plant + Vector2(64.0, 0.0))
	var err: String = _T.assert_float_eq(right, Nettle.STING_LEAN_SKEW, 0.0001,
		"a victim dead right leans the top fully right, got %.4f" % right)
	if err == "":
		var left: float = Nettle.sting_lean_skew(plant, plant + Vector2(-64.0, 0.0))
		err = _T.assert_float_eq(left, -Nettle.STING_LEAN_SKEW, 0.0001,
			"a victim dead left leans it fully left, got %.4f" % left)
	if err == "":
		# The reason this is a projection and not a sign(): a pest passing straight in
		# front has no side to lean toward, and a sign() would have snapped to a full
		# lean one pixel either way.
		var above: float = Nettle.sting_lean_skew(plant, plant + Vector2(0.0, -80.0))
		err = _T.assert_float_eq(above, 0.0, 0.0001,
			"a victim straight up gets no sideways lean at all, got %.4f" % above)
	if err == "":
		var near_right: float = Nettle.sting_lean_skew(plant, plant + Vector2(8.0, -80.0))
		err = _T.assert_true(near_right > 0.0 and near_right < Nettle.STING_LEAN_SKEW * 0.5,
			"and one barely to the right leans barely right, got %.4f" % near_right)
	if err == "":
		var degenerate: float = Nettle.sting_lean_skew(plant, plant)
		err = _T.assert_float_eq(degenerate, 0.0, 0.0001,
			"a victim on top of the plant is a lean of nothing, not a NaN")
	return err


## The spark's fan opens AWAY from the Nettle, so the burst points back at what caused it.
func test_a_nettle_spark_fans_away_from_the_plant_that_caused_it() -> String:
	var plant := Vector2(0.0, 0.0)
	var victim := Vector2(0.0, 96.0)  # straight below, so the fan must open downward
	var ends: PackedVector2Array = Nettle.spark_spoke_ends(plant, victim)
	var err: String = _T.assert_eq(ends.size(), Nettle.SPARK_SPOKES,
		"one spoke per SPARK_SPOKES")
	var mean := Vector2.ZERO
	if err == "":
		for end_point: Vector2 in ends:
			mean += end_point
			err = _T.assert_float_eq(end_point.length(), Nettle.SPARK_LENGTH, 0.001,
				"every spoke is SPARK_LENGTH long, got %.3f" % end_point.length())
			if err != "":
				break
	if err == "":
		mean /= float(ends.size())
		var toward: Vector2 = (victim - plant).normalized()
		# The direction assertion: the fan's own bisector, not "some spoke happens to".
		err = _T.assert_float_eq(mean.normalized().dot(toward), 1.0, 0.0001,
			"and the fan's bisector runs the way the sting went (%s, toward %s)"
				% [mean, toward])
	if err == "":
		var span: float = absf(ends[ends.size() - 1].angle_to(ends[0]))
		err = _T.assert_float_eq(span, Nettle.SPARK_FAN_RADIANS, 0.0001,
			"spanning exactly SPARK_FAN_RADIANS, got %.4f" % span)
	if err == "":
		# Rotating the victim rotates the whole fan -- the geometry is not baked to one axis.
		var sideways: PackedVector2Array = Nettle.spark_spoke_ends(plant, Vector2(96.0, 0.0))
		var side_mean := Vector2.ZERO
		for end_point: Vector2 in sideways:
			side_mean += end_point
		err = _T.assert_float_eq(side_mean.normalized().dot(Vector2.RIGHT), 1.0, 0.0001,
			"and a victim to the right gets a fan opening right, got %s" % side_mean)
	return err


## The reach half for the Nettle: the real sting path composes both directions and, gate
## shut, spawns no spark and leaves the sprite unsheared.
func test_a_nettle_sting_records_the_direction_it_went() -> String:
	var nettle := Nettle.new()
	nettle.setup(PlantCatalog.NETTLE, Vector2i(0, 0), null)
	nettle.position = Vector2.ZERO
	# Out of reach for the settle frames, then walked in -- same reason as the
	# Chomp lunge test above: `_act()` runs on every settle frame, so a Nettle
	# with an armoured beetle already in range stings it before the precondition
	# is read, and the "has not stung" assertion saw a lean of 0.1703.
	var victim: Pest = _pest(Pest.BEETLE, Vector2(2000.0, 24.0))
	victim.apply_mutation(Pest.MUTATION_ARMOURED)
	var host: Node2D = _host([nettle, victim])
	await _T.instantiate_scene(host)
	var err: String = _T.assert_true(Nettle.can_sting(victim),
		"the victim is one this plant will actually fight")
	if err == "":
		err = _T.assert_float_eq(nettle._sting_lean, 0.0, 0.0001,
			"a Nettle that has not stung is not leaning")
	victim.position = Vector2(70.0, 24.0)
	if err == "":
		# The real path -- _act() calls exactly this once a target clears the filter.
		nettle._sting(victim)
		# Right and below, so the lean is positive and strictly under the full amount.
		err = _T.assert_true(nettle._sting_lean > 0.0,
			"the sting leaned toward a victim on the right, got %.4f" % nettle._sting_lean)
	if err == "":
		err = _T.assert_true(nettle._sting_lean < Nettle.STING_LEAN_SKEW,
			"and only partly, since the victim is off-axis, got %.4f" % nettle._sting_lean)
	if err == "":
		err = _T.assert_eq(nettle._spark_ends.size(), Nettle.SPARK_SPOKES,
			"and the spark geometry was composed too")
	if err == "":
		var mean := Vector2.ZERO
		for end_point: Vector2 in nettle._spark_ends:
			mean += end_point
		var toward: Vector2 = (victim.global_position - nettle.global_position).normalized()
		err = _T.assert_float_eq(mean.normalized().dot(toward), 1.0, 0.0001,
			"pointing the way the sting actually went (%s, toward %s)" % [mean, toward])
	if err == "":
		# The gate: nothing was drawn and nothing was added to the tree headless, which is
		# also the check that a spark cannot accumulate on a plant that stings all game.
		err = _T.assert_eq(nettle.get_node_or_null("PrickleSpark"), null,
			"no spark node headless -- animations_enabled() is false")
	if err == "":
		err = _T.assert_float_eq(nettle._sprite.skew, 0.0, 0.0001,
			"and no skew was applied, the same gate _sting_twitch has always had")
	if err == "":
		# The damage is the game event and is ahead of both gates, unchanged by any of this.
		err = _T.assert_true(victim.health < victim.max_health,
			"while the sting itself still landed")
	_T.free_ui(host)
	return err


# -- The Shield Bug reaches a player (plant-tower-defense-pdri) ----------------
#
# The species shipped in cycle 100 and sat in Pest.SPECIES for a cycle without
# being in a single wave -- spawnable by name, meetable by nobody. The tests above
# in "The Shield Bug's plate" pin what it DOES; these three pin that it is in the
# game at all, that it is not in it too early, and that putting it there did not
# quietly spend the campaign's last scarce budget.
#
# All three sweep the table rather than naming waves 15 and 21, so a future row
# that moves the species takes these with it instead of failing on a literal.


## Every campaign wave carrying a Shield Bug, and how many it sends. The one
## helper the three tests below share; a wave number is never written down.
func _shieldbug_waves() -> Dictionary:
	var out: Dictionary = {}
	for wave: int in range(1, WaveDirector.WAVES.size() + 1):
		var count: int = 0
		for group: Dictionary in WaveDirector.groups_for(wave):
			if StringName(group["species"]) == Pest.SHIELDBUG:
				count += int(group["count"])
		if count > 0:
			out[wave] = count
	return out


## The bead's entire point, as one assertion. A species that exists, is drawn, is
## spawnable and is fully tested is still not IN the game until the wave table
## sends one -- and nothing in the suite noticed that for a whole cycle, because
## every test of it staged its own pest.
func test_the_shield_bug_is_actually_in_a_wave_a_player_will_meet() -> String:
	var waves: Dictionary = _shieldbug_waves()
	var err: String = _T.assert_gt(waves.size(), 0,
		("no campaign wave sends a Shield Bug, so no player will ever meet one."
			+ " Pest.SPECIES holding the entry is not the same as the game containing"
			+ " the species -- see WaveDirector.WAVES"))
	if err != "":
		return err
	var total: int = 0
	for wave: int in waves.keys():
		total += int(waves[wave])
	if err == "":
		err = _T.assert_gt(total, 0, "and the rows send a positive number of them (%s)" % [waves])
	if err == "":
		# It has to be reachable by the mode most players finish in, not only by
		# endless -- `_endless_groups` sends aphids and beetles and nothing else, so
		# if the campaign ever stops carrying the species it leaves the game entirely.
		var endless_has_one: bool = false
		for group: Dictionary in WaveDirector.groups_for(WaveDirector.WAVES.size() + 1):
			if StringName(group["species"]) == Pest.SHIELDBUG:
				endless_has_one = true
		err = _T.assert_false(endless_has_one,
			("endless still sends only the swarm and the column, so the campaign is the"
				+ " ONLY place this species lives -- which is why the check above matters"))
	return err


## Not too early, which is the half that makes it a decision rather than a wall.
##
## A Corn Cobbler is the free starter and cannot scratch a plated bug at any level
## (asserted in test_the_shield_bugs_plate_is_priced_between_a_corn_kernel_and_a_dandelion_seed).
## So a Shield Bug in the opening waves is not a difficulty spike, it is a lane the
## player has no legal answer to. The rule is stated as a property of the table --
## second half only -- so it follows a table that grows again.
func test_the_shield_bug_never_lands_before_the_player_can_own_an_answer_to_it() -> String:
	var waves: Dictionary = _shieldbug_waves()
	var err: String = _T.assert_gt(waves.size(), 0,
		"there are Shield Bug waves to place (a zero here is a vacuous pass)")
	if err != "":
		return err
	var half: int = WaveDirector.WAVES.size() / 2
	var earliest: int = WaveDirector.WAVES.size() + 1
	for wave: int in waves.keys():
		err = _T.assert_gt(int(wave), half,
			("wave %d sends %d Shield Bug(s), but it is in the campaign's first half"
				+ " (<= %d). The free starter cannot damage this species at any level, so"
				+ " a plated bug before the Chomp and the Dandelion are realistically owned"
				+ " is a wall, not a decision") % [wave, int(waves[wave]), half])
		if err != "":
			return err
		earliest = mini(earliest, int(wave))
	# And past the wave mutations start, so the player is not meeting their first
	# armoured pest and their first plated one in the same breath.
	err = _T.assert_gt(earliest, WaveDirector.MUTATION_START_WAVE,
		("the debut (wave %d) is past MUTATION_START_WAVE (%d) -- two new things to read"
			+ " on one wave is the mistake cycle 101 had to undo on wave 8 itself")
			% [earliest, WaveDirector.MUTATION_START_WAVE])
	if err == "":
		# A debut of one reads as a stray, not as a species. Six blocked hits each is
		# the mechanic, and it only becomes visible when a group of them arrives.
		err = _T.assert_gt(int(waves[earliest]), 2,
			("and the debut sends a legible GROUP of them (%d) rather than a stray the"
				+ " player never identifies") % int(waves[earliest]))
	return err


## What it displaced, pinned as the decision it was.
##
## The finale is the only campaign row with no road slack (40 of 40) and it sits
## just 18.7 points of base health under the seam bound derived at
## WaveDirector.ENDLESS_BEETLE_BASE -- the campaign's scarcest resource, and the
## reason plant-tower-defense-eeaq inserted six waves in front of it rather than
## after it. Putting three plated bugs in the finale was legal and cost 8 of those
## 18.7. This asserts the choice not to, so a future cycle that spends it does so
## on purpose and reads why here.
# -- The Salve Aloe: the plant that undoes damage (plant-tower-defense-ibvb) ---


## The reach, asserted where it can FAIL.
##
## `Aloe.REACH` is 1.5 cells, chosen so the drawn ring genuinely contains the eight
## surrounding cells — a diagonal neighbour is `CELL * sqrt(2)` ~= 90.5px away and the ring
## is 96. Mint's header records refusing diagonals for the opposite reason at a one-cell
## ring, so the DIAGONAL is the case that separates a correct Aloe from one that quietly
## copied Mint's radius. A test that only checked an orthogonal neighbour would pass on both.
func test_an_aloe_reaches_its_diagonal_neighbours_and_not_the_cell_beyond() -> String:
	var here := Vector2i(4, 4)
	var err: String = _T.assert_true(Aloe.reaches(here, Vector2i(5, 4)),
		"an orthogonal neighbour is in reach")
	if err == "":
		err = _T.assert_true(Aloe.reaches(here, Vector2i(5, 5)),
			("and so is a DIAGONAL one, which is the whole reason REACH is 1.5 cells and "
				+ "not Mint's 1.0 — %.1f px against a %.1f px diagonal")
				% [Aloe.REACH, Vector2(Board.CELL, Board.CELL).length()])
	if err == "":
		err = _T.assert_false(Aloe.reaches(here, Vector2i(6, 4)),
			"two cells away is not, so the ring is a real limit rather than decoration")
	if err == "":
		err = _T.assert_false(Aloe.reaches(here, here),
			"and an Aloe does not heal itself — see reaches() for why that is not a nerf")
	return err


## The rate, and the ceiling that is the design rather than a number awaiting a buff.
##
## The second assertion is the one worth having: it pins that a single pest out-damages an
## Aloe, which is the claim the blurb makes to the player. If someone ever "fixes" the heal
## to be competitive, this is what argues back.
func test_an_aloe_mends_slower_than_one_pest_eats() -> String:
	var err: String = _T.assert_float_eq(Aloe.heal_for(1.0), Aloe.HEAL_PER_SECOND, 0.001,
		"one second of healing is one second's worth")
	if err == "":
		err = _T.assert_float_eq(Aloe.heal_for(0.5), Aloe.HEAL_PER_SECOND * 0.5, 0.001,
			"and it is proportional to delta, not a per-frame step")
	if err == "":
		err = _T.assert_float_eq(Aloe.heal_for(-1.0), 0.0, 0.001,
			"a negative delta heals nothing rather than turning a healer into a mouth")
	if err == "":
		err = _T.assert_true(Aloe.HEAL_PER_SECOND < Pest.EAT_DPS,
			("an Aloe loses the race with one pest (%.1f/s against %.1f/s) — this is the "
				+ "ceiling aloe.gd argues for, not a balance oversight")
				% [Aloe.HEAL_PER_SECOND, Pest.EAT_DPS])
	return err


## The LIVE half of this plant lives in `test_placement.gd`, not here: it needs a whole
## `game.tscn`, and this script builds bare `_host([...])` boards with no `GAME_SCENE`
## constant at all. Writing it here cost one run to learn — the parse error took the entire
## script down and the suite reported `Total: 564` against 705, which is exactly the
## denominator CLAUDE.md says to read instead of the exit code.


func test_the_shield_bug_was_paid_for_in_beetles_rather_than_out_of_the_finale() -> String:
	# TWO WAVES, and keeping them apart is the whole of what the Cutworm's row cost this
	# derivation. `campaign_end` is where the multiplier ramp finishes and the endless one
	# starts -- the seam is still WAVES.size() -> +1 and the two scales still cancel, so the
	# bound below is unmoved. `finale` is the last row whose `count x health` is COMPARABLE
	# with the first endless wave's, which is the last swarm: the solo boss row reads 1800
	# points of one body against 424 of forty, and pricing a Shield Bug's headroom against
	# that number would be measuring nothing. See `boss_solo_wave`.
	var campaign_end: int = WaveDirector.WAVES.size()
	var finale: int = WaveDirector.last_swarm_wave()
	var waves: Dictionary = _shieldbug_waves()
	var err: String = _T.assert_gt(waves.size(), 0,
		"there are Shield Bug waves to check (a zero here is a vacuous pass)")
	if err != "":
		return err
	err = _T.assert_false(waves.has(finale),
		("the finale carries a Shield Bug. It is the one row with zero road slack and"
			+ " the least health headroom in the campaign, so anything added there is"
			+ " paid for out of the seam bound -- re-derive before allowing this"))
	if err != "":
		return err

	# The headroom itself, computed the way test_economy.gd's seam test does, so the
	# two cannot disagree about what the bound is.
	var seam_health: float = 0.0
	for group: Dictionary in WaveDirector.groups_for(campaign_end + 1):
		seam_health += float(group["count"]) * float(Pest.SPECIES[group["species"]]["health"])
	var finale_health: float = 0.0
	for group: Dictionary in WaveDirector.groups_for(finale):
		finale_health += float(group["count"]) * float(Pest.SPECIES[group["species"]]["health"])
	err = _T.assert_gt(seam_health, 0.0, "the first endless wave has contents")
	if err == "":
		err = _T.assert_gt(finale_health, 0.0, "and so does the finale")
	if err != "":
		return err
	# The finale's own health scale belongs in the campaign multiplier since
	# plant-tower-defense-iqp8: the campaign no longer sits at 1.0 on that axis, and
	# omitting it inflates the bound to 725 and the headroom to 307, which would let
	# this assertion pass while measuring nothing. See health_scale_for -- the
	# endless ramp is a multiple of the campaign's last value precisely so the two
	# scales cancel here and the bound stays 436.7.
	var campaign_mult: float = (1.0 + WaveDirector.MUTATION_CHANCE * WaveDirector.MUTATION_THREAT_WEIGHT) \
		* WaveDirector.health_scale_for(campaign_end)
	var seam_mult: float = 1.0 + WaveDirector.mutation_chance_for(campaign_end + 1) \
		* WaveDirector.MUTATION_THREAT_WEIGHT
	var seam_scales: float = WaveDirector.health_scale_for(campaign_end + 1) \
		* WaveDirector.speed_scale_for(campaign_end + 1)
	var bound: float = seam_health * seam_mult * seam_scales / campaign_mult
	# Derived, not a literal 18.7: the claim is that the headroom is still worth more
	# than the thing it was NOT spent on, so the choice above stays a choice rather
	# than becoming an impossibility a later reader mistakes for one.
	var one_bug: float = float(Pest.SPECIES[Pest.SHIELDBUG]["health"])
	err = _T.assert_gt(bound - finale_health, one_bug,
		("the finale's headroom under the seam bound is %.1f points (finale %.0f, bound"
			+ " %.1f), which no longer covers even one %.0f-point Shield Bug. It measured"
			+ " 18.7 when this species was landed, and it was landed without spending any"
			+ " of it -- its waves paid for their plated bugs in beetles instead")
			% [bound - finale_health, finale_health, bound, one_bug])
	if err != "":
		return err

	# And every row that DID take one is still strictly inside the road budget, which
	# is what "paid for in beetles" has to mean to be more than a sentence.
	var checked: int = 0
	for wave: int in waves.keys():
		var peak: int = WaveDirector.peak_simultaneous_pests(int(wave))
		err = _T.assert_gt(WaveDirector.SIMULTANEOUS_PEST_CEILING, peak,
			("wave %d carries %d Shield Bug(s) and peaks at %d, strictly under the %d"
				+ " ceiling -- only the finale is allowed to land on it")
				% [wave, int(waves[wave]), peak, WaveDirector.SIMULTANEOUS_PEST_CEILING])
		if err != "":
			return err
		checked += 1
	return _T.assert_gt(checked, 0, "the per-wave sweep actually ran (%d waves)" % checked)


# -- The Nurse Beetle: the second boss (plant-tower-defense-gsai) --------------
#
# The bead's whole ask was a boss that poses a DIFFERENT question, not a bigger
# one. The queen's question is where a kill lands; the Nurse's is what the
# garden's damage is aimed at, because every damaging plant in this game shoots
# the pest furthest along the road and a healer behind the front of the queue is
# something that rule will not shoot at.
#
# So the tests below are in two halves. The first four pin the MECHANIC -- the
# rate against the plant it was priced against, the aura's exclusivity, and that
# it heals its neighbours and never itself. The last four pin that the species is
# IN THE GAME and that putting it there did not spend the campaign's last scarce
# budget, and they sweep the table rather than naming waves 17 and 19, so a row
# that moves the species takes them with it.


## Every campaign wave carrying a Nurse Beetle, and how many it sends. Derived off
## the AURA rather than off the species name, so a third healer would be counted
## here the day it landed instead of quietly escaping every check below.
func _nurse_waves() -> Dictionary:
	var out: Dictionary = {}
	for wave: int in range(1, WaveDirector.WAVES.size() + 1):
		var count: int = 0
		for group: Dictionary in WaveDirector.groups_for(wave):
			if Pest.heal_radius(StringName(group["species"])) > 0.0:
				count += int(group["count"])
		if count > 0:
			out[wave] = count
	return out


## The best a level-1 Corn Cobbler can do to one pest anywhere inside its ring.
## Swept rather than sampled at one distance: the claim being made is "the free
## starter loses this race", and a claim about the starter's BEST case is the only
## version of it worth asserting.
func _best_starter_cob_dps() -> float:
	var best: float = 0.0
	var steps: int = 40
	for i: int in range(steps + 1):
		var distance: float = CornCobbler.RANGE * float(i) / float(steps)
		best = maxf(best, CornCobbler.single_target_dps(1, distance))
	return best


## The number the whole species is balanced on, asserted against the plant it was
## priced against rather than written down.
##
## `Pest.heal_per_second(NURSE)` sits ABOVE one level-1 Corn Cobbler's damage and
## BELOW two of them. That band is the decision the boss exists to pose: trickle
## damage spread thin over a lane does nothing at all inside the aura, and the same
## seeds concentrated do. Reading it off `CornCobbler.LEVELS` means a balance pass
## on corn fails here loudly instead of quietly turning this species into a beetle.
func test_the_nurse_beetles_aura_out_paces_one_starter_cob_and_loses_to_two() -> String:
	var heal: float = Pest.heal_per_second(Pest.NURSE)
	var starter: float = _best_starter_cob_dps()
	var err: String = _T.assert_gt(heal, 0.0, "the Nurse Beetle actually has an aura")
	if err == "":
		err = _T.assert_gt(starter, 0.0,
			"and a level-1 cob actually does damage (a zero here is a vacuous pass)")
	if err != "":
		return err
	err = _T.assert_gt(heal, starter,
		("one level-1 Corn Cobbler loses the race outright -- %.2f health a second put"
			+ " back against %.2f a second taken off, so a lane of free starter plants"
			+ " never finishes anything standing inside the aura") % [heal, starter])
	if err == "":
		err = _T.assert_gt(starter * 2.0, heal,
			("and TWO of them win it (%.2f against %.2f). If this ever fails the species"
				+ " has become unanswerable by the plant every player owns, which is a"
				+ " wall rather than a decision -- see Pest.SPECIES[NURSE]")
				% [starter * 2.0, heal])
	if err == "":
		# The other end of the band: the top of the corn ladder, at the rim of its own
		# ring where only the middle kernel connects, still clears the aura on its own.
		var maxed_at_rim: float = CornCobbler.single_target_dps(
			CornCobbler.LEVELS.size(), CornCobbler.RANGE * 0.95)
		err = _T.assert_gt(maxed_at_rim, heal,
			("a maxed cob at the far edge of its ring still out-damages the aura"
				+ " (%.2f against %.2f) -- upgrading is an answer to this boss")
				% [maxed_at_rim, heal])
	if err == "":
		# Legibility, and the reason the pulse is 3.0 rather than 2.0 every second: one
		# pulse is exactly one whole aphid, so a swarm inside the aura visibly stops
		# dying rather than dying slightly slower.
		err = _T.assert_float_eq(Pest.heal_amount(Pest.NURSE),
			float(Pest.SPECIES[Pest.APHID]["health"]), 0.0001,
			"one pulse is exactly one aphid's whole health pool")
	if err == "":
		# The mirror image, and worth asserting together because the pair IS the design:
		# the garden's own healer is tuned to LOSE its race with one pest, and this one
		# is tuned to WIN its race with one plant.
		err = _T.assert_gt(Pest.EAT_DPS, Aloe.HEAL_PER_SECOND,
			("the Aloe still loses its race (%.1f/s of healing against %.1f/s of eating)"
				+ " while the Nurse wins hers -- that asymmetry is what makes this a boss"
				+ " and that a support plant") % [Aloe.HEAL_PER_SECOND, Pest.EAT_DPS])
	return err


## The reach, against the two numbers it was chosen between.
##
## Under `CornCobbler.RANGE` so a cob that can reach the Nurse can reach everything
## she is protecting -- "shoot the healer" is never a shot the player cannot take
## from a plant already on the board. And under the 192 px between the board's
## parallel road rows, so an aura never leaks into a lane the Nurse is not walking.
func test_the_auras_reach_sits_under_a_cobs_ring_and_under_the_gap_between_lanes() -> String:
	var reach: float = Pest.heal_radius(Pest.NURSE)
	var err: String = _T.assert_gt(reach, 0.0, "the aura has a reach")
	if err == "":
		err = _T.assert_gt(CornCobbler.RANGE, reach,
			("a cob's ring (%.0f) contains the aura (%.0f), so anything the Nurse is"
				+ " protecting is inside reach of a cob that can see her")
				% [CornCobbler.RANGE, reach])
	if err == "":
		err = _T.assert_gt(reach, float(Board.CELL),
			("and it reaches past her own cell (%.0f against %d) -- an aura that only"
				+ " covered the pest it was standing on would be a health pool")
				% [reach, Board.CELL])
	if err == "":
		# Derived from the road rather than written down: PATH_CORNERS runs along three
		# rows of the board and the closest two are three cells apart.
		var lane_gap: float = float(Board.CELL) * 3.0
		err = _T.assert_gt(lane_gap, reach,
			("and it does not bridge two lanes of the road (%.0f px apart against a"
				+ " %.0f px aura) -- a Nurse heals the wave she is walking in")
				% [lane_gap, reach])
	return err


## The branch must not leak, exactly as the plate's must not. Every other species
## reports no aura at all rather than a rate with no reach behind it.
func test_the_aura_belongs_to_exactly_one_species_and_leaves_the_others_alone() -> String:
	var healers: Array[StringName] = []
	for which: StringName in Pest.SPECIES:
		if Pest.heal_radius(which) > 0.0:
			healers.append(which)
	var err: String = _T.assert_eq(healers.size(), 1,
		"exactly one species carries an aura (found %s)" % [healers])
	if err == "":
		err = _T.assert_eq(String(healers[0]), String(Pest.NURSE), "and it is the Nurse Beetle")
	if err != "":
		return err
	# heal_amount() and heal_period() read heal_radius() first on purpose: a row
	# naming a rate and no reach must be auraless, not a heal that reaches the whole
	# board because a missing key read as zero and zero compared as "no limit".
	var checked: int = 0
	for which: StringName in Pest.SPECIES:
		if which == Pest.NURSE:
			continue
		err = _T.assert_float_eq(Pest.heal_per_second(which), 0.0, 0.0001,
			"%s puts nothing back into anything" % which)
		if err == "":
			err = _T.assert_float_eq(Pest.heal_amount(which), 0.0, 0.0001,
				"%s has no pulse size either" % which)
		if err == "":
			err = _T.assert_float_eq(Pest.heal_period(which), 0.0, 0.0001,
				"%s has no pulse clock, so _tick_aura returns before it ever counts" % which)
		if err != "":
			return err
		checked += 1
	return _T.assert_gt(checked, 0, "there were other species to check (%d)" % checked)


## The pure half of the heal, where the two guards live.
func test_healing_never_overshoots_the_bar_and_never_runs_backwards() -> String:
	var err: String = _T.assert_float_eq(Pest.healed_to(4.0, 3.0, 16.0), 7.0, 0.0001,
		"an ordinary top-up is just addition")
	if err == "":
		err = _T.assert_float_eq(Pest.healed_to(15.0, 3.0, 16.0), 16.0, 0.0001,
			"and it stops at the pest's own maximum rather than overfilling the bar")
	if err == "":
		err = _T.assert_float_eq(Pest.healed_to(8.0, -5.0, 16.0), 8.0, 0.0001,
			("a negative amount heals nothing rather than turning a nurse into a second"
				+ " mouth -- the same guard Aloe.heal_for spends a maxf on"))
	return err


## The aura on a real board: one pulse, three pests, three different answers.
##
## Driven by calling `pulse_aura()` directly rather than by pumping sixty physics
## frames, which would be measuring the frame pump. Positions and health are set
## AFTER the scene settles, because entering the tree switches physics processing
## back on and the pests walk themselves down their own routes first -- the same
## trap `_corn_volley_damage` documents above.
func test_a_nurse_tops_up_the_pest_beside_her_and_never_herself() -> String:
	var nurse: Pest = _pest(Pest.NURSE, Vector2.ZERO)
	var near: Pest = _pest(Pest.BEETLE, Vector2.ZERO)
	var far: Pest = _pest(Pest.BEETLE, Vector2.ZERO)
	var host: Node2D = _host([nurse, near, far])
	await _T.instantiate_scene(host)
	var reach: float = Pest.heal_radius(Pest.NURSE)
	var pulse: float = Pest.heal_amount(Pest.NURSE)
	var three: Array[Pest] = [nurse, near, far]
	for pest: Pest in three:
		pest.set_physics_process(false)
	nurse.position = Vector2.ZERO
	near.position = Vector2(0.0, reach * 0.5)
	far.position = Vector2(0.0, reach * 2.0)
	# Hurt by more than one pulse, so a heal that landed cannot be hidden by the
	# ceiling in healed_to().
	var wound: float = pulse * 3.0
	for pest: Pest in three:
		pest.health = pest.max_health
		pest.take_damage(wound)

	var err: String = _T.assert_float_eq(near.health, near.max_health - wound, 0.0001,
		"the neighbour starts hurt (a full-health pest could not show a heal)")
	if err == "":
		nurse.pulse_aura()
		err = _T.assert_float_eq(near.health, near.max_health - wound + pulse, 0.0001,
			("one pulse put %.1f back into the pest %.0f px away, inside the %.0f px aura"
				% [pulse, reach * 0.5, reach]))
	if err == "":
		err = _T.assert_float_eq(far.health, far.max_health - wound, 0.0001,
			("and nothing at all into the one %.0f px away, outside it -- the reach is a"
				+ " real limit rather than decoration") % (reach * 2.0))
	if err == "":
		err = _T.assert_float_eq(nurse.health, nurse.max_health - wound, 0.0001,
			("and nothing into HERSELF. A boss that also repairs its own bar is a health"
				+ " pool wearing a mechanic's name, which is the one thing this species"
				+ " was built not to be -- see Pest.pulse_aura"))
	if err == "":
		# A corpse must not be stood back up. `died` has already fired by then, so the
		# seeds and the husk are paid and a revived pest would be paid for twice.
		near.kill()
		var dead_at: float = near.health
		nurse.pulse_aura()
		err = _T.assert_float_eq(near.health, dead_at, 0.0001,
			"a pulse over a corpse leaves it dead rather than reviving a paid-for kill")
	_T.free_ui(host)
	return err


## The bead's acceptance criterion, as one assertion. A species that exists, is
## priced and is fully tested is still not in the game until the table sends one --
## the exact defect the Shield Bug sat on for a whole cycle.
func test_the_nurse_beetle_is_actually_in_a_wave_a_player_will_meet() -> String:
	var waves: Dictionary = _nurse_waves()
	var err: String = _T.assert_gt(waves.size(), 0,
		("no campaign wave sends a Nurse Beetle, so no player will ever meet one."
			+ " Pest.SPECIES holding the entry is not the same as the game containing"
			+ " the species -- see WaveDirector.WAVES"))
	if err != "":
		return err
	var total: int = 0
	for wave: int in waves.keys():
		total += int(waves[wave])
	err = _T.assert_gt(total, 0, "and the rows send a positive number of them (%s)" % [waves])
	if err == "":
		# Campaign only, and deliberately: `_endless_groups` is built on threat rising
		# every single wave by exactly one beetle's worth, and a boss on a cadence
		# breaks that. The species therefore lives in the campaign or nowhere.
		var endless_has_one: bool = false
		for group: Dictionary in WaveDirector.groups_for(WaveDirector.WAVES.size() + 1):
			if Pest.heal_radius(StringName(group["species"])) > 0.0:
				endless_has_one = true
		err = _T.assert_false(endless_has_one,
			("endless still sends only the swarm and the column -- see _endless_groups"
				+ " for why a periodic boss cannot go there"))
	return err


## Two Nurses inside one aura would top each other up for as long as they both
## lived, because `pulse_aura` heals every OTHER pest in range and makes no
## exception for a second healer. That is not a bug to patch in the pest -- an
## exception the player cannot see is worse than the rule -- so the table carries
## the constraint and this is what enforces it.
func test_no_wave_sends_two_nurse_beetles_into_each_others_aura() -> String:
	var waves: Dictionary = _nurse_waves()
	var err: String = _T.assert_gt(waves.size(), 0,
		"there are Nurse waves to check (a zero here is a vacuous pass)")
	if err != "":
		return err
	for wave: int in waves.keys():
		err = _T.assert_eq(int(waves[wave]), 1,
			("wave %d sends %d Nurse Beetles. Two of them heal EACH OTHER (pulse_aura"
				+ " excludes only `self`), so a pair inside one aura is a boss the"
				+ " garden cannot finish -- send them on separate waves")
				% [wave, int(waves[wave])])
		if err != "":
			return err
	return err


## Not too early, and never on a wave that already carries the other boss.
##
## The first half is the Shield Bug's rule for the same reason: the free starter
## plant cannot beat this aura on its own, so a Nurse before the Chomp and the
## Dandelion are realistically owned is a lane with no legal answer. The second
## half is new -- two bosses in one row dilutes both, and the two questions they
## pose are meant to be asked separately.
func test_the_nurse_beetle_lands_late_and_never_shares_a_wave_with_the_queen() -> String:
	var waves: Dictionary = _nurse_waves()
	var err: String = _T.assert_gt(waves.size(), 0,
		"there are Nurse waves to place (a zero here is a vacuous pass)")
	if err != "":
		return err
	var half: int = WaveDirector.WAVES.size() / 2
	var earliest: int = WaveDirector.WAVES.size() + 1
	for wave: int in waves.keys():
		err = _T.assert_gt(int(wave), half,
			("wave %d sends a Nurse Beetle, but it is in the campaign's first half"
				+ " (<= %d). One level-1 Corn Cobbler loses the race with the aura, so a"
				+ " Nurse before a second kind of plant is realistically owned is a wall,"
				+ " not a decision") % [wave, half])
		if err != "":
			return err
		var shares_with_queen: bool = false
		for group: Dictionary in WaveDirector.groups_for(int(wave)):
			if StringName(group["species"]) == Pest.QUEEN:
				shares_with_queen = true
		err = _T.assert_false(shares_with_queen,
			("wave %d carries both bosses. They pose different questions -- the queen"
				+ " asks where a kill lands, the Nurse asks what the garden's damage is"
				+ " aimed at -- and a row that asks both asks neither") % wave)
		if err != "":
			return err
		earliest = mini(earliest, int(wave))
	err = _T.assert_gt(earliest, WaveDirector.MUTATION_START_WAVE,
		("the debut (wave %d) is past MUTATION_START_WAVE (%d) -- two new things to read"
			+ " on one wave is the mistake cycle 101 had to undo on wave 8 itself")
			% [earliest, WaveDirector.MUTATION_START_WAVE])
	return err


## What it displaced, pinned as the decision it was -- the Shield Bug's test one
## species later, and the same two facts about the finale.
##
## The finale is the only campaign row with no road slack (40 of 40) and the least
## health headroom under the seam bound derived at WaveDirector.ENDLESS_BEETLE_BASE.
## A Nurse there would have been paid for out of that headroom; every other row pays
## in beetles. This asserts the choice not to, so a future cycle that spends it does
## so on purpose and reads why here.
func test_the_nurse_beetle_was_paid_for_in_beetles_rather_than_out_of_the_finale() -> String:
	var finale: int = WaveDirector.WAVES.size()
	var waves: Dictionary = _nurse_waves()
	var err: String = _T.assert_gt(waves.size(), 0,
		"there are Nurse waves to check (a zero here is a vacuous pass)")
	if err != "":
		return err
	err = _T.assert_false(waves.has(finale),
		("the finale carries a Nurse Beetle. It is the one row with zero road slack and"
			+ " the least health headroom in the campaign, so anything added there is"
			+ " paid for out of the seam bound -- re-derive before allowing this"))
	if err != "":
		return err

	# The headroom itself, computed exactly the way test_economy.gd's seam test and
	# the Shield Bug's own test above compute it, so the three cannot disagree.
	var seam_health: float = 0.0
	for group: Dictionary in WaveDirector.groups_for(finale + 1):
		seam_health += float(group["count"]) * float(Pest.SPECIES[group["species"]]["health"])
	var finale_health: float = 0.0
	for group: Dictionary in WaveDirector.groups_for(finale):
		finale_health += float(group["count"]) * float(Pest.SPECIES[group["species"]]["health"])
	err = _T.assert_gt(seam_health, 0.0, "the first endless wave has contents")
	if err == "":
		err = _T.assert_gt(finale_health, 0.0, "and so does the finale")
	if err != "":
		return err
	# The finale's own health scale belongs in the campaign multiplier since
	# plant-tower-defense-iqp8 -- see the Shield Bug's copy of this derivation above
	# and health_scale_for. Without it the headroom below reads 307 points instead
	# of 18.7, and this assertion (which says the headroom is SMALL) fails with a
	# message pointing at the finale rather than at the missing multiplier.
	var campaign_mult: float = (1.0 + WaveDirector.MUTATION_CHANCE * WaveDirector.MUTATION_THREAT_WEIGHT) \
		* WaveDirector.health_scale_for(finale)
	var seam_mult: float = 1.0 + WaveDirector.mutation_chance_for(finale + 1) \
		* WaveDirector.MUTATION_THREAT_WEIGHT
	var seam_scales: float = WaveDirector.health_scale_for(finale + 1) \
		* WaveDirector.speed_scale_for(finale + 1)
	var bound: float = seam_health * seam_mult * seam_scales / campaign_mult
	var one_nurse: float = float(Pest.SPECIES[Pest.NURSE]["health"])
	err = _T.assert_gt(one_nurse, bound - finale_health,
		("the finale's headroom under the seam bound is %.1f points (finale %.0f, bound"
			+ " %.1f), which is now enough to hold a %.0f-point Nurse Beetle. It measured"
			+ " 18.7 when this species landed -- less than half a Nurse -- which is WHY"
			+ " both of her rows paid in beetles instead. If this ever fails, the finale"
			+ " has been made lighter or the seam bound raised, and the sentence above"
			+ " needs rewriting rather than deleting")
			% [bound - finale_health, finale_health, bound, one_nurse])
	if err != "":
		return err

	# And every row that DID take one is still strictly inside the road budget --
	# only the finale is allowed to land on it.
	var checked: int = 0
	for wave: int in waves.keys():
		var peak: int = WaveDirector.peak_simultaneous_pests(int(wave))
		err = _T.assert_gt(WaveDirector.SIMULTANEOUS_PEST_CEILING, peak,
			("wave %d carries a Nurse Beetle and peaks at %d, strictly under the %d"
				+ " ceiling -- only the finale is allowed to land on it")
				% [wave, peak, WaveDirector.SIMULTANEOUS_PEST_CEILING])
		if err != "":
			return err
		checked += 1
	return _T.assert_gt(checked, 0, "the per-wave sweep actually ran (%d waves)" % checked)


## `wave_carries_boss` used to compare against `Pest.QUEEN` by name. That was
## correct and unextendable at the same time: a second boss would have gone on
## answering `false`, silently, and both readers of it -- the HUD's "a boss is
## coming" prep note and the rule that drought never lands on a boss wave -- would
## have quietly stopped applying to half the bosses in the game.
##
## This is the check that a name written into a comparison cannot pass: the boss
## list is derived from the SPECIES flag, and every wave containing any of them has
## to answer true.
func test_wave_carries_boss_sees_every_boss_species_and_not_just_the_queen() -> String:
	var bosses: Array[StringName] = Pest.boss_species()
	var err: String = _T.assert_gt(bosses.size(), 1,
		("the game has more than one boss species (%s). If this fails, the test below"
			+ " is asserting a single-species rule and proves nothing about the flag")
			% [bosses])
	if err == "":
		err = _T.assert_false(Pest.is_boss(Pest.BEETLE),
			"and an ordinary pest is not one, so the flag separates something")
	if err != "":
		return err
	var seen: Dictionary = {}
	var boss_waves: int = 0
	var plain_waves: int = 0
	for wave: int in range(1, WaveDirector.WAVES.size() + 1):
		var carries: bool = false
		for group: Dictionary in WaveDirector.groups_for(wave):
			var which: StringName = StringName(group["species"])
			if Pest.is_boss(which):
				carries = true
				seen[which] = true
		err = _T.assert_eq(WaveDirector.wave_carries_boss(wave), carries,
			"wave_carries_boss(%d) agrees with the species in the row" % wave)
		if err != "":
			return err
		if carries:
			boss_waves += 1
		else:
			plain_waves += 1
	err = _T.assert_gt(boss_waves, 0, "some campaign waves carry a boss (%d)" % boss_waves)
	if err == "":
		err = _T.assert_gt(plain_waves, 0,
			("and some do not (%d) -- a function answering true everywhere would pass the"
				+ " sweep above and mean nothing") % plain_waves)
	if err == "":
		# The half a per-wave sweep cannot claim: every boss the game HAS is in the
		# campaign somewhere, so none of them is a flag nothing ever exercises.
		err = _T.assert_eq(seen.size(), bosses.size(),
			("every boss species reaches a campaign wave -- %s of %s" % [seen.keys(), bosses]))
	if err == "":
		err = _T.assert_false(WaveDirector.wave_carries_boss(WaveDirector.WAVES.size() + 1),
			"and no endless wave carries one, which is what the campaign-only rule means")
	return err


# -- The Leafhopper and the Locust: two more questions (plant-tower-defense-4zyb) --
#
# The five species before these are answered by damage: the beetle by how much, the
# Shield Bug by what kind, the queen by where a kill lands, the Nurse by what the
# garden's damage is aimed at. Neither of these two is answered by damage at all.


## Every other species walks at a constant speed for its whole crossing.
## `hop_speed_multiplier` is the one exception, and the shape it has to hold is the
## crouch/leap split itself: near-motionless for most of the cycle, then a burst.
func test_a_leafhopper_crouches_then_leaps_and_never_drifts_off_its_own_average() -> String:
	var period: float = Pest.hop_period(Pest.HOPPER)
	var err: String = _T.assert_gt(period, 0.0,
		"the Leafhopper actually carries a hop_period -- every other species answers 0.0")
	if err == "":
		err = _T.assert_float_eq(Pest.hop_speed_multiplier(Pest.HOPPER, 0.0),
			Pest.HOP_CROUCH_MULT, 0.0001, "the cycle opens crouched")
	if err == "":
		var crouch_span: float = period * Pest.hop_crouch_fraction(Pest.HOPPER)
		err = _T.assert_float_eq(Pest.hop_speed_multiplier(Pest.HOPPER, crouch_span - 0.01),
			Pest.HOP_CROUCH_MULT, 0.0001, "and stays crouched right up to the leap")
	if err == "":
		var leap: float = Pest.hop_leap_multiplier(Pest.HOPPER)
		err = _T.assert_gt(leap, 1.0,
			"the leap half is a real burst, faster than the species' own average speed")
	if err == "":
		# The invariant `hop_leap_multiplier` is DERIVED from, stated as an assertion
		# rather than trusted: the cycle's time-weighted average multiplier is 1.0, so
		# a hopping species' `speed` still means "average px/s over the crossing" --
		# which is what lets WaveDirector.crossing_seconds price it with no special case.
		var fraction: float = Pest.hop_crouch_fraction(Pest.HOPPER)
		var leap: float = Pest.hop_leap_multiplier(Pest.HOPPER)
		var average: float = fraction * Pest.HOP_CROUCH_MULT + (1.0 - fraction) * leap
		err = _T.assert_float_eq(average, 1.0, 0.0001,
			("the cycle's time-weighted average multiplier is 1.0 (got %.4f) -- if this"
				+ " drifts, WaveDirector's crossing-time arithmetic is quietly pricing a"
				+ " species that no longer crosses at its own stated speed") % average)
	if err == "":
		# Every OTHER species must answer the identity multiplier at every clock value,
		# the same "the branch must not leak" shape the plate and the aura are held to.
		for which: StringName in Pest.SPECIES:
			if which == Pest.HOPPER:
				continue
			err = _T.assert_float_eq(Pest.hop_speed_multiplier(which, 1.23), 1.0, 0.0001,
				"%s answers a flat 1.0 -- it does not hop" % which)
			if err != "":
				break
	return err


## The live half: a Leafhopper actually walks slower during the crouch than during
## the leap, through `_effective_speed()` rather than through the pure function
## alone -- the pure function could be right and the wiring in `_physics_process`
## could still call `speed` instead of it.
func test_a_leafhoppers_effective_speed_actually_changes_with_its_own_clock() -> String:
	var pest: Pest = _pest(Pest.HOPPER, Vector2.ZERO)
	var host: Node2D = _host([pest])
	await _T.instantiate_scene(host)
	pest.set_physics_process(false)
	var crouch: float = pest._effective_speed()
	pest._hop_clock = Pest.hop_period(Pest.HOPPER) * Pest.hop_crouch_fraction(Pest.HOPPER) + 0.01
	var leap: float = pest._effective_speed()
	var err: String = _T.assert_gt(leap, crouch * 2.0,
		("the leap (%.1f px/s) is more than twice the crouch (%.1f) -- a wobble, not"
			+ " the rhythm the species is built on") % [leap, crouch])
	if err == "":
		err = _T.assert_gt(pest.speed, crouch,
			"crouched, it is slower than its own SPECIES row says")
	_T.free_ui(host)
	return err


## Alone, a Locust is exactly its SPECIES row's speed. `_swarm_neighbor_count` and
## `swarm_speed_multiplier` are pure and split out precisely so this is checkable
## without a physics frame -- the same shape `pulse_aura`'s reach and rate are.
func test_a_lone_locust_is_the_slowest_ordinary_bug_and_gets_no_crowd_bonus() -> String:
	var reach: float = Pest.swarm_radius(Pest.LOCUST)
	var err: String = _T.assert_gt(reach, 0.0,
		"the Locust actually carries a swarm_radius -- every other species answers 0.0")
	if err == "":
		err = _T.assert_float_eq(Pest.swarm_speed_multiplier(0, Pest.swarm_cap(Pest.LOCUST),
			Pest.swarm_step(Pest.LOCUST)), 1.0, 0.0001,
			"zero neighbours is the identity multiplier")
	if err == "":
		var locust_speed: float = float(Pest.SPECIES[Pest.LOCUST]["speed"])
		for which: StringName in Pest.SPECIES:
			if which == Pest.LOCUST:
				continue
			# ORDINARY is the word in this test's own name, and a boss is not one. The
			# Cutworm walks at 20 px/s against the Locust's 24 and is in no sense the
			# least threatening thing on the board -- it is 1800 health and fifteen cells
			# of body, and it walks slowly BECAUSE of that rather than in spite of it.
			# Read off the `boss` flag rather than by name, so the next boss is excluded
			# without this test being edited again.
			if Pest.is_boss(which):
				continue
			var other_speed: float = float(Pest.SPECIES[which]["speed"])
			err = _T.assert_gte(other_speed, locust_speed,
				("%s (%.0f px/s) is not slower than the Locust (%.0f) -- alone, this species"
					+ " is supposed to be the least threatening thing on the board")
					% [which, other_speed, locust_speed])
			if err != "":
				break
	if err == "":
		# The cap is derived, not guessed: a fully massed column tops out at exactly
		# the aphid's own speed, the fastest anything else in this game moves.
		var capped: float = float(Pest.SPECIES[Pest.LOCUST]["speed"]) * Pest.swarm_speed_multiplier(
			Pest.swarm_cap(Pest.LOCUST), Pest.swarm_cap(Pest.LOCUST), Pest.swarm_step(Pest.LOCUST))
		err = _T.assert_float_eq(capped, float(Pest.SPECIES[Pest.APHID]["speed"]), 0.01,
			("a fully massed Locust column tops out at %.2f px/s, the aphid's own %.0f --"
				+ " however dense the swarm gets it never outpaces the fastest thing this"
				+ " game already fields") % [capped, float(Pest.SPECIES[Pest.APHID]["speed"])])
	if err == "":
		for which: StringName in Pest.SPECIES:
			if which == Pest.LOCUST:
				continue
			err = _T.assert_eq(Pest.swarm_cap(which), 0,
				"%s carries no swarm cap -- it does not read another pest's crowd at all" % which)
			if err != "":
				break
	return err


## The live half of the crowd mechanic, and the property that makes it a rule about
## LOCUSTS rather than a second, quieter aura reading every pest on the board:
## another species standing on top of it changes nothing, and its own kind does.
func test_a_locusts_effective_speed_climbs_with_its_own_kind_and_ignores_everyone_else() -> String:
	var lone: Pest = _pest(Pest.LOCUST, Vector2.ZERO)
	var stranger: Pest = _pest(Pest.BEETLE, Vector2.ZERO)
	var host: Node2D = _host([lone, stranger])
	await _T.instantiate_scene(host)
	for pest: Pest in [lone, stranger]:
		pest.set_physics_process(false)
	lone.position = Vector2.ZERO
	stranger.position = Vector2(0.0, Pest.swarm_radius(Pest.LOCUST) * 0.5)
	var alone_speed: float = lone._effective_speed()
	var err: String = _T.assert_float_eq(alone_speed, lone.speed, 0.0001,
		"a beetle standing well inside the reach changes nothing -- it is not a Locust")
	if err == "":
		var packed: Array[Pest] = []
		for i: int in range(Pest.swarm_cap(Pest.LOCUST)):
			var kin: Pest = _pest(Pest.LOCUST, Vector2.ZERO)
			kin.position = Vector2(0.0, Pest.swarm_radius(Pest.LOCUST) * 0.5)
			kin.set_physics_process(false)
			host.add_child(kin)
			packed.append(kin)
		var crowded_speed: float = lone._effective_speed()
		err = _T.assert_gt(crowded_speed, alone_speed,
			("%d of its own kind inside the reach and it is still walking at %.1f, the"
				+ " same as alone (%.1f)") % [Pest.swarm_cap(Pest.LOCUST), crowded_speed, alone_speed])
		if err == "":
			var far: Pest = _pest(Pest.LOCUST, Vector2.ZERO)
			far.position = Vector2(0.0, Pest.swarm_radius(Pest.LOCUST) * 3.0)
			far.set_physics_process(false)
			host.add_child(far)
			var still_capped: float = lone._effective_speed()
			err = _T.assert_float_eq(still_capped, crowded_speed, 0.0001,
				"one more Locust well outside the reach changes nothing")
			far.free()
		for kin: Pest in packed:
			kin.free()
	_T.free_ui(host)
	return err


## The bead's acceptance criterion for these two, the same shape as the Nurse's own
## `test_the_nurse_beetle_is_actually_in_a_wave_a_player_will_meet`: a species that
## exists in `Pest.SPECIES` and is fully tested is still not in the game until a
## wave actually sends one.
func test_the_leafhopper_and_the_locust_are_both_actually_in_a_wave_a_player_will_meet() -> String:
	var hopper_total: int = 0
	var locust_total: int = 0
	for wave: int in range(1, WaveDirector.WAVES.size() + 1):
		for group: Dictionary in WaveDirector.groups_for(wave):
			var species: StringName = StringName(group["species"])
			if species == Pest.HOPPER:
				hopper_total += int(group["count"])
			elif species == Pest.LOCUST:
				locust_total += int(group["count"])
	var err: String = _T.assert_gt(hopper_total, 0,
		"no campaign wave sends a Leafhopper -- Pest.SPECIES holding the entry is not"
			+ " the same as the game containing the species")
	if err == "":
		err = _T.assert_gt(locust_total, 0, "and none sends a Locust either")
	return err


## The Locust's debut row is built to let several of them bunch up together -- a
## tight spawn gap is the whole point, since the swarm mechanic has nothing to say
## about a column trickling out one at a time. Pinned here so a future pacing edit
## that widens the gap fails loudly instead of quietly turning the debut back into
## an aphid with worse stats.
func test_the_locusts_debut_paces_them_close_enough_to_actually_swarm() -> String:
	var found: bool = false
	var err: String = ""
	for wave: int in range(1, WaveDirector.WAVES.size() + 1):
		for group: Dictionary in WaveDirector.groups_for(wave):
			if StringName(group["species"]) != Pest.LOCUST:
				continue
			found = true
			var gap: float = float(group["gap"])
			var travelled: float = gap * float(Pest.SPECIES[Pest.LOCUST]["speed"])
			err = _T.assert_gt(Pest.swarm_radius(Pest.LOCUST), travelled,
				("wave %d's Locusts spawn %.2fs apart, %.0f px of walking at their own"
					+ " (unboosted) speed -- past swarm_radius (%.0f), so consecutive"
					+ " spawns never link up and the debut teaches nothing")
					% [wave, gap, travelled, Pest.swarm_radius(Pest.LOCUST)])
			if err != "":
				return err
	return _T.assert_true(found, "there is a Locust group to check (a vacuous pass otherwise)")


# -- BEGIN the sting's thrust is aimed (plant-tower-defense-n2wd) ---------------


## The jab travels at the victim, in both axes and at a fixed distance.
##
## `sting_lean_skew` above is a projection onto x, because a shear has nowhere to go but
## sideways. A THRUST does: the player report this pair of gestures answers ("the red
## plant also needs a better animation, at the moment it just jiggles") was about a plant
## that deformed in place, and a jab that only moved horizontally would still not travel
## at a pest sitting directly above the plant. So this asserts the case the skew
## deliberately cannot cover.
func test_a_nettle_thrusts_at_its_victim_in_both_axes() -> String:
	var plant := Vector2(120.0, 400.0)
	var right: Vector2 = Nettle.sting_thrust_offset(plant, plant + Vector2(64.0, 0.0))
	var err: String = _T.assert_float_eq(right.x, Nettle.STING_THRUST_PX, 0.0001,
		"a victim dead right pulls the jab fully right, got %.3f" % right.x)
	if err == "":
		err = _T.assert_float_eq(right.y, 0.0, 0.0001,
			"and not at all vertically, got %.3f" % right.y)
	if err == "":
		# The case sting_lean_skew answers with zero, and the reason this is a vector.
		var above: Vector2 = Nettle.sting_thrust_offset(plant, plant + Vector2(0.0, -80.0))
		err = _T.assert_float_eq(above.y, -Nettle.STING_THRUST_PX, 0.0001,
			("a victim straight up is jabbed UP -- the skew has no answer for this one,"
				+ " which is why the thrust is a vector and not a second projection."
				+ " got %.3f") % above.y)
	if err == "":
		var diag: Vector2 = Nettle.sting_thrust_offset(plant, plant + Vector2(50.0, -50.0))
		err = _T.assert_float_eq(diag.length(), Nettle.STING_THRUST_PX, 0.0001,
			("the throw is the same distance whichever way it points (%.3f) -- a jab"
				+ " that reached further diagonally would read as two different gestures")
				% diag.length())
	if err == "":
		# Degenerate input must not produce a NaN direction, which would put the sprite
		# somewhere Godot will not draw and leave no error behind.
		var same: Vector2 = Nettle.sting_thrust_offset(plant, plant)
		err = _T.assert_true(same == Vector2.ZERO,
			"a victim on top of the plant produces no thrust rather than a NaN, got %s" % same)
	return err


# -- END the sting's thrust is aimed -------------------------------------------


# -- BEGIN a meal is eaten in bites (plant-tower-defense-h4v1) ------------------


## The chew lands three discrete bites, not one continuous drain.
##
## Pure statics, deliberately: `GardenTheme.animations_enabled()` is false for every
## test in this suite by construction, so anything asserted through the drawing is
## asserted through a closed gate. test_combat.gd's own rule (see the note above
## `test_a_chomp_lunges_at_the_pest_it_grabbed`) is that the COMPOSITION comes out
## into a static and the field is written above the gate, so deleting it goes red
## rather than silently doing nothing.
func test_a_chomp_eats_a_meal_in_discrete_bites() -> String:
	var err: String = _T.assert_eq(ChompFlower.bites_taken_for(0.0), 0,
		"nothing has been bitten off at the instant of the grab")
	if err == "":
		err = _T.assert_eq(ChompFlower.bites_taken_for(0.99), ChompFlower.BITES_PER_MEAL - 1,
			("the last bite lands WITH the kill, not just before it -- a bite at 0.99"
				+ " is one the player never sees separately from the pest dying"))
	if err == "":
		err = _T.assert_eq(ChompFlower.bites_taken_for(1.0), ChompFlower.BITES_PER_MEAL,
			"and a finished chew has taken every bite")
	if err == "":
		# Monotone, and it actually advances: a function stuck at 0 satisfies the
		# first assertion above and nothing else here.
		var seen: int = 0
		var last: int = -1
		var steps: int = 0
		for i: int in range(0, 21):
			var taken: int = ChompFlower.bites_taken_for(float(i) / 20.0)
			if taken < last:
				return "bites_taken_for went BACKWARDS at progress %.2f (%d after %d)" % [
					float(i) / 20.0, taken, last]
			if taken > last:
				steps += 1
			last = taken
			seen = maxi(seen, taken)
		err = _T.assert_eq(seen, ChompFlower.BITES_PER_MEAL,
			"the sweep reached every bite (%d of %d)" % [seen, ChompFlower.BITES_PER_MEAL])
		if err == "":
			err = _T.assert_gt(steps, 2,
				("and it arrived in separate steps rather than in one jump -- %d"
					+ " transitions over the sweep") % steps)
	if err == "":
		err = _T.assert_gt(ChompFlower.BITES_PER_MEAL, 2,
			("two bites read as start-and-finish, which is what the meal already"
				+ " looked like before plant-tower-defense-h4v1"))
	return err


## Each bite takes something off the bug, and the corpse keeps what was taken.
func test_a_chewed_pest_shrinks_and_its_corpse_stays_shrunk() -> String:
	# The suite's own idiom (see `_pest` above): a bare Pest with setup() called and
	# physics off. Nothing here needs a tree -- every function under test is pure or a
	# plain field write, which is the point of pulling them out of the drawing.
	var pest: Pest = _pest(Pest.APHID, Vector2(200.0, 296.0))
	var err: String = _T.assert_true(pest != null, "the suite can build a pest")
	if err != "":
		return err
	if err == "":
		err = _T.assert_float_eq(pest.chewed_scale(), 1.0, 0.0001,
			"an untouched bug is drawn at full size")
	if err == "":
		pest.set_chewed(1.0)
		err = _T.assert_float_eq(pest.chewed_scale(), Pest.CHEWED_MIN_SCALE, 0.0001,
			"a fully eaten one is down to CHEWED_MIN_SCALE")
	if err == "":
		err = _T.assert_gt(Pest.CHEWED_MIN_SCALE, 0.0,
			("and that floor is not zero -- a bug that vanishes to a point before the"
				+ " flower finishes is a bug that died early"))
	if err == "":
		# Monotone down, with a real middle: a step function that only moved at 1.0
		# would satisfy both endpoints above.
		pest.set_chewed(0.5)
		var half: float = pest.chewed_scale()
		err = _T.assert_gt(1.0, half, "half-eaten is smaller than untouched (%.3f)" % half)
		if err == "":
			err = _T.assert_gt(half, Pest.CHEWED_MIN_SCALE,
				"and larger than fully eaten (%.3f)" % half)
	if err == "":
		# The discontinuity this replaces: the bug used to be full-size right up to
		# the frame it became a corpse.
		pest.set_chewed(1.0)
		pest.kill(Pest.DEATH_BITTEN)
		var corpse: Vector2 = pest.corpse_scale()
		err = _T.assert_gt(1.0, corpse.y,
			("the corpse of a fully eaten bug is still small -- it must not pop back to"
				+ " full size on the frame it dies (got y=%.3f)") % corpse.y)
	pest.free()
	return err


## A pest released unharmed is whole again.
##
## A Chomp destroyed mid-chew lets its meal go, and a bug that walked away two-thirds
## eaten would be a kill the game never scored.
func test_a_pest_released_from_a_chomp_is_whole_again() -> String:
	var pest: Pest = _pest(Pest.APHID, Vector2(200.0, 296.0))
	var err: String = _T.assert_true(pest != null, "the suite can build a pest")
	if err != "":
		return err
	pest.set_chewed(0.66)
	if err == "":
		err = _T.assert_gt(1.0, pest.chewed_scale(), "the bug is part-eaten to begin with")
	if err == "":
		err = _T.assert_float_eq(pest.chewed_fraction(), 0.66, 0.0001,
			"and it reports back what was taken off it")
	if err == "":
		# The clamp, asserted where it matters: ChompFlower divides bites by
		# BITES_PER_MEAL, so an off-by-one in that cadence hands this a value above 1
		# and an unclamped one would invert the lerp and grow the bug.
		pest.set_chewed(1.4)
		err = _T.assert_float_eq(pest.chewed_fraction(), 1.0, 0.0001,
			"a fraction past the end is clamped rather than inverting the shrink")
	if err == "":
		pest.set_chewed(0.0)
		err = _T.assert_float_eq(pest.chewed_scale(), 1.0, 0.0001,
			"and releasing it puts it back to full size")
	pest.free()
	return err


# -- END a meal is eaten in bites ----------------------------------------------


# -- BEGIN a dandelion survives a freed pest in its census ---------------------


## `best_target()` skips a pest that has been freed under it.
##
## The sibling of plant-tower-defense-or67 / gh#43, which fixed exactly this in
## `Plant._furthest_along_in_range`. Dandelion overrides targeting and kept none of
## it: `grep -c is_instance_valid game/dandelion.gd` read 0 until this landed.
##
## A FREED pest, deliberately, not a null one. `is_instance_valid` and `!= null`
## disagree on precisely this value -- a freed Object is not equal to null -- so a
## test that appended `null` would pass against a `!= null` guard that still crashes
## on the real case. That gap is also why no static gate could see this: the cast
## resolves and the name check is clean.
func test_a_dandelion_skips_a_pest_freed_under_it() -> String:
	var dandelion := Dandelion.new()
	dandelion.position = Vector2(200.0, 296.0)
	var live: Pest = _pest(Pest.APHID, Vector2(220.0, 296.0))
	var doomed: Pest = _pest(Pest.APHID, Vector2(240.0, 296.0))
	var pests: Array[Pest] = [live, doomed]

	# Freed, not removed from the array: that is the state the board actually reaches
	# when a kernel kills a pest between the census and the targeting pass.
	doomed.free()

	var err: String = _T.assert_false(is_instance_valid(doomed),
		"the pest really is freed, so this test is exercising the case it claims to")
	if err == "":
		var picked: Pest = dandelion.best_target(pests)
		err = _T.assert_true(picked == live,
			("best_target returns the survivor rather than crashing on the corpse"
				+ " (got %s)") % picked)
	if err == "":
		# The other half, and the one a null-check would not have caught: the freed
		# pest must not be counted into the blast census either, or the bomb aims at
		# a phantom.
		var only_dead: Array[Pest] = [doomed]
		err = _T.assert_true(dandelion.best_target(only_dead) == null,
			"and a census of nothing but corpses picks no target at all")
	dandelion.free()
	live.free()
	return err


# -- END a dandelion survives a freed pest ------------------------------------


# -- BEGIN the campaign's second act (plant-tower-defense-iqp8) ---------------
#
# The campaign's back half stopped escalating: waves 10-22 averaged +6.7% of
# threat a wave for thirteen waves against +14.7% to +80.0% for waves 2-8, and a
# depth-first garden won all twenty-two of them in cycle 101 without losing a
# life. The fix is a compounding health ramp under waves 10-22 -- one function,
# `WaveDirector.health_scale_for`, rather than fourteen rewritten wave rows,
# because the rows are capped by the seam bound at ENDLESS_BEETLE_BASE and have
# about one beetle of headroom between them.
#
# Balance is the one thing no static gate can judge, so these tests do NOT claim
# the campaign is now fun. They pin the four things that ARE checkable and that a
# later balance pass will break without noticing: the first act is untouched, the
# second one really climbs, the curve never falls anywhere from wave 1 to wave
# 300, and the seam bound is exactly the number three other tests derive.
#
# Every number quoted below was priced offline against _raw_threat before
# wave_director.gd was edited -- an arithmetic model of the pure statics, not a
# measurement of a running game.


## The shape of the ramp, asserted at both ends.
##
## Two halves and both matter. The first act must be bit-for-bit what it was --
## wave 8 is MUTATION_START_WAVE and wave 9 already steps +29.1% on count alone,
## and cycle 101's whole tuning was about not landing two difficulty increases on
## one wave -- so health_scale_for is exactly 1.0 out to SECOND_ACT_START_WAVE and
## wave 10 is the first tougher wave. The second act must then step by exactly
## CAMPAIGN_HEALTH_STEP every wave, compounding, which is the property that stops
## it front-loading the way a linear ramp would.
func test_the_second_act_starts_where_it_says_it_does() -> String:
	var err: String = ""
	var flat: int = 0
	for wave: int in range(1, WaveDirector.SECOND_ACT_START_WAVE + 1):
		err = _T.assert_float_eq(WaveDirector.health_scale_for(wave), 1.0, 0.000001,
			("wave %d is in the first act and must be bit-for-bit unscaled -- the ramp"
				+ " anchors AT wave %d, it does not start on it")
				% [wave, WaveDirector.SECOND_ACT_START_WAVE])
		if err != "":
			return err
		flat += 1
	err = _T.assert_gt(flat, 5, "the first act was actually swept (%d waves)" % flat)
	if err != "":
		return err

	var climbed: int = 0
	for wave: int in range(WaveDirector.SECOND_ACT_START_WAVE + 1, WaveDirector.WAVES.size() + 1):
		var ratio: float = WaveDirector.health_scale_for(wave) \
			/ WaveDirector.health_scale_for(wave - 1)
		err = _T.assert_float_eq(ratio, 1.0 + WaveDirector.CAMPAIGN_HEALTH_STEP, 0.000001,
			("wave %d sends pests exactly %.0f%% tougher than wave %d (got %+.2f%%)."
				+ " Compounding rather than linear: a linear ramp puts its biggest"
				+ " relative step on wave %d and its smallest on the finale, which is"
				+ " the wrong way round for a second act")
				% [wave, WaveDirector.CAMPAIGN_HEALTH_STEP * 100.0, wave - 1,
					(ratio - 1.0) * 100.0, WaveDirector.SECOND_ACT_START_WAVE + 1])
		if err != "":
			return err
		climbed += 1
	err = _T.assert_gt(climbed, 10,
		"and the second act is a real stretch of waves, not one row (%d)" % climbed)
	if err == "":
		# The finale, as the one number a human can hold: x1.469 at 0.03 over
		# thirteen waves. Derived rather than typed, so the constant stays the only
		# place the steepness is chosen.
		var top: float = pow(1.0 + WaveDirector.CAMPAIGN_HEALTH_STEP,
			float(WaveDirector.WAVES.size() - WaveDirector.SECOND_ACT_START_WAVE))
		err = _T.assert_float_eq(WaveDirector.health_scale_for(WaveDirector.WAVES.size()), top,
			0.000001, "the finale's pests are x%.3f of the wave-1 pest" % top)
	if err == "":
		# THE THING THAT MUST NOT HAVE MOVED. Speed feeds crossing_seconds, which
		# feeds _paced_gap and peak_simultaneous_pests -- so a campaign speed ramp
		# would silently re-price every road-budget number in wave_director.gd. It
		# was available as a lever and was deliberately not used.
		var pinned: int = 0
		for wave: int in range(1, WaveDirector.WAVES.size() + 1):
			err = _T.assert_float_eq(WaveDirector.speed_scale_for(wave), 1.0, 0.000001,
				("wave %d's pests still walk at the species speed. Health was the lever"
					+ " because it feeds damage and nothing else; speed feeds the road"
					+ " budget") % wave)
			if err == "":
				err = _T.assert_float_eq(WaveDirector.mutation_chance_for(wave),
					WaveDirector.MUTATION_CHANCE, 0.000001,
					"and wave %d still rolls the flat campaign mutation rate" % wave)
			if err != "":
				return err
			pinned += 1
		err = _T.assert_gt(pinned, 20, "the whole campaign was checked (%d waves)" % pinned)
	return err


## The stated invariant, swept rather than argued: threat_for rises strictly at
## every adjacent pair from wave 1 to wave 300 -- through the campaign, across the
## seam into endless, and past the wave every per-pest multiplier has capped.
##
## test_selftest.gd and test_combat.gd already sweep this. It is repeated here
## deliberately: it is the one thing the bead named as non-negotiable, and a
## reader of this section should not have to go and find out whether anybody
## checks it. If this fails and the sweeps elsewhere pass, the campaign ramp is
## the cause.
func test_the_second_act_never_lets_the_threat_curve_fall() -> String:
	var err: String = _T.assert_float_eq(WaveDirector.threat_for(1), 1.0, 0.0001,
		"wave 1 is still the unit every other number is quoted in")
	if err != "":
		return err
	var walked: int = 0
	var previous: float = WaveDirector.threat_for(1)
	var previous_wave: int = 1
	for wave: int in range(2, 301):
		# Skipped, for the reason `boss_solo_wave` is written down: `_raw_threat` sums
		# count x health, so the Cutworm's row prices at 1800 against the last swarm's 424
		# -- honest about what walks in and wrong about what the garden has to do, since
		# `Cutworm.ZONE_HIDE` means most of what the board fires at it lands at 0.15. The
		# sweep goes on comparing the wave before it with the wave after, so the seam this
		# test exists for is still covered.
		if WaveDirector.boss_solo_wave(wave):
			continue
		var threat: float = WaveDirector.threat_for(wave)
		err = _T.assert_gt(threat, previous,
			("wave %d (x%.2f) must price above wave %d (x%.2f). The campaign health"
				+ " ramp multiplies the finale, so the seam is the pair to look at"
				+ " first -- see health_scale_for on why the endless ramp is a"
				+ " multiple of the campaign's last value and not an addition to it")
				% [wave, threat, previous_wave, previous])
		if err != "":
			return err
		previous = threat
		previous_wave = wave
		walked += 1
	return _T.assert_gt(walked, 250, "the sweep actually walked the curve (%d pairs)" % walked)


## The bead's actual complaint, as a gate: no wave in the second act steps by
## less than a floor, and the table alone cannot clear that floor.
##
## The second assertion is the load-bearing one. A floor that the wave rows
## already satisfied would pass with the ramp deleted, and this whole change would
## be untested. So the table's own contribution is recovered by dividing the ramp
## back out, and the test asserts that six of the thirteen steps fall BELOW the
## floor without it -- which is the plateau the bead was filed about, measured.
##
## Swept to SECOND_ACT_ORIGINAL_END_WAVE, not WaveDirector.WAVES.size() --
## see that constant's own comment. The coda appended past it
## (plant-tower-defense-vyov) cannot also clear a 5%-per-wave floor on the
## seam bound's remaining ~18.7 points of headroom; it is checked for its own,
## much weaker invariant (threat_for still strictly rising) by
## test_the_second_act_never_lets_the_threat_curve_fall instead.
func test_the_back_half_no_longer_plateaus() -> String:
	var floor_step: float = 0.05
	var first: int = WaveDirector.SECOND_ACT_START_WAVE + 1
	var steps: Dictionary = {}
	var flat_without_the_ramp: int = 0
	var counted: int = 0
	var err: String = ""
	for wave: int in range(first, WaveDirector.SECOND_ACT_ORIGINAL_END_WAVE + 1):
		var ratio: float = WaveDirector.threat_for(wave) / WaveDirector.threat_for(wave - 1)
		var ramp: float = WaveDirector.health_scale_for(wave) \
			/ WaveDirector.health_scale_for(wave - 1)
		steps["wave %d" % wave] = ratio - 1.0
		if ratio / ramp - 1.0 < floor_step:
			flat_without_the_ramp += 1
		err = _T.assert_gt(ratio - 1.0, floor_step,
			("wave %d steps %+.1f%%, under the %.0f%% floor the second act is supposed"
				+ " to hold. The measured minimum when this landed was +6.2%% at wave"
				+ " 20; if this fires, either a row was edited or CAMPAIGN_HEALTH_STEP"
				+ " was cut") % [wave, (ratio - 1.0) * 100.0, floor_step * 100.0])
		if err != "":
			return err
		counted += 1
	err = _T.assert_gt(counted, 10,
		"every wave of the second act was priced (%d)" % counted)
	if err == "":
		err = _T.assert_gt(flat_without_the_ramp, 5,
			("the ramp is load-bearing: only %d of the %d steps would fall under the"
				+ " %.0f%% floor on the wave rows alone. Six did when this landed"
				+ " (waves 15, 16, 18, 19, 20 and 21). If this drops to zero the rows"
				+ " have been rewritten and the ramp is now redundant rather than the"
				+ " thing holding the floor up")
				% [flat_without_the_ramp, counted, floor_step * 100.0])
	if err == "":
		# The steps still sitting near the line, recorded by name. A future row edit
		# that pushes a third wave down here has to say so out loud.
		#
		# TWO of them, and both numbers are from a RUN. The lane that wrote this
		# priced the ramp offline at CAMPAIGN_HEALTH_STEP = 0.04 and recorded
		# {"wave 20": 0.062366} from its own Python model. The step landed at 0.03
		# instead -- 0.04 compounds into endless and took a real garden six waves past
		# the seam from fighting half its escapees to fighting 11 of 38 -- so wave 20
		# is 0.0522 now, and wave 16 came down to the line with it.
		err = _T.assert_margin(steps, floor_step, 0.02,
			{"wave 16": 0.066822, "wave 20": 0.052237},
			("wave 20 is the second act's flattest join and the only step within 2 points"
				+ " of the floor -- it is the +2.2%% join the bead singled out, lifted"
				+ " to +6.2%% by the ramp and no further"))
	return err


## The seam bound did not move, and the reason it did not move is a design choice
## that could easily have gone the other way.
##
## `threat_for` must rise across the seam, which caps the campaign finale at 436.7
## points of base health -- test_economy.gd derives it, and two tests in this file
## measure the finale's headroom under it. A campaign health ramp multiplies the
## finale's threat, so it eats that headroom unless the endless ramp is expressed
## as a MULTIPLE of where the campaign finished rather than as an addition to 1.0.
## Written multiplicatively the campaign factor appears on both sides of the
## division and cancels exactly; written additively it does not, and at
## CAMPAIGN_HEALTH_STEP 0.03 the headroom drops from 18.7 points to about 11 -- one
## one Shield Bug, which is what the Shield Bug's own test in this file asserts it
## is above. This pins the mechanism, not just the consequence.
func test_the_second_act_costs_the_seam_bound_nothing() -> String:
	# `campaign_end` is the ramp's last step and `finale` the last COMPARABLE row -- the
	# same split the Shield Bug's test above spells out. The seam mechanism asserted first
	# is about the ramp and reads campaign_end; the headroom asserted last is about points
	# of health, and reads finale because the solo boss row is 1800 of them in one body.
	var campaign_end: int = WaveDirector.WAVES.size()
	var finale: int = WaveDirector.last_swarm_wave()
	var first_endless: int = campaign_end + 1

	# The mechanism: one endless step of health past the finale is exactly
	# ENDLESS_HEALTH_STEP *of the finale's scale*, not of 1.0.
	var seam_ratio: float = WaveDirector.health_scale_for(first_endless) \
		/ WaveDirector.health_scale_for(campaign_end)
	var err: String = _T.assert_float_eq(seam_ratio, 1.0 + WaveDirector.ENDLESS_HEALTH_STEP,
		0.000001,
		("the first endless wave's pests are one endless step tougher than the FINALE's"
			+ " (x%.4f). If this becomes x%.4f the ramp has been made additive and the"
			+ " seam bound has quietly shrunk")
			% [seam_ratio, (1.0 + WaveDirector.ENDLESS_HEALTH_STEP)
				/ WaveDirector.health_scale_for(campaign_end)])
	if err != "":
		return err

	# The consequence, computed the way test_economy.gd's seam test computes it --
	# with the finale's own health scale now in the campaign multiplier, which is
	# the correction the ramp forced on all three copies of this derivation.
	var seam_health: float = 0.0
	for group: Dictionary in WaveDirector.groups_for(first_endless):
		seam_health += float(group["count"]) * float(Pest.SPECIES[group["species"]]["health"])
	var finale_health: float = 0.0
	for group: Dictionary in WaveDirector.groups_for(finale):
		finale_health += float(group["count"]) * float(Pest.SPECIES[group["species"]]["health"])
	err = _T.assert_gt(seam_health, 0.0, "the first endless wave has contents")
	if err == "":
		err = _T.assert_gt(finale_health, 0.0, "and so does the finale")
	if err != "":
		return err
	var campaign_mult: float = (1.0 + WaveDirector.MUTATION_CHANCE * WaveDirector.MUTATION_THREAT_WEIGHT) \
		* WaveDirector.health_scale_for(campaign_end)
	var seam_mult: float = 1.0 + WaveDirector.mutation_chance_for(first_endless) \
		* WaveDirector.MUTATION_THREAT_WEIGHT
	var seam_scales: float = WaveDirector.health_scale_for(first_endless) \
		* WaveDirector.speed_scale_for(first_endless)
	var bound: float = seam_health * seam_mult * seam_scales / campaign_mult
	err = _T.assert_float_eq(bound, 436.7, 0.5,
		("the seam bound is still the 436.7 points of base health that"
			+ " ENDLESS_BEETLE_BASE, test_economy.gd and two tests in this file all"
			+ " quote (got %.2f). It is quoted in prose in three places, so a change"
			+ " to it is a documentation change as much as a balance one")
			% bound)
	if err == "":
		# 18.7 until plant-tower-defense-vyov's coda (waves 23-26) spent 6 of it on
		# the new finale (queen3+aphid24+beetle7 = 424, up from the old finale's
		# 418) -- see SECOND_ACT_ORIGINAL_END_WAVE for where that 6 went. The bound
		# itself (asserted above) is unmoved; only the finale's own share of it grew.
		err = _T.assert_float_eq(bound - finale_health, 12.7, 0.5,
			("and the finale keeps exactly the %.2f points of headroom under the seam"
				+ " bound now that plant-tower-defense-vyov's coda spent 6 of the"
				+ " original 18.7 on the new finale")
				% (bound - finale_health))
	return err


## What the ramp actually is from the player's side, which none of the threat
## arithmetic above says out loud: the swarm outgrows the plant they start with.
##
## A level-1 Corn Cobbler does 1.0 damage a kernel and an aphid has 3.0 health, so
## a plain aphid has cost exactly three kernels in every wave of this game since
## it shipped. Under the ramp it costs three through wave 9, four from wave 10 and
## five from wave 19 -- the swarm's price against the default plant goes up by two
## thirds across the second act, and the answer to that is a different plant
## rather than more corn. That is the bead's "the plants unlocked at wave 7 have
## something to be needed for", reduced to an integer.
##
## Asserted through the real Pest as well as the arithmetic, because
## `apply_wave_scaling` is what the game actually calls and a ramp the spawner did
## not apply would leave every number above true and the board unchanged.
func test_the_swarm_outgrows_the_plant_the_player_starts_with() -> String:
	var kernel: float = float(CornCobbler.LEVELS[0]["damage"])
	var aphid: float = float(Pest.SPECIES[Pest.APHID]["health"])
	var err: String = _T.assert_gt(kernel, 0.0, "a level-1 kernel does real damage")
	if err == "":
		err = _T.assert_gt(aphid, 0.0, "and an aphid has real health")
	if err != "":
		return err

	var previous: int = 0
	var rises: int = 0
	var swept: int = 0
	for wave: int in range(1, WaveDirector.WAVES.size() + 1):
		var kernels: int = ceili(aphid * WaveDirector.health_scale_for(wave) / kernel)
		err = _T.assert_gte(kernels, previous,
			("the price of one aphid against a level-1 cob never goes DOWN"
				+ " (wave %d wants %d kernels, wave %d wanted %d)")
				% [wave, kernels, wave - 1, previous])
		if err != "":
			return err
		if kernels > previous and previous > 0:
			rises += 1
		previous = kernels
		swept += 1
	err = _T.assert_gt(swept, 20, "the whole campaign was priced (%d waves)" % swept)
	if err == "":
		err = _T.assert_gte(rises, 2,
			("the aphid gets more expensive at least twice across the campaign (got %d)."
				+ " It rose at waves 10 and 19 when this landed, 3 kernels -> 4 -> 5")
				% rises)
	if err == "":
		err = _T.assert_eq(ceili(aphid / kernel), 3,
			"and it still starts at the three kernels it has always cost")
	if err != "":
		return err

	# Through the code the spawner actually runs, not the multiplier alone.
	var late: Pest = _pest(Pest.APHID, Vector2(100.0, 100.0))
	var unscaled: float = late.max_health
	late.apply_wave_scaling(WaveDirector.health_scale_for(WaveDirector.WAVES.size()),
		WaveDirector.speed_scale_for(WaveDirector.WAVES.size()))
	err = _T.assert_float_eq(late.max_health,
		unscaled * WaveDirector.health_scale_for(WaveDirector.WAVES.size()), 0.0001,
		("a finale aphid really carries %.2f health rather than the species' %.2f"
			+ " -- Pest.apply_wave_scaling is the path Game takes, and its docstring"
			+ " still calls this an endless-only multiplier")
			% [late.max_health, unscaled])
	if err == "":
		err = _T.assert_float_eq(late.health, late.max_health, 0.0001,
			"and spawns with a full bar rather than reading as pre-damaged")
	if err == "":
		err = _T.assert_float_eq(late.speed, float(Pest.SPECIES[Pest.APHID]["speed"]), 0.0001,
			("at the unscaled species speed -- the finale's pests are tougher and not"
				+ " one pixel faster, which is what keeps every pacing number in"
				+ " wave_director.gd valid"))
	late.free()
	return err


# -- END the campaign's second act --------------------------------------------


# -- BEGIN what a death feels like (plant-tower-defense-6v39, -rowt) -----------
#
# Two cues on the one path every pest leaves the board by, `Pest.kill()`.
#
# -6v39: the kernel kill gets a knockback. Cycle 65 shipped a bitten corpse (narrower)
# and a blasted one (tilted) and left the kernel on the straight default so the two
# that differ would read as remarkable -- but a Corn Cobbler is the plant most players
# own most of the time, so the default was the majority of corpses a player ever sees
# and the moment of death said nothing. The shove is a third CHANNEL (position) rather
# than a third `_death_cause` value, so a corpse can be chewed AND shoved.
#
# -rowt: `DEATH_LINGER` was a flat 0.35s, so an armoured beetle that soaked four
# volleys left on the same beat as an aphid that took one. It is now scaled by
# `husk_multiplier()`, which is already the game's answer to "how much did this cost to
# deal with" -- the same number `Game._on_pest_died` reads for the husk and for
# `Sfx.kill_event_for`.
#
# Both live past `GardenTheme.animations_enabled()`, false for every test in this suite
# by construction, so both follow the rule the directional-animation block above
# states: the composition comes out into a pure static (`Pest.knockback_offset`,
# `Pest.death_linger_for`) and the result is recorded into a field written ABOVE the
# gate (`_death_knockback`, `_death_linger`), read back through `death_knockback()` and
# `death_linger()`. Deleting the shove from the kill goes red rather than going quiet.


## Every side, not just one: a sign error that is right for a kernel flying right is
## wrong for the other three, and the wrong sign here is a corpse thrown TOWARD the cob
## that shot it -- which still renders a perfectly plausible frame.
func test_a_kernels_knockback_is_aimed_away_from_the_shot_on_every_side() -> String:
	var kernel := Vector2(300.0, 200.0)
	var victims: Dictionary = {
		"right": kernel + Vector2(17.0, 0.0),
		"left": kernel + Vector2(-17.0, 0.0),
		"below": kernel + Vector2(0.0, 12.0),
		"above": kernel + Vector2(0.0, -12.0),
		"down-left": kernel + Vector2(-9.0, 11.0),
	}
	var err: String = ""
	for side: String in victims:
		var pest_at: Vector2 = victims[side]
		var shove: Vector2 = Pest.knockback_offset(kernel, pest_at)
		var onward: Vector2 = (pest_at - kernel).normalized()
		err = _T.assert_float_eq(shove.length(), Pest.DEATH_KNOCKBACK_PX, 0.001,
			"a %s hit shoves by exactly DEATH_KNOCKBACK_PX, got %.3f" % [side, shove.length()])
		if err != "":
			break
		# A unit dot of 1.0 is "the same way the kernel was travelling", and nothing
		# else scores it: a corpse thrown back at the shooter scores -1, one thrown
		# across the road scores 0.
		err = _T.assert_float_eq(shove.normalized().dot(onward), 1.0, 0.0001,
			"and carries the body ONWARD, not back at the cob (%s: shove %s, onward %s)"
				% [side, shove, onward])
		if err != "":
			break
	if err == "":
		# `Kernel._physics_process` is a centre-to-centre distance test, so a kernel
		# arriving exactly on a pest's centre is reachable and a normalize() there
		# would be a NaN riding into a Tween and a sprite position.
		err = _T.assert_eq(Pest.knockback_offset(kernel, kernel), Vector2.ZERO,
			"a hit dead on the centre shoves nowhere, not to NaN")
	if err == "":
		# A shove, not a throw. Past a quarter cell the corpse starts landing in the
		# square next door, and a husk the player is about to sweep is dropped at the
		# body's cell -- the picture and the click would stop agreeing.
		err = _T.assert_true(Pest.DEATH_KNOCKBACK_PX < float(Board.CELL) * 0.25,
			"and the corpse stays in the cell it died in (%.1f px against %.1f)"
				% [Pest.DEATH_KNOCKBACK_PX, float(Board.CELL) * 0.25])
	if err == "":
		# The slide has to be over before the fade begins, or the corpse is still
		# moving while it disappears -- two cues competing for the same beat.
		err = _T.assert_true(Pest.DEATH_KNOCKBACK_TIME < Pest.DEATH_LINGER - Pest.DEATH_FADE,
			"and has settled before the fade starts (%.2fs of a %.2fs hold)"
				% [Pest.DEATH_KNOCKBACK_TIME, Pest.DEATH_LINGER - Pest.DEATH_FADE])
	return err


## The reach half: the REAL kernel path composes the shove and the corpse really sits
## on it, whatever the animation gate says.
##
## Driven through `Kernel._physics_process` rather than by calling `take_damage`
## directly, because the thing being checked is that the kernel -- the only object in
## the game that knows which way the shot was travelling -- hands the direction over at
## all. A test that passed the vector in itself would pass with that line deleted.
##
## The frame-by-frame loop is deliberate: the kernel samples every SPEED*delta px
## (7.0 px at 60 Hz) against an 18 px radius, so it detects the pest while still SHORT
## of it. Stepping it in one big delta would park the kernel PAST the pest and record a
## backwards shove that the real game never produces.
func test_a_kernel_kill_shoves_the_corpse_along_the_shot_and_a_plain_kill_does_not() -> String:
	var pest: Pest = _pest(Pest.APHID, Vector2(200.0, 100.0))
	# One kernel's worth of life left, so the first hit is the killing one.
	pest.health = 0.5
	var kernel := Kernel.new()
	kernel.setup(Vector2(120.0, 100.0), Vector2.RIGHT, 5.0, Rect2(Vector2.ZERO, Vector2(896.0, 576.0)))
	# Stepped by hand below, the way the coverage simulation in this file drives them.
	kernel.set_physics_process(false)
	var host: Node2D = _host([pest, kernel])
	await _T.instantiate_scene(host)

	var err: String = _T.assert_eq(pest.death_knockback(), Vector2.ZERO,
		"a living pest is not already mid-knockback")
	var frames: int = 0
	# The pest WALKS while the kernel closes -- it is a live pest with its own
	# _physics_process -- so the body's own last position is the baseline, not the
	# spawn point. Comparing against the spawn point measures the gait, not the
	# knockback, and fails by ~1.3px for a reason that has nothing to do with the bead.
	var last_live: Vector2 = pest.position
	while err == "" and pest.is_alive() and frames < 60:
		last_live = pest.position
		kernel._physics_process(1.0 / 60.0)
		frames += 1
	if err == "":
		err = _T.assert_false(pest.is_alive(),
			"the kernel reached the pest and killed it (%d frames)" % frames)
	if err == "":
		err = _T.assert_float_eq(pest.death_knockback().length(), Pest.DEATH_KNOCKBACK_PX, 0.001,
			"and recorded a full-strength shove, got %s" % pest.death_knockback())
	if err == "":
		err = _T.assert_float_eq(pest.death_knockback().normalized().dot(Vector2.RIGHT), 1.0, 0.0001,
			("aimed the way the kernel was flying -- this cob shot rightward, so the body"
				+ " goes right (got %s)") % pest.death_knockback())
	if err == "":
		# The picture, not just the number. Animations are off here, so this IS the
		# corpse's resting state: a shove composed inside the Tween would read (0, 0).
		err = _T.assert_eq(pest._sprite.position, pest.death_knockback(),
			"and the corpse sprite is actually sitting there with animations off")
	if err == "":
		# The body itself must not have moved. `died` fires before `_play_death`, and
		# `Game._on_pest_died` drops the husk and files the lane loss at `pest.position`
		# -- a knockback on the Node2D would walk a husk off the cell it was earned on
		# and shift what the coverage and escape simulations in this file count.
		err = _T.assert_eq(pest.position, last_live,
			("while the pest node stays exactly where it fell -- the shove is a sprite"
				+ " offset. A body-level knockback would put this %.1fpx away")
				% Pest.DEATH_KNOCKBACK_PX)

	# And the straight corpse keeps its path, which is what leaves
	# `test_a_corpse_lies_differently_depending_on_what_killed_it` meaning something: a
	# Chomp's meal, a bomb's victim and any direct kill lie where they fell.
	if err == "":
		var chewed: Pest = _pest(Pest.APHID, Vector2(400.0, 300.0))
		host.add_child(chewed)
		chewed.kill(Pest.DEATH_BITTEN)
		err = _T.assert_eq(chewed.death_knockback(), Vector2.ZERO,
			"a chewed corpse is not shoved -- only a hit that arrived along a line is")
		if err == "":
			err = _T.assert_eq(chewed._sprite.position, Vector2.ZERO,
				"and its sprite is still centred on the body")
	_T.free_ui(host)
	return err


## Every husk multiplier the game can actually reach, derived from the mutation table
## and `mutations_compose` rather than from a list somebody has to remember to grow --
## the same derivation `test_selftest.gd`'s `_reachable_husk_values` uses, and for the
## same reason: the hand-written version of that one was wrong.
func _reachable_husk_multipliers() -> Array[float]:
	var seen: Dictionary = {1.0: true}
	for a: StringName in Pest.MUTATION_HUSK_MULTIPLIER:
		var ma: float = float(Pest.MUTATION_HUSK_MULTIPLIER[a])
		seen[ma] = true
		for b: StringName in Pest.MUTATION_HUSK_MULTIPLIER:
			if Pest.mutations_compose(a, b):
				seen[ma * float(Pest.MUTATION_HUSK_MULTIPLIER[b])] = true
	var out: Array[float] = []
	for m: float in seen:
		out.append(m)
	out.sort()
	return out


## A hard-won kill holds the screen longer than an easy one, across every price the
## game can actually charge.
func test_a_corpse_holds_in_proportion_to_what_the_kill_cost() -> String:
	var prices: Array[float] = _reachable_husk_multipliers()
	var err: String = _T.assert_gt(prices.size(), 2,
		"there is more than one price to tell apart (%d)" % prices.size())
	if err == "":
		err = _T.assert_float_eq(Pest.death_linger_for(1.0), Pest.DEATH_LINGER, 0.0001,
			"a plain pest leaves on exactly the beat it always did")
	var previous: float = 0.0
	for price: float in prices:
		if err != "":
			break
		var held: float = Pest.death_linger_for(price)
		err = _T.assert_gt(held, previous,
			"a %.2fx kill holds longer than every cheaper one (%.3fs against %.3fs)"
				% [price, held, previous])
		if err == "":
			# The fade is a fixed tail and the HOLD is what grows. If a scaled linger
			# ever dipped under DEATH_FADE the fade would swallow the whole beat and
			# `_play_death` would queue a negative interval.
			err = _T.assert_gt(held - Pest.DEATH_FADE, 0.0,
				"and still has a solid hold in front of its fade (%.3fs at %.2fx)"
					% [held - Pest.DEATH_FADE, price])
		previous = held
	if err == "":
		# Visibly different, which is the acceptance. A tenth of a second is roughly
		# the floor a player reads as "that one stayed"; the hardest pest today is
		# three times the plain beat.
		err = _T.assert_gt(Pest.death_linger_for(prices[prices.size() - 1]) - Pest.DEATH_LINGER, 0.1,
			"and the dearest kill outlasts the cheapest by an eyeful, not by a frame")
	if err == "":
		# The cap is not decoration: `husk_multiplier()` is a PRODUCT, so a fourth
		# mutation would multiply into it. Today nothing reaches the ceiling.
		err = _T.assert_gte(Pest.DEATH_LINGER_MAX_MULTIPLIER, prices[prices.size() - 1],
			("the cap is at or above the dearest kill the game can roll (%.2f against %.2f)"
				+ " -- below it and the mutation stops being felt")
				% [Pest.DEATH_LINGER_MAX_MULTIPLIER, prices[prices.size() - 1]])
	if err == "":
		err = _T.assert_float_eq(Pest.death_linger_for(99.0),
			Pest.DEATH_LINGER * Pest.DEATH_LINGER_MAX_MULTIPLIER, 0.0001,
			"and it really clamps, rather than documenting a clamp")
	if err == "":
		# Never faster than the default. A corpse that vanished quicker than a plain
		# one would read as the game dropping frames, not as an easy kill.
		err = _T.assert_float_eq(Pest.death_linger_for(0.1), Pest.DEATH_LINGER, 0.0001,
			"nothing leaves faster than the plain beat, whatever it is worth")
	if err == "":
		# `test_a_pest_killed_headless_is_eventually_freed` waits 600 frames for a
		# corpse to go. The longest one this can produce must sit comfortably inside
		# that, or a mutation shipped today fails a test written months ago.
		err = _T.assert_true(Pest.death_linger_for(Pest.DEATH_LINGER_MAX_MULTIPLIER) < 2.0,
			"and the longest corpse in the game is still under two seconds (%.2fs)"
				% Pest.death_linger_for(Pest.DEATH_LINGER_MAX_MULTIPLIER))
	return err


## The reach half, and the bead's acceptance verbatim: two pests of different difficulty
## killed in the same frame leave at different times.
##
## Through `kill()`, the one path every death takes, so the scaling cannot be deleted
## from it without this going red.
func test_two_pests_killed_in_one_frame_leave_at_different_times() -> String:
	var plain: Pest = _pest(Pest.APHID, Vector2(100.0, 100.0))
	var dear: Pest = _pest(Pest.APHID, Vector2(160.0, 100.0))
	var err: String = _T.assert_true(dear.apply_mutation(Pest.MUTATION_HUNGRY),
		"the second aphid really took the mutation")
	var host: Node2D = _host([plain, dear])
	await _T.instantiate_scene(host)

	if err == "":
		err = _T.assert_float_eq(plain.death_linger(), Pest.DEATH_LINGER, 0.0001,
			"a live pest reports the plain beat until something kills it")
	if err == "":
		err = _T.assert_gt(dear.husk_multiplier(), plain.husk_multiplier(),
			"the mutated one costs the player more to deal with")
	if err == "":
		# The same frame, one after the other, which is the comparison the acceptance
		# asks for -- not two runs with a stopwatch.
		plain.kill()
		dear.kill()
		err = _T.assert_float_eq(plain.death_linger(), Pest.DEATH_LINGER, 0.0001,
			"the plain corpse still leaves on the beat it always did")
	if err == "":
		err = _T.assert_gt(dear.death_linger(), plain.death_linger(),
			"and the dear one outstays it (%.3fs against %.3fs)"
				% [dear.death_linger(), plain.death_linger()])
	if err == "":
		# Exactly the price, not merely longer: the corpse and the husk are paid on the
		# same number, which is the whole argument for reusing husk_multiplier() here
		# instead of inventing a second measure of difficulty.
		err = _T.assert_float_eq(dear.death_linger() / plain.death_linger(),
			dear.husk_multiplier(), 0.0001,
			("the two lingers stand in exactly the ratio the two husks do (%.3f against %.3f)")
				% [dear.death_linger() / plain.death_linger(), dear.husk_multiplier()])
	if err == "":
		err = _T.assert_gt(dear.death_linger() - Pest.DEATH_FADE, 0.0,
			"and its fade is still a tail on the end of a solid hold")
	_T.free_ui(host)
	return err


# -- END what a death feels like -----------------------------------------------


# -- BEGIN what the board says is happening to this pest right now --------------
# plant-tower-defense-ayri (the cob points at its CURRENT target) and
# plant-tower-defense-wlyz (a pest the garden actually touched says so).


## Kernels living under `host` — the cob spawns them as its own SIBLINGS, so this is
## how "did it fire" is asked without a stopwatch.
func _kernels_under(host: Node) -> int:
	var found: int = 0
	for child: Node in host.get_children():
		if child is Kernel:
			found += 1
	return found


## The bead's first acceptance: a cob with a pest in range points at it BEFORE firing.
##
## Held deliberately off the trigger the whole way through — `_cooldown` is set well
## above zero and the kernel count is asserted at zero — because the old behaviour
## would pass any test that let a shot go off. `_aim_angle` was written in `_fire_at`
## and nowhere else, so "points at its target" and "just shot at its target" were the
## same observation, and only a cob that has NOT fired can tell them apart.
func test_a_cob_points_at_the_pest_it_will_shoot_before_it_shoots_it() -> String:
	var corn := CornCobbler.new()
	# OUT of RANGE for the settle. instantiate_scene pumps frames before the line
	# below can switch physics off, so an aphid parked in reach is already aimed at
	# by the time the "never seen a pest" assertion runs -- it read -PI/2, the exact
	# direction of a pest the test had put directly overhead. The precondition has to
	# survive the settle or it is not a precondition.
	var aphid: Pest = _pest(Pest.APHID, Vector2(0.0, -400.0))
	var host: Node2D = _host([corn, aphid])
	await _T.instantiate_scene(host)
	corn.set_physics_process(false)
	# Mid-reload. Nothing in this test is allowed to fire.
	corn._cooldown = 0.5

	var err: String = _T.assert_float_eq(corn.aim_angle(), 0.0, 0.0001,
		"a cob that has never seen a pest sits on its initial angle")
	# Now walk it into reach, by hand, with the cob frozen.
	aphid.position = Vector2(0.0, -100.0)
	var pests: Array[Pest] = [aphid]
	corn._act(0.016, pests)
	if err == "":
		err = _T.assert_eq(_kernels_under(host), 0,
			"no volley went off -- the cob is still most of a reload away")
	if err == "":
		# Due north of the cob: -Y is up, so the angle is -PI/2.
		err = _T.assert_float_eq(corn.aim_angle(), -PI * 0.5, 0.0005,
			"and it is ALREADY pointing at the pest standing north of it (%.1f deg)"
				% rad_to_deg(corn.aim_angle()))
	if err == "":
		# And it tracks, rather than latching the first thing it ever saw.
		aphid.position = Vector2(120.0, 120.0)
		corn._act(0.016, pests)
		err = _T.assert_float_eq(corn.aim_angle(), PI * 0.25, 0.0005,
			"the fan follows the pest round the cob with no shot in between (%.1f deg)"
				% rad_to_deg(corn.aim_angle()))
	if err == "":
		err = _T.assert_eq(_kernels_under(host), 0, "still without firing a kernel")
	if err == "":
		# The picture, not just the number: the drawn pip has to be on the pest's side
		# of the cob, which is the whole of what a player reads off this.
		var pips: PackedVector2Array = corn.muzzle_pip_positions()
		err = _T.assert_gt(pips.size(), 0, "the cob draws at least one pip")
		if err == "":
			err = _T.assert_gt(pips[0].x, 0.0,
				"and it sits on the same side of the cob as the pest (x = %.1f)" % pips[0].x)
		if err == "":
			err = _T.assert_gt(pips[0].y, 0.0, "on both axes")
	_T.free_ui(host)
	return err


## The fan and the volley are aimed at the SAME pest, driven through the real _act()
## with a decoy standing somewhere else entirely.
##
## This is the regression the fix could most easily have introduced: aiming and firing
## used to be one statement, and splitting them into "aim every tick, fire when armed"
## is exactly how a cob ends up drawing at one bug and shooting another.
func test_the_fan_and_the_volley_are_pointed_at_the_same_pest() -> String:
	var corn := CornCobbler.new()
	# `_furthest_along_in_range` keeps the first pest of equal progress, and `_pest`
	# gives every pest a two-point route, so both of these read progress 1.0 and the
	# chosen one is the one listed first. Deliberate: the point is that the DECOY is
	# somewhere the fan must not be.
	# Both parked OUT of RANGE (176) for the settle. instantiate_scene pumps frames
	# before physics can be switched off, so pests placed in reach let the cob fire a
	# whole volley of its own before the _act below -- the kernel count then reads two
	# volleys and the test fails on a number that has nothing to do with aiming.
	var chosen: Pest = _pest(Pest.APHID, Vector2(-420.0, 0.0))
	var decoy: Pest = _pest(Pest.APHID, Vector2(0.0, 420.0))
	var host: Node2D = _host([corn, chosen, decoy])
	await _T.instantiate_scene(host)
	corn.set_physics_process(false)
	corn._cooldown = 0.0
	# Walked into reach by hand, with the cob frozen.
	chosen.position = Vector2(-120.0, 0.0)
	decoy.position = Vector2(0.0, 120.0)

	var pests: Array[Pest] = [chosen, decoy]
	corn._act(0.016, pests)
	var err: String = _T.assert_eq(_kernels_under(host), corn.kernels_per_shot(),
		"the cob fired its whole volley")
	if err == "":
		err = _T.assert_float_eq(absf(corn.aim_angle()), PI, 0.0005,
			"and the fan is pointed due west at the pest it chose, not south at the decoy")
	var fired: Kernel = null
	for child: Node in host.get_children():
		if child is Kernel:
			fired = child as Kernel
			break
	if err == "":
		err = _T.assert_true(fired != null, "a kernel is on the board to read back")
	if err == "":
		err = _T.assert_float_eq(wrapf(fired._velocity.angle() - corn.aim_angle(), -PI, PI),
			0.0, 0.0005,
			("the kernel really flies down the line the fan is drawn on (%.2f deg apart)"
				% rad_to_deg(wrapf(fired._velocity.angle() - corn.aim_angle(), -PI, PI))))
	_T.free_ui(host)
	return err


## The bead's third acceptance, verbatim: "the redraw rate is measured, not assumed".
##
## A fan that follows its target is a repaint every physics tick unless something
## bounds it, on every cob on the board at once. AIM_STEPS is that bound and
## `aim_repaints()` is the count, so this walks a pest right across a cob's face and
## reads the actual number rather than trusting the constant's doc comment.
##
## The pest is MOVED BY HAND with physics off. A live pest walks itself, and a count
## taken while the suite's own frame pump moves it would be measuring the gait.
func test_the_fan_follows_a_walking_pest_without_repainting_every_frame() -> String:
	var corn := CornCobbler.new()
	var aphid: Pest = _pest(Pest.APHID, Vector2(-150.0, -60.0))
	var host: Node2D = _host([corn, aphid])
	await _T.instantiate_scene(host)
	corn.set_physics_process(false)
	# Never arms. Every repaint counted below belongs to the aim and nothing else.
	corn._cooldown = 1000.0

	# The bucketing itself first, as arithmetic: two angles inside one bucket are one
	# repaint, a full turn wraps back onto bucket zero rather than opening a 49th
	# nothing else can reach, and the count below is only worth reading if this holds.
	var bucket_width: float = TAU / float(CornCobbler.AIM_STEPS)
	var err: String = _T.assert_eq(CornCobbler.aim_step_for(0.0), 0,
		"due east is bucket zero")
	if err == "":
		err = _T.assert_eq(CornCobbler.aim_step_for(TAU), CornCobbler.aim_step_for(0.0),
			"a full turn wraps onto the same bucket rather than off the end")
	if err == "":
		err = _T.assert_eq(CornCobbler.aim_step_for(bucket_width * 0.2),
			CornCobbler.aim_step_for(0.0),
			"a fifth of a bucket is not a repaint")
	if err == "":
		err = _T.assert_eq(CornCobbler.aim_step_for(bucket_width * 4.0), 4,
			"and four buckets along is bucket four")
	if err != "":
		_T.free_ui(host)
		return err

	var pests: Array[Pest] = [aphid]
	var ticks: int = 240
	var first: float = 0.0
	var last: float = 0.0
	for i: int in range(ticks + 1):
		aphid.position = Vector2(lerpf(-150.0, 150.0, float(i) / float(ticks)), -60.0)
		corn._act(0.0, pests)
		if i == 0:
			first = corn.aim_angle()
		last = corn.aim_angle()

	var sweep: float = absf(wrapf(last - first, -PI, PI))
	var bucket: float = bucket_width
	var repaints: float = float(corn.aim_repaints())
	err = _T.assert_gt(sweep, 2.0,
		"the pest really crossed the cob's face (%.0f deg of sweep)" % rad_to_deg(sweep))
	if err == "":
		err = _T.assert_gt(corn.aim_repaints(), 1,
			"the fan really followed it -- a fan that never repainted is a fan nobody sees move")
	if err == "":
		# The bound, derived from the sweep rather than written down: one repaint per
		# bucket crossed, plus the two partial buckets at the ends.
		err = _T.assert_gte(sweep / bucket + 2.0, repaints,
			"%.0f repaints for %.1f buckets of sweep -- the aim is bucketed, not per-frame"
				% [repaints, sweep / bucket])
	if err == "":
		err = _T.assert_gt(repaints, sweep / bucket - 2.0,
			"and it did not skip buckets either (%.0f against %.1f)" % [repaints, sweep / bucket])
	if err == "":
		err = _T.assert_gt(float(ticks) * 0.25, repaints,
			"%.0f repaints across %d ticks is a fraction of a per-frame redraw"
				% [repaints, ticks])
	if err == "":
		# The other half of the tradeoff: a bucket has to be small enough that the fan
		# reads as turning rather than snapping. Measured at the pip, where it is seen.
		err = _T.assert_gt(6.0, CornCobbler.aim_step_pip_travel(CornCobbler.LEVELS.size()),
			"one bucket moves the widest pip %.1f px, which is a turn and not a jump"
				% CornCobbler.aim_step_pip_travel(CornCobbler.LEVELS.size()))
		if err == "":
			err = _T.assert_gt(CornCobbler.aim_step_pip_travel(CornCobbler.LEVELS.size()), 0.0,
				"and it does move -- a 0 px step is a frozen fan")
	_T.free_ui(host)
	return err


## plant-tower-defense-wlyz's acceptance: an escape distinguishes fought-and-survived
## from untouched, and the test drives both.
##
## `_ever_engaged` has known this since the run summary was written; what it has never
## had is a picture. Both halves are asserted here — the flag the summary counts and
## the mark the board draws — because the failure this is guarding against is the two
## drifting apart, i.e. a pest counted as fought in the post-mortem and drawn as
## untouched while the player could still have done something about it.
func test_an_escaping_pest_says_whether_the_garden_ever_touched_it() -> String:
	var fought: Pest = _pest(Pest.APHID, Vector2(100.0, 100.0))
	var untouched: Pest = _pest(Pest.APHID, Vector2(160.0, 100.0))
	var host: Node2D = _host([fought, untouched])
	await _T.instantiate_scene(host)

	var err: String = _T.assert_false(fought.shows_fought_mark(),
		"a pest arrives on the board bare")
	if err == "":
		err = _T.assert_false(untouched.shows_fought_mark(), "both of them")
	if err == "":
		fought.take_damage(1.0)
		err = _T.assert_true(fought.shows_fought_mark(),
			"one kernel that lands is enough to mark it")
	if err == "":
		err = _T.assert_true(fought.shows_fought_mark() == fought.was_engaged(),
			"and the mark says exactly what the summary counts")
	if err == "":
		err = _T.assert_false(untouched.shows_fought_mark(),
			"while the one nothing ever shot at is still bare")

	# The escape itself. `_escape()` emits and frees in the same frame, so the reading
	# has to happen inside the handler -- deferring it would get a freed instance,
	# which is the same reason Game._note_escape reads the flag where it does.
	var seen: Array = []
	fought.escaped.connect(func(p: Pest) -> void:
		seen.append([p.was_engaged(), p.shows_fought_mark()]))
	untouched.escaped.connect(func(p: Pest) -> void:
		seen.append([p.was_engaged(), p.shows_fought_mark()]))
	if err == "":
		# Past the end of its two-point route, which is the real escape path.
		fought._advance(1000.0)
		untouched._advance(1000.0)
		err = _T.assert_eq(seen.size(), 2, "both pests reached the exit")
	if err == "":
		err = _T.assert_true(bool(seen[0][0]) and bool(seen[0][1]),
			"the one that was fought leaves wearing the mark")
	if err == "":
		err = _T.assert_false(bool(seen[1][0]) or bool(seen[1][1]),
			"and the one that strolled past an empty road leaves bare")
	_T.free_ui(host)
	return err


## The case the health bar cannot report, which is the case the mark is worth drawing
## for: a Shield Bug whose plate ate the whole kernel.
##
## Nothing else on the board moves. The bar is full, the bug walks on, and "the garden
## is shooting this one and getting nowhere" and "nothing in the garden can reach this
## lane" look identical without the mark -- which is exactly the two sentences the bead
## is about, at the moment the player can still buy a different plant.
func test_a_hit_the_plate_ate_still_marks_the_pest_it_bounced_off() -> String:
	var bug: Pest = _pest(Pest.SHIELDBUG, Vector2(100.0, 100.0))
	var host: Node2D = _host([bug])
	await _T.instantiate_scene(host)

	var kernel: float = _top_kernel_damage()
	var before: float = bug.health
	var err: String = _T.assert_gt(Pest.shell_absorb(Pest.SHIELDBUG), kernel,
		"the plate eats the whole of the biggest kernel in the game (%.2f against %.2f)"
			% [Pest.shell_absorb(Pest.SHIELDBUG), kernel])
	if err == "":
		bug.take_damage(kernel)
		err = _T.assert_float_eq(bug.health, before, 0.0001,
			"so the health bar has nothing whatsoever to report")
	if err == "":
		err = _T.assert_true(bug.shows_fought_mark(),
			"and the mark is the only thing on the board saying the garden reached it")
	_T.free_ui(host)
	return err


## Being held counts, and it survives being let go.
##
## `_ever_engaged`'s own header argues this case: a Chomp destroyed mid-chew hands back
## a live pest at full health that had very much been fought. The mark has to make the
## same call, or a released bug walks the rest of the road looking untouched.
func test_a_pest_a_chomp_held_keeps_the_mark_after_it_is_let_go() -> String:
	var chomp := ChompFlower.new()
	var aphid: Pest = _prey(Pest.APHID, Vector2(0.0, -Board.CELL))
	var host: Node2D = _host([chomp, aphid])
	await _T.instantiate_scene(host)

	var pests: Array[Pest] = [aphid]
	chomp._act(0.016, pests)
	var err: String = _T.assert_true(chomp.is_busy(), "the Chomp closed on the aphid")
	if err == "":
		err = _T.assert_true(aphid.held_by != null, "and the aphid knows it is held")
	if err == "":
		# The pest's own frame is where being held is recorded -- `_pest` turns physics
		# off, so this is the one call that reaches it.
		aphid._physics_process(0.016)
		err = _T.assert_true(aphid.shows_fought_mark(),
			"a mouth closing on a pest marks it, even though a Chomp does no damage")
	if err == "":
		err = _T.assert_float_eq(aphid.health, aphid.max_health, 0.0001,
			"at full health, which is why the mark is the only record of it")
	if err == "":
		chomp.release()
		err = _T.assert_true(aphid.shows_fought_mark(),
			"and letting it go does not un-fight it")
	_T.free_ui(host)
	return err


## The mark's geometry, which is where it earns its place in `game/OVERLAY_GRAMMAR.md`
## rather than inventing an eleventh shape.
##
## It is the DASHED RING row -- "a REMARK about the thing inside it" -- applied to a
## pest for the first time, so what has to hold is the two things that row is
## distinguished by: the break (a solid ring at this size would read as a reach), and
## its position clear of every other mark a pest can wear at the same time. Both
## asserted with the colour thrown away, which is that document's one rule with teeth.
func test_the_fought_mark_is_a_broken_ring_clear_of_every_other_mark_on_a_pest() -> String:
	var dashes: PackedVector2Array = Pest.fought_ring_dashes()
	var err: String = _T.assert_eq(dashes.size(), Pest.FOUGHT_RING_DASHES,
		"the ring is drawn in %d dashes" % Pest.FOUGHT_RING_DASHES)
	if err == "":
		err = _T.assert_gt(dashes.size(), 2,
			"which is enough of them to read as a broken loop rather than as two arcs")
	var ink: float = 0.0
	for i: int in range(dashes.size()):
		if err != "":
			break
		var dash: Vector2 = dashes[i]
		err = _T.assert_gt(dash.y, dash.x, "dash %d covers an arc rather than a point" % i)
		ink += dash.y - dash.x
		if err == "" and i > 0:
			err = _T.assert_gt(dash.x, dashes[i - 1].y,
				("and there is a real gap in front of it -- the BREAK is the channel that "
					+ "survives the colour being thrown away (dash %d)") % i)
	if err == "":
		err = _T.assert_float_eq(ink, PI, 0.0001,
			"half the turn is ink and half is bare (%.3f of %.3f)" % [ink, TAU])
	if err == "":
		err = _T.assert_gt(TAU, dashes[dashes.size() - 1].y,
			"and the last dash closes inside one turn")

	# Every species at once, derived from SPECIES rather than a hand-list: a sixth
	# pest at a new sprite scale must not be able to ship wearing its remark inside
	# its own armour.
	var checked: int = 0
	for which: StringName in Pest.SPECIES:
		if err != "":
			break
		var scale: float = float(Pest.SPECIES[which]["scale"])
		var ring: float = Pest.fought_ring_radius(scale)
		var plate: float = Pest.SPRITE_HALF * scale * Pest.PLATE_OUTER
		err = _T.assert_gt(ring, plate,
			"%s wears the remark outside its armour plate (%.1f against %.1f)"
				% [which, ring, plate])
		if err == "":
			err = _T.assert_gt(ring, Pest.SPRITE_HALF * scale,
				"%s wears it outside its own silhouette too" % which)
		checked += 1
	if err == "":
		err = _T.assert_eq(checked, Pest.SPECIES.size(),
			"every species in the table was measured, not just the ones anyone remembered")
	return err


# -- END what the board says is happening to this pest right now ----------------


# =============================================================================
# BEGIN plant-tower-defense-sleq: the previous selection, held for comparison
#
# Selecting a second plant used to erase the first one's rings (game.gd:_select ->
# Plant.set_selected(false), which hides the brackets AND empties the sole-cover
# marks). The question a player actually has is comparative -- "which of these two
# should I move?" -- so the two things being compared were never on screen together.
#
# The held-over look is a THIRD STATE of the SUBJECT row in game/OVERLAY_GRAMMAR.md,
# not an eleventh shape: same corner brackets, two of the four corners drawn. Adding a
# row would fail test_the_legend_names_as_many_shapes_as_the_grammar_documents, and it
# would deserve to, because the shape has not changed.
#
# Everything here is asserted off pure statics -- SelectionMarker.bracket_corners and
# SelectionMarker.held_ink -- because GardenTheme.animations_enabled() is false for the
# whole suite and headless runs no _draw() at all. The composition lives above that gate
# so deleting the demotion goes red instead of quietly making the two states identical.


## The corner table, which is the whole cue. Four corners = the subject now; two
## diagonally opposite = the subject one click ago.
func test_the_held_over_subject_is_the_same_brackets_with_two_corners_missing() -> String:
	var live: Array[Vector2] = SelectionMarker.bracket_corners(false)
	var held: Array[Vector2] = SelectionMarker.bracket_corners(true)
	var err: String = _T.assert_eq(live.size(), 4,
		"the live subject is a closed box: four detached corners")
	if err == "":
		err = _T.assert_eq(held.size(), 2,
			"and the held-over one is the same box left open: two of them")
	# COUNT is the channel. Size is spent separating live (22) from the hover promise
	# (27), and colour is the channel this project's grammar forbids spending alone --
	# so if these two ever have the same number of corners the cue has no carrier left.
	if err == "":
		err = _T.assert_gt(live.size(), held.size(),
			("the two states differ in how many corners are drawn, which is the one "
				+ "channel left: size belongs to the hover promise and colour to nobody"))
	# Held is a SUBSET, not a different figure. A corner the live state never draws
	# would make this a new shape rather than the same one, incomplete.
	var subset: int = 0
	for corner: Vector2 in held:
		if err != "":
			break
		err = _T.assert_true(live.has(corner),
			"held corner %s is one the live brackets already draw" % corner)
		subset += 1
	if err == "":
		err = _T.assert_eq(subset, held.size(),
			"every held corner was checked, not just the first")
	# DIAGONALLY OPPOSITE. Two corners down one edge read as an arrow pointing
	# somewhere; opposite corners still describe a box, which is what the row means.
	if err == "":
		err = _T.assert_true((held[0] + held[1]).is_equal_approx(Vector2.ZERO),
			("the two are diagonally opposite (%s and %s) -- adjacent corners would "
				+ "read as an arrow rather than as an unfinished box")
				% [held[0], held[1]])
	# Signs only: the corners are multiplied by `half` and `arm` at paint time, so a
	# value that is not +-1 would put a bracket somewhere off the box entirely.
	var checked: int = 0
	for corner: Vector2 in live:
		if err != "":
			break
		err = _T.assert_float_eq(absf(corner.x), 1.0, 0.0001,
			"corner %s sits on the box's own x edge" % corner)
		if err == "":
			err = _T.assert_float_eq(absf(corner.y), 1.0, 0.0001,
				"and on its y edge, so `half` and `arm` put it on the box")
		checked += 1
	if err == "":
		err = _T.assert_eq(checked, live.size(), "every live corner was measured")
	return err


## The one rule with teeth: a cue must be legible when its colour is discarded. Held
## versus live has to differ in something that is not a hue and not an alpha.
func test_the_held_over_look_survives_its_colour_being_thrown_away() -> String:
	# held_ink is alpha-only by construction, and that is what proves alpha is the
	# SECOND channel rather than the carrier: the RGB is byte-identical, so a greyscale
	# read of the two states is the corner count and the ring radius and nothing else.
	var base := Color(0.2, 0.4, 0.8, 0.8)
	var dim: Color = SelectionMarker.held_ink(base, true)
	var err: String = _T.assert_float_eq(dim.r, base.r, 0.0001, "held ink keeps the red")
	if err == "":
		err = _T.assert_float_eq(dim.g, base.g, 0.0001, "and the green")
	if err == "":
		err = _T.assert_float_eq(dim.b, base.b, 0.0001,
			("and the blue -- shifting the hue would make the held plant a different "
				+ "statement instead of the same one, quieter"))
	if err == "":
		err = _T.assert_float_eq(dim.a, base.a * SelectionMarker.HELD_ALPHA_SCALE, 0.0001,
			"only the alpha moves, by HELD_ALPHA_SCALE")
	if err == "":
		err = _T.assert_gt(1.0, SelectionMarker.HELD_ALPHA_SCALE,
			"which dims rather than brightens (%.2f)" % SelectionMarker.HELD_ALPHA_SCALE)
	if err == "":
		err = _T.assert_gt(SelectionMarker.HELD_ALPHA_SCALE, 0.0,
			"and leaves the cue on screen rather than erasing it")
	# The live path must be untouched, or every existing assertion about MARKER_COLOR
	# and WARNING_COLOR is now asserting a slightly different colour.
	if err == "":
		err = _T.assert_eq(SelectionMarker.held_ink(base, false), base,
			("held_ink is the identity when nothing is held over -- the armed and "
				+ "selected colours the rest of the suite pins must not move"))
	# The brackets' own channel is the CORNER COUNT, which is what carries the state
	# once the colour is gone: four corners live against two held.
	if err == "":
		err = _T.assert_gt(SelectionMarker.bracket_corners(false).size(),
			SelectionMarker.bracket_corners(true).size(),
			("the held box is drawn from fewer corners than the live one (%d against "
				+ "%d), which is the reading a greyscale conversion cannot take away")
				% [SelectionMarker.bracket_corners(true).size(),
					SelectionMarker.bracket_corners(false).size()])
	return err


## The statics above describe a cue only if the paint calls actually read them. This is
## the source check that says so, structural so it survives the numbers being retuned --
## the same treatment test_placement.gd gives the uproot arc, and for the same reason:
## headless has no renderer, so no test in this suite can watch a _draw() run.
func test_the_held_over_demotion_is_what_the_cues_actually_paint() -> String:
	var marker_src: String = FileAccess.get_file_as_string("res://game/selection_marker.gd")
	var err: String = _T.assert_gt(marker_src.length(), 0,
		"selection_marker.gd is readable -- every check below is vacuous otherwise")
	if err != "":
		return err
	var brackets: int = marker_src.find("func _draw_brackets(")
	err = _T.assert_gt(brackets, 0, "the brackets have a painter")
	if err == "":
		var body: String = marker_src.substr(brackets)
		err = _T.assert_true(body.contains("bracket_corners("),
			("its corners come from bracket_corners() -- a nested sign loop here would "
				+ "leave the tested static describing a box nobody draws"))
		if err == "":
			err = _T.assert_true(body.contains("held_ink("),
				"and its ink from held_ink(), so the dimming is not a second rule")
	return err

## The two setters that carry the demoted look, driven rather than read.
##
## THEY LOST THEIR ONLY CALLER IN A TEST IN CYCLE 179 and nothing said so: the removed
## sole-cover checks were what named `set_held_over`, `held_over` and
## `Plant.set_uproot_armed`, so deleting a cue quietly took three live methods out of the
## suite's reach while every remaining assertion stayed green. `tools/suite_reach_check.py`
## is what noticed. Written as a DRIVE rather than a static read for that reason -- the
## statics above are already pinned, and what was actually lost was the only proof that
## the setter reaches the state.
func test_the_held_over_setters_reach_the_state_they_name() -> String:
	var marker := SelectionMarker.new()
	var err: String = _T.assert_false(marker.held_over,
		"a freshly built marker is LIVE -- a plant outside a Game is never demoted")
	if err == "":
		marker.set_held_over(true)
		err = _T.assert_true(marker.held_over, "set_held_over(true) reaches the state")
	if err == "":
		# Idempotence is the promise its header makes, and a second call returning early
		# must not undo the first.
		marker.set_held_over(true)
		err = _T.assert_true(marker.held_over,
			"and calling it again is idempotent rather than a toggle")
	if err == "":
		marker.set_held_over(false)
		err = _T.assert_false(marker.held_over, "and it restores the live look")
	marker.free()

	# The plant-side driver, which is the seam Game actually uses: arming is reached
	# through the Plant, not by touching the marker Game never holds a reference to.
	# `setup()` is what builds the cue children, the way test_placement.gd's sway check
	# reaches them.
	if err == "":
		var plant := Plant.new()
		plant.setup(PlantCatalog.CORN, Vector2i(3, 5), null)
		var live: SelectionMarker = plant.get_node_or_null(
			NodePath(SelectionMarker.NODE_NAME)) as SelectionMarker
		err = _T.assert_true(live != null,
			"the plant built its selection marker under the documented node name")
		if err == "":
			err = _T.assert_eq(live.marker_color, SelectionMarker.MARKER_COLOR,
				"and it starts in the unarmed ink")
		if err == "":
			plant.set_uproot_armed(true)
			err = _T.assert_eq(live.marker_color, SelectionMarker.WARNING_COLOR,
				("set_uproot_armed(true) reddens the brackets THROUGH the plant -- the "
					+ "only route Game has, since it never holds the marker itself"))
		if err == "":
			plant.set_uproot_armed(false)
			err = _T.assert_eq(live.marker_color, SelectionMarker.MARKER_COLOR,
				"and disarming puts the live ink back")
		plant.free()
	return err


# END plant-tower-defense-sleq: the previous selection, held for comparison
# =============================================================================


# =============================================================================
# BEGIN plant-tower-defense-r8zc / plant-tower-defense-l69v: the per-play wobble,
# and the husk cue that deliberately has none
#
# **Nothing below claims a sound was heard, and nothing below can.** `Sfx.play()`
# is gated off headless by `should_play`, so a suite cannot watch a voice start —
# the same limit the sound section at the top of this file states about itself.
# What these hold is the COMPOSITION: `Sfx.pitch_for` is a pure function of an
# event and a play index, so the number a voice would be given is assertable to
# the last decimal even though the noise is not. That is the whole reason the
# jitter is a static rather than a `randf_range` inside `play()`.
# =============================================================================


## The wobble exists, is bounded, and is centred (plant-tower-defense-r8zc).
##
## The mutation this is written to kill is the cheap one: delete the jitter term from
## `Sfx.pitch_for` and every table in `sfx.gd` stays perfectly valid, `JITTER` stays
## unique, `test_no_two_events_are_the_same_sound` stays green, and the player hears the
## identical sample at the identical pitch six times a second again. So this asserts the
## VARIATION rather than the table: 64 consecutive plays of a wobbled cue must produce 64
## different pitches.
##
## Three claims, and each one fails to a different breakage:
##   * distinct — a wobble that has been deleted or zeroed collapses all 64 onto the centre.
##   * inside the band — a wobble scaled by the wrong thing (a raw hash, a full semitone)
##     leaves the range `pitch_band` promises, and the twin check below is asserted against
##     that band rather than against whatever `pitch_for` happens to do.
##   * mean near the centre — a one-sided offset would detune the cue permanently rather
##     than vary it, which is a retune of `PITCH` by the back door.
##
## The events are read off `Sfx.JITTER`, not named, so a row added tomorrow is checked
## tomorrow.
func test_a_repeated_cue_never_settles_on_one_pitch() -> String:
	# Denominator first: an empty JITTER table would pass every loop below beautifully.
	var err: String = _T.assert_gt(Sfx.JITTER.size(), 0,
		"there are cues the game wobbles at all -- an empty JITTER makes this whole "
			+ "sweep vacuous, and deleting the table is exactly one of the breakages "
			+ "it is here to catch")
	if err != "":
		return err
	for event: StringName in Sfx.JITTER:
		var width: float = float(Sfx.JITTER[event])
		err = _T.assert_gt(width, 0.0,
			"'%s' has a real half-width -- a 0.0 row is an event that reads as wobbled "
				% event + "and is not, which is worse than no row at all")
		if err != "":
			return err
		var band: Vector2 = Sfx.pitch_band(event)
		var seen: Dictionary = {}
		var lowest: float = 999.0
		var highest: float = -999.0
		for index: int in range(64):
			var pitch: float = Sfx.pitch_for(event, index)
			seen[pitch] = true
			lowest = minf(lowest, pitch)
			highest = maxf(highest, pitch)
			if pitch < band.x - 0.000001 or pitch > band.y + 0.000001:
				return _T.assert_true(false,
					("play %d of '%s' came out at %.5f, outside the band %.5f..%.5f its "
						+ "JITTER row promises -- the twin check below is asserted "
						+ "against that band, so a pitch outside it is a collision "
						+ "nothing is watching for")
						% [index, event, pitch, band.x, band.y])
		err = _T.assert_eq(seen.size(), 64,
			("64 plays of '%s' are 64 different pitches, got %d -- a machine gun is "
				+ "exactly what a repeated identical pitch sounds like")
				% [event, seen.size()])
		if err != "":
			return err
		# And the spread is most of the band rather than a twitch in the middle of it.
		# A jitter narrowed to a hundredth of its row would still be 64 distinct floats.
		err = _T.assert_gte(highest - lowest, (band.y - band.x) * 0.75,
			("'%s' actually uses its band: 64 plays spanned %.5f of the %.5f it is "
				+ "allowed") % [event, highest - lowest, band.y - band.x])
		if err != "":
			return err
		# Centred, over enough plays for the average to mean something. A wobble that
		# only ever goes up is a retune of PITCH wearing a jitter's clothes.
		var total: float = 0.0
		for index: int in range(1024):
			total += Sfx.jitter_offset(event, index)
		err = _T.assert_float_eq(total / 1024.0, 0.0, 0.10,
			("'%s' wobbles both ways -- 1024 plays averaged %+.4f of its half-width, "
				+ "and a one-sided offset detunes the cue instead of varying it")
				% [event, total / 1024.0])
		if err != "":
			return err
	# The other side of the rule, and the one that keeps `PITCH` readable: a cue with no
	# row gets its table value EXACTLY, not a value plus a zero. `pitch_for` early-returns
	# for precisely this, and every event outside JITTER is checked for it.
	for event: StringName in Sfx.SOUNDS:
		if Sfx.JITTER.has(event):
			continue
		var centre: float = float(Sfx.PITCH.get(event, 1.0))
		for index: int in [0, 1, 7, 4137]:
			err = _T.assert_float_eq(Sfx.pitch_for(event, index), centre, 0.0000001,
				("'%s' has no JITTER row, so play %d is its PITCH centre to the bit -- "
					+ "a cue nobody asked to vary must not") % [event, index])
			if err != "":
				return err
	return err


## The wobble is a sequence, not a dice roll (plant-tower-defense-r8zc).
##
## `randf_range` was the obvious implementation and it is the wrong one twice over. A test
## could bound a random pitch but never name it, so "wobbling correctly" and "wobbling at
## all" would stop being distinguishable claims — and two people comparing what the game
## sounds like would be comparing two different games. So `jitter_offset` is a hash of the
## event id and the play index: same pair, same pitch, on every machine and every run.
##
## The literals below are the pin. They are not magic numbers to be updated when they fail:
## a change to them is a change to what the game sounds like, and it should have to be
## typed on purpose. The mixers are written out in `sfx.gd` rather than reaching for the
## engine's `hash()` for the same reason — `hash()` carries no cross-version promise, and a
## point release quietly reshuffling every cue's wobble is not a thing anyone would notice.
func test_the_wobble_is_the_same_wobble_on_every_machine() -> String:
	# Same input, same answer, twice — the floor a random implementation fails outright.
	var first: float = Sfx.pitch_for(Sfx.CORN_FIRED, 12)
	var err: String = _T.assert_float_eq(Sfx.pitch_for(Sfx.CORN_FIRED, 12), first, 0.0,
		"asking twice gives the same pitch to the bit -- randf_range does not")
	if err == "":
		# The pins. Recorded from the implementation, then checked against an independent
		# reimplementation of FNV-1a and lowbias32 outside the engine.
		err = _T.assert_float_eq(Sfx.jitter_offset(Sfx.CORN_FIRED, 0), 0.680650325, 0.000001,
			"CORN_FIRED's first play sits where it has always sat")
	if err == "":
		err = _T.assert_float_eq(Sfx.jitter_offset(Sfx.PEST_KILLED, 0), -0.221807225, 0.000001,
			"and so does PEST_KILLED's")
	if err == "":
		err = _T.assert_float_eq(Sfx.jitter_offset(Sfx.PEST_KILLED, 3), -0.288870673, 0.000001,
			"and the sequence advances the way it was recorded, not just its first step")
	if err == "":
		# Total, including the indices a long session or a negative reaches. An offset
		# that escapes [-1, 1] escapes the band `pitch_band` promises, which is what the
		# twin check trusts.
		for index: int in [-9, -1, 0, 1, 63, 1000003]:
			var offset: float = Sfx.jitter_offset(Sfx.PLANT_BITTEN, index)
			err = _T.assert_true(offset >= -1.0 and offset <= 1.0,
				"index %d answers inside [-1, 1], got %+.6f" % [index, offset])
			if err != "":
				return err
	if err == "":
		# Two cues must not step through one sequence together: a board where the corn
		# and the kills wobble in lockstep is a board with one wobble on it. The seeds
		# are what separate them, so the seeds are what is asserted, across the whole
		# table rather than for a chosen pair.
		var seeds: Dictionary = {}
		for event: StringName in Sfx.SOUNDS:
			var seed_value: int = Sfx.event_seed(event)
			if seeds.has(seed_value):
				return _T.assert_eq(str(event), str(seeds[seed_value]),
					("'%s' and '%s' seed the same wobble sequence, so they step through "
						+ "it together -- two cues varying in lockstep is one wobble, "
						+ "not two") % [event, seeds[seed_value]])
			seeds[seed_value] = event
		err = _T.assert_eq(seeds.size(), Sfx.SOUNDS.size(),
			"every event contributed its own wobble seed")
	if err == "":
		# And the implementation really is a hash rather than a die. Source-read, because
		# the absence of a call is not observable any other way — there is no state a
		# deleted `randf` leaves behind.
		var src: String = FileAccess.get_file_as_string("res://game/sfx.gd")
		err = _T.assert_gt(src.length(), 0, "sfx.gd is readable")
		if err == "":
			var start: int = src.find("static func jitter_offset(")
			err = _T.assert_gt(start, 0, "jitter_offset has a body to read")
			if err == "":
				var body: String = src.substr(start, src.find("\n\n\n", start) - start)
				err = _T.assert_false(body.contains("randf") or body.contains("randi"),
					("the wobble draws no random numbers -- one `randf_range` here makes "
						+ "every pin above unwritable and the game's sound "
						+ "unreproducible"))
	return err


## The twin rule, restated for a table that now has ranges in it
## (plant-tower-defense-r8zc).
##
## `test_no_two_events_are_the_same_sound` keys on the triple (file, volume, pitch) and is
## the only thing stopping two cues arriving at the player identically. The wobble makes
## that triple a statement about the CENTRES: two events on one file at one volume, 0.04
## apart in `PITCH`, would pass it while overlapping on some pair of plays. So that check
## keeps its job — the table is unique — and this one adds the half it can no longer see:
## the RANGES are disjoint, by `Sfx.MIN_TWIN_PITCH_GAP`, for every pair that shares both a
## file and a volume.
##
## Pairs that differ in volume are deliberately not checked. Volume is the other axis of
## the same triple and it separates them on its own — `WAVE_CLEARED` and `RUN_WON` are the
## same jingle at the same centre and are told apart at 5 dB, which is the table's own
## long-standing answer.
##
## Derived from `SOUNDS`, so an event added to a shared file tomorrow is checked against
## every wobble already on that file.
func test_two_events_on_one_file_never_overlap_once_they_wobble() -> String:
	var events: Array[StringName] = []
	for event: StringName in Sfx.SOUNDS:
		events.append(event)
	var err: String = _T.assert_gt(events.size(), 20,
		"the table is populated -- an empty sweep is a vacuous pass, got %d" % events.size())
	if err != "":
		return err
	# Denominator: this proves nothing unless files really are shared. If every event
	# had its own file the loop below would examine zero pairs and pass.
	var pairs: int = 0
	var tightest: float = 999.0
	for i: int in range(events.size()):
		for j: int in range(i + 1, events.size()):
			var a: StringName = events[i]
			var b: StringName = events[j]
			if String(Sfx.SOUNDS[a]).get_file() != String(Sfx.SOUNDS[b]).get_file():
				continue
			if not is_equal_approx(
					float(Sfx.VOLUME_DB.get(a, 0.0)), float(Sfx.VOLUME_DB.get(b, 0.0))):
				continue
			pairs += 1
			var band_a: Vector2 = Sfx.pitch_band(a)
			var band_b: Vector2 = Sfx.pitch_band(b)
			# Signed on purpose: two bands that overlap give a negative clearance and
			# fail loudly, rather than an absolute distance that reads as a pass.
			var clearance: float = band_a.x - band_b.y
			if band_b.x > band_a.y:
				clearance = band_b.x - band_a.y
			tightest = minf(tightest, clearance)
			err = _T.assert_gte(clearance, Sfx.MIN_TWIN_PITCH_GAP,
				("'%s' (%.3f..%.3f) and '%s' (%.3f..%.3f) are the same file at the same "
					+ "volume and leave %.3f between their pitch bands -- under "
					+ "MIN_TWIN_PITCH_GAP (%.3f) they can arrive at the player as one "
					+ "sound on some pair of plays, which the (file, volume, pitch) "
					+ "triple check cannot see")
					% [a, band_a.x, band_a.y, b, band_b.x, band_b.y, clearance,
						Sfx.MIN_TWIN_PITCH_GAP])
			if err != "":
				return err
	err = _T.assert_gt(pairs, 0,
		"events really do share files -- with none shared this whole check is vacuous "
			+ "and so is the palette argument in SOUNDS' comments")
	if err == "":
		# The budget, printed as an assertion rather than left implicit: a future JITTER
		# row has this much room before it starts eating a twin's separation.
		err = _T.assert_gte(tightest, Sfx.MIN_TWIN_PITCH_GAP,
			"the tightest same-file same-volume pair leaves %.3f, against the %.3f floor"
				% [tightest, Sfx.MIN_TWIN_PITCH_GAP])
	return err


## The wobble reaches the voice, and the play index reaches the wobble
## (plant-tower-defense-r8zc).
##
## `pitch_for` being correct is worth nothing if nothing calls it — that is the exact
## failure cycle 74 recorded, where `PITCH` stayed unique while `play()` had stopped
## reading it and the player heard twins. `tune_voice` is the seam a headless test can
## hold, so the first half is asserted through a real `AudioStreamPlayer`.
##
## The second half cannot be: `play()` is behind the headless gate, so nothing here can
## watch it advance `_play_count` and hand the index down. That half is source-read, which
## is weaker and is why it is stated rather than hidden — it catches `tune_voice(voice,
## event)` being restored in `play()`, which would freeze every cue on index 0 forever
## while every assertion above stayed green.
func test_the_voice_a_play_tunes_actually_carries_the_wobble() -> String:
	var voice := AudioStreamPlayer.new()
	Sfx.tune_voice(voice, Sfx.CORN_FIRED, 0)
	var first: float = voice.pitch_scale
	Sfx.tune_voice(voice, Sfx.CORN_FIRED, 1)
	var second: float = voice.pitch_scale
	var err: String = _T.assert_true(first != second,
		("two plays of one cue put two different pitches on the voice, got %.5f twice "
			+ "-- tune_voice is the only place a voice's pitch is written, so if the "
			+ "wobble does not arrive here it does not arrive at all") % first)
	if err == "":
		err = _T.assert_float_eq(second, Sfx.pitch_for(Sfx.CORN_FIRED, 1), 0.0000001,
			"and it is the composed pitch, not a second rule living in tune_voice")
	if err == "":
		# The default the existing two-argument callers get. Not zero-jitter: index 0 is
		# a real play of the sequence, and a caller that does not care which play it is
		# gets the first one rather than a fourth behaviour nobody documented.
		Sfx.tune_voice(voice, Sfx.CORN_FIRED)
		err = _T.assert_float_eq(voice.pitch_scale, first, 0.0000001,
			"an omitted index means play 0, so no existing caller changed meaning")
	if err == "":
		# A cue with no row is still exactly its table value through the same seam --
		# the pooled-voice reuse hazard tune_voice was written for, now with a fourth
		# table able to leave something behind.
		Sfx.tune_voice(voice, Sfx.CORN_FIRED, 5)
		Sfx.tune_voice(voice, Sfx.SUNDEW_CLAIM, 5)
		err = _T.assert_float_eq(voice.pitch_scale, float(Sfx.PITCH.get(Sfx.SUNDEW_CLAIM, 1.0)),
			0.0000001, "a voice borrowed by an unwobbled cue carries none of the last "
				+ "cue's wobble forward, got %.5f" % voice.pitch_scale)
	voice.free()
	if err == "":
		var src: String = FileAccess.get_file_as_string("res://game/sfx.gd")
		err = _T.assert_gt(src.length(), 0, "sfx.gd is readable")
		if err == "":
			var start: int = src.find("static func play(event: StringName)")
			err = _T.assert_gt(start, 0, "play() has a body to read")
			if err == "":
				var body: String = src.substr(start, src.find("\n\n\n", start) - start)
				err = _T.assert_true(body.contains("_play_count"),
					("play() advances the event's own play count -- without it every "
						+ "cue is frozen on index 0 and the wobble is a constant that "
						+ "every check above still passes"))
				if err == "":
					err = _T.assert_true(body.contains("tune_voice(voice, event, index)"),
						"and hands that index to tune_voice, which is the only route "
							+ "the wobble has to a voice")
	return err


## Every wobbled cue is one the game actually repeats (plant-tower-defense-r8zc).
##
## `JITTER`'s membership rule is "a cue ONE source repeats faster than about once a
## second", and a rule stated only in a comment is a rule that expires quietly. This pins
## it to the constants it was derived from, so slowing the Corn Cobbler down or lengthening
## a Nettle's sting fails here rather than leaving a row whose justification has gone.
##
## Two kinds of cue, checked two ways, because they have two kinds of rate:
##   * a cue one plant fires on its own clock, where the rate is that plant's constant;
##   * a cue the whole BOARD produces, where no single constant is the rate and the
##     `REPEAT_MS` gate is the real ceiling on how fast the player hears it.
##
## What this does NOT check: that a cue outside `JITTER` deserves to be. There is no table
## anywhere that says how often `RUN_WON` fires, so the exclusions are argued in `JITTER`'s
## own comment and only the two that were genuinely close are pinned below.
func test_every_wobbled_cue_is_one_the_game_actually_repeats() -> String:
	var err: String = _T.assert_gt(Sfx.JITTER.size(), 0, "there are rows to check")
	if err != "":
		return err
	# The plant-clock cues. Each number is the constant JITTER's comment cites.
	var clocks: Dictionary = {
		Sfx.CORN_FIRED: float(CornCobbler.LEVELS[CornCobbler.LEVELS.size() - 1]["interval"]),
		Sfx.DANDELION_PUFF: Dandelion.SHOT_INTERVAL,
		Sfx.NETTLE_STING: Nettle.STING_INTERVAL,
		Sfx.SEED_BOMB_BURST: Dandelion.SHOT_INTERVAL,
	}
	for event: StringName in clocks:
		err = _T.assert_true(Sfx.JITTER.has(event),
			"'%s' is wobbled -- it is on this list because its source has a clock" % event)
		if err != "":
			return err
		err = _T.assert_true(float(clocks[event]) < 1.0,
			("'%s' really does repeat faster than once a second: its source fires every "
				+ "%.2fs. If this fails the cue got slower and its JITTER row is now "
				+ "decoration on a sound nobody hears twice in a breath")
				% [event, float(clocks[event])])
		if err != "":
			return err
	# The board-rate cues, where the gate is the rate. Read off REPEAT_MS rather than
	# retyped, so retuning a gate is checked against the row it justifies.
	for event: StringName in [Sfx.PEST_KILLED, Sfx.PEST_KILLED_HARD, Sfx.PLANT_BITTEN]:
		err = _T.assert_true(Sfx.JITTER.has(event), "'%s' is wobbled" % event)
		if err != "":
			return err
		err = _T.assert_true(Sfx.REPEAT_MS.has(event),
			("'%s' has a REPEAT_MS row -- for a board-rate cue that gate IS the rate, "
				+ "and without one the claim in JITTER's comment has no number behind it")
				% event)
		if err != "":
			return err
		err = _T.assert_true(int(Sfx.REPEAT_MS[event]) < 1000,
			"'%s' can be heard again inside a second (%dms)" % [event, int(Sfx.REPEAT_MS[event])])
		if err != "":
			return err
	# Every row points at a real cue. `sfx_call_check.py` gates this statically too; it is
	# repeated here because a key JITTER holds and SOUNDS does not is swallowed in silence
	# by `JITTER.get(event, 0.0)`, exactly as a stale PITCH key would be.
	for event: StringName in Sfx.JITTER:
		err = _T.assert_true(Sfx.SOUNDS.has(event),
			"'%s' has a JITTER row and no sound -- a wobble on nothing" % event)
		if err != "":
			return err
	# And the kill pair's narrower width, which is the one magnitude with a second
	# constraint on it: the whole interval carrying "that one was expensive" is 0.12, so
	# the two wobbles together must not eat it.
	var plain: float = float(Sfx.JITTER.get(Sfx.PEST_KILLED, 0.0))
	var hard: float = float(Sfx.JITTER.get(Sfx.PEST_KILLED_HARD, 0.0))
	var interval: float = absf(float(Sfx.PITCH.get(Sfx.PEST_KILLED_HARD, 1.0))
		- float(Sfx.PITCH.get(Sfx.PEST_KILLED, 1.0)))
	return _T.assert_gte(interval - plain - hard, Sfx.MIN_TWIN_PITCH_GAP,
		("a hard kill stays audibly above a plain one under the wobble: %.3f of interval "
			+ "less %.3f and %.3f of wobble leaves %.3f, against the %.3f floor")
			% [interval, plain, hard, interval - plain - hard, Sfx.MIN_TWIN_PITCH_GAP])


## The husk sweep is deliberately NOT wobbled and deliberately NOT value-pitched
## (plant-tower-defense-l69v, closed unimplemented).
##
## The bead asked whether a rich husk should sound rich. The answer recorded here is no,
## and the reason is not that it is hard — `Sfx.kill_event_for` is the pattern and a
## `husk_event_for(value)` beside it would have been six lines. It is that pitch cannot
## carry this particular fact:
##
##   * A kill and its sweep are seconds apart. `CompostMeter.lifetime_for` runs from
##     `HUSK_LIFETIME` down to `MIN_HUSK_LIFETIME`, so the richest husk — the one the cue
##     would be about — must be swept within 4.5s of the kill or it rots. Every pitch pair
##     already in `PITCH` works because both halves are common and heard against each
##     other; a sweep's only reference is the previous sweep, seconds ago and under a wave.
##   * Wide enough to survive that gap, a pitch shift on `handleCoins.ogg` stops reading as
##     "a bigger payout" and starts reading as a different coin — which is what `PITCH`'s
##     header says pitch MEANS in this table, and it would collide semantically with
##     `SEEDS_GROWN`, the other consumer of that file.
##   * It arrives after the decision it would inform. The husk's value cue exists so a
##     player sweeps the rich one first; `HUSK_COLLECTED` plays once the click is spent.
##
## The visual channel already carries it in the window where it is actionable, and this
## asserts that rather than asserting the absence of a feature: radius, glow and — above
## the point where both of those saturate — pip count. If that ever stops being true, the
## question this bead asked reopens, and it reopens here.
func test_a_husks_value_is_carried_by_the_husk_and_not_by_its_sweep() -> String:
	# No wobble and no second event id on the sweep. Both would be additions nobody
	# argued for; a row appearing here should have to argue with this test.
	var err: String = _T.assert_false(Sfx.JITTER.has(Sfx.HUSK_COLLECTED),
		("the sweep is unwobbled -- it is player-paced, not a stream, and its pitch was "
			+ "examined and declined in plant-tower-defense-l69v"))
	if err == "":
		var husk_ids: int = 0
		for event: StringName in Sfx.SOUNDS:
			if String(event).begins_with("husk_"):
				husk_ids += 1
		err = _T.assert_eq(husk_ids, 2,
			("there are exactly two husk cues, collected and rotted -- a third id would "
				+ "be the value-pitched sweep this bead closed against, got %d")
				% husk_ids)
	if err == "":
		# The gap the decision turns on, asserted as the bound it actually is. No median
		# was measured -- driving a wave needs a running game -- but the ceiling is what
		# the argument uses, and the ceiling is in the code.
		var cheap: float = CompostMeter.lifetime_for(CompostMeter.BASE_VALUE)
		var rich: float = CompostMeter.lifetime_for(CompostMeter.FULL_VALUE)
		err = _T.assert_gte(rich, 1.0,
			("a rich husk gives the player whole seconds to sweep it (%.1fs) -- if this "
				+ "ever became a fraction of a second the kill and the sweep would be one "
				+ "moment and a pitch pair between them would start working") % rich)
		if err == "":
			err = _T.assert_true(rich < cheap,
				("and the rich one is the SHORTER window (%.1fs against %.1fs), which is "
					+ "why its cue has to be legible before the click rather than after "
					+ "it") % [rich, cheap])
	if err == "":
		# The channel that does carry it, in the window where it is actionable. Three
		# steps, because the first two saturate: this is the whole "size and glow already
		# say it" alternative the bead named, checked rather than repeated.
		var base_radius: float = HuskLayer.radius_for(CompostMeter.BASE_VALUE)
		var full_radius: float = HuskLayer.radius_for(CompostMeter.FULL_VALUE)
		err = _T.assert_gt(full_radius, base_radius,
			"a rich husk is drawn bigger than a cheap one (%.1f vs %.1f)"
				% [full_radius, base_radius])
		if err == "":
			err = _T.assert_gt(HuskLayer.glow_for(CompostMeter.FULL_VALUE),
				HuskLayer.glow_for(CompostMeter.BASE_VALUE),
				"and brighter")
		if err == "":
			# Above FULL_VALUE both of those are flat, so the visual answer is complete
			# only because of the pips. If it were not, the audio question would be open.
			var saturated: int = CompostMeter.FULL_VALUE * 3
			err = _T.assert_float_eq(HuskLayer.radius_for(saturated), full_radius, 0.0001,
				"radius really has saturated by %d seeds, which is what makes the pips "
					% saturated + "load-bearing rather than a flourish")
			if err == "":
				err = _T.assert_gt(HuskLayer.overflow_pips(saturated),
					HuskLayer.overflow_pips(CompostMeter.FULL_VALUE),
					("and the pips carry the range above it -- with these flat too, "
						+ "nothing would distinguish a 9-seed husk from a 60-seed one "
						+ "and plant-tower-defense-l69v would deserve another look"))
	return err

# END plant-tower-defense-r8zc / plant-tower-defense-l69v
# =============================================================================


# =============================================================================
# BEGIN plant-tower-defense-kmjp: what rain pays, now that drought pays 150%
#
# The bead's premise was FALSE and that is the finding: it said rain "heals pests"
# and was therefore the only weather with a downside and no compensation. Rain heals
# PLANTS -- `Game._apply_weather` calls `plant.heal(...)` on every plant Game owns --
# and nothing in the game applies a weather term to a pest at all. So rain has no
# downside to compensate, no number moved, and the decision is written at
# `WaveDirector.WEATHER_RAIN_HEAL_FRACTION` with the three refused alternatives.
#
# What the bead's ACCEPTANCE clause still wanted is real and is not a number: every
# weather's upside must be named before the wave commits. These tests pin the half
# that is true today and the invariant a fourth weather would have to satisfy.


## Every weather in the game gives the player something, and exactly one gives nothing
## because it also asks for nothing.
##
## The set is DERIVED from `WaveDirector.weather_for` rather than typed, so a fourth
## state added to that function arrives in this test on its own and has to answer the
## same question. "Gives something" is derived too, from the three pure per-weather
## functions -- and `heal_fraction_for` exists so that this sentence can be written
## without a branch that already knows the answer involves rain.
func test_no_weather_asks_for_something_and_gives_nothing_back() -> String:
	var seen: Array[StringName] = []
	for wave: int in range(1, 101):
		var state: StringName = WaveDirector.weather_for(wave)
		if not seen.has(state):
			seen.append(state)
	var err: String = _T.assert_eq(seen.size(), 3,
		("the first hundred waves produce three distinct weathers, got %d (%s). That is "
			+ "the denominator every assertion below divides by -- a sweep that found one "
			+ "state would pass the loops underneath while checking nothing")
			% [seen.size(), seen])
	if err == "":
		# The weathers that give nothing, collected rather than assumed. Exactly one may
		# be here, and it has to be the one that asks for nothing either.
		var giftless: Array[StringName] = []
		var costly_and_giftless: Array[StringName] = []
		for state: StringName in seen:
			var gives: bool = (WaveDirector.seed_multiplier_for(state) > 1.0
				or WaveDirector.heal_fraction_for(state) > 0.0)
			var costs: bool = WaveDirector.fire_interval_scale_for(state) > 1.0
			if not gives:
				giftless.append(state)
			if costs and not gives:
				costly_and_giftless.append(state)
		err = _T.assert_eq(costly_and_giftless.size(), 0,
			("no weather slows the garden without paying for it: %s. This is the whole of "
				+ "plant-tower-defense-kmjp's acceptance criterion as arithmetic")
				% [costly_and_giftless])
		if err == "":
			err = _T.assert_eq(giftless.size(), 1,
				("and exactly one weather has nothing to offer, got %s -- two would mean a "
					+ "state the player is asked to notice and given no reason to want")
					% [giftless])
		if err == "":
			err = _T.assert_eq(String(giftless[0]), String(WaveDirector.WEATHER_CLEAR),
				("and it is clear: the baseline rather than a state, which is also why it "
					+ "is the one weather `Hud.show_weather` refuses to announce"))
	if err == "":
		err = _T.assert_float_eq(
			WaveDirector.fire_interval_scale_for(WaveDirector.WEATHER_CLEAR), 1.0, 0.0001,
			"and clear really does ask for nothing, which is what earns it the exemption")
	return err


## Rain gives and never takes, which is the sentence the bead denied.
##
## Asserted on all three per-weather functions at once rather than on the heal alone:
## the claim being refuted is "rain has a downside", and a downside would have to appear
## in the interval scale or the seed multiplier, so both are named here as zeroes.
func test_rain_gives_and_never_takes_which_is_why_no_number_moved() -> String:
	var err: String = _T.assert_gt(
		WaveDirector.heal_fraction_for(WaveDirector.WEATHER_RAIN), 0.0,
		"rain gives health back (%.2f of maximum)"
			% WaveDirector.heal_fraction_for(WaveDirector.WEATHER_RAIN))
	if err == "":
		err = _T.assert_float_eq(
			WaveDirector.fire_interval_scale_for(WaveDirector.WEATHER_RAIN), 1.0, 0.0001,
			("and takes nothing off the rate of fire -- a rain that slowed the garden is "
				+ "the downside the bead reported and it does not exist"))
	if err == "":
		err = _T.assert_float_eq(
			WaveDirector.seed_multiplier_for(WaveDirector.WEATHER_RAIN), 1.0, 0.0001,
			("and nothing off the seed rate either. Paying rain LESS than clear was the "
				+ "first alternative refused: it would make clear the punished state, and "
				+ "clear is eleven waves in twelve"))
	if err == "":
		# The other side of the pair, so the refusal has both halves on the record: a
		# drought is the weather that costs, and it is the one that pays.
		err = _T.assert_gt(
			WaveDirector.fire_interval_scale_for(WaveDirector.WEATHER_DROUGHT), 1.0,
			"a drought is the weather that costs")
		if err == "":
			err = _T.assert_gt(
				WaveDirector.seed_multiplier_for(WaveDirector.WEATHER_DROUGHT), 1.0,
				"and the one that pays for it, which is the shape rain never needed")
		if err == "":
			err = _T.assert_float_eq(
				WaveDirector.heal_fraction_for(WaveDirector.WEATHER_DROUGHT), 0.0, 0.0001,
				"while a drought heals nothing, so the two gifts do not overlap")
	return err


## A weather's compensation has to be legible while the player can still act on it.
##
## The prep note is that surface: it is the message row's idle state through the whole
## prep gap, BEFORE the wave commits, which is when seeds are spent. The banner
## (`Hud.weather_note`) fires from `Game._on_wave_started` -- after.
##
## Both halves are asserted here and both pass. Rain's was the open one until cycle 110:
## `next_wave_note` appended a bare "rain" and said nothing about the 35% it hands back,
## so the only weather whose upside costs nothing was also the only one the player was
## never told about in time to use it. The lane that found this could not fix it -- the
## clause lives in `Hud.next_wave_note`, which it did not own -- so it wrote the edit out
## and the parent landed the two together.
##
## Worth keeping about the shape of that gap: rain's gift is CONDITIONAL and often zero,
## because a full-health garden mends nothing. That is what made it invisible rather than
## merely unmentioned -- a player could sit through several rain waves and correctly
## observe that rain did nothing, on exactly the waves where it would have paid least.
## Told three waves out, they can leave a chewed Corn standing instead of uprooting at a
## refund and paying full price again, which is the decision the sentence exists to buy.
func test_a_compensation_is_named_where_the_player_can_still_act_on_it() -> String:
	var note: String = Hud.next_wave_note(21, 30, false, WaveDirector.WEATHER_DROUGHT)
	var percent: String = "%d%%" % int(round(WaveDirector.WEATHER_DROUGHT_SEED_BONUS * 100.0))
	var err: String = _T.assert_true(note.contains("drought"),
		"the prep note names the weather that is coming: %s" % note)
	if err == "":
		err = _T.assert_true(note.contains(percent),
			("and the number it pays (%s), derived from WEATHER_DROUGHT_SEED_BONUS rather "
				+ "than typed -- retuning the bonus without retuning the sentence is the "
				+ "drift this pins. Got: %s") % [percent, note])
	if err == "":
		# The rain half, closed. The gift is written on the banner AND in the prep note,
		# and only the second reaches the player while they can still act on it.
		var rain: String = Hud.next_wave_note(20, 26, false, WaveDirector.WEATHER_RAIN)
		var mend: String = "%d%%" % int(round(WaveDirector.WEATHER_RAIN_HEAL_FRACTION * 100.0))
		err = _T.assert_true(rain.contains(mend),
			("the prep note names what rain hands back (%s), derived from "
				+ "WEATHER_RAIN_HEAL_FRACTION rather than typed. Got: %s") % [mend, rain])
		if err == "":
			err = _T.assert_true(rain.length() < note.length(),
				("and its clause is shorter than drought's (%d chars against %d), which is "
					+ "why the message row's worst case is still the drought sample in "
					+ "Hud.message_corpus()") % [rain.length(), note.length()])
		if err == "":
			err = _T.assert_gt(Hud.weather_note(WaveDirector.WEATHER_RAIN).length(), 0,
				"and the banner still says it too, as the wave opens")
		if err == "":
			err = _T.assert_eq(Hud.weather_note(WaveDirector.WEATHER_CLEAR), "",
				("while clear says nothing on either surface, which is the exemption "
					+ "test_no_weather_asks_for_something_and_gives_nothing_back earns it"))
	return err

# END plant-tower-defense-kmjp
# =============================================================================


# =============================================================================
# BEGIN plant-tower-defense-bt5i: whether a drought should slow the non-shooters
#
# The bead's numbers were stale and its substance was live. It said
# Plant.fire_interval_scale is read by CornCobbler and Dandelion only -- two plants
# of five. It is read by THREE of EIGHT: Nettle reads it too, and Nettle, Mint and
# Aloe did not exist when the bead was written. What was true then and is still true
# is that the split was an accident of which files happened to read the field.
#
# The decision is NO EXTENSION -- a drought lengthens a repeating attack interval and
# nothing else -- and it is written per-plant at
# WaveDirector.WEATHER_DROUGHT_INTERVAL_SCALE. This is the gate that stops it being
# an accident again: the affected set is derived from the plant scripts rather than
# recorded, so a ninth plant that starts reading the field, or a Nettle that quietly
# stops, fails against that paragraph instead of extending it in silence.


## The set a drought reaches, derived rather than recorded.
##
## Source of truth is `PlantCatalog.ids()` and the plant scripts themselves -- the ids
## ARE the script basenames, and the readability check below is what turns a broken
## mapping into a failure instead of into an empty set that agrees with everything.
##
## Comments are stripped before the search on purpose: all three affected files also
## DESCRIBE `fire_interval_scale` in a doc comment next to the line that reads it, and a
## raw scan would credit any future plant whose header merely mentions the field. This is
## the same trap `tools/gdsource.py` exists for.
func test_a_drought_slows_what_the_garden_shoots_and_nothing_else() -> String:
	var ids: Array[StringName] = PlantCatalog.ids()
	var err: String = _T.assert_gt(ids.size(), 0,
		"the catalogue has plants in it, or every loop below is vacuous")
	if err != "":
		return err
	var slowed: PackedStringArray = []
	var unreadable: PackedStringArray = []
	var read: int = 0
	for id: StringName in ids:
		var path: String = "res://game/%s.gd" % String(id)
		var src: String = FileAccess.get_file_as_string(path)
		if src.length() == 0:
			unreadable.append(path)
			continue
		read += 1
		var code: String = ""
		for line: String in src.split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			code += line + "\n"
		if code.contains("fire_interval_scale"):
			slowed.append(String(id))
	err = _T.assert_eq(unreadable.size(), 0,
		("every catalogue id resolves to res://game/<id>.gd, missing: %s. That mapping is "
			+ "this test's own assumption -- an id that stopped matching its filename would "
			+ "otherwise read as a plant the drought does not touch") % [unreadable])
	if err == "":
		err = _T.assert_eq(read, ids.size(),
			("and all %d of them were read (%d) -- the denominator, without which the set "
				+ "below is a claim about however many files happened to open")
				% [ids.size(), read])
	if err == "":
		slowed.sort()
		var expected: PackedStringArray = [
			String(PlantCatalog.CORN), String(PlantCatalog.DANDELION),
			String(PlantCatalog.NETTLE),
		]
		expected.sort()
		err = _T.assert_eq(", ".join(slowed), ", ".join(expected),
			("a drought reaches exactly the plants that fire on a repeating interval. Got "
				+ "[%s], decided [%s]. If a plant was ADDED here, read the per-plant "
				+ "reasoning at WaveDirector.WEATHER_DROUGHT_INTERVAL_SCALE before widening "
				+ "this list -- the bead that wrote it refused a chew, a seed clock, an "
				+ "aura, a neighbour buff and a heal, each for a different reason. If one "
				+ "was REMOVED, the garden now has a shooter the weather cannot touch")
				% [", ".join(slowed), ", ".join(expected)])
	if err == "":
		# The claim that makes the Chomp bullet arithmetic rather than an opinion: a chew's
		# length is the MEAL's, scaled by the flower's ladder and by nothing else. Asserted
		# as proportionality so it survives the ladder being retuned or reindexed.
		var one: float = ChompFlower.chew_seconds_for(1, 1.0)
		err = _T.assert_gt(one, 0.0, "a level-1 chew of a 1s meal takes time")
		if err == "":
			err = _T.assert_float_eq(ChompFlower.chew_seconds_for(1, 2.6), one * 2.6, 0.0001,
				("and a 2.6s meal takes 2.6 times as long -- the pest brings the number, so "
					+ "a drought folded in here would lengthen the HOLD as much as the busy "
					+ "time and change sign with the size of the lane"))
	if err == "":
		# The other two refusals, as the shape of their own APIs. Neither of these pure
		# functions has a weather term to take, which is the concrete form of "there is
		# nothing here for a drought to multiply".
		err = _T.assert_float_eq(Aloe.heal_for(1.0), Aloe.HEAL_PER_SECOND, 0.0001,
			("an Aloe's repair is per second and unconditioned -- it works between waves, "
				+ "where nothing is racing it"))
		if err == "":
			err = _T.assert_float_eq(Sunflower.seconds_left_at(0.0), Sunflower.INTERVAL,
				0.0001,
				("and a Sunflower's clock is its own. Slowing it under the one weather that "
					+ "pays WEATHER_DROUGHT_SEED_BONUS on kills would move two numbers "
					+ "against each other so the total barely moved"))
	if err == "":
		# And the half that must keep working: the weather really does reach a shooter.
		var drought: float = WaveDirector.fire_interval_scale_for(WaveDirector.WEATHER_DROUGHT)
		err = _T.assert_float_eq(
			Plant.composed_interval(Nettle.STING_INTERVAL, drought, 1.0),
			Nettle.STING_INTERVAL * drought, 0.0001,
			("while a Nettle's sting really is lengthened by the sky -- the third reader, "
				+ "and the one the bead did not know about"))
	return err

# END plant-tower-defense-bt5i
# =============================================================================


# =============================================================================
# BEGIN plant-tower-defense-frzz: the gait reference speed, against the species
# that actually exist
#
# The bead's line numbers were stale -- it said pest.gd:235-245 and the GAIT_ block
# is at pest.gd:550-560 -- and its substance was live and worse than it knew.
#
# The header at pest.gd:553 justifies GAIT_REFERENCE_SPEED = 60.0 as sitting
# "between the aphid's 78 and the beetle's 38, so the fast one scuttles fast and the
# slow one plods without either needing a per-species constant".
#
# THERE ARE FIVE SPECIES NOW, NOT TWO. Derived from `Pest.SPECIES` rather than read
# off that sentence: aphid 78, shieldbug 54, nurse 44, beetle 38, queen 30. So 60.0
# is ABOVE FOUR OF THE FIVE, the corpus midpoint is 54 -- which is the Shield Bug's
# own speed -- and the nearest species now sits 6.0 away. The bead worried that "a
# species added at speed 61 would land on the boundary silently"; the corpus has
# already crowded the constant without anyone saying so.
#
# What survives of the header's reasoning is weaker than "midpoint" and is what the
# mechanic actually needs: species on BOTH sides, so `speed / GAIT_REFERENCE_SPEED`
# is used in both directions, and none of them sitting so near the reference that its
# gait reads as neutral. Those are the two tests below. Neither asserts the header's
# arithmetic, because the header's arithmetic is no longer true.


## Every species' walking speed, out of `Pest.SPECIES` rather than typed out.
##
## `speed` is a required key with no accessor -- pest.gd:820 reads it raw as
## `stats["speed"]` -- so this reads it the way the game does. Keyed by String because
## that is what `_T.assert_margin` compares its recorded set against.
func _species_speeds() -> Dictionary:
	var out: Dictionary = {}
	for which: StringName in Pest.SPECIES:
		var stats: Dictionary = Pest.SPECIES[which] as Dictionary
		out[String(which)] = float(stats["speed"])
	return out


## How close a species' speed may come to GAIT_REFERENCE_SPEED before its gait stops
## telling the player anything, in pixels per second.
##
## Not picked. `Pest.gait_rate` scales linearly with `for_speed / GAIT_REFERENCE_SPEED`,
## so a species N% off the reference waggles N% off the neutral GAIT_RATE. The smallest
## gait-rate difference this game already SHIPS as a readable tell is the subtler of its
## two mutation rate multipliers -- ARMOURED 0.8 and WINGED 2.4, i.e. 0.2 and 1.4 away
## from neutral. A species inside that band is being asked to communicate itself with a
## difference smaller than the one the game uses to encode a whole separate mutation.
##
## Both multipliers go through `minf()` on purpose rather than 0.2 being written down:
## a future mutation with a subtler tell moves this number and takes the band with it,
## instead of leaving a fact about a version of the file that no longer exists.
func _gait_reference_margin() -> float:
	var subtlest: float = minf(
		absf(1.0 - Pest.ARMOURED_RATE_MULTIPLIER),
		absf(1.0 - Pest.WINGED_RATE_MULTIPLIER))
	return subtlest * Pest.GAIT_REFERENCE_SPEED


## The half of the header's sentence that still holds: some species walk faster than
## the reference and some slower, so one constant really does buy both a scuttle and a
## plod.
##
## Deliberately NOT asserted here: that 60.0 is a midpoint, or that the beetle is the
## slow end. Neither is true any more -- the queen at 30 is the slow end and four of
## five species are below the reference. A test written to the header would have to
## fail or be fudged; this one asserts the property the mechanic depends on.
func test_the_gait_reference_speed_still_has_species_on_both_sides_of_it() -> String:
	var speeds: Dictionary = _species_speeds()
	var err: String = _T.assert_gt(speeds.size(), 1,
		("Pest.SPECIES yielded %d species. Every loop below divides by that, and a "
			+ "corpus of one agrees with any reference speed at all")
			% [speeds.size()])
	if err != "":
		return err
	var faster: PackedStringArray = []
	var slower: PackedStringArray = []
	var fastest: float = -1.0
	var slowest: float = -1.0
	for name: String in speeds:
		var speed: float = float(speeds[name])
		if speed > Pest.GAIT_REFERENCE_SPEED:
			faster.append(name)
		elif speed < Pest.GAIT_REFERENCE_SPEED:
			slower.append(name)
		if fastest < 0.0 or speed > fastest:
			fastest = speed
		if slowest < 0.0 or speed < slowest:
			slowest = speed
	err = _T.assert_gt(faster.size(), 0,
		("at least one species walks faster than GAIT_REFERENCE_SPEED %.1f, or the "
			+ "clamp's whole upper half (GAIT_RATE_MAX %.2f) is unreachable outside "
			+ "endless-mode scaling and the constant is a ceiling rather than a "
			+ "reference. Speeds were %s")
			% [Pest.GAIT_REFERENCE_SPEED, Pest.GAIT_RATE_MAX, str(speeds)])
	if err == "":
		err = _T.assert_gt(slower.size(), 0,
			("and at least one plods. Speeds were %s") % [str(speeds)])
	if err == "":
		# The consequence, through the function that reads the constant rather than
		# through the constant itself: the fastest species really does waggle faster
		# than the slowest. This is "the fast one scuttles fast and the slow one plods"
		# as arithmetic, and it is what would break if the reference walked off the top
		# or the bottom of the corpus.
		err = _T.assert_gt(
			Pest.gait_rate(fastest, false, false),
			Pest.gait_rate(slowest, false, false),
			("the fastest species (%.1f px/s) waggles faster than the slowest (%.1f) "
				+ "off GAIT_REFERENCE_SPEED alone, with no per-species constant")
				% [fastest, slowest])
	return err


## The gate the bead asked for: nothing may walk close enough to the reference that its
## gait reads as neutral, and the one species already near the line is recorded by name.
##
## The Shield Bug at 54.0 is 6.0 from the reference -- a gait rate of 0.90x neutral,
## still readable, and inside the 12.0 band because the band is derived from the mutation
## tells rather than fitted to the corpus. It is RECORDED, not exempted: a second species
## landing in the band, or this one drifting, fails here instead of arriving in silence.
func test_no_species_walks_close_enough_to_the_gait_reference_to_lose_its_tell() -> String:
	var speeds: Dictionary = _species_speeds()
	var margin: float = _gait_reference_margin()
	var err: String = _T.assert_gt(speeds.size(), 1,
		("Pest.SPECIES yielded %d species -- the corpus this gate sweeps")
			% [speeds.size()])
	if err == "":
		err = _T.assert_gt(margin, 0.0,
			("the band has to be a band, and it is %.4f px/s. It comes off the mutation "
				+ "rate multipliers, so a pair of them both set to 1.0 would collapse it "
				+ "to zero and leave the gate below agreeing with every corpus there is")
				% [margin])
	if err == "":
		err = _T.assert_margin(speeds, Pest.GAIT_REFERENCE_SPEED, margin,
			{"shieldbug": 54.0},
			("the Shield Bug is the ONE species within %.1f px/s of GAIT_REFERENCE_SPEED "
				+ "%.1f. The header still says the reference sits between the aphid's 78 "
				+ "and the beetle's 38; there are five species now and it is above four "
				+ "of them, so read that sentence as history. Speeds swept: %s")
				% [margin, Pest.GAIT_REFERENCE_SPEED, str(speeds)])
	return err

# END plant-tower-defense-frzz
# =============================================================================


# =============================================================================
# BEGIN plant-tower-defense-f7y2: the weather multipliers, the same shape again
#
# -frzz above is a tuned constant whose justification is written in prose sitting
# near a corpus nobody asserts it stays clear of. The weather multipliers are that
# shape exactly: WEATHER_DROUGHT_SEED_BONUS 1.5, WEATHER_DROUGHT_INTERVAL_SCALE 2.0
# and WEATHER_RAIN_HEAL_FRACTION 0.35, each with a paragraph of reasoning above it
# in wave_director.gd and no test between the reasoning and the number.
#
# The bead names two failure modes and both are here:
#
#   1. A multiplier drifts back into the baseline and the weather stops being
#      distinguishable from clear. That is `_T.assert_margin` against the neutral
#      value of each effect, with the weathers already sitting on neutral recorded
#      by name -- clear is SUPPOSED to be on the line, and rain is supposed to be on
#      it for two of the three effects.
#   2. Two weathers drift into each other and stop being different choices. Margin
#      cannot express a pairwise claim -- it measures every value against one
#      threshold -- so that half is plain assertions over the enumerated pairs.
#
# All three bands are derived from the smallest change the GAME ITSELF already treats
# as meaningful in that quantity, never from what would make today's numbers pass.
# See the three band helpers.
#
# The corpus is swept out of `weather_for(1..100)`, the same derivation
# `test_no_weather_asks_for_something_and_gives_nothing_back` above uses: a fourth
# weather joins these gates without anyone remembering to add it.
#
# NOT ASSERTED, but worth writing down because it is the most striking thing found
# here: WEATHER_RAIN_HEAL_FRACTION 0.35 is exactly `Pest.EAT_DPS / Plant.MAX_HEALTH`
# (14.0 / 40.0), i.e. rain hands back precisely one second of a pest chewing. That is
# either design or coincidence, and nothing in wave_director.gd claims it, so it is
# left as an observation rather than turned into a contract nobody agreed to.


## The weathers the game can actually produce, swept rather than listed.
func _weathers_in_play() -> Array[StringName]:
	var seen: Array[StringName] = []
	for wave: int in range(1, 101):
		var state: StringName = WaveDirector.weather_for(wave)
		if not seen.has(state):
			seen.append(state)
	return seen


## How close a seed multiplier may come to 1.0 before it pays what clear pays.
##
## Not a perceptual guess. `Game.weather_seed_value` (game.gd:953) is
## `maxi(1, int(round(float(base) * seed_multiplier_for(weather))))`, so the payout is
## an INTEGER and a multiplier only changes it when it moves the rounded product off
## `base`. The cheapest pest in `Pest.SPECIES` decides where that starts, and it is the
## aphid at 3 seeds: any multiplier under 1 + 0.5/3 rounds straight back to 3 and hands
## the player the clear number on the commonest kill in the game.
##
## The rounding rule is duplicated here rather than called, because
## `weather_seed_value` is an instance method on `Game` and `Game` is a Node this suite
## has no board for. That is the one line in this block that can go stale behind our
## back, so it is named out loud: game.gd:953.
func _seed_multiplier_band() -> float:
	var cheapest: float = -1.0
	for which: StringName in Pest.SPECIES:
		var stats: Dictionary = Pest.SPECIES[which] as Dictionary
		var seeds: float = float(stats["seeds"])
		if cheapest < 0.0 or seeds < cheapest:
			cheapest = seeds
	if cheapest <= 0.0:
		return 0.0
	return 0.5 / cheapest


## How far a firing-interval scale must sit from 1.0 to be worth announcing.
##
## This quantity has no integer quantum and no pixel to hide behind, so it borrows the
## smallest interval change the game already ships as a thing the player is meant to
## notice: `Mint.NEIGHBOUR_SCALE` 0.75, a quarter off neutral. A weather asking to be
## read as an event off less than one Garden Mint is asking too much.
##
## Say plainly: this is the least-grounded of the three bands, and it is the one to
## revisit first if a weather is ever separated from another by fire rate alone.
func _fire_interval_band() -> float:
	return absf(1.0 - Mint.NEIGHBOUR_SCALE)


## How much of a plant's health a weather must give back before the heal is invisible.
##
## `Game._apply_weather` heals `Plant.MAX_HEALTH * heal_fraction_for(next)`
## (game.gd:425) and the player reads the result off the plant's own health bar, which
## is `Plant.HEALTH_BAR_SIZE.x` pixels wide in the plant's local space. A heal smaller
## than one pixel of that bar does not move the only surface that reports it -- the
## same kind of grounding as the seed band above, a display quantum rather than a
## judgement.
func _heal_fraction_band() -> float:
	if Plant.HEALTH_BAR_SIZE.x <= 0.0:
		return 0.0
	return 1.0 / Plant.HEALTH_BAR_SIZE.x


## Failure mode one: no weather's multiplier has drifted back into the clear baseline.
##
## Each effect is measured against ITS OWN neutral -- 1.0 for the two multiplicative
## ones, 0.0 for the heal -- and the weathers legitimately sitting on that neutral are
## recorded by name rather than skipped. That is the whole point of recording them:
## clear must stay at neutral in all three, rain must stay at neutral in the two it
## does not touch, and any of them moving off is a change to what the forecast means.
func test_no_weather_multiplier_has_drifted_into_the_clear_baseline() -> String:
	var weathers: Array[StringName] = _weathers_in_play()
	var err: String = _T.assert_gt(weathers.size(), 1,
		("`weather_for` produced %d distinct weather(s) over the first hundred waves "
			+ "(%s). Every dictionary below is built from that sweep, and a corpus of "
			+ "one would pass all three margins while checking nothing")
			% [weathers.size(), str(weathers)])
	if err != "":
		return err
	var seed_mult: Dictionary = {}
	var interval: Dictionary = {}
	var heal: Dictionary = {}
	for state: StringName in weathers:
		var key: String = String(state)
		seed_mult[key] = WaveDirector.seed_multiplier_for(state)
		interval[key] = WaveDirector.fire_interval_scale_for(state)
		heal[key] = WaveDirector.heal_fraction_for(state)
	var seed_band: float = _seed_multiplier_band()
	var interval_band: float = _fire_interval_band()
	var heal_band: float = _heal_fraction_band()
	err = _T.assert_gt(minf(seed_band, minf(interval_band, heal_band)), 0.0,
		("all three bands have to be bands: seeds %.5f, interval %.5f, heal %.5f. Each "
			+ "is derived from another constant, and a zero here would leave its margin "
			+ "agreeing with every value there is")
			% [seed_band, interval_band, heal_band])
	if err == "":
		err = _T.assert_margin(seed_mult, 1.0, seed_band, {"clear": 1.0, "rain": 1.0},
			("only drought pays, and it pays 1.5 -- three times the %.5f band it has to "
				+ "clear to change the rounded payout on a 3-seed aphid at all "
				+ "(game.gd:953). Clear and rain are recorded ON the line because that "
				+ "is the design: rain is the mercy wave and paying it less was refused "
				+ "outright in wave_director.gd:866. Swept: %s")
				% [seed_band, str(seed_mult)])
	if err == "":
		err = _T.assert_margin(interval, 1.0, interval_band, {"clear": 1.0, "rain": 1.0},
			("a drought doubles the interval, four times the %.5f band, which is what "
				+ "lets Hud.weather_note say 'Everything shoots half as often' and be "
				+ "exactly right. Swept: %s")
				% [interval_band, str(interval)])
	if err == "":
		err = _T.assert_margin(heal, 0.0, heal_band, {"clear": 0.0, "drought": 0.0},
			("rain's 0.35 of max health is eleven times the %.5f band -- one pixel of a "
				+ "%.0f-pixel health bar -- so the heal is a thing the player watches "
				+ "happen rather than a number in a log. Clear and drought are recorded "
				+ "at zero: rain is the only weather in this game that heals, and a "
				+ "second one appearing here has to say so. Swept: %s")
				% [heal_band, Plant.HEALTH_BAR_SIZE.x, str(heal)])
	return err


## Failure mode two: no two weathers have drifted into being the same choice.
##
## `assert_margin` cannot state this -- it measures a corpus against ONE threshold, and
## "these two are too alike" is a claim about a pair. So this is plain assertions over
## the enumerated pairs, with the pair count asserted first so a sweep that produced one
## weather cannot pass by running the inner loop zero times.
##
## The bar is deliberately low: a pair only has to be separated in ONE effect, by more
## than that effect's own band. Two weathers alike in all three are not two weathers.
func test_no_two_weathers_have_drifted_into_the_same_choice() -> String:
	var weathers: Array[StringName] = _weathers_in_play()
	var err: String = _T.assert_gt(weathers.size(), 1,
		("`weather_for` produced %d distinct weather(s) (%s) -- fewer than two and the "
			+ "pair loop below runs zero times and reports a clean pass")
			% [weathers.size(), str(weathers)])
	if err != "":
		return err
	var bands: Dictionary = {
		"seed multiplier": _seed_multiplier_band(),
		"fire interval scale": _fire_interval_band(),
		"heal fraction": _heal_fraction_band(),
	}
	var effects: Dictionary = {
		"seed multiplier": {},
		"fire interval scale": {},
		"heal fraction": {},
	}
	for state: StringName in weathers:
		var key: String = String(state)
		(effects["seed multiplier"] as Dictionary)[key] = (
			WaveDirector.seed_multiplier_for(state))
		(effects["fire interval scale"] as Dictionary)[key] = (
			WaveDirector.fire_interval_scale_for(state))
		(effects["heal fraction"] as Dictionary)[key] = (
			WaveDirector.heal_fraction_for(state))
	var pairs: int = 0
	var alike: PackedStringArray = []
	for i: int in range(weathers.size()):
		for j: int in range(i + 1, weathers.size()):
			pairs += 1
			var a: String = String(weathers[i])
			var b: String = String(weathers[j])
			var separated: bool = false
			for effect: String in effects:
				var values: Dictionary = effects[effect] as Dictionary
				var delta: float = absf(float(values[a]) - float(values[b]))
				if delta > float(bands[effect]):
					separated = true
					break
			if not separated:
				alike.append("%s vs %s" % [a, b])
	err = _T.assert_eq(pairs, weathers.size() * (weathers.size() - 1) / 2,
		("every unordered pair of the %d weathers was compared, %d of them")
			% [weathers.size(), pairs])
	if err == "":
		err = _T.assert_eq(alike.size(), 0,
			("no two weathers are the same choice, and these were: %s. Today the three "
				+ "separate on two effects -- drought against either of the others on "
				+ "the seed bonus and the interval, clear against rain on the heal "
				+ "alone. That last one is the thin pair: rain differs from clear in "
				+ "ONE number, so WEATHER_RAIN_HEAL_FRACTION shrinking toward zero does "
				+ "not just weaken rain, it deletes it as a distinct forecast")
				% [str(alike)])
	return err

# END plant-tower-defense-f7y2
# =============================================================================


# =============================================================================
# BEGIN plant-tower-defense-snba: where the end of a route actually is
#
# THE BEAD, AND WHY IT IS ANSWERED WITH A TEST RATHER THAN A METHOD.
#
# The bead asked for `Pest.last_survivable_leg()` returning `_route.size() - 2`,
# because three test files hand-set `_leg` and nothing writes that number down.
# Building it would have shipped a false claim, and the falseness is the finding:
#
#   * `_route.size() - 1` is the last leg the MODEL has. `Pest.enter_road_at`
#     clamps to exactly it (game/pest.gd:869) and `_advance` escapes at
#     `_leg >= _route.size()`. A pest on it is alive and walking, not doomed.
#   * `_route.size() - 2` is the last leg a HOSTED TEST can park a pest on, because
#     `_T.instantiate_scene` pumps settle frames that walk it. That is a fact about
#     the harness, and putting it on `Pest` under the name "survivable" would tell
#     every future reader the game forbids a leg the game clamps TO.
#
# So the model number stays where it already lives (the clamp), the harness number
# stays in the tests, and the pair is made executable here instead of being prose in
# one test's comment. The alternative the bead offered — a helper placing a pest at a
# FRACTION of its route — was rejected for the same reason plus one: a fraction is
# more arithmetic, not less, and its failing case is 1.0, which is precisely the
# value a caller reaching for "at the end" would type.
#
# Nothing a player can see changes here. This is a testing-model change and a
# comment; it is written down rather than shown.
# =============================================================================


## Both numbers, pinned against `Pest._advance` itself.
##
## No hosting, on purpose: this test drives `_advance` by hand rather than letting
## settle frames drive it, so the escape it observes is the one this route asked for
## and not however many frames the harness happened to pump. That is also what makes
## it the right place to state the harness rule the OTHER tests obey — see
## `test_corn_shoots_the_pest_closest_to_escaping` above, which is the test that was
## silently comparing two freed references until leg 4 was walked back to leg 3.
func test_the_last_leg_of_a_route_is_the_one_a_pest_escapes_off() -> String:
	var route := PackedVector2Array([
		Vector2(0, 0), Vector2(40, 0), Vector2(80, 0), Vector2(120, 0), Vector2(160, 0),
	])
	var last: int = route.size() - 1
	var parkable: int = route.size() - 2
	# One leg's length, plus a pixel. The plus-a-pixel matters: `_advance` spends
	# distance in a `while distance > 0.0` loop, so landing EXACTLY on a waypoint
	# leaves the loop with `_leg` already incremented and the escape check unrun.
	var stride: float = route[0].distance_to(route[1]) + 1.0

	# 1. The model's ceiling, read off the clamp rather than retyped.
	var over := Pest.new()
	over.setup(Pest.APHID, route)
	over.set_physics_process(false)
	over.enter_road_at(route[0], last + 5)
	var err: String = _T.assert_eq(over.route_leg(), last,
		("enter_road_at clamps a runaway leg to %d on a %d-point route, so that — not "
			+ "anything smaller — is the last leg the game itself has")
			% [last, route.size()])
	over.free()
	if err != "":
		return err

	# 2. And a pest on it is on its final step: one leg of walking ends the walk.
	var final_step := Pest.new()
	final_step.setup(Pest.APHID, route)
	final_step.set_physics_process(false)
	final_step.enter_road_at(route[last - 1], last)
	err = _T.assert_true(final_step.is_alive(), "the pest starts its final step alive")
	if err == "":
		final_step._advance(stride)
		err = _T.assert_false(final_step.is_alive(),
			("a pest walking leg %d of a %d-point route is off the board when that leg "
				+ "ends — which is why a hosted test must never park one there")
				% [last, route.size()])
	# `_escape()` has already called queue_free() on it; free() as well is a double
	# free. Left to the deferred deletion the game itself relies on.
	if err != "":
		return err

	# 3. One leg back survives exactly the same walk. This is the number the tests use.
	var parked := Pest.new()
	parked.setup(Pest.APHID, route)
	parked.set_physics_process(false)
	parked.enter_road_at(route[parkable - 1], parkable)
	parked._advance(stride)
	err = _T.assert_true(parked.is_alive(),
		("a pest parked on leg %d of a %d-point route survives the same walk that "
			+ "took leg %d off the board") % [parkable, route.size(), last])
	if err == "":
		err = _T.assert_eq(parked.route_leg(), last,
			"and it lands on the final leg rather than skipping past it")
	if err == "":
		# The guard against a route so short that the two numbers coincide: on a
		# two-point route `parkable` is 0, which enter_road_at clamps up to 1, and
		# every assertion above would be about the same leg twice.
		err = _T.assert_gt(parkable, 0,
			"the two legs this test compares are distinct, or it proves nothing")
	parked.free()
	return err

# END plant-tower-defense-snba
# =============================================================================


# =============================================================================
# plant-tower-defense-n3zm — the pitch scale has a DIRECTION, and it is asserted
#
# `Sfx.PITCH`'s header states a rule in prose: losses go lower, gains go higher, the
# routine half of a pair keeps the base, magnitudes graded by how grave the event is.
# Until these two checks, exactly one of the seven entries was held to any of it —
# `test_tuning_a_voice_applies_both_axes_the_table_declares` puts PLANT_DESTROYED beside
# CHOMP_BITE and asserts one number is below the other. The remaining six entries, the
# grading, and "the routine half keeps the base" were prose, and prose in this project
# has a record.
#
# WHERE THE JUDGEMENT LIVES, since that is the substance of this pair and not the
# assertions. Which events count as losses is NOT derivable here. There is no ledger of
# what an event costs the player; `Sfx` knows a file, a volume, a pitch, a wobble and a
# repeat gap, and not one of those has a sign. Three derivations were tried and rejected:
#
#   * the sign of `PITCH` itself — the table agreeing with itself, which is the defect;
#   * the `# Losses, gravest first.` / `# Gains` comments already sitting in `sfx.gd` —
#     unreadable from GDScript, and a comment is the prose being escaped;
#   * what the event costs in seeds, the only currency spanning both columns — it prices
#     `PLANT_UPGRADED` as a loss, because upgrading is the one entry here the player pays
#     for. A derivation that produces the wrong answer confidently is failure 4.
#
# So it is `derive-the-list`'s step-1 branch: a taste call is RECORDED — `Sfx.PITCH_GRADE`,
# in `game/sfx.gd` beside the entries it grades, per the bead's acceptance — and what is
# asserted is the PROPERTY it claims, not its membership. The two sides are the author's
# stated intent (a rank) and the tuned number (a pitch), and neither is computed from the
# other. Moving one without the other is red.
#
# What this pair still cannot say: whether the intent is RIGHT. Nobody has heard these
# numbers (see `Sfx.JITTER`'s own note). It holds the table to what it says about itself.
# =============================================================================


## Every entry in `Sfx.PITCH` points the way `Sfx.PITCH_GRADE` says it does, and by the
## amount the grading implies.
##
## Five claims, and the equality is deliberately both directions (`derive-the-list` step
## 3): a `PITCH` entry with no grade is a pitch nobody stated the direction of, and a
## grade with no `PITCH` entry is a rule about a sound that does not exist.
func test_the_pitch_scale_points_the_way_its_grades_say() -> String:
	# Denominator first: every sweep below iterates these tables, and an empty one
	# satisfies all five claims beautifully.
	var err: String = _T.assert_gt(Sfx.PITCH.size(), 6,
		"PITCH is populated (an empty sweep is a vacuous pass), got %d" % Sfx.PITCH.size())
	if err != "":
		return err

	# 1. The two tables are the same SET, both directions.
	var ungraded: Array[String] = []
	for event: StringName in Sfx.PITCH:
		if not Sfx.PITCH_GRADE.has(event):
			ungraded.append(String(event))
	err = _T.assert_eq(ungraded.size(), 0,
		("every PITCH entry is graded in PITCH_GRADE — ungraded: %s. An entry added to "
			+ "PITCH and not graded is a number with no stated direction, which is "
			+ "exactly what this check exists to stop shipping.") % str(ungraded))
	if err != "":
		return err
	var unpitched: Array[String] = []
	for event: StringName in Sfx.PITCH_GRADE:
		if not Sfx.PITCH.has(event):
			unpitched.append(String(event))
	err = _T.assert_eq(unpitched.size(), 0,
		("and every PITCH_GRADE entry is in PITCH — stray grades: %s. This is the "
			+ "direction a one-sided `has` check cannot fail: a rule left behind about a "
			+ "cue whose pitch row was deleted.") % str(unpitched))
	if err != "":
		return err
	err = _T.assert_eq(Sfx.PITCH_GRADE.size(), Sfx.PITCH.size(),
		"so the two tables are equal, not merely overlapping")
	if err != "":
		return err

	# 2. The ranks are non-zero and all different. Zero would be "routine", which is what
	# an ABSENT row means, and a tie makes claim 4 below vacuously true for that pair —
	# two events the author never said which of was graver, whose pitches differ anyway.
	var rank_owner: Dictionary = {}
	for event: StringName in Sfx.PITCH_GRADE:
		var rank: int = int(Sfx.PITCH_GRADE[event])
		err = _T.assert_true(rank != 0,
			("'%s' is graded 0, which is neither a loss nor a gain — a routine event "
				+ "keeps the base by having NO row in PITCH at all") % event)
		if err != "":
			return err
		err = _T.assert_false(rank_owner.has(rank),
			("'%s' and '%s' are both graded %d — the ranks are an ordering, so a tie "
				+ "says the table has no opinion about which is graver while the pitches "
				+ "below still differ") % [event, rank_owner.get(rank, &""), rank])
		if err != "":
			return err
		rank_owner[rank] = event

	# 3. The sign of each pitch matches the sign of its grade. 1.0 is the base a routine
	# event keeps, so "below 1.0" and "a loss" are the same statement — this is the claim
	# the one existing pair check made about one entry, now made about all of them.
	var signed_checked: int = 0
	for event: StringName in Sfx.PITCH:
		var pitch: float = float(Sfx.PITCH[event])
		var rank: int = int(Sfx.PITCH_GRADE[event])
		if rank < 0:
			# No _T.assert_lt exists; the arguments are flipped instead.
			err = _T.assert_gt(1.0, pitch,
				("'%s' is graded %d (a loss) so it must sit BELOW the 1.0 base, got %.2f"
					+ " — losses go lower is the whole rule") % [event, rank, pitch])
		else:
			err = _T.assert_gt(pitch, 1.0,
				("'%s' is graded %d (a gain) so it must sit ABOVE the 1.0 base, got %.2f"
					+ " — gains go higher is the whole rule") % [event, rank, pitch])
		if err != "":
			return err
		signed_checked += 1
	err = _T.assert_eq(signed_checked, Sfx.PITCH.size(),
		"and the sign sweep visited every entry rather than a subset of them")
	if err != "":
		return err

	# 4. The grading. Within one column, a graver rank sits STRICTLY further from the
	# base — this is "the magnitudes are graded by how grave the event is" as an
	# assertion. Compared across the column rather than to a neighbour, so a retune that
	# reorders two entries three rows apart cannot slip past.
	var graded: Array = Sfx.PITCH_GRADE.keys()
	var compared: int = 0
	for a: StringName in graded:
		for b: StringName in graded:
			var rank_a: int = int(Sfx.PITCH_GRADE[a])
			var rank_b: int = int(Sfx.PITCH_GRADE[b])
			if a == b or signi(rank_a) != signi(rank_b):
				continue
			if absi(rank_a) <= absi(rank_b):
				continue
			var far_a: float = absf(float(Sfx.PITCH[a]) - 1.0)
			var far_b: float = absf(float(Sfx.PITCH[b]) - 1.0)
			compared += 1
			err = _T.assert_gt(far_a, far_b,
				("'%s' is graded %d and '%s' only %d, so '%s' must sit further from the "
					+ "1.0 base — got %.3f against %.3f. The table is meant to read as a "
					+ "scale, not as %d numbers that happen to have signs.")
					% [a, rank_a, b, rank_b, a, far_a, far_b, Sfx.PITCH.size()])
			if err != "":
				return err
	err = _T.assert_gt(compared, 5,
		("the grading sweep actually compared same-column pairs, got %d — a table whose "
			+ "columns are one entry each compares nothing and passes") % compared)
	if err != "":
		return err

	# 5. The gravest loss is the furthest thing from the base in the WHOLE table, gains
	# included. This is the bead's own wording, and it is a design statement rather than
	# arithmetic: a tower defense's worst news should be its most conspicuous sound, so no
	# gain may ever be pitched further out than the worst loss.
	var gravest: StringName = &""
	var lowest_rank: int = 0
	for event: StringName in Sfx.PITCH_GRADE:
		var rank: int = int(Sfx.PITCH_GRADE[event])
		if rank < lowest_rank:
			lowest_rank = rank
			gravest = event
	err = _T.assert_true(gravest != &"",
		"the table has a loss in it at all, or claim 5 is about nothing")
	if err != "":
		return err
	var gravest_far: float = absf(float(Sfx.PITCH[gravest]) - 1.0)
	for event: StringName in Sfx.PITCH:
		if event == gravest:
			continue
		err = _T.assert_gt(gravest_far, absf(float(Sfx.PITCH[event]) - 1.0),
			("the gravest loss '%s' (grade %d) sits furthest from the base, but '%s' is "
				+ "further out — %.3f against %.3f. Nothing in this game should be a "
				+ "wider interval than its worst news.")
				% [gravest, lowest_rank, event, absf(float(Sfx.PITCH[event]) - 1.0),
					gravest_far])
		if err != "":
			return err
	return err


## "The routine event of a pair keeps the base" — the third clause of `PITCH`'s rule, and
## the one that makes 1.0 mean something rather than being an arbitrary origin.
##
## A pitched cue is only audibly pitched next to something: `PEST_ESCAPED` at 0.72 is a
## lower `error_002.ogg` **than the `error_002.ogg` a refused purchase plays**. So every
## `PITCH` entry must share its file with at least one event that has no `PITCH` row and
## therefore sits at exactly 1.0. `RUN_LOST` is the counter-example living in the table
## today: `bong_001.ogg` is its alone, so a `PITCH` row on it would be a number with
## nothing to be heard against, and this check is what would say so.
##
## IT SAID SO, which is why `EXCUSED` exists (plant-tower-defense-tnwd). Giving
## `CHOMP_BITE` a bite recorded for it left `PLANT_DESTROYED` alone on `chop.ogg`, and
## this test went red on exactly the clause it was written to hold — the gate working,
## not a nuisance. Two honest answers were available and the quieter one was taken: the
## 0.78 is kept, because it is the second-gravest step on the losses scale that
## `test_the_gravest_loss_sits_furthest_from_the_base` reads and dropping it would
## change what a dying plant sounds like today, which is a design decision and not a
## side effect of naming an audio file.
##
## `EXCUSED` is gated in BOTH directions below. An entry that stops needing the excuse
## fails, so the list cannot quietly become the place pitched-and-lonely cues go to be
## forgotten — the failure `.claude/skills/scope-vs-claim` describes, where a check keeps
## reporting clean because its exception set grew to cover everything it used to catch.
func test_every_pitched_event_moved_off_a_base_it_shares_a_file_with() -> String:
	var EXCUSED: Array[StringName] = [Sfx.PLANT_DESTROYED]
	var lonely: Array[StringName] = []
	var err: String = _T.assert_gt(Sfx.SOUNDS.size(), 20,
		"the sound table is populated (an empty sweep is a vacuous pass), got %d"
			% Sfx.SOUNDS.size())
	if err != "":
		return err
	var checked: int = 0
	for event: StringName in Sfx.PITCH:
		var file: String = str(Sfx.SOUNDS.get(event, "")).get_file()
		err = _T.assert_false(file.is_empty(),
			("'%s' has a PITCH row and no SOUNDS row — a pitch on a cue that cannot "
				+ "play is tuning nothing") % event)
		if err != "":
			return err
		# Every file-mate, NOT just the unpitched ones: filtering here would make the
		# assertion below true by construction instead of being a claim about the table.
		var mates: Array[String] = []
		var at_base: Array[String] = []
		for other: StringName in Sfx.SOUNDS:
			if other == event or str(Sfx.SOUNDS[other]).get_file() != file:
				continue
			mates.append(String(other))
			if is_equal_approx(float(Sfx.PITCH.get(other, 1.0)), 1.0):
				at_base.append(String(other))
		if mates.is_empty() or at_base.is_empty():
			# Recorded and skipped rather than failed, IF it is one of the named few.
			# The `EXCUSED` check after the loop is what stops this being a hole.
			lonely.append(event)
			continue
		err = _T.assert_false(EXCUSED.has(event),
			("'%s' is in EXCUSED and has %s at the base after all — delete the excuse "
				+ "rather than leaving it to cover the next lonely cue silently")
				% [event, str(at_base)])
		if err != "":
			return err
		err = _T.assert_gt(mates.size(), 0,
			("'%s' is the only event on %s, so its pitch of %.2f has nothing to be heard "
				+ "against — a shift off a base is only audible beside that base")
				% [event, file, float(Sfx.PITCH[event])])
		if err != "":
			return err
		err = _T.assert_gt(at_base.size(), 0,
			("'%s' shares %s with %s and every one of them is pitched too — the routine "
				+ "half of the pair is supposed to KEEP the base, and here nothing does")
				% [event, file, str(mates)])
		if err != "":
			return err
		# And it really did move: a graded entry sitting on the base is a row that says
		# "this is a loss" and sounds exactly like the routine event beside it.
		err = _T.assert_gt(absf(float(Sfx.PITCH[event]) - 1.0), 0.0,
			("'%s' is graded %d but sits at the 1.0 base, indistinguishable from %s")
				% [event, int(Sfx.PITCH_GRADE.get(event, 0)), str(at_base)])
		if err != "":
			return err
		checked += 1
	# The other direction on EXCUSED: every cue the sweep found lonely must be one of the
	# named few, and the list must be no longer than the set it explains. Written as two
	# claims rather than one `size ==`, because a mismatched pair of the same size would
	# satisfy that and is exactly the drift this is for.
	for event: StringName in lonely:
		err = _T.assert_true(EXCUSED.has(event),
			("'%s' is pitched to %.2f and is alone at that file with nothing at the 1.0 "
				+ "base, so the shift is inaudible. Give its file a second event at the "
				+ "base, drop the PITCH row, or add it to EXCUSED above WITH the reason")
				% [event, float(Sfx.PITCH[event])])
		if err != "":
			return err
	err = _T.assert_eq(EXCUSED.size(), lonely.size(),
		("EXCUSED names %s and the sweep found %s lonely — an excuse for a cue that does "
			+ "not need one is a gate with a hole in it") % [str(EXCUSED), str(lonely)])
	if err != "":
		return err
	# Pinned to a number, not to `PITCH.size()`: an emptied table would otherwise satisfy
	# every claim above by having nothing to check.
	err = _T.assert_gte(checked, 6,
		"at least six pitched events were actually swept, got %d" % checked)
	if err != "":
		return err
	return _T.assert_eq(checked + lonely.size(), Sfx.PITCH.size(),
		("the sweep visited every pitched event, got %d checked + %d excused of %d")
			% [checked, lonely.size(), Sfx.PITCH.size()])

# END plant-tower-defense-n3zm
# =============================================================================


# =============================================================================
# The wave banner's painter (plant-tower-defense-jk4a)
#
# `Hud._show_banner` used to assign both banner Labels unconditionally for three
# callers, so which of `announce_wave`, `announce_wave_cleared` and `show_weather`
# a player saw was decided by statement order in `Game._on_wave_started`. It is
# now one painter (`_paint_banner`) resolving one claim, with `banner_claim_wins`
# as the pure arbitration rule -- the shape the message row already uses.
#
# These assert the ARBITRATION, not that a string lands. A test that only checked
# "announce_wave puts the wave text on the Label" passes identically against the
# code this replaced, so it would have measured nothing about the change.
# =============================================================================


## The rule itself, with no HUD at all. Static and pure for the same reason
## `Hud.message_is_stressed` is: the contended cases -- two claims live at once,
## one expiring under another -- are exactly the ones a live HUD makes hardest to
## stage, and every one of them is one call here.
func test_the_banner_arbitration_ranks_the_wave_beats_above_the_weather() -> String:
	var err: String = _T.assert_eq(
		Hud.banner_claim_rank(Hud.BANNER_CLAIM_WAVE),
		Hud.banner_claim_rank(Hud.BANNER_CLAIM_CLEARED),
		"the two wave beats share a rung -- a wave starting and one being held are "
			+ "the same weight of event, which is the whole of plant-tower-defense-d2a")
	if err == "":
		err = _T.assert_gt(
			Hud.banner_claim_rank(Hud.BANNER_CLAIM_WAVE),
			Hud.banner_claim_rank(Hud.BANNER_CLAIM_WEATHER),
			"and both outrank the weather, which has a status row and a full-screen "
				+ "overlay carrying it for the whole wave where the beat has only this")
	if err == "":
		err = _T.assert_gt(
			Hud.banner_claim_rank(Hud.BANNER_CLAIM_WEATHER),
			Hud.banner_claim_rank(&"a_claim_nobody_registered"),
			"an unrecognised claim ranks below everything, so a name typoed into a "
				+ "caller added next year loses the banner rather than taking it")

	# The two rules, one assertion each, both directions.
	if err == "":
		err = _T.assert_false(
			Hud.banner_claim_wins(Hud.BANNER_CLAIM_WEATHER, Hud.BANNER_CLAIM_WAVE, 1.0),
			"a weaker claim does not take a banner a live wave beat is standing on")
	if err == "":
		err = _T.assert_true(
			Hud.banner_claim_wins(Hud.BANNER_CLAIM_WEATHER, Hud.BANNER_CLAIM_WAVE, 0.0),
			"but a claim with no time left is not a claim -- the same weather takes "
				+ "the same banner the moment the beat before it has finished")
	if err == "":
		err = _T.assert_true(
			Hud.banner_claim_wins(Hud.BANNER_CLAIM_WAVE, Hud.BANNER_CLAIM_WEATHER, 1.0),
			"and a stronger claim takes it while the weaker one is still live")
	if err == "":
		err = _T.assert_true(
			Hud.banner_claim_wins(Hud.BANNER_CLAIM_CLEARED, Hud.BANNER_CLAIM_WAVE, 1.0),
			"a tie goes to the ARRIVING claim -- refusing it would leave 'Wave 7' "
				+ "standing over a wave 7 the player has already held")
	if err == "":
		err = _T.assert_true(
			Hud.banner_claim_wins(Hud.BANNER_CLAIM_WEATHER, Hud.BANNER_CLAIM_NONE, 0.0),
			"and an unclaimed banner is free for anything")
	return err


## The same rule through the real HUD, in the order the game actually produces it.
##
## `Game._on_wave_started` calls `_apply_weather` -- which reaches
## `Hud.show_weather` -- and then `announce_wave` one line later, so the wave beat
## has always been what a player sees. What is asserted here is that it is the HUD
## deciding that: the weather is refused while the beat stands, and takes the same
## banner once the beat's clock has run out.
func test_a_standing_banner_claim_refuses_a_weaker_one_and_yields_once_it_expires() -> String:
	var game := await _T.instantiate_ui("res://game/game.tscn", Vector2i(1152, 648)) as Game
	var banner: Label = game.hud.get_node_or_null("Root/Banner") as Label
	var err: String = _T.assert_true(banner != null, "the banner's headline row exists")

	if err == "":
		game.hud.announce_wave(7, 19, "faster")
		err = _T.assert_eq(String(game.hud.banner_claim()), String(Hud.BANNER_CLAIM_WAVE),
			"announcing a wave claims the banner for the wave")
	if err == "":
		game.hud.show_weather(WaveDirector.WEATHER_DROUGHT)
		err = _T.assert_eq(String(game.hud.banner_claim()), String(Hud.BANNER_CLAIM_WAVE),
			"weather arriving under a live wave beat is refused, not queued behind it")
	if err == "":
		err = _T.assert_eq(banner.text, Hud.wave_headline(7),
			("and the headline is never even momentarily overwritten -- got '%s', "
				+ "which is what the old shared setter would have left here") % banner.text)

	# Equal rank: the wave the player just held is the true thing about the board.
	if err == "":
		game.hud.announce_wave_cleared(7, 19)
		err = _T.assert_eq(banner.text, Hud.wave_cleared_headline(7),
			"a claim of equal rank does take it, so consecutive beats both land")

	# The claim expires. Driven by the fade's own clock rather than by pumped
	# frames: the alpha is a pure function of the time left, so the deltas are the
	# test's to choose (see .claude/skills/assert-an-animation, rung 1).
	if err == "":
		game.hud._fade_banner(Hud.BANNER_HOLD_SECONDS)
		err = _T.assert_eq(String(game.hud.banner_claim()), String(Hud.BANNER_CLAIM_NONE),
			"running the hold out drops the claim rather than leaving it standing")
	if err == "":
		err = _T.assert_true(game.hud.banner_seconds_left() <= 0.0,
			"with no time left on it, got %.2f" % game.hud.banner_seconds_left())

	# And now the weaker claim wins, which is what makes the refusal above a rule
	# rather than `show_weather` simply never doing anything.
	if err == "":
		game.hud.show_weather(WaveDirector.WEATHER_DROUGHT)
		err = _T.assert_eq(String(game.hud.banner_claim()), String(Hud.BANNER_CLAIM_WEATHER),
			"the same weather takes the freed banner")
	if err == "":
		err = _T.assert_eq(banner.text, Hud.weather_headline(WaveDirector.WEATHER_DROUGHT),
			"and the painter puts its headline on the row, got '%s'" % banner.text)
	_T.free_ui(game)
	return err


## A dropped claim empties the rows rather than only hiding them.
##
## `hide_banner()` is what `Hud.refresh()` calls when a run ends, and the old
## version left the last headline sitting in a hidden 48px Label over the board.
## Three separate live misreads in cycles 110-111 were a hidden Control still
## holding its last text, and this is the widest one in the game.
func test_dropping_the_banner_claim_leaves_no_stale_headline_behind() -> String:
	var game := await _T.instantiate_ui("res://game/game.tscn", Vector2i(1152, 648)) as Game
	var banner: Label = game.hud.get_node_or_null("Root/Banner") as Label
	var note: Label = game.hud.get_node_or_null("Root/BannerNote") as Label
	var err: String = _T.assert_true(banner != null and note != null, "both rows exist")
	if err == "":
		game.hud.announce_wave(12, 30, "tougher")
		err = _T.assert_true(banner.text != "" and note.text != "",
			"the banner is up with both rows written")
	if err == "":
		game.hud.hide_banner()
		err = _T.assert_eq(banner.text, "",
			("taking it down empties the headline, got '%s' -- a hidden Label still "
				+ "holding a wave number is what the next thing to show this row for "
				+ "any reason at all would put on screen") % banner.text)
	if err == "":
		err = _T.assert_eq(note.text, "", "and the note row with it, got '%s'" % note.text)
	if err == "":
		err = _T.assert_float_eq(banner.modulate.a, 1.0, 0.001,
			("and it is left at full opacity, not at whatever alpha the fade had "
				+ "reached, got %.2f") % banner.modulate.a)
	_T.free_ui(game)
	return err

# END plant-tower-defense-jk4a
# =============================================================================


# --- Weather's teaching surfaces, pinned (plant-tower-defense-zhqf) ----------------
#
# Five comments across three files described weather as taught by three surfaces: the
# prep note, a banner as the wave opens, and "a status row carrying the state after the
# banner is gone (`weather_note`)". Two of the three did not exist.
#
#   * THE BANNER was written by Hud.show_weather and overwritten by Hud.announce_wave
#     ten lines later in the same call stack (game/game.gd:453 then :465), every wave,
#     for its whole life. It now loses by rule instead of by statement order.
#   * THE STATUS ROW was proposed as -saaw and MEASURED AND REFUSED: the wave slot's
#     base string is 302px in a 312px box, so even a bare "*" needed 317.
#     `weather_note()` is the banner's own subtitle and has never been anywhere else.
#
# The surface that does the teaching is `next_wave_note`, on the message row, BEFORE
# the wave commits -- which is the half -kmjp and -4c1l argued for, because a player
# can only act on an upside they are told about while they still have the seeds.
#
# These pin that, in the direction that failed: prose drifted and nothing could see it.
# A test asserting only "weather_note returns a string" passes against every state
# above, including the one where five comments were wrong.


## The surface a player can ACT on names the weather, and names its number.
##
## Both directions, because a note that mentioned rain and not drought is the exact
## asymmetry -kmjp filed: assert each weather is named AND that the number it is worth
## is in the string, derived from the constant rather than typed here.
func test_the_prep_note_is_where_weather_is_actually_taught() -> String:
	var rain: String = Hud.next_wave_note(4, 8, false, WaveDirector.WEATHER_RAIN, false)
	var err: String = _T.assert_true(rain.to_lower().contains("rain"),
		"the prep note names rain (got: %s)" % rain)
	if err == "":
		err = _T.assert_true(
			rain.contains(str(int(round(WaveDirector.WEATHER_RAIN_HEAL_FRACTION * 100.0)))),
			("and carries the heal PERCENTAGE, not a bare 'rain' -- a player cannot "
				+ "spend on an upside whose size they are not told (got: %s)" % rain))
	if err == "":
		var dry: String = Hud.next_wave_note(4, 8, false, WaveDirector.WEATHER_DROUGHT, false)
		err = _T.assert_true(dry.to_lower().contains("drought"),
			"the prep note names drought too (got: %s)" % dry)
		if err == "":
			err = _T.assert_true(
				dry.contains(str(int(round(WaveDirector.WEATHER_DROUGHT_SEED_BONUS * 100.0)))),
				"and its compensation percentage (got: %s)" % dry)
	if err == "":
		var clear: String = Hud.next_wave_note(4, 8, false, WaveDirector.WEATHER_CLEAR, false)
		err = _T.assert_false(clear.to_lower().contains("rain") or clear.to_lower().contains("drought"),
			("and a clear wave names neither -- without this the two assertions above "
				+ "pass on a note that names both every time (got: %s)" % clear))
	return err


## `weather_note` is the banner's subtitle and nothing else, which is the fact five
## comments got wrong.
##
## Asserted as a REACHABILITY claim rather than a string claim: the point is not what
## the words are, it is that `show_weather` is the only thing that consumes them and
## that `show_weather` loses the banner to a wave beat. A future status row would break
## this test, and breaking it is the correct outcome -- it should be re-read, not
## deleted, because the comment above it is the argument that would need rewriting.
func test_the_weather_subtitle_reaches_the_player_only_through_a_banner_that_loses() -> String:
	var err: String = _T.assert_gt(Hud.weather_note(WaveDirector.WEATHER_RAIN).length(), 0,
		"there is a weather subtitle to place")
	if err == "":
		err = _T.assert_true(
			Hud.banner_claim_rank(Hud.BANNER_CLAIM_WEATHER)
				< Hud.banner_claim_rank(Hud.BANNER_CLAIM_WAVE),
			("and it ranks BELOW the wave beat, so it is refused whenever a wave opens "
				+ "-- which is every time Game._on_wave_started calls it"))
	if err == "":
		err = _T.assert_true(
			Hud.banner_claim_rank(Hud.BANNER_CLAIM_WEATHER)
				< Hud.banner_claim_rank(Hud.BANNER_CLAIM_CLEARED),
			"and below the cleared beat, which is the other thing that can be standing")
	if err == "":
		# The direction that makes the two above mean something: weather still OUTRANKS
		# nothing-claimed, so it is a real claim that loses, not a no-op.
		err = _T.assert_true(
			Hud.banner_claim_rank(Hud.BANNER_CLAIM_WEATHER)
				> Hud.banner_claim_rank(Hud.BANNER_CLAIM_NONE),
			("while still outranking the un-claimed banner -- weather LOSES a contest, "
				+ "it is not a claim that does nothing"))
	return err


## A shot pest recoils, and the recoil out-reads its own walk (plant-tower-defense-qhgs).
##
## The other side of the fight finally answers. `Plant` has flinched since cycle 86; a pest
## taking a kernel to the face differed from one that took nothing in HIT_FLASH_DURATION's
## 0.10s of hue and in nothing else, against this project's standing rule that colour is
## never the only signal.
##
## Asserted through `flinch_amount` and `gait_yaw`, both pure, because everything in
## `_gait` past the `animations_enabled()` gate is unreachable headless — the same reason
## `Plant.flinch_amount` exists and the same trap `assert-an-animation` names: a test that
## pumps `_gait` and reads `_sprite.rotation` is asserting an early return.
##
## The arm-and-decay half IS driven through the real methods, because `flash_hit()` arms
## before its gate on purpose, so `_gait` can be stepped headless and the clock watched
## run down. What no headless test can see is the yaw actually on screen; that is the one
## claim left for a running game.
func test_a_shot_pest_recoils_further_than_it_walks() -> String:
	var err: String = _T.assert_float_eq(Pest.flinch_amount(Pest.FLINCH_SECONDS), 1.0,
		0.0001, "the instant of a hit is full recoil")
	if err == "":
		err = _T.assert_float_eq(Pest.flinch_amount(0.0), 0.0, 0.0001,
			"and it is gone once the window closes")
	if err == "":
		# Monotone down across the whole window, which a before/after pair cannot see.
		var previous: float = 1.0
		for i: int in range(1, 17):
			var left: float = Pest.FLINCH_SECONDS * (1.0 - float(i) / 16.0)
			var here: float = Pest.flinch_amount(left)
			err = _T.assert_true(here < previous,
				"the recoil only decays; at %.3fs left it went %.3f -> %.3f"
					% [left, previous, here])
			if err != "":
				return err
			previous = here
	if err == "":
		err = _T.assert_float_eq(Pest.flinch_amount(Pest.FLINCH_SECONDS * 4.0), 1.0,
			0.0001, "and a re-arm under sustained fire is clamped rather than stacking")
	if err == "":
		# GAIT_SWING is the LARGEST yaw any pest walks with -- both multipliers shrink it
		# (WINGED 0.45, ARMOURED 0.6), so the base is the ceiling and the comparison holds
		# for every pest on the board rather than for the plain one.
		err = _T.assert_true(Pest.FLINCH_RADIANS > Pest.GAIT_SWING * 2.0,
			"a recoil is clearly bigger than the walk (%.3f vs %.3f rad)"
				% [Pest.FLINCH_RADIANS, Pest.GAIT_SWING])
	if err == "":
		# The absolute floor, in pixels, at half a cell from the pivot. Every assertion
		# above is written in terms of FLINCH_RADIANS and would pass with it set to 0.0 --
		# which is the mutation that survived cycle 71 on the plant's side.
		var swing_px: float = sin(Pest.FLINCH_RADIANS) * (float(Board.CELL) * 0.5)
		err = _T.assert_gte(swing_px, 2.0,
			"and big enough to see: %.2f px at half a cell out" % swing_px)
	return err


## The recoil clock is faster than any walk it has to interrupt (plant-tower-defense-qhgs).
##
## This is the one place a pest's flinch could not copy the plant's numbers. `Plant` sways
## at WOBBLE_RATE 1.15 and can pick any fast flinch rate it likes; a pest's gait clock is
## computed per pest from its speed and its mutations, and a winged one at the speed clamp
## runs at GAIT_RATE * GAIT_RATE_MAX * WINGED_RATE_MULTIPLIER. A FLINCH_RATE below that is
## SLOWER than the walk it is meant to interrupt, and would read as a lurch in the gait
## rather than as a hit.
##
## Enumerated over the whole trait matrix and both ends of the speed clamp rather than
## checked against the fastest species that happens to exist today, so a species added at
## speed 200, or a fourth rate multiplier, fails here instead of quietly landing above it.
func test_the_recoil_clock_outruns_every_gait_clock() -> String:
	var err: String = ""
	# Either side of the clamp by a wide margin, so the clamp itself is what is measured
	# rather than any species' current speed.
	var speeds: Array[float] = [1.0, Pest.GAIT_REFERENCE_SPEED, 10000.0]
	var checked: int = 0
	for armoured: bool in [false, true]:
		for winged: bool in [false, true]:
			for speed: float in speeds:
				var rate: float = Pest.gait_rate(speed, armoured, winged)
				checked += 1
				err = _T.assert_true(Pest.FLINCH_RATE > rate,
					("the recoil must out-run the walk it interrupts: armoured=%s "
						+ "winged=%s speed=%.0f walks at %.2f rad/s, recoil is %.2f")
						% [armoured, winged, speed, rate, Pest.FLINCH_RATE])
				if err != "":
					return err
	if err == "":
		err = _T.assert_eq(checked, 12,
			"the trait matrix is 2 x 2 x 3 and every cell must be asked (%d asked)" % checked)
	return err


## Damage arms the recoil and time takes it away (plant-tower-defense-qhgs).
##
## Driven through the real `flash_hit()` and `_gait()` rather than through the pure pair
## above, because the thing worth checking here is the WIRING: that the cue a Kernel
## already fires is the one that arms the motion, and that the decay runs on a machine
## where `animations_enabled()` is false. Both are true only because each sits before its
## early return, which is an ordering nothing else in the suite would notice if it moved.
func test_damage_arms_a_pest_recoil_that_then_runs_out() -> String:
	var pest: Pest = _pest(Pest.APHID, Vector2(100, 100))
	var err: String = _T.assert_float_eq(Pest.flinch_amount(pest._flinch_left), 0.0, 0.0001,
		"an unhit pest carries no recoil")
	if err == "":
		pest.flash_hit()
		err = _T.assert_float_eq(Pest.flinch_amount(pest._flinch_left), 1.0, 0.0001,
			"a hit that landed arms it in full, headless included")
	if err == "":
		pest._gait(Pest.FLINCH_SECONDS * 0.5)
		var half: float = Pest.flinch_amount(pest._flinch_left)
		err = _T.assert_true(half > 0.4 and half < 0.6,
			"half the window later it is about half gone (%.3f)" % half)
	if err == "":
		# Past the end of the window, not exactly on it, so the clamp at zero is what is
		# being read rather than a float landing on the boundary.
		pest._gait(Pest.FLINCH_SECONDS)
		err = _T.assert_float_eq(Pest.flinch_amount(pest._flinch_left), 0.0, 0.0001,
			"and it runs out rather than going negative or sticking")
	if err == "":
		# The yaw seam, at the two states the wiring above produces. A pest with no recoil
		# left must walk exactly as it did before anything shot it -- a flinch that leaves
		# a permanent offset in the gait is the failure this pins.
		err = _T.assert_float_eq(Pest.gait_yaw(1.0, Pest.GAIT_SWING, 1.0, 0.0),
			Pest.GAIT_SWING, 0.0001,
			"with the recoil spent, the yaw is the walk and nothing else")
	if err == "":
		err = _T.assert_gt(absf(Pest.gait_yaw(1.0, Pest.GAIT_SWING, -1.0, 1.0)),
			Pest.GAIT_SWING,
			"and at full recoil against the walk it still moves the body the other way")
	pest.free()
	return err


## A Chomp with a full mouth champs, and out-reads its own breathe
## (plant-tower-defense-ts34).
##
## The asymmetry this closes: the pest IN the mouth has always shown the meal —
## `ChompFlower._chew` calls `set_chewed` on it and `Pest._gait` multiplies that into the
## sprite scale every frame — while the flower doing the eating swayed exactly like an idle
## one. Its only tell was the drawn chew ring, which is a timer readout, and one channel is
## not enough here.
##
## Asserted through `champ_scale`, which is pure, because everything in `Plant._wobble`
## past the `animations_enabled()` gate is unreachable headless — the same seam
## `Plant.breathe_scale` and `Pest.gait_yaw` exist for, and the trap
## `assert-an-animation` names: a test that pumps `_wobble` and reads the pivot is
## asserting an early return.
func test_a_chewing_chomp_champs_further_than_it_breathes() -> String:
	var err: String = _T.assert_eq(ChompFlower.champ_scale(0.0, false), Vector2.ONE,
		"an empty mouth is the identity — a Chomp with nothing in it moves like any plant")
	if err == "":
		# Across a whole period, so the claim is about the motion and not about one lucky
		# sample. The peak has to clear the idle breathe or the champ reads as nothing.
		var peak: float = 0.0
		var trough: float = 0.0
		for i: int in range(0, 121):
			var clock: float = float(i) / 120.0 * (TAU / ChompFlower.CHAMP_RATE)
			var at: Vector2 = ChompFlower.champ_scale(clock, true)
			peak = maxf(peak, at.x - 1.0)
			trough = minf(trough, at.x - 1.0)
			# The two axes are opposite at every point: a mouth closing is a head
			# flattening AND widening, not a plant getting bigger.
			err = _T.assert_float_eq(at.x + at.y, 2.0, 0.0001,
				"the champ trades one axis for the other at clock %.3f (got %s)" % [clock, at])
			if err != "":
				return err
		if err == "":
			err = _T.assert_gt(peak, Plant.BREATHE_AMOUNT * 2.0,
				("a champ has to clearly out-read the idle breathe (%.4f peak vs "
					+ "BREATHE_AMOUNT %.4f)") % [peak, Plant.BREATHE_AMOUNT])
		if err == "":
			# No assert_lt in the runner, so the same claim as a positive magnitude.
			err = _T.assert_gt(-trough, Plant.BREATHE_AMOUNT * 2.0,
				"and in both directions, not just one (%.4f trough)" % trough)
		if err == "":
			# The absolute floor, in pixels, on a 64px sprite. Every assertion above is
			# relative to CHAMP_AMOUNT and would pass with it set to 0.0 -- which is
			# exactly the mutation that survived cycle 71 on BREATHE_AMOUNT.
			var swing_px: float = peak * float(Board.CELL)
			err = _T.assert_gte(swing_px, 2.0,
				"and big enough to see: %.2f px on a cell-sized sprite" % swing_px)
	return err


## The hook changes nothing for a plant that does not want it (plant-tower-defense-ts34).
##
## `Plant.idle_scale_multiplier` is multiplied into the breathe for EVERY plant, so the
## default has to be the exact identity or the hook's existence is a silent change to all
## eight of them. Vector2.ONE is that identity for a component-wise multiply, and this is
## the test that says so rather than the comment.
##
## Swept over the catalogue rather than sampled: a plant added later that overrides the
## hook by accident, or a base class that stops returning ONE, fails here instead of
## quietly shifting every bed on the board.
func test_only_the_chomp_overrides_the_idle_scale_hook() -> String:
	# Through Game.new_plant and over PlantCatalog.ids(), the same pairing
	# test_exactly_two_plants_in_the_catalogue_grow_and_the_rest_are_born_finished uses
	# and for the same reason: the match in new_plant is what decides which class a
	# placed plant actually gets, so a plant added to the catalogue reaches this test
	# whether or not anyone remembers it exists.
	var game := await _T.instantiate_scene("res://game/game.tscn") as Game
	var overriding: Array[String] = []
	var checked: int = 0
	var err: String = ""
	for id: StringName in PlantCatalog.ids():
		var plant: Plant = Game.new_plant(id)
		if plant == null:
			err = "Game.new_plant built nothing for %s" % id
			break
		checked += 1
		# Two clocks, because a hook returning ONE only at zero would pass a single read.
		if (plant.idle_scale_multiplier(0.0) != Vector2.ONE
				or plant.idle_scale_multiplier(1.234) != Vector2.ONE):
			overriding.append(str(id))
		plant.free()
	if err == "":
		err = _T.assert_gt(checked, 1,
			"the catalogue really was swept -- a loop over nothing asserts nothing")
	if err == "":
		# An UNHELD Chomp is the identity too, and that is the point: the override is keyed
		# to having a pest in the mouth, not to being a Chomp. So a freshly built plant of
		# every kind, Chomp included, must be inert here.
		err = _T.assert_eq(overriding.size(), 0,
			("no plant moves off the shared breathe while idle, and these do: %s"
				% str(overriding)))
	_T.free_ui(game)
	return err


## A plant nearly dead leans, and the threshold is DERIVED from what kills it
## (plant-tower-defense-tkwf).
##
## The flinch says "just hit" and decays in 0.32s. Between bites a plant at 8% health and
## one at 95% were the same silhouette, and the difference lived entirely in a health bar
## the player has to be looking at — a bar which is itself a continuous lerp
## (`Hud.health_color_on`), so it answers by hue alone against this project's standing rule
## that colour is never the only signal.
##
## THE DERIVATION IS THE POINT OF THIS TEST. `wilt_threshold()` is `Pest.EAT_DPS /
## MAX_HEALTH` — one second of a hungry pest's chewing — and pinning it as a literal here
## would recreate exactly the drift the derivation exists to prevent. Asserted against the
## two constants it comes from, so a retune of either moves the cue with the danger.
func test_a_plant_wilts_below_one_second_of_chewing() -> String:
	var err: String = _T.assert_float_eq(Plant.wilt_threshold(),
		Pest.EAT_DPS / Plant.MAX_HEALTH, 0.0001,
		"the wilt starts at one second of chewing, derived rather than typed")
	if err == "":
		# And that it is a SANE fraction rather than an accident of two constants: a
		# threshold at 1.0 would wilt every plant that has ever been touched, and one at
		# 0.0 would wilt nothing.
		err = _T.assert_true(Plant.wilt_threshold() > 0.1 and Plant.wilt_threshold() < 0.6,
			("one second of chewing is %.3f of a plant -- outside 0.1..0.6 the cue is "
				+ "either constant or unreachable, and the balance moved under it")
				% Plant.wilt_threshold())
	if err == "":
		err = _T.assert_float_eq(Plant.wilt_amount(1.0), 0.0, 0.0001,
			"a full plant does not lean")
	if err == "":
		err = _T.assert_float_eq(Plant.wilt_amount(Plant.wilt_threshold()), 0.0, 0.0001,
			"and neither does one exactly at the threshold")
	if err == "":
		err = _T.assert_float_eq(Plant.wilt_amount(0.0), 1.0, 0.0001,
			"a plant at zero health is fully wilted")
	if err == "":
		# Monotone across the whole band, which a before/after pair cannot see.
		var previous: float = 0.0
		for i: int in range(1, 21):
			var fraction: float = Plant.wilt_threshold() * (1.0 - float(i) / 20.0)
			var here: float = Plant.wilt_amount(fraction)
			err = _T.assert_true(here > previous,
				"the lean only deepens; at %.3f health it went %.3f -> %.3f"
					% [fraction, previous, here])
			if err != "":
				return err
			previous = here
	return err


## The lean is HELD, big enough to read, and leans different ways on neighbouring beds
## (plant-tower-defense-tkwf).
##
## Held is the design: `_wobble`'s rotation already carries two sinusoids on deliberately
## separate clocks, and a third at any frequency phase-locks with one of them eventually. A
## DC offset has no frequency to lock with — so this asserts the OFFSET, and that the sway
## still swings its full range about it rather than being replaced by it.
func test_the_wilt_is_a_held_lean_that_neighbours_do_not_share() -> String:
	# Big enough to out-read the idle sway, or it is not a state, it is a mood. Same rule
	# FLINCH_RADIANS is pinned by and for the same reason.
	var err: String = _T.assert_true(Plant.WILT_RADIANS > Plant.WOBBLE_RADIANS * 2.0,
		"a full lean clearly out-reads the sway (%.3f vs %.3f rad)"
			% [Plant.WILT_RADIANS, Plant.WOBBLE_RADIANS])
	if err == "":
		# The absolute floor in PIXELS, on the corner of a cell-sized sprite. Every
		# assertion above is relative to WILT_RADIANS and would pass with it set to 0.0 —
		# the cycle-71 mutation, which survived exactly that shape of test.
		var lean_px: float = sin(Plant.WILT_RADIANS) * (float(Board.CELL) * 0.5)
		err = _T.assert_gte(lean_px, 4.0,
			"and is visible: %.2f px at half a cell out" % lean_px)
	if err == "":
		err = _T.assert_float_eq(Plant.wilt_angle(0.0, 0.0), 0.0, 0.0001,
			"a plant with no wilt has no lean at all")
	if err == "":
		# BOTH directions must occur across the phases real cells produce, or every dying
		# plant in a row tips identically and it reads as a rendering fault.
		var left: int = 0
		var right: int = 0
		var checked: int = 0
		for y: int in range(Board.ROWS):
			for x: int in range(Board.COLS):
				var phase: float = Plant._wobble_phase(Vector2i(x, y))
				var angle: float = Plant.wilt_angle(1.0, phase)
				checked += 1
				if angle > 0.0:
					right += 1
				elif angle < 0.0:
					left += 1
		err = _T.assert_eq(checked, Board.ROWS * Board.COLS,
			"every cell on the board was asked (%d)" % checked)
		if err == "":
			err = _T.assert_gt(left, 0,
				"some cells lean one way (%d of %d)" % [left, checked])
		if err == "":
			err = _T.assert_gt(right, 0,
				"and some the other (%d of %d) -- a constant sign reads as a bug"
					% [right, checked])
	if err == "":
		# The composition claim: the sway still swings its FULL range about the lean rather
		# than being flattened by it. Asserted as the arithmetic `_wobble` performs, since
		# everything past its animations gate is unreachable headless.
		var lean: float = Plant.wilt_angle(1.0, 0.0)
		var high: float = lean + Plant.WOBBLE_RADIANS
		var low: float = lean - Plant.WOBBLE_RADIANS
		err = _T.assert_float_eq(high - low, Plant.WOBBLE_RADIANS * 2.0, 0.0001,
			"a wilting plant still breathes through its whole sway, displaced")
		if err == "":
			err = _T.assert_true(low > Plant.WOBBLE_RADIANS,
				("and never returns to where a healthy plant sits: the leaning range is "
					+ "%.3f..%.3f against a healthy %.3f..%.3f")
					% [low, high, -Plant.WOBBLE_RADIANS, Plant.WOBBLE_RADIANS])
	return err


## Only a plant in real danger leans, swept over the catalogue (plant-tower-defense-tkwf).
##
## `wilt_amount` is on the base class, so EVERY plant gains this — which is right, and is
## exactly why it needs the sweep `test_only_the_chomp_overrides_the_idle_scale_hook` does
## for the other hook: a freshly built plant of any kind must be upright, and the same
## plant at one hit point must not be.
func test_every_plant_stands_up_until_it_is_in_danger() -> String:
	# The literal path, not GAME_SCENE: that constant is test_selftest.gd's and this file
	# spells the scene out, as test_exactly_two_plants_in_the_catalogue_grow_and_the_rest
	# _are_born_finished does a few hundred lines up.
	var game := await _T.instantiate_scene("res://game/game.tscn") as Game
	var err: String = ""
	var checked: int = 0
	for id: StringName in PlantCatalog.ids():
		var plant: Plant = Game.new_plant(id)
		if plant == null:
			err = "Game.new_plant built nothing for %s" % id
			break
		checked += 1
		err = _T.assert_float_eq(Plant.wilt_amount(plant.health / Plant.MAX_HEALTH),
			0.0, 0.0001, "%s stands up straight at full health" % id)
		if err == "":
			# One hit point: unambiguously in danger for every plant, since MAX_HEALTH is
			# shared and the threshold is a fraction of it.
			plant.health = 1.0
			err = _T.assert_gt(Plant.wilt_amount(plant.health / Plant.MAX_HEALTH), 0.5,
				"%s leans hard at 1hp" % id)
		plant.free()
		if err != "":
			break
	if err == "":
		err = _T.assert_gt(checked, 1, "the catalogue was swept (%d plants)" % checked)
	_T.free_ui(game)
	return err


## The recoil and the flash now read the same verdict (plant-tower-defense-zdy2).
##
## THE DEFECT THIS PINS is not the one the bead asked about. It asked whether a
## sundew-stuck pest should recoil as hard as a shot one. The enumeration found something
## worse alongside it: a hit a Shield Bug's plate ATE already flashes at
## `SHELL_FLASH_DIM` 0.45 against `HIT_FLASH_BOOST` 1.9 — a 4.2x split saying "that did
## nothing" — while the recoil said "that hit hard" in the same frame. Two channels, one
## event, opposite claims. That is a contradiction rather than a judgement.
##
## Asserted through the constants and the armed state rather than by watching a pest,
## because `_gait` early-returns on `animations_enabled()` headless — the same seam
## `gait_yaw` and `flinch_amount` exist for.
func test_a_glancing_cue_shakes_less_than_a_hit_that_landed() -> String:
	var err: String = _T.assert_true(Pest.GLANCE_FLINCH_SCALE < 1.0,
		"a glance is gentler than a hit that landed (%.2f)" % Pest.GLANCE_FLINCH_SCALE)
	if err == "":
		err = _T.assert_gt(Pest.GLANCE_FLINCH_SCALE, 0.0,
			"and is not nothing -- something DID happen to the bug")
	if err == "":
		# THE FLOOR, and it is absolute rather than a fraction of itself: a scale that
		# drops the recoil below the pest's own walk is not a quiet cue, it is no cue.
		# Written against GAIT_SWING because that is the motion it has to out-read, the
		# same rule FLINCH_RADIANS itself is pinned by.
		var glanced: float = Pest.FLINCH_RADIANS * Pest.GLANCE_FLINCH_SCALE
		err = _T.assert_gt(glanced, Pest.GAIT_SWING,
			("a glancing recoil still out-reads the walk: %.3f rad against GAIT_SWING "
				+ "%.3f") % [glanced, Pest.GAIT_SWING])
	if err == "":
		# And the colour's own split, quoted here so the two channels are compared in one
		# place. This is what the recoil was contradicting.
		# assert_gt with the operands the other way up: the helper set has no assert_lt.
		err = _T.assert_gt(Pest.HIT_FLASH_BOOST, Pest.SHELL_FLASH_DIM,
			("the colour already split these 4.2x (%.2f bright vs %.2f dim) while the "
				+ "recoil split them not at all -- that gap is what this cycle closed")
				% [Pest.HIT_FLASH_BOOST, Pest.SHELL_FLASH_DIM])
	return err


## Half the callers of flash_hit never damaged the pest, and the split is deliberate
## (plant-tower-defense-zdy2).
##
## THE ENUMERATION IS THE TEST. Six call sites; three of them damage. The Chomp calls
## nothing that damages at all — it holds a pest, chews it cosmetically through
## `set_chewed`, and kills it when its own clock runs out — so before this cycle it was
## saying "a hit landed" in motion about a pest that had taken nothing.
##
## Read from SOURCE rather than by driving each plant, because the question is "which
## callers pass the glancing flag", which is a fact about the call sites and not about any
## runtime state. A behavioural version would need six scenarios and would still not tell
## you a seventh caller had appeared.
func test_only_the_sundew_calls_the_hit_cue_glancing() -> String:
	var glancing: Array[String] = []
	var plain: Array[String] = []
	var dir: DirAccess = DirAccess.open("res://game")
	var err: String = _T.assert_true(dir != null, "res://game is readable")
	if err != "":
		return err
	for name: String in dir.get_files():
		if not name.ends_with(".gd"):
			continue
		var src: String = FileAccess.get_file_as_string("res://game/%s" % name)
		if name == "pest.gd":
			continue  # the declaration itself, not a call site
		var from: int = 0
		while true:  # loop-bound-check: ok - breaks below the moment src.find() returns -1; from only ever advances.
			var at: int = src.find("flash_hit(", from)
			if at < 0:
				break
			from = at + 1
			var close: int = src.find(")", at)
			var args: String = src.substr(at + 10, maxi(0, close - at - 10)).strip_edges()
			if args == "true":
				glancing.append(name)
			elif args == "":
				plain.append(name)
	if err == "":
		err = _T.assert_gt(glancing.size() + plain.size(), 3,
			("the sweep found %d call site(s) -- a scan that matches almost nothing "
				+ "reports clean over the wrong thing")
				% (glancing.size() + plain.size()))
	if err == "":
		# THE DECISION, asserted so a future caller has to come past it.
		err = _T.assert_eq(glancing, ["sticky_sundew.gd"] as Array[String],
			("only the Sundew flashes glancing -- it is the one caller where nothing "
				+ "struck the bug. Got %s") % str(glancing))
	if err == "":
		# The Chomp deliberately does NOT, and this is the assertion that stops a future
		# tidy-up from "fixing" it: being eaten alive is the most violent thing in the
		# game, and it routes through _chew_left rather than take_damage as an
		# implementation detail the bug does not care about.
		err = _T.assert_true(plain.has("chomp_flower.gd"),
			("the Chomp keeps the full recoil on purpose -- see GLANCE_FLINCH_SCALE. "
				+ "Plain callers: %s") % str(plain))
	if err == "":
		err = _T.assert_false(glancing.has("chomp_flower.gd"),
			"and does not also appear as glancing, which would mean two call sites disagree")
	return err


## `flash_hit` actually APPLIES the verdict it computes (plant-tower-defense-zdy2).
##
## WRITTEN BECAUSE A MUTATION SURVIVED. The two tests above assert the CONSTANT and the
## CALL SITES, and neither noticed `_flinch_force = 1.0` being pinned unconditionally --
## which restores the exact defect this cycle set out to fix. A table and a list of callers
## are not the thing that reads them; see .claude/skills/extract-a-testable-seam.
##
## Readable headlessly only because `flash_hit` arms BEFORE its `animations_enabled()`
## gate, which cycle 139 did on purpose so the decay in `_gait` could never inherit a value
## armed only on animated machines. That decision is what makes this assertion possible at
## all, three cycles later.
func test_the_hit_cue_applies_the_verdict_it_computes() -> String:
	var pest: Pest = _pest(Pest.APHID, Vector2(100, 100))
	var err: String = _T.assert_float_eq(pest._flinch_force, 1.0, 0.0001,
		"a pest starts at full force, so a glance below is a change and not a default")
	if err == "":
		pest.flash_hit(true)
		err = _T.assert_float_eq(pest._flinch_force, Pest.GLANCE_FLINCH_SCALE, 0.0001,
			"a glancing cue arms the reduced force")
	if err == "":
		pest.flash_hit()
		err = _T.assert_float_eq(pest._flinch_force, 1.0, 0.0001,
			"and a hit that landed arms the full one -- the force does not stick")
	if err == "":
		# THE SHELL HALF, which is the contradiction the bead did not see: a plate-blocked
		# hit is a plain flash_hit() from Kernel, so the reduction has to come from the
		# CONSUMED `_last_hit_blocked` rather than from the caller.
		pest._last_hit_blocked = true
		pest.flash_hit()
		err = _T.assert_float_eq(pest._flinch_force, Pest.GLANCE_FLINCH_SCALE, 0.0001,
			("a hit the plate ate shakes like a glance, because the colour already says "
				+ "so at SHELL_FLASH_DIM and the two channels must not disagree"))
	if err == "":
		err = _T.assert_false(pest._last_hit_blocked,
			"and the verdict is CONSUMED, so the next cue does not inherit it")
	if err == "":
		pest.flash_hit()
		err = _T.assert_float_eq(pest._flinch_force, 1.0, 0.0001,
			"which the very next plain flash proves by coming back at full force")
	pest.free()
	return err


# -- The Chomp's catch: vines, the haul, and eating on top of the flower ------
#
# Every function under test here is a pure static, which is the whole design: the catch
# is derived from `_capture_elapsed` frame by frame rather than tweened, so there is no
# part of it that only exists on a machine pumping frames. See the CATCH block in
# `game/chomp_flower.gd` and `.claude/skills/assert-an-animation`.


## The cap, and the reason it exists: an aphid's entire meal is 0.45s and a fixed 0.32s
## catch would spend five sixths of it hauling.
##
## Pinned against absolute seconds and not only against CAPTURE_SECONDS: an assertion
## written purely as a multiple of the thing under test survives that thing being zeroed,
## which is the second failure mode `assert-an-animation` names.
func test_a_chomps_catch_is_capped_at_a_fraction_of_the_meal_it_belongs_to() -> String:
	var aphid: float = float(Pest.SPECIES[Pest.APHID]["chew_seconds"])
	var beetle: float = float(Pest.SPECIES[Pest.BEETLE]["chew_seconds"])
	var snatch: float = ChompFlower.capture_seconds_for(aphid)
	var haul: float = ChompFlower.capture_seconds_for(beetle)
	var err: String = _T.assert_float_eq(haul, ChompFlower.CAPTURE_SECONDS, 0.0001,
		"a beetle's 2.6s meal can afford the whole catch, got %.3fs" % haul)
	if err == "":
		err = _T.assert_true(snatch < haul,
			"an aphid's %.2fs meal cannot, and gets a shorter one (%.3fs)" % [aphid, snatch])
	if err == "":
		err = _T.assert_float_eq(snatch, 0.18, 0.0005,
			"0.40 of an aphid's 0.45s, which leaves 0.27s of visible eating; got %.3fs" % snatch)
	if err == "":
		err = _T.assert_true(snatch < aphid * 0.5,
			"and under half the meal, or the eating sprite never gets a turn")
	if err == "":
		err = _T.assert_float_eq(ChompFlower.capture_seconds_for(0.0), 0.0, 0.0001,
			"an empty mouth has no catch to run -- _chew_total is 0.0 between meals")
	return err


## The two beats keep their ratio whatever the cap does to their sum, so a snatched aphid
## and a hauled queen are the same gesture at two speeds.
func test_a_snatched_aphid_and_a_hauled_queen_are_the_same_gesture() -> String:
	var aphid: float = float(Pest.SPECIES[Pest.APHID]["chew_seconds"])
	var queen: float = float(Pest.SPECIES[Pest.QUEEN]["chew_seconds"])
	var err: String = ""
	for meal: float in [aphid, queen]:
		var whole: float = ChompFlower.capture_seconds_for(meal)
		var lash: float = ChompFlower.lash_seconds_for(meal)
		if err == "":
			err = _T.assert_float_eq(lash / whole,
				ChompFlower.LASH_SECONDS / ChompFlower.CAPTURE_SECONDS, 0.0001,
				"a %.2fs meal splits its catch in the same proportion" % meal)
		if err == "":
			err = _T.assert_true(lash > 0.0 and lash < whole,
				"and both beats are real -- lash %.4f of %.4f" % [lash, whole])
	if err == "":
		# The absolute, so zeroing LASH_SECONDS does not leave the ratio claim above true.
		err = _T.assert_float_eq(ChompFlower.lash_seconds_for(queen), 0.10, 0.0005,
			"a queen affords the full 0.10s lash, got %.4f"
				% ChompFlower.lash_seconds_for(queen))
	return err


## The three beats, in order, off one clock. The point of the sweep is that the boundaries
## line up: the lash finishes exactly where the haul starts, and the haul finishes inside
## the catch rather than trailing into the meal.
func test_a_chomps_catch_runs_lash_then_haul_then_holds() -> String:
	var meal: float = float(Pest.SPECIES[Pest.BEETLE]["chew_seconds"])
	var lash_span: float = ChompFlower.lash_seconds_for(meal)
	var whole: float = ChompFlower.capture_seconds_for(meal)
	var err: String = _T.assert_float_eq(ChompFlower.lash_progress(0.0, meal), 0.0, 0.0001,
		"the vines have not left the flower on the frame the mouth closes")
	if err == "":
		err = _T.assert_float_eq(ChompFlower.haul_progress(0.0, meal), 0.0, 0.0001,
			"and nothing is being dragged yet")
	if err == "":
		err = _T.assert_float_eq(ChompFlower.lash_progress(lash_span, meal), 1.0, 0.0001,
			"the vines reach the bug exactly at the end of the lash")
	if err == "":
		err = _T.assert_float_eq(ChompFlower.haul_progress(lash_span, meal), 0.0, 0.0001,
			"which is the same instant the haul starts -- no gap, no overlap")
	if err == "":
		err = _T.assert_float_eq(ChompFlower.haul_progress(whole, meal), 1.0, 0.0001,
			"and the bug is home at the end of the catch, well inside the meal")
	if err == "":
		# Monotone, and strictly so across the middle: a haul that plateaus is a bug that
		# stops in mid-air.
		var last: float = -1.0
		var steps: int = 20
		for i in range(steps + 1):
			var at: float = whole * float(i) / float(steps)
			var now: float = ChompFlower.haul_progress(at, meal)
			if now < last:
				err = "the haul went backwards at %.4fs (%.4f after %.4f)" % [at, now, last]
				break
			last = now
	if err == "":
		err = _T.assert_float_eq(ChompFlower.haul_progress(meal, meal), 1.0, 0.0001,
			"and it stays home for the whole of the chew that follows")
	return err


## The endpoints of the carry, which are the load-bearing part: exactly ZERO at the start
## is what lets every other system keep believing the pest is on the road, and exactly
## `travel` at the end is what puts it in the mouth rather than near it.
func test_a_hauled_bug_starts_on_the_road_and_lands_exactly_in_the_mouth() -> String:
	# Down-left, so a sign error on either axis is a different answer.
	var travel := Vector2(-48.0, -31.0)
	# The easing's endpoints first, because they are what makes every claim below EXACT
	# rather than approximate: `carry_offset_at` lands on `travel` only because
	# `smooth(1)` is 1, and `release()` restores the road by writing a zero only because
	# `smooth(0)` is 0.
	var err: String = _T.assert_float_eq(ChompFlower.smooth(0.0), 0.0, 0.0,
		"smoothstep starts at exactly 0")
	if err == "":
		err = _T.assert_float_eq(ChompFlower.smooth(1.0), 1.0, 0.0,
			"and ends at exactly 1")
	if err == "":
		err = _T.assert_float_eq(ChompFlower.smooth(0.5), 0.5, 0.0001,
			"symmetric about the middle")
	if err == "":
		err = _T.assert_float_eq(ChompFlower.smooth(-3.0), 0.0, 0.0,
			"and clamped, so a clock that overran does not throw the bug past the mouth")
	if err == "":
		err = _T.assert_float_eq(ChompFlower.smooth(9.0), 1.0, 0.0, "at either end")
	if err == "":
		err = _T.assert_eq(ChompFlower.carry_offset_at(travel, 0.0), Vector2.ZERO,
			"at the start the body is exactly where its node stands")
	if err == "":
		err = _T.assert_eq(ChompFlower.carry_offset_at(travel, 1.0), travel,
			"and at the end it is exactly at the mouth, not near it")
	if err == "":
		var mid: Vector2 = ChompFlower.carry_offset_at(travel, 0.5)
		err = _T.assert_float_eq(mid.x, travel.x * 0.5, 0.0001,
			"halfway across at halfway through")
		if err == "":
			err = _T.assert_true(mid.y < travel.y * 0.5,
				("and ABOVE the straight line, which is the arc -- got %.2f against a "
					+ "chord of %.2f") % [mid.y, travel.y * 0.5])
		if err == "":
			err = _T.assert_float_eq(mid.y, travel.y * 0.5 - ChompFlower.HAUL_ARC_HEIGHT,
				0.0001, "by the full HAUL_ARC_HEIGHT at the top of the arc")
	if err == "":
		# The arc is a lift, not a drift: it is gone by the time the bug lands, or the
		# meal would be eaten HAUL_ARC_HEIGHT above the flower.
		err = _T.assert_float_eq(ChompFlower.carry_offset_at(travel, 1.0).y, travel.y,
			0.0001, "and the lift is spent by the landing")
	if err == "":
		err = _T.assert_eq(ChompFlower.carry_offset_at(Vector2.ZERO, 0.5).x, 0.0,
			"a bug already on top of the flower is not thrown sideways")
	return err


## A vine starts on the plant and ends on the bug. Both endpoints, for every vine, at
## every point in the reach -- the failure this shape is chosen to rule out is a vine
## that stops short of the thing it is supposed to be holding.
func test_every_vine_reaches_from_the_flower_to_the_bug_it_is_holding() -> String:
	var prey := Vector2(62.0, -6.0)
	var err: String = ""
	for index in range(ChompFlower.VINE_COUNT):
		var tip: Vector2 = ChompFlower.vine_tip(index, prey, 1.0)
		var curve: PackedVector2Array = ChompFlower.vine_curve(
			ChompFlower.vine_root(index), tip, ChompFlower.VINE_BOW,
			ChompFlower.VINE_SEGMENTS)
		if err == "":
			err = _T.assert_eq(curve.size(), ChompFlower.VINE_SEGMENTS + 1,
				"vine %d is drawn as VINE_SEGMENTS spans" % index)
		if err == "":
			err = _T.assert_eq(curve[0], ChompFlower.vine_root(index),
				"vine %d leaves the flower at its own root" % index)
		if err == "":
			err = _T.assert_eq(curve[curve.size() - 1], tip,
				"and lands exactly on its grip, not near it")
		if err == "":
			# The bow is the whole reason three vines are legible as three, so a curve
			# that is secretly a straight line is a failure.
			var straight: Vector2 = curve[0].lerp(curve[curve.size() - 1], 0.5)
			err = _T.assert_gt(curve[curve.size() / 2].distance_to(straight), 1.0,
				"vine %d actually bows away from the chord" % index)
	if err == "":
		# Reaching: at the start of the lash the vines are still on the plant.
		err = _T.assert_eq(ChompFlower.vine_tip(0, prey, 0.0), Vector2.ZERO,
			"before the lash the vines have not left the flower")
	if err == "":
		var half: Vector2 = ChompFlower.vine_tip(0, prey, 0.5)
		var whole: Vector2 = ChompFlower.vine_tip(0, prey, 1.0)
		err = _T.assert_true(half.length() > 0.0 and half.length() < whole.length(),
			"mid-lash they are out but not there yet (%.2f of %.2f)"
				% [half.length(), whole.length()])
	if err == "":
		# The grips clasp from different sides. Two vines landing on the same point would
		# make VINE_COUNT decorative.
		var seen := {}
		for index in range(ChompFlower.VINE_COUNT):
			seen[ChompFlower.grip_offset(index).snapped(Vector2(0.01, 0.01))] = true
		err = _T.assert_eq(seen.size(), ChompFlower.VINE_COUNT,
			"all %d vines take hold at different points on the bug" % ChompFlower.VINE_COUNT)
	if err == "":
		# The degenerate span `_nearest_free_pest` genuinely permits: a bug at distance 0.
		var dot: PackedVector2Array = ChompFlower.vine_curve(Vector2.ZERO, Vector2.ZERO,
			ChompFlower.VINE_BOW, ChompFlower.VINE_SEGMENTS)
		err = _T.assert_eq(dot[dot.size() - 1], Vector2.ZERO,
			"a bug on top of the flower gets a dot, not a NaN")
	return err


## A loaded vine straightens, and a vine still out writhes. Both pinned to absolutes so
## zeroing either amplitude fails the test rather than trivially satisfying it.
func test_a_pulling_vine_goes_taut_and_a_waiting_one_writhes() -> String:
	# Declared at the top of the function rather than inside the branch that first uses
	# them: an `if` body is its own scope in GDScript, so a `var` written there is gone
	# by the next `if err == "":` block.
	var first: float = ChompFlower.vine_bow(0, 0.0, 1.0)
	var second: float = ChompFlower.vine_bow(1, 0.0, 1.0)
	var err: String = _T.assert_float_eq(ChompFlower.vine_slack(0.0), 1.0, 0.0001,
		"a vine still reaching carries its full bow")
	if err == "":
		err = _T.assert_float_eq(ChompFlower.vine_slack(1.0), ChompFlower.VINE_TAUT_SLACK,
			0.0001, "and a vine under load has straightened out")
	if err == "":
		err = _T.assert_true(ChompFlower.VINE_TAUT_SLACK < 0.6,
			"which is a visible straightening, not a rounding error")
	if err == "":
		# Alternating sign is what separates three vines drawn from nearly one point.
		err = _T.assert_true(first * second < 0.0,
			"neighbouring vines bow to opposite sides (%.2f, %.2f)" % [first, second])
	if err == "":
		err = _T.assert_float_eq(absf(first), ChompFlower.VINE_BOW, 0.0001,
			"at rest on the clock a vine bows by exactly VINE_BOW")
	if err == "":
		# The writhe, read as a real spread over a real second rather than as a multiple
		# of VINE_WRITHE_AMOUNT.
		var low: float = 999.0
		var high: float = -999.0
		for i in range(120):
			var at: float = float(i) / 120.0
			var bow: float = ChompFlower.vine_bow(0, at, 1.0)
			low = minf(low, bow)
			high = maxf(high, bow)
		err = _T.assert_gt(high - low, 2.0,
			"a vine held out for a second visibly writhes (spread %.2f px)" % (high - low))
	if err == "":
		err = _T.assert_float_eq(ChompFlower.vine_bow(0, 0.37, 0.0), 0.0, 0.0001,
			"and a vine with no slack left is straight whatever the clock says")
	return err


## THE POINT OF THE WHOLE DESIGN, and the one a screenshot could never show: the bug is
## DRAWN on the flower and its node is still standing on the road, where Kernel targeting,
## the escape route and `_adjacent_plant` all still find it.
func test_a_bug_eaten_on_top_of_a_chomp_still_stands_on_the_road() -> String:
	var chomp := ChompFlower.new()
	chomp.setup(PlantCatalog.CHOMP, Vector2i(0, 0), null)
	chomp.position = Vector2(0.0, -62.0)
	var beetle: Pest = _prey(Pest.BEETLE, Vector2.ZERO)
	var host: Node2D = _host([chomp, beetle])
	await _T.instantiate_scene(host)

	var road: Vector2 = beetle.position
	var pests: Array[Pest] = [beetle]
	var err: String = _T.assert_true(chomp.is_busy(), "the settle frames closed the mouth")
	if err == "":
		err = _T.assert_true(beetle.is_carried(), "and the vines have hold of the beetle")
	# Past the end of the catch, but nowhere near the end of a beetle's 2.6s meal.
	var spent: float = 0.0
	while spent < ChompFlower.CAPTURE_SECONDS and err == "":
		chomp._act(0.02, pests)
		spent += 0.02
	if err == "":
		err = _T.assert_true(chomp.is_busy(), "still mid-meal, so the beetle is up there now")
	if err == "":
		err = _T.assert_eq(beetle.position, road,
			"the NODE never moved -- this is what keeps a held pest inside a cob's line of fire")
	if err == "":
		var carried: Vector2 = beetle.carry_offset()
		err = _T.assert_true(carried.length() > 20.0,
			"but the BODY was hauled a long way off it (%s)" % carried)
	if err == "":
		err = _T.assert_eq(beetle.carry_offset(),
			(chomp.global_position + ChompFlower.CARRY_ANCHOR) - beetle.global_position,
			"landing exactly on the flower's mouth anchor")
	if err == "":
		err = _T.assert_eq(beetle._sprite.position, beetle.carry_offset(),
			"and the sprite is the thing that moved")
	if err == "":
		err = _T.assert_eq(beetle.z_index, Pest.CARRY_Z_INDEX,
			"drawn above the flower rather than behind it")
	if err == "":
		# Let go alive: everything about the body comes home, because the offset is
		# derived and not tweened, so putting it back is a write of Vector2.ZERO.
		chomp.release()
		err = _T.assert_eq(beetle.carry_offset(), Vector2.ZERO,
			"a beetle a destroyed flower let go is back on the road")
	if err == "":
		err = _T.assert_eq(beetle._sprite.position, Vector2.ZERO, "body and node reunited")
	if err == "":
		err = _T.assert_eq(beetle.z_index, 0, "and back in the ordinary draw order")
	if err == "":
		err = _T.assert_false(beetle.is_carried(), "and nothing has hold of it")
	_T.free_ui(host)
	return err


## The corpse stays where the meal was eaten. Before the kill/release order was reversed
## in `_chew`, a bug swallowed on top of a flower had its body put back on the road one
## line before it died, so the corpse appeared a cell away on the path.
func test_a_bug_swallowed_on_top_of_a_chomp_leaves_its_corpse_up_there() -> String:
	var chomp := ChompFlower.new()
	chomp.setup(PlantCatalog.CHOMP, Vector2i(0, 0), null)
	chomp.position = Vector2(0.0, -62.0)
	# Spawned far out of reach and walked in AFTERWARDS, for the reason
	# `test_a_chomps_bite_records_a_lunge_toward_the_meal` records: `instantiate_scene`
	# pumps settle frames, `_act` runs on every one of them, and an aphid's whole 0.45s
	# meal fits inside them -- so a Chomp handed its lunch at spawn has already eaten it
	# and let go before the first line of the test runs.
	var aphid: Pest = _pest(Pest.APHID, Vector2(-2000.0, 0.0))
	var host: Node2D = _host([chomp, aphid])
	await _T.instantiate_scene(host)
	# Past the stem, not level with it: since q9h4 the mouth will not close otherwise.
	aphid.position = Vector2(ChompFlower.GRAB_LEAD + 4.0, 0.0)

	var pests: Array[Pest] = [aphid]
	var err: String = _T.assert_false(chomp.is_busy(),
		"nothing was in reach during the settle")
	var lifted := Vector2.ZERO
	var spent: float = 0.0
	while spent < 3.0 and err == "" and aphid.is_alive():
		chomp._act(0.02, pests)
		if aphid.is_alive() and aphid.carry_offset() != Vector2.ZERO:
			lifted = aphid.carry_offset()
		spent += 0.02
	if err == "":
		err = _T.assert_false(aphid.is_alive(), "the aphid was swallowed inside 3 seconds")
	if err == "":
		err = _T.assert_true(lifted.length() > 20.0,
			"and it had been hauled onto the flower first (%s)" % lifted)
	if err == "":
		err = _T.assert_eq(aphid.carry_offset(), lifted,
			"the corpse keeps the offset it died at -- it does not drop to the path")
	if err == "":
		err = _T.assert_eq(aphid._sprite.position, aphid.death_knockback() + lifted,
			"which the corpse sprite is placed at, knockback included")
	if err == "":
		err = _T.assert_false(chomp.is_busy(), "and the mouth is free for the next bug")
	_T.free_ui(host)
	return err


## One bug at a time, restated against the catch: a second pest walking into a flower
## mid-haul is not grabbed, and nothing about the first bug's journey is disturbed.
func test_a_chomp_mid_haul_will_not_start_a_second_bug() -> String:
	var chomp := ChompFlower.new()
	chomp.setup(PlantCatalog.CHOMP, Vector2i(0, 0), null)
	chomp.position = Vector2(0.0, -62.0)
	# Both spawned far out of reach and walked in afterwards. Settle frames run `_act`,
	# and an aphid's whole 0.45s meal fits inside them -- letting the settle decide which
	# bug is in the mouth makes this test's answer depend on how many frames
	# `instantiate_scene` happened to pump.
	var beetle: Pest = _pest(Pest.BEETLE, Vector2(-2000.0, 0.0))
	var aphid: Pest = _pest(Pest.APHID, Vector2(-2000.0, 40.0))
	var host: Node2D = _host([chomp, beetle, aphid])
	await _T.instantiate_scene(host)
	# The beetle is the nearer of the two, so the grab below is not a coin toss either.
	# Both past the stem, the beetle by less, so it is still the nearer of the two.
	beetle.position = Vector2(ChompFlower.GRAB_LEAD + 4.0, 0.0)
	aphid.position = Vector2(ChompFlower.GRAB_LEAD + 12.0, 0.0)

	var pests: Array[Pest] = [beetle, aphid]
	var err: String = _T.assert_false(chomp.is_busy(),
		"nothing was in reach during the settle")
	if err == "":
		chomp._act(0.016, pests)
		err = _T.assert_true(chomp.held_pest() == beetle, "the nearer bug was caught")
	# One step into the haul, which is the frame a second grab would be most tempting.
	if err == "":
		chomp._act(ChompFlower.lash_seconds_for(beetle.chew_seconds) + 0.01, pests)
		err = _T.assert_true(chomp.held_pest() == beetle, "the mouth is still on the first bug")
	if err == "":
		err = _T.assert_true(chomp.held_pest().carry_offset().length() > 0.0,
			"which is by now being dragged in")
	if err == "":
		err = _T.assert_eq(aphid.carry_offset(), Vector2.ZERO,
			"the bug that was not caught is not being dragged anywhere")
	if err == "":
		err = _T.assert_false(aphid.is_carried(), "and nothing has hold of it")
	if err == "":
		err = _T.assert_true(aphid.held_by == null, "one bug at a time, which is the plant")
	_T.free_ui(host)
	return err


## The carry seam itself, called directly rather than through a flower: `set_carried`,
## `set_carry_offset`, and the three drawings each one moves.
##
## Worth its own check because the seam is the whole safety argument for hauling a bug
## across the board — it exists so `position` never changes — and a Chomp test that only
## reads `carry_offset()` back is asserting the field, not the drawings that read it.
func test_a_carried_pests_body_moves_and_its_place_on_the_road_does_not() -> String:
	var pest: Pest = _pest(Pest.BEETLE, Vector2(120.0, 40.0))
	var host: Node2D = _host([pest])
	await _T.instantiate_scene(host)

	var road: Vector2 = pest.position
	var bar_home: Vector2 = pest._health_bar.position
	var lift := Vector2(-14.0, -33.0)
	var err: String = _T.assert_false(pest.is_carried(), "a walking pest is not carried")
	if err == "":
		pest.set_carried(true)
		pest.set_carry_offset(lift)
		err = _T.assert_eq(pest.position, road, "the node has not moved and must not")
	if err == "":
		err = _T.assert_eq(pest._sprite.position, lift, "the body has")
	if err == "":
		err = _T.assert_eq(pest._health_bar.position, bar_home + lift,
			"and the health bar went with it, or the pest would be drawn away from its own bar")
	if err == "":
		err = _T.assert_eq(pest._health_back.position, bar_home + lift, "both halves of it")
	if err == "":
		err = _T.assert_eq(pest.carry_offset(), lift, "and the offset reads back")
	if err == "":
		pest.set_carried(false)
		err = _T.assert_eq(pest._sprite.position, Vector2.ZERO, "letting go puts the body back")
	if err == "":
		err = _T.assert_eq(pest._health_bar.position, bar_home, "and the bar with it")
	if err == "":
		# The dead-pest refusal, which is what keeps a corpse on the flower that ate it.
		pest.set_carried(true)
		pest.set_carry_offset(lift)
		pest.kill(Pest.DEATH_BITTEN)
		pest.set_carry_offset(Vector2.ZERO)
		err = _T.assert_eq(pest.carry_offset(), lift,
			"a dead pest ignores the carry -- the corpse stays where it was eaten")
	_T.free_ui(host)
	return err


# -- The ambush: a Chomp waits until the bug is past it -----------------------
#
# plant-tower-defense-q9h4. The mouth used to close on the leading edge of the reach,
# catching a bug before it was level with the stem. `GRAB_LEAD` makes the flower let
# them come on a bit and snap from behind.


## All four headings, by the cross product rather than by three examples, because the
## road turns four times and "past" is a different axis and a different sign on each leg
## of it (`.claude/skills/enumerate-the-pairs`). A rule written as `pest.x > plant.x` is
## right on the three legs `Board.PATH_CORNERS` runs +X along and wrong or meaningless
## on the other four, and only a sweep like this one says so.
func test_a_chomp_waits_for_a_pest_to_pass_from_every_direction() -> String:
	var plant := Vector2(200.0, 300.0)
	var lead: float = ChompFlower.GRAB_LEAD
	var headings: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	var err: String = _T.assert_gt(lead, 0.0, "there is a lead to wait out at all")
	for heading: Vector2 in headings:
		if err != "":
			break
		# Three points on the pest's own line: still coming, exactly level, and past.
		var coming: Vector2 = plant - heading * (lead + 10.0)
		var level: Vector2 = plant
		var past: Vector2 = plant + heading * (lead + 10.0)
		# Operands flipped: the helper set has no assert_lt (test_combat.gd:2089).
		err = _T.assert_gt(0.0, ChompFlower.pass_distance(plant, coming, heading),
			"walking %s: a bug still on its way in is NEGATIVE past the flower" % heading)
		if err == "":
			err = _T.assert_float_eq(ChompFlower.pass_distance(plant, level, heading),
				0.0, 0.0001, "walking %s: level with the stem is exactly 0" % heading)
		if err == "":
			err = _T.assert_float_eq(ChompFlower.pass_distance(plant, past, heading),
				lead + 10.0, 0.001, "walking %s: and past is the distance past" % heading)
		if err == "":
			err = _T.assert_false(
				ChompFlower.is_past_enough(plant, coming, heading, lead),
				"walking %s: the mouth does not close on a bug still approaching" % heading)
		if err == "":
			err = _T.assert_false(
				ChompFlower.is_past_enough(plant, level, heading, lead),
				"walking %s: nor on one level with the stem -- that is the whole change"
					% heading)
		if err == "":
			err = _T.assert_true(
				ChompFlower.is_past_enough(plant, past, heading, lead),
				"walking %s: and does close once it is a little way past" % heading)
		if err == "":
			# The boundary itself, which is where an off-by-one lives.
			err = _T.assert_true(
				ChompFlower.is_past_enough(plant, plant + heading * lead, heading, lead),
				"walking %s: exactly GRAB_LEAD past is past enough" % heading)
		if err == "":
			err = _T.assert_false(
				ChompFlower.is_past_enough(plant, plant + heading * (lead - 0.5),
					heading, lead),
				"walking %s: half a pixel short of it is not" % heading)
	if err == "":
		# The sideways axis is not "past" at all. A bug on a crossing lane that happens
		# to be beside this flower has gone nowhere past it.
		err = _T.assert_float_eq(
			ChompFlower.pass_distance(plant, plant + Vector2(0.0, 90.0), Vector2.RIGHT),
			0.0, 0.0001, "displacement across the heading is not progress along it")
	if err == "":
		# The degenerate default, and it is the SAFE direction: see is_past_enough.
		err = _T.assert_true(
			ChompFlower.is_past_enough(plant, plant, Vector2.ZERO, lead),
			"a pest with no heading is grabbable, because a flower that silently never "
				+ "eats is the worse of the two available failures")
	return err


## THE NUMBER THIS FEATURE CAN DIE ON. A Chomp stands on grass and its prey walks a lane
## one `Board.CELL` away, so the reach only cuts a chord across that lane -- and the lead
## is spent out of the chord. Set it too long and the window closes, the flower eats
## nothing, and NOTHING REPORTS IT: "found no prey" and "there is no prey" are the same
## silence, which is the failure `GRAB_RADIUS`'s own header records from when it was 62.
##
## Written in FRAMES rather than pixels because pixels alone cannot fail honestly -- a
## 4 px window is open and useless. Derived from the species table (not a hand-listed
## few) at each species' own top speed and the fastest game speed the player can pick,
## so a new species or a faster `GameSpeed` step is covered the day it lands.
func test_the_pass_window_stays_open_for_every_species_at_double_speed() -> String:
	var window: float = ChompFlower.pass_window_for(1)
	# The half-chord computed here rather than as `window + GRAB_LEAD`, which is only the
	# same number while the window is still open -- exactly the case this message is for.
	var reach: float = ChompFlower.grab_radius_for(1)
	var half_chord: float = sqrt(maxf(0.0, reach * reach - float(Board.CELL * Board.CELL)))
	var err: String = _T.assert_gt(window, 0.0,
		("GRAB_LEAD %.1f leaves no room at rung 1: a %.1f px reach cuts only a %.1f px "
			+ "half-chord across a lane one cell away, and the lead spends all of it. "
			+ "This flower would never eat, and nothing else in this suite would say so")
			% [ChompFlower.GRAB_LEAD, reach, half_chord])
	if err != "":
		return err
	var fastest_step: float = 1.0
	for step: float in GameSpeed.STEPS:
		fastest_step = maxf(fastest_step, step)
	if err == "":
		err = _T.assert_gte(fastest_step, 2.0,
			"the speed steps still include a 2x, or this test is measuring nothing")
	var checked: int = 0
	for species: StringName in Pest.SPECIES:
		if err != "":
			break
		var speed: float = float(Pest.SPECIES[species]["speed"])
		if speed <= 0.0:
			continue
		# Per physics frame, at the worst case the player can actually produce.
		var travel: float = speed * fastest_step / 60.0
		var frames: float = window / travel
		err = _T.assert_gte(frames, 4.0,
			("'%s' at %.0f px/s crosses the %.1f px pass-window in %.1f physics frames "
				+ "at %.0fx -- too few for the mouth to notice it and close")
				% [species, speed, window, frames, fastest_step])
		checked += 1
	if err == "":
		err = _T.assert_eq(checked, Pest.SPECIES.size(),
			"every species was swept, got %d of %d" % [checked, Pest.SPECIES.size()])
	if err == "":
		# Buying reach widens the window, so no rung is worse off than the one below.
		var previous: float = 0.0
		for level: int in range(1, ChompFlower.LEVELS.size() + 1):
			var w: float = ChompFlower.pass_window_for(level)
			err = _T.assert_gt(w, previous,
				"rung %d widens the pass-window (%.1f after %.1f)" % [level, w, previous])
			if err != "":
				break
			previous = w
	return err


## The rule reaching the selector, which the pure statics above cannot show. Two pests
## in reach, identical but for which way they walk: the mouth takes the one that has
## gone by and leaves the one still coming.
func test_a_chomp_takes_the_bug_that_has_gone_by_and_leaves_the_one_arriving() -> String:
	var chomp := ChompFlower.new()
	chomp.setup(PlantCatalog.CHOMP, Vector2i(0, 0), null)
	chomp.position = Vector2.ZERO
	# Both on the lane one cell up, both well inside GRAB_RADIUS (73.6), one on each
	# side of the stem by more than GRAB_LEAD.
	var arriving: Pest = _pest(Pest.BEETLE, Vector2(-2000.0, -64.0))
	var leaving: Pest = _pest(Pest.BEETLE, Vector2(-2001.0, -64.0))
	var host: Node2D = _host([chomp, arriving, leaving])
	await _T.instantiate_scene(host)
	arriving.position = Vector2(-24.0, -64.0)
	leaving.position = Vector2(24.0, -64.0)

	var pests: Array[Pest] = [arriving, leaving]
	var err: String = _T.assert_false(chomp.is_busy(), "nothing was in reach at spawn")
	if err == "":
		# Both walk +X, which is the leg the default road runs past a Chomp on.
		# By the dot, not by ==: `travel_direction()` rotates a unit vector, which leaves
		# the off-axis component at ~4e-8 rather than at a clean zero.
		err = _T.assert_float_eq(arriving.travel_direction().dot(Vector2.RIGHT), 1.0,
			0.0001, "the arriving beetle is walking right")
	if err == "":
		err = _T.assert_float_eq(leaving.travel_direction().dot(Vector2.RIGHT), 1.0,
			0.0001, "and so is the one that has gone by")
	if err == "":
		err = _T.assert_gt(chomp.grab_radius(),
			arriving.global_position.distance_to(chomp.global_position),
			"the arriving beetle IS inside the reach -- it is refused for its heading, "
				+ "not for its distance")
	if err == "":
		chomp._act(0.016, pests)
		err = _T.assert_true(chomp.held_pest() == leaving,
			"the mouth closed on the bug that had gone past, not the nearer one in front")
	if err == "":
		err = _T.assert_true(arriving.held_by == null,
			"and the arriving beetle walked on untouched")
	if err == "":
		# And it is not a permanent refusal: the same bug, once it has gone by, is prey.
		chomp.release()
		arriving.position = Vector2(ChompFlower.GRAB_LEAD + 2.0, -64.0)
		leaving.position = Vector2(-2000.0, -64.0)
		chomp._act(0.016, pests)
		err = _T.assert_true(chomp.held_pest() == arriving,
			"the bug it let through is caught on the way out")
	_T.free_ui(host)
	return err


# -- the warm cache ---------------------------------------------------------
#
# WHY A LOADING HITCH IS AN AUDIO DEFECT HERE, because that is the part that is not
# obvious and the part these three tests are guarding.
#
# Both stream caches used to fill lazily: `Sfx.stream_for` and `Music._stream_for`
# call `load()` the first time an id is asked for, which is the frame that first
# fires the cue -- a run's first kill, first volley, first bite -- and, for the RUN
# bed, the crossfade that begins a run with a second stream already decoding.
#
# On desktop that stall is a frame nobody sees. On the Web build it is crackle, and
# the chain is written out in project.godot's `[audio]` block: `default_playback_type
# .web=0` puts every voice through the engine's WASM mixer, `variant/thread_support
# =false` means that mixer's ring buffer is refilled from the main loop once per
# rendered frame, so a stalled main thread IS a missed refill. `output_latency.web
# =140` gave a long frame four frames of headroom; it gives none at all to a frame
# that has not finished decoding, because that frame does not render until it has.
#
# NONE OF THIS IS AUDIBLE TO THE SUITE and no test below pretends otherwise. What is
# observable is the state that decides it: how many streams are resident, and whether
# anything warms them before gameplay starts.


func test_prewarm_leaves_no_cue_left_to_load() -> String:
	## Asserts the count against `SOUNDS.size() + 1`, derived rather than typed, so a
	## seventeenth cue is covered the day it is added.
	##
	## The `+ 1` is the ambience bed, and it is the whole reason this is an equality
	## and not a `>= SOUNDS.size()`. The bed lives outside `SOUNDS` on purpose (see
	## test_the_bed_is_not_a_cue), it is the longest-running sound the game makes, and
	## a `prewarm` that looped `SOUNDS` and forgot it would leave the one load that
	## lands mid-wave exactly where it was.
	##
	## Order-independent by construction: it asserts the state AFTER prewarm, which is
	## the same whether the suite arrived here cold or with the cache already warm from
	## test_every_sound_the_game_can_play_actually_loads. A test written as "resident
	## went from 0 to N" would pass or fail on suite order alone.
	var resident: int = Sfx.prewarm()
	var err: String = _T.assert_eq(resident, Sfx.SOUNDS.size() + 1,
		"prewarm reports every cue in the table resident, plus the bed")
	if err == "":
		err = _T.assert_eq(Sfx.streams_resident(), Sfx.SOUNDS.size() + 1,
			"and asking again agrees -- the return value is the cache, not a tally "
				+ "of what prewarm happened to touch")
	if err == "":
		# The denominator. `Sfx.SOUNDS.size() + 1` is a true statement about an empty
		# table too, and an empty table is how this test goes vacuous.
		err = _T.assert_gt(Sfx.SOUNDS.size(), 20,
			"there was a real table to warm (an empty one passes the above trivially)")
	return err


func test_prewarm_covers_the_beds_as_well_as_the_cues() -> String:
	## The bed cache is the one that hurt most and is the easiest to forget, because
	## `Music` has two players and looks warm as soon as either has a stream. RUN is an
	## mp3 and the largest file this project ships; it is loaded during a crossfade, so
	## its decode overlaps the outgoing bed's.
	var resident: int = Music.prewarm()
	var err: String = _T.assert_eq(resident, Music.TRACKS.size(),
		"every bed in TRACKS is resident after prewarm")
	if err == "":
		err = _T.assert_gt(Music.TRACKS.size(), 1,
			"there is more than one bed, so this is not one lucky load")
	return err


func test_the_game_scene_warms_the_audio_caches_before_it_plays() -> String:
	## THE CLAIM THE OTHER TWO CANNOT MAKE: that something actually CALLS prewarm.
	## `Game._ready` deleting those two lines is the regression that puts every load
	## back into a gameplay frame, and it would leave both tests above green.
	##
	## Cold first, via the seam `Sfx.forget_streams` exists for, then build the real
	## scene and read the caches back. The scene is torn down but the caches are left
	## warm, which is the state every other test in this file either wants or ignores.
	Sfx.forget_streams()
	Music.forget_streams()
	var err: String = _T.assert_eq(Sfx.streams_resident(), 0,
		"the cue cache really is cold to start with -- otherwise this test asserts nothing")
	if err != "":
		return err
	err = _T.assert_eq(Music.streams_resident(), 0, "and so is the bed cache")
	if err != "":
		return err
	var game := await _T.instantiate_scene("res://game/game.tscn") as Game
	err = _T.assert_true(game != null, "the game scene loaded")
	if err == "":
		err = _T.assert_eq(Sfx.streams_resident(), Sfx.SOUNDS.size() + 1,
			"_ready warmed every cue and the bed, so the first kill of the run pays "
				+ "no load")
	if err == "":
		err = _T.assert_eq(Music.streams_resident(), Music.TRACKS.size(),
			"and every bed, so the crossfade into a run decodes nothing new")
	_T.free_ui(game)
	return err
