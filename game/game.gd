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
## How long an armed Uproot stays armed before it disarms itself.
##
## Uproot is the only irreversible click in the game — it refunds 60% and frees
## the node, and a real undo would have to restore CornCobbler.level, the
## Sunflower's yield clock, the plant's remaining health and the consumed free
## starter, several of which cannot be recovered once queue_free lands. So the
## click is gated going in rather than reversed coming out. Four seconds is long
## enough to read the relabelled button and short enough that a wave arriving
## mid-decision does not leave a live trigger sitting under the cursor.
const UPROOT_CONFIRM_SECONDS: float = 4.0
## Where "Back to the gate" goes. The game could previously only be left by
## quitting: the sole scene change in the project ran the other way, title into
## game, and R reloaded the run without ever offering the menu.
const TITLE_SCENE := "res://game/title.tscn"

## Every key the run answers to, and what it does.
##
## A run had four keyboard verbs and no screen named one of them. The only mention
## anywhere was "Press M to bring it back", printed after you had already found M.
## The title screen documents its own three keys in a HintLabel, so the convention
## existed; the run simply did not follow it.
##
## This is a table rather than three sentences on the pause card because a list of
## bindings that is written by hand goes stale the first time someone adds a key
## and forgets. `test_every_key_the_run_handles_is_named_on_the_pause_card` reads
## the KEY_* constants out of _unhandled_input's own source and asserts this table
## covers them, so adding a binding without documenting it fails the build.
const KEY_HELP: Array[Dictionary] = [
	{"keys": "Esc  ·  P", "does": "hold the garden still", "codes": [KEY_ESCAPE, KEY_P]},
	{"keys": "M", "does": "sound on or off", "codes": [KEY_M]},
	{"keys": "R", "does": "start over, once the run is done", "codes": [KEY_R]},
]

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
var _preview: PlacementPreview
## Last cell the cursor was over, or x < 0 for "off the board". Kept so the
## preview can be re-drawn on events that are not mouse motion.
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _husk_layer: HuskLayer
var _plants: Dictionary = {}
var _prep_left: float = 0.0
var _wave_live: bool = false
var _score_recorded: bool = false

## The plant an Uproot click has armed, and how long it stays armed. Held here
## rather than in the Hud because the HUD is deliberately stateless — it renders
## whatever state() hands it and keeps no second copy of the truth (see hud.gd).
## Keyed by the plant, not a bare bool, so arming one plant and then selecting
## another cannot leave a live trigger pointed at the wrong garden bed.
var _uproot_armed: Plant = null
var _uproot_left: float = 0.0

## Last health reading of the selected plant, so the panel can follow a chew.
##
## Plant has no health_changed signal and damage is applied per physics frame by
## every adjacent pest (Pest.EAT_DPS * delta), so wiring one would fire ~60x a
## second and rebuild every HUD string with it. Watching the value here refreshes
## on change only, and keeps the HUD stateless — it still holds no copy of this.
var _selected_health: float = -1.0

## What the run did, as opposed to what it lost.
##
## The post-mortem could only ever report damage — waves survived, beds lost,
## weakest ground — because these two were the numbers nobody had written down.
## _on_pest_died is the single funnel every kill routes through, and nothing in
## game/ called Time.* at all, so a run had no duration either.
var pests_defeated: int = 0
var run_seconds: float = 0.0

## The post-mortem card and the layer it sits on, built once when the run ends.
var _summary: RunSummary = null
var _summary_layer: CanvasLayer = null

