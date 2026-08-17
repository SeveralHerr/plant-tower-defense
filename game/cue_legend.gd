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
]


static func row_count() -> int:
	return ROWS.size()


## The y a row's swatch centre sits at. Pure, so the fits-the-page test can ask where the
## last row lands without building the pane — the same split `OverlayScreen.rows_that_fit`
## uses.
static func row_center_y(index: int) -> float:
	return ROW_TOP + float(index) * ROW_PITCH + SWATCH_RADIUS


## The bottom edge of the last row's text, which is what has to fit rather than the swatch:
## the detail line sits below the swatch's centre line and is the lowest ink on the page.
static func content_bottom() -> float:
	return row_center_y(ROWS.size() - 1) + MEANS_HEIGHT + float(DETAIL_FONT_SIZE) + 4.0


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
