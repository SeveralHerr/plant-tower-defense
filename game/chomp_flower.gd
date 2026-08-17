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

## Radius of the "mouth full" ring. **Fixed**, and the arc's swept ANGLE carries the
## progress — the idiom `HuskLayer` has used since the husks existed
## (`game/husk_layer.gd:69-77`: a fixed `radius + RING_GAP`, `TAU * frac` of it drawn).
##
## It used to shrink from 16 to nothing instead, and that was backwards. A shrinking
## ring is smallest exactly when its news is most urgent — "the mouth is nearly free"
## is the moment a player decides whether to commit a lane — and `Node2D` paints its
## own canvas below its children, so the last of it disappeared behind the flower's
## own sprite. Two timers in one game had opposite answers and the husk's was the
## better one.
##
## 22 px is pinned between three things, none of them taste:
##   * **above** the old 16, so the arc clears the flower's head rather than being
##     drawn under it (cycle 70 measured a Corn Cobbler pip at 20 px reading leaf
##     green at one aim and its own gold at another);
##   * **below 26.0**, which is where `Sunflower`'s gauge puts its nearest corner —
##     `test_combat` asserts that corner is strictly outside this ring so the two
##     radial-looking readouts never share a pixel;
##   * **below 32**, half a `Board.CELL`, so it stays inside its own cell.
const CHEW_RING_RADIUS: float = 22.0
const CHEW_RING_WIDTH: float = 3.0

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


## Emitted when this Chomp is sitting still and the reason is flight — see
## `idle_only_because_of_flight`. Rising edge only: the condition is true for every
## frame a winged pest spends crossing the reach, and a per-frame signal would put the
## same sentence on the message row sixty times a second.
##
## Carries nothing. `Game` has the plant in hand from the connection, which is the same
## split `destroyed(plant)` and `grew_seeds` already use here.
signal flight_ignored

## True while `flight_ignored` has already fired for the current stretch of being
## walked past. Cleared when the condition goes false, so the next winged pest to
## arrive is a fresh edge — which is also the retry path when the message row was too
## busy to show the hint the first time.
var _flight_noted: bool = false


func _act(delta: float, pests: Array[Pest]) -> void:
	if _held != null:
		_chew(delta)
		return
	var prey: Pest = _nearest_free_pest(pests)
	if prey != null:
		_grab(prey)
		_flight_noted = false
		return
	# After the grab attempt, not before: a mouth that just closed on something is not
	# idle, whatever else is in reach.
	var winged: int = 0
	var grabbable: int = 0
	for pest: Pest in pests:
		if pest.held_by != null:
			continue
		if pest.global_position.distance_to(global_position) > GRAB_RADIUS:
			continue
		if pest.is_winged:
			winged += 1
		else:
			grabbable += 1
	if not idle_only_because_of_flight(winged, grabbable):
		_flight_noted = false
		return
	if _flight_noted:
		return
	_flight_noted = true
	flight_ignored.emit()


## The state the flight hint explains, as a pure function of what is within reach.
##
## Both halves matter and only together. A winged pest in reach is not confusing if a
## grabbable one is there too — the mouth closes on that one, the player sees the plant
## working, and nothing needs saying. It is confusing when EVERYTHING in reach flies,
## because then a bug walks over a mouth that does not move.
##
## Static and pure so the condition has a name a test can assert directly, rather than
## being an `and` buried in `_act` that can only be reached by staging two pests in a
## live tree. `Hud.uproot_shows_tip` is the same move for the same reason.
static func idle_only_because_of_flight(winged_in_reach: int, grabbable_in_reach: int) -> bool:
	return winged_in_reach > 0 and grabbable_in_reach == 0


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


## How far round the chew ring is drawn: a full circle when the mouth has just
## closed, sweeping down to nothing as the meal finishes.
##
## Pure, so the shape is assertable without a rendered frame — and so the draw site
## below carries no branch of its own. At the end the two ends coincide and
## `draw_arc` draws nothing, which is the same reason `CornCobbler._draw_muzzle_fan`
## lost its `if`: one place decides, and a test can reach it.
static func chew_arc_end(progress: float) -> float:
	return TAU * clampf(1.0 - progress, 0.0, 1.0)


## The ring around the flower while the mouth is full — the whole Chomp/beetle
## trade-off ("mouth busy, lane open") made visible. Fixed radius, swept angle; see
## CHEW_RING_RADIUS for why round that way.
func _draw() -> void:
	if _held == null:
		return
	draw_arc(Vector2.ZERO, CHEW_RING_RADIUS, 0.0, chew_arc_end(chew_progress()), 24,
		Color(1.0, 0.55, 0.15, 0.85), CHEW_RING_WIDTH, true)


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