## The pause card and its layer, built on demand and freed on resume.
var _pause_screen: PauseScreen = null
var _pause_layer: CanvasLayer = null

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

	_preview = PlacementPreview.new()
	_preview.name = "PlacementPreview"
	_preview.visible = false
	_entities.add_child(_preview)

	hud = Hud.new()
	hud.name = "HUD"
	add_child(hud)

	bank.seeds_changed.connect(func(_total: int) -> void: _refresh())
	bank.purchase_failed.connect(func(reason: String) -> void: hud.show_message(reason))
	bank.plant_unlocked.connect(_on_plant_unlocked)

	director.spawn_requested.connect(spawn_pest)
	director.wave_started.connect(_on_wave_started)
	director.wave_spawning_finished.connect(func(_n: int) -> void: _refresh())

	# Wired to the signal rather than to the click handler so every route into a
	# collected husk pays the same cue — _click_at is the only one today, but the
	# devtools verbs and the tests reach collect_at() directly.
	compost.husk_collected.connect(_on_husk_collected)
	# The silent-death case this whole sound pass exists for: a husk that rotted
	# because the player was too slow used to leave the board with no cue at all.
	compost.husk_rotted.connect(_on_husk_rotted)

	hud.plant_selected.connect(_on_plant_chosen)
	hud.packet_requested.connect(_on_packet_requested)
	hud.next_wave_requested.connect(start_next_wave)
	hud.upgrade_requested.connect(upgrade_selected)
	# The button goes through the confirm gate; uproot_selected() stays the
	# unguarded mutator underneath it, which is what the devtools verbs and the
	# placement tests drive.
	hud.uproot_requested.connect(request_uproot)

	_prep_left = PREP_SECONDS
	_refresh()
	hud.show_message("Plant your free Corn Cobbler on the grass, then grow the first wave.", 8.0)


func _process(delta: float) -> void:
	# Ahead of the game-over return: a run that ends while Uproot is armed must
	# still disarm, or the trigger is left live under the cursor on the results
	# screen and survives into whatever the player clicks next.
	_tick_uproot_confirm(delta)
	_watch_selected_health()
	if game_over or victory:
		return
	# After the early return, so the clock stops the instant the run does rather
	# than counting the time the player spends reading the post-mortem.
	run_seconds += delta
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
	Sfx.play(Sfx.WAVE_STARTED)
	# Past the fixed table, say what actually got worse. The threat level on
	# the bar answers "how much"; this answers "in what way", which is the half
	# that tells a player whether to buy damage or buy coverage.
	hud.announce_wave(number, director.current_wave_pest_count(),
		WaveDirector.escalation_note(number))
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
		# After _commit_lane_pressure above, not before: prep_note() reads the
		# batch that call just posted, and running it first would describe the
		# wave before last for the whole of the window the player buys in.
		hud.show_message(Hud.wave_cleared_line(director.current_wave, prep_note()), 6.0)
	else:
		victory = true
		_end_run("The garden holds!")
	_refresh()


## The sentence the prep window opens with, past "Wave N cleared."
##
## The run-total damage reading has existed all along and was revealed exactly
## once — by Board.show_run_pressure(), from _end_run — which is to say the
## number that would inform a purchase was held back until purchasing had
## stopped. This is where it comes forward.
##
## It does NOT come forward as paint. The road already wears the per-wave map,
## and a second tint over the same cells is a blend rather than two readings
## (see Hud.prep_depth_note). It comes forward as the comparison the map cannot
## make: how deep this wave got against how deep the run has been getting.
##
## The countdown is the fallback rather than the headline. It restates the prep
## strip, which already draws the same countdown in the coming wave's threat
## colour — worth a whole line only when there is genuinely nothing else to say,
## which is a run that has not yet stopped a single pest anywhere.
func prep_note() -> String:
	var note: String = Hud.prep_depth_note(board.last_wave_depth(), board.run_depth())
	if note != "":
		return note
	return "Next one grows in %d seconds." % int(PREP_SECONDS)


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


func _on_husk_collected(_value: int) -> void:
	Sfx.play(Sfx.HUSK_COLLECTED)
	_refresh()


## The cue for a husk nobody swept. No _refresh(): a rotted husk changes nothing
## the HUD reads except `husks_on_ground`, which the next frame's refresh picks
## up anyway — and a rot storm at the end of a wave must not rebuild the bar once
## per husk.
func _on_husk_rotted(_value: int) -> void:
	Sfx.play(Sfx.HUSK_ROTTED)


