class_name Cutworm
extends Pest

## The boss whose body fills fifteen of the road's thirty-two cells at once.
##
## `Pest.SPECIES[CUTWORM]` holds the stats and the reasoning behind each; this file is
## the two things that are genuinely different about it — HOW IT MOVES and HOW IT DRAWS.
## Everything else is inherited and deliberately untouched: the health pool, the damage
## pipeline, `died`/`escaped`, the `pests` group, the hit flash, the death cause. A
## Corn Cobbler aiming at it (`Plant._furthest_along_in_range`) and a Dandelion sorting
## by `progress()` both work without knowing this class exists.
##
## THE BODY IS NOT A CHAIN OF SPRITES. Fifteen 64 px sprites spaced one cell apart and
## snapped to cardinal rotations — which is what copying `Pest` gives you — opens gaps
## on the outside of every turn, piles up on the inside, and leaves three sprites square
## to the screen inside a diagonal bend. It reads as a train. What is drawn instead is
## ONE continuous outline swept along `Board.spine()`, so the body cannot leave the
## dirt, cannot open a gap, and cannot disagree with the road the head is walking.
##
## THE STATE IS ONE SCALAR. `_head_s` is the head's distance along the road; station
## `i` sits at `_head_s - i * STATION_SPACING`. There is no position-history buffer and
## no per-segment follower, so there is nothing that can desynchronise, and the whole
## animal is one number. Before `_head_s` reaches `i * STATION_SPACING` station `i` has
## not emerged and the body is simply cut off at s = 0 — which is off the west edge of
## the board, so the burrow is free rather than animated.
##
## The measurements every constant below is derived from were taken against the real
## `Board.PATH_CORNERS` and are written up in `docs/cutworm-design.html`.

## How many ring stations the body carries, and how far apart they sit.
##
## 21 gaps of 44 px is 924 px between the end stations; with the head cap (one GIRTH)
## that is 953 px of drawn animal, which is 14.9 of this road's 32 cells.
##
## 44 and not 64: the spacing has to be comfortably UNDER the body's own width (58 px)
## or the ring ticks read as joints between segments rather than as rings around one
## body. That is the whole difference between a worm and a caterpillar train.
const STATIONS: int = 22
const STATION_SPACING: float = 44.0

## Half the body's width. The lane is `Board.CELL` wide, so 32 is the hard ceiling and
## it is set by the STRAIGHTS, not by the corners — swept at 33 the body clips grass, at
## 32 it does not. 29 is 32 minus the peristaltic swing below, which is why the two
## constants may not be tuned independently.
const GIRTH: float = 29.0

## The thickness wave, and the surge that comes off the same term.
##
## A 64 px lane leaves no room to slither sideways and a snake wiggle would put the body
## on the grass. Real earthworms do not wiggle anyway — they move by a wave of thickness
## running head to tail — so this modulates the RADIUS and not the spine.
##
## The amplitude is derived, not chosen: GIRTH * 1.10 = 31.9 against a 32 px half-lane.
## At 0.12 the fat phase of the wave puts 5,568 body-edge samples on the grass; at 0.10,
## none of 382,068. `test_the_peristaltic_swing_is_whatever_the_lane_has_left_after_the_
## girth` holds the pair together.
##
## `SPEED_SURGE` reads the SAME sine, so the body's pulse and the animal's lurch are one
## motion and cannot look out of step with each other.
const PERISTALSIS_AMPLITUDE: float = 0.10
const PERISTALSIS_WAVELENGTH: float = 150.0
const PERISTALSIS_RATE: float = 2.2
const SPEED_SURGE: float = 0.25

