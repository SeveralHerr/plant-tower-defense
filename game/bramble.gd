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

## What fraction of a bite actually lands. 0.25 means a Bramble takes four times as
## long to eat as anything else.
##
## Read against the two clocks that already exist. `Plant.MAX_HEALTH / Pest.EAT_DPS`
## puts an ordinary plant at 2.86s under one mouth; this makes a Bramble 11.4s. Against
## the `WaveDirector`'s pressure that is the useful band: one pest is held for most of a
## prep gap (`Game.PREP_SECONDS` is 18), and a pack of four eating it together is
## through in 2.9s — so a Bramble buys a lot against a trickle and little against a
## crush, which is the shape a wall should have. A wall that held a full wave would
## delete the lane rather than lengthen it.
const BITE_RESISTANCE: float = 0.25

## Seconds a Bramble holds `pest_count` pests, at full health and with nothing healing
## it. The class's entire balance claim as one pure function, so a test can assert the
## band above rather than quote it.
##
## Zero pests is `INF` rather than a division by zero, and that is the honest answer:
## nothing is eating it, so it stands forever.
static func hold_seconds(pest_count: int) -> float:
	if pest_count <= 0:
		return INF
	return MAX_HEALTH / (Pest.EAT_DPS * BITE_RESISTANCE * float(pest_count))


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
func bite_resistance() -> float:
	return BITE_RESISTANCE


## Nothing. See the class header: the pest owns the halt, not the wall.
func _act(_delta: float, _pests: Array[Pest]) -> void:
	pass
