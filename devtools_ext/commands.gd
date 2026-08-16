extends RefCounted

## Project DevTools command extension.
##
## The generic verbs can read and press anything, but they cannot express "put a
## Chomp Flower on cell (2,2)" or "send one beetle now" — those are the setup
## steps every runtime check of this game starts with, so they live here.
##
## Every handler returns exactly {success, message, data}.

## Reported instead of "" when a git fact genuinely cannot be read (an exported
## build has no .git at all). An empty string reads as a value that was found and
## happened to be blank, which is the failure this verb exists to prevent.
const UNAVAILABLE: String = "unavailable"

var _dev: Node


func register_commands(dev: Node) -> void:
	_dev = dev
	_dev.register_command("game_state", _cmd_game_state)
	_dev.register_command("place_plant", _cmd_place_plant)
	_dev.register_command("spawn_pest", _cmd_spawn_pest)
	_dev.register_command("add_seeds", _cmd_add_seeds)
	_dev.register_command("start_wave", _cmd_start_wave)
	_dev.register_command("buy_packet", _cmd_buy_packet)
	_dev.register_command("upgrade_plant", _cmd_upgrade_plant)
	_dev.register_command("board_info", _cmd_board_info)
	_dev.register_command("compost_state", _cmd_compost_state)
	_dev.register_command("collect_husk", _cmd_collect_husk)
	# Not a game verb: it answers "which checkout am I actually driving?" before any
	# of the above are believed. Registered with a literal name so `list-commands
	# --offline` can still find it with no game running.
	_dev.register_command("project_identity", _cmd_project_identity)
	# Merged into every reply: a session that has quietly lost its Game answers
	# well-formed zeros otherwise, which reads exactly like a clean pass.
	_dev.register_status_provider(_status)


func _game() -> Game:
	return _dev.get_tree().get_first_node_in_group("game") as Game


func _status(_args: Dictionary) -> Dictionary:
	var game: Game = _game()
	if game == null:
		return {"game": "absent"}
	return {
		"game": "over" if game.game_over else ("won" if game.victory else "running"),
		"wave": game.director.current_wave,
		"seeds": game.bank.seeds,
		"lives": game.lives,
		"plants": game.state()["plants"],
		"pests_alive": game.state()["pests_alive"],
	}


func _fail(message: String) -> Dictionary:
	return {"success": false, "message": message, "data": {}}


func _cmd_game_state(_args: Dictionary) -> Dictionary:
	var game: Game = _game()
	if game == null:
		return _fail("no Game in the tree")
	var state: Dictionary = game.state()
	# The live objects in state() are for the HUD; the bus needs plain values.
	state.erase("bank")
	var placed: Variant = state.get("selected_placed")
	state["selected_placed"] = "" if placed == null else str((placed as Plant).cell)
	state["selected_plant"] = String(state["selected_plant"])
	state["unlocked"] = game.bank.unlocked.map(func(id: StringName) -> String: return String(id))
	state["free_starter_available"] = game.bank.free_starter_available
	return {"success": true, "message": "state", "data": state}


func _cmd_place_plant(args: Dictionary) -> Dictionary:
	var game: Game = _game()
	if game == null:
		return _fail("no Game in the tree")
	var id := StringName(str(args.get("plant", "corn_cobbler")))
	var cell := Vector2i(int(args.get("x", 0)), int(args.get("y", 0)))
	var refusal: String = game.place_plant(id, cell)
	if refusal != "":
		return _fail("refused at %s: %s" % [cell, refusal])
	return {
		"success": true,
		"message": "planted %s at %s" % [id, cell],
		"data": {"seeds": game.bank.seeds, "plants": game.state()["plants"]},
	}


func _cmd_spawn_pest(args: Dictionary) -> Dictionary:
	var game: Game = _game()
	if game == null:
		return _fail("no Game in the tree")
	var species := StringName(str(args.get("species", "aphid")))
	if not Pest.SPECIES.has(species):
		return _fail("unknown species '%s'" % species)
	var mutation := StringName(str(args.get("mutation", "")))
	var count: int = maxi(1, int(args.get("count", 1)))
	for i: int in range(count):
		game.spawn_pest(species, mutation)
	return {
		"success": true,
		"message": "spawned %d %s" % [count, species],
		"data": {"pests_alive": game.state()["pests_alive"]},
	}


func _cmd_add_seeds(args: Dictionary) -> Dictionary:
	var game: Game = _game()
	if game == null:
		return _fail("no Game in the tree")
	game.bank.add_seeds(int(args.get("amount", 100)))
	return {"success": true, "message": "seeds", "data": {"seeds": game.bank.seeds}}


