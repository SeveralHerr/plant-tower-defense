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
## And the Options screen, the third of the same kind. The switches it flips are
## owned by RunConfig, Sfx and Music, none of which this card or Game has to know
## about -- so this signal is answered here too.
signal options_requested

## The Designer's Notebook, while it covers this card. Null the rest of the time.
var _notebook: NotebookScreen = null
## The Keys screen, while it covers this card. Null the rest of the time.
var _keys_screen: KeyBindingScreen = null
## The Options screen, while it covers this card. Null the rest of the time.
var _options_screen: OptionsScreen = null
# There is deliberately NO `_buttons` array here any more. It existed for exactly one
# reader -- `_set_card_active`, this card's copy of the eight lines that are now
# `OverlayScreen.set_controls_active` -- and a hand-kept list of "every button on the
# card" is a thing a seventh button gets left out of. What COVERS this card derives
# the set from the tree instead (`OverlayScreen.interactive_under`), so a row added to
# `BUTTONS` is inert under an overlay without anyone editing a second place.
## The click-eating layer, held rather than re-found by name:
## `_apply_viewport_layout()` re-sizes it on every window change, and a
## `get_node("Backdrop")` per resize would be a lookup that can silently miss.
var _backdrop: ColorRect = null

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
##
## 360, not 320. The legend is the widest thing this card holds and its text is
## not authored here -- it is KeyBindings.ACTIONS, shared with the Keys screen and
## the Options screen. At 320 the longest row drew 265px into a 264px box: one
## pixel of budget, which is the same "hand-picked number with no slack" this
## header spends three paragraphs complaining about vertically. Widened rather
## than shortening the phrase, because the phrase is the only thing on any of the
## three screens that says WHICH bars the C key changes, and a 40px card is a
## cheaper thing to spend than that sentence. See KEY_ROW_MAX_WIDTH.
##
## 440, not 360, for the SECOND half of the same row -- and this half is not ours
## to author at all. A legend row is `"%s   %s" % [keys, does]`, and since the Keys
## screen landed the player picks the first `%s`: `capture()` binds whatever keycode
## arrives. The paragraph above measured the `does` phrases and left the key column
## at whatever `Esc` and `P` happen to cost. Sweeping every code
## `OS.get_keycode_string()` will name gives "On-screen keyboard", and that beside
## the colourblind phrase drew **384px into a 304px box** -- 80px of legend onto the
## dimmed backdrop over the live board, which is the exact failure this header
## already describes happening once.
##
## **And 440 was the last hand-picked width.** It was the worst case charged to every
## player: sized for a key almost nobody binds, on a card that is 31% of the viewport
## for the shipped keys and 38% for everyone. Three widths picked by hand, each one
## correct until the thing it measured changed, is the same story `card_height()`
## stopped telling two constants above -- so `card_width()` now derives itself from
## its widest row the way the height derives itself from its row count, and the
## constant below is only a FLOOR (the button block is 248 wide and the card cannot
## be narrower than what it holds).
##
## Measured, not estimated: `_measure()` builds a detached Label carrying the same
## font-size override the rows carry, and this project sets no custom theme, so an
## off-tree Label resolves the identical font. Asserted rather than assumed --
## test_the_cards_own_measurement_agrees_with_the_labels_it_builds compares it
## against `_T.text_width` on the real rows.
const CARD_MIN_WIDTH: float = BUTTON_SIZE.x + KEY_ROW_INSET * 2.0

