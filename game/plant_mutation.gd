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

## The suffix that turns a plant sprite's path into its sport's.
##
## One spelling, three readers: `tools/gen_sport_svg.py` appends it when it writes the
## seventeen derived SVGs, `test_sprite_style.gd` keys MUTANT_PALETTE off it, and this
## file resolves a texture with it. That tool checks the gate's copy against its own on
## every run, and `test_selftest.gd` checks this one against both.
const SPORT_SUFFIX := "_sport"


## What a sport's sprite is multiplied by, and it is WHITE deliberately.
##
## This used to be Color(1.10, 0.88, 1.16) -- a 12% violet shift over the parent's own
## drawing -- and the whole of the sport's colour cue. It was a cue you could only read by
## holding a sport next to its own parent, which is the one comparison a player standing
## over a 14x9 garden is least likely to make.
##
## A sport now wears its OWN art (`sport_texture_path` below), acid green where the parent
## was green and hot magenta where it was gold or red, and there is nothing left for a
## multiplier to add. Multiplying a tint over an already-recoloured sprite does not make it
## more dramatic; it desaturates toward whatever the tint's own hue is, which is how three
## deliberate hues become one muddy one.
##
## It also settles what a sport does with a chosen SKIN, and settles it the same way the
## tint did: the skin is not applied. A sport is the run's own state -- this instance is a
## mutated survivor, and it is gone the moment CrossBreeder throws a different one -- so it
## must not be a colour the player has to go and un-pick on the Skins screen to see.
const SPORT_MODULATE := Color.WHITE


## The sport's drawing for a plant sprite path, or the same path back for a kind with no
## derived art.
##
## Pure and path-shaped rather than a table, because a plant does not have ONE sprite: the
## Bramble swaps between three by health, the Dandelion between four by fluff count, and
## the Chomp between four by what it is doing. Every one of those has a sport, generated
## from it by `tools/gen_sport_svg.py`, and a table keyed by PLANT would have covered the
## nine standing frames and quietly left a mutated Chomp reverting to unmutated colours the
## moment it bit something.
static func sport_texture_path(base_path: String) -> String:
	if base_path.is_empty():
		return base_path
	var stem: String = base_path.get_basename()
	if stem.ends_with(SPORT_SUFFIX):
		return base_path
	return "%s%s.%s" % [stem, SPORT_SUFFIX, base_path.get_extension()]


## The path a plant should actually load: its sport's when it is one, its own otherwise.
##
## The one function every texture assignment in the game goes through (`Plant.frame_texture_path`),
## so "does this frame have a mutant twin" is asked in one place rather than at four
## call sites that each have to remember.
static func texture_path(base_path: String, is_sport: bool) -> String:
	# No node ever carries this script -- it is a `class_name ... extends RefCounted`
	# static utility -- so `scripts-seen` and the verify ledger's `reach` cannot see it
	# however much of it ran. Measured, not assumed: bsxh's runtime pass sprouted four
	# sports, read each one's loaded texture, and drove a sport Bramble through all three
	# damage frames, and the ledger still recorded this file as unreachable by
	# construction. `texture_path` is the funnel every sprite in the game goes through
	# (`Plant.frame_texture_path`), so marking it once is enough. Same shape and same
	# reason as `GameSpeed._apply`.
	DevTools.mark_script_reached("res://game/plant_mutation.gd")
	return sport_texture_path(base_path) if is_sport else base_path


