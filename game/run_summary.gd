class_name RunSummary
extends Control

## The post-mortem. What a finished run actually amounted to, on a card that
## stays until the player dismisses it.
##
## This replaces a banner plus a 30-second message. Every number below was
## already computed and had nowhere to live: the seed total went into a two-line
## banner, and the weakest-cell reading — the single most useful thing the run
## produced — went into `Hud.show_message(..., 30.0)`, a one-line clipped Label
## that erases itself while the player is still reading the banner above it.
##
## The backdrop is deliberately not opaque. `Board.show_run_pressure()` paints
## the run's whole damage map onto the road at the same moment this appears, and
## that map is the visual half of the same post-mortem — so the card floats over
## it rather than replacing it, and the row naming the worst cell has the actual
## cell tinted red behind it.
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

## Alpha of the backdrop. Lower than the notebook's 0.88 on purpose: this screen
## has something worth seeing behind it.
const BACKDROP_ALPHA: float = 0.55

const BUTTON_SIZE := Vector2(232.0, 44.0)
const BUTTON_Y: float = 476.0

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
		GardenTheme.LEAF_DARK if won else GardenTheme.PAPER_MARGIN)
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
	return "%d seeds grown — your best is %d" % [earned, best]


## Every row is `label: value`, built from one table so the order is readable in
## one place and a new stat cannot be added without deciding where it sits.
func summary_rows() -> Array:
	var wave: int = int(_stats.get("wave", 0))
	var endless: bool = bool(_stats.get("endless", false))
	var waves: String = "%d" % wave if endless else "%d of %d" % [wave, int(_stats.get("wave_count", 0))]
	var rows: Array = [
		["Waves survived", waves],
		["Threat reached", "level %d" % int(_stats.get("threat_level", 1))],
		["Garden lost", "%d of %d beds" % [int(_stats.get("lives_lost", 0)), Game.LIVES]],
		["Compost swept", "%d" % int(_stats.get("compost_total", 0))],
		["Weakest ground", _worst_cell_text()],
	]
	return rows


func _worst_cell_text() -> String:
	var cell: Vector2i = _stats.get("worst_cell", Vector2i(-1, -1))
	if cell.x < 0:
		return "nothing got past you"
	return "column %d, row %d — %d lost there" % [
		cell.x + 1, cell.y + 1, int(_stats.get("worst_cell_losses", 0)),
	]


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
		# The weakest-ground row is the longest and the one that used to get
		# ellipsised out of existence in the HUD message line. Clip rather than
		# overflow, so a regression shows as a trimmed row and not as text
		# running off the paper.
		value.clip_text = true
		value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		add_child(value)

		_rows.append(value)
		y += ROW_HEIGHT + 8.0


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
