class_name HuskLayer
extends Node2D

## Pure view over CompostMeter — draws whatever it reports, owns none of the
## data itself, so there is never a second copy of "which husks exist" to
## drift out of sync with what a click can actually collect.
##
## A husk's *size and glow encode its seed value*. Every husk used to be one
## fixed 9px blob, so a hungry beetle's 9-seed payout looked exactly like a
## plain aphid's 2-seed one and the player only learned the difference after
## spending the click. Mutations already tint the pest itself; this is the same
## idea carried through to what the pest leaves behind.

## The smallest husk the game can drop: ceil(aphid seeds 3 / 2) with no
## mutation multiplier. Anything at or below this draws at BASE_RADIUS.
const BASE_VALUE: int = 2
## The biggest: ceil(beetle seeds 9 / 2 * hungry 2.0). Glow saturates here.
const FULL_VALUE: int = 9

const BASE_RADIUS: float = 8.0
const MAX_RADIUS: float = 15.0
const RADIUS_PER_SEED: float = 1.0
## Gap between the husk body and its rot-timer ring.
const RING_GAP: float = 3.0

const DIM_RING := Color(0.86, 0.72, 0.30, 0.85)
const BRIGHT_RING := Color(1.0, 0.97, 0.62, 1.0)
const RING_WIDTH_MIN: float = 2.0
const RING_WIDTH_MAX: float = 3.5


var compost: CompostMeter = null


## Drawn radius of a husk worth `value` seeds. Static and pure so the size↔value
## relationship is assertable without a viewport — see test_selftest.gd.
static func radius_for(value: int) -> float:
	return clampf(
		BASE_RADIUS + float(value - BASE_VALUE) * RADIUS_PER_SEED, BASE_RADIUS, MAX_RADIUS
	)


## 0 for the cheapest husk, 1 for the richest — the single knob both the ring
## colour and its width read, so brightness and weight can never disagree.
static func glow_for(value: int) -> float:
	return clampf(float(value - BASE_VALUE) / float(FULL_VALUE - BASE_VALUE), 0.0, 1.0)


func _process(_delta: float) -> void:
	if compost != null:
		queue_redraw()


func _draw() -> void:
	if compost == null:
		return
	for h: Dictionary in compost.husks():
		var pos: Vector2 = h["position"]
		var value: int = int(h["value"])
		var frac: float = clampf(float(h["life"]) / CompostMeter.HUSK_LIFETIME, 0.0, 1.0)
		var radius: float = radius_for(value)
		var glow: float = glow_for(value)
		draw_circle(pos, radius, Color(0.64, 0.45, 0.25, 0.35 + 0.35 * frac))
		# The rot timer sweeps this ring away; a richer husk wears a brighter,
		# heavier one, so "worth hurrying for" is legible at a glance.
		draw_arc(
			pos,
			radius + RING_GAP,
			0.0,
			TAU * frac,
			16,
			DIM_RING.lerp(BRIGHT_RING, glow),
			lerpf(RING_WIDTH_MIN, RING_WIDTH_MAX, glow),
			true
		)
