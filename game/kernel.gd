class_name Kernel
extends Node2D

## A corn kernel in flight. Straight line, fixed direction, dies on the first pest
## it touches or when it leaves the board.

const SPEED: float = 420.0
const HIT_RADIUS: float = 18.0

var damage: float = 1.0

var _velocity: Vector2 = Vector2.ZERO
var _bounds: Rect2 = Rect2()


func setup(from: Vector2, direction: Vector2, dmg: float, bounds: Rect2) -> void:
	position = from
	damage = dmg
	_bounds = bounds.grow(64.0)
	_velocity = direction.normalized() * SPEED
	rotation = direction.angle() + PI * 0.5
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/sprites/corn_kernel.png") as Texture2D
	add_child(sprite)
	add_to_group("kernels")


func _physics_process(delta: float) -> void:
	position += _velocity * delta
	if not _bounds.has_point(position):
		queue_free()
		return
	for node: Node in get_tree().get_nodes_in_group("pests"):
		var pest := node as Pest
		if pest == null or not pest.is_alive():
			continue
		if pest.global_position.distance_to(global_position) <= HIT_RADIUS:
			pest.take_damage(damage)
			queue_free()
			return
