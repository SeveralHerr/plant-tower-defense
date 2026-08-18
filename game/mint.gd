class_name Mint
extends Plant

## The plant that makes the plants beside it better, and does nothing on its own.
##
## Every other plant in the catalogue answers "what happens to the pest in front of me".
## Corn shoots it, Chomp eats it, Sundew slows it, Dandelion blasts a group of them,
## Sunflower ignores them and grows money. Mint is the first that answers a question about
## the BOARD instead: where you put it changes what your other plants are worth.
##
## That is the role `-ibvb` asked for — "a role the five do not cover" — and it is the one
## that makes placement geometry a decision. Until now a plant's cell mattered only for
## reach and for which lane it covered; two Corns were two Corns wherever they sat.
##
## **It speeds up firing, not everything.** Corn's shot interval and Dandelion's bomb
## interval both read `Plant.composed_interval`; a Chomp's chew does not, because a chew is
## a hold rather than a rate and halving it would quietly halve the Chomp's whole reason to
## exist (it occupies the mouth on purpose — see `chomp_flower.gd`'s header). The blurb says
## "shooting" for that reason and not as a simplification.

## Orthogonally adjacent only — no diagonals. One cell in each of the four directions, which
## is what "reach = one cell" means on a square grid and what `REACH` below draws.
##
## Diagonals were the other option and are refused: a diagonal neighbour is 90 px away
## against 64, so a ring drawn at one cell would not contain it, and a cue that does not
## contain what it affects is the defect cycle 85 shipped. Four neighbours also makes the
## interesting placement — a Mint between two Corns — legible at a glance.
const NEIGHBOUR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

## What one Mint multiplies a neighbour's firing interval by. Below 1.0 because an interval
## is the reciprocal of a rate: 0.75 is a third again as many shots, not a quarter fewer.
##
## 0.75 rather than 0.5, and the number is the balance: a Mint costs 25 against a Corn's 10,
## so two Corns and a Mint (45) must not beat four Corns (40) outright. At 0.75 they do not —
## three Corns' worth of fire from two, for more seeds and a cell that shoots nothing.
const NEIGHBOUR_SCALE: float = 0.75

## Drawn reach, matching `Board.CELL` so the ring contains exactly the cells it affects.
const REACH: float = Board.CELL

## The mint's hue for the shared reach ring. The alpha is deliberately NOT written
## here — `Plant.REACH_RING_ALPHA` is the grammar's, and a second copy of it is how one
## plant's ring ends up brighter than the rest. The width used to live beside it as a
## `RING_WIDTH` of 2.0 and is now `Plant.REACH_RING_WIDTH`, which was already the same
## 2.0 in all five plants that drew this ring.
const RING_COLOR := Color(0.54, 0.77, 0.72, Plant.REACH_RING_ALPHA)
const LEAF_PULSE_SECONDS: float = 2.6
const LEAF_PULSE_SCALE: float = 0.04

var _pulse_time: float = 0.0


## The multiplier a plant with `mints` adjacent Mints should carry.
##
## Static and pure, so "two Mints stack" is a question a test answers in one line instead of
## by building a board. `pow` rather than a table because the answer for three is a real
## question a player can ask and an unbounded one — and because the shape (each Mint
## multiplies) is the thing worth stating, not five hardcoded rows.
##
## Note it is deliberately NOT clamped. Four Mints around one Corn is 0.32, which is a silly
## board that costs 100 seeds to build and gives up four shooting cells to speed one up; the
## game does not need to forbid it, and forbidding it would be a rule the player cannot see.
static func scale_for(mints: int) -> float:
	return pow(NEIGHBOUR_SCALE, maxi(0, mints))


## Every cell this Mint reaches. Pure given a cell, so `Game` can ask without a Mint existing
## and a test can check the shape without a board.
static func neighbours_of(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for offset: Vector2i in NEIGHBOUR_OFFSETS:
		out.append(cell + offset)
	return out


## Mint engages nothing, so `_act` has no pests to consider. The buff is applied by `Game`
## whenever the plant set changes rather than from here, and that is deliberate: a buff
## applied per-frame by the buffer cannot be UNapplied when the buffer is uprooted, because
## by then there is nothing left to run the frame. Ownership sits with whoever owns the set.
func _act(_delta: float, _pests: Array[Pest]) -> void:
	pass


## The idle sway is `Plant._wobble`'s, shared with every plant. This adds a slow breathing
## scale on top, small enough to read as "alive" rather than as an event — a Mint never fires,
## so without it the only plant on the board that does nothing would also be the only one that
## never moves for its own reasons.
func _process(delta: float) -> void:
	_pulse_time += delta
	if _sprite == null:
		return
	var swell: float = 1.0 + sin(_pulse_time * TAU / LEAF_PULSE_SECONDS) * LEAF_PULSE_SCALE
	_sprite.scale = Vector2.ONE * swell


## A solid full ring at one cell — the grammar's REACH row (`game/OVERLAY_GRAMMAR.md`), used
## as-is rather than inventing a shape. A Mint's reach is not a weapon's, but "this is how far
## it acts" is exactly what the row means and a second vocabulary for the same statement is
## how a grammar stops being one.
##
## There is no `_draw()` here any more, and its absence is the point: this plant paints
## nothing except its reach, so it inherits `Plant._draw()` and answers the two questions
## below instead. Drawn only while selected — that gate lives in `Plant.draw_reach_ring()`
## now, with the reason a ring is not always up.
func reach_ring_radius() -> float:
	return REACH


func reach_ring_color() -> Color:
	return RING_COLOR