## Between the key column and the phrase column. Named because the derived width is
## a sum and an unnamed gap inside a sum is the term nobody can find later.
const KEY_COL_GAP: float = 16.0
## The rows' font size, hoisted out of _build_key_list so the static measurement and
## the built Label cannot drift onto different fonts.
const KEY_ROW_FONT_SIZE: int = 13
## Never higher than this, whatever the arithmetic says. A card taller than the
## viewport should hang off the bottom where the next thing added to it is visibly
## missing, rather than slide its heading off the top where the player cannot even
## tell which screen they are on.
const CARD_MIN_TOP: float = 24.0
## What this card is centred ON -- the board, not the window (the window's own
## centre is 576). It is RunSummary.CARD's centre too: that card spans 128..768,
## and the two are the same kind of object over the same board, so they share a
## spine.
##
## CARD_X is derived from it for the same reason card_top() is derived from
## card_height(): the old bare 288.0 encoded this centre without naming it, so
## widening the card by 40px would have slid it 40px right instead of 20px each
## way, and nothing would have said why.
const CARD_CENTRE_X: float = 448.0
## Left edge, derived from the derived width so a card that grows stays centred on
## CARD_CENTRE_X rather than growing to the right. A function now rather than a
## const, because what it is derived FROM is measured at runtime.
static func card_x() -> float:
	return CARD_CENTRE_X - card_width() / 2.0
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
## How far a legend row is held off each edge of the paper. Named rather than the
## bare 28.0 / 56.0 pair it used to be written as, because the budget below is
## derived from it and a test measures the longest row against that budget.
const KEY_ROW_INSET: float = 28.0
## What one legend row's TEXT has to fit inside, measured through the font rather
## than trusted to the Label's box.
##
## Asserted the way NotebookScreen.SUBHEAD_MAX_WIDTH is, and for the same reason:
## the row text is not authored here. It comes from KeyBindings.ACTIONS, which
## also feeds the Keys screen and the Options screen, so the phrase that fits
## those two can quietly stop fitting this card -- and did. "C   colourblind-safe
## health and threat bars" drew 326px in a 264px box and put ~34px of legend onto
## the dimmed backdrop over the live board.
##
## Nothing caught it, twice over. The card's own layout test checks vertical fit
## and pairwise overlap only, and `clip_text` makes `Label.get_minimum_size()`
## report the ~1px clip stub instead of the text -- so the obvious width assertion
## passes unconditionally on exactly the labels that need it. Measure with
## `_T.text_width`.
## What ONE legend row's two columns together have to fit inside. Derived from the
## card, which is now derived from these columns -- the loop is deliberate and it
## terminates: card_width() takes the max of the floor and what the columns need, so
## this reads back the answer rather than participating in computing it.
static func key_row_max_width() -> float:
	return card_width() - KEY_ROW_INSET * 2.0

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


## Text width through the same font a legend row draws in.
##
## Shared now: `GardenTheme.measure()` carries the reasoning and the caveat, and
## three screens plus four tests depend on the same answer. Kept as a one-line
## forwarder rather than inlined at the call sites because the font size is this
## screen's property, not the caller's, and because
## test_the_cards_own_measurement_agrees_with_the_labels_it_builds names it.
static func _measure(text: String) -> float:
	return GardenTheme.measure(text, KEY_ROW_FONT_SIZE)


## The key column: as wide as the widest key CURRENTLY bound.
##
## Currently, not "as wide as any key could ever be" -- that is the whole point of
## deriving it. A player on the shipped keys gets a 46px column (`Esc  ·  P`); one
## who binds the longest name the engine has gets 127px and a card 81px wider, and
## nobody pays for a binding they did not make.
static func key_column_width() -> float:
	var widest: float = 0.0
	for row: Dictionary in Game.key_help():
		widest = maxf(widest, _measure(String(row["keys"])))
	return widest


## The phrase column: as wide as the widest `does` phrase.
##
## Authored by KeyBindings.ACTIONS and shared with two other screens, so it changes
## when a verb is renamed and nothing here has to be told.
static func does_column_width() -> float:
	var widest: float = 0.0
	for row: Dictionary in Game.key_help():
		widest = maxf(widest, _measure(String(row["does"])))
	return widest


## What the card has to be to hold its widest legend row, floored at what the button
## block needs. The height's counterpart, and written after three hand-picked widths
## in a row each went stale the moment the thing they measured changed.
static func card_width() -> float:
	var legend: float = (key_column_width() + KEY_COL_GAP + does_column_width()
		+ KEY_ROW_INSET * 2.0)
	return ceilf(maxf(CARD_MIN_WIDTH, legend))


## The card, sized to whatever it actually contains and placed from that size.
static func card_rect() -> Rect2:
	return Rect2(card_x(), card_top(), card_width(), card_height())


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
##
## Counted in ROWS, not in buttons: Keys and Options share one (see BUTTONS), and
## `BUTTONS.size()` here would size the card for a row that is not drawn and push
## the legend into the paper below it.
static func key_list_offset() -> float:
	return (FIRST_BUTTON_OFFSET
		+ float(button_row_count()) * BUTTON_SIZE.y
		+ float(button_row_count() - 1) * BUTTON_GAP
		+ KEY_LIST_GAP)


