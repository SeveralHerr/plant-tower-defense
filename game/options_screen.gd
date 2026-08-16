class_name OptionsScreen
extends Control

## The screen that lets a player see and set the three switches this game has,
## over the title screen.
##
## Until this existed every one of them was reachable by exactly one route: a
## keystroke during a run, answered by a HUD sentence that faded. So the state of
## an accessibility option was only ever legible in the instant you changed it,
## and a player who could not remember whether the colourblind bars were on had
## to press C twice and read the second sentence to find out.
##
## ## Why a sibling screen and not a second column on the Keys screen
##
## KeyBindingScreen's panel is SIZED FROM ITS ROW COUNT (see the note on its
## PANEL), and it already runs eight verbs from y=136 to a footer at y=560 inside
## a 600-tall panel at y=24. Three more rows at its 48 pitch want another 144px,
## which puts the panel at 744 in a 648-tall viewport. Horizontally it is just as
## full: its three columns already reach x=668 of a 700-wide panel. There is no
## room in either direction, so the choice was a sibling screen or a redesign of
## the one screen that already works.
##
## Same overlay contract as NotebookScreen and KeyBindingScreen, which is what
## lets TitleScreen.overlay_open() treat all three alike: an opaque-ish Backdrop
## that eats the mouse, a paper panel, a Back button, and a `back_requested`
## signal rather than any knowledge of who opened it.
##
## ## What persists
##
## All three, now. This screen shipped with only the colourblind flag in the save,
## which is exactly the inconsistency putting three switches in one list makes
## visible to a player: two of the rows reset on every launch and the third did
## not, with nothing on screen saying which was which. The save format was at v5
## and had been collided on twice, so extending it was filed rather than smuggled
## in beside a UI change (plant-tower-defense-v6c); v6 widens the options line to
## `cb0 sfx0 mus0` and RunConfig.set_mute_sfx / set_mute_music are what this screen
## calls. See RunConfig.SAVE_VERSION for the format and its history.
##
## Node paths are a contract — `Backdrop`, `BackButton`, `Note` and
## `Row%d` / `RowKey%d` / `RowButton%d` are asserted by test_selftest.gd and
## pressable from the devtools bridge. The row names deliberately match
## KeyBindingScreen's, so one bridge recipe drives either screen.

signal back_requested

## The node name both doors give it. A path the bridge and test_selftest.gd press
## by name, so it is a contract and not a local choice. Same arrangement as
## KeyBindingScreen.NODE_NAME.
const NODE_NAME := "OptionsScreen"


## The one place this screen is constructed. TitleScreen and PauseScreen both open
## it, and building it twice by hand is how one of the two ends up with a different
## name or a different process mode — which is exactly the drift KeyBindingScreen
## grew `build()` to stop when it got its second door.
##
## PROCESS_MODE_ALWAYS is set outright rather than left to inherit. The pause card
## holds the tree still, and an overlay frozen by the pause that owns it has dead
## buttons, a Back that does nothing and no way out of it. Inheriting would resolve
## to ALWAYS today, because the card is ALWAYS — but that is a fact about who the
## parent happens to be, and it inverts silently the day this is reparented. It
## costs nothing on the title screen, which is never paused, and it is a stated
## property a test can read instead of an inherited one it must infer.
static func build() -> OptionsScreen:
	var screen := OptionsScreen.new()
	screen.name = NODE_NAME
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	return screen

## The switches, in the order they are drawn. A table rather than three
## hand-placed rows for the same reason KeyBindings.ACTIONS is one: the row list,
## the reader and the writer all have to name the same set, and three separate
## lists is how one of them ends up missing a switch.
##
## `action` is the InputMap verb that already toggles it, so each row can show
## the key it is ALSO on — the keystrokes are not replaced by this screen, and a
## row that hid them would make the Keys screen's rebinding look like it did
## nothing.
const COLORBLIND := &"colorblind"
const MUTE_SFX := &"mute_sfx"
const MUTE_MUSIC := &"mute_music"

const OPTIONS: Array[Dictionary] = [
	{
		"id": COLORBLIND,
		"name": "Colourblind-safe bars",
		"action": KeyBindings.ACTION_COLORBLIND,
	},
	{
		"id": MUTE_SFX,
		"name": "Sound effects",
		"action": KeyBindings.ACTION_MUTE_SFX,
	},
	{
		"id": MUTE_MUSIC,
		"name": "Music",
		"action": KeyBindings.ACTION_MUTE_MUSIC,
	},
]

