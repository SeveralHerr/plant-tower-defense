class_name Game
extends Node2D

## Root of the run. Owns the board, the plants, the bugs, the money and the waves,
## and is the only place any of them are wired together.
##
## Everything below the HUD lives under `Entities`, which sits at y = BAR_HEIGHT so
## board coordinates and cell coordinates agree — a plant at cell (3, 2) is at
## board-local (224, 160) whatever the top bar does.

## The budget audit subsystem (plant-tower-defense-2dlh, the game.gd split). Loaded
## by `preload` rather than given a `class_name`, on purpose — see that file's own
## header for why. Everything Game forwards to it is at the bottom of this file,
## under "-- budgets --".
const GameBudget := preload("res://game/game_budget.gd")

## The STANDARD profile's value, and the name a test means when it says "ten beds"
## (plant-tower-defense-s1o8.3). It stayed a const when difficulty profiles landed
## precisely so the 40-odd references to it across `game/`, `test/` and `tools/` kept
## meaning what they already meant; `DIFFICULTIES` below reads it rather than restating
## it, so there is still one number and no second copy to drift.
##
## What a RUN uses is `lives`, seeded from the chosen profile in `_ready()`. Anything
## computing a proportion — "beds lost of beds" — must use `starting_lives` and not this,
## or a gentler profile reports its losses against a total it never had.
const LIVES: int = 10
## Seconds between a wave being cleared and the next one starting on its own. The
## button is still there; this stops a finished wave from stalling the run.
const PREP_SECONDS: float = 18.0
## THE DIFFICULTY PROFILES (plant-tower-defense-s1o8.3). A named bundle of the three
## run-shaping constants above, chosen once and carried across the scene swap on
## `RunConfig.difficulty` exactly the way `endless` is.
##
## The campaign was one curve for everyone: `LIVES`, `PREP_SECONDS` and
## `SeedBank.STARTING_SEEDS` were const, and the machinery to DESCRIBE difficulty already
## existed and was unreachable — `WaveDirector.threat_for` prices any wave as a multiple
## of wave 1, and `set_seed` on both the director and the bank had only test callers.
##
## STANDARD IS DERIVED, NOT RESTATED. Its three values read the constants rather than
## repeating them, so the numbers that forty-odd references across the repo already mean
## cannot drift from the profile that ships them. Change `LIVES` and standard follows.
##
## WHAT VARIES AND WHAT DOES NOT. Three of these shape how much ROOM the player has: beds
## to lose, seconds to think, seeds to open with. `seed_yield` shapes the ECONOMY, and it
## is the axis added by plant-tower-defense-i8oh. The wave curve itself is still untouched
## and still deliberately out of scope — `_raw_threat`'s own block records that the curve is
## asserted to rise strictly wave over wave out to 300, so a strength multiplier is a
## change that has to be re-verified against that property rather than added beside it.
## Filed separately.
##
## WHY THE ECONOMY, AND WHAT THE ROOM AXES COULD NOT DO. The three room axes were measured
## across a whole campaign and separated nothing (plant-tower-defense-i8oh). Under the
## shipped `RunSim.greedy_cover`, on seed 1, all three profiles were overrun on wave 7 with
## every bed spent and within 19 seeds of the same income; under `RunSim.thicken_cover` all
## three reached wave 22 having lost NOTHING and earned 5735 seeds each — the same number to
## the digit, three times. Lives cannot separate runs that lose none. Prep time cannot
## separate a policy that spends the instant the window opens. Starting seeds shift the
## first plant by part of a wave and are gone by wave 2. The one thing that was still
## deciding the run at wave 20 was whether the purse could keep buying, so that is the axis
## that was made to bind. `docs/playtest-runs.jsonl` carries both halves of that
## measurement, before and after.
##
## `seed_yield` MULTIPLIES WHAT A KILL AND A SUNFLOWER ARE WORTH, at the moment the game
## decides what they are worth and nowhere else — `_on_pest_died` and `_on_plant_grew_seeds`
## below, through `seeds_after_yield`. It is applied to the pest's value ONCE, so the husk
## that kill drops follows it without being scaled a second time. Standard is exactly 1.0,
## which is not decoration: `seeds_after_yield(n, 1.0)` returns `n` for every n, so the
## standard campaign is bit-for-bit the game it was before this axis existed, and any number
## that moved on standard is a bug rather than a rebalance.
##
## THE NUMBERS ARE DERIVED FROM THE PROFILE'S OWN OTHER AXES, not tuned. Each profile
## already takes a ratio against standard, and it is the same ratio three times over:
## gentle has 15 beds of 10 (1.5), 26 seconds of 18 (1.44) and 40 opening seeds of 25 (1.6);
## harsh has 5 of 10 (0.5), 9 of 18 (0.5) and 15 of 25 (0.6). So the yield is 1.5 and 0.5 —
## the ratio those three already agreed on. Picking a fourth independent number would have
## made the yield the one axis with no reason behind it, and
## `test_the_seed_yield_takes_the_ratio_the_other_axes_take` in `test/unit/test_playtest.gd`
## is the gate that keeps it derived.
##
## NO `blurb` KEY (plant-tower-defense-h5s3). Three per-profile sentences lived here once,
## and nothing ever read them — the title screen's picker (`TitleScreen.difficulty_label`)
## reads only `label`, and the menu has no free pixel to add a second line to: every
## header row is already at its floor (see the layout note above `TitleScreen.BUTTON_TOP`)
## and the difficulty button's own half-band cell cannot fit more than the profile's bare
## name. A key with no reader is the exact failure mode plant-tower-defense-i8oh's own
## WHAT TO WATCH named, and this table had already grown one. Deleted rather than wired up,
## because wiring it up here would mean restructuring a title screen that has no room for
## it; `test_no_difficulty_profile_carries_an_unread_key` in `test/unit/test_selftest.gd`
## pins the table to exactly the keys something reads.
##
## A difficulty that changes only the room is still a real difficulty — on `gentle` a player
## who loses four beds to a wave they misread is still in the run — but it is not one any
## measurement of this game could SEE, and a selector nothing can measure is a selector that
## drifts. This one is readable off a single run's `seeds_earned`.
##
## WHAT `seed_yield` STILL DOES NOT SEPARATE, AND WHY THAT IS A DECISION, NOT A GAP
## (plant-tower-defense-fmzu). `RunSim.POLICY_THICKEN` — the strongest built-in garden,
## used only to prove the campaign is WINNABLE at all — clears every corpus board on every
## difficulty here with full lives and seeds to spare, because its own stopping rule is
## board coverage, not the purse (`thicken_cover` in `tools/run_sim.gd` keeps buying the
## best per-seed placement until no open cell gains anything, then falls through to
## packets/upgrades — it never stops because harsh's smaller wallet ran out first). Harsh
## already earns and builds less under THICKEN than gentle does (125 vs 79 plants over the
## same 22 waves, pinned by
## `test_the_three_profiles_end_a_run_differently_and_not_only_start_it_differently` in
## `test/unit/test_playtest.gd`) — the selector is not decoration — but every corpus road's
## minimum defensible garden is cheap enough that even harsh's economy affords it early and
## banks the rest. Squeezing `seed_yield`/`lives`/`prep_seconds`/`starting_seeds` further
## cannot fix that without either a bigger minimum garden (a road/reach change, not a
## difficulty one) or a harder WAVE CURVE, and the wave curve is deliberately not one of
## these four keys — see `WaveDirector._raw_threat`'s own header for why a per-difficulty
## strength scale has to be re-verified against the whole strictly-rising threat curve
## rather than layered in here. That is real, separate, already-filed work:
## plant-tower-defense-jyaq. `docs/playtest-sweep.md` carries the full decision.
##
## THE ORDER IS THE ORDER A PICKER SHOWS. `DIFFICULTY_ORDER` exists so the title screen
## (bead 4) has one list to iterate instead of sorting a Dictionary, which in GDScript is
## insertion-ordered but not documented as a promise anyone should lean on.
const DIFFICULTY_STANDARD := &"standard"
const DIFFICULTY_GENTLE := &"gentle"
const DIFFICULTY_HARSH := &"harsh"
const DIFFICULTY_ORDER: Array[StringName] = [
	DIFFICULTY_GENTLE, DIFFICULTY_STANDARD, DIFFICULTY_HARSH,
]
const DIFFICULTIES: Dictionary = {
	DIFFICULTY_GENTLE: {
		"label": "Gentle",
		"lives": 15,
		"prep_seconds": 26.0,
		"starting_seeds": 40,
		"seed_yield": 1.5,
	},
	DIFFICULTY_STANDARD: {
		"label": "Standard",
		"lives": LIVES,
		"prep_seconds": PREP_SECONDS,
		"starting_seeds": SeedBank.STARTING_SEEDS,
		"seed_yield": 1.0,
	},
	DIFFICULTY_HARSH: {
		"label": "Harsh",
		"lives": 5,
		"prep_seconds": 9.0,
		"starting_seeds": 15,
		"seed_yield": 0.5,
	},
}


## The bundle for `name`, falling back to standard for anything unknown.
##
## FALLS BACK RATHER THAN FAILING, and that is the same rule `RunConfig`'s save reader
## follows: a value written by a later build must not take the run down. An unknown name
## here means a save or a title screen from a build that knows a profile this one does
## not, and the honest response is the designed game rather than a crash.
##
## Static and pure so the table is assertable without starting a run.
static func difficulty_profile(name: StringName) -> Dictionary:
	if DIFFICULTIES.has(name):
		return DIFFICULTIES[name]
	return DIFFICULTIES[DIFFICULTY_STANDARD]


## How long an armed Uproot stays armed before it disarms itself.
##
## Uproot is the only irreversible click in the game — it refunds 60% and frees
## the node, and a real undo would have to restore CornCobbler.level, the
## Sunflower's yield clock, the plant's remaining health and the consumed free
## starter, several of which cannot be recovered once queue_free lands. So the
## click is gated going in rather than reversed coming out. Four seconds is long
## enough to read the relabelled button and short enough that a wave arriving
## mid-decision does not leave a live trigger sitting under the cursor.
const UPROOT_CONFIRM_SECONDS: float = 4.0

## What `arm_uproot()` returns for the click that ARMED the confirm — a success, not a
## refusal, and the one value on Game that breaks the "" == it-worked convention every
## other `-> String` method here follows (plant-tower-defense-qewm).
##
## It has a name so that the twenty-one call sites asserting it stop asserting a bare
## literal, and so that `uproot_press_accepted()` below has one thing to compare against
## instead of a string repeated across four files. Do not read it as a reason: the arming
## click sets `_uproot_armed`, starts the clock, marks the bed, plays a sound and posts a
## message. Nothing was refused.
const UPROOT_CONFIRM_NEEDED := "confirm needed"
## Where the pause card's "Leave this run" goes. The game could previously only be left by
## quitting: the sole scene change in the project ran the other way, title into
## game, and R reloaded the run without ever offering the menu.
const TITLE_SCENE := "res://game/title.tscn"
## The HUD signal the top bar's speed button rings. Named because it is reached by
## STRING rather than by member access — see the connect in `_ready` for why — and
## a signal name typed twice in two files is a signal name that will be typed
## differently once. `test_the_hud_carries_the_speed_button` asserts this exact
## StringName is on Hud.
const SPEED_SIGNAL := &"speed_requested"

## Every key the run answers to, and what it does — read out of the InputMap, not
## written down here.
##
## A run had four keyboard verbs and no screen named one of them. The only mention
## anywhere was "Press M to bring it back", printed after you had already found M.
## The title screen documents its own three keys in a HintLabel, so the convention
## existed; the run simply did not follow it.
##
## This used to be a hand-written `const KEY_HELP` sitting beside the handler, with
## `test_every_key_the_run_handles_is_named_on_the_pause_card` scanning
## _unhandled_input's own source for KEY_* constants to stop the two drifting
## apart. Now the handler asks the InputMap and so does this, so there is nothing
## left to drift: rebinding pause to F1 relabels the pause card in the same frame.
## The test still runs, and now asserts that every ACTION the handler answers to
## has a row here — the same guarantee one level up.
##
## Rows are {keys, does, codes}, which is the shape PauseScreen._build_key_list
## has always drawn.
static func key_help() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for action: StringName in KeyBindings.actions_in(KeyBindings.SCOPE_RUN):
		out.append({
			"action": action,
			"keys": KeyBindings.label_for(action),
			"does": KeyBindings.describe(action),
			"codes": KeyBindings.keys_for(action),
		})
	return out


## What the HUD says when a mute is toggled. Split out because it is the one line
## of run text that has to name a key: it used to say "Press M", which becomes a
## lie the moment a player rebinds the verb. Static and pure so a test can read
## the sentence without a running game.
static func mute_message(what: String, muted: bool, action: StringName, pronoun: String = "it") -> String:
	if not muted:
		return "%s on." % what
	return "%s off. Press %s to bring %s back." % [what, KeyBindings.label_for(action), pronoun]

var board: Board
var bank: SeedBank
var director: WaveDirector
var hud: Hud
var compost: CompostMeter

## Beds left, and how many there were. `starting_lives` is not decoration: `lives_lost`
## and the post-mortem's denominator both used `LIVES` directly, which is the standard
## profile's ten, so on any other profile they would have reported a loss the player
## never took.
var lives: int = LIVES
var starting_lives: int = LIVES
## Seconds of prep this run gets, from the profile. Read in place of `PREP_SECONDS`
## everywhere the RUN is what is being timed; `PREP_SECONDS` itself stays the standard
## profile's value and the thing the comments about pacing still refer to.
var prep_seconds: float = PREP_SECONDS
## What a kill and a Sunflower are worth on this run, from the profile's `seed_yield`
## (plant-tower-defense-i8oh). 1.0 is the designed game and is standard's value, so a run
## that never reads a profile pays exactly what it always paid.
##
## A FIELD ON THE RUN rather than a read of `RunConfig.difficulty` at each payment, the same
## shape `lives` and `prep_seconds` already have. `_ready` sets all three from one profile
## lookup, which is what makes "the profile is applied first" a single statement rather than
## three places that could disagree about which run they are in.
var seed_yield: float = 1.0
## Which plant a click on empty ground would buy, or `&""` for NONE
## (plant-tower-defense-vvmy).
##
## `&""` IS A LEGAL VALUE NOW, and before this it was not reachable at all: this field was
## born holding CORN and every assignment to it named another plant, so there was no state
## in which a click on grass did not spend seeds. On a mouse that is a mild irritation. On
## a phone it is the defect that was reported — the board is the biggest target on screen,
## a stray tap is the easiest input there is, and every one of them bought something.
##
## The three ways in and out, so the rule is in one place rather than inferred from five
## call sites:
##
##   * ARMED by the plant bar (`_on_plant_chosen`) and by a packet that hands over a plant
##     the player did not have (`_on_packet_requested`).
##   * DISARMED by a placement that actually SUCCEEDED (`_commit_placement`), which is the
##     "lift to plant, then nothing is armed" half of the reported gesture. A REFUSAL does
##     not disarm: losing your pick because you were five seeds short is a second
##     punishment for one mistake, and the player's next move is to try again.
##   * DISARMED by the player saying so — right-click (`_unhandled_input`), or, because a
##     phone has no right button, a touch that ends off the board (`_on_screen_touch`).
##     That second one is not a new gesture: sliding off the board was ALREADY the touch
##     abort, and it already threw the placement away. It now throws the arm away with it.
##
## NOTHING NEEDS A `PlantCatalog.has()` GUARD ADDED FOR THIS, which was worth checking
## rather than assuming. `PlantCatalog.entry()` returns `{}` for an unknown id, so
## `on_road(&"")` is false, `reach(&"")` is 0.0 and `texture_path(&"")` is `""`; and
## `would_plant_at` already opened with `if not PlantCatalog.has(selected_plant)`, which
## is the guard that makes an empty arm refuse a purchase instead of crashing on one. The
## cue is the only thing that had to change — see `_update_preview`.
var selected_plant: StringName = PlantCatalog.CORN
var selected_placed: Plant = null
## The plant the player is comparing FROM: the selection before this one, kept on
## screen with its sole-cover rings demoted so two plants' answers to "what does this
## one alone hold?" can be read side by side (plant-tower-defense-sleq).
##
## WHAT CLEARS IT: selecting a third plant, which drops the oldest. The window is
## exactly two BY CONSTRUCTION rather than by a rule anybody has to learn, so the
## board cannot accumulate rings however long a session runs. Every `_select(null)`
## clears it too -- picking a packet out of the bar, a plant eaten under the cursor,
## an uproot committing -- because all three are moments where the question changed.
## No timer, no key, no modifier: a comparison is read at the player's pace, and a cue
## that needs a keypress to dismiss is one most players will leave up.
var _held_over: Plant = null
var game_over: bool = false
var victory: bool = false

var _entities: Node2D
var _cursor: ColorRect
## The shop entry the cursor is on, &"" for none. Decides which question the
## board's dead-ground marks answer: this plant's, or the whole garden's
## (plant-tower-defense-tzz7 / -g8kc).
var _hovered_shop_plant: StringName = &""
var _preview: PlacementPreview
## Last cell the cursor was over, or x < 0 for "off the board". Kept so the
## preview can be re-drawn on events that are not mouse motion.
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _husk_layer: HuskLayer
var _plants: Dictionary = {}

## The cross-breeding clock and its generator (`CrossBreeder`, plant-tower-defense-f21v).
##
## A generator of its own rather than a share of `WaveDirector`'s: the two mechanics
## draw at completely unrelated moments, and a single stream would mean the sports a
## garden throws depend on how many mutation rolls the waves happened to make. A seed
## that reproduces one run has to reproduce both, which is what two streams give and
## one does not.
##
## THAT LAST SENTENCE WAS FALSE FOR AS LONG AS THIS STREAM HAD NO SETTER
## (plant-tower-defense-4n66). Two streams give reproducibility only if BOTH are
## pinnable; this one was constructed here, drawn from at `_tick_cross_breeding`, and
## mentioned nowhere else in `game/`, `test/` or `devtools_ext/` -- so every run threw a
## different set of sports and no seed could pin them, while this block said otherwise.
## `set_run_seed` below is the setter that makes the paragraph true.
##
## WHAT A RUN IS SEEDED BY TODAY: nothing. There is no run seed. `set_run_seed`,
## `WaveDirector.set_seed` and `SeedBank.set_seed` have test and tool callers only --
## no code path a PLAYER takes fixes any of the three, so a live run randomizes all of
## them and a bug report still cannot be reproduced from a seed. That is a design call
## (a run seed has to be chosen, shown, and carried on `RunConfig` across the scene
## swap) and is deliberately NOT made here; this block records that it is open rather
## than implying it is settled. What is settled is that all three streams are now
## pinnable through one call, so whatever eventually fixes a run's seed has one place
## to call and cannot fix two of three by accident -- which is the failure that
## produced this bead.
var _cross_clock: float = 0.0
var _cross_rng := RandomNumberGenerator.new()
var _prep_left: float = 0.0
var _wave_live: bool = false
## Off by default: a prep countdown that hits zero waits at zero for the "Next
## wave" button rather than starting the wave itself. On, it behaves as the
## countdown always used to -- start_next_wave() fires the instant prep runs out.
##
## No HUD button and no key for it yet, and both are measured absences rather
## than oversights:
##
## - The top stats row's own headroom is 38px at the narrowest supported
##   viewport (see Hud.min_viewport_width()), and even a bare CheckButton
##   reading "Auto" needs ~106px there -- confirmed against the live control,
##   not guessed. Fitting one means shrinking an existing readout to pay for
##   it, which is a redesign this bead did not ask for.
## - KeyBindingScreen is at its own hard ceiling already: `panel_height()`'s
##   own doc comment states nine is the last verb count that fits the
##   648-tall viewport floor, and KeyBindings.ACTIONS already has nine. A
##   tenth pushes the panel's foot off the bottom of the screen with nothing
##   clamping it -- the same class of redesign as the HUD row.
##
## So today this is a session-only field a test, the devtools bridge
## (`run-method --node Game --method toggle_autostart_waves`), or a future UI
## pass can flip. RunConfig is not the right home for it either if that UI
## pass arrives: every switch OptionsScreen.OPTIONS lists is readable and
## settable from the TITLE screen, before any Game exists, and this flag
## describes a Game that may not exist yet.
var autostart_waves: bool = false
## The weather the current wave arrived under, or CLEAR between waves.
##
## Held by Game rather than read from the director on demand, because the wave
## number moves the instant a wave ends and the weather has to survive until the
## next one starts -- a plant placed in the prep gap after a drought wave must not
## inherit the drought, and one placed during it must.
var weather: StringName = WaveDirector.WEATHER_CLEAR
var _weather_overlay: WeatherOverlay = null
## The ambient bees (plant-tower-defense-qz4j). Purely aesthetic, and held here only so
## `_apply_board_layout` can keep it over the board and `_apply_weather` can tell it to
## sit out the rain -- nothing in a run reads it.
var _bees: BeeSwarm = null
var _score_recorded: bool = false

## Petals this run has earned from waves, held until `bank_score()` files them
## (plant-tower-defense-u82u).
##
## RUN-LOCAL AND ACCUMULATED, not paid out per wave, and that is one save file write per
## run instead of one per wave: `RunConfig.add_petals` writes on every change, and a
## twenty-two wave campaign would otherwise rewrite `user://highscore.save` twenty-two
## times for a number nothing reads until the run is over.
##
## Flushed inside `bank_score()` — see that function. Not persisted: an unbanked run is
## an unfinished one, and the whole point of the latch there is that a run pays once.
var _petals_earned: int = 0

## The plant an Uproot click has armed, and how long it stays armed. Held here
## rather than in the Hud because the HUD is deliberately stateless — it renders
## whatever state() hands it and keeps no second copy of the truth (see hud.gd).
## Keyed by the plant, not a bare bool, so arming one plant and then selecting
## another cannot leave a live trigger pointed at the wrong garden bed.
var _uproot_armed: Plant = null
var _uproot_left: float = 0.0

## How long after the move window lapses a click on empty ground is read as "you meant to
## move" rather than as a purchase (plant-tower-defense-b9bl).
##
## SHORT ON PURPOSE, and this is the whole tuning. The grace exists to catch the click
## already in flight when the deadline passed — a player mid-reach, whose hand was
## committed before the arc ran out. It is not a second move window: making it long turns
## every ordinary purchase near a lapsed uproot into a refusal, which trades a silent wrong
## action for a loud wrong one and is worse, because the player then cannot buy at all
## without waiting the grace out.
##
## Consumed on the first click either way, so it can never refuse twice.
const MOVE_LAPSED_GRACE_SECONDS: float = 1.5
var _move_lapsed_left: float = 0.0

## How long Board's road-answer ring stays lit after a road plant is refused on
## grass (plant-tower-defense-oxf1). Same countdown-then-clear shape as
## `_move_lapsed_left` just above: decremented in `_process()`, and the cue is
## cleared the frame it reaches zero rather than left for the next redraw to
## notice. Set from `Hud.message_seconds(Hud.ROLE_NOTICE)` rather than a new
## literal -- this cue IS a notice, in the same sense the role table already
## names, and reusing that table's number means a future retune of "how long a
## notice reads" moves this ring with it instead of leaving it stranded at
## whatever this cycle typed.
var _road_answer_left: float = 0.0

## Last health reading of the selected plant, so the panel can follow a chew.
##
## Plant has no health_changed signal and damage is applied per physics frame by
## every adjacent pest (Pest.EAT_DPS * delta), so wiring one would fire ~60x a
## second and rebuild every HUD string with it. Watching the value here refreshes
## on change only, and keeps the HUD stateless — it still holds no copy of this.
var _selected_health: float = -1.0

## What the run did, as opposed to what it lost.
##
## The post-mortem could only ever report damage — waves survived, beds lost,
## weakest ground — because these two were the numbers nobody had written down.
## _on_pest_died is the single funnel every kill routes through, and nothing in
## game/ called Time.* at all, so a run had no duration either.
var pests_defeated: int = 0
var run_seconds: float = 0.0

## Where the run's seeds actually went, as opposed to how many it earned.
##
## Cycle 101's A/B varied exactly one bit — whether a surplus bought another plant
## or another level on a plant already in the ground. Same economy, no cheats, same
## map. The breadth-first campaign reached eleven level-1 plants and died at wave
## 10; the depth-first one won all 22 waves without losing a bed. That bit is the
## single largest thing a new player gets wrong, and until these two counters
## existed the game wrote down every number about the run EXCEPT the one the run
## was decided by. `seeds_earned_total` is income; nothing recorded outgoings.
##
## SEEDS, not purchase counts. A plant and an upgrade are differently priced, so
## "11 plants, 6 upgrades" reads as a near-balance where the same run's "275 on
## plants, 90 on upgrades" reads as a policy — and seeds are what cycle 101 varied,
## so seeds are what the post-mortem should hand back. They also stay short enough
## for the card's value column at endless magnitudes, which a count-and-price pair
## does not (see RunSummary.spend_text).
##
## GROSS, not net. An uproot refund is not taken back out of `seeds_on_plants`, and
## re-planting the same cob somewhere else charges this a second time. Both are
## right for the question being asked: the player chose breadth with those seeds on
## both occasions, and a "net" number would let a player who churns plants read as
## though they had been spending on depth.
##
## Packets are a THIRD sink and are deliberately in neither total. See
## RunSummary.spend_text — the row names two destinations and never claims they add
## up to everything spent, so a packet is not silently filed under either policy.
var seeds_on_plants: int = 0
var seeds_on_upgrades: int = 0

## The post-mortem card and the layer it sits on, built once when the run ends.
var _summary: RunSummary = null
var _summary_layer: CanvasLayer = null

## The pause card and its layer, built on demand and freed on resume.
var _pause_screen: PauseScreen = null
var _pause_layer: CanvasLayer = null

## The Skins screen, over the pause layer -- see `_open_skins()` for why it rides
## on `pause_run()`'s own layer rather than building a second one
## (plant-tower-defense-ncfv).
var _skins_screen: SkinsScreen = null

## Road cell -> how many pests this wave were lost there (killed or escaped).
## Committed to the board as one batch when the wave ends; see
## Board.record_lane_pressure_wave.
var _wave_losses: Dictionary = {}
## The escaped half of _wave_losses — same cells, a subset of the counts. Kept
## as a second tally rather than as a flag on the first because the pressure map
## wants the sum and the post-mortem wants the difference, and there is no single
## number that is both. Committed in the same batch; see _commit_lane_pressure.
var _wave_escapes: Dictionary = {}

