class_name WeatherOverlay
extends Node2D

## Weather, drawn on the ground it applies to.
##
## `Hud.show_weather` fires a banner as a wave opens and the banner fades, so a player who
## looked away had no way to ask "why is my corn slow". `plant-tower-defense-saaw` asked
## for a standing readout on the top bar and that was **measured and refused**: the wave
## slot's base string is 302 px in a 312 px box, so every candidate tag overflowed — "  rain"
## 366, "  dry" 357, " ~" 324, even a bare "*" 317 — and widening the slot put
## `hud_stats_row` 35 px over its own budget. The bead's note ends "reopen only with a
## decision about WHERE".
##
## This is that decision, and the measurement is what makes it obvious in hindsight: **the
## top bar was never weather's home.** Weather is a property of the garden, not of the run's
## bookkeeping — it changes what every plant does — and the board has the one thing the bar
## does not, which is room. `plant-tower-defense-cxru` already landed the other half: the
## selection panel quotes the drought-stretched interval for a player who asks a specific
## plant. This is the half for the player who has not asked anything.
##
## **Three channels, per the project rule that colour is never the only signal.** Each
## weather has a hue AND a mark shape AND, since `plant-tower-defense-jwd6`, a state of
## motion: drought stipples short dry dashes and holds perfectly still, rain draws slanted
## streaks that fall. With colour discarded they are still a different texture, and neither
## borrows a shape from `game/OVERLAY_GRAMMAR.md` — those marks are cell-sized and sit on
## road cells or on plants; these are 3-7 px, scattered, and deliberately not aligned to the
## grid at all, so nothing reads them as being about one cell.

## Marks per weather. Enough to read as a texture across the board, few enough that the whole
## overlay is one `_draw` of a few dozen primitives — drawn once on a change for drought, and
## once a frame for rain, which is the only weather that moves.
const MARK_COUNT: int = 90

## Deterministic placement: the same wave always paints the same marks from the same scatter,
## so a drought never shimmers and a screenshot of one is reproducible. Rain adds exactly one
## time term on top of this — `_rain_phase`, an offset applied to every mark alike — so a
## falling frame is still this scatter, moved, rather than a second placement rule. A hash
## rather than an RNG because an RNG here would be a second stream the wave director's seed
## does not control.
const SCATTER_PRIME_X: int = 73856093
const SCATTER_PRIME_Y: int = 19349663

## DROUGHT_TINT is a uniform full-board wash, not a mark -- it changes the tint of the
## ground itself rather than sitting as a shape a player reads against it, so it owes
## no separation from a ground it is part of.
const DROUGHT_TINT := Color(0.86, 0.72, 0.36, 0.20)
## DARKENED (plant-tower-defense-w86n): the crack dashes ARE marks -- scattered across
## both grounds -- and the original `Color(0.74, 0.60, 0.30)` (luminance 0.608) failed
## both: 0.019 against grass, 0.041 against dirt, at its own 0.55 alpha, against a 0.12
## floor. `.darkened(0.55)`: luminance 0.274, clearing grass by 0.083 and dirt by 0.023.
## See test_every_board_mark_clears_the_ground_floor_at_the_alpha_it_is_drawn_at.
const DROUGHT_MARK := Color(0.33, 0.27, 0.14, 0.55)
const DROUGHT_MARK_LENGTH: float = 7.0
const DROUGHT_MARK_WIDTH: float = 1.5

const RAIN_TINT := Color(0.55, 0.72, 0.95, 0.18)
const RAIN_MARK := Color(0.78, 0.89, 1.0, 0.60)
const RAIN_MARK_LENGTH: float = 9.0
const RAIN_MARK_WIDTH: float = 1.0
## Rain leans; drought's dashes lie flat. That angle difference is the second channel
## doing its job — the two are different textures before they are different colours.
const RAIN_SLANT := Vector2(0.34, 1.0)

## Rain falls at this many board pixels per second along `RAIN_SLANT`. Fast enough to read as
## weather at a glance, slow enough that a 9 px streak stays a streak: at 110 px/s a mark
## crosses the 576 px board in a little over five seconds.
const RAIN_FALL_SPEED: float = 110.0

var _weather: StringName = WaveDirector.WEATHER_CLEAR
var _size: Vector2 = Vector2.ZERO
## How far the rain has fallen, in pixels along `RAIN_SLANT`, since this rain began. Zero
## whenever it is not raining, which is what makes the still picture and the first frame of a
## falling one the same picture.
var _rain_phase: float = 0.0


func _ready() -> void:
	_refresh_motion()


func setup(board_size: Vector2) -> void:
	_size = board_size
	queue_redraw()


## Called by Game when a wave's weather is applied. Repaints only on a CHANGE — but a CHANGE
## now also starts or stops the fall, and the falling picture repaints itself per frame from
## `_process`. Everything else — drought, clear — is still drawn once and left alone.
func set_weather(weather: StringName) -> void:
	if weather == _weather:
		return
	_weather = weather
	_rain_phase = 0.0
	_refresh_motion()
	queue_redraw()


