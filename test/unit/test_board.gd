extends RefCounted

## The playfield's invariants.
##
## The path shape is not decoration: it decides where plants may stand, how long
## a pest is on screen, and — because the Kenney kit ships no tile for dirt on
## opposite or three sides of a grass cell — whether the board can even be drawn
## without a hole in the art. Those are the first two things asserted here.
##
## The third is what the board *says* on top of that shape. Every warning surface
## on the playfield is GardenTheme.DANGER — the lane pressure tint, the hover
## cursor over a cell you may not build on, a plant being chewed — so hue cannot
## tell them apart and, for a player who cannot separate reds, never could. The
## board therefore carries a second channel that is not colour, under one rule: a
## solid red surface is a live warning, a broken one is a record or a recovery.
## The cases below assert the *break*, not the constants that describe it.

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


# --- The second warning channel (plant-tower-defense-e0m) -------------------
#
# Two surfaces, one rule. Lane pressure is hatched because the flat cursor tint
# it shares a cell with is not; a regrowing plant's bar is notched because a
# bleeding one is not. Each case below asserts that the two things differ in
# something a greyscale screenshot would still show, which is the only form of
# the assertion that says anything about the player the cue exists for.


func test_lane_pressure_paints_a_hatch_and_not_a_fill() -> String:
	## The claim is not "a hatch constant exists" but "the paint leaves gaps".
	## Game._update_cursor paints Color(GardenTheme.DANGER, 0.30) as a flat 64px
	## square over the hovered cell, and this readout used to paint the same red as
	## a flat 64px square over the same cell — stacked on the same pixels every time
	## the player hovers the road during prep, which is exactly when the tint is
	## meant to be read. A wash over a wash is one deeper wash; a wash over stripes
	## still has stripes in it, and that only holds while the stripes have gaps.
	var board: Board = _board()
	var err: String = _T.assert_true(board != null, "there is a board to ask about")
	if err != "":
		return err
	var cell := Vector2i(4, 1)
	err = _T.assert_true(board.is_path(cell), "cell %s is road, so it can carry pressure" % cell)
	if err != "":
		return err
	var origin: Vector2 = Vector2(cell) * float(Board.CELL)
	var inked: int = 0
	var bare: int = 0
	var samples: int = 0
	for sy: int in range(1, Board.CELL, 3):
		for sx: int in range(1, Board.CELL, 3):
			samples += 1
			if LanePressureOverlay.is_hatched(origin + Vector2(float(sx), float(sy))):
				inked += 1
			else:
				bare += 1
	err = _T.assert_gt(samples, 100, "the sweep visited the cell (an empty sweep passes vacuously)")
	if err == "":
		err = _T.assert_gt(inked, 0, "some of the cell is painted — a hatch that inks nothing is no readout")
	if err == "":
		# A threshold rather than "> 0": a hatch that leaves one pixel bare is not a
		# fill by the letter of it and is a fill to every eye that looks at the
		# board. The geometry gives 43% (see HATCH_ALPHA), so a fifth of the cell is
		# a floor with real room under it, and a stripe widened until the gaps close
		# fails here instead of quietly going back to being a wash.
		err = _T.assert_gt(float(bare) / float(samples), 0.2,
			("and a real share of it is not: %d of %d sample points are bare. That gap is "
				+ "what survives the cursor's flat wash being painted over the top, and it "
				+ "is the whole difference between a second channel and a second red")
				% [bare, samples])
	return err


