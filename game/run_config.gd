extends Node

## Autoload. The one thing that has to survive the title-screen -> game.tscn
## scene swap: which mode the player picked, plus the seed high scores and the
## earned milestone flags, all of which by definition have to outlive any single
## run.
##
## `endless` is read once, by Game._ready() wiring it into WaveDirector; the
## title screen is the only writer. The scores are persisted to user:// so they
## are still there next launch, not just next scene — and, since v3 of the save,
## so are the keys the player has moved (see `key_bindings`).
##
## There are two scores because there are two games. The fixed campaign ends
## after WaveDirector's eight-wave table; endless never ends. A campaign total
## and an endless total are therefore not comparable in either direction, and
## sharing one number meant a single endless run permanently retired the campaign
## record — while the title screen labelled that number "Best endless run"
## whichever mode had actually set it.
##
## THE RULE OF THIS FILE: a save we cannot understand leaves the in-memory scores
## alone. Every score in this game is re-earnable by playing except the record of
## having earned it, and `record_score` only ever raises a record — so the instant
## a bad parse writes a 0 into a slot, the next mediocre run refills it and the
## real number is gone with no way back. Silence is recoverable; a zero is not.
## Everything below follows from that: whole-file validation, a version that is
## actually compared, a write that never truncates the previous save, and a
## refusal that moves a file aside rather than over it.

const SAVE_PATH := "user://highscore.save"

## Bumped when the on-disk shape changes. Version 1 is the original single line;
## version 2 is a `vN` header followed by campaign then endless. Version 5 adds
## three fields under those, in this order: the earned milestone ids, the display
## options, and a count of rebound keys followed by that many
## `action code [code...]` lines. Version 6 widens the options line from the lone
## `cb0`/`cb1` to three space-separated flags, `cb0 sfx0 mus0`, adding the two
## audio mutes. Actually parsed and compared — see `_parse_save`.
##
## **There is deliberately no readable version 3 or 4.** Two development branches
## each minted their own `SAVE_VERSION = 3` in parallel — one writing the key
## bindings on line 4, the other the milestones — and one of them went on to a 4.
## Both shapes reached this machine's `user://` during live testing, so a `v3` on
## disk here is genuinely two different formats wearing one number. They are
## cheap to tell apart (`m0` against a bare digit) and that is not the point: a
## version number whose meaning depends on which branch wrote it has already
## failed at its one job, and teaching the parser to guess would bless the
## ambiguity rather than end it. Both are refused below and quarantined by the
## existing `.bak` path — nothing is destroyed, and the only thing a player on
## this machine loses is a high score from a build that never shipped.
##
## Version 6 is the first bump made with that history written down, and it is
## deliberately narrow: it widens ONE line, keeps every other field in the same
## place, and leaves the variable-length binding block last. A v5 file is read
## forward rather than refused, because a v5 file is unambiguous — one branch
## wrote it, and its options line has exactly one token where v6's has three.
const SAVE_VERSION: int = 6

## The version that introduced the milestone line, the options line and the
## binding block — all three landed together, so one number covers them.
##
## Written as its own constant rather than as `SAVE_VERSION`, which is what the
## three `version >= ...` reads in `_parse_save` used to say. That was correct for
## exactly as long as those fields were the newest thing in the file: the moment
## SAVE_VERSION moved to 6, `version >= SAVE_VERSION` would have meant "only a
## v6 file has milestones", so a v5 save's milestones AND its rebound keys would
## have been skipped, defaulted, and then written back out empty by the migration
## rewrite — silent data loss caused by the bump itself rather than by the format.
const VERSION_WITH_EXTRAS: int = 5

## The version that put the two audio mutes on the options line. Same role as
## VERSION_WITH_EXTRAS: the parser asks which SHAPE a line has by the version that
## defined it, never by comparison against whatever the current version happens
## to be.
const VERSION_WITH_MUTES: int = 6

## The first version this build refuses on sight, and the last. See SAVE_VERSION.
const AMBIGUOUS_VERSIONS: Array[int] = [3, 4]

## A `count` line claiming more rebound actions than the game has verbs is not a
## file this build wrote. Bounded so a corrupt digit cannot ask the parser for a
## million lines before it decides it does not like them.
const MAX_BINDING_ROWS: int = 32

## The milestone line's leading character, and the whole reason it has one.
##
## `get_line()` returns "" past the end of a truncated file, so a v3 save cut after
## the endless line hands the parser an empty milestone line — which is also what a
## player who has earned nothing legitimately has. Those two must not read the same,
## for exactly the reason `_is_score` spells out about `int("")`. So the empty set is
## written `m0`, a length is carried, and "" is not a valid line at all.
const MILESTONE_PREFIX := "m"
## Characters an id may contain. Ids are written by this project, never by a player,
## so the set is deliberately narrow: anything outside it is corruption, not taste.
const MILESTONE_ID_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_"

