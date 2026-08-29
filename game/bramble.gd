class_name Bramble
extends Plant

## The plant that stands IN the road, and the first thing in the game a pest has to
## deal with rather than walk past.
##
## ## Why this role and not another
##
## Eight plants answer one of four questions: what happens to the pest in front of me
## (Corn, Chomp, Dandelion, Nettle), what happens to the seeds (Sunflower), what the
## plants beside me are worth (Mint), or what happens to a plant that was already
## chewed (Aloe). Every one of them acts on a pest that is WALKING PAST, and the pest
## walks past regardless — `Pest._physics_process` stops for exactly two things, a
## Chomp's mouth (`held_by`) and, for the `is_hungry` mutation only, a plant it has
## decided to eat. Nothing else in the garden has ever changed how long a wave takes
## to cross the board.
##
## That is what this plant sells: TIME. It does no damage at all and it never will —
## what it does is make the cobs behind it get more shots off at the same wave.
##
## ## Why it is a resistance and not a bigger health pool
##
## `Plant.MAX_HEALTH` is a const, shared by every plant, and read in nine places
## including the HUD's `Health %d/%d` line and `Game`'s rain heal. A blocker wants to
## survive longer than 40 health at `Pest.EAT_DPS`, and there were two ways to get it:
## make the pool per-plant, or take less damage from each bite.
##
## Resistance was chosen for a design reason rather than for being the smaller diff.
## The two are identical against a lone pest — both buy `effective_health / EAT_DPS`
## seconds — and they differ in exactly one place: what a point of HEALING is worth.
## A heal of 1 health buys `1 / EAT_DPS` seconds on a big pool and
## `1 / (EAT_DPS * BITE_RESISTANCE)` seconds here, i.e. four times as much. So the
## Salve Aloe, standing on the grass one cell off the road, is worth four times more
## behind a Bramble than behind anything else, and "Aloe behind the wall" becomes a
## real board rather than a coincidence. A bigger pool would have made the Aloe
## proportionally WORSE, which is the opposite of the interaction worth having.
##
## The honest cost of the choice, stated rather than hidden: the health bar and the
## HUD's `Health 40/40` are still counting real health, so a Bramble reads as a
## normal-sized plant that is chewed slowly. That is the correct reading — it IS a
## normal-sized plant that is chewed slowly.
##
## ## Why a winged pest ignores it
##
## `ChompFlower` refuses a winged pest twice (`_can_grab`, `_act`) and the Sundew
## exists because of it. A wall that stopped fliers would be the first thing in the
## game with no counter at all, and the mutation that already means "goes over the
## garden" is the obvious one to honour. So wave 8 onward, a lane held by Brambles
## alone starts leaking, and the answer is the same as it has always been: something
## that shoots.
##
## ## Why the pest owns the stopping and not this class
##
## `_act()` here is empty on purpose. Halting is a decision about the PEST's own
## movement — it happens between `_tick_aura` and `_advance` inside
## `Pest._physics_process`, in the same block as the hungry mutation's meal, because
## that is the one place in the codebase where "does this creature move this frame"
## is decided. A Bramble reaching out to freeze pests would be a second answer to
## that question living in a different file, and the two would drift.
##
## This class owns the two NUMBERS the rule reads (`STOP_RADIUS`, `BITE_RESISTANCE`)
## and the one predicate it asks (`stops`), so the balance is assertable with no
## board, no pest and no tree.

## How close a pest gets before it is held.
##
## Measured against the road rather than picked: `Board.route()` is one waypoint per
## road cell centre, so a pest walking toward a Bramble's cell is exactly `Board.CELL`
## away when it stands on the cell before it. 0.6 of a cell (38.4 px) therefore holds
## the pest a little inside its own approach — visibly stopped at the thicket rather
## than standing on top of it — while being comfortably under a full cell, so a pest
## on the NEXT cell along is never held by a Bramble it has already passed.
##
## Deliberately NOT `Pest.EAT_RADIUS` (`Board.CELL * 1.15`), which is sized for the
## opposite geometry: a hungry pest on the road reaching a plant one cell OFF it.
## A Bramble is on the road, so it needs less than one cell, not more.
const STOP_RADIUS: float = Board.CELL * 0.6

