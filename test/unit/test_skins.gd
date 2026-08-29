extends RefCounted

## Unlockable skins for every plant and every pest (plant-tower-defense-ncfv).
##
## Split three ways, matching the mechanism's own split: `Skins` is pure data and
## rule (asserted with no RunConfig, no Game, no save file), `RunConfig`'s
## `selected_skin()` / `set_skin()` and the v10 save line are the persistence half,
## and `SkinsScreen` is the one Control-shaped piece, driven through
## `_T.instantiate_ui`.
##
## A NEW FILE RATHER THAN AN ADDITION TO test_selftest.gd: four lanes are working
## this bead's neighbours in parallel worktrees and test_selftest.gd is already the
## file every one of them is most likely to touch, so a new mechanism gets a new
## file to keep this lane's own tests out of that merge.

const GAME_SCENE := "res://game/game.tscn"

## Where this script's RunConfig writes go instead of the player's own save.
## `set_skin()` reaches `RunConfig._save()` on a successful call, and several tests
## here call it to prove persistence -- without a redirect those calls write the
## developer's real `user://highscore.save`. `tools/save_persist_check.py` requires
## this of any test script that can reach `_save()`.
const SUITE_SAVE_PATH := "user://test_skins_suite.save"
var _suite_stashed_save_path: String = ""

var _T


func setup() -> void:
	_suite_stashed_save_path = RunConfig.save_path
	RunConfig.save_path = SUITE_SAVE_PATH


## Called by the runner after every test in this file, including one that aborted
## on a runtime error.
func teardown() -> void:
	if _suite_stashed_save_path != "":
		RunConfig.save_path = _suite_stashed_save_path
	DirAccess.remove_absolute(SUITE_SAVE_PATH)


# -- Skins: pure data and rule -----------------------------------------------


func test_every_plant_and_every_pest_gets_exactly_one_skins_row() -> String:
	var targets: Array[Dictionary] = Skins.targets()
	var expected: int = PlantCatalog.ids().size() + Pest.SPECIES.size()
	var err: String = _T.assert_eq(targets.size(), expected,
		"one row per plant kind plus one per pest species, no more and no fewer")
	if err == "":
		var seen: Dictionary = {}
		for target: Dictionary in targets:
			var key: String = Skins.selection_key(target["kind"], target["id"])
			err = _T.assert_false(seen.has(key), "%s is not listed twice" % key)
			if err != "":
				break
			seen[key] = true
			err = _T.assert_true(Skins.has_target(target["kind"], target["id"]),
				"%s is a target Skins.has_target recognises" % key)
			if err != "":
				break
	return err


## The bead's own title -- "for every plant and every pest" -- read literally: a
## pest species this build adds later is swept in for free because `Skins.pest_ids()`
## is derived from `Pest.SPECIES.keys()` rather than a list kept in skins.gd. Cannot
## exercise lane F's two new species from this worktree, so this asserts the
## DERIVATION instead of a fixed count.
func test_plant_ids_and_has_family_answer_directly() -> String:
	var ids: Array[StringName] = Skins.plant_ids()
	var err: String = _T.assert_eq(ids, PlantCatalog.ids(),
		"Skins.plant_ids() is PlantCatalog's own order, not a second copy of it")
	if err == "":
		err = _T.assert_true(Skins.has_family(Skins.DEFAULT_SKIN), "the default family is known")
	if err == "":
		err = _T.assert_false(Skins.has_family(&"not_a_real_skin"), "and an unknown id is not")
	return err


func test_pest_targets_are_derived_from_pest_species_not_a_list() -> String:
	var derived: Array[StringName] = Skins.pest_ids()
	var err: String = _T.assert_eq(derived.size(), Pest.SPECIES.size(),
		"every key in Pest.SPECIES became a target")
	for id: StringName in derived:
		if err != "":
			break
		err = _T.assert_true(Pest.SPECIES.has(id), "%s is a real species" % id)
	return err


func test_the_default_skin_is_always_unlocked_and_white() -> String:
	var err: String = _T.assert_true(Skins.is_unlocked(Skins.DEFAULT_SKIN, {}),
		"the default skin needs no milestone")
	if err == "":
		err = _T.assert_eq(Skins.tint_for(Skins.DEFAULT_SKIN), Color(1.0, 1.0, 1.0),
			"and paints no visible change")
	return err


