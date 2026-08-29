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

## Where this script's RunConfig writes go instead of the player's own save.
## The reasoning is written out once, in test_combat.gd's setup().
##
## This file wrote nothing to RunConfig for a hundred cycles and then did, without
## gaining a line that mentions it: plant-tower-defense-gz53 put a one-shot hint on
## the `_refresh()` funnel, which put `_save()` on the end of a chain any test that
## places a plant already walks —
## `place_plant() -> _refresh() -> _maybe_teach_upgrading() -> spend_hint() -> _save()`.
## `tools/save_persist_check.py` printed that chain and named the two tests here that
## reach it, before a single test had been run. That is the whole argument for the
## checker: nothing in this file changed, and this file became a writer.
const SUITE_SAVE_PATH := "user://test_board_suite.save"
var _suite_stashed_save_path: String = ""


func setup() -> void:
	_suite_stashed_save_path = RunConfig.save_path
	RunConfig.save_path = SUITE_SAVE_PATH


func teardown() -> void:
	if _suite_stashed_save_path != "":
		RunConfig.save_path = _suite_stashed_save_path
	DirAccess.remove_absolute(SUITE_SAVE_PATH)


func _board() -> Board:
	# BOARD.NEW() VERDICT: PINS the shipped board -- the default-board factory this
	# file's many road-shape assertions are pinned against; see _road_corpus() below
	# for the property-swept counterpart.
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
	var produced: Dictionary = {}
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
			produced[mask] = true
			var err: String = _T.assert_true(Board.GRASS_EDGE_TILE.has(mask),
				"cell %s needs edge mask %d, which the Kenney kit has no tile for" % [cell, mask])
			if err != "":
				return err
	var err_sweep: String = _T.assert_gt(checked, 60,
		"the sweep actually visited the grass (empty sweep = vacuous pass)")
	if err_sweep != "":
		return err_sweep
	# The OTHER direction, and the reason it is here: the sweep above fails when the
	# road grows a shape the table cannot draw -- the direction that produces a visible
	# bug, which is why it felt like the whole check. It can never fail on an entry no
	# level can produce: a mask left over from a road that was reshaped, pointing at a
	# tile nobody has looked at since. Nothing said whether the table's nine entries
	# were nine or seven. A derived table asserted in one direction is a second source
	# of truth wearing a checked list's clothes.
	#
	# UNREACHABLE_EDGE_MASKS is where a deliberate exception gets written down instead
	# of being invisible. It is empty, and that is a finding, not a default.
	var extra: Array[int] = []
	for mask: int in Board.GRASS_EDGE_TILE:
		if not produced.has(mask) and not Board.UNREACHABLE_EDGE_MASKS.has(mask):
			extra.append(mask)
	extra.sort()
	return _T.assert_eq(str(extra), "[]",
		"every entry in GRASS_EDGE_TILE is a mask this board actually produces; these "
			+ "are not, and are not declared in UNREACHABLE_EDGE_MASKS either -- either "
			+ "delete them or say there why they are kept")


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
	## stay clean.
	##
	## This used to say "one angle throughout, because a hatch whose angle varies
	## reads as two different marks rather than as one texture." Two angles now
	## ship, and the rationale was half right: varying the angle *freely* would
	## read as noise, but a single mirrored pair reads as one texture with a lean,
	## which is why orientation was the channel chosen for off-aim ground. What
	## this test actually pins is unchanged and still the point — `|span.x| ==
	## |span.y|`, i.e. every stripe is at 45 degrees in one direction or the other,
	## so neither lean can drift into an arbitrary angle.
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
	while i + 1 < segments.size():  # loop-bound-check: ok - bounded by the segment list's own size, not by the code under test.
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
		# Through `health_bar_color_on`, on BOTH ramps: `health_bar_color` reads
		# RunConfig.colorblind_safe, which is process-global and seeded from
		# whatever save the machine running this happens to have.
		for safe: bool in [false, true]:
			err = _T.assert_true(
				Plant.health_bar_color_on(true, safe) != Plant.health_bar_color_on(false, safe),
				"the two colours still differ as well on the %s ramp — the shape is a second channel, not a replacement"
					% ("colourblind-safe" if safe else "default"))
			if err != "":
				break
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


# -- Tree-global groups: who is in one, and why (plant-tower-defense-02k) ----
#
# `test_kernels_launch_from_the_cob_on_an_offset_layer` read
# `get_nodes_in_group("kernels")[0]`, was green for months, and turned red when
# four unrelated tests were appended. The fix that landed was right; the reason
# written beside it is not, and a wrong reason sends the next reader after the
# wrong defect. The three cases below pin what was actually measured.
#
# Measured at HEAD, with a tree-global group census taken after every one of the
# suite's 355 test methods: no group grew across any test boundary, and the final
# census was empty, identical to the baseline. Nothing leaks between tests. The
# stranger that `kernels[0]` returned was fired by the SAME test, during the
# settle frames `_T.instantiate_scene` pumps, because a CornCobbler enters the
# tree already loaded.
#
# Both facts are load-bearing and neither is guaranteed by anything else, so each
# gets a case:
#   1. `_T.free_ui` frees synchronously. If the harness ever goes back to
#      `queue_free`, the cross-test leak the fix's comment describes becomes real
#      and this goes red first.
#   2. Hosting a loaded cob beside a pest populates "kernels" BEFORE the test
#      acts. That is the contamination, and it is intra-test.
#   3. A host that is never freed does stay in the group. The exposure is real;
#      free_ui is the only thing standing between it and every later test.
#
# The static half of this is `tools/group_leak_check.py`, which refuses a
# selection out of a tree-global group that has neither a before/after diff nor
# an exact cardinality assertion.


func _combat_host(nodes: Array[Node]) -> Node2D:
	var container := Node2D.new()
	container.name = "GroupProvenanceHost"
	for node: Node in nodes:
		container.add_child(node)
	return container


## Every group with at least one member in the live tree. There is no SceneTree
## API to enumerate groups, so walking is the only census that cannot miss one
## nobody thought to name.
func _census(tree: SceneTree) -> Dictionary:
	var out: Dictionary = {}
	_census_walk(tree.root, out)
	return out


func _census_walk(node: Node, out: Dictionary) -> void:
	for group: StringName in node.get_groups():
		var key: String = str(group)
		if key.begins_with("_"):
			continue  # engine-internal
		out[key] = int(out.get(key, 0)) + 1
	for child: Node in node.get_children():
		_census_walk(child, out)


func test_free_ui_empties_a_group_without_waiting_for_a_frame() -> String:
	## The whole "nothing leaks between tests" result rests on one fact:
	## `_T.free_ui` calls `free()`, not `queue_free()`. `free()` is immediate;
	## `queue_free()` defers to the end of the frame, and a test that returns
	## before that frame hands its nodes to the next test still in the group.
	## Asserted with NO frame pumped in between, which is the only way to tell
	## the two apart.
	var pest := Pest.new()
	pest.setup(Pest.APHID, PackedVector2Array([Vector2(10, 10), Vector2(610, 10)]))
	var hosted_nodes: Array[Node] = [pest]
	var host: Node2D = _combat_host(hosted_nodes)
	var hosted: Node = await _T.instantiate_scene(host)
	var err: String = _T.assert_true(hosted != null, "the host entered the tree")
	if err != "":
		_T.free_ui(host)
		return err

	var tree: SceneTree = host.get_tree()
	err = _T.assert_true(tree != null, "and the host can see the SceneTree")
	if err != "":
		_T.free_ui(host)
		return err

	err = _T.assert_eq(tree.get_nodes_in_group("pests").size(), 1,
		"the hosted pest registered with the tree-global group")
	if err != "":
		_T.free_ui(host)
		return err

	_T.free_ui(host)
	# Deliberately no `await` here: a deferred free would still show a member.
	err = _T.assert_eq(tree.get_nodes_in_group("pests").size(), 0,
		"free_ui emptied the group synchronously - if this is 1, free_ui now defers "
		+ "and every test can inherit the previous test's nodes")
	if err == "":
		err = _T.assert_eq(_census(tree).size(), 0,
			"and no other group kept a member either")
	return err


