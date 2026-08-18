class_name ChompFlower
extends Plant

## The melee plant. The design doc's words are "eats small pests easily, takes a
## while eating bigger pests", so this is not a damage-per-second tower — it is a
## body blocker.
##
## Grabbing a pest holds it still AND occupies the flower for the whole chew. An
## aphid is gone in under half a second; a beetle ties the mouth up for two and a
## half, during which every other bug in the lane walks straight past. A player
## who fills a lane with Chomps has a lane full of busy mouths and nothing
## shooting, which is the entire rock-paper-scissors of the game.

## Must exceed one cell: a Chomp stands on grass and the pest walks the road, so
## the closest they ever get is exactly CELL apart. At 62 the flower could not
## reach the lane beside it and never ate anything — with no error anywhere,
## because "found no prey" and "there is no prey" look identical. Kept under two
## cells so it still only covers the lane it is actually next to.
const GRAB_RADIUS: float = Board.CELL * 1.15

## The mouth's ladder — the second one in the game, and the first that is not the
## cob's (see `Plant.upgrade_ladder` for the surface this fills in).
##
## Both stats are SCALES of this class's own constants rather than absolute numbers,
## so level 1 is the flower that shipped, exactly, by construction rather than by a
## pair of numbers someone has to keep in step with `GRAB_RADIUS` and the pest table.
## `PlantCatalog.reach(CHOMP)` still answers `GRAB_RADIUS` and is still right: it is
## asked before anything is planted, and every flower is planted at level 1.
##
## What a level buys, and why it is a behaviour rather than a bigger number:
##
##   * `reach_scale` — 1.15 -> 1.30 -> 1.45 cells (73.6 -> 83.2 -> 92.7 px). Still
##     under two cells at the top, which is the rule GRAB_RADIUS's header states: a
##     Chomp covers the lane it is beside and never the one after it. The player sees
##     a mouth close on a bug it used to let past.
##   * `chew_scale` — the meal itself, not the plant's own clock. A Chomp's real cost
##     is the mouth being shut (see this class's header), so the only upgrade worth
##     buying for a body blocker is one that gives the lane back sooner: a beetle goes
##     2.6s -> 2.08s -> 1.69s, an aphid 0.45s -> 0.29s.
##
## Deliberately gentle at the top, and this is the one number in the table that is a
## balance decision rather than an arithmetic one. `Pest.SPECIES[QUEEN]`'s 11-second
## chew is documented at `game/pest.gd:145` as the trade for eating a queen at all —
## "the whole rest of the wave walking past a shut mouth". At 0.65 that is 7.15s, which
## is still most of a wave, so the trade survives the ladder rather than being bought
## out of it. A `chew_scale` near 0.4 would have deleted it.
##
## Both columns move the same way at every rung and neither can reverse — reach only
## grows, chew only shortens — so level N grabs everything level N-1 would have grabbed
## and finishes sooner, at every distance, against any pest. That is the same "there is
## no configuration in which upgrading can lose" property `CornCobbler.KERNEL_STEP_DEGREES`
## spends thirty lines establishing, and here it is free because the table is monotone;
## `test_combat` pins it anyway, because free is not the same as checked.
##
## Costs: 25 then 45, against corn's 20 then 45. A Chomp costs 15 to plant where a cob
## costs 10, and a ladder on a dearer plant opening dearer is the same gradient
## `PlantCatalog` already prices tiers on. 45 stays the dearest single upgrade in the
## game rather than being beaten by a new one.
##
## The names are NOUNS, like the cob's "single / triple / bunch" and unlike the
## adjectives that first went in here. `Hud.upgrade_message` puts the level name in a
## sentence ("... is now a %s."), and a sentence is what makes "gaping" wrong and
## "gaping maw" right — the selection panel would have taken either.
const LEVELS: Array[Dictionary] = [
	{"name": "bud", "chew_scale": 1.00, "reach_scale": 1.00, "upgrade_cost": 25},
	{"name": "toothy maw", "chew_scale": 0.80, "reach_scale": 1.13, "upgrade_cost": 45},
	{"name": "gaping maw", "chew_scale": 0.65, "reach_scale": 1.26, "upgrade_cost": 0},
]