func test_a_milestone_gated_skin_locks_until_its_milestone_is_earned() -> String:
	var gated: Array[Dictionary] = []
	for row: Dictionary in Skins.FAMILIES:
		if String(row.get("unlock_milestone", "")) != "":
			gated.append(row)
	var err: String = _T.assert_gt(gated.size(), 0,
		"at least one skin is milestone-gated -- otherwise the rest of this test "
			+ "checks nothing")
	for row: Dictionary in gated:
		if err != "":
			break
		var id := StringName(row["id"])
		var milestone: String = String(row["unlock_milestone"])
		err = _T.assert_false(Skins.is_unlocked(id, {}), "%s is locked with nothing earned" % id)
		if err == "":
			err = _T.assert_true(Skins.is_unlocked(id, {milestone: true}),
				"and unlocks once %s is earned" % milestone)
		if err == "":
			# Every gated family names a milestone Milestones.gd actually has a row
			# for -- Milestones.entry() returning {} here would mean this skin can
			# never be unlocked by any run, milestone-gated forever.
			err = _T.assert_false(Milestones.entry(milestone).is_empty(),
				"%s's unlock_milestone %s is a real row in Milestones.TABLE" % [id, milestone])
	return err


func test_an_unknown_skin_id_is_locked_and_untinted() -> String:
	var err: String = _T.assert_false(Skins.is_unlocked(&"not_a_real_skin", {"campaign_cleared": true}),
		"an id this build does not know is never unlocked, whatever is earned")
	if err == "":
		err = _T.assert_eq(Skins.tint_for(&"not_a_real_skin"), Color(1.0, 1.0, 1.0),
			"and reads as untinted rather than erroring -- the same contract "
				+ "Pest.tint_for uses for an unknown mutation")
	return err


## unlocked_families() always answers at least [DEFAULT_SKIN], and only what the
## milestones passed in actually earned -- exercised at both ends of the table
## rather than one hand-picked milestone, per enumerate-the-pairs.
func test_unlocked_families_grows_exactly_with_earned_milestones() -> String:
	var none: Array[Dictionary] = Skins.unlocked_families({})
	var err: String = _T.assert_eq(none.size(), 1, "nothing earned unlocks only the default")
	if err == "":
		var earned: Dictionary = {}
		for row: Dictionary in Skins.FAMILIES:
			var milestone: String = String(row.get("unlock_milestone", ""))
			if milestone != "":
				earned[milestone] = true
		var all: Array[Dictionary] = Skins.unlocked_families(earned)
		err = _T.assert_eq(all.size(), Skins.FAMILIES.size(),
			"every milestone earned unlocks every family, none left out")
	return err


## next_unlocked() cycles through exactly the unlocked set and wraps, never landing
## on a locked family and never getting stuck. Enumerated over the whole table
## rather than one hand-picked step (enumerate-the-pairs): every unlocked id's
## successor is itself unlocked, and walking FAMILIES.size() steps from any start
## returns to that start.
func test_next_unlocked_cycles_the_unlocked_set_and_wraps() -> String:
	var earned: Dictionary = {"campaign_cleared": true, "threat_peak": true}
	# unbroken_garden deliberately left unearned, so "frost" stays locked and the
	# cycle has a real gap to skip over rather than visiting every family.
	var unlocked: Array[Dictionary] = Skins.unlocked_families(earned)
	var err: String = _T.assert_true(unlocked.size() < Skins.FAMILIES.size(),
		"the fixture leaves at least one family locked, or this test checks nothing")
	if err == "":
		var current: StringName = Skins.DEFAULT_SKIN
		var visited: Dictionary = {}
		for _i: int in Skins.FAMILIES.size():
			current = Skins.next_unlocked(current, earned)
			err = _T.assert_true(Skins.is_unlocked(current, earned),
				"next_unlocked never lands on a locked family, got %s" % current)
			if err != "":
				break
			visited[current] = true
		if err == "":
			err = _T.assert_eq(visited.size(), unlocked.size(),
				"cycling visits exactly the unlocked set, wrapping rather than growing")
	if err == "":
		err = _T.assert_false(visited_contains_locked(unlocked, earned),
			"sanity: nothing in unlocked_families() is actually locked")
	return err


