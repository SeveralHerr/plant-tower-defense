class_name BeeSwarm
extends Node2D

## Bees crossing the garden, every twenty-odd seconds, for no reason at all.
##
## This is the one thing drawn on the board that is NOT a cue. `game/OVERLAY_GRAMMAR.md`
## enumerates twelve drawn shapes and every one of them means something a player can act
## on; a bee means nothing, reads nothing, and is read by nothing. That is the feature —
## a garden with no ambient life in it looks like a spreadsheet with grass on top — and it
## is also the risk, because a moving gold shape on a board where every other moving gold
## shape is information will be read as information unless it is deliberately kept out of
## the grammar. The three things that keep it out are named where they are implemented:
## SHADOW_COLOR (a channel no cue owns), the wander (nothing that carries a message
## meanders), and the refusal to look at the plant set at all — see `setup`.
##
## **A bout, not a population.** The obvious version is one bee circling forever, which is
## a per-frame cost buying wallpaper: after ninety seconds nobody sees it. Instead the
## garden is empty, and then something happens — one to three bees enter from an edge,
## cross on lazy lines, and leave. Between bouts this node has `_process` OFF and is
## waiting on a `SceneTreeTimer`, so an idle garden pays for bees exactly nothing: no frame
## callback, no redraw, and no nodes, because a bee is two floats in an array rather than
## a child.
##
## **Everything about a bout is a hash of its number**, in the shape `WeatherOverlay`
## already uses for its scatter: bout 7 is the same bees on the same lines in every run, so
## a screenshot is reproducible, and no second RNG stream escapes the seed `Game.set_seed`
## pins. See `hash01`.

## Seconds between bouts, sampled per bout from the hash. Tuned for "noticeable when you
## look at the garden, forgettable when you are fighting a wave" — at the short end a
## player who has just placed a plant sees the next bout before they finish reading the
## selection panel; at the long end a whole wave can pass without one.
const GAP_MIN: float = 22.0
const GAP_MAX: float = 40.0
## The first bout comes sooner than a sampled gap would allow, because the opening of a run
## is the one moment a player is looking AT the garden rather than at the packet row.
const FIRST_GAP: float = 6.0

const BEES_MIN: int = 1
const BEES_MAX: int = 3
## How long one bee takes to cross, before the per-bee hash stretches it. A crossing much
## faster than this reads as a projectile — the board is only 896 px wide.
const CROSS_SECONDS_MIN: float = 9.0
const CROSS_SECONDS_MAX: float = 14.0
## Bees of one bout do not enter together; the last one may be this far behind the first.
## Without it three bees leave one edge in formation, which reads as a spawn.
const STAGGER_MAX: float = 1.8

## How far outside the board the entry and exit points sit, so a bee is already flying when
## it becomes visible and does not pop in at the rim.
const EDGE_MARGIN: float = 30.0
## And how far in from the corners an edge point may be picked, so a path across one corner
## of the board is not a path that never enters it.
const EDGE_INSET: float = 40.0

## The meander, as two sines across the direction of travel.
##
## **The two frequencies are deliberately incommensurate.** 0.21 and 0.63 would be a ratio
## of exactly 3, the pair would re-phase every cycle, and every bee would draw the same
## tidy S — which is what machinery looks like. 0.21 against 0.58 never repeats inside a
## crossing, so two bees on the same line still fly differently.
const WANDER_A1: float = 34.0
const WANDER_F1: float = 0.21
const WANDER_A2: float = 11.0
const WANDER_F2: float = 0.58

## Body size, approved at 18 px — a bit over a quarter of a 64 px cell.
##
## AT THIS SIZE A BEE IS APHID-SIZED, and a gold bug crossing the garden must never be
## mistaken for something to shoot. Four separations carry that, none of them colour: this
## thing has a shadow and no pest does; it flies over grass as readily as over the road,
## while a pest is nailed to the road; it wanders, where a pest walks a straight lane at a
## constant speed; and it has no health bar, no husk and no reaction to being hit, because
## nothing can hit it. If it ever still reads as a target in play, BODY_LENGTH comes down
## rather than the shadow coming off.
const BODY_LENGTH: float = 18.0
const BODY_WIDTH: float = 10.8
## Wings beat far faster than a frame can show, which is the point: at 14 Hz against 60 fps
## the pair is aliased into a flicker, and a flicker is what a wing looks like.
const WING_BEAT: float = 14.0
## Wing geometry, as fractions of the body, MEASURED AGAINST A SCREENSHOT rather than
## guessed. The first draft ran them at 1.12 of the body's length and 8.2 px off its centre
## line, which is roughly what a wing does on a diagram — and on the board at 18 px the two
## pale ovals were the biggest thing in the drawing, so the bee read as a white moth with a
## gold seed in it. Shorter than the body and tucked close is what makes the gold the
## subject and the wings the blur.
const WING_LENGTH_RATIO: float = 0.72
const WING_WIDTH_RATIO: float = 0.30
## How far off the body's centre line each wing sits at rest, and how far the beat moves it.
const WING_SPREAD: float = 4.6
const WING_BEAT_TRAVEL: float = 1.5

