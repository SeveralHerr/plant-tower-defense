class_name SelectionMarker
extends Node2D

## Corner brackets drawn around a selected plant, independent of whatever the
## plant's own _draw() does.
##
## CornCobbler and ChompFlower each fully override Plant._draw() to paint their
## own overlay (a range ring, a shrinking chew ring) and never call
## super._draw() — so a selection cue placed in Plant._draw() would have been
## silently dropped by exactly the subclasses most likely to want one. That is
## how the Chomp Flower ended up with *no* selection feedback at all: it draws
## no range ring, and selecting it painted nothing. A separate child node with
## its own _draw() sidesteps the problem instead of relying on every current
## and future subclass remembering to chain to the parent implementation.

const HALF: float = 22.0
const ARM: float = 8.0
const MARKER_COLOR := Color(1.0, 0.95, 0.35, 0.9)
const LINE_WIDTH: float = 2.0

const _SIGNS: Array[float] = [-1.0, 1.0]


func _draw() -> void:
	for sx: float in _SIGNS:
		for sy: float in _SIGNS:
			var corner := Vector2(HALF * sx, HALF * sy)
			draw_line(corner, corner + Vector2(-ARM * sx, 0.0), MARKER_COLOR, LINE_WIDTH)
			draw_line(corner, corner + Vector2(0.0, -ARM * sy), MARKER_COLOR, LINE_WIDTH)
