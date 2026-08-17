class_name Board
extends Node2D

## The playfield: a grass field with a dirt path cut through it.
##
## Tiles come from the vendored Kenney "Tower Defense" kit. Which tile goes where
## is not guessed — `GRASS_EDGE_TILE` was derived by sampling the midpoint of each
## edge of all 299 kit PNGs and grouping them by (top, right, bottom, left) being
## dirt `#BB8044` or grass `#2ECC71`. tile050 is the only fully-pure dirt tile in
## the kit; the eight grass tiles below are its transitions.
##
## The path is the only place pests walk, and the only place plants may NOT go.

const CELL: int = 64
const COLS: int = 14
const ROWS: int = 9

## Corners of the pests' route, in walk order. Expanded to one waypoint per cell.
##
## MOVING THIS SPENDS A BUDGET YOU CANNOT SEE FROM HERE. Three numbers in other
## files were measured against the road these corners happen to produce, and
## nothing recomputes them:
##
##   - WaveDirector.SIMULTANEOUS_PEST_CEILING (40) is reasoned from "32 road
##     cells, 2112 px, about 3.5 pests per cell". A shorter road makes 40 more
##     crowded than the reasoning intends; a longer one stops it biting.
##   - the dead-ground count (15 of 94 cells).
##   - the Sundew's coverage arithmetic, stated against how much road one
##     placement reaches on THIS route.
##
## `python tools/devtools.py cmd board_info` prints the husk click budget, which
## is the one that is NOT at risk here — it walks the route, but the walk yields
## CELL/2 for any road, so the 4 px clearance is two constants. See
## test_the_road_is_still_the_road_the_constants_were_measured_against, which
## measures the route and fails naming what has to be re-derived.
## The road CLIMBS once, and that is deliberate (plant-tower-defense-84x0).
##
## The previous route ran right, down, left, down, right — never once travelling
## -Y. Pest._update_facing() has a `_facing = 0.0` branch for up-screen travel,
## every pest sprite rests head-up-screen to make it mean something, and neither
## had run in a single frame of a real game. A quarter of the walk animation was
## unreachable content.
##
## The reshape holds both invariants the constants above are reasoned from: 31
## steps over 32 cells, 1984 px plus two 64 px brackets = 2112 px, identical to
## the road they were measured against. That is not a coincidence — it is why
## these corners and not a freer shape. Re-derive nothing that depends only on
## length or cell count; DO re-check anything that depends on the road's SHAPE
## (dead ground, Sundew coverage), which has genuinely changed.
const PATH_CORNERS: Array[Vector2i] = [
	Vector2i(0, 1),
	Vector2i(6, 1),
	Vector2i(6, 4),
	Vector2i(2, 4),
	Vector2i(2, 7),
	Vector2i(9, 7),
	Vector2i(9, 3),
	Vector2i(13, 3),
]

const PATH_TILE: int = 50

## Plain grass. tile024 carries the kit's faint speckle; tiles 038-045, which look
## like grass variants by their colour histogram, are actually the kit's overlay
## markers (an empty plot square, a wrench, an X, a target) and scatter obvious
## UI junk across the field. Only a screenshot of the running game shows that.
const GRASS_TILE: int = 24

## Neighbour mask -> kit tile. bit0 = up is path, bit1 = right, bit2 = down,
## bit3 = left. The kit ships no tile for opposite-side or three-side dirt, so
## those fall back to plain grass; the path shape below never needs them.
const GRASS_EDGE_TILE: Dictionary = {
	0b0000: GRASS_TILE,
	0b0001: 116,
	0b0010: 92,
	0b0100: 70,
	0b1000: 94,
	0b0011: 73,
	0b0110: 96,
	0b1100: 95,
	0b1001: 72,
}

## Masks kept in GRASS_EDGE_TILE that the current road does NOT produce.
##
## Empty, deliberately. `test_every_grass_cell_has_a_tile_the_kit_actually_ships`
## asserts both directions: every mask the board produces has a tile (a hole in the
## road's edging), AND every entry above is a mask the board can reach. The second
## half had no assertion at all until it was added, so an entry left over from a
## reshaped road would have sat here indefinitely pointing at a tile nobody looks at.
##
## This is where an intentional exception goes if PATH_CORNERS ever grows a shape that
## needs a tile before the road that uses it — with the reason, since "it is unreachable
## on purpose" and "it is unreachable because we forgot" are the same silence otherwise.
const UNREACHABLE_EDGE_MASKS: Array[int] = []