## The three damage zones, by station index from the head.
##
## Fifteen cells of body means every plant on the board is in range of SOME part of it
## at once — and `Plant._furthest_along_in_range` picks the pest furthest along the road,
## which with one pest on the board is trivially this one. So the whole field fires at
## it, and the hide multiplier is the only thing between this and a two-second boss.
##
##   * `ZONE_MAW` 1.0 — the head. What every player tries first, and it is also the part
##     eating the garden, so it is the honest option and never the efficient one.
##   * `ZONE_HIDE` 0.15 — the trunk. NOT zero: a player raking the body should see chip
##     damage, because blanks read as a bug rather than as armour.
##   * `ZONE_BAND` 2.5 — the clitellum, stations 5 to 7. It rides five stations BEHIND
##     the head, which is 220 px of road the head has already walked and already chewed.
##     That is the fight: the plants that can hit the band are the plants the worm has
##     just eaten past, so you build a kill box behind it and pay for the ground with
##     plants you already know you are going to lose. It is the first pest in this game
##     answered from anywhere but the front of the queue.
const ZONE_MAW: float = 1.0
const ZONE_HIDE: float = 0.15
const ZONE_BAND: float = 2.5
const BAND_FIRST_STATION: int = 5
const BAND_LAST_STATION: int = 7

## How far from the head a hit still counts as hitting the head rather than the trunk.
## One station: the head cap plus the first ring, which is the part the sprite draws.
const MAW_REACH: float = STATION_SPACING

## The Cutworm eats through what an ordinary pest chews at, times this.
##
## Three, because the head has to clear the lane it walks for the band mechanic to mean
## anything: if the plants behind the head survived, the kill box would be free.
const EAT_MULTIPLIER: float = 3.0

## How much of a Sundew's slow it takes. See `Pest.slow_resistance`.
const SLOW_RESISTANCE: float = 0.5

## How far the body is sampled when the outline is swept.
##
## MEASURED, AND 4 PX WAS WRONG. At 4 px a full-length body is ~240 stations, and each
## costs two triangles for the hide plus two for the shadow — which, with a per-quad
## dorsal facet on top, put over 2000 `draw_colored_polygon` calls in one frame, rebuilt
## from scratch on every `_advance`. The live reading, from the bridge: 200 frames took
## 1213 ms with the body still emerging and 23454 ms once it was fully out — 165 fps
## against 8.5, on a board that idles at 171.
##
## 12 px is ~80 stations. The chord error against the tightest curve the body ever lies
## on (`RoadSpine.FILLET`, a 26 px radius) is about 12^2 / (8 x 26) = 0.7 px, which is
## under the rim's own 2.6 px width — so the outline is not visibly coarser, it is six
## times cheaper. `test_the_cutworms_frame_cost_stays_inside_its_budget` holds the count.
const OUTLINE_STEP: float = 12.0

## What one frame of body may cost, in `draw_colored_polygon` calls.
##
## A stated budget rather than a comment, because what went wrong is not visible in any
## single line of the drawing: it is the product of the sample step, the number of strips
## and the body's length, and each of those looks reasonable on its own. The number is
## derived in the test from `body_span() / OUTLINE_STEP`, so it moves when the geometry
## does — what it pins is that nobody adds a THIRD full-length strip without noticing.
const MAX_BODY_POLYGONS: int = 400

## The body's paint. Every shade is already in `art_src/STYLE.md`; see the head sprite's
## header for why sand and not the pest-red family every other bug wears.
const HIDE := Color("ECDCB8")
const HIDE_RIM := Color("A69B81")
const HIDE_LIT := Color("FFEDC6")
const BAND := Color("E74C3C")
const BAND_RIM := Color("AF392D")
const BODY_SHADOW := Color(0.24, 0.16, 0.09, 0.26)
const SHADOW_OFFSET := Vector2(0.0, 4.0)
const RIM_WIDTH: float = 2.6
const TICK_WIDTH: float = 2.2

## The drawn body sits UNDER the head sprite. `Pest._build_visuals` adds `_sprite` as a
## child, and a `_draw` on this node paints beneath its children, which is exactly the
## order wanted: the trunk runs in behind the head rather than over its face.

## The head's distance along the UNFILLETED route, in px.
##
## Unfilleted on purpose, and this is the one number in the file that has to be:
## `Board.spine()` is 2.8% shorter than `Board.route()` (2053 px against 2112), so a
## walk clocked on the drawn spine would deliver this boss 2.8% early and quietly move
## the timing every constant in `wave_director.gd` was measured against — with no local
## tell, because the animal would still look right. The fillet is for DRAWING.
var _head_s: float = 0.0

