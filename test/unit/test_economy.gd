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
		err = _T.assert_eq(button.text, Hud.uproot_button_text(
				game.selected_placed.uproot_refund(),
				game.bank.placement_cost(game.selected_placed.kind)),
			("the resting label prints the live refund AND the net of the trade"
				+ " (plant-tower-defense-eupm), got %s") % button.text)
	if err == "":
		var before: String = button.text
		game.selected_placed.take_damage(Plant.MAX_HEALTH - 1.0)
		game._process(0.016)
		err = _T.assert_true(button.text != before,
			"a chewed plant reprices its own uproot button, still says %s" % button.text)
		if err == "":
			err = _T.assert_eq(button.text, Hud.uproot_button_text(
					game.selected_placed.uproot_refund(),
					game.bank.placement_cost(game.selected_placed.kind)),
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
	# The seventh, added to the options line at v7, and it leaks the same way the two
	# mutes do and then some: RunConfig loads it from the developer's own save at
	# startup, so a maintainer who plays at 2x would read `spd1` in every byte-exact
	# assertion below without ever having mentioned speed.
	RunConfig.game_speed_step = 0
	# The eighth and ninth, added to the preferences line at v8, and they leak exactly
	# the way the mutes and the speed do: RunConfig loads them from the developer's own
	# save at startup, so a maintainer who plays with the music turned down would read
	# `mvol2` in every byte-exact assertion below without ever having mentioned volume.
	RunConfig.sfx_level = 0
	RunConfig.music_level = 0
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
		# THE PICKED PROFILE, and the dictionary of records keyed by it
		# (plant-tower-defense-1hgx). `best_for()` reads `difficulty` when a caller does
		# not name one, so a test that leaves this on gentle changes what EVERY later
		# test's `best_for()` answers -- which is how the per-difficulty test broke nine
		# of its neighbours the first time it ran. Duplicated for the same reason
		# `earned_milestones` is: `record_score` mutates it in place.
		"difficulty": RunConfig.difficulty,
		"difficulty_high_scores": RunConfig.difficulty_high_scores.duplicate(),
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
		# The garden speed, both halves, exactly like the mutes above -- RunConfig's
		# persisted index and the engine clock `apply_game_speed` pushes it into. The
		# engine half is the one that matters most in this whole dictionary:
		# `Engine.time_scale` is PROCESS-GLOBAL, so a test that leaked ½x would not
		# fail here, it would slow every timing-sensitive test in every LATER script.
		"game_speed_step": RunConfig.game_speed_step,
		"engine_time_scale": Engine.time_scale,
		"game_speed_chosen_step": GameSpeed.step(),
		# The two audio levels, both halves each, exactly like the mutes -- RunConfig's
		# persisted index and the mixer `apply_audio_levels` pushes it into. The mixer
		# half is `AudioServer` bus volume, which is PROCESS-GLOBAL in the same way
		# `Engine.time_scale` is: a leaked 25% would not fail here, it would sit under
		# every later script in the run.
		"sfx_level": RunConfig.sfx_level,
		"music_level": RunConfig.music_level,
		"sfx_bus_level": Sfx.level(),
		"music_bus_level": Music.level(),
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
	RunConfig.difficulty = StringName(_stashed_run_config["difficulty"])
	RunConfig.difficulty_high_scores = (
		_stashed_run_config["difficulty_high_scores"] as Dictionary).duplicate()
	RunConfig.fresh_record = bool(_stashed_run_config["fresh_record"])
	RunConfig.load_status = str(_stashed_run_config["load_status"])
	RunConfig.key_bindings = _stashed_run_config["key_bindings"] as Dictionary
	RunConfig.earned_milestones = (_stashed_run_config["earned_milestones"] as Dictionary).duplicate()
	RunConfig.colorblind_safe = bool(_stashed_run_config["colorblind_safe"])
	RunConfig.mute_sfx = bool(_stashed_run_config["mute_sfx"])
	RunConfig.mute_music = bool(_stashed_run_config["mute_music"])
	Sfx.set_muted(bool(_stashed_run_config["sfx_is_muted"]))
	Music.set_muted(bool(_stashed_run_config["music_is_muted"]))
	RunConfig.game_speed_step = int(_stashed_run_config["game_speed_step"])
	RunConfig.sfx_level = int(_stashed_run_config["sfx_level"])
	RunConfig.music_level = int(_stashed_run_config["music_level"])
	# Through the setters, so the BUS goes back and not just the remembered index --
	# the bus is the process-global half and the only one a later script can trip over.
	Sfx.set_level(int(_stashed_run_config["sfx_bus_level"]))
	Music.set_level(int(_stashed_run_config["music_bus_level"]))
	# `reset()` FIRST, and it is doing real work: it is the only thing that clears
	# `GameSpeed._held_step`, so a body that returned early while held would otherwise
	# leave the whole rest of the run parked -- and `set_step` on a held table moves
	# the parked choice instead of the engine, so the restore would silently no-op.
	# Then the engine is put back outright, because the two readings were taken
	# separately and only the recorded one is the truth.
	GameSpeed.reset()
	GameSpeed.set_step(int(_stashed_run_config["game_speed_chosen_step"]))
	Engine.time_scale = float(_stashed_run_config["engine_time_scale"])
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


## A HEADLESS PROCESS NEVER WRITES THE PLAYER'S SAVE (plant-tower-defense-58u7).
##
## Every test in this file redirects `RunConfig.save_path` in its setup. None of that
## helps with the defect this guards: `RunConfig` is an AUTOLOAD, its `_ready()` runs at
## PROCESS START, and `_load()` migrates an old format and writes it back — all before the
## runner has called any `setup()`. The first `run_tests.py` after the v6 -> v7 bump
## rewrote the developer's real `user://highscore.save`, and it was found by reading the
## file afterwards rather than by any gate. `save_persist_check.py` was clean throughout,
## correctly: it asks whether a test FUNCTION reaches `_save()`, and there is no test
## function anywhere in that chain.
##
## ASSERTED ON THE PURE FUNCTION, plus the live autoload's own resolved path. The pure
## half pins the rule; the live half is what would catch `_ready()` being reordered so the
## redirect lands after `_load()`, which is the mistake that recreates the bug exactly.
##
## The rule is HEADLESS, not "under test", and that is deliberate: a bare
## `godot --headless --script res://tools/lint_project.gd` is documented in `CLAUDE.md`
## and brings this autoload up too, so a rule keyed on the unit runner would have left the
## linter exposed. Every headless entry point here is a tool; `capture.gd` refuses to run
## headless at all because there is no renderer, and a player's process always has one.
func test_a_headless_process_never_writes_the_players_save() -> String:
	# The live autoload, first: this is the assertion that fails if `_ready()` is
	# reordered so the redirect lands after `_load()`.
	# `RunConfig.loaded_from` AND NOT `RunConfig.save_path`, and the difference is the
	# whole assertion. Both orders of `_ready()` leave `save_path` pointing at the scratch
	# file by the time a test can read it, so `save_path` cannot tell "redirected, then
	# loaded" from "loaded the real save, then redirected" — the second being exactly the
	# bug. Mutating the order and watching this test still pass is how that was found.
	# `boot_loaded_from` is captured once in `_ready()`, so no later test can erase it.
	var err: String = _T.assert_true(RunConfig.boot_loaded_from != RunConfig.SAVE_PATH,
		("this process is headless and boot loaded %s, which is the player's real save. "
			+ "_ready() must resolve the path BEFORE _load(), because _load() migrates an "
			+ "old format and writes it back") % RunConfig.boot_loaded_from)
	if err == "":
		err = _T.assert_eq(RunConfig.resolved_save_path("", "headless"),
			RunConfig.HEADLESS_SAVE_PATH,
			"a headless process with no override goes to the scratch file")
	if err == "":
		err = _T.assert_eq(RunConfig.resolved_save_path("", "windows"),
			RunConfig.SAVE_PATH,
			"and a process with a real display gets the player's save, or the game "
				+ "would never load it")
	if err == "":
		# An explicit path beats both, because a caller that named one has said what it
		# wants. This is the seam `--isolated` runs and any future per-run redirect need.
		err = _T.assert_eq(
			RunConfig.resolved_save_path("user://named.save", "headless"),
			"user://named.save",
			"an explicit PLANT_TD_SAVE_PATH wins over the headless default")
	if err == "":
		err = _T.assert_eq(
			RunConfig.resolved_save_path("user://named.save", "windows"),
			"user://named.save", "and over the player's save too")
	if err == "":
		# `OS.get_environment` returns "" for a variable that does not exist, so empty
		# MUST mean unset rather than "a file called nothing".
		err = _T.assert_eq(RunConfig.resolved_save_path("", "headless"),
			RunConfig.HEADLESS_SAVE_PATH,
			"an unset variable reads as \"\" and must not be treated as a path")
	if err == "":
		err = _T.assert_true(RunConfig.HEADLESS_SAVE_PATH != RunConfig.SAVE_PATH,
			"the scratch file is a different file from the player's, which is the whole "
				+ "point and would be a silent no-op if the two constants converged")
	# THE TWO FIELDS DO DIFFERENT JOBS, and this is what says so. `loaded_from` follows
	# every load; `boot_loaded_from` is frozen at process start. Collapsing them into one
	# field is the tempting simplification, and it would make the assertion above pass
	# vacuously the moment any earlier test drove a load over its own scratch path -- which
	# is precisely the fragility this pair was split to remove.
	if err == "":
		var scratch: String = "user://loaded_from_probe.save"
		var boot_before: String = RunConfig.boot_loaded_from
		var was: String = RunConfig.save_path
		RunConfig.save_path = scratch
		RunConfig._load()
		RunConfig.save_path = was
		err = _T.assert_eq(RunConfig.loaded_from, scratch,
			"loaded_from follows the load that just happened")
		if err == "":
			err = _T.assert_eq(RunConfig.boot_loaded_from, boot_before,
				("boot_loaded_from did NOT move, which is the only reason the guard above "
					+ "cannot be made vacuous by a neighbouring test"))
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


## THE RECORD KNOWS WHICH DIFFICULTY EARNED IT (plant-tower-defense-1hgx).
##
## The dishonesty this closes, stated as the test that would have failed: a 5008 set on
## Gentle (15 lives, 26s of prep, 40 seeds) and a 5008 set on Harsh (5, 9.0, 15) were the
## same number in the same slot, so **beating your own record by picking an easier setting
## was indistinguishable from beating it by playing better**. That is a correctness
## question about the score, not a presentation question about a label.
##
## Both directions, because they fail differently. A Harsh run must not be judged against
## a Gentle record (it would almost never be a "record" and the player would stop seeing
## the message), and a Gentle run must not overwrite a Harsh one (the harder number is the
## one worth keeping).
func test_a_record_is_kept_per_difficulty_and_not_shared() -> String:
	return _with_scratch_save(0, 0, null, func() -> String:
		RunConfig.endless = false
		RunConfig.difficulty = Game.DIFFICULTY_GENTLE
		var err: String = _T.assert_true(RunConfig.record_score(5000),
			"a first run on gentle sets a record")
		if err == "":
			err = _T.assert_eq(RunConfig.best_for(false, Game.DIFFICULTY_GENTLE), 5000,
				"and the record is filed against gentle")
		if err == "":
			# THE assertion. The standard slot is where every pre-v9 score lived, and a
			# gentle run reaching it is the whole defect.
			err = _T.assert_eq(RunConfig.best_for(false, Game.DIFFICULTY_STANDARD), 0,
				"and standard's record is untouched -- a gentle run must not set it")
		if err == "":
			RunConfig.difficulty = Game.DIFFICULTY_HARSH
			err = _T.assert_true(RunConfig.record_score(400),
				("400 on harsh IS a record, even though it is far under gentle's 5000 -- "
					+ "judging it against gentle is how a harder run stops counting"))
		if err == "":
			err = _T.assert_eq(RunConfig.best_for(false, Game.DIFFICULTY_GENTLE), 5000,
				"and gentle's record did not move")
		if err == "":
			RunConfig.difficulty = Game.DIFFICULTY_GENTLE
			err = _T.assert_false(RunConfig.record_score(4999),
				"a worse gentle run still does not overwrite gentle's own record")
		return err)


## The v9 line's own grammar, including the case that makes the count worth writing.
func test_the_difficulty_score_line_round_trips_and_refuses_a_bad_count() -> String:
	var line: String = RunConfig.compose_difficulty_line(
		{"campaign:harsh": 400, "campaign:gentle": 5000, "endless:harsh": 0})
	# Sorted, and the zero dropped: a record of nothing is the absence of a record, and
	# sorting is what makes two saves holding the same records byte-identical.
	var err: String = _T.assert_eq(line, "d2 campaign:gentle=5000 campaign:harsh=400",
		"the line is count-prefixed, sorted, and drops the slot with no record in it")
	if err == "":
		var back: Variant = RunConfig.parse_difficulty_line(line)
		err = _T.assert_true(back != null, "and it reads back")
		if err == "":
			var got: Dictionary = back as Dictionary
			err = _T.assert_eq(int(got.get("campaign:gentle", -1)), 5000,
				"with the value it went in with")
	if err == "":
		err = _T.assert_eq(RunConfig.compose_difficulty_line({}), "d0",
			"a player who has only ever played standard writes d0, not an empty line -- "
				+ "an empty line is indistinguishable from a truncation")
	if err == "":
		var empty: Variant = RunConfig.parse_difficulty_line("d0")
		err = _T.assert_true(empty != null and (empty as Dictionary).is_empty(),
			"and d0 reads back as no records rather than as a refusal")
	if err == "":
		# THE REASON THE COUNT IS WRITTEN AT ALL. A line cut after its first field is
		# otherwise a valid line describing fewer records.
		err = _T.assert_true(
			RunConfig.parse_difficulty_line("d2 campaign:gentle=5000") == null,
			"a count that disagrees with the fields is refused, not tolerated")
	if err == "":
		err = _T.assert_true(RunConfig.parse_difficulty_line("d1 campaign:gentle=x") == null,
			"and a value that is not a score is refused")
	# THE KEY IS THE SAVE'S FIELD NAME, so changing its shape silently orphans every
	# record already on disk -- the stored line would still parse and would simply describe
	# slots nothing reads. Pinned as a literal for that reason: an assertion written as
	# `score_key(...) == score_key(...)` would move with the function and never disagree.
	if err == "":
		err = _T.assert_eq(RunConfig.score_key(true, Game.DIFFICULTY_HARSH),
			"endless:harsh", "the key is mode:difficulty, which is what the save writes")
	if err == "":
		err = _T.assert_eq(RunConfig.score_key(false, Game.DIFFICULTY_GENTLE),
			"campaign:gentle", "and campaign is the other mode's word")
	return err


## A v8 SAVE MIGRATES BY GAINING A MEANING, NOT BY MOVING A BYTE
## (plant-tower-defense-1hgx).
##
## Before v9, lines 2 and 3 were "the campaign best" and "the endless best" with no idea
## which profile was played. From v9 they are STANDARD's records specifically. Standard is
## what the game shipped as and what the picker defaults to, so those runs were almost
## certainly played on it — and attributing them anywhere else would be inventing a fact.
##
## So this test's real claim is that the numbers do not move and the other profiles start
## empty, which is the migration being correct rather than absent.
func test_a_version_eight_save_reads_its_scores_as_standards() -> String:
	var v8: String = "v8\n4138\n5008\nm0\ncb0 sfx0 mus0 spd0 svol0 mvol0\n0\n"
	return _with_scratch_save(0, 0, v8, func() -> String:
		RunConfig._load()
		var err: String = _T.assert_eq(RunConfig.load_status, "migrated",
			"a v8 file is migrated rather than refused")
		if err == "":
			err = _T.assert_eq(RunConfig.best_for(false, Game.DIFFICULTY_STANDARD), 4138,
				"its campaign number is standard's campaign record")
		if err == "":
			err = _T.assert_eq(RunConfig.best_for(true, Game.DIFFICULTY_STANDARD), 5008,
				"and its endless number is standard's endless record")
		if err == "":
			err = _T.assert_eq(RunConfig.best_for(false, Game.DIFFICULTY_HARSH), 0,
				("and harsh starts empty -- a player who never played it has no record "
					+ "there, and copying standard's in would be inventing one"))
		if err == "":
			# The rewrite the migration performs must be readable by this build, or the
			# next launch refuses the file the migration just wrote.
			RunConfig._save()
			RunConfig._load()
			err = _T.assert_eq(RunConfig.load_status, "loaded",
				"and the file the migration wrote reads back as current")
		if err == "":
			err = _T.assert_eq(RunConfig.best_for(false, Game.DIFFICULTY_STANDARD), 4138,
				"with the number still there after the round trip")
		return err)


func test_a_well_formed_save_round_trips_exactly() -> String:
	## The happy path, end to end through the real writer and the real reader, and
	## byte-exact on the file itself — a reader that refused everything would pass
	## every test above this one.
	return _with_scratch_save(1234, 5678, null, func() -> String:
		RunConfig._save()
		var err: String = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH),
			"v%d\n1234\n5678\nm0\ncb0 sfx0 mus0 spd0 svol0 mvol0\nd0\n0\n" % RunConfig.SAVE_VERSION,
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
				"v%d\n9999\n8765\nm0\ncb0 sfx0 mus0 spd0 svol0 mvol0\nd0\n0\n" % RunConfig.SAVE_VERSION,
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
				"v%d\n0\n31337\nm0\ncb0 sfx0 mus0 spd0 svol0 mvol0\nd0\n0\n" % RunConfig.SAVE_VERSION,
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
				"v%d\n1234\n5678\nm2:campaign_cleared,hundred_pests\ncb0 sfx0 mus0 spd0 svol0 mvol0\nd0\n0\n" % RunConfig.SAVE_VERSION,
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


## The two contracts, and the door each one is refused at.
##
## `earned_milestones` stores both hints and achievements, and until `RunConfig.HINTS`
## existed nothing in the code said which an id was. The two are opposite: an
## achievement is EARNED, so recording it is a consequence of the player doing a
## thing; a hint is SPENT, so recording it is a claim that the player was shown a
## thing. Cycle 79's bug was that claim being made by a code path that decided to
## show a tip and then didn't.
##
## Asserted through the doors rather than through the flag, because the flag cannot
## tell them apart — that is the whole problem — and because a guard that refuses is
## only a guard if the refusal is observable.
func test_a_hint_cannot_be_recorded_through_the_achievement_door() -> String:
	# The predicate itself before the behaviour that reads it, which is this file's
	# habit for a reason: both guards below resolve through `is_hint`, so a test that
	# only drove them would leave the deciding function unnamed. `suite_reach_check`
	# said so out loud when this landed without it.
	var err: String = _T.assert_true(RunConfig.is_hint(RunConfig.HINT_MOVE_PREVIEW),
		"the move tip is a hint")
	if err == "":
		err = _T.assert_false(RunConfig.is_hint("threat_peak"),
			"an achievement is not, and neither guard would fire on it")
	if err != "":
		return err
	return _with_scratch_save(1, 2, null, func() -> String:
		var fresh: Array[String] = RunConfig.record_milestones([RunConfig.HINT_MOVE_PREVIEW])
		var bad: String = _T.assert_eq(str(fresh), "[]",
			"record_milestones reports nothing new, because it recorded nothing")
		if bad == "":
			bad = _T.assert_false(RunConfig.has_milestone(RunConfig.HINT_MOVE_PREVIEW),
				"and the hint is genuinely unspent afterwards -- not merely unreported")
		if bad == "":
			# The same call with a real achievement, so the refusal above is shown to be
			# about the KIND of id and not about the method being broken.
			bad = _T.assert_eq(RunConfig.record_milestones(["threat_peak"]).size(), 1,
				"while an achievement through the same call records normally")
		return bad)


func test_an_achievement_cannot_be_spent_as_a_hint() -> String:
	## The other direction, and it matters for a reason that is not symmetry: passing
	## an achievement here would mean answering "was the player shown it", which is not
	## a question about a thing they did. A `shown: true` would look correct and record
	## it anyway, so the refusal has to be on the id, not on the flag.
	return _with_scratch_save(1, 2, null, func() -> String:
		var err: String = _T.assert_false(RunConfig.spend_hint("threat_peak", true),
			"an achievement is refused at the hint door even with shown = true")
		if err == "":
			err = _T.assert_false(RunConfig.has_milestone("threat_peak"),
				"and nothing was written")
		if err == "":
			err = _T.assert_false(RunConfig.spend_hint("not_an_id_at_all", true),
				"and so is an id in neither set, rather than being invented as a hint")
		return err)


func test_no_id_is_both_a_hint_and_an_achievement() -> String:
	## Derived over both lists rather than checked on the one hint that exists, because
	## the guard this protects is for the SECOND hint's author. An id in both sets would
	## be refused at both doors and therefore recordable by nothing at all — the two
	## guards are complementary, so an overlap is not a conflict the code would resolve,
	## it is a flag that can never be set.
	##
	## `Milestones.TABLE` is the achievement list because it is the one the notebook
	## shelf renders (`notebook_screen.gd:487` counts earned off TABLE), so an id absent
	## from it is invisible there — which is exactly why a hint is deliberately kept out.
	## `TABLE` is an Array[Dictionary] keyed by "id", not a set of ids — which the first
	## draft of this test got wrong, and got wrong in the way that passes: `TABLE.has(id)`
	## compares a String against Dictionaries and is false for every id in the game, so
	## the assertion was green and vacuous. The ids are pulled out here, once, and the
	## count is asserted against TABLE's own size so a shape change fails loudly instead
	## of emptying the corpus.
	var achievement_ids: Array[String] = []
	for row: Dictionary in Milestones.TABLE:
		achievement_ids.append(String(row["id"]))
	var err: String = _T.assert_gt(RunConfig.HINTS.size(), 0, "there are hints to check")
	if err == "":
		err = _T.assert_eq(achievement_ids.size(), Milestones.TABLE.size(),
			"every row in TABLE yielded an id -- %d of %d"
				% [achievement_ids.size(), Milestones.TABLE.size()])
	if err != "":
		return err
	for id: String in RunConfig.HINTS:
		err = _T.assert_false(achievement_ids.has(id),
			"'%s' is a hint, so it is not also an achievement id" % id)
		if err != "":
			return err
	for id: String in achievement_ids:
		err = _T.assert_false(RunConfig.is_hint(id),
			"'%s' is an achievement, so it is not also in RunConfig.HINTS" % id)
		if err != "":
			return err
	return err


func test_spending_a_hint_requires_saying_it_was_shown() -> String:
	## `shown` being a required argument is the design: the old shape was an `if` around
	## `record_milestones`, and an `if` is something the next hint's author can simply
	## not write. All three outcomes, because a fix that never records anything would
	## pass the first assertion on its own.
	return _with_scratch_save(1, 2, null, func() -> String:
		var err: String = _T.assert_false(
			RunConfig.spend_hint(RunConfig.HINT_MOVE_PREVIEW, false),
			"a hint the player was not shown is not spent")
		if err == "":
			err = _T.assert_false(RunConfig.has_milestone(RunConfig.HINT_MOVE_PREVIEW),
				"so it is still owed to them")
		if err == "":
			err = _T.assert_true(
				RunConfig.spend_hint(RunConfig.HINT_MOVE_PREVIEW, true),
				"and shown = true is what spends it")
		if err == "":
			err = _T.assert_true(RunConfig.has_milestone(RunConfig.HINT_MOVE_PREVIEW),
				"recorded")
		if err == "":
			err = _T.assert_false(
				RunConfig.spend_hint(RunConfig.HINT_MOVE_PREVIEW, true),
				"a second spend is not a second first sight")
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
				"v%d\n4321\n8765\nm0\ncb0 sfx0 mus0 spd0 svol0 mvol0\nd0\n0\n" % RunConfig.SAVE_VERSION,
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
	return _with_scratch_save(0, 0, "v%d\n10\n20\nm2:from_the_future,hundred_pests\ncb0 sfx0 mus0 spd0 svol0 mvol0\nd0\n0\n"
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
					"v%d\n10\n20\nm3:from_the_future,hundred_pests,threat_peak\ncb0 sfx0 mus0 spd0 svol0 mvol0\nd0\n0\n"
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
				"v%d\n11\n22\nm0\ncb1 sfx0 mus0 spd0 svol0 mvol0\nd0\n0\n" % RunConfig.SAVE_VERSION,
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
				"v%d\n11\n22\nm0\ncb0 sfx0 mus0 spd0 svol0 mvol0\nd0\n0\n" % RunConfig.SAVE_VERSION,
				"and that is written down too -- off is a choice, not an absence")
		return err)


func test_setting_the_option_to_what_it_already_is_does_not_rewrite_the_save() -> String:
	## `set_colorblind_safe` writes only on a change. The save file is not a place
	## to record that someone pressed a key twice, and every write is a rename over
	## the one file in this game holding a number that cannot be re-earned.
	return _with_scratch_save(5, 6, null, func() -> String:
		RunConfig.set_colorblind_safe(true)
		var written: String = FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH)
		var err: String = _T.assert_true(written.contains("\ncb1 sfx0 mus0 spd0 svol0 mvol0\n"), "the first set wrote the file")
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
			"v%d\n4321\n8765\nm0\ncb2 sfx0 mus0 spd0\n" % RunConfig.SAVE_VERSION,
		# v6's and v7's own shapes. The line grew from one field to three and then to
		# four, and every way a four-field line can be wrong is a way this parser must
		# not shrug. Each case below is one field short, one field long, or right-sized
		# and wrong — never merely "not three", which is what these fixtures decayed
		# into the moment the current version gained its fourth field.
		"a v5-shaped options line in a current file":
			"v%d\n4321\n8765\nm0\ncb0\n" % RunConfig.SAVE_VERSION,
		"a v6-shaped options line in a current file":
			"v%d\n4321\n8765\nm0\ncb0 sfx0 mus0\n" % RunConfig.SAVE_VERSION,
		"an options line one field short":
			"v%d\n4321\n8765\nm0\ncb0 sfx0 spd0\n" % RunConfig.SAVE_VERSION,
		"an options line with a fifth field":
			"v%d\n4321\n8765\nm0\ncb0 sfx0 mus0 spd0 xyz1\n" % RunConfig.SAVE_VERSION,
		# The speed field is the one that is not a flag, so it is the one whose own
		# marker has to be checked rather than inferred from its position.
		"a fourth field that is not the speed field":
			"v%d\n4321\n8765\nm0\ncb0 sfx0 mus0 xyz1\n" % RunConfig.SAVE_VERSION,
		# The whole reason each flag carries its own prefix. A bare `0 1 0` reads
		# perfectly when two fields swap places, and the player's music mute quietly
		# becomes their colourblind setting.
		"an options line with its fields transposed":
			"v%d\n4321\n8765\nm0\nsfx0 cb0 mus0 spd0\n" % RunConfig.SAVE_VERSION,
		"an options line padded with a second space":
			"v%d\n4321\n8765\nm0\ncb0  sfx0 mus0 spd0\n" % RunConfig.SAVE_VERSION,
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
# (v7 widened the same line again with `spd0`, the garden speed. That field is not
# an Options-screen switch and is covered by its own section at the end of this
# file; the fixtures below carry it only because a current-version save has to.)


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
				"v%d\n11\n22\nm0\ncb0 sfx1 mus0 spd0 svol0 mvol0\nd0\n0\n" % RunConfig.SAVE_VERSION,
				"the options line carries all three switches, colourblind first")
		if err == "":
			err = _T.assert_true(RunConfig.set_mute_music(true), "and the bed mutes independently")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH),
				"v%d\n11\n22\nm0\ncb0 sfx1 mus1 spd0 svol0 mvol0\nd0\n0\n" % RunConfig.SAVE_VERSION,
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
				"v%d\n11\n22\nm0\ncb0 sfx0 mus1 spd0 svol0 mvol0\nd0\n0\n" % RunConfig.SAVE_VERSION,
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
		var err: String = _T.assert_true(written.contains("\ncb0 sfx1 mus0 spd0 svol0 mvol0\n"), "the first set wrote the file")
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


