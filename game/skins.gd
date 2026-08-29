class_name Skins
extends RefCounted

## Every plant and every pest can wear one of a small set of skins, purely cosmetic and
## purely player-chosen (plant-tower-defense-ncfv). A skin is an art STYLE for a plant
## and a tint for a pest — see the two sections on that below.
##
## This file is the pure data and the rule, the same split `Milestones` already
## draws against `RunConfig`: `Skins` answers "what skins exist, what does one cost
## and does this player own it", `RunConfig.purchased_skins` is the persisted
## wardrobe, `RunConfig.selected_skins` the persisted per-target choice, and
## `RunConfig.buy_skin()` / `set_skin()` are the two writers.
## Nothing here touches a save file, and nothing here is mutable — every function is
## `static` and takes whatever player state it needs (a `purchased` Dictionary) as an
## argument, so the whole table is assertable with no RunConfig, no Game and no
## Control, the same way `Milestones.earned_by` is.
##
## ---------------------------------------------------------------------------
## ONE FAMILY TABLE FOR EVERY TARGET
##
## The obvious shape is one bespoke skin per plant and one per pest — nine-plus-five
## tints to draw, name and price, and fourteen individual "why does THIS skin cost
## THIS much" justifications, for a feature that is purely cosmetic. Instead there
## is one small table of skin FAMILIES (`FAMILIES` below), and every family applies
## uniformly to every target: buying "Botanical Plate" dresses whichever plant or pest
## row it was bought on, the same style, at the same price, whether that row is the
## Sunflower or the Aphid.
##
## OWNERSHIP IS PER TARGET, NOT PER FAMILY, and that is the one place the shop
## deliberately does not follow the table's uniformity. Buying the plate for the
## Sunflower does not dress the Mint: a purchase that covered every row at once
## would be the milestone gate back again under a price tag, and would empty the
## shop in three transactions.
##
## This is also what makes the feature survive the catalogue growing. `targets()`
## derives the actual plant and pest list from `PlantCatalog.ids()` and
## `Pest.SPECIES.keys()` rather than naming them here, so a species another lane
## adds to either table gets all of `FAMILIES` for free — nobody has to remember to
## add a row to THIS file when the game gains a tenth plant or a sixth pest.
##
## ---------------------------------------------------------------------------
## WHY PURCHASED, AND WHY THE MILESTONE GATE WAS REMOVED RATHER THAN KEPT
##
## Until the Petal shop these three families were milestone-gated, one apiece:
## `campaign_cleared` handed out the first, `unbroken_garden` the second, `threat_peak`
## the third. That gate is GONE, not layered under a price, and the reason is arithmetic
## rather than taste. A milestone unlocks a FAMILY, and a family applies to every target
## — so the day a player cleared the campaign, one whole family arrived on all fourteen
## rows at once. With a
## price on top, two thirds of the shop would have been unbuyable on the one day the
## player had most reason to open it, and the rest free. One gate or the other, and
## the one the player can steer is the one worth keeping.
##
## Milestones did not lose their reward, they gained a second: `RunConfig.MILESTONE_PETALS`
## petals apiece, once, so the achievement still feeds the wardrobe — it just buys a skin
## the player picks instead of dictating one.
##
## THE THREE IDS WERE RENAMED AT v12, AND THE RENAME IS A SAVE MIGRATION — see
## `RunConfig.VERSION_WITH_STYLE_SKINS` and `RENAMED_FAMILIES` below. They were `golden`,
## `frost` and `ember`, which are names for COLOURS, and they were right for exactly as
## long as a family WAS a colour: one palette ramp laid over the parent drawing. A family
## is now one art STYLE — an ink plate, cut paper, a linen sampler — and the colour is a
## consequence of the style rather than the thing being bought, so a colour name names the
## wrong fact and the shop row reads as a paint chip.
##
## The IDS and not just the titles, deliberately. A title is what the player reads and
## costs nothing to change; an id is what the SAVE carries, what `texture_path()` spells
## into a filename, and what the art gates scope a palette by. Leaving three colour ids
## under three style titles would have left every one of those saying "golden" about an
## engraving — which is the state a name is in just before somebody trusts it.
##
## A v10 save's `s` line still parses and its selections still survive, exactly as they
## did before; they are simply renamed on the way in now, and are then not selectable
## because nothing is owned yet — see `RunConfig.selected_skin()`, whose fallback to
## DEFAULT_SKIN *is* the v10 -> v11 migration.
##
## ---------------------------------------------------------------------------
## A PLANT SKIN IS A DRAWING, A PEST SKIN IS A TINT
##
## `tint` is still on every row because a pest skin is still exactly what it always was:
## one `modulate` multiplier over the species sprite. A PLANT skin is not — it is a
## generated alternate drawing with its own palette ramp and its own added geometry
## (`tools/gen_skin_svg.py`), rendered to `assets/sprites/` like every other sprite. So a
## row carries `art`, and a plant wearing an `art` family takes the drawing and
## `Color.WHITE`, never both: multiplying a tint over an already-recoloured sprite
## desaturates three deliberate hues into one muddy one, which is the mistake
## `PlantMutation.SPORT_MODULATE` was changed to stop making.
##
## That is also why the two costs differ. Pricing a drawing and a multiplier the same
## would have charged the same for two different things.

