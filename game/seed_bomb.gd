class_name SeedBomb
extends Node2D

## A dandelion seed in the air. Arcs to a point and detonates there.
##
## The second projectile in the game, and it is deliberately the opposite of the
## first on both axes a projectile has:
##
##   * A `Kernel` travels in a fixed DIRECTION at a fixed SPEED and dies on the
##     first thing it touches. Where it ends up is a consequence of what walked
##     into it. A SeedBomb is fired at a POINT and takes exactly FLIGHT_SECONDS to
##     get there no matter how far that is — it touches nothing on the way and
##     cannot be intercepted. What it hits is decided entirely at the moment it
##     lands.
##   * A `Kernel` hits ONE pest, centre-to-centre, inside HIT_RADIUS (18). A
##     SeedBomb hits EVERY live pest inside BLAST_RADIUS (46), at a damage that
##     slides down to BLAST_EDGE_FRACTION at the rim. This is the only
##     area-of-effect in the catalogue.
##
## Those two together are what make the Dandelion a different plant rather than a
## re-skinned Corn Cobbler, and they are also its whole weakness: the target point
## is where a pest was at LAUNCH, and it walks for FLIGHT_SECONDS before the seed
## arrives. An unslowed aphid covers 78 * 0.55 = 43 px in that time — just inside
## the rim, i.e. the softest part of the blast. A beetle covers 21 and takes it
## nearly full. See Dandelion's header for what that does to the pairings.
##
## THE SIBLING-SPACE TRAP, restated because it is the one that costs an afternoon:
## `setup()` takes coordinates in the PARENT's space, not global ones. Entities
## sits on a layer offset by the top bar, so a bomb seeded from `global_position`
## launches a bar-height below the plant and lands a bar-height below the pest —
## which misses everything and reads as "the dandelion is broken". Kernel.setup()
## carries the same warning; Dandelion._launch_at passes `position` and a
## global-space DELTA, which is the one combination that is right in both spaces.

## Time from leaving the head to landing, regardless of distance. Fixed rather
## than distance/speed on purpose: a constant flight time makes the lead a player
## has to give a constant too, so "the fast one outruns the blast" is a rule they
## can learn instead of a range-dependent surprise.
const FLIGHT_SECONDS: float = 0.55

## How high, in px, the seed's sprite is lifted off its own ground track at the
## apex. The board is top-down, so an arc cannot be a change of position — the
## position IS the ground track, and the arc is the sprite lifting off it while a
## shadow stays behind at ground level. That pairing is the whole illusion: drop
## the shadow and the seed just looks like it drifted up-screen and back.
const ARC_HEIGHT: float = 44.0

## Everything alive inside this takes something. 46 px is ~0.72 of a cell and 2.5x
## a Kernel's HIT_RADIUS: wide enough to catch two pests walking the same stretch
## of road, narrow enough that it never covers a whole lane at once.
const BLAST_RADIUS: float = 46.0

## What a pest sitting exactly on the rim takes, as a fraction of a dead-centre
## hit. Deliberately not zero — a blast whose edge does nothing has an invisible
## boundary the player is judged against, and "it looked like it was in it" is the
## worst complaint a splash weapon can earn. Linear in between; see damage_at().
const BLAST_EDGE_FRACTION: float = 0.4

## How long the burst ring stays on the board after the damage has already been
## dealt. The damage is instantaneous, so this is purely the receipt — but it is
## the only thing that says WHERE the blast was and HOW BIG it was, and without it
## an area weapon is a pest that dies for no visible reason.
const BLAST_LINGER: float = 0.28

## The sprite's scale at the apex, and how far it tumbles over the whole flight.
## Both are cosmetic and both are gated on GardenTheme.animations_enabled().
const SPRITE_APEX_SCALE: float = 1.35
const SPIN_TURNS: float = 0.75

## The ground shadow. Small, soft and always under the seed — it is the only cue
## that says where the thing in the air is actually going to land.
const SHADOW_RADIUS: float = 4.0
const SHADOW_APEX_SHRINK: float = 0.55
## ALPHA RAISED (plant-tower-defense-75os/w86n): pure black clears grass at 0.22
## (0.141 separation) but missed GROUND_DIRT by 0.0025 (0.117 against the floor's
## 0.12) — the seed usually lands over the road, which is the ground this cue most
## needs. The colour is already the darkest it can be, so the only lever is alpha;
## 0.26 clears both (0.167 on grass, 0.139 on dirt). See
## test_every_board_mark_clears_the_ground_floor_at_the_alpha_it_is_drawn_at.
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.26)

