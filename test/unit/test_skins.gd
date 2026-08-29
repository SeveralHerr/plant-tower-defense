extends RefCounted

## Purchasable skins for every plant and every pest (plant-tower-defense-ncfv, and the
## Petal shop that replaced its milestone gate, plant-tower-defense-u82u).
##
## Split three ways, matching the mechanism's own split: `Skins` is pure data and
## rule (asserted with no RunConfig, no Game, no save file), `RunConfig`'s
## `buy_skin()` / `owns_skin()` / `selected_skin()` / `set_skin()` and the v10 `s` and
## v11 `p`/`u` save lines are the persistence half, and `SkinsScreen` is the one
## Control-shaped piece, driven through `_T.instantiate_ui`.
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
	# The mirror seam is a STATIC on a class the whole process shares, so a test that
	# aborted mid-method would otherwise leave every later `_save()` in the run writing
	# into a stale Dictionary and every later `_load()` over a missing file reading one
	# back. Cleared here, unconditionally, rather than at the end of the one test that
	# sets it -- the runner calls this even after a runtime error, and that is the only
	# place that is true of.
	SaveMirror.force_store = null


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


func test_the_default_skin_is_always_owned_free_and_white() -> String:
	var err: String = _T.assert_true(
		Skins.is_owned(Skins.KIND_PLANT, PlantCatalog.ids()[0], Skins.DEFAULT_SKIN, {}),
		"the default skin is owned with an empty wardrobe")
	if err == "":
		err = _T.assert_eq(Skins.tint_for(Skins.DEFAULT_SKIN), Color(1.0, 1.0, 1.0),
			"and paints no visible change")
	if err == "":
		err = _T.assert_eq(Skins.cost_for(Skins.KIND_PLANT, Skins.DEFAULT_SKIN), 0,
			"and costs nothing -- it is the sprite's own art, there is nothing to buy")
	if err == "":
		err = _T.assert_false(Skins.has_art(Skins.DEFAULT_SKIN),
			"and has no generated drawing of its own")
	return err


## Every row the shop draws a button for is priced, titled and drawable. Walked off
## `buyable_families()` rather than named, so a fourth family joins this check the day
## it joins the table (`.claude/skills/derive-the-list`).
func test_every_buyable_family_is_priced_titled_and_drawn() -> String:
	var buyable: Array[Dictionary] = Skins.buyable_families()
	var err: String = _T.assert_eq(buyable.size(), Skins.FAMILIES.size() - 1,
		"buyable_families() is FAMILIES minus the default row and nothing else")
	for row: Dictionary in buyable:
		if err != "":
			break
		var id := StringName(row["id"])
		err = _T.assert_true(id != Skins.DEFAULT_SKIN, "%s is not the default row" % id)
		if err == "":
			err = _T.assert_true(Skins.has_art(id),
				("%s has a drawing of its own -- a family with none would be a plant "
					+ "skin priced as a drawing and rendered as a tint") % id)
		if err == "":
			err = _T.assert_true(Skins.title_of(id) != String(id),
				"%s has a shop label, not its bare id" % id)
		if err == "":
			err = _T.assert_eq(Skins.cost_for(Skins.KIND_PLANT, id), Skins.PLANT_SKIN_COST,
				"%s costs a plant skin's price on a plant" % id)
		if err == "":
			err = _T.assert_eq(Skins.cost_for(Skins.KIND_PEST, id), Skins.PEST_SKIN_COST,
				"%s costs a pest skin's price on a pest" % id)
	if err == "":
		err = _T.assert_gt(Skins.PLANT_SKIN_COST, Skins.PEST_SKIN_COST,
			"a generated drawing costs more than a tint, or the two prices are "
				+ "saying the same thing about two different purchases")
	return err


## `texture_path` is a PURE PATH TRANSFORM, and the four cases that must hand the base
## path back are exactly the four ways a caller can ask for a drawing that does not
## exist. Enumerated over the real family table rather than one example each.
func test_texture_path_derives_a_drawing_only_where_there_is_one() -> String:
	var base := "res://assets/sprites/sunflower.png"
	var err: String = _T.assert_eq(Skins.texture_path(base, Skins.DEFAULT_SKIN), base,
		"the default skin is the sprite's own art")
	if err == "":
		err = _T.assert_eq(Skins.texture_path(base, &"not_a_real_skin"), base,
			"and so is a family this build does not know")
	if err == "":
		err = _T.assert_eq(Skins.texture_path("", &"golden"), "",
			"and the empty path stays empty rather than becoming _skin_golden.")
	for row: Dictionary in Skins.buyable_families():
		if err != "":
			break
		var id := StringName(row["id"])
		var once: String = Skins.texture_path(base, id)
		err = _T.assert_eq(once, "res://assets/sprites/sunflower_skin_%s.png" % id,
			"%s derives its own drawing beside the parent" % id)
		if err == "":
			# Idempotent: the funnel is reached once per frame per plant, and a second
			# pass must not produce sunflower_skin_golden_skin_golden.png.
			err = _T.assert_eq(Skins.texture_path(once, id), once,
				"%s applied twice is %s applied once" % [id, id])
		if err == "":
			# And a path already wearing ANOTHER family's suffix is left alone too --
			# the guard is "does this carry a skin suffix", not "does it carry MINE".
			var other: StringName = &"frost" if id != &"frost" else &"ember"
			err = _T.assert_eq(Skins.texture_path(once, other), once,
				"%s is not restacked under a second family" % once)
	if err == "":
		# A family with a tint and no drawing hands the path back -- the pest case. No
		# such row exists today, so it is built rather than looked up, which is the
		# honest way to assert a branch the table cannot currently reach.
		err = _T.assert_false(Skins.has_art(&"a_tint_only_family"),
			"a family that is not in the table has no art, so texture_path returns "
				+ "the base path by the same branch a tint-only family would")
	return err


