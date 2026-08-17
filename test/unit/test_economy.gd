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
	bank.add_seeds(SeedBank.PACKET_COST * 40)
	var seen: Array[StringName] = []
	# The LAST tier in PACKET_ORDER, read rather than named. This loop used to
	# drain on the common tier and was green only because of the bug it was
	# standing next to: common fell back to the whole locked pool when its tier
	# filter emptied, so it could hand out the tier-2 Sunflower and the loop
	# terminated. With the fallback gone, common correctly refuses once tier 1 is
	# spent and this would spin on "" forever. It was then pinned to `rare`, which
	# was the tier that could reach the whole catalogue — until `epic` arrived
	# above it and rare's cap dropped to 2, at which point the same spin came back.
	# Twice is enough: the tier that reaches everything is now derived.
	var top: StringName = SeedBank.PACKET_ORDER[SeedBank.PACKET_ORDER.size() - 1]
	while not bank.locked_plants().is_empty():
		var got: StringName = bank.buy_packet(top)
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
	## Same claim as the single-tier drain above, but across EVERY tier now that a
	## capped packet can refuse: escalate to the next pricier packet when the cheap
	## one is spent. Every plant stays reachable, none arrives twice, and once the
	## garden is complete every tier refuses.
	##
	## Walks SeedBank.PACKET_ORDER rather than naming common and rare, which is the
	## thing this test is really for: a third tier that no ladder ever climbs to is
	## a plant the player can never be handed, and a hard-coded two-step escalation
	## would have passed while `epic` sat unreachable behind it.
	var bank := SeedBank.new()
	bank.set_seed(21)
	bank.add_seeds(int(SeedBank.PACKET_TIERS[&"epic"]["cost"]) * 40)
	var seen: Array[StringName] = []
	var guard: int = 0
	while not bank.locked_plants().is_empty() and guard < 40:
		guard += 1
		var got: StringName = &""
		for tier: StringName in SeedBank.PACKET_ORDER:
			got = bank.buy_packet(tier)
			if got != &"":
				break
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
	for tier: StringName in SeedBank.PACKET_ORDER:
		err2 = _T.assert_eq(bank.buy_packet(tier), &"",
			"a %s packet is refused once the garden is complete" % tier)
		if err2 != "":
			return err2
	return err2


## Two modes, two records. One number shared between an eight-wave campaign and an
## unbounded endless run meant a single endless result permanently retired the
## campaign record, while the title screen labelled it "Best endless run" whichever
## mode had actually set it.
func test_a_campaign_run_cannot_take_the_endless_record() -> String:
	# record_score() persists, so the path is redirected before the first call and
	# not merely the numbers restored after the last. Staging campaign to 0 and then
	# recording 300 wrote a 300 straight over the player's real campaign record;
	# every assertion here passed while it happened.
	var stashed_path: String = RunConfig.save_path
	RunConfig.save_path = "user://test_economy_modes.save"
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
	RunConfig.save_path = stashed_path
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists("user://test_economy_modes.save" + suffix):
			DirAccess.remove_absolute("user://test_economy_modes.save" + suffix)
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
## Spawn a pest and hand back THAT pest, not whichever the group lists first.
##
## `get_nodes_in_group` is tree-global and `instantiate_scene` pumps settle frames,
## so anything that acts on entering the tree has already acted before the test body
## runs — index 0 is not necessarily the node under test. `assert_gt(size, 0)` does
## not save you: it was true every time `test_kernels_launch` measured a kernel its
## own setup had fired. Diffing the group around the spawn cannot pick up a stranger.
func _spawn_and_take(game: Game, species: StringName) -> Pest:
	var before: Dictionary = {}
	for p: Node in game.get_tree().get_nodes_in_group("pests"):
		before[p.get_instance_id()] = true
	game.spawn_pest(species)
	for p: Node in game.get_tree().get_nodes_in_group("pests"):
		if not before.has(p.get_instance_id()) and p is Pest:
			return p as Pest
	return null


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
		var victim: Pest = _spawn_and_take(game, Pest.APHID)
		err = _T.assert_true(victim != null, "a pest is on the board to kill")
		if err == "":
			# Through the real death path, not by touching the counter.
			victim.take_damage(9999.0)
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


# -- Health-scaled uproot refund (plant-tower-defense-s2o) -------------------
#
# A plant's health only ever goes down and there is no heal path, so for as long
# as the refund read only the catalogue cost, uproot-and-replant was a full heal
# for the difference (4 seeds on a Corn Cobbler) — strictly better than leaving a
# damaged plant standing, which made the health bar a readout with no decision
# attached to it. The refund now slides with what is left of the plant.


## One refund, taken at a given health, through the real damage path rather than
## by assigning `health` — so these break if take_damage ever stops being the
## thing that moves it.
func _refund_at_health(id: StringName, hp: float) -> int:
	var plant := Plant.new()
	plant.kind = id
	plant.take_damage(Plant.MAX_HEALTH - hp)
	var refund: int = plant.uproot_refund()
	plant.free()
	return refund


func test_the_uproot_refund_falls_as_the_plant_is_eaten() -> String:
	## Every plant in the catalogue, not a hand-picked one: the slope is applied to
	## a cost, and each cost rounds differently.
	for id: StringName in PlantCatalog.ids():
		var cost: int = PlantCatalog.cost(id)
		var full: int = _refund_at_health(id, Plant.MAX_HEALTH)
		var half: int = _refund_at_health(id, Plant.MAX_HEALTH * 0.5)
		var wreck: int = _refund_at_health(id, 1.0)
		# The full-health rate is unchanged — this issue makes damage cost you a
		# refund, it does not quietly nerf selling a pristine plant.
		var err: String = _T.assert_eq(full, int(floor(cost * Plant.UPROOT_RATE_FULL)),
			"%s at full health still refunds the old flat rate" % id)
		if err == "":
			err = _T.assert_true(half < full,
				"%s: half-eaten refunds %d, pristine refunds %d — damage must cost something"
					% [id, half, full])
		if err == "":
			err = _T.assert_true(wreck < half,
				"%s: at 1hp refunds %d, at half health %d — the slope keeps going" % [id, wreck, half])
		if err != "":
			return err
	return ""


func test_uprooting_refunds_less_than_it_cost_at_every_health() -> String:
	## The infinite-seed-printer invariant, re-pinned across the whole slope. The
	## full-health end is the one that binds — it is the largest refund a plant can
	## ever pay — and it has to bind for every cost in the catalogue, not just 10.
	for id: StringName in PlantCatalog.ids():
		var cost: int = PlantCatalog.cost(id)
		for hp: float in [Plant.MAX_HEALTH, Plant.MAX_HEALTH * 0.5, 1.0]:
			var refund: int = _refund_at_health(id, hp)
			var err: String = _T.assert_true(refund < cost,
				"%s at %.0fhp refunds %d of %d — a refund at or above cost prints seeds"
					% [id, hp, refund, cost])
			if err != "":
				return err
	return ""


func test_uprooting_a_wreck_still_pays_something_back() -> String:
	## The other failure mode, and the reason the slope has a floor: a refund that
	## decays to nothing makes clearing a chewed cell a punishment for having been
	## attacked. A wreck is worth scrap, and scrap is never zero.
	for id: StringName in PlantCatalog.ids():
		var floor_value: int = maxi(Plant.MIN_UPROOT_REFUND,
			int(floor(PlantCatalog.cost(id) * Plant.UPROOT_RATE_WRECK)))
		var err: String = _T.assert_gt(floor_value, 0, "%s's floor is a real number of seeds" % id)
		if err == "":
			err = _T.assert_gte(_refund_at_health(id, 1.0), floor_value,
				"%s at 1hp refunds at least its %d-seed floor" % [id, floor_value])
		if err == "":
			# Below 1hp a plant is destroyed rather than uprooted, but the arithmetic
			# must not fall through zero on the way there either.
			err = _T.assert_gte(_refund_at_health(id, 0.0), Plant.MIN_UPROOT_REFUND,
				"%s never refunds nothing at all" % id)
		if err != "":
			return err
	return ""


func test_uprooting_and_replanting_a_wreck_costs_more_than_it_returns() -> String:
	## The actual acceptance criterion: replacing a damaged plant has to be a real
	## purchase, not a discount repair. Driven through a real bank so the claim is
	## about seeds in the purse, not about a formula.
	var bank := SeedBank.new()
	bank.set_seed(21)
	bank.add_seeds(5000)
	var guard: int = 0
	while not bank.locked_plants().is_empty() and guard < 40:
		guard += 1
		# Every tier, cheapest first: no single tier reaches the whole catalogue
		# any more (SeedBank.PACKET_TIERS), so a loop that named one would leave
		# the top plant locked and this test would report it as unaffordable.
		for tier: StringName in SeedBank.PACKET_ORDER:
			if bank.buy_packet(tier) != &"":
				break
	# Burn the one free planting, or the Corn Cobbler's replant price is 0 and the
	# exploit reads as free rather than as arithmetic.
	bank.pay_for_plant(PlantCatalog.starting_unlocks()[0])
	for id: StringName in PlantCatalog.ids():
		var replant: int = bank.placement_cost(id)
		var wreck: int = _refund_at_health(id, 1.0)
		var before: int = bank.seeds
		bank.refund(wreck)
		var err: String = _T.assert_true(bank.pay_for_plant(id),
			"replanting %s is affordable in this test" % id)
		if err == "":
			err = _T.assert_eq(bank.seeds, before + wreck - replant,
				"%s: uproot (+%d) then replant (-%d) leaves the purse short" % [id, wreck, replant])
		if err == "":
			err = _T.assert_gt(replant, wreck,
				"%s: a wreck returns %d and costs %d to replace — recycling is not a repair"
					% [id, wreck, replant])
		if err == "":
			# And strictly worse than it used to be: under the old flat 0.6 refund a
			# Corn Cobbler healed itself for 4 seeds, which is what made replanting
			# dominant over leaving a damaged plant standing.
			var old_loss: int = replant - int(floor(replant * Plant.UPROOT_RATE_FULL))
			err = _T.assert_gt(replant - wreck, old_loss,
				"%s: the round trip now costs %d, up from the old flat %d"
					% [id, replant - wreck, old_loss])
		if err != "":
			return err
	return ""


func test_the_uproot_button_reprices_itself_as_the_plant_is_chewed() -> String:
	## A refund the player cannot see before committing is not a decision. The
	## button label is where this number lives, and it is refreshed off
	## Game._watch_selected_health — a poll, not a signal, so it only lands if
	## _process runs between the bite and the read.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(200)
	var cell := Vector2i(-1, -1)
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			if game.board.is_buildable(Vector2i(x, y)) and game.plant_at(Vector2i(x, y)) == null:
				cell = Vector2i(x, y)
				break
		if cell.x >= 0:
			break
	var err: String = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "", "planted")
	var button: Button = game.hud.get_node_or_null("Root/SidePanel/SelectionBox/UprootButton") as Button
	if err == "":
		err = _T.assert_true(button != null, "the uproot button is on screen")
	if err == "":
		err = _T.assert_eq(button.text, "Uproot (+%d)" % game.selected_placed.uproot_refund(),
			"the resting label prints the live refund, got %s" % button.text)
	if err == "":
		var before: String = button.text
		game.selected_placed.take_damage(Plant.MAX_HEALTH - 1.0)
		game._process(0.016)
		err = _T.assert_true(button.text != before,
			"a chewed plant reprices its own uproot button, still says %s" % button.text)
		if err == "":
			err = _T.assert_eq(button.text, "Uproot (+%d)" % game.selected_placed.uproot_refund(),
				"and prints exactly what commit_uproot would pay, got %s" % button.text)
	_T.free_ui(game)
	return err


# -- Refunds are change, not income (plant-tower-defense-v3b) ----------------
#
# `seeds_earned_total` is the number RunConfig.record_score() files as the high
# score for BOTH modes (Game._end_run), and SeedBank.refund() used to route
# through add_seeds(), which credits it. So a Corn Cobbler — 10 to plant, 6 back
# at full health — cost 4 of purse and paid 6 of score per plant-and-uproot
# cycle, repeatably: a 100-seed float buys 23 round trips and ~138 points of
# recorded score with no pest ever reaching the board. The purse arithmetic was
# never wrong; only the scoreboard was.


## First buildable, empty cell. Re-read rather than cached, because the loop
## below replants on the same cell and has to see it come free again.
func _empty_grass(game: Game) -> Vector2i:
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var cell := Vector2i(x, y)
			if game.board.is_buildable(cell) and game.plant_at(cell) == null:
				return cell
	return Vector2i(-1, -1)