## The ladder (plant-tower-defense-4u74), and every rung buys RESISTANCE rather than health.
##
## WHY THAT AXIS AND NOT A BIGGER POOL. It is the same argument the class header makes for
## choosing resistance in the first place, applied one level up. A heal is worth
## `1 / (EAT_DPS * bite_resistance())` seconds, so lowering the resistance scales the Salve
## Aloe standing behind the wall — and the rain — WITH the upgrade. A bigger health pool
## would dilute both: the same 3 HP/s would buy proportionally less of a longer wall, and the
## board that this plant makes interesting would get worse as you invested in it.
##
## THE PRICE IS THE POINT, and it is why this plant wanted a ladder more than any other. Six
## of the nine plants cannot absorb a seed after they are placed
## (test_the_seed_sink_is_finite_while_the_seed_income_is_not), and a Bramble is the only one
## that is a RECURRING cost — it is consumed by doing its job. So "spend more on this one so
## you replace it less often" is a decision the economy did not previously offer anywhere.
##
## TWO RUNGS ABOVE THE BASE, priced against the cob's ladder rather than invented: the cob
## climbs 25 then 45 from a 10-seed plant. A Bramble starts at 20 and climbs 30 then 55 —
## dearer per rung because each one buys a multiplier on everything healing it, and because
## the wall is replaced often enough that a cheap ladder would just be a discount.
##
## `hold_seconds` reads the ladder, so the panel's "Holds Ns" moves with the rung and no
## second number has to be kept in step.
## THE RUNG NAMES ARE BUDGETED, which is not obvious and cost a failing suite to find. The
## panel's first line is `"%s — %s" % [display, level_name]` and `selection_corpus` crosses
## every plant name with every rung, so the longest pair sets the height of the whole
## selection stack. "Barrier Bramble — deep thicket" is 30 characters against the previous
## worst of 25 ("Chomp Flower — gaping maw"), and it pushed `hud_selection_panel` 25 px
## through its floor — which the budget check reported with the three ways out, one of which
## was "shorten the plant name".
##
## So the top rung is "bulwark", not "deep thicket": 25 characters, exactly the existing
## worst case, so this ladder spends none of that budget. It also reads as the strongest of
## the three, which "deep thicket" did not — bramble, thicket, bulwark climbs.
const LEVELS: Array[Dictionary] = [
	{"name": "bramble", "resistance": 0.25, "upgrade_cost": 30},
	{"name": "thicket", "resistance": 0.18, "upgrade_cost": 55},
	{"name": "bulwark", "resistance": 0.12, "upgrade_cost": 0},
]


## What fraction of a bite actually lands at the BASE rung. Kept as a const because the
## catalogue, the header above and `LEVELS[0]` all have to agree about where the ladder
## starts, and `test_the_brambles_ladder_starts_where_its_constant_says` pins that they do.
## 0.25 means a Bramble takes four times as long to eat as anything else.
##
## Read against the two clocks that already exist. `Plant.MAX_HEALTH / Pest.EAT_DPS`
## puts an ordinary plant at 2.86s under one mouth; this makes a Bramble 11.4s. Against
## the `WaveDirector`'s pressure that is the useful band: one pest is held for most of a
## prep gap (`Game.PREP_SECONDS` is 18, and it is the STANDARD profile's 18 since cycle
## 155), and a pack of four eating it together is through in 2.9s — so a Bramble buys a
## lot against a trickle and little against a crush, which is the shape a wall should
## have. On `harsh`, whose gap is nine seconds, 11.4s is longer than the whole gap and
## the reading flips: one pest is held for MORE than a prep window. That is a shift in
## what the wall means rather than a defect, and it is recorded here because the number
## above is now a comparison against one profile out of three. A wall that held a full wave would
## delete the lane rather than lengthen it.
const BITE_RESISTANCE: float = 0.25

