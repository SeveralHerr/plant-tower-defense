class_name PauseScreen
extends Control

## The run, held still. Escape or P from anywhere in a run.
##
## The game had no pause at all: `get_tree().paused` appeared nowhere, and
## PREP_SECONDS kept counting down while the player was away from the keyboard,
## so stepping away mid-run cost beds. There was also no way out of a run in
## progress — the only scene change ran title -> game, and R only reloaded once
## the run was already over. Leaving meant losing or killing the process.
##
## Built in code and shaped after RunSummary rather than the Notebook, because it
## is the same kind of object: a card over a live board that must not hide the
## board entirely.

## What the card says under its heading. Set by Game before the screen enters the
## tree, because "The wave is waiting." was a constant and pause fires at any
## moment outside game-over -- so it was simply false between waves.
var _note_text: String = "The garden is holding still."

signal resume_requested
signal restart_requested
signal gate_requested

## Same card geometry as the post-mortem, centred on the board rather than the
## window, so the two screens read as the same family and neither sits off to the
## side of the thing it is covering.
const CARD := Rect2(288.0, 152.0, 320.0, 300.0)
const BACKDROP_ALPHA: float = 0.55
const BUTTON_SIZE := Vector2(248.0, 44.0)
## Offset from the card's own top, not an absolute viewport y. It was written as
## a bare 232.0 -- the one offset in this file not relative to CARD -- and with
## CARD at y=152 that put the buttons at 232 while the note's box ran 228..252, so
## twenty of the note's twenty-four pixels sat under an opaque stylebox. Nothing
## caught it: each Control fits its own box, and per-Control checks are all the UI
## gates do. Relative means moving the card can never separate them again.
const FIRST_BUTTON_OFFSET: float = 116.0
const BUTTON_GAP: float = 12.0

## Node names are a contract: the devtools bridge presses these by path.
const BUTTONS: Array[Dictionary] = [
	{"name": "ResumeButton", "text": "Back to the garden", "signal": "resume_requested"},
	{"name": "RestartButton", "text": "Start over", "signal": "restart_requested"},
	{"name": "GateButton", "text": "Back to the gate", "signal": "gate_requested"},
]


## Built by Game so the note can describe the moment the run was actually paused.
static func build(note: String) -> PauseScreen:
	var screen := PauseScreen.new()
	screen.name = "PauseScreen"
	if note != "":
		screen._note_text = note
	return screen


func _ready() -> void:
	# PROCESS_MODE_ALWAYS, or the pause screen is frozen by the pause it owns and
	# none of its own buttons can be clicked. This is the whole trick of a pause
	# menu in Godot and the reason it cannot simply be a node like any other.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Explicit position+size rather than PRESET_FULL_RECT: added with add_child()
	# outside a layout pass, where the preset resolves to 0x0. Same reason as
	# TitleScreen and RunSummary.
	position = Vector2.ZERO
	size = Vector2(_viewport_width(), _viewport_height())
	theme = GardenTheme.build()

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(GardenTheme.INK, BACKDROP_ALPHA)
	backdrop.position = Vector2.ZERO
	backdrop.size = size
	# Eats clicks, so the board and the side panel underneath cannot be played
	# through a pause.
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var card := Panel.new()
	card.name = "Card"
	card.position = CARD.position
	card.size = CARD.size
	card.add_theme_stylebox_override("panel", GardenTheme.paper_panel())
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)

	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "Paused"
	heading.position = Vector2(CARD.position.x, CARD.position.y + 30.0)
	heading.size = Vector2(CARD.size.x, 44.0)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", GardenTheme.INK)
	add_child(heading)

	var note := Label.new()
	note.name = "Note"
	note.text = _note_text
	note.position = Vector2(CARD.position.x, CARD.position.y + 76.0)
	note.size = Vector2(CARD.size.x, 24.0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.65))
	add_child(note)

	_build_buttons()


func _build_buttons() -> void:
	var y: float = CARD.position.y + FIRST_BUTTON_OFFSET
	var first: Button = null
	for spec: Dictionary in BUTTONS:
		var button := Button.new()
		button.name = String(spec["name"])
		button.text = String(spec["text"])
		button.position = Vector2(CARD.position.x + (CARD.size.x - BUTTON_SIZE.x) / 2.0, y)
		button.size = BUTTON_SIZE
		var which: String = String(spec["signal"])
		button.pressed.connect(func() -> void: emit_signal(which))
		add_child(button)
		if first == null:
			first = button
		y += BUTTON_SIZE.y + BUTTON_GAP
	if first != null:
		first.grab_focus()


## Escape and P both close it, matching the two keys that open it. Handled here
## rather than in Game because Game is paused and its _unhandled_input does not
## run — which is exactly the bug a pause menu ships with when the close key is
## left on the paused node.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE or key.keycode == KEY_P:
		resume_requested.emit()
		get_viewport().set_input_as_handled()


func _viewport_width() -> int:
	return ProjectSettings.get_setting("display/window/size/viewport_width", 1152)


func _viewport_height() -> int:
	return ProjectSettings.get_setting("display/window/size/viewport_height", 648)
