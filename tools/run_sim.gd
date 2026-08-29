class_name RunSim
extends RefCounted

## A whole run of this game, played by nobody, one physics frame at a time.
##
## `test_combat.gd`'s `_over_promise_run` already drives ONE wave over the real Board,
## the real Plant subclasses, the real Kernel and the real WaveDirector schedule. This is
## that idea carried across the wave boundary: seeds, lives, plant identity and plant
## HEALTH survive from one wave to the next, a `SeedBank` is in the loop so plants are
## paid for and packets are bought, and the thing that decides what to buy and where to
## put it is a `Callable` rather than a hand-listed array of cells.
##
## WHY IT HAND-STEPS instead of hosting a `Game` and awaiting frames. `Game` runs
## perfectly well headless (the suite hosts `res://game/game.tscn` in dozens of tests),
## and driving it would re-derive nothing. But `CompostMeter._process` and `Game._process`
## take a VARIABLE delta, and "same seed, same records, twice" is an acceptance criterion
## here. A run that awaits real frames is reproducible only up to how busy the machine
## was. So this steps every node by hand at a fixed dt, exactly as `_over_promise_run`
## does, and nothing in the tree runs a frame this loop did not drive.
##
## THE PRICE OF THAT, stated plainly because it is the thing most likely to go stale:
## the economy below is a re-derivation of `Game`'s, not a call into it. Every branch that
## moves seeds cites the `game/game.gd` function it mirrors BY NAME rather than by line,
## because nothing checks a citation inside GDScript and a line number here would rot
## unread. `test/unit/test_playtest.gd` pins the shapes it can.
##
## `queue_free()` never lands, because the tree runs no frame between our steps: a Tween
## scheduled by `Pest._play_death` never fires its callback. So this frees corpses and
## spent kernels itself, at the END of the frame that produced them, once every step that
## could still be holding a reference has run. Without that a 25-wave run leaves several
## thousand dead pests in the tree-global `pests` group, which `Kernel._physics_process`
## and `Plant._live_pests` both scan every frame, and the run slows to a crawl on garbage.

const DT: float = 1.0 / 60.0

## Every key a wave record carries, and the ONLY place the list is written down.
##
## Beads t5yy.2, .3 and .4 all read these records. A reader that hand-lists the keys it
## expects drifts silently the day a key is renamed here; one that iterates this constant
## fails loudly. `test_playtest.gd` asserts each record's key set IS this set, in both
## directions, so a key added to the builder without a line here is a failure and so is a
## line here the builder never fills.
const RECORD_KEYS: Array[StringName] = [
	&"wave", &"weather", &"threat", &"threat_level",
	&"seeds_start", &"seeds_end", &"seeds_earned",
	&"seeds_from_kills", &"seeds_from_growth", &"seeds_from_husks",
	&"seeds_spent_plants", &"seeds_spent_packets",
	&"lives_start", &"lives_end",
	&"spawned", &"killed", &"escaped",
	&"plants_alive", &"plants_lost", &"plants_placed", &"plants_sported",
	&"packets_bought", &"unlocked", &"health_total", &"frames",
]

## Order verbs a policy may return. Anything else is refused BY NAME rather than ignored:
## a typo'd op that silently did nothing would read, in the records, as a policy that
## chose to do nothing.
const OP_PLANT := &"plant"
const OP_PACKET := &"packet"
const OP_UPGRADE := &"upgrade"

## The two ends of the skill range this file ships, by the name a caller passes.
##
## `tools/playtest.gd --policy NAME` resolves through `policy_named()` rather than naming
## either of these, so a third policy added here is selectable the day it exists;
## `POLICY_NAMES` is what a test and the flag's error message both iterate, so a policy
## added to one and not the other fails loudly instead of being quietly unplayable.
const POLICY_GREEDY := &"greedy"
const POLICY_THICKEN := &"thicken"
const POLICY_NAMES: Array[StringName] = [POLICY_GREEDY, POLICY_THICKEN]

# -- configuration, set before play() ----------------------------------------

var difficulty: StringName = Game.DIFFICULTY_STANDARD
var endless: bool = false
## How many waves this run may attempt. A whole-run loop is exactly the hazard
## plant-tower-defense-x44s names, so BOTH ceilings here are hard failures that name the
## wave rather than conditions that hang.
var wave_ceiling: int = 30
var frame_ceiling_per_wave: int = 30000
## How many times the policy may be re-asked between two waves. A policy that keeps
## returning orders it can afford would otherwise spin here forever.
var policy_round_ceiling: int = 200
var roll_seed: int = 1
var road_corners: Array[Vector2i] = []
## `func(sim: RunSim) -> Array`, called repeatedly between waves until it returns nothing.
## Left unset it is `greedy_cover`.
var policy: Callable = Callable()
## Which of `POLICY_NAMES` the run is playing, for the record and the summary line.
##
## A LABEL, and it is only trustworthy because `use_policy()` is the one thing that writes
## it and it writes both halves at once. Every number a sweep records is a statement about
## the policy that produced it (see `tools/playtest_report.py`'s NOT COVERED note), so a
## committed baseline that did not say which policy played it is a table of numbers with
## the most load-bearing column missing. A caller that sets `policy` by hand — every test
## in `test_playtest.gd` that swaps in a one-liner — leaves this alone and writes no record.
var policy_name: StringName = POLICY_GREEDY
## Whether the driver sweeps every husk the frame it can reach it. TRUE is perfect play
## and it is deliberately the default: `seeds_from_husks` is recorded separately, so a
## reader can subtract the whole of it and see the floor a player who never sweeps gets.
var sweep_husks: bool = true

