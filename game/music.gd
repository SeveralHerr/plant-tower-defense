class_name Music
extends RefCounted

## The whole music system: one looping bed at a time, crossfaded between two
## named tracks on scene transitions. Sits beside Sfx (see sfx.gd) rather than
## folding into it -- Sfx is short one-shot cues fired from dozens of call
## sites at fixed volumes; this is a single continuous loop with exactly two
## states, driven from three call sites (TitleScreen, Game's own _ready, and
## the run's own end), so it earns its own small file instead of growing a
## second shape inside Sfx's dictionary.
##
## PLACEHOLDER CONTENT, said plainly rather than shipped quietly. Both tracks
## below are real CC0 Kenney loops (see assets/audio/License.txt) from the
## same "Game Assets All-in-1" bundle the rest of assets/audio/ is vendored
## from -- specifically "Music Loops" (1.1), which ships general-purpose
## instrumental beds with no lyrics, stingers, or game-specific mixing. That
## bundle, and every other CC0/licensed asset source findable on this machine,
## has no track written for a plant-tower-defense game, or for any tower
## defense at all -- so these two are a placeholder pairing chosen for mood
## (title: pastoral and unhurried; run: brisk and a little tense) and NOT a
## claim that either was composed for this game. Swap TRACKS below the day a
## purpose-made theme exists; nothing else in this file should need to change.
##
## Deliberately NOT an autoload, for the same reason as Sfx: the host Node
## parents itself to the SceneTree root on first use, which survives both
## change_scene_to_file() and reload_current_scene() without adding a name to
## project.godot that `class_name Music` would then collide with.

const TITLE := &"title"
const RUN := &"run"

## Track id -> the stream it plays. See the file header above for what these
## two actually are and why.
const TRACKS: Dictionary = {
	TITLE: "res://assets/audio/Farm Frolics.ogg",
	RUN: "res://assets/audio/Mission Plausible.ogg",
}

## Scene path -> the bed that scene plays. Read by play_for_scene(), which is
## what TitleScreen._ready() and Game._ready() actually call -- the bed is
## chosen from *where the player landed*, not asked for by name at each call
## site, so a new scene that wants music only has to add one line here rather
## than remember to call the right play_*() from everywhere it can be reached.
##
## The post-mortem card is deliberately not in this table: it is an overlay
## inside game.tscn, not a scene change, so no scene_file_path names it. See
## Game._end_run, which calls play_title() directly for that one transition.
const SCENE_TRACKS: Dictionary = {
	"res://game/title.tscn": TITLE,
	"res://game/game.tscn": RUN,
}

const BASE_VOLUME_DB: float = -14.0
const SILENT_DB: float = -80.0
const CROSSFADE_SECONDS: float = 1.4

static var _host: Node = null
static var _players: Array[AudioStreamPlayer] = []
static var _active: int = -1
static var _current_track: StringName = &""
## track -> AudioStream, or null for "asked once, not loadable". Same cache
## shape as Sfx._streams, for the same reason: a missing file degrades to
## silence once, not a failed load every crossfade.
static var _streams: Dictionary = {}


# -- pure decision logic (headlessly testable) -------------------------------


## Same shape as Sfx.should_play: whether `track` would actually make sound
## given `muted`/`headless`, with no side effects. Split out so a test can
## assert the decision without a live game -- see the class doc on why this
## file exists at all, and the module doc comment for why headless matters.
static func should_play(track: StringName, muted: bool, headless: bool) -> bool:
	if not TRACKS.has(track):
		return false
	return not muted and not headless


## Which bed a scene plays, or "" for a scene this system has no opinion
## about. Pure, so test_selftest.gd can assert the whole map without
## instantiating either scene.
static func track_for_scene(scene_path: String) -> StringName:
	return SCENE_TRACKS.get(scene_path, &"")


static func is_headless() -> bool:
	return Sfx.is_headless()


## What is (or would be) playing, regardless of mute -- the decision Music has
## made, as opposed to whether anything can currently be heard.
static func current_track() -> StringName:
	return _current_track


# -- playing -------------------------------------------------------------


## The normal entry point: hand it a scene's own scene_file_path and it looks
## up the right bed. An unmapped path is a silent no-op, the same "unknown id
## goes quiet" contract Sfx.should_play documents -- a scene that never asks
## for music should not have to know this system exists.
static func play_for_scene(scene_path: String) -> void:
	var track: StringName = track_for_scene(scene_path)
	if track != &"":
		_play(track)


