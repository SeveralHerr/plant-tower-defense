class_name Pest
extends Node2D

## A bug walking the road. Two species, per the drawings: a small fast one
## (aphid) and a big slow one (beetle).
##
## The interesting state here is `held_by`. A Chomp Flower that grabs a pest does
## not delete it — it holds it in place for `chew_seconds` while the pest stays on
## the board blocking nothing and taking no ground. That is what makes the Chomp a
## body blocker rather than a damage source, which is the whole plant/pest balance.

signal died(pest: Pest)
signal escaped(pest: Pest)

const APHID := &"aphid"
const BEETLE := &"beetle"

## species -> stats. `chew_seconds` is the design doc's "eats small pests easily,
## takes a while eating bigger pests" expressed as a number.
const SPECIES: Dictionary = {
	APHID: {
		"display": "Aphid",
		"texture": "res://assets/sprites/pest_aphid.png",
		"dead_texture": "res://assets/sprites/pest_aphid_dead.png",
		"health": 3.0,
		"speed": 78.0,
		"seeds": 3,
		"chew_seconds": 0.45,
		"scale": 0.72,
		"big": false,
	},
	BEETLE: {
		"display": "Beetle",
		"texture": "res://assets/sprites/pest_beetle.png",
		"dead_texture": "res://assets/sprites/pest_beetle_dead.png",
		"health": 16.0,
		"speed": 38.0,
		"seeds": 9,
		"chew_seconds": 2.6,
		"scale": 1.0,
		"big": true,
	},
}

## From wave 8 (WaveDirector.MUTATION_START_WAVE) a spawned pest may carry one of
## these. Each is a single trait, not a new species — the wave table stays the
## same shape, a run just stops being identical every time.
const MUTATION_ARMOURED := &"armoured"
const MUTATION_WINGED := &"winged"
const MUTATION_HUNGRY := &"hungry"

## A mutated pest costs the player more to deal with than a plain one — the
## husk it leaves should too, or the mutation and compost systems sit side by
## side without ever touching. Armoured/winged both cost extra effort to kill
## (double chew time; unreachable by a Chomp at all); hungry costs the most,
## since a plant it reaches is destroyed outright rather than merely delayed.
const MUTATION_HUSK_MULTIPLIER: Dictionary = {
	MUTATION_ARMOURED: 1.5,
	MUTATION_WINGED: 1.5,
	MUTATION_HUNGRY: 2.0,
}

## Each mutation's hue. Still applied as a sprite tint — but hue is the one
## channel that survives neither colour blindness nor a greyscale screenshot,
## and two of these three change what the player must do (winged is unreachable
## by a Chomp at all; hungry destroys a bed in MAX_HEALTH / EAT_DPS seconds).
## So every entry here is paired with a drawn silhouette marker below, and the
## marker — not the colour — is what carries the meaning.
const MUTATION_TINT: Dictionary = {
	MUTATION_ARMOURED: Color(0.58, 0.66, 0.78),
	MUTATION_WINGED: Color(0.82, 0.94, 1.0, 0.88),
	MUTATION_HUNGRY: Color(1.0, 0.52, 0.5),
}

## The non-colour half of a mutation's read: a shape at the silhouette edge.
## Named ids rather than raw draw calls so markers_for() is a pure, assertable
## function and the geometry below is only ever the rendering of its answer.
const MARKER_PLATES := &"plates"
const MARKER_WINGS := &"wings"
const MARKER_JAWS := &"jaws"

## Which mutation's hue each marker borrows. Markers never invent a colour —
## they take STYLE.md's three-value rule (dark rim / base / light facet) and
## apply it to the tint that is already in MUTATION_TINT.
const MARKER_SOURCE: Dictionary = {
	MARKER_PLATES: MUTATION_ARMOURED,
	MARKER_WINGS: MUTATION_WINGED,
	MARKER_JAWS: MUTATION_HUNGRY,
}

const MARKER_LIGHTEN: float = 0.42
const MARKER_DARKEN: float = 0.52
const MARKER_ALPHA: float = 0.95
const MARKER_LINE: float = 2.0

## Half of the 64 px sprite canvas STYLE.md mandates. Every marker below is
## placed in fractions of this times the species' own sprite scale, so an
## aphid's marks hug its silhouette exactly as tightly as a beetle's hug its.
const SPRITE_HALF: float = 32.0