## THE OWNERSHIP MATRIX. The claim is a relation -- "a family bought on THIS target is
## owned on that target and on no other" -- so it is the PAIRS that are the evidence,
## not three worked examples (`.claude/skills/enumerate-the-pairs`). Both member lists
## come from the source (`Skins.targets()`, `Skins.buyable_families()`), so a plant, a
## pest or a family added to either table extends this table for free.
##
## The expectation is COMPUTED from the purchase, not tabulated: `owned == (this is the
## row it was bought on)`. A hand-written answer key would be a second implementation of
## the very rule under test.
func test_ownership_is_per_target_and_never_leaks_to_another_row() -> String:
	var targets: Array[Dictionary] = Skins.targets()
	var families: Array[Dictionary] = Skins.buyable_families()
	var err: String = _T.assert_gt(targets.size(), 1,
		"more than one target, or 'it did not leak to another row' checks nothing")
	if err == "":
		err = _T.assert_gt(families.size(), 1,
			"more than one buyable family, or the same is true of the other axis")
	# One purchase, then the whole cross product read back against it. Bought on the
	# FIRST target only, so every other row is a leak if it answers true.
	var bought_on: Dictionary = targets[0]
	for family_row: Dictionary in families:
		if err != "":
			break
		var family := StringName(family_row["id"])
		var wardrobe: Dictionary = {
			Skins.selection_key(bought_on["kind"], bought_on["id"]): [String(family)],
		}
		for target: Dictionary in targets:
			for other: Dictionary in families:
				var same_row: bool = (target["kind"] == bought_on["kind"]
					and target["id"] == bought_on["id"])
				var expected: bool = same_row and StringName(other["id"]) == family
				var got: bool = Skins.is_owned(target["kind"], target["id"],
					StringName(other["id"]), wardrobe)
				err = _T.assert_eq(got, expected,
					"buying %s on %s: %s on %s should read %s" % [family,
						Skins.selection_key(bought_on["kind"], bought_on["id"]),
						other["id"], Skins.selection_key(target["kind"], target["id"]),
						expected])
				if err != "":
					break
			# The default is owned on every row of that same table, always, whatever
			# was bought -- the half of the relation an "is it owned" loop over the
			# buyable families alone can never see.
			if err == "":
				err = _T.assert_true(Skins.is_owned(target["kind"], target["id"],
					Skins.DEFAULT_SKIN, wardrobe),
					"the default stays owned on %s" % Skins.selection_key(
						target["kind"], target["id"]))
			if err != "":
				break
	return err


func test_an_unknown_skin_id_is_never_owned_and_untinted() -> String:
	var plant: StringName = PlantCatalog.ids()[0]
	var wardrobe: Dictionary = {
		Skins.selection_key(Skins.KIND_PLANT, plant): ["not_a_real_skin"],
	}
	# Even with the id sitting in the wardrobe -- which is what a save from a newer
	# build looks like -- this build does not hand it out.
	var err: String = _T.assert_false(
		Skins.is_owned(Skins.KIND_PLANT, plant, &"not_a_real_skin", wardrobe),
		"an id this build does not know is never owned, however the save spells it")
	if err == "":
		err = _T.assert_eq(Skins.tint_for(&"not_a_real_skin"), Color(1.0, 1.0, 1.0),
			"and reads as untinted rather than erroring -- the same contract "
				+ "Pest.tint_for uses for an unknown mutation")
	return err


## owned_families() always answers at least [DEFAULT_SKIN], and grows by exactly one row
## per purchase -- exercised at both ends of the table rather than one hand-picked
## family, per enumerate-the-pairs.
func test_owned_families_grows_exactly_with_what_was_bought() -> String:
	var plant: StringName = PlantCatalog.ids()[0]
	var key: String = Skins.selection_key(Skins.KIND_PLANT, plant)
	var none: Array[Dictionary] = Skins.owned_families(Skins.KIND_PLANT, plant, {})
	var err: String = _T.assert_eq(none.size(), 1,
		"an empty wardrobe owns only the default")
	if err == "":
		var bought: Array[String] = []
		for row: Dictionary in Skins.buyable_families():
			bought.append(String(row["id"]))
			var owned: Array[Dictionary] = Skins.owned_families(Skins.KIND_PLANT, plant,
				{key: bought.duplicate()})
			err = _T.assert_eq(owned.size(), bought.size() + 1,
				"%d purchase(s) plus the default is %d rows" % [bought.size(), bought.size() + 1])
			if err != "":
				break
		if err == "":
			err = _T.assert_eq(
				Skins.owned_families(Skins.KIND_PLANT, plant, {key: bought}).size(),
				Skins.FAMILIES.size(),
				"and buying every family owns every family, none left out")
	return err


## next_owned() cycles through exactly the owned set and wraps, never landing on a
## family that was not bought and never getting stuck. Enumerated over the whole table
## rather than one hand-picked step (enumerate-the-pairs): every owned id's successor is
## itself owned, and walking FAMILIES.size() steps from any start returns to that start.
func test_next_owned_cycles_the_owned_set_and_wraps() -> String:
	var plant: StringName = PlantCatalog.ids()[0]
	var buyable: Array[Dictionary] = Skins.buyable_families()
	# The LAST buyable family is deliberately left unbought, so the cycle has a real gap
	# to skip over rather than visiting every family.
	var bought: Array[String] = []
	for i: int in buyable.size() - 1:
		bought.append(String(buyable[i]["id"]))
	var wardrobe: Dictionary = {Skins.selection_key(Skins.KIND_PLANT, plant): bought}
	var owned: Array[Dictionary] = Skins.owned_families(Skins.KIND_PLANT, plant, wardrobe)
	var err: String = _T.assert_true(owned.size() < Skins.FAMILIES.size(),
		"the fixture leaves at least one family unbought, or this test checks nothing")
	var visited: Dictionary = {}
	if err == "":
		var current: StringName = Skins.DEFAULT_SKIN
		for _i: int in Skins.FAMILIES.size():
			current = Skins.next_owned(Skins.KIND_PLANT, plant, current, wardrobe)
			err = _T.assert_true(Skins.is_owned(Skins.KIND_PLANT, plant, current, wardrobe),
				"next_owned never lands on a family nobody bought, got %s" % current)
			if err != "":
				break
			visited[current] = true
		if err == "":
			err = _T.assert_eq(visited.size(), owned.size(),
				"cycling visits exactly the owned set, wrapping rather than growing")
	if err == "":
		err = _T.assert_false(rows_contain_an_unowned_family(owned, plant, wardrobe),
			"sanity: nothing in owned_families() is actually unowned")
	return err


func rows_contain_an_unowned_family(rows: Array[Dictionary], plant: StringName,
		wardrobe: Dictionary) -> bool:
	for row: Dictionary in rows:
		if not Skins.is_owned(Skins.KIND_PLANT, plant, StringName(row["id"]), wardrobe):
			return true
	return false


