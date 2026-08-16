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
##
## Drawing that ring with equal confidence everywhere was itself a lie, though:
## 15 of the board's 94 buildable cells cover no road at a Corn Cobbler's reach
## and 34 cover none at a Chomp Flower's, and the ring looked identical on all
## of them. Seeds could be spent on a plant that would never fire once, with
## nothing saying so before the click or after it. See covers_road().

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

## The dead-zone cue: legal cell, but this plant's reach touches no road, so it
## would stand there for the whole run and never fire once.
##
## Told apart from every other state by *shape*, not hue — this project just
## shipped mutation cues built on the same rule. The mark is a single straight
## bar struck through the brackets, and a straight stroke that is not one of the
## four corner arms appears in no other preview state: `at_risk` is a dashed
## circle with no straight edges anywhere, `placeable` is brackets plus one
## solid circle, blocked is brackets alone. In greyscale the bar is still the
## only thing on screen crossing the cell.
##
## The reach ring is still drawn, dimmed to the same slate, because "how far it
## would reach" is exactly the evidence for the claim — the player can see the
## circle falling short of the road rather than being told so.
const DEAD_COLOR := Color(0.70, 0.73, 0.80, 0.80)
const DEAD_BAR_WIDTH: float = 3.0
## Bar length is the bracket box, not the ring: a Corn Cobbler's ring is 176 px,
## and a 352 px diagonal slashed across the playfield reads as a board-wide
## overlay rather than as a note about one cell.
const DEAD_BAR_ANGLE: float = -PI * 0.25

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

## The board the hovered cell belongs to, used to answer "does this reach any
## road at all". Optional: left null it is resolved from the preview's own
## siblings — Game builds the board and the preview as children of the same
## Entities node — so the cue works with no change at the call site. Assign it
## explicitly if you would rather not rely on that.
var board: Board = null

var _resolved_board: Board = null


func _init() -> void:
	half = PREVIEW_HALF
	arm = PREVIEW_ARM


## Precedence, stated in one place, because three cues over one cell is how a
## preview stops meaning anything:
##
## 1. Illegal (road, off-board, occupied, unaffordable) wins outright. Red
##    brackets and nothing else — no ring, no risk dashes, no dead-zone bar. A
##    cell that already refuses the click is not also told why the plant it
##    refuses would have been useless there.
## 2. `at_risk` (a defenceless plant beside the road) — only reachable by a
##    plant with no reach of its own.
## 3. Dead zone (reach > 0, and it covers no road) — only reachable by a plant
##    that does have reach.
##
## 2 and 3 are mutually exclusive by construction rather than by an `elif`: they
## test opposite sides of `reach > 0.0`, so no cell can ever draw both.
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
	var dead: bool = shows_dead_zone()
	var base: Color = DEAD_COLOR if dead else marker_color
	var ring := Color(base.r, base.g, base.b, RING_ALPHA)
	draw_arc(Vector2.ZERO, reach, 0.0, TAU, 48, ring, RING_WIDTH, true)
	if dead:
		_draw_dead_bar()


## Dashes rather than a solid ring, drawn as evenly spaced arc segments — a
## second solid circle would read as a second range, which is the opposite of
## what it means. Called from _draw() before the coverage ring so a plant with
## both never has the warning hidden underneath.
func _draw_risk_ring() -> void:
	var step: float = TAU / float(RISK_DASHES * 2)
	for i: int in range(RISK_DASHES):
		var from: float = float(i) * step * 2.0
		draw_arc(Vector2.ZERO, RISK_RADIUS, from, from + step, 4, RISK_COLOR, RISK_WIDTH, true)


## One straight stroke through the bracket box. Deliberately the only straight
## line in any preview state other than the four corner arms, so the state is
## legible with the colour thrown away.
func _draw_dead_bar() -> void:
	var arm_vec: Vector2 = Vector2.from_angle(DEAD_BAR_ANGLE) * PREVIEW_HALF
	draw_line(-arm_vec, arm_vec, DEAD_COLOR, DEAD_BAR_WIDTH, true)


## Will the player actually see the dead-zone mark? The precedence rule above,
## as one predicate — geometry *and* legality, where covers_road() below is only
## the geometry. An illegal cell answers false however dead it is: red brackets
## already refused the click, and a second overlapping warning on top of a
## refusal is what this cue is meant to avoid becoming.
func shows_dead_zone() -> bool:
	return placeable and reach > 0.0 and not covers_road()


## Does the plant being previewed reach any road from the cell it is hovering?
##
## True — "it is fine" — is also the answer when the board cannot be resolved or
## the plant has no reach at all. Both are cases where the question is
## unanswerable or meaningless, and a warning nobody can act on is worse than
## no warning. A Sunflower is never dead-zoned: it is not supposed to fire.
func covers_road() -> bool:
	if reach <= 0.0:
		return true
	var on_board: Board = _board()
	if on_board == null:
		return true
	return covered_road_cells(on_board, on_board.world_to_cell(position), reach) > 0


## How many road cells a plant of `reach_px` standing on `cell` can touch.
##
## Measured centre to centre, and that is the definition rather than an
## approximation of one: Board.route() is literally one waypoint per road cell
## centre, so a road cell whose centre is inside the circle is a road cell the
## pest walking it is inside the circle at. Static, because the number is a
## property of the board and the reach and needs no live preview node — which is
## what lets the tests pin it across the whole grid.
static func covered_road_cells(on_board: Board, cell: Vector2i, reach_px: float) -> int:
	if on_board == null or reach_px <= 0.0:
		return 0
	# Forces the path build if the board has not had its _ready() yet — is_path()
	# on an unbuilt board answers false for every cell, which would report the
	# whole field dead rather than reporting that it could not tell.
	if on_board.path_cell_count() <= 0:
		return 0
	var origin: Vector2 = on_board.cell_to_world(cell)
	var count: int = 0
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var road := Vector2i(x, y)
			if not on_board.is_path(road):
				continue
			if origin.distance_to(on_board.cell_to_world(road)) <= reach_px:
				count += 1
	return count


## The board to measure against: the one handed in, else the sibling Game put
## next to this node. Cached, and re-resolved if it is ever freed.
func _board() -> Board:
	if board != null and is_instance_valid(board):
		return board
	if _resolved_board != null and is_instance_valid(_resolved_board):
		return _resolved_board
	_resolved_board = null
	var parent: Node = get_parent()
	if parent == null:
		return null
	for sibling: Node in parent.get_children():
		var found := sibling as Board
		if found != null:
			_resolved_board = found
			break
	return _resolved_board