## The drawing spine and its arc-length index, both built once in `setup()`.
var _spine: PackedVector2Array = PackedVector2Array()
var _spine_cum: PackedFloat32Array = PackedFloat32Array()
var _walk_length: float = 0.0

## Advances with the physics clock, so the peristaltic wave has a phase. Separate from
## `_gait_time` because that one drives the inherited sway this species does not use.
var _pulse: float = 0.0


## The distance from the head station to the tail station. NOT the drawn length — the
## head cap adds one GIRTH in front of it, which is what makes the drawn animal 953 px.
static func body_span() -> float:
	return float(STATIONS - 1) * STATION_SPACING


## The drawn length, head cap included. What "fifteen cells" actually means.
static func drawn_length() -> float:
	return body_span() + GIRTH


## Pure: the body's half-width at `u` (0.0 at the head, 1.0 at the tail) with the
## peristaltic wave at arc position `s` and time `t` folded in.
##
## The profile is a blunt head, a long trunk that thins by 8% over its length, and a
## tail that tapers to a point across the last quarter. The taper is what makes the
## animal read head-and-tail rather than tube — a constant-radius body with a rounded
## end is a hose.
##
## A `static func` and not a method for the reason CLAUDE.md gives: headless executes no
## `_draw`, so a shape assembled inside one is a shape no test can reach. The whole
## outline is derived from this, so this is the seam the suite asserts through.
static func radius_at(u: float, s: float, t: float) -> float:
	var shape: float
	if u < 0.10:
		shape = 0.88 + 0.12 * (u / 0.10)
	elif u < 0.72:
		shape = 1.00 - 0.08 * ((u - 0.10) / 0.62)
	else:
		shape = maxf(0.05, 0.92 * pow(1.0 - (u - 0.72) / 0.28, 0.72))
	return GIRTH * shape * peristalsis(s, t)


## Pure: the thickness wave's multiplier at arc position `s` and time `t`.
##
## Public and separate from `radius_at` because `_effective_speed` reads THE SAME term
## to surge the walk — that is the point of it being one sine, and a second copy of this
## arithmetic living in the movement code is how the pulse and the lurch drift apart.
static func peristalsis(s: float, t: float) -> float:
	return 1.0 + PERISTALSIS_AMPLITUDE * sin(
		s / PERISTALSIS_WAVELENGTH * TAU - t * PERISTALSIS_RATE)


## Pure: how many samples the outline sweep takes between two arc positions.
##
## The seam the frame budget is measured through. `_sweep` and `_draw_band` both loop
## `range(sample_count(...))` rather than stepping a float until it overshoots, so
## `body_polygon_cost` below counts the work the drawing actually does instead of a second
## piece of arithmetic that can drift from it.
static func sample_count(from: float, to: float) -> int:
	if to <= from:
		return 0
	return int(ceilf((to - from) / OUTLINE_STEP)) + 1


## How many full-length filled strips one frame of body draws.
##
## Two: the hide, and the shadow under it. The dorsal facet is a single `draw_polyline`
## and the ring ticks are `draw_line`s, so neither scales with the body's length — which
## is the whole reason they are drawn that way (see OUTLINE_STEP). A third strip added
## here without this number moving is what the budget test refuses.
const STRIPS_PER_FRAME: int = 2


## Pure: how many `draw_colored_polygon` calls one frame of this body costs, at a given
## head position. Two triangles per sample gap per strip, plus the band's partial strip.
##
## THE NUMBER THAT WAS NOT BEING WATCHED. Frame rate is a machine fact and it is what
## eventually reported this — 8.5 fps on a board that idles at 171 — but by then the cause
## was three constants deep. Draw calls are machine-independent and can be asserted with
## no game at all, which is what `test_the_cutworms_frame_cost_stays_inside_its_budget`
## does.
static func body_polygon_cost(head_s: float, walk_length: float) -> int:
	var head: float = minf(head_s, walk_length)
	var tail: float = maxf(0.0, head_s - body_span())
	var body: int = maxi(0, sample_count(tail, head) - 1)
	var band: Vector2 = band_range(head_s)
	var band_gaps: int = maxi(0, sample_count(maxf(band.x, tail), minf(band.y, head)) - 1)
	return (body * STRIPS_PER_FRAME + band_gaps) * 2