## How many ROWS the button block occupies. Every entry in BUTTONS is a row except
## the ones marked `share_row`, which sit beside the entry above them.
static func button_row_count() -> int:
	var rows: int = 0
	for spec: Dictionary in BUTTONS:
		if not bool(spec.get("share_row", false)):
			rows += 1
	return rows


## Where each button in BUTTONS goes, in viewport coordinates and in table order.
##
## Static and separate from `_build_buttons` so the geometry is assertable without
## a paused game, and so the height the card sizes itself to and the boxes the
## buttons are actually given come from the same arithmetic rather than from two
## copies of it.
##
## A `share_row` entry does two things: it takes the right half of the row above,
## and it SHRINKS the button already there to the left half. Written that way round
## because the alternative is a lookahead in the loop that places the first one,
## and a pair whose left half was sized before its partner was known is exactly how
## two buttons end up overlapping by BUTTON_PAIR_GAP.
static func button_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var card: Rect2 = card_rect()
	var left: float = card.position.x + (card.size.x - BUTTON_SIZE.x) / 2.0
	var half: float = (BUTTON_SIZE.x - BUTTON_PAIR_GAP) / 2.0
	var y: float = card.position.y + FIRST_BUTTON_OFFSET
	for i: int in range(BUTTONS.size()):
		if i > 0 and bool(BUTTONS[i].get("share_row", false)):
			var partner: Rect2 = out[i - 1]
			out[i - 1] = Rect2(partner.position, Vector2(half, BUTTON_SIZE.y))
			out.append(Rect2(Vector2(left + half + BUTTON_PAIR_GAP, partner.position.y),
				Vector2(half, BUTTON_SIZE.y)))
			continue
		out.append(Rect2(Vector2(left, y), BUTTON_SIZE))
		y += BUTTON_SIZE.y + BUTTON_GAP
	return out
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
## Horizontal gap between the two halves of a shared row. See BUTTONS.
const BUTTON_PAIR_GAP: float = 8.0

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
##
## OptionsButton sits BESIDE Keys, sharing its row, and still above the two doors
## that throw the run away. The moment a player most wants the colourblind bars is
## the moment they cannot read the ones on screen, and that moment is mid-run -- so
## a screen reachable only from the title was reachable only by abandoning the run
## first, the same argument that gave Keys its second door.
##
## It shares rather than adding a sixth row because the card had run out of height
## to give. Six full-width rows made it 614 tall in a 648 viewport: it still FIT,
## but card_top() hit its CARD_MIN_TOP floor, so the card stopped being centred and
## the next thing added to it would have hung off the bottom. Two half-width
## buttons in one row is also the truer shape -- these two are the same kind of
## thing, a door onto a screen, and neither ends the run.
const BUTTONS: Array[Dictionary] = [
	{"name": "ResumeButton", "text": "Back to the garden", "signal": "resume_requested"},
	{"name": "NotebookButton", "text": "Designer's Notebook", "signal": "notebook_requested"},
	{"name": "KeysButton", "text": "Keys", "signal": "keys_requested"},
	{"name": "OptionsButton", "text": "Options", "signal": "options_requested", "share_row": true},
	{"name": "RestartButton", "text": "Start over", "signal": "restart_requested"},
	{"name": "GateButton", "text": "Back to the gate", "signal": "gate_requested"},
]


