class_name Sfx
extends RefCounted

## One place that owns sound. Every noise the game makes goes through `play()`.
##
## The game shipped completely silent: four player-facing cues (uproot arming,
## plant damage, threat escalation, mutation markers) landed across two cycles
## and not one of them made a sound. The worst of it was silent death — a compost
## husk rotting away unclaimed erased itself with no cue at all, so "you were too
## slow" and "there was never a husk there" looked and sounded identical.
##
## Shaped after GardenTheme: a `class_name` with static state and static entry
## points, so a call site never has to find an instance, and one documented
## headless gate (`audio_enabled()`, the analogue of
## `GardenTheme.animations_enabled()`) that every path asks before it makes noise.
##
## Deliberately NOT an autoload. The pool below parents itself to the scene tree
## root on first use, which gives it the two things an autoload would have given
## it — a place in the tree and survival across `reload_current_scene()` — without
## adding a name to `project.godot` that `class_name Sfx` would then collide with.

# -- the sound table --------------------------------------------------------
#
# Event ids are StringNames so a call site is a constant, not a spelled-out
# path. Most files below are CC0 Kenney audio vendored under assets/audio; the
# four written for this game (PEST_KILLED, CORN_FIRED, PLANT_PLACED,
# PLANT_CHOSEN) are not Kenney's. See the License.txt beside them, which now says which is which —
# the blanket "everything here is CC0" it used to say stopped being true the
# moment a second source landed in the directory.

const PLANT_PLACED := &"plant_placed"
const PLANT_BITTEN := &"plant_bitten"
const PLANT_DESTROYED := &"plant_destroyed"
const PEST_KILLED := &"pest_killed"
## The same kill, when it was a hard one. A SECOND ID rather than a pitch argument on
## `play()`: the pitch table is keyed by event, and an override at the call site would make
## every existing caller a place where a caller could disagree with the table — which is
## exactly what `tune_voice` was extracted to prevent (cycle 74).
const PEST_KILLED_HARD := &"pest_killed_hard"
const PEST_ESCAPED := &"pest_escaped"
const HUSK_COLLECTED := &"husk_collected"
const HUSK_ROTTED := &"husk_rotted"
const WAVE_STARTED := &"wave_started"
## A wave surviving rather than a wave arriving -- see WAVE_STARTED's own SOUNDS
## comment for why it does not simply reuse that bell (plant-tower-defense-d2a).
const WAVE_CLEARED := &"wave_cleared"
const UPROOT_ARMED := &"uproot_armed"
const RUN_WON := &"run_won"
const RUN_LOST := &"run_lost"
## A purchase SeedBank refused — not enough seeds, a locked plant, an empty
## packet. Every one of those reasons already reaches hud.show_message(); this
## is the one thing that used to reach nothing at all. See Game._ready, where
## bank.purchase_failed is the single place this plays from, so every refusal
## gets the same cue regardless of which of the four call sites emitted it.
const PURCHASE_DENIED := &"purchase_denied"
## The instant any plant's upgrade lands (Plant.upgrade()) — a cue for the
## transaction itself, not just next volley's wider fan. See corn_cobbler.gd's
## _upgrade_flourish() for the sprite half of this.
##
## It plays from Plant.upgrade() rather than from the flourish since cycle 101,
## which is a fix and not a move: the flourish is behind
## GardenTheme.animations_enabled(), so an upgrade was SILENT for any player who
## had animations turned off, and nothing pinned that silence.
const PLANT_UPGRADED := &"plant_upgraded"
## A plant deliberately dug up (Game.commit_uproot), as opposed to
## PLANT_DESTROYED's "a hungry pest ate it" — the player chose this one.
const PLANT_UPROOTED := &"plant_uprooted"
## The three attacking plants' own act, as opposed to the pest-side reaction
## cues above (PEST_KILLED, PLANT_BITTEN) that already covered how a pest
## answers being hit. Before these, a Corn Cobbler volleying five kernels, a
## Chomp Flower snapping shut or a Sundew catching a pest made no sound at all
## on the attacker's end — every existing combat cue centralised on the pest.
const CORN_FIRED := &"corn_fired"
const CHOMP_BITE := &"chomp_bite"
const SUNDEW_CLAIM := &"sundew_claim"
## The Bomb Dandelion's two halves, and they are two cues rather than one
## because they happen at two different places at two different times: a seed
## leaves the head, and SeedBomb.FLIGHT_SECONDS later it bursts somewhere else. A
## single "fired" cue would put the whole event at the plant, which is precisely
## the half of it the player is NOT meant to be watching.
const DANDELION_PUFF := &"dandelion_puff"
const SEED_BOMB_BURST := &"seed_bomb_burst"
## A Nettle stinging a mutated pest (`Nettle._sting`) — the only damaging act in
## the game with nothing in flight, so without a cue the sole evidence a Nettle
## did anything is the victim's own hit flash, which looks identical to a kernel
## landing from a cob three cells away.
##
## **A VARIANT, not a new voice, and the reason is what the file already means.**
## `impactSoft_medium_002.ogg` is not Corn's sound: it is this pack's generic soft
## impact, and two events already sit on it from opposite sides of the exchange —
## PLANT_BITTEN at −8.0 (a pest's mouth closing) and this sting. CORN_FIRED used to
## be the third and has since moved to its own `shoot.wav`, which leaves this cue as
## the pair's other half rather than as one of three; a second position on that same
## scale extends a statement the table is already making, and does not borrow an
## identity. The refused
## alternative was another vendored file: the palette is a small fixed set of
## voices on purpose (see PITCH's header), and a timbre nobody else in the game shares would
## make the loudest new thing in the mix a plant that deals 3.0 damage every 0.7s
## and is dead weight until `WaveDirector.MUTATION_START_WAVE`. A specialist's
## tick should sound like a smaller version of a hit, which is exactly what a
## variant is for.
const NETTLE_STING := &"nettle_sting"
## A HUD button acknowledging the click itself, before whatever it went on to
## do. Only the two presses that answered with nothing of their own use it —
## "Grow the next wave" and the plant bar; see Game._on_next_wave_requested for
## which buttons are deliberately left to their own outcome cues, and why a
## refusal must stay PURCHASE_DENIED rather than becoming a press plus a denial.
const BUTTON_PRESSED := &"button_pressed"
## Picking a packet out of the plant bar — the gesture that ARMS a placement, as
## opposed to PLANT_PLACED's soil closing over one several seconds later. Split
## off BUTTON_PRESSED once the bar became a drag as well as a click (see
## Game._on_plant_chosen): the bar is the only control in the game a player can
## hold, and a hold answered by the same blip every other button makes says the
## thing in their hand is a button rather than a plant.
const PLANT_CHOSEN := &"plant_chosen"
## A Sunflower paying out (Sunflower.grew_seeds -> Game._on_plant_grew_seeds).
## The other half of HUSK_COLLECTED: both are seeds arriving, one swept off the
## ground by hand and one grown on a clock — see SOUNDS for why they share a
## stream and VOLUME_DB for why this one sits under it.
const SEEDS_GROWN := &"seeds_grown"