## Armour: two concentric arcs hugging the sides and underside — an outline
## thickening, per the doc's "plate". The arc deliberately stops short of the
## top (-15 deg round to 195 deg) because the health bar lives up there.
const PLATE_OUTER: float = 1.06
const PLATE_INNER: float = 0.92
const PLATE_FROM: float = -PI / 12.0
const PLATE_TO: float = PI * 13.0 / 12.0
const PLATE_SEGMENTS: int = 22
const PLATE_WIDTH: float = 3.0
const PLATE_SEAM_WIDTH: float = 2.0

## Winged: a swept wing either side, rooted at the body and reaching past the
## silhouette. Drawn on the parent's canvas item, i.e. BEHIND the sprite child,
## which is why every point sits outside the sprite's own art rather than on it.
const WING_ROOT_IN := Vector2(0.40, -0.22)
const WING_TIP := Vector2(1.10, -0.92)
const WING_TIP_OUT := Vector2(1.06, -0.34)
const WING_ROOT_OUT := Vector2(0.52, 0.02)

## Hungry: a row of teeth along the lower edge, the same tooth language the
## Chomp Flower's maw uses — on the bug this time, which is the point.
const JAW_TEETH: int = 3
const JAW_TOP: float = 0.78
const JAW_TIP: float = 1.14
const JAW_HALF_WIDTH: float = 0.19
const JAW_SPACING: float = 0.40

## How close a hungry pest has to be to a plant to start eating it. Same
## reasoning as ChompFlower.GRAB_RADIUS: a pest walks the road, a plant stands
## one cell off it, so anything under one cell can never reach either.
const EAT_RADIUS: float = Board.CELL * 1.15
const EAT_DPS: float = 14.0

## How long a killed pest's corpse (dead-eyes sprite) stays on screen before it
## is actually freed. Long enough to read as a beat, short enough not to pile up.
const DEATH_LINGER: float = 0.35

var species: StringName = APHID
var health: float = 1.0
var max_health: float = 1.0
var speed: float = 60.0
var seed_value: int = 1
var chew_seconds: float = 0.5
var is_big: bool = false

## Set by a Chomp Flower while it is eating this pest. A held pest does not move.
var held_by: Node = null

var mutation: StringName = &""
var is_armoured: bool = false
var is_winged: bool = false
var is_hungry: bool = false

var _route: PackedVector2Array = PackedVector2Array()
var _leg: int = 1
var _sprite: Sprite2D
var _health_bar: ColorRect
var _health_back: ColorRect
var _alive: bool = true
var _dead_texture: Texture2D = null
var _sprite_scale: float = 1.0


func setup(which: StringName, route: PackedVector2Array) -> void:
	species = which
	var stats: Dictionary = SPECIES[which]
	max_health = float(stats["health"])
	health = max_health
	speed = float(stats["speed"])
	seed_value = int(stats["seeds"])
	chew_seconds = float(stats["chew_seconds"])
	is_big = bool(stats["big"])
	_route = route
	_leg = 1
	if not _route.is_empty():
		position = _route[0]
	add_to_group("pests")
	_build_visuals(String(stats["texture"]), float(stats["scale"]))
	var dead_path: String = String(stats.get("dead_texture", ""))
	if dead_path != "":
		_dead_texture = load(dead_path) as Texture2D


## Endless mode's per-wave difficulty multipliers, from
## WaveDirector.health_scale_for / speed_scale_for. Called after setup(), which
## is what seeded the species defaults these scale.
##
## `health` moves with `max_health` rather than being left at the species value,
## so a scaled pest still spawns with a full bar — a beetle arriving at 16/48
## would read as pre-damaged and the bar would barely move for its first three
## hits. Mutations do not touch health or speed, so this composes with
## apply_mutation() in either order.
func apply_wave_scaling(health_multiplier: float, speed_multiplier: float) -> void:
	max_health *= health_multiplier
	health = max_health
	speed *= speed_multiplier


## Applies one wave-8+ trait. Called by whoever spawns this pest, after setup()
## so the sprite already exists to tint. A no-op for &"" (the common case).
##
## Setting the flag is what matters: markers() reads the flags, not `mutation`,
## so calling this twice leaves a pest wearing both marks rather than only the
## last one's. Nothing in the game does that today, but a Chomp already reads
## `is_winged` directly, and a cue that disagreed with the rule it advertises
## would be worse than no cue at all.
func apply_mutation(which: StringName) -> void:
	mutation = which
	match which:
		MUTATION_ARMOURED:
			is_armoured = true
			# The doc's "armoured" — a Chomp's mouth is tied up twice as long.
			chew_seconds *= 2.0
		MUTATION_WINGED:
			is_winged = true
		MUTATION_HUNGRY:
			is_hungry = true
	_tint(tint_for(which))
	queue_redraw()


