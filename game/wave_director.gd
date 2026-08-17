class_name WaveDirector
extends Node

## The wave table. Aphids come in swarms and beetles come in ones and twos, so a
## wave is a list of groups rather than a flat count — a run of eight aphids
## followed by a beetle reads very differently from the two interleaved.

## `mutations` is the whole set the roll produced — empty, one, or (since cycle 81, past
## SECOND_MUTATION_START_WAVE) two. It replaced a single `mutation: StringName` argument
## rather than joining it, because two arguments meaning the same thing is how a listener
## ends up reading the one that is easier and paying a doubly-mutated pest for one trait.
signal spawn_requested(species: StringName, mutations: Array)
signal wave_started(number: int)
signal wave_spawning_finished(number: int)

## Wave 8 is where the fixed table gets its first beetle-heavy mix (see WAVES
## below) — the doc's mutations layer onto that rather than starting cold.
##
## It used to be the last wave of the table as well, which made "the campaign's
## finale" and "the wave mutations start" the same wave and left the player one
## wave to meet them in. Growing the table to 16 made it the halfway mark, and
## growing it to 22 (plant-tower-defense-eeaq) has now moved it again — wave 8 is
## a bit over a third of the way in, and the description "the halfway mark" that
## stood here is no longer true. It is left at 8 anyway, deliberately: `_raw_threat`
## multiplies by the mutation weight from this wave on, so moving it re-prices
## every wave from here to the end of the table, and the threat curve is asserted
## to rise strictly wave over wave out to 300. A constant whose only defect is
## that a sentence about it went stale is not worth spending that on. What it
## costs is real and small — mutations now have fourteen waves of campaign to be
## met in rather than eight, so armoured and winged bugs are ordinary by the time
## the queens arrive at 12, 14, 18, 20 and 22 rather than still novel.
const MUTATION_START_WAVE: int = 8
const MUTATION_CHANCE: float = 0.4
const MUTATIONS: Array[StringName] = [Pest.MUTATION_ARMOURED, Pest.MUTATION_WINGED, Pest.MUTATION_HUNGRY]

## Past the fixed table, _endless_groups already turns up count/gap every
## wave — but MUTATION_CHANCE held flat forever, so wave 40 looked exactly as
## "weird" as wave 8 even though everything else about it had escalated.
## Climbing this too keeps a long endless run from going numb.
const MUTATION_CHANCE_ENDLESS_STEP: float = 0.02
const MUTATION_CHANCE_MAX: float = 0.85

