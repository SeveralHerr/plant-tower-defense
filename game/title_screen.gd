class_name TitleScreen
extends Control

## The main scene. Two ways into the same game.tscn: the fixed 8-wave campaign,
## or endless (WaveDirector keeps escalating past the table — see
## WaveDirector._endless_groups). RunConfig.endless is the one flag that
## survives the scene swap; the high score it also carries is read here so a
## returning player sees it before they even press Start.
##
## `skip_to_game()` exists for the harness: devtools_config.json's entry_hook
## calls it so an automated check lands in the playable scene without a real
## mouse click on a button that only exists after _ready().
##
## Everything here is positioned by hand against the constants below rather than
## by a Container. That is deliberate for a fixed-size fullscreen menu — the
## numbers are checkable (`node-bounds`, and the tests below) and there is no
## Container silently resetting a child's scale mid-tween. The HUD's top bar is
## the opposite case and uses an HBoxContainer, for the reason written there.

const GAME_SCENE := "res://game/game.tscn"

## Layout, top to bottom. The one hard constraint is that the last interactive
## row has to clear TitleBackdrop.HORIZON (0.74 of the height, 479px at 648)
## so the scenery never sits under a button.
const TITLE_Y: float = 88.0
const SUBTITLE_Y: float = 154.0
const SCORE_Y: float = 182.0
## ## Why the menu is a grid and not a column
##
## It was one column of full-width rows, and it had run out of screen. Everything
## here has to end above TitleBackdrop.HORIZON (0.74 of the viewport — 479 at
## 648); three rows fitted at the shipped pitch, a fourth (Keys) did not, and a
## fifth (Options) was paid for out of three constants at once because no single
## one had slack: the header came up 10 (subtitle 158 -> 154, score 190 -> 182,
## top 218 -> 208), the two heights each lost 4, and the gap lost 2. That left
## five rows footing at 448 with the hint at 454..476 and every number at its
## floor — the secondary height is 40 because `findings` gates an interactive
## Control at 40x40, and the header cannot come up further without the subtitle
## running into the wordmark's box.
##
## So a sixth destination — credits, a difficulty picker, the trophy shelf if it
## ever leaves the notebook — had nowhere to go AT ANY PITCH, and the old comment
## here said exactly that and left it there.
##
## The fix is a shape, not another pixel: the two rows that start a run stay
## full-width, and the secondary destinations pair up TWO TO A ROW inside the same
## 300px band. Halving the row count of the half of the menu that grows buys the
## sixth, seventh and eighth destinations without moving BUTTON_TOP, without
## shrinking a button below the 40px gate, and without pushing anything past the
## horizon. `menu_capacity()` computes that ceiling rather than asserting it, and
## test_the_title_menu_has_room_for_the_next_destination is the check that says so.
##
## The two shapes not taken. A scrolling list puts destinations below a fold on
## the one screen whose whole problem was that the keyboard verbs were
## undiscoverable. A single "More" door scales forever but moves the game's own
## account of itself — the Designer's Notebook — a click further away, and this
## screen is a player's first thirty seconds.
##
## The cost is one label: "Designer's Notebook" draws ~183px at the theme's
## button size and a half-band cell is 146, so the title's button says "Notebook".
## The notebook's own heading, and the pause card's button, still say the whole
## thing.
const BUTTON_TOP: float = 208.0
## The band the whole menu lives in — the FULL width of a primary row and of a
## secondary PAIR together. Deliberately unchanged at 300 by the grid: it is what
## `button_column()` reports and what PLANT_X's "x 426-726" note is about, so a
## wider band would silently invalidate the two clear lawn bands documented there.
const BUTTON_WIDTH: float = 300.0
const BUTTON_HEIGHT: float = 44.0
## The rows that are not "start a run": shorter, because they are not the thing
## the screen is for. 40 is a floor, not a preference — `findings` gates an
## interactive Control at 40x40.
const SECONDARY_BUTTON_HEIGHT: float = 40.0
const BUTTON_GAP: float = 8.0
## How many entries at the top of MENU_BUTTON_NAMES are full-width primaries.
## Everything after them is a secondary destination and pairs up two to a row.
## One number rather than a parallel table of spans, so a destination added to
## MENU_BUTTON_NAMES cannot end up with a layout row nobody wrote.
const PRIMARY_COUNT: int = 2
## The hint line, sized and placed relative to whatever the menu turned out to be.
## It was a hand-picked HINT_Y: 454, which is how a sixth button would have landed
## on top of it rather than being refused. Derived, the hint moves when the menu
## does and `menu_capacity()` can account for it.
const HINT_GAP: float = 6.0
const HINT_HEIGHT: float = 22.0

## Every button in the menu, in reading order. A list rather than five names
## spelled out at each call site: `_link_focus`, `_set_menu_active`,
## `_play_entrance` and three layout tests all need the same set, and the tests
## were carrying their own copy of it — which is how adding the fourth button
## broke them rather than being checked by them.
##
## Order is the contract: the first PRIMARY_COUNT are the full-width rows, the
## rest fill the grid left-to-right then top-to-bottom, and both the focus ring
## and the entrance stagger read it.
const MENU_BUTTON_NAMES: Array[String] = [
	"StartButton", "EndlessButton", "NotebookButton", "KeysButton", "OptionsButton",
]


