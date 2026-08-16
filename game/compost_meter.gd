class_name CompostMeter
extends Node

## The doc's compost idea: "pests leave husks, sweeping them pays seeds."
##
## Pest deaths already pay seeds directly (Game._on_pest_died) — the husk is a
## *second*, optional payout that requires the player to click it before it
## rots, so staying engaged with a clearing lane earns more than tabbing away.
## That's why this is seeds-in-seeds-out rather than a second currency to read.

signal husk_collected(value: int)

## How long the *cheapest* husk sits on the ground before it rots away, and the
## ceiling for every husk.
const HUSK_LIFETIME: float = 10.0
## ...and how long the richest one gets. A richer husk rots faster, so the board
## asks "which one first?" instead of "sweep them in any order, it makes no
## difference" — which is what a single shared timer meant. It also gives the
## size/glow cue a second job: a big bright husk is now urgent as well as
## valuable, and those two readings point the same way.
const MIN_HUSK_LIFETIME: float = 4.5
## How close a click has to land to sweep a husk.
const COLLECT_RADIUS: float = 28.0

## The husk value range the game can actually produce: ceil(aphid 3 / 2) with no
## mutation at the bottom, ceil(beetle 9 / 2 * hungry 2.0) at the top. Lives
## here rather than in HuskLayer because it is a fact about what the game drops,
## not about how a husk is drawn — and size, glow and lifetime all key off it,
## so they cannot disagree about which husk is the rich one.
const BASE_VALUE: int = 2
const FULL_VALUE: int = 9


## Where `value` sits in the drop range: 0.0 for the cheapest husk, 1.0 for the
## richest. The single knob the radius, the ring brightness and the rot timer
## all read.
static func value_fraction(value: int) -> float:
	return clampf(float(value - BASE_VALUE) / float(FULL_VALUE - BASE_VALUE), 0.0, 1.0)


## How long a husk worth `value` seeds survives uncollected. Static and pure so
## the value-to-urgency curve is assertable without a running meter.
static func lifetime_for(value: int) -> float:
	return lerpf(HUSK_LIFETIME, MIN_HUSK_LIFETIME, value_fraction(value))

var total_collected: int = 0

## id -> {"position": Vector2, "value": int, "life": float, "max_life": float}
var _husks: Dictionary = {}
var _next_id: int = 1


func drop_husk(at: Vector2, value: int) -> int:
	var id: int = _next_id
	_next_id += 1
	var span: float = lifetime_for(value)
	_husks[id] = {"position": at, "value": value, "life": span, "max_life": span}
	return id


## Snapshot for rendering: [{id, position, value, life, max_life}]. `life`
## counts down to 0 from this husk's own `max_life`, which is no longer the
## same for every husk — the rot ring has to divide by `max_life`, not by
## HUSK_LIFETIME, or a rich husk's ring reads two-thirds full at the instant it
## vanishes.
func husks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: Variant in _husks:
		var h: Dictionary = _husks[id]
		out.append({
			"id": id,
			"position": h["position"],
			"value": h["value"],
			"life": h["life"],
			"max_life": h["max_life"],
		})
	return out


func husk_count() -> int:
	return _husks.size()


## Sweeps the nearest husk within COLLECT_RADIUS of `at`. Returns the seeds it
## paid, or 0 if nothing was close enough — the caller decides what 0 means
## (Game treats it as "the click was for something else").
func collect_at(at: Vector2) -> int:
	var best_id: Variant = null
	var best_distance: float = COLLECT_RADIUS
	for id: Variant in _husks:
		var h: Dictionary = _husks[id]
		var d: float = (h["position"] as Vector2).distance_to(at)
		if d <= best_distance:
			best_distance = d
			best_id = id
	if best_id == null:
		return 0
	var value: int = int((_husks[best_id] as Dictionary)["value"])
	_husks.erase(best_id)
	total_collected += value
	husk_collected.emit(value)
	return value


func _process(delta: float) -> void:
	var expired: Array = []
	for id: Variant in _husks:
		var h: Dictionary = _husks[id]
		h["life"] = float(h["life"]) - delta
		if h["life"] <= 0.0:
			expired.append(id)
	for id: Variant in expired:
		_husks.erase(id)