## How the run's escapes happened, as opposed to how many there were.
##
## The count has always been reported (as beds lost) and the place has always
## been recorded — but the place is a constant. Board._run_escapes documents why:
## every escape is filed against exit_cell(), because an escaped pest's own
## position is off the board by the time `escaped` fires. So two runs that lost
## the same beds left byte-identical evidence however differently they lost them.
##
## This is the one thing an escaping pest knows that the player can act on. A pest
## that reaches the exit having never been touched walked road nothing was aimed at
## — a hole in the coverage, answered by planting more. One that arrives having
## been fought was in range and the damage merely ran out, answered by upgrading
## what is already there or buying it time with a Sundew. Those are opposite
## purchases and nothing else on the card separates them.
##
## The reason, corrected against a measurement (see the coverage block below).
## This used to read "was never in range of anything the whole way down", and that
## is false: Corn shoots only the pest furthest along, so a pest can stand well
## inside a cob's ring for its whole stay on a cell and be passed over for a pest
## further down the road. Every one of the 68 untouched escapes in that sweep had
## walked covered ground at some point. What holds — and what the branch above is
## entitled to — is the weaker claim: every one of them had ALSO walked at least
## one cell nothing could aim at, and no pest that stayed inside covered ground for
## its whole walk ever came out untouched. Untouched still means a hole; it does
## not mean the pest was out of reach the whole way.
##
## `_escapes_recorded` is the denominator and is deliberately NOT `LIVES - lives`:
## an escape whose pest could not be read counts toward neither of these, so the
## card falls back to the bare bed count rather than reporting "all were fought"
## about pests it never saw. See _note_escape.
var _escapes_recorded: int = 0
var _escapes_untouched: int = 0


func _ready() -> void:
	add_to_group("game")

	# AUDIO IS WARMED HERE, IN A FRAME THAT IS ALREADY A LOADING FRAME, and that
	# placement is the whole point of the call. Both caches used to fill lazily, on
	# first use, which put a `load()` inside the frame that fires a cue -- the first
	# kill, the first volley, the first bite -- and inside the crossfade that starts a
	# run. On the Web build the engine mixes in WASM and refills its ring buffer once
	# per rendered frame (project.godot's [audio] block), so a main-thread stall is a
	# missed refill and a missed refill is crackle. `output_latency.web=140` gave a
	# long frame headroom; it gives none to a frame that has not finished decoding.
	# Ahead of `play_for_scene` so the title bed is resident before it is asked for.
	Sfx.prewarm()
	Music.prewarm()

	Music.play_for_scene(scene_file_path)

	# THE PROFILE IS APPLIED FIRST, ahead of every node this method builds
	# (plant-tower-defense-s1o8.3). `bank` reads `starting_seeds` in its own initialiser
	# and the HUD reads `lives` on the frame it is built, so a profile applied further
	# down would be a run that starts on the standard numbers and corrects itself a few
	# lines later -- visibly, on the first frame, for the seed counter.
	#
	# Read through `difficulty_profile()` rather than indexing `DIFFICULTIES`, so an
	# unknown name from a later build falls back to the designed game instead of
	# crashing here. See that function.
	var profile: Dictionary = difficulty_profile(RunConfig.difficulty)
	starting_lives = int(profile["lives"])
	lives = starting_lives
	prep_seconds = float(profile["prep_seconds"])
	# The economy axis. Ahead of the bank for the same reason `starting_seeds` is: a run
	# that paid a kill at the standard rate and corrected itself afterwards would be a
	# visible tick in the seed counter with no cause a reader of it could find.
	seed_yield = float(profile["seed_yield"])

	# The speed the player chose in their last run (plant-tower-defense-zgzc).
	# Here rather than in RunConfig._ready(), which fires at process start while the
	# TITLE screen is coming up — a saved half speed applied there would slow that
	# scene's own animations for no reason a reader of it could find, and _exit_tree
	# would throw it away on the first exit anyway. The speed is a fact about a RUN.
	# Ahead of the HUD, so the button's face is right on the frame it is built.
	RunConfig.apply_game_speed()

	bank = SeedBank.new()
	bank.name = "SeedBank"
	# Set before the node enters the tree, so nothing can observe the standard opening
	# balance and then watch it change. SeedBank.seeds is a plain field with no setter
	# and no signal, so this is a write rather than a correction.
	bank.seeds = int(profile["starting_seeds"])
	add_child(bank)

	director = WaveDirector.new()
	director.name = "WaveDirector"
	director.endless = RunConfig.endless
	add_child(director)

	compost = CompostMeter.new()
	compost.name = "CompostMeter"
	add_child(compost)

	_entities = Node2D.new()
	_entities.name = "Entities"
	_entities.position = Vector2(0, Hud.BAR_HEIGHT)
	add_child(_entities)
	# Placed properly once the board exists; see _apply_board_layout. The value above is
	# the design-size answer and is kept so nothing reads an unset position mid-_ready.

	board = Board.new()
	board.name = "Board"
	_entities.add_child(board)

	# Above the ground and below everything that stands on it. Added to Entities right
	# after the board rather than as a Board child, so husks, plants and pests all draw
	# over it in their existing order and nothing had to learn about weather.
	_weather_overlay = WeatherOverlay.new()
	_weather_overlay.name = "WeatherOverlay"
	_weather_overlay.setup(board.board_size())
	_entities.add_child(_weather_overlay)

	_husk_layer = HuskLayer.new()
	_husk_layer.name = "HuskLayer"
	_husk_layer.compost = compost
	_entities.add_child(_husk_layer)

	_cursor = ColorRect.new()
	_cursor.name = "Cursor"
	_cursor.size = Vector2(Board.CELL, Board.CELL)
	_cursor.color = Color(1, 1, 1, 0.22)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.visible = false
	_entities.add_child(_cursor)

	_preview = PlacementPreview.new()
	_preview.name = "PlacementPreview"
	_preview.visible = false
	_entities.add_child(_preview)

	# A SIBLING of Entities, not a child of it, and the difference is load-bearing.
	# Draw order inside Entities is child order, and plants are added to it all run --
	# so a bee layer parented there would sink under every plant the player builds. As a
	# sibling added after it, bees are over the whole board and under the HUD's own
	# CanvasLayer, with the ordering structural rather than maintained. It is given
	# Entities' position by _apply_board_layout, which is the only thing keeping the two
	# in the same space.
	_bees = BeeSwarm.new()
	_bees.name = "BeeSwarm"
	_bees.setup(board.board_size())
	add_child(_bees)

	hud = Hud.new()
	hud.name = "HUD"
	add_child(hud)

	bank.seeds_changed.connect(func(_total: int) -> void: _refresh())
	# The sound is generic to every refusal, from all four purchase_failed call
	# sites; the shake is not, and lands separately at each site below — see
	# _click_at and _on_packet_requested — because only they know which control
	# the player actually reached for.
	bank.purchase_failed.connect(func(reason: String) -> void:
		hud.show_message(reason)  # message-corpus-check: ok - purchase refusals are assembled by SeedBank at runtime
		Sfx.play(Sfx.PURCHASE_DENIED))
	bank.plant_unlocked.connect(_on_plant_unlocked)

	director.spawn_requested.connect(spawn_pest)
	director.wave_started.connect(_on_wave_started)
	director.wave_spawning_finished.connect(func(_n: int) -> void: _refresh())

	# Wired to the signal rather than to the click handler so every route into a
	# collected husk pays the same cue — _click_at is the only one today, but the
	# devtools verbs and the tests reach collect_at() directly.
	compost.husk_collected.connect(_on_husk_collected)
	# The silent-death case this whole sound pass exists for: a husk that rotted
	# because the player was too slow used to leave the board with no cue at all.
	compost.husk_rotted.connect(_on_husk_rotted)

	hud.plant_selected.connect(_on_plant_chosen)
	hud.plant_hovered.connect(_on_plant_hovered)
	hud.packet_requested.connect(_on_packet_requested)
	# Through a handler rather than straight onto start_next_wave(), so the
	# mutator underneath stays unguarded for the devtools verb, the prep-timer
	# expiry and the tests — the same split arm_uproot() / commit_uproot()
	# already uses. A wave that arrives because the countdown ran out is not a
	# press and must not click.
	hud.next_wave_requested.connect(_on_next_wave_requested)
	hud.upgrade_requested.connect(upgrade_selected)
	# The button goes through the confirm gate; commit_uproot() stays the unguarded
	# mutator underneath it, which is what the placement tests drive directly (and
	# what a bridge session reaches with `run-method`). No devtools VERB wraps it --
	# see its own header.
	hud.uproot_requested.connect(arm_uproot)
	hud.speed_requested.connect(_on_speed_requested)
	hud.skins_requested.connect(_open_skins)

	# The playfield's own place in the window, and it has to be re-taken whenever the window
	# changes shape — the HUD reserves a fixed-width panel on the right and a fixed-height
	# bar on top, so what is left for the board moves with the viewport.
	_apply_board_layout()
	get_viewport().size_changed.connect(_apply_board_layout)

	_prep_left = prep_seconds
	_refresh()
	# ACT, the longest band there is: this sentence is an instruction to be carried out
	# by a player who has not yet learned where the grass is or what the button does.
	# Its length is incidental — see Hud.message_seconds for why that is not the variable.
	hud.show_message("Plant your free Corn Cobbler on the grass, then grow the first wave.",
		Hud.message_seconds(Hud.ROLE_ACT))

	# Last, and deliberately here rather than a frame later: the two HUD budgets
	# read StatsRow.size and the readouts' custom_minimum_size, both of which are
	# assigned outright in Hud._build_top_bar() -- which has already run, because
	# add_child() on a node already inside the tree readies its child at once.
	# Waiting for a process frame would buy nothing and would put the warning
	# after the first thing the player sees. See the budgets section below.
	check_budgets()


## Fixes ALL THREE of this run's random streams, in the shape `WaveDirector.set_seed`
## and `SeedBank.set_seed` already use (plant-tower-defense-4n66).
##
## THE POINT IS THAT IT IS ONE CALL. The two streams that had setters were pinnable
## and the third was not, and nothing said so -- `_cross_rng`'s own block claimed the
## opposite for as long as it was true. Any caller that pins a run by reaching for
## `director.set_seed` and `bank.set_seed` reproduces exactly that bug, because it
## cannot pin a private field. This is the only place that knows how many streams a run
## has, so a fourth one is added here and every caller inherits it.
##
## ONE VALUE FOR THREE STREAMS, DELIBERATELY. The streams stay separate -- see
## `_cross_rng` for why sharing a generator would couple the sports to the mutation
## rolls -- but they are all set from the same number, so a run has one seed to quote
## rather than three. `tools/run_sim.gd` already does this by hand with its `roll_seed`;
## this is that, in the one place a Game can offer it.
##
## Safe to call after `_ready()` only: the two children do not exist before it.
## No player-facing caller today; see `_cross_rng`'s block on what that leaves open.
func set_run_seed(value: int) -> void:
	director.set_seed(value)
	bank.set_seed(value)
	_cross_rng.seed = value


func _process(delta: float) -> void:
	# Ahead of the game-over return: a run that ends while Uproot is armed must
	# still disarm, or the trigger is left live under the cursor on the results
	# screen and survives into whatever the player clicks next.
	_tick_uproot_confirm(delta)
	# Decayed here rather than inside _tick_uproot_confirm, which early-returns the moment
	# `_uproot_left` hits zero — and zero is exactly when this clock starts.
	_move_lapsed_left = maxf(0.0, _move_lapsed_left - delta)
	# Same place as the clock above and for the same reason: a run ending mid-flash must
	# still clear the ring, or it is left lit over the results screen (plant-tower-defense-oxf1).
	var road_answer_was_showing: bool = _road_answer_left > 0.0
	_road_answer_left = maxf(0.0, _road_answer_left - delta)
	if road_answer_was_showing and _road_answer_left <= 0.0:
		board.mark_road_answer([])
	_watch_selected_health()
	if game_over or victory:
		return
	# After the early return, so the clock stops the instant the run does rather
	# than counting the time the player spends reading the post-mortem.
	run_seconds += delta
	_apply_aloe_healing(delta)
	_tick_cross_breeding(delta)
	_check_wave_cleared()
	if not _wave_live and director.has_more_waves():
		# `delta` is already scaled by Engine.time_scale, so the prep countdown runs
		# at whatever GameSpeed is set to and the HUD's prep strip — which renders
		# `prep_left`/`prep_total` straight out of state() — cannot disagree with it.
		# That is the constraint the speed control had to satisfy and it is satisfied
		# by the strip never having had a clock of its own.
		#
		# Clamped at 0 rather than left to go negative: with autostart off, nothing
		# else ever moves it off 0 again, and pause_note()'s "N seconds away" reads
		# straight off this value.
		_prep_left = maxf(0.0, _prep_left - delta)
		if _prep_left <= 0.0 and autostart_waves:
			start_next_wave()


## `Engine.time_scale` is engine state and outlives every scene. A run left at 2x
## by a reload, a return to the title, or the window closing would hand its speed
## to whatever came next, with nothing in that scene's code to explain it.
##
## One caller covering every exit, rather than a `reset()` remembered at the three
## sites that leave a run — the fourth site is the one that forgets, and this is a
## defect nobody would look for in the scene they end up in.
func _exit_tree() -> void:
	GameSpeed.reset()


# -- waves ------------------------------------------------------------------


## The "Grow the next wave" button, as opposed to the wave itself.
##
## Every other HUD button already answers its own press: Upgrade rings
## PLANT_UPGRADED or the denial, Uproot rings UPROOT_ARMED, a packet either
## opens or is refused — which is why only this one and the plant bar (see
## _on_plant_chosen) get a press cue, and why a refusal stays PURCHASE_DENIED
## alone rather than becoming a click followed by a buzz.
##
## Note the bell that follows is not a later beat: start_next_wave() reaches
## WaveDirector.wave_started synchronously, so WAVE_STARTED sounds in this same
## frame. BUTTON_PRESSED is trimmed to sit under it (see Sfx.VOLUME_DB) — the
## click of the button, not a second announcement of the wave.
func _on_next_wave_requested() -> void:
	Sfx.play(Sfx.BUTTON_PRESSED)
	start_next_wave()


func start_next_wave() -> bool:
	if game_over or victory or _wave_live or not director.has_more_waves():
		return false
	director.start_next_wave()
	return true


## Puts a wave's weather onto the garden: the fire-rate multiplier onto every plant
## that exists, and rain's heal once, now.
##
## Every plant Game owns, not `get_tree().get_nodes_in_group("plants")` -- a
## tree-global group read would also collect plants belonging to a second Game in
## the same tree, which is exactly what the suite does when two scenes are hosted at
## once. See .claude/skills/godot-test-isolation.
func _apply_weather(next: StringName) -> void:
	weather = next
	apply_weather_over(_plants, next)
	# The banner is the beat and it fades; the overlay is the state and it stays for the
	# whole wave. Both from one place, so a weather that reaches the plants always reaches
	# the ground they stand on -- the failure 99ddc1e named, where the surfaces that
	# DESCRIBE a value are a separate population from the code that uses it.
	if _weather_overlay != null:
		_weather_overlay.set_weather(next)
	# And the bees, which do not fly in the rain. Told from here for the same reason as
	# the overlay: one place decides what the weather is, and everything that shows it
	# hears about it in one breath.
	if _bees != null:
		_bees.set_weather(next)
	hud.show_weather(next)


## The garden half of `_apply_weather` -- the fire-rate multiplier onto every plant in
## `plants` and rain's heal once, now (plant-tower-defense-b0mp). The banner and the
## overlay stay with the caller: those are the only part a driver with no HUD cannot do,
## which is exactly the split `RunSim`'s own header for `_apply_weather` already drew.
##
## STATIC AND CALLED FROM BOTH DRIVERS, exactly like `refresh_neighbour_buffs_over` above.
static func apply_weather_over(plants: Dictionary, next: StringName) -> void:
	# suite-reach-check: ok - extracted mirror body (plant-tower-defense-b0mp); reached at
	# runtime through `_apply_weather` on both `Game` and `RunSim`, which test_mirror_parity.gd
	# already drives (a wave's weather is applied before its first frame on both sides). A
	# direct unit test naming this symbol is left for a follow-up, as with `kill_payout` above.
	var scale: float = WaveDirector.fire_interval_scale_for(next)
	var heal: float = Plant.MAX_HEALTH * WaveDirector.heal_fraction_for(next)
	for key: Vector2i in plants:
		var plant := plants[key] as Plant
		if plant == null or not is_instance_valid(plant) or plant.is_destroyed():
			continue
		plant.fire_interval_scale = scale
		if heal > 0.0:
			plant.heal(heal)


func _on_wave_started(number: int) -> void:
	_wave_live = true
	_wave_losses = {}
	_wave_escapes = {}
	_apply_weather(WaveDirector.weather_for(number))
	Sfx.play(Sfx.WAVE_STARTED)
	# Past the fixed table, say what actually got worse. The threat level on
	# the bar answers "how much"; this answers "in what way", which is the half
	# that tells a player whether to buy damage or buy coverage.
	hud.announce_wave(number, director.current_wave_pest_count(),
		WaveDirector.escalation_note(number))
	_refresh()


## Notes one pest lost at `at` against the wave's tally. This used to be a
## per-frame scan of every live pest keeping a single high-water mark, which
## answered "how far did the worst one get" and threw away everything else —
## a wave stopped cleanly at three separate points looked identical to one
## stopped at its furthest. Every pest leaves the board through exactly one of
## the two callers below, so the events say the same thing the scan did and
## more, without looping over the group sixty times a second.
##
## `escaped` splits the tally without splitting either call site, and both halves
## still count toward the pressure map. What the flag buys is the post-mortem's
## ability to ask "how many of these did this cell actually stop", which the sum
## cannot answer: a cell that let twelve pests walk out reads identically to a
## cell that killed twelve, and the second one is the player's best turret.
func _note_lane_loss(at: Vector2, escaped: bool = false) -> void:
	if not _wave_live:
		return
	var cell: Vector2i = board.world_to_cell(at)
	_wave_losses[cell] = int(_wave_losses.get(cell, 0)) + 1
	if escaped:
		_wave_escapes[cell] = int(_wave_escapes.get(cell, 0)) + 1


## Commits this wave's whole loss tally to the board. Split out of
## _check_wave_cleared because a wave does not only end by clearing — losing
## the last life mid-wave ends it too, and _process's own `if game_over:
## return` guard means _check_wave_cleared never runs on that path (caught
## live: a wave lost to zero lives left the board's readout permanently one
## wave stale). _on_pest_escaped calls this directly the moment lives hits 0,
## before that guard ever gets a chance to skip it.
func _commit_lane_pressure() -> void:
	if _wave_losses.is_empty():
		return
	board.record_lane_pressure_wave(_wave_losses)
	# After the losses, always with them, never without: Board.stops_at subtracts
	# one from the other, so an escape batch that landed on a board which never
	# saw the matching loss batch would report negative defending.
	board.record_escapes(_wave_escapes)
	_wave_losses = {}
	_wave_escapes = {}


func _check_wave_cleared() -> void:
	if not _wave_live:
		return
	if director.is_spawning() or not get_tree().get_nodes_in_group("pests").is_empty():
		return
	_wave_live = false
	_prep_left = prep_seconds
	_commit_lane_pressure()
	# ONE PETAL PER WAVE CLEARED, and it is counted HERE rather than inside the
	# `has_more_waves()` branch below: the final campaign wave takes the `else` branch
	# straight to victory, so an award written one line down would silently pay nothing
	# for the hardest wave in the run. Accumulated rather than filed — see
	# `_petals_earned` and `bank_score()`.
	_petals_earned += 1
	if director.has_more_waves():
		# The wave that was about to attack got a banner and a bell the instant
		# it started (_on_wave_started); the wave a player just survived was
		# getting a single status-row sentence, quieter than the thing it
		# outlasted. Same weight now, on purpose (plant-tower-defense-d2a).
		Sfx.play(Sfx.WAVE_CLEARED)
		hud.announce_wave_cleared(director.current_wave, director.current_wave_pest_count())
		# After _commit_lane_pressure above, not before: prep_note() reads the
		# batch that call just posted, and running it first would describe the
		# wave before last for the whole of the window the player buys in.
		# DIGEST, the longest ambient band: this is the between-waves beat, the one moment
		# the player is reading rather than clicking, and the line carries prep_note()'s
		# whole clause. Note it outlasts far LONGER strings elsewhere — "Wave 3 cleared."
		# is fifteen characters and gets six seconds, which is the pair in
		# Hud.message_seconds that rules out deriving any of this from length.
		hud.show_message(Hud.wave_cleared_line(director.current_wave, prep_note()),
			Hud.message_seconds(Hud.ROLE_DIGEST))
	else:
		victory = true
		_end_run("The garden holds!")
	_refresh()


## The sentence the prep window opens with, past "Wave N cleared."
##
## The run-total damage reading has existed all along and was revealed exactly
## once — by Board.show_run_pressure(), from _end_run — which is to say the
## number that would inform a purchase was held back until purchasing had
## stopped. This is where it comes forward.
##
## It does NOT come forward as paint. The road already wears the per-wave map,
## and a second tint over the same cells is a blend rather than two readings
## (see Hud.prep_depth_note). It comes forward as the comparison the map cannot
## make: how deep this wave got against how deep the run has been getting.
##
## The countdown is the fallback rather than the headline. It restates the prep
## strip, which already draws the same countdown in the coming wave's threat
## colour — worth a whole line only when there is genuinely nothing else to say,
## which is a run that has not yet stopped a single pest anywhere.
##
## The coverage reading outranks the depth comparison in exactly one case, and it
## is a comparison rather than a threshold: when the wave's pests were, on
## average, stopped FURTHER down the road than the garden can reach. That is the
## wave where the hole is the explanation, and it is the only wave where a
## sentence about the hole is news rather than a standing fact restated.
##
## A mean, deliberately, because that is what last_wave_depth() is and Board.depth_of
## argues the case at length: one lucky straggler must not be able to fake it. So a
## wave killed cleanly inside the covered stretch with one escape at the exit still
## reads as a wave that went mostly right, and the line stays on the depth note.
## The coverage line arrives when leaks are the bulk of the losses, which is when
## planting deeper is genuinely the purchase to make.
##
## coverage_note() returns "" for a garden with nothing planted at all, so this
## branch cannot take the line away from the depth note on an empty board — see
## coverage_note_for() for why that silence is correct and not an oversight.
func prep_note() -> String:
	var last_wave: float = board.last_wave_depth()
	if last_wave > coverage_frontier():
		var hole: String = coverage_note()
		if hole != "":
			return hole
	var note: String = Hud.prep_depth_note(last_wave, board.run_depth())
	if note != "":
		return note
	return "Next one grows in %d seconds." % int(prep_seconds)


# -- coverage ---------------------------------------------------------------
#
# Where the garden cannot reach, DERIVED from the board and the plants standing
# on it rather than observed off the pests that walked through it.
#
# The observed version is the one that looks obvious, and it cannot work. A pest
# carries Pest._ever_engaged, which is monotone: the first kernel that lands sets
# it and nothing ever clears it. Sample that flag per road cell and every cell
# after first contact reports "the garden reached here", whatever is or is not
# standing beside it — so the observed map can only ever mark a PREFIX of the
# road, and the two holes that actually cost beds (a gap in the middle, and an
# uncovered run to the exit) are precisely the two it cannot see. It answers "how
# far down the road before something touched them", which this board already has
# a vocabulary for in Board.depth_of, and it answers it at the cost of a per-cell
# recording pass. See test_the_engagement_flag_can_only_ever_mark_a_prefix_of_the_road.
#
# The derived map has none of that. Corn's reach is a known radius from a known
# cell, so the set of road cells nothing can touch is a pure function of the board
# and the placed plants — available DURING play, correct the frame a plant is
# bought or uprooted, and free of any dependency on a pest having walked there.
#
# The two would still disagree, and the disagreement is not one-sided, which is
# what this paragraph used to get wrong. It over-promises in the obvious
# direction: a Corn shoots only the pest furthest along, a Chomp with a full mouth
# grabs nothing, a winged pest is unreachable by one at all. It ALSO under-promises,
# and that half was missed. A Kernel flies until it leaves the board
# (Kernel._physics_process) and kills the first pest it touches whether or not that
# pest was the one aimed at, so a cob's overshoot kills well past its own 176 px
# ring. Driven live: four cobs at the entry, four waves, and 7 kills landed on
# cells this map calls uncovered — (6, 1) and (3, 5), both a clean 200 px and
# 192 px from the nearest cob — against 10 escapes at the exit.
#
# So this is not a bound in either direction. It answers exactly one question and
# it answers it exactly: "is any standing plant in range of this cell". That is
# still the question worth asking, because it is the one a purchase acts on — but
# nothing built on it may be phrased as "nothing could touch them here", and
# LanePressureOverlay's mark is named `unaimed` rather than `unreachable` for that
# reason. See test_a_kernel_can_kill_on_ground_the_coverage_map_calls_unaimed.
#
# The over-promising half has now been MEASURED, and the size of it is the reason
# nothing was built on it. Fourteen driven waves over three gardens (a six-cob
# campaign garden, seven cobs covering all 32 road cells, and nine mouths), 439
# pests, sampled every physics frame:
#
#   * At the CELL, the over-promise is enormous and useless. 3,909 of 4,664 stays
#     on covered ground — 84% — passed with nothing touching the pest. But it
#     reads 66% in a wave that killed 14 of 14 and lost no bed at all, and 88% in
#     one that lost 34 of 40, so it is loud everywhere and quiet nowhere. 82% of
#     it (3,216) is a cob that fired at a DIFFERENT pest during the stay and 14%
#     (555) is one that had this pest picked and had not landed a shot yet: it
#     measures the fire rate and the targeting rule, not ground the garden cannot
#     reach. Three stays in 3,909 were the map's own geometry.
#   * At the PEST — the unit a player acts on — it is zero. 116 pests spent their
#     whole road walk inside covered ground and every one of them was touched,
#     including in runs losing half the wave. All 68 pests that got out untouched
#     had walked at least one cell this map already marks `unaimed`.
#   * The geometry is honest: all 755 answered stays had the pest genuinely inside
#     a covering plant's radius, so the centre-to-centre coverage test never once
#     claimed ground the plant could not actually hold.
#
# The one case that IS a real over-promise is a road cell covered by Chomps alone,
# because a mouth cannot close on a winged pest — and that case needs a garden
# with no Corn in it, since a 176 px ring covers everything a 73.6 px mouth does.
# ONE blind stay in the 3,747 unanswered stays across the eleven runs with Corn in
# the garden; 134 of 162 (83%) in the three chomp-only ones. Corn is the free
# starter and the only damage in the game, so the garden that case needs is a
# garden nobody has.
#
# See test_the_coverage_map_keeps_its_promise_to_a_pest_that_never_leaves_covered_ground,
# test_the_in_reach_and_idle_reading_is_just_as_loud_in_a_wave_the_garden_sweeps and
# test_a_winged_pest_only_outruns_the_map_in_a_garden_with_no_corn_in_it, which
# carries a 31-mouth positive control so the zeros above are a reading and not a
# counter that never fires.


