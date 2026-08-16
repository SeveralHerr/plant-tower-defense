class_name WaveDirector
extends Node

## The wave table. Aphids come in swarms and beetles come in ones and twos, so a
## wave is a list of groups rather than a flat count — a run of eight aphids
## followed by a beetle reads very differently from the two interleaved.

signal spawn_requested(species: StringName, mutation: StringName)
signal wave_started(number: int)
signal wave_spawning_finished(number: int)

## Wave 8 is where the fixed table gets its first beetle-heavy mix (see WAVES
## below) — the doc's mutations layer onto that rather than starting cold.
const MUTATION_START_WAVE: int = 8
const MUTATION_CHANCE: float = 0.4
const MUTATIONS: Array[StringName] = [Pest.MUTATION_ARMOURED, Pest.MUTATION_WINGED, Pest.MUTATION_HUNGRY]

## Past the fixed table, _endless_groups already turns up count/gap every
## wave — but MUTATION_CHANCE held flat forever, so wave 40 looked exactly as
## "weird" as wave 8 even though everything else about it had escalated.
## Climbing this too keeps a long endless run from going numb.
const MUTATION_CHANCE_ENDLESS_STEP: float = 0.02
const MUTATION_CHANCE_MAX: float = 0.85

## Count, gap and mutation chance all climb past the fixed table, but the pest
## itself did not: a wave-60 aphid had the same 3 HP and 78 px/s as a wave-9
## one, so the entire late game was a quantity problem and a board that could
## clear wave 20 could clear wave 200 unattended. These scale the pest, so a
## long run eventually demands upgrades rather than only more of them.
##
## Health is the main lever and speed the minor one, deliberately: health makes
## a lane take longer to clear, which the player answers with damage, while
## speed shortens the window a lane has to work in at all and turns punishing
## fast. Hence a 3x health ceiling against a 1.6x speed one — at the cap an
## aphid crosses a 64px cell in half a second, which a placed Corn Cobbler can
## still act inside.
##
## Both of these stop, and so does everything else that scales a pest — which is
## what SIMULTANEOUS_PEST_CEILING below is about.
const ENDLESS_HEALTH_STEP: float = 0.06
const ENDLESS_HEALTH_MAX: float = 3.0
const ENDLESS_SPEED_STEP: float = 0.015
const ENDLESS_SPEED_MAX: float = 1.6

## --- The road is a fixed-size pipe -----------------------------------------
##
## Every endless scale stops except one. Measured off the constants above: the
## aphid spawn gap floors at wave 22, the beetle gap at 28, mutation chance at
## 31, health at 42 and speed at 48. From wave 49 the only thing still moving
## was the headcount — and nothing capped it. 166 pests at wave 48, 376 at
## wave 108, 1748 at wave 500.
##
## Against the real road (Board.PATH_CORNERS is 31 cells plus the off-board
## entry and exit, so 2112 px) and the capped speeds, an aphid crosses in
## 16.9 s and a beetle in 34.7 s. A group spaced `gap` apart therefore has
## `crossing / gap` of itself walking at once, and at the 0.16 s floor that is
## 106 aphids. Sweeping the real schedule, the peak is 115 pests alive at once
## by wave 40 and it never comes down again — on a 14x9 board with a 32-cell
## road, i.e. three and a half pests per cell of road. That is the quantity
## problem the ENDLESS_HEALTH_STEP block above says these scales exist to
## avoid, arrived at from the other direction.
##
## So the road gets a budget. No wave paces more than this many pests onto it,
## at any wave number, forever. What grows instead is the mix — see
## _endless_groups.
const SIMULTANEOUS_PEST_CEILING: int = 40

## How that ceiling is split between the wave's two groups. They sum to it
## exactly, which is what makes the bound hold by construction rather than by
## tuning: each group is paced so that it alone never has more than its share
## walking, so the wave can never have more than their sum.
##
## The swarm keeps the size the last wave of the fixed table gave it, so
## nothing visibly shrinks at the seam. The column takes the rest, and by work
## it is already the heavier half of the road: 18 beetles is 288 points of
## health against the swarm's 66.
const ENDLESS_APHID_SHARE: int = 22
const ENDLESS_BEETLE_SHARE: int = 18

