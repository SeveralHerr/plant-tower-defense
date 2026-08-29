class_name Plant
extends Node2D

## Shared body for anything planted on a grass cell.
##
## Subclasses override `_act()`, which runs every physics frame with the pests
## currently on the board. Nothing here touches the scene tree for targeting —
## the pest list is passed down, so a subclass is testable without a Game.

## A hungry pest (see Pest.is_hungry) eats a plant instead of walking past it —
## this is what it eats through. Most plants never take a scratch in a normal
## run; the bar only appears once they do, same as a pest's.
const MAX_HEALTH: float = 40.0

## How long a plant has to go unbitten before it starts putting health back on,
## and how fast it does so once it has.
##
## Regrowth is the catalogue's answer to a hungry pest, and it deliberately lives
## here rather than on a fifth plant. Every entry in PlantCatalog either damages a
## pest (Corn, Chomp), funds the ones that do (Sunflower) or slows them (Sundew),
## and none of those repair a bed — a chewed plant's health only ever went down,
## for the whole rest of the run. That made "a hungry pest reached my Corn" a
## permanent loss the player could not respond to in any way, and since
## uproot_refund() started sliding with remaining health it was a loss they could
## not even scrap their way out of.
##
## The two numbers are chosen against the two clocks that already exist:
##
##   * REGROWTH_DELAY is measured against Pest.EAT_DPS. A hungry pest calls
##     take_damage() every physics frame while it is eating, and every one of
##     those resets the clock below — so regrowth contributes exactly nothing to a
##     bed that is under attack right now. A full plant still dies in
##     MAX_HEALTH / Pest.EAT_DPS = 2.86s if the player does nothing, which is the
##     same 2.86s it took before this existed. The mutation still takes beds; it
##     just no longer takes them forever.
##   * REGROWTH_RATE is measured against Game.PREP_SECONDS (18s, the gap between
##     a cleared wave and the next one). One clean intermission is
##     18 - 6 = 12 seconds of growing, i.e. 18hp, i.e. 45% of a bed. So a lightly
##     chewed plant is whole again by the next wave, a half-eaten one is not quite
##     (19.3s, just over one gap), and a wreck at 1hp needs 32s — closer to two.
##     That gradient is the decision: uprooting a wrecked Corn Cobbler refunds 2
##     against a 10-seed replant and loses its upgrade level, so the player is now
##     choosing between ~8 seeds now and ~30 seconds of patience. Before this,
##     patience bought nothing and the choice did not exist.
##
## Deliberately NOT enough to protect a bed mid-bite: Pest.EAT_DPS out-eats this
## by more than 9 to 1, so even a hypothetical ungated version would only stretch
## 2.86s to 3.19s. Protecting a plant while it is actually being eaten is a
## different mechanic and is not this one.
const REGROWTH_DELAY: float = 6.0
const REGROWTH_RATE: float = 1.5

## The in-world bar's healing colour. Green is the only cue the player gets that
## regrowth is a thing the game does, so it is on the readout they are already
## looking at rather than on a new one.
##
## Its bleeding counterpart is NOT a constant here any more. `HEALTH_BAR_HURT` was
## a third copy of the same red-lerp end the HUD draws twice, and when the
## colourblind-safe ramp arrived it reached `Hud.health_color` and
## `Hud.threat_color` and stopped there — leaving the one bar a player actually
## watches through a chew (the HUD's copy only appears for the *selected* plant)
## on the green-to-red pair the option exists to get rid of. So the bleeding end
## is now read out of `Hud.health_color_on(0.0, safe)`: one ramp, one switch,
## three bars that cannot disagree. See health_bar_color_on().
##
## The safe counterpart of this green is `Hud.HEALTH_FULL_SAFE` — the same "whole"
## end the HUD's fill lands on — rather than a fourth hand-picked colour.
const HEALTH_BAR_REGROWING := Color(0.36, 0.70, 0.34)

## Where that bar lives, in the plant's own local space. Named rather than typed
## out four times, because the numbers are load-bearing elsewhere: the Sunflower's
## yield gauge is positioned to clear this exact rect
## (test_the_sunflower_gauge_clears_the_health_bar_the_brackets_and_the_chew_ring
## asserts it against a hand-copied Rect2(-16, -34, 32, 5)), and the notches below
## are derived from it rather than being a second set of magic offsets that could
## drift away from the bar they are cut into.
const HEALTH_BAR_ORIGIN := Vector2(-16, -34)
const HEALTH_BAR_SIZE := Vector2(32, 5)

## The bar's second channel (plant-tower-defense-e0m), and the plant's half of the
## board-wide rule LanePressureOverlay's HATCH_* block states: **a solid red
## surface is a live warning; a broken one is a record or a recovery.**
##
## The pair above is red versus green, in one rect, at one position, at one size —
## the single most common colour-vision deficiency there is, sitting on the one
## readout in this game where colour alone decides a purchase. "Bleeding" and
## "healing" are what the player is choosing between when they weigh
## uproot_refund() against seconds_to_full_from(): scrap the wreck for 2 seeds now,
## or leave it and get a whole plant back in ~32s. A deuteranope was being asked to
## make that call off a hue they cannot see, and the only thing pinning the cue
## (test_combat.gd, `Plant.health_bar_color(true) != Plant.health_bar_color(false)`)
## asserted precisely the channel that does not reach them.
##
## So a regrowing bar is cut into HEALTH_BAR_SEGMENTS blocks by notches and a hurt
## one is left whole. The notches are drawn on the *slot*, not on the filled part,
## and in near-black rather than the backing's grey, so they are visible over both
## the fill and the empty remainder — a plant at 10% health still reads as notched,
## which a divider spaced along the fill would not manage.
##
## Count, not hue: it is the same vocabulary PlacementPreview already uses to tell
## dead ground (one bar) from redundant ground (two), so this is a second dialect
## of an existing language rather than a third language on the board.
const HEALTH_BAR_SEGMENTS: int = 4
const HEALTH_BAR_NOTCH: float = 2.0
const HEALTH_BAR_NOTCH_COLOR := Color(0.0, 0.0, 0.0, 0.8)

signal destroyed(plant: Plant)

var kind: StringName = &""
var cell: Vector2i = Vector2i.ZERO
var board: Board = null
var health: float = MAX_HEALTH

## A SPORT: a plant the garden threw rather than one the player bought
## (`CrossBreeder`). Same kind, one buff, its own tint and mark.
##
## **Set BEFORE `setup()`, never after.** `_build_visuals` reads it to tint the
## sprite and to add the mark, and it is the only chance either gets — nothing
## repaints a plant that changes its mind about being a sport. `Game._sprout_sport`
## is the one caller and sets it on the line after `new_plant`.
##
## An instance flag and not a subclass, for the reason `PlantMutation`'s header
## gives at length: a sport has to be the same kind as its parents everywhere that
## reads `kind`, which is the shop, the packets, the coverage map, the wave-side
## readouts and every test over the catalogue.
var is_sport: bool = false
## What this plant's firing interval is multiplied by right now. 1.0 is clear
## weather; a drought wave sets 2.0 (plant-tower-defense-q3lx).
##
## An instance variable, set by Game on every plant it owns, rather than a static
## on this class. A static would be simpler and would leak: the suite shares one
## process, so a drought staged by one test would still be in force for every test
## after it, and the failure would surface as an unrelated plant "not shooting" in
## a test that never mentions weather. This project has already paid for that shape
## once with RunConfig -- see test_no_test_persists_through_the_players_own_save.
##
## Read where the cooldown is ARMED rather than where it is decremented, so the
## multiplier applies to the next shot rather than retroactively stretching one
## already in flight -- and so a wave ending mid-cooldown does not leave a plant
## owing time it earned under weather that has passed.
var fire_interval_scale: float = 1.0

## The same multiplier, contributed by NEIGHBOURS rather than by the sky — a Mint next door.
##
## A separate field and not a share of the one above, and the reason is mechanical rather
## than tidiness: `Game._apply_weather` does `plant.fire_interval_scale = scale` for every
## plant on every weather change (`game/game.gd:345`). It **assigns**. A buff folded into
## that field would be wiped the next time the weather turned, and the failure would be
## invisible — the plants keep firing, at the wrong rate, with nothing logged anywhere.
##
## So the two factors compose instead, through `composed_interval` below. Weather owns one,
## the board owns the other, and neither can silently overwrite the other's work.
var neighbour_interval_scale: float = 1.0