## Named for "the current version" rather than for v6, which is what it said until
## SAVE_VERSION became 7 and the name started describing a bump two versions back.
## The body already interpolated `RunConfig.SAVE_VERSION`; only the name drifted.
func test_a_version_five_save_reads_forward_into_the_current_version() -> String:
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
				"v%d\n70\n80\nm1:threat_peak\ncb1 sfx0 mus0 spd0 svol0 mvol0\nd0\n1\ngarden_pause 4194332\n" % RunConfig.SAVE_VERSION,
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
## endless one: the endless column is paced apart from the first endless wave on,
## so endless peaks at 29, and WAVES' last row is sized to land on 40 exactly.
## That is why this still reads zero headroom, and it is a different sentence from
## the one above -- one is the construction, the other is a measurement of a real
## wave. ("From wave 17 on" is what this used to say; the campaign grew to 22
## waves in plant-tower-defense-eeaq and endless now starts at 23, which is the
## kind of drift a wave NUMBER written into prose picks up and a phrase like "the
## first endless wave" does not.)
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
		err = _T.assert_false(both.contains("click a spot to move"),
			"the forfeit clause displaces the move tip rather than joining it -- got %s" % both)
	return err


## The one-shot hint must not be spent by a prompt that never shows it
## (plant-tower-defense-np1d).
##
## Cycle 79 introduced this by adding the forfeit clause: `Game` recorded
## HINT_MOVE_PREVIEW whenever the player had not yet seen the tip, and the forfeit clause
## then displaced the tip. A first-ever uproot on an upgraded plant burned the hint
## permanently without showing it — and that is the LIKELY path, since uprooting something
## cheap is not a decision worth a four-second prompt.
##
## Both directions, because a fix that simply never records it would pass the first half.
## The flight hint is spent on `show_message`'s RETURN VALUE, not on the handler running.
##
## This is the assertion the whole two-door contract is for, and without it a mutation
## replacing `posted` with a literal `true` at the call site survives every other test in
## this change: the predicate still fires, the signal still emits, the message still
## appears in the ordinary case. The only observable difference is the case below — a row
## too busy to take the line — and there the hint must stay OWED.
##
## Both halves, because a handler that never spends anything would pass the first.
func test_the_flight_hint_is_not_spent_when_the_row_was_too_busy() -> String:
	RunConfig.earned_milestones.erase(RunConfig.HINT_CHOMP_IGNORES_FLIGHT)
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var hud: Hud = game.hud
	# Drain Game._ready's starter tip, then park a DEADLINE line on the row for six
	# seconds. A MESSAGE_NORMAL arrival cannot pre-empt that, so it queues -- which is
	# exactly the state where "I called show_message" and "the player read it" diverge.
	hud._process(9.0)
	hud._message_left = 0.0
	hud._message_queue.clear()
	hud._advance_message_queue()
	hud.show_message("sitting on the row", 6.0, Hud.MESSAGE_DEADLINE)

	game._on_flight_ignored()
	var err: String = _T.assert_false(
		RunConfig.has_milestone(RunConfig.HINT_CHOMP_IGNORES_FLIGHT),
		"the row was busy, so the tip was queued rather than seen -- the hint stays owed")
	if err == "":
		err = _T.assert_gt(hud.pending_messages(), 0,
			"and the line is genuinely waiting, so this is the queued case and not a drop")
	if err == "":
		# Clear the row and offer it again. This is the retry path: a hint the player was
		# not shown comes back round, which a hint spent on the call could never do.
		hud._message_left = 0.0
		hud._message_queue.clear()
		hud._advance_message_queue()
		game._on_flight_ignored()
		err = _T.assert_true(RunConfig.has_milestone(RunConfig.HINT_CHOMP_IGNORES_FLIGHT),
			"offered onto a clear row it posts, and NOW it is spent")
	_T.free_ui(game)
	RunConfig.earned_milestones.erase(RunConfig.HINT_CHOMP_IGNORES_FLIGHT)
	return err