func visited_contains_locked(rows: Array[Dictionary], earned: Dictionary) -> bool:
	for row: Dictionary in rows:
		if not Skins.is_unlocked(StringName(row["id"]), earned):
			return true
	return false


# -- RunConfig: persistence and the door -------------------------------------


func test_set_skin_refuses_an_unknown_target() -> String:
	var stashed: Dictionary = RunConfig.selected_skins.duplicate()
	RunConfig.selected_skins = {}
	var ok: bool = RunConfig.set_skin(Skins.KIND_PLANT, &"not_a_plant", Skins.DEFAULT_SKIN)
	var err: String = _T.assert_false(ok, "an unknown plant id is refused")
	if err == "":
		err = _T.assert_eq(RunConfig.selected_skins.size(), 0, "and nothing was recorded")
	RunConfig.selected_skins = stashed
	return err


func test_set_skin_refuses_a_skin_not_yet_unlocked() -> String:
	var stashed_selections: Dictionary = RunConfig.selected_skins.duplicate()
	var stashed_milestones: Dictionary = RunConfig.earned_milestones.duplicate()
	RunConfig.selected_skins = {}
	RunConfig.earned_milestones = {}
	var plant: StringName = PlantCatalog.ids()[0]
	var ok: bool = RunConfig.set_skin(Skins.KIND_PLANT, plant, &"golden")
	var err: String = _T.assert_false(ok, "golden is refused with campaign_cleared unearned")
	if err == "":
		err = _T.assert_eq(RunConfig.selected_skin(Skins.KIND_PLANT, plant), Skins.DEFAULT_SKIN,
			"and the plant reads back as the default, not a half-set choice")
	RunConfig.selected_skins = stashed_selections
	RunConfig.earned_milestones = stashed_milestones
	return err


## The round trip a milestone actually earns: unlock, choose, and read the choice
## back -- for a plant and a pest, since the mechanism is meant to cover both.
func test_set_skin_persists_once_the_milestone_is_earned() -> String:
	var stashed_selections: Dictionary = RunConfig.selected_skins.duplicate()
	var stashed_milestones: Dictionary = RunConfig.earned_milestones.duplicate()
	var stashed_path: String = RunConfig.save_path
	RunConfig.save_path = "user://test_skins_persist.save"
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(RunConfig.save_path + suffix):
			DirAccess.remove_absolute(RunConfig.save_path + suffix)
	RunConfig.selected_skins = {}
	RunConfig.earned_milestones = {"campaign_cleared": true}
	var plant: StringName = PlantCatalog.ids()[0]
	var pest: StringName = StringName(Pest.SPECIES.keys()[0])
	var err: String = _T.assert_true(RunConfig.set_skin(Skins.KIND_PLANT, plant, &"golden"),
		"golden lands on the plant once campaign_cleared is earned")
	if err == "":
		err = _T.assert_eq(RunConfig.selected_skin(Skins.KIND_PLANT, plant), &"golden",
			"and reads back as chosen")
	if err == "":
		# The pest side of the same door -- threat_peak, not campaign_cleared, so this
		# also proves ember and golden are independent gates rather than one flag.
		RunConfig.earned_milestones["threat_peak"] = true
		err = _T.assert_true(RunConfig.set_skin(Skins.KIND_PEST, pest, &"ember"),
			"ember lands on the pest once threat_peak is earned")
	if err == "":
		err = _T.assert_eq(RunConfig.selected_skin(Skins.KIND_PEST, pest), &"ember",
			"and reads back as chosen too")
	if err == "":
		# Idempotent, the same contract record_milestones documents for itself.
		err = _T.assert_true(RunConfig.set_skin(Skins.KIND_PLANT, plant, &"golden"),
			"choosing the same skin twice still reports success")
	if err == "":
		var bytes: String = FileAccess.get_file_as_string(RunConfig.save_path)
		err = _T.assert_true(bytes.contains(Skins.selection_key(Skins.KIND_PLANT, plant) + "=golden"),
			"the choice actually reached disk: %s" % bytes)
		if err == "":
			err = _T.assert_true(bytes.contains(Skins.selection_key(Skins.KIND_PEST, pest) + "=ember"),
				"and so did the pest's: %s" % bytes)
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(RunConfig.save_path + suffix):
			DirAccess.remove_absolute(RunConfig.save_path + suffix)
	RunConfig.save_path = stashed_path
	RunConfig.selected_skins = stashed_selections
	RunConfig.earned_milestones = stashed_milestones
	return err


