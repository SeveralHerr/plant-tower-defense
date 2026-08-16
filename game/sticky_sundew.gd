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

## The wash is painted as a UNION, not as one disc per plant, and that is a
## correctness fix rather than a polish pass (plant-tower-defense-3lu).
##
## Every patch used to fill its own disc at PATCH_COLOR's alpha 0.10. Alpha
## blending is not idempotent: two of those laid over the same grass composite to
## an effective 1 - 0.9^2 = 0.19, so the lens where two patches met came out
## nearly twice as strong as either patch alone. The board was therefore drawing
## "more slow here" over the one piece of ground where the slow is provably
## identical — see META_SOURCES, where the refcount deliberately holds an
## overlapped pest at SLOW_FACTOR rather than at SLOW_FACTOR squared. A player
## could spend 60 seeds covering one stretch of road twice and be shown a darker
## patch of grass as their receipt.
##
## So each patch subtracts the discs of every overlapping patch that got here
## first (see _wash_order) and fills only what is left. The union is then painted
## exactly once, at exactly the alpha a single patch is painted at, everywhere.
##
## What still shows there are two plants is the beads: each patch keeps its own
## full rim of them, so two overlapping Sundews read as two bead rings crossing
## over one evenly-washed piece of ground. That is the truth stated in pictures —
## two plants, one slow.
const WASH_SEGMENTS: int = 48

## Paint order for that union. Of any two overlapping patches exactly one has to
## own the lens they share, so the two need a total order they both agree on.
## Assigned on construction and never reused: node order under Entities is not
## usable for this, because it shifts every time any sibling is uprooted, and a
## patch whose rank changed under it would hand the lens back and forth.
static var _next_wash_order: int = 0

## Every patch currently in the tree, oldest `_wash_order` first.
##
## Kept as a class-level list rather than found by scanning, and that is a cost
## fix rather than a tidy-up (plant-tower-defense-fp5). The scan it replaces was a
## walk over this node's siblings — and a Sundew's siblings under `Entities` are
## every pest on the board as well as every other plant (see Game.spawn_pest), so
## the price of drawing ONE patch scaled with the number of BUGS. Worse, the
## redraws are densest exactly when that number is highest: `_refresh_droplets`
## queues one every time the bead size moves, and the bead size is read off how
## many pests are stuck in the patch.
##
## Membership changes at exactly two moments, and both of them already had a hook
## in this file: a patch entering the tree, and a patch leaving it. Nothing else
## has to be believed for the list to be right — in particular no other file has
## to remember to tell this one anything.
##
## Freed patches cannot linger. `_exit_tree` fires on `free()`, on an uproot, on a
## plant being eaten and on `reload_current_scene()` (which unparents the whole
## scene before dropping it), so a restart hands the next run an empty list rather
## than a list of dead patches. `live_patches()` prunes invalid entries as it
## reads anyway, so even a patch destroyed by some path that skipped the
## notification cannot come back as a ghost neighbour.
##
## Sorted on insert. Which patch owns a shared lens is decided by `_wash_order`
## and by nothing else, so iteration order cannot change that — but it does decide
## the order `wash_polygons` applies its clips in, and a union assembled in a
## different order from one frame to the next is a union that can flicker.
static var _live: Array[StickySundew] = []

## The pests this particular Sundew currently holds a source on. Not a set of
## every slowed pest on the board — each patch tracks only its own claim, and the
## metadata above is what reconciles overlapping claims.
var _stuck: Array[Pest] = []
## Last bead size actually painted. The patch changes only when a pest enters or
## leaves, so without this a field of Sundews would repaint every frame for a
## picture that did not move.
var _drawn_radius: float = -1.0
## This patch's rank in the paint order above. Stable for the node's whole life.
var _wash_order: int = 0


func _init() -> void:
	_next_wash_order += 1
	_wash_order = _next_wash_order


## A hungry pest can eat the Sundew out from under its own patch. If that left the
## board's pests holding a slow whose source no longer exists, every bug in that
## lane would walk at 55% for the rest of the run with nothing on screen to explain
## it — the worst kind of bug, because it looks like balance.
func _on_setup() -> void:
	destroyed.connect(_on_destroyed)
	# Plant.setup() has already put this node on its cell, so the neighbours it
	# has to divide the wash with are knowable from here.
	rewash_neighbourhood()


