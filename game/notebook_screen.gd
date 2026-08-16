class_name NotebookScreen
extends Control

## "A screen showing the original hand-drawn image1.jpg-image6.jpg beside the
## finished sprite for each plant." The drawings are the source material the
## whole game was built from; PAGES below is the mapping of which drawing shows
## which plant, plus what that page actually decided.
##
## The first version of this screen was a slideshow: two bare 320x320 textures
## side by side on flat INK, one green caption, three default-theme buttons. It
## answered "which drawing" and nothing else — not which pane was which, not
## what the drawing settled, not how far through you were. So the content here
## is now the point and the layout serves it: a paper spread (NotebookPage), a
## labelled pane on each side, and a real note per page.
##
## Node paths are a contract. `Backdrop`, `Drawing`, `Sprite` and `PageLabel`
## are asserted by test_selftest.gd and reachable from the devtools bridge, so
## they stay direct children of this node even though the paper panel is drawn
## behind them. Nothing here is in a Container; see TitleScreen for why that is
## deliberate on a fixed-size fullscreen menu.

signal back_requested

## Panel rect, in viewport coordinates. Everything else is placed against it.
const PANEL := Rect2(76.0, 32.0, 1000.0, 584.0)
const PAGE_SPLIT: float = 576.0

## Centre of each page's *writing* area — the paper right of its red margin
## rule, which NotebookPage draws at MARGIN_X into each half. Centring content
## on the raw page instead put the drawing's frame straight over the left margin
## line and started the note text on the wrong side of the right one.
const LEFT_CENTRE: float = 358.0
const RIGHT_CENTRE: float = 858.0
## Width of a centred run of text on either page. Both writing areas are 436
## wide; this leaves a little air at each edge.
const TEXT_WIDTH: float = 420.0

const DRAWING_FRAME := Rect2(LEFT_CENTRE - 188.0, 140.0, 376.0, 316.0)
const DRAWING_BOX := Rect2(LEFT_CENTRE - 180.0, 148.0, 360.0, 300.0)
const SPRITE_BOX := Rect2(RIGHT_CENTRE - 100.0, 138.0, 200.0, 190.0)

## 112, not the 122 this started at: at 122 the pane label's box ran 5px into
## the top of DRAWING_FRAME. Caught by the HUD occlusion audit, which is the
## only check that looks at a *pair* of Controls — `findings` reported 0 over
## the same frame, correctly, because each of the two fits its own box.
const PANE_LABEL_Y: float = 112.0
const SOURCE_Y: float = 462.0
const PLANT_HEADING_Y: float = 336.0
## Six wrapped lines at font 14. The first pass gave this 108px, and the longest
## note lost its final clause to an ellipsis on a page that had 90px of unused
## paper below it — see test_notebook_every_page_carries_a_caption_and_a_note
## for the character budget this height buys.
const NOTE_RECT := Rect2(RIGHT_CENTRE - 200.0, 372.0, 400.0, 142.0)
const FOOTER_Y: float = 544.0
const FOOTER_HEIGHT: float = 40.0
const PAGER_WIDTH: float = 110.0

## Largest whole-number enlargement a sprite is drawn at inside SPRITE_BOX.
##
## Filling the box was the obvious thing and it was wrong: the sprites are not
## all one size. Every plant is 128x128 at 2x, but `corn_kernel@2x` is 32x32,
## and stretching that to a 190px box turned the kernel page into a yellow
## smear. A whole-number factor keeps the pixel grid intact.
##
## The cap is 2 rather than the 4 that would make every page draw at the same
## 128px, because 4x magnifies the kernel's own antialiasing into visible mush —
## and because the kernel *is* smaller than the cob that fires it. Letting the
## two pages differ in size states that instead of hiding it.
const MAX_SPRITE_ZOOM: float = 2.0

## Fade-and-nudge when the page changes. Short: this is a page turn, not a
## transition, and anything slower makes Next feel unresponsive when held.
const TURN_SECONDS: float = 0.18
const TURN_NUDGE: float = 22.0
const TURN_START_ALPHA: float = 0.15