## What a plant's firing interval actually is, once the sky and its neighbours have both had
## their say. Multiplicative, so a drought (2.0) beside a Mint (0.8) is 1.6 rather than one
## of them winning.
##
## Static and pure so the composition is assertable without a board, a wave or a weather
## change — which matters more here than usual, because the bug this function exists to
## prevent only appears on the SECOND event (place a Mint, then change the weather) and a
## test that stages one event would pass against the broken version.
##
## A THIRD factor arrived with the sports (`PlantMutation`), and it is defaulted
## rather than required. That is not laziness about the call sites: `sport_scale` is
## not owned by anybody who can ASSIGN it — it is derived from `is_sport` and the
## kind, both fixed for the life of the plant — so it carries none of the
## overwrite hazard the two paragraphs above are about, and a caller that does not
## pass it is a caller with nothing to lose. The three plants that time a shot pass
## `sport_rate_scale()`; every existing test that calls this with three arguments
## still describes exactly the composition it was written to describe.
static func composed_interval(base: float, weather_scale: float, neighbour_scale: float,
		sport_scale: float = 1.0) -> float:
	return base * weather_scale * neighbour_scale * sport_scale


## What this plant multiplies a LOWER-IS-BETTER quantity by: a firing interval, a
## chew, a bite-resistance fraction. 1.0 for anything the garden did not throw.
##
## Two accessors on `Plant` rather than nine `if is_sport` branches spread over the
## subclasses, so "an ordinary plant is unaffected" is stated once and cannot be got
## wrong in the ninth place it is written.
func sport_rate_scale() -> float:
	return PlantMutation.rate_scale(kind) if is_sport else 1.0


## What this plant multiplies a HIGHER-IS-BETTER quantity by: a radius, a heal, a
## count of Mints. 1.0 for anything the garden did not throw.
func sport_power_scale() -> float:
	return PlantMutation.power_scale(kind) if is_sport else 1.0


## The name a readout should print for THIS plant, which is not always its kind's.
##
## Every surface that names a placed plant goes through here rather than through
## `PlantCatalog.display_name(plant.kind)`, which is what they all said before the
## sports: a sport printed as "Corn Cobbler" is a plant the player cannot tell from
## the cob beside it in the one readout that exists to tell them apart.
##
## The shop and the packets keep asking the catalogue directly, and correctly so —
## nothing there is a plant yet, and a packet cannot promise a sport.
func display_name() -> String:
	return PlantMutation.display_name(kind) if is_sport else PlantCatalog.display_name(kind)

var _sprite: Sprite2D
## The node the idle motion lives on, sitting between the plant and its sprite.
##
## `_wobble` used to write `_sprite.rotation` directly, which was fine while the
## sway had one channel. A breathe is a SCALE, and `_sprite.scale` already has
## five owners that all tween back to `Vector2.ONE`: the planting pop below, the
## exit shrink in `play_exit_and_free`, `Sunflower._bloom`'s payout pop,
## `CornCobbler._recoil` and its upgrade flourish, and `ChompFlower`'s bite squash.
## An idle scale on that property would be overwritten by whichever of them ran
## last, and would stomp their landing on the next physics frame.
##
## So idle motion goes on the parent and event flourishes stay on the sprite —
## the transforms multiply instead of fighting over one property. `Pest` needs no
## equivalent because `_gait` is the only writer of a pest's sprite scale
## (`game/pest.gd:743`); a plant is the case where two animations want the same
## number.
##
## The node sits AT the plant's origin and never moves; the point it turns about is
## carried in the transform `sway_transform()` builds, not in this node's position.
## See that function for why the pivot point cannot be a node position here without
## breaking the two gestures that tween `_sprite.position` and the five that tween
## `_sprite.scale`.
var _sway_pivot: Node2D
var _wobble_time: float = 0.0
## Seconds of flinch left. Re-armed by `take_damage`, decayed in `_wobble`.
var _flinch_left: float = 0.0
## Idle sway, the same shape TitleScreen's decorative lawn already uses
## (TitleScreen.SWAY_RADIANS / SWAY_RATE): a small continuous rock rather than
## a one-shot event tween like play_exit_and_free()'s pop. Kept subtle on
## purpose — this runs on every placed plant, every frame, for the whole run.
const WOBBLE_RADIANS: float = 0.055
const WOBBLE_RATE: float = 1.15

## How far below the sprite's centre the sway rotates from, in the plant's own
## frame (+Y is down, so this is a depth).
##
## The sway used to turn `_sway_pivot` about its own origin, which IS the sprite's
## centre — so every bed on the board rocked about its waist and the base of the
## stem swung as far as the head did. A tethered balloon, not something rooted in
## soil. Rotating about the base instead pins the one point that should never move,
## and the travel at the top comes free: a point `d` above the pivot moves
## `d * sin(angle)` sideways, so the top of a 64 px sprite goes from `32 * sin` to
## `(32 + STEM_PIVOT_Y) * sin` — 1.8x the visible swing out of an unchanged angle.
##
## 25 px and NOT the sprite's 32 px half-height, which is what the issue guessed at,
## because the art does not reach the bottom of its own PNG. Measured across the
## eight plant sprites, the last opaque row ends at +24 (nettle, mint, aloe), +25
## (corn_cobbler, sticky_sundew) or +27 (chomp_flower, sunflower, dandelion). This is
## the median: no plant's base is more than 2 px from it, and a pivot at 32 would
## have sat up to 8 px below the visible stem, in transparent padding, hinging every
## plant from a point underground.
##
## Not derived at runtime — an offset that cost an image decode per plant would be a
## worse trade than a constant. It is derived at TEST time instead: see
## `test_the_stem_pivot_is_the_bottom_of_the_art_not_the_bottom_of_the_png`, which
## re-measures the PNGs and fails if new art moves the baseline out from under it.
const STEM_PIVOT_Y: float = 25.0

## The flinch: the third word of the standing animation ask, after sway and breathe.
##
## Every idle motion in this game is a continuous sinusoid, so **nothing on the board was
## ever startled** — a bed being eaten looked exactly like one that was not, and the only
## tell was a health bar the player has to be looking at. This is a fast shake added on top
## of the slow sway, decaying back into it, on the same `_wobble_time` clock and the same
## `_sway_pivot` — not a Tween, which would fight the pivot the way an idle scale would have
## fought `_sprite.scale`.
##
## A hungry pest calls `take_damage` every physics frame, so the flinch is re-armed every
## frame while a plant is actually being eaten: it reads as a sustained shudder for as long
## as the biting lasts and decays out over `FLINCH_SECONDS` once it stops. That is the
## behaviour wanted and it falls out of the trigger rather than needing a state machine.
##
## `FLINCH_RADIANS` is deliberately three times `WOBBLE_RADIANS`: a flinch that does not
## clearly out-read the idle sway is not a flinch. At 0.16 rad the corner of a 64 px sprite
## moves about 5 px, which `test_a_bitten_plant_flinches_further_than_it_sways` pins as an
## absolute pixel floor rather than as a multiple of the constant — an assertion written in
## the units of the thing under test passes when that thing is zeroed, which is how a
## mutation survived in cycle 71.
const FLINCH_RADIANS: float = 0.16
const FLINCH_RATE: float = 26.0
const FLINCH_SECONDS: float = 0.32

## THE WILT, and it is the only thing on this plant that says "nearly gone"
## (plant-tower-defense-tkwf).
##
## The flinch above fires on the BITE and decays over 0.32s, so it says "just hit" and
## never "still in trouble": between bites, a plant at 8% health and one at 95% are the
## same silhouette. The difference lived entirely in a health bar the player has to be
## looking at — and `Hud.health_color_on` is a continuous LERP with no threshold in it, so
## even the bar answers by hue alone, against this project's standing rule that colour is
## never the only signal.
##
## A HELD LEAN, not a third oscillation, and that is the whole design. `_wobble`'s rotation
## already carries two sinusoids and its own comment records why they run on separate
## clocks: a third at any frequency phase-locks with one of them sooner or later and reads
## as "sways oddly" rather than as a state. A DC offset has no frequency to lock with. It
## also composes correctly by construction — the sway keeps its full range, displaced — so
## a wilting plant still breathes and still flinches, which a replacement channel would
## have cost.
##
## AND IT IS ROTATION RATHER THAN SCALE deliberately: scale on `_sway_pivot` now has two
## writers (the breathe and `idle_scale_multiplier`, which the Chomp's champ uses), and
## `plant-tower-defense-tkwf` names the trap directly — three multiplied sinusoids do not
## read as three states, they read as noise.
##
## THE THRESHOLD IS DERIVED, not chosen: `Pest.EAT_DPS / MAX_HEALTH` is 14/40 = 0.35, i.e.
## **less than one second of chewing from dead**. That is the number this file's own header
## already reasons in — it prices a full plant's life at `MAX_HEALTH / Pest.EAT_DPS` =
## 2.86s — and deriving it means a retune of either constant moves the cue with the danger
## instead of leaving it pointing at a fraction that used to matter.
const WILT_RADIANS: float = 0.22


## Pure: how far into "nearly gone" this health fraction is, 0.0 to 1.0.
##
## Zero above the threshold and ramping below it, rather than a step, for the reason the
## health bar itself lerps: a plant crossing a line and snapping into a pose reads as a
## bug, and the player's question is "how bad" rather than "is it bad".
static func wilt_amount(fraction: float) -> float:
	var threshold: float = wilt_threshold()
	if threshold <= 0.0:
		return 0.0
	var below: float = threshold - clampf(fraction, 0.0, 1.0)
	return clampf(below / threshold, 0.0, 1.0)


