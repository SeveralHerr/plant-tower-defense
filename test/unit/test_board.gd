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


# --- Clicks the board never received (plant-tower-defense-ygh) --------------
#
# Every action the player has on the playfield is a left click, and Game reads
# all of them out of _unhandled_input (Game._click_at). The viewport's GUI pass
# runs *first*, and a Control parented to a Node2D is a GUI root picked in world
# space — so a bare ColorRect over the board at the default MOUSE_FILTER_STOP
# does not misroute a click, it deletes one. Plant and Pest both park health
# bars there.
#
# The three cases below are deliberately of two kinds. Two drive a real
# InputEventMouseButton through the hosted viewport and assert what the *board*
# did with it, because "the property is IGNORE" is a statement about a field and
# "the click selected the plant" is a statement about the game. The third
# enumerates every world-space Control the running game owns and demands the
# property of all of them, because the first two only ever prove it about the
# rects that happen to exist today.

const GAME_SCENE := "res://game/game.tscn"


func _left_click(at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	event.global_position = at
	return event


## First plot below the top row. Row 0 sits under the HUD bar, which is a
## screen-space Control that is *supposed* to take the click, so a plant there
## would make the assertions below say nothing.
func _plot_below_the_top_row(game: Game) -> Vector2i:
	for y: int in range(1, Board.ROWS):
		for x: int in range(Board.COLS):
			var cell := Vector2i(x, y)
			if game.board.is_buildable(cell) and game.plant_at(cell) == null:
				return cell
	return Vector2i(-1, -1)


## Every Control that is NOT inside a CanvasLayer, i.e. everything drawn in board
## space rather than on the screen. The HUD, the pause card and the run summary
## all live under CanvasLayers and are excluded on purpose: a modal backdrop that
## stops the mouse is doing its job, and RunSummary's says exactly that in its
## own comment.
func _world_space_controls(node: Node, under_layer: bool, out: Array[Control]) -> void:
	var layered: bool = under_layer or node is CanvasLayer
	var control := node as Control
	if control != null and not layered:
		out.append(control)
	for child: Node in node.get_children():
		_world_space_controls(child, layered, out)


func test_a_damaged_plants_health_bar_does_not_eat_the_click_on_its_cell() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	var cell: Vector2i = _plot_below_the_top_row(game)
	err = _T.assert_true(game.board.is_buildable(cell), "there is a plot to plant on (got %s)" % cell)
	if err != "":
		_T.free_ui(game)
		return err
	game.bank.add_seeds(100)
	err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "", "a plant goes in at %s" % cell)
	var plant: Plant = game.plant_at(cell)
	if err == "":
		err = _T.assert_true(plant != null, "and the board hands it back")
	if err != "":
		_T.free_ui(game)
		return err
	var viewport: Viewport = game.get_viewport()
	err = _T.assert_true(viewport != null, "there is a viewport to push events through")
	if err != "":
		_T.free_ui(game)
		return err

	# The bar only exists once something has bitten the plant, which is what made
	# this easy to miss: the dead patch appears on the plants the player has a
	# reason to click, and never on the ones they do not.
	plant.take_damage(Plant.MAX_HEALTH * 0.25)
	err = _T.assert_true(plant._health_back != null and plant._health_back.visible,
		"a bitten plant is wearing its health bar")
	if err != "":
		_T.free_ui(game)
		return err

	# CONTROL. If this fails, nothing below means anything — the probe never
	# reached Game at all, and a green run would be measuring the event pipeline
	# rather than the health bar.
	game._select(null)
	_T.dispatch_events(viewport, [_left_click(plant.global_position)])
	err = _T.assert_true(game.selected_placed == plant,
		"CONTROL: a click at the middle of the cell reaches Game._click_at and selects the plant")
	if err != "":
		_T.free_ui(game)
		return err

	# Taken off the node rather than off HEALTH_BAR_ORIGIN, so the point is where
	# the bar actually is and not where the constants say it should be — then
	# checked against the cell, because a bar hanging entirely outside the
	# clickable board would make the whole case moot.
	var over_bar: Vector2 = plant._health_back.get_global_rect().get_center()
	var entities_origin: Vector2 = plant.global_position - plant.position
	err = _T.assert_eq(game.board.world_to_cell(over_bar - entities_origin), cell,
		"the middle of the bar %s sits over the plant's own cell %s" % [over_bar, cell])
	if err == "":
		err = _T.assert_true(plant._health_back.get_global_rect().has_point(over_bar),
			"and inside the bar's own rect %s" % plant._health_back.get_global_rect())
	if err != "":
		_T.free_ui(game)
		return err

	game._select(null)
	err = _T.assert_true(game.selected_placed == null, "deselected, so the next click has to do the work")
	if err == "":
		_T.dispatch_events(viewport, [_left_click(over_bar)])
		err = _T.assert_true(game.selected_placed == plant,
			("a click on the health bar reaches the board too. At MOUSE_FILTER_STOP the "
				+ "viewport's GUI pass swallows it and _unhandled_input never runs, so a "
				+ "click on a damaged plant does nothing whatsoever"))
	_T.free_ui(game)
	return err


