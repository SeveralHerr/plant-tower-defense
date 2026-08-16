class_name KeyBindingScreen
extends OverlayScreen

## The screen that lets a player move a key, over the title screen.
##
## The pause card has always printed a legend of the keyboard verbs; this is the
## same list with a button beside each row. It reads and writes the live InputMap
## through KeyBindings and persists the result through RunConfig, so there is no
## third copy of a binding anywhere — the row you are looking at, the handler that
## answers the key, and the line in the save file are all the same fact.
##
## It has two doors: the title screen, so a player who has not started a run can
## still reach it, and the pause card, because the player who most wants to move a
## key is the one who just pressed the wrong one mid-run. It used to have only the
## first, and this header used to say why: the pause card derives its height from
## its contents and a fifth button there grew it past the bottom of the viewport.
## That was true of a card whose TOP was a hand-picked constant. PauseScreen now
## derives that edge too and centres itself, which buys back half of every button
## it adds -- see PauseScreen.card_top.
##
## Both doors go through `build()` below. Two call sites constructing the same
## overlay by hand is how one of them ends up without PROCESS_MODE_ALWAYS.
##
## The backdrop, the paper, the Back button and `back_requested` are OverlayScreen's
## — the chrome this screen, the Options screen and the notebook all wear. What is
## left here is the row table and the rebinding itself.
##
## Node paths are a contract — `Backdrop`, `BackButton`, `ResetButton`, `Note` and
## `Row%d` / `RowKey%d` / `RowButton%d` are asserted by test_selftest.gd and
## pressable from the devtools bridge.

## The node name both doors give it. A path the bridge and test_selftest.gd press
## by name, so it is a contract and not a local choice.
const NODE_NAME := "KeysScreen"


## The one place this screen is constructed. TitleScreen and PauseScreen both open
## it, and building it twice by hand is how one of the two ends up with a different
## name or a different process mode.
##
## PROCESS_MODE_ALWAYS is set outright rather than left to inherit — and here
## rather than in OverlayScreen, so it stays a stated property of this overlay
## instead of one inherited from a base class. The pause card holds the tree
## still, and an overlay frozen by the pause that owns it has dead buttons, a Back
## that does nothing and no way out of it. Inheriting from the parent node would
## resolve to ALWAYS today, because the card is ALWAYS -- but that is a fact about
## who the parent happens to be, and it inverts silently the day this is reparented
## to a CanvasLayer. It costs nothing on the title screen, which is never paused,
## and it is a stated property a test can read instead of an inherited one it must
## infer.
static func build() -> KeyBindingScreen:
	var screen := KeyBindingScreen.new()
	screen.name = NODE_NAME
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	return screen


## Panel rect, in viewport coordinates. Everything else is placed against it.
##
## 600 tall at y=24, and the row pitch is OverlayScreen.ROW_HEIGHT rather than the
## 52 it started at, because the verb list grew an eighth row: the colourblind-bars
## toggle, which arrived as a raw scancode check on one branch while another was
## moving every verb onto the InputMap, and became an action when the two merged.
## At the previous 568-tall/52-pitch geometry eight rows footed at exactly 568
## against a footer starting at 544 — a real overlap, caught by an assertion rather
## than by eye.
##
## The older note this replaces is still the reason that assertion exists: at 536
## tall the footer's y worked out to exactly where the last row's button ended and
## every check passed, because each Control sat inside the paper and
## `Rect2.intersects` is false for two boxes sharing an edge. It only read as wrong
## in a screenshot. So the rule is a minimum GAP, not merely "no intersection", and
## the panel is sized from the row count rather than the row count being trusted to
## fit the panel. That rule now lives in one place for every overlay that has rows:
## OverlayScreen.FOOTER_GAP.
const PANEL := Rect2(226.0, 24.0, 700.0, 600.0)

const HEADING_Y: float = 44.0
const NOTE_Y: float = 90.0
const ROWS_TOP: float = 136.0

## Column x offsets from the panel's left edge.
const DOES_X: float = 32.0
const DOES_WIDTH: float = 320.0
const KEY_X: float = 372.0
const KEY_WIDTH: float = 140.0
const BUTTON_X: float = 518.0

## The action waiting for a keystroke, or `&""`. Exactly one row can be listening:
## a screen with two rows both claiming the next key has no answer for which one
## gets it.
var _listening: StringName = &""
var _rows: Array[StringName] = []
var _key_labels: Array[Label] = []
var _reset_button: Button

const PROMPT := "Press a key…"
const IDLE_NOTE := "Choose a row, then press the key you want it on."


func panel_rect() -> Rect2:
	return PANEL


func _build_contents() -> void:
	_build_header()
	_build_rows()
	_build_footer()
	refresh()


func _build_header() -> void:
	add_heading("Keys", HEADING_Y)
	# The one line that changes: it carries the instruction, the prompt while a row
	# is listening, and the refusal when a key is already spoken for. One place for
	# all three, so a rejected keystroke cannot be silent.
	add_note_label(IDLE_NOTE, NOTE_Y)