## Panel rect, in viewport coordinates, SIZED FROM THE ROW COUNT rather than
## picked and then trusted to fit — the same discipline (and the same hard-won
## reason) as KeyBindingScreen.PANEL. Three rows of 48 from ROWS_TOP put the last
## button's foot at 392; the footer starts at 440. That 48px is a GAP, asserted
## as one: `Rect2.intersects` is false for two boxes sharing an edge, so a footer
## laid flush against the last row passes every overlap check ever written and is
## wrong only in a screenshot.
const PANEL := Rect2(226.0, 144.0, 700.0, 360.0)

const HEADING_Y: float = 164.0
const NOTE_Y: float = 210.0
const ROWS_TOP: float = 256.0
## 48, matching KeyBindingScreen: the button in a row is 40 tall (`findings`
## gates an interactive Control at 40x40 and is right to) and 8px of clearance
## above it is what keeps the label of the row below off it.
const ROW_HEIGHT: float = 48.0
const ROW_BUTTON_SIZE := Vector2(150.0, 40.0)
const FOOTER_HEIGHT: float = 40.0
## The minimum clear space between the last row and the footer. Asserted rather
## than merely achieved — see PANEL.
const FOOTER_GAP: float = 24.0

## Column x offsets from the panel's left edge. Same three columns as the Keys
## screen, so the two read as one pair of screens rather than two designs.
const NAME_X: float = 32.0
const NAME_WIDTH: float = 340.0
const KEY_X: float = 384.0
const KEY_WIDTH: float = 120.0
const BUTTON_X: float = 518.0

const ON_TEXT := "On"
const OFF_TEXT := "Off"
## Says "remembered" rather than "stay set while you play", which is what it said
## while two of the three switches died with the process. All three are in the save
## now (RunConfig's options line), so the sentence a player reads and the thing the
## file does finally agree — and the note is the only place on this screen that
## makes a promise about lifetime at all.
const NOTE_TEXT := "These are remembered next time you play. The key beside each one still works."

var _rows: Array[StringName] = []
var _key_labels: Array[Label] = []
var _buttons: Array[Button] = []
var _back_button: Button


# -- the state itself -------------------------------------------------------
#
# Static and free of the screen, so the mapping from a row to the flag it drives
# is assertable without building a Control — and so nothing here can grow a
# fourth copy of "is the colourblind ramp on".


static func is_known(id: StringName) -> bool:
	for row: Dictionary in OPTIONS:
		if StringName(row["id"]) == id:
			return true
	return false


## Whether the switch is currently ON, read from whoever actually owns it. Note
## the two mute flags are inverted on purpose: the owner stores "muted", and a
## row labelled "Sound effects" that read On while silent would be lying.
##
## An unknown id is false rather than an error, the same contract Sfx.should_play
## documents: a renamed switch should go quiet, not take the screen down.
static func is_on(id: StringName) -> bool:
	match id:
		COLORBLIND:
			return RunConfig.colorblind_safe
		MUTE_SFX:
			return not Sfx.is_muted()
		MUTE_MUSIC:
			return not Music.is_muted()
	return false


## Sets a switch through its owner's own setter, never by assigning the flag.
## That matters for all three: every one of them persists, and each setter does
## something past the flag — Music.set_muted has to bring the bed back rather than
## merely stop gating it (see its doc comment), and Sfx.set_muted stops the voices
## already sounding. Returns the state afterwards.
##
## All three go through RunConfig now. The two mutes used to call Sfx/Music
## directly, which set the flag the player hears without touching the one the save
## records — see RunConfig.mute_sfx, which owns that pairing and writes both.
static func set_on(id: StringName, enabled: bool) -> bool:
	match id:
		COLORBLIND:
			RunConfig.set_colorblind_safe(enabled)
		MUTE_SFX:
			RunConfig.set_mute_sfx(not enabled)
		MUTE_MUSIC:
			RunConfig.set_mute_music(not enabled)
	return is_on(id)


static func toggle(id: StringName) -> bool:
	if not is_known(id):
		return false
	return set_on(id, not is_on(id))


## The row for an id, or an empty Dictionary.
static func row_for(id: StringName) -> Dictionary:
	for row: Dictionary in OPTIONS:
		if StringName(row["id"]) == id:
			return row
	return {}


## What the switch is called on screen.
static func describe(id: StringName) -> String:
	return String(row_for(id).get("name", ""))


## The verb that also toggles it, so the key column reads out of the live
## InputMap rather than out of a second table of keycodes.
static func action_for(id: StringName) -> StringName:
	return StringName(row_for(id).get("action", &""))


static func state_text(on: bool) -> String:
	return ON_TEXT if on else OFF_TEXT


# -- the screen -------------------------------------------------------------


