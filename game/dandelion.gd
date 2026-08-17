class_name Dandelion
extends Plant

## The fifth plant, and the first one that hits more than one thing at a time.
##
## The ask it ships for, in the owner's own words: "an animated dandelion that
## blows its seeds as bombs". So all three halves of it are load-bearing —
## the seeds ARC and DETONATE (SeedBomb, which travels to a point rather than in a
## direction), the head visibly LOSES FLUFF as it fires (four authored frames,
## swapped off `_fluff`), and it arrives out of a new `epic` packet tier above
## common and rare.
##
## WHY IT IS NOT A LONGER-RANGED CORN COBBLER
##
## Everything already in the catalogue answers pests one at a time. A Corn Cobbler
## puts a kernel through ONE pest (Kernel.HIT_RADIUS is 18 px, centre to centre,
## and off-axis kernels in a bunch miss anything past 80 px). A Chomp Flower holds
## ONE. A Sundew slows a patch but does no damage at all, and a Sunflower never
## touches a pest. Nothing in the game had ever damaged two pests with one action.
##
## So this one only damages groups, and it is priced as if that is all it does:
##
##   * MAGAZINE, NOT A FIRE RATE. A cob fires forever on a clock. This holds
##     FLUFF_MAX seeds and has to grow them back, so it is a burst weapon with a
##     long reload rather than a stream — and the reload is the picture (see
##     FLUFF_TEXTURES). At the numbers below one Dandelion sustains 1.48 dps
##     against a lone pest, which is LESS than a 10-seed level-1 Corn Cobbler's
##     1.25... within a rounding error of it, for 4.5x the price. Against three
##     pests standing together it is 4.44 dps, which nothing else in the game can
##     reach at any price.
##   * IT LEADS NOTHING. The seed is aimed where the pest was at launch and takes
##     SeedBomb.FLIGHT_SECONDS to arrive. An aphid at 78 px/s walks 43 px in that
##     time and ends up out near the rim, where SeedBomb.BLAST_EDGE_FRACTION cuts
##     the damage to 40%; a beetle at 38 px/s walks 21 px and takes nearly all of
##     it. This plant is good against slow, big, clumped things and bad against
##     single fast ones — the exact inverse of a Chomp Flower, which cannot touch
##     a winged pest and eats an aphid in 0.45s.
##   * IT PAIRS WITH THE SUNDEW, AND THAT IS DELIBERATE. A patch at SLOW_FACTOR
##     0.55 cuts an aphid's flight-time drift from 43 px to 24 px, i.e. from the
##     soft rim to nearly dead centre. The two most expensive plants in the game
##     are the two that make each other better, which is what a tier-3 seed should
##     buy: a reason to have built something else first.
##
## Balance summary, against the four it stands beside:
##
##   plant           cost  reach  what it does to a pest
##   Corn Cobbler      10    176  1 pest, 1.25 dps (level 1), forever
##   Chomp Flower      15     74  1 pest, held then killed, mouth busy meanwhile
##   Seed Sunflower    25      0  nothing; pays for the others
##   Sticky Sundew     30    118  every pest in the patch, slowed 45%, no damage
##   Bomb Dandelion 45    192  every pest within 46 px of the landing point,
##                                3.0 dmg at the centre falling to 1.2 at the rim,
##                                two seeds a volley, ~4s between volleys

## The furthest a seed is thrown. Longer than a Corn Cobbler's 176 because this is
## artillery — but the extra 16 px is nearly nothing, and it is not what the 45
## seeds buy. What they buy is the blast; the range is only enough that a
## Dandelion parked behind a row of cobs still reaches the road they cover.
const RANGE: float = 192.0

## Seeds on the head at once, and therefore also the number of authored frames
## minus one — FLUFF_TEXTURES is indexed by this directly, so the picture cannot
## disagree with the count. Raising this needs another drawing, which is the right
## amount of friction for a number that is also an animation.
const FLUFF_MAX: int = 3

## The head will not open fire until it has grown back at least this many seeds,
## and once it does it empties itself all the way down to zero.
##
## Without it the plant is not a burst weapon at all: it would fire the instant a
## single seed finished growing, sit at 0-1 fluff for the whole of every wave, and
## the four frames would only ever show the bald one. That is the failure the
## owner's ask names outright — "it should regrow between volleys or the plant
## runs out of picture". With it, a Dandelion visibly fills up, empties, and fills
## again, and the fluff on the head is an honest readout of how much burst is
## banked. See volley_open() for the rule as a pure function.
const VOLLEY_MIN_FLUFF: int = 2

