class_name CornCobbler
extends Plant

## The ranged plant. The design doc draws it twice: one cob firing a single
## kernel, and the same cob firing a spray labelled "bunch of corn". That is the
## upgrade ladder, so it is the upgrade ladder here — three levels, each one
## visibly wider than the last.

const RANGE: float = 176.0

## The angle between one kernel and the next, the same at every level. This is the
## constant the whole upgrade ladder is built on, and it is what keeps an upgrade
## from being a downgrade.
##
## A spread is only free if the kernels you already had stay where they were. When
## the ladder was 1 -> 2 -> 5 kernels over 0 -> 14 -> 52 degrees, each level
## re-spaced its kernels from scratch, so paying for one MOVED the shots you had
## rather than adding to them. Both of the resulting holes were real:
##
##   * Level 2's two kernels sat at +/-7 deg with nothing on the aim line. A kernel
##     fired `t` off the line passes a pest on the line at Kernel.HIT_RADIUS / sin t,
##     so +/-7 deg stopped connecting at 148 px — inside RANGE (176). Between 148 px
##     and the edge of its own ring, the 20-seed level did *zero* damage to the pest
##     it was aiming at, where level 1 did 1.25 dps.
##   * Level 3 re-spaced to +/-26, +/-13, 0. The outer pair stops connecting at 41 px
##     and the inner pair at 80 px, so past 80 px only the middle kernel ever landed:
##     1.61 dps against the 2.78 dps the *cheaper* level 2 was doing. The most
##     expensive upgrade in the game made the cob worse at the thing it aimed at.
##
## Fixed step + odd counts fixes both by construction. Every level fires through
## KERNEL_STEP_DEGREES * (kernels - 1) degrees, kernels are always odd, and each
## level adds one pair to the outside of the level below. So level N's firing angles
## are a strict superset of level N-1's, every level keeps a kernel on the aim line,
## and the interval only ever shortens and the damage only ever rises. Together those
## mean level N hits at least everything level N-1 would have hit, at least as hard,
## at least as often — at every range, against any arrangement of pests. There is no
## configuration left in which upgrading can lose.
##
## Off-axis kernels are still situational (see `reach_at_offset`): past 80 px the
## bunch is one kernel plus four warning shots. `damage` is what the player is
## actually buying at long range, and it is why it climbs with the level rather than
## sitting flat at 1.0 the way it used to.
const KERNEL_STEP_DEGREES: float = 13.0

## level -> firing pattern. `spread_degrees` is the total arc the kernels cover, and
## it is always KERNEL_STEP_DEGREES * (kernels - 1) — `test_combat` pins that, so a
## hand-typed spread that breaks the nesting fails rather than shipping.
const LEVELS: Array[Dictionary] = [
	{"name": "single", "kernels": 1, "spread_degrees": 0.0, "interval": 0.80, "damage": 1.0, "upgrade_cost": 20},
	{"name": "triple", "kernels": 3, "spread_degrees": 26.0, "interval": 0.72, "damage": 1.2, "upgrade_cost": 45},
	{"name": "bunch", "kernels": 5, "spread_degrees": 52.0, "interval": 0.62, "damage": 1.4, "upgrade_cost": 0},
]