## The beetle column, which is the one endless number left uncapped — and the
## only one that can be. With the per-pest multipliers capped (deliberately,
## above) and the road capped too, the only way a later wave can ask more of
## the player is to spend the same road space on the heavier species. One more
## beetle every wave, forever: 16 more points of work, and about two more
## seconds of siege.
const ENDLESS_BEETLE_BASE: int = 6
const ENDLESS_BEETLE_STEP: int = 1

## How much of a wave's threat a mutation roll is worth. Well under 1.0 because
## a mutation makes a pest harder to remove, not a second pest.
const MUTATION_THREAT_WEIGHT: float = 0.6

## Each group: species, how many, and the gap in seconds between each one.
## `lead` is the pause before the group starts.
const WAVES: Array[Array] = [
	[{"species": &"aphid", "count": 5, "gap": 1.10, "lead": 0.5}],
	[{"species": &"aphid", "count": 9, "gap": 0.85, "lead": 0.5}],
	[
		{"species": &"aphid", "count": 8, "gap": 0.70, "lead": 0.5},
		{"species": &"beetle", "count": 1, "gap": 1.00, "lead": 2.0},
	],
	[
		{"species": &"aphid", "count": 12, "gap": 0.55, "lead": 0.5},
		{"species": &"beetle", "count": 2, "gap": 2.00, "lead": 1.5},
	],
	[
		{"species": &"beetle", "count": 3, "gap": 1.60, "lead": 0.5},
		{"species": &"aphid", "count": 10, "gap": 0.45, "lead": 1.0},
	],
	[
		{"species": &"aphid", "count": 16, "gap": 0.38, "lead": 0.5},
		{"species": &"beetle", "count": 3, "gap": 1.40, "lead": 2.0},
	],
	[
		{"species": &"beetle", "count": 5, "gap": 1.20, "lead": 0.5},
		{"species": &"aphid", "count": 14, "gap": 0.40, "lead": 1.0},
	],
	[
		{"species": &"aphid", "count": 22, "gap": 0.30, "lead": 0.5},
		{"species": &"beetle", "count": 7, "gap": 0.90, "lead": 1.5},
	],
]

var current_wave: int = 0
## Set by the title screen (RunConfig.endless) before Game._ready() runs. Past
## the fixed table, has_more_waves() never goes false — the run only ends by
## running out of lives.
var endless: bool = false

## Flattened spawn schedule for the running wave: [{species, at, mutation}],
## `at` in seconds from the moment the wave started.
var _schedule: Array[Dictionary] = []
var _next: int = 0
var _elapsed: float = 0.0
var _running: bool = false
var _rng := RandomNumberGenerator.new()


## Fixes the mutation roll for tests and for reproducing a run.
func set_seed(value: int) -> void:
	_rng.seed = value


func wave_count() -> int:
	return WAVES.size()


func is_spawning() -> bool:
	return _running


func has_more_waves() -> bool:
	if endless:
		return true
	return current_wave < WAVES.size()


## Pests actually scheduled for the wave in progress — unlike the static
## pests_in_wave(), this works past the end of the fixed table (endless mode).
func current_wave_pest_count() -> int:
	return _schedule.size()


## Total pests a wave will send. Used by the HUD and by the tests, which is why it
## reads the table rather than counting what was spawned.
static func pests_in_wave(number: int) -> int:
	if number < 1 or number > WAVES.size():
		return 0
	var total: int = 0
	for group: Dictionary in WAVES[number - 1]:
		total += int(group["count"])
	return total


func start_next_wave() -> int:
	if not has_more_waves():
		return 0
	current_wave += 1
	var groups: Array = groups_for(current_wave)
	_schedule = _build_schedule(groups)
	_next = 0
	_elapsed = 0.0
	_running = not _schedule.is_empty()
	wave_started.emit(current_wave)
	return current_wave