# -- live state, readable by a policy ----------------------------------------

var board: Board = null
var bank: SeedBank = null
var compost: CompostMeter = null
var director: WaveDirector = null
## cell -> Plant, exactly the shape `Game._plants` has, so `CrossBreeder.roll` takes it
## unmodified.
var plants: Dictionary = {}
var lives: int = 0
var starting_lives: int = 0
## The profile's `seed_yield`, read in `play()` beside lives and prep, and the thing
## `_on_pest_died` and `_on_plant_grew_seeds` pay through. Mirrors `Game.seed_yield`.
##
## 1.0 UNTIL `play()` READS THE PROFILE, so a policy or a test that reads it before the run
## starts sees the designed game rather than a zero that would silently make every kill
## worth one seed.
var seed_yield: float = 1.0
var weather: StringName = WaveDirector.WEATHER_CLEAR
var wave: int = 0

# -- results ------------------------------------------------------------------

var records: Array[Dictionary] = []
## "" when the run ended for a reason the game itself has: the beds ran out, or the table
## did. Non-empty means the DRIVER stopped it, and it names the wave.
var failure: String = ""
var ended: StringName = &"unstarted"
var waves_played: int = 0
## Pests and plants standing in the tree-global groups before this run put anything there
## — a sibling test's, since the runner keeps stepping while a test awaits. Counted rather
## than assumed clean; every caller asserts they are zero. See
## `.claude/skills/godot-test-isolation`.
var foreign_pests: int = 0
var foreign_plants: int = 0

var _host: Node = null
var _pests: Array[Pest] = []
var _kernels: Array[Kernel] = []
var _reap: Array[Node] = []
var _cross_clock: float = 0.0
var _cross_rng := RandomNumberGenerator.new()
var _cover_cache: Dictionary = {}
var _prep_seconds: float = 0.0
## Per-wave counters, zeroed by _begin_wave().
var _w: Dictionary = {}


## Plays the whole run and returns one record per wave.
##
## `on_host` must already be in a tree: `Plant`, `Pest` and `Kernel` all read tree-global
## groups, and a node outside the tree joins none of them. Never awaits, so the caller's
## own settle frames are the last frames anything but this loop drives.
func play(on_host: Node) -> Array[Dictionary]:
	_host = on_host
	if _host == null or not _host.is_inside_tree():
		failure = "the host is not in a tree; the groups would be empty and every plant would fire at nothing"
		ended = &"refused"
		return records
	board = Board.new()
	if not road_corners.is_empty():
		# A REFUSED ROAD RETURNS NOTHING AND SAYS SO, rather than falling back to the
		# shipped snake — the same rule `_over_promise_run`'s `road_refusal` follows, and
		# for the same reason: a corpus run silently measuring the default board would
		# produce a plausible number on the one axis where plausible is indistinguishable
		# from right.
		var refusal: String = board.set_road(road_corners)
		if refusal != "":
			board.free()
			board = null
			failure = "road refused: %s" % refusal
			ended = &"refused"
			return records
	var tree: SceneTree = _host.get_tree()
	foreign_pests = tree.get_nodes_in_group("pests").size()
	foreign_plants = tree.get_nodes_in_group("plants").size()

	var profile: Dictionary = Game.difficulty_profile(difficulty)
	starting_lives = int(profile["lives"])
	lives = starting_lives
	_prep_seconds = float(profile["prep_seconds"])
	# The economy axis, mirroring `Game._ready`'s read of the same key. Every value this
	# driver takes from a difficulty is read HERE, off one `difficulty_profile()` lookup, so
	# there is one place to look when asking what a profile changes about a run.
	seed_yield = float(profile["seed_yield"])
	bank = SeedBank.new()
	bank.set_seed(roll_seed)
	# The purse is set directly rather than through add_seeds(), so the difficulty's float
	# does not count as income. `seeds_earned_total` is the scoreboard (see SeedBank), and
	# a gentle run would otherwise start 15 points of "score" ahead of a harsh one for
	# nothing it did.
	bank.seeds = int(profile["starting_seeds"])
	compost = CompostMeter.new()
	director = WaveDirector.new()
	director.set_seed(roll_seed)
	director.endless = endless
	# A stream of its own, seeded, for the reason `Game._cross_rng`'s header gives.
	#
	# This used to be a WORKAROUND: `Game` left its own copy randomized, so a driver that
	# wanted reproducible gardens had no choice but to own one. That is fixed
	# (plant-tower-defense-4n66) — `Game.set_run_seed` now pins all three streams from one
	# value, which is what the three lines above and this one do by hand. The duplication
	# stays because RunSim is deliberately not a Game: it hosts no tree, no HUD and no
	# wave director children, and reaching for `Game.set_run_seed` would mean hosting one.
	# If a fourth stream is ever added to a run, it has to be added in BOTH places, and
	# `tools/rng_seed_check.py` is the gate that notices the game half.
	_cross_rng.seed = roll_seed
	ended = &"played"

	while waves_played < wave_ceiling:
		if not director.has_more_waves():
			ended = &"cleared"
			break
		# THE COUNTERS ARE ZEROED FIRST, before the policy spends and before the prep
		# window pays a Sunflower. Both of those belong to the wave they precede — a
		# driver that opened the record at `start_next_wave()` would file the whole of a
		# wave's shopping against the PREVIOUS wave and then wipe it, so `plants_placed`
		# would read zero for every wave and nobody would be able to tell from the numbers.
		_begin_wave()
		_run_policy()
		if failure != "":
			break
		_step_prep()
		if not _play_one_wave():
			break
		waves_played += 1
		if lives <= 0:
			ended = &"eaten"
			break
	if failure == "" and ended == &"played" and waves_played >= wave_ceiling:
		# Not a failure: a ceiling that was ASKED for is the run ending where the caller
		# said it should. The blown-ceiling failure is the per-wave frame one.
		ended = &"ceiling"
	return records


