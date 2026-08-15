class_name Game
extends Node2D

## Root of the run. Owns the board, the plants, the bugs, the money and the waves,
## and is the only place any of them are wired together.
##
## Everything below the HUD lives under `Entities`, which sits at y = BAR_HEIGHT so
## board coordinates and cell coordinates agree — a plant at cell (3, 2) is at
## board-local (224, 160) whatever the top bar does.

const LIVES: int = 10
## Seconds between a wave being cleared and the next one starting on its own. The
## button is still there; this stops a finished wave from stalling the run.
const PREP_SECONDS: float = 18.0

var board: Board
var bank: SeedBank
var director: WaveDirector
var hud: Hud

var lives: int = LIVES
var selected_plant: StringName = PlantCatalog.CORN
var selected_placed: Plant = null
var game_over: bool = false
var victory: bool = false

var _entities: Node2D
var _cursor: ColorRect
var _plants: Dictionary = {}
var _prep_left: float = 0.0
var _wave_live: bool = false


func _ready() -> void:
	add_to_group("game")

	bank = SeedBank.new()
	bank.name = "SeedBank"
	add_child(bank)

	director = WaveDirector.new()
	director.name = "WaveDirector"
	add_child(director)

	_entities = Node2D.new()
	_entities.name = "Entities"
	_entities.position = Vector2(0, Hud.BAR_HEIGHT)
	add_child(_entities)

	board = Board.new()
	board.name = "Board"
	_entities.add_child(board)

	_cursor = ColorRect.new()
	_cursor.name = "Cursor"
	_cursor.size = Vector2(Board.CELL, Board.CELL)
	_cursor.color = Color(1, 1, 1, 0.22)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.visible = false
	_entities.add_child(_cursor)

	hud = Hud.new()
	hud.name = "HUD"
	add_child(hud)

	bank.seeds_changed.connect(func(_total: int) -> void: _refresh())
	bank.purchase_failed.connect(func(reason: String) -> void: hud.show_message(reason))
	bank.plant_unlocked.connect(_on_plant_unlocked)

	director.spawn_requested.connect(spawn_pest)
	director.wave_started.connect(_on_wave_started)

	hud.plant_selected.connect(_on_plant_chosen)
	hud.packet_requested.connect(_on_packet_requested)
	hud.next_wave_requested.connect(start_next_wave)
	hud.upgrade_requested.connect(upgrade_selected)
	hud.uproot_requested.connect(uproot_selected)

	_prep_left = PREP_SECONDS
	_refresh()
	hud.show_message("Plant your free Corn Cobbler on the grass, then grow the first wave.", 8.0)


func _process(delta: float) -> void:
	if game_over or victory:
		return
	_check_wave_cleared()
	if not _wave_live and director.has_more_waves():
		_prep_left -= delta
		if _prep_left <= 0.0:
			start_next_wave()


# -- waves ------------------------------------------------------------------


func start_next_wave() -> bool:
	if game_over or victory or _wave_live or not director.has_more_waves():
		return false
	director.start_next_wave()
	return true


func _on_wave_started(number: int) -> void:
	_wave_live = true
	hud.show_message("Wave %d — %d pests." % [number, WaveDirector.pests_in_wave(number)])
	_refresh()


func _check_wave_cleared() -> void:
	if not _wave_live:
		return
	if director.is_spawning() or not get_tree().get_nodes_in_group("pests").is_empty():
		return
	_wave_live = false
	_prep_left = PREP_SECONDS
	if director.has_more_waves():
		hud.show_message("Wave %d cleared. Next one grows in %d seconds." % [director.current_wave, int(PREP_SECONDS)], 6.0)
	else:
		victory = true
		hud.show_banner("The garden holds!")
	_refresh()


## Puts one pest on the road immediately. The wave director drives this; the
## devtools `spawn_pest` verb uses it to stage a single bug without a whole wave.
func spawn_pest(species: StringName) -> void:
	var pest := Pest.new()
	_entities.add_child(pest)
	pest.setup(species, board.route())
	pest.died.connect(_on_pest_died)
	pest.escaped.connect(_on_pest_escaped)


func _on_pest_died(pest: Pest) -> void:
	bank.add_seeds(pest.seed_value)


func _on_pest_escaped(_pest: Pest) -> void:
	lives -= 1
	if lives <= 0:
		lives = 0
		game_over = true
		hud.show_banner("The garden is eaten")
		get_tree().call_group("pests", "queue_free")
	_refresh()