## Which page kind the Notebook door from a PAUSE opens on, asked by kind rather than
## by index because PAGES is reordered by whoever adds a page.
##
## THE ANSWER TO plant-tower-defense-5s99, WRITTEN DOWN SO NOBODY RE-ASKS IT. That bead
## proposed the door open on the SELECTED plant's page instead — `NotebookScreen.
## page_for_plant()` and `Game.selected_placed` both exist, and `Game.pause_run` already
## hands `build()` two arguments, so a third was nearly free. It stays the legend, and
## the reasons are in descending order of weight:
##
## 1. THE PLANT PAGE IS OFTEN NOT A GAMEPLAY PAGE. `page_for_plant(&"corn_cobbler")` is
##    PAGES[0] and `page_for_plant(&"chomp_flower")` is PAGES[3] — both KIND_DRAWING,
##    so `go_to()` shows a photograph of a pencil sketch and hides the spec card
##    entirely (`_spec.visible = kind == KIND_PLANT`). The bead's own worked example is
##    a player who "selects a Chomp, wonders what it does"; that door would answer with
##    "Named in the corner, drawn with a jaw full of triangular teeth". Corn Cobbler is
##    worse — it is the free starter plant, so it is the plant a confused player is most
##    likely to have selected, and its page is the portrait the whole game began from.
##    Six of the eight plants get a spec; the two that do not are the two everybody has.
##
## 2. THE QUESTION IS ALREADY ANSWERED, LIVE, WITHOUT PAUSING. `Hud._refresh_selection`
##    fills SelectionBox the instant a plant is clicked, with that plant's CURRENT
##    numbers — damage per volley, fire interval, chew progress, seconds to the next
##    yield, pests being slowed. The notebook's spec card is a static catalogue entry.
##    Routing the pause door at it trades a live answer for a worse historical one.
##
## 3. THE SELECTION IS SET BY PLACING, NOT ONLY BY ASKING. `Game.place_plant` ends in
##    `_select(plant)`, so putting a Sunflower in a back corner and never clicking again
##    leaves it selected for the rest of the run. The bead named the staleness objection
##    and it is worse than it looks: the selection is not "the last thing you asked
##    about", it is "the last thing you did".
##
## 4. BEING WRONG COSTS 2 TO 7 PRESSES, NOT ONE. The bead said to check this rather than
##    assume it. The pager is one page per press in each direction (PrevButton/NextButton
##    and ACTION_PAGE_PREV/NEXT — there is no jump), and it wraps, so the shortest walk
##    from a plant page to the legend at index 12 of 14 is: Corn 2, Chomp 5, Sunflower 7,
##    Sundew 6, Dandelion 5, Mint 4, Nettle 3, Aloe 2. Median 5.
##
## 5. THE STALENESS RULES ON OFFER CANNOT BE WRITTEN ON THE DOOR. Option (c) — "only when
##    the plant was selected since this wave started" — is a new field in Game and a rule
##    the player is never told, which makes two identical-looking presses of one button
##    go to two different places for an invisible reason. That is the opposite of the
##    condition this change was made under.
##
## What DID change is the half that was genuinely missing: the door's destination is now
## written on the door. See notebook_door_tooltip().
static func notebook_door_kind() -> String:
	return NotebookScreen.KIND_LEGEND


