extends RefCounted

## THE BUDGET AUDIT SUBSYSTEM, extracted whole out of `game/game.gd`
## (plant-tower-defense-2dlh, the game.gd split). Prices every layout/economy
## "budget" this project tracks — a pixel clearance, a label's worst-case width, a
## pest-road ceiling — against a floor declared in `BUDGET_FLOOR`, and reports which
## ones have run out. `Game.check_budgets()` calls into this once from `_ready()`;
## `Game.check_budgets()` calls `Game.budget_entries()` (itself a
## one-line forward to here) on demand.
##
## WHY THIS GROUP AND WHY A PLAIN RefCounted, not a new autoload. It was the single
## most self-contained ~830 lines of a 4630-line file: every function here either
## takes its own live-state (`board`, `hud`) as a PARAMETER instead of reading
## `self`, or needs no live state at all (`computed_budget`, `budget_regressions`,
## `budgets_at_floor`, `budget_number`, ... are pure data-in data-out, already —
## the original code on Game was already written `static`, just parked on the
## wrong class). Moving it cost no behavior: nothing here ever depended on being
## `self` on the same object as the plant/pest/wave logic, which is exactly what
## made it safe to cut first. `Game` still OWNS this — it is a plain object every
## `Game` call forwards into, not a second autoload competing with the first.
##
## DELIBERATELY NO `class_name`. This file is reached ONLY through
## `game.gd`'s own `const GameBudget := preload("res://game/game_budget.gd")` and
## the forwarding wrappers built on top of it — never named directly by anything
## outside `game.gd`. Two reasons, both load-bearing: (1) it is an implementation
## detail of Game, not a second public type the rest of the project should reach
## for, which a `class_name` would invite; (2) `test_every_game_class_is_at_least_
## named_somewhere_in_the_test_suite` (`test/unit/test_selftest.gd`) requires every
## `class_name` under `game/` to be named literally by some test — a real rule for
## a real class, and the wrong one to satisfy by teaching a test a name that exists
## only to be forwarded. `preload` keeps this file exactly what it is: private to
## `game.gd`.
##
## THE PUBLIC SURFACE ON `Game` DID NOT MOVE. Every symbol `devtools_ext/commands.gd`
## and `test/unit/*.gd` reference as `Game.BUDGET_FLOOR`, `Game.computed_budget(...)`,
## `game.budget_entries(...)`, `game.budget_report`, `game.warn_new_floors(...)` and so
## on is still there, as a re-exported const or a one-line delegating wrapper — see
## the "Budget audit (see game/game_budget.gd)" block near the end of `game.gd`.