## The burst. Cream over a sand rim — the Dandelion's own two hues, so a blast
## reads as that plant's doing rather than as a generic explosion, and it cannot
## be confused with CornCobbler's green range ring, ChompFlower's orange chew ring
## or StickySundew's blue-grey beads.
##
## ALPHA RAISED (plant-tower-defense-75os/w86n): the fill's own header calls this
## "the only thing that says WHERE the blast was and HOW BIG it was", which makes it
## exactly the kind of cue GROUND_SEPARATION_MIN exists for, and nothing had priced
## it. At the original 0.34 alpha it cleared dirt (0.136) but missed grass by 0.021
## (0.099 against 0.12); 0.48 clears both (0.140 on grass, 0.192 on dirt).
const BLAST_FILL := Color(1.0, 0.93, 0.78, 0.48)
## DARKENED (plant-tower-defense-75os/w86n): the rim is meant to carry the reading
## the way `CornCobbler.PIP_RIM_COLOR` carries its pip's, and the original
## `Color(0.65, 0.61, 0.51)` failed BOTH grounds at its own 0.9 alpha (0.028 on grass,
## 0.069 on dirt, against a 0.12 floor) — a rim weaker than the fill it is supposed to
## outline. `.darkened(0.40)`: luminance 0.367, clearing grass by 0.128 and dirt by
## 0.031. See test_every_board_mark_clears_the_ground_floor_at_the_alpha_it_is_drawn_at.
const BLAST_RIM := Color(0.39, 0.37, 0.31, 0.9)
const BLAST_RIM_WIDTH: float = 3.0
const BLAST_SEGMENTS: int = 28

const TEXTURE_PATH := "res://assets/sprites/dandelion_seed.png"

var damage: float = 1.0

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _detonated: bool = false
var _blast_left: float = 0.0
var _sprite: Sprite2D = null


## `from` and `to` are both in the PARENT's space. See the class header.
##
## `bounds` clamps the landing point onto the board. A pest is always on the road
## and the road is always on the board, so this never fires in practice — it is
## here so that a caller which ever computes a target some other way (a lead, a
## predicted position, a devtools verb) cannot detonate off the playfield, where
## the ring would be drawn somewhere the player is not looking.
func setup(from: Vector2, to: Vector2, dmg: float, bounds: Rect2) -> void:
	_from = from
	_to = Vector2(
		clampf(to.x, bounds.position.x, bounds.end.x),
		clampf(to.y, bounds.position.y, bounds.end.y))
	damage = dmg
	position = _from
	_sprite = Sprite2D.new()
	_sprite.texture = load(TEXTURE_PATH) as Texture2D
	add_child(_sprite)
	add_to_group("seed_bombs")
	_refresh_sprite(0.0)


func _physics_process(delta: float) -> void:
	if _detonated:
		_blast_left = maxf(0.0, _blast_left - delta)
		queue_redraw()
		if _blast_left <= 0.0:
			queue_free()
		return
	_elapsed = minf(_elapsed + delta, FLIGHT_SECONDS)
	var t: float = flight_fraction()
	position = _from.lerp(_to, t)
	_refresh_sprite(t)
	queue_redraw()
	if _elapsed >= FLIGHT_SECONDS:
		detonate()


## 0.0 the frame it leaves the head, 1.0 the frame it lands.
func flight_fraction() -> float:
	if FLIGHT_SECONDS <= 0.0:
		return 1.0
	return clampf(_elapsed / FLIGHT_SECONDS, 0.0, 1.0)


func has_detonated() -> bool:
	return _detonated


## Where this bomb is going, in the parent's space — after the clamp, so it is the
## point that will actually be hit rather than the one that was asked for.
func target() -> Vector2:
	return _to


## How far the sprite is currently lifted off its own ground track, in px. 0.0
## with animations off, which is exactly the "no arc, still lands" degradation the
## rest of the game's cosmetic layer uses.
func sprite_lift() -> float:
	if _sprite == null or not GardenTheme.animations_enabled():
		return 0.0
	return -_sprite.position.y


## Pure: the height of the arc at `t` of the flight. A parabola through 0 at both
## ends and ARC_HEIGHT at the middle, so the seed leaves the head at ground level
## and arrives at ground level — anything else and the shadow and the sprite would
## not meet on the frame the blast is drawn.
static func lift_at(t: float) -> float:
	var u: float = clampf(t, 0.0, 1.0)
	return ARC_HEIGHT * 4.0 * u * (1.0 - u)


## Pure: the fraction of full damage something `distance` px from the centre of a
## blast takes. 1.0 at the centre, BLAST_EDGE_FRACTION at the rim, 0.0 outside.
##
## Split out and pure because it is the entire balance of an area weapon and it is
## not observable any other way: the pest that took a rim hit and the pest that
## took a centre hit look identical afterwards.
static func damage_falloff(distance: float) -> float:
	if distance > BLAST_RADIUS:
		return 0.0
	return lerpf(1.0, BLAST_EDGE_FRACTION, clampf(distance / BLAST_RADIUS, 0.0, 1.0))


