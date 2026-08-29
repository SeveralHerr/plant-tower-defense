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
##
## Version 7 widens the same line again, to four fields — `cb0 sfx0 mus0 spd0` —
## adding the garden speed the player last chose (`game_speed_step`). It follows
## v6's shape exactly: one line widened, every other field in the same place, the
## binding block still last, and a `VERSION_WITH_SPEED` constant so the parser asks
## which shape a line has by the version that defined it rather than by comparison
## against whatever `SAVE_VERSION` happens to be.
##
## Honest note on where it was put. The options line's own comment argues it is
## "the screen that shows these", and the speed is NOT an Options-screen switch —
## it is a top-bar button and a key. It rides here anyway because the alternative,
## a line of its own, moves every field under it and changes `compose_save`'s
## signature, and line geometry is what every reader and every test of this file
## depends on. The fourth field is also the first that is not a bool, so it is
## parsed by `_parse_step` rather than by the loop over the flag prefixes — which
## is the seam to watch. If a fifth non-switch preference ever lands, this line has
## stopped being "the options" and should be renamed rather than grown again.
##
## Version 8 is that fifth, and the sixth with it: `cb0 sfx0 mus0 spd0 svol0 mvol0`,
## adding the two audio LEVELS (`sfx_level`, `music_level`). Neither is a switch, so
## the line is now four non-bools out of six and the note above has fired.
##
## **IT WAS RENAMED, NOT JUST GROWN, and the rename is the whole of what v8 changes
## about how this file reads.** `_options_line` is `_preferences_line`,
## `_parse_options` is `_parse_preferences`, `OPTIONS_PREFIXES` — which never held
## anything but the bools — is `SWITCH_PREFIXES`, and `compose_save`'s parameter says
## `preferences_line`. Not a byte on disk moves because of any of that: it is
## line 5 either way, in the same place, written by the same writer. What changes is
## that the next person adding a preference reads a name that does not promise them
## a screen. The old name said "the options", the Options screen shows three of the
## six fields, and the two that were already wrong (`spd`, and now the levels) were
## each argued into place against a name that did not fit them.
##
## The alternative considered again and refused again was a line of its own for the
## levels. Same answer v7 gave: it moves every field under it, changes
## `compose_save`'s signature, and line geometry is what every reader and every
## byte-exact test of this file depends on. A rename costs no geometry at all.
##
## What would change it: a preference that is not one scalar per player — a list, a
## per-plant setting, anything with its own length. THAT wants a line, because a
## variable-length field on a fixed line is the thing the binding block is kept last
## to avoid.
##
## Version 10 is exactly that preference arriving: which cosmetic skin the player has
## chosen for each plant kind and each pest species (plant-tower-defense-ncfv). A
## Dictionary keyed per-target with no fixed count is precisely what this paragraph
## describes, so it gets a LINE of its own — `compose_skins_line` /
## `parse_skins_line`, count-prefixed and sorted exactly like `compose_difficulty_line`
## below, which is the closest existing shape (a sparse, count-prefixed set of
## `key=value` fields) and is copied rather than reinvented.
##
## THE NEW LINE GOES BEFORE THE BINDING COUNT, never after — see
## VERSION_WITH_DIFFICULTY_SCORES for why: the binding block is kept last so its own
## count can catch a truncation, and a field appended after it would take that guard
## down with it. So the v10 line order is: milestones, preferences, difficulty
## scores, SKINS, binding count, bindings.
const SAVE_VERSION: int = 10

## The version that made the record know which difficulty earned it
## (plant-tower-defense-1hgx).
##
## WHAT V9 CHANGES IS A MEANING, NOT A BYTE. Lines 2 and 3 held "the campaign best" and
## "the endless best" with no idea which profile was played, so a 5008 set on Gentle
## (15 lives, 26s of prep, 40 seeds) and a 5008 set on Harsh (5, 9.0, 15) were the same
## number in the same slot — and beating your own record by picking an easier setting was
## indistinguishable from beating it by playing better. From v9 those two lines are the
## STANDARD records specifically, and a new line carries the other profiles.
##
## SO THE MIGRATION MOVES NOTHING. A v8 file's two numbers keep their bytes and gain a
## precise meaning: Standard is what the game shipped as, what the picker defaults to, and
## therefore what those runs were almost certainly played on. Attributing them anywhere
## else would be inventing a fact; leaving them unattributed is what v8 already did.
##
## THE NEW LINE GOES BEFORE THE BINDING COUNT, never after. The binding block is
## variable-length and is kept last precisely so a truncation is detectable by comparing
## its count against what follows — a field appended after it would be read as a binding
## and would take the count's guard down with it.
const VERSION_WITH_DIFFICULTY_SCORES: int = 9

## The version that put the chosen-skin line in the file. Same role as
## VERSION_WITH_DIFFICULTY_SCORES: a v9 file does not have it, and reading one anyway
## would consume the binding count as a skin line and then refuse the whole save.
const VERSION_WITH_SKINS: int = 10

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

## The version that put the garden speed on the options line. Same role again: a
## v6 line has three fields, a v7 line has four, and the parser is told which it is
## looking at instead of guessing from the field count.
const VERSION_WITH_SPEED: int = 7

## The version that put the two audio levels on the preferences line. Same role a
## fourth time: a v6 line has three fields, a v7 line has four, a v8 line has six,
## and the parser is told which it is looking at rather than counting and guessing.
const VERSION_WITH_LEVELS: int = 8

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

## The one rule in this game that REVERSES something the player already learned, rather
## than filling a gap in what they know (plant-tower-defense-lven).
##
## The other three hints teach rules the board does not state. This one contradicts a rule
## the board stated for the entire history of the project: `Board.is_buildable` refused
## every road cell until the Barrier Bramble, and `Game.place_plant` still answers "pests
## walk there" for eight of the nine plants. A player who has internalised that will read
## "Grows across the road itself" as flavour and never try — so this is the hint most likely
## to be load-bearing, and it is the last of the four to exist.
const HINT_ROAD_PLANTS := "seen_road_tip"

## The one instance of grammar row 6 left on the board (plant-tower-defense-rr02):
## the bar on the GRASS. Cycle 144 named a second bar on the ROAD alongside it; a
## player called that one an artifact in the lanes and it was removed, along with
## the rings that shared the selection with it.
##
## `cue_legend.gd:112` is the audit that refused these bars a legend row — "four
## instances, four meanings, one channel" — and that verdict is why the survivor
## still needs a sentence of its own rather than a shared row.
##
## THE SENTENCE LEADS WITH THE GROUND, which is what tells this mark from every
## other straight line the board draws: orientation is a channel a reader has to
## already know to read, and "on grass" is one they can use on first sight.
const HINT_DEAD_GROUND := "seen_dead_ground_tip"

