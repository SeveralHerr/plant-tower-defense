class_name OverlayScreen
extends Control

## The chrome every full-screen overlay in this game wears, owned once.
##
## Three screens open over the title menu or the pause card — the Designer's
## Notebook, the Keys screen and the Options screen — and until this class existed
## each of them hand-rolled the same four things: a nearly-opaque `Backdrop`
## ColorRect sized to the viewport, a paper panel behind the content, a
## `BackButton` wired to a `back_requested` signal, and the pair of getters that
## read the viewport size out of ProjectSettings. Options was written by copying
## Keys, so the two matched to the letter — which is exactly the state in which a
## fix lands on one copy and not the other.
##
## ## Node paths are a contract
##
## `Backdrop`, `Paper`, `BackButton`, `Note` and `Row%d` / `RowKey%d` /
## `RowButton%d` are asserted by test_selftest.gd and pressed BY NAME from the
## devtools bridge. This class builds them under exactly those names for every
## screen; a subclass that wants a different name wants a different contract, and
## that is a conversation and not an edit.
##
## The screen's OWN node name is the other half of that contract, and every subclass
## declares it as `NODE_NAME` — `KeyBindingScreen.NODE_NAME`, `OptionsScreen.NODE_NAME`,
## `NotebookScreen.NODE_NAME`. It is not declared here because the value differs per
## screen, but the CONSTANT is not optional: a subclass without one is the screen
## every sweep over "all the overlays" has to special-case, which is what the
## notebook was until plant-tower-defense-j7b1.
## `test_every_overlay_screen_declares_a_node_name_and_they_are_distinct` derives the
## subclass set from the engine's global class table and asserts it, so a fourth
## screen is asked for a NODE_NAME without anyone having to remember this paragraph.
##
## ## What a subclass supplies
##
## `panel_rect()` — where the paper sits, sized from the screen's own row count
## rather than picked and then trusted to fit (see FOOTER_GAP).
## `_build_contents()` — the rows, the headings, the footer. Everything above is
## already on screen by the time it runs.
##
## `_ready()` is deliberately NOT one of them: a subclass that defined its own
## would silently replace this one and lose the backdrop, which is the failure
## the class exists to prevent. Two hooks are provided for the one screen that
## genuinely differs — `_add_paper()` (NotebookScreen draws a two-page spread, not
## a Panel) and `_focus_default()` (the notebook opens with its pager focused).
##
## ## Process mode is NOT set here
##
## An overlay opened from the pause card must not freeze with the tree it is
## sitting on: a frozen overlay has dead buttons, a Back that does nothing and no
## way out of it. That is PROCESS_MODE_ALWAYS, and it is set at each construction
## site outright — KeyBindingScreen.build(), PauseScreen._open_notebook() — rather
## than inherited from whichever parent the overlay happens to be added to.
## Setting it here for every overlay would make it an inherited fact again, one
## layer further away, and the point is that it is a stated property a test can
## read.
##
## ## What is under an overlay goes inert, and the OVERLAY is what does it
##
## **Focus and the mouse are two channels and both have to go.** Every overlay here
## carries a full-viewport `MOUSE_FILTER_STOP` Backdrop, so nothing underneath can
## be CLICKED through it — and focus does not care what is drawn on top, so Tab or
## an arrow key walks straight onto a button the player cannot see. The mouse filter
## goes too because `BACKDROP_ALPHA` is 0.88: a button still tracking the cursor
## underneath lights up in its hover colour and the glow shows through the paper.
##
## That was eight lines written three times under three names — `Hud.set_active`,
## `PauseScreen._set_card_active`, `TitleScreen._set_menu_active` — each added the
## cycle its own screen got caught. It is `set_controls_active()` below now, once.
##
## More to the point, **the overlay calls it**. An overlay knows when it opens and
## when it closes; an opener has to remember, twice, and the HUD's opener forgot for
## several cycles (plant-tower-defense-csrc). `_ready()` derives the surface from
## this node's PARENT — no list, nothing declared at a call site — holds it inert,
## and `close()` / `_exit_tree()` hand it back exactly as it was found.
##
## The one thing it cannot see is a surface on a DIFFERENT `CanvasLayer`: that is
## nobody's child. The HUD is precisely that, which is why `Game.pause_run` still
## makes it inert separately. Such a caller hands the surface over with a second
## `hold_inert()` call rather than writing the eight lines again.

signal back_requested