func test_planting_and_uprooting_in_a_loop_does_not_move_the_score() -> String:
	## The exploit itself, through a real Game rather than a bare bank, because
	## what makes it an exploit is that a player can click it.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(200)
	var cell: Vector2i = _empty_grass(game)
	var err: String = _T.assert_gte(cell.x, 0, "there is a grass cell to plant on")
	# Burn the one free planting first, or the first cycle costs nothing and the
	# arithmetic below reads as a discount instead of as the churn.
	if err == "":
		err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "", "the free starter is spent")
	if err == "":
		err = _T.assert_eq(game.commit_uproot(), "", "and pulled straight back up")
	var cost: int = game.bank.placement_cost(PlantCatalog.CORN)
	var earned_before: int = game.bank.seeds_earned_total
	var seeds_before: int = game.bank.seeds
	var refund: int = 0
	var cycles: int = 10
	for i: int in range(cycles):
		if err != "":
			break
		err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "", "cycle %d plants" % i)
		if err == "":
			# Read before the uproot, off the same method the button prints.
			refund = game.selected_placed.uproot_refund()
			err = _T.assert_eq(game.commit_uproot(), "", "cycle %d uproots" % i)
	if err == "":
		err = _T.assert_eq(game.bank.seeds_earned_total, earned_before,
			"%d plant/uproot cycles earned nothing — the score is for playing, not for churning"
				% cycles)
	if err == "":
		# The other half of the claim: the purse still moves, and downward. This is
		# a fix to the scoreboard, not a nerf to uprooting.
		err = _T.assert_gt(cost, refund,
			"one round trip is a real loss (%d out, %d back)" % [cost, refund])
	if err == "":
		err = _T.assert_eq(game.bank.seeds, seeds_before - cycles * (cost - refund),
			"and the player paid %d for the churn" % (cycles * (cost - refund)))
	_T.free_ui(game)
	return err


func test_ordinary_income_still_raises_the_recorded_score() -> String:
	## The fix must not make the scoreboard stop counting. A pest kill is the
	## income path with the most wiring under it — Game._on_pest_died — so it is
	## the one worth driving; the bare add_seeds call covers Sunflower yields and
	## swept husks, which reach the bank the same way.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var earned_before: int = game.bank.seeds_earned_total
	var victim: Pest = _spawn_and_take(game, Pest.APHID)
	var err: String = _T.assert_true(victim != null, "a pest is on the board to kill")
	var value: int = 0
	if err == "":
		value = victim.seed_value
		err = _T.assert_gt(value, 0, "and it is worth something to kill")
	if err == "":
		victim.take_damage(9999.0)
		err = _T.assert_eq(game.bank.seeds_earned_total, earned_before + value,
			"a kill is income, and income is the score")
	if err == "":
		var mid: int = game.bank.seeds_earned_total
		game.bank.add_seeds(17)
		err = _T.assert_eq(game.bank.seeds_earned_total, mid + 17,
			"and add_seeds still credits the score by default")
	_T.free_ui(game)
	return err


func test_an_upgrade_charge_never_raises_the_score() -> String:
	## A charge is a negative add_seeds, and the sign guard already kept it off the
	## score — pinned here because the refund fix sits in the same `if`, and a
	## flag added carelessly could let -12 seeds count as 12 earned.
	var bank := SeedBank.new()
	bank.add_seeds(100)
	var earned: int = bank.seeds_earned_total
	var purse: int = bank.seeds
	bank.add_seeds(-12)
	var err: String = _T.assert_eq(bank.seeds_earned_total, earned,
		"paying 12 out is not earning 12")
	if err == "":
		err = _T.assert_eq(bank.seeds, purse - 12, "but it is still charged for")
	if err != "":
		return err
	# And through the caller that actually passes a negative amount.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(500)
	var cell: Vector2i = _empty_grass(game)
	err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "", "planted something upgradeable")
	if err == "":
		var corn := game.selected_placed as CornCobbler
		err = _T.assert_true(corn != null, "a Corn Cobbler is selected")
		if err == "":
			var price: int = corn.upgrade_cost()
			var earned_before: int = game.bank.seeds_earned_total
			var seeds_before: int = game.bank.seeds
			err = _T.assert_eq(game.upgrade_selected(), "", "the upgrade goes through")
			if err == "":
				err = _T.assert_eq(game.bank.seeds, seeds_before - price,
					"and costs %d seeds" % price)
			if err == "":
				err = _T.assert_eq(game.bank.seeds_earned_total, earned_before,
					"while the score sits still — spending is not earning")
	_T.free_ui(game)
	return err


func test_a_refund_still_pays_the_player_exactly_what_it_promised() -> String:
	## The fix moves the score and nothing else. Both routes: refund() on its own,
	## and a real uproot taken at a health where the slope has actually bitten, so
	## this would catch a "fix" that quietly changed what comes back.
	var bank := SeedBank.new()
	var purse: int = bank.seeds
	bank.refund(7)
	var err: String = _T.assert_eq(bank.seeds, purse + 7, "refund() still pays out in full")
	if err == "":
		err = _T.assert_eq(bank.seeds_earned_total, 0, "without ever crediting the score")
	if err != "":
		return err
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(200)
	var cell: Vector2i = _empty_grass(game)
	err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "", "planted")
	if err == "":
		game.selected_placed.take_damage(Plant.MAX_HEALTH * 0.5)
		var promised: int = game.selected_placed.uproot_refund()
		var seeds_before: int = game.bank.seeds
		var earned_before: int = game.bank.seeds_earned_total
		err = _T.assert_gt(promised, 0, "a half-eaten plant is still worth scrapping")
		if err == "":
			err = _T.assert_eq(game.commit_uproot(), "", "uprooted")
		if err == "":
			err = _T.assert_eq(game.bank.seeds, seeds_before + promised,
				"the purse gained exactly the %d the uproot button printed" % promised)
		if err == "":
			err = _T.assert_eq(game.bank.seeds_earned_total, earned_before,
				"and the score did not follow the money")
	_T.free_ui(game)
	return err


# -- A save that cannot be read must not zero a record (plant-tower-defense-5el) --
#
# The high score is the only quantity in this game a player cannot re-earn on
# demand, and `RunConfig.record_score` only ever raises a record. So a `_load`
# that wrote a 0 into a slot did not merely lose one launch's reading: the next
# mediocre run refilled the slot and the real number was gone permanently. Two
# routes there, both now closed. `int("")` is 0 in GDScript and `get_line()`
# returns `""` past the end of a truncated file, so a half-written save loaded as
# a pair of zeros that looked exactly like a player who had never played. And the
# `SAVE_VERSION` stamp was written on every save and compared on no load, so a
# file from a later build was parsed as if it were this one's.
#
# These drive the real `_load`/`_save` over a scratch path rather than over
# `user://highscore.save`, because pointing a test suite at the developer's own
# save is the same bug wearing a different hat.

const HIGHSCORE_TEST_PATH := "user://test_economy_highscore.save"


## Every file the scratch save path can produce — the save, the temp file `_save`
## assembles in, and the quarantine `_save` moves a refused file to.
func _scratch_save_files() -> Array[String]:
	return [
		HIGHSCORE_TEST_PATH,
		HIGHSCORE_TEST_PATH + ".tmp",
		HIGHSCORE_TEST_PATH + ".bak",
	]


func _clear_scratch_save() -> void:
	for path: String in _scratch_save_files():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## Points RunConfig at the scratch save with `contents` on disk (`null` writes no
## file at all) and the given in-memory records, runs `body`, and then puts every
## piece of RunConfig back and deletes every scratch file — on the failing return
## as well as the passing one, since `body` reports a failure by returning a
## string rather than by throwing, and a leftover save file would be read by the
## next run of this suite.
##
## RunConfig is an autoload shared by the whole test run. `save_path`, both
## scores, `endless`, `fresh_record` and `load_status` all have to come back, or
## every later test inherits whatever this one was proving.
func _with_scratch_save(campaign: int, endless_best: int, contents: Variant, body: Callable) -> String:
	_clear_scratch_save()
	if contents != null:
		var f := FileAccess.open(HIGHSCORE_TEST_PATH, FileAccess.WRITE)
		if f == null:
			# Nothing has been redirected yet, so there is nothing to restore.
			return "could not create the scratch save at %s" % HIGHSCORE_TEST_PATH
		f.store_string(str(contents))
		f.close()

	_stash_run_config()
	RunConfig.save_path = HIGHSCORE_TEST_PATH
	RunConfig.campaign_high_score = campaign
	RunConfig.endless_high_score = endless_best
	# The third persisted field, and the one a test is most likely to inherit
	# without noticing: an earned flag left over from an earlier test changes the
	# bytes `_save` writes, which is precisely what the byte-exact assertions below
	# are reading.
	RunConfig.earned_milestones = {}
	# And the fourth. Same reasoning: it is one of the bytes `_save` writes.
	RunConfig.colorblind_safe = false
	# The fifth and sixth, added to the options line at v6. These are the ones most
	# likely to be inherited without noticing, because nothing in this suite has to
	# mention audio to move them: RunConfig loads them from the developer's own save
	# at startup, so a maintainer who plays muted would read `sfx1` in every
	# byte-exact assertion below.
	RunConfig.mute_sfx = false
	RunConfig.mute_music = false
	var err: String = str(body.call())
	_restore_run_config()
	return err


## Everything of RunConfig's these tests move, remembered where `teardown` can
## also reach it. The wrapper above restores on both of its own return paths, but
## a runtime error inside `body` aborts the test method outright and neither of
## them runs — and an aborted test that leaves the autoload pointing at a deleted
## scratch file is how one failure becomes a whole suite of them.
var _stashed_run_config: Dictionary = {}


func _stash_run_config() -> void:
	_stashed_run_config = {
		"save_path": RunConfig.save_path,
		"campaign_high_score": RunConfig.campaign_high_score,
		"endless_high_score": RunConfig.endless_high_score,
		"endless": RunConfig.endless,
		"fresh_record": RunConfig.fresh_record,
		"load_status": RunConfig.load_status,
		# Parsed out of the save alongside the scores, so a scratch fixture that
		# carries rebindings would otherwise leave them in the autoload for every
		# later test. `_load` deliberately does not touch the live InputMap, so
		# this is the whole of the blast radius.
		"key_bindings": RunConfig.key_bindings,
		# Duplicated, not aliased: the Dictionary is mutated in place by
		# `record_milestones` and by `_load`, so stashing the reference would hand
		# `_restore_run_config` the very object the test just changed.
		"earned_milestones": RunConfig.earned_milestones.duplicate(),
		"colorblind_safe": RunConfig.colorblind_safe,
		# The two mutes, both halves each. RunConfig's own fields are what the writer
		# emits; Sfx's and Music's statics are what a player hears, and a test that
		# went through the setters has moved both. Leaking either one is how a
		# persisted flag reaches a test that never mentioned sound.
		"mute_sfx": RunConfig.mute_sfx,
		"mute_music": RunConfig.mute_music,
		"sfx_is_muted": Sfx.is_muted(),
		"music_is_muted": Music.is_muted(),
		# Private, and stashed anyway: a refusal leaves a quarantine pending, and
		# leaking that into a later test means an unrelated `_save` tries to move a
		# file this one deleted.
		"_refused_path": RunConfig._refused_path,
	}


func _restore_run_config() -> void:
	if _stashed_run_config.is_empty():
		return
	RunConfig.save_path = str(_stashed_run_config["save_path"])
	RunConfig.campaign_high_score = int(_stashed_run_config["campaign_high_score"])
	RunConfig.endless_high_score = int(_stashed_run_config["endless_high_score"])
	RunConfig.endless = bool(_stashed_run_config["endless"])
	RunConfig.fresh_record = bool(_stashed_run_config["fresh_record"])
	RunConfig.load_status = str(_stashed_run_config["load_status"])
	RunConfig.key_bindings = _stashed_run_config["key_bindings"] as Dictionary
	RunConfig.earned_milestones = (_stashed_run_config["earned_milestones"] as Dictionary).duplicate()
	RunConfig.colorblind_safe = bool(_stashed_run_config["colorblind_safe"])
	RunConfig.mute_sfx = bool(_stashed_run_config["mute_sfx"])
	RunConfig.mute_music = bool(_stashed_run_config["mute_music"])
	Sfx.set_muted(bool(_stashed_run_config["sfx_is_muted"]))
	Music.set_muted(bool(_stashed_run_config["music_is_muted"]))
	RunConfig._refused_path = str(_stashed_run_config["_refused_path"])
	_stashed_run_config = {}
	_clear_scratch_save()


## Where this script's RunConfig writes go instead of the player's own save.
##
## Distinct from HIGHSCORE_TEST_PATH, which `_with_scratch_save` points at for the
## tests that are ABOUT the save format and that stage bytes for it to read. This one
## is the floor under everything else in the file: the reasoning is written out once,
## in test_combat.gd's setup(), and the short version is that hosting `game.tscn` can
## reach `RunConfig._save()` through the game's own code on a condition no reader can
## evaluate. `tools/save_persist_check.py` requires it of any test script that can.
const SUITE_SAVE_PATH := "user://test_economy_suite.save"
var _suite_stashed_save_path: String = ""