## Radius of the "mouth full" ring. **Fixed**, and the arc's swept ANGLE carries the
## progress — the idiom `HuskLayer` has used since the husks existed
## (`game/husk_layer.gd:69-77`: a fixed `radius + RING_GAP`, `TAU * frac` of it drawn).
##
## It used to shrink from 16 to nothing instead, and that was backwards. A shrinking
## ring is smallest exactly when its news is most urgent — "the mouth is nearly free"
## is the moment a player decides whether to commit a lane — and `Node2D` paints its
## own canvas below its children, so the last of it disappeared behind the flower's
## own sprite. Two timers in one game had opposite answers and the husk's was the
## better one.
##
## 22 px is pinned between three things, none of them taste:
##   * **above** the old 16, so the arc clears the flower's head rather than being
##     drawn under it (cycle 70 measured a Corn Cobbler pip at 20 px reading leaf
##     green at one aim and its own gold at another);
##   * **below 26.0**, which is where `Sunflower`'s gauge puts its nearest corner —
##     `test_combat` asserts that corner is strictly outside this ring so the two
##     radial-looking readouts never share a pixel;
##   * **below 32**, half a `Board.CELL`, so it stays inside its own cell.
const CHEW_RING_RADIUS: float = 22.0
const CHEW_RING_WIDTH: float = 3.0

## The fang crown: what an upgraded mouth WEARS, always on, whether or not it is
## chewing.
##
## This exists for the reason `CornCobbler`'s muzzle fan exists, and the reason is
## worth restating because it is the whole standard for a ladder in this game: an
## upgrade the board does not show is an upgrade that reads as nothing having
## happened. The cob learned that at 45 seeds a level. A Chomp's two stats are a
## reach and a chew time, and neither of them can be seen on an idle flower — the
## chew ring only appears mid-meal, and a mouth that is not eating anything looks
## identical at every level.
##
## COUNT, not hue, and not size: `level - 1` PAIRS of teeth, so the plain flower
## wears none, and the vocabulary is the one the board already speaks — the health
## bar's notches, `PlacementPreview`'s one-bar/two-bar ground cue.
##
## Geometry, all four of which are constraints rather than taste. A tooth is 5.4 px
## across, rim included, and it has to fit in a band 8 px wide — every number below
## is that band being divided up, which is why they are as specific as they are:
##   * FANG_RADIUS 28 sits OUTSIDE the sprite. `Node2D` paints its own canvas below
##     its children, so anything drawn under the flower is invisible rather than
##     dimmed — the same trap `Sunflower`'s gauge header documents. chomp_flower.svg's
##     nine petals are ellipses centred 17 px out with ry 6 and a 2 px stroke, so the
##     ring of petals ends at r = 24; a tooth's inner edge is at 25.3 and its outer at
##     30.7, inside the 32 px half-cell.
##   * That inner edge also clears the chew ring's outer edge (22 + half of 3 = 23.5),
##     so the two readouts on this one plant can never share a pixel — the same
##     clearance rule `test_combat` already pins between that ring and a Sunflower's
##     gauge.
##   * The crown sits in the TOP half only (±39° from straight up at the top level).
##     The two leaves in the sprite are drawn at 55° and 125° — down-right and
##     down-left — and they reach r = 31, so the bottom half is the only part of this
##     plant that would swallow a tooth at this radius.
##   * FANG_STEP_DEGREES is fixed, and each level adds one PAIR outside the pair
##     below, so level N's angles are a strict superset of level N-1's. Straight from
##     `CornCobbler.KERNEL_STEP_DEGREES`: a readout whose marks MOVE when you pay for
##     it reads as a different thing, not as more of the same thing.
const FANG_RADIUS: float = 28.0
const FANG_STEP_DEGREES: float = 26.0
const FANG_SIZE: float = 1.8
const FANG_RIM_WIDTH: float = 0.9
## The sprite's own tooth white over the maw's own dark red, so the crown reads as
## this flower's teeth rather than as a new object parked beside it — and as neither
## the chew ring's orange nor the cob's gold.
const FANG_COLOR := Color(1.0, 0.98, 0.94, 0.95)
const FANG_RIM_COLOR := Color(0.34, 0.11, 0.08, 0.90)