func test_the_move_tip_is_spent_only_when_it_is_actually_shown() -> String:
	# The predicate itself, all four combinations, before the behaviour that reads it.
	# Two inputs is four cases and three of them say no, so a single worked example
	# would have proved almost nothing — and `suite_reach_check` is what pointed out
	# that driving it only through `arm_uproot` left the seam itself unnamed.
	var err: String = _T.assert_true(Hud.uproot_shows_tip(true, 0),
		"a first arm on a plant with nothing to forfeit shows the tip")
	if err == "":
		err = _T.assert_false(Hud.uproot_shows_tip(true, 65),
			"the forfeit clause displaces it")
	if err == "":
		err = _T.assert_false(Hud.uproot_shows_tip(false, 0),
			"a player who has seen it does not see it again")
	if err == "":
		err = _T.assert_false(Hud.uproot_shows_tip(false, 65),
			"and neither at once")
	if err != "":
		return err
	RunConfig.earned_milestones.erase(RunConfig.HINT_MOVE_PREVIEW)
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	game.bank.add_seeds(300)
	var planted: Array[Vector2i] = []
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			if planted.size() >= 2:
				break
			if game.place_plant(PlantCatalog.CORN, Vector2i(x, y)) == "":
				planted.append(Vector2i(x, y))
	err = _T.assert_eq(planted.size(), 2, "two cobs went in")
	var label: Label = game.hud.get_node_or_null("Root/TopBar/MessageLabel") as Label
	if err == "":
		# First arm ever, on an UPGRADED plant: the forfeit clause wins the row.
		var cob := game.plant_at(planted[1]) as CornCobbler
		err = _T.assert_true(cob != null and cob.upgrade(), "the second cob upgraded")
		if err == "":
			game.selected_placed = cob
			err = _T.assert_eq(game.arm_uproot(), "confirm needed", "and armed")
	if err == "":
		err = _T.assert_true(label.text.contains("upgrade seeds are not refunded"),
			"the money clause is what the player got -- %s" % label.text)
	if err == "":
		err = _T.assert_false(label.text.contains("click a spot to move"),
			"and the tip was displaced, not shown")
	if err == "":
		err = _T.assert_false(RunConfig.has_milestone(RunConfig.HINT_MOVE_PREVIEW),
			"so the one-shot is NOT spent -- a hint nobody saw is a hint still owed")
	if err == "":
		# Now a fresh plant: the tip appears and only now is the one-shot spent.
		game.hud._message_left = 0.0
		game.hud._message_queue.clear()
		game.hud._advance_message_queue()
		game._disarm_uproot()
		game.selected_placed = game.plant_at(planted[0])
		err = _T.assert_eq(game.arm_uproot(), "confirm needed", "arming on the fresh one")
	if err == "":
		err = _T.assert_true(label.text.contains("click a spot to move"),
			"the tip finally shows -- %s" % label.text)
	if err == "":
		err = _T.assert_true(RunConfig.has_milestone(RunConfig.HINT_MOVE_PREVIEW),
			"and NOW the one-shot is spent")
	RunConfig.earned_milestones.erase(RunConfig.HINT_MOVE_PREVIEW)
	_T.free_ui(game)
	return err


# -- The campaign is 22 waves now (plant-tower-defense-eeaq) -------------------
#
# Six waves went in front of the finale rather than after it, and the four tests
# below are the four things that made "in front of" the only option. They are
# pure arithmetic over WaveDirector's statics -- no scene, no node, no settle --
# so they belong in test_dir rather than behind the bridge.
#
# The suite already asserts, in test_combat.gd and test_selftest.gd, that
# threat_for() rises strictly across the seam and that no wave overruns the road.
# What it has never asserted is WHY those two hold together, which is the one
# thing a future balance pass needs and the one thing that is not obvious from
# either file: the first endless wave's health is capped by a rule about its
# COMPOSITION, and that cap propagates backwards onto the campaign finale.


## The seam bound, derived rather than restated.
##
## `threat_for` must rise strictly from the finale into the first endless wave.
## The first endless wave's contents are not free to grow, because
## test_the_beetle_column_is_the_axis_that_replaced_the_headcount requires it to
## stay under half beetle -- so its health has a ceiling, and dividing that
## ceiling by the campaign's own mutation multiplier gives a ceiling on the
## FINALE. That number (436.7 points of base health against a finale already
## worth 418) is why plant-tower-defense-eeaq could not append waves to the end
## of the table and inserted them before the last row instead.
##
## Asserted here rather than left in wave_director.gd's prose because prose does
## not fail. Anyone raising the finale gets the number and the reason in one
## message, at the moment they raise it, instead of a strict-increase test
## failing at wave 23 with nothing to say about the cause.
func test_the_campaign_finale_fits_under_the_endless_seam() -> String:
	var finale: int = WaveDirector.WAVES.size()
	var first_endless: int = finale + 1

	var seam_health: float = 0.0
	for group: Dictionary in WaveDirector.groups_for(first_endless):
		seam_health += float(group["count"]) * float(Pest.SPECIES[group["species"]]["health"])
	var finale_health: float = 0.0
	for group: Dictionary in WaveDirector.groups_for(finale):
		finale_health += float(group["count"]) * float(Pest.SPECIES[group["species"]]["health"])

	# Vacuity guard: both sides have to be real waves, or every comparison below
	# is 0 against 0 and passes for the wrong reason.
	var err: String = _T.assert_gt(seam_health, 0.0, "the first endless wave has contents")
	if err == "":
		err = _T.assert_gt(finale_health, 0.0, "and so does the campaign finale")
	if err != "":
		return err

	# The two multipliers _raw_threat applies. The first endless wave has one wave of
	# every endless scale on it.
	#
	# The finale's own HEALTH scale belongs in the campaign side since
	# plant-tower-defense-iqp8 -- the campaign no longer sits at 1.0 on that axis.
	# Leaving it out does not fail this test, it inflates `bound` from 436.7 to 725
	# and the assertion below goes on passing while measuring nothing, which is the
	# worse outcome. See health_scale_for's header: the endless ramp is a MULTIPLE of
	# the campaign's last value precisely so the two cancel here and the seam bound
	# stays put at any step size.
	var campaign_mult: float = (1.0 + WaveDirector.MUTATION_CHANCE * WaveDirector.MUTATION_THREAT_WEIGHT) \
		* WaveDirector.health_scale_for(finale)
	var seam_mutations: float = 1.0 + WaveDirector.mutation_chance_for(first_endless) \
		* WaveDirector.MUTATION_THREAT_WEIGHT
	var seam_scales: float = WaveDirector.health_scale_for(first_endless) \
		* WaveDirector.speed_scale_for(first_endless)
	var bound: float = seam_health * seam_mutations * seam_scales / campaign_mult

	err = _T.assert_gt(bound, finale_health,
		("the finale is worth %.0f points of base health against a seam bound of %.1f"
			+ " -- %.1f points of headroom, i.e. %.1f beetles. Raising the finale past the"
			+ " bound inverts threat_for at the seam; raising the bound means raising"
			+ " ENDLESS_APHID_SHARE, and the two road shares sum to"
			+ " SIMULTANEOUS_PEST_CEILING exactly")
			% [finale_health, bound, bound - finale_health,
				(bound - finale_health) / float(Pest.SPECIES[Pest.BEETLE]["health"])])
	if err == "":
		# The bound is the real crossing point, not a conservative estimate: one
		# aphid past it and the first endless wave prices BELOW the finale.
		var just_over: float = bound + float(Pest.SPECIES[Pest.APHID]["health"])
		err = _T.assert_gt(just_over * campaign_mult, WaveDirector._raw_threat(first_endless),
			"and the bound is exactly where the seam inverts, not a margin under it")
	if err == "":
		# And the thing the bound exists to protect actually holds today.
		err = _T.assert_gt(WaveDirector.threat_for(first_endless), WaveDirector.threat_for(finale),
			"so the first endless wave still prices above the campaign finale")
	return err


## The finale is the ONLY wave that spends the whole road.
##
## test_every_campaign_wave_stays_inside_the_road_budget_brood_included asserts
## that the worst campaign wave equals SIMULTANEOUS_PEST_CEILING, which a tie
## satisfies -- so six new rows could each have been sized to 40 and that test
## would still be green while "the finale is the fullest the road ever gets"
## quietly stopped being true. This pins the uniqueness, which is the half the
## prose in SIMULTANEOUS_PEST_CEILING actually claims.
func test_only_the_campaign_finale_spends_the_whole_road_budget() -> String:
	var finale: int = WaveDirector.WAVES.size()
	var err: String = _T.assert_gt(finale, 1, "there is a campaign to sweep")
	if err != "":
		return err
	var checked: int = 0
	var runner_up: int = 0
	var runner_up_wave: int = 0
	for wave: int in range(1, finale):
		var peak: int = WaveDirector.peak_simultaneous_pests(wave)
		err = _T.assert_gt(WaveDirector.SIMULTANEOUS_PEST_CEILING, peak,
			("wave %d peaks at %d, strictly under the %d ceiling -- only the finale is"
				+ " allowed to land on it") % [wave, peak, WaveDirector.SIMULTANEOUS_PEST_CEILING])
		if err != "":
			return err
		if peak > runner_up:
			runner_up = peak
			runner_up_wave = wave
		checked += 1
	err = _T.assert_gt(checked, 1, "the sweep walked a campaign (%d waves)" % checked)
	if err == "":
		err = _T.assert_eq(WaveDirector.peak_simultaneous_pests(finale),
			WaveDirector.SIMULTANEOUS_PEST_CEILING,
			"and the finale lands on it exactly")
	if err == "":
		# Not a bound nobody comes near either: the runner-up is reported so a
		# future row that quietly drops the whole campaign to half the ceiling is
		# visible as a number rather than as a still-passing test.
		err = _T.assert_gt(float(runner_up),
			float(WaveDirector.SIMULTANEOUS_PEST_CEILING) * 0.5,
			"and the wave below it (wave %d, %d pests) is still a real second place"
				% [runner_up_wave, runner_up])
	return err


## Every campaign wave asks a different question.
##
## The table's header claims this in prose for all twenty-two rows, and prose
## cannot catch a row pasted twice and edited in one number. A wave IS its group
## list -- species, order, counts, gaps and leads -- so the signature below is the
## whole of what the player meets, and two identical signatures are two identical
## waves however far apart they sit.
##
## The second half is the specific claim the run-up rests on: wave 12 and wave 14
## both open with the queen, and the new wave 18 is the only row in the table that
## buries her between two other groups. If a later edit moves her to the front of
## that row it becomes wave 14 with different numbers, and nothing else in the
## suite would notice.
func test_no_two_campaign_waves_are_the_same_wave() -> String:
	var seen: Dictionary = {}
	var queen_not_first: Array[int] = []
	var err: String = ""
	for wave: int in range(1, WaveDirector.WAVES.size() + 1):
		var parts: PackedStringArray = []
		var index: int = 0
		for group: Dictionary in WaveDirector.groups_for(wave):
			parts.append("%s%d@%.2f/%.2f" % [group["species"], int(group["count"]),
				float(group["gap"]), float(group["lead"])])
			if StringName(group["species"]) == Pest.QUEEN and index > 0:
				queen_not_first.append(wave)
			index += 1
		var signature: String = " ".join(parts)
		err = _T.assert_false(seen.has(signature),
			"wave %d is not a repeat of wave %s -- %s"
				% [wave, seen.get(signature, "?"), signature])
		if err != "":
			return err
		seen[signature] = wave
	err = _T.assert_eq(seen.size(), WaveDirector.WAVES.size(),
		"every wave in the table got a signature (a short count means an empty row)")
	if err == "":
		err = _T.assert_eq(queen_not_first.size(), 1,
			("exactly one wave buries the queen behind another group -- that arrangement is"
				+ " the whole of what wave 18 asks that 12 and 14 do not. Got %s")
				% [queen_not_first])
	return err


## The campaign has a second drought, and it is boss-free on purpose.
##
## weather_for() drops drought on any wave carrying a boss, so a queen added to
## the drought row deletes the weather silently -- no error, no finding, just a
## wave that stops halving the garden's rate of fire. That is a one-word edit with
## no local tell, which is exactly what an enumeration is for.
##
## Both lists are enumerated rather than sampled, because the claim being made is
## about the whole campaign ("one drought before, two now"), and the exemption is
## checked against a real witness -- wave 14 is a multiple of WEATHER_DROUGHT_EVERY
## and carries a queen and is clear -- rather than asserted from the rule.
func test_the_campaign_droughts_and_rains_are_where_the_table_says() -> String:
	var droughts: Array[int] = []
	var rains: Array[int] = []
	for wave: int in range(1, WaveDirector.WAVES.size() + 1):
		var weather: StringName = WaveDirector.weather_for(wave)
		if weather == WaveDirector.WEATHER_DROUGHT:
			droughts.append(wave)
		elif weather == WaveDirector.WEATHER_RAIN:
			rains.append(wave)

	var err: String = _T.assert_eq(droughts.size(), 2,
		"the campaign runs two droughts, at 7 and 21 -- got %s" % [droughts])
	if err == "":
		err = _T.assert_eq(droughts[0], 7, "the first is wave 7")
	if err == "":
		err = _T.assert_eq(droughts[1], 21, "and the second is wave 21")
	if err == "":
		err = _T.assert_false(WaveDirector.wave_carries_boss(droughts[1]),
			("wave 21 carries no queen, which is the only reason its drought lands"
				+ " -- see WAVES' row for it"))
	if err == "":
		err = _T.assert_eq(rains.size(), 4,
			"and four rain waves, at 5, 10, 15 and 20 -- got %s" % [rains])
	if err == "":
		err = _T.assert_eq(rains[rains.size() - 1], 20,
			"the last of them being the wave paired traits start on")
	if err != "":
		return err

	# The exemption, against a wave that really exercises it rather than against
	# the rule that produces it.
	err = _T.assert_eq(14 % WaveDirector.WEATHER_DROUGHT_EVERY, 0,
		"wave 14 is a drought wave by the arithmetic")
	if err == "":
		err = _T.assert_true(WaveDirector.wave_carries_boss(14), "and it carries a queen")
	if err == "":
		err = _T.assert_eq(String(WaveDirector.weather_for(14)),
			String(WaveDirector.WEATHER_CLEAR),
			"so it comes up clear -- the exemption is doing work, not decorating")
	return err


