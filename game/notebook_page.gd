class_name NotebookPage
extends Control

## The sheet the Designer's Notebook is printed on: cream stock with a drop
## shadow, blue rules, a red margin down each page, a wire binding through the
## middle, and the page dots at the foot.
##
## The screen it backs used to be two textures floating on a flat dark field
## with a one-line caption under them — a slideshow, not a notebook. Every mark
## here is copied from the actual photographs in `image1.jpg`-`image6.jpg`:
## those are ruled A4 with a red margin and a wire spiral, so the frame around
## them may as well be the same paper.
##
## One node draws all of it. The alternative — a Panel plus ~30 ColorRects for
## rules, margins and rings — is the same picture at thirty times the node
## count, and every one of those would be a Control that `validate-ui` has an
## opinion about.

## Where the ruled area starts and stops, in local Y.
const RULES_TOP: float = 120.0
const RULES_BOTTOM: float = 470.0
const RULE_SPACING: float = 30.0
## Red margin line, in local X, one per page.
const MARGIN_X: float = 64.0
## Binding, in local X — the seam between the two pages.
const BINDING_X: float = 500.0
const BINDING_TOP: float = 110.0
const BINDING_BOTTOM: float = 478.0
const RING_COUNT: int = 12
const RING_RADIUS: float = 7.0

const DOTS_Y: float = 490.0
const DOT_RADIUS: float = 5.0
const DOT_SPACING: float = 20.0

## Which dot is filled. Set by NotebookScreen.go_to(); a plain setter rather
## than a method so the redraw cannot be forgotten at a call site.
var current_page: int = 0:
	set(value):
		current_page = value
		queue_redraw()
var page_count: int = 1:
	set(value):
		page_count = value
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# draw_style_box, not draw_rect: it is the one call that gives rounded
	# corners and the drop shadow together, and it reuses the exact StyleBox the
	# rest of the game's paper is made of.
	draw_style_box(GardenTheme.paper_panel(), Rect2(Vector2.ZERO, size))
	_draw_rules()
	_draw_binding()
	_draw_dots()


func _draw_rules() -> void:
	var rule := Color(GardenTheme.PAPER_RULE, 0.55)
	var y: float = RULES_TOP
	while y <= RULES_BOTTOM:
		# Two runs, not one line across the fold: paper does not rule through a
		# spiral binding, and a single line makes the spread read as one wide
		# page rather than two facing ones.
		draw_line(Vector2(24.0, y), Vector2(BINDING_X - 26.0, y), rule, 1.0)
		draw_line(Vector2(BINDING_X + 26.0, y), Vector2(size.x - 24.0, y), rule, 1.0)
		y += RULE_SPACING

	var margin := Color(GardenTheme.PAPER_MARGIN, 0.5)
	draw_line(Vector2(MARGIN_X, RULES_TOP - 24.0), Vector2(MARGIN_X, RULES_BOTTOM + 20.0), margin, 1.0)
	draw_line(
		Vector2(BINDING_X + MARGIN_X, RULES_TOP - 24.0),
		Vector2(BINDING_X + MARGIN_X, RULES_BOTTOM + 20.0),
		margin, 1.0,
	)


func _draw_binding() -> void:
	draw_line(
		Vector2(BINDING_X, BINDING_TOP), Vector2(BINDING_X, BINDING_BOTTOM),
		Color(GardenTheme.INK_SOFT, 0.35), 2.0,
	)
	var ring := Color(GardenTheme.INK_SOFT, 0.75)
	for i: int in RING_COUNT:
		var t: float = float(i) / float(RING_COUNT - 1)
		var y: float = lerpf(BINDING_TOP + RING_RADIUS, BINDING_BOTTOM - RING_RADIUS, t)
		# An unfilled arc reads as wire; a filled circle reads as a hole punch.
		draw_arc(Vector2(BINDING_X, y), RING_RADIUS, 0.0, TAU, 12, ring, 2.5)


## One dot per page, filled for the page on screen. This is the readout the old
## screen was missing entirely: "1 / 6" tells you where you are, but only a row
## of dots tells you at a glance how much is left.
func _draw_dots() -> void:
	if page_count <= 0:
		return
	var span: float = float(page_count - 1) * DOT_SPACING
	var start: float = size.x / 2.0 - span / 2.0
	for i: int in page_count:
		var centre := Vector2(start + float(i) * DOT_SPACING, DOTS_Y)
		if i == current_page:
			draw_circle(centre, DOT_RADIUS, GardenTheme.LEAF_DARK)
		else:
			draw_arc(centre, DOT_RADIUS, 0.0, TAU, 12, Color(GardenTheme.INK, 0.35), 1.5)