## What the Notebook door promises, DERIVED from the notebook rather than written here.
##
## The gap this closes is real and predates the bead above: pressing "Designer's
## Notebook" from a pause opens the book at 13 / 14, and pressing the identically
## labelled button on the title screen opens it at 1 / 14. Nothing said so. A player who
## meets the second door first has every reason to read the first one as a book that
## lost its place, and the pager label showing "13 / 14" is what that looks like.
##
## Every part of the sentence comes from NotebookScreen — the index from
## `page_for_kind`, the total from `PAGES.size()`, the subject from the same
## `PANE_LABELS` row the page itself draws as its left-pane heading. So the promise on
## this button and the page the door actually opens cannot drift apart, and adding a
## page above the legend re-words the tooltip without anybody editing it.
##
## A tooltip and not the label: BUTTON_SIZE.x is 248 and a Button's minimum width is its
## text, so a longer label would silently widen the button past the rect `button_rects()`
## placed it in — which is the exact failure three paragraphs of this file's header are
## already about. `tooltip_text` takes no part in minimum size.
static func notebook_door_tooltip() -> String:
	var kind: String = notebook_door_kind()
	var at: int = maxi(0, NotebookScreen.page_for_kind(kind))
	return "Opens at page %d of %d — %s." % [
		at + 1, NotebookScreen.PAGES.size(), NotebookScreen.pane_label_for(kind),
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
	# The LIVE canvas, not the design size this used to read out of ProjectSettings
	# (plant-tower-defense-nrup). The line below is why it matters more here than
	# anywhere else in the game.
	size = _live_viewport_size()
	theme = GardenTheme.build()

	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color(GardenTheme.INK, BACKDROP_ALPHA)
	_backdrop.position = Vector2.ZERO
	_backdrop.size = size
	# Eats clicks, so the board and the side panel underneath cannot be played
	# through a pause. That makes its SIZE a correctness property and not a
	# cosmetic one: sized from the design width on a 1536-unit-wide canvas it
	# stopped 384px short of the right edge, and that strip was live, clickable
	# board over a paused run — a plant could be placed through the pause menu.
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

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
	options_requested.connect(_open_options)

	if GardenTheme.animations_enabled():
		_play_entrance()

	# CHECKED, not assumed: this card is `build()` + `add_child()` on pause and
	# freed on resume (Game.pause_run / Game.resume_run), so it is rebuilt every
	# time it is shown. That is still not enough. THIS IS THE SURFACE MOST LIKELY TO BE
	# LIVE DURING A RESIZE in the whole game: it holds the run still, which is
	# exactly what a player does before alt-tabbing, maximising or dragging the
	# window. And unlike every other screen here its stale layer is not cosmetic —
	# see the Backdrop's mouse_filter above.
	#
	# It works while paused because signal emission is not gated by
	# `SceneTree.paused`; only _process and input are, and this node is
	# PROCESS_MODE_ALWAYS in any case.
	var vp: Viewport = get_viewport()
	if vp != null and not vp.size_changed.is_connected(_apply_viewport_layout):
		vp.size_changed.connect(_apply_viewport_layout)


## The click-eating layer, re-derived. Deliberately NOT the card.
##
## The card is a fixed-size composition placed by the static `card_rect()`, and its
## heading, note, buttons and key rows are all placed against that one rect — so
## moving it means re-running the builder, which would take focus out from under
## the player mid-pause. It stays where the pause opened it. The Backdrop does not
## get that latitude: a strip of window it does not cover is a strip of live board.
func _apply_viewport_layout() -> void:
	# `size_changed` outlives the build — the card fades out over an unpause and a
	# resize can land inside that fade.
	if _backdrop == null or not is_instance_valid(_backdrop):
		return
	size = _live_viewport_size()
	_backdrop.position = Vector2.ZERO
	_backdrop.size = size


func _build_buttons() -> void:
	# Placed from button_rects(), not from a second run of the same arithmetic: the
	# card's own height is derived from that function's row count, and two copies of
	# the layout is how a button ends up on a card sized for a different one.
	var rects: Array[Rect2] = button_rects()
	var first: Button = null
	for i: int in range(BUTTONS.size()):
		var spec: Dictionary = BUTTONS[i]
		var button := Button.new()
		button.name = String(spec["name"])
		button.text = String(spec["text"])
		button.position = rects[i].position
		button.size = rects[i].size
		var which: String = String(spec["signal"])
		button.pressed.connect(func() -> void: emit_signal(which))
		# NOT a fourth cell in BUTTONS, and the reason is mechanical: this string is
		# derived from NotebookScreen at runtime and BUTTONS is a const, which can hold
		# only literals. Keyed off the SIGNAL rather than the node name so a renamed
		# node cannot silently drop the one promise this card makes about where a door
		# goes.
		if which == "notebook_requested":
			button.tooltip_text = notebook_door_tooltip()
		add_child(button)
		if first == null:
			first = button
	if first != null:
		first.grab_focus()


## The keys a run answers to, listed where a player goes when they want to know
## what their options are. Nothing here is authored: the rows come from Game.
func _build_key_list() -> void:
	if _keys.is_empty():
		return
	var y: float = card_rect().position.y + key_list_offset()
	# Hoisted out of the row loop: they are loop-invariant, and the alignment below
	# is derived from them, so recomputing them per row would be three chances for the
	# label's box and the label's alignment to be reasoning about different columns.
	var row_left: float = card_rect().position.x + KEY_ROW_INSET
	var key_col: float = key_column_width()
	# NOT the bare HORIZONTAL_ALIGNMENT_RIGHT this used to write down
	# (plant-tower-defense-22a). The rule -- key text flush against the gutter it shares
	# with its phrase -- now lives in ONE place for both screens that show these keys,
	# and it is derived from where the columns actually are. The comment three lines
	# below this one used to claim the keys lined up "the way they already do on the
	# Keys screen", which was false: that screen centred them. Routing both screens
	# through `KeyBindingScreen.key_alignment` is what makes the sentence true, and
	# what stops it going quietly false again.
	var key_align: int = KeyBindingScreen.key_alignment(row_left,
		row_left + key_col + KEY_COL_GAP)
	for i: int in range(_keys.size()):
		var row: Dictionary = _keys[i]
		# TWO Labels, not one string. As `"%s   %s"` the key and the phrase shared a
		# width budget, so the long one ate the short one -- which is what turned a
		# player binding a long key name into a phrase running off the card, and what
		# made the card's width a function of the worst case of both halves at once.
		# Split, each column is bounded by its own content, and the keys line up
		# vertically the way they already do on the Keys screen.
		var key_label := Label.new()
		key_label.name = "KeyRow%d" % i
		key_label.text = String(row["keys"])
		# Flush against the gutter: the two columns read as one pair, and a ragged edge
		# on the key column would put a variable gap in the middle of every row. Which
		# EDGE is flush follows from the column order and is not decided here.
		key_label.horizontal_alignment = key_align
		var label := Label.new()
		label.name = "KeyRowDoes%d" % i
		label.text = String(row["does"])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		# ORDER MATTERS, and this is the bug that put a legend row on the backdrop.
		#
		# `Control.set_size` clamps to `get_combined_minimum_size()`, and a Label's
		# minimum width is its whole text UNLESS clip_text or a trimming overrun
		# behaviour is already set -- only then does it collapse to the ~1px stub.
		# Written the other way round, `size` was assigned while the label was still
		# unclipped AND still on the theme's default font size (16, not 13), so the
		# assigned 264 lost to a 326px minimum measured at the wrong size, and the
		# later font_size/clip_text overrides lowered the minimum without ever
		# shrinking the box back. Set the three things that decide the minimum
		# first, and the assigned width is the one that survives.
		for pair: Array in [[key_label, row_left, key_col],
				[label, row_left + key_col + KEY_COL_GAP,
					key_row_max_width() - key_col - KEY_COL_GAP]]:
			var text_label: Label = pair[0]
			text_label.add_theme_font_size_override("font_size", KEY_ROW_FONT_SIZE)
			text_label.clip_text = true
			text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			text_label.position = Vector2(float(pair[1]), y)
			text_label.size = Vector2(float(pair[2]), KEY_ROW_HEIGHT)
			text_label.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.55))
			add_child(text_label)
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
	# It asks about ANY overlay: the keys screen and the options screen are the
	# second and third, both answer Escape the same way, and neither looks at P at
	# all either.
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


