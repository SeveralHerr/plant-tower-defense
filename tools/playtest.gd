@tool
extends SceneTree

## Plays whole runs of the game with nobody at the keyboard and prints what happened.
##
## The human-callable half of `tools/run_sim.gd`; `test/unit/test_playtest.gd` is the
## other half. Both drive the SAME class, which is the point of it living in `tools/`
## rather than inside a test file: `/verify` re-runs `test_dir` on every change and has to
## stay fast, while bead plant-tower-defense-t5yy.2 needs to sweep hundreds of endless
## waves. Those are two budgets, and one driver.
##
## Run it:
##   godot --headless --path . --script res://tools/playtest.gd
##   godot --headless --path . --script res://tools/playtest.gd -- --waves 40 --endless
##   godot --headless --path . --script res://tools/playtest.gd -- --difficulty harsh --json
##
## Flags (everything after the bare `--`, read via OS.get_cmdline_user_args()):
##   --waves N          wave ceiling per run (default 26, one past the campaign table)
##   --seed N           the roll seed; repeatable, one run per seed
##   --seeds N          shorthand for seeds 1..N
##   --difficulty NAME  gentle | standard | harsh (default standard). Repeatable.
##   --endless          play past the fixed table
##   --no-sweep         do not sweep husks, i.e. the floor a player who never clicks gets
##   --json             emit every record as one JSON document instead of a table
##   --out PATH         ALSO append the record to PATH as JSONL, one line per wave plus
##                      one per run, for `tools/playtest_report.py` to read back. This is
##                      what makes a balance baseline a committed artefact rather than
##                      scrollback (plant-tower-defense-t5yy.4).
##
## READ THE DENOMINATOR, not the exit code. Every run prints `N wave(s) played of M
## attempted` and how it ended; a run that played two waves and stopped is not a game that
## is easy. Exit 0 every run finished the way the game says it should (`cleared`, `eaten`
## or the wave ceiling the caller asked for), 1 a run the DRIVER had to stop, 2 the script
## could not run at all.
##
## THIS ASSERTS NOTHING ABOUT BALANCE and is not a gate. Whether wave 14 is boring, or
## whether harsh is beatable, is beads t5yy.2/.3/.4 reading these numbers.

const DEFAULT_WAVES: int = 26

## Loaded at RUN time, never named at compile time, and this is not a style choice.
##
## In `--script` mode Godot compiles this file before it registers the project's
## autoloads, so a compile-time reference to `RunSim` pulls in `Game`, which names the
## `RunConfig` singleton, which does not exist yet: the whole chain fails to compile and
## the script never runs. `tools/run_tests.gd` sidesteps the same trap by loading its test
## scripts after the tree is up. The `load()` pair in `_run()` is that, and the failure it
## guards against printed seven `Compile Error` lines, played nothing and still exited 0.
const RUN_SIM := "res://tools/run_sim.gd"
const GAME := "res://game/game.gd"

var _sim_script: GDScript = null
var _game_script: GDScript = null


func _initialize() -> void:
	_run()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var waves: int = DEFAULT_WAVES
	var seeds: Array[int] = []
	var difficulties: Array[StringName] = []
	var endless: bool = false
	var sweep: bool = true
	var as_json: bool = false
	var out_path: String = ""
	var i: int = 0
	while i < args.size():
		var arg: String = args[i]
		match arg:
			"--waves":
				i += 1
				waves = int(args[i]) if i < args.size() else waves
			"--seed":
				i += 1
				if i < args.size():
					seeds.append(int(args[i]))
			"--seeds":
				i += 1
				if i < args.size():
					for n: int in range(1, int(args[i]) + 1):
						seeds.append(n)
			"--difficulty":
				i += 1
				if i < args.size():
					difficulties.append(StringName(args[i]))
			"--endless":
				endless = true
			"--no-sweep":
				sweep = false
			"--json":
				as_json = true
			"--out":
				i += 1
				if i < args.size():
					out_path = args[i]
			_:
				printerr("playtest: no such flag: %s" % arg)
				quit(2)
				return
		i += 1
	if seeds.is_empty():
		seeds.append(1)
	var host := Node2D.new()
	host.name = "PlaytestHost"
	root.add_child(host)
	# Two frames so the autoloads are up (see RUN_SIM's note) and the host is genuinely in
	# the tree with its groups before the driver takes its foreign-node census. Everything
	# after this is hand-stepped.
	await process_frame
	await process_frame
	_sim_script = load(RUN_SIM) as GDScript
	_game_script = load(GAME) as GDScript
	if _sim_script == null or _game_script == null:
		printerr("playtest: could not load %s / %s" % [RUN_SIM, GAME])
		quit(2)
		return
	if difficulties.is_empty():
		difficulties.append(_game_script.DIFFICULTY_STANDARD)

	var failures: int = 0
	var empty: int = 0
	var all: Array[Dictionary] = []
	var jsonl: Array[String] = []
	for difficulty: StringName in difficulties:
		for roll: int in seeds:
			var sim: Object = _sim_script.new()
			sim.difficulty = difficulty
			sim.endless = endless
			sim.wave_ceiling = waves
			sim.roll_seed = roll
			sim.sweep_husks = sweep
			var records: Array[Dictionary] = sim.play(host)
			print(sim.summary_line())
			if sim.foreign_pests > 0 or sim.foreign_plants > 0:
				# Nothing else runs in this process, so a non-zero census here is a bug in
				# this script rather than a sibling test — said out loud because the same
				# number is a REAL hazard for the test-suite caller.
				printerr("playtest: %d foreign pest(s) and %d foreign plant(s) were already in the tree"
					% [sim.foreign_pests, sim.foreign_plants])
			if out_path != "":
				_collect_jsonl(jsonl, difficulty, roll, endless, sweep, sim, records, waves)
			if as_json:
				all.append({
					"difficulty": String(difficulty), "seed": roll, "endless": endless,
					"swept": sweep, "ended": String(sim.ended), "failure": sim.failure,
					"waves_played": sim.waves_played, "waves_attempted": waves,
					"records": _jsonable(records),
				})
			else:
				_print_table(records)
			if sim.failure != "":
				failures += 1
			if sim.waves_played <= 0:
				empty += 1
			sim.dispose()
	if as_json:
		print(JSON.stringify(all, "  "))
	if out_path != "":
		var wrote: String = _write_jsonl(out_path, jsonl)
		if wrote != "":
			printerr("playtest: %s" % wrote)
			host.queue_free()
			quit(2)
			return
		print("playtest: %d row(s) written to %s" % [jsonl.size(), out_path])
	host.queue_free()
	var attempted: int = difficulties.size() * seeds.size()
	print("Playtest: %d run(s), %d played nothing, %d driver failure(s)"
		% [attempted, empty, failures])
	if empty > 0:
		# A RUN THAT PLAYED NO WAVES IS NOT A CLEAN RUN. Exiting 0 on it is the vacuity
		# CLAUDE.md warns about and it is not hypothetical: the first live invocation of
		# this script printed seven `Compile Error` lines, played zero waves and exited 0.
		printerr("playtest: %d of %d run(s) played no waves at all -- nothing was measured"
			% [empty, attempted])
		quit(2)
		return
	quit(1 if failures > 0 else 0)


