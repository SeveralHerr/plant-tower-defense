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
	_dev.register_command("budgets", _cmd_budgets)
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
		"budgets": _budget_status(game),
	}


## What Game.check_budgets() found at startup, on every reply.
##
## The carrier, and the reason this line exists at all. push_warning() reaches the
## editor's Errors tab and stderr, and `devtools.py launch` redirects stderr into
## a file nobody opens unless something has already gone wrong -- so a warning
## about a budget quietly running out is delivered exactly where a person who has
## no idea a budget exists will never look. status is merged into EVERY reply,
## so it reaches anyone who touches this game through the bridge at all.
##
## Always present, never omitted when clean: a check that ran and found nothing is
## a count of zero, not a missing key. And it is the STARTUP reading rather than a
## fresh one -- pricing four budgets, one of them a 120-wave sweep, on every reply
## would make reading this game more expensive than playing it.
func _budget_status(game: Game) -> String:
	if game.budget_report.is_empty():
		return "not read (Game.check_budgets() has not run)"
	var line: String = str(game.budget_report.get("summary", "no summary"))
	var warnings: Array = game.budget_report.get("warnings", [])
	# The first offender in full. A count on its own tells a reader something is
	# wrong and nothing about what, which is one more thing to go and look up.
	if warnings.size() > 0:
		line += " -- " + str(warnings[0])
	return line


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


## The board's shape, plus the one budget on it that is nearly spent.
##
## husk_click_margin is 4.0 px: the distance between a husk's 28 px sweep and the
## nearest ground a plant may stand on. It is reported here with BOTH terms of the
## subtraction it comes from (husk_lane_to_buildable minus husk_collect_radius),
## because the result alone says nothing about how much room is left. Whoever
## moves Board.PATH_CORNERS or CompostMeter.COLLECT_RADIUS is spending that
## budget, and until this verb printed it the only place the number appeared was
## in the failure text of the test that guards it -- which is an alarm, not a
## budget. See PlacementPreview.husk_click_budget().
##
## The numbers are not computed here: margin is PlacementPreview.husk_click_margin()
## itself, the same call the gate asserts on, so this readout cannot drift away
## from the thing it reports.
func _cmd_board_info(_args: Dictionary) -> Dictionary:
	var game: Game = _game()
	if game == null:
		return _fail("no Game in the tree")
	var budget: Dictionary = PlacementPreview.husk_click_budget(game.board)
	return {
		"success": true,
		"message": "board %dx%d -- %s" % [Board.COLS, Board.ROWS, budget["summary"]],
		"data": {
			"cols": Board.COLS,
			"rows": Board.ROWS,
			"cell": Board.CELL,
			"path_cells": game.board.path_cell_count(),
			"route_points": game.board.route().size(),
			"husk_lane_to_buildable": budget["lane_to_buildable"],
			"husk_collect_radius": budget["collect_radius"],
			"husk_click_margin": budget["margin"],
			"husk_click_margin_measured": budget["measured"],
			"husk_click_budget": budget["summary"],
		},
	}


# --- Every declared budget, and what is left of it -------------------------
#
# Four constants in this project carry a "moving me costs you X" doc comment,
# and every one of the X's lives in a DIFFERENT file: Board.PATH_CORNERS names
# three numbers measured against the road it produces, CompostMeter.COLLECT_RADIUS
# has 4 px between it and a click that could place a plant, NotebookScreen's
# SUBHEAD_MAX_WIDTH holds a centred sentence off two pane labels, and Hud's
# WORST_CASE_TEXT prices four readouts against a row that has nineteen pixels
# spare. A person finds each of those warnings by editing that exact line, which
# means they find it AFTER deciding to move it.
#
# `budgets` is the set, before anyone goes looking. Each entry says what is being
# spent, what the ceiling is, what remains and what to look at when it runs out.
#
# What it deliberately does NOT do is transcribe. Every number below is the live
# call the gate itself asserts on -- husk_click_budget(), stats_row_budget(), the
# theme font over the real Label, peak_simultaneous_pests() -- because a verb
# printing hand-copied constants would be a fifth place for them to go stale,
# which is the exact disease it exists to cure. Where a coupling genuinely has no
# ceiling to measure against, the entry says so in words and reports its live
# measurements as observations rather than inventing a headroom for them.
#
# Four of the six now live on Game itself -- the ledger, the thresholds, the
# grading and the four budgets a run can price without a bridge are in the
# `budgets` section of res://game/game.gd, because the run reads them at startup
# and warns about the ones that have fallen through their declared floor. This
# verb calls game.budget_entries() and adds the two below, which is the same
# rule the husk budget already followed: one arithmetic, so the warning a player's
# launch prints and the table this verb draws cannot disagree.


