class_name OptionsScreen
extends OverlayScreen

## The screen that lets a player see and set the audio and accessibility
## preferences this game has, over the title screen.
##
## Three switches and two dials, in two tables (`OPTIONS`, `DIALS`) drawn into one
## column of rows. The dials arrived at v8 with the audio levels
## (plant-tower-defense-u9uh); before them sound was a switch and the only answer to
## "this is too loud" was silence.
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

## The DIALS, drawn under the switches, in the order they are listed.
##
## A SECOND table rather than two more entries in OPTIONS, and the reason is that
## they are a different control, not a different setting. Every function above that
## takes an OPTIONS id — `is_on`, `set_on`, `toggle`, `state_text` — answers a
## yes/no question, and `rows()` is documented and asserted as "which switches this
## screen drew". A dial has four positions and no answer to "is it on", so folding
## it into that table would mean either a `kind` field every reader has to branch
## on or an `is_on` that lies about a 25% row. Two tables, two vocabularies, one
## row grammar.
##
## NO `action` KEY, and that is a statement rather than an omission: there is no
## keystroke for a level. `KeyBindings.ACTIONS` is the Keys screen's table and is
## not this lane's to grow, and a dial is a poor fit for a key anyway — a cycle key
## for volume is four presses to get back where you were, on a control whose whole
## purpose is being findable. The key column is left blank for these rows rather
## than reading "unbound", which is what `KeyBindings.label_for(&"")` returns and
## which would claim there is a binding waiting to be made.
const SFX_LEVEL := &"sfx_level"
const MUSIC_LEVEL := &"music_level"

const DIALS: Array[Dictionary] = [
	{
		"id": SFX_LEVEL,
		"name": "Sound effects volume",
	},
	{
		"id": MUSIC_LEVEL,
		"name": "Music volume",
	},
]

## The panel this screen SHIPPED at, kept as the FLOOR. Position and width are
## final; the height is now a floor under `panel_height()` below, exactly the
## treatment `KeyBindingScreen.PANEL_MIN_HEIGHT` gets and for the same reason — a
## derived number that silently redraws a screen everyone already knows is a worse
## answer than one that only moves when it has to.
##
## Three rows of OverlayScreen.ROW_HEIGHT from ROWS_TOP put the last button's foot
## at 392; the footer starts at 440. That 48px is a GAP, asserted as one against
## OverlayScreen.FOOTER_GAP, which is where that rule lives for every overlay with
## rows: `Rect2.intersects` is false for two boxes sharing an edge, so a footer laid
## flush against the last row passes every overlap check ever written and is wrong
## only in a screenshot.
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
## Says "remembered" rather than "stay set while you play", which is what it said
## while two of the three switches died with the process. All three are in the save
## now (RunConfig's options line), so the sentence a player reads and the thing the
## file does finally agree — and the note is the only place on this screen that
## makes a promise about lifetime at all.
## Reworded at v8 from "The key beside each one still works", which stopped being
## true the moment the screen gained two rows with no key: a promise made about
## "each one" is a promise a dial row visibly breaks. Same length to the character,
## so the 700px `Note` budget it is clipped against is unchanged.
const NOTE_TEXT := "These are remembered next time you play. Where a key is shown, it still works."

var _rows: Array[StringName] = []
var _key_labels: Array[Label] = []
## The dial ids, in the order they were drawn, kept apart from `_rows` so that
## `rows()` keeps meaning exactly what its own doc comment and the suite say it
## means. Their buttons are in `_row_buttons` after the switches', at the same
## offset this array's indices carry.
var _dials: Array[StringName] = []


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


## The row for an id, switch or dial, or an empty Dictionary. Both tables, because
## `describe()` is asked for every row this screen draws — unlike `is_known()`
## above, which answers "can this be flipped" and must stay switches-only.
static func row_for(id: StringName) -> Dictionary:
	for row: Dictionary in OPTIONS:
		if StringName(row["id"]) == id:
			return row
	for row: Dictionary in DIALS:
		if StringName(row["id"]) == id:
			return row
	return {}


