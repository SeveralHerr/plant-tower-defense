class_name CornCobbler
extends Plant

## The ranged plant. The design doc draws it twice: one cob firing a single
## kernel, and the same cob firing a spray labelled "bunch of corn". That is the
## upgrade ladder, so it is the upgrade ladder here — three levels, each one
## visibly wider than the last.

const RANGE: float = 176.0

## level -> firing pattern. `spread_degrees` is the total arc the kernels cover.
const LEVELS: Array[Dictionary] = [
	{"name": "single", "kernels": 1, "spread_degrees": 0.0, "interval": 0.80, "damage": 1.0, "upgrade_cost": 20},
	{"name": "double", "kernels": 2, "spread_degrees": 14.0, "interval": 0.72, "damage": 1.0, "upgrade_cost": 45},
	{"name": "bunch", "kernels": 5, "spread_degrees": 52.0, "interval": 0.62, "damage": 1.0, "upgrade_cost": 0},
]

var level: int = 1

var _cooldown: float = 0.0


func _act(delta: float, pests: Array[Pest]) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0.0:
		return
	var target: Pest = _furthest_along_in_range(pests, RANGE)
	if target == null:
		return
	_fire_at(target.global_position - global_position)
	_cooldown = float(_stats()["interval"])


func _fire_at(direction: Vector2) -> void:
	var stats: Dictionary = _stats()
	var count: int = int(stats["kernels"])
	var spread: float = deg_to_rad(float(stats["spread_degrees"]))
	var base_angle: float = direction.angle()
	var bounds := Rect2(Vector2.ZERO, Vector2(896, 576))
	if board != null:
		bounds = Rect2(Vector2.ZERO, board.board_size())
	for i: int in range(count):
		var offset: float = 0.0
		if count > 1:
			offset = -spread * 0.5 + spread * (float(i) / float(count - 1))
		var kernel := Kernel.new()
		get_parent().add_child(kernel)
		# `position`, not `global_position`: the kernel is a sibling, so it lives in
		# the same parent space. Entities sit on a layer offset by the top bar, so
		# seeding a sibling from a global coordinate launches every kernel 72 px
		# below the cob — which misses every pest and looks like "the corn is broken".
		kernel.setup(position, Vector2.RIGHT.rotated(base_angle + offset), float(stats["damage"]), bounds)
	_recoil()


## Placement is otherwise blind: the cob reaches RANGE and nothing on screen
## says so. Only drawn while selected so an idle board doesn't fill with rings.
func _draw() -> void:
	if not _selected:
		return
	var fill := Color(0.35, 0.85, 0.45, 0.10)
	var edge := Color(0.35, 0.85, 0.45, 0.55)
	draw_circle(Vector2.ZERO, RANGE, fill)
	draw_arc(Vector2.ZERO, RANGE, 0.0, TAU, 48, edge, 2.0, true)


func _recoil() -> void:
	if _sprite == null or not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2(0.88, 1.14), 0.05)
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.10)


func _stats() -> Dictionary:
	return LEVELS[clampi(level - 1, 0, LEVELS.size() - 1)]


func max_level() -> int:
	return LEVELS.size()


func is_max_level() -> bool:
	return level >= LEVELS.size()


## Seeds to reach the next level, or 0 when there is no next level.
func upgrade_cost() -> int:
	if is_max_level():
		return 0
	return int(LEVELS[level - 1]["upgrade_cost"])


func upgrade() -> bool:
	if is_max_level():
		return false
	level += 1
	return true


func level_name() -> String:
	return String(_stats()["name"])


func kernels_per_shot() -> int:
	return int(_stats()["kernels"])