## event -> the stream it plays. This dictionary is the whole contract: an event
## not in here is inaudible, and test_combat asserts every path in it actually
## loads, because a typo'd path fails in the most literal way sound can — by
## being silent, which is exactly what the game already sounded like.
const SOUNDS: Dictionary = {
	# Its own file, written for this game: soil closing over a seedling. It used to
	# be Kenney's grass footstep, which PLANT_UPROOTED and DANDELION_PUFF still
	# wear — the reverse of this act, and a seed head letting go, are both rustles,
	# and this one no longer has to be.
	PLANT_PLACED: "res://assets/audio/plant-place.ogg",
	PLANT_BITTEN: "res://assets/audio/impactSoft_medium_002.ogg",
	PLANT_DESTROYED: "res://assets/audio/chop.ogg",
	# The first cue in this table written FOR this game rather than borrowed from a
	# general-purpose pack: a bug taking the hit, not a generic soft impact. See
	# License.txt for where it came from and why the Kenney claim no longer covers
	# the whole directory.
	PEST_KILLED: "res://assets/audio/hit-received.wav",
	# The SAME impact, deliberately: a hard kill is the same event, landing harder. A
	# different file would say "a different thing happened", and what happened is a kill.
	# The pitch below is what carries "harder", and `test_no_two_events_are_the_same_sound`
	# is what stops the two collapsing into one sound.
	PEST_KILLED_HARD: "res://assets/audio/hit-received.wav",
	PEST_ESCAPED: "res://assets/audio/error_002.ogg",
	HUSK_COLLECTED: "res://assets/audio/handleCoins.ogg",
	HUSK_ROTTED: "res://assets/audio/minimize_006.ogg",
	WAVE_STARTED: "res://assets/audio/impactBell_heavy_002.ogg",
	# Reuses RUN_WON's jingle rather than vendoring a fourth file: a wave
	# cleared is a small version of the same beat a run won is, so it wears the
	# same instrument, trimmed quieter (see VOLUME_DB) so the real win still
	# lands as the loudest cheer in the game (plant-tower-defense-d2a).
	WAVE_CLEARED: "res://assets/audio/jingles-pizzicato_00.ogg",
	UPROOT_ARMED: "res://assets/audio/question_002.ogg",
	RUN_WON: "res://assets/audio/jingles-pizzicato_00.ogg",
	RUN_LOST: "res://assets/audio/bong_001.ogg",
	# Reuses PEST_ESCAPED's stream rather than vendoring a second file: this
	# project's audio pack has exactly one thing in it that already means
	# "no" — see assets/audio/License.txt, which now names both consumers.
	PURCHASE_DENIED: "res://assets/audio/error_002.ogg",
	# Reuses WAVE_STARTED's bell rather than vendoring a third file: both are
	# "something changed for the better" beats, and they never sound in the
	# same breath — a wave starts in the calm between purchases.
	PLANT_UPGRADED: "res://assets/audio/impactBell_heavy_002.ogg",
	# Kenney's grass footstep, which is the only soft rustle in the borrowed
	# palette and is what a plant leaving the soil is — the reverse of PLANT_PLACED,
	# which has since moved onto a planting sound of its own. Shares the file with
	# DANDELION_PUFF and is told apart from it by volume (see VOLUME_DB).
	PLANT_UPROOTED: "res://assets/audio/footstep_grass_000.ogg",
	# Its own file, and the second cue written for this game: a kernel leaving the
	# cob is the one sound in here a borrowed impact never really carried, because
	# an impact is a landing and this is a launch. PLANT_BITTEN keeps the soft
	# impact the two used to share — see NETTLE_STING for who is left on it.
	CORN_FIRED: "res://assets/audio/shoot.wav",
	# Reuses PLANT_DESTROYED's stream — both are a chomp, just aimed the other
	# way: a Chomp Flower's own bite instead of a hungry pest's.
	CHOMP_BITE: "res://assets/audio/chop.ogg",
	# Reuses UPROOT_ARMED's stream — a light chime for a catch that only slows,
	# not the heavier PEST_KILLED impact a Sundew never earns since it never kills.
	SUNDEW_CLAIM: "res://assets/audio/question_002.ogg",
	# Reuses PLANT_UPROOTED's grass footstep, the only soft rustle this pack
	# vendored — and a seed head letting go of its fluff is a rustle rather than an
	# impact. Told apart from an uprooting by level (see VOLUME_DB) and by the fact
	# that an uprooting happens once, by hand, and this happens two or three times
	# a second from a plant already on the board.
	DANDELION_PUFF: "res://assets/audio/footstep_grass_000.ogg",
	# Kenney's heavy soft impact, the largest thing left in the borrowed palette
	# once PEST_KILLED moved onto its own file. Deliberately NOT following the kill
	# over: a burst is a blast going off, a kill is a bug being hit, and a burst
	# that kills plays this AND that in the same frame — which is right, a blast
	# that took something down should sound bigger than one that only clipped it.
	SEED_BOMB_BURST: "res://assets/audio/impactSoft_heavy_000.ogg",
	# Reuses PLANT_BITTEN's soft impact — the second position on that file now that
	# CORN_FIRED has its own, and the one that actually lands on a pest. See
	# NETTLE_STING's own comment for why this is a variant rather than another
	# vendored voice; the pitch and the volume below are what make it one.
	NETTLE_STING: "res://assets/audio/impactSoft_medium_002.ogg",
	# Reuses HUSK_COLLECTED's coins for the same reason the flying glyph reuses
	# the husk's gold: seeds arriving are seeds arriving, and a second currency
	# sound for the same currency would say they were different things.
	SEEDS_GROWN: "res://assets/audio/handleCoins.ogg",
	# Reuses HUSK_ROTTED's stream, which is the one interface blip this pack
	# vendored (Kenney's "minimize"): everything else in the table is a bell, an
	# impact, a chime or a jingle, and a button that rang any of those would be
	# claiming to be an event. The two are told apart by level and by place — a
	# husk rots quietly out on the board at -6, a press answers the cursor.
	BUTTON_PRESSED: "res://assets/audio/minimize_006.ogg",
	# Its own file rather than BUTTON_PRESSED's blip: this is a click AND a drag
	# (Game._unhandled_input's touch branch), so it is the one control whose cue
	# has to survive being held. See the id's own comment above.
	PLANT_CHOSEN: "res://assets/audio/clickanddrag.ogg",
}

## Per-event trim, in dB, for the handful that are not level with the rest.
## Absent means 0.0. Ambience (a bite, a husk rotting) sits under the events the
## player is meant to react to; the two run-enders sit slightly under everything
## because they play alone with nothing to compete with.
const VOLUME_DB: Dictionary = {
	PLANT_BITTEN: -8.0,
	HUSK_ROTTED: -6.0,
	PEST_KILLED: -3.0,
	PEST_KILLED_HARD: -1.5,
	RUN_WON: -4.0,
	RUN_LOST: -4.0,
	# Under RUN_WON's own -4.0, not level with it: this is the same jingle, so
	# the run-won trim alone would leave the two indistinguishable by ear and
	# the wave-to-wave cue as loud as the once-a-run one.
	WAVE_CLEARED: -9.0,
	# Under HUSK_COLLECTED's 0.0, same stream: a sweep is something the player
	# did and wants confirmed, a Sunflower payout arrives on its own clock every
	# six seconds per flower whether or not anyone was watching. Ambience, not
	# an answer to an act.
	SEEDS_GROWN: -7.0,
	# The quietest thing in the table, and it has to be. Game.start_next_wave()
	# reaches WaveDirector.wave_started synchronously, so the press cue and
	# WAVE_STARTED's bell sound in the SAME frame — this is meant to read as the
	# click under that bell, not as a second event competing with it.
	BUTTON_PRESSED: -10.0,
	# Under PLANT_UPROOTED's 0.0, same stream: an uprooting is a thing the player
	# did and wants confirmed, a seed leaving a head is the plant working on its own
	# clock two or three times a volley. Ambience, not an answer to an act — the
	# same split SEEDS_GROWN makes against HUSK_COLLECTED.
	DANDELION_PUFF: -9.0,
	# Under PEST_KILLED's -3.0, so a burst that killed something is audibly bigger
	# than the burst alone. The two stopped sharing a stream when the kill moved to
	# `hit-received.wav`; the ordering is what carried the meaning, not the file, so
	# the number stays where it was.
	SEED_BOMB_BURST: -6.0,
	# The upper rung of the two events left on impactSoft_medium_002.ogg, and the
	# position is the whole point: this is one plant's contact hit on the cell beside
	# it, and PLANT_BITTEN at -8.0 is a pest chewing in the background. It stays
	# under CORN_FIRED's 0.0 volley, which now announces itself on its own file — a
	# sting is smaller than a volley and larger than a chew, so it sounds that way
	# rather than being trimmed to whatever was free.
	NETTLE_STING: -5.0,
}