# -- the remembered garden speed (plant-tower-defense-zgzc) ------------------
#
# v7 put the garden speed on the options line. Before it, GameSpeed cycled
# 1x/2x/half and `Game._end_run` and `Game._exit_tree` both called `reset()`, so the
# choice did not survive a run, a restart or a quit -- someone who plays at 2x had
# to press the button again every single run.
#
# The reset itself is correct and stays: `Engine.time_scale` is process-global and
# outlives every node, so a run abandoned at 2x would hand the title screen a
# doubled clock. What changed is that the choice is written down somewhere the
# reset cannot reach (`RunConfig.game_speed_step`) and put back on the way IN
# (`Game._ready` -> `RunConfig.apply_game_speed`) rather than being kept across the
# way out.
#
# ALL THREE STEPS ARE STICKY, half speed included. The argument is written out in
# full over `RunConfig.game_speed_step`; the short version is that the button
# carries its own label on the top bar of every frame, so a remembered half speed
# announces itself and is one press from normal, whereas a setting that is
# remembered for two of its three values and silently not for the third is a defect
# with no signal anywhere. `test_the_half_speed_step_is_sticky_too` is what pins
# that decision, so a future clamp has to argue with a failing test rather than
# quietly land.
#
# Every test here goes through `_with_scratch_save`, which now stashes and restores
# `Engine.time_scale` as well as the persisted index -- see `_stash_run_config`.
# That is not politeness: a leaked half speed would not fail anything in this file,
# it would slow every timing-sensitive test in every later script.


## The acceptance criterion, at the persistence layer: a speed chosen in one run is
## the speed the next launch reads back.
func test_the_chosen_garden_speed_round_trips_through_the_save() -> String:
	return _with_scratch_save(0, 0, null, func() -> String:
		# Through the setter, not by assigning the field: the setter is what a run
		# actually reaches, and it is the half that writes the file.
		var stored: int = RunConfig.store_game_speed(1)
		var err: String = _T.assert_eq(stored, 1, "store_game_speed hands back what it stored")
		if err == "":
			err = _T.assert_true(FileAccess.file_exists(HIGHSCORE_TEST_PATH),
				"and it wrote the save, rather than only moving the field")
		if err == "":
			err = _T.assert_true(
				FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH).contains("\ncb0 sfx0 mus0 spd1 svol0 mvol0\n"),
				"the speed rides on the options line as the fourth field -- got %s"
					% [FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH)])
		if err == "":
			# The round trip proper. Wipe the in-memory field first, or a `_load` that
			# never touched it would pass this by leaving 1 where it found it.
			RunConfig.game_speed_step = 0
			RunConfig._load()
			err = _T.assert_eq(RunConfig.load_status, "loaded",
				"a file this build just wrote reads back as current, not as migrated")
		if err == "":
			err = _T.assert_eq(RunConfig.game_speed_step, 1,
				"and the next launch starts at the speed the last run chose")
		return err)


## The open question this bead left, answered and pinned. See the section header.
func test_the_half_speed_step_is_sticky_too() -> String:
	return _with_scratch_save(0, 0, null, func() -> String:
		var half: int = GameSpeed.STEPS.find(0.5)
		var err: String = _T.assert_true(half > 0,
			"half speed is a step of GameSpeed.STEPS -- got %s" % [GameSpeed.STEPS])
		if err != "":
			return err
		if err == "":
			err = _T.assert_eq(RunConfig.store_game_speed(half), half,
				"half speed is persisted like any other step, NOT clamped away to 1x")
		if err == "":
			RunConfig.game_speed_step = 0
			RunConfig._load()
			err = _T.assert_eq(RunConfig.game_speed_step, half,
				("and it comes back on the next launch. If this fails because someone "
					+ "clamped the persisted value to {1x, 2x}, read the argument over "
					+ "RunConfig.game_speed_step first -- it names what would change it."))
		return err)


## What an OLD save does when the field is absent. The migration case, and the one
## the version history in run_config.gd exists to keep honest.
func test_a_save_written_before_the_speed_field_reads_as_one_x_and_is_rewritten() -> String:
	# A v6 file: three fields on the options line, no speed. Deliberately carrying a
	# milestone and a rebound key, because the thing that goes wrong in a bump is not
	# the new field -- it is an OLD field defaulted and written back out empty by the
	# migration rewrite, which is exactly what VERSION_WITH_EXTRAS exists to prevent.
	var original: String = "v6\n70\n80\nm1:threat_peak\ncb1 sfx0 mus0\n1\ngarden_pause 4194332\n"
	return _with_scratch_save(0, 0, original, func() -> String:
		RunConfig._load()
		var err: String = _T.assert_eq(RunConfig.load_status, "migrated",
			"a v6 file is read forward, not refused")
		if err == "":
			err = _T.assert_eq(RunConfig.game_speed_step, 0,
				("a save with no speed field reads as 1x -- a player who never had the "
					+ "control had a garden running at normal speed"))
		if err == "":
			err = _T.assert_eq(RunConfig.campaign_high_score, 70, "and its scores survive")
		if err == "":
			err = _T.assert_true(RunConfig.has_milestone("threat_peak"),
				"and its milestone survives the bump")
		if err == "":
			err = _T.assert_eq(RunConfig.key_bindings.size(), 1,
				"and so does its rebound key -- the field under the one that moved")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH),
				"v%d\n70\n80\nm1:threat_peak\ncb1 sfx0 mus0 spd0 svol0 mvol0\nd0\n1\ngarden_pause 4194332\n"
					% RunConfig.SAVE_VERSION,
				"and it is rewritten once in the new shape, with the speed defaulted in place")
		if err == "":
			RunConfig._load()
			err = _T.assert_eq(RunConfig.load_status, "loaded",
				"the migrated file loads as current next time, rather than migrating forever")
		return err)


## The speed field is the first on that line that is not a flag, so it is the first
## whose own malformed shapes nothing else in this file covers.
func test_a_save_with_a_broken_speed_field_is_refused_whole() -> String:
	var cases: Dictionary = {
		"a speed field with no digits":
			"v%d\n4321\n8765\nm0\ncb0 sfx0 mus0 spd\n" % RunConfig.SAVE_VERSION,
		"a speed field that is not a number":
			"v%d\n4321\n8765\nm0\ncb0 sfx0 mus0 spdx\n" % RunConfig.SAVE_VERSION,
		# `int("")` is 0 and `int("-1")` is -1: both would read as a legal-looking
		# index if the parser reached for `int()` before `is_valid_int()`.
		"a negative speed step":
			"v%d\n4321\n8765\nm0\ncb0 sfx0 mus0 spd-1\n" % RunConfig.SAVE_VERSION,
		"a speed step past the bound":
			"v%d\n4321\n8765\nm0\ncb0 sfx0 mus0 spd%d\n"
				% [RunConfig.SAVE_VERSION, RunConfig.MAX_SPEED_STEP + 1],
		"a speed field wearing another field's marker":
			"v%d\n4321\n8765\nm0\ncb0 sfx0 mus0 cb0\n" % RunConfig.SAVE_VERSION,
	}
	for what: String in cases:
		var err: String = _with_scratch_save(4321, 8765, cases[what],
			func() -> String: return _assert_refused(4321, 8765, what))
		if err != "":
			return err
	return ""


## A step index this build has no step for is KEPT rather than condemning the file,
## and refused at the point of use. Same asymmetry `_parse_milestones` cites for not
## checking ids against `Milestones.TABLE`: the scores in the file cannot be
## re-earned and a speed can, so a downgrade must not cost the player both.
func test_a_saved_speed_step_this_build_has_no_step_for_starts_at_one_x() -> String:
	var future_step: int = GameSpeed.STEPS.size() + 1
	# SIX fields, not four. This fixture writes `RunConfig.SAVE_VERSION` in the header, so
	# the line under it must have the shape THAT version declares — and at v8 a four-field
	# line is malformed, so the file was refused for its field count and this test failed
	# claiming the speed handling had regressed. It had not: the fixture had.
	#
	# That is the same weakening lane u9uh flagged on the two refusal fixtures at :1425-1449
	# and on test_a_save_with_a_broken_speed_field_is_refused_whole — a fixture pinned to
	# SAVE_VERSION rather than to the version whose shape it is testing goes stale silently
	# on every bump, and the failure it produces points at the parser instead of at itself.
	var original: String = "v%d\n70\n80\nm0\ncb0 sfx0 mus0 spd%d svol0 mvol0\nd0\n0\n" % [
		RunConfig.SAVE_VERSION, future_step]
	return _with_scratch_save(0, 0, original, func() -> String:
		RunConfig._load()
		var err: String = _T.assert_eq(RunConfig.load_status, "loaded",
			"a step from a build with more steps does not condemn the two scores in the file")
		if err == "":
			err = _T.assert_eq(RunConfig.campaign_high_score, 70, "which is the point of keeping it")
		if err == "":
			err = _T.assert_eq(RunConfig.game_speed_step, future_step,
				"the index is kept verbatim, for a build that has that step")
		if err == "":
			# It emits a push_warning, which is the intended loudness -- the run must
			# not stop over a speed.
			RunConfig.apply_game_speed()
			err = _T.assert_float_eq(Engine.time_scale, GameSpeed.NORMAL, 0.0001,
				("but the engine starts at 1x rather than wrapping with posmod, which "
					+ "would silently pick some OTHER step of this build's table"))
		if err == "":
			err = _T.assert_eq(RunConfig.game_speed_step, future_step,
				"and applying it did not overwrite the index it could not use")
		GameSpeed.reset()
		return err)


## `GameSpeed.set_step` wraps with posmod, which is right for a button and wrong for
## a value that will be written to disk and read back forever.
func test_store_game_speed_refuses_an_index_this_build_has_no_step_for() -> String:
	return _with_scratch_save(0, 0, null, func() -> String:
		var err: String = _T.assert_eq(RunConfig.store_game_speed(GameSpeed.STEPS.size()), 0,
			"an index one past the table is refused, and the stored value stands")
		if err == "":
			err = _T.assert_eq(RunConfig.store_game_speed(-1), 0, "so is a negative one")
		if err == "":
			err = _T.assert_false(FileAccess.file_exists(HIGHSCORE_TEST_PATH),
				"and neither refusal wrote a save")
		return err)


## The `set_colorblind_safe` contract, checked rather than assumed. It matters more
## here than anywhere else in the file: a full cycle back to 1x is three presses, so
## an unguarded setter would write user:// three times per lap of the button.
func test_store_game_speed_writes_only_when_the_choice_actually_changes() -> String:
	return _with_scratch_save(0, 0, null, func() -> String:
		var err: String = _T.assert_eq(RunConfig.store_game_speed(0), 0,
			"storing the speed that is already stored is a no-op")
		if err == "":
			err = _T.assert_false(FileAccess.file_exists(HIGHSCORE_TEST_PATH),
				"so nothing was written -- the save file is not a press counter")
		if err == "":
			err = _T.assert_eq(RunConfig.store_game_speed(1), 1, "a real change is stored")
		if err == "":
			err = _T.assert_true(FileAccess.file_exists(HIGHSCORE_TEST_PATH), "and written")
		return err)


## The restore must not fight the pause parking. `-03t6` pinned "the pause card
## reads at 1x" and test_selftest.gd holds that assertion for `GameSpeed` alone;
## this is the same question asked of the path that now also restores a speed.
func test_restoring_a_saved_speed_still_leaves_the_pause_card_at_one_x() -> String:
	return _with_scratch_save(0, 0, null, func() -> String:
		# Explicitly unheld to start. `is_held()` is static process state, so this test
		# would pass for the wrong reason -- every reading 1x -- if an earlier one left
		# a hold standing.
		GameSpeed.reset()
		RunConfig.game_speed_step = 1
		RunConfig.apply_game_speed()
		var chosen: float = GameSpeed.STEPS[1]
		var err: String = _T.assert_float_eq(Engine.time_scale, chosen, 0.0001,
			"applying the saved speed moves the engine, which is the whole feature")
		if err == "":
			GameSpeed.hold()
			err = _T.assert_float_eq(Engine.time_scale, GameSpeed.NORMAL, 0.0001,
				("and a pause still parks it at 1x -- the card's fades run on the paused "
					+ "tree and Engine.time_scale scales a Tween whether or not it is paused"))
		if err == "":
			err = _T.assert_eq(GameSpeed.step(), 1,
				"the choice is parked, not discarded")
		if err == "":
			# The branch that would be reachable if `Game._ready` ever ran behind a
			# card, or if a future entry point applied the saved speed while held.
			RunConfig.game_speed_step = 2
			RunConfig.apply_game_speed()
			err = _T.assert_float_eq(Engine.time_scale, GameSpeed.NORMAL, 0.0001,
				"restoring a speed WHILE held moves the parked choice and leaves the engine at 1x")
		if err == "":
			GameSpeed.release()
			err = _T.assert_float_eq(Engine.time_scale, GameSpeed.STEPS[2], 0.0001,
				"and the release hands back the speed that was chosen last")
		# Unconditionally, on the failing path too: `Engine.time_scale` and
		# `GameSpeed._held_step` are both static, so a body that returned early while
		# held would leave the whole rest of the suite parked.
		GameSpeed.reset()
		return err)


## What `reset()` does and does not reach, stated once. This is the seam the whole
## item turns on: the engine goes back to 1x on every way out of a run, and the
## player's choice is somewhere reset cannot see.
func test_ending_a_run_resets_the_engine_but_not_the_remembered_choice() -> String:
	return _with_scratch_save(0, 0, null, func() -> String:
		var err: String = _T.assert_eq(RunConfig.store_game_speed(1), 1, "the player picks 2x")
		if err == "":
			RunConfig.apply_game_speed()
			err = _T.assert_float_eq(Engine.time_scale, GameSpeed.STEPS[1], 0.0001,
				"and the run runs at it")
		if err == "":
			# Both `Game._end_run` and `Game._exit_tree` call exactly this.
			GameSpeed.reset()
			err = _T.assert_float_eq(Engine.time_scale, GameSpeed.NORMAL, 0.0001,
				("leaving the run puts the ENGINE back to 1x, which is not negotiable -- "
					+ "Engine.time_scale outlives the scene and the title screen gets it"))
		if err == "":
			err = _T.assert_eq(GameSpeed.step(), 0, "and forgets the step it was holding")
		if err == "":
			err = _T.assert_eq(RunConfig.game_speed_step, 1,
				"but the player's choice is on disk, where reset() cannot reach it")
		if err == "":
			# Which is what makes the next run start at 2x: Game._ready calls this.
			RunConfig.apply_game_speed()
			err = _T.assert_float_eq(Engine.time_scale, GameSpeed.STEPS[1], 0.0001,
				"so the next run starts at the speed the last one chose")
		GameSpeed.reset()
		return err)


