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
## The HUD signal the top bar's speed button rings. Named because it is reached by
## STRING rather than by member access — see the connect in `_ready` for why — and
## a signal name typed twice in two files is a signal name that will be typed
## differently once. `test_the_hud_carries_the_speed_button` asserts this exact
## StringName is on Hud.
const SPEED_SIGNAL := &"speed_requested"

## Every key the run answers to, and what it does — read out of the InputMap, not
## written down here.
##
## A run had four keyboard verbs and no screen named one of them. The only mention
## anywhere was "Press M to bring it back", printed after you had already found M.
## The title screen documents its own three keys in a HintLabel, so the convention
## existed; the run simply did not follow it.
##
## This used to be a hand-written `const KEY_HELP` sitting beside the handler, with
## `test_every_key_the_run_handles_is_named_on_the_pause_card` scanning
## _unhandled_input's own source for KEY_* constants to stop the two drifting
## apart. Now the handler asks the InputMap and so does this, so there is nothing
## left to drift: rebinding pause to F1 relabels the pause card in the same frame.
## The test still runs, and now asserts that every ACTION the handler answers to
## has a row here — the same guarantee one level up.
##
## Rows are {keys, does, codes}, which is the shape PauseScreen._build_key_list
## has always drawn.
static func key_help() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for action: StringName in KeyBindings.actions_in(KeyBindings.SCOPE_RUN):
		out.append({
			"action": action,
			"keys": KeyBindings.label_for(action),
			"does": KeyBindings.describe(action),
			"codes": KeyBindings.keys_for(action),
		})
	return out


## What the HUD says when a mute is toggled. Split out because it is the one line
## of run text that has to name a key: it used to say "Press M", which becomes a
## lie the moment a player rebinds the verb. Static and pure so a test can read
## the sentence without a running game.
static func mute_message(what: String, muted: bool, action: StringName, pronoun: String = "it") -> String:
	if not muted:
		return "%s on." % what
	return "%s off. Press %s to bring %s back." % [what, KeyBindings.label_for(action), pronoun]

var board: Board
var bank: SeedBank
var director: WaveDirector
var hud: Hud
var compost: CompostMeter

var lives: int = LIVES
var selected_plant: StringName = PlantCatalog.CORN
var selected_placed: Plant = null
## The plant the player is comparing FROM: the selection before this one, kept on
## screen with its sole-cover rings demoted so two plants' answers to "what does this
## one alone hold?" can be read side by side (plant-tower-defense-sleq).
##
## WHAT CLEARS IT: selecting a third plant, which drops the oldest. The window is
## exactly two BY CONSTRUCTION rather than by a rule anybody has to learn, so the
## board cannot accumulate rings however long a session runs. Every `_select(null)`
## clears it too -- picking a packet out of the bar, a plant eaten under the cursor,
## an uproot committing -- because all three are moments where the question changed.
## No timer, no key, no modifier: a comparison is read at the player's pace, and a cue
## that needs a keypress to dismiss is one most players will leave up.
var _held_over: Plant = null
var game_over: bool = false
var victory: bool = false

var _entities: Node2D
var _cursor: ColorRect
## The shop entry the cursor is on, &"" for none. Decides which question the
## board's dead-ground marks answer: this plant's, or the whole garden's
## (plant-tower-defense-tzz7 / -g8kc).
var _hovered_shop_plant: StringName = &""
var _preview: PlacementPreview
## Last cell the cursor was over, or x < 0 for "off the board". Kept so the
## preview can be re-drawn on events that are not mouse motion.
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _husk_layer: HuskLayer
var _plants: Dictionary = {}
var _prep_left: float = 0.0
var _wave_live: bool = false
## The weather the current wave arrived under, or CLEAR between waves.
##
## Held by Game rather than read from the director on demand, because the wave
## number moves the instant a wave ends and the weather has to survive until the
## next one starts -- a plant placed in the prep gap after a drought wave must not
## inherit the drought, and one placed during it must.
var weather: StringName = WaveDirector.WEATHER_CLEAR
var _weather_overlay: WeatherOverlay = null
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

## Where the run's seeds actually went, as opposed to how many it earned.
##
## Cycle 101's A/B varied exactly one bit — whether a surplus bought another plant
## or another level on a plant already in the ground. Same economy, no cheats, same
## map. The breadth-first campaign reached eleven level-1 plants and died at wave
## 10; the depth-first one won all 22 waves without losing a bed. That bit is the
## single largest thing a new player gets wrong, and until these two counters
## existed the game wrote down every number about the run EXCEPT the one the run
## was decided by. `seeds_earned_total` is income; nothing recorded outgoings.
##
## SEEDS, not purchase counts. A plant and an upgrade are differently priced, so
## "11 plants, 6 upgrades" reads as a near-balance where the same run's "275 on
## plants, 90 on upgrades" reads as a policy — and seeds are what cycle 101 varied,
## so seeds are what the post-mortem should hand back. They also stay short enough
## for the card's value column at endless magnitudes, which a count-and-price pair
## does not (see RunSummary.spend_text).
##
## GROSS, not net. An uproot refund is not taken back out of `seeds_on_plants`, and
## re-planting the same cob somewhere else charges this a second time. Both are
## right for the question being asked: the player chose breadth with those seeds on
## both occasions, and a "net" number would let a player who churns plants read as
## though they had been spending on depth.
##
## Packets are a THIRD sink and are deliberately in neither total. See
## RunSummary.spend_text — the row names two destinations and never claims they add
## up to everything spent, so a packet is not silently filed under either policy.
var seeds_on_plants: int = 0
var seeds_on_upgrades: int = 0

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
## The escaped half of _wave_losses — same cells, a subset of the counts. Kept
## as a second tally rather than as a flag on the first because the pressure map
## wants the sum and the post-mortem wants the difference, and there is no single
## number that is both. Committed in the same batch; see _commit_lane_pressure.
var _wave_escapes: Dictionary = {}

## How the run's escapes happened, as opposed to how many there were.
##
## The count has always been reported (as beds lost) and the place has always
## been recorded — but the place is a constant. Board._run_escapes documents why:
## every escape is filed against exit_cell(), because an escaped pest's own
## position is off the board by the time `escaped` fires. So two runs that lost
## the same beds left byte-identical evidence however differently they lost them.
##
## This is the one thing an escaping pest knows that the player can act on. A pest
## that reaches the exit having never been touched walked road nothing was aimed at
## — a hole in the coverage, answered by planting more. One that arrives having
## been fought was in range and the damage merely ran out, answered by upgrading
## what is already there or buying it time with a Sundew. Those are opposite
## purchases and nothing else on the card separates them.
##
## The reason, corrected against a measurement (see the coverage block below).
## This used to read "was never in range of anything the whole way down", and that
## is false: Corn shoots only the pest furthest along, so a pest can stand well
## inside a cob's ring for its whole stay on a cell and be passed over for a pest
## further down the road. Every one of the 68 untouched escapes in that sweep had
## walked covered ground at some point. What holds — and what the branch above is
## entitled to — is the weaker claim: every one of them had ALSO walked at least
## one cell nothing could aim at, and no pest that stayed inside covered ground for
## its whole walk ever came out untouched. Untouched still means a hole; it does
## not mean the pest was out of reach the whole way.
##
## `_escapes_recorded` is the denominator and is deliberately NOT `LIVES - lives`:
## an escape whose pest could not be read counts toward neither of these, so the
## card falls back to the bare bed count rather than reporting "all were fought"
## about pests it never saw. See _note_escape.
var _escapes_recorded: int = 0
var _escapes_untouched: int = 0


func _ready() -> void:
	add_to_group("game")
	Music.play_for_scene(scene_file_path)

	# The speed the player chose in their last run (plant-tower-defense-zgzc).
	# Here rather than in RunConfig._ready(), which fires at process start while the
	# TITLE screen is coming up — a saved half speed applied there would slow that
	# scene's own animations for no reason a reader of it could find, and _exit_tree
	# would throw it away on the first exit anyway. The speed is a fact about a RUN.
	# Ahead of the HUD, so the button's face is right on the frame it is built.
	RunConfig.apply_game_speed()

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
	# Placed properly once the board exists; see _apply_board_layout. The value above is
	# the design-size answer and is kept so nothing reads an unset position mid-_ready.

	board = Board.new()
	board.name = "Board"
	_entities.add_child(board)

	# Above the ground and below everything that stands on it. Added to Entities right
	# after the board rather than as a Board child, so husks, plants and pests all draw
	# over it in their existing order and nothing had to learn about weather.
	_weather_overlay = WeatherOverlay.new()
	_weather_overlay.name = "WeatherOverlay"
	_weather_overlay.setup(board.board_size())
	_entities.add_child(_weather_overlay)

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
	# The sound is generic to every refusal, from all four purchase_failed call
	# sites; the shake is not, and lands separately at each site below — see
	# _click_at and _on_packet_requested — because only they know which control
	# the player actually reached for.
	bank.purchase_failed.connect(func(reason: String) -> void:
		hud.show_message(reason)  # message-corpus-check: ok - purchase refusals are assembled by SeedBank at runtime
		Sfx.play(Sfx.PURCHASE_DENIED))
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
	hud.plant_hovered.connect(_on_plant_hovered)
	hud.packet_requested.connect(_on_packet_requested)
	# Through a handler rather than straight onto start_next_wave(), so the
	# mutator underneath stays unguarded for the devtools verb, the prep-timer
	# expiry and the tests — the same split arm_uproot() / commit_uproot()
	# already uses. A wave that arrives because the countdown ran out is not a
	# press and must not click.
	hud.next_wave_requested.connect(_on_next_wave_requested)
	hud.upgrade_requested.connect(upgrade_selected)
	# The button goes through the confirm gate; commit_uproot() stays the unguarded
	# mutator underneath it, which is what the placement tests drive directly (and
	# what a bridge session reaches with `run-method`). No devtools VERB wraps it --
	# see its own header.
	hud.uproot_requested.connect(arm_uproot)
	hud.speed_requested.connect(_on_speed_requested)

	# The playfield's own place in the window, and it has to be re-taken whenever the window
	# changes shape — the HUD reserves a fixed-width panel on the right and a fixed-height
	# bar on top, so what is left for the board moves with the viewport.
	_apply_board_layout()
	get_viewport().size_changed.connect(_apply_board_layout)

	_prep_left = PREP_SECONDS
	_refresh()
	hud.show_message("Plant your free Corn Cobbler on the grass, then grow the first wave.", 8.0)

	# Last, and deliberately here rather than a frame later: the two HUD budgets
	# read StatsRow.size and the readouts' custom_minimum_size, both of which are
	# assigned outright in Hud._build_top_bar() -- which has already run, because
	# add_child() on a node already inside the tree readies its child at once.
	# Waiting for a process frame would buy nothing and would put the warning
	# after the first thing the player sees. See the budgets section below.
	check_budgets()


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
	_apply_aloe_healing(delta)
	_check_wave_cleared()
	if not _wave_live and director.has_more_waves():
		# `delta` is already scaled by Engine.time_scale, so the prep countdown runs
		# at whatever GameSpeed is set to and the HUD's prep strip — which renders
		# `prep_left`/`prep_total` straight out of state() — cannot disagree with it.
		# That is the constraint the speed control had to satisfy and it is satisfied
		# by the strip never having had a clock of its own.
		_prep_left -= delta
		if _prep_left <= 0.0:
			start_next_wave()


## `Engine.time_scale` is engine state and outlives every scene. A run left at 2x
## by a reload, a return to the title, or the window closing would hand its speed
## to whatever came next, with nothing in that scene's code to explain it.
##
## One caller covering every exit, rather than a `reset()` remembered at the three
## sites that leave a run — the fourth site is the one that forgets, and this is a
## defect nobody would look for in the scene they end up in.
func _exit_tree() -> void:
	GameSpeed.reset()


# -- waves ------------------------------------------------------------------


## The "Grow the next wave" button, as opposed to the wave itself.
##
## Every other HUD button already answers its own press: Upgrade rings
## PLANT_UPGRADED or the denial, Uproot rings UPROOT_ARMED, a packet either
## opens or is refused — which is why only this one and the plant bar (see
## _on_plant_chosen) get a press cue, and why a refusal stays PURCHASE_DENIED
## alone rather than becoming a click followed by a buzz.
##
## Note the bell that follows is not a later beat: start_next_wave() reaches
## WaveDirector.wave_started synchronously, so WAVE_STARTED sounds in this same
## frame. BUTTON_PRESSED is trimmed to sit under it (see Sfx.VOLUME_DB) — the
## click of the button, not a second announcement of the wave.
func _on_next_wave_requested() -> void:
	Sfx.play(Sfx.BUTTON_PRESSED)
	start_next_wave()


func start_next_wave() -> bool:
	if game_over or victory or _wave_live or not director.has_more_waves():
		return false
	director.start_next_wave()
	return true


## Puts a wave's weather onto the garden: the fire-rate multiplier onto every plant
## that exists, and rain's heal once, now.
##
## Every plant Game owns, not `get_tree().get_nodes_in_group("plants")` -- a
## tree-global group read would also collect plants belonging to a second Game in
## the same tree, which is exactly what the suite does when two scenes are hosted at
## once. See .claude/skills/godot-test-isolation.
func _apply_weather(next: StringName) -> void:
	weather = next
	var scale: float = WaveDirector.fire_interval_scale_for(next)
	var heal: float = Plant.MAX_HEALTH * WaveDirector.heal_fraction_for(next)
	for key: Vector2i in _plants:
		var plant := _plants[key] as Plant
		if plant == null or not is_instance_valid(plant) or plant.is_destroyed():
			continue
		plant.fire_interval_scale = scale
		if heal > 0.0:
			plant.heal(heal)
	# The banner is the beat and it fades; the overlay is the state and it stays for the
	# whole wave. Both from one place, so a weather that reaches the plants always reaches
	# the ground they stand on -- the failure 99ddc1e named, where the surfaces that
	# DESCRIBE a value are a separate population from the code that uses it.
	if _weather_overlay != null:
		_weather_overlay.set_weather(next)
	hud.show_weather(next)


func _on_wave_started(number: int) -> void:
	_wave_live = true
	_wave_losses = {}
	_wave_escapes = {}
	_apply_weather(WaveDirector.weather_for(number))
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
##
## `escaped` splits the tally without splitting either call site, and both halves
## still count toward the pressure map. What the flag buys is the post-mortem's
## ability to ask "how many of these did this cell actually stop", which the sum
## cannot answer: a cell that let twelve pests walk out reads identically to a
## cell that killed twelve, and the second one is the player's best turret.
func _note_lane_loss(at: Vector2, escaped: bool = false) -> void:
	if not _wave_live:
		return
	var cell: Vector2i = board.world_to_cell(at)
	_wave_losses[cell] = int(_wave_losses.get(cell, 0)) + 1
	if escaped:
		_wave_escapes[cell] = int(_wave_escapes.get(cell, 0)) + 1


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
	# After the losses, always with them, never without: Board.stops_at subtracts
	# one from the other, so an escape batch that landed on a board which never
	# saw the matching loss batch would report negative defending.
	board.record_escapes(_wave_escapes)
	_wave_losses = {}
	_wave_escapes = {}


