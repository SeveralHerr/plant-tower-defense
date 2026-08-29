class_name CompostMeter
extends Node

## The doc's compost idea: "pests leave husks, sweeping them pays seeds."
##
## Pest deaths already pay seeds directly (Game._on_pest_died) — the husk is a
## *second*, optional payout that requires the player to click it before it
## rots, so staying engaged with a clearing lane earns more than tabbing away.
## That's why this is seeds-in-seeds-out rather than a second currency to read.

## `at` is this husk's board position at the moment it was swept — carried so
## a listener can draw something at the click rather than only knowing a
## number changed. See HuskLayer for the same position drawn while the husk
## was still on the ground, and Hud.fly_seed_glyph for the one caller that
## reads it today.
signal husk_collected(value: int, at: Vector2)
## A husk the player never got to. This used to happen in total silence — the
## husk simply stopped being drawn — which made "you were too slow" and "there
## was never a husk there" the same event from the player's chair. Game listens
## for this and plays Sfx.HUSK_ROTTED, so the loss is announced rather than
## merely rendered. The meter also *counts* it into `total_rotted` — the signal
## is the cue, not the record, so a run's missed compost survives whether or not
## anything is listening.
signal husk_rotted(value: int)

## How long the *cheapest* husk sits on the ground before it rots away, and the
## ceiling for every husk.
const HUSK_LIFETIME: float = 10.0
## ...and how long the richest one gets. A richer husk rots faster, so the board
## asks "which one first?" instead of "sweep them in any order, it makes no
## difference" — which is what a single shared timer meant. It also gives the
## size/glow cue a second job: a big bright husk is now urgent as well as
## valuable, and those two readings point the same way.
##
## AND IT IS A FLOOR, NOT A MIDPOINT (plant-tower-defense-ix76). The question that bead
## asked is whether a 60-seed husk should rot faster than a 9-seed one — six of the ten
## reachable values sit at or above `FULL_VALUE`, so today they all get exactly this 4.5s,
## and the pips say one is worth six times the other while the clock says hurry equally.
##
## DECIDED: NO. They keep the same floor. Three reasons, in the order they matter:
##
##   * 4.5s is a REACTION TIME, not a difficulty knob. The values above 9 come from the two
##     bosses (`Pest.SPECIES` — the Nurse at 39 seeds, the Queen at 40) crossed with
##     mutations, so the richest husks drop at the single busiest moment on the board: a
##     health bar emptying, plants firing, lives possibly just spent. Going below this makes
##     the rarest drop the hardest to claim, which punishes the player at the game's high
##     point rather than making it tense.
##   * THE URGENCY IS ALREADY CARRIED, TWICE, above the saturation point — size and glow to
##     9, and `HuskLayer.overflow_pips` counting beyond it. A player already knows a 60 is
##     special; what they do not need is less time to act on knowing.
##   * THE FAILURES ARE NOT SYMMETRIC. Rot too slow and the compost meter is mildly too
##     generous. Rot too fast on exactly the rarest drops and the player learns boss kills
##     are not worth chasing — the opposite of what a boss should teach.
##
## The inconsistency the bead names is real and is ACCEPTED rather than denied: the pips
## answer "how much is this worth" and the clock answers "how long do you have". Those are
## different questions, and they are allowed to saturate differently because value is
## unbounded and reaction time is not.
##
## `test_the_rot_floor_is_a_floor_and_the_curve_still_sorts_below_it` pins this, so widening
## `FULL_VALUE` or adding a second rot curve fails the suite and lands the reader here.
const MIN_HUSK_LIFETIME: float = 4.5
## How close a click has to land to sweep a husk.
##
## THERE ARE 4 PIXELS OF HEADROOM ABOVE THIS AND NO MORE. The nearest the lane
## ever comes to buildable ground is half a cell — 32 px — because Board.route()
## is one point per road-cell centre and a centre cannot be closer than that to
## a neighbouring cell's box. So 32 - 28 = 4 px is the entire clearance between
## "this click sweeps a husk" and "this click places a plant", and at <= 0 the
## two become genuinely ambiguous and PlacementPreview needs a husk state it
## does not currently have.
##
## Raising this to 32 does not merely narrow the margin, it closes it.
## `Game.budget_entries()`'s husk_click entry prints the subtraction with both
## terms; PlacementPreview.husk_click_margin() is the gate.
const COLLECT_RADIUS: float = 28.0

