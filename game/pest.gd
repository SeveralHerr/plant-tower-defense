class_name Pest
extends Node2D

## A bug walking the road. Three species, per the drawings: a small fast one
## (aphid), a big slow one (beetle), and the boss the campaign builds toward (the
## Aphid Queen).
##
## The interesting state here is `held_by`. A Chomp Flower that grabs a pest does
## not delete it — it holds it in place for `chew_seconds` while the pest stays on
## the board blocking nothing and taking no ground. That is what makes the Chomp a
## body blocker rather than a damage source, which is the whole plant/pest balance.

signal died(pest: Pest)
signal escaped(pest: Pest)

const APHID := &"aphid"
const BEETLE := &"beetle"
const QUEEN := &"queen"

## species -> stats. `chew_seconds` is the design doc's "eats small pests easily,
## takes a while eating bigger pests" expressed as a number.
##
## `split_species` / `split_count` are the boss mechanic and the only optional
## pair here: a species that names them bursts into that many of that species
## WHERE IT DIED rather than simply leaving the board. Read through
## split_species() / split_count() below, never off the raw Dictionary, so an
## ordinary pest answers "&"" / 0" instead of erroring on a missing key.
const SPECIES: Dictionary = {
	APHID: {
		"display": "Aphid",
		"texture": "res://assets/sprites/pest_aphid.png",
		"dead_texture": "res://assets/sprites/pest_aphid_dead.png",
		"health": 3.0,
		"speed": 78.0,
		"seeds": 3,
		"chew_seconds": 0.45,
		"scale": 0.72,
		"big": false,
	},
	BEETLE: {
		"display": "Beetle",
		"texture": "res://assets/sprites/pest_beetle.png",
		"dead_texture": "res://assets/sprites/pest_beetle_dead.png",
		"health": 16.0,
		"speed": 38.0,
		"seeds": 9,
		"chew_seconds": 2.6,
		"scale": 1.0,
		"big": true,
	},
	## The boss (plant-tower-defense-74a). Deliberately NOT a fourth mutation and
	## deliberately not "a beetle with more health": what makes a queen a
	## different fight is that killing her is a decision about WHERE, not about
	## whether. She bursts into three aphids at the spot she falls, so a garden
	## that only reaches the last stretch of road converts one slow boss into
	## three fast pests with almost no road left to shoot them on, while the same
	## kill made at the entrance is simply free. Nothing else on the board makes
	## the player care where a kill lands.
	##
	## The numbers, and what each is for:
	##   * health 80 — measured against CornCobbler.single_target_dps. A level-3
	##     cob does 2.26 dps and holds a pest crossing its ring for ~11 s at this
	##     speed, so one cob is ~25 damage: a lone Corn Cobbler cannot take her,
	##     four maxed ones can, which is exactly the band the issue asks for.
	##   * speed 30 — slower than a beetle, so she is on the road a long time and
	##     the swarm behind her arrives while she is still walking. Also what
	##     makes the 11 s exposure above true.
	##   * chew_seconds 11 — a Chomp CAN eat her, and pays for it with the whole
	##     rest of the wave walking past a shut mouth. Note the mouth is beside
	##     the road, so a Chomp kill bursts the brood right next to the plant
	##     that is now busy for another eleven seconds. That is the trade, not a
	##     loophole.
	##   * seeds 40 — a beetle is 9. She is worth the wave.
	##   * scale 1.45 — 64 px of authored art (STYLE.md's canvas) drawn at 93 px
	##     on a 64 px cell. Nothing else on the board overflows its own cell.
	QUEEN: {
		"display": "Aphid Queen",
		"texture": "res://assets/sprites/pest_queen.png",
		"dead_texture": "res://assets/sprites/pest_queen_dead.png",
		"health": 80.0,
		"speed": 30.0,
		"seeds": 40,
		"chew_seconds": 11.0,
		"scale": 1.45,
		"big": true,
		"split_species": APHID,
		"split_count": 3,
	},
}

## From wave 8 (WaveDirector.MUTATION_START_WAVE) a spawned pest may carry one of
## these. Each is a single trait, not a new species — the wave table stays the
## same shape, a run just stops being identical every time.
const MUTATION_ARMOURED := &"armoured"
const MUTATION_WINGED := &"winged"
const MUTATION_HUNGRY := &"hungry"

## A mutated pest costs the player more to deal with than a plain one — the
## husk it leaves should too, or the mutation and compost systems sit side by
## side without ever touching. Armoured/winged both cost extra effort to kill
## (double chew time; unreachable by a Chomp at all); hungry costs the most,
## since a plant it reaches is destroyed outright rather than merely delayed.
const MUTATION_HUSK_MULTIPLIER: Dictionary = {
	MUTATION_ARMOURED: 1.5,
	MUTATION_WINGED: 1.5,
	MUTATION_HUNGRY: 2.0,
}