## Seconds between two seeds of the SAME volley. Short — a volley should read as
## one act, not as a slow drip.
const SHOT_INTERVAL: float = 0.45

## How long after the last seed left before the head starts growing another, and
## how long each one then takes.
##
## The delay is what stops a volley from refilling itself mid-volley (which would
## make VOLLEY_MIN_FLUFF meaningless and the plant a stream again), and together
## they set the whole tempo: a spent head is armed again after
## REGROW_DELAY + VOLLEY_MIN_FLUFF * FLUFF_REGROW_SECONDS = 3.6s, and completely
## full after REGROW_DELAY + FLUFF_MAX * FLUFF_REGROW_SECONDS = 4.9s. Both are
## comfortably inside Game.PREP_SECONDS (18), so a Dandelion is always at a full
## head when a wave arrives — the burst is banked during the calm and spent in the
## fight, which is the shape the whole plant is built around.
const REGROW_DELAY: float = 1.0
const FLUFF_REGROW_SECONDS: float = 1.3

## What one seed does at the dead centre of its blast. SeedBomb.damage_falloff()
## slides this down to 1.2 at the rim.
##
## Calibrated against the two pests: an aphid has 3 health, so a centre hit kills
## one outright and a rim hit does not. A beetle has 16, so a full three-seed head
## dead-centre takes 9 off it — over half — and the pair a steady volley delivers
## takes 6. Neither pest is one-shot by a volley, which keeps the Corn Cobbler
## that has to finish them worth owning.
const SEED_DAMAGE: float = 3.0

## fluff count -> the frame the head wears. Indexed by `_fluff` directly, so the
## drawing and the state cannot drift: there is no mapping table to keep in step,
## and a fifth seed would fail on the array bound rather than silently reusing the
## last picture. See art_src/dandelion.svg for why every frame's tuft set is
## symmetric about the vertical axis.
const FLUFF_TEXTURES: Array[String] = [
	"res://assets/sprites/dandelion_bare.png",
	"res://assets/sprites/dandelion_sparse.png",
	"res://assets/sprites/dandelion_thinning.png",
	"res://assets/sprites/dandelion.png",
]

## The selection ring. Sand rather than green: CornCobbler already owns a green
## ring at RANGE and the two plants would otherwise be telling the player the same
## thing in the same colour at nearly the same radius.
const RING_FILL := Color(0.93, 0.86, 0.72, 0.10)
const RING_EDGE := Color(0.65, 0.61, 0.51, 0.55)
## The blast preview, drawn at the last place this plant actually threw a seed —
## the one number a player cannot infer from the range ring, and the whole reason
## to buy the plant.
const BLAST_PREVIEW_FILL := Color(1.0, 0.93, 0.78, 0.13)
const BLAST_PREVIEW_EDGE := Color(0.65, 0.61, 0.51, 0.7)

## The head's recoil as a seed leaves it. A puff, not CornCobbler's sideways
## squash: the seed goes UP and OUT of the top of the head, so the head stretches
## upward after it and settles back.
const PUFF_SCALE := Vector2(0.92, 1.12)

var _fluff: int = FLUFF_MAX
## Seconds until the next seed of the current volley may leave.
var _shot_cooldown: float = 0.0
## Seconds since the last seed left. Regrowth is gated on this, which is the whole
## reason a volley cannot refill itself halfway through.
var _since_shot: float = REGROW_DELAY
## Seconds of growing left before the next seed appears on the head.
var _regrow_left: float = FLUFF_REGROW_SECONDS
## Whether the head is currently emptying itself. See VOLLEY_MIN_FLUFF.
var _volley_open: bool = true
## Where the last seed was thrown, in this plant's own space. Drawn as the blast
## preview while selected; Vector2.ZERO before the plant has ever fired, which is
## why _has_fired gates the preview rather than a zero check (the plant's own cell
## is a legitimate landing point).
var _last_landing: Vector2 = Vector2.ZERO
var _has_fired: bool = false
## stem -> Texture2D, loaded once each. The head swaps frames on every shot and on
## every regrown seed, which is far too often to be calling load().
var _frames: Dictionary = {}


func _on_setup() -> void:
	_refresh_fluff_sprite()


func _act(delta: float, pests: Array[Pest]) -> void:
	_since_shot += delta
	_shot_cooldown = maxf(0.0, _shot_cooldown - delta)
	_grow_fluff(delta)
	_volley_open = volley_open(_fluff, _volley_open)
	if not _volley_open or _fluff <= 0 or _shot_cooldown > 0.0:
		return
	var target: Pest = best_target(pests)
	if target == null:
		return
	_launch_at(target.global_position - global_position)