func _ready() -> void:
	# Explicit position+size rather than PRESET_FULL_RECT: added with add_child()
	# outside a layout pass, where the preset resolves to 0x0. Same reason as
	# TitleScreen, NotebookScreen, PauseScreen and KeyBindingScreen.
	position = Vector2.ZERO
	size = Vector2(get_viewport_width(), get_viewport_height())
	theme = GardenTheme.build()

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(GardenTheme.INK, 0.88)
	backdrop.position = Vector2.ZERO
	backdrop.size = size
	add_child(backdrop)

	var paper := Panel.new()
	paper.name = "Paper"
	paper.position = PANEL.position
	paper.size = PANEL.size
	paper.add_theme_stylebox_override("panel", GardenTheme.paper_panel())
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)

	_build_header()
	_build_rows()
	_build_footer()
	refresh()
	_back_button.grab_focus()


func _build_header() -> void:
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "Options"
	heading.position = Vector2(PANEL.position.x, HEADING_Y)
	heading.size = Vector2(PANEL.size.x, 40.0)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", GardenTheme.INK)
	add_child(heading)

	var note := Label.new()
	note.name = "Note"
	note.text = NOTE_TEXT
	note.position = Vector2(PANEL.position.x, NOTE_Y)
	note.size = Vector2(PANEL.size.x, 24.0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.65))
	note.clip_text = true
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(note)


## One row per entry in OPTIONS, in table order — not a hand-written list, for
## the same reason KeyBindingScreen builds its rows off KeyBindings.ACTIONS.
func _build_rows() -> void:
	var y: float = ROWS_TOP
	for row: Dictionary in OPTIONS:
		var id := StringName(row["id"])
		var index: int = _rows.size()
		_rows.append(id)

		var label := Label.new()
		label.name = "Row%d" % index
		label.text = String(row["name"])
		label.position = Vector2(PANEL.position.x + NAME_X, y + 8.0)
		label.size = Vector2(NAME_WIDTH, 24.0)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", GardenTheme.INK)
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		add_child(label)

		var key := Label.new()
		key.name = "RowKey%d" % index
		key.position = Vector2(PANEL.position.x + KEY_X, y + 8.0)
		key.size = Vector2(KEY_WIDTH, 24.0)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_theme_font_size_override("font_size", 16)
		key.add_theme_color_override("font_color", GardenTheme.LEAF_DARK)
		key.clip_text = true
		key.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		add_child(key)
		_key_labels.append(key)

		var button := Button.new()
		button.name = "RowButton%d" % index
		button.position = Vector2(PANEL.position.x + BUTTON_X, y)
		button.size = ROW_BUTTON_SIZE
		# Bound, not read off the loop variable — a lambda closing over `id`
		# directly is how three buttons all end up flipping the last switch.
		button.pressed.connect(flip.bind(id))
		add_child(button)
		_buttons.append(button)

		y += ROW_HEIGHT


func _build_footer() -> void:
	var y: float = PANEL.position.y + PANEL.size.y - FOOTER_HEIGHT - 24.0

	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = "← Back"
	_back_button.position = Vector2(PANEL.position.x + NAME_X, y)
	_back_button.size = Vector2(150.0, FOOTER_HEIGHT)
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	add_child(_back_button)


## Flips one switch and redraws. The only writer the buttons have, so "changed on
## screen" and "changed in the thing that owns it" cannot come apart.
func flip(id: StringName) -> bool:
	var now: bool = toggle(id)
	refresh()
	return now


## Redraws every row from the flags and the InputMap. Called after anything that
## could have moved either, rather than each caller patching the one row it
## believes it changed — a switch flipped by its keystroke while this screen is
## up is then one `refresh()` away from being right, instead of unreachable.
func refresh() -> void:
	for i: int in _rows.size():
		var id: StringName = _rows[i]
		_key_labels[i].text = KeyBindings.label_for(action_for(id))
		var on: bool = is_on(id)
		_buttons[i].text = state_text(on)
		_buttons[i].add_theme_color_override("font_color",
			GardenTheme.LEAF_DARK if on else GardenTheme.INK_SOFT)


## Which switches this screen drew, in row order. For tests and the bridge — the
## alternative is reading it back off rendered text, which asserts on the wrong
## layer.
func rows() -> Array[StringName]:
	return _rows.duplicate()


## Escape closes. Handled in `_input` rather than `_unhandled_input` for the same
## reason NotebookScreen and KeyBindingScreen are: a focused Button eats keys for
## focus navigation before an unhandled handler ever sees them.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventAction):
		return
	if event.is_action_pressed(KeyBindings.ACTION_BACK):
		back_requested.emit()
		get_viewport().set_input_as_handled()


func get_viewport_width() -> int:
	return ProjectSettings.get_setting("display/window/size/viewport_width", 1152)


func get_viewport_height() -> int:
	return ProjectSettings.get_setting("display/window/size/viewport_height", 648)
