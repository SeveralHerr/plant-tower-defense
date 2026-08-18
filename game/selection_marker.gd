class_name SelectionMarker
extends Node2D
## The drawn-overlay grammar this cue belongs to is `game/OVERLAY_GRAMMAR.md`
## — what a solid ring, a dashed ring, a filled dot and a doubled width each
## mean, and the two places the grammar does not hold. Read it before adding a
## cue; its mechanical half is pinned by
## test_the_overlay_grammar_holds_where_it_is_mechanical.

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

## The uproot confirm window, drawn on the bed that is four seconds from being dug up
## (plant-tower-defense-fjqp).
##
## **Not a new shape.** `game/OVERLAY_GRAMMAR.md` already has a row reading "partial arc
## at a fixed radius, sweeping closed = TIME REMAINING on a clock that is already
## running", with two instances: a husk's rot timer (`HuskLayer._draw`) and a Chomp's
## chew (`ChompFlower.chew_arc_end`). `Game.UPROOT_CONFIRM_SECONDS` is the same sentence
## about the one decision in this game that cannot be undone, so it is the third
## instance of that row rather than a fifth cue. The legend already teaches the shape.
##
## **It is the missing CHANNEL, not a second copy of the armed cue.** Arming already
## changes two things on this plant — these brackets go `WARNING_COLOR` at
## `WARNING_LINE_WIDTH`, and `SoleCoverMarks` escalates with them (`Plant.set_uproot_armed`
## drives both). Both are BINARY. They say a destructive action is one click away and
## say nothing at all about how long that stays true, and the window closes in silence:
## the player who hesitates finds the next click doing something else. Time was the
## channel nothing on screen carried.
##
## RADIUS, and both bounds are asserted rather than merely written here
## (`test_placement.gd`, the fjqp section):
##   * strictly inside `HALF` — the bracket arms lie on the lines |x| = HALF and
##     |y| = HALF, so any circle of radius < HALF crosses none of them and the clock
##     never draws through the subject cue it sits inside.
##   * strictly inside `ChompFlower.CHEW_RING_RADIUS`, and this one is load-bearing. A
##     Chomp Flower can be armed for uproot WHILE chewing. Two arcs at the same radius
##     both sweeping closed would be told apart by hue alone, which is the one rule
##     OVERLAY_GRAMMAR.md says a cue may not break. Different radii keep them two
##     concentric clocks in greyscale.
const UPROOT_RING_RADIUS: float = 16.0
const UPROOT_RING_WIDTH: float = 3.0
const UPROOT_RING_SEGMENTS: int = 32

## Twelve o'clock, sweeping clockwise. The two board instances of this row start at 0.0
## (three o'clock) and nothing forces a choice, but `CueLegend`'s swatch for the row is
## drawn from -PI * 0.5 — that is the picture on the page the player is taught it on,
## so the one cue guarding an irreversible action matches the teaching rather than the
## two cues nobody is taught.
const UPROOT_RING_START: float = -PI * 0.5

var marker_color: Color = MARKER_COLOR
var half: float = HALF
var arm: float = ARM
var line_width: float = LINE_WIDTH

## The open confirm window as this marker last heard it. `Game` owns the clock that
## actually fires and pushes both numbers here every frame it is open
## (`Game._push_uproot_clock`); this node counts nothing of its own, so the arc on
## screen and the timer that expires cannot drift apart. Zero means no window, which is
## what `set_warning(false)` restores on every disarm path there is.
var uproot_left: float = 0.0
var uproot_window: float = 0.0

var _entrance_tween: Tween = null


## Where the confirm arc ENDS, in radians, with `seconds_left` of a `window_seconds`
## window still to run.
##
## Pure and static so the sweep is assertable with no board, no frame and no renderer:
## headless never runs a `_draw()` at all, so a composition left inside the paint call
## is a composition the suite can only assert the existence of. Same treatment
## `ChompFlower.chew_arc_end` and `HuskLayer.radius_for` get, for the same reason.
##
## A full circle at the instant of arming, closing back toward `UPROOT_RING_START` as
## the window runs out. A window of zero or less returns the start angle — an arc of no
## length, which is the correct picture for "nothing is armed" rather than a full ring
## drawn by a division that went to infinity.
static func uproot_arc_end(seconds_left: float, window_seconds: float) -> float:
	if window_seconds <= 0.0:
		return UPROOT_RING_START
	return UPROOT_RING_START + TAU * clampf(seconds_left / window_seconds, 0.0, 1.0)


## Feeds the confirm arc. Both numbers arrive from `Game` rather than one of them being
## remembered here, because `uproot_arc_end` needs the window to turn seconds into a
## sweep and a window remembered in two places is a window that can disagree.
##
## Negative input is floored at zero instead of rejected: the last tick of a window
## overshoots past zero by whatever `delta` was, and that frame should draw an empty
## arc, not an arc swept backwards.
func set_uproot_window(seconds_left: float, window_seconds: float) -> void:
	var left: float = maxf(seconds_left, 0.0)
	var span: float = maxf(window_seconds, 0.0)
	if is_equal_approx(uproot_left, left) and is_equal_approx(uproot_window, span):
		return
	uproot_left = left
	uproot_window = span
	queue_redraw()


## Arms or disarms the warning look. Idempotent and repaint-only — the marker's
## visibility is `set_selected`'s business and this never touches it, so a plant that
## is armed and then deselected does not flicker.
##
## Disarming also closes the confirm arc, and it is done HERE rather than at the caller
## because this is already the one call every exit from the armed state runs through:
## `Game._disarm_uproot` is the sole place the arming is cleared, and it goes through
## `Plant.set_uproot_armed`, which goes through this. An arc left drawn over a window
## that has closed is worse than no arc at all — it tells the player a click will
## destroy this bed when the click will now do something else entirely.
func set_warning(warning: bool) -> void:
	var next_color: Color = WARNING_COLOR if warning else MARKER_COLOR
	var next_width: float = WARNING_LINE_WIDTH if warning else LINE_WIDTH
	# Read before the clearing below, and folded into the early-return test: a marker
	# already wearing the base look but still holding a clock has to repaint, or the
	# stale arc survives precisely the no-op call the idempotence promise invites.
	var stale_clock: bool = not warning and (uproot_left > 0.0 or uproot_window > 0.0)
	if not warning:
		uproot_left = 0.0
		uproot_window = 0.0
	var unchanged: bool = (marker_color == next_color
		and is_equal_approx(line_width, next_width)
		and not stale_clock)
	if unchanged:
		return
	marker_color = next_color
	line_width = next_width
	queue_redraw()


func _draw() -> void:
	_draw_brackets()
	_draw_uproot_window()


## The confirm arc, and nothing at all on every frame except the four seconds after an
## Uproot is armed. A cue the player only ever meets while it is saying something.
##
## `WARNING_COLOR`, the same red the brackets and the sole-cover rings are already
## wearing: three marks in one hue read as one statement about this plant, where a
## second red would read as a second, unrelated warning. Colour is not this cue's
## channel — the sweep is — so sharing it costs nothing.
func _draw_uproot_window() -> void:
	if uproot_window <= 0.0 or uproot_left <= 0.0:
		return
	draw_arc(Vector2.ZERO, UPROOT_RING_RADIUS, UPROOT_RING_START,
		uproot_arc_end(uproot_left, uproot_window), UPROOT_RING_SEGMENTS,
		WARNING_COLOR, UPROOT_RING_WIDTH, true)


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
