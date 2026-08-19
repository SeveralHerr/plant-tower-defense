class_name KeyBindings
extends RefCounted

## Every keyboard verb this game has, as real InputMap actions.
##
## Until this file existed there was no `[input]` section in project.godot and no
## call to InputMap anywhere: five keys were raw `key.keycode == KEY_*`
## comparisons scattered across Game, PauseScreen and NotebookScreen, and the one
## place any of them was *named* was Game.KEY_HELP — a hand-written legend sitting
## beside the handler it described, with a test scanning the handler's source to
## stop the two drifting apart. That test is the tell: a binding table that has to
## be policed by grep is a binding table with no owner.
##
## THE RULE OF THIS FILE: ACTIONS below is the only place a default key is
## written down. The InputMap is built from it, the pause card's legend is
## rendered from it (via Game.key_help()), the settings screen lists it, and the
## save file stores only the rows that differ from it. Nothing may hardcode a
## keycode against one of these verbs again.
##
## ## Why registered at runtime, and not in project.godot's [input]
##
## Because the default and the description have to be the same row. A player
## rebinding a key needs three things about each verb — its name, what it does,
## and what it is bound to now — and `[input]` can only hold the third. Putting
## the defaults there would split this table in half and re-create exactly the
## drift Game.KEY_HELP's scanning test was written to catch, one file further
## apart. It also matches how the rest of this project works: the screens, the
## theme and the sprites are all built in code, and project.godot holds almost
## nothing.
##
## The engine's own `ui_*` actions are untouched. They still come from the
## project defaults, they still drive Button focus, and NotebookScreen's page
## keys deliberately shadow `ui_left`/`ui_right` in `_input` — see the comment
## there.
##
## ## Static, not an autoload
##
## InputMap is already a global singleton, so there is no per-instance state to
## keep; and a `class_name` with constants is usable from a const expression,
## which an autoload name is not. `_static_init` installs the defaults the first
## moment anything touches this class, so no caller has to remember to. RunConfig
## applies the player's saved overrides on top, once, from its own `_ready`.

## The verbs a run answers to. Listed on the pause card, in this order.
const SCOPE_RUN := &"run"
## The verbs the Designer's Notebook answers to while it is open.
const SCOPE_NOTEBOOK := &"notebook"

const ACTION_PAUSE := &"garden_pause"
const ACTION_MUTE_SFX := &"garden_mute_sfx"
const ACTION_MUTE_MUSIC := &"garden_mute_music"
const ACTION_RESTART := &"garden_restart"
const ACTION_COLORBLIND := &"garden_colorblind"
const ACTION_SPEED := &"garden_speed"
const ACTION_PAGE_PREV := &"garden_page_prev"
const ACTION_PAGE_NEXT := &"garden_page_next"
const ACTION_BACK := &"garden_back"

## action -> what it does, what it is bound to out of the box, and which screen
## answers it. `does` is written as the second half of a legend row ("Esc · P
## hold the garden still"), so it is a verb phrase and not a sentence.
const ACTIONS: Array[Dictionary] = [
	{
		"action": ACTION_PAUSE,
		"does": "hold the garden still",
		"defaults": [KEY_ESCAPE, KEY_P],
		"scope": SCOPE_RUN,
	},
	{
		"action": ACTION_MUTE_SFX,
		"does": "sound effects on or off",
		"defaults": [KEY_M],
		"scope": SCOPE_RUN,
	},
	{
		"action": ACTION_MUTE_MUSIC,
		"does": "music on or off",
		"defaults": [KEY_N],
		"scope": SCOPE_RUN,
	},
	{
		"action": ACTION_RESTART,
		"does": "start over, once the run is done",
		"defaults": [KEY_R],
		"scope": SCOPE_RUN,
	},
	{
		"action": ACTION_COLORBLIND,
		"does": "colourblind-safe health and threat bars",
		"defaults": [KEY_C],
		"scope": SCOPE_RUN,
	},
	{
		# Last of the run-scope rows, so the block stays contiguous: `actions_in`
		# preserves table order and both the pause card's legend and the Keys
		# screen's rows are drawn from it.
		#
		# F rather than Space: Space is `ui_accept`, so it fires whichever HUD button
		# currently holds focus, and a verb that sometimes grows a wave instead of
		# speeding one up is worse than no shortcut. F is unbound here and is what a
		# fast-forward is called everywhere else.
		"action": ACTION_SPEED,
		# Names both directions, because it is one control: see GameSpeed.STEPS.
		"does": "run the garden faster, or slower",
		"defaults": [KEY_F],
		"scope": SCOPE_RUN,
	},
	{
		"action": ACTION_PAGE_PREV,
		"does": "turn back a page",
		"defaults": [KEY_LEFT],
		"scope": SCOPE_NOTEBOOK,
	},
	{
		"action": ACTION_PAGE_NEXT,
		"does": "turn forward a page",
		"defaults": [KEY_RIGHT],
		"scope": SCOPE_NOTEBOOK,
	},
	{
		"action": ACTION_BACK,
		"does": "close what is open",
		"defaults": [KEY_ESCAPE],
		"scope": SCOPE_NOTEBOOK,
	},
]

