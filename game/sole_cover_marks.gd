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

## The armed palette, taken from SelectionMarker's rather than declared fresh, so
## the brackets and the rings cannot drift to two different reds. Same doubling
## rule as SelectionMarker.WARNING_LINE_WIDTH for the same reason: the escalation
## has to survive the colour being thrown away, which is this project's standing
## two-channel rule.
const WARNING_COLOR := SelectionMarker.WARNING_COLOR
const WARNING_RING_WIDTH: float = RING_WIDTH * 2.0

## The name Plant gives this node, so the suite and the devtools bridge can find
## it by path instead of against Godot's auto-generated `@SoleCoverMarks@42`.
const NODE_NAME := "SoleCoverMarks"

## World positions of the cells to mark. Set by Game._refresh; world rather than
## cells so this node needs no Board reference and no coordinate maths of its own,
## which keeps it drawable in a test from a hand-built array.
var points: PackedVector2Array = PackedVector2Array()


## The armed look, mirroring SelectionMarker.set_warning() — same hue, same
## doubling, so the brackets and the rings escalate together rather than reading
## as two unrelated cues (plant-tower-defense-j46n).
##
## Arming an uproot is the one moment the game knows a MOVE is being weighed, and
## these rings already hold the answer to "what does that cost": they are exactly
## the cells nothing else covers. Turning them red changes the tense — from "these
## depend on you" to "these go bare if you confirm" — with no new computation.
##
## NOT applied to the holds-nothing ring, and that is deliberate rather than an
## oversight. The brackets warn because the ACTION is destructive, which is true
## whatever the coverage looks like. These rings warn about what is LOST, and when
## the set is empty nothing is: the plant can be dug up and replanted with the road
## unchanged. Reddening that state would be a false alarm about the one case where
## uprooting is free, which is the case the ring was added to announce.
var warning: bool = false


## Arms or disarms the warning look. Idempotent and repaint-only, and it never
## touches `visible` — that is set_selected's business, exactly as
## SelectionMarker.set_warning leaves it alone so an armed-then-deselected plant
## does not flicker.
func set_warning(next: bool) -> void:
	if warning == next:
		return
	warning = next
	queue_redraw()


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


## Radius of the "holds nothing alone" ring drawn on the plant itself. Outside
## SelectionMarker.HALF (22) so it reads as a separate statement rather than as a
## thicker bracket, and far inside any plant's range ring.
const ALONE_RADIUS: float = 31.0
## Dashes, not a solid circle — the convention PlacementPreview._draw_risk_ring
## already set here: a solid ring is a RANGE, a broken one is a remark about the
## thing inside it. A solid ring at 31 px would read as a second, tiny reach.
const ALONE_DASHES: int = 8


func _draw() -> void:
	# Empty is a real answer and it has to LOOK like one. An empty set means every
	# cell this plant reaches is also held by something else — so it can be dug up
	# and replanted elsewhere without the road losing anything, which is worth
	# knowing and is the opposite of "the cue is broken".
	#
	# Drawing nothing would make those two states identical, and cycle 55 already
	# paid for that confusion: a hover cue that correctly drew nothing cost ten
	# minutes of hunting a bug that was not there. So the answer is always a ring;
	# only its POSITION changes. Out on the road: these cells depend on you. Around
	# the plant: nothing does.
	#
	# It says nothing about whether uprooting is a good idea. Depth on a thin
	# stretch is often exactly what was bought, and the game has no business
	# recommending otherwise — this reports a fact and leaves the decision alone.
	if points.is_empty():
		# Deliberately NOT reddened when armed — see `warning`'s header. Nothing is
		# lost here, so there is nothing to warn about.
		var step: float = TAU / float(ALONE_DASHES * 2)
		for i: int in range(ALONE_DASHES):
			var from: float = float(i) * step * 2.0
			draw_arc(Vector2.ZERO, ALONE_RADIUS, from, from + step, 4,
				MARK_COLOR, RING_WIDTH, true)
		return
	for at: Vector2 in points:
		draw_arc(to_local(at), RING_RADIUS, 0.0, TAU, 20, ring_color(), ring_width(), true)


## The ink the road rings are drawn in, as a predicate rather than a branch inside
## `_draw()` — the same reason PlacementPreview.shows_dead_zone() is one: a rule
## that can only be checked by looking at pixels gets checked once.
##
## Warns only when there is something to warn ABOUT. An armed uproot on a plant
## holding nothing alone costs the road nothing, and reddening that would be a
## false alarm about the single case where uprooting is free.
func ring_color() -> Color:
	return WARNING_COLOR if warning and not points.is_empty() else MARK_COLOR


func ring_width() -> float:
	return WARNING_RING_WIDTH if warning and not points.is_empty() else RING_WIDTH