# -- the dials ---------------------------------------------------------------
#
# Same arrangement as the switches above: static, free of the screen, and reading
# and writing through the owner rather than through a copy this screen kept.


static func is_dial(id: StringName) -> bool:
	for row: Dictionary in DIALS:
		if StringName(row["id"]) == id:
			return true
	return false


## The step a dial is currently on, read from the mixer that actually holds it.
## An unknown id reads as full rather than erroring, the same contract `is_on`
## documents one section up.
static func level_of(id: StringName) -> int:
	match id:
		SFX_LEVEL:
			return Sfx.level()
		MUSIC_LEVEL:
			return Music.level()
	return Sfx.DEFAULT_LEVEL


## What a dial's button says. Derived through `Sfx.level_text` rather than spelled
## out here, so the screen cannot disagree with the table about what 0.75 is called.
static func level_text(id: StringName) -> String:
	return Sfx.level_text(level_of(id))


## Advances a dial one step and reports where it landed. Goes through RunConfig,
## never through `Sfx.set_level` directly, for exactly the reason `set_on` gives
## for the two mutes: the mixer is what the player hears and the save is what the
## next launch reads, and only RunConfig moves both. An unknown id is a no-op that
## reports full, not an error.
static func cycle(id: StringName) -> int:
	match id:
		SFX_LEVEL:
			return RunConfig.cycle_sfx_level()
		MUSIC_LEVEL:
			return RunConfig.cycle_music_level()
	return Sfx.DEFAULT_LEVEL


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


## HOW THIS PANEL GROWS, decided once and written where the next person adding a
## row will read it (plant-tower-defense-1490).
##
## **It grows. It does not split.** The two candidates were this and putting audio
## on its own overlay the way Keys already is, and Keys is the precedent AGAINST the
## split rather than for it: that screen was separated because its rows come from
## `KeyBindings.ACTIONS`, a table that grows every time the game gains a verb, and
## because a row there is a capture flow rather than a value. Audio is two rows,
## fixed, in exactly the row grammar the switches already use. A split would leave
## this screen holding three switches and a door, put every audio change one
## navigation step further away, and spend one of the title menu's destination slots
## — which has its own budget — on a two-row screen.
##
## Six rows is the last count that fits, and that is arithmetic rather than taste:
## at `PANEL.position.y` of 144 a seventh row returns 528, and 144 + 528 is 672
## against a 648-tall viewport. Nothing here clamps it, deliberately, exactly as
## `KeyBindingScreen.panel_height` does not — silently squashing the rows would hide
## the problem, and the suite's own panel-inside-the-viewport assertion is what says
## so out loud on the day it happens. The fix then is `ROWS_TOP`, the row PITCH, or
## the header block, not this function.
static func panel_height() -> float:
	var rows: float = float(OPTIONS.size() + DIALS.size())
	# The last row's BUTTON is what the footer has to clear, and it is
	# ROW_BUTTON_SIZE.y tall rather than a whole ROW_HEIGHT — the pitch includes the
	# gap between rows, and counting it on the last one would over-reserve. Copied in
	# shape from KeyBindingScreen.panel_height, which is the same sum against the
	# same four constants.
	var last_row_foot: float = ROWS_TOP + maxf(rows - 1.0, 0.0) * ROW_HEIGHT + ROW_BUTTON_SIZE.y
	var needed: float = (last_row_foot + FOOTER_GAP + FOOTER_HEIGHT + FOOTER_INSET) - PANEL.position.y
	return maxf(PANEL.size.y, needed)