## The plants that can lay a finger on a pest, and the whole list.
##
## Read off Pest._ever_engaged rather than off the catalogue, because those are
## the same two things: a kernel that lands, and a Chomp that holds. A Sticky
## Sundew "deals no damage whatsoever" by its own doc comment — it only slows —
## and a Sunflower never touches a pest at all.
##
## PlantCatalog.reach() answers a DIFFERENT question and answers it with a
## non-zero number for the Sundew, correctly: a patch that touches no road is as
## useless as a cob that can shoot none, and the placement cue should say so
## before the thirty seeds are spent. Usefulness is not coverage. Keeping the two
## apart is the entire reason this list is written out rather than inferred from a
## radius — a road walled in dew is road nothing can touch, and a coverage map
## built on reach() would call it defended.
##
## Listed positively, so a fifth plant reads as non-engaging until somebody says
## otherwise. That is the failure direction that over-reports a hole, and a
## readout that nags is recoverable where one promising coverage it does not have
## costs beds. test_every_plant_that_can_touch_a_pest_is_named_as_one fails when
## the catalogue grows, which is what forces the decision to be made rather than
## defaulted into.
## Kept as the name the coverage code and its tests read, but it is no longer
## the declaration — PlantCatalog.engages() is, one key beside each plant. A
## const cannot call a function, so this is a static rather than a const, and
## every caller goes through it instead of through a list two files from the
## plants it describes.
static func engaging_plants() -> Array[StringName]:
	return PlantCatalog.engaging_ids()

## The longest line the coverage branch can hand the status row, through
## Hud.wave_cleared_line. Same contract as Hud.PREP_NOTE_WORST_CASE and for the
## same reason: MessageLabel clips with an ellipsis, so a line that outgrows the
## row renders trimmed and nothing complains.
##
## The widest reachable frontier is 0.0 — a garden covering the entry cell and
## nothing else, which is not a hypothetical: a lone Chomp Flower on (0, 0) has a
## GRAB_RADIUS of 73.6 px, which reaches the road cell 64 px below it and misses
## the next one at 90.5 px. That reads "the last 100% of the road", and 100 is
## therefore the widest percentage this can print rather than the 97 that counting
## cells suggests. test_the_coverage_note_fits_the_status_row pins this string to
## the formatter and measures it against both the row and Hud's declared worst
## case, so the arithmetic above is checked rather than trusted.
##
## Grew by five characters when "covers" became "is aimed at" — see
## coverage_note_for() for why the wording had to change. The width is measured,
## not assumed, so if that spend ever stops fitting the row the test says so
## rather than the sentence quietly clipping.
const COVERAGE_NOTE_WORST_CASE: String = "Wave 9999 cleared. Nothing is aimed at the last 100% of the road."


## How far a plant of `id` can actually HURT a pest, in pixels; 0.0 for one that
## cannot hurt one at all.
##
## The damaging kinds return PlantCatalog.reach(id) rather than a second copy of
## the number, so a balance change to CornCobbler.RANGE moves this with it instead
## of leaving a coverage map quoting a radius the cob no longer has.
##
## GATED ON PlantCatalog.damages(), NOT ON engages() (plant-tower-defense-i8k9), and
## the two answer differently for exactly one plant. Every readout downstream of this
## is worded "aimed at" — coverage_note_for's "Nothing is aimed at the last N% of the
## road", Board.mark_unaimed_road, the card's `road_aimed` — and "aimed" is the
## narrower question. A Bramble already contributed nothing here, but only because a
## Bramble's reach() happens to be 0.0; a holding plant with a real reach would have
## been counted as covering road it cannot hurt anything on. This changes no number
## in today's catalogue and removes that accident. See PlantCatalog.damages() for why
## it is a derived function rather than a second key beside `engages`.
static func engagement_reach(id: StringName) -> float:
	if not PlantCatalog.damages(id):
		return 0.0
	return PlantCatalog.reach(id)


## Every road cell a pest could stand on right now with nothing in the garden able
## to touch it — the coverage-hole map, in walk order.
##
## Empty is the honest answer for a board that cannot be read, and it is also the
## answer for a perfectly covered road. The two are told apart by
## coverage_frontier(), which returns -1.0 for the first and 1.0 for the second.
func uncovered_road_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if board == null or not is_instance_valid(board):
		return out
	var covered: Dictionary = covered_road_cells()
	for cell: Vector2i in board.road_cells():
		if not covered.has(cell):
			out.append(cell)
	return out


## The other half: road cell -> true for every cell something can reach. A
## Dictionary rather than an Array because every caller here is asking `has`, and
## the union across four plants is what makes it a set in the first place.
##
## Goes through PlacementPreview.covered_road_cell_list rather than re-deriving
## the distance test, so this map and the dead-ground cue on the hover preview
## cannot disagree about which road a plant reaches. A destroyed plant is skipped:
## a hungry pest that ate the cob took its coverage off the board with it.
## `except` leaves one plant out of the answer — "what would the garden cover
## WITHOUT this one", which is what the move preview asks: what a plant would newly
## defend somewhere else is a question about the garden it is leaving behind.
##
## Default null keeps the plain reading, which is what every other caller wants.
func covered_road_cells(except: Plant = null) -> Dictionary:
	var covered: Dictionary = {}
	if board == null or not is_instance_valid(board):
		return covered
	for key: Vector2i in _plants:
		var plant := _plants[key] as Plant
		if plant == null or not is_instance_valid(plant) or plant.is_destroyed():
			continue
		if except != null and is_instance_valid(except) and plant == except:
			continue
		var reach: float = engagement_reach(plant.kind)
		if reach <= 0.0:
			continue
		for road: Vector2i in PlacementPreview.covered_road_cell_list(board, plant.cell, reach):
			covered[road] = true
	return covered


## How far down the road the garden can reach: 0.0 when only the entry cell is
## covered, 1.0 when the exit cell is, and -1.0 when nothing standing can touch
## any road at all.
##
## The road is one snake — Board.depth_of makes the argument, and PATH_CORNERS
## traces a single path from (0, 1) to (13, 7) — so "where does the garden stop
## reaching" has exactly one spatial degree of freedom and this is it. Everything
## past this point is a free walk to the exit, which is the reading a player can
## act on: plant deeper, rather than plant more.
##
## Deliberately the DEEPEST covered cell and not the covered count. A garden with
## a hole in the middle and a plant at the exit has a frontier of 1.0 and nothing
## to warn about on this reading — a pest crossing that hole is shot before it and
## shot after it. The count is what uncovered_road_cells() is for.
##
## -1.0 rather than 0.0 for "nothing covered", for the same reason Board.depth_of
## returns it: a garden that covers exactly the entry cell genuinely reads 0.0, and
## a caller that could not tell it from an empty board would describe one as the
## other.
func coverage_frontier() -> float:
	if board == null or not is_instance_valid(board):
		return -1.0
	var last: int = board.path_cell_count() - 1
	if last <= 0:
		return -1.0
	var deepest: int = -1
	for cell: Vector2i in covered_road_cells():
		deepest = maxi(deepest, board.path_index(cell))
	if deepest < 0:
		return -1.0
	return float(deepest) / float(last)


## The sentence, for the garden standing right now.
func coverage_note() -> String:
	return coverage_note_for(coverage_frontier())


## Pure: the sentence for a frontier. Split out so the worst case above can be
## pinned to the formatter rather than to a literal somebody has to remember to
## re-copy, and so every branch is assertable without a board.
##
## Silent for a frontier below 0.0, which is a garden with nothing planted that
## can fight. That is not a hole in the coverage, it is the absence of a garden,
## and the empty board says it louder than a percentage could — while a line
## claiming "the last 100% of the road" on an empty field is a statistic standing
## in for something the player can already see.
##
## Silent again at 1.0, where the garden reaches the exit cell and there is no
## tail at all, and silent for anything that rounds to a 0% tail, because a
## readout that says zero reads as a broken measurement rather than as good news.
## "Aimed at", not "covers". The word matters and the measurement says so.
## Kernel._physics_process flies until the kernel leaves the board and kills the
## first pest it touches, aimed at or not — 7 kills were measured on unaimed
## ground, at 202 px and 192 px from the nearest cob, well outside its 176 px
## ring. So "nothing covers it" is false: things die there. What is true is that
## no plant has that stretch in reach, which is still the reading a purchase acts
## on, and it is the same word the board's own mark uses (`unaimed`, never
## `unreachable`). A player told "nothing covers" over-buys cover for ground that
## is already taking kills.
static func coverage_note_for(frontier: float) -> String:
	if frontier < 0.0 or frontier >= 1.0:
		return ""
	var tail: int = int(round((1.0 - frontier) * 100.0))
	if tail <= 0:
		return ""
	return "Nothing is aimed at the last %d%% of the road." % tail


## Puts one pest on the road immediately. The wave director drives this; the
## devtools `spawn_pest` verb uses it to stage a single bug without a whole
## wave. `mutation` is &"" outside wave 8+ or for a manually staged pest.
func spawn_pest(species: StringName, mutations: Array = []) -> void:
	var pest: Pest = _new_pest(species)
	for which: StringName in mutations:
		# Return value deliberately ignored: `apply_mutation` refuses a pair that does not
		# compose, and WaveDirector already asked `Pest.mutations_compose` before rolling
		# one. A refusal here means those two disagree, which is a bug in the rule rather
		# than a case to handle at the spawn site -- and the pest is still a valid pest.
		pest.apply_mutation(which)


## One pest on the road at the entrance, wired up and scaled for the wave in
## progress. The single constructor both spawn_pest() and _spawn_brood() go
## through, so a pest that arrives because a boss burst is the same object, on
## the same route, with the same signals, as one the wave director asked for —
## the alternative is two spawn paths and a brood that quietly stops paying
## seeds or stops costing a bed.
## Which node class a species arrives as. Seven of the eight are a bare `Pest` and are
## told apart by their `SPECIES` row alone, which is the whole reason this game has one
## pest script and a table rather than eight scripts.
##
## The Cutworm is the one that could not be a table row: its body is 953 px long, so it
## has its own walk, its own drawing and its own damage zones (`game/cutworm.gd`). The
## decision lives HERE, at the single spawn funnel, rather than as a static on `Pest` —
## a base class that names its own subclass is a cycle, and GDScript resolves those at
## load time in an order nothing in this repo controls.
##
## Named rather than inlined so `test_every_species_spawns_the_node_class_it_needs` has
## something to call: a species added later that quietly comes out as a plain `Pest`
## when it needed a subclass is invisible at every other seam.
func _pest_node_for(species: StringName) -> Pest:
	if species == Pest.CUTWORM:
		return Cutworm.new()
	return Pest.new()


func _new_pest(species: StringName) -> Pest:
	var pest: Pest = _pest_node_for(species)
	_entities.add_child(pest)
	# Endless difficulty rides on the wave number, not on the endless flag —
	# both scales are 1.0 inside the fixed table, so campaign spawns and a
	# devtools-staged pest go through the identical call.
	setup_pest(pest, species, board, director.current_wave)
	pest.died.connect(_on_pest_died)
	pest.escaped.connect(_on_pest_escaped)
	# Every arrival goes through here — the director's spawns, a boss's brood and the
	# devtools verb alike — so this is the one place the bed has to be told a garden
	# stopped being empty. Sfx.set_ambience is idempotent; the second pest of a wave
	# does not restart the loop from its first footfall.
	_refresh_pest_ambience()
	return pest


## The setup pair in `_new_pest` -- `pest.setup()` and `pest.apply_wave_scaling()`
## (plant-tower-defense-b0mp). Parenting, the two signals and the ambience refresh stay
## with the caller, because those are what actually differ between `Game` (a scene tree,
## a bed to tell) and `RunSim` (a headless host, a list to append to).
##
## STATIC AND CALLED FROM BOTH DRIVERS, exactly like `brood_entries` above.
static func setup_pest(pest: Pest, species: StringName, on_board: Board, wave: int) -> void:
	# suite-reach-check: ok - extracted mirror body (plant-tower-defense-b0mp); reached at
	# runtime through `_new_pest` on both `Game` and `RunSim`, exercised by every wave
	# test_mirror_parity.gd plays (there is no pest on either side that skips this). A
	# direct unit test naming this symbol is left for a follow-up, as with `kill_payout` above.
	pest.setup(species, on_board.route())
	pest.apply_wave_scaling(
		WaveDirector.health_scale_for(wave),
		WaveDirector.speed_scale_for(wave)
	)


## How far from the death point the brood is scattered before it re-forms on the
## road. Purely legibility: three pests stacked on one pixel read as one pest,
## and the whole point of the mechanic is that the player SEES the boss become
## three things. Well inside half a cell (32 px), so every one of them is still
## on the road cell its parent died on and the lane-pressure tally, the husk
## drop and the coverage map all still file them where they actually are.
const BROOD_SPREAD: float = 14.0


## The boss mechanic: a pest whose species names a split bursts into that many
## smaller ones AT THE SPOT IT FELL rather than simply leaving the board.
##
## Hung off `died` and nothing else, which is the whole design. An escaped queen
## does NOT burst — she is already off the board and has taken her bed; three
## more aphids materialising past the exit would be a punishment with nowhere to
## walk. So the only way to see the brood is to kill her, and the only question
## the player controls is where. Kill her at the gate and the three aphids have
## the entire road left to be shot on; kill her at the last corner and they have
## seconds. That is a decision about placement that nothing else on this board
## asks for, and it is deliberately not "armoured, but more".
##
## Not spawned once the run is over: _on_pest_escaped clears the pest group the
## instant the last bed goes, and a brood arriving after that would repopulate a
## board the player has already lost and keep the wave alive behind the card.
func _spawn_brood(parent: Pest) -> void:
	if game_over or victory:
		return
	for entry: Dictionary in brood_entries(parent):
		var child: Pest = _new_pest(entry["species"])
		child.enter_road_at(entry["position"], entry["leg"])


## The geometry of `_spawn_brood` -- the whole body bar the guard (plant-tower-defense-b0mp).
## `game_over`/`victory` here and `lives <= 0` in `RunSim` are what actually differ between
## the two callers' guards, so those stay behind; everything after them -- the split
## species/count, the scatter around the death point, the leg each child re-enters on -- is
## one shared, pure function returning `[{species, position, leg}, ...]` rather than calling
## `_new_pest` itself, since THAT differs per driver (parenting, signals, ambience).
##
## STATIC, PURE, AND CALLED FROM BOTH DRIVERS, exactly like `apply_weather_over` above.
static func brood_entries(parent: Pest) -> Array[Dictionary]:
	# suite-reach-check: ok - extracted mirror body (plant-tower-defense-b0mp), reached at
	# runtime through `_spawn_brood` on both `Game` and `RunSim` whenever a boss pest dies
	# (neither of test_mirror_parity.gd's two scenarios kills a boss, so this particular
	# guard is not exercised by that gate today). A direct unit test naming this symbol is
	# left for a follow-up, as with `kill_payout` above.
	var entries: Array[Dictionary] = []
	var species: StringName = Pest.split_species(parent.species)
	var count: int = Pest.split_count(parent.species)
	if species == &"" or count <= 0:
		return entries
	var at: Vector2 = parent.position
	var leg: int = parent.route_leg()
	for i: int in range(count):
		entries.append({
			"species": species,
			"position": at + Vector2(BROOD_SPREAD, 0.0).rotated(TAU * float(i) / float(count)),
			"leg": leg,
		})
	return entries


func _on_husk_collected(value: int, at: Vector2) -> void:
	Sfx.play(Sfx.HUSK_COLLECTED)
	# `at` is board-local (Entities' own space, same as pest.position); the
	# Seeds label it is flying toward lives on Hud's CanvasLayer. to_global()
	# is the one line that crosses that gap — see SeedGlyph's own header for
	# why nothing on the board side needs more than this.
	if hud != null and is_instance_valid(hud):
		hud.fly_seed_glyph(_entities.to_global(at), value)
	_refresh()


## The cue for a husk nobody swept. No _refresh(): a rotted husk changes nothing
## the HUD reads except `husks_on_ground`, which the next frame's refresh picks
## up anyway — and a rot storm at the end of a wave must not rebuild the bar once
## per husk.
func _on_husk_rotted(_value: int) -> void:
	Sfx.play(Sfx.HUSK_ROTTED)


## A pest's seed value under the current weather, rounded and never below 1.
##
## Public and pure so the economy is assertable without killing anything, and so the
## HUD could quote it later without duplicating the arithmetic.
func weather_seed_value(base: int) -> int:
	return weather_seed_value_for(base, weather)


## The same arithmetic with the weather passed in rather than read off a running run.
##
## Split out for `RunSim`, which pays a kill without a `Game` in the tree at all. The
## instance method above delegates rather than repeating the expression, so the ONE place
## this game decides what a kill is worth stays one place — a second copy in the driver
## is exactly the drift its own header warns about.
static func weather_seed_value_for(base: int, under: StringName) -> int:
	return maxi(1, int(round(float(base) * WaveDirector.seed_multiplier_for(under))))


## `base` seeds after the difficulty's `seed_yield`, and the ONE place that arithmetic
## lives (plant-tower-defense-i8oh).
##
## STATIC, PURE, AND CALLED FROM BOTH DRIVERS, exactly like `weather_seed_value_for` above
## and for the same reason. `tools/run_sim.gd` re-derives this game's economy rather than
## calling into it — its own header says so at length and names that as the thing most
## likely to go stale — so an income rule that had a second copy in the driver would be one
## rounding decision away from a simulation that reports a run the game does not play. Two
## call sites, one function, no arithmetic to keep in step.
##
## NEVER ROUNDS A PAYMENT AWAY. `maxi(1, ...)` is the same floor `weather_seed_value_for`
## keeps: a one-seed aphid on a lean profile is worth less, and worth SOMETHING, because a
## kill that pays nothing is a kill the player cannot tell from a miss. `base <= 0` passes
## through untouched — a zero is a source that produced nothing this frame, not a payment
## to be floored up to one.
static func seeds_after_yield(base: int, scale: float) -> int:
	if base <= 0:
		return base
	return maxi(1, int(round(float(base) * scale)))


## The two arithmetic lines a kill actually pays through, in `_on_pest_died` and
## `RunSim._on_pest_died` alike (plant-tower-defense-b0mp). Both are one seed-value
## expression apart: `seeds_after_yield` then `weather_seed_value_for` for the direct
## payment, `CompostMeter.husk_value_for` off the same pre-weather `worth` for the husk —
## the ordering `_on_pest_died`'s own header insists on, so this is the ONE place either
## number can drift.
##
## STATIC, PURE, AND CALLED FROM BOTH DRIVERS: `seed_yield` and `under` (the weather) are
## passed in rather than read off a running `Game`, exactly like `weather_seed_value_for`
## and `seeds_after_yield` above — `RunSim` pays a kill with no `Game` in the tree at all.
## Returns `{"seeds": int, "husk": int}` rather than two values, so a caller cannot apply
## one and forget the other.
static func kill_payout(pest: Pest, seed_yield: float, under: StringName) -> Dictionary:
	# suite-reach-check: ok - extracted mirror body (plant-tower-defense-b0mp); reached at
	# runtime through `_on_pest_died` on both `Game` and `RunSim`, which test_mirror_parity.gd
	# already exercises and asserts the two sides' `seeds_from_kills`/husk payouts agree on.
	# A direct unit test naming this symbol, matching the `weather_seed_value_for` /
	# `seeds_after_yield` convention, is left for a follow-up -- this bead's remit was the
	# five extractions and the existing parity gate, not new tests.
	var worth: int = seeds_after_yield(pest.seed_value, seed_yield)
	return {
		"seeds": weather_seed_value_for(worth, under),
		"husk": CompostMeter.husk_value_for(worth, pest.husk_multiplier()),
	}


## How many pests are still WALKING, as opposed to how many nodes are still in the
## "pests" group. The two disagree for `Pest.DEATH_LINGER` after every kill, because a
## corpse stays in the group while it lies there — and a bed that counted corpses would
## keep the garden noisy for a third of a second after the wave was over, every wave.
##
## Public because it is the number `Sfx.should_loop_ambience` is documented to take, and
## because a devtools status provider and a test both want it without reaching into the
## group themselves.
func walking_pests() -> int:
	var walking: int = 0
	for node: Node in get_tree().get_nodes_in_group("pests"):
		var pest := node as Pest
		if pest != null and pest.is_alive():
			walking += 1
	return walking


## Tells the bed what the board looks like now. Called from the spawn funnel and from
## both ways a pest leaves, which between them are every transition the count has —
## deliberately not from `_process`, because a loop that is re-decided sixty times a
## second is a loop nothing can be asserted about.
func _refresh_pest_ambience() -> void:
	Sfx.set_ambience(walking_pests() > 0)


func _on_pest_died(pest: Pest) -> void:
	# Played here, not in Pest, on purpose: Pest._play_death() queue_frees the
	# node DEATH_LINGER seconds later, and a freed node cannot finish a sound.
	# Sfx's pool sits under the scene tree root, so nothing on the board owns it.
	# A harder kill sounds like one. The threshold is the pest's OWN price rather than a
	# list of which mutations count: husk_multiplier() is already the game's answer to "how
	# much did this cost to deal with", it multiplies across a doubly-mutated pest, and
	# reading it here means a fourth mutation is audible the day it is added without anyone
	# editing this line (plant-tower-defense-tgoc).
	Sfx.play(Sfx.kill_event_for(pest.husk_multiplier()))
	# Pest.kill() clears `_alive` BEFORE it emits `died`, so the pest being buried here
	# is already excluded from walking_pests() — the bed fades on the last kill rather
	# than DEATH_LINGER later, when the corpse finally leaves the group.
	_refresh_pest_ambience()
	pests_defeated += 1
	_note_lane_loss(pest.position)
	# Scaled by the weather this wave arrived under: a drought pays more, because it
	# cost more to get here (plant-tower-defense-4c1l). Applied to the direct seeds
	# only -- the husk below already carries husk_multiplier(), and scaling both would
	# pay the weather bonus twice for one kill.
	# THE DIFFICULTY IS APPLIED TO THE PEST'S VALUE, ONCE, and then both payments below read
	# that number (plant-tower-defense-i8oh). Scaling the seeds and the husk separately would
	# pay the profile's multiplier twice for one kill, and it would round twice — a
	# three-seed aphid on a lean profile would come out worth a different amount depending on
	# which of the two roundings you asked about. Same rule the weather bonus follows two
	# lines down: applied to the direct seeds only, because the husk already carries
	# husk_multiplier() and scaling both would pay the weather bonus twice.
	var payout: Dictionary = kill_payout(pest, seed_yield, weather)
	bank.add_seeds(int(payout["seeds"]))
	# Half again, as a husk — collectible for a bonus, or left to rot. See
	# CompostMeter: this is what makes "sweep the field" worth doing. Scaled by
	# husk_multiplier() so a harder kill (a mutation) pays out more, tying the
	# mutation and compost systems together instead of leaving them side by side.
	compost.drop_husk(pest.position, int(payout["husk"]))
	# Last, after the seeds and the husk this kill earned: the brood is the
	# consequence of the kill, not part of paying for it, and a player who kills
	# a queen at the exit should still be holding her 40 seeds while the three
	# aphids she left walk out.
	_spawn_brood(pest)


## Files what the escaping pest knew about its own walk — if there is a pest to
## ask, which there frequently is not.
##
## The guard is the whole point of splitting this out rather than reading `pest`
## inline. _on_pest_escaped is called with null by the tests that stage a losing
## run without putting bugs on the board, and an unguarded deref there would
## raise inside a test method — which aborts only that method and returns "",
## which the runner cannot tell from a pass. So the tolerance is a named,
## readable branch instead of an assumption.
##
## A null escape is counted in neither tally, not counted as "fought". An
## unobserved pest is not evidence of a pest that was engaged, and the card's
## fallback branch exists precisely so it never has to pretend otherwise.
func _note_escape(pest: Pest) -> void:
	if pest == null or not is_instance_valid(pest):
		return
	_escapes_recorded += 1
	if not pest.was_engaged():
		_escapes_untouched += 1


func _on_pest_escaped(pest: Pest) -> void:
	# Before the lives arithmetic below: losing the last bed calls _end_run in the
	# same breath, and _end_run builds the card out of summary_stats(). A read
	# filed after that point would be missing from the run that ended on it.
	_note_escape(pest)
	# An escaped pest is past the exit and off the board, so its own position
	# is not a road cell and would be dropped. Attribute it to the last cell of
	# the road instead — which is also the honest reading: that is where the
	# lane finally failed. Deliberately not conditional on `pest`; the tests
	# and the losing-escape path both call this with null, and the bed still
	# counts. _note_escape above is the only part that needs a real pest, and it
	# says so by returning rather than by guarding the whole handler.
	_note_lane_loss(board.cell_to_world(board.exit_cell()), true)
	Sfx.play(Sfx.PEST_ESCAPED)
	# An escaped pest is off the board but still in the group for this frame, and a
	# losing escape frees the whole group below — both are handled by counting again
	# at the end of the handler rather than here. See the _refresh() tail.
	lives -= 1
	if lives <= 0:
		lives = 0
		game_over = true
		_commit_lane_pressure()
		_end_run("The garden is eaten")
		get_tree().call_group("pests", "queue_free")
	_refresh_pest_ambience()
	_refresh()