## True while the options screen covers this card.
func options_open() -> bool:
	return _options_screen != null and is_instance_valid(_options_screen)


## Whichever overlay currently covers this card, or null when none does.
##
## The same shape as `overlay_open()` returning the NODE instead of a bool, and the
## reason it exists is that a caller who wants the screen had three different ways
## to get it and no uniform one: `KeyBindingScreen.NODE_NAME` and
## `OptionsScreen.NODE_NAME` off this card, and `_notebook` — a private field — for
## the third. A sweep over "every overlay" had to spell all three out, and a fourth
## door would have been silently uncovered by it rather than picked up.
##
## Order is the order the fields are declared and does not matter: `_open_notebook`,
## `_open_keys` and `_open_options` each refuse while `overlay_open()`, so at most
## one of the three is ever live. That is the invariant this method reads, not one
## it enforces.
func open_overlay() -> OverlayScreen:
	if notebook_open():
		return _notebook
	if keys_open():
		return _keys_screen
	if options_open():
		return _options_screen
	return null


## True while ANY overlay covers this card. One shared guard rather than three,
## matching TitleScreen.overlay_open for the same reason: three independent "is
## mine open" checks would happily stack the options screen on the keys screen,
## leaving the one underneath still eating Escape.
##
## Asks `open_overlay()` rather than re-ORing the three predicates, so the bool and
## the node can never disagree about whether something is up.
func overlay_open() -> bool:
	return open_overlay() != null


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
	# NotebookScreen._init already assigns this; kept here so the three doors on this
	# card read the same way (KeyBindingScreen.build() and OptionsScreen.build() name
	# theirs from their own NODE_NAME too) and so the string is never spelled out at
	# a construction site again.
	_notebook.name = NotebookScreen.NODE_NAME
	# Opened FROM A PAUSED RUN, so it opens on the page about the board rather than on the
	# pencil drawings. Somebody who stopped a wave to look something up is looking at a
	# mark they do not recognise; somebody browsing from the title screen is not looking at
	# a board at all. The legend was page 10 of 10 and the title screen's own header calls
	# this notebook "a click further away" on purpose — that reasoning was about a
	# scrapbook, and it should not also gate the page explaining what the marks mean.
	#
	# Asked by kind, never by index: PAGES gets reordered by whoever adds a page, and a
	# literal 9 here would silently open on whatever moved into that slot. (It is 12 of
	# 14 now, not 9 of 10 — which is the sentence above earning its keep twice over.)
	# maxi because page_for_kind answers -1 for a kind with no page, and this door would
	# rather open the front of the book than refuse to open.
	#
	# And it stays the legend WHATEVER IS SELECTED ON THE BOARD — that was asked, weighed
	# and declined; the five reasons are on notebook_door_kind(), which is also the only
	# place this kind is named so the button's tooltip and this line cannot disagree.
	_notebook.open_at = maxi(0, NotebookScreen.page_for_kind(notebook_door_kind()))
	_notebook.process_mode = Node.PROCESS_MODE_ALWAYS
	_notebook.back_requested.connect(_close_notebook, CONNECT_DEFERRED)
	# No `_set_card_active(false)` here, and none in `_close_notebook` either: the
	# overlay makes this card inert on `add_child` and hands it back on `close()`.
	# See OverlayScreen.hold_inert — an opener that has to remember is an opener that
	# can forget, and one did (plant-tower-defense-csrc).
	add_child(_notebook)