func test_hosting_a_loaded_cob_puts_kernels_in_the_group_before_the_test_acts() -> String:
	## The actual mechanism behind the false green. `_T.instantiate_scene` pumps
	## settle frames, and a CornCobbler enters the tree already loaded, so hosting
	## it beside a pest fires a volley before the test has called anything. Any
	## later `get_nodes_in_group("kernels")[0]` therefore reads a kernel this test
	## fired during its own setup - one that has already moved off the launch
	## point - not the kernel the assertion is about.
	##
	## This is why the rule is "prove which node you got", not "stop other tests
	## leaking": no other test is involved.
	var corn := CornCobbler.new()
	corn.level = corn.max_level()
	corn.position = Vector2(160, 160)
	var aphid := Pest.new()
	aphid.setup(Pest.APHID, PackedVector2Array([Vector2(220, 160), Vector2(820, 160)]))
	aphid.position = Vector2(220, 160)
	aphid.set_physics_process(false)
	var hosted_nodes: Array[Node] = [corn, aphid]
	var host: Node2D = _combat_host(hosted_nodes)
	host.position = Vector2(0, 72)

	var hosted: Node = await _T.instantiate_scene(host)
	var err: String = _T.assert_true(hosted != null, "the combat host entered the tree")
	if err != "":
		_T.free_ui(host)
		return err
	var tree: SceneTree = host.get_tree()
	err = _T.assert_true(tree != null, "and can see the SceneTree")
	if err != "":
		_T.free_ui(host)
		return err

	# Wait for the volley rather than assuming instantiate_scene pumped enough
	# frames for it. The claim under test is "hosting alone fires it, with the
	# test calling nothing" - NOT "it fires within however many settle frames the
	# harness happens to run". Asserting the latter made this test itself
	# order-dependent: it passed alone and in the suite for two cycles, then went
	# red when unrelated tests were appended and the timing shifted, which is the
	# same accident it was written to document.
	#
	# Nothing here calls _act. The frames are pumped and the cob does the rest.
	var settled: Array[Node] = tree.get_nodes_in_group("kernels")
	var waited: int = 0
	while settled.is_empty() and waited < 30:
		await tree.physics_frame
		settled = tree.get_nodes_in_group("kernels")
		waited += 1
	err = _T.assert_gt(settled.size(), 0,
		"hosting alone fired a volley within %d physics frames and the test called "
		% waited + "nothing - this is the contamination, and it comes from this "
		+ "test's own setup, not from a previous test")
	if err != "":
		_T.free_ui(host)
		return err

	var stale: Dictionary = {}
	for kernel: Node in settled:
		stale[kernel.get_instance_id()] = true

	var targets: Array[Pest] = [aphid]
	corn._act(1.0, targets)
	var fired: Array[Node] = []
	for kernel: Node in tree.get_nodes_in_group("kernels"):
		if not stale.has(kernel.get_instance_id()):
			fired.append(kernel)
	err = _T.assert_gt(fired.size(), 0, "and the cob fired again when acted on")
	if err == "":
		# The point of the whole exercise: index 0 is a settle-frame kernel, so a
		# test reading it is not reading what it thinks it is.
		var all_kernels: Array[Node] = tree.get_nodes_in_group("kernels")
		err = _T.assert_gt(all_kernels.size(), 0, "the group is readable at all")
		if err == "":
			err = _T.assert_true(stale.has(all_kernels[0].get_instance_id()),
				"kernels[0] is a settle-frame kernel, not the one _act just launched - "
				+ "which is exactly what the old test measured and called a pass")
	_T.free_ui(host)
	return err


func test_a_host_that_is_never_freed_keeps_its_nodes_in_the_group() -> String:
	## The exposure, stated positively: free_ui is the ONLY thing keeping the
	## group clean between tests. A test that aborts on a runtime error before its
	## `_T.free_ui` line - which the runner reports as one failed test, not as a
	## suite-wide contamination - leaves everything it hosted in every group it
	## joined, for every test that follows. Measured over a full run at HEAD this
	## never happens, but it is one uncaught error away.
	var pest := Pest.new()
	pest.setup(Pest.BEETLE, PackedVector2Array([Vector2(30, 30), Vector2(630, 30)]))
	var hosted_nodes: Array[Node] = [pest]
	var host: Node2D = _combat_host(hosted_nodes)
	var hosted: Node = await _T.instantiate_scene(host)
	var err: String = _T.assert_true(hosted != null, "the host entered the tree")
	if err != "":
		_T.free_ui(host)
		return err
	var tree: SceneTree = host.get_tree()
	err = _T.assert_true(tree != null, "and can see the SceneTree")
	if err != "":
		_T.free_ui(host)
		return err

	err = _T.assert_eq(tree.get_nodes_in_group("pests").size(), 1, "one pest hosted")
	if err == "":
		# Frames pass, as they would between two tests that both await. Nothing
		# reclaims the node: there is no automatic teardown behind free_ui.
		await tree.process_frame
		await tree.process_frame
		err = _T.assert_eq(tree.get_nodes_in_group("pests").size(), 1,
			"still in the group two frames later - nothing reclaims a host that was "
			+ "never freed, so the next test would read this pest as its own")
	_T.free_ui(host)
	if err == "":
		err = _T.assert_eq(tree.get_nodes_in_group("pests").size(), 0,
			"and only the explicit free_ui clears it")
	return err