# -- the two audio dials (plant-tower-defense-u9uh) ---------------------------
#
# Sound was a switch: `mute_sfx` / `mute_music`, and a player who found the music
# loud had exactly one option and it was silence. `AudioServer` appeared nowhere in
# game/ -- there were no buses and never had been -- so a level had nowhere to
# land. v8 adds two, one per category, and two persisted indices into `Sfx.LEVELS`.
#
# EVERY TEST BELOW GOES THROUGH `_with_scratch_save`, including the ones that never
# open a file. `AudioServer` bus volume is PROCESS-GLOBAL in exactly the way
# `Engine.time_scale` is, and `_stash_run_config` is where both halves of the pair
# -- the remembered index and the bus it is pushed into -- are put back. A test
# here that moved the mixer outside that wrapper would not fail; it would sit under
# every later script in the run, which is how the remembered speed leaked at
# cycle 104.


## The acceptance clause the bead is actually about: not that the setting is
## STORED, but that it reaches the thing that makes the noise.
##
## `Sfx.tune_voice` is the seam, and it is the seam for the reason cycle 74 wrote
## down: `play()` is gated off headless by `should_play`, so a suite cannot watch a
## voice start -- but it can hand `tune_voice` a bare AudioStreamPlayer and read
## back every property the event decided, which now includes which bus it plays on.
## A dial wired only into the save file would pass a storage test and be inaudible.
func test_the_dial_reaches_the_voice_and_the_bus_not_only_the_save() -> String:
	return _with_scratch_save(0, 0, null, func() -> String:
		var voice := AudioStreamPlayer.new()
		Sfx.tune_voice(voice, Sfx.PEST_KILLED)
		var err: String = _T.assert_eq(String(voice.bus), String(Sfx.BUS_NAME),
			"tune_voice routes the voice to the effects bus, so a cue cannot be played past the dial")
		if err == "":
			err = _T.assert_true(Sfx.ensure_bus(Sfx.BUS_NAME) >= 0,
				"and that bus exists in the running mixer rather than being a name nobody made")
		if err == "":
			# The other half: the level the player chose is the number the bus holds.
			# Every step, not just one -- a mapping asserted at a single point is a
			# mapping that can be a constant.
			for step: int in Sfx.LEVELS.size():
				Sfx.set_level(step)
				var bus: int = Sfx.ensure_bus(Sfx.BUS_NAME)
				err = _T.assert_float_eq(AudioServer.get_bus_volume_db(bus), Sfx.level_db(step), 0.001,
					"effects level %d puts %.2fdB on the bus" % [step, Sfx.level_db(step)])
				if err != "":
					break
		if err == "":
			for step: int in Sfx.LEVELS.size():
				Music.set_level(step)
				var bus: int = Sfx.ensure_bus(Music.BUS_NAME)
				err = _T.assert_float_eq(AudioServer.get_bus_volume_db(bus), Sfx.level_db(step), 0.001,
					"music level %d puts %.2fdB on ITS OWN bus" % [step, Sfx.level_db(step)])
				if err != "":
					break
		if err == "":
			# Two faders, not one master, and this is what says so: the two buses are
			# different buses, so "turn the music down and leave the game audible" is
			# expressible. A single master could not say it at all.
			err = _T.assert_true(Sfx.ensure_bus(Sfx.BUS_NAME) != Sfx.ensure_bus(Music.BUS_NAME),
				"effects and music are separate buses, which is what makes them separate dials")
		if err == "":
			Sfx.set_level(0)
			Music.set_level(Sfx.LEVELS.size() - 1)
			err = _T.assert_float_eq(
				AudioServer.get_bus_volume_db(Sfx.ensure_bus(Sfx.BUS_NAME)), Sfx.level_db(0), 0.001,
				"and turning the music right down leaves the effects bus where it was")
		voice.free()
		return err)


## The design question, pinned so it cannot be quietly reversed: a dial at zero
## would BE a mute, so no step is zero and silence stays exactly one mechanism.
##
## Without this, the obvious "improvement" of adding a 0% step reintroduces two
## ways to silence one category -- and then the mute key has to stash the level it
## silenced and put it back, which is the state machine the header refuses.
func test_no_level_is_silence_so_the_mute_stays_the_only_way_to_be_quiet() -> String:
	return _with_scratch_save(0, 0, null, func() -> String:
		var err: String = _T.assert_gt(Sfx.LEVELS.size(), 1,
			"a dial with one position is a switch again")
		for step: int in Sfx.LEVELS.size():
			if err != "":
				break
			err = _T.assert_true(Sfx.LEVELS[step] > 0.0,
				("level %d is %.2f -- no step may be zero, or a dial becomes a second mute "
					+ "and unmuting has to guess what to come back to") % [step, Sfx.LEVELS[step]])
		if err == "":
			err = _T.assert_float_eq(Sfx.LEVELS[Sfx.DEFAULT_LEVEL], 1.0, 0.0001,
				"and index 0 is FULL, so a default save reads svol0 and the shipped mix is unchanged")
		if err == "":
			# Orthogonal, demonstrated rather than asserted about: mute and unmute
			# across a level change, and the level is exactly where it was left.
			Sfx.set_level(2)
			Sfx.set_muted(true)
			Sfx.set_muted(false)
			err = _T.assert_eq(Sfx.level(), 2,
				"muting and unmuting leaves the chosen level alone -- nothing is stashed anywhere")
		if err == "":
			err = _T.assert_false(Sfx.is_muted(),
				"and the level did not silently mute anything on its way past")
		return err)


## The round trip proper, byte-exact on the file, through the real setters and the
## real parser.
func test_the_two_levels_round_trip_through_the_save() -> String:
	return _with_scratch_save(0, 0, null, func() -> String:
		# Through the setters, not by assigning the fields: the setter is what the
		# Options screen reaches, and it is the half that writes the file.
		var err: String = _T.assert_eq(RunConfig.set_sfx_level(2), 2,
			"set_sfx_level hands back what it stored")
		if err == "":
			err = _T.assert_eq(RunConfig.set_music_level(1), 1, "and so does the music half")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH),
				"v%d\n0\n0\nm0\ncb0 sfx0 mus0 spd0 svol2 mvol1\nd0\n0\n" % RunConfig.SAVE_VERSION,
				"the two levels are the fifth and sixth fields of the preferences line")
		if err == "":
			# Wipe first, or a `_load` that never touched them would pass by leaving
			# what it found.
			RunConfig.sfx_level = 0
			RunConfig.music_level = 0
			RunConfig._load()
			err = _T.assert_eq(RunConfig.load_status, "loaded",
				"a file this build just wrote reads back as current, not as migrated")
		if err == "":
			err = _T.assert_eq(RunConfig.sfx_level, 2, "and the effects level comes back")
		if err == "":
			err = _T.assert_eq(RunConfig.music_level, 1, "and the music level with it")
		if err == "":
			# `_load` is data only -- the mixer is `apply_audio_levels`'s job, and that
			# split is what keeps a parser test from retuning the whole suite.
			Sfx.set_level(0)
			Music.set_level(0)
			RunConfig._load()
			err = _T.assert_eq(Sfx.level(), 0,
				"_load does NOT touch the mixer: AudioServer is process-global, so only apply_audio_levels may")
		if err == "":
			RunConfig.apply_audio_levels()
			err = _T.assert_eq(Sfx.level(), 2, "and apply_audio_levels is the one door that does")
		if err == "":
			err = _T.assert_eq(Music.level(), 1, "for both halves")
		return err)


## An index this build has no level for is REFUSED at the setter and KEPT from a
## save — the same asymmetry `store_game_speed` / `MAX_SPEED_STEP` draws, for the
## same reason: a caller's off-by-one must not be persisted forever, and a file
## from a later build must not cost two high scores that cannot be re-earned.
func test_a_level_this_build_has_no_step_for_is_refused_by_the_setter_and_kept_from_a_save() -> String:
	return _with_scratch_save(0, 0, null, func() -> String:
		var past_the_end: int = Sfx.LEVELS.size()
		RunConfig.sfx_level = 1
		var err: String = _T.assert_eq(RunConfig.set_sfx_level(past_the_end), 1,
			"a step this build has no level for is refused and the stored one is kept")
		if err == "":
			err = _T.assert_eq(RunConfig.set_sfx_level(-1), 1, "and so is a negative one")
		return err)


## Read from a save rather than from a caller, which is the other side of the rule
## above: a later build's eighth step is data this one must not destroy.
func test_a_level_from_a_later_build_is_read_and_kept_and_falls_back_to_full() -> String:
	var future: String = ("v%d\n40\n50\nm0\ncb0 sfx0 mus0 spd0 svol%d mvol0\nd0\n0\n"
		% [RunConfig.SAVE_VERSION, RunConfig.MAX_LEVEL_STEP])
	return _with_scratch_save(0, 0, future, func() -> String:
		RunConfig._load()
		var err: String = _T.assert_eq(RunConfig.load_status, "loaded",
			"a level index this build has no step for does not condemn the file")
		if err == "":
			err = _T.assert_eq(RunConfig.sfx_level, RunConfig.MAX_LEVEL_STEP,
				"the index is KEPT, so a downgrade does not silently rewrite it away")
		if err == "":
			err = _T.assert_eq(RunConfig.campaign_high_score, 40,
				"and the scores in the same file survive it")
		if err == "":
			# Refused at the point of USE instead, exactly like apply_game_speed.
			err = _T.assert_float_eq(Sfx.level_db(RunConfig.MAX_LEVEL_STEP),
				Sfx.level_db(Sfx.DEFAULT_LEVEL), 0.0001,
				"and it is refused where it is used: an unreadable level plays at full, not silent")
		return err)


## What an OLD save does when the fields are absent. Follows
## `test_a_save_written_before_the_speed_field_...` deliberately, including the
## milestone and the rebound key: what goes wrong in a bump is never the new field,
## it is an OLD one defaulted and written back out empty by the migration rewrite.
func test_a_save_written_before_the_levels_reads_as_full_and_is_rewritten() -> String:
	var original: String = "v7\n70\n80\nm1:threat_peak\ncb1 sfx1 mus0 spd1\n1\ngarden_pause 4194332\n"
	return _with_scratch_save(0, 0, original, func() -> String:
		RunConfig._load()
		var err: String = _T.assert_eq(RunConfig.load_status, "migrated",
			"a v7 file is read forward, not refused")
		if err == "":
			err = _T.assert_eq(RunConfig.sfx_level, 0,
				("a save with no level fields reads as full -- a player who never had the "
					+ "dial had a game at the volume it shipped with"))
		if err == "":
			err = _T.assert_eq(RunConfig.music_level, 0, "and the same for the music half")
		if err == "":
			# THE FIELD THE BUMP COULD HAVE COST, and the reason a v8 line ADDS two
			# fields rather than widening `sfx`/`mus` from a flag into a level: a save
			# that already said `sfx1 mus0` still means effects muted, music audible.
			err = _T.assert_true(RunConfig.mute_sfx,
				"its effects mute survives the bump meaning exactly what it meant")
		if err == "":
			err = _T.assert_false(RunConfig.mute_music, "and its music mute stays off")
		if err == "":
			err = _T.assert_eq(RunConfig.game_speed_step, 1, "and the speed under it is untouched")
		if err == "":
			err = _T.assert_true(RunConfig.has_milestone("threat_peak"),
				"and its milestone survives")
		if err == "":
			err = _T.assert_eq(RunConfig.key_bindings.size(), 1,
				"and so does its rebound key -- the field under the line that moved")
		if err == "":
			err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH),
				"v%d\n70\n80\nm1:threat_peak\ncb1 sfx1 mus0 spd1 svol0 mvol0\nd0\n1\ngarden_pause 4194332\n"
					% RunConfig.SAVE_VERSION,
				"and it is rewritten once in the new shape, with the levels defaulted in place")
		if err == "":
			RunConfig._load()
			err = _T.assert_eq(RunConfig.load_status, "loaded",
				"the migrated file loads as current next time, rather than migrating forever")
		return err)


## The two level fields are the second and third on that line that are not flags,
## so their own malformed shapes need the same sweep the speed field got.
##
## Every fixture here is SIX fields — the current shape — so each one fails on the
## field it names rather than on the count. The four-field cases in
## `test_a_save_with_a_broken_options_line_is_refused_whole` are still refused at
## v8, but they are now refused for being short, which is not what they were
## written to check.
func test_a_save_with_a_broken_level_field_is_refused_whole() -> String:
	var cases: Dictionary = {
		"a level field with no digits":
			"v%d\n4321\n8765\nm0\ncb0 sfx0 mus0 spd0 svol mvol0\nd0\n" % RunConfig.SAVE_VERSION,
		"a level field that is not a number":
			"v%d\n4321\n8765\nm0\ncb0 sfx0 mus0 spd0 svolx mvol0\nd0\n" % RunConfig.SAVE_VERSION,
		"a negative level":
			"v%d\n4321\n8765\nm0\ncb0 sfx0 mus0 spd0 svol-1 mvol0\nd0\n" % RunConfig.SAVE_VERSION,
		"a level past the bound":
			"v%d\n4321\n8765\nm0\ncb0 sfx0 mus0 spd0 svol%d mvol0\nd0\n"
				% [RunConfig.SAVE_VERSION, RunConfig.MAX_LEVEL_STEP + 1],
		# The whole reason each field carries its own marker. The two levels are
		# adjacent fields about the same subject, so a transposition is the mistake
		# most likely to actually happen and the one a bare digit could not catch.
		"the two levels transposed":
			"v%d\n4321\n8765\nm0\ncb0 sfx0 mus0 spd0 mvol0 svol0\n" % RunConfig.SAVE_VERSION,
		"a level field wearing the mute's marker":
			"v%d\n4321\n8765\nm0\ncb0 sfx0 mus0 spd0 sfx0 mvol0\nd0\n" % RunConfig.SAVE_VERSION,
		"the music level missing":
			"v%d\n4321\n8765\nm0\ncb0 sfx0 mus0 spd0 svol0\n" % RunConfig.SAVE_VERSION,
		"a seventh field":
			"v%d\n4321\n8765\nm0\ncb0 sfx0 mus0 spd0 svol0 mvol0 xyz1\n" % RunConfig.SAVE_VERSION,
	}
	for what: String in cases:
		var err: String = _with_scratch_save(4321, 8765, cases[what],
			func() -> String: return _assert_refused(4321, 8765, what))
		if err != "":
			return err
	return ""