## Each mutation's hue. Still applied as a sprite tint — but hue is the one
## channel that survives neither colour blindness nor a greyscale screenshot,
## and two of these three change what the player must do (winged is unreachable
## by a Chomp at all; hungry destroys a bed in MAX_HEALTH / EAT_DPS seconds).
## So every entry here is paired with a drawn silhouette marker below, and the
## marker — not the colour — is what carries the meaning.
const MUTATION_TINT: Dictionary = {
	MUTATION_ARMOURED: Color(0.58, 0.66, 0.78),
	MUTATION_WINGED: Color(0.82, 0.94, 1.0, 0.88),
	MUTATION_HUNGRY: Color(1.0, 0.52, 0.5),
}

## The non-colour half of a mutation's read: a shape at the silhouette edge.
## Named ids rather than raw draw calls so markers_for() is a pure, assertable
## function and the geometry below is only ever the rendering of its answer.
const MARKER_PLATES := &"plates"
const MARKER_WINGS := &"wings"
const MARKER_JAWS := &"jaws"

## Which mutation's hue each marker borrows. Markers never invent a colour —
## they take STYLE.md's three-value rule (dark rim / base / light facet) and
## apply it to the tint that is already in MUTATION_TINT.
const MARKER_SOURCE: Dictionary = {
	MARKER_PLATES: MUTATION_ARMOURED,
	MARKER_WINGS: MUTATION_WINGED,
	MARKER_JAWS: MUTATION_HUNGRY,
}

const MARKER_LIGHTEN: float = 0.42
const MARKER_DARKEN: float = 0.52
const MARKER_ALPHA: float = 0.95
const MARKER_LINE: float = 2.0

## Half of the 64 px sprite canvas STYLE.md mandates. Every marker below is
## placed in fractions of this times the species' own sprite scale, so an
## aphid's marks hug its silhouette exactly as tightly as a beetle's hug its.
const SPRITE_HALF: float = 32.0

## Armour: two concentric arcs hugging the sides and underside — an outline
## thickening, per the doc's "plate". The arc deliberately stops short of the
## top (-15 deg round to 195 deg) because the health bar lives up there.
const PLATE_OUTER: float = 1.06
const PLATE_INNER: float = 0.92
const PLATE_FROM: float = -PI / 12.0
const PLATE_TO: float = PI * 13.0 / 12.0
const PLATE_SEGMENTS: int = 22
const PLATE_WIDTH: float = 3.0
const PLATE_SEAM_WIDTH: float = 2.0

## Winged: a swept wing either side, rooted at the body and reaching past the
## silhouette. Drawn on the parent's canvas item, i.e. BEHIND the sprite child,
## which is why every point sits outside the sprite's own art rather than on it.
const WING_ROOT_IN := Vector2(0.40, -0.22)
const WING_TIP := Vector2(1.10, -0.92)
const WING_TIP_OUT := Vector2(1.06, -0.34)
const WING_ROOT_OUT := Vector2(0.52, 0.02)

## Hungry: a row of teeth along the lower edge, the same tooth language the
## Chomp Flower's maw uses — on the bug this time, which is the point.
const JAW_TEETH: int = 3
const JAW_TOP: float = 0.78
const JAW_TIP: float = 1.14
const JAW_HALF_WIDTH: float = 0.19
const JAW_SPACING: float = 0.40

## How close a hungry pest has to be to a plant to start eating it. Same
## reasoning as ChompFlower.GRAB_RADIUS: a pest walks the road, a plant stands
## one cell off it, so anything under one cell can never reach either.
const EAT_RADIUS: float = Board.CELL * 1.15
const EAT_DPS: float = 14.0

## The health bar's box, and how far above the pest's centre it floats.
##
## The offset scales with the sprite, and only ever upward. A queen is drawn at
## scale 1.45, so her silhouette reaches 46 px from her centre and a bar pinned
## at 30 would be painted across her own back — the one readout a boss fight is
## actually about, hidden inside the boss. maxf(1.0, ...) is what keeps this
## change to one sprite: an aphid at 0.72 keeps the bar exactly where every pest
## in the game has always had it rather than sliding down into its body.
const HEALTH_BAR_SIZE := Vector2(32, 5)
const HEALTH_BAR_TOP: float = -30.0


## Where a pest drawn at `sprite_scale` floats its bar. Pure, so the placement is
## assertable without a viewport.
static func health_bar_top_for(sprite_scale: float) -> float:
	return HEALTH_BAR_TOP * maxf(1.0, sprite_scale)


## How long a killed pest's corpse (dead-eyes sprite) stays on screen before it
## is actually freed. Long enough to read as a beat, short enough not to pile up.
const DEATH_LINGER: float = 0.35

## How much of DEATH_LINGER's tail is spent fading out rather than held solid —
## the corpse reads for a beat first, same as before this existed, then goes.
const DEATH_FADE: float = 0.15

## A kernel connecting and a kernel missing (leaving the board unaimed) used to
## look identical — Kernel._physics_process called queue_free() on either exit
## with nothing in between (plant-tower-defense-7o3). A killed pest already gets
## its own unmistakable cue (the corpse swap and fade below, plus Sfx.PEST_KILLED
## from Game._on_pest_died), so this is only for the other case: a hit that the
## pest survives, where the health bar shrinking was the only tell.
##
## Total time the flash takes to rise and fall back to the sprite's normal tint.
const HIT_FLASH_DURATION: float = 0.10
## How hard the flash boosts the sprite's current colour channels — deliberately
## a multiply, not a replacement, so a flash on an armoured or hungry pest still
## reads as that pest's own hue gone bright, not as a third, unrelated colour.
const HIT_FLASH_BOOST: float = 1.9

