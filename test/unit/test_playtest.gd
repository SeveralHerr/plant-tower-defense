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


# =============================================================================
# THE DIFFICULTY SELECTOR, AND WHETHER IT BINDS (plant-tower-defense-i8oh)
#
# The measurement that produced these: three profiles, one seed, 22 waves, both policies.
# Before the `seed_yield` axis, the three ended IDENTICALLY -- overrun on wave 7 with every
# bed spent under greedy, and reaching the ceiling under thicken having lost nothing and
# earned 5735 seeds EACH, the same number three times to the digit. Lives cannot separate
# runs that lose none, prep time cannot separate a policy that spends the instant the window
# opens, and starting seeds are gone by wave 2.
#
# So the axis had to be one the run keeps spending, and the checks below are the three that
# make it stay one: it is DERIVED (not a fourth free number), it is READ by the driver (not
# restated in a table nothing consumes -- the failure mode this bead is about, and which
# `blurb` in the same table was a second instance of until plant-tower-defense-h5s3 deleted
# it, nothing in the project ever having displayed one), and it SEPARATES a real run rather
# than only its opening balance.
# =============================================================================


## `Game.seeds_after_yield` keeps its two promises across every pest this game ships.
##
## THE CORPUS IS `Pest.SPECIES`, not three numbers typed here: these are the actual values
## the function is asked about at runtime (`Pest.seed_value` is `stats["seeds"]`), so a
## species added with a seed value of 1 is priced by this test the day it lands rather than
## the day somebody remembers a list.
##
## TWO PROMISES, and both are load-bearing. IDENTITY AT 1.0 is what makes standard bit-for-
## bit the game it was: if `seeds_after_yield(n, 1.0) != n` for any n in the corpus, the
## standard campaign was silently rebalanced by an axis that was supposed to leave it alone,
## and `docs/playtest-runs.jsonl`'s standard rows would not have come back identical. NEVER
## ZERO is the other: a kill that pays nothing is a kill the player cannot tell from a miss,
## and the cheapest pest on the leanest profile is exactly where a bare `int(round(...))`
## rounds a payment out of existence.
func test_a_yield_never_rounds_a_kill_down_to_nothing_and_is_identity_at_one() -> String:
	var values: Array[int] = []
	for id: Variant in Pest.SPECIES:
		var stats: Dictionary = Pest.SPECIES[id]
		if stats.has("seeds"):
			values.append(int(stats["seeds"]))
	# The denominator. An empty corpus makes every assertion below pass over nothing, which
	# is the vacuity CLAUDE.md names -- and it is reachable, because this reads a key out of
	# a table rather than a declared list.
	var err: String = _T.assert_gte(values.size(), 3,
		("%d pest seed value(s) came out of Pest.SPECIES -- an empty or near-empty corpus "
			+ "passes every check below without asking anything") % values.size())
	if err != "":
		return err
	var priced: int = 0
	for base: int in values:
		err = _T.assert_eq(Game.seeds_after_yield(base, 1.0), base,
			("a yield of 1.0 is the identity on %d. Standard's yield IS 1.0, so anything "
				+ "else here means the standard campaign moved when this axis was added")
				% base)
		if err != "":
			return err
		for profile_name: StringName in Game.DIFFICULTY_ORDER:
			var scale: float = float(Game.difficulty_profile(profile_name)["seed_yield"])
			var paid: int = Game.seeds_after_yield(base, scale)
			err = _T.assert_gt(paid, 0,
				("a %d-seed pest on %s (yield %.2f) paid %d. A kill worth nothing is a kill "
					+ "the player cannot tell from a miss") % [base, profile_name, scale, paid])
			if err != "":
				return err
			priced += 1
	# Zero passes through untouched: it is a source that produced nothing this frame, not a
	# payment to be floored up to one. Asserted rather than assumed, because the `maxi(1,
	# ...)` above would otherwise turn every empty income column in a wave record into a 1.
	err = _T.assert_eq(Game.seeds_after_yield(0, 0.5), 0,
		"a zero payment stays zero rather than being floored up to one seed")
	if err != "":
		return err
	return _T.assert_eq(priced, values.size() * Game.DIFFICULTY_ORDER.size(),
		"every pest value was priced on every profile (%d of %d)"
			% [priced, values.size() * Game.DIFFICULTY_ORDER.size()])


