class_name Skins
extends RefCounted

## Every plant and every pest can wear one of a small set of colour skins, purely
## cosmetic and purely player-chosen (plant-tower-defense-ncfv).
##
## This file is the pure data and the rule, the same split `Milestones` already
## draws against `RunConfig`: `Skins` answers "what skins exist and which is X
## unlocked by", `RunConfig.selected_skins` is the persisted per-player choice, and
## `RunConfig.selected_skin()` / `set_skin()` are the one reader and the one writer.
## Nothing here touches a save file, and nothing here is mutable — every function is
## `static` and takes whatever player state it needs (an `earned_milestones`
## Dictionary) as an argument, so the whole table is assertable with no RunConfig,
## no Game and no Control, the same way `Milestones.earned_by` is.
##
## ---------------------------------------------------------------------------
## ONE FAMILY TABLE FOR EVERY TARGET
##
## The obvious shape is one bespoke skin per plant and one per pest — nine-plus-five
## tints to draw, name and gate, and fourteen individual "why does THIS milestone
## unlock THIS plant's colour" justifications, for a feature that is purely
## cosmetic. Instead there is one small table of skin FAMILIES (`FAMILIES` below),
## and every family applies uniformly to every target: picking "Golden" recolours
## whichever plant or pest row it was picked on, the same gold, gated on the same
## milestone, whether that row is the Sunflower or the Aphid.
##
## This is also what makes the feature survive the catalogue growing. `targets()`
## derives the actual plant and pest list from `PlantCatalog.ids()` and
## `Pest.SPECIES.keys()` rather than naming them here, so a species another lane
## adds to either table gets all of `FAMILIES` for free — nobody has to remember to
## add a row to THIS file when the game gains a tenth plant or a sixth pest.
##
## ---------------------------------------------------------------------------
## WHY MILESTONE-GATED, AND WHY THESE THREE MILESTONES
##
## Milestones already exist, are already persisted, and are already "the things a
## run can be the first to do" — see `game/milestones.gd`'s own header, whose first
## rule is "no new gameplay counters". Gating a skin on an existing milestone id
## costs nothing that rule would object to: nothing new is counted, an old flag is
## simply given a second, cosmetic reward. Three families are unlocked this way,
## chosen for breadth rather than difficulty — a finish, a flawless finish, and a
## survived worst-case — rather than one skin per milestone in the table (seven),
## which would be more content than a first cut of a cosmetic feature needs to
## justify. A follow-up can widen FAMILIES without touching anything that reads it,
## since `targets()`, `unlocked_families()` and `tint_for()` all walk the table
## rather than naming its rows.

const KIND_PLANT := &"plant"
const KIND_PEST := &"pest"

## The skin worn from a fresh save, and by any target nobody has spent a milestone
## unlocking a skin for: `Color.WHITE`, i.e. the sprite's own art with nothing
## multiplied over it. Always unlocked — see `is_unlocked()` — and the only skin
## `RunConfig.selected_skin()` ever falls back to.
const DEFAULT_SKIN := &"default"

## id, the label the Skins screen shows, the modulate colour applied over the
## sprite's own art, and the milestone id that unlocks it — "" for DEFAULT_SKIN,
## which is the only family with no unlock condition.
##
## Colours are ordinary `Sprite2D.modulate` multipliers, the same mechanism
## `Pest.MUTATION_TINT` and `PlantMutation.TINT` already use — a value below 1.0
## darkens that channel, above 1.0 brightens it. Chosen to be visibly distinct from
## every mutation/sport tint already in the game (Pest.MUTATION_TINT,
## PlantMutation.TINT) so a skinned plant or pest never reads as a mutated one.
const FAMILIES: Array[Dictionary] = [
	{
		"id": DEFAULT_SKIN,
		"title": "Default",
		"tint": Color(1.0, 1.0, 1.0),
		"unlock_milestone": "",
	},
	{
		"id": "golden",
		"title": "Golden",
		"tint": Color(1.25, 1.05, 0.55),
		"unlock_milestone": "campaign_cleared",
	},
	{
		"id": "frost",
		"title": "Frost",
		"tint": Color(0.72, 0.88, 1.15),
		"unlock_milestone": "unbroken_garden",
	},
	{
		"id": "ember",
		"title": "Ember",
		"tint": Color(1.25, 0.55, 0.45),
		"unlock_milestone": "threat_peak",
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


## Whether `id` is unlocked given this player's earned milestones.
## DEFAULT_SKIN (empty `unlock_milestone`) is always true. An id this build does
## not know is always false — a skin from a newer build sitting in a save is not
## selectable here even if the save still names it as the current choice, which is
## exactly why `RunConfig.selected_skin()` falls back to DEFAULT_SKIN rather than
## trusting a saved id outright.
static func is_unlocked(id: StringName, earned_milestones: Dictionary) -> bool:
	var row: Dictionary = family(id)
	if row.is_empty():
		return false
	var needs: String = String(row.get("unlock_milestone", ""))
	return needs.is_empty() or bool(earned_milestones.get(needs, false))


## Every skin this player can currently pick, in `FAMILIES` order. Always contains
## at least the `DEFAULT_SKIN` row — see `is_unlocked()`.
static func unlocked_families(earned_milestones: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in FAMILIES:
		if is_unlocked(StringName(row["id"]), earned_milestones):
			out.append(row)
	return out


## The next unlocked skin after `current`, cycling back to the first once the list
## is exhausted — what the Skins screen's row button advances through. A locked
## family is simply not in `unlocked_families()`'s output, so this never lands on
## one; an unknown `current` (a foreign id, or one no longer unlocked) is treated as
## sitting before the first row, so cycling from it always reaches DEFAULT_SKIN
## before anything else, never gets stuck, and never raises past the end of a
## one-entry list.
static func next_unlocked(current: StringName, earned_milestones: Dictionary) -> StringName:
	var choices: Array[Dictionary] = unlocked_families(earned_milestones)
	if choices.is_empty():
		return DEFAULT_SKIN
	var at: int = -1
	for i: int in choices.size():
		if StringName(choices[i]["id"]) == current:
			at = i
			break
	var next_index: int = (at + 1) % choices.size()
	return StringName(choices[next_index]["id"])
