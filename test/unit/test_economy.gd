extends RefCounted

## The design doc's economy, asserted as rules.
##
## "You get one free plant to start with, some aren't free. You have to buy plant
## seeds to get plants." Three claims: exactly one plant is free, exactly once;
## a locked plant cannot be paid for at any price; and a packet is the only way
## to unlock one.

const GAME_SCENE := "res://game/game.tscn"

var _T


func test_exactly_one_plant_is_unlocked_at_the_start() -> String:
	var starters: Array[StringName] = PlantCatalog.starting_unlocks()
	return _T.assert_eq(starters.size(), 1,
		"the doc says ONE free plant to start with, found %s" % [starters])


func test_the_free_starter_is_free_exactly_once() -> String:
	var bank := SeedBank.new()
	var starter: StringName = PlantCatalog.starting_unlocks()[0]
	var err: String = _T.assert_eq(bank.placement_cost(starter), 0, "the first one is free")
	if err != "":
		return err
	var before: int = bank.seeds
	err = _T.assert_true(bank.pay_for_plant(starter), "planting the free one succeeds")
	if err != "":
		return err
	err = _T.assert_eq(bank.seeds, before, "and costs nothing")
	if err != "":
		return err
	return _T.assert_eq(bank.placement_cost(starter), PlantCatalog.cost(starter),
		"the second one costs full price")


func test_a_locked_plant_cannot_be_bought_however_rich_you_are() -> String:
	var bank := SeedBank.new()
	bank.add_seeds(10000)
	var locked: Array[StringName] = bank.locked_plants()
	var err: String = _T.assert_gt(locked.size(), 0, "there is something left to unlock")
	if err != "":
		return err
	return _T.assert_false(bank.pay_for_plant(locked[0]),
		"seeds alone do not unlock %s — only a packet does" % locked[0])


func test_a_packet_unlocks_a_locked_plant_and_charges_for_it() -> String:
	var bank := SeedBank.new()
	bank.set_seed(1234)
	bank.add_seeds(SeedBank.PACKET_COST)
	var before: int = bank.seeds
	var locked_before: int = bank.locked_plants().size()
	var got: StringName = bank.buy_packet()
	var err: String = _T.assert_true(got != &"", "the packet held something")
	if err != "":
		return err
	err = _T.assert_eq(bank.seeds, before - SeedBank.PACKET_COST, "the packet was paid for")
	if err != "":
		return err
	err = _T.assert_true(bank.is_unlocked(got), "%s is now plantable" % got)
	if err != "":
		return err
	return _T.assert_eq(bank.locked_plants().size(), locked_before - 1, "one fewer plant is locked")


func test_a_packet_you_cannot_afford_changes_nothing() -> String:
	var bank := SeedBank.new()
	var poor := SeedBank.PACKET_COST - 1
	bank.add_seeds(poor - bank.seeds)
	var locked_before: int = bank.locked_plants().size()
	var err: String = _T.assert_eq(bank.buy_packet(), &"", "the packet is refused")
	if err != "":
		return err
	err = _T.assert_eq(bank.seeds, poor, "and no seeds were taken")
	if err != "":
		return err
	return _T.assert_eq(bank.locked_plants().size(), locked_before, "and nothing was unlocked")


func test_a_packet_never_hands_back_something_you_already_own() -> String:
	## With a short catalogue this is easy to get wrong by rolling over all plants
	## and re-granting one. Drain the packets and check every roll was new.
	var bank := SeedBank.new()
	bank.set_seed(7)
	bank.add_seeds(SeedBank.PACKET_COST * 20)
	var seen: Array[StringName] = []
	while not bank.locked_plants().is_empty():
		# Rare, not common. This loop used to drain on the common tier and was
		# green only because of the bug it was standing next to: common fell back
		# to the whole locked pool when its tier filter emptied, so it could hand
		# out the tier-2 Sunflower and the loop terminated. With the fallback gone,
		# common correctly refuses once tier 1 is spent and this would spin on ""
		# forever. Rare is the tier that can actually reach the whole catalogue.
		var got: StringName = bank.buy_packet(&"rare")
		var err: String = _T.assert_false(seen.has(got), "packet rolled %s twice" % got)
		if err != "":
			return err
		seen.append(got)
	var err2: String = _T.assert_gt(seen.size(), 0, "at least one packet was opened")
	if err2 != "":
		return err2
	return _T.assert_eq(bank.buy_packet(), &"", "packets are refused once the garden is complete")


