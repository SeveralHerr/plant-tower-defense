class_name ShopScreen
extends OverlayScreen

## Where petals are spent. The title screen's buy door for skins, against
## `SkinsScreen`'s in-run quick-equip door off the HUD — two screens over one
## wardrobe on purpose, because the two questions are asked at different moments:
## "which of the ones I own is this plant wearing" is a decision taken mid-run with
## the board visible, and "is this one worth five petals" is one taken between runs
## with the balance in front of you.
##
## ## What this screen owns and what it does not
##
## Nothing. Every read is `RunConfig.petals` / `owns_skin()` / `selected_skin()` and
## every write is `RunConfig.buy_skin()` / `set_skin()`, which is the same "the screen
## has no state of its own" rule `SkinsScreen` and `OptionsScreen` both follow. The
## only thing this screen remembers is which page it is showing.
##
## ## The row grammar, and why it is paged
##
## `SkinsScreen` is the model, down to the seam names: a FIXED set of
## `page_capacity()` row slots is built once in `_build_rows()` and REBOUND per page
## by `_show_page()`, never rebuilt. Fourteen targets (nine plants, five pests) do not
## fit a panel that also has to keep `FOOTER_GAP` clear of its footer, and this
## codebase has never used a `ScrollContainer` — `OverlayScreen.rows_that_fit()`
## exists precisely to answer "how many of these fit", so the capacity is derived and
## the rest is paged.
##
## A row is one target and carries three things: what it is, what it is wearing, and
## one button per buyable family whose TEXT and `disabled` state together are the
## whole of the purchase state. Four states, spelled in `STATES` and produced by
## `button_state()`:
##
##   buy           `Heirloom Gold  5✿`   not owned, affordable  — buys it and wears it
##   unaffordable  `Heirloom Gold  5✿`   not owned, too dear    — disabled
##   equip         `Heirloom Gold`       owned, not worn        — wears it
##   worn          `Heirloom Gold  worn` owned and worn         — disabled
##
## ## Every width on this screen is measured, not chosen
##
## The row is three price buttons wide and the family titles are the game's, not this
## screen's — "Heirloom Gold" is thirteen characters and the next family added could
## be twenty. A typed-in button width would clip a title the day the table grows, and
## `Label.get_minimum_size()` cannot catch it because every row Label here is
## `clip_text`. So `family_button_width()`, `name_column_width()` and
## `wearing_column_width()` each sweep the real corpus through `GardenTheme.measure()`
## — the same door `PauseScreen.card_width()` uses — and `panel_width()` is their sum.
## The floors below are what those return when no font resolves at all; see
## `GardenTheme.measure`'s own note on why it answers 0.0 rather than erroring.

const NODE_NAME := "ShopScreen"

## The paper's top inset and height. Fixed, unlike the width: the row budget is a
## statement about the 648-tall design canvas (`OverlayScreen.design_height()`), and
## `page_capacity()` reads these two directly so the number of slots is answerable
## before any instance exists. The WIDTH is derived instead, because what decides it
## is the widest string the buttons can carry rather than a canvas dimension.
const PANEL_TOP: float = 24.0
const PANEL_HEIGHT: float = 600.0

const HEADING_Y: float = 44.0
const NOTE_Y: float = 90.0
## The balance sits on its own line under the note rather than beside the heading.
## `add_heading` and `add_note_label` both build a Label spanning the WHOLE paper
## width — that is the shared chrome, not this screen's choice — so anything sharing
## either of their y bands would overlap them, and the overlay containment sweep
## (`_overlay_content_fits_and_stands_clear`) checks exactly that.
const BALANCE_Y: float = 118.0
const BALANCE_HEIGHT: float = 24.0
const BALANCE_FONT_SIZE: int = 20
const ROWS_TOP: float = 152.0

## Column x offsets from the paper's left edge. NAME_X doubles as the RIGHT margin
## and as the Back button's inset, the same as every other overlay here, so the
## footer lines up under the first column.
const NAME_X: float = 28.0
const COLUMN_GAP: float = 12.0
## Between two family buttons in one row. Same 8px the title menu splits its band
## with; it is a gap between two live controls, not a text margin.
const BUTTON_GAP: float = 8.0

