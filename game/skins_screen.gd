class_name SkinsScreen
extends OverlayScreen

## Where a player puts on a skin they already OWN, for a plant or a pest
## (plant-tower-defense-ncfv). Reads and writes entirely through
## `RunConfig.selected_skin()` / `set_skin()` and the rule table in `game/skins.gd` —
## this screen has no state of its own beyond which page it is showing.
##
## ## Why this screen survived the Shop
##
## The Shop (`ShopScreen`, off the title menu) is where petals become skins. This is
## the door off the HUD, mid-run, and it is deliberately NOT the same door: buying is
## a decision made between runs against a balance, and equipping is a decision made
## while looking at the garden the change lands on. Folding the two together would
## have put a price and a purchase confirmation on a paused board, and would have made
## "change what my Sunflowers look like" cost a trip back to the title screen.
##
## So this screen only ever offers what is already owned, and never a price. A player
## who wants more is told where they come from, once, in `NOTE_TEXT`.
##
## ## Why a pager and not a scroll list
##
## Nothing else in this game's UI uses a `ScrollContainer` — every overlay here
## (`KeyBindingScreen`, `OptionsScreen`, `NotebookScreen`) hand-places absolute-
## position rows within a row budget it derives from the viewport, and
## `OverlayScreen.rows_that_fit` exists precisely to answer "how many of these fit".
## Nine plants plus (today) five pest species is fourteen rows, more than the seven
## a panel this size holds without crowding the footer — so rather than introduce a
## Container-based layout this codebase has never exercised, this screen pages
## through the same fixed row grammar everything else uses, the way the Designer's
## Notebook already turns pages for the same reason. `page_capacity()` is derived,
## not guessed, so it moves correctly if the panel or the row pitch ever does.
##
## ## The row grammar
##
## A FIXED set of `page_capacity()` row slots is built once, in `_build_rows()`, and
## `_show_page()` REBINDS each slot to a different `{kind, id}` target as the page
## turns rather than rebuilding Controls — the same "redraw from the flags" shape
## `OptionsScreen.refresh()` uses, one level up: there the flags are fixed and the
## rows are fixed; here the BACKING DATA a fixed row shows also changes with the
## page.
##
## Each row's button cycles through `Skins.owned_families()` for that target, never
## through an unowned one — an unowned skin is never offered, only counted, in the
## row's second column ("2/4 owned"), which is the whole of how this screen tells a
## player there is more to have without needing a locked/greyed button state, and
## without repeating the Shop's price list on a paused board.
##
## The count is now PER TARGET rather than per player, because ownership is: buying
## Cut Paper for the Sunflower buys nothing for the Aphid. The old
## `Skins.unlocked_families(earned_milestones)` answered the same number for every
## row on the page, which was correct while a milestone unlocked a family everywhere
## at once and would now be a readout that never changes.

const NODE_NAME := "SkinsScreen"

## The panel this screen ships at. Position.x is a placeholder — `panel_rect()`
## centres it live through `paper_left()`, the same as every other overlay here.
## Height matches `KeyBindingScreen.PANEL_MIN_HEIGHT`: this is a catalogue screen
## with the same "as tall as the viewport allows" shape as the Keys screen, not the
## "grows to its own row count" shape `OptionsScreen.panel_height()` uses, because
## the row COUNT here is fixed at `page_capacity()` regardless of how many targets
## exist — paging absorbs the rest.
const PANEL := Rect2(0.0, 24.0, 700.0, 600.0)

const HEADING_Y: float = 44.0
const NOTE_Y: float = 90.0
const ROWS_TOP: float = 136.0