static func damage_at(distance: float, full: float) -> float:
	return full * damage_falloff(distance)


## Pure: how many of `positions` a blast centred on `centre` would catch. The
## whole of the targeting question for an area weapon, answered without a tree —
## Dandelion.best_target() aims with it and a test can sweep it.
static func caught(centre: Vector2, positions: PackedVector2Array) -> int:
	var n: int = 0
	for at: Vector2 in positions:
		if centre.distance_to(at) <= BLAST_RADIUS:
			n += 1
	return n


## The landing. Public because it is the event, not an implementation step: a
## devtools verb or a test wanting the blast without waiting out the flight calls
## this rather than stepping physics 33 times.
##
## Damage first, then the ring. A pest killed here emits `died` synchronously
## (Pest.kill), which Game listens to — so the seeds and the husk land in the same
## frame as the burst, the same as a Kernel's kill does.
func detonate() -> void:
	if _detonated:
		return
	_detonated = true
	_blast_left = BLAST_LINGER
	_elapsed = FLIGHT_SECONDS
	position = _to
	if _sprite != null:
		_sprite.visible = false
	Sfx.play(Sfx.SEED_BOMB_BURST)
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group("pests"):
			var pest := node as Pest
			if pest == null or not pest.is_alive():
				continue
			var dealt: float = damage_at(pest.global_position.distance_to(global_position), damage)
			if dealt <= 0.0:
				continue
			# Blasted: a corpse this kills lies tilted off its facing, because a bomb
			# throws the body off the line it was walking (plant-tower-defense-f5z6).
			# The blast's own centre, not the pest's: `damage_at` has already scaled the
			# damage by how far this pest sat from it, and on the Cutworm the same point
			# decides WHICH PART of it the blast caught. A seed landing on the band is
			# worth two and a half times one landing on the trunk beside it.
			pest.take_damage(dealt, Pest.DEATH_BLASTED, Vector2.ZERO, global_position)
			# Same split Kernel documents: a kill already has the corpse swap and
			# Sfx.PEST_KILLED, so the flash is only for the ones that survived —
			# and on a blast that is most of them, which is exactly when "did that
			# even touch it" needs answering.
			if pest.is_alive():
				pest.flash_hit()
	queue_redraw()


## Pure: how far through its linger a burst `left` seconds from gone is. 0.0 the
## instant it detonates, 1.0 as it disappears.
static func burst_progress(left: float) -> float:
	if BLAST_LINGER <= 0.0:
		return 1.0
	return clampf(1.0 - left / BLAST_LINGER, 0.0, 1.0)


## Pure: the ring's radius partway through the burst. It grows from a point out to
## BLAST_RADIUS, so what the player sees expanding is the actual area that was
## already damaged rather than a decorative flash of some other size.
static func burst_radius(progress: float) -> float:
	return BLAST_RADIUS * clampf(progress, 0.0, 1.0)


func _refresh_sprite(t: float) -> void:
	if _sprite == null:
		return
	if not GardenTheme.animations_enabled():
		_sprite.position = Vector2.ZERO
		return
	_sprite.position = Vector2(0.0, -lift_at(t))
	var swell: float = lerpf(1.0, SPRITE_APEX_SCALE, lift_at(t) / maxf(ARC_HEIGHT, 0.001))
	_sprite.scale = Vector2(swell, swell)
	_sprite.rotation = TAU * SPIN_TURNS * clampf(t, 0.0, 1.0)


## In flight: the ground shadow, which is where the arc's illusion actually lives.
## After the landing: the burst ring.
##
## Both are drawn on this node's own canvas item, so they sit BEHIND the sprite
## child — which is what a shadow has to do, and which lets the ring paint under
## the pests it just hit rather than over their health bars.
func _draw() -> void:
	if _detonated:
		var progress: float = burst_progress(_blast_left)
		var radius: float = burst_radius(progress)
		var fade: float = 1.0 - progress
		draw_circle(Vector2.ZERO, radius, Color(BLAST_FILL, BLAST_FILL.a * fade))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, BLAST_SEGMENTS,
			Color(BLAST_RIM, BLAST_RIM.a * fade), BLAST_RIM_WIDTH, true)
		return
	if not GardenTheme.animations_enabled():
		return
	# The shadow shrinks as the seed climbs, which is the second half of the
	# height cue: a shadow the same size throughout reads as a seed sliding along
	# the ground rather than one going over something.
	var height: float = lift_at(flight_fraction()) / maxf(ARC_HEIGHT, 0.001)
	draw_circle(Vector2.ZERO, SHADOW_RADIUS * lerpf(1.0, SHADOW_APEX_SHRINK, height), SHADOW_COLOR)
