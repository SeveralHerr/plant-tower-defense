class_name CornCobbler
extends Plant

## The ranged plant. The design doc draws it twice: one cob firing a single
## kernel, and the same cob firing a spray labelled "bunch of corn". That is the
## upgrade ladder, so it is the upgrade ladder here — three levels, each one
## visibly wider than the last.

const RANGE: float = 176.0

## The angle between one kernel and the next, the same at every level. This is the
## constant the whole upgrade ladder is built on, and it is what keeps an upgrade
## from being a downgrade.
##
## A spread is only free if the kernels you already had stay where they were. When
## the ladder was 1 -> 2 -> 5 kernels over 0 -> 14 -> 52 degrees, each level
## re-spaced its kernels from scratch, so paying for one MOVED the shots you had
## rather than adding to them. Both of the resulting holes were real:
##
##   * Level 2's two kernels sat at +/-7 deg with nothing on the aim line. A kernel
##     fired `t` off the line passes a pest on the line at Kernel.HIT_RADIUS / sin t,
##     so +/-7 deg stopped connecting at 148 px — inside RANGE (176). Between 148 px
##     and the edge of its own ring, the 20-seed level did *zero* damage to the pest
##     it was aiming at, where level 1 did 1.25 dps.
##   * Level 3 re-spaced to +/-26, +/-13, 0. The outer pair stops connecting at 41 px
##     and the inner pair at 80 px, so past 80 px only the middle kernel ever landed:
##     1.61 dps against the 2.78 dps the *cheaper* level 2 was doing. The most
##     expensive upgrade in the game made the cob worse at the thing it aimed at.
##
## Fixed step + odd counts fixes both by construction. Every level fires through
## KERNEL_STEP_DEGREES * (kernels - 1) degrees, kernels are always odd, and each
## level adds one pair to the outside of the level below. So level N's firing angles
## are a strict superset of level N-1's, every level keeps a kernel on the aim line,
## and the interval only ever shortens and the damage only ever rises. Together those
## mean level N hits at least everything level N-1 would have hit, at least as hard,
## at least as often — at every range, against any arrangement of pests. There is no
## configuration left in which upgrading can lose.
##
## Off-axis kernels are still situational (see `reach_at_offset`): past 80 px the
## bunch is one kernel plus four warning shots. `damage` is what the player is
## actually buying at long range, and it is why it climbs with the level rather than
## sitting flat at 1.0 the way it used to.
const KERNEL_STEP_DEGREES: float = 13.0