## Shortest gap between two plays of the SAME event, in milliseconds. Absent
## means DEFAULT_REPEAT_MS.
##
## This is not politeness, it is the difference between a cue and a mess: five
## pests dying in one frame play the identical sample five times, which stacks in
## phase and comes out as one much louder sound rather than five deaths. It also
## does the throttling for `Plant.take_damage`, which a hungry pest calls every
## physics frame — the chew is one repeating nibble here rather than sixty a
## second, and the call site stays a single unguarded `Sfx.play()`.
## The palette's third axis, and the one that separates a loss from a no-op.
##
## 25 named beats share 15 audio files, which is a palette rather than a problem —
## a small set of voices used deliberately. What was a problem is two events arriving at
## the player *identically*: `play()` composes exactly the stream, the volume and
## (now) the pitch, so before this table `PEST_ESCAPED` and `PURCHASE_DENIED` were
## the same `error_002.ogg` at the same 0.0 dB, and `PLANT_DESTROYED` and
## `CHOMP_BITE` were the same `chop.ogg` at the same 0.0. **A pest reaching the
## house costs a life; a refused purchase costs nothing**, and a plant dying was
## indistinguishable from a plant eating.
##
## Volume alone would have satisfied the rule and answered the wrong question: a
## quieter version of a sound is the same event, smaller — which is exactly what
## `WAVE_CLEARED` means by wearing `RUN_WON`'s jingle at −9.0, and exactly not what
## an escape means next to a refusal. Pitch says *a different thing happened*.
##
## **Losses go lower, gains go higher, and the routine event of a pair keeps the
## base.** Every entry here shares a file with at least one event that has no row here
## and therefore sits at exactly 1.0, and this entry is that sound moved off the base in
## the direction of what it means. The magnitudes are graded by how grave the event is —
## losing a life is the furthest down, a warning the least — so the table reads as a
## scale rather than seven arbitrary numbers.
##
## `test_no_two_events_are_the_same_sound` gates the uniqueness and cannot see the
## direction. **`PITCH_GRADE` below is where the direction is written down**, and
## `test_the_pitch_scale_points_the_way_its_grades_say` is what holds these numbers to
## it — so this paragraph is now a summary of an assertion rather than the only place
## the rule exists. Read that table before adding an eighth entry; an entry added here
## and not graded there fails the suite.
##
## Found by deriving the (file, volume, pitch) triples rather than by listening:
## three of the five collisions were invisible to a hand-read of the table, and the
## test named the third one after the first two had already been fixed.
const PITCH: Dictionary = {
	# Losses, gravest first.
	PEST_ESCAPED: 0.72,
	PLANT_DESTROYED: 0.78,
	PLANT_UPROOTED: 0.82,
	# A warning rather than a loss: the shallowest step down, because nothing has
	# happened yet and the player can still walk away.
	UPROOT_ARMED: 0.88,
	# Gains, and the only entries above the base.
	PLANT_UPGRADED: 1.18,
	# A harder kill is a bigger gain, so it sits above the plain kill rather than below it.
	# Modest on purpose: a kill is the most frequent sound in the game and a wide interval
	# would turn a wave into a melody.
	PEST_KILLED_HARD: 1.12,
	# The shallowest step up in the table, because it is the smallest gain in the game:
	# 3.0 damage off one pest, not a kill and not a permanent upgrade. So the gains column
	# reads as a scale — a sting under a hard kill under an upgrade — the same way the
	# losses above it do. Up rather than down because damage dealt is a gain; thin rather
	# than blunt because a sting is a needle and a kernel is not, which is the half of this
	# number `test_the_gains_read_as_a_scale` cannot see.
	NETTLE_STING: 1.08,
}

## event -> which way it means, as a signed rank. Negative is something going wrong,
## positive is something going right, and the MAGNITUDE is the gravity order the block
## above claims: −4 is the gravest thing in the table and +3 the largest gain. **These
## are ranks, not pitches.** Only their sign and their order carry anything; the gaps
## between them mean nothing and nothing reads their absolute value.
##
## **This is the one judgement call in the whole pitch scale, written down beside the
## entries rather than left in prose or copied into a test.** Whether a pest reaching the
## house is a loss and a Nettle's sting is a gain is not derivable from anything in this
## project. There is no ledger of what an event costs the player, and the only currency
## that spans both columns is seeds — which prices `PLANT_UPGRADED` as a LOSS, since
## upgrading is the one entry here the player actually pays for. A derivation off the
## sign of `PITCH` itself would be the table agreeing with itself. So this is recorded,
## and the check asserts the PROPERTY it claims rather than its membership:
## `test_the_pitch_scale_points_the_way_its_grades_say` requires every `PITCH` key to be
## graded here and every graded key to be in `PITCH`, each sign to match its side of 1.0,
## and — within a column — a graver rank to sit strictly further from 1.0. Retune a pitch
## without moving its rank, or add an eighth entry pointing the wrong way, and it is red.
##
## `PITCH` is the tuned number; this is the intent behind it; the test is that the two
## agree. Neither half can say the intent is RIGHT — that is what a listener is for (see
## `JITTER`'s "NOBODY HAS HEARD THIS"), and it is why this is a rank and not a second
## opinion about how many cents a life is worth.
const PITCH_GRADE: Dictionary = {
	# The losses, gravest first, and the order is the order of what stays gone. A life
	# never comes back; a plant a pest ate was paid for and is off the board; a plant the
	# player dug up was their own decision and hands part of itself back.
	PEST_ESCAPED: -4,
	PLANT_DESTROYED: -3,
	PLANT_UPROOTED: -2,
	# Down because it POINTS at a loss, not because one has happened — nothing is gone
	# yet and the player can still walk away, which is what makes it the shallowest step
	# down in the table. Its `PITCH` row says the same thing about the number.
	UPROOT_ARMED: -1,
	# The gains, smallest first: 3.0 damage off one pest, then a kill that was expensive
	# enough to be worth calling out, then a permanent upgrade. The same order the three
	# `PITCH` rows above already spell out one at a time.
	NETTLE_STING: 1,
	PEST_KILLED_HARD: 2,
	PLANT_UPGRADED: 3,
}

