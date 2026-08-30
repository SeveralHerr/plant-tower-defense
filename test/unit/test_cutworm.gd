extends RefCounted

## The Cutworm boss, and the six species hooks it is the only user of.
##
## FRESH COVERAGE, written against the restored code rather than restored with it. The
## boss landed once (a6e4fe9), was deleted whole by 91458e6 along with ~1500 lines of its
## own tests, and came back gameplay-only. So the claims here are re-derived from what the
## code says it does — which is the honest way round: a test restored beside the code it
## tests proves the pair was consistent when it was written, not that either is right now.
##
## Everything the boss is made of is a `static func` on purpose (CLAUDE.md: headless
## executes no `_draw`), so most of this file needs no node at all. The two that do —
## `head_distance` and the zone lookup that reads the live spine — build one and free it.

var _T


func _board() -> Board:
	# Board builds its path lazily on first query, so no tree is needed to ask it about
	# geometry. Same factory the road tests use, and for the same reason: the shipped
	# board is what every constant in Cutworm was measured against.
	return Board.new()


## A configured boss, off the tree. `setup()` adds it to the `pests` group, which is
## harmless while it is treeless and NOT harmless once it enters one — see
## .claude/skills/godot-test-isolation for the group read that goes wrong. Every caller
## here frees it.
func _worm() -> Cutworm:
	var worm := Cutworm.new()
	worm.setup(Pest.CUTWORM, _board().route())
	return worm


# -- the body's geometry ------------------------------------------------------

func test_the_drawn_animal_is_the_fifteen_cells_the_wave_table_was_written_around() -> String:
	# The whole argument for wave 27 being one pest is this number: 953 px of body on a
	# 32-cell road. If it drops under about twelve cells the row stops being a boss and
	# becomes a lonely bug, and nothing else in the project would notice.
	var span: float = Cutworm.body_span()
	var err: String = _T.assert_float_eq(span, 924.0, 0.01,
		"21 gaps of STATION_SPACING between the end stations")
	if err != "":
		return err
	err = _T.assert_float_eq(Cutworm.drawn_length(), span + Cutworm.GIRTH, 0.01,
		"the drawn length is the station span plus the head cap")
	if err != "":
		return err
	var cells: float = Cutworm.drawn_length() / float(Board.CELL)
	return _T.assert_true(cells > 14.0 and cells < 15.5,
		"the body covers ~15 cells of the road, which is what makes the solo row a boss")


func test_the_body_tapers_head_to_tail_and_never_leaves_the_lane() -> String:
	# The profile is the difference between an animal and a hose. Asserted as a SHAPE
	# rather than at three sampled u's: a blunt head, a trunk that thins slightly, and a
	# tail that runs out to a point.
	var head: float = Cutworm.radius_at(0.0, 0.0, 0.0)
	var trunk: float = Cutworm.radius_at(0.40, 0.0, 0.0)
	var tail: float = Cutworm.radius_at(1.0, 0.0, 0.0)
	var err: String = _T.assert_gt(trunk, head,
		"the trunk is fatter than the blunt head, which is what gives the head a jaw")
	if err != "":
		return err
	err = _T.assert_gt(trunk, tail, "the tail tapers away; a constant radius is a hose")
	if err != "":
		return err
	# The lane is one cell wide, so half a cell is the hard ceiling — and the peristaltic
	# wave has to fit UNDER it too, which is why the sweep walks t as well as u.
	var half_lane: float = float(Board.CELL) * 0.5
	var widest: float = 0.0
	for ui: int in range(0, 101):
		for ti: int in range(0, 32):
			var r: float = Cutworm.radius_at(float(ui) / 100.0, float(ti) * 37.0,
				float(ti) * 0.2)
			widest = maxf(widest, r)
	return _T.assert_true(widest <= half_lane,
		"the fattest phase of the wave still fits the 64 px lane: %f <= %f"
			% [widest, half_lane])