## level -> firing pattern. `spread_degrees` is the total arc the kernels cover, and
## it is always KERNEL_STEP_DEGREES * (kernels - 1) — `test_combat` pins that, so a
## hand-typed spread that breaks the nesting fails rather than shipping. It is the one
## number in this table that another number in this table implies, and it is written out
## anyway because a ladder is retuned by reading the columns side by side; the pin is
## what makes that affordable, and it is the only exception the rule below has.
##
## ---------------------------------------------------------------------------------
## THE RULE THIS TABLE IS READ BY
##
## **If the answer changes when a row here changes, it is a pure static over LEVELS
## taking `for_level` — never a literal, never a branch on the level number, and never
## recomputed beside a caller that already had the row in hand.**
##
## That is not a preference, it is three bugs, and each of the statics below this table
## is one of them already fixed. They read as three unrelated helpers, which is exactly
## why the rule never transferred: what they have in common was never written down, so
## the fourth question got answered wherever it was asked. Here is the common part.
##
##   * `kernel_angle_offsets` — TWO SUBSYSTEMS ASKED THE SAME QUESTION. Firing and
##     drawing each spaced their own kernels, so an upgrade could widen the shot without
##     widening the picture. One function, and the fan cannot lie about the volley.
##   * `spread_arc_span` — A CALL SITE RESTATED A ROW. `_draw_muzzle_fan` carried a
##     branch of its own for "level 1 gets no arc", which is `kernels == 1` wearing a
##     level number; cycle 70 watched a mutation to that branch survive a test that only
##     ever asked `kernel_angle_offsets`. Which levels wear an arc, and how wide, is one
##     pure function now, and the draw site READS it rather than measuring the two
##     outermost offsets for itself — which is what it went back to doing, silently,
##     while three separate comments claimed otherwise.
##   * `upgrade_spend` — A TOTAL THE TABLE IMPLIES AND NOBODY STORES. The climb is 20
##     then 45, and a hand-typed 65 is a second source of truth that a retune silently
##     falsifies — on the number the player is told they are forfeiting.
##
## Three callers, three different failures, one rule. The tells that you are about to
## break it, in the order they show up: a literal that is arithmetic over a row; a
## comparison against a level NUMBER standing in for a property of the row; the same
## derivation appearing at two call sites in different subsystems.
##
## Take `for_level`, not this cob's `level`. The callers that most need these answers are
## asking about a rung nothing is standing on — `Hud.message_corpus` prices the armed
## prompt at the ladder's maximum, which no instance can answer.
##
## Where a new one goes. If the question is about A LADDER, it belongs on `Plant` beside
## `ladder_row` / `ladder_upgrade_cost` / `ladder_spend`, and every future ladder gets it
## for free. If it is about CORN, it goes here, under this rule.
## `test_placement.test_every_level_taking_static_on_the_cob_is_exercised_across_the_ladder`
## derives the set of `static func f(for_level: int)` straight out of this file and fails
## on one no test names, so a fourth question added under this rule cannot arrive
## unasserted the way the three above each did.
##
## And the obvious fourth question is already answered, twice. "What does it cost to
## REACH level N" is `upgrade_spend(for_level)` here and `Plant.ladder_spend(ladder,
## for_level)` generically. It looks missing because `upgrade_cost()` answers only the
## next step and reads like the whole of the subject. Do not add a third name for it.
## ---------------------------------------------------------------------------------
const LEVELS: Array[Dictionary] = [
	{"name": "single", "kernels": 1, "spread_degrees": 0.0, "interval": 0.80, "damage": 1.0, "upgrade_cost": 20},
	{"name": "triple", "kernels": 3, "spread_degrees": 26.0, "interval": 0.72, "damage": 1.2, "upgrade_cost": 45},
	{"name": "bunch", "kernels": 5, "spread_degrees": 52.0, "interval": 0.62, "damage": 1.4, "upgrade_cost": 0},
]

## Muzzle fan geometry. The upgrade ladder used to be invisible on the board —
## paying 45 seeds changed a line in the selection panel and nothing else — so
## every cob now wears the shot it actually fires: one pip per kernel, laid out on
## the angles `kernel_angle_offsets` hands to `_fire_at`, with a thin arc spanning
## the outer two. Drawing and firing read the same function, so the picture cannot
## drift away from the behaviour the way a hand-drawn "level 3 is bushier" badge
## would — retune LEVELS and the board retunes with it.
##
## The fan is projected from a pivot FAN_PIVOT behind the cob rather than measured
## from the cob's centre. That magnifies the angles about a common origin: a single
## KERNEL_STEP_DEGREES step is a 7.7 px gap between neighbouring pips this way and
## barely 3 px measured from the cob's centre — pips fused into one blob, i.e.
## exactly the "looks the same as level 1" bug this is fixing. The
## projection is monotonic and shares its input with the shot, so wider spread is
## always a wider fan and level 1's zero spread is still a single pip; it makes a
## true difference visible rather than inventing one.
##
## FAN_LENGTH - FAN_PIVOT puts the centre pip at 20 px, out on the sprite's
## shoulder, and the whole fan inside a radius of ~26 — clear of the 32 px cell
## edge, and a directional spray of filled dots on one side rather than anything
## ring-shaped, so it reads as neither the RANGE ring (green, 176 px, selected
## only) nor SelectionMarker's four thin corner brackets.
##
## "Inside a radius of ~26" is now a measurement rather than an estimate: the widest pip
## rim sits at 25.88 from the plant's centre, computed off `muzzle_pips()` in
## `ReadoutBand` (game/readout_band.gd). The fan is listed there as NOT radial, because
## FAN_PIVOT is the whole reason — the pips are at a fixed radius from the pivot and a
## moving one from the plant, so a radius interval is the wrong shape for this mark and a
## directional spray is what tells it apart. Read that file before adding a mark to any
## plant; the radii ARE finite, and the cob's are the only ones in the band that move.
const FAN_PIVOT: float = 14.0
const FAN_LENGTH: float = 34.0
const PIP_SIZE: float = 2.4
const PIP_RIM_WIDTH: float = 1.2
## Corn gold over a dark rim: a bare yellow dot this small dissolves into both a
## grass tile and the cob's own sprite, and the rim is what keeps it legible.
const PIP_COLOR := Color(1.0, 0.78, 0.20, 0.95)
const PIP_RIM_COLOR := Color(0.24, 0.16, 0.04, 0.9)
const SPREAD_ARC_COLOR := Color(1.0, 0.78, 0.20, 0.45)

