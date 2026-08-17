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
## Whether the reset button is one press from firing. See `reset_all()`.
var _reset_armed: bool = false

const PROMPT := "Press a key…"
const IDLE_NOTE := "Choose a row, then press the key you want it on."
const RESET_IDLE := "Put them all back"
## What the button says once armed. Carries the count, because "are you sure" with
## no number is a question the player cannot answer — one moved key and six are
## the same dialog otherwise.
const RESET_ARMED := "Yes — undo %d"
const RESET_NOTHING_TO_DO := "Every key is already where it started."
## The armed note's opening clause. Separate so the test can assert the sentence's
## SHAPE — count first, verb names last after a colon — rather than only that the
## names appear somewhere in it, which is what let a garbled first draft through.
const RESET_MOVED_COUNT := "%d key%s moved."


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
	# Picking a row is the "no" answer to an armed reset. An arm that survived the
	# player going off to do something else would fire on their next glance at the
	# button, which is the confirmation being worse than none.
	_disarm_reset()
	_listening = action
	_note.text = "%s — press the key you want, or Esc to leave it alone." % KeyBindings.describe(action)
	refresh()


## The reset button's handler, in two presses rather than one.
##
## It used to be wired straight through: one press ran `KeyBindings.reset_all()`,
## `_persist()`, and therefore `RunConfig._save()`, so every key a player had moved
## was gone from disk before their finger left the mouse — no confirm, no undo, and
## the only feedback a past-tense sentence. Of everything a settings screen owns
## this is the one control that can destroy work, and it looked exactly as safe as
## "Change".
##
## Two presses, not a modal: this screen is already an overlay over a card that may
## itself be over a paused run, and a third layer to answer a yes/no is more
## machinery than the question is worth. The button becomes the question.
##
## What is about to be lost is DERIVED, never counted by hand —
## `KeyBindings.overrides()` is "every action whose keys differ from the table's",
## the same set the save file is written from. So the number in the prompt and the
## number that actually gets undone cannot disagree.
func reset_all() -> void:
	_listening = &""
	var moved: Dictionary = KeyBindings.overrides()
	if moved.is_empty():
		# The old version wrote a save here — reset the InputMap to what it already
		# was and persisted it. Nothing to undo is not a thing to confirm OR to
		# write; it is a thing to say.
		_disarm_reset()
		_note.text = RESET_NOTHING_TO_DO
		return
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = RESET_ARMED % moved.size()
		# It names the KEYS, not the verbs, and both halves of that were forced by
		# reading this line in the running game rather than by design:
		#
		#   1. `KeyBindings.describe()` returns a legend cell ("hold the garden
		#      still"), not a noun phrase -- the same trap written up thirty lines
		#      down at the refusal message. The first draft read "hold the garden
		#      still will go back to its shipped key".
		#   2. Even composed correctly, those phrases are whole sentences, and this
		#      Label is 700px with `clip_text`. Two of them measured 962px and the
		#      harness reported `ui_text_trimmed`: the player saw a cut string, so a
		#      confirmation naming what it will destroy named it off the edge.
		#
		# The key labels are what the player actually chose and actually loses, and
		# eight of them still fit where two `does` phrases did not. The rows directly
		# above say which verb each key belongs to, which is the half this line does
		# not have room to repeat.
		_note.text = "%s Press again to put %s back — or pick a row to leave it alone." % [
			RESET_MOVED_COUNT % [moved.size(), "" if moved.size() == 1 else "s"],
			_moved_keys(moved),
		]
		refresh()
		return
	KeyBindings.reset_all()
	_persist()
	_disarm_reset()
	_note.text = "Every key is back where it started."
	refresh()


## The keys currently sitting on the moved verbs, in table order rather than
## Dictionary order. Table order because `actions()` is what every other list on
## this screen is drawn in, and a confirmation that names them in a different order
## than the rows above it reads as being about something else.
func _moved_keys(moved: Dictionary) -> String:
	var names: PackedStringArray = []
	for action: StringName in KeyBindings.actions():
		if moved.has(String(action)):
			names.append(KeyBindings.label_for(action))
	return " · ".join(names)


## Back to "Put them all back". Called from everywhere that means "not that":
## picking a row, capturing a key, and the reset completing.
func _disarm_reset() -> void:
	_reset_armed = false
	if _reset_button != null:
		_reset_button.text = RESET_IDLE


## Is the reset one press from firing? For tests and the bridge — the button's text
## says the same thing, and asserting on rendered text is asserting on the wrong
## layer (same reason `listening_for()` exists).
func reset_armed() -> bool:
	return _reset_armed


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