## Past the fixed table, endless keeps the same two-group shape (aphid swarm,
## beetle column), so the curve does not visibly reset the moment the table
## runs out — but only one of the two still grows.
##
## The swarm is pinned at its road share. It arrives exactly as tight as it
## always did (the 0.30 - over * 0.01 curve, down to its 0.16 s floor) and it is
## over in about three and a half seconds. Everything a later wave gains goes
## into the column instead, which is what turns a long run from a quantity
## problem into a composition one: beetles are 24% of wave 9's bodies, 45% of
## wave 20's, 69% of wave 50's, 82% of wave 100's and 96% of wave 500's. Same
## shape on the road, steadily worse contents.
##
## Static so threat_for() can price a wave that is not running — it reads only
## `number` and the table size, never instance state.
static func _endless_groups(number: int) -> Array:
	var over: int = number - WAVES.size()
	var beetles: int = endless_beetle_count(over)
	return [
		{
			"species": Pest.APHID,
			"count": ENDLESS_APHID_SHARE,
			"gap": _paced_gap(maxf(0.16, 0.30 - over * 0.01), Pest.APHID, number,
				ENDLESS_APHID_SHARE, ENDLESS_APHID_SHARE),
			"lead": 0.5,
		},
		{
			"species": Pest.BEETLE,
			"count": beetles,
			"gap": _paced_gap(maxf(0.5, 0.9 - over * 0.02), Pest.BEETLE, number,
				beetles, ENDLESS_BEETLE_SHARE),
			"lead": 1.5,
		},
	]


## Beetles in the endless wave `WAVES.size() + over`. Clamped at `over <= 0` so
## escalation_note() can ask what the wave before the first endless one sent
## without reading off the front of the curve.
static func endless_beetle_count(over: int) -> int:
	return ENDLESS_BEETLE_BASE + maxi(0, over) * ENDLESS_BEETLE_STEP


## The length of the walk in pixels, entrance to exit. Read off Board's own
## corner list rather than typed in, so a change to the path shape cannot leave
## the pacing below quietly pricing the old road. The corners are axis-aligned
## by construction — Board._build_path steps between them with signi() — so the
## Manhattan distance IS the walk, and the two extra cells are the off-board
## entry and exit that Board._build_route brackets the route with.
static func route_length() -> float:
	var cells: int = 0
	for i: int in range(Board.PATH_CORNERS.size() - 1):
		var delta: Vector2i = Board.PATH_CORNERS[i + 1] - Board.PATH_CORNERS[i]
		cells += absi(delta.x) + absi(delta.y)
	return float(cells + 2) * float(Board.CELL)


## How long one pest of `species` takes to walk the whole road on `wave`. The
## other half of the pacing arithmetic: how many of a group are walking at once
## is its spawn rate times this, and nothing else.
static func crossing_seconds(species: StringName, wave: int) -> float:
	var speed: float = float(Pest.SPECIES[species]["speed"]) * speed_scale_for(wave)
	return route_length() / speed


## `natural` is the spacing the escalation curve wants; the return is the
## spacing the road can take. A group of more than `share` pests has to be
## spread to `crossing / share` or it stacks up — that, rather than a
## hard-coded floor, is what a spawn gap's minimum is actually for.
##
## A group no bigger than its share needs no floor at all, since it cannot
## exceed the share however tightly it is packed. That is deliberate and it is
## why the early endless waves are spaced exactly as they always were: the
## pacing only starts biting at the wave the road actually fills up.
static func _paced_gap(natural: float, species: StringName, wave: int, count: int, share: int) -> float:
	if count <= share:
		return natural
	return maxf(natural, crossing_seconds(species, wave) / float(share))