## Pure: the health fraction at which the wilt starts, DERIVED from the damage that causes
## it. One second of a hungry pest's chewing, as a fraction of a full plant.
static func wilt_threshold() -> float:
	return clampf(Pest.EAT_DPS / MAX_HEALTH, 0.0, 1.0)


## Pure: the held lean, in radians, for a plant at `amount` of wilt standing on `phase`.
##
## The DIRECTION comes from the plant's own sway phase, so neighbouring beds lean opposite
## ways. A constant sign would make every dying plant in a row tip identically, which reads
## as a rendering fault rather than as a garden in trouble — the same reason `_wobble_phase`
## exists at all.
static func wilt_angle(amount: float, phase: float) -> float:
	if amount <= 0.0:
		return 0.0
	var direction: float = 1.0 if sin(phase) >= 0.0 else -1.0
	return direction * clampf(amount, 0.0, 1.0) * WILT_RADIANS
## The breathe: the sway's second channel, added in cycle 71 because a plant had
## one and a pest had two. `Pest._gait` narrows and lengthens the body alongside
## its side-to-side swing (`game/pest.gd:743`), which is what stops a walking bug
## reading as a rigid sprite being rotated; a plant was being rotated and nothing
## else. Same axes as the pest's — -X narrows while +Y lengthens, so a plant
## breathes upward rather than inflating.
##
## Half the pest's `GAIT_STRETCH` of 0.06, because a bug is mid-stride and a plant
## is standing still, and this runs on every placed plant every frame for a whole
## run. `BREATHE_RATE` is 2.0 for the same reason `Pest.GAIT_STRETCH_RATE` is: a
## body pulses twice per side-to-side swing, once at each extreme.
const BREATHE_AMOUNT: float = 0.022
const BREATHE_RATE: float = 2.0

## The three numbers every reach ring is drawn with — see `draw_reach_ring()` for the
## decision they encode. Alpha and width were ALREADY unanimous across all five plants
## that drew an edge (0.55 and 2.0, five times over); naming them here is not a change
## of look, it is what stops the sixth plant from picking its own and being right by
## luck. Segments were not unanimous (48, 48, 40, 44, 48) and are now 48 everywhere,
## which is the one number in this block a player cannot see.
##
## The reach ring's RADIUS is the one number not named here, because it is per-plant —
## and the reason it can be per-plant without anyone checking is that every reach in the
## catalogue is at least 64 px, twice the 32 px half-cell. `ReadoutBand`
## (game/readout_band.gd) is where that stops being a coincidence: the ring is a row in
## its registry like every other mark drawn at a fixed radius on a plant, and
## `test_placement.gd` asserts the shortest reach in the catalogue still clears the band.
## A plant added with a one-cell reach would put a green ring in among the clocks, and
## nothing before that file would have said so.
const REACH_RING_ALPHA: float = 0.55
const REACH_RING_WIDTH: float = 2.0
const REACH_RING_SEGMENTS: int = 48

## The plant family's squash-and-return vocabulary, in two tiers.
##
## Every animation outside this family already names its duration — Hud's
## PREP_BAR_PULSE_SECONDS / PANEL_RISE_SECONDS / READOUT_PUNCH_SECONDS, Music's
## CROSSFADE_SECONDS, PauseScreen's RISE_SECONDS, and Pest's HIT_FLASH_DURATION,
## which is split 0.35/0.65 OF itself rather than written out as two numbers. The
## plant flourishes named nothing: nine gestures, twenty-one bare literals.
##
## The interesting part of re-running that census is what the twenty-one turned out
## to be. They use seven distinct numbers between them, and two exact pairs account
## for five of the nine gestures. These are those two pairs.
##
## TWITCH is the per-action beat — `CornCobbler._recoil()` on every shot,
## `Nettle._sting_twitch()` on every sting. FLOURISH is the once-in-a-while beat —
## `CornCobbler._upgrade_flourish()`, `ChompFlower._on_upgraded()`, and the
## Sunflower's payout pop. Both of those upgrade headers already assert the
## relationship between the tiers in prose: "pushed further and held longer", and
## "a snap wider than `_bite`'s and held longer, the same relationship
## `CornCobbler._upgrade_flourish` has to its own `_recoil`". Naming the pairs is
## what turns those two sentences into something that can fail — see
## `test_the_flourish_tier_is_pushed_further_and_held_longer_than_the_twitch`.
##
## NOT one pair that each subclass scales, which was the shape the issue guessed
## at. The tiers do not sit on a single factor: out goes 0.05 -> 0.10 (x2.0) while
## back goes 0.10 -> 0.18 (x1.8). One scalar would have had to move one of the four
## numbers, and a duration is invisible to every gate in this project — nothing
## headless can tell a 0.10 that was meant from a 0.10 that fell out of a multiply.
## Two declared pairs, every value preserved exactly.
##
## TWITCH_BACK_SECONDS and FLOURISH_OUT_SECONDS are both 0.10, and that is a
## coincidence rather than a dependency: the recovery of a small gesture happens to
## be the strike of a large one. Declared separately on purpose. Tying them would
## mean a recoil's recovery moved every time an upgrade's snap was retuned, which
## is the bug that shared constants are supposed to prevent, not cause.
const TWITCH_OUT_SECONDS: float = 0.05
const TWITCH_BACK_SECONDS: float = 0.10
const FLOURISH_OUT_SECONDS: float = 0.10
const FLOURISH_BACK_SECONDS: float = 0.18

## The planting pop, and the only gesture in the family whose OUT outlasts its
## BACK. It is an arrival, not a strike: the sprite starts at 0.4 and has to be
## SEEN growing before it settles, where every other pair here snaps out and eases
## home. The test below names this as the deliberate exception rather than leaving
## it as a pair that quietly breaks the rule the other five follow.
const PLANTING_POP_OUT_SECONDS: float = 0.12
const PLANTING_POP_BACK_SECONDS: float = 0.10

## The uproot/death shrink. One-way — there is no return, because there is nothing
## left to return to — so it is a single value rather than a pair. It equals
## FLOURISH_BACK_SECONDS and is declared separately for the same reason the 0.10
## above is: a plant leaving the board and a cob celebrating a purchase are not one
## number wearing two names.
const EXIT_SHRINK_SECONDS: float = 0.18

var _selected: bool = false
var _health_back: ColorRect = null
var _health_bar: ColorRect = null
## HEALTH_BAR_SEGMENTS - 1 dividers, shown only while the plant is regrowing.
## Built once and toggled rather than created on demand: a node spawned the frame
## a plant starts healing is a node that has to be freed the frame it stops, and
## the bar is refreshed from take_damage() at sixty calls a second.
var _health_notches: Array[ColorRect] = []
var _selection_marker: SelectionMarker = null
## Seconds since the last bite, capped at REGROWTH_DELAY. Capped rather than left
## to climb because nothing past the threshold reads it — regrowth_in_step() only
## cares how much of the step is past the delay — and an uncapped float would
## quietly lose precision over a long endless run for no benefit at all.
var _quiet_time: float = REGROWTH_DELAY


func setup(id: StringName, at: Vector2i, on_board: Board) -> void:
	kind = id
	cell = at
	board = on_board
	if board != null:
		position = board.cell_to_world(at)
	add_to_group("plants")
	_build_visuals()
	_on_setup()
	# Last, so it covers anything a subclass added in _on_setup() as well as the
	# bars above. See the method for why a Control on the playfield is a click
	# the player simply loses.
	_make_world_controls_click_through()