## The hue for a mutation; white (i.e. untinted) for &"" and anything unknown.
static func tint_for(which: StringName) -> Color:
	if not MUTATION_TINT.has(which):
		return Color.WHITE
	var colour: Color = MUTATION_TINT[which]
	return colour


func _tint(colour: Color) -> void:
	if _sprite != null:
		_sprite.modulate = colour


## Which silhouette marks this pest wears. Pure and flag-driven, so a pest
## carrying two traits reports both, a plain pest reports none, and a test can
## ask the question without a viewport, a frame, or a pixel.
func markers() -> Array[StringName]:
	return markers_for(is_armoured, is_winged, is_hungry)


## Draw order: plates first so they sit under wings and jaws — a plated bug
## that also flies should read as "plated, and also winged", not as a shell
## with something scribbled over it.
static func markers_for(armoured: bool, winged: bool, hungry: bool) -> Array[StringName]:
	var out: Array[StringName] = []
	if armoured:
		out.append(MARKER_PLATES)
	if winged:
		out.append(MARKER_WINGS)
	if hungry:
		out.append(MARKER_JAWS)
	return out


func _build_visuals(texture_path: String, sprite_scale: float) -> void:
	_sprite_scale = sprite_scale
	_sprite = Sprite2D.new()
	_sprite.texture = load(texture_path) as Texture2D
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	add_child(_sprite)

	_health_back = ColorRect.new()
	_health_back.color = Color(0.12, 0.12, 0.12, 0.65)
	_health_back.position = Vector2(-16, -30)
	_health_back.size = Vector2(32, 5)
	add_child(_health_back)

	_health_bar = ColorRect.new()
	_health_bar.color = GardenTheme.LEAF
	_health_bar.position = Vector2(-16, -30)
	_health_bar.size = Vector2(32, 5)
	add_child(_health_bar)


## The mutation cues. Drawn here rather than in a child node because Pest has no
## subclasses — the trap SelectionMarker exists to dodge (CornCobbler and
## ChompFlower each fully override Plant._draw() and never chain to super) has no
## instance on this side of the board. If a Pest subclass ever appears, the fix
## is `super._draw()` in it, and the per-marker methods below are already split
## out so it can reuse them piecemeal.
##
## Note that a Node2D paints its own canvas item BEFORE its children, so every
## shape here lands *behind* the sprite. That is why the geometry sits at and
## past the silhouette edge: a marker drawn over the body would simply not exist.
func _draw() -> void:
	if not _alive:
		return
	var r: float = SPRITE_HALF * _sprite_scale
	for marker: StringName in markers():
		match marker:
			MARKER_PLATES:
				_draw_plates(r)
			MARKER_WINGS:
				_draw_wings(r)
			MARKER_JAWS:
				_draw_jaws(r)


func _draw_plates(r: float) -> void:
	draw_arc(Vector2.ZERO, r * PLATE_OUTER, PLATE_FROM, PLATE_TO, PLATE_SEGMENTS,
		marker_ink(MARKER_PLATES), PLATE_WIDTH, true)
	draw_arc(Vector2.ZERO, r * PLATE_INNER, PLATE_FROM, PLATE_TO, PLATE_SEGMENTS,
		marker_fill(MARKER_PLATES), PLATE_SEAM_WIDTH, true)


func _draw_wings(r: float) -> void:
	for sx: float in [-1.0, 1.0]:
		var mirror := Vector2(sx, 1.0)
		_draw_marker_shape(PackedVector2Array([
			WING_ROOT_IN * mirror * r,
			WING_TIP * mirror * r,
			WING_TIP_OUT * mirror * r,
			WING_ROOT_OUT * mirror * r,
		]), MARKER_WINGS)


func _draw_jaws(r: float) -> void:
	var middle: float = float(JAW_TEETH - 1) * 0.5
	for i: int in range(JAW_TEETH):
		var cx: float = (float(i) - middle) * JAW_SPACING * r
		_draw_marker_shape(PackedVector2Array([
			Vector2(cx - JAW_HALF_WIDTH * r, JAW_TOP * r),
			Vector2(cx + JAW_HALF_WIDTH * r, JAW_TOP * r),
			Vector2(cx, JAW_TIP * r),
		]), MARKER_JAWS)


## Filled light shape with a darker rim of its own hue — STYLE.md's rule, so a
## drawn marker sits in the same visual language as the authored sprites.
func _draw_marker_shape(points: PackedVector2Array, marker: StringName) -> void:
	draw_colored_polygon(points, marker_fill(marker))
	var rim: PackedVector2Array = points.duplicate()
	rim.append(points[0])
	draw_polyline(rim, marker_ink(marker), MARKER_LINE, true)