## Muzzle fan geometry. The upgrade ladder used to be invisible on the board —
## paying 45 seeds changed a line in the selection panel and nothing else — so
## every cob now wears the shot it actually fires: one pip per kernel, laid out on
## the angles `kernel_angle_offsets` hands to `_fire_at`, with a thin arc spanning
## the outer two. Drawing and firing read the same function, so the picture cannot
## drift away from the behaviour the way a hand-drawn "level 3 is bushier" badge
## would — retune LEVELS and the board retunes with it.
##
## The fan is projected from a pivot FAN_PIVOT behind the cob rather than measured
## from the cob's centre. That magnifies the angles about a common origin: a single
## KERNEL_STEP_DEGREES step is a 7.7 px gap between neighbouring pips this way and
## barely 3 px measured from the cob's centre — pips fused into one blob, i.e.
## exactly the "looks the same as level 1" bug this is fixing. The
## projection is monotonic and shares its input with the shot, so wider spread is
## always a wider fan and level 1's zero spread is still a single pip; it makes a
## true difference visible rather than inventing one.
##
## FAN_LENGTH - FAN_PIVOT puts the centre pip at 20 px, out on the sprite's
## shoulder, and the whole fan inside a radius of ~26 — clear of the 32 px cell
## edge, and a directional spray of filled dots on one side rather than anything
## ring-shaped, so it reads as neither the RANGE ring (green, 176 px, selected
## only) nor SelectionMarker's four thin corner brackets.
const FAN_PIVOT: float = 14.0
const FAN_LENGTH: float = 34.0
const PIP_SIZE: float = 2.4
const PIP_RIM_WIDTH: float = 1.2
## Corn gold over a dark rim: a bare yellow dot this small dissolves into both a
## grass tile and the cob's own sprite, and the rim is what keeps it legible.
const PIP_COLOR := Color(1.0, 0.78, 0.20, 0.95)
const PIP_RIM_COLOR := Color(0.24, 0.16, 0.04, 0.9)
const SPREAD_ARC_COLOR := Color(1.0, 0.78, 0.20, 0.45)

var level: int = 1

var _cooldown: float = 0.0
## Where the fan points. Updated on every shot, so an upgraded cob visibly
## sweeps its wider spray across whatever it last shot at.
var _aim_angle: float = 0.0


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
	var base_angle: float = direction.angle()
	_aim_angle = base_angle
	queue_redraw()
	var bounds := Rect2(Vector2.ZERO, Vector2(896, 576))
	if board != null:
		bounds = Rect2(Vector2.ZERO, board.board_size())
	for offset: float in kernel_angle_offsets(level):
		var kernel := Kernel.new()
		get_parent().add_child(kernel)
		# `position`, not `global_position`: the kernel is a sibling, so it lives in
		# the same parent space. Entities sit on a layer offset by the top bar, so
		# seeding a sibling from a global coordinate launches every kernel 72 px
		# below the cob — which misses every pest and looks like "the corn is broken".
		kernel.setup(position, Vector2.RIGHT.rotated(base_angle + offset), float(stats["damage"]), bounds)
	_recoil()


## The range ring is placement feedback and only appears while selected, so an
## idle board doesn't fill with rings. The muzzle fan is always on: it is the
## board-level readout of what an upgrade bought, and it is worthless if you have
## to click the plant to see it — that was the whole complaint.
##
## Note there is still no super._draw() call here, and there must not be: the
## selection brackets live in a SelectionMarker child precisely because this
## override eats them. See SelectionMarker's header.
func _draw() -> void:
	if _selected:
		var fill := Color(0.35, 0.85, 0.45, 0.10)
		var edge := Color(0.35, 0.85, 0.45, 0.55)
		draw_circle(Vector2.ZERO, RANGE, fill)
		draw_arc(Vector2.ZERO, RANGE, 0.0, TAU, 48, edge, 2.0, true)
	_draw_muzzle_fan()


func _draw_muzzle_fan() -> void:
	var offsets: PackedFloat32Array = kernel_angle_offsets(level)
	if offsets.is_empty():
		return
	# Level 1 fires one kernel through a 0° spread, so there is no arc to draw —
	# a lone pip is the honest picture of a single shot.
	if offsets.size() > 1:
		draw_arc(muzzle_pivot(_aim_angle), FAN_LENGTH, _aim_angle + offsets[0],
			_aim_angle + offsets[offsets.size() - 1], 24, SPREAD_ARC_COLOR, 2.0, true)
	for pip: Vector2 in muzzle_pips(level, _aim_angle):
		draw_circle(pip, PIP_SIZE + PIP_RIM_WIDTH, PIP_RIM_COLOR)
		draw_circle(pip, PIP_SIZE, PIP_COLOR)


func _recoil() -> void:
	if _sprite == null or not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2(0.88, 1.14), 0.05)
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.10)


static func _level_stats(for_level: int) -> Dictionary:
	return LEVELS[clampi(for_level - 1, 0, LEVELS.size() - 1)]


func _stats() -> Dictionary:
	return _level_stats(level)