## How far under its own CEILING a budget has to fall before it reads "tight" rather
## than "ok". A fraction of the ceiling, not of the floor — see `computed_budget`.
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
## -- 4 px of 32 on the husk sweep, 10 of 171 on the tightest readout, 10 of 1120
## on the row (plant-tower-defense-ncfv's Skins door is the third fixed control
## the row now carries, and the ratchet below is that commit's), and the road
## sits at exactly its pest ceiling. That rule prints
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
	# 53px, and roomy on purpose (plant-tower-defense-0y0w). The rack's widest label
	# is "Common Packet (20)" at 179 of 232px, and a price would have to gain four
	# digits to close that -- so this floor is not guarding today's margin, it is
	# guarding a FOURTH TIER with a longer name, which is the only realistic way the
	# rack ever overflows. Declared at 40 rather than at 53 so a modest retune does
	# not trip it; a new tier that eats 140px will.
	"packet_rack": 40.0,
	# FIVE PIXELS, on a surface where running out would have been silent
	# (plant-tower-defense-wf4i, justified by -yoc2's verdict).
	#
	# The run summary's value labels are `clip_text` with OVERRUN_TRIM_ELLIPSIS, so a
	# string that outgrows its column does not wrap and does not push anything: its
	# height is unchanged, which means BUTTON_CLEARANCE -- the only other gate on that
	# card -- reads a number a content regression cannot move. Nothing was watching.
	#
	# `run_summary.gd`'s own header carried a hand claim that the beds row "sets the
	# card's value-column high-water mark" at 36 CHARACTERS. It named the right string
	# and the wrong unit: measured in the font it renders in, that row draws 330.0 of
	# 335.2px. The claim was right and comfortable-sounding and the margin is 1.5%.
	"run_summary_values": 5.0,
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
	# Ratcheted DOWN from 19.0, the same pattern "hud_readouts" above used going up:
	# accept a spend by moving the floor to what the build now actually has, in the
	# same commit that spends it. The Skins door (plant-tower-defense-ncfv) is a
	# third fixed control on this row -- SKINS_BUTTON_SIZE is already cut to the
	# narrowest width the design-width floor allows (see its own comment in
	# hud.gd), so the only honest fix left for the LIVE headroom this specific
	# viewport measures is to declare what it now is rather than pretend the row
	# still has 19.
	"hud_stats_row": 10.0,
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
##
## Three rows sit at floor permanently, by ratchet. An unconditional warning naming them
## every launch is wallpaper within a day -- and a warning nobody reads is worse than no
## warning, because it is still there when the one that matters arrives. So the question the
## warning answers is not "is anything at floor" but "did THIS build spend a row's last
## pixel".
##
## Declared IN CODE rather than persisted to `user://` or to a gitignored file, and that is
## the whole design. Accepting a newly-at-floor row becomes a one-line edit that shows up in
## review next to the floor it concerns, which is where somebody can ask whether spending it
## was intended. A baseline written automatically at runtime would accept the regression
## silently on the next launch, which is the failure mode of every self-updating baseline.
##
## KEEP THIS IN SYNC BY LETTING THE WARNING TELL YOU. It reports both directions: a row here
## that is no longer at floor is named too, because a stale entry silences a real finding.
## READ OFF THE LIVE GAME, not guessed. `cmd budgets` on this build reports
## at_floor = [husk_click, run_summary_values, hud_readouts, hud_selection_panel] -- FOUR, and
## the bead that asked for this warning says three. My first draft of this list was written
## from the bead and was wrong in both directions: it named `hud_stats_row`, which is not at
## floor, and missed `husk_click` and `hud_readouts`. That draft passed every headless test I
## wrote, because the tests assert the WARNING's behaviour against whatever this list says --
## and it would have fired on every launch naming three rows as newly spent and one as stale,
## which is precisely the wallpaper this design exists to avoid.
const BUDGET_FLOOR_ACCEPTED: Array[String] = [
	"husk_click",
	"run_summary_values",
	"hud_readouts",
	"hud_selection_panel",
	# The Skins door (plant-tower-defense-ncfv): a third fixed control on the stats
	# row, priced against a floor moved down in the same commit -- see
	# BUDGET_FLOOR["hud_stats_row"]'s own comment.
	"hud_stats_row",
]

## What running the packet rack out of width costs, and what to do about it.
##
## A constant rather than a literal inside `_budget_packet_rack` because the test that
## proves this budget CAN fail has to rebuild the entry with a worsened width, and an
## assertion against a sentence the test itself typed proves nothing. Both sides read
## this, so the test checks that the production consequence reaches the warning.
const PACKET_RACK_WHEN_FULL: String = (
	"a packet label outgrows the fixed 232px button it is drawn in. The button "
	+ "cannot grow to fit -- packet_row_rect hands it a size -- so nothing pushes and "
	+ "no layout gate sees it. Shorten the tier's display name in "
	+ "SeedBank.PACKET_TIERS, or widen PANEL_WIDTH, which every other panel budget "
	+ "also divides by")


