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
##
## It also carries the Designer's Notebook now. That screen was constructed in
## exactly one place -- TitleScreen._open_notebook -- so the game's only account of
## itself was closed to the player from the first frame of a run onwards. This card
## is the obvious home: it is already full-screen, already lists the keyboard verbs,
## and is already the only way out of a run. See _open_notebook for the two things
## that makes tricky (process mode, and two screens answering Escape).

## What the card says under its heading. Set by Game before the screen enters the
## tree, because "The wave is waiting." was a constant and pause fires at any
## moment outside game-over -- so it was simply false between waves.
var _note_text: String = "The garden is holding still."
## The run's key bindings, passed in by Game so this screen never keeps its own
## copy of a list that could disagree with what the game actually handles.
var _keys: Array[Dictionary] = []

signal resume_requested
signal restart_requested
signal gate_requested
## Emitted by the fourth button and answered by this screen itself, so the table
## below stays uniform (every row is a name, a label and a signal) and Game does
## not have to know the notebook exists to let a player read it.
signal notebook_requested
## Same arrangement for the Keys screen: a reader-and-editor over this card, not a
## change to the run, so Game would only hand it straight back.
signal keys_requested

## The Designer's Notebook, while it covers this card. Null the rest of the time.
var _notebook: NotebookScreen = null
## The Keys screen, while it covers this card. Null the rest of the time.
var _keys_screen: KeyBindingScreen = null
## Every button on the card, so the whole row block can be made inert under an
## overlay without naming them one at a time. Filled by _build_buttons().
var _buttons: Array[Button] = []

## Same card geometry as the post-mortem, centred on the board rather than the
## window, so the two screens read as the same family and neither sits off to the
## side of the thing it is covering.
## Card geometry. The height is DERIVED, not written down.
##
## It was a hand-picked 380 against content ending at 370 -- ten pixels, which a
## fourth button (56) or a fourth key row (26) silently spends, putting text onto
## the backdrop over the live board while overlapping nothing, so no gate fires.
## This card derived where its content starts and hardcoded where it must stop,
## which is the same class of mistake as the absolute FIRST_BUTTON_Y it replaced.
##
## Not "the same geometry as the post-mortem" either, whatever this header used to
## claim: RunSummary.CARD is 640x456 and this one is not.
##
## The TOP is derived now as well, for the same reason one edge further up. It was
## a hand-picked 140, and with four buttons and five key rows the card footed at
## 642 in a 648-tall viewport -- six pixels of slack. That is what made
## KeyBindingScreen unreachable from a run: its own header said a fifth button
## "grows it past the bottom of the viewport", and it did, but only because the top
## was pinned where the height was not. Centred, the card absorbs half of every row
## or button it gains, and CARD_MIN_TOP is the floor where it stops being able to.
const CARD_WIDTH: float = 320.0
## Never higher than this, whatever the arithmetic says. A card taller than the
## viewport should hang off the bottom where the next thing added to it is visibly
## missing, rather than slide its heading off the top where the player cannot even
## tell which screen they are on.
const CARD_MIN_TOP: float = 24.0
const CARD_X: float = 288.0
const CARD_FOOT_PADDING: float = 24.0
## Gap between the last button and the key list. The list's own offset is derived
## from the button block rather than written down: a hand-picked 268.0 put the
## first key row at 408 under a GateButton ending at 412, which is the same
## absolute-offset mistake that once hid the note under ResumeButton. Deriving it
## means adding a fourth button cannot silently land on the list.
const KEY_LIST_GAP: float = 20.0
## 26, not 22. A Label does not render at its declared size: at font 13 these
## reported 23px against a declared 22 and each row overlapped the next by one
## pixel. Third time this trap has bitten in this file's neighbourhood -- the wave
## banner declared 62 for a 48px font that rendered 67 -- so the rule is to leave
## real headroom over the font, never to match it.
const KEY_ROW_HEIGHT: float = 26.0

## Entrance rise, borrowed outright from RunSummary rather than picked fresh:
## same offset, same duration, same curve as RISE_SECONDS / RISE_OFFSET there.
## This card is "shaped after RunSummary" for being the same kind of object —
## a card over a live board — and having it move differently on arrival would
## contradict the one sentence this file already uses to justify its own shape.
const RISE_SECONDS: float = 0.28
const RISE_OFFSET: float = 26.0

## True from the moment play_exit() starts until this node is freed. Stops a
## second Escape/P landing mid-fade from firing a second resume_requested,
## which would hand Game a screen it is already in the middle of resuming —
## see _input and play_exit.
var _closing: bool = false


## The card, sized to whatever it actually contains and placed from that size.
static func card_rect() -> Rect2:
	return Rect2(CARD_X, card_top(), CARD_WIDTH, card_height())