## The contract names, spelled once. Written out at each call site would be four
## more places for a typo to become a bridge recipe that presses nothing.
const BACKDROP_NAME := "Backdrop"
const PAPER_NAME := "Paper"
const BACK_BUTTON_NAME := "BackButton"
const NOTE_NAME := "Note"

## Not fully opaque: the garden behind shows through faintly, so an overlay reads
## as something held up in front of the game rather than a different program.
## Still dark enough that nothing behind it competes, and still a
## MOUSE_FILTER_STOP ColorRect, so the buttons underneath stay unclickable.
const BACKDROP_ALPHA: float = 0.88

const BACK_TEXT := "← Back"
## 40 tall, and every interactive Control on an overlay is: `findings` gates an
## interactive Control at 40x40 and is right to — a 38px button is a 38px touch
## target.
const BACK_BUTTON_SIZE := Vector2(150.0, 40.0)
const ROW_BUTTON_SIZE := Vector2(150.0, 40.0)

## 48, not 44. The button in a row is 40 tall and a row pitch matching its own
## contents leaves two Labels touching the row above — the same one-pixel overlap
## PauseScreen.KEY_ROW_HEIGHT's comment is about. It was 52 on the Keys screen
## while the table had seven verbs; the eighth bought its four pixels back out of
## the pitch rather than out of the 8px clearance above each button, which is the
## part doing work.
const ROW_HEIGHT: float = 48.0

const FOOTER_HEIGHT: float = 40.0
## How far up from the paper's foot the footer sits.
const FOOTER_INSET: float = 24.0

## The minimum clear space between the foot of the last row and the top of the
## footer. THE RULE, in one place, for every overlay that has rows.
##
## It is a minimum GAP and deliberately not mere non-intersection. Both the Keys
## and the Options screen size their panel from their row count, and the Keys
## screen once had a footer laid flush against the last row: every Control sat
## inside the paper, nothing intersected anything — `Rect2.intersects` is false
## for two boxes sharing an edge — and every check written at the time passed. It
## was wrong only in a screenshot. `footer_clearance()` below measures it,
## `_ready()` complains at build time if a screen breaks it, and the suite asserts
## it once for every screen with rows rather than once per screen.
const FOOTER_GAP: float = 24.0


## How many evenly pitched rows fit between `top` and `floor_y`.
##
## **The arithmetic three separate surfaces had each written out in prose.** Cycle 75
## enumerated every row-limited surface in the game and found four: `TitleScreen` COMPUTES
## its ceiling, and `OptionsScreen`, the notebook's milestone shelf and `RunSummary` each
## wrote the sums into a comment and pinned the result with a test. All three were correct,
## all three were derived by hand in three files by three cycles that could not see each
## other, and each had to be re-derived by the next person wanting a row.
##
## Four arguments, and `-knpc` explicitly warned that a four-argument helper can be worse
## than four computations. They are kept because they are not knobs — they are the four
## facts a row layout has, and every caller passes its own named constants for all four, so
## the call site still reads as that surface's geometry rather than as a configuration.
## What is shared is only the `(n - 1) * pitch` off-by-one, which is the part that gets
## re-derived wrongly.
##
## `TitleScreen.menu_capacity()` deliberately does NOT use this: its rows are a grid with
## per-row heights (`menu_bottom` walks `menu_rows(count)`), so there is no single pitch to
## pass. A helper that grew an argument to swallow that case would stop being four facts.
static func rows_that_fit(top: float, pitch: float, item_height: float,
		floor_y: float) -> int:
	if pitch <= 0.0:
		return 0
	var n: int = 0
	while top + float(n) * pitch + item_height <= floor_y:
		n += 1
	return n

## The covering layer, held rather than re-found by name: `_apply_viewport_layout()`
## re-sizes it on every window change and a `get_node(BACKDROP_NAME)` per resize
## would be a lookup that can silently miss.
var _backdrop: ColorRect
## The overlay's own Back button, set by add_back_button(). Kept because
## `_focus_default()` opens on it and `footer_clearance()` measures against it.
var _back_button: Button
## The line that changes: an instruction, a prompt, a refusal. One Label named
## `Note`, on whichever screen has something to say.
var _note: Label
## Every row button the screen built, in row order. Registered by
## add_row_button() rather than by each screen keeping its own list, because the
## footer-gap rule measures the LAST one and a row this base never saw is a row
## the rule silently skips.
var _row_buttons: Array[Button] = []

