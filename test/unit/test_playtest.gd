extends RefCounted

## `RunSim`, the whole-run driver — asserted on the properties bead
## plant-tower-defense-t5yy.1 asked for, and on nothing about whether the game is
## balanced. That is beads t5yy.2, .3 and .4, and mixing them here would make a suite that
## goes green on neither.
##
## THE BUDGET IS THE DESIGN CONSTRAINT. `/verify` re-runs this directory on every change,
## so nothing here plays a campaign: `SHORT_RUN` waves is enough to cross a wave boundary
## twice, which is where every property this file cares about actually lives. The long
## sweeps run out of `tools/playtest.gd`, whose whole reason for existing is that it is
## not on this budget.
##
## EVERY RUN ASSERTS `foreign_pests` AND `foreign_plants` ARE ZERO, inheriting
## `_over_promise_run`'s rule rather than re-deriving it: the runner keeps stepping while
## a test awaits, so a sibling test's pests can be standing in the tree-global group that
## `Kernel._physics_process` and `Plant._live_pests` read. See
## `.claude/skills/godot-test-isolation`.

var _T

## Two waves and a bit. Enough that seeds, lives, plant identity and plant health have all
## had to survive a boundary, and small enough that the whole file stays inside a
## `/verify`.
const SHORT_RUN: int = 3

## Deliberately tiny, for the ceiling test only. Wave 1 cannot possibly clear in four
## frames, so this is the one number in the file whose whole job is to be blown.
const IMPOSSIBLE_FRAMES: int = 4


func _host() -> Node2D:
	var host := Node2D.new()
	host.name = "RunSimHost"
	return host


## A short standard run on one seed, with the driver already disposed. `records` and the
## summary are read off the returned dictionary rather than off the sim, because the sim
## is gone by then and a test that held one would be reading freed nodes.
func _play(configure: Callable) -> Dictionary:
	var host: Node2D = _host()
	await _T.instantiate_scene(host)
	var sim := RunSim.new()
	sim.wave_ceiling = SHORT_RUN
	sim.roll_seed = 4242
	configure.call(sim)
	var records: Array[Dictionary] = sim.play(host)
	var out: Dictionary = {
		"records": records.duplicate(true),
		"summary": sim.summary_line(),
		"failure": sim.failure,
		"ended": sim.ended,
		"waves_played": sim.waves_played,
		"foreign": sim.foreign_pests + sim.foreign_plants,
		"lives": sim.lives,
		"starting_lives": sim.starting_lives,
		"unlocked": sim.bank.unlocked.duplicate() if sim.bank != null else [],
	}
	# The host goes FIRST and the sim's own four nodes second: every plant still standing
	# holds the `Board` this is about to free, and a plant freed after its board would be
	# reading a dangling pointer on the way out.
	_T.free_ui(host)
	sim.dispose()
	return out


func _clean(run: Dictionary, context: String) -> String:
	var err: String = _T.assert_eq(int(run["foreign"]), 0,
		"%s: a sibling test's pests or plants were standing in the tree-global groups, so "
		% context + "every kill, every escape and every coverage read in this run may be theirs")
	if err != "":
		return err
	return _T.assert_eq(String(run["failure"]), "",
		"%s: the driver stopped the run itself -- %s" % [context, run["summary"]])


func test_a_short_run_plays_the_waves_it_was_asked_for() -> String:
	var run: Dictionary = await _play(func(_sim: RunSim) -> void: pass)
	var err: String = _clean(run, "short standard run")
	if err != "":
		return err
	# THE DENOMINATOR, asserted rather than only printed. A driver whose loop never
	# entered returns an empty record list and a clean exit, which run_tests.py scores
	# exactly like a run that played every wave. See CLAUDE.md on vacuity.
	print("  " + String(run["summary"]))
	err = _T.assert_eq(int(run["waves_played"]), SHORT_RUN,
		"the run played every wave it was asked for")
	if err != "":
		return err
	var records: Array = run["records"]
	err = _T.assert_eq(records.size(), SHORT_RUN, "one record per wave played")
	if err != "":
		return err
	for i: int in range(records.size()):
		err = _T.assert_eq(int((records[i] as Dictionary)[&"wave"]), i + 1,
			"records run in wave order from 1")
		if err != "":
			return err
	return ""