## The premise `tools/settle_read_check.py` is built on, asserted at runtime
## rather than argued from the harness source: a node that acts on entering the
## tree has ALREADY ACTED by the time `_T.instantiate_scene()` returns, and it
## keeps acting afterwards. So a value like this one is never "settled" — there is
## no frame count at which it stops being a different number, which is why the
## checker treats a physics-driven transform as volatile and a Control's size as
## not.
##
## Written the way the checker asks tests to be written: the claim is "a hosted
## mover moves with the test calling nothing", awaited as a BOUNDED CONDITION.
## Asserting "it has moved by the time instantiate_scene returned" would be the
## very defect this documents — it would pass or fail on how many settle frames
## the harness happens to pump, a number no test states.
func test_a_hosted_mover_is_never_settled_so_its_position_cannot_be_read_straight_off() -> String:
	var pest := Pest.new()
	pest.setup(Pest.APHID, PackedVector2Array([Vector2(100, 100), Vector2(700, 100)]))
	pest.position = Vector2(100, 100)
	# Captured BEFORE hosting, so it is not itself a settle-dependent read.
	var launched_at: Vector2 = pest.position
	var hosted_nodes: Array[Node] = [pest]
	var host: Node2D = _combat_host(hosted_nodes)

	var hosted: Node = await _T.instantiate_scene(host)
	var err: String = _T.assert_true(hosted != null, "the combat host entered the tree")
	if err != "":
		_T.free_ui(host)
		return err
	var tree: SceneTree = host.get_tree()
	err = _T.assert_true(tree != null, "and can see the SceneTree")
	if err != "":
		_T.free_ui(host)
		return err
	err = _T.assert_true(is_instance_valid(pest),
		"the pest survived hosting — a freed one aborts this method into a silent pass")
	if err != "":
		_T.free_ui(host)
		return err

	var waited: int = 0
	while is_instance_valid(pest) and pest.position == launched_at and waited < 120:
		await tree.physics_frame
		waited += 1
	err = _T.assert_true(is_instance_valid(pest), "the pest is still alive after %d frames" % waited)
	if err == "":
		err = _T.assert_true(pest.position != launched_at,
			("hosting alone walked the pest off %s within %d physics frames and this test "
				+ "called nothing. There is therefore no number of settle frames at which "
				+ "`pest.position` is a settled value, which is what settle_read_check "
				+ "calls a volatile transform") % [launched_at, waited])
	# And it does not stop: a second bounded wait finds it somewhere else again.
	if err == "":
		var moved_to: Vector2 = pest.position
		var again: int = 0
		while is_instance_valid(pest) and pest.position == moved_to and again < 120:
			await tree.physics_frame
			again += 1
		err = _T.assert_true(is_instance_valid(pest) and pest.position != moved_to,
			("and moved again over the next %d frames — it converges on nothing, so no "
				+ "extra `await tree.process_frame` would have made it safe to read")
				% again)
	_T.free_ui(host)
	return err


## The other half of the same distinction, and the reason settle_read_check does
## NOT flag a Control read. Layout CONVERGES: `UI_SETTLE_FRAMES` exists precisely
## to pump it to a fixed point, and once there, further frames change nothing. A
## checker that treated `panel.size` like `pest.position` produced 106 findings
## over this repo and not one of them was real.
func test_a_hosted_controls_size_settles_and_then_stops_changing() -> String:
	var panel := Control.new()
	panel.name = "SettleProbe"
	panel.custom_minimum_size = Vector2(120.0, 40.0)
	var label := Label.new()
	label.text = "a readout wide enough to force a layout pass"
	panel.add_child(label)

	var hosted: Node = await _T.instantiate_ui(panel)
	var err: String = _T.assert_true(hosted != null, "the panel entered the tree")
	if err != "":
		_T.free_ui(panel)
		return err
	var tree: SceneTree = panel.get_tree()
	err = _T.assert_true(tree != null, "and can see the SceneTree")
	if err != "":
		_T.free_ui(panel)
		return err

	var settled: Vector2 = panel.size
	# Without this the test would pass vacuously on (0, 0) == (0, 0), which is
	# exactly what a Control looks like when it was never laid out at all.
	err = _T.assert_gt(settled.x, 0.0,
		"the panel actually got laid out — a zero size means no layout pass ran and "
		+ "the comparison below would be (0, 0) against (0, 0)")
	if err == "":
		err = _T.assert_gt(settled.y, 0.0, "in both axes")
	if err != "":
		_T.free_ui(panel)
		return err

	var pumped: int = 0
	while pumped < 20:
		await tree.process_frame
		pumped += 1
	err = _T.assert_eq(panel.size, settled,
		("%d further frames changed nothing: %s is a fixed point, not a moving "
			+ "target. This is why a Control read straight after instantiate_ui is "
			+ "the harness's contract rather than a defect") % [pumped, settled])
	_T.free_ui(panel)
	return err


## A cell position handed to `to_local()` must be GLOBAL, and `cell_to_world` is not.
##
## Reported from a screenshot: the yellow sole-cover rings were floating on the grass
## instead of sitting on the road cells they mark. `Entities` sits at `y = Hud.BAR_HEIGHT`
## and `Board` sits at (0, 0) inside it, so `cell_to_world` — which is board-local despite
## the name — is correct for every caller that assigns a sibling's `position`, and **72 px
## wrong for the two that passed it to `Node2D.to_local()`**. That is more than a full 64 px
## row, so every mark landed on the wrong cell.
##
## Nothing caught it because every existing test asserts the POINTS and none asserts where
## they land. This pins the distinction itself: if `cell_to_global` ever becomes an alias
## for `cell_to_world`, the offset assertion below fails.
func test_a_cell_position_for_to_local_is_global_and_board_local_is_not() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	# Mounted the way Game mounts it: a Board at (0, 0) inside a parent pushed down by the
	# HUD bar. The bug only exists because that offset exists.
	var entities := Node2D.new()
	entities.position = Vector2(0.0, Hud.BAR_HEIGHT)
	tree.root.add_child(entities)
	# BOARD.NEW() VERDICT: PINS the shipped board (non-road) -- this exercises
	# cell_to_world/cell_to_global's coordinate arithmetic, which does not read the
	# road at all, so a corpus sweep would not exercise anything new.
	var board := Board.new()
	entities.add_child(board)

	var cell := Vector2i(2, 4)
	var local: Vector2 = board.cell_to_world(cell)
	var global: Vector2 = board.cell_to_global(cell)
	var err: String = _T.assert_eq(local, Vector2(160.0, 288.0),
		"board-local is the plain cell centre")
	if err == "":
		err = _T.assert_eq(global - local, Vector2(0.0, Hud.BAR_HEIGHT),
			("global is that plus the bar the board sits under -- if these are equal, the "
				+ "two functions have collapsed into one and the cues go back on the grass"))
	if err == "":
		# The round trip a `_draw` actually performs. A node parented into the same space
		# must recover the board-local point from the global one.
		err = _T.assert_eq(board.to_local(global), local,
			"and to_local() on the global form lands back on the cell centre")
	if err == "":
		err = _T.assert_eq(board.world_to_cell(board.to_local(global)), cell,
			"which is still the cell we asked about")
	entities.free()
	return err


# =============================================================================
# THE ROAD CORPUS (plant-tower-defense-s1o8.1, extended by plant-tower-defense-s1o8.2)
#
# Board.PATH_CORNERS was a const and every number measured against it was a
# literal recorded in a test. `Board.set_road()` makes the road a parameter; this
# corpus is what stops the tests from going on describing one specific snake.
#
# s1o8.1 shipped THREE roads:
#   * the DEFAULT, so every derivation is checked against the shape the whole
#     game was tuned on and a change to the walker shows up here first;
#   * a SHORT straight run, which is the smallest road the walker can be handed
#     and is what makes a density claim about the pest ceiling say something --
#     40 pests over 14 cells is a different game from 40 over 32;
#   * a LONG serpentine, more cells than the default, so the derivations are
#     exercised in both directions rather than only downward.
#
# s1o8.2 ADDS THREE MORE, chosen against the axes the bead names rather than to
# be pretty -- length, corner count, dead ground per plant kind, minimum garden
# size (a greedy cover), and whether -Y (climbing) shows up anywhere besides the
# default's single deliberate climb:
#   * DOUBLE CLIMB, which travels up-down-up across the full board height and
#     never travels LEFT -- a second, independent exerciser of the up-screen
#     Pest facing branch this whole file's header warns went unreached for one
#     hundred cycles, so the corpus does not depend on the default alone to
#     keep it live;
#   * TIGHT COIL, a dense four-tooth switchback -- the highest corner count in
#     the corpus and a road that revisits neither U nor L against DOUBLE_CLIMB's
#     shape, exercised at a different density;
#   * LOWER BAND, confined to rows 4-7 rather than spread over the whole board,
#     so the dead-ground DISTRIBUTION (not just the count) differs -- the top
#     three rows are untouched, which the other five roads never leave alone.
#
# python tools/board_check.py validates every road below (see that file for what
# it checks and why) -- run it after touching any road in this corpus. It is
# also how LONG's shape was caught and fixed: the ORIGINAL s1o8.1 serpentine
# spaced its five full-width rows two apart, which leaves a ONE-row grass band
# between adjacent road rows -- exactly the "road that doubles back beside
# itself" case Board.GRASS_EDGE_TILE's own header warns falls back to plain
# grass with nothing erroring. `board_check.py` catches it (missing masks 5, 7,
# 13); the corners below are respaced to three rows apart, which leaves a
# TWO-row band and produces only masks GRASS_EDGE_TILE actually ships.
#
# Hand-written rather than derived, and that is the right call here: this is a
# corpus of INPUTS, and `derive-the-list` is about not hand-typing the answers.
# The answers -- cell counts, lengths, densities -- are all computed below.
# =============================================================================