func test_the_lane_hatch_runs_at_one_angle_and_stays_inside_its_own_cell() -> String:
	## A stripe that leaks past the cell edge paints a reading onto ground that did
	## not earn it — the pressure map is per-cell, and a cell with no losses must
	## stay clean. One angle throughout, because a hatch whose angle varies reads as
	## two different marks rather than as one texture.
	var cell := Vector2i(4, 1)
	var segments: PackedVector2Array = LanePressureOverlay.hatch_segments(cell)
	var err: String = _T.assert_gt(segments.size(), 0, "the cell hatches at all")
	if err != "":
		return err
	err = _T.assert_eq(segments.size() % 2, 0, "the stripes come back as from/to pairs")
	if err != "":
		return err
	var box := Rect2(Vector2(cell) * float(Board.CELL),
		Vector2(float(Board.CELL), float(Board.CELL))).grow(0.001)
	var checked: int = 0
	var i: int = 0
	while i + 1 < segments.size():
		var from: Vector2 = segments[i]
		var to: Vector2 = segments[i + 1]
		i += 2
		checked += 1
		err = _T.assert_true(box.has_point(from) and box.has_point(to),
			"stripe %s -> %s stays inside its cell %s" % [from, to, box])
		if err != "":
			return err
		var span: Vector2 = to - from
		err = _T.assert_gt(span.length(), 0.0, "stripe %s -> %s has a length worth drawing" % [from, to])
		if err != "":
			return err
		err = _T.assert_float_eq(absf(span.x), absf(span.y), 0.001,
			"and runs at the same 45 degrees every other stripe does")
		if err != "":
			return err
	return _T.assert_gt(checked, 3,
		"several stripes crossed the cell — one stripe is a line, not a texture")


func test_the_lane_hatch_lines_up_across_neighbouring_road_cells() -> String:
	## Intercepts computed per cell would tile the road into 64px squares with a
	## seam on every boundary, which reads as a grid of separate warnings rather
	## than as one stretch of road that bled. They are laid out in the board's own
	## space instead, so both cells' stripes must sit on the same lattice.
	var board: Board = _board()
	var err: String = _T.assert_true(board != null, "there is a board to ask about")
	if err != "":
		return err
	var pair: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1)]
	var endpoints: int = 0
	for cell: Vector2i in pair:
		err = _T.assert_true(board.is_path(cell), "cell %s is road" % cell)
		if err != "":
			return err
		var segments: PackedVector2Array = LanePressureOverlay.hatch_segments(cell)
		err = _T.assert_gt(segments.size(), 0, "cell %s hatches at all" % cell)
		if err != "":
			return err
		for point: Vector2 in segments:
			endpoints += 1
			var d: float = point.x - point.y
			var lattice: float = round(d / LanePressureOverlay.HATCH_SPACING) \
				* LanePressureOverlay.HATCH_SPACING
			err = _T.assert_float_eq(absf(d - lattice), 0.0, 0.001,
				("stripe endpoint %s in cell %s sits on the board-wide lattice — "
					+ "a per-cell one seams at every boundary") % [point, cell])
			if err != "":
				return err
	return _T.assert_gt(endpoints, 10, "both cells contributed stripes to check")


func test_a_bleeding_plant_and_a_regrowing_one_differ_in_more_than_their_colour() -> String:
	## The bar was red for "being eaten" and green for "growing back" and nothing
	## else: one rect, one position, one size, two hues — and that pair is the
	## commonest colour-vision deficiency there is. A real decision hangs off it
	## (scrap the wreck for uproot_refund() now, or wait seconds_to_full_from() and
	## get a whole plant), and the only thing pinning the cue asserted precisely the
	## channel that does not reach the player it matters most to. So: assert the two
	## states are still told apart with the colour thrown away.
	var hurt: int = Plant.health_bar_segments(false)
	var healing: int = Plant.health_bar_segments(true)
	var err: String = _T.assert_eq(hurt, 1, "a bleeding bar is one solid block")
	if err == "":
		err = _T.assert_gt(healing, hurt,
			"a regrowing one is cut into %d — same rect, same place, different shape" % healing)
	if err == "":
		# The colour channel is still asserted, so a later merge cannot collapse the
		# two hues and leave this green on the shape alone. Two channels, not a swap.
		err = _T.assert_true(Plant.health_bar_color(true) != Plant.health_bar_color(false),
			"the two colours still differ as well — the shape is a second channel, not a replacement")
	if err == "":
		var notches: Array[Rect2] = Plant.health_bar_notch_rects()
		err = _T.assert_eq(notches.size(), healing - 1,
			"and %d blocks are what %d dividers cut" % [healing, notches.size()])
	return err


