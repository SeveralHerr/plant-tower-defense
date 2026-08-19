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
## Height and top only. The WIDTH is derived from the columns above and the panel is
## re-centred on it, so a wider key column grows the paper evenly on both sides
## rather than pushing it right -- the same reason PauseScreen derives CARD_X.
const PANEL_TOP: float = 24.0
## The shipped panel, kept as the FLOOR so nothing moves at eight rows and the
## paper only grows for a table that has outgrown it. Same treatment
## `key_column_width()` gives KEY_MIN_WIDTH, and for the same reason: a derived
## number that silently redraws the screen everyone already knows is a worse answer
## than one that only moves when it has to.
const PANEL_MIN_HEIGHT: float = 600.0


## Tall enough to hold every row in `KeyBindings.ACTIONS` and still stand
## `FOOTER_GAP` clear of the footer — DERIVED, which is what the header two
## paragraphs up has been asking for since the eighth row arrived and overlapped
## the footer at the then-hardcoded 568.
##
## The ninth row is the speed toggle (`GameSpeed`), and it is what turned this
## constant into a function: at the shipped 600 the last row footed at exactly the
## footer's y, a clearance of 0 against a FOOTER_GAP of 24, which
## `OverlayScreen._warn_if_footer_is_flush` would have pushed an error about at
## build time and `_overlay_content_fits_and_stands_clear` fails on.
##
## NINE ROWS IS THE LAST COUNT THAT FITS. The arithmetic below returns 624 for
## nine, and 24 + 624 is exactly the 648-tall viewport — a tenth verb returns 672
## and puts the paper's foot off the bottom of the screen. Nothing here clamps it,
## deliberately: silently squashing the rows would hide the problem, and
## `test_the_keys_panel_stays_inside_the_viewport` is the assertion that says so
## out loud on the day it happens. The fix then is the row PITCH or the header
## block, not this function.
static func panel_height() -> float:
	var rows: float = float(KeyBindings.actions().size())
	# The last row's BUTTON is what the footer has to clear, and it is
	# ROW_BUTTON_SIZE.y tall rather than a whole ROW_HEIGHT — the pitch includes the
	# gap between rows, and counting it on the last one would over-reserve.
	var last_row_foot: float = ROWS_TOP + maxf(rows - 1.0, 0.0) * ROW_HEIGHT + ROW_BUTTON_SIZE.y
	var needed: float = (last_row_foot + FOOTER_GAP + FOOTER_HEIGHT + FOOTER_INSET) - PANEL_TOP
	return maxf(PANEL_MIN_HEIGHT, needed)


static func panel_width() -> float:
	return (DOES_X * 2.0 + DOES_WIDTH + DOES_KEY_GAP + key_column_width()
		+ KEY_BUTTON_GAP + ROW_BUTTON_SIZE.x)

const HEADING_Y: float = 44.0
const NOTE_Y: float = 90.0
const ROWS_TOP: float = 136.0

## Column x offsets from the panel's left edge.
##
## The KEY column is DERIVED, and it is the only one that has to be: its text is the
## player's, not ours. `capture()` binds whatever keycode arrives, and the engine
## names some of them at length -- "On-screen keyboard" measures 157px at this
## screen's font 16 against the 140px column this used to be, so the one screen whose
## entire job is telling the player which key a verb sits on was showing them
## "On-screen keybo...". That is worse than the same truncation on the pause card,
## because the pause card's justification for allowing it was "the Keys screen shows
## it in full" -- which was not true.
##
## Same treatment PauseScreen.card_width() got: measure, derive, floor. 140 stays as
## the FLOOR, so nothing moves for a player on the shipped keys and the panel widens
## only for the one who binds a long name.
const DOES_X: float = 32.0
const DOES_WIDTH: float = 320.0
## Between the phrase column and the key column, and between the key column and the
## row's button. Named because the panel width is a sum of them and an unnamed term
## inside a sum is the one nobody can find later.
const DOES_KEY_GAP: float = 20.0
const KEY_BUTTON_GAP: float = 6.0
## The column the key has always had, kept as the minimum so the shipped layout is
## pixel-identical and only a long binding moves anything.
const KEY_MIN_WIDTH: float = 140.0