## The walk cycle (plant-tower-defense-iue). Plant._wobble() is the reference
## idiom: one accumulated clock per instance, one `sin()` off it per frame, no
## Tween anywhere. That shape is the whole reason this is affordable — this runs
## on every pest on the road, and WaveDirector.SIMULTANEOUS_PEST_CEILING puts
## that at 40 at once. Two `sin()` calls and two property writes per pest per
## frame is 4,800 sines a second at the ceiling, which is nothing; forty Tweens
## being created and destroyed as pests spawn and die would not be.
##
## A bug seen from above does not bob up and down — it slews. So the motion is
## a yaw waggle *around the facing rotation* plus a body-axis stretch: the
## silhouette narrows and lengthens as it scuttles, which is exactly the shape
## the drawn sprites already have (long axis up-screen, per STYLE.md).
##
## Peak yaw either side of the direction of travel. Read the composition rule in
## _apply_facing(): this is added to `_facing`, never written over it.
const GAIT_SWING: float = 0.13
## Waggles per second at GAIT_REFERENCE_SPEED, in radians of clock.
const GAIT_RATE: float = 8.5
## The speed a pest walks at to get exactly GAIT_RATE — between the aphid's 78
## and the beetle's 38, so the fast one scuttles fast and the slow one plods
## without either needing a per-species constant. Endless-mode speed scaling
## rides along for free (a hasted pest visibly hurries), clamped either side so
## a wave-30 beetle flails rather than blurs.
const GAIT_REFERENCE_SPEED: float = 60.0
const GAIT_RATE_MIN: float = 0.55
const GAIT_RATE_MAX: float = 1.9
## Body-axis squash/stretch, as a fraction of the species' own sprite scale.
const GAIT_STRETCH: float = 0.06
## Strides per waggle: the body pulses twice per side-to-side sway, which is
## what stops the two reading as one motion.
const GAIT_STRETCH_RATE: float = 2.0

## Each mutation's gait tell, so the trait is readable from movement alone and
## not only from the hue + marker pair above. Winged flutters (fast, shallow);
## armoured plods (slow, stiff); hungry lunges — see gait_stretch() for why that
## one is a shape change rather than a bigger number.
const WINGED_RATE_MULTIPLIER: float = 2.4
const WINGED_SWING_MULTIPLIER: float = 0.45
const ARMOURED_RATE_MULTIPLIER: float = 0.8
const ARMOURED_SWING_MULTIPLIER: float = 0.6
const HUNGRY_STRETCH_MULTIPLIER: float = 2.2

## Per-pest phase, so nine aphids spawned in a column read as nine creatures
## rather than one animation played nine times. The golden angle: successive
## spawns land as far apart on the circle as any sequence can, so even the two
## pests either side of a single spawn beat are visibly out of step.
const GAIT_PHASE_STEP: float = 2.399963
## The spawn counter wraps here rather than climbing for the length of an
## endless run — `index * GAIT_PHASE_STEP` at a few million loses the precision
## that makes neighbouring phases distinct, and 64 distinct phases is already
## more than SIMULTANEOUS_PEST_CEILING can put on the road at once.
const GAIT_PHASE_PERIOD: int = 64

var species: StringName = APHID
var health: float = 1.0
var max_health: float = 1.0
var speed: float = 60.0
var seed_value: int = 1
var chew_seconds: float = 0.5
var is_big: bool = false

## Set by a Chomp Flower while it is eating this pest. A held pest does not move.
var held_by: Node = null

var mutation: StringName = &""
var is_armoured: bool = false
var is_winged: bool = false
var is_hungry: bool = false

var _route: PackedVector2Array = PackedVector2Array()
var _leg: int = 1
var _sprite: Sprite2D
var _health_bar: ColorRect
var _health_back: ColorRect
var _alive: bool = true
var _dead_texture: Texture2D = null
var _sprite_scale: float = 1.0

## How this pest died, so the corpse can say so (plant-tower-defense-f5z6).
##
## Every death used to leave the same straight corpse, which is a fair default and
## makes three quite different events look identical: a Chomp chewing something to
## pieces, a seed bomb going off underneath it, and a kernel arriving. The cue is
## the corpse itself rather than a new effect, because a corpse is already drawn,
## already lingers for DEATH_LINGER, and is already the thing a player looks at.
##
## `&""` — the default — is the straight corpse, and it is what a kernel kill and
## any future unattributed kill both get. That is deliberate: the plain corpse
## should be the common case, so the two that differ read as remarkable.
const DEATH_BITTEN := &"bitten"
const DEATH_BLASTED := &"blasted"

## Squash along the body axis for a chewed corpse. A Chomp closes on the whole
## pest, so the corpse is SHORTER rather than displaced — shape, not position,
## which is also the channel a screenshot can be asserted against.
const BITTEN_SQUASH: float = 0.62