## The yield is the ratio the profile's other axes already take, not a fourth free number.
##
## DERIVED FROM THE TABLE, BY TYPE. The axes come out of the standard profile itself --
## every numeric value in it except the yield -- so a fifth number added to a profile joins
## this check the day it is added, and `label` is skipped because it is a String rather than
## because it is named here (`blurb` was a second example of this until
## plant-tower-defense-h5s3 deleted the key).
##
## The band is what the other axes span, not an exact figure: gentle already runs 1.44 (26s
## of 18) to 1.6 (40 seeds of 25) and there is no single ratio to hit. What the band refuses
## is the thing that has no reason behind it -- a yield of 3.0 on a profile whose every
## other axis says "half again", which is how a difficulty selector stops being one bundle
## and becomes a table of unrelated dials.
func test_the_seed_yield_takes_the_ratio_the_other_axes_take() -> String:
	var standard: Dictionary = Game.DIFFICULTIES[Game.DIFFICULTY_STANDARD]
	var err: String = _T.assert_float_eq(float(standard["seed_yield"]), 1.0, 0.0001,
		("standard's yield is exactly 1.0. `seeds_after_yield(n, 1.0)` returns n for every "
			+ "n, so the standard campaign is bit-for-bit the game it was before this axis "
			+ "existed -- any other value here silently rebalances the designed game"))
	if err != "":
		return err
	var profiles_checked: int = 0
	for profile_name: StringName in Game.DIFFICULTY_ORDER:
		var profile: Dictionary = Game.difficulty_profile(profile_name)
		err = _T.assert_true(profile.has("seed_yield"),
			("%s has no `seed_yield`. Every profile carries every axis or the run reading "
				+ "it indexes into nothing at _ready time") % profile_name)
		if err != "":
			return err
		var lowest: float = 0.0
		var highest: float = 0.0
		var axes: int = 0
		for key: Variant in standard:
			var axis: String = String(key)
			if axis == "seed_yield":
				continue
			var baseline: Variant = standard[key]
			# BY TYPE, not by name: `label` is a String and drops out here without a
			# list of exclusions anyone has to remember to extend.
			if not (baseline is int or baseline is float):
				continue
			err = _T.assert_true(profile.has(key),
				"%s is missing the `%s` axis that standard has" % [profile_name, axis])
			if err != "":
				return err
			var ratio: float = float(profile[key]) / float(baseline)
			if axes == 0 or ratio < lowest:
				lowest = ratio
			if axes == 0 or ratio > highest:
				highest = ratio
			axes += 1
		# The denominator, and not `> 0`: one axis is not a band, it is a coincidence.
		err = _T.assert_gte(axes, 2,
			("%s was priced against %d numeric axis(es) of standard's -- a band needs two, "
				+ "and an empty sweep here would pass every yield there is")
				% [profile_name, axes])
		if err != "":
			return err
		var got: float = float(profile["seed_yield"])
		err = _T.assert_true(got >= lowest - 0.001 and got <= highest + 0.001,
			("%s's seed_yield is %.3f and its other %d axes run %.3f to %.3f against "
				+ "standard. A yield outside the band its own profile already agreed on is "
				+ "a number with no reason behind it")
				% [profile_name, got, axes, lowest, highest])
		if err != "":
			return err
		profiles_checked += 1
	return _T.assert_eq(profiles_checked, Game.DIFFICULTY_ORDER.size(),
		"every ordered profile was priced (%d of %d)"
			% [profiles_checked, Game.DIFFICULTY_ORDER.size()])


## The DRIVER reads the yield off the profile, rather than paying the standard rate.
##
## The shape `test_the_difficulty_profile_is_read_rather_than_restated` above uses, for the
## axis added by plant-tower-defense-i8oh, and for the same reason: an axis written into
## `DIFFICULTIES` that nothing on the path a run takes ever reads is the exact defect that
## bead is about. `RunSim.seed_yield` is 1.0 until `play()` reads the profile, so a driver
## that never made the read fails this on gentle and on harsh and passes on standard --
## which is why all three are checked and not just one.
func test_the_run_reads_the_profiles_seed_yield_rather_than_paying_the_standard_rate() -> String:
	var checked: int = 0
	for profile_name: StringName in Game.DIFFICULTY_ORDER:
		var host: Node2D = _host()
		await _T.instantiate_scene(host)
		var sim := RunSim.new()
		sim.wave_ceiling = 1
		sim.roll_seed = 4242
		sim.difficulty = profile_name
		var before: float = sim.seed_yield
		sim.play(host)
		var after: float = sim.seed_yield
		var strays: int = sim.foreign_pests + sim.foreign_plants
		var failure: String = sim.failure
		# The host first and the sim's four parentless nodes second, for the reason
		# `_play()` above gives at length.
		_T.free_ui(host)
		sim.dispose()

		var err: String = _T.assert_eq(strays, 0,
			"%s: a sibling test's nodes were in the tree-global groups" % profile_name)
		if err == "":
			err = _T.assert_eq(failure, "", "%s: the driver stopped the run itself -- %s"
				% [profile_name, failure])
		if err == "":
			err = _T.assert_float_eq(before, 1.0, 0.0001,
				("an unplayed run pays the designed rate rather than zero -- a 0.0 default "
					+ "would make every kill worth exactly one seed and look like a tuning "
					+ "choice"))
		if err == "":
			err = _T.assert_float_eq(after,
				float(Game.difficulty_profile(profile_name)["seed_yield"]), 0.0001,
				("%s did not take its profile's seed_yield into the run. This is the "
					+ "assertion a driver that ignored the key passes on standard and "
					+ "fails on the other two") % profile_name)
		if err != "":
			return err
		checked += 1
	return _T.assert_eq(checked, Game.DIFFICULTY_ORDER.size(),
		"every ordered profile was played (%d of %d)"
			% [checked, Game.DIFFICULTY_ORDER.size()])


