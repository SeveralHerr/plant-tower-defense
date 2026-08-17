class_name PlacementPreview
extends SelectionMarker
## The drawn-overlay grammar this cue belongs to is `game/OVERLAY_GRAMMAR.md`
## — what a solid ring, a dashed ring, a filled dot and a doubled width each
## mean, and the two places the grammar does not hold. Read it before adding a
## cue; its mechanical half is pinned by
## test_the_overlay_grammar_holds_where_it_is_mechanical.

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
## 11 of the board's 94 buildable cells cover no road at a Corn Cobbler's reach
## and 36 cover none at a Chomp Flower's, and the ring looked identical on all
## of them. (Those were 15 and 34 until the road grew its climb in cycle 53 —
## the counts are re-derived in test_the_real_route_strands_exactly_the_cells_it
## _was_measured_to_strand, and they moved in opposite directions.) Seeds could be spent on a plant that would never fire once, with
## nothing saying so before the click or after it. See covers_road().

## A size larger than the selection brackets so the two are distinguishable
## when a preview hovers over an already-selected plant's cell.
const PREVIEW_HALF: float = 27.0
const PREVIEW_ARM: float = 9.0

## Dim relative to SelectionMarker.MARKER_COLOR: a hover is a suggestion, and
## it should not compete with the marker on the plant actually selected.
##
## Derived from the palette rather than hand-typed, which is the last pair the
## GardenTheme merge missed. They were `Color(0.55, 0.95, 0.62, 0.75)` and
## `Color(0.95, 0.42, 0.36, 0.75)` — close to these, but independently chosen:
## the old blocked red was *more* saturated in the red channel than DANGER
## itself, so it was not a lightening of anything and no amount of reading the
## constant would have told you it was meant to be the same red.
##
## They stay literals because they have to: `Color.lightened()` is a method
## call, and a GDScript `const` initialiser must be a constant expression, so
## `Color(GardenTheme.DANGER.lightened(0.25), 0.75)` is a hard parse error —
## which cascades into every script that depends on this one.
##
## So the tie to the palette is enforced by a test instead of by the compiler:
## test_the_placement_brackets_come_from_the_palette_and_still_look_the_same
## asserts each of these is within a small tolerance of the palette colour it
## belongs to, lightened. Change DANGER without changing this and the suite
## says so. `lightened` rather than the raw palette value because the dimming
## is the point — a hover is a suggestion, and the marker on the plant the
## player actually selected has to stay the loudest thing on the board.
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

## The redundancy cue (plant-tower-defense-3lu): legal cell, real road under the
## reach — and every one of those road cells is already inside a patch of the
## same plant that is standing there now. A Sticky Sundew's slow does not stack
## (StickySundew.META_SOURCES says why), so a second patch over exactly the same
## road costs thirty seeds and multiplies the crossing time by
## StickySundew.added_crossing_time_multiplier(1), which is 1.0. Nothing.
##
## Drawn in DEAD_COLOR, the same slate as dead ground, on purpose: the two are
## the same KIND of statement — "you may put it here, and it will do nothing" —
## so telling them apart is the *shape's* job, which is the rule the dead bar was
## built on in the first place. Dead ground is one straight bar; redundant ground
## is two parallel bars on that same angle. An equals sign laid over the cell:
## "the same as the patch you already have". Countable at a glance, legible with
## the colour thrown away, and still nothing but straight strokes, which no other
## preview state draws outside the four corner arms.
##
## The evidence is already on screen and needs no extra drawing: a Sundew's dew
## beads are always on (see StickySundew.DROPLETS), so the rim of the patch that
## makes this one redundant is visible right next to the ring being previewed.
const REDUNDANT_BAR_GAP: float = 8.0

## Reach of the plant being previewed, from PlantCatalog.reach(). 0.0 draws no
## ring at all, which is correct for the Sunflower rather than a missing case.
var reach: float = 0.0