func test_the_peristaltic_swing_is_whatever_the_lane_has_left_after_the_girth() -> String:
	# The two constants may not be tuned independently and this is the statement of why:
	# GIRTH at full swing is exactly what the half-lane has room for.
	var err: String = _T.assert_true(
		Cutworm.GIRTH * (1.0 + Cutworm.PERISTALSIS_AMPLITUDE) <= float(Board.CELL) * 0.5,
		"GIRTH at the wave's fat phase still fits half a lane")
	if err != "":
		return err
	# One sine, read by the thickness AND by the surge, so the pulse and the lurch cannot
	# drift apart. Its extremes are what that costs.
	var lo: float = INF
	var hi: float = -INF
	for i: int in range(0, 400):
		var v: float = Cutworm.peristalsis(float(i) * 3.0, float(i) * 0.05)
		lo = minf(lo, v)
		hi = maxf(hi, v)
	err = _T.assert_float_eq(hi, 1.0 + Cutworm.PERISTALSIS_AMPLITUDE, 0.01,
		"the wave peaks at exactly one amplitude above rest")
	if err != "":
		return err
	return _T.assert_float_eq(lo, 1.0 - Cutworm.PERISTALSIS_AMPLITUDE, 0.01,
		"and troughs the same distance below it")


func test_the_outline_sweep_takes_no_samples_across_a_body_that_has_not_emerged() -> String:
	# Before the head reaches a station the body is cut off at s = 0 rather than animated,
	# so the sweep is routinely asked for a backwards range. Returning 0 there is what
	# keeps `body_polygon_cost` honest during the burrow.
	var err: String = _T.assert_eq(Cutworm.sample_count(100.0, 100.0), 0,
		"a zero-length span draws nothing")
	if err != "":
		return err
	err = _T.assert_eq(Cutworm.sample_count(200.0, 100.0), 0,
		"and a backwards span draws nothing rather than a negative count")
	if err != "":
		return err
	# One step apart is two samples: both ends. The +1 is the fencepost the cost budget
	# is counted in.
	return _T.assert_eq(Cutworm.sample_count(0.0, Cutworm.OUTLINE_STEP), 2,
		"one step spans two samples, ends included")


func test_the_cutworms_frame_cost_stays_inside_its_budget() -> String:
	# THE NUMBER THAT WAS NOT BEING WATCHED, per body_polygon_cost's own header: an
	# 8.5 fps frame on a board that idles at 171. Draw calls are machine-independent, so
	# this is assertable with no game at all — and the budget is DERIVED from the
	# geometry rather than typed, so tightening OUTLINE_STEP moves the ceiling with it.
	var walk: float = RoadSpine.length_of(_board().route())
	# A `for` over a derived step count rather than a `while s <= walk`: the loop bound is
	# then the road's own length divided by the step, which is a number this file computes
	# instead of a property of the code under test. See tools/loop_bound_check.py.
	var worst: int = 0
	for i: int in range(int(walk / Cutworm.OUTLINE_STEP) + 1):
		var s: float = float(i) * Cutworm.OUTLINE_STEP
		worst = maxi(worst, Cutworm.body_polygon_cost(s, walk))
	var err: String = _T.assert_gt(worst, 0, "a boss mid-road draws something")
	if err != "":
		return err
	return _T.assert_true(worst <= Cutworm.MAX_BODY_POLYGONS,
		"the fattest frame costs %d polygons against a budget of %d"
			% [worst, Cutworm.MAX_BODY_POLYGONS])


func test_the_quad_area_gate_refuses_a_degenerate_strip() -> String:
	# The live-frame check asserts against this rather than a screenshot. A quad that has
	# collapsed is a strip segment that paints nothing, which is how a body opens a hole
	# on a bend without the polygon COUNT changing at all.
	var square := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10),
		Vector2(0, 10)])
	var err: String = _T.assert_float_eq(Cutworm.quad_area(square), 100.0, 0.01,
		"the shoelace formula on a 10x10 square")
	if err != "":
		return err
	var collapsed := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 0),
		Vector2(0, 0)])
	err = _T.assert_float_eq(Cutworm.quad_area(collapsed), 0.0, 0.01,
		"a quad with no width has no area")
	if err != "":
		return err
	return _T.assert_float_eq(Cutworm.quad_area(PackedVector2Array([Vector2.ZERO])), 0.0,
		0.01, "fewer than three points is not a quad and is worth zero, not a crash")


# -- the damage zones ---------------------------------------------------------