const ROAD_DEFAULT: Array[Vector2i] = []   # empty = Board.PATH_CORNERS

const ROAD_SHORT: Array[Vector2i] = [
	Vector2i(0, 4),
	Vector2i(13, 4),
]

## Three full-width rows, three apart (was two -- see the block header above for
## the render bug that spacing shipped and how board_check.py caught it).
const ROAD_LONG: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(13, 0),
	Vector2i(13, 3),
	Vector2i(0, 3),
	Vector2i(0, 6),
	Vector2i(13, 6),
]

## Bottom-left to top-right, three climbs (U), never L. Every vertical leg is at
## least three columns from its neighbour, which is what keeps the grass between
## them two cells wide instead of one -- see ROAD_LONG's header for why that
## margin is load-bearing rather than cosmetic.
const ROAD_DOUBLE_CLIMB: Array[Vector2i] = [
	Vector2i(0, 7),
	Vector2i(4, 7),
	Vector2i(4, 2),
	Vector2i(8, 2),
	Vector2i(8, 7),
	Vector2i(11, 7),
	Vector2i(11, 1),
	Vector2i(13, 1),
]

## Four teeth, each vertical leg three columns from the next -- the densest
## corner count in the corpus (8 turns over 35 cells).
const ROAD_TIGHT_COIL: Array[Vector2i] = [
	Vector2i(0, 4),
	Vector2i(2, 4),
	Vector2i(2, 1),
	Vector2i(5, 1),
	Vector2i(5, 7),
	Vector2i(8, 7),
	Vector2i(8, 1),
	Vector2i(11, 1),
	Vector2i(11, 7),
	Vector2i(13, 7),
]

## Confined to rows 4-7 -- the top three rows of the board are untouched, which
## none of the other five roads leave alone. Every dip is at least three columns
## from the next, and stops one row short of the board's own bottom edge so the
## ground under a dip is never sealed against it into a pocket.
const ROAD_LOWER_BAND: Array[Vector2i] = [
	Vector2i(0, 7),
	Vector2i(3, 7),
	Vector2i(3, 4),
	Vector2i(6, 4),
	Vector2i(6, 7),
	Vector2i(9, 7),
	Vector2i(9, 4),
	Vector2i(12, 4),
	Vector2i(12, 7),
	Vector2i(13, 7),
]


## Every road the corpus holds, resolved -- the default expanded to its real corners so a
## caller never has to know that empty means default. `tools/board_check.py` parses this
## function directly (the string/constant pairs, not a copy of them), so a road added here
## is validated automatically and a road named here under a typo'd constant is a parse
## failure in that tool rather than a silent gap.
func _road_corpus() -> Array:
	return [
		{"name": "default", "corners": Board.PATH_CORNERS},
		{"name": "short straight", "corners": ROAD_SHORT},
		{"name": "long serpentine", "corners": ROAD_LONG},
		{"name": "double climb", "corners": ROAD_DOUBLE_CLIMB},
		{"name": "tight coil", "corners": ROAD_TIGHT_COIL},
		{"name": "lower band", "corners": ROAD_LOWER_BAND},
	]


## Number of direction changes among a road's own segments -- a switchback's corner
## count, computed from the corners rather than hand-counted, so a road edited later
## cannot drift out of sync with a number recorded beside it.
func _turn_count(corners: Array[Vector2i]) -> int:
	var dirs: Array[Vector2i] = []
	for i: int in range(corners.size() - 1):
		dirs.append(Vector2i(
			signi(corners[i + 1].x - corners[i].x), signi(corners[i + 1].y - corners[i].y)))
	var turns: int = 0
	for i: int in range(1, dirs.size()):
		if dirs[i] != dirs[i - 1]:
			turns += 1
	return turns