const HINTS: Array[String] = [
	HINT_MOVE_PREVIEW, HINT_CHOMP_IGNORES_FLIGHT, HINT_UPGRADE_EXISTS, HINT_ROAD_PLANTS,
	HINT_DEAD_GROUND,
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
## THE PREFERENCES LINE, and it is called that rather than "the options" since v8 —
## see SAVE_VERSION for the rename and why it changes no bytes. It is every
## remembered player preference that is one scalar, switch or not, in a fixed
## prefixed order. Three of the six are Options-screen switches; the other three are
## a top-bar button and two dials.
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
## The preferences line's BOOL fields, in the order they are written and read.
## Order is fixed by this array and by nothing else, so the writer and the reader
## cannot drift apart.
##
## Named for what it holds rather than for the line it sits on — it was
## `OPTIONS_PREFIXES` until v8, and by then the line had four fields of which this
## covered three. Everything after these is a step index parsed by `_parse_step`,
## which is the seam v7's own note asked the next reader to watch.
const SWITCH_PREFIXES: Array[String] = [
	OPTIONS_COLORBLIND_PREFIX,
	OPTIONS_MUTE_SFX_PREFIX,
	OPTIONS_MUTE_MUSIC_PREFIX,
]

## The v7 field: which step of `GameSpeed.STEPS` the player last chose, written
## `spd0`/`spd1`/`spd2`. Carries a prefix for the same reason its three neighbours
## do, and it needs one more than they do: a bare digit in the fourth column is
## indistinguishable from the key-binding COUNT line one row down, so a save
## truncated mid-options-line would parse as a shorter file that happened to line
## up. `spd` cannot be mistaken for a count.
const OPTIONS_SPEED_PREFIX := "spd"

## The largest step index this parser will read out of a save.
##
## NOT `GameSpeed.STEPS.size()`, and the difference is the whole point. A save
## written by a later build with a fourth step must not condemn the file — the two
## high scores in it cannot be re-earned and a speed can, which is the same
## asymmetry `_parse_milestones` cites for not checking ids against
## `Milestones.TABLE`. So an index this build has no step for is READ and KEPT
## here, and refused at the point of use: `apply_game_speed` falls back to 1x for
## anything outside `GameSpeed.STEPS`, and a downgrade that never touches the
## control writes the original index back out untouched.
##
## Bounded all the same, so a corrupt digit cannot claim step 900000000.
const MAX_SPEED_STEP: int = 15

## The v8 fields: which step of `Sfx.LEVELS` the player last chose for each of the
## two audio categories, written `svol0`/`mvol0`. Prefixed for the reason every
## other field on this line is, and spelled four characters rather than three so a
## reader skimming the line cannot mistake `svol` for `sfx` — they are adjacent
## fields about the same category, and the whole argument for prefixes is that a
## transposition must be refused rather than read.
##
## `Sfx.LEVELS[0]` is FULL, so a default save reads `svol0 mvol0` and sits beside
## the four other zeros rather than carrying a magic index nobody can check by eye.
const OPTIONS_SFX_LEVEL_PREFIX := "svol"
const OPTIONS_MUSIC_LEVEL_PREFIX := "mvol"

## The largest level index this parser will read out of a save.
##
## Same value and same argument as MAX_SPEED_STEP, and a SEPARATE constant on
## purpose: they bound two different tables, and one shared number is how a change
## to the speed table's ceiling silently moves the level table's. An index this
## build has no level for is READ and KEPT — a save from a later build with eight
## steps must not condemn two high scores that cannot be re-earned — and refused at
## the point of use, where `Sfx.level_db` falls back to full.
const MAX_LEVEL_STEP: int = 15

## Where a HEADLESS process saves instead, and the environment variable that overrides
## both (plant-tower-defense-58u7).
##
## THE HOLE THIS CLOSES. A test redirects `save_path` in its `setup()`. This autoload's
## `_ready()` runs at PROCESS START, before the runner has called any `setup()` — so it
## loads the player's real save, sees an old format version, migrates it and writes it
## back, and every redirect in the suite is installed too late to matter. That is not a
## hypothetical: the first `run_tests.py` after the v6 -> v7 bump rewrote the developer's
## real `user://highscore.save`, and it was found by reading the file afterwards rather
## than by any gate. Nothing was lost that time. The next format bump had the same
## exposure, and so does anything else `_load` might decide to write.
##
## `save_persist_check.py` cannot see it and says so now: it asks whether a test FUNCTION
## can reach `_save()`, and there is no test function in this chain at all.
##
## HEADLESS IS THE RIGHT SIGNAL, not "is this a test". Every headless entry point in this
## project is a tool — the unit runner, the linter, the import gate — and `capture.gd`
## refuses to run headless precisely because there is no renderer. A player's process
## always has one. So the rule is total rather than a list of runners to keep in sync,
## which matters because a bare `godot --headless --script res://tools/lint_project.gd`
## is documented in `CLAUDE.md` and no Python wrapper could have caught it.
##
## `DisplayServer.get_name()` and NOT `OS.has_feature("headless")`, which is the obvious
## reach and is **false** under `--headless` — measured, not assumed.
const HEADLESS_SAVE_PATH := "user://headless_scratch.save"
const SAVE_PATH_ENV := "PLANT_TD_SAVE_PATH"


## The file this autoload persists to. A variable rather than a constant for
## exactly one reason: the unit tests need to drive this code over a scratch file
## instead of over the player's real save, which is the single thing in this
## project that cannot be regenerated by playing. The game never reassigns it.
## `.tmp` and `.bak` siblings are derived from it, so a test redirects all three
## at once.
##
## Resolved at `_ready()` before `_load()` runs — see `resolved_save_path`.
var save_path: String = SAVE_PATH

var endless: bool = false

## Which named bundle of run-shaping constants this run uses
## (plant-tower-defense-s1o8.3). The SECOND thing carried across the title -> game swap,
## and deliberately shaped exactly like `endless` above: one field, written by the title
## screen, read once by `Game._ready()`. A run-shaping choice is a fact about a RUN.
##
## A NAME rather than the values. The bundle itself lives on `Game.DIFFICULTIES`, beside
## the constants it varies, so a reader who opens `LIVES` to ask "can this be other than
## 10" finds the answer in the next paragraph rather than in an autoload two files away.
## Carrying values here would also put a save-format question on something that is not
## saved: this is not persisted and must not be, because it describes one run and the
## high scores it would otherwise silently make incomparable are already split by mode.
##
## AN UNKNOWN NAME IS NOT A CRASH. `Game.difficulty_profile()` falls back to the standard
## bundle and says so, for the same reason `RunConfig`'s save reader keeps its scores when
## it cannot understand a file: a value from a later build must not take the run down.
var difficulty: StringName = &"standard"
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

## The records for every profile OTHER than standard, keyed "<mode>:<difficulty>"
## (plant-tower-defense-1hgx). Standard's two live in the fields above and are the two
## lines the save has always had; see `VERSION_WITH_DIFFICULTY_SCORES` for why that split
## is a meaning rather than a migration.
##
## A DICTIONARY RATHER THAN FOUR MORE FIELDS, because the profile set is `Game.DIFFICULTIES`
## and a fourth profile must not need a field here. `best_for` reads it through
## `score_key`, so nothing outside this file spells a key.
var difficulty_high_scores: Dictionary = {}

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

## The cosmetic skin chosen for each plant kind and pest species, as
## `Skins.selection_key(kind, id) -> skin id`. Absent means DEFAULT_SKIN — a fresh
## save and a pre-v10 save both read every target as unskinned, which is the correct
## reading rather than a fallback: nobody had a choice to lose before this existed.
##
## Set only through `set_skin()`, never assigned directly — see that function for why
## a raw assignment could persist a skin nobody has unlocked, or one no plant/pest
## this build knows exists.
var selected_skins: Dictionary = {}

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

## The two audio levels, as indices into `Sfx.LEVELS`, as the save records them.
##
## Plain data, for the fourth time in this file and for the fourth identical
## reason: `AudioServer` bus volume is PROCESS-GLOBAL, so a `_load` that pushed
## these into the mixer would make every test that drives this parser over a
## scratch file a test that silently retunes the whole suite's audio.
## `apply_audio_levels()` is the one door.
##
## **A LEVEL IS NOT A MUTE AND NEITHER SUBSUMES THE OTHER**, which is the design
## question this field exists to have answered rather than left implicit.
## `Sfx.LEVELS` contains no zero (see its own comment), so a dial cannot silence a
## category and a mute cannot be expressed as a level — the two are orthogonal, the
## mixer composes them, and unmuting always lands back on the level the player
## chose with nothing stashed anywhere. That is also why v8 ADDS two fields rather
## than widening `sfx`/`mus` from a flag to a level: a save that already reads
## `sfx1 mus0` still means exactly what it meant, effects muted and music audible,
## and migrating it costs nothing but the two new zeros appended to its line.
##
## Default 0 — full — which is both the first-launch value and what every save
## older than v8 reads as, by the same argument the speed's 0 makes: a player who
## never had the dial had a game at the volume it shipped with.
var sfx_level: int = 0
var music_level: int = 0

## Which step of `GameSpeed.STEPS` the player last chose, as the save records it.
##
## Plain data, exactly like `key_bindings` and the two mutes above it, and for the
## third time for the same reason: a `_load` that reached into `GameSpeed` would
## make every test that drives this parser over a scratch file a test that silently
## retimes the whole suite's engine clock. `Engine.time_scale` is process-global,
## so that failure would not even stay inside the test that caused it.
## `apply_game_speed()` is the one place that moves this into the engine.
##
## ALL THREE STEPS ARE STICKY, ½x INCLUDED, and that was the open question.
## Clamping the persisted value to {1x, 2x} was the alternative: a forgotten half
## speed makes a first run feel sluggish, and slow is harder for a player to
## diagnose than fast. It was rejected because the state is not hidden. The button
## sits on the top bar of every frame with `½x` on its face and the next step in
## its tooltip, one press from normal — which is exactly the affordance that makes
## a sticky setting safe, and exactly what a persisted invisible flag would lack.
## Against that, clamping buys a defect with no signal at all: two of the control's
## three steps would be remembered and the third silently would not, with nothing
## anywhere saying so. `kanban.md` also has the slow mode down as being for the
## person who drew this game and wants to watch it — a deliberate audience, who
## would have to re-choose it every launch.
##
## What would change this: the speed readout leaving the top bar (behind a menu,
## or a button that stops printing the current step), which turns it into invisible
## state and makes the clamp right; or an actual playtest report of a slow first
## run confusing someone, which is the measurement this taste call stands in for.
##
## Defaults to 0 — 1x — which is both the first-launch value and what every save
## older than v7 reads as, because a player who never had the control had a garden
## running at normal speed.
var game_speed_step: int = 0

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

## The path the last `_load()` read from — the one it would have MIGRATED and written
## back, which is the question `save_path` cannot answer after the fact
## (plant-tower-defense-58u7). Written by `_load`, never by anything else.
var loaded_from: String = ""

## The same, for the load `_ready()` did AT PROCESS START, and it is a second field rather
## than a reading of the first because every test that drives `_load` overwrites
## `loaded_from`. The guard that matters is about boot — nothing else in the process
## touches the player's file — so the assertion needs a value no later load can erase.
## Without this the test only worked while it happened to run before its neighbours.
var boot_loaded_from: String = ""

## The file `_load` refused, if any. The next `_save` moves it aside instead of
## writing over it: a file this build cannot read may still be one that a later
## build, or a person with a text editor, can.
var _refused_path: String = ""


## Pure: which file this process should persist to, given an environment and a display
## driver name (plant-tower-defense-58u7).
##
## Pure and static so the decision is testable without a second process. The three-way
## order is deliberate: an explicit `PLANT_TD_SAVE_PATH` beats everything, because a
## caller that named a path has said what it wants; headless falls to the scratch file;
## and only a process with a real display gets the player's save.
##
## An env var set to `""` is the same as unset — `OS.get_environment` returns `""` for a
## variable that does not exist, and there is no path that is the empty string.
static func resolved_save_path(env_path: String, display_name: String) -> String:
	if env_path != "":
		return env_path
	if display_name == "headless":
		return HEADLESS_SAVE_PATH
	return SAVE_PATH


## Every field `_load` fills, back to what a process that found no save file holds.
##
## Separate from `_load`, and it has to be: `_load` on a missing file returns EARLY with
## `load_status = "absent"` and assigns nothing at all. That is the right reading for a
## first launch — the declared defaults above already say it — and it is exactly wrong for
## the case this exists for, where the fields were filled from a file that is about to
## stop being this process's truth.
##
## RUN STATE IS NOT SAVE STATE and is deliberately untouched. `endless`, `difficulty`,
## `fresh_record`, `previous_best` and `fresh_record_endless` are what this run is doing;
## `_load` never writes them, and clearing them here would silently end a run in progress.
##
## Data only, exactly like `_load` itself and for the same reason: nothing here calls
## `apply_key_bindings`, `apply_audio_mutes`, `apply_audio_levels` or `apply_game_speed`.
## The InputMap, the `AudioServer` buses and `Engine.time_scale` are process-global, so a
## reset that pushed into them would reach every later test in a run rather than the one
## that asked.
func reset_persisted_state() -> void:
	campaign_high_score = 0
	endless_high_score = 0
	difficulty_high_scores = {}
	key_bindings = {}
	earned_milestones = {}
	colorblind_safe = false
	mute_sfx = false
	mute_music = false
	sfx_level = 0
	music_level = 0
	game_speed_step = 0
	load_status = ""
	loaded_from = ""
	_refused_path = ""


## Throws away the scratch file, so what this process starts holding is a property of THIS
## process rather than of every headless process before it (plant-tower-defense-xdp7).
##
## THE FILE AND THE FIELDS, and the second half is the one that actually bit. Eleven save
## tests failed on an unmodified checkout against a `d2 campaign:gentle=3453` line no run
## in the suite wrote. Redirecting `save_path` — which five test scripts already do in
## their `setup()`, and which is what `tools/save_persist_check.py` enforces — moves the
## WRITES and cannot undo the load this autoload already did at process start:
## `difficulty_high_scores` was still sitting there from a scratch file left behind weeks
## earlier, and `_save` composes it into every byte-exact assertion in the file.
##
## `.tmp` AND `.bak` GO TOO. `_load` adopts the temp file when the save is missing, which
## is the whole point of writing it separately — so deleting only the save would hand the
## next load the previous process's interrupted write in place of its finished one. That
## is the same defect wearing a disguise, and a much harder one to spot.
##
## Returns whether anything was there to throw away, so a caller can say so.
func discard_scratch_save() -> bool:
	var found: bool = false
	for path: String in [save_path, _tmp_path(), _backup_path()]:
		if FileAccess.file_exists(path):
			found = true
			DirAccess.remove_absolute(path)
	reset_persisted_state()
	return found


## Where this process persists, and what it starts holding — the whole boot decision,
## minus the three `apply_*` calls `_ready()` makes after it.
##
## A function rather than three lines inline so a test can run the real decision instead
## of a copy of it: this is the code path that made eleven save tests depend on which
## tests some earlier process happened to run, and a test that re-implemented it would
## have gone on passing while it drifted. The `apply_*` calls stay in `_ready()` on
## purpose — they push into the InputMap, the `AudioServer` and `Engine.time_scale`, all
## process-global, and a test forced to fire them to reach this would retune its whole run.
##
## THE DISCARD IS KEYED ON THE RESOLVED PATH, not on "are we headless". A caller that named
## a path through `PLANT_TD_SAVE_PATH` has said what it wants and may well have staged a
## file at it; deleting that would be answering a question nobody asked. Only the shared
## default — the path nobody chose and every headless process gets — is thrown away, which
## also leaves `HEADLESS_SAVE_PATH` the one known file a failing run's state can be read
## out of afterwards (plant-tower-defense-l6zo's argument against a per-run temp path).
##
## Concurrency is NOT what this fixes and is still open: two headless processes running at
## once still share this one path, and the second one's discard now removes the first's
## file rather than merely racing its writes. `user://` cannot be isolated at all (harness
## gh#28), so that stays plant-tower-defense-l6zo's question about the runner.
func adopt_save_path(env_path: String, display_name: String) -> void:
	save_path = resolved_save_path(env_path, display_name)
	if save_path == HEADLESS_SAVE_PATH:
		discard_scratch_save()
	_load()


func _ready() -> void:
	# The resolve happens BEFORE `_load()`, and that ordering is the whole of the earlier
	# fix: `_load` migrates an old format and writes it back, so a redirect installed
	# after it has already lost. `adopt_save_path` holds both halves plus the scratch
	# discard, so the order cannot come apart in the one caller that matters.
	adopt_save_path(OS.get_environment(SAVE_PATH_ENV), DisplayServer.get_name())
	boot_loaded_from = loaded_from
	apply_key_bindings()
	apply_audio_mutes()
	apply_audio_levels()


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
## Returns whether the bindings reached disk, for the one caller that can say so
## (plant-tower-defense-bia). Every other setter here still returns void: they are called
## from places with no screen to report on, and giving them all a return value nobody reads
## would be the dead code this repo has been bitten by before.
func store_key_bindings(map: Dictionary) -> bool:
	key_bindings = map
	return _save()


## The storage key for one (mode, difficulty) pair. Static and pure so a test can name a
## slot without a live RunConfig, and so nothing outside this file has to know that the
## standard profile is stored differently from the others.
static func score_key(for_endless: bool, difficulty_name: StringName) -> String:
	return "%s:%s" % ["endless" if for_endless else "campaign", difficulty_name]


## The record for a mode ON A PROFILE. Takes both rather than reading `endless` and
## `difficulty`, so the title screen can show any cell without having to lie about which
## one is selected — the reason the flag was already a parameter.
##
## `difficulty_name` DEFAULTS TO THE LIVE PROFILE, which keeps every existing call site
## meaning what it meant: before v9 there was one record per mode, and the one the player
## is about to play for is the one those callers wanted.
##
## An unknown profile reads 0 rather than falling back to standard's number, and that is
## deliberate in the opposite direction from `Game.difficulty_profile`: falling back there
## keeps a run playable, and falling back here would show a player a record they never set.
func best_for(for_endless: bool, difficulty_name: StringName = &"") -> int:
	var profile: StringName = difficulty_name if difficulty_name != &"" else difficulty
	if profile == Game.DIFFICULTY_STANDARD:
		return endless_high_score if for_endless else campaign_high_score
	return int(difficulty_high_scores.get(score_key(for_endless, profile), 0))


## Called once a run ends (win or lose). Only ever raises the record — a worse
## run than last time should not overwrite the number the player is proud of.
## Files against the mode that was actually played.
func record_score(seeds_earned: int) -> bool:
	if seeds_earned <= best_for(endless):
		return false
	previous_best = best_for(endless)
	fresh_record_endless = endless
	if difficulty == Game.DIFFICULTY_STANDARD:
		if endless:
			endless_high_score = seeds_earned
		else:
			campaign_high_score = seeds_earned
	else:
		difficulty_high_scores[score_key(endless, difficulty)] = seeds_earned
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
		preferences_line: String, bindings: Dictionary,
		other_difficulties: Dictionary = {}, skins: Dictionary = {}) -> String:
	var out: PackedStringArray = [
		"v%d" % SAVE_VERSION,
		str(campaign),
		str(endless_best),
		milestone_line,
		preferences_line,
		compose_difficulty_line(other_difficulties),
		compose_skins_line(skins),
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


## The v9 line carrying every non-standard record (plant-tower-defense-1hgx).
##
## COUNT-PREFIXED, like the binding block below it and for the same reason: a line cut in
## half is otherwise indistinguishable from a player who has only ever played standard.
## `d0` is the honest empty set and is what a fresh save writes.
##
## Sorted, so two saves holding the same records are byte-identical — the property the
## binding block's own sort exists for, and what makes a save comparable between runs.
##
## Zero-valued slots are dropped rather than written as `=0`: a record of nothing is the
## absence of a record, and keeping them would make the line grow with the profile table
## for no information.
static func compose_difficulty_line(scores: Dictionary) -> String:
	var fields: PackedStringArray = []
	var names: Array = scores.keys()
	names.sort()
	for name: Variant in names:
		var value: int = int(scores[name])
		if value > 0:
			fields.append("%s=%d" % [String(name), value])
	return " ".join(PackedStringArray(["d%d" % fields.size()]) + fields)


## Reads what `compose_difficulty_line` wrote. `null` on anything malformed, which is the
## convention every other `_parse_*` here follows so `_parse_save` can refuse the file
## rather than half-read it.
##
## A COUNT THAT DISAGREES WITH THE FIELDS IS A REFUSAL, not a truncation to be tolerated.
## The whole point of writing the count is that it can disagree.
static func parse_difficulty_line(text: String) -> Variant:
	var parts: PackedStringArray = text.split(" ", false)
	if parts.size() == 0 or not parts[0].begins_with("d"):
		return null
	var count_text: String = parts[0].substr(1)
	if not count_text.is_valid_int():
		return null
	var count: int = int(count_text)
	if count < 0 or parts.size() - 1 != count:
		return null
	var out: Dictionary = {}
	for i: int in range(1, parts.size()):
		var field: String = parts[i]
		var split: int = field.find("=")
		if split <= 0:
			return null
		var value_text: String = field.substr(split + 1)
		if not _is_score(value_text):
			return null
		out[field.substr(0, split)] = int(value_text)
	return out


## The v10 line carrying every chosen skin (plant-tower-defense-ncfv). Same shape as
## `compose_difficulty_line` immediately above — count-prefixed `key=value` fields,
## sorted so two saves holding the same choices are byte-identical — with two
## differences: the value is a skin id (a string), not a score, and a skin set to
## DEFAULT_SKIN is dropped rather than written, for the same reason
## `compose_difficulty_line` drops a zero score: the absence of a record already
## means "nothing chosen", so writing DEFAULT_SKIN out would grow the line for no
## information the reader does not already infer.
static func compose_skins_line(selections: Dictionary) -> String:
	var fields: PackedStringArray = []
	var keys: Array = selections.keys()
	keys.sort()
	for key: Variant in keys:
		var skin: String = String(selections[key])
		if skin != "" and skin != String(Skins.DEFAULT_SKIN):
			fields.append("%s=%s" % [String(key), skin])
	return " ".join(PackedStringArray(["s%d" % fields.size()]) + fields)


## Reads what `compose_skins_line` wrote. `null` on anything malformed — the same
## convention `parse_difficulty_line` follows, so `_parse_save` can refuse the whole
## file rather than half-read it.
##
## The key ("plant:sunflower") and the value (a skin id) are both validated against
## MILESTONE_ID_CHARS, plus the ":" that separates a kind from a target id — ids are
## written by this project, never by a player, so anything else is corruption. The
## kind half is NOT checked against KIND_PLANT/KIND_PEST here: a save from a later
## build may name a third kind this build does not have a screen for, and rejecting
## the whole save over one unfamiliar kind would cost the two scores it cannot
## refuse away. `Skins.has_target` is where an unknown kind or id is actually turned
## into "not selectable" — see `selected_skin()`.
static func parse_skins_line(text: String) -> Variant:
	var parts: PackedStringArray = text.split(" ", false)
	if parts.size() == 0 or not parts[0].begins_with("s"):
		return null
	var count_text: String = parts[0].substr(1)
	if not count_text.is_valid_int():
		return null
	var count: int = int(count_text)
	if count < 0 or parts.size() - 1 != count:
		return null
	var out: Dictionary = {}
	for i: int in range(1, parts.size()):
		var field: String = parts[i]
		var split: int = field.find("=")
		if split <= 0:
			return null
		var key: String = field.substr(0, split)
		var value: String = field.substr(split + 1)
		if value.is_empty() or not _is_id_text(value):
			return null
		var colon: int = key.find(":")
		if colon <= 0 or colon == key.length() - 1:
			return null
		if not _is_id_text(key.substr(0, colon)) or not _is_id_text(key.substr(colon + 1)):
			return null
		if out.has(key):
			return null
		out[key] = value
	return out


## Whether `text` is made only of MILESTONE_ID_CHARS — shared by the skins line's
## key and value halves, which follow the same "written by this project, never by a
## player" rule the milestone ids do.
static func _is_id_text(text: String) -> bool:
	if text.is_empty():
		return false
	for i: int in range(text.length()):
		if not MILESTONE_ID_CHARS.contains(text[i]):
			return false
	return true


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
		# REFUSED AT THE DOOR, because the alternative is that every later save in
		# this session fails and nothing says so to the caller.
		#
		# `_save()` writes the file and then reads it back through the loader's own
		# validator, and `_parse_milestones` rejects any id containing a character
		# outside MILESTONE_ID_CHARS (lowercase, digits, underscore). So an id with a
		# capital or a hyphen in it is accepted here, written, rejected on readback,
		# and `_save()` returns false -- for THIS call and for every subsequent one,
		# because the bad id is still sitting in `earned_milestones`. The player's
		# high score, settings and real milestones all quietly stop persisting.
		#
		# Measured: `record_milestones(["SNAPSHOT_PROBE"])` returned ["SNAPSHOT_PROBE"]
		# as freshly recorded, and the next four `_save()` calls in that session all
		# returned false. It cost most of a cycle to attribute, because the symptom
		# ("saves are failing") is nowhere near the cause and the reporting is split:
		# `_save` warns, `record_milestones` returns success.
		#
		# Loud rather than silent, and matching the hint refusal above: the run must
		# not stop over a bad id, but nobody should have to find this by bisection.
		if not is_recordable_milestone(text):
			push_warning(("RunConfig: '%s' is not a recordable milestone id -- only "
				+ "%s are legal. Refusing it here, because accepting it would make "
				+ "every save in this session fail silently.") % [text, MILESTONE_ID_CHARS])
			continue
		earned_milestones[text] = true
		fresh.append(text)
	if not fresh.is_empty():
		_save()
	return fresh


## The skin currently chosen for `kind`/`id`, or `Skins.DEFAULT_SKIN`.
##
## Reads back through `Skins.is_unlocked` rather than trusting the saved value
## outright: a milestone lost to a refused/quarantined save (see this file's own
## header) or a skin from a build newer than this one must not leave a plant or
## pest wearing a colour the player can no longer see a reason for on the Skins
## screen. Falling back to DEFAULT_SKIN here, rather than erroring, is the same
## "an unknown reads as off" contract `Milestones.is_met` and `Pest.tint_for` use.
func selected_skin(kind: StringName, id: StringName) -> StringName:
	var key: String = Skins.selection_key(kind, id)
	var chosen: StringName = StringName(selected_skins.get(key, Skins.DEFAULT_SKIN))
	if chosen == Skins.DEFAULT_SKIN:
		return chosen
	if not Skins.is_unlocked(chosen, earned_milestones):
		return Skins.DEFAULT_SKIN
	return chosen


## Sets the skin for `kind`/`id`, and persists it. Returns whether the choice took —
## false for an unknown target, an unknown skin, or one not yet unlocked, in which
## case `selected_skins` is left exactly as it was.
##
## THIS IS THE ONLY WRITER. A raw assignment to `selected_skins` could persist a
## skin the player has not earned, or a target this build does not have — either of
## which `selected_skin()` would then have to notice and correct on every read
## instead of being refused once, here, at the door.
##
## Idempotent like `record_milestones`: picking the skin already chosen changes
## nothing and does not touch the file.
func set_skin(kind: StringName, id: StringName, skin_id: StringName) -> bool:
	if not Skins.has_target(kind, id):
		return false
	if not Skins.is_unlocked(skin_id, earned_milestones):
		return false
	var key: String = Skins.selection_key(kind, id)
	if StringName(selected_skins.get(key, Skins.DEFAULT_SKIN)) == skin_id:
		return true
	if skin_id == Skins.DEFAULT_SKIN:
		selected_skins.erase(key)
	else:
		selected_skins[key] = String(skin_id)
	_save()
	return true


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


## Pushes whatever `_load` made of the two levels into the mixer. The dial twin of
## `apply_audio_mutes`, and safe on every load path for the same reason: a refused
## or absent save leaves both indices at 0, which is the same instruction as "play
## at the volume the game shipped with".
##
## CALLED FROM `_ready()`, unlike `apply_game_speed`, and the difference is worth
## stating because both touch process-global engine state. A saved ½x applied at
## autoload time would run the TITLE screen's animations at half speed, so the
## speed is a fact about a run and `Game._ready` applies it. A saved volume has no
## such seam: the title screen plays a music bed of its own within a frame of this
## running, and a dial that only took effect once a run started would leave the one
## piece of audio a player hears before pressing anything at full volume. So this is
## applied at process start, exactly like the mutes it sits beside.
func apply_audio_levels() -> void:
	Sfx.set_level(sfx_level)
	Music.set_level(music_level)


## Records a level for the one-shot cues and writes it down. Same shape and same
## contract as `set_mute_sfx`: the owner is set unconditionally so a mixer moved
## behind this file's back is resynced, the file is written only on an actual
## change, and the value afterwards is returned so a caller need not read it back.
##
## Refuses an index outside this build's own table, exactly as `store_game_speed`
## does and for the same reason: `Sfx.set_level` tolerates one by falling back to
## full, which is right for a save from a later build and wrong for a caller's
## off-by-one, because persisting it would make that off-by-one survive forever.
func set_sfx_level(index: int) -> int:
	if index < 0 or index >= Sfx.LEVELS.size():
		push_warning(("RunConfig: refusing to persist sound level %d — this build has %d levels. "
			+ "Keeping %d.") % [index, Sfx.LEVELS.size(), sfx_level])
		return sfx_level
	Sfx.set_level(index)
	if sfx_level == index:
		return sfx_level
	sfx_level = index
	_save()
	return sfx_level


func cycle_sfx_level() -> int:
	return set_sfx_level(Sfx.next_level(Sfx.level()))


## The music bed's half. Identical in shape to `set_sfx_level`; the level table is
## `Sfx.LEVELS` for both, because they are the same four steps on two faders (see
## `Music._level`).
func set_music_level(index: int) -> int:
	if index < 0 or index >= Sfx.LEVELS.size():
		push_warning(("RunConfig: refusing to persist music level %d — this build has %d levels. "
			+ "Keeping %d.") % [index, Sfx.LEVELS.size(), music_level])
		return music_level
	Music.set_level(index)
	if music_level == index:
		return music_level
	music_level = index
	_save()
	return music_level


func cycle_music_level() -> int:
	return set_music_level(Sfx.next_level(Music.level()))


## Records the garden speed the player has cycled to and writes it down. Returns
## the stored index, so a caller does not have to read it back.
##
## Same shape and same contract as `set_colorblind_safe`: writes only on an actual
## change, because the save file is not a place to record that someone pressed a
## key twice — and this key is pressed three times per full cycle back to 1x, so
## the guard is doing more work here than anywhere else in this file.
##
## Takes the index rather than the float, because the index is what `GameSpeed`
## considers the choice (`step()` survives a hold; `scale()` does not) and because
## a float on disk is a rounding argument waiting to happen.
##
## Refuses an index outside this build's own table. `GameSpeed.set_step` wraps with
## `posmod`, which is right for a player pressing a button and wrong for a persisted
## value: it would turn a caller's off-by-one into a silently different setting that
## then survives forever. An out-of-range index arriving from a SAVE is a different
## case and is kept — see MAX_SPEED_STEP.
func store_game_speed(index: int) -> int:
	if index < 0 or index >= GameSpeed.STEPS.size():
		push_warning(("RunConfig: refusing to persist garden speed step %d — this build has %d steps. "
			+ "Keeping %d.") % [index, GameSpeed.STEPS.size(), game_speed_step])
		return game_speed_step
	if game_speed_step == index:
		return game_speed_step
	game_speed_step = index
	_save()
	return game_speed_step


## Pushes the saved garden speed into the engine. The speed twin of
## `apply_key_bindings` / `apply_audio_mutes`, separate from `_load` for the reason
## `game_speed_step` spells out.
##
## NOT called from `_ready()`, unlike its two siblings, and that is the one thing
## about it worth knowing. This autoload readies at process start, while the TITLE
## screen is coming up, and a saved ½x applied there would run the title's own
## animations at half speed for no reason a reader of that scene could find — then
## `Game._exit_tree`'s `GameSpeed.reset()` would throw it away again on the first
## exit. The speed is a fact about a RUN, so the run applies it: `Game._ready()` is
## the single caller.
##
## Safe against all four writers of `Engine.time_scale`. It goes through
## `GameSpeed.set_step`, so a hold is respected (the parked choice moves and the
## engine stays at 1x, which is what a pause card must read at); `reset()` on
## `_end_run` and `_exit_tree` still puts the engine back to 1x on every way out of
## a run, and this call is what puts the choice back on the way in.
##
## An index this build has no step for falls back to 1x rather than wrapping — see
## MAX_SPEED_STEP for why such an index is on disk at all, and why it is left there.
func apply_game_speed() -> void:
	if game_speed_step < 0 or game_speed_step >= GameSpeed.STEPS.size():
		push_warning(("RunConfig: saved garden speed step %d is not one of this build's %d steps "
			+ "— starting at 1x. The saved value is kept for a build that has it.")
			% [game_speed_step, GameSpeed.STEPS.size()])
		GameSpeed.set_step(0)
		return
	GameSpeed.set_step(game_speed_step)


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
## Whether `id` can survive a save/load round trip.
##
## Derived from the same constant `_parse_milestones` validates against, rather than
## re-stating the rule — the two halves being written independently is exactly how a writer
## comes to accept what its own reader rejects, and that is the defect this exists to close.
## Static and pure so a test can ask without a save file, and so the check costs nothing at
## the call site.
static func is_recordable_milestone(id: String) -> bool:
	if id.is_empty():
		return false
	for i: int in range(id.length()):
		if not MILESTONE_ID_CHARS.contains(id[i]):
			return false
	return true


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


## One `<prefix><digits>` step index, or `null` if it is not one. The non-bool
## sibling of `_parse_flag`, and the only field on the options line that is not a
## flag — see OPTIONS_SPEED_PREFIX for why it is here at all.
##
## `is_valid_int()` before `int()`, for the reason `_is_score` spells out: `int("")`
## and `int("x")` are both 0 in GDScript, and 0 is a legal-looking step.
##
## `max_step` is a parameter with a default rather than a read of MAX_SPEED_STEP
## inside the body, because v8 gave this function three callers over two tables and
## a bound belongs to a table, not to a parser. The default keeps every existing
## two-argument call reading exactly as it did.
static func _parse_step(text: String, prefix: String, max_step: int = MAX_SPEED_STEP) -> Variant:
	if not text.begins_with(prefix):
		return null
	var body: String = text.substr(prefix.length())
	if not body.is_valid_int():
		return null
	var step: int = int(body)
	if step < 0 or step > max_step:
		return null
	return step


## The preferences line, read in the shape the file's own version defines.
##
## v5 is the lone colourblind flag; v6 is SWITCH_PREFIXES in order, space
## separated, all three required; v7 is those three followed by the speed field; v8
## is those four followed by the two audio levels.
## Split with empties KEPT, so `cb0  sfx0 mus0` is four fields and is refused: two
## spaces is not a shape this writer produces, and a parser that shrugs at it is a
## parser that would shrug at a half-written line.
##
## Returns {colorblind_safe, mute_sfx, mute_music, game_speed_step, sfx_level,
## music_level}, or `null` on anything else. A v5 line's two absent mutes read as
## false — a player who never had the setting had a game that made noise, which is
## exactly what unmuted means. A v5 or v6 line's absent speed reads as step 0, and a
## line older than v8 reads both absent levels as step 0, by the same argument each
## time: a player who never had the control had whatever the game shipped with.
static func _parse_preferences(text: String, version: int) -> Variant:
	if version < VERSION_WITH_MUTES:
		# Compared against the two v5 spellings outright rather than run through
		# `_parse_flag`. v5's line was one fixed word, not a prefixed field in a
		# sequence, and reading a closed format with the open format's parser is how
		# a shape nobody ever wrote (`cb0 ` with a trailing space, say) becomes
		# readable years after the writer that would have produced it is gone.
		if text == OPTIONS_COLORBLIND_ON:
			return {"colorblind_safe": true, "mute_sfx": false, "mute_music": false,
				"game_speed_step": 0, "sfx_level": 0, "music_level": 0}
		if text == OPTIONS_COLORBLIND_OFF:
			return {"colorblind_safe": false, "mute_sfx": false, "mute_music": false,
				"game_speed_step": 0, "sfx_level": 0, "music_level": 0}
		return null
	# Exactly three fields at v6, exactly four at v7, exactly six at v8 — never "at
	# least three". A tolerant count is how a v6 line read by this build would
	# silently keep its speed at 1x while the version header claimed the field was
	# there, and at v8 it is how a save whose levels were cut off would come back at
	# full volume for a player who had turned it down.
	var has_speed: bool = version >= VERSION_WITH_SPEED
	var has_levels: bool = version >= VERSION_WITH_LEVELS
	var expected: int = SWITCH_PREFIXES.size() + (1 if has_speed else 0) + (2 if has_levels else 0)
	var fields: PackedStringArray = text.split(" ")
	if fields.size() != expected:
		return null
	var values: Array[bool] = []
	for i: int in range(SWITCH_PREFIXES.size()):
		var flag: Variant = _parse_flag(fields[i], SWITCH_PREFIXES[i])
		if flag == null:
			return null
		values.append(bool(flag))
	var step: int = 0
	if has_speed:
		var parsed_step: Variant = _parse_step(fields[SWITCH_PREFIXES.size()], OPTIONS_SPEED_PREFIX)
		if parsed_step == null:
			return null
		step = int(parsed_step)
	var sfx_step: int = 0
	var music_step: int = 0
	if has_levels:
		# Bounded by MAX_LEVEL_STEP, not MAX_SPEED_STEP: same number today, two
		# different tables, and reading one table's field against the other's ceiling
		# is how a change to `GameSpeed.STEPS` silently starts refusing volumes.
		var parsed_sfx: Variant = _parse_step(fields[SWITCH_PREFIXES.size() + 1],
			OPTIONS_SFX_LEVEL_PREFIX, MAX_LEVEL_STEP)
		if parsed_sfx == null:
			return null
		var parsed_music: Variant = _parse_step(fields[SWITCH_PREFIXES.size() + 2],
			OPTIONS_MUSIC_LEVEL_PREFIX, MAX_LEVEL_STEP)
		if parsed_music == null:
			return null
		sfx_step = int(parsed_sfx)
		music_step = int(parsed_music)
	return {"colorblind_safe": values[0], "mute_sfx": values[1], "mute_music": values[2],
		"game_speed_step": step, "sfx_level": sfx_step, "music_level": music_step}


static func _flag_text(prefix: String, on: bool) -> String:
	return "%s%d" % [prefix, 1 if on else 0]


func _preferences_line() -> String:
	return " ".join(PackedStringArray([
		_flag_text(OPTIONS_COLORBLIND_PREFIX, colorblind_safe),
		_flag_text(OPTIONS_MUTE_SFX_PREFIX, mute_sfx),
		_flag_text(OPTIONS_MUTE_MUSIC_PREFIX, mute_music),
		"%s%d" % [OPTIONS_SPEED_PREFIX, game_speed_step],
		"%s%d" % [OPTIONS_SFX_LEVEL_PREFIX, sfx_level],
		"%s%d" % [OPTIONS_MUSIC_LEVEL_PREFIX, music_level],
	]))


func _parse_failed(reason: String) -> Dictionary:
	return {"ok": false, "campaign": 0, "endless": 0, "milestones": [],
		"colorblind_safe": false, "mute_sfx": false, "mute_music": false,
		"game_speed_step": 0, "sfx_level": 0, "music_level": 0,
		"bindings": {}, "version": 0, "difficulty_scores": {}, "skins": {}, "reason": reason}


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
			"game_speed_step": 0, "sfx_level": 0, "music_level": 0,
			"bindings": {}, "version": 1, "difficulty_scores": {}, "skins": {}, "reason": "v1"}

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
	var speed_step: int = 0
	var sfx_step: int = 0
	var music_step: int = 0
	if version >= VERSION_WITH_EXTRAS:
		# The one line whose SHAPE differs between four readable versions, so the
		# version goes in rather than being compared against here — a v5 line has one
		# field, a v6 line has three, a v7 line has four, a v8 line has six, and the
		# parser is told which it is looking at.
		var parsed_prefs: Variant = _parse_preferences(f.get_line().strip_edges(), version)
		if parsed_prefs == null:
			return _parse_failed("its preferences line is not a preferences line")
		var prefs := parsed_prefs as Dictionary
		colorblind = bool(prefs["colorblind_safe"])
		muted_sfx = bool(prefs["mute_sfx"])
		muted_music = bool(prefs["mute_music"])
		speed_step = int(prefs["game_speed_step"])
		sfx_step = int(prefs["sfx_level"])
		music_step = int(prefs["music_level"])

	# The v9 line, gated on VERSION_WITH_DIFFICULTY_SCORES for the reason
	# VERSION_WITH_EXTRAS exists: a v8 file does not have it, and reading one anyway would
	# consume the binding count as a difficulty line and then refuse the whole save.
	var difficulty_scores: Dictionary = {}
	if version >= VERSION_WITH_DIFFICULTY_SCORES:
		var parsed_diff: Variant = parse_difficulty_line(f.get_line().strip_edges())
		if parsed_diff == null:
			return _parse_failed("its difficulty-score line is not a difficulty-score line")
		difficulty_scores = parsed_diff as Dictionary

	# The v10 line, gated on VERSION_WITH_SKINS for the reason VERSION_WITH_DIFFICULTY_SCORES
	# exists one field up: a v9 file does not have it, and reading one anyway would consume
	# the binding count as a skin line and then refuse the whole save.
	var skins: Dictionary = {}
	if version >= VERSION_WITH_SKINS:
		var parsed_skins: Variant = parse_skins_line(f.get_line().strip_edges())
		if parsed_skins == null:
			return _parse_failed("its skin line is not a skin line")
		skins = parsed_skins as Dictionary

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
		"game_speed_step": speed_step,
		"sfx_level": sfx_step,
		"music_level": music_step,
		"version": version,
		"bindings": bindings,
		"difficulty_scores": difficulty_scores,
		"skins": skins,
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
	# THE PATH THIS LOAD ACTUALLY USED, kept because `save_path` is a variable and a
	# later assignment to it erases the evidence of what boot did
	# (plant-tower-defense-58u7). `_ready()` must resolve the redirect BEFORE calling
	# this, and reading `save_path` afterwards cannot tell the two orders apart — both
	# leave it pointing at the scratch file. This can: written here, it is whichever
	# path was in force when the file was opened and possibly migrated.
	loaded_from = path
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
	# A pre-v9 save has none, and an empty dictionary is the correct reading rather than a
	# fallback: before v9 the player could not have had a non-standard record recorded.
	difficulty_high_scores = parsed.get("difficulty_scores", {}) as Dictionary
	# A pre-v10 save has none, and an empty dictionary is the correct reading for the
	# same reason: before v10 there was no Skins screen to have chosen one on.
	selected_skins = parsed.get("skins", {}) as Dictionary
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
	# Data only again, and this one MUST be: `Engine.time_scale` is process-global,
	# so a `_load` that applied it would retime every test in the suite that ever
	# stages a save file. `apply_game_speed()` is the one door, and `Game._ready` is
	# the one caller — see `game_speed_step`.
	game_speed_step = int(parsed["game_speed_step"])
	# Data only for the fourth time, and this pair MUST be for the same reason the
	# speed must: `AudioServer` bus volume is process-global, so a `_load` that
	# applied it would retune every test in the suite that stages a save file.
	# `apply_audio_levels()` is the one door, and `_ready` is the one caller.
	sfx_level = int(parsed["sfx_level"])
	music_level = int(parsed["music_level"])
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
## Returns whether the record reached disk (plant-tower-defense-bia).
##
## `-> void` until now, with four failure paths that each `push_warning` and return. A
## warning goes to the editor log, which no player has, and to nowhere a SCREEN can read --
## so `KeyBindingScreen._persist` wrote on every capture and reported success by changing
## the row's key text, which looks identical when the write did not land.
##
## Every existing caller ignoring this is still correct: they had no answer before and the
## behaviour on failure is unchanged. Only callers that can SAY something need read it.
##
## THE RENAME FAILURE RETURNS TRUE, and that is the one judgement in here. Its own warning
## says "The finished save is at %s and _load will adopt it" -- the data is on disk, complete
## and validated, and the next launch picks it up. Reporting "not saved" there would be a lie
## in the other direction, and the one thing a save confirmation must never do is claim work
## was lost when it was not.
func _save() -> bool:
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
		return false
	f.store_string(compose_save(campaign_high_score, endless_high_score,
		_milestone_line(), _preferences_line(), key_bindings, difficulty_high_scores,
		selected_skins))
	f.flush()
	var write_error: int = f.get_error()
	f.close()
	if write_error != OK:
		# A short write is exactly the truncation this whole issue is about. Here
		# it lands in the temp file, where it can be thrown away instead of read.
		push_warning("RunConfig: %s while writing %s. Keeping the previous save."
			% [error_string(write_error), tmp])
		DirAccess.remove_absolute(tmp)
		return false
	var readback: Dictionary = _parse_save(tmp)
	if not bool(readback["ok"]):
		# Read back through the same validator the loader uses, so "whatever is at
		# save_path parses" is true by construction rather than by argument — and
		# so a future writer that its own reader cannot read fails here, loudly,
		# instead of at some player's next launch.
		push_warning("RunConfig: %s does not read back (%s). Keeping the previous save."
			% [tmp, str(readback["reason"])])
		DirAccess.remove_absolute(tmp)
		return false
	var rename_error: int = DirAccess.rename_absolute(tmp, save_path)
	if rename_error != OK:
		push_warning("RunConfig: %s replacing %s. The finished save is at %s and _load will adopt it."
			% [error_string(rename_error), save_path, tmp])
	# See the header: the data is on disk and _load adopts it, so this is a success.
	return true
