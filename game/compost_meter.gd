class_name CompostMeter
extends Node

## The doc's compost idea: "pests leave husks, sweeping them pays seeds."
##
## Pest deaths already pay seeds directly (Game._on_pest_died) — the husk is a
## *second*, optional payout that requires the player to click it before it
## rots, so staying engaged with a clearing lane earns more than tabbing away.
## That's why this is seeds-in-seeds-out rather than a second currency to read.

signal husk_collected(value: int)

## How long an uncollected husk sits on the ground before it rots away.
const HUSK_LIFETIME: float = 10.0
## How close a click has to land to sweep a husk.
const COLLECT_RADIUS: float = 28.0

var total_collected: int = 0

## id -> {"position": Vector2, "value": int, "life": float}
var _husks: Dictionary = {}
var _next_id: int = 1


func drop_husk(at: Vector2, value: int) -> int:
	var id: int = _next_id
	_next_id += 1
	_husks[id] = {"position": at, "value": value, "life": HUSK_LIFETIME}
	return id


## Snapshot for rendering: [{id, position, value, life}], `life` counting down
## from HUSK_LIFETIME to 0.
func husks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: Variant in _husks:
		var h: Dictionary = _husks[id]
		out.append({"id": id, "position": h["position"], "value": h["value"], "life": h["life"]})
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