func _on_pest_died(pest: Pest) -> void:
	# Played here, not in Pest, on purpose: Pest._play_death() queue_frees the
	# node DEATH_LINGER seconds later, and a freed node cannot finish a sound.
	# Sfx's pool sits under the scene tree root, so nothing on the board owns it.
	Sfx.play(Sfx.PEST_KILLED)
	pests_defeated += 1
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
	Sfx.play(Sfx.PEST_ESCAPED)
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
func _end_run(_banner: String) -> void:
	var new_record: bool = bank_score()
	# While playing, the lane overlay shows the last wave and fades older ones,
	# which is what makes it readable in the moment and useless afterwards — by
	# the time a run ends, wave 3's disaster has decayed to nothing. Swap it for
	# the run total, accumulated unfaded all along, so the board itself answers
	# "where was my garden actually weak". The card's backdrop is translucent
	# precisely so this stays visible underneath it.
	board.show_run_pressure()
	# Idempotent: _end_run's score filing is already guarded by _score_recorded,
	# but nothing stopped it building UI twice, and both end paths can be reached
	# more than once in a frame (a losing escape also clears the pest group).
	if _summary != null and is_instance_valid(_summary):
		return
	# Behind the idempotency guard rather than at the top of _end_run: both end
	# paths can be reached twice in a frame, and the run-ender is the one cue in
	# the game long enough for a doubled play to be audible as a doubled play.
	Sfx.play(Sfx.RUN_WON if victory else Sfx.RUN_LOST)
	_summary = RunSummary.build(summary_stats(new_record))
	_summary_layer = CanvasLayer.new()
	_summary_layer.name = "SummaryLayer"
	# Above the HUD's layer 10, or the side panel draws over the card.
	_summary_layer.layer = 20
	add_child(_summary_layer)
	_summary_layer.add_child(_summary)
	_summary.replay_requested.connect(func() -> void: get_tree().reload_current_scene())
	_summary.gate_requested.connect(func() -> void: get_tree().change_scene_to_file(TITLE_SCENE))


## Files the run's seed total against the high score for the mode being played,
## at most once per run.
##
## _end_run used to be the only caller of RunConfig.record_score, reached only by
## winning or by losing the last bed -- and `has_more_waves()` is unconditionally
## true in endless, so victory is unreachable there. That made dying the only way
## to bank an endless score, and then pause shipped two doors that walked out
## past it. A player who quit a long run voluntarily filed nothing, which is to
## say the run they were most likely to be proud of was the one guaranteed not to
## count.
##
## Shares _score_recorded with _end_run, so quitting and then losing, or losing
## and then quitting, still files exactly one score.
## What the pause card says about the moment it interrupted. The old text was the
## constant "The wave is waiting.", which is false between waves -- and pause can
## fire at any moment outside game-over.
func pause_note() -> String:
	if _wave_live:
		var alive: int = get_tree().get_nodes_in_group("pests").size()
		if alive > 0:
			return "%d pest(s) frozen mid-step." % alive
		return "The wave is still arriving."
	if not director.has_more_waves():
		return "Nothing left to grow."
	return "The next wave is %d seconds away." % int(ceil(_prep_left))


func bank_score() -> bool:
	if _score_recorded:
		return false
	_score_recorded = true
	return RunConfig.record_score(bank.seeds_earned_total)


## Holds the run still. The prep countdown, the wave spawner, every plant timer
## and every pest all live on the paused tree, so one flag stops all of them --
## which is the point: a hand-rolled "paused" bool would have to be checked in
## eight places and would be forgotten in the ninth.
func pause_run() -> void:
	if _pause_screen != null and is_instance_valid(_pause_screen):
		return
	_pause_screen = PauseScreen.build(pause_note(), KEY_HELP)
	_pause_layer = CanvasLayer.new()
	_pause_layer.name = "PauseLayer"
	# Above the HUD at 10 and the post-mortem at 20, so a pause is always the
	# top-most thing on screen.
	_pause_layer.layer = 30
	# The layer must keep processing too, or the Control inside it never draws
	# the frame that shows it.
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_layer)
	_pause_layer.add_child(_pause_screen)
	_pause_screen.resume_requested.connect(resume_run)
	_pause_screen.restart_requested.connect(func() -> void:
		bank_score()
		get_tree().paused = false
		get_tree().reload_current_scene())
	_pause_screen.gate_requested.connect(func() -> void:
		bank_score()
		# Unpause before leaving: `paused` is a property of the tree, not of the
		# scene, so it would survive the change and freeze the title screen.
		get_tree().paused = false
		get_tree().change_scene_to_file(TITLE_SCENE))
	get_tree().paused = true


func resume_run() -> void:
	get_tree().paused = false
	if _pause_layer != null and is_instance_valid(_pause_layer):
		_pause_layer.queue_free()
	_pause_layer = null
	_pause_screen = null


