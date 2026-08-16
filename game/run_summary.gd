class_name RunSummary
extends Control

## The post-mortem. What a finished run actually amounted to, on a card that
## stays until the player dismisses it.
##
## This replaces a banner plus a 30-second message. Every number below was
## already computed and had nowhere to live: the seed total went into a two-line
## banner, and the per-cell reading — the single most useful thing the run
## produced — went into `Hud.show_message(..., 30.0)`, a one-line clipped Label
## that erases itself while the player is still reading the banner above it.
##
## The backdrop is deliberately not opaque. `Board.show_run_pressure()` paints
## the run's whole damage map onto the road at the same moment this appears, and
## that map is the visual half of the same post-mortem — so the screen floats
## over it rather than replacing it.
##
## The BACKDROP is what floats. The card is not: `GardenTheme.paper_panel()` is
## opaque PAPER, and CARD covers screen x 128..768, y 96..552. Measured against
## the road PATH_CORNERS traces (board local, offset by Hud.BAR_HEIGHT = 72),
## that hides 19 of the 32 road cells outright, leaves 9 showing only their
## bottom halves along row 7, and leaves exactly 4 fully visible: (0,1), (1,1),
## (12,7) and the exit (13,7). So "the row naming a cell has that actual cell
## tinted behind it" — which this comment used to claim — is false for most of
## the board, and the one cell a player can always see is the exit.
##
## The map and the cell-naming row are deliberately not the same reading. The
## map is every pest that left the road, escapes included, so its reddest cell is
## the exit on a run that bled out; the row counts only the pests a cell stopped
## for good. See _stop_cell_text — they agreed until the exit started winning a
## row headed "weakest ground" with pests it had never touched.
##
## Put those two facts together and the player of a losing run sees one red
## corner, bottom right, and a card naming a cell they cannot even look at. Both
## halves are correct and both are wanted; nothing said they were two questions.
## `map_legend_text` is the sentence that says so, and it is deliberately printed
## on the board below the card rather than added as an eighth row — it captions a
## picture, so it belongs beside the picture, and the strip it sits in is right
## next to the only red the player can reliably see.
##
## Node names are a contract, same as the HUD's: the devtools bridge presses
## these buttons by path and test_selftest.gd reads these labels.

signal replay_requested
signal gate_requested

## Card rect in viewport coordinates. Centred on the *board*, not the window —
## the board occupies x < 896 and the side panel owns the rest, so centring on
## the window would sit the card visibly off to the right of the thing it is
## describing.
const CARD := Rect2(128.0, 96.0, 640.0, 456.0)
const ROW_HEIGHT: float = 34.0
const ROW_INSET: float = 36.0
const FIRST_ROW_Y: float = 186.0
## Gap between rows. 4, not the 8 this started at: the card grew from five rows to
## seven when the run learned to count what it defeated, and at 8 the last row ran
## to y=472 against buttons at 476 — four pixels, measured live. Not an overlap,
## but the same flush-boundary shape that put the selection panel's foot exactly on
## the panel edge two cycles ago, and BUTTON_CLEARANCE now refuses it.
const ROW_GAP: float = 4.0
## Minimum space the last row must leave above the buttons.
const BUTTON_CLEARANCE: float = 16.0

## Alpha of the backdrop. Lower than the notebook's 0.88 on purpose: this screen
## has something worth seeing behind it.
const BACKDROP_ALPHA: float = 0.55

const BUTTON_SIZE := Vector2(232.0, 44.0)
const BUTTON_Y: float = 476.0

## The map legend's strip, in viewport coordinates. Every number here is measured
## against something that would break it, so none of them is a taste call:
##
##   - the card's paper foots at 552 and its StyleBoxFlat shadow (size 14, offset
##     (0, 6)) reaches 572, so anything above 572 sits in the drop shadow;
##   - the road's last row is board row 7, which is screen y 520..584 once
##     Hud.BAR_HEIGHT is added — a caption overlapping THAT would cover the very
##     tint it is captioning, which is the one failure this label must not have;
##   - the viewport is 648 tall.
##
## 588 clears both (4px under the road, 16 under the shadow) and 588 + 22 = 610
## leaves 38px at the bottom. The width is the board's, not the card's, because
## the sentence is about the board.
const MAP_LEGEND_Y: float = 588.0
const MAP_LEGEND_HEIGHT: float = 22.0
const MAP_LEGEND_WIDTH: int = Board.COLS * Board.CELL
const MAP_LEGEND_FONT_SIZE: int = 13

## Entrance rise, matching the title screen's idiom. Gated on
## GardenTheme.animations_enabled() — headless never pumps the tween, so the
## card must already be correct before it runs.
const RISE_SECONDS: float = 0.28
const RISE_OFFSET: float = 26.0

var _rows: Array[Label] = []