## Rotation off the facing for a blasted corpse, in radians. A bomb throws the
## body off its line of travel; nothing else in the game rotates a corpse away
## from `_facing`, so the tilt reads as "something moved this" without needing a
## second colour. Deliberately not a multiple of PI/2 — the four cardinals are
## spoken for by _update_facing and a corpse at one of them would read as a
## living pest that stopped.
const BLASTED_TILT: float = 0.55

var _death_cause: StringName = &""

## The walk cycle's own state. `_facing` is the cardinal rotation
## _update_facing() decides; `_sway` is the gait's offset from it. They are kept
## apart precisely because two features write one property: whichever of them
## ran last would otherwise erase the other, and since _advance() calls
## _update_facing() every single frame, the loser would always be the gait.
var _facing: float = 0.0
var _sway: float = 0.0
var _gait_time: float = 0.0
var _gait_phase: float = 0.0

## Handed out at setup() and wrapped at GAIT_PHASE_PERIOD. Static because the
## thing being spread out is *between* pests — a per-instance seed cannot know
## what the pest beside it chose. StickySundew._next_wash_order is the same
## pattern; unlike that one this needs no reset, because a phase is cosmetic and
## the wrap keeps it bounded on its own.
static var _next_gait_index: int = 0

## Did anything in the garden ever lay a finger on this pest?
##
## Set by exactly the two things that can. A kernel landing (take_damage) and a
## Chomp holding it still are the whole list: a Sundew "deals no damage
## whatsoever" by its own doc comment, it only slows, and a Sunflower never
## touches a pest at all. So a pest that walked a field of Sundews and reached
## the exit really was never engaged, and this does not overstate the garden.
##
## Held counts, even though a Chomp does no damage. A Chomp eaten out from under
## its meal calls release() (chomp_flower.gd wires `destroyed` to it) and hands
## back a live pest at full health — which had very much been fought, and would
## otherwise report itself as having strolled past an empty lane.
##
## The reading this exists for is at the moment of escape; see Game._note_escape.
var _ever_engaged: bool = false


func setup(which: StringName, route: PackedVector2Array) -> void:
	species = which
	var stats: Dictionary = SPECIES[which]
	max_health = float(stats["health"])
	health = max_health
	speed = float(stats["speed"])
	seed_value = int(stats["seeds"])
	chew_seconds = float(stats["chew_seconds"])
	is_big = bool(stats["big"])
	_route = route
	_leg = 1
	if not _route.is_empty():
		position = _route[0]
	add_to_group("pests")
	_gait_phase = gait_phase(_next_gait_index)
	_next_gait_index = (_next_gait_index + 1) % GAIT_PHASE_PERIOD
	_build_visuals(String(stats["texture"]), float(stats["scale"]))
	var dead_path: String = String(stats.get("dead_texture", ""))
	if dead_path != "":
		_dead_texture = load(dead_path) as Texture2D
	_make_world_controls_click_through()
	if _route.size() > 1:
		_update_facing(_route[1] - _route[0])


## Drops a pest that has already been setup() into the middle of that walk.
##
## The brood a boss bursts into (see split_species) has to arrive where its
## parent fell, not at the entrance — a queen killed at the exit whose aphids
## restarted from the gate would turn the entire mechanic upside down and reward
## exactly the play it is meant to punish. `leg` is the waypoint index the pest
## is walking TOWARD, which is what the parent's route_leg() hands back, so the
## child inherits the walk rather than re-deriving it from a position.
##
## Clamped to the route's own bounds: a leg past the end would make the very
## next _advance() call _escape() on a pest that had not walked anywhere, and a
## leg below 1 would send it back to a waypoint it is already past.
func enter_road_at(at: Vector2, leg: int) -> void:
	if _route.is_empty():
		return
	position = at
	_leg = clampi(leg, 1, _route.size() - 1)
	_update_facing(_route[_leg] - position)


## The waypoint index this pest is walking toward. Public because a burst boss
## has to hand its own place in the walk to the brood it leaves behind, and that
## is the only honest way to say "here, on this road, facing this way".
func route_leg() -> int:
	return _leg


## What `species` bursts into when it dies, or &"" for a pest that simply dies.
static func split_species(which: StringName) -> StringName:
	var stats: Dictionary = SPECIES.get(which, {}) as Dictionary
	return StringName(stats.get("split_species", &""))


## How many of split_species() it bursts into; 0 when it bursts into nothing.
##
## Reads the same entry the sprite counts out: pest_queen.svg draws exactly
## three eggs on the brood sac, so the picture and the number are the same
## claim. test_the_queens_sprite_counts_out_the_brood_it_bursts_into holds them
## together.
static func split_count(which: StringName) -> int:
	if split_species(which) == &"":
		return 0
	var stats: Dictionary = SPECIES.get(which, {}) as Dictionary
	return int(stats.get("split_count", 0))


## Endless mode's per-wave difficulty multipliers, from
## WaveDirector.health_scale_for / speed_scale_for. Called after setup(), which
## is what seeded the species defaults these scale.
##
## `health` moves with `max_health` rather than being left at the species value,
## so a scaled pest still spawns with a full bar — a beetle arriving at 16/48
## would read as pre-damaged and the bar would barely move for its first three
## hits. Mutations do not touch health or speed, so this composes with
## apply_mutation() in either order.
func apply_wave_scaling(health_multiplier: float, speed_multiplier: float) -> void:
	max_health *= health_multiplier
	health = max_health
	speed *= speed_multiplier


