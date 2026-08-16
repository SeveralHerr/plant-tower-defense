class_name SeedGlyph
extends Control

## The payout, drawn as a small travelling disc instead of only a number that
## changes at the top of the screen (plant-tower-defense-o2b).
##
## CompostMeter.collect_at() erases a husk instantly and Game._click_at hands
## the swept value straight to bank.add_seeds(), which lands in the Seeds stat
## — a HUD readout, well away from wherever the click actually landed. A
## queued caption said "Composted a husk for N seeds", but nothing on screen
## carried the payout from the husk's own position to the number it became.
## This is that carry: a disc, sized off HuskLayer.radius_for() so it reads as
## the same husk rather than a generic sparkle, that flies from the click to
## the Seeds label and shrinks as it goes.
##
## A Control under Hud's own CanvasLayer (Hud._fx_layer), not a Node2D on the
## board. The flight crosses from board space to screen space and the two
## endpoints are drawn on different canvases — the husk on Board's, the Seeds
## label on Hud's (layer 10) — so there is no single parent whose local space
## already contains both ends. The board side of that gap is closed once, at
## launch, by Game._on_husk_collected calling Node2D.to_global() on the
## husk's board-local position (the same `_entities.to_global()` trick
## PlacementPreview and SelectionMarker do not need, because they only ever
## draw on the board's own canvas); the HUD side needs no conversion at all,
## since Hud's root Control already fills the viewport at (0, 0) with no
## offset or scale, so a screen pixel and a point in its local space are the
## same point. See Hud.fly_seed_glyph for where both halves meet.
##
## Purely cosmetic. Bank already has the seeds and CompostMeter has already
## forgotten the husk by the time this plays — collect_at() erases and pays
## out before the signal that triggers this even fires — so a game that
## cannot afford the animation (headless, or animations off) drops it with
## nothing left uncounted.

## Where the disc ends up, relative to its start radius — small enough to
## read as "landing", never zero, so it does not blink out a frame early.
const RADIUS_END: float = 3.0
const FLIGHT_SECONDS: float = 0.5
## The same gold HuskLayer's rings brighten toward and Hud.COMPOST already
## uses — a flying husk payout and a resting one should read as the same
## substance, not a second currency's colour.
const COLOR := GardenTheme.GOLD

var _radius: float = 0.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius, COLOR)


## Starts the flight and frees this node when it lands. `from` and `to` are
## both in this node's parent's local space — screen pixels, once Hud's own
## full-rect root is the parent. `start_radius` is normally
## HuskLayer.radius_for(value), so the disc opens at the size the husk was
## actually drawn.
func launch(from: Vector2, to: Vector2, start_radius: float) -> void:
	# A plain Control defaults to MOUSE_FILTER_STOP, which would make a
	# travelling decoration the thing a click under it hits during the half
	# second it is on screen. It is never meant to be interactive.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = from
	_radius = start_radius
	queue_redraw()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position", to, FLIGHT_SECONDS)
	tween.tween_method(_set_radius, start_radius, RADIUS_END, FLIGHT_SECONDS)
	tween.chain().tween_callback(queue_free)


func _set_radius(r: float) -> void:
	_radius = r
	queue_redraw()