const ROW_LABEL_HEIGHT: float = 24.0
## The row's Labels are 24 tall inside a 40 tall button, so they are dropped 8 to sit
## on the button's centre line rather than on its top edge.
const ROW_LABEL_INSET: float = 8.0
## `OverlayScreen.add_row_label` hardcodes 16 for every row cell in the game. Named
## here because the width derivation has to measure at the size the Label will draw
## at, and measuring at the wrong one is a budget that is silently wrong.
const ROW_FONT_SIZE: int = 16

## The pager label's size. Named because `pager_label_width()` measures at it and
## `_build_pager` draws at it; a literal in one of those two is how a strip ends up
## measured at one size and rendered at another.
const PAGER_LABEL_FONT_SIZE: int = 15

## What a measured string needs on top of itself inside a themed Button.
## `GardenTheme._button_box` puts 14px of content margin on each side and the focus
## box expands 2px past the border; 36 is those 28 plus 8 of breathing room, so a
## title that only just fits does not sit flush against its own border.
const BUTTON_TEXT_MARGIN: float = 36.0
## The same allowance for a bare Label, which has no stylebox. 12 is a gap to the
## next column rather than padding.
const LABEL_TEXT_MARGIN: float = 12.0

## Floors for the three derived columns. These are what the measurement returns when
## no font resolves (`GardenTheme.measure` answers 0.0 then, deliberately), so they
## have to be wide enough to be a sane screen on their own rather than a token
## minimum. The button floor is the shared `ROW_BUTTON_SIZE.x`.
const NAME_MIN_WIDTH: float = 150.0
const WEARING_MIN_WIDTH: float = 130.0

## The pager, in the footer strip to the RIGHT of the Back button. Right-aligned off
## `panel_width()` rather than at a fixed x, because the paper's width is derived and
## a fixed x would drift out of the footer the day a family title grows.
##
## FLOORS, not widths — `pager_button_width()` measures the two faces the same way
## every other column on this screen is measured, and these are what it falls back to
## when no font resolves. Written down as 70/90 first, and that was a real overlap
## rather than a near miss: `Control.set_size` clamps to `get_combined_minimum_size()`,
## and a Button's minimum is its text plus the theme's 14+14 content margins plus the
## focus box's expand, so "< Prev" at BUTTON_FONT_SIZE came back 83 wide from a
## position that had reserved 70 and sat 13px under the page label. The three columns
## above were derived from the start and none of them moved; these two were the only
## hand-typed widths on the screen and they were the only two that collided.
const PAGER_BUTTON_MIN_WIDTH: float = 70.0
const PAGER_LABEL_MIN_WIDTH: float = 90.0

## What the two pager buttons say, in one place because two things measure it: the
## width derivation below and the Controls `_build_pager` labels. A face measured from
## one string and drawn from another is the defect the derivation exists to stop.
const PAGER_PREV_TEXT := "< Prev"
const PAGER_NEXT_TEXT := "Next >"


## The width both pager buttons take: the wider of the two faces, so Prev and Next are
## the same size and the strip reads as one control rather than as two that disagree.
static func pager_button_width() -> float:
	var widest: float = maxf(
		GardenTheme.measure(PAGER_PREV_TEXT, GardenTheme.BUTTON_FONT_SIZE),
		GardenTheme.measure(PAGER_NEXT_TEXT, GardenTheme.BUTTON_FONT_SIZE))
	return maxf(PAGER_BUTTON_MIN_WIDTH, ceilf(widest + BUTTON_TEXT_MARGIN))


## Measured against the widest page count this screen can actually reach rather than
## against "Page 9/9": `total_pages()` is derived from `Skins.targets()` and
## `page_capacity()`, so the string is as wide as the real corpus makes it and no wider.
static func pager_label_width() -> float:
	var pages: int = maxi(1, int(ceil(float(Skins.targets().size()) / float(maxi(1, page_capacity())))))
	var widest: String = "Page %d/%d" % [pages, pages]
	return maxf(PAGER_LABEL_MIN_WIDTH,
		ceilf(GardenTheme.measure(widest, PAGER_LABEL_FONT_SIZE) + LABEL_TEXT_MARGIN))