func _on_destroyed(_plant: Plant) -> void:
	release_all()
	rewash_neighbourhood()


## Half of the membership bookkeeping for `_live`. Deliberately here rather than
## in `_on_setup`: `setup()` runs once, but the tree can be entered and left more
## than once, and a list maintained on the asymmetric pair would lose a patch for
## good the first time one was re-parented. Plant does not define `_enter_tree`
## today; if it ever does, this override will eat it and will need a
## `super._enter_tree()` — the same trap `_exit_tree` below describes.
##
## Note this lands BEFORE `setup()` has put the node on its cell, so a patch is on
## the list for a moment while still sitting at the origin. Harmless, and the same
## window the sibling scan had: every call site adds the child and calls `setup()`
## in one unbroken call, so no frame — and therefore no `_draw` — can happen in
## between.
func _enter_tree() -> void:
	_register(self)


## Uprooting frees the node, which is the other way a patch can vanish. Plant does
## not define `_exit_tree` today; if it ever does, this override will eat it and
## will need a `super._exit_tree()` — the same trap SelectionMarker's header
## describes for `_draw`.
##
## Deregisters FIRST, so the rewash below tells the patches that are staying to
## repaint without this one counting itself among them.
func _exit_tree() -> void:
	_live.erase(self)
	release_all()
	rewash_neighbourhood()


## Puts `patch` on `_live` in `_wash_order` order. The order is monotonic in
## construction, so this walks nothing at all in the normal case — the insert is
## at the end — and the loop only earns its keep for a patch that left the tree
## and came back.
static func _register(patch: StickySundew) -> void:
	if _live.has(patch):
		return
	var at: int = _live.size()
	while at > 0 and _live[at - 1]._wash_order > patch._wash_order:
		at -= 1
	_live.insert(at, patch)


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


## Pure: what ONE MORE patch would multiply the crossing time of a stretch of
## road by, when `existing_sources` patches already cover that same stretch.
##
## This is plant-tower-defense-3lu written as arithmetic. The first patch is
## worth crossing_time_multiplier() — 1.82x as long under every gun covering that
## road. The second, and the third, and the tenth are worth 1.0: exactly nothing,
## because the slow does not stack. Thirty seeds each for a number that does not
## move.
##
## Stated here rather than left implied, and read by PlacementPreview so the cue
## that warns about the second patch is derived from the balance rule instead of
## being a second copy of it that can quietly drift off it.
static func added_crossing_time_multiplier(existing_sources: int) -> float:
	if existing_sources > 0:
		return 1.0
	return crossing_time_multiplier()


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