## Common tail of a run, win or lose: banners the result and files the seed
## total against RunConfig's persisted high score exactly once.
func _end_run(_banner: String) -> void:
	var new_record: bool = bank_score()
	# While playing, the lane overlay shows the last wave and fades older ones,
	# which is what makes it readable in the moment and useless afterwards — by
	# the time a run ends, wave 3's disaster has decayed to nothing. Swap it for
	# the run total, accumulated unfaded all along, so the board itself answers
	# "where was my garden actually weak". The card's backdrop is translucent
	# precisely so this stays visible underneath it.
	board.show_run_pressure()
	# Idempotent: _end_run's score filing is already guarded by _score_recorded,
	# but nothing stopped it building UI twice, and both end paths can be reached
	# more than once in a frame (a losing escape also clears the pest group).
	if _summary != null and is_instance_valid(_summary):
		return
	# The run is over, so the speed the player picked for it is over too — and the
	# post-mortem card built ten lines down animates, on the same doubled clock the
	# pause card is protected from. `reset()` rather than `hold()`: there is nothing
	# left in THIS run to come back to.
	#
	# It no longer follows that a restart starts at 1x, and that clause used to be
	# here: since plant-tower-defense-zgzc the choice lives on disk, so a restart goes
	# _exit_tree -> _ready -> RunConfig.apply_game_speed() and comes back at the
	# remembered speed. The reset is still right — what it protects is the card's own
	# animation, not the next run.
	GameSpeed.reset()
	# Behind the idempotency guard rather than at the top of _end_run: both end
	# paths can be reached twice in a frame, and the run-ender is the one cue in
	# the game long enough for a doubled play to be audible as a doubled play.
	Sfx.play(Sfx.RUN_WON if victory else Sfx.RUN_LOST)
	# The run is over however it ended, so the board's traffic is over with it. Asked
	# for unconditionally rather than counted: a victory ends with pests still walking
	# (the last wave is cleared by the kill that emptied it, but a loss is not), and a
	# bed still running under the post-mortem card is the one place this would be heard
	# as a bug rather than as ambience.
	Sfx.set_ambience(false)
	# Not a scene change, so play_for_scene has nothing to key off -- the run
	# ending is the direct-override case SCENE_TRACKS' own doc comment names.
	Music.play_title()
	var stats: Dictionary = summary_stats(new_record)
	# Behind the same guard as the card, and evaluated against `stats` rather than
	# against Game, so the flags a run files and the numbers its post-mortem prints
	# are read from one snapshot and cannot disagree. `record_milestones` returns
	# only what is new, which is the one thing that stops being knowable the instant
	# it is written down.
	stats["new_milestones"] = RunConfig.record_milestones(Milestones.earned_by(stats))
	# MILESTONE_PETALS apiece, once ever, and `record_milestones` is what makes "once"
	# true: it returns only what is FRESH, so a milestone earned three runs ago is not in
	# this array and pays nothing. Granted here rather than inside RunConfig because this
	# is the one place that array is in hand — the newness exists for exactly the instant
	# after the union, which is the whole reason that function has a return value.
	var fresh_milestones: Array = stats["new_milestones"] as Array
	if not fresh_milestones.is_empty():
		RunConfig.add_petals(fresh_milestones.size() * RunConfig.MILESTONE_PETALS)
	_summary = RunSummary.build(stats)
	_summary_layer = CanvasLayer.new()
	_summary_layer.name = "SummaryLayer"
	# Above the HUD's layer 10, or the side panel draws over the card.
	_summary_layer.layer = 20
	add_child(_summary_layer)
	# Same reason as the pause card, and the run is over so there is no re-enabling:
	# the post-mortem's backdrop stops the mouse and does not touch focus, and the HUD
	# is on its own CanvasLayer where nothing else can reach it
	# (plant-tower-defense-csrc).
	if hud != null and is_instance_valid(hud):
		hud.set_active(false)
	_summary_layer.add_child(_summary)
	_summary.replay_requested.connect(func() -> void: get_tree().reload_current_scene())
	_summary.gate_requested.connect(func() -> void: get_tree().change_scene_to_file(TITLE_SCENE))


## Files the run's seed total against the high score for the mode being played,
## at most once per run.
##
## _end_run used to be the only caller of RunConfig.record_score, reached only by
## winning or by losing the last bed -- and `has_more_waves()` is unconditionally
## true in endless, so victory is unreachable there. That made dying the only way
## to bank an endless score, and then pause shipped two doors that walked out
## past it. A player who quit a long run voluntarily filed nothing, which is to
## say the run they were most likely to be proud of was the one guaranteed not to
## count.
##
## Shares _score_recorded with _end_run, so quitting and then losing, or losing
## and then quitting, still files exactly one score.
##
## IT FILES BOTH OF THE RUN'S PERSISTED REWARDS, not just the score: the seed total
## against the high score, and the petals the run earned by clearing waves
## (plant-tower-defense-u82u). Widened rather than joined by a second function, because
## the latch and the four call sites are the valuable part and a sibling call would have
## to be remembered at every one of them.
## What the pause card says about the moment it interrupted. The old text was the
## constant "The wave is waiting.", which is false between waves -- and pause can
## fire at any moment outside game-over.
func pause_note() -> String:
	if _wave_live:
		var alive: int = get_tree().get_nodes_in_group("pests").size()
		if alive > 0:
			return "%d pest(s) frozen mid-step." % alive
		return "The wave is still arriving."
	if not director.has_more_waves():
		return "Nothing left to grow."
	return "The next wave is %d seconds away." % int(ceil(_prep_left))


func bank_score() -> bool:
	if _score_recorded:
		return false
	_score_recorded = true
	# THE RUN'S PETALS GO THROUGH THE SAME LATCH, and that is why they are filed here
	# rather than beside it. This function is already the one place both end paths and
	# both pause doors reach, and it is already guarded against paying twice; a second
	# call added next to it at those four sites would be four chances to forget one, and
	# the one forgotten would be the pause door that the last fix had to add.
	if _petals_earned > 0:
		RunConfig.add_petals(_petals_earned)
		_petals_earned = 0
	return RunConfig.record_score(bank.seeds_earned_total)


## The top bar's speed button, as opposed to the speed itself.
##
## Same split as `_on_next_wave_requested` / `start_next_wave`: the press pays for
## the click cue, the mutator underneath stays unguarded for the keyboard verb, the
## tests and the bridge. A speed change that happened because somebody pressed F
## must not sound like a button.
func _on_speed_requested() -> void:
	Sfx.play(Sfx.BUTTON_PRESSED)
	cycle_speed()


## Flips the flag. The bridge's target today (`run-method --method
## toggle_autostart_waves`) -- see `autostart_waves`'s own doc comment for why
## there is no key or HUD button wired to it yet.
func toggle_autostart_waves() -> bool:
	autostart_waves = not autostart_waves
	return autostart_waves


## Advances the garden's playback speed one step and redraws the button that says
## so. Returns the speed now running, so a caller does not have to ask twice.
##
## Deliberately does NOT reset between waves. A player who asked for a faster
## garden asked about the run, not about this wave, and a control that quietly puts
## itself back every 20 seconds is one the player has to keep re-pressing — the prep
## gap, an 18-second countdown with nothing to do in it, is where fast-forward is
## wanted most. It resets on the run ENDING (`_end_run`) and on leaving the scene
## (`_exit_tree`), and parks at 1x for the pause card (`pause_run`); those are the
## three places the speed stops being about a run in progress.
func cycle_speed() -> float:
	var now: float = GameSpeed.cycle()
	# The step, not the scale: `step()` is what survives a hold and what the save
	# records. Writes only on an actual change, so a full lap of the button is one
	# write and not three — see RunConfig.store_game_speed.
	RunConfig.store_game_speed(GameSpeed.step())
	# Immediately rather than at the next state change: nothing else on the top bar
	# has to move for the button's own face to be wrong, and a speed toggle whose
	# readout lags a press is a toggle the player presses twice.
	_refresh()
	return now


## Holds the run still. The prep countdown, the wave spawner, every plant timer
## and every pest all live on the paused tree, so one flag stops all of them --
## which is the point: a hand-rolled "paused" bool would have to be checked in
## eight places and would be forgotten in the ninth.
func pause_run() -> void:
	if _pause_screen != null and is_instance_valid(_pause_screen):
		return
	_pause_screen = PauseScreen.build(pause_note(), key_help())
	_pause_layer = CanvasLayer.new()
	_pause_layer.name = "PauseLayer"
	# Above the HUD at 10 and the post-mortem at 20, so a pause is always the
	# top-most thing on screen.
	_pause_layer.layer = 30
	# The layer must keep processing too, or the Control inside it never draws
	# the frame that shows it.
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_layer)
	_pause_layer.add_child(_pause_screen)
	# The HUD is on its own CanvasLayer and is therefore nobody's child -- the pause
	# card can make its OWN buttons inert and cannot reach these. Focus does not care
	# what is drawn on top, so without this a Tab from the pause card walks onto a
	# plant button behind it (plant-tower-defense-csrc).
	if hud != null and is_instance_valid(hud):
		hud.set_active(false)
	_pause_screen.resume_requested.connect(resume_run)
	_pause_screen.restart_requested.connect(func() -> void:
		bank_score()
		get_tree().paused = false
		get_tree().reload_current_scene())
	_pause_screen.gate_requested.connect(func() -> void:
		bank_score()
		# Unpause before leaving: `paused` is a property of the tree, not of the
		# scene, so it would survive the change and freeze the title screen.
		get_tree().paused = false
		get_tree().change_scene_to_file(TITLE_SCENE))
	# THE PAUSE CARD READS AT 1x. Its fades run on the paused tree — that is the
	# whole point of the PROCESS_MODE_ALWAYS four lines up — and `Engine.time_scale`
	# scales a Tween whether or not the tree is paused, so a run held at 2x would
	# dissolve its own card in half the time it was tuned for. `hold()` parks the
	# player's choice rather than discarding it; `resume_run` puts it back.
	#
	# After the connects, before `paused = true`, so the card is built and wired at
	# the speed it will be drawn at.
	GameSpeed.hold()
	get_tree().paused = true


## Awaits the card's own fade before freeing it — see PauseScreen.play_exit.
## The tree stays paused for the whole fade: PauseScreen sets itself
## PROCESS_MODE_ALWAYS in _ready, so its tween still advances, and unpausing
## first would let the board come back to life while its own pause card is
## still dissolving on top of it.
func resume_run() -> void:
	# Before the fade, not after: the Options screen over the pause card can flip
	# the colourblind ramp, and the board behind the card is still drawn on the
	# palette it had when the run was held. Repainting here means the bars are
	# already right in the frames the card is dissolving over. Cheap and idempotent
	# on the common path where nothing changed — see repaint_for_palette.
	repaint_for_palette()
	if _pause_screen != null and is_instance_valid(_pause_screen):
		await _pause_screen.play_exit()
	# AFTER the fade, not before: play_exit() is the card's own tween and it is the
	# last thing that has to run at 1x. Restoring the player's speed here means the
	# frame the board comes back to life on is the first one that is sped up, which
	# is the frame they asked for it on.
	GameSpeed.release()
	get_tree().paused = false
	if _pause_layer != null and is_instance_valid(_pause_layer):
		_pause_layer.queue_free()
	_pause_layer = null
	_pause_screen = null
	# Live again. After the layer is gone rather than before, so there is no frame
	# where both the card and a focusable HUD are on screen.
	if hud != null and is_instance_valid(hud):
		hud.set_active(true)


## The Skins screen, over a paused run (plant-tower-defense-ncfv).
##
## Rides on `pause_run()`'s own layer rather than building a second one, and is
## added as a SIBLING of `_pause_screen` under `_pause_layer` rather than as that
## card's child the way the notebook, Keys and Options screens open over IT
## (`PauseScreen._open_notebook` etc.) -- this lane does not own `pause_screen.gd`,
## so a fourth door on that card is not available here. `OverlayScreen._ready()`
## derives what to hold inert from `get_parent()`, and the parent either way is
## something the pause card's own buttons sit under, so they still go inert
## correctly as a sibling: `interactive_under(_pause_layer, self)` walks every
## descendant of the layer except this screen's own subtree, which reaches
## `_pause_screen`'s buttons exactly as it would if they were nested one level
## deeper.
##
## The seam this costs: the plain pause card is visible for one frame behind this
## screen's own backdrop before the backdrop paints over it, where the other three
## overlays never show their card underneath at all. Accepted rather than fixed
## here, since fixing it means the fourth door on the card, in a file this lane
## does not own.
func _open_skins() -> void:
	if _skins_screen != null and is_instance_valid(_skins_screen):
		return
	pause_run()
	_skins_screen = SkinsScreen.build()
	_skins_screen.back_requested.connect(_close_skins, CONNECT_DEFERRED)
	_pause_layer.add_child(_skins_screen)


## Back to the run, not back to the pause card. Pressing Skins from the HUD never
## goes through the pause card (see `_open_skins`), so there is no card underneath
## for Back to reveal -- it means "done choosing", and resumes the run the same
## way the pause card's own Resume button does.
func _close_skins() -> void:
	if _skins_screen != null and is_instance_valid(_skins_screen):
		_skins_screen.close()
	_skins_screen = null
	resume_run()


## True while the run is held. Read by the tests; the tree's own `paused` is the
## single source of truth, so this never disagrees with it.
func is_paused() -> bool:
	return get_tree().paused


## Everything the post-mortem card reports. Split out from _end_run so a test can
## assert the numbers without building the Control, and so the panel takes a plain
## Dictionary rather than reaching into Game for each field.
func summary_stats(new_record: bool) -> Dictionary:
	var worst: Vector2i = board.worst_run_cell()
	var stopped: Vector2i = board.worst_stop_cell()
	return {
		"victory": victory,
		"endless": director.endless,
		"wave": director.current_wave,
		"wave_count": director.wave_count(),
		"threat_level": WaveDirector.threat_level(maxi(1, director.current_wave)),
		"lives_lost": starting_lives - lives,
		"starting_lives": starting_lives,
		"seeds_earned_total": bank.seeds_earned_total,
		"high_score": RunConfig.best_for(director.endless),
		"new_record": new_record,
		"compost_total": compost.total_collected,
		# The denominator. state() carries the total but not the meter, so the
		# card cannot ask how many husks were resolved without this.
		"compost_resolved": compost.total_resolved(),
		"pests_defeated": pests_defeated,
		"run_seconds": run_seconds,
		# The run's own policy, read off the run rather than recomputed from the
		# price table afterwards — a board of eleven cobs at the end says nothing
		# about what was uprooted, what a packet cost, or which cob was free.
		#
		# Always written, both of them, so `0` on the card means the run genuinely
		# spent nothing there. That is why spend_text needs no absent-value sentinel
		# where _compost_text does: an unrecorded denominator and a perfect sweep
		# read the same, but an unrecorded spend and a spend of nothing do not.
		"seeds_on_plants": seeds_on_plants,
		"seeds_on_upgrades": seeds_on_upgrades,
		# The peak of the painted map, kept because the map is painted from it and
		# the two must agree about which cell is reddest. Not what the card's row
		# names — see below, and Board.worst_stop_cell.
		"worst_cell": worst,
		"worst_cell_losses": int(board.run_losses().get(worst, 0)),
		# The cell that stopped the most pests for good, and how many. Escapes are
		# already reported, as beds lost, one row above; counting them a second
		# time here is what let the exit cell win a row headed "weakest ground"
		# and point the player at ground that was never defended in the first place.
		"stop_cell": stopped,
		"stop_cell_stops": board.stops_at(stopped),
		# How the beds went, not just how many. Both are 0 for a run whose escapes
		# carried no pest to read, and RunSummary.beds_text treats that as "no
		# evidence" rather than as "every one of them was fought".
		"escapes_recorded": _escapes_recorded,
		"escapes_untouched": _escapes_untouched,
		# The coverage half of "covered is not engaged", read off the same derived
		# map the hover cue and the lane overlay use rather than recomputed, so the
		# card cannot disagree with the board about which ground was aimed at.
		# RunSummary.reach_note_text() is silent without both of these
		# (plant-tower-defense-b7v5).
		"road_aimed": covered_road_cells().size(),
		"road_cells": board.road_cells().size(),
	}


# -- placement --------------------------------------------------------------


## Picking a plant out of the bar. The other press with nothing of its own: a
## selection pays nothing and places nothing, so until PLANT_PLACED rings on the
## board — several seconds and one aimed click later — the bar answered a click
## with silence. This is the only route in; there is no keyboard shortcut for
## selecting a plant, so the cue cannot fall out of step with a second path.
func _on_plant_chosen(id: StringName) -> void:
	Sfx.play(Sfx.PLANT_CHOSEN)
	selected_plant = id
	_offer_road_hint()
	_select(null)
	# Picking a different plant while the cursor sits still must re-draw the
	# ring: switching from a Chomp to a Corn triples the coverage, and a hover
	# cue that only updates on mouse motion would show the old plant's reach
	# until the player happened to move.
	if _hover_cell.x >= 0:
		_update_preview(_hover_cell, board.is_buildable_for(_hover_cell, selected_plant) and not _plants.has(_hover_cell))
	_refresh()


## Single point of truth for `selected_placed` — flips the range-ring/selection
## flag on the outgoing and incoming plant so exactly one plant ever shows it.

## The board's dead-ground marks, repushed. One question at a time: with a shop
## entry hovered the board answers about THAT plant (tzz7); with nothing hovered it
## answers about the garden the player already owns (g8kc). Never both, which is why
## board_dead_cells() returns one list rather than two -- two locks stacked on one
## cell is a smear, and before plant-tower-defense-uqer it was worse than that: two
## marks on that angle WAS PlacementPreview's redundant-patch cue, so an overlap
## did not read as clutter, it read as a different sentence.
func _refresh_dead_ground() -> void:
	if board == null or not is_instance_valid(board):
		return
	var dead: Array[Vector2i] = PlacementPreview.board_dead_cells(
		board, _hovered_shop_plant, bank.unlocked)
	board.mark_dead_ground(
		dead,
		PlacementPreview.dead_lock_points(),
		PlacementPreview.board_dead_color(),
		PlacementPreview.DEAD_BAR_WIDTH)
	_offer_dead_ground_hint(dead)


## The one-shot that names the bar on the grass (plant-tower-defense-rr02), offered
## the first time it is drawn for a plant the player is actually considering.
##
## THE HOVER IS THE GATE, and it is the whole decision in this function. There is no
## count that makes this cue informative — because these bars are on the board from
## the opening screen. The
## header above says why: with nothing hovered, `board_dead_cells` answers about the
## garden's unlocks (g8kc), which resolves to the LONGEST reach the player owns. So an
## ungated hint would fire at a board the player has done nothing to, and would teach
## "some grass is far from the road" — true, unactionable, and forgotten by the time it
## matters.
##
## With a packet hovered the same marks answer about THAT plant (tzz7), and they move
## under the player's hand: hovering a short-reaching plant darkens grass a Corn
## Cobbler leaves clear. That is the moment the mark is about a decision in progress
## and the counter-play in the sentence — one bed closer — is a thing they can do next
## click. A gate derived from what the cue MEANS at each call site, not a threshold.
##
## THE SHARPER VERSION, considered and not taken: fire only when the hovered set is
## strictly larger than the ambient one, i.e. only when hovering REVEALED bars. It is
## a better moment and it costs a second `dead_ground_cells` sweep over every
## buildable cell on a path that runs on each shop hover. It is also dead early on:
## with one plant unlocked the ambient set IS that plant's set, so the refinement
## would never fire for the player who most needs the sentence.
##
## Spent on `show_message`'s RETURN VALUE, as `_offer_road_hint` is: a line the row
## drops must leave the hint owed rather than burning it unseen.
##
## `row_is_quiet()` before offering, because this caller is LEVEL-triggered. A hovered packet keeps its dead
## set for as long as the cursor rests there and `_refresh()` re-enters here on every
## seed payout, so a refused post is re-offered and re-offered until the row's queue
## starts dropping. That was measured once already, at `refused=11`.
func _offer_dead_ground_hint(dead: Array[Vector2i]) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	if dead.is_empty() or _hovered_shop_plant == &"":
		return
	if RunConfig.has_milestone(RunConfig.HINT_DEAD_GROUND):
		return
	if not hud.row_is_quiet():
		return
	var posted: bool = hud.show_message(Hud.dead_ground_tip())
	RunConfig.spend_hint(RunConfig.HINT_DEAD_GROUND, posted)


## Applied straight away rather than left for the next _refresh(), for the reason
## Hud._on_packet_hover spells out: a mouse crossing a button changes no state, so
## waiting for a refresh would light the board only when something else happens to
## happen, which is indistinguishable from a bug.
func _on_plant_hovered(id: StringName) -> void:
	if id == _hovered_shop_plant:
		return
	_hovered_shop_plant = id
	_refresh_dead_ground()

func _select(plant: Plant) -> void:
	var previous: Plant = selected_placed
	if selected_placed != null and is_instance_valid(selected_placed):
		selected_placed.set_selected(false)
	# Changing selection cancels a pending Uproot. Keying the arming to the plant
	# would already stop it firing on the wrong one, but leaving it armed means
	# clicking back to the first plant re-enters a live window the player has
	# stopped thinking about.
	if plant != _uproot_armed:
		_disarm_uproot()
	selected_placed = plant
	if selected_placed != null:
		selected_placed.set_selected(true)
	# AFTER the assignment, because _apply_held_over asks whether a plant is the live
	# selection before it hides anything. Exactly one previous selection is kept, and
	# only when the selection actually moved to ANOTHER plant: re-clicking the plant
	# already selected must not drop the one it is being compared against.
	if plant == null:
		_hold_over(null)
	elif previous != null and previous != plant:
		_hold_over(previous)



## Moves the held-over slot, which holds exactly one plant. Idempotent.
func _hold_over(plant: Plant) -> void:
	if _held_over == plant:
		return
	_apply_held_over(_held_over, false)
	_held_over = plant
	_apply_held_over(_held_over, true)


## Turns the demoted look on or off on one plant's two cue nodes.
##
## The marker is reached by node name for the reason `_push_uproot_clock` spells out:
## `SelectionMarker.NODE_NAME` is documented as exactly this contract. A plant built
## outside a Game has neither node, which is a silent no-op here as it is there.
##
## `live` guards the hiding half. A held plant RE-selected passes through here with
## `held = false` on the same frame it becomes the selection, and emptying its marks
## then would blank the rings the player just clicked for.
func _apply_held_over(plant: Plant, held: bool) -> void:
	if plant == null or not is_instance_valid(plant):
		return
	var live: bool = plant == selected_placed
	var marker := plant.get_node_or_null(
		NodePath(SelectionMarker.NODE_NAME)) as SelectionMarker
	if marker != null:
		marker.set_held_over(held)
		marker.visible = held or live


func plant_at(cell: Vector2i) -> Plant:
	return _plants.get(cell, null) as Plant


## Would a click on `cell` right now actually put the selected plant into the
## ground? Exactly the question place_plant() answers with "", minus the paying:
## a predicate rather than a trial call, because place_plant() charges the bank
## and neither a hover cue nor a precedence test may spend the player's seeds to
## find out what it would have said.
##
## It exists because it has two callers, and they are the two halves of one
## promise. _update_preview draws the encouraging green brackets on it, and
## _click_at hands it the click ahead of the compost sweep — so the ring is a
## promise rather than a hint: if the preview shows a plant going in, the click
## plants it. See _click_at for the rest of that rule.
func would_plant_at(cell: Vector2i) -> bool:
	if game_over or victory:
		return false
	if not PlantCatalog.has(selected_plant):
		return false
	# is_buildable_FOR, not is_buildable: since the Barrier Bramble the answer depends on
	# which plant is selected, and this predicate's whole contract is that it says exactly
	# what place_plant() would say. The two calls have to move together or the green
	# brackets start promising a plant the click then refuses.
	if not board.is_buildable_for(cell, selected_plant):
		return false
	if _plants.has(cell):
		return false
	# can_afford folds in both the lock and the free starter, which is the whole
	# money question — the same call _update_preview used to make on its own.
	return bank.can_afford(selected_plant)


## The cell a dragging finger is aiming at: the one it is over, or the nearest one that
## would actually take the plant (plant-tower-defense-bmis). Board-local `at`.
##
## THE ONE FUNCTION BOTH THE CUE AND THE COMMIT ASK, which is the whole of why it is a
## function and not two loops. `_update_cursor` draws the preview at whatever this
## returns and `_click_at` plants at whatever this returns, from the same position, so
## the ghost cannot promise a cell the release then declines to use. Two independent
## implementations of "nearest placeable" that agreed on the day they were written is
## precisely the shape of bug the preview's own promise ("if you see the brackets, the
## click plants it") exists to rule out.
##
## FALLS BACK TO THE RAW CELL, never to nothing. A finger over a road cell with no legal
## neighbour in reach still gets the red brackets on the cell it is actually over, which
## is the honest answer — the alternative is a cue that vanishes whenever the snap fails
## and a player who cannot tell "you may not build here" from "the game stopped
## responding".
##
## `would_plant_at` is the filter, not `is_buildable_for`: a cell the player cannot AFFORD
## is not a cell to drag them onto, and neither is one that already holds a plant. This is
## the same predicate `_click_at` consults, so a snap target is by construction a cell the
## click will accept.
##
## Only the eight neighbours are searched, and `TOUCH_SNAP_RADIUS` is what makes that
## complete rather than arbitrary: the nearest point of any cell two away is 96 px and the
## radius is 72, so a ring-2 candidate could never win. That relationship is pinned by
## test_the_snap_radius_cannot_reach_past_the_ring_it_searches — widen the radius past 96
## and the test fails rather than the search quietly going half-blind.
func snapped_placement_cell(at: Vector2) -> Vector2i:
	var raw: Vector2i = board.world_to_cell(at)
	if would_plant_at(raw):
		return raw
	var best: Vector2i = raw
	var best_distance: float = TOUCH_SNAP_RADIUS
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var candidate := Vector2i(raw.x + dx, raw.y + dy)
			if candidate == raw or not board.is_inside(candidate):
				continue
			if not would_plant_at(candidate):
				continue
			var distance: float = at.distance_to(board.cell_to_world(candidate))
			# Strictly nearer, so a tie goes to the first candidate in this fixed
			# scan order and the same finger position always resolves to the same cell.
			if distance < best_distance:
				best_distance = distance
				best = candidate
	return best


## The refusals a player can be SHOWN, as named constants (plant-tower-defense-n4cx).
##
## Two of these are returned from BOTH `place_plant` and `commit_move`, and until cycle 168
## each site wrote its own copy with a comment at `commit_move` claiming they were "the same
## refusal text". They were, and nothing enforced it -- rewording one in cycle 168 broke the
## claim in the same edit that read the comment saying it held. A const cannot drift.
const REFUSAL_ON_GRASS := "pests walk there — try the grass"
const REFUSAL_ON_ROAD := "this one goes ON the road"