## The geometry answer (plant-tower-defense-1490), asserted rather than left in a
## comment — which is the whole complaint that bead makes about the shipped PANEL.
##
## The panel GROWS to its rows now instead of the rows being trusted to fit it, so
## the binding constraint moved from the paper to the viewport. Both halves are
## checked here: the derivation holds for the rows the screen actually declares, and
## the ceiling it is heading toward is a real one rather than infinity.
func test_the_options_panel_grows_to_its_rows_and_stays_on_the_screen() -> String:
	var rows: int = OptionsScreen.OPTIONS.size() + OptionsScreen.DIALS.size()
	var height: float = OptionsScreen.panel_height()
	var last_row_foot: float = (OptionsScreen.ROWS_TOP + float(rows - 1) * OverlayScreen.ROW_HEIGHT
		+ OverlayScreen.ROW_BUTTON_SIZE.y)
	var footer_top: float = (OptionsScreen.PANEL.position.y + height
		- OverlayScreen.FOOTER_HEIGHT - OverlayScreen.FOOTER_INSET)
	var err: String = _T.assert_gt(rows, OptionsScreen.OPTIONS.size(),
		"the screen has dials as well as switches, or this item did not land")
	if err == "":
		err = _T.assert_true(footer_top - last_row_foot >= OverlayScreen.FOOTER_GAP,
			("the footer stands %.1fpx clear of the last of %d rows, against a FOOTER_GAP of %.1f"
				% [footer_top - last_row_foot, rows, OverlayScreen.FOOTER_GAP]))
	if err == "":
		err = _T.assert_true(OptionsScreen.PANEL.position.y + height <= 648.0,
			("the paper's foot is at %.1f in a 648-tall viewport"
				% [OptionsScreen.PANEL.position.y + height]))
	if err == "":
		err = _T.assert_true(rows <= OptionsScreen.rows_capacity(),
			("%d rows against a capacity of %d -- if this fails, the fix is ROWS_TOP, the row "
				+ "pitch or the header block, NOT a clamp inside panel_height()")
				% [rows, OptionsScreen.rows_capacity()])
	if err == "":
		# A capacity that is not a real ceiling would make the assertion above a
		# formality. One more row than it allows must genuinely run off the screen.
		var over: int = OptionsScreen.rows_capacity() + 1
		var over_foot: float = (OptionsScreen.ROWS_TOP + float(over - 1) * OverlayScreen.ROW_HEIGHT
			+ OverlayScreen.ROW_BUTTON_SIZE.y + OverlayScreen.FOOTER_GAP
			+ OverlayScreen.FOOTER_HEIGHT + OverlayScreen.FOOTER_INSET)
		err = _T.assert_true(over_foot > 648.0,
			("row %d would put the paper's foot at %.1f, off a 648-tall screen -- so the "
				+ "capacity is a ceiling and not a formality") % [over, over_foot])
	if err == "":
		# The shipped three-switch layout is pixel-identical: the floor is doing its
		# job, so nobody's screen moved because the arithmetic became a function.
		err = _T.assert_true(height >= OptionsScreen.PANEL.size.y,
			"and PANEL's height is a floor, so the panel can only ever grow from where it shipped")
	return err


## The cycle itself, as pure functions, before any screen or save is involved.
## `next_level` is split out of the button for the reason `Sfx.kill_event_for` was:
## a ternary at a call site is a decision no test can watch.
func test_the_dial_cycles_through_every_level_and_wraps() -> String:
	return _with_scratch_save(0, 0, null, func() -> String:
		var seen: Array[int] = []
		var step: int = Sfx.DEFAULT_LEVEL
		for _i: int in Sfx.LEVELS.size():
			seen.append(step)
			step = Sfx.next_level(step)
		var err: String = _T.assert_eq(step, Sfx.DEFAULT_LEVEL,
			"cycling once per level comes back to where it started")
		if err == "":
			err = _T.assert_eq(seen.size(), Sfx.LEVELS.size(),
				"and every level is reachable by pressing -- %s" % [seen])
		if err == "":
			# A wrap that skipped one would still return to 0 and still have the right
			# length if it visited the same step twice.
			for i: int in seen.size():
				err = _T.assert_eq(seen[i], i, "step %d of the cycle is level %d" % [i, i])
				if err != "":
					break
		if err == "":
			err = _T.assert_eq(Sfx.next_level(Sfx.LEVELS.size() + 9), Sfx.next_level(Sfx.DEFAULT_LEVEL),
				"and a step this build has no level for cycles on from full rather than erroring")
		if err == "":
			# The text is derived from LEVELS, so a fifth step cannot arrive unnamed.
			err = _T.assert_eq(Sfx.level_text(Sfx.DEFAULT_LEVEL), "100%",
				"full reads as 100%% -- got %s" % [Sfx.level_text(Sfx.DEFAULT_LEVEL)])
		if err == "":
			err = _T.assert_eq(Sfx.cycle_level(), Sfx.next_level(Sfx.DEFAULT_LEVEL),
				"Sfx.cycle_level advances the live mixer by one step")
		if err == "":
			err = _T.assert_eq(Music.cycle_level(), Sfx.next_level(Sfx.DEFAULT_LEVEL),
				"and Music.cycle_level does the same on its own bus")
		if err == "":
			var quiet: int = Sfx.LEVELS.size() - 1
			err = _T.assert_float_eq(Sfx.apply_bus_level(Sfx.BUS_NAME, quiet), Sfx.level_db(quiet), 0.001,
				"apply_bus_level reports the dB it wrote, so nobody has to read the mixer back")
		if err == "":
			# The doors the row buttons actually go through, named directly rather than
			# only reached via OptionsScreen.cycle: `Sfx.cycle_level` moves the mixer and
			# nothing else, and a screen wired to THAT would be a dial the save never
			# hears about. These are the pair that move both halves.
			Sfx.set_level(0)
			RunConfig.sfx_level = 0
			err = _T.assert_eq(RunConfig.cycle_sfx_level(), Sfx.next_level(0),
				"RunConfig.cycle_sfx_level advances the mixer AND records it")
		if err == "":
			err = _T.assert_eq(RunConfig.sfx_level, Sfx.level(),
				"leaving the remembered index and the live bus in step")
		if err == "":
			Music.set_level(0)
			RunConfig.music_level = 0
			err = _T.assert_eq(RunConfig.cycle_music_level(), Sfx.next_level(0),
				"and RunConfig.cycle_music_level does the same for the bed")
		return err)


## The player's actual route to the dial: the row on the Options screen, pressed.
##
## Not folded into `_with_scratch_save` because this one has to `await` the UI up,
## and that wrapper takes a Callable whose return it stringifies — a coroutine
## handed to it would be silently mangled. The stash and the restore are therefore
## called by hand here, and `teardown()` calls the restore again on an aborted run.
func test_pressing_a_dial_row_turns_the_volume_down_and_writes_it_down() -> String:
	_stash_run_config()
	RunConfig.save_path = HIGHSCORE_TEST_PATH
	RunConfig.campaign_high_score = 0
	RunConfig.endless_high_score = 0
	RunConfig.earned_milestones = {}
	RunConfig.colorblind_safe = false
	RunConfig.mute_sfx = false
	RunConfig.mute_music = false
	RunConfig.game_speed_step = 0
	RunConfig.sfx_level = 0
	RunConfig.music_level = 0
	Sfx.set_level(0)
	Music.set_level(0)

	var screen := await _T.instantiate_ui(OptionsScreen.new(), Vector2i(1152, 648)) as OptionsScreen
	var declared: Array[StringName] = []
	for row: Dictionary in OptionsScreen.DIALS:
		declared.append(StringName(row["id"]))

	var err: String = _T.assert_eq(screen.dials(), declared,
		"the screen draws every dial the table declares, in table order")
	if err == "":
		err = _T.assert_eq(screen.rows().size(), OptionsScreen.OPTIONS.size(),
			"and rows() still means the SWITCHES -- the dials are a second table, not three more switches")
	for j: int in screen.dials().size():
		if err != "":
			break
		var id: StringName = screen.dials()[j]
		# The dials are drawn under the switches, so their row index is offset.
		var index: int = screen.rows().size() + j
		var label: Label = screen.get_node_or_null("Row%d" % index) as Label
		var key: Label = screen.get_node_or_null("RowKey%d" % index) as Label
		var button: Button = screen.get_node_or_null("RowButton%d" % index) as Button
		err = _T.assert_true(label != null and key != null and button != null,
			"dial %d (%s) has a name, a key cell and a button at row %d" % [j, id, index])
		if err == "":
			err = _T.assert_true(OptionsScreen.is_dial(id), "%s is a dial and not a switch" % [id])
		if err == "":
			err = _T.assert_eq(label.text, OptionsScreen.describe(id), "row %d says what it is" % index)
		if err == "":
			# Blank, not "unbound": there is no key for a level, and a key cell reading
			# "unbound" would claim there is a binding waiting to be made.
			err = _T.assert_eq(key.text, "", "row %d shows no key, because a dial has none" % index)
		if err == "":
			err = _T.assert_eq(button.text, OptionsScreen.level_text(id),
				"row %d reads the mixer rather than a copy the screen kept" % index)
		if err == "":
			err = _T.assert_true(button.size.x >= 40.0 and button.size.y >= 40.0,
				"row %d's button is a real touch target" % index)
		if err == "":
			var was: int = OptionsScreen.level_of(id)
			button.pressed.emit()
			err = _T.assert_eq(OptionsScreen.level_of(id), Sfx.next_level(was),
				"pressing row %d turns %s one step" % [index, id])
		if err == "":
			err = _T.assert_eq(button.text, OptionsScreen.level_text(id),
				"and the button says the new level afterwards")
	if err == "":
		# The half a mixer-only dial would fail: the press has to reach the file, not
		# just the bus, or the level is gone at the next launch.
		err = _T.assert_eq(FileAccess.get_file_as_string(HIGHSCORE_TEST_PATH),
			"v%d\n0\n0\nm0\ncb0 sfx0 mus0 spd0 svol1 mvol1\nd0\n0\n" % RunConfig.SAVE_VERSION,
			"and both presses are in the save, not held for the session")
	if err == "":
		# `turn` is the screen's own door and the only writer the buttons have; named
		# directly so it is exercised rather than only reached through a signal.
		err = _T.assert_eq(screen.turn(OptionsScreen.SFX_LEVEL), Sfx.level(),
			"turn() reports where the dial landed, and the mixer agrees")
	if err == "":
		err = _T.assert_eq(RunConfig.sfx_level, Sfx.level(),
			"and the remembered index and the live mixer never come apart")

	_T.free_ui(screen)
	_restore_run_config()
	return err


# -- BEGIN plant-tower-defense-b7v5 / plant-tower-defense-lp97 ----------------
#
# plant-tower-defense-lp97 ("Tell the player what the run cost") ships NO CODE and
# NO TEST, because its premise is false and the check is worth more than the row
# would have been. The bead says "Not one row is about seeds" and
# "SeedBank.seeds_earned_total ... reaches no screen". Both were true when it was
# filed and neither is true now: commit 738f787 gave the card a fourth row,
# `["Seeds spent", spend_text()]`, and `_score_line()` has printed
# "%d seeds grown — your best %s is %d" straight off `seeds_earned_total` since the
# card existed. The bead's own ACCEPTANCE — "the card says something about the run's
# economy" — is met twice over, so the row it asks for would be a third statement of
# a fact the screen already makes. See the lane report; the bead wants closing, not
# implementing.
#
# plant-tower-defense-b7v5 is the rest of this block. The mechanic — a cob fires at
# the pest furthest along, so covered ground fights one pest at a time — has been
# measured three times (game.gd's coverage block, test_combat's
# test_the_coverage_map_keeps_its_promise_to_a_pest_that_never_leaves_covered_ground)
# and never once stated to the player. RunSummary.reach_note_text() states it. The
# card had no room for a row and no room in a fold, so it is a sentence on the strip
# under the card, one line below the map legend; the doc comment on the method
# carries that argument in full.
#
# The last test here is the WIRING gate and it is expected to fail until
# `Game.summary_stats` exports `road_aimed` and `road_cells`. That edit is in the
# lane report; this lane does not own game.gd. A note the game never populates is a
# note that never appears, so the gate is deliberately a failing test rather than a
# paragraph nobody reads.


func test_the_reach_note_says_covered_is_not_fought_and_is_silent_when_it_is_not_true() -> String:
	## Every branch of reach_note_text() off a plain Dictionary, no Control built —
	## the same shape summary_rows() and map_legend_text() are asserted in, and the
	## reason the method is public rather than inlined into _build_reach_note().
	##
	## The three silences matter more than the sentence: each one is a real run, and
	## each would otherwise print a true-looking line teaching the wrong lesson.
	var unwired := RunSummary.build({
		"escapes_recorded": 4, "escapes_untouched": 4,
	})
	var err: String = _T.assert_eq(unwired.reach_note_text(), "",
		"a card that was never handed the coverage says nothing, rather than inventing a 0 of 0")
	unwired.free()

	if err == "":
		var barren := RunSummary.build({
			"road_cells": 32, "road_aimed": 0,
			"escapes_recorded": 4, "escapes_untouched": 4,
		})
		err = _T.assert_eq(barren.reach_note_text(), "",
			("a garden that could touch no road at all has no covered ground for"
				+ " 'covered' to contrast with, so the targeting rule is not its lesson"))
		barren.free()

	if err == "":
		var unwatched := RunSummary.build({
			"road_cells": 32, "road_aimed": 30,
			"escapes_recorded": 0, "escapes_untouched": 0,
		})
		err = _T.assert_eq(unwatched.reach_note_text(), "",
			"a run that could read none of its escapes claims nothing about them")
		unwatched.free()

	if err == "":
		var fought := RunSummary.build({
			"road_cells": 32, "road_aimed": 30,
			"escapes_recorded": 4, "escapes_untouched": 0,
		})
		err = _T.assert_eq(fought.reach_note_text(), "",
			"and a run where every escape was fought did not meet this mechanic")
		fought.free()

	if err == "":
		var bitten := RunSummary.build({
			"road_cells": 32, "road_aimed": 30,
			"escapes_recorded": 4, "escapes_untouched": 4,
		})
		err = _T.assert_eq(bitten.reach_note_text(),
			("30 of 32 road cells were aimed at, and 4 still walked in untouched"
				+ " — a cob fires at the furthest pest only."),
			"the run it exists for names both halves and then names the rule")
		if err == "":
			# The distinction has to survive the player reading only the words, so it
			# is checked as words and not as a colour or a position.
			err = _T.assert_true(bitten.reach_note_text().contains("aimed at")
					and bitten.reach_note_text().contains("untouched"),
				"and states both sides in the sentence itself, not by sitting near another row")
		bitten.free()

	if err == "":
		# A count of aimed cells larger than the road is a wiring mistake, not a
		# reading, and the sentence must not print "40 of 32" while it is being made.
		var overclaimed := RunSummary.build({
			"road_cells": 32, "road_aimed": 40,
			"escapes_recorded": 1, "escapes_untouched": 1,
		})
		err = _T.assert_true(overclaimed.reach_note_text().begins_with("32 of 32"),
			"an over-large aimed count is clamped to the road, got '%s'"
				% overclaimed.reach_note_text())
		overclaimed.free()
	return err