const KIND_PLANT := &"plant"
const KIND_PEST := &"pest"

## The skin worn from a fresh save, and by any target the player has not bought one
## for: `Color.WHITE`, i.e. the sprite's own art with nothing multiplied over it.
## Always owned — see `is_owned()` — free — see `cost_for()` — and the only skin
## `RunConfig.selected_skin()` ever falls back to.
const DEFAULT_SKIN := &"default"

## What a plant skin's drawing is called on disk: `sunflower.png` wearing `plate` is
## `sunflower_skin_plate.png`. Written here and derived by `texture_path()` rather
## than typed into any plant script, exactly as `PlantMutation.SPORT_SUFFIX` is — see
## `texture_path()` for what a literal would have cost.
const SKIN_SUFFIX := "_skin_"

## Petals a skin costs, by what the purchase actually buys. A plant skin is a
## generated drawing with its own geometry; a pest skin is a tint. Pricing them the
## same would have charged the same for two different things.
##
## The RATIO is the tuning, not the absolute: a run pays one petal per wave cleared
## and ten per first-time milestone, so a full campaign is roughly two plant skins.
## Five and three keep a pest skin reachable inside a single good run while a plant
## skin is something a player saves toward across two.
const PLANT_SKIN_COST: int = 5
const PEST_SKIN_COST: int = 3

## Every family id this project has retired, and what it is called now. Read by
## `RunConfig`'s v11 -> v12 migration (`VERSION_WITH_STYLE_SKINS`) and by nothing else at
## runtime: a live build only ever writes the right-hand column.
##
## HERE RATHER THAN IN `RunConfig`, because what a family is CALLED is a fact about the
## family — the same split the class header draws between this file and the save. The save
## format owns WHEN to ask; this file owns the answer.
##
## A MAP, NOT A GUESS. An id that is not a key comes back unchanged, and that is the
## behaviour a save from a LATER build needs: it names a family this build has never had,
## it is kept on disk verbatim, and it is refused at the point of USE — `is_owned()`
## answers false and `RunConfig.selected_skin()` falls back to DEFAULT_SKIN, the same
## tolerance `RunConfig.parse_purchase_line` already documents. Reinterpreting an unknown
## id as the nearest known one would dress a player in a skin they never bought, and the
## two high scores sharing that file cannot be re-earned.
##
## IT NEVER SHRINKS. A key deleted here is a wardrobe that stops migrating for every
## player who has not launched the game since v11 — and their `u` line still says
## `golden`, so what they lose is a PURCHASE, not a preference.
const RENAMED_FAMILIES: Dictionary = {
	"golden": "plate",
	"frost": "cutpaper",
	"ember": "sampler",
}


## `id` as THIS build spells it: the current name for a retired id, or `id` unchanged.
##
## Takes and returns a String rather than a StringName because both callers are save
## lines, which are text — converting once at the boundary is cheaper to be right about
## than a StringName round trip at every lookup.
static func current_family_id(id: String) -> String:
	return String(RENAMED_FAMILIES.get(id, id))