## Every refusal string in this file, for the message row's width budget to price.
##
## THE REASON THIS EXISTS is a gap that stayed open for the life of the refusals:
## `test_no_message_clips_for_any_plant_in_the_catalogue` sweeps `Hud.message_corpus()`,
## and refusals are not in it -- `message_corpus_check` waives the `show_message` call site
## because these are assembled at runtime, and says in its own NOT COVERED line that it
## "cannot see a message built at runtime from data (a refusal string...)". So the one class
## of message the player sees at their most stuck was the one class no width gate priced,
## and cycle 168 lengthened two of them without any gate that could have objected.
##
## Not every entry here is reachable today -- "off the garden" is guarded out by `_click_at`
## and "not paid for" shakes the plant button instead of printing. They are priced anyway:
## a refusal that becomes reachable later should not have to remember to be measured.
static func refusal_corpus() -> Array[String]:
	return [
		REFUSAL_ON_GRASS,
		REFUSAL_ON_ROAD,
		"the run is over",
		"off the garden",
		"something is already growing there",
		"not paid for",
		"nothing is selected",
		"arm the move first",
		"it is already there",
		"that is not ground it can take",
	]


## The ONE plant that could stand on `cell`, or `&""` when the answer is not one
## (plant-tower-defense-lyj5).
##
## WHAT THIS IS FOR. A wrong-ground refusal tells the player their plant does not go here.
## Sometimes the game also knows exactly what DOES, and can point at it instead of leaving
## them to read the sentence, look back at the bar and work it out.
##
## THE TWO DIRECTIONS ARE NOT SYMMETRIC, and that asymmetry is why this returns a single
## id rather than a list. `Board.is_buildable_for` gives a road plant `is_path(cell)` and
## everything else `is_buildable(cell)`, so:
##
##   a ROAD cell   -- exactly one plant in the catalogue is legal, the Bramble. One packet
##                    to point at, and this is the confusing case: the player clicked the
##                    road, which is where the pests are, which feels like where a defence
##                    belongs.
##   a GRASS cell  -- eight of the nine are legal. There is no single packet, and flashing
##                    eight is noise. The honest cue there is about the ROAD, not about a
##                    packet, and it is deliberately not built here.
##
## DERIVED FROM THE CATALOGUE, never from the Bramble's name. A second road plant makes
## the answer ambiguous and this returns `&""` on the same day it is added, rather than
## going on pointing at whichever one was hard-coded.
##
## Says nothing about affordability or unlocks on purpose: "which plant goes here" is a
## fact about the ground, and a player who cannot afford the answer still needs to know
## what the answer is. The packet tooltip already explains a locked plant.
func sole_legal_plant_for(cell: Vector2i) -> StringName:
	var found: StringName = &""
	for id: StringName in PlantCatalog.ids():
		if not board.is_buildable_for(cell, id):
			continue
		if found != &"":
			return &""
		found = id
	return found


## Places `id` on `cell`, charging the bank. Returns "" on success, or the reason
## it refused — the devtools verbs and the tests both read that string.
func place_plant(id: StringName, cell: Vector2i) -> String:
	if game_over or victory:
		return "the run is over"
	if not PlantCatalog.has(id):
		return "no such plant: %s" % id
	if not board.is_buildable_for(cell, id):
		# Three reasons now, not two, and the new one is the road plant's mirror image.
		# "Pests walk there" is exactly wrong for a Bramble — pests walking there is the
		# entire point — so a road plant refused on grass gets its own sentence. The order
		# matters: off-board is checked through is_inside first, because a road plant
		# clicked outside the garden is off the garden and not "no pests walk there".
		if not board.is_inside(cell):
			return "off the garden"
		# BOTH NAME THE VERB since cycle 168's tip audit (plant-tower-defense-n4cx).
		# They used to read "no pests walk there" and "pests walk there" -- facts about
		# the cell, with nothing the player could do in them, and the first one reads as
		# GOOD news out of context. A refusal is the one message where naming the action
		# matters most, because the player has just been stopped and is looking for what
		# to do instead.
		if PlantCatalog.on_road(id):
			return REFUSAL_ON_ROAD
		return REFUSAL_ON_GRASS
	if _plants.has(cell):
		return "something is already growing there"
	# Priced BEFORE the charge, and this order is load-bearing: pay_for_plant()
	# clears `free_starter_available` on the way through, so asking the bank what
	# this cost after it had been paid for would bill the one free cob at full
	# price. Read first, charge, then bank the number the charge actually used.
	var price: int = bank.placement_cost(id)
	if not bank.pay_for_plant(id):
		return "not paid for"
	# The free starter really does add 0, which is the truth: a run that planted
	# nothing but its free cob spent nothing on breadth.
	seeds_on_plants += price
	var plant: Plant = _install_plant(id, cell, false)
	Sfx.play(Sfx.PLANT_PLACED)
	_select(plant)
	_refresh()
	return ""


## Builds a plant, puts it on the board and wires everything Game owns about it.
##
## Extracted from `place_plant` when the sports arrived (plant-tower-defense-f21v),
## and the extraction is the point rather than a tidy-up: there are now TWO ways a
## plant reaches this board, and every one of the five wirings below — the destroyed
## signal, the two duck-typed ones, the weather scale, the plant dictionary — is a
## thing a second planting path would have had to remember. Four of the five are
## silent when forgotten. A sport that never connected `destroyed` would leave a
## ghost in `_plants` at the cell it died on, and nothing would report it.
##
## `sport` is set BEFORE `setup()` because `Plant._build_visuals` reads it — see
## `Plant.is_sport`. That ordering is the one thing about this function a caller
## could get wrong, and it is why the flag is a parameter here rather than something
## the caller assigns afterwards.
##
## Charges nothing and selects nothing. Both belong to the caller: a purchase pays
## and takes the selection, a sport does neither.
func _install_plant(id: StringName, cell: Vector2i, sport: bool) -> Plant:
	var plant: Plant = new_plant(id)
	plant.is_sport = sport
	_entities.add_child(plant)
	plant.setup(id, cell, board)
	_plants[cell] = plant
	plant.destroyed.connect(_on_plant_destroyed)
	if plant.has_signal("grew_seeds"):
		# Bound here rather than added to Sunflower's own signal. What a plant
		# knows about its payout is the amount; where on the board that happened
		# is the plant itself, which Game already has in hand — the same split as
		# `destroyed(plant)`, where the handler reads `plant.cell` off the subject
		# instead of the signal carrying a copy of it. It also keeps the
		# duck-typed contract above at one argument, so a future economy plant
		# only has to emit a number to be wired up.
		plant.connect("grew_seeds", _on_plant_grew_seeds.bind(plant))
	# Duck-typed for the same reason as `grew_seeds` above: only ChompFlower declines a
	# pest for flying, and a second plant that ever does gets wired by declaring the
	# signal rather than by editing this list.
	if plant.has_signal("flight_ignored"):
		plant.connect("flight_ignored", _on_flight_ignored)
	# A plant bought DURING a drought wave inherits it. Without this the way to beat
	# a drought would be to plant into it, which is the opposite of what the weather
	# is for -- and it would only ever be discovered by a player who tried it.
	plant.fire_interval_scale = WaveDirector.fire_interval_scale_for(weather)
	return plant


## -- the garden throws a sport (plant-tower-defense-f21v) --------------------
##
## Two plants of a kind standing side by side sometimes produce a third, mutated,
## in an empty cell beside them. The whole RULE lives in `CrossBreeder`, which is
## pure; what lives here is the clock, the planting and the sentence the player
## reads. See that class for why the split is where it is.
##
## Drawn from `_cross_rng` -- a stream of its own, NOT the one the waves use; see that
## field's block for why, and for what `set_run_seed` does and does not guarantee.
## Ticked out of `_process` AFTER the game-over return, so a finished run does not keep
## growing plants under the post-mortem card.
func _tick_cross_breeding(delta: float) -> void:
	_cross_clock += delta
	if _cross_clock < CrossBreeder.TICK_SECONDS:
		return
	# Subtracted rather than zeroed, so a frame that overshoots does not quietly
	# lengthen the interval — the same reason `Sunflower._act` subtracts its own.
	_cross_clock -= CrossBreeder.TICK_SECONDS
	var sprout: Dictionary = CrossBreeder.roll(_plants, board, _cross_rng)
	if sprout.is_empty():
		return
	# The refusal is dropped on purpose HERE and only here: `CrossBreeder.open_cells`
	# has already filtered to legal empty cells, so this call cannot be refused, and a
	# handler for a branch that cannot be taken is a branch nothing will ever maintain.
	# The refusal exists for the OTHER callers -- the bridge and the tests, which pass
	# any cell at all.
	_sprout_sport(sprout["kind"] as StringName, sprout["cell"] as Vector2i)


## Plants a sport. The one planting path in this game that never touches `SeedBank`.
##
## Returns "" on success or the reason it refused, in the same shape `place_plant` uses,
## because it is reachable from the same two places `place_plant` is -- a test and the
## devtools bridge -- and a planting verb that silently succeeds at an illegal cell is
## how a cob ended up standing in the road during live verification.
##
## Does NOT select it, and that is deliberate rather than an omission: a sport can
## arrive at any moment, including while the player is reading the panel for a plant
## they are about to upgrade, and stealing the selection would make a gift into an
## interruption. The message row says where it happened; the mark on the plant says
## which one it is.
##
## `Sfx.SEEDS_GROWN` rather than `PLANT_PLACED`, reusing the Sunflower's payout cue:
## both are the garden handing the player something they did not spend on, and this
## board's audio vocabulary already spells that with one sound. A press cue here
## would say the player did it.
func _sprout_sport(kind: StringName, cell: Vector2i) -> String:
	# THE GUARD, and it is not belt-and-braces. `CrossBreeder.open_cells` already only
	# ever offers a legal empty cell, so the roll cannot reach this — but this function
	# is also the sprout's only ENTRY POINT, and it was reachable from the devtools
	# bridge and from a test with any cell at all. Driven that way it planted a cob in
	# the middle of the road, where a plant is not merely wrong but standing in the lane
	# the pests walk down.
	#
	# `is_buildable_for` and not `is_buildable`: a Barrier Bramble belongs ON the road
	# (`PlantCatalog.on_road`) and every other kind beside it, which is the same
	# question `place_plant` asks and the reason there is one function that answers it.
	if not PlantCatalog.has(kind):
		return "no such plant: %s" % kind
	if board == null or not board.is_buildable_for(cell, kind):
		return REFUSAL_ON_ROAD if PlantCatalog.on_road(kind) else REFUSAL_ON_GRASS
	if _plants.has(cell):
		return "something is already growing there"
	var plant: Plant = _install_plant(kind, cell, true)
	Sfx.play(Sfx.SEEDS_GROWN)
	if hud == null or not is_instance_valid(hud):
		# The headless suite drives a Game with no HUD (see `_refresh`'s own note on
		# the same guard). A sport still arrives; only the sentence about it does not.
		_refresh()
		return ""
	hud.show_message(Hud.sport_message(plant.display_name(), PlantMutation.note(kind)),
		Hud.message_seconds(Hud.ROLE_NOTICE))
	_refresh()
	return ""


## A Chomp is being walked past by something it cannot catch, and until now said so with
## nothing at all. One sentence, once ever.
##
## The hint is spent on `show_message`'s RETURN VALUE, not on this handler running. That
## is the whole point of the two-door contract: the row drops a line when its queue is
## full and the new entry is the lowest priority, so "I called show_message" and "the
## player read it" are different facts. A dropped line leaves the hint owed, and the next
## winged pest to cross a Chomp's reach is a fresh edge that offers it again.
##
## MESSAGE_NORMAL, not a deadline: nothing is counting down. The player has as long as
## the wave to act on it, and a higher priority would let a one-shot tutorial line stomp
## a lives-lost readout.
## Told once, the first time the player has a road plant selected by any route
## (plant-tower-defense-lven).
##
## ON SELECTION rather than on the first refusal, and the refusal is why. `_click_at`
## already answers a misplaced road plant with "No pests walk there." — so the confused
## moment is not silent, and what the player is missing is not feedback but the POSITIVE
## instruction: where it does go. A hint that fires after the mistake would be the second
## thing they read about it.
##
## The other three hints fire on an EVENT the player caused and did not understand (a flier
## crossed a mouth, an uproot was armed). This one has no such event, because the mistake it
## prevents is a click the player will not make: they learned the road is unbuildable and
## will not try. Selection is the last moment before that, and it is guaranteed — nothing
## can be planted without being selected.
##
## Spent on `show_message`'s RETURN VALUE, exactly as `_on_flight_ignored` is: the row drops
## a line when its queue is full, "I called show_message" and "the player read it" are
## different facts, and a dropped line leaves the hint owed for the next selection.
func _offer_road_hint() -> void:
	if not PlantCatalog.on_road(selected_plant):
		return
	if RunConfig.has_milestone(RunConfig.HINT_ROAD_PLANTS):
		return
	var posted: bool = hud.show_message(
		Hud.road_plant_tip(PlantCatalog.display_name(selected_plant)))
	RunConfig.spend_hint(RunConfig.HINT_ROAD_PLANTS, posted)


func _on_flight_ignored() -> void:
	if RunConfig.has_milestone(RunConfig.HINT_CHOMP_IGNORES_FLIGHT):
		return
	var posted: bool = hud.show_message(Hud.flight_tip())
	RunConfig.spend_hint(RunConfig.HINT_CHOMP_IGNORES_FLIGHT, posted)


## The cheapest plant on the board the player could upgrade right now, or null when
## nothing there has a rung left to climb.
##
## Static and taking the collection, rather than reading `_plants` itself, because
## everything interesting about it is decidable with no tree, no HUD and no bank —
## see `.claude/skills/extract-a-testable-seam`. `_maybe_teach_upgrading` below is
## the one line that supplies the argument.
##
## `can_upgrade()` and not `has_upgrades()`: the second is true of a Corn Cobbler
## sitting at the top of its ladder, which is a plant the player cannot spend a seed
## on. Asking the wrong one of those two would fire this hint at somebody whose only
## upgradable plant is already finished, which is the one case where the advice is
## actively wrong.
static func cheapest_upgrade(plants: Array) -> Plant:
	var best: Plant = null
	for entry: Variant in plants:
		var plant := entry as Plant
		if plant == null or not is_instance_valid(plant) or plant.is_destroyed():
			continue
		if not plant.can_upgrade():
			continue
		if best == null or plant.upgrade_cost() < best.upgrade_cost():
			best = plant
	return best


## Teaches, once ever, that a plant already in the ground can be upgraded.
##
## WHY THIS FIRES ON A BANK BALANCE AND NOT ON A TIMER OR AT STARTUP: cycle 101's A/B
## showed upgrading decides the run, and the bead that filed it (-gz53) asked for the
## prompt to be tied to a state where the advice is ACTIONABLE. That state is exactly
## "the player is holding at least what the cheapest upgrade on their own board
## costs" — before it, the tip is a rule they cannot use; at it, it is a decision
## they can make this second. A hint fired at a moment the player cannot act on it is
## worse than none, because it spends the message row AND the attention (-qoil).
##
## Called from `_refresh`, which is the funnel every purchase, uproot, plant death
## and wave change already runs through — so the moment the balance crosses is
## caught wherever it happens, rather than in the four call sites that can move it.
## The `has_milestone` guard is first and returns before the sweep, so the cost after
## the hint has been seen once, forever, is one dictionary lookup.
##
## Spent on `show_message`'s RETURN, like the flight tip: the row drops a line when
## its queue is full, and "I called show_message" is not "the player read it". A
## dropped line leaves the hint owed and the next refresh offers it again.
func _maybe_teach_upgrading() -> void:
	if hud == null or not is_instance_valid(hud):
		return
	if RunConfig.has_milestone(RunConfig.HINT_UPGRADE_EXISTS):
		return
	# Ask before offering. This caller is LEVEL-triggered — affordability stays true
	# once it becomes true — so a refused post is not a one-off here the way it is for
	# the flight tip: the next refresh would offer it again and stack a second copy
	# into the row's queue. See Hud.row_is_quiet, which exists for this.
	if not hud.row_is_quiet():
		return
	var cheapest: Plant = cheapest_upgrade(_plants.values())
	if cheapest == null or bank.seeds < cheapest.upgrade_cost():
		return
	var posted: bool = hud.show_message(
		Hud.upgrade_tip(PlantCatalog.display_name(cheapest.kind), cheapest.upgrade_cost()))
	RunConfig.spend_hint(RunConfig.HINT_UPGRADE_EXISTS, posted)


## The id -> class table, as a function. Static and public since `RunSim` builds a garden
## with no `Game` in the tree: a driver holding its own copy of this match would keep
## planting Corn the day a tenth plant is added, and the run it reported would be a run of
## a game nobody can play.
static func new_plant(id: StringName) -> Plant:
	match id:
		PlantCatalog.CHOMP:
			return ChompFlower.new()
		PlantCatalog.SUNFLOWER:
			return Sunflower.new()
		PlantCatalog.SUNDEW:
			return StickySundew.new()
		PlantCatalog.DANDELION:
			return Dandelion.new()
		PlantCatalog.MINT:
			return Mint.new()
		PlantCatalog.NETTLE:
			return Nettle.new()
		PlantCatalog.ALOE:
			return Aloe.new()
		PlantCatalog.BRAMBLE:
			return Bramble.new()
		_:
			return CornCobbler.new()


## A hungry pest (Pest.is_hungry) ate this plant down to 0 health instead of
## walking past it. No refund — see commit_uproot() for the "sold on
## purpose" path, which is the only one that pays anything back.
func _on_plant_destroyed(plant: Plant) -> void:
	if _plants.get(plant.cell) == plant:
		_plants.erase(plant.cell)
	if selected_placed == plant:
		_select(null)
	Sfx.play(Sfx.PLANT_DESTROYED)
	# NOTICE: a plant died during a wave, when the player's attention is on the road
	# rather than the row. Longer than a confirmation because nothing else on screen
	# says WHICH plant went — the sprite is simply gone.
	hud.show_message(Hud.destroyed_message(plant.kind),  # message-corpus-check: ok - destroyed_message is a one-line dispatcher over eaten_message/chewed_through_message; BOTH are priced for every plant in message_corpus(), which is wider than this call site can reach
		Hud.message_seconds(Hud.ROLE_NOTICE))
	plant.play_exit_and_free()
	_refresh()


## A Sunflower's payout, given the same two channels a swept husk already had
## (see _on_husk_collected): a cue, and a glyph that carries the number from the
## thing that produced it to the readout it lands in. Without them the only sign
## a Sunflower had ever earned its cell was the Seeds counter quietly ticking up
## at the top of the screen, six seconds' walk away from the flower.
##
## `plant` is bound at connect time, not emitted — see place_plant. Its
## `position` is board-local (Entities' own space, same as a husk's), so the one
## to_global() crossing into the HUD's canvas is the same line, for the same
## reason, as the husk's.
func _on_plant_grew_seeds(amount: int, plant: Plant) -> void:
	Sfx.play(Sfx.SEEDS_GROWN)
	# The profile's yield, on the second of the three income sources
	# (plant-tower-defense-i8oh). The GLYPH reads the same number the bank did, deliberately:
	# a flower that flies a 5 and banks a 3 is a readout the player will trust over the
	# counter, and then stop trusting either.
	var paid: int = seeds_after_yield(amount, seed_yield)
	bank.add_seeds(paid)
	if hud != null and is_instance_valid(hud) and is_instance_valid(plant):
		hud.fly_seed_glyph(_entities.to_global(plant.position), paid)


func upgrade_selected() -> String:
	# Asks the plant whether it grows, rather than asking whether it is a cob.
	# `has_upgrades()` is a non-empty ladder; it is a separate question from
	# `upgrade_cost() == 0`, which is also what the TOP of a real ladder costs.
	var plant: Plant = selected_placed
	if plant == null or not is_instance_valid(plant) or not plant.has_upgrades():
		return "nothing upgradeable is selected"
	if plant.is_max_level():
		return "already fully grown"
	var price: int = plant.upgrade_cost()
	if bank.seeds < price:
		hud.show_message("That upgrade costs %d seeds." % price)
		# This refusal never touches bank.pay() (that's `bank.seeds < price`
		# above, checked directly), so it never reaches purchase_failed and its
		# shared Sfx.PURCHASE_DENIED — this is the one denial site that has to
		# play the cue itself, same as it shakes the button itself.
		hud.shake_upgrade_button()
		Sfx.play(Sfx.PURCHASE_DENIED)
		return "not enough seeds"
	bank.add_seeds(-price)
	# BELOW the refusal, not beside it. Every early return above this line is a
	# purchase that did not happen — "nothing upgradeable is selected", "already
	# fully grown", and the `bank.seeds < price` denial that shakes the button —
	# and a counter incremented at the top of this method would credit the player
	# with depth for the clicks that bought nothing. This is the only line in the
	# game that charges for a level, so it is the only line that may count one.
	seeds_on_upgrades += price
	plant.upgrade()
	hud.show_message(Hud.upgrade_message(PlantCatalog.display_name(plant.kind), plant.level_name()))
	_refresh()
	return ""


## What the Uproot button is wired to. The first click arms; a second click on
## the same plant within UPROOT_CONFIRM_SECONDS commits.
##
## Three returns, and only ONE of them is a refusal (plant-tower-defense-qewm):
##
## * `""` — the second click. The plant was uprooted. Success, and the value this
##   class's convention reserves for success.
## * `UPROOT_CONFIRM_NEEDED` — the first click. The confirm was ARMED: `_uproot_armed`
##   is set, the four-second clock is running, the bed is marked, a sound played and a
##   message posted. Also a success. This is the one place on Game where a non-empty
##   return does not mean "it did not happen", which is why it is a named constant and
##   why `uproot_press_accepted()` exists to state it in code rather than in prose.
## * `"nothing is selected"` — the only genuine refusal. Nothing happened.
##
## The wording here used to call the arming click "a refusal the caller can distinguish
## from a real failure". A test call site duly labelled it "the first click refuses",
## and a later cycle, reading the convention rather than this method, wrote a
## reproduction asserting `""` for the arming click — which failed on its own
## precondition and looked exactly like the bug it was written for. A caller that only
## wants "was the press taken" must ask `uproot_press_accepted()` and compare no strings.
##
## **`arm_` and `commit_`, and the names were `request_uproot` / `uproot_selected`
## until a caller guessed wrong** (plant-tower-defense-mim5). Neither old name carried
## the destructive word: "request" sounds like the safe one and is, "selected" names
## the SUBJECT rather than the ACTION, and the pair reads as a verb and a noun rather
## than as two steps. Writing a test for the arming half, I called `uproot_selected`,
## it removed the bed with no confirmation, and it returned "" — which is this API's
## success value. Nothing failed; a plant was simply gone.
##
## The rule the rename follows: **when two functions differ in destructiveness, the
## names must differ in the destructive word.** `arm_` is a promise that nothing
## happens yet; `commit_` is a promise that it does.
func arm_uproot() -> String:
	if selected_placed == null or not is_instance_valid(selected_placed):
		return "nothing is selected"
	# No `and _uproot_left > 0.0` here, and _update_preview lost the same half for the
	# same reason (plant-tower-defense-iljz). `selected_placed` is non-null by the guard
	# above, so `_uproot_armed == selected_placed` already says something is armed — and
	# `_disarm_uproot()` is the ONE place the arming is cleared and it clears the
	# reference and the clock together, so an open window is exactly a non-null
	# `_uproot_armed`. A second condition that cannot disagree is dead code wearing a
	# safety belt, which is a shape this repo has now paid for twice.
	# test_the_uproot_window_leaves_nothing_armed_behind_it pins the invariant at
	# runtime; test_the_uproot_clock_is_never_written_without_the_arming pins that no
	# future writer can move one without the other.
	if _uproot_armed == selected_placed:
		_disarm_uproot()
		return commit_uproot()
	_uproot_armed = selected_placed
	_uproot_left = UPROOT_CONFIRM_SECONDS
	# The bed itself says so, not only the message row (plant-tower-defense-rtgp).
	_uproot_armed.set_uproot_armed(true)
	# And how LONG it says so for (plant-tower-defense-fjqp). Pushed on the arming frame
	# rather than left to the first tick: the arc has to appear as a full circle the
	# instant it appears, or its own first frame reads as time already spent.
	_push_uproot_clock()
	Sfx.play(Sfx.UPROOT_ARMED)
	# IMPORTANT: this is an instruction with a live 4-second trigger behind it, and
	# an ambient husk pickup used to wipe it mid-read.
	# The move-preview tip rides along the FIRST time an uproot is ever armed, and
	# never again (plant-tower-defense-23fa). It costs 185 px of this row's headroom
	# and teaches something once; paying that on every uproot forever was the wrong
	# trade, and a hint that appears once is more likely to be read than one that
	# has become wallpaper.
	#
	# Recorded before the message rather than after: record_milestones() is
	# idempotent and only writes when something is new, so the order cannot
	# double-write — and arming twice in a frame is a thing this method already
	# guards against above.
	# Every plant answers what it has spent climbing its own ladder; a plant with no
	# ladder answers 0. This used to be `as CornCobbler`, which was correct only
	# while corn was the sole upgradable plant -- the Chomp Flower now forfeits too,
	# and its full climb (70) is dearer than the cob's (65).
	var forfeited: int = selected_placed.upgrade_spent()
	var first_arm: bool = not RunConfig.has_milestone(RunConfig.HINT_MOVE_PREVIEW)
	# Spend the one-shot only when the tip is going to be SHOWN. `Hud.uproot_shows_tip`
	# owns that decision because the message composer needs it too, and a rule stated in
	# two files is a rule that drifts — which it did for one cycle, in exactly this spot.
	#
	# The answer now goes THROUGH `spend_hint` rather than gating a call beside it: the
	# old shape was an `if` around `record_milestones`, and an `if` is something the next
	# hint's author can simply not write. `shown` is an argument, so they cannot.
	RunConfig.spend_hint(RunConfig.HINT_MOVE_PREVIEW,
		Hud.uproot_shows_tip(first_arm, forfeited))
	# DEADLINE, not IMPORTANT: `_uproot_left` is already counting down by the time
	# this line is posted, so a deferral here does not postpone the message, it
	# eats the window it describes. See Hud.MESSAGE_DEADLINE.
	#
	# AND ITS DURATION IS AN OVERRIDE, not a band from `Hud.message_seconds`. Four
	# seconds here is not a reading time, it is UPROOT_CONFIRM_SECONDS — the window
	# `_tick_uproot_confirm` is counting down as this prints. The prompt has to last
	# exactly as long as the thing it describes: shorter and the player believes the
	# window lapsed while it is still open, longer and they confirm into nothing. This
	# is the call site that must NOT move when the ambient bands are retuned.
	hud.show_message(
		Hud.uproot_armed_message(PlantCatalog.display_name(selected_placed.kind), first_arm,
			forfeited),
		UPROOT_CONFIRM_SECONDS, Hud.MESSAGE_DEADLINE)
	_refresh()
	return UPROOT_CONFIRM_NEEDED


