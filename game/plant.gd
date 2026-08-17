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

var _sprite: Sprite2D
var _wobble_time: float = 0.0
## Idle sway, the same shape TitleScreen's decorative lawn already uses
## (TitleScreen.SWAY_RADIANS / SWAY_RATE): a small continuous rock rather than
## a one-shot event tween like play_exit_and_free()'s pop. Kept subtle on
## purpose — this runs on every placed plant, every frame, for the whole run.
const WOBBLE_RADIANS: float = 0.055
const WOBBLE_RATE: float = 1.15
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
	_sprite = Sprite2D.new()
	_sprite.texture = load(PlantCatalog.texture_path(kind)) as Texture2D
	add_child(_sprite)

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
	_selection_marker.visible = false
	add_child(_selection_marker)

	# Planting pop: the sprites are centred on their own vertical axis, which is
	# what makes a scale tween land without drifting off the cell.
	if not is_inside_tree():
		return
	_sprite.scale = Vector2(0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2(1.12, 1.12), 0.12)
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.10)


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
## it. Callers (Game._on_plant_destroyed, Game.uproot_selected) have already
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
	tween.tween_property(_sprite, "scale", Vector2.ZERO, 0.18)
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
	if _sprite == null or not GardenTheme.animations_enabled():
		return
	_sprite.rotation = sin(_wobble_time * WOBBLE_RATE + _wobble_phase(cell)) * WOBBLE_RADIANS


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
func _furthest_along_in_range(pests: Array[Pest], radius: float) -> Pest:
	var best: Pest = null
	var best_progress: float = -1.0
	for pest: Pest in pests:
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


## Game toggles this when the plant is clicked/deselected. Base class just
## tracks the flag and repaints; subclasses that draw a selection overlay
## (e.g. a range ring) override `_draw()` and read `_selected`.
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