## `OS.get_keycode_string` is correct and long. The pause card's legend is the
## narrowest place any of this is drawn -- `PauseScreen.key_row_max_width()` at
## `PauseScreen.KEY_ROW_FONT_SIZE` -- so the handful of keys whose engine name does
## not fit get a short form here. Anything absent falls through to the engine's own
## name, which is what keeps this from becoming a second key table.
##
## That budget is a FUNCTION now, not the constant this line used to name: the card
## sizes itself to its widest bound key, so a long name here no longer clips, it
## widens the card. Which makes this table's job smaller than it was -- it is about
## a name being unreadable ("On-screen keyboard" for a key nobody calls that), not
## about a name being too wide to draw.
##
## The budget is named rather than repeated as a number: this comment said "the
## pause card is 320px wide" and stayed saying it after the card was widened to
## hold the longest `does` phrase.
##
## ## What earns a row here, and what does not
##
## The engine names a key badly in two different ways, and only one of them needs
## writing down.
##
## **It spends a word where the key prints a glyph.** `KEY_BRACKETLEFT` comes back
## "BracketLeft"; the key has `[` printed on it and `[` is what a player calls it.
## That set is a RULE and not a taste call — across the printable block the glyph
## simply IS the keycode — so it is not recorded at all. `key_label()` falls
## through to `glyph_for()`, and the 32 punctuation keys need no rows. The 36
## letter and digit keycodes take the same path and come out character-for-
## character identical to the engine's own name, which is why that rule could be
## stated over the whole block rather than over a list of the keys it improves.
##
## **It spends an abbreviation nobody says where the key prints no glyph.** "Kp 0"
## for the numeric keypad; "Escape" where every keyboard prints Esc. Nothing
## derives "Num 0" from "Kp 0", so those rows live here. Their KEYS are still
## derivable — the engine's own name for a keypad key begins with "Kp " — and
## `test_short_names_is_exactly_the_keys_the_glyph_rule_cannot_reach` asserts the
## recorded keys equal that derived set in both directions, so a keypad key the
## engine grows arrives as a failing test rather than as one stray "Kp" on a
## legend. The seven rows below the keypad block are the judgement half and are
## hand-typed on purpose: changing that set should cost somebody a diff.
##
## Everything else keeps the engine's name. "F1", "Home", "PageUp" are already
## what a player calls them, and a second spelling for those would be the second
## key table this file exists to avoid.
##
## One row is LONGER than what it replaces: "Num 0" (5) against the engine's
## "Kp 0" (4). It is the only place the trade goes that way and it is safe in both
## places a key is drawn — `PauseScreen.key_column_width()` measures
## `label_for()` itself, and `KeyBindingScreen.key_column_width()` is sized for
## every name the ENGINE can produce, whose widest ("On-screen keyboard") no row
## here comes close to.
const SHORT_NAMES: Dictionary = {
	# Keypad. Derived keys, chosen values: the engine calls these "Kp 0" .. "Kp 9",
	# "Kp Multiply" and so on, and "Kp" is not a word anybody says out loud.
	KEY_KP_MULTIPLY: "Num *",
	KEY_KP_DIVIDE: "Num /",
	KEY_KP_SUBTRACT: "Num -",
	KEY_KP_PERIOD: "Num .",
	KEY_KP_ADD: "Num +",
	KEY_KP_0: "Num 0",
	KEY_KP_1: "Num 1",
	KEY_KP_2: "Num 2",
	KEY_KP_3: "Num 3",
	KEY_KP_4: "Num 4",
	KEY_KP_5: "Num 5",
	KEY_KP_6: "Num 6",
	KEY_KP_7: "Num 7",
	KEY_KP_8: "Num 8",
	KEY_KP_9: "Num 9",
	# The keypad's Enter is the one keypad key a player does not distinguish from
	# the other one, so it is named for what it does rather than for where it sits.
	KEY_KP_ENTER: "Enter",
	# Judgement. No rule reaches these: the arrows print an arrow that the engine
	# spells as a word, and the rest are what the keycap says.
	KEY_ESCAPE: "Esc",
	KEY_LEFT: "←",
	KEY_RIGHT: "→",
	KEY_UP: "↑",
	KEY_DOWN: "↓",
	# Space and Enter already match `OS.get_keycode_string`, so neither shortens
	# anything. They are pins, not abbreviations: Space sits one code below
	# `GLYPH_FIRST`, and widening that bound by one would otherwise render it as
	# the invisible character it prints.
	KEY_SPACE: "Space",
	KEY_ENTER: "Enter",
}