func test_the_reach_note_fits_its_box_and_survives_the_cards_own_entrance() -> String:
	## The layout budget, measured rather than asserted in prose.
	##
	## The card had none left: RunSummary.rows_capacity() returns 7 against the 7 rows
	## summary_rows() builds, and that is asserted here rather than trusted, because
	## it is the whole reason this sentence is not simply an eighth row.
	##
	## The rejected position is measured too. A second 20px strip under the map legend
	## looks free against a 648-tall viewport and is not: _play_entrance drops every
	## child by RISE_OFFSET_WIN before tweening it back, so the real floor is
	## 648 - 32. The negative control below is what makes that a measurement instead
	## of a paragraph — it fails if somebody raises the viewport or drops the rise and
	## the strip becomes available after all.
	var err: String = _T.assert_eq(RunSummary.rows_capacity(), 7,
		"the card holds seven rows")
	if err == "":
		var card := RunSummary.build({})
		err = _T.assert_eq(card.summary_rows().size(), RunSummary.rows_capacity(),
			"and is already full, so a new subject on it is a swap and never an addition")
		card.free()

	var screen: float = float(ProjectSettings.get_setting(
		"display/window/size/viewport_height", 648))
	if err == "":
		var rejected: float = RunSummary.MAP_LEGEND_Y + RunSummary.MAP_LEGEND_HEIGHT + 20.0
		err = _T.assert_true(rejected + RunSummary.RISE_OFFSET_WIN > screen,
			("a second 20px line under the legend would foot at %.0f and hang off a"
				+ " %.0f-tall screen through the rise — this is why the note is not there")
					% [rejected + RunSummary.RISE_OFFSET_WIN, screen])
	if err != "":
		return err

	var panel := RunSummary.build({
		"victory": true,
		"lives_lost": Game.LIVES,
		"escapes_recorded": Game.LIVES,
		"escapes_untouched": 4,
		"road_cells": 32,
		"road_aimed": 30,
	})
	await _T.instantiate_ui(panel, Vector2i(1152, 648))
	var box: Panel = panel.get_node_or_null("ReachNote") as Panel
	err = _T.assert_true(box != null, "the reach note is on the screen")
	if err != "":
		_T.free_ui(panel)
		return err
	var note: Label = box.get_node_or_null("ReachNoteText") as Label
	err = _T.assert_true(note != null, "with the sentence inside it")
	if err != "":
		_T.free_ui(panel)
		return err
	err = _T.assert_eq(note.text, panel.reach_note_text(),
		"and the label carries the string the formatter builds, not a second copy of the format")

	# 1. Beside the card, not over it — the column the ribbon opened.
	if err == "":
		err = _T.assert_false(Rect2(box.position, box.size).intersects(RunSummary.CARD),
			"the note at (%.0f, %.0f) %.0fx%.0f does not sit on the card"
				% [box.position.x, box.position.y, box.size.x, box.size.y])
	if err == "":
		err = _T.assert_true(box.position.x + box.size.x <= 1152.0,
			"and its right edge %.0f is on the screen" % [box.position.x + box.size.x])

	# 2. The rise budget, at the worst ribbon this game can produce.
	if err == "":
		var worst_top: float = RunSummary.reach_note_top(Milestones.TABLE.size())
		var worst_foot: float = worst_top + RunSummary.REACH_NOTE_HEIGHT
		err = _T.assert_true(worst_top >= RunSummary.RIBBON_TOP
				+ RunSummary.ribbon_height(Milestones.TABLE.size()),
			"a full ribbon does not push the note into itself (%.0f against %.0f)"
				% [worst_top, RunSummary.RIBBON_TOP
					+ RunSummary.ribbon_height(Milestones.TABLE.size())])
		if err == "":
			err = _T.assert_true(worst_foot + RunSummary.RISE_OFFSET_WIN <= screen,
				("and even under a full ribbon it foots at %.0f, %.0f through the rise,"
					+ " inside a %.0f-tall screen")
						% [worst_foot, worst_foot + RunSummary.RISE_OFFSET_WIN, screen])
		if err == "":
			# The empty ribbon is the common case and must not leave a hole above it.
			err = _T.assert_float_eq(RunSummary.reach_note_top(0), RunSummary.RIBBON_TOP,
				0.001, "and with no milestones it takes the top of the column")

	# 3. The sentence fits its box. NOT _T.text_width, which measures the unwrapped
	#    string and cannot see a wrap; and NOT get_minimum_size(), which is the wrong
	#    answer on every Label this screen draws. An overflowing wrapped Label loses
	#    lines off the bottom, and that is what is counted.
	if err == "":
		err = _T.assert_gt(note.get_line_count(), 0, "the sentence laid out at all")
	if err == "":
		err = _T.assert_eq(note.get_visible_line_count(), note.get_line_count(),
			"every one of its %d wrapped lines is inside the box" % note.get_line_count())
	var short_text: String = note.text
	_T.free_ui(panel)
	if err != "":
		return err

	# The WORST case, built by the formatter rather than typed out: a road that grew
	# to four digits, every cell of it aimed at, and every bed lost to a pest nothing
	# ever touched. Hosted as its own card rather than assigned onto the label above,
	# because a wrapped line count read in the same frame the text changed is a read
	# of the previous layout.
	var wide := RunSummary.build({
		"road_cells": 999, "road_aimed": 999,
		"escapes_recorded": Game.LIVES, "escapes_untouched": Game.LIVES,
	})
	await _T.instantiate_ui(wide, Vector2i(1152, 648))
	var wide_note: Label = wide.get_node_or_null("ReachNote/ReachNoteText") as Label
	err = _T.assert_true(wide_note != null, "the worst-case card drew a note too")
	if err == "":
		err = _T.assert_gt(wide_note.text.length(), short_text.length(),
			"and the worst case really is the longer string")
	if err == "":
		err = _T.assert_gt(wide_note.get_line_count(), 0, "which laid out")
	if err == "":
		err = _T.assert_eq(wide_note.get_visible_line_count(), wide_note.get_line_count(),
			"and still fits its box, at %d wrapped lines" % wide_note.get_line_count())
	_T.free_ui(wide)
	return err


func test_the_run_summary_is_handed_the_coverage_it_needs_to_name_the_mechanic() -> String:
	## The wiring gate, and the bead's ACCEPTANCE: "a test asserts the line against a
	## run with known coverage and known untouched pests".
	##
	## FAILS UNTIL `Game.summary_stats` exports `road_aimed` and `road_cells`. That
	## edit belongs to a file this lane does not own; the exact two lines are in the
	## lane report. Written as a failing test rather than as a comment because a
	## sentence the game never populates is a sentence that never appears, and the
	## silent branch in reach_note_text() makes that failure invisible on screen.
	##
	## Both numbers are read back off the game's OWN functions rather than against
	## literals, so the assertion is "the card is handed what the board knows" and
	## not "the road is 32 cells long" — which is a fact about this map and would
	## have to be re-typed the day the map changes.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the run stood up")
	if err != "":
		return err
	game.bank.add_seeds(400)

	# The buildable cell that covers the most road, derived from the same
	# covered_road_cell_list() the coverage map itself is built from rather than
	# hand-picked — a hand-picked cell is one map edit away from covering nothing
	# and turning every assertion below into a check of the aimed <= 0 silence.
	var reach: float = Game.engagement_reach(PlantCatalog.CORN)
	var best := Vector2i(-1, -1)
	var best_cover: int = 0
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var cell := Vector2i(x, y)
			if not game.board.is_buildable(cell) or game.plant_at(cell) != null:
				continue
			var covers: int = PlacementPreview.covered_road_cell_list(
				game.board, cell, reach).size()
			if covers > best_cover:
				best_cover = covers
				best = cell
	err = _T.assert_gt(best_cover, 0, "some buildable cell on this map can reach the road")
	if err == "":
		err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, best), "",
			"and a cob goes into it")
	if err == "":
		err = _T.assert_eq(game.covered_road_cells().size(), best_cover,
			"the garden's coverage is exactly what that one cob reaches")

	# A known untouched pest: spawned, never shot at, walked out.
	if err == "":
		var pest: Pest = _spawn_and_take(game, Pest.APHID)
		err = _T.assert_true(pest != null, "a pest is on the road")
		if err == "":
			err = _T.assert_false(pest.was_engaged(),
				"and nothing has touched it — the flag the untouched count reads")
		if err == "":
			game._on_pest_escaped(pest)
			err = _T.assert_eq(game._escapes_untouched, 1, "so it escapes untouched")

	var stats: Dictionary = {}
	if err == "":
		stats = game.summary_stats(false)
		err = _T.assert_true(stats.has("road_cells") and stats.has("road_aimed"),
			("summary_stats exports the coverage the post-mortem needs"
				+ " — add \"road_aimed\" and \"road_cells\", see plant-tower-defense-b7v5"))
	if err == "":
		err = _T.assert_eq(int(stats["road_cells"]), game.board.road_cells().size(),
			"the denominator is the board's own road, not a copy of it")
	if err == "":
		err = _T.assert_eq(int(stats["road_aimed"]), game.covered_road_cells().size(),
			"and the numerator is the same derived map the board and the hover cue read")
	if err == "":
		err = _T.assert_gt(int(stats["road_cells"]), int(stats["road_aimed"]),
			"one cob does not cover the whole road, so this run really is the contrast case")

	if err == "":
		var panel := RunSummary.build(stats)
		var text: String = panel.reach_note_text()
		err = _T.assert_eq(text, ("%d of %d road cells were aimed at, and 1 still walked in"
			+ " untouched — a cob fires at the furthest pest only.")
				% [int(stats["road_aimed"]), int(stats["road_cells"])],
			"and the card says so, in the numbers the run actually produced")
		panel.free()
	_T.free_ui(game)
	return err


# -- END plant-tower-defense-b7v5 / plant-tower-defense-lp97 ------------------


# -- BEGIN plant-tower-defense-dgu5 -------------------------------------------
#
# The post-mortem's reach par: how few cobs it takes to put every road cell inside
# one, printed against how much road this run's garden actually reached.
#
# The number was already written and already tested — in `test_combat._cover_greedily`,
# where the game cannot read it. `RunSummary.reach_cover` is that logic lifted into the
# game, which is the direction `derive-the-list` insists on; the duplicate left behind
# in test_combat is a follow-up, and until it is collapsed the first test below gates
# THIS copy against the property a cover claims rather than against the other copy's
# answer. That is deliberate: two greedy covers agreeing proves they were copied from
# each other, and one covering the road proves the thing the card says.
#
# What these do NOT assert is that a par-sized garden would win. It would not, and that
# is the point of the row's wording: cycle 54 found five cobs reaching all 32 road cells
# and BROKE TWO TESTS with them, because a cob shoots only the furthest-along pest in
# range. The row says "reach alone" and never says a plant count, and the second test
# below is what holds it to that.


## The cover is a cover — every cell buildable, every road cell reached, and nothing in
## it spare. Pure: no Control, no stats Dictionary, no run.
##
## The irredundancy half is what makes "takes N cobs" a claim rather than a length.
## Greedy cannot prove no smaller cover exists — it exhibits one, which is exactly what
## "N is enough for reach" needs — but a cover carrying a cell that reaches nothing new
## would inflate the number the card prints, and that is checkable.
func test_the_reach_par_is_a_real_cover_of_this_road() -> String:
	var probe := Board.new()
	var road: Array[Vector2i] = probe.road_cells()
	var reach: float = RunSummary.par_reach_px()
	var err: String = _T.assert_gt(road.size(), 2,
		"the untreed probe board traced a road to cover — an empty one would make every"
			+ " assertion below true of nothing")
	if err == "":
		err = _T.assert_float_eq(reach, CornCobbler.RANGE, 0.01,
			("the par is measured in cob reach, read through PlantCatalog rather than"
				+ " typed here, so a balance change moves it"))

	var cover: Array[Vector2i] = []
	if err == "":
		cover = RunSummary.reach_cover(probe, reach)
		err = _T.assert_gt(cover.size(), 0, "and greedy found a cover at all")
	if err == "":
		err = _T.assert_true(cover.size() < road.size(),
			("the cover is smaller than the road (%d cells against %d) — a par the size of"
				+ " the road is not a benchmark") % [cover.size(), road.size()])

	# Every cell is somewhere a plant may actually stand. A cover that had drifted onto
	# road would be refused at placement and the card would be quoting a garden nobody
	# can build — the same failure `test_the_recorded_gardens_still_have_the_property_
	# they_claim` was written for next door.
	var standable: int = 0
	if err == "":
		for at: Vector2i in cover:
			err = _T.assert_true(probe.is_buildable(at),
				"%s is somewhere a plant may stand, not road" % at)
			if err != "":
				break
			standable += 1
		if err == "":
			err = _T.assert_eq(standable, cover.size(),
				"and every cell in the cover was really checked")

	if err == "":
		var reached: Dictionary = {}
		for at: Vector2i in cover:
			for cell: Vector2i in PlacementPreview.covered_road_cell_list(probe, at, reach):
				reached[cell] = true
		err = _T.assert_eq(reached.size(), road.size(),
			("the cover reaches every one of the %d road cells — that is the whole of what"
				+ " the card claims for it") % road.size())

	# Nothing spare in it.
	var pruned: int = 0
	if err == "":
		for i: int in range(cover.size()):
			var without: Dictionary = {}
			for j: int in range(cover.size()):
				if j == i:
					continue
				for cell: Vector2i in PlacementPreview.covered_road_cell_list(
						probe, cover[j], reach):
					without[cell] = true
			err = _T.assert_true(without.size() < road.size(),
				("dropping %s leaves road unreached (%d of %d), so it is not padding the"
					+ " number the card prints") % [cover[i], without.size(), road.size()])
			if err != "":
				break
			pruned += 1
		if err == "":
			err = _T.assert_eq(pruned, cover.size(),
				"and every cell in the cover was really tried — a short loop is what makes"
					+ " a minimality gate vacuous")

	# One board, one garden. The tie-break is strictly-greater over candidates collected
	# in (x, y) order, so a second call must not answer differently.
	if err == "":
		var again: Array[Vector2i] = RunSummary.reach_cover(probe, reach)
		err = _T.assert_eq(again, cover,
			"the cover is deterministic — a seeded run gets the same par twice")

	probe.free()
	return err