## Price every budget this run can price, compare each against BUDGET_FLOOR, and
## push_warning the ones that fell through it. Called once from `Game._ready()`
## through `Game.check_budgets()`.
##
## push_warning is a weak carrier on its own -- it reaches the editor's Errors
## tab and stderr, and `devtools.py launch` redirects stderr to a file nobody
## opens unless something already went wrong. So the same verdict is stored in
## `Game.budget_report`, which devtools_ext/commands.gd merges into the `status` of
## EVERY bus reply, and the noise question is settled by a test rather than by
## this comment: test_a_clean_launch_warns_about_no_budget_at_all in
## test/unit/test_economy.gd asserts a real startup produces zero warnings.
static func check_budgets(board: Board, hud: Hud) -> Dictionary:
	var entries: Array[Dictionary] = budget_entries(board, hud, BUDGET_WAVE_SWEEP)
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
	var report: Dictionary = {
		"summary": summary,
		"measured": measured,
		"declared": BUDGET_FLOOR.size(),
		"warnings": warnings,
	}
	for line: String in warnings:
		push_warning(line)
	# AFTER the regressions, deliberately. `budget_regressions()` reports what has fallen
	# THROUGH a floor, which is an error; this reports what newly came to REST on one, which
	# is a decision somebody made. Printing the error first keeps the ordering honest when
	# both fire, and the two never name the same row -- budgets_at_floor() excludes anything
	# budget_regressions() would report.
	warn_new_floors(entries)
	return report


## Every budget this run can price on its own, in the shape `cmd budgets` reports
## them. The verb appends the two it can only ask about with a bridge.
static func budget_entries(board: Board, hud: Hud, sweep: int = BUDGET_WAVE_SWEEP) -> Array[Dictionary]:
	var entries: Array[Dictionary] = [
		_budget_husk_click(board),
		_budget_packet_rack(),
		_budget_run_summary_values(),
		_budget_hud_readouts(hud),
		_budget_hud_message_row(hud),
		_budget_hud_stats_row(hud),
		_budget_hud_selection_panel(),
		_budget_pest_road_ceiling(maxi(1, sweep)),
	]
	return entries


## What `warn_new_floors` should say, or "" for nothing. Pure and static so the wording is
## assertable without launching the game -- the run that produces this state is a startup,
## which is the hardest moment to observe.
static func new_floor_warning(at_floor: Array[String], accepted: Array[String]) -> String:
	var newly: Array[String] = []
	for id: String in at_floor:
		if not accepted.has(id):
			newly.append(id)
	var lifted: Array[String] = []
	for id: String in accepted:
		if not at_floor.has(id):
			lifted.append(id)
	if newly.is_empty() and lifted.is_empty():
		return ""
	var parts: Array[String] = []
	if not newly.is_empty():
		parts.append("this build spent the last pixel of %s" % ", ".join(newly))
	if not lifted.is_empty():
		# Not a defect, and said anyway: an accepted entry that has lifted means the list is
		# stale, and a stale entry is a row whose next regression will be silent.
		parts.append("%s no longer rest%s at floor, so BUDGET_FLOOR_ACCEPTED is stale"
			% [", ".join(lifted), "" if lifted.size() > 1 else "s"])
	return "Budgets: %s." % "; ".join(parts)


## Print the warning, if there is one. Called from check_budgets() at startup.
static func warn_new_floors(entries: Array[Dictionary]) -> String:
	var text: String = new_floor_warning(budgets_at_floor(entries), BUDGET_FLOOR_ACCEPTED)
	if text != "":
		push_warning(text)
	return text


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
			+ "declares. %s. When it runs out: %s. Read the whole ledger with "
			+ "Game.budget_entries(); if the spend is intended, move Game.BUDGET_FLOOR[\"%s\"] "
			+ "to %s in the same commit.") % [
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
static func _budget_husk_click(board: Board) -> Dictionary:
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
static func _budget_hud_message_row(hud: Hud) -> Dictionary:
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
			Game.mute_message("Sound effects", true, KeyBindings.ACTION_MUTE_SFX, "them"),
			Game.mute_message("Music", true, KeyBindings.ACTION_MUTE_MUSIC)]:
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


