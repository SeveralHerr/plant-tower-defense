class_name Aloe
extends Plant

## The plant that repairs the garden, and the first thing in the game that makes damage
## impermanent.
##
## ## Why this role and not another
##
## Seven plants answer one of three questions: what happens to the pest in front of me
## (Corn, Chomp, Dandelion, Nettle), what happens to the seeds (Sunflower), or what the
## plants beside me are worth (Mint, and Sundew over the road). None of them answers what
## happens to a plant that has already been chewed.
##
## And until now the answer was "nothing, ever". `Plant.health` only goes down. The single
## exception is the rain heal, applied once per weather change to every plant at once
## (`Game._apply_weather`) — which is the weather's doing, not the player's, and arrives
## every fifth wave whether it is needed or not. So a Corn that survived wave 6 on four
## health entered wave 7 on four health, and a player's only repair was to uproot at a
## refund and pay full price again.
##
## That is what this plant sells: not survivability during a fight, but the fact that
## surviving one leaves you with something.
##
## ## Why it cannot save a plant under attack, deliberately
##
## `Pest.EAT_DPS` takes a full-health plant down in `MAX_HEALTH / EAT_DPS` seconds — the
## header on `Plant` puts it at 2.86s. `HEAL_PER_SECOND` below is 3.0 against that, so an
## Aloe adds about a fifth of a second to a plant being eaten and changes no outcome in a
## fight. That is the design, not a number waiting to be tuned up: a heal fast enough to
## out-pace a mouth would make the correct play "one Aloe behind everything" and delete the
## decision that the whole board is about. What it does instead is repair the survivors
## between waves, where nothing is racing it.
##
## Say that in the blurb, because a player who buys this expecting a shield has been
## mis-sold — see `PlantCatalog`'s entry, which names the between-waves case outright.
##
## ## Why THIS plant heals from its own `_act` and Mint does not buff from its own
##
## Mint's header is explicit that the neighbour buff is applied by `Game` rather than by the
## Mint, because a buff is a STATE: something has to un-apply it when the Mint is uprooted,
## and by then the Mint is gone and cannot run the frame that would.
##
## A heal is not a state, it is an EVENT that accumulates. Nothing has to be reverted when
## an Aloe is uprooted — the health it already gave is health the plant has, and the only
## consequence of the Aloe vanishing is that no more arrives. So the asymmetry between these
## two support plants is real rather than an inconsistency, and it is worth reading before
## anyone "tidies" one into the other's shape.
##
## What still lives in `Game` is the ITERATION, for the ordinary reason: `Game` owns
## `_plants`, and an Aloe reaching for the plant set itself would have to ask the tree —
## which returns a second `Game`'s plants when the suite hosts two scenes at once
## (`.claude/skills/godot-test-isolation`). The decision of WHO gets healed and by HOW MUCH
## is pure and static below, so it is assertable without a board.

## How far the rosette reaches, in pixels.
##
## 1.5 cells rather than Mint's 1.0, and the number is chosen so the drawn ring tells the
## truth. A diagonal neighbour is `Board.CELL * sqrt(2)` ≈ 90.5 px away; 1.5 cells is 96, so
## this ring genuinely contains all eight surrounding cells. Mint's header records refusing
## diagonals for exactly the opposite reason — at a one-cell ring they sit OUTSIDE the cue,
## and "a cue that does not contain what it affects is the defect cycle 85 shipped".
##
## So the two support plants differ in shape as well as in effect, and both cues are honest.
const REACH: float = Board.CELL * 1.5

## Health per second restored to each damaged plant in reach.
##
## Read against `Plant.MAX_HEALTH` (40) and `Pest.EAT_DPS`: this is a full repair in about
## thirteen seconds of quiet, and roughly a fifth of the rate a single pest removes it. The
## first number is the one that matters, because the second is deliberately a losing race —
## see the class header.
const HEAL_PER_SECOND: float = 3.0

const RING_COLOR := Color(0.90, 0.86, 0.72, 0.55)
const RING_WIDTH: float = 2.0

## The slow breathing scale, the same idea as Mint's and for the same reason: this plant
## never fires, so without it the only two plants on the board that do nothing would also be
## the only two that never move. Slower and shallower than Mint's, so two support plants
## side by side do not pulse in lockstep and read as one animation.
const PULSE_SECONDS: float = 3.4
const PULSE_SCALE: float = 0.03

var _pulse_time: float = 0.0


## How much health one Aloe restores in `delta` seconds. Pure, so the rate is assertable
## without a tree, a pest or a clock.
##
## Clamped at zero rather than trusting the caller: `_process` deltas are non-negative in
## practice, but a negative one here would turn a healer into a second mouth, and that is a
## bad enough failure to spend one `maxf` on.
static func heal_for(delta: float) -> float:
	return HEAL_PER_SECOND * maxf(0.0, delta)


## Does an Aloe at `from_cell` reach a plant at `to_cell`?
##
## Asked in CELLS and answered in pixels, because `REACH` is a drawn radius and the ring the
## player sees is the promise being kept. Comparing cell distance instead would let the cue
## and the effect disagree the moment either number moved.
##
## An Aloe does not heal itself: `from_cell == to_cell` is false here. Not a balance call —
## a self-healing Aloe is a plant that repairs the one thing on the board nothing was
## attacking, since a pest that reaches the Aloe has already walked past whatever the Aloe
## was planted to protect.
static func reaches(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if from_cell == to_cell:
		return false
	var step: Vector2 = Vector2(to_cell - from_cell) * Board.CELL
	return step.length() <= REACH


## Aloe engages nothing, so `_act` has no pests to consider. The healing is driven by
## `Game`, which owns the plant set — see the class header for why the ITERATION lives there
## while the decision lives here.
func _act(_delta: float, _pests: Array[Pest]) -> void:
	pass


func _process(delta: float) -> void:
	_pulse_time += delta
	if _sprite == null:
		return
	var swell: float = 1.0 + sin(_pulse_time * TAU / PULSE_SECONDS) * PULSE_SCALE
	_sprite.scale = Vector2.ONE * swell


## The grammar's REACH row (`game/OVERLAY_GRAMMAR.md`), used as-is rather than invented:
## "this is how far it acts" is exactly what a solid full ring means, and a second vocabulary
## for the same statement is how a grammar stops being one.
##
## Drawn only while selected, like every other reach in the game.
func _draw() -> void:
	if not _selected:
		return
	draw_arc(Vector2.ZERO, REACH, 0.0, TAU, 48, RING_COLOR, RING_WIDTH, true)