## A skin the player chose can still be LOST if the save that recorded the
## milestone gets corrupted independently of the one that recorded the choice --
## `selected_skin()` has to notice rather than hand back a colour for a milestone
## that, as far as this session is concerned, was never earned.
func test_selected_skin_falls_back_to_default_if_its_milestone_is_no_longer_earned() -> String:
	var stashed_selections: Dictionary = RunConfig.selected_skins.duplicate()
	var stashed_milestones: Dictionary = RunConfig.earned_milestones.duplicate()
	# set_skin() below succeeds, and a successful set_skin() saves -- redirected so
	# that write lands on scratch rather than the developer's real save file, the
	# same discipline every other test here that can reach _save() follows.
	var stashed_path: String = RunConfig.save_path
	RunConfig.save_path = "user://test_skins_fallback.save"
	RunConfig.earned_milestones = {"campaign_cleared": true}
	var plant: StringName = PlantCatalog.ids()[0]
	RunConfig.selected_skins = {}
	var err: String = _T.assert_true(RunConfig.set_skin(Skins.KIND_PLANT, plant, &"golden"),
		"golden is chosen while the milestone stands")
	if err == "":
		RunConfig.earned_milestones = {}
		err = _T.assert_eq(RunConfig.selected_skin(Skins.KIND_PLANT, plant), Skins.DEFAULT_SKIN,
			"and reads back as the default once the milestone is gone, not as golden")
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(RunConfig.save_path + suffix):
			DirAccess.remove_absolute(RunConfig.save_path + suffix)
	RunConfig.save_path = stashed_path
	RunConfig.selected_skins = stashed_selections
	RunConfig.earned_milestones = stashed_milestones
	return err


# -- The v10 save line: compose, parse, and reading a v9 file forward --------


func test_compose_and_parse_skins_line_round_trip() -> String:
	var selections: Dictionary = {
		Skins.selection_key(Skins.KIND_PLANT, PlantCatalog.ids()[0]): "golden",
		Skins.selection_key(Skins.KIND_PEST, StringName(Pest.SPECIES.keys()[0])): "frost",
	}
	var line: String = RunConfig.compose_skins_line(selections)
	var err: String = _T.assert_true(line.begins_with("s2 "), "two entries, count-prefixed: %s" % line)
	if err == "":
		var parsed: Variant = RunConfig.parse_skins_line(line)
		err = _T.assert_eq(parsed, selections, "parse_skins_line reads back exactly what was written")
	return err


func test_compose_skins_line_drops_default_selections() -> String:
	var line: String = RunConfig.compose_skins_line({
		Skins.selection_key(Skins.KIND_PLANT, PlantCatalog.ids()[0]): String(Skins.DEFAULT_SKIN),
	})
	return _T.assert_eq(line, "s0", "a default selection is absence, not a recorded default")


func test_parse_skins_line_refuses_malformed_lines() -> String:
	var cases: Array[String] = [
		"d0",                     # a difficulty line, not a skins line -- wrong prefix
		"s1",                     # count says one, no fields follow
		"s0 plant:sunflower=golden",  # count says zero, one field follows
		"splant:sunflower=golden",    # no space, the count is unparsable
		"s1 plant:sunflower",         # no "=" at all
		"s1 plantsunflower=golden",   # no ":" between kind and id
		"s1 :sunflower=golden",       # empty kind before the ":"
		"s1 plant:=golden",           # empty id after the ":"
		"s1 plant:sunflower=",        # empty value
		"s1 PLANT:sunflower=golden",  # uppercase is not in MILESTONE_ID_CHARS
		"s2 plant:sunflower=golden plant:sunflower=frost",  # the same key twice
	]
	for text: String in cases:
		var parsed: Variant = RunConfig.parse_skins_line(text)
		var err: String = _T.assert_true(parsed == null, "%s is refused, got %s" % [text, parsed])
		if err != "":
			return err
	return ""