## `stats` is Game.state() plus the end-of-run extras; see Game._end_run.
static func build(stats: Dictionary) -> RunSummary:
	var screen := RunSummary.new()
	screen.name = "RunSummary"
	screen._stats = stats
	return screen


var _stats: Dictionary = {}


func _ready() -> void:
	# Explicit position+size rather than PRESET_FULL_RECT: this Control is added
	# with add_child() outside any layout pass, where the preset resolves to 0x0
	# and leaves the whole card invisible. Same reason as TitleScreen._ready().
	position = Vector2.ZERO
	size = Vector2(_viewport_width(), _viewport_height())
	theme = GardenTheme.build()

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(GardenTheme.INK, BACKDROP_ALPHA)
	backdrop.position = Vector2.ZERO
	backdrop.size = size
	# MOUSE_FILTER_STOP: the run is over, and the side panel underneath still has
	# live plant and packet buttons that would otherwise stay clickable.
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var card := Panel.new()
	card.name = "Card"
	card.position = CARD.position
	card.size = CARD.size
	card.add_theme_stylebox_override("panel", GardenTheme.paper_panel())
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)

	_build_heading()
	_build_rows()
	_build_map_legend()
	_build_buttons()

	if GardenTheme.animations_enabled():
		_play_entrance()


func _build_heading() -> void:
	var won: bool = bool(_stats.get("victory", false))

	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "The garden holds!" if won else "The garden is eaten"
	heading.position = Vector2(CARD.position.x, CARD.position.y + 28.0)
	heading.size = Vector2(CARD.size.x, 44.0)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color",
		# DANGER, not PAPER_MARGIN. That one is the notebook page's printed
		# margin rule -- paper stock chosen for a different screen's look -- and
		# it is the softer of the two reds. "The garden is eaten" is the loudest
		# "this cost you something" line in the game and should wear the colour
		# that means exactly that everywhere else.
		GardenTheme.LEAF_DARK if won else GardenTheme.DANGER)
	add_child(heading)

	var sub := Label.new()
	sub.name = "Subheading"
	sub.text = _score_line()
	sub.position = Vector2(CARD.position.x, CARD.position.y + 78.0)
	sub.size = Vector2(CARD.size.x, 26.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.7))
	add_child(sub)


## The seed total against the persisted best. Pulled out as its own builder so a
## test can assert every branch of it without standing up a Control — the same
## shape TitleScreen.high_score_text() uses for the same reason.
func _score_line() -> String:
	var earned: int = int(_stats.get("seeds_earned_total", 0))
	if bool(_stats.get("new_record", false)):
		return "%d seeds grown — a new best" % earned
	var best: int = int(_stats.get("high_score", 0))
	# "your best" is now the record for the mode just played, not a single number
	# shared between the eight-wave campaign and an unbounded endless run.
	var mode: String = "endless" if bool(_stats.get("endless", false)) else "campaign"
	return "%d seeds grown — your best %s is %d" % [earned, mode, best]


## Every row is `label: value`, built from one table so the order is readable in
## one place and a new stat cannot be added without deciding where it sits.
func summary_rows() -> Array:
	var wave: int = int(_stats.get("wave", 0))
	var endless: bool = bool(_stats.get("endless", false))
	var waves: String = "%d" % wave if endless else "%d of %d" % [wave, int(_stats.get("wave_count", 0))]
	var rows: Array = [
		["Waves survived", waves],
		["Pests defeated", "%d" % int(_stats.get("pests_defeated", 0))],
		["Time in the garden", _duration_text()],
		["Threat reached", "level %d" % int(_stats.get("threat_level", 1))],
		["Garden lost", "%d of %d beds" % [int(_stats.get("lives_lost", 0)), Game.LIVES]],
		["Compost swept", _compost_text()],
		["Where you held them", _stop_cell_text()],
	]
	return rows


## Compost as a fraction, not a bare tally: "12 of 19", the seeds swept against
## the seeds that were there to sweep. Every other row on this card is a total or
## a bound; "Compost swept 12" was the one number with no scale behind it, and a
## player cannot tell a clean run from an ignored lane by reading it.
##
## Folded into the existing row rather than given an eighth one. Height is the
## binding constraint: rows step by ROW_HEIGHT + ROW_GAP = 38, the seventh ends
## at 186 + 6*38 + 34 = 448 against buttons at 476, so there are 28px of slack
## and BUTTON_CLEARANCE wants 16 of them. An eighth row would foot at 486 — ten
## pixels *below* the top of the buttons, not merely inside the clearance — and
## ROW_GAP has already been cut once (8 to 4) to fit the seventh. Width is not
## the constraint: the value column is CARD.size.x * 0.58 - ROW_INSET = 335px,
## and "127 of 214" is shorter than the "3 of 5 beds" the Garden lost row above
## already renders, never mind the stopping-point row that sets the real width
## high-water mark. So the fraction is free and this row costs what it always did.
##
## `total_resolved()` is the denominator, so a husk still on the ground when the
## run ended is in neither half — see CompostMeter.total_resolved for why.
func _compost_text() -> String:
	var swept: int = int(_stats.get("compost_total", 0))
	# -1, not `swept`: an absent denominator and a perfect sweep must not read the
	# same. A stats dictionary that predates the denominator degrades to the bare
	# numerator it always showed, rather than claiming a "12 of 12" it cannot know.
	var resolved: int = int(_stats.get("compost_resolved", -1))
	if resolved < swept or resolved <= 0:
		return "%d" % swept
	return "%d of %d" % [swept, resolved]


