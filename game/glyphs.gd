class_name Glyphs
extends RefCounted

## Every non-ASCII character this game's source carries, and what each one means.
##
## ## Why this file exists
##
## Two vocabularies were drawing from the same alphabet with nobody holding both
## halves. `KeyBindings.SHORT_NAMES` owns the four arrows as KEY NAMES — the
## printed name of KEY_LEFT is literally "←". The screens separately reached for
## glyphs as marks and separators, and one of those reaches picked "←" as the
## mark meaning "this key is about to be taken back". On the key screen, which is
## the one screen that draws both, an arrow key with an armed revert read "← ←".
##
## Nothing caught it. It was found by looking at a screenshot, and the reasoning
## that replaced it (a bullet, `KeyBindingScreen.KEY_REVERT_MARK`) lives in a
## comment beside that constant, where the next person choosing a mark will not
## read it. This table is that reasoning moved somewhere a test can check.
##
## ## The rule the collision actually breaks
##
## It is NOT "no glyph may be used twice". "← Back" is fine and always was —
## the word "Back" carries the meaning and the arrow only decorates it. What
## cannot happen is a glyph that **stands alone** next to a value and is also a
## key's name, because then the value and the glyph are read as two keys.
##
## So every drawn glyph carries a ROLE, and the gate is narrow:
##
##     MARK ∩ KeyBindings.SHORT_NAMES.values() = ∅
##
## `test_placement.gd` asserts it, derives the KEY_NAME rows from `SHORT_NAMES`
## itself rather than from anything typed here, and checks both directions.
##
## ## What this table does and does not claim
##
## It claims: every non-ASCII character appearing anywhere in `res://game/*.gd`
## has a row here, and every row's glyph is still somewhere in that source.
## Both directions are swept at test time over the real files.
##
## It does NOT claim that `drawn_in` is the complete list of files drawing a
## glyph. Those are WITNESSES — a short list that must still hold, chosen so a
## glyph cannot quietly stop being drawn at all. For the six glyphs that have a
## real named constant behind them the test asserts against that constant
## instead, which is the strong form; the witness list is the weak form for the
## glyphs still written inline. Moving an inline glyph onto a constant here is
## an upgrade from the weak form to the strong one.


## The glyph IS a key's printed name. This set is owned by
## `KeyBindings.SHORT_NAMES` and is derived from it, never typed here.
const ROLE_KEY_NAME := "key_name"

## The glyph stands ALONE beside a value and carries its whole meaning with no
## word to lean on. This is the only role the collision can bite, because a bare
## glyph beside a value is indistinguishable from a second value.
const ROLE_MARK := "mark"

## The glyph stands BETWEEN two things and belongs to neither.
const ROLE_SEPARATOR := "separator"

## The glyph never appears without an adjoining word in the same string. The word
## carries the meaning, so sharing the glyph with a key name is harmless.
const ROLE_WORDED := "worded"

## Part of a number's printed form.
const ROLE_NUMERAL := "numeral"

## Appears only in comments and doc headers. Never drawn, never a player's
## problem — recorded so that the sweep below can be TOTAL rather than filtered,
## because a filter is where a real glyph goes to hide.
const ROLE_PROSE := "prose"


## Named so the screens can read the table instead of retyping the character.
## A glyph typed inline is a glyph with no row.
const MIDDOT := "·"
const HALF := "½"
const EM_DASH := "—"
const BULLET := "•"
const ELLIPSIS := "…"
const PREV_ANGLE := "‹"
const NEXT_ANGLE := "›"
const LEFT_ARROW := "←"
const UP_ARROW := "↑"
const RIGHT_ARROW := "→"
const DOWN_ARROW := "↓"
const INFINITY := "∞"
## The Petal shop's two marks. Named here as well as in `ShopScreen` because this
## table is what says a drawn character has been thought about, and both of these are
## Dingbats — the first block this project has drawn from that its shipped font is not
## guaranteed to carry. `ShopScreen._mark()` asks `Font.has_char()` before drawing
## either, so a row here is a claim about what the glyph MEANS, not a promise that it
## renders; the fallback is that screen's business.
const PETAL := "✿"
const TICK := "✓"