## Pure: the arc positions the weak band spans, given where the head is.
## Returns `[from, to]`, from being the further-back (smaller) value.
static func band_range(head_s: float) -> Vector2:
	return Vector2(head_s - float(BAND_LAST_STATION) * STATION_SPACING,
		head_s - float(BAND_FIRST_STATION) * STATION_SPACING)


## Pure: what a hit `behind` px back from the head is worth. The zone table, as one
## function, with no node and no tree — which is what lets the suite check every station
## along the whole walk rather than three sampled points.
static func zone_multiplier(behind: float) -> float:
	if behind <= MAW_REACH:
		return ZONE_MAW
	if behind >= float(BAND_FIRST_STATION) * STATION_SPACING \
			and behind <= float(BAND_LAST_STATION) * STATION_SPACING:
		return ZONE_BAND
	return ZONE_HIDE


func setup(which: StringName, route: PackedVector2Array) -> void:
	super.setup(which, route)
	_walk_length = RoadSpine.length_of(route)
	_spine = RoadSpine.fillet(route, RoadSpine.FILLET)
	_spine_cum = RoadSpine.cumulative(_spine)
	# The head starts where the route starts, which is off the west edge of the board,
	# so the first thing a player sees is a mouth coming out of the ground rather than a
	# whole animal appearing at the gate.
	_head_s = 0.0


## The walk, and the only override of it.
##
## `Pest._advance` walks waypoint legs and calls `_escape()` the moment the head runs
## out of route. That is right for a 64 px body and wrong for this one twice over: the
## head reaching the exit is not this pest leaving (fourteen cells of it are still on
## the board taking damage), and the position it should sit at is an arc length rather
## than a leg index.
func _advance(distance: float) -> void:
	_head_s += distance
	# Clamped: once the head is off the east edge it stays parked there while the rest of
	# the body walks out from under it. `progress()` reads 1.0 throughout, which is what
	# keeps the cobs aimed at it rather than switching to nothing.
	position = RoadSpine.point_at(_spine, _spine_cum, minf(_head_s, _walk_length))
	_update_facing(RoadSpine.tangent_at(_spine, _spine_cum, minf(_head_s, _walk_length)))
	queue_redraw()
	# It escapes TAIL-last. Damage keeps landing on the band and the tail for 47.7 s
	# after the head has gone, and the lives are only spent when the last of it clears,
	# so the comeback is real and the tension holds to the end of the wave.
	if _head_s - drawn_length() >= _walk_length:
		_escape()


## Free rotation, against `Pest`'s four-way snap.
##
## The base class snaps to a cardinal because `Board.route()`'s legs are axis-aligned
## and a 64 px sprite turning a right angle in one frame is correct. This head is on a
## FILLETED spine whose tangent sweeps continuously through a corner, so a snap here
## would leave the head square to the screen while its own body was diagonal — exactly
## the tell that makes a sprite chain read as a train.
##
## Sprites rest head-up-screen (-Y) per `art_src/STYLE.md`, i.e. a heading of `-PI/2`,
## so the sprite's rotation is the heading plus a quarter turn.
func _update_facing(direction: Vector2) -> void:
	if _sprite == null or direction.length() < 0.0001:
		return
	_sprite.rotation = direction.angle() + PI * 0.5


## Distance along the road, taken from the arc length rather than the leg index.
##
## `Pest.progress()` divides `_leg` by the route size, and this class never advances
## `_leg`, so without this override the boss would report 0.0 for its entire walk and
## every cob on the board would treat it as the pest furthest BEHIND.
func progress() -> float:
	if _walk_length <= 0.0:
		return 0.0
	return clampf(_head_s / _walk_length, 0.0, 1.0)