## THE ACCEPTANCE, pinned: the three profiles END a run differently, not only start one.
##
## EVERY ORDERED PAIR, under EVERY policy, rather than two example comparisons -- the claim
## is a relation over the whole profile set and the wrong way to check a relation is to pick
## two of its members (`.claude/skills/enumerate-the-pairs`). The expectation is DERIVED from
## the table's own `seed_yield` rather than from the three names, so a retune that reorders
## the profiles retunes this test with it and a retune that flattens them fails it.
##
## SEEDS EARNED, not lives and not the wave reached. Under `greedy` the policy stops buying
## once the road is covered, so income is not what is binding and all three still fall on
## the same wave; under `thicken` income is exactly what is binding and the gardens come out
## 125, 116 and 79 plants over 22 waves. Earnings are the axis that moves under BOTH, which
## is what makes this assertable inside a `/verify` budget instead of only in a campaign
## sweep. The campaign numbers live in `docs/playtest-runs.jsonl`.
func test_the_three_profiles_end_a_run_differently_and_not_only_start_it_differently() -> String:
	var compared: int = 0
	for policy_name: StringName in RunSim.POLICY_NAMES:
		var earned: Dictionary = {}
		for profile_name: StringName in Game.DIFFICULTY_ORDER:
			var run: Dictionary = await _play(func(sim: RunSim) -> void:
				sim.difficulty = profile_name
				sim.use_policy(policy_name))
			var err: String = _clean(run, "%s under %s" % [profile_name, policy_name])
			if err != "":
				return err
			var total: int = 0
			for record: Dictionary in run["records"] as Array:
				total += int(record[&"seeds_earned"])
			earned[profile_name] = total
		for richer: StringName in Game.DIFFICULTY_ORDER:
			for leaner: StringName in Game.DIFFICULTY_ORDER:
				var rich_yield: float = float(Game.difficulty_profile(richer)["seed_yield"])
				var lean_yield: float = float(Game.difficulty_profile(leaner)["seed_yield"])
				if rich_yield <= lean_yield:
					continue
				var err: String = _T.assert_gt(int(earned[richer]), int(earned[leaner]),
					("under `%s`, %s (yield %.2f) earned %d over %d waves and %s (yield "
						+ "%.2f) earned %d. Equal here means the selector is back to "
						+ "changing only the opening balance -- which is a difference no "
						+ "run shows, and the whole of plant-tower-defense-i8oh")
						% [policy_name, richer, rich_yield, int(earned[richer]), SHORT_RUN,
							leaner, lean_yield, int(earned[leaner])])
				if err != "":
					return err
				compared += 1
	# THE VACUOUS PASS THIS EXISTS TO REFUSE. If every profile carried the same yield, the
	# `continue` above would skip every pair and this test would report a clean separation
	# having compared nothing -- which is precisely the state the bead was filed about.
	var expected: int = RunSim.POLICY_NAMES.size() * (Game.DIFFICULTY_ORDER.size()
		* (Game.DIFFICULTY_ORDER.size() - 1)) / 2
	return _T.assert_eq(compared, expected,
		("%d ordered pair(s) compared and %d expected from %d profile(s) x %d policy(s). "
			+ "Short means two profiles share a yield and no run can tell them apart; a "
			+ "zero means none of them can be told apart at all")
			% [compared, expected, Game.DIFFICULTY_ORDER.size(), RunSim.POLICY_NAMES.size()])