## THE ACCEPTANCE CRITERION: a v9 file loads forward with no skins unlocked, not a
## crash and not a reset of the fields v9 already had.
func test_a_v9_save_loads_forward_with_no_skins_selected() -> String:
	var path := "user://test_skins_v9_forward.save"
	var stashed_path: String = RunConfig.save_path
	var stashed_selections: Dictionary = RunConfig.selected_skins.duplicate()
	var stashed_milestones: Dictionary = RunConfig.earned_milestones.duplicate()
	var stashed_campaign: int = RunConfig.campaign_high_score
	var stashed_endless: int = RunConfig.endless_high_score
	var stashed_status: String = RunConfig.load_status
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

	# A hand-typed v9 file: every field v9 ever wrote, and nothing past the binding
	# count -- no "sN" line, because no build before v10 ever wrote one.
	var v9_bytes: String = ("v9\n1234\n5678\nm1:campaign_cleared\ncb1 sfx0 mus0 spd0 svol0 mvol0\n"
		+ "d1 campaign:harsh=99\n1\ngarden_pause %d\n") % KEY_F1
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(v9_bytes)
	f.close()

	RunConfig.save_path = path
	RunConfig._load()
	var err: String = _T.assert_eq(RunConfig.load_status, "migrated",
		"a v9 file loads and is rewritten forward rather than refused, got %s"
			% RunConfig.load_status)
	if err == "":
		err = _T.assert_eq(RunConfig.selected_skins, {},
			"no skins were unlocked by a build that predates the Skins screen -- "
				+ "not a crash, not every skin unlocked, an empty set")
	if err == "":
		# THE REST OF v9 SURVIVED THE MIGRATION -- the whole point of "reads forward"
		# rather than "refuses the file".
		err = _T.assert_eq(RunConfig.campaign_high_score, 1234, "the campaign score survived")
	if err == "":
		err = _T.assert_eq(RunConfig.endless_high_score, 5678, "the endless score survived")
	if err == "":
		err = _T.assert_true(RunConfig.has_milestone("campaign_cleared"),
			"the earned milestone survived")
	if err == "":
		err = _T.assert_eq(RunConfig.difficulty_high_scores.get(
				RunConfig.score_key(false, &"harsh"), 0), 99,
			"and the v9 difficulty-score line survived alongside it")
	if err == "":
		# Rewritten forward: the file on disk is now a v10 file with an explicit "s0".
		var rewritten: String = FileAccess.get_file_as_string(path)
		err = _T.assert_true(rewritten.begins_with("v%d\n" % RunConfig.SAVE_VERSION),
			"the migrated file is stamped at the current version: %s" % rewritten)
		if err == "":
			err = _T.assert_true(rewritten.contains("\ns0\n"),
				"and carries the empty skins line explicitly, not by omission: %s" % rewritten)

	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	RunConfig.save_path = stashed_path
	RunConfig.selected_skins = stashed_selections
	RunConfig.earned_milestones = stashed_milestones
	RunConfig.campaign_high_score = stashed_campaign
	RunConfig.endless_high_score = stashed_endless
	RunConfig.load_status = stashed_status
	return err


# -- The tint actually applying on the board ----------------------------------