## The four states a family button can be in, and the whole of what pressing one
## does. Spelled as constants rather than as bare `&"buy"` literals at eight call
## sites, and listed in STATES so the width sweep and the tests can walk them —
## `.claude/skills/derive-the-list`: three example cases is not a test of a
## four-state machine.
const STATE_BUY := &"buy"
const STATE_UNAFFORDABLE := &"unaffordable"
const STATE_EQUIP := &"equip"
const STATE_WORN := &"worn"
const STATES: Array[StringName] = [STATE_BUY, STATE_UNAFFORDABLE, STATE_EQUIP, STATE_WORN]
## The two that a player cannot act on: one is already true, the other cannot be
## afforded. Derived from here by `state_is_disabled()` rather than re-tested with an
## `or` at each site.
const DISABLED_STATES: Array[StringName] = [STATE_UNAFFORDABLE, STATE_WORN]

## The petal mark, and the check mark for a skin already being worn.
##
## BOTH ARE ASKED OF THE FONT rather than assumed — see `_mark()`. `✿` (U+273F) and
## `✓` (U+2713) are Dingbats, and this project's shipped non-ASCII is arrows and
## mathematical operators (`←`, `≈`, `∞`, `±`) which live in blocks Godot's built-in
## font does carry. A missing glyph does not fail loudly: it draws as a hex box with
## an advance like any other glyph, so every width assertion on this screen would
## pass over it.
## Taken from `Glyphs` rather than spelled here, so the character this screen draws
## and the row that says what it MEANS cannot become two different characters.
const PETAL_GLYPH := Glyphs.PETAL
const WORN_GLYPH := Glyphs.TICK
## THE FALLBACKS, AND ONE OF THEM IS A DEVIATION FROM THE CONTRACT, which asked for
## "the word". "petals" spelled out on three price buttons in one row needs about
## 1164px of a 1152px canvas, so the word does not fit and a clipped price is worse
## than no mark at all. The unit is instead named twice on this screen where there is
## room for it — the balance line reads "Petals  N" and NOTE_TEXT says where they
## come from — so a bare `Heirloom Gold  5` under a line reading `Petals  12` is
## still unambiguous. The worn mark's word does fit and is used.
const PETAL_FALLBACK := ""
const WORN_FALLBACK := "worn"

const NOTE_TEXT := ("Petals come from clearing waves and from milestones. Buy a look for a "
	+ "plant or a pest here, then press it again to wear it.")

var _name_labels: Array[Label] = []
var _wearing_labels: Array[Label] = []
## Every family button on the screen, flat, in slot-major order: slot `i`'s button
## for family column `f` is at `i * _family_count + f`. Flat rather than an
## `Array[Array]` because the only access is through `_button_at()`, and one index
## sum in one function is easier to be right about than a nested typed Array that
## GDScript will silently widen on the way in and out.
var _family_buttons: Array[Button] = []
var _family_count: int = 0
var _balance_label: Label
var _page_label: Label
var _prev_button: Button
var _next_button: Button

## Every (kind, id) pair this screen pages through, fixed for the life of the screen:
## buying a skin changes what a row SAYS, never which rows exist.
var _all_targets: Array[Dictionary] = []
## The current page's targets, one entry per row slot — an empty Dictionary for a
## slot past the end of `_all_targets` on the last page.
var _page_targets: Array[Dictionary] = []
var _page: int = 0


## The one place this screen is constructed. PROCESS_MODE_ALWAYS is set here rather
## than inherited, for the reason `OverlayScreen`'s header gives: it is a stated
## property a test can read, and an overlay that froze with the tree under it would
## have a dead Back button. This screen's only door today is the title menu, which is
## never paused — which is exactly why setting it here rather than relying on the
## parent matters, because the day it gains a pause-card door nothing would say so.
static func build() -> ShopScreen:
	var screen := ShopScreen.new()
	screen.name = NODE_NAME
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	return screen


# -- the measured layout -------------------------------------------------------