## Which plant is being previewed, when the caller happens to know. Optional, and
## the default is deliberately the useless-but-harmless one: left &"" the kind is
## inferred from `reach` instead, because a Sticky Sundew is the only catalogue
## entry whose reach is StickySundew.SAP_RADIUS. That inference is what lets the
## cue work with no change at Game._update_preview's call site at all.
##
## Set it if you would rather not lean on that — one line, next to the existing
## `_preview.reach = PlantCatalog.reach(selected_plant)`:
##
##     _preview.plant_id = selected_plant
##
## The day a second plant is priced at the same radius, the inference starts
## warning about the wrong one and that line becomes required rather than
## preferable.
var plant_id: StringName = &""
## False for a cell that is road, off-board, occupied, or unaffordable. Only
## recolours; a blocked preview still draws, because "you cannot put it here"
## is the thing worth showing.
##
## Game sets it from Game.would_plant_at(), which is the same predicate
## Game._click_at consults before it lets anything else have the click — so true
## here is a promise that the click plants, not a hint that it might.
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

## The road cells some standing plant already has in range, as a set. Pushed by
## Game._update_preview from covered_road_cells(); empty means "nothing is
## covered yet" AND, honestly, "nobody has told me". Both read the same here and
## that is fine — with an empty set every road cell in reach is marked new, which
## is exactly right on an empty garden and harmless before the first push.
var covered_now: Dictionary = {}

## Radius of the dot marking a road cell this purchase would newly defend. Small
## on purpose: the marks sit INSIDE the range ring and must not compete with it,
## and there can be nine of them at a Corn Cobbler's reach.
const NEW_COVER_DOT: float = 4.0

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
## 4. Redundant coverage (reach > 0, it covers road, and every road cell it
##    covers is already inside an existing patch of the same non-stacking
##    plant) — only reachable by a plant that does have reach.
##
## 2 is mutually exclusive with 3 and 4 by construction rather than by an `elif`:
## it tests the opposite side of `reach > 0.0`, so no cell can draw 2 alongside
## either. 3 and 4 are mutually exclusive with each other the same way, on
## opposite sides of "does it cover any road at all": dead ground covers none, so
## covering_patch_count() answers 0 there and rule 3 keeps the cell to itself.
## And 1 outranks all three in one place: `placeable` is a term in every one of
## shows_dead_zone(), shows_redundant_coverage() and the `at_risk` branch below,
## so a refusal is never annotated with a critique.
##
## There is deliberately no fifth state for "a husk will take this click". It
## cannot happen — see husk_click_budget() for the 32 - 28 = 4 px that says so,
## and for how much of that allowance a road or a sweep radius costs — and it is
## the one thing here that would be *transient*: the three states above are facts
## about the board and the plant, stable until something is planted, while a husk
## rots on a 4.5-10 s timer and this node is only redrawn on mouse motion, on a
## plant being picked, and after a click. A cue nobody moves the mouse to refresh
## is a cue that goes on claiming something for seconds after it stopped being
## true. Game._click_at carries that rule as precedence instead.
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
	var redundant: bool = shows_redundant_coverage()
	var base: Color = DEAD_COLOR if dead or redundant else marker_color
	var ring := Color(base.r, base.g, base.b, RING_ALPHA)
	draw_arc(Vector2.ZERO, reach, 0.0, TAU, 48, ring, RING_WIDTH, true)
	if dead:
		_draw_dead_bar()
	if redundant:
		_draw_redundant_bars()
	# Last, so the dots sit over the ring rather than under it. Skipped on dead
	# ground for the same reason the risk ring is: there is nothing new to cover
	# there and a second mark on a cell already carrying a warning is noise.
	if not dead:
		_draw_new_cover_dots()


## A dot on every road cell inside the ring that NOTHING standing already covers
## — "this is the road this purchase newly defends" (plant-tower-defense-ivoq).
##
## WHY NOT ON THE ROAD ITSELF, which is where the bead asked for it. The road's
## permanent paint is out of channels and says so: `lane_pressure_overlay.gd`
## spends hue on DANGER, alpha on how much pressure a cell took, and orientation
## on aimed-versus-unaimed, and argues explicitly that a density or a second hue
## would cost the property the hatch was built for — that the cursor's flat wash
## still reads over an off-aim cell. This is a hover-time mark on a transient
## node, so it spends none of that.
##
## AND WHY IT IS NOT A REDUNDANCY WARNING. `shows_redundant_coverage()` above
## warns that a second Sundew patch on the same road buys nothing, which is true
## of a field effect. It is FALSE of a Corn Cobbler: a cob engages one pest at a
## time, so a second cob over identical cells is worth real money — measured, in
## test_combat, as the difference between a five-cob garden that lets a pest
## through and a seven-cob garden that does not. So no dots is not a warning
## here. It means "you are buying depth rather than reach", which on a thin
## stretch is the right purchase and on a thick one is not, and the player can
## see which because the dots show where the road is bare.
func _draw_new_cover_dots() -> void:
	var on_board: Board = _board()
	if on_board == null:
		return
	for cell: Vector2i in new_cover_cells():
		# cell_to_GLOBAL: to_local() measures from the viewport, and cell_to_world is
		# board-local, so this drew every gained-cell dot 72 px high -- the same defect
		# as SoleCoverMarks, in the same shape, found by enumerating cell_to_world's
		# callers after a screenshot caught the other one.
		draw_circle(to_local(on_board.cell_to_global(cell)), NEW_COVER_DOT, marker_color)