## Column x offsets from the panel's left edge. Same NAME_X the other overlays use,
## so the Back button lines up under this screen's rows the way it does under
## theirs; the other two are this screen's own, since neither of the other screens
## has an "N/M owned" column.
##
## BUTTON_X IS THE ONE WIDTH HERE THAT IS NOT DERIVED, and the v12 family rename is
## what makes that worth saying. The button carries `Skins.title_of(...)`, a shared
## `ROW_BUTTON_SIZE.x` of 150 — and `Control.set_size` clamps to
## `get_combined_minimum_size()`, so a title wider than 150 minus the theme's 14+14
## content margins and the focus box's 2+2 expand does not clip, it makes the button
## WIDER than the slot reserved for it. "Botanical Plate" at BUTTON_FONT_SIZE is the
## first title in this game's history to reach that, and it still fits: the panel is
## 700 wide and BUTTON_X leaves 182 for a button that needs about 156, so the button
## grows into its own right margin rather than off the paper. What it eats is the
## symmetry with NAME_X, not the enclosure the overlay sweep checks.
##
## `test_a_family_title_still_fits_the_row_button_it_is_drawn_in` (test_skins.gd) is
## the measurement, over every FAMILIES title through `GardenTheme.measure`, so the
## family that finally does not fit says so instead of drawing over the margin. The
## fix when it fires is ShopScreen's shape — derive the column and the panel width
## from the corpus — not a wider constant here.
const NAME_X: float = 32.0
const NAME_WIDTH: float = 280.0
const OWNED_X: float = 328.0
const OWNED_WIDTH: float = 170.0
const BUTTON_X: float = 518.0

## The pager row, in the footer strip beside the Back button — same y, same
## FOOTER_HEIGHT, positioned clear of BACK_BUTTON_SIZE's 150px width (32 to 182)
## with room to spare before KEY_X's 384, the second-column x every other overlay's
## footer-adjacent furniture already respects.
const PAGER_PREV_X: float = 380.0
const PAGER_PREV_WIDTH: float = 70.0
const PAGER_LABEL_X: float = 458.0
const PAGER_LABEL_WIDTH: float = 90.0
const PAGER_NEXT_X: float = 556.0
const PAGER_NEXT_WIDTH: float = 70.0

## Deliberately shorter than the sentence it replaces, and the reason is mechanical
## rather than editorial: `add_note_label` gives this string the panel's full 700px
## with `clip_text` and OVERRUN_TRIM_ELLIPSIS, so a sentence over budget is not a
## warning, it is a sentence the player never reads the end of. The old text was 107
## characters against `OptionsScreen.NOTE_TEXT`'s 78 in a panel of exactly the same
## width; this is 74 (76 until v12 took the word "colour" out of it, which is no longer
## what a family is). `test_the_skins_screen_note_fits_the_paper_it_is_printed_on`
## measures the built Label through `_T.text_width` -- its own resolved theme font,
## not a character count and not the eye. `get_minimum_size()` is no use here: it
## reports the clip stub on exactly the labels that carry `clip_text`.
##
## It names the Shop because this screen no longer has any way to say "there is more":
## the second column counts what is owned, and a player who owns one family sees
## "1/4 owned" with nothing telling them where the other three live.
const NOTE_TEXT := "Pick a look for each plant and pest you own one for. Buy more in the Shop."

var _name_labels: Array[Label] = []
var _owned_labels: Array[Label] = []
var _skin_buttons: Array[Button] = []
var _page_label: Label
var _prev_button: Button
var _next_button: Button

## Every (kind, id) pair this screen can page through, fixed for the life of the
## screen — a purchase made mid-session cannot add a target, only add a family to
## one already here.
var _all_targets: Array[Dictionary] = []
## The current page's targets, one entry per row slot in `_skin_buttons` order — an
## empty Dictionary for a slot past the end of `_all_targets` on the last page.
var _page_targets: Array[Dictionary] = []
var _page: int = 0


## The one place this screen is constructed — see `OptionsScreen.build()` for why
## PROCESS_MODE_ALWAYS is set outright rather than inherited: whatever opens this
## (a paused run, in this game's only door today — see `Game._open_skins`) must not
## freeze it, or its Back button and its pager both go dead behind the pause that
## owns it.
static func build() -> SkinsScreen:
	var screen := SkinsScreen.new()
	screen.name = NODE_NAME
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	return screen


## How many rows this panel holds before the footer's clearance is threatened —
## DERIVED against this screen's own PANEL and the shared row constants, the same
## call `OptionsScreen.rows_capacity()` and `KeyBindingScreen.panel_height()` each
## make against theirs, so a future change to ROW_HEIGHT or FOOTER_GAP moves this
## number with it instead of leaving it to be re-measured by hand.
static func page_capacity() -> int:
	return OverlayScreen.rows_that_fit(ROWS_TOP, ROW_HEIGHT, ROW_BUTTON_SIZE.y,
		PANEL.position.y + PANEL.size.y - FOOTER_HEIGHT - FOOTER_INSET - FOOTER_GAP)


