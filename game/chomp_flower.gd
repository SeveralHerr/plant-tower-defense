class_name ChompFlower
extends Plant

## The melee plant. The design doc's words are "eats small pests easily, takes a
## while eating bigger pests", so this is not a damage-per-second tower — it is a
## body blocker.
##
## Grabbing a pest holds it still AND occupies the flower for the whole chew. An
## aphid is gone in under half a second; a beetle ties the mouth up for two and a
## half, during which every other bug in the lane walks straight past. A player
## who fills a lane with Chomps has a lane full of busy mouths and nothing
## shooting, which is the entire rock-paper-scissors of the game.

## Must exceed one cell: a Chomp stands on grass and the pest walks the road, so
## the closest they ever get is exactly CELL apart. At 62 the flower could not
## reach the lane beside it and never ate anything — with no error anywhere,
## because "found no prey" and "there is no prey" look identical. Kept under two
## cells so it still only covers the lane it is actually next to.
const GRAB_RADIUS: float = Board.CELL * 1.15

## Radius of the "mouth full" ring at the start of a chew. It shrinks to 0 as
## the meal finishes, so the busy-mouth trade the design doc describes — "takes
## a while eating bigger pests" — is something the player can see, not infer.
const CHEW_RING_RADIUS: float = 16.0

## The design doc draws a Chomp mid-bite as its own picture, not a tinted idle
## sprite — swapped in for the whole chew and back on release.
const EATING_TEXTURE_PATH := "res://assets/sprites/chomp_flower_eating.png"

## The threshold is a fraction of chew_progress(), the same one the shrinking
## chew ring already reads, so it fires for any pest — an aphid crosses it
## too, just with only ~40% of its already-brief 0.45s chew left to show it,
## which reads as instant either way. A beetle's 2.6s chew is long enough
## that the last ~1s actually gets to show a second picture instead of the
## mouth just staying wide open the whole time.
const LATE_BITE_THRESHOLD: float = 0.6
const EATING_LATE_TEXTURE_PATH := "res://assets/sprites/chomp_flower_eating_late.png"

var _held: Pest = null
var _chew_left: float = 0.0
var _chew_total: float = 0.0
var _idle_texture: Texture2D = null
var _eating_texture: Texture2D = null
var _eating_late_texture: Texture2D = null


## A hungry pest that eats the flower out from under a meal must not leave the
## mouth stuck "busy" pointing at a freed pest.
func _on_setup() -> void:
	destroyed.connect(func(_p: Plant) -> void: release())


func _act(delta: float, pests: Array[Pest]) -> void:
	if _held != null:
		_chew(delta)
		return
	var prey: Pest = _nearest_free_pest(pests)
	if prey != null:
		_grab(prey)


func _nearest_free_pest(pests: Array[Pest]) -> Pest:
	var best: Pest = null
	var best_distance: float = GRAB_RADIUS
	for pest: Pest in pests:
		# Winged (doc: "ignores ground plants") flies over a Chomp's reach — the
		# mouth simply cannot close on it. It still walks into Corn's kernels.
		if pest.held_by != null or pest.is_winged:
			continue
		var d: float = pest.global_position.distance_to(global_position)
		if d <= best_distance:
			best_distance = d
			best = pest
	return best


func _grab(pest: Pest) -> void:
	_held = pest
	pest.held_by = self
	_chew_total = pest.chew_seconds
	_chew_left = _chew_total
	_bite()
	_show_eating_sprite()
	queue_redraw()


func _chew(delta: float) -> void:
	if not is_instance_valid(_held) or not _held.is_alive():
		release()
		return
	_chew_left -= delta
	if chew_progress() > LATE_BITE_THRESHOLD and _sprite != null and _sprite.texture != _eating_late_texture:
		_show_eating_late_sprite()
	queue_redraw()
	if _chew_left <= 0.0:
		var meal: Pest = _held
		release()
		# Bitten, so the corpse is squashed rather than straight -- a Chomp closes
		# on the whole pest (plant-tower-defense-f5z6).
		meal.kill(Pest.DEATH_BITTEN)


## Drops whatever is in the mouth and frees the flower. Called by Pest.kill() too,
## so a pest shot out of the mouth by a stray kernel does not wedge the plant shut.
func release() -> void:
	if _held != null and is_instance_valid(_held):
		_held.held_by = null
	_held = null
	_chew_left = 0.0
	_chew_total = 0.0
	_show_idle_sprite()
	queue_redraw()


func is_busy() -> bool:
	return _held != null


func held_pest() -> Pest:
	return _held


## 0.0 when the mouth just closed, 1.0 when the meal is about to finish.
func chew_progress() -> float:
	if _chew_total <= 0.0:
		return 0.0
	return clampf(1.0 - _chew_left / _chew_total, 0.0, 1.0)


## Shrinking ring around the flower while the mouth is full — the whole
## Chomp/beetle trade-off ("mouth busy, lane open") made visible.
func _draw() -> void:
	if _held == null:
		return
	var radius: float = CHEW_RING_RADIUS * (1.0 - chew_progress())
	if radius <= 0.5:
		return
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(1.0, 0.55, 0.15, 0.85), 3.0, true)


func _bite() -> void:
	# Ahead of the tree-guard below: the mouth closing is the game event, and
	# it happens whether or not there is a tree to play the squash tween in —
	# Sfx.play() gates its own headless silence, so there is nothing here for
	# a unit test calling _grab() directly to trip over.
	Sfx.play(Sfx.CHOMP_BITE)
	# The catch itself, not a kill — the meal doesn't die until _chew_left runs
	# out, so unlike Kernel's post-damage guard this is never racing a death
	# this same frame. Same is_alive() guard anyway, kept for the pattern.
	if is_instance_valid(_held) and _held.is_alive():
		_held.flash_hit()
	if _sprite == null or not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2(1.18, 0.82), 0.06)
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.12)


func _show_eating_sprite() -> void:
	if _sprite == null:
		return
	if _idle_texture == null:
		_idle_texture = _sprite.texture
	if _eating_texture == null:
		_eating_texture = load(EATING_TEXTURE_PATH) as Texture2D
	if _eating_texture != null:
		_sprite.texture = _eating_texture


func _show_eating_late_sprite() -> void:
	if _sprite == null:
		return
	if _idle_texture == null:
		_idle_texture = _sprite.texture
	if _eating_late_texture == null:
		_eating_late_texture = load(EATING_LATE_TEXTURE_PATH) as Texture2D
	if _eating_late_texture != null:
		_sprite.texture = _eating_late_texture


func _show_idle_sprite() -> void:
	if _sprite != null and _idle_texture != null:
		_sprite.texture = _idle_texture