## Five pages, not six, because there are only five drawings.
##
## `image1.jpg` and `image6.jpg` are the same photograph — byte for byte, same
## SHA — and the table this replaced listed both, so the notebook showed one
## picture twice under two captions that described different things ("first
## sketch" and "the kernel volley", neither of which is what the photo shows).
## Nothing caught it: both paths exist, both load, and the paths themselves
## differ, so a duplicate check on the strings would have passed too. See
## test_no_two_notebook_pages_show_the_same_drawing, which compares the bytes.
const PAGES: Array[Dictionary] = [
	{
		"drawing": "res://image1.jpg",
		"sprite": "res://assets/sprites/corn_cobbler.png",
		"caption": "Corn Cobbler",
		"note": "The portrait the whole game starts from: the name spelled out at the top and the cob drawn underneath with a proper face. Everything in the sprite comes from here — the grid of kernels, two dot eyes, leaves splayed at the base, and a plant that grows out of the ground rather than standing on it.",
	},
	{
		"drawing": "res://image2.jpg",
		"sprite": "res://assets/sprites/seed_packet.png",
		"caption": "The brief",
		"note": "\"I want it to be a tower defence game. Plants fight bugs. You get one free plant to start, some aren't free. You have to buy plant seeds to get plants.\" Four sentences, and every one of them is a rule the game still runs on.",
	},
	{
		"drawing": "res://image3.jpg",
		"sprite": "res://assets/sprites/corn_kernel.png",
		"caption": "The bunch-of-corn upgrade",
		"note": "An arrow from one cob to another, \"bunch of corn\" written at the top, and a scatter of D-shapes flying off to the right. That is the whole upgrade path — one kernel becomes several at once — and the D-shapes became the kernel sprite.",
	},
	{
		"drawing": "res://image4.jpg",
		"sprite": "res://assets/sprites/chomp_flower.png",
		"caption": "Chomp Flower",
		"note": "Named in the corner, drawn with a jaw full of triangular teeth, and specced in two bullet points: \"eats small pests easily\", \"takes a while eating bigger pests\". The only plant that arrived with its own balance rules already written down.",
	},
	{
		"drawing": "res://image5.jpg",
		"sprite": "res://assets/sprites/chomp_flower_eating.png",
		"caption": "Eating takes time",
		"note": "Three poses on one page: mouth open, a pest labelled with an arrow, then the flower shut with its eyes X-ed out mid-chew. Chewing is not instant — that is what leaves a lane briefly open — so the mid-bite pose is a separate sprite, not a tint.",
	},
]

var _page: int = 0
var _paper: NotebookPage
var _drawing_rect: TextureRect
var _sprite_rect: TextureRect
var _caption: Label
var _note: Label
var _source: Label
var _page_label: Label
var _next_button: Button


func _ready() -> void:
	# Explicit position+size, not an anchor preset — see TitleScreen._ready()
	# for why: this Control was added straight to another Control with
	# add_child() outside any layout pass, and PRESET_FULL_RECT resolved to
	# 0x0, leaving the title screen's own buttons visible right through it.
	position = Vector2.ZERO
	size = Vector2(get_viewport_width(), get_viewport_height())
	# The title screen already puts this theme on its own root, and a child
	# inherits it — but a test builds this screen standalone, and so would any
	# future caller. Setting it outright costs one Theme and removes the
	# question of who the parent is.
	theme = GardenTheme.build()

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	# Not fully opaque any more: the title screen's garden shows through
	# faintly, so the notebook reads as something held up in front of the game
	# rather than a different program. Still dark enough that nothing behind it
	# competes for attention, and still a MOUSE_FILTER_STOP ColorRect, so the
	# buttons underneath stay unclickable.
	backdrop.color = Color(GardenTheme.INK, 0.88)
	backdrop.position = Vector2.ZERO
	backdrop.size = size
	add_child(backdrop)

	_paper = NotebookPage.new()
	_paper.name = "Paper"
	_paper.position = PANEL.position
	_paper.size = PANEL.size
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_paper)
	_paper.page_count = PAGES.size()

	_build_header()
	_build_left_page()
	_build_right_page()
	_build_footer()

	go_to(0)
	_next_button.grab_focus()


func _build_header() -> void:
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "Designer's Notebook"
	heading.position = Vector2(PANEL.position.x, 52.0)
	heading.size = Vector2(PANEL.size.x, 40.0)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", GardenTheme.INK)
	add_child(heading)

	var subhead := Label.new()
	subhead.name = "Subheading"
	# Counted from PAGES, not written out. The hard-coded "Six pages" outlived
	# the sixth page by about four minutes.
	subhead.text = "%d pages of pencil, and what each one turned into." % PAGES.size()
	subhead.position = Vector2(PANEL.position.x, 94.0)
	subhead.size = Vector2(PANEL.size.x, 22.0)
	subhead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subhead.add_theme_font_size_override("font_size", 14)
	subhead.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.6))
	add_child(subhead)

	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.text = "← Back"
	back_button.position = Vector2(100.0, 52.0)
	# 40 tall, not 38: `findings` gates interactive Controls at 40x40 and is
	# right to — a 38px button is a 38px touch target.
	back_button.size = Vector2(108.0, 40.0)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	add_child(back_button)