## Every branch of the row's text off a plain Dictionary, and the one thing it must never
## say. No Control built — the shape `beds_text` and `reach_note_text` are asserted in.
func test_the_reach_row_states_reach_alone_and_never_a_plant_count() -> String:
	var probe := Board.new()
	var road: int = probe.road_cells().size()
	var par: int = RunSummary.reach_cover(probe, RunSummary.par_reach_px()).size()
	probe.free()
	var err: String = _T.assert_gt(road, 2, "there is a road for the row to be about")
	if err == "":
		err = _T.assert_gt(par, 0, "and a par to print against it")
	if err != "":
		return err

	# Nobody handed the card the coverage: a card built by a test, or by a Game that
	# predates the wiring. It says so rather than inventing an "0 of 0" — and it says
	# SOMETHING, because a row is always drawn and an empty value Label is what every
	# width gate in this suite reads as the clip_text stub.
	var unwired := RunSummary.build({})
	err = _T.assert_eq(unwired.reach_text(), "not measured",
		"an unwired card names the absence instead of fabricating a fraction")
	if err == "":
		err = _T.assert_gt(unwired.reach_text().length(), 0,
			"and it is not the empty string, which no row may be")
	unwired.free()

	# The full reading.
	var run := RunSummary.build({"road_cells": road, "road_aimed": road - 5})
	if err == "":
		err = _T.assert_eq(run.reach_par(), par,
			"the card derives the same par the cover does, off its own probe")
	if err == "":
		err = _T.assert_eq(run.reach_text(),
			"%d of %d — reach alone takes %d cobs" % [road - 5, road, par],
			"the row is the run's coverage against the benchmark")
	if err == "":
		err = _T.assert_true(run.reach_text().contains("reach alone"),
			("the wording separates reach from sufficiency — cycle 54's minimal cover"
				+ " reaches every cell and holds the road worse than a redundant one"))

	# THE TRAP, gated. A par that scored the player on how many plants they built would
	# be telling a player who just lost to build the garden that loses harder, so the row
	# must not be able to say it: two cards differing only in the size of the garden read
	# identically, and the word does not appear at all.
	if err == "":
		var many := RunSummary.build({"road_cells": road, "road_aimed": road - 5, "plants": 11})
		var few := RunSummary.build({"road_cells": road, "road_aimed": road - 5, "plants": 5})
		err = _T.assert_eq(many.reach_text(), few.reach_text(),
			"the row cannot tell an eleven-plant garden from a five-plant one")
		if err == "":
			err = _T.assert_false(many.reach_text().to_lower().contains("plant"),
				"and never names a plant count at all: '%s'" % many.reach_text())
		many.free()
		few.free()

	# Clamped, not wrapped: a numerator above its denominator is a stats dictionary that
	# does not agree with itself, and "35 of 32 reached" is worse than a capped number.
	if err == "":
		var overclaimed := RunSummary.build({"road_cells": road, "road_aimed": road + 3})
		err = _T.assert_true(overclaimed.reach_text().begins_with("%d of %d" % [road, road]),
			"an over-claimed numerator is capped at the road: '%s'" % overclaimed.reach_text())
		overclaimed.free()

	# The probe guard. A stats dictionary whose road is not this board's road is a card
	# describing a different map, so the fraction survives and the benchmark is dropped
	# rather than measured against a road the run never played.
	if err == "":
		var foreign := RunSummary.build({"road_cells": road + 900, "road_aimed": 40})
		err = _T.assert_eq(foreign.reach_par(), 0,
			"a probe that disagrees with the run's own road count vouches for nothing")
		if err == "":
			err = _T.assert_eq(foreign.reach_text(), "40 of %d" % (road + 900),
				"so the row prints the fraction with no par: '%s'" % foreign.reach_text())
		foreign.free()

	run.free()
	return err


## On the card: the row is where the swapped-out one was, the card is still seven rows,
## and both halves of it fit the columns they are drawn in.
##
## Measured through the resolved theme font via `_T.text_width`. Every value Label here
## sets `clip_text`, and a clipping Label reports a ~1px minimum by design, so a width
## gate built on `get_minimum_size()` passes for any string of any length.
##
## This is the only test in the suite that renders the row's REAL string: every other
## card in the suite is built from a stats Dictionary with no road keys in it, so they
## all draw the "not measured" branch and none of them measures the wide one.
func test_the_reach_row_replaced_the_duration_row_and_fits_the_card() -> String:
	var probe := Board.new()
	var road: int = probe.road_cells().size()
	probe.free()
	var panel := RunSummary.build({
		"victory": false,
		"endless": false,
		"wave": 10,
		"wave_count": 22,
		"threat_level": 3,
		"lives_lost": 6,
		"seeds_earned_total": 412,
		"high_score": 900,
		"compost_total": 30,
		"compost_resolved": 44,
		"pests_defeated": 180,
		"stop_cell": Vector2i(6, 3),
		"stop_cell_stops": 41,
		"road_cells": road,
		"road_aimed": road - 5,
	})
	await _T.instantiate_ui(panel, Vector2i(1152, 648))

	var rows: Array = panel.summary_rows()
	var err: String = _T.assert_eq(rows.size(), RunSummary.rows_capacity(),
		("the card is still full and no fuller — an eighth row foots at 486 against"
			+ " buttons at 476, so this row is a swap"))
	if err == "":
		err = _T.assert_eq(RunSummary.rows_capacity(), 7,
			"and the capacity really is seven, not a number that moved under the swap")

	var keys: Array[String] = []
	for row: Array in rows:
		keys.append(String(row[0]))
	if err == "":
		err = _T.assert_true(keys.has("Road in reach"),
			"the card names the road it reached, got rows: %s" % str(keys))
	if err == "":
		err = _T.assert_false(keys.has("Time in the garden"),
			("and the row it replaced is gone rather than both being on the card — the"
				+ " duration was the one row reporting nothing about the garden"))

	var value: Label = panel.get_node_or_null("Value_Roadinreach") as Label
	var key: Label = panel.get_node_or_null("Row_Roadinreach") as Label
	if err == "":
		err = _T.assert_true(value != null and key != null, "the row was really built")
	if err == "":
		err = _T.assert_eq(value.text, panel.reach_text(),
			"the row draws exactly what the builder returns, not a second copy of the format")
	if err == "":
		err = _T.assert_true(value.text.contains("cobs"),
			("and this card really is rendering the wide branch (%s) rather than the"
				+ " 'not measured' one every other card in the suite draws") % value.text)

	var column: float = RunSummary.CARD.size.x * 0.58 - RunSummary.ROW_INSET
	if err == "":
		var drawn: float = _T.text_width(value)
		err = _T.assert_gt(drawn, 1.0,
			"the font really measured '%s' — a 1px answer is the clip_text stub" % value.text)
		if err == "":
			err = _T.assert_true(drawn <= column,
				"the reach row fits its column without ellipsis (%.0f of %.0f px)"
					% [drawn, column])
	if err == "":
		# The key column, which the value's own gate cannot see: key and value boxes
		# overlap by 36px by construction, so a long key runs into the number.
		var budget: float = value.position.x - key.position.x
		var wide: float = _T.text_width(key)
		err = _T.assert_gt(wide, 1.0, "the key was really measured too")
		if err == "":
			err = _T.assert_true(wide <= budget,
				"key '%s' is %.0fpx and has %.0fpx before the value column starts"
					% [key.text, wide, budget])

	# The beds row still sets this column's high-water mark, which is the assumption
	# `test_the_worst_case_beds_row_still_fits_its_column` gates every other row against.
	if err == "":
		var beds: Label = panel.get_node_or_null("Value_Gardenlost") as Label
		err = _T.assert_true(beds != null, "the beds row is on the card to compare against")
		if err == "":
			err = _T.assert_true(_T.text_width(beds) <= column,
				"and it still fits (%.0f of %.0f px)" % [_T.text_width(beds), column])

	_T.free_ui(panel)
	return err


# -- END plant-tower-defense-dgu5 ---------------------------------------------


# -- plant-tower-defense-i8k9: hurting is not the same question as holding ------
#
# `PlantCatalog.engages` is "can this touch a pest", which its own header defines as
# "damage OR HOLD". `PlantCatalog.damages` is the narrower half, added because three
# readouts wanted it and each asked `engages` instead — getting the right answer for a
# reason unrelated to what it asked. The three tests below are, in order: that the two
# keys really are different questions, that the one production consumer now asks the
# right one, and that `damages` is derived from each plant's own damage constant
# rather than hardcoded.


## The two keys are different questions, and BOTH directions are planted.
##
## A `damages()` that answered false for everything would satisfy "the Bramble does not
## damage" and every implication assertion here, so the buckets are counted and each is
## required to be non-empty. A `damages()` that simply mirrored `engages()` would leave
## the holding-only bucket empty, which is the assertion that says the second key is
## doing work rather than being ceremony.
func test_the_catalogue_tells_hurting_apart_from_holding() -> String:
	var ids: Array[StringName] = PlantCatalog.ids()
	var err: String = _T.assert_gt(ids.size(), 1,
		"the catalogue has plants to sweep at all — an empty sweep is a vacuous pass")

	var hurting: Array[StringName] = []
	var holding_only: Array[StringName] = []
	var neither: Array[StringName] = []
	for id: StringName in ids:
		if err != "":
			break
		if PlantCatalog.damages(id):
			hurting.append(id)
			# The invariant that makes `damages` the NARROWER key rather than a second
			# unrelated one: you cannot hurt what you cannot touch.
			err = _T.assert_true(PlantCatalog.engages(id),
				("%s damages a pest, so it must engage one too — `damages` is a subset of"
					+ " `engages`, never a rival to it") % id)
		elif PlantCatalog.engages(id):
			holding_only.append(id)
		else:
			neither.append(id)

	if err == "":
		err = _T.assert_eq(hurting.size() + holding_only.size() + neither.size(), ids.size(),
			"every plant in the catalogue landed in exactly one of the three buckets")
	if err == "":
		err = _T.assert_gt(hurting.size(), 0,
			("some plant hurts a pest — without this, a `damages()` answering false for"
				+ " everything passes every other assertion in this test"))
	if err == "":
		err = _T.assert_gt(holding_only.size(), 0,
			("some plant engages WITHOUT hurting — that disagreement is the entire reason"
				+ " `damages` exists, and without one the two keys are indistinguishable"))
	if err == "":
		err = _T.assert_gt(neither.size(), 0,
			("and some plant does neither, so `damages()` is not merely `engages()` spelled"
				+ " a second way"))
	if err == "":
		err = _T.assert_true(holding_only.has(PlantCatalog.BRAMBLE),
			("the Bramble is the plant that holds and hurts nothing — its blurb says"
				+ " \"Hurts nothing\" and this is the key that clause can be read against."
				+ " Holding-only found: %s") % [holding_only])
	return err


## The one production consumer asks the narrower question now.
##
## `Game.engagement_reach` feeds `covered_road_cells`, `sole_cover_cells` and
## `_refresh_deferred_road`, and everything they draw is worded "aimed at". It returned
## 0.0 for a Bramble before this bead too — but only because a Bramble's `reach()`
## happens to be 0.0, so a holding plant WITH a reach would have been counted as
## covering road it cannot hurt anything on. This asserts the number AND the reason.
func test_the_coverage_map_asks_whether_a_plant_hurts_not_whether_it_engages() -> String:
	var err: String = _T.assert_true(PlantCatalog.engages(PlantCatalog.BRAMBLE),
		"the Bramble engages — so the OLD gate on engagement_reach would have let it in")
	if err == "":
		err = _T.assert_false(PlantCatalog.damages(PlantCatalog.BRAMBLE),
			"and it hurts nothing, which is the gate engagement_reach reads now")
	if err == "":
		err = _T.assert_float_eq(Game.engagement_reach(PlantCatalog.BRAMBLE), 0.0, 0.0001,
			"so it contributes no coverage")
	if err == "":
		# Named explicitly so the assertion above is not silently leaning on it: the
		# reach IS 0.0 today, and the point of the change is that it no longer has to be.
		err = _T.assert_float_eq(PlantCatalog.reach(PlantCatalog.BRAMBLE), 0.0, 0.0001,
			("the Bramble's reach is still 0.0 today — give a holding plant a real radius"
				+ " and engagement_reach must STILL be 0.0, which is what the damages gate"
				+ " now guarantees and the reach accident never did"))

	# The other direction: a plant that hurts keeps its full reach through the gate.
	if err == "":
		err = _T.assert_gt(PlantCatalog.reach(PlantCatalog.CORN), 0.0,
			"a cob has a real firing range — a zero here would make the next line vacuous")
	if err == "":
		err = _T.assert_float_eq(Game.engagement_reach(PlantCatalog.CORN),
			PlantCatalog.reach(PlantCatalog.CORN), 0.0001,
			"and it still reaches all of it through the new gate")

	# And the case `engages` was introduced for, which `damages` must not undo: a plant
	# with a real reach that touches pests without hurting them.
	if err == "":
		err = _T.assert_gt(PlantCatalog.reach(PlantCatalog.SUNDEW), 0.0,
			"the Sundew has a real sap radius")
	if err == "":
		err = _T.assert_float_eq(Game.engagement_reach(PlantCatalog.SUNDEW), 0.0, 0.0001,
			"and still contributes no coverage — a lane walled in dew is undefended road")
	return err


## `damages` is read off each plant's own damage constant, not hardcoded beside it.
##
## This is the anti-drift half. A second boolean key in PLANTS would have to be
## remembered when a balance change zeroes a damage number; a derivation cannot be
## forgotten. The assertions are written as `damages(id) == <the constant is positive>`
## rather than as `damages(id) == true`, so retuning the constant to zero moves the
## expectation with it instead of turning this test red for the wrong reason.
func test_damages_is_read_off_each_plants_own_damage_constant() -> String:
	var err: String = _T.assert_gt(Nettle.STING_DAMAGE, 0.0,
		"the Nettle's sting takes health off a pest")
	if err == "":
		err = _T.assert_eq(PlantCatalog.damages(PlantCatalog.NETTLE),
			Nettle.STING_DAMAGE > 0.0,
			"and the catalogue answers off THAT constant rather than a hardcoded true")
	if err == "":
		err = _T.assert_gt(Dandelion.SEED_DAMAGE, 0.0, "the Dandelion's seeds do too")
	if err == "":
		err = _T.assert_eq(PlantCatalog.damages(PlantCatalog.DANDELION),
			Dandelion.SEED_DAMAGE > 0.0,
			"and the catalogue answers off Dandelion.SEED_DAMAGE the same way")

	if err == "":
		var rungs: int = 0
		var armed: int = 0
		for row: Dictionary in CornCobbler.LEVELS:
			rungs += 1
			if float(row.get("damage", 0.0)) > 0.0:
				armed += 1
		err = _T.assert_gt(rungs, 0,
			"the cob's level table has rungs to read — an empty ladder is a vacuous pass")
		if err == "":
			err = _T.assert_eq(PlantCatalog.damages(PlantCatalog.CORN), armed > 0,
				("and the cob answers off the damage column of its own ladder"
					+ " (%d of %d rungs armed)") % [armed, rungs])

	if err == "":
		# The Chomp is the one arm with no constant to derive from — it deals no damage
		# at all, it holds and then calls Pest.kill(DEATH_BITTEN). Asserted here so the
		# declaration is recorded as a declaration rather than mistaken for a derivation
		# by the next reader of damages().
		err = _T.assert_true(PlantCatalog.damages(PlantCatalog.CHOMP),
			("a Chomp kills what it eats, so it hurts pests — and it is the one arm of"
				+ " damages() written out rather than read off a damage constant"))
	if err == "":
		err = _T.assert_false(PlantCatalog.damages(PlantCatalog.SUNFLOWER),
			"a Sunflower fights nothing, which is what its own blurb promises")
	return err


# -- END plant-tower-defense-i8k9 ---------------------------------------------