## Every declared budget with its current headroom.
##
## Answers with no Game in the tree too (plant-tower-defense-gzm) -- a title
## screen degrades four of the six entries to "unmeasured" (they read live
## nodes or an instance method that groups them) rather than refusing the
## whole reply, and the other two (notebook_subhead, road_shape) need nothing
## a title screen doesn't already have, so they answer computed either way.
##
## args: id (String, one budget's id, default all), waves (int, the sweep for the
## pest ceiling).
##
## data keys: budgets (Array of entry Dictionaries), count/computed/uncomputed/
## spent/spent_by_design/tight (int), tightest (String, the id with the least
## headroom left as a fraction of its ceiling, or ""), summary (String, the
## same line as `message`),
## under_floor (int) and warnings (Array[String]) -- the budgets that have fallen
## below Game.BUDGET_FLOOR, which is what the run warns about at startup and is
## always the whole ledger's count rather than the --id filter's -- and
## startup_check (String, what Game.check_budgets() found on this launch).
##
## Entry keys, all JSON-safe: id, constant, declared_in, spends, units, state,
## measured_by, summary, when_it_runs_out (String); computed (bool); spent,
## ceiling, headroom (float, all -1.0 when computed is false); observations
## (Array[String]).
func _cmd_budgets(args: Dictionary) -> Dictionary:
	var game: Game = _game()
	var sweep: int = maxi(1, int(args.get("waves", Game.BUDGET_WAVE_SWEEP)))
	var wanted: String = str(args.get("id", ""))
	# The four the run prices itself, then the two only a bridge can ask about.
	# Appended with a plain loop: game.budget_entries() hands back a typed Array
	# and `+` between two of them is a place a typing mistake hides.
	#
	# game.budget_entries() needs a live instance for all four of its own --
	# husk_click and both HUD entries read live nodes, and pest_road_ceiling is
	# only reached through the instance method that groups them -- so on a
	# title screen with no Game running, those four degrade to "unmeasured"
	# instead of refusing the whole reply (plant-tower-defense-gzm).
	# notebook_subhead and road_shape need nothing a title screen doesn't
	# already have, so they still answer either way.
	var all: Array[Dictionary] = []
	if game != null:
		for entry: Dictionary in game.budget_entries(sweep):
			all.append(entry)
	else:
		for entry: Dictionary in _budget_entries_without_game():
			all.append(entry)
	all.append(_budget_notebook_subhead())
	all.append(_budget_road_shape(game))
	# A plain loop, not Array.filter: filter hands back an untyped Array and
	# returning that as Array[Dictionary] is a runtime error the static checkers
	# never see.
	var entries: Array[Dictionary] = []
	var names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in all:
		names.append(str(entry["id"]))
		if wanted == "" or str(entry["id"]) == wanted:
			entries.append(entry)
	if entries.is_empty():
		return _fail("no budget called '%s' -- known ids: %s" % [wanted, ", ".join(names)])

	var computed: int = 0
	var spent: int = 0
	var spent_by_design: int = 0
	var tight: int = 0
	var tightest: String = ""
	var tightest_fraction: float = INF
	for entry: Dictionary in entries:
		if not bool(entry["computed"]):
			continue
		computed += 1
		var state: String = str(entry["state"])
		if state == "spent":
			spent += 1
		elif state == Game.BUDGET_SPENT_BY_DESIGN:
			spent_by_design += 1
		elif state == "tight":
			tight += 1
		var ceiling: float = float(entry["ceiling"])
		if ceiling <= 0.0:
			continue
		var fraction: float = float(entry["headroom"]) / ceiling
		if fraction < tightest_fraction:
			tightest_fraction = fraction
			tightest = str(entry["id"])
	var headline: String = (
		"%d budget(s): %d computed, %d without a number -- %d spent, %d spent by design, %d tight") % [
			entries.size(), computed, entries.size() - computed, spent, spent_by_design, tight,
		]
	if tightest != "":
		for entry: Dictionary in entries:
			if str(entry["id"]) == tightest:
				headline += "; tightest %s: %s" % [tightest, entry["summary"]]
				break
	# Graded against the declared floors as well as against their own ceilings.
	# `tight` says a budget is nearly out, and three of these are permanently
	# tight by design; `spent_by_design` says one is exactly at its ceiling by
	# construction (pest_road_ceiling -- see Game.BUDGET_SPENT_BY_DESIGN) rather
	# than an accident that happened to land there. `under_floor` is the only
	# half of this table that is news: a budget SPENT since somebody last looked,
	# plain "spent" and never "spent_by_design", because BUDGET_FLOOR declares
	# pest_road_ceiling's own floor at 0.0 -- it cannot fall through a floor it
	# is defined to sit on. Regraded here from this reply's own measurements --
	# not read out of game.budget_report -- so `--args '{"waves": 300}'` grades
	# the sweep it was actually asked for.
	#
	# Over `all` and not `entries`: --id is a display filter, and grading only the
	# shown entry would report every floor whose budget was filtered out as a
	# floor guarding nothing. The count is the whole ledger's, and says so.
	var regressions: Array[String] = Game.budget_regressions(all)
	if regressions.size() > 0:
		headline += "; %d of the %d budget(s) under the floor Game.BUDGET_FLOOR declares" % [
			regressions.size(), all.size(),
		]
	return {
		"success": true,
		"message": headline,
		"data": {
			"budgets": entries,
			"count": entries.size(),
			"computed": computed,
			"uncomputed": entries.size() - computed,
			"spent": spent,
			"spent_by_design": spent_by_design,
			"tight": tight,
			"tightest": tightest,
			"under_floor": regressions.size(),
			"warnings": regressions,
			"startup_check": (str(game.budget_report.get("summary", "not read")) if game != null
				else "no Game in the tree -- the startup check has not run yet"),
			"summary": headline,
		},
	}