## Seconds a Bramble holds `pest_count` pests, at full health and with nothing healing
## it. The class's entire balance claim as one pure function, so a test can assert the
## band above rather than quote it.
##
## Zero pests is `INF` rather than a division by zero, and that is the honest answer:
## nothing is eating it, so it stands forever.
static func hold_seconds(pest_count: int, for_level: int = 1) -> float:
	if pest_count <= 0:
		return INF
	return MAX_HEALTH / (Pest.EAT_DPS * resistance_at(for_level) * float(pest_count))


## The resistance a wall on `for_level` takes a bite at. Clamped at both ends, like
## `Dandelion.texture_for_fluff`, so a caller reasoning about a hypothetical rung still gets
## a number and the real caller can never be out of range.
##
## Levels are 1-based (`Plant.level` starts at 1), which is why the index is `for_level - 1`
## and not `for_level` — the same off-by-one `Plant.ladder_row` handles for every other
## ladder, and the reason this is a named function rather than an inline lookup.
static func resistance_at(for_level: int) -> float:
	var row: Dictionary = LEVELS[clampi(for_level - 1, 0, LEVELS.size() - 1)]
	return float(row["resistance"])


## Does a Bramble hold a pest with these mutations? The whole rule, and the only
## place it is written.
##
## Takes the flag rather than a `Pest`, for the same reason `Nettle.can_sting` does:
## the rule is assertable without spawning anything, and `Pest._blocking_plant` reads
## it rather than re-deciding it.
static func stops(pest_is_winged: bool) -> bool:
	return not pest_is_winged


## A bite, scaled. The one override, and the whole of the resistance.
##
## `amount` is scaled BEFORE `super`, so everything downstream — the health bar, the
## flinch, the quiet clock that gates regrowth, the `destroyed` signal — sees the
## damage that actually landed. A zero-damage call stays zero and therefore still does
## not reset the regrowth clock, which is the rule `Plant.take_damage` states.
func take_damage(amount: float) -> void:
	super.take_damage(amount * bite_resistance())


## The declaration the HUD and `Plant.seconds_of_chewing_left` read. `take_damage` above
## reads it too rather than reaching for `BITE_RESISTANCE` directly, so a readout saying
## "holds 11 seconds" and the mouth actually eating it cannot come apart.
## A Thorn Bramble — the sport, `PlantMutation` — takes the rung's resistance down
## further, and it is scaled HERE rather than in `take_damage` for the reason the
## paragraph above gives: this is the one number both the mouth and the readout read,
## so a sport that holds longer is a sport the panel says holds longer, with nothing
## remembered at a second site.
func bite_resistance() -> float:
	return resistance_at(level) * sport_rate_scale()


## How long it holds under one mouth, before and after (plant-tower-defense-jvnm).
##
## SECONDS, because that is the currency `Hud.resisting_detail` already prints for this
## plant — "a Bramble is never busy and never idle: it is a wall, and the only question
## about it is how long it lasts". A resistance of 0.25 -> 0.18 is the honest number and
## it is meaningless to a player; the same fact as 11.4 -> 15.9 seconds is not.
##
## From FULL health rather than from the health it has now, and the distinction matters:
## the detail line answers "how long does THIS bramble have left", which falls as it is
## eaten. A rung is bought for what it will be worth on the next wall too, so the gain is
## quoted against a fresh one. One mouth, at `Pest.EAT_DPS`, matching the detail line's
## own assumption.
func upgrade_gain() -> String:
	if is_max_level():
		return ""
	var now: float = resistance_at(level)
	var next: float = resistance_at(level + 1)
	if now <= 0.0 or next <= 0.0:
		return ""
	# NO VERB, and the same number->number->unit shape the cob's gain uses. "holds
	# 11.4→15.9s" was the first phrasing and it measured 252px in a 232px box --
	# `test_every_upgrade_button_face_fits_the_panel` refused it before a player saw it.
	# The word was the widest thing in the phrase and the least informative: the button
	# already says Upgrade, and the unit says the rest.
	return "%.1f→%.1fs" % [
		MAX_HEALTH / (Pest.EAT_DPS * now), MAX_HEALTH / (Pest.EAT_DPS * next)]


