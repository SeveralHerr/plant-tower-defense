class_name PlantCatalog
extends RefCounted

## The plants, as data. One entry per drawing in the design doc.
##
## `free_starter` is the doc's "You get one free plant to start with, some aren't
## free": exactly one plant is unlocked from the first frame and costs nothing to
## place the first time. Everything else has to come out of a seed packet.

const CORN := &"corn_cobbler"
const CHOMP := &"chomp_flower"

const PLANTS: Dictionary = {
	CORN: {
		"display": "Corn Cobbler",
		"texture": "res://assets/sprites/corn_cobbler.png",
		"cost": 10,
		"tier": 1,
		"unlocked_at_start": true,
		"free_starter": true,
		"blurb": "Fires kernels down the lane. Upgrades to a bunch of corn.",
	},
	CHOMP: {
		"display": "Chomp Flower",
		"texture": "res://assets/sprites/chomp_flower.png",
		"cost": 15,
		"tier": 1,
		"unlocked_at_start": false,
		"free_starter": false,
		"blurb": "Eats small pests instantly. Big ones take a while — and it is busy the whole time.",
	},
}

## Order the shop and the plant bar list plants in. Keeps the UI stable as more
## plants are added to PLANTS.
const ORDER: Array[StringName] = [CORN, CHOMP]


static func ids() -> Array[StringName]:
	return ORDER.duplicate()


static func has(id: StringName) -> bool:
	return PLANTS.has(id)


static func entry(id: StringName) -> Dictionary:
	return PLANTS.get(id, {}) as Dictionary


static func display_name(id: StringName) -> String:
	return String(entry(id).get("display", String(id)))


static func cost(id: StringName) -> int:
	return int(entry(id).get("cost", 0))


static func texture_path(id: StringName) -> String:
	return String(entry(id).get("texture", ""))


static func blurb(id: StringName) -> String:
	return String(entry(id).get("blurb", ""))


static func unlocked_at_start(id: StringName) -> bool:
	return bool(entry(id).get("unlocked_at_start", false))


static func is_free_starter(id: StringName) -> bool:
	return bool(entry(id).get("free_starter", false))


static func starting_unlocks() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ORDER:
		if unlocked_at_start(id):
			out.append(id)
	return out
