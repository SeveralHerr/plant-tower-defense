class_name PlantMutation
extends RefCounted

## The sport. What a plant becomes when two of its kind standing side by side throw
## one into an empty cell beside them (`CrossBreeder`), and the one place in this
## repo that says what "mutated" means for a PLANT.
##
## ---------------------------------------------------------------------------
## WHY A FLAG AND NOT NINE MORE CATALOGUE ENTRIES
##
## The obvious shape — a `popcorn_cobbler` beside `corn_cobbler` in
## `PlantCatalog.PLANTS` — is closed off by the catalogue's own contract.
## `test_plant_order_lists_every_plant_once` asserts `PlantCatalog.ids().size() ==
## PLANTS.size()`, so every entry is in `ORDER`; `ORDER` is what the shop bar lays
## out (`Hud.plant_bar_layout`) and what the title screen hand-places a slot for
## (`game/title_screen.gd:211`). Nine mutants as entries is nine packets nobody can
## ever buy, in a bar sized by counting them.
##
## So a mutant is the SAME KIND wearing a trait, which is exactly the shape `Pest`
## already uses: an armoured aphid is an aphid with `is_armoured`, not a species.
## The two mechanics are now built the same way on both sides of the board, and
## that symmetry is worth more than the file it saves.
##
## ---------------------------------------------------------------------------
## RATE AND POWER, AND WHY THERE ARE EXACTLY TWO OF THEM
##
## Every plant's buff is one number, and the only thing that differs between kinds
## is WHICH number it multiplies. Rather than nine bespoke keys — `interval_scale`,
## `radius_scale`, `resistance_scale` ... — there are two, split by the direction
## "better" points in:
##
##   * `rate`  — multiplies a quantity where LOWER IS BETTER (a firing interval, a
##     chew, a bite-resistance fraction). Always <= 1.0.
##   * `power` — multiplies a quantity where HIGHER IS BETTER (a radius, a heal, a
##     count of Mints). Always >= 1.0.
##
## Exactly one of the two is non-neutral per kind, and the other is exactly 1.0.
## That is not decoration: it is what makes "a sport is strictly better than its
## parent, and only in one respect" a property the suite can check over the whole
## table instead of nine assertions that each have to be remembered
## (`test_every_plant_has_a_sport_and_every_sport_is_strictly_better`). A kind that
## wanted two buffs would be a design change, and it should fail that test on the
## way in rather than arrive as a second quiet key.
##
## WHAT THE NUMBER IS NOT. It is deliberately small — 0.70..0.85 on a rate, 1.25..
## 2.0 on a power. The bead's words were "a slightly different and better effect",
## and a sport is FREE: nothing was spent on it and nothing can be spent to get one.
## A free plant that is twice a bought one makes the shop the wrong move, which is
## the opposite of what a garden mechanic should do to a tower-defense economy.
##
## ---------------------------------------------------------------------------
## THE NAMES ARE LENGTH-BUDGETED, not merely chosen. `Hud.selection_corpus()`
## prices the selection panel against every display name crossed with every rung
## and every detail line, and the panel's width budget is asserted. Every name
## below is no longer than the longest name already in the catalogue ("Barrier
## Bramble", 15 characters), so the sports cost that budget nothing —
## `test_no_sport_name_is_wider_than_the_catalogue_already_is` pins it rather than
## leaving it to the eye.

## The single tint every sport wears, and it is ONE colour for all nine on purpose.
##
## The alternative — a per-kind hue — was refused for the reason `Pest`'s markers
## are the shape they are: a mutation is a piece of VOCABULARY, and a vocabulary
## with nine words for one idea is nine things to learn instead of one. A player
## who has seen a single sport can read every other sport on sight.
##
## Multiplied into `Sprite2D.modulate`, so it shifts a sprite rather than replacing
## it — "different but similar" is the requirement, and a sport that shared no
## colour with its parent would read as a tenth plant. Violet-leaning and slightly
## brighter than white: green foliage cools toward blue and gold warms toward rose,
## which is visible on every sprite in `assets/sprites/` without any of them
## ceasing to be recognisable.
const TINT := Color(1.10, 0.88, 1.16)

## The sport's BADGE: a small disc with a star in it, pinned to the plant's shoulder
## and painted by `SportMark`.
##
## The tint alone is not enough and that was the whole lesson of the pest markers: a
## colour shift is invisible next to a plant of a different KIND, and a player
## comparing a sport to its own parent two cells away is the only reader who would
## ever catch it.
##
## A BADGE rather than the row of three loose diamonds this started as. The diamonds
## were a texture — they read as "something is sparkling here" — where what the cue
## has to say is "this plant is a different THING". A disc with a rim is a shape
## nothing else on this board wears, so it reads as an icon rather than as decoration,
## and it survives being looked at from across a 14x9 garden.
##
## Pinned to the top-right SHOULDER, not centred over the head. Centred, it collides
## with the two things already parked above a plant: the health bar
## (`Plant.HEALTH_BAR_ORIGIN` is y -34, spanning the middle half of the cell) and the
## selection box. Off to one side it never covers either, and it sits where a corner
## badge sits on every other piece of UI a player has ever read.
const BADGE_CENTRE := Vector2(17.0, -25.0)
const BADGE_RADIUS: float = 8.0
const BADGE_FILL := Color(0.62, 0.36, 0.85, 0.95)
const BADGE_RIM := Color(0.30, 0.16, 0.42, 0.98)
const BADGE_RIM_WIDTH: float = 2.0

## The star inside the disc. Four points, which is the fewest that still reads as a
## star rather than as a blob, and white so it carries at a distance against the
## violet — the badge's whole job is to be legible small.
const STAR_POINTS: int = 4
const STAR_OUTER: float = 5.4
const STAR_INNER: float = 2.1
const STAR_COLOR := Color(1.0, 0.98, 1.0, 0.98)