## Applies one wave-8+ trait. Called by whoever spawns this pest, after setup()
## so the sprite already exists to tint. A no-op for &"" (the common case).
##
## Setting the flag is what matters: markers() reads the flags, not `mutation`,
## so calling this twice leaves a pest wearing both marks rather than only the
## last one's. Nothing in the game does that today, but a Chomp already reads
## `is_winged` directly, and a cue that disagreed with the rule it advertises
## would be worse than no cue at all.
func apply_mutation(which: StringName) -> void:
	mutation = which
	match which:
		MUTATION_ARMOURED:
			is_armoured = true
			# The doc's "armoured" — a Chomp's mouth is tied up twice as long.
			chew_seconds *= 2.0
		MUTATION_WINGED:
			is_winged = true
		MUTATION_HUNGRY:
			is_hungry = true
	_tint(tint_for(which))
	queue_redraw()


## The hue for a mutation; white (i.e. untinted) for &"" and anything unknown.
static func tint_for(which: StringName) -> Color:
	if not MUTATION_TINT.has(which):
		return Color.WHITE
	var colour: Color = MUTATION_TINT[which]
	return colour


func _tint(colour: Color) -> void:
	if _sprite != null:
		_sprite.modulate = colour


## Which silhouette marks this pest wears. Pure and flag-driven, so a pest
## carrying two traits reports both, a plain pest reports none, and a test can
## ask the question without a viewport, a frame, or a pixel.
func markers() -> Array[StringName]:
	return markers_for(is_armoured, is_winged, is_hungry)


## Draw order: plates first so they sit under wings and jaws — a plated bug
## that also flies should read as "plated, and also winged", not as a shell
## with something scribbled over it.
static func markers_for(armoured: bool, winged: bool, hungry: bool) -> Array[StringName]:
	var out: Array[StringName] = []
	if armoured:
		out.append(MARKER_PLATES)
	if winged:
		out.append(MARKER_WINGS)
	if hungry:
		out.append(MARKER_JAWS)
	return out


func _build_visuals(texture_path: String, sprite_scale: float) -> void:
	_sprite_scale = sprite_scale
	_sprite = Sprite2D.new()
	_sprite.texture = load(texture_path) as Texture2D
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	add_child(_sprite)

	var bar_origin := Vector2(-HEALTH_BAR_SIZE.x * 0.5, health_bar_top_for(sprite_scale))

	_health_back = ColorRect.new()
	_health_back.color = Color(0.12, 0.12, 0.12, 0.65)
	_health_back.position = bar_origin
	_health_back.size = HEALTH_BAR_SIZE
	_health_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_health_back)

	_health_bar = ColorRect.new()
	_health_bar.color = GardenTheme.LEAF
	_health_bar.position = bar_origin
	_health_bar.size = HEALTH_BAR_SIZE
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_health_bar)


## Every Control this pest owns stops taking mouse input.
##
## The same defect Plant._make_world_controls_click_through() documents at
## length, on a target that moves. A Control parented to a Node2D is picked by
## the viewport's GUI pass in world space, and that pass runs before the
## `_unhandled_input` Game._click_at lives in — so a pest's 32x5 bar at the
## default MOUSE_FILTER_STOP is a strip of board where the player's clicks stop
## existing, and it walks the road at `speed` px/s.
##
## Worse here than on a plant, in a way worth naming: every husk in the game
## lands on the road (Board.route() is one point per road cell, and pests only
## ever walk it), so this bar drifts over the compost the player is trying to
## sweep and blanks the only click that would collect it. A plant's bar sits
## still and can at least be clicked around.
##
## Runs once from setup(), after the bars exist — a pest has no subclasses and
## builds nothing later, so there is no second call site to keep in step.
func _make_world_controls_click_through() -> void:
	for node: Node in find_children("*", "Control", true, false):
		var control := node as Control
		if control == null:
			continue
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE


## The mutation cues. Drawn here rather than in a child node because Pest has no
## subclasses — the trap SelectionMarker exists to dodge (CornCobbler and
## ChompFlower each fully override Plant._draw() and never chain to super) has no
## instance on this side of the board. If a Pest subclass ever appears, the fix
## is `super._draw()` in it, and the per-marker methods below are already split
## out so it can reuse them piecemeal.
##
## Note that a Node2D paints its own canvas item BEFORE its children, so every
## shape here lands *behind* the sprite. That is why the geometry sits at and
## past the silhouette edge: a marker drawn over the body would simply not exist.
func _draw() -> void:
	if not _alive:
		return
	var r: float = SPRITE_HALF * _sprite_scale
	for marker: StringName in markers():
		match marker:
			MARKER_PLATES:
				_draw_plates(r)
			MARKER_WINGS:
				_draw_wings(r)
			MARKER_JAWS:
				_draw_jaws(r)