## The most pests that can be walking at once during `wave` — the number
## SIMULTANEOUS_PEST_CEILING is a ceiling on.
##
## Every pest is counted from the instant it spawns to the instant it would
## reach the exit, and nothing is ever killed. That is the pessimistic reading
## and the honest one: a board that kills nothing is exactly the board the
## player is about to lose on, and it is the case where the frame rate has to
## hold up.
static func peak_simultaneous_pests(wave: int) -> int:
	var spawns := PackedFloat64Array()
	var exits := PackedFloat64Array()
	var cursor: float = 0.0
	for group: Dictionary in groups_for(wave):
		cursor += float(group["lead"])
		var gap: float = float(group["gap"])
		var crossing: float = crossing_seconds(StringName(group["species"]), wave)
		for _i: int in range(int(group["count"])):
			spawns.append(cursor)
			exits.append(cursor + crossing)
			cursor += gap
	spawns.sort()
	exits.sort()
	# The count only ever goes up at a spawn, so the peak is always at one — no
	# need to look anywhere else. A pest whose exit lands exactly on a spawn is
	# counted as still walking, which is the pessimistic reading and the right
	# one for a ceiling.
	var peak: int = 0
	var gone: int = 0
	for i: int in range(spawns.size()):
		while gone < exits.size() and exits[gone] < spawns[i]:
			gone += 1
		peak = maxi(peak, i + 1 - gone)
	return peak


## The groups any wave will send, table or endless. One place that answers
## "what is in wave N", so the schedule builder and the threat readout can
## never be pricing different waves.
static func groups_for(wave: int) -> Array:
	if wave < 1:
		return []
	return WAVES[wave - 1] if wave <= WAVES.size() else _endless_groups(wave)


## Raw threat: total pest health the wave will put on the road, scaled by the
## per-pest multipliers and the mutation rate. Health is the weighting because
## it is what a lane has to chew through — 22 aphids and 7 beetles are not
## 29 interchangeable units, they are 66 and 112 points of work.
##
## That weighting is what keeps the readout honest now that the endless ramp is
## a composition ramp. Past wave 48 every multiplier below is pinned at its cap,
## so this reduces to `constant * base health of the mix` and the number on the
## bar tracks the beetle column one for one — a wave with one more beetle in it
## prices exactly 16 points higher, and there is no way to make an endless wave
## harder that this function cannot see. The levers _endless_groups moves are
## counts and species, which are the two things it reads first.
##
## The one thing it deliberately does not read is spacing. It never did, and it
## must not start: pacing only ever *loosens* a wave (see _paced_gap), so a
## formula blind to it can only over-state a wave, never under-state one, and a
## threat number that fell because a wave was spread out would be reporting the
## fix as a difficulty cut.
static func _raw_threat(wave: int) -> float:
	var total: float = 0.0
	for group: Dictionary in groups_for(wave):
		var stats: Dictionary = Pest.SPECIES[group["species"]]
		total += float(group["count"]) * float(stats["health"])
	if wave >= MUTATION_START_WAVE:
		total *= 1.0 + mutation_chance_for(wave) * MUTATION_THREAT_WEIGHT
	return total * health_scale_for(wave) * speed_scale_for(wave)


## Wave `wave`'s difficulty as a multiple of wave 1, which is the only unit a
## player has any feel for. Five things now climb independently past the fixed
## table — count, gap, mutation chance, health and speed — and the HUD showed
## none of them; "Wave 39" and "Wave 9" read identically. This collapses all of
## them into one number the bar can carry.
static func threat_for(wave: int) -> float:
	var reference: float = _raw_threat(1)
	if reference <= 0.0:
		return 0.0
	return _raw_threat(wave) / reference


## Each threat level is this much more threat than the one below it.
const THREAT_LEVEL_BASE: float = 1.45


## The readable form of threat_for(), and the one the HUD shows.
##
## The raw multiple is precise and useless on a bar: wave 1 is five aphids, so
## everything is measured against a tiny reference and the number runs away —
## measured live, wave 28 reads x140 and wave 108 reads x897. "Threat 897" tells
## a player nothing they can hold in their head. A log scale keeps the campaign
## at levels 1-8 and puts wave 108 at 19, which is a number that means
## something next to the one you saw last wave.
##
## Non-decreasing rather than strictly increasing, by construction — it is a
## floor, so consecutive waves often share a level. That is the point: a level
## that ticked every single wave would just be the wave number again.
static func threat_level(wave: int) -> int:
	var threat: float = threat_for(wave)
	if threat <= 1.0:
		return 1
	return 1 + int(floor(log(threat) / log(THREAT_LEVEL_BASE)))