## id, the label the Shop and the Skins screen show, the modulate colour applied over
## the sprite's own art, and whether this family has a generated DRAWING of its own.
##
## Colours are ordinary `Sprite2D.modulate` multipliers, the same mechanism
## `Pest.MUTATION_TINT` uses — a value below 1.0 darkens that channel, above 1.0
## brightens it. Chosen to be visibly distinct from `Pest.MUTATION_TINT` so a skinned
## pest never reads as a mutated one.
##
## `tint` IS READ BY PESTS AND BY NOTHING ELSE. `Pest.set_pest_skin` (`game/pest.gd`) is
## its one live caller; every plant path goes through `has_art()` and takes the generated
## DRAWING with `Color.WHITE` over it. It stays on all three `art` rows all the same,
## because a pest skin has no generated art to take instead — there are no `_skin_`
## drawings for the five species, so the multiplier is the whole of what a pest buys.
##
## Said out loud here because the SHAPE invites the opposite reading: a row carrying both
## a `tint` and an `art` looks like a row that means both, and a plant that took both is
## exactly the defect this table was rebuilt to stop — multiplying a tint over an
## already-recoloured sprite desaturates three deliberate hues into one muddy one. See
## the class header, and `PlantMutation.SPORT_MODULATE` for the same argument the first
## time this project made the mistake.
##
## So the three colours below are PEST colours, and they no longer have to agree with the
## style their family draws for a plant — an engraving has no hue to match. Staying
## visibly distinct from `Pest.MUTATION_TINT`, so a skinned pest never reads as a mutated
## one, is the only constraint left on them.
##
## `unlock_milestone` is GONE rather than emptied. A row with an unused key is a row
## the next reader has to be told is unused; see the class header for why the gate
## went instead of sitting under a price.
##
## THE TITLES NAME THE STYLE, and at v12 so do the ids. "Golden"/"Frost"/"Ember" named a
## tint; "Heirloom Gold"/"Hoarfrost"/"Cinder" named a made thing but still named it by
## its colour. These three name the TECHNIQUE the drawing is made with, which is what a
## player who owns all three actually has: three visibly unrelated renderings of the same
## plant, not three paint jobs. `RENAMED_FAMILIES` above carries the old spellings forward
## out of a save; nothing in a live build writes them.
const FAMILIES: Array[Dictionary] = [
	{
		"id": DEFAULT_SKIN,
		"title": "Default",
		"tint": Color(1.0, 1.0, 1.0),
		"art": false,
	},
	{
		"id": &"plate",
		"title": "Botanical Plate",
		"tint": Color(1.25, 1.05, 0.55),
		"art": true,
	},
	{
		"id": &"cutpaper",
		"title": "Cut Paper",
		"tint": Color(0.72, 0.88, 1.15),
		"art": true,
	},
	{
		"id": &"sampler",
		"title": "Linen Sampler",
		"tint": Color(1.25, 0.55, 0.45),
		"art": true,
	},
]


## Every plant kind a skin can be picked for. `PlantCatalog.ids()`'s own order, not
## a copy of it kept here to drift out of step.
static func plant_ids() -> Array[StringName]:
	return PlantCatalog.ids()


## Every pest species a skin can be picked for. Read off `Pest.SPECIES.keys()`
## directly rather than a list kept here — see the class header for why: a species
## another lane adds shows up on the Skins screen the moment it exists in that
## table, with nothing here to edit.
static func pest_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: Variant in Pest.SPECIES.keys():
		out.append(StringName(id))
	return out


## Whether `kind`/`id` names a real target — a plant or pest this build actually
## has — rather than a stale id a save carries forward from a build with more of
## either. `RunConfig.set_skin()` refuses at the door on this.
static func has_target(kind: StringName, id: StringName) -> bool:
	if kind == KIND_PLANT:
		return PlantCatalog.has(id)
	if kind == KIND_PEST:
		return Pest.SPECIES.has(id)
	return false