## Card-local y at which the last thing on the card ends.
static func content_height() -> float:
	return key_list_offset() + float(key_row_count()) * KEY_ROW_HEIGHT


## The whole card, content plus the paper below it.
static func card_height() -> float:
	return content_height() + CARD_FOOT_PADDING


## Top edge: centred on the viewport, floored at CARD_MIN_TOP. Derived, so a button
## or a key row added to the card costs it half the pixels it used to.
static func card_top() -> float:
	return maxf(CARD_MIN_TOP, (float(_viewport_height()) - card_height()) / 2.0)


## How many key rows the card will draw. Static so card_rect() can size for them
## before any instance exists; Game passes the same table it hands to build().
static func key_row_count() -> int:
	return Game.key_help().size()


## Top of the key list, in card-local coordinates.
static func key_list_offset() -> float:
	return (FIRST_BUTTON_OFFSET
		+ float(BUTTONS.size()) * BUTTON_SIZE.y
		+ float(BUTTONS.size() - 1) * BUTTON_GAP
		+ KEY_LIST_GAP)
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
##
## NotebookButton sits second because it is the one row here that does not end or
## interrupt anything -- it belongs beside Resume, above the two doors that throw
## the run away. Its label is the notebook's own heading rather than a promise the
## content does not keep: the five pages are about the drawings the game came from,
## so "Help" or "How to play" would be a lie told by a button.
##
## KeysButton sits third for the same reason and is directly under the legend it
## edits: the rows below this block say what each key does, and this is the button
## that moves one. Its label is the screen's own heading, same rule as the
## notebook's. It was reachable only from the title screen, which meant the player
## who had just pressed the wrong key mid-run had to abandon the run to move it.
const BUTTONS: Array[Dictionary] = [
	{"name": "ResumeButton", "text": "Back to the garden", "signal": "resume_requested"},
	{"name": "NotebookButton", "text": "Designer's Notebook", "signal": "notebook_requested"},
	{"name": "KeysButton", "text": "Keys", "signal": "keys_requested"},
	{"name": "RestartButton", "text": "Start over", "signal": "restart_requested"},
	{"name": "GateButton", "text": "Back to the gate", "signal": "gate_requested"},
]


## Built by Game so the note can describe the moment the run was actually paused.
static func build(note: String, keys: Array[Dictionary] = []) -> PauseScreen:
	var screen := PauseScreen.new()
	screen.name = "PauseScreen"
	if note != "":
		screen._note_text = note
	screen._keys = keys
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
	var rect: Rect2 = card_rect()
	card.position = rect.position
	card.size = rect.size
	card.add_theme_stylebox_override("panel", GardenTheme.paper_panel())
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)

	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "Paused"
	heading.position = Vector2(card_rect().position.x, card_rect().position.y + 30.0)
	heading.size = Vector2(card_rect().size.x, 44.0)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", GardenTheme.INK)
	add_child(heading)

	var note := Label.new()
	note.name = "Note"
	note.text = _note_text
	note.position = Vector2(card_rect().position.x, card_rect().position.y + 76.0)
	note.size = Vector2(card_rect().size.x, 24.0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.65))
	add_child(note)

	_build_buttons()
	_build_key_list()
	# Answered here rather than by Game: the notebook is a reader over this card,
	# not a change to the run, and nothing in Game would do anything with it except
	# hand it straight back.
	notebook_requested.connect(_open_notebook)
	keys_requested.connect(_open_keys)

	if GardenTheme.animations_enabled():
		_play_entrance()


func _build_buttons() -> void:
	var y: float = card_rect().position.y + FIRST_BUTTON_OFFSET
	var first: Button = null
	for spec: Dictionary in BUTTONS:
		var button := Button.new()
		button.name = String(spec["name"])
		button.text = String(spec["text"])
		button.position = Vector2(card_rect().position.x + (card_rect().size.x - BUTTON_SIZE.x) / 2.0, y)
		button.size = BUTTON_SIZE
		var which: String = String(spec["signal"])
		button.pressed.connect(func() -> void: emit_signal(which))
		add_child(button)
		_buttons.append(button)
		if first == null:
			first = button
		y += BUTTON_SIZE.y + BUTTON_GAP
	if first != null:
		first.grab_focus()


## The keys a run answers to, listed where a player goes when they want to know
## what their options are. Nothing here is authored: the rows come from Game.
func _build_key_list() -> void:
	if _keys.is_empty():
		return
	var y: float = card_rect().position.y + key_list_offset()
	for i: int in range(_keys.size()):
		var row: Dictionary = _keys[i]
		var label := Label.new()
		label.name = "KeyRow%d" % i
		label.text = _key_row_text(row)
		label.position = Vector2(card_rect().position.x + 28.0, y)
		label.size = Vector2(card_rect().size.x - 56.0, KEY_ROW_HEIGHT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.55))
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		add_child(label)
		y += KEY_ROW_HEIGHT