## A one-shot UI hint, riding in the milestone set — NOT an achievement
## (plant-tower-defense-23fa).
##
## The set already has exactly the semantics a "shown once, ever" flag needs:
## `record_milestones` is idempotent, writes the file only when something is
## genuinely new, and `has_milestone` reads it back across sessions. Adding a
## separate persisted field for the same behaviour would mean a SAVE_VERSION bump
## and a migration, for a boolean.
##
## Safe from the player's view, and checked rather than assumed: the notebook's
## shelf draws its rows from `Milestones.TABLE` and counts earned off TABLE too
## (`notebook_screen.gd:487`, whose own header says this is so "an id from a newer
## build sitting in the save cannot push the total past the shelf's rows"). An id
## that is not in TABLE is invisible there. The design already anticipated
## foreign ids; this is one, deliberately.
##
## Named here rather than written as a bare string at the call site, so the reuse
## is discoverable from the persistence layer instead of only from the HUD.
const HINT_MOVE_PREVIEW := "seen_move_tip"

## Every id in `earned_milestones` that is a HINT rather than an ACHIEVEMENT. One
## dictionary, two opposite contracts, and until this list existed nothing in the
## code said which an id was:
##
##   an ACHIEVEMENT is EARNED — the player did the thing, and recording it is a
##   consequence of the doing. `Milestones.TABLE` holds these and the notebook
##   shelf renders them.
##   a HINT is SPENT — it is a one-shot the player is owed a sight of, and
##   recording it is a claim that they got it.
##
## Cycle 79 paid for the distinction: the move tip was recorded whenever the game
## DECIDED to show it, a later change displaced the sentence that would have shown
## it, and the hint burned unseen for a cycle. Cycle 80 fixed that one call site by
## putting the decision in `Hud.uproot_shows_tip` and having `Game` ask it — right,
## and a fix to one site rather than to the class.
##
## The list is what makes the guard possible in both directions: `spend_hint`
## refuses an id that is not here, and `record_milestones` refuses one that is. So a
## hint cannot be recorded by a path that never rendered it, and an achievement
## cannot be routed through a door that asks whether it was seen — a question that
## means nothing about a thing the player did.
## The second hint, and the first one filed under the contract rather than before it.
##
## A Chomp declines a winged pest with a bare `continue` (`game/chomp_flower.gd:85`) —
## no sound, no message, no visual. From the player's chair a mouth that sits still
## next to a bug is indistinguishable from a broken plant, and the rule it is obeying
## ("ignores ground plants") is in the design brief and nowhere in the game.
const HINT_CHOMP_IGNORES_FLIGHT := "seen_flight_tip"

## The third hint, and the one with the most evidence behind it of anything in this
## file (plant-tower-defense-gz53).
##
## Cycle 101 played the campaign twice on the same economy with no cheats, differing
## in exactly one policy bit — spend surplus seeds on NEW plants, or on the plants
## already down. Breadth-first reached eleven level-1 plants and died at wave 10.
## Depth-first won all 22 waves without losing a life. Both had all seven plants by
## wave 7, so the catalogue is not the difference: UPGRADING IS.
##
## And nothing said so. The Upgrade button exists only while a placed plant is
## selected, `Milestones` never mentions plant levels, and of twenty-one
## `show_message` call sites exactly two concerned upgrades — a refusal reached only
## by a player who had already found the button, and the confirmation after a
## successful one. Every mention of the mechanic that decides the run was a reply to
## somebody who already knew, or a caption in a screen they had to go and open.
const HINT_UPGRADE_EXISTS := "seen_upgrade_tip"

const HINTS: Array[String] = [
	HINT_MOVE_PREVIEW, HINT_CHOMP_IGNORES_FLIGHT, HINT_UPGRADE_EXISTS,
]


## Whether `id` is a hint rather than an achievement. Static and pure so both
## guards below read the same answer, and so a test can ask without a save file.
static func is_hint(id: String) -> bool:
	return HINTS.has(id)

## The options line. Marked for the same reason the milestone line is: a save
## truncated after the milestones hands the parser "", and `bool("")` would happily
## read as "the option is off" — a setting silently reverting on a player who needs
## it is the exact failure these options exist to prevent.
##
## In v5 the whole line was `cb0` or `cb1`. In v6 it is three space-separated flags
## in a fixed order — `cb0 sfx0 mus0` — because the screen that shows these is one
## list of three switches (see OptionsScreen.OPTIONS), and one screen reading one
## line is one fewer place for the set to disagree with itself. The alternative
## considered was a fourth line of its own for the mutes; it was rejected because
## it would have split "the options" across two lines and two parsers for no gain,
## and because a line per switch makes every future switch another version bump.
##
## Every flag carries its own PREFIX rather than being a bare `0`/`1` in a known
## column. A bare triple reads perfectly when two of its fields are transposed —
## a player's music mute silently becoming their colourblind setting — whereas
## `sfx1` in the colourblind slot is refused. The cost is nine bytes.
const OPTIONS_COLORBLIND_PREFIX := "cb"
const OPTIONS_MUTE_SFX_PREFIX := "sfx"
const OPTIONS_MUTE_MUSIC_PREFIX := "mus"
## The v5 spellings, kept because a v5 file on disk is still read by this build and
## its whole options line is one of these two exactly.
const OPTIONS_COLORBLIND_OFF := "cb0"
const OPTIONS_COLORBLIND_ON := "cb1"
## The v6 options line's fields, in the order they are written and read. Order is
## fixed by this array and by nothing else, so the writer and the reader cannot
## drift apart.
const OPTIONS_PREFIXES: Array[String] = [
	OPTIONS_COLORBLIND_PREFIX,
	OPTIONS_MUTE_SFX_PREFIX,
	OPTIONS_MUTE_MUSIC_PREFIX,
]

