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
## **Two channels, per the project rule that colour is never the only signal.** Each
## weather has a hue AND a mark shape: drought stipples short dry dashes, rain draws
## slanted streaks. With colour discarded they are still a different texture, and neither
## borrows a shape from `game/OVERLAY_GRAMMAR.md` — those marks are cell-sized and sit on
## road cells or on plants; these are 3-7 px, scattered, and deliberately not aligned to the
## grid at all, so nothing reads them as being about one cell.

## Marks per weather. Enough to read as a texture across the board, few enough that the
## whole overlay is one `_draw` of a few dozen primitives on a change rather than per frame.
const MARK_COUNT: int = 90

## Deterministic placement: the same wave always paints the same marks, so nothing shimmers
## when the overlay repaints and a screenshot is reproducible. A hash rather than an RNG
## because an RNG here would be a second stream the wave director's seed does not control.
const SCATTER_PRIME_X: int = 73856093
const SCATTER_PRIME_Y: int = 19349663

const DROUGHT_TINT := Color(0.86, 0.72, 0.36, 0.20)
const DROUGHT_MARK := Color(0.74, 0.60, 0.30, 0.55)
const DROUGHT_MARK_LENGTH: float = 7.0
const DROUGHT_MARK_WIDTH: float = 1.5

const RAIN_TINT := Color(0.55, 0.72, 0.95, 0.18)
const RAIN_MARK := Color(0.78, 0.89, 1.0, 0.60)
const RAIN_MARK_LENGTH: float = 9.0
const RAIN_MARK_WIDTH: float = 1.0
## Rain leans; drought's dashes lie flat. That angle difference is the second channel
## doing its job — the two are different textures before they are different colours.
const RAIN_SLANT := Vector2(0.34, 1.0)

var _weather: StringName = WaveDirector.WEATHER_CLEAR
var _size: Vector2 = Vector2.ZERO


func setup(board_size: Vector2) -> void:
	_size = board_size
	queue_redraw()


## Called by Game when a wave's weather is applied. Repaints only on a CHANGE: the overlay
## is static for a whole wave, so a `queue_redraw()` per call would be a repaint per wave
## start rather than per frame either way — but the guard keeps `_draw` off the profile
## entirely for the eleven waves in twelve that are clear.
func set_weather(weather: StringName) -> void:
	if weather == _weather:
		return
	_weather = weather
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
				var at: Vector2 = mark_position(i, _size)
				draw_line(at, at + RAIN_SLANT.normalized() * RAIN_MARK_LENGTH, RAIN_MARK,
					RAIN_MARK_WIDTH, true)