func panel_rect() -> Rect2:
	return Rect2(Vector2(paper_left(PANEL.size.x), PANEL.position.y), PANEL.size)


func _build_contents() -> void:
	_all_targets = Skins.targets()
	add_heading("Skins", HEADING_Y)
	add_note_label(NOTE_TEXT, NOTE_Y)
	_build_rows()
	_build_pager()
	add_back_button(Vector2(panel_rect().position.x + NAME_X, footer_y()))
	_show_page(0)


## One row per slot, built once. `add_row_button` registers each into
## OverlayScreen's own `_row_buttons`, which is what lets `_warn_if_footer_is_flush`
## police this screen's clearance the same way it polices every other overlay's —
## nothing about paging exempts this panel from that rule, since the slots
## themselves never move.
func _build_rows() -> void:
	var left: float = panel_rect().position.x
	var y: float = ROWS_TOP
	for i: int in page_capacity():
		_name_labels.append(add_row_label("SkinName%d" % i, "",
			Vector2(left + NAME_X, y + 8.0), Vector2(NAME_WIDTH, 24.0), GardenTheme.INK))
		_owned_labels.append(add_row_label("SkinOwned%d" % i, "",
			Vector2(left + OWNED_X, y + 8.0), Vector2(OWNED_WIDTH, 24.0), GardenTheme.INK_SOFT))
		# Bound, not read off the loop variable — OptionsScreen._build_rows carries the
		# same comment for the same reason: a lambda closing over `i` directly is how
		# every button ends up pressing the last slot.
		var button: Button = add_row_button(i, Vector2(left + BUTTON_X, y))
		button.pressed.connect(_on_skin_button_pressed.bind(i))
		_skin_buttons.append(button)
		y += ROW_HEIGHT


## Prev / page-of-M / Next, in the footer strip. Plain Buttons and a Label rather
## than `add_row_button`/`add_row_label`, which name their Controls for the ROW
## grammar's own contract — these three are footer furniture, the same tier the
## Back button already occupies, and naming them as rows would put "RowButton%d"
## on a Control the row-count math above does not know about.
func _build_pager() -> void:
	var left: float = panel_rect().position.x
	var y: float = footer_y()

	_prev_button = Button.new()
	_prev_button.name = "SkinsPagePrev"
	_prev_button.text = "< Prev"
	_prev_button.position = Vector2(left + PAGER_PREV_X, y)
	_prev_button.size = Vector2(PAGER_PREV_WIDTH, FOOTER_HEIGHT)
	_prev_button.pressed.connect(func() -> void: _show_page(_page - 1))
	add_child(_prev_button)

	_page_label = Label.new()
	_page_label.name = "SkinsPageLabel"
	_page_label.position = Vector2(left + PAGER_LABEL_X, y)
	_page_label.size = Vector2(PAGER_LABEL_WIDTH, FOOTER_HEIGHT)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.add_theme_font_size_override("font_size", 15)
	_page_label.add_theme_color_override("font_color", GardenTheme.INK)
	add_child(_page_label)

	_next_button = Button.new()
	_next_button.name = "SkinsPageNext"
	_next_button.text = "Next >"
	_next_button.position = Vector2(left + PAGER_NEXT_X, y)
	_next_button.size = Vector2(PAGER_NEXT_WIDTH, FOOTER_HEIGHT)
	_next_button.pressed.connect(func() -> void: _show_page(_page + 1))
	add_child(_next_button)


## How many pages `_all_targets` needs at this screen's row capacity. At least 1,
## so an empty target list (never happens today — PlantCatalog and Pest.SPECIES are
## both non-empty — still reads as "page 1 of 1" rather than "page 1 of 0".
func total_pages() -> int:
	var capacity: int = maxi(_skin_buttons.size(), 1)
	return maxi(1, int(ceil(float(_all_targets.size()) / float(capacity))))


## The page currently shown, 0-based.
func current_page() -> int:
	return _page


