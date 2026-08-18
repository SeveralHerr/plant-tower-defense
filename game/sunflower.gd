class_name Sunflower
extends Plant

## The third plant — an economy pick, not a combat one, so a rare packet has
## something worth pulling for besides "a slightly better Corn". It fires
## nothing and grabs nothing; it just pays out seeds on a clock, which makes
## the cell it stands on a real trade-off against a lane tile.

signal grew_seeds(amount: int)

const INTERVAL: float = 6.0
const YIELD: int = 3

## The yield gauge: a stalk-shaped column standing in the plant's lower-left
## that fills upward as the next payout approaches.
##
## The plant whose entire purpose is a clock was the one plant with no clock on
## the board — the payout time existed only as "Next 3 seeds in 4s" in the
## selection panel, which you had to click the plant to read. Corn wears its
## muzzle fan and Chomp wears its chew ring without being selected; this is the
## Sunflower's equivalent.
##
## Deliberately NOT a ring or an arc. ChompFlower already owns the radial idiom
## (CHEW_RING_RADIUS, a 3 px orange stroke at a fixed 22 px, centred on the plant,
## *sweeping* closed as the meal finishes) and a second circle on the board would
## read as the same language. This differs on three axes at once: straight instead
## of round, in a corner instead of centred, and gold rather than the chew ring's
## orange. It is also always on, where the chew ring only appears mid-meal.
##
## It used to differ on a fourth — "growing instead of shrinking", back when the
## chew ring shrank its radius. Cycle 78 turned that into a swept angle at a fixed
## radius (see ChompFlower.CHEW_RING_RADIUS for why), so both readouts now grow or
## shrink along their own axis and the direction no longer separates them. Three
## axes is still three, and the geometry below keeps them from ever sharing a pixel.
##
## Geometry — Rect2(-30, 10, 6, 20) — is pinned by three things it must clear:
##   * the sprite. Node2D paints its own canvas item *below* its children, so
##     anything drawn under the 64x64 flower is simply invisible, not merely
##     dimmed. sunflower.svg's petal tips reach r = 26 and its two leaves reach
##     r = 29 down-left and down-right; the trough's nearest corner (-24, 10) is
##     at r = 26.0 and 13.9 px off the leaf axis, so the whole column sits on
##     bare grass. That clearance, not the column's looks, is what sets its
##     height: any taller and the top — the part that says "payout imminent" —
##     would slide behind a petal of the same gold.
##   * the health bar, which Plant._build_visuals puts at Rect2(-16, -34, 32, 5).
##     The two are disjoint on both axes, not just one, so a damaged Sunflower
##     shows two readouts that never touch.
##   * the selection brackets, whose lower-left arm runs down x = -22. The
##     column's right edge is x = -24.
## All of it stays inside the 64 px cell (|x| <= 31, |y| <= 31 with the rim).
const GAUGE_WIDTH: float = 6.0
const GAUGE_HEIGHT: float = 20.0
const GAUGE_LEFT: float = -30.0
const GAUGE_BOTTOM: float = 30.0

## Ink surround first, so the gauge is legible against both the grass it stands
## on (#2ECC71) and the gold it is drawn in.
const GAUGE_RIM_COLOR := Color(0.10, 0.13, 0.10, 0.85)
const GAUGE_BACK_COLOR := Color(0.16, 0.22, 0.17, 0.75)
## Seed gold — brighter and yellower than ChompFlower's chew orange
## (1.0, 0.55, 0.15), and the same family as the flower's own petals.
const GAUGE_FILL_COLOR := Color(1.0, 0.84, 0.30, 0.95)
const GAUGE_CAP_COLOR := Color(1.0, 0.98, 0.82, 0.95)
## The payout flash, at full strength. Fades to nothing over BLOOM_FLASH_TIME.
const GAUGE_FLASH_COLOR := Color(1.0, 0.98, 0.80, 0.85)
const BLOOM_FLASH_TIME: float = 0.45

var _timer: float = 0.0
## Last fill height actually painted, in whole pixels. The gauge changes by less
## than a pixel most frames, so this is what keeps a field of Sunflowers off a
## 60 Hz repaint each; -1 means "nothing painted yet, repaint regardless".
var _drawn_fill_height: float = -1.0
## 0 except during the payout flourish. Never left non-zero without a Tween
## running to bring it back — see _bloom().
var _bloom_flash: float = 0.0


func _act(delta: float, _pests: Array[Pest]) -> void:
	_timer += delta
	if _timer >= INTERVAL:
		_timer -= INTERVAL
		grew_seeds.emit(YIELD)
		_bloom()
	_refresh_gauge()