## event -> the half-width of its per-play pitch wobble, in `pitch_scale` units.
## Absent means 0.0, and a cue with no row here sounds exactly as it always has.
##
## **The fourth tuning table, and the first that varies WITHIN one event.** `SOUNDS`,
## `VOLUME_DB` and `PITCH` each say what an event sounds like; this says how far the Nth
## play of it may sit from the N−1th. What it answers is machine-gun sameness — the
## identical sample at the identical pitch, arriving faster than the ear stops hearing the
## repeats as one texture. `REPEAT_MS` above answers the OTHER half of that complaint and
## cannot answer this one: a gate stops N calls in one frame becoming a single much louder
## sound, and it is deliberately shorter than the rate any source actually fires at, so
## every consecutive volley still plays. Two plays 620ms apart is exactly what the gate is
## there to permit, and exactly what sounds like a machine gun for thirty seconds.
##
## **The membership rule, so this is a derivation and not a taste list: a row here belongs
## to a cue that ONE source repeats faster than about once a second.** Each entry is that
## claim backed by the constant that makes it true.
##
##   * `CORN_FIRED` — `CornCobbler.LEVELS[2]["interval"]` is 0.62s, and four Mints take a
##     single cob to 0.62 * 0.75^4 = 0.196s. Several cobs on a board multiply that again.
##   * `PEST_KILLED` / `PEST_KILLED_HARD` — not one source but the whole board, so the 70ms
##     gate above IS the rate; a volley landing on a cleared wave spends it.
##   * `PLANT_BITTEN` — the 420ms gate is likewise the rate, sustained for as long as a pest
##     is eating, which is the most relentless repetition in the game.
##   * `DANDELION_PUFF` — `Dandelion.SHOT_INTERVAL` is 0.45s.
##   * `NETTLE_STING` — `Nettle.STING_INTERVAL` is 0.7s, with a 221ms floor under four Mints
##     (the arithmetic is written out at that event's `REPEAT_MS` row).
##   * `SEED_BOMB_BURST` — one Dandelion's bombs land `SHOT_INTERVAL` apart; a row of them
##     spends the 90ms gate.
##
## **And what is absent because the rule excludes it, not because nobody thought of it.**
##
##   * The UI acknowledgements — `BUTTON_PRESSED`, `PLANT_CHOSEN`, `PURCHASE_DENIED`,
##     `UPROOT_ARMED`. A click that wobbles does not read as variety, it reads as a fault
##     in the button.
##   * Everything once-a-run or once-a-wave: `RUN_WON`, `RUN_LOST`, `WAVE_STARTED`,
##     `WAVE_CLEARED`, `PLANT_PLACED`, `PLANT_UPGRADED`, `PLANT_UPROOTED`, `PLANT_DESTROYED`,
##     and `SEEDS_GROWN` at one per flower per six seconds. There is nothing for them to vary
##     against, and a cue heard once a run should be exactly what it was authored as.
##   * `CHOMP_BITE`, which is the near miss worth naming rather than passing over.
##     `ChompFlower.BITES_PER_MEAL` is 3 and a gaping maw chews an aphid in 0.45 * 0.65 =
##     0.29s, so its bites are ~97ms apart — fast enough by the rule above. It is out because
##     a Chomp holds ONE pest at a time: the burst is three sounds and then silence, not a
##     stream. Adding the row is a one-line opt-in and it costs one existing assertion; see
##     `test_a_wobbled_cue_stays_inside_the_band_its_row_promises` for which.
##   * `HUSK_COLLECTED`, which is player-paced, and whose pitch was the subject of
##     plant-tower-defense-l69v — closed unimplemented, and the reasoning there is the
##     reason this row is empty rather than an oversight.
##
## **The magnitudes.** 0.04 is about 0.68 of a semitone at the peak and 1.4 peak-to-peak:
## enough that two plays cannot land in phase as one louder sound, too little to hum. The
## kill pair gets 0.03 instead, and it is the one number here carrying a second constraint —
## the whole distance between a plain kill and a hard one is 0.12 in `PITCH`, held small on
## purpose (see `PEST_KILLED_HARD`'s comment), so a wobble here spends the interval that
## carries "that one was expensive". 0.03 a side leaves 0.06 of clear air between the bands.
##
## **NOBODY HAS HEARD THIS.** The rates above are measured off the game's own constants; the
## claim that the sameness is audible, and that these widths fix it without turning a wave
## into a warble, is an argument from those numbers and not a listening test — see
## plant-tower-defense-r8zc. A listener who disagrees edits rows, not code: an event opts out
## by deleting its row and the whole feature opts out by emptying the table.
const JITTER: Dictionary = {
	CORN_FIRED: 0.04,
	PLANT_BITTEN: 0.04,
	DANDELION_PUFF: 0.04,
	NETTLE_STING: 0.04,
	SEED_BOMB_BURST: 0.04,
	PEST_KILLED: 0.03,
	PEST_KILLED_HARD: 0.03,
}

## How much clear air two events sharing BOTH a file and a volume must leave between their
## pitch bands, once `JITTER` has widened each centre in `PITCH` into a range.
##
## This constant is the whole reason `JITTER` did not quietly break the uniqueness rule.
## `test_no_two_events_are_the_same_sound` keys on the triple (file, volume, pitch) and so
## asserts the TABLE is unique; with a wobble on top, two events 0.04 apart in `PITCH` could
## still arrive at the player identically on some pair of plays, and that check would never
## see it. So the table check keeps its job and a second one asserts the RANGES are disjoint
## by at least this much — see `test_two_events_on_one_file_never_overlap_once_they_wobble`.
##
## 0.04 rather than 0.0 because touching bands are not a separation anyone can hear. The
## tightest same-file same-volume pair in the table today is `UPROOT_ARMED` (0.88) against
## `SUNDEW_CLAIM` (1.00), and neither is wobbled, so the live margin is the full 0.12; this
## is the budget a future row has to fit inside rather than a limit anything is near.
const MIN_TWIN_PITCH_GAP: float = 0.04

const DEFAULT_REPEAT_MS: int = 45
const REPEAT_MS: Dictionary = {
	PLANT_BITTEN: 420,
	PEST_KILLED: 70,
	PEST_KILLED_HARD: 70,
	HUSK_ROTTED: 200,
	# A row of Sunflowers planted in the same breath comes due in the same
	# frame forever after — INTERVAL is a constant, so their clocks never drift
	# apart on their own. Without this, four flowers pay out as one sound four
	# times as loud rather than as four payouts.
	SEEDS_GROWN: 200,
	# A row of Dandelions comes due together for the same reason a row of
	# Sunflowers does — Dandelion.SHOT_INTERVAL and FLUFF_REGROW_SECONDS are
	# constants, so heads planted in the same breath stay in phase forever. One
	# plant's own volley is SHOT_INTERVAL (450ms) apart and never touches these
	# gaps; three plants firing in one frame would otherwise be one sound three
	# times as loud rather than three seeds.
	DANDELION_PUFF: 120,
	SEED_BOMB_BURST: 90,
	# Derived from the Nettle's own numbers rather than copied off a row above.
	# `Nettle.sting_interval()` is `STING_INTERVAL` (0.7s) composed with the sky and
	# the neighbours, and only ONE of those two can make it shorter: drought is 2.0
	# (`WaveDirector.WEATHER_DROUGHT_INTERVAL_SCALE`, slower) and a Mint is 0.75 per
	# adjacent cell with at most four of them (`Mint.NEIGHBOUR_OFFSETS`). So the
	# floor for a single Nettle is 700 * 0.75^4 = 221ms, and 200 sits under it: no
	# board a player can build loses one of a lone Nettle's own stings to this gate.
	# What it does collapse is a BANK of them — STING_INTERVAL is a constant, so
	# Nettles planted in the same breath come due in the same frame forever after,
	# the same phase-lock DANDELION_PUFF and SEEDS_GROWN are gated for, and a wave-8
	# swarm walking past four of them would otherwise machine-gun one sample into a
	# single much louder noise. `test_a_bank_of_nettles_cannot_machine_gun_the_sting`
	# pins the 200 against those constants, so retuning either one fails the suite
	# instead of quietly re-arming the problem.
	NETTLE_STING: 200,
}

## How many sounds can overlap. A tower defense's loudest moment is a volley
## landing on a cleared wave — several pests dying, a husk dropping and a plant
## firing inside the same handful of frames — so a single AudioStreamPlayer (one
## stream, a second `play()` cuts the first) would drop all but the last of them.
## Eight voices covers that without one player per event id, which would have
## made overlap of the SAME event impossible while still costing a node each.
const POOL_SIZE: int = 8


# -- the mixer --------------------------------------------------------------
#
# THE DIAL, and the reason it is a BUS rather than a per-voice trim.
#
# `VOLUME_DB` above is the composition: what a sting is worth NEXT TO a kernel,
# tuned over four cycles and written down as a scale. The player's dial is a
# different quantity entirely -- how loud that whole composition is in the room
# -- and folding the two into one number would mean every future cue's author
# has to remember to ask about a preference before it can be heard. A bus is set
# once and everything routed through it is already asking.
#
# It also puts the two categories on separate faders for free, which is what the
# player actually wants: `Music` sends its beds to its own bus (`Music.BUS_NAME`)
# and reads the same LEVELS table below, so "turn the music down but leave the
# game audible" is two independent numbers rather than one master that cannot
# express it. The two mutes were split for exactly this reason at cycle 74 (see
# `Music._muted`); a single master dial would re-make that mistake one axis over.
#
# Both buses are created at runtime rather than in a `default_bus_layout.tres`.
# There is no bus layout in this project and adding one is a binary resource that
# no reader of this file would find; `ensure_bus` below is idempotent, so the
# game, a test and a headless lint can each ask for it without coordinating.

