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

## The name Plant gives this node. A contract: test_selftest.gd looks it up by this
## path and the devtools bridge can read it the same way, neither of which works
## against Godot's auto-generated `@SelectionMarker@31`.
const NODE_NAME := "SelectionMarker"

const HALF: float = 22.0
const ARM: float = 8.0
const MARKER_COLOR := Color(1.0, 0.95, 0.35, 0.9)
const LINE_WIDTH: float = 2.0

const _SIGNS: Array[float] = [-1.0, 1.0]

## Grow-in for the one deliberate click that shows these brackets: a plant
## being selected. Node2D, not Control, so neither `scale` nor `modulate` is
## at any risk of a Container sort resetting it mid-tween — the trap
## Hud._play_panel_entrance and TitleScreen both document for their own Controls
## simply does not apply here.
##
## Not called from PlacementPreview. That subclass redraws on every mouse
## motion as the cursor crosses from cell to cell — animating a cue that fires
## that often would read as lag behind the cursor, not motion, and it is a
## hover promise rather than the click it promises. See Plant.set_selected for
## the one call site that plays this.
const GROW_SECONDS: float = 0.14
const GROW_START_SCALE: float = 0.55

## Subclass knobs. Vars rather than consts precisely so a subclass reuses the
## geometry instead of copying the numbers — see PlacementPreview.
## What the brackets look like while an uproot is armed on this plant
## (plant-tower-defense-rtgp).
##
## **Two channels, because one of them is colour.** The armed state is a pending
## destructive change, and this project answers that the same way everywhere it warns:
## lane pressure is hatched because the cursor tint it shares a cell with is not, a
## regrowing health bar is notched, and the Keys screen's armed reset marks its rows
## as well as tinting them. `RunConfig.colorblind_safe` exists precisely because a hue
## is not a reliable carrier, so the brackets get heavier as well as redder.
##
## Weight rather than a glyph: this is a shape drawn with `draw_line`, not a Label, so
## thickness is the channel it already has. It also reads at a glance on a 64px cell,
## which a mark would not.
const WARNING_COLOR := Color(GardenTheme.DANGER, 0.95)
const WARNING_LINE_WIDTH: float = LINE_WIDTH * 2.0

var marker_color: Color = MARKER_COLOR
var half: float = HALF
var arm: float = ARM
var line_width: float = LINE_WIDTH

var _entrance_tween: Tween = null


## Arms or disarms the warning look. Idempotent and repaint-only — the marker's
## visibility is `set_selected`'s business and this never touches it, so a plant that
## is armed and then deselected does not flicker.
func set_warning(warning: bool) -> void:
	var next_color: Color = WARNING_COLOR if warning else MARKER_COLOR
	var next_width: float = WARNING_LINE_WIDTH if warning else LINE_WIDTH
	if marker_color == next_color and is_equal_approx(line_width, next_width):
		return
	marker_color = next_color
	line_width = next_width
	queue_redraw()


func _draw() -> void:
	_draw_brackets()


func _draw_brackets() -> void:
	for sx: float in _SIGNS:
		for sy: float in _SIGNS:
			var corner := Vector2(half * sx, half * sy)
			draw_line(corner, corner + Vector2(-arm * sx, 0.0), marker_color, line_width)
			draw_line(corner, corner + Vector2(0.0, -arm * sy), marker_color, line_width)


## Grows the brackets in from GROW_START_SCALE and transparent, instead of the
## instant show `visible = true` used to be the whole of. Killed and restarted
## on every call — the same shape Hud._ease_threat_tint uses — so reselecting
## a plant fast (or a second click before the first tween lands) cannot leave
## two tweens racing over the same scale.
##
## A no-op with animations off: `scale` and `modulate` are left at whatever
## they already were, which is Vector2.ONE and full white on a freshly-built
## node — an already-correct final state, same as every other gate in this
## project's animation family.
func play_entrance() -> void:
	if not GardenTheme.animations_enabled():
		return
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	scale = Vector2.ONE * GROW_START_SCALE
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	_entrance_tween = create_tween().set_parallel(true)
	_entrance_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(self, "scale", Vector2.ONE, GROW_SECONDS)
	_entrance_tween.tween_property(self, "modulate", Color.WHITE, GROW_SECONDS)