## Back to the card, with the run still held. Nothing here touches
## `get_tree().paused`: closing a reader is not resuming a run, and the only two
## places that flag is written stay Game.pause_run and Game.resume_run.
##
## Deferred by its connection, so it can land after the notebook has already been
## freed by a resume that happened first -- hence the `notebook_open()` guard, which
## is an is_instance_valid check, rather than a bare `close()` on a dead reference.
func _close_notebook() -> void:
	# `close()` rather than `queue_free()`, and the difference is the line below it:
	# the overlay hands the card back synchronously here, so `grab_focus()` lands on a
	# button that is focusable again. `queue_free()` defers to the end of the frame,
	# which would put the restore AFTER the grab and make it an error, not a focus.
	if notebook_open():
		_notebook.close()
	_notebook = null
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
	# The card goes inert on add_child and comes back on close(), by the overlay
	# rather than by this door — see _open_notebook.
	add_child(_keys_screen)


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
		_keys_screen.close()
	_keys_screen = null
	_refresh_key_list()
	var button: Button = get_node_or_null("KeysButton") as Button
	if button != null:
		button.grab_focus()


## The Options screen, over the pause card. The third door of the same shape, and
## the one whose absence hurt most: the switch a player reaches for mid-run is the
## colourblind ramp, and wanting it is caused by not being able to read the board
## they are currently playing on.
##
## Built through OptionsScreen.build() for the reason KeyBindingScreen.build()
## exists -- the title menu opens the same overlay, and two hand-rolled
## constructions is how one of them ends up without PROCESS_MODE_ALWAYS and freezes
## under the pause it is sitting on.
##
## CONNECT_DEFERRED, exactly as _open_keys and _open_notebook use it, and it is not
## optional: OptionsScreen emits back_requested from inside its own _input, so a
## direct connection would null `_options_screen` DURING the very Escape the guard
## in _input has to refuse -- this card would look, see nothing in the way, and
## resume the run out from under the screen the player just closed.
func _open_options() -> void:
	if overlay_open():
		return
	_options_screen = OptionsScreen.build()
	_options_screen.back_requested.connect(_close_options, CONNECT_DEFERRED)
	# The card goes inert on add_child and comes back on close(), by the overlay
	# rather than by this door — see _open_notebook.
	add_child(_options_screen)