func _check_wave_cleared() -> void:
	if not _wave_live:
		return
	if director.is_spawning() or not get_tree().get_nodes_in_group("pests").is_empty():
		return
	_wave_live = false
	_prep_left = PREP_SECONDS
	_commit_lane_pressure()
	if director.has_more_waves():
		# The wave that was about to attack got a banner and a bell the instant
		# it started (_on_wave_started); the wave a player just survived was
		# getting a single status-row sentence, quieter than the thing it
		# outlasted. Same weight now, on purpose (plant-tower-defense-d2a).
		Sfx.play(Sfx.WAVE_CLEARED)
		hud.announce_wave_cleared(director.current_wave, director.current_wave_pest_count())
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
##
## The coverage reading outranks the depth comparison in exactly one case, and it
## is a comparison rather than a threshold: when the wave's pests were, on
## average, stopped FURTHER down the road than the garden can reach. That is the
## wave where the hole is the explanation, and it is the only wave where a
## sentence about the hole is news rather than a standing fact restated.
##
## A mean, deliberately, because that is what last_wave_depth() is and Board.depth_of
## argues the case at length: one lucky straggler must not be able to fake it. So a
## wave killed cleanly inside the covered stretch with one escape at the exit still
## reads as a wave that went mostly right, and the line stays on the depth note.
## The coverage line arrives when leaks are the bulk of the losses, which is when
## planting deeper is genuinely the purchase to make.
##
## coverage_note() returns "" for a garden with nothing planted at all, so this
## branch cannot take the line away from the depth note on an empty board — see
## coverage_note_for() for why that silence is correct and not an oversight.
func prep_note() -> String:
	var last_wave: float = board.last_wave_depth()
	if last_wave > coverage_frontier():
		var hole: String = coverage_note()
		if hole != "":
			return hole
	var note: String = Hud.prep_depth_note(last_wave, board.run_depth())
	if note != "":
		return note
	return "Next one grows in %d seconds." % int(PREP_SECONDS)


# -- coverage ---------------------------------------------------------------
#
# Where the garden cannot reach, DERIVED from the board and the plants standing
# on it rather than observed off the pests that walked through it.
#
# The observed version is the one that looks obvious, and it cannot work. A pest
# carries Pest._ever_engaged, which is monotone: the first kernel that lands sets
# it and nothing ever clears it. Sample that flag per road cell and every cell
# after first contact reports "the garden reached here", whatever is or is not
# standing beside it — so the observed map can only ever mark a PREFIX of the
# road, and the two holes that actually cost beds (a gap in the middle, and an
# uncovered run to the exit) are precisely the two it cannot see. It answers "how
# far down the road before something touched them", which this board already has
# a vocabulary for in Board.depth_of, and it answers it at the cost of a per-cell
# recording pass. See test_the_engagement_flag_can_only_ever_mark_a_prefix_of_the_road.
#
# The derived map has none of that. Corn's reach is a known radius from a known
# cell, so the set of road cells nothing can touch is a pure function of the board
# and the placed plants — available DURING play, correct the frame a plant is
# bought or uprooted, and free of any dependency on a pest having walked there.
#
# The two would still disagree, and the disagreement is not one-sided, which is
# what this paragraph used to get wrong. It over-promises in the obvious
# direction: a Corn shoots only the pest furthest along, a Chomp with a full mouth
# grabs nothing, a winged pest is unreachable by one at all. It ALSO under-promises,
# and that half was missed. A Kernel flies until it leaves the board
# (Kernel._physics_process) and kills the first pest it touches whether or not that
# pest was the one aimed at, so a cob's overshoot kills well past its own 176 px
# ring. Driven live: four cobs at the entry, four waves, and 7 kills landed on
# cells this map calls uncovered — (6, 1) and (3, 5), both a clean 200 px and
# 192 px from the nearest cob — against 10 escapes at the exit.
#
# So this is not a bound in either direction. It answers exactly one question and
# it answers it exactly: "is any standing plant in range of this cell". That is
# still the question worth asking, because it is the one a purchase acts on — but
# nothing built on it may be phrased as "nothing could touch them here", and
# LanePressureOverlay's mark is named `unaimed` rather than `unreachable` for that
# reason. See test_a_kernel_can_kill_on_ground_the_coverage_map_calls_unaimed.
#
# The over-promising half has now been MEASURED, and the size of it is the reason
# nothing was built on it. Fourteen driven waves over three gardens (a six-cob
# campaign garden, seven cobs covering all 32 road cells, and nine mouths), 439
# pests, sampled every physics frame:
#
#   * At the CELL, the over-promise is enormous and useless. 3,909 of 4,664 stays
#     on covered ground — 84% — passed with nothing touching the pest. But it
#     reads 66% in a wave that killed 14 of 14 and lost no bed at all, and 88% in
#     one that lost 34 of 40, so it is loud everywhere and quiet nowhere. 82% of
#     it (3,216) is a cob that fired at a DIFFERENT pest during the stay and 14%
#     (555) is one that had this pest picked and had not landed a shot yet: it
#     measures the fire rate and the targeting rule, not ground the garden cannot
#     reach. Three stays in 3,909 were the map's own geometry.
#   * At the PEST — the unit a player acts on — it is zero. 116 pests spent their
#     whole road walk inside covered ground and every one of them was touched,
#     including in runs losing half the wave. All 68 pests that got out untouched
#     had walked at least one cell this map already marks `unaimed`.
#   * The geometry is honest: all 755 answered stays had the pest genuinely inside
#     a covering plant's radius, so the centre-to-centre coverage test never once
#     claimed ground the plant could not actually hold.
#
# The one case that IS a real over-promise is a road cell covered by Chomps alone,
# because a mouth cannot close on a winged pest — and that case needs a garden
# with no Corn in it, since a 176 px ring covers everything a 73.6 px mouth does.
# ONE blind stay in the 3,747 unanswered stays across the eleven runs with Corn in
# the garden; 134 of 162 (83%) in the three chomp-only ones. Corn is the free
# starter and the only damage in the game, so the garden that case needs is a
# garden nobody has.
#
# See test_the_coverage_map_keeps_its_promise_to_a_pest_that_never_leaves_covered_ground,
# test_the_in_reach_and_idle_reading_is_just_as_loud_in_a_wave_the_garden_sweeps and
# test_a_winged_pest_only_outruns_the_map_in_a_garden_with_no_corn_in_it, which
# carries a 31-mouth positive control so the zeros above are a reading and not a
# counter that never fires.


## The plants that can lay a finger on a pest, and the whole list.
##
## Read off Pest._ever_engaged rather than off the catalogue, because those are
## the same two things: a kernel that lands, and a Chomp that holds. A Sticky
## Sundew "deals no damage whatsoever" by its own doc comment — it only slows —
## and a Sunflower never touches a pest at all.
##
## PlantCatalog.reach() answers a DIFFERENT question and answers it with a
## non-zero number for the Sundew, correctly: a patch that touches no road is as
## useless as a cob that can shoot none, and the placement cue should say so
## before the thirty seeds are spent. Usefulness is not coverage. Keeping the two
## apart is the entire reason this list is written out rather than inferred from a
## radius — a road walled in dew is road nothing can touch, and a coverage map
## built on reach() would call it defended.
##
## Listed positively, so a fifth plant reads as non-engaging until somebody says
## otherwise. That is the failure direction that over-reports a hole, and a
## readout that nags is recoverable where one promising coverage it does not have
## costs beds. test_every_plant_that_can_touch_a_pest_is_named_as_one fails when
## the catalogue grows, which is what forces the decision to be made rather than
## defaulted into.
## Kept as the name the coverage code and its tests read, but it is no longer
## the declaration — PlantCatalog.engages() is, one key beside each plant. A
## const cannot call a function, so this is a static rather than a const, and
## every caller goes through it instead of through a list two files from the
## plants it describes.
static func engaging_plants() -> Array[StringName]:
	return PlantCatalog.engaging_ids()

## The longest line the coverage branch can hand the status row, through
## Hud.wave_cleared_line. Same contract as Hud.PREP_NOTE_WORST_CASE and for the
## same reason: MessageLabel clips with an ellipsis, so a line that outgrows the
## row renders trimmed and nothing complains.
##
## The widest reachable frontier is 0.0 — a garden covering the entry cell and
## nothing else, which is not a hypothetical: a lone Chomp Flower on (0, 0) has a
## GRAB_RADIUS of 73.6 px, which reaches the road cell 64 px below it and misses
## the next one at 90.5 px. That reads "the last 100% of the road", and 100 is
## therefore the widest percentage this can print rather than the 97 that counting
## cells suggests. test_the_coverage_note_fits_the_status_row pins this string to
## the formatter and measures it against both the row and Hud's declared worst
## case, so the arithmetic above is checked rather than trusted.
##
## Grew by five characters when "covers" became "is aimed at" — see
## coverage_note_for() for why the wording had to change. The width is measured,
## not assumed, so if that spend ever stops fitting the row the test says so
## rather than the sentence quietly clipping.
const COVERAGE_NOTE_WORST_CASE: String = "Wave 9999 cleared. Nothing is aimed at the last 100% of the road."


## How far a plant of `id` can actually touch a pest, in pixels; 0.0 for one that
## cannot touch one at all.
##
## The engaging kinds return PlantCatalog.reach(id) rather than a second copy of
## the number, so a balance change to CornCobbler.RANGE moves this with it instead
## of leaving a coverage map quoting a radius the cob no longer has.
static func engagement_reach(id: StringName) -> float:
	if not PlantCatalog.engages(id):
		return 0.0
	return PlantCatalog.reach(id)