## One row per distinct non-ASCII character in `res://game/*.gd`.
##
## `roles` is an Array because exactly one glyph legitimately has two, and that
## fact is asserted rather than tolerated — see `dual_role_glyphs()`.
const TABLE: Array[Dictionary] = [
	{
		"glyph": MIDDOT,
		"codepoint": 0x00B7,
		"unicode_name": "MIDDLE DOT",
		"roles": [ROLE_SEPARATOR],
		"means": "Joins peers of equal weight: the keys of one verb (\"Esc  ·  P\"), the halves of a hint (\"Arrows to choose  ·  Enter to grow\"), the items of a short list.",
		"drawn_in": ["key_bindings.gd", "title_screen.gd", "hud.gd"],
	},
	{
		"glyph": HALF,
		"codepoint": 0x00BD,
		"unicode_name": "VULGAR FRACTION ONE HALF",
		"roles": [ROLE_NUMERAL],
		"means": "Half. Only the slow step of the speed button, where two characters is a hard budget and \"0.5x\" is four.",
		"drawn_in": ["game_speed.gd"],
	},
	{
		"glyph": EM_DASH,
		"codepoint": 0x2014,
		"unicode_name": "EM DASH",
		"roles": [ROLE_SEPARATOR],
		"means": "Joins a subject to the clause that qualifies it, inside one sentence (\"12 seeds grown — a new best\"). Prose punctuation, never a mark on a value.",
		"drawn_in": ["run_summary.gd", "plant_catalog.gd", "notebook_screen.gd"],
	},
	{
		"glyph": BULLET,
		"codepoint": 0x2022,
		"unicode_name": "BULLET",
		"roles": [ROLE_MARK],
		"means": "This binding is one press away from being taken back. Appended bare to a key name while the reset is armed, as the second channel beside the DANGER tint.",
		"drawn_in": ["key_binding_screen.gd"],
	},
	{
		"glyph": ELLIPSIS,
		"codepoint": 0x2026,
		"unicode_name": "HORIZONTAL ELLIPSIS",
		"roles": [ROLE_WORDED],
		"means": "Waiting on the player (\"Press a key…\", \"Listening…\"). Always trails a word.",
		"drawn_in": ["key_binding_screen.gd"],
	},
	{
		"glyph": PREV_ANGLE,
		"codepoint": 0x2039,
		"unicode_name": "SINGLE LEFT-POINTING ANGLE QUOTATION MARK",
		"roles": [ROLE_WORDED],
		"means": "The notebook's previous page (\"‹ Prev\"). An angle rather than an arrow precisely so the pager cannot be read as a key name.",
		"drawn_in": ["notebook_screen.gd"],
	},
	{
		"glyph": NEXT_ANGLE,
		"codepoint": 0x203A,
		"unicode_name": "SINGLE RIGHT-POINTING ANGLE QUOTATION MARK",
		"roles": [ROLE_WORDED],
		"means": "The notebook's next page (\"Next ›\"). Mirror of PREV_ANGLE, and chosen for the same reason.",
		"drawn_in": ["notebook_screen.gd"],
	},
	{
		"glyph": LEFT_ARROW,
		"codepoint": 0x2190,
		"unicode_name": "LEFTWARDS ARROW",
		"roles": [ROLE_KEY_NAME, ROLE_WORDED],
		"means": "The Left arrow key's printed name, AND the decoration on a worded back affordance (\"← Back\", \"← just now\"). The only glyph in this game meaning two things, and the only one allowed to — a back button always carries its word, so it can never be mistaken for a key. Nothing may add a third role, and nothing may make it a MARK.",
		"drawn_in": ["key_bindings.gd", "overlay_screen.gd", "title_screen.gd"],
	},
	{
		"glyph": UP_ARROW,
		"codepoint": 0x2191,
		"unicode_name": "UPWARDS ARROW",
		"roles": [ROLE_KEY_NAME],
		"means": "The Up arrow key's printed name.",
		"drawn_in": ["key_bindings.gd"],
	},
	{
		"glyph": RIGHT_ARROW,
		"codepoint": 0x2192,
		"unicode_name": "RIGHTWARDS ARROW",
		"roles": [ROLE_KEY_NAME],
		"means": "The Right arrow key's printed name.",
		"drawn_in": ["key_bindings.gd"],
	},
	{
		"glyph": DOWN_ARROW,
		"codepoint": 0x2193,
		"unicode_name": "DOWNWARDS ARROW",
		"roles": [ROLE_KEY_NAME],
		"means": "The Down arrow key's printed name.",
		"drawn_in": ["key_bindings.gd"],
	},
	{
		"glyph": PETAL,
		"codepoint": 0x273F,
		"unicode_name": "BLACK FLORETTE",
		"roles": [ROLE_MARK],
		"means": "One petal, the currency skins are bought with. Appended bare to a price (\"Heirloom Gold  5✿\") because the word does not fit: three priced buttons carrying \"5 petals\" measured 1164px against a 1152px canvas, so the unit is carried by the balance line and the note instead and the price wears the mark. Bare beside a number, which is the shape the collision gate bites, so it is gated with the rest.",
		"drawn_in": ["shop_screen.gd"],
	},
	{
		"glyph": TICK,
		"codepoint": 0x2713,
		"unicode_name": "CHECK MARK",
		"roles": [ROLE_MARK],
		"means": "This skin is the one the target is wearing. Appended to an owned family's title on a disabled button, as the second channel beside the disabled tint. Unlike the petal it has a word that fits, so `ShopScreen` falls back to \"worn\" when the font cannot draw it.",
		"drawn_in": ["shop_screen.gd"],
	},
	{
		"glyph": INFINITY,
		"codepoint": 0x221E,
		"unicode_name": "INFINITY",
		"roles": [ROLE_MARK],
		"means": "This run has no final wave. Appended bare to the wave number (\"Wave  9999 ∞\") because the spelled-out version measured 397px against a 320px budget. Bare beside a number is exactly the shape the collision bites, so this one is gated.",
		"drawn_in": ["hud.gd"],
	},
	{
		"glyph": "°",
		"codepoint": 0x00B0,
		"unicode_name": "DEGREE SIGN",
		"roles": [ROLE_PROSE],
		"means": "Degrees, in comments describing gape and sweep angles. Never drawn.",
		"drawn_in": [],
	},
	{
		"glyph": "±",
		"codepoint": 0x00B1,
		"unicode_name": "PLUS-MINUS SIGN",
		"roles": [ROLE_PROSE],
		"means": "A tolerance in a comment. Never drawn.",
		"drawn_in": [],
	},
	{
		"glyph": "–",
		"codepoint": 0x2013,
		"unicode_name": "EN DASH",
		"roles": [ROLE_PROSE],
		"means": "A numeric range in a comment. Distinct from EM_DASH, which is the drawn one — do not swap them.",
		"drawn_in": [],
	},
	{
		"glyph": "↔",
		"codepoint": 0x2194,
		"unicode_name": "LEFT RIGHT ARROW",
		"roles": [ROLE_PROSE],
		"means": "A two-way relation in a comment. Never drawn — and it must stay that way, because it is one arrow away from the key vocabulary.",
		"drawn_in": [],
	},
	{
		"glyph": "−",
		"codepoint": 0x2212,
		"unicode_name": "MINUS SIGN",
		"roles": [ROLE_PROSE],
		"means": "Arithmetic in a comment. Not the ASCII hyphen, and not drawn.",
		"drawn_in": [],
	},
	{
		"glyph": "≈",
		"codepoint": 0x2248,
		"unicode_name": "ALMOST EQUAL TO",
		"roles": [ROLE_PROSE],
		"means": "Approximation in a comment. Never drawn.",
		"drawn_in": [],
	},
]


