class_name Nettle
extends Plant

## The specialist. It stings a pest the mutations changed and lets every plain one walk past.
##
## Six plants answer "what happens to the pest in front of me" and one (Mint) answers a
## question about the board. Every one of the six answers it the same way underneath: hit
## whatever is in reach. The Nettle is the first that REFUSES a target, and the refusal is
## the whole design — it is dead weight for seven waves and then it is the only cell on the
## board whose every sting is spent on something that was actually hard to kill.
##
## WHY THE ROLE EXISTS. Mutations start at `WaveDirector.MUTATION_START_WAVE`
## (`game/wave_director.gd:25`) and the garden's answer to them was "more of the same". That
## is worst for the winged one: `ChompFlower._can_grab` refuses a flier outright
## (`game/chomp_flower.gd`, the two `pest.is_winged` guards in `_can_grab`/`_act`, and
## `Game._on_flight_ignored` gives the refusal a sentence),
## so a lane walled in mouths does nothing at all to it. The counter-play that refusal
## implies is a plant that only ever fights the mutations, and nobody had built one.
##
## WHY THE BLURB SAYS SO OUT LOUD. A plant that does nothing for seven waves and is not
## advertised as such is a trap rather than a decision, so `PlantCatalog.PLANTS[NETTLE]`'s
## blurb names the wave and `test_the_nettle_blurb_warns_it_is_dead_weight_before_mutations`
## pins the sentence against `WaveDirector.MUTATION_START_WAVE` rather than against an 8, so
## moving the wave fails the suite instead of quietly making the shop lie.

## How far a sting reaches, in px — 1.75 cells against `Board.CELL` (64).
##
## Deliberately the shortest reach of any plant that damages: CornCobbler.RANGE is 176 and
## Dandelion.RANGE is its throw. A sting lands the instant it is due, with no projectile to
## dodge or outrun (see `_sting`), and something has to pay for that. Reach is what pays: a
## Nettle has to be planted where the mutations will actually come past, which is the same
## decision every other plant makes and a sharper version of it.
const RANGE: float = 112.0

## What one sting takes off, and how often. 3.0 / 0.7 = 4.29 dps.
##
## The number is set against the cheapest thing it stands beside rather than picked. A
## level-1 CornCobbler at this range lands one kernel for 1.0 damage every 0.80s
## (`game/corn_cobbler.gd:49`) — 1.25 dps for 10 seeds, i.e. 0.125 dps per seed. A Nettle is
## 4.29 dps for 40 seeds, i.e. 0.107. **So it is worse per seed than corn against any pest
## corn can also hit**, and it can only hit some of them. That is the property that keeps a
## specialist from being a strict upgrade, and
## `test_the_nettle_never_out_earns_a_cob_per_seed` pins it rather than leaving it in a
## comment where a retune can quietly falsify it.
const STING_DAMAGE: float = 3.0
const STING_INTERVAL: float = 0.7

## A solid full ring at RANGE — the grammar's REACH row (`game/OVERLAY_GRAMMAR.md`), the same
## statement CornCobbler, Dandelion, PlacementPreview and Mint already make, in the same
## shape. Deliberately NOT a new cue: the grammar file says adding a row fails the suite until
## someone decides whether the notebook teaches it, and "this is how far it acts" is exactly
## what the existing row means. A second vocabulary for one statement is how a grammar stops
## being one.
##
## Orange rather than Corn's green, because the sprite is orange and every reach in this game
## is drawn in its own plant's hue. It carries no meaning on its own — the SHAPE is the
## signal, per the two-channel rule at the top of the grammar file.
##
## The alpha is deliberately NOT written here — `Plant.REACH_RING_ALPHA` is the grammar's,
## and a second copy of it is how one plant's ring ends up brighter than the rest. The width
## used to sit beside it as a `RING_WIDTH` of 2.0 and is now `Plant.REACH_RING_WIDTH`, which
## was already the same 2.0 in all five plants that drew this ring.
const RING_COLOR := Color(1.0, 0.40, 0.0, Plant.REACH_RING_ALPHA)