## The road cells this plant covers that NOTHING else standing covers — what the
## garden would lose if it were uprooted (plant-tower-defense-nx9o).
##
## The mirror of PlacementPreview.new_cover_cells(), which answers the same
## question about a plant not bought yet. Both exist because a range ring is
## identical whether it is the only thing holding that road or one of three, and
## cycle 54 measured that difference as decisive: five cobs covering all 32 road
## cells lose a pest where seven covering the same 32 do not.
##
## Empty is a real answer and NOT a suggestion to uproot: it means everything this
## plant reaches is backed up, which on a stretch that needs depth is exactly the
## purchase that was wanted. It is the answer to "can I move this one?", not to
## "should I?".
func sole_cover_cells(plant: Plant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if board == null or not is_instance_valid(board):
		return out
	if plant == null or not is_instance_valid(plant) or plant.is_destroyed():
		return out
	var reach: float = engagement_reach(plant.kind)
	if reach <= 0.0:
		return out
	# "Everything except this plant" is covered_road_cells(except) exactly. This was
	# a second copy of that loop, written before the parameter existed; the two
	# agreed on every rule, which is precisely why the duplication was easy to keep
	# and would have been easy to break. One of them is enough.
	var others: Dictionary = covered_road_cells(plant)
	for cell: Vector2i in PlacementPreview.covered_road_cell_list(board, plant.cell, reach):
		if not others.has(cell):
			out.append(cell)
	return out


## Every road cell a pest could stand on right now with nothing in the garden able
## to touch it — the coverage-hole map, in walk order.
##
## Empty is the honest answer for a board that cannot be read, and it is also the
## answer for a perfectly covered road. The two are told apart by
## coverage_frontier(), which returns -1.0 for the first and 1.0 for the second.
func uncovered_road_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if board == null or not is_instance_valid(board):
		return out
	var covered: Dictionary = covered_road_cells()
	for cell: Vector2i in board.road_cells():
		if not covered.has(cell):
			out.append(cell)
	return out


## The other half: road cell -> true for every cell something can reach. A
## Dictionary rather than an Array because every caller here is asking `has`, and
## the union across four plants is what makes it a set in the first place.
##
## Goes through PlacementPreview.covered_road_cell_list rather than re-deriving
## the distance test, so this map and the dead-ground cue on the hover preview
## cannot disagree about which road a plant reaches. A destroyed plant is skipped:
## a hungry pest that ate the cob took its coverage off the board with it.
## `except` leaves one plant out of the answer — "what would the garden cover
## WITHOUT this one". Two callers want that and they want it for the same reason:
## sole_cover_cells() asks what a plant uniquely holds, and the move preview asks
## what a plant would newly defend somewhere else, which is a question about the
## garden it is leaving behind.
##
## Default null keeps the plain reading, which is what every other caller wants.
func covered_road_cells(except: Plant = null) -> Dictionary:
	var covered: Dictionary = {}
	if board == null or not is_instance_valid(board):
		return covered
	for key: Vector2i in _plants:
		var plant := _plants[key] as Plant
		if plant == null or not is_instance_valid(plant) or plant.is_destroyed():
			continue
		if except != null and is_instance_valid(except) and plant == except:
			continue
		var reach: float = engagement_reach(plant.kind)
		if reach <= 0.0:
			continue
		for road: Vector2i in PlacementPreview.covered_road_cell_list(board, plant.cell, reach):
			covered[road] = true
	return covered


## How far down the road the garden can reach: 0.0 when only the entry cell is
## covered, 1.0 when the exit cell is, and -1.0 when nothing standing can touch
## any road at all.
##
## The road is one snake — Board.depth_of makes the argument, and PATH_CORNERS
## traces a single path from (0, 1) to (13, 7) — so "where does the garden stop
## reaching" has exactly one spatial degree of freedom and this is it. Everything
## past this point is a free walk to the exit, which is the reading a player can
## act on: plant deeper, rather than plant more.
##
## Deliberately the DEEPEST covered cell and not the covered count. A garden with
## a hole in the middle and a plant at the exit has a frontier of 1.0 and nothing
## to warn about on this reading — a pest crossing that hole is shot before it and
## shot after it. The count is what uncovered_road_cells() is for.
##
## -1.0 rather than 0.0 for "nothing covered", for the same reason Board.depth_of
## returns it: a garden that covers exactly the entry cell genuinely reads 0.0, and
## a caller that could not tell it from an empty board would describe one as the
## other.
func coverage_frontier() -> float:
	if board == null or not is_instance_valid(board):
		return -1.0
	var last: int = board.path_cell_count() - 1
	if last <= 0:
		return -1.0
	var deepest: int = -1
	for cell: Vector2i in covered_road_cells():
		deepest = maxi(deepest, board.path_index(cell))
	if deepest < 0:
		return -1.0
	return float(deepest) / float(last)


## The sentence, for the garden standing right now.
func coverage_note() -> String:
	return coverage_note_for(coverage_frontier())


## Pure: the sentence for a frontier. Split out so the worst case above can be
## pinned to the formatter rather than to a literal somebody has to remember to
## re-copy, and so every branch is assertable without a board.
##
## Silent for a frontier below 0.0, which is a garden with nothing planted that
## can fight. That is not a hole in the coverage, it is the absence of a garden,
## and the empty board says it louder than a percentage could — while a line
## claiming "the last 100% of the road" on an empty field is a statistic standing
## in for something the player can already see.
##
## Silent again at 1.0, where the garden reaches the exit cell and there is no
## tail at all, and silent for anything that rounds to a 0% tail, because a
## readout that says zero reads as a broken measurement rather than as good news.
## "Aimed at", not "covers". The word matters and the measurement says so.
## Kernel._physics_process flies until the kernel leaves the board and kills the
## first pest it touches, aimed at or not — 7 kills were measured on unaimed
## ground, at 202 px and 192 px from the nearest cob, well outside its 176 px
## ring. So "nothing covers it" is false: things die there. What is true is that
## no plant has that stretch in reach, which is still the reading a purchase acts
## on, and it is the same word the board's own mark uses (`unaimed`, never
## `unreachable`). A player told "nothing covers" over-buys cover for ground that
## is already taking kills.
static func coverage_note_for(frontier: float) -> String:
	if frontier < 0.0 or frontier >= 1.0:
		return ""
	var tail: int = int(round((1.0 - frontier) * 100.0))
	if tail <= 0:
		return ""
	return "Nothing is aimed at the last %d%% of the road." % tail


## Puts one pest on the road immediately. The wave director drives this; the
## devtools `spawn_pest` verb uses it to stage a single bug without a whole
## wave. `mutation` is &"" outside wave 8+ or for a manually staged pest.
func spawn_pest(species: StringName, mutations: Array = []) -> void:
	var pest: Pest = _new_pest(species)
	for which: StringName in mutations:
		# Return value deliberately ignored: `apply_mutation` refuses a pair that does not
		# compose, and WaveDirector already asked `Pest.mutations_compose` before rolling
		# one. A refusal here means those two disagree, which is a bug in the rule rather
		# than a case to handle at the spawn site -- and the pest is still a valid pest.
		pest.apply_mutation(which)


## One pest on the road at the entrance, wired up and scaled for the wave in
## progress. The single constructor both spawn_pest() and _spawn_brood() go
## through, so a pest that arrives because a boss burst is the same object, on
## the same route, with the same signals, as one the wave director asked for —
## the alternative is two spawn paths and a brood that quietly stops paying
## seeds or stops costing a bed.
func _new_pest(species: StringName) -> Pest:
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
	pest.died.connect(_on_pest_died)
	pest.escaped.connect(_on_pest_escaped)
	return pest


## How far from the death point the brood is scattered before it re-forms on the
## road. Purely legibility: three pests stacked on one pixel read as one pest,
## and the whole point of the mechanic is that the player SEES the boss become
## three things. Well inside half a cell (32 px), so every one of them is still
## on the road cell its parent died on and the lane-pressure tally, the husk
## drop and the coverage map all still file them where they actually are.
const BROOD_SPREAD: float = 14.0


## The boss mechanic: a pest whose species names a split bursts into that many
## smaller ones AT THE SPOT IT FELL rather than simply leaving the board.
##
## Hung off `died` and nothing else, which is the whole design. An escaped queen
## does NOT burst — she is already off the board and has taken her bed; three
## more aphids materialising past the exit would be a punishment with nowhere to
## walk. So the only way to see the brood is to kill her, and the only question
## the player controls is where. Kill her at the gate and the three aphids have
## the entire road left to be shot on; kill her at the last corner and they have
## seconds. That is a decision about placement that nothing else on this board
## asks for, and it is deliberately not "armoured, but more".
##
## Not spawned once the run is over: _on_pest_escaped clears the pest group the
## instant the last bed goes, and a brood arriving after that would repopulate a
## board the player has already lost and keep the wave alive behind the card.
func _spawn_brood(parent: Pest) -> void:
	if game_over or victory:
		return
	var species: StringName = Pest.split_species(parent.species)
	var count: int = Pest.split_count(parent.species)
	if species == &"" or count <= 0:
		return
	var at: Vector2 = parent.position
	var leg: int = parent.route_leg()
	for i: int in range(count):
		var child: Pest = _new_pest(species)
		child.enter_road_at(at + Vector2(BROOD_SPREAD, 0.0).rotated(TAU * float(i) / float(count)), leg)


func _on_husk_collected(value: int, at: Vector2) -> void:
	Sfx.play(Sfx.HUSK_COLLECTED)
	# `at` is board-local (Entities' own space, same as pest.position); the
	# Seeds label it is flying toward lives on Hud's CanvasLayer. to_global()
	# is the one line that crosses that gap — see SeedGlyph's own header for
	# why nothing on the board side needs more than this.
	if hud != null and is_instance_valid(hud):
		hud.fly_seed_glyph(_entities.to_global(at), value)
	_refresh()


## The cue for a husk nobody swept. No _refresh(): a rotted husk changes nothing
## the HUD reads except `husks_on_ground`, which the next frame's refresh picks
## up anyway — and a rot storm at the end of a wave must not rebuild the bar once
## per husk.
func _on_husk_rotted(_value: int) -> void:
	Sfx.play(Sfx.HUSK_ROTTED)


## A pest's seed value under the current weather, rounded and never below 1.
##
## Public and pure so the economy is assertable without killing anything, and so the
## HUD could quote it later without duplicating the arithmetic.
func weather_seed_value(base: int) -> int:
	return maxi(1, int(round(float(base) * WaveDirector.seed_multiplier_for(weather))))


func _on_pest_died(pest: Pest) -> void:
	# Played here, not in Pest, on purpose: Pest._play_death() queue_frees the
	# node DEATH_LINGER seconds later, and a freed node cannot finish a sound.
	# Sfx's pool sits under the scene tree root, so nothing on the board owns it.
	# A harder kill sounds like one. The threshold is the pest's OWN price rather than a
	# list of which mutations count: husk_multiplier() is already the game's answer to "how
	# much did this cost to deal with", it multiplies across a doubly-mutated pest, and
	# reading it here means a fourth mutation is audible the day it is added without anyone
	# editing this line (plant-tower-defense-tgoc).
	Sfx.play(Sfx.kill_event_for(pest.husk_multiplier()))
	pests_defeated += 1
	_note_lane_loss(pest.position)
	# Scaled by the weather this wave arrived under: a drought pays more, because it
	# cost more to get here (plant-tower-defense-4c1l). Applied to the direct seeds
	# only -- the husk below already carries husk_multiplier(), and scaling both would
	# pay the weather bonus twice for one kill.
	bank.add_seeds(weather_seed_value(pest.seed_value))
	# Half again, as a husk — collectible for a bonus, or left to rot. See
	# CompostMeter: this is what makes "sweep the field" worth doing. Scaled by
	# husk_multiplier() so a harder kill (a mutation) pays out more, tying the
	# mutation and compost systems together instead of leaving them side by side.
	var husk_value: int = CompostMeter.husk_value_for(pest.seed_value, pest.husk_multiplier())
	compost.drop_husk(pest.position, husk_value)
	# Last, after the seeds and the husk this kill earned: the brood is the
	# consequence of the kill, not part of paying for it, and a player who kills
	# a queen at the exit should still be holding her 40 seeds while the three
	# aphids she left walk out.
	_spawn_brood(pest)


## Files what the escaping pest knew about its own walk — if there is a pest to
## ask, which there frequently is not.
##
## The guard is the whole point of splitting this out rather than reading `pest`
## inline. _on_pest_escaped is called with null by the tests that stage a losing
## run without putting bugs on the board, and an unguarded deref there would
## raise inside a test method — which aborts only that method and returns "",
## which the runner cannot tell from a pass. So the tolerance is a named,
## readable branch instead of an assumption.
##
## A null escape is counted in neither tally, not counted as "fought". An
## unobserved pest is not evidence of a pest that was engaged, and the card's
## fallback branch exists precisely so it never has to pretend otherwise.
func _note_escape(pest: Pest) -> void:
	if pest == null or not is_instance_valid(pest):
		return
	_escapes_recorded += 1
	if not pest.was_engaged():
		_escapes_untouched += 1


func _on_pest_escaped(pest: Pest) -> void:
	# Before the lives arithmetic below: losing the last bed calls _end_run in the
	# same breath, and _end_run builds the card out of summary_stats(). A read
	# filed after that point would be missing from the run that ended on it.
	_note_escape(pest)
	# An escaped pest is past the exit and off the board, so its own position
	# is not a road cell and would be dropped. Attribute it to the last cell of
	# the road instead — which is also the honest reading: that is where the
	# lane finally failed. Deliberately not conditional on `pest`; the tests
	# and the losing-escape path both call this with null, and the bed still
	# counts. _note_escape above is the only part that needs a real pest, and it
	# says so by returning rather than by guarding the whole handler.
	_note_lane_loss(board.cell_to_world(board.exit_cell()), true)
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
	# The run is over, so the speed the player picked for it is over too — and the
	# post-mortem card built ten lines down animates, on the same doubled clock the
	# pause card is protected from. `reset()` rather than `hold()`: there is nothing
	# left in THIS run to come back to.
	#
	# It no longer follows that a restart starts at 1x, and that clause used to be
	# here: since plant-tower-defense-zgzc the choice lives on disk, so a restart goes
	# _exit_tree -> _ready -> RunConfig.apply_game_speed() and comes back at the
	# remembered speed. The reset is still right — what it protects is the card's own
	# animation, not the next run.
	GameSpeed.reset()
	# Behind the idempotency guard rather than at the top of _end_run: both end
	# paths can be reached twice in a frame, and the run-ender is the one cue in
	# the game long enough for a doubled play to be audible as a doubled play.
	Sfx.play(Sfx.RUN_WON if victory else Sfx.RUN_LOST)
	# Not a scene change, so play_for_scene has nothing to key off -- the run
	# ending is the direct-override case SCENE_TRACKS' own doc comment names.
	Music.play_title()
	var stats: Dictionary = summary_stats(new_record)
	# Behind the same guard as the card, and evaluated against `stats` rather than
	# against Game, so the flags a run files and the numbers its post-mortem prints
	# are read from one snapshot and cannot disagree. `record_milestones` returns
	# only what is new, which is the one thing that stops being knowable the instant
	# it is written down.
	stats["new_milestones"] = RunConfig.record_milestones(Milestones.earned_by(stats))
	_summary = RunSummary.build(stats)
	_summary_layer = CanvasLayer.new()
	_summary_layer.name = "SummaryLayer"
	# Above the HUD's layer 10, or the side panel draws over the card.
	_summary_layer.layer = 20
	add_child(_summary_layer)
	# Same reason as the pause card, and the run is over so there is no re-enabling:
	# the post-mortem's backdrop stops the mouse and does not touch focus, and the HUD
	# is on its own CanvasLayer where nothing else can reach it
	# (plant-tower-defense-csrc).
	if hud != null and is_instance_valid(hud):
		hud.set_active(false)
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


## The top bar's speed button, as opposed to the speed itself.
##
## Same split as `_on_next_wave_requested` / `start_next_wave`: the press pays for
## the click cue, the mutator underneath stays unguarded for the keyboard verb, the
## tests and the bridge. A speed change that happened because somebody pressed F
## must not sound like a button.
func _on_speed_requested() -> void:
	Sfx.play(Sfx.BUTTON_PRESSED)
	cycle_speed()


## Advances the garden's playback speed one step and redraws the button that says
## so. Returns the speed now running, so a caller does not have to ask twice.
##
## Deliberately does NOT reset between waves. A player who asked for a faster
## garden asked about the run, not about this wave, and a control that quietly puts
## itself back every 20 seconds is one the player has to keep re-pressing — the prep
## gap, an 18-second countdown with nothing to do in it, is where fast-forward is
## wanted most. It resets on the run ENDING (`_end_run`) and on leaving the scene
## (`_exit_tree`), and parks at 1x for the pause card (`pause_run`); those are the
## three places the speed stops being about a run in progress.
func cycle_speed() -> float:
	var now: float = GameSpeed.cycle()
	# The step, not the scale: `step()` is what survives a hold and what the save
	# records. Writes only on an actual change, so a full lap of the button is one
	# write and not three — see RunConfig.store_game_speed.
	RunConfig.store_game_speed(GameSpeed.step())
	# Immediately rather than at the next state change: nothing else on the top bar
	# has to move for the button's own face to be wrong, and a speed toggle whose
	# readout lags a press is a toggle the player presses twice.
	_refresh()
	return now


## Holds the run still. The prep countdown, the wave spawner, every plant timer
## and every pest all live on the paused tree, so one flag stops all of them --
## which is the point: a hand-rolled "paused" bool would have to be checked in
## eight places and would be forgotten in the ninth.
func pause_run() -> void:
	if _pause_screen != null and is_instance_valid(_pause_screen):
		return
	_pause_screen = PauseScreen.build(pause_note(), key_help())
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
	# The HUD is on its own CanvasLayer and is therefore nobody's child -- the pause
	# card can make its OWN buttons inert and cannot reach these. Focus does not care
	# what is drawn on top, so without this a Tab from the pause card walks onto a
	# plant button behind it (plant-tower-defense-csrc).
	if hud != null and is_instance_valid(hud):
		hud.set_active(false)
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
	# THE PAUSE CARD READS AT 1x. Its fades run on the paused tree — that is the
	# whole point of the PROCESS_MODE_ALWAYS four lines up — and `Engine.time_scale`
	# scales a Tween whether or not the tree is paused, so a run held at 2x would
	# dissolve its own card in half the time it was tuned for. `hold()` parks the
	# player's choice rather than discarding it; `resume_run` puts it back.
	#
	# After the connects, before `paused = true`, so the card is built and wired at
	# the speed it will be drawn at.
	GameSpeed.hold()
	get_tree().paused = true


## Awaits the card's own fade before freeing it — see PauseScreen.play_exit.
## The tree stays paused for the whole fade: PauseScreen sets itself
## PROCESS_MODE_ALWAYS in _ready, so its tween still advances, and unpausing
## first would let the board come back to life while its own pause card is
## still dissolving on top of it.
func resume_run() -> void:
	# Before the fade, not after: the Options screen over the pause card can flip
	# the colourblind ramp, and the board behind the card is still drawn on the
	# palette it had when the run was held. Repainting here means the bars are
	# already right in the frames the card is dissolving over. Cheap and idempotent
	# on the common path where nothing changed — see repaint_for_palette.
	repaint_for_palette()
	if _pause_screen != null and is_instance_valid(_pause_screen):
		await _pause_screen.play_exit()
	# AFTER the fade, not before: play_exit() is the card's own tween and it is the
	# last thing that has to run at 1x. Restoring the player's speed here means the
	# frame the board comes back to life on is the first one that is sped up, which
	# is the frame they asked for it on.
	GameSpeed.release()
	get_tree().paused = false
	if _pause_layer != null and is_instance_valid(_pause_layer):
		_pause_layer.queue_free()
	_pause_layer = null
	_pause_screen = null
	# Live again. After the layer is gone rather than before, so there is no frame
	# where both the card and a focusable HUD are on screen.
	if hud != null and is_instance_valid(hud):
		hud.set_active(true)


## True while the run is held. Read by the tests; the tree's own `paused` is the
## single source of truth, so this never disagrees with it.
func is_paused() -> bool:
	return get_tree().paused


## Everything the post-mortem card reports. Split out from _end_run so a test can
## assert the numbers without building the Control, and so the panel takes a plain
## Dictionary rather than reaching into Game for each field.
func summary_stats(new_record: bool) -> Dictionary:
	var worst: Vector2i = board.worst_run_cell()
	var stopped: Vector2i = board.worst_stop_cell()
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
		# The run's own policy, read off the run rather than recomputed from the
		# price table afterwards — a board of eleven cobs at the end says nothing
		# about what was uprooted, what a packet cost, or which cob was free.
		#
		# Always written, both of them, so `0` on the card means the run genuinely
		# spent nothing there. That is why spend_text needs no absent-value sentinel
		# where _compost_text does: an unrecorded denominator and a perfect sweep
		# read the same, but an unrecorded spend and a spend of nothing do not.
		"seeds_on_plants": seeds_on_plants,
		"seeds_on_upgrades": seeds_on_upgrades,
		# The peak of the painted map, kept because the map is painted from it and
		# the two must agree about which cell is reddest. Not what the card's row
		# names — see below, and Board.worst_stop_cell.
		"worst_cell": worst,
		"worst_cell_losses": int(board.run_losses().get(worst, 0)),
		# The cell that stopped the most pests for good, and how many. Escapes are
		# already reported, as beds lost, one row above; counting them a second
		# time here is what let the exit cell win a row headed "weakest ground"
		# and point the player at ground that was never defended in the first place.
		"stop_cell": stopped,
		"stop_cell_stops": board.stops_at(stopped),
		# How the beds went, not just how many. Both are 0 for a run whose escapes
		# carried no pest to read, and RunSummary.beds_text treats that as "no
		# evidence" rather than as "every one of them was fought".
		"escapes_recorded": _escapes_recorded,
		"escapes_untouched": _escapes_untouched,
		# The coverage half of "covered is not engaged", read off the same derived
		# map the hover cue and the lane overlay use rather than recomputed, so the
		# card cannot disagree with the board about which ground was aimed at.
		# RunSummary.reach_note_text() is silent without both of these
		# (plant-tower-defense-b7v5).
		"road_aimed": covered_road_cells().size(),
		"road_cells": board.road_cells().size(),
	}


# -- placement --------------------------------------------------------------


## Picking a plant out of the bar. The other press with nothing of its own: a
## selection pays nothing and places nothing, so until PLANT_PLACED rings on the
## board — several seconds and one aimed click later — the bar answered a click
## with silence. This is the only route in; there is no keyboard shortcut for
## selecting a plant, so the cue cannot fall out of step with a second path.
func _on_plant_chosen(id: StringName) -> void:
	Sfx.play(Sfx.BUTTON_PRESSED)
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