# -- RunConfig: persistence and the door -------------------------------------
#
# Every test below that can reach `RunConfig._save()` stages its own scratch path.
# `setup()` at the top of this file already redirects the suite (which is what
# `tools/save_persist_check.py` requires), and these go further only where the test
# asserts on the BYTES and therefore needs a file of its own that no neighbour has
# written to.


## Everything of RunConfig's the shop tests move, taken and put back in one place.
##
## A helper rather than eight lines repeated per test, and it exists because the field
## list GREW: v11 added `petals` and `purchased_skins`, and a per-test stash is eight
## places to forget one of them. `purchased_skins` in particular is the field a leak
## would be invisible in -- a stray purchase does not fail the test that made it, it
## makes some later test's `buy_skin` return false for a reason nothing prints.
func _stash_shop_state() -> Dictionary:
	return {
		"save_path": RunConfig.save_path,
		"selected_skins": RunConfig.selected_skins.duplicate(true),
		"purchased_skins": RunConfig.purchased_skins.duplicate(true),
		"earned_milestones": RunConfig.earned_milestones.duplicate(),
		"petals": RunConfig.petals,
		"load_status": RunConfig.load_status,
	}


func _restore_shop_state(stashed: Dictionary) -> void:
	# The scratch files first, while `save_path` still points at them.
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(RunConfig.save_path + suffix):
			DirAccess.remove_absolute(RunConfig.save_path + suffix)
	RunConfig.save_path = str(stashed["save_path"])
	RunConfig.selected_skins = (stashed["selected_skins"] as Dictionary).duplicate(true)
	RunConfig.purchased_skins = (stashed["purchased_skins"] as Dictionary).duplicate(true)
	RunConfig.earned_milestones = (stashed["earned_milestones"] as Dictionary).duplicate()
	RunConfig.petals = int(stashed["petals"])
	RunConfig.load_status = str(stashed["load_status"])


## Points RunConfig at `path` with an empty wardrobe and `balance` petals.
func _stage_shop(path: String, balance: int) -> void:
	RunConfig.save_path = path
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	RunConfig.selected_skins = {}
	RunConfig.purchased_skins = {}
	RunConfig.petals = balance


## THE FOUR REFUSALS `buy_skin` documents, each one asserted to leave the balance and
## the wardrobe exactly as they were -- which is the half a "returns false" check
## misses, and the half that would show up as a player being charged for nothing.
func test_buy_skin_refuses_unknown_unaffordable_and_already_owned() -> String:
	var stashed: Dictionary = _stash_shop_state()
	_stage_shop("user://test_skins_buy_refusals.save", Skins.PLANT_SKIN_COST)
	var plant: StringName = PlantCatalog.ids()[0]

	var err: String = _T.assert_false(RunConfig.buy_skin(Skins.KIND_PLANT, &"not_a_plant", &"golden"),
		"an unknown target is refused")
	if err == "":
		err = _T.assert_false(RunConfig.buy_skin(Skins.KIND_PLANT, plant, &"not_a_real_skin"),
			"and so is a family this build does not know")
	if err == "":
		err = _T.assert_false(RunConfig.buy_skin(Skins.KIND_PLANT, plant, Skins.DEFAULT_SKIN),
			"and so is the default, which is not for sale because everyone has it")
	if err == "":
		err = _T.assert_eq(RunConfig.petals, Skins.PLANT_SKIN_COST,
			"three refusals later the balance has not moved")
	if err == "":
		err = _T.assert_eq(RunConfig.purchased_skins, {}, "and nothing was recorded")
	if err == "":
		err = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PLANT, plant, &"golden"),
			"the affordable purchase goes through")
	if err == "":
		err = _T.assert_eq(RunConfig.petals, 0, "and costs exactly its price")
	if err == "":
		err = _T.assert_false(RunConfig.buy_skin(Skins.KIND_PLANT, plant, &"golden"),
			"buying it again is refused rather than silently charged")
	if err == "":
		err = _T.assert_eq(RunConfig.petals, 0, "so the balance is still zero, not negative")
	if err == "":
		# The unaffordable case, at exactly one petal short -- the boundary, not a
		# comfortable zero, because `cost > petals` and `cost >= petals` differ only
		# there.
		RunConfig.petals = Skins.PEST_SKIN_COST - 1
		var pest: StringName = StringName(Pest.SPECIES.keys()[0])
		err = _T.assert_false(RunConfig.buy_skin(Skins.KIND_PEST, pest, &"frost"),
			"one petal short is refused")
		if err == "":
			err = _T.assert_eq(RunConfig.petals, Skins.PEST_SKIN_COST - 1,
				"and the petal it did have is still there")
		if err == "":
			RunConfig.petals = Skins.PEST_SKIN_COST
			err = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PEST, pest, &"frost"),
				"exactly the price is enough")
	_restore_shop_state(stashed)
	return err


## A purchase dresses ONE row. The unit-level version of this is the ownership matrix
## above; this is the same claim through the real writer, because `buy_skin` is where a
## key could be built wrong and hand golden to every plant at once.
func test_buying_a_skin_for_one_target_does_not_give_it_to_another() -> String:
	var stashed: Dictionary = _stash_shop_state()
	_stage_shop("user://test_skins_per_target.save", Skins.PLANT_SKIN_COST * 2)
	var ids: Array[StringName] = PlantCatalog.ids()
	var err: String = _T.assert_gt(ids.size(), 1,
		"more than one plant, or this test cannot tell a leak from a hit")
	if err == "":
		err = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PLANT, ids[0], &"golden"),
			"golden is bought for the first plant")
	if err == "":
		err = _T.assert_true(RunConfig.owns_skin(Skins.KIND_PLANT, ids[0], &"golden"),
			"the row it was bought on owns it")
	if err == "":
		err = _T.assert_false(RunConfig.owns_skin(Skins.KIND_PLANT, ids[1], &"golden"),
			"the next plant does not")
	if err == "":
		var pest: StringName = StringName(Pest.SPECIES.keys()[0])
		err = _T.assert_false(RunConfig.owns_skin(Skins.KIND_PEST, pest, &"golden"),
			"and neither does a pest -- the key carries the kind as well as the id")
	if err == "":
		err = _T.assert_false(RunConfig.owns_skin(Skins.KIND_PLANT, ids[0], &"frost"),
			"and the purchase bought one family, not the row's whole wardrobe")
	_restore_shop_state(stashed)
	return err