## The bus every one-shot cue plays on. `Music` has its own; see the block above.
const BUS_NAME := &"Sfx"

## The dial's steps, as linear amplitudes, LOUDEST FIRST.
##
## Index 0 is full, exactly the way `GameSpeed.STEPS[0]` is `NORMAL` -- so the
## default is `0`, the shipped mix is bit-for-bit what it was before the dial
## existed, and the persisted field reads `svol0` beside the four other zeros on
## `RunConfig`'s preferences line rather than as a magic 3.
##
## **NOTHING HERE IS ZERO, and that is the whole answer to "a dial at zero is a
## mute".** Two independent ways to silence one category is a state machine
## nobody asked for: the mute key would have to stash the level it silenced and
## put it back, and a level of 0 saved with the mute off is a player who has no
## idea why their game is quiet. So silence stays exactly one thing -- the mute,
## which is on a key, on the Options screen, and in the save already -- and the
## dial only ever chooses between four audible levels. Unmuting therefore always
## lands back on the level the player chose, with nothing remembered anywhere.
##
## Four steps rather than a continuous slider for the same reason `GameSpeed` has
## three: the control is a row button that cycles, so every value is reachable by
## pressing, reportable as a word, and assertable as an index.
const LEVELS: Array[float] = [1.0, 0.75, 0.5, 0.25]

## The step a level this build has no entry for falls back to. FULL, deliberately:
## a save from a later build with more steps is READ and KEPT (see
## `RunConfig.MAX_LEVEL_STEP`) and refused at the point of use, and the safe
## reading of "a volume I cannot interpret" is the one the game shipped with, not
## silence.
const DEFAULT_LEVEL: int = 0

static var _muted: bool = false
## Which entry of LEVELS this bus is set to. The live twin of
## `RunConfig.sfx_level`, exactly as `_muted` is the live twin of
## `RunConfig.mute_sfx`: this one is what the mixer is doing, that one is what
## the file records, and `RunConfig.set_sfx_level` is the only supported writer of
## the pair.
static var _level: int = DEFAULT_LEVEL
static var _host: Node = null
static var _voices: Array[AudioStreamPlayer] = []
static var _next_voice: int = 0
## event -> AudioStream, or null for "asked once, not loadable". Cached either
## way so a missing file costs one failed lookup for the whole session.
static var _streams: Dictionary = {}
## event -> Time.get_ticks_msec() of its last actual play.
static var _last_played: Dictionary = {}
## event -> how many times it has ACTUALLY played this process, which is the index
## `pitch_for` wobbles by. Advanced only past the repeat gate, so a throttled call does
## not burn a step of the sequence and the count means "how many times a player heard
## this" rather than "how many times something asked".
##
## Never reset, including across `reload_current_scene()`, and that matches `_last_played`
## beside it: both describe the speaker rather than the run. A replayed board carrying on
## from index 4137 is the same sequence of wobbles either way — see `jitter_offset` for why
## the sequence has no period worth landing on.
static var _play_count: Dictionary = {}


# -- the gate ---------------------------------------------------------------


## The headless gate, the same shape and for the same reason as
## `GardenTheme.animations_enabled()`.
##
## Headless does still have an audio server, so this is not strictly required to
## avoid an error — but the test runner drives hundreds of gameplay calls with no
## one listening, `--mute` is already set in devtools_config.json, and a pool of
## AudioStreamPlayers spun up inside a unit test is a scene-tree side effect that
## test teardown would then have to know about. Silence is the correct behaviour
## for a game nobody can hear.
static func audio_enabled() -> bool:
	return not _muted and not is_headless()


static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


## Whether the player can currently hear anything. The project-level mute, which
## is separate from the engine's `--mute` the harness launches with: that one is
## a command-line flag the player cannot reach, this one is a runtime toggle
## (Game binds it to M) and it does not disturb the audio buses, so a muted run
## and a `--mute`d run stay independently controlled.
static func is_muted() -> bool:
	return _muted


## Returns the new state, so a caller can report it without asking again.
static func set_muted(value: bool) -> bool:
	_muted = value
	if _muted:
		stop_all()
	else:
		# The bed is the one sound that is not re-fired by the next thing that
		# happens: a wave already under way asks for it exactly once, at each spawn.
		# Without this, unmuting mid-wave leaves the garden silent until the next
		# pest walks on. See `_resume_ambience`.
		_resume_ambience()
	return _muted


static func toggle_muted() -> bool:
	return set_muted(not _muted)


# -- the dial ---------------------------------------------------------------
#
# Static and pure wherever it can be, for the reason `should_play` is: whether a
# sound was AUDIBLE is not observable headlessly, so the tests assert on the
# state that drives playback. Here that state is a real `AudioServer` bus, which
# IS readable headless -- `AudioServer.get_bus_volume_db` answers on the dummy
# driver -- so unlike `play()` the whole path from a level index to the number
# the mixer is holding can be pinned by a headless test.
#
# **`AudioServer` bus state is PROCESS-GLOBAL.** A test that moves it must stash
# and restore, the same rule `Engine.time_scale` earned in `GameSpeed`. Adding a
# bus is not undone by anything here, deliberately: `ensure_bus` is idempotent by
# name, so the cost of a suite that touched it is one bus that was going to exist
# the moment the game launched anyway.
#
# **THESE TWO BUSES ARE WHY `audio/general/default_playback_type.web` IS PINNED TO 0
# (Stream) IN `project.godot`, and that line is a shipped-bug fix, not tidying.**
#
# Godot's default on Web is Sample playback: instead of the engine mixing and handing
# the browser one buffer, every `AudioStreamPlayer` is baked to a WebAudio AudioBuffer
# and routed through one GainNode chain per `AudioServer` bus, in the browser's own
# node graph. A bus that exists before the audio driver starts is mirrored into that
# graph once. A bus added at RUNTIME -- which is exactly what `ensure_bus` below does,
# and the whole reason there is no `default_bus_layout.tres` -- is mirrored with a
# backwards edge. Read off the deployed itch.io build, live:
#
#     Gain#0 -> Gain#1 -> Gain#2 -> AudioDestination     Master              correct
#     Gain#4 -> Gain#5 -> Gain#6 -> Gain#0               Sfx -> Master       correct
#     Gain#2 -> Gain#4                                   Master OUT -> Sfx IN   WRONG
#     Gain#7 -> Gain#8 -> Gain#9 -> Gain#4               Music -> Sfx           WRONG
#     Gain#2 -> Gain#7                                   Master OUT -> Music IN WRONG
#
# `#0 -> #1 -> #2 -> #4 -> #5 -> #6 -> #0` is a closed loop and every gain in it is
# 1.0, so the signal re-circulates and sums forever. Peak amplitude at the destination,
# against a full scale of 1.0: **1.18 at 18s, 50.5 at 131s, 78.8 at 140s** -- real audio
# (RMS 28.3, 671 zero crossings in a 2048-sample window), just seventy-eight times too
# loud and still climbing. A player got a few seconds of correct sound and then a wall
# of clipping. Desktop was never affected: desktop is already Stream and never builds
# that graph at all, which is why every gate in this repo and every headless test passed
# throughout.
#
# The fix is the project setting, not a rewrite here: on Stream the mix goes out through
# the engine's own AudioWorkletNode -- the node that measured exactly 0.0000 for the whole
# session, because under Sample nothing was using it. The cyclic Gain graph is still
# built and still cyclic; with no source feeding it, it is silent.
#
# **So do not "simplify" this by dropping the project setting**, and be careful adding a
# third bus: the mis-wiring is a property of adding buses after driver start, so a fourth
# category would join the same loop the moment web went back to Sample playback.