## The board's dead-ground marks, repushed. One question at a time: with a shop
## entry hovered the board answers about THAT plant (tzz7); with nothing hovered it
## answers about the garden the player already owns (g8kc). Never both, which is why
## board_dead_cells() returns one list rather than two -- two bars on that angle is
## PlacementPreview's redundant-patch cue, a different sentence.
func _refresh_dead_ground() -> void:
	if board == null or not is_instance_valid(board):
		return
	board.mark_dead_ground(
		PlacementPreview.board_dead_cells(board, _hovered_shop_plant, bank.unlocked),
		PlacementPreview.dead_bar_arm(),
		PlacementPreview.board_dead_color(),
		PlacementPreview.DEAD_BAR_WIDTH)


## The board's deferred-road bars, repushed. See PlacementPreview.deferred_road_cells
## for what "deferred" means and why it is a static property of the garden's SHAPE
## rather than a live read of what each gun is currently shooting at.
##
## The guns go in as two parallel lists rather than as the Game itself, because a
## PlacementPreview naming Game back would be a cyclic class_name reference -- the
## same seam _refresh_dead_ground() takes `bank.unlocked` across. The filter is
## covered_road_cells()' filter exactly: standing, not destroyed, engagement_reach
## above zero.
func _refresh_deferred_road() -> void:
	if board == null or not is_instance_valid(board):
		return
	var gun_cells: Array[Vector2i] = []
	var gun_reaches := PackedFloat32Array()
	for key: Vector2i in _plants:
		var plant := _plants[key] as Plant
		if plant == null or not is_instance_valid(plant) or plant.is_destroyed():
			continue
		var reach: float = engagement_reach(plant.kind)
		if reach <= 0.0:
			continue
		gun_cells.append(plant.cell)
		gun_reaches.append(reach)
	board.mark_deferred_road(
		PlacementPreview.deferred_road_cells(board, gun_cells, gun_reaches),
		PlacementPreview.DEFERRED_BAR_ARM,
		PlacementPreview.deferred_road_color(),
		PlacementPreview.DEFERRED_BAR_WIDTH)


## Applied straight away rather than left for the next _refresh(), for the reason
## Hud._on_packet_hover spells out: a mouse crossing a button changes no state, so
## waiting for a refresh would light the board only when something else happens to
## happen, which is indistinguishable from a bug.
func _on_plant_hovered(id: StringName) -> void:
	if id == _hovered_shop_plant:
		return
	_hovered_shop_plant = id
	_refresh_dead_ground()

func _select(plant: Plant) -> void:
	var previous: Plant = selected_placed
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
	# AFTER the assignment, because _apply_held_over asks whether a plant is the live
	# selection before it hides anything. Exactly one previous selection is kept, and
	# only when the selection actually moved to ANOTHER plant: re-clicking the plant
	# already selected must not drop the one it is being compared against.
	if plant == null:
		_hold_over(null)
	elif previous != null and previous != plant:
		_hold_over(previous)



## Moves the held-over slot, which holds exactly one plant. Idempotent.
func _hold_over(plant: Plant) -> void:
	if _held_over == plant:
		return
	_apply_held_over(_held_over, false)
	_held_over = plant
	_apply_held_over(_held_over, true)


## Turns the demoted look on or off on one plant's two cue nodes.
##
## The marker is reached by node name for the reason `_push_uproot_clock` spells out:
## `SelectionMarker.NODE_NAME` is documented as exactly this contract. A plant built
## outside a Game has neither node, which is a silent no-op here as it is there.
##
## `live` guards the hiding half. A held plant RE-selected passes through here with
## `held = false` on the same frame it becomes the selection, and emptying its marks
## then would blank the rings the player just clicked for.
func _apply_held_over(plant: Plant, held: bool) -> void:
	if plant == null or not is_instance_valid(plant):
		return
	var live: bool = plant == selected_placed
	var marker := plant.get_node_or_null(
		NodePath(SelectionMarker.NODE_NAME)) as SelectionMarker
	if marker != null:
		marker.set_held_over(held)
		marker.visible = held or live
	var marks: SoleCoverMarks = plant.sole_cover_marks()
	if marks != null:
		marks.set_held_over(held)
		marks.visible = held or live
		if not held and not live:
			marks.set_points(PackedVector2Array())


## One plant's sole-cover rings, pushed from the garden as it now stands. Lifted out of
## _refresh() because there are two of them now -- the selection and the plant held
## over beside it -- and two copies of this loop is where the two would start
## disagreeing.
func _push_sole_cover(plant: Plant) -> void:
	if plant == null or not is_instance_valid(plant):
		return
	var marks: SoleCoverMarks = plant.sole_cover_marks()
	if marks == null:
		return
	var at: PackedVector2Array = PackedVector2Array()
	for cell: Vector2i in sole_cover_cells(plant):
		# GLOBAL, because SoleCoverMarks._draw hands these to to_local().
		# cell_to_world is board-local and the marks drew 72 px high for it.
		at.append(board.cell_to_global(cell))
	marks.set_points(at)


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
	# Priced BEFORE the charge, and this order is load-bearing: pay_for_plant()
	# clears `free_starter_available` on the way through, so asking the bank what
	# this cost after it had been paid for would bill the one free cob at full
	# price. Read first, charge, then bank the number the charge actually used.
	var price: int = bank.placement_cost(id)
	if not bank.pay_for_plant(id):
		return "not paid for"
	# The free starter really does add 0, which is the truth: a run that planted
	# nothing but its free cob spent nothing on breadth.
	seeds_on_plants += price
	var plant: Plant = _new_plant(id)
	_entities.add_child(plant)
	plant.setup(id, cell, board)
	_plants[cell] = plant
	Sfx.play(Sfx.PLANT_PLACED)
	plant.destroyed.connect(_on_plant_destroyed)
	if plant.has_signal("grew_seeds"):
		# Bound here rather than added to Sunflower's own signal. What a plant
		# knows about its payout is the amount; where on the board that happened
		# is the plant itself, which Game already has in hand — the same split as
		# `destroyed(plant)`, where the handler reads `plant.cell` off the subject
		# instead of the signal carrying a copy of it. It also keeps the
		# duck-typed contract above at one argument, so a future economy plant
		# only has to emit a number to be wired up.
		plant.connect("grew_seeds", _on_plant_grew_seeds.bind(plant))
	# Duck-typed for the same reason as `grew_seeds` above: only ChompFlower declines a
	# pest for flying, and a second plant that ever does gets wired by declaring the
	# signal rather than by editing this list.
	if plant.has_signal("flight_ignored"):
		plant.connect("flight_ignored", _on_flight_ignored)
	# A plant bought DURING a drought wave inherits it. Without this the way to beat
	# a drought would be to plant into it, which is the opposite of what the weather
	# is for -- and it would only ever be discovered by a player who tried it.
	plant.fire_interval_scale = WaveDirector.fire_interval_scale_for(weather)
	_select(plant)
	_refresh()
	return ""


## A Chomp is being walked past by something it cannot catch, and until now said so with
## nothing at all. One sentence, once ever.
##
## The hint is spent on `show_message`'s RETURN VALUE, not on this handler running. That
## is the whole point of the two-door contract: the row drops a line when its queue is
## full and the new entry is the lowest priority, so "I called show_message" and "the
## player read it" are different facts. A dropped line leaves the hint owed, and the next
## winged pest to cross a Chomp's reach is a fresh edge that offers it again.
##
## MESSAGE_NORMAL, not a deadline: nothing is counting down. The player has as long as
## the wave to act on it, and a higher priority would let a one-shot tutorial line stomp
## a lives-lost readout.
func _on_flight_ignored() -> void:
	if RunConfig.has_milestone(RunConfig.HINT_CHOMP_IGNORES_FLIGHT):
		return
	var posted: bool = hud.show_message(Hud.flight_tip())
	RunConfig.spend_hint(RunConfig.HINT_CHOMP_IGNORES_FLIGHT, posted)


## The cheapest plant on the board the player could upgrade right now, or null when
## nothing there has a rung left to climb.
##
## Static and taking the collection, rather than reading `_plants` itself, because
## everything interesting about it is decidable with no tree, no HUD and no bank —
## see `.claude/skills/extract-a-testable-seam`. `_maybe_teach_upgrading` below is
## the one line that supplies the argument.
##
## `can_upgrade()` and not `has_upgrades()`: the second is true of a Corn Cobbler
## sitting at the top of its ladder, which is a plant the player cannot spend a seed
## on. Asking the wrong one of those two would fire this hint at somebody whose only
## upgradable plant is already finished, which is the one case where the advice is
## actively wrong.
static func cheapest_upgrade(plants: Array) -> Plant:
	var best: Plant = null
	for entry: Variant in plants:
		var plant := entry as Plant
		if plant == null or not is_instance_valid(plant) or plant.is_destroyed():
			continue
		if not plant.can_upgrade():
			continue
		if best == null or plant.upgrade_cost() < best.upgrade_cost():
			best = plant
	return best


## Teaches, once ever, that a plant already in the ground can be upgraded.
##
## WHY THIS FIRES ON A BANK BALANCE AND NOT ON A TIMER OR AT STARTUP: cycle 101's A/B
## showed upgrading decides the run, and the bead that filed it (-gz53) asked for the
## prompt to be tied to a state where the advice is ACTIONABLE. That state is exactly
## "the player is holding at least what the cheapest upgrade on their own board
## costs" — before it, the tip is a rule they cannot use; at it, it is a decision
## they can make this second. A hint fired at a moment the player cannot act on it is
## worse than none, because it spends the message row AND the attention (-qoil).
##
## Called from `_refresh`, which is the funnel every purchase, uproot, plant death
## and wave change already runs through — so the moment the balance crosses is
## caught wherever it happens, rather than in the four call sites that can move it.
## The `has_milestone` guard is first and returns before the sweep, so the cost after
## the hint has been seen once, forever, is one dictionary lookup.
##
## Spent on `show_message`'s RETURN, like the flight tip: the row drops a line when
## its queue is full, and "I called show_message" is not "the player read it". A
## dropped line leaves the hint owed and the next refresh offers it again.
func _maybe_teach_upgrading() -> void:
	if hud == null or not is_instance_valid(hud):
		return
	if RunConfig.has_milestone(RunConfig.HINT_UPGRADE_EXISTS):
		return
	# Ask before offering. This caller is LEVEL-triggered — affordability stays true
	# once it becomes true — so a refused post is not a one-off here the way it is for
	# the flight tip: the next refresh would offer it again and stack a second copy
	# into the row's queue. See Hud.row_is_quiet, which exists for this.
	if not hud.row_is_quiet():
		return
	var cheapest: Plant = cheapest_upgrade(_plants.values())
	if cheapest == null or bank.seeds < cheapest.upgrade_cost():
		return
	var posted: bool = hud.show_message(
		Hud.upgrade_tip(PlantCatalog.display_name(cheapest.kind), cheapest.upgrade_cost()))
	RunConfig.spend_hint(RunConfig.HINT_UPGRADE_EXISTS, posted)


func _new_plant(id: StringName) -> Plant:
	match id:
		PlantCatalog.CHOMP:
			return ChompFlower.new()
		PlantCatalog.SUNFLOWER:
			return Sunflower.new()
		PlantCatalog.SUNDEW:
			return StickySundew.new()
		PlantCatalog.DANDELION:
			return Dandelion.new()
		PlantCatalog.MINT:
			return Mint.new()
		PlantCatalog.NETTLE:
			return Nettle.new()
		PlantCatalog.ALOE:
			return Aloe.new()
		_:
			return CornCobbler.new()


## A hungry pest (Pest.is_hungry) ate this plant down to 0 health instead of
## walking past it. No refund — see commit_uproot() for the "sold on
## purpose" path, which is the only one that pays anything back.
func _on_plant_destroyed(plant: Plant) -> void:
	if _plants.get(plant.cell) == plant:
		_plants.erase(plant.cell)
	if selected_placed == plant:
		_select(null)
	Sfx.play(Sfx.PLANT_DESTROYED)
	hud.show_message(Hud.eaten_message(PlantCatalog.display_name(plant.kind)), 4.0)
	plant.play_exit_and_free()
	_refresh()


## A Sunflower's payout, given the same two channels a swept husk already had
## (see _on_husk_collected): a cue, and a glyph that carries the number from the
## thing that produced it to the readout it lands in. Without them the only sign
## a Sunflower had ever earned its cell was the Seeds counter quietly ticking up
## at the top of the screen, six seconds' walk away from the flower.
##
## `plant` is bound at connect time, not emitted — see place_plant. Its
## `position` is board-local (Entities' own space, same as a husk's), so the one
## to_global() crossing into the HUD's canvas is the same line, for the same
## reason, as the husk's.
func _on_plant_grew_seeds(amount: int, plant: Plant) -> void:
	Sfx.play(Sfx.SEEDS_GROWN)
	bank.add_seeds(amount)
	if hud != null and is_instance_valid(hud) and is_instance_valid(plant):
		hud.fly_seed_glyph(_entities.to_global(plant.position), amount)


func upgrade_selected() -> String:
	# Asks the plant whether it grows, rather than asking whether it is a cob.
	# `has_upgrades()` is a non-empty ladder; it is a separate question from
	# `upgrade_cost() == 0`, which is also what the TOP of a real ladder costs.
	var plant: Plant = selected_placed
	if plant == null or not is_instance_valid(plant) or not plant.has_upgrades():
		return "nothing upgradeable is selected"
	if plant.is_max_level():
		return "already fully grown"
	var price: int = plant.upgrade_cost()
	if bank.seeds < price:
		hud.show_message("That upgrade costs %d seeds." % price)
		# This refusal never touches bank.pay() (that's `bank.seeds < price`
		# above, checked directly), so it never reaches purchase_failed and its
		# shared Sfx.PURCHASE_DENIED — this is the one denial site that has to
		# play the cue itself, same as it shakes the button itself.
		hud.shake_upgrade_button()
		Sfx.play(Sfx.PURCHASE_DENIED)
		return "not enough seeds"
	bank.add_seeds(-price)
	# BELOW the refusal, not beside it. Every early return above this line is a
	# purchase that did not happen — "nothing upgradeable is selected", "already
	# fully grown", and the `bank.seeds < price` denial that shakes the button —
	# and a counter incremented at the top of this method would credit the player
	# with depth for the clicks that bought nothing. This is the only line in the
	# game that charges for a level, so it is the only line that may count one.
	seeds_on_upgrades += price
	plant.upgrade()
	hud.show_message(Hud.upgrade_message(PlantCatalog.display_name(plant.kind), plant.level_name()))
	_refresh()
	return ""


