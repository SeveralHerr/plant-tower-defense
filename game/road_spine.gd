class_name RoadSpine
extends RefCounted

## The road as a curve a long body can lie along, rather than as a list of cells.
##
## `Board.route()` is one waypoint per path cell bracketed by an off-board entry and
## exit, so every leg is axis-aligned and every corner is an exact right angle. That
## is deliberate and it is what makes `Pest._update_facing`'s four-way snap correct
## rather than approximate (pest.gd) — a 64 px sprite turns a corner in one frame and
## nobody notices.
##
## The Cutworm cannot do that. Its drawn body is 953 px long, which puts it inside
## three of this road's five corners at once, so it needs a spine whose TANGENT is
## continuous and not merely whose position is. `fillet()` supplies one; the rest of
## this file is the arc-length sampling that goes with it.
##
## Everything here is a pure static over its arguments — no board, no tree, no state —
## for the same reason `Board.road_cell_count` and `Board.road_length_px` are: it makes
## the geometry assertable without instantiating anything, and it means the design
## page's measurements (docs/cutworm-design.html) and the game compute the same shape
## from the same inputs.

## The fillet radius the Cutworm walks, and the one every measurement in
## docs/cutworm-design.html was taken at.
##
## 26 and not more: the fillet is bounded below `Board.CELL * 0.5` because a corner cut
## deeper than half a cell starts pulling the spine out of the cell that owns the
## corner. Measured at this radius against the real `PATH_CORNERS`, 0 of 104,136
## body-edge samples leave a road cell across the whole walk — the bend costs no grass.
const FILLET: float = 26.0

## How much of each incoming leg a corner may eat. Both legs of every interior corner
## on this road are a full cell (64 px), so 0.48 never binds here — it exists so a
## board handed a road with a one-cell jog (`Board.set_road`) fillets it proportionally
## instead of overrunning the leg and folding the spine back on itself.
const FILLET_LEG_FRACTION: float = 0.48

## Bezier samples per px of fillet radius. 1.6 px per sample at r = 26 is 16 points
## across a quarter turn, which is under half a pixel of chord error — invisible at
## this scale, and cheap enough that the spine is rebuilt rather than cached.
const FILLET_SAMPLE_STEP: float = 1.6


## The route with every interior corner cut back by `radius` and replaced by a
## quadratic Bezier through the original vertex.
##
## THE LENGTH CHANGES, AND THAT IS THE TRAP. Cutting corners is shorter: this road's
## 2112 px becomes 2053.1 px at radius 26, −2.8%. A walk clock keyed to the filleted
## length would deliver every boss 2.8% early and quietly move the timing every number
## in `wave_director.gd` was measured against. So the fillet is for DRAWING and for the
## body's tangent; `Cutworm` walks and reports `progress()` on the unfilleted route.
## `test_the_fillet_does_not_change_what_the_road_is_worth` holds that apart.
##
## A radius of 0 returns the points unchanged, which is what makes this safe to call
## unconditionally — including on a route that has no corners left to cut.
static func fillet(points: PackedVector2Array, radius: float) -> PackedVector2Array:
	var turns: PackedVector2Array = corners(points)
	if radius <= 0.0 or turns.size() < 3:
		return turns
	var out := PackedVector2Array()
	out.append(turns[0])
	for i: int in range(1, turns.size() - 1):
		var a: Vector2 = turns[i - 1]
		var b: Vector2 = turns[i]
		var c: Vector2 = turns[i + 1]
		var r: float = minf(radius, minf(a.distance_to(b), b.distance_to(c)) * FILLET_LEG_FRACTION)
		if r < 0.75:
			out.append(b)
			continue
		var from: Vector2 = b + (a - b).normalized() * r
		var to: Vector2 = b + (c - b).normalized() * r
		out.append(from)
		var steps: int = maxi(3, int(roundf(r / FILLET_SAMPLE_STEP)))
		for k: int in range(1, steps + 1):
			out.append(_quadratic(from, b, to, float(k) / float(steps)))
	out.append(turns[turns.size() - 1])
	return out


## The route reduced to the points where it actually turns.
##
## `Board.route()` emits one point per cell, so a straight run of six cells is five
## collinear waypoints with nothing to fillet. Dropping them first is not an
## optimisation: `fillet()` reads each vertex's two neighbours to find the corner's
## legs, and a collinear neighbour one cell away would cap every radius at 30 px
## whatever was asked for.
static func corners(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points.duplicate()
	var out := PackedVector2Array()
	out.append(points[0])
	for i: int in range(1, points.size() - 1):
		var into: Vector2 = (points[i] - points[i - 1]).sign()
		var out_of: Vector2 = (points[i + 1] - points[i]).sign()
		if not into.is_equal_approx(out_of):
			out.append(points[i])
	out.append(points[points.size() - 1])
	return out


## Cumulative distance to each point, so `point_at` can be a search rather than a walk.
## `cumulative(pts)[i]` is the arc length from the start to `pts[i]`; the last entry is
## the whole length, which is what `length_of` hands back.
static func cumulative(points: PackedVector2Array) -> PackedFloat32Array:
	var cum := PackedFloat32Array()
	cum.resize(points.size())
	if points.is_empty():
		return cum
	cum[0] = 0.0
	for i: int in range(1, points.size()):
		cum[i] = cum[i - 1] + points[i - 1].distance_to(points[i])
	return cum


static func length_of(points: PackedVector2Array) -> float:
	if points.size() < 2:
		return 0.0
	var total: float = 0.0
	for i: int in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


## The point `s` px along the polyline, clamped at both ends.
##
## Clamped rather than wrapped or refused, because both ends are load-bearing for the
## Cutworm: a station behind the entry has not emerged yet and one past the exit has
## already left, and both cases want the end point rather than an error. The body is
## cut off there, which is the burrow and the exit for free.
static func point_at(points: PackedVector2Array, cum: PackedFloat32Array, s: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var last: int = points.size() - 1
	if s <= 0.0:
		return points[0]
	if s >= cum[last]:
		return points[last]
	var lo: int = 0
	var hi: int = last
	while lo < hi - 1:
		var mid: int = (lo + hi) / 2
		if cum[mid] <= s:
			lo = mid
		else:
			hi = mid
	var span: float = cum[hi] - cum[lo]
	var t: float = 0.0 if span <= 0.0 else (s - cum[lo]) / span
	return points[lo].lerp(points[hi], t)


## The unit direction of travel at `s`, by central difference rather than by reading
## the segment `s` happens to land in.
##
## The difference matters exactly at a fillet's seam: a segment read there flips by a
## few degrees between one 1.6 px Bezier chord and the next, and a body whose ring
## ticks are drawn off that reading shows the seams. Averaging across `HALF_STEP` on
## both sides smooths it to the curve the fillet is approximating.
const TANGENT_HALF_STEP: float = 5.0

static func tangent_at(points: PackedVector2Array, cum: PackedFloat32Array, s: float) -> Vector2:
	if points.size() < 2:
		return Vector2.RIGHT
	var total: float = cum[points.size() - 1]
	var back: Vector2 = point_at(points, cum, maxf(0.0, s - TANGENT_HALF_STEP))
	var ahead: Vector2 = point_at(points, cum, minf(total, s + TANGENT_HALF_STEP))
	var delta: Vector2 = ahead - back
	if delta.length() < 0.0001:
		return Vector2.RIGHT
	return delta.normalized()


static func _quadratic(from: Vector2, control: Vector2, to: Vector2, t: float) -> Vector2:
	var m: float = 1.0 - t
	return from * (m * m) + control * (2.0 * m * t) + to * (t * t)
