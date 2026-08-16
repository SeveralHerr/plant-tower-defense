class_name LanePressureOverlay
extends Node2D

## Paints the "how far did pests get" readout onto the road.
##
## Added as Board's LAST child (see Board._ready) rather than drawn inside
## Board._draw() itself — a parent's own draw commands land on its own canvas
## item, which is recorded *before* its children's, so anything Board painted
## directly would sit underneath the tile sprites `_build_tiles()` adds as
## children and never be seen. A separate, later-added child sidesteps that.

## cell -> alpha (0..1). Set by Board.record_lane_pressure(), read only here.
var pressure: Dictionary = {}

## The road cells no standing plant currently has in range, as a set. Set by
## Board.mark_unaimed_road(), read only here. Empty means "everything the road
## carries is aimed at" — and also, honestly, "nobody has told me yet".
##
## THE SECOND READING ON THE SAME CELLS, and why it is an angle rather than a
## colour. `pressure` says how far pests got. This says whether the garden, as it
## stands right now, points anything at where they got to. Those are opposite
## purchases — upgrade what is already there, or plant something that reaches —
## and until this map arrived the road painted both of them the identical red.
##
## GardenTheme.DANGER is spent three times over (this tint, Game._update_cursor's
## blocked-cell wash, Plant's health bar) and the alpha channel is spent too: it
## carries how MUCH pressure a cell took. So the two free channels left on a
## 64 px cell are texture and orientation, and orientation is the one that costs
## no extra ink. A mirrored hatch inks exactly the same 57% and leaves exactly the
## same 43% bare (see HATCH_ALPHA) — mirror_x() is a reflection, not a redraw —
## so the cursor's flat wash still reads over an off-aim cell exactly as well as
## it reads over an aimed one, which is the property the hatch was built for and
## the one a density or a second hue would have spent.
##
## It also teaches itself without a legend, which is the part a colour could not
## do. Coverage is derived from the plants standing *now*, and Game._refresh
## pushes it on every placement — so a player who drops a Corn Cobbler covering
## the leaking stretch watches the stripes under it rotate, in the prep window,
## with the pressure map still on screen. Placing the plant IS the tutorial.
##
## WHAT THE MARK DOES NOT CLAIM. "Off aim" is exactly "no plant has this cell
## inside its reach" and nothing more. It is not "nothing could have died here":
## a Kernel flies until it leaves the board (Kernel._physics_process) and kills
## the first pest it touches, whoever it was aimed at, so a cob's overshoot
## routinely kills well outside its own 176 px ring. Measured over a four-wave
## run with four cobs at the entry: 7 of the run's kills landed on cells this map
## calls off-aim, against 10 escapes. Game's coverage block calls the derived map
## an upper bound on what happened; the overshoot is the direction that argument
## misses, and it is why nothing here — code or paint — says "fought".
var unaimed: Dictionary = {}

## The second warning channel (plant-tower-defense-e0m), and the one rule behind
## it: **a solid red surface is a live warning; a broken one is a record or a
## recovery.**
##
## This tint used to be a flat `draw_rect` of `GardenTheme.DANGER` over the whole
## cell. So is the hover cursor on a cell you may not build on — Game._update_cursor
## paints `Color(GardenTheme.DANGER, 0.30)` as a flat 64px square at exactly the
## same place. Same hue, same shape, same position, same order of alpha, and the
## two are stacked on the same pixels every time the player hovers the road during
## prep, which is precisely when this readout is meant to be read. That collision
## — not the plant health bar, which can never share a cell with the road because
## plants only stand on buildable ground — is the one the board actually had.
##
## Hatching rather than a fourth hue, because a player who cannot separate these
## reds is not helped by another red. It also survives being covered: a flat wash
## laid on top of stripes still leaves stripes, whereas a flat wash on top of a
## flat wash is one deeper wash and nothing more.
##
## The board's other half of the rule lives on `Plant.HEALTH_BAR_SEGMENTS`: a
## bleeding plant's bar stays solid, a regrowing one is notched.
const HATCH_SPACING: float = 10.0
const HATCH_WIDTH: float = 4.0
## HATCH_SPACING is an intercept step along an axis, so the *perpendicular* gap
## between two stripes is HATCH_SPACING / sqrt(2) = 7.07 px, and a 4 px stripe
## therefore inks 4 / 7.07 = 57% of the cell and leaves 43% bare. 0.85 puts the
## coverage-weighted total at 0.48, against the 0.50 the old flat fill laid down —
## so the road reads at very nearly the strength it always did, and the change is
## a texture rather than a dimming.
##
## The 43% is the number that matters and the one is_hatched() is written to
## measure: it is what stays visible when the cursor's flat wash is painted on top,
## and it is the difference between a second channel and a slightly different red.
const HATCH_ALPHA: float = 0.85