# -- placement --------------------------------------------------------------


func _on_plant_chosen(id: StringName) -> void:
	selected_plant = id
	selected_placed = null
	_refresh()


func plant_at(cell: Vector2i) -> Plant:
	return _plants.get(cell, null) as Plant


## Places `id` on `cell`, charging the bank. Returns "" on success, or the reason
## it refused — the devtools verbs and the tests both read that string.
func place_plant(id: StringName, cell: Vector2i) -> String:
	if game_over or victory:
		return "the run is over"
	if not PlantCatalog.has(id):
		return "no such plant: %s" % id
	if not board.is_buildable(cell):
		return "pests walk there" if board.is_path(cell) else "off the garden"
	if _plants.has(cell):
		return "something is already growing there"
	if not bank.pay_for_plant(id):
		return "not paid for"
	var plant: Plant = _new_plant(id)
	_entities.add_child(plant)
	plant.setup(id, cell, board)
	_plants[cell] = plant
	selected_placed = plant
	_refresh()
	return ""


func _new_plant(id: StringName) -> Plant:
	match id:
		PlantCatalog.CHOMP:
			return ChompFlower.new()
		_:
			return CornCobbler.new()


func upgrade_selected() -> String:
	var corn := selected_placed as CornCobbler
	if corn == null:
		return "nothing upgradeable is selected"
	if corn.is_max_level():
		return "already a full bunch of corn"
	var price: int = corn.upgrade_cost()
	if bank.seeds < price:
		hud.show_message("That upgrade costs %d seeds." % price)
		return "not enough seeds"
	bank.add_seeds(-price)
	corn.upgrade()
	hud.show_message("Corn Cobbler is now firing a %s." % corn.level_name())
	_refresh()
	return ""


func uproot_selected() -> String:
	if selected_placed == null or not is_instance_valid(selected_placed):
		return "nothing is selected"
	var plant: Plant = selected_placed
	_plants.erase(plant.cell)
	bank.refund(plant.uproot_refund())
	plant.queue_free()
	selected_placed = null
	_refresh()
	return ""


func _on_packet_requested() -> void:
	var got: StringName = bank.buy_packet()
	if got != &"":
		selected_plant = got


func _on_plant_unlocked(id: StringName) -> void:
	hud.show_message("The packet held a %s!" % PlantCatalog.display_name(id), 5.0)
	_refresh()


# -- input ------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_update_cursor(motion.position)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_click_at(click.position)
		return
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_R and (game_over or victory):
		get_tree().reload_current_scene()


func _update_cursor(screen_pos: Vector2) -> void:
	var cell: Vector2i = board.world_to_cell(screen_pos - _entities.position)
	if not board.is_inside(cell) or screen_pos.x > board.board_size().x:
		_cursor.visible = false
		return
	_cursor.visible = true
	_cursor.position = Vector2(cell.x * Board.CELL, cell.y * Board.CELL)
	var free: bool = board.is_buildable(cell) and not _plants.has(cell)
	_cursor.color = Color(0.18, 0.80, 0.44, 0.30) if free else Color(0.91, 0.30, 0.24, 0.30)


func _click_at(screen_pos: Vector2) -> void:
	if screen_pos.y < Hud.BAR_HEIGHT or screen_pos.x > board.board_size().x:
		return
	var cell: Vector2i = board.world_to_cell(screen_pos - _entities.position)
	if not board.is_inside(cell):
		return
	var existing: Plant = plant_at(cell)
	if existing != null:
		selected_placed = existing
		_refresh()
		return
	var refusal: String = place_plant(selected_plant, cell)
	if refusal != "" and refusal != "not paid for":
		hud.show_message(refusal.capitalize() + ".")


# -- state ------------------------------------------------------------------


func _refresh() -> void:
	if hud == null:
		return
	hud.refresh(state())


## One dictionary describing the whole run. The HUD renders it, the devtools
## `game_state` verb returns it, and the tests assert on it.
func state() -> Dictionary:
	return {
		"bank": bank,
		"seeds": bank.seeds,
		"wave": director.current_wave,
		"wave_count": director.wave_count(),
		"wave_live": _wave_live,
		"lives": lives,
		"selected_plant": selected_plant,
		"selected_placed": selected_placed,
		"plants": _plants.size(),
		"pests_alive": get_tree().get_nodes_in_group("pests").size(),
		"can_start_wave": not _wave_live and director.has_more_waves() and not game_over and not victory,
		"game_over": game_over,
		"victory": victory,
	}