static func marker_fill(marker: StringName) -> Color:
	var colour: Color = tint_for(_marker_source(marker)).lightened(MARKER_LIGHTEN)
	colour.a = MARKER_ALPHA
	return colour


static func marker_ink(marker: StringName) -> Color:
	var colour: Color = tint_for(_marker_source(marker)).darkened(MARKER_DARKEN)
	colour.a = MARKER_ALPHA
	return colour


static func _marker_source(marker: StringName) -> StringName:
	if not MARKER_SOURCE.has(marker):
		return &""
	var source: StringName = MARKER_SOURCE[marker]
	return source


func _physics_process(delta: float) -> void:
	if not _alive or held_by != null:
		return
	if is_hungry:
		var meal: Plant = _adjacent_plant()
		if meal != null:
			meal.take_damage(EAT_DPS * delta)
			return
	_advance(delta * speed)


## The doc's "hungry" trait: eats the plant instead of walking past. Only ever
## looks at the lane it is currently beside — same one-cell reach as a Chomp's
## grab, so a hungry pest cannot reach across the road to a different lane.
func _adjacent_plant() -> Plant:
	var best: Plant = null
	var best_distance: float = EAT_RADIUS
	for node: Node in get_tree().get_nodes_in_group("plants"):
		var plant := node as Plant
		if plant == null or plant.is_destroyed():
			continue
		var d: float = plant.global_position.distance_to(global_position)
		if d <= best_distance:
			best_distance = d
			best = plant
	return best


## Walk `distance` px along the remaining route, spending it across legs so a fast
## pest cannot skip a corner at low frame rates.
func _advance(distance: float) -> void:
	while distance > 0.0:
		if _leg >= _route.size():
			_escape()
			return
		var target: Vector2 = _route[_leg]
		var to_target: Vector2 = target - position
		var gap: float = to_target.length()
		if gap <= distance:
			position = target
			distance -= gap
			_leg += 1
		else:
			position += to_target / gap * distance
			distance = 0.0


func take_damage(amount: float) -> void:
	if not _alive:
		return
	health = maxf(0.0, health - amount)
	if is_instance_valid(_health_bar):
		_health_bar.size = Vector2(32.0 * (health / max_health), 5)
	if health <= 0.0:
		kill()


## Death by any cause — kernels, or a Chomp finishing its meal.
func kill() -> void:
	if not _alive:
		return
	_alive = false
	if held_by != null and held_by.has_method("release"):
		held_by.call("release")
	died.emit(self)
	_play_death()


## Swaps in the doc's "X-eyed pest" corpse sprite and lingers a beat before
## freeing, rather than the pest just vanishing — a separate sprite, not a tint,
## per the sprite-pass-2 ask. Deferred so a listener of `died` (Game awards
## seeds and drops a compost husk) still sees a valid global_position.
func _play_death() -> void:
	set_physics_process(false)
	if _health_back != null:
		_health_back.visible = false
	if _health_bar != null:
		_health_bar.visible = false
	if _dead_texture != null and _sprite != null:
		_sprite.texture = _dead_texture
		_sprite.modulate = Color.WHITE
	# The corpse drops the tint, so it drops the markers with it — a dead pest
	# still wearing wings would read as a threat the player still has to answer.
	queue_redraw()
	if not is_inside_tree():
		queue_free()
		return
	# Bound to self: Godot kills a node's own tweens when the node frees, so a
	# teardown that frees the tree immediately (free_ui, not queue_free) never
	# fires this callback on a dangling instance.
	var tween := create_tween()
	tween.tween_interval(DEATH_LINGER)
	tween.tween_callback(queue_free)


func is_alive() -> bool:
	return _alive


## 1.0 for a plain pest; higher for a mutation, so a harder kill leaves a
## better husk. Game._on_pest_died reads this when it drops one.
func husk_multiplier() -> float:
	return float(MUTATION_HUSK_MULTIPLIER.get(mutation, 1.0))


func _escape() -> void:
	if not _alive:
		return
	_alive = false
	escaped.emit(self)
	queue_free()


## 0.0 at the entrance, 1.0 at the exit. Targeting uses this to shoot whichever
## pest is furthest along rather than whichever happens to be nearest.
func progress() -> float:
	if _route.size() < 2:
		return 0.0
	return clampf(float(_leg) / float(_route.size() - 1), 0.0, 1.0)