func _build_visuals() -> void:
	# The sprite hangs off the sway pivot, not off the plant — see `_sway_pivot`.
	_sway_pivot = Node2D.new()
	_sway_pivot.name = "Sway"
	add_child(_sway_pivot)

	_sprite = Sprite2D.new()
	_sprite.texture = load(PlantCatalog.texture_path(kind)) as Texture2D
	# A sport wears its parent's drawing with a shift over it, which is the whole of
	# "different but similar". Multiplied into `modulate` rather than swapped for a
	# second texture: nine more PNGs is nine more things for `test_sprite_style` to
	# police and nine more chances for a sport to stop looking like its own kind.
	if is_sport:
		_sprite.modulate = PlantMutation.TINT
	_sway_pivot.add_child(_sprite)

	_health_back = ColorRect.new()
	_health_back.color = Color(0.12, 0.12, 0.12, 0.65)
	_health_back.position = HEALTH_BAR_ORIGIN
	_health_back.size = HEALTH_BAR_SIZE
	_health_back.visible = false
	_health_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_health_back)

	_health_bar = ColorRect.new()
	# Through the switch even here, where the bar is built hidden: a plant placed
	# with the option already on and bitten before its first _refresh_health_bar()
	# would otherwise flash the default ramp's red for a frame.
	_health_bar.color = health_bar_color(false)
	_health_bar.position = HEALTH_BAR_ORIGIN
	_health_bar.size = HEALTH_BAR_SIZE
	_health_bar.visible = false
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_health_bar)

	# After the bar, so they cut into it: children of a Node2D are painted in
	# tree order, which is the same reason the bar itself is added after the
	# sprite. A notch added before the bar would be a notch painted under it.
	_health_notches = []
	for slot: Rect2 in health_bar_notch_rects():
		var notch := ColorRect.new()
		notch.color = HEALTH_BAR_NOTCH_COLOR
		notch.position = slot.position
		notch.size = slot.size
		notch.visible = false
		# The bars are Controls parked over the playfield, and a Control that
		# stops the mouse over a plant is a Control that eats the click meant to
		# select it. Set here, on the two bars above, and swept again from
		# setup() — see _make_world_controls_click_through() for why the sweep
		# is the part that matters and this line is only documentation.
		notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(notch)
		_health_notches.append(notch)

	# A sibling node, not something drawn inside this plant's own _draw() — see
	# SelectionMarker's own header for why subclasses can't be trusted to paint
	# this themselves.
	_selection_marker = SelectionMarker.new()
	# Named, because an auto-named node is unaddressable. This project treats node
	# paths as a contract -- OverlayScreen's header says so for its own rows, and the
	# devtools bridge presses and reads BY NAME -- and `@SelectionMarker@31` is a path
	# nothing can be written against, in a test or from the bridge.
	_selection_marker.name = SelectionMarker.NODE_NAME
	_selection_marker.visible = false
	add_child(_selection_marker)

	# After the selection marker, so a selected sport shows both and the mark sits on
	# top. See SportMark's header for why this is a node and not three lines inside
	# `_draw`: seven of the nine plant scripts override `_draw`, so a cue painted in
	# the base class would appear on two kinds and quietly not on the rest.
	if is_sport:
		var mark := SportMark.new()
		mark.name = SportMark.NODE_NAME
		add_child(mark)

	# Planting pop: the sprites are centred on their own vertical axis, which is
	# what makes a scale tween land without drifting off the cell.
	if not is_inside_tree():
		return
	_sprite.scale = Vector2(0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2(1.12, 1.12), PLANTING_POP_OUT_SECONDS)
	tween.tween_property(_sprite, "scale", Vector2.ONE, PLANTING_POP_BACK_SECONDS)


## Every Control this plant owns stops taking mouse input.
##
## The viewport runs its GUI pass *before* `_unhandled_input`, and a Control
## parented to a Node2D is still a GUI root — it is picked in world space with
## the Node2D's transform applied, exactly where it is drawn. Game reads the
## whole board out of `_unhandled_input` (Game._click_at), so any Control parked
## over the playfield at the default MOUSE_FILTER_STOP swallows the press before
## Game is ever offered it. Not "the click does the wrong thing": nothing at all
## happens, which is the worst shape a bug can take on a board where every
## action the player has is a click.
##
## The bar is HEALTH_BAR_SIZE at HEALTH_BAR_ORIGIN — the middle half of the top
## three pixels of the plant's own cell, plus two pixels of the cell above — and
## it only exists once the plant has been bitten. So the dead patch appeared on
## exactly the plants the player was reaching for, and only after something had
## gone wrong, which is the worst moment to lose a click on.
##
## Swept over the subtree rather than left as a rule at each construction site,
## because the per-node version is a thing the next person has to already know:
## the notches in _build_visuals() were added later and had to rediscover it,
## while the two bars they were added between had it wrong from the beginning.
## Called from setup() after _on_setup(), so a subclass that adds a Control of
## its own is covered without knowing any of this.
##
## Pest carries a copy of this method for the same reason. Deliberately a copy
## and not a shared static: Plant and Pest already name each other in their
## signatures, and a static call across that cycle is not a dependency worth
## taking on for six lines of `find_children`.
func _make_world_controls_click_through() -> void:
	for node: Node in find_children("*", "Control", true, false):
		var control := node as Control
		if control == null:
			continue
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_setup() -> void:
	pass


## Shrinks the sprite to nothing and frees this Node — the mirror of
## _build_visuals()'s pop-in, played on the way off the board instead of onto
## it. Callers (Game._on_plant_destroyed, Game.commit_uproot) have already
## dropped this plant from `_plants` and any selection before reaching here, so
## the Node lingering in the tree for the tween's duration touches nothing
## else: Game drives `_act()` off that dict, not off the "plants" group, so an
## entry no longer in it has already stopped acting.
##
## Headless pumps no frames, so a Tween queued here never runs — this frees on
## the spot instead, same as every call site did before this existed.
func play_exit_and_free() -> void:
	if _sprite == null or not is_inside_tree() or not GardenTheme.animations_enabled():
		queue_free()
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2.ZERO, EXIT_SHRINK_SECONDS)
	tween.tween_callback(queue_free)


## Regrowth runs here rather than in `_act()` on purpose: `_act` is the hook every
## subclass overrides, and not one of them chains to super, so a heal written
## there would exist on the base class and on nothing the player can actually
## plant. Same trap SelectionMarker's header describes for `_draw`.
func _physics_process(delta: float) -> void:
	_regrow(delta)
	_wobble(delta)
	_act(delta, _live_pests())


## Advances the idle-sway clock every frame regardless of the gate below, so
## `_wobble_time` stays meaningful (rather than frozen at 0) if animations are
## ever toggled on mid-run; only the rotation it drives is gated. Reads `cell`
## for a per-plant phase so a bed of identical plants doesn't rock as one
## rigid slab — the same reason TitleScreen phases its lawn by array index,
## which a planted Plant has none of.
func _wobble(delta: float) -> void:
	_wobble_time += delta
	# Decayed OUTSIDE the gate, for the same reason the clock above advances outside it:
	# a mid-run animations toggle should find a meaningful value, not one frozen at
	# whatever it held when the toggle went off.
	_flinch_left = maxf(0.0, _flinch_left - delta)
	if _sway_pivot == null or not GardenTheme.animations_enabled():
		return
	var clock: float = _wobble_time * WOBBLE_RATE + _wobble_phase(cell)
	# The flinch rides its own fast clock rather than a multiple of the sway's, so the two
	# never phase-lock into one larger sway -- which is what a shared clock at a harmonic
	# ratio would look like, and it would read as "sways more when bitten" instead of
	# "flinched".
	# ADDED, not blended: the wilt is a held offset the sway swings ABOUT, so a dying plant
	# still breathes and still flinches at full amplitude from a leaning rest position.
	# Replacing the angle instead would have bought the lean by spending the two channels
	# that say "alive" and "just bitten".
	var angle: float = (sin(clock) * WOBBLE_RADIANS
		+ sin(_wobble_time * FLINCH_RATE) * FLINCH_RADIANS * flinch_amount(_flinch_left)
		+ wilt_angle(wilt_amount(health / MAX_HEALTH), _wobble_phase(cell)))
	# One transform rather than `rotation` and `scale` separately, because the pivot
	# POINT is the third thing being set and there is no property for it — see
	# `sway_transform`. Both of the reads this replaces still work: Godot decomposes
	# `rotation` and `scale` back out of the transform, and the origin it also carries
	# is zero whenever the angle is.
	# MULTIPLIED into the breathe rather than replacing it, so a plant with something to
	# say about its own body says it ON TOP of the idle motion every plant shares. The
	# default is Vector2.ONE, which is the identity for a component-wise multiply, so a
	# plant that does not override this is byte-for-byte unchanged by the hook existing.
	_sway_pivot.transform = sway_transform(angle,
		breathe_scale(clock) * idle_scale_multiplier(_wobble_time))


## Subclass hook: an extra body-axis scale this plant wants on top of the shared breathe.
##
## SCALE and not rotation, because rotation on `_sway_pivot` is already spoken for twice —
## the sway and the flinch ride it, and a third writer there would have to phase against
## both. Scale has exactly one owner on this pivot (`breathe_scale`) and multiplying is
## how two scales compose without either needing to know the other's amplitude.
##
## Takes the raw `_wobble_time` rather than the sway's `clock`, deliberately: the sway
## clock carries a per-cell phase (`_wobble_phase`) so a bed of plants does not rock as
## one slab, and a subclass motion that is ABOUT AN EVENT — a mouth chewing — should be in
## step with the event rather than with where the plant happens to stand.
##
## Returns ONE here rather than being abstract, because "no opinion" is the right answer
## for every plant but one and an abstract hook would make eight files declare it.
func idle_scale_multiplier(_clock: float) -> Vector2:
	return Vector2.ONE


## Pure: the breathe's scale at a point on the sway clock. Split out for the same
## reason `_wobble_phase` is — everything inside `_wobble` past the gate is
## unreachable headless, so a test that pumps `_wobble` and then asserts what
## moved passes whatever the body does. Cycle 71 wrote exactly that test, watched
## a mutation pointing the breathe at `_sprite.scale` survive it, and split this
## out in response.
## Pure: how much of the flinch is left, 1.0 the instant of a bite down to 0.0.
##
## Split out for the reason `breathe_scale` was: everything in `_wobble` past the
## `animations_enabled()` gate is unreachable headless, so a test that pumps `_wobble` and
## reads what moved is testing an early return. This is the half a headless suite can hold.
static func flinch_amount(left: float) -> float:
	return clampf(left / FLINCH_SECONDS, 0.0, 1.0)


