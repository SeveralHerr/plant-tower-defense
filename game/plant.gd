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

## The in-world bar's two colours. Red is the bar that was always there; green is
## the only cue the player gets that regrowth is a thing the game does, so it is
## on the readout they are already looking at rather than on a new one.
const HEALTH_BAR_HURT := GardenTheme.DANGER
const HEALTH_BAR_REGROWING := Color(0.36, 0.70, 0.34)

signal destroyed(plant: Plant)

var kind: StringName = &""
var cell: Vector2i = Vector2i.ZERO
var board: Board = null
var health: float = MAX_HEALTH

var _sprite: Sprite2D
var _wobble_time: float = 0.0
var _selected: bool = false
var _health_back: ColorRect = null
var _health_bar: ColorRect = null
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


func _build_visuals() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load(PlantCatalog.texture_path(kind)) as Texture2D
	add_child(_sprite)

	_health_back = ColorRect.new()
	_health_back.color = Color(0.12, 0.12, 0.12, 0.65)
	_health_back.position = Vector2(-16, -34)
	_health_back.size = Vector2(32, 5)
	_health_back.visible = false
	add_child(_health_back)

	_health_bar = ColorRect.new()
	_health_bar.color = HEALTH_BAR_HURT
	_health_bar.position = Vector2(-16, -34)
	_health_bar.size = Vector2(32, 5)
	_health_bar.visible = false
	add_child(_health_bar)

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


func _on_setup() -> void:
	pass


## Regrowth runs here rather than in `_act()` on purpose: `_act` is the hook every
## subclass overrides, and not one of them chains to super, so a heal written
## there would exist on the base class and on nothing the player can actually
## plant. Same trap SelectionMarker's header describes for `_draw`.
func _physics_process(delta: float) -> void:
	_regrow(delta)
	_act(delta, _live_pests())


## One step of recovery. A destroyed plant never comes back — Game frees the node
## on `destroyed`, but the guard is here anyway so a plant that hits 0 in the same
## frame something else is iterating cannot be resurrected by the next tick.
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
func _refresh_health_bar() -> void:
	if _health_back == null or _health_bar == null:
		return
	var fraction: float = clampf(health / MAX_HEALTH, 0.0, 1.0)
	var whole: bool = fraction >= 1.0
	_health_back.visible = not whole
	_health_bar.visible = not whole
	_health_bar.size = Vector2(32.0 * fraction, 5)
	_health_bar.color = health_bar_color(is_regrowing())


## Pure: which colour the bar wears. Split out so the cue is assertable without a
## viewport — the bar is a ColorRect child, so nothing else about it is.
static func health_bar_color(regrowing: bool) -> Color:
	return HEALTH_BAR_REGROWING if regrowing else HEALTH_BAR_HURT


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
	queue_redraw()
