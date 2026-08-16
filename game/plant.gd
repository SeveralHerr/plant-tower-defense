class_name Plant
extends Node2D

## Shared body for anything planted on a grass cell.
##
## Subclasses override `_act()`, which runs every physics frame with the pests
## currently on the board. Nothing here touches the scene tree for targeting —
## the pest list is passed down, so a subclass is testable without a Game.

## A hungry pest (see Pest.is_hungry) eats a plant instead of walking past it —
## this is what it eats through. Most plants never take a scratch in a normal
## run; the bar only appears once they do, same as a pest's.
const MAX_HEALTH: float = 40.0

signal destroyed(plant: Plant)

var kind: StringName = &""
var cell: Vector2i = Vector2i.ZERO
var board: Board = null
var health: float = MAX_HEALTH

var _sprite: Sprite2D
var _wobble_time: float = 0.0
var _selected: bool = false
var _health_back: ColorRect = null
var _health_bar: ColorRect = null
var _selection_marker: SelectionMarker = null


func setup(id: StringName, at: Vector2i, on_board: Board) -> void:
	kind = id
	cell = at
	board = on_board
	if board != null:
		position = board.cell_to_world(at)
	add_to_group("plants")
	_build_visuals()
	_on_setup()


func _build_visuals() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load(PlantCatalog.texture_path(kind)) as Texture2D
	add_child(_sprite)

	_health_back = ColorRect.new()
	_health_back.color = Color(0.12, 0.12, 0.12, 0.65)
	_health_back.position = Vector2(-16, -34)
	_health_back.size = Vector2(32, 5)
	_health_back.visible = false
	add_child(_health_back)

	_health_bar = ColorRect.new()
	_health_bar.color = Color(0.85, 0.25, 0.22)
	_health_bar.position = Vector2(-16, -34)
	_health_bar.size = Vector2(32, 5)
	_health_bar.visible = false
	add_child(_health_bar)

	# A sibling node, not something drawn inside this plant's own _draw() — see
	# SelectionMarker's own header for why subclasses can't be trusted to paint
	# this themselves.
	_selection_marker = SelectionMarker.new()
	_selection_marker.visible = false
	add_child(_selection_marker)

	# Planting pop: the sprites are centred on their own vertical axis, which is
	# what makes a scale tween land without drifting off the cell.
	if not is_inside_tree():
		return
	_sprite.scale = Vector2(0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2(1.12, 1.12), 0.12)
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.10)


func _on_setup() -> void:
	pass


func _physics_process(delta: float) -> void:
	_act(delta, _live_pests())


func _act(_delta: float, _pests: Array[Pest]) -> void:
	pass


func _live_pests() -> Array[Pest]:
	var out: Array[Pest] = []
	for node: Node in get_tree().get_nodes_in_group("pests"):
		var pest := node as Pest
		if pest != null and pest.is_alive():
			out.append(pest)
	return out


## Whichever live pest inside `radius` is furthest along the road. Leaking a pest
## costs a life, so the one closest to the exit is always the right target.
func _furthest_along_in_range(pests: Array[Pest], radius: float) -> Pest:
	var best: Pest = null
	var best_progress: float = -1.0
	for pest: Pest in pests:
		if pest.global_position.distance_to(global_position) > radius:
			continue
		var p: float = pest.progress()
		if p > best_progress:
			best_progress = p
			best = pest
	return best


## Sold/uprooted plants refund most of what they cost — see uproot_refund().
func uproot_refund() -> int:
	return int(floor(PlantCatalog.cost(kind) * 0.6))


## A hungry pest calls this instead of walking past. Game listens for
## `destroyed` and removes the plant from the board — no refund, it was eaten.
func take_damage(amount: float) -> void:
	if is_destroyed():
		return
	health = maxf(0.0, health - amount)
	# A hungry pest calls this every physics frame, so this would be sixty plays
	# a second if it were not gated — Sfx.REPEAT_MS[PLANT_BITTEN] is what turns
	# that stream of calls into a repeating nibble, which is why the call site
	# here stays unguarded. The bar below only appears once a plant is bitten,
	# and a bar the player is not looking at is not a warning.
	if amount > 0.0:
		Sfx.play(Sfx.PLANT_BITTEN)
	if _health_back != null:
		_health_back.visible = true
		_health_bar.visible = true
		_health_bar.size = Vector2(32.0 * (health / MAX_HEALTH), 5)
	if health <= 0.0:
		destroyed.emit(self)


func is_destroyed() -> bool:
	return health <= 0.0


## Game toggles this when the plant is clicked/deselected. Base class just
## tracks the flag and repaints; subclasses that draw a selection overlay
## (e.g. a range ring) override `_draw()` and read `_selected`.
func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	if _selection_marker != null:
		_selection_marker.visible = value
	queue_redraw()