## What the Uproot button is wired to. The first click arms; a second click on
## the same plant within UPROOT_CONFIRM_SECONDS commits.
##
## Returns "" when the plant was actually uprooted, and otherwise the reason it
## was not — "confirm needed" for the arming click, which is a refusal the caller
## can distinguish from a real failure.
##
## **`arm_` and `commit_`, and the names were `request_uproot` / `uproot_selected`
## until a caller guessed wrong** (plant-tower-defense-mim5). Neither old name carried
## the destructive word: "request" sounds like the safe one and is, "selected" names
## the SUBJECT rather than the ACTION, and the pair reads as a verb and a noun rather
## than as two steps. Writing a test for the arming half, I called `uproot_selected`,
## it removed the bed with no confirmation, and it returned "" — which is this API's
## success value. Nothing failed; a plant was simply gone.
##
## The rule the rename follows: **when two functions differ in destructiveness, the
## names must differ in the destructive word.** `arm_` is a promise that nothing
## happens yet; `commit_` is a promise that it does.
func arm_uproot() -> String:
	if selected_placed == null or not is_instance_valid(selected_placed):
		return "nothing is selected"
	# No `and _uproot_left > 0.0` here, and _update_preview lost the same half for the
	# same reason (plant-tower-defense-iljz). `selected_placed` is non-null by the guard
	# above, so `_uproot_armed == selected_placed` already says something is armed — and
	# `_disarm_uproot()` is the ONE place the arming is cleared and it clears the
	# reference and the clock together, so an open window is exactly a non-null
	# `_uproot_armed`. A second condition that cannot disagree is dead code wearing a
	# safety belt, which is a shape this repo has now paid for twice.
	# test_the_uproot_window_leaves_nothing_armed_behind_it pins the invariant at
	# runtime; test_the_uproot_clock_is_never_written_without_the_arming pins that no
	# future writer can move one without the other.
	if _uproot_armed == selected_placed:
		_disarm_uproot()
		return commit_uproot()
	_uproot_armed = selected_placed
	_uproot_left = UPROOT_CONFIRM_SECONDS
	# The bed itself says so, not only the message row (plant-tower-defense-rtgp).
	_uproot_armed.set_uproot_armed(true)
	# And how LONG it says so for (plant-tower-defense-fjqp). Pushed on the arming frame
	# rather than left to the first tick: the arc has to appear as a full circle the
	# instant it appears, or its own first frame reads as time already spent.
	_push_uproot_clock()
	Sfx.play(Sfx.UPROOT_ARMED)
	# IMPORTANT: this is an instruction with a live 4-second trigger behind it, and
	# an ambient husk pickup used to wipe it mid-read.
	# The move-preview tip rides along the FIRST time an uproot is ever armed, and
	# never again (plant-tower-defense-23fa). It costs 185 px of this row's headroom
	# and teaches something once; paying that on every uproot forever was the wrong
	# trade, and a hint that appears once is more likely to be read than one that
	# has become wallpaper.
	#
	# Recorded before the message rather than after: record_milestones() is
	# idempotent and only writes when something is new, so the order cannot
	# double-write — and arming twice in a frame is a thing this method already
	# guards against above.
	# Every plant answers what it has spent climbing its own ladder; a plant with no
	# ladder answers 0. This used to be `as CornCobbler`, which was correct only
	# while corn was the sole upgradable plant -- the Chomp Flower now forfeits too,
	# and its full climb (70) is dearer than the cob's (65).
	var forfeited: int = selected_placed.upgrade_spent()
	var first_arm: bool = not RunConfig.has_milestone(RunConfig.HINT_MOVE_PREVIEW)
	# Spend the one-shot only when the tip is going to be SHOWN. `Hud.uproot_shows_tip`
	# owns that decision because the message composer needs it too, and a rule stated in
	# two files is a rule that drifts — which it did for one cycle, in exactly this spot.
	#
	# The answer now goes THROUGH `spend_hint` rather than gating a call beside it: the
	# old shape was an `if` around `record_milestones`, and an `if` is something the next
	# hint's author can simply not write. `shown` is an argument, so they cannot.
	RunConfig.spend_hint(RunConfig.HINT_MOVE_PREVIEW,
		Hud.uproot_shows_tip(first_arm, forfeited))
	# DEADLINE, not IMPORTANT: `_uproot_left` is already counting down by the time
	# this line is posted, so a deferral here does not postpone the message, it
	# eats the window it describes. See Hud.MESSAGE_DEADLINE.
	hud.show_message(
		Hud.uproot_armed_message(PlantCatalog.display_name(selected_placed.kind), first_arm,
			forfeited),
		UPROOT_CONFIRM_SECONDS, Hud.MESSAGE_DEADLINE)
	_refresh()
	return "confirm needed"


## True while a second Uproot click would commit. Read by the HUD to relabel the
## button, and by the tests.
##
## `_uproot_left > 0.0` is deliberately NOT a third term (plant-tower-defense-iljz):
## it can never disagree with the first. The null check IS load-bearing and stays —
## with nothing selected and nothing armed the two nulls compare EQUAL, and without it
## this would answer true for a button that must read "Uproot".
func uproot_armed() -> bool:
	return _uproot_armed != null and _uproot_armed == selected_placed


## Refreshes the panel when — and only when — the selected plant's health moves.
func _watch_selected_health() -> void:
	if selected_placed == null or not is_instance_valid(selected_placed):
		_selected_health = -1.0
		return
	if is_equal_approx(selected_placed.health, _selected_health):
		return
	_selected_health = selected_placed.health
	_refresh()


## The ONE place the arming is cleared, which is why the marker is put back here
## rather than at each caller. Every exit runs through it: confirming, the timer
## expiring, selecting something else, and the armed plant being eaten mid-decision --
## and that last one is why the validity check is not optional.
func _disarm_uproot() -> void:
	if _uproot_armed != null and is_instance_valid(_uproot_armed):
		_uproot_armed.set_uproot_armed(false)
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
		return
	# Every surviving frame, and only here. The branch above hands the close-out to
	# _disarm_uproot(), which zeroes the drawn arc through Plant.set_uproot_armed —
	# so this line must not run after it, or a cleared clock is pushed straight back
	# onto a marker that has just finished putting itself away.
	_push_uproot_clock()


## Hands the open window to the armed plant's `SelectionMarker`, which is what draws it
## (plant-tower-defense-fjqp). Game owns the clock; the marker owns the paint.
##
## `_uproot_left` is read here and in `_tick_uproot_confirm` and nowhere else, and the
## marker counts nothing of its own — so the arc a player watches close and the timer
## that actually decides whether the next click destroys a bed are the same number.
##
## Reached by node name rather than through a `Plant` accessor because
## `SelectionMarker.NODE_NAME` is exactly the contract that exists for this: it is the
## path `test_selftest.gd` and the devtools bridge already look the marker up by, and it
## is documented as a contract on the constant itself. A plant built outside a Game has
## no marker, which is a silent no-op here for the same reason it is one in
## `Plant.set_uproot_armed`.
func _push_uproot_clock() -> void:
	if _uproot_armed == null or not is_instance_valid(_uproot_armed):
		return
	var marker := _uproot_armed.get_node_or_null(
		NodePath(SelectionMarker.NODE_NAME)) as SelectionMarker
	if marker == null:
		return
	marker.set_uproot_window(_uproot_left, UPROOT_CONFIRM_SECONDS)


## The unguarded mutator: removes the selected plant and pays the refund with **no
## confirmation and no undo**. The button never reaches this directly — it is wired to
## `arm_uproot`, which gates it behind the four-second confirm — but the devtools
## verbs and the placement tests call it deliberately, because a test that has to
## arm-and-wait to remove a plant is testing the timer rather than the removal.
##
## Named `commit_` for the reason `arm_uproot`'s header spells out: this is the one
## that destroys, and its name has to say so to anyone reading a call site.
func commit_uproot() -> String:
	if selected_placed == null or not is_instance_valid(selected_placed):
		return "nothing is selected"
	var plant: Plant = selected_placed
	_plants.erase(plant.cell)
	bank.refund(plant.uproot_refund())
	Sfx.play(Sfx.PLANT_UPROOTED)
	plant.play_exit_and_free()
	_select(null)
	_refresh()
	return ""


## Beat between a purchase landing and its reveal. SeedBank's own header calls
## this "a gamble that reads as suspense" (seed_bank.gd), but buy_packet()
## rolls and returns synchronously, so nothing used to separate the click from
## the banner — the roll and the reveal happened in the same frame. The roll
## itself stays exactly that synchronous and testable; only what the player
## SEES of it is delayed, and only here, in the presentation layer.
const PACKET_OPEN_STEP_SECONDS: float = 0.09
const PACKET_OPEN_STEPS: int = 3

## The tier being opened, set immediately before buy_packet() so
## _on_plant_unlocked — which fires synchronously from inside that call — knows
## which pool to flash candidates from.
var _opening_tier: StringName = &"common"


func _on_packet_requested(tier: StringName = &"common") -> void:
	_opening_tier = tier
	var got: StringName = bank.buy_packet(tier)
	if got != &"":
		selected_plant = got
	else:
		hud.shake_packet_button(tier)


func _on_plant_unlocked(id: StringName) -> void:
	if not GardenTheme.animations_enabled():
		# Headless never pumps the frames a wait needs, so the old instant
		# reveal stays the whole story there — same rule every other flourish
		# in this file follows.
		_reveal_plant_unlock(id)
		return
	await _open_packet(id)


## Flickers through a couple of the tier's other still-locked candidates
## before landing on the real pick — PACKET_OPEN_STEPS steps of
## PACKET_OPEN_STEP_SECONDS each, well under a second total, so it reads as a
## beat rather than a wait. Falls back to `id` itself for a step if the pool
## it drew from is down to nothing else (a packet with one thing left to give).
##
## Reads bank.packet_pool(_opening_tier) rather than the tier's whole catalogue:
## by the time this runs, `id` is already unlocked (buy_packet() appends it
## before emitting), so the pool is naturally everything BUT the real pick —
## exactly the "other candidates" a flicker needs, with nothing to filter out.
func _open_packet(id: StringName) -> void:
	var pool: Array[StringName] = bank.packet_pool(_opening_tier)
	for i: int in range(PACKET_OPEN_STEPS):
		var flash: StringName = id if pool.is_empty() else pool[i % pool.size()]
		# Same priority on every step, deliberately: show_message() only queues
		# a message behind one still on screen for MESSAGE_MIN_READABLE seconds
		# or a higher priority. Equal priority and a step well under that falls
		# through to the immediate-overwrite branch instead, so each flicker
		# replaces the last rather than queuing up behind it.
		hud.show_message("...%s?" % PlantCatalog.display_name(flash),  # message-corpus-check: ok - a plant name already bounded by packet_message() plus three characters
			PACKET_OPEN_STEP_SECONDS, Hud.MESSAGE_IMPORTANT)
		await get_tree().create_timer(PACKET_OPEN_STEP_SECONDS).timeout
	_reveal_plant_unlock(id)


func _reveal_plant_unlock(id: StringName) -> void:
	# IMPORTANT, matching every step of the flourish above it: an ambient
	# message re-surfacing between those steps (see _open_packet) would
	# otherwise queue the reveal itself behind it instead of showing it.
	hud.show_message(Hud.packet_message(PlantCatalog.display_name(id)), 5.0,
		Hud.MESSAGE_IMPORTANT)
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
	# A verb arrives as an InputEventKey off a keyboard and as an InputEventAction
	# out of Input.action_press -- which is what the devtools bridge's `input tap`
	# sends, and the only way any of these four is checkable in a running game.
	# Narrowing to InputEventKey here, as this handler did while it compared raw
	# keycodes, made every one of them unreachable from the bridge while looking
	# perfectly correct to a player. `is_action_pressed` does the pressed and
	# not-an-echo filtering the explicit guard used to.
	if not (event is InputEventKey or event is InputEventAction):
		return
	# Actions, not keycodes: what these four verbs are bound to is KeyBindings.ACTIONS
	# and, after a visit to the settings screen, whatever the player put there
	# instead. Nothing in this handler may name a KEY_* constant again — the pause
	# card's legend is rendered from the same InputMap these lines read.
	if event.is_action_pressed(KeyBindings.ACTION_RESTART) and (game_over or victory):
		get_tree().reload_current_scene()
		return
	# Not while the run is over: the post-mortem is already a modal surface, and
	# pausing behind it would leave two cards stacked with no way to reach either.
	if event.is_action_pressed(KeyBindings.ACTION_PAUSE) and not (game_over or victory):
		pause_run()
		return
	# The project-level mute, which is what makes the sound pass something the
	# player controls rather than something the engine's --mute flag controls for
	# them. Deliberately live even on the results screen: a jingle the player
	# wants to stop is exactly when they reach for this.
	#
	# M and N are two independent switches, not one shared one: M silences the
	# one-shot cues (Sfx), N silences the looping bed (Music). They used to be
	# a single flag -- Music read Sfx.is_muted() directly -- so a run had
	# exactly one volume and it silenced both at once. See Music._muted's own
	# doc comment for the split.
	#
	# Through RunConfig rather than straight at Sfx/Music, so a mute set from the
	# keyboard mid-run is the same act as one set on the Options screen and is
	# written to the save either way. Calling the static setters here left the
	# player's choice alive exactly as long as the process (plant-tower-defense-v6c).
	if event.is_action_pressed(KeyBindings.ACTION_MUTE_SFX):
		# The key named in the message is read back out of the InputMap, not typed
		# here. "Press M to bring them back" printed at a player who had rebound
		# the verb to F2 is worse than saying nothing at all.
		hud.show_message(mute_message("Sound effects", RunConfig.toggle_mute_sfx(),  # message-corpus-check: ok - keybind-dependent; the budget measures the CURRENT binding live
			KeyBindings.ACTION_MUTE_SFX, "them"), 2.5)
		return
	if event.is_action_pressed(KeyBindings.ACTION_MUTE_MUSIC):
		hud.show_message(mute_message("Music", RunConfig.toggle_mute_music(),  # message-corpus-check: ok - keybind-dependent; the budget measures the CURRENT binding live
			KeyBindings.ACTION_MUTE_MUSIC), 2.5)
		return
	# Swaps the health fill and the threat readout onto GardenTheme's blue/orange
	# ramp. This arrived as a raw scancode check from the branch that added the
	# ramp, at the same time as the branch that moved every other verb onto the
	# InputMap; it is an action here so the Keys screen can rebind it like the
	# rest, and so the pause card lists it without a second hand-written row.
	# (Naming the constant even in a comment fails the scan above, by design.)
	#
	# _refresh() rather than waiting for the next state change: both bars are
	# repainted from state, and the threat tint EASES toward its target, so a player
	# who presses this between waves with nothing selected would otherwise see
	# nothing happen and conclude the key does not work.
	if event.is_action_pressed(KeyBindings.ACTION_COLORBLIND):
		var safe: bool = RunConfig.toggle_colorblind_safe()
		hud.show_message(
			"Colourblind-safe bars on." if safe else "Colourblind-safe bars off.", 2.5)
		repaint_for_palette()
		return
	# The designer's "faster button", and the backlog's slow mode, as one verb —
	# see GameSpeed.STEPS.
	#
	# NO show_message here, and the omission is a decision rather than an oversight:
	# the top bar's speed button is the readout, and it changes on the same
	# _refresh() this triggers. A message would be a second copy of the same fact,
	# and — the half that actually settled it — every string that reaches that row
	# has to be priced in `Hud.message_corpus()` or `message_corpus_check` is right
	# to call it an unpriced producer. A readout the player is already looking at
	# beats a line that has to be budgeted to say the same thing.
	if event.is_action_pressed(KeyBindings.ACTION_SPEED):
		cycle_speed()


