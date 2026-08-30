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
		err = _T.assert_true(Skins.price_for(Skins.KIND_PLANT, Skins.DEFAULT_SKIN).is_empty(),
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
			err = _T.assert_eq(Skins.price_for(Skins.KIND_PLANT, id),
				Skins.PRICES[Skins.KIND_PLANT],
				"%s costs a plant skin's price on a plant" % id)
		if err == "":
			err = _T.assert_eq(Skins.price_for(Skins.KIND_PEST, id),
				Skins.PRICES[Skins.KIND_PEST],
				"%s costs a pest skin's price on a pest" % id)
	return err


## EVERY KIND IS PRICED IN EVERY CURRENCY, walked over both tables rather than over a
## list of the three ids typed here (`.claude/skills/derive-the-list`). A currency added
## to `Currency.TABLE` and forgotten in `Skins.PRICES` would otherwise cost nothing: a
## missing key reads as 0, `Currency.covers` answers true for it, and the shop would
## quietly sell a two-currency skin with no error anywhere.
func test_every_kind_is_priced_in_every_currency() -> String:
	var kinds: Array[StringName] = []
	for target: Dictionary in Skins.targets():
		var kind := StringName(target["kind"])
		if not kinds.has(kind):
			kinds.append(kind)
	var err: String = _T.assert_gt(kinds.size(), 1,
		"more than one target kind, or the per-kind pricing claim below is vacuous")
	var checked: int = 0
	for kind: StringName in kinds:
		if err != "":
			break
		err = _T.assert_true(Skins.PRICES.has(kind), "%s has a price row at all" % kind)
		if err != "":
			break
		var price: Dictionary = Skins.PRICES[kind] as Dictionary
		err = _T.assert_eq(price.size(), Currency.ids().size(),
			("%s is priced in exactly the currencies that exist -- %d terms against %d "
				+ "currencies") % [kind, price.size(), Currency.ids().size()])
		for id: StringName in Currency.ids():
			if err != "":
				break
			checked += 1
			err = _T.assert_true(price.has(String(id)),
				"%s names a price in %s" % [kind, id])
			if err == "":
				err = _T.assert_gt(int(price[String(id)]), 0,
					("%s costs a positive amount of %s -- a zero term is a currency "
						+ "that is not really part of the price") % [kind, id])
	if err == "":
		err = _T.assert_eq(checked, kinds.size() * Currency.ids().size(),
			"%d price terms swept, which is every kind against every currency" % checked)
	return err


## A drawing costs more than a tint IN EVERY CURRENCY, not just on average.
##
## The old single-number version of this said `PLANT_SKIN_COST > PEST_SKIN_COST` and was
## a complete claim because there was one number. With three there are three ways to get
## it wrong, and the interesting one is a price where two terms say "a plant skin is
## dearer" and the third says the opposite -- which reads to a player as a plant skin
## being cheaper than a pest one whenever that term is the binding constraint, which it
## is precisely when it is the scarcest.
func test_a_plant_skin_costs_more_than_a_pest_skin_in_every_currency() -> String:
	var plant: Dictionary = Skins.PRICES[Skins.KIND_PLANT] as Dictionary
	var pest: Dictionary = Skins.PRICES[Skins.KIND_PEST] as Dictionary
	var err: String = ""
	var checked: int = 0
	for id: StringName in Currency.ids():
		if err != "":
			break
		checked += 1
		err = _T.assert_gt(int(plant.get(String(id), 0)), int(pest.get(String(id), 0)),
			("a generated drawing costs more %s than a tint does, or these two prices "
				+ "are saying the same thing about two different purchases") % id)
	return err if err != "" else _T.assert_gt(checked, 2,
		"%d currencies compared, and there should be one per Currency.TABLE row" % checked)


# -- the currency table and the wallet line (plant-tower-defense-il1y) --------


## Every row of `Currency.TABLE` is complete and distinct, walked over the table rather
## than over three ids typed here (`.claude/skills/derive-the-list`).
##
## `source_of` is asserted because it is DRAWN -- it is the last column of the Shop's
## currency table, not a comment -- so an empty one is a blank cell on a real screen.
func test_every_currency_is_named_marked_and_says_where_it_comes_from() -> String:
	var ids: Array[StringName] = Currency.ids()
	var err: String = _T.assert_eq(ids.size(), Currency.TABLE.size(),
		"ids() is the whole table and nothing else")
	if err == "":
		err = _T.assert_gt(ids.size(), 2,
			"%d currencies, and a skin is meant to cost more than one thing" % ids.size())
	var seen_titles: Array[String] = []
	var seen_glyphs: Array[String] = []
	for id: StringName in ids:
		if err != "":
			break
		err = _T.assert_true(Currency.has(id), "%s is a currency this build knows" % id)
		if err == "":
			err = _T.assert_true(Currency.title_of(id) != String(id),
				"%s has a drawn word, not its bare id" % id)
		if err == "":
			err = _T.assert_false(Currency.source_of(id).is_empty(),
				("%s says where it comes from -- that string is a COLUMN on the Shop, "
					+ "so an empty one is a blank cell") % id)
		if err == "":
			err = _T.assert_false(Currency.glyph_of(id).is_empty(),
				"%s has a mark" % id)
		if err == "":
			# DISTINCT, all three ways. Two currencies sharing a word or a mark are two
			# rows the player reads as one.
			err = _T.assert_false(seen_titles.has(Currency.title_of(id)),
				"%s's word is its own" % id)
		if err == "":
			err = _T.assert_false(seen_glyphs.has(Currency.glyph_of(id)),
				"and so is its mark -- three amounts in one column at one size are told "
					+ "apart by silhouette and nothing else")
		seen_titles.append(Currency.title_of(id))
		seen_glyphs.append(Currency.glyph_of(id))
	if err == "":
		# An id from a newer build's save: named by its own spelling, marked with
		# nothing, and explained with nothing -- never blank, never guessed at.
		err = _T.assert_eq(Currency.title_of(&"verdigris"), "verdigris",
			"an unknown currency falls back to its raw id rather than rendering blank")
		if err == "":
			err = _T.assert_eq(Currency.glyph_of(&"verdigris"), "",
				"and carries no mark")
		if err == "":
			err = _T.assert_eq(Currency.source_of(&"verdigris"), "",
				"and claims no source, so a composed note simply omits it")
	return err


## `compost_for` is a FLOOR, and the boundary is the whole of it: a run that killed
## COMPOST_PER_PESTS - 1 pests is worth nothing, and one that killed exactly
## COMPOST_PER_PESTS is worth one. Rounding up would make a quit-out worth a wave.
func test_compost_is_floored_against_the_pests_a_run_defeated() -> String:
	var rate: int = Currency.COMPOST_PER_PESTS
	var err: String = _T.assert_gt(rate, 1,
		"the rate is more than one pest, or flooring is not a claim about anything")
	if err == "":
		err = _T.assert_eq(Currency.compost_for(0), 0, "a run that killed nothing pays nothing")
	if err == "":
		err = _T.assert_eq(Currency.compost_for(-4), 0,
			"and neither does a negative, which is not a shape a run produces but is "
				+ "one an int can hold")
	if err == "":
		err = _T.assert_eq(Currency.compost_for(rate - 1), 0,
			"one pest short of the rate is still nothing -- FLOORED, not rounded")
	if err == "":
		err = _T.assert_eq(Currency.compost_for(rate), 1, "exactly the rate is one")
	if err == "":
		err = _T.assert_eq(Currency.compost_for(rate * 3 + rate - 1), 3,
			"and the remainder past a multiple is dropped rather than carried")
	return err


## The wallet line round trips, and the shapes it has to refuse are refused.
##
## `parse_wallet_line` is asserted directly here as well as through a whole save in
## test_economy.gd, because this is where its GRAMMAR lives: the file-level test can only
## say "the save was refused", and cannot say which of a dozen malformed lines it was
## refused for.
func test_compose_and_parse_wallet_line_round_trip() -> String:
	var purse: Dictionary = Currency.empty_wallet()
	purse[String(Currency.PETALS)] = 118
	purse[String(Currency.COMPOST)] = 40
	var line: String = RunConfig.compose_wallet_line(purse)
	var err: String = _T.assert_true(
		line.begins_with("%s%d " % [RunConfig.WALLET_PREFIX, Currency.ids().size()]),
		("every known currency is written, including the ones at zero, and the line is "
			+ "count-prefixed: %s") % line)
	if err == "":
		var parsed: Variant = RunConfig.parse_wallet_line(line)
		err = _T.assert_eq(parsed, purse,
			"parse_wallet_line reads back exactly what was written")
	if err == "":
		# SORTED, so two saves holding the same wallet are byte-identical rather than
		# differing by the order the player happened to earn things in.
		var shuffled: Dictionary = {}
		var backwards: Array[StringName] = Currency.ids()
		backwards.reverse()
		for id: StringName in backwards:
			shuffled[String(id)] = int(purse[String(id)])
		err = _T.assert_eq(RunConfig.compose_wallet_line(shuffled), line,
			"and the field order is the writer's sort, not the Dictionary's")
	if err == "":
		# A caller that named nothing still gets every currency -- the shape
		# `compose_save`'s own default relies on.
		err = _T.assert_eq(RunConfig.compose_wallet_line({}),
			RunConfig.compose_wallet_line(Currency.empty_wallet()),
			"an empty Dictionary composes the same line a full empty wallet does")
	var refused: Dictionary = {
		"a line with no marker": "3 petals=1",
		"the marker with no count": "w petals=1",
		"a count that is not a number": "wx petals=1",
		"a count that disagrees with the fields": "w2 petals=1",
		"a negative count": "w-1",
		"a field with no value": "w1 petals",
		"a value that is not a number": "w1 petals=some",
		"a negative amount": "w1 petals=-1",
		"an id outside the legal alphabet": "w1 Petals=1",
		"the same currency twice": "w2 petals=1 petals=2",
	}
	for what: String in refused:
		if err != "":
			break
		err = _T.assert_eq(RunConfig.parse_wallet_line(String(refused[what])), null,
			"%s is refused, not half-read (%s)" % [what, refused[what]])
	if err == "":
		# The tolerance the refusals must NOT swallow: a currency this build has never
		# had is a legal line. Refusing it would condemn a save whose two high scores
		# cannot be re-earned, over a balance that can.
		var future: Variant = RunConfig.parse_wallet_line("w1 verdigris=7")
		err = _T.assert_eq(future, {"verdigris": 7},
			"while a currency from a newer build parses, because the whole file is at "
				+ "stake and one unfamiliar id is not grounds to lose it")
	return err


## `wallet_from_parsed` fills in what a save did not carry and keeps what this build
## cannot spend -- the two halves of reading a wallet written by a different build.
func test_a_parsed_wallet_gains_this_builds_currencies_and_keeps_the_strangers() -> String:
	var thin: Dictionary = RunConfig.wallet_from_parsed({String(Currency.PETALS): 5})
	var err: String = _T.assert_eq(thin.size(), Currency.ids().size(),
		"a save naming one currency reads as a full wallet: %s" % thin)
	if err == "":
		err = _T.assert_eq(Currency.amount_in(thin, Currency.PETALS), 5,
			"with what it did name")
	if err == "":
		err = _T.assert_eq(Currency.amount_in(thin, Currency.COMPOST), 0,
			("and zero of what it did not -- which is the honest reading rather than a "
				+ "fallback, since nothing before v13 could have earned it"))
	if err == "":
		var strange: Dictionary = RunConfig.wallet_from_parsed({"verdigris": 7})
		err = _T.assert_eq(int(strange.get("verdigris", 0)), 7,
			("a currency this build does not know is KEPT, so a round trip through an "
				+ "older build is not a silent confiscation"))
		if err == "":
			err = _T.assert_eq(Currency.amount_in(strange, &"verdigris"), 7,
				"and reads back through the same door every other amount does")
	if err == "":
		# Never negative, whatever a corrupted line said. `_is_score` already refuses one
		# at the parser; this is the second door, because a negative reaching the wallet
		# is what makes the next save fail its own readback for the rest of the session.
		var broken: Dictionary = RunConfig.wallet_from_parsed({String(Currency.PETALS): -3})
		err = _T.assert_eq(Currency.amount_in(broken, Currency.PETALS), 0,
			"a negative amount clamps to zero rather than reaching the wallet")
	return err


## `grant_all` is ONE WRITE for several currencies, which is the whole reason it exists
## beside `grant`: a banked run pays petals and compost together, and three grants would
## rewrite the save three times while the post-mortem is animating.
##
## The claim a `grant`-shaped test cannot make is the FILE one, so this counts writes by
## deleting the save between calls and asking whether it came back.
func test_grant_all_pays_every_currency_in_one_write() -> String:
	var stashed: Dictionary = _stash_shop_state()
	_stage_shop("user://test_skins_grant_all.save", Currency.empty_wallet())
	var earned: Dictionary = {
		String(Currency.PETALS): 27,
		String(Currency.COMPOST): 35,
		String(Currency.HEARTWOOD): 1,
	}
	RunConfig.grant_all(earned)
	var err: String = ""
	for id: StringName in Currency.ids():
		if err != "":
			break
		err = _T.assert_eq(Currency.amount_in(RunConfig.wallet, id),
			int(earned[String(id)]), "%s landed" % id)
	if err == "":
		err = _T.assert_true(FileAccess.file_exists(RunConfig.save_path),
			"and the grant wrote the file")
	if err == "":
		# ADDS, never replaces: a second banked run tops the wallet up.
		RunConfig.grant_all({String(Currency.PETALS): 3})
		err = _T.assert_eq(Currency.amount_in(RunConfig.wallet, Currency.PETALS), 30,
			"a second grant adds to what was there")
	if err == "":
		# NOTHING TO PAY IS NO WRITE, the same rule `grant` follows and for the reason
		# `set_colorblind_safe` gives: the save is not a place to record that nothing
		# happened. A run that cleared no wave and killed nothing reaches this.
		DirAccess.remove_absolute(RunConfig.save_path)
		RunConfig.grant_all({})
		err = _T.assert_false(FileAccess.file_exists(RunConfig.save_path),
			"an empty grant writes nothing")
		if err == "":
			RunConfig.grant_all({String(Currency.PETALS): 0})
			err = _T.assert_false(FileAccess.file_exists(RunConfig.save_path),
				"and neither does a grant of zero")
	if err == "":
		# A bad id costs a warning and NOT the grants beside it, which is the whole
		# argument for doing the refusals against the in-memory wallet first.
		RunConfig.grant_all({"verdigris": 4, String(Currency.COMPOST): 2})
		err = _T.assert_eq(Currency.amount_in(RunConfig.wallet, Currency.COMPOST), 37,
			"a currency this build does not have does not cost the ones beside it")
		if err == "":
			err = _T.assert_eq(int(RunConfig.wallet.get("verdigris", 0)), 0,
				"and it was refused rather than invented")
	_restore_shop_state(stashed)
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
		err = _T.assert_eq(Skins.texture_path("", &"plate"), "",
			"and the empty path stays empty rather than becoming _skin_plate.")
	for row: Dictionary in Skins.buyable_families():
		if err != "":
			break
		var id := StringName(row["id"])
		var once: String = Skins.texture_path(base, id)
		err = _T.assert_eq(once, "res://assets/sprites/sunflower_skin_%s.png" % id,
			"%s derives its own drawing beside the parent" % id)
		if err == "":
			# Idempotent: the funnel is reached once per frame per plant, and a second
			# pass must not produce sunflower_skin_plate_skin_plate.png.
			err = _T.assert_eq(Skins.texture_path(once, id), once,
				"%s applied twice is %s applied once" % [id, id])
		if err == "":
			# And a path already wearing ANOTHER family's suffix is left alone too --
			# the guard is "does this carry a skin suffix", not "does it carry MINE".
			var other: StringName = &"cutpaper" if id != &"cutpaper" else &"sampler"
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
		"wallet": RunConfig.wallet.duplicate(true),
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
	RunConfig.wallet = (stashed["wallet"] as Dictionary).duplicate(true)
	RunConfig.load_status = str(stashed["load_status"])


## Points RunConfig at `path` with an empty wardrobe and `purse` in the wallet.
func _stage_shop(path: String, purse: Dictionary) -> void:
	RunConfig.save_path = path
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	RunConfig.selected_skins = {}
	RunConfig.purchased_skins = {}
	RunConfig.wallet = purse


## A wallet holding exactly `copies` of `price` and nothing else -- the staging every
## shop test wants, because "can afford exactly this and no more" is the boundary each
## of them is actually about.
##
## DERIVED FROM THE PRICE, never typed. A test that staged `{"petals": 120, ...}` would
## be a second copy of `Skins.PRICES` that stops agreeing with it the day the prices are
## retuned, and would then pass or fail for a reason having nothing to do with the code
## under test.
static func _purse_for(price: Dictionary, copies: int = 1) -> Dictionary:
	var out: Dictionary = Currency.empty_wallet()
	for key: Variant in price.keys():
		out[String(key)] = int(price[key]) * copies
	return out


## `_purse_for(price)` with one unit of `short` taken back out: the boundary
## `Currency.covers` turns on, and the only wallet that tells `>=` from `>`.
static func _purse_short_of(price: Dictionary, short: StringName) -> Dictionary:
	var out: Dictionary = _purse_for(price)
	out[String(short)] = maxi(0, int(out.get(String(short), 0)) - 1)
	return out


## The two prices added together -- for the tests that buy a plant skin AND a pest one
## and then assert the wallet is spent to the penny.
static func _purse_for_both() -> Dictionary:
	var out: Dictionary = _purse_for(Skins.PRICES[Skins.KIND_PLANT] as Dictionary)
	for key: Variant in (Skins.PRICES[Skins.KIND_PEST] as Dictionary).keys():
		out[String(key)] = (int(out.get(String(key), 0))
			+ int((Skins.PRICES[Skins.KIND_PEST] as Dictionary)[key]))
	return out


## Whether the wallet is empty in every currency -- "spent to the penny", said once
## rather than three assertions per test.
static func _purse_is_empty() -> bool:
	for id: StringName in Currency.ids():
		if Currency.amount_in(RunConfig.wallet, id) != 0:
			return false
	return true


## THE FOUR REFUSALS `buy_skin` documents, each one asserted to leave the balance and
## the wardrobe exactly as they were -- which is the half a "returns false" check
## misses, and the half that would show up as a player being charged for nothing.
func test_buy_skin_refuses_unknown_unaffordable_and_already_owned() -> String:
	var stashed: Dictionary = _stash_shop_state()
	_stage_shop("user://test_skins_buy_refusals.save",
		_purse_for(Skins.PRICES[Skins.KIND_PLANT] as Dictionary))
	var plant: StringName = PlantCatalog.ids()[0]

	var err: String = _T.assert_false(RunConfig.buy_skin(Skins.KIND_PLANT, &"not_a_plant", &"plate"),
		"an unknown target is refused")
	if err == "":
		err = _T.assert_false(RunConfig.buy_skin(Skins.KIND_PLANT, plant, &"not_a_real_skin"),
			"and so is a family this build does not know")
	if err == "":
		err = _T.assert_false(RunConfig.buy_skin(Skins.KIND_PLANT, plant, Skins.DEFAULT_SKIN),
			"and so is the default, which is not for sale because everyone has it")
	if err == "":
		err = _T.assert_eq(RunConfig.wallet,
			_purse_for(Skins.PRICES[Skins.KIND_PLANT] as Dictionary),
			"three refusals later the wallet has not moved")
	if err == "":
		err = _T.assert_eq(RunConfig.purchased_skins, {}, "and nothing was recorded")
	if err == "":
		err = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PLANT, plant, &"plate"),
			"the affordable purchase goes through")
	if err == "":
		err = _T.assert_true(_purse_is_empty(), "and costs exactly its price: %s"
			% RunConfig.wallet)
	if err == "":
		err = _T.assert_false(RunConfig.buy_skin(Skins.KIND_PLANT, plant, &"plate"),
			"buying it again is refused rather than silently charged")
	if err == "":
		err = _T.assert_true(_purse_is_empty(),
			"so the wallet is still zero, not negative: %s" % RunConfig.wallet)
	if err == "":
		# The unaffordable case, ONE UNIT SHORT IN EACH CURRENCY IN TURN -- the boundary,
		# not a comfortable zero, because `covers` turns on `>=` and a `>` would differ
		# only there. Each currency separately, because `Currency.covers` is all-or-
		# nothing and the way to get that wrong is to check one term and stop.
		var pest: StringName = StringName(Pest.SPECIES.keys()[0])
		var pest_price: Dictionary = Skins.PRICES[Skins.KIND_PEST] as Dictionary
		for short: StringName in Currency.ids():
			if err != "":
				break
			RunConfig.wallet = _purse_short_of(pest_price, short)
			err = _T.assert_false(RunConfig.buy_skin(Skins.KIND_PEST, pest, &"cutpaper"),
				"one %s short is refused even with every other currency in hand" % short)
			if err == "":
				err = _T.assert_eq(RunConfig.wallet, _purse_short_of(pest_price, short),
					"and what it did have is still there")
		if err == "":
			RunConfig.wallet = _purse_for(pest_price)
			err = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PEST, pest, &"cutpaper"),
				"exactly the price is enough")
	_restore_shop_state(stashed)
	return err