## Petals cannot go negative, which is not a nicety: `_is_score` refuses a negative on
## the `p` line, so a balance that went below zero would fail `_save()`'s own readback
## and every save for the rest of the session would silently return false.
func test_petals_never_go_negative() -> String:
	var stashed: Dictionary = _stash_shop_state()
	_stage_shop("user://test_skins_petal_floor.save", 0)
	var err: String = _T.assert_eq(RunConfig.add_petals(-5), 0,
		"a negative grant is a no-op, not a subtraction")
	if err == "":
		err = _T.assert_eq(RunConfig.add_petals(0), 0, "and zero changes nothing either")
	if err == "":
		err = _T.assert_false(FileAccess.file_exists(RunConfig.save_path),
			"neither wrote the file -- the save is not a place to record that "
				+ "nothing happened")
	if err == "":
		err = _T.assert_eq(RunConfig.add_petals(3), 3, "a real grant lands")
	if err == "":
		# Spend every petal there is, then try to spend past the floor.
		var plant: StringName = PlantCatalog.ids()[0]
		err = _T.assert_false(RunConfig.buy_skin(Skins.KIND_PLANT, plant, &"golden"),
			"a purchase dearer than the balance is refused rather than overdrawn")
		if err == "":
			err = _T.assert_eq(RunConfig.petals, 3, "and the balance is untouched")
	if err == "":
		err = _T.assert_true(RunConfig._save(),
			"the balance still reads back through the loader's own validator")
	_restore_shop_state(stashed)
	return err


func test_set_skin_refuses_an_unknown_target() -> String:
	var stashed: Dictionary = RunConfig.selected_skins.duplicate()
	RunConfig.selected_skins = {}
	var ok: bool = RunConfig.set_skin(Skins.KIND_PLANT, &"not_a_plant", Skins.DEFAULT_SKIN)
	var err: String = _T.assert_false(ok, "an unknown plant id is refused")
	if err == "":
		err = _T.assert_eq(RunConfig.selected_skins.size(), 0, "and nothing was recorded")
	RunConfig.selected_skins = stashed
	return err


func test_set_skin_refuses_a_skin_that_was_never_bought() -> String:
	var stashed_selections: Dictionary = RunConfig.selected_skins.duplicate()
	var stashed_purchases: Dictionary = RunConfig.purchased_skins.duplicate(true)
	RunConfig.selected_skins = {}
	RunConfig.purchased_skins = {}
	var plant: StringName = PlantCatalog.ids()[0]
	var ok: bool = RunConfig.set_skin(Skins.KIND_PLANT, plant, &"golden")
	var err: String = _T.assert_false(ok, "golden is refused with an empty wardrobe")
	if err == "":
		err = _T.assert_eq(RunConfig.selected_skin(Skins.KIND_PLANT, plant), Skins.DEFAULT_SKIN,
			"and the plant reads back as the default, not a half-set choice")
	RunConfig.selected_skins = stashed_selections
	RunConfig.purchased_skins = stashed_purchases
	return err


## The round trip a purchase actually earns: buy, choose, and read the choice back --
## for a plant and a pest, since the mechanism is meant to cover both, and asserted on
## the BYTES as well as on the fields, because the wardrobe and the selection are two
## different lines and either could be the one that did not reach disk.
func test_set_skin_persists_once_the_skin_is_bought() -> String:
	var stashed: Dictionary = _stash_shop_state()
	_stage_shop("user://test_skins_persist.save",
		Skins.PLANT_SKIN_COST + Skins.PEST_SKIN_COST)
	var plant: StringName = PlantCatalog.ids()[0]
	var pest: StringName = StringName(Pest.SPECIES.keys()[0])
	var err: String = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PLANT, plant, &"golden"),
		"golden is bought for the plant")
	if err == "":
		err = _T.assert_true(RunConfig.set_skin(Skins.KIND_PLANT, plant, &"golden"),
			"and can then be chosen")
	if err == "":
		err = _T.assert_eq(RunConfig.selected_skin(Skins.KIND_PLANT, plant), &"golden",
			"and reads back as chosen")
	if err == "":
		# The pest side of the same two doors, at the pest price -- so this also proves
		# the two prices are read off the kind rather than being one number.
		err = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PEST, pest, &"ember"),
			"ember is bought for the pest with exactly the pest price left")
	if err == "":
		err = _T.assert_eq(RunConfig.petals, 0, "and the balance is spent to the penny")
	if err == "":
		err = _T.assert_true(RunConfig.set_skin(Skins.KIND_PEST, pest, &"ember"),
			"the pest can wear what was bought for it")
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
		if err == "":
			err = _T.assert_true(bytes.contains("\nu2 "),
				"and the wardrobe is its own line with both purchases on it: %s" % bytes)
		if err == "":
			err = _T.assert_true(bytes.contains("\np0\n"),
				"with the spent balance beside it: %s" % bytes)
	if err == "":
		# All the way back off disk, not just out of memory.
		RunConfig.selected_skins = {}
		RunConfig.purchased_skins = {}
		RunConfig.petals = 99
		RunConfig._load()
		err = _T.assert_eq(RunConfig.load_status, "loaded", "the file this build wrote is one it reads")
		if err == "":
			err = _T.assert_eq(RunConfig.petals, 0, "the balance came back")
		if err == "":
			err = _T.assert_true(RunConfig.owns_skin(Skins.KIND_PLANT, plant, &"golden"),
				"and so did the plant's purchase")
		if err == "":
			err = _T.assert_eq(RunConfig.selected_skin(Skins.KIND_PEST, pest), &"ember",
				"and the pest is still wearing what it was wearing")
	_restore_shop_state(stashed)
	return err