func _draw() -> void:
	for cell: Vector2i in pressure:
		var alpha: float = float(pressure[cell])
		if alpha <= 0.0:
			continue
		var tint := Color(GardenTheme.DANGER, alpha * HATCH_ALPHA)
		var segments: PackedVector2Array = hatch_segments(cell, unaimed.has(cell))
		var i: int = 0
		while i + 1 < segments.size():
			draw_line(segments[i], segments[i + 1], tint, HATCH_WIDTH, true)
			i += 2


## The stripes for one cell, as from/to pairs in this node's own local space —
## which is the Board's, since the overlay sits at the Board's origin.
##
## Pure and static so the texture is assertable without a viewport: a `_draw()`
## body is not, and "is this a texture or a fill" is exactly the claim that has to
## survive somebody later deciding the stripes look better solid.
##
## Intercepts are multiples of HATCH_SPACING in the *board's* space rather than
## per-cell, so the stripes run unbroken across neighbouring road cells and the
## road reads as one hatched ribbon instead of as tiled squares. A stripe is the
## line `x - y = d` clipped to the cell, which for a 45-degree line against an
## axis-aligned square is exact rather than sampled.
##
## `off_aim` mirrors the whole lattice in x — see `unaimed` for what that second
## texture is saying. Mirrored rather than re-derived at the other angle so the
## two textures are the same texture: same stripe count, same 57% ink, same 43%
## bare, same board-wide lattice, and so the mirrored stripes run unbroken across
## neighbouring off-aim cells for exactly the reason the aimed ones do. The seam
## that DOES appear is the one worth having — it falls precisely where the garden
## stops reaching.
static func hatch_segments(cell: Vector2i, off_aim: bool = false) -> PackedVector2Array:
	if off_aim:
		var mirrored := PackedVector2Array()
		# -cell.x - 1 is the cell whose x-span is this cell's reflected about 0,
		# so reflecting the answer back lands it exactly on this cell.
		for point: Vector2 in _aimed_segments(Vector2i(-cell.x - 1, cell.y)):
			mirrored.append(Vector2(-point.x, point.y))
		return mirrored
	return _aimed_segments(cell)


## The unmirrored stripes. Split out only so hatch_segments() can call it twice
## without recursing through its own flag.
static func _aimed_segments(cell: Vector2i) -> PackedVector2Array:
	var out := PackedVector2Array()
	var size: float = float(Board.CELL)
	var x0: float = float(cell.x) * size
	var y0: float = float(cell.y) * size
	# Every intercept whose line can touch this cell at all.
	var lowest: float = x0 - y0 - size
	var highest: float = x0 - y0 + size
	var k: int = int(ceil(lowest / HATCH_SPACING))
	while float(k) * HATCH_SPACING < highest:
		var d: float = float(k) * HATCH_SPACING
		k += 1
		var from_x: float = maxf(x0, y0 + d)
		var to_x: float = minf(x0 + size, y0 + size + d)
		# A line that only clips the corner contributes nothing to draw.
		if to_x - from_x <= 0.0:
			continue
		out.append(Vector2(from_x, from_x - d))
		out.append(Vector2(to_x, to_x - d))
	return out


## Is a board-local `point` inside a stripe? The texture stated as a predicate,
## so a test can assert the thing that actually matters — that the hatch leaves
## gaps, i.e. that it is a texture and not a fill — rather than assert that a
## constant exists.
##
## With `off_aim` it answers for the mirrored texture, which is what lets a test
## assert the two readings differ in something a greyscale screenshot still shows:
## sample one cell under both flags and the ink totals match while the masks do
## not. Same predicate for both, deliberately — a second copy of the arithmetic
## could drift into a second, denser texture and take the 43% with it.
static func is_hatched(point: Vector2, off_aim: bool = false) -> bool:
	var d: float = (-point.x - point.y) if off_aim else (point.x - point.y)
	var nearest: float = round(d / HATCH_SPACING) * HATCH_SPACING
	# Perpendicular distance from the point to the line x - y = nearest (or, for
	# the mirrored texture, to -x - y = nearest, which is the same distance).
	return absf(d - nearest) / sqrt(2.0) <= HATCH_WIDTH * 0.5