## Appended to a key that the armed reset is about to take back
## (plant-tower-defense-saq).
##
## **A second channel, not a decoration.** The row is also tinted DANGER while armed,
## and a tint alone is exactly what `RunConfig.colorblind_safe` exists to make
## unreliable -- this project already answers that everywhere it warns: lane pressure
## is hatched because the cursor tint it shares a cell with is not, and a regrowing
## health bar is notched because a bleeding one is not. This is the same rule on a
## Label, where the only channel available besides colour is the text itself.
##
## **Not an arrow**, and that is the whole of the choice. "←" was the first version,
## picked because it is proven in this font (`OverlayScreen.BACK_TEXT` is "← Back")
## and because it reads as "going back" -- and a screenshot of the armed screen shows
## why it is wrong: `KeyBindings.SHORT_NAMES` renders KEY_LEFT as "←", so the pager's
## own row is a key literally named "←" and a moved one would read "← ←".
##
## The mark has to come from outside the key vocabulary, which rules out all four
## arrows, "Esc", "Space" and "Enter". A bullet is not a keycode string in any build,
## and it is a mark rather than a word, which is what a second channel wants -- the
## note above the rows is already carrying the sentence.
##
## The key column's width includes it (see `key_column_width`), so arming the reset
## never widens the panel or clips a name.
##
## DELIBERATELY NOT `Glyphs.BULLET`, though `Glyphs.TABLE` documents this character and
## a test asserts the two agree (plant-tower-defense-m14g). Building the literal from
## the constant would make that assertion compare `Glyphs.BULLET` to `Glyphs.BULLET`,
## and the table earns its keep precisely by being a CHECKED CACHE with two independent
## sides — one of them here, one of them there. Wiring collapses it to one side and the
## check stops being able to fail.
##
## So the pointer is prose and the agreement is a test: **before choosing a new mark,
## read `Glyphs.ROLE_MARK`.** It records which characters are already spoken for and
## why a mark, unlike a worded label such as `OverlayScreen.BACK_TEXT`, must not be a
## glyph `KeyBindings.SHORT_NAMES` also prints — a bare mark beside a key's name reads
## as one string, which is the bug that produced that table.
const KEY_REVERT_MARK := "  •"
## What add_row_label draws at. Hoisted so the derivation and the Label cannot end up
## measuring different fonts -- the same reason PauseScreen.KEY_ROW_FONT_SIZE exists.
const ROW_FONT_SIZE: int = 16


## As wide as the widest key the engine can ever name here, floored at the shipped
## column. **Not** the widest key currently bound, and the difference is the point.
##
## PauseScreen.key_column_width() derives from the CURRENT bindings, because that card
## is rebuilt every time it opens and a player never watches it resize. This screen is
## the one they are editing ON: the column would have to grow under their hands, mid-
## keystroke, in response to the key they just pressed -- and the row's button would
## slide sideways as it did. A layout that reflows while you are using it is a worse
## answer than a column that was always wide enough.
##
## So the set is "every key that could appear here" rather than "every key here now",
## which for this screen is the honest reading of the same rule. It costs ~17px of a
## 700px panel, once, for everyone -- against 80px of a 360px card, which is what made
## the same choice wrong on the pause card.
##
## Cached because it sweeps the engine's whole special-key block and the answer cannot
## change within a process.
static var _key_column_cache: float = 0.0