const BODY_COLOR := Color(1.0, 0.8, 0.0)
## The rim and the two stripes: the body's own hue, darkened, per `art_src/STYLE.md`'s
## rule that no rim in this game is black or grey. DARKER THAN THE KIT'S OWN `#8A6D00`
## (luminance 0.42) on purpose — that shade clears grass but misses dirt by 0.006 at the
## alpha this is drawn at, and a bee crosses both grounds. At 0.256 luminance it clears
## dirt by 0.158. See test_every_board_mark_clears_the_ground_floor_at_the_alpha_it_is_drawn_at.
const RIM_COLOR := Color(0.33, 0.26, 0.0)
const WING_COLOR := Color(1.0, 1.0, 1.0, 0.55)

## THE LOAD-BEARING PART, and it is not decoration.
##
## Every cue in `OVERLAY_GRAMMAR.md` lives on the ground plane — an arc on a plant, a dot
## on a cell, a hatch filling a cell. A soft ellipse offset down-right says *this is above
## the garden, not a mark about the cell under it*, which is a channel no cue owns and
## therefore cannot be confused with one. Cover the shadow and a bee immediately starts to
## read like something being said about the cell it happens to be over.
##
## The value is `SeedBomb.SHADOW_COLOR`, restated rather than imported: those are the only
## two airborne things in the game, and they should say "airborne" identically.
## `test_the_two_airborne_shadows_in_this_game_are_the_same_shadow` fails if they drift.
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.26)
const SHADOW_OFFSET := Vector2(7.2, 12.0)
## Slightly wider and much flatter than the body: a shadow is the body seen from the sun's
## angle, not a copy of it pasted underneath.
const SHADOW_LENGTH: float = 22.0
const SHADOW_WIDTH: float = 12.5

## Segments in the drawn ellipses. Twelve is the point where a 22 px shadow stops showing
## its corners; more is paying for vertices nobody can see.
const ELLIPSE_SEGMENTS: int = 12

## Hash primes, the same pair `WeatherOverlay` scatters its marks with. Shared VALUES
## rather than a shared function because the two hashes answer different questions (a
## position there, a parameter here) and folding them into one would make a change to
## either visible in the other's picture.
const HASH_PRIME_A: int = 73856093
const HASH_PRIME_B: int = 19349663

var _size: Vector2 = Vector2.ZERO
var _weather: StringName = WaveDirector.WEATHER_CLEAR
## Which bout is open, or the one that just closed. Only ever increases, so no two bouts in
## a run share a hash even though the hash itself is stateless.
var _bout: int = 0
## Progress 0..1 of each bee in the open bout; empty between bouts. A bee is an index into
## this and `_waiting`, not a node — nothing to leak, nothing for the orphan gate to count.
var _progress: PackedFloat32Array = PackedFloat32Array()
## Seconds each bee still has to wait before it enters.
var _waiting: PackedFloat32Array = PackedFloat32Array()
## Time the wings have been beating. Advances only while a bout is open, so the beat is a
## property of the flight rather than of how long the game has been running.
var _elapsed: float = 0.0
## The pending gap. Held so `next_bout_seconds` can answer without opening the timer up.
var _pending_gap: float = 0.0


func _ready() -> void:
	set_process(false)
	# Absent entirely when animation is off — which is every headless run, and is the same
	# `GardenTheme` gate every cosmetic tween in this project sits behind. Not "drawn
	# still": a still bee hanging over the board would be a mark, and a mark is exactly
	# what this must never be.
	if GardenTheme.animations_enabled():
		_schedule_bout(FIRST_GAP)


## The board this flies over, and the ONLY thing this node is ever told.
##
## No plant set, no pest list, no wave, no seed count. "Purely aesthetic" is a property of
## this signature rather than a promise in a comment: a bee cannot bend toward a Sunflower
## because nothing here knows a Sunflower exists. That was a decision and not an oversight
## — a bee that curves toward a plant is a bee that appears to be telling you something
## about that plant, and the moment a player believes that, this is a cue.
func setup(board_size: Vector2) -> void:
	_size = board_size
	queue_redraw()