## One line naming what happened and how much of it there was.
##
## The denominator is the point. `tools/run_tests.py` reports a driver whose loop never
## entered as a clean pass, so a caller has to be able to see the wave count it actually
## played beside the one it asked for. See CLAUDE.md's note on vacuity.
func summary_line() -> String:
	return "Run: %d wave(s) played of %d attempted | %s | difficulty=%s policy=%s endless=%s seed=%d | lives %d/%d | seeds earned %d%s" % [
		waves_played, wave_ceiling, ended, difficulty, policy_name, str(endless), roll_seed,
		lives, starting_lives, (0 if bank == null else bank.seeds_earned_total),
		("" if failure == "" else " | FAILED: %s" % failure)]


## Frees everything this run built. The host's own children go with the host; these four
## are parentless by design, so nothing else will.
func dispose() -> void:
	for node: Node in _reap:
		if is_instance_valid(node):
			node.free()
	_reap.clear()
	# THE ONES STILL STANDING TOO, and this is not tidiness. Clearing `plants` drops this
	# object's reference and leaves the NODE parented to the host, inside the tree-global
	# `plants` and `pests` groups, where the NEXT run's contamination census finds it.
	# Measured before the fix: a three-difficulty invocation reported "4 foreign pest(s)
	# and 12 foreign plant(s) were already in the tree" on its third run -- runs one and
	# two's gardens, still standing. Every number in those two runs described a board
	# somebody else had planted, and the census said so on stderr while the records were
	# written anyway.
	# UNTYPED LOOP VARIABLES AND is_instance_valid BEFORE THE CAST, both load-bearing.
	# `dispose()` is reached from two orders: a sweep frees nothing first, and
	# `test_playtest.gd._play` frees the HOST first -- which frees every child with it, so
	# by the time this runs the dictionary holds freed objects. `var plant := standing as
	# Node` on one of those is itself the error ("Trying to cast a freed object"), before
	# any validity check written after it can run, and it aborts the coroutine mid-method
	# where a `-> String` test reports it as a pass.
	for standing: Variant in plants.values():
		if standing != null and is_instance_valid(standing):
			(standing as Node).free()
	for pest: Variant in _pests:
		if pest != null and is_instance_valid(pest):
			(pest as Node).free()
	for kernel: Variant in _kernels:
		if kernel != null and is_instance_valid(kernel):
			(kernel as Node).free()
	for owned: Node in [board, bank, compost, director]:
		if owned != null and is_instance_valid(owned):
			owned.free()
	board = null
	bank = null
	compost = null
	director = null
	plants.clear()
	_pests.clear()
	_kernels.clear()


# -- the wave loop ------------------------------------------------------------

func _play_one_wave() -> bool:
	director.start_next_wave()
	wave = director.current_wave
	_apply_weather(WaveDirector.weather_for(wave))
	var pending: Array[Dictionary] = []
	var handle := func(species: StringName, mutations: Array) -> void:
		pending.append({"species": species, "mutations": mutations})
	director.spawn_requested.connect(handle)
	var frame: int = 0
	while frame < frame_ceiling_per_wave:
		frame += 1
		director._process(DT)
		for entry: Dictionary in pending:
			var pest: Pest = _new_pest(StringName(entry["species"]))
			for which: Variant in entry["mutations"]:
				pest.apply_mutation(StringName(which))
			_w["spawned"] = int(_w["spawned"]) + 1
		pending.clear()
		_step_frame()
		if lives <= 0:
			break
		if int(_w["spawned"]) >= director.current_wave_pest_count() and _live_count() == 0:
			break
	director.spawn_requested.disconnect(handle)
	_w["frames"] = frame
	records.append(_record())
	if frame >= frame_ceiling_per_wave:
		# NAMES THE WAVE, and fails rather than hanging. A whole-run loop is
		# plant-tower-defense-x44s's hazard exactly, and a driver that quietly returned a
		# short record here would report the wave as survived.
		failure = ("wave %d spent its whole %d-frame ceiling without clearing (%d of %d spawned, %d still walking)"
			% [wave, frame_ceiling_per_wave, int(_w["spawned"]),
				director.current_wave_pest_count(), _live_count()])
		ended = &"stalled"
		waves_played += 1
		return false
	return true


