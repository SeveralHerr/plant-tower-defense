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
var compost: CompostMeter

var lives: int = LIVES
var selected_plant: StringName = PlantCatalog.CORN
var selected_placed: Plant = null
var game_over: bool = false
var victory: bool = false

var _entities: Node2D
var _cursor: ColorRect
var _husk_layer: HuskLayer
var _plants: Dictionary = {}
var _prep_left: float = 0.0
var _wave_live: bool = false
var _score_recorded: bool = false

## The furthest any pest got this wave, so the lane pressure readout can be
## committed to the board once the wave actually clears. -1.0 means nothing
## has walked yet this wave (progress() itself never goes negative).
## Road cell -> how many pests this wave were lost there (killed or escaped).
## Committed to the board as one batch when the wave ends; see
## Board.record_lane_pressure_wave.
var _wave_losses: Dictionary = {}


func _ready() -> void:
	add_to_group("game")

	bank = SeedBank.new()
	bank.name = "SeedBank"
	add_child(bank)

	director = WaveDirector.new()
	director.name = "WaveDirector"
	director.endless = RunConfig.endless
	add_child(director)

	compost = CompostMeter.new()
	compost.name = "CompostMeter"
	add_child(compost)

	_entities = Node2D.new()
	_entities.name = "Entities"
	_entities.position = Vector2(0, Hud.BAR_HEIGHT)
	add_child(_entities)

	board = Board.new()
	board.name = "Board"
	_entities.add_child(board)

	_husk_layer = HuskLayer.new()
	_husk_layer.name = "HuskLayer"
	_husk_layer.compost = compost
	_entities.add_child(_husk_layer)

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
	director.wave_spawning_finished.connect(func(_n: int) -> void: _refresh())

	compost.husk_collected.connect(func(_v: int) -> void: _refresh())

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
	_wave_losses = {}
	hud.show_message("Wave %d — %d pests." % [number, director.current_wave_pest_count()])
	_refresh()


## Notes one pest lost at `at` against the wave's tally. This used to be a
## per-frame scan of every live pest keeping a single high-water mark, which
## answered "how far did the worst one get" and threw away everything else —
## a wave stopped cleanly at three separate points looked identical to one
## stopped at its furthest. Every pest leaves the board through exactly one of
## the two callers below, so the events say the same thing the scan did and
## more, without looping over the group sixty times a second.
func _note_lane_loss(at: Vector2) -> void:
	if not _wave_live:
		return
	var cell: Vector2i = board.world_to_cell(at)
	_wave_losses[cell] = int(_wave_losses.get(cell, 0)) + 1


## Commits this wave's whole loss tally to the board. Split out of
## _check_wave_cleared because a wave does not only end by clearing — losing
## the last life mid-wave ends it too, and _process's own `if game_over:
## return` guard means _check_wave_cleared never runs on that path (caught
## live: a wave lost to zero lives left the board's readout permanently one
## wave stale). _on_pest_escaped calls this directly the moment lives hits 0,
## before that guard ever gets a chance to skip it.
func _commit_lane_pressure() -> void:
	if _wave_losses.is_empty():
		return
	board.record_lane_pressure_wave(_wave_losses)
	_wave_losses = {}


func _check_wave_cleared() -> void:
	if not _wave_live:
		return
	if director.is_spawning() or not get_tree().get_nodes_in_group("pests").is_empty():
		return
	_wave_live = false
	_prep_left = PREP_SECONDS
	_commit_lane_pressure()
	if director.has_more_waves():
		hud.show_message("Wave %d cleared. Next one grows in %d seconds." % [director.current_wave, int(PREP_SECONDS)], 6.0)
	else:
		victory = true
		_end_run("The garden holds!")
	_refresh()


## Puts one pest on the road immediately. The wave director drives this; the
## devtools `spawn_pest` verb uses it to stage a single bug without a whole
## wave. `mutation` is &"" outside wave 8+ or for a manually staged pest.
func spawn_pest(species: StringName, mutation: StringName = &"") -> void:
	var pest := Pest.new()
	_entities.add_child(pest)
	pest.setup(species, board.route())
	# Endless difficulty rides on the wave number, not on the endless flag —
	# both scales are 1.0 inside the fixed table, so campaign spawns and a
	# devtools-staged pest go through the identical call.
	pest.apply_wave_scaling(
		WaveDirector.health_scale_for(director.current_wave),
		WaveDirector.speed_scale_for(director.current_wave)
	)
	if mutation != &"":
		pest.apply_mutation(mutation)
	pest.died.connect(_on_pest_died)
	pest.escaped.connect(_on_pest_escaped)


