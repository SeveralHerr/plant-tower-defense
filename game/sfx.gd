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
# path. Every file below is CC0 Kenney audio vendored under assets/audio; see
# the License.txt beside it for which pack each one came from.

const PLANT_PLACED := &"plant_placed"
const PLANT_BITTEN := &"plant_bitten"
const PLANT_DESTROYED := &"plant_destroyed"
const PEST_KILLED := &"pest_killed"
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
## The instant a Corn Cobbler's upgrade lands (CornCobbler.upgrade()) — a cue
## for the transaction itself, not just next volley's wider fan. See
## corn_cobbler.gd's _upgrade_flourish() for the sprite half of this.
const PLANT_UPGRADED := &"plant_upgraded"
## A plant deliberately dug up (Game.uproot_selected), as opposed to
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
## A HUD button acknowledging the click itself, before whatever it went on to
## do. Only the two presses that answered with nothing of their own use it —
## "Grow the next wave" and the plant bar; see Game._on_next_wave_requested for
## which buttons are deliberately left to their own outcome cues, and why a
## refusal must stay PURCHASE_DENIED rather than becoming a press plus a denial.
const BUTTON_PRESSED := &"button_pressed"
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
	PLANT_PLACED: "res://assets/audio/footstep_grass_000.ogg",
	PLANT_BITTEN: "res://assets/audio/impactSoft_medium_002.ogg",
	PLANT_DESTROYED: "res://assets/audio/chop.ogg",
	PEST_KILLED: "res://assets/audio/impactSoft_heavy_000.ogg",
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
	# Reuses PLANT_PLACED's stream for the reverse of the same act — a plant
	# leaving the soil rather than going into it.
	PLANT_UPROOTED: "res://assets/audio/footstep_grass_000.ogg",
	# Reuses PLANT_BITTEN's stream — the same soft impact, on the other side of
	# the exchange: a kernel leaving the cob instead of a pest's mouth closing.
	CORN_FIRED: "res://assets/audio/impactSoft_medium_002.ogg",
	# Reuses PLANT_DESTROYED's stream — both are a chomp, just aimed the other
	# way: a Chomp Flower's own bite instead of a hungry pest's.
	CHOMP_BITE: "res://assets/audio/chop.ogg",
	# Reuses UPROOT_ARMED's stream — a light chime for a catch that only slows,
	# not the heavier PEST_KILLED impact a Sundew never earns since it never kills.
	SUNDEW_CLAIM: "res://assets/audio/question_002.ogg",
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
}

## Per-event trim, in dB, for the handful that are not level with the rest.
## Absent means 0.0. Ambience (a bite, a husk rotting) sits under the events the
## player is meant to react to; the two run-enders sit slightly under everything
## because they play alone with nothing to compete with.
const VOLUME_DB: Dictionary = {
	PLANT_BITTEN: -8.0,
	HUSK_ROTTED: -6.0,
	PEST_KILLED: -3.0,
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
const DEFAULT_REPEAT_MS: int = 45
const REPEAT_MS: Dictionary = {
	PLANT_BITTEN: 420,
	PEST_KILLED: 70,
	HUSK_ROTTED: 200,
	# A row of Sunflowers planted in the same breath comes due in the same
	# frame forever after — INTERVAL is a constant, so their clocks never drift
	# apart on their own. Without this, four flowers pay out as one sound four
	# times as loud rather than as four payouts.
	SEEDS_GROWN: 200,
}

## How many sounds can overlap. A tower defense's loudest moment is a volley
## landing on a cleared wave — several pests dying, a husk dropping and a plant
## firing inside the same handful of frames — so a single AudioStreamPlayer (one
## stream, a second `play()` cuts the first) would drop all but the last of them.
## Eight voices covers that without one player per event id, which would have
## made overlap of the SAME event impossible while still costing a node each.
const POOL_SIZE: int = 8

static var _muted: bool = false
static var _host: Node = null
static var _voices: Array[AudioStreamPlayer] = []
static var _next_voice: int = 0
## event -> AudioStream, or null for "asked once, not loadable". Cached either
## way so a missing file costs one failed lookup for the whole session.
static var _streams: Dictionary = {}
## event -> Time.get_ticks_msec() of its last actual play.
static var _last_played: Dictionary = {}


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
	return _muted


static func toggle_muted() -> bool:
	return set_muted(not _muted)


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
	voice.stream = stream
	voice.volume_db = float(VOLUME_DB.get(event, 0.0))
	voice.play()
	return true


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


## Silences every voice — used by mute, and available to a scene teardown.
static func stop_all() -> void:
	for voice: AudioStreamPlayer in _voices:
		if is_instance_valid(voice):
			voice.stop()


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