func _cmd_start_wave(_args: Dictionary) -> Dictionary:
	var game: Game = _game()
	if game == null:
		return _fail("no Game in the tree")
	if not game.start_next_wave():
		return _fail("cannot start a wave now (wave live, run over, or table exhausted)")
	return {
		"success": true,
		"message": "wave %d" % game.director.current_wave,
		"data": {"wave": game.director.current_wave, "pests": WaveDirector.pests_in_wave(game.director.current_wave)},
	}


func _cmd_buy_packet(args: Dictionary) -> Dictionary:
	var game: Game = _game()
	if game == null:
		return _fail("no Game in the tree")
	var tier := StringName(str(args.get("tier", "common")))
	var got: StringName = game.bank.buy_packet(tier)
	if got == &"":
		return _fail("packet refused — check tier, seeds, and remaining locked plants")
	return {
		"success": true,
		"message": "packet held %s" % got,
		"data": {"plant": String(got), "seeds": game.bank.seeds},
	}


func _cmd_compost_state(_args: Dictionary) -> Dictionary:
	var game: Game = _game()
	if game == null:
		return _fail("no Game in the tree")
	return {
		"success": true,
		"message": "compost",
		"data": {
			"total_collected": game.compost.total_collected,
			"husks_on_ground": game.compost.husk_count(),
			"husks": game.compost.husks(),
		},
	}


func _cmd_collect_husk(args: Dictionary) -> Dictionary:
	var game: Game = _game()
	if game == null:
		return _fail("no Game in the tree")
	var at := Vector2(float(args.get("x", 0.0)), float(args.get("y", 0.0)))
	var value: int = game.compost.collect_at(at)
	if value <= 0:
		return _fail("no husk within collect radius of %s" % at)
	game.bank.add_seeds(value)
	return {"success": true, "message": "collected %d" % value, "data": {"seeds": game.bank.seeds}}


func _cmd_upgrade_plant(args: Dictionary) -> Dictionary:
	var game: Game = _game()
	if game == null:
		return _fail("no Game in the tree")
	var cell := Vector2i(int(args.get("x", 0)), int(args.get("y", 0)))
	var plant: Plant = game.plant_at(cell)
	if plant == null:
		return _fail("nothing growing at %s" % cell)
	game.selected_placed = plant
	var refusal: String = game.upgrade_selected()
	if refusal != "":
		return _fail(refusal)
	var corn := plant as CornCobbler
	return {
		"success": true,
		"message": "upgraded",
		"data": {"level": corn.level, "level_name": corn.level_name(), "kernels": corn.kernels_per_shot()},
	}


func _cmd_board_info(_args: Dictionary) -> Dictionary:
	var game: Game = _game()
	if game == null:
		return _fail("no Game in the tree")
	return {
		"success": true,
		"message": "board",
		"data": {
			"cols": Board.COLS,
			"rows": Board.ROWS,
			"cell": Board.CELL,
			"path_cells": game.board.path_cell_count(),
			"route_points": game.board.route().size(),
		},
	}


# --- Which build is this? ---

## Proves which checkout the answering process was launched from, before any other
## verb's answer is trusted.
##
## user:// is keyed on the project NAME, so a second worktree of this same project
## owns the same bus directory: a Godot left running in a sibling checkout answers
## every command here, and the symptoms are `no Game in the tree` and node-not-found
## on paths that plainly exist -- which reads as a broken scene rather than as the
## wrong process. project_root is the field that separates them; everything else is
## corroboration.
##
## git facts are read off disk with FileAccess rather than shelled out for: there are
## zero OS.execute calls in this project and a blocking git invocation on the main
## thread would stall the frame the bus answers from.
##
## Wire contract - data keys: project_root (String, absolute, what res:// globalizes
## to), project_name (String), git_dir (String, absolute, or "unavailable"),
## git_branch (String, branch name, "detached", or "unavailable"), git_sha (String,
## 40 hex chars, or "unavailable"), is_worktree (bool, true when .git is a file
## pointing elsewhere), user_dir (String, the shared-by-project-name dir the bus
## lives under), engine_version (String), pid (int).
func _cmd_project_identity(_args: Dictionary) -> Dictionary:
	var root: String = ProjectSettings.globalize_path("res://")
	if root == "":
		return _fail("res:// did not globalize -- cannot identify this build")
	root = root.rstrip("/").rstrip("\\")
	var project_name: String = str(ProjectSettings.get_setting("application/config/name", ""))
	var git: Dictionary = _git_identity(root)
	var version: Dictionary = Engine.get_version_info()
	var engine: String = str(version.get("string", "%d.%d.%d" % [
		int(version.get("major", 0)), int(version.get("minor", 0)), int(version.get("patch", 0)),
	]))
	var sha: String = str(git["sha"])
	return {
		"success": true,
		"message": "%s at %s (%s @ %s)" % [
			project_name, root, git["branch"], sha if sha == UNAVAILABLE else sha.substr(0, 8),
		],
		"data": {
			"project_root": root,
			"project_name": project_name,
			"git_dir": git["dir"],
			"git_branch": git["branch"],
			"git_sha": sha,
			"is_worktree": git["is_worktree"],
			"user_dir": OS.get_user_data_dir(),
			"engine_version": engine,
			"pid": OS.get_process_id(),
		},
	}


