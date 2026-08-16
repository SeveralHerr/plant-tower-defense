class_name GardenTheme
extends RefCounted

## One palette, one Button look, one set of motion rules — shared by the title
## screen and the Designer's Notebook.
##
## Both of those screens used to paint themselves out of locally-declared INK /
## PAPER / LEAF constants and then leave every Button on Godot's default theme,
## which is grey-on-grey. The result was a cream-and-green screen with three
## slate-grey slabs bolted to it: the two halves had no relationship at all.
## Colour lives here so there is exactly one place a shade can be changed, and
## `build()` is what stops a Button from opting out of the palette by default.
##
## Nothing here touches the in-game HUD. That one styles its own Controls
## against the board's constants and is deliberately left alone.

## The dark green-black everything sits on. Same value the HUD uses.
const INK := Color(0.12, 0.15, 0.13)
## One step up from INK, for hairlines and dividers that must not read as black.
const INK_SOFT := Color(0.22, 0.26, 0.23)
const PAPER := Color(0.925, 0.863, 0.722)
const PAPER_DARK := Color(0.851, 0.788, 0.659)
## The blue rule on the notebook paper in image1-image6. Reused literally.
const PAPER_RULE := Color(0.612, 0.714, 0.808)
## And the red margin line down the left of those same pages.
const PAPER_MARGIN := Color(0.847, 0.412, 0.412)
const LEAF := Color(0.180, 0.800, 0.443)
const LEAF_DARK := Color(0.106, 0.463, 0.267)
const GOLD := Color(0.78, 0.62, 0.38)
const SOIL := Color(0.361, 0.243, 0.157)

## Radius/border used by every button and panel, so a screen cannot half-adopt
## the look.
const CORNER: int = 6
const BORDER: int = 2


## A Theme applied to a screen's root Control, inherited by every descendant —
## which is why the Notebook, added as a child of the title screen at runtime,
## does not have to ask for it.
static func build() -> Theme:
	var theme := Theme.new()
	theme.set_stylebox("normal", "Button", _button_box(PAPER, INK))
	theme.set_stylebox("hover", "Button", _button_box(PAPER.lightened(0.12), LEAF))
	theme.set_stylebox("pressed", "Button", _button_box(PAPER_DARK, LEAF_DARK))
	theme.set_stylebox("disabled", "Button", _button_box(Color(PAPER, 0.35), Color(INK, 0.35)))
	# Focus is drawn *over* the state box, so it has to be transparent inside or
	# it repaints the fill and cancels the hover colour out.
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.set_corner_radius_all(CORNER)
	focus.set_border_width_all(3)
	focus.border_color = GOLD
	focus.set_expand_margin_all(2)
	theme.set_stylebox("focus", "Button", focus)

	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_focus_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", Color(INK, 0.45))
	theme.set_font_size("font_size", "Button", 18)
	return theme


static func _button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(CORNER)
	box.set_border_width_all(BORDER)
	box.border_color = border
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


## The notebook's page stock: cream, softly rounded, with an ink hairline so it
## reads as a sheet lying on the dark rather than a hole cut out of it.
static func paper_panel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER
	box.set_corner_radius_all(10)
	box.set_border_width_all(BORDER)
	box.border_color = INK_SOFT
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 14
	box.shadow_offset = Vector2(0, 6)
	return box


## Entrance tweens, hover pops and page cross-fades all ask this first.
##
## Headless has no renderer and pumps frames only when a test explicitly awaits
## one, so an entrance that starts a node at `modulate.a = 0` and relies on a
## Tween to finish the job leaves that node invisible — and, worse, leaves it
## invisible in a way no assertion about `size` or node paths would ever catch.
## Every animation in these screens is therefore an enhancement layered on top
## of an already-correct final state, gated here.
static func animations_enabled() -> bool:
	return DisplayServer.get_name() != "headless"


## Swaps a 1x sprite path for its 2x sibling when one exists.
##
## The notebook blows a 64x64 sprite up to a ~200px box, where the 1x source
## turns to mush under bilinear filtering. `assets/sprites/retina/<name>@2x.png`
## is already generated for every sprite by `tools/render_svg.gd`; this is what
## makes the notebook actually use it.
static func retina_path(sprite_path: String) -> String:
	var base: String = sprite_path.get_file().get_basename()
	var retina: String = "res://assets/sprites/retina/%s@2x.png" % base
	return retina if ResourceLoader.exists(retina) else sprite_path