static func breathe_scale(clock: float) -> Vector2:
	var breathe: float = sin(clock * BREATHE_RATE) * BREATHE_AMOUNT
	return Vector2(1.0 - breathe, 1.0 + breathe)


## Pure: the entire transform the idle sway puts on `_sway_pivot` — the rotation, the
## breathe, and the point both of them happen ABOUT.
##
## Split out for the reason `breathe_scale` and `flinch_amount` were: everything in
## `_wobble` past the `animations_enabled()` gate is unreachable headless, so a test
## that pumps `_wobble` and reads what moved is testing an early return. This is the
## whole geometry, in the one place a headless suite can hold it, and it is the same
## call the running game makes rather than a restatement of it.
##
## **Why the pivot point is a transform and not this node's `position`.** `_sprite`
## sits at the pivot's origin with `offset` zero, and both of those zeroes are
## load-bearing, in different ways:
##
##   * `ChompFlower._bite()` and `Nettle._sting_twitch()` tween `_sprite.position` out
##     to a lunge/thrust and home again to `Vector2.ZERO`. Pushing the pivot node down
##     and pulling the sprite node up to compensate would make ZERO the wrong home, and
##     both gestures would finish by yanking the plant STEM_PIVOT_Y px off its cell.
##   * `Sprite2D.offset` is applied inside the sprite's OWN local space, so it is
##     multiplied by `_sprite.scale`. Compensating with `offset` instead would make all
##     five scale flourishes scale about the stem rather than about the sprite centre —
##     the planting pop starts at 0.4, so it would arrive `0.6 * STEM_PIVOT_Y` = 15 px
##     underground and slide up out of the soil, and `play_exit_and_free`'s shrink to
##     zero would collapse into the ground rather than into the plant. The comment at
##     the pop's own construction ("the sprites are centred on their own vertical axis,
##     which is what makes a scale tween land without drifting off the cell") is exactly
##     the invariant that route breaks.
##
## Folding the offset into the pivot's own transform touches neither, because a child's
## local translation is mapped by the parent's BASIS and only the ORIGIN changed here.
## The basis is the same rotation and scale it always was, so a 7 px lunge still travels
## 7 px, still leans by at most the sway angle (the property `ChompFlower._bite` calls
## deliberate), and still comes home to the same pixel.
##
## Returns `Transform2D.IDENTITY` at rest, which is the other half of the promise: a
## plant standing still, and every headless run with the gate shut, is exactly what it
## was before the pivot moved.
static func sway_transform(angle: float, breathe: Vector2) -> Transform2D:
	var about := Vector2(0.0, STEM_PIVOT_Y)
	var spun := Transform2D(angle, breathe, 0.0, Vector2.ZERO)
	spun.origin = about - spun.basis_xform(about)
	return spun


## Pure: per-cell phase offset for the sway above. Split out so a test can
## assert two neighbouring cells land on different phases without a live tree.
static func _wobble_phase(at: Vector2i) -> float:
	return float(at.x) * 1.7 + float(at.y) * 0.9


## One step of recovery. A destroyed plant never comes back — Game frees the node
## on `destroyed`, but the guard is here anyway so a plant that hits 0 in the same
## frame something else is iterating cannot be resurrected by the next tick.
## Gives health back at once, capped at full and refused on a destroyed bed.
##
## Distinct from `_regrow()`, which is the slow per-frame recovery gated behind
## REGROWTH_DELAY. This is the one-shot kind: a rain wave opening
## (plant-tower-defense-q3lx). It deliberately does NOT touch `_quiet_time`, so
## rain landing on a bed that is being eaten right now heals it without also
## restarting the regrowth clock the biting is supposed to hold at zero.
##
## Returns how much was actually given, which is not always what was asked for --
## a plant at 90% takes 10%, and the caller that wants to say "healed" needs to
## know the difference between a heal and a no-op.
func heal(amount: float) -> float:
	if amount <= 0.0 or is_destroyed() or health >= MAX_HEALTH:
		return 0.0
	var before: float = health
	health = minf(MAX_HEALTH, health + amount)
	_refresh_health_bar()
	return health - before


func _regrow(delta: float) -> void:
	if delta <= 0.0:
		return
	var gained: float = 0.0
	if not is_destroyed() and health < MAX_HEALTH:
		gained = regrowth_in_step(_quiet_time, delta)
	_quiet_time = minf(_quiet_time + delta, REGROWTH_DELAY)
	if gained <= 0.0:
		return
	health = minf(MAX_HEALTH, health + gained)
	_refresh_health_bar()


## Pure: hp put back during a `delta`-second step that begins `quiet_before`
## seconds after the last bite.
##
## Only the part of the step past REGROWTH_DELAY counts, so a step straddling the
## threshold grows its tail and not the whole of itself. That matters more than it
## looks: without it, a 5-second devtools `step-time` landing one frame after the
## delay would hand back 5 seconds of growth the plant had not earned, and the
## boundary test below would pass on a mechanic that cheats at low frame rates.
static func regrowth_in_step(quiet_before: float, delta: float) -> float:
	if delta <= 0.0:
		return 0.0
	var growing: float = minf(delta, maxf(0.0, quiet_before + delta - REGROWTH_DELAY))
	return growing * REGROWTH_RATE


## Pure: how long a plant sitting at `from_health` needs to be whole again, with
## nothing biting it in the meantime. Includes the delay, because the delay is
## part of what the player is waiting out. 0.0 for a plant that is already whole.
static func seconds_to_full_from(from_health: float) -> float:
	var missing: float = clampf(MAX_HEALTH - from_health, 0.0, MAX_HEALTH)
	if missing <= 0.0:
		return 0.0
	return REGROWTH_DELAY + missing / REGROWTH_RATE


## Pure: how long a full-health bed lasts against something chewing it at `dps`.
## Takes the rate as an argument rather than reading Pest.EAT_DPS so this file
## stays ignorant of Pest — and so the test that pins "regrowth does not save a
## bed under attack" has to name the number it is comparing against.
static func seconds_to_be_eaten(dps: float) -> float:
	if dps <= 0.0:
		return INF
	return MAX_HEALTH / dps


## What fraction of an incoming bite actually lands on this plant. 1.0 for every plant
## that simply takes what it is given, which is eight of the nine.
##
## A method on the base class rather than a type check in the HUD, and that is the whole
## point of it: `_refresh_health` asks every plant the same question and gets an honest
## answer, instead of the readout carrying a list of which plants are special. The list
## is the thing that goes stale — see `PlantCatalog.on_road`'s header for the same
## argument about placement.
##
## Overriding this is NOT enough on its own to make a plant tough; `take_damage` has to
## apply it. `Bramble` does both and its override reads this rather than the constant
## directly, so the two cannot disagree — which is what
## test_a_resisting_plant_takes_exactly_the_fraction_it_declares pins.
func bite_resistance() -> float:
	return 1.0


## How many seconds of chewing at `dps` this plant has left, from the health it has NOW
## and through whatever resistance it declares.
##
## The instance counterpart of `seconds_to_be_eaten` above, and it answers the question a
## player actually has while looking at the panel — "will this hold?" — rather than the
## balance question "how tough is this kind of plant". Same ignorance of `Pest`: the rate
## is an argument, so the caller names the number it means.
##
## INF when nothing is eating it or when it cannot be eaten, which is the honest answer
## rather than a division by zero.
func seconds_of_chewing_left(dps: float) -> float:
	var rate: float = dps * bite_resistance()
	if rate <= 0.0:
		return INF
	return health / rate


## Whether this plant is currently putting health back on. What the bar's colour
## follows, and what a readout would ask.
func is_regrowing() -> bool:
	return not is_destroyed() and health < MAX_HEALTH and _quiet_time >= REGROWTH_DELAY


## Seconds of quiet still owed before regrowth starts; 0.0 once it has started.
func seconds_until_regrowth() -> float:
	return maxf(0.0, REGROWTH_DELAY - _quiet_time)


func _act(_delta: float, _pests: Array[Pest]) -> void:
	pass


func _live_pests() -> Array[Pest]:
	var out: Array[Pest] = []
	for node: Node in get_tree().get_nodes_in_group("pests"):
		var pest := node as Pest
		if pest != null and pest.is_alive():
			out.append(pest)
	return out


