class_name Kernel
extends Node2D

## A corn kernel in flight. Straight line, fixed direction, dies on the first pest
## it touches or when it leaves the board.

const SPEED: float = 420.0
const HIT_RADIUS: float = 18.0

var damage: float = 1.0


## True when a kernel launched `angle_offset` radians off the aim line still passes
## within HIT_RADIUS of a pest sitting `distance` px straight down that line.
##
## Worth stating plainly because it is the entire physics of a spread weapon here
## and it is not obvious from the loop below: the closest a straight-line kernel
## ever gets to that pest is `distance * sin(angle_offset)`, so an off-axis kernel
## has a hard maximum range that has nothing to do with CornCobbler.RANGE. A pest's
## own size is not consulted anywhere — a beetle draws 64 px of sprite, but the hit
## test is centre-to-centre against HIT_RADIUS and nothing else, so widening a
## spread costs real damage rather than merely spreading it around.
##
## This is the continuous form; `_physics_process` samples every SPEED * delta px
## (7.0 px at 60 Hz), which can drop a grazing pass whose closest approach falls
## between two samples — but only for the outermost 0.34 px of the radius. Nothing
## in CornCobbler.LEVELS lands inside that margin, and a pattern that did would be a
## knife edge worth failing rather than shipping.
static func connects(distance: float, angle_offset: float) -> bool:
	return distance * absf(sin(angle_offset)) <= HIT_RADIUS


## The furthest a pest can be down the aim line and still be caught by a kernel
## fired `angle_offset` off it; INF for the kernel travelling along the line itself.
## At CornCobbler's 13 degree step that is 80 px for the first pair and 41 px for
## the second — both well inside its 176 px ring, which is why a wide volley is a
## crowd tool and not extra single-target damage.
static func reach_at_offset(angle_offset: float) -> float:
	var lateral: float = absf(sin(angle_offset))
	if lateral <= 0.0:
		return INF
	return HIT_RADIUS / lateral

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
			# The third argument is the corpse's shove, and this is the only place in
			# the game that has the direction to give one: a kernel arrives along a
			# line, and `to - from` off the two positions IS that line at the moment of
			# impact (plant-tower-defense-6v39). Composed here, at the call site, the
			# same way ChompFlower._bite() composes its lunge — the pure static holds
			# the arithmetic and the caller holds the two points.
			#
			# Costs nothing on a hit the pest survives: `take_damage` only carries it
			# into `kill()`, and never remembers it.
			# The kernel's own position is where the hit landed, which for every pest but
			# the Cutworm is the same thing as "on that pest" and is ignored. On a 953 px
			# body it decides whether this was the maw, the hide or the soft band — see
			# `Cutworm.zone_multiplier`.
			pest.take_damage(damage, &"", Pest.knockback_offset(global_position, pest.global_position),
				global_position)
			# A hit that didn't kill gets its own cue; a hit that did already has
			# one — the corpse swap, fade and Sfx.PEST_KILLED in Pest._play_death
			# (plant-tower-defense-7o3). Without this split, "connected but the
			# pest lived" looked exactly like the kernel simply missing.
			if pest.is_alive():
				pest.flash_hit()
			queue_free()
			return