func _build_left_page() -> void:
	add_child(_pane_label("DrawingPaneLabel", "The drawing", LEFT_CENTRE))

	# A matte behind the photo. The drawings are photographs of white paper on
	# cream stock, so without a frame the two whites bleed into each other and
	# the drawing has no edge at all.
	var frame := Panel.new()
	frame.name = "DrawingFrame"
	frame.position = DRAWING_FRAME.position
	frame.size = DRAWING_FRAME.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_box := StyleBoxFlat.new()
	frame_box.bg_color = Color(1.0, 0.996, 0.98)
	frame_box.set_border_width_all(2)
	frame_box.border_color = Color(GardenTheme.INK, 0.55)
	frame_box.shadow_color = Color(0, 0, 0, 0.22)
	frame_box.shadow_size = 8
	frame_box.shadow_offset = Vector2(0, 4)
	frame.add_theme_stylebox_override("panel", frame_box)
	add_child(frame)

	# EXPAND_IGNORE_SIZE, not EXPAND_FIT_WIDTH_PROPORTIONAL: the latter makes
	# the control's own resolved size follow the texture's aspect against
	# whatever it thinks its available width is, which outside a Container
	# blew this up to fill most of the screen rather than respecting the
	# explicit box below (caught by a live screenshot, not any test).
	_drawing_rect = TextureRect.new()
	_drawing_rect.name = "Drawing"
	_drawing_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drawing_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drawing_rect.position = DRAWING_BOX.position
	_drawing_rect.size = DRAWING_BOX.size
	_drawing_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drawing_rect)

	_source = Label.new()
	_source.name = "SourceLabel"
	_source.position = Vector2(LEFT_CENTRE - TEXT_WIDTH / 2.0, SOURCE_Y)
	_source.size = Vector2(TEXT_WIDTH, 20.0)
	_source.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_source.add_theme_font_size_override("font_size", 13)
	_source.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.45))
	add_child(_source)


func _build_right_page() -> void:
	add_child(_pane_label("SpritePaneLabel", "In the game", RIGHT_CENTRE))

	_sprite_rect = TextureRect.new()
	_sprite_rect.name = "Sprite"
	_sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# STRETCH_SCALE, not KEEP_ASPECT_CENTERED: the control is resized to a whole
	# multiple of the texture by _fit_sprite() below, so there is nothing left
	# for the stretch mode to letterbox and a fractional scale can never sneak
	# back in through a rounding difference between the two.
	_sprite_rect.stretch_mode = TextureRect.STRETCH_SCALE
	# The sprites are 64px art shown here at ~200px. Bilinear filtering at that
	# ratio turns the outlines — which the style contract in art_src/STYLE.md
	# defines as a darker shade of the fill, one pixel wide — into a smear.
	_sprite_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite_rect.position = SPRITE_BOX.position
	_sprite_rect.size = SPRITE_BOX.size
	_sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sprite_rect)

	_caption = Label.new()
	_caption.name = "Caption"
	_caption.position = Vector2(RIGHT_CENTRE - TEXT_WIDTH / 2.0, PLANT_HEADING_Y)
	_caption.size = Vector2(TEXT_WIDTH, 30.0)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.add_theme_color_override("font_color", GardenTheme.LEAF_DARK)
	add_child(_caption)

	_note = Label.new()
	_note.name = "NoteLabel"
	_note.position = NOTE_RECT.position
	_note.size = NOTE_RECT.size
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 14)
	_note.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.8))
	# The notes vary in length by ~80 characters. Without this the longest one
	# runs past the bottom of the page and over the pager; the box is the
	# budget, and text that will not fit gets an ellipsis rather than the paper.
	_note.clip_text = true
	_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_note)


func _pane_label(node_name: String, text: String, centre_x: float) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = Vector2(centre_x - TEXT_WIDTH / 2.0, PANE_LABEL_Y)
	label.size = Vector2(TEXT_WIDTH, 20.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.5))
	return label