## The keycodes whose glyph is the character the code IS: the printable ASCII
## block, minus space (0x20), whose glyph is invisible and which therefore keeps
## the word `SHORT_NAMES` gives it.
##
## Anchored on the engine's own first and last printable constants rather than on
## 0x21 and 0x7E, so a keycode table that renumbers takes this bound with it.
const GLYPH_FIRST: int = KEY_EXCLAM
const GLYPH_LAST: int = KEY_ASCIITILDE

## Separator between the keys of a multi-key verb, matching the legend the pause
## card has always drawn ("Esc  ·  P").
const KEY_JOIN := "  ·  "

## A save file that claims more bound keys than this is not a save file we wrote.
## Purely a sanity bound on the parser — see RunConfig._parse_save.
const MAX_KEYS_PER_ACTION: int = 4


## Runs the first time anything in the project touches `KeyBindings`, which is
## before any screen can ask what a key is bound to. Registering here rather than
## from an autoload's `_ready` means a unit test that builds one screen in
## isolation gets the same InputMap the running game has.
static func _static_init() -> void:
	install()


## Registers every action with its default keys. Idempotent, and deliberately
## non-destructive: an action that already carries events is left exactly as it
## is, so calling this again cannot undo a player's rebinding. `reset_all()` is
## the call that does clobber.
static func install() -> void:
	for row: Dictionary in ACTIONS:
		var action := StringName(row["action"])
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			_bind(action, defaults_for(action))


## Every action this game defines, in table order.
static func actions() -> Array[StringName]:
	var out: Array[StringName] = []
	for row: Dictionary in ACTIONS:
		out.append(StringName(row["action"]))
	return out