func test_the_health_bar_dividers_stay_inside_the_bar_and_never_merge() -> String:
	## Two dividers that touch read as one wide gap, at which point the blocks stop
	## being countable and the shape channel has quietly become a texture that says
	## nothing. And a divider on either end would eat the fill's start or a full
	## bar's finish, which are the two places the bar is read as a quantity.
	var slot := Rect2(Plant.HEALTH_BAR_ORIGIN, Plant.HEALTH_BAR_SIZE)
	var notches: Array[Rect2] = Plant.health_bar_notch_rects()
	var err: String = _T.assert_gt(notches.size(), 0, "there are dividers to check")
	if err != "":
		return err
	var ink: float = 0.0
	for i: int in range(notches.size()):
		var notch: Rect2 = notches[i]
		ink += notch.size.x
		err = _T.assert_true(slot.encloses(notch),
			"divider %d %s stays inside the bar %s" % [i, notch, slot])
		if err != "":
			return err
		err = _T.assert_gt(notch.position.x, slot.position.x,
			"divider %d clears the left end, where the fill starts" % i)
		if err != "":
			return err
		err = _T.assert_gt(slot.end.x, notch.end.x,
			"and the right end, where a full bar reaches")
		if err != "":
			return err
		for j: int in range(i + 1, notches.size()):
			err = _T.assert_false(notch.intersects(notches[j]),
				"dividers %d %s and %d %s stay apart" % [i, notch, j, notches[j]])
			if err != "":
				return err
	return _T.assert_gt(slot.size.x - ink, slot.size.x * 0.5,
		"the dividers spend %.0f of %.0f px, leaving the majority of the bar as fill" % [ink, slot.size.x])


func test_a_live_plants_bar_actually_wears_the_shape_it_is_told_to() -> String:
	## The three above are statements about pure functions. This is the one that says
	## the nodes on the board follow them — a shape channel that exists only in a
	## static method is a channel no player ever sees. It also pins the part that
	## makes the cue honest: the width, which is the *quantity*, does not move when
	## the shape does, so the second channel adds a reading rather than distorting
	## the one already there.
	var plant := Plant.new()
	var err: String = _T.assert_true(plant != null, "a plant to inspect")
	if err != "":
		return err
	plant.setup(PlantCatalog.CORN, Vector2i(2, 2), null)
	err = _T.assert_true(plant._health_bar != null, "it built a health bar")
	if err == "":
		err = _T.assert_gt(plant._health_notches.size(), 0, "and the dividers that cut it")
	if err != "":
		plant.free()
		return err
	# Bitten this frame: half eaten and not yet recovering.
	plant.health = Plant.MAX_HEALTH * 0.5
	plant._quiet_time = 0.0
	plant._refresh_health_bar()
	var bleeding_width: float = plant._health_bar.size.x
	err = _T.assert_false(plant.is_regrowing(), "a plant bitten this frame is not regrowing")
	if err == "":
		err = _T.assert_false(plant._health_notches[0].visible, "so its bar is left whole")
	if err == "":
		err = _T.assert_gt(bleeding_width, 0.0, "and the bar has a width to compare against")
	# Same health, same width, but quiet for long enough that it is healing.
	if err == "":
		plant._quiet_time = Plant.REGROWTH_DELAY
		plant._refresh_health_bar()
		err = _T.assert_true(plant.is_regrowing(), "after the delay it is regrowing")
	if err == "":
		err = _T.assert_true(plant._health_notches[0].visible, "which cuts the bar into blocks")
	if err == "":
		err = _T.assert_float_eq(plant._health_bar.size.x, bleeding_width, 0.001,
			"at the same width as before — the shape changed and the quantity did not")
	# Whole again: neither cue, because a full bar was never a warning.
	if err == "":
		plant.health = Plant.MAX_HEALTH
		plant._refresh_health_bar()
		err = _T.assert_false(plant._health_bar.visible, "a whole plant hides the bar")
	if err == "":
		err = _T.assert_false(plant._health_notches[0].visible, "and its dividers with it")
	plant.free()
	return err