static func key_column_width() -> float:
	if _key_column_cache > 0.0:
		return _key_column_cache
	var widest: float = KEY_MIN_WIDTH
	# The printable range, then the special block (KEY_SPECIAL is 1 << 22). A code the
	# engine does not name comes back as `KeyBindings.key_label`'s "?" placeholder,
	# which measures a few px and cannot be what wins the max.
	#
	# `KeyBindings.key_label`, NOT `OS.get_keycode_string` -- the string the row
	# actually DRAWS. The two differ for every code in `KeyBindings.SHORT_NAMES`, and
	# that table is not only a shortener: it exists to make a key READABLE, so an entry
	# giving a punctuation key a word ("Apostrophe" for what the engine calls "'") is
	# WIDER than the engine's name. Measuring the engine's name would then size this
	# column for a string no row ever shows, and the one screen whose entire job is
	# telling the player which key a verb sits on would clip the name it invented.
	# Sweeping the drawn label means a change to SHORT_NAMES flows through here with
	# nobody remembering to come and widen anything.
	for code: int in range(32, 127):
		widest = maxf(widest, GardenTheme.measure(KeyBindings.key_label(code), ROW_FONT_SIZE))
	for code: int in range(1 << 22, (1 << 22) + 512):
		widest = maxf(widest, GardenTheme.measure(KeyBindings.key_label(code), ROW_FONT_SIZE))
	# Room for the revert mark on the widest of them. Arming the reset appends it to
	# every moved row, and a column sized without it would clip the longest key name
	# exactly when the player is being asked to decide about that key.
	_key_column_cache = ceilf(widest + GardenTheme.measure(KEY_REVERT_MARK, ROW_FONT_SIZE))
	return _key_column_cache


## Which way the key text sits in its column, for EVERY screen that draws a key
## beside the phrase it belongs to (plant-tower-defense-22a).
##
## One rule, stated once: **the key text is flush against the gutter it shares with
## its `does` phrase.** The pause card wrote that rule down first -- "a ragged right
## edge on the key column would put a variable gap in the middle of every row" -- and
## then wrote, one line above it, that the keys "line up vertically the way they
## already do on the Keys screen". They did not. The card right-aligned; this screen
## centred, which is ragged on BOTH edges, so the gap between a verb's phrase and its
## key was a different width on every row and the card's comment was describing a
## screen that did not exist.
##
## It is derived from the LAYOUT rather than written down per screen, because the two
## screens put the columns in opposite orders and the alignment is a consequence of
## that order, not an independent choice:
##
##   PauseScreen       [key][gap][does]   phrase to the RIGHT -> key aligns RIGHT
##   KeyBindingScreen  [does][gap][key]   phrase to the LEFT  -> key aligns LEFT
##
## So the two screens disagree about the enum and agree about the rule, which is the
## only reading of "align the key column across both screens" that survives the
## columns being in different orders. Reorder a screen's columns and the alignment
## follows on its own; hand-writing it is how they came apart the first time.
##
## Takes the two columns' LEFT edges rather than a flag, so there is no second copy
## of "which side is the phrase on" to drift from the positions actually used.
static func key_alignment(key_left: float, phrase_left: float) -> int:
	if phrase_left > key_left:
		return HORIZONTAL_ALIGNMENT_RIGHT
	return HORIZONTAL_ALIGNMENT_LEFT


## This screen's own answer, so a caller does not have to reassemble the geometry to
## ask. Both terms are the same column offsets `_build_rows` places the labels at.
static func row_key_alignment() -> int:
	return key_alignment(key_x(), DOES_X)


static func key_x() -> float:
	return DOES_X + DOES_WIDTH + DOES_KEY_GAP


static func button_x() -> float:
	return key_x() + key_column_width() + KEY_BUTTON_GAP

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


