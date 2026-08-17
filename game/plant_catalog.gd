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
const DANDELION := &"dandelion"
const MINT := &"mint"
const NETTLE := &"nettle"

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
	DANDELION: {
		"display": "Bomb Dandelion",
		"texture": "res://assets/sprites/dandelion.png",
		"cost": 45,
		# The first tier-3 entry, and the reason SeedBank grew an `epic` packet:
		# `rare` used to cap at 99 and therefore reached everything, so a third
		# tier only means something once the tier below it stops being a superset.
		"tier": 3,
		"unlocked_at_start": false,
		"free_starter": false,
		"blurb": "Throws its seeds in an arc and they burst where they land. Hits everything standing together — and grows its fluff back between volleys.",
		# The only entry in the catalogue that damages more than one pest with one
		# action. See Dandelion's header for why that is worth 45 seeds when its
		# single-target rate is a 10-seed cob's.
		"engages": true,
	},
	MINT: {
		"display": "Garden Mint",
		"texture": "res://assets/sprites/mint.png",
		"cost": 25,
		"tier": 2,
		"unlocked_at_start": false,
		"free_starter": false,
		"blurb": "Touches nothing. The plants beside it shoot a third again as fast — so where you put it is the whole point.",
		# Engages nothing, like Sunflower and Sundew -- but for a third reason again.
		# Sunflower ignores the lane, Sundew touches pests without hurting them, and Mint
		# never sees a pest at all: its reach is over PLANTS. Anything asking "does this
		# cell defend the lane" must answer no for a Mint even when it is surrounded by
		# cobs that do.
		"engages": false,
	},
	NETTLE: {
		"display": "Prickly Nettle",
		"texture": "res://assets/sprites/nettle.png",
		"cost": 40,
		# TIER 2, and the bead that asked for this plant said 3. It cannot be 3:
		# test_the_dandelion_is_priced_against_the_four_plants_it_stands_beside asserts the
		# Dandelion's tier is STRICTLY above every other entry's, so a second tier-3 plant
		# fails the suite. Checked before writing the number rather than after.
		#
		# It is also the right answer on its own terms. A packet tier is how the plant is
		# ACQUIRED, and this one has to be in the player's hands BEFORE
		# WaveDirector.MUTATION_START_WAVE to be worth anything at all -- an epic packet at 90
		# seeds (SeedBank.PACKET_TIERS) is not reliably affordable by wave 8. The rare packet
		# caps at tier 2 and costs 45, which is where the answer to a wave-8 problem belongs.
		#
		# 40 seeds makes it the dearest tier-2 entry (Sundew 30, Sunflower and Mint 25) and
		# still under the Dandelion's 45. That gradient is the statement: a specialist is
		# priced like the top of its tier, never like the tier above it.
		"tier": 2,
		"unlocked_at_start": false,
		"free_starter": false,
		# Names the wave outright. A plant that does nothing for seven waves and does not say
		# so is a trap rather than a decision -- see nettle.gd's header. The 8 here is pinned
		# against WaveDirector.MUTATION_START_WAVE by
		# test_the_nettle_blurb_warns_it_is_dead_weight_before_mutations, because a blurb is a
		# const String and cannot interpolate one.
		"blurb": "Stings only pests the mutations changed — armoured, winged, hungry — and lets the rest walk past. Dead weight until wave 8, when the first of them arrive.",
		# Damages, and is the only entry whose `true` here is CONDITIONAL on the pest. That is
		# not a reason to write false: everything that reads this key is asking "does this cell
		# defend the lane", and a Nettle on the road's shoulder at wave 12 defends it. What the
		# key cannot express is "against some pests only", and nothing in the game asks that
		# yet -- see Nettle.can_sting, which is where the real answer lives.
		"engages": true,
	},
}

## Order the shop and the plant bar list plants in. Keeps the UI stable as more
## plants are added to PLANTS.
## Mint sits last because it is the only entry whose value depends on what is already on
## the board -- a first-time reader meeting it before they own anything to speed up would
## read it as a plant that does nothing.
## Nettle sits after it for the same class of reason and a sharper one: it is the only entry
## that does nothing AT ALL for the first seven waves, so the last thing a reader scrolling
## the shop meets is the one whose blurb has to be read before it is bought.
const ORDER: Array[StringName] = [CORN, CHOMP, SUNFLOWER, SUNDEW, DANDELION, MINT, NETTLE]


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
		DANDELION:
			# The throw, not the blast. SeedBomb.BLAST_RADIUS is how wide the
			# landing is, which is a different question from how far a seed can be
			# thrown — and it is the throw that decides whether a cell is dead
			# ground.
			return Dandelion.RANGE
		MINT:
			# A real reach, over PLANTS rather than over the road -- the dead-ground cue
			# asks this question, and a Mint touching no plant is exactly as wasted as a
			# cob covering no lane. Read from Mint's own constant, not a copied 64.
			return Mint.REACH
		NETTLE:
			# The sting's reach, read from Nettle's own constant rather than a copied 112.
			#
			# Worth saying what this answers and what it cannot: the dead-ground cue asks
			# this question, so a Nettle that touches no road cell is flagged as wasted, and
			# that is correct at every wave. What no reach can express is "wasted UNTIL wave
			# 8" -- the blurb is where that lives, and it is the only place it can.
			return Nettle.RANGE
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