func test_every_record_carries_exactly_the_declared_keys() -> String:
	var run: Dictionary = await _play(func(_sim: RunSim) -> void: pass)
	var err: String = _clean(run, "key-set run")
	if err != "":
		return err
	var records: Array = run["records"]
	err = _T.assert_gt(records.size(), 0, "there is a record to check the keys of")
	if err != "":
		return err
	# BOTH DIRECTIONS. A key the builder fills but RECORD_KEYS does not name is invisible
	# to every downstream reader; a key RECORD_KEYS names but the builder never fills
	# crashes one. Beads t5yy.2/.3/.4 all iterate that constant, so this is the check that
	# keeps it worth iterating.
	for record: Dictionary in records:
		for key: StringName in RunSim.RECORD_KEYS:
			err = _T.assert_true(record.has(key),
				"RECORD_KEYS names `%s` and the record does not carry it" % key)
			if err != "":
				return err
		err = _T.assert_eq(record.size(), RunSim.RECORD_KEYS.size(),
			"the record carries a key RECORD_KEYS does not name: %s vs %s"
				% [record.keys(), RunSim.RECORD_KEYS])
		if err != "":
			return err
	return ""


func test_the_same_seed_plays_the_same_run_twice() -> String:
	var first: Dictionary = await _play(func(_sim: RunSim) -> void: pass)
	var err: String = _clean(first, "determinism run A")
	if err != "":
		return err
	var second: Dictionary = await _play(func(_sim: RunSim) -> void: pass)
	err = _clean(second, "determinism run B")
	if err != "":
		return err
	# Compared key by key rather than with one `==` on the arrays, so a failure names the
	# wave and the field that drifted instead of printing two record dumps side by side.
	# The three seeded streams -- WaveDirector's mutation rolls, SeedBank's packet rolls
	# and RunSim's own cross-breeding clock -- are the only randomness in a run, and a
	# fourth one added anywhere lands here.
	var a: Array = first["records"]
	var b: Array = second["records"]
	err = _T.assert_eq(a.size(), b.size(), "the same seed plays the same number of waves")
	if err != "":
		return err
	for i: int in range(a.size()):
		for key: StringName in RunSim.RECORD_KEYS:
			err = _T.assert_eq(str((a[i] as Dictionary)[key]), str((b[i] as Dictionary)[key]),
				"wave %d's `%s` differed between two runs on one seed" % [i + 1, key])
			if err != "":
				return err
	return ""


func test_seeds_lives_and_plants_carry_across_the_wave_boundary() -> String:
	var run: Dictionary = await _play(func(_sim: RunSim) -> void: pass)
	var err: String = _clean(run, "carry-forward run")
	if err != "":
		return err
	var records: Array = run["records"]
	err = _T.assert_gte(records.size(), 2, "a boundary needs two waves to be crossed")
	if err != "":
		return err
	for i: int in range(1, records.size()):
		var before: Dictionary = records[i - 1]
		var after: Dictionary = records[i]
		# Beds are the strict one: nothing between two waves gives one back, so the next
		# wave has to open on exactly the count the last one closed with. A driver that
		# rebuilt its state per wave would read the difficulty's float here every time.
		err = _T.assert_eq(int(after[&"lives_start"]), int(before[&"lives_end"]),
			"beds carried across the boundary between waves %d and %d" % [i, i + 1])
		if err != "":
			return err
		# And the purse is strict for the same reason, because `seeds_start` is captured
		# before the policy spends rather than after (see RunSim's wave loop): nothing at
		# all happens between one wave's close and the next wave's open.
		err = _T.assert_eq(int(after[&"seeds_start"]), int(before[&"seeds_end"]),
			"wave %d opened on %d seeds and wave %d closed on %d, so the purse is not the "
				% [i + 1, int(after[&"seeds_start"]), i, int(before[&"seeds_end"])]
				+ "one that survived the boundary")
		if err != "":
			return err
	# The conservation law, and the one assertion here that a per-wave garden could not
	# pass: every plant the run ever acquired, minus every plant it ever lost, is what is
	# standing at the end. A driver that rebuilt the garden each wave fails this on the
	# first boundary.
	var placed: int = 0
	var sported: int = 0
	var lost: int = 0
	for record: Dictionary in records:
		placed += int(record[&"plants_placed"])
		sported += int(record[&"plants_sported"])
		lost += int(record[&"plants_lost"])
	return _T.assert_eq(placed + sported - lost,
		int((records[records.size() - 1] as Dictionary)[&"plants_alive"]),
		"%d planted + %d sported - %d lost is not the garden left standing" % [placed, sported, lost])


