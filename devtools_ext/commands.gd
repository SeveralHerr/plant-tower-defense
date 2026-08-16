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
# WORST_CASE_TEXT prices four readouts against a row that has eleven pixels
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

## A budget is "tight" once less than this fraction of its ceiling is unspent.
##
## 0.15 rather than something smaller because these budgets are small in absolute
## terms and nearly all of them are already near their end: 4 px of 32 on the husk
## sweep, ~7 px of 168 on the seeds readout, 11 px of 1112 on the stats row. A
## threshold that called those comfortable would report a clean board right up to
## the day one of them breaks, which is the failure mode this verb exists against.
const BUDGET_TIGHT_FRACTION: float = 0.15

## Waves swept when pricing the road's simultaneous-pest ceiling. The peak lands
## around wave 20 -- see test_an_endless_wave_never_fills_the_road_past_the_stated_ceiling,
## which sweeps 300 -- so this is well past it and still cheap enough to run on
## the frame the bus answers from. Override with `--args '{"waves": 300}'`.
const BUDGET_WAVE_SWEEP: int = 120

## Reported when a budget's own inputs could not be read this run. Distinct from
## "described", which means there was never a number to read: an unmeasured
## budget is a hole in the readout and a described one is a property of the
## coupling. Collapsing the two is how a check disappears from a report.
const BUDGET_UNMEASURED: String = "unmeasured"
const BUDGET_DESCRIBED: String = "described"


## Every declared budget with its current headroom.
##
## args: id (String, one budget's id, default all), waves (int, the sweep for the
## pest ceiling).
##
## data keys: budgets (Array of entry Dictionaries), count/computed/uncomputed/
## spent/tight (int), tightest (String, the id with the least headroom left as a
## fraction of its ceiling, or ""), summary (String, the same line as `message`).
##
## Entry keys, all JSON-safe: id, constant, declared_in, spends, units, state,
## measured_by, summary, when_it_runs_out (String); computed (bool); spent,
## ceiling, headroom (float, all -1.0 when computed is false); observations
## (Array[String]).
func _cmd_budgets(args: Dictionary) -> Dictionary:
	var game: Game = _game()
	if game == null:
		return _fail("no Game in the tree")
	var sweep: int = maxi(1, int(args.get("waves", BUDGET_WAVE_SWEEP)))
	var wanted: String = str(args.get("id", ""))
	var all: Array[Dictionary] = [
		_budget_husk_click(game),
		_budget_notebook_subhead(),
		_budget_hud_readouts(game),
		_budget_hud_stats_row(game),
		_budget_pest_road_ceiling(sweep),
		_budget_road_shape(game),
	]
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
		elif state == "tight":
			tight += 1
		var ceiling: float = float(entry["ceiling"])
		if ceiling <= 0.0:
			continue
		var fraction: float = float(entry["headroom"]) / ceiling
		if fraction < tightest_fraction:
			tightest_fraction = fraction
			tightest = str(entry["id"])
	var headline: String = "%d budget(s): %d computed, %d without a number -- %d spent, %d tight" % [
		entries.size(), computed, entries.size() - computed, spent, tight,
	]
	if tightest != "":
		for entry: Dictionary in entries:
			if str(entry["id"]) == tightest:
				headline += "; tightest %s: %s" % [tightest, entry["summary"]]
				break
	return {
		"success": true,
		"message": headline,
		"data": {
			"budgets": entries,
			"count": entries.size(),
			"computed": computed,
			"uncomputed": entries.size() - computed,
			"spent": spent,
			"tight": tight,
			"tightest": tightest,
			"summary": headline,
		},
	}