## The husk value range the SMOOTH cues span — not the range the game drops.
## That distinction is new, and it is a correction: this block used to read "the
## husk value range the game can actually produce ... ceil(beetle 9 / 2 * hungry
## 2.0) at the top", which was already false for a plain queen (20) when it was
## written, and became far more false when cycle 81 made `husk_multiplier` a
## product and pushed the ceiling to 60.
##
## Derived, not remembered — `Pest.SPECIES` x every composable mutation set gives
## ten reachable values, {2, 3, 5, 7, 9, 14, 20, 30, 40, 60}, and six of them sit
## at or above FULL_VALUE. So everything from 9 up saturates radius, ring
## brightness and rot speed alike, and a paired-mutation beetle husk (14) is
## pixel-for-pixel a single-mutation one (9).
##
## FULL_VALUE stays at 9 deliberately. It is the knob `lifetime_for` was tuned
## against, so widening it to 60 would silently slow the rot of every husk in the
## game — a balance change wearing a legibility fix's clothes. The visual half of
## the problem is answered above the saturation point instead, by
## `HuskLayer.overflow_pips`, which counts rather than lerps.
const BASE_VALUE: int = 2
const FULL_VALUE: int = 9


## What a kill worth `seed_value` seeds drops after `multiplier` mutations.
##
## Lived inline at its one call site in `Game._on_pest_died` until the drop table
## needed deriving — and a formula at a call site is a decision no test can name,
## so a test wanting the ten values the game can actually produce had to
## reimplement the ceil-and-halve itself and then be wrong in private. Same
## reason `Sfx.kill_event_for` and `Pest.markers_for` are up here.
static func husk_value_for(seed_value: int, multiplier: float) -> int:
	return maxi(1, int(ceil(float(seed_value) / 2.0 * multiplier)))


## Where `value` sits in the drop range: 0.0 for the cheapest husk, 1.0 for the
## richest. The single knob the radius, the ring brightness and the rot timer
## all read.
static func value_fraction(value: int) -> float:
	return clampf(float(value - BASE_VALUE) / float(FULL_VALUE - BASE_VALUE), 0.0, 1.0)


## How long a husk worth `value` seeds survives uncollected. Static and pure so
## the value-to-urgency curve is assertable without a running meter.
static func lifetime_for(value: int) -> float:
	return lerpf(HUSK_LIFETIME, MIN_HUSK_LIFETIME, value_fraction(value))

## Seeds swept off the board. The post-mortem's "Compost swept" numerator.
var total_collected: int = 0
## Seeds that rotted where they fell — the numerator's missing denominator half.
##
## "Compost swept 12" is a number no player can grade themselves against: 12 out
## of 13 is a clean run and 12 out of 60 is a lane they never looked at, and the
## card reported both as "12". This is the other half, in the same units as
## `total_collected`, so the two can be added.
##
## Seeds, not husks, deliberately. The numerator has always been seeds, a husk's
## value spans BASE_VALUE..FULL_VALUE, and the rich husk is also the one that
## rots fastest (lifetime_for) — so a husk count would call sweeping one cheap
## husk and letting the richest rot a 50% run, when the player threw away most of
## what was on the board.
var total_rotted: int = 0


## Seeds the compost system actually resolved, one way or the other: swept plus
## rotted. The denominator for `total_collected`.
##
## Deliberately NOT "every seed ever dropped as a husk". A husk still lying on
## the ground has not been missed — the player may be one click away from it —
## and the run can end (Game._on_pest_escaped kills the last bed and builds the
## card in the same frame) with husks that were dropped a moment earlier and were
## never collectable at all. Counting those would charge the player for husks the
## game never gave them time to reach. Every husk in this total is one whose
## story is over, so the fraction is honest at any instant, mid-run included.
func total_resolved() -> int:
	return total_collected + total_rotted

## id -> {"position": Vector2, "value": int, "life": float, "max_life": float}
var _husks: Dictionary = {}
var _next_id: int = 1


func drop_husk(at: Vector2, value: int) -> int:
	var id: int = _next_id
	_next_id += 1
	var span: float = lifetime_for(value)
	_husks[id] = {"position": at, "value": value, "life": span, "max_life": span}
	return id


## Snapshot for rendering: [{id, position, value, life, max_life}]. `life`
## counts down to 0 from this husk's own `max_life`, which is no longer the
## same for every husk — the rot ring has to divide by `max_life`, not by
## HUSK_LIFETIME, or a rich husk's ring reads two-thirds full at the instant it
## vanishes.
func husks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: Variant in _husks:
		var h: Dictionary = _husks[id]
		out.append({
			"id": id,
			"position": h["position"],
			"value": h["value"],
			"life": h["life"],
			"max_life": h["max_life"],
		})
	return out


