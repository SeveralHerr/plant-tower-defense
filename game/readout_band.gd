class_name ReadoutBand
extends RefCounted

## Which radii the plant readouts occupy (plant-tower-defense-xf0b).
##
## ## Why this file exists
##
## Several marks in this game are drawn as a circle centred on a plant's own origin,
## inside that plant's own 64 px cell. Radius is the ONLY thing telling them apart —
## they share a centre, they are all thin arcs of ink, and `OVERLAY_GRAMMAR.md`'s own
## channel table says so: for a ring, the channels are SIZE and CENTRE, and the centre
## is spent. So the radii are a shared, finite resource, and until this file existed
## nobody owned it.
##
## The evidence that this was a real problem rather than a tidiness one: every
## constraint keeping these marks apart was written as a PAIR, by hand, in whichever
## file happened to be under edit at the time, and the pairs were spread over five
## source headers and two test files —
##
##   * `chomp_flower.gd`'s chew ring header argues 22 against "the old 16" and against
##     "26.0, which is where `Sunflower`'s gauge puts its nearest corner";
##   * `chomp_flower.gd`'s fang crown header argues 28 against the petals and against
##     the chew ring;
##   * `selection_marker.gd`'s uproot clock header argues 16 against `HALF` and against
##     the chew ring;
##   * `sole_cover_marks.gd`'s alone ring header argues 31 against `HALF` — and against
##     nothing else, which is the hole this file found;
##   * `test_combat.gd` and `test_placement.gd` then assert nine of those pairs, each
##     one naming its two ends by hand.
##
## N marks written as pairs is N*(N-1)/2 sentences that each have to be remembered.
## Four marks is six pairs and only five of them were ever written down. The one nobody
## wrote is a real overlap, and it is recorded in `test_placement.gd` beside the gate.
##
## ## The rule, in one sentence
##
## **A mark whose ink lies at a fixed distance from the plant's origin is read by that
## distance, so no two such marks that can be worn at once may share it.**
##
## Membership is that sentence and nothing else — no taste, no list of "the important
## ones". A mark is in this family when its ink is at a fixed radius from `Vector2.ZERO`
## in the plant's own space. `NOT_RADIAL` records every mark that a plant's subtree
## paints and this family excludes, with the mechanical reason, and `test_placement.gd`
## asserts that the two together account for every script in a plant's subtree that
## declares a `_draw()`. That is what stops the family being "the marks somebody
## remembered".
##
## ## Why the numbers here are DERIVED and not typed
##
## Not one radius below is written as a literal. Every one is computed from the
## constant the draw call itself reads — `ChompFlower.CHEW_RING_RADIUS`,
## `SelectionMarker.UPROOT_RING_WIDTH`, `SoleCoverMarks.ALONE_RADIUS`, and so on.
##
## That is deliberate, and it is the opposite of what `Glyphs.TABLE` does one directory
## over. `Glyphs` is a CHECKED CACHE: it records a value that also exists as a literal
## somewhere else, and `key_binding_screen.gd:173` refuses to be wired to it precisely
## because wiring would make the agreement assertion compare `Glyphs.BULLET` to
## `Glyphs.BULLET` — one side, no possible failure.
##
## The trap does not apply here, because the claim is not an EQUALITY. Nothing below
## asserts "the chew ring is at 22". The claim is a RELATION between four independently
## authored constants — that their intervals do not intersect — and a relation over
## derived inputs stays able to fail: move any one of the source constants and the gate
## goes red. Retyping the radii here would have created the second copy the glyph table
## is careful to keep, for a check that does not need one; wiring the plants to read a
## band constant FROM here would have been the other error, and a worse one, because
## then "does the chew ring sit inside the band" would be comparing the band to itself.
## Derived inputs, relational claim: two sides, no duplication.

## The band's outer edge. A mark that crosses this is drawing on the neighbouring
## cell's bed, where it reads as a remark about somebody else's plant.
const OUTER: float = Board.CELL * 0.5

## Row keys, named so a reader of `marks()` does not have to guess at the strings.
const NAME := "name"
const OWNER := "owner"
const INNER := "inner"
const OUTER_R := "outer"
## Can this mark's ink appear at ANY angle around the plant? A mark that sweeps is
## angularly total, so for a pair of sweepers "same pixel" reduces to "same radius".
const SWEEPS := "sweeps"
## The angular half-width, measured from `Vector2.UP`, of a mark that does NOT sweep.
## Only read when `SWEEPS` is false.
const HALF_ARC := "half_arc"
## Which plants wear this mark. Empty means every plant does.
const WEARERS := "wearers"