## A second trait on the same pest, and the first thing this game's endless ramp does that
## raises VARIETY rather than intensity.
##
## Everything else that escalates — health, speed, the beetle column, the mutation chance
## itself — makes the same eight kinds of enemy (two species x three mutations plus plain)
## arrive harder and more often. Past the cap at wave ~30 the player has met all eight for
## hours and meets nothing new again, ever. A pair is a genuinely different problem rather
## than a bigger one: a hungry winged aphid ignores the Chomp AND eats what it reaches, and
## the answer to it is a different arrangement of plants, not more of them.
##
## Kept deliberately late and rare. It starts a full campaign's worth of waves after single
## mutations do, and it is a roll ON TOP of a pest that already mutated, so its real
## frequency is `mutation_chance_for(wave) * SECOND_MUTATION_CHANCE` — under 3% at the
## first wave it can happen and ~7% at the endless cap. Rare enough that meeting one is an
## event; `test_a_second_mutation_is_rare_and_late` pins both ends.
##
## **This is no longer an endless-only trait, and that is the one behaviour change the
## campaign's growth to 22 waves carries that is not a new row in the table.** It sat at
## 20 while the table ended at 16, so a pair could only ever be met four waves into an
## endless run; waves 20, 21 and 22 are campaign waves now, so a player who never touches
## endless will meet one. Deliberate rather than incidental — it is what makes the last
## three campaign waves ask a question the first nineteen do not, and it costs no road
## budget and no health to ask it. The frequency is unchanged and small: campaign
## mutation chance is flat at MUTATION_CHANCE, so 0.4 * 0.08 = 3.2% of pests, and the
## roll only fires on a pest that already mutated, so a 36-pest wave averages about one.
## Unplaytested at the time of writing — see the bead's note about -t52o.
const SECOND_MUTATION_START_WAVE: int = 20
const SECOND_MUTATION_CHANCE: float = 0.08

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
## Every endless scale stops except one. Measured off the constants above and
## the twenty-two-wave table below: the beetle column is paced out from the very
## first endless wave, the aphid spawn gap floors at wave 36, mutation chance
## caps at 45, health at 56 and speed at 62. From wave 63 the only thing still
## moving is the headcount — and nothing capped it. (Those five wave numbers have
## now moved twice, eight later when the table grew from 8 waves to 16 and six
## later when it grew from 16 to 22, because every one of them is
## `WAVES.size() + n`. The measurements in the paragraph below were taken on the
## eight-wave table and are kept as the history of why this constant exists; they
## are not re-derivations of it.)
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
##
## WHICH WAVE ACTUALLY SPENDS IT moved when the table grew to sixteen waves, and
## the move is worth naming because the budget readout is measured off it. It
## used to be an endless wave: the column ramped 7 -> 18 beetles through waves
## 9-20 at its natural spacing, so at wave 20 all 18 were walking while the
## swarm was still on the road, and the two groups peaked together at exactly
## 40. ENDLESS_BEETLE_BASE is now 20 — past ENDLESS_BEETLE_SHARE from the very
## first endless wave — so _paced_gap spreads the column from the start and it
## reaches its 18 long after the swarm has walked off. Endless now peaks at 29.
##
## The ceiling is unchanged and so is the construction that bounds it (the two
## shares still sum to it exactly). What changed is where the sweep finds the
## worst wave: the campaign's finale, at 40 of 40. That is deliberate rather
## than incidental — see WAVES' last row — because a budget nothing in the game
## ever reaches is decoration, and `cmd budgets` grades this one on the measured
## peak rather than on the shares.
##
## It did NOT move again when the table grew from 16 to 22, and that is the whole
## reason those six waves were inserted in front of the finale rather than added
## after it. The finale is the same row it always was; it still peaks at 40, and
## the sweep still finds the worst wave there. The six new rows peak at 37, 35,
## 34, 33, 38 and 37 — the closest, wave 20, sits two under the bound with a
## queen's brood already counted in. See WAVES' header for why "in front of"
## rather than "after" was forced rather than chosen.
const SIMULTANEOUS_PEST_CEILING: int = 40

## How that ceiling is split between the wave's two groups. They sum to it
## exactly, which is what makes the bound hold by construction rather than by
## tuning: each group is paced so that it alone never has more than its share
## walking, so the wave can never have more than their sum.
##
## The swarm sits inside the range the campaign's own swarms cover (12 to 24
## across waves 9-22), so nothing visibly changes size at the seam. The column
## takes the rest, and by work it is already the heavier half of the road: 18
## beetles is 288 points of health against the swarm's 66.
const ENDLESS_APHID_SHARE: int = 22
const ENDLESS_BEETLE_SHARE: int = 18