## The sting twitch: a fast squash on the sprite, the same shape `CornCobbler._recoil` plays
## and for the same reason. A sting has no projectile, so without this the ONLY board-level
## evidence that a Nettle did anything is the victim's own hit flash — and that flash looks
## identical to a kernel landing from a cob three cells away.
const STING_SQUASH := Vector2(1.16, 0.86)

## How far the sprite shears toward its victim at the top of a sting, in radians of skew.
##
## STING_SQUASH's header already argues that a sting with nothing in flight needs
## evidence of its own. What it does not give is evidence of WHO — a squash is symmetric,
## so a Nettle stinging a beetle on its left and one on its right looked identical, and
## looked identical to a Nettle stinging nothing while a cob three cells away landed a
## kernel. A shear has a sign, and the sign is the target.
##
## Skew rather than rotation because `_sprite.rotation` is not this class's to write:
## `Plant._sway_pivot` exists precisely so idle motion and event flourishes stop fighting
## over one property, and the sway owns the pivot's angle. Skew is a fourth free channel
## (scale is the event tweens', rotation is the sway's, position is now Chomp's lunge),
## and it is also the better picture: a skewed sprite leans its HEAD at the pest while the
## base stays planted, which is what a stem does and what a rotation about the origin does
## not.
##
## 0.18 rad moves the top of a 64 px sprite about 5.8 px sideways. Bounded on both sides:
## comfortably clear of the idle sway's ~1.8 px, so it does not read as one more breath,
## and comfortably inside the cell — `nettle.svg`'s painted content runs 13.3..50.7 in x,
## so the body reaches 18.7 px from centre and 5.8 more leaves the leading edge at 24.5,
## well under the 32 px half-`Board.CELL`. It lands in the same size class as
## `Plant.FLINCH_RADIANS` (0.16 rad, ~5.1 px at the same height) on purpose: an attack and
## a plant being eaten are both single events worth noticing, and neither should shout
## over the other.
const STING_LEAN_SKEW: float = 0.18

## The prickle spark: the short-lived burst drawn AT the victim, which is the other half
## of "point at it" — the lean says the plant acted, the spark says where it landed.
##
## A fan rather than a ring, and that is the whole directional claim: the spokes are
## centred on the direction the sting travelled, so the burst visibly points back at the
## Nettle that caused it. A symmetric starburst would have been decoration; this is a
## sentence about which plant is responsible, which is the complaint the designer's note
## is actually about.
##
## Built from `Line2D` children rather than a new scene or a new script: a spark is one
## frame of geometry, and a `class_name` file for it would cost an import pass and a
## `test_sprite_style.gd` row for no picture that these spokes cannot draw.
##
## SPARK_LENGTH 11 keeps the whole burst inside the victim's own 64 px cell at the fan's
## extremes; SPARK_SECONDS 0.18 is a hair longer than the 0.15s lean so the spark is still
## on screen as the plant settles back.
const SPARK_SPOKES: int = 5
const SPARK_LENGTH: float = 11.0
const SPARK_FAN_RADIANS: float = 1.05
const SPARK_WIDTH: float = 2.0
## The plant's own orange, the hue RING_COLOR already speaks for this plant.
const SPARK_COLOR := Color(1.0, 0.55, 0.10, 0.95)
const SPARK_SECONDS: float = 0.18

var _cooldown: float = 0.0
## The last sting's direction, in the two forms the two halves of the animation need.
##
## Composed on EVERY sting and ABOVE the animation gate — see `_sting` — for the reason
## `ChompFlower._bite_lunge` spells out: the direction is the part of this that can be
## WRONG, a sign flip renders as a perfectly plausible picture, and everything past
## `GardenTheme.animations_enabled()` is unreachable for every test in the suite by
## construction. These fields are the ONLY source `_sting_twitch` and
## `_spawn_prickle_spark` read, so the recorded direction and the drawn one cannot
## disagree.
var _sting_lean: float = 0.0
var _spark_ends: PackedVector2Array = PackedVector2Array()