## One JSONL row per wave, plus one per run, both carrying the four keys that identify
## the run they belong to.
##
## THE RUN KEYS ARE ON EVERY ROW ON PURPOSE. A wave row that only carried a wave number
## would need a join to be readable, and the first thing anyone does with a JSONL file is
## `grep` one line out of it. The wave row is otherwise exactly what `RunSim` recorded --
## the keys are its `RECORD_KEYS` and this function never names one, so a column added
## there reaches the committed baseline the same day rather than being silently dropped
## here. `tools/playtest_report.py` reads `RECORD_KEYS` back out of `run_sim.gd` for the
## same reason and refuses a row carrying anything else.
func _collect_jsonl(into: Array[String], difficulty: StringName, roll: int, endless: bool,
		sweep: bool, sim: Object, records: Array[Dictionary], attempted: int) -> void:
	var keys: Dictionary = {
		"difficulty": String(difficulty), "seed": roll, "endless": endless, "swept": sweep,
	}
	for record: Dictionary in records:
		var row: Dictionary = keys.duplicate()
		row["kind"] = "wave"
		row.merge(_jsonable_record(record))
		into.append(JSON.stringify(row))
	var summary: Dictionary = keys.duplicate()
	summary["kind"] = "run"
	summary["ended"] = String(sim.ended)
	summary["failure"] = sim.failure
	summary["waves_played"] = sim.waves_played
	summary["waves_attempted"] = attempted
	# The contamination census, carried into the record rather than left on stderr. A run
	# measured on a tree still holding a previous run's plants is not a run, and a reader
	# of the committed baseline has no other way to know which rows those were.
	summary["foreign_pests"] = sim.foreign_pests
	summary["foreign_plants"] = sim.foreign_plants
	into.append(JSON.stringify(summary))


## Writes the rows whole, at the end, rather than a line at a time: a sweep killed
## half-way then leaves no file rather than a truncated one a reader would take for a
## complete record of a shorter run.
func _write_jsonl(path: String, rows: Array[String]) -> String:
	var dir: String = path.get_base_dir()
	if dir.begins_with("res://") or dir.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(dir)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not open %s for writing (error %d)" % [path, FileAccess.get_open_error()]
	for row: String in rows:
		file.store_line(row)
	file.close()
	return ""


## One record with every value JSON-safe. Separate from `_jsonable` above, which takes the
## whole array; this one is the per-row half `_collect_jsonl` needs.
func _jsonable_record(record: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in record:
		var value: Variant = record[key]
		if value is StringName:
			out[String(key)] = String(value)
		elif value is Array:
			var listed: Array = []
			for item: Variant in value as Array:
				listed.append(String(item) if item is StringName else item)
			out[String(key)] = listed
		else:
			out[String(key)] = value
	return out


## One row per wave, columns from `RunSim.RECORD_KEYS` rather than from a header written
## here — a key added to the record shows up in this table the same day.
func _print_table(records: Array[Dictionary]) -> void:
	if records.is_empty():
		print("  (no waves played)")
		return
	var header: PackedStringArray = PackedStringArray()
	for key: StringName in _sim_script.RECORD_KEYS:
		header.append(String(key))
	print("  " + "\t".join(header))
	for record: Dictionary in records:
		var row: PackedStringArray = PackedStringArray()
		for key: StringName in _sim_script.RECORD_KEYS:
			row.append(_cell(record[key]))
		print("  " + "\t".join(row))


func _cell(value: Variant) -> String:
	if value is float:
		return "%.2f" % (value as float)
	if value is Array:
		return "%d" % (value as Array).size()
	return str(value)


## JSON has no StringName and no typed Array, so the record's `weather` and `unlocked`
## have to be spelled out as strings or `JSON.stringify` drops them to nulls.
func _jsonable(records: Array[Dictionary]) -> Array:
	var out: Array = []
	for record: Dictionary in records:
		var flat: Dictionary = {}
		for key: StringName in _sim_script.RECORD_KEYS:
			var value: Variant = record[key]
			if value is StringName:
				flat[String(key)] = String(value)
			elif value is Array:
				var names: Array = []
				for item: Variant in value as Array:
					names.append(str(item))
				flat[String(key)] = names
			else:
				flat[String(key)] = value
		out.append(flat)
	return out