func _draw_plates(r: float) -> void:
	draw_arc(Vector2.ZERO, r * PLATE_OUTER, PLATE_FROM, PLATE_TO, PLATE_SEGMENTS,
		marker_ink(MARKER_PLATES), PLATE_WIDTH, true)
	draw_arc(Vector2.ZERO, r * PLATE_INNER, PLATE_FROM, PLATE_TO, PLATE_SEGMENTS,
		marker_fill(MARKER_PLATES), PLATE_SEAM_WIDTH, true)


func _draw_wings(r: float) -> void:
	for sx: float in [-1.0, 1.0]:
		var mirror := Vector2(sx, 1.0)
		_draw_marker_shape(PackedVector2Array([
			WING_ROOT_IN * mirror * r,
			WING_TIP * mirror * r,
			WING_TIP_OUT * mirror * r,
			WING_ROOT_OUT * mirror * r,
		]), MARKER_WINGS)


func _draw_jaws(r: float) -> void:
	var middle: float = float(JAW_TEETH - 1) * 0.5
	for i: int in range(JAW_TEETH):
		var cx: float = (float(i) - middle) * JAW_SPACING * r
		_draw_marker_shape(PackedVector2Array([
			Vector2(cx - JAW_HALF_WIDTH * r, JAW_TOP * r),
			Vector2(cx + JAW_HALF_WIDTH * r, JAW_TOP * r),
			Vector2(cx, JAW_TIP * r),
		]), MARKER_JAWS)


## Filled light shape with a darker rim of its own hue — STYLE.md's rule, so a
## drawn marker sits in the same visual language as the authored sprites.
func _draw_marker_shape(points: PackedVector2Array, marker: StringName) -> void:
	draw_colored_polygon(points, marker_fill(marker))
	var rim: PackedVector2Array = points.duplicate()
	rim.append(points[0])
	draw_polyline(rim, marker_ink(marker), MARKER_LINE, true)


static func marker_fill(marker: StringName) -> Color:
	var colour: Color = tint_for(_marker_source(marker)).lightened(MARKER_LIGHTEN)
	colour.a = MARKER_ALPHA
	return colour


static func marker_ink(marker: StringName) -> Color:
	var colour: Color = tint_for(_marker_source(marker)).darkened(MARKER_DARKEN)
	colour.a = MARKER_ALPHA
	return colour


static func _marker_source(marker: StringName) -> StringName:
	if not MARKER_SOURCE.has(marker):
		return &""
	var source: StringName = MARKER_SOURCE[marker]
	return source


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	# Before the held/eating guards below on purpose: a pest in a Chomp's mouth
	# or chewing a bed is still a live creature, and freezing it solid the moment
	# it stopped travelling would put the static sprite back exactly where the
	# player is looking hardest.
	_gait(delta)
	# Split out of the combined guard this used to share with `_alive`: being held
	# is the one non-damaging way the garden engages a pest, and a Chomp that is
	# destroyed mid-chew releases it unharmed. See _ever_engaged.
	if held_by != null:
		_ever_engaged = true
		return
	if is_hungry:
		var meal: Plant = _adjacent_plant()
		if meal != null:
			meal.take_damage(EAT_DPS * delta)
			return
	_advance(delta * speed)


## The doc's "hungry" trait: eats the plant instead of walking past. Only ever
## looks at the lane it is currently beside — same one-cell reach as a Chomp's
## grab, so a hungry pest cannot reach across the road to a different lane.
func _adjacent_plant() -> Plant:
	var best: Plant = null
	var best_distance: float = EAT_RADIUS
	for node: Node in get_tree().get_nodes_in_group("plants"):
		var plant := node as Plant
		if plant == null or plant.is_destroyed():
			continue
		var d: float = plant.global_position.distance_to(global_position)
		if d <= best_distance:
			best_distance = d
			best = plant
	return best


## Walk `distance` px along the remaining route, spending it across legs so a fast
## pest cannot skip a corner at low frame rates.
func _advance(distance: float) -> void:
	while distance > 0.0:
		if _leg >= _route.size():
			_escape()
			return
		var target: Vector2 = _route[_leg]
		var to_target: Vector2 = target - position
		_update_facing(to_target)
		var gap: float = to_target.length()
		if gap <= distance:
			position = target
			distance -= gap
			_leg += 1
		else:
			position += to_target / gap * distance
			distance = 0.0


## Turns the sprite to face the leg it is currently walking. `PATH_CORNERS`
## (Board.gd) is expanded to one waypoint per grid cell, so every leg of the
## route is axis-aligned — never a diagonal — which is what makes a snap to
## one of the four cardinal rotations exactly right rather than an approximation.
##
## Only `_sprite` rotates, not this Node2D: the health bar and the mutation
## markers (`_draw()`, drawn on the Pest's own canvas item) are deliberately
## screen-locked — PLATE_FROM/PLATE_TO already carve out the top of the ring
## because "the health bar lives up there", and a marker that spun with travel
## direction would fight that same fixed layout.
##
## STYLE.md's convention is up-screen (-Y) at rest, i.e. rotation 0 here; the
## other three are 90-degree turns off that art, which Godot's rotation turns
## clockwise: +90 deg (PI/2) faces +X (right), 180 deg faces +Y (down), -90 deg
## faces -X (left).
func _update_facing(direction: Vector2) -> void:
	if _sprite == null:
		return
	if absf(direction.x) < 0.01 and absf(direction.y) < 0.01:
		return
	if absf(direction.x) > absf(direction.y):
		_facing = PI / 2.0 if direction.x > 0.0 else -PI / 2.0
	else:
		_facing = PI if direction.y > 0.0 else 0.0
	_apply_facing()