## Which `arm_uproot()` returns mean the press was TAKEN, as code rather than as a
## sentence in a doc comment (plant-tower-defense-qewm).
##
## Static and pure on purpose: the ambiguity this answers is a property of the three
## return values and of nothing else, so pinning it needs no Game instance, no scene,
## no selected plant and no clock — which is the whole reason the convention was
## uncheckable before. `arm_uproot()` cannot drift away from it without this failing.
##
## Deliberately NOT `not reply.is_empty()`-shaped: adding a fourth return value that is
## a real refusal must make this answer false without anyone remembering to come here,
## and the only way to get that is to enumerate the successes rather than the failures.
static func uproot_press_accepted(reply: String) -> bool:
	return reply == "" or reply == UPROOT_CONFIRM_NEEDED


## True while a second Uproot click would commit. Read by the HUD to relabel the
## button, and by the tests.
##
## `_uproot_left > 0.0` is deliberately NOT a third term (plant-tower-defense-iljz):
## it can never disagree with the first. The null check IS load-bearing and stays —
## with nothing selected and nothing armed the two nulls compare EQUAL, and without it
## this would answer true for a button that must read "Uproot".
func uproot_armed() -> bool:
	return _uproot_armed != null and _uproot_armed == selected_placed


## Refreshes the panel when — and only when — the selected plant's health moves.
func _watch_selected_health() -> void:
	if selected_placed == null or not is_instance_valid(selected_placed):
		_selected_health = -1.0
		return
	if is_equal_approx(selected_placed.health, _selected_health):
		return
	_selected_health = selected_placed.health
	_refresh()


## The ONE place the arming is cleared, which is why the marker is put back here
## rather than at each caller. Every exit runs through it: confirming, the timer
## expiring, selecting something else, and the armed plant being eaten mid-decision --
## and that last one is why the validity check is not optional.
func _disarm_uproot() -> void:
	if _uproot_armed != null and is_instance_valid(_uproot_armed):
		_uproot_armed.set_uproot_armed(false)
	_uproot_armed = null
	_uproot_left = 0.0


func _tick_uproot_confirm(delta: float) -> void:
	if _uproot_left <= 0.0:
		return
	# A plant that was eaten mid-decision takes its arming with it, rather than
	# leaving a freed instance armed for a cell something else can be planted on.
	if _uproot_armed == null or not is_instance_valid(_uproot_armed):
		_disarm_uproot()
		_refresh()
		return
	# THE CLOCK DOES NOT RUN WHILE THE PLAYER IS VISIBLY DECIDING
	# (plant-tower-defense-b9bl). Arming means two things since the move shipped: "are you
	# sure" — a destructive confirm, which wants to be SHORT — and "choose a destination",
	# which wants to be LONG, because the move tip asks the player to hover and compare.
	# UPROOT_CONFIRM_SECONDS was tuned for the first and cycle 143 handed it the second.
	#
	# Holding while the pointer sits on a legal destination resolves that without weakening
	# the confirm: the window only outlives four seconds while the player is demonstrably
	# mid-decision, and it resumes the instant they look away. The arc stops unwinding,
	# which is honest — the deadline really has stopped.
	#
	# `_push_uproot_clock()` still runs at the bottom, so the marker keeps being told the
	# same value rather than being left with a stale one.
	if not can_move_to(_uproot_armed, _hover_cell):
		_uproot_left -= delta
	if _uproot_left <= 0.0:
		# The window lapsed with a plant still armed, which is exactly the state a player
		# is in when they hesitate over a destination. The next click on empty ground is
		# far more likely to be the move they were composing than a purchase they suddenly
		# decided on, so `_click_at` gets a short grace to refuse it out loud instead of
		# silently buying a second plant.
		_move_lapsed_left = MOVE_LAPSED_GRACE_SECONDS
		_disarm_uproot()
		# CONFIRM: the arc on the marker has already finished unwinding and the plant has
		# visibly stopped being armed, so this line is a receipt for something the board
		# already showed. The shortest band, and still comfortably over
		# Hud.MESSAGE_MIN_READABLE.
		hud.show_message("Uproot cancelled.", Hud.message_seconds(Hud.ROLE_CONFIRM))
		_refresh()
		return
	# Every surviving frame, and only here. The branch above hands the close-out to
	# _disarm_uproot(), which zeroes the drawn arc through Plant.set_uproot_armed —
	# so this line must not run after it, or a cleared clock is pushed straight back
	# onto a marker that has just finished putting itself away.
	_push_uproot_clock()


## Hands the open window to the armed plant's `SelectionMarker`, which is what draws it
## (plant-tower-defense-fjqp). Game owns the clock; the marker owns the paint.
##
## `_uproot_left` is read here and in `_tick_uproot_confirm` and nowhere else, and the
## marker counts nothing of its own — so the arc a player watches close and the timer
## that actually decides whether the next click destroys a bed are the same number.
##
## Reached by node name rather than through a `Plant` accessor because
## `SelectionMarker.NODE_NAME` is exactly the contract that exists for this: it is the
## path `test_selftest.gd` and the devtools bridge already look the marker up by, and it
## is documented as a contract on the constant itself. A plant built outside a Game has
## no marker, which is a silent no-op here for the same reason it is one in
## `Plant.set_uproot_armed`.
func _push_uproot_clock() -> void:
	if _uproot_armed == null or not is_instance_valid(_uproot_armed):
		return
	var marker := _uproot_armed.get_node_or_null(
		NodePath(SelectionMarker.NODE_NAME)) as SelectionMarker
	if marker == null:
		return
	marker.set_uproot_window(_uproot_left, UPROOT_CONFIRM_SECONDS)


## The unguarded mutator: removes the selected plant and pays the refund with **no
## confirmation and no undo**. The button never reaches this directly — it is wired to
## `arm_uproot`, which gates it behind the four-second confirm — but the devtools
## verbs and the placement tests call it deliberately, because a test that has to
## arm-and-wait to remove a plant is testing the timer rather than the removal.
##
## Named `commit_` for the reason `arm_uproot`'s header spells out: this is the one
## that destroys, and its name has to say so to anyone reading a call site.
func commit_uproot() -> String:
	if selected_placed == null or not is_instance_valid(selected_placed):
		return "nothing is selected"
	var plant: Plant = selected_placed
	_plants.erase(plant.cell)
	bank.refund(plant.uproot_refund())
	Sfx.play(Sfx.PLANT_UPROOTED)
	plant.play_exit_and_free()
	_select(null)
	_refresh()
	return ""


## Move the armed plant to `cell`, keeping the plant (plant-tower-defense-h5w6).
##
## THE POINT IS THE PRESERVATION, not the price. `commit_uproot()` above frees the plant
## and hands back a base-cost-scaled refund, so relocating a climbed Corn Cobbler costs 69
## seeds and the climb; this keeps the same node — its level, its health, its upgrade
## spend — and charges `Plant.move_cost()`, a quarter of what the player has put in. See
## that constant's header for why the bead's own framing (refund-minus-cost) was the free
## option with extra arithmetic.
##
## GATED ON THE ARMED WINDOW rather than being a mode of its own. `arm_uproot()` already
## selects the plant, starts the confirm clock and turns on the destination preview the
## move tip tells the player to hover — every piece was there and nothing consumed the
## click. So a move is the armed window's OTHER ending, beside confirming and cancelling,
## and it costs no new gesture to learn.
##
## Refusal strings rather than a bool, like `place_plant` and `commit_uproot`: every caller
## here wants to say what went wrong, and "not paid for" is deliberately the same wording
## `place_plant` uses so `_click_at` can shake the same button for the same reason.
## Would a move to `cell` land, ignoring price? The GROUND half of `commit_move`'s
## refusals, split out because the confirm clock needs the same answer
## (plant-tower-defense-b9bl) and two copies of "is this a legal destination" is how the
## clock and the click start disagreeing about what the player is doing.
##
## Deliberately NOT including affordability: a player hovering a destination they cannot
## yet afford is still deciding, and freezing the clock for them is right. The refusal for
## that is `commit_move`'s and it names the seeds.
func can_move_to(plant: Plant, cell: Vector2i) -> bool:
	if plant == null or not is_instance_valid(plant):
		return false
	if cell == plant.cell or _plants.has(cell):
		return false
	return board.is_inside(cell) and board.is_buildable_for(cell, plant.kind)


func commit_move(cell: Vector2i) -> String:
	if selected_placed == null or not is_instance_valid(selected_placed):
		return "nothing is selected"
	if not uproot_armed():
		return "arm the move first"
	var plant: Plant = selected_placed
	if cell == plant.cell:
		return "it is already there"
	if _plants.has(cell):
		return "something is already growing there"
	if not board.is_buildable_for(cell, plant.kind):
		# The SAME CONSTANT `place_plant` returns, and for the same reason: whether a
		# Barrier Bramble may stand here is a fact about the plant and the ground, and a
		# move must not be a way around it. It was a second copy of the literal until
		# cycle 168 reworded one of them and left this one behind.
		return REFUSAL_ON_GRASS if board.is_path(cell) else "that is not ground it can take"
	var price: int = plant.move_cost()
	if not bank.spend(price):
		# Checked by SPENDING rather than by comparing first: `SeedBank.spend` refuses and
		# changes nothing when the seeds are not there, so there is one place that decides
		# affordability instead of a comparison here that can drift from it.
		return "not paid for"
	# The dictionary key and the plant's own idea of where it stands are two facts and
	# both have to move. `_plants` is keyed by cell and `plant.cell` is read by
	# `_on_plant_destroyed`, the husk drop, the neighbour buff and the sole-cover marks —
	# leaving either behind puts the plant in one place and its consequences in another.
	_plants.erase(plant.cell)
	plant.cell = cell
	plant.position = board.cell_to_world(cell)
	_plants[cell] = plant
	# The window is spent either way, exactly as confirming or cancelling spends it. A
	# move that left the plant armed would leave the next click one press from digging up
	# the thing that was just rescued. `_disarm_uproot` is the ONE place the arming is
	# cleared and puts the marker back with it, which its own header says is why every
	# exit runs through it.
	_disarm_uproot()
	Sfx.play(Sfx.PLANT_PLACED)
	seeds_on_plants += price
	_refresh()
	return ""


## Beat between a purchase landing and its reveal. SeedBank's own header calls
## this "a gamble that reads as suspense" (seed_bank.gd), but buy_packet()
## rolls and returns synchronously, so nothing used to separate the click from
## the banner — the roll and the reveal happened in the same frame. The roll
## itself stays exactly that synchronous and testable; only what the player
## SEES of it is delayed, and only here, in the presentation layer.
const PACKET_OPEN_STEP_SECONDS: float = 0.09
const PACKET_OPEN_STEPS: int = 3

## The tier being opened, set immediately before buy_packet() so
## _on_plant_unlocked — which fires synchronously from inside that call — knows
## which pool to flash candidates from.
var _opening_tier: StringName = &"common"


func _on_packet_requested(tier: StringName = &"common") -> void:
	_opening_tier = tier
	var got: StringName = bank.buy_packet(tier)
	if got != &"":
		selected_plant = got
		# The SECOND route in, and the comment above _on_plant_chosen says there is only
		# one ("This is the only route in; there is no keyboard shortcut"). That is true of
		# the BAR and not of `selected_plant`: a packet hands the player a plant already
		# selected, so a Bramble can arrive here having never been pressed in the bar. A
		# hint wired only to the bar would miss exactly the player meeting the plant for
		# the first time, which is the only player it is for.
		_offer_road_hint()
	else:
		hud.shake_packet_button(tier)


func _on_plant_unlocked(id: StringName) -> void:
	if not GardenTheme.animations_enabled():
		# Headless never pumps the frames a wait needs, so the old instant
		# reveal stays the whole story there — same rule every other flourish
		# in this file follows.
		_reveal_plant_unlock(id)
		return
	await _open_packet(id)


## Flickers through a couple of the tier's other still-locked candidates
## before landing on the real pick — PACKET_OPEN_STEPS steps of
## PACKET_OPEN_STEP_SECONDS each, well under a second total, so it reads as a
## beat rather than a wait. Falls back to `id` itself for a step if the pool
## it drew from is down to nothing else (a packet with one thing left to give).
##
## Reads bank.packet_pool(_opening_tier) rather than the tier's whole catalogue:
## by the time this runs, `id` is already unlocked (buy_packet() appends it
## before emitting), so the pool is naturally everything BUT the real pick —
## exactly the "other candidates" a flicker needs, with nothing to filter out.
## Packets waiting for the flourish, each carrying its OWN tier.
##
## `_opening_tier` is set immediately before `buy_packet()` and read inside the flourish,
## which was safe while exactly one flourish could be running. It is not safe once a
## purchase can wait for another: a common packet queued behind a rare one would flash
## candidates from the rare pool by the time it ran. The tier travels with the id instead.
var _packet_queue: Array[Dictionary] = []

## Whether the runner below is already draining `_packet_queue`.
var _packet_opening: bool = false


## SERIALISED, and this is the fix for plant-tower-defense-47v7 rather than a tidy-up.
##
## The flourish is a coroutine: three steps with an `await` between each. Two purchases
## inside about a second put two of them in flight at once, and their posts interleave --
## measured in cycle 129 with `cmd messages`, two purchases back to back gave
##
##     refused 1
##     refused_log ["The packet held a Chomp Flower!"]
##     row "The packet held a Barrier Bramble!" | 3 pending
##
## The refused line is a REVEAL. The first packet's flourish reached `_reveal_plant_unlock`
## while the second packet's flicker steps held the row and filled the queue, so the player
## was told what the second packet contained and never told about the first -- which they
## had paid seeds for, and which the reveal is the only announcement of.
##
## Of the three options the bead offered -- collapse the flicker, queue properly, or leave
## it -- this is "queue properly", chosen because the player bought two packets and is owed
## two answers. Collapsing would still have dropped one of them.
##
## Serialising at the FLOURISH rather than raising the reveal's priority, because the
## priority ladder is about how much a line matters to the player and both reveals matter
## exactly the same amount. The contention is between two runs of one animation, which is a
## sequencing problem; solving it with priorities would have made a second reveal preempt a
## first that had been on screen for a tenth of a second.
func _open_packet(id: StringName) -> void:
	_packet_queue.append({"id": id, "tier": _opening_tier})
	if _packet_opening:
		return
	_packet_opening = true
	while not _packet_queue.is_empty():
		var next: Dictionary = _packet_queue.pop_front()
		# BEFORE each flourish, including the first, and that "including the first" is the
		# whole fix. Serialising only the queue looked correct and the game was still broken:
		# a flourish lasts PACKET_OPEN_STEPS * PACKET_OPEN_STEP_SECONDS, about a quarter of a
		# second, so two purchases half a second apart never overlap and never queue. The
		# second one starts fresh -- and posts its steps behind the FIRST one's five-second
		# reveal, refusing it exactly as before. Caught by re-running cycle 129's live recipe
		# against the "fix"; the headless test passed throughout, because it fires both
		# purchases in the same frame, which is the one case serialisation alone did cover.
		await _row_ready_for_a_flourish()
		await _play_packet_flourish(StringName(next["id"]), StringName(next["tier"]))
	_packet_opening = false


## Wait until an equal-priority post will land on the row instead of queueing behind it.
##
## SERIALISING THE FLOURISHES IS NOT ENOUGH ON ITS OWN, which is worth stating because it
## looks like it should be. A reveal is posted for 5 seconds; `show_message` overwrites at
## equal priority only once the current line has `MESSAGE_MIN_READABLE` or less remaining.
## So a second flourish starting the instant the first returns still posts three steps
## behind a 5-second reveal, fills the queue, and gets its own reveal refused -- the
## original defect, one call deeper.
##
## Asked of the row rather than computed from the constants: `5.0 - MESSAGE_MIN_READABLE`
## would be a fourth place that has to change when the reveal's duration does, and the row
## already knows the answer. `message_seconds_left()` exists because cycle 129 needed it for
## `cmd messages`; this is its second caller and the reason it is not a debug-only reader.
##
## The frame cap is a stop, not a timeout: nothing should hold the row this long, and if
## something does, the packet still gets its reveal rather than the coroutine waiting
## forever. Sixty seconds of frames at 60fps, which is far past any message this game posts.
## The priority test matters as much as the time one. A flourish posts at
## `MESSAGE_IMPORTANT`, so it PREEMPTS anything ambient sitting on the row -- waiting for an
## ambient line to expire would delay every packet behind a husk notice for no reason, and
## would be a visible regression rather than a fix. Only a line at IMPORTANT or above can
## make a flourish queue, so only that is worth waiting for.
func _row_ready_for_a_flourish() -> void:
	var frames: int = 0
	while frames < 3600 \
			and hud.message_priority() >= Hud.MESSAGE_IMPORTANT \
			and hud.message_seconds_left() > Hud.MESSAGE_MIN_READABLE:
		frames += 1
		await get_tree().process_frame


func _play_packet_flourish(id: StringName, tier: StringName) -> void:
	var pool: Array[StringName] = bank.packet_pool(tier)
	for i: int in range(PACKET_OPEN_STEPS):
		var flash: StringName = id if pool.is_empty() else pool[i % pool.size()]
		# Same priority on every step, deliberately: show_message() only queues
		# a message behind one still on screen for MESSAGE_MIN_READABLE seconds
		# or a higher priority. Equal priority and a step well under that falls
		# through to the immediate-overwrite branch instead, so each flicker
		# replaces the last rather than queuing up behind it.
		#
		# WHICH IS ALSO WHY THE DURATION IS AN OVERRIDE and takes no band from
		# `Hud.message_seconds`: these steps are an animation, not messages, and
		# being UNDER MESSAGE_MIN_READABLE is the whole mechanism. Give them a
		# readable duration and every step queues behind the last, filling the row's
		# queue and getting the reveal below refused — the defect
		# `_row_ready_for_a_flourish` was written to fix, reintroduced one call deeper.
		hud.show_message("...%s?" % PlantCatalog.display_name(flash),  # message-corpus-check: ok - a plant name already bounded by packet_message() plus three characters
			PACKET_OPEN_STEP_SECONDS, Hud.MESSAGE_IMPORTANT)
		await get_tree().create_timer(PACKET_OPEN_STEP_SECONDS).timeout
	_reveal_plant_unlock(id)


func _reveal_plant_unlock(id: StringName) -> void:
	# IMPORTANT, matching every step of the flourish above it: an ambient
	# message re-surfacing between those steps (see _open_packet) would
	# otherwise queue the reveal itself behind it instead of showing it.
	# REVEAL, and it is the one band that is not free to retune: `_row_ready_for_a_flourish`
	# above waits on this line still holding the row, so its length decides how two quick
	# packet purchases interleave. Changing ROLE_REVEAL is a gameplay change, not a
	# cosmetic one — see Hud.message_seconds.
	hud.show_message(Hud.packet_message(PlantCatalog.display_name(id)),
		Hud.message_seconds(Hud.ROLE_REVEAL), Hud.MESSAGE_IMPORTANT)
	_refresh()


# -- input ------------------------------------------------------------------


## Which finger is currently down, or -1. The whole of the touch/mouse-emulation guard
## (plant-tower-defense-qdsi).
##
## ONE finger, by index, and not a count. A second finger landing while the first is placing
## is palm contact or a fumble far more often than it is a second intent, and this game has
## no two-finger gesture — so the first finger down owns the placement and everything else is
## ignored until it lifts. `touch list` on the bridge is what shows a second index arriving.
var _touch_index: int = -1

## Where the finger that owns the placement first landed, board-local, and whether it has
## since moved far enough to count as a DRAG rather than a tap (plant-tower-defense-bmis).
##
## THE WHOLE OF THE SNAP'S SCOPE IS THIS FLAG, and the reason is that `_click_at` means
## four different things depending on what is under it. A tap on a plant selects it; a tap
## on a husk composts it; a tap on empty ground plants. Snapping a TAP away from the cell
## it landed on would make the first two unreachable on touch — every tap on a plant would
## be pulled to the empty grass beside it and buy a second one — because "the cell is
## occupied" is exactly the condition the snap fires on.
##
## A DRAG is not ambiguous in that way. A finger that has travelled across the board with
## a placement cue under it the whole time is placing, and nothing else; that is the
## gesture the player described when they asked for this. So the tap keeps today's
## behaviour to the pixel and the drag gets the help.
var _touch_start: Vector2 = Vector2.ZERO
var _touch_dragged: bool = false

## How far a finger must travel before it is a drag and not a tap.
##
## Small, and it is a slop rather than a gesture threshold: a real finger jitters by a
## pixel or two between press and release without any intent to move, and on a device that
## delivers that jitter as `InputEventScreenDrag` (which is a property of the hardware, not
## something a test can decide — see plant-tower-defense-bfbb) every tap would otherwise
## arrive as a drag. 16 px is a quarter of a `Board.CELL` and well under the 32 px from a
## cell's centre to its edge, so a finger that has not left the cell it landed on is never
## a drag, and one that has crossed into another cell always is.
const TOUCH_DRAG_SLOP: float = 16.0

## How far a dragging finger may miss a placeable cell and still be understood to mean it.
##
## MEASURED AGAINST `Board.CELL` = 64, and the three distances that matter are from the
## touch point to a candidate cell's CENTRE:
##
##   * an orthogonal neighbour's centre is 32 px away with the finger on the shared edge,
##     64 from the centre of the cell it is in, and 96 from the far edge;
##   * a diagonal neighbour's centre is 45.25 px from the shared corner and 90.51 from the
##     centre;
##   * the NEAREST point of a cell two away is 96.
##
## 72 sits above 64 and below 90.51 and 96, and that buys exactly the rule worth having:
## an orthogonal neighbour is reachable from anywhere in the near half of the cell and
## from its centre, a diagonal only while the finger is leaning into that corner, and a
## cell two away is unreachable from anywhere — a snap that could skip a cell would put a
## plant somewhere the player never pointed. `test_the_snap_radius_cannot_reach_past_the
## _ring_it_searches` pins the last of those against `Board.CELL` rather than against 72,
## so changing the cell size fails the test instead of silently widening the reach.
const TOUCH_SNAP_RADIUS: float = 72.0


## A finger going down or coming up.
##
## COMMITS ON RELEASE, which is the change the bead is really about. A tap placed on PRESS
## gives a touch player no way to see what they are about to do and no way to abort a
## mis-aim: the cell under the first contact is the cell they get. Committing on release
## means the finger can slide to the right cell with the preview updating the whole way
## (see the InputEventScreenDrag branch), and sliding off the board aborts.
##
## The release position is used, NOT the press position. That is the same sentence as the
## line above and it is the one an implementation gets wrong by using the remembered start.
func _on_screen_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		if _touch_index != -1:
			return   # a second finger while one is placing: see _touch_index
		_touch_index = touch.index
		_touch_start = touch.position
		# Not a drag until it has travelled TOUCH_DRAG_SLOP. A press is a press.
		_touch_dragged = false
		# Show the cue immediately, so the first thing a finger does is reveal validity
		# rather than change the board.
		_update_cursor(touch.position)
		return
	if touch.index != _touch_index:
		return
	# A FINGER THAT LEFT THE BOARD IS SAYING "NEVER MIND" (plant-tower-defense-vvmy), and
	# it is the only way a touch player can say it -- there is no right button on a phone,
	# so the right-click escape in `_unhandled_input` reaches nobody who is actually
	# playing this on the device the gesture was built for.
	#
	# NOT A NEW GESTURE. Sliding off the board was already the abort and already threw the
	# placement away (see this function's own header); what is new is that it now throws
	# the ARM away with it, so a player who changes their mind ends up with nothing armed
	# rather than with a live purchase waiting on their next stray tap.
	#
	# `_hover_cell.x < 0` is the same test `_update_cursor` leaves behind when the finger
	# is off the board, rather than a second bounds check that could disagree with it.
	# CLEARED BEFORE THE COMMIT, NOT AFTER IT, and that ordering is now load-bearing
	# (plant-tower-defense-vvmy). `_update_cursor` reads `_touch_index` to decide whether
	# to lift the ghost clear of the finger, and `_commit_placement` redraws the cue on
	# its way out. Clearing afterwards -- which is what this did -- left that last redraw
	# believing a finger was still down, so the ghost stayed lifted a cell above its own
	# square with nothing touching the screen.
	#
	# The comment this replaces is still true of WHY it is not deferred: an earlier draft
	# held the flag for a frame to keep the emulated mouse events out, and that is no
	# longer this flag's job -- `device == -1` does it in `_unhandled_input`, for the
	# PRESS, which arrives before any flag could be set. All this carries is the
	# one-finger rule, so nothing below needs it and it can go early.
	var dragged: bool = _touch_dragged
	_touch_index = -1
	_touch_dragged = false
	# A FINGER THAT LEFT THE BOARD IS SAYING "NEVER MIND" (plant-tower-defense-vvmy), and
	# it is the only way a touch player can say it -- there is no right button on a phone,
	# so the right-click escape in `_unhandled_input` reaches nobody who is actually
	# playing this on the device the gesture was built for.
	#
	# NOT A NEW GESTURE. Sliding off the board was already the abort and already threw the
	# placement away (see this function's own header); what is new is that it now throws
	# the ARM away with it, so a player who changes their mind ends up with nothing armed
	# rather than with a live purchase waiting on their next stray tap.
	#
	# ASKED OF THE RELEASE POSITION, not of `_hover_cell`. Reading the cue's own leftover
	# state looked like the way to guarantee the abort and the cue could not disagree, and
	# it is exactly how they disagreed -- a finger dragged off the RIGHT edge crosses onto
	# the side panel, which swallows the remaining drag events, so the cue is left holding
	# the last on-board cell it heard about. See `off_board`, which both callers now share.
	if off_board(touch.position):
		disarm_plant()
		return
	# The gesture decides whether the release may be snapped; see `_touch_dragged`.
	_click_at(touch.position, dragged)