## The road cells this purchase would newly defend: inside the reach, and not
## already covered by anything standing.
##
## A predicate rather than logic inside `_draw()`, for the reason the rest of this
## file already follows — `shows_dead_zone()` and `covering_patch_count()` are
## both readable without a canvas. A cue that can only be checked by looking at
## pixels is a cue that gets checked once.
##
## Empty means one of two very different things and the caller must not conflate
## them: the plant covers no road at all (`shows_dead_zone()` is the predicate for
## that, and `_draw()` skips these dots entirely when it is true), or every cell it
## reaches is already covered — the "buying depth, not reach" case, which is a
## legitimate purchase and is why no mark is drawn for it.
func new_cover_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var on_board: Board = _board()
	# `placeable` for the same reason shows_dead_zone() checks it: an illegal cell
	# answers false however much road it would reach. Without this the predicate
	# happily reports newly-defended cells for a cell the click already refuses --
	# `_draw()` never gets that far, so the only thing such an answer could do is
	# mislead a reader or a test into thinking the cue fires there.
	if on_board == null or reach <= 0.0 or not placeable:
		return out
	for cell: Vector2i in covered_road_cell_list(on_board, _hovered_cell(on_board), reach):
		if not covered_now.has(cell):
			out.append(cell)
	return out


## The cell this preview is sitting on, back out of its own world position —
## Game sets `position`, not a cell, and the coverage helpers take a cell.
func _hovered_cell(on_board: Board) -> Vector2i:
	return on_board.world_to_cell(position)


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


## The dead bar, doubled. Same angle, same width, same slate — the difference is
## that you can count them, which survives greyscale, a colourblind player and a
## screenshot at half size. See REDUNDANT_BAR_GAP.
func _draw_redundant_bars() -> void:
	var along: Vector2 = Vector2.from_angle(DEAD_BAR_ANGLE) * PREVIEW_HALF
	var across: Vector2 = along.orthogonal().normalized() * (REDUNDANT_BAR_GAP * 0.5)
	draw_line(-along + across, along + across, DEAD_COLOR, DEAD_BAR_WIDTH, true)
	draw_line(-along - across, along - across, DEAD_COLOR, DEAD_BAR_WIDTH, true)


## Will the player actually see the dead-zone mark? The precedence rule above,
## as one predicate — geometry *and* legality, where covers_road() below is only
## the geometry. An illegal cell answers false however dead it is: red brackets
## already refused the click, and a second overlapping warning on top of a
## refusal is what this cue is meant to avoid becoming.
func shows_dead_zone() -> bool:
	return placeable and reach > 0.0 and not covers_road()


## Will the player see the redundancy mark? Same shape of question as
## shows_dead_zone(), and it obeys the same rule 1: an illegal cell answers false
## however redundant the ground under it is.
##
## The condition is not spelled out again here. It is read straight off the
## plant's own value model: the mark fires exactly when one more patch would
## multiply the crossing time of the road it covers by 1.0. If the balance ever
## changes so that a second patch is worth something, that constant moves and
## this cue stops firing on its own, rather than going on warning about a
## purchase that has become worth making.
func shows_redundant_coverage() -> bool:
	if not placeable or reach <= 0.0:
		return false
	var added: float = StickySundew.added_crossing_time_multiplier(covering_patch_count())
	return is_equal_approx(added, 1.0)


