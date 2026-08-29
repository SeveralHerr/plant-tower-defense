class_name SportMark
extends Node2D

## The hazard badge over a mutated plant. A node rather than something painted
## inside `Plant._draw`, and the reason is coverage rather than taste: seven of the
## nine plant scripts override `_draw` and call `draw_reach_ring()` themselves, so a
## cue added to the base class's `_draw` would appear on two kinds and silently not
## on the other seven. A child node is drawn by the engine whoever its parent is.
##
## It is also the shape plant-tower-defense-vlpg is moving the rest of this board's
## cues toward — a named node with its own paint, addressable from the devtools
## bridge and from a test, instead of a branch inside somebody else's `_draw`.
##
## The geometry and the colours belong to `PlantMutation`, not to this file: the
## mark and the tint are one piece of vocabulary and they are stated in one place.

## Named, because an auto-named node is unaddressable. Same argument as
## `SelectionMarker.NODE_NAME`, which this sits beside in every sport's tree.
const NODE_NAME := "SportMark"

## Slow, and slow on purpose. This is an identity cue, not an alert: it says "this
## plant is a sport" to a player who looks at it, and nothing about it is urgent.
## A pulse at this period reads as breathing next to `Plant.BREATHE_RATE` (2.0) and
## `Aloe.PULSE_SECONDS` rather than as a warning.
const PULSE_SECONDS: float = 2.4
const PULSE_ALPHA: float = 0.22

var _clock: float = 0.0


func _ready() -> void:
	name = NODE_NAME


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


## Pure: the alpha multiplier at `clock` seconds. Lifted out of `_draw` so the
## animation is assertable in a headless run, where no `_draw` ever executes — see
## `.claude/skills/assert-an-animation`.
static func pulse_at(clock: float) -> float:
	return 1.0 - PULSE_ALPHA * 0.5 * (1.0 - cos(clock * TAU / PULSE_SECONDS))


func _draw() -> void:
	var fade: float = pulse_at(_clock)
	var fill: Color = PlantMutation.BADGE_FILL
	fill.a *= fade
	var rim: Color = PlantMutation.BADGE_RIM
	rim.a *= fade
	var ink: Color = PlantMutation.TREFOIL_COLOR
	ink.a *= fade
	draw_circle(PlantMutation.BADGE_CENTRE, PlantMutation.BADGE_RADIUS, fill)
	# The rim as an arc rather than a second, larger disc under the first: a disc
	# would paint over whatever the badge overlaps, and this cue sits off the plant's
	# shoulder where the grass and sometimes a neighbour's leaves are.
	draw_arc(PlantMutation.BADGE_CENTRE, PlantMutation.BADGE_RADIUS, 0.0, TAU, 20, rim,
		PlantMutation.BADGE_RIM_WIDTH, true)
	for blade: PackedVector2Array in PlantMutation.badge_trefoil():
		draw_colored_polygon(blade, ink)
	draw_circle(PlantMutation.BADGE_CENTRE, PlantMutation.TREFOIL_HUB, ink)