## Every mark this game paints at a fixed radius from a plant's own origin.
##
## Ordered outward, so a reader can see the band fill up.
static func marks() -> Array[Dictionary]:
	# Built as typed locals rather than written inline: `WEARERS` is read back as an
	# `Array[StringName]` and a bare `[]` inside a Dictionary literal is an untyped one.
	var every_plant: Array[StringName] = []
	var chomp_only: Array[StringName] = [PlantCatalog.CHOMP]
	var out: Array[Dictionary] = []
	out.append({
		NAME: "uproot clock",
		OWNER: "res://game/selection_marker.gd",
		INNER: SelectionMarker.UPROOT_RING_RADIUS - SelectionMarker.UPROOT_RING_WIDTH * 0.5,
		OUTER_R: SelectionMarker.UPROOT_RING_RADIUS + SelectionMarker.UPROOT_RING_WIDTH * 0.5,
		SWEEPS: true,
		HALF_ARC: PI,
		WEARERS: every_plant,
	})
	out.append({
		NAME: "chew ring",
		OWNER: "res://game/chomp_flower.gd",
		INNER: ChompFlower.CHEW_RING_RADIUS - ChompFlower.CHEW_RING_WIDTH * 0.5,
		OUTER_R: ChompFlower.CHEW_RING_RADIUS + ChompFlower.CHEW_RING_WIDTH * 0.5,
		SWEEPS: true,
		HALF_ARC: PI,
		WEARERS: chomp_only,
	})
	out.append({
		NAME: "fang crown",
		OWNER: "res://game/chomp_flower.gd",
		INNER: ChompFlower.FANG_RADIUS - fang_ink_radius(),
		OUTER_R: ChompFlower.FANG_RADIUS + fang_ink_radius(),
		# The one mark here that does not sweep: the crown is in the TOP half only,
		# because the sprite's two leaves own the bottom. Its reach is measured off
		# `fang_points()` rather than off FANG_STEP_DEGREES, so a change to how the
		# offsets are laid out cannot leave this stale.
		SWEEPS: false,
		HALF_ARC: fang_half_arc(),
		WEARERS: chomp_only,
	})
	out.append({
		NAME: "alone ring",
		OWNER: "res://game/sole_cover_marks.gd",
		INNER: SoleCoverMarks.ALONE_RADIUS - SoleCoverMarks.RING_WIDTH * 0.5,
		OUTER_R: SoleCoverMarks.ALONE_RADIUS + SoleCoverMarks.RING_WIDTH * 0.5,
		# Dashed, but the dashes are spread over the whole turn, so it can put ink at
		# any angle a second mark might want. Treated as total on purpose: "our dashes
		# happen to fall in your gaps" is not a clearance, it is a coincidence.
		SWEEPS: true,
		HALF_ARC: PI,
		WEARERS: every_plant,
	})
	out.append({
		NAME: "reach ring",
		OWNER: "res://game/plant.gd",
		# The smallest reach any plant draws — the one closest to the band, and so the
		# only one worth holding against it. Derived over the catalogue, so a plant
		# added with a short reach is measured whether or not anyone remembers this.
		INNER: smallest_reach() - Plant.REACH_RING_WIDTH * 0.5,
		OUTER_R: largest_reach() + Plant.REACH_RING_WIDTH * 0.5,
		SWEEPS: true,
		HALF_ARC: PI,
		WEARERS: every_plant,
	})
	return out


## Marks a plant's own subtree paints that are NOT at a fixed radius from its origin,
## each with the mechanical reason. This is the other half of the completeness claim in
## `test_placement.gd`: together with `marks()` it must account for every script under a
## plant that declares a `_draw()`, so a new mark cannot arrive unclassified.
##
## Being here is not a free pass. It means only that RADIUS is not the channel telling
## this mark apart, so this gate has nothing to say about it — three of these five are
## still held against their neighbours by assertions written where they live.
##
## A static rather than a `const` only because the reasons are long enough to need
## joining across lines, which a constant expression cannot do.
static func not_radial() -> Dictionary:
	return {
	"res://game/corn_cobbler.gd":
		"the muzzle fan is projected from FAN_PIVOT behind the cob, not from its "
		+ "origin, so its pips are at a fixed radius from the PIVOT and a moving one "
		+ "from the plant. It is told apart by being a directional spray.",
	"res://game/sunflower.gd":
		"the yield gauge is a rectangle in the lower-left corner. Sunflower's own "
		+ "header names 'straight instead of round, in a corner instead of centred' "
		+ "as two of the three axes it differs on; radius is not its channel.",
	"res://game/sticky_sundew.gd":
		"the sap patch is GROUND, not a readout -- a filled disc the size of the "
		+ "reach, clipped where a neighbour got there first. Its droplets sit on the "
		+ "beads, which move.",
	"res://game/dandelion.gd":
		"the blast preview is centred on the bomb's landing cell, not on the plant.",
	"res://game/plant.gd":
		"Plant._draw() paints only the reach ring, which IS radial and is a row in "
		+ "marks() -- this entry is the same file's second hat, and is why the "
		+ "completeness sweep unions the two rather than partitioning them.",
	}