func setup() -> void:
	_suite_stashed_save_path = RunConfig.save_path
	RunConfig.save_path = SUITE_SAVE_PATH


## Called by the runner after every test in this file, including one that aborted
## on a runtime error. A no-op unless a scratch-save test left something behind.
func teardown() -> void:
	_restore_run_config()
	# After the restore, not before: `_restore_run_config` puts back whatever
	# `_stash_run_config` took, which is this file's own SUITE_SAVE_PATH, so undoing
	# the suite-level redirect has to be the last word.
	if _suite_stashed_save_path != "":
		RunConfig.save_path = _suite_stashed_save_path
	DirAccess.remove_absolute(SUITE_SAVE_PATH)


## `_load` ran, refused what it found, and left both records exactly where they
## were. The assertion that matters is the pair of numbers, not the status: a
## status of "refused" sitting beside a zeroed score would be a more articulate
## version of the same bug.
func _assert_refused(campaign: int, endless_best: int, what: String) -> String:
	RunConfig._load()
	var err: String = _T.assert_eq(RunConfig.campaign_high_score, campaign,
		"%s left the campaign record alone" % what)
	if err == "":
		err = _T.assert_eq(RunConfig.endless_high_score, endless_best,
			"%s left the endless record alone" % what)
	if err == "":
		err = _T.assert_eq(RunConfig.load_status, "refused",
			"%s was refused rather than quietly half-read" % what)
	return err


func test_a_truncated_save_leaves_the_records_alone() -> String:
	## The original defect. A save is three `store_line` calls, so an interrupted
	## write leaves the header alone, or the header and one score, or a score cut
	## mid-digit. Every one of them used to reach `int(f.get_line())` on an empty
	## string and file a 0 that `record_score` could then never raise back.
	var cases: Dictionary = {
		"a header-only save": "v2\n",
		"a save cut after the campaign line": "v2\n4321\n",
		"a save cut mid-number with no newline": "v2\n43",
		"a save with a blank score line": "v2\n4321\n\n",
	}
	for what: String in cases:
		var err: String = _with_scratch_save(4321, 8765, cases[what],
			func() -> String: return _assert_refused(4321, 8765, what))
		if err != "":
			return err
	return ""


func test_a_garbage_save_leaves_the_records_alone() -> String:
	## Anything that is not the format: a hand-edit, a crossed file, a zero-length
	## file left behind by a disk that filled up. None of it may be interpreted.
	var cases: Dictionary = {
		"an empty file": "",
		"prose": "hello there\nfriend\n",
		"a version header that is not a number": "vX\n10\n20\n",
		"non-numeric scores": "v2\nlots\nmore\n",
		"a fractional score": "v2\n12.5\n20\n",
		"a negative score": "v2\n-40\n20\n",
	}
	for what: String in cases:
		var err: String = _with_scratch_save(4321, 8765, cases[what],
			func() -> String: return _assert_refused(4321, 8765, what))
		if err != "":
			return err
	return ""


func test_a_save_from_a_newer_build_is_refused_not_reinterpreted() -> String:
	## What `SAVE_VERSION` is now for. A file one version ahead might be endless
	## first, or campaign plus some fourth record — reading it positionally as the
	## current shape is how a later build's numbers land in the wrong slots with no
	## error at all.
	## The scores in the fixture are deliberately valid-looking integers, so the
	## version number is the only thing that can be rejecting them.
	for ahead: int in [1, 7]:
		var future: int = RunConfig.SAVE_VERSION + ahead
		var contents: String = "v%d\n11\n22\n" % future
		var what: String = "a version %d save" % future
		var err: String = _with_scratch_save(4321, 8765, contents,
			func() -> String: return _assert_refused(4321, 8765, what))
		if err != "":
			return err
	return ""


func test_no_save_at_all_still_means_a_fresh_pair_of_zeros() -> String:
	## The first-launch case has to keep working: refusing to trust a bad file
	## must not turn into refusing to start. Absence is a legitimate reading and a
	## different one from refusal — which is the whole reason `load_status`
	## distinguishes them rather than both just being "the scores did not move".
	return _with_scratch_save(0, 0, null, func() -> String:
		RunConfig._load()
		var err: String = _T.assert_eq(RunConfig.load_status, "absent",
			"no file at all is 'absent', not 'refused'")
		if err == "":
			err = _T.assert_eq(RunConfig.campaign_high_score, 0, "a first launch has no campaign record")
		if err == "":
			err = _T.assert_eq(RunConfig.endless_high_score, 0, "and no endless record")
		if err == "":
			err = _T.assert_false(FileAccess.file_exists(HIGHSCORE_TEST_PATH),
				"and reading nothing did not write anything either")
		return err)


func test_a_well_formed_save_round_trips_exactly() -> String:
	## The happy path, end to end through the real writer and the real reader, and
	## byte-exact on the file itself — a reader that refused everything would pass
	## every test above this one.
	return _with_scratch_save(1234, 5678, null, func() -> String:
		RunConfig._save()
		var err: String = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH),
			"v%d\n1234\n5678\nm0\ncb0 sfx0 mus0\n0\n" % RunConfig.SAVE_VERSION,
			"the save is a version stamp, campaign, endless, the milestone set, the options, then a count of rebound keys")
		if err == "":
			err = _T.assert_false(FileAccess.file_exists(HIGHSCORE_TEST_PATH + ".tmp"),
				"and the temp file it was assembled in was renamed away, not left behind")
		if err == "":
			# Deliberately not zeros: a `_load` that assigned nothing at all would
			# otherwise pass this by doing nothing at all.
			RunConfig.campaign_high_score = 7
			RunConfig.endless_high_score = 9
			RunConfig._load()
			err = _T.assert_eq(RunConfig.load_status, "loaded", "a current-version file loads")
		if err == "":
			err = _T.assert_eq(RunConfig.campaign_high_score, 1234, "campaign came back exactly")
		if err == "":
			err = _T.assert_eq(RunConfig.endless_high_score, 5678, "endless came back exactly")
		return err)


func test_a_refused_save_is_not_immediately_overwritten() -> String:
	## The other half of "leave the scores alone": leave the file alone too. This
	## build failing to read a file is not evidence that nothing can read it, and
	## stamping the fallback over it on launch is what turns a bad read into a
	## permanent loss. When a later `_save` finally does need the path, the refused
	## bytes are moved aside rather than destroyed.
	var original: String = "v2\nnot-a-number\n8765\n"
	return _with_scratch_save(4321, 8765, original, func() -> String:
		var err: String = _assert_refused(4321, 8765, "a corrupt save")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH), original,
				"the file it could not read is still on disk, byte for byte")
		if err == "":
			err = _T.assert_false(FileAccess.file_exists(HIGHSCORE_TEST_PATH + ".bak"),
				"and nothing was quarantined yet — reading is not the moment to move files")
		if err == "":
			# Now make the game genuinely need the path, and check the old bytes
			# survive the takeover.
			RunConfig.endless = false
			err = _T.assert_true(RunConfig.record_score(9999),
				"9999 beats the campaign record that survived the refusal")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH + ".bak"), original,
				"the unreadable file was moved aside, not written over")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH),
				"v%d\n9999\n8765\nm0\ncb0 sfx0 mus0\n0\n" % RunConfig.SAVE_VERSION,
				"and the new save kept the endless record the refusal had preserved")
		return err)


func test_a_version_one_save_still_migrates_into_the_endless_slot() -> String:
	## Reading the version must not cost the one migration that already exists.
	## Version 1 was a bare integer with no header at all, and it lands in the
	## endless slot on purpose — the title screen has always called it "Best
	## endless run", so that is the record the player believes they hold.
	return _with_scratch_save(4321, 8765, "31337\n", func() -> String:
		RunConfig._load()
		var err: String = _T.assert_eq(RunConfig.load_status, "migrated",
			"a headerless file is version 1")
		if err == "":
			err = _T.assert_eq(RunConfig.endless_high_score, 31337,
				"the legacy number is the endless record")
		if err == "":
			err = _T.assert_eq(RunConfig.campaign_high_score, 0, "and campaign starts empty")
		if err == "":
			# A parse that fully succeeded is the one case that may rewrite the file.
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH),
				"v%d\n0\n31337\nm0\ncb0 sfx0 mus0\n0\n" % RunConfig.SAVE_VERSION,
				"and the ambiguity is resolved on disk once, not re-guessed every launch")
		return err)


func test_an_interrupted_save_is_recovered_rather_than_read_as_zero() -> String:
	## The write side of the same principle. `FileAccess.WRITE` truncates its
	## target as it opens, so writing in place destroyed the previous save before
	## producing a byte of the new one — on a full or read-only user:// that left a
	## stub where a record used to be. `_save` now assembles beside the file and
	## renames, which is only worth doing if `_load` picks the temp up when the
	## rename is the step that got interrupted.
	return _with_scratch_save(1234, 5678, null, func() -> String:
		RunConfig._save()
		var written: String = FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH)
		# Stage exactly the state a crash between "the temp file is complete" and
		# "the temp file has replaced the save" leaves behind.
		DirAccess.rename_absolute(HIGHSCORE_TEST_PATH, HIGHSCORE_TEST_PATH + ".tmp")
		RunConfig.campaign_high_score = 0
		RunConfig.endless_high_score = 0
		RunConfig._load()
		var err: String = _T.assert_eq(RunConfig.load_status, "recovered",
			"a complete temp file with no save beside it is adopted, not read as a first launch")
		if err == "":
			err = _T.assert_eq(RunConfig.campaign_high_score, 1234, "campaign survived the interruption")
		if err == "":
			err = _T.assert_eq(RunConfig.endless_high_score, 5678, "endless survived it too")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH), written,
				"and the save is back where it belongs")
		return err)


# -- milestones (plant-tower-defense-4qi) ------------------------------------
#
# The third persisted field. Everything above is about not losing two numbers a
# player cannot re-earn; a milestone flag IS re-earnable, and these tests are
# about the same file not becoming less careful because a cheaper field moved
# into it.


func test_a_run_with_milestones_round_trips_through_the_save() -> String:
	## The whole point: the flags outlive the scene AND the process. Two ids, not
	## one, because a writer that joined nothing and a reader that split nothing
	## would agree perfectly on a single-element list.
	return _with_scratch_save(1234, 5678, null, func() -> String:
		var fresh: Array[String] = RunConfig.record_milestones(["hundred_pests", "campaign_cleared"])
		var err: String = _T.assert_eq(fresh.size(), 2, "both ids were new")
		if err == "":
			# Sorted on the way out, so the bytes are a function of the SET rather
			# than of the order the run happened to earn things in.
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH),
				"v%d\n1234\n5678\nm2:campaign_cleared,hundred_pests\ncb0 sfx0 mus0\n0\n" % RunConfig.SAVE_VERSION,
				"filing a milestone wrote the file, ids sorted")
		if err == "":
			# Deliberately not empty: a `_load` that assigned nothing would pass an
			# emptiness check by doing nothing at all.
			RunConfig.earned_milestones = {"something_else": true}
			RunConfig._load()
			err = _T.assert_eq(RunConfig.load_status, "loaded", "the v3 file loads")
		if err == "":
			err = _T.assert_true(RunConfig.has_milestone("campaign_cleared"), "the clear came back")
		if err == "":
			err = _T.assert_true(RunConfig.has_milestone("hundred_pests"), "and so did the hundred")
		if err == "":
			err = _T.assert_false(RunConfig.has_milestone("something_else"),
				"and the load replaced the in-memory set rather than merging into it")
		return err)


func test_filing_a_milestone_twice_is_not_a_second_first_time() -> String:
	## `record_milestones` returns the NEW ids, and that return value is the only
	## moment newness exists — by the time the card asks, the flag is set. Both end
	## paths of a run can fire twice in a frame, so a second call announcing the
	## same milestone again is the failure this guards.
	return _with_scratch_save(1, 2, null, func() -> String:
		var first: Array[String] = RunConfig.record_milestones(["threat_peak"])
		var err: String = _T.assert_eq(first.size(), 1, "the first filing is new")
		if err == "":
			var again: Array[String] = RunConfig.record_milestones(["threat_peak", "clean_sweep"])
			err = _T.assert_eq(again.size(), 1, "the second filing reports only the genuinely new one")
		if err == "":
			err = _T.assert_eq(str(RunConfig.record_milestones(["threat_peak"])), "[]",
				"and a repeat of an already-earned id is nothing at all")
		if err == "":
			err = _T.assert_eq(RunConfig.earned_milestones.size(), 2, "two flags are held")
		return err)