## The beetle column, which is the one endless number left uncapped — and the
## only one that can be. With the per-pest multipliers capped (deliberately,
## above) and the road capped too, the only way a later wave can ask more of
## the player is to spend the same road space on the heavier species. One more
## beetle every wave, forever: 16 more points of work, and about two more
## seconds of siege.
##
## The base is not a free number: it is pinned to the last wave of the fixed
## table by the same "nothing shrinks at the seam" rule as the swarm above.
## `_endless_groups` reads `endless_beetle_count(1)` for the first endless wave,
## so BASE + STEP has to price at or above the campaign's finale or the wave
## after the hardest wave in the game is visibly easier than it — and
## threat_for() would report the drop, which is worse than the drop.
##
## The campaign finale is 2 queens + 22 aphids + 12 beetles = 418 points of
## health; the first endless wave is 22 aphids + 21 beetles = 402, carried past
## it by the endless scales (x1.252 mutation, x1.06 health, x1.015 speed) to 542
## against the campaign finale's 518. That is where 20 comes from, and it is why
## this constant has to move whenever the last row of WAVES does. Kept under 21
## so the first endless wave is still mostly swarm — see
## test_the_beetle_column_is_the_axis_that_replaced_the_headcount, which asserts
## exactly that.
##
## **That "kept under 21" is a much harder constraint than it looks, and it is
## what shaped plant-tower-defense-eeaq.** Read forwards it caps the column at 21
## beetles; read backwards it caps the CAMPAIGN. The first endless wave can hold
## at most `3 * ENDLESS_APHID_SHARE + 16 * (ENDLESS_APHID_SHARE - 1)` points of
## base health while staying under half beetle, which is 402 today, and the seam
## rule — threat_for rises strictly wave over wave, across the seam, asserted out
## to wave 300 — turns that into a ceiling on the finale of 402 * 1.3469 / 1.24 =
## **436.7 points of base health**. The finale is already 418. So the campaign
## had 18.7 points of headroom above its last row, which is one beetle and one
## aphid, and appending seven waves to the end of the table was arithmetically
## impossible without first re-deriving A, B and the two road shares together.
## Six waves went in FRONT of the finale instead, into the 300 -> 418 gap that
## was the largest single step in the campaign's second half, and none of the
## four constants moved. If a future cycle does want a heavier finale, this is
## the paragraph to start from: raising the finale means raising
## ENDLESS_APHID_SHARE first, and the shares sum to SIMULTANEOUS_PEST_CEILING
## exactly, which is a literal that test_selftest.gd reads out of this file's
## source text.
const ENDLESS_BEETLE_BASE: int = 20
const ENDLESS_BEETLE_STEP: int = 1

## How much of a wave's threat a mutation roll is worth. Well under 1.0 because
## a mutation makes a pest harder to remove, not a second pest.
const MUTATION_THREAT_WEIGHT: float = 0.6

