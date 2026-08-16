class_name StickySundew
extends Plant

## The fourth plant, and the first one that does not kill, hold or pay.
##
## Everything already in the catalogue answers a pest by taking it OFF the board:
## a Corn Cobbler shoots it, a Chomp Flower swallows it, a Seed Sunflower pays for
## the two of them. That leaves one axis of a pest completely untouched — how fast
## it is — and two threats that walk straight through the gap:
##
##   * `Pest.is_winged`. A Chomp Flower is forbidden from grabbing it (see
##     ChompFlower._nearest_free_pest), so a lane walled with mouths does nothing
##     at all to a flier and the only answer on the board is raw Corn damage. A
##     Sundew's dew is on the ground the flier is over, not in a mouth it has to
##     fit into, so this is the second plant in the game that can touch one — and
##     the first that can touch several at once.
##   * `WaveDirector.speed_scale_for`. Endless mode literally multiplies every
##     pest's `speed` wave after wave, and until this plant nothing in the
##     catalogue reacted to that number in any way. A Sundew is the only thing
##     that reads it back down.
##
## The trade is deliberately the mirror image of a Chomp Flower's. A Chomp takes
## ONE pest, TOTALLY, TEMPORARILY, and is busy the whole time. A Sundew takes
## EVERY pest in its patch, PARTIALLY, PERMANENTLY, and is never busy — but it
## deals no damage whatsoever, so a garden of nothing but Sundews is a garden
## where the bugs arrive late and win anyway. It is a multiplier on guns that
## already cover the same road, which is what makes where you put it a decision.

## How far the dew spreads. Must clear one cell for the same reason
## ChompFlower.GRAB_RADIUS must — a plant stands on grass, a pest walks the road,
## so anything under CELL never touches the lane beside it. Kept well under a Corn
## Cobbler's RANGE (176) so a Sundew can never blanket everything one cob covers:
## the patch is a stretch of road you choose, not the whole board.
const SAP_RADIUS: float = Board.CELL * 1.85

## What a caught pest's `speed` is multiplied by. 0.55 is a 45% cut: an aphid
## drops 78 -> 42.9 and a beetle 38 -> 20.9. Big enough that a Corn Cobbler
## covering the same road lands ~1.8x as many kernels per crossing, small enough
## that it is never a stun — a Sundew always leaks, it just leaks slowly.
const SLOW_FACTOR: float = 0.55

## The slow does NOT stack. Two overlapping patches hold a pest at 0.55, not at
## 0.30 — a stacking slow is a stun as soon as you can afford three of them, and
## a stun this cheap would delete the Chomp Flower's whole reason to exist.
##
## Enforced with a source COUNT rather than a flag, kept as metadata on the pest
## itself: whichever Sundew arrives first records the pest's untouched speed and
## applies the cut, every later one only increments, and the speed is handed back
## exactly once, when the last patch lets go. A plain flag would be restored by
## whichever plant released first and leave the pest walking at full speed inside
## a patch it is still standing in; a per-plant saved base would be worse still,
## since the second Sundew would save the ALREADY-SLOWED speed as the original and
## strand the pest at 0.55 forever after both let go.
const META_SOURCES: StringName = &"sundew_slow_sources"
const META_BASE_SPEED: StringName = &"sundew_base_speed"

## The board readout: a stipple of dew beads around the rim of the patch, on all
## the time, plus a very faint wash over the ground inside it.
##
## Deliberately not a stroked circle. CornCobbler owns a stroked ring (green, thin,
## at RANGE, only while `_selected`) and ChompFlower owns the other one (orange,
## 3px, shrinking, only mid-meal), so a third stroked circle would read as one of
## those two. This differs on every axis at once: broken into beads instead of
## drawn as a line, blue-grey instead of green or orange — the one palette family
## nothing else on this board uses — and always on rather than conditional, for the
## same reason the Sunflower's gauge is always on. A patch of ground you have to
## click a plant to see is a patch you will plant a gun outside of.
const DROPLETS: int = 12
## First bead straight up-screen, matching the kit's facing convention. Twelve at
## 30 degrees from there is symmetric about the vertical axis, like the sprite.
const DROPLET_PHASE: float = -PI * 0.5
const DROPLET_IDLE: float = 2.4
const DROPLET_FULL: float = 4.4
## How many stuck pests count as "working flat out". Beads swell towards
## DROPLET_FULL as the patch fills, so a Sundew that is earning its 30 seeds looks
## different from one sitting in a lane nothing walks down.
const DROPLET_SWELL_AT: int = 3

const PATCH_COLOR := Color(0.54, 0.64, 0.65, 0.10)
const DROPLET_COLOR := Color(0.64, 0.76, 0.78, 0.90)
const DROPLET_RIM_COLOR := Color(0.46, 0.55, 0.56, 0.90)
const DROPLET_RIM_WIDTH: float = 1.2

## The pests this particular Sundew currently holds a source on. Not a set of
## every slowed pest on the board — each patch tracks only its own claim, and the
## metadata above is what reconciles overlapping claims.
var _stuck: Array[Pest] = []
## Last bead size actually painted. The patch changes only when a pest enters or
## leaves, so without this a field of Sundews would repaint every frame for a
## picture that did not move.
var _drawn_radius: float = -1.0