func test_uprooting_refunds_less_than_it_cost() -> String:
	## A refund at or above cost turns replanting into an infinite seed printer.
	for id: StringName in PlantCatalog.ids():
		var plant := Plant.new()
		plant.kind = id
		var refund: int = plant.uproot_refund()
		plant.free()
		var err: String = _T.assert_true(refund < PlantCatalog.cost(id),
			"%s refunds %d of %d — a full refund makes seeds infinite" % [id, refund, PlantCatalog.cost(id)])
		if err != "":
			return err
	return ""


func test_a_common_packet_never_rolls_above_its_tier_cap() -> String:
	## The two packet tiers differ by exactly one thing — max_tier — so a common
	## packet handing back a tier-2 plant makes the cheap one strictly better and
	## both HUD tooltips false. Driven over the real unlock sequence rather than a
	## hand-built pool: the bug was in what the pool degrades to AFTER the first
	## unlock, so a single roll from a fresh bank cannot see it.
	var cap: int = int(SeedBank.PACKET_TIERS[&"common"]["max_tier"])
	for seed_value: int in [1, 7, 99, 1234, 20250815]:
		var bank := SeedBank.new()
		bank.set_seed(seed_value)
		bank.add_seeds(SeedBank.PACKET_COST * 20)
		var rolls: int = 0
		var guard: int = 0
		while guard < 20:
			guard += 1
			var got: StringName = bank.buy_packet(&"common")
			if got == &"":
				break
			rolls += 1
			var err: String = _T.assert_true(PlantCatalog.tier(got) <= cap,
				"a common packet (max_tier %d) rolled %s, tier %d" % [cap, got, PlantCatalog.tier(got)])
			if err != "":
				return err
		var err2: String = _T.assert_gt(rolls, 0, "seed %d opened no packet at all" % seed_value)
		if err2 != "":
			return err2
	return ""


func test_a_common_packet_with_nothing_left_in_range_charges_nothing() -> String:
	## The exhausted-pool case on its own. Unlock every tier-1 plant through the
	## real packet path, then buy one more: it must be refused, say why, and leave
	## the purse exactly as it was. Being charged for nothing is the worse half of
	## this bug — worse than the over-tier roll, because the seeds just vanish.
	var bank := SeedBank.new()
	bank.set_seed(11)
	bank.add_seeds(500)
	var cap: int = int(SeedBank.PACKET_TIERS[&"common"]["max_tier"])
	var guard: int = 0
	while not bank.packet_pool(&"common").is_empty() and guard < 20:
		guard += 1
		bank.buy_packet(&"common")
	var err: String = _T.assert_true(bank.packet_pool(&"common").is_empty(),
		"every tier-%d plant is unlocked after %d packet(s)" % [cap, guard])
	if err != "":
		return err
	err = _T.assert_gt(bank.locked_plants().size(), 0, "and something above the cap is still locked")
	if err != "":
		return err
	var seeds_before: int = bank.seeds
	var earned_before: int = bank.seeds_earned_total
	var locked_before: int = bank.locked_plants().size()
	var reasons: Array[String] = []
	bank.purchase_failed.connect(func(reason: String) -> void: reasons.append(reason))
	var got: StringName = bank.buy_packet(&"common")
	err = _T.assert_eq(got, &"", "the packet is refused rather than reaching past tier %d" % cap)
	if err != "":
		return err
	err = _T.assert_eq(bank.seeds, seeds_before, "and the player was not charged for nothing")
	if err != "":
		return err
	err = _T.assert_eq(bank.seeds_earned_total, earned_before, "and the run's score did not move either")
	if err != "":
		return err
	err = _T.assert_eq(bank.locked_plants().size(), locked_before, "and nothing was unlocked")
	if err != "":
		return err
	return _T.assert_eq(reasons.size(), 1, "purchase_failed said why exactly once, got %s" % [reasons])


