class_name WaveDirector
extends Node

## The wave table. Aphids come in swarms and beetles come in ones and twos, so a
## wave is a list of groups rather than a flat count — a run of eight aphids
## followed by a beetle reads very differently from the two interleaved.

signal spawn_requested(species: StringName, mutation: StringName)
signal wave_started(number: int)
signal wave_spawning_finished(number: int)

## Wave 8 is where the fixed table gets its first beetle-heavy mix (see WAVES
## below) — the doc's mutations layer onto that rather than starting cold.
const MUTATION_START_WAVE: int = 8
const MUTATION_CHANCE: float = 0.4
const MUTATIONS: Array[StringName] = [Pest.MUTATION_ARMOURED, Pest.MUTATION_WINGED, Pest.MUTATION_HUNGRY]

## Past the fixed table, _endless_groups already turns up count/gap every
## wave — but MUTATION_CHANCE held flat forever, so wave 40 looked exactly as
## "weird" as wave 8 even though everything else about it had escalated.
## Climbing this too keeps a long endless run from going numb.
const MUTATION_CHANCE_ENDLESS_STEP: float = 0.02
const MUTATION_CHANCE_MAX: float = 0.85

## Count, gap and mutation chance all climb past the fixed table, but the pest
## itself did not: a wave-60 aphid had the same 3 HP and 78 px/s as a wave-9
## one, so the entire late game was a quantity problem and a board that could
## clear wave 20 could clear wave 200 unattended. These scale the pest, so a
## long run eventually demands upgrades rather than only more of them.
##
## Health is the main lever and speed the minor one, deliberately: health makes
## a lane take longer to clear, which the player answers with damage, while
## speed shortens the window a lane has to work in at all and turns punishing
## fast. Hence a 3x health ceiling against a 1.6x speed one — at the cap an
## aphid crosses a 64px cell in half a second, which a placed Corn Cobbler can
## still act inside.
const ENDLESS_HEALTH_STEP: float = 0.06
const ENDLESS_HEALTH_MAX: float = 3.0
const ENDLESS_SPEED_STEP: float = 0.015
const ENDLESS_SPEED_MAX: float = 1.6

## Each group: species, how many, and the gap in seconds between each one.
## `lead` is the pause before the group starts.
const WAVES: Array[Array] = [
	[{"species": &"aphid", "count": 5, "gap": 1.10, "lead": 0.5}],
	[{"species": &"aphid", "count": 9, "gap": 0.85, "lead": 0.5}],
	[
		{"species": &"aphid", "count": 8, "gap": 0.70, "lead": 0.5},
		{"species": &"beetle", "count": 1, "gap": 1.00, "lead": 2.0},
	],
	[
		{"species": &"aphid", "count": 12, "gap": 0.55, "lead": 0.5},
		{"species": &"beetle", "count": 2, "gap": 2.00, "lead": 1.5},
	],
	[
		{"species": &"beetle", "count": 3, "gap": 1.60, "lead": 0.5},
		{"species": &"aphid", "count": 10, "gap": 0.45, "lead": 1.0},
	],
	[
		{"species": &"aphid", "count": 16, "gap": 0.38, "lead": 0.5},
		{"species": &"beetle", "count": 3, "gap": 1.40, "lead": 2.0},
	],
	[
		{"species": &"beetle", "count": 5, "gap": 1.20, "lead": 0.5},
		{"species": &"aphid", "count": 14, "gap": 0.40, "lead": 1.0},
	],
	[
		{"species": &"aphid", "count": 22, "gap": 0.30, "lead": 0.5},
		{"species": &"beetle", "count": 7, "gap": 0.90, "lead": 1.5},
	],
]

var current_wave: int = 0
## Set by the title screen (RunConfig.endless) before Game._ready() runs. Past
## the fixed table, has_more_waves() never goes false — the run only ends by
## running out of lives.
var endless: bool = false

## Flattened spawn schedule for the running wave: [{species, at, mutation}],
## `at` in seconds from the moment the wave started.
var _schedule: Array[Dictionary] = []
var _next: int = 0
var _elapsed: float = 0.0
var _running: bool = false
var _rng := RandomNumberGenerator.new()


## Fixes the mutation roll for tests and for reproducing a run.
func set_seed(value: int) -> void:
	_rng.seed = value