## The design doc draws a Chomp mid-bite as its own picture, not a tinted idle
## sprite — swapped in for the whole chew and back on release.
const EATING_TEXTURE_PATH := "res://assets/sprites/chomp_flower_eating.png"

## The threshold is a fraction of chew_progress(), the same one the shrinking
## chew ring already reads, so it fires for any pest — an aphid crosses it
## too, just with only ~40% of its already-brief 0.45s chew left to show it,
## which reads as instant either way. A beetle's 2.6s chew is long enough
## that the last ~1s actually gets to show a second picture instead of the
## mouth just staying wide open the whole time.
const LATE_BITE_THRESHOLD: float = 0.6
const EATING_LATE_TEXTURE_PATH := "res://assets/sprites/chomp_flower_eating_late.png"

## How far the mouth throws itself at what it just caught, in px.
##
## The designer's note asked for an attack that READS as an attack, and the answer is a
## direction rather than more scale. A squash is symmetric: (1.18, 0.82) looks identical
## whether the meal is to the left, the right or straight up, so the only board-level
## evidence a Chomp did anything was a pest that stopped moving. Corn has a kernel that
## visibly leaves the plant and travels at somebody; this is the melee version of that
## sentence — the plant, not a projectile, is what moves at the target.
##
## 7 px is bounded on both sides rather than picked. **Above ~4**, or it disappears into
## `Plant.WOBBLE_RADIANS`' idle sway, which already swings the corner of a 64 px sprite
## about 1.8 px and would make the lunge read as one more breath. **Small enough that the
## sprite stays in its own cell**: `chomp_flower.svg`'s painted content runs 8.2..55.8 in
## x, so the body reaches 23.8 px from centre and 7 more puts its leading edge at 30.8,
## inside the 32 px half-`Board.CELL`. A lunging flower therefore never draws itself into
## the neighbouring square, where it would read as a plant standing there.
##
## Note what does NOT travel with it: the chew ring and the fang crown are drawn in this
## node's own `_draw()`, not on `_sprite`, so both stay put while the head moves. That is
## the right split rather than an oversight — they are READOUTS (mouth busy, level bought)
## and a readout that lurches every time the plant acts is harder to read, not livelier.
const LUNGE_DISTANCE: float = 7.0

## The bite's four durations. Declared here rather than taken from `Plant.TWITCH_*`
## because the bite is the one gesture in the family that genuinely does not fit
## either tier: the lunge's out is the twitch's 0.05, but everything else is longer,
## and both channels come home slower than a recoil does. A bite has further to
## travel than a squash — `LUNGE_DISTANCE` above moves the whole head — so it gets
## its own numbers rather than being rounded onto a shared pair it does not match.
##
## The two channels are deliberately staggered by a hundredth of a second in each
## direction, position leading on the way out and lagging on the way back. That is
## what these numbers ALREADY were, preserved exactly. Whether the stagger was ever
## intended or just drifted while nothing named it is a question only a pair of eyes
## on the running game can answer, and no gate in this project can: a duration is
## invisible to lint, to `name_check`, and to a headless suite that pumps no frames.
## Naming them is what makes the question askable at all.
##
## `BITE_SQUASH_OUT_SECONDS` is the outward beat's real length (it is the longer of
## the two outs, and `chain()` below waits for it), so it is the window anything
## swapped in for the duration of the open jaw should be shown for.
const BITE_LUNGE_OUT_SECONDS: float = 0.05
const BITE_SQUASH_OUT_SECONDS: float = 0.06
const BITE_LUNGE_BACK_SECONDS: float = 0.13
const BITE_SQUASH_BACK_SECONDS: float = 0.12