## A mark the theme's own font can actually draw, or `fallback`.
##
## Asked rather than decided, because the answer is a fact about whichever font the
## theme resolves and this file cannot name that font — `GardenTheme.measure`'s own
## header makes the same argument for measuring through a detached Label instead of
## loading a Font by path. Detached is sound here for its reason too: no custom theme
## is set in project.godot, so an off-tree Label resolves the same font as an in-tree
## one.
static func _mark(glyph: String, fallback: String) -> String:
	if glyph.is_empty():
		return fallback
	var probe := Label.new()
	var font: Font = probe.get_theme_font("font")
	var drawable: bool = font != null and font.has_char(glyph.unicode_at(0))
	probe.free()
	return glyph if drawable else fallback


static func petal_mark() -> String:
	return _mark(PETAL_GLYPH, PETAL_FALLBACK)


static func worn_mark() -> String:
	return _mark(WORN_GLYPH, WORN_FALLBACK)


## What a family button says in each of its four states. Pure, and static, so the
## width sweep below can price every string this screen can ever draw without
## building the screen to find out — the same reason `TitleScreen.button_rect()` is
## static.
static func button_text(kind: StringName, family_id: StringName, state: StringName) -> String:
	var title: String = Skins.title_of(family_id)
	if state == STATE_EQUIP:
		return title
	if state == STATE_WORN:
		return "%s  %s" % [title, worn_mark()]
	# buy and unaffordable are the SAME sentence and differ only in `disabled`. A
	# refusal that also changed the words would leave a player unable to see what the
	# thing they cannot afford costs, which is the one fact they need.
	return "%s  %d%s" % [title, Skins.cost_for(kind, family_id), petal_mark()]


## Whether a button in `state` is one a player can press.
static func state_is_disabled(state: StringName) -> bool:
	return DISABLED_STATES.has(state)


## Every kind `Skins.targets()` actually produces, in first-seen order.
##
## Derived from the target list rather than written as `[KIND_PLANT, KIND_PEST]`,
## because the price is keyed on the kind (`Skins.cost_for`) and a third kind would
## otherwise be priced by a sweep that never sees it.
static func target_kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for target: Dictionary in Skins.targets():
		var kind := StringName(target["kind"])
		if not out.has(kind):
			out.append(kind)
	return out


## Every string a family button can ever carry: the cross product of kind x buyable
## family x state, de-duplicated — `buy` and `unaffordable` draw the same sentence, so
## the list is shorter than the product. The width derivation prices this, and
## `test_the_shop_measures_every_face_it_draws_and_fits_them_all` is what says the
## prices came from a real font rather than from the floors.
static func family_button_texts() -> Array[String]:
	var out: Array[String] = []
	for kind: StringName in target_kinds():
		for row: Dictionary in Skins.buyable_families():
			for state: StringName in STATES:
				var text: String = button_text(kind, StringName(row["id"]), state)
				if not out.has(text):
					out.append(text)
	return out


static func family_button_width() -> float:
	var widest: float = 0.0
	for text: String in family_button_texts():
		widest = maxf(widest, GardenTheme.measure(text, GardenTheme.BUTTON_FONT_SIZE))
	return maxf(ROW_BUTTON_SIZE.x, ceilf(widest + BUTTON_TEXT_MARGIN))


static func name_column_width() -> float:
	var widest: float = 0.0
	for target: Dictionary in Skins.targets():
		widest = maxf(widest, GardenTheme.measure(
			Skins.display_name(StringName(target["kind"]), StringName(target["id"])), ROW_FONT_SIZE))
	return maxf(NAME_MIN_WIDTH, ceilf(widest + LABEL_TEXT_MARGIN))


## Priced over `Skins.FAMILIES`, not `buyable_families()`: this column shows what the
## target is WEARING, and the one thing every target can be wearing is the default,
## which is the row `buyable_families()` drops.
static func wearing_column_width() -> float:
	var widest: float = 0.0
	for row: Dictionary in Skins.FAMILIES:
		widest = maxf(widest, GardenTheme.measure(String(row["title"]), ROW_FONT_SIZE))
	return maxf(WEARING_MIN_WIDTH, ceilf(widest + LABEL_TEXT_MARGIN))


