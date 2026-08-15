class_name WaveDirector
extends Node

## The wave table. Aphids come in swarms and beetles come in ones and twos, so a
## wave is a list of groups rather than a flat count — a run of eight aphids
## followed by a beetle reads very differently from the two interleaved.

signal spawn_requested(species: StringName)
signal wave_started(number: int)
signal wave_spawning_finished(number: int)

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

## Flattened spawn schedule for the running wave: [{species, at}], `at` in
## seconds from the moment the wave started.
var _schedule: Array[Dictionary] = []
var _next: int = 0
var _elapsed: float = 0.0
var _running: bool = false


func wave_count() -> int:
	return WAVES.size()


func is_spawning() -> bool:
	return _running


func has_more_waves() -> bool:
	return current_wave < WAVES.size()


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
	_schedule = _build_schedule(WAVES[current_wave - 1])
	_next = 0
	_elapsed = 0.0
	_running = not _schedule.is_empty()
	wave_started.emit(current_wave)
	return current_wave


func _build_schedule(groups: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cursor: float = 0.0
	for group: Dictionary in groups:
		cursor += float(group["lead"])
		var gap: float = float(group["gap"])
		for i: int in range(int(group["count"])):
			out.append({"species": group["species"], "at": cursor})
			cursor += gap
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	while _next < _schedule.size() and float(_schedule[_next]["at"]) <= _elapsed:
		spawn_requested.emit(_schedule[_next]["species"])
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