## The index of `bus_name`, creating the bus if this process has not got one yet.
## Returns -1 if the bus could not be made -- `AudioServer.set_bus_name` silently
## uniquifies a name that collides, so the index is read back BY NAME rather than
## assumed to be the one just added.
##
## Lives here rather than in a third file that both `Sfx` and `Music` import.
## `Music` already delegates `is_headless()` to this class for the same reason:
## two static functions do not earn a `class_name` of their own, and a file named
## for one of the two categories is a worse home for the shared half than the file
## that already owns the sound system.
static func ensure_bus(bus_name: StringName) -> int:
	var existing: int = AudioServer.get_bus_index(bus_name)
	if existing >= 0:
		return existing
	AudioServer.add_bus(-1)
	var added: int = AudioServer.bus_count - 1
	if added < 0:
		return -1
	AudioServer.set_bus_name(added, String(bus_name))
	# Explicitly onto the master bus rather than left to whatever `add_bus`
	# defaulted to: a bus that sends nowhere is silent, and silence is the one
	# failure this whole file is written to avoid being able to ship quietly.
	AudioServer.set_bus_send(added, AudioServer.get_bus_name(0))
	return AudioServer.get_bus_index(bus_name)


## The amplitude a step means, in dB. Pure, so the mapping is assertable without
## a bus, a game or a tree -- and so the one place a level becomes a number is a
## function rather than a line inside a setter.
##
## An index this build has no step for reads as `DEFAULT_LEVEL` (full) rather
## than erroring: see that constant, and `RunConfig.apply_game_speed` for the same
## rule one preference over.
static func level_db(index: int) -> float:
	var step: int = index if (index >= 0 and index < LEVELS.size()) else DEFAULT_LEVEL
	return linear_to_db(LEVELS[step])


## What the row on the Options screen says. Derived from LEVELS rather than
## spelled out beside it, so a fifth step cannot arrive with no name.
static func level_text(index: int) -> String:
	var step: int = index if (index >= 0 and index < LEVELS.size()) else DEFAULT_LEVEL
	return "%d%%" % int(round(LEVELS[step] * 100.0))


## The next step, wrapping. The row button's whole behaviour, as a pure function
## of the current index — same shape as `GameSpeed.STEPS` cycling, and split out
## for the same reason `Sfx.kill_event_for` is: a ternary at the call site is a
## decision no test can watch.
static func next_level(index: int) -> int:
	if LEVELS.is_empty():
		return DEFAULT_LEVEL
	var step: int = index if (index >= 0 and index < LEVELS.size()) else DEFAULT_LEVEL
	return (step + 1) % LEVELS.size()


## Puts a level onto a bus and reports the dB it actually wrote, so a caller (or
## a test) never has to read the mixer back to find out what happened. Returns
## `NAN` when the bus could not be made — a mixer that is not there is not a
## volume of zero.
static func apply_bus_level(bus_name: StringName, index: int) -> float:
	var bus: int = ensure_bus(bus_name)
	if bus < 0:
		push_warning("Sfx: no audio bus '%s' — that category's level cannot be set." % [bus_name])
		return NAN
	var db: float = level_db(index)
	AudioServer.set_bus_volume_db(bus, db)
	return db


## The one-shot cues' own level. Returns the step it is now on, so a caller can
## report it without asking again — the shape every setter in this project uses.
static func set_level(index: int) -> int:
	_level = index
	apply_bus_level(BUS_NAME, _level)
	return _level


static func level() -> int:
	return _level


static func cycle_level() -> int:
	return set_level(next_level(_level))


## The entire decision behind a `play()`, as a pure function of its inputs.
##
## Split out because whether a sound was AUDIBLE is not observable headlessly,
## so the tests assert on this instead — the state that drives playback. An
## unknown event is false here rather than an error: a cue whose id was renamed
## should go quiet, not take the frame down with it.
static func should_play(event: StringName, muted: bool, headless: bool) -> bool:
	if not SOUNDS.has(event):
		return false
	return not muted and not headless


# -- playing ----------------------------------------------------------------


## Plays `event` if anything can hear it. Returns true only if a voice actually
## started, so a caller (or a test) can tell "played" from every reason it did
## not — muted, headless, unknown id, missing file, still inside the repeat gap.
##
## Never errors and never throws. Sound is decoration on a game that has to keep
## running without it, so every failure below is a `false` and a silence.
static func play(event: StringName) -> bool:
	if not should_play(event, _muted, is_headless()):
		return false
	var now: int = Time.get_ticks_msec()
	var gap: int = int(REPEAT_MS.get(event, DEFAULT_REPEAT_MS))
	if _last_played.has(event) and now - int(_last_played[event]) < gap:
		return false
	var stream: AudioStream = stream_for(event)
	if stream == null:
		return false
	var voice: AudioStreamPlayer = _take_voice()
	if voice == null:
		return false
	_last_played[event] = now
	var index: int = int(_play_count.get(event, 0))
	_play_count[event] = index + 1
	voice.stream = stream
	tune_voice(voice, event, index)
	voice.play()
	return true


## Which kill sound a pest has earned, from what it cost to deal with.
##
## A pure static rather than a ternary at the call site, and this is the **fourth** time this
## project has needed that move: `spread_arc_span`, `Hud.uproot_shows_tip`, `tune_voice` and
## now this one all exist because a mutation survived a test that asserted the inputs to a
## decision rather than the decision. Reaching for the seam first is cheaper than earning it.
##
## Takes the multiplier rather than the pest, so it needs no scene, no tree and no Pest at
## all — and so the threshold is the game's own price for a kill rather than a second list of
## which mutations count. A fourth mutation is audible the day it is added.
static func kill_event_for(husk_multiplier: float) -> StringName:
	return PEST_KILLED_HARD if husk_multiplier > 1.0 else PEST_KILLED


# -- the wobble -------------------------------------------------------------
#
# THE COMPOSITION, pulled out into pure statics for the reason `should_play`,
# `tune_voice` and `kill_event_for` were: `play()` is gated off headless, so the only
# thing a suite can ever watch is a function that decides, never a voice that sounds.
# A jitter written inline in `play()` would be a mutation nothing could kill. Written
# as `pitch_for(event, index)` it is a table lookup plus arithmetic, assertable to the
# last decimal with no tree, no pool and no audio server.
#
# **DETERMINISTIC, NOT RANDOM, and the reason is not only testability.** `randf_range`
# would make the pitch of a given play unassertable — a test could bound it, never name
# it, so the difference between "wobbling correctly" and "wobbling at all" would stop
# being a claim anyone can write down. It would also make the sound of a board
# unreproducible, which is the wrong trade for a cue whose whole job is to be heard the
# same way twice by two people comparing notes. So the sequence is a hash of the event id
# and the play index: same event, same index, same pitch, forever, on every machine.
#
# A CYCLING TABLE of offsets was the other candidate and is the one to avoid. A short
# period is exactly what the ear latches onto — a five-entry ring played at 0.196s is a
# five-note phrase at 300bpm, which is the melody `PEST_KILLED_HARD`'s comment warns
# about arriving by a different door. A hash has no period a player will ever reach.
#
# The mixer below is written out here rather than reaching for `hash()` deliberately:
# the engine makes no promise that `hash()` is stable across Godot versions, and a cue's
# wobble sequence changing under a point release is a silent change to what the game
# sounds like. FNV-1a and lowbias32 are both fully specified by the six lines they take.

## Mask that keeps the mixers below in 32 bits. Everything is masked BEFORE each shift,
## so `>>` never sees a negative int64 and never shifts sign bits in.
const HASH_MASK: int = 0xFFFFFFFF


## A 32-bit avalanche (the `lowbias32` finalizer). Low bits of the 64-bit products are
## all that survive the mask, so an overflowing multiply is harmless by construction.
static func _mix32(value: int) -> int:
	var x: int = value & HASH_MASK
	x = ((x ^ (x >> 16)) * 0x7FEB352D) & HASH_MASK
	x = ((x ^ (x >> 15)) * 0x846CA68B) & HASH_MASK
	return (x ^ (x >> 16)) & HASH_MASK