## The prep window between two waves, stepped for real rather than skipped.
##
## `Plant._regrow` and `Sunflower._act` both run off physics frames, so a driver that
## jumped straight from one wave to the next would carry chewed plants forward that the
## real game heals, and would never pay a Sunflower for the seconds it earns its cell.
## The seconds come from the difficulty profile, which is the only place they are stated —
## and they are one of the three things `gentle`, `standard` and `harsh` differ by, so a
## driver that skipped them would make two of the three difficulties the same run.
func _step_prep() -> void:
	var frames: int = int(round(_prep_seconds / DT))
	for i: int in range(frames):
		_step_frame()


## One physics frame, in tree order: plants, then the kernels they launched, then the
## pests, then the ground. Mirrors the order `_over_promise_run` established and the
## reason for it — a node added mid-physics is held back a frame in a real tree.
func _step_frame() -> void:
	for cell: Vector2i in plants.keys():
		var plant := plants[cell] as Plant
		if plant == null or not is_instance_valid(plant) or plant.is_destroyed():
			continue
		plant._physics_process(DT)
	var known: int = _kernels.size()
	for node: Node in _host.get_children():
		var fresh := node as Kernel
		if fresh != null and not _kernels.has(fresh):
			fresh.set_physics_process(false)
			_kernels.append(fresh)
	for i: int in range(known):
		var shot: Kernel = _kernels[i]
		if not is_instance_valid(shot) or shot.is_queued_for_deletion():
			continue
		shot._physics_process(DT)
	for pest: Pest in _pests.duplicate():
		if is_instance_valid(pest) and pest.is_alive():
			pest._physics_process(DT)
	compost._process(DT)
	if sweep_husks:
		_sweep()
	_tick_cross_breeding(DT)
	_collect_garbage()


func _live_count() -> int:
	var n: int = 0
	for pest: Pest in _pests:
		if is_instance_valid(pest) and pest.is_alive():
			n += 1
	return n


## Frees the corpses, the spent kernels and the eaten plants this frame produced.
##
## At the END of the frame and never inside a signal handler: `died` fires from inside
## `Kernel._physics_process`, and freeing the pest there would pull the node out from
## under the loop that is iterating it.
func _collect_garbage() -> void:
	var still: Array[Kernel] = []
	for shot: Kernel in _kernels:
		if not is_instance_valid(shot):
			continue
		if shot.is_queued_for_deletion():
			_host.remove_child(shot)
			shot.free()
			continue
		still.append(shot)
	_kernels = still
	var walking: Array[Pest] = []
	for pest: Pest in _pests:
		if not is_instance_valid(pest):
			continue
		if pest.is_alive():
			walking.append(pest)
			continue
		_host.remove_child(pest)
		pest.free()
	_pests = walking
	for node: Node in _reap:
		if not is_instance_valid(node):
			continue
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()
	_reap.clear()


# -- the economy, mirrored from Game ------------------------------------------

## Mirrors `Game._new_pest`. One constructor for scheduled pests and for brood, the split
## that function names: a pest that arrives because a queen burst is the same object, on
## the same route, paying the same seeds.
##
## The setup pair itself -- `pest.setup()` and `pest.apply_wave_scaling()` -- is
## `Game.setup_pest`, the shared static both sides call (plant-tower-defense-b0mp); the
## parenting, the two signals and the list append below stay here because they differ
## from `Game`'s (a headless host, no ambience to refresh).
func _new_pest(species: StringName) -> Pest:
	var pest := Pest.new()
	_host.add_child(pest)
	pest.set_physics_process(false)
	Game.setup_pest(pest, species, board, director.current_wave)
	pest.died.connect(_on_pest_died)
	pest.escaped.connect(_on_pest_escaped)
	_pests.append(pest)
	return pest


## Mirrors `Game._on_pest_died`: the difficulty's yield on the pest's value, then the
## weather on the direct seeds, then the husk, then the brood — in that order, because the
## brood is the consequence of the kill rather than part of paying for it.
##
## `Game.kill_payout` is CALLED, not re-derived (plant-tower-defense-b0mp) — both the seed
## price and the husk price are the ONE shared static now, so there is no second copy of
## either roundings to keep in step. `Game._on_pest_died` calls the same function.
func _on_pest_died(pest: Pest) -> void:
	_w["killed"] = int(_w["killed"]) + 1
	var payout: Dictionary = Game.kill_payout(pest, seed_yield, weather)
	var paid: int = int(payout["seeds"])
	bank.add_seeds(paid)
	_w["seeds_from_kills"] = int(_w["seeds_from_kills"]) + paid
	compost.drop_husk(pest.position, int(payout["husk"]))
	_spawn_brood(pest)


