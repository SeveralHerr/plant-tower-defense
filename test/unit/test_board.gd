extends RefCounted

## The playfield's invariants.
##
## The path shape is not decoration: it decides where plants may stand, how long
## a pest is on screen, and — because the Kenney kit ships no tile for dirt on
## opposite or three sides of a grass cell — whether the board can even be drawn
## without a hole in the art. Those are the two things asserted here.

var _T


func _board() -> Board:
	var board := Board.new()
	# Board builds its path lazily on first query, so no tree is needed to ask it
	# about geometry — only the tile sprites want a running scene.
	return board


func test_route_covers_every_path_cell_plus_an_entry_and_an_exit() -> String:
	var board: Board = _board()
	var cells: int = board.path_cell_count()
	var err: String = _T.assert_gt(cells, 20, "the road is long enough to be worth defending")
	if err != "":
		return err
	return _T.assert_eq(board.route().size(), cells + 2,
		"route = one point per path cell, bracketed by an off-board entry and exit")


func test_the_road_is_continuous_and_never_jumps_a_cell() -> String:
	var board: Board = _board()
	var route: PackedVector2Array = board.route()
	for i: int in range(1, route.size()):
		var step: float = route[i].distance_to(route[i - 1])
		var err: String = _T.assert_true(step <= Board.CELL + 0.01,
			"step %d is one cell or less (was %.1f px) — a gap here teleports pests over a plant" % [i, step])
		if err != "":
			return err
	return ""


func test_plants_may_not_stand_on_the_road() -> String:
	var board: Board = _board()
	var route: PackedVector2Array = board.route()
	for i: int in range(1, route.size() - 1):
		var cell: Vector2i = board.world_to_cell(route[i])
		var err: String = _T.assert_false(board.is_buildable(cell), "cell %s is road, not a plot" % cell)
		if err != "":
			return err
	return ""


func test_every_grass_cell_has_a_tile_the_kit_actually_ships() -> String:
	## The kit has no dirt-on-opposite-sides or dirt-on-three-sides grass tile. A
	## path that needed one would silently fall back to plain grass and leave a
	## square hole in the road's edging — visible only in a screenshot.
	var board: Board = _board()
	var checked: int = 0
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var cell := Vector2i(x, y)
			if board.is_path(cell):
				continue
			var mask: int = 0
			if board.is_path(cell + Vector2i.UP):
				mask |= 0b0001
			if board.is_path(cell + Vector2i.RIGHT):
				mask |= 0b0010
			if board.is_path(cell + Vector2i.DOWN):
				mask |= 0b0100
			if board.is_path(cell + Vector2i.LEFT):
				mask |= 0b1000
			checked += 1
			var err: String = _T.assert_true(Board.GRASS_EDGE_TILE.has(mask),
				"cell %s needs edge mask %d, which the Kenney kit has no tile for" % [cell, mask])
			if err != "":
				return err
	return _T.assert_gt(checked, 60, "the sweep actually visited the grass (empty sweep = vacuous pass)")


func test_cell_and_world_round_trip() -> String:
	var board: Board = _board()
	var cell := Vector2i(5, 3)
	return _T.assert_eq(board.world_to_cell(board.cell_to_world(cell)), cell,
		"a cell centre converts back to the same cell")