## What this overlay is holding inert while it is open, and what each of those
## controls WAS at the moment it opened. One Dictionary per control:
## `{"control": Control, "focus": Control.FocusMode, "filter": Control.MouseFilter}`.
## See `hold_inert()` for why the prior state is recorded rather than assumed.
var _held: Array[Dictionary] = []


## Backdrop, paper, contents, then focus — in that order, once, for every overlay.
##
## Explicit position+size rather than PRESET_FULL_RECT: an overlay is added with
## add_child() outside a layout pass, where the preset resolves to 0x0 and leaves
## the menu behind it visible and clickable straight through. Same reason as
## TitleScreen and PauseScreen.
func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(get_viewport_width(), get_viewport_height())
	# The opener usually has this theme on its own root and a child inherits it —
	# but a test builds these screens standalone, and so would any future caller.
	# Setting it outright costs one Theme and removes the question of who the
	# parent is.
	theme = GardenTheme.build()

	_backdrop = ColorRect.new()
	_backdrop.name = BACKDROP_NAME
	_backdrop.color = Color(GardenTheme.INK, BACKDROP_ALPHA)
	_backdrop.position = Vector2.ZERO
	_backdrop.size = size
	add_child(_backdrop)

	_add_paper()
	_build_contents()
	_warn_if_footer_is_flush()
	# The overlay makes the surface it opened over inert ITSELF, so no opener has to
	# remember to — which is the half that got forgotten. DERIVED from this node's
	# parent, so nothing is declared at a call site and a button added to that surface
	# later is covered without anyone editing a list. See hold_inert().
	#
	# Before _focus_default(), not after: a menu button that currently holds focus is
	# dropped by going FOCUS_NONE, and the Back button should be what picks it up.
	hold_inert(interactive_under(get_parent(), self))
	_focus_default()

	# CHECKED, not assumed: every overlay is `new()`/`build()` + `add_child()` on
	# open and `queue_free()` on close (TitleScreen._open_keys / _close_keys and
	# PauseScreen's three pairs), so the CONTENT is rebuilt every time it is shown
	# and a resize between two openings costs nothing. That is an argument about
	# the NEXT open, not about this one. These screens are read screens -- the
	# Options dials, the Keys table, the Notebook -- and stay up for as long as the
	# player is reading them; the pause card holds one open over a paused run,
	# which is the single most likely moment for someone to resize or maximise a
	# window. So the covering layer does need the signal.
	#
	# It reaches the surface while the tree is PAUSED, which matters here: signal
	# emission is not gated by `SceneTree.paused`, only `_process` and input are.
	var vp: Viewport = get_viewport()
	if vp != null and not vp.size_changed.is_connected(_apply_viewport_layout):
		vp.size_changed.connect(_apply_viewport_layout)


## The overlay's covering layer, re-derived. Deliberately NOT the content.
##
## What must track the window is the pair that has to reach its edges: this
## Control's own rect and the Backdrop's. A Backdrop that stops short of a widened
## window is not cosmetic -- `PauseScreen`'s is `MOUSE_FILTER_STOP` exactly so the
## board underneath cannot be played through a pause, and the strip it stops short
## of is live, clickable board.
##
## The content is a FIXED-SIZE COMPOSITION and stays one. Its paper is centred
## through `paper_left()`, which is live, so re-centring on resize would mean
## re-running each screen's builder -- and that would discard a Keys row mid-capture
## and move focus out from under the player. The paper stays where it was opened,
## off-centre until the screen is next opened, and that is a deliberately smaller
## wrong than the alternative. See the report on plant-tower-defense-nrup for the
## follow-up that would close it properly (translate the built composition by the
## delta rather than rebuild it).
func _apply_viewport_layout() -> void:
	# `size_changed` outlives the build -- a viewport resized while this overlay is
	# mid-teardown -- so the guard is real rather than defensive dressing.
	if _backdrop == null or not is_instance_valid(_backdrop):
		return
	size = Vector2(get_viewport_width(), get_viewport_height())
	_backdrop.position = Vector2.ZERO
	_backdrop.size = size


## Where the paper sits, in viewport coordinates. Everything a screen draws is
## placed against it, and the suite asserts every visible Control is inside it.
func panel_rect() -> Rect2:
	return Rect2()


## The screen's own content. Called with the backdrop and the paper already up.
func _build_contents() -> void:
	pass