func test_a_version_two_save_migrates_forward_with_an_empty_milestone_set() -> String:
	## The migration that the version bump is actually for. A v2 file has three
	## lines and no fourth, and reading it must not be confused with reading a v3
	## file whose fourth line was lost — the version says which of those it is.
	return _with_scratch_save(0, 0, "v2\n4321\n8765\n", func() -> String:
		RunConfig._load()
		var err: String = _T.assert_eq(RunConfig.load_status, "migrated",
			"a v2 file is read and rewritten, not refused")
		if err == "":
			err = _T.assert_eq(RunConfig.campaign_high_score, 4321, "campaign survived the bump")
		if err == "":
			err = _T.assert_eq(RunConfig.endless_high_score, 8765, "and so did endless")
		if err == "":
			err = _T.assert_eq(RunConfig.earned_milestones.size(), 0,
				"a player who predates milestones has earned none of them")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH),
				"v%d\n4321\n8765\nm0\ncb0 sfx0 mus0\n0\n" % RunConfig.SAVE_VERSION,
				"and the file is now the current shape, resolved once")
		return err)


func test_a_v3_save_with_a_broken_milestone_line_is_refused_whole() -> String:
	## The line that exists because `get_line()` returns "" past the end of a
	## truncated file — the same defect `_is_score` refuses for the scores, in the
	## one field where "" would otherwise be a perfectly ordinary reading.
	##
	## Refused WHOLE, deliberately. The flags in this file are cheap and the two
	## scores beside them are not, so the tempting move — take the scores, drop the
	## milestones — is exactly the half-adoption `_parse_save` exists to refuse.
	var cases: Dictionary = {
		"a v3 save cut before its milestone line": "v3\n4321\n8765\n",
		"a milestone line with no marker": "v3\n4321\n8765\n2:a,b\n",
		"a count that disagrees with the list": "v3\n4321\n8765\nm3:alpha,beta\n",
		"a count with no list": "v3\n4321\n8765\nm2\n",
		"a list with no count": "v3\n4321\n8765\nm0:alpha\n",
		"an empty id between two commas": "v3\n4321\n8765\nm3:alpha,,beta\n",
		"an id with characters no build writes": "v3\n4321\n8765\nm1:Alpha Beta\n",
		"the same id twice": "v3\n4321\n8765\nm2:alpha,alpha\n",
	}
	for what: String in cases:
		var err: String = _with_scratch_save(4321, 8765, cases[what],
			func() -> String: return _assert_refused(4321, 8765, what))
		if err != "":
			return err
	return ""


func test_a_milestone_id_this_build_has_never_heard_of_survives_a_round_trip() -> String:
	## A save written by a later build carries ids with no rule here. Dropping them
	## would silently un-earn them the moment an older build touched the file, which
	## is a data loss with no error attached — so the parser takes any well-formed
	## id and the writer hands it straight back.
	# A current-shape fixture, not the v3 this was written against: v3 is refused
	# outright now (two branches each defined one, see RunConfig.SAVE_VERSION), so
	# carrying the unknown id through a version bump is no longer a thing this test
	# can express. What it is about — the parser keeping an id it has no rule for —
	# is unchanged and is what stays asserted here.
	return _with_scratch_save(0, 0, "v%d\n10\n20\nm2:from_the_future,hundred_pests\ncb0 sfx0 mus0\n0\n"
			% RunConfig.SAVE_VERSION,
		func() -> String:
			RunConfig._load()
			var err: String = _T.assert_eq(RunConfig.load_status, "loaded", "the file reads")
			if err == "":
				err = _T.assert_true(RunConfig.has_milestone("from_the_future"),
					"an id with no rule in this build is still held")
			if err == "":
				err = _T.assert_true(Milestones.entry("from_the_future").is_empty(),
					"and this build genuinely has no rule for it")
			if err == "":
				RunConfig.record_milestones(["threat_peak"])
				err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH),
					"v%d\n10\n20\nm3:from_the_future,hundred_pests,threat_peak\ncb0 sfx0 mus0\n0\n"
						% RunConfig.SAVE_VERSION,
					"and the next save writes it back out rather than eating it")
			return err)


# -- display options (plant-tower-defense-xu0) -------------------------------
#
# The fifth line. An accessibility option that resets every launch is one the
# player has to find again every launch, so it is persisted -- and persisting it
# means it inherits every rule the scores above it live under.


func test_the_colourblind_option_round_trips_through_the_save() -> String:
	## Set it, write it, read it back over a deliberately wrong in-memory value.
	return _with_scratch_save(11, 22, null, func() -> String:
		var err: String = _T.assert_true(RunConfig.toggle_colorblind_safe(),
			"one toggle turns the safe ramp on")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH),
				"v%d\n11\n22\nm0\ncb1 sfx0 mus0\n0\n" % RunConfig.SAVE_VERSION,
				"and wrote it down rather than holding it for the session")
		if err == "":
			# Deliberately the wrong value, so a `_load` that assigned nothing at
			# all could not pass this by doing nothing at all.
			RunConfig.colorblind_safe = false
			RunConfig._load()
			err = _T.assert_true(RunConfig.colorblind_safe, "the option came back on")
		if err == "":
			err = _T.assert_false(RunConfig.toggle_colorblind_safe(), "a second toggle turns it off")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH),
				"v%d\n11\n22\nm0\ncb0 sfx0 mus0\n0\n" % RunConfig.SAVE_VERSION,
				"and that is written down too -- off is a choice, not an absence")
		return err)


func test_setting_the_option_to_what_it_already_is_does_not_rewrite_the_save() -> String:
	## `set_colorblind_safe` writes only on a change. The save file is not a place
	## to record that someone pressed a key twice, and every write is a rename over
	## the one file in this game holding a number that cannot be re-earned.
	return _with_scratch_save(5, 6, null, func() -> String:
		RunConfig.set_colorblind_safe(true)
		var written: String = FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH)
		var err: String = _T.assert_true(written.contains("\ncb1 sfx0 mus0\n"), "the first set wrote the file")
		if err == "":
			# Move the scores under it. A second set that rewrites would pick these
			# up; one that no-ops leaves the file as it was.
			RunConfig.campaign_high_score = 999
			err = _T.assert_true(RunConfig.set_colorblind_safe(true),
				"setting it to what it already is still reports the state")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH), written,
				"and the file was not touched")
		return err)


func test_a_save_with_a_broken_options_line_is_refused_whole() -> String:
	## Same rule as the milestone line, and the same reason for it: "" is what
	## `get_line()` returns past the end of a truncated file, and `bool("")` is
	## false -- which is a legal-looking reading of an option whose whole point is
	## that it stays on.
	# Current-version fixtures on purpose. These were written as `v4` literals, and
	# they kept passing after v4 became a refused version — but for the wrong
	# reason: the whole file was being turned away before the options line was ever
	# read, so the thing this test names was no longer the thing failing it.
	var cases: Dictionary = {
		"a save cut before its options line": "v%d\n4321\n8765\nm0\n" % RunConfig.SAVE_VERSION,
		"a bare 0 with no marker": "v%d\n4321\n8765\nm0\n0\n" % RunConfig.SAVE_VERSION,
		"a spelled-out boolean": "v%d\n4321\n8765\nm0\nfalse\n" % RunConfig.SAVE_VERSION,
		"an option value that is not one of the two":
			"v%d\n4321\n8765\nm0\ncb2 sfx0 mus0\n" % RunConfig.SAVE_VERSION,
		# v6's own shapes. The line grew from one field to three, and every way a
		# three-field line can be wrong is a way this parser must not shrug.
		"a v5-shaped options line in a v6 file":
			"v%d\n4321\n8765\nm0\ncb0\n" % RunConfig.SAVE_VERSION,
		"an options line one field short":
			"v%d\n4321\n8765\nm0\ncb0 sfx0\n" % RunConfig.SAVE_VERSION,
		"an options line with a fourth field":
			"v%d\n4321\n8765\nm0\ncb0 sfx0 mus0 xyz1\n" % RunConfig.SAVE_VERSION,
		# The whole reason each flag carries its own prefix. A bare `0 1 0` reads
		# perfectly when two fields swap places, and the player's music mute quietly
		# becomes their colourblind setting.
		"an options line with its fields transposed":
			"v%d\n4321\n8765\nm0\nsfx0 cb0 mus0\n" % RunConfig.SAVE_VERSION,
		"an options line padded with a second space":
			"v%d\n4321\n8765\nm0\ncb0  sfx0 mus0\n" % RunConfig.SAVE_VERSION,
	}
	for what: String in cases:
		var err: String = _with_scratch_save(4321, 8765, cases[what],
			func() -> String: return _assert_refused(4321, 8765, what))
		if err != "":
			return err
	return ""


# -- the two audio mutes (plant-tower-defense-v6c) ---------------------------
#
# v6 widened the options line from `cb0` to `cb0 sfx0 mus0`. The Options screen
# shows all three switches in one list, and before this two of them reset on every
# launch while the third did not -- with nothing on screen saying which was which.


func test_the_two_mutes_round_trip_through_the_save() -> String:
	## Both, not one: a writer that emitted a single flag and a reader that read a
	## single flag would agree perfectly on a file where the two happen to match, so
	## the fixture below sets them to DIFFERENT values.
	return _with_scratch_save(11, 22, null, func() -> String:
		var err: String = _T.assert_true(RunConfig.set_mute_sfx(true),
			"muting the cues reports the muted state, matching Sfx.set_muted's own return")
		if err == "":
			err = _T.assert_true(Sfx.is_muted(), "and the flag the player hears moved too")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH),
				"v%d\n11\n22\nm0\ncb0 sfx1 mus0\n0\n" % RunConfig.SAVE_VERSION,
				"the options line carries all three switches, colourblind first")
		if err == "":
			err = _T.assert_true(RunConfig.set_mute_music(true), "and the bed mutes independently")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH),
				"v%d\n11\n22\nm0\ncb0 sfx1 mus1\n0\n" % RunConfig.SAVE_VERSION,
				"which is a third field, not the same field written twice")
		if err == "":
			# Deliberately wrong in memory, and deliberately asymmetric: a `_load`
			# that assigned nothing could not pass this by doing nothing, and one
			# that assigned the same value to both could not pass it either.
			RunConfig.set_mute_music(false)
			RunConfig.mute_sfx = false
			RunConfig.mute_music = true
			# Straight at the owner, deliberately behind RunConfig's back: this is the
			# state the next two assertions are about, and going through the setter
			# would be the very thing they are checking `_load` does not do.
			Sfx.set_muted(false)
			RunConfig._load()
			err = _T.assert_true(RunConfig.mute_sfx, "the cue mute came back muted")
		if err == "":
			err = _T.assert_false(RunConfig.mute_music, "and the bed came back unmuted, not merely 'the same as the other one'")
		if err == "":
			# The half `_load` deliberately does NOT do, for the same reason it does
			# not touch the InputMap: a parser driven over a scratch file must not
			# silence the suite that is driving it.
			err = _T.assert_false(Sfx.is_muted(),
				"_load alone left the live flag where it was -- applying it is a separate call")
		if err == "":
			RunConfig.apply_audio_mutes()
			err = _T.assert_true(Sfx.is_muted(), "apply_audio_mutes is the step that silences the cues")
		if err == "":
			err = _T.assert_false(Music.is_muted(), "and it applied the bed's own flag, not the cue's")
		if err == "":
			# The keyboard's entry point (Game answers M and N with these). It flips
			# what the player currently HEARS, not what the save last recorded, which
			# is what makes a static flag moved behind RunConfig's back self-heal
			# rather than needing two presses to catch up.
			err = _T.assert_false(RunConfig.toggle_mute_sfx(), "one press brings the cues back")
		if err == "":
			err = _T.assert_true(RunConfig.toggle_mute_music(), "and one silences the bed")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH),
				"v%d\n11\n22\nm0\ncb0 sfx0 mus1\n0\n" % RunConfig.SAVE_VERSION,
				"and both presses were written down, which is the whole point of the issue")
		if err == "":
			# Drift, staged deliberately: the live flag says muted, the save says not.
			Sfx.set_muted(true)
			err = _T.assert_false(RunConfig.toggle_mute_sfx(),
				"the toggle reads the live flag, so one press still means 'undo what I hear'")
		return err)