## Every (kind, id) pair the Skins screen draws a row for: plants first, in
## `PlantCatalog`'s own order, then pests, in `Pest.SPECIES`'s own order.
static func targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in plant_ids():
		out.append({"kind": KIND_PLANT, "id": id})
	for id: StringName in pest_ids():
		out.append({"kind": KIND_PEST, "id": id})
	return out


## The key `RunConfig.selected_skins` and the save's skin line index a choice by.
## ":" is not among `RunConfig.MILESTONE_ID_CHARS`, so it is an unambiguous
## separator between a kind — always exactly "plant" or "pest" — and a target id
## that never contains one, even though several target ids contain "_"
## (`corn_cobbler`, `shieldbug`'s siblings) which would make "_" itself ambiguous.
static func selection_key(kind: StringName, id: StringName) -> String:
	return "%s:%s" % [String(kind), String(id)]


## The FAMILIES row for a skin id, or `{}` for an id this build does not know —
## which a save from a newer build can carry, the same tolerance
## `Milestones.entry()` extends to a foreign milestone id.
static func family(id: StringName) -> Dictionary:
	for row: Dictionary in FAMILIES:
		if StringName(row["id"]) == id:
			return row
	return {}


static func has_family(id: StringName) -> bool:
	return not family(id).is_empty()


## The label the Skins screen shows. Falls back to the raw id, the same choice
## `Milestones.title_of` makes for an id its own table does not carry, so a row
## from a newer build's family never renders blank.
static func title_of(id: StringName) -> String:
	var row: Dictionary = family(id)
	return String(row["title"]) if row.has("title") else String(id)


## The modulate colour for a skin id. White — i.e. no visible change — for
## DEFAULT_SKIN and for any id this build does not recognise, matching the
## "unknown reads as off" contract `Pest.tint_for` already uses for an unknown
## mutation.
static func tint_for(id: StringName) -> Color:
	var row: Dictionary = family(id)
	if not row.has("tint"):
		return Color.WHITE
	return row["tint"]


## Whether this family has a generated DRAWING of its own, as opposed to being a bare
## `modulate` multiplier. False for DEFAULT_SKIN and for an id this build does not
## know, matching the "an unknown reads as off" contract `tint_for` already uses.
static func has_art(id: StringName) -> bool:
	return bool(family(id).get("art", false))


## What `family` costs for a target of this `kind`, in petals.
##
## Keyed on the KIND rather than on the row, because the price is a fact about what
## the purchase gets you — a drawing or a multiplier — and that is decided by whether
## the target is a plant or a pest, not by which of the three families it is. A
## per-row price would also mean three numbers to re-argue every time a family joins
## the table.
##
## Zero for DEFAULT_SKIN, which nobody buys, and zero for a family this build does not
## know. The second is not a free skin: `RunConfig.buy_skin()` refuses an unknown
## family at the door, before it ever asks the price, exactly as `set_skin()` refuses
## an unknown target. Answering 0 here rather than erroring keeps this readable from a
## shop row built off a save from a newer build.
static func cost_for(kind: StringName, id: StringName) -> int:
	if id == DEFAULT_SKIN or not has_family(id):
		return 0
	return PEST_SKIN_COST if kind == KIND_PEST else PLANT_SKIN_COST


## Every family the shop draws a buy button for: FAMILIES minus DEFAULT_SKIN.
##
## Derived by dropping the one row rather than by a second list, so a family added to
## FAMILIES appears in the shop with nothing here to edit — the same rule `targets()`
## follows for the catalogue (`.claude/skills/derive-the-list`).
static func buyable_families() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in FAMILIES:
		if StringName(row["id"]) != DEFAULT_SKIN:
			out.append(row)
	return out


