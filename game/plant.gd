class_name Plant
extends Node2D

## Shared body for anything planted on a grass cell.
##
## Subclasses override `_act()`, which runs every physics frame with the pests
## currently on the board. Nothing here touches the scene tree for targeting —
## the pest list is passed down, so a subclass is testable without a Game.

var kind: StringName = &""
var cell: Vector2i = Vector2i.ZERO
var board: Board = null

var _sprite: Sprite2D
var _wobble_time: float = 0.0
var _selected: bool = false


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


## Game toggles this when the plant is clicked/deselected. Base class just
## tracks the flag and repaints; subclasses that draw a selection overlay
## (e.g. a range ring) override `_draw()` and read `_selected`.
func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	queue_redraw()