## Every bar the colourblind ramp reaches, repainted now rather than at whatever
## the next state change happens to be.
##
## Three bars, and only two of them are the HUD's. `_refresh()` covers those; the
## in-world plant bar is drawn from take_damage()/_regrow(), so a chewed plant
## nobody is currently eating would keep the old ramp until something bit it again.
##
## A method rather than five lines inside the C-key handler because the keystroke
## is no longer the only thing that can flip the switch mid-run: the Options screen
## over the pause card can too, and `resume_run` calls this on the way out for that
## reason. A player who opens Options mid-run to turn the accessibility bars on is
## doing it because they cannot read the current ones — "it takes effect at the
## next wave" is not an answer to that.
func repaint_for_palette() -> void:
	_refresh()
	for plant: Plant in _plants.values():
		plant.repaint_health_bar()


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
	# While an uproot is armed the player is weighing a MOVE, not a purchase, so the
	# preview describes the plant being moved rather than whatever is selected in the
	# shop (plant-tower-defense-qk5q). Nothing else about the hover changes: the same
	# brackets, the same ring, the same dots — only the subject.
	# `_uproot_armed` alone, with no `_uproot_left > 0.0` beside it. That guard was
	# here first and a mutation could not kill it: _disarm_uproot() nulls this on
	# every exit path there is — the player confirming, the window expiring, and the
	# plant being eaten mid-decision — so a live `_uproot_armed` already means an
	# open window. A second condition that can never disagree is the dead code this
	# repo has been bitten by before, wearing a safety belt.
	# test_the_uproot_window_leaves_nothing_armed_behind_it pins the invariant.
	var moving: Plant = _uproot_armed
	if moving != null and not is_instance_valid(moving):
		moving = null
	var previewing: StringName = moving.kind if moving != null else selected_plant
	_preview.reach = PlantCatalog.reach(previewing)
	# Explicit rather than inferred. PlacementPreview falls back to deducing the
	# kind from `reach`, which works only while no two plants share a radius --
	# a coincidence, not a rule, and the redundant-coverage cue depends on it.
	_preview.plant_id = previewing
	# What the garden already reaches, so the preview can dot the road cells this
	# purchase would newly defend. Recomputed per hover rather than cached: the
	# set changes on every placement and every uproot, and a stale one would mark
	# ground as bare that a plant now covers — the one error this cue must not
	# make, since it is read as "spend seeds here".
	# The plant being moved is left OUT of what counts as already covered, because it
	# is about to stop covering it. Without that, every cell it currently holds reads
	# as "already defended" and the move preview would report the destination as
	# buying almost nothing — worst exactly where the move matters most, a short hop
	# that keeps most of the old reach.
	_preview.covered_now = covered_road_cells(moving)
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
	# BOARD-LOCAL, and it has to be. This guard used to read
	# `screen_pos.y < Hud.BAR_HEIGHT or screen_pos.x > board.board_size().x` — an absolute
	# screen coordinate compared against a board-LOCAL width, which was correct for exactly
	# as long as the board started at (0, BAR_HEIGHT) and silently wrong the moment
	# `_apply_board_layout` began centring it. At a 1387-wide canvas the board sits at
	# x = 117, so the old test rejected every click on its rightmost 117 px and ACCEPTED
	# clicks in the left gutter, where `world_to_cell` returns a negative cell.
	#
	# That failure is invisible in a screenshot: the board draws perfectly and a strip of it
	# just stops responding. Found by reading the guard, not by looking at the picture — the
	# same lesson `Board.cell_to_global`'s header records.
	# A FAITHFUL translation of the old test into board-local space, not a tightening.
	# It deliberately does NOT reject `local.x < 0` or a y past the board's bottom: the
	# husk branch below is reached from here on purpose, and `Board._build_route` brackets
	# the road with an off-board entry and exit whose husks belong to no cell and are still
	# the player's to collect. Rejecting the whole off-board area would have taken those
	# with it — which is what the first draft of this guard did.
	var local: Vector2 = screen_pos - _entities.position
	if local.y < 0.0 or local.x > board.board_size().x:
		return
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
	if refusal == "not paid for":
		# The refusal fired on a board click, not a bar click — pay_for_plant()
		# already told the player why through purchase_failed. What shakes here
		# is the slot they picked the plant from, the one thing on screen that
		# actually names what they were trying to buy.
		hud.shake_plant_button(selected_plant)
	elif refusal != "":
		hud.show_message(refusal.capitalize() + ".")  # message-corpus-check: ok - placement refusals are assembled at runtime, not written here
	# The cell under the cursor just changed state — either it now holds a
	# plant, or the purchase drained the seeds that made it affordable. Either
	# way the cue on screen is stale until the mouse moves, which it need not.
	_update_preview(cell, board.is_buildable(cell) and not _plants.has(cell))


# -- state ------------------------------------------------------------------


## Recomputes every plant's neighbour buff from the board as it now stands.
##
## Driven from `_refresh()` rather than from Mint itself, and that is the whole design: a
## buff applied by the buffer cannot be UNapplied when the buffer is uprooted, because by
## then there is nothing left to run. Whoever owns the set owns the derived state, so this
## recomputes from scratch every time rather than adding and subtracting deltas — an
## incremental version has to get uproot, destruction, placement and replacement all right,
## and gets no second chance when it does not.
##
## Assigns rather than multiplies into the field, for the same reason weather does: two
## sources writing one number is how the number stops meaning anything. Weather owns
## `fire_interval_scale`, this owns `neighbour_interval_scale`, and `Plant.composed_interval`
## is where they meet.
## Centres the playfield in the space the HUD leaves it, and keeps it centred when the
## window changes shape.
##
## WHY THIS EXISTS. The board is a fixed 896x576 (`Board.COLS * CELL` by `ROWS * CELL`) and
## `_entities` sat at `Vector2(0, BAR_HEIGHT)` — hard against the left edge, forever. At the
## design size that is exactly right and invisible: 896 of board plus 256 of side panel is
## 1152, the whole canvas, with nothing left over.
##
## It stopped being invisible the moment the HUD started laying out against the LIVE
## viewport (plant-tower-defense-0jye). `stretch/aspect="expand"` gives a wide window MORE
## canvas width, the side panel is now correctly pinned to the right edge of it, and the
## board still started at x=0 with a fixed width — so every pixel of the extra width piled
## up in one grey gutter between the playfield and the panel. Reported from a screenshot,
## which is the second time this file has learned something that way (see
## `Board.cell_to_global`'s header for the first).
##
## Note what the old behaviour was actually doing: before -0jye the panel was ALSO in the
## wrong place, at a hardcoded `1152 - PANEL_WIDTH`, so the gutter existed and was hidden by
## a second bug sitting on top of it. Fixing the panel is what made this one visible.
##
## WHAT IT DOES: splits the leftover space evenly instead of dumping it on one side, in both
## axes — horizontally between x=0 and the panel's left edge, vertically between the top bar
## and the bottom of the canvas. `floorf` because a half-pixel offset on a 64px pixel-art
## grid is visible as softening on every sprite at once.
##
## `maxf(0, ...)` because a viewport SMALLER than the board must not push it off the left or
## up under the bar — it clamps to the old behaviour instead, which is the readable failure.
##
## Safe to move because both readers of `_entities.position` already subtract it
## (`_click_at` and `_update_preview`), so the screen-to-cell mapping follows the board
## rather than assuming where it sits. That was checked before this was written, not after.
func _apply_board_layout() -> void:
	if board == null or not is_instance_valid(board) or _entities == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var play: Vector2 = Vector2(view.x - Hud.PANEL_WIDTH, view.y - Hud.BAR_HEIGHT)
	var board_px: Vector2 = board.board_size()
	_entities.position = Vector2(
		floorf(maxf(0.0, (play.x - board_px.x) * 0.5)),
		Hud.BAR_HEIGHT + floorf(maxf(0.0, (play.y - board_px.y) * 0.5)))


## Every Aloe mends the damaged plants it reaches (plant-tower-defense-ibvb).
##
## The ITERATION is here and the decisions are in `Aloe`, for the reason its header spells
## out: `Game` owns `_plants`, and an Aloe reaching for the plant set itself would have to
## ask the tree — which returns a second `Game`'s plants when the suite hosts two scenes at
## once (`.claude/skills/godot-test-isolation`). `Aloe.reaches` and `Aloe.heal_for` are pure
## and static, so the interesting half is assertable with no board at all.
##
## Unlike `_refresh_neighbour_buffs`, this runs per FRAME rather than per change to the
## plant set, and that is the difference between a state and an event: a Mint's buff has to
## be un-applied when the Mint goes, a heal that already happened does not. See Aloe's
## header, which argues that asymmetry rather than leaving it looking like an oversight.
##
## `delta` is already scaled by `Engine.time_scale`, so an Aloe repairs at the same rate per
## GAME second whatever speed the player has the garden running at. That is the right answer
## and not an accident of where this sits: at 2x a wave arrives twice as fast, and a heal
## that stayed on wall-clock time would quietly become half as effective for anyone using
## the speed control.
##
## Skipped entirely when no Aloe is planted, which is every board until someone buys one —
## the first loop is over `_plants` and breaks nothing, but the second is not entered at all
## and the common case stays one cheap pass.
func _apply_aloe_healing(delta: float) -> void:
	var aloes: Array[Vector2i] = []
	for key: Vector2i in _plants:
		var plant := _plants[key] as Plant
		if plant == null or not is_instance_valid(plant) or plant.is_destroyed():
			continue
		if plant is Aloe:
			aloes.append(key)
	if aloes.is_empty():
		return
	var amount: float = Aloe.heal_for(delta)
	for key: Vector2i in _plants:
		var plant := _plants[key] as Plant
		if plant == null or not is_instance_valid(plant) or plant.is_destroyed():
			continue
		for from_cell: Vector2i in aloes:
			if Aloe.reaches(from_cell, key):
				# `Plant.heal` already refuses a destroyed or full-health plant and clamps
				# at MAX_HEALTH, so two Aloes overlapping one Corn heal it twice as fast up
				# to full and never past it. Deliberately NOT capped at one Aloe per plant:
				# stacking support is the same decision Mint already lets the player make.
				plant.heal(amount)


func _refresh_neighbour_buffs() -> void:
	var mints: Dictionary = {}
	for key: Vector2i in _plants:
		var plant := _plants[key] as Plant
		if plant == null or not is_instance_valid(plant) or plant.is_destroyed():
			continue
		if plant is Mint:
			for cell: Vector2i in Mint.neighbours_of(key):
				mints[cell] = int(mints.get(cell, 0)) + 1
	for key: Vector2i in _plants:
		var plant := _plants[key] as Plant
		if plant == null or not is_instance_valid(plant):
			continue
		# A Mint beside a Mint buffs nothing: neither of them fires, so the number would
		# be real and unobservable. Skipping it keeps `scale_for` honest as the answer to
		# "what does this plant's interval get multiplied by" rather than to "how many
		# Mints are adjacent", which are different questions the moment one is a Mint.
		plant.neighbour_interval_scale = (1.0 if plant is Mint
			else Mint.scale_for(int(mints.get(key, 0))))


func _refresh() -> void:
	_refresh_neighbour_buffs()
	# Ahead of the hud guard, not after it. The road's off-aim marks are the one
	# part of a refresh that is not the HUD's, and the headless suite drives a Game
	# with no HUD at all — putting this below the return would make the board's
	# second reading the only readout in the run that cannot be tested without one.
	#
	# Cheap enough to sit on the same funnel as the HUD: uncovered_road_cells() is
	# one 126-cell sweep per engaging plant, and mark_unaimed_road() returns early
	# without repainting when the set has not moved, which is every refresh except
	# the ones where a plant was bought, uprooted or eaten.
	if board != null and is_instance_valid(board):
		board.mark_unaimed_road(uncovered_road_cells())
		# The dead-ground marks read the garden's unlocks, so they move when a packet
		# is opened -- not only when the cursor moves. Same funnel and the same
		# early-return discipline as mark_unaimed_road above.
		_refresh_dead_ground()
		# The deferred bars read the standing guns and their reaches, so they move
		# when the garden does -- a cob bought, uprooted or eaten -- and not only
		# when the cursor moves. Same funnel, same discipline.
		_refresh_deferred_road()
		# The preview's new-cover dots read the same set, and pushing it only from
		# _update_preview would leave them stale whenever the garden changes while
		# the cursor is STILL — a plant eaten mid-wave, an uproot committing, a
		# purchase from the bar. That is the one error this cue must not make,
		# because it is read as "spend seeds here": either marking ground as bare
		# that a plant now covers, or failing to mark ground that just became bare.
		# Only while it is on screen; a hidden preview has nothing to repaint.
		if _preview != null and is_instance_valid(_preview) and _preview.visible:
			_preview.covered_now = covered_road_cells()
			_preview.queue_redraw()
		# The selected plant's own half of the same question, and the plant held
		# over beside it. Pushed here rather than from set_selected() because the
		# answer changes when the GARDEN changes, not only when the selection does:
		# plant a second cob beside the selected one and the rings under it should
		# thin out without the player clicking anything.
		#
		# A held plant eaten or uprooted leaves a freed reference behind; cleared here
		# rather than at each death path, because this is the one funnel every one of
		# them already runs through.
		if _held_over != null and not is_instance_valid(_held_over):
			_held_over = null
		_push_sole_cover(selected_placed)
		_push_sole_cover(_held_over)
	if hud == null:
		return
	hud.refresh(state())
	# AFTER hud.refresh, not before. The tip names a price the player is about to go
	# looking for, so the readouts it will be compared against — the seed count above
	# all — must already show this refresh's numbers. Posting first would put the
	# message on screen a frame ahead of the balance that justifies it.
	_maybe_teach_upgrading()


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
		# The wave AFTER the one just cleared, described for the prep gap. Unlike
		# `weather`, which is the weather Game is holding, these are deliberately
		# derived for `current_wave + 1` -- the whole point is to say what has not
		# happened yet.
		"next_wave_pests": WaveDirector.pests_in_wave(director.current_wave + 1),
		"next_wave_boss": WaveDirector.wave_carries_boss(director.current_wave + 1),
		"next_weather": WaveDirector.weather_for(director.current_wave + 1),
		# Endless has no last wave, so the flag is false there by construction rather
		# than by a comparison that happens to never be true.
		"next_wave_is_last": (not director.endless
			and director.current_wave + 1 == WaveDirector.WAVES.size()),
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
		# The weather Game is HOLDING, not weather_for(current_wave). Between waves
		# the wave number has already moved to the one that has not started, so
		# deriving it here would show the next wave's weather during the prep gap --
		# announcing a drought before it applies to anything.
		"weather": weather,
		# The speed the PLAYER chose, and its two rendered forms. The HUD keeps no
		# second copy of any truth (see hud.gd), so the button's face and its tooltip
		# are handed to it the same way every other readout is.
		#
		# `GameSpeed.scale()` and not `Engine.time_scale`: while the pause card is up
		# they differ on purpose, and the button must keep saying what the player
		# picked rather than flicking to "1x" behind a card that is covering it.
		"game_speed": GameSpeed.scale(),
		"game_speed_label": GameSpeed.label(),
		"game_speed_tooltip": GameSpeed.button_tooltip(),
	}


# -- budgets ----------------------------------------------------------------
#
# Four constants in this project carry a "moving me costs you X" doc comment, and
# every one of the X's lives in a different file. `python tools/devtools.py cmd
# budgets` prices all six couplings and prints what is left of each -- but it
# needs a launched game and a bridge, so the one person who will never run it is
# the person who is about to spend one.
#
# So the pricing lives here, on the run itself, and the run reads it once at
# startup. `cmd budgets` calls budget_entries() rather than measuring anything of
# its own, the same way board_info and budgets both call
# PlacementPreview.husk_click_budget(): one arithmetic, so the verb and the
# warning cannot report different headroom for the same board.
#
# What is NOT priced here is the two couplings a run cannot price cheaply or at
# all. The notebook subheading needs a NotebookScreen the run never builds -- it
# is a title-screen subscreen, and the verb stands one up inside a throwaway
# SubViewport to measure it, which is a whole UI built and thrown away on the
# frame the player is waiting through, to check a sentence that is a constant and
# a font and therefore cannot change between two launches of the same build.
# test_the_budgets_notebook_entry_measures_the_sentence_the_screen_draws already
# fails on it, headless, every /verify. The road's shape has no ceiling to
# subtract from at all. Both stay in devtools_ext/commands.gd and are built
# through the constructors below, so their grading is still this grading.


## A budget is "tight" once less than this fraction of its ceiling is unspent.
##
## 0.15 rather than something smaller because these budgets are small in absolute
## terms and nearly all of them are already near their end: 4 px of 32 on the husk
## sweep, 10 px of 171 on the seeds readout, 19 px of 1112 on the stats row. A
## threshold that called those comfortable would report a clean board right up to
## the day one of them breaks, which is the failure mode the readout exists
## against. It is a label on a reading, NOT the startup warning's trigger -- see
## BUDGET_FLOOR, which is where that argument is made.
const BUDGET_TIGHT_FRACTION: float = 0.15

## Waves swept when pricing the road's simultaneous-pest ceiling. The peak lands
## around wave 20 -- see test_an_endless_wave_never_fills_the_road_past_the_stated_ceiling,
## which sweeps 300 -- so this is well past it and still cheap enough to run on
## one frame at startup and on the frame the bus answers from. Override the verb's
## sweep with `--args '{"waves": 300}'`.
const BUDGET_WAVE_SWEEP: int = 120

## Reported when a budget's own inputs could not be read this run. Distinct from
## "described", which means there was never a number to read: an unmeasured
## budget is a hole in the readout and a described one is a property of the
## coupling. Collapsing the two is how a check disappears from a report.
const BUDGET_UNMEASURED: String = "unmeasured"
const BUDGET_DESCRIBED: String = "described"