## Seconds until the next payout. The selection panel's "Next %d seeds in %.0fs"
## reads this.
func seconds_until_next_yield() -> float:
	return seconds_left_at(_timer)


## How full the gauge is: 0.0 the instant a payout lands, approaching 1.0 as the
## next one comes due.
##
## Routed through the same static as seconds_until_next_yield() on purpose. A
## board readout that drifts away from the number in the panel is worse than no
## readout at all, and the cheapest way to guarantee they agree is for there to
## be only one clock.
func yield_progress() -> float:
	return progress_at(_timer)


## Pure: seconds left after `elapsed` seconds of an interval. Clamped at 0 so a
## frame that overshoots never shows a negative countdown.
static func seconds_left_at(elapsed: float) -> float:
	return maxf(0.0, INTERVAL - elapsed)


## Pure: the gauge fill fraction for `elapsed` seconds into an interval, defined
## as the complement of the countdown rather than as a second division of its
## own — same input, same clock, no drift.
static func progress_at(elapsed: float) -> float:
	return clampf(1.0 - seconds_left_at(elapsed) / INTERVAL, 0.0, 1.0)


## The gauge's empty trough, in the plant's own space.
static func gauge_trough_rect() -> Rect2:
	return Rect2(GAUGE_LEFT, GAUGE_BOTTOM - GAUGE_HEIGHT, GAUGE_WIDTH, GAUGE_HEIGHT)


## The filled part of the trough at `progress`, growing upward from the bottom.
## Pure, so what gets drawn is checkable without rendering a frame.
static func gauge_fill_rect(progress: float) -> Rect2:
	var height: float = GAUGE_HEIGHT * clampf(progress, 0.0, 1.0)
	return Rect2(GAUGE_LEFT, GAUGE_BOTTOM - height, GAUGE_WIDTH, height)


## This flower's fill rect right now.
func yield_gauge_rect() -> Rect2:
	return gauge_fill_rect(yield_progress())


## Note there is no super._draw() call here, and there must not be: the
## selection brackets live in a SelectionMarker child precisely because an
## override like this one eats them. See SelectionMarker's header. The Sunflower
## reaches nothing, so unlike CornCobbler there is no range ring to paint when
## `_selected` — and the gauge is deliberately not gated on selection either,
## since a clock you have to click to see is the bug this fixes.
func _draw() -> void:
	var trough: Rect2 = gauge_trough_rect()
	draw_rect(trough.grow(1.0), GAUGE_RIM_COLOR, true)
	draw_rect(trough, GAUGE_BACK_COLOR, true)

	var fill: Rect2 = yield_gauge_rect()
	if fill.size.y >= 1.0:
		draw_rect(fill, GAUGE_FILL_COLOR, true)
		draw_line(fill.position, Vector2(fill.end.x, fill.position.y), GAUGE_CAP_COLOR, 1.5)

	if _bloom_flash > 0.0:
		draw_rect(trough, Color(GAUGE_FLASH_COLOR, GAUGE_FLASH_COLOR.a * _bloom_flash), true)


## Repaint only when the picture would actually change by a pixel.
func _refresh_gauge() -> void:
	var height: float = roundf(yield_gauge_rect().size.y)
	if is_equal_approx(height, _drawn_fill_height):
		return
	_drawn_fill_height = height
	queue_redraw()


func _bloom() -> void:
	# The gauge has just wrapped back to empty. Forced rather than left to
	# _refresh_gauge()'s pixel comparison so a payout can never leave a full
	# column painted on the board.
	_drawn_fill_height = -1.0
	queue_redraw()
	if _sprite == null or not is_inside_tree():
		return
	# Same gate hud.gd, run_summary.gd and title_screen.gd use. Headless pumps no
	# frames, so a Tween there never runs — every one of these is a flourish on
	# top of a state that is already correct without it (`scale` is already
	# Vector2.ONE, `_bloom_flash` is already 0), never the thing that establishes
	# it.
	if not GardenTheme.animations_enabled():
		return
	# `Plant.FLOURISH_*` rather than the twitch tier, and deliberately: a payout is
	# this plant's ONE visible event, so it is spent at the longer beat a cob only
	# gets when it buys a level. Same pair as `CornCobbler._upgrade_flourish()`.
	var pop := create_tween()
	pop.tween_property(_sprite, "scale", Vector2(1.16, 1.16), FLOURISH_OUT_SECONDS)
	pop.tween_property(_sprite, "scale", Vector2.ONE, FLOURISH_BACK_SECONDS)
	var flash := create_tween()
	flash.tween_method(_set_bloom_flash, 1.0, 0.0, BLOOM_FLASH_TIME)


func _set_bloom_flash(value: float) -> void:
	_bloom_flash = value
	queue_redraw()