## The file this autoload persists to. A variable rather than a constant for
## exactly one reason: the unit tests need to drive this code over a scratch file
## instead of over the player's real save, which is the single thing in this
## project that cannot be regenerated by playing. The game never reassigns it.
## `.tmp` and `.bak` siblings are derived from it, so a test redirects all three
## at once.
var save_path: String = SAVE_PATH

var endless: bool = false
## True from the moment a run beats its mode's record until the title screen has
## said so. Not persisted: it is about the journey the player just took, not about
## the save file.
##
## Without it, a record set by quitting is silent. _end_run captures
## record_score's return and hands it to the post-mortem's "a new best", but the
## two pause exits call it as a bare statement and drop it -- so leaving on a
## personal best said nothing at all, and the title screen renders the same
## sentence whether the number moved a second ago or three sessions back.
var fresh_record: bool = false
## What `fresh_record` replaced, and which mode it was in. Session-only, like the
## flag itself -- deliberately NOT written to the save, because "the number you just
## beat" is a fact about this sitting and not about the garden
## (plant-tower-defense-9z1).
##
## Kept because a record that simply appears says less than one you watch arrive: the
## title screen rolls the digits from here up to the new best. Without it the screen
## has the destination and no idea where the count started, and "roll up from zero"
## would tell a player who improved 5008 -> 5010 that they had just earned 5010 seeds
## from nothing.
var previous_best: int = 0
## Which of the two records moved. Stored rather than read off `endless`, because
## `endless` is the mode the player is ABOUT to play -- the title screen writes it
## the moment they move the selection -- and the record that just fell belongs to the
## mode they have finished.
var fresh_record_endless: bool = false

var campaign_high_score: int = 0
var endless_high_score: int = 0

## The keys the player has moved, as {action_name: Array[int] of keycodes}. Only
## the rows that differ from KeyBindings.ACTIONS live here — see
## KeyBindings.overrides() for why the defaults must not be pinned into the save.
##
## It lives in this file rather than in a settings file of its own because this is
## already the thing that survives a scene swap and already owns the one write to
## user://. A second persistence mechanism would mean a second half-written-file
## story, and this file's whole header is about how expensive that was to get
## right once.
##
## Plain data, deliberately: `_load` sets it, and applying it to the InputMap is a
## separate call (`apply_key_bindings`). A `_load` that reached into the global
## InputMap would make every test that drives this parser over a scratch file a
## test that silently rebinds the whole suite's keyboard.
var key_bindings: Dictionary = {}
## Milestone ids this player has earned, as a set (`id -> true`). See
## `game/milestones.gd` for the table and the rules.
##
## A set rather than an Array because every operation this needs is a membership
## test or a union, and because the on-disk order then has to be decided once, by
## the writer, instead of drifting with whatever order a run happened to earn
## things in — a save whose bytes change when nothing changed is a save you cannot
## diff.
##
## Unlike the two scores, a lost flag is re-earnable: play another good run and it
## comes back. That asymmetry is why the milestones ride in the same file rather
## than getting a second one, and why a malformed milestone line still refuses the
## WHOLE save — the scores in it are the part that cannot be re-earned, and
## half-reading a file to rescue the cheap half is the exact move `_parse_save`
## exists to refuse.
var earned_milestones: Dictionary = {}

## Draw the two combat bars — a plant's health fill and the wave readout's threat
## tint — on GardenTheme's blue/orange ramp instead of the green/amber/red one.
##
## Persisted rather than held for a session, and that is the whole difference
## between an accessibility option and a debug switch: a player who needs this
## needs it on every launch, and one that resets is one they have to find and set
## again every time. It lives here because this is already the file that outlives
## the scene swap, and because the flag has to be readable from `Hud.threat_color`,
## which is static and has no HUD instance to ask.
##
## The only thing that sets it today is the run's own C key (Game.KEY_HELP). That
## is a placeholder for a settings screen, which does not exist yet — when one
## lands, it should own this and the key should stay as the shortcut.
var colorblind_safe: bool = false

## The two audio mutes, as the save records them: `true` means silent.
##
## The flags a player actually hears are `Sfx._muted` and `Music._muted`, which are
## static and die with the process — these are their persisted record, and
## `apply_audio_mutes()` is what puts one into the other. Exactly the arrangement
## `key_bindings` uses, and for exactly the same reason: a `_load` that reached
## into Sfx and Music directly would make every test that drives this parser over a
## scratch file a test that silently mutes the whole suite's audio. That has
## already happened once in this project with a different flag, which is why the
## rule is stated here rather than left to be rediscovered.
##
## The corollary is that `set_mute_sfx` / `set_mute_music` are the only supported
## writers: they move BOTH halves. Calling `Sfx.set_muted` directly changes what
## the player hears without changing what the next save records.
var mute_sfx: bool = false
var mute_music: bool = false

## What `_load` made of the save file. Exists so that "there was no save" and
## "there was a save and it was refused" are distinguishable from the outside —
## both leave the scores where they were, and only one of them is a problem.
## One of:
##   ""          `_load` has not run yet
##   "absent"    no file, first launch — the zeros are legitimate
##   "loaded"    a current-version file was read
##   "migrated"  an older-version file was read and rewritten in the new shape
##               (version 1's bare integer, or version 2's three lines with no
##               milestone line under them)
##   "recovered" `save_path` was missing and an interrupted `_save`'s temp file
##               was complete, so it was adopted
##   "refused"   a file exists and could not be trusted; the scores were left alone
var load_status: String = ""