func test_a_placed_plant_wears_its_chosen_skins_tint() -> String:
	var stashed_selections: Dictionary = RunConfig.selected_skins.duplicate()
	var stashed_milestones: Dictionary = RunConfig.earned_milestones.duplicate()
	# set_skin() below succeeds and saves -- redirected to scratch, as above.
	var stashed_path: String = RunConfig.save_path
	RunConfig.save_path = "user://test_skins_plant_tint.save"
	RunConfig.earned_milestones = {"campaign_cleared": true}
	var kind: StringName = PlantCatalog.ids()[0]
	RunConfig.selected_skins = {}
	var err: String = _T.assert_true(RunConfig.set_skin(Skins.KIND_PLANT, kind, &"golden"),
		"golden is chosen for the plant this test places")
	var plant: Plant = null
	if err == "":
		# Plant.new() -- the base class, not a specific subclass -- is exactly what
		# test_a_plant_standing_still_is_exactly_where_it_always_was builds too: the
		# subclasses differ only in _act()'s combat behaviour, which this test does
		# not touch. `null` for the board, the same as that test passes, since
		# setup() only reaches into it for cell_to_world() when it is not null.
		plant = Plant.new()
		plant.setup(kind, Vector2i(1, 1), null)
		err = _T.assert_eq(plant.skin_id, &"golden", "the plant records the skin it was placed with")
	if err == "":
		err = _T.assert_true(plant._sprite != null, "the sprite exists to be tinted")
		if err == "":
			err = _T.assert_eq(plant._sprite.modulate, Skins.tint_for(&"golden"),
				"and wears exactly the tint Skins.tint_for(golden) declares")
	if plant != null:
		plant.free()
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(RunConfig.save_path + suffix):
			DirAccess.remove_absolute(RunConfig.save_path + suffix)
	RunConfig.save_path = stashed_path
	RunConfig.selected_skins = stashed_selections
	RunConfig.earned_milestones = stashed_milestones
	return err


func test_a_spawned_pest_wears_its_chosen_skins_tint_until_a_mutation_lands() -> String:
	var stashed_selections: Dictionary = RunConfig.selected_skins.duplicate()
	var stashed_milestones: Dictionary = RunConfig.earned_milestones.duplicate()
	# set_skin() below succeeds and saves -- redirected to scratch, as above.
	var stashed_path: String = RunConfig.save_path
	RunConfig.save_path = "user://test_skins_pest_tint.save"
	RunConfig.earned_milestones = {"threat_peak": true}
	var species: StringName = Pest.APHID
	RunConfig.selected_skins = {}
	var err: String = _T.assert_true(RunConfig.set_skin(Skins.KIND_PEST, species, &"ember"),
		"ember is chosen for the species this test spawns")
	var pest: Pest = null
	if err == "":
		pest = Pest.new()
		pest.setup(species, PackedVector2Array([Vector2(0, 0), Vector2(64, 0)]))
		err = _T.assert_eq(pest.skin_id, &"ember", "the pest records the skin it spawned with")
	if err == "":
		err = _T.assert_true(pest._sprite != null, "the sprite exists to be tinted")
	if err == "":
		err = _T.assert_eq(pest._sprite.modulate, Skins.tint_for(&"ember"),
			"and wears exactly the tint Skins.tint_for(ember) declares")
	if pest != null:
		# A mutation still wins outright once it lands -- the same priority
		# apply_mutation() gives two mutations composing onto one tint.
		err = _T.assert_true(pest.apply_mutation(Pest.MUTATION_ARMOURED),
			"the mutation applies cleanly onto a skinned, unmutated pest")
	if err == "":
		err = _T.assert_eq(pest.skin_id, &"ember", "the skin is still recorded")
		if err == "":
			err = _T.assert_eq(pest._sprite.modulate, Pest.tint_for(Pest.MUTATION_ARMOURED),
				"but the sprite now wears the mutation's colour, not the skin's -- "
					+ "MUTATION_TINT carries gameplay information and a skin carries none")
	if pest != null:
		pest.free()
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(RunConfig.save_path + suffix):
			DirAccess.remove_absolute(RunConfig.save_path + suffix)
	RunConfig.save_path = stashed_path
	RunConfig.selected_skins = stashed_selections
	RunConfig.earned_milestones = stashed_milestones
	return err


## set_pest_skin() called directly, off setup() -- the writer setup() itself uses,
## named on its own rather than only exercised as a side effect of it.
func test_set_pest_skin_applies_and_reapplies_the_tint_directly() -> String:
	var pest := Pest.new()
	pest.setup(Pest.APHID, PackedVector2Array([Vector2(0, 0), Vector2(64, 0)]))
	pest.set_pest_skin(&"golden")
	var err: String = _T.assert_eq(pest.skin_id, &"golden", "the id is recorded")
	if err == "":
		err = _T.assert_eq(pest._sprite.modulate, Skins.tint_for(&"golden"), "and the tint applied")
	if err == "":
		# Called again with a different id: the sprite follows, not just the field.
		pest.set_pest_skin(&"frost")
		err = _T.assert_eq(pest._sprite.modulate, Skins.tint_for(&"frost"),
			"a second call moves the sprite too, not only skin_id")
	pest.free()
	return err