## The one place `_sprite.rotation` is written. Facing and gait each own one
## term of the sum and neither can clobber the other; with animations off
## `_sway` is a standing 0.0, so this reduces to exactly the bare cardinal
## rotation that shipped before the gait existed — a correct static state, not
## a half-applied transform.
func _apply_facing() -> void:
	if _sprite != null:
		_sprite.rotation = _facing + _sway


## One step of the walk cycle. Advances the clock unconditionally, the same way
## Plant._wobble() does, so a mid-run animations toggle picks up a meaningful
## phase instead of every pest on the board snapping from a frozen 0.
func _gait(delta: float) -> void:
	_gait_time += delta
	if _sprite == null or not GardenTheme.animations_enabled():
		return
	var clock: float = _gait_time * gait_rate(speed, is_armoured, is_winged) + _gait_phase
	_sway = sin(clock) * gait_swing(is_armoured, is_winged)
	_apply_facing()
	# Local to the sprite, so it follows the facing rotation: -Y is the body's
	# long axis (STYLE.md's up-screen convention), which makes +Y stretch a
	# lengthening and -X squash a narrowing, whichever way the bug is walking.
	var stretch: float = gait_stretch(sin(clock * GAIT_STRETCH_RATE), is_hungry)
	_sprite.scale = Vector2(_sprite_scale * (1.0 - stretch), _sprite_scale * (1.0 + stretch))


## Pure: how fast this pest's walk cycle runs, in radians of clock per second.
## Split out (with the two below) so the whole gait is assertable without a
## viewport, a frame, or animations being on at all.
static func gait_rate(for_speed: float, armoured: bool, winged: bool) -> float:
	var scaled: float = clampf(for_speed / GAIT_REFERENCE_SPEED, GAIT_RATE_MIN, GAIT_RATE_MAX)
	var rate: float = GAIT_RATE * scaled
	if winged:
		rate *= WINGED_RATE_MULTIPLIER
	if armoured:
		rate *= ARMOURED_RATE_MULTIPLIER
	return rate


## Pure: peak yaw either side of the direction of travel, in radians. Both
## multipliers apply to a pest carrying both traits — markers_for() promises the
## same thing about the drawn marks, and a gait that quietly picked one would
## contradict a rule this file already advertises.
static func gait_swing(armoured: bool, winged: bool) -> float:
	var swing: float = GAIT_SWING
	if winged:
		swing *= WINGED_SWING_MULTIPLIER
	if armoured:
		swing *= ARMOURED_SWING_MULTIPLIER
	return swing


## Pure: the body-axis stretch for one point of the stride wave (`wave` in
## -1..1). A hungry pest's is cubed rather than merely larger: cubing flattens
## the middle of the wave and keeps the extremes, so the body sits still and
## then snaps — a lunge. Raising the amplitude alone would only have given the
## same scuttle, bigger.
static func gait_stretch(wave: float, hungry: bool) -> float:
	if hungry:
		return wave * wave * wave * GAIT_STRETCH * HUNGRY_STRETCH_MULTIPLIER
	return wave * GAIT_STRETCH


## Pure: the phase the `index`-th pest spawned this run walks on.
static func gait_phase(index: int) -> float:
	return fposmod(float(index) * GAIT_PHASE_STEP, TAU)


func take_damage(amount: float, cause: StringName = &"") -> void:
	if not _alive:
		return
	# A zero-damage call is not an engagement. Nothing in the game makes one
	# today, but `amount` is a float off a kernel and a plant level table, and
	# "something shot at it" must mean something landed.
	if amount > 0.0:
		_ever_engaged = true
	health = maxf(0.0, health - amount)
	if is_instance_valid(_health_bar):
		_health_bar.size = Vector2(HEALTH_BAR_SIZE.x * (health / max_health), HEALTH_BAR_SIZE.y)
	if health <= 0.0:
		kill(cause)


## Pure: what `flash_hit` boosts a sprite's current tint towards for the flash's
## rising half — alpha untouched, so a partially transparent state (mid death
## fade, say) stays exactly as transparent while it flashes. Split out so the
## picture is checkable without a live tree, a Tween, or animations turned on.
static func hit_flash_color(base: Color) -> Color:
	return Color(base.r * HIT_FLASH_BOOST, base.g * HIT_FLASH_BOOST, base.b * HIT_FLASH_BOOST, base.a)