## Where the head is along the road, in px. Public because it is the whole state of the
## animal, and because a bridge session inspecting the boss has nothing else to read.
func head_distance() -> float:
	return _head_s


## The surge, off the same sine the body's thickness wave uses.
##
## `super()` first, so a Sundew's slow (which writes `speed`) and the inherited species
## machinery both still apply — this multiplies whatever the rest of the game decided.
func _effective_speed() -> float:
	return super._effective_speed() * (1.0 + SPEED_SURGE
		* (peristalsis(_head_s, _pulse) - 1.0) / PERISTALSIS_AMPLITUDE)


func _physics_process(delta: float) -> void:
	_pulse += delta
	super._physics_process(delta)


# --- the six species hooks (see Pest) ----------------------------------------

func damage_multiplier_at(hit_at: Vector2) -> float:
	# A caller that does not track where its hit landed gets the hide, not the head.
	# That is the conservative answer rather than the convenient one: a damage source
	# added later and wired up carelessly makes the boss HARDER, which shows up in a
	# playtest, instead of easier, which does not.
	if not hit_at.is_finite():
		return ZONE_HIDE
	return zone_multiplier(_arc_behind_head(hit_at))


func eat_dps() -> float:
	return super.eat_dps() * EAT_MULTIPLIER


func halts_to_eat() -> bool:
	return false


func eats_in_passing() -> bool:
	return true


func slow_resistance() -> float:
	return SLOW_RESISTANCE


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	# The base class paints the mutation markers and the fought ring on this same canvas
	# item; skipping `super` would delete both silently.
	super._draw()
	if _spine.is_empty():
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var ticks: Array[Vector2] = []
	_sweep(left, right, ticks)
	if left.size() < 2:
		return
	_fill_strip(left, right, BODY_SHADOW, SHADOW_OFFSET)
	_fill_strip(left, right, HIDE, Vector2.ZERO)
	# One flat highlight facet down the back, never a gradient (art_src/STYLE.md).
	#
	# ONE `draw_polyline`, not a third filled strip. As a strip it cost as many triangles
	# as the body itself for a highlight that did not survive being looked at on screen —
	# see OUTLINE_STEP for what that arithmetic did to the frame rate. A stroked line
	# cannot taper, so it stops before the tail does rather than spilling off the point.
	draw_polyline(_across(left, right, SHEEN_NEAR + (SHEEN_FAR - SHEEN_NEAR) * 0.5),
		HIDE_LIT, GIRTH * (SHEEN_FAR - SHEEN_NEAR) * 2.0)
	_draw_band()
	_draw_ticks(ticks)
	draw_polyline(left, HIDE_RIM, RIM_WIDTH)
	draw_polyline(right, HIDE_RIM, RIM_WIDTH)
	# The tail's blunt end. The head's is under the sprite and needs no cap.
	draw_line(left[0], right[0], HIDE_RIM, RIM_WIDTH)