## The muzzle's floor brightness the instant a volley fires. Never 0 — the fan
## is the picture of what an upgrade bought, and a fired cob should still show
## it, just dimmed, not disappear until the reload completes.
const READY_ALPHA_FLOOR: float = 0.35
## Repaint granularity for the readiness fade — discipline borrowed from
## Sunflower's `_drawn_fill_height`: a 0.6-0.8s reload does not need a fresh
## frame for every sub-percent of progress, only for the visible steps a fade
## across READY_ALPHA_FLOOR..1.0 actually paints.
const READINESS_STEPS: int = 24

## Repaint granularity for the AIM, and the same discipline READINESS_STEPS applies
## to the fade — a bound on repaints, not on the picture.
##
## The fan now follows the cob's CURRENT target rather than its last shot, so
## `_aim_angle` moves every physics tick a target walks. Repainting on every one of
## those would put a queue_redraw() per plant per frame on a board that can hold a
## dozen cobs, to move a pip by a fraction of a pixel. So the aim is STORED exactly
## and PAINTED exactly — nothing is quantised into the shot — and only the decision
## to repaint is bucketed: one repaint per AIM_STEPS of a full turn.
##
## 48 buckets is 7.5 degrees, which moves the outermost pip of a level-3 fan by about
## 3 px (`aim_step_pip_travel`) — a step a player reads as the fan turning rather than
## as it jumping. A pest crossing a cob's whole reach sweeps well under half a turn, so
## this caps the aim at roughly twenty repaints for the entire pass, against the ~600
## physics ticks that pass takes.
const AIM_STEPS: int = 48

## `level` is NOT declared here any more — it is `Plant.level`, along with
## `upgrade()`, `upgrade_cost()`, `level_name()`, `max_level()`, `is_max_level()`
## and the spend. This class kept all of it for ninety-nine cycles and the ladder
## below is all that was ever cob-specific about it; see Plant's "Upgrades" block
## for why the machinery moved and the numbers did not.
var _cooldown: float = 0.0
## Where the fan points: at the pest this cob would shoot RIGHT NOW, updated every
## tick `_act` runs, whether or not the volley is armed.
##
## It used to be written only inside `_fire_at`, which made the fan a post-view
## wearing the shape of a preview — a cob showed where it HAD shot, one frame after
## that stopped being the useful question, and a freshly planted cob pointed due east
## at nothing until its first volley. The player's question is "which way will this
## thing shoot", and it is asked hardest in the seconds BEFORE it shoots.
##
## Still 0.0 at rest, and that is honest rather than lazy: with nothing in range there
## is no target to point at, so the fan holds the last direction it was given (or east
## on a cob that has never seen a pest). What it must never do again is hold a
## direction while a different pest is standing in range.
var _aim_angle: float = 0.0
## Last readiness step actually painted; -1 means "nothing painted yet".
var _drawn_readiness_step: int = -1
## Last aim bucket actually painted; -1 means "nothing painted yet". Same job as
## `_drawn_readiness_step`, for the other thing that moves the fan.
var _drawn_aim_step: int = -1
## How many repaints the AIM has asked for over this cob's life.
##
## Counted rather than reasoned about because the bead this came from asks for the
## redraw rate to be MEASURED: a follow-the-target fan is a cheap feature or a
## per-frame repaint on every plant on the board depending entirely on whether
## AIM_STEPS is doing its job, and "it should be fine" is not a number. Written here,
## above the draw gate, so a headless test can walk a pest across a cob's reach and
## read the actual count — `_draw()` never runs headless, so a budget whose only
## record is inside one cannot be checked at all.
var _aim_repaints: int = 0