## Whichever live pest inside `radius` is furthest along the road. Leaking a pest
## costs a life, so the one closest to the exit is always the right target.
##
## **"live" is checked, not assumed.** The array comes from the caller, and Game
## rebuilds it from the `pests` group every frame — so in a real run every entry is
## valid by construction. That is a property of one caller, not of this function, and
## a targeting routine that dereferences a freed node crashes the game rather than
## failing an assertion. Reached for real: a harness regression froze a pest between
## a test hosting it and this loop running, and the result was an access violation
## (see plant-tower-defense-or67 and gh#43).
##
## Note what the guard costs, because it is not free: a caller passing a stale array
## now gets a quietly smaller candidate set instead of a crash. That is the right
## trade for a shipped game and the wrong one for a test, which is why
## test_corn_shoots_the_pest_closest_to_escaping asserts its pests are still valid
## before it calls this — the guard protects the player, the assertion keeps the
## signal.
func _furthest_along_in_range(pests: Array[Pest], radius: float) -> Pest:
	var best: Pest = null
	var best_progress: float = -1.0
	for pest: Pest in pests:
		if pest == null or not is_instance_valid(pest):
			continue
		if pest.global_position.distance_to(global_position) > radius:
			continue
		var p: float = pest.progress()
		if p > best_progress:
			best_progress = p
			best = pest
	return best


## What a pristine plant hands back, as a fraction of its cost. Strictly under 1.0
## for every entry in the catalogue or replanting becomes an infinite seed printer
## — test_uprooting_refunds_less_than_it_cost pins that.
const UPROOT_RATE_FULL: float = 0.6

## What a plant one bite from death hands back. It is deliberately NOT zero: a
## refund that decays to nothing turns uprooting a wreck into a punishment for
## having been attacked, and the whole point of the slope is to stop the player
## recycling damaged plants, not to strand them on a cell they cannot clear. At
## 0.2 the scrap value is real but never a repair — see uproot_refund().
const UPROOT_RATE_WRECK: float = 0.2

## And a hard floor under the fraction, so a hypothetical 3-seed plant still pays
## something back rather than rounding down into nothing.
const MIN_UPROOT_REFUND: int = 1


## Sold/uprooted plants refund a share of what they cost, and the share slides
## with what is left of the plant.
##
## Before this, the refund read only the catalogue cost, so a Corn Cobbler at 1hp
## refunded the same 6 as one that had never been touched — which made
## uproot-and-replant a 4-seed full heal, strictly better than leaving a damaged
## plant standing, and made the health bar a readout with no decision attached to
## it. Now a wreck refunds 2 and costs 10 to replace: recycling is scrap value,
## never repair.
##
## Linear between the two rates rather than stepped, because the HUD prints this
## number live (Hud._refresh_selection, refreshed by Game._watch_selected_health)
## and a number that slides as the plant is eaten reads as a consequence; one that
## jumps at a threshold reads as a bug.
##
## Regrowth (see REGROWTH_RATE) is what turns this slope into a choice rather than
## a tax. Scrapping a wrecked Corn Cobbler is 2 back against a 10-seed replant and
## the loss of its upgrade level; leaving it standing is free and takes ~32s. The
## refund is the price of not waiting, which is only a price now that waiting
## works.
func uproot_refund() -> int:
	var fraction: float = clampf(health / MAX_HEALTH, 0.0, 1.0)
	var rate: float = UPROOT_RATE_WRECK + (UPROOT_RATE_FULL - UPROOT_RATE_WRECK) * fraction
	return maxi(MIN_UPROOT_REFUND, int(floor(PlantCatalog.cost(kind) * rate)))


## What the player has put into this plant: what it cost to buy plus every seed spent
## climbing it. The number a MOVE is priced against, and it is not the same number a
## refund is priced against — `uproot_refund()` scales the BASE cost alone, which is
## exactly why relocating an upgraded plant is expensive today (plant-tower-defense-h5w6).
func invested_value() -> int:
	return PlantCatalog.cost(kind) + upgrade_spent()


## THE PRICE OF MOVING, and the decision this constant records
## (plant-tower-defense-h5w6).
##
## THE BEAD ASKED THE WRONG QUESTION, and answering the asked one would have shipped
## nothing worth having. It framed the choice as "free moves are costless, full price is
## cruel, refund-minus-cost is the middle" — but refund-minus-cost is FOUR SEEDS on a
## healthy Corn Cobbler, which is the free option with extra arithmetic. The reason nobody
## relocates anything is not the seeds. It is that `commit_uproot()` frees the plant, so a
## move destroys the LEVEL: `uproot_refund()` scales the base cost, and `Hud`'s own armed
## prompt says the quiet part out loud — "Its %d upgrade seeds are not refunded."
##
## Priced out, on a healthy Corn Cobbler:
##   * fresh, uproot + rebuy:      10 - 6 = 4 seeds and nothing lost
##   * fully climbed, same route:  10 - 6 + 65 forfeited = 69 seeds AND the climb again
##
## So the cost of moving today scales with exactly how much the player cared about the
## plant, which is backwards: the plants worth moving are the ones it is prohibitive to
## move. That is the defect, and the price is only half its fix — the other half is that
## a move must PRESERVE the plant rather than replacing it.
##
## A QUARTER OF WHAT YOU HAVE PUT IN, so four moves cost you the plant. That is the whole
## rule and it is meant to be sayable: it scales with what is at stake without ever
## approaching the 69 that made the feature dead, it is never free, and a player can
## predict it from a number the game already shows them in the forfeit clause.
##
## Rounded UP and floored at one, so the cheapest possible move still costs something —
## a free move is the option the bead correctly rules out, and integer division would
## have quietly reintroduced it for every plant under four seeds.
const MOVE_RATE: float = 0.25
const MIN_MOVE_COST: int = 1


func move_cost() -> int:
	return maxi(MIN_MOVE_COST, int(ceil(float(invested_value()) * MOVE_RATE)))


# -- Upgrades ---------------------------------------------------------------
#
# The whole upgrade surface, for every plant, in one place. It was a CornCobbler
# feature for ninety-nine cycles: `level`, `upgrade()`, `upgrade_cost()`,
# `level_name()` and `is_max_level()` all lived on the cob, and both call sites
# — `Game.upgrade_selected` and `Hud._refresh_selection` — reached them through
# `selected_placed as CornCobbler`. A cast IS a decision, and the decision it was
# making was "corn is the only plant that grows", which is a statement about the
# 2026-06 catalogue rather than about the game.
#
# What moves here is only the ladder MACHINERY. Every number stays in the plant
# that owns it: a subclass overrides `upgrade_ladder()` to return its own const
# table and nothing else about it is special-cased anywhere. So the next plant to
# grow a ladder is a const and a one-line override — not a fourth branch at two
# call sites and a fifth in the message corpus.
#
# **A plant is upgradeable iff its ladder is non-empty**, and that is the only
# test anything may make. `has_upgrades()` is the name of that decision; nothing
# outside this block is allowed to ask it by naming a class.

## The default ladder: a plant that does not grow. Named rather than written as a
## bare `[]` at the one place it is returned, so the "no ladder" case reads as a
## deliberate answer and not as a stub someone forgot to fill in.
const NO_LADDER: Array[Dictionary] = []

## Which rung of `upgrade_ladder()` this plant is on, 1-based. 1 for every plant
## in the game the moment it is planted, including the ones with no ladder at all
## — `max_level()` is 1 for those, so they are born fully grown and `can_upgrade()`
## is false without anyone writing a guard.
##
## Written by `upgrade()` and by nothing else in the game (tests set it directly to
## reach a rung without paying for it). Not persisted: uprooting a plant loses its
## level, which is the rule `uproot_refund()`'s header already states.
var level: int = 1


## This plant's ladder: one Dictionary per level, lowest first. Empty means "this
## plant does not grow", which is the default and is what six of the seven entries
## in `PlantCatalog` still answer.
##
## Two keys are required of every row because this file reads them:
##   * `"name"` — what the level is called, for the selection panel and the message
##     row. Short: it is measured against `Hud`'s message-row budget.
##   * `"upgrade_cost"` — seeds to reach the NEXT level, and 0 on the last row.
## Everything else in a row belongs to the plant and is read by that plant alone
## (`CornCobbler` keeps kernels, spread, interval and damage there; `ChompFlower`
## keeps a chew scale and a reach scale).
##
## Overridden rather than configured through a registry keyed on `kind`, because a
## registry is a second place the answer lives and this one cannot drift: the
## ladder is a const in the class whose behaviour reads it.
func upgrade_ladder() -> Array[Dictionary]:
	return NO_LADDER


## Pure: row `for_level` of `ladder`, clamped to its ends, and `{}` for a plant
## with no ladder at all.
##
## The clamp matters more than it looks. Every stat lookup in every upgradeable
## plant goes through here, so a level that has somehow run past the end of the
## table returns the top row instead of indexing out of bounds and taking the
## frame with it — and an EMPTY ladder returns an empty row rather than reading
## `ladder[-1]`, which is the case a `clampi(...)` written without the guard gets
## wrong for exactly the six plants that do not grow.
static func ladder_row(ladder: Array[Dictionary], for_level: int) -> Dictionary:
	if ladder.is_empty():
		return {}
	return ladder[clampi(for_level - 1, 0, ladder.size() - 1)]


