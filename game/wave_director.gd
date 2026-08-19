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
## **That "eight kinds" is now a fact about ENDLESS only, and the asymmetry is the point.**
## The campaign gained a third ordinary species when the Shield Bug entered the table at
## waves 15 and 21 (plant-tower-defense-pdri), so a campaign player meets three species x
## three mutations plus plain — twelve kinds, not eight. `_endless_groups` still sends
## aphids and beetles and nothing else, so the paragraph above is unchanged where it is
## actually about: past the table, the mix rotates between two species forever and the
## twelfth kind is one more thing an endless run stops showing you. Deliberately not
## "fixed" by adding the Shield Bug to the endless mix — the swarm and the column sum to
## SIMULTANEOUS_PEST_CEILING exactly (see ENDLESS_APHID_SHARE), so a third endless group
## needs a third road share and all four constants re-derived together.
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

## --- The second act (plant-tower-defense-iqp8) ------------------------------
##
## The campaign's back half did not escalate. Derived from the table rather than
## sampled: waves 2-7 step +80.0%, +48.1%, +70.0%, +14.7%, +23.1% and +27.1% of
## threat_for, wave 8 steps +43.3% after cycle 101's tuning — and then waves 10
## through 22 average +6.7% a wave for thirteen waves, four of them under +4%.
## Cycle 101 played the campaign end to end and a depth-first garden won all
## twenty-two waves without losing a single life, finishing on 1129 spare seeds.
## Both of that cycle's opposed seed policies had all seven plants unlocked by
## wave 7, and neither was ever asked to use them. The design question ("is a
## flawless 22/22 the right ending for a tutorial campaign?") was put to James
## and answered: the plateau should climb.
##
## THIS IS THE LEVER, and it is one function rather than fourteen wave rows. The
## rows cannot grow. ENDLESS_BEETLE_BASE's derivation caps any campaign finale at
## 436.7 points of base health against a finale already worth 418, so the entire
## table has about one beetle of headroom in it. `health_scale_for` had no such
## bound — it simply returned 1.0 for every campaign wave, which meant the one
## axis the campaign could escalate on for free was switched off by construction.
##
## Compounding rather than linear, and anchored at wave 9 rather than wave 1:
##   * ANCHORED AT 9 because wave 8 is MUTATION_START_WAVE and wave 9 already
##     steps +29.1% on count alone. Cycle 101's whole argument was that two
##     difficulty increases landing on one wave is a step nobody can read; a ramp
##     whose first step fell on 9 would repeat the mistake it fixed. So
##     health_scale_for(9) is exactly 1.0 and wave 10 is the first tougher wave.
##   * COMPOUNDING because a linear ramp front-loads. +0.03 against a 1.0 base is
##     a bigger relative step than +0.03 against a 1.5 one, so a linear ramp
##     climbs hardest at waves 10-12 and least at 20-22, which is the opposite
##     shape a second act wants. Compounding puts the same +3% on every wave.
##
## WHAT 0.03 BUYS, priced offline against _raw_threat: the finale's pests are
## x1.469, the back half's smallest step goes +2.2% -> +5.2% (wave 20) and its
## average +6.7% -> +9.9%, and no step anywhere in the campaign exceeds +17.0%
## (wave 12, the first queen) — so this introduces no new cliff, and wave 8's
## +43.3% is still comfortably the largest step in the game. Against a level-1
## Corn Cobbler (1.0 damage a kernel) an aphid costs 3 kernels through wave 9,
## 4 from wave 10 and 5 from wave 19, which is the bead in one sentence: the
## swarm outgrows the plant the player starts with.
##
## **EVERY NUMBER IN THAT PARAGRAPH WAS WRONG FOR ONE CYCLE AND NOTHING SAID SO
## (plant-tower-defense-8v43).** It was written when this constant was 0.04 and
## survived a067d5f settling it at 0.03 unedited, so it argued a behaviour —
## x1.665, +18.2%, five kernels from wave 17, the cap at 36 — belonging to a
## number the game does not have. Prose is where this file's quantities live, and
## the two tests over this ramp were both written to derive FROM the constant
## (test_the_second_act_starts_where_it_says_it_does computes its own `top`;
## test_the_swarm_outgrows_the_plant_the_player_starts_with asserts `rises >= 2`),
## which is right for the shape and leaves the magnitudes unchecked by
## construction. The figures above are now pinned in the player's own units by
## `test_the_second_act_costs_what_its_comment_says_it_costs`, so moving this
## constant fails the suite and lands the editor on this paragraph.
##
## WHAT IT COSTS. ENDLESS_HEALTH_MAX is an absolute ceiling on how tough a pest
## may ever get, not a budget belonging to endless, and the campaign now spends
## part of it: endless health reaches the cap at wave 40 instead of wave 56.
## Speed still pins last, at wave 62, so anything that searches for "the first
## wave past which nothing per-pest is moving" finds the same wave it did.
##
## NOT playtested. Every number above is an offline model of pure functions.
## Whether wave 18 is now hard rather than merely long is unknown until someone
## plays it — see the bead.
const SECOND_ACT_START_WAVE: int = 9
const CAMPAIGN_HEALTH_STEP: float = 0.03

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
## 34, 33, 38 and 38 — the closest, waves 20 and 21, sit two under the bound with
## a queen's brood already counted in. See WAVES' header for why "in front of"
## rather than "after" was forced rather than chosen.
##
## It did not move for the Shield Bug either (plant-tower-defense-pdri), and that
## is the same story a third time. Waves 15 and 21 gained a plated group and each
## PAID for it in beetles rather than being allowed to grow: 15 went 35 -> 37
## pests and 21 went 37 -> 38, both still under the bound, and the finale was left
## untouched at 40 of 40 and 418 points of base health. Putting the species in the
## finale instead would have been the obvious place for it and was rejected on
## arithmetic — see WAVES' header for the 8-of-18.7 that would have cost.
##
## And a fourth time for the second boss (plant-tower-defense-gsai). Waves 17 and
## 19 each traded three beetles for one Nurse Beetle, which is 48 points of base
## health out and 48 back in, so both rows price at exactly what they always did
## and both got EMPTIER on the road: 17 peaked 35 -> 33 and 19 peaked 33 -> 31. The
## finale is untouched for the fourth time running. That is now the pattern rather
## than a coincidence: past wave 12 this table has no slack left, so a new species
## enters by displacement or not at all, and the finale is the one row with nothing
## to displace.
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
##
## **436.7 survived the second act unchanged, and that was designed for rather
## than lucky.** plant-tower-defense-iqp8 ramps `health_scale_for` across waves
## 10-22, which multiplies the finale's threat — so a naive campaign ramp eats
## this headroom, and at CAMPAIGN_HEALTH_STEP 0.03 an additive endless ramp cuts
## 18.7 points to about 11 — one Shield Bug. The endless ramp is expressed as a
## multiple of the campaign's last health scale instead, so the campaign factor
## appears on both sides of the division above and cancels out of it exactly. The
## 1.3469 is unchanged; its 1.06 is now the RATIO h(23)/h(22). health_scale_for
## has the full derivation.
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
## **The rows below are no longer the campaign's whole difficulty curve.** Since
## plant-tower-defense-iqp8 a compounding health ramp runs underneath waves 10-22
## (SECOND_ACT_START_WAVE), so a row's "points of base health" — the unit every
## note in this file quotes, and the one all the seam arithmetic is done in — is
## what the row is worth BEFORE that multiplier. Every such figure here is still
## correct as written and still the right thing to reason about when editing a
## row, because the ramp multiplies rows rather than reordering them. What it
## means is that the finale actually puts 418 * 1.665 = 696 points of health on
## the road, and that a reader comparing a wave's number here against a pest's
## health bar in the running game will find the bar bigger.
##
## The second movement escalates on ONE axis at a time so a loss is legible. 9-11
## thicken the beetle column against a swarm that no longer grows. 12 is the
## first Aphid Queen, and the wave is deliberately the LIGHTEST of the late
## waves by headcount (23 pests) so the boss is the thing the player is looking
## at rather than one more silhouette in a crowd. 13 is a pure pressure wave that
## gives the garden a wave to buy in. 14 puts a queen behind a beetle column, so
## she arrives while the cobs are already busy. 15 is the Shield Bug's debut —
## see its own note on the row.
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
##   17  THE LONG MARCH. Fifteen beetles at 2.2 s, which is 31 s of column before
##       the swarm even starts: a 40 s wave against a table whose next longest is
##       27 s. Nothing here is dangerous alone. It is the first wave that asks
##       whether the garden can hold a lane for the better part of a minute
##       without a lull to repair or replant in — and, since
##       plant-tower-defense-gsai, whether it can do that against a Nurse Beetle
##       putting 2.0 health a second back into whatever it is shooting;
##   18  THE QUEEN IN THE MIDDLE. Wave 12 puts her at the head of the wave and
##       wave 14 puts her at the head of the column; this buries her BETWEEN two
##       groups, so the cobs are committed down-lane when she arrives and the
##       swarm lands while they are still on her. Same boss, third question;
##   19  THE BATTERING RAM. The same species mix as 17 and the opposite tempo —
##       18 beetles at 0.70 s, the whole wave delivered in 19 s. 17 asks about
##       endurance, 19 asks about burst, and they are next to each other on
##       purpose so the contrast is the lesson. Both carry a Nurse Beetle for
##       that same reason: a boss in one and not the other would have turned a
##       matched pair into two unrelated waves;
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
##       to spec does not clear it; one built over spec does. It is also the
##       Shield Bug's second and last campaign appearance, and the pairing is the
##       reason it is here rather than anywhere else in the run-up: drought
##       doubles a plant's firing INTERVAL (WEATHER_DROUGHT_INTERVAL_SCALE) while
##       a plate eats whole kernels, so the two failures stack on exactly one
##       plant — the Corn Cobbler — and on none of the three answers to it. A
##       Chomp's `chew_seconds` and a Dandelion's blast radius are not rates and
##       the weather does not touch them. This is the one wave in the campaign
##       where "which plant answers this lane" is asked with both hands.
##
## -- The Shield Bug enters at 15 and 21 (plant-tower-defense-pdri) -------------
##
## The species shipped a cycle before it was in any wave, deliberately, so that it
## could land and be tested before it moved the difficulty curve. This is that
## second half, and both halves of it are arithmetic.
##
## WHICH WAVE. Its whole point is that a Corn Cobbler cannot hurt it — a level-1
## cob's 1.0 kernel is under `shell_absorb` 1.5 and so are all three of its
## upgrades, so a corn-only lane does literally nothing to one for six hits. That
## makes it a decision only for a player who owns something else, and a wall for
## one who does not, so it belongs after the Chomp Flower and the Bomb Dandelion
## are realistically OWNED rather than merely purchasable. Chomp is tier 1 at 15
## seeds and is the only tier-1 plant a 20-seed common packet can roll, so it is
## effectively guaranteed early; the Dandelion is tier 3 at 45 seeds and reachable
## only through a 90-seed epic packet, which is the late one. Cycle 101 played the
## campaign end to end on two opposed seed policies and BOTH had all seven plants
## unlocked by wave 7 (log-devtools.md, cycle 101). Wave 15 leaves eight waves of
## income on top of that before the plate is ever seen, which is the margin that
## makes it a decision.
##
## Wave 15 also cost the least written design of any row in that band: it and 13
## were the campaign's two "pure pressure" rows, the only ones in the second
## movement with no idea of their own. One of them was free to become one.
##
## WHAT IT DISPLACES, and why NOT the finale. The obvious home for a new species
## is wave 22, and it is the one place it cannot go cheaply. The finale is at 40
## of 40 on the road, so anything added there displaces a body; and it sits 18.7
## points of base health under the 436.7 seam bound (ENDLESS_BEETLE_BASE has the
## derivation), which is the campaign's scarcest resource and the entire reason
## plant-tower-defense-eeaq inserted six waves in FRONT of the finale instead of
## after it. The cheapest legal finale carrying three plated bugs was -1 beetle
## -2 aphids +3 shieldbugs = 426 points, which spends 8 of those 18.7 — 43% of the
## headroom the next balance pass has to work in — and it would also have made
## wave 20 four groups' worth of rehearsal for a four-group finale. Rejected on
## price. The finale is byte-for-byte the row it always was.
##
## So both appearances pay in beetles, on rows that had slack:
##   15  -2 beetles, +4 shieldbugs. 300 -> 308 points of base health (+2.7%),
##       35 -> 37 pests, peak 35 -> 37 of 40. The step in from 14 goes +2.0% ->
##       +4.8%, which moves the campaign's flattest join off its floor.
##   21  -2 beetles, +3 shieldbugs. 397 -> 395 points (-0.5%), 37 -> 38 pests,
##       peak 37 -> 38 of 40. This row gets LIGHTER in health and heavier in play,
##       which is not a contradiction — see _raw_threat, which prices a Shield Bug
##       at its 10 points of health and cannot see the plate at all.
## Both are placed LAST in their wave on purpose. The swarm and the column have
## already pulled every cob down-lane by then, so the plated group arrives at the
## one moment the answer to it is a plant the player either has or does not.
##
## -- The Nurse Beetle enters at 17 and 19 (plant-tower-defense-gsai) -----------
##
## The campaign's SECOND boss, and it is in the table because the bead asked for a
## boss that poses a different question rather than a bigger one. The queen's
## question is where a kill lands. The Nurse's is what the garden's damage is
## AIMED at: every damaging plant here shoots the pest furthest along the road, so
## a healer walking behind the front of the queue is something the garden's own
## targeting rule will not shoot at while it undoes the damage that rule is doing.
## The two answers are the two plants that ignore the rule — a Chomp at the mouth
## of a lane and a Dandelion's area blast. `Pest.SPECIES[NURSE]` has the full
## argument and every number's derivation.
##
## CAMPAIGN, NOT ENDLESS, and that was a decision rather than a default. Endless is
## unbounded and would have been the cheap place to put her — but `_endless_groups`
## is built on two invariants that a periodic boss breaks (threat rises EVERY wave,
## and the rise is exactly one beetle's worth), and a third road share would have to
## come out of two that already sum to SIMULTANEOUS_PEST_CEILING exactly. That
## argument is already written out at `_endless_groups` for the queen and it is
## unchanged by there being two bosses instead of one. The campaign is also simply
## where this species means something: it is a question about whether the player's
## garden owns a second kind of plant, and endless is played by a garden that
## already owns everything.
##
## WHICH ROWS. Not 12, 14, 18, 20 or 22 — those carry the queen, and two bosses in
## one wave dilutes both. Not 15, which is the Shield Bug's debut. Not 21: making a
## row a boss row exempts it from drought (`weather_for`), so a Nurse there would
## silently delete the campaign's second drought, which is the exact failure the row
## for 21 warns about and test_economy enumerates against. Not 13, which is the
## campaign's one deliberate "buy a plant" breather and sits between two queens.
## That leaves 16, 17 and 19, and 17/19 are a matched pair by construction.
##
## WHAT THEY COST. Three beetles each, exactly:
##   17  -3 beetles, +1 Nurse. 339 -> 339 points of base health (48 out, 48 in),
##       35 -> 33 pests, peak 35 -> 33 of 40.
##   19  -3 beetles, +1 Nurse. 372 -> 372 points, 33 -> 31 pests, peak 33 -> 31.
## So the entire threat curve — wave 1 through wave 300, the seam, the finale's 418
## against the 436.7 bound — is unmoved to the last decimal, and the finale is
## byte-for-byte the row it has always been. The campaign got harder in two places
## and the number on the bar did not move, which is honest rather than convenient:
## `_raw_threat` prices a Nurse at her 48 points of health and cannot see the aura,
## exactly as it cannot see the Shield Bug's plate. Both under-statements are
## written down there rather than fudged.
##
## Every row here is checked, not eyeballed:
##   * peak_simultaneous_pests() stays inside SIMULTANEOUS_PEST_CEILING for all
##     twenty-two, and the finale is deliberately sized to land on it exactly —
##     40 of 40, brood headroom included, which is why its swarm is 22 and not 23.
##     The campaign finale is still the fullest the road ever gets in this game;
##     see SIMULTANEOUS_PEST_CEILING for why endless no longer is, and for the
##     six new rows' own peaks;
##   * threat_for() rises strictly wave over wave, across the seam into endless
##     and out to wave 300. The six run-up rows are +11, +20, +16, +17, +8 and +15
##     points of base health apart, i.e. about one beetle each, which is the same
##     step endless itself takes forever. (The first and last of those six moved
##     when the Shield Bug landed: wave 15 rose 300 -> 308 so 16's step shrank,
##     and wave 21 fell 397 -> 395 so its own step shrank and the finale's grew.
##     Both are still inside the +2.0% to +13.6% band every row from 9 to 22 sits
##     in — see the note on wave 8.);
##   * health_scale_for/speed_scale_for/mutation_chance_for are untouched — they
##     key off `wave - WAVES.size()`, so growing the table moved the whole
##     endless ramp six waves later by construction rather than by edit.
##     (That third bullet is history now, and only for health.
##     plant-tower-defense-iqp8 gave the campaign a second act by ramping
##     `health_scale_for` from wave 10 to wave 22 — see SECOND_ACT_START_WAVE.
##     Nothing in the two bullets above moved with it: the ramp touches no count
##     and no gap, so every peak, every road-budget number and every "points of
##     base health" figure quoted anywhere in this file is still the number it
##     was. Speed and the mutation rate really are still endless-only.)
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
	# Wave 8 is MUTATION_START_WAVE, and it used to be a double step: 22 aphids at
	# 0.30 plus 7 beetles priced +45.9% on count alone, and the mutation multiplier
	# then compounded another +24.0% on top of it, for +80.9% in one wave. Every
	# other wave from 9 to 22 steps between +2.0% and +13.6%. Two independent
	# difficulty increases landed on the same wave, so there was no wave anywhere in
	# the campaign where a player met an armoured or winged pest at a density they
	# could read.
	#
	# The counts below hold wave 7's peak spawn rate exactly (0.40 gap = 2.50/s), so
	# the new thing on screen at wave 8 is the mutation and nothing else. The
	# mutation weight alone then carries the wave: +43.3%, in line with wave 6's
	# +23.1% and wave 7's +27.1%, and the count ramp resumes at wave 9 (+29.1%
	# instead of +2.2%). Waves 10-22 are untouched, and threat_for still rises
	# strictly -- both re-derived offline against _raw_threat before the edit.
	#
	# Measured, not guessed: a playthrough on a breadth-first policy (eleven level-1
	# plants, no upgrades) lost 7 of 11 plants on this wave and was dead by wave 10.
	# See plant-tower-defense-t52o.
	[
		{"species": &"aphid", "count": 15, "gap": 0.40, "lead": 0.5},
		{"species": &"beetle", "count": 6, "gap": 1.00, "lead": 1.5},
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
	# The Shield Bug's debut (plant-tower-defense-pdri). Four of them, arriving
	# after the swarm and the column rather than mixed into either, because a new
	# species the player cannot pick out of a crowd teaches nothing — the same
	# reason wave 12 is the lightest of the late waves.
	#
	# Four is what makes the lesson land instead of merely occur: `shell_hits` is
	# 6, so four plated bugs eat 24 consecutive kernels, which is 19.2 s of a
	# level-1 cob's whole output for zero damage. One or two would read as bad
	# luck. The two beetles they cost keep the row inside its window (base health
	# must stay above wave 14's 294 and below wave 16's 319; it lands at 308).
	[
		{"species": &"aphid", "count": 20, "gap": 0.26, "lead": 0.5},
		{"species": &"beetle", "count": 13, "gap": 0.90, "lead": 1.5},
		{"species": &"shieldbug", "count": 4, "gap": 1.20, "lead": 2.0},
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
	# The long march, and the Nurse Beetle's debut (plant-tower-defense-gsai).
	#
	# 2.20 s is past every gap in the fifteen rows above it (the widest is 2.00 s,
	# for TWO beetles in wave 4) and it is chosen against the beetle's own crossing
	# time: 55.6 s to walk the road, so the fourteen gaps take 30.8 s and the
	# fifteenth beetle spawns while the first is still 55% of the way down it. The
	# column is therefore continuous rather than a queue, which is what makes this an
	# endurance wave instead of a slow one; at 40.2 s from the first spawn to the
	# last it is still by half again the longest wave in the table (the next is
	# 26.9 s).
	#
	# The Nurse is the MIDDLE group, which is the whole placement argument. Put at
	# the head she is simply the furthest-along pest and every cob in the garden
	# shoots her before the wave arrives, so the aura never happens; put last she
	# walks alone behind a road that has already emptied. Second of three, she
	# spawns as the column finishes and the swarm behind her — 78 px/s against her
	# 44 — streams past and around her, so she is inside a crowd from the moment
	# she is on the board. She is faster than the beetles ahead of her too, so she
	# closes on the tail of the column rather than falling off it.
	#
	# WHY THIS ROW. The endurance wave is the one this species makes a different
	# wave rather than a harder one. 17 asks whether the garden can hold a lane for
	# forty seconds; a Nurse in it asks whether it can hold one for forty seconds
	# while something puts back 2.0 health a second into whatever it is shooting.
	# A garden of level-1 cobs (1.25 dps each, so one loses that race outright) has
	# been getting away with breadth all campaign, and this is the row that says no.
	#
	# WHAT IT COST: -3 beetles, +1 Nurse. 48 points of base health out and 48 back
	# in, so this row prices at exactly the 339 it always did and the whole threat
	# curve from wave 1 to wave 300 is byte-for-byte unmoved. The headcount drops
	# 35 -> 33 and the peak 35 -> 33 of 40. That the wave is genuinely harder and
	# prices identically is not a bug in the numbers -- see `_raw_threat`, which
	# cannot see an aura any more than it can see the Shield Bug's plate.
	[
		{"species": &"beetle", "count": 15, "gap": 2.20, "lead": 0.5},
		{"species": &"nurse", "count": 1, "gap": 1.00, "lead": 2.0},
		{"species": &"aphid", "count": 17, "gap": 0.34, "lead": 1.5},
	],
	# The queen in the middle. She is the second group of three, which is the
	# arrangement neither wave 12 nor wave 14 uses.
	[
		{"species": &"beetle", "count": 14, "gap": 1.00, "lead": 0.5},
		{"species": &"queen", "count": 1, "gap": 1.00, "lead": 2.0},
		{"species": &"aphid", "count": 17, "gap": 0.32, "lead": 2.0},
	],
	# The battering ram — wave 17's species mix at three times the tempo, and that
	# pairing is why the Nurse Beetle is in BOTH of them rather than only in 17.
	# The two rows exist to be compared: same three species, opposite tempo, so the
	# lesson is the contrast. Putting the new boss in one of them and not the other
	# would have made them two different waves that happen to share a species list.
	#
	# 17 asks whether the garden can out-heal an aura for forty seconds; 19 asks
	# whether it can out-heal one for twelve, with everything arriving at once. The
	# answers are genuinely different plants -- sustained dps against a lane in 17,
	# a Chomp or a Dandelion landing on the Nurse herself in 19, because there is no
	# time to grind through 2.0 health a second at this tempo.
	#
	# Paid for the same way and to the same number: -3 beetles, +1 Nurse, 48 out and
	# 48 back, so the row still prices at 372. Headcount 33 -> 31, peak 33 -> 31.
	[
		{"species": &"beetle", "count": 18, "gap": 0.70, "lead": 0.5},
		{"species": &"nurse", "count": 1, "gap": 1.00, "lead": 2.0},
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
	# The Shield Bugs below do NOT threaten that — `wave_carries_boss` asks for
	# Pest.QUEEN specifically, and a plated bug is an ordinary pest.
	#
	# Three rather than the debut's four, and two beetles paid for them: the row
	# drops from 397 to 395 points of base health and still clears wave 20's 380.
	# It is genuinely harder than that number for the reason this wave exists —
	# under drought a cob's kernels arrive half as often AND bounce, so the
	# stacked failure is on one plant and the answers to it are untouched.
	[
		{"species": &"beetle", "count": 20, "gap": 0.85, "lead": 0.5},
		{"species": &"aphid", "count": 15, "gap": 0.28, "lead": 1.5},
		{"species": &"shieldbug", "count": 3, "gap": 1.30, "lead": 1.5},
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
## endless spawns no bosses, so there is nothing there to protect.
##
## Asks `Pest.is_boss`, i.e. the `boss` flag on the SPECIES row, rather than
## comparing against `Pest.QUEEN`. It compared against the queen by name until the
## Nurse Beetle landed (plant-tower-defense-gsai), and that comparison was correct
## and unextendable at the same time: a second boss would have gone on answering
## `false` here, silently, and BOTH readers of this function would have quietly
## stopped applying to half the bosses in the game -- the HUD's "a boss is coming"
## prep note, and the rule that drought never lands on a boss wave. Neither has a
## local tell. A flag on the species cannot fail that way: a boss added without one
## is a boss nobody ever claimed was one.
static func wave_carries_boss(wave: int) -> bool:
	if wave < 1 or wave > WAVES.size():
		return false
	for group: Dictionary in WAVES[wave - 1]:
		if Pest.is_boss(StringName(group["species"])):
			return true
	return false


## What a plant's firing interval is multiplied by under this weather. Drought is
## the only one that touches it; the number is 2.0 because "halves fire rate" is
## the design brief's own wording and an interval is the reciprocal of a rate.
##
## ## WHAT A DROUGHT SLOWS, decided rather than inherited (plant-tower-defense-bt5i)
##
## **A drought lengthens a repeating ATTACK interval and nothing else.** Everything that
## pays this scale reads it through `Plant.fire_interval_scale` into
## `Plant.composed_interval`, and today that is three of the NINE plants in
## `PlantCatalog`: `CornCobbler.fire_interval`, the Dandelion's per-seed cooldown off
## `Dandelion.SHOT_INTERVAL`, and `Nettle.sting_interval`. The other six are untouched,
## and until this bead that was an
## accident of which files happened to read the field rather than an answer anyone had
## given. (The bead itself said two of five, which was true of a smaller roster: Nettle
## and Aloe did not exist when it was written.) It is the answer now, and the reason is a
## different one for each of the five:
##
##   * **Chomp Flower** — a chew is a grip, not a rate of fire, and its length belongs to
##     the MEAL rather than to the plant (`Pest.chew_seconds` through
##     `ChompFlower.chew_seconds_for`). Lengthening it lengthens how long the pest is HELD
##     exactly as much as how long the flower is busy: a nerf on a thin lane and a buff on
##     a crowded one. A weather whose SIGN depends on the board is not a readable event,
##     which is the same standard `weather_for` already applies when it refuses to run
##     rain and drought over one wave.
##   * **Seed Sunflower** — its clock IS the seed economy (`Sunflower.INTERVAL`), and a
##     drought already pays `WEATHER_DROUGHT_SEED_BONUS` on every kill. Slowing seed
##     growth under the one weather that raises seed income moves two numbers against
##     each other so the total barely moves: the balance change nobody can perceive.
##   * **Sticky Sundew** — an aura has no rate to multiply. It is on, permanently, or it
##     is not there at all.
##   * **Garden Mint** — it never acts. Its output is `neighbour_interval_scale` on plants
##     the drought is ALREADY slowing, and `Plant.composed_interval` multiplies both
##     factors, so slowing the Mint too would apply one weather twice to one shot.
##   * **Salve Aloe** — it repairs between waves, where nothing is racing it, and inside a
##     fight it loses to `Pest.EAT_DPS` by design. Halving `Aloe.heal_for` costs the
##     player nothing they can feel in the first case and nothing that matters in the
##     second.
##
## This is what lets `Hud.weather_note` say "Everything shoots half as often" and be
## exactly right rather than roughly right: SHOOTS is the boundary, and that sentence is
## now the specification rather than a description of whatever the plant files happen to
## do. `test_a_drought_slows_what_the_garden_shoots_and_nothing_else` derives the affected
## set from `PlantCatalog.ids()` and the plant scripts themselves, so a ninth plant that
## starts reading `fire_interval_scale` — or a Nettle that quietly stops — fails against
## this paragraph instead of extending it in silence.
const WEATHER_DROUGHT_INTERVAL_SCALE: float = 2.0

static func fire_interval_scale_for(weather: StringName) -> float:
	return WEATHER_DROUGHT_INTERVAL_SCALE if weather == WEATHER_DROUGHT else 1.0


## What a pest killed under this weather is worth, as a multiple of its seed value
## (plant-tower-defense-4c1l).
##
## **Only drought pays.** A drought doubles the firing interval of every plant that HAS one
## — three of the nine, per the block above; a Bramble and a Mint have nothing to slow — so
## the same
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
##
## Re-opened once the 1.5 shipped and left standing: see `WEATHER_RAIN_HEAL_FRACTION`
## below for the three alternatives plant-tower-defense-kmjp refused and why.
const WEATHER_DROUGHT_SEED_BONUS: float = 1.5

static func seed_multiplier_for(weather: StringName) -> float:
	return WEATHER_DROUGHT_SEED_BONUS if weather == WEATHER_DROUGHT else 1.0


## How much of a plant's maximum health a rain wave gives back, applied once as
## the wave opens rather than trickled -- a heal the player can SEE happen is
## worth more than a slightly larger one they cannot.
##
## ## WHAT RAIN PAYS, asked again now drought pays 150% (plant-tower-defense-kmjp)
##
## The bead this answers said rain "heals pests" and was therefore the only weather with
## a downside and no compensation. **IT HEALS PLANTS.** `Game._apply_weather` walks the
## plants Game owns and calls `plant.heal(Plant.MAX_HEALTH * WEATHER_RAIN_HEAL_FRACTION)`
## on each of them; nothing anywhere applies a weather term to a pest's health, its damage
## or its speed. So rain has no downside at all -- it is the only weather in this game that
## gives without taking, and the forecast a player reads is one weather that pays for a
## cost (drought), one that gives for free (rain), and a baseline (clear).
##
## SO NOTHING HERE MOVES. All three shapes the bead offered are refused:
##
##   * **Rain pays a smaller seed bonus.** It already has a compensation, and a second one
##     makes CLEAR the punished state -- clear is eleven waves in twelve.
##   * **Drought's bonus and rain's heal shrink together.** That moves two numbers so the
##     ratio between them does not move: the balance change nobody can perceive, which is
##     the one kind this project was told not to ship.
##   * **A non-seed upside for rain** (a free replant, faster regrowth). New mechanism, and
##     the bead's own note puts any weather rebalance downstream of the blocked
##     counter-play question rather than in front of it.
##
## WHAT WAS ACTUALLY MISSING is the bead's acceptance clause and not its premise: an upside
## has to be NAMED BEFORE THE WAVE COMMITS. Rain's heal was announced by
## `Hud.weather_note`, which `Game._on_wave_started` fires through `Hud.show_weather`
## AFTER the wave has begun -- after the player has already spent. The surface they read
## while deciding is `Hud.next_wave_note`, and that function appended a bare "rain" while
## drought got "drought · pests pay 150%". The asymmetry was the whole defect and the fix
## was one clause in that function, not a number in this file.
##
## FIXED, and both halves of the sentence above are now history rather than description
## (plant-tower-defense-zhqf, which found this reading as present tense). `next_wave_note`
## appends "rain · beds mend 25%" -- `game/hud.gd:3460-3461`, derived from
## WEATHER_RAIN_HEAL_FRACTION rather than typed. And `Hud.weather_note` turned out to
## announce nothing to anybody: it is the banner's subtitle, and that banner was
## overwritten in the same call stack for its whole life, so the "after the player has
## already spent" objection understated the case -- the surface was not late, it was
## never there.
##
## Worth saying out loud, because the fraction below is what makes it matter: this heal is
## CONDITIONAL AND FREQUENTLY ZERO. A full-health garden gets nothing from rain. A player
## who can read the number three waves out can leave a chewed Corn standing instead of
## uprooting it at a refund and paying full price again -- which is a decision, and it is
## only available to someone told the number in advance.
const WEATHER_RAIN_HEAL_FRACTION: float = 0.35


## The fraction of its maximum health a plant gets back when this weather arrives.
##
## The third member of a family that had two (`fire_interval_scale_for`,
## `seed_multiplier_for`), and its absence is half of why rain read as the weather with
## nothing to say: the other two effects were functions of the weather and this one was a
## ternary inlined at its single call site, so no caller and no test could ask "what does
## THIS weather give" without knowing in advance that the answer involved rain.
##
## Pure and static, like its two siblings, so "every weather gives the player something"
## is assertable across the whole set without a board, a wave or a hand-written table of
## which weather is which.
static func heal_fraction_for(weather: StringName) -> float:
	return WEATHER_RAIN_HEAL_FRACTION if weather == WEATHER_RAIN else 0.0


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
## What endless does NOT do is bosses — neither the queen nor the Nurse Beetle.
## Both live in the fixed table only, and that is a decision rather than an
## omission: the two endless invariants worth having are that threat rises every
## single wave and that the rise is exactly one beetle's worth (see _raw_threat),
## and a boss that appears every Nth wave breaks both — the wave after a boss wave
## prices lower than the boss wave, which the readout would have to report as the
## difficulty going down. Making bosses permanent instead would need a third road
## share, and the two that exist already sum to SIMULTANEOUS_PEST_CEILING exactly.
## The second boss was weighed against exactly this paragraph and put in the
## campaign for exactly these reasons; see WAVES' header.
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
##
## **The second thing it cannot read is a MECHANIC, and those two are the one place
## it under-states a wave.** Both are bounded, both are written down here rather
## than corrected, and neither is fixable in this function, because the size of
## each depends on which plants the player owns and a fudge factor would have to
## guess the garden:
##
##   * The Shield Bug's plate. A plated bug is priced at its 10 points of health
##     like any other pest, while `shell_hits` 6 blocked hits are work a lane has
##     to do and get nothing for. Waves 15 and 21 are harder than the bar says.
##   * The Nurse Beetle's aura (plant-tower-defense-gsai). She is priced at her 48
##     points of health and nothing else, while `Pest.heal_per_second(NURSE)` puts
##     2.0 health a second back into every other pest inside 160 px of her for as
##     long as she is alive — which, against a lane of level-1 Corn Cobblers doing
##     1.25/s each, is unbounded work rather than merely extra work. Waves 17 and
##     19 are harder than the bar says, and by more than the plate costs.
##     Deliberately NOT priced by scaling her health up to compensate: that would
##     put the whole error into her own bar, where the player would read it as a
##     boss with a big health pool, which is the exact thing this species was
##     built not to be.
##
## The standard this function is held to is the paragraph above: it may over-state
## a wave, never under-state one. These are the two places it does — four rows and
## nine pests in a twenty-two wave table — and they are named rather than hidden.
##
## Note the claim in the paragraph above — "there is no way to make an endless
## wave harder that this function cannot see" — is untouched by that, and stays
## exactly true, because `_endless_groups` sends aphids and beetles only.
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
## **That reason is now half true, and the half that is not is deliberately left
## alone.** Since plant-tower-defense-iqp8 the campaign escalates on health as
## well as on the table, so waves 10-22 would all answer "tougher" if this
## function were allowed past the `wave <= WAVES.size()` guard — thirteen
## consecutive waves saying the same word, which is the noise the guard exists to
## prevent. The campaign's readout for the second act is the threat level instead,
## and it moves: across waves 9-22 it used to tick three times and now ticks four
## (levels 8, 9, 10, 11 arriving at waves 9, 11, 14 and 18 rather than 8, 9, 10 at
## waves 9, 12 and 18), and the finale reads level 11 rather than level 10.
## A wave-start line that names the ramp ONCE, at the wave it starts, is a better
## answer than either and is filed rather than guessed at here.
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


## Multiplier on a spawned pest's health for `wave`. TWO ramps, multiplied: the
## campaign's second act (SECOND_ACT_START_WAVE / CAMPAIGN_HEALTH_STEP carry the
## whole argument for it) and endless's, which now rides ON TOP of wherever the
## campaign finished instead of restarting from 1.0.
##
## It returned a flat 1.0 through the fixed table until plant-tower-defense-iqp8,
## and this is the only function that changed to give the campaign a second act.
## The `over <= 0` early return is gone rather than edited around: there is no
## longer a wave at which nothing is climbing, so a shape whose whole point was
## "campaign is untouched by construction" would now be a lie told by a control
## flow. Note that speed_scale_for keeps it, deliberately — speed feeds
## crossing_seconds, which feeds _paced_gap and peak_simultaneous_pests, so
## scaling campaign speed would move every road-budget number in the file.
## Health feeds nothing but damage, which is exactly why it is the safe lever.
##
## MULTIPLICATIVE COMPOSITION IS LOAD-BEARING, not tidiness. The seam bound
## derived at ENDLESS_BEETLE_BASE divides the first endless wave's threat by the
## finale's, so every factor common to both cancels — and with the endless ramp
## expressed as a multiple of the campaign's last value, the campaign ramp is one
## of them. The bound stays exactly 402 * 1.3469 / 1.24 = 436.7 points of base
## health and the finale keeps exactly 18.7 points of headroom under it, however
## steep the second act gets. (The 1.3469 in that product is
## `1.252 * 1.06 * 1.015`, and its 1.06 is now the seam RATIO h(23)/h(22) rather
## than h(23) itself — same number, different reading.) An ADDITIVE endless ramp
## — `campaign_top + over * ENDLESS_HEALTH_STEP` — does not cancel: at
## CAMPAIGN_HEALTH_STEP 0.03 it shrinks that headroom from 18.7 points to about
## 11 — it eats 40% of the campaign's scarcest resource, and gets steadily worse as
## the step rises (at 0.04 it took 55% of it) — and the seam test fails with a
## number no reader could trace back to a campaign health ramp.
##
## It also closes a discontinuity that was always there. The pest met on the first
## endless wave used to be x1.06 of a WAVE 1 pest, i.e. barely tougher than the
## one the finale sent; it is now x1.06 of the finale's, which is what "endless
## continues the run" was supposed to mean.
##
## Still capped at ENDLESS_HEALTH_MAX. That cap is an absolute ceiling on a pest,
## not an allowance belonging to endless, so the campaign spending part of it is
## the intent rather than a leak — see SECOND_ACT_START_WAVE for the price.
static func health_scale_for(wave: int) -> float:
	var climbed: int = clampi(wave, SECOND_ACT_START_WAVE, WAVES.size()) - SECOND_ACT_START_WAVE
	var campaign: float = pow(1.0 + CAMPAIGN_HEALTH_STEP, float(climbed))
	var over: int = wave - WAVES.size()
	if over <= 0:
		return campaign
	return minf(ENDLESS_HEALTH_MAX, campaign * (1.0 + float(over) * ENDLESS_HEALTH_STEP))


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