# -- SkinsScreen: the one Control-shaped piece --------------------------------


func test_the_skins_screen_declares_a_distinct_node_name() -> String:
	var err: String = _T.assert_eq(SkinsScreen.NODE_NAME, "SkinsScreen",
		"the contract every OverlayScreen subclass carries -- see "
			+ "test_every_overlay_screen_declares_a_node_name_and_they_are_distinct")
	if err == "":
		var built := SkinsScreen.build()
		err = _T.assert_eq(String(built.name), SkinsScreen.NODE_NAME, "build() names it")
		if err == "":
			err = _T.assert_eq(built.process_mode, Node.PROCESS_MODE_ALWAYS,
				"and states PROCESS_MODE_ALWAYS outright -- the pause layer it opens "
					+ "over must not freeze it")
		built.free()
	return err


## page_capacity() named directly -- what the screen's own row-building loop calls
## internally, asserted on its own rather than only exercised through it.
func test_page_capacity_is_positive_and_matches_the_built_rows() -> String:
	var capacity: int = SkinsScreen.page_capacity()
	var err: String = _T.assert_gt(capacity, 0,
		"the panel holds at least one row, or nothing built on this screen at all")
	if err == "":
		var screen := await _T.instantiate_ui(SkinsScreen.build(), Vector2i(1152, 648)) as SkinsScreen
		err = _T.assert_true(screen.show_page_for(Skins.KIND_PLANT, PlantCatalog.ids()[0]),
			"the first page can be reached")
		if err == "":
			err = _T.assert_true(screen.visible_targets().size() <= capacity,
				"a page never shows more targets than page_capacity() declared")
		_T.free_ui(screen)
	return err


## Pages through every target, without ever showing a target twice or skipping
## one -- the paging arithmetic `_show_page` is built around, exercised end to end
## rather than trusted from reading the source.
func test_the_skins_screen_pages_through_every_target_exactly_once() -> String:
	var screen := await _T.instantiate_ui(SkinsScreen.build(), Vector2i(1152, 648)) as SkinsScreen
	var err: String = _T.assert_gt(screen.total_pages(), 1,
		"fourteen-plus targets at a handful of rows a page is more than one page, "
			+ "or this test is not exercising the pager at all")
	var seen: Dictionary = {}
	if err == "":
		var page: int = 0
		while page < screen.total_pages() and err == "":
			for target: Dictionary in screen.visible_targets():
				var key: String = Skins.selection_key(target["kind"], target["id"])
				err = _T.assert_false(seen.has(key), "%s was not already shown on an earlier page" % key)
				if err != "":
					break
				seen[key] = true
			page += 1
			if page < screen.total_pages():
				screen._show_page(page)
	if err == "":
		err = _T.assert_eq(seen.size(), Skins.targets().size(),
			"every target was shown on exactly one page")
	_T.free_ui(screen)
	return err


## Pressing a row's button advances to the next UNLOCKED skin and RunConfig agrees
## -- the screen has no state of its own to disagree with the thing it writes to.
func test_pressing_a_row_button_advances_the_selection_and_persists_it() -> String:
	var stashed_selections: Dictionary = RunConfig.selected_skins.duplicate()
	var stashed_milestones: Dictionary = RunConfig.earned_milestones.duplicate()
	# Pressing the row button reaches RunConfig.set_skin(), which saves -- redirected
	# to scratch, the same discipline every other test here that can reach _save()
	# follows.
	var stashed_path: String = RunConfig.save_path
	RunConfig.save_path = "user://test_skins_screen_press.save"
	RunConfig.selected_skins = {}
	RunConfig.earned_milestones = {"campaign_cleared": true, "unbroken_garden": true, "threat_peak": true}

	var screen := await _T.instantiate_ui(SkinsScreen.build(), Vector2i(1152, 648)) as SkinsScreen
	var plant: StringName = PlantCatalog.ids()[0]
	var err: String = _T.assert_true(screen.show_page_for(Skins.KIND_PLANT, plant),
		"the screen can turn to the page holding the first plant")
	if err == "":
		err = _T.assert_true(screen.press_skin_button(Skins.KIND_PLANT, plant),
			"and its row button can be pressed")
	if err == "":
		var chosen: StringName = RunConfig.selected_skin(Skins.KIND_PLANT, plant)
		err = _T.assert_true(chosen != Skins.DEFAULT_SKIN,
			"one press moved off the default -- every milestone is earned in this fixture")
	_T.free_ui(screen)
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(RunConfig.save_path + suffix):
			DirAccess.remove_absolute(RunConfig.save_path + suffix)
	RunConfig.save_path = stashed_path
	RunConfig.selected_skins = stashed_selections
	RunConfig.earned_milestones = stashed_milestones
	return err


