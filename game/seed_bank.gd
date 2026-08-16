class_name SeedBank
extends Node

## Seeds, unlocks, and the seed-packet gamble.
##
## The design doc: "You get one free plant to start with, some aren't free. You
## have to buy plant seeds to get plants." So a packet is the only route to a new
## plant, and it is a gamble rather than a menu — you buy the packet, the packet
## picks. With a short catalogue that reads as suspense; with a long one it is the
## difference between a shop and a decision.

signal seeds_changed(total: int)
signal plant_unlocked(id: StringName)
signal purchase_failed(reason: String)

const STARTING_SEEDS: int = 25

## Kept for existing callers/tests that just want "the" packet price — it is
## the common tier's cost, the default buy_packet() reaches for.
const PACKET_COST: int = 20

## Packet tiers: cheap and common-only, or pricier with a shot at anything
## including higher tiers. `max_tier` filters the pool, and it is the ONLY thing
## the two tiers differ by — so the cap has to bind. When nothing at or below
## `max_tier` is still locked, buy_packet() refuses and charges nothing; it must
## never quietly reach past the cap, or a 20-seed common packet becomes a cheaper
## rare packet and both HUD tooltips start lying. The player is not stranded by
## the refusal: seeds come from pests, sunflowers and compost, so a pricier packet
## is always still reachable.
const PACKET_TIERS: Dictionary = {
	&"common": {"display": "Common Packet", "cost": PACKET_COST, "max_tier": 1},
	&"rare": {"display": "Rare Packet", "cost": 45, "max_tier": 99},
}

var seeds: int = STARTING_SEEDS
## Every seed ever gained (not net of spending) — the run's score for the
## endless-mode high score. Refunds count too; they are still seeds earned.
var seeds_earned_total: int = 0
var unlocked: Array[StringName] = []
## Cleared the first time the free starter is planted. See placement_cost().
var free_starter_available: bool = true

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	unlocked = PlantCatalog.starting_unlocks()
	_rng.randomize()


## Fixes the packet roll for tests and for reproducing a run.
func set_seed(value: int) -> void:
	_rng.seed = value


func add_seeds(amount: int) -> void:
	seeds = maxi(0, seeds + amount)
	if amount > 0:
		seeds_earned_total += amount
	seeds_changed.emit(seeds)


func is_unlocked(id: StringName) -> bool:
	return unlocked.has(id)


func locked_plants() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in PlantCatalog.ids():
		if not unlocked.has(id):
			out.append(id)
	return out


## What planting `id` costs right now. The one free starter is free exactly once —
## after that a Corn Cobbler costs the same as any other.
func placement_cost(id: StringName) -> int:
	if free_starter_available and PlantCatalog.is_free_starter(id):
		return 0
	return PlantCatalog.cost(id)


func can_afford(id: StringName) -> bool:
	return is_unlocked(id) and seeds >= placement_cost(id)


## Charges for a placement. Returns false and changes nothing if it cannot be paid.
func pay_for_plant(id: StringName) -> bool:
	if not is_unlocked(id):
		purchase_failed.emit("%s is still in the packet — buy seeds first." % PlantCatalog.display_name(id))
		return false
	var price: int = placement_cost(id)
	if seeds < price:
		purchase_failed.emit("Not enough seeds for %s (%d needed)." % [PlantCatalog.display_name(id), price])
		return false
	if price == 0 and PlantCatalog.is_free_starter(id):
		free_starter_available = false
	seeds -= price
	seeds_changed.emit(seeds)
	return true


func refund(amount: int) -> void:
	add_seeds(amount)


## Everything `tier`'s packet could still roll: locked plants at or below its
## `max_tier`. An empty pool means that packet has nothing left to give — the HUD
## can disable the button on it, and buy_packet() refuses rather than reaching
## past the cap. Unknown tiers have an empty pool.
func packet_pool(tier: StringName = &"common") -> Array[StringName]:
	var out: Array[StringName] = []
	var spec: Dictionary = PACKET_TIERS.get(tier, {}) as Dictionary
	if spec.is_empty():
		return out
	var max_tier: int = int(spec["max_tier"])
	for id: StringName in locked_plants():
		if PlantCatalog.tier(id) <= max_tier:
			out.append(id)
	return out


## The cheapest packet tier that still has something locked in range, or &"" if
## none has. Used to point the player somewhere when their packet is spent.
func _cheapest_tier_with_stock() -> StringName:
	var best: StringName = &""
	var best_cost: int = 0
	for key: StringName in PACKET_TIERS:
		if packet_pool(key).is_empty():
			continue
		var cost: int = int((PACKET_TIERS[key] as Dictionary)["cost"])
		if best == &"" or cost < best_cost:
			best = key
			best_cost = cost
	return best


func _packet_spent_message(spec: Dictionary) -> String:
	var line: String = "A %s only holds tier-%d seeds, and you have them all." % [spec["display"], int(spec["max_tier"])]
	var better: StringName = _cheapest_tier_with_stock()
	if better == &"":
		return line
	var better_spec: Dictionary = PACKET_TIERS[better] as Dictionary
	return "%s Try a %s (%d)." % [line, better_spec["display"], int(better_spec["cost"])]


## Buys one seed packet of `tier` ("common" by default, or "rare"). Returns the
## plant it rolled, or &"" if it could not buy — in which case nothing is charged.
func buy_packet(tier: StringName = &"common") -> StringName:
	var spec: Dictionary = PACKET_TIERS.get(tier, {}) as Dictionary
	if spec.is_empty():
		purchase_failed.emit("no such packet: %s" % tier)
		return &""
	if locked_plants().is_empty():
		purchase_failed.emit("Every plant is already growing in your garden.")
		return &""
	var pool: Array[StringName] = packet_pool(tier)
	if pool.is_empty():
		purchase_failed.emit(_packet_spent_message(spec))
		return &""
	var cost: int = int(spec["cost"])
	if seeds < cost:
		purchase_failed.emit("A %s costs %d seeds." % [spec["display"], cost])
		return &""
	seeds -= cost
	seeds_changed.emit(seeds)
	var picked: StringName = pool[_rng.randi_range(0, pool.size() - 1)]
	unlocked.append(picked)
	plant_unlocked.emit(picked)
	return picked