## The sheet the content is drawn on. Overridable for the one screen whose paper
## is not a Panel — NotebookScreen draws a ruled two-page spread.
##
## MOUSE_FILTER_IGNORE: the paper is decoration, and a Panel that stopped the
## mouse would eat clicks aimed at whatever is drawn over it.
func _add_paper() -> void:
	var panel: Rect2 = panel_rect()
	if panel.size.x <= 0.0 or panel.size.y <= 0.0:
		return
	var paper := Panel.new()
	paper.name = PAPER_NAME
	paper.position = panel.position
	paper.size = panel.size
	paper.add_theme_stylebox_override("panel", GardenTheme.paper_panel())
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)


## Where keyboard focus lands when the overlay opens. The Back button by default,
## because it is the way out and every overlay has one.
func _focus_default() -> void:
	if _back_button != null and is_instance_valid(_back_button):
		_back_button.grab_focus()


# -- what is underneath goes inert --------------------------------------------


## Focus mode and mouse filter over a list of controls, in ONE place.
##
## The eight lines `Hud.set_active`, `PauseScreen._set_card_active` and
## `TitleScreen._set_menu_active` had each written out separately, each with its own
## copy of the paragraph explaining why the mouse filter goes as well as the focus.
## The class header above carries that paragraph now, once.
##
## Static, and takes a plain `Array` rather than `Array[Button]`, so a caller
## holding `Array[Button]`, `Array[BaseButton]` or `Array[Control]` passes it
## straight in. A non-Control entry is skipped rather than crashing the caller: the
## lists that reach here are collected from live trees.
static func set_controls_active(controls: Array, active: bool) -> void:
	var mode: Control.FocusMode = Control.FOCUS_ALL if active else Control.FOCUS_NONE
	var filter: Control.MouseFilter = (Control.MOUSE_FILTER_STOP if active
		else Control.MOUSE_FILTER_IGNORE)
	for entry: Variant in controls:
		if not is_instance_valid(entry):
			continue
		var control := entry as Control
		if control == null:
			continue
		control.focus_mode = mode
		control.mouse_filter = filter


## Every `BaseButton` under `root`, minus everything inside `except`.
##
## DERIVED, not listed. The three copies this replaces each walked a list its own
## screen kept — `Hud.interactive_controls()`, `PauseScreen._buttons`,
## `TitleScreen.menu_buttons()` — and a list is a thing a new button gets left out of
## with nothing to say so. What an overlay covers is not a list: it is whatever sits
## under the node it was added to, which the tree already knows.
##
## `except` is skipped WITH ITS WHOLE SUBTREE, so an overlay never makes its own Back
## button inert. An overlay that did would be a screen with no way out of it, which
## is the same failure `PROCESS_MODE_ALWAYS` exists to prevent one layer down.
##
## `BaseButton` rather than `Control`: a Label or a Panel underneath is already
## unfocusable, and a blanket `Control` sweep would be a much larger set restored
## from a much larger snapshot for no behaviour.
static func interactive_under(root: Node, except: Node) -> Array[BaseButton]:
	var out: Array[BaseButton] = []
	if root == null or not is_instance_valid(root):
		return out
	for child: Node in root.get_children():
		if child == except:
			continue
		var button := child as BaseButton
		if button != null:
			out.append(button)
		out.append_array(interactive_under(child, except))
	return out


## Holds `controls` inert until this overlay closes, remembering what each of them
## was first.
##
## **The remembering is the part the three copies did not do.** They restored a
## DEFAULT — `FOCUS_ALL` / `MOUSE_FILTER_STOP` — so a control deliberately left
## unfocusable or click-through before the overlay opened came back live, and
## nothing would have said so. Every surface covered today happens to be
## all-default buttons, which is exactly why that would go unnoticed until it
## didn't.
##
## Idempotent per control: one already held keeps its ORIGINAL snapshot rather than
## being re-recorded as inert. That matters while `TitleScreen._set_menu_active`
## still runs around this one — a second snapshot taken after the first made
## everything `FOCUS_NONE` would turn the release into a no-op and leave the menu
## dead behind a closed notebook.
func hold_inert(controls: Array) -> void:
	for entry: Variant in controls:
		if not is_instance_valid(entry):
			continue
		var control := entry as Control
		if control == null or _is_held(control):
			continue
		_held.append({
			"control": control,
			"focus": control.focus_mode,
			"filter": control.mouse_filter,
		})
	set_controls_active(controls, false)


func _is_held(control: Control) -> bool:
	for entry: Dictionary in _held:
		if entry["control"] == control:
			return true
	return false