func test_the_rare_packet_is_the_route_past_the_common_cap() -> String:
	## The other half of the refusal: capping the common packet must not strand a
	## player short of the higher tier, so the pricier packet has to still deliver
	## it — and charge for it.
	var bank := SeedBank.new()
	bank.set_seed(5)
	bank.add_seeds(1000)
	var cap: int = int(SeedBank.PACKET_TIERS[&"common"]["max_tier"])
	var guard: int = 0
	while not bank.packet_pool(&"common").is_empty() and guard < 20:
		guard += 1
		bank.buy_packet(&"common")
	var err: String = _T.assert_eq(bank.buy_packet(&"common"), &"", "the common packet is spent")
	if err != "":
		return err
	err = _T.assert_gt(bank.packet_pool(&"rare").size(), 0, "but the rare packet still has stock")
	if err != "":
		return err
	var before: int = bank.seeds
	var cost: int = int(SeedBank.PACKET_TIERS[&"rare"]["cost"])
	var got: StringName = bank.buy_packet(&"rare")
	err = _T.assert_gt(PlantCatalog.tier(got), cap,
		"the rare packet reached past tier %d, got %s" % [cap, got])
	if err != "":
		return err
	err = _T.assert_true(bank.is_unlocked(got), "%s is now plantable" % got)
	if err != "":
		return err
	return _T.assert_eq(bank.seeds, before - cost, "and the rare packet was paid for")


func test_draining_the_catalogue_never_repeats_a_plant() -> String:
	## Same claim as the single-tier drain above, but across both tiers now that a
	## capped packet can refuse: escalate to the pricier packet when the cheap one
	## is spent. Every plant stays reachable, none arrives twice, and once the
	## garden is complete both tiers refuse.
	var bank := SeedBank.new()
	bank.set_seed(21)
	bank.add_seeds(int(SeedBank.PACKET_TIERS[&"rare"]["cost"]) * 40)
	var seen: Array[StringName] = []
	var guard: int = 0
	while not bank.locked_plants().is_empty() and guard < 40:
		guard += 1
		var got: StringName = bank.buy_packet(&"common")
		if got == &"":
			got = bank.buy_packet(&"rare")
		var err: String = _T.assert_true(got != &"",
			"no packet could deliver with %d plant(s) still locked" % bank.locked_plants().size())
		if err != "":
			return err
		err = _T.assert_false(seen.has(got), "a packet rolled %s twice" % got)
		if err != "":
			return err
		seen.append(got)
	var err2: String = _T.assert_true(bank.locked_plants().is_empty(),
		"every plant was reachable through packets, %s left" % [bank.locked_plants()])
	if err2 != "":
		return err2
	err2 = _T.assert_eq(bank.buy_packet(&"rare"), &"", "packets are refused once the garden is complete")
	if err2 != "":
		return err2
	return _T.assert_eq(bank.buy_packet(&"common"), &"", "including the cheap one")


