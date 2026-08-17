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
const RING_COLOR := Color(1.0, 0.40, 0.0, 0.55)
const RING_WIDTH: float = 2.0

## The sting twitch: a fast squash on the sprite, the same shape `CornCobbler._recoil` plays
## and for the same reason. A sting has no projectile, so without this the ONLY board-level
## evidence that a Nettle did anything is the victim's own hit flash — and that flash looks
## identical to a kernel landing from a cob three cells away.
const STING_SQUASH := Vector2(1.16, 0.86)

var _cooldown: float = 0.0


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
## **No sound, and that is a gap rather than a decision.** `game/sfx.gd` has a cue for every
## other engagement in the game (`CORN_FIRED`, `CHOMP_BITE`, `SUNDEW_CLAIM`, `DANDELION_PUFF`,
## `SEED_BOMB_BURST`) and nothing that fits a sting; borrowing one of those would teach the
## player that a different plant had acted, which is worse than silence. Adding a cue means a
## new entry in `Sfx.SOUNDS`, `VOLUME_DB`, `PITCH` and `REPEAT_MS`, and that is its own item.
func _sting(target: Pest) -> void:
	target.take_damage(STING_DAMAGE)
	if target.is_alive():
		target.flash_hit()
	_cooldown = sting_interval()
	_sting_twitch()


## Gated the way every cosmetic Tween in this project is: headless pumps no frames, so a Tween
## queued here would never run, and `_sprite` is null only before `_build_visuals`.
func _sting_twitch() -> void:
	if _sprite == null or not is_inside_tree() or not GardenTheme.animations_enabled():
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", STING_SQUASH, 0.05)
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.10)


## Drawn only while selected, like every other reach in the game. No super._draw() call, and
## there must not be one — the selection brackets live in a `SelectionMarker` child precisely
## because an override here eats them. See that class's header.
func _draw() -> void:
	if not _selected:
		return
	draw_arc(Vector2.ZERO, RANGE, 0.0, TAU, 44, RING_COLOR, RING_WIDTH, true)