## Mirrors `Game._on_pest_escaped`. A bed per escapee, and the run is over the moment the
## last one goes.
func _on_pest_escaped(_pest: Pest) -> void:
	_w["escaped"] = int(_w["escaped"]) + 1
	lives -= 1
	if lives <= 0:
		lives = 0


## Mirrors `Game._spawn_brood`, now `Game.brood_entries` — the shared static both sides
## call for the split geometry (plant-tower-defense-b0mp). Only a KILLED boss bursts here;
## an escaped one has already taken her bed and three aphids past the exit would have
## nowhere to walk, which is why the guard stays behind rather than joining the static.
func _spawn_brood(parent: Pest) -> void:
	if lives <= 0:
		return
	for entry: Dictionary in Game.brood_entries(parent):
		var child: Pest = _new_pest(entry["species"])
		child.enter_road_at(entry["position"], entry["leg"])


## Every husk within reach of itself, swept. Perfect play, on purpose — see `sweep_husks`.
## The seeds land in their own record key so the no-sweeping floor is recoverable by
## subtraction rather than by a second run.
func _sweep() -> void:
	for husk: Dictionary in compost.husks():
		var value: int = compost.collect_at(husk["position"] as Vector2)
		if value <= 0:
			continue
		bank.add_seeds(value)
		_w["seeds_from_husks"] = int(_w["seeds_from_husks"]) + value


## Mirrors `Game._on_plant_grew_seeds` — a Sunflower's payout, after the profile's yield.
func _on_plant_grew_seeds(amount: int) -> void:
	var paid: int = Game.seeds_after_yield(amount, seed_yield)
	bank.add_seeds(paid)
	_w["seeds_from_growth"] = int(_w["seeds_from_growth"]) + paid


## Mirrors `Game._on_plant_destroyed`. No refund: a plant eaten is not a plant sold.
func _on_plant_destroyed(plant: Plant) -> void:
	_w["plants_lost"] = int(_w["plants_lost"]) + 1
	if plants.get(plant.cell) == plant:
		plants.erase(plant.cell)
	_cover_cache.clear()
	_reap.append(plant)


## Mirrors `Game._apply_weather`, now `Game.apply_weather_over` — the shared static both
## sides call for the fire-rate multiplier and rain's heal (plant-tower-defense-b0mp). The
## banner and the overlay are the game's own half; there is no HUD here to reach them.
func _apply_weather(next: StringName) -> void:
	weather = next
	Game.apply_weather_over(plants, next)


## Mirrors `Game._refresh_neighbour_buffs`, now `Game.refresh_neighbour_buffs_over` —
## the shared static both sides call (plant-tower-defense-b0mp), so the mint-buff rule
## itself (a Mint beside a Mint buffs nothing) lives in one place rather than two.
func _refresh_neighbour_buffs() -> void:
	Game.refresh_neighbour_buffs_over(plants)


## Mirrors `Game._tick_cross_breeding` and `Game._sprout_sport`. The one planting path
## that never touches `SeedBank` — which is exactly why a balance driver that left it out
## would under-report how many plants a long run ends up holding.
func _tick_cross_breeding(delta: float) -> void:
	_cross_clock += delta
	if _cross_clock < CrossBreeder.TICK_SECONDS:
		return
	# Subtracted rather than zeroed, so a frame that overshoots does not quietly lengthen
	# the interval.
	_cross_clock -= CrossBreeder.TICK_SECONDS
	var sprout: Dictionary = CrossBreeder.roll(plants, board, _cross_rng)
	if sprout.is_empty():
		return
	var kind: StringName = sprout["kind"]
	var cell: Vector2i = sprout["cell"]
	if plants.has(cell) or not board.is_buildable_for(cell, kind):
		return
	_install(kind, cell, true)
	_w["plants_sported"] = int(_w["plants_sported"]) + 1


## Mirrors `Game._install_plant`. Charges nothing: the two callers pay (or do not) for
## themselves, the same split `Game` keeps between `place_plant` and `_sprout_sport`.
func _install(id: StringName, cell: Vector2i, sport: bool) -> Plant:
	var plant: Plant = Game.new_plant(id)
	plant.is_sport = sport
	_host.add_child(plant)
	plant.set_physics_process(false)
	plant.setup(id, cell, board)
	plants[cell] = plant
	plant.destroyed.connect(_on_plant_destroyed)
	if plant.has_signal("grew_seeds"):
		plant.connect("grew_seeds", _on_plant_grew_seeds)
	plant.fire_interval_scale = WaveDirector.fire_interval_scale_for(weather)
	_cover_cache.clear()
	_refresh_neighbour_buffs()
	return plant