func test_a_hits_position_along_the_body_decides_what_it_is_worth() -> String:
	# The entire fight, as one function: the maw is worth 1.0, the clitellum 2.5, and the
	# hide between them 0.15. A player raking the trunk sees chip damage and learns to
	# aim; a player who never finds the band never kills the boss inside the wave.
	var err: String = _T.assert_float_eq(Cutworm.zone_multiplier(0.0), Cutworm.ZONE_MAW,
		0.001, "a hit on the head is worth full damage")
	if err != "":
		return err
	err = _T.assert_float_eq(Cutworm.zone_multiplier(Cutworm.MAW_REACH),
		Cutworm.ZONE_MAW, 0.001, "the maw reaches exactly one station back, inclusive")
	if err != "":
		return err
	var band_middle: float = float(Cutworm.BAND_FIRST_STATION + 1) * Cutworm.STATION_SPACING
	err = _T.assert_float_eq(Cutworm.zone_multiplier(band_middle), Cutworm.ZONE_BAND,
		0.001, "the clitellum is the soft spot and is worth more than the head")
	if err != "":
		return err
	# Between the maw and the band, and behind the band: hide both times. Two samples and
	# not one, because a band written with a one-sided comparison passes the near test.
	err = _T.assert_float_eq(
		Cutworm.zone_multiplier(Cutworm.MAW_REACH + Cutworm.STATION_SPACING),
		Cutworm.ZONE_HIDE, 0.001, "the shoulder between maw and band is hide")
	if err != "":
		return err
	return _T.assert_float_eq(
		Cutworm.zone_multiplier(float(Cutworm.BAND_LAST_STATION + 2)
			* Cutworm.STATION_SPACING),
		Cutworm.ZONE_HIDE, 0.001, "and everything behind the band is hide again")


func test_the_band_rides_the_stations_it_names_wherever_the_head_is() -> String:
	# `band_range` is the drawing's copy of the same table `zone_multiplier` answers from,
	# so the two agreeing is what stops the red stripe being painted somewhere the extra
	# damage is not. Swept along the whole walk rather than sampled at one head position.
	# Same derived bound as the budget sweep above, and for the same reason: 97 px is a
	# stride chosen to land off the station spacing, so the samples do not all fall on the
	# same phase of the band.
	const STRIDE: float = 97.0
	var walk: float = RoadSpine.length_of(_board().route())
	for i: int in range(int(walk / STRIDE) + 1):
		var head_s: float = float(i) * STRIDE
		var band: Vector2 = Cutworm.band_range(head_s)
		var err: String = _T.assert_true(band.x < band.y,
			"the band spans forward from its further-back edge at head_s %f" % head_s)
		if err != "":
			return err
		# The midpoint of the drawn band, expressed as distance behind the head, has to
		# be a spot the zone table calls the band.
		var behind: float = head_s - (band.x + band.y) * 0.5
		err = _T.assert_float_eq(Cutworm.zone_multiplier(behind), Cutworm.ZONE_BAND,
			0.001, "the middle of the painted band is worth ZONE_BAND at head_s %f"
				% head_s)
		if err != "":
			return err
	return ""


func test_an_untracked_hit_gets_the_hide_rather_than_the_head() -> String:
	# The conservative answer rather than the convenient one: a damage source added later
	# and wired up carelessly makes the boss HARDER, which shows up in a playtest, instead
	# of easier, which does not.
	var worm: Cutworm = _worm()
	var err: String = _T.assert_float_eq(worm.damage_multiplier_at(Vector2.INF),
		Cutworm.ZONE_HIDE, 0.001, "a caller that does not track where it hit gets hide")
	if err == "":
		# The head starts at the route's first point, off the west edge, so a hit there is
		# a hit on the maw — and `head_distance` is the whole state of the animal.
		err = _T.assert_float_eq(worm.head_distance(), 0.0, 0.001,
			"the boss starts burrowed at s = 0 rather than fully on the board")
	if err == "":
		err = _T.assert_float_eq(worm.damage_multiplier_at(worm.position),
			Cutworm.ZONE_MAW, 0.001, "a hit landing on the head is a hit on the maw")
	worm.free()
	return err


# -- the six species hooks ----------------------------------------------------