func test_a_run_that_never_starts_a_wave_says_so_instead_of_returning_clean() -> String:
	# The vacuity guard, from the other side: a driver handed a host that is not in a tree
	# cannot read the groups every plant and pest depends on, and the honest answer is a
	# refusal rather than a clean empty record list.
	var loose := Node2D.new()
	var sim := RunSim.new()
	sim.wave_ceiling = SHORT_RUN
	var records: Array[Dictionary] = sim.play(loose)
	var err: String = _T.assert_eq(records.size(), 0, "nothing was played")
	if err == "":
		err = _T.assert_eq(String(sim.ended), "refused", "and the run says it was refused")
	if err == "":
		err = _T.assert_true(sim.failure.contains("tree"),
			"the refusal names the reason, got: %s" % sim.failure)
	sim.dispose()
	loose.free()
	return err


func test_a_wave_that_cannot_clear_fails_naming_the_wave() -> String:
	# plant-tower-defense-x44s: a whole-run loop is exactly the shape that hangs a suite
	# instead of failing it. Four frames cannot clear wave 1 under any policy, so this
	# asserts the ceiling is a FAILURE that names the wave and not a quietly short record.
	var host: Node2D = _host()
	await _T.instantiate_scene(host)
	var sim := RunSim.new()
	sim.wave_ceiling = SHORT_RUN
	sim.frame_ceiling_per_wave = IMPOSSIBLE_FRAMES
	sim.roll_seed = 4242
	sim.play(host)
	var err: String = _T.assert_eq(String(sim.ended), "stalled",
		"the blown ceiling ended the run, got: %s" % sim.summary_line())
	if err == "":
		err = _T.assert_true(sim.failure.contains("wave 1"),
			"the failure names the wave it blew on, got: %s" % sim.failure)
	if err == "":
		err = _T.assert_true(sim.failure.contains(str(IMPOSSIBLE_FRAMES)),
			"and names the ceiling it blew, got: %s" % sim.failure)
	sim.dispose()
	_T.free_ui(host)
	return err


func test_an_illegal_road_is_refused_rather_than_played_on_the_shipped_board() -> String:
	# The rule `_over_promise_run.road_refusal` set, kept: a corpus run that silently fell
	# back to the shipped snake would measure the default board and report it as the
	# corpus, which is a plausible number on the one axis where plausible is
	# indistinguishable from right. A single corner is not a road.
	var host: Node2D = _host()
	await _T.instantiate_scene(host)
	var sim := RunSim.new()
	sim.wave_ceiling = SHORT_RUN
	sim.road_corners = [Vector2i(0, 4)] as Array[Vector2i]
	var records: Array[Dictionary] = sim.play(host)
	var err: String = _T.assert_eq(records.size(), 0, "nothing was played on a refused road")
	if err == "":
		err = _T.assert_eq(String(sim.ended), "refused", "the run says it was refused")
	if err == "":
		err = _T.assert_true(sim.failure.begins_with("road refused:"),
			"the refusal names the road, got: %s" % sim.failure)
	sim.dispose()
	_T.free_ui(host)
	return err