static func wearing_x() -> float:
	return NAME_X + name_column_width() + COLUMN_GAP


static func buttons_x() -> float:
	return wearing_x() + wearing_column_width() + COLUMN_GAP


## The paper's width: both margins, both text columns, and one button per buyable
## family with a gap between each pair. Everything that decides it is measured or
## derived, so a fourth family widens the paper rather than overflowing the row.
static func panel_width() -> float:
	var count: int = Skins.buyable_families().size()
	return (buttons_x() + float(count) * family_button_width()
		+ float(maxi(count - 1, 0)) * BUTTON_GAP + NAME_X)


## How many rows this paper holds before the footer's clearance is threatened.
## Derived against this screen's own panel and the shared row constants, the same
## call `SkinsScreen.page_capacity()` makes against its own — so a change to
## ROW_HEIGHT or FOOTER_GAP moves this with it instead of leaving it to be
## re-measured by hand.
static func page_capacity() -> int:
	return OverlayScreen.rows_that_fit(ROWS_TOP, ROW_HEIGHT, ROW_BUTTON_SIZE.y,
		PANEL_TOP + PANEL_HEIGHT - FOOTER_HEIGHT - FOOTER_INSET - FOOTER_GAP)


## The balance line, composed once so the screen and any test agree on the wording
## rather than on a format string transcribed twice.
static func balance_line(petals: int) -> String:
	return "Petals  %d" % petals


func panel_rect() -> Rect2:
	var width: float = panel_width()
	return Rect2(Vector2(paper_left(width), PANEL_TOP), Vector2(width, PANEL_HEIGHT))


# -- building ------------------------------------------------------------------


func _build_contents() -> void:
	_all_targets = Skins.targets()
	_family_count = Skins.buyable_families().size()
	add_heading("Shop", HEADING_Y)
	add_note_label(NOTE_TEXT, NOTE_Y)
	_build_balance()
	_build_rows()
	_build_pager()
	add_back_button(Vector2(panel_rect().position.x + NAME_X, footer_y()))
	_show_page(0)


## The balance, in GOLD — this game's colour for a number the player earned, the same
## one the focus ring and the score line already use.
func _build_balance() -> void:
	var panel: Rect2 = panel_rect()
	_balance_label = Label.new()
	_balance_label.name = "Balance"
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# STYLING BEFORE SIZE, the ordering `OverlayScreen.add_row_label` carries a
	# paragraph about: `Control.set_size` clamps to `get_combined_minimum_size()`, and a
	# Label's minimum width is its whole text measured at whatever font size is in
	# effect at that moment. This one spans the paper and its text is eight characters,
	# so the clamp could not bite today — it is written in the order that is right
	# anyway, rather than depending on that staying true.
	_balance_label.add_theme_font_size_override("font_size", BALANCE_FONT_SIZE)
	_balance_label.add_theme_color_override("font_color", GardenTheme.GOLD)
	_balance_label.text = balance_line(RunConfig.petals)
	_balance_label.position = Vector2(panel.position.x, BALANCE_Y)
	_balance_label.size = Vector2(panel.size.x, BALANCE_HEIGHT)
	add_child(_balance_label)