# -- the policy seam ----------------------------------------------------------

## Asks the policy for orders and executes them until it stops asking.
##
## Re-asked rather than handed one batch, so a policy can read the purse it just spent
## from instead of simulating it. `policy_round_ceiling` is the guard: a policy that keeps
## returning affordable orders would otherwise spin here for the rest of the run.
func _run_policy() -> void:
	var chooser: Callable = policy if policy.is_valid() else func(sim: RunSim) -> Array:
		return greedy_cover(sim)
	var round_no: int = 0
	while round_no < policy_round_ceiling:
		round_no += 1
		var orders: Variant = chooser.call(self)
		if orders == null or (orders as Array).is_empty():
			return
		var acted: bool = false
		for order: Dictionary in orders as Array:
			if _execute(order) == "":
				acted = true
		if not acted:
			return
	failure = "the policy was still issuing orders after %d rounds before wave %d" % [
		policy_round_ceiling, director.current_wave + 1]
	ended = &"stalled"


## Runs one order. "" means it happened; anything else is the reason it did not, in the
## same shape `Game.place_plant` returns.
func _execute(order: Dictionary) -> String:
	var op: StringName = StringName(order.get("op", &""))
	match op:
		OP_PLANT:
			var id: StringName = StringName(order.get("id", &""))
			var cell: Vector2i = order.get("cell", Vector2i(-1, -1))
			if not PlantCatalog.has(id):
				return "no such plant: %s" % id
			if not board.is_buildable_for(cell, id):
				return "not buildable"
			if plants.has(cell):
				return "something is already growing there"
			# Priced BEFORE the charge, the same load-bearing order `Game.place_plant`
			# keeps: `pay_for_plant()` clears `free_starter_available` on the way through,
			# so asking afterwards would bill the one free cob at full price.
			var plant_price: int = bank.placement_cost(id)
			if not bank.pay_for_plant(id):
				return "not paid for"
			_w["seeds_spent_plants"] = int(_w["seeds_spent_plants"]) + plant_price
			_w["plants_placed"] = int(_w["plants_placed"]) + 1
			_install(id, cell, false)
			return ""
		OP_PACKET:
			var tier: StringName = StringName(order.get("tier", &"common"))
			var cost: int = int((SeedBank.PACKET_TIERS.get(tier, {}) as Dictionary).get("cost", 0))
			if bank.buy_packet(tier) == &"":
				return "packet refused"
			_w["seeds_spent_packets"] = int(_w["seeds_spent_packets"]) + cost
			_w["packets_bought"] = int(_w["packets_bought"]) + 1
			return ""
		OP_UPGRADE:
			var at: Vector2i = order.get("cell", Vector2i(-1, -1))
			var growing := plants.get(at) as Plant
			if growing == null or not growing.has_upgrades() or growing.is_max_level():
				return "nothing upgradeable there"
			var level_price: int = growing.upgrade_cost()
			if not bank.spend(level_price):
				return "not enough seeds"
			growing.upgrade()
			_w["seeds_spent_plants"] = int(_w["seeds_spent_plants"]) + level_price
			_cover_cache.clear()
			return ""
		_:
			return "no such op: %s" % op


# -- coverage, derived rather than listed -------------------------------------

## Every road cell something standing can reach right now. The same union
## `Game.covered_road_cells` builds, and read the same way — off `engagement_reach`, so a
## Sundew's sap radius does not count as a lane being defended.
func covered_road_cells() -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector2i in plants:
		var plant := plants[cell] as Plant
		if plant == null or not is_instance_valid(plant) or plant.is_destroyed():
			continue
		for road: Vector2i in cover_of(cell, Game.engagement_reach(plant.kind)):
			out[road] = true
	return out


## What a plant of `reach` standing on `cell` would cover, cached. The cache is cleared
## whenever the garden changes shape; the reach is quantised to a whole pixel for the key,
## which is safe because `PlantCatalog.reach` is a whole number for every plant and the
## comparison inside `covered_road_cell_list` is a distance in pixels.
func cover_of(cell: Vector2i, reach: float) -> Array[Vector2i]:
	var key: String = "%d,%d,%d" % [cell.x, cell.y, int(round(reach))]
	if _cover_cache.has(key):
		return _cover_cache[key]
	var list: Array[Vector2i] = PlacementPreview.covered_road_cell_list(board, cell, reach)
	_cover_cache[key] = list
	return list


# -- the default policy -------------------------------------------------------