## One target lookup, used for both the picture and the shot.
##
## The lookup moved OUT of the `_cooldown <= 0.0` branch, which is the whole of this
## change: it used to run only on the tick a volley went off, so the fan could only
## ever be told about a pest at the moment it was already being shot at. Now the cob
## picks its target every tick and points at it; firing is what the cooldown gates,
## not aiming.
##
## `target` is deliberately one local read by both calls below. The fan pointing at a
## different pest from the one the volley hits would be a worse bug than the one this
## fixes, and two separate `_furthest_along_in_range` calls a line apart is exactly how
## that arrives — a pest crossing the range edge between them is enough.
func _act(delta: float, pests: Array[Pest]) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	var target: Pest = _furthest_along_in_range(pests, RANGE)
	if target != null:
		var direction: Vector2 = target.global_position - global_position
		_aim_at(direction)
		if _cooldown <= 0.0:
			_fire_at(direction)
			_cooldown = fire_interval()
	_refresh_readiness()


## Point the fan at `direction`, and repaint only when the aim has crossed into a new
## AIM_STEPS bucket — `_refresh_readiness()`'s discipline, applied to the other input
## the fan is drawn from.
##
## A zero direction leaves the aim alone rather than snapping it east: `Vector2.ZERO
## .angle()` is 0.0, so a pest standing exactly on the cob would otherwise yank the
## whole fan to due east for as long as it stood there.
func _aim_at(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	_aim_angle = direction.angle()
	var step: int = aim_step_for(_aim_angle)
	if step == _drawn_aim_step:
		return
	_drawn_aim_step = step
	_aim_repaints += 1
	queue_redraw()


## Which of AIM_STEPS repaint buckets `angle` falls in. Pure, and wrapped, so the
## bucket a cob aiming just under a full turn lands in is the one it shares with a cob
## aiming at zero rather than a 49th bucket nothing else can reach.
static func aim_step_for(angle: float) -> int:
	return roundi(fposmod(angle, TAU) / TAU * float(AIM_STEPS)) % AIM_STEPS


## The widest the fan's outermost pip moves between two neighbouring repaint buckets,
## in pixels, for `for_level`. Pure: this is the number AIM_STEPS is chosen against,
## so it is checkable without a frame and a retune of either constant is measured
## rather than eyeballed.
##
## Measured at the pip, not at the pivot, because the pip is what the player watches:
## the fan is projected from FAN_PIVOT behind the cob precisely so a small angle is a
## visible distance, and that magnification applies to the stutter as much as to the
## spread.
static func aim_step_pip_travel(for_level: int) -> float:
	var bucket: float = TAU / float(AIM_STEPS)
	var widest: float = 0.0
	for offset: float in kernel_angle_offsets(for_level):
		var here: Vector2 = muzzle_pivot(0.0) + Vector2.RIGHT.rotated(offset) * FAN_LENGTH
		var there: Vector2 = muzzle_pivot(bucket) + Vector2.RIGHT.rotated(bucket + offset) * FAN_LENGTH
		widest = maxf(widest, here.distance_to(there))
	return widest


func _fire_at(direction: Vector2) -> void:
	var stats: Dictionary = level_row()
	_aim_at(direction)
	# The angle the FAN is on, not a second reading of `direction`. One variable for
	# the picture and the shot is the same rule `kernel_angle_offsets` already enforces
	# for the spread, one level up: the cob fires exactly where it is pointing.
	var base_angle: float = _aim_angle
	queue_redraw()
	var bounds := Rect2(Vector2.ZERO, Vector2(896, 576))
	if board != null:
		bounds = Rect2(Vector2.ZERO, board.board_size())
	for offset: float in kernel_angle_offsets(level):
		var kernel := Kernel.new()
		get_parent().add_child(kernel)
		# `position`, not `global_position`: the kernel is a sibling, so it lives in
		# the same parent space. Entities sit on a layer offset by the top bar, so
		# seeding a sibling from a global coordinate launches every kernel 72 px
		# below the cob — which misses every pest and looks like "the corn is broken".
		kernel.setup(position, Vector2.RIGHT.rotated(base_angle + offset), float(stats["damage"]), bounds)
	Sfx.play(Sfx.CORN_FIRED)
	_recoil()


## The cob's own hue for the shared reach ring. The green is the sprite's, and the
## alpha is deliberately NOT written here — `Plant.REACH_RING_ALPHA` is the grammar's
## and a second copy of it is how one plant's ring ends up brighter than the rest.
const RING_COLOR := Color(0.35, 0.85, 0.45, Plant.REACH_RING_ALPHA)


func reach_ring_radius() -> float:
	return RANGE


func reach_ring_color() -> Color:
	return RING_COLOR


## The range ring is placement feedback and only appears while selected, so an
## idle board doesn't fill with rings. The muzzle fan is always on: it is the
## board-level readout of what an upgrade bought, and it is worthless if you have
## to click the plant to see it — that was the whole complaint.
##
## Note there is still no super._draw() call here, and there must not be: the
## selection brackets live in a SelectionMarker child precisely because this
## override eats them. See SelectionMarker's header — and note that the same trap
## is why `Plant.draw_reach_ring()` is CALLED on the first line of `_draw()` below,
## rather than inherited.
##
## The ring lost a 10%-alpha green wash inside it when the six copies of this cue
## became one. `Plant.draw_reach_ring()` argues that at length; the short version is
## that the grammar's channel for a reach is size and centre, which the edge carries
## alone, and the hover ring this one promises never had a fill either.
func _draw() -> void:
	draw_reach_ring()
	_draw_muzzle_fan()


## Fades the whole fan toward READY_ALPHA_FLOOR right after a shot and back to
## full brightness as the next one arms, driven off the same _cooldown _act
## already reads — so the readout can't drift from what the cob is actually
## doing the way a second, hand-tuned clock could. A cob mid-reload and a cob
## about to fire were pixel-identical before this; now the fan itself answers
## "is this one loaded".
func _draw_muzzle_fan() -> void:
	var offsets: PackedFloat32Array = kernel_angle_offsets(level)
	if offsets.is_empty():
		return
	var fade: float = lerpf(READY_ALPHA_FLOOR, 1.0, readiness())
	# Level 1 fires one kernel through a 0° spread, so there is no arc to draw — a lone
	# pip is the honest picture of a single shot. That decision lives in
	# `spread_arc_span` and NOT in an `if` here, on purpose: at level 1 the span is 0,
	# the two ends coincide and `draw_arc` draws nothing, so "which levels get an arc"
	# is decided in one pure function a test can assert without rendering a frame.
	#
	# It is READ here rather than recomputed, which is the whole of the LEVELS rule and
	# is what this line got wrong until cycle 107. Taking `offsets[0]` and `offsets[-1]`
	# here gives the identical picture — `kernel_angle_offsets` is symmetric about the
	# aim, so the ends are ±span/2 — and that is exactly what made it survivable: the
	# draw site had quietly gone back to measuring the spread for itself while the
	# comment above it, `sfx.gd`'s "fourth time this project needed that move" note and
	# `test_placement`'s own header all three said it read `spread_arc_span`, which by
	# then had no production caller at all. A restated derivation does not announce
	# itself; only the function nothing calls does.
	#
	# The symmetry this centring depends on is `kernel_angle_offsets`' own stated
	# invariant, and `test_placement` now asserts it per rung rather than leaving it as
	# prose two functions away.
	var arc_span: float = spread_arc_span(level)
	draw_arc(muzzle_pivot(_aim_angle), FAN_LENGTH, _aim_angle - arc_span * 0.5,
		_aim_angle + arc_span * 0.5, 24,
		Color(SPREAD_ARC_COLOR, SPREAD_ARC_COLOR.a * fade), 2.0, true)
	for pip: Vector2 in muzzle_pips(level, _aim_angle):
		draw_circle(pip, PIP_SIZE + PIP_RIM_WIDTH, Color(PIP_RIM_COLOR, PIP_RIM_COLOR.a * fade))
		draw_circle(pip, PIP_SIZE, Color(PIP_COLOR, PIP_COLOR.a * fade))


func _recoil() -> void:
	if _sprite == null or not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2(0.88, 1.14), TWITCH_OUT_SECONDS)
	tween.tween_property(_sprite, "scale", Vector2.ONE, TWITCH_BACK_SECONDS)


