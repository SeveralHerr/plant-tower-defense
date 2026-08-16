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
##
## The bracket geometry lives in _draw_brackets() rather than inline in _draw()
## so PlacementPreview can borrow it: "where this plant would go" and "which
## plant is selected" are the same shape on purpose, one dim and one bright, so
## the hover cue reads as a promise of the selected state rather than as an
## unrelated second overlay.

const HALF: float = 22.0
const ARM: float = 8.0
const MARKER_COLOR := Color(1.0, 0.95, 0.35, 0.9)
const LINE_WIDTH: float = 2.0

const _SIGNS: Array[float] = [-1.0, 1.0]

## Subclass knobs. Vars rather than consts precisely so a subclass reuses the
## geometry instead of copying the numbers — see PlacementPreview.
var marker_color: Color = MARKER_COLOR
var half: float = HALF
var arm: float = ARM
var line_width: float = LINE_WIDTH


func _draw() -> void:
	_draw_brackets()


func _draw_brackets() -> void:
	for sx: float in _SIGNS:
		for sy: float in _SIGNS:
			var corner := Vector2(half * sx, half * sy)
			draw_line(corner, corner + Vector2(-arm * sx, 0.0), marker_color, line_width)
			draw_line(corner, corner + Vector2(0.0, -arm * sy), marker_color, line_width)