## True while the run is held. Read by the tests; the tree's own `paused` is the
## single source of truth, so this never disagrees with it.
func is_paused() -> bool:
	return get_tree().paused


## Everything the post-mortem card reports. Split out from _end_run so a test can
## assert the numbers without building the Control, and so the panel takes a plain
## Dictionary rather than reaching into Game for each field.
func summary_stats(new_record: bool) -> Dictionary:
	var worst: Vector2i = board.worst_run_cell()
	return {
		"victory": victory,
		"endless": director.endless,
		"wave": director.current_wave,
		"wave_count": director.wave_count(),
		"threat_level": WaveDirector.threat_level(maxi(1, director.current_wave)),
		"lives_lost": LIVES - lives,
		"seeds_earned_total": bank.seeds_earned_total,
		"high_score": RunConfig.best_for(director.endless),
		"new_record": new_record,
		"compost_total": compost.total_collected,
		# The denominator. state() carries the total but not the meter, so the
		# card cannot ask how many husks were resolved without this.
		"compost_resolved": compost.total_resolved(),
		"pests_defeated": pests_defeated,
		"run_seconds": run_seconds,
		"worst_cell": worst,
		"worst_cell_losses": int(board.run_losses().get(worst, 0)),
	}


# -- placement --------------------------------------------------------------


func _on_plant_chosen(id: StringName) -> void:
	selected_plant = id
	_select(null)
	# Picking a different plant while the cursor sits still must re-draw the
	# ring: switching from a Chomp to a Corn triples the coverage, and a hover
	# cue that only updates on mouse motion would show the old plant's reach
	# until the player happened to move.
	if _hover_cell.x >= 0:
		_update_preview(_hover_cell, board.is_buildable(_hover_cell) and not _plants.has(_hover_cell))
	_refresh()


## Single point of truth for `selected_placed` — flips the range-ring/selection
## flag on the outgoing and incoming plant so exactly one plant ever shows it.
func _select(plant: Plant) -> void:
	if selected_placed != null and is_instance_valid(selected_placed):
		selected_placed.set_selected(false)
	# Changing selection cancels a pending Uproot. Keying the arming to the plant
	# would already stop it firing on the wrong one, but leaving it armed means
	# clicking back to the first plant re-enters a live window the player has
	# stopped thinking about.
	if plant != _uproot_armed:
		_disarm_uproot()
	selected_placed = plant
	if selected_placed != null:
		selected_placed.set_selected(true)


func plant_at(cell: Vector2i) -> Plant:
	return _plants.get(cell, null) as Plant


## Would a click on `cell` right now actually put the selected plant into the
## ground? Exactly the question place_plant() answers with "", minus the paying:
## a predicate rather than a trial call, because place_plant() charges the bank
## and neither a hover cue nor a precedence test may spend the player's seeds to
## find out what it would have said.
##
## It exists because it has two callers, and they are the two halves of one
## promise. _update_preview draws the encouraging green brackets on it, and
## _click_at hands it the click ahead of the compost sweep — so the ring is a
## promise rather than a hint: if the preview shows a plant going in, the click
## plants it. See _click_at for the rest of that rule.
func would_plant_at(cell: Vector2i) -> bool:
	if game_over or victory:
		return false
	if not PlantCatalog.has(selected_plant):
		return false
	if not board.is_buildable(cell):
		return false
	if _plants.has(cell):
		return false
	# can_afford folds in both the lock and the free starter, which is the whole
	# money question — the same call _update_preview used to make on its own.
	return bank.can_afford(selected_plant)


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
	Sfx.play(Sfx.PLANT_PLACED)
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
		PlantCatalog.SUNDEW:
			return StickySundew.new()
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
	Sfx.play(Sfx.PLANT_DESTROYED)
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