## What game.budget_entries() would have reported, degraded to "unmeasured"
## because there is no Game to read the live nodes and statics those four
## methods need. Same ids, constants and declared_in every other reply uses --
## so `--id hud_readouts` finds the same name whether or not a run is live --
## but the "why" points at Game.budget_entries() rather than duplicating the
## paragraph each real method already carries next to its own arithmetic; a
## copy here is exactly the fifth place this whole file exists to prevent one.
func _budget_entries_without_game() -> Array[Dictionary]:
	var why: String = "no Game in the tree"
	var see_it: String = "see Game.budget_entries() in game.gd for what running out of this costs"
	var out: Array[Dictionary] = [
		Game.uncomputed_budget(Game.BUDGET_UNMEASURED, "husk_click", "CompostMeter.COLLECT_RADIUS",
			"res://game/compost_meter.gd", "husk sweep radius", why, see_it,
			Game.no_budget_observations()),
		Game.uncomputed_budget(Game.BUDGET_UNMEASURED, "hud_readouts", "Hud.WORST_CASE_TEXT",
			"res://game/hud.gd", "the widest readout's worst case", why, see_it,
			Game.no_budget_observations()),
		Game.uncomputed_budget(Game.BUDGET_UNMEASURED, "hud_stats_row", "Hud.stats_row_budget()",
			"res://game/hud.gd", "the stats row's contents", why, see_it,
			Game.no_budget_observations()),
		Game.uncomputed_budget(Game.BUDGET_UNMEASURED, "pest_road_ceiling",
			"WaveDirector.SIMULTANEOUS_PEST_CEILING", "res://game/wave_director.gd",
			"pests on the road at once", why, see_it,
			Game.no_budget_observations()),
	]
	return out


## NotebookScreen.SUBHEAD_MAX_WIDTH against the width the subheading actually
## draws at in the real theme font.
##
## Measured through Font.get_string_size and not get_minimum_size(): the pane
## labels are held off the subheading by nothing but the centred text being
## narrower than the panel, and a clip_text Label reports a ~1px minimum, so the
## obvious form of this measurement cannot fail.
##
## The screen is built to be measured. It is a title-screen subscreen and is
## absent for the whole of play, so a budget that could only be read while it was
## open would be unreadable exactly when someone is editing the sentence. It is
## built inside a throwaway SubViewport rather than under the running game so
## that NotebookScreen._ready()'s grab_focus() lands somewhere harmless, and it is
## removed before this function returns, so no frame is ever drawn with it in.
##
## And it is why this one budget is NOT on Game's startup path: building a whole
## screen and throwing it away is a fair price for a verb someone typed and a
## wrong one for every launch of the game. It is also the budget that needs it
## least -- the sentence is a constant and the font is a resource, so the number
## is the same on every launch of a build, which is precisely what a headless test
## is for.
func _budget_notebook_subhead() -> Dictionary:
	var screen := NotebookScreen.new()
	var frame := SubViewport.new()
	frame.size = Vector2i(screen.get_viewport_width(), screen.get_viewport_height())
	frame.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_dev.add_child(frame)
	frame.add_child(screen)
	var drawn: float = -1.0
	var text: String = ""
	var subhead: Label = screen.get_node_or_null("Subheading") as Label
	if subhead != null:
		text = subhead.text
		var font: Font = subhead.get_theme_font("font")
		var size_px: int = subhead.get_theme_font_size("font_size")
		if size_px <= 0:
			size_px = subhead.get_theme_default_font_size()
		if font != null and size_px > 0 and text != "":
			drawn = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
	_dev.remove_child(frame)
	frame.queue_free()

	var observations: Array[String] = []
	if text != "":
		observations.append("the sentence measured: \"%s\"" % text)
	if drawn <= 0.0:
		return Game.uncomputed_budget(Game.BUDGET_UNMEASURED, "notebook_subhead",
			"NotebookScreen.SUBHEAD_MAX_WIDTH", "res://game/notebook_screen.gd",
			"the centred subheading's drawn text",
			"no Subheading Label, or no theme font to measure it in",
			"the subheading reaches the two pane labels and the spread reads as one smear",
			observations)
	return Game.computed_budget("notebook_subhead", "NotebookScreen.SUBHEAD_MAX_WIDTH",
		"res://game/notebook_screen.gd", "subheading text",
		drawn, NotebookScreen.SUBHEAD_MAX_WIDTH, "px",
		"Font.get_string_size() over the live Subheading Label",
		("the centred sentence overhangs into \"The drawing\" and \"In the game\" -- it "
			+ "collides before it clips, so shorten the sentence or move PANE_LABEL_Y"),
		observations)