## Two modes, two records. One number shared between an eight-wave campaign and an
## unbounded endless run meant a single endless result permanently retired the
## campaign record, while the title screen labelled it "Best endless run" whichever
## mode had actually set it.
func test_a_campaign_run_cannot_take_the_endless_record() -> String:
	var campaign_before: int = RunConfig.campaign_high_score
	var endless_before: int = RunConfig.endless_high_score
	RunConfig.campaign_high_score = 0
	RunConfig.endless_high_score = 5000

	# A campaign run scoring 300 against campaign's 0 IS a record, even though the
	# same 300 is nowhere near the endless 5000. That is the whole point: the two
	# numbers are not comparable, so one shared slot could only ever be wrong.
	RunConfig.endless = false
	var err: String = _T.assert_true(RunConfig.record_score(300),
		"300 beats the campaign record of 0")
	if err == "":
		err = _T.assert_eq(RunConfig.campaign_high_score, 300,
			"a campaign run files against campaign")
	if err == "":
		err = _T.assert_eq(RunConfig.endless_high_score, 5000,
			"and leaves the endless record untouched")
	if err == "":
		RunConfig.endless = true
		err = _T.assert_false(RunConfig.record_score(300),
			"the same 300 is not an endless record, because endless holds 5000")
	if err == "":
		err = _T.assert_eq(RunConfig.campaign_high_score, 300, "and campaign is unchanged by that")

	RunConfig.campaign_high_score = campaign_before
	RunConfig.endless_high_score = endless_before
	RunConfig.endless = false
	return err


func test_each_mode_reports_its_own_best() -> String:
	var c: int = RunConfig.campaign_high_score
	var e: int = RunConfig.endless_high_score
	RunConfig.campaign_high_score = 111
	RunConfig.endless_high_score = 999
	var err: String = _T.assert_eq(RunConfig.best_for(false), 111, "campaign best")
	if err == "":
		err = _T.assert_eq(RunConfig.best_for(true), 999, "endless best")
	if err == "":
		# The title line names both rather than claiming one belongs to the other.
		var line: String = TitleScreen.high_score_text()
		err = _T.assert_true(line.contains("111") and line.contains("999"),
			"the title screen shows both records, got %s" % line)
	if err == "":
		RunConfig.campaign_high_score = 0
		err = _T.assert_false(TitleScreen.high_score_text().contains("0"),
			"an unplayed mode is omitted, not shown as a zero: %s" % TitleScreen.high_score_text())
	RunConfig.campaign_high_score = c
	RunConfig.endless_high_score = e
	return err


## The post-mortem could only report damage, because these were the two numbers
## nobody had ever written down.
func test_a_run_counts_what_it_defeated_and_how_long_it_took() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_eq(game.pests_defeated, 0, "a fresh run has defeated nothing")
	# Not asserted as 0: instantiate_scene pumps real frames, so the clock has
	# legitimately been running since the scene loaded. The delta is the claim.
	var started_at: float = game.run_seconds
	if err == "":
		game._process(2.5)
		err = _T.assert_float_eq(game.run_seconds - started_at, 2.5, 0.01,
			"the clock advances by exactly the delta it is given")
	if err == "":
		game.spawn_pest(Pest.APHID)
		var pests: Array = game.get_tree().get_nodes_in_group("pests")
		err = _T.assert_gt(pests.size(), 0, "a pest is on the board to kill")
		if err == "":
			# Through the real death path, not by touching the counter.
			(pests[0] as Pest).take_damage(9999.0)
			err = _T.assert_eq(game.pests_defeated, 1, "a kill is counted where kills funnel")
	if err == "":
		# The clock must stop when the run does, or it measures how long the player
		# spent reading their own post-mortem.
		game.game_over = true
		var frozen: float = game.run_seconds
		game._process(5.0)
		err = _T.assert_float_eq(game.run_seconds, frozen, 0.001,
			"the clock stops the instant the run ends")
	if err == "":
		var stats: Dictionary = game.summary_stats(false)
		err = _T.assert_eq(int(stats["pests_defeated"]), 1, "and both reach the post-mortem")
		if err == "":
			err = _T.assert_gt(float(stats["run_seconds"]), 0.0, "with a duration")
	_T.free_ui(game)
	return err