## Pure: what level `for_level` is called on `ladder`; "" when there is no ladder.
static func ladder_level_name(ladder: Array[Dictionary], for_level: int) -> String:
	return String(ladder_row(ladder, for_level).get("name", ""))


## Pure: seeds to leave `for_level` for the next rung, and 0 when there is no next
## rung — either because this is the top of the ladder or because there is no
## ladder. Both zeroes mean the same thing to a caller ("nothing to buy here"), so
## they are deliberately not distinguished; `has_upgrades()` is the question that
## separates them and the HUD asks it first.
static func ladder_upgrade_cost(ladder: Array[Dictionary], for_level: int) -> int:
	if ladder.is_empty() or for_level >= ladder.size():
		return 0
	return int(ladder_row(ladder, for_level).get("upgrade_cost", 0))


## Pure: what has ALREADY been spent getting a plant to `for_level`, in seeds.
##
## Summed from the ladder rather than written down, which is the whole reason
## `CornCobbler.upgrade_spend` existed: the cob's ladder is 20 then 45 and a
## hand-typed 65 is a second source of truth that a retune silently falsifies — on
## a number the player is about to be told they are forfeiting
## (`Hud.uproot_armed_message`). Generic now, so the second upgradeable plant gets
## an honest forfeit line without anyone noticing it needed one.
static func ladder_spend(ladder: Array[Dictionary], for_level: int) -> int:
	var spent: int = 0
	for i: int in range(mini(for_level, ladder.size()) - 1):
		spent += int(ladder[i].get("upgrade_cost", 0))
	return spent


## Does this plant grow at all? THE question the Upgrade button is gated on, and
## the replacement for `selected_placed as CornCobbler`.
func has_upgrades() -> bool:
	return not upgrade_ladder().is_empty()


## WHAT THE NEXT RUNG BUYS, as a short phrase for the upgrade button
## (plant-tower-defense-jvnm).
##
## The notebook tells the player "Climbing one plant beats adding another", and until
## cycle 171 they had no way to check it: the selection panel shows what this plant IS at
## its current rung, and the price arrives separately, with nothing connecting the two. A
## player at the moment of deciding had a damage number and a number of seeds.
##
## `""` FOR A PLANT WITH NO LADDER AND FOR ONE AT THE TOP, and both callers want that: the
## button is hidden for the first and reads "Fully grown" for the second, so there is no
## next rung to describe in either case.
##
## EACH PLANT ANSWERS IN THE CURRENCY ITS OWN DETAIL LINE ALREADY USES, and that is the
## rule rather than a coincidence. A cob's line reads damage, so its gain is damage. A
## Bramble's reads how many seconds of chewing it has left, so its gain is seconds. A
## Chomp's reads chew PROGRESS and has no absolute to point at — a chew's length belongs
## to the pest, not the flower (`Pest.chew_seconds` runs 0.45 to 2.6 by species) — so its
## gain is the proportion, which is the only honest thing a flower can say by itself.
## Forcing one shape on all three would mean inventing a number for the Chomp.
##
## Overridden, not dispatched on. `Hud._refresh_selection` asks the plant, the way it
## already asks `has_upgrades()` and `bite_resistance()` — the casts that used to live
## there are what made a second upgradeable plant unreachable.
func upgrade_gain() -> String:
	return ""


## The top rung. 1 for a plant with no ladder, so `is_max_level()` is true for it
## and every "already at the top" path treats it as finished rather than broken.
func max_level() -> int:
	return maxi(1, upgrade_ladder().size())


func is_max_level() -> bool:
	return level >= max_level()


## Is there a rung above this one to buy? `has_upgrades() and not is_max_level()`,
## named because it is the condition `upgrade()` refuses on and the condition the
## button is enabled by, and two call sites spelling out the same `and` is how the
## two ended up disagreeing about the Sunflower.
func can_upgrade() -> bool:
	return has_upgrades() and not is_max_level()


func upgrade_cost() -> int:
	return ladder_upgrade_cost(upgrade_ladder(), level)


func level_name() -> String:
	return ladder_level_name(upgrade_ladder(), level)


## This plant's own row of its own ladder — where a subclass reads its stats.
func level_row() -> Dictionary:
	return ladder_row(upgrade_ladder(), level)


## Seeds already sunk into this plant's level, which an uproot forfeits.
##
## `upgrade_spent`, past tense, and NOT `upgrade_spend` — that name is taken by
## `CornCobbler`'s static, which asks the same question of the CLASS (`Hud`'s message
## corpus prices the armed prompt at the ladder's maximum, which no instance can
## answer). GDScript refuses a static and an instance method of one name in one
## hierarchy, and `name_check --require-compile` said so within a minute of the two
## being written. Different question, different tense, different name.
func upgrade_spent() -> int:
	return ladder_spend(upgrade_ladder(), level)


## Buy the next rung. Returns false — changing nothing — when there is no next
## rung, which is both the top of a ladder and a plant that has none.
##
## The caller charges for it. This is deliberate and it is the same split
## `Game.upgrade_selected` already used: the seeds are the bank's business, the
## level is the plant's, and a plant that could spend the player's seeds would be
## a plant a test cannot exercise without a Game.
##
## `queue_redraw()` is here rather than in each subclass's hook because a ladder
## the player cannot see is the defect this whole surface exists to avoid — every
## upgradeable plant wears its level (the cob's muzzle fan, the flower's fang
## crown), and a plant that repaints only when something else dirties its canvas
## shows the level the player paid to leave behind. The cue is played here for the
## same reason: it is the sound of the purchase landing, and it used to sit inside
## `CornCobbler._upgrade_flourish` BEHIND `GardenTheme.animations_enabled()` —
## so a player with animations turned off bought upgrades in silence.
func upgrade() -> bool:
	if not can_upgrade():
		return false
	level += 1
	queue_redraw()
	Sfx.play(Sfx.PLANT_UPGRADED)
	_on_upgraded()
	return true


## What this plant does when it grows — its sprite flourish, a re-tuned timer,
## whatever. Runs after `level` has already moved, so it reads the NEW level.
## Empty here: the base class owns the ladder, never the celebration.
func _on_upgraded() -> void:
	pass


## A hungry pest calls this instead of walking past. Game listens for
## `destroyed` and removes the plant from the board — no refund, it was eaten.
func take_damage(amount: float) -> void:
	if is_destroyed():
		return
	health = maxf(0.0, health - amount)
	# A hungry pest calls this every physics frame, so this would be sixty plays
	# a second if it were not gated — Sfx.REPEAT_MS[PLANT_BITTEN] is what turns
	# that stream of calls into a repeating nibble, which is why the call site
	# here stays unguarded. The bar below only appears once a plant is bitten,
	# and a bar the player is not looking at is not a warning.
	if amount > 0.0:
		Sfx.play(Sfx.PLANT_BITTEN)
		# THE line that keeps regrowth out of a fight. A pest mid-meal calls this
		# every frame, so the quiet clock never leaves zero while it is eating and
		# regrowth_in_step() therefore returns zero for every one of those frames.
		# A 0-damage call is not a bite and does not reset it.
		_quiet_time = 0.0
		# Re-armed rather than accumulated: a hungry pest calls this every physics frame,
		# so a plant mid-meal shudders continuously and decays out once the biting stops.
		_flinch_left = FLINCH_SECONDS
	_refresh_health_bar()
	if health <= 0.0:
		destroyed.emit(self)


## The in-world bar, for both directions. It hides itself again once the plant is
## whole, which is the same rule that kept it hidden before the first bite: a full
## bar is not a warning, and leaving one painted over a recovered bed would make
## regrowth look like it had not happened.
## Repaint the in-world bar without anything having happened to the plant.
##
## The bar is drawn from take_damage() and _regrow() — i.e. only when the number
## moves — which is right for a readout and wrong for a *palette* change. A player
## who presses the colourblind-safe key while a chewed plant sits quietly on the
## board would otherwise watch nothing happen to the one bar the option is most
## for, until something bit it again. Game's handler calls this for every placed
## plant, the same reason it calls Hud._refresh() rather than waiting for state.
func repaint_health_bar() -> void:
	_refresh_health_bar()


func _refresh_health_bar() -> void:
	if _health_back == null or _health_bar == null:
		return
	var fraction: float = clampf(health / MAX_HEALTH, 0.0, 1.0)
	var whole: bool = fraction >= 1.0
	var regrowing: bool = is_regrowing()
	_health_back.visible = not whole
	_health_bar.visible = not whole
	_health_bar.size = Vector2(HEALTH_BAR_SIZE.x * fraction, HEALTH_BAR_SIZE.y)
	_health_bar.color = health_bar_color(regrowing)
	# The shape channel. Hidden with the bar, so a whole plant wears neither.
	for notch: ColorRect in _health_notches:
		notch.visible = (not whole) and regrowing


