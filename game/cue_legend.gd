class_name CueLegend
extends Control

## The page that teaches the board's drawn vocabulary.
##
## `game/OVERLAY_GRAMMAR.md` has documented ten shapes and what each one MEANS since
## cycle 67, and it is referenced only from GDScript comments — no script loads it. So for
## ten cycles the game has been speaking a language written down for developers and taught
## to nobody. A player meets a dashed ring, a doubled line width and a row of pips with
## nothing to check them against.
##
## **Every swatch is drawn with the constants the real cue uses**, not with numbers chosen
## to look similar. `SelectionMarker.MARKER_COLOR`, `SelectionMarker.LINE_WIDTH`,
## `SoleCoverMarks.ALONE_DASHES`, `HuskLayer.BRIGHT_RING`, `PlacementPreview.NEW_COVER_DOT`
## — a legend is a second drawing of something the board already draws, which is a second
## source of truth by construction, and sharing the constants is the only part of that
## which can be made structural. What is NOT shared is the drawing code: the cues live on
## six different nodes with six different geometries, and there is no honest way to call
## `CornCobbler._draw()` at 18 px inside a notebook. `test_every_legend_row_uses_its_cue's
## own constants` is what holds the rest.
##
## Five rows, not ten. The ten grammar rows include cues a player meets late or never (the
## weather overlay, the doubled-width armed state, the pip count on a husk worth more than
## nine seeds), and a legend nobody finishes reading teaches less than a short one. These
## five are the vocabulary of the first two waves: place a plant, select it, watch it
## shoot, let a husk rot, hover a second plant.

## Row geometry. Absolute positions inside a Control sized to the notebook's drawing box,
## which is the idiom `NotebookScreen._build_shelf` established — the pane is one Control
## with drawn swatches and Label children beside them, rather than nested containers.
const ROW_TOP: float = 14.0
const ROW_PITCH: float = 46.0
const SWATCH_X: float = 26.0
const SWATCH_RADIUS: float = 15.0
const TEXT_X: float = 56.0
const MEANS_HEIGHT: float = 19.0
const MEANS_FONT_SIZE: int = 15
const DETAIL_FONT_SIZE: int = 12

## The five shapes, in the order a player meets them.
const SHAPE_SUBJECT := "subject"
const SHAPE_REACH := "reach"
const SHAPE_CLOCK := "clock"
const SHAPE_REMARK := "remark"
const SHAPE_GAIN := "gain"
## The sixth, and the one with the highest cost of being misread: it is the only cue in the
## game guarding an action that cannot be undone.
const SHAPE_ARMED := "armed"

