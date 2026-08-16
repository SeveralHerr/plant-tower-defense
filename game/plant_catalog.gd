class_name PlantCatalog
extends RefCounted

## The plants, as data. One entry per drawing in the design doc.
##
## `free_starter` is the doc's "You get one free plant to start with, some aren't
## free": exactly one plant is unlocked from the first frame and costs nothing to
## place the first time. Everything else has to come out of a seed packet.

const CORN := &"corn_cobbler"
const CHOMP := &"chomp_flower"
const SUNFLOWER := &"sunflower"
const SUNDEW := &"sticky_sundew"

const PLANTS: Dictionary = {
	CORN: {
		"display": "Corn Cobbler",
		"texture": "res://assets/sprites/corn_cobbler.png",
		"cost": 10,
		"tier": 1,
		"unlocked_at_start": true,
		"free_starter": true,
		"blurb": "Fires kernels down the lane. Upgrades to a bunch of corn.",
		# Kernels do damage. The only plant in the game that does.
		"engages": true,
	},
	CHOMP: {
		"display": "Chomp Flower",
		"texture": "res://assets/sprites/chomp_flower.png",
		"cost": 15,
		"tier": 1,
		"unlocked_at_start": false,
		"free_starter": false,
		"blurb": "Eats small pests instantly. Big ones take a while — and it is busy the whole time.",
		# Holds rather than hurts, but a held pest has been reached: a Chomp
		# eaten mid-chew releases a live one, and that pest was fought.
		"engages": true,
	},
	SUNFLOWER: {
		"display": "Seed Sunflower",
		"texture": "res://assets/sprites/sunflower.png",
		"cost": 25,
		"tier": 2,
		"unlocked_at_start": false,
		"free_starter": false,
		"blurb": "Fights nothing. Grows seeds on a clock — plant it somewhere the lane doesn't need.",
		# Never touches a pest at all. Its own blurb says so.
		"engages": false,
	},
	SUNDEW: {
		"display": "Sticky Sundew",
		"texture": "res://assets/sprites/sticky_sundew.png",
		"cost": 30,
		"tier": 2,
		"unlocked_at_start": false,
		"free_starter": false,
		"blurb": "Hurts nothing. Everything in its dew crawls at half speed — wings included, which no Chomp can say.",
		# Slows, never damages. This is the entry that makes reach() the wrong
		# question: SAP_RADIUS is a real reach and a lane walled in dew is
		# undefended, so coverage must ask this key and not that one.
		"engages": false,
	},
}

## Order the shop and the plant bar list plants in. Keeps the UI stable as more
## plants are added to PLANTS.
const ORDER: Array[StringName] = [CORN, CHOMP, SUNFLOWER, SUNDEW]


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


## Packet tiers use this to filter their pool — see SeedBank.PACKET_TIERS.
static func tier(id: StringName) -> int:
	return int(entry(id).get("tier", 1))


## How far a plant of this kind reaches, in pixels; 0.0 for one that does not
## reach at all (the Sunflower fires nothing and grabs nothing).
##
## Read straight off each subclass's own constant rather than re-listed as a
## number here, so a balance change to CornCobbler.RANGE moves the placement
## preview with it instead of leaving the ring quietly lying about coverage.
## PlacementPreview is the caller: the ring has to be drawable before any plant
## exists, which is why this is static and keyed on the id.
static func reach(id: StringName) -> float:
	match id:
		CORN:
			return CornCobbler.RANGE
		CHOMP:
			return ChompFlower.GRAB_RADIUS
		SUNDEW:
			# A Sundew fires nothing, but it does reach: a patch that touches no
			# road is exactly as useless as a cob that can shoot none, and the
			# dead-ground cue should say so before the 30 seeds are spent.
			return StickySundew.SAP_RADIUS
		_:
			return 0.0



## Can a plant of `id` actually touch a pest?
##
## Deliberately NOT derivable from reach(): a Sundew has a real SAP_RADIUS and
## engages nothing, so a coverage map built on reach() calls a lane walled in dew
## defended. This lives beside each plant in PLANTS so the answer is written where
## the plant is, rather than in a positive list two files away that has to be
## remembered.
##
## A missing key reads as false, which is the safe direction — it over-reports a
## coverage hole, and a readout that nags is recoverable where one promising cover
## it does not have costs beds. But defaulting is not the same as deciding, so
## test_every_plant_declares_whether_it_engages fails on an entry that omits it.
static func engages(id: StringName) -> bool:
	return bool(entry(id).get("engages", false))


## Every plant that can touch a pest, in catalogue order.
static func engaging_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ORDER:
		if engages(id):
			out.append(id)
	return out

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