func test_setting_a_mute_to_what_it_already_is_does_not_rewrite_the_save() -> String:
	## Same rule as `set_colorblind_safe`, and the same reason: every write is a
	## rename over the one file in this game holding a number that cannot be
	## re-earned, and the save is not a place to record that someone pressed M twice.
	return _with_scratch_save(5, 6, null, func() -> String:
		RunConfig.set_mute_sfx(true)
		var written: String = FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH)
		var err: String = _T.assert_true(written.contains("\ncb0 sfx1 mus0\n"), "the first set wrote the file")
		if err == "":
			# Move a score under it. A second set that rewrites picks this up; one
			# that no-ops leaves the file exactly as it was.
			RunConfig.campaign_high_score = 999
			err = _T.assert_true(RunConfig.set_mute_sfx(true),
				"setting it to what it already is still reports the state")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH), written,
				"and the file was not touched")
		if err == "":
			# The owner is still set unconditionally, so a static flag moved behind
			# RunConfig's back is resynced rather than left disagreeing with the save.
			Sfx.set_muted(false)
			RunConfig.set_mute_sfx(true)
			err = _T.assert_true(Sfx.is_muted(),
				"a no-op for the save is still a write to the flag the player hears")
		return err)


func test_a_version_five_save_reads_forward_into_version_six() -> String:
	## The migration, and the trap under it. Every v5 field was read behind
	## `version >= SAVE_VERSION`, which meant "only a CURRENT file has milestones" --
	## true while 5 was current, and silent data loss the moment SAVE_VERSION became
	## 6: the milestones and the rebound keys would have been skipped, defaulted, and
	## then written back out empty by this very rewrite. So the assertions that
	## matter here are the two fields v6 did not touch.
	var original: String = "v5\n70\n80\nm1:threat_peak\ncb1\n1\ngarden_pause 4194332\n"
	return _with_scratch_save(0, 0, original, func() -> String:
		RunConfig._load()
		var err: String = _T.assert_eq(RunConfig.load_status, "migrated",
			"a v5 file is read forward, not refused -- one branch wrote it and its shape is unambiguous")
		if err == "":
			err = _T.assert_eq(RunConfig.campaign_high_score, 70, "the campaign score came through")
		if err == "":
			err = _T.assert_eq(RunConfig.endless_high_score, 80, "and the endless one")
		if err == "":
			err = _T.assert_true(RunConfig.has_milestone("threat_peak"),
				"the milestone line was READ, not skipped as 'a field only a v6 file has'")
		if err == "":
			err = _T.assert_eq(RunConfig.key_bindings, {"garden_pause": [4194332]},
				"and so was the binding block under it")
		if err == "":
			err = _T.assert_true(RunConfig.colorblind_safe, "the v5 options line still means colourblind-safe")
		if err == "":
			err = _T.assert_false(RunConfig.mute_sfx,
				"a v5 file has no mute fields, and a player who never had the setting had sound")
		if err == "":
			err = _T.assert_false(RunConfig.mute_music, "both of them")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH),
				"v%d\n70\n80\nm1:threat_peak\ncb1 sfx0 mus0\n1\ngarden_pause 4194332\n" % RunConfig.SAVE_VERSION,
				"and the file is rewritten in the new shape once, keeping everything it carried")
		if err == "":
			# The rewritten file has to be one this build reads back as current,
			# rather than one it migrates again on every launch.
			RunConfig._load()
			err = _T.assert_eq(RunConfig.load_status, "loaded",
				"the migrated file loads as current the next time round")
		return err)


func test_a_v3_save_is_refused_because_two_builds_each_defined_one() -> String:
	## This asserted that a v3 file migrates forward, and it was right about the v3
	## its own branch wrote. It is inverted rather than deleted because the reason
	## is worth pinning: two development branches each minted a `SAVE_VERSION = 3`
	## in parallel — one putting the key bindings on line 4, the other the
	## milestones — so a v3 on disk names two different formats. The parser refuses
	## rather than guessing (see RunConfig.SAVE_VERSION), and `_load` quarantines
	## the file instead of writing over it, which is what keeps this a recoverable
	## situation rather than a destroyed save.
	return _with_scratch_save(0, 0, "v3\n70\n80\nm1:threat_peak\n", func() -> String:
		RunConfig._load()
		var err: String = _T.assert_eq(RunConfig.load_status, "refused",
			"an ambiguous v3 file is refused rather than read as either shape")
		if err == "":
			err = _T.assert_true(RunConfig.has_milestone("threat_peak") == false,
				"and nothing from it is adopted -- a half-read save is the thing "
					+ "_parse_save exists to refuse")
		if err == "":
			# The file itself is still there, untouched, until the next _save moves
			# it aside. That is the difference between refusing and destroying.
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH),
				"v3\n70\n80\nm1:threat_peak\n",
				"the refused file is left exactly as it was found")
		return err)


# -- budget floors ----------------------------------------------------------
#
# Game.BUDGET_FLOOR and the startup warning that reads it. In the economy file
# because that is what a budget is here: a number one part of the game may spend
# out of another part's ceiling, priced once and checked on the way past.
#
# The question these tests settle is not "does a warning appear" but "does it
# appear ONLY when it should". Three of the four declared budgets are already
# `tight` and one is already `spent` on an unmodified build, so a rule that fired
# on either would print four lines on every launch of a project that is behaving
# as designed -- and four warnings that are always there are zero warnings. So the
# first test asserts a real launch of the real scene warns about nothing WHILE at
# least one budget is tight or spent, and the rest stage one budget through its
# floor and assert the other three stay silent.
#
# push_warning() cannot be intercepted from a test, so what is asserted is the
# list Game.check_budgets() warns from. The push is one line over that list; what
# goes in it is the whole feature.


const DEVTOOLS_EXT := "res://devtools_ext/commands.gd"


## A copy of `entry` with its headroom moved to `headroom`, built through the
## same constructor every real measurement goes through.
##
## Deliberately not a hand-written Dictionary literal: a forged entry that had
## drifted from the real shape would let every test below pass against a fiction.
func _budget_with_headroom(entry: Dictionary, headroom: float) -> Dictionary:
	var observations: Array[String] = ["staged by the test"]
	return Game.computed_budget(str(entry["id"]), str(entry["constant"]),
		str(entry["declared_in"]), str(entry["spends"]),
		float(entry["ceiling"]) - headroom, float(entry["ceiling"]), str(entry["units"]),
		str(entry["measured_by"]), str(entry["when_it_runs_out"]), observations)


## The live entries with one id swapped for `replacement`, or dropped entirely
## when `replacement` is empty. Returns [] when the id was not in the list, so
## the caller's vacuity guard is a size check rather than a null check.
func _entries_swapping(entries: Array[Dictionary], id: String,
		replacement: Dictionary) -> Array[Dictionary]:
	var staged: Array[Dictionary] = []
	var found: bool = false
	for entry: Dictionary in entries:
		if str(entry["id"]) != id:
			staged.append(entry)
			continue
		found = true
		if not replacement.is_empty():
			staged.append(replacement)
	if not found:
		return []
	return staged


## One entry out of a list by id, or {} when it is not there.
func _entry_by_id(entries: Array[Dictionary], id: String) -> Dictionary:
	for entry: Dictionary in entries:
		if str(entry["id"]) == id:
			return entry
	return {}


## The noise question, settled by the startup path itself rather than by argument.
##
## The scene is instantiated and nothing else: Game._ready() runs check_budgets()
## on its own, so this is the reading a player's launch produces. Two halves, and
## the second is the one that matters -- zero warnings would prove nothing if
## every budget had room to spare, so the tight-or-spent count is asserted to be
## non-zero in the same run.
func test_a_clean_launch_warns_about_no_budget_at_all() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	var report: Dictionary = game.budget_report
	err = _T.assert_gt(report.size(), 0,
		"Game._ready() ran the startup budget check at all -- an empty report is the check "
			+ "never running, which reads exactly like a clean one")
	if err != "":
		_T.free_ui(game)
		return err
	err = _T.assert_gt(int(report["declared"]), 0, "there are declared floors to grade")
	if err == "":
		err = _T.assert_eq(int(report["declared"]), Game.BUDGET_FLOOR.size(),
			"and the report graded every one of them")
	if err == "":
		# The denominator. "0 warnings" over two of four budgets is the failure
		# this whole check exists against, so a floor whose budget could not be
		# measured must not be able to hide inside a clean verdict.
		err = _T.assert_eq(int(report["measured"]), int(report["declared"]),
			"every declared budget was actually measured: %s" % report["summary"])
	if err != "":
		_T.free_ui(game)
		return err

	var entries: Array[Dictionary] = game.budget_entries(30)
	var near_the_end: int = 0
	for entry: Dictionary in entries:
		if not Game.BUDGET_FLOOR.has(str(entry["id"])):
			continue
		var state: String = str(entry["state"])
		if state == "tight" or state == "spent" or state == Game.BUDGET_SPENT_BY_DESIGN:
			near_the_end += 1
	err = _T.assert_gt(near_the_end, 0,
		"at least one declared budget really is tight or spent on this build -- without that, "
			+ "warning about nothing proves nothing")
	if err == "":
		var warnings: Array = report["warnings"]
		# This assertion is also the carrier: push_warning goes to a log nobody
		# opens, and this line fails a /verify the moment a budget is spent past
		# what BUDGET_FLOOR declares, quoting the warning that says how to accept
		# it. %d budgets being tight or spent alongside it is the point -- those
		# are by design and are deliberately not warnings.
		err = _T.assert_eq(warnings.size(), 0,
			("no declared budget has fallen through its floor (%d of them are tight or spent, "
				+ "which is the designed state and not a warning) -- %s")
					% [near_the_end, warnings])
	_T.free_ui(game)
	return err


## The other half: the rule does fire, and it names one budget.
##
## The husk sweep is staged a whole slip past its floor and the other three are
## left exactly as the running game measured them. One line, about the husk, and
## no mention of the three that were already tight before the test touched
## anything.
## The three-way split `budgets_at_floor()` exists to make, staged one budget at a
## time so each verdict is about a known position rather than about the live board.
##
## Resting ON a floor is not a regression and is not news — it is the state that
## decides whether the next pixel spent anywhere is affordable, and cycle 66 had to
## work it out by comparing seven headrooms to seven floors by hand. The distinction
## that makes it worth its own function: `tight` is a fraction of a budget's own
## CEILING, so hud_message_row reports tight while holding 81 px above its floor.
##
## `budget_regressions()` owns "below". Anything it would warn about is excluded
## here rather than counted twice, so the two can be read side by side without
## double-counting one budget.
func test_a_budget_resting_on_its_floor_is_reported_without_being_a_regression() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var entries: Array[Dictionary] = game.budget_entries(30)
	var err: String = _T.assert_gt(entries.size(), 0, "the run priced its budgets")
	if err == "":
		err = _T.assert_true(Game.BUDGET_FLOOR.has("husk_click"),
			"husk_click has a declared floor to rest on")
	if err != "":
		_T.free_ui(game)
		return err
	var floor_left: float = float(Game.BUDGET_FLOOR["husk_click"])
	var live: Dictionary = _entry_by_id(entries, "husk_click")

	# Exactly on the floor: at_floor reports it, regressions does not.
	var resting: Array[Dictionary] = _entries_swapping(entries, "husk_click",
		_budget_with_headroom(live, floor_left))
	if err == "":
		err = _T.assert_true(Game.budgets_at_floor(resting).has("husk_click"),
			"a budget exactly on its floor is reported as at-floor")
	if err == "":
		err = _T.assert_eq(Game.budget_regressions(resting).size(), 0,
			("and is NOT a regression -- resting on a floor is the declared state, not a "
				+ "fall through it: %s") % [Game.budget_regressions(resting)])

	# Below it: regressions owns that, so at_floor must NOT also claim it.
	var through: Array[Dictionary] = _entries_swapping(entries, "husk_click",
		_budget_with_headroom(live, floor_left - Game.BUDGET_SLIP - 1.0))
	if err == "":
		err = _T.assert_false(Game.budgets_at_floor(through).has("husk_click"),
			("a budget BELOW its floor is not counted as at-floor -- budget_regressions "
				+ "owns that case and counting it twice would overstate both"))
	if err == "":
		err = _T.assert_eq(Game.budget_regressions(through).size(), 1,
			"and is a regression, exactly once")

	# Well clear of it: neither.
	var roomy: Array[Dictionary] = _entries_swapping(entries, "husk_click",
		_budget_with_headroom(live, floor_left + 100.0))
	if err == "":
		err = _T.assert_false(Game.budgets_at_floor(roomy).has("husk_click"),
			"a budget with room is not at-floor")
	if err == "":
		err = _T.assert_eq(Game.budget_regressions(roomy).size(), 0,
			"nor a regression")

	# A budget that is at its floor BY CONSTRUCTION is excluded, because the
	# headline counts that state separately and pest_road_ceiling would otherwise
	# make every reading say "4 of 7" with one entry that can never be anything
	# else. Reading the live verb is what surfaced this; the arithmetic alone was
	# happy to include it.
	if err == "":
		var by_design: Dictionary = _budget_with_headroom(live, floor_left)
		by_design["state"] = Game.BUDGET_SPENT_BY_DESIGN
		var designed: Array[Dictionary] = _entries_swapping(entries, "husk_click", by_design)
		err = _T.assert_false(Game.budgets_at_floor(designed).has("husk_click"),
			("a budget spent by design is not counted as at-floor -- the headline reports "
				+ "that state on its own, and counting it twice buries the ones somebody "
				+ "actually spent"))

	# An UNCOMPUTED budget is never at-floor, whatever its headroom field says.
	# A budget that could not be measured has no headroom to rest on, and
	# budget_regressions calls that "a hole in the check, not a pass" — so
	# counting it here would report the HUD as fuller than anyone has established.
	# Added because a mutation removing the `computed` guard survived without it.
	if err == "":
		var blind: Dictionary = _budget_with_headroom(live, floor_left)
		blind["computed"] = false
		var unmeasured: Array[Dictionary] = _entries_swapping(entries, "husk_click", blind)
		err = _T.assert_false(Game.budgets_at_floor(unmeasured).has("husk_click"),
			("a budget that could not be measured is not resting on its floor -- it is a "
				+ "hole in the check, and reporting it as at-floor would overstate how "
				+ "full the HUD is"))
	_T.free_ui(game)
	return err