## Lane pressure readout: how much a recorded cell fades on the *next* wave
## that records a different one, so the tint reads as "recent pressure", not
## a permanent stain from wave 1.
const LANE_PRESSURE_DECAY: float = 0.55
const LANE_PRESSURE_MIN_ALPHA: float = 0.03

var _path_cells: Dictionary = {}
var _path_order: Array[Vector2i] = []
var _route: PackedVector2Array = PackedVector2Array()
var _pressure_overlay: LanePressureOverlay = null
## Road cell -> total pests lost there across the whole run. Never faded; see
## run_losses(). Kept beside the overlay's decaying map rather than derived
## from it, because the decay is lossy by design and cannot be undone.
var _run_losses: Dictionary = {}
## The last batch record_lane_pressure_wave() actually accepted, raw counts and
## unnormalised. A wave that lost nothing never reaches that function's body, so
## this holds the last wave that *drew blood* rather than the last wave to end —
## which is the same thing the decaying overlay shows, and deliberately so: the
## prep line and the road must not describe two different waves.
var _last_wave_losses: Dictionary = {}
## Road cell -> how many of the losses recorded there were pests that walked out
## alive, run-total and never faded. A strict subset of _run_losses: every escape
## is recorded in both, because an escape IS a loss for the pressure map's
## purposes ("a pest stopped being your problem here") and is emphatically not a
## kill for the post-mortem's ("you held them here").
##
## In practice this map has exactly one key — Game._on_pest_escaped attributes
## every escape to exit_cell(), because an escaped pest's own position is off the
## board. That is not a defect and it is why there is no second *map* on the
## post-mortem card: the spatial content of an escape is a constant. What this is
## for is subtracting, so the exit cell cannot claim to be a chokepoint on the
## strength of pests that were never stopped there at all.
var _run_escapes: Dictionary = {}
## Road cell -> true for every cell nothing standing in the garden can aim at.
## Pushed in by Game (mark_unaimed_road) rather than derived here, because the
## garden is Game's to know about and Board deliberately knows only the ground.
##
## Kept on the Board as well as on the overlay so it can be read back on a Board
## that never entered the tree — the overlay is built in _ready(), and a query
## that answered "everything is aimed at" for a Board without one would be a
## confident wrong answer rather than a missing one.
var _unaimed: Dictionary = {}


func _ready() -> void:
	_build_path()
	_build_tiles()
	# Last child added = drawn last = on top of the tile sprites above.
	_pressure_overlay = LanePressureOverlay.new()
	add_child(_pressure_overlay)


## Every cell the path covers, in walk order. Built once, before the tiles.
func _build_path() -> void:
	if not _path_order.is_empty():
		return
	for i: int in range(PATH_CORNERS.size() - 1):
		var from: Vector2i = PATH_CORNERS[i]
		var to: Vector2i = PATH_CORNERS[i + 1]
		var step := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
		var at: Vector2i = from
		while at != to:
			_add_path_cell(at)
			at += step
	_add_path_cell(PATH_CORNERS[PATH_CORNERS.size() - 1])
	_build_route()


func _add_path_cell(cell: Vector2i) -> void:
	if _path_cells.has(cell):
		return
	# The value is the cell's position along the road, not a bare `true`.
	# `is_path` only ever asks `has`, so the slot was free, and storing the index
	# in it is what makes `path_index` a dictionary lookup rather than a linear
	# scan of _path_order once per cell per depth reading.
	_path_cells[cell] = _path_order.size()
	_path_order.append(cell)


## World-space walk route: one point per path cell centre, bracketed by an
## off-board entry and exit so pests walk in and out rather than popping.
func _build_route() -> void:
	var pts := PackedVector2Array()
	var first: Vector2i = _path_order[0]
	pts.append(cell_to_world(first) + Vector2(-CELL, 0))
	for cell: Vector2i in _path_order:
		pts.append(cell_to_world(cell))
	var last: Vector2i = _path_order[_path_order.size() - 1]
	pts.append(cell_to_world(last) + Vector2(CELL, 0))
	_route = pts


