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

## Reach of the plant being previewed, from PlantCatalog.reach(). 0.0 draws no
## ring at all, which is correct for the Sunflower rather than a missing case.
var reach: float = 0.0
## False for a cell that is road, off-board, occupied, or unaffordable. Only
## recolours; a blocked preview still draws, because "you cannot put it here"
## is the thing worth showing.
var placeable: bool = true


func _init() -> void:
	half = PREVIEW_HALF
	arm = PREVIEW_ARM


func _draw() -> void:
	marker_color = OK_COLOR if placeable else BLOCKED_COLOR
	_draw_brackets()
	# No ring on a blocked cell: a coverage circle centred somewhere the plant
	# cannot go is an answer to a question the player is not asking.
	if reach <= 0.0 or not placeable:
		return
	var ring := Color(marker_color.r, marker_color.g, marker_color.b, RING_ALPHA)
	draw_arc(Vector2.ZERO, reach, 0.0, TAU, 48, ring, RING_WIDTH, true)