## The actions belonging to one screen, in table order.
static func actions_in(scope: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for row: Dictionary in ACTIONS:
		if StringName(row["scope"]) == scope:
			out.append(StringName(row["action"]))
	return out


static func is_known(action: StringName) -> bool:
	for row: Dictionary in ACTIONS:
		if StringName(row["action"]) == action:
			return true
	return false


## The row for an action, or an empty Dictionary. Callers that already know the
## action exists should still check, because a typo'd StringName is otherwise a
## silent empty legend rather than an error.
static func row_for(action: StringName) -> Dictionary:
	for row: Dictionary in ACTIONS:
		if StringName(row["action"]) == action:
			return row
	return {}


## What the action does, for a legend or a settings row.
static func describe(action: StringName) -> String:
	var row: Dictionary = row_for(action)
	return String(row.get("does", ""))


## The keys the table ships with. A fresh copy each call — the const's own array
## must never be handed out somewhere it could be mutated.
##
## Built with a loop rather than a slice or a duplicate: an untyped Array
## returned as Array[int] is a runtime error, and this is a path a settings
## screen hits on every Reset.
static func defaults_for(action: StringName) -> Array[int]:
	var out: Array[int] = []
	var row: Dictionary = row_for(action)
	for code: int in (row.get("defaults", []) as Array):
		out.append(code)
	return out


## What the action is bound to right now, read back out of the InputMap rather
## than out of any copy we keep. The InputMap is the truth; this file only seeds
## it.
static func keys_for(action: StringName) -> Array[int]:
	var out: Array[int] = []
	if not InputMap.has_action(action):
		return out
	for event: InputEvent in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var code: int = key.keycode if key.keycode != KEY_NONE else key.physical_keycode
		if code != KEY_NONE and not out.has(code):
			out.append(code)
	return out


## Rebinds an action. Refuses an empty list: an unbound verb is a verb the player
## can no longer reach and no screen in this game explains how to get it back.
## Returns whether anything was changed.
static func set_keys(action: StringName, keys: Array[int]) -> bool:
	if not is_known(action) or keys.is_empty():
		return false
	install()
	_bind(action, keys)
	return true


## Puts one action back on its shipped keys.
static func reset_action(action: StringName) -> bool:
	return set_keys(action, defaults_for(action))


static func reset_all() -> void:
	install()
	for action: StringName in actions():
		_bind(action, defaults_for(action))


## Which other action already answers to `code`, or `&""`.
##
## Two verbs on one key is not an error the engine reports — both handlers simply
## fire, in whatever order the tree happens to walk — so the settings screen has
## to ask before it writes. `except` is the row being edited, which is allowed to
## keep its own key.
static func action_using(code: int, except: StringName = &"") -> StringName:
	for action: StringName in actions():
		if action == except:
			continue
		if keys_for(action).has(code):
			return action
	return &""


## Every action whose current keys differ from the table's, as
## {action_name: Array[int]}. This — and not the whole table — is what gets
## saved: a defaults change in a later build should reach a player who never
## touched that row, and it only can if their save does not pin it.
static func overrides() -> Dictionary:
	var out: Dictionary = {}
	for action: StringName in actions():
		var now: Array[int] = keys_for(action)
		if now != defaults_for(action):
			out[String(action)] = now
	return out


## Applies a saved override set over the defaults. Returns the names it declined,
## which is the interesting half: a save written by a build that had an action
## this one does not is a downgrade, not corruption, and dropping the row it
## cannot place is the right answer where refusing the file is not (RunConfig
## keeps the player's high scores in the same file — see its header).
static func apply_overrides(saved: Dictionary) -> Array[String]:
	reset_all()
	var dropped: Array[String] = []
	for name: Variant in saved.keys():
		var action := StringName(name)
		if not is_known(action):
			dropped.append(String(name))
			continue
		var keys: Array[int] = []
		for code: Variant in (saved[name] as Array):
			keys.append(int(code))
		if not set_keys(action, keys):
			dropped.append(String(name))
	return dropped


## The character printed on this key, or "" for a key that prints none.
##
## This is the whole of "the engine names it badly" that needs no judgement, and
## the reason 32 punctuation keys have no rows in `SHORT_NAMES`. Inside the
## printable block the engine's own fallback for an unnamed code is this same
## character, so letters and digits come out unchanged and only the keys the
## engine spelled as a word move — "BracketLeft" to "[".
static func glyph_for(code: int) -> String:
	if code < GLYPH_FIRST or code > GLYPH_LAST:
		return ""
	return String.chr(code)


## One key, as short as it can be said.
static func key_label(code: int) -> String:
	if SHORT_NAMES.has(code):
		return String(SHORT_NAMES[code])
	var glyph: String = glyph_for(code)
	if glyph != "":
		return glyph
	var name: String = OS.get_keycode_string(code)
	return name if name != "" else "?"


## Every key an action answers to, as one legend cell ("Esc  ·  P").
static func label_for(action: StringName) -> String:
	var parts: PackedStringArray = []
	for code: int in keys_for(action):
		parts.append(key_label(code))
	if parts.is_empty():
		return "unbound"
	return KEY_JOIN.join(parts)


static func _bind(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for code: int in keys:
		var event := InputEventKey.new()
		# `keycode`, not `physical_keycode`: the settings screen captures whatever
		# the player pressed straight off the event, and every InputEventKey this
		# project builds in a test sets `keycode` too. Matching on the logical key
		# keeps those three in agreement.
		event.keycode = code
		InputMap.action_add_event(action, event)
