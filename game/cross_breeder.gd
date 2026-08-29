class_name CrossBreeder
extends RefCounted

## Two plants of a kind standing side by side sometimes throw a sport into an empty
## cell beside them. This is the whole rule, as pure functions over a cell -> plant
## Dictionary, a `Board` and an RNG — `Game` owns the clock and the planting, and
## owns nothing else about it.
##
## ---------------------------------------------------------------------------
## WHY IT IS A CLASS AND NOT TWENTY LINES INSIDE `Game._process`
##
## Every interesting thing here is a decision with an edge: which pairs count, which
## cells are open, what happens when a pair has no open cell, whether a sport can
## itself be a parent. Inside `_process` all six of those are unreachable to the
## suite — `Game` needs a tree, a HUD, a bank and a wave director to exist at all,
## and the roll would only ever be observed through "did a plant appear". Out here
## every one of them is a function call with no frame behind it. See
## `.claude/skills/extract-a-testable-seam`.
##
## ---------------------------------------------------------------------------
## THE FOUR RULES, and what each is protecting against
##
##   1. **ORTHOGONAL NEIGHBOURS ONLY.** The pair must share an edge, and the sport
##      lands on a cell sharing an edge with one of them. Diagonals are excluded
##      for the reason `Mint.NEIGHBOUR_OFFSETS` excludes them: this board already
##      has one adjacency rule and a second, wider one would mean "next to" means
##      two different things depending on which plant is asking.
##   2. **SAME KIND.** The bead says "a new mutated version of IT", and "it" has to
##      be a single plant kind for the sentence to have a referent. Two different
##      plants crossing would also need a rule for which of them the child is, and
##      there is no answer to that which is not arbitrary.
##   3. **A SPORT IS NEVER A PARENT.** This is the bound on the whole mechanic. Two
##      sports throwing a third is a population that grows with itself, and a garden
##      that fills itself with free plants has stopped being a garden the player is
##      building. With this rule the sports are bounded by what the player PLANTED:
##      every child needs two bought parents, and it never becomes one.
##   4. **ONE ROLL PER TICK, NOT ONE PER PAIR.** A garden with twenty eligible pairs
##      would otherwise mutate twenty times as fast as one with a single pair, which
##      turns "plant lots of the same thing" into the dominant strategy and makes
##      late waves rain free plants. The tick rolls once; only if it succeeds does it
##      pick a pair, uniformly. So the RATE is flat and only the RECIPIENT is random,
##      which is the shape a rare event should have.
##
## ---------------------------------------------------------------------------
## WHAT THIS DELIBERATELY DOES NOT DO. It does not charge seeds, it does not check
## whether the kind is unlocked, and it does not care whether the player could have
## afforded one. A sport is not a purchase — it is the garden doing something on its
## own, which is the only reason the mechanic is interesting. `Game._sprout_sport`
## is correspondingly the one planting path in the game that never touches `SeedBank`.

## How often the garden is asked. Six seconds is a little under a Sunflower's
## payout interval (`Sunflower.INTERVAL`, 6.0), which is the only other thing on
## this board that happens on a clock of its own — so the two garden-side events
## tick at about the same human rhythm rather than at two unrelated ones.
const TICK_SECONDS: float = 6.0

## The chance ONE tick produces a sport, given at least one eligible pair.
##
## Priced against a run, not picked: at 0.025 a tick of 6.0 s, a garden holding a
## pair throws a sport about every 240 seconds. A full campaign is a bit over ten
## minutes of live play, and a garden does not hold a matching pair for all of it,
## so a player who plants doubles sees two or three sports in a campaign and a
## player who plants one of everything sees none. That gap is the mechanic: it pays
## for a decision the player was already making (breadth against depth) rather than
## adding one.
##
## This was 0.04 — a sport every 150 s, four or five of them a campaign — and it was
## paired with buffs deliberately kept small. Rate and size are ONE decision made in
## two files, and both halves moved together: a sport now arrives about two thirds as
## often and is worth roughly half again as much when it lands (`PlantMutation`, the
## band under "HOW BIG THE NUMBER IS"). Four small gifts are background income the
## player stops reading; two large ones are news, and news is the only thing a
## mechanic nobody can buy has to sell.
##
## `test_a_sport_is_rare_enough_to_stay_an_event` pins both ends of that in seconds
## rather than in ticks, so retuning either constant fails against the sentence
## above instead of quietly moving it.
const CHANCE_PER_TICK: float = 0.025

## The four cells sharing an edge with a cell. Not `Mint.NEIGHBOUR_OFFSETS` reached
## across, deliberately: that constant is Mint's statement about its own buff and
## this one is the breeding rule's, and the day one of them wants diagonals it must
## be able to change without moving the other.
const ADJACENT: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]