## The one exception to the paragraph above, and it is world state rather than run state.
##
## Bees sit out the rain. It is one branch and it is the kind of detail that makes a garden
## feel like a place; it stays out of the grammar because ABSENCE carries no message — a
## player cannot read "no bees" as advice, and nothing is drawn to be misread.
func set_weather(weather: StringName) -> void:
	_weather = weather


## Pure: may a bout open in this weather?
static func bout_allowed(weather: StringName) -> bool:
	return weather != WaveDirector.WEATHER_RAIN


## Pure: 0.0..1.0 from two ints, stable across runs and platforms.
##
## Deterministic by hash rather than by RNG for the reason `WeatherOverlay` gives: an RNG
## here would be a fourth random stream, and `Game.set_seed` — which exists precisely so a
## run can be reproduced — does not pin it. Masked to 31 bits at every step so the
## arithmetic stays inside a positive int and cannot depend on how a platform signs a
## shift.
static func hash01(a: int, b: int) -> float:
	var h: int = ((a + 1) * HASH_PRIME_A) ^ ((b + 1) * HASH_PRIME_B)
	h = absi(h) & 0x7fffffff
	h = (h ^ (h >> 13)) & 0x7fffffff
	h = (h * 1274126177) & 0x7fffffff
	return float(h ^ (h >> 16)) / 2147483648.0


## Pure: seconds of quiet before bout `bout` opens.
static func bout_gap(bout: int) -> float:
	return lerpf(GAP_MIN, GAP_MAX, hash01(bout, 9001))


## Pure: how many bees bout `bout` sends.
static func bees_in_bout(bout: int) -> int:
	var span: int = BEES_MAX - BEES_MIN + 1
	# `mini` rather than a modulo: hash01 never returns 1.0, but a float multiply that
	# rounds up at the top of the range would silently wrap to BEES_MIN under `%`, which
	# is the one failure mode a test would never catch by sampling.
	return BEES_MIN + mini(span - 1, int(hash01(bout, 4242) * float(span)))


## Pure: how long bee `index` of bout `bout` takes to cross, entry point to exit point.
static func cross_seconds(bout: int, index: int) -> float:
	return lerpf(CROSS_SECONDS_MIN, CROSS_SECONDS_MAX, hash01(bout, index * 31 + 7))


## Pure: how long that bee waits before it enters.
static func stagger_seconds(bout: int, index: int) -> float:
	return STAGGER_MAX * hash01(bout, index * 31 + 11)


## Pure: a point on side `side` (0 top, 1 right, 2 bottom, 3 left) of a board of `size`,
## `EDGE_MARGIN` outside it, `u` of the way along.
static func edge_point(u: float, side: int, size: Vector2) -> Vector2:
	var along_x: float = lerpf(EDGE_INSET, maxf(EDGE_INSET, size.x - EDGE_INSET), u)
	var along_y: float = lerpf(EDGE_INSET, maxf(EDGE_INSET, size.y - EDGE_INSET), u)
	match side % 4:
		0: return Vector2(along_x, -EDGE_MARGIN)
		1: return Vector2(size.x + EDGE_MARGIN, along_y)
		2: return Vector2(along_x, size.y + EDGE_MARGIN)
		_: return Vector2(-EDGE_MARGIN, along_y)


## Pure: where bee `index` of bout `bout` comes in.
static func entry_point(bout: int, index: int, size: Vector2) -> Vector2:
	var side: int = int(hash01(bout, index * 31 + 1) * 4.0) % 4
	return edge_point(hash01(bout, index * 31 + 2), side, size)


## Pure: where it goes out. Never the side it came in on — a bee that enters and leaves by
## the same edge turns around inside the garden, and a thing that turns around is a thing
## that was going somewhere.
static func exit_point(bout: int, index: int, size: Vector2) -> Vector2:
	var side_in: int = int(hash01(bout, index * 31 + 1) * 4.0) % 4
	var side_out: int = (side_in + 1 + int(hash01(bout, index * 31 + 3) * 3.0) % 3) % 4
	return edge_point(hash01(bout, index * 31 + 4), side_out, size)