## The signal itself, named and connected directly -- Hud's own contract, checked
## before asking what Game does with it (the next test's subject).
func test_the_hud_button_emits_skins_requested() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	await _pump(game)
	var button: Button = game.hud.get_node_or_null("Root/TopBar/StatsRow/SkinsButton") as Button
	var err: String = _T.assert_true(button != null, "the button exists")
	var fired: Array[bool] = [false]
	if err == "":
		# A second listener beside Game's own -- signals fan out to every connection,
		# so this does not disturb Game._open_skins from also firing TOO: the press
		# goes through the real button, so it also pauses the real run underneath
		# this test, same as it would for a player. Cleaned up below, or the paused
		# tree survives this test and greets whichever test runs next
		# (godot-test-isolation's whole subject -- `SceneTree.paused` is exactly the
		# kind of process-global flag its own header warns about).
		game.hud.skins_requested.connect(func() -> void: fired[0] = true)
		button.pressed.emit()
		err = _T.assert_true(fired[0], "pressing it emits skins_requested")
	if game.is_paused():
		await game.resume_run()
	_T.free_ui(game)
	return err


# -- Reachability: the HUD door and the run it opens over ---------------------


## The seam SkinsScreen's own header and the exemption in
## test_every_overlay_makes_everything_under_it_unfocusable both argue for: opened
## as a SIBLING of the pause card rather than its child, does the pause card's own
## buttons still go inert correctly? `OverlayScreen._ready()` claims this is
## derived from the parent rather than from a fixed list -- this is what proves it
## rather than trusting the claim.
func test_the_hud_button_opens_skins_over_a_paused_run_and_the_pause_card_goes_inert() -> String:
	var game := await _T.instantiate_scene(GAME_SCENE) as Game
	await _pump(game)
	var button: Button = game.hud.get_node_or_null("Root/TopBar/StatsRow/SkinsButton") as Button
	var err: String = _T.assert_true(button != null, "the HUD carries a SkinsButton")
	if err == "":
		err = _T.assert_false(game.is_paused(), "the run is not paused before the press")
	if err == "":
		button.pressed.emit()
		await _pump(game)
		err = _T.assert_true(game.is_paused(), "pressing Skins pauses the run")
	var card: PauseScreen = null
	if err == "":
		card = game.get_node_or_null("PauseLayer/PauseScreen") as PauseScreen
		err = _T.assert_true(card != null, "and the pause card came up under it")
	if err == "":
		var resume: Button = card.get_node_or_null("ResumeButton") as Button
		err = _T.assert_true(resume != null, "the card built its own Resume button")
		if err == "":
			err = _T.assert_eq(resume.focus_mode, Control.FOCUS_NONE,
				"and it is inert while the Skins screen sits over it -- "
					+ "SkinsScreen._ready() reached it as a sibling, not a child")
	var skins: SkinsScreen = null
	if err == "":
		skins = game.get_node_or_null("PauseLayer/SkinsScreen") as SkinsScreen
		err = _T.assert_true(skins != null, "the Skins screen itself is up")
	if err == "":
		skins._input(_key_press(KEY_ESCAPE))
		await _pump(game)
		err = _T.assert_false(game.is_paused(), "Escape closes it and resumes the run -- "
			+ "there is no pause card to fall back to, since Skins never opened through one")
	_T.free_ui(game)
	return err


func _key_press(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _pump(node: Node) -> void:
	await node.get_tree().process_frame
	await node.get_tree().process_frame
