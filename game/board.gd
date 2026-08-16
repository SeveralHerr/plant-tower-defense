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
const PATH_CORNERS: Array[Vector2i] = [
	Vector2i(0, 1),
	Vector2i(9, 1),
	Vector2i(9, 4),
	Vector2i(3, 4),
	Vector2i(3, 7),
	Vector2i(13, 7),
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
	_path_cells[cell] = true
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


func is_path(cell: Vector2i) -> bool:
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


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / float(CELL)), floori(pos.y / float(CELL)))


func path_cell_count() -> int:
	_build_path()
	return _path_order.size()


func route() -> PackedVector2Array:
	_build_path()
	return _route


func board_size() -> Vector2:
	return Vector2(COLS * CELL, ROWS * CELL)


## The last path cell before the exit — where a pest that walked the whole road
## was lost. An escaped pest's own position is off the board by then, and
## record_lane_pressure_wave rightly refuses to paint a cell that is not road,
## so the caller needs somewhere real to attribute the escape to.
func exit_cell() -> Vector2i:
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


## The single cell that cost the most over the whole run, or (-1, -1) if
## nothing was ever lost. What the post-mortem points at.
func worst_run_cell() -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var most: int = 0
	for cell: Vector2i in _run_losses:
		var count: int = int(_run_losses[cell])
		if count > most:
			most = count
			best = cell
	return best


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