## The menu laid out as rows of indices into MENU_BUTTON_NAMES.
##
## The first PRIMARY_COUNT entries take a row each. The rest pair up — except a
## lone trailing secondary, which spans the whole band rather than leaving a hole
## beside it, so an odd count reads as a decision instead of an accident.
static func menu_rows(count: int) -> Array[PackedInt32Array]:
	var rows: Array[PackedInt32Array] = []
	var i: int = 0
	while i < count:
		if i < PRIMARY_COUNT or i + 1 >= count:
			rows.append(PackedInt32Array([i]))
			i += 1
		else:
			rows.append(PackedInt32Array([i, i + 1]))
			i += 2
	return rows


## How tall row `row_index` is. The primaries come first and one to a row, so the
## row index and the button index agree for exactly that many rows.
static func row_height(row_index: int) -> float:
	return BUTTON_HEIGHT if row_index < PRIMARY_COUNT else SECONDARY_BUTTON_HEIGHT


## Where menu button `index` goes, in a menu of `count` buttons. The one place
## that answers "where does the Nth destination sit" — which is the question the
## old five hand-written positions had no answer to for N=6.
static func button_rect(index: int, count: int) -> Rect2:
	var left: float = float(viewport_width()) / 2.0 - BUTTON_WIDTH / 2.0
	var y: float = BUTTON_TOP
	var rows: Array[PackedInt32Array] = menu_rows(count)
	for r: int in rows.size():
		var row: PackedInt32Array = rows[r]
		var height: float = row_height(r)
		for c: int in row.size():
			if row[c] != index:
				continue
			if row.size() == 1:
				return Rect2(left, y, BUTTON_WIDTH, height)
			var cell: float = (BUTTON_WIDTH - BUTTON_GAP) / 2.0
			return Rect2(left + float(c) * (cell + BUTTON_GAP), y, cell, height)
		y += height + BUTTON_GAP
	return Rect2()


## The y at which the last button of a `count`-button menu ends.
static func menu_bottom(count: int) -> float:
	var rows: Array[PackedInt32Array] = menu_rows(count)
	if rows.is_empty():
		return BUTTON_TOP
	var y: float = BUTTON_TOP
	for r: int in rows.size():
		y += row_height(r) + BUTTON_GAP
	return y - BUTTON_GAP


## Where the hint line sits under a `count`-button menu.
static func hint_y(count: int) -> float:
	return menu_bottom(count) + HINT_GAP


## The largest menu this screen can hold with the hint still clear of
## TitleBackdrop.HORIZON.
##
## Computed, not written down. The number the single column could not raise was
## 5, and it was 5 at every pitch anyone tried; this says what the grid actually
## buys instead of a comment claiming it. Terminates because hint_y() grows with
## every row.
static func menu_capacity() -> int:
	var horizon: float = float(viewport_height()) * TitleBackdrop.HORIZON
	var n: int = 0
	while hint_y(n + 1) + HINT_HEIGHT <= horizon:
		n += 1
	return n

## Where a decorative plant's stem meets the ground, and how much bigger than
## its board size it is drawn here.
const PLANT_BASE_Y: float = 514.0
## 1.5 since the EIGHTH plant (the Salve Aloe, plant-tower-defense-ibvb). It was 1.7, and
## the paragraph above `PLANT_X` predicted this exact day: "That is the day to drop
## PLANT_SCALE or go to two rows." Dropping the scale is the cheaper of the two it named and
## the one that keeps a single lawn line, which is the composition the screen is built on.
##
## The arithmetic, which is what makes 1.5 the number rather than a guess. A band runs from
## the button column to the screen edge, 426px either side. A canvas is 64 * scale, so four
## of them need 256 * scale: at 1.7 that is 436 and does not fit, at 1.5 it is 384 and fits
## with 42px to spare. 1.6 also fits (409.6) but leaves only 16px across three joins, which
## is inside the margin the seventh slot had to spend ink measurements to recover — so 1.5
## buys the next plant as well, and the next one after that is the two-row day for real.
const PLANT_SCALE: float = 1.5
## The board sprites are square art at this size; PLANT_SCALE enlarges them from
## it. Written down rather than measured off a texture because plant_span()
## below has to answer "does slot 3 clear the buttons" without loading anything —
## test_the_title_lawn_shows_every_plant_in_the_catalogue pins it to the real
## texture width so it cannot drift.
const PLANT_ART_WIDTH: float = 64.0

