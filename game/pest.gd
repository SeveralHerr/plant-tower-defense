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


## Applies one wave-8+ trait. Called by whoever spawns this pest, after setup()
## so the sprite already exists to tint. A no-op for &"" (the common case).
func apply_mutation(which: StringName) -> void:
	mutation = which
	match which:
		MUTATION_ARMOURED:
			is_armoured = true
			# The doc's "armoured" — a Chomp's mouth is tied up twice as long.
			chew_seconds *= 2.0
			_tint(Color(0.58, 0.66, 0.78))
		MUTATION_WINGED:
			is_winged = true
			_tint(Color(0.82, 0.94, 1.0, 0.88))
		MUTATION_HUNGRY:
			is_hungry = true
			_tint(Color(1.0, 0.52, 0.5))


func _tint(colour: Color) -> void:
	if _sprite != null:
		_sprite.modulate = colour


func _build_visuals(texture_path: String, sprite_scale: float) -> void:
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
	_health_bar.color = Color(0.18, 0.80, 0.44)
	_health_bar.position = Vector2(-16, -30)
	_health_bar.size = Vector2(32, 5)
	add_child(_health_bar)


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
