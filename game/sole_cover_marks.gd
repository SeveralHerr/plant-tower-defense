class_name SoleCoverMarks
extends Node2D
## The drawn-overlay grammar this cue belongs to is `game/OVERLAY_GRAMMAR.md`
## — what a solid ring, a dashed ring, a filled dot and a doubled width each
## mean, and the two places the grammar does not hold. Read it before adding a
## cue; its mechanical half is pinned by
## test_the_overlay_grammar_holds_where_it_is_mechanical.

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

## The same rings, on the plant the player is comparing FROM rather than the one
## selected now (plant-tower-defense-sleq). Two sets of these are on the board at once
## while a comparison is open, and "which of these two should I move?" is unanswerable
## if the reader cannot tell which cluster belongs to which plant.
##
## **SIZE is the channel, because this row's channel already IS size.**
## `game/OVERLAY_GRAMMAR.md` files these under "small solid ring, cell-sized, centred on
## a ROAD CELL", and the entry the exceptions section argues at length is exactly that:
## what tells this ring apart from a 176 px reach is 9 px on a cell versus 176 px on a
## plant, "size and centre, not shape". A third size inside the same row is that row's
## own logic applied once more, not a new row — which matters, because adding a row
## fails `test_the_legend_names_as_many_shapes_as_the_grammar_documents`.
##
## **The WIDTH deliberately does not move.** Doubled line width is the ARMED row, the
## one cue guarding an action that cannot be undone. A held-over ring is not an
## escalation and must not borrow the channel that means one, so it stays `RING_WIDTH`
## and shrinks instead.
##
## **They can never collide on a cell**, which is what makes two sets legible at all.
## Sole cover means "nothing else standing covers this", so a cell held by both plants
## is in neither answer — `Game.sole_cover_cells` computes each through
## `covered_road_cells(except)`, and the two sets are disjoint by construction rather
## than by luck. The reader is never asked to untangle two rings on one cell; only to
## tell two clusters apart, which the size does.
##
## Half-and-a-bit of `RING_RADIUS`: an 11 px circle against a 19 px one on a 64 px cell,
## a ratio no gamma curve or greyscale conversion touches. Bigger than
## `PlacementPreview.NEW_COVER_DOT` on purpose too, so where a hover's gained-cell disc
## and a held ring do land near each other they nest rather than coincide — and they
## differ by FILL anyway, which is that row's own channel.
const HELD_RING_RADIUS: float = 5.5

## Borrowed, not declared, for the same reason `WARNING_COLOR` below is: the brackets
## and the rings of one held-over plant must dim by one number.
const HELD_ALPHA_SCALE: float = SelectionMarker.HELD_ALPHA_SCALE

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

## Is this the plant being compared FROM? Set by `Game`, which owns which plant that is
## (`Game._held_over`), exactly as it owns the selection. False on a fresh node, so a
## plant built outside a Game is never accidentally demoted.
var held_over: bool = false


## Demotes these rings to the held-over look, or restores them. Idempotent and
## repaint-only, and — like `set_warning` — it leaves `visible` alone: which of the two
## remembered plants is on screen is Game's business, and a held plant re-selected must
## not flicker on the way back to the live look.
func set_held_over(next: bool) -> void:
	if held_over == next:
		return
	held_over = next
	queue_redraw()


## The radius a road-cell mark is drawn at, live or held over.
##
## Pure and static for the reason `SelectionMarker.uproot_arc_end` is: `_draw()` never
## runs headless, so the one number that separates a held cluster from the live one
## would otherwise be a number no test in this project can read. Hoisted above the gate,
## deleting the demotion goes red rather than silently making two ring sets identical.
static func mark_radius(held: bool) -> float:
	return HELD_RING_RADIUS if held else RING_RADIUS


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
		#
		# Its RADIUS does not shrink when held over either, and that asymmetry against
		# the road rings below is the derivable part rather than an oversight: this ring
		# is concentric with the plant's own brackets, so it inherits their answer to
		# "which of the two is live" for free — the SUBJECT row's channel is size and
		# CENTRE, and this shares the centre. A mark sitting whole cells out on the road
		# inherits nothing, which is why that one moves and this one only dims. Dropping
		# the holds-nothing ring from the held plant would cost the comparison its most
		# decisive case: one plant holding four cells alone against one holding none is
		# the entire answer to "which of these should I move?".
		var step: float = TAU / float(ALONE_DASHES * 2)
		for i: int in range(ALONE_DASHES):
			var from: float = float(i) * step * 2.0
			draw_arc(Vector2.ZERO, ALONE_RADIUS, from, from + step, 4,
				ring_color(), RING_WIDTH, true)
		return
	var radius: float = mark_radius(held_over)
	for at: Vector2 in points:
		draw_arc(to_local(at), radius, 0.0, TAU, 20, ring_color(), ring_width(), true)


## The ink the road rings are drawn in, as a predicate rather than a branch inside
## `_draw()` — the same reason PlacementPreview.shows_dead_zone() is one: a rule
## that can only be checked by looking at pixels gets checked once.
##
## Warns only when there is something to warn ABOUT. An armed uproot on a plant
## holding nothing alone costs the road nothing, and reddening that would be a
## false alarm about the single case where uprooting is free.
##
## The held-over demotion is folded in HERE rather than at each `draw_arc`, which is the
## same reason this function exists at all: `_draw()` had two call sites for the ink and
## the empty-set branch had a third, and three places is where a rule stops agreeing
## with itself. `SelectionMarker.held_ink` is a no-op when `held_over` is false, so the
## live values are still exactly `WARNING_COLOR` and `MARK_COLOR`.
func ring_color() -> Color:
	var armed: bool = warning and not points.is_empty()
	# ARMED OUTRANKS HELD. A plant one click from being destroyed is the most urgent
	# thing on the board, and half-fading that warning because the plant also happens
	# to be the one being compared against is exactly backwards.
	#
	# The state is reachable: set_uproot_armed() is public and arming does not require
	# the plant to be the live selection, so "held and armed" is not the impossible
	# combination it looks like from _select's side. A pre-existing test drove exactly
	# it and caught the demotion (plant-tower-defense-sleq).
	if armed:
		return WARNING_COLOR
	# `warning`, not `armed`: a plant holding nothing alone keeps MARK_COLOR when armed
	# (reddening it would warn about the one uproot that costs the road nothing), but
	# it is still ARMED, so it must not be dimmed either.
	if warning:
		return MARK_COLOR
	return SelectionMarker.held_ink(MARK_COLOR, held_over)


func ring_width() -> float:
	return WARNING_RING_WIDTH if warning and not points.is_empty() else RING_WIDTH