func test_the_difficulty_profile_is_read_rather_than_restated() -> String:
	# Every difficulty, off `Game.DIFFICULTY_ORDER` rather than off the three names spelled
	# out here: a fourth profile is played by this test the day it is added. The claim is
	# only that the driver STARTS where the profile says -- whether harsh is beatable is
	# bead t5yy.3.
	for profile_name: StringName in Game.DIFFICULTY_ORDER:
		var profile: Dictionary = Game.difficulty_profile(profile_name)
		var run: Dictionary = await _play(func(sim: RunSim) -> void:
			sim.difficulty = profile_name
			sim.wave_ceiling = 1)
		var err: String = _clean(run, "difficulty %s" % profile_name)
		if err != "":
			return err
		var records: Array = run["records"]
		err = _T.assert_eq(records.size(), 1, "%s played its one wave" % profile_name)
		if err != "":
			return err
		err = _T.assert_eq(int(run["starting_lives"]), int(profile["lives"]),
			"%s starts on the beds its profile names" % profile_name)
		if err != "":
			return err
		err = _T.assert_eq(int((records[0] as Dictionary)[&"lives_start"]), int(profile["lives"]),
			"%s's first record starts on the profile's beds" % profile_name)
		if err != "":
			return err
		# `seeds_start` is captured before the policy spends (see RunSim's wave loop), so
		# this is an equality rather than a bound -- and it is the assertion a driver that
		# had hardcoded SeedBank.STARTING_SEEDS fails on gentle (40) and on harsh (15).
		err = _T.assert_eq(int((records[0] as Dictionary)[&"seeds_start"]),
			int(profile["starting_seeds"]),
			"%s did not open on its profile's starting seeds" % profile_name)
		if err != "":
			return err
	return ""


func test_the_three_income_sources_are_all_in_the_loop() -> String:
	# Kills, a Sunflower's growth and a swept husk are the three ways seeds arrive
	# (Game._on_pest_died, _on_plant_grew_seeds, _on_husk_collected). A driver missing one
	# reports a poorer run than the game plays, and the miss is invisible in a total. So
	# each has its own record key, and this asserts the two the short run must reach.
	var run: Dictionary = await _play(func(_sim: RunSim) -> void: pass)
	var err: String = _clean(run, "income run")
	if err != "":
		return err
	var kills: int = 0
	var husks: int = 0
	var growth: int = 0
	var earned: int = 0
	for record: Dictionary in run["records"] as Array:
		kills += int(record[&"seeds_from_kills"])
		husks += int(record[&"seeds_from_husks"])
		growth += int(record[&"seeds_from_growth"])
		earned += int(record[&"seeds_earned"])
	err = _T.assert_gt(kills, 0, "a short run kills something and is paid for it")
	if err != "":
		return err
	err = _T.assert_gt(husks, 0, "and sweeps the husks those kills dropped")
	if err != "":
		return err
	# The three columns must ACCOUNT for the total, or a fourth income path has appeared
	# and the split has stopped being a split. Growth is included even though a short
	# greedy run may never buy a Sunflower: zero is a real term in the sum.
	return _T.assert_eq(kills + husks + growth, earned,
		"the three income columns do not add up to seeds_earned -- a fourth source moved "
		+ "seeds without being counted")


func test_a_policy_is_a_parameter_and_a_silent_one_plants_nothing() -> String:
	# The seam bead t5yy.3 varies and bead t5yy.2 runs for hundreds of waves. Asserted by
	# swapping in a policy that buys nothing at all: if the driver were planting from a
	# baked-in list, this run would still have a garden.
	var run: Dictionary = await _play(func(sim: RunSim) -> void:
		sim.wave_ceiling = 1
		sim.policy = func(_s: RunSim) -> Array: return [])
	var err: String = _clean(run, "empty-policy run")
	if err != "":
		return err
	var records: Array = run["records"]
	err = _T.assert_eq(records.size(), 1, "the empty policy still played its wave")
	if err != "":
		return err
	var first: Dictionary = records[0]
	err = _T.assert_eq(int(first[&"plants_placed"]), 0, "a silent policy plants nothing")
	if err != "":
		return err
	err = _T.assert_eq(int(first[&"packets_bought"]), 0, "and buys nothing")
	if err != "":
		return err
	# The garden is not necessarily EMPTY -- cross-breeding plants for free -- so the
	# claim is about what the purse bought, and separately that an undefended lane costs
	# beds. That second half is what proves the wave really ran.
	return _T.assert_gt(int(first[&"escaped"]), 0,
		"an undefended garden let nothing through, so the wave cannot have run")