## A computed budget's fourth possible state, alongside "ok", "tight" and
## "spent" — reported instead of "spent" when the caller declares the zero
## headroom is the intended shape of the coupling rather than an accident that
## happened to land on it. pest_road_ceiling is the one budget this applies to
## today: ENDLESS_APHID_SHARE + ENDLESS_BEETLE_SHARE sum to
## SIMULTANEOUS_PEST_CEILING exactly, which is what makes the bound hold by
## construction rather than by tuning (see wave_director.gd). Plain "spent"
## reads as "this ran out and nobody noticed"; a budget that can never read any
## other way needs a different word, or every future glance at the report
## mistakes the one alarm this table can still raise for the one row that was
## never going to ring it.
##
## The wave that spends it is now the campaign finale rather than an endless one
## (plant-tower-defense-74a): the endless column is paced apart from its first
## wave, so endless peaks at 29, and wave 16 is sized to land on 40 exactly.
## Both halves of the claim still hold — the shares bound it by construction,
## and a real wave reaches it — but they are now made by two different waves.
## See WaveDirector.SIMULTANEOUS_PEST_CEILING.
const BUDGET_SPENT_BY_DESIGN: String = "spent_by_design"

## What each budget had left the last time one was read and accepted. The only
## thing the startup warning fires on.
##
## "Warn when a budget is tight" is the obvious rule and it is the wrong one:
## three of the four below are ALREADY tight and one is already spent, by design
## -- 4 px of 32 on the husk sweep, 10 of 171 on the tightest readout, 19 of 1112
## on the row, and the road sits at exactly its pest ceiling. That rule prints
## four warnings on every launch of a project that is behaving as intended, and
## four warnings that are always there are zero warnings.
##
## "Warn when one is spent" is not news either: every budget below already has a
## check that fails the moment it goes negative --
## test_no_husk_the_game_can_drop_lands_within_a_click_of_buildable_ground,
## test_no_readout_clips_its_own_worst_case, test_the_stats_row_budget_fits_the_bar
## and test_an_endless_wave_never_fills_the_road_past_the_stated_ceiling. A
## startup warning that repeated them would add noise and no information.
##
## The uncovered ground is the stretch between "still fits" and "fits with
## nothing to spare": a readout that goes from 90 px of slack to 3 px breaks
## nothing, fails nothing, and is reported nowhere. So the warning fires on a
## budget falling BELOW a number written down here -- on a spend, not on a state.
## Accepting a spend means editing this table in the commit that spends it, which
## is the point: the number moves in a diff a person reviews, instead of moving
## silently inside a font metric.
##
## A budget with no entry here is deliberately never warned about (the road has
## no ceiling to fall through), and an entry here with no budget to match it IS
## warned about -- a floor guarding a budget that no longer exists is a check
## that has quietly stopped running.
const BUDGET_FLOOR: Dictionary = {
	"husk_click": 4.0,
	# Ratcheted up from 7.0 / 8.0 in the same commit that re-proportioned
	# hud.gd's readout widths and STATS_SEPARATION (plant-tower-defense-73y) --
	# the pattern budget_regressions()'s own warning names: accept a spend (or
	# here, a gain) by moving the floor to what the build now actually has.
	"hud_readouts": 10.0,
	# The message row, measured against every plant name the catalogue can produce
	# (plant-tower-defense-m1el). 342px of slack at the time it was declared, which is
	# roomy -- and that is the number worth having written down, because "roomy" is
	# what everyone assumed about the wave slot until it had 10px left.
	"hud_message_row": 40.0,
	"hud_stats_row": 19.0,
	# ZERO, and it is the news this budget was filed to find (plant-tower-defense-r722).
	#
	# Cycle 57 priced the cob's second line against the 232px box BY HAND, wrote
	# "~190 of 232" into a decision, and lost the number. Measured mechanically over
	# every line the panel can draw -- rather than the one line someone happened to be
	# looking at -- the cob is not the worst case and never was. A Chomp Flower that is
	# chewing shows "Chewing — 100% through this one." at 252 px in a 232 px box; it
	# wraps to a second row, SelectionLabel grows from 56 to 72, and because the Chomp
	# has a ladder its Upgrade button is in the stack. The foot lands at 184 px into
	# 184 px of panel: flush with the panel edge, no margin at all -- which is the exact
	# state `_refresh_selection`'s own comment records a draft having hit at window
	# y=648 and being sent back for.
	#
	# So this floor is not a comfortable number ratcheted down. It is a tripwire on a
	# panel that has already run out: the next row anybody adds leaves the panel, and
	# `budgets_at_floor()` reports this entry as resting on its floor on every reading
	# until the wrapping line is shortened. Filed separately -- shortening it is a text
	# decision, not a budget one.
	"hud_selection_panel": 0.0,
	"pest_road_ceiling": 0.0,
}

## How far under its floor a budget has to fall before the run says so.
##
## One unit, not zero. Two of these floors are widths measured with
## Font.get_string_size() and font metrics are not bit-identical across platforms
## or DPI; a floor compared exactly would eventually fire on a rounding
## difference, which is the same noise BUDGET_FLOOR exists to avoid, only harder
## to argue with. Nothing meaningful is spent in under a pixel, and the two
## budgets counted in whole units (pests) cannot move by less than one at all.
const BUDGET_SLIP: float = 1.0

## The startup budget read, as check_budgets() left it. Empty until it runs.
##
## Kept rather than recomputed because the devtools status provider reports it on
## every single bus reply, and pricing four budgets -- including a 120-wave sweep
## -- per reply would make reading the game more expensive than playing it. It is
## a report of what startup found, and it says so.
var budget_report: Dictionary = {}


## Price every budget this run can price, compare each against BUDGET_FLOOR, and
## push_warning the ones that fell through it. Called once from _ready().
##
## push_warning is a weak carrier on its own -- it reaches the editor's Errors
## tab and stderr, and `devtools.py launch` redirects stderr to a file nobody
## opens unless something already went wrong. So the same verdict is stored in
## budget_report, which devtools_ext/commands.gd merges into the `status` of
## EVERY bus reply, and the noise question is settled by a test rather than by
## this comment: test_a_clean_launch_warns_about_no_budget_at_all in
## test/unit/test_economy.gd asserts a real startup produces zero warnings.
func check_budgets() -> Dictionary:
	var entries: Array[Dictionary] = budget_entries(BUDGET_WAVE_SWEEP)
	var warnings: Array[String] = budget_regressions(entries)
	# The denominator, not just the verdict: a floor whose budget failed to
	# measure is the easiest way for this check to quietly stop checking.
	var measured: int = 0
	for entry: Dictionary in entries:
		if BUDGET_FLOOR.has(str(entry["id"])) and bool(entry["computed"]):
			measured += 1
	var summary: String = "%d of %d declared budget(s) measured, %d under floor" % [
		measured, BUDGET_FLOOR.size(), warnings.size(),
	]
	budget_report = {
		"summary": summary,
		"measured": measured,
		"declared": BUDGET_FLOOR.size(),
		"warnings": warnings,
	}
	for line: String in warnings:
		push_warning(line)
	return budget_report


## Every budget this run can price on its own, in the shape `cmd budgets` reports
## them. The verb appends the two it can only ask about with a bridge.
func budget_entries(sweep: int = BUDGET_WAVE_SWEEP) -> Array[Dictionary]:
	var entries: Array[Dictionary] = [
		_budget_husk_click(),
		_budget_hud_readouts(),
		_budget_hud_message_row(),
		_budget_hud_stats_row(),
		_budget_hud_selection_panel(),
		_budget_pest_road_ceiling(maxi(1, sweep)),
	]
	return entries


## The budgets that have fallen below the floor declared for them, one sentence
## each, naming what to look at and how to accept the spend.
##
## Static and pure -- it grades the entries it is handed and reads nothing else,
## so a test can hand it a budget worsened on purpose and watch the warning
## appear, which is the only way to prove the rule fires at all rather than
## proving the current numbers happen to be fine.
## The budgets sitting exactly ON their declared floor — the ratchet pulled all
## the way, with nothing left to spend (plant-tower-defense-k7v4).
##
## Distinct from `tight` and from `budget_regressions()`, and the distinction is
## the whole point. `tight` is a fraction of a budget's own CEILING, so
## hud_message_row reports tight at 121 px while still holding 81 px above its
## floor. `budget_regressions()` reports what has fallen THROUGH a floor, which is
## news. This reports what is resting on one: not a regression, and not news, but
## the state that decides whether the next pixel spent anywhere is affordable.
##
## Cycle 66 answered that question by comparing seven headrooms against seven
## floors by hand, which is why fourteen cycles passed without anyone noticing
## that three rows of the HUD had run out. A count is not a new measurement — it
## is the one arithmetic step between the numbers already printed and the question
## anyone actually has.
##
## `BUDGET_SLIP` on both sides: a budget one pixel over its floor is resting on it
## for every practical purpose, and the same tolerance keeps this from disagreeing
## with `budget_regressions()` about a borderline case.
static func budgets_at_floor(entries: Array[Dictionary]) -> Array[String]:
	var at_floor: Array[String] = []
	for entry: Dictionary in entries:
		var id: String = str(entry["id"])
		if not BUDGET_FLOOR.has(id) or not bool(entry["computed"]):
			continue
		# `spent_by_design` is excluded, and reading the live verb is what showed
		# why. pest_road_ceiling declares a floor of 0.0 and sits on it by
		# construction, so it qualified on the arithmetic and made every reading
		# report "4 of 7" with one entry that can never be anything else. The
		# headline already counts that state separately, so including it here
		# reports one budget twice and buries the three that are at floor because
		# somebody SPENT them -- which is the only actionable half.
		if str(entry.get("state", "")) == BUDGET_SPENT_BY_DESIGN:
			continue
		var floor_left: float = float(BUDGET_FLOOR[id])
		var headroom: float = float(entry["headroom"])
		# At or below, but `budget_regressions()` owns "below" -- so anything it
		# would report is excluded here rather than counted twice.
		if headroom < floor_left - BUDGET_SLIP:
			continue
		if headroom <= floor_left + BUDGET_SLIP:
			at_floor.append(id)
	return at_floor


static func budget_regressions(entries: Array[Dictionary]) -> Array[String]:
	var lines: Array[String] = []
	var seen: Dictionary = {}
	for entry: Dictionary in entries:
		var id: String = str(entry["id"])
		if not BUDGET_FLOOR.has(id):
			continue
		seen[id] = true
		var floor_left: float = float(BUDGET_FLOOR[id])
		if not bool(entry["computed"]):
			lines.append(("Budget '%s' (%s, declared in %s) has a floor of %s in this build but "
				+ "could not be measured this run: %s. A declared budget that cannot be read is a "
				+ "hole in the check, not a pass.") % [
					id, entry["constant"], entry["declared_in"],
					budget_number(floor_left), entry["summary"],
				])
			continue
		var headroom: float = float(entry["headroom"])
		if headroom >= floor_left - BUDGET_SLIP:
			continue
		lines.append(("Budget '%s' (%s, declared in %s) is down to %s %s, under the %s this build "
			+ "declares. %s. When it runs out: %s. Read it with `python tools/devtools.py cmd "
			+ "budgets`; if the spend is intended, move Game.BUDGET_FLOOR[\"%s\"] to %s in the "
			+ "same commit.") % [
				id, entry["constant"], entry["declared_in"],
				budget_number(headroom), entry["units"], budget_number(floor_left),
				entry["summary"], entry["when_it_runs_out"], id, budget_number(headroom),
			])
	for id: String in BUDGET_FLOOR:
		if seen.has(id):
			continue
		lines.append(("Budget '%s' has a floor of %s declared in Game.BUDGET_FLOOR, but nothing "
			+ "reported a budget by that name -- the floor is guarding a coupling that has been "
			+ "renamed or removed, so it is checking nothing.") % [
				id, budget_number(float(BUDGET_FLOOR[id])),
			])
	return lines


## A budget whose headroom was measured this run. `spent` and `ceiling` come from
## the live call named in `measured_by`; the subtraction and the verdict happen
## here so no two entries can grade themselves differently.
##
## `by_design` reports BUDGET_SPENT_BY_DESIGN instead of "spent" when the
## headroom lands at or below zero — for a coupling like pest_road_ceiling
## whose ceiling is defined to be spent exactly, by construction, rather than
## approached by accident. Every other caller leaves it false and gets the
## plain "spent" a real regression should read as.
static func computed_budget(id: String, constant: String, declared_in: String, spends: String,
		spent: float, ceiling: float, units: String, measured_by: String,
		when_it_runs_out: String, observations: Array[String],
		by_design: bool = false) -> Dictionary:
	var headroom: float = ceiling - spent
	var state: String = "ok"
	if headroom <= 0.0:
		state = BUDGET_SPENT_BY_DESIGN if by_design else "spent"
	elif ceiling > 0.0 and headroom < ceiling * BUDGET_TIGHT_FRACTION:
		state = "tight"
	return {
		"id": id,
		"constant": constant,
		"declared_in": declared_in,
		"computed": true,
		"spends": spends,
		"spent": spent,
		"ceiling": ceiling,
		"headroom": headroom,
		"units": units,
		"state": state,
		"measured_by": measured_by,
		"summary": "%s %s of %s %s max -- %s %s left" % [
			spends, budget_number(spent), budget_number(ceiling), units,
			budget_number(headroom), units,
		],
		"when_it_runs_out": when_it_runs_out,
		"observations": observations,
	}


## A budget with no headroom number: either the coupling never had a ceiling
## (BUDGET_DESCRIBED) or its inputs could not be read this run (BUDGET_UNMEASURED).
##
## The three numeric fields are -1.0 rather than 0.0, and for the reason
## PlacementPreview.lane_to_buildable_distance() gives: 0.0 is a real headroom and
## it is the worst one there is, so an entry that measured nothing must not be
## able to impersonate a budget that is exactly spent.
static func uncomputed_budget(state: String, id: String, constant: String, declared_in: String,
		spends: String, why: String, when_it_runs_out: String,
		observations: Array[String]) -> Dictionary:
	var lead: String = "NO CEILING TO MEASURE AGAINST" if state == BUDGET_DESCRIBED else "UNMEASURED"
	return {
		"id": id,
		"constant": constant,
		"declared_in": declared_in,
		"computed": false,
		"spends": spends,
		"spent": -1.0,
		"ceiling": -1.0,
		"headroom": -1.0,
		"units": "",
		"state": state,
		"measured_by": "",
		"summary": "%s -- %s: %s" % [spends, lead, why],
		"when_it_runs_out": when_it_runs_out,
		"observations": observations,
	}


## An entry that has nothing to observe. A named typed empty rather than a bare
## `[]` at the call site: an untyped Array literal handed to an Array[String]
## parameter is the class of mistake that only shows up at runtime.
static func no_budget_observations() -> Array[String]:
	var empty: Array[String] = []
	return empty


## Whole numbers print whole. "husk sweep 28 of 32 px max" is the sentence this
## readout exists to produce, and "28.0 of 32.0" is the same sentence wearing a
## spreadsheet.
static func budget_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % int(roundf(value))
	return "%.1f" % value


## CompostMeter.COLLECT_RADIUS against the closest the pests' lane comes to
## ground a plant may stand on.
##
## Not recomputed here: this is PlacementPreview.husk_click_budget(), the same
## call `board_info` prints and the same terms the gate asserts on, so no two
## readouts can report different clearances for the same board.
func _budget_husk_click() -> Dictionary:
	var budget: Dictionary = PlacementPreview.husk_click_budget(board)
	var observations: Array[String] = [str(budget["summary"])]
	if not bool(budget["measured"]):
		return uncomputed_budget(BUDGET_UNMEASURED, "husk_click",
			"CompostMeter.COLLECT_RADIUS", "res://game/compost_meter.gd",
			"husk sweep radius",
			"the board has no route to walk, so there is no lane to measure from",
			"a click could sweep a husk while standing on plantable ground",
			observations)
	return computed_budget("husk_click", "CompostMeter.COLLECT_RADIUS",
		"res://game/compost_meter.gd", "husk sweep",
		float(budget["collect_radius"]), float(budget["lane_to_buildable"]), "px",
		"PlacementPreview.husk_click_budget()",
		("at 0 px a click is genuinely ambiguous between sweeping a husk and planting: "
			+ "PlacementPreview needs a husk state it does not have, and Game._click_at "
			+ "can no longer put placement first"),
		observations)