## A skin the player chose reads back as the default the moment it is not owned, and
## `selected_skin()` has to notice rather than hand back a drawing nothing in the Shop
## explains. Two situations wear this one branch, which is why it has its own test:
## a wardrobe lost to a refused/quarantined save, and -- the one that will actually
## happen -- a v10 save whose `s` line names a choice made under the old milestone gate,
## on a build where nothing has been bought yet. THAT IS THE v10 -> v11 MIGRATION, and
## it is deliberate: the selection is kept, not discarded, so buying the family later
## returns the choice with no re-picking.
func test_selected_skin_falls_back_to_default_when_the_skin_is_not_owned() -> String:
	var stashed: Dictionary = _stash_shop_state()
	_stage_shop("user://test_skins_fallback.save", Skins.PLANT_SKIN_COST)
	var plant: StringName = PlantCatalog.ids()[0]
	var err: String = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PLANT, plant, &"golden"),
		"golden is bought and chosen while it is owned")
	if err == "":
		err = _T.assert_true(RunConfig.set_skin(Skins.KIND_PLANT, plant, &"golden"), "chosen")
	if err == "":
		# The wardrobe goes, the selection stays -- exactly the shape a v10 save has.
		RunConfig.purchased_skins = {}
		err = _T.assert_eq(RunConfig.selected_skin(Skins.KIND_PLANT, plant), Skins.DEFAULT_SKIN,
			"and reads back as the default once it is not owned, not as golden")
	if err == "":
		err = _T.assert_eq(String(RunConfig.selected_skins.get(
				Skins.selection_key(Skins.KIND_PLANT, plant), "")), "golden",
			"while the CHOICE is still recorded -- the migration keeps it rather than "
				+ "throwing away a preference the player still holds")
	if err == "":
		# And it comes back the moment the family is bought for that row again.
		RunConfig.petals = Skins.PLANT_SKIN_COST
		err = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PLANT, plant, &"golden"),
			"buying it again is a purchase, not a refusal, since it is no longer owned")
		if err == "":
			err = _T.assert_eq(RunConfig.selected_skin(Skins.KIND_PLANT, plant), &"golden",
				"and the old choice is worn again with nothing re-picked")
	_restore_shop_state(stashed)
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


## The `p` line is a prefix and a non-negative integer. Every other shape is a refusal,
## because `_parse_save` cannot half-read a file: a balance it guesses at is a balance
## the player either loses or is handed for free.
func test_parse_petal_line_refuses_malformed_lines() -> String:
	var cases: Array[String] = [
		"",           # a file truncated one line up -- the case int("") makes dangerous
		"s0",         # a skins line, not a petal line -- wrong prefix
		"p",          # the prefix with no number
		"px",         # not a number at all
		"p-1",        # negative: `_is_score` refuses it, and so must this
		"p 3",        # a space where the digits belong
		"p3.5",       # not an integer
		"3",          # a bare digit, which is what the binding COUNT line looks like
	]
	var err: String = ""
	for text: String in cases:
		var parsed: Variant = RunConfig.parse_petal_line(text)
		err = _T.assert_true(parsed == null, "%s is refused, got %s" % [text, parsed])
		if err != "":
			return err
	# And the two shapes that ARE legal, so this is not a function that refuses
	# everything and passes by doing so.
	err = _T.assert_eq(RunConfig.parse_petal_line("p0"), 0, "p0 is the honest empty purse")
	if err == "":
		err = _T.assert_eq(RunConfig.parse_petal_line("p42"), 42, "and p42 is forty-two")
	if err == "":
		# The writer and its reader as a pair, which is the point of asserting either:
		# the failure this shape exists to prevent is a writer producing a line its own
		# reader refuses, after which every save in the session dies silently.
		for balance: int in [0, 1, 7, 4242]:
			var line: String = RunConfig.compose_petal_line(balance)
			err = _T.assert_eq(RunConfig.parse_petal_line(line), balance,
				"compose_petal_line(%d) is %s and reads back as %d" % [balance, line, balance])
			if err != "":
				break
	return err


func test_compose_and_parse_purchase_line_round_trip() -> String:
	var plant_key: String = Skins.selection_key(Skins.KIND_PLANT, PlantCatalog.ids()[0])
	var pest_key: String = Skins.selection_key(Skins.KIND_PEST,
		StringName(Pest.SPECIES.keys()[0]))
	# Deliberately unsorted going in, on both axes: the keys and the family list within
	# a key are both sorted by the writer, which is what makes two saves holding the same
	# wardrobe byte-identical whatever order the player bought things in.
	var purchases: Dictionary = {
		pest_key: ["golden", "ember"],
		plant_key: ["frost", "golden"],
	}
	var line: String = RunConfig.compose_purchase_line(purchases)
	# The expected string is ASSEMBLED from the same sort the writer promises rather
	# than typed out: "pest:aphid" sorts before "plant:sunflower", which is a fact about
	# these two ids and not about the rule, and a literal here would be a test that
	# passes on the catalogue as it stands today.
	var wardrobes: Dictionary = {
		plant_key: "frost,golden",
		pest_key: "ember,golden",
	}
	var sorted_keys: Array = wardrobes.keys()
	sorted_keys.sort()
	var expected: PackedStringArray = ["u2"]
	for key: Variant in sorted_keys:
		expected.append("%s=%s" % [key, wardrobes[key]])
	var err: String = _T.assert_eq(line, " ".join(expected),
		"two keys, count-prefixed, keys sorted and each family list sorted: %s" % line)
	if err == "":
		var parsed: Variant = RunConfig.parse_purchase_line(line)
		err = _T.assert_true(parsed != null, "the line this writer produced reads back")
		if err == "":
			var back := parsed as Dictionary
			err = _T.assert_eq(back.keys().size(), 2, "both keys survived")
			if err == "":
				var plant_expected: Array[String] = ["frost", "golden"]
				err = _T.assert_eq(back[plant_key], plant_expected,
					"the plant's wardrobe came back sorted")
			if err == "":
				var pest_expected: Array[String] = ["ember", "golden"]
				err = _T.assert_eq(back[pest_key], pest_expected,
					"and so did the pest's")
	return err


func test_compose_purchase_line_drops_the_default_and_the_empty() -> String:
	var key: String = Skins.selection_key(Skins.KIND_PLANT, PlantCatalog.ids()[0])
	var err: String = _T.assert_eq(RunConfig.compose_purchase_line({}), "u0",
		"an empty wardrobe is the honest empty set, not an absent line")
	if err == "":
		err = _T.assert_eq(RunConfig.compose_purchase_line({key: [String(Skins.DEFAULT_SKIN)]}),
			"u0", "the default is owned by everyone always, so recording it is noise")
	if err == "":
		err = _T.assert_eq(RunConfig.compose_purchase_line({key: []}), "u0",
			"and a key whose list is empty is dropped rather than written as key=")
	if err == "":
		err = _T.assert_eq(RunConfig.compose_purchase_line({key: ["golden", "golden"]}),
			"u1 %s=golden" % key, "a duplicate within a key is written once")
	return err