## Every card Control rises in, matching RunSummary._play_entrance's own loop
## exactly. Backdrop is excluded: it is not content, and fading a full-frame
## ColorRect in on the same curve would still cost a frame of a board that
## looks less dark than the pause it is announcing.
func _play_entrance() -> void:
	for child: Node in get_children():
		var control := child as Control
		if control == null or control.name == "Backdrop":
			continue
		control.position.y += RISE_OFFSET
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(control, "position:y", control.position.y - RISE_OFFSET, RISE_SECONDS)


## Fades the whole card out before Game frees it. Without this, resume used to
## free the layer on the same frame Escape fired — an entrance with a curve and
## an exit with none, which is only half a motion vocabulary for one screen.
##
## Awaited by Game.resume_run() so the layer is not freed out from under a
## still-fading Control. Skipped outright with animations off, same as every
## other gate in this file's family — headless pumps no frames, so an await on
## a tween that never advances would hang the caller forever.
func play_exit() -> void:
	if _closing:
		return
	_closing = true
	if not GardenTheme.animations_enabled():
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, RISE_SECONDS)
	await tween.finished


## Escape and P both close it, matching the two keys that open it. Handled here
## rather than in Game because Game is paused and its _unhandled_input does not
## run — which is exactly the bug a pause menu ships with when the close key is
## left on the paused node.
func _input(event: InputEvent) -> void:
	# Two `_input` handlers answering the same Escape. Left to resolve itself, one
	# keystroke closes the notebook AND resumes the run behind it, and the player
	# who put a page down is dropped onto a live board in the same frame.
	#
	# The engine does in fact resolve it in our favour: the notebook is a child of
	# this node, `_input` walks children before their parent, and NotebookScreen
	# ends its handler with set_input_as_handled(), which stops the propagation
	# before this method is ever called. This line makes that the stated rule rather
	# than a consequence of where the node happens to sit -- and it covers a key
	# tree order does not, because the notebook does not handle P at all and would
	# let it through to unpause the run it is sitting on top of.
	#
	# The guard only works because _close_notebook is deferred; see _open_notebook.
	# It asks about EITHER overlay: the keys screen is the second one, it answers
	# Escape the same way, and it does not look at P at all either.
	if overlay_open():
		return
	# Both shapes a verb can arrive in — see Game._unhandled_input for why the
	# InputEventKey-only narrowing that used to be here made the close key
	# unreachable from the devtools bridge.
	if not (event is InputEventKey or event is InputEventAction):
		return
	# The same action Game._unhandled_input opens this card with, so "the two keys
	# that open it" stays true after a rebinding instead of being a sentence about
	# Escape and P specifically.
	if event.is_action_pressed(KeyBindings.ACTION_PAUSE):
		# Already fading out — a second press here must not ask Game to resume a
		# screen it is already in the middle of resuming.
		if _closing:
			get_viewport().set_input_as_handled()
			return
		resume_requested.emit()
		get_viewport().set_input_as_handled()


## True while the notebook covers this card.
func notebook_open() -> bool:
	return _notebook != null and is_instance_valid(_notebook)


## True while the keys screen covers this card.
func keys_open() -> bool:
	return _keys_screen != null and is_instance_valid(_keys_screen)


## True while EITHER overlay covers this card. One shared guard rather than two,
## matching TitleScreen.overlay_open for the same reason: two independent "is mine
## open" checks would happily stack the keys screen on the notebook, leaving the
## notebook underneath still eating Escape.
func overlay_open() -> bool:
	return notebook_open() or keys_open()


## The Designer's Notebook, over the pause card.
##
## Built here rather than in Game because pause is the only surface a player can
## reach mid-run, and until now the notebook was constructed in exactly one place
## -- TitleScreen -- so the game's only explanation of itself was shut the moment
## a run started.
##
## PROCESS_MODE_ALWAYS is set outright rather than left to inherit. Inheriting
## would work today: this card is ALWAYS (see _ready) and a child inherits it. But
## that is a fact about who the parent happens to be, and the failure mode if it
## ever stops being true is silent -- a notebook frozen by the pause that owns it,
## with dead buttons and a page-turn tween that never advances. Stated here, it is
## also a property a test can read instead of a fact it has to infer.
##
## CONNECT_DEFERRED is what makes _input's `notebook_open()` guard mean anything.
## back_requested is emitted from inside NotebookScreen._input, so a direct
## connection would run _close_notebook and null `_notebook` *during* the very
## keystroke the guard has to refuse -- this screen would look at an already-closed
## notebook, see nothing in the way, and resume the run. Deferring it means the
## notebook is still open for the whole of that event's propagation and shuts at the
## end of the frame instead.
func _open_notebook() -> void:
	if overlay_open():
		return
	_notebook = NotebookScreen.new()
	_notebook.name = "Notebook"
	_notebook.process_mode = Node.PROCESS_MODE_ALWAYS
	_notebook.back_requested.connect(_close_notebook, CONNECT_DEFERRED)
	add_child(_notebook)
	_set_card_active(false)