## What the Uproot button is wired to. The first click arms; a second click on
## the same plant within UPROOT_CONFIRM_SECONDS commits.
##
## Returns "" when the plant was actually uprooted, and otherwise the reason it
## was not — "confirm needed" for the arming click, which is a refusal the caller
## can distinguish from a real failure.
func request_uproot() -> String:
	if selected_placed == null or not is_instance_valid(selected_placed):
		return "nothing is selected"
	if _uproot_armed == selected_placed and _uproot_left > 0.0:
		_disarm_uproot()
		return uproot_selected()
	_uproot_armed = selected_placed
	_uproot_left = UPROOT_CONFIRM_SECONDS
	Sfx.play(Sfx.UPROOT_ARMED)
	# IMPORTANT: this is an instruction with a live 4-second trigger behind it, and
	# an ambient husk pickup used to wipe it mid-read.
	hud.show_message("Click Uproot again to dig up your %s — it will not grow back."
		% PlantCatalog.display_name(selected_placed.kind), UPROOT_CONFIRM_SECONDS,
		Hud.MESSAGE_IMPORTANT)
	_refresh()
	return "confirm needed"


## True while a second Uproot click would commit. Read by the HUD to relabel the
## button, and by the tests.
func uproot_armed() -> bool:
	return _uproot_armed != null and _uproot_armed == selected_placed and _uproot_left > 0.0


## Refreshes the panel when — and only when — the selected plant's health moves.
func _watch_selected_health() -> void:
	if selected_placed == null or not is_instance_valid(selected_placed):
		_selected_health = -1.0
		return
	if is_equal_approx(selected_placed.health, _selected_health):
		return
	_selected_health = selected_placed.health
	_refresh()


func _disarm_uproot() -> void:
	_uproot_armed = null
	_uproot_left = 0.0


func _tick_uproot_confirm(delta: float) -> void:
	if _uproot_left <= 0.0:
		return
	# A plant that was eaten mid-decision takes its arming with it, rather than
	# leaving a freed instance armed for a cell something else can be planted on.
	if _uproot_armed == null or not is_instance_valid(_uproot_armed):
		_disarm_uproot()
		_refresh()
		return
	_uproot_left -= delta
	if _uproot_left <= 0.0:
		_disarm_uproot()
		hud.show_message("Uproot cancelled.", 2.0)
		_refresh()


## The unguarded mutator: removes the selected plant and pays the refund with no
## confirmation. The button never reaches this directly — see request_uproot —
## but the devtools verbs and the placement tests do, deliberately.
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
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_R and (game_over or victory):
		get_tree().reload_current_scene()
		return
	# Not while the run is over: the post-mortem is already a modal surface, and
	# pausing behind it would leave two cards stacked with no way to reach either.
	if (key.keycode == KEY_ESCAPE or key.keycode == KEY_P) and not (game_over or victory):
		pause_run()
		return
	# The project-level mute, which is what makes the sound pass something the
	# player controls rather than something the engine's --mute flag controls for
	# them. Deliberately live even on the results screen: a jingle the player
	# wants to stop is exactly when they reach for this.
	if key.keycode == KEY_M:
		var muted: bool = Sfx.toggle_muted()
		hud.show_message("Sound off. Press M to bring it back." if muted else "Sound on.", 2.5)


func _update_cursor(screen_pos: Vector2) -> void:
	var cell: Vector2i = board.world_to_cell(screen_pos - _entities.position)
	if not board.is_inside(cell) or screen_pos.x > board.board_size().x:
		_cursor.visible = false
		_preview.visible = false
		_hover_cell = Vector2i(-1, -1)
		return
	_hover_cell = cell
	_cursor.visible = true
	_cursor.position = Vector2(cell.x * Board.CELL, cell.y * Board.CELL)
	var free: bool = board.is_buildable(cell) and not _plants.has(cell)
	_cursor.color = Color(GardenTheme.LEAF, 0.30) if free else Color(GardenTheme.DANGER, 0.30)
	_update_preview(cell, free)


## Hover cue for the plant currently picked in the bar: brackets in the shape
## it will wear once selected, plus the coverage it would have. Affordability
## counts as "blocked" alongside road/occupied — hovering a legal cell you
## cannot pay for should not draw an encouraging green ring.
func _update_preview(cell: Vector2i, free: bool) -> void:
	# Nothing to preview over a plant already there: that cell's own selection
	# marker and range ring are the truthful answer, and stacking a second set
	# of brackets on it reads as a bug.
	if _plants.has(cell):
		_preview.visible = false
		return
	_preview.visible = true
	_preview.position = board.cell_to_world(cell)
	_preview.reach = PlantCatalog.reach(selected_plant)
	# Explicit rather than inferred. PlacementPreview falls back to deducing the
	# kind from `reach`, which works only while no two plants share a radius --
	# a coincidence, not a rule, and the redundant-coverage cue depends on it.
	_preview.plant_id = selected_plant
	# The same predicate _click_at obeys, so the brackets are a promise: green
	# means this click plants. `free` is kept as the caller's override — the
	# self-test suite drives this method with a forced value to pin the blocked
	# rendering — and would_plant_at() recomputes it honestly from the board.
	_preview.placeable = free and would_plant_at(cell)
	# Only a plant that cannot defend itself is "at risk" beside the road. A
	# Corn Cobbler there is the entire point of a Corn Cobbler; flagging it
	# would teach the player to ignore the cue everywhere it matters.
	_preview.at_risk = _preview.reach <= 0.0 and board.is_road_adjacent(cell)
	_preview.queue_redraw()