func test_parse_purchase_line_refuses_malformed_lines() -> String:
	var cases: Array[String] = [
		"s0",                        # a skins line, not a wardrobe line -- wrong prefix
		"u1",                        # count says one, no fields follow
		"u0 plant:sunflower=golden",  # count says zero, one field follows
		"uplant:sunflower=golden",    # no space, the count is unparsable
		"u1 plant:sunflower",         # no "=" at all
		"u1 plantsunflower=golden",   # no ":" between kind and id
		"u1 :sunflower=golden",       # empty kind before the ":"
		"u1 plant:=golden",           # empty id after the ":"
		"u1 plant:sunflower=",        # empty value
		"u1 plant:sunflower=golden,",  # a trailing comma is an empty family
		"u1 plant:sunflower=golden,,frost",  # and so is a doubled one
		"u1 plant:sunflower=GOLDEN",  # uppercase is not in MILESTONE_ID_CHARS
		"u1 PLANT:sunflower=golden",  # nor in the key half
		"u1 plant:sunflower=golden,golden",  # the same family twice on one key
		"u2 plant:sunflower=golden plant:sunflower=frost",  # the same key twice
	]
	var err: String = ""
	for text: String in cases:
		var parsed: Variant = RunConfig.parse_purchase_line(text)
		err = _T.assert_true(parsed == null, "%s is refused, got %s" % [text, parsed])
		if err != "":
			return err
	# And the empty set, which is a legitimate reading and must NOT be a refusal --
	# `null` and `{}` are exactly the distinction this parser exists to keep.
	var empty: Variant = RunConfig.parse_purchase_line("u0")
	err = _T.assert_true(empty != null, "u0 parses rather than being refused")
	if err == "":
		err = _T.assert_eq(empty, {}, "and reads as the empty wardrobe")
	return err


## Whatever `buy_skin` writes, `parse_purchase_line` must read -- the failure mode
## `record_milestones` documents at length is a writer its own reader rejects, after
## which every save in the session dies silently. Enumerated over the real target and
## family tables rather than one example, because the id that breaks this will be one
## somebody adds to a table years from now.
func test_every_target_and_family_survives_the_purchase_line() -> String:
	var purchases: Dictionary = {}
	var families: Array[String] = []
	for row: Dictionary in Skins.buyable_families():
		families.append(String(row["id"]))
	var targets: Array[Dictionary] = Skins.targets()
	var err: String = _T.assert_gt(targets.size(), 0, "there are targets to write down")
	if err == "":
		err = _T.assert_gt(families.size(), 0, "and families to write beside them")
	for target: Dictionary in targets:
		if err != "":
			break
		err = _T.assert_true(RunConfig.is_recordable_purchase(target["kind"], target["id"],
				StringName(families[0])),
			"%s is spelled in characters a save can carry" % Skins.selection_key(
				target["kind"], target["id"]))
		purchases[Skins.selection_key(target["kind"], target["id"])] = families.duplicate()
	if err == "":
		var line: String = RunConfig.compose_purchase_line(purchases)
		var parsed: Variant = RunConfig.parse_purchase_line(line)
		err = _T.assert_true(parsed != null,
			"the whole catalogue bought outright reads back: %s" % line)
		if err == "":
			err = _T.assert_eq((parsed as Dictionary).size(), targets.size(),
				"with every row still on it")
	return err


## THE ACCEPTANCE CRITERION: a v9 file loads forward with no skins unlocked, not a
## crash and not a reset of the fields v9 already had.
func test_a_v9_save_loads_forward_with_no_skins_selected() -> String:
	var path := "user://test_skins_v9_forward.save"
	var stashed_path: String = RunConfig.save_path
	var stashed_selections: Dictionary = RunConfig.selected_skins.duplicate()
	var stashed_milestones: Dictionary = RunConfig.earned_milestones.duplicate()
	var stashed_purchases: Dictionary = RunConfig.purchased_skins.duplicate(true)
	var stashed_petals: int = RunConfig.petals
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
			"no skins were chosen by a build that predates the Skins screen -- "
				+ "not a crash, not every skin selected, an empty set")
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
		# Rewritten forward: the file on disk is now a v11 file with an explicit "s0",
		# and the two shop lines under it.
		var rewritten: String = FileAccess.get_file_as_string(path)
		err = _T.assert_true(rewritten.begins_with("v%d\n" % RunConfig.SAVE_VERSION),
			"the migrated file is stamped at the current version: %s" % rewritten)
		if err == "":
			err = _T.assert_true(rewritten.contains("\ns0\n"),
				"and carries the empty skins line explicitly, not by omission: %s" % rewritten)
		if err == "":
			err = _T.assert_true(rewritten.contains("\ns0\np0\nu0\n"),
				("and the two v11 lines under it, in that order and above the binding "
					+ "count -- a field written after the count would be read as a "
					+ "binding: %s") % rewritten)

	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	RunConfig.save_path = stashed_path
	RunConfig.selected_skins = stashed_selections
	RunConfig.earned_milestones = stashed_milestones
	RunConfig.purchased_skins = stashed_purchases
	RunConfig.petals = stashed_petals
	RunConfig.campaign_high_score = stashed_campaign
	RunConfig.endless_high_score = stashed_endless
	RunConfig.load_status = stashed_status
	return err


