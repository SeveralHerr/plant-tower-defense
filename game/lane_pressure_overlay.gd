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


func _draw() -> void:
	for cell: Vector2i in pressure:
		var alpha: float = float(pressure[cell])
		if alpha <= 0.0:
			continue
		var rect := Rect2(Vector2(cell.x, cell.y) * Board.CELL, Vector2(Board.CELL, Board.CELL))
		draw_rect(rect, Color(GardenTheme.DANGER, alpha * 0.5))