## This cob's ladder. The one override the generic upgrade surface needs — see
## `Plant.upgrade_ladder`.
func upgrade_ladder() -> Array[Dictionary]:
	return LEVELS


static func _level_stats(for_level: int) -> Dictionary:
	return ladder_row(LEVELS, for_level)


## The angle offsets, in radians and in launch order, that a shot at `for_level`
## puts its kernels on — one entry per kernel, symmetric about the aim direction
## and spanning exactly that level's `spread_degrees`.
##
## Both `_fire_at` and `_draw_muzzle_fan` go through here, which is the point: an
## upgrade that widens the spray cannot widen the shot without widening the
## picture, or vice versa.
static func kernel_angle_offsets(for_level: int) -> PackedFloat32Array:
	var stats: Dictionary = _level_stats(for_level)
	var count: int = int(stats["kernels"])
	var spread: float = deg_to_rad(float(stats["spread_degrees"]))
	var out := PackedFloat32Array()
	for i: int in range(count):
		if count > 1:
			out.append(-spread * 0.5 + spread * (float(i) / float(count - 1)))
		else:
			out.append(0.0)
	return out


## The spread `for_level` fires through, derived rather than read back out of the
## table. LEVELS quotes the same number; `test_combat` asserts they agree, which is
## what stops a retune from widening the arc without re-nesting the angles.
static func spread_for(for_level: int) -> float:
	return KERNEL_STEP_DEGREES * float(int(_level_stats(for_level)["kernels"]) - 1)