## One pass down the live span, filling both edges of the outline and the ring ticks.
##
## Local space: this node sits at the head, so everything is offset by `position`. The
## span runs from the tail end (clamped to the entry, which is the burrow) to the head
## end (clamped to the exit, which is where the head parks while the body walks out).
func _sweep(left: PackedVector2Array, right: PackedVector2Array, ticks: Array[Vector2]) -> void:
	var span: float = body_span()
	var head: float = minf(_head_s, _walk_length)
	var tail: float = maxf(0.0, _head_s - span)
	if head <= tail:
		return
	# Counted first and then indexed, rather than stepped until it overshoots. Two reasons,
	# and neither is style: a `while` that walks by a float lands its final sample on top
	# of its predecessor whenever the last step is short, which is one of the two ways a
	# degenerate quad reached the triangulator (see `_fill_strip`) -- and the count is what
	# `body_polygon_cost` reads, so the budget measures the sweep rather than a second
	# arithmetic that could drift from it.
	var samples: int = sample_count(tail, head)
	for i: int in range(samples):
		var here: float = minf(tail + float(i) * OUTLINE_STEP, head)
		var at: Vector2 = RoadSpine.point_at(_spine, _spine_cum, here) - position
		var normal: Vector2 = RoadSpine.tangent_at(_spine, _spine_cum, here).orthogonal()
		var r: float = radius_at(clampf((_head_s - here) / span, 0.0, 1.0), here, _pulse)
		left.append(at + normal * r)
		right.append(at - normal * r)
	for i: int in range(1, STATIONS):
		var station: float = _head_s - float(i) * STATION_SPACING
		if station < tail or station > head:
			continue
		var at: Vector2 = RoadSpine.point_at(_spine, _spine_cum, station) - position
		var normal: Vector2 = RoadSpine.tangent_at(_spine, _spine_cum, station).orthogonal()
		var r: float = radius_at(clampf((_head_s - station) / span, 0.0, 1.0), station, _pulse)
		ticks.append(at + normal * r)
		ticks.append(at - normal * r)
		ticks.append(Vector2(station, 0.0))


## Where the dorsal facet sits, as a fraction across the body from the left edge.
## 0.19..0.31 puts a band a quarter of the width wide over the back, clear of both rims.
const SHEEN_NEAR: float = 0.19
const SHEEN_FAR: float = 0.31