func panel_rect() -> Rect2:
	return Rect2(PANEL.position, Vector2(PANEL.size.x, panel_height()))


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
## How many rows this screen can hold at all, with the footer's clearance intact
## AND the paper still on the screen.
##
## **The question this answers changed with `panel_height()`, and the change is the
## point.** It used to measure rows against a panel of a fixed 360, which made the
## answer 3 and made every new option a geometry decision taken while holding a
## feature — the thing -1490 was filed about. The panel now grows to its rows, so
## the binding constraint is no longer the paper, it is the VIEWPORT the paper sits
## in: the ceiling is the bottom of the screen, and a seventh row is what runs the
## paper off it.
##
## The floor passed in is `- FOOTER_GAP` and not merely the footer's y, because a
## last row flush against the footer passes every overlap check ever written and is
## wrong only in a screenshot — which is the whole reason `FOOTER_GAP` exists.
static func rows_capacity() -> int:
	var viewport_height: float = float(ProjectSettings.get_setting(
		"display/window/size/viewport_height", 648))
	return OverlayScreen.rows_that_fit(ROWS_TOP, ROW_HEIGHT, ROW_BUTTON_SIZE.y,
		viewport_height - FOOTER_HEIGHT - FOOTER_INSET - FOOTER_GAP)


## THE SWITCHES FIRST, THEN THE DIALS, and the order is a contract rather than a
## preference: `rows()` is asserted to be exactly the OPTIONS ids in table order and
## the suite reads `Row0`..`Row2` by name, so a dial drawn in among them would
## renumber a switch. It is also the right reading order — three yes/no answers,
## then two amounts.
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

	for row: Dictionary in DIALS:
		var id := StringName(row["id"])
		# Numbered on past the switches, so `Row%d` / `RowButton%d` stay one
		# continuous sequence down the paper — the naming contract OverlayScreen
		# documents is about the row's PLACE on the screen, not about its kind.
		var index: int = _rows.size() + _dials.size()
		_dials.append(id)

		add_row_label("Row%d" % index, String(row["name"]),
			Vector2(PANEL.position.x + NAME_X, y + 8.0), Vector2(NAME_WIDTH, 24.0),
			GardenTheme.INK)

		# Built and left blank rather than skipped: every row on this paper has a
		# `RowKey%d`, and a screen where the node exists for three rows and not for
		# two is a screen where a bridge recipe fails on exactly the rows a reader
		# would not think to check. See DIALS for why there is no key to show.
		add_row_label("RowKey%d" % index, "",
			Vector2(PANEL.position.x + KEY_X, y + 8.0), Vector2(KEY_WIDTH, 24.0),
			GardenTheme.LEAF_DARK, HORIZONTAL_ALIGNMENT_CENTER)

		add_row_button(index, Vector2(PANEL.position.x + BUTTON_X, y)).pressed.connect(turn.bind(id))

		y += ROW_HEIGHT


func _build_footer() -> void:
	add_back_button(Vector2(PANEL.position.x + NAME_X, footer_y()))


## Flips one switch and redraws. The only writer the buttons have, so "changed on
## screen" and "changed in the thing that owns it" cannot come apart.
func flip(id: StringName) -> bool:
	var now: bool = toggle(id)
	refresh()
	return now


## Advances one dial and redraws. The dials' counterpart to `flip` and the only
## writer their buttons have, for the same reason: "changed on screen" and "changed
## in the thing that owns it" cannot come apart if there is one door.
func turn(id: StringName) -> int:
	var now: int = cycle(id)
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
	for j: int in _dials.size():
		var dial: StringName = _dials[j]
		var button: Button = _row_buttons[_rows.size() + j]
		button.text = level_text(dial)
		# Dimmed at the quietest step and inked at every other, which is the same
		# two-channel treatment the switches get one loop up: the percentage is the
		# text channel and this is the colour one, so a player who cannot read the
		# tint still has the number. Not DANGER — a quiet game is a choice, not a
		# warning.
		button.add_theme_color_override("font_color",
			GardenTheme.INK_SOFT if level_of(dial) == Sfx.LEVELS.size() - 1
			else GardenTheme.LEAF_DARK)


## Which switches this screen drew, in row order. For tests and the bridge — the
## alternative is reading it back off rendered text, which asserts on the wrong
## layer.
##
## SWITCHES ONLY, and it stays that way: the dials are `dials()` below. This is
## asserted equal to the OPTIONS ids, and a reader of either the test or this name
## expects the set of things `is_on`/`toggle` answer for.
func rows() -> Array[StringName]:
	return _rows.duplicate()


## Which dials this screen drew, in row order. The `rows()` of the second table.
func dials() -> Array[StringName]:
	return _dials.duplicate()