## One hand-placed slot per plant, in PlantCatalog.ids() order.
##
## The *list* is derived — _build_scenery walks the catalogue, so a plant added
## to PlantCatalog stands on the lawn without anyone remembering a second list.
## The lawn used to name its four plants outright and the Sticky Sundew was
## therefore missing from the first thing a new player ever sees.
##
## The *placement* is not derived, and deliberately so: these four x positions
## were chosen by eye against the backdrop's furrows, not divided evenly out of
## the width, for the same reason nothing on this screen is in a Container. The
## pairing that falls out of catalogue order happens to read, too — the two
## tier-1 plants stand left of the buttons and the two you have to open a packet
## for stand right of them.
##
## Every slot has to keep its whole sprite clear of the centre column the buttons
## occupy (x 426-726 at 1152 wide). At PLANT_SCALE a decoration is 109px wide, so
## a new slot may only live in x 60-371 or x 781-1092; there is room for about one
## more in each band before they start to crowd. If the catalogue outgrows the
## slots, lawn_plants() drops the surplus and says so — see the note there.
## (Those two bands are the CANVAS bands and both are now overspilled a little at the
## edges — see the seventh-slot paragraph below, which measures in ink instead and says
## why. The 426-726 column is the one number here that is still absolute: it is what
## test_the_title_lawn_clears_the_button_column_and_the_horizon checks, in canvases.)
##
## The fifth slot (the Bomb Dandelion) went into the RIGHT band, and the two
## slots already there moved left to make room, rather than into the left band
## where there was also space. That keeps the reading the comment above describes:
## catalogue order puts the two tier-1 plants — the ones you start with or open a
## cheap packet for — left of the buttons, and everything a pricier packet has to
## hand over right of them. Three in that band at 806/940/1074 leaves 25px between
## sprites and 24px of margin at the screen edge; a fourth does not fit, and
## test_the_title_lawn_shows_every_plant_in_the_catalogue says so.
## The SIXTH slot (Garden Mint) went into the LEFT band and the two already there respaced
## from 132/272 to 100/215 to make room at 330. Not the right band, despite Mint being tier 2
## like the two plants that live there: three 109px sprites already overhang that band's
## 311px by 29px a side, and a fourth would have to overlap rather than merely overhang.
##
## Spacing is 115 against the right band's 134, so the gap between sprites is 6px rather than
## 25. That is the cost of a sixth plant: tighter, still positive, still clear of the button
## column (330 + 54.5 = 384.5 against 426).
##
## THE SEVENTH SLOT (Prickly Nettle), and the paragraph above said it would not fit. It does
## not fit *in canvases*, and that turned out to be the wrong unit to measure in.
##
## The arithmetic that says no is real: a band runs from the button column to the screen edge,
## 426px either side, and four 109px canvases need 436. There is no arrangement of four that
## does not overlap, in either band, at PLANT_SCALE. That is what "a SEVENTH does not fit"
## meant and it is still true as stated.
##
## But 109px is the CANVAS, and art_src/STYLE.md:13 sizes the drawing INSIDE it: "loose
## objects use ~40-56 px of the 64". Every sprite here therefore carries transparent margin,
## and it is the INK that must not collide. Measured off the sources rather than assumed —
## these are half-widths in screen px, i.e. the SVG's own content half-width times
## PLANT_SCALE:
##
##   * sunflower  45.9   art_src/sunflower.svg:21-32, the petal ring: 12 petals centred 18
##                       from the middle with an 8px semi-axis, so 27 of the 32 available
##                       (this is the widest sprite in the catalogue and the one that binds)
##   * dandelion  40.5   art_src/dandelion.svg:47-49, a pappus of r=3.2 plus a 0.6 rim on the
##                       r=20 tuft ring
##   * sundew     39.4   art_src/sticky_sundew.svg:20, whose header states its own content box
##                       as x 8.8..55.2
##   * nettle     31.8   art_src/nettle.svg, content box 13.28..50.72 as
##                       tools/svg_style_check.py measures it
##
## So the right band is respaced from 806/940/1074 to 786/889/992 with the Nettle at 1095.
## Canvases overlap by 6px at each join and NO INK DOES: 17.7px of clear space between the
## sunflower and the sundew, 22.8 between the sundew and the dandelion, 30.4 between the
## dandelion and the nettle. The two hard edges are checked in canvases, because that is what
## the tests measure and what a redraw could fill: the sunflower's left edge is 731.5 against
## the column at 726, and the nettle's right edge is 1149.5 against the viewport's 1152.
##
## The Nettle goes rightmost ON PURPOSE and that is not a free choice — it is the narrowest
## sprite in the catalogue, and the rightmost slot is the one with 2.5px of canvas margin to
## the screen edge. Putting any of the other three there would have been the same 2.5px of
## canvas over 8px of ink instead of 25.
##
## THE EIGHTH ARRIVED (the Salve Aloe), and the paragraph that used to sit here was right on
## both counts: the ink trick did not stretch to it, and the answer was to drop PLANT_SCALE.
## It is 1.5 now, and its own comment carries the arithmetic.
##
## At 1.5 a canvas is 96px, so FOUR fit in each 426px band with 42px to spare and the whole
## ink argument above becomes slack rather than load-bearing. The slots are therefore
## re-derived as an even four per band instead of the hand-tuned seven, which is a simpler
## thing to keep true:
##
##   left  band, centres  60 / 165 / 270 / 375   (375 + 48 = 423, clear of the column at 426)
##   right band, centres 780 / 885 / 990 / 1095  (780 - 48 = 732, clear of it; 1095 + 48 =
##                                                1143, inside the 1152 viewport)
##
## Both hard edges keep more canvas margin than the seven-slot layout did — 3px at the
## column and 9px at the screen edge, against 5.5 and 2.5 — so the Nettle no longer has to be
## rightmost for its narrowness. It still is, because catalogue order puts it there and
## nothing is gained by moving it.
##
## A NINTH is the two-row day, and this time there is no third trick: five 96px canvases need
## 480 in a 426px band. lawn_plants() still degrades with a push_warning until someone does it.
##
## In CATALOGUE order, not left-to-right order -- lawn_plants() maps by index -- so the
## out-of-sequence 270.0 and 375.0 near the end are correct and not typos.
const PLANT_X: Array[float] = [
	60.0, 165.0, 780.0, 885.0, 990.0, 270.0, 1095.0, 375.0,
]
## The bugs the plants are there to fight, marching across the soil.
const PEST_BASE_Y: float = 606.0
const PEST_SCALE: float = 1.15
## `offset` is both the starting x and the phase of the walk bob. Neither is 0:
## a pest starting at 0 begins its life off the left edge, so the title screen
## opens with one bug visible instead of two.
const PESTS: Array[Dictionary] = [
	{"sprite": "res://assets/sprites/pest_aphid.png", "speed": 46.0, "offset": 210.0},
	{"sprite": "res://assets/sprites/pest_beetle.png", "speed": 31.0, "offset": 700.0},
]
## How far past each edge a pest travels before wrapping, so it walks off rather
## than blinking out at the boundary.
const PEST_MARGIN: float = 60.0