## Pure: the patch disc as a polygon, centred on `center` in this patch's own
## space.
##
## Wound the way Geometry2D hands an OUTER boundary back — the winding
## is_polygon_clockwise() calls false — so an unclipped outline and a clipped one
## are the same kind of thing and wash_polygons() can return either without the
## caller having to know which it got. Pinned by a test, because it is a
## convention of the engine's clipper rather than anything visible on screen.
##
## Every disc uses the same segment count and the same phase, so clipping one out
## of another leaves no sliver of double-painted grass along the seam where the
## two rims coincide.
static func patch_outline(center: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in range(WASH_SEGMENTS):
		var angle: float = TAU * float(i) / float(WASH_SEGMENTS)
		out.append(center + Vector2.RIGHT.rotated(angle) * SAP_RADIUS)
	return out


## Pure: what this patch actually fills, given the offsets — relative to its own
## centre — of the overlapping patches that own the ground they share.
##
## No neighbours gets the whole disc back, which is the common case and the one
## PATCH_COLOR's alpha was tuned on. A patch whose ground is entirely claimed
## (a second Sundew dropped on the very same spot) gets nothing at all and paints
## nothing, which is the honest picture of what the second thirty seeds bought.
static func wash_polygons(claimed: PackedVector2Array) -> Array[PackedVector2Array]:
	var parts: Array[PackedVector2Array] = [patch_outline()]
	for offset: Vector2 in claimed:
		# Rims that only touch share no area; clipping on them would return the
		# whole disc back as a slightly different polygon for no reason.
		if offset.length() >= SAP_RADIUS * 2.0:
			continue
		var cutter: PackedVector2Array = patch_outline(offset)
		var kept: Array[PackedVector2Array] = []
		for part: PackedVector2Array in parts:
			for piece: PackedVector2Array in Geometry2D.clip_polygons(part, cutter):
				# Equal-radius discs cannot sit inside one another, so a single
				# clip never punches a hole. Enough of them ringed around this
				# patch can, though, and Geometry2D returns a hole wound the
				# other way — filling one as if it were solid would paint back
				# exactly the ground this whole function exists to leave alone.
				if not Geometry2D.is_polygon_clockwise(piece):
					kept.append(piece)
		parts = kept
	return parts


# ---------------------------------------------------------------------- visuals

## Note there is no super._draw() call here, and there must not be: the selection
## brackets live in a SelectionMarker child precisely because an override like
## this one eats them. See SelectionMarker's header.
func _draw() -> void:
	_draw_wash()
	var radius: float = droplet_radius(stuck_count())
	for bead: Vector2 in droplet_points():
		draw_circle(bead, radius + DROPLET_RIM_WIDTH, DROPLET_RIM_COLOR)
		draw_circle(bead, radius, DROPLET_COLOR)


## This patch's share of the union — see WASH_SEGMENTS for why it is a share
## rather than a disc.
func _draw_wash() -> void:
	var claimed: PackedVector2Array = shared_ground_offsets()
	if claimed.is_empty():
		# Nothing overlaps, so the share IS the disc. Kept as draw_circle rather
		# than a 48-gon so the overwhelmingly common single patch is pixel-for-
		# pixel what it always was.
		draw_circle(Vector2.ZERO, SAP_RADIUS, PATCH_COLOR)
		return
	for part: PackedVector2Array in wash_polygons(claimed):
		if part.size() >= 3:
			draw_colored_polygon(part, PATCH_COLOR)


## Offsets, in this patch's own space, of the overlapping patches that own the
## ground the two share — the ones that got here first. Everything this patch
## outranks paints around it instead, so between any pair the lens is filled
## exactly once.
func shared_ground_offsets() -> PackedVector2Array:
	var out := PackedVector2Array()
	for other: StickySundew in sibling_patches():
		if other._wash_order >= _wash_order:
			continue
		var offset: Vector2 = other.position - position
		if offset.length() >= SAP_RADIUS * 2.0:
			continue
		out.append(offset)
	return out


## Every patch sharing ground with this one repaints when this one arrives or
## leaves. Without that, an uprooted patch leaves an unwashed crescent behind in
## its neighbour — the neighbour is still painting around a disc that is no
## longer there.
func rewash_neighbourhood() -> void:
	queue_redraw()
	for other: StickySundew in sibling_patches():
		if other.position.distance_to(position) < SAP_RADIUS * 2.0:
			other.queue_redraw()


## Every patch on the board right now, oldest first — see `_live` for why this is
## a list rather than a search. Static because the answer is: a caller does not
## need a patch in hand to ask what is planted.
##
## Prunes as it reads. An entry can only be invalid if a patch was destroyed
## without its exit notification running, which nothing does today; the sweep is
## here because the alternative failure — handing a caller a freed node to read
## `position` off — is a crash rather than a wrong picture.
static func live_patches() -> Array[StickySundew]:
	var out: Array[StickySundew] = []
	var stale: bool = false
	for patch: StickySundew in _live:
		if is_instance_valid(patch):
			out.append(patch)
		else:
			stale = true
	if stale:
		_live.assign(out)
	return out


## The other patches this one shares a parent with, oldest first.
##
## Still filtered by parent, which is what the sibling scan gave for free. It
## matters for the test runner more than for the game: a run holds exactly one
## Entities layer, but two hosted scenes alive at once would otherwise let one
## board's patches carve lenses out of the other's.
func sibling_patches() -> Array[StickySundew]:
	var out: Array[StickySundew] = []
	var parent: Node = get_parent()
	if parent == null:
		return out
	for other: StickySundew in live_patches():
		if other != self and other.get_parent() == parent:
			out.append(other)
	return out


func _refresh_droplets() -> void:
	var radius: float = droplet_radius(stuck_count())
	if is_equal_approx(radius, _drawn_radius):
		return
	_drawn_radius = radius
	queue_redraw()
