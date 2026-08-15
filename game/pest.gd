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
		"health": 16.0,
		"speed": 38.0,
		"seeds": 9,
		"chew_seconds": 2.6,
		"scale": 1.0,
		"big": true,
	},
}

var species: StringName = APHID
var health: float = 1.0
var max_health: float = 1.0
var speed: float = 60.0
var seed_value: int = 1
var chew_seconds: float = 0.5
var is_big: bool = false

## Set by a Chomp Flower while it is eating this pest. A held pest does not move.
var held_by: Node = null

var _route: PackedVector2Array = PackedVector2Array()
var _leg: int = 1
var _sprite: Sprite2D
var _health_bar: ColorRect
var _alive: bool = true


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


func _build_visuals(texture_path: String, sprite_scale: float) -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load(texture_path) as Texture2D
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	add_child(_sprite)

	var back := ColorRect.new()
	back.color = Color(0.12, 0.12, 0.12, 0.65)
	back.position = Vector2(-16, -30)
	back.size = Vector2(32, 5)
	add_child(back)

	_health_bar = ColorRect.new()
	_health_bar.color = Color(0.18, 0.80, 0.44)
	_health_bar.position = Vector2(-16, -30)
	_health_bar.size = Vector2(32, 5)
	add_child(_health_bar)


func _physics_process(delta: float) -> void:
	if not _alive or held_by != null:
		return
	_advance(delta * speed)


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
	queue_free()


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