# =============================================================================
# BEGIN plant-tower-defense-wenx: does any remaining untaught cue deserve a row?
#
# The answer is NO, and this block is the audit, recorded here so the next person
# asking re-reads it instead of re-deriving it. Nothing below this comment is a
# behaviour change; the page teaches exactly what it taught before.
#
# WHAT COUNTS AS A CUE, stated because the answer depends on it: a mark whose
# PRESENCE, SHAPE or GEOMETRY carries state the player has to read. A sprite
# drawing its own body is not one, however much ink it uses. The test is whether
# removing it changes what the player KNOWS rather than what the game looks like.
#
# TWO TRAPS IN THE DERIVATION, both live in the repo right now, both reported to
# whoever owns OVERLAY_GRAMMAR.md rather than fixed here:
#
#   1. THE GREP IN THAT FILE NO LONGER FINDS THE NEWEST CUES. Its "How this was
#      derived" section says to re-run
#      `grep -n "draw_arc(\|draw_circle(\|draw_line(\|draw_rect(" game/*.gd` and
#      records 55 calls across 15 files. It is 80 across 20 now -- and, worse, it
#      is structurally blind to `Board.mark_dead_ground` and
#      `Board.mark_deferred_road`, which paint Line2D CHILDREN and not a `_draw()`
#      at all. Board's own header says why they had to: "a headless run paints no
#      frame, so a `_draw()` here would be a cue no gate could ever see". So the
#      recipe misses exactly the two cues that were built to be gateable. A census
#      of one API is a census of the asker's assumption.
#   2. THE LANE-PRESSURE HATCH HAS NO GRAMMAR ROW AT ALL. `lane_pressure_overlay.gd`
#      is named in that file's cue-file list and its 45-degree stripe lattice
#      matches none of the ten shapes. That is a hole in the GRAMMAR, not in this
#      page, and it is not a hole this page can close.
#
# THE DIFF, one line per grammar row. "taught" means this file has a row for the
# SHAPE; the instances after it are what actually draws it today.
#
#   1  solid full ring         TAUGHT  reach    aloe/mint/nettle/corn/dandelion rings,
#                                               the bomb's blast preview, the hover ring
#   2  dashed ring             TAUGHT  remark   sole-cover holds-nothing ring, the hover
#                                               at-risk ring, Pest's fought mark
#   3  partial arc             TAUGHT  clock    husk rot, Chomp chew, uproot confirm
#   4  small solid ring        untaught         sole-cover road rings, live and held-over
#   5  filled dot              TAUGHT  gain     new-cover dots
#   6  straight line in a box  untaught         hover dead bar, hover redundant pair,
#                                               BOARD dead-ground bars, BOARD deferred bars
#   7  corner brackets         TAUGHT  subject  live, hover promise, held-over (2 of 4)
#   8  scattered short marks   untaught         drought dashes, rain streaks
#   9  doubled line width      TAUGHT  armed    brackets and sole-cover rings, together
#  10  a row of small pips     untaught         a husk worth more than CompostMeter.FULL_VALUE
#
# WHAT A ROW COSTS, AND HOW MANY ARE LEFT: none. `rows_that_fit()` below answers
# it mechanically and `test_the_legend_page_is_exactly_full` pins it -- the last
# row's text ends at 294 px inside a 300 px matte and a seventh lands at 340. And
# it cannot be bought back by cutting ROW_PITCH: a row's own ink is 50 px tall
# (SWATCH_RADIUS above the centre line, MEANS_HEIGHT + DETAIL_FONT_SIZE + 4 below
# it) and seven rows need a pitch of 39, so they would OVERLAP. The next row costs
# a smaller swatch, smaller type, or a second notebook page. Not a line -- a page.
#
# THE VERDICT, per untaught cue, against that price:
#
#   * BOARD DEAD-GROUND BARS and BOARD DEFERRED-ROAD BARS (row 6) -- the strongest
#     case and still no. They are the only untaught cues that are PERSISTENT: both
#     are repushed from `Game._refresh()` with no hover, the deferred bars from the
#     garden's shape alone, and up to 24 road cells can carry one at once. A player
#     meets them without having asked. But row 6 is the row a single legend line
#     teaches WORST: its four instances mean four different things (this cell
#     refuses the plant / this second patch buys nothing / this ground fires at
#     nothing / this road cell is behind a queue), and the grammar defines the row
#     by its CHANNEL -- "legible with colour discarded" -- rather than by a meaning.
#     A row reading "a straight line: this one is out of the conversation" is true
#     of all four and actionable for none. Teaching it honestly is four rows, which
#     is more than a page. The right home for it is the hints page or a mark-side
#     tooltip, both of which carry a sentence per instance. Filed as that, not as a
#     legend row.
#   * HELD-OVER BRACKETS (row 7, taught row / untaught state) -- no, confidently.
#     The cue only ever exists because the player just selected a second plant, and
#     it appears with the LIVE brackets beside it in the same frame: same shape, one
#     closed and one open, one bright and one dim. Two states of one cue, side by
#     side, at the instant the player produced them, is a better teaching condition
#     than a page read minutes earlier on another screen.
#   * UPROOT CONFIRM ARC (row 3, taught row / untaught instance) -- no. It draws
#     only in the four seconds after arming, next to the doubled red brackets this
#     page already teaches as "armed -- one more click does it". The player has the
#     noun; the arc supplies the tense.
#   * SOLE-COVER ROAD RINGS (row 4) -- the closest call, and still no. They are met
#     earliest of anything here: they appear on the first plant the player ever
#     selects. But this page already teaches the OTHER branch of the same node --
#     the dashed ring, "on a plant nothing depends on" -- so the concept is on the
#     page and the road rings are its positive case. Worth revisiting if row 4 ever
#     gains an instance that is not SoleCoverMarks.
#   * WEATHER MARKS (row 8) -- no. Whole-screen, unmistakable, and announced.
#   * HUSK PIPS (row 10) -- no. Late, rare, and a magnitude on a mark already taught.
#
# END plant-tower-defense-wenx
# =============================================================================