var _held: Pest = null
var _chew_left: float = 0.0
var _chew_total: float = 0.0
var _idle_texture: Texture2D = null
var _eating_texture: Texture2D = null
var _eating_late_texture: Texture2D = null
## Where the last bite threw the mouth, in the sprite's own space.
##
## Composed on EVERY bite and ABOVE the animation gate — `_bite` writes it before it
## returns headless — which is the whole reason it is a field instead of a local. The
## direction is the part of this animation that can be WRONG (a lunge that points away
## from the meal is a perfectly plausible picture, which is this project's documented
## 2D-placement failure mode), and it is unreachable behind `animations_enabled()`,
## false for every test in the suite by construction. Recording it splits "which way
## does the mouth go" from "does a Tween get to play it", and only the second needs a
## frame. `test_a_chomps_bite_records_a_lunge_toward_the_meal` asserts it off `_grab`,
## so deleting the composition from `_bite` goes red rather than silently aiming the
## flower at the origin.
##
## This is the ONLY source the tween below reads, so the field and the picture cannot
## disagree.
var _bite_lunge: Vector2 = Vector2.ZERO


## This flower's ladder. The one override the generic upgrade surface needs — see
## `Plant.upgrade_ladder`.
func upgrade_ladder() -> Array[Dictionary]:
	return LEVELS


## Pure: how far a flower at `for_level` can close its mouth, in pixels. Derived from
## GRAB_RADIUS so level 1 IS GRAB_RADIUS rather than a number that happens to match it.
static func grab_radius_for(for_level: int) -> float:
	return GRAB_RADIUS * float(ladder_row(LEVELS, for_level).get("reach_scale", 1.0))


## Pure: how long a flower at `for_level` takes over a meal whose own chew is
## `base_seconds` (`Pest.chew_seconds`, mutations already applied).
##
## Takes the pest's number as an argument rather than reading a Pest, for the reason
## `Plant.seconds_to_be_eaten` takes a dps: it keeps this file ignorant of the pest
## table, and it makes the test that pins the queen's 11 seconds name the 11.
static func chew_seconds_for(for_level: int, base_seconds: float) -> float:
	return base_seconds * float(ladder_row(LEVELS, for_level).get("chew_scale", 1.0))


## This flower's reach right now — what `_act` and `_nearest_free_pest` both close on,
## so an upgrade cannot widen one without widening the other.
func grab_radius() -> float:
	return grab_radius_for(level)