## Pure: where bee `index` of bout `bout` is, `t` of the way through its crossing.
##
## A straight line from entry to exit, plus a two-sine meander ACROSS that line. Everything
## interesting about the flight is in the last term, and the `sin(PI * t)` on it is what
## makes the ends behave: the wander is exactly zero at t=0 and t=1, so a bee enters and
## leaves travelling straight through its edge point instead of popping into view mid-swerve
## — and `bee_position(..., 0.0)` IS `entry_point`, which is the property the test asserts
## rather than the shape of the curve, because a curve nobody can see is not the claim.
##
## Static, and this is the reason the whole file is arranged around it: headless runs no
## `_draw` and pumps no frames, so a path assembled inside a draw call is a path no test can
## reach. See `.claude/skills/assert-an-animation`.
static func bee_position(bout: int, index: int, t: float, size: Vector2) -> Vector2:
	var from: Vector2 = entry_point(bout, index, size)
	var to: Vector2 = exit_point(bout, index, size)
	var along: Vector2 = from.lerp(to, t)
	var across: Vector2 = (to - from).normalized().orthogonal()
	# Phase in SECONDS of flight, not in t: two bees on the same line but with different
	# crossing times then wander at the same rate rather than in the same shape.
	var seconds: float = t * cross_seconds(bout, index)
	var phase: float = hash01(bout, index * 31 + 5) * TAU
	var swing: float = WANDER_A1 * sin(TAU * WANDER_F1 * seconds + phase) \
		+ WANDER_A2 * sin(TAU * WANDER_F2 * seconds + phase * 1.7)
	return along + across * swing * sin(PI * t)


## Pure: which way that bee is pointing, by finite difference along its own path.
##
## Sampled rather than differentiated because the derivative of the expression above is
## four terms of chain rule that would then be a second description of the flight, free to
## disagree with the first. A bee is drawn where it is going NEXT, which is the same
## definition a reader of `bee_position` already has.
static func bee_heading(bout: int, index: int, t: float, size: Vector2) -> float:
	var here: Vector2 = bee_position(bout, index, t, size)
	var soon: Vector2 = bee_position(bout, index, minf(1.0, t + 0.004), size)
	var step: Vector2 = soon - here
	if step.length_squared() <= 0.0:
		step = bee_position(bout, index, t, size) - bee_position(bout, index, maxf(0.0, t - 0.004), size)
	return step.angle()


## Pure: an ellipse as a polygon, centred on the origin, long axis along +X.
##
## Godot's `CanvasItem` has no ellipse primitive and `draw_circle` under a scaled transform
## scales the stroke widths with it, so the rim would thicken with the body. A polygon keeps
## the geometry and the stroke independent, and — because this is a static func — the shape
## is assertable without a viewport.
static func ellipse_points(length: float, width: float, segments: int = ELLIPSE_SEGMENTS) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in range(segments):
		var a: float = TAU * float(i) / float(segments)
		points.append(Vector2(cos(a) * length * 0.5, sin(a) * width * 0.5))
	return points


## Pure: the wing pair's vertical offset and thickness at a beat phase in -1..1.
##
## Returned as a pair rather than drawn inline so the beat is assertable: the two wings must
## move in OPPOSITE directions (a pair beating together reads as one flapping sheet), which
## is a claim about two numbers and needs no renderer to check.
static func wing_offsets(beat: float) -> Vector2:
	return Vector2(
		-WING_SPREAD - beat * WING_BEAT_TRAVEL,
		WING_SPREAD + beat * WING_BEAT_TRAVEL)


func _process(delta: float) -> void:
	_elapsed += delta
	var flying: bool = false
	for i: int in range(_progress.size()):
		if _waiting[i] > 0.0:
			_waiting[i] -= delta
			flying = true
			continue
		if _progress[i] >= 1.0:
			continue
		_progress[i] = minf(1.0, _progress[i] + delta / cross_seconds(_bout, i))
		if _progress[i] < 1.0:
			flying = true
	queue_redraw()
	if not flying:
		_close_bout()


## Seconds until the next bout, for anything asking what this node is waiting on. Zero
## while a bout is open.
func next_bout_seconds() -> float:
	return 0.0 if not _progress.is_empty() else _pending_gap


## How many bees are in the air right now. The one live read this node offers, and it
## exists for the bridge rather than for the game — nothing in a run calls it.
func flying_count() -> int:
	var n: int = 0
	for i: int in range(_progress.size()):
		if _waiting[i] <= 0.0 and _progress[i] < 1.0:
			n += 1
	return n


## Arm the timer for the next bout. A `SceneTreeTimer` rather than a counter in `_process`,
## which is the whole of the "idle costs nothing" claim: with no bout open this node has no
## frame callback at all. `process_always = false` so a paused game's bees do not arrive
## while the pause menu is up, and the default `ignore_time_scale = false` so the garden at
## 2x is twice as busy, like everything else in it.
func _schedule_bout(seconds: float) -> void:
	_pending_gap = seconds
	var timer := get_tree().create_timer(seconds, false)
	timer.timeout.connect(_open_bout)