## Direct override for the one transition that is not a scene change: a
## finished run settling back onto the title bed while the post-mortem card
## is up. See SCENE_TRACKS' doc comment.
static func play_title() -> void:
	_play(TITLE)


## Re-applies the current mute state to whatever is already selected. Call
## this alongside Sfx.toggle_muted() / Sfx.set_muted() -- Music keeps no mute
## flag of its own, it reads Sfx's, so M stays the single switch for every
## sound the game makes instead of growing a second one just for the bed.
static func refresh_mute() -> void:
	if not should_play(_current_track, Sfx.is_muted(), is_headless()):
		stop_all()
		return
	# Coming back from mute: the active player was stopped outright (below),
	# not faded to silence, so resume it the same way rather than crossfading
	# in from a silence that was never actually playing.
	if _active >= 0 and _active < _players.size() and not _players[_active].playing:
		_start(_players[_active], _current_track, BASE_VOLUME_DB)


## Silences every bed outright -- used by refresh_mute() and available to a
## scene teardown, same role as Sfx.stop_all().
static func stop_all() -> void:
	for player: AudioStreamPlayer in _players:
		if is_instance_valid(player):
			player.stop()


static func _play(track: StringName) -> void:
	if track == _current_track:
		return
	_current_track = track
	if not should_play(track, Sfx.is_muted(), is_headless()):
		stop_all()
		return
	if _host == null:
		# The very first call in a run can land mid-frame, while the caller's
		# own scene is still being added to the tree -- exactly what
		# TitleScreen._ready() and Game._ready() do, calling this as close to
		# their own _ready() as they can. SceneTree.root is then still "busy
		# setting up children" and a synchronous add_child() to it fails
		# outright (confirmed live: "ERROR: Parent node is busy setting up
		# children" out of _ensure_host, immediately followed by "Playback
		# can only happen when a node is inside the scene tree" out of
		# _start). One idle frame later root is no longer busy, so only ever
		# the first call -- before _host exists at all -- is deferred; every
		# later crossfade reuses the already-built host and runs synchronously.
		(func() -> void:
			if track == _current_track:
				_start_playing(track)
		).call_deferred()
		return
	_start_playing(track)


static func _start_playing(track: StringName) -> void:
	if not _ensure_host():
		return
	var incoming: int = (_active + 1) % _players.size() if _active >= 0 else 0
	var outgoing: int = _active
	_start(_players[incoming], track, SILENT_DB)
	var tween := _host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(_players[incoming], "volume_db", BASE_VOLUME_DB, CROSSFADE_SECONDS)
	if outgoing >= 0 and outgoing != incoming and is_instance_valid(_players[outgoing]):
		var dying: AudioStreamPlayer = _players[outgoing]
		tween.tween_property(dying, "volume_db", SILENT_DB, CROSSFADE_SECONDS)
		tween.chain().tween_callback(dying.stop)
	_active = incoming


static func _start(player: AudioStreamPlayer, track: StringName, volume_db: float) -> void:
	var stream: AudioStream = _stream_for(track)
	if stream == null:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.play()


## The stream behind a track, or null if there isn't one. `loop` is set here,
## not in the .ogg's import settings, so the file that decides a bed loops is
## the same file that decides which bed plays which scene.
static func _stream_for(track: StringName) -> AudioStream:
	if _streams.has(track):
		return _streams[track] as AudioStream
	var path: String = String(TRACKS.get(track, ""))
	var stream: AudioStream = null
	if path != "" and ResourceLoader.exists(path):
		stream = load(path) as AudioStream
		var ogg := stream as AudioStreamOggVorbis
		if ogg != null:
			ogg.loop = true
	if stream == null:
		push_warning("Music: no audio stream for '%s' (%s) -- that bed will be silent." % [track, path])
	_streams[track] = stream
	return stream


## Builds the two-player host under the scene tree root on first use. Parented
## to root rather than to whatever scene requested the track, for the same
## reason as Sfx._ensure_pool: a scene swap must not cut the bed off mid-note,
## and the host has to survive reload_current_scene() to keep the in-run bed
## running across a mid-wave restart.
static func _ensure_host() -> bool:
	if _host != null and is_instance_valid(_host) and _host.is_inside_tree():
		return true
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null or not is_instance_valid(loop.root):
		return false
	_players.clear()
	_active = -1
	_host = Node.new()
	_host.name = "MusicHost"
	for i: int in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "Bed%d" % i
		_host.add_child(player)
		_players.append(player)
	loop.root.add_child(_host)
	return true