## Absolute-path text read. Godot's importer never scans .git, so res:// paths into
## it resolve to nothing -- everything below works off globalized OS paths.
func _read_text_absolute(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _absolutize(path: String, relative_to: String) -> String:
	if path.is_absolute_path():
		return path.simplify_path()
	return relative_to.path_join(path).simplify_path()


## Locates the git directory for `root`, following the `gitdir: <path>` indirection
## used when .git is a FILE. That is not a corner case here: agent worktrees live at
## .claude/worktrees/, and a worktree is exactly the situation this verb diagnoses.
func _git_dir_for(root: String) -> String:
	var dot: String = root.path_join(".git")
	if DirAccess.dir_exists_absolute(dot):
		return dot
	if not FileAccess.file_exists(dot):
		return ""
	for line: String in _read_text_absolute(dot).split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("gitdir:"):
			var target: String = _absolutize(trimmed.substr(7).strip_edges(), root)
			return target if DirAccess.dir_exists_absolute(target) else ""
	return ""


## A linked worktree keeps its own HEAD but shares refs/ with the main checkout,
## which it names in a `commondir` file. Reading only the worktree's own dir finds
## HEAD and then no ref to resolve it against.
func _git_common_dir(git_dir: String) -> String:
	var marker: String = git_dir.path_join("commondir")
	if not FileAccess.file_exists(marker):
		return git_dir
	var text: String = _read_text_absolute(marker).strip_edges()
	return git_dir if text == "" else _absolutize(text, git_dir)


func _loose_ref(base_dir: String, ref: String) -> String:
	var loose: String = base_dir.path_join(ref)
	if not FileAccess.file_exists(loose):
		return ""
	return _read_text_absolute(loose).strip_edges()


func _resolve_ref(ref: String, git_dir: String, common_dir: String) -> String:
	var own_sha: String = _loose_ref(git_dir, ref)
	if own_sha != "":
		return own_sha
	var shared_sha: String = _loose_ref(common_dir, ref)
	if shared_sha != "":
		return shared_sha
	# A missing loose ref means the ref was packed -- by `git gc` or a fresh clone.
	var packed: String = common_dir.path_join("packed-refs")
	if not FileAccess.file_exists(packed):
		return ""
	for line: String in _read_text_absolute(packed).split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed == "" or trimmed.begins_with("#") or trimmed.begins_with("^"):
			continue
		var parts: PackedStringArray = trimmed.split(" ", false)
		if parts.size() >= 2 and parts[1] == ref:
			return parts[0]
	return ""


## Returns {dir, branch, sha, is_worktree} with every value a JSON-safe scalar --
## the bus carries plain values only, the way _cmd_game_state erases its live bank.
func _git_identity(root: String) -> Dictionary:
	var out: Dictionary = {
		"dir": UNAVAILABLE,
		"branch": UNAVAILABLE,
		"sha": UNAVAILABLE,
		"is_worktree": false,
	}
	var git_dir: String = _git_dir_for(root)
	if git_dir == "":
		return out
	out["dir"] = git_dir
	out["is_worktree"] = not DirAccess.dir_exists_absolute(root.path_join(".git"))
	var head: String = _read_text_absolute(git_dir.path_join("HEAD")).strip_edges()
	if head == "":
		return out
	if not head.begins_with("ref:"):
		# Detached HEAD: the file holds the sha itself and there is no branch to name.
		out["branch"] = "detached"
		out["sha"] = head
		return out
	var ref: String = head.substr(4).strip_edges()
	out["branch"] = ref.trim_prefix("refs/heads/")
	var sha: String = _resolve_ref(ref, git_dir, _git_common_dir(git_dir))
	if sha != "":
		out["sha"] = sha
	return out