## Open the next bout NOW rather than when the timer says so, and report how many bees it
## sent (zero if the weather refused it). For `cmd bee_bout` — a live check of a feature
## whose whole point is that it happens rarely otherwise means waiting up to forty seconds
## per look, and a check nobody runs twice is a check.
##
## This is the game's own path, not a shortcut past it: it is the same `_open_bout` the
## timer calls, so a forced bout is indistinguishable from a scheduled one once it is in
## the air.
func open_bout_now() -> int:
	# Counted by whether a bout was actually TAKEN, not by how many bees are in the air:
	# called while a bout is already flying, this opens nothing, and reporting that bout's
	# bees would read as a second one having launched.
	var before: int = _bout
	_open_bout()
	return _progress.size() if _bout != before else 0


func _open_bout() -> void:
	# A bout forced through `open_bout_now` leaves the scheduled timer still ticking, and
	# it lands mid-flight. Dropped rather than queued, and safe to drop because
	# `_close_bout` is what arms the next timer — the schedule resumes from whichever bout
	# actually flew.
	if not _progress.is_empty():
		return
	_pending_gap = 0.0
	_bout += 1
	# A bout that falls in the rain is SKIPPED, not queued: bees that all turn up the
	# moment the weather clears would be a flock, and a flock is an event.
	if not bout_allowed(_weather):
		_schedule_bout(bout_gap(_bout))
		return
	var count: int = bees_in_bout(_bout)
	_progress = PackedFloat32Array()
	_waiting = PackedFloat32Array()
	for i: int in range(count):
		_progress.append(0.0)
		_waiting.append(stagger_seconds(_bout, i))
	_elapsed = 0.0
	set_process(true)
	queue_redraw()


func _close_bout() -> void:
	_progress = PackedFloat32Array()
	_waiting = PackedFloat32Array()
	set_process(false)
	queue_redraw()
	_schedule_bout(bout_gap(_bout + 1))


func _draw() -> void:
	if _size.x <= 0.0 or _size.y <= 0.0:
		return
	var beat: float = sin(TAU * WING_BEAT * _elapsed)
	for i: int in range(_progress.size()):
		if _waiting[i] > 0.0 or _progress[i] >= 1.0:
			continue
		var at: Vector2 = bee_position(_bout, i, _progress[i], _size)
		var facing: float = bee_heading(_bout, i, _progress[i], _size)
		_draw_bee(at, facing, beat)
	# Left as found, so nothing drawn after this inherits a bee's transform.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_bee(at: Vector2, facing: float, beat: float) -> void:
	# The shadow first and in its own transform, because it is the one part of the drawing
	# that is not on the bee: it belongs to the ground the bee is above.
	draw_set_transform(at + SHADOW_OFFSET, facing, Vector2.ONE)
	draw_colored_polygon(ellipse_points(SHADOW_LENGTH, SHADOW_WIDTH), SHADOW_COLOR)

	draw_set_transform(at, facing, Vector2.ONE)
	var wings: Vector2 = wing_offsets(beat)
	for offset: float in [wings.x, wings.y]:
		var wing := PackedVector2Array()
		for point: Vector2 in ellipse_points(
				BODY_LENGTH * WING_LENGTH_RATIO, BODY_WIDTH * WING_WIDTH_RATIO):
			# Set back from the head: a wing rooted at the front reads as an ear.
			wing.append(point + Vector2(-2.4, offset))
		draw_colored_polygon(wing, WING_COLOR)

	var body: PackedVector2Array = ellipse_points(BODY_LENGTH, BODY_WIDTH)
	draw_colored_polygon(body, BODY_COLOR)
	var rim: PackedVector2Array = body.duplicate()
	rim.append(body[0])
	draw_polyline(rim, RIM_COLOR, 1.2, true)
	# Two stripes, back half of the body, at the half-heights the ellipse actually has
	# there — a stripe drawn to a fixed height pokes out of the narrow end.
	draw_line(Vector2(-1.44, -5.04), Vector2(-1.44, 5.04), RIM_COLOR, 1.4, true)
	draw_line(Vector2(-5.04, -3.84), Vector2(-5.04, 3.84), RIM_COLOR, 1.4, true)
	draw_circle(Vector2(BODY_LENGTH * 0.45, 0.0), BODY_WIDTH * 0.355, RIM_COLOR)