## Pure: where the crown's teeth sit, in the plant's own space, for a level — one per
## tooth, left to right, empty at level 1.
##
## Pure and public for the reason `CornCobbler.muzzle_pips` is: what gets drawn is then
## checkable without rendering a frame, and the "bare mouth versus a crown of teeth"
## difference a player reads at a glance is one function rather than a condition at the
## draw site.
static func fang_points(for_level: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for offset: float in fang_offsets(for_level):
		out.append(Vector2.UP.rotated(offset) * FANG_RADIUS)
	return out


## Pure: the angles, in radians off straight up and in left-to-right order, that a crown
## at `for_level` puts its teeth on. `level - 1` pairs, each pair one FANG_STEP_DEGREES
## outside the pair below, so every level's set contains every lower level's set.
static func fang_offsets(for_level: int) -> PackedFloat32Array:
	var pairs: int = maxi(0, for_level - 1)
	var out := PackedFloat32Array()
	for k: int in range(pairs, 0, -1):
		out.append(deg_to_rad(-FANG_STEP_DEGREES * (float(k) - 0.5)))
	for k: int in range(1, pairs + 1):
		out.append(deg_to_rad(FANG_STEP_DEGREES * (float(k) - 0.5)))
	return out


## A hungry pest that eats the flower out from under a meal must not leave the
## mouth stuck "busy" pointing at a freed pest.
func _on_setup() -> void:
	destroyed.connect(func(_p: Plant) -> void: release())


## Emitted when this Chomp is sitting still and the reason is flight — see
## `idle_only_because_of_flight`. Rising edge only: the condition is true for every
## frame a winged pest spends crossing the reach, and a per-frame signal would put the
## same sentence on the message row sixty times a second.
##
## Carries nothing. `Game` has the plant in hand from the connection, which is the same
## split `destroyed(plant)` and `grew_seeds` already use here.
signal flight_ignored

## True while `flight_ignored` has already fired for the current stretch of being
## walked past. Cleared when the condition goes false, so the next winged pest to
## arrive is a fresh edge — which is also the retry path when the message row was too
## busy to show the hint the first time.
var _flight_noted: bool = false


func _act(delta: float, pests: Array[Pest]) -> void:
	if _held != null:
		_chew(delta)
		return
	var prey: Pest = _nearest_free_pest(pests)
	if prey != null:
		_grab(prey)
		_flight_noted = false
		return
	# After the grab attempt, not before: a mouth that just closed on something is not
	# idle, whatever else is in reach.
	var winged: int = 0
	var grabbable: int = 0
	for pest: Pest in pests:
		if pest.held_by != null:
			continue
		if pest.global_position.distance_to(global_position) > grab_radius():
			continue
		if pest.is_winged:
			winged += 1
		else:
			grabbable += 1
	if not idle_only_because_of_flight(winged, grabbable):
		_flight_noted = false
		return
	if _flight_noted:
		return
	_flight_noted = true
	flight_ignored.emit()


## The state the flight hint explains, as a pure function of what is within reach.
##
## Both halves matter and only together. A winged pest in reach is not confusing if a
## grabbable one is there too — the mouth closes on that one, the player sees the plant
## working, and nothing needs saying. It is confusing when EVERYTHING in reach flies,
## because then a bug walks over a mouth that does not move.
##
## Static and pure so the condition has a name a test can assert directly, rather than
## being an `and` buried in `_act` that can only be reached by staging two pests in a
## live tree. `Hud.uproot_shows_tip` is the same move for the same reason.
static func idle_only_because_of_flight(winged_in_reach: int, grabbable_in_reach: int) -> bool:
	return winged_in_reach > 0 and grabbable_in_reach == 0


func _nearest_free_pest(pests: Array[Pest]) -> Pest:
	var best: Pest = null
	var best_distance: float = grab_radius()
	for pest: Pest in pests:
		# Winged (doc: "ignores ground plants") flies over a Chomp's reach — the
		# mouth simply cannot close on it. It still walks into Corn's kernels.
		if pest.held_by != null or pest.is_winged:
			continue
		var d: float = pest.global_position.distance_to(global_position)
		if d <= best_distance:
			best_distance = d
			best = pest
	return best


func _grab(pest: Pest) -> void:
	_held = pest
	pest.held_by = self
	_chew_total = chew_seconds_for(level, pest.chew_seconds)
	_chew_left = _chew_total
	_bite()
	_show_eating_sprite()
	queue_redraw()


func _chew(delta: float) -> void:
	if not is_instance_valid(_held) or not _held.is_alive():
		release()
		return
	_chew_left -= delta
	if chew_progress() > LATE_BITE_THRESHOLD and _sprite != null and _sprite.texture != _eating_late_texture:
		_show_eating_late_sprite()
	queue_redraw()
	if _chew_left <= 0.0:
		var meal: Pest = _held
		release()
		# Bitten, so the corpse is squashed rather than straight -- a Chomp closes
		# on the whole pest (plant-tower-defense-f5z6).
		meal.kill(Pest.DEATH_BITTEN)


## Drops whatever is in the mouth and frees the flower. Called by Pest.kill() too,
## so a pest shot out of the mouth by a stray kernel does not wedge the plant shut.
func release() -> void:
	if _held != null and is_instance_valid(_held):
		_held.held_by = null
	_held = null
	_chew_left = 0.0
	_chew_total = 0.0
	_show_idle_sprite()
	queue_redraw()


func is_busy() -> bool:
	return _held != null


func held_pest() -> Pest:
	return _held


## 0.0 when the mouth just closed, 1.0 when the meal is about to finish.
func chew_progress() -> float:
	if _chew_total <= 0.0:
		return 0.0
	return clampf(1.0 - _chew_left / _chew_total, 0.0, 1.0)


## How far round the chew ring is drawn: a full circle when the mouth has just
## closed, sweeping down to nothing as the meal finishes.
##
## Pure, so the shape is assertable without a rendered frame — and so the draw site
## below carries no branch of its own. At the end the two ends coincide and
## `draw_arc` draws nothing, which is the same reason `CornCobbler._draw_muzzle_fan`
## lost its `if`: one place decides, and a test can reach it.
static func chew_arc_end(progress: float) -> float:
	return TAU * clampf(1.0 - progress, 0.0, 1.0)


## The ring around the flower while the mouth is full — the whole Chomp/beetle
## trade-off ("mouth busy, lane open") made visible. Fixed radius, swept angle; see
## CHEW_RING_RADIUS for why round that way.
func _draw() -> void:
	# Always, and before the ring: the crown is what this flower's LEVEL looks like and
	# the ring is what its current MEAL looks like. A cue the player has to catch the
	# plant mid-chew to see cannot be the readout for something they bought.
	_draw_fang_crown()
	if _held == null:
		return
	draw_arc(Vector2.ZERO, CHEW_RING_RADIUS, 0.0, chew_arc_end(chew_progress()), 24,
		Color(1.0, 0.55, 0.15, 0.85), CHEW_RING_WIDTH, true)


## Level 1 draws nothing here and that is decided in `fang_offsets`, not by an `if`
## at this site — the same split `_draw_muzzle_fan` made after cycle 70 watched a
## mutation to the rule survive a test that only asked the other function.
func _draw_fang_crown() -> void:
	for tooth: Vector2 in fang_points(level):
		draw_circle(tooth, FANG_SIZE + FANG_RIM_WIDTH, FANG_RIM_COLOR)
		draw_circle(tooth, FANG_SIZE, FANG_COLOR)


## Which way this bite throws the head, and how far — pure, so the direction is
## assertable with no board, no frame and no open animation gate.
##
## Returns a vector FROM the flower TOWARD the meal, `LUNGE_DISTANCE` long: the sign
## and the axis are the entire content of the animation, and a squash tween cannot
## carry either. Degenerate input (a pest exactly on top of the flower, which
## `_nearest_free_pest` genuinely permits at distance 0) returns `Vector2.ZERO` rather
## than a normalised NaN — a lunge nowhere is the correct picture for a meal that is
## already here.
static func lunge_offset(from: Vector2, to: Vector2) -> Vector2:
	var delta: Vector2 = to - from
	if delta.length_squared() <= 0.0001:
		return Vector2.ZERO
	return delta.normalized() * LUNGE_DISTANCE


func _bite() -> void:
	# Ahead of the tree-guard below: the mouth closing is the game event, and
	# it happens whether or not there is a tree to play the squash tween in —
	# Sfx.play() gates its own headless silence, so there is nothing here for
	# a unit test calling _grab() directly to trip over.
	Sfx.play(Sfx.CHOMP_BITE)
	# The catch itself, not a kill — the meal doesn't die until _chew_left runs
	# out, so unlike Kernel's post-damage guard this is never racing a death
	# this same frame. Same is_alive() guard anyway, kept for the pattern.
	if is_instance_valid(_held) and _held.is_alive():
		_held.flash_hit()
	# Also ahead of the guard, and for a different reason than the two above: this is
	# not a game event, it is the one part of the ANIMATION that has a right and a
	# wrong answer. See `_bite_lunge`.
	_bite_lunge = Vector2.ZERO
	if is_instance_valid(_held):
		_bite_lunge = lunge_offset(global_position, _held.global_position)
	# `animations_enabled()` joins this guard as of the lunge, which it should have
	# been on all along: `_on_upgraded` below claims to be gated "exactly as every
	# cosmetic Tween in this class and in `Plant` is" and this one was the exception
	# that made the sentence false. Everything a headless run needs from a bite — the
	# sound, the flash, the hold, and now the lunge VECTOR — is already settled above.
	if _sprite == null or not is_inside_tree() or not GardenTheme.animations_enabled():
		return
	# Position and scale in parallel, then both back: the squash is what a bite feels
	# like and the lunge is who it is aimed at, and playing them in sequence would read
	# as two separate twitches. `_sprite.position` is otherwise unwritten on a plant —
	# idle sway and flinch live on `_sway_pivot` and every event tween owns
	# `_sprite.scale` (see `Plant._sway_pivot`), so this adds a third channel rather
	# than joining the queue for the second.
	#
	# The offset is applied in the sway pivot's frame, so a lunge is rotated by whatever
	# the idle sway is doing at that instant — at most FLINCH_RADIANS (0.16 rad, 9°),
	# which leans the lunge without ever pointing it at the wrong neighbour. Deliberate:
	# the body leaning at its meal is the picture, and un-rotating it would decouple the
	# head from the stem it is attached to.
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sprite, "position", _bite_lunge, BITE_LUNGE_OUT_SECONDS)
	tween.tween_property(_sprite, "scale", Vector2(1.18, 0.82), BITE_SQUASH_OUT_SECONDS)
	tween.chain().tween_property(_sprite, "position", Vector2.ZERO, BITE_LUNGE_BACK_SECONDS)
	tween.tween_property(_sprite, "scale", Vector2.ONE, BITE_SQUASH_BACK_SECONDS)