## Turns to `page`, clamped into range, and rebinds every row slot to that page's
## slice of `_all_targets` — hiding a slot past the end on the last page rather
## than leaving it showing the previous page's target under a button that would
## then write to the wrong one.
func _show_page(page: int) -> void:
	var capacity: int = _skin_buttons.size()
	_page = clampi(page, 0, total_pages() - 1)
	var start: int = _page * capacity
	_page_targets = []
	for i: int in capacity:
		var idx: int = start + i
		var visible: bool = idx < _all_targets.size()
		_name_labels[i].visible = visible
		_owned_labels[i].visible = visible
		_skin_buttons[i].visible = visible
		_page_targets.append(_all_targets[idx] if visible else {})
		if visible:
			_refresh_slot(i)
	if _page_label != null:
		_page_label.text = "Page %d/%d" % [_page + 1, total_pages()]
	if _prev_button != null:
		_prev_button.disabled = _page <= 0
	if _next_button != null:
		_next_button.disabled = _page >= total_pages() - 1


## Redraws one slot from RunConfig — the current choice and the owned count —
## the same "redraw from the owner, never trust what the button already says"
## rule `OptionsScreen.refresh()` follows.
func _refresh_slot(i: int) -> void:
	var target: Dictionary = _page_targets[i]
	if target.is_empty():
		return
	var kind: StringName = target["kind"]
	var id: StringName = target["id"]
	_name_labels[i].text = Skins.display_name(kind, id)
	# Asked per target, with this row's own kind and id, because that is the grain
	# ownership actually has now — `RunConfig.purchased_skins` is keyed by
	# `Skins.selection_key(kind, id)`. Reading it once outside the loop and reusing it
	# for every row is the shape this had while a milestone unlocked a family for the
	# whole board, and it would now print the Sunflower's count on the Aphid's row.
	var owned: Array[Dictionary] = Skins.owned_families(kind, id, RunConfig.purchased_skins)
	var tag: String = "Plant" if kind == Skins.KIND_PLANT else "Pest"
	_owned_labels[i].text = "%s - %d/%d owned" % [tag, owned.size(), Skins.FAMILIES.size()]
	_skin_buttons[i].text = Skins.title_of(RunConfig.selected_skin(kind, id))


## Advances the slot's target to its next OWNED skin and persists the choice.
## The only writer this screen has — "changed on screen" and "changed in
## RunConfig" cannot come apart if there is one door, the same argument
## `OptionsScreen.flip()` makes for its own single writer.
func _on_skin_button_pressed(slot: int) -> void:
	if slot < 0 or slot >= _page_targets.size():
		return
	var target: Dictionary = _page_targets[slot]
	if target.is_empty():
		return
	var kind: StringName = target["kind"]
	var id: StringName = target["id"]
	var current: StringName = RunConfig.selected_skin(kind, id)
	var next: StringName = Skins.next_owned(kind, id, current, RunConfig.purchased_skins)
	RunConfig.set_skin(kind, id, next)
	_refresh_slot(slot)


## Every real (non-empty) target on the page currently shown — for tests and the
## bridge, the same "answer the question directly rather than reading it back off
## rendered text" shape `OptionsScreen.rows()` is kept for.
func visible_targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for target: Dictionary in _page_targets:
		if not target.is_empty():
			out.append(target)
	return out


## Presses the row button for `kind`/`id` if it is on the page currently shown —
## the one door a test or the bridge needs, rather than having to locate a
## `RowButton%d` by first working out which slot a target landed in.
func press_skin_button(kind: StringName, id: StringName) -> bool:
	for i: int in _page_targets.size():
		var target: Dictionary = _page_targets[i]
		if not target.is_empty() and StringName(target["kind"]) == kind and StringName(target["id"]) == id:
			_skin_buttons[i].pressed.emit()
			return true
	return false


## Turns to the page holding `kind`/`id`, or does nothing if it is not a target
## this screen knows. For tests and the bridge, so reaching a target past page 1
## is not "press Next and hope".
func show_page_for(kind: StringName, id: StringName) -> bool:
	var capacity: int = maxi(_skin_buttons.size(), 1)
	for i: int in _all_targets.size():
		var target: Dictionary = _all_targets[i]
		if StringName(target["kind"]) == kind and StringName(target["id"]) == id:
			_show_page(i / capacity)
			return true
	return false