func test_a_budget_pushed_through_its_floor_is_the_only_one_warned_about() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null and game.board != null,
		"the main scene loads and brought its board")
	if err != "":
		return err
	var entries: Array[Dictionary] = game.budget_entries(30)
	err = _T.assert_gt(entries.size(), 0, "the run priced its budgets")
	if err == "":
		err = _T.assert_true(Game.BUDGET_FLOOR.has("husk_click"),
			"husk_click has a declared floor to fall through")
	if err != "":
		_T.free_ui(game)
		return err
	var floor_left: float = float(Game.BUDGET_FLOOR["husk_click"])
	var live: Dictionary = _entry_by_id(entries, "husk_click")
	err = _T.assert_gt(live.size(), 0, "and the run reports husk_click")
	if err != "":
		_T.free_ui(game)
		return err
	var spent_further: Dictionary = _budget_with_headroom(live,
		floor_left - Game.BUDGET_SLIP - 1.0)
	var staged: Array[Dictionary] = _entries_swapping(entries, "husk_click", spent_further)
	err = _T.assert_eq(staged.size(), entries.size(),
		"the staged list is the live one with husk_click swapped, nothing else")
	if err != "":
		_T.free_ui(game)
		return err

	var lines: Array[String] = Game.budget_regressions(staged)
	err = _T.assert_eq(lines.size(), 1,
		"spending one budget past its floor warns once, not once per tight budget: %s" % [lines])
	if err != "":
		_T.free_ui(game)
		return err
	var line: String = lines[0]
	err = _T.assert_true(line.contains("husk_click"), "and the line names the budget: %s" % line)
	if err == "":
		err = _T.assert_true(line.contains("CompostMeter.COLLECT_RADIUS"),
			"and the constant whose move spent it: %s" % line)
	if err == "":
		# Without this the reader is told a number is wrong and not how to accept
		# it, which is how a warning becomes permanent furniture.
		err = _T.assert_true(line.contains("BUDGET_FLOOR"),
			"and how to accept the spend if it was intended: %s" % line)
	if err == "":
		for other: String in Game.BUDGET_FLOOR:
			if other == "husk_click":
				continue
			err = _T.assert_false(line.contains(other),
				"and says nothing about %s, which is exactly as tight as it was before" % other)
			if err != "":
				break
	_T.free_ui(game)
	return err


## The direction of the comparison, which is the one bug a staged regression test
## cannot catch on its own: a budget with room left is silence, however tight its
## own `state` label calls it.
func test_a_budget_above_its_floor_stays_silent_however_tight_it_is_called() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	var entries: Array[Dictionary] = game.budget_entries(30)
	err = _T.assert_gt(entries.size(), 0, "the run priced its budgets")
	if err != "":
		_T.free_ui(game)
		return err
	var live: Dictionary = _entry_by_id(entries, "hud_readouts")
	err = _T.assert_gt(live.size(), 0, "the run reports hud_readouts")
	if err != "":
		_T.free_ui(game)
		return err
	# Given back exactly its floor, and given back a hundred pixels more. Neither
	# is a spend, and the first is the boundary the second would never test.
	var floor_left: float = float(Game.BUDGET_FLOOR["hud_readouts"])
	var just_over: Array[Dictionary] = _entries_swapping(entries, "hud_readouts",
		_budget_with_headroom(live, floor_left))
	var far_over: Array[Dictionary] = _entries_swapping(entries, "hud_readouts",
		_budget_with_headroom(live, floor_left + 100.0))
	err = _T.assert_gt(just_over.size(), 0, "hud_readouts was staged at its floor")
	if err == "":
		err = _T.assert_eq(Game.budget_regressions(just_over).size(), 0,
			"a budget sitting exactly on its floor has spent nothing: %s"
				% [Game.budget_regressions(just_over)])
	if err == "":
		err = _T.assert_eq(Game.budget_regressions(far_over).size(), 0,
			"and one with a hundred pixels more is not a regression either: %s"
				% [Game.budget_regressions(far_over)])
	if err == "":
		var staged_state: String = str(_entry_by_id(just_over, "hud_readouts")["state"])
		err = _T.assert_eq(staged_state, "tight",
			"and it is still labelled tight while it goes unwarned -- the two verdicts answer "
				+ "different questions, which is the whole argument for the floor")
	_T.free_ui(game)
	return err


## A declared budget that could not be measured is a hole in the check, and a
## hole reported as a pass is how a check stops working without anyone noticing.
func test_a_declared_budget_that_cannot_be_measured_warns_rather_than_passes() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	var entries: Array[Dictionary] = game.budget_entries(30)
	err = _T.assert_gt(entries.size(), 0, "the run priced its budgets")
	if err != "":
		_T.free_ui(game)
		return err
	var blind: Dictionary = Game.uncomputed_budget(Game.BUDGET_UNMEASURED, "hud_stats_row",
		"Hud.stats_row_budget()", "res://game/hud.gd", "the stats row's contents",
		"staged by the test: no StatsRow to measure",
		"the readouts push the wave button off the right edge of the bar",
		Game.no_budget_observations())
	var staged: Array[Dictionary] = _entries_swapping(entries, "hud_stats_row", blind)
	err = _T.assert_eq(staged.size(), entries.size(), "hud_stats_row was swapped for a blind one")
	if err != "":
		_T.free_ui(game)
		return err
	var lines: Array[String] = Game.budget_regressions(staged)
	err = _T.assert_eq(lines.size(), 1,
		"an unmeasured budget with a floor is worth exactly one line: %s" % [lines])
	if err == "":
		err = _T.assert_true(lines[0].contains("hud_stats_row"),
			"which names it: %s" % lines[0])
	if err == "":
		err = _T.assert_true(lines[0].contains("hole"),
			"and says a budget that cannot be read is not a budget that is fine: %s" % lines[0])
	_T.free_ui(game)
	return err


## A floor guarding a budget that no longer exists is a check that has quietly
## stopped running -- the failure mode of every table of expectations kept beside
## the thing it describes.
func test_a_floor_whose_budget_has_vanished_is_warned_about() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	var entries: Array[Dictionary] = game.budget_entries(30)
	err = _T.assert_gt(entries.size(), 0, "the run priced its budgets")
	if err != "":
		_T.free_ui(game)
		return err
	var without: Array[Dictionary] = _entries_swapping(entries, "pest_road_ceiling", {})
	err = _T.assert_eq(without.size(), entries.size() - 1,
		"pest_road_ceiling was dropped, as a rename or a deletion would drop it")
	if err != "":
		_T.free_ui(game)
		return err
	var lines: Array[String] = Game.budget_regressions(without)
	err = _T.assert_eq(lines.size(), 1, "the orphaned floor is reported once: %s" % [lines])
	if err == "":
		err = _T.assert_true(lines[0].contains("pest_road_ceiling"),
			"and names the floor with nothing behind it: %s" % lines[0])
	_T.free_ui(game)
	return err


## Every floor names a budget the run actually reports, on the real build. The
## test above proves the rule catches an orphaned floor; this one proves there is
## not one sitting in the table right now.
func test_every_declared_floor_names_a_budget_this_run_measures() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	err = _T.assert_gt(Game.BUDGET_FLOOR.size(), 0, "there are floors declared to check")
	if err != "":
		_T.free_ui(game)
		return err
	var entries: Array[Dictionary] = game.budget_entries(30)
	var checked: int = 0
	for id: String in Game.BUDGET_FLOOR:
		var entry: Dictionary = _entry_by_id(entries, id)
		err = _T.assert_gt(entry.size(), 0,
			"the floor declared for '%s' names a budget the run prices" % id)
		if err == "":
			err = _T.assert_true(bool(entry["computed"]),
				"and %s comes back with a number: %s" % [id, entry["summary"]])
		if err == "":
			err = _T.assert_gt(str(entry["units"]).length(), 0,
				"and the units its floor is written in: %s" % [entry])
		if err != "":
			break
		checked += 1
	if err == "":
		err = _T.assert_eq(checked, Game.BUDGET_FLOOR.size(),
			"every declared floor was checked, not an empty table passing quietly")
	_T.free_ui(game)
	return err


## SIMULTANEOUS_PEST_CEILING is spent to the pixel by construction --
## ENDLESS_APHID_SHARE + ENDLESS_BEETLE_SHARE sum to it exactly, which is what
## makes the bound hold without tuning (see wave_director.gd). A plain "spent"
## state would read as a regression on every single glance at the report; this
## pins the distinct one Game.BUDGET_SPENT_BY_DESIGN exists to give it.
##
## The wave that reaches the bound is now the campaign finale rather than an
## endless one: the endless column is paced apart from wave 17 on, so endless
## peaks at 29, and WAVES' last row is sized to land on 40 exactly. That is why
## this still reads zero headroom, and it is a different sentence from the one
## above -- one is the construction, the other is a measurement of a real wave.
func test_the_pest_road_ceiling_reports_spent_by_design_not_a_plain_spent() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	var entries: Array[Dictionary] = game.budget_entries(30)
	var entry: Dictionary = _entry_by_id(entries, "pest_road_ceiling")
	err = _T.assert_gt(entry.size(), 0, "the run reports pest_road_ceiling")
	if err == "":
		err = _T.assert_eq(float(entry["headroom"]), 0.0, "and it really is spent to the pixel")
	if err == "":
		err = _T.assert_eq(str(entry["state"]), Game.BUDGET_SPENT_BY_DESIGN,
			"labelled distinctly from a budget that ran out by accident: %s" % entry["state"])
	if err == "":
		var lines: Array[String] = Game.budget_regressions(entries)
		var mentions_ceiling: bool = false
		for line: String in lines:
			if line.contains("pest_road_ceiling"):
				mentions_ceiling = true
				break
		err = _T.assert_false(mentions_ceiling,
			("and the renamed state still never warns on its own -- BUDGET_FLOOR declares its "
				+ "own floor at exactly 0.0: %s") % [lines])
	_T.free_ui(game)
	return err


## The startup warning and `cmd budgets` are one arithmetic, not two.
##
## The reason the ledger moved onto Game at all. If the verb kept its own copy the
## two would agree on the day they were written and disagree on the day someone
## edited one of them -- and the day that matters is the second one. So the verb's
## reply is compared entry for entry against the run's own pricing, and the husk
## entry against husk_click_margin(), the number its gate fails on.
func test_the_budgets_verb_and_the_startup_check_price_the_same_budgets() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null and game.board != null,
		"the main scene loads and brought its board")
	if err != "":
		return err
	var ext = preload(DEVTOOLS_EXT).new()
	ext._dev = game
	var reply: Dictionary = ext._cmd_budgets({"waves": 30})
	err = _T.assert_true(bool(reply["success"]), "the verb answers: %s" % reply["message"])
	if err != "":
		_T.free_ui(game)
		return err
	var from_verb: Array = reply["data"]["budgets"]
	var from_run: Array[Dictionary] = game.budget_entries(30)
	err = _T.assert_gt(from_run.size(), 0, "the run prices budgets of its own")
	if err == "":
		err = _T.assert_gt(from_verb.size(), from_run.size(),
			"and the verb reports those plus the two it needs a bridge for")
	if err != "":
		_T.free_ui(game)
		return err

	var compared: int = 0
	for entry: Dictionary in from_run:
		var id: String = str(entry["id"])
		var mirror: Dictionary = {}
		for candidate: Dictionary in from_verb:
			if str(candidate["id"]) == id:
				mirror = candidate
				break
		err = _T.assert_gt(mirror.size(), 0, "the verb reports %s too" % id)
		if err == "":
			err = _T.assert_float_eq(float(mirror["headroom"]), float(entry["headroom"]), 0.001,
				"and prices %s identically (%s vs %s)"
					% [id, mirror["headroom"], entry["headroom"]])
		if err == "":
			err = _T.assert_eq(str(mirror["state"]), str(entry["state"]),
				"and grades %s the same way" % id)
		if err != "":
			break
		compared += 1
	if err == "":
		err = _T.assert_eq(compared, from_run.size(),
			"every budget the run prices was compared, not an empty loop passing quietly")
	if err == "":
		var husk: Dictionary = _entry_by_id(from_run, "husk_click")
		err = _T.assert_gt(husk.size(), 0, "the run prices the husk sweep")
		if err == "":
			err = _T.assert_float_eq(float(husk["headroom"]),
				PlacementPreview.husk_click_margin(game.board), 0.001,
				"and it is husk_click_margin() itself, the number the gate fails on")
	if err == "":
		err = _T.assert_eq(int(reply["data"]["under_floor"]), 0,
			"and the verb grades this build against the floors as clean too: %s"
				% [reply["data"]["warnings"]])
	_T.free_ui(game)
	return err


