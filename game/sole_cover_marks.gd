class_name SoleCoverMarks
extends Node2D

## Rings on the road cells a selected plant is the ONLY thing covering — "this is
## what the garden loses if you dig this up" (plant-tower-defense-nx9o).
##
## The mirror of PlacementPreview's new-cover dots, which answer the same question
## about a plant not bought yet. Both exist because a range ring is identical
## whether it is the only thing holding that road or one of three, and cycle 54
## measured that difference as decisive: five cobs covering all 32 road cells lose
## a pest where seven covering the same 32 do not.
##
## WHY A SEPARATE NODE, twice over.
##
## Not in Plant._draw(): CornCobbler and ChompFlower fully override it and never
## call super, which is the trap SelectionMarker's header documents and the reason
## the Chomp shipped with no selection cue at all.
##
## Not in SelectionMarker either, which would otherwise be the obvious home — it
## is already a child, already toggled with selection, already borrowed by the
## preview. But play_entrance() tweens that node's `scale` from 0.55 to 1.0 over
## GROW_SECONDS, and these marks sit whole cells away from the plant's origin.
## Scaling them about that origin would slide every ring inward and then out again
## on each selection, which reads as a bug rather than as a flourish. Brackets are
## 22 px from centre and do not care; a mark 320 px away does.
##
## NOT ON THE ROAD'S OWN PAINT, which is where a "coverage depth" cue would
## naively go. lane_pressure_overlay.gd spends hue on DANGER, alpha on how much
## pressure a cell took and orientation on aimed-versus-unaimed, and argues that a
## density or a second hue would cost the property its hatch exists for. This is a
## selection-time overlay on a node that is hidden the rest of the time, so it
## spends none of that.

## Radius of the ring drawn on each cell. Larger than the preview's 4 px dot and
## drawn as an outline rather than a disc, so the two cues are not mistaken for
## each other: the preview says "you would gain this", this says "you alone hold
## this", and they can be on screen together while hovering with a plant selected.
const RING_RADIUS: float = 9.0
const RING_WIDTH: float = 2.0

## Yellow, matching SelectionMarker.MARKER_COLOR rather than the preview's green:
## everything about the plant currently selected reads in one colour, and these
## marks belong to the selection, not to the purchase.
const MARK_COLOR := Color(SelectionMarker.MARKER_COLOR, 0.75)

## The name Plant gives this node, so the suite and the devtools bridge can find
## it by path instead of against Godot's auto-generated `@SoleCoverMarks@42`.
const NODE_NAME := "SoleCoverMarks"

## World positions of the cells to mark. Set by Game._refresh; world rather than
## cells so this node needs no Board reference and no coordinate maths of its own,
## which keeps it drawable in a test from a hand-built array.
var points: PackedVector2Array = PackedVector2Array()


## Replaces the marks and repaints only when they actually moved.
##
## Returns whether anything changed, for the same reason Board.mark_unaimed_road
## does: this is driven from _refresh(), which fires on every seed payout, and an
## unconditional queue_redraw() there would repaint the whole set several times a
## second to show an identical picture. It is also the claim a test wants — "the
## rings moved when the second cob landed" is a claim about a change.
func set_points(next: PackedVector2Array) -> bool:
	if next.size() == points.size():
		var same: bool = true
		for i: int in range(next.size()):
			if not next[i].is_equal_approx(points[i]):
				same = false
				break
		if same:
			return false
	points = next
	queue_redraw()
	return true


func _draw() -> void:
	for at: Vector2 in points:
		draw_arc(to_local(at), RING_RADIUS, 0.0, TAU, 20, MARK_COLOR, RING_WIDTH, true)