## How many patches already on the board cover every road cell a patch placed on
## the hovered cell would cover.
##
## 0 whenever this hover would put dew on road that nothing is sticky on yet —
## and 0, benignly, in every case where the question does not apply: a plant that
## is not a patch, a board that cannot be resolved, and dead ground, where there
## is no covered road to be redundant about and rule 3 owns the cell.
func covering_patch_count() -> int:
	if not previewing_non_stacking_patch():
		return 0
	var on_board: Board = _board()
	if on_board == null:
		return 0
	var mine: Array[Vector2i] = covered_road_cell_list(on_board,
		on_board.world_to_cell(position), reach)
	if mine.is_empty():
		return 0
	var already: Dictionary = {}
	var sharing: int = 0
	for patch: StickySundew in _existing_patches():
		var theirs: Array[Vector2i] = covered_road_cell_list(on_board,
			on_board.world_to_cell(patch.position), StickySundew.SAP_RADIUS)
		var shares: bool = false
		for road: Vector2i in theirs:
			already[road] = true
			if mine.has(road):
				shares = true
		if shares:
			sharing += 1
	for road: Vector2i in mine:
		if not already.has(road):
			# One cell of new road is enough. The second patch is then buying a
			# stretch of lane the first never touched, which is the whole
			# legitimate use of a second Sundew.
			return 0
	return sharing


## Is the plant being previewed one whose effect does not stack — one where a
## second copy over the same road is worth nothing? Today the Sticky Sundew, and
## only it. See `plant_id` for why this can answer without being told.
func previewing_non_stacking_patch() -> bool:
	if plant_id != &"":
		return plant_id == PlantCatalog.SUNDEW
	return reach > 0.0 and is_equal_approx(reach, StickySundew.SAP_RADIUS)


## The patches standing on the board right now, found the same way the Board is:
## Game adds every plant as a sibling of this preview under Entities. A patch a
## hungry pest has already killed does not count — its dew comes off the board
## with it (StickySundew._on_destroyed), so a cell it used to cover is real
## ground again.
func _existing_patches() -> Array[StickySundew]:
	var out: Array[StickySundew] = []
	var parent: Node = get_parent()
	if parent == null:
		return out
	for sibling: Node in parent.get_children():
		var patch := sibling as StickySundew
		if patch != null and is_instance_valid(patch) and not patch.is_destroyed():
			out.append(patch)
	return out


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
	return covered_road_cell_list(on_board, cell, reach_px).size()