## Every glyph carrying `role`, sorted, so a caller never depends on TABLE order.
static func with_role(role: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for row: Dictionary in TABLE:
		if _roles_of(row).has(role):
			out.append(String(row["glyph"]))
	out.sort()
	return out


## The glyphs that stand alone beside a value. THE set the gate tests against
## `KeyBindings.SHORT_NAMES.values()`.
static func marks() -> PackedStringArray:
	return with_role(ROLE_MARK)


## Every glyph this game actually puts on screen — everything that is not
## comment-only prose.
static func drawn() -> PackedStringArray:
	var out: PackedStringArray = []
	for row: Dictionary in TABLE:
		if not _roles_of(row).has(ROLE_PROSE):
			out.append(String(row["glyph"]))
	out.sort()
	return out


## Every glyph in the table, drawn or prose, sorted.
static func all_glyphs() -> PackedStringArray:
	var out: PackedStringArray = []
	for row: Dictionary in TABLE:
		out.append(String(row["glyph"]))
	out.sort()
	return out


## Glyphs carrying more than one role. Expected to be exactly [LEFT_ARROW]; the
## suite asserts that, because a second dual-role glyph is a decision somebody
## should have to make on purpose.
static func dual_role_glyphs() -> PackedStringArray:
	var out: PackedStringArray = []
	for row: Dictionary in TABLE:
		if _roles_of(row).size() > 1:
			out.append(String(row["glyph"]))
	out.sort()
	return out


## The row for `glyph`, or an empty Dictionary if the table has none.
static func row_for(glyph: String) -> Dictionary:
	for row: Dictionary in TABLE:
		if String(row["glyph"]) == glyph:
			return row
	return {}


## What `glyph` means, in one sentence, or "" if it is not in the table.
static func meaning(glyph: String) -> String:
	var row := row_for(glyph)
	return "" if row.is_empty() else String(row["means"])


## The witness files recorded for `glyph` — see the class header on what a
## witness does and does not claim.
static func witnesses(glyph: String) -> PackedStringArray:
	var row := row_for(glyph)
	if row.is_empty():
		return PackedStringArray()
	var out: PackedStringArray = []
	for f: String in row["drawn_in"]:
		out.append(f)
	return out


static func _roles_of(row: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for r: String in row["roles"]:
		out.append(r)
	return out