## The file `_load` refused, if any. The next `_save` moves it aside instead of
## writing over it: a file this build cannot read may still be one that a later
## build, or a person with a text editor, can.
var _refused_path: String = ""


func _ready() -> void:
	_load()
	apply_key_bindings()
	apply_audio_mutes()


## Pushes whatever `_load` made of the save into the live InputMap. Separate from
## `_load` on purpose (see `key_bindings`), and safe on every load path: a refused
## or absent save leaves `key_bindings` empty, which is the same instruction as
## "put every verb back on the key it ships with".
func apply_key_bindings() -> void:
	var dropped: Array[String] = KeyBindings.apply_overrides(key_bindings)
	if not dropped.is_empty():
		# Not a refusal. A save naming a verb this build does not have is a save
		# from a build that did — a downgrade, not damage — and the rest of it,
		# including two high scores, is perfectly readable.
		push_warning("RunConfig: ignoring saved bindings for %s — this build has no such action." % [dropped])


## Records the player's rebindings and writes them out. The one entry point the
## settings screen uses, so "changed on screen" and "changed on disk" cannot come
## apart.
func store_key_bindings(map: Dictionary) -> void:
	key_bindings = map
	_save()


## The record for a mode. Takes the flag rather than reading `endless`, so the
## title screen can show both without having to lie about which mode is selected.
func best_for(for_endless: bool) -> int:
	return endless_high_score if for_endless else campaign_high_score


## Called once a run ends (win or lose). Only ever raises the record — a worse
## run than last time should not overwrite the number the player is proud of.
## Files against the mode that was actually played.
func record_score(seeds_earned: int) -> bool:
	if seeds_earned <= best_for(endless):
		return false
	previous_best = best_for(endless)
	fresh_record_endless = endless
	if endless:
		endless_high_score = seeds_earned
	else:
		campaign_high_score = seeds_earned
	fresh_record = true
	_save()
	return true


## The exact bytes of a current-version save. Split out of `_save` so the writer
## has one shape rather than a run of `store_line` calls that a later field can be
## appended to in the wrong place — and so the rows are sorted, which is what makes
## a save byte-comparable between two runs that rebound the same keys in a
## different order.
## The variable-length binding block goes LAST for the same reason it carries a
## count: everything above it is a fixed number of lines, so a reader that has
## consumed them knows exactly where the block starts. Put the bindings in the
## middle and every field under them moves whenever a player rebinds a key.
static func compose_save(campaign: int, endless_best: int, milestone_line: String,
		options_line: String, bindings: Dictionary) -> String:
	var out: PackedStringArray = [
		"v%d" % SAVE_VERSION,
		str(campaign),
		str(endless_best),
		milestone_line,
		options_line,
		str(bindings.size()),
	]
	var names: Array = bindings.keys()
	names.sort()
	for name: Variant in names:
		var fields: PackedStringArray = [String(name)]
		for code: Variant in (bindings[name] as Array):
			fields.append(str(int(code)))
		out.append(" ".join(fields))
	return "\n".join(out) + "\n"


## Has this player ever earned this milestone?
func has_milestone(id: String) -> bool:
	return earned_milestones.has(id)


## Files a finished run's milestones and hands back the ones that are NEW.
##
## The return value is the whole point: the card wants to say "you just did this
## for the first time", and by the time it asks, the flag is already set — so a
## caller that files first and reads after can only ever learn "you have this",
## which is true of a milestone earned three sessions ago. The newness exists for
## one instant, at the moment of the union, and this is that instant.
##
## Idempotent, deliberately. `Game._end_run` can be reached twice in a frame and
## both pause doors bank a score; a second call with the same ids adds nothing,
## returns nothing and — because nothing changed — does not write the file either.
func record_milestones(ids: Array) -> Array[String]:
	var fresh: Array[String] = []
	for id: Variant in ids:
		var text: String = String(id)
		if is_hint(text):
			# Loud rather than silent: a hint arriving here is a caller that has not
			# been told the two contracts differ, and the whole point is that it
			# cannot record one by accident. Warning rather than error because the
			# run must not stop — the player loses a tip, not their game.
			push_warning(("RunConfig: '%s' is a HINT, not an achievement — refusing to "
				+ "record it here. Use spend_hint(id, shown) so the record cannot "
				+ "outrun the sight of it.") % [text])
			continue
		if text.is_empty() or has_milestone(text):
			continue
		earned_milestones[text] = true
		fresh.append(text)
	if not fresh.is_empty():
		_save()
	return fresh