## Each group: species, how many, and the gap in seconds between each one.
## `lead` is the pause before the group starts.
##
## Twenty-two waves, in four movements. Waves 1-7 teach the two ordinary pests;
## wave 8 is where mutations start (MUTATION_START_WAVE) and the swarm reaches
## full size; 9-15 are the campaign the game did not have — a board that could
## clear wave 8 used to be handed straight to endless, so the fixed table ended
## at the exact moment it had finished explaining itself.
##
## The second movement escalates on ONE axis at a time so a loss is legible. 9-11
## thicken the beetle column against a swarm that no longer grows. 12 is the
## first Aphid Queen, and the wave is deliberately the LIGHTEST of the late
## waves by headcount (23 pests) so the boss is the thing the player is looking
## at rather than one more silhouette in a crowd. 13 and 15 are pure pressure
## waves that give the garden a wave to buy in. 14 puts a queen behind a beetle
## column, so she arrives while the cobs are already busy.
##
## -- The third movement: 16-21, the run-up (plant-tower-defense-eeaq) ---------
##
## WHY THEY ARE HERE AND NOT AFTER THE FINALE. The ask was "more levels" and the
## obvious shape is seven more rows on the end. That is arithmetically impossible
## without moving four endless constants at once, and the derivation is written
## out at ENDLESS_BEETLE_BASE: the first endless wave is pinned under half beetle,
## which caps it at 402 points of base health, which — because threat_for must
## rise strictly ACROSS the seam — caps any campaign finale at 436.7. The old
## finale was already 418. Seven appended waves had 18.7 points of health to share
## between them, which is one beetle.
##
## The 300 -> 418 step from the old wave 15 to the old wave 16 was, at +39%, the
## largest single jump in the campaign's second half, and it is where the six new
## rows went. So the finale is the same row it always was — same peak, same 518
## points of threat, same seam — and what the player gains is a run-up to it
## instead of a wall. Nothing about endless changed except that every landmark in
## it now sits six waves later, which is `WAVES.size() + n` doing exactly what it
## did when the table went from 8 to 16.
##
## The six are one axis each, the same way the second movement is:
##   16  TWO COLUMNS. Beetles, then the swarm, then beetles again. Every other
##       wave in this table is monotone in species order, so a garden that
##       re-commits after the swarm has passed is punished here for the first
##       time — the question is whether you hold anything back;
##   17  THE LONG MARCH. Eighteen beetles at 2.2 s, which is 37 s of column
##       before the swarm even starts: a 46 s wave against a table whose longest
##       was 33 s. Nothing here is dangerous alone. It is the first wave that
##       asks whether the garden can hold a lane for a minute without a lull to
##       repair or replant in;
##   18  THE QUEEN IN THE MIDDLE. Wave 12 puts her at the head of the wave and
##       wave 14 puts her at the head of the column; this buries her BETWEEN two
##       groups, so the cobs are committed down-lane when she arrives and the
##       swarm lands while they are still on her. Same boss, third question;
##   19  THE BATTERING RAM. The same species mix as 17 and the opposite tempo —
##       21 beetles at 0.70 s, the whole wave delivered in 20 s. 17 asks about
##       endurance, 19 asks about burst, and they are next to each other on
##       purpose so the contrast is the lesson;
##   20  RAIN, AND THE FIRST PAIRS. weather_for(20) is rain, and 20 is
##       SECOND_MUTATION_START_WAVE — so the wave that heals the garden as it
##       opens is also the first that can send a pest carrying two traits. It is
##       the finale's own shape (queen, swarm, column) at three-quarter scale,
##       which makes it a rehearsal as well as a wave;
##   21  THE DROUGHT. weather_for(21) is drought, which halves every plant's rate
##       of fire — and drought skips a wave carrying a boss, so this row has no
##       queen precisely so the weather lands. The campaign used to contain
##       exactly one drought (wave 7, against 19 pests); this is its second, and
##       it falls on the second-heaviest wave in the game. A garden built exactly
##       to spec does not clear it; one built over spec does.
##
## Every row here is checked, not eyeballed:
##   * peak_simultaneous_pests() stays inside SIMULTANEOUS_PEST_CEILING for all
##     twenty-two, and the finale is deliberately sized to land on it exactly —
##     40 of 40, brood headroom included, which is why its swarm is 22 and not 23.
##     The campaign finale is still the fullest the road ever gets in this game;
##     see SIMULTANEOUS_PEST_CEILING for why endless no longer is, and for the
##     six new rows' own peaks;
##   * threat_for() rises strictly wave over wave, across the seam into endless
##     and out to wave 300. The six new rows are +19, +20, +16, +17, +8 and +17
##     points of base health apart, i.e. about one beetle each, which is the same
##     step endless itself takes forever;
##   * health_scale_for/speed_scale_for/mutation_chance_for are untouched — they
##     key off `wave - WAVES.size()`, so growing the table moved the whole
##     endless ramp six waves later by construction rather than by edit.
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
	# -- 9-16: the second half (plant-tower-defense-74a) ---------------------
	[
		{"species": &"aphid", "count": 18, "gap": 0.34, "lead": 0.5},
		{"species": &"beetle", "count": 8, "gap": 0.95, "lead": 1.5},
	],
	[
		{"species": &"aphid", "count": 24, "gap": 0.30, "lead": 0.5},
		{"species": &"beetle", "count": 8, "gap": 1.10, "lead": 2.0},
	],
	[
		{"species": &"beetle", "count": 10, "gap": 1.00, "lead": 0.5},
		{"species": &"aphid", "count": 20, "gap": 0.32, "lead": 1.5},
	],
	# The first queen, and she walks in front. Corn shoots whichever pest is
	# furthest along, so leading the wave is what makes her the fight rather
	# than something that arrives after it — every cob she passes is aimed at
	# her until she is dead or gone.
	[
		{"species": &"queen", "count": 1, "gap": 1.00, "lead": 0.5},
		{"species": &"aphid", "count": 14, "gap": 0.36, "lead": 2.5},
		{"species": &"beetle", "count": 8, "gap": 1.10, "lead": 2.0},
	],
	[
		{"species": &"aphid", "count": 22, "gap": 0.28, "lead": 0.5},
		{"species": &"beetle", "count": 13, "gap": 0.95, "lead": 1.5},
	],
	# The second queen walks BEHIND ten beetles, which is the same boss posing
	# the opposite question: the cobs are already committed down the lane when
	# she arrives, so she is deep in the garden before anything is free to aim
	# at her — and a late kill is exactly the kill that hurts.
	[
		{"species": &"queen", "count": 1, "gap": 1.00, "lead": 0.5},
		{"species": &"beetle", "count": 10, "gap": 1.00, "lead": 2.0},
		{"species": &"aphid", "count": 18, "gap": 0.30, "lead": 1.5},
	],
	[
		{"species": &"aphid", "count": 20, "gap": 0.26, "lead": 0.5},
		{"species": &"beetle", "count": 15, "gap": 0.90, "lead": 1.5},
	],
	# -- 16-21: the run-up (plant-tower-defense-eeaq) ------------------------
	# Two columns with the swarm between them. The beetle groups are identical
	# on purpose — it is the same column arriving twice, so the difference the
	# player feels is entirely about what they did in the gap.
	[
		{"species": &"beetle", "count": 8, "gap": 1.10, "lead": 0.5},
		{"species": &"aphid", "count": 21, "gap": 0.30, "lead": 1.5},
		{"species": &"beetle", "count": 8, "gap": 1.10, "lead": 1.5},
	],
	# The long march. 2.20 s is past every gap in the fifteen rows above it (the
	# widest is 2.00 s, for TWO beetles in wave 4) and it is chosen against the
	# beetle's own crossing time: 55.6 s to walk the road, so the seventeen gaps
	# take 37.4 s and the eighteenth beetle spawns while the first is still two
	# thirds of the way down it.
	# The column is therefore continuous rather than a queue, which is what makes
	# this an endurance wave instead of a slow one.
	[
		{"species": &"beetle", "count": 18, "gap": 2.20, "lead": 0.5},
		{"species": &"aphid", "count": 17, "gap": 0.34, "lead": 1.0},
	],
	# The queen in the middle. She is the second group of three, which is the
	# arrangement neither wave 12 nor wave 14 uses.
	[
		{"species": &"beetle", "count": 14, "gap": 1.00, "lead": 0.5},
		{"species": &"queen", "count": 1, "gap": 1.00, "lead": 2.0},
		{"species": &"aphid", "count": 17, "gap": 0.32, "lead": 2.0},
	],
	# The battering ram — wave 17's species mix at three times the tempo.
	[
		{"species": &"beetle", "count": 21, "gap": 0.70, "lead": 0.5},
		{"species": &"aphid", "count": 12, "gap": 0.30, "lead": 1.5},
	],
	# Rain (weather_for(20)) and the first wave that can pair two mutations
	# (SECOND_MUTATION_START_WAVE). Same three groups in the same order as the
	# finale, at three-quarter weight.
	[
		{"species": &"queen", "count": 1, "gap": 1.00, "lead": 0.5},
		{"species": &"aphid", "count": 20, "gap": 0.28, "lead": 2.0},
		{"species": &"beetle", "count": 15, "gap": 1.00, "lead": 1.5},
	],
	# The drought (weather_for(21)). NO QUEEN, and that is load-bearing rather
	# than a choice about pacing: weather_for skips drought on any wave
	# wave_carries_boss() answers true for, so a queen added to this row would
	# silently delete the campaign's second drought and nothing would report it.
	[
		{"species": &"beetle", "count": 22, "gap": 0.85, "lead": 0.5},
		{"species": &"aphid", "count": 15, "gap": 0.28, "lead": 1.5},
	],
	# The finale. Two queens six seconds apart: far enough that the garden
	# cannot simply overlap its answer to both, close enough that the first
	# one's brood is still on the road when the second arrives.
	[
		{"species": &"queen", "count": 2, "gap": 6.00, "lead": 0.5},
		{"species": &"aphid", "count": 22, "gap": 0.28, "lead": 2.0},
		{"species": &"beetle", "count": 12, "gap": 1.00, "lead": 1.5},
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


## -- Weather (plant-tower-defense-q3lx) ------------------------------------
##
## A wave can arrive under weather, which is the first thing in this game that
## changes how a wave PLAYS rather than what is in it. Rain heals the garden;
## drought halves how fast it shoots.
##
## **Derived from the wave number, not a column in WAVES.** A column would be
## twenty-two more hand-typed cells beside twenty-two that already exist, and the
## table's own header spends its closing bullets on how every row in it is checked
## rather than eyeballed. A rule can be stated in one sentence and asserted against
## every wave out to 300, including the endless ones the table does not reach.
##
## The payoff arrived when the campaign grew to 22 waves: waves 16-21 picked up
## their weather without a line of code, one rain (20) and one drought (21), and
## the drought is real only because that row happens to carry no queen. A column
## would have needed six more cells typed by the same hand that wrote the rows.
const WEATHER_CLEAR := &"clear"
const WEATHER_RAIN := &"rain"
const WEATHER_DROUGHT := &"drought"

## Nothing before this: the opening waves are where a player is learning what a
## plant even does, and a mechanic that changes the rules lands better once the
## rules are known. 4 is the wave the second plant is normally affordable by.
const WEATHER_FIRST_WAVE: int = 4
## Rain every 5th wave, drought every 7th. Coprime on purpose -- equal periods
## would make one of them permanently shadow the other, and the two only collide
## every 35 waves, which endless reaches and the campaign does not.
const WEATHER_RAIN_EVERY: int = 5
const WEATHER_DROUGHT_EVERY: int = 7

## Which weather a wave arrives under.
##
## Two rules that are not arbitrary and are asserted in the suite:
##
##   * **Rain wins a collision.** Wave 35 is a multiple of both. The mercy beats
##     the cruelty, because a wave that is simultaneously "heal everything" and
##     "shoot half as fast" is not a readable event, and if one of them has to be
##     silently dropped it should be the one that costs the player.
##   * **Drought never lands on a wave carrying a boss.** Derived by asking the
##     table whether the wave contains a queen, not by excluding 12/14/16 by hand
##     -- so a queen moved or added takes its drought exemption with it. Halving
##     the garden's rate of fire on the wave that is already the hardest is not
##     difficulty, it is a spike, and the table's threat curve does not know
##     weather exists.
static func weather_for(wave: int) -> StringName:
	if wave < WEATHER_FIRST_WAVE:
		return WEATHER_CLEAR
	if wave % WEATHER_RAIN_EVERY == 0:
		return WEATHER_RAIN
	if wave % WEATHER_DROUGHT_EVERY == 0 and not wave_carries_boss(wave):
		return WEATHER_DROUGHT
	return WEATHER_CLEAR


## Does this wave's table row contain a boss? False past the end of the table --
## endless spawns no queens, so there is nothing there to protect.
static func wave_carries_boss(wave: int) -> bool:
	if wave < 1 or wave > WAVES.size():
		return false
	for group: Dictionary in WAVES[wave - 1]:
		if StringName(group["species"]) == Pest.QUEEN:
			return true
	return false


## What a plant's firing interval is multiplied by under this weather. Drought is
## the only one that touches it; the number is 2.0 because "halves fire rate" is
## the design brief's own wording and an interval is the reciprocal of a rate.
const WEATHER_DROUGHT_INTERVAL_SCALE: float = 2.0

static func fire_interval_scale_for(weather: StringName) -> float:
	return WEATHER_DROUGHT_INTERVAL_SCALE if weather == WEATHER_DROUGHT else 1.0


## What a pest killed under this weather is worth, as a multiple of its seed value
## (plant-tower-defense-4c1l).
##
## **Only drought pays.** A drought doubles every plant's firing interval, so the same
## wave costs the player more plants, more lives and more attention — and until now it
## paid exactly what the easy version of that wave paid. This is the same idea as
## `Pest.husk_multiplier()`, which already pays more for a harder kill; weather is that
## idea one level up, applied to the whole wave rather than to one mutation.
##
## Rain stays at 1.0 rather than paying LESS, which would be the symmetrical choice and
## the wrong one. Rain is the mercy wave; making it also the poor wave turns the good
## weather into something a player dreads, and the healing is already its whole effect.
##
## 1.5 rather than 2.0: a drought should be worth surviving, not worth WANTING. At 2.0
## the arithmetic starts to favour praying for bad weather, which inverts the mechanic.
const WEATHER_DROUGHT_SEED_BONUS: float = 1.5

static func seed_multiplier_for(weather: StringName) -> float:
	return WEATHER_DROUGHT_SEED_BONUS if weather == WEATHER_DROUGHT else 1.0


## How much of a plant's maximum health a rain wave gives back, applied once as
## the wave opens rather than trickled -- a heal the player can SEE happen is
## worth more than a slightly larger one they cannot.
const WEATHER_RAIN_HEAL_FRACTION: float = 0.35


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
## over in about six seconds. Everything a later wave gains goes into the column
## instead, which is what turns a long run from a quantity problem into a
## composition one: beetles are 49% of the first endless wave's bodies, 52% of
## wave 26's, 69% of wave 50's, 82% of wave 100's and 96% of wave 500's. Same
## shape on the road, steadily worse contents. (Those percentages are quoted at
## fixed wave NUMBERS, so five of the six moved when the table grew from 16 waves
## to 22 and `over` shrank by six at every one of them — the first-endless figure
## is the only one that is a property of the constants rather than of where the
## table happens to end.)
##
## What endless does NOT do is queens. The boss lives in the fixed table only,
## and that is a decision rather than an omission: the two endless invariants
## worth having are that threat rises every single wave and that the rise is
## exactly one beetle's worth (see _raw_threat), and a boss that appears every
## Nth wave breaks both — the wave after a boss wave prices lower than the boss
## wave, which the readout would have to report as the difficulty going down.
## Making bosses permanent instead would need a third road share, and the two
## that exist already sum to SIMULTANEOUS_PEST_CEILING exactly.
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


## Bodies a wave can put on the road that its own schedule does not list.
##
## A boss bursts into `split_count` smaller pests when it is killed
## (Game._spawn_brood), so a wave carrying one is a wave that can hold one more
## body than it schedules — `count - 1` more, since the boss itself is gone by
## then. That is invisible to the schedule sweep below, which never kills
## anything, and it is the exact case the road budget exists to bound: a queen
## dying is not a rare event, it is the intended outcome of every queen.
##
## Counted at its worst: every boss in the wave burst at the same instant, all
## the brood still walking, and nothing else dead. That over-states a real wave
## (a queen killed at the gate leaves aphids that are gone long before the
## finale's second queen arrives) and over-stating is the only safe direction
## for a ceiling.
static func brood_headroom_for(wave: int) -> int:
	var extra: int = 0
	for group: Dictionary in groups_for(wave):
		var split: int = Pest.split_count(StringName(group["species"]))
		if split > 1:
			extra += int(group["count"]) * (split - 1)
	return extra


## The most pests that can be walking at once during `wave` — the number
## SIMULTANEOUS_PEST_CEILING is a ceiling on.
##
## Every pest is counted from the instant it spawns to the instant it would
## reach the exit, and nothing is ever killed. That is the pessimistic reading
## and the honest one: a board that kills nothing is exactly the board the
## player is about to lose on, and it is the case where the frame rate has to
## hold up.
##
## Nothing-is-ever-killed used to be the whole story, and a boss broke it in the
## one direction the sweep cannot see: the ONLY way to put a queen's brood on
## the road is to kill her, so "nothing dies" is no longer the worst case for
## headcount. brood_headroom_for() adds that back on top — see its own comment.
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
	return peak + brood_headroom_for(wave)


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
			var rolled: Array[StringName] = []
			if mutating and _rng.randf() < chance:
				rolled.append(MUTATIONS[_rng.randi_range(0, MUTATIONS.size() - 1)])
				# A second trait is a roll ON TOP of a pest that already mutated, so
				# its real frequency is the product of the two chances. Rolled from the
				# whole list and rejected once if it does not compose, rather than from
				# a filtered list: `Pest.mutations_compose` owns that rule and a second
				# copy of it here is how the two drift.
				if current_wave >= SECOND_MUTATION_START_WAVE \
						and _rng.randf() < SECOND_MUTATION_CHANCE:
					var second: StringName = MUTATIONS[_rng.randi_range(0, MUTATIONS.size() - 1)]
					if Pest.mutations_compose(rolled[0], second):
						rolled.append(second)
			out.append({
				"species": group["species"],
				"at": cursor,
				"mutation": rolled[0] if not rolled.is_empty() else &"",
				"mutations": rolled,
			})
			cursor += gap
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	while _next < _schedule.size() and float(_schedule[_next]["at"]) <= _elapsed:
		var entry: Dictionary = _schedule[_next]
		spawn_requested.emit(entry["species"], entry["mutations"])
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