## Pure: which colour the bar wears. Split out so the cue is assertable without a
## viewport — the bar is a ColorRect child, so nothing else about it is.
##
## Kept as the *first* of two channels rather than the only one. See
## health_bar_segments() for the second and HEALTH_BAR_SEGMENTS for why a lone
## red-versus-green readout was the wrong thing to have shipped — the notches are
## not superseded by the switch below, they are the half of the cue that works on
## a screenshot, in greyscale, and for a player who never finds the option.
##
## Split into a reading half and a pure half exactly as `Hud.health_color` /
## `Hud.health_color_on` are, and for the same reason: the ramp tests drive the
## pure one so they cannot be changed by a setting an earlier test left on.
static func health_bar_color(regrowing: bool) -> Color:
	return health_bar_color_on(regrowing, RunConfig.colorblind_safe)


## The two states as the two ends of the HUD's own health ramp, so a build cannot
## end up with a safe fill on the side panel and a green-to-red bar on the board
## six inches away — which is precisely what it had.
static func health_bar_color_on(regrowing: bool, safe: bool) -> Color:
	if regrowing:
		return Hud.HEALTH_FULL_SAFE if safe else HEALTH_BAR_REGROWING
	return Hud.health_color_on(0.0, safe)


## Pure: how many blocks the bar reads as — 1 whole one while a plant is bleeding,
## HEALTH_BAR_SEGMENTS while it is healing.
##
## The shape channel expressed as a number so a test can assert the two states
## differ *with the colour thrown away*, which is the only form of the assertion
## that says anything about the player this cue exists for.
static func health_bar_segments(regrowing: bool) -> int:
	return HEALTH_BAR_SEGMENTS if regrowing else 1


## Pure: where the dividers sit, in the plant's own local space, evenly across the
## whole slot rather than across the filled part — see HEALTH_BAR_SEGMENTS for why
## the empty remainder has to carry them too.
##
## The drawn notches are built straight out of this, so the geometry a test pins
## and the geometry on screen cannot drift apart.
static func health_bar_notch_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if HEALTH_BAR_SEGMENTS < 2:
		return out
	for i: int in range(1, HEALTH_BAR_SEGMENTS):
		var across: float = HEALTH_BAR_SIZE.x * float(i) / float(HEALTH_BAR_SEGMENTS)
		var left: float = HEALTH_BAR_ORIGIN.x + across - HEALTH_BAR_NOTCH * 0.5
		out.append(Rect2(Vector2(left, HEALTH_BAR_ORIGIN.y),
			Vector2(HEALTH_BAR_NOTCH, HEALTH_BAR_SIZE.y)))
	return out


func is_destroyed() -> bool:
	return health <= 0.0


## Shows, on the plant itself, that an uproot is one click from removing it
## (plant-tower-defense-rtgp).
##
## The message row already says so in a sentence with a four-second life. This is the
## same fact on the thing it is about — the bed the player is deciding to destroy —
## which is where the Keys screen's armed reset put it too.
##
## Routed through the marker rather than drawn here because the marker is already the
## "this plant is the subject" overlay, and a second overlay saying nearly the same
## thing is how two cues end up disagreeing. A plant with no marker (one built outside
## a Game) is a silent no-op rather than an error.
func set_uproot_armed(armed: bool) -> void:
	if _selection_marker != null and is_instance_valid(_selection_marker):
		_selection_marker.set_warning(armed)


# ------------------------------------------------------------------- reach ring

## How far this plant's reach ring is drawn, in px, or 0.0 for a plant that draws
## none — which is the honest answer for a Sunflower and the base answer here.
##
## A subclass overrides THIS rather than passing a number to `draw_reach_ring()`, and
## the difference is the whole reason the ring is testable: headless runs no `_draw()`
## at all, so a radius handed straight to a draw call is a number no test can ever
## read. Overriding a getter puts the same number somewhere
## `test_every_plant_with_a_reach_draws_a_ring_at_that_reach` can hold against
## `PlantCatalog.reach()`, which is the other half of the same claim.
func reach_ring_radius() -> float:
	return 0.0


## The hue of that ring. Per-plant on purpose — every reach in this game is drawn in
## its own plant's colour, and Nettle's header argues why (the sprite is orange, the
## SHAPE is the signal). The ALPHA is not per-plant: `REACH_RING_ALPHA` is the
## grammar's, and a subclass returning some other one is picking a second brightness
## for a single statement. Never read while `reach_ring_radius()` is 0.
func reach_ring_color() -> Color:
	return Color(1.0, 1.0, 1.0, REACH_RING_ALPHA)


## The drawn-overlay grammar's REACH row (`game/OVERLAY_GRAMMAR.md`) — a solid full
## ring, plant-sized, centred on a plant, meaning "this is how far it acts" — with
## exactly one implementation.
##
## Six plants each wrote that sentence themselves before this existed, in THREE
## different shapes: fill-and-edge (Corn, Dandelion), fill-only (the Sundew's wash)
## and edge-only (Mint, Nettle, Aloe). One grammar row implemented six times is not a
## rule, it is six agreements, and three of those six were written after the rule was
## documented.
##
## **THE RING IS THE EDGE; the fill was a flourish and it is gone.** That is a
## decision, so here is its reason rather than a preference. The grammar's own
## per-row channel table names SIZE and CENTRE as what carries this row once the
## colour is thrown away, and both of those live entirely in the edge — a fill adds no
## channel. Worse, the same table's *Filled dot* row states outright that fill-versus-
## outline is itself a meaning-bearing channel ("a disc and an outline ring are
## different marks before they are different colours"), so a wash inside two of six
## reach rings made those two a different mark by the document's own rule.
## `PlacementPreview`, which draws the reach a plant *would* have, has never carried a
## fill: a filled selected ring and an unfilled hover ring were already two shapes for
## one statement, and the hover is the one the player meets first.
##
## The Sundew's sap wash is NOT an exception to this and never was. It is the patch
## itself — ground with sap on it, painted whether or not anything is selected, and
## clipped away where a neighbouring patch got there first. It keeps its fill because
## it is not this cue; it now draws this cue as well, which is new and visible: a
## Sundew crowded by neighbours shows a wash eaten down to a sliver, and selecting it
## finally answers how far the patch actually reaches.
##
## **This must be CALLED from a subclass's own `_draw()`.** It cannot be left inside
## `Plant._draw()` and hoped for. `CornCobbler`, `Dandelion`, `StickySundew` and
## `ChompFlower` each fully override `_draw()` and never call `super` — the exact trap
## `SelectionMarker`'s header documents, and the reason the selection brackets had to
## be moved into a child node. A subclass whose only overlay is its reach should
## delete its `_draw()` outright and inherit the default below, rather than write an
## override that does nothing but call this; Mint, Nettle and Aloe each did.
##
## The selection gate lives here rather than in each caller, because "a reach is shown
## when you ask for it" belongs to the rule and not to any one plant. A ring that was
## always up would put a permanent circle under every plant on the board at once.
func draw_reach_ring() -> void:
	# suite-reach-check: ok - a draw_* call is only legal inside NOTIFICATION_DRAW and
	# headless never enters one, so calling this from a test either errors on the engine
	# side or exercises nothing. Its two decisions are split out where a test CAN hold
	# them: `draws_reach_ring()` is the gate (asserted by
	# test_a_reach_ring_appears_on_selection_and_not_before) and `reach_ring_radius()` /
	# `reach_ring_color()` are the geometry (asserted by
	# test_every_plant_with_a_reach_draws_a_ring_at_that_reach). That it is CALLED at all
	# is the source scan in test_every_plant_that_paints_more_than_its_reach_still_calls_the_ring.
	if not draws_reach_ring():
		return
	draw_arc(Vector2.ZERO, reach_ring_radius(), 0.0, TAU, REACH_RING_SEGMENTS,
		reach_ring_color(), REACH_RING_WIDTH, true)


## Would `draw_reach_ring()` paint anything if a draw pass ran right now?
##
## The gate, lifted out of the draw call so it is assertable at all. Headless runs no
## `_draw()`, so a condition left inline inside one is a decision no test can ever
## reach — and this particular decision is a real piece of design ("a reach is shown
## when you ask for it, or the board fills with permanent circles"), not a detail.
func draws_reach_ring() -> bool:
	return _selected and reach_ring_radius() > 0.0


## What a plant whose only overlay is its reach gets for free. Anything that paints
## more than this overrides `_draw()` and calls `draw_reach_ring()` itself — see that
## method for why it cannot be the other way round.
func _draw() -> void:
	draw_reach_ring()


## Game toggles this when the plant is clicked/deselected. Base class tracks the flag
## and repaints; the reach ring reads it through `draw_reach_ring()`, so a subclass
## that wants one overrides `reach_ring_radius()` rather than `_draw()`.
func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	if _selection_marker != null:
		_selection_marker.visible = value
		if value:
			# Grow-in only on the way in. Deselecting hides the marker outright,
			# matching Hud._play_panel_entrance's own selection box: the box that
			# just told the player what changed is not worth an animated exit,
			# and losing selection often means a plant just died under it.
			_selection_marker.play_entrance()
	queue_redraw()