## The angle offsets, in radians and in launch order, that a shot at `for_level`
## puts its kernels on — one entry per kernel, symmetric about the aim direction
## and spanning exactly that level's `spread_degrees`.
##
## Both `_fire_at` and `_draw_muzzle_fan` go through here, which is the point: an
## upgrade that widens the spray cannot widen the shot without widening the
## picture, or vice versa.
static func kernel_angle_offsets(for_level: int) -> PackedFloat32Array:
	var stats: Dictionary = _level_stats(for_level)
	var count: int = int(stats["kernels"])
	var spread: float = deg_to_rad(float(stats["spread_degrees"]))
	var out := PackedFloat32Array()
	for i: int in range(count):
		if count > 1:
			out.append(-spread * 0.5 + spread * (float(i) / float(count - 1)))
		else:
			out.append(0.0)
	return out


## The spread `for_level` fires through, derived rather than read back out of the
## table. LEVELS quotes the same number; `test_combat` asserts they agree, which is
## what stops a retune from widening the arc without re-nesting the angles.
static func spread_for(for_level: int) -> float:
	return KERNEL_STEP_DEGREES * float(int(_level_stats(for_level)["kernels"]) - 1)


## How many of `for_level`'s kernels catch one pest sitting `distance` px straight
## down the aim line. The only thing an off-axis kernel's fate turns on is how far
## from the line it passes, so this is the whole of the single-target question —
## see Kernel.connects().
static func kernels_connecting_at(for_level: int, distance: float) -> int:
	var hits: int = 0
	for offset: float in kernel_angle_offsets(for_level):
		if Kernel.connects(distance, offset):
			hits += 1
	return hits


## Damage per second `for_level` lands on a single pest `distance` px away. This is
## the number plant-tower-defense-axt was filed about: it used to fall from 2.78 to
## 1.61 when the player paid 45 seeds. Kept as a function rather than a comment so
## the claim is executable — `test_combat` sweeps it across the whole of RANGE.
static func single_target_dps(for_level: int, distance: float) -> float:
	var stats: Dictionary = _level_stats(for_level)
	return float(kernels_connecting_at(for_level, distance)) * float(stats["damage"]) / float(stats["interval"])


## The point the fan is projected from, in the plant's own space: FAN_PIVOT behind
## the cob, opposite the way it is aiming. Every pip is exactly FAN_LENGTH from
## here, at exactly `aim + kernel_angle_offsets()[i]`.
static func muzzle_pivot(aim: float = 0.0) -> Vector2:
	return Vector2.RIGHT.rotated(aim) * -FAN_PIVOT


## Where the muzzle pips sit in the plant's own space, for a level and an aim
## direction — one per kernel, in launch order. Pure: no node state, so what gets
## drawn is checkable without rendering a frame.
static func muzzle_pips(for_level: int, aim: float = 0.0) -> PackedVector2Array:
	var pivot: Vector2 = muzzle_pivot(aim)
	var out := PackedVector2Array()
	for offset: float in kernel_angle_offsets(for_level):
		out.append(pivot + Vector2.RIGHT.rotated(aim + offset) * FAN_LENGTH)
	return out


## The radius a pip covers on screen, rim included — what "does the fan fit in the
## cell" has to be measured against.
static func pip_outer_radius() -> float:
	return PIP_SIZE + PIP_RIM_WIDTH


## This cob's pips, at its current level and current aim.
func muzzle_pip_positions() -> PackedVector2Array:
	return muzzle_pips(level, _aim_angle)


func aim_angle() -> float:
	return _aim_angle


func spread_degrees() -> float:
	return float(_stats()["spread_degrees"])


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
	# Without this the fan keeps showing the level you paid to leave behind until
	# something else happens to dirty the canvas.
	queue_redraw()
	return true


func level_name() -> String:
	return String(_stats()["name"])


func kernels_per_shot() -> int:
	return int(_stats()["kernels"])


## What one kernel takes off a pest at this level. Public because it is now half of
## what an upgrade buys — past 80 px it is the *whole* of what an upgrade buys — and
## a selection panel quoting only `kernels_per_shot()` describes the level 3 cob as
## five kernels while the player watches four of them sail past.
func kernel_damage() -> float:
	return float(_stats()["damage"])


## Seconds between volleys at this level.
func fire_interval() -> float:
	return float(_stats()["interval"])