## A purchase dresses ONE row. The unit-level version of this is the ownership matrix
## above; this is the same claim through the real writer, because `buy_skin` is where a
## key could be built wrong and hand plate to every plant at once.
func test_buying_a_skin_for_one_target_does_not_give_it_to_another() -> String:
	var stashed: Dictionary = _stash_shop_state()
	_stage_shop("user://test_skins_per_target.save",
		_purse_for(Skins.PRICES[Skins.KIND_PLANT] as Dictionary, 2))
	var ids: Array[StringName] = PlantCatalog.ids()
	var err: String = _T.assert_gt(ids.size(), 1,
		"more than one plant, or this test cannot tell a leak from a hit")
	if err == "":
		err = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PLANT, ids[0], &"plate"),
			"plate is bought for the first plant")
	if err == "":
		err = _T.assert_true(RunConfig.owns_skin(Skins.KIND_PLANT, ids[0], &"plate"),
			"the row it was bought on owns it")
	if err == "":
		err = _T.assert_false(RunConfig.owns_skin(Skins.KIND_PLANT, ids[1], &"plate"),
			"the next plant does not")
	if err == "":
		var pest: StringName = StringName(Pest.SPECIES.keys()[0])
		err = _T.assert_false(RunConfig.owns_skin(Skins.KIND_PEST, pest, &"plate"),
			"and neither does a pest -- the key carries the kind as well as the id")
	if err == "":
		err = _T.assert_false(RunConfig.owns_skin(Skins.KIND_PLANT, ids[0], &"cutpaper"),
			"and the purchase bought one family, not the row's whole wardrobe")
	_restore_shop_state(stashed)
	return err