## The teeth coming in: a snap wider than `_bite`'s and held longer, the same
## relationship `CornCobbler._upgrade_flourish` has to its own `_recoil` — one payment
## for a whole level against one of hundreds of bites.
##
## Note what this deliberately does NOT do: re-time the meal already in the mouth.
## `_chew_total` was set when the mouth closed, at the level it closed at, and a bug
## already half-swallowed finishing early because the player bought something is a
## refund the ladder is not offering. The next meal is where the upgrade lands.
##
## Gated exactly as every cosmetic Tween in this class and in `Plant` is: headless
## pumps no frames, so a Tween queued here would never run. The level, the reach, the
## chew scale and the crown are all already correct without it.
func _on_upgraded() -> void:
	if _sprite == null or not is_inside_tree() or not GardenTheme.animations_enabled():
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2(1.30, 0.74), FLOURISH_OUT_SECONDS)
	tween.tween_property(_sprite, "scale", Vector2.ONE, FLOURISH_BACK_SECONDS)


func _show_eating_sprite() -> void:
	if _sprite == null:
		return
	if _idle_texture == null:
		_idle_texture = _sprite.texture
	if _eating_texture == null:
		_eating_texture = load(EATING_TEXTURE_PATH) as Texture2D
	if _eating_texture != null:
		_sprite.texture = _eating_texture


func _show_eating_late_sprite() -> void:
	if _sprite == null:
		return
	if _idle_texture == null:
		_idle_texture = _sprite.texture
	if _eating_late_texture == null:
		_eating_late_texture = load(EATING_LATE_TEXTURE_PATH) as Texture2D
	if _eating_late_texture != null:
		_sprite.texture = _eating_late_texture


func _show_idle_sprite() -> void:
	if _sprite != null and _idle_texture != null:
		_sprite.texture = _idle_texture