## Sway amplitude in radians and its rate. Small on purpose — this is a plant in
## a breeze, not a metronome.
const SWAY_RADIANS: float = 0.055
const SWAY_RATE: float = 1.15

const ENTRANCE_SECONDS: float = 0.32
const ENTRANCE_RISE: float = 26.0
const ENTRANCE_STAGGER: float = 0.07

var _start_button: Button
var _endless_button: Button
var _notebook_button: Button
var _keys_button: Button
var _options_button: Button
var _notebook: NotebookScreen = null
var _keys_screen: KeyBindingScreen = null
var _options_screen: OptionsScreen = null

## The gradient behind everything, held rather than re-found by name:
## `_apply_viewport_layout()` re-sizes it on every window change.
var _backdrop: TitleBackdrop = null

var _plants: Array[Sprite2D] = []
var _pests: Array[Sprite2D] = []
var _elapsed: float = 0.0


func _ready() -> void:
	# Explicit position+size, not an anchor preset: this Control is the scene
	# root added straight under the Viewport with no sized CanvasLayer/Control
	# ancestor to anchor against, so PRESET_FULL_RECT silently resolved to a
	# 0x0 rect — invisible on the bare title screen (INK is nearly the
	# viewport's own clear colour) but very visible once the Notebook overlay
	# tried to use the same trick to hide the buttons underneath it.
	position = Vector2.ZERO
	size = Vector2(get_viewport_width(), get_viewport_height())
	# Set on the root, so the Notebook — which is added as a child of this node
	# at runtime — inherits the same Button look without asking for it.
	theme = GardenTheme.build()

	_backdrop = TitleBackdrop.new()
	_backdrop.name = "Backdrop"
	_backdrop.position = Vector2.ZERO
	_backdrop.size = size
	# The scenery is scenery. Without this it is a full-screen Control sitting
	# over every button, and `reachable-ui` is right to call them blocked.
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	Music.play_for_scene(scene_file_path)

	_build_scenery()
	_build_text()
	_build_buttons()
	_play_entrance()

	# CHECKED, not assumed: this is the main scene's root and it is never rebuilt.
	# A player who resizes or maximises the window is, almost by definition, doing
	# it on the first screen they see — so of the three surfaces this lane touched
	# it is the one MOST likely to be live during a resize, not the least.
	var vp: Viewport = get_viewport()
	if vp != null and not vp.size_changed.is_connected(_apply_viewport_layout):
		vp.size_changed.connect(_apply_viewport_layout)


## The covering layer, re-derived. Deliberately NOT the composition.
##
## `TitleBackdrop` paints its gradient and its horizon across its own rect, so a
## Backdrop left at the design size on a widened window leaves a bare strip of the
## window's clear colour down one side — the most visible symptom this screen had
## of reading the setting instead of the screen.
##
## The menu, the wordmark and the lawn do NOT move here. They are a fixed
## composition in design coordinates whose internal relationships are pinned by
## tests (`plant_span()` vs `button_column()`, `menu_capacity()` vs the horizon),
## and the right fix for a fixed composition on a bigger canvas is one translation
## of the whole thing — see `viewport_width()`.
func _apply_viewport_layout() -> void:
	# `size_changed` outlives the build: a resize landing while the scene is being
	# swapped out for game.tscn reaches a half-torn-down screen.
	if _backdrop == null or not is_instance_valid(_backdrop):
		return
	size = Vector2(get_viewport_width(), get_viewport_height())
	_backdrop.position = Vector2.ZERO
	_backdrop.size = size


func _build_text() -> void:
	# The COMPOSITION width, not the live one. These three Labels are full-width
	# and centred, and the menu under them is placed by the static `button_rect()`
	# — which is design-width by construction. A live width here would centre the
	# wordmark on the window while the buttons stayed centred on the design canvas,
	# which is a title screen with two different middles.
	var width: float = float(viewport_width())

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Pest Control"
	title.position = Vector2(0, TITLE_Y)
	title.size = Vector2(width, 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", GardenTheme.PAPER)
	# The wordmark sits over a gradient, not a flat fill, so it needs its own
	# contrast rather than relying on the backdrop's value staying put. Same
	# shadow treatment the in-game banner uses.
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	add_child(title)

	var subtitle := Label.new()
	subtitle.name = "SubtitleLabel"
	subtitle.text = "Plants fight bugs. One free plant to start."
	subtitle.position = Vector2(0, SUBTITLE_Y)
	subtitle.size = Vector2(width, 26)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", GardenTheme.LEAF)
	add_child(subtitle)

	var score := Label.new()
	score.name = "HighScoreLabel"
	score.text = high_score_text()
	score.position = Vector2(0, SCORE_Y)
	score.size = Vector2(width, 24)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 15)
	score.add_theme_color_override("font_color", GardenTheme.GOLD)
	add_child(score)
	# The roll is armed BEFORE the flag is cleared, and reads the values it needs off
	# RunConfig while they are still true. Order matters here and nowhere else in this
	# builder.
	_arm_record_ratchet(score)
	# Announced once, on the first title screen after the record. Cleared here
	# rather than inside high_score_text() so that builder stays pure and a test
	# can call it twice without the second call disagreeing with the first.
	RunConfig.fresh_record = false

	var hint := Label.new()
	hint.name = "HintLabel"
	# "Arrows", not "Up / Down": the secondary destinations sit two to a row now,
	# so Left and Right are real moves and a hint naming only two of the four
	# would be describing the menu this screen used to be.
	hint.text = "Arrows to choose  ·  Enter to grow"
	hint.position = Vector2(0, hint_y(MENU_BUTTON_NAMES.size()))
	hint.size = Vector2(width, HINT_HEIGHT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(GardenTheme.PAPER, 0.55))
	add_child(hint)