## How many of `for_level`'s kernels catch one pest sitting `distance` px straight
## down the aim line. The only thing an off-axis kernel's fate turns on is how far
## from the line it passes, so this is the whole of the single-target question —
## see Kernel.connects().
static func kernels_connecting_at(for_level: int, distance: float) -> int:
	var hits: int = 0
	for offset: float in kernel_angle_offsets(for_level):
		if Kernel.connects(distance, offset):
			hits += 1
	return hits


## Damage per second `for_level` lands on a single pest `distance` px away. This is
## the number plant-tower-defense-axt was filed about: it used to fall from 2.78 to
## 1.61 when the player paid 45 seeds. Kept as a function rather than a comment so
## the claim is executable — `test_combat` sweeps it across the whole of RANGE.
static func single_target_dps(for_level: int, distance: float) -> float:
	var stats: Dictionary = _level_stats(for_level)
	return float(kernels_connecting_at(for_level, distance)) * float(stats["damage"]) / float(stats["interval"])


## The point the fan is projected from, in the plant's own space: FAN_PIVOT behind
## the cob, opposite the way it is aiming. Every pip is exactly FAN_LENGTH from
## here, at exactly `aim + kernel_angle_offsets()[i]`.
static func muzzle_pivot(aim: float = 0.0) -> Vector2:
	return Vector2.RIGHT.rotated(aim) * -FAN_PIVOT


## Where the muzzle pips sit in the plant's own space, for a level and an aim
## direction — one per kernel, in launch order. Pure: no node state, so what gets
## drawn is checkable without rendering a frame.
static func muzzle_pips(for_level: int, aim: float = 0.0) -> PackedVector2Array:
	var pivot: Vector2 = muzzle_pivot(aim)
	var out := PackedVector2Array()
	for offset: float in kernel_angle_offsets(for_level):
		out.append(pivot + Vector2.RIGHT.rotated(aim + offset) * FAN_LENGTH)
	return out


## The angular width of the drawn spread arc for a level — 0.0 when no arc appears,
## which is the single-kernel level and only that one.
##
## Pure, for the same reason `muzzle_pips` is: `_draw_muzzle_fan` reads this rather
## than deciding for itself, so what gets drawn is checkable without rendering a
## frame, and the "lone pip versus a bow of pips" difference a player reads at a
## glance is one function rather than a condition at the draw site.
##
## "Reads this" is load-bearing and was untrue for the whole of cycles 70–106: the draw
## site took the first and last offset instead, which paints the same arc and left this
## function with no production caller while three comments said it had one. See the
## LEVELS rule — a derivation restated at the call site is invisible, so the thing to
## watch for is the pure function nothing outside the tests names.
static func spread_arc_span(for_level: int) -> float:
	var offsets: PackedFloat32Array = kernel_angle_offsets(for_level)
	if offsets.size() < 2:
		return 0.0
	return absf(offsets[offsets.size() - 1] - offsets[0])


## The radius a pip covers on screen, rim included — what "does the fan fit in the
## cell" has to be measured against.
static func pip_outer_radius() -> float:
	return PIP_SIZE + PIP_RIM_WIDTH


## This cob's pips, at its current level and current aim.
func muzzle_pip_positions() -> PackedVector2Array:
	return muzzle_pips(level, _aim_angle)


func aim_angle() -> float:
	return _aim_angle


## How many repaints this cob's aim has asked for. The measured half of "the fan
## follows the target without repainting every frame" — see `_aim_repaints`.
func aim_repaints() -> int:
	return _aim_repaints