## One step of the head growing back. Loops rather than adding one seed per call
## so a long `delta` — a devtools `step-time`, a stalled frame — grows everything
## it has earned instead of silently capping at one.
func _grow_fluff(delta: float) -> void:
	if delta <= 0.0:
		return
	if _fluff >= FLUFF_MAX:
		_regrow_left = FLUFF_REGROW_SECONDS
		return
	if _since_shot < REGROW_DELAY:
		return
	_regrow_left -= delta
	var grew: bool = false
	while _regrow_left <= 0.0 and _fluff < FLUFF_MAX:
		_fluff += 1
		_regrow_left += FLUFF_REGROW_SECONDS
		grew = true
	if _fluff >= FLUFF_MAX:
		_regrow_left = FLUFF_REGROW_SECONDS
	if grew:
		_refresh_fluff_sprite()


## Which pest to throw at: whichever one's blast would catch the MOST pests, and
## among equals the one furthest along the road.
##
## Deliberately not Plant._furthest_along_in_range(), which every other engaging
## plant uses. That rule is right for a single-target weapon — leaking a pest costs
## a life, so shoot the leader — and wrong for this one: a seed thrown at a lone
## leader while three more walk together six cells back throws away the only thing
## this plant does better than a 10-seed cob. Progress is still the tie-break, so
## with nothing clumped it degrades to exactly the usual rule.
func best_target(pests: Array[Pest]) -> Pest:
	var here: PackedVector2Array = PackedVector2Array()
	for pest: Pest in pests:
		here.append(pest.global_position)
	var best: Pest = null
	var best_caught: int = 0
	var best_progress: float = -1.0
	for pest: Pest in pests:
		if pest.global_position.distance_to(global_position) > RANGE:
			continue
		var catches: int = SeedBomb.caught(pest.global_position, here)
		var progress: float = pest.progress()
		if catches > best_caught or (catches == best_caught and progress > best_progress):
			best = pest
			best_caught = catches
			best_progress = progress
	return best


func _launch_at(offset: Vector2) -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(896, 576))
	if board != null:
		bounds = Rect2(Vector2.ZERO, board.board_size())
	var bomb := SeedBomb.new()
	get_parent().add_child(bomb)
	# `position`, not `global_position`, plus a global-space DELTA — the one
	# combination that lands in the right place in both spaces. See SeedBomb's
	# header for what the other combinations do.
	bomb.setup(position, position + offset, SEED_DAMAGE, bounds)
	_last_landing = offset
	_has_fired = true
	_fluff -= 1
	# Re-evaluated HERE and not only at the top of the next _act(). The seed that
	# empties the head closes the volley, and a flag that only caught up a frame
	# later would have is_volley_open() reporting "mid-volley" on a plant with
	# nothing left to fire — which is what the selection panel reads.
	_volley_open = volley_open(_fluff, _volley_open)
	_shot_cooldown = composed_interval(SHOT_INTERVAL, fire_interval_scale,
		neighbour_interval_scale)
	_since_shot = 0.0
	_refresh_fluff_sprite()
	Sfx.play(Sfx.DANDELION_PUFF)
	_puff()
	queue_redraw()


# ------------------------------------------------------------------ pure model

## Pure: whether a head holding `fluff` seeds, which was or was not already
## emptying itself, is firing this frame.
##
## The whole of VOLLEY_MIN_FLUFF as a function, so the tempo is assertable without
## a tree, a wave or a frame — and so the hysteresis is stated once. It IS
## hysteresis and has to be: a plain `fluff >= VOLLEY_MIN_FLUFF` test would stop
## the volley the moment it dropped to one seed, so the head would never reach the
## bald frame and would sit oscillating between two and one forever.
static func volley_open(fluff: int, was_open: bool) -> bool:
	if fluff >= VOLLEY_MIN_FLUFF:
		return true
	if fluff <= 0:
		return false
	return was_open


## Pure: the frame a head holding `fluff` seeds wears. Clamped rather than
## bounds-checked so a caller reasoning about a hypothetical count still gets a
## picture, but the real caller can never be out of range — `_fluff` only ever
## moves by one, between 0 and FLUFF_MAX.
static func texture_for_fluff(fluff: int) -> String:
	return FLUFF_TEXTURES[clampi(fluff, 0, FLUFF_TEXTURES.size() - 1)]


## Pure: seconds from a spent head to the next seed leaving it.
static func rearm_seconds() -> float:
	return REGROW_DELAY + float(VOLLEY_MIN_FLUFF) * FLUFF_REGROW_SECONDS