# -- The purse's signals as contracts, not as decoration ---------------------
#
# `suite_reach_check` reported 17 of 24 signals in this game named by no test.
# A signal is the one thing in a Godot project with no compile-time contract at
# all: a wrong argument count fails at emit time, a listener that stopped being
# connected fails silently and forever, and neither is visible to lint. These
# assert what the signal CARRIES and on which paths it fires, because naming it
# would satisfy the checker while proving nothing.


## Every path that moves the purse announces the new total — including refund,
## which is the one that looks like it might not.
##
## `refund()` routes through `add_seeds(amount, false)`, and that `false` exists
## to keep a refund off `seeds_earned_total` (crediting it made uproot a
## repeatable score button). It would be an easy mistake to suppress the signal
## on the same flag, which would leave the HUD showing a stale purse after every
## uproot — visible only by eye, and only if you looked.
func test_every_path_that_moves_the_purse_announces_the_new_total() -> String:
	var bank := SeedBank.new()
	var seen: Array[int] = []
	bank.seeds_changed.connect(func(total: int) -> void: seen.append(total))

	bank.add_seeds(10)
	var err: String = _T.assert_eq(seen.size(), 1, "income announces once")
	if err == "":
		err = _T.assert_eq(seen[seen.size() - 1], bank.seeds,
			"and carries the purse's new total, not the delta")

	if err == "":
		var before_refund: int = seen.size()
		bank.refund(5)
		err = _T.assert_eq(seen.size(), before_refund + 1,
			"a refund announces too — the counts_as_income flag is about the SCORE,"
				+ " and must not be read as 'stay quiet'")
	if err == "":
		err = _T.assert_eq(seen[seen.size() - 1], bank.seeds,
			"and the refund's announcement is also the new total")

	# And the score half of that same call, so the two cannot be conflated later.
	if err == "":
		err = _T.assert_eq(bank.seeds_earned_total, 10,
			"while the refund stayed off the score, which is why the flag exists")

	bank.free()
	return err


## A purchase announces; a refused purchase does not.
##
## The failure direction matters more than the success: an emit on the refusal
## path would drive the HUD to redraw a purse that did not move, and every
## readout would agree with itself while being wrong about whether you paid.
func test_a_refused_purchase_says_nothing_about_the_purse() -> String:
	var bank := SeedBank.new()
	var announced: int = 0
	var refusals: Array[String] = []
	bank.seeds_changed.connect(func(_total: int) -> void: announced += 1)
	bank.purchase_failed.connect(func(reason: String) -> void: refusals.append(reason))

	# Locked by construction: the catalogue says so rather than this test assuming it.
	var locked: Array[StringName] = bank.locked_plants()
	var err: String = _T.assert_gt(locked.size(), 0,
		"some plant starts locked, or the refusal below cannot happen")
	if err != "":
		bank.free()
		return err

	var paid: bool = bank.pay_for_plant(locked[0])
	err = _T.assert_false(paid, "a locked plant cannot be bought")
	if err == "":
		err = _T.assert_eq(announced, 0, "and the purse announced nothing")
	if err == "":
		err = _T.assert_eq(refusals.size(), 1, "while the refusal was announced once")
	if err == "":
		err = _T.assert_true(refusals[0].length() > 0,
			"with a reason a player could read, not an empty string")

	bank.free()
	return err


## `plant_unlocked` carries the plant that was actually unlocked, and fires only
## when one was. A packet that cannot afford itself, or has nothing left to give,
## must not announce an unlock it did not perform.
func test_the_packet_announces_only_the_plant_it_really_unlocked() -> String:
	var bank := SeedBank.new()
	bank.set_seed(12345)
	var unlocked_ids: Array[StringName] = []
	bank.plant_unlocked.connect(func(id: StringName) -> void: unlocked_ids.append(id))

	# Too poor: no unlock, no announcement.
	bank.seeds = 0
	var got: StringName = bank.buy_packet()
	var err: String = _T.assert_eq(String(got), "", "a packet nobody can afford buys nothing")
	if err == "":
		err = _T.assert_eq(unlocked_ids.size(), 0, "and announces nothing")
	if err != "":
		bank.free()
		return err

	# Affordable: exactly one unlock, and the id announced is the id returned.
	bank.seeds = 999
	var before: int = bank.unlocked.size()
	got = bank.buy_packet()
	err = _T.assert_true(String(got) != "", "a packet that can be afforded gives something")
	if err == "":
		err = _T.assert_eq(unlocked_ids.size(), 1, "and announces exactly once")
	if err == "":
		err = _T.assert_eq(unlocked_ids[0], got,
			"and the id announced is the id returned — a listener and a caller"
				+ " reading different plants is the whole failure this guards")
	if err == "":
		err = _T.assert_eq(bank.unlocked.size(), before + 1,
			"and the purse's own list grew by exactly one")
	if err == "":
		err = _T.assert_true(bank.is_unlocked(got),
			"and the announced plant really is unlocked afterwards")

	bank.free()
	return err


# -- Pest.died and Pest.escaped as contracts (plant-tower-defense-1av) -------
#
# The same argument as the purse block above, on the pair that carries the most
# wiring. `Game._on_pest_died` is the funnel every kill routes through: it banks
# the seeds, drops the husk and files the lane loss. `_on_pest_escaped` is its
# counterpart and takes the bed.
#
# Two failure modes neither lint, `name_check` nor `import_check` can see:
#
#   1. The `connect` calls in `Game.spawn_pest` quietly stopping. Every existing
#      test of the escape ledger calls `game._on_pest_escaped(...)` directly (see
#      test_combat._staged_escape_run), so deleting `pest.escaped.connect(...)`
#      leaves the whole suite green and the game unlosable. The tests below drive
#      the signal, never the handler.
#   2. A pest announcing twice, or announcing both. `died` and `escaped` are
#      mutually exclusive per pest and both are followed by `queue_free`, so a
#      second emit is a second payout or a second bed off one bug.
#
# Both signals are also read at the ONE instant they are readable — `_escape()`
# emits and queue_frees on the next line, `kill()` emits and then `_play_death()`
# swaps the sprite — so the payload is asserted from inside the handler.


## Walks `pest` off the end of its own route the way the game does: repeated
## `_physics_process` ticks through `_advance`, not a direct `_escape()` call, so
## the leg-walking and the emit both really run.
##
## Bounded, and it reports the bound rather than hanging or passing quietly. It
## also refuses a pest that was already off the board when it was handed over —
## that would run zero ticks and every assertion after it would be about nothing.
func _walk_until_gone(pest: Pest) -> String:
	if pest == null or not is_instance_valid(pest):
		return "no pest to walk off the road"
	if not pest.is_alive():
		return "the pest was already off the board before the walk began"
	var ticks: int = 0
	while pest.is_alive() and ticks < 400:
		pest._physics_process(1.0)
		ticks += 1
	if pest.is_alive():
		return "still on the road after %d ticks — it never reached the exit" % ticks
	return ""


## A kill announces the pest itself, exactly once, and never announces an escape.
##
## The payload is read from inside the handler because that is where Game reads
## it: `_on_pest_died` takes `position`, `seed_value` and `husk_multiplier()` off
## this argument, and `_play_death()` runs the moment the emit returns.
##
## The negative half is the valuable one. `escaped` firing here would take a bed
## for a pest the player just killed — the run would end while the garden was
## winning, and nothing in the code would look wrong.
func test_a_kill_announces_the_pest_itself_and_never_an_escape() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	# A beetle: 9 seeds and a husk worth 5, both distinct from the aphid's, so a
	# payout credited from the wrong pest does not happen to match.
	var victim: Pest = _spawn_and_take(game, Pest.BEETLE)
	var err: String = _T.assert_true(victim != null, "a pest is on the board to kill")
	if err != "":
		_T.free_ui(game)
		return err

	var victim_id: int = victim.get_instance_id()
	var died_ids: Array[int] = []
	var escaped_ids: Array[int] = []
	var seed_value_at_emit: Array[int] = []
	var alive_at_emit: Array[bool] = []
	# Three separate listeners, all single-expression, all null-tolerant: a
	# dereference of a null payload would raise, and a raise inside a test method
	# aborts it and returns "", which the runner cannot tell from a pass. The
	# sentinels (-1, 0) fail an assertion instead.
	victim.died.connect(func(p: Pest) -> void:
		died_ids.append(0 if p == null else p.get_instance_id()))
	victim.died.connect(func(p: Pest) -> void:
		seed_value_at_emit.append(-1 if p == null else p.seed_value))
	victim.died.connect(func(p: Pest) -> void:
		alive_at_emit.append(p != null and p.is_alive()))
	victim.escaped.connect(func(p: Pest) -> void:
		escaped_ids.append(0 if p == null else p.get_instance_id()))

	var lives_before: int = game.lives
	var seeds_before: int = game.bank.seeds
	var husks_before: int = game.compost.husk_count()
	var defeated_before: int = game.pests_defeated
	var expected_seeds: int = victim.seed_value

	victim.take_damage(victim.max_health + 1.0)

	err = _T.assert_eq(died_ids.size(), 1, "a lethal hit announces the death exactly once")
	if err == "":
		err = _T.assert_eq(died_ids[0], victim_id,
			"and hands over the pest that died itself — Game._on_pest_died reads"
				+ " position, seed_value and husk_multiplier() off this argument,"
				+ " so the wrong instance pays the wrong seeds at the wrong cell")
	if err == "":
		err = _T.assert_eq(seed_value_at_emit.size(), 1,
			"the payload was dereferenceable inside the handler")
	if err == "":
		err = _T.assert_eq(seed_value_at_emit[0], expected_seeds,
			"and still carried its species' seed value at the instant of the emit,"
				+ " which is the only instant Game gets to read it")
	if err == "":
		err = _T.assert_eq(alive_at_emit.size(), 1, "and its liveness was readable too")
	if err == "":
		err = _T.assert_false(alive_at_emit[0],
			"reading FALSE: kill() drops `_alive` before it emits, which is what makes"
				+ " a re-entrant kill() from inside a listener a no-op rather than a loop")
	if err == "":
		err = _T.assert_eq(escaped_ids.size(), 0,
			"and nothing announced an escape: died and escaped are mutually exclusive,"
				+ " and a pest firing both would pay its seeds AND cost a bed")

	# Game's half of the same wire. If `pest.died.connect(_on_pest_died)` were
	# deleted from spawn_pest, every assertion above still holds and every one
	# below fails — which is the point of asserting both.
	if err == "":
		err = _T.assert_eq(game.pests_defeated, defeated_before + 1,
			"the kill reached Game's funnel, so spawn_pest's connection is live")
	if err == "":
		err = _T.assert_eq(game.bank.seeds, seeds_before + expected_seeds,
			"and banked exactly this pest's seed value, once")
	if err == "":
		err = _T.assert_eq(game.compost.husk_count(), husks_before + 1,
			"and dropped exactly one husk")
	if err == "":
		err = _T.assert_eq(game.lives, lives_before,
			"while costing no bed — a kill that also took a life would end a run"
				+ " the player was winning")

	# A corpse cannot die again, by either route into kill().
	if err == "":
		victim.take_damage(victim.max_health + 1.0)
		victim.kill()
		err = _T.assert_eq(died_ids.size(), 1,
			"a second lethal hit and an explicit second kill() are both silent")
	if err == "":
		err = _T.assert_eq(game.bank.seeds, seeds_before + expected_seeds,
			"so the seeds were banked once, not three times")
	if err == "":
		err = _T.assert_eq(game.compost.husk_count(), husks_before + 1,
			"and one husk landed, not three")
	if err == "":
		err = _T.assert_eq(escaped_ids.size(), 0, "and it still never escaped")

	_T.free_ui(game)
	return err