## The ladder, for `Plant`'s upgrade machinery. Same shape the cob and the Chomp return.
func upgrade_ladder() -> Array[Dictionary]:
	return LEVELS


## Nothing. See the class header: the pest owns the halt, not the wall.
func _act(_delta: float, _pests: Array[Pest]) -> void:
	pass


# ---------------------------------------------------------------------- visuals

## The three frames, whole first. Indexed by `texture_for_health` directly, so the picture
## cannot disagree with the count — the same arrangement `Dandelion.FLUFF_TEXTURES` uses,
## and adding a fourth frame means adding a threshold below rather than editing a branch.
##
## WHY THIS PLANT AND NOT THE OTHER EIGHT. Nothing in this game changed a plant's picture as
## it took damage before this: every `_sprite.texture` assignment under `game/` was a state
## machine (`ChompFlower`'s idle → gape → eating → late-bite, driven by `chew_progress()`)
## or an ammo count (`Dandelion`'s fluff frames). Neither reads `health`. On eight plants
## that is right — they are damaged incidentally, and the 32x5 px health bar is a detail the
## player consults. A Barrier Bramble is damaged AS ITS FUNCTION: the player is watching
## this specific plant to judge whether it will hold, and the whole answer was a bar.
const DAMAGE_TEXTURES: Array[String] = [
	"res://assets/sprites/bramble.png",
	"res://assets/sprites/bramble_chewed.png",
	"res://assets/sprites/bramble_ragged.png",
]

## Where the picture changes, as fractions of full health.
##
## Thirds, and derived rather than picked: the panel already prints "Holds Ns"
## (`Hud.resisting_detail`) and that number is linear in health, so a frame boundary at 2/3
## and 1/3 of health is also 2/3 and 1/3 of the seconds it is advertising. The picture and
## the readout therefore change together, which is the one thing that stops them being two
## sources of truth about the same question.
##
## One fewer threshold than frames, and `texture_for_health` clamps, so the two arrays
## cannot disagree about how many states there are.
const DAMAGE_THRESHOLDS: Array[float] = [2.0 / 3.0, 1.0 / 3.0]

## Pure: the frame a wall at `fraction` of full health wears.
##
## Takes the fraction rather than the plant so the balance is assertable with no node, no
## board and no tree — same reason `Bramble.stops` takes a bool. Clamped at both ends: a
## caller reasoning about a hypothetical still gets a picture, and a plant healed above full
## by a rounding error still gets the whole one.
static func texture_for_health(fraction: float) -> String:
	var index: int = 0
	for cut: float in DAMAGE_THRESHOLDS:
		if fraction < cut:
			index += 1
	return DAMAGE_TEXTURES[clampi(index, 0, DAMAGE_TEXTURES.size() - 1)]


var _frames: Dictionary = {}


## Both directions, and that is why this hangs off `_refresh_health_bar` rather than off
## `take_damage`. Health goes UP as well as down — `Plant.heal` (the Salve Aloe, the rain)
## and `Plant._regrow` both call this — and a wall that showed damage it no longer had would
## be exactly the readout this plant was given a picture to avoid. `_refresh_health_bar` is
## the one function every path that moves `health` already goes through.
func _refresh_health_bar() -> void:
	super._refresh_health_bar()
	_refresh_damage_sprite()


func _refresh_damage_sprite() -> void:
	if _sprite == null:
		return
	var path: String = texture_for_health(health / MAX_HEALTH)
	if not _frames.has(path):
		_frames[path] = load(path) as Texture2D
	var texture: Texture2D = _frames[path] as Texture2D
	if texture != null:
		_sprite.texture = texture