## THE OTHER ACCEPTANCE CRITERION: a v10 file -- one written by the build that had the
## Skins screen and the milestone gate -- loads forward with ZERO petals and NO
## purchases, and its recorded SELECTIONS survive rather than being discarded.
##
## The selection surviving is the whole of the v10 -> v11 migration: it is kept on disk,
## reads back as DEFAULT_SKIN while nothing is owned, and returns the day the player buys
## that family for that row. See `RunConfig.selected_skin()`.
func test_a_v10_save_loads_forward_with_no_petals_and_no_purchases() -> String:
	var path := "user://test_skins_v10_forward.save"
	var stashed: Dictionary = _stash_shop_state()
	var stashed_campaign: int = RunConfig.campaign_high_score
	var stashed_endless: int = RunConfig.endless_high_score
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

	var plant: StringName = PlantCatalog.ids()[0]
	var key: String = Skins.selection_key(Skins.KIND_PLANT, plant)
	# A hand-typed v10 file: every field v10 ever wrote, INCLUDING a chosen skin, and
	# nothing past the binding count -- no "p"/"u" lines, because no build before v11
	# ever wrote one.
	var v10_bytes: String = ("v10\n1234\n5678\nm1:campaign_cleared\n"
		+ "cb0 sfx0 mus0 spd0 svol0 mvol0\nd0\ns1 %s=golden\n0\n") % key
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(v10_bytes)
	f.close()

	RunConfig.save_path = path
	RunConfig.petals = 99
	RunConfig.purchased_skins = {"plant:leftover": ["ember"]}
	RunConfig._load()
	var err: String = _T.assert_eq(RunConfig.load_status, "migrated",
		"a v10 file loads and is rewritten forward rather than refused, got %s"
			% RunConfig.load_status)
	if err == "":
		err = _T.assert_eq(RunConfig.petals, 0,
			"a build with no shop earned no petals -- not 99 inherited from this "
				+ "process, and not a crash")
	if err == "":
		err = _T.assert_eq(RunConfig.purchased_skins, {},
			"and bought nothing -- the load REPLACED the in-memory wardrobe rather "
				+ "than merging into it")
	if err == "":
		err = _T.assert_eq(String(RunConfig.selected_skins.get(key, "")), "golden",
			"while the v10 SELECTION survived the parse")
	if err == "":
		err = _T.assert_eq(RunConfig.selected_skin(Skins.KIND_PLANT, plant), Skins.DEFAULT_SKIN,
			"and is not worn, because nothing is owned yet -- that fallback IS the "
				+ "v10 -> v11 migration")
	if err == "":
		err = _T.assert_eq(RunConfig.campaign_high_score, 1234,
			"the rest of v10 survived it: the campaign score")
	if err == "":
		err = _T.assert_true(RunConfig.has_milestone("campaign_cleared"),
			"and the earned milestone")
	if err == "":
		var rewritten: String = FileAccess.get_file_as_string(path)
		err = _T.assert_eq(rewritten,
			("v%d\n1234\n5678\nm1:campaign_cleared\ncb0 sfx0 mus0 spd0 svol0 mvol0\n"
				+ "d0\ns1 %s=golden\np0\nu0\n0\n") % [RunConfig.SAVE_VERSION, key],
			"and the file on disk is now a v11 file, byte for byte: %s" % rewritten)
	if err == "":
		# It reads back as CURRENT, or the next launch refuses what the migration wrote.
		RunConfig._load()
		err = _T.assert_eq(RunConfig.load_status, "loaded",
			"the file the migration wrote reads back as current, not migrated again")

	RunConfig.campaign_high_score = stashed_campaign
	RunConfig.endless_high_score = stashed_endless
	_restore_shop_state(stashed)
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	return err


# -- SaveMirror: the web half, made reachable ---------------------------------


## The mirror round trip through `force_store`, which is the whole reason that seam
## exists: without it every line of `SaveMirror` sits behind `OS.has_feature("web")`, a
## branch no gate in this project can open, and "the wardrobe persists on the web" would
## be a claim about code no run has ever executed
## (`.claude/skills/extract-a-testable-seam`).
func test_the_save_mirror_round_trips_through_its_test_seam() -> String:
	var stashed_store: Variant = SaveMirror.force_store
	var err: String = _T.assert_false(SaveMirror.active(),
		"a desktop build with no override has nowhere to mirror to")
	if err == "":
		SaveMirror.force_store = {}
		err = _T.assert_true(SaveMirror.active(), "the seam turns the backend on")
	if err == "":
		err = _T.assert_eq(SaveMirror.read(), "", "an empty store reads as absent")
	if err == "":
		err = _T.assert_true(SaveMirror.write("v11\nhello\n"), "a write lands")
	if err == "":
		err = _T.assert_eq(SaveMirror.read(), "v11\nhello\n", "and reads back exactly")
	if err == "":
		err = _T.assert_true(SaveMirror.write("second"), "a second write replaces it")
		if err == "":
			err = _T.assert_eq(SaveMirror.read(), "second", "rather than appending")
	if err == "":
		SaveMirror.erase()
		err = _T.assert_eq(SaveMirror.read(), "", "and erase empties it again")
	SaveMirror.force_store = stashed_store
	return err


## THE PATH THE MIRROR EXISTS FOR: the save and its `.tmp` are both gone -- an IDBFS
## mount that came back empty -- and the browser still has the bytes. `_load` writes them
## to `save_path` and parses THAT, so there is exactly one parser and one validator in
## `RunConfig` (see `SaveMirror`'s header), and `load_status` says "mirrored" so a launch
## that took this path is distinguishable from an ordinary one.
func test_a_load_with_no_file_on_disk_reads_the_mirror() -> String:
	var stashed_store: Variant = SaveMirror.force_store
	var stashed: Dictionary = _stash_shop_state()
	var stashed_campaign: int = RunConfig.campaign_high_score
	_stage_shop("user://test_skins_mirror.save", Skins.PLANT_SKIN_COST)
	SaveMirror.force_store = {}
	RunConfig.campaign_high_score = 4242
	var plant: StringName = PlantCatalog.ids()[0]

	var err: String = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PLANT, plant, &"golden"),
		"a purchase is made, which writes the save and therefore the mirror")
	if err == "":
		err = _T.assert_eq(SaveMirror.read(),
			FileAccess.get_file_as_string(RunConfig.save_path),
			"and the mirror is byte-identical to the file -- a copy of validated "
				+ "bytes, never a second composition")
	if err == "":
		# The web failure this exists for: user:// came back empty. Both files gone,
		# every field wiped, and the browser copy is all there is.
		for suffix: String in ["", ".tmp"]:
			if FileAccess.file_exists(RunConfig.save_path + suffix):
				DirAccess.remove_absolute(RunConfig.save_path + suffix)
		RunConfig.petals = 77
		RunConfig.purchased_skins = {}
		RunConfig.campaign_high_score = 0
		RunConfig._load()
		err = _T.assert_eq(RunConfig.load_status, "mirrored",
			"the load says where it got the bytes, got %s" % RunConfig.load_status)
	if err == "":
		err = _T.assert_true(RunConfig.owns_skin(Skins.KIND_PLANT, plant, &"golden"),
			"the purchase came back off the mirror")
	if err == "":
		err = _T.assert_eq(RunConfig.petals, 0, "and so did the spent balance")
	if err == "":
		err = _T.assert_eq(RunConfig.campaign_high_score, 4242,
			"and the high score that shared the file")
	if err == "":
		err = _T.assert_true(FileAccess.file_exists(RunConfig.save_path),
			"and the bytes were written back to save_path, so the next launch is "
				+ "an ordinary load rather than another mirrored one")
	if err == "":
		# A mirror with nothing in it is not a load. Both files gone AND the store
		# empty is a genuine first launch, and must read as one.
		SaveMirror.erase()
		for suffix: String in ["", ".tmp"]:
			if FileAccess.file_exists(RunConfig.save_path + suffix):
				DirAccess.remove_absolute(RunConfig.save_path + suffix)
		RunConfig._load()
		err = _T.assert_eq(RunConfig.load_status, "absent",
			"an empty mirror with no file is a first launch, not a mirrored one")
	RunConfig.campaign_high_score = stashed_campaign
	_restore_shop_state(stashed)
	SaveMirror.force_store = stashed_store
	return err