## One row per slot, built once and rebound per page. Each family button goes through
## `add_row_button`, which registers it into `OverlayScreen`'s own `_row_buttons` —
## that is what lets `_warn_if_footer_is_flush` police this screen's footer clearance
## the same way it polices every other overlay's, and the slots themselves never move
## no matter which page is up.
func _build_rows() -> void:
	var left: float = panel_rect().position.x
	var families: Array[Dictionary] = Skins.buyable_families()
	var button_width: float = family_button_width()
	var name_width: float = name_column_width()
	var wearing_width: float = wearing_column_width()
	# Hoisted rather than called per row: each of these sweeps the whole corpus through
	# a detached Label (`GardenTheme.measure`), and the answer cannot change between two
	# rows of the same build.
	var wearing_column_x: float = wearing_x()
	var first_button_x: float = buttons_x()
	var y: float = ROWS_TOP
	for i: int in page_capacity():
		_name_labels.append(add_row_label("ShopName%d" % i, "",
			Vector2(left + NAME_X, y + ROW_LABEL_INSET),
			Vector2(name_width, ROW_LABEL_HEIGHT), GardenTheme.INK))
		_wearing_labels.append(add_row_label("ShopWearing%d" % i, "",
			Vector2(left + wearing_column_x, y + ROW_LABEL_INSET),
			Vector2(wearing_width, ROW_LABEL_HEIGHT), GardenTheme.INK_SOFT))
		for f: int in families.size():
			var at := Vector2(left + first_button_x + float(f) * (button_width + BUTTON_GAP), y)
			# `RowButton%d` numbering runs across the whole grid rather than restarting
			# per row: the name is a bridge address and two Controls under one parent
			# cannot share one, or Godot renames the second out from under every
			# get_node looking for it.
			var button: Button = add_row_button(i * families.size() + f, at)
			button.size = Vector2(button_width, ROW_BUTTON_SIZE.y)
			# Bound, not read off the loop variables — the same comment
			# `SkinsScreen._build_rows` and `OptionsScreen._build_rows` both carry: a
			# lambda closing over `i` directly is how every button ends up pressing the
			# last slot.
			button.pressed.connect(_on_family_pressed.bind(i, f))
			_family_buttons.append(button)
		y += ROW_HEIGHT


## Prev / page-of-M / Next, right-aligned in the footer strip. Plain Buttons and a
## Label rather than `add_row_button`/`add_row_label`, which name their Controls for
## the ROW grammar's contract — these three are footer furniture, the same tier the
## Back button occupies, and naming them as rows would hand `RowButton%d` to a Control
## the row-count math does not know about.
func _build_pager() -> void:
	var panel: Rect2 = panel_rect()
	var y: float = footer_y()
	var button_width: float = pager_button_width()
	var label_width: float = pager_label_width()
	var next_x: float = panel.size.x - NAME_X - button_width
	var label_x: float = next_x - BUTTON_GAP - label_width
	var prev_x: float = label_x - BUTTON_GAP - button_width

	_prev_button = Button.new()
	_prev_button.name = "ShopPagePrev"
	_prev_button.text = PAGER_PREV_TEXT
	_prev_button.position = Vector2(panel.position.x + prev_x, y)
	_prev_button.size = Vector2(button_width, FOOTER_HEIGHT)
	_prev_button.pressed.connect(func() -> void: _show_page(_page - 1))
	add_child(_prev_button)

	_page_label = Label.new()
	_page_label.name = "ShopPageLabel"
	_page_label.position = Vector2(panel.position.x + label_x, y)
	_page_label.size = Vector2(label_width, FOOTER_HEIGHT)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.add_theme_font_size_override("font_size", PAGER_LABEL_FONT_SIZE)
	_page_label.add_theme_color_override("font_color", GardenTheme.INK)
	add_child(_page_label)

	_next_button = Button.new()
	_next_button.name = "ShopPageNext"
	_next_button.text = PAGER_NEXT_TEXT
	_next_button.position = Vector2(panel.position.x + next_x, y)
	_next_button.size = Vector2(button_width, FOOTER_HEIGHT)
	_next_button.pressed.connect(func() -> void: _show_page(_page + 1))
	add_child(_next_button)


# -- paging and redraw ---------------------------------------------------------


## The button for family column `f` of row slot `i`. One index sum, in one place.
func _button_at(slot: int, column: int) -> Button:
	return _family_buttons[slot * _family_count + column]


## How many pages `_all_targets` needs at this screen's row capacity. At least 1, so
## an empty target list — which cannot happen today, both catalogues are non-empty —
## reads as "page 1 of 1" rather than "page 1 of 0".
func total_pages() -> int:
	var capacity: int = maxi(_name_labels.size(), 1)
	return maxi(1, int(ceil(float(_all_targets.size()) / float(capacity))))


## The page currently shown, 0-based.
func current_page() -> int:
	return _page


