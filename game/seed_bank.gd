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
## unlocked so far including higher tiers. `max_tier` filters the pool; when
## nothing in range is left to unlock, buy_packet() falls back to any locked
## plant rather than refusing a packet the player can afford.
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


## Buys one seed packet of `tier` ("common" by default, or "rare"). Returns the
## plant it rolled, or &"" if it could not buy.
func buy_packet(tier: StringName = &"common") -> StringName:
	var spec: Dictionary = PACKET_TIERS.get(tier, {}) as Dictionary
	if spec.is_empty():
		purchase_failed.emit("no such packet: %s" % tier)
		return &""
	var locked: Array[StringName] = locked_plants()
	if locked.is_empty():
		purchase_failed.emit("Every plant is already growing in your garden.")
		return &""
	var cost: int = int(spec["cost"])
	if seeds < cost:
		purchase_failed.emit("A %s costs %d seeds." % [spec["display"], cost])
		return &""
	var max_tier: int = int(spec["max_tier"])
	var pool: Array[StringName] = locked.filter(func(id: StringName) -> bool: return PlantCatalog.tier(id) <= max_tier)
	if pool.is_empty():
		pool = locked
	seeds -= cost
	seeds_changed.emit(seeds)
	var picked: StringName = pool[_rng.randi_range(0, pool.size() - 1)]
	unlocked.append(picked)
	plant_unlocked.emit(picked)
	return picked