## What actually got harder going into `wave`, for the wave-start message. Empty
## inside the fixed table, where the table itself is the escalation and naming
## "more pests" every wave would be noise.
##
## "heavier" is the one that still fires after the other three have hit their
## caps. Before the beetle column existed this line went silent at exactly the
## wave the ramp stopped, which read as "nothing got worse" — the note has to
## keep pace with the axis that is actually still moving or it is worse than
## nothing.
static func escalation_note(wave: int) -> String:
	if wave <= WAVES.size():
		return ""
	var parts: PackedStringArray = []
	if health_scale_for(wave) > health_scale_for(wave - 1):
		parts.append("tougher")
	if speed_scale_for(wave) > speed_scale_for(wave - 1):
		parts.append("faster")
	if mutation_chance_for(wave) > mutation_chance_for(wave - 1):
		parts.append("stranger")
	if endless_beetle_count(wave - WAVES.size()) > endless_beetle_count(wave - 1 - WAVES.size()):
		parts.append("heavier")
	return _join_words(parts)


## "a", "a and b", "a, b and c", "a, b, c and d". Written out because the note
## now has a fourth thing it can say, and the three-way special case it used to
## carry could not reach it.
static func _join_words(parts: PackedStringArray) -> String:
	if parts.is_empty():
		return ""
	if parts.size() == 1:
		return parts[0]
	var head: String = ", ".join(parts.slice(0, parts.size() - 1))
	return "%s and %s" % [head, parts[parts.size() - 1]]


## Flat MUTATION_CHANCE through the fixed table; climbs by
## MUTATION_CHANCE_ENDLESS_STEP per wave past it once endless mode is the
## thing still running waves, capped at MUTATION_CHANCE_MAX so a very long
## run does not end up mutating every single pest.
static func mutation_chance_for(wave: int) -> float:
	var over: int = wave - WAVES.size()
	if over <= 0:
		return MUTATION_CHANCE
	return minf(MUTATION_CHANCE_MAX, MUTATION_CHANCE + float(over) * MUTATION_CHANCE_ENDLESS_STEP)


## Multiplier on a spawned pest's health for `wave`. Exactly 1.0 through the
## fixed table — same `over <= 0` shape as mutation_chance_for, so campaign mode
## is untouched by construction rather than by a mode flag someone can forget.
static func health_scale_for(wave: int) -> float:
	var over: int = wave - WAVES.size()
	if over <= 0:
		return 1.0
	return minf(ENDLESS_HEALTH_MAX, 1.0 + float(over) * ENDLESS_HEALTH_STEP)


## Multiplier on a spawned pest's walking speed for `wave`. See the constants:
## this climbs far more slowly than health and stops far sooner.
static func speed_scale_for(wave: int) -> float:
	var over: int = wave - WAVES.size()
	if over <= 0:
		return 1.0
	return minf(ENDLESS_SPEED_MAX, 1.0 + float(over) * ENDLESS_SPEED_STEP)


func _build_schedule(groups: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cursor: float = 0.0
	var mutating: bool = current_wave >= MUTATION_START_WAVE
	var chance: float = mutation_chance_for(current_wave)
	for group: Dictionary in groups:
		cursor += float(group["lead"])
		var gap: float = float(group["gap"])
		for i: int in range(int(group["count"])):
			var mutation: StringName = &""
			if mutating and _rng.randf() < chance:
				mutation = MUTATIONS[_rng.randi_range(0, MUTATIONS.size() - 1)]
			out.append({"species": group["species"], "at": cursor, "mutation": mutation})
			cursor += gap
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	while _next < _schedule.size() and float(_schedule[_next]["at"]) <= _elapsed:
		var entry: Dictionary = _schedule[_next]
		spawn_requested.emit(entry["species"], entry["mutation"])
		_next += 1
	if _next >= _schedule.size():
		_running = false
		wave_spawning_finished.emit(current_wave)


func reset() -> void:
	current_wave = 0
	_schedule.clear()
	_next = 0
	_elapsed = 0.0
	_running = false
