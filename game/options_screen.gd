class_name OptionsScreen
extends OverlayScreen

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
## The overlay chrome — the Backdrop, the paper, the Back button and
## `back_requested` — is OverlayScreen's, which is what lets
## TitleScreen.overlay_open() treat all three overlays alike. This screen was
## originally written by copying KeyBindingScreen, which is why its node names
## match that one to the letter; the copy is now a shared base rather than a
## second transcription.
##
## ## What persists and what does not
##
## Only the colourblind flag survives a restart, because only it is in the save
## (RunConfig.compose_save writes one options line, `cb0`/`cb1`). The two mute
## flags are Sfx._muted / Music._muted, which are static and live exactly as long
## as the process does — this screen does not change that either way, it gives
## them the same lifetime they already had from their keystrokes. Extending the
## save is a deliberate act on a format that is at v5 and has been collided on
## twice; it is filed rather than smuggled in beside a UI change.
##
## Node paths are a contract — `Backdrop`, `BackButton`, `Note` and
## `Row%d` / `RowKey%d` / `RowButton%d` are asserted by test_selftest.gd and
## pressable from the devtools bridge. The row names deliberately match
## KeyBindingScreen's, so one bridge recipe drives either screen.

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
## reason) as KeyBindingScreen.PANEL. Three rows of OverlayScreen.ROW_HEIGHT from
## ROWS_TOP put the last button's foot at 392; the footer starts at 440. That 48px
## is a GAP, asserted as one against OverlayScreen.FOOTER_GAP, which is where that
## rule lives for every overlay with rows: `Rect2.intersects` is false for two
## boxes sharing an edge, so a footer laid flush against the last row passes every
## overlap check ever written and is wrong only in a screenshot.
const PANEL := Rect2(226.0, 144.0, 700.0, 360.0)

const HEADING_Y: float = 164.0
const NOTE_Y: float = 210.0
const ROWS_TOP: float = 256.0

## Column x offsets from the panel's left edge. Same three columns as the Keys
## screen, so the two read as one pair of screens rather than two designs.
const NAME_X: float = 32.0
const NAME_WIDTH: float = 340.0
const KEY_X: float = 384.0
const KEY_WIDTH: float = 120.0
const BUTTON_X: float = 518.0

const ON_TEXT := "On"
const OFF_TEXT := "Off"
const NOTE_TEXT := "These stay set while you play. The key beside each one still works."

var _rows: Array[StringName] = []
var _key_labels: Array[Label] = []


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
## That matters for all three: RunConfig.set_colorblind_safe persists, and
## Music.set_muted has to bring the bed back rather than merely stop gating it
## (see its doc comment). Returns the state afterwards.
static func set_on(id: StringName, enabled: bool) -> bool:
	match id:
		COLORBLIND:
			RunConfig.set_colorblind_safe(enabled)
		MUTE_SFX:
			Sfx.set_muted(not enabled)
		MUTE_MUSIC:
			Music.set_muted(not enabled)
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


func panel_rect() -> Rect2:
	return PANEL


func _build_contents() -> void:
	_build_header()
	_build_rows()
	_build_footer()
	refresh()


func _build_header() -> void:
	add_heading("Options", HEADING_Y)
	add_note_label(NOTE_TEXT, NOTE_Y)


## One row per entry in OPTIONS, in table order — not a hand-written list, for
## the same reason KeyBindingScreen builds its rows off KeyBindings.ACTIONS.
func _build_rows() -> void:
	var y: float = ROWS_TOP
	for row: Dictionary in OPTIONS:
		var id := StringName(row["id"])
		var index: int = _rows.size()
		_rows.append(id)

		add_row_label("Row%d" % index, String(row["name"]),
			Vector2(PANEL.position.x + NAME_X, y + 8.0), Vector2(NAME_WIDTH, 24.0),
			GardenTheme.INK)

		_key_labels.append(add_row_label("RowKey%d" % index, "",
			Vector2(PANEL.position.x + KEY_X, y + 8.0), Vector2(KEY_WIDTH, 24.0),
			GardenTheme.LEAF_DARK, HORIZONTAL_ALIGNMENT_CENTER))

		# Bound, not read off the loop variable — a lambda closing over `id`
		# directly is how three buttons all end up flipping the last switch.
		add_row_button(index, Vector2(PANEL.position.x + BUTTON_X, y)).pressed.connect(flip.bind(id))

		y += ROW_HEIGHT


func _build_footer() -> void:
	add_back_button(Vector2(PANEL.position.x + NAME_X, footer_y()))


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
		_row_buttons[i].text = state_text(on)
		_row_buttons[i].add_theme_color_override("font_color",
			GardenTheme.LEAF_DARK if on else GardenTheme.INK_SOFT)


## Which switches this screen drew, in row order. For tests and the bridge — the
## alternative is reading it back off rendered text, which asserts on the wrong
## layer.
func rows() -> Array[StringName]:
	return _rows.duplicate()