## One edge lerped across to the other, `f` of the way. `f = 0` is `left`, `f = 1` is
## `right`, and anything between is a line running parallel to both down the body.
static func _across(left: PackedVector2Array, right: PackedVector2Array,
		f: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(left.size())
	for i: int in range(left.size()):
		out[i] = left[i].lerp(right[i], f)
	return out


## Fills the ribbon between two edges as a run of quads, one per sample step.
##
## NOT as one closed polygon, and that is not a style preference: a worm lying through
## a corner is a concave outline, and `draw_colored_polygon` on a concave polygon
## produces a fan that folds across the bend — the body renders with a triangular bite
## taken out of the inside of every turn. Each quad here is convex by construction, so
## there is nothing to triangulate wrongly.
## DEGENERATE QUADS ARE SKIPPED, and that is not defensive coding — it is the one thing
## about this drawing that headless could not have told us. `_draw` never executes in a
## headless run, so the first live frame produced a stream of
##
##     ERROR: Invalid polygon data, triangulation failed.
##        [0] _fill_strip (res://game/cutworm.gd)
##
## once per frame per bad quad. Two ways one arises, both real: the tail's profile taper
## brings the two edges to within a pixel of each other, and the sweep's final sample is
## clamped to the head, so a step landing all but exactly on it appends a point on top of
## its predecessor. Either way the quad has no area, and Godot's triangulator rejects it
## rather than drawing nothing quietly.
const MIN_QUAD_AREA: float = 0.05

## TRIANGLES, NOT QUADS, and the reason is the corner rather than the tail.
##
## The first live frame threw `Invalid polygon data, triangulation failed` from here even
## after degenerate quads were skipped, and the second backtrace named `_draw_band` rather
## than the tail. That is a different failure: an offset curve FOLDS wherever the offset
## exceeds the local curvature radius, so at a 26 px fillet the inner edge of a 29 px body
## crosses itself and the quad becomes a bowtie — self-intersecting, nonzero area, and
## still un-triangulatable.
##
## It cannot be tuned away. The fold clears only with a fillet wider than the body's fat
## phase (29 x 1.10 = 31.9), and `RoadSpine.FILLET_LEG_FRACTION` caps the fillet at 30.7
## on this road's 64 px legs. So the geometry is accepted and the drawing is made immune
## to it: a triangle cannot self-intersect, so splitting each segment into two removes the
## whole class. What remains on screen is a ~2 px pinch on the inside of a corner at the
## fat phase of the wave, underneath the overlapping neighbouring segments.
func _fill_strip(left: PackedVector2Array, right: PackedVector2Array, colour: Color,
		offset: Vector2) -> void:
	var tri := PackedVector2Array()
	tri.resize(3)
	for i: int in range(left.size() - 1):
		tri[0] = left[i] + offset
		tri[1] = left[i + 1] + offset
		tri[2] = right[i] + offset
		if quad_area(tri) >= MIN_QUAD_AREA:
			draw_colored_polygon(tri, colour)
		tri[0] = left[i + 1] + offset
		tri[1] = right[i + 1] + offset
		tri[2] = right[i] + offset
		if quad_area(tri) >= MIN_QUAD_AREA:
			draw_colored_polygon(tri, colour)


## Pure: the unsigned area of a quad, by the shoelace formula.
##
## Split out and public because it is the gate above, and a gate inside `_draw` is a gate
## no test can reach — CLAUDE.md's rule about geometry living in a `static func`. The
## live-frame check that found the bug asserts against this, not against a screenshot.
static func quad_area(quad: PackedVector2Array) -> float:
	if quad.size() < 3:
		return 0.0
	var total: float = 0.0
	for i: int in range(quad.size()):
		var a: Vector2 = quad[i]
		var b: Vector2 = quad[(i + 1) % quad.size()]
		total += a.x * b.y - b.x * a.y
	return absf(total) * 0.5


## The clitellum, drawn as its own quad strip over the hide rather than as a clipped
## band, because Godot's canvas has no clip for an arbitrary polygon and a rectangle
## clip would cut it square across a bend.
func _draw_band() -> void:
	var range_px: Vector2 = band_range(_head_s)
	var span: float = body_span()
	var head: float = minf(_head_s, _walk_length)
	var tail: float = maxf(0.0, _head_s - span)
	var from: float = maxf(range_px.x, tail)
	var to: float = minf(range_px.y, head)
	if to <= from:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	# Same counted loop as `_sweep`, and through the same `sample_count`, for the same two
	# reasons written out there.
	var samples: int = sample_count(from, to)
	for i: int in range(samples):
		var here: float = minf(from + float(i) * OUTLINE_STEP, to)
		var at: Vector2 = RoadSpine.point_at(_spine, _spine_cum, here) - position
		var normal: Vector2 = RoadSpine.tangent_at(_spine, _spine_cum, here).orthogonal()
		var r: float = radius_at(clampf((_head_s - here) / span, 0.0, 1.0), here, _pulse)
		left.append(at + normal * r)
		right.append(at - normal * r)
	if left.size() < 2:
		return
	_fill_strip(left, right, BAND, Vector2.ZERO)
	draw_polyline(left, BAND_RIM, RIM_WIDTH)
	draw_polyline(right, BAND_RIM, RIM_WIDTH)


## The ring ticks: one line across the body at each station, in the rim shade — or the
## band's rim where the station is inside the clitellum, so the segmentation carries on
## across the weak point instead of stopping at it.
func _draw_ticks(ticks: Array[Vector2]) -> void:
	var range_px: Vector2 = band_range(_head_s)
	for i: int in range(0, ticks.size(), 3):
		var station: float = ticks[i + 2].x
		var inside: bool = station >= range_px.x and station <= range_px.y
		draw_line(ticks[i], ticks[i + 1], BAND_RIM if inside else HIDE_RIM, TICK_WIDTH)


## How far back along the body a world-space point sits, in px, by nearest approach to
## the spine rather than by straight-line distance to the head.
##
## Straight-line would be wrong exactly where it matters: at a corner the head and a
## station eight cells back can be 90 px apart in a straight line and 500 px apart along
## the animal, and a kernel hitting the trunk there would be scored as hitting the maw.
func _arc_behind_head(hit_at: Vector2) -> float:
	var best: float = _head_s
	var best_distance: float = INF
	var span: float = body_span()
	var head: float = minf(_head_s, _walk_length)
	var tail: float = maxf(0.0, _head_s - span)
	var s: float = tail
	while s <= head:
		var d: float = RoadSpine.point_at(_spine, _spine_cum, s).distance_squared_to(hit_at)
		if d < best_distance:
			best_distance = d
			best = s
		s += OUTLINE_STEP
	return _head_s - best