## How far one tooth's ink reaches from its own centre, rim included.
##
## The crown is dots ON a circle rather than a stroke ALONG one, so what turns it into a
## radius interval is a tooth's radius, not a line's half-width — and the rim counts,
## because the rim is what makes a 1.8 px white dot legible against the sprite.
static func fang_ink_radius() -> float:
	return ChompFlower.FANG_SIZE + ChompFlower.FANG_RIM_WIDTH


## How far round from straight up the crown's ink reaches, in radians — the outermost
## tooth's angle plus the angle that tooth's own body subtends at the crown's radius.
##
## Measured off `fang_points()` at the top level, so this cannot drift from the crown
## that is actually drawn.
static func fang_half_arc() -> float:
	var widest: float = 0.0
	for tooth: Vector2 in ChompFlower.fang_points(ChompFlower.LEVELS.size()):
		widest = maxf(widest, absf(tooth.angle_to(Vector2.UP)))
	return widest + atan2(fang_ink_radius(), ChompFlower.FANG_RADIUS)


## The shortest reach any plant in the catalogue draws a ring at, ignoring the plants
## that reach nothing at all.
static func smallest_reach() -> float:
	var shortest: float = INF
	for id: StringName in PlantCatalog.ids():
		var reach: float = PlantCatalog.reach(id)
		if reach > 0.0:
			shortest = minf(shortest, reach)
	return shortest


static func largest_reach() -> float:
	var longest: float = 0.0
	for id: StringName in PlantCatalog.ids():
		longest = maxf(longest, PlantCatalog.reach(id))
	return longest


## Can these two marks be on ONE plant at ONE time? Two marks on different plants can
## share a radius freely — they never meet a pixel, and the board is read one bed at a
## time. An empty `WEARERS` means "every plant", so it meets everything.
static func co_wearable(a: Dictionary, b: Dictionary) -> bool:
	var left: Array = a.get(WEARERS, [])
	var right: Array = b.get(WEARERS, [])
	if left.is_empty() or right.is_empty():
		return true
	for id: StringName in left:
		if right.has(id):
			return true
	return false


## Do these two marks' angular extents meet? A sweeper meets everything. Two
## non-sweepers are both centred on straight up in this game, so their extents meet
## whenever either is non-zero — stated as a comparison rather than assumed, so a
## future mark anchored somewhere else fails here loudly instead of passing quietly.
static func arcs_meet(a: Dictionary, b: Dictionary) -> bool:
	if bool(a.get(SWEEPS, true)) or bool(b.get(SWEEPS, true)):
		return true
	return float(a.get(HALF_ARC, 0.0)) + float(b.get(HALF_ARC, 0.0)) > 0.0


## How many pixels of radius these two marks share; 0.0 or less when they are clear of
## each other. The whole predicate, as a number rather than a bool, so a failure can
## print how badly and a near miss can be recorded as a measurement.
static func radial_overlap(a: Dictionary, b: Dictionary) -> float:
	var low: float = minf(float(a[OUTER_R]), float(b[OUTER_R]))
	var high: float = maxf(float(a[INNER]), float(b[INNER]))
	return low - high


## Do these two marks collide — same plant, same angles, same radii?
static func collide(a: Dictionary, b: Dictionary) -> bool:
	return co_wearable(a, b) and arcs_meet(a, b) and radial_overlap(a, b) > 0.0


## The unclaimed radius slices left inside the band, as `[inner, outer]` pairs, outside
## the innermost mark and inside `OUTER`.
##
## This is the number the bead was really asking for, and the reason a comment listing
## three radii would not have done: it is not "here are the marks", it is **how much room
## is left**. The answer today is one slice 3.0 px wide and one 1.8 px wide, against a
## ring width of 2.0 px. Two of those five marks arrived in the last thirty cycles.
##
## Everything below the innermost mark is excluded rather than counted as free: that is
## the sprite's own silhouette, and `Node2D` paints `_draw()` UNDER its children, so a
## mark there is not dim, it is gone. Three separate headers in this family record having
## learned that; it is not free space.
static func free_slices() -> Array[Vector2]:
	var used: Array[Vector2] = []
	for mark: Dictionary in marks():
		var inner: float = float(mark[INNER])
		var outer: float = minf(float(mark[OUTER_R]), OUTER)
		if inner < OUTER:
			used.append(Vector2(inner, outer))
	used.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out: Array[Vector2] = []
	var edge: float = -1.0
	for span: Vector2 in used:
		if edge >= 0.0 and span.x > edge:
			out.append(Vector2(edge, span.x))
		edge = maxf(edge, span.y)
	if edge >= 0.0 and OUTER > edge:
		out.append(Vector2(edge, OUTER))
	return out


## The widest slice a new mark could take without moving an existing one.
static func widest_free_slice() -> float:
	var widest: float = 0.0
	for slice: Vector2 in free_slices():
		widest = maxf(widest, slice.y - slice.x)
	return widest