## Board.PATH_CORNERS. The one entry here with no headroom number, and it is not
## an omission.
##
## Three things were measured against the road these corners happen to produce --
## the pest ceiling's "3.5 pests per cell" reasoning, the dead-ground count, and
## the Sundew's coverage arithmetic -- and none of them is a ceiling this road is
## approaching. They are numbers written down once, in prose, against a road that
## looked like this. So there is nothing to subtract, and a headroom invented for
## them would be exactly the fiction this verb exists to prevent.
##
## What CAN be done is report what the road measures today, which is what the
## prose would have to be re-derived against. Deliberately without the values it
## was originally derived against: those already live in
## test_the_road_is_still_the_road_the_constants_were_measured_against, which
## fails naming them, and copying them here would make this the fifth place they
## can go stale.
func _budget_road_shape(game: Game) -> Dictionary:
	var board: Board = (game.board if game != null else null)
	# road_shape reads nothing but Board's own statics -- PATH_CORNERS, the
	# route and buildable set it produces -- and every one of is_path(),
	# route() and path_cell_count() self-heals via _build_path() on a Board
	# that never entered a tree (see is_path()'s own comment for why). So with
	# no Game to borrow a live board from, this stands one up itself: the same
	# throwaway shape _budget_notebook_subhead() uses for its screen, built,
	# read and freed without ever entering the tree or drawing a frame.
	var owns_board: bool = false
	if board == null:
		board = Board.new()
		owns_board = true
	var spends: String = "the road three other files were measured against"
	var when_out: String = ("nothing breaks loudly -- WaveDirector.SIMULTANEOUS_PEST_CEILING, "
		+ "the dead-ground count and the Sundew's coverage arithmetic all go on quoting a road "
		+ "that no longer exists. test_the_road_is_still_the_road_the_constants_were_measured_against "
		+ "is the alarm, and it names what has to be re-derived.")
	if board.path_cell_count() <= 0:
		var unmeasured: Dictionary = Game.uncomputed_budget(Game.BUDGET_UNMEASURED, "road_shape",
			"Board.PATH_CORNERS", "res://game/board.gd", spends,
			"a board whose path could not be built", when_out,
			Game.no_budget_observations())
		if owns_board:
			board.free()
		return unmeasured
	var route: PackedVector2Array = board.route()
	var length: float = 0.0
	for i: int in range(route.size() - 1):
		length += route[i].distance_to(route[i + 1])
	var observations: Array[String] = [
		("the road is %d cells and %s px of walking, entry to exit -- the two numbers the pest "
			+ "ceiling's reasoning is written against") % [
				board.path_cell_count(), Game.budget_number(length),
			],
	]
	var buildable: int = 0
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			if board.is_buildable(Vector2i(x, y)):
				buildable += 1
	observations.append("the route leaves %d buildable cells of %d" % [
		buildable, Board.ROWS * Board.COLS,
	])
	for id: StringName in PlantCatalog.ids():
		var reach: float = PlantCatalog.reach(id)
		if reach <= 0.0:
			continue
		var dead: int = 0
		for y: int in range(Board.ROWS):
			for x: int in range(Board.COLS):
				var cell := Vector2i(x, y)
				if not board.is_buildable(cell):
					continue
				if PlacementPreview.covered_road_cells(board, cell, reach) == 0:
					dead += 1
		observations.append("%s reaches %s px: %d of the %d buildable cells are dead ground" % [
			id, Game.budget_number(reach), dead, buildable,
		])
	observations.append("the Sundew's coverage arithmetic is prose -- no number here can check it")
	var described: Dictionary = Game.uncomputed_budget(Game.BUDGET_DESCRIBED, "road_shape",
		"Board.PATH_CORNERS", "res://game/board.gd", spends,
		("the three couplings are prose reasoned against this road, not ceilings it approaches, "
			+ "so there is nothing to subtract -- the measurements below are what they would "
			+ "have to be re-derived against"),
		when_out, observations)
	if owns_board:
		board.free()
	return described


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