## The four Hud.WORST_CASE_TEXT strings against the width each readout is clipped
## to. Reported as the WORST of the four, with every one of them listed as an
## observation: a row is only as safe as its tightest slot, and a mean would let
## a clipping Compost label hide behind a roomy Lives one.
##
## Measured in the real theme font off the live Labels, which is what makes this
## a readout rather than a copy of the comment in hud.gd -- a clipped Label
## renders "Seeds  4..." and nothing errors.
## The status row against the widest message the CONTENT can produce.
##
## Unlike `hud_readouts`, whose worst cases are written down in
## `Hud.WORST_CASE_TEXT`, this one is derived: it sweeps `PlantCatalog.PLANTS` and
## `CornCobbler.LEVELS` through the four message builders whose length is data rather
## than prose. A plant added with a long name moves this number without anyone
## re-typing a worst case, which is the whole reason those builders are static
## functions on Hud rather than format strings at their call sites.
func _budget_hud_message_row() -> Dictionary:
	var label: Label = null
	if hud != null and is_instance_valid(hud):
		label = hud.get_node_or_null("Root/TopBar/MessageLabel") as Label
	if label == null:
		return uncomputed_budget(BUDGET_UNMEASURED, "hud_message_row",
			"Hud.eaten_message() and siblings", "res://game/hud.gd",
			"the widest string this row can ever hold",
			"no Root/TopBar/MessageLabel in the running HUD",
			"a message renders trimmed to an ellipsis and nothing errors",
			no_budget_observations())
	var worst: String = ""
	var worst_px: float = 0.0
	# One corpus, declared beside the producers it names (Hud.message_corpus()).
	# This loop used to BE the corpus, rebuilt from whatever the last person found
	# by grepping show_message() -- which was wrong in two consecutive cycles and
	# carried a comment claiming eight call sites when there are fourteen. The
	# budget measures; it no longer decides what to measure.
	#
	# The mute lines stay here rather than in the corpus, because they are the one
	# producer whose width is not a property of the game: KeyBindings.label_for()
	# joins every key bound to the action, so a rebind moves the number. Measuring
	# what is bound NOW is the honest reading, and it cannot be a static corpus.
	for line: String in Hud.message_corpus() + [
			mute_message("Sound effects", true, KeyBindings.ACTION_MUTE_SFX, "them"),
			mute_message("Music", true, KeyBindings.ACTION_MUTE_MUSIC)]:
		var drawn: float = GardenTheme.measure(line, Hud.MESSAGE_FONT_SIZE)
		if drawn > worst_px:
			worst_px = drawn
			worst = line
	if worst_px <= 0.0:
		return uncomputed_budget(BUDGET_UNMEASURED, "hud_message_row",
			"Hud.eaten_message() and siblings", "res://game/hud.gd",
			"the widest string this row can ever hold",
			"the message-row sweep measured nothing",
			"a message renders trimmed to an ellipsis and nothing errors",
			no_budget_observations())
	return computed_budget("hud_message_row", "Hud.eaten_message() and siblings",
		"res://game/hud.gd", "widest message-row string", worst_px, label.size.x, "px",
		("GardenTheme.measure() over Hud.message_corpus() -- which declares the set "
			+ "beside the producers it names -- plus both mute lines at their CURRENT "
			+ "keybinds, whose width follows the player's keymap and cannot be static. "
			+ "NOT covered, and named as such in message_corpus(): purchase and "
			+ "placement refusals, assembled from data no static caller can reach"),
		("a message renders trimmed to an ellipsis and nothing errors -- shorten the "
			+ "message, shorten the name, or widen the row (\"%s\")") % worst,
		no_budget_observations())


func _budget_hud_readouts() -> Dictionary:
	var stats: HBoxContainer = _stats_row()
	if stats == null:
		return uncomputed_budget(BUDGET_UNMEASURED, "hud_readouts",
			"Hud.WORST_CASE_TEXT", "res://game/hud.gd", "the widest readout's worst case",
			"no Root/TopBar/StatsRow in the running HUD",
			"a counter grows past its slot and renders trimmed, silently",
			no_budget_observations())
	var observations: Array[String] = []
	var worst_name: String = ""
	var worst_needed: float = 0.0
	var worst_budget: float = 0.0
	var worst_left: float = INF
	for readout: String in Hud.WORST_CASE_TEXT:
		var label: Label = stats.get_node_or_null(readout) as Label
		if label == null:
			observations.append("%s: declared a worst case but is not in the row" % readout)
			continue
		var font: Font = label.get_theme_font("font")
		var size_px: int = label.get_theme_font_size("font_size")
		if size_px <= 0:
			size_px = label.get_theme_default_font_size()
		if font == null or size_px <= 0:
			observations.append("%s: no theme font resolved, not measured" % readout)
			continue
		var worst_case: String = String(Hud.WORST_CASE_TEXT[readout])
		var needed: float = font.get_string_size(
			worst_case, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
		var slot: float = label.custom_minimum_size.x
		observations.append("%s: \"%s\" draws %s of %s px -- %s left" % [
			readout, worst_case, budget_number(needed), budget_number(slot),
			budget_number(slot - needed),
		])
		if slot - needed < worst_left:
			worst_left = slot - needed
			worst_name = readout
			worst_needed = needed
			worst_budget = slot
	if worst_name == "":
		return uncomputed_budget(BUDGET_UNMEASURED, "hud_readouts",
			"Hud.WORST_CASE_TEXT", "res://game/hud.gd", "the widest readout's worst case",
			"none of the declared readouts could be measured",
			"a counter grows past its slot and renders trimmed, silently",
			observations)
	return computed_budget("hud_readouts", "Hud.WORST_CASE_TEXT", "res://game/hud.gd",
		"%s worst case" % worst_name, worst_needed, worst_budget, "px",
		("Font.get_string_size() over Hud.WORST_CASE_TEXT's declared worst case for each "
			+ "readout, measured against that readout's LIVE slot in Root/TopBar/StatsRow"),
		("%s renders its longest value trimmed to an ellipsis and nothing errors -- widen "
			+ "its slot, which spends the stats-row budget below") % worst_name,
		observations)


## Hud.stats_row_budget() -- the four slots plus the separations plus the wave
## button -- against the width of the row they have to fit inside.
##
## The sum is the invariant, not any one width: widening a readout to fix the
## entry above is paid for out of this one, which is the coupling the two entries
## exist to make visible together.
func _budget_hud_stats_row() -> Dictionary:
	var stats: HBoxContainer = _stats_row()
	if stats == null or stats.get_child_count() <= 0 or stats.size.x <= 0.0:
		return uncomputed_budget(BUDGET_UNMEASURED, "hud_stats_row",
			"Hud.stats_row_budget()", "res://game/hud.gd", "the stats row's contents",
			"no Root/TopBar/StatsRow in the running HUD, or it has no width yet",
			"the readouts push the wave button off the right edge of the bar",
			no_budget_observations())
	var needed: float = Hud.stats_row_budget(stats.get_child_count() - 1)
	var observations: Array[String] = [
		("%d children, so %d separations of %d px, plus a %d px wave button" % [
			stats.get_child_count(), stats.get_child_count() - 1,
			Hud.STATS_SEPARATION, int(Hud.NEXT_WAVE_BUTTON_SIZE.x),
		]),
	]
	return computed_budget("hud_stats_row", "Hud.stats_row_budget()", "res://game/hud.gd",
		"stats row contents", needed, stats.size.x, "px",
		"Hud.stats_row_budget() against the live StatsRow's width",
		("the readouts stop fitting: with the Spacer in the row an over-long one shoves the "
			+ "wave button off the bar rather than overlapping it, which is not a fix"),
		observations)


func _stats_row() -> HBoxContainer:
	if hud == null:
		return null
	return hud.get_node_or_null("Root/TopBar/StatsRow") as HBoxContainer


## The selection panel's box against every line it can be asked to hold.
##
## The sixth budget, and the one this table was missing longest. It is the same
## SHAPE as hud_message_row — a fixed box, a derived worst-case corpus, a font
## measured in the real theme — and a different failure mode, which is why it needed
## its own entry rather than a wider message row. The status row CLIPS: an over-long
## line renders "Seeds 4…" and nothing moves. SelectionLabel autowraps: an over-long
## line grows the label by a row, and a VBoxContainer pushes Upgrade and Uproot down
## by that row, out through the panel's foot. Nothing overflows its own box at any
## point, so `findings` / `validate-ui` see a clean panel the whole way down.
##
## TWO numbers, reported together and graded differently, and the asymmetry is the
## whole design:
##
##   * **the widest per-plant line** against Hud.SELECTION_BOX_WIDTH. This is the
##     reading cycle 57 took by hand ("the cob's second line at ~190px of a 232px
##     box") to decide against adding words there, and then lost. It is reported, not
##     graded -- the label autowraps, so a line wider than the box is drawn rather
##     than clipped, and "over" here is a spend, not a break. Today the widest line in
##     the game is over the box by 34px and the panel is fine.
##   * **the vertical room left** under the stack's foot. This one is graded, because
##     this is the one that breaks: the row the wrap produced grows SelectionLabel,
##     and the VBox pushes Upgrade and Uproot down by it, through the panel's foot.
##
## Both are in `observations` on every reading, so the one that is not the gate is
## still the one a person needs before adding a word. Naming the widest LINE and not
## just its width is the actionable half: "232px" tells nobody which sentence to cut.
##
## Pure arithmetic over Hud's statics — no live node, deliberately. Unlike the stats
## row there is nothing to read off the running HUD that is not already a constant:
## SelectionBox's width is set from SELECTION_BOX_WIDTH and never resized, and the
## room under it is a statement about the DESIGN canvas rather than the window (see
## Hud.selection_room_below). So this one entry prices identically headless, windowed,
## and on a 21:9 screen, which is what a budget wants to be.
func _budget_hud_selection_panel() -> Dictionary:
	var corpus: Array[String] = Hud.selection_corpus()
	var priced: Dictionary = Hud.selection_panel_budget(
		corpus, Hud.SELECTION_BOX_WIDTH, Hud.selection_room_below())
	if not bool(priced["measured"]):
		return uncomputed_budget(BUDGET_UNMEASURED, "hud_selection_panel",
			"Hud.SELECTION_BOX_Y against Hud.selection_room_below()", "res://game/hud.gd",
			"the selection stack's foot",
			("the selection sweep measured nothing -- %d text(s), %d line(s), box %s px"
				% [int(priced["texts"]), int(priced["physical_lines"]),
					budget_number(float(priced["box_width"]))]),
			"a selection line wraps and pushes Upgrade and Uproot out through the panel foot",
			no_budget_observations())
	var width_left: float = float(priced["width_left"])
	var height_left: float = float(priced["height_left"])
	# Both readings, always, in the order a person asks them: what is the worst line,
	# and where does the stack end up. Naming the WIDEST LINE ITSELF is the actionable
	# half -- "232px" tells nobody which sentence to shorten.
	var observations: Array[String] = [
		("widest line is \"%s\" at %s of %s px -- %s px of horizontal room left"
			% [priced["widest_line"], budget_number(float(priced["widest_px"])),
				budget_number(float(priced["box_width"])), budget_number(width_left)]),
		("the tallest text wraps to %d row(s) at %s px each, so SelectionLabel stands %s px "
			+ "and the stack foots %s px into %s px of panel -- %s px of vertical room left")
			% [int(priced["rows"]), budget_number(float(priced["row_height"])),
				budget_number(float(priced["label_height"])),
				budget_number(float(priced["stack_height"])),
				budget_number(float(priced["room_below"])), budget_number(height_left)],
		("that tallest text is \"%s\"" % String(priced["tallest_text"]).replace("\n", " / ")),
		# The denominator. A corpus that swept nothing prices a roomy panel.
		("swept %d text(s) / %d physical line(s), derived from PlantCatalog.ids() crossed with "
			+ "Hud.selection_level_names() and Hud.selection_detail_corpus()")
			% [int(priced["texts"]), int(priced["physical_lines"])],
	]
	return computed_budget("hud_selection_panel",
		"Hud.SELECTION_BOX_Y against Hud.selection_room_below()", "res://game/hud.gd",
		"the selection stack's foot",
		float(priced["stack_height"]), float(priced["room_below"]), "px",
		("Hud.selection_panel_budget() over Hud.selection_corpus() -- every plant in "
			+ "PlantCatalog.ids() crossed with every ladder rung and every detail line, "
			+ "measured in the real theme font and word-wrapped to the box, then run "
			+ "through Label's own row arithmetic. Graded on the VERTICAL room only: the "
			+ "widest-line reading is in the observations because this label wraps rather "
			+ "than clips, so a line over the box is a spend of the vertical budget and not "
			+ "a break of its own. NOT covered: a detail assembled at runtime from something "
			+ "no static caller can reach -- there is none today, and the producers in "
			+ "hud.gd are what keeps it that way"),
		("a selection line wraps to an extra row, SelectionLabel grows, and the VBox pushes "
			+ "Upgrade and Uproot down through the panel's foot -- where they are still "
			+ "pressable by path and invisible to a player. Shorten the detail line, shorten "
			+ "the plant name, or move Hud.SELECTION_BOX_Y up (which spends the packet rack's "
			+ "4px clearance, so read that budget first)"),
		observations)


## WaveDirector.SIMULTANEOUS_PEST_CEILING against the worst wave in a sweep.
##
## The one dependent of Board.PATH_CORNERS that has a real ceiling, so it is the
## one that gets a number. Swept rather than sampled: the peak lands at the
## campaign finale (wave 16), where two queens, their brood headroom, a full
## swarm and a beetle column are all priced onto the road at once, and every
## endless wave after it is paced apart — so a probe at wave 100 would report
## the road at 29 of 40 and be wrong in the reassuring direction.
func _budget_pest_road_ceiling(sweep: int) -> Dictionary:
	var worst: int = 0
	var worst_wave: int = 0
	for wave: int in range(1, sweep + 1):
		var peak: int = WaveDirector.peak_simultaneous_pests(wave)
		if peak > worst:
			worst = peak
			worst_wave = wave
	if worst <= 0:
		return uncomputed_budget(BUDGET_UNMEASURED, "pest_road_ceiling",
			"WaveDirector.SIMULTANEOUS_PEST_CEILING", "res://game/wave_director.gd",
			"pests on the road at once",
			"the sweep of %d wave(s) found no wave that puts a pest on the road" % sweep,
			"more pests walk the road at once than it was ever sized for",
			no_budget_observations())
	var observations: Array[String] = [
		"worst of waves 1-%d is wave %d, at %d pests walking at once" % [sweep, worst_wave, worst],
		("the ceiling itself is reasoned from the road's length -- see the road_shape entry, "
			+ "which is what moving Board.PATH_CORNERS actually invalidates"),
	]
	return computed_budget("pest_road_ceiling", "WaveDirector.SIMULTANEOUS_PEST_CEILING",
		"res://game/wave_director.gd", "peak pests on the road",
		float(worst), float(WaveDirector.SIMULTANEOUS_PEST_CEILING), "pests",
		"WaveDirector.peak_simultaneous_pests() swept over waves 1-%d" % sweep,
		("the road holds more pests than the pacing was sized for and the frame rate is the "
			+ "thing that gives -- _paced_gap is the lever, not the wave table"),
		observations,
		# ENDLESS_APHID_SHARE + ENDLESS_BEETLE_SHARE sum to the ceiling exactly --
		# see BUDGET_SPENT_BY_DESIGN's own comment for why that earns a state of
		# its own instead of reading as an ordinary "spent".
		true)