## A balance cannot go negative, which is not a nicety: `_is_score` refuses a negative
## amount on the `w` line, so a wallet that went below zero would fail `_save()`'s own
## readback and every save for the rest of the session would silently return false.
##
## SWEPT OVER EVERY CURRENCY, not asserted on petals and assumed of the rest: `grant`
## takes the id as an argument, so "the guard is on the function" is exactly the kind of
## claim that holds for the one currency somebody tested it with.
func test_a_balance_never_goes_negative() -> String:
	var stashed: Dictionary = _stash_shop_state()
	_stage_shop("user://test_skins_petal_floor.save", Currency.empty_wallet())
	var err: String = ""
	for id: StringName in Currency.ids():
		if err != "":
			break
		err = _T.assert_eq(RunConfig.grant(id, -5), 0,
			"a negative grant of %s is a no-op, not a subtraction" % id)
		if err == "":
			err = _T.assert_eq(RunConfig.grant(id, 0), 0,
				"and zero %s changes nothing either" % id)
	if err == "":
		err = _T.assert_false(FileAccess.file_exists(RunConfig.save_path),
			"none of them wrote the file -- the save is not a place to record that "
				+ "nothing happened")
	if err == "":
		err = _T.assert_eq(RunConfig.grant(Currency.PETALS, 3), 3, "a real grant lands")
	if err == "":
		err = _T.assert_eq(RunConfig.grant(&"not_a_currency", 9), 0,
			"and a currency this build does not have is refused rather than invented")
	if err == "":
		# Nowhere near any price, so every term of the purchase is short at once.
		var plant: StringName = PlantCatalog.ids()[0]
		err = _T.assert_false(RunConfig.buy_skin(Skins.KIND_PLANT, plant, &"plate"),
			"a purchase dearer than the wallet is refused rather than overdrawn")
		if err == "":
			err = _T.assert_eq(Currency.amount_in(RunConfig.wallet, Currency.PETALS), 3,
				"and the wallet is untouched")
	if err == "":
		err = _T.assert_true(RunConfig._save(),
			"the wallet still reads back through the loader's own validator")
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
	var ok: bool = RunConfig.set_skin(Skins.KIND_PLANT, plant, &"plate")
	var err: String = _T.assert_false(ok, "plate is refused with an empty wardrobe")
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
	_stage_shop("user://test_skins_persist.save", _purse_for_both())
	var plant: StringName = PlantCatalog.ids()[0]
	var pest: StringName = StringName(Pest.SPECIES.keys()[0])
	var err: String = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PLANT, plant, &"plate"),
		"plate is bought for the plant")
	if err == "":
		err = _T.assert_true(RunConfig.set_skin(Skins.KIND_PLANT, plant, &"plate"),
			"and can then be chosen")
	if err == "":
		err = _T.assert_eq(RunConfig.selected_skin(Skins.KIND_PLANT, plant), &"plate",
			"and reads back as chosen")
	if err == "":
		# The pest side of the same two doors, at the pest price -- so this also proves
		# the two prices are read off the kind rather than being one number.
		err = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PEST, pest, &"sampler"),
			"sampler is bought for the pest with exactly the pest price left")
	if err == "":
		err = _T.assert_true(_purse_is_empty(),
			"and the wallet is spent to the penny: %s" % RunConfig.wallet)
	if err == "":
		err = _T.assert_true(RunConfig.set_skin(Skins.KIND_PEST, pest, &"sampler"),
			"the pest can wear what was bought for it")
	if err == "":
		err = _T.assert_eq(RunConfig.selected_skin(Skins.KIND_PEST, pest), &"sampler",
			"and reads back as chosen too")
	if err == "":
		# Idempotent, the same contract record_milestones documents for itself.
		err = _T.assert_true(RunConfig.set_skin(Skins.KIND_PLANT, plant, &"plate"),
			"choosing the same skin twice still reports success")
	if err == "":
		var bytes: String = FileAccess.get_file_as_string(RunConfig.save_path)
		err = _T.assert_true(bytes.contains(Skins.selection_key(Skins.KIND_PLANT, plant) + "=plate"),
			"the choice actually reached disk: %s" % bytes)
		if err == "":
			err = _T.assert_true(bytes.contains(Skins.selection_key(Skins.KIND_PEST, pest) + "=sampler"),
				"and so did the pest's: %s" % bytes)
		if err == "":
			err = _T.assert_true(bytes.contains("\nu2 "),
				"and the wardrobe is its own line with both purchases on it: %s" % bytes)
		if err == "":
			err = _T.assert_true(bytes.contains(
					"\n" + RunConfig.compose_wallet_line(Currency.empty_wallet()) + "\n"),
				"with the spent wallet beside it: %s" % bytes)
	if err == "":
		# All the way back off disk, not just out of memory.
		RunConfig.selected_skins = {}
		RunConfig.purchased_skins = {}
		RunConfig.wallet = _purse_for_both()
		RunConfig._load()
		err = _T.assert_eq(RunConfig.load_status, "loaded", "the file this build wrote is one it reads")
		if err == "":
			err = _T.assert_true(_purse_is_empty(),
				"the spent wallet came back: %s" % RunConfig.wallet)
		if err == "":
			err = _T.assert_true(RunConfig.owns_skin(Skins.KIND_PLANT, plant, &"plate"),
				"and so did the plant's purchase")
		if err == "":
			err = _T.assert_eq(RunConfig.selected_skin(Skins.KIND_PEST, pest), &"sampler",
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
	_stage_shop("user://test_skins_fallback.save",
		_purse_for(Skins.PRICES[Skins.KIND_PLANT] as Dictionary))
	var plant: StringName = PlantCatalog.ids()[0]
	var err: String = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PLANT, plant, &"plate"),
		"plate is bought and chosen while it is owned")
	if err == "":
		err = _T.assert_true(RunConfig.set_skin(Skins.KIND_PLANT, plant, &"plate"), "chosen")
	if err == "":
		# The wardrobe goes, the selection stays -- exactly the shape a v10 save has.
		RunConfig.purchased_skins = {}
		err = _T.assert_eq(RunConfig.selected_skin(Skins.KIND_PLANT, plant), Skins.DEFAULT_SKIN,
			"and reads back as the default once it is not owned, not as plate")
	if err == "":
		err = _T.assert_eq(String(RunConfig.selected_skins.get(
				Skins.selection_key(Skins.KIND_PLANT, plant), "")), "plate",
			"while the CHOICE is still recorded -- the migration keeps it rather than "
				+ "throwing away a preference the player still holds")
	if err == "":
		# And it comes back the moment the family is bought for that row again.
		RunConfig.wallet = _purse_for(Skins.PRICES[Skins.KIND_PLANT] as Dictionary)
		err = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PLANT, plant, &"plate"),
			"buying it again is a purchase, not a refusal, since it is no longer owned")
		if err == "":
			err = _T.assert_eq(RunConfig.selected_skin(Skins.KIND_PLANT, plant), &"plate",
				"and the old choice is worn again with nothing re-picked")
	_restore_shop_state(stashed)
	return err