func test_a_pests_health_bar_does_not_eat_the_click_on_the_husk_under_it() -> String:
	## The same defect on a moving target, and the case that is worse than the
	## plant's: husks only ever land on the road (Board.route() is one point per
	## road cell, and pests walk nothing else), so a pest's bar drifts over the
	## compost the player is reaching for and blanks the click that collects it.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	var route: PackedVector2Array = game.board.route()
	err = _T.assert_gt(route.size(), 13, "the road is long enough to hold two far-apart husks")
	if err != "":
		_T.free_ui(game)
		return err
	game.spawn_pest(Pest.APHID)
	var pests: Array[Node] = game.get_tree().get_nodes_in_group("pests")
	err = _T.assert_eq(pests.size(), 1, "exactly one pest on the board, so the right one is picked")
	if err != "":
		_T.free_ui(game)
		return err
	var pest := pests[0] as Pest
	err = _T.assert_true(pest != null, "and it is a Pest")
	if err != "":
		_T.free_ui(game)
		return err
	var viewport: Viewport = game.get_viewport()
	err = _T.assert_true(viewport != null, "there is a viewport to push events through")
	if err != "":
		_T.free_ui(game)
		return err

	# Parked on a road cell rather than left at route()[0], which is the off-board
	# entry point and is not ground anything can be clicked on.
	pest.position = route[2]
	var entities_origin: Vector2 = pest.global_position - pest.position
	err = _T.assert_true(pest._health_back != null and pest._health_back.visible,
		"a live pest always wears its bar — unlike a plant's, this one needs no damage first")
	if err != "":
		_T.free_ui(game)
		return err

	# CONTROL: a husk on bare road, far from the pest, collected through the same
	# machinery. A failure here is the probe, not the bar.
	var far: Vector2 = route[12]
	err = _T.assert_gt(far.distance_to(pest.position), CompostMeter.COLLECT_RADIUS * 2.0,
		"the control husk is well outside the sweep radius of the one under the pest")
	if err != "":
		_T.free_ui(game)
		return err
	game.compost.drop_husk(far, 5)
	var before: int = game.bank.seeds
	_T.dispatch_events(viewport, [_left_click(far + entities_origin)])
	err = _T.assert_eq(game.bank.seeds, before + 5,
		"CONTROL: a click on open road sweeps the husk under it and pays for it")
	if err != "":
		_T.free_ui(game)
		return err

	var over_bar: Vector2 = pest._health_back.get_global_rect().get_center()
	err = _T.assert_eq(game.board.world_to_cell(over_bar - entities_origin),
		game.board.world_to_cell(pest.position),
		"the middle of the pest's bar %s is over the road cell it stands on" % over_bar)
	if err != "":
		_T.free_ui(game)
		return err
	# Dropped exactly under the bar rather than at the pest's feet: the claim being
	# tested is that the click reaches Game, and putting the husk on the clicked
	# point keeps CompostMeter.COLLECT_RADIUS out of the verdict.
	game.compost.drop_husk(over_bar - entities_origin, 7)
	before = game.bank.seeds
	_T.dispatch_events(viewport, [_left_click(over_bar)])
	err = _T.assert_eq(game.bank.seeds, before + 7,
		("a click on the strip a pest's health bar covers still reaches the board. At "
			+ "MOUSE_FILTER_STOP the husk under a passing pest is uncollectable, and the "
			+ "player gets no cue at all that anything happened"))
	_T.free_ui(game)
	return err


func test_every_world_space_control_in_a_live_game_is_click_transparent() -> String:
	## Enumerated from the running tree rather than listed by hand, because a list
	## is exactly what goes stale: the notch dividers were added to the health bar
	## long after the two bars they sit between, and the rule they had to obey was
	## written down nowhere except in those bars' own (wrong) filter. Anything
	## Control-shaped that is not inside a CanvasLayer is drawn on the board, and
	## the board is read through _unhandled_input, so all of it must pass a click.
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	var err: String = _T.assert_true(game != null, "the main scene loads")
	if err != "":
		return err
	var cell: Vector2i = _plot_below_the_top_row(game)
	game.bank.add_seeds(100)
	err = _T.assert_eq(game.place_plant(PlantCatalog.CORN, cell), "", "a plant is on the board")
	var plant: Plant = game.plant_at(cell)
	if err == "":
		err = _T.assert_true(plant != null, "and can be inspected")
	if err != "":
		_T.free_ui(game)
		return err
	# Bitten, so the bar, its backing and the regrowth notches are all real nodes
	# in the tree by the time the sweep below walks it.
	plant.take_damage(Plant.MAX_HEALTH * 0.5)
	game.spawn_pest(Pest.APHID)

	var found: Array[Control] = []
	_world_space_controls(game, false, found)
	err = _T.assert_gt(found.size(), 5,
		"the sweep found the board's Controls at all (an empty sweep passes vacuously)")
	if err != "":
		_T.free_ui(game)
		return err
	var saw_plant_bar: bool = false
	var saw_pest_bar: bool = false
	for control: Control in found:
		if control == plant._health_bar:
			saw_plant_bar = true
		err = _T.assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			("%s (%s) is drawn on the playfield and stops the mouse — the viewport's GUI "
				+ "pass eats the click before Game._unhandled_input is ever offered it")
				% [game.get_path_to(control), control.get_class()])
		if err != "":
			break
	if err == "":
		for node: Node in game.get_tree().get_nodes_in_group("pests"):
			var pest := node as Pest
			if pest == null:
				continue
			if found.has(pest._health_bar):
				saw_pest_bar = true
	if err == "":
		err = _T.assert_true(saw_plant_bar, "the plant's own health bar was one of the Controls checked")
	if err == "":
		err = _T.assert_true(saw_pest_bar, "and so was a pest's")
	_T.free_ui(game)
	return err
