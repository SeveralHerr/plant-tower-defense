class_name TitleBackdrop
extends Control

## The title screen's scenery: dusk sky, a warm glow behind the wordmark, and a
## grass horizon with a band of soil under it.
##
## Drawn rather than authored as an image for two reasons. It has to resize with
## the viewport (the project stretches `canvas_items` on an `expand` aspect, so
## the title screen is one of the few things that genuinely sees a different
## width), and it costs no import, no atlas and no extra megabyte for what is
## eleven `draw_*` calls issued once.
##
## This replaces a single full-screen `ColorRect` in INK. That ColorRect is why
## the title screen read as "unfinished placeholder": a flat fill gives the eye
## no horizon, so the buttons floated in the middle of nothing and the bottom
## third of the screen was visibly empty rather than deliberately empty.
##
## The node keeps the name "Backdrop" and its explicit full-viewport size, both
## of which are asserted by test_title_screen_backdrop_actually_covers_the_viewport.

const SKY_TOP := Color(0.055, 0.078, 0.075)
const SKY_HORIZON := Color(0.157, 0.235, 0.176)
## Two greens: the band at the horizon and the nearer band in front of it.
const GRASS_FAR := Color(0.114, 0.318, 0.176)
const GRASS := Color(0.153, 0.416, 0.227)
const GRASS_LIGHT := Color(0.208, 0.529, 0.290)
const SOIL := Color(0.263, 0.180, 0.118)
const FURROW := Color(0.196, 0.133, 0.086)

## Fraction of the height where the grass starts. The buttons sit well above it
## — see TitleScreen.BUTTON_TOP — so the scenery never competes with them.
const HORIZON: float = 0.74
## Where the soil shows through the grass, as a fraction of the height. Kept
## near the bottom on purpose: the first pass put it at 0.82 and the result was
## a 117px slab of flat brown across the whole foot of the screen, which is the
## same "nothing is happening here" the original flat INK backdrop had.
const SOIL_LINE: float = 0.875
## Enough bands that the gradient reads as smooth at 648px tall and few enough
## that the whole backdrop is one cheap redraw.
const SKY_BANDS: int = 40
## Centre of the warm glow, in fractions of the backdrop, sitting behind the
## wordmark so the title has something to rest on instead of raw dark.
const GLOW_CENTRE := Vector2(0.5, 0.24)
const GLOW_MAX_RADIUS: float = 330.0
const GLOW_MIN_RADIUS: float = 60.0
## Stacked translucent discs, and the count is what decides whether this reads
## as a glow or as a dartboard: seven rings put seven visible steps across 270px
## of radius. Twenty-two is a ~12px step, below where the eye picks the edge out
## against a gradient. Alpha is set so count x alpha stays around 0.22 at the
## core — raising the count without lowering this just makes a brighter disc.
const GLOW_RINGS: int = 22
const GLOW_ALPHA: float = 0.010

## Scallop radius for the grass and soil edges — the same "drawn with a fat
## pencil" edge the sprites use, rather than a ruler-straight boundary.
const SCALLOP_RADIUS: float = 15.0
const SCALLOP_STEP: float = 1.3

const TUFT_SPACING: float = 46.0
const TUFT_WIDTH: float = 13.0
const TUFT_HEIGHT: float = 14.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	var horizon: float = h * HORIZON
	_draw_sky(w, horizon)
	_draw_glow(w, h)
	_draw_ground(w, h, horizon)


func _draw_sky(w: float, horizon: float) -> void:
	var band: float = horizon / float(SKY_BANDS)
	for i: int in SKY_BANDS:
		var t: float = float(i) / float(SKY_BANDS - 1)
		# +1 on the height: adjacent bands must overlap by a pixel or the
		# gradient shows hairline seams wherever the float division rounds down.
		draw_rect(Rect2(0.0, float(i) * band, w, band + 1.0), SKY_TOP.lerp(SKY_HORIZON, t))


func _draw_glow(w: float, h: float) -> void:
	var centre := Vector2(w * GLOW_CENTRE.x, h * GLOW_CENTRE.y)
	var tint := Color(GardenTheme.GOLD, GLOW_ALPHA)
	for i: int in GLOW_RINGS:
		var t: float = float(i) / float(GLOW_RINGS - 1)
		draw_circle(centre, lerpf(GLOW_MAX_RADIUS, GLOW_MIN_RADIUS, t), tint)


func _draw_ground(w: float, h: float, horizon: float) -> void:
	draw_rect(Rect2(0.0, horizon, w, h - horizon), GRASS_FAR)
	_draw_scalloped_edge(w, horizon, GRASS_FAR)
	_draw_tufts(w, horizon, GRASS_LIGHT)

	var soil_top: float = h * SOIL_LINE
	# A second, nearer band of grass. Without it the strip between the horizon
	# and the soil is one 90px slab of a single green — the same flatness the
	# sky gradient exists to avoid, just lower down. The scallop and the tufts
	# on its own edge are what make it read as grass in front of grass rather
	# than as two stripes.
	var near_top: float = lerpf(horizon, soil_top, 0.45)
	draw_rect(Rect2(0.0, near_top, w, h - near_top), GRASS)
	_draw_scalloped_edge(w, near_top, GRASS)
	_draw_tufts(w, near_top, GRASS_LIGHT)

	draw_rect(Rect2(0.0, soil_top, w, h - soil_top), SOIL)
	_draw_scalloped_edge(w, soil_top, SOIL)

	# Furrows: the rows a garden is actually planted in, and the only cue that
	# the soil band has depth rather than being a second flat rectangle.
	var rows: int = 4
	for i: int in rows:
		var y: float = lerpf(soil_top + 16.0, h - 8.0, float(i) / float(rows - 1))
		draw_line(Vector2(0.0, y), Vector2(w, y), FURROW, 2.0)


## Overlapping circles centred on `y`, so the boundary reads as drawn rather
## than as the top edge of a rectangle.
func _draw_scalloped_edge(w: float, y: float, colour: Color) -> void:
	var x: float = -SCALLOP_RADIUS
	while x < w + SCALLOP_RADIUS:
		draw_circle(Vector2(x, y), SCALLOP_RADIUS, colour)
		x += SCALLOP_RADIUS * SCALLOP_STEP


## Blades poking up above the grass line. Heights vary with x through a fixed
## sine rather than an RNG: the backdrop must draw the same picture every run so
## a screenshot diff means a real change.
func _draw_tufts(w: float, line_y: float, colour: Color) -> void:
	var x: float = 0.0
	while x < w:
		var height: float = TUFT_HEIGHT * (0.6 + 0.4 * sin(x * 0.07))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, line_y),
			Vector2(x + TUFT_WIDTH * 0.5, line_y - height),
			Vector2(x + TUFT_WIDTH, line_y),
		]), colour)
		x += TUFT_SPACING
