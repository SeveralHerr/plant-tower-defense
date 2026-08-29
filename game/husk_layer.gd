class_name HuskLayer
extends Node2D

## Pure view over CompostMeter — draws whatever it reports, owns none of the
## data itself, so there is never a second copy of "which husks exist" to
## drift out of sync with what a click can actually collect.
##
## A husk's *size and glow encode its seed value*. Every husk used to be one
## fixed 9px blob, so a hungry beetle's 9-seed payout looked exactly like a
## plain aphid's 2-seed one and the player only learned the difference after
## spending the click. Mutations already tint the pest itself; this is the same
## idea carried through to what the pest leaves behind.
##
## **Two channels, and neither of them reads `RunConfig.colorblind_safe`** — deliberately,
## like every other cue on the board. A husk's value is carried by RADIUS and, once radius
## and brightness have both saturated at `CompostMeter.FULL_VALUE`, by the COUNT of pips.
## Its rot clock is carried by the swept ANGLE of an arc, which also moves. Throw the colour
## away and all three still read. The pips exist precisely because brightness ran out of
## range (cycle 88), which is the two-channel rule arriving as a consequence rather than as
## a requirement. See `game/OVERLAY_GRAMMAR.md`'s per-row channel table, which enumerates
## this for all ten shapes rather than asserting it.

const BASE_RADIUS: float = 8.0
const MAX_RADIUS: float = 15.0
const RADIUS_PER_SEED: float = 1.0
## Gap between the husk body and its rot-timer ring.
const RING_GAP: float = 3.0

const DIM_RING := Color(0.86, 0.72, 0.30, 0.85)
const BRIGHT_RING := Color(1.0, 0.97, 0.62, 1.0)
const RING_WIDTH_MIN: float = 2.0
const RING_WIDTH_MAX: float = 3.5

## The husk's own body fill, at BODY_ALPHA_MIN..BODY_ALPHA_MAX as it decays -- see
## `_draw`'s `0.35 + 0.35 * frac`. DARKENED (plant-tower-defense-w86n): a husk sits on
## the road it was killed on at least as often as on grass, and the alpha fades
## continuously across the husk's whole collectible life, so the worst case -- alpha
## 0.35, moments before it disappears -- is the one that has to clear, not just the
## fresh one at 0.70. The original `Color(0.64, 0.45, 0.25)` (luminance 0.476) missed
## both at that low end: 0.058 against grass's 0.642, 0.020 against dirt's 0.534, a
## floor of 0.12. `.darkened(0.62)`: luminance 0.181, clearing grass by 0.042 and dirt
## by 0.004 at alpha 0.35, and by much more once the husk is fresh at 0.70. See
## test_every_board_mark_clears_the_ground_floor_at_the_alpha_it_is_drawn_at.
const BODY_COLOR := Color(0.24, 0.17, 0.10)

## Pips: what a husk wears once radius and glow have both run out of range.
##
## Three at most, and that ceiling is a promise about what the cue means rather
## than a layout convenience — past 27 seeds the mark says "very rich", not a
## number, and pretending otherwise would need six pips on a 30px husk.
const PIP_MAX: int = 3
const PIP_RADIUS: float = 1.7
const PIP_SPACING: float = 4.6


var compost: CompostMeter = null


## Drawn radius of a husk worth `value` seeds. Static and pure so the size↔value
## relationship is assertable without a viewport — see test_selftest.gd.
static func radius_for(value: int) -> float:
	return clampf(
		BASE_RADIUS + float(value - CompostMeter.BASE_VALUE) * RADIUS_PER_SEED,
		BASE_RADIUS,
		MAX_RADIUS
	)


## 0 for the cheapest husk, 1 for the richest — the single knob both the ring
## colour and its width read, so brightness and weight can never disagree.
## Delegates rather than recomputing: CompostMeter.value_fraction is the same
## curve the rot timer uses, and a husk that draws as rich must also be the one
## that rots fast or the two cues fight each other.
static func glow_for(value: int) -> float:
	return CompostMeter.value_fraction(value)


## How many pips a husk worth `value` wears. Zero for everything the smooth cues
## can still tell apart, then one per whole FULL_VALUE the husk is over.
##
## This exists because the smooth cues stop working, and the measurement is worth
## keeping next to the fix: `Pest.SPECIES` crossed with every composable mutation
## set drops ten distinct values, {2, 3, 5, 7, 9, 14, 20, 30, 40, 60}, and
## `radius_for` and `glow_for` BOTH saturate at 9. So six of the ten render as
## one husk — including the pair the whole second-mutation feature exists to
## produce: a beetle's hungry kill (9) and its armoured-and-hungry kill (14) are
## the same circle, the same brightness and the same ring weight.
##
## A count rather than another lerp, for two reasons. The range above the
## saturation point is 9..60, and no brightness ramp survives being asked to
## resolve 6.6x. And `CompostMeter.FULL_VALUE` cannot simply be widened to 60 to
## fix the ramp, because `lifetime_for` reads the same fraction — the rot clock
## would slow for every husk in the game.
##
## The grammar row this claims is COUNT, which nothing else on the board used;
## see game/OVERLAY_GRAMMAR.md. Deliberately silent at 9 so the husk the player
## already knows is unchanged.
static func overflow_pips(value: int) -> int:
	if value <= CompostMeter.FULL_VALUE:
		return 0
	return clampi(value / CompostMeter.FULL_VALUE, 1, PIP_MAX)


func _process(_delta: float) -> void:
	if compost != null:
		queue_redraw()


func _draw() -> void:
	if compost == null:
		return
	for h: Dictionary in compost.husks():
		var pos: Vector2 = h["position"]
		var value: int = int(h["value"])
		# Against this husk's own max_life, not the global ceiling: lifetimes
		# differ per husk now, and dividing by the constant would leave a rich
		# husk's ring showing two-thirds remaining as it disappears.
		var span: float = maxf(0.001, float(h["max_life"]))
		var frac: float = clampf(float(h["life"]) / span, 0.0, 1.0)
		var radius: float = radius_for(value)
		var glow: float = glow_for(value)
		draw_circle(pos, radius, Color(BODY_COLOR, 0.35 + 0.35 * frac))
		# The rot timer sweeps this ring away; a richer husk wears a brighter,
		# heavier one, so "worth hurrying for" is legible at a glance.
		draw_arc(
			pos,
			radius + RING_GAP,
			0.0,
			TAU * frac,
			16,
			DIM_RING.lerp(BRIGHT_RING, glow),
			lerpf(RING_WIDTH_MIN, RING_WIDTH_MAX, glow),
			true
		)
		# After the body, so they sit on top of it rather than under; and inside
		# the rot ring, so a sweeping arc never crosses them and turns a count of
		# three into a count of two mid-rot.
		var pips: int = overflow_pips(value)
		var middle: float = float(pips - 1) * 0.5
		for i: int in range(pips):
			draw_circle(
				pos + Vector2((float(i) - middle) * PIP_SPACING, 0.0),
				PIP_RADIUS,
				BRIGHT_RING
			)