## Whether this Nettle may sting `pest` at all.
##
## Asked as "does it carry any mutation", off `Pest.mutations` (`game/pest.gd`, the
## `var mutations: Array[StringName]` declaration — named rather than cited by line because
## that file was gaining a species while this was written and any number here would be stale
## by the commit), and NOT
## as `pest.is_armoured or pest.is_winged`. The bead that asked for this plant named the two
## flags, and a two-flag test is a hand-list that goes stale in one direction only: the day a
## fourth mutation is added, a plant advertised as "stings anything the mutations changed"
## silently stops covering it, the blurb becomes false, and nothing fails. `mutations` is the
## set the roll actually produced (`WaveDirector.MUTATIONS`), so this cannot drift.
##
## `is_hungry` is therefore in scope, which is a real gameplay difference from the bead's
## text and the right one: the hungry mutation is the one that destroys beds outright
## (`Plant.take_damage`'s callers), so a plant that answered the other two and shrugged at
## that one would be answering the easy half of the problem.
##
## Static and taking a Pest rather than reading a field, so the rule is assertable against a
## bare `Pest.new()` with no board, no wave and no frame.
static func can_sting(pest: Pest) -> bool:
	if pest == null or not is_instance_valid(pest):
		return false
	return not pest.mutations.is_empty()


## The candidates, filtered. Kept SEPARATE from choosing among them on purpose.
##
## The bead asked whether a target filter belongs on the plant or on a shared helper, because
## `CornCobbler` picks through `Plant._furthest_along_in_range` and `Dandelion` picks through
## its own `best_target` (`game/dandelion.gd:205`), and a third rule would be the point at
## which "how a plant chooses" wants to be one named thing.
##
## The answer this file lands on is that there is no third rule here, and there does not need
## to be one. "Which pests may I hit" and "which of those do I hit first" are different
## questions, and only the first is new: the second is still `_furthest_along_in_range`,
## unchanged and shared, because leaking a pest costs a life whether it was mutated or not.
## So the filter composes with the existing selector instead of replacing it —
## `_furthest_along_in_range(stingable(pests), RANGE)` — and Dandelion stays the only plant in
## the game with a selection rule of its own.
##
## The reach filter is deliberately left to `_furthest_along_in_range` rather than applied
## here as well, so this function is about the REFUSAL and nothing else, and a test can ask
## "which pests would this plant ever fight" without positioning anything.
static func stingable(pests: Array[Pest]) -> Array[Pest]:
	var out: Array[Pest] = []
	for pest: Pest in pests:
		if can_sting(pest):
			out.append(pest)
	return out


## Damage per second against something it will actually fight. Pure and public because the
## balance claim in STING_DAMAGE's comment is only worth writing down if something executes
## it: `test_the_nettle_never_out_earns_a_cob_per_seed` divides this by the catalogue cost
## and compares it against `CornCobbler.single_target_dps`, so a retune that makes the
## specialist strictly better fails rather than shipping.
static func sustained_dps() -> float:
	return STING_DAMAGE / STING_INTERVAL


## Seconds between stings as this Nettle will actually sting right now — the base interval
## with the sky and the neighbours both folded in, through the one function that composes
## them (`Plant.composed_interval`, `game/plant.gd:150`).
##
## Read through that seam rather than hand-multiplying, which is the whole reason the seam
## exists: `Game._apply_weather` ASSIGNS `fire_interval_scale` on every plant on every weather
## change, so a Mint's buff folded into that field is wiped the next time the weather turns,
## silently, with the plant still firing at the wrong rate. A Nettle standing beside a Mint
## speeds up exactly as a Corn does, and it does so because it reads the same function rather
## than because someone remembered to copy the line.
func sting_interval() -> float:
	return composed_interval(STING_INTERVAL, fire_interval_scale, neighbour_interval_scale)


func _act(delta: float, pests: Array[Pest]) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0.0:
		return
	var target: Pest = _furthest_along_in_range(stingable(pests), RANGE)
	if target == null:
		return
	_sting(target)