# -- The v10 save line: compose, parse, and reading a v9 file forward --------


func test_compose_and_parse_skins_line_round_trip() -> String:
	var selections: Dictionary = {
		Skins.selection_key(Skins.KIND_PLANT, PlantCatalog.ids()[0]): "plate",
		Skins.selection_key(Skins.KIND_PEST, StringName(Pest.SPECIES.keys()[0])): "cutpaper",
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
		"s0 plant:sunflower=plate",  # count says zero, one field follows
		"splant:sunflower=plate",    # no space, the count is unparsable
		"s1 plant:sunflower",         # no "=" at all
		"s1 plantsunflower=plate",   # no ":" between kind and id
		"s1 :sunflower=plate",       # empty kind before the ":"
		"s1 plant:=plate",           # empty id after the ":"
		"s1 plant:sunflower=",        # empty value
		"s1 PLANT:sunflower=plate",  # uppercase is not in MILESTONE_ID_CHARS
		"s2 plant:sunflower=plate plant:sunflower=cutpaper",  # the same key twice
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
	# wardrobe byte-identical whatever order the player bought things in. Both lists below
	# are written in the reverse of the order they must come out in -- an input that
	# happened to arrive sorted would let this pass with the writer's sort deleted, which
	# is what the v12 rename nearly did to it: `ember,golden` was sorted going in and
	# `sampler,plate` is not, so the two ends of this test disagreed until both moved.
	var purchases: Dictionary = {
		pest_key: ["sampler", "plate"],
		plant_key: ["plate", "cutpaper"],
	}
	var line: String = RunConfig.compose_purchase_line(purchases)
	# The expected string is ASSEMBLED from the same sort the writer promises rather
	# than typed out: "pest:aphid" sorts before "plant:sunflower", which is a fact about
	# these two ids and not about the rule, and a literal here would be a test that
	# passes on the catalogue as it stands today.
	var wardrobes: Dictionary = {
		plant_key: "cutpaper,plate",
		pest_key: "plate,sampler",
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
				var plant_expected: Array[String] = ["cutpaper", "plate"]
				err = _T.assert_eq(back[plant_key], plant_expected,
					"the plant's wardrobe came back sorted")
			if err == "":
				var pest_expected: Array[String] = ["plate", "sampler"]
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
		err = _T.assert_eq(RunConfig.compose_purchase_line({key: ["plate", "plate"]}),
			"u1 %s=plate" % key, "a duplicate within a key is written once")
	return err


func test_parse_purchase_line_refuses_malformed_lines() -> String:
	var cases: Array[String] = [
		"s0",                        # a skins line, not a wardrobe line -- wrong prefix
		"u1",                        # count says one, no fields follow
		"u0 plant:sunflower=plate",  # count says zero, one field follows
		"uplant:sunflower=plate",    # no space, the count is unparsable
		"u1 plant:sunflower",         # no "=" at all
		"u1 plantsunflower=plate",   # no ":" between kind and id
		"u1 :sunflower=plate",       # empty kind before the ":"
		"u1 plant:=plate",           # empty id after the ":"
		"u1 plant:sunflower=",        # empty value
		"u1 plant:sunflower=plate,",  # a trailing comma is an empty family
		"u1 plant:sunflower=plate,,cutpaper",  # and so is a doubled one
		"u1 plant:sunflower=PLATE",  # uppercase is not in MILESTONE_ID_CHARS
		"u1 PLANT:sunflower=plate",  # nor in the key half
		"u1 plant:sunflower=plate,plate",  # the same family twice on one key
		"u2 plant:sunflower=plate plant:sunflower=cutpaper",  # the same key twice
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
	var stashed_wallet: Dictionary = RunConfig.wallet.duplicate(true)
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
		# Rewritten forward: the file on disk is now a current-version file with an explicit "s0",
		# and the two shop lines under it.
		var rewritten: String = FileAccess.get_file_as_string(path)
		err = _T.assert_true(rewritten.begins_with("v%d\n" % RunConfig.SAVE_VERSION),
			"the migrated file is stamped at the current version: %s" % rewritten)
		if err == "":
			err = _T.assert_true(rewritten.contains("\ns0\n"),
				"and carries the empty skins line explicitly, not by omission: %s" % rewritten)
		if err == "":
			err = _T.assert_true(rewritten.contains("\ns0\n%s\nu0\n"
					% RunConfig.compose_wallet_line(Currency.empty_wallet())),
				("and the wallet and wardrobe lines under it, in that order and above "
					+ "the binding count -- a field written after the count would be "
					+ "read as a binding: %s") % rewritten)

	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	RunConfig.save_path = stashed_path
	RunConfig.selected_skins = stashed_selections
	RunConfig.earned_milestones = stashed_milestones
	RunConfig.purchased_skins = stashed_purchases
	RunConfig.wallet = stashed_wallet
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
func test_a_v10_save_loads_forward_with_an_empty_wallet_and_no_purchases() -> String:
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
	#
	# THE SKIN IS SPELLED `golden`, WHICH IS WHAT v10 WROTE, and it is a literal rather
	# than `Skins.RENAMED_FAMILIES.keys()[0]`: this is a fixture standing in for a file
	# on a real player's disk, and a fixture derived from the map would rename itself to
	# match whatever the map said and assert nothing. So a v10 save now crosses TWO
	# migrations on one load -- the v11 wardrobe it never had, and the v12 rename.
	var v10_bytes: String = ("v10\n1234\n5678\nm1:campaign_cleared\n"
		+ "cb0 sfx0 mus0 spd0 svol0 mvol0\nd0\ns1 %s=golden\n0\n") % key
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(v10_bytes)
	f.close()

	RunConfig.save_path = path
	RunConfig.wallet = Currency.add(Currency.empty_wallet(), Currency.PETALS, 99)
	RunConfig.purchased_skins = {"plant:leftover": ["sampler"]}
	RunConfig._load()
	var err: String = _T.assert_eq(RunConfig.load_status, "migrated",
		"a v10 file loads and is rewritten forward rather than refused, got %s"
			% RunConfig.load_status)
	if err == "":
		err = _T.assert_eq(RunConfig.wallet, Currency.empty_wallet(),
			("a build with no shop earned nothing in any currency -- not the 99 petals "
				+ "inherited from this process, and not a crash: %s") % RunConfig.wallet)
	if err == "":
		err = _T.assert_eq(RunConfig.purchased_skins, {},
			"and bought nothing -- the load REPLACED the in-memory wardrobe rather "
				+ "than merging into it")
	if err == "":
		err = _T.assert_eq(String(RunConfig.selected_skins.get(key, "")), "plate",
			("while the v10 SELECTION survived the parse AND was renamed forward -- it "
				+ "went in as `golden` and a build that kept it verbatim would be holding a "
				+ "family `Skins.has_family` says does not exist"))
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
				+ "d0\ns1 %s=plate\nw3 compost=0 heartwood=0 petals=0\nu0\n0\n")
				% [RunConfig.SAVE_VERSION, key],
			("and the file on disk is now a current-version file, byte for byte, "
				+ "with the skin renamed on the way through: %s") % rewritten)
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


# -- the v12 family rename (plant-tower-defense-p5ke.2) -----------------------
#
# The three families were named for COLOURS -- `golden`, `frost`, `ember` -- while a
# family WAS a colour. A family is now an art STYLE, so they are `plate`, `cutpaper` and
# `sampler`. The ids the save carries changed, which makes this a migration and not a
# rename, and `RunConfig.VERSION_WITH_STYLE_SKINS` is where the save half is asserted
# (test_economy.gd). What is asserted HERE is the table itself.


## The table carries the style ids and no retired one.
##
## The failure this is pointed at is a half-done rename: a `FAMILIES` row still spelled
## `golden` while `Skins.RENAMED_FAMILIES` maps `golden` onto `plate` is a build whose
## own migration renames an id it still has, which reads as working until a save from
## before the rename comes back holding two families where the player bought one.
##
## THE THREE IDS ARE PINNED AS LITERALS, deliberately, for the reason
## `test_the_difficulty_score_line_round_trips_and_refuses_a_bad_count` pins `score_key`'s
## output: these exact strings are what a player's save FILE carries, so changing one
## orphans every wardrobe on disk. Written as `FAMILIES[1]["id"] == FAMILIES[1]["id"]`
## this would move with the table and never disagree.
func test_the_family_table_carries_the_style_ids_and_no_retired_one() -> String:
	var ids: Array[String] = []
	for row: Dictionary in Skins.FAMILIES:
		ids.append(String(row["id"]))
	var expected: Array[String] = ["default", "plate", "cutpaper", "sampler"]
	var err: String = _T.assert_eq(ids, expected,
		"FAMILIES is the default row and the three style families, in that order: %s" % [ids])
	if err == "":
		err = _T.assert_gt(Skins.RENAMED_FAMILIES.size(), 0,
			"there are retired ids to check for, or every sweep below passes over nothing")
	for old: Variant in Skins.RENAMED_FAMILIES.keys():
		if err != "":
			break
		var new_id: String = String(Skins.RENAMED_FAMILIES[old])
		err = _T.assert_false(Skins.has_family(StringName(old)),
			("%s is retired and must not still be in FAMILIES -- a map from an id onto an "
				+ "id the table also has is a migration that duplicates a wardrobe") % old)
		if err == "":
			err = _T.assert_true(Skins.has_family(StringName(new_id)),
				"%s is what %s became, so the table has to actually carry it" % [new_id, old])
		if err == "":
			err = _T.assert_eq(Skins.current_family_id(String(old)), new_id,
				"current_family_id maps %s forward" % old)
		if err == "":
			# IDEMPOTENT, and it has to be: `_save` writes what `_load` produced, and a
			# map applied twice that moved twice would rename a family every launch.
			err = _T.assert_eq(Skins.current_family_id(new_id), new_id,
				"and leaves %s where it is when asked again" % new_id)
	if err == "":
		err = _T.assert_eq(Skins.current_family_id("verdigris"), "verdigris",
			("a family this build has never had comes back unchanged -- a save from a "
				+ "LATER build names one, and guessing it onto a known family would hand "
				+ "out a skin nobody bought"))
	if err == "":
		# The titles moved with the ids. Asserted through `title_of` rather than by
		# reading the row, so the lookup a screen actually calls is the one under test.
		err = _T.assert_eq(Skins.title_of(&"plate"), "Botanical Plate", "the plate's label")
	if err == "":
		err = _T.assert_eq(Skins.title_of(&"cutpaper"), "Cut Paper", "cut paper's")
	if err == "":
		err = _T.assert_eq(Skins.title_of(&"sampler"), "Linen Sampler", "and the sampler's")
	return err


## The two rename functions, over the two shapes the save actually carries.
##
## Static and pure on both sides, so this needs no file, no autoload state and no scene --
## which is the whole reason they are `static func`s over the parsers' output rather than
## a rewrite of the line's text.
func test_the_family_rename_maps_both_save_lines_and_leaves_a_stranger_alone() -> String:
	var plant_key: String = Skins.selection_key(Skins.KIND_PLANT, PlantCatalog.ids()[0])
	var pest_key: String = Skins.selection_key(Skins.KIND_PEST,
		StringName(Pest.SPECIES.keys()[0]))

	# The `s` line: one value per key, and the KEYS must not move -- no target was
	# renamed, only the family a target wears.
	var selections: Dictionary = RunConfig.rename_selected_families(
		{plant_key: "golden", pest_key: "verdigris"})
	var err: String = _T.assert_eq(String(selections.get(plant_key, "")), "plate",
		"a worn family is renamed forward")
	if err == "":
		err = _T.assert_eq(String(selections.get(pest_key, "")), "verdigris",
			"and one this build has never heard of is left exactly as it was found")
	if err == "":
		err = _T.assert_eq(selections.keys().size(), 2, "with both rows still present")

	# The `u` line: a LIST per key, sorted on the way out. `ember,golden` arrives sorted
	# and `sampler,plate` is not, so a rename that only mapped would hand the writer a
	# list in the wrong order and make a migrated save differ from a freshly bought one
	# over nothing.
	if err == "":
		var purchases: Dictionary = RunConfig.rename_purchased_families(
			{plant_key: ["ember", "golden"]})
		var want: Array[String] = ["plate", "sampler"]
		err = _T.assert_eq(purchases.get(plant_key, []), want,
			"a wardrobe is renamed AND re-sorted: %s" % [purchases])
	if err == "":
		# A file carrying both an old id and its new one. No writer produces it and a
		# text editor can; `parse_purchase_line` refuses a duplicate, so collapsing it
		# here is what stops `_save`'s readback failing for the rest of the session.
		var collapsed: Dictionary = RunConfig.rename_purchased_families(
			{plant_key: ["golden", "plate"]})
		var one: Array[String] = ["plate"]
		err = _T.assert_eq(collapsed.get(plant_key, []), one,
			"an old id beside its own new one collapses to one entry, not two")
	if err == "":
		var stranger: Dictionary = RunConfig.rename_purchased_families(
			{pest_key: ["verdigris"]})
		var kept: Array[String] = ["verdigris"]
		err = _T.assert_eq(stranger.get(pest_key, []), kept,
			"and an unknown family is kept verbatim rather than mapped onto a known one")
	if err == "":
		# Whatever the rename produces has to be writable by the line it feeds, or the
		# migration lands and the save that records it fails silently.
		var line: String = RunConfig.compose_purchase_line(
			RunConfig.rename_purchased_families({plant_key: ["ember", "golden"]}))
		err = _T.assert_eq(line, "u1 %s=plate,sampler" % plant_key,
			"and the result composes into a wardrobe line: %s" % line)
		if err == "":
			err = _T.assert_true(RunConfig.parse_purchase_line(line) != null,
				"which this build's own reader accepts")
	return err


## Every family title still fits the row button the Skins screen draws it in.
##
## THE SHOP ABSORBS A LONGER TITLE AND THIS SCREEN DOES NOT, which is why the rename
## needed a measurement rather than a look. `ShopScreen` derives every column from
## `GardenTheme.measure`, so "Botanical Plate" widened its paper with nothing edited.
## `SkinsScreen`'s row button is the shared `OverlayScreen.ROW_BUTTON_SIZE` -- a flat
## 150 -- and `Control.set_size` clamps to `get_combined_minimum_size()`, so a title too
## wide for 150 does not clip: it makes the button WIDER than the slot laid out for it.
##
## Measured through the theme rather than counted in characters. "Botanical Plate" is two
## characters longer than "Heirloom Gold" and only about five pixels wider, because the
## letters it gained are narrow ones -- a character count cannot tell those apart, and
## `Label.get_minimum_size()` is no use either on the `clip_text` labels beside it.
##
## THE BUDGET IS THE PANEL, not the 150. The 150 is what is reserved; the panel is what
## is enforced (`_overlay_content_fits_and_stands_clear` asks `panel.encloses`). What
## this deliberately cannot see is the right margin a slightly-too-wide button eats on
## its way there -- see `SkinsScreen`'s note on BUTTON_X for why that is a shape change
## and not a wider constant.
func test_a_family_title_still_fits_the_row_button_it_is_drawn_in() -> String:
	# The real Button, wearing the real look, asked for its own minimum -- rather than
	# the text width plus a hand-copied 14+14 content margin and the focus box's 2+2
	# expand. A number transcribed out of GardenTheme is a number that stops being true
	# the day the theme changes and nothing says so.
	var probe := Button.new()
	GardenTheme.style_paper_button(probe)
	var budget: float = SkinsScreen.PANEL.size.x - SkinsScreen.BUTTON_X
	var err: String = _T.assert_gt(Skins.FAMILIES.size(), 0,
		"there are titles to measure, or this sweep passes over nothing")
	var measured: int = 0
	for row: Dictionary in Skins.FAMILIES:
		if err != "":
			break
		probe.text = String(row["title"])
		var needed: float = probe.get_combined_minimum_size().x
		# A zero would mean no font resolved and every assertion below is vacuous --
		# `GardenTheme.measure` answers 0.0 in exactly that case, deliberately, and the
		# same hole is open here.
		err = _T.assert_gt(needed, 0.0,
			("%s measured to nothing -- a 0 means no font resolved, and every assertion in "
				+ "this sweep is then vacuous") % row["title"])
		if err == "":
			measured += 1
			err = _T.assert_true(needed <= budget,
				("\"%s\" needs %.0fpx in a button the Skins screen gives %.0fpx of panel "
					+ "(BUTTON_X %.0f of a %.0f-wide paper). Every column on ShopScreen is "
					+ "measured and absorbed this; SkinsScreen's row button is a flat "
					+ "constant and cannot. The fix is ShopScreen's shape -- derive the "
					+ "column and the panel width from the corpus -- not a wider number "
					+ "here.") % [row["title"], needed, budget, SkinsScreen.BUTTON_X,
						SkinsScreen.PANEL.size.x])
	probe.free()
	if err == "":
		err = _T.assert_eq(measured, Skins.FAMILIES.size(),
			"every family title was measured, not just the ones before a break")
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
	_stage_shop("user://test_skins_mirror.save",
		_purse_for(Skins.PRICES[Skins.KIND_PLANT] as Dictionary))
	SaveMirror.force_store = {}
	RunConfig.campaign_high_score = 4242
	var plant: StringName = PlantCatalog.ids()[0]

	var err: String = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PLANT, plant, &"plate"),
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
		RunConfig.wallet = Currency.add(Currency.empty_wallet(), Currency.PETALS, 77)
		RunConfig.purchased_skins = {}
		RunConfig.campaign_high_score = 0
		RunConfig._load()
		err = _T.assert_eq(RunConfig.load_status, "mirrored",
			"the load says where it got the bytes, got %s" % RunConfig.load_status)
	if err == "":
		err = _T.assert_true(RunConfig.owns_skin(Skins.KIND_PLANT, plant, &"plate"),
			"the purchase came back off the mirror")
	if err == "":
		err = _T.assert_true(_purse_is_empty(),
			"and so did the spent wallet: %s" % RunConfig.wallet)
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
	_stage_shop("user://test_skins_plant_tint.save",
		_purse_for(Skins.PRICES[Skins.KIND_PLANT] as Dictionary))
	var kind: StringName = PlantCatalog.ids()[0]
	var err: String = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PLANT, kind, &"plate"),
		"plate is bought for the plant this test places")
	if err == "":
		err = _T.assert_true(RunConfig.set_skin(Skins.KIND_PLANT, kind, &"plate"),
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
		err = _T.assert_eq(plant.skin_id, &"plate", "the plant records the skin it was placed with")
	if err == "":
		err = _T.assert_true(plant._sprite != null, "the sprite exists to be painted")
		if err == "":
			var expected: Color = (Color.WHITE if Skins.has_art(&"plate")
				else Skins.tint_for(&"plate"))
			err = _T.assert_eq(plant._sprite.modulate, expected,
				"a family with a drawing of its own is worn WHITE -- the drawing is "
					+ "already the colour")
	if err == "":
		err = _T.assert_eq(plant.frame_texture_path(PlantCatalog.texture_path(kind)),
			Skins.texture_path(PlantCatalog.texture_path(kind), &"plate"),
			"and the frame funnel hands back the skin's own drawing, not the parent's")
	if plant != null:
		plant.free()
	_restore_shop_state(stashed)
	return err


## A PEST skin is still a tint and nothing else, which is why `tint` survived the shop
## on every FAMILIES row -- see `Skins`'s own header.
func test_a_spawned_pest_wears_its_chosen_skins_tint_until_a_mutation_lands() -> String:
	var stashed: Dictionary = _stash_shop_state()
	_stage_shop("user://test_skins_pest_tint.save",
		_purse_for(Skins.PRICES[Skins.KIND_PEST] as Dictionary))
	var species: StringName = Pest.APHID
	var err: String = _T.assert_true(RunConfig.buy_skin(Skins.KIND_PEST, species, &"sampler"),
		"sampler is bought for the species this test spawns")
	if err == "":
		err = _T.assert_true(RunConfig.set_skin(Skins.KIND_PEST, species, &"sampler"),
			"and chosen for it")
	var pest: Pest = null
	if err == "":
		pest = Pest.new()
		pest.setup(species, PackedVector2Array([Vector2(0, 0), Vector2(64, 0)]))
		err = _T.assert_eq(pest.skin_id, &"sampler", "the pest records the skin it spawned with")
	if err == "":
		err = _T.assert_true(pest._sprite != null, "the sprite exists to be tinted")
	if err == "":
		err = _T.assert_eq(pest._sprite.modulate, Skins.tint_for(&"sampler"),
			"and wears exactly the tint Skins.tint_for(sampler) declares")
	if pest != null:
		# A mutation still wins outright once it lands -- the same priority
		# apply_mutation() gives two mutations composing onto one tint.
		err = _T.assert_true(pest.apply_mutation(Pest.MUTATION_ARMOURED),
			"the mutation applies cleanly onto a skinned, unmutated pest")
	if err == "":
		err = _T.assert_eq(pest.skin_id, &"sampler", "the skin is still recorded")
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
	pest.set_pest_skin(&"plate")
	var err: String = _T.assert_eq(pest.skin_id, &"plate", "the id is recorded")
	if err == "":
		err = _T.assert_eq(pest._sprite.modulate, Skins.tint_for(&"plate"), "and the tint applied")
	if err == "":
		# Called again with a different id: the sprite follows, not just the field.
		pest.set_pest_skin(&"cutpaper")
		err = _T.assert_eq(pest._sprite.modulate, Skins.tint_for(&"cutpaper"),
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
	_stage_shop("user://test_skins_screen_press.save", Currency.empty_wallet())
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