## Records a one-shot hint as spent — and only if `shown` says the player actually
## saw it. Returns true when this call is what recorded it.
##
## `shown` is a required argument and that is the entire design. The old shape was
## `record_milestones([HINT_MOVE_PREVIEW])`, which a caller reaches at the moment it
## DECIDES to show a hint, and the decision and the showing are different events
## separated by however much rendering sits between them. Cycle 79's bug lived in
## that gap for a cycle. A caller cannot get here without answering the question,
## and a caller that answers `false` cannot spend anything.
##
## Refuses an achievement id too. Passing one would mean asking whether the player
## was shown a thing they did, which is not a question about it — and the refusal is
## what keeps `HINTS` honest, since an id nobody added to the list cannot be spent
## through this door either.
func spend_hint(id: String, shown: bool) -> bool:
	if not is_hint(id):
		push_warning(("RunConfig: '%s' is not in HINTS — refusing to spend it as a hint. "
			+ "An achievement is earned by doing, so use record_milestones; a new hint "
			+ "needs adding to HINTS first.") % [id])
		return false
	if not shown:
		return false
	if has_milestone(id):
		return false
	earned_milestones[id] = true
	_save()
	return true


## Flips the colourblind-safe ramp and writes it down. Returns the new state, so a
## caller can say which way it went without reading the flag back.
##
## A method rather than a bare assignment because the persisting is the point: an
## accessibility option set for one session is one the player has to find again on
## every launch. Writes only on an actual change — the save file is not a place to
## record that someone pressed a key twice.
func set_colorblind_safe(enabled: bool) -> bool:
	if colorblind_safe == enabled:
		return colorblind_safe
	colorblind_safe = enabled
	_save()
	return colorblind_safe


func toggle_colorblind_safe() -> bool:
	return set_colorblind_safe(not colorblind_safe)


## Pushes whatever `_load` made of the two mutes into the classes that own them.
## The audio twin of `apply_key_bindings`, separate from `_load` for the reason
## `mute_sfx` spells out, and safe on every load path: a refused or absent save
## leaves both flags false, which is the same instruction as "the game makes noise",
## the state a player who has never touched either key is in.
func apply_audio_mutes() -> void:
	Sfx.set_muted(mute_sfx)
	Music.set_muted(mute_music)


## Silences (or unsilences) the one-shot cues and writes it down. Same shape and
## same contract as `set_colorblind_safe`: writes only on an actual change, returns
## the state afterwards — which, note, is the MUTED state, matching
## `Sfx.set_muted`'s own return rather than inverting it halfway up the stack.
##
## Sets the owner unconditionally even when the persisted flag already matches, so
## a process whose static flag was moved behind this file's back is resynced rather
## than left disagreeing with the save it is about to be written into.
func set_mute_sfx(muted: bool) -> bool:
	Sfx.set_muted(muted)
	if mute_sfx == muted:
		return mute_sfx
	mute_sfx = muted
	_save()
	return mute_sfx


func toggle_mute_sfx() -> bool:
	return set_mute_sfx(not Sfx.is_muted())


## The music bed's half. `Music.set_muted` does more than gate the next play — it
## has to bring a running bed back — which is why this goes through the setter
## rather than assigning the flag, exactly as OptionsScreen.set_on documents.
func set_mute_music(muted: bool) -> bool:
	Music.set_muted(muted)
	if mute_music == muted:
		return mute_music
	mute_music = muted
	_save()
	return mute_music


func toggle_mute_music() -> bool:
	return set_mute_music(not Music.is_muted())


## Where `_save` assembles the next file before it replaces `save_path`.
func _tmp_path() -> String:
	return save_path + ".tmp"


## Where a refused file is quarantined, rather than being overwritten.
func _backup_path() -> String:
	return save_path + ".bak"


## A score field is a plain non-negative integer and nothing else.
##
## The `""` case is the whole issue: `get_line()` returns `""` past the end of a
## truncated file, `int("")` is 0 in GDScript, and 0 is a legal-looking high
## score. Every other malformed field at least looks wrong; this one looks like a
## player who never played.
static func _is_score(text: String) -> bool:
	return text.is_valid_int() and int(text) >= 0


## An action name in the save is a lowercase identifier and nothing else. This is
## a check on the file's SHAPE, not on its vocabulary: a name this build does not
## recognise is still well-formed, and is dropped by `apply_key_bindings` rather
## than being allowed to condemn the two high scores sharing the file.
static func _is_action_name(text: String) -> bool:
	if text == "":
		return false
	return text.is_valid_ascii_identifier() and text == text.to_lower()


## The milestone line, or `null` if it is not one.
##
## Shape: `m0` for the empty set, `m3:alpha,beta,gamma` otherwise. The count is not
## decoration — it is the only thing that can catch a line truncated at a comma,
## which is the shape a short write actually leaves. A cut that lands mid-id still
## parses (as an id this build does not know), and that is an accepted limit: the
## cost is one milestone the player re-earns, whereas refusing the file would cost
## the two scores they cannot.
##
## Ids are NOT checked against Milestones.TABLE. A save written by a later build
## carries ids this one has no rule for, and dropping them here would silently
## un-earn them the first time an older build touched the file.
##
## Returns Array[String] on success, `null` on anything else — a distinction
## `[]` cannot make, since the empty set is a legitimate reading.
static func _parse_milestones(text: String) -> Variant:
	if not text.begins_with(MILESTONE_PREFIX):
		return null
	var body: String = text.substr(MILESTONE_PREFIX.length())
	var colon: int = body.find(":")
	var count_text: String = body if colon < 0 else body.substr(0, colon)
	if not count_text.is_valid_int():
		return null
	var count: int = int(count_text)
	if count < 0:
		return null
	if (count == 0) != (colon < 0):
		# `m0:` and `m2` are both self-contradictory: a count with no list, or a
		# list with no count. Neither is a shape this writer produces.
		return null
	var ids: Array[String] = []
	if colon >= 0:
		for token: String in body.substr(colon + 1).split(","):
			if token.is_empty() or ids.has(token):
				return null
			for i: int in range(token.length()):
				if not MILESTONE_ID_CHARS.contains(token[i]):
					return null
			ids.append(token)
	if ids.size() != count:
		return null
	return ids