func test_the_default_policy_covers_road_it_could_not_reach_before() -> String:
	# The greedy cover, asserted as the one property it promises: after a wave of buying,
	# the garden reaches road it did not reach at the start. Not "covers everything" --
	# that is a balance claim and this file makes none.
	var run: Dictionary = await _play(func(sim: RunSim) -> void: sim.wave_ceiling = 2)
	var err: String = _clean(run, "greedy cover run")
	if err != "":
		return err
	var records: Array = run["records"]
	err = _T.assert_gte(records.size(), 1, "the greedy run played")
	if err != "":
		return err
	var placed: int = 0
	for record: Dictionary in records:
		placed += int(record[&"plants_placed"])
	err = _T.assert_gt(placed, 0, "the default policy planted something")
	if err != "":
		return err
	return _T.assert_gt(int((records[0] as Dictionary)[&"killed"]), 0,
		"and what it planted killed something")



## The leak that made a multi-run invocation measure somebody else's garden.
##
## `_play()` above frees the HOST before disposing, which frees every plant and pest with
## it -- so no test in this file could ever have seen this. `tools/playtest.gd` does the
## other thing, and the thing a sweep has to do: one host, many runs, `dispose()` between.
## `dispose()` cleared the `plants` dictionary without freeing the nodes in it, so they
## stayed parented to the shared host and inside the tree-global `plants` group, and the
## next run's census found them. Measured on a three-difficulty invocation before the
## fix: "4 foreign pest(s) and 12 foreign plant(s) were already in the tree" on the third
## run -- runs one and two's gardens, still standing, while their records were written
## anyway.
func test_a_disposed_run_leaves_nothing_standing_for_the_next_one() -> String:
	var host: Node2D = _host()
	await _T.instantiate_scene(host)

	var first := RunSim.new()
	first.wave_ceiling = SHORT_RUN
	first.roll_seed = 4242
	first.play(host)
	var planted: int = first.plants.size()
	first.dispose()

	# Deliberately disposed while the host is still alive, which is the ONE ordering a
	# sweep uses and the one no other test here exercises.
	var second := RunSim.new()
	second.wave_ceiling = 1
	second.roll_seed = 4242
	second.play(host)
	var strays: int = second.foreign_pests + second.foreign_plants
	var second_pests: int = second.foreign_pests
	var second_plants: int = second.foreign_plants
	second.dispose()
	_T.free_ui(host)

	var err: String = _T.assert_gt(planted, 0,
		"the first run really did build a garden, so there was something to leak")
	if err == "":
		err = _T.assert_eq(strays, 0,
			("and a disposed run leaves nothing standing: the second run found %d foreign "
				+ "pest(s) and %d foreign plant(s) on the shared host. Every number a run "
				+ "records over somebody else's garden is describing that garden.")
				% [second_pests, second_plants])
	return err


# =============================================================================
# THE TWO ENDS OF THE SKILL RANGE (plant-tower-defense-i8oh)
#
# The bead's finding is the GAP between two policies: one that stops planting the moment
# the road is covered, and one that keeps going. Its second table -- the thickening end --
# was measured with a driver that was never merged, so nothing in the repo could reproduce
# it and it was recorded as an anecdote. `RunSim.thicken_cover` is that end, and these are
# the checks that keep BOTH ends playable rather than only the one the default uses.
# =============================================================================