## A budget whose headroom was measured this run. `spent` and `ceiling` come from
## the live call named in `measured_by`; the subtraction and the verdict happen
## here so no two entries can grade themselves differently.
func _computed_budget(id: String, constant: String, declared_in: String, spends: String,
		spent: float, ceiling: float, units: String, measured_by: String,
		when_it_runs_out: String, observations: Array[String]) -> Dictionary:
	var headroom: float = ceiling - spent
	var state: String = "ok"
	if headroom <= 0.0:
		state = "spent"
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
			spends, _budget_number(spent), _budget_number(ceiling), units,
			_budget_number(headroom), units,
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
func _uncomputed_budget(state: String, id: String, constant: String, declared_in: String,
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
static func _no_observations() -> Array[String]:
	var empty: Array[String] = []
	return empty


## Whole numbers print whole. "husk sweep 28 of 32 px max" is the sentence this
## verb exists to produce, and "28.0 of 32.0" is the same sentence wearing a
## spreadsheet.
static func _budget_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % int(roundf(value))
	return "%.1f" % value


## CompostMeter.COLLECT_RADIUS against the closest the pests' lane comes to
## ground a plant may stand on.
##
## Not recomputed here: this is PlacementPreview.husk_click_budget(), the same
## call `board_info` prints and the same terms the gate asserts on, so the two
## verbs cannot report different clearances for the same board.
func _budget_husk_click(game: Game) -> Dictionary:
	var budget: Dictionary = PlacementPreview.husk_click_budget(game.board)
	var observations: Array[String] = [str(budget["summary"])]
	if not bool(budget["measured"]):
		return _uncomputed_budget(BUDGET_UNMEASURED, "husk_click",
			"CompostMeter.COLLECT_RADIUS", "res://game/compost_meter.gd",
			"husk sweep radius",
			"the board has no route to walk, so there is no lane to measure from",
			"a click could sweep a husk while standing on plantable ground",
			observations)
	return _computed_budget("husk_click", "CompostMeter.COLLECT_RADIUS",
		"res://game/compost_meter.gd", "husk sweep",
		float(budget["collect_radius"]), float(budget["lane_to_buildable"]), "px",
		"PlacementPreview.husk_click_budget()",
		("at 0 px a click is genuinely ambiguous between sweeping a husk and planting: "
			+ "PlacementPreview needs a husk state it does not have, and Game._click_at "
			+ "can no longer put placement first"),
		observations)


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
		return _uncomputed_budget(BUDGET_UNMEASURED, "notebook_subhead",
			"NotebookScreen.SUBHEAD_MAX_WIDTH", "res://game/notebook_screen.gd",
			"the centred subheading's drawn text",
			"no Subheading Label, or no theme font to measure it in",
			"the subheading reaches the two pane labels and the spread reads as one smear",
			observations)
	return _computed_budget("notebook_subhead", "NotebookScreen.SUBHEAD_MAX_WIDTH",
		"res://game/notebook_screen.gd", "subheading text",
		drawn, NotebookScreen.SUBHEAD_MAX_WIDTH, "px",
		"Font.get_string_size() over the live Subheading Label",
		("the centred sentence overhangs into \"The drawing\" and \"In the game\" -- it "
			+ "collides before it clips, so shorten the sentence or move PANE_LABEL_Y"),
		observations)


## The four Hud.WORST_CASE_TEXT strings against the width each readout is clipped
## to. Reported as the WORST of the four, with every one of them listed as an
## observation: a row is only as safe as its tightest slot, and a mean would let
## a clipping Compost label hide behind a roomy Lives one.
##
## Measured in the real theme font off the live Labels, which is what makes this
## a readout rather than a copy of the comment in hud.gd -- a clipped Label
## renders "Seeds  4..." and nothing errors.
func _budget_hud_readouts(game: Game) -> Dictionary:
	var stats: HBoxContainer = _stats_row(game)
	if stats == null:
		return _uncomputed_budget(BUDGET_UNMEASURED, "hud_readouts",
			"Hud.WORST_CASE_TEXT", "res://game/hud.gd", "the widest readout's worst case",
			"no Root/TopBar/StatsRow in the running HUD",
			"a counter grows past its slot and renders trimmed, silently",
			_no_observations())
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
			readout, worst_case, _budget_number(needed), _budget_number(slot),
			_budget_number(slot - needed),
		])
		if slot - needed < worst_left:
			worst_left = slot - needed
			worst_name = readout
			worst_needed = needed
			worst_budget = slot
	if worst_name == "":
		return _uncomputed_budget(BUDGET_UNMEASURED, "hud_readouts",
			"Hud.WORST_CASE_TEXT", "res://game/hud.gd", "the widest readout's worst case",
			"none of the declared readouts could be measured",
			"a counter grows past its slot and renders trimmed, silently",
			observations)
	return _computed_budget("hud_readouts", "Hud.WORST_CASE_TEXT", "res://game/hud.gd",
		"%s worst case" % worst_name, worst_needed, worst_budget, "px",
		"Font.get_string_size() over each live readout in Root/TopBar/StatsRow",
		("%s renders its longest value trimmed to an ellipsis and nothing errors -- widen "
			+ "its slot, which spends the stats-row budget below") % worst_name,
		observations)