## The packet rack's widest label against the fixed rect it is drawn into.
##
## Needs no live node, like the run summary's: `Hud.packet_rack_budget()` sweeps
## `SeedBank.PACKET_ORDER` and measures in the theme's Button font. The rack is the
## ONLY content-driven text in the side panel — the plant buttons are icon-only with
## their names in tooltips, which have no slot to overflow. See
## `Hud.packet_rack_corpus`'s header for why the rest of the panel is not priced.
static func _budget_packet_rack() -> Dictionary:
	var priced: Dictionary = Hud.packet_rack_budget()
	var corpus: Array[String] = Hud.packet_rack_corpus()
	var observations: Array[String] = [
		("widest of %d label(s) is \"%s\" at %s of %s px" % [
			corpus.size(), String(priced["text"]),
			budget_number(float(priced["needed"])), budget_number(float(priced["slot"])),
		]),
		("%d tier(s) in SeedBank.PACKET_ORDER x 2 stock states, at font size %d" % [
			# The size the buttons WEAR, matching what packet_rack_budget() measures at.
			# This said GardenTheme.BUTTON_FONT_SIZE while the budget measured at it too --
			# so the observation agreed with the budget and both disagreed with the screen
			# (plant-tower-defense-fo96).
			SeedBank.PACKET_ORDER.size(), Hud.PACKET_BUTTON_FONT_SIZE,
		]),
	]
	return computed_budget("packet_rack", "Hud.packet_row_rect().size.x",
		"res://game/hud.gd", "the packet rack's widest label",
		float(priced["needed"]), float(priced["slot"]), "px",
		"Hud.packet_rack_budget() over Hud.packet_rack_corpus()",
		PACKET_RACK_WHEN_FULL, observations)


## The run summary's value column against the widest string it can print.
##
## The only budget here that needs NO live node — `RunSummary.value_column_budget()`
## drives the card's own producers over `corpus_states()` and measures in the theme
## font, so this reads the same on a fresh boot as at a game over. That is deliberate:
## the card exists for about four seconds at the end of a run, and a budget that could
## only be read while it was on screen would be a budget nobody read.
static func _budget_run_summary_values() -> Dictionary:
	var priced: Dictionary = RunSummary.value_column_budget()
	var corpus: Array[String] = RunSummary.summary_corpus()
	var observations: Array[String] = [
		("widest of %d string(s) is \"%s\" at %s of %s px" % [
			corpus.size(), String(priced["text"]),
			budget_number(float(priced["needed"])), budget_number(float(priced["slot"])),
		]),
		("the column is %s%% of a %s px card less a %s px inset, at font size %d" % [
			budget_number(RunSummary.VALUE_COLUMN_FRACTION * 100.0),
			budget_number(RunSummary.CARD.size.x), budget_number(RunSummary.ROW_INSET),
			RunSummary.ROW_FONT_SIZE,
		]),
	]
	return computed_budget("run_summary_values",
		"RunSummary.value_slot_width()", "res://game/run_summary.gd",
		"the run summary's widest value",
		float(priced["needed"]), float(priced["slot"]), "px",
		"RunSummary.value_column_budget() over RunSummary.summary_corpus()",
		("a value string is trimmed to an ellipsis mid-word. It does NOT wrap and does "
			+ "not push the buttons, so BUTTON_CLEARANCE cannot see it -- the row simply "
			+ "stops saying what it said. Shorten the phrasing in the producer that "
			+ "built it, or widen VALUE_COLUMN_FRACTION at the key column's expense"),
		observations)


static func _budget_hud_readouts(hud: Hud) -> Dictionary:
	var stats: HBoxContainer = _stats_row(hud)
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
static func _budget_hud_stats_row(hud: Hud) -> Dictionary:
	var stats: HBoxContainer = _stats_row(hud)
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


static func _stats_row(hud: Hud) -> HBoxContainer:
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
static func _budget_hud_selection_panel() -> Dictionary:
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
static func _budget_pest_road_ceiling(sweep: int) -> Dictionary:
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