func husk_count() -> int:
	return _husks.size()


## Sweeps the nearest husk within COLLECT_RADIUS of `at`. Returns the seeds it
## paid, or 0 if nothing was close enough — the caller decides what 0 means
## (Game treats it as "the click was for something else").
func collect_at(at: Vector2) -> int:
	var best_id: Variant = null
	var best_distance: float = COLLECT_RADIUS
	for id: Variant in _husks:
		var h: Dictionary = _husks[id]
		var d: float = (h["position"] as Vector2).distance_to(at)
		if d <= best_distance:
			best_distance = d
			best_id = id
	if best_id == null:
		return 0
	var husk: Dictionary = _husks[best_id]
	var value: int = int(husk["value"])
	var husk_position: Vector2 = husk["position"]
	_husks.erase(best_id)
	total_collected += value
	husk_collected.emit(value, husk_position)
	return value


## Rot, unconditionally. THE DECREMENT HAS NO HOLD AND WILL NOT GET ONE
## (plant-tower-defense-7bhb), which is a decision rather than an omission.
##
## The bead came from the uproot window, where `Game._tick_uproot_confirm` skips its
## decrement while `can_move_to(_uproot_armed, _hover_cell)` is true — the clock stops
## while the player hovers a legal destination. It asked whether a husk should likewise
## stop rotting while the player is reaching for it. DECIDED: NO, for four reasons, in
## the order they matter.
##
##   * THE UPROOT HOLD COVERS A GAP BETWEEN TWO STEPS. Arming is one act and confirming
##     at a destination is another, and the window exists only to bound the space
##     between them. Collecting a husk is ONE click. There is no in-between state to
##     protect, so a hold would not be pausing a decision — it would be pausing the
##     pressure itself.
##   * "HOVERING A HUSK" IS NOT A STATE THIS GAME HAS, and building it costs more than
##     it sounds. `_hover_cell` is a CELL; a husk is swept within `COLLECT_RADIUS` of a
##     POINT. Those are different queries, and the block above `COLLECT_RADIUS` records
##     that exactly 4 px separate "this click sweeps a husk" from "this click places a
##     plant" (32 px half-cell minus 28 px reach). A hold keyed on proximity puts the
##     pointer's distance to a husk into that 4 px margin as a second meaning.
##   * IT WOULD FIRE WITHOUT BEING ASKED. Husks drop where pests die, which is on and
##     beside the road — the same ground the pointer crosses while the player walls a
##     lane. 28 px is a distance you pass through incidentally, so the clock would stop
##     for reasons the player never chose and cannot see. The uproot hold is legible
##     because the player armed it and an arc is unwinding at them; this one would be
##     invisible causation.
##   * MOUSE PLAYERS COULD REACH IT AND TOUCH PLAYERS COULD NOT. `game/game.gd:2438`
##     says it in its own words — the drag branch is "the hover a mouse player has had
##     all along and a touch player never did". A finger only hovers while it is down,
##     and a finger down over a husk collects it on release, so the hold would be
##     structurally unreachable on touch.
##
## And the cost of getting it wrong is not symmetric. `MIN_HUSK_LIFETIME` above gives
## the size/glow cue its second job — a big bright husk is urgent as well as valuable —
## so a clock that can be stopped by resting the mouse does not merely soften the
## pressure, it takes one of the two readings back off a cue cycle 88 built precisely
## because one channel had run out of range.
##
## 10 s down to 4.5 s is a reaction time. It is a deadline you lose to by ignoring a
## husk, not one you lose to while reaching for it, and that is the shape it should keep.
func _process(delta: float) -> void:
	var expired: Array = []
	for id: Variant in _husks:
		var h: Dictionary = _husks[id]
		h["life"] = float(h["life"]) - delta
		if h["life"] <= 0.0:
			expired.append(id)
	# Erase and COUNT first, THEN announce: a listener that reads husk_count() or
	# total_resolved() from inside the signal must not see the husk it is being
	# told about still on the board, nor a total that has not yet counted it. Same
	# ordering collect_at() follows for total_collected.
	for id: Variant in expired:
		var value: int = int((_husks[id] as Dictionary)["value"])
		_husks.erase(id)
		total_rotted += value
		husk_rotted.emit(value)