## The sport's BADGE: a hazard trefoil on a disc, pinned to the plant's shoulder and
## painted by `SportMark`.
##
## The art alone is not enough and that is the same lesson the tint taught, one level up: a
## recolour says "this plant is a different colour", and only a MARK says "this plant is a
## different thing". A player who has seen one badge can read every sport on the board
## without learning nine recolours.
##
## A TREFOIL, and not the four-point star this started as. The star said "special" -- the
## vocabulary of a bonus, a rare drop, a favourite -- and a sport is not a reward, it is a
## mutation. The trefoil is the one shape in general circulation that means exactly
## "something here has been changed by something you should not touch", and it is the mark
## a player already knows from a hazard drum. Three blades round a hub is also the more
## legible shape at this size: it has rotational symmetry, so it survives being glanced at,
## where a star's points read as noise once they are under about ten pixels.
##
## Pinned to the RIGHT SHOULDER, and the exact numbers are load-bearing rather than an eye
## judgement. The health bar is a 32x5 rect at y -34 (`Plant.HEALTH_BAR_ORIGIN` /
## `HEALTH_BAR_SIZE`), i.e. x -16..16, y -34..-29, and it carries a quantity the player
## reads off a damaged plant. From (21, -17) the nearest point of that rect is (16, -29),
## exactly 13 px away against a 9 px radius: four pixels of clearance, checked by
## `test_the_sport_badge_stays_clear_of_the_health_bar_and_never_pulses_away`.
##
## This was (17, -25) with a radius of 8, which overlapped the bar by four pixels the whole
## time it shipped. The clearance assertion existed and was correct; the test it sat in
## ended `return ""` instead of `return err`, so it failed on every run and reported a pass.
##
## The badge DOES overlap the selection brackets (`SelectionMarker.LIVE_CORNERS` reach
## +-22), and that is allowed where the bar is not: the brackets are two-pixel decoration
## that says "this one is selected", already known to the player who just clicked it, and a
## badge drawn over a corner of them costs nothing. A bar with its remaining health covered
## is a readout the player cannot get back. An earlier version of this comment claimed
## clearance from both, which was never true of either.
const BADGE_CENTRE := Vector2(21.0, -17.0)
const BADGE_RADIUS: float = 9.0

## Hazard yellow on near-black, which is the trefoil's own colourway and not a decision
## this file is free to make differently -- the mark is only borrowed vocabulary if it is
## borrowed whole.
##
## It is also the pair that works on this board. The badge lands on grass (`#2ECC71`), on
## road (`#BB8044`), and on the sport's own art, which after `gen_sport_svg.py` is acid
## green or hot magenta; a violet disc, which is what this was, sat inside the mutagen
## ramp's own hue and vanished into the plant it was marking. Yellow at this value is the
## one hue on the board nothing else occupies, and near-black is the one value.
const BADGE_FILL := Color(0.93, 0.97, 0.15, 0.96)
const BADGE_RIM := Color(0.07, 0.08, 0.02, 0.98)
const BADGE_RIM_WIDTH: float = 2.0

## The trefoil inside the disc. Three blades and a hub, at the proportions the real mark
## uses: blades run from 1.5x the hub radius to 4x it, each spanning 60 degrees with 60
## degrees of gap, so the yellow between them is as wide as the blades themselves. That
## ratio is what makes the shape readable at a size where the blades are three pixels
## across; drawn thicker it closes into a disc.
const TREFOIL_COLOR := Color(0.07, 0.08, 0.02, 0.98)
const TREFOIL_BLADES: int = 3
const TREFOIL_HUB: float = 1.7
const TREFOIL_INNER: float = 2.55
const TREFOIL_OUTER: float = 6.8
const TREFOIL_SPAN: float = TAU / 6.0

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


## The trefoil inside the badge: `TREFOIL_BLADES` blades, each an annular sector from
## `TREFOIL_INNER` to `TREFOIL_OUTER` spanning `TREFOIL_SPAN`, with the first blade
## pointing up-screen. One polygon per blade, so a caller draws them and nothing else.
##
## Up-screen because `art_src/STYLE.md` makes that the facing of everything directional in
## this kit, and a trefoil rolled a few degrees off is the kind of wrongness a player feels
## without being able to name. The hub is NOT here: it is a disc, `draw_circle` draws it
## exactly, and turning a circle into a polygon to keep the shape in one function would
## make the drawn mark worse to save a line.
##
## Pure, so what `_draw` paints is checkable in a headless run — the same reason
## `badge_ring` above and `Sunflower.gauge_fill_rect` are statics. Headless executes no
## `_draw` at all, so a shape assembled inside one is a shape no test can reach; see
## `.claude/skills/assert-an-animation`.
static func badge_trefoil(segments: int = 6) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var steps: int = maxi(segments, 2)
	for blade: int in range(TREFOIL_BLADES):
		var mid: float = -PI * 0.5 + TAU * float(blade) / float(TREFOIL_BLADES)
		var poly := PackedVector2Array()
		for i: int in range(steps + 1):
			var angle: float = mid - TREFOIL_SPAN * 0.5 + TREFOIL_SPAN * float(i) / float(steps)
			poly.append(BADGE_CENTRE + Vector2.RIGHT.rotated(angle) * TREFOIL_OUTER)
		for i: int in range(steps + 1):
			var angle: float = mid + TREFOIL_SPAN * 0.5 - TREFOIL_SPAN * float(i) / float(steps)
			poly.append(BADGE_CENTRE + Vector2.RIGHT.rotated(angle) * TREFOIL_INNER)
		out.append(poly)
	return out