## Damage applied straight to the pest, with nothing in flight.
##
## Every other damaging plant in the game spawns a travelling node — a `Kernel`, a `SeedBomb`
## — and both of them can miss: a kernel passes a pest it was aimed at once the pest is far
## enough off the line (`CornCobbler.KERNEL_STEP_DEGREES`'s header does the arithmetic), and a
## bomb lands where the pests were half a second ago. A nettle stings what brushes against it,
## which is both what the plant is and the one thing that makes it worth 40 seeds against a
## flier: a winged pest cannot be held by a Chomp and cannot outrun something with no travel
## time. RANGE is what this is paid for with — see its comment.
##
## `flash_hit()` on a survivor follows `Kernel`'s split exactly (`game/kernel.gd:70-76`): a
## kill already has the corpse swap, the fade and `Sfx.PEST_KILLED`, and without the flash a
## sting that connected and did not kill would look like nothing having happened at all.
##
## `Sfx.NETTLE_STING` is the audible half of the argument `STING_SQUASH` makes visually — a
## sting with no projectile needs evidence of its own, or the only sign a Nettle acted is a
## hit flash indistinguishable from a kernel landing from three cells away. And it
## is a VARIANT rather than a voice of its own: the same soft impact `CORN_FIRED` and
## `PLANT_BITTEN` already wear, pitched up to 1.08 and trimmed to −5.0 so it sits between
## them. Borrowing `CORN_FIRED` itself would have taught the player that a different plant
## acted — that objection is about wearing another cue UNCHANGED, and it does not survive
## the pitch and the volume. See `Sfx.NETTLE_STING`'s comment for the twelfth vendored file
## that was refused, and `Sfx.REPEAT_MS` for why the gate is 200ms and where the number
## came from.
##
## Unguarded, like every other `Sfx.play()` call site: `play()` owns the headless gate and
## the repeat gap, so a guard here would be a second opinion about both.
func _sting(target: Pest) -> void:
	target.take_damage(STING_DAMAGE)
	if target.is_alive():
		target.flash_hit()
	Sfx.play(Sfx.NETTLE_STING)
	_cooldown = sting_interval()
	# Composed here, above both gates, and not inside the two functions that play it:
	# see `_sting_lean`. A sting always knows which way it went, whether or not anything
	# is going to draw it.
	_sting_lean = sting_lean_skew(global_position, target.global_position)
	_spark_ends = spark_spoke_ends(global_position, target.global_position)
	_sting_twitch()
	_spawn_prickle_spark(target)


## How far, and which way, the sprite shears at a victim in that direction — pure, so the
## SIGN is assertable with no board, no frame and no open animation gate.
##
## Scaled by the horizontal component of the direction rather than by its sign alone,
## which is the difference between a lean and a flinch: a pest directly to the right gets
## the full `STING_LEAN_SKEW`, one on the left gets the negative of it, and one straight
## above or below gets nothing, because there is no sideways to lean in. A `sign()` here
## would have made a pest one pixel to the right of dead-ahead produce a full-strength
## lean, and the plant would snap between extremes as a bug walked past its front.
##
## Positive skew leans the sprite's TOP toward +x: Godot's skew rotates the local Y axis,
## so a point at local (0, -h) lands at (h·sin(skew), -h·cos(skew)). Right is positive,
## which is what makes the assertion in `test_a_nettle_leans_at_the_side_its_victim_is_on`
## a statement about the screen rather than about a convention.
static func sting_lean_skew(from: Vector2, to: Vector2) -> float:
	var delta: Vector2 = to - from
	if delta.length_squared() <= 0.0001:
		return 0.0
	return STING_LEAN_SKEW * delta.normalized().x