## A hungry pest can eat the Sundew out from under its own patch. If that left the
## board's pests holding a slow whose source no longer exists, every bug in that
## lane would walk at 55% for the rest of the run with nothing on screen to explain
## it — the worst kind of bug, because it looks like balance.
func _on_setup() -> void:
	destroyed.connect(func(_p: Plant) -> void: release_all())


## Uprooting frees the node, which is the other way a patch can vanish. Plant does
## not define `_exit_tree` today; if it ever does, this override will eat it and
## will need a `super._exit_tree()` — the same trap SelectionMarker's header
## describes for `_draw`.
func _exit_tree() -> void:
	release_all()


func _act(_delta: float, pests: Array[Pest]) -> void:
	apply_patch(pests)


## One step of stickiness: let go of anything that left, catch anything that
## arrived. Public and delta-free on purpose — the whole mechanic is then drivable
## from a test without a physics frame, a tween or a wave.
func apply_patch(pests: Array[Pest]) -> void:
	for i: int in range(_stuck.size() - 1, -1, -1):
		var held: Pest = _stuck[i]
		if not is_instance_valid(held) or not held.is_alive() or not covers(held):
			_release_at(i)
	for pest: Pest in pests:
		if _stuck.has(pest) or not covers(pest):
			continue
		_claim(pest)
	_refresh_droplets()


## Whether `pest` is standing in this patch right now.
func covers(pest: Pest) -> bool:
	if pest == null or not is_instance_valid(pest):
		return false
	return pest.global_position.distance_to(global_position) <= SAP_RADIUS


func _claim(pest: Pest) -> void:
	_stuck.append(pest)
	var sources: int = slow_sources(pest)
	if sources == 0:
		pest.set_meta(META_BASE_SPEED, pest.speed)
		pest.speed = slowed_speed(pest.speed)
	pest.set_meta(META_SOURCES, sources + 1)


func _release_at(index: int) -> void:
	var pest: Pest = _stuck[index]
	_stuck.remove_at(index)
	# A pest that died or escaped took its metadata to the grave with it; there is
	# no speed left to hand back and no counter left to decrement.
	if not is_instance_valid(pest):
		return
	var sources: int = slow_sources(pest) - 1
	if sources > 0:
		pest.set_meta(META_SOURCES, sources)
		return
	pest.remove_meta(META_SOURCES)
	if pest.has_meta(META_BASE_SPEED):
		pest.speed = float(pest.get_meta(META_BASE_SPEED))
		pest.remove_meta(META_BASE_SPEED)


## Lets go of everything this patch holds, restoring any pest no other patch is
## still standing on.
func release_all() -> void:
	for i: int in range(_stuck.size() - 1, -1, -1):
		_release_at(i)


## How many live pests this patch is holding. What the beads are sized from, and
## what the selection panel would read.
func stuck_count() -> int:
	var n: int = 0
	for pest: Pest in _stuck:
		if is_instance_valid(pest) and pest.is_alive():
			n += 1
	return n


# ------------------------------------------------------------------ pure model

## Pure: what a pest walking at `base_speed` slows to inside a patch.
static func slowed_speed(base_speed: float) -> float:
	return base_speed * SLOW_FACTOR


## Pure: how much longer the same stretch of road takes to cross once it is
## sticky — i.e. how much more time every gun covering it gets. This is the
## number the plant is priced against, so it is stated rather than left implied.
static func crossing_time_multiplier() -> float:
	return 1.0 / SLOW_FACTOR


## How many patches are currently holding `pest`. 0 for an untouched pest, and
## still 0 for one that was released, since the metadata is removed rather than
## zeroed.
static func slow_sources(pest: Pest) -> int:
	if pest == null or not is_instance_valid(pest):
		return 0
	return int(pest.get_meta(META_SOURCES, 0))


static func is_slowed(pest: Pest) -> bool:
	return slow_sources(pest) > 0


## Where the dew beads sit, in the plant's own space: evenly spaced on the rim of
## the patch, first one up-screen. Pure, so what gets drawn is checkable without
## rendering a frame.
static func droplet_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in range(DROPLETS):
		var angle: float = DROPLET_PHASE + TAU * float(i) / float(DROPLETS)
		out.append(Vector2.RIGHT.rotated(angle) * SAP_RADIUS)
	return out


## Bead size for a patch holding `stuck` pests — idle at none, saturating at
## DROPLET_SWELL_AT so a busy patch does not keep growing off its own rim.
static func droplet_radius(stuck: int) -> float:
	var t: float = clampf(float(stuck) / float(DROPLET_SWELL_AT), 0.0, 1.0)
	return lerpf(DROPLET_IDLE, DROPLET_FULL, t)


# ---------------------------------------------------------------------- visuals

## Note there is no super._draw() call here, and there must not be: the selection
## brackets live in a SelectionMarker child precisely because an override like
## this one eats them. See SelectionMarker's header.
func _draw() -> void:
	draw_circle(Vector2.ZERO, SAP_RADIUS, PATCH_COLOR)
	var radius: float = droplet_radius(stuck_count())
	for bead: Vector2 in droplet_points():
		draw_circle(bead, radius + DROPLET_RIM_WIDTH, DROPLET_RIM_COLOR)
		draw_circle(bead, radius, DROPLET_COLOR)


func _refresh_droplets() -> void:
	var radius: float = droplet_radius(stuck_count())
	if is_equal_approx(radius, _drawn_radius):
		return
	_drawn_radius = radius
	queue_redraw()