## The milestone set as one line, ids sorted so the bytes are a function of the
## set and not of the order it was assembled in.
func _milestone_line() -> String:
	var ids: Array = earned_milestones.keys()
	ids.sort()
	if ids.is_empty():
		return "%s0" % MILESTONE_PREFIX
	return "%s%d:%s" % [MILESTONE_PREFIX, ids.size(), ",".join(PackedStringArray(ids))]


## One `<prefix>0` / `<prefix>1` flag, or `null` if it is not one. Exact spellings
## and nothing else — these are bools, so there is no third reading to be tolerant
## toward, and "" (a file truncated one line up) is not one of them.
static func _parse_flag(text: String, prefix: String) -> Variant:
	if text == prefix + "1":
		return true
	if text == prefix + "0":
		return false
	return null


## The options line, read in the shape the file's own version defines.
##
## v5 is the lone colourblind flag; v6 is OPTIONS_PREFIXES in order, space
## separated, all three required. Split with empties KEPT, so `cb0  sfx0 mus0` is
## four fields and is refused: two spaces is not a shape this writer produces, and
## a parser that shrugs at it is a parser that would shrug at a half-written line.
##
## Returns {colorblind_safe, mute_sfx, mute_music}, or `null` on anything else.
## A v5 line's two absent mutes read as false — a player who never had the setting
## had a game that made noise, which is exactly what unmuted means.
static func _parse_options(text: String, version: int) -> Variant:
	if version < VERSION_WITH_MUTES:
		# Compared against the two v5 spellings outright rather than run through
		# `_parse_flag`. v5's line was one fixed word, not a prefixed field in a
		# sequence, and reading a closed format with the open format's parser is how
		# a shape nobody ever wrote (`cb0 ` with a trailing space, say) becomes
		# readable years after the writer that would have produced it is gone.
		if text == OPTIONS_COLORBLIND_ON:
			return {"colorblind_safe": true, "mute_sfx": false, "mute_music": false}
		if text == OPTIONS_COLORBLIND_OFF:
			return {"colorblind_safe": false, "mute_sfx": false, "mute_music": false}
		return null
	var fields: PackedStringArray = text.split(" ")
	if fields.size() != OPTIONS_PREFIXES.size():
		return null
	var values: Array[bool] = []
	for i: int in range(OPTIONS_PREFIXES.size()):
		var flag: Variant = _parse_flag(fields[i], OPTIONS_PREFIXES[i])
		if flag == null:
			return null
		values.append(bool(flag))
	return {"colorblind_safe": values[0], "mute_sfx": values[1], "mute_music": values[2]}


static func _flag_text(prefix: String, on: bool) -> String:
	return "%s%d" % [prefix, 1 if on else 0]


func _options_line() -> String:
	return " ".join(PackedStringArray([
		_flag_text(OPTIONS_COLORBLIND_PREFIX, colorblind_safe),
		_flag_text(OPTIONS_MUTE_SFX_PREFIX, mute_sfx),
		_flag_text(OPTIONS_MUTE_MUSIC_PREFIX, mute_music),
	]))


func _parse_failed(reason: String) -> Dictionary:
	return {"ok": false, "campaign": 0, "endless": 0, "milestones": [],
		"colorblind_safe": false, "mute_sfx": false, "mute_music": false,
		"bindings": {}, "version": 0, "reason": reason}


