class_name HuskLayer
extends Node2D

## Pure view over CompostMeter — draws whatever it reports, owns none of the
## data itself, so there is never a second copy of "which husks exist" to
## drift out of sync with what a click can actually collect.

var compost: CompostMeter = null


func _process(_delta: float) -> void:
	if compost != null:
		queue_redraw()


func _draw() -> void:
	if compost == null:
		return
	for h: Dictionary in compost.husks():
		var pos: Vector2 = h["position"]
		var frac: float = clampf(float(h["life"]) / CompostMeter.HUSK_LIFETIME, 0.0, 1.0)
		draw_circle(pos, 9.0, Color(0.64, 0.45, 0.25, 0.35 + 0.35 * frac))
		draw_arc(pos, 12.0, 0.0, TAU * frac, 16, Color(0.98, 0.85, 0.40, 0.9), 2.0, true)
