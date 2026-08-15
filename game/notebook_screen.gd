class_name NotebookScreen
extends Control

## "A screen showing the original hand-drawn image1.jpg-image6.jpg beside the
## finished sprite for each plant." The drawings are the source material the
## whole game was built from; PAGES below is literally todo.md's own mapping
## of which drawing shows which plant.

signal back_requested

const INK := Color(0.12, 0.15, 0.13)
const PAPER := Color(0.925, 0.863, 0.722)
const LEAF := Color(0.180, 0.800, 0.443)

const PAGES: Array[Dictionary] = [
	{"drawing": "res://image1.jpg", "sprite": "res://assets/sprites/corn_cobbler.png", "caption": "Corn Cobbler — first sketch"},
	{"drawing": "res://image2.jpg", "sprite": "res://assets/sprites/seed_packet.png", "caption": "The brief: one free plant, buy the rest with seeds"},
	{"drawing": "res://image3.jpg", "sprite": "res://assets/sprites/corn_cobbler.png", "caption": "Corn Cobbler — the \"bunch of corn\" upgrade"},
	{"drawing": "res://image4.jpg", "sprite": "res://assets/sprites/chomp_flower.png", "caption": "Chomp Flower — the toothy design"},
	{"drawing": "res://image5.jpg", "sprite": "res://assets/sprites/chomp_flower.png", "caption": "Chomp Flower — \"eats small pests easily\""},
	{"drawing": "res://image6.jpg", "sprite": "res://assets/sprites/corn_kernel.png", "caption": "Corn Cobbler — the kernel volley"},
]

var _page: int = 0
var _drawing_rect: TextureRect
var _sprite_rect: TextureRect
var _caption: Label
var _page_label: Label


func _ready() -> void:
	# Explicit position+size, not an anchor preset — see TitleScreen._ready()
	# for why: this Control was added straight to another Control with
	# add_child() outside any layout pass, and PRESET_FULL_RECT resolved to
	# 0x0, leaving the title screen's own buttons visible right through it.
	position = Vector2.ZERO
	size = Vector2(get_viewport_width(), get_viewport_height())
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = INK
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(get_viewport_width(), get_viewport_height())
	add_child(backdrop)

	var width: float = get_viewport_width()
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "Designer's Notebook"
	heading.position = Vector2(0, 24)
	heading.size = Vector2(width, 40)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", PAPER)
	add_child(heading)

	# EXPAND_IGNORE_SIZE, not EXPAND_FIT_WIDTH_PROPORTIONAL: the latter makes
	# the control's own resolved size follow the texture's aspect against
	# whatever it thinks its available width is, which outside a Container
	# blew this up to fill most of the screen rather than respecting the
	# explicit 320x320 box below (caught by a live screenshot, not any test).
	_drawing_rect = TextureRect.new()
	_drawing_rect.name = "Drawing"
	_drawing_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drawing_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drawing_rect.position = Vector2(width / 2.0 - 340, 90)
	_drawing_rect.size = Vector2(320, 320)
	add_child(_drawing_rect)

	_sprite_rect = TextureRect.new()
	_sprite_rect.name = "Sprite"
	_sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite_rect.position = Vector2(width / 2.0 + 20, 90)
	_sprite_rect.size = Vector2(320, 320)
	add_child(_sprite_rect)

	_caption = Label.new()
	_caption.name = "Caption"
	_caption.position = Vector2(0, 424)
	_caption.size = Vector2(width, 30)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 18)
	_caption.add_theme_color_override("font_color", LEAF)
	add_child(_caption)

	var prev_button := Button.new()
	prev_button.name = "PrevButton"
	prev_button.text = "< Prev"
	prev_button.position = Vector2(width / 2.0 - 180, 470)
	prev_button.size = Vector2(100, 40)
	prev_button.pressed.connect(func() -> void: go_to(_page - 1))
	add_child(prev_button)

	_page_label = Label.new()
	_page_label.name = "PageLabel"
	_page_label.position = Vector2(width / 2.0 - 70, 480)
	_page_label.size = Vector2(140, 24)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.add_theme_color_override("font_color", PAPER)
	add_child(_page_label)

	var next_button := Button.new()
	next_button.name = "NextButton"
	next_button.text = "Next >"
	next_button.position = Vector2(width / 2.0 + 80, 470)
	next_button.size = Vector2(100, 40)
	next_button.pressed.connect(func() -> void: go_to(_page + 1))
	add_child(next_button)

	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.text = "Back"
	back_button.position = Vector2(width / 2.0 - 60, 530)
	back_button.size = Vector2(120, 40)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	add_child(back_button)

	go_to(0)


func get_viewport_width() -> int:
	return ProjectSettings.get_setting("display/window/size/viewport_width", 1152)


func get_viewport_height() -> int:
	return ProjectSettings.get_setting("display/window/size/viewport_height", 648)


## Wraps, so Prev on page 0 and Next on the last page both stay useful instead
## of dead-ending.
func go_to(page: int) -> void:
	_page = ((page % PAGES.size()) + PAGES.size()) % PAGES.size()
	var entry: Dictionary = PAGES[_page]
	_drawing_rect.texture = load(String(entry["drawing"])) as Texture2D
	_sprite_rect.texture = load(String(entry["sprite"])) as Texture2D
	_caption.text = String(entry["caption"])
	_page_label.text = "%d / %d" % [_page + 1, PAGES.size()]