func test_every_species_hook_answers_for_the_ordinary_bug_and_the_boss_overrides_it() -> String:
	# The hooks exist so a damage source asks "how much is this hit worth" rather than
	# "which subclass am I shooting". Both halves are asserted here: the base answer that
	# every other species relies on, and the boss's override.
	var aphid := Pest.new()
	aphid.setup(Pest.APHID, _board().route())
	var worm: Cutworm = _worm()
	var err: String = _T.assert_float_eq(aphid.damage_multiplier_at(Vector2.INF), 1.0,
		0.001, "a 64 px body has no 'where' to ask about and takes hits whole")
	if err == "":
		err = _T.assert_true(aphid.halts_to_eat(),
			"a pest with a mouth at the front of one body stops to chew")
	if err == "":
		err = _T.assert_false(worm.halts_to_eat(),
			"a wall in front of the head does not hold the other fourteen cells back")
	if err == "":
		err = _T.assert_false(aphid.eats_in_passing(),
			"an unmutated aphid only eats what stands in its way")
	if err == "":
		err = _T.assert_true(worm.eats_in_passing(),
			"the boss answers yes permanently, without wearing a mutation it never rolled")
	if err == "":
		err = _T.assert_float_eq(aphid.slow_resistance(), 1.0, 0.001,
			"every other species takes the Sundew's slow in full")
	if err == "":
		err = _T.assert_float_eq(worm.slow_resistance(), Cutworm.SLOW_RESISTANCE, 0.001,
			"the boss takes half of it, so the Sundew stays worth buying without being "
				+ "the whole answer")
	if err == "":
		err = _T.assert_gt(worm.eat_dps(), aphid.eat_dps(),
			"the boss chews a bed faster than an aphid does")
	if err == "":
		err = _T.assert_float_eq(worm.eat_dps(),
			aphid.eat_dps() * Cutworm.EAT_MULTIPLIER, 0.001,
			"and by exactly the multiplier, read through the method rather than a "
				+ "second constant that drifts from the first")
	worm.free()
	aphid.free()
	return err


func test_the_mouth_may_not_close_on_a_boss_that_is_longer_than_the_plant() -> String:
	# `chew_seconds` is a duration and a duration is the wrong shape for "no": a very
	# large one still lets the plant commit, still plays the grab, and still ends with the
	# boss released. The flag is the answer, and `can_be_held` reads it, so the two cannot
	# disagree.
	var err: String = _T.assert_false(Pest.is_holdable(Pest.CUTWORM),
		"the Chomp cannot close on 953 px of animal")
	if err != "":
		return err
	err = _T.assert_true(Pest.is_holdable(Pest.APHID),
		"and every ordinary bug is still grabbable")
	if err != "":
		return err
	var worm: Cutworm = _worm()
	err = _T.assert_false(worm.can_be_held(),
		"the node's answer is the table's answer and not a second opinion")
	worm.free()
	return err


func test_a_resisted_slow_never_becomes_a_speed_up() -> String:
	# Written as "how much of the CUT is taken" rather than a second factor multiplied in,
	# because the two disagree at exactly the interesting end: a naive `factor * 2` on
	# 0.55 is 1.10, i.e. a Sundew that speeds the boss up.
	var full: float = StickySundew.SLOW_FACTOR
	var err: String = _T.assert_float_eq(StickySundew.resisted_factor(full, 1.0), full,
		0.001, "full resistance-free is the factor untouched, i.e. every species but one")
	if err != "":
		return err
	err = _T.assert_float_eq(StickySundew.resisted_factor(full, 0.0), 1.0, 0.001,
		"total resistance is no slow at all, not a negative one")
	if err != "":
		return err
	var half: float = StickySundew.resisted_factor(full, 0.5)
	err = _T.assert_true(half > full and half < 1.0,
		"half the cut sits between the full slow and no slow: %f" % half)
	if err != "":
		return err
	# The end that the rejected arithmetic gets wrong. Swept, because one sample cannot
	# tell a clamp from a coincidence.
	for i: int in range(0, 21):
		var r: float = float(i) / 20.0
		var f: float = StickySundew.resisted_factor(full, r)
		err = _T.assert_true(f <= 1.0,
			"a resisted slow at resistance %f is still a slow, not a shove: %f" % [r, f])
		if err != "":
			return err
	return ""


# -- the wave table's exemption ----------------------------------------------