## Which road cells those are, rather than how many. The redundancy rule needs
## the cells themselves: "does this patch cover any road the patches already down
## do not" is a question about identity, and two patches covering three cells
## each can easily be three different cells.
static func covered_road_cell_list(on_board: Board, cell: Vector2i,
		reach_px: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if on_board == null or reach_px <= 0.0:
		return out
	# Forces the path build if the board has not had its _ready() yet — is_path()
	# on an unbuilt board answers false for every cell, which would report the
	# whole field dead rather than reporting that it could not tell.
	if on_board.path_cell_count() <= 0:
		return out
	var origin: Vector2 = on_board.cell_to_world(cell)
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var road := Vector2i(x, y)
			if not on_board.is_path(road):
				continue
			if origin.distance_to(on_board.cell_to_world(road)) <= reach_px:
				out.append(road)
	return out


## How much clearance there is between a husk and ground a plant may stand on —
## the measurement behind this class saying nothing at all about husks.
##
## A husk claims a 56 px-wide sweep target (CompostMeter.COLLECT_RADIUS is 28) on
## a 64 px cell, which reads like a click a preview ought to warn about. It is
## not, and the reason is geometry rather than luck: pests only ever walk
## Board.route(), which is one point per road cell centre, so a husk's centre is
## always at least CELL / 2 = 32 px from the nearest buildable cell — four clear
## of the sweep. No click that sweeps a husk can land on ground a plant could have
## gone into, so the green brackets never lie about one, and Game._click_at can
## put placement first without ever making a husk hard to reach.
##
## Returned as a float rather than a bool because the number is the interesting
## part: it is 4.0 today, and a wider COLLECT_RADIUS, a pest that gets knocked off
## the lane, or a road drawn along the board edge all eat into it. At <= 0.0 the
## conflict becomes real and this class needs a husk state after all.
##
## A subtraction, and only the difference comes back here. The two terms it is a
## difference OF are in husk_click_budget() — read that one when the question is
## "how much of this budget am I about to spend", which is the question a designer
## moving PATH_CORNERS or COLLECT_RADIUS is actually asking.
##
## 0.0 is also what an unmeasurable board answers, which is deliberately the value
## that fails the gate rather than a value that passes it. husk_click_budget()
## tells the two apart with a `measured` flag; this signature cannot.
static func husk_click_margin(on_board: Board) -> float:
	var clearance: float = lane_to_buildable_distance(on_board)
	if clearance < 0.0:
		return 0.0
	return clearance - CompostMeter.COLLECT_RADIUS


## The first term of that subtraction: how close the pests' lane — and so the
## husk of anything that dies on it — ever gets to a cell a plant may stand on.
## 32.0 today, which is CELL / 2, because route() is one point per road cell
## centre and a road cell centre is half a cell from the road cell's edge.
##
## -1.0, never 0.0, when the board cannot be walked at all: a real distance of
## zero would mean the lane touches buildable ground, which is the exact defect
## this measures, so an unmeasurable board must not be able to impersonate one.
##
## Exact, not sampled: every route segment is axis-aligned, so a segment's own
## bounding box is the segment, and box-to-box distance is the true distance.
static func lane_to_buildable_distance(on_board: Board) -> float:
	if on_board == null or on_board.path_cell_count() <= 0:
		return -1.0
	var route: PackedVector2Array = on_board.route()
	if route.size() < 2:
		return -1.0
	var closest: float = INF
	for i: int in range(route.size() - 1):
		var a: Vector2 = route[i]
		var b: Vector2 = route[i + 1]
		var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y))
		var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
		for y: int in range(Board.ROWS):
			for x: int in range(Board.COLS):
				var cell := Vector2i(x, y)
				if not on_board.is_buildable(cell):
					continue
				var corner := Vector2(float(cell.x * Board.CELL), float(cell.y * Board.CELL))
				var far: Vector2 = corner + Vector2(float(Board.CELL), float(Board.CELL))
				var dx: float = maxf(maxf(lo.x - far.x, corner.x - hi.x), 0.0)
				var dy: float = maxf(maxf(lo.y - far.y, corner.y - hi.y), 0.0)
				closest = minf(closest, Vector2(dx, dy).length())
	if is_inf(closest):
		return -1.0
	return closest


## The same 4 px, shown as the subtraction it is rather than as its answer.
##
## The whole point of this function is that a bare "4.0" teaches nobody anything.
## A designer dragging PATH_CORNERS one cell nearer the board edge, or nudging
## CompostMeter.COLLECT_RADIUS up because husks feel fiddly to click, is spending
## a budget that no number anywhere told them existed — they find out when
## test_no_husk_the_game_can_drop_lands_within_a_click_of_buildable_ground goes
## red, with nothing saying that four pixels was the entire allowance. So this
## reports both terms and their difference together: 32 - 28 = 4, and the reader
## can see which of the two they just moved.
##
## `margin` is not recomputed here — it is husk_click_margin() called, so the
## readout cannot drift away from the value the gate actually asserts on. That
## costs a second walk of the lane, which is free at the once-per-devtools-call
## rate this is used at and is the cheapest possible guarantee that the number a
## designer reads and the number a test fails on are the same number.
##
## Keys: measured (bool), lane_to_buildable (float, -1.0 when unmeasured),
## collect_radius (float), margin (float), summary (String). All JSON-safe
## scalars, because this crosses the devtools bus in `board_info`.
static func husk_click_budget(on_board: Board) -> Dictionary:
	var clearance: float = lane_to_buildable_distance(on_board)
	var radius: float = CompostMeter.COLLECT_RADIUS
	var margin: float = husk_click_margin(on_board)
	if clearance < 0.0:
		return {
			"measured": false,
			"lane_to_buildable": -1.0,
			"collect_radius": radius,
			"margin": margin,
			"summary": ("husk click budget: UNMEASURED — no board, or a board with no route. "
				+ "margin reads %.1f because that is what an unmeasurable board is worth, "
				+ "not because anything was measured.") % margin,
		}
	return {
		"measured": true,
		"lane_to_buildable": clearance,
		"collect_radius": radius,
		"margin": margin,
		"summary": ("husk click budget: lane comes within %.1f px of buildable ground, "
			+ "husk sweeps at %.1f px, %.1f px clear. At 0.0 a click could sweep a husk "
			+ "while standing on plantable ground and the preview would need a husk state.")
			% [clearance, radius, margin],
	}


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