## A greedy cover, in four clauses in a fixed order: plug the biggest hole you can pay
## for, then buy income, then buy an unlock, then grow what you have.
##
## Honest rather than good. Nothing here is tuned, and nothing here decides whether a
## number is right — that is beads t5yy.2/.3/.4, which swap this out. What it MUST be is
## DERIVED: every candidate cell comes from `board.is_buildable_for`, every price from
## `SeedBank.placement_cost`, and every score from the real coverage map, so a plant added
## to `PlantCatalog` is played by this policy the day it exists rather than the day
## somebody remembers to add it to a list in here.
static func greedy_cover(sim: RunSim) -> Array:
	var covered: Dictionary = sim.covered_road_cells()
	var best: Dictionary = best_placement(sim, true)
	if not best.is_empty():
		return [best]

	# Nothing left to cover that this purse can reach. Buy the garden some income, so a
	# run that has plugged its holes is not sitting on seeds it will never spend.
	if covered.size() >= sim.board.road_cells().size():
		for id: StringName in PlantCatalog.ids():
			if Game.engagement_reach(id) > 0.0 or not sim.bank.can_afford(id):
				continue
			var open: Array[Vector2i] = sim.open_cells(id)
			if open.is_empty():
				continue
			return [{"op": OP_PLANT, "id": id, "cell": open[0]}]

	var tier: StringName = sim.cheapest_affordable_packet()
	if tier != &"":
		return [{"op": OP_PACKET, "tier": tier}]

	var grow: Vector2i = sim.cheapest_affordable_upgrade()
	if grow != Vector2i(-1, -1):
		return [{"op": OP_UPGRADE, "cell": grow}]
	return []


## The single best plant-and-cell this purse can buy, scored per seed, or {} for none.
##
## THE BOOLEAN IS THE WHOLE DIFFERENCE BETWEEN THE TWO POLICIES SHIPPED HERE, which is why
## it is one function taking a flag rather than two loops that would drift
## (plant-tower-defense-i8oh). `only_new` scores a placement on the road cells NOTHING
## reaches yet — the greedy cover, and the clause whose `gain <= 0` is why greedy stops
## planting the moment the road is covered. `only_new = false` scores it on the road it
## reaches AT ALL, so a lane that is already covered once is still worth covering twice.
##
## Everything else is identical and stays DERIVED: candidates from `open_cells` (which
## reads `board.is_buildable_for`), prices from `SeedBank.placement_cost`, scores from the
## real coverage map. A plant added to `PlantCatalog` is played by both policies the day it
## exists.
##
## STRICTLY GREATER, over `PlantCatalog.ids()` and `open_cells` in their fixed orders: two
## runs on one seed have to build the same garden, and a `>=` would make the winner depend
## on which of two equally-scored placements happened to be visited last.
static func best_placement(sim: RunSim, only_new: bool) -> Dictionary:
	var covered: Dictionary = sim.covered_road_cells() if only_new else {}
	var best: Dictionary = {}
	var best_gain: float = 0.0
	for id: StringName in PlantCatalog.ids():
		if not sim.bank.can_afford(id):
			continue
		var reach: float = Game.engagement_reach(id)
		if reach <= 0.0:
			continue
		var price: int = maxi(1, sim.bank.placement_cost(id))
		for cell: Vector2i in sim.open_cells(id):
			var gain: int = 0
			for road: Vector2i in sim.cover_of(cell, reach):
				if not covered.has(road):
					gain += 1
			if gain <= 0:
				continue
			var per_seed: float = float(gain) / float(price)
			if per_seed > best_gain:
				best_gain = per_seed
				best = {"op": OP_PLANT, "id": id, "cell": cell}
	return best


## The OTHER end of the skill range: `greedy_cover` with its stopping rule replaced.
##
## `greedy_cover` stops planting the moment `covered.size()` reaches the road, because from
## there every remaining placement scores `gain <= 0` and `best_placement(sim, true)` comes
## back empty. From wave 3 on it holds at six plants, replaces what dies and banks the rest.
## THIS policy, at exactly that moment — when no placement adds NEW coverage — plants for
## TOTAL coverage instead of stopping, which thickens the lane rather than leaving every
## cell of road singly covered.
##
## THREE LINES, and they are the whole policy. The first is greedy's own first clause,
## unchanged and reached through the same function greedy reaches it through. The second is
## the replacement stopping rule. The third hands the rest of the decision — income,
## packets, upgrades — back to `greedy_cover` unmodified, which re-asks its first clause
## (empty, by the line above) and falls through to its remaining three. So the ONLY
## behavioural difference between the two policies is `only_new`, and a run that separates
## them separated on that.
##
## WHY IT EXISTS (plant-tower-defense-i8oh). The finding that bead records is the GAP
## between these two policies — overrun a third of the way in at one end, a far deeper run
## at the other — and a gap whose far end nothing in the repo can reproduce is an anecdote
## rather than a measurement. Both ends now sweep from `tools/playtest.gd --policy`, and
## `docs/playtest-runs.jsonl` carries both.
##
## NOT A RECOMMENDATION. Neither policy is tuned and neither is a claim about how a person
## plays; both are machines, and the point is the size of the interval between them.
static func thicken_cover(sim: RunSim) -> Array:
	var best: Dictionary = best_placement(sim, true)
	if best.is_empty():
		best = best_placement(sim, false)
	if not best.is_empty():
		return [best]
	return greedy_cover(sim)