func _build_footer() -> void:
	var prev_button := Button.new()
	prev_button.name = "PrevButton"
	prev_button.text = "‹ Prev"
	prev_button.position = Vector2(PAGE_SPLIT - PAGER_WIDTH - 80.0, FOOTER_Y)
	prev_button.size = Vector2(PAGER_WIDTH, FOOTER_HEIGHT)
	prev_button.pressed.connect(func() -> void: go_to(_page - 1))
	add_child(prev_button)

	_page_label = Label.new()
	_page_label.name = "PageLabel"
	_page_label.position = Vector2(PAGE_SPLIT - 80.0, FOOTER_Y + 8.0)
	_page_label.size = Vector2(160.0, 24.0)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.7))
	add_child(_page_label)

	_next_button = Button.new()
	_next_button.name = "NextButton"
	_next_button.text = "Next ›"
	_next_button.position = Vector2(PAGE_SPLIT + 80.0, FOOTER_Y)
	_next_button.size = Vector2(PAGER_WIDTH, FOOTER_HEIGHT)
	_next_button.pressed.connect(func() -> void: go_to(_page + 1))
	add_child(_next_button)


## Left/Right turn the page and Escape closes, which is what anyone reading six
## pages will reach for first.
##
## Handled in `_input` rather than `_unhandled_input` on purpose: a focused
## Button consumes `ui_left`/`ui_right` for focus navigation, so by the time
## unhandled input runs the arrow keys are already gone. Only the three keys
## below are swallowed; Tab and Enter still reach the buttons normally.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_LEFT:
			go_to(_page - 1)
		KEY_RIGHT:
			go_to(_page + 1)
		KEY_ESCAPE:
			back_requested.emit()
		_:
			return
	get_viewport().set_input_as_handled()


func get_viewport_width() -> int:
	return ProjectSettings.get_setting("display/window/size/viewport_width", 1152)


func get_viewport_height() -> int:
	return ProjectSettings.get_setting("display/window/size/viewport_height", 648)


## Wraps, so Prev on page 0 and Next on the last page both stay useful instead
## of dead-ending.
##
## The content is applied synchronously and only then animated. A turn that
## swapped the texture in a tween callback would leave `go_to()` returning with
## the old page still on screen — invisible to a player, fatal to a test, and
## exactly the class of bug GardenTheme.animations_enabled() exists to prevent.
func go_to(page: int) -> void:
	var previous: int = _page
	_page = ((page % PAGES.size()) + PAGES.size()) % PAGES.size()
	var entry: Dictionary = PAGES[_page]
	_drawing_rect.texture = load(String(entry["drawing"])) as Texture2D
	_sprite_rect.texture = load(GardenTheme.retina_path(String(entry["sprite"]))) as Texture2D
	_fit_sprite()
	_caption.text = String(entry["caption"])
	_note.text = String(entry["note"])
	_source.text = String(entry["drawing"]).get_file()
	_page_label.text = "%d / %d" % [_page + 1, PAGES.size()]
	_paper.current_page = _page
	if previous != _page:
		_play_turn(_direction(previous, _page))


## Size the sprite to a whole multiple of its texture and centre that inside
## SPRITE_BOX. The control's own rect changes per page, so the invariant worth
## asserting is enclosure and integer scale, not a fixed size — see
## test_notebook_images_stay_inside_their_box.
func _fit_sprite() -> void:
	var texture: Texture2D = _sprite_rect.texture
	if texture == null:
		return
	var source := Vector2(texture.get_width(), texture.get_height())
	var factor: float = floorf(minf(SPRITE_BOX.size.x / source.x, SPRITE_BOX.size.y / source.y))
	factor = clampf(factor, 1.0, MAX_SPRITE_ZOOM)
	var drawn: Vector2 = source * factor
	_sprite_rect.size = drawn
	# Floored, so the control lands on whole pixels. Half a pixel of offset is
	# what puts a seam through point-sampled art.
	_sprite_rect.position = (SPRITE_BOX.position + (SPRITE_BOX.size - drawn) / 2.0).floor()


## +1 for a forward turn, -1 for a backward one, following the shorter way
## round so wrapping 6 -> 1 still nudges forwards.
static func _direction(from_page: int, to_page: int) -> float:
	var forward: int = posmod(to_page - from_page, PAGES.size())
	return 1.0 if forward <= PAGES.size() / 2 else -1.0


func _play_turn(direction: float) -> void:
	if not GardenTheme.animations_enabled():
		return
	var tween := create_tween()
	tween.set_parallel(true)
	for node: Control in [_drawing_rect, _sprite_rect, _caption, _note, _source]:
		tween.tween_property(node, "modulate:a", 1.0, TURN_SECONDS).from(TURN_START_ALPHA)
		tween.tween_property(node, "position:x", node.position.x, TURN_SECONDS) \
			.from(node.position.x + TURN_NUDGE * direction) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)