func _build_tiles() -> void:
	for y: int in range(ROWS):
		for x: int in range(COLS):
			var cell := Vector2i(x, y)
			var sprite := Sprite2D.new()
			sprite.centered = false
			sprite.position = Vector2(x * CELL, y * CELL)
			sprite.texture = _texture_for(cell)
			add_child(sprite)


func _texture_for(cell: Vector2i) -> Texture2D:
	if is_path(cell):
		return _kit_tile(PATH_TILE)
	var mask: int = 0
	if is_path(cell + Vector2i.UP):
		mask |= 0b0001
	if is_path(cell + Vector2i.RIGHT):
		mask |= 0b0010
	if is_path(cell + Vector2i.DOWN):
		mask |= 0b0100
	if is_path(cell + Vector2i.LEFT):
		mask |= 0b1000
	return _kit_tile(GRASS_EDGE_TILE.get(mask, GRASS_TILE))


func _kit_tile(number: int) -> Texture2D:
	return load("res://assets/kenney/png/towerDefense_tile%03d.png" % number) as Texture2D


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS


## Builds the path first, like path_cell_count() already did. Without that this
## answers "there is no road anywhere" on a Board that has not entered the tree
## — not an error, just a confident no — and every caller downstream
## (is_buildable, is_road_adjacent, path_index) inherits it. A test that built a
## Board without awaiting it therefore measured an empty board and passed, which
## is how this was found: two hatch tests failed on their own vacuity guard
## rather than on the hatch.
##
## _build_path() early-returns on a non-empty _path_order, so this costs one
## is_empty() check per call.
func is_path(cell: Vector2i) -> bool:
	_build_path()
	return _path_cells.has(cell)


## A plant may stand on any in-bounds cell that is not the pests' road.
func is_buildable(cell: Vector2i) -> bool:
	return is_inside(cell) and not is_path(cell)


## Is this cell within a hungry pest's reach of the road? Orthogonal only, and
## that is the whole definition rather than an approximation of one: Pest.EAT_RADIUS
## is CELL * 1.15, so a pest on the road can reach a plant one cell up, down,
## left or right of it and nothing diagonal, which is 1.41 cells away.
func is_road_adjacent(cell: Vector2i) -> bool:
	for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if is_path(cell + step):
			return true
	return false


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL + CELL * 0.5, cell.y * CELL + CELL * 0.5)


## The same centre in GLOBAL space, which is what `Node2D.to_local()` expects.
##
## `cell_to_world` is named "world" and returns BOARD-LOCAL — fine for every caller that
## sets a `position` on a sibling of the Board (they share a parent, so board-local *is*
## parent-relative) and a trap for the two that pass it to `to_local()`. `Entities` sits at
## `y = Hud.BAR_HEIGHT`, so those two drew every mark **72 px high — more than a full 64 px
## row**, putting road cues on the grass above them. Reported from a screenshot, not caught
## by any test, because every test asserted the POINTS and none asserted where they land.
##
## Use this at any site that hands a cell position to `to_local`, `global_position`, or
## anything else measuring from the viewport. `cell_to_world` stays for the sibling case,
## which is most of them.
func cell_to_global(cell: Vector2i) -> Vector2:
	return to_global(cell_to_world(cell))


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / float(CELL)), floori(pos.y / float(CELL)))


func path_cell_count() -> int:
	_build_path()
	return _path_order.size()


## Every road cell, in walk order — the same order path_index() numbers them in.
##
## The map half of the road, beside route()'s geometry half. Everything that asks
## a spatial question about the road had to rebuild this list by scanning
## ROWS x COLS and filtering on is_path(), which is 126 checks for a 32-cell
## answer and puts the walk order back together by accident rather than by
## reading the one place it is recorded.
##
## Builds first, for the reason is_path() spells out at length: a Board that has
## not entered the tree would otherwise answer "there is no road" — a confident
## empty list rather than an error — and a caller that then subtracts a coverage
## set from it would report a garden with no holes in it because it could not see
## any road to have holes in.
##
## A plain loop rather than `_path_order.duplicate()`: the copy is what stops a
## caller mutating the road out from under path_index(), and a loop says so where
## a duplicate() whose return type happens to survive does not.
func road_cells() -> Array[Vector2i]:
	_build_path()
	var out: Array[Vector2i] = []
	for cell: Vector2i in _path_order:
		out.append(cell)
	return out