## cell -> kind, for every plant that may be a PARENT right now.
##
## The one function here that touches `Plant` at all; everything below it works on
## the Dictionary this returns. That split is why the rules above are assertable
## without instantiating a single node.
##
## Refuses a destroyed plant, a freed one, and — rule 3 — a sport.
static func eligible_kinds(plants: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in plants:
		var cell := key as Vector2i
		var plant := plants[key] as Plant
		if plant == null or not is_instance_valid(plant):
			continue
		if plant.is_destroyed() or plant.is_sport:
			continue
		out[cell] = plant.kind
	return out


## Every unordered pair of same-kind plants sharing an edge, as `[a, b]` with `a`
## the smaller cell in reading order.
##
## Canonical order and not "whatever the Dictionary iterated": a pair listed twice
## would be drawn twice as often by `roll` below, so the same two cobs would breed
## at double the rate of every other pair for no reason a player could see.
static func pairs(kinds: Dictionary) -> Array:
	var out: Array = []
	for key: Variant in kinds:
		var cell := key as Vector2i
		for step: Vector2i in ADJACENT:
			var other: Vector2i = cell + step
			if not kinds.has(other):
				continue
			if kinds[other] != kinds[cell]:
				continue
			# Each edge is seen twice, once from each end. Keeping only the pass
			# that walks it in reading order emits it exactly once.
			if not _precedes(cell, other):
				continue
			out.append([cell, other])
	return out


## Reading order over cells: rows first, then columns within a row.
static func _precedes(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


## The cells a pair could throw a sport into: adjacent to either parent, inside the
## board, legal for that kind, and empty.
##
## `board.is_buildable_for` and not `is_buildable`, so a Barrier Bramble's sport
## lands on the road where a Bramble belongs and every other kind's lands on grass.
## That is the one place this rule would have silently produced an unplaceable plant
## — see `PlantCatalog.on_road`.
##
## Deduplicated, and the two parents' own cells are excluded by the occupancy check
## rather than by a special case: they are in `occupied` because they are plants.
static func open_cells(pair: Array, occupied: Dictionary, kind: StringName,
		board: Board) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if board == null or pair.size() != 2:
		return out
	var seen: Dictionary = {}
	for parent: Vector2i in pair:
		for step: Vector2i in ADJACENT:
			var cell: Vector2i = parent + step
			if seen.has(cell):
				continue
			seen[cell] = true
			if occupied.has(cell):
				continue
			if not board.is_buildable_for(cell, kind):
				continue
			out.append(cell)
	return out


## Every pair that has somewhere to put a child, as
## `[{"pair": [a, b], "kind": k, "cells": [...]}, ...]`.
##
## A pair boxed in by its own neighbours is dropped HERE rather than after the roll,
## and that is a real decision: rolling first and then discovering there is nowhere
## to put the sport would silently spend the tick, so a densely planted garden would
## mutate more and more rarely with no cause the player could observe. Dropping the
## boxed-in pair first means the chance in `CHANCE_PER_TICK` is the chance of a
## sport, not the chance of an attempt.
static func candidates(plants: Dictionary, board: Board) -> Array:
	var out: Array = []
	var kinds: Dictionary = eligible_kinds(plants)
	for pair: Array in pairs(kinds):
		var kind: StringName = kinds[pair[0]]
		var cells: Array[Vector2i] = open_cells(pair, plants, kind, board)
		if cells.is_empty():
			continue
		out.append({"pair": pair, "kind": kind, "cells": cells})
	return out


## One tick of the mechanic: `{}` for nothing happened, or
## `{"kind": k, "cell": c, "parents": [a, b]}` for a sport to plant.
##
## The RNG is passed in rather than owned, for the reason `WaveDirector.set_seed`
## exists: a run has to be reproducible, and a mechanic holding a private generator
## is a mechanic no seed can pin.
##
## Two draws, in this order and never one: the chance first, then the recipient.
## Drawing a pair before knowing whether anything will happen would consume a random
## number on every quiet tick, so an identical seed would produce different gardens
## depending on how many plants happened to be standing when the clock ticked.
static func roll(plants: Dictionary, board: Board, rng: RandomNumberGenerator,
		chance: float = CHANCE_PER_TICK) -> Dictionary:
	if rng == null:
		return {}
	var options: Array = candidates(plants, board)
	if options.is_empty():
		return {}
	if rng.randf() >= chance:
		return {}
	var choice: Dictionary = options[rng.randi_range(0, options.size() - 1)]
	var cells: Array = choice["cells"]
	return {
		"kind": choice["kind"],
		"cell": cells[rng.randi_range(0, cells.size() - 1)],
		"parents": choice["pair"],
	}


## How long, on average, a garden holding one breedable pair waits for a sport.
##
## Stated as a function rather than as a sentence in a comment because it is the
## number the tuning is actually about, and a comment quoting it goes stale the
## moment either constant moves — which is exactly what happened to three paragraphs
## in `WaveDirector` (see plant-tower-defense-8v43).
static func mean_seconds_between(chance: float = CHANCE_PER_TICK) -> float:
	if chance <= 0.0:
		return INF
	return TICK_SECONDS / chance
