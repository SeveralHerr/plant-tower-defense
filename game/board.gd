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

var _path_cells: Dictionary = {}
var _path_order: Array[Vector2i] = []
var _route: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	_build_path()
	_build_tiles()


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