func wave_count() -> int:
	return WAVES.size()


func is_spawning() -> bool:
	return _running


func has_more_waves() -> bool:
	if endless:
		return true
	return current_wave < WAVES.size()


## Pests actually scheduled for the wave in progress — unlike the static
## pests_in_wave(), this works past the end of the fixed table (endless mode).
func current_wave_pest_count() -> int:
	return _schedule.size()


## Total pests a wave will send. Used by the HUD and by the tests, which is why it
## reads the table rather than counting what was spawned.
static func pests_in_wave(number: int) -> int:
	if number < 1 or number > WAVES.size():
		return 0
	var total: int = 0
	for group: Dictionary in WAVES[number - 1]:
		total += int(group["count"])
	return total


func start_next_wave() -> int:
	if not has_more_waves():
		return 0
	current_wave += 1
	var groups: Array = WAVES[current_wave - 1] if current_wave <= WAVES.size() else _endless_groups(current_wave)
	_schedule = _build_schedule(groups)
	_next = 0
	_elapsed = 0.0
	_running = not _schedule.is_empty()
	wave_started.emit(current_wave)
	return current_wave


## Past the fixed table, endless keeps the same two-group shape (aphid swarm,
## beetle knot) and just turns every knob up, so the curve does not visibly
## reset the moment the table runs out.
func _endless_groups(number: int) -> Array:
	var over: int = number - WAVES.size()
	return [
		{"species": &"aphid", "count": 20 + over * 3, "gap": maxf(0.16, 0.30 - over * 0.01), "lead": 0.5},
		{"species": &"beetle", "count": 6 + int(over / 2.0), "gap": maxf(0.5, 0.9 - over * 0.02), "lead": 1.5},
	]


## Flat MUTATION_CHANCE through the fixed table; climbs by
## MUTATION_CHANCE_ENDLESS_STEP per wave past it once endless mode is the
## thing still running waves, capped at MUTATION_CHANCE_MAX so a very long
## run does not end up mutating every single pest.
static func mutation_chance_for(wave: int) -> float:
	var over: int = wave - WAVES.size()
	if over <= 0:
		return MUTATION_CHANCE
	return minf(MUTATION_CHANCE_MAX, MUTATION_CHANCE + float(over) * MUTATION_CHANCE_ENDLESS_STEP)


## Multiplier on a spawned pest's health for `wave`. Exactly 1.0 through the
## fixed table — same `over <= 0` shape as mutation_chance_for, so campaign mode
## is untouched by construction rather than by a mode flag someone can forget.
static func health_scale_for(wave: int) -> float:
	var over: int = wave - WAVES.size()
	if over <= 0:
		return 1.0
	return minf(ENDLESS_HEALTH_MAX, 1.0 + float(over) * ENDLESS_HEALTH_STEP)


## Multiplier on a spawned pest's walking speed for `wave`. See the constants:
## this climbs far more slowly than health and stops far sooner.
static func speed_scale_for(wave: int) -> float:
	var over: int = wave - WAVES.size()
	if over <= 0:
		return 1.0
	return minf(ENDLESS_SPEED_MAX, 1.0 + float(over) * ENDLESS_SPEED_STEP)


func _build_schedule(groups: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cursor: float = 0.0
	var mutating: bool = current_wave >= MUTATION_START_WAVE
	var chance: float = mutation_chance_for(current_wave)
	for group: Dictionary in groups:
		cursor += float(group["lead"])
		var gap: float = float(group["gap"])
		for i: int in range(int(group["count"])):
			var mutation: StringName = &""
			if mutating and _rng.randf() < chance:
				mutation = MUTATIONS[_rng.randi_range(0, MUTATIONS.size() - 1)]
			out.append({"species": group["species"], "at": cursor, "mutation": mutation})
			cursor += gap
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	while _next < _schedule.size() and float(_schedule[_next]["at"]) <= _elapsed:
		var entry: Dictionary = _schedule[_next]
		spawn_requested.emit(entry["species"], entry["mutation"])
		_next += 1
	if _next >= _schedule.size():
		_running = false
		wave_spawning_finished.emit(current_wave)


func reset() -> void:
	current_wave = 0
	_schedule.clear()
	_next = 0
	_elapsed = 0.0
	_running = false