## Zero is not a score, it is the absence of one, and "Best garden: 0 seeds grown"
## reads like a bug on a first launch. Separated out so the wording is assertable
## without building the screen.
##
## Both modes are named, because they are two different games and this line used
## to claim every record belonged to endless whichever mode had set it. When only
## one mode has been played the other is simply omitted rather than shown as a
## zero — an absent record and a bad one should not look alike.
##
## It also marks a record set moments ago. Without that, leaving a run on a
## personal best said nothing anywhere: _end_run hands record_score's return to
## the post-mortem's "a new best", but the pause exits drop it, and this line
## reads identically whether the number moved a second ago or three sessions back.
## The flag is cleared by the screen that shows it, not here — a static builder
## that mutates state cannot be called twice by a test.
static func high_score_text() -> String:
	return high_score_text_at(RunConfig.best_for(false), RunConfig.best_for(true),
		RunConfig.fresh_record)


## The same line for a GIVEN pair of numbers, which is what makes the roll possible:
## the ratchet renders this once per frame with an interpolated value, so the moving
## line and the settled one are produced by the same function and cannot disagree
## about spacing, separators or which modes are named
## (plant-tower-defense-9z1).
static func high_score_text_at(campaign: int, endless: int, fresh: bool) -> String:
	if campaign <= 0 and endless <= 0:
		return "No garden on record yet."
	var parts: PackedStringArray = []
	if campaign > 0:
		parts.append("Campaign %d" % campaign)
	if endless > 0:
		parts.append("Endless %d" % endless)
	var line: String = "Best seeds grown  —  %s" % " · ".join(parts)
	if fresh:
		return "%s   ← just now" % line
	return line


## How long the digits take to arrive, and how many steps they arrive in.
##
## Stepped rather than continuous: a counter that lands on 4,997 for one frame on
## its way to 5,008 reads as a glitch, and a player cannot follow more than a few
## values anyway. RATCHET_STEPS is what the roll actually shows.
const RATCHET_SECONDS: float = 0.8
const RATCHET_STEPS: int = 24


