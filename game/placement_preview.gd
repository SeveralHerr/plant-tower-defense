class_name PlacementPreview
extends SelectionMarker

## "This is where the plant you picked would go, and this is what it would
## cover." A sibling Node2D under Entities, drawn on its own, positioned at the
## hovered cell's centre.
##
## Subclasses SelectionMarker rather than reimplementing it: the brackets are
## deliberately the *same shape* the plant will wear once placed and selected,
## only dimmer and a size larger, so the hover cue reads as a promise of that
## state. Reusing the node also inherits the reason it exists at all — a cue
## drawn from a Plant's own _draw() is silently dropped by every subclass that
## overrides _draw() without chaining, which is how the Chomp Flower shipped
## with no selection feedback.
##
## The range ring is the part the flat cursor rect could never show. Coverage
## was previously invisible until *after* the seeds were spent and the plant
## selected — the one piece of information that decides where a Corn Cobbler
## should go was the one piece you could not see while deciding.

## A size larger than the selection brackets so the two are distinguishable
## when a preview hovers over an already-selected plant's cell.
const PREVIEW_HALF: float = 27.0
const PREVIEW_ARM: float = 9.0

## Dim relative to SelectionMarker.MARKER_COLOR: a hover is a suggestion, and
## it should not compete with the marker on the plant actually selected.
const OK_COLOR := Color(0.55, 0.95, 0.62, 0.75)
const BLOCKED_COLOR := Color(0.95, 0.42, 0.36, 0.75)
## Dimmer still — the ring covers a large area, so at bracket alpha it would
## dominate the board.
const RING_ALPHA: float = 0.30
const RING_WIDTH: float = 1.5

## The hungry-pest warning. Amber, not the blocked red — the cell is legal and
## the player may well want it anyway; this is a risk, not a refusal.
const RISK_COLOR := Color(1.0, 0.72, 0.20, 0.85)
const RISK_RADIUS: float = 30.0
const RISK_WIDTH: float = 2.0
const RISK_DASHES: int = 8

## Reach of the plant being previewed, from PlantCatalog.reach(). 0.0 draws no
## ring at all, which is correct for the Sunflower rather than a missing case.
var reach: float = 0.0
## False for a cell that is road, off-board, occupied, or unaffordable. Only
## recolours; a blocked preview still draws, because "you cannot put it here"
## is the thing worth showing.
var placeable: bool = true

## The cell is legal, but a hungry pest walking past can reach whatever stands
## here — and this plant cannot fight back. Draws a dashed warning ring at one
## cell's reach, which is exactly how far a hungry pest can lunge.
##
## Only meaningful for a plant with no reach of its own: a Corn Cobbler beside
## the road is the entire point of a Corn Cobbler, and warning about it would
## train the player to ignore the cue. A Sunflower there is one hungry mutation
## away from losing the run's economy, and nothing on screen said so.
var at_risk: bool = false


func _init() -> void:
	half = PREVIEW_HALF
	arm = PREVIEW_ARM


func _draw() -> void:
	marker_color = OK_COLOR if placeable else BLOCKED_COLOR
	_draw_brackets()
	# Before the coverage ring, so a plant with both never has the warning
	# painted over. Only on a cell you could actually use — warning about a
	# cell that already refuses the click is noise on top of noise.
	if at_risk and placeable:
		_draw_risk_ring()
	# No ring on a blocked cell: a coverage circle centred somewhere the plant
	# cannot go is an answer to a question the player is not asking.
	if reach <= 0.0 or not placeable:
		return
	var ring := Color(marker_color.r, marker_color.g, marker_color.b, RING_ALPHA)
	draw_arc(Vector2.ZERO, reach, 0.0, TAU, 48, ring, RING_WIDTH, true)


## Dashes rather than a solid ring, drawn as evenly spaced arc segments — a
## second solid circle would read as a second range, which is the opposite of
## what it means. Called from _draw() before the coverage ring so a plant with
## both never has the warning hidden underneath.
func _draw_risk_ring() -> void:
	var step: float = TAU / float(RISK_DASHES * 2)
	for i: int in range(RISK_DASHES):
		var from: float = float(i) * step * 2.0
		draw_arc(Vector2.ZERO, RISK_RADIUS, from, from + step, 4, RISK_COLOR, RISK_WIDTH, true)