## Id, the line that names the meaning, and the line that says where it is seen.
##
## `means` is the grammar's own wording where the grammar has wording, so the two cannot
## drift into describing different systems. `where` is what the grammar has no column for
## and a player needs most: not what the shape means but when they will see it.
const ROWS: Array[Dictionary] = [
	{
		"shape": SHAPE_SUBJECT,
		"means": "This is the thing being talked about",
		"where": "Corner brackets, on a plant you clicked",
	},
	{
		"shape": SHAPE_REACH,
		"means": "How far it acts",
		"where": "A full ring, while a plant is selected",
	},
	{
		"shape": SHAPE_CLOCK,
		"means": "Time remaining, running out now",
		"where": "A closing arc, on a husk before it rots",
	},
	{
		"shape": SHAPE_REMARK,
		"means": "A remark about what is inside it",
		"where": "A dashed ring, on a plant nothing depends on",
	},
	{
		"shape": SHAPE_GAIN,
		"means": "A cell you would gain",
		"where": "A filled dot, while you hover a new plant",
	},
	{
		"shape": SHAPE_ARMED,
		"means": "Armed — one more click does it",
		"where": "The same mark, drawn twice as thick",
	},
]


static func row_count() -> int:
	return ROWS.size()


## The y a row's swatch centre sits at. Pure, so the fits-the-page test can ask where the
## last row lands without building the pane — the same split `OverlayScreen.rows_that_fit`
## uses.
static func row_center_y(index: int) -> float:
	return ROW_TOP + float(index) * ROW_PITCH + SWATCH_RADIUS


## How far BELOW a row's swatch centre the row's lowest ink sits — the `means` line plus
## the detail line under it. Split out of `content_bottom` rather than written twice
## because `rows_that_fit` needs the same tail, and a row height derived in two places is
## the layout arithmetic `OverlayScreen.rows_that_fit`'s own header says gets re-derived
## wrongly.
static func row_ink_below_center() -> float:
	return MEANS_HEIGHT + float(DETAIL_FONT_SIZE) + 4.0


## The bottom edge of the last row's text, which is what has to fit rather than the swatch:
## the detail line sits below the swatch's centre line and is the lowest ink on the page.
static func content_bottom() -> float:
	return row_center_y(ROWS.size() - 1) + row_ink_below_center()


## How many rows this page could hold in a matte `box_height` tall — the answer to "what
## does another row cost", as a number rather than as arithmetic in a comment.
##
## `box_height` is an ARGUMENT and not `NotebookScreen.DRAWING_BOX.size.y` read directly,
## which would be the cyclic `class_name` reference this project refuses everywhere else
## (`Board` takes `PlacementPreview`'s geometry as arguments for exactly this reason):
## `NotebookScreen` already names `CueLegend`, so `CueLegend` may not name it back.
##
## The item height is a row's WHOLE ink, swatch top to detail bottom — `SWATCH_RADIUS`
## above the centre line and `row_ink_below_center()` under it. That is the number that
## makes the answer honest: the page currently fits exactly `ROWS.size()`, and a seventh
## row cannot be bought by cutting `ROW_PITCH`, because seven rows need a pitch smaller
## than one row is tall and they would overlap. See the wenx audit block above.
static func rows_that_fit(box_height: float) -> int:
	return OverlayScreen.rows_that_fit(ROW_TOP, ROW_PITCH,
		SWATCH_RADIUS + row_ink_below_center(), box_height)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_labels()


func _build_labels() -> void:
	var text_width: float = maxf(40.0, size.x - TEXT_X - 6.0)
	for i: int in ROWS.size():
		var row: Dictionary = ROWS[i]
		var id: String = String(row["shape"])
		var top: float = row_center_y(i) - MEANS_HEIGHT * 0.5 - 4.0

		var means := Label.new()
		means.name = "LegendMeans_%s" % id
		means.text = String(row["means"])
		means.position = Vector2(TEXT_X, top)
		means.size = Vector2(text_width, MEANS_HEIGHT)
		means.add_theme_font_size_override("font_size", MEANS_FONT_SIZE)
		means.add_theme_color_override("font_color", GardenTheme.LEAF_DARK)
		means.clip_text = true
		means.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		means.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(means)

		var where := Label.new()
		where.name = "LegendWhere_%s" % id
		where.text = String(row["where"])
		where.position = Vector2(TEXT_X, top + MEANS_HEIGHT - 2.0)
		where.size = Vector2(text_width, float(DETAIL_FONT_SIZE) + 6.0)
		where.add_theme_font_size_override("font_size", DETAIL_FONT_SIZE)
		where.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.7))
		where.clip_text = true
		where.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		where.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(where)