## Hands back everything this overlay took, exactly as it found it.
##
## Idempotent, and called from two places on purpose: `close()`, which is the
## intended way out, and `_exit_tree()`, which is the backstop for an overlay freed
## some other way — `Game.resume_run()` frees the whole pause layer with an overlay
## possibly still open over the card. "The opener forgot" is what this entire class
## of bug is made of (plant-tower-defense-csrc), so the overlay does not depend on
## being asked.
func release_inert() -> void:
	for entry: Dictionary in _held:
		var held: Variant = entry["control"]
		# Checked before it is typed: assigning a previously-freed instance to a
		# `Control`-typed local is itself a runtime error, so the guard cannot come
		# after the cast. A held control CAN be freed before this runs — teardown frees
		# the surface and the overlay sitting on it in the same pass.
		if not is_instance_valid(held):
			continue
		var control := held as Control
		if control == null:
			continue
		# Straight from the Dictionary into the property, with no enum-typed local in
		# between: these two came OUT of the same properties, so the engine's own
		# setter is the only conversion that has to be right.
		control.focus_mode = entry["focus"]
		control.mouse_filter = entry["filter"]
	_held.clear()


## The way out: hands back what this overlay covered, then frees itself.
##
## Openers call this instead of `queue_free()`, and the difference is a frame.
## `queue_free()` defers deletion to the end of the frame, so the `_exit_tree()`
## restore lands AFTER the opener's own `grab_focus()` — and `grab_focus()` on a
## control still sitting at `FOCUS_NONE` does nothing but push an error. Closing
## through here means the surface is live again on the line the caller asked for it,
## which is what lets a close path be `close()` + `grab_focus()` and nothing else.
func close() -> void:
	release_inert()
	queue_free()


## The backstop, for an overlay that went away without anyone calling `close()`.
## See `release_inert()`.
func _exit_tree() -> void:
	release_inert()


# -- the pieces a screen assembles itself out of ------------------------------


## The screen's title, centred across the paper.
func add_heading(text: String, y: float) -> Label:
	var panel: Rect2 = panel_rect()
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = text
	heading.position = Vector2(panel.position.x, y)
	heading.size = Vector2(panel.size.x, 40.0)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", GardenTheme.INK)
	add_child(heading)
	return heading


## The `Note` line under the heading, and the field behind it. One Label for the
## instruction, the prompt and the refusal, so a rejected keystroke cannot be
## silent — see KeyBindingScreen.capture().
func add_note_label(text: String, y: float) -> Label:
	var panel: Rect2 = panel_rect()
	_note = Label.new()
	_note.name = NOTE_NAME
	_note.text = text
	_note.position = Vector2(panel.position.x, y)
	_note.size = Vector2(panel.size.x, 24.0)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 15)
	_note.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.65))
	# The box is the budget: a longer sentence is trimmed rather than allowed to
	# run off the paper.
	_note.clip_text = true
	_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_note)
	return _note