func route() -> PackedVector2Array:
	_build_path()
	return _route


func board_size() -> Vector2:
	return Vector2(COLS * CELL, ROWS * CELL)


## The last path cell before the exit — where a pest that walked the whole road
## was lost. An escaped pest's own position is off the board by then, and
## record_lane_pressure_wave rightly refuses to paint a cell that is not road,
## so the caller needs somewhere real to attribute the escape to.
##
## Builds the path first, for the reason is_path() spells out at length: without
## it, a Board that has not entered the tree answers (-1, -1) — a confident "there
## is no exit" rather than an error — and a caller written against that gets a
## cell it will then quietly drop from every road-only filter. This was the last
## public query on this class that did not build, so `Board.new().exit_cell()`
## disagreed with `Board.new().path_cell_count()` about whether a road existed.
## Caught writing a post-mortem test that read the exit off a probe Board and got
## (-1, -1) back, which every subsequent assertion would have measured against.
func exit_cell() -> Vector2i:
	_build_path()
	if _path_order.is_empty():
		return Vector2i(-1, -1)
	return _path_order[_path_order.size() - 1]


## Called once per wave with every road cell that wave lost a pest at, mapped
## to how many were lost there. The busiest cell paints at full strength and
## the rest in proportion, so the readout is the *distribution* of a wave's
## damage rather than one hot pixel at its high-water mark.
##
## Normalising against the wave's own worst cell rather than against an
## absolute count is what keeps it readable at both ends of the game: wave 1
## sends five pests and an endless wave 40 sends eighty, and an absolute scale
## would paint the early game invisible and the late game uniformly saturated.
##
## Everything earlier fades by LANE_PRESSURE_DECAY exactly once for the whole
## batch — not once per cell, which is what made the naive "just call the
## single-cell version N times" version wrong: the first cell of a wave would
## be faded N-1 times by its own wave-mates before the player ever saw it.
func record_lane_pressure_wave(losses: Dictionary) -> void:
	if _pressure_overlay == null:
		return
	var fresh: Dictionary = {}
	var worst: float = 0.0
	for cell: Vector2i in losses:
		if not is_path(cell):
			continue
		var count: float = float(losses[cell])
		if count <= 0.0:
			continue
		fresh[cell] = count
		worst = maxf(worst, count)
	if fresh.is_empty():
		return
	for cell: Vector2i in fresh:
		_run_losses[cell] = int(_run_losses.get(cell, 0)) + int(fresh[cell])
	var out: Dictionary = {}
	for key: Vector2i in _pressure_overlay.pressure:
		if fresh.has(key):
			continue
		var next: float = float(_pressure_overlay.pressure[key]) * LANE_PRESSURE_DECAY
		if next >= LANE_PRESSURE_MIN_ALPHA:
			out[key] = next
	for cell: Vector2i in fresh:
		# Floored at MIN_ALPHA so a cell that lost one pest out of forty is
		# still visible — "one got through here" is exactly the thing worth
		# seeing, and it is the reading a pure proportion would erase.
		out[cell] = maxf(LANE_PRESSURE_MIN_ALPHA, float(fresh[cell]) / worst)
	# Kept raw rather than derived back out of `out`: `out` is normalised against
	# this wave's own worst cell, so every wave's peak is 1.0 there and a depth
	# read off it would weight a five-pest wave the same as an eighty-pest one.
	_last_wave_losses = fresh.duplicate()
	_pressure_overlay.pressure = out
	_pressure_overlay.queue_redraw()


## Single-cell convenience over record_lane_pressure_wave — same fade
## semantics, and the cell lands at full strength since it is its own worst.
func record_lane_pressure(cell: Vector2i) -> void:
	record_lane_pressure_wave({cell: 1})


## Every loss of the whole run, never faded. The per-wave map answers "where
## did I lose *this* wave" and fades by design, which is what makes it readable
## while playing and useless afterwards — by the time a run ends, wave 3's
## disaster has decayed to nothing. This is the other question: which ground
## bled you all game.
func run_losses() -> Dictionary:
	return _run_losses.duplicate()