func _unhandled_input(event: InputEvent) -> void:
	# TOUCH FIRST, and the order is the whole of the mouse-emulation problem below.
	var touch := event as InputEventScreenTouch
	if touch != null:
		_on_screen_touch(touch)
		return
	var drag := event as InputEventScreenDrag
	if drag != null:
		# A finger already down, moving. This is the hover a mouse player has had all
		# along and a touch player never did: the preview follows the finger, so validity
		# is visible BEFORE the commit rather than being discovered by the result.
		_touch_index = drag.index
		# A tap that jitters is still a tap; see TOUCH_DRAG_SLOP. Latched rather than
		# recomputed per event, so a finger that wanders out and comes back to where it
		# started does not stop being a drag halfway through the gesture.
		if not _touch_dragged and _touch_start.distance_to(drag.position) > TOUCH_DRAG_SLOP:
			_touch_dragged = true
		_update_cursor(drag.position, _touch_dragged)
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		# Same discriminator as the press below, for the same measured reason: the emulated
		# motion arrives before the drag that produced it, so a flag is too late here too.
		if motion.device == -1 and DisplayServer.is_touchscreen_available():
			return
		_update_cursor(motion.position)
		return
	var click := event as InputEventMouseButton
	# NEVER MIND (plant-tower-defense-lzw4). A plant selected on the board had no way out
	# of the selection but to select ANOTHER plant, pick a packet out of the bar, or uproot
	# it — every exit either moved the rings somewhere else or spent something, and none of
	# them is the thing a player reaches for when they only wanted a look. Right-click is
	# that gesture, and it was free: nothing else in this project reads MOUSE_BUTTON_RIGHT,
	# so this takes no click away from anything that already had one.
	#
	# IT IS ALSO THE CANCEL FOR AN ARMED UPROOT, and by _select's own rule rather than by
	# a second call here: `_select(null)` disarms whenever the new selection is not the
	# armed plant. That window is the one a player most wants out of, because it is holding
	# a destructive confirm open on a clock.
	#
	# NOT CONSUMED WHEN NOTHING IS SELECTED. A right press over bare board is not this
	# gesture; swallowing it would quietly reserve the button against anything added later.
	#
	# No emulated-device guard, unlike the left branch below: mouse-from-touch emulation
	# only ever synthesises MOUSE_BUTTON_LEFT, so there is no second event to tell apart.
	#
	# IT NOW CLEARS THE SHOP PICK TOO (plant-tower-defense-vvmy), which the paragraph
	# above did not: it un-selected the plant on the BOARD and left `selected_plant`
	# holding whatever the bar had armed, so "never mind" only ever meant half of what a
	# player pressing it means. One gesture, one rule -- right-click clears the selection,
	# all of it -- beats two gestures a player has to keep straight.
	#
	# STILL NOT CONSUMED WHEN THERE WAS NOTHING TO CLEAR, and `disarm_plant()` returning a
	# bool is what keeps that true now that there are two things to clear rather than one.
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
		var had_placed: bool = selected_placed != null and is_instance_valid(selected_placed)
		# BOTH called, and `or` short-circuits -- so `disarm_plant()` goes first. Written
		# the other way round, a right-click on a board selection would clear the marker
		# and leave the arm, which is exactly the half-clear this branch is fixing.
		var cleared: bool = disarm_plant() or had_placed
		if not cleared:
			return
		if had_placed:
			_select(null)
		_refresh()
		return
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		# THE EMULATED PRESS IS THE ONE THAT MUST NOT PLANT.
		#
		# `input_devices/pointing/emulate_mouse_from_touch` is on by default and is left
		# on deliberately: every Button in this game is a Control that answers mouse
		# events, so turning it off to get clean touch handling would kill the shop, the
		# pause card and every screen's Back button on exactly the devices this is for.
		#
		# So the engine sends BOTH for one finger — a real InputEventScreenTouch and an
		# emulated InputEventMouseButton. Handling both plants twice, and worse, the
		# emulated PRESS arrives with the finger going down, which would commit at the
		# press position and undo the entire point of committing on release.
		#
		# THE DEVICE ID TELLS THEM APART, and a flag cannot — which was worth measuring
		# rather than assuming, because the obvious implementation is a flag and it does
		# not work. Probed on a running game with `set-feature --touchscreen true` and one
		# `touch press`:
		#
		#     PROBE mouse press  device=-1  touch_index=-1
		#     PROBE screen touch pressed index=0 device=0
		#
		# The emulated mouse press arrives BEFORE the InputEventScreenTouch. So a guard set
		# by the touch handler is always too late — the first version of this planted at the
		# press cell, which is the exact behaviour commit-on-release exists to remove — and
		# no ordering of the branches above can fix it. Godot marks the emulated event
		# `device == -1` and a real one 0, and that is the only thing available before the
		# touch is seen.
		#
		# NARROWED BY `is_touchscreen_available()` deliberately. `device == -1` means
		# "synthesised", not "from touch": the devtools bridge's own `mouse-move` sends one,
		# and on a desktop with no touchscreen emulation never fires, so a -1 there is a
		# test driving the game and must be honoured. This ignores it only where a real
		# finger could have produced it.
		if click.device == -1 and DisplayServer.is_touchscreen_available():
			return
		_click_at(click.position)
		return
	# A verb arrives as an InputEventKey off a keyboard and as an InputEventAction
	# out of Input.action_press -- which is what the devtools bridge's `input tap`
	# sends, and the only way any of these four is checkable in a running game.
	# Narrowing to InputEventKey here, as this handler did while it compared raw
	# keycodes, made every one of them unreachable from the bridge while looking
	# perfectly correct to a player. `is_action_pressed` does the pressed and
	# not-an-echo filtering the explicit guard used to.
	if not (event is InputEventKey or event is InputEventAction):
		return
	# Actions, not keycodes: what these four verbs are bound to is KeyBindings.ACTIONS
	# and, after a visit to the settings screen, whatever the player put there
	# instead. Nothing in this handler may name a KEY_* constant again — the pause
	# card's legend is rendered from the same InputMap these lines read.
	if event.is_action_pressed(KeyBindings.ACTION_RESTART) and (game_over or victory):
		get_tree().reload_current_scene()
		return
	# Not while the run is over: the post-mortem is already a modal surface, and
	# pausing behind it would leave two cards stacked with no way to reach either.
	if event.is_action_pressed(KeyBindings.ACTION_PAUSE) and not (game_over or victory):
		pause_run()
		return
	# The project-level mute, which is what makes the sound pass something the
	# player controls rather than something the engine's --mute flag controls for
	# them. Deliberately live even on the results screen: a jingle the player
	# wants to stop is exactly when they reach for this.
	#
	# M and N are two independent switches, not one shared one: M silences the
	# one-shot cues (Sfx), N silences the looping bed (Music). They used to be
	# a single flag -- Music read Sfx.is_muted() directly -- so a run had
	# exactly one volume and it silenced both at once. See Music._muted's own
	# doc comment for the split.
	#
	# Through RunConfig rather than straight at Sfx/Music, so a mute set from the
	# keyboard mid-run is the same act as one set on the Options screen and is
	# written to the save either way. Calling the static setters here left the
	# player's choice alive exactly as long as the process (plant-tower-defense-v6c).
	if event.is_action_pressed(KeyBindings.ACTION_MUTE_SFX):
		# The key named in the message is read back out of the InputMap, not typed
		# here. "Press M to bring them back" printed at a player who had rebound
		# the verb to F2 is worse than saying nothing at all.
		# SETTING for all three toggles below: the world answers as well, but subtly —
		# silence and a repaint are both easy to miss, and the un-mute half of the line
		# names the key to press. A hair longer than a CONFIRM for that reason and no
		# other; "Music on." is ten characters and outlasts sentences twice its length.
		hud.show_message(mute_message("Sound effects", RunConfig.toggle_mute_sfx(),  # message-corpus-check: ok - keybind-dependent; the budget measures the CURRENT binding live
			KeyBindings.ACTION_MUTE_SFX, "them"), Hud.message_seconds(Hud.ROLE_SETTING))
		return
	if event.is_action_pressed(KeyBindings.ACTION_MUTE_MUSIC):
		hud.show_message(mute_message("Music", RunConfig.toggle_mute_music(),  # message-corpus-check: ok - keybind-dependent; the budget measures the CURRENT binding live
			KeyBindings.ACTION_MUTE_MUSIC), Hud.message_seconds(Hud.ROLE_SETTING))
		return
	# Swaps the health fill and the threat readout onto GardenTheme's blue/orange
	# ramp. This arrived as a raw scancode check from the branch that added the
	# ramp, at the same time as the branch that moved every other verb onto the
	# InputMap; it is an action here so the Keys screen can rebind it like the
	# rest, and so the pause card lists it without a second hand-written row.
	# (Naming the constant even in a comment fails the scan above, by design.)
	#
	# _refresh() rather than waiting for the next state change: both bars are
	# repainted from state, and the threat tint EASES toward its target, so a player
	# who presses this between waves with nothing selected would otherwise see
	# nothing happen and conclude the key does not work.
	if event.is_action_pressed(KeyBindings.ACTION_COLORBLIND):
		var safe: bool = RunConfig.toggle_colorblind_safe()
		hud.show_message(
			"Colourblind-safe bars on." if safe else "Colourblind-safe bars off.",
			Hud.message_seconds(Hud.ROLE_SETTING))
		repaint_for_palette()
		return
	# The designer's "faster button", and the backlog's slow mode, as one verb —
	# see GameSpeed.STEPS.
	#
	# NO show_message here, and the omission is a decision rather than an oversight:
	# the top bar's speed button is the readout, and it changes on the same
	# _refresh() this triggers. A message would be a second copy of the same fact,
	# and — the half that actually settled it — every string that reaches that row
	# has to be priced in `Hud.message_corpus()` or `message_corpus_check` is right
	# to call it an unpriced producer. A readout the player is already looking at
	# beats a line that has to be budgeted to say the same thing.
	if event.is_action_pressed(KeyBindings.ACTION_SPEED):
		cycle_speed()


## Every bar the colourblind ramp reaches, repainted now rather than at whatever
## the next state change happens to be.
##
## Three bars, and only two of them are the HUD's. `_refresh()` covers those; the
## in-world plant bar is drawn from take_damage()/_regrow(), so a chewed plant
## nobody is currently eating would keep the old ramp until something bit it again.
##
## A method rather than five lines inside the C-key handler because the keystroke
## is no longer the only thing that can flip the switch mid-run: the Options screen
## over the pause card can too, and `resume_run` calls this on the way out for that
## reason. A player who opens Options mid-run to turn the accessibility bars on is
## doing it because they cannot read the current ones — "it takes effect at the
## next wave" is not an answer to that.
func repaint_for_palette() -> void:
	_refresh()
	for plant: Plant in _plants.values():
		plant.repaint_health_bar()


## The free-to-place cursor hover wash's own alpha, named rather than a bare
## literal repeated at both call sites below (plant-tower-defense-sv30).
const CURSOR_HOVER_ALPHA: float = 0.30

## The free-to-place half of the cursor hover wash. NOT `GardenTheme.LEAF`
## (plant-tower-defense-sv30, out of plant-tower-defense-w86n's colour-margin
## sweep): `GardenTheme.GROUND_GRASS := GardenTheme.LEAF`, the SAME constant, so
## painting the free cue in LEAF over grass had 0.0 luminance separation from its
## own background — not a dim cue, an invisible one, at ANY alpha, because
## `GardenTheme.composite_over` scales separation by exactly alpha and alpha
## times zero is zero regardless of which alpha ships.
##
## LIGHTENING TOWARD WHITE CANNOT FIX THIS EITHER, which is why the fix below is
## a darkening rather than the lightening `PlacementPreview.OK_COLOR` used for
## the brackets this cue sits inside. Clearing `GardenTheme.GROUND_SEPARATION_MIN`
## (0.12) at `CURSOR_HOVER_ALPHA` (0.30) needs a base separation of at least
## 0.12 / 0.30 = 0.40 from BOTH grounds, and grass alone already sits at
## luminance 0.64 of a possible 1.0 — a brighter mark would need luminance
## >= 1.04, past white. `OK_COLOR` clears its brackets at alpha 0.75, where the
## same arithmetic only demands 0.16; this wash is drawn dimmer, so it does not
## have that room.
##
## `GardenTheme.INK`, darkened by half: luminance 0.071, against grass (0.642)
## and dirt (0.534, the tighter of the two grounds). A literal rather than a
## call to `.darkened()` because a `const` initializer cannot call a method —
## the same reason `PlacementPreview.OK_COLOR`/`BLOCKED_COLOR` are literals with
## their derivation in a comment rather than in the expression. The derivation
## is asserted, not just claimed, by
## test_every_board_mark_clears_the_ground_floor_at_the_alpha_it_is_drawn_at's
## "free cursor hover wash" rows.
const CURSOR_FREE_COLOR := Color(0.06, 0.075, 0.065)

## `snap` is passed only by the touch drag branch, and only once the finger has actually
## travelled — see `_touch_dragged` for why a tap must never snap. A mouse never passes it:
## a cursor is one pixel, it occludes nothing, and pulling it off the cell the player put
## it on would be taking away precision they already have.
##
## THE ABORT IS DECIDED ON THE RAW CELL, deliberately, and it is the reason the snap is
## applied after the bounds guard rather than before it. Sliding off the board is how a
## touch player cancels a placement (see `_on_screen_touch`); if the snap ran first, a
## finger leaving the board over the last column would be pulled back onto it and the
## cancel would be unreachable.
## Is this screen point outside the playfield? Extracted out of `_update_cursor`'s own
## opening guard, which is still its only other caller (plant-tower-defense-vvmy).
##
## EXTRACTED BECAUSE THE TOUCH ABORT HAD TO ASK THE SAME QUESTION AND ASKED A DIFFERENT
## ONE. `_on_screen_touch` first tested `_hover_cell.x < 0` -- the state this guard leaves
## behind -- on the reasoning that reading the cue's own answer could not disagree with
## the cue. It disagreed, and the running game is what said so.
##
## The reason is the SIDE PANEL. Drag a finger off the right-hand edge and it crosses
## `board_size().x` (896) onto the panel (which begins at 908); the panel is a Control
## that answers input, so it consumes the `InputEventScreenDrag`s from there on and
## `_unhandled_input` never sees them. `_hover_cell` is left holding the last cell the
## cue managed to update to. Measured on the running game after exactly that gesture:
## `_touch_index=-1  _hover_cell=(13, 8)` -- column 13 of 14, the last column before the
## edge, and not the `(-1, -1)` the abort was waiting for. Every drag step past the board
## had been swallowed.
##
## So the release asks about the RELEASE POSITION, which it always has, rather than about
## a cue that may never have been told. This is the same arithmetic either way; making it
## a named function is what stops the two answers drifting again.
##
## The `x >` half is not redundant with `is_inside`: the board is narrower than the
## window, and a point in the strip between the board's right edge and the panel maps to
## a column that IS inside the grid.
func off_board(screen_pos: Vector2) -> bool:
	var cell: Vector2i = board.world_to_cell(screen_pos - _entities.position)
	return not board.is_inside(cell) or screen_pos.x > board.board_size().x


func _update_cursor(screen_pos: Vector2, snap: bool = false) -> void:
	var local: Vector2 = screen_pos - _entities.position
	var cell: Vector2i = board.world_to_cell(local)
	if off_board(screen_pos):
		_cursor.visible = false
		_preview.visible = false
		_hover_cell = Vector2i(-1, -1)
		return
	if snap:
		cell = snapped_placement_cell(local)
	_hover_cell = cell
	_cursor.visible = true
	_cursor.position = Vector2(cell.x * Board.CELL, cell.y * Board.CELL)
	var free: bool = board.is_buildable_for(cell, selected_plant) and not _plants.has(cell)
	_cursor.color = Color(CURSOR_FREE_COLOR, CURSOR_HOVER_ALPHA) if free else Color(GardenTheme.DANGER, CURSOR_HOVER_ALPHA)
	_update_preview(cell, free)


## Hover cue for the plant currently picked in the bar: brackets in the shape
## it will wear once selected, plus the coverage it would have. Affordability
## counts as "blocked" alongside road/occupied — hovering a legal cell you
## cannot pay for should not draw an encouraging green ring.
func _update_preview(cell: Vector2i, free: bool) -> void:
	# Nothing to preview over a plant already there: that cell's own selection
	# marker and range ring are the truthful answer, and stacking a second set
	# of brackets on it reads as a bug.
	if _plants.has(cell):
		_preview.visible = false
		return
	_preview.visible = true
	_preview.position = board.cell_to_world(cell)
	# The ghost gets out from under the finger, and ONLY when there is a finger
	# (plant-tower-defense-vvmy). `_touch_index` is the one flag that means "a finger owns
	# this gesture right now" — it is set on press, cleared on release, and it is already
	# what the one-finger rule is enforced with, so this cue cannot disagree with the
	# gesture it is describing.
	#
	# AFTER `position`, not before: PlacementPreview.ghost_lift_offset() flips the lift's
	# direction on row 0, and the setter reads the row out of the position it is given.
	# Assigned unconditionally rather than only on change, for the same reason — see that
	# property's own header.
	_preview.lifted = _touch_index != -1
	# While an uproot is armed the player is weighing a MOVE, not a purchase, so the
	# preview describes the plant being moved rather than whatever is selected in the
	# shop (plant-tower-defense-qk5q). Nothing else about the hover changes: the same
	# brackets, the same ring, the same dots — only the subject.
	# `_uproot_armed` alone, with no `_uproot_left > 0.0` beside it. That guard was
	# here first and a mutation could not kill it: _disarm_uproot() nulls this on
	# every exit path there is — the player confirming, the window expiring, and the
	# plant being eaten mid-decision — so a live `_uproot_armed` already means an
	# open window. A second condition that can never disagree is the dead code this
	# repo has been bitten by before, wearing a safety belt.
	# test_the_uproot_window_leaves_nothing_armed_behind_it pins the invariant.
	var moving: Plant = _uproot_armed
	if moving != null and not is_instance_valid(moving):
		moving = null
	var previewing: StringName = moving.kind if moving != null else selected_plant
	# NOTHING ARMED, NOTHING TO PREVIEW (plant-tower-defense-vvmy). This is the whole cost
	# of making `&""` a legal `selected_plant`, and it is the branch that makes the empty
	# state legible rather than merely harmless: the brackets promise "a click here buys
	# this", and with no plant chosen there is nothing they could be promising.
	#
	# THE CURSOR TINT DELIBERATELY STAYS UP -- `_update_cursor` sets it before calling
	# here and this does not undo it. A click with nothing armed still does things: it
	# selects a plant already standing there and it sweeps a husk. The square under the
	# pointer is still where those land, so the cue that says WHICH SQUARE is still true.
	# What comes down is only the cue that was making a promise about a purchase.
	if not PlantCatalog.has(previewing):
		_preview.visible = false
		return
	_preview.reach = PlantCatalog.reach(previewing)
	# Explicit rather than inferred. PlacementPreview falls back to deducing the
	# kind from `reach`, which works only while no two plants share a radius --
	# a coincidence, not a rule, and the redundant-coverage cue depends on it.
	_preview.plant_id = previewing
	# What the garden already reaches, so the preview can dot the road cells this
	# purchase would newly defend. Recomputed per hover rather than cached: the
	# set changes on every placement and every uproot, and a stale one would mark
	# ground as bare that a plant now covers — the one error this cue must not
	# make, since it is read as "spend seeds here".
	# The plant being moved is left OUT of what counts as already covered, because it
	# is about to stop covering it. Without that, every cell it currently holds reads
	# as "already defended" and the move preview would report the destination as
	# buying almost nothing — worst exactly where the move matters most, a short hop
	# that keeps most of the old reach.
	_preview.covered_now = covered_road_cells(moving)
	# The same predicate _click_at obeys, so the brackets are a promise: green
	# means this click plants. `free` is kept as the caller's override — the
	# self-test suite drives this method with a forced value to pin the blocked
	# rendering — and would_plant_at() recomputes it honestly from the board.
	#
	# THE THIRD TERM IS THE ARMED-MOVE CASE (plant-tower-defense-l7ak), and it is a no-op
	# in every other one: with nothing armed `previewing == selected_plant`, so it asks
	# the same question would_plant_at() just answered.
	#
	# While an uproot IS armed the two halves of this cue describe different plants. The
	# ring, the reach and the coverage dots are the plant being MOVED (`previewing`, per
	# -qk5q); the brackets are a promise about what a click does, and a click plants
	# `selected_plant` — the SHOP pick, which `_select()` never touches. Before a plant
	# stood somewhere the others could not, those could not visibly disagree: every plant
	# was placeable in exactly the same cells. Hover a road cell with a cob armed and a
	# Barrier Bramble picked, and the old code drew green brackets around a cob's range
	# ring over ground no cob can occupy — which reads as "your cob moves here" and plants
	# a Bramble.
	#
	# Requiring BOTH is the conservative reading and the one that cannot mis-promise: the
	# click must plant, AND the plant being described must be able to stand there. It
	# refuses a cell rather than inventing a meaning for the disagreement — whether a move
	# should be a single action at all is still open (plant-tower-defense-h5w6), and a cue
	# that answered it here would be deciding that question by accident.
	_preview.placeable = (free and would_plant_at(cell)
		and board.is_buildable_for(cell, previewing))
	# Only a plant that cannot defend itself is "at risk" beside the road. A
	# Corn Cobbler there is the entire point of a Corn Cobbler; flagging it
	# would teach the player to ignore the cue everywhere it matters.
	#
	# A road plant is excluded by that same sentence rather than by an exception to it.
	# A Barrier Bramble has reach 0.0 and stands on a cell every neighbour of which is
	# road, so both halves of the test above are true of it — and being eaten is the
	# entire point of a Barrier Bramble, exactly as shooting is the entire point of a
	# cob. Warning the player about the one purchase whose whole job is to be chewed is
	# how a cue gets ignored on the cells where it means something.
	_preview.at_risk = (_preview.reach <= 0.0 and board.is_road_adjacent(cell)
		and not PlantCatalog.on_road(previewing))
	_preview.queue_redraw()


## One click, up to four things it could mean. The rule, in the sentence a player
## would say it in: **a click that would plant, plants — a husk only takes clicks
## that were never going to plant anything.**
##
## The sweep used to run first and unconditionally, so a husk within
## CompostMeter.COLLECT_RADIUS (28 px, a 56 px target on a 64 px cell) of the
## click ate it, and the player got "Composted a husk" on a cell the preview had
## just drawn as legal, affordable and empty. The preview could not warn about it
## either: it is redrawn on mouse motion, on picking a plant in the bar, and after
## a click — nothing per-frame — while a husk rots on its own 4.5-10 s timer
## (CompostMeter.lifetime_for), so any husk cue would go stale under a still
## cursor. Precedence is the fix; a fourth preview state would have been a picture
## that lies for up to ten seconds at a time.
##
## Harvesting is untouched by the reordering, and provably so rather than
## hopefully so. Pests only ever walk Board.route(), which is one point per road
## cell centre bracketed by two off-board tails, so every husk lands on the road.
##
## THAT ARGUMENT USED TO END "and nothing may ever be planted on the road", which was
## true for eight plants and stopped being true the day the Barrier Bramble arrived
## (PlantCatalog.on_road). The invariant it rested on is gone; the guarantee is not,
## because the branch below now sweeps FIRST on any road cell rather than relying on
## would_plant_at() being false there. Two halves, and they cover different ground:
##
##   * On grass, the old argument still stands unchanged — a husk cannot land there, so
##     the preview's promise ("if you see the brackets, the click plants it") is intact
##     everywhere it was ever made. PlacementPreview.husk_click_margin() is that claim
##     as a number and test_placement still gates it: the nearest a husk can come to
##     GRASS a plant may stand on is 32 px, four clear of the 28 px sweep.
##   * On road, the sweep wins outright. A husk is already-earned seeds and a Bramble
##     can be planted a pixel to either side, so the cheap mistake is the one to make
##     impossible.
## `snap` is true only for the release of a touch DRAG (see `_touch_dragged`). It changes
## nothing about a mouse click or a tap, and its branch sits at the very top of the ladder
## below on purpose: a finger that has been dragging with a placement ghost under it has
## been shown one promise the whole way, and every branch it skips — the compost sweep,
## the select, the lapsed-move grace — would answer that promise with something else.
func _click_at(screen_pos: Vector2, snap: bool = false) -> void:
	# BOARD-LOCAL, and it has to be. This guard used to read
	# `screen_pos.y < Hud.BAR_HEIGHT or screen_pos.x > board.board_size().x` — an absolute
	# screen coordinate compared against a board-LOCAL width, which was correct for exactly
	# as long as the board started at (0, BAR_HEIGHT) and silently wrong the moment
	# `_apply_board_layout` began centring it. At a 1387-wide canvas the board sits at
	# x = 117, so the old test rejected every click on its rightmost 117 px and ACCEPTED
	# clicks in the left gutter, where `world_to_cell` returns a negative cell.
	#
	# That failure is invisible in a screenshot: the board draws perfectly and a strip of it
	# just stops responding. Found by reading the guard, not by looking at the picture — the
	# same lesson `Board.cell_to_global`'s header records.
	# A FAITHFUL translation of the old test into board-local space, not a tightening.
	# It deliberately does NOT reject `local.x < 0` or a y past the board's bottom: the
	# husk branch below is reached from here on purpose, and `Board._build_route` brackets
	# the road with an off-board entry and exit whose husks belong to no cell and are still
	# the player's to collect. Rejecting the whole off-board area would have taken those
	# with it — which is what the first draft of this guard did.
	var local: Vector2 = screen_pos - _entities.position
	if local.y < 0.0 or local.x > board.board_size().x:
		return
	var cell: Vector2i = board.world_to_cell(local)
	# THE SNAPPED RELEASE, above everything (plant-tower-defense-bmis). Only when the
	# resolver actually moved the cell: a drag that ends over a perfectly good cell falls
	# straight through and is handled by the ladder below exactly as it always was, so a
	# drag onto a plant to select it, or onto a husk that no placement wanted, is
	# untouched.
	#
	# NOT WHILE AN UPROOT IS ARMED. That window owns the click outright (see the branch
	# further down) and the question it is asking is "move it here?", not "buy one here?".
	# The cue the player has been watching is the move preview, and `snapped_placement_cell`
	# filters on `would_plant_at`, which is about buying.
	if snap and not uproot_armed():
		var aimed: Vector2i = snapped_placement_cell(local)
		if aimed != cell:
			_commit_placement(aimed)
			return
	# Ahead of the is_inside() guard below, exactly where the sweep has always
	# been: Board._build_route brackets the road with an off-board entry and exit,
	# a Corn Cobbler can shoot a pest standing on either, and the husk that drops
	# there belongs to no cell at all. It is still the player's to collect.
	# `or board.is_path(cell)` is the Barrier Bramble's amendment to the rule the header
	# above states, and the header has been rewritten to match. On GRASS nothing changed:
	# the preview's promise still holds, because a husk never lands on grass. On the ROAD
	# the sweep now goes first, and it has to — a road cell can hold a husk AND accept a
	# Bramble at the same time, and without this the first click on a husk in a lane the
	# player is walling plants a Bramble on top of it and the husk is gone unrefunded.
	#
	# Costs the placement nothing, because collect_at() returns 0 when no husk is in
	# range: a road click with nothing to sweep falls straight through to place_plant().
	if not would_plant_at(cell) or board.is_path(cell):
		var swept: int = compost.collect_at(local)
		if swept > 0:
			bank.add_seeds(swept)
			# CONFIRM: the husk vanished from the board on this same click and the seed
			# counter moved. Deliberately SHORTER than the settings toggles above despite
			# being a longer sentence — see Hud.message_seconds, where this exact pair is
			# the evidence that these durations are not derived from length.
			hud.show_message("Composted a husk for %d seeds." % swept,
				Hud.message_seconds(Hud.ROLE_CONFIRM))
			return
	if not board.is_inside(cell):
		return
	# THE ARMED WINDOW'S THIRD ENDING (plant-tower-defense-h5w6). Above the
	# select-or-place branches on purpose: while an uproot is armed the player is already
	# being shown what the plant would reach from wherever they hover, and the two
	# branches below would answer that preview by selecting a different plant or buying a
	# second one. Whichever cell they click, the question they are answering is "move it
	# here?" — so this consumes the click first and reports its own refusal.
	if uproot_armed():
		var moved: String = commit_move(cell)
		if moved == "":
			return
		if moved == "not paid for":
			# The bar slot for THIS plant's kind, which is the thing on screen that names
			# what they were trying to spend on — the same shake place_plant's refusal
			# gets, for the same reason.
			hud.shake_plant_button(selected_placed.kind)
			return
		if moved != "it is already there":
			hud.show_message(Hud.as_sentence(moved) + ".")  # message-corpus-check: ok - move refusals are assembled at runtime, not written here
			return
		# Clicking the plant's own cell is not a refusal worth a line: it is what a player
		# does when they change their mind, and the armed window already says how to
		# cancel. Fall through so the click still selects, exactly as it did before.
	var existing: Plant = plant_at(cell)
	if existing != null:
		_select(existing)
		_refresh()
		return
	# THE CLICK THAT ARRIVED ONE MOMENT LATE (plant-tower-defense-b9bl). Below the
	# select branch, so clicking another plant still selects it — that is unambiguous and
	# never a move. Above `place_plant`, because the whole point is not to buy.
	#
	# Consumed either way. A grace that survived its own refusal would refuse the player's
	# next genuine purchase too, and they would have no way to buy but to wait it out.
	if _move_lapsed_left > 0.0:
		_move_lapsed_left = 0.0
		hud.show_message(Hud.move_window_closed_tip(),
			Hud.message_seconds(Hud.ROLE_CONFIRM))
		return
	_commit_placement(cell)