## The drawing a plant frame wears under a skin.
##
## PURE PATH TRANSFORM, exactly like `PlantMutation.sport_texture_path` and for exactly
## its reason: a plant does not have ONE sprite. The Bramble swaps between three by
## health, the Dandelion between four by fluff count, the Chomp between four by what it
## is doing, and every one of those has a skin generated from it. A table keyed by
## PLANT would have covered the standing frames and quietly left a skinned Chomp
## reverting to unskinned art the moment it bit something.
##
## And never a literal in a plant script or in `PlantCatalog`: `gen_sport_svg.plant_stems()`
## derives its stem list from those two places, so a skin path written down there would
## make the sport generator demand a `_sport` twin of every skin — fifty-one files for
## nothing.
##
## Returns `base_path` unchanged for DEFAULT_SKIN, for a family this build does not
## know, for a family with no art (a pest skin is a tint, and there is no drawing to
## point at), for the empty path, and for a path that already carries a skin suffix —
## the last so calling this twice is the same as calling it once.
static func texture_path(base_path: String, skin_id: StringName) -> String:
	if base_path.is_empty() or skin_id == DEFAULT_SKIN or not has_art(skin_id):
		return base_path
	var stem: String = base_path.get_basename()
	if stem.contains(SKIN_SUFFIX):
		return base_path
	return "%s%s%s.%s" % [stem, SKIN_SUFFIX, String(skin_id), base_path.get_extension()]


## Whether this player owns `family` FOR THIS TARGET.
##
## `purchased` is `RunConfig.purchased_skins`: `selection_key(kind, id)` -> the list of
## family ids bought on that row. Passed in rather than read off RunConfig, like every
## other function here, so the whole rule is assertable with no autoload.
##
## DEFAULT_SKIN is always owned — it is the sprite's own art, there is nothing to buy —
## and a family this build does not know is never owned, however the save spells it. A
## purchase from a newer build sitting in `u` is therefore kept on disk and simply not
## selectable, the same tolerance `parse_purchase_line` extends to a foreign id.
static func is_owned(kind: StringName, id: StringName, family_id: StringName,
		purchased: Dictionary) -> bool:
	if family_id == DEFAULT_SKIN:
		return true
	if not has_family(family_id):
		return false
	var owned: Variant = purchased.get(selection_key(kind, id), [])
	if not (owned is Array):
		return false
	for entry: Variant in (owned as Array):
		if StringName(entry) == family_id:
			return true
	return false


## Every skin this player can currently wear on this target, in `FAMILIES` order.
## Always contains at least the `DEFAULT_SKIN` row — see `is_owned()`.
static func owned_families(kind: StringName, id: StringName,
		purchased: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in FAMILIES:
		if is_owned(kind, id, StringName(row["id"]), purchased):
			out.append(row)
	return out


## The next owned skin after `current` on this target, cycling back to the first once
## the list is exhausted — what the Skins screen's row button advances through. An
## unowned family is simply not in `owned_families()`'s output, so this never lands on
## one; an unknown `current` (a foreign id, or one that was never bought here) is
## treated as sitting before the first row, so cycling from it always reaches
## DEFAULT_SKIN before anything else, never gets stuck, and never raises past the end of
## a one-entry list.
static func next_owned(kind: StringName, id: StringName, current: StringName,
		purchased: Dictionary) -> StringName:
	var choices: Array[Dictionary] = owned_families(kind, id, purchased)
	if choices.is_empty():
		return DEFAULT_SKIN
	var at: int = -1
	for i: int in choices.size():
		if StringName(choices[i]["id"]) == current:
			at = i
			break
	var next_index: int = (at + 1) % choices.size()
	return StringName(choices[next_index]["id"])


## What a target is CALLED, as opposed to what its skin is called (`title_of`).
##
## Here rather than on either screen, because both screens draw the same row for the
## same set of targets and had ended up with a copy each — the Skins screen to label a
## row, the Shop to label a row AND to measure the widest one before any Control exists.
## Two copies of a two-branch lookup is two places for a species to start reading as its
## raw id on one screen and its display name on the other; `targets()` already lives
## here, so the name for a target belongs beside it.
##
## Falls back to the raw id for a target this build does not carry, matching the choice
## `title_of` makes for an unknown family — a row from a save a newer build wrote never
## renders blank.
static func display_name(kind: StringName, id: StringName) -> String:
	if kind == KIND_PLANT:
		return PlantCatalog.display_name(id)
	var stats: Dictionary = Pest.SPECIES.get(id, {}) as Dictionary
	return String(stats.get("display", String(id)))