## The seed an event id contributes to its own wobble sequence — FNV-1a over the id's
## characters, so two cues never step through the same offsets in lockstep and neither
## needs a row anywhere to say so.
static func event_seed(event: StringName) -> int:
	var text: String = String(event)
	var acc: int = 2166136261
	for i: int in range(text.length()):
		acc = ((acc ^ text.unicode_at(i)) * 16777619) & HASH_MASK
	return acc


## Where in its band the `index`-th play of `event` lands, as a fraction in [-1.0, 1.0].
##
## Pure and total: every integer index answers, negatives included, and the answer for a
## given pair never changes. This is the function to assert against — a wobble that has
## stopped wobbling shows up here as a constant, which is a red test, where the same
## breakage inside `play()` shows up as nothing at all.
static func jitter_offset(event: StringName, index: int) -> float:
	var mixed: int = _mix32(event_seed(event) ^ _mix32(index))
	return float(mixed) / float(HASH_MASK) * 2.0 - 1.0


## The pitch the `index`-th play of `event` is actually given: its `PITCH` centre, moved
## by at most its `JITTER` half-width.
##
## An event with no `JITTER` row returns its centre EXACTLY, not a centre plus a zero —
## the early return is what lets a reader (and `test_no_two_events_are_the_same_sound`)
## keep reading the `PITCH` table as the literal truth for every cue outside the table
## above.
static func pitch_for(event: StringName, index: int) -> float:
	var centre: float = float(PITCH.get(event, 1.0))
	var width: float = float(JITTER.get(event, 0.0))
	if width <= 0.0:
		return centre
	return centre + width * jitter_offset(event, index)


## The lowest and highest pitch `event` can ever be played at, as `Vector2(low, high)`.
##
## Derived from the same two tables `pitch_for` reads rather than recomputed, so the band
## a check asserts about and the pitch a player hears cannot come apart. This is what
## makes "two events on one file never collide" a claim about ranges instead of about the
## two numbers at their centres.
static func pitch_band(event: StringName) -> Vector2:
	var centre: float = float(PITCH.get(event, 1.0))
	var width: float = maxf(float(JITTER.get(event, 0.0)), 0.0)
	return Vector2(centre - width, centre + width)


## Puts everything except the stream onto a voice — every property that decides
## what an event SOUNDS like, in one place.
##
## Split out of `play()` so a test can watch it work. `play()` itself is gated off
## headless (`should_play` → false), so a headless suite cannot observe it at all,
## and cycle 74 watched a mutation deleting the pitch line survive a test that
## asserted only the tables: `PITCH` stayed unique while nothing read it, and the
## player heard twins again. This is the seam that makes the table's uniqueness
## mean something.
##
## Every property is written unconditionally, including the defaults: voices are
## pooled and reused, so a value left behind by the last event to borrow this voice
## would follow the next one around.
## `index` is which play of this event the voice is for — `play()` passes the event's own
## running count and everything else can leave it at 0. It only reaches `pitch_for`, and
## for a cue with no `JITTER` row it changes nothing at all, which is why every existing
## caller could keep its two arguments.
static func tune_voice(voice: AudioStreamPlayer, event: StringName, index: int = 0) -> void:
	voice.volume_db = float(VOLUME_DB.get(event, 0.0))
	voice.pitch_scale = pitch_for(event, index)
	# THE ROUTING, written here and not in `_ensure_pool`, and that placement is the
	# whole reason the dial is assertable. `play()` is gated off headless by
	# `should_play`, so a suite cannot watch the pool being built — but it can hand
	# this function a bare AudioStreamPlayer and read the bus back, which is what
	# makes "the player's level reaches the thing that makes the noise" a headless
	# claim instead of a hope. Same argument the pitch line above earned in cycle 74.
	#
	# `ensure_bus` first, unconditionally: voices are pooled and a caller (a test,
	# most often) can hand in a player this process has never routed, and assigning a
	# bus name the server does not have leaves the voice on Master with the dial
	# doing nothing to it.
	ensure_bus(BUS_NAME)
	voice.bus = BUS_NAME


## The stream behind an event, or null if there isn't one.
##
## `ResourceLoader.exists` first, then a null-checked `load`: a path that is
## missing, or an .ogg Godot has not imported yet, must degrade to silence rather
## than to a red error in the console. A deliberate choice, and the reason this
## warns rather than `push_error`s — a missing sound file should not be able to
## fail a lint gate or a test run for a game that is otherwise fine.
static func stream_for(event: StringName) -> AudioStream:
	if _streams.has(event):
		return _streams[event] as AudioStream
	var path: String = String(SOUNDS.get(event, ""))
	var stream: AudioStream = null
	if path != "" and ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null:
		push_warning("Sfx: no audio stream for '%s' (%s) — that cue will be silent." % [event, path])
	_streams[event] = stream
	return stream


## Silences every voice — used by mute, and available to a scene teardown. The
## bed goes with them, and `_ambience_wanted` deliberately does NOT: what the
## board wants is not changed by whether the player can hear it, which is what
## lets `set_muted(false)` put the bed back exactly where it was.
static func stop_all() -> void:
	for voice: AudioStreamPlayer in _voices:
		if is_instance_valid(voice):
			voice.stop()
	if _ambience_fade != null and _ambience_fade.is_valid():
		_ambience_fade.kill()
	_ambience_fade = null
	if _ambience_voice != null and is_instance_valid(_ambience_voice):
		_ambience_voice.stop()


## How many voices are currently sounding. Cheap liveness for a devtools status
## provider, and the honest answer to "did anything actually make a noise".
static func voices_playing() -> int:
	var count: int = 0
	for voice: AudioStreamPlayer in _voices:
		if is_instance_valid(voice) and voice.playing:
			count += 1
	return count


# -- the pool ---------------------------------------------------------------


## A free voice, or the oldest one if they are all busy. Stealing rather than
## dropping: when eight sounds are already going, a ninth event is precisely the
## moment something loud is happening, and going quiet then is the wrong answer.
static func _take_voice() -> AudioStreamPlayer:
	if not _ensure_pool():
		return null
	for voice: AudioStreamPlayer in _voices:
		if not voice.playing:
			return voice
	var stolen: AudioStreamPlayer = _voices[_next_voice % _voices.size()]
	_next_voice = (_next_voice + 1) % _voices.size()
	return stolen


## Builds the pool under the scene tree root on first use.
##
## Parented to `root`, not to whatever is playing: a pest that plays its own
## death sound and is then queue_free'd cuts that sound off mid-sample (see
## `Pest._play_death`, which frees the node DEATH_LINGER seconds later). A voice
## that outlives every node it speaks for cannot be cut, and it also survives
## `reload_current_scene()`, which is how the replay button restarts a run.
static func _ensure_pool() -> bool:
	if _host != null and is_instance_valid(_host) and _host.is_inside_tree():
		return true
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null or not is_instance_valid(loop.root):
		return false
	_voices.clear()
	_next_voice = 0
	_host = Node.new()
	_host.name = "SfxPool"
	for i: int in range(POOL_SIZE):
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%d" % i
		_host.add_child(voice)
		_voices.append(voice)
	loop.root.add_child(_host)
	return true


# -- the bed ----------------------------------------------------------------
#
# THE THIRD SHAPE, and why it is neither a `SOUNDS` row nor a `Music` track.
#
# Everything in `SOUNDS` is a one-shot fired at a moment, and every mechanism
# `play()` wraps one in — the repeat gate, the wobble, the voice stealing — is a
# statement about one-shots: how two of the same thing in a frame should sound,
# and which of nine simultaneous cues may be dropped. A bed asks none of those
# and asks one they never do: **when does it stop.** Routed through `play()` it
# would have been a cue re-fired forever that a kill could steal mid-note.
#
# It is not a `Music` track either. `Music` crossfades ONE bed chosen by which
# SCENE the player is in; this one is chosen by what is on the BOARD, rides the
# `Sfx` bus because it is a sound the garden makes rather than a score under it,
# and has to be able to sound while a track is already playing. So it gets its
# own voice — one node, never stolen, outside the pool.