## The prickle spark's spokes, as end points in the spark's own local space — the spark
## itself is placed ON the victim, so these radiate out from it.
##
## `SPARK_SPOKES` of them, all `SPARK_LENGTH` long, evenly spanning `SPARK_FAN_RADIANS`
## and BISECTED by the direction the sting travelled, so the fan opens away from the
## Nettle and the burst points back at the plant that caused it. Pure and returning
## geometry rather than adding nodes, so "does this point at anything" is one assertion
## on a mean vector instead of a screenshot somebody has to squint at — which is the
## house rule for 2D placement here, where the wrong direction still renders.
##
## Local space and global space share an orientation for this node: a planted bed is
## positioned by `Board` and never rotated or scaled (the sway lives on a child pivot),
## so the spark being parented to the Nettle costs no basis change.
static func spark_spoke_ends(from: Vector2, to: Vector2) -> PackedVector2Array:
	var delta: Vector2 = to - from
	var aim: float = 0.0 if delta.length_squared() <= 0.0001 else delta.angle()
	var ends := PackedVector2Array()
	for i: int in range(SPARK_SPOKES):
		var across: float = 0.0
		if SPARK_SPOKES > 1:
			across = float(i) / float(SPARK_SPOKES - 1) - 0.5
		ends.append(Vector2(SPARK_LENGTH, 0.0).rotated(aim + across * SPARK_FAN_RADIANS))
	return ends


## Gated the way every cosmetic Tween in this project is: headless pumps no frames, so a Tween
## queued here would never run, and `_sprite` is null only before `_build_visuals`.
##
## Scale and skew in parallel and both back together — a lean that arrived after the squash
## had already recovered would read as two separate twitches rather than as one sting.
func _sting_twitch() -> void:
	if _sprite == null or not is_inside_tree() or not GardenTheme.animations_enabled():
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sprite, "scale", STING_SQUASH, 0.05)
	tween.tween_property(_sprite, "skew", _sting_lean, 0.05)
	tween.chain().tween_property(_sprite, "scale", Vector2.ONE, 0.10)
	tween.tween_property(_sprite, "skew", 0.0, 0.10)


## The burst at the victim, which frees ITSELF off the end of its own tween rather than
## leaving anything for a caller to remember — the node exists for `SPARK_SECONDS` and
## there is no other code path that can reach it.
##
## Parented to the Nettle rather than to the board so a plant uprooted mid-sting takes its
## spark with it; a spark orphaned onto the playfield outlives the plant that owns it and
## shows up as exactly the in-tree node growth `performance`'s `Total nodes … growth`
## watches for.
func _spawn_prickle_spark(target: Pest) -> void:
	if not is_inside_tree() or not is_instance_valid(target):
		return
	if not GardenTheme.animations_enabled():
		return
	var spark := Node2D.new()
	spark.name = "PrickleSpark"
	spark.position = to_local(target.global_position)
	spark.scale = Vector2(0.55, 0.55)
	for end_point: Vector2 in _spark_ends:
		var spoke := Line2D.new()
		# Starting a quarter of the way out leaves the victim itself uncovered — a burst
		# drawn over the pest hides the hit flash that is the other evidence of a sting.
		spoke.points = PackedVector2Array([end_point * 0.25, end_point])
		spoke.width = SPARK_WIDTH
		spoke.default_color = SPARK_COLOR
		spark.add_child(spoke)
	add_child(spark)
	var tween := spark.create_tween().set_parallel(true)
	tween.tween_property(spark, "scale", Vector2(1.15, 1.15), SPARK_SECONDS)
	tween.tween_property(spark, "modulate:a", 0.0, SPARK_SECONDS)
	tween.chain().tween_callback(spark.queue_free)


## Drawn only while selected, like every other reach in the game — that gate lives in
## `Plant.draw_reach_ring()` now, along with the reason a ring is not always up.
##
## There is no `_draw()` here any more, and its absence is the point: a Nettle paints nothing
## except its reach, so it inherits `Plant._draw()` and answers the two questions below. That
## also retires the `super._draw()` warning this comment used to carry — there is no override
## left to eat the `SelectionMarker` child's brackets.
func reach_ring_radius() -> float:
	return RANGE


func reach_ring_color() -> Color:
	return RING_COLOR