func test_the_solo_boss_row_is_named_by_derivation_and_not_by_its_number() -> String:
	# `boss_solo_wave` is the exemption the threat sweep reads, and the point of it being
	# derived is that appending another solo boss moves every check that reads it at once.
	# So this asserts the RULE, not "wave 27".
	var solo: Array[int] = []
	for wave: int in range(1, WaveDirector.WAVES.size() + 1):
		if WaveDirector.boss_solo_wave(wave):
			solo.append(wave)
	var err: String = _T.assert_eq(solo.size(), 1,
		"exactly one row in the campaign is one boss and nothing else")
	if err != "":
		return err
	var row: Array = WaveDirector.WAVES[solo[0] - 1]
	err = _T.assert_eq(row.size(), 1, "the solo row carries one group")
	if err != "":
		return err
	err = _T.assert_true(Pest.is_boss(StringName(row[0]["species"])),
		"and that group's species is flagged a boss on its SPECIES row")
	if err != "":
		return err
	err = _T.assert_true(WaveDirector.wave_carries_boss(solo[0]),
		"so the HUD's prep note and the drought exemption pick it up for free")
	if err != "":
		return err
	# Out of range answers false rather than reaching past the table — endless spawns no
	# bosses, so there is nothing there to exempt.
	err = _T.assert_false(WaveDirector.boss_solo_wave(0), "wave 0 is not a row")
	if err != "":
		return err
	return _T.assert_false(WaveDirector.boss_solo_wave(WaveDirector.WAVES.size() + 1),
		"and neither is the first endless wave")


func test_the_last_swarm_is_the_seam_the_endless_ramp_is_priced_against() -> String:
	# `health_scale_for` makes the endless ramp a MULTIPLE of the campaign's last value,
	# and measured against the boss's row that comparison is meaningless — 1800 points of
	# one body against 424 of forty. So the seam reads the last SWARM, derived.
	var last: int = WaveDirector.last_swarm_wave()
	var err: String = _T.assert_gt(last, 0, "the campaign has at least one swarm in it")
	if err != "":
		return err
	err = _T.assert_false(WaveDirector.boss_solo_wave(last),
		"the seam wave is a swarm and not the solo boss")
	if err != "":
		return err
	for wave: int in range(last + 1, WaveDirector.WAVES.size() + 1):
		err = _T.assert_true(WaveDirector.boss_solo_wave(wave),
			"everything appended after the seam is a solo boss row (wave %d)" % wave)
		if err != "":
			return err
	return ""


# -- the road the body is swept along ----------------------------------------

func test_the_filleted_spine_rounds_the_road_without_leaving_it() -> String:
	# A SECOND READER of the road, not a replacement — every 64 px pest still walks the
	# unfilleted route. This exists for the one pest whose body is longer than the
	# straights it lies on.
	var board: Board = _board()
	var route: PackedVector2Array = board.route()
	var spine: PackedVector2Array = board.spine()
	var err: String = _T.assert_gt(spine.size(), route.size(),
		"rounding a corner costs samples; the spine is denser than the route")
	if err != "":
		return err
	# `Board.spine()` is a delegation and not a second implementation -- asserted rather
	# than read off the one-line body, because the default radius is the whole of what the
	# board contributes and a board that started rounding to its own number would draw the
	# boss on a road no other reader agrees with.
	err = _T.assert_eq(spine, RoadSpine.fillet(route, RoadSpine.FILLET),
		"the board's spine is RoadSpine.fillet at the shared radius, not a second rounding")
	if err != "":
		return err
	# Shorter, because a rounded corner cuts the diagonal off a right angle — and only
	# slightly, because the corners are a small part of a long road.
	var route_len: float = RoadSpine.length_of(route)
	var spine_len: float = RoadSpine.length_of(spine)
	err = _T.assert_true(spine_len < route_len,
		"the filleted road is shorter than the square one: %f < %f"
			% [spine_len, route_len])
	if err != "":
		return err
	err = _T.assert_true(spine_len > route_len * 0.9,
		"but only by the corners, not by a shortcut across the board")
	if err != "":
		return err
	# Ends are untouched. The boss has to arrive when the wave table says it does, which
	# is why it still takes its DISTANCE from the unfilleted route.
	err = _T.assert_true(spine[0].is_equal_approx(route[0]),
		"the fillet does not move where the road starts")
	if err != "":
		return err
	return _T.assert_true(spine[spine.size() - 1].is_equal_approx(route[route.size() - 1]),
		"nor where it ends")