## Run-total pressure at `cell`, normalised against the run's own worst cell so
## it reads the same way the per-wave map does.
func run_pressure_alpha(cell: Vector2i) -> float:
	var worst: int = 0
	for key: Vector2i in _run_losses:
		worst = maxi(worst, int(_run_losses[key]))
	if worst <= 0:
		return 0.0
	return maxf(LANE_PRESSURE_MIN_ALPHA, float(_run_losses.get(cell, 0)) / float(worst))


## The single cell that saw the most pests leave the road over the whole run,
## killed or escaped, or (-1, -1) if nothing was ever lost. What the *painted*
## map peaks at — run_pressure_alpha normalises against exactly this cell.
##
## Deliberately NOT what the post-mortem's row points at any more; see
## worst_stop_cell(). A kill and an escape are the same event to the tint, which
## is honest for "where did they stop being on the road", and they are opposite
## events to a sentence that recommends an action.
func worst_run_cell() -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var most: int = 0
	for cell: Vector2i in _run_losses:
		var count: int = int(_run_losses[cell])
		if count > most:
			most = count
			best = cell
	return best


## Commits a wave's escapes. Called beside record_lane_pressure_wave, with the
## same cells and a subset of its counts — never instead of it, or a cell would
## report more escapes than losses and stops_at() would floor to zero for a cell
## that really did kill things.
func record_escapes(escapes: Dictionary) -> void:
	for cell: Vector2i in escapes:
		# Same road-only filter record_lane_pressure_wave applies, and for the
		# same reason: a count against a cell the pressure map refused would be
		# subtracted from a loss total that never included it.
		if not is_path(cell):
			continue
		var count: int = int(escapes[cell])
		if count <= 0:
			continue
		_run_escapes[cell] = int(_run_escapes.get(cell, 0)) + count


## Every escape of the whole run, by cell. See _run_escapes for why this is
## almost always a single entry at the exit.
func run_escapes() -> Dictionary:
	return _run_escapes.duplicate()


## Pests this cell stopped **for good** — losses minus escapes. This is the
## number a player can act on: it is how much work the ground at `cell` actually
## did, with the pests that merely passed their last road cell taken back out.
##
## Floored at 0 rather than allowed to go negative. record_escapes is documented
## as a companion to record_lane_pressure_wave and not a replacement, but a
## caller that ignores that must not be able to make a cell report a negative
## amount of defending.
func stops_at(cell: Vector2i) -> int:
	return maxi(0, int(_run_losses.get(cell, 0)) - int(_run_escapes.get(cell, 0)))


## The cell that stopped the most pests for good over the whole run, or (-1, -1)
## if nothing was ever stopped anywhere.
##
## This is the post-mortem's cell. It differs from worst_run_cell() in exactly
## one situation and it is the situation that mattered: a run bleeding out at the
## exit piles every escape onto the exit cell, which then wins worst_run_cell()
## on the strength of pests it never touched. Naming that cell to the player, on
## a row that then invites them to reinforce or abandon it, is advice drawn from
## the one cell in the run that did the least.
##
## (-1, -1) is not the same claim as "a clean run". A run that stopped nothing
## anywhere is the worst run there is, and the card must not read it as the best;
## the clean-run reading lives on the beds-lost row, which measures it directly.
func worst_stop_cell() -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var most: int = 0
	for cell: Vector2i in _run_losses:
		var count: int = stops_at(cell)
		if count > most:
			most = count
			best = cell
	return best


## Where `cell` sits along the road: 0 at the entry, path_cell_count() - 1 at
## the exit, and -1 for anything that is not road.
func path_index(cell: Vector2i) -> int:
	_build_path()
	return int(_path_cells.get(cell, -1))


