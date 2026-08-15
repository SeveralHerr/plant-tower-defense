extends RefCounted

## Project DevTools command extension.
##
## The generic verbs can read and press anything, but they cannot express "put a
## Chomp Flower on cell (2,2)" or "send one beetle now" — those are the setup
## steps every runtime check of this game starts with, so they live here.
##
## Every handler returns exactly {success, message, data}.

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