func spread_degrees() -> float:
	return float(level_row()["spread_degrees"])


## What has already been spent upgrading a cob to `for_level`, in seeds.
##
## Derived by summing `LEVELS[..]["upgrade_cost"]` rather than written down: the ladder
## is 20 then 45, and a hand-typed 65 would be a second source of truth that a retune
## silently falsifies — on a number the player is about to be told they are forfeiting.
##
## Exists because `Plant.uproot_refund()` scales the plant's BASE cost
## (`game/plant.gd:541-544`), so upgrades are consumed rather than refunded. That is a
## defensible rule and it was an unstated one until cycle 79; this is what lets the armed
## prompt say it, and say it only when there is something to say.
##
## Kept as a static on the cob because two callers ask it of the CLASS rather than of a
## plant — `Hud.message_corpus` prices the armed prompt at the ladder's maximum, which no
## instance can answer — while the per-plant question is `Plant.upgrade_spend()` and every
## instance caller should use that instead.
static func upgrade_spend(for_level: int) -> int:
	return ladder_spend(LEVELS, for_level)


## The instant the seeds are spent, not just the fan's next repaint. Same
## squash-and-recover shape _recoil() plays on every shot, pushed further and
## held longer — an upgrade is one payment for the whole level, not one of
## hundreds of volleys, so it earns a beat _recoil()'s per-shot twitch can't
## spend. Gated the same way every cosmetic Tween in this class is: headless
## pumps no frames, so a Tween queued here never runs, and _sprite is only
## null before _build_visuals runs.
##
## The PLANT_UPGRADED cue used to be the last line of this function, i.e. behind
## that gate — so a player who turned animations off bought upgrades in silence.
## It is `Plant.upgrade()`'s now, where the purchase actually lands; this is the
## sprite half only, which is what `game/sfx.gd:55` already says it is.
func _upgrade_flourish() -> void:
	if _sprite == null or not is_inside_tree() or not GardenTheme.animations_enabled():
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2(0.72, 1.34), FLOURISH_OUT_SECONDS)
	tween.tween_property(_sprite, "scale", Vector2.ONE, FLOURISH_BACK_SECONDS)


func _on_upgraded() -> void:
	_upgrade_flourish()


func kernels_per_shot() -> int:
	return int(level_row()["kernels"])


## What one kernel takes off a pest at this level. Public because it is now half of
## what an upgrade buys — past 80 px it is the *whole* of what an upgrade buys — and
## a selection panel quoting only `kernels_per_shot()` describes the level 3 cob as
## five kernels while the player watches four of them sail past.
func kernel_damage() -> float:
	return float(level_row()["damage"])


## Seconds between volleys, **as this cob will actually fire right now** — the
## level's interval scaled by whatever weather is over the garden
## (`Plant.fire_interval_scale`, plant-tower-defense-q3lx).
##
## Effective rather than nominal, and that is the whole fix here. Weather multiplied
## the number the cob ARMS its cooldown with, and left two surfaces quoting the
## number from the table: the selection panel told the player "0.80s" while the cob
## fired every 1.60s, and `readiness()` divided a cooldown armed at 1.60 by a base of
## 0.80, so the arming glow sat at 0 for the whole first half of every reload.
##
## Two bugs, one cause, and it is worth naming: **the surfaces that DESCRIBE a value
## are a separate population from the code that USES it, and one edit does not reach
## both.** The fix is not to patch the two readouts, it is to make this the only
## place any of them asks.
func fire_interval() -> float:
	return composed_interval(float(level_row()["interval"]), fire_interval_scale,
		neighbour_interval_scale)


## Fraction of the reload elapsed: 0.0 the instant a volley fires, 1.0 once the
## next one is armed. Pure and driven off the same `interval` LEVELS already
## quotes, so retuning a level's fire rate retunes the readout with it.
static func readiness_at(cooldown: float, interval: float) -> float:
	if interval <= 0.0:
		return 1.0
	return clampf(1.0 - cooldown / interval, 0.0, 1.0)


## This cob's readiness right now.
func readiness() -> float:
	return readiness_at(_cooldown, fire_interval())


## Repaint only when the fade would actually move by a visible step.
func _refresh_readiness() -> void:
	var step: int = roundi(readiness() * READINESS_STEPS)
	if step == _drawn_readiness_step:
		return
	_drawn_readiness_step = step
	queue_redraw()