## Every distinct unit direction a road's segments travel in, as Vector2i (Board's own
## UP/RIGHT/DOWN/LEFT are exactly these four vectors).
func _directions_travelled(corners: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in range(corners.size() - 1):
		var d := Vector2i(
			signi(corners[i + 1].x - corners[i].x), signi(corners[i + 1].y - corners[i].y))
		if not out.has(d):
			out.append(d)
	return out


## The MINIMUM number of Corn Cobblers whose combined range reaches every cell of
## `board`'s road, by the textbook greedy set cover: repeatedly plant the buildable cell
## that newly covers the most still-uncovered road, until none is left.
##
## Deliberately independent of test_combat.gd's `_whole_road_garden()` / `_mixed_garden()`
## -- those are RECORDED, taste-based gardens for firepower on the default road specifically
## (see that file's own comment on why a minimal cover was rejected there). This is the
## other question, asked of every road in the corpus: how small CAN a full-coverage garden
## be, which is exactly the number the bead names as "minimum garden size".
func _greedy_garden_size(board: Board, reach_px: float) -> int:
	var uncovered: Dictionary = {}
	for cell: Vector2i in board.road_cells():
		uncovered[cell] = true
	var placed: int = 0
	while not uncovered.is_empty():  # loop-bound-check: ok - breaks below on best_gain == 0, and every other pass erases at least one cell from `uncovered`.
		var best_gain: int = 0
		var best_cell := Vector2i(-1, -1)
		for y: int in range(Board.ROWS):
			for x: int in range(Board.COLS):
				var at := Vector2i(x, y)
				if not board.is_buildable(at):
					continue
				var gain: int = 0
				for road_cell: Vector2i in PlacementPreview.covered_road_cell_list(
						board, at, reach_px):
					if uncovered.has(road_cell):
						gain += 1
				if gain > best_gain:
					best_gain = gain
					best_cell = at
		if best_gain == 0:
			# Nothing buildable buys any more coverage -- a playability gap, which
			# test_no_road_in_the_corpus_leaves_a_reaching_plant_with_nothing_to_do
			# already asserts never happens across this corpus. Stop rather than loop.
			break
		placed += 1
		for road_cell: Vector2i in PlacementPreview.covered_road_cell_list(
				board, best_cell, reach_px):
			uncovered.erase(road_cell)
	return placed


## THE SPREAD ITSELF, ASSERTED (plant-tower-defense-s1o8.2).
##
## "A variety of different layouts" is the bead's own phrase and it cannot be accepted as
## prose -- this is the one place that checks the corpus actually VARIES, as opposed to
## every road in it merely being individually valid (which the five tests above check) or
## individually correct about dead ground (which
## test_dead_ground_is_exactly_the_cells_no_road_cell_reaches checks). Every property here
## is swept once over the same _road_corpus() every other corpus test uses, and every
## assertion is about the SPREAD -- max minus min, or a union of directions -- never a
## literal for any one road; the individual numbers are pinned where they already are.
##
## THE MARGINS are round numbers well inside what the corpus in fact measures (cells
## 14..46, turns 0..8, greedy gardens 3..8), not the tightest bound that would pass today
## -- a corpus that shrinks its spread a little is still a corpus with real variety, and a
## test pinned to today's exact numbers would fail on the first road anyone reshapes for an
## unrelated reason.
func test_the_road_corpus_actually_spans_the_axes_it_claims_to() -> String:
	var corn_reach: float = PlantCatalog.reach(PlantCatalog.CORN)
	var chomp_reach: float = PlantCatalog.reach(PlantCatalog.CHOMP)
	var cell_counts: Array[int] = []
	var turn_counts: Array[int] = []
	var garden_sizes: Array[int] = []
	var corn_dead: Array[int] = []
	var chomp_dead: Array[int] = []
	var directions_seen: Dictionary = {}
	var err: String = ""
	var checked: int = 0
	for road: Dictionary in _road_corpus():
		if err != "":
			break
		var name: String = str(road["name"])
		var road_corners: Array[Vector2i] = road["corners"]
		var board := Board.new()
		if name != "default":
			err = _T.assert_eq(board.set_road(road_corners), "",
				"the %s road is accepted by set_road" % name)
			if err != "":
				board.free()
				break
		await _T.instantiate_scene(board)
		err = _T.assert_gt(board.path_cell_count(), 0,
			"the %s road built its path before anything was measured" % name)
		if err == "":
			checked += 1
			cell_counts.append(board.path_cell_count())
			turn_counts.append(_turn_count(road_corners))
			garden_sizes.append(_greedy_garden_size(board, corn_reach))
			corn_dead.append(PlacementPreview.dead_ground_cells(board, corn_reach).size())
			chomp_dead.append(PlacementPreview.dead_ground_cells(board, chomp_reach).size())
			for d: Vector2i in _directions_travelled(road_corners):
				directions_seen[d] = true
		_T.free_ui(board)

	if err == "":
		err = _T.assert_eq(checked, _road_corpus().size(),
			"every corpus road was swept for spread (%d of %d)" % [checked, _road_corpus().size()])

	# Length in cells: a short, dense road plays differently from a long, thin one --
	# this is what WaveDirector.SIMULTANEOUS_PEST_CEILING is reasoned against (see the
	# density test above).
	if err == "":
		err = _T.assert_gte(cell_counts.max() - cell_counts.min(), 20,
			("road length spans at least 20 cells across the corpus (%d..%d, spread %d) "
				+ "-- a corpus this narrow would not exercise short-and-dense against "
				+ "long-and-thin") % [cell_counts.min(), cell_counts.max(),
					cell_counts.max() - cell_counts.min()])

	# Corner count: a straight run vs a switchback.
	if err == "":
		err = _T.assert_gte(turn_counts.max() - turn_counts.min(), 5,
			("corner count spans at least 5 turns across the corpus (%d..%d, spread %d)")
				% [turn_counts.min(), turn_counts.max(), turn_counts.max() - turn_counts.min()])

	# Dead ground per plant kind: the number that teaches a player "this corner is
	# useless" -- kanban.md flags exactly this as a lesson a player wrongly carries
	# from one board to the next if it never varies.
	if err == "":
		err = _T.assert_gte(corn_dead.max() - corn_dead.min(), 10,
			("dead ground for a Corn Cobbler spans at least 10 cells across the corpus "
				+ "(%d..%d)") % [corn_dead.min(), corn_dead.max()])
	if err == "":
		err = _T.assert_gte(chomp_dead.max() - chomp_dead.min(), 10,
			("and dead ground for a Chomp Flower spans at least 10 cells (%d..%d)")
				% [chomp_dead.min(), chomp_dead.max()])

	# Minimum garden size: test_combat.gd's own greedy derivation finds five cobs cover
	# the default road (a different tie-break from this sweep's row-major one, both
	# legitimate greedy covers over the same road; see _greedy_garden_size's header). A
	# road where that number is meaningfully larger or smaller plays differently, per
	# the bead -- this asserts the corpus actually produces that spread.
	if err == "":
		err = _T.assert_gte(garden_sizes.max() - garden_sizes.min(), 3,
			("the minimum full-coverage garden spans at least 3 cobs across the corpus "
				+ "(%d..%d)") % [garden_sizes.min(), garden_sizes.max()])

	# Direction coverage: all four cardinal directions, INCLUDING -Y (climbing), appear
	# somewhere in the corpus -- Pest._update_facing()'s up-screen branch had run in no
	# real frame before the default road's single deliberate climb (board.gd's own
	# header). s1o8.2 adds two more climbing roads so that branch does not depend on the
	# default alone to stay reached.
	if err == "":
		err = _T.assert_eq(directions_seen.size(), 4,
			("all four travel directions appear somewhere in the corpus (%d distinct "
				+ "found: %s)") % [directions_seen.size(), str(directions_seen.keys())])
	if err == "":
		err = _T.assert_true(directions_seen.has(Vector2i.UP),
			"and -Y (climbing) is one of them, on more than just the default road")
	return err


## The road is a parameter now, and its length and cell count are DERIVED from it
## (plant-tower-defense-s1o8.1).
##
## This replaces a test that pinned 32 cells and 2112 px as literals. Those numbers were
## correct and they were also the whole problem: they describe one snake, and cycle 53's
## note above records that the same test "passes in silence" through a reshape that moves
## every shape-dependent number in the game.
##
## WHAT MAKES THIS A CHECK RATHER THAN A RESTATEMENT: the expected values come from
## `Board.road_cell_count` / `road_length_px`, which compute from the CORNERS by
## arithmetic -- one cell per step plus the cell you start on -- while the actual values
## come from `_build_path()`, which WALKS the corners a cell at a time and from
## `_build_route()`, which measures the points it produced. Two independent routes to the
## same number. A walker that skipped a cell, stepped twice, or mis-signed an axis makes
## them disagree; a test that recomputed the answer the same way the code does would not.
##
## The default road still produces exactly 32 and 2112.0, asserted by name below, because
## "the road is a parameter now" must not mean "the game changed".
func test_every_road_in_the_corpus_walks_the_length_its_corners_imply() -> String:
	var err: String = ""
	var checked: int = 0
	# BOARD.NEW() VERDICT: PROPERTY -- already swept over _road_corpus() below.
	for road: Dictionary in _road_corpus():
		var name: String = str(road["name"])
		var corners: Array[Vector2i] = road["corners"]
		var board := Board.new()
		if name != "default":
			err = _T.assert_eq(board.set_road(corners), "",
				"the %s road is accepted by set_road" % name)
			if err != "":
				board.free()
				return err
		await _T.instantiate_scene(board)

		var route: PackedVector2Array = board.route()
		# Vacuity guard: an unbuilt board hands back an empty route and every assertion
		# below would measure nothing while passing.
		err = _T.assert_gt(route.size(), 2, "the %s road built a route" % name)
		if err != "":
			_T.free_ui(board)
			return err
		var cells: int = route.size() - 2
		var length: float = 0.0
		for i: int in range(route.size() - 1):
			length += route[i].distance_to(route[i + 1])

		checked += 1
		err = _T.assert_eq(cells, Board.road_cell_count(corners),
			("the %s road walks the cell count its corners imply -- the walker and the "
				+ "arithmetic disagree, which means one of them is wrong") % name)
		if err == "":
			err = _T.assert_float_eq(length, Board.road_length_px(corners), 0.01,
				"the %s road measures the length its cell count implies" % name)
		if err == "":
			err = _T.assert_eq(board.road_cells().size(), cells,
				"and road_cells() agrees with route() about how many there are (%s)" % name)
		_T.free_ui(board)
		if err != "":
			return err
	if err == "":
		err = _T.assert_eq(checked, _road_corpus().size(),
			"every corpus road was walked (%d of %d)" % [checked, _road_corpus().size()])
	if err == "":
		# The default road, by name and by literal, because every constant in the game was
		# tuned against exactly these two numbers and "the road is a parameter now" must
		# not quietly mean "the road changed".
		err = _T.assert_eq(Board.road_cell_count(Board.PATH_CORNERS), 32,
			"the default road is still 32 cells")
	if err == "":
		err = _T.assert_float_eq(Board.road_length_px(Board.PATH_CORNERS), 2112.0, 0.01,
			"and still 2112 px of walking")
	return err


## DEAD GROUND AS A PROPERTY, RATHER THAN AS 11 AND 36
## (plant-tower-defense-s1o8.1).
##
## The suite recorded "11 stranded cells for a Corn Cobbler and 36 for a Chomp, of 94",
## and those numbers were correct and were the whole problem: they describe ONE snake.
## Cycle 53 reshaped the road at an identical length and cell count and moved the two in
## OPPOSITE directions, so they cannot be predicted from the invariant the length/count
## test pins — which is exactly why the bead asks for a property a bad road violates
## instead of a second literal recorded beside the first.
##
## THE PROPERTY: a buildable cell is dead ground for reach R exactly when no road cell's
## centre lies within R of it. Derived here from the road cells directly, and deliberately
## NOT by calling `covered_road_cells` — that is the function under test, and an
## "independent" derivation that calls it asserts only that it is deterministic. Two
## nested sweeps and a distance, which is the definition rather than the implementation.
##
## Both directions, because each catches a different mistake: a cell reported dead that is
## in range means the cue darkens ground the player can use, and a cell in range of
## nothing that is NOT reported means the cue stays silent about a bed that can never
## fire. The second is the one this project shipped a bug for.
##
## THE DEFAULT'S 11 AND 36 ARE STILL PINNED at the bottom. Deriving the rule does not
## make the numbers uninteresting — the game was tuned on that board, and a change to the
## walker that keeps the property while moving the count is a real change to the game.
func test_dead_ground_is_exactly_the_cells_no_road_cell_reaches() -> String:
	var err: String = ""
	var reaches: Array[Dictionary] = [
		{"who": "Corn Cobbler", "px": PlantCatalog.reach(PlantCatalog.CORN)},
		{"who": "Chomp Flower", "px": PlantCatalog.reach(PlantCatalog.CHOMP)},
	]
	var checked: int = 0
	var default_counts: Dictionary = {}
	# BOARD.NEW() VERDICT: PROPERTY -- already swept over _road_corpus() below.
	for road: Dictionary in _road_corpus():
		if err != "":
			break
		var name: String = str(road["name"])
		var corners: Array[Vector2i] = road["corners"]
		var board := Board.new()
		if name != "default":
			err = _T.assert_eq(board.set_road(corners), "",
				"the %s road is accepted by set_road" % name)
			if err != "":
				board.free()
				return err
		await _T.instantiate_scene(board)

		# Vacuity guard, and the important one here: `dead_ground_cells` returns an EMPTY
		# array for a board whose path has not been built, which would make every
		# assertion below compare two empty sets and pass.
		err = _T.assert_gt(board.path_cell_count(), 0,
			"the %s road built its path before anything was measured" % name)
		var road_centres: Array[Vector2] = []
		if err == "":
			for y: int in range(Board.ROWS):
				for x: int in range(Board.COLS):
					if board.is_path(Vector2i(x, y)):
						road_centres.append(board.cell_to_world(Vector2i(x, y)))
		for reach: Dictionary in reaches:
			if err != "":
				break
			var px: float = float(reach["px"])
			var who: String = str(reach["who"])
			var reported: Array[Vector2i] = PlacementPreview.dead_ground_cells(board, px)
			var derived: Array[Vector2i] = []
			for y: int in range(Board.ROWS):
				for x: int in range(Board.COLS):
					var cell := Vector2i(x, y)
					if not board.is_buildable(cell):
						continue
					var here: Vector2 = board.cell_to_world(cell)
					var nearest: float = -1.0
					for centre: Vector2 in road_centres:
						var d: float = here.distance_to(centre)
						if nearest < 0.0 or d < nearest:
							nearest = d
					if nearest > px:
						derived.append(cell)
			checked += 1
			# Reported-but-reachable: the cue darkens a bed the player can use.
			for cell: Vector2i in reported:
				if err != "":
					break
				err = _T.assert_true(derived.has(cell),
					("%s on the %s road: %s is called dead ground, but a road cell lies "
						+ "within %.1f px of it") % [who, name, cell, px])
			# Reachable-by-nothing but not reported: the cue stays silent about a bed
			# that can never fire, which is the direction this project has shipped.
			for cell: Vector2i in derived:
				if err != "":
					break
				err = _T.assert_true(reported.has(cell),
					("%s on the %s road: no road cell is within %.1f px of %s, and the "
						+ "cue does not call it dead ground") % [who, name, px, cell])
			if err == "" and name == "default":
				default_counts[who] = reported.size()
		_T.free_ui(board)

	# Six sweeps, three roads by two reaches. A corpus that quietly shrank would make
	# every assertion above vacuous while the test went on passing.
	if err == "":
		err = _T.assert_eq(checked, _road_corpus().size() * reaches.size(),
			("every road in the corpus was swept at every reach (%d of %d)")
				% [checked, _road_corpus().size() * reaches.size()])
	# The default board's own numbers, still pinned. The property holding says the RULE
	# is right; these say the board the game was tuned on has not moved under it.
	if err == "":
		err = _T.assert_eq(int(default_counts.get("Corn Cobbler", -1)), 11,
			"the default road still strands 11 cells for a Corn Cobbler")
	if err == "":
		err = _T.assert_eq(int(default_counts.get("Chomp Flower", -1)), 36,
			"and 36 for a Chomp Flower")
	return err


## THE SUNDEW'S COVERAGE ARITHMETIC, SAID ABOUT ANY ROAD RATHER THAN ABOUT THIS ONE
## (plant-tower-defense-s1o8.1).
##
## The last of the three entries under cycle 53's "PROPERTY OF *THIS* ROAD" heading
## (`test/unit/test_selftest.gd`): "the Sundew's coverage arithmetic: stated against how
## much road a single placement reaches on this route". The live test that guards it picks
## `Vector2i(4, 0)` by hand, because on THIS road that cell is grass and lies over road a
## cob cannot reach. Neither of those is true of an arbitrary road, and nothing said so.
##
## THE TWO CLAIMS, separated because they fail differently:
##
## 1. On every road, SOMEWHERE is worth putting a patch. If the best cell on some road
##    covers no road at all, a Sundew is unplayable on that board and the corpus has to
##    know before a player does. This is the property.
## 2. The best cell's coverage is NOT the same number across the corpus. That is what
##    makes it arithmetic about a route rather than a constant nobody noticed was one —
##    and it is the assertion that fails if a future refactor starts answering from
##    SAP_RADIUS alone.
##
## Uses only `Board` and `PlacementPreview` statics: no `Game`, no unlock, no thirty
## seeds. The live test keeps guarding the default board's specific cell, which is the
## regression this cannot replace.
func test_a_sundews_best_patch_is_worth_laying_on_every_road_and_not_the_same_size() -> String:
	var err: String = ""
	var best_by_road: Dictionary = {}
	# BOARD.NEW() VERDICT: PROPERTY -- already swept over _road_corpus() below.
	for road: Dictionary in _road_corpus():
		if err != "":
			break
		var name: String = str(road["name"])
		var corners: Array[Vector2i] = road["corners"]
		var board := Board.new()
		if name != "default":
			err = _T.assert_eq(board.set_road(corners), "",
				"the %s road is accepted by set_road" % name)
			if err != "":
				board.free()
				return err
		await _T.instantiate_scene(board)
		err = _T.assert_gt(board.path_cell_count(), 0,
			"the %s road built its path before anything was measured" % name)
		var best: int = 0
		var best_cell := Vector2i(-1, -1)
		if err == "":
			for y: int in range(Board.ROWS):
				for x: int in range(Board.COLS):
					var cell := Vector2i(x, y)
					if not board.is_buildable(cell):
						continue
					var covers: int = PlacementPreview.covered_road_cells(
						board, cell, StickySundew.SAP_RADIUS)
					if covers > best:
						best = covers
						best_cell = cell
		if err == "":
			# Claim 1. A road where the answer is zero is a road no Sundew can be played
			# on, and the corpus is where that has to surface.
			err = _T.assert_gt(best, 0,
				("the %s road has somewhere worth laying a patch -- the best buildable "
					+ "cell covers %d road cells, so a Sundew is unplayable here")
					% [name, best])
		if err == "":
			best_by_road[name] = best
			err = _T.assert_true(board.is_buildable(best_cell),
				"and the cell that scored best (%s) really is grass" % best_cell)
		_T.free_ui(board)

	if err == "":
		err = _T.assert_eq(best_by_road.size(), _road_corpus().size(),
			("every road in the corpus was measured (%d of %d) -- a corpus that shrank "
				+ "would leave the spread claim below comparing one number to itself")
				% [best_by_road.size(), _road_corpus().size()])
	if err == "":
		# Claim 2. The spread is the point: equal numbers across three genuinely
		# different roads would mean the answer had stopped depending on the route.
		var values: Array = best_by_road.values()
		var lowest: int = int(values[0])
		var highest: int = int(values[0])
		for v: Variant in values:
			lowest = mini(lowest, int(v))
			highest = maxi(highest, int(v))
		err = _T.assert_gt(highest, lowest,
			("how much road one patch buys varies across the corpus (%d..%d over %s) -- "
				+ "one number for every road would mean this is answered from SAP_RADIUS "
				+ "and not from the route") % [lowest, highest, str(best_by_road)])
	return err


## PlantCatalog.reaches_over_road() is the exception list playability_gaps()
## reads (plant-tower-defense-zg6l): true for a real reach measured against the
## road, false for no reach at all, and false for a reach measured against
## PLANTS instead. Asserted directly, once each, rather than left to be implied
## by the corpus test below only ever calling it through playability_gaps().
func test_reaches_over_road_matches_what_each_plants_reach_actually_measures() -> String:
	var err: String = _T.assert_true(PlantCatalog.reaches_over_road(PlantCatalog.CORN),
		"Corn Cobbler has a real reach over the road")
	if err == "":
		err = _T.assert_true(PlantCatalog.reaches_over_road(PlantCatalog.SUNDEW),
			"and so does the Sundew's SAP_RADIUS")
	if err == "":
		err = _T.assert_true(not PlantCatalog.reaches_over_road(PlantCatalog.MINT),
			"but Mint's reach is over plants, not the road, so it is excluded")
	if err == "":
		err = _T.assert_true(not PlantCatalog.reaches_over_road(PlantCatalog.ALOE),
			"and so is Aloe's, for the same reason")
	if err == "":
		err = _T.assert_true(not PlantCatalog.reaches_over_road(PlantCatalog.BRAMBLE),
			"a Bramble's reach() is 0.0 -- no radius, not a road reach")
	if err == "":
		err = _T.assert_true(not PlantCatalog.reaches_over_road(PlantCatalog.SUNFLOWER),
			"and a Sunflower's is 0.0 for the same reason")
	return err


## THE PLAYABILITY PREDICATE, GENERALISED ACROSS EVERY REACHING PLANT
## (plant-tower-defense-zg6l).
##
## The Sundew test just above is cycle 170's worked example for one plant on one
## kind of reach. Board.playability_gaps() asks the same question -- "is there
## anywhere on this board worth putting this plant" -- of every catalogue entry
## PlantCatalog.reaches_over_road() says should be asked, and this asserts it
## over the same corpus.
##
## Two claims, matching the shape of the test above:
##
## 1. Nothing in the corpus HAS a gap today. Not guaranteed by construction -- a
##    road reshaped to hug a corner of the board could strand a short-reach
##    plant the way it already strands dead-ground cells for a Corn Cobbler --
##    so this is a real assertion over the actual corpus roads, not a
##    restatement of the predicate's own logic.
## 2. Bramble and Sunflower (reach 0.0, "no radius") and Mint and Aloe (reach
##    over PLANTS, not the road) are never in the answer, on any road, because
##    they are never asked: PlantCatalog.reaches_over_road() excludes all four
##    before playability_gaps() ever measures a distance.
func test_no_road_in_the_corpus_leaves_a_reaching_plant_with_nothing_to_do() -> String:
	var err: String = ""
	var checked: int = 0
	var never_asked: Array[StringName] = [
		PlantCatalog.BRAMBLE, PlantCatalog.SUNFLOWER, PlantCatalog.MINT, PlantCatalog.ALOE,
	]
	# BOARD.NEW() VERDICT: PROPERTY -- already swept over _road_corpus() below.
	for road: Dictionary in _road_corpus():
		if err != "":
			break
		var name: String = str(road["name"])
		var corners: Array[Vector2i] = road["corners"]
		var board := Board.new()
		if name != "default":
			err = _T.assert_eq(board.set_road(corners), "",
				"the %s road is accepted by set_road" % name)
			if err != "":
				board.free()
				return err
		await _T.instantiate_scene(board)
		err = _T.assert_gt(board.path_cell_count(), 0,
			"the %s road built its path before anything was measured" % name)
		if err == "":
			var gaps: Array[StringName] = board.playability_gaps()
			checked += 1
			# Claim 1. A road that strands a plant with nowhere to reach the road
			# is a road the corpus gate has to know about before a player does.
			err = _T.assert_eq(gaps.size(), 0,
				("the %s road leaves every reaching plant something to do -- "
					+ "playability_gaps() reports %s stranded") % [name, str(gaps)])
			# Claim 2. The four plants reach() says should never be asked this
			# question are never in the answer, on any road.
			for id: StringName in never_asked:
				if err != "":
					break
				err = _T.assert_true(not gaps.has(id),
					"%s is never asked the road question, on any road"
						% PlantCatalog.display_name(id))
		_T.free_ui(board)

	if err == "":
		err = _T.assert_eq(checked, _road_corpus().size(),
			("every road in the corpus was measured for a playability gap (%d of %d)")
				% [checked, _road_corpus().size()])
	return err


## set_road refuses the road that would HANG, and three that would merely be wrong
## (plant-tower-defense-s1o8.1).
##
## The diagonal case is the one this test exists for and it is not a tidiness check.
## `_build_path()` walks each segment with `while at != to`, stepping `signi` on each
## axis, so a segment from (0,0) to (3,4) steps (1,1) forever and never arrives: the loop
## does not terminate, and it runs in `_ready()`, so the game hangs with no error and
## nothing on screen. A refusal is the only thing between a caller's typo and that.
##
## Asserted by REFUSAL STRING rather than by calling it and seeing what happens, for the
## obvious reason -- a test that hands the walker a diagonal to prove it hangs never
## returns, and would take the whole suite with it.
func test_set_road_refuses_the_roads_that_cannot_be_walked() -> String:
	# BOARD.NEW() VERDICT: PINS the shipped board (non-road) -- set_road()'s own
	# input-validation contract, independent of which road is currently loaded;
	# _road_corpus() holds only legal roads, so it does not apply to a refusal matrix.
	var board := Board.new()
	var err: String = _T.assert_true(board.set_road([
			Vector2i(0, 0), Vector2i(3, 4)]).contains("diagonal"),
		"a diagonal segment is refused by name -- the walker would never arrive")
	if err == "":
		err = _T.assert_true(board.set_road([Vector2i(0, 1)]).length() > 0,
			"one corner is not a road")
	if err == "":
		err = _T.assert_true(board.set_road([
				Vector2i(0, 1), Vector2i(Board.COLS, 1)]).contains("off a"),
			"a corner past the last column is refused")
	if err == "":
		err = _T.assert_true(board.set_road([
				Vector2i(0, 1), Vector2i(0, -1)]).contains("off a"),
			"and one above the first row")
	if err == "":
		err = _T.assert_true(board.set_road([
				Vector2i(2, 2), Vector2i(2, 2)]).length() > 0,
			"a zero-length segment is refused rather than silently skipped")
	if err == "":
		# The other direction, which is what stops all of the above from being satisfied
		# by a set_road that refuses everything.
		err = _T.assert_eq(board.set_road(ROAD_SHORT), "",
			"and a legal road is still accepted")
	if err == "":
		err = _T.assert_eq(board.road_corners(), ROAD_SHORT,
			"and is the road the board then reports as its own")
	board.free()
	return err


## A board already in the tree refuses a new road, and says why
## (plant-tower-defense-s1o8.1).
##
## `_build_tiles()` adds one Sprite2D per cell straight onto the Board with no container
## and no names, so there is nothing to re-tile through: a second run would stack 126 more
## sprites on the old ones and the board would show the previous road's tiles under the
## new road's cells. Refusing is the honest answer and this pins it, because the
## alternative failure is silent and visual.
func test_a_board_in_the_tree_will_not_change_its_road() -> String:
	# BOARD.NEW() VERDICT: PINS the shipped board (non-road) -- exercises the
	# refusal API using ROAD_SHORT/ROAD_LONG directly, not a specific road's shape;
	# no corpus sweep applies since this tests a transition, not a static layout.
	var board := Board.new()
	var err: String = _T.assert_eq(board.set_road(ROAD_SHORT), "",
		"the road is set before the board enters the tree")
	if err == "":
		await _T.instantiate_scene(board)
		err = _T.assert_true(board.set_road(ROAD_LONG).contains("already in the tree"),
			"and refused after, because the tiles are built from the old one")
	if err == "":
		err = _T.assert_eq(board.road_corners(), ROAD_SHORT,
			"the refused call left the board on the road it had")
	if err == "":
		err = _T.assert_eq(board.road_cells().size(),
			Board.road_cell_count(ROAD_SHORT),
			"and its cells are still that road's")
	_T.free_ui(board)
	return err


## SIMULTANEOUS_PEST_CEILING is a hard cap, not a road derivation, and the corpus is what
## says whether a fixed 40 survives a different road (plant-tower-defense-s1o8.1).
##
## READ THE CONSTANT'S OWN ARGUMENT BEFORE CHANGING THIS. 40 is not computed from the
## road. `wave_director.gd`'s header derives the PROBLEM from the road -- sweeping the real
## schedule found 115 pests alive at once "on a 14x9 board with a 32-cell road, i.e. three
## and a half pests per cell of road" -- and then sets 40 by CONSTRUCTION from the wave
## table, the two group shares summing to it exactly so the bound holds without tuning.
## The road decided that a ceiling was needed and what it would MEAN; the table decided
## the number. A test asserting `ceiling == cells * something` would therefore be
## inventing a derivation the code does not have.
##
## What the road genuinely constrains is DENSITY, and that is what this checks: 40 pests
## on the default road is 1.25 per cell, against the 3.5 per cell the header names as the
## quantity problem the ceiling exists to prevent. A shorter road makes the same 40 denser
## without anything in the director noticing, so the corpus is where that shows up.
##
## The bound is 3.5 because that is the number the header already argued as too many. It
## is not a fresh opinion, and if it moves, the header is what has to move first.
func test_the_pest_ceiling_stays_a_playable_density_on_every_road_in_the_corpus() -> String:
	var worst_name: String = ""
	var worst: float = 0.0
	# The road whose density is `worst`, tracked alongside it -- the failure message below
	# names this road's own cell count rather than a fixed corpus index, so a corpus that
	# grows (s1o8.2 added three roads) cannot make the message quote the wrong road's cells.
	var worst_cells: int = 0
	var checked: int = 0
	for road: Dictionary in _road_corpus():
		var cells: int = Board.road_cell_count(road["corners"])
		var err: String = _T.assert_gt(cells, 0,
			"the %s road has cells to spread pests over" % str(road["name"]))
		if err != "":
			return err
		checked += 1
		var density: float = float(WaveDirector.SIMULTANEOUS_PEST_CEILING) / float(cells)
		if density > worst:
			worst = density
			worst_name = str(road["name"])
			worst_cells = cells
	var err: String = _T.assert_eq(checked, _road_corpus().size(),
		"every corpus road was priced (%d of %d)" % [checked, _road_corpus().size()])
	if err == "":
		err = _T.assert_true(worst < 3.5,
			("%s puts %d pests on %d cells = %.2f per cell, at or past the 3.5 per cell "
				+ "wave_director.gd's own header calls the quantity problem this ceiling "
				+ "exists to prevent. Either that road leaves the corpus or the ceiling "
				+ "becomes road-derived -- do not raise this bound without moving the "
				+ "header's argument first.")
				% [worst_name, WaveDirector.SIMULTANEOUS_PEST_CEILING, worst_cells, worst])
	if err == "":
		# The default road, by name: 40 over 32 cells. Pinned so that a change to the
		# ceiling or to the default road has to come past this sentence.
		var default_density: float = (float(WaveDirector.SIMULTANEOUS_PEST_CEILING)
			/ float(Board.road_cell_count(Board.PATH_CORNERS)))
		err = _T.assert_float_eq(default_density, 1.25, 0.001,
			"the default road carries 1.25 pests per cell at the ceiling (%.3f)"
				% default_density)
	return err