## One text cell of a row — the left column that says what it is, or the middle
## one that says which key it is on. The two are the same Label in two dresses:
## same font size, same clip-and-ellipsis budget, different colour and alignment.
##
## The screens keep their own column x offsets, because the two column layouts
## differ by a few pixels and each of those numbers is documented where it is
## used. What is shared is the styling, which is what drifted.
func add_row_label(node_name: String, text: String, at: Vector2, box: Vector2,
		color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	# ORDER MATTERS, and this helper had it backwards. `Control.set_size` clamps to
	# `get_combined_minimum_size()`, and a Label's minimum width is its WHOLE TEXT
	# until clip_text or a trimming overrun behaviour is set -- measured at whatever
	# font size is in effect at that moment. Assigning `size` first, then the font
	# size and clip_text, means the assigned box loses to a minimum measured at the
	# theme default (16 here by luck, not by construction), and the later overrides
	# lower the minimum without ever shrinking the box back.
	#
	# PauseScreen._build_key_list carries the same comment because the same bug put a
	# legend row on the backdrop over a live board and was fixed THERE -- at one call
	# site, while this shared helper, which two screens build every row through, kept
	# it. A fix applied where it was found rather than where it lives is a fix that
	# leaves the defect in the shared thing.
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", 16)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.position = at
	label.size = box
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


## The row's button, named `RowButton%d` and registered for the footer-gap rule.
## The caller sets the text and connects it: what a row's button does is the one
## thing the two screens do not share.
func add_row_button(index: int, at: Vector2) -> Button:
	var button := Button.new()
	button.name = "RowButton%d" % index
	button.position = at
	button.size = ROW_BUTTON_SIZE
	add_child(button)
	_row_buttons.append(button)
	return button


## The way out, wired to `back_requested` — the screen never learns who opened it.
func add_back_button(at: Vector2, box: Vector2 = BACK_BUTTON_SIZE) -> Button:
	_back_button = Button.new()
	_back_button.name = BACK_BUTTON_NAME
	_back_button.text = BACK_TEXT
	_back_button.position = at
	_back_button.size = box
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	add_child(_back_button)
	return _back_button


# -- the layout rule ----------------------------------------------------------


## The y a footer row sits at, derived from the paper rather than written down
## per screen.
func footer_y() -> float:
	var panel: Rect2 = panel_rect()
	return panel.position.y + panel.size.y - FOOTER_HEIGHT - FOOTER_INSET


## The Back button, or null on a screen that somehow built none.
func back_button() -> Button:
	return _back_button


## Whether the footer-gap rule applies at all. A screen with no rows — the
## notebook — has nothing for the footer to stand clear of.
func has_rows() -> bool:
	return not _row_buttons.is_empty()


## Clear space between the foot of the last row and the top of the footer, or
## -1.0 when the rule does not apply. See FOOTER_GAP for why this is a distance
## and not a boolean "do they overlap".
func footer_clearance() -> float:
	if not has_rows() or _back_button == null:
		return -1.0
	var last: Button = _row_buttons[_row_buttons.size() - 1]
	return _back_button.position.y - (last.position.y + last.size.y)


## Says so at build time, in the one place that sees every overlay. The suite
## asserts the same rule; this is the half that fires in a live game the moment a
## constant is nudged, rather than at the next headless run.
func _warn_if_footer_is_flush() -> void:
	if not has_rows() or _back_button == null:
		return
	var gap: float = footer_clearance()
	if gap < FOOTER_GAP:
		push_error(("%s: the footer stands %.1fpx below the last row, under the %.1fpx "
			+ "FOOTER_GAP. Grow the panel or drop the row pitch — a flush footer "
			+ "intersects nothing and is still wrong.") % [get_script().resource_path, gap, FOOTER_GAP])


# -- the viewport ------------------------------------------------------------
#
# TWO questions, two names -- see ScreenMetrics for the whole argument. These two
# used to read ProjectSettings, with a comment saying it was because `_ready()`
# sizes the overlay before it is necessarily inside a sized viewport. That
# condition is real and is now the FALLBACK inside `ScreenMetrics.live_size()`
# rather than the answer for every window.


## The canvas this overlay has to cover. Live: an overlay that stops short of the
## window leaves a strip of whatever is behind it visible and, on the pause card,
## clickable.
func get_viewport_width() -> int:
	return ScreenMetrics.live_width(self)


func get_viewport_height() -> int:
	return ScreenMetrics.live_height(self)


## The canvas the overlay's CONTENT was composed on. Every row budget on these
## screens -- `OptionsScreen.rows_capacity()`, `KeyBindingScreen.panel_height()`'s
## nine-verb ceiling -- is a statement about this number and must not follow the
## window: `stretch/aspect="expand"` never produces a canvas smaller than it, so
## it is the worst case a budget has to survive.
static func design_width() -> int:
	return ScreenMetrics.design_width()


static func design_height() -> int:
	return ScreenMetrics.design_height()


## The left edge of a `width`-wide paper, centred on the live canvas. All three
## overlays centre their paper; two of them had the sum baked into a constant at
## the design width (`OptionsScreen.PANEL.x`, `NotebookScreen.PANEL.x`) and one
## computed it (`KeyBindingScreen.panel_rect()`). Same number at 1152, and a rigid
## translation of the whole composition anywhere else -- so every offset measured
## from the paper's left edge is untouched by it.
func paper_left(width: float) -> float:
	return ScreenMetrics.centred_left(self, width)


## Escape closes. Handled in `_input` rather than `_unhandled_input`: a focused
## Button consumes keys for focus navigation before an unhandled handler ever sees
## them, and the arrow keys are verbs on two of these screens.
##
## A subclass that needs the keystroke first overrides this and calls
## `super._input(event)` for everything it did not answer — see
## KeyBindingScreen._input, which swallows every key while a row is listening.
func _input(event: InputEvent) -> void:
	# Both shapes a verb can arrive in — see Game._unhandled_input for why an
	# InputEventKey-only narrowing makes these unreachable from the devtools bridge.
	if not (event is InputEventKey or event is InputEventAction):
		return
	if event.is_action_pressed(KeyBindings.ACTION_BACK):
		back_requested.emit()
		get_viewport().set_input_as_handled()