## Turns to `page`, clamped into range, and rebinds every row slot to that page's
## slice — HIDING a slot past the end on the last page rather than leaving it showing
## the previous page's target under buttons that would then buy for the wrong one.
func _show_page(page: int) -> void:
	var capacity: int = _name_labels.size()
	_page = clampi(page, 0, total_pages() - 1)
	var start: int = _page * capacity
	_page_targets = []
	for i: int in capacity:
		var idx: int = start + i
		var shown: bool = idx < _all_targets.size()
		_name_labels[i].visible = shown
		_wearing_labels[i].visible = shown
		for f: int in _family_count:
			_button_at(i, f).visible = shown
		_page_targets.append(_all_targets[idx] if shown else {})
	# Bound first, drawn second: `_refresh_slot` reads `_page_targets`, so filling it
	# and reading it in one pass would redraw slot 0 against a list that does not yet
	# have slot 1 in it.
	_refresh_page()
	if _page_label != null:
		_page_label.text = "Page %d/%d" % [_page + 1, total_pages()]
	if _prev_button != null:
		_prev_button.disabled = _page <= 0
	if _next_button != null:
		_next_button.disabled = _page >= total_pages() - 1


## Every visible slot, plus the balance.
##
## THE WHOLE PAGE, not the row that was pressed, and that is the difference between
## this screen and `SkinsScreen`'s `_refresh_slot(slot)`. Equipping is local; BUYING
## is not. A purchase drops the balance, and a balance that drops past a price turns
## every other row's `buy` into `unaffordable` — so a redraw scoped to the pressed row
## leaves eleven live-looking buttons on screen that the player can no longer afford.
func _refresh_page() -> void:
	for i: int in _page_targets.size():
		if not _page_targets[i].is_empty():
			_refresh_slot(i)
	if _balance_label != null:
		_balance_label.text = balance_line(RunConfig.petals)


## Redraws one slot from RunConfig — the current choice and every button's state —
## following the same "redraw from the owner, never trust what the button already
## says" rule `OptionsScreen.refresh()` does.
func _refresh_slot(i: int) -> void:
	var target: Dictionary = _page_targets[i]
	if target.is_empty():
		return
	var kind := StringName(target["kind"])
	var id := StringName(target["id"])
	_name_labels[i].text = Skins.display_name(kind, id)
	_wearing_labels[i].text = Skins.title_of(RunConfig.selected_skin(kind, id))
	var families: Array[Dictionary] = Skins.buyable_families()
	for f: int in _family_count:
		var family_id := StringName(families[f]["id"])
		var state: StringName = button_state(kind, id, family_id)
		var button: Button = _button_at(i, f)
		button.text = button_text(kind, family_id, state)
		button.disabled = state_is_disabled(state)


# -- the writer ----------------------------------------------------------------


## The only writer this screen has. "Changed on screen" and "changed in RunConfig"
## cannot come apart if there is one door — the argument `OptionsScreen.flip()` and
## `SkinsScreen._on_skin_button_pressed` both make for theirs.
##
## It re-derives the state rather than trusting the button's own `disabled`. That is
## not belt-and-braces: `press_family_button()` and the devtools bridge's `press` verb
## both reach a Button's `pressed` signal directly, and a state read off the control
## that is about to act on it is a state nothing checked.
func _on_family_pressed(slot: int, column: int) -> void:
	if slot < 0 or slot >= _page_targets.size():
		return
	var target: Dictionary = _page_targets[slot]
	if target.is_empty():
		return
	var families: Array[Dictionary] = Skins.buyable_families()
	if column < 0 or column >= families.size():
		return
	var kind := StringName(target["kind"])
	var id := StringName(target["id"])
	var family_id := StringName(families[column]["id"])
	var state: StringName = button_state(kind, id, family_id)
	if state_is_disabled(state):
		return
	if state == STATE_BUY:
		# The refusal is RunConfig's to make, not this screen's to predict: `buy_skin`
		# checks the price against the balance itself and returns false rather than
		# spending. A redraw follows either way — a refused purchase means this
		# screen's picture of the balance was wrong, which is the moment to fix it.
		if not RunConfig.buy_skin(kind, id, family_id):
			_refresh_page()
			return
	# Bought or already owned, the press ends with the target WEARING it. Buying
	# something and then having to press it a second time to see it is a step with no
	# decision in it.
	RunConfig.set_skin(kind, id, family_id)
	_refresh_page()