## Back to the card, with the run still held. The legend is redrawn for the same
## reason _close_keys redraws it: this screen shows the key beside each switch, and
## while it cannot move one, it sits over a card whose rows are built once and the
## cheap redraw is what keeps that from being a fact anyone has to remember.
func _close_options() -> void:
	if options_open():
		_options_screen.close()
	_options_screen = null
	_refresh_key_list()
	var button: Button = get_node_or_null("OptionsButton") as Button
	if button != null:
		button.grab_focus()


## Re-reads the legend from Game rather than from anything this screen kept. The
## row COUNT cannot change at runtime -- it is KeyBindings' run-scope table, which
## is a const -- so this rewrites the labels in place rather than re-laying out a
## card whose height is already derived from that same count.
func _refresh_key_list() -> void:
	_keys = Game.key_help()
	# The COLUMN WIDTH can move here, which the text-only refresh this replaced could
	# not account for. The Keys screen opens over this card, so a player can rebind
	# `P` to something far wider and close it, and the column built for `Esc  ·  P`
	# would clip the new name.
	#
	# The card itself is NOT resized: it is already on screen with buttons placed
	# against its edges, and sliding all of that sideways under the player to answer a
	# rebinding is a worse answer than the one below. So the columns are re-split
	# inside the width the card already has, and the key column is clamped so that the
	# PHRASE column never drops below what the widest phrase needs.
	#
	# That ordering is the decision: if something has to be truncated it is the key,
	# not the phrase. The phrase is ours, is the same on every screen, and is the half
	# that says what the row is FOR; the key is the player's, they just typed it, and
	# the Keys screen one layer up is showing it in full. The truncation is also
	# transient -- the next pause rebuilds the card at a width that fits.
	# Measured off the Card NODE, not off key_row_max_width().
	#
	# That distinction is the whole of this function and it cost a live check to
	# find. `key_row_max_width()` derives from `card_width()`, which re-measures the
	# CURRENT bindings -- so the moment the player rebinds, it answers with the width
	# the card WOULD be if it were rebuilt, while the card on screen is still the one
	# built for the old bindings. Laying the columns out against that number put a
	# 247px phrase at x+143 on a 365px card: 52px onto the backdrop, which is the
	# exact failure the header's own three paragraphs are about, reintroduced by the
	# fix for it.
	#
	# The card is the ground truth for as long as it exists. The next pause rebuilds
	# it at the derived width.
	var card: Control = get_node_or_null("Card") as Control
	var room: float = (card.size.x if card != null else card_width()) - KEY_ROW_INSET * 2.0
	var key_col: float = minf(key_column_width(), room - KEY_COL_GAP - does_column_width())
	key_col = maxf(key_col, 0.0)
	for i: int in range(_keys.size()):
		var key_label: Label = get_node_or_null("KeyRow%d" % i) as Label
		var does_label: Label = get_node_or_null("KeyRowDoes%d" % i) as Label
		if key_label == null or does_label == null:
			continue
		key_label.text = String(_keys[i]["keys"])
		does_label.text = String(_keys[i]["does"])
		key_label.size.x = key_col
		does_label.position.x = key_label.position.x + key_col + KEY_COL_GAP
		does_label.size.x = room - key_col - KEY_COL_GAP


## The DESIGN canvas — the size this card was composed at, which is what these two
## have always returned. The name said "the viewport" and this pair was the fourth
## copy of `Hud.get_viewport_width()` in the game (plant-tower-defense-nrup); the
## implementation now lives once, in `ScreenMetrics`, and the doc says which of the
## two questions it answers.
##
## Static, because card_top() is: the card's placement depends on how tall the
## canvas is, and card_rect() has to answer that before any instance exists — which
## is also why it cannot be live. A static function has no `get_viewport()`.
##
## Design is the right answer here anyway: the card is a fixed-size composition
## (`card_width()` is derived from its own legend columns, `card_height()` from its
## own row count) and `CARD_MIN_TOP` is a floor authored against 648. What must
## follow the window is the layer that COVERS it — see `_apply_viewport_layout()`.
static func _viewport_width() -> int:
	return ScreenMetrics.design_width()


static func _viewport_height() -> int:
	return ScreenMetrics.design_height()


## The live canvas this card has to cover. Separate from the pair above because
## they are separate questions — see ScreenMetrics.
func _live_viewport_size() -> Vector2:
	return ScreenMetrics.live_size(self)