## One row per declared verb, in table order — not a hand-written list. A verb
## added to KeyBindings.ACTIONS appears here without anyone remembering to add it,
## which is the whole reason that table exists.
func _build_rows() -> void:
	var y: float = ROWS_TOP
	for action: StringName in KeyBindings.actions():
		var index: int = _rows.size()
		_rows.append(action)

		add_row_label("Row%d" % index, KeyBindings.describe(action),
			Vector2(PANEL.position.x + DOES_X, y + 8.0), Vector2(DOES_WIDTH, 24.0),
			GardenTheme.INK)

		_key_labels.append(add_row_label("RowKey%d" % index, "",
			Vector2(PANEL.position.x + KEY_X, y + 8.0), Vector2(KEY_WIDTH, 24.0),
			GardenTheme.LEAF_DARK, HORIZONTAL_ALIGNMENT_CENTER))

		var button: Button = add_row_button(index, Vector2(PANEL.position.x + BUTTON_X, y))
		button.text = "Change"
		# Bound, not read off the loop variable: a lambda closing over `action`
		# directly is the classic way seven buttons all end up rebinding the last
		# verb in the table.
		button.pressed.connect(listen_for.bind(action))

		y += ROW_HEIGHT


func _build_footer() -> void:
	var y: float = footer_y()
	add_back_button(Vector2(PANEL.position.x + DOES_X, y))

	_reset_button = Button.new()
	_reset_button.name = "ResetButton"
	_reset_button.text = "Put them all back"
	_reset_button.position = Vector2(PANEL.position.x + BUTTON_X, y)
	_reset_button.size = Vector2(ROW_BUTTON_SIZE.x, FOOTER_HEIGHT)
	_reset_button.pressed.connect(reset_all)
	add_child(_reset_button)


## Arms a row. The next key press lands on this verb; Escape backs out.
func listen_for(action: StringName) -> void:
	if not KeyBindings.is_known(action):
		return
	_listening = action
	_note.text = "%s — press the key you want, or Esc to leave it alone." % KeyBindings.describe(action)
	refresh()


## Puts every verb back on its shipped key and forgets the save's overrides.
func reset_all() -> void:
	_listening = &""
	KeyBindings.reset_all()
	_persist()
	_note.text = "Every key is back where it started."
	refresh()


## Redraws the key column and the row buttons from the InputMap. Called after
## anything that could have moved a binding, rather than each caller patching the
## one row it thinks it changed.
func refresh() -> void:
	for i: int in _rows.size():
		_key_labels[i].text = PROMPT if _rows[i] == _listening else KeyBindings.label_for(_rows[i])
		_row_buttons[i].text = "Listening…" if _rows[i] == _listening else "Change"


## Which verb is waiting for a key, or `&""`. For tests and the bridge — the
## button text says the same thing, and asserting on rendered text is asserting on
## the wrong layer.
func listening_for() -> StringName:
	return _listening


## The keystroke a listening row is waiting for.
##
## While a row is armed this swallows EVERY key, which is the point — the key being
## captured must not also fire the verb it is bound to on the way past. Everything
## else falls through to OverlayScreen._input, which answers Escape with
## `back_requested`; see its comment for why either handler is in `_input` rather
## than `_unhandled_input`.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventAction):
		return
	if _listening != &"":
		var key := event as InputEventKey
		if key == null or not key.pressed or key.echo:
			return
		capture(key.keycode)
		get_viewport().set_input_as_handled()
		return
	super._input(event)


## Binds `code` to the armed row, or explains why it did not. Split out of `_input`
## so the decision is testable without a viewport and an event queue.
##
## Returns whether the binding moved.
func capture(code: int) -> bool:
	if _listening == &"":
		return false
	var action: StringName = _listening
	if code == KEY_ESCAPE:
		# Escape is how you leave a row alone. It is also `garden_back`'s shipped
		# key, so binding it here would be a player asking for a verb they can only
		# reach by first losing the way out of this screen.
		_listening = &""
		_note.text = IDLE_NOTE
		refresh()
		return false
	var taken: StringName = KeyBindings.action_using(code, action)
	if taken != &"":
		# Two verbs on one key is not an error the engine reports — both handlers
		# simply fire. Refused here, where there is somewhere to say so.
		_listening = &""
		# Phrased so it composes with any `does` string. "M already sound effects on
		# or off." is what the obvious wording produced -- those phrases are legend
		# cells ("M   sound effects on or off"), not sentence fragments.
		_note.text = "%s is taken — it already means: %s" % [
			KeyBindings.key_label(code), KeyBindings.describe(taken),
		]
		refresh()
		return false
	# One key per verb after a rebinding, even for a verb that ships with two
	# (pause is Esc and P out of the box). A screen that appended would need a way
	# to remove, and "put them all back" is the honest version of that for a list
	# this size.
	var moved: bool = KeyBindings.set_keys(action, [code])
	_listening = &""
	if moved:
		_persist()
		# Same shape the pause card's legend draws, for the same reason as above.
		_note.text = "Set:  %s   %s" % [KeyBindings.key_label(code), KeyBindings.describe(action)]
	else:
		_note.text = IDLE_NOTE
	refresh()
	return moved


## Writes the moved rows out beside the high scores. Every path that changes a
## binding goes through here, so "changed on screen" and "changed on disk" cannot
## come apart.
func _persist() -> void:
	RunConfig.store_key_bindings(KeyBindings.overrides())