## One click, up to four things it could mean. The rule, in the sentence a player
## would say it in: **a click that would plant, plants — a husk only takes clicks
## that were never going to plant anything.**
##
## The sweep used to run first and unconditionally, so a husk within
## CompostMeter.COLLECT_RADIUS (28 px, a 56 px target on a 64 px cell) of the
## click ate it, and the player got "Composted a husk" on a cell the preview had
## just drawn as legal, affordable and empty. The preview could not warn about it
## either: it is redrawn on mouse motion, on picking a plant in the bar, and after
## a click — nothing per-frame — while a husk rots on its own 4.5-10 s timer
## (CompostMeter.lifetime_for), so any husk cue would go stale under a still
## cursor. Precedence is the fix; a fourth preview state would have been a picture
## that lies for up to ten seconds at a time.
##
## Harvesting is untouched by the reordering, and provably so rather than
## hopefully so. Pests only ever walk Board.route(), which is one point per road
## cell centre bracketed by two off-board tails, so every husk lands on the road —
## and nothing may ever be planted on the road. A click on a husk therefore always
## sweeps it, because would_plant_at() is false everywhere a husk can be reached
## from. PlacementPreview.husk_click_margin() is that claim as a number, and
## test_placement gates it: today the nearest a husk can come to ground a plant
## may stand on is 32 px, four clear of the 28 px sweep.
func _click_at(screen_pos: Vector2) -> void:
	if screen_pos.y < Hud.BAR_HEIGHT or screen_pos.x > board.board_size().x:
		return
	var local: Vector2 = screen_pos - _entities.position
	var cell: Vector2i = board.world_to_cell(local)
	# Ahead of the is_inside() guard below, exactly where the sweep has always
	# been: Board._build_route brackets the road with an off-board entry and exit,
	# a Corn Cobbler can shoot a pest standing on either, and the husk that drops
	# there belongs to no cell at all. It is still the player's to collect.
	if not would_plant_at(cell):
		var swept: int = compost.collect_at(local)
		if swept > 0:
			bank.add_seeds(swept)
			hud.show_message("Composted a husk for %d seeds." % swept, 2.0)
			return
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
	# The cell under the cursor just changed state — either it now holds a
	# plant, or the purchase drained the seeds that made it affordable. Either
	# way the cue on screen is stale until the mouse moves, which it need not.
	_update_preview(cell, board.is_buildable(cell) and not _plants.has(cell))


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
		"prep_left": _prep_left,
		"prep_total": PREP_SECONDS,
		"more_waves": director.has_more_waves(),
		"next_threat_level": WaveDirector.threat_level(maxi(1, director.current_wave + 1)),
		"lives": lives,
		"selected_plant": selected_plant,
		"selected_placed": selected_placed,
		"uproot_armed": uproot_armed(),
		"plants": _plants.size(),
		"pests_alive": get_tree().get_nodes_in_group("pests").size(),
		"can_start_wave": not _wave_live and director.has_more_waves() and not game_over and not victory,
		"game_over": game_over,
		"victory": victory,
		"endless": director.endless,
		"seeds_earned_total": bank.seeds_earned_total,
		"high_score": RunConfig.best_for(director.endless),
		"compost_total": compost.total_collected,
		"pests_defeated": pests_defeated,
		"run_seconds": run_seconds,
		"husks_on_ground": compost.husk_count(),
		"threat": WaveDirector.threat_for(maxi(1, director.current_wave)),
		"threat_level": WaveDirector.threat_level(maxi(1, director.current_wave)),
	}