func _draw() -> void:
	for i: int in ROWS.size():
		var at := Vector2(SWATCH_X, row_center_y(i))
		match String(ROWS[i]["shape"]):
			SHAPE_SUBJECT:
				_draw_subject(at)
			SHAPE_REACH:
				_draw_reach(at)
			SHAPE_CLOCK:
				_draw_clock(at)
			SHAPE_REMARK:
				_draw_remark(at)
			SHAPE_GAIN:
				_draw_gain(at)
			SHAPE_ARMED:
				_draw_armed(at)


## Corner brackets, at `SelectionMarker`'s own proportions: ARM is 8 of HALF's 22, so the
## arms are scaled by the same ratio rather than by a number that looked right at 15 px.
func _draw_subject(at: Vector2) -> void:
	var arm: float = SWATCH_RADIUS * (SelectionMarker.ARM / SelectionMarker.HALF)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var corner := at + Vector2(sx, sy) * SWATCH_RADIUS
			draw_line(corner, corner - Vector2(sx * arm, 0.0),
				SelectionMarker.MARKER_COLOR, SelectionMarker.LINE_WIDTH, true)
			draw_line(corner, corner - Vector2(0.0, sy * arm),
				SelectionMarker.MARKER_COLOR, SelectionMarker.LINE_WIDTH, true)


## A solid full ring. `CornCobbler` draws its range at width 2.0 in the plant's edge
## colour; the swatch borrows the theme's leaf edge for the same reason the plant does.
func _draw_reach(at: Vector2) -> void:
	draw_arc(at, SWATCH_RADIUS, 0.0, TAU, 40, GardenTheme.LEAF_DARK, 2.0, true)


## A partial arc sweeping closed, which is the grammar's TIME REMAINING. Drawn at
## three-quarters so it reads as a clock mid-run rather than as a broken ring, in
## `HuskLayer`'s own bright ring colour and its widest ring weight.
func _draw_clock(at: Vector2) -> void:
	draw_arc(at, SWATCH_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * 0.75, 32,
		HuskLayer.BRIGHT_RING, HuskLayer.RING_WIDTH_MAX, true)


## A dashed ring — an arc loop, not a full circle. `SoleCoverMarks.ALONE_DASHES` is the
## dash count the board actually uses, so a change there changes this.
func _draw_remark(at: Vector2) -> void:
	var step: float = TAU / float(SoleCoverMarks.ALONE_DASHES)
	for i: int in SoleCoverMarks.ALONE_DASHES:
		var from: float = float(i) * step
		draw_arc(at, SWATCH_RADIUS, from, from + step * 0.5, 6,
			SoleCoverMarks.MARK_COLOR, SoleCoverMarks.RING_WIDTH, true)


## A filled dot. `PlacementPreview.NEW_COVER_DOT` is a cell-scale radius and the swatch is
## smaller than a cell, so it is scaled against the marker's own size rather than used raw
## — the RATIO is what the player recognises, and a 4 px dot beside a 15 px ring would read
## as a speck.
func _draw_gain(at: Vector2) -> void:
	var radius: float = SWATCH_RADIUS * (PlacementPreview.NEW_COVER_DOT / SelectionMarker.HALF) * 2.0
	draw_circle(at, maxf(3.0, radius), SelectionMarker.MARKER_COLOR)


## The armed state: the SUBJECT's own brackets at `SelectionMarker.WARNING_LINE_WIDTH` in
## `WARNING_COLOR`. Deliberately the same shape as the first row rather than a new one,
## because that IS the grammar — "doubled line width" means the mark you already know,
## thicker, and a legend that invented a separate symbol for it would teach the wrong thing.
##
## Reading the two rows together is the lesson, which is also why this row sits last: a
## player who has just been shown corner brackets meaning "this is the thing being talked
## about" is in the right frame to see the heavy version and read it as the same statement
## with a warning on it.
##
## This is the cue with the highest cost of being misread in the whole game. It guards the
## uproot, which is the one action that cannot be undone, and cycle 79 spent an entire cycle
## on the sentence beside it — while the visual half went untaught until now.
func _draw_armed(at: Vector2) -> void:
	var arm: float = SWATCH_RADIUS * (SelectionMarker.ARM / SelectionMarker.HALF)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var corner := at + Vector2(sx, sy) * SWATCH_RADIUS
			draw_line(corner, corner - Vector2(sx * arm, 0.0),
				SelectionMarker.WARNING_COLOR, SelectionMarker.WARNING_LINE_WIDTH, true)
			draw_line(corner, corner - Vector2(0.0, sy * arm),
				SelectionMarker.WARNING_COLOR, SelectionMarker.WARNING_LINE_WIDTH, true)