## The picture moves only while it is actually raining.
##
## Two separate reasons the frame callback is off by default, and they are not the same
## reason: eleven waves in twelve are clear, and a `_process` that redraws ninety primitives
## on a clear wave is a per-frame cost buying a still image; and `animations_enabled()` is
## false headless and for a player who has turned motion off, which is the same
## `GardenTheme` gate every cosmetic tween in this project uses (`game/nettle.gd:193`). With
## either false the phase is pinned at zero and `_draw` paints exactly the frame it painted
## before this change.
##
## **Drought does not get a shimmer, and that is the decision, not an omission.** The file
## already argues that slant vs flat is a channel; motion vs stillness is the same argument
## one step further — rain falls and a drought is the weather in which nothing moves. A heat
## shimmer would spend the channel to say "this is also weather", which the tint and the
## dashes already say, and would cost a second per-frame redraw to say it.
func _refresh_motion() -> void:
	var moving: bool = rain_should_fall(_weather, GardenTheme.animations_enabled())
	if not moving:
		_rain_phase = 0.0
	set_process(moving)


## Pure: does the picture move? Both halves of the answer are things a headless test cannot
## observe in place — `animations_enabled()` is false for the whole suite, and whether
## `_process` was armed is a property of the tree — so the decision is named and taken here,
## and `_refresh_motion` above is its one caller.
static func rain_should_fall(weather: StringName, animations_on: bool) -> bool:
	return animations_on and weather == WaveDirector.WEATHER_RAIN


func _process(delta: float) -> void:
	_rain_phase = advance_rain_phase(_rain_phase, delta)
	queue_redraw()


func weather() -> StringName:
	return _weather


## Pure: where the nth mark sits inside a board of `size`. Split out so the scatter is
## assertable without a rendered frame — the properties that matter are that marks are
## inside the board and that they do not collapse onto a few points, and neither needs a
## renderer to check.
static func mark_position(index: int, size: Vector2) -> Vector2:
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	var hx: int = absi((index + 1) * SCATTER_PRIME_X) % 65536
	var hy: int = absi((index + 1) * SCATTER_PRIME_Y) % 65536
	return Vector2(
		fmod(float(hx), size.x),
		fmod(float(hy), size.y))


## Pure: the fall phase `delta` seconds later — "how far the rain has fallen by now".
##
## Extracted rather than left inside `_process` because both of the things that decide whether
## the rain moves are gates a headless test cannot open: `_process` needs frames, and
## `GardenTheme.animations_enabled()` is false for the whole suite by construction. A test that
## called either would be asserting an early return. This is the only place the phase advances,
## and `_process` above is its one line.
##
## The phase is NOT wrapped here. It resets to zero every time the weather changes, so a rain
## wave bounds it at a few thousand pixels; the wrapping that matters is per axis and by the
## board, in `rain_mark_position`.
static func advance_rain_phase(phase: float, delta: float) -> float:
	if delta <= 0.0:
		return phase
	return phase + RAIN_FALL_SPEED * delta


## Pure: where the nth rain mark sits once the fall has advanced `phase` pixels along
## `RAIN_SLANT`.
##
## Wrapping is per axis and by the board, not by the phase: a mark that runs off the bottom
## re-enters at the top on its own schedule, so the picture scrolls and there is never a moment
## when every mark jumps at once. Wrapping the phase would be cheaper and would put a sideways
## lurch in the picture once per cycle, because a phase that returns a mark to its starting row
## does not generally return it to its starting column.
##
## `phase == 0.0` reproduces `mark_position` exactly — the still frame the animations-disabled
## path draws is the first frame of the falling one, not a different picture.
static func rain_mark_position(index: int, size: Vector2, phase: float) -> Vector2:
	var at: Vector2 = mark_position(index, size)
	if size.x <= 0.0 or size.y <= 0.0:
		return at
	var drift: Vector2 = RAIN_SLANT.normalized() * phase
	return Vector2(fposmod(at.x + drift.x, size.x), fposmod(at.y + drift.y, size.y))


func _draw() -> void:
	if _size.x <= 0.0 or _size.y <= 0.0:
		return
	match _weather:
		WaveDirector.WEATHER_DROUGHT:
			draw_rect(Rect2(Vector2.ZERO, _size), DROUGHT_TINT, true)
			for i: int in range(MARK_COUNT):
				var at: Vector2 = mark_position(i, _size)
				draw_line(at, at + Vector2(DROUGHT_MARK_LENGTH, 0.0), DROUGHT_MARK,
					DROUGHT_MARK_WIDTH, true)
		WaveDirector.WEATHER_RAIN:
			draw_rect(Rect2(Vector2.ZERO, _size), RAIN_TINT, true)
			for i: int in range(MARK_COUNT):
				var at: Vector2 = rain_mark_position(i, _size, _rain_phase)
				draw_line(at, at + RAIN_SLANT.normalized() * RAIN_MARK_LENGTH, RAIN_MARK,
					RAIN_MARK_WIDTH, true)