## The bed's file. Not in `SOUNDS` on purpose (see above), and asserted absent
## from it by test, because an id in that table is a cue something must fire.
const AMBIENCE_SOUND := "res://assets/audio/bug-steps.wav"

## Where the bed sits under the cues. Below `PLANT_BITTEN`'s −8.0, the quietest
## continuous thing in `VOLUME_DB`: a chew is one pest at one plant and this is
## the whole board's traffic, so it has to be the floor of the mix or it becomes
## what the player hears instead of the kill they are waiting for.
const AMBIENCE_VOLUME_DB: float = -13.0

## How long the bed takes to arrive and to leave. A cut to silence the instant
## the last pest dies lands on top of that pest's own kill cue and reads as the
## audio dropping out; a fade about as long as a corpse's `Pest.DEATH_LINGER`
## reads as the garden going quiet.
const AMBIENCE_FADE_SECONDS: float = 0.45

## Silence, as a fade target. The same value `Music.SILENT_DB` uses, written here
## rather than reached across so this file's mixer numbers stay in this file.
const AMBIENCE_SILENT_DB: float = -80.0

## What the BOARD wants, independent of whether anything can hear it. Kept across
## a mute so unmuting mid-wave brings the bed back rather than waiting for the
## next pest to spawn — the same split `_muted` makes against `_level`.
static var _ambience_wanted: bool = false
static var _ambience_voice: AudioStreamPlayer = null
static var _ambience_fade: Tween = null
## Loaded once and cached like `_streams`; null for "asked once, not loadable".
static var _ambience_stream: AudioStream = null
static var _ambience_asked: bool = false


## Whether the bed should be sounding, as a pure function of its inputs — the
## `should_play` of the loop, and for the same reason: audibility is not
## observable headlessly, so the tests assert the decision instead.
##
## Takes a COUNT rather than a tree, so the caller decides what counts as a
## walker (`Game.walking_pests` counts pests still alive, not corpses still
## lingering in the group) and this file never has to know what a pest is.
static func should_loop_ambience(walkers: int, muted: bool, headless: bool) -> bool:
	return walkers > 0 and not muted and not headless


## Asks for the bed on or off. Returns whether it is now actually sounding, so a
## caller can tell "the board wants it" from "the player can hear it".
##
## Idempotent, which it has to be: this is called from every spawn and every
## death, many times a wave, and a call that agrees with the current state must
## not restart the loop from its first footfall.
static func set_ambience(active: bool) -> bool:
	_ambience_wanted = active
	if not should_loop_ambience(1 if active else 0, _muted, is_headless()):
		_fade_ambience_out()
		return false
	return _fade_ambience_in()


## Whether a voice is actually carrying the bed right now. The honest answer for
## a devtools status provider, and what a live check asserts.
static func ambience_playing() -> bool:
	if _ambience_voice == null or not is_instance_valid(_ambience_voice):
		return false
	return _ambience_voice.playing


## What the board last asked for, whether or not it is audible.
static func ambience_wanted() -> bool:
	return _ambience_wanted


## The bed's stream. `loop_mode` is expected to come from the .import
## (`edit/loop_mode=2`, and note that **2 is Forward — the importer's 1 is
## "Disabled"**, because its enum starts at "Detect From WAV"; a 1 there imports a
## bed that does not loop and says nothing), which is the only place `loop_end` can
## be set correctly
## without this file guessing at a sample's frame count — but a re-import that
## drops the setting must not silently turn a bed into a one-shot, so this warns
## and `_ensure_ambience_voice` re-fires the voice on `finished` as the degraded
## path. A stream that really loops never emits `finished`, so that connection
## costs nothing when the import is right.
static func ambience_stream() -> AudioStream:
	if _ambience_asked:
		return _ambience_stream
	_ambience_asked = true
	if ResourceLoader.exists(AMBIENCE_SOUND):
		_ambience_stream = load(AMBIENCE_SOUND) as AudioStream
	if _ambience_stream == null:
		push_warning("Sfx: no ambience stream (%s) — the board will be silent." % AMBIENCE_SOUND)
		return null
	var wav := _ambience_stream as AudioStreamWAV
	if wav != null and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		push_warning(("Sfx: %s imported without a loop (edit/loop_mode=2, Forward) — the "
			+ "bed will restart with a seam instead of running unbroken.") % AMBIENCE_SOUND)
	return _ambience_stream


## Whether the bed's own stream loops on its own. False means the seam path above
## is what is carrying it, which is a defect in the .import rather than in this
## file — so it is readable, and a headless test reads it.
static func ambience_stream_loops() -> bool:
	var wav := ambience_stream() as AudioStreamWAV
	if wav == null:
		return false
	return wav.loop_mode != AudioStreamWAV.LOOP_DISABLED


## Starts the bed silent and fades it up. Returns false for every reason it could
## not start, exactly as `play()` does.
static func _fade_ambience_in() -> bool:
	if ambience_stream() == null or not _ensure_ambience_voice():
		return false
	if not _ambience_voice.playing:
		_ambience_voice.volume_db = AMBIENCE_SILENT_DB
		_ambience_voice.play()
	_tween_ambience_to(AMBIENCE_VOLUME_DB, false)
	return true


## Fades the bed out and stops the voice at the end of the fade. Safe to call
## when nothing is playing, which is what every death in an empty garden does.
static func _fade_ambience_out() -> void:
	if not ambience_playing():
		return
	_tween_ambience_to(AMBIENCE_SILENT_DB, true)


## The one place a fade is built, so an in cancels an out and neither leaks a
## Tween. The running one is killed rather than left to finish: two live tweens
## on one `volume_db` is the defect `Music._start_playing` documents.
static func _tween_ambience_to(target_db: float, stop_after: bool) -> void:
	if _ambience_fade != null and _ambience_fade.is_valid():
		_ambience_fade.kill()
	_ambience_fade = null
	if _ambience_voice == null or not is_instance_valid(_ambience_voice):
		return
	if not _ambience_voice.is_inside_tree():
		_ambience_voice.volume_db = target_db
		if stop_after:
			_ambience_voice.stop()
		return
	_ambience_fade = _ambience_voice.create_tween()
	if _ambience_fade == null:
		_ambience_voice.volume_db = target_db
		if stop_after:
			_ambience_voice.stop()
		return
	_ambience_fade.tween_property(_ambience_voice, "volume_db", target_db,
		AMBIENCE_FADE_SECONDS)
	if stop_after:
		_ambience_fade.tween_callback(_ambience_voice.stop)


## The bed's own voice, built beside the pool and outside it. Parented to the
## pool's host, so it survives `reload_current_scene()` for the same reason the
## voices do and goes away with them if the host is ever torn down.
static func _ensure_ambience_voice() -> bool:
	if _ambience_voice != null and is_instance_valid(_ambience_voice) \
			and _ambience_voice.is_inside_tree():
		return true
	if not _ensure_pool():
		return false
	_ambience_voice = AudioStreamPlayer.new()
	_ambience_voice.name = "Ambience"
	_ambience_voice.bus = String(BUS_NAME)
	_ambience_voice.stream = ambience_stream()
	_ambience_voice.volume_db = AMBIENCE_SILENT_DB
	# The degraded path documented on `ambience_stream()`: a stream that really
	# loops never finishes, so this only fires if the import lost its loop.
	_ambience_voice.finished.connect(_on_ambience_finished)
	_host.add_child(_ambience_voice)
	return true


static func _on_ambience_finished() -> void:
	if not _ambience_wanted or not audio_enabled():
		return
	if _ambience_voice != null and is_instance_valid(_ambience_voice):
		_ambience_voice.play()


## Brings the bed back after an unmute, if the board still wants it. Called by
## `set_muted`, the only thing that can silence it without the board having
## changed its mind.
static func _resume_ambience() -> void:
	if _ambience_wanted:
		set_ambience(true)