## Rolls the new record's digits up from the one it beat.
##
## **The label already holds the final text before this runs**, and that is the rule
## every animation on these screens follows: headless pumps no frames, so a tween that
## is responsible for arriving at the correct state leaves the correct state
## unreachable in every test and on any machine where animation is off. This only ever
## overwrites a correct line with an intermediate one and then puts it back.
##
## Silent unless there is something to show: no fresh record, no roll. And no roll when
## the previous best was 0 either -- a first-ever record has nothing to count up FROM,
## and rolling 0 -> 308 would tell a player who has just set their first score that
## they climbed from a zero they never held.
func _arm_record_ratchet(score: Label) -> void:
	if not GardenTheme.animations_enabled() or not RunConfig.fresh_record:
		return
	var from: int = RunConfig.previous_best
	if from <= 0:
		return
	var endless: bool = RunConfig.fresh_record_endless
	var to: int = RunConfig.best_for(endless)
	if to <= from:
		return
	# The mode that did NOT move is held at its real value for the whole roll.
	var other: int = RunConfig.best_for(not endless)
	var tween := create_tween()
	tween.tween_method(
		func(value: float) -> void:
			var shown: int = int(round(lerpf(float(from), float(to), value)))
			score.text = (high_score_text_at(other, shown, true) if endless
				else high_score_text_at(shown, other, true)),
		0.0, 1.0, RATCHET_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Put the real line back at the end rather than trusting the last interpolation
	# step to land exactly on `to` -- lerpf at t=1.0 does, but a tween that is
	# interrupted (the player presses a key and the screen changes) does not run its
	# last step at all, and the label would keep whatever number it was mid-count.
	tween.tween_callback(func() -> void:
		if is_instance_valid(score):
			score.text = high_score_text_at(RunConfig.best_for(false),
				RunConfig.best_for(true), true))


func _build_buttons() -> void:
	# Every position comes from button_rect(), which is the only thing that knows
	# the shape of the menu. Nothing here counts pixels down the screen any more,
	# so a destination appended to MENU_BUTTON_NAMES lands somewhere real rather
	# than on top of the hint.
	var count: int = MENU_BUTTON_NAMES.size()

	# What each mode is goes in the label, not in a tooltip.
	#
	# A first pass put it in `tooltip_text` and that was wrong twice over. A
	# title screen is the one place a player has not learned to hover yet, so
	# the difference between the two modes was hidden behind a gesture nobody
	# makes on a menu. And the tooltip outlives the button: pressing Designer's
	# Notebook while its own tooltip is up leaves that tooltip floating over the
	# notebook, because the popup belongs to the Viewport rather than to the
	# button the overlay covered.
	_start_button = _make_button(0, count, "Start  ·  8 waves")
	_start_button.pressed.connect(_start_campaign)

	_endless_button = _make_button(1, count, "Endless  ·  no finish line")
	_endless_button.pressed.connect(_start_endless)

	# "Notebook", not "Designer's Notebook", and only because of the cell width —
	# see the grid note above BUTTON_TOP. The screen it opens still heads itself
	# with the whole name, and so does the pause card's button, which sits in a
	# full-width row and can afford it.
	_notebook_button = _make_button(2, count, "Notebook")
	_notebook_button.pressed.connect(_open_notebook)

	# The keyboard verbs were undiscoverable and unchangeable: the only screen that
	# named them was the pause card, which needs a run in progress to reach.
	_keys_button = _make_button(3, count, "Keys")
	_keys_button.pressed.connect(_open_keys)

	# The three persisted switches had exactly one surface between them: a
	# keystroke during a run, answered by a HUD sentence that faded. The Keys
	# screen could move those keys but not read what they were set to, so the one
	# screen this game had for configuration was the one place a player could not
	# see whether the colourblind bars were on.
	_options_button = _make_button(4, count, "Options")
	_options_button.pressed.connect(_open_options)

	# Explicit wrap-around, so Down off the last button returns to the first
	# instead of dead-ending — the geometric default only ever walks the list.
	_link_focus(menu_buttons())
	_start_button.grab_focus()


## The column, top to bottom, in MENU_BUTTON_NAMES order.
func menu_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for node_name: String in MENU_BUTTON_NAMES:
		var button := get_node_or_null(node_name) as Button
		if button != null:
			out.append(button)
	return out


## Named and placed from MENU_BUTTON_NAMES + button_rect, so a call site cannot
## hand a button a name the layout does not know about.
func _make_button(index: int, count: int, label: String) -> Button:
	var button := Button.new()
	button.name = MENU_BUTTON_NAMES[index]
	button.text = label
	var rect: Rect2 = button_rect(index, count)
	button.position = rect.position
	button.size = rect.size
	add_child(button)
	return button


## Two different walks over the same menu, because the menu is a grid now.
##
## Tab (focus_previous/next) keeps the flat ring in reading order: every
## destination once, in MENU_BUTTON_NAMES order, wrapping at both ends.
##
## The arrow keys (focus_neighbor_*) follow the GRID. That distinction is the
## whole point: with a single ring on the neighbours, Down from "Notebook" would
## reach "Keys" — the button to its RIGHT — which is the failure mode that makes a
## two-column menu feel broken even though every button is reachable. Down goes to
## the row below, staying in the same column where that row has one; Left and
## Right move within a row and are left unset on a full-width row, which has no
## sideways to go.
##
## Both wrap. The hint on screen says the arrows choose, and a ring is what a
## player who holds Down expects; Godot's geometric default walks the list and
## stops dead at each end.
func _link_focus(buttons: Array[Button]) -> void:
	for i: int in buttons.size():
		buttons[i].focus_previous = buttons[(i - 1 + buttons.size()) % buttons.size()].get_path()
		buttons[i].focus_next = buttons[(i + 1) % buttons.size()].get_path()

	var rows: Array[PackedInt32Array] = menu_rows(buttons.size())
	for r: int in rows.size():
		var row: PackedInt32Array = rows[r]
		var above: PackedInt32Array = rows[(r - 1 + rows.size()) % rows.size()]
		var below: PackedInt32Array = rows[(r + 1) % rows.size()]
		for c: int in row.size():
			var button: Button = buttons[row[c]]
			# A narrower neighbouring row has no cell in this column; land on its
			# last one rather than nowhere.
			button.focus_neighbor_top = buttons[above[mini(c, above.size() - 1)]].get_path()
			button.focus_neighbor_bottom = buttons[below[mini(c, below.size() - 1)]].get_path()
			if row.size() > 1:
				button.focus_neighbor_left = buttons[row[(c - 1 + row.size()) % row.size()]].get_path()
				button.focus_neighbor_right = buttons[row[(c + 1) % row.size()]].get_path()


## Which plants the lawn shows, in catalogue order.
##
## A catalogue longer than PLANT_X is a layout decision somebody has to make, not
## something to paper over by cramming a fifth sprite into a band sized for two.
## So the surplus is dropped, a warning names exactly which plants are not on the
## title screen, and test_the_title_lawn_shows_every_plant_in_the_catalogue fails
## with the fix in its message: add an x to PLANT_X inside one of the two clear
## bands documented there, or move the lawn to two rows.
## Built with a loop rather than `ids.slice(...)`: Array.slice hands back an
## untyped Array, and returning one of those as Array[StringName] is a runtime
## error on a path that only fires the day somebody adds the fifth plant — which
## is the worst possible day to find out.
static func lawn_plants() -> Array[StringName]:
	var ids: Array[StringName] = PlantCatalog.ids()
	if ids.size() <= PLANT_X.size():
		return ids
	var shown: Array[StringName] = []
	var dropped: Array[StringName] = []
	for i: int in ids.size():
		if i < PLANT_X.size():
			shown.append(ids[i])
		else:
			dropped.append(ids[i])
	push_warning("TitleScreen: %d plants but %d lawn slots — %s is not on the title screen. Add an x to PLANT_X."
		% [ids.size(), PLANT_X.size(), dropped])
	return shown


## The x span a decoration in `slot` covers on screen, as (left, right). The
## sprite is centred on its slot, so this is the number the button column has to
## be checked against — not PLANT_X itself, which is only the stem.
static func plant_span(slot: int) -> Vector2:
	var half: float = PLANT_ART_WIDTH * PLANT_SCALE / 2.0
	return Vector2(PLANT_X[slot] - half, PLANT_X[slot] + half)


## The x span the buttons occupy, as (left, right). Derived from BUTTON_WIDTH and
## the viewport rather than written out, so the "426-726" in PLANT_X's comment
## stays a description of this rather than a second source of truth.
## `viewport_width()`, not `get_viewport_width()`, and the two stopped being the
## same number when the latter went live (plant-tower-defense-nrup). This function
## exists to REPORT where `button_rect()` puts the buttons, and `button_rect()` is
## static and design-width. Reading the live width here would make this a report
## about a column that is not drawn — and since the lawn it is checked against is
## the hand-placed `PLANT_X`, it would silently move the subject of
## `test_the_title_lawn_clears_the_button_column_and_the_horizon` off the thing
## the test is protecting.
func button_column() -> Vector2:
	var centre: float = float(viewport_width()) / 2.0
	return Vector2(centre - BUTTON_WIDTH / 2.0, centre + BUTTON_WIDTH / 2.0)


## Sprite2D, not TextureRect, for every decoration.
##
## These move, and two of them walk off the edge of the screen on purpose. As
## Controls that would be a steady stream of `validate-ui` findings about
## offscreen and out-of-parent Controls — findings that would be correct about
## Controls and meaningless about scenery. A Node2D is simply not what those
## checks look at, which is the honest way to say "this is not UI".
func _build_scenery() -> void:
	for id: StringName in lawn_plants():
		var slot: int = _plants.size()
		var sprite := _make_sprite(PlantCatalog.texture_path(id), PLANT_SCALE)
		sprite.name = "Plant_%d" % slot
		# Which plant is standing where, for a test and for the bridge — a node
		# named by its slot cannot answer "is the Sundew on the lawn".
		sprite.set_meta("plant", id)
		# Origin at the base of the stem, art shifted up above it. `offset` is
		# in texture pixels (applied before `scale`), and putting the node's own
		# origin in the soil is what makes the sway below a lean rather than a
		# slide — a Sprite2D rotates about its position, not about its picture.
		sprite.offset = Vector2(0.0, -sprite.texture.get_height() / 2.0)
		sprite.position = Vector2(PLANT_X[slot], PLANT_BASE_Y)
		add_child(sprite)
		_plants.append(sprite)

	for entry: Dictionary in PESTS:
		var sprite := _make_sprite(String(entry["sprite"]), PEST_SCALE)
		sprite.name = "Pest_%d" % _pests.size()
		sprite.position = Vector2(float(entry["offset"]), PEST_BASE_Y)
		sprite.set_meta("speed", float(entry["speed"]))
		sprite.set_meta("offset", float(entry["offset"]))
		add_child(sprite)
		_pests.append(sprite)


func _make_sprite(path: String, scale_factor: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(path) as Texture2D
	sprite.scale = Vector2(scale_factor, scale_factor)
	# The sprites are 64px art enlarged past 1:1 here; the default bilinear
	# filter turns their outlines to mush at this size.
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite


func _process(delta: float) -> void:
	if not GardenTheme.animations_enabled():
		return
	_elapsed += delta
	for i: int in _plants.size():
		# Each plant is given its own phase, or the whole lawn sways as one object.
		_plants[i].rotation = sin(_elapsed * SWAY_RATE + float(i) * 1.7) * SWAY_RADIANS
	_march_pests()


func _march_pests() -> void:
	var span: float = float(get_viewport_width()) + PEST_MARGIN * 2.0
	for pest: Sprite2D in _pests:
		var speed: float = float(pest.get_meta("speed"))
		var start: float = float(pest.get_meta("offset"))
		pest.position.x = fmod(start + _elapsed * speed, span) - PEST_MARGIN
		# A 2px bob at ~2Hz. Enough that the eye reads "walking" rather than
		# "sliding", without turning into a hop.
		pest.position.y = PEST_BASE_Y + sin(_elapsed * 6.0 + start) * 2.0


## Fade the wordmark up and deal the buttons in from below.
##
## Every property this touches is already at its final value before the tween
## exists — `from()` sets the start, so a skipped or interrupted entrance leaves
## a correct screen rather than an invisible one. Headless skips it outright:
## nothing pumps the frames the tween needs, so there it would be a permanent
## `modulate.a = 0` on three buttons and a title.
func _play_entrance() -> void:
	if not GardenTheme.animations_enabled():
		return
	var tween := create_tween()
	tween.set_parallel(true)
	var rows: Array[Control] = [
		get_node("TitleLabel") as Control,
		get_node("SubtitleLabel") as Control,
		get_node("HighScoreLabel") as Control,
	]
	for button: Button in menu_buttons():
		rows.append(button)
	rows.append(get_node("HintLabel") as Control)
	for i: int in rows.size():
		var row: Control = rows[i]
		var delay: float = float(i) * ENTRANCE_STAGGER
		tween.tween_property(row, "modulate:a", 1.0, ENTRANCE_SECONDS).from(0.0).set_delay(delay)
		tween.tween_property(row, "position:y", row.position.y, ENTRANCE_SECONDS) \
			.from(row.position.y + ENTRANCE_RISE) \
			.set_delay(delay) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)


## One notebook at a time, and the title's own buttons stop taking focus while
## it is up. The overlay's opaque Backdrop already swallows the mouse, but
## focus is a separate channel: without this, Tab and the arrow keys walk
## straight through the notebook onto buttons the player cannot see.
func _open_notebook() -> void:
	if overlay_open():
		return
	_notebook = NotebookScreen.new()
	_notebook.name = "Notebook"
	_notebook.back_requested.connect(_close_notebook)
	add_child(_notebook)
	_set_menu_active(false)


func _close_notebook() -> void:
	if _notebook != null and is_instance_valid(_notebook):
		_notebook.queue_free()
	_notebook = null
	_set_menu_active(true)
	_notebook_button.grab_focus()


## The keys screen, same overlay contract as the notebook: one at a time, the menu
## behind it goes inert, and it is closed by its own signal rather than by knowing
## who opened it.
##
## Built through KeyBindingScreen.build() rather than here, because the pause card
## is its second door now and the two must not drift into two versions of the same
## overlay. The connection stays direct: nothing on this screen answers Escape, so
## there is no keystroke for a mid-event close to fall through to. The pause card
## defers its own for exactly that reason -- see PauseScreen._open_keys.
func _open_keys() -> void:
	if overlay_open():
		return
	_keys_screen = KeyBindingScreen.build()
	_keys_screen.back_requested.connect(_close_keys)
	add_child(_keys_screen)
	_set_menu_active(false)


func _close_keys() -> void:
	if _keys_screen != null and is_instance_valid(_keys_screen):
		_keys_screen.queue_free()
	_keys_screen = null
	_set_menu_active(true)
	_keys_button.grab_focus()


## The options screen, same overlay contract again — see _open_keys. A third
## overlay is exactly why `overlay_open()` is one shared guard: three independent
## "is mine open" checks would let any of them open on top of any other.
##
## Built through OptionsScreen.build() rather than here, for the reason the keys
## screen already is: the pause card is its second door now, and two call sites
## constructing the same overlay by hand is how one of them ends up without
## PROCESS_MODE_ALWAYS. The connection stays direct — nothing on this screen
## answers Escape, so there is no keystroke for a mid-event close to fall through
## to. The pause card defers its own for exactly that reason.
func _open_options() -> void:
	if overlay_open():
		return
	_options_screen = OptionsScreen.build()
	_options_screen.back_requested.connect(_close_options)
	add_child(_options_screen)
	_set_menu_active(false)


func _close_options() -> void:
	if _options_screen != null and is_instance_valid(_options_screen):
		_options_screen.queue_free()
	_options_screen = null
	_set_menu_active(true)
	_options_button.grab_focus()


## True while any overlay covers the menu. One shared guard rather than three:
## the notebook, the keys screen and the options screen all go inert-behind-me,
## and independent "is mine open" checks would happily stack one on another.
func overlay_open() -> bool:
	if _notebook != null and is_instance_valid(_notebook):
		return true
	if _keys_screen != null and is_instance_valid(_keys_screen):
		return true
	return _options_screen != null and is_instance_valid(_options_screen)


func _set_menu_active(active: bool) -> void:
	var mode: Control.FocusMode = Control.FOCUS_ALL if active else Control.FOCUS_NONE
	# Mouse filter as well as focus. The notebook's Backdrop swallows clicks, so
	# the buttons cannot be *pressed* through it — but the Backdrop is 0.88
	# alpha, so a button still tracking the mouse underneath lights up in its
	# hover colour and that glow shows through the paper. An ignored Control
	# never receives the enter event at all.
	var filter: Control.MouseFilter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	for button: Button in menu_buttons():
		button.focus_mode = mode
		button.mouse_filter = filter


## The canvas this screen has to COVER. Live, and it has exactly two callers:
## `_apply_viewport_layout()` (this Control's own rect and the Backdrop's) and
## `_march_pests()` (scenery that walks off both edges, so it wants the real
## edges). Everything else on this screen is a fixed composition and asks
## `viewport_width()` below instead — see that function.
func get_viewport_width() -> int:
	return ScreenMetrics.live_width(self)


func get_viewport_height() -> int:
	return ScreenMetrics.live_height(self)


## The canvas this screen was COMPOSED on, and the number every layout constant
## here was authored against.
##
## Static, because button_rect() and menu_capacity() are: the menu's shape has to
## be answerable before any instance exists, which is what lets a test ask "would
## a seventh destination fit" without building the screen to find out.
##
## **This one deliberately did NOT go live** (plant-tower-defense-nrup), and the
## proof is `PLANT_X`. The lawn slots are hand-placed constants in design
## coordinates, and `test_the_title_lawn_clears_the_button_column_and_the_horizon` compares
## `plant_span(slot)` — a pure function of `PLANT_X` — against `button_column()`.
## Move the button column onto the live width and its centre goes from 576 to 768
## on a 21:9 window while the lawn stays put: the buttons drive straight through
## the plants, and the invariant a test exists to hold is broken by the fix that
## was supposed to be an improvement. `menu_capacity()` has the same problem for
## the same reason — measured against a live height it reports a bigger menu on
## every window that is not 16:9, and a ceiling that relaxes is not a ceiling.
##
## A fixed composition wants CENTRING, not re-derivation. That is the follow-up
## named in the report on plant-tower-defense-nrup; it is one translation applied
## to the whole screen, not a live number per constant.
static func viewport_width() -> int:
	return ScreenMetrics.design_width()


static func viewport_height() -> int:
	return ScreenMetrics.design_height()


func _start_campaign() -> void:
	RunConfig.endless = false
	get_tree().change_scene_to_file(GAME_SCENE)


func _start_endless() -> void:
	RunConfig.endless = true
	get_tree().change_scene_to_file(GAME_SCENE)


## Harness entry_hook target — see devtools_config.json. Lands in the same
## place Start does, without needing a pressed signal on a live button.
func skip_to_game() -> void:
	_start_campaign()