## Every policy this build carries is selectable BY NAME, and a name it does not carry is
## refused rather than quietly played as greedy.
##
## The refusal is the half worth writing down. `Game.difficulty_profile` falls back to
## standard for an unknown name and that is right, because a difficulty name arrives from a
## SAVE. A policy name arrives from a command line, where a silent fallback writes a
## committed baseline row LABELLED with the policy that was typed and holding the numbers
## of the one that ran -- plausible on the one axis where plausible cannot be told from
## right.
func test_every_policy_is_selectable_by_name_and_an_unknown_one_is_refused() -> String:
	var checked: int = 0
	for name: StringName in RunSim.POLICY_NAMES:
		var chosen: Callable = RunSim.policy_named(name)
		var err: String = _T.assert_true(chosen.is_valid(),
			("POLICY_NAMES names `%s` and policy_named() hands back nothing for it -- a "
				+ "policy in the list and not in the match is one no sweep can select")
				% name)
		if err != "":
			return err
		var sim := RunSim.new()
		err = _T.assert_eq(sim.use_policy(name), "", "use_policy(%s) took" % name)
		if err == "":
			err = _T.assert_eq(String(sim.policy_name), String(name),
				("and left the LABEL agreeing with the Callable -- these two are written "
					+ "in one call precisely so a record cannot say `%s` about a run some "
					+ "other policy played") % name)
		if err != "":
			return err
		checked += 1
	# The denominator, and it is not `> 0`: this bead is about the interval between TWO
	# policies, so a list that has lost one of them must not pass here in silence.
	var err: String = _T.assert_gte(checked, 2,
		("%d policy(s) checked -- the finding this file pins is the GAP between two of "
			+ "them, and one policy has no gap") % checked)
	if err != "":
		return err
	err = _T.assert_false(RunSim.policy_named(&"a_policy_from_a_later_build").is_valid(),
		"an unknown policy name resolves to nothing rather than to the default")
	if err != "":
		return err
	var refused := RunSim.new()
	var reason: String = refused.use_policy(&"a_policy_from_a_later_build")
	err = _T.assert_true(reason.begins_with("no such policy:"),
		"and use_policy says so rather than returning \"\", got: %s" % reason)
	if err == "":
		# The message names what this build DOES carry, so a typo is one read away from
		# fixed instead of one grep away.
		err = _T.assert_true(reason.contains(String(RunSim.POLICY_THICKEN)),
			"and the refusal names the policies this build has, got: %s" % reason)
	if err == "":
		err = _T.assert_eq(String(refused.policy_name), String(RunSim.POLICY_GREEDY),
			"and a refused name leaves the label where it was rather than half-applying")
	return err


## The thickening policy plants past the point the greedy one stops, on the same seed.
##
## THE ONE PROPERTY, and deliberately not more. "thicken reaches wave 22" is a balance
## reading and belongs in `docs/playtest-runs.jsonl` where a person reads it; what has to
## stay true for that record to mean anything is that the two policies are two policies.
## `best_placement(sim, only_new)` is the single boolean between them, and a refactor that
## collapsed it would leave every sweep still running, still exiting 0, and quietly
## measuring one policy twice.
func test_the_thickening_policy_plants_past_the_point_greedy_stops() -> String:
	var planted: Dictionary = {}
	for name: StringName in [RunSim.POLICY_GREEDY, RunSim.POLICY_THICKEN]:
		var run: Dictionary = await _play(func(sim: RunSim) -> void:
			sim.use_policy(name))
		var err: String = _clean(run, "policy %s" % name)
		if err != "":
			return err
		var total: int = 0
		for record: Dictionary in run["records"] as Array:
			total += int(record[&"plants_placed"])
		planted[name] = total
	var greedy: int = int(planted[RunSim.POLICY_GREEDY])
	var thick: int = int(planted[RunSim.POLICY_THICKEN])
	var err: String = _T.assert_gt(greedy, 0,
		"the greedy run planted something, so there is a floor to be above")
	if err == "":
		err = _T.assert_gt(thick, greedy,
			("thicken planted %d and greedy planted %d over the same %d waves on the same "
				+ "seed. Equal means the stopping rule is no longer the difference between "
				+ "them, and every number in docs/playtest-runs.jsonl that is labelled by "
				+ "policy is then labelling one policy twice.")
				% [thick, greedy, SHORT_RUN])
	return err