## Minutes and seconds. A bare float of seconds is a number the player has to
## convert, and "413.7" is not a thing anyone recognises about their own run.
func _duration_text() -> String:
	var total: int = int(round(float(_stats.get("run_seconds", 0.0))))
	return "%d:%02d" % [total / 60, total % 60]


## The chokepoint, named as a chokepoint.
##
## This row used to be headed "Weakest ground" over `worst_cell` — the cell where
## the most pests left the road, killed or escaped alike. In almost every run
## that is the cell holding the player's best turret, so the post-mortem's one
## piece of spatial advice named the strongest ground in the garden and told the
## player it was the weakest. A player acting on it dismantles the thing that was
## working. The row is not merely useless when it is wrong; it is inverted.
##
## Two things changed. The number is now `stop_cell_stops` — losses with the
## escapes taken back out, so the exit cell cannot bid for the row with pests it
## never touched (Board.worst_stop_cell). And the heading states what is measured
## instead of interpreting it: "where you held them" is true of a chokepoint and
## true of a last-ditch stand at the exit, and neither reading recommends tearing
## anything down.
##
## The weakness half of the post-mortem is not missing, it is on the two rows
## that measure it directly — "Garden lost N of 10 beds" is the escape count, and
## the road underneath this card is still painted with the full mixed map, whose
## reddest cell IS the exit on a run that bled out. So the card carries both
## readings, in the two media each is honest in: a number for what stopped them,
## a picture for where they got to.
##
## The row wears "held", not "stopped", and that is the third change rather than
## a synonym. "Stopped" is already the mixed map's own word for its own reading —
## Board.depth_of documents `losses` as "every pest that STOPPED there, not every
## pest that hurt you", kills and escapes alike. A row headed "Where they
## stopped" therefore described the tint at least as well as it described this
## number, which is exactly the collision that made a player read the number as a
## caption for the picture. "Held" is true of a kill and false of an escape, so
## it cannot be read off the tint at all. See map_legend_text for the other side.
func _stop_cell_text() -> String:
	var cell: Vector2i = _stats.get("stop_cell", Vector2i(-1, -1))
	if cell.x < 0:
		# Not "nothing got past you", which is what this said before. That is a
		# claim about escapes, made from an empty measurement of kills: the run
		# that reaches this branch hardest is the one that stopped nothing at all
		# anywhere, and it read as the compliment for a flawless run.
		#
		# And note which run reaches it: one where every pest walked out. The road
		# behind the card is at its reddest in exactly that run, so this branch and
		# the tint are at their furthest apart here. map_legend_text still fires.
		return "nowhere — no ground held them"
	return "column %d, row %d — %d held" % [
		cell.x + 1, cell.y + 1, int(_stats.get("stop_cell_stops", 0)),
	]


## The caption for the picture. This is the whole of the fix for "the post-mortem
## names a cell the road under it may not be reddest at".
##
## The two readings are not collapsed, because a player wants both: "how far did
## they get" is the tint, "where did my ground actually do work" is the row. What
## was missing was any statement that they are two questions. An unlabelled
## picture next to a number reads as a picture the number captions.
##
## On a run that bleeds out they are guaranteed to disagree, not merely likely to:
## Game._on_pest_escaped files every one of the LIVES escapes against
## Board.exit_cell(), so the exit accumulates 10 losses without stopping anything,
## and worst_run_cell() goes to the one cell in the run that did the least. That
## is the run this sentence exists for.
##
## Reads `worst_cell`, which summary_stats has always exported and no part of this
## card has ever displayed — it is stored precisely because the paint is made from
## it. So the legend names the reddest cell out of the same value the tint peaks
## at, and the two cannot drift.
##
## Returns "" when nothing was lost anywhere: Board.show_run_pressure() early-
## returns on an empty loss map, so there is no red road, and a legend for it
## would be describing paint that was never applied.
func map_legend_text() -> String:
	var reddest: Vector2i = _stats.get("worst_cell", Vector2i(-1, -1))
	if reddest.x < 0:
		return ""
	if reddest == _stats.get("stop_cell", Vector2i(-1, -1)):
		# The agreeing case still gets a caption. Saying "these are the same cell"
		# is a reading; saying nothing leaves the player to assume it, and the
		# assumption is wrong on the next run.
		return "Red road: how far they got, escapes and all. Reddest at the very cell the card above names."
	# Kept short deliberately. The strip is MAP_LEGEND_WIDTH = 896px at font size
	# 13 with no autowrap, and this is the longest string the screen draws; see
	# test_the_map_legend_clears_the_card_the_road_and_the_bottom_of_the_screen,
	# which measures it through the resolved font rather than trusting the count.
	return ("Red road: how far they got, escapes and all. Reddest at column %d, row %d"
		+ " — the card above counts only what held.") % [reddest.x + 1, reddest.y + 1]