## Selects a named policy AND the label that goes into the record, in one call so the two
## cannot disagree. "" means it took; anything else is the reason it did not, naming every
## policy this build carries rather than only the one that was refused.
func use_policy(name: StringName) -> String:
	var chosen: Callable = policy_named(name)
	if not chosen.is_valid():
		var known: PackedStringArray = PackedStringArray()
		for known_name: StringName in POLICY_NAMES:
			known.append(String(known_name))
		return "no such policy: %s (this build carries %s)" % [name, ", ".join(known)]
	policy = chosen
	policy_name = name
	return ""


## The policy `name` selects, or an invalid Callable for a name this build does not carry.
##
## An INVALID CALLABLE RATHER THAN A FALLBACK, which is the opposite of
## `Game.difficulty_profile`'s rule and deliberately so. A difficulty name arrives from a
## SAVE, where the honest answer to "written by a later build" is the designed game; a
## policy name arrives from a command line a person just typed, where silently measuring a
## policy they did not ask for produces a plausible number on the one axis where plausible
## is indistinguishable from right. `tools/playtest.gd` refuses the name and says so.
static func policy_named(name: StringName) -> Callable:
	match name:
		POLICY_GREEDY:
			return func(sim: RunSim) -> Array: return greedy_cover(sim)
		POLICY_THICKEN:
			return func(sim: RunSim) -> Array: return thicken_cover(sim)
	return Callable()


## Every cell `id` could legally go in right now, in a fixed scan order so two runs on one
## seed build the same garden.
func open_cells(id: StringName) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var cell := Vector2i(x, y)
			if plants.has(cell):
				continue
			if board.is_buildable_for(cell, id):
				out.append(cell)
	return out


## The cheapest packet tier that still has stock and that the purse can pay for, or &"".
## Read off `SeedBank.PACKET_ORDER` and `packet_pool` rather than off a price written here,
## for the reason `SeedBank.cheapest_packet_for` gives at length.
func cheapest_affordable_packet() -> StringName:
	for tier: StringName in SeedBank.PACKET_ORDER:
		if bank.packet_pool(tier).is_empty():
			continue
		if bank.seeds >= int((SeedBank.PACKET_TIERS[tier] as Dictionary)["cost"]):
			return tier
	return &""


## The cell holding the cheapest upgrade this purse can pay for, or (-1, -1).
func cheapest_affordable_upgrade() -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_price: int = 0
	for cell: Vector2i in plants:
		var plant := plants[cell] as Plant
		if plant == null or not is_instance_valid(plant) or plant.is_destroyed():
			continue
		if not plant.has_upgrades() or plant.is_max_level():
			continue
		var price: int = plant.upgrade_cost()
		if price <= 0 or price > bank.seeds:
			continue
		if best == Vector2i(-1, -1) or price < best_price:
			best = cell
			best_price = price
	return best


# -- records ------------------------------------------------------------------

func _begin_wave() -> void:
	_w = {
		"seeds_start": bank.seeds, "lives_start": lives,
		"earned_start": bank.seeds_earned_total,
		"spawned": 0, "killed": 0, "escaped": 0, "frames": 0,
		"plants_lost": 0, "plants_placed": 0, "plants_sported": 0,
		"packets_bought": 0,
		"seeds_from_kills": 0, "seeds_from_growth": 0, "seeds_from_husks": 0,
		"seeds_spent_plants": 0, "seeds_spent_packets": 0,
	}


## Builds one wave's record. Every key comes from `RECORD_KEYS` and nowhere else — see
## that constant for the drift this is guarding against.
func _record() -> Dictionary:
	var alive: int = 0
	var health: float = 0.0
	for cell: Vector2i in plants:
		var plant := plants[cell] as Plant
		if plant == null or not is_instance_valid(plant) or plant.is_destroyed():
			continue
		alive += 1
		health += plant.health
	return {
		&"wave": wave,
		&"weather": weather,
		&"threat": WaveDirector.threat_for(wave),
		&"threat_level": WaveDirector.threat_level(wave),
		&"seeds_start": int(_w["seeds_start"]),
		&"seeds_end": bank.seeds,
		&"seeds_earned": bank.seeds_earned_total - int(_w["earned_start"]),
		&"seeds_from_kills": int(_w["seeds_from_kills"]),
		&"seeds_from_growth": int(_w["seeds_from_growth"]),
		&"seeds_from_husks": int(_w["seeds_from_husks"]),
		&"seeds_spent_plants": int(_w["seeds_spent_plants"]),
		&"seeds_spent_packets": int(_w["seeds_spent_packets"]),
		&"lives_start": int(_w["lives_start"]),
		&"lives_end": lives,
		&"spawned": int(_w["spawned"]),
		&"killed": int(_w["killed"]),
		&"escaped": int(_w["escaped"]),
		&"plants_alive": alive,
		&"plants_lost": int(_w["plants_lost"]),
		&"plants_placed": int(_w["plants_placed"]),
		&"plants_sported": int(_w["plants_sported"]),
		&"packets_bought": int(_w["packets_bought"]),
		&"unlocked": bank.unlocked.duplicate(),
		&"health_total": health,
		&"frames": int(_w["frames"]),
	}