## Validates an entire save file and only then hands back its contents.
##
## Validate-then-commit rather than parse-defensively, deliberately: a parser
## that assigns campaign before discovering that the endless line is missing has
## already done the damage this function exists to prevent. There is no
## half-understood save worth half-adopting — the fields are two independent
## records, and taking one while dropping the other is indistinguishable from
## corruption on the next launch. So nothing here touches the live scores; the
## caller commits, or does not.
##
## Returns {ok: bool, campaign: int, endless: int, version: int, reason: String}.
func _parse_save(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _parse_failed("cannot open it (%s)" % error_string(FileAccess.get_open_error()))
	var header: String = f.get_line().strip_edges()
	if header == "":
		return _parse_failed("it is empty")

	if not header.begins_with("v"):
		# Version 1: a bare integer on one line, and nothing else. No build ever
		# wrote a literal "v1" header, so the absence of the header IS the version.
		if not _is_score(header):
			return _parse_failed("its first line %s is neither a version nor a score" % [header])
		# That legacy number is migrated into the ENDLESS slot, and the choice is
		# not arbitrary: the title screen has always presented it as "Best endless
		# run", so that is the record the player believes they hold, and endless
		# totals dwarf campaign ones (eight waves against an unbounded run) — so a
		# legacy value that did come from a campaign is merely a hard endless
		# record, whereas the reverse migration would leave an unbeatable number
		# sitting on the eight-wave mode.
		# Version 1 predates key bindings, milestones and the display options
		# entirely, so the migration leaves every verb on the key it ships with —
		# which is where it already was — and the empty milestone set here is a
		# reading rather than a fallback.
		return {"ok": true, "campaign": 0, "endless": int(header), "milestones": [],
			"colorblind_safe": false, "mute_sfx": false, "mute_music": false,
			"bindings": {}, "version": 1, "reason": "v1"}

	var version_text: String = header.substr(1)
	if not version_text.is_valid_int():
		return _parse_failed("its version header %s is not a number" % [header])
	var version: int = int(version_text)
	if version > SAVE_VERSION:
		# The real point of reading the version at all. A later build may write
		# four lines, or the same three in another order, or the same three
		# meaning something else. Parsing it "as if it were current" is how a
		# newer build's endless record lands in the campaign slot silently. The
		# safe response to a file from the future is to decline to read it — and,
		# just as importantly, to decline to write over it, because that file is
		# not damaged, it is simply not ours. See `_load`.
		return _parse_failed("it is version %d and this build reads at most %d" % [version, SAVE_VERSION])
	if version < 2:
		return _parse_failed("version %d never had a %s header" % [version, header])
	if AMBIGUOUS_VERSIONS.has(version):
		# See SAVE_VERSION. Two parallel branches both wrote a `v3`, meaning
		# different things by line 4, and one of them wrote a `v4` on top. Refused
		# rather than guessed; `_load` quarantines it to .bak instead of writing
		# over it, so nothing is lost that a later build could still read.
		return _parse_failed(("it is version %d, which two development builds each "
			+ "defined differently, so its fields cannot be identified") % [version])

	# Version 2 onward: campaign, then endless, one per line.
	# Version 2 and up: campaign, then endless, one per line.
	var campaign_text: String = f.get_line().strip_edges()
	var endless_text: String = f.get_line().strip_edges()
	if not _is_score(campaign_text):
		return _parse_failed("its campaign score %s is not a number" % [campaign_text])
	if not _is_score(endless_text):
		return _parse_failed("its endless score %s is not a number" % [endless_text])

	# Version 5's three added fields, read in the order compose_save writes them:
	# milestones, then options, then the variable-length binding block last. A
	# version-2 file has none of them, which is the migration — every one falls
	# back to its default exactly once, on the launch that rewrites the file
	# forward, exactly as a version-1 file is handled.
	#
	# Gated on VERSION_WITH_EXTRAS, never on SAVE_VERSION: see that constant for
	# what `version >= SAVE_VERSION` here would have cost a v5 save the moment
	# SAVE_VERSION became 6.
	var milestones: Array = []
	if version >= VERSION_WITH_EXTRAS:
		var parsed_ids: Variant = _parse_milestones(f.get_line().strip_edges())
		if parsed_ids == null:
			return _parse_failed("its milestone line is not a milestone line")
		milestones = parsed_ids as Array

	var colorblind: bool = false
	var muted_sfx: bool = false
	var muted_music: bool = false
	if version >= VERSION_WITH_EXTRAS:
		# The one line whose SHAPE differs between two readable versions, so the
		# version goes in rather than being compared against here — a v5 line has one
		# field, a v6 line has three, and the parser is told which it is looking at.
		var parsed_options: Variant = _parse_options(f.get_line().strip_edges(), version)
		if parsed_options == null:
			return _parse_failed("its options line is not an options line")
		var options := parsed_options as Dictionary
		colorblind = bool(options["colorblind_safe"])
		muted_sfx = bool(options["mute_sfx"])
		muted_music = bool(options["mute_music"])

	# The count is what makes a truncation here detectable at all — without it, a
	# file cut after the options line is indistinguishable from a player who never
	# opened the Keys screen, and the rebindings vanish with no error. Same
	# reasoning as the empty-score case above, three fields along.
	var bindings: Dictionary = {}
	if version >= VERSION_WITH_EXTRAS:
		var count_text: String = f.get_line().strip_edges()
		if not count_text.is_valid_int():
			return _parse_failed("its key-binding count %s is not a number" % [count_text])
		var count: int = int(count_text)
		if count < 0 or count > MAX_BINDING_ROWS:
			return _parse_failed("it claims %d rebound keys and this build has at most %d verbs"
				% [count, MAX_BINDING_ROWS])
		for i: int in count:
			var row: String = f.get_line().strip_edges()
			var fields: PackedStringArray = row.split(" ", false)
			if fields.size() < 2:
				return _parse_failed("its key-binding row %d (%s) is not an action and at least one key" % [i, row])
			var action: String = fields[0]
			if not _is_action_name(action):
				return _parse_failed("its key-binding row %d names %s, which is not an action name" % [i, action])
			if bindings.has(action):
				return _parse_failed("it binds %s twice" % [action])
			if fields.size() - 1 > KeyBindings.MAX_KEYS_PER_ACTION:
				return _parse_failed("it puts %d keys on %s" % [fields.size() - 1, action])
			var codes: Array[int] = []
			for k: int in range(1, fields.size()):
				if not fields[k].is_valid_int() or int(fields[k]) <= 0:
					return _parse_failed("its key-binding row %d has %s where a keycode belongs" % [i, fields[k]])
				codes.append(int(fields[k]))
			bindings[action] = codes

	return {
		"ok": true,
		"campaign": int(campaign_text),
		"endless": int(endless_text),
		"milestones": milestones,
		"colorblind_safe": colorblind,
		"mute_sfx": muted_sfx,
		"mute_music": muted_music,
		"version": version,
		"bindings": bindings,
		"reason": "v%d" % version,
	}


## Reads the save, or refuses to.
##
## Nothing is written on the refusal path — not the fallback, not a "repaired"
## file, nothing. Overwriting the file we just failed to read is the one action
## that turns a recoverable situation into a permanent one, and it is precisely
## what the old version-1 branch did on every launch.
func _load() -> void:
	var path: String = save_path
	var recovered: bool = false
	# Whatever a previous load refused, this one supersedes: a quarantine that is
	# still pending against a file nobody is going to read again is just a stale
	# rename waiting to fire at the wrong moment.
	_refused_path = ""
	if not FileAccess.file_exists(path):
		# An interrupted `_save` can leave a complete temp file with no save
		# beside it. Adopting it is the entire reason `_save` writes it
		# separately; without this, the safety net catches nothing.
		if not FileAccess.file_exists(_tmp_path()):
			load_status = "absent"
			return
		path = _tmp_path()
		recovered = true

	var parsed: Dictionary = _parse_save(path)
	if not bool(parsed["ok"]):
		load_status = "refused"
		_refused_path = path
		push_warning("RunConfig: refusing %s because %s. High scores left as they are (campaign %d, endless %d)."
			% [path, str(parsed["reason"]), campaign_high_score, endless_high_score])
		return

	campaign_high_score = int(parsed["campaign"])
	endless_high_score = int(parsed["endless"])
	key_bindings = parsed["bindings"] as Dictionary
	# Replaced, not merged. A load is "this is what is on disk", and a union with
	# whatever the process happened to be holding would make a save reloaded twice
	# read differently from one loaded once.
	earned_milestones = {}
	for id: String in (parsed["milestones"] as Array):
		earned_milestones[id] = true
	colorblind_safe = bool(parsed["colorblind_safe"])
	# Data only, like `key_bindings` above it: nothing here touches Sfx or Music.
	# `apply_audio_mutes()` is the one place that does, and `_ready` calls it.
	mute_sfx = bool(parsed["mute_sfx"])
	mute_music = bool(parsed["mute_music"])
	if recovered:
		load_status = "recovered"
		_save()
	elif int(parsed["version"]) < SAVE_VERSION:
		load_status = "migrated"
		# Rewrite immediately in the new shape, so the ambiguity is resolved once
		# rather than being re-guessed on every launch. Unlike the refusal path,
		# this write follows a parse that fully succeeded.
		_save()
	else:
		load_status = "loaded"


## Assembles the file at a temp path and only then replaces `save_path`.
##
## Judged warranted, not ceremony, for a file this small. `FileAccess.WRITE`
## truncates its target the instant it opens, so the previous shape destroyed the
## only copy of an unregenerable number *before* writing a byte of the
## replacement — and it did that on every new record. A full or read-only user://
## therefore turned "could not save" into "the previous save is now a zero-length
## file", which is the exact truncation the reader above now has to refuse. Fixing
## only the reader would leave that: the live session keeps its number, and the
## next launch starts at zero anyway. The write side is the half that actually
## keeps the data.
##
## Honest caveat: Godot's `DirAccess.rename_absolute` removes an existing
## destination before renaming on Windows, so this is not a true atomic swap
## there. It shrinks the window from "the whole write" to "one rename", and the
## finished temp file is still on disk if we lose even that — which is why `_load`
## adopts the temp when the save has gone missing.
func _save() -> void:
	if _refused_path != "":
		# Move the file `_load` could not read aside rather than over it. First
		# refusal wins: that file is the one closest to the data the player set,
		# and a second corruption should not be allowed to bury it.
		if FileAccess.file_exists(_refused_path) and not FileAccess.file_exists(_backup_path()):
			DirAccess.rename_absolute(_refused_path, _backup_path())
		_refused_path = ""

	var tmp: String = _tmp_path()
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("RunConfig: cannot write %s (%s). The record stands in memory only, and the previous save is untouched."
			% [tmp, error_string(FileAccess.get_open_error())])
		return
	f.store_string(compose_save(campaign_high_score, endless_high_score,
		_milestone_line(), _options_line(), key_bindings))
	f.flush()
	var write_error: int = f.get_error()
	f.close()
	if write_error != OK:
		# A short write is exactly the truncation this whole issue is about. Here
		# it lands in the temp file, where it can be thrown away instead of read.
		push_warning("RunConfig: %s while writing %s. Keeping the previous save."
			% [error_string(write_error), tmp])
		DirAccess.remove_absolute(tmp)
		return
	var readback: Dictionary = _parse_save(tmp)
	if not bool(readback["ok"]):
		# Read back through the same validator the loader uses, so "whatever is at
		# save_path parses" is true by construction rather than by argument — and
		# so a future writer that its own reader cannot read fails here, loudly,
		# instead of at some player's next launch.
		push_warning("RunConfig: %s does not read back (%s). Keeping the previous save."
			% [tmp, str(readback["reason"])])
		DirAccess.remove_absolute(tmp)
		return
	var rename_error: int = DirAccess.rename_absolute(tmp, save_path)
	if rename_error != OK:
		push_warning("RunConfig: %s replacing %s. The finished save is at %s and _load will adopt it."
			% [error_string(rename_error), save_path, tmp])