## Hud.stats_row_budget() -- the four slots plus the separations plus the wave
## button -- against the width of the row they have to fit inside.
##
## The sum is the invariant, not any one width: widening a readout to fix the
## entry above is paid for out of this one, which is the coupling the two entries
## exist to make visible together.
func _budget_hud_stats_row(game: Game) -> Dictionary:
	var stats: HBoxContainer = _stats_row(game)
	if stats == null or stats.get_child_count() <= 0 or stats.size.x <= 0.0:
		return _uncomputed_budget(BUDGET_UNMEASURED, "hud_stats_row",
			"Hud.stats_row_budget()", "res://game/hud.gd", "the stats row's contents",
			"no Root/TopBar/StatsRow in the running HUD, or it has no width yet",
			"the readouts push the wave button off the right edge of the bar",
			_no_observations())
	var needed: float = Hud.stats_row_budget(stats.get_child_count() - 1)
	var observations: Array[String] = [
		("%d children, so %d separations of %d px, plus a %d px wave button" % [
			stats.get_child_count(), stats.get_child_count() - 1,
			Hud.STATS_SEPARATION, int(Hud.NEXT_WAVE_BUTTON_SIZE.x),
		]),
	]
	return _computed_budget("hud_stats_row", "Hud.stats_row_budget()", "res://game/hud.gd",
		"stats row contents", needed, stats.size.x, "px",
		"Hud.stats_row_budget() against the live StatsRow's width",
		("the readouts stop fitting: with the Spacer in the row an over-long one shoves the "
			+ "wave button off the bar rather than overlapping it, which is not a fix"),
		observations)


func _stats_row(game: Game) -> HBoxContainer:
	if game.hud == null:
		return null
	return game.hud.get_node_or_null("Root/TopBar/StatsRow") as HBoxContainer


## WaveDirector.SIMULTANEOUS_PEST_CEILING against the worst wave in a sweep.
##
## The one dependent of Board.PATH_CORNERS that has a real ceiling, so it is the
## one that gets a number. Swept rather than sampled: the peak lands early, where
## the swarm and the column both still sit on the road at their natural spacing,
## and a probe at wave 100 would report the road half empty.
func _budget_pest_road_ceiling(sweep: int) -> Dictionary:
	var worst: int = 0
	var worst_wave: int = 0
	for wave: int in range(1, sweep + 1):
		var peak: int = WaveDirector.peak_simultaneous_pests(wave)
		if peak > worst:
			worst = peak
			worst_wave = wave
	if worst <= 0:
		return _uncomputed_budget(BUDGET_UNMEASURED, "pest_road_ceiling",
			"WaveDirector.SIMULTANEOUS_PEST_CEILING", "res://game/wave_director.gd",
			"pests on the road at once",
			"the sweep of %d wave(s) found no wave that puts a pest on the road" % sweep,
			"more pests walk the road at once than it was ever sized for",
			_no_observations())
	var observations: Array[String] = [
		"worst of waves 1-%d is wave %d, at %d pests walking at once" % [sweep, worst_wave, worst],
		("the ceiling itself is reasoned from the road's length -- see the road_shape entry, "
			+ "which is what moving Board.PATH_CORNERS actually invalidates"),
	]
	return _computed_budget("pest_road_ceiling", "WaveDirector.SIMULTANEOUS_PEST_CEILING",
		"res://game/wave_director.gd", "peak pests on the road",
		float(worst), float(WaveDirector.SIMULTANEOUS_PEST_CEILING), "pests",
		"WaveDirector.peak_simultaneous_pests() swept over waves 1-%d" % sweep,
		("the road holds more pests than the pacing was sized for and the frame rate is the "
			+ "thing that gives -- _paced_gap is the lever, not the wave table"),
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
	var board: Board = game.board
	var spends: String = "the road three other files were measured against"
	var when_out: String = ("nothing breaks loudly -- WaveDirector.SIMULTANEOUS_PEST_CEILING, "
		+ "the dead-ground count and the Sundew's coverage arithmetic all go on quoting a road "
		+ "that no longer exists. test_the_road_is_still_the_road_the_constants_were_measured_against "
		+ "is the alarm, and it names what has to be re-derived.")
	if board == null or board.path_cell_count() <= 0:
		return _uncomputed_budget(BUDGET_UNMEASURED, "road_shape", "Board.PATH_CORNERS",
			"res://game/board.gd", spends,
			"no board, or a board whose path has not been built", when_out,
			_no_observations())
	var route: PackedVector2Array = board.route()
	var length: float = 0.0
	for i: int in range(route.size() - 1):
		length += route[i].distance_to(route[i + 1])
	var observations: Array[String] = [
		("the road is %d cells and %s px of walking, entry to exit -- the two numbers the pest "
			+ "ceiling's reasoning is written against") % [
				board.path_cell_count(), _budget_number(length),
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
			id, _budget_number(reach), dead, buildable,
		])
	observations.append("the Sundew's coverage arithmetic is prose -- no number here can check it")
	return _uncomputed_budget(BUDGET_DESCRIBED, "road_shape", "Board.PATH_CORNERS",
		"res://game/board.gd", spends,
		("the three couplings are prose reasoned against this road, not ceilings it approaches, "
			+ "so there is nothing to subtract -- the measurements below are what they would "
			+ "have to be re-derived against"),
		when_out, observations)


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