func test_an_arc_length_index_reads_back_the_point_and_the_heading_it_was_built_from() -> String:
	# `cumulative` / `point_at` / `tangent_at` are the whole of how one scalar becomes a
	# body: station i sits at head_s - i * STATION_SPACING and asks these for a position.
	# A straight line is used rather than the board's road because the expected answers
	# are then arithmetic and not a second implementation of the same sampling.
	var line := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)])
	var cum: PackedFloat32Array = RoadSpine.cumulative(line)
	var err: String = _T.assert_eq(cum.size(), line.size(),
		"one cumulative distance per point, the first being zero")
	if err != "":
		return err
	err = _T.assert_float_eq(cum[0], 0.0, 0.001, "the first point is zero along")
	if err != "":
		return err
	err = _T.assert_float_eq(RoadSpine.length_of(line), 200.0, 0.01,
		"two 100 px legs is a 200 px walk")
	if err != "":
		return err
	err = _T.assert_true(RoadSpine.point_at(line, cum, 50.0).is_equal_approx(
		Vector2(50, 0)), "halfway along the first leg is halfway along the first leg")
	if err != "":
		return err
	err = _T.assert_true(RoadSpine.point_at(line, cum, 150.0).is_equal_approx(
		Vector2(100, 50)), "and past the bend the walk continues down the second")
	if err != "":
		return err
	# Clamped at both ends rather than extrapolated: before the head has emerged the body
	# is cut off at s = 0, and s past the end is a boss that has already left.
	err = _T.assert_true(RoadSpine.point_at(line, cum, -50.0).is_equal_approx(line[0]),
		"an s before the start clamps to the start rather than running off backwards")
	if err != "":
		return err
	err = _T.assert_true(RoadSpine.point_at(line, cum, 900.0).is_equal_approx(
		line[line.size() - 1]), "and an s past the end clamps to the end")
	if err != "":
		return err
	# The heading is what turns the head sprite and what the body's ribs are drawn
	# perpendicular to, so it is a unit vector or the body is drawn at the wrong width.
	var heading: Vector2 = RoadSpine.tangent_at(line, cum, 50.0)
	err = _T.assert_float_eq(heading.length(), 1.0, 0.01,
		"the tangent is normalised; an un-normalised one scales every rib it draws")
	if err != "":
		return err
	return _T.assert_true(heading.is_equal_approx(Vector2.RIGHT),
		"and mid-leg it points straight down the leg")


# -- what the Chomp does instead of biting the boss --------------------------

func test_the_mouth_says_which_bugs_it_can_finish_and_which_it_only_chews() -> String:
	# "eats small pests easily, takes a while eating bigger pests" as a number. The boss
	# is the case that broke the old phrasing: it is not slow to eat, it is not eaten.
	var err: String = _T.assert_float_eq(ChompFlower.meal_damage(),
		float(ChompFlower.BITES_PER_MEAL) * ChompFlower.BITE_DAMAGE, 0.001,
		"a whole meal is every bite of it")
	if err != "":
		return err
	err = _T.assert_true(ChompFlower.dies_in_the_mouth(ChompFlower.meal_damage()),
		"a bug on exactly a meal's worth of health is finished by the last bite")
	if err != "":
		return err
	err = _T.assert_false(ChompFlower.dies_in_the_mouth(ChompFlower.meal_damage() + 0.1),
		"and one point above it is spat out")
	if err != "":
		return err
	err = _T.assert_eq(ChompFlower.bites_to_kill(3.0), 3,
		"3 health against 1.0 bites is three bites, not two and a bit")
	if err != "":
		return err
	err = _T.assert_eq(ChompFlower.bites_to_kill(2.5), 3,
		"and the ceil is the whole point: a part-bite is still a bite")
	if err != "":
		return err
	return _T.assert_eq(ChompFlower.bites_to_kill(ChompFlower.meal_damage() + 1.0), 0,
		"a pest the mouth cannot finish has no killing bite, rather than a large one")