## An escape announces the pest itself, exactly once, and never a death.
##
## Driven by walking the road, not by calling `_escape()` or `_on_pest_escaped`:
## the connection made in `Game.spawn_pest` is half of what is under test, and a
## handler called directly proves nothing about it.
##
## The negatives here are the whole economy. An escape that also paid seeds or
## dropped a husk would make ignoring a lane profitable; an escape that also
## counted as a kill would make the post-mortem's "defeated" a lie.
func test_a_pest_that_walks_the_whole_road_announces_an_escape_and_never_a_death() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game._on_wave_started(1)
	var runner: Pest = _spawn_and_take(game, Pest.APHID)
	var err: String = _T.assert_true(runner != null, "a pest is on the road to lose")
	if err != "":
		_T.free_ui(game)
		return err

	var runner_id: int = runner.get_instance_id()
	var escaped_ids: Array[int] = []
	var died_ids: Array[int] = []
	var engaged_at_emit: Array[bool] = []
	# `was_engaged()` is read inside the handler because that is the last moment
	# it can be read at all: _escape() emits and queue_frees on the next line, so
	# Game._note_escape's read is not merely early, it is the only read there is.
	runner.escaped.connect(func(p: Pest) -> void:
		escaped_ids.append(0 if p == null else p.get_instance_id()))
	runner.escaped.connect(func(p: Pest) -> void:
		engaged_at_emit.append(p != null and p.was_engaged()))
	runner.died.connect(func(p: Pest) -> void:
		died_ids.append(0 if p == null else p.get_instance_id()))

	var lives_before: int = game.lives
	var seeds_before: int = game.bank.seeds
	var earned_before: int = game.bank.seeds_earned_total
	var husks_before: int = game.compost.husk_count()
	var defeated_before: int = game.pests_defeated

	err = _walk_until_gone(runner)
	if err == "":
		err = _T.assert_eq(escaped_ids.size(), 1,
			"reaching the end of the route announces the escape exactly once")
	if err == "":
		err = _T.assert_eq(escaped_ids[0], runner_id,
			"and hands over the pest that escaped itself")
	if err == "":
		err = _T.assert_eq(died_ids.size(), 0,
			"and never announces a death for the same bug")
	if err == "":
		err = _T.assert_eq(engaged_at_emit.size(), 1,
			"the payload answered was_engaged() inside the handler")
	if err == "":
		err = _T.assert_false(engaged_at_emit[0],
			"reporting an unopposed walk as untouched — nothing in this empty"
				+ " garden ever laid a finger on it")

	# Game's half.
	if err == "":
		err = _T.assert_eq(game.lives, lives_before - 1,
			"the escape cost exactly one bed, so spawn_pest's connection is live")
	if err == "":
		err = _T.assert_eq(game.bank.seeds, seeds_before,
			"while paying no seeds — an escape that paid would make leaking a lane"
				+ " a way to earn")
	if err == "":
		err = _T.assert_eq(game.bank.seeds_earned_total, earned_before,
			"and scoring none either")
	if err == "":
		err = _T.assert_eq(game.compost.husk_count(), husks_before,
			"and dropping no husk: there is no corpse past the exit to sweep")
	if err == "":
		err = _T.assert_eq(game.pests_defeated, defeated_before,
			"and counting nothing as defeated")

	# Walking on past the exit is silent...
	if err == "":
		runner._physics_process(10.0)
		err = _T.assert_eq(escaped_ids.size(), 1,
			"a pest already past the exit cannot escape twice — a second emit is a"
				+ " second bed off one bug")
	# ...and so is a kernel that lands in the frame it walked out in, which is the
	# one way `died` could still fire for a pest that has already escaped.
	if err == "":
		runner.take_damage(9999.0)
		err = _T.assert_eq(died_ids.size(), 0,
			"and a hit landing after the escape kills nothing: `_alive` is already down")
	if err == "":
		err = _T.assert_eq(game.bank.seeds, seeds_before,
			"so the pest that cost a bed never also paid out")
	if err == "":
		err = _T.assert_eq(game.lives, lives_before - 1,
			"and the bed count moved exactly once")

	_T.free_ui(game)
	return err


## The re-entrancy guarantee under "exactly once".
##
## `kill()` sets `_alive = false` BEFORE it emits, so a listener that reaches back
## for the pest it was just handed gets a no-op instead of a recursion. Worth
## pinning separately from the two calls in the test above, because that pair
## tests the guard across calls and this tests it inside one emit — and it is the
## inner one that would double-bank without ever looking like a second kill.
func test_a_listener_killing_the_pest_again_does_not_bank_it_twice() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var victim: Pest = _spawn_and_take(game, Pest.BEETLE)
	var err: String = _T.assert_true(victim != null, "a pest is on the board to kill")
	if err != "":
		_T.free_ui(game)
		return err

	var announcements: Array[int] = []
	victim.died.connect(func(_p: Pest) -> void: announcements.append(1))
	# The accident a listener is most likely to have: acting on the pest it was
	# handed. Connected after the counter so the count is taken before the
	# re-entry, and after Game's own handler so Game has already paid out once.
	victim.died.connect(func(p: Pest) -> void:
		if p != null and is_instance_valid(p):
			p.kill())

	var seeds_before: int = game.bank.seeds
	var husks_before: int = game.compost.husk_count()
	var defeated_before: int = game.pests_defeated
	var expected_seeds: int = victim.seed_value

	victim.take_damage(victim.max_health + 1.0)

	err = _T.assert_eq(announcements.size(), 1,
		"a listener calling kill() re-entrantly gets no second announcement")
	if err == "":
		err = _T.assert_eq(game.pests_defeated, defeated_before + 1,
			"so the kill is counted once")
	if err == "":
		err = _T.assert_eq(game.bank.seeds, seeds_before + expected_seeds,
			"the seeds are banked once")
	if err == "":
		err = _T.assert_eq(game.compost.husk_count(), husks_before + 1,
			"and one husk lands, not one per listener")

	_T.free_ui(game)
	return err


## The ORDER of `escaped`'s handler against Game's own bookkeeping.
##
## `_on_pest_escaped` files `_note_escape(pest)` before it touches `lives`, and
## the comment there says why: losing the last bed calls `_end_run` on the next
## few lines, and `_end_run` builds the card out of `summary_stats()`. A read
## filed after the arithmetic would be missing from the run that ended on it —
## the tenth escape would be the one escape the post-mortem never heard about.
##
## The assertion is deliberately against `_summary._stats`, the dictionary the
## card was BUILT with, not against `summary_stats()` called again afterwards.
## Re-asking would pass either way, because by then the counter has caught up.
##
## Every bed goes through a real pest walking a real road: the beds row computes
## `LIVES - lives`, so forcing `lives` would desynchronise it from the escape
## tally that is the actual subject here.
func test_the_last_escape_is_in_the_card_that_same_escape_builds() -> String:
	# _end_run banks the run against RunConfig's persisted record. Point that at
	# the scratch save; teardown() restores it even if this method aborts.
	_stash_run_config()
	RunConfig.save_path = HIGHSCORE_TEST_PATH
	RunConfig.endless = false

	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_eq(game.lives, Game.LIVES,
		"the run starts with a whole garden, so LIVES escapes is exactly what ends it")
	if err != "":
		_T.free_ui(game)
		_restore_run_config()
		return err
	game._on_wave_started(1)

	var walked: int = 0
	var fought_one: bool = false
	for i: int in range(Game.LIVES):
		var bug: Pest = _spawn_and_take(game, Pest.APHID)
		if bug == null:
			err = "only %d of %d pests made it onto the road" % [walked, Game.LIVES]
			break
		if i == 0:
			# Half a kernel: the garden reached this one, and an aphid walks on.
			# Scaled off its own max_health so endless health scaling cannot make
			# a fixed number lethal and turn this escape into a kill.
			bug.take_damage(bug.max_health * 0.1)
			if not bug.is_alive():
				err = "the token hit killed the pest — it can no longer escape"
				break
			fought_one = true
		err = _walk_until_gone(bug)
		if err != "":
			break
		walked += 1

	if err == "":
		err = _T.assert_eq(walked, Game.LIVES,
			"every bed was lost to a pest that really walked out")
	if err == "":
		err = _T.assert_true(fought_one, "and exactly one of them had been shot at")
	if err == "":
		err = _T.assert_eq(game.lives, 0, "the garden is gone")
	if err == "":
		err = _T.assert_true(game.game_over, "and the run ended on that last escape")
	if err == "":
		err = _T.assert_true(game._summary != null and is_instance_valid(game._summary),
			"which built the post-mortem card in the same call")

	if err == "":
		var built: Dictionary = game._summary._stats
		err = _T.assert_eq(int(built.get("escapes_recorded", -1)), Game.LIVES,
			"all %d escapes are in the card the %dth escape itself built — _note_escape"
				% [Game.LIVES, Game.LIVES]
				+ " runs before the lives arithmetic precisely so the last one makes it")
	if err == "":
		err = _T.assert_eq(int(game._summary._stats.get("escapes_untouched", -1)),
			Game.LIVES - 1,
			"and the one that was shot at is not among the untouched, so the split is"
				+ " read off each emitted pest's own was_engaged()")
	if err == "":
		err = _T.assert_eq(int(game._summary._stats.get("lives_lost", -1)), Game.LIVES,
			"beds lost agrees with escapes recorded — that is the pair that would"
				+ " disagree by one if the read were filed after the arithmetic")
	if err == "":
		err = _T.assert_eq(game._summary.beds_text(),
			"%d of %d beds — %d walked in untouched" % [Game.LIVES, Game.LIVES, Game.LIVES - 1],
			"and the row the player reads says so")

	_T.free_ui(game)
	_restore_run_config()
	return err


## An upgrade is money the player does not get back, and now the prompt says so
## (plant-tower-defense-s40d).
##
## Two claims, and the second is the one that rots. The message quotes a number, so
## `upgrade_spend` has to be right; but the message also ASSERTS an economic rule —
## that the refund ignores upgrades — and if `uproot_refund()` ever starts paying them
## the sentence becomes a lie that no test about strings would catch. So the rule is
## pinned here, next to the sentence that depends on it.
func test_an_upgrade_is_not_refunded_and_the_prompt_says_the_number() -> String:
	# Derived, not typed: the ladder is 20 then 45 today and this reads it.
	var expected_at_top: int = 0
	for i: int in range(CornCobbler.LEVELS.size() - 1):
		expected_at_top += int(CornCobbler.LEVELS[i]["upgrade_cost"])
	var err: String = _T.assert_eq(CornCobbler.upgrade_spend(CornCobbler.LEVELS.size()),
		expected_at_top, "the top of the ladder has the whole ladder's cost behind it")
	if err == "":
		err = _T.assert_eq(CornCobbler.upgrade_spend(1), 0,
			"and a fresh plant has forfeited nothing")
	if err == "":
		err = _T.assert_gt(expected_at_top, 0,
			"the ladder costs something, or this whole message is about zero seeds")
	if err == "":
		# The economic claim the sentence makes. Same kind, same health, different
		# level: the refund must not move, or the prompt is telling the player
		# something false.
		var game := await _T.instantiate_scene(GAME_SCENE) as Game
		game.bank.add_seeds(300)
		# Found rather than assumed: the road's shape has been reshaped twice and a
		# hard-coded pair of cells is a test that fails for the wrong reason.
		var planted: Array[Vector2i] = []
		for y: int in range(Board.ROWS):
			for x: int in range(Board.COLS):
				if planted.size() >= 2:
					break
				if game.place_plant(PlantCatalog.CORN, Vector2i(x, y)) == "":
					planted.append(Vector2i(x, y))
		if planted.size() == 2:
			var fresh: Plant = game.plant_at(planted[0])
			var cob := game.plant_at(planted[1]) as CornCobbler
			if cob != null and cob.upgrade():
				err = _T.assert_eq(cob.level, 2, "the second cob really did upgrade")
				if err == "":
					err = _T.assert_eq(cob.uproot_refund(), fresh.uproot_refund(),
						("an upgraded cob refunds exactly what a fresh one does -- if this "
							+ "ever stops being true, uproot_armed_message is lying"))
				if err == "":
					var line: String = Hud.uproot_armed_message("Corn Cobbler", false,
						CornCobbler.upgrade_spend(cob.level))
					err = _T.assert_true(line.contains("%d upgrade seeds" % int(CornCobbler.LEVELS[0]["upgrade_cost"])),
						"and the prompt quotes what was actually spent -- got %s" % line)
			else:
				err = "could not upgrade the second cob"
		else:
			err = "could not plant two cobs"
		_T.free_ui(game)
	if err == "":
		# The two extras never share the row. The budget refused that build at 188 px
		# over, so this is a constraint rather than a preference.
		var both: String = Hud.uproot_armed_message("Bomb Dandelion", true, 65)
		err = _T.assert_false(both.contains("Hover to compare"),
			"the forfeit clause displaces the move tip rather than joining it -- got %s" % both)
	return err