## Centred on the LIVE canvas, not on the design width it used to inline a
## `ProjectSettings` read for (plant-tower-defense-nrup). Identical at 1152; on a
## wider window this is the paper actually landing in the middle of the screen
## instead of in the middle of the left 1152px of it. Every row on this screen is
## placed at `panel_rect().position.x + <column offset>`, so they all follow from
## this one number and none of them needed touching.
##
## The HEIGHT stays derived from the row count against the DESIGN height -- see
## `panel_height()`'s nine-row ceiling, and `ScreenMetrics` for why a budget must
## not follow the window.
func panel_rect() -> Rect2:
	var width: float = panel_width()
	return Rect2(paper_left(width), PANEL_TOP, width, panel_height())


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
			Vector2(panel_rect().position.x + DOES_X, y + 8.0), Vector2(DOES_WIDTH, 24.0),
			GardenTheme.INK)

		# Flush against the phrase column, not centred -- see `key_alignment`. Centred
		# put a different-width gap between every verb and its key, on the one screen
		# a player reads down looking for one.
		_key_labels.append(add_row_label("RowKey%d" % index, "",
			Vector2(panel_rect().position.x + key_x(), y + 8.0), Vector2(key_column_width(), 24.0),
			GardenTheme.LEAF_DARK, row_key_alignment()))

		var button: Button = add_row_button(index, Vector2(panel_rect().position.x + button_x(), y))
		button.text = "Change"
		# Bound, not read off the loop variable: a lambda closing over `action`
		# directly is the classic way seven buttons all end up rebinding the last
		# verb in the table.
		button.pressed.connect(listen_for.bind(action))

		y += ROW_HEIGHT


func _build_footer() -> void:
	var y: float = footer_y()
	add_back_button(Vector2(panel_rect().position.x + DOES_X, y))

	_reset_button = Button.new()
	_reset_button.name = "ResetButton"
	_reset_button.text = "Put them all back"
	_reset_button.position = Vector2(panel_rect().position.x + button_x(), y)
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
	var landed: bool = _persist()
	_disarm_reset()
	_note.text = persisted_note("Every key is back where it started.", landed)
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
	# Which rows the armed reset would take back. Read once rather than per row, and
	# only while armed -- `overrides()` walks every action and compares against the
	# table, which is cheap but not free, and every other refresh is a keystroke.
	var reverting: Dictionary = KeyBindings.overrides() if _reset_armed else {}
	for i: int in _rows.size():
		var listening: bool = _rows[i] == _listening
		var doomed: bool = reverting.has(String(_rows[i]))
		var key_text: String = PROMPT if listening else KeyBindings.label_for(_rows[i])
		if doomed and not listening:
			key_text += KEY_REVERT_MARK
		_key_labels[i].text = key_text
		# Two channels, and the colour is the second one. See KEY_REVERT_MARK.
		_key_labels[i].add_theme_color_override("font_color",
			GardenTheme.DANGER if doomed else GardenTheme.LEAF_DARK)
		_row_buttons[i].text = "Listening…" if listening else "Change"


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
		var landed: bool = _persist()
		# Same shape the pause card's legend draws, for the same reason as above.
		_note.text = persisted_note("Set:  %s   %s" % [
			KeyBindings.key_label(code), KeyBindings.describe(action)], landed)
	else:
		_note.text = IDLE_NOTE
	refresh()
	return moved


## Writes the moved rows out beside the high scores. Every path that changes a
## binding goes through here, so "changed on screen" and "changed on disk" cannot
## come apart.
## Returns whether it reached disk, so the two callers can say so
## (plant-tower-defense-bia). Before this it returned void and the only feedback was the
## row's key text changing — which looks identical when the write failed, on the one screen
## whose entire job is changing something that has to survive the session.
func _persist() -> bool:
	return RunConfig.store_key_bindings(KeyBindings.overrides())


## What the note says after a write, given whether it landed.
##
## Static and pure so both sentences are assertable without a screen, a save file or a
## failing disk — which matters more than usual here, because the failure branch is
## unreachable in a test that is not deliberately breaking `RunConfig.save_path`, and an
## unreachable sentence is exactly the kind that ships misspelled.
##
## THE SUCCESS SENTENCE DOES NOT MENTION SAVING. "Set: M sound effects on or off" is what a
## player wants to read, and appending "— saved" to every capture would put a word about
## disks on a screen about keys, forever, to cover a case that essentially never happens.
## Silence is the confirmation; the failure is what needs words. That asymmetry is the whole
## design, and it is why this returns the caller's own sentence unchanged on success.
static func persisted_note(base: String, landed: bool) -> String:
	if landed:
		return base
	return base + "  (NOT saved — this key is set for now, but will be back to normal next time you play.)"