## The visual tell for a hit this pest survived. Called by Kernel right after a
## connecting take_damage() that did NOT kill — see HIT_FLASH_DURATION's comment
## for why a lethal hit does not also call this (it has its own, bigger cue).
##
## Gated the same way every cosmetic Tween in this game is: headless pumps no
## frames, so a Tween queued there never runs and this is a silent no-op rather
## than a wasted node.
func flash_hit() -> void:
	if not _alive or _sprite == null or not is_inside_tree() or not GardenTheme.animations_enabled():
		return
	var base: Color = _sprite.modulate
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", hit_flash_color(base), HIT_FLASH_DURATION * 0.35)
	tween.tween_property(_sprite, "modulate", base, HIT_FLASH_DURATION * 0.65)


## Death by any cause — kernels, or a Chomp finishing its meal.
func kill(cause: StringName = &"") -> void:
	if not _alive:
		return
	_alive = false
	_death_cause = cause
	if held_by != null and held_by.has_method("release"):
		held_by.call("release")
	died.emit(self)
	_play_death()


## Swaps in the doc's "X-eyed pest" corpse sprite and lingers a beat before
## freeing, rather than the pest just vanishing — a separate sprite, not a tint,
## per the sprite-pass-2 ask. Deferred so a listener of `died` (Game awards
## seeds and drops a compost husk) still sees a valid global_position.
func _play_death() -> void:
	set_physics_process(false)
	if _health_back != null:
		_health_back.visible = false
	if _health_bar != null:
		_health_bar.visible = false
	# set_physics_process(false) above stops the gait but does not undo it, and a
	# corpse frozen at whatever quarter of a stride it died on reads as a bug
	# still leaning into a step. Put the sprite back on its facing and its own
	# scale so the husk lies straight under the fade below. `_facing` is kept,
	# not zeroed: a beetle killed walking left should lie facing left.
	if _sprite != null:
		_sway = 0.0
		_sprite.rotation = corpse_rotation()
		_sprite.scale = corpse_scale()
	if _dead_texture != null and _sprite != null:
		_sprite.texture = _dead_texture
		_sprite.modulate = Color.WHITE
	# The corpse drops the tint, so it drops the markers with it — a dead pest
	# still wearing wings would read as a threat the player still has to answer.
	queue_redraw()
	if not is_inside_tree():
		queue_free()
		return
	# Bound to self: Godot kills a node's own tweens when the node frees, so a
	# teardown that frees the tree immediately (free_ui, not queue_free) never
	# fires this callback on a dangling instance.
	var tween := create_tween()
	if GardenTheme.animations_enabled():
		# Full opacity for most of the linger, then fade the tail end — same
		# "hold, then go" shape as the rest of a corpse's beat, just on alpha
		# instead of a callback. Plant.play_exit_and_free() is the reference:
		# a tween on the way off the board, gated the same way.
		tween.tween_interval(DEATH_LINGER - DEATH_FADE)
		tween.tween_property(_sprite, "modulate:a", 0.0, DEATH_FADE)
	else:
		tween.tween_interval(DEATH_LINGER)
	tween.tween_callback(queue_free)


## How the corpse lies, as a predicate rather than a branch inside `_play_death()`
## — the same reason PlacementPreview.new_cover_cells() is one. A corpse is on
## screen for DEATH_LINGER and then gone, so a rule readable only from a
## screenshot is a rule that gets checked once.
##
## Straight on the pest's own facing for everything except a blast. `_facing` is
## kept rather than zeroed for the reason the corpse code has always kept it: a
## beetle killed walking left should lie facing left.
func corpse_rotation() -> float:
	if _death_cause == DEATH_BLASTED:
		return _facing + BLASTED_TILT
	return _facing


## The corpse's own scale. Squashed along the body axis when something chewed it,
## full size otherwise.
##
## Note this squashes X, not Y: the sprite rests head-up-screen (art_src/STYLE.md)
## and `_sprite.rotation` carries the facing, so the body's long axis is always
## local Y whichever way the pest was walking. Squashing Y would shorten the
## corpse nose-to-tail, which is a pest that shrank; squashing X narrows it, which
## is a pest that was closed on.
func corpse_scale() -> Vector2:
	if _death_cause == DEATH_BITTEN:
		return Vector2(_sprite_scale * BITTEN_SQUASH, _sprite_scale)
	return Vector2(_sprite_scale, _sprite_scale)


func is_alive() -> bool:
	return _alive


## True once anything in the garden has touched this pest — a kernel that landed
## or a Chomp that held it. False for one that walked the whole road unopposed.
##
## Read by Game._note_escape at the instant `escaped` fires, which is the last
## moment it can be: _escape() emits and then queue_frees, so a listener that
## deferred the read would get a freed instance.
func was_engaged() -> bool:
	return _ever_engaged


## 1.0 for a plain pest; higher for a mutation, so a harder kill leaves a
## better husk. Game._on_pest_died reads this when it drops one.
func husk_multiplier() -> float:
	return float(MUTATION_HUSK_MULTIPLIER.get(mutation, 1.0))


func _escape() -> void:
	if not _alive:
		return
	_alive = false
	escaped.emit(self)
	queue_free()


## 0.0 at the entrance, 1.0 at the exit. Targeting uses this to shoot whichever
## pest is furthest along rather than whichever happens to be nearest.
func progress() -> float:
	if _route.size() < 2:
		return 0.0
	return clampf(float(_leg) / float(_route.size() - 1), 0.0, 1.0)