func _build_map_legend() -> void:
	var text: String = map_legend_text()
	# No node at all rather than an empty one: a zero-content Label here is what
	# validate-ui reports as an offscreen/zero-size Control finding, and a run with
	# nothing painted has nothing to say.
	if text.is_empty():
		return
	var legend := Label.new()
	legend.name = "MapLegend"
	legend.text = text
	legend.position = Vector2(0.0, MAP_LEGEND_Y)
	legend.size = Vector2(float(MAP_LEGEND_WIDTH), MAP_LEGEND_HEIGHT)
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# The backdrop already stops every click; this label must not become the thing
	# that eats one on its way there.
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_theme_font_size_override("font_size", MAP_LEGEND_FONT_SIZE)
	# PAPER, not INK: this one sits on the INK backdrop over dark road, not on the
	# card's paper, and it is the only text on the screen that does.
	legend.add_theme_color_override("font_color", Color(GardenTheme.PAPER, 0.82))
	add_child(legend)


func _build_rows() -> void:
	var y: float = FIRST_ROW_Y
	for row: Array in summary_rows():
		var key := Label.new()
		key.name = "Row_%s" % String(row[0]).replace(" ", "")
		key.text = String(row[0])
		key.position = Vector2(CARD.position.x + ROW_INSET, y)
		key.size = Vector2(CARD.size.x * 0.42, ROW_HEIGHT)
		key.add_theme_font_size_override("font_size", 17)
		key.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.62))
		add_child(key)

		var value := Label.new()
		value.name = "Value_%s" % String(row[0]).replace(" ", "")
		value.text = String(row[1])
		value.position = Vector2(CARD.position.x + CARD.size.x * 0.42, y)
		value.size = Vector2(CARD.size.x * 0.58 - ROW_INSET, ROW_HEIGHT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_font_size_override("font_size", 17)
		value.add_theme_color_override("font_color", GardenTheme.INK)
		# The stopping-point row is the longest and the one that used to get
		# ellipsised out of existence in the HUD message line. Clip rather than
		# overflow, so a regression shows as a trimmed row and not as text
		# running off the paper.
		value.clip_text = true
		value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		add_child(value)

		_rows.append(value)
		y += ROW_HEIGHT + ROW_GAP


func _build_buttons() -> void:
	var replay := Button.new()
	replay.name = "ReplayButton"
	replay.text = "Plant another garden"
	replay.position = Vector2(CARD.position.x + ROW_INSET, BUTTON_Y)
	replay.size = BUTTON_SIZE
	replay.pressed.connect(func() -> void: replay_requested.emit())
	add_child(replay)

	var gate := Button.new()
	gate.name = "GateButton"
	gate.text = "Back to the gate"
	gate.position = Vector2(CARD.position.x + CARD.size.x - ROW_INSET - BUTTON_SIZE.x, BUTTON_Y)
	gate.size = BUTTON_SIZE
	gate.pressed.connect(func() -> void: gate_requested.emit())
	add_child(gate)

	# Restarting was previously an undocumented R keypress that nothing on screen
	# ever mentioned. It still works; now there is also a button, and this says so.
	var hint := Label.new()
	hint.name = "KeyHint"
	hint.text = "or press R"
	hint.position = Vector2(CARD.position.x, BUTTON_Y + BUTTON_SIZE.y + 6.0)
	hint.size = Vector2(CARD.size.x, 20.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.45))
	add_child(hint)

	replay.grab_focus()


func _play_entrance() -> void:
	for child: Node in get_children():
		var control := child as Control
		if control == null or control.name == "Backdrop":
			continue
		control.position.y += RISE_OFFSET
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(control, "position:y", control.position.y - RISE_OFFSET, RISE_SECONDS)


func _viewport_width() -> int:
	return ProjectSettings.get_setting("display/window/size/viewport_width", 1152)


func _viewport_height() -> int:
	return ProjectSettings.get_setting("display/window/size/viewport_height", 648)