## How far down the road a batch of losses landed — 0.0 stopped on the entry
## cell, 1.0 stopped on the exit cell — weighted by how many stopped at each.
##
## This board has ONE road. PATH_CORNERS traces a single snake from (0, 1) to
## (13, 7), so "which lane is leaking" is not a question the geometry can pose;
## the only spatial variable a loss carries is how far along that snake it
## happened. Depth is therefore the whole of what a pressure map says, reduced
## to the one number that can be compared between two waves.
##
## A mean, not a high-water mark. record_lane_pressure_wave was rewritten off a
## high-water mark for exactly this reason — a wave stopped cleanly at three
## separate points and a wave stopped once at its furthest read identically —
## and a mean moves only when the *bulk* of a wave gets deeper, so one lucky
## straggler cannot fake it.
##
## Note what is being counted. Game._note_lane_loss fires on a kill as well as
## on an escape, so `losses` is every pest that STOPPED there, not every pest
## that hurt you. That makes this "how far are they getting", which is the
## honest reading and the useful one: it rises while your front line is being
## outrun, waves before anything actually escapes.
##
## That mixing is correct here and correct for the tint, and it is wrong for any
## reading phrased as *which ground failed you* — the two are near-opposites at
## the cell level. stops_at() / worst_stop_cell() are that other question; a
## depth or a tint must keep using the mixed totals.
##
## Returns -1.0 for "nothing recorded", which is not 0.0. A wave killed dead on
## the entry cell genuinely reads 0%, and that is the best reading in the game;
## a caller that cannot tell it from an empty run would either hide it or boast
## about a wave that never fought.
func depth_of(losses: Dictionary) -> float:
	_build_path()
	var last: int = _path_order.size() - 1
	if last <= 0:
		return -1.0
	var weighted: float = 0.0
	var total: float = 0.0
	for cell: Vector2i in losses:
		var index: int = path_index(cell)
		if index < 0:
			continue
		var count: float = float(losses[cell])
		if count <= 0.0:
			continue
		weighted += float(index) * count
		total += count
	if total <= 0.0:
		return -1.0
	return weighted / (float(last) * total)


## Mean stopping depth over the whole run, unfaded. The "which ground has been
## giving way all game" half of the readout.
func run_depth() -> float:
	return depth_of(_run_losses)


## Mean stopping depth of the last wave that drew blood. The "what just went
## wrong" half — the same wave the road is currently tinted for.
func last_wave_depth() -> float:
	return depth_of(_last_wave_losses)


## Swaps the overlay from the decaying per-wave map to the run total. One-way
## and deliberately so: this is called once, when the run ends, and there is
## nothing left to play that would want the live map back.
func show_run_pressure() -> void:
	if _pressure_overlay == null or _run_losses.is_empty():
		return
	var out: Dictionary = {}
	for cell: Vector2i in _run_losses:
		out[cell] = run_pressure_alpha(cell)
	_pressure_overlay.pressure = out
	_pressure_overlay.queue_redraw()


## Current tint strength at `cell`, 0.0 if nothing has been recorded there
## (or it has faded past LANE_PRESSURE_MIN_ALPHA). Test/devtools hook so
## callers don't reach into the overlay node directly.
func lane_pressure_alpha(cell: Vector2i) -> float:
	if _pressure_overlay == null:
		return 0.0
	return float(_pressure_overlay.pressure.get(cell, 0.0))


## Tells the road which of its cells no standing plant currently has in range,
## so the pressure hatch can draw those cells at the mirrored angle. Game calls
## this from _refresh() with uncovered_road_cells(); see LanePressureOverlay's
## `unaimed` for the whole argument about why an angle and not a colour.
##
## Non-road cells are dropped, the same filter record_lane_pressure_wave applies
## and for the same reason: the overlay only ever draws road, so a mark against
## ground that is not road is a mark nothing can render and nothing can clear.
##
## Returns whether the set actually changed. That is not decoration — this is
## called from every _refresh(), which fires on every seed payout, and a
## queue_redraw() on each of those would repaint the whole road several times a
## second to show the same picture. It is also the assertion a test wants: "the
## stripes rotated when the plant landed" is a claim about a change.
func mark_unaimed_road(cells: Array[Vector2i]) -> bool:
	var next: Dictionary = {}
	for cell: Vector2i in cells:
		if is_path(cell):
			next[cell] = true
	if next.size() == _unaimed.size():
		var same: bool = true
		for cell: Vector2i in next:
			if not _unaimed.has(cell):
				same = false
				break
		if same:
			return false
	_unaimed = next
	if _pressure_overlay != null:
		_pressure_overlay.unaimed = _unaimed
		_pressure_overlay.queue_redraw()
	return true


## Is `cell` currently marked as ground nothing is aimed at? The read-back beside
## lane_pressure_alpha(), and for the same reason: callers ask the Board rather
## than reaching into the overlay node, so a Board without one answers from its
## own copy instead of answering false for everything.
func is_unaimed(cell: Vector2i) -> bool:
	return _unaimed.has(cell)