## Pure: seconds from one volley starting to the next one starting, in the steady
## state where there is always something to shoot at — the reload plus the seeds
## of the volley itself.
static func volley_cycle_seconds() -> float:
	return rearm_seconds() + float(VOLLEY_MIN_FLUFF - 1) * SHOT_INTERVAL


## Pure: sustained damage per second against `pests_in_blast` pests standing dead
## centre. This is the number the plant is priced on and the claim its header
## makes, so it is executable rather than a comment: at 1 it must stay in the
## neighbourhood of a level-1 Corn Cobbler's 1.25, and at 3 it must beat anything
## else in the catalogue.
static func sustained_dps(pests_in_blast: int) -> float:
	var cycle: float = volley_cycle_seconds()
	if cycle <= 0.0:
		return 0.0
	return float(VOLLEY_MIN_FLUFF) * SEED_DAMAGE * float(maxi(pests_in_blast, 0)) / cycle


## Pure: how far a pest walking at `speed` drifts out of the blast while the seed
## is in the air. The plant's whole weakness as one number — see the header for
## what it does to an aphid versus a beetle.
static func lead_error(speed: float) -> float:
	return maxf(0.0, speed) * SeedBomb.FLIGHT_SECONDS


## Pure: the fraction of a centre hit a pest walking at `speed` actually takes,
## assuming it walks straight away from the landing point for the whole flight.
## The worst case, deliberately: a pest walking across the blast rather than out of
## it takes more than this, never less.
static func damage_fraction_against(speed: float) -> float:
	return SeedBomb.damage_falloff(lead_error(speed))


# --------------------------------------------------------------------- readouts

## Seeds currently on the head. What the sprite frame is, and what the selection
## panel prints.
func fluff() -> int:
	return _fluff


## Whether the head is mid-volley right now.
func is_volley_open() -> bool:
	return _volley_open


## The frame the head is ACTUALLY wearing right now, as a resource path.
##
## The whole of what this plant was asked for is "it visibly loses fluff as it
## fires", and that claim is not checkable from `_fluff`: a count that moves while
## the picture does not is precisely the bug. This reads the texture off the live
## Sprite2D, so a test asserts the drawing changed rather than the number.
##
## "" for a plant whose visuals were never built — a bare `Dandelion.new()` driven
## through `_act` in a unit test, which is most of them.
func head_texture_path() -> String:
	if _sprite == null or _sprite.texture == null:
		return ""
	return _sprite.texture.resource_path


## Seconds until this head can throw again — 0.0 while it is mid-volley. Reads the
## live clocks rather than the constants, so a head interrupted halfway through
## growing reports what is left rather than a fresh reload.
func seconds_until_armed() -> float:
	if _volley_open and _fluff > 0:
		return _shot_cooldown
	var wait: float = maxf(0.0, REGROW_DELAY - _since_shot)
	var needed: int = VOLLEY_MIN_FLUFF - _fluff
	if needed <= 0:
		return 0.0
	var growing: float = maxf(0.0, _regrow_left) + float(needed - 1) * FLUFF_REGROW_SECONDS
	return wait + growing


# ---------------------------------------------------------------------- visuals

func _refresh_fluff_sprite() -> void:
	if _sprite == null:
		return
	var path: String = texture_for_fluff(_fluff)
	if not _frames.has(path):
		_frames[path] = load(path) as Texture2D
	var texture: Texture2D = _frames[path] as Texture2D
	if texture != null:
		_sprite.texture = texture


## Note there is no super._draw() call here, and there must not be: the selection
## brackets live in a SelectionMarker child precisely because an override like
## this one eats them. See SelectionMarker's header.
func _draw() -> void:
	if not _selected:
		return
	draw_circle(Vector2.ZERO, RANGE, RING_FILL)
	draw_arc(Vector2.ZERO, RANGE, 0.0, TAU, 48, RING_EDGE, 2.0, true)
	if not _has_fired:
		return
	draw_circle(_last_landing, SeedBomb.BLAST_RADIUS, BLAST_PREVIEW_FILL)
	draw_arc(_last_landing, SeedBomb.BLAST_RADIUS, 0.0, TAU, 24, BLAST_PREVIEW_EDGE, 2.0, true)


## Gated the same way every cosmetic Tween in this game is: headless pumps no
## frames, so a Tween queued there never runs and this is a silent no-op.
func _puff() -> void:
	if _sprite == null or not is_inside_tree() or not GardenTheme.animations_enabled():
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", PUFF_SCALE, 0.06)
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.14)