# -- The tint actually applying on the board ----------------------------------


## A plant wearing an `art` family takes the DRAWING and `Color.WHITE`, never both.
##
## The expectation is the rule stated once rather than a pinned colour: multiplying a
## tint over an already-recoloured sprite desaturates three deliberate hues into one
## muddy one, which is the mistake `PlantMutation.SPORT_MODULATE` was changed to stop
## making, and a hardcoded `Color.WHITE` here would go on passing if `has_art` ever
## started answering false.
func test_a_placed_plant_wears_its_chosen_skins_drawing_and_no_tint() -> String:
	var stashed: Dictionary = _stash_shop_state()
	_stage_shop("user://test_skins_plant_tint.save", Skins.PLANT_SKIN_COST)
	var kind: StringName = PlantCatalog.ids()[0]
	var err: String = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PLANT, kind, &"golden"),
		"golden is bought for the plant this test places")
	if err == "":
		err = _T.assert_true(RunConfig.set_skin(Skins.KIND_PLANT, kind, &"golden"),
			"and chosen for it")
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
		err = _T.assert_true(plant._sprite != null, "the sprite exists to be painted")
		if err == "":
			var expected: Color = (Color.WHITE if Skins.has_art(&"golden")
				else Skins.tint_for(&"golden"))
			err = _T.assert_eq(plant._sprite.modulate, expected,
				"a family with a drawing of its own is worn WHITE -- the drawing is "
					+ "already the colour")
	if err == "":
		err = _T.assert_eq(plant.frame_texture_path(PlantCatalog.texture_path(kind)),
			Skins.texture_path(PlantCatalog.texture_path(kind), &"golden"),
			"and the frame funnel hands back the skin's own drawing, not the parent's")
	if plant != null:
		plant.free()
	_restore_shop_state(stashed)
	return err


## A PEST skin is still a tint and nothing else, which is why `tint` survived the shop
## on every FAMILIES row -- see `Skins`'s own header.
func test_a_spawned_pest_wears_its_chosen_skins_tint_until_a_mutation_lands() -> String:
	var stashed: Dictionary = _stash_shop_state()
	_stage_shop("user://test_skins_pest_tint.save", Skins.PEST_SKIN_COST)
	var species: StringName = Pest.APHID
	var err: String = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PEST, species, &"ember"),
		"ember is bought for the species this test spawns")
	if err == "":
		err = _T.assert_true(RunConfig.set_skin(Skins.KIND_PEST, species, &"ember"),
			"and chosen for it")
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
	_restore_shop_state(stashed)
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
		while page < screen.total_pages() and err == "":  # loop-bound-check: ok - page counts up against the pager's own fixed total, computed once above.
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


## Pressing a row's button advances to the next OWNED skin and RunConfig agrees -- the
## screen has no state of its own to disagree with the thing it writes to.
##
## The wardrobe is staged directly rather than bought through `buy_skin`, because what
## this test is about is the screen, and a fixture that had to earn eight petals first
## would fail for a reason in the economy.
func test_pressing_a_row_button_advances_the_selection_and_persists_it() -> String:
	var stashed: Dictionary = _stash_shop_state()
	# Pressing the row button reaches RunConfig.set_skin(), which saves -- redirected
	# to scratch, the same discipline every other test here that can reach _save()
	# follows.
	_stage_shop("user://test_skins_screen_press.save", 0)
	var plant: StringName = PlantCatalog.ids()[0]
	var owned: Array[String] = []
	for row: Dictionary in Skins.buyable_families():
		owned.append(String(row["id"]))
	RunConfig.purchased_skins = {Skins.selection_key(Skins.KIND_PLANT, plant): owned}

	var screen := await _T.instantiate_ui(SkinsScreen.build(), Vector2i(1152, 648)) as SkinsScreen
	var err: String = _T.assert_true(screen.show_page_for(Skins.KIND_PLANT, plant),
		"the screen can turn to the page holding the first plant")
	if err == "":
		err = _T.assert_true(screen.press_skin_button(Skins.KIND_PLANT, plant),
			"and its row button can be pressed")
	if err == "":
		var chosen: StringName = RunConfig.selected_skin(Skins.KIND_PLANT, plant)
		err = _T.assert_true(chosen != Skins.DEFAULT_SKIN,
			"one press moved off the default -- every family is owned in this fixture")
	if err == "":
		var neighbour: StringName = PlantCatalog.ids()[1]
		err = _T.assert_true(screen.show_page_for(Skins.KIND_PLANT, neighbour),
			"the page holding the next plant can be reached")
		if err == "":
			err = _T.assert_true(screen.press_skin_button(Skins.KIND_PLANT, neighbour),
				"and its button presses too")
		if err == "":
			err = _T.assert_eq(RunConfig.selected_skin(Skins.KIND_PLANT, neighbour),
				Skins.DEFAULT_SKIN,
				"but it owns nothing, so the only family to cycle to is the default -- "
					+ "ownership is per row, and the screen reads it per row")
	_T.free_ui(screen)
	_restore_shop_state(stashed)
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