## Buy the selected plant for `cell`, say why not, and leave the cue on screen truthful.
##
## Split out of `_click_at`'s tail so the snapped release can reach it without either
## restating the refusal handling or falling through branches it has already been shown
## past (plant-tower-defense-bmis). Two callers, one behaviour: a snapped drag and an
## ordinary click that reached the bottom of the ladder buy in exactly the same way, and
## a refusal reads the same however the cell was chosen.
## Put the shop pick back to NONE, and say whether that changed anything.
##
## The bool is what the right-click branch consumes the event on: a gesture that cleared
## something was this gesture, and one that cleared nothing was not. See `selected_plant`.
func disarm_plant() -> bool:
	if selected_plant == &"":
		return false
	selected_plant = &""
	# The bar's armed ring and the board's brackets are both downstream of `_refresh()`
	# and `_update_preview()` respectively, and neither notices a field changing under it.
	# Without this the ring stays lit on a plant that is no longer armed, which is worse
	# than the no-cue state this whole bead is about -- a wrong cue outranks a missing one.
	_refresh()
	if _hover_cell.x >= 0:
		_update_preview(_hover_cell,
			board.is_buildable_for(_hover_cell, selected_plant) and not _plants.has(_hover_cell))
	return true


func _commit_placement(cell: Vector2i) -> void:
	var refusal: String = place_plant(selected_plant, cell)
	# PLANTED, SO NOTHING IS ARMED (plant-tower-defense-vvmy). Only on the empty string --
	# every other return is a refusal, and a refusal keeps the pick so the player's next
	# move is to try again rather than to go back to the bar. See `selected_plant`.
	#
	# Through `disarm_plant()` and not a bare assignment, because `place_plant()` has
	# ALREADY called `_refresh()` by the time it returns "" -- with the old pick still in
	# the field. Assigning here without a second refresh leaves the bar's armed ring lit
	# on a plant that is no longer armed until the next unrelated state push.
	#
	# Before the refusal branches rather than after them, so the tail's `_update_preview`
	# below redraws against the arm this call actually left behind.
	if refusal == "":
		disarm_plant()
	if refusal == "not paid for":
		# The refusal fired on a board click, not a bar click — pay_for_plant()
		# already told the player why through purchase_failed. What shakes here
		# is the slot they picked the plant from, the one thing on screen that
		# actually names what they were trying to buy.
		hud.shake_plant_button(selected_plant)
	elif refusal != "":
		hud.show_message(Hud.as_sentence(refusal) + ".")  # message-corpus-check: ok - placement refusals are assembled at runtime, not written here
		# AND POINT AT THE PLANT THAT WOULD WORK, when there is exactly one
		# (plant-tower-defense-lyj5). The sentence names the ground; this names the
		# packet, which is the thing the player has to click next.
		#
		# Guarded on the refusal being about the GROUND. "Something is already growing
		# there" has a sole legal plant too -- the cell is grass, but every plant is
		# refused by the occupant -- and shaking a packet there would point at a purchase
		# that is not the problem.
		if refusal == REFUSAL_ON_GRASS or refusal == REFUSAL_ON_ROAD:
			var fits: StringName = sole_legal_plant_for(cell)
			if fits != &"" and fits != selected_plant:
				hud.shake_plant_button(fits)
			elif refusal == REFUSAL_ON_ROAD:
				# THE GRASS DIRECTION (plant-tower-defense-oxf1): `fits` is always
				# &"" here -- the clicked cell is grass (REFUSAL_ON_ROAD only fires
				# when board.is_buildable_for() failed a road-only plant, which on an
				# in-bounds cell means the cell is not path), and sole_legal_plant_for()
				# ties past its second non-road candidate on every grass cell in the
				# catalogue. No packet to point at, so point at the GROUND instead:
				# every road cell, lit until _road_answer_left lapses in _process().
				board.mark_road_answer(board.road_cells())
				_road_answer_left = Hud.message_seconds(Hud.ROLE_NOTICE)
	# The cell under the cursor just changed state — either it now holds a
	# plant, or the purchase drained the seeds that made it affordable. Either
	# way the cue on screen is stale until the mouse moves, which it need not.
	_update_preview(cell, board.is_buildable_for(cell, selected_plant) and not _plants.has(cell))


# -- state ------------------------------------------------------------------


## Recomputes every plant's neighbour buff from the board as it now stands.
##
## Driven from `_refresh()` rather than from Mint itself, and that is the whole design: a
## buff applied by the buffer cannot be UNapplied when the buffer is uprooted, because by
## then there is nothing left to run. Whoever owns the set owns the derived state, so this
## recomputes from scratch every time rather than adding and subtracting deltas — an
## incremental version has to get uproot, destruction, placement and replacement all right,
## and gets no second chance when it does not.
##
## Assigns rather than multiplies into the field, for the same reason weather does: two
## sources writing one number is how the number stops meaning anything. Weather owns
## `fire_interval_scale`, this owns `neighbour_interval_scale`, and `Plant.composed_interval`
## is where they meet.
## Centres the playfield in the space the HUD leaves it, and keeps it centred when the
## window changes shape.
##
## WHY THIS EXISTS. The board is a fixed 896x576 (`Board.COLS * CELL` by `ROWS * CELL`) and
## `_entities` sat at `Vector2(0, BAR_HEIGHT)` — hard against the left edge, forever. At the
## design size that is exactly right and invisible: 896 of board plus 256 of side panel is
## 1152, the whole canvas, with nothing left over.
##
## It stopped being invisible the moment the HUD started laying out against the LIVE
## viewport (plant-tower-defense-0jye). `stretch/aspect="expand"` gives a wide window MORE
## canvas width, the side panel is now correctly pinned to the right edge of it, and the
## board still started at x=0 with a fixed width — so every pixel of the extra width piled
## up in one grey gutter between the playfield and the panel. Reported from a screenshot,
## which is the second time this file has learned something that way (see
## `Board.cell_to_global`'s header for the first).
##
## Note what the old behaviour was actually doing: before -0jye the panel was ALSO in the
## wrong place, at a hardcoded `1152 - PANEL_WIDTH`, so the gutter existed and was hidden by
## a second bug sitting on top of it. Fixing the panel is what made this one visible.
##
## WHAT IT DOES: splits the leftover space evenly instead of dumping it on one side, in both
## axes — horizontally between x=0 and the panel's left edge, vertically between the top bar
## and the bottom of the canvas. `floorf` because a half-pixel offset on a 64px pixel-art
## grid is visible as softening on every sprite at once.
##
## `maxf(0, ...)` because a viewport SMALLER than the board must not push it off the left or
## up under the bar — it clamps to the old behaviour instead, which is the readable failure.
##
## Safe to move because both readers of `_entities.position` already subtract it
## (`_click_at` and `_update_preview`), so the screen-to-cell mapping follows the board
## rather than assuming where it sits. That was checked before this was written, not after.
func _apply_board_layout() -> void:
	if board == null or not is_instance_valid(board) or _entities == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var play: Vector2 = Vector2(view.x - Hud.PANEL_WIDTH, view.y - Hud.BAR_HEIGHT)
	var board_px: Vector2 = board.board_size()
	_entities.position = Vector2(
		floorf(maxf(0.0, (play.x - board_px.x) * 0.5)),
		Hud.BAR_HEIGHT + floorf(maxf(0.0, (play.y - board_px.y) * 0.5)))
	# The bee layer is a sibling of Entities and therefore does NOT inherit this. Given
	# the same origin here, in the one function that knows where the board sits, so a
	# resized window cannot leave bees flying over the side panel.
	if _bees != null and is_instance_valid(_bees):
		_bees.position = _entities.position


## Every Aloe mends the damaged plants it reaches (plant-tower-defense-ibvb).
##
## The ITERATION is here and the decisions are in `Aloe`, for the reason its header spells
## out: `Game` owns `_plants`, and an Aloe reaching for the plant set itself would have to
## ask the tree — which returns a second `Game`'s plants when the suite hosts two scenes at
## once (`.claude/skills/godot-test-isolation`). `Aloe.reaches` and `Aloe.heal_for` are pure
## and static, so the interesting half is assertable with no board at all.
##
## Unlike `_refresh_neighbour_buffs`, this runs per FRAME rather than per change to the
## plant set, and that is the difference between a state and an event: a Mint's buff has to
## be un-applied when the Mint goes, a heal that already happened does not. See Aloe's
## header, which argues that asymmetry rather than leaving it looking like an oversight.
##
## `delta` is already scaled by `Engine.time_scale`, so an Aloe repairs at the same rate per
## GAME second whatever speed the player has the garden running at. That is the right answer
## and not an accident of where this sits: at 2x a wave arrives twice as fast, and a heal
## that stayed on wall-clock time would quietly become half as effective for anyone using
## the speed control.
##
## Skipped entirely when no Aloe is planted, which is every board until someone buys one —
## the first loop is over `_plants` and breaks nothing, but the second is not entered at all
## and the common case stays one cheap pass.
func _apply_aloe_healing(delta: float) -> void:
	# CELL -> the amount that Aloe puts back this frame, rather than a list of cells
	# and one shared number. An Amber Aloe (the sport, `PlantMutation`) mends harder
	# than the one beside it, so "how much healing arrives at this plant" stopped being
	# a property of the frame and became a property of the healer.
	var aloes: Dictionary = {}
	for key: Vector2i in _plants:
		var plant := _plants[key] as Plant
		if plant == null or not is_instance_valid(plant) or plant.is_destroyed():
			continue
		if plant is Aloe:
			aloes[key] = Aloe.heal_for(delta, plant.sport_power_scale())
	if aloes.is_empty():
		return
	for key: Vector2i in _plants:
		var plant := _plants[key] as Plant
		if plant == null or not is_instance_valid(plant) or plant.is_destroyed():
			continue
		for from_cell: Vector2i in aloes:
			var amount: float = float(aloes[from_cell])
			if Aloe.reaches(from_cell, key):
				# `Plant.heal` already refuses a destroyed or full-health plant and clamps
				# at MAX_HEALTH, so two Aloes overlapping one Corn heal it twice as fast up
				# to full and never past it. Deliberately NOT capped at one Aloe per plant:
				# stacking support is the same decision Mint already lets the player make.
				plant.heal(amount)


func _refresh_neighbour_buffs() -> void:
	refresh_neighbour_buffs_over(_plants)


## The whole body of `_refresh_neighbour_buffs`, over a cell -> Plant dictionary
## (plant-tower-defense-b0mp). `Game._plants` and `RunSim.plants` are the same shape and
## this differed from `RunSim._refresh_neighbour_buffs` only in that variable's name, so
## the mint-buff rule itself now lives in exactly one place.
##
## STATIC AND CALLED FROM BOTH DRIVERS, exactly like `weather_seed_value_for` above.
static func refresh_neighbour_buffs_over(plants: Dictionary) -> void:
	# suite-reach-check: ok - extracted mirror body (plant-tower-defense-b0mp); reached at
	# runtime through `_refresh_neighbour_buffs` on both `Game` (via `_refresh`, called from
	# `_install_plant`) and `RunSim` (via `_install`), every time either side places a plant.
	# A direct unit test naming this symbol is left for a follow-up, as with `kill_payout`.
	var mints: Dictionary = {}
	for key: Vector2i in plants:
		var plant := plants[key] as Plant
		if plant == null or not is_instance_valid(plant) or plant.is_destroyed():
			continue
		if plant is Mint:
			# A sport Mint counts TWICE, which is the whole of its buff — see
			# `PlantMutation`'s MINT row for why that rides in the same `power` key
			# as every other sport's multiplier rather than in a third key only one
			# plant uses. `Mint.scale_for` is unchanged and still answers "what does
			# N Mints' worth of neighbour do", which is now a question a single plant
			# can be the whole of.
			var worth: int = int(round(plant.sport_power_scale()))
			for cell: Vector2i in Mint.neighbours_of(key):
				mints[cell] = int(mints.get(cell, 0)) + worth
	for key: Vector2i in plants:
		var plant := plants[key] as Plant
		if plant == null or not is_instance_valid(plant):
			continue
		# A Mint beside a Mint buffs nothing: neither of them fires, so the number would
		# be real and unobservable. Skipping it keeps `scale_for` honest as the answer to
		# "what does this plant's interval get multiplied by" rather than to "how many
		# Mints are adjacent", which are different questions the moment one is a Mint.
		plant.neighbour_interval_scale = (1.0 if plant is Mint
			else Mint.scale_for(int(mints.get(key, 0))))


func _refresh() -> void:
	_refresh_neighbour_buffs()
	# Ahead of the hud guard, not after it. The road's off-aim marks are the one
	# part of a refresh that is not the HUD's, and the headless suite drives a Game
	# with no HUD at all — putting this below the return would make the board's
	# second reading the only readout in the run that cannot be tested without one.
	#
	# Cheap enough to sit on the same funnel as the HUD: uncovered_road_cells() is
	# one 126-cell sweep per engaging plant, and mark_unaimed_road() returns early
	# without repainting when the set has not moved, which is every refresh except
	# the ones where a plant was bought, uprooted or eaten.
	if board != null and is_instance_valid(board):
		board.mark_unaimed_road(uncovered_road_cells())
		# The dead-ground marks read the garden's unlocks, so they move when a packet
		# is opened -- not only when the cursor moves. Same funnel and the same
		# early-return discipline as mark_unaimed_road above.
		_refresh_dead_ground()
		# The preview's new-cover dots read the same set, and pushing it only from
		# _update_preview would leave them stale whenever the garden changes while
		# the cursor is STILL — a plant eaten mid-wave, an uproot committing, a
		# purchase from the bar. That is the one error this cue must not make,
		# because it is read as "spend seeds here": either marking ground as bare
		# that a plant now covers, or failing to mark ground that just became bare.
		# Only while it is on screen; a hidden preview has nothing to repaint.
		if _preview != null and is_instance_valid(_preview) and _preview.visible:
			_preview.covered_now = covered_road_cells()
			_preview.queue_redraw()
		# A held plant eaten or uprooted leaves a freed reference behind; cleared here
		# rather than at each death path, because this is the one funnel every one of
		# them already runs through.
		if _held_over != null and not is_instance_valid(_held_over):
			_held_over = null
	if hud == null:
		return
	hud.refresh(state())
	# AFTER hud.refresh, not before. The tip names a price the player is about to go
	# looking for, so the readouts it will be compared against — the seed count above
	# all — must already show this refresh's numbers. Posting first would put the
	# message on screen a frame ahead of the balance that justifies it.
	_maybe_teach_upgrading()


## One dictionary describing the whole run. The HUD renders it, the devtools
## `game_state` verb returns it, and the tests assert on it.
func state() -> Dictionary:
	return {
		"bank": bank,
		"seeds": bank.seeds,
		"wave": director.current_wave,
		"wave_count": director.wave_count(),
		"wave_live": _wave_live,
		"prep_left": _prep_left,
		"prep_total": prep_seconds,
		"more_waves": director.has_more_waves(),
		"next_threat_level": WaveDirector.threat_level(maxi(1, director.current_wave + 1)),
		# The wave AFTER the one just cleared, described for the prep gap. Unlike
		# `weather`, which is the weather Game is holding, these are deliberately
		# derived for `current_wave + 1` -- the whole point is to say what has not
		# happened yet.
		"next_wave_pests": WaveDirector.pests_in_wave(director.current_wave + 1),
		"next_wave_boss": WaveDirector.wave_carries_boss(director.current_wave + 1),
		"next_weather": WaveDirector.weather_for(director.current_wave + 1),
		# Endless has no last wave, so the flag is false there by construction rather
		# than by a comparison that happens to never be true.
		"next_wave_is_last": (not director.endless
			and director.current_wave + 1 == WaveDirector.WAVES.size()),
		"lives": lives,
		"selected_plant": selected_plant,
		"selected_placed": selected_placed,
		"uproot_armed": uproot_armed(),
		"plants": _plants.size(),
		"pests_alive": get_tree().get_nodes_in_group("pests").size(),
		"can_start_wave": not _wave_live and director.has_more_waves() and not game_over and not victory,
		"game_over": game_over,
		"victory": victory,
		"endless": director.endless,
		"seeds_earned_total": bank.seeds_earned_total,
		"high_score": RunConfig.best_for(director.endless),
		"compost_total": compost.total_collected,
		"pests_defeated": pests_defeated,
		"run_seconds": run_seconds,
		"husks_on_ground": compost.husk_count(),
		"threat": WaveDirector.threat_for(maxi(1, director.current_wave)),
		"threat_level": WaveDirector.threat_level(maxi(1, director.current_wave)),
		# The weather Game is HOLDING, not weather_for(current_wave). Between waves
		# the wave number has already moved to the one that has not started, so
		# deriving it here would show the next wave's weather during the prep gap --
		# announcing a drought before it applies to anything.
		"weather": weather,
		# The speed the PLAYER chose, and its two rendered forms. The HUD keeps no
		# second copy of any truth (see hud.gd), so the button's face and its tooltip
		# are handed to it the same way every other readout is.
		#
		# `GameSpeed.scale()` and not `Engine.time_scale`: while the pause card is up
		# they differ on purpose, and the button must keep saying what the player
		# picked rather than flicking to "1x" behind a card that is covering it.
		"game_speed": GameSpeed.scale(),
		"game_speed_label": GameSpeed.label(),
		"game_speed_tooltip": GameSpeed.button_tooltip(),
		"autostart_waves": autostart_waves,
	}



# -- budgets ----------------------------------------------------------------
#
# Four constants in this project carry a "moving me costs you X" doc comment, and
# every one of the X's lives in a different file. `Game.budget_entries()` prices
# all six couplings and reports what is left of each -- but reading it means being
# in the game already, so the one person who will never read it is the person who
# is about to spend one.
#
# So the pricing lives here, on the run itself, and the run reads it once at
# startup. `cmd budgets` calls budget_entries() rather than measuring anything of
# its own, the same way board_info and budgets both call
# PlacementPreview.husk_click_budget(): one arithmetic, so the verb and the
# warning cannot report different headroom for the same board.
#
# What is NOT priced here is the two couplings a run cannot price cheaply or at
# all. The notebook subheading needs a NotebookScreen the run never builds -- it
# is a title-screen subscreen, and the verb stands one up inside a throwaway
# SubViewport to measure it, which is a whole UI built and thrown away on the
# frame the player is waiting through, to check a sentence that is a constant and
# a font and therefore cannot change between two launches of the same build.
# test_the_budgets_notebook_entry_measures_the_sentence_the_screen_draws already
# fails on it, headless, every /verify. The road's shape has no ceiling to
# subtract from at all. Both stay in devtools_ext/commands.gd and are built
# through GameBudget's constructors, so their grading is still this grading.
#
# THE WHOLE SUBSYSTEM MOVED TO `game/game_budget.gd` (class `GameBudget`,
# plant-tower-defense-2dlh -- the game.gd split). See that file's own header for
# why this was the safe first cut out of a 4630-line file: every function in it
# either takes its live state (`board`, `hud`) as a PARAMETER instead of reading
# `self`, or needed no live state at all -- it was already written `static`,
# just parked on the wrong class. Everything below is a one-line forward. NO
# CALLER'S SURFACE CHANGED: `Game.BUDGET_FLOOR`, `Game.computed_budget(...)`,
# `game.budget_entries(...)`, `game.budget_report`, `game.warn_new_floors(...)`
# and every other symbol `devtools_ext/commands.gd` and `test/unit/*.gd`
# reference by these exact names still resolve exactly as before the split.

## See GameBudget.BUDGET_TIGHT_FRACTION for why 0.15.
const BUDGET_TIGHT_FRACTION: float = GameBudget.BUDGET_TIGHT_FRACTION
## See GameBudget.BUDGET_WAVE_SWEEP for why 120.
const BUDGET_WAVE_SWEEP: int = GameBudget.BUDGET_WAVE_SWEEP
## See GameBudget.BUDGET_UNMEASURED / BUDGET_DESCRIBED for the distinction.
const BUDGET_UNMEASURED: String = GameBudget.BUDGET_UNMEASURED
const BUDGET_DESCRIBED: String = GameBudget.BUDGET_DESCRIBED
## See GameBudget.BUDGET_SPENT_BY_DESIGN.
const BUDGET_SPENT_BY_DESIGN: String = GameBudget.BUDGET_SPENT_BY_DESIGN
## See GameBudget.BUDGET_FLOOR -- the full per-entry reasoning now lives there.
const BUDGET_FLOOR: Dictionary = GameBudget.BUDGET_FLOOR
## See GameBudget.BUDGET_SLIP.
const BUDGET_SLIP: float = GameBudget.BUDGET_SLIP
## See GameBudget.BUDGET_FLOOR_ACCEPTED -- keep this in sync by letting the
## startup warning tell you, exactly as GameBudget's own comment says.
const BUDGET_FLOOR_ACCEPTED: Array[String] = GameBudget.BUDGET_FLOOR_ACCEPTED
## See GameBudget.PACKET_RACK_WHEN_FULL.
const PACKET_RACK_WHEN_FULL: String = GameBudget.PACKET_RACK_WHEN_FULL

## The startup budget read, as check_budgets() left it. Empty until it runs.
##
## Kept rather than recomputed because the devtools status provider reports it on
## every single bus reply, and pricing four budgets -- including a 120-wave sweep
## -- per reply would make reading the game more expensive than playing it. It is
## a report of what startup found, and it says so.
var budget_report: Dictionary = {}


## Forwards to GameBudget.check_budgets(board, hud). Called once from _ready().
func check_budgets() -> Dictionary:
	budget_report = GameBudget.check_budgets(board, hud)
	return budget_report


## Forwards to GameBudget.budget_entries(board, hud, sweep). Kept as an instance
## method (not moved wholesale) because devtools_ext/commands.gd and
## test/unit/*.gd call it as `game.budget_entries(...)` on a live instance.
func budget_entries(sweep: int = GameBudget.BUDGET_WAVE_SWEEP) -> Array[Dictionary]:
	return GameBudget.budget_entries(board, hud, sweep)


## Forwards to GameBudget.warn_new_floors(entries). Kept as an instance method
## because test/unit/test_selftest.gd calls it as `game.warn_new_floors(entries)`.
func warn_new_floors(entries: Array[Dictionary]) -> String:
	return GameBudget.warn_new_floors(entries)


static func new_floor_warning(at_floor: Array[String], accepted: Array[String]) -> String:
	return GameBudget.new_floor_warning(at_floor, accepted)


static func budgets_at_floor(entries: Array[Dictionary]) -> Array[String]:
	return GameBudget.budgets_at_floor(entries)


static func budget_regressions(entries: Array[Dictionary]) -> Array[String]:
	return GameBudget.budget_regressions(entries)


static func computed_budget(id: String, constant: String, declared_in: String, spends: String,
		spent: float, ceiling: float, units: String, measured_by: String,
		when_it_runs_out: String, observations: Array[String],
		by_design: bool = false) -> Dictionary:
	return GameBudget.computed_budget(id, constant, declared_in, spends, spent, ceiling,
		units, measured_by, when_it_runs_out, observations, by_design)


static func uncomputed_budget(state: String, id: String, constant: String, declared_in: String,
		spends: String, why: String, when_it_runs_out: String,
		observations: Array[String]) -> Dictionary:
	return GameBudget.uncomputed_budget(state, id, constant, declared_in, spends, why,
		when_it_runs_out, observations)


static func no_budget_observations() -> Array[String]:
	return GameBudget.no_budget_observations()


static func budget_number(value: float) -> String:
	return GameBudget.budget_number(value)