# -- what this screen can be asked ---------------------------------------------


## Which of the four states a family button is in for this target, right now.
##
## Ownership is asked FIRST and the balance second: an owned skin is never for sale
## again, so a player who owns Hoarfrost and has spent down to zero petals still sees
## `equip` rather than `unaffordable`. Asking the price first would have priced
## something already paid for.
func button_state(kind: StringName, id: StringName, family_id: StringName) -> StringName:
	if RunConfig.owns_skin(kind, id, family_id):
		return STATE_WORN if RunConfig.selected_skin(kind, id) == family_id else STATE_EQUIP
	return STATE_BUY if RunConfig.petals >= Skins.cost_for(kind, family_id) else STATE_UNAFFORDABLE


## Every real (non-empty) target on the page currently shown — the same seam
## `SkinsScreen.visible_targets()` exists for: answer the question directly rather
## than having a test read it back off rendered text.
func visible_targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for target: Dictionary in _page_targets:
		if not target.is_empty():
			out.append(target)
	return out


## Turns to the page holding `kind`/`id`, or does nothing if it is not a target this
## screen knows. For tests and the bridge, so reaching a target past page 1 is not
## "press Next and hope".
func show_page_for(kind: StringName, id: StringName) -> bool:
	var capacity: int = maxi(_name_labels.size(), 1)
	for i: int in _all_targets.size():
		var target: Dictionary = _all_targets[i]
		if StringName(target["kind"]) == kind and StringName(target["id"]) == id:
			_show_page(i / capacity)
			return true
	return false


## Presses one family button, if the target is on the page currently shown and the
## button is one a player could press.
##
## REFUSES A DISABLED BUTTON rather than emitting its signal anyway, and returns false
## for it. A disabled Button emits nothing when it is clicked, so a seam that emitted
## regardless would let a test "press" something no player can reach and then assert
## the handler's guard — proving the guard and not the screen. False therefore means
## "that press did not happen", for either reason; `button_state()` says which.
func press_family_button(kind: StringName, id: StringName, family_id: StringName) -> bool:
	var button: Button = _button_for(kind, id, family_id)
	if button == null or button.disabled:
		return false
	button.pressed.emit()
	return true


## The drawn button for one (target, family), or null when that target is not on the
## page currently up or the family is not one this build sells.
##
## The lookup written once. Both public seams below need it and they differ only in
## what they then do with the control — two copies of a two-deep search is two places
## for the slot arithmetic to be wrong in different ways.
func _button_for(kind: StringName, id: StringName, family_id: StringName) -> Button:
	var families: Array[Dictionary] = Skins.buyable_families()
	for i: int in _page_targets.size():
		var target: Dictionary = _page_targets[i]
		if target.is_empty():
			continue
		if StringName(target["kind"]) != kind or StringName(target["id"]) != id:
			continue
		for f: int in families.size():
			if StringName(families[f]["id"]) == family_id:
				return _button_at(i, f)
		return null
	return null


## What one family button is actually SHOWING — `{"text": String, "disabled": bool}`,
## or `{}` when that target is not on the page currently up.
##
## Read off the live Control rather than recomposed from `button_state()`, which is
## the whole point of it: a screen whose model says `worn` and whose button still
## reads `Heirloom Gold  5` is exactly the defect a test that asked `button_state()`
## twice would pass over. The alternative — a test reaching for `RowButton17` — makes
## every assertion depend on which slot a target happened to land in.
func button_face(kind: StringName, id: StringName, family_id: StringName) -> Dictionary:
	var button: Button = _button_for(kind, id, family_id)
	if button == null:
		return {}
	return {"text": button.text, "disabled": button.disabled}


## What the balance line actually reads, off the Label rather than recomposed — so a
## test asserting the balance is asserting the pixels' own source and not a second
## copy of the format string.
func balance_text() -> String:
	return "" if _balance_label == null else _balance_label.text