func _on_pest_died(pest: Pest) -> void:
	_note_lane_loss(pest.position)
	bank.add_seeds(pest.seed_value)
	# Half again, as a husk — collectible for a bonus, or left to rot. See
	# CompostMeter: this is what makes "sweep the field" worth doing. Scaled by
	# husk_multiplier() so a harder kill (a mutation) pays out more, tying the
	# mutation and compost systems together instead of leaving them side by side.
	var husk_value: int = maxi(1, int(ceil(pest.seed_value / 2.0 * pest.husk_multiplier())))
	compost.drop_husk(pest.position, husk_value)


func _on_pest_escaped(_pest: Pest) -> void:
	# An escaped pest is past the exit and off the board, so its own position
	# is not a road cell and would be dropped. Attribute it to the last cell of
	# the road instead — which is also the honest reading: that is where the
	# lane finally failed. Deliberately not conditional on `_pest`; the tests
	# and the losing-escape path both call this with null.
	_note_lane_loss(board.cell_to_world(board.exit_cell()))
	lives -= 1
	if lives <= 0:
		lives = 0
		game_over = true
		_commit_lane_pressure()
		_end_run("The garden is eaten")
		get_tree().call_group("pests", "queue_free")
	_refresh()


## Common tail of a run, win or lose: banners the result and files the seed
## total against RunConfig's persisted high score exactly once.
func _end_run(banner: String) -> void:
	var new_record: bool = not _score_recorded and RunConfig.record_score(bank.seeds_earned_total)
	_score_recorded = true
	var line: String = "%s\nSeeds grown: %d" % [banner, bank.seeds_earned_total]
	if new_record:
		line += "  — new high score!"
	else:
		line += "  (best %d)" % RunConfig.high_score
	hud.show_banner(line)


# -- placement --------------------------------------------------------------


func _on_plant_chosen(id: StringName) -> void:
	selected_plant = id
	_select(null)
	_refresh()


## Single point of truth for `selected_placed` — flips the range-ring/selection
## flag on the outgoing and incoming plant so exactly one plant ever shows it.
func _select(plant: Plant) -> void:
	if selected_placed != null and is_instance_valid(selected_placed):
		selected_placed.set_selected(false)
	selected_placed = plant
	if selected_placed != null:
		selected_placed.set_selected(true)


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
	plant.destroyed.connect(_on_plant_destroyed)
	if plant.has_signal("grew_seeds"):
		plant.connect("grew_seeds", _on_plant_grew_seeds)
	_select(plant)
	_refresh()
	return ""


func _new_plant(id: StringName) -> Plant:
	match id:
		PlantCatalog.CHOMP:
			return ChompFlower.new()
		PlantCatalog.SUNFLOWER:
			return Sunflower.new()
		_:
			return CornCobbler.new()


## A hungry pest (Pest.is_hungry) ate this plant down to 0 health instead of
## walking past it. No refund — see uproot_selected() for the "sold on
## purpose" path, which is the only one that pays anything back.
func _on_plant_destroyed(plant: Plant) -> void:
	if _plants.get(plant.cell) == plant:
		_plants.erase(plant.cell)
	if selected_placed == plant:
		_select(null)
	hud.show_message("A hungry pest ate your %s!" % PlantCatalog.display_name(plant.kind), 4.0)
	plant.queue_free()
	_refresh()


func _on_plant_grew_seeds(amount: int) -> void:
	bank.add_seeds(amount)


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
	_select(null)
	_refresh()
	return ""


func _on_packet_requested(tier: StringName = &"common") -> void:
	var got: StringName = bank.buy_packet(tier)
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
	var local: Vector2 = screen_pos - _entities.position
	var swept: int = compost.collect_at(local)
	if swept > 0:
		bank.add_seeds(swept)
		hud.show_message("Composted a husk for %d seeds." % swept, 2.0)
		return
	var cell: Vector2i = board.world_to_cell(local)
	if not board.is_inside(cell):
		return
	var existing: Plant = plant_at(cell)
	if existing != null:
		_select(existing)
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
		"endless": director.endless,
		"seeds_earned_total": bank.seeds_earned_total,
		"high_score": RunConfig.high_score,
		"compost_total": compost.total_collected,
		"husks_on_ground": compost.husk_count(),
	}