## Back to the card, with the run still held. Nothing here touches
## `get_tree().paused`: closing a reader is not resuming a run, and the only two
## places that flag is written stay Game.pause_run and Game.resume_run.
##
## Deferred by its connection, so it can land after the notebook has already been
## freed by a resume that happened first -- hence the is_instance_valid guard
## rather than a bare queue_free.
func _close_notebook() -> void:
	if notebook_open():
		_notebook.queue_free()
	_notebook = null
	_set_card_active(true)
	var button: Button = get_node_or_null("NotebookButton") as Button
	if button != null:
		button.grab_focus()


## The Keys screen, over the pause card.
##
## This is the door the title screen's copy could not be: the player who wants to
## move a key is the one who just pressed the wrong one, and reaching the title
## screen from there meant throwing the run away first.
##
## Everything structural about the overlay -- its name, its process mode -- comes
## from KeyBindingScreen.build(), so this card and the title menu cannot end up
## opening two different versions of it.
##
## CONNECT_DEFERRED for the same reason _open_notebook uses it, and it is not
## optional here: back_requested is emitted from inside KeyBindingScreen._input,
## so a direct connection would null `_keys_screen` DURING the very Escape the
## guard in _input has to refuse -- this card would look, see nothing in the way,
## and resume the run out from under the screen the player just closed.
func _open_keys() -> void:
	if overlay_open():
		return
	_keys_screen = KeyBindingScreen.build()
	_keys_screen.back_requested.connect(_close_keys, CONNECT_DEFERRED)
	add_child(_keys_screen)
	_set_card_active(false)


## Back to the card, with the run still held -- and with the legend redrawn.
##
## The redraw is the part that is easy to leave out. This card's key rows are built
## once from the table Game handed it at construction, and until now nothing could
## change a binding while the card existed. Now the button directly above the
## legend can, so without this a player rebinds pause to K, closes the screen, and
## reads a row still telling them it is Esc -- on the one screen in the game whose
## whole job is to say what the keys are.
func _close_keys() -> void:
	if keys_open():
		_keys_screen.queue_free()
	_keys_screen = null
	_refresh_key_list()
	_set_card_active(true)
	var button: Button = get_node_or_null("KeysButton") as Button
	if button != null:
		button.grab_focus()


## Re-reads the legend from Game rather than from anything this screen kept. The
## row COUNT cannot change at runtime -- it is KeyBindings' run-scope table, which
## is a const -- so this rewrites the labels in place rather than re-laying out a
## card whose height is already derived from that same count.
func _refresh_key_list() -> void:
	_keys = Game.key_help()
	for i: int in range(_keys.size()):
		var label: Label = get_node_or_null("KeyRow%d" % i) as Label
		if label == null:
			continue
		label.text = _key_row_text(_keys[i])


## One legend row, written in exactly one place. Built and refreshed by two
## different methods, and two copies of this format string is how the redraw ends
## up subtly unlike the row it replaces.
static func _key_row_text(row: Dictionary) -> String:
	return "%s   %s" % [String(row["keys"]), String(row["does"])]


## Nothing under the notebook may still be live.
##
## The overlay's Backdrop is a MOUSE_FILTER_STOP ColorRect, so these buttons
## cannot be *pressed* through it -- but focus is a separate channel, and Tab or
## an arrow key would walk straight onto "Start over" behind the paper. The mouse
## filter goes too: at 0.88 alpha a button still tracking the cursor underneath
## lights up in its hover colour and that glow shows through. Same treatment, for
## the same two reasons, that TitleScreen._set_menu_active gives its own menu.
func _set_card_active(active: bool) -> void:
	var mode: Control.FocusMode = Control.FOCUS_ALL if active else Control.FOCUS_NONE
	var filter: Control.MouseFilter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	for button: Button in _buttons:
		button.focus_mode = mode
		button.mouse_filter = filter


## Static, because card_top() is: the card's own placement now depends on how tall
## the window is, and card_rect() has to answer that before any instance exists.
static func _viewport_width() -> int:
	return ProjectSettings.get_setting("display/window/size/viewport_width", 1152)


static func _viewport_height() -> int:
	return ProjectSettings.get_setting("display/window/size/viewport_height", 648)