## kind -> the sport it throws. Keyed by `PlantCatalog` id, and every id must be
## here: `test_every_plant_has_a_sport_and_every_sport_is_strictly_better` walks
## `PlantCatalog.ids()` rather than this table's own keys, so a tenth plant that
## arrives without a sport fails on the way in instead of quietly never mutating.
##
## `note` is the half-sentence a readout may borrow. It says what the buff DOES in
## the player's units, never what it multiplies.
const TABLE: Dictionary = {
	PlantCatalog.CORN: {
		"display": "Popcorn Cobbler",
		"rate": 0.82,
		"power": 1.0,
		"note": "fires faster",
	},
	PlantCatalog.CHOMP: {
		"display": "Snap Flower",
		"rate": 0.80,
		"power": 1.0,
		"note": "chews faster",
	},
	PlantCatalog.SUNFLOWER: {
		"display": "Gold Sunflower",
		"rate": 0.80,
		"power": 1.0,
		"note": "seeds sooner",
	},
	PlantCatalog.SUNDEW: {
		# A DEEPER SLOW and not a wider patch, and the reason is that the wider patch
		# is not available. `StickySundew.wash_polygons` clips each patch's disc out
		# of its neighbours' and states its own invariant for doing so — "equal-radius
		# discs cannot sit inside one another, so a single clip never punches a hole".
		# A sport with a bigger radius makes that sentence false, and the failure is a
		# hole in the drawn wash rather than anything the mechanic would notice.
		#
		# The cut, not the factor: `StickySundew.slow_factor` scales the 0.45 the
		# plant takes OFF, so 1.25 here is 0.55 -> 0.4375. See that method and
		# `MIN_SLOW_FACTOR` beside it, which is the floor that keeps a sport from ever
		# becoming the stun this plant is documented not to be.
		"display": "Tar Sundew",
		"rate": 1.0,
		"power": 1.25,
		"note": "holds harder",
	},
	PlantCatalog.DANDELION: {
		"display": "Burr Dandelion",
		"rate": 0.85,
		"power": 1.0,
		"note": "throws more often",
	},
	PlantCatalog.MINT: {
		# The one row whose `power` is a COUNT rather than a multiplier: a sport Mint
		# is worth two Mints to everything beside it (`Game._refresh_neighbour_buffs`).
		# Kept in the same key anyway, because the property the table is checked for
		# is "higher is better", and 2.0 satisfies it exactly as 1.25 does. What it
		# must NOT be is a third key that only one row uses.
		"display": "Wild Mint",
		"rate": 1.0,
		"power": 2.0,
		"note": "counts twice",
	},
	PlantCatalog.NETTLE: {
		"display": "Iron Nettle",
		"rate": 0.85,
		"power": 1.0,
		"note": "stings more often",
	},
	PlantCatalog.ALOE: {
		"display": "Amber Aloe",
		"rate": 1.0,
		"power": 1.40,
		"note": "mends faster",
	},
	PlantCatalog.BRAMBLE: {
		# RATE, not power, and it is the row that shows why the two keys are split by
		# direction instead of by name. `Bramble.BITE_RESISTANCE` is 0.25 and LOWER is
		# tougher, so the tougher wall multiplies by less than one exactly as a faster
		# cob does.
		"display": "Thorn Bramble",
		"rate": 0.70,
		"power": 1.0,
		"note": "holds longer",
	},
}


static func has(kind: StringName) -> bool:
	return TABLE.has(kind)


static func entry(kind: StringName) -> Dictionary:
	return TABLE.get(kind, {}) as Dictionary


## The sport's name, or the ordinary one for a kind with no row. Falling back to
## the catalogue rather than to "" is the same choice `Milestones.title_of` makes:
## a blank where a name belongs is indistinguishable from a layout bug.
static func display_name(kind: StringName) -> String:
	var row: Dictionary = entry(kind)
	return String(row["display"]) if row.has("display") else PlantCatalog.display_name(kind)


## The multiplier for a quantity where lower is better. 1.0 — a no-op — for a kind
## with no row, so an unmutated plant and an unknown kind both fall through to the
## behaviour the game already had.
static func rate_scale(kind: StringName) -> float:
	return float(entry(kind).get("rate", 1.0))


## The multiplier for a quantity where higher is better.
static func power_scale(kind: StringName) -> float:
	return float(entry(kind).get("power", 1.0))


## The half-sentence a readout may print about what this sport does differently.
static func note(kind: StringName) -> String:
	return String(entry(kind).get("note", ""))


## The badge's outline, as a polygon rather than an arc call.
##
## Pure, so what `_draw` paints is checkable in a headless run — the same reason
## `Sunflower.gauge_fill_rect` is a static rather than a body inside `_draw`. Headless
## executes no `_draw` at all, so a shape assembled inside one is a shape no test can
## reach; see `.claude/skills/assert-an-animation`.
static func badge_ring(segments: int = 20) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		out.append(BADGE_CENTRE + Vector2.RIGHT.rotated(angle) * BADGE_RADIUS)
	return out


## The star inside the badge: `STAR_POINTS` spikes, alternating outer and inner radius,
## with the first spike pointing up-screen.
##
## Up-screen because `art_src/STYLE.md` makes that the facing of everything directional
## in this kit, and a star tilted a few degrees off vertical is the kind of wrongness a
## player feels without being able to name.
static func badge_star() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in range(STAR_POINTS * 2):
		var angle: float = -PI * 0.5 + PI * float(i) / float(STAR_POINTS)
		var radius: float = STAR_OUTER if i % 2 == 0 else STAR_INNER
		out.append(BADGE_CENTRE + Vector2.RIGHT.rotated(angle) * radius)
	return out
