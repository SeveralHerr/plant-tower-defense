class_name NotebookScreen
extends OverlayScreen

## "A screen showing the original hand-drawn image1.jpg-image6.jpg beside the
## finished sprite for each plant." The drawings are the source material the
## whole game was built from; PAGES below is the mapping of which drawing shows
## which plant, plus what that page actually decided.
##
## The first version of this screen was a slideshow: two bare 320x320 textures
## side by side on flat INK, one green caption, three default-theme buttons. It
## answered "which drawing" and nothing else — not which pane was which, not
## what the drawing settled, not how far through you were. So the content here
## is now the point and the layout serves it: a paper spread (NotebookPage), a
## labelled pane on each side, and a real note per page.
##
## The Backdrop, the Back button and `back_requested` are OverlayScreen's — the
## chrome this screen shares with the Keys and Options screens. Two things here
## are NOT shared and are the reason this screen overrides rather than inherits
## them: the paper is a ruled two-page spread (NotebookPage) and not a Panel, and
## the screen opens with its pager focused rather than its Back button, because
## the first thing a reader wants is the next page. There are no rows, so the
## footer-gap rule OverlayScreen states for the other two does not apply here.
##
## Node paths are a contract. `Backdrop`, `Drawing`, `Sprite` and `PageLabel`
## are asserted by test_selftest.gd and reachable from the devtools bridge, so
## they stay direct children of this node even though the paper panel is drawn
## behind them. Nothing here is in a Container; see TitleScreen for why that is
## deliberate on a fixed-size fullscreen menu.

## What this screen's node is called once it is in the tree, matching
## `KeyBindingScreen.NODE_NAME` and `OptionsScreen.NODE_NAME`. The third overlay
## went without one, so the only way to ask "is the notebook up" was to read
## `PauseScreen._notebook` -- a private field, and a different question from the
## one the other two answer. A sweep over "every overlay" had to special-case this
## one, which is the opposite of what a shared base class is for.
##
## "Notebook", NOT "NotebookScreen": this is the name both construction sites
## already assign (PauseScreen._open_notebook, TitleScreen._open_notebook) and the
## name six checks in test_selftest.gd already reach for. The constant is being
## given to a name that exists, not a rename — a rename here would move the node
## out from under every one of them.
const NODE_NAME := "Notebook"

## Panel rect, in viewport coordinates. Everything else is placed against it.
const PANEL := Rect2(76.0, 32.0, 1000.0, 584.0)
const PAGE_SPLIT: float = 576.0

## Centre of each page's *writing* area — the paper right of its red margin
## rule, which NotebookPage draws at MARGIN_X into each half. Centring content
## on the raw page instead put the drawing's frame straight over the left margin
## line and started the note text on the wrong side of the right one.
const LEFT_CENTRE: float = 358.0
const RIGHT_CENTRE: float = 858.0
## Width of a centred run of text on either page. Both writing areas are 436
## wide; this leaves a little air at each edge.
const TEXT_WIDTH: float = 420.0

const DRAWING_FRAME := Rect2(LEFT_CENTRE - 188.0, 140.0, 376.0, 316.0)
const DRAWING_BOX := Rect2(LEFT_CENTRE - 180.0, 148.0, 360.0, 300.0)
const SPRITE_BOX := Rect2(RIGHT_CENTRE - 100.0, 138.0, 200.0, 190.0)
## The index card a KIND_PLANT page shows where the photograph would be. Inset
## inside DRAWING_BOX, so it is mounted on the same matte the drawings are: the
## frame stays on every page and only its contents change, which is what keeps
## the two kinds of page reading as one notebook rather than two screens.
## (DRAWING_BOX inset by 16 on every side, written out: a const expression that
## reads .position off another const is not something to find out about at parse
## time.)
const SPEC_BOX := Rect2(LEFT_CENTRE - 164.0, 164.0, 328.0, 268.0)

## 112, not the 122 this started at: at 122 the pane label's box ran 5px into
## the top of DRAWING_FRAME. Caught by the HUD occlusion audit, which is the
## only check that looks at a *pair* of Controls — `findings` reported 0 over
## the same frame, correctly, because each of the two fits its own box.
const PANE_LABEL_Y: float = 112.0
const SOURCE_Y: float = 462.0
const PLANT_HEADING_Y: float = 336.0

## How wide the centred subheading's TEXT may draw, which is not how wide its box
## is. The box is the full panel (382px) and its bottom edge overlaps PANE_LABEL_Y
## by 5px — see the comment on PANE_LABEL_Y for why that const came down to 112 —
## so the pane labels are clear of it only while the text stays narrow enough to
## not reach them. 358 is the panel width less twice the 12px the long form of
## the sentence overhung by. Widening the subheading is a real layout change, not
## a copy edit: it collides before it clips.
const SUBHEAD_MAX_WIDTH: float = 358.0

## Six wrapped lines at font 14. The first pass gave this 108px, and the longest
## note lost its final clause to an ellipsis on a page that had 90px of unused
## paper below it — see test_notebook_every_page_carries_a_caption_and_a_note
## for the character budget this height buys.
const NOTE_RECT := Rect2(RIGHT_CENTRE - 200.0, 372.0, 400.0, 142.0)
const FOOTER_Y: float = 544.0
const PAGER_WIDTH: float = 110.0

## Where the Back button sits on this screen, which is beside the heading rather
## than in a footer — there is no footer here but the pager, and a Back button in
## the middle of it would sit between Prev and Next.
const BACK_AT := Vector2(100.0, 52.0)
## Narrower than OverlayScreen.BACK_BUTTON_SIZE, because it is up in the header
## beside a 30pt heading rather than in a row of 150px footer buttons. Still 40
## tall: `findings` gates an interactive Control at 40x40 and is right to — a 38px
## button is a 38px touch target.
const BACK_SIZE := Vector2(108.0, 40.0)

## Largest whole-number enlargement a sprite is drawn at inside SPRITE_BOX.
##
## Filling the box was the obvious thing and it was wrong: the sprites are not
## all one size. Every plant is 128x128 at 2x, but `corn_kernel@2x` is 32x32,
## and stretching that to a 190px box turned the kernel page into a yellow
## smear. A whole-number factor keeps the pixel grid intact.
##
## The cap is 2 rather than the 4 that would make every page draw at the same
## 128px, because 4x magnifies the kernel's own antialiasing into visible mush —
## and because the kernel *is* smaller than the cob that fires it. Letting the
## two pages differ in size states that instead of hiding it.
const MAX_SPRITE_ZOOM: float = 2.0

## Fade-and-nudge when the page changes. Short: this is a page turn, not a
## transition, and anything slower makes Next feel unresponsive when held.
const TURN_SECONDS: float = 0.18
const TURN_NUDGE: float = 22.0
const TURN_START_ALPHA: float = 0.15

## Two kinds of page, both in one table because the pager counts PAGES.size().
##
## KIND_DRAWING is the original five: a photograph of the paper on the left, the
## sprite it turned into on the right. There are five and not six because
## `image1.jpg` and `image6.jpg` are the same photograph — byte for byte, same
## SHA — and the table this replaced listed both, so the notebook showed one
## picture twice under two captions that described different things ("first
## sketch" and "the kernel volley", neither of which is what the photo shows).
## Nothing caught it: both paths exist, both load, and the paths themselves
## differ, so a duplicate check on the strings would have passed too. See
## test_no_two_notebook_pages_show_the_same_drawing, which compares the bytes.
##
## KIND_PLANT is the answer to the two plants that have no drawing at all. The
## Seed Sunflower and the Sticky Sundew were designed in this repository, not on
## paper, and inventing a pencil sketch for them would make the whole notebook a
## story rather than a record. So those pages answer the other question: a
## drawing page says *where this came from*, a plant page says *what this does*.
## The left half stops being a photograph and becomes an index card built out of
## PlantCatalog — see plant_spec(). That costs the spread its symmetry, which is
## the honest thing for it to cost: half of one is missing because half of one
## does not exist.
##
## `plant` names the catalogue id a page is about, or &"" for a page about a
## decision rather than a plant. It is what page_for_plant() and
## test_the_notebook_has_a_page_for_every_plant_in_the_catalogue read; a plant
## with no page is a plant the only explanatory screen in the game never mentions.
##
## `drawing` on a plant page names the artefact the page is about — the sprite
## file, authored here — rather than a photograph, so the byte comparison above
## keeps meaning "no two pages are about the same thing". SourceLabel prints it
## either way, saying outright that this one was never on paper.
##
## KIND_SHELF is the third, and it is about the player rather than about the game.
## A milestone was announced exactly once — RunSummary.new_milestones() reads only
## the ids a run was the FIRST to earn, so the post-mortem's ribbon is the only
## surface that ever drew one, and a milestone earned three runs ago sat in
## RunConfig.earned_milestones with `has_milestone()` public and called by nothing.
## The shelf is where the whole set lives. It goes in the notebook rather than on
## the title screen because the title's button column is already full to the inch
## (see TitleScreen.BUTTON_TOP: a fifth row foots below TitleBackdrop.HORIZON) and
## because the pager here is exactly the structure a fixed-length list wanted.
##
## Unearned rows are drawn too, greyed and with their note prefixed. A shelf that
## showed only what you have tells a new player nothing at all — the unearned rows
## are the half that says what there is to go and try.
const KIND_DRAWING := "drawing"
const KIND_PLANT := "plant"
const KIND_SHELF := "shelf"

## KIND_LEGEND is the fourth, and it exists because `game/OVERLAY_GRAMMAR.md` documented
## ten drawn shapes and what each MEANS, is referenced only from GDScript comments, and is
## therefore a language the game speaks and teaches to nobody. See `CueLegend`.
##
## It goes here rather than on a screen of its own for the reason KIND_SHELF already
## established at line 142: this notebook stopped being purely a design-history artefact
## when the shelf arrived, because the shelf is "about the player rather than about the
## game". A cycle-88 note in `kanban.md` claimed the opposite and called this surface the
## wrong shape for a legend; confirming that claim before building is what found the
## precedent one screen away, and the note was corrected rather than worked around.
const KIND_LEGEND := "legend"

## AND HERE IS THE COUNTER-CASE, because the paragraph above reads as an argument for
## adding a page whenever the game has a rule, and it is not (plant-tower-defense-djvk).
##
## Cycle 127's notebook audit measured that this file never once says "drought", and filed
## a P2 to give weather a page: the player meets it from wave 4
## (`game/wave_director.gd:754`) and drought halves every plant's rate of fire. The
## measurement was right and the conclusion was wrong. Weather is taught in THREE places,
## each at the moment it can be acted on:
##
##   - the prep note, BEFORE the seeds are spent — "drought · pests pay 150%"
##     (`game/hud.gd:3304-3310`)
##   - the full-screen `WeatherOverlay`, which draws for the whole wave and is the
##     standing state a player can look back at
##
## TWO OF THE THREE SURFACES THIS LIST ORIGINALLY NAMED DID NOT EXIST
## (plant-tower-defense-zhqf), and the list is corrected above rather than quietly
## trimmed, because the correction is the interesting part. It claimed "a banner as the
## wave opens" and "a status row carrying the state after the banner is gone
## (`weather_note`)". The banner was written by `Hud.show_weather` and overwritten by
## `Hud.announce_wave` ten lines later in the same call stack, so no player has ever
## seen it; it now loses by rule instead. The status row was proposed as `-saaw` and
## measured and REFUSED — every candidate tag overflowed the wave slot — and four
## comments across three files went on citing it as shipped.
##
## The test the legend passed is the one weather fails: a language the game SPEAKS and
## TEACHES TO NOBODY. Weather is still spoken and taught, and the conclusion survives —
## but it now rests on the prep note and the overlay, which is one fewer surface than
## the argument was written against. If a fourth thing ever wants weather's teaching
## reduced, this is the paragraph to re-read first.
##
## THE ERROR IS WORTH MORE THAN THE ANSWER, and it is why this is written here rather
## than left in a closed bead. The audit enumerated over `notebook_screen.gd` and drew a
## conclusion about THE GAME. `-pa4g`, the very bead that commissioned the audit, warned
## in its own text: "two of my last four absence claims about this codebase were wrong,
## both because the enumeration was over the wrong set." One bead later, same mistake.
## Before adding a page for a rule, grep the HUD for the rule's own words first.

## KIND_HINTS is the fifth (plant-tower-defense-ei83), and it is the only page whose
## content the player has already been shown and cannot get back.
##
## Every id in `RunConfig.HINTS` is displayed exactly once per save and then spent —
## `RunConfig.spend_hint` makes that permanent on purpose, because a tip that reposts
## every time becomes wallpaper. The cost is that a player looking at the board when
## the row posted has no route back to it, and the three hints teach three things the
## game says nowhere else: that an armed Uproot previews reach elsewhere, that a Chomp
## declines a flier by design rather than by fault, and that upgrading a plant already
## down is a stronger move than adding another.
##
## It is NOT the shelf with a second section. Hints are deliberately outside
## `Milestones.TABLE` (`game/run_config.gd:166-222`) — an achievement is EARNED and a
## hint is SPENT, and the shelf counts earned off TABLE so a foreign id there would
## either be invisible or push the count past its own rows. `shelf_capacity()` is 7
## against a 7-row table, so there is no room either. A separate page is the shape the
## split already implies.
##
## The sentences come from `Hud.HINT_CARDS` and are read through `Hud.hint_title` /
## `Hud.hint_note_text` rather than restated here, so the page and the message row can
## never teach the same rule two different ways: that failure is worse than either
## surface alone, so they share one table.
const KIND_HINTS := "hints"


## What the left pane's own label says on each kind of page.
##
## A table rather than the `if drawn / elif spec / else` chain `go_to` used to carry, and
## the reason is mechanical: with three kinds that `else` MEANT the shelf, so adding a
## fourth kind would have silently given the legend the shelf's heading and the shelf
## nothing wrong at all — the failure would have shown up on a page nobody was editing.
## Adding a kind now means adding a row, and a kind with no row is a visible empty string
## rather than a wrong one borrowed from its neighbour.
const PANE_LABELS: Dictionary = {
	KIND_DRAWING: "The drawing",
	KIND_PLANT: "No drawing — the spec",
	KIND_SHELF: "Every first the garden records",
	KIND_LEGEND: "What the marks on the board mean",
	KIND_HINTS: "Tips the garden only gives once",
}


## The left pane's heading for `kind`, or "" for a kind nobody has given one.
static func pane_label_for(kind: String) -> String:
	return String(PANE_LABELS.get(kind, ""))


## How many shapes `game/OVERLAY_GRAMMAR.md` documents. Named here because the legend
## page's provenance line prints it to the player, and a hard-typed count inside a format
## string is a number nobody would ever re-check.
##
## This comment used to quote the rendered line as "5 of the board's 10". Both numbers had
## drifted — six taught, eleven documented — because the test below guards the CONSTANT and
## nothing guards prose that quotes it. Hence no example here: a comment that restates a
## number it does not own is a second copy, and the second copy is always the one that rots.
##
## `test_the_legend_names_as_many_shapes_as_the_grammar_documents` parses the document's
## table and fails when it grows — which is the only way this stays true, since a new
## grammar row is added by someone editing markdown who will never open this file.
const OVERLAY_GRAMMAR_SHAPES: int = 12
const OVERLAY_GRAMMAR_PATH := "res://game/OVERLAY_GRAMMAR.md"


## Which page this notebook opens on. Set before `add_child`, since the build reads it.
##
## Default 0, which is what the title screen wants: someone browsing the designer's
## notebook came for the pencil drawings, and `PAGES[0]` is the portrait the whole game
## started from. The PAUSE screen sets it to the legend instead, and that difference is
## the whole feature — the two doors are asked different questions.
##
## A player who has stopped a run in progress and opened the notebook is looking at a board
## and wondering what something on it means. A player on the title screen is not looking at
## a board at all. Nine presses of Next is a fine price for browsing and a bad one for
## being confused, so the context pays it rather than the player.
var open_at: int = 0


## The index of the first page of `kind`, or **-1** when there is none.
##
## A named lookup so no caller hardcodes 9. `PAGES` is reordered by whoever adds a page and
## a pause screen holding a literal would silently open on whatever moved into that slot.
##
## Generalised out of `shelf_page()`, which was this function for one kind — written first
## and for the same reason, "so appending a page above it cannot silently point a test at a
## drawing". Adding a second copy for KIND_LEGEND was the obvious move and the wrong one;
## `shelf_page()` now delegates.
##
## Returns -1 rather than 0 because that is the honest answer and the two callers want
## opposite things from it: a test asserting the shelf exists needs to be able to fail,
## while the pause screen would rather open the front of the book than nothing. The clamp
## belongs at the caller that wants it, not in a finder that would then be unable to say no.
static func page_for_kind(kind: String) -> int:
	for i: int in PAGES.size():
		if String(PAGES[i].get("kind", KIND_DRAWING)) == kind:
			return i
	return -1

## The shelf's rows, laid out inside DRAWING_BOX — the same matte a photograph is
## mounted on, for the reason SPEC_BOX gives: the frame stays on every page and
## only its contents change.
##
## Milestones.TABLE.size() rows at this pitch is 7 * 42 + 3 = 297 against
## DRAWING_BOX's 300, so the table has NO room for an eighth entry at these
## numbers. That is deliberate rather than an oversight waiting to happen:
## test_the_milestone_shelf_fits_the_page fails the moment TABLE grows, and names
## the two ways out (drop the pitch, or split the shelf across both pages).
const SHELF_ROW_PITCH: float = 42.0
const SHELF_ROW_TOP: float = 3.0


## How many shelf rows fit inside DRAWING_BOX.
##
## Computed rather than stated. The header above says "7 * 42 + 3 = 297 against 300" and
## is correct; this is that sum as a number, so an eighth milestone moves it rather than
## asking whoever adds one to redo the arithmetic from a comment.
##
## `item_height` is the pitch here, because a shelf row occupies its whole slot -- unlike
## an options row, where a 40 px button sits in a 48 px pitch and the difference is what
## keeps the last one clear of the footer.
static func shelf_capacity() -> int:
	return OverlayScreen.rows_that_fit(SHELF_ROW_TOP, SHELF_ROW_PITCH, SHELF_ROW_PITCH,
		DRAWING_BOX.size.y)
## The earned/unearned mark, and it is a SIZE difference rather than only a colour
## one. Same rule Plant.HEALTH_BAR_SEGMENTS states for the board: a cue that is
## carried by hue alone is a cue the colourblind-safe option exists because of.
## The greying is the second channel and the "Not yet — " prefix on the note is a
## third, so the shelf reads with the colour thrown away entirely.
const SHELF_PIP_EARNED: float = 10.0
const SHELF_PIP_UNEARNED: float = 4.0
const SHELF_PIP_X: float = 4.0
const SHELF_TEXT_X: float = 22.0
const SHELF_TITLE_HEIGHT: float = 20.0
const SHELF_NOTE_HEIGHT: float = 17.0
const SHELF_TITLE_FONT_SIZE: int = 15
const SHELF_NOTE_FONT_SIZE: int = 11

## The hints page reuses the shelf's pip column, text inset and title band, and does
## NOT reuse its pitch. That is the one place the two lists genuinely differ and it is
## worth the two extra constants: a milestone note is a half-line label ("Cleared it
## without an escape") and a hint note is an instruction that has to be followable
## without the board in front of you, so it is two to three wrapped lines. Dropped into
## the shelf's 17px single-line clip, the longest of the three lost everything after
## "hover another bed to see what the plant" — an ellipsis in the middle of the only
## sentence teaching the mechanic, on the page whose entire job is teaching it.
##
## Three rows at 98 is 3 + 2*98 + 94 = 293 against DRAWING_BOX's 300, so a FOURTH hint
## does not fit — the same deliberate tightness `shelf_capacity()` has, and
## `hints_capacity()` below is the number a test asserts against `Hud.hint_ids().size()`
## so hint four fails the suite rather than silently dropping off the matte.
##
## The note height is four wrapped lines at 12 and the longest card today wraps to
## three. The spare line is not slack: the unshown form of a card is the shown form
## plus "Not shown yet — ", so every note on this page is ~16 characters longer than
## the sentence anyone wrote, and the state a reader most needs to read is the state
## that overflows first.
const HINT_ROW_PITCH: float = 98.0
const HINT_NOTE_HEIGHT: float = 74.0
const HINT_NOTE_FONT_SIZE: int = 12


## How many hint rows fit inside DRAWING_BOX. Computed, for the reason
## `shelf_capacity()` is: the arithmetic in the comment above moves when a constant does.
static func hints_capacity() -> int:
	return OverlayScreen.rows_that_fit(SHELF_ROW_TOP, HINT_ROW_PITCH,
		SHELF_TITLE_HEIGHT + HINT_NOTE_HEIGHT, DRAWING_BOX.size.y)


## How many hint PAGES the current hint list needs.
##
## The fourth hint (plant-tower-defense-lven) hit the ceiling the block above predicted:
## "a FOURTH hint does not fit". It was right, and the two ways out it named were "drop the
## pitch or split the page". The pitch cannot drop — four rows need a pitch of 67 against a
## row that is 94 tall, and shrinking the note to reach it clips the UNSHOWN form, which the
## same block calls "the state a reader most needs to read". So: split.
##
## The page is still FINITE and still fails loudly. A third hint page needs a second
## KIND_HINTS entry in PAGES with its own byte-distinct drawing, and
## test_the_hints_page_has_room_for_every_hint_the_game_can_spend now asserts this against
## the number of those entries rather than against a single page's row count — so hint seven
## fails the suite exactly as hint four did, instead of drawing off the matte.
static func hint_pages_needed() -> int:
	var per: int = hints_capacity()
	if per <= 0:
		return 0
	return int(ceil(float(Hud.hint_ids().size()) / float(per)))


## Which page of the BOOK carries hint page `index`, or -1.
##
## Separate from `page_for_kind`, which answers "where is the first hints page" and is what
## the pause door and the pager use. This answers "where is hint page 2", which only a
## caller walking every hints page needs — and the two hints pages are not required to be
## adjacent in the book, so it is a scan rather than an offset from the first.
static func page_for_hint_page(index: int) -> int:
	for i: int in PAGES.size():
		var entry: Dictionary = PAGES[i]
		if String(entry.get("kind", "")) == KIND_HINTS \
				and int(entry.get("hint_page", 0)) == index:
			return i
	return -1


## The hint ids that belong on hint page `index` (0-based), in list order.
##
## Pure and static so the slicing is assertable without building a Control — the same
## reason `Bramble.texture_for_health` takes a fraction rather than a plant.
static func hints_on_page(index: int) -> Array[String]:
	var per: int = hints_capacity()
	var out: Array[String] = []
	if per <= 0 or index < 0:
		return out
	var ids: Array[String] = Hud.hint_ids()
	for i: int in range(index * per, mini((index + 1) * per, ids.size())):
		out.append(ids[i])
	return out


const PAGES: Array[Dictionary] = [
	{
		"plant": &"corn_cobbler",
		"drawing": "res://image1.jpg",
		"sprite": "res://assets/sprites/corn_cobbler.png",
		"caption": "Corn Cobbler",
		"note": "The portrait the whole game starts from: the name spelled out at the top and the cob drawn underneath with a proper face. Everything in the sprite comes from here — the grid of kernels, two dot eyes, leaves splayed at the base, and a plant that grows out of the ground rather than standing on it.",
	},
	{
		"plant": &"",
		"drawing": "res://image2.jpg",
		"sprite": "res://assets/sprites/seed_packet.png",
		"caption": "The brief",
		"note": "\"I want it to be a tower defence game. Plants fight bugs. You get one free plant to start, some aren't free. You have to buy plant seeds to get plants.\" Four sentences, and every one of them is a rule the game still runs on.",
	},
	{
		"plant": &"",
		"drawing": "res://image3.jpg",
		"sprite": "res://assets/sprites/corn_kernel.png",
		"caption": "The bunch-of-corn upgrade",
		# "one rung of the three", not "the whole upgrade path" (plant-tower-defense-hvdj).
		# The drawing really does show a single arrow, and every other clause on this page
		# is about the paper — so the page keeps describing the artefact. But
		# CornCobbler.LEVELS has three rungs (single, triple, bunch) and this was the one
		# clause making a claim about the GAME, which is the clause that went stale.
		#
		# Scoped rather than expanded: CornCobbler now draws the ladder on the board, one
		# pip per kernel, so a player counts the rungs without opening the notebook. There
		# is nothing here for a documented ladder to add. Note bodies are budgeted at 300
		# characters (test_notebook_every_page_carries_a_caption_and_a_note); this is 263.
		"note": "An arrow from one cob to another, \"bunch of corn\" written at the top, and a scatter of D-shapes flying off to the right. That is one rung of the three the upgrade path ended up with — one kernel becomes several at once — and the D-shapes became the kernel sprite.",
	},
	{
		"plant": &"chomp_flower",
		"drawing": "res://image4.jpg",
		"sprite": "res://assets/sprites/chomp_flower.png",
		"caption": "Chomp Flower",
		"note": "Named in the corner, drawn with a jaw full of triangular teeth, and specced in two bullet points: \"eats small pests easily\", \"takes a while eating bigger pests\". The only plant that arrived with its own balance rules already written down.",
	},
	{
		"plant": &"",
		"drawing": "res://image5.jpg",
		"sprite": "res://assets/sprites/chomp_flower_eating.png",
		"caption": "Eating takes time",
		"note": "Three poses on one page: mouth open, a pest labelled with an arrow, then the flower shut with its eyes X-ed out mid-chew. Chewing is not instant — that is what leaves a lane briefly open — so the mid-bite pose is a separate sprite, not a tint.",
	},
	{
		"kind": KIND_PLANT,
		"plant": &"sunflower",
		"drawing": "res://assets/sprites/sunflower.png",
		"sprite": "res://assets/sprites/sunflower.png",
		"caption": "Seed Sunflower",
		"note": "No pencil page for this one. The Seed Sunflower was designed here, in the repo, for a run with a full board and nothing left to spend seeds on: it fires nothing and grabs nothing, it grows more seeds on a clock, so a corner the lane never touches finally has a job.",
	},
	{
		"kind": KIND_PLANT,
		"plant": &"sticky_sundew",
		"drawing": "res://assets/sprites/sticky_sundew.png",
		"sprite": "res://assets/sprites/sticky_sundew.png",
		"caption": "Sticky Sundew",
		"note": "Also designed here rather than on paper. A Chomp Flower is forbidden from closing on a winged pest, so a lane walled with mouths did nothing at all to a flier. The dew is on the ground underneath, so it catches what flies over it — and gives every gun longer to shoot.",
	},
	{
		"kind": KIND_PLANT,
		"plant": &"dandelion",
		"drawing": "res://assets/sprites/dandelion.png",
		"sprite": "res://assets/sprites/dandelion.png",
		"caption": "Bomb Dandelion",
		"note": "The only plant that hits more than one bug at once. Its seeds arc and burst where they land, so pests walking together take the whole blast — but a seed is aimed where they were half a second ago, and wants something slowing them first. Three seeds a head, and it goes visibly bald throwing them.",
	},
	{
		"kind": KIND_PLANT,
		"plant": &"mint",
		"drawing": "res://assets/sprites/mint.png",
		"sprite": "res://assets/sprites/mint.png",
		"caption": "Garden Mint",
		"note": "The third plant designed here rather than on paper, and the first that is about the BOARD instead of the lane. Every other plant answers what happens to the pest in front of it; Mint answers what the plants beside it are worth. It is the only reason a cell's neighbours have ever mattered.",
	},
	{
		"kind": KIND_PLANT,
		"plant": &"nettle",
		"drawing": "res://assets/sprites/nettle.png",
		"sprite": "res://assets/sprites/nettle.png",
		"caption": "Prickly Nettle",
		"note": "The fourth designed here, and the first plant that refuses a target. It stings only mutated pests — armoured, winged, hungry — and does nothing at all before wave 8, which its shop line says outright. A specialist you are told to buy late is a decision; one you are not is a trap.",
	},
	{
		"kind": KIND_PLANT,
		"plant": &"aloe",
		"drawing": "res://assets/sprites/aloe.png",
		"sprite": "res://assets/sprites/aloe.png",
		"caption": "Salve Aloe",
		"note": "The fifth designed here, and the first thing that undoes damage. Before it, health only ever fell — the rain heals, but that is the weather's doing. Too slow to save a plant being eaten, on purpose: a heal that beat a mouth would make one Aloe behind everything the only board.",
	},
	{
		"kind": KIND_PLANT,
		"plant": &"bramble",
		"drawing": "res://assets/sprites/bramble.png",
		"sprite": "res://assets/sprites/bramble.png",
		"caption": "Barrier Bramble",
		"note": "The sixth designed here, and the only plant that stands in the road. Everything before it acted on a pest walking past — and the pest walked past regardless. This one sells time: nothing gets by until it is chewed through, and the cobs behind it get those seconds. Fliers go over.",
	},
	{
		"kind": KIND_SHELF,
		"plant": &"",
		# Kept a real path even though the shelf page never shows it: Drawing is
		# loaded on every page (see go_to) so no layout check has to special-case
		# a TextureRect holding null, and the byte-uniqueness check across pages
		# wants something distinct here. The packet is the game's own picture of
		# "something you got", which is what the whole page is about.
		"drawing": "res://assets/sprites/seed_packet.png",
		"sprite": "res://assets/sprites/seed_packet.png",
		"caption": "The shelf",
		"note": "Every first the garden can record, earned or not. A run announces one once on the post-mortem and then it lives here — and the greyed rows say outright what they want, so this is a list of things left to try rather than a list of things missed.",
	},
	{
		"kind": KIND_LEGEND,
		"plant": &"",
		# Distinct from every other page's, because the byte-uniqueness check across
		# PAGES requires it (see the shelf entry above). An aphid rather than a plant:
		# the marks on the board are drawn about the bugs as often as about the beds,
		# and this is the thing the player is reading the board FOR.
		"drawing": "res://assets/sprites/pest_aphid.png",
		"sprite": "res://assets/sprites/pest_aphid.png",
		"caption": "Reading the board",
		# A TEMPLATE, not the finished sentence: the two %s are the row count, filled by
		# legend_note_text() from CueLegend.ROWS.size(). It said "the five here" while the
		# table held six — the uncounted one being ARMED, the cue that guards uproot, so the
		# row a player most needs the legend to be right about. Meanwhile the source line on
		# this very page (see go_to) has always derived its own count correctly, which is
		# what made the hand-written one survive: the page showed a right number and a wrong
		# one at the same time.
		"note": "The garden draws on itself. A shape means the same thing wherever it appears — a full ring is always a reach, a closing arc is always a clock running down — so the %s here are worth more than %s facts. The rest of the marks follow the same grammar once these are familiar.",
	},
	{
		"kind": KIND_HINTS,
		"plant": &"",
		# Distinct bytes from every other page's `drawing`, which the byte-uniqueness
		# check across PAGES requires (see the shelf entry above). A gaping Chomp is the
		# picture of the thing a hint is FOR: a mouth sitting open beside a winged pest
		# looks exactly like a broken plant until somebody says it is a rule.
		"drawing": "res://assets/sprites/chomp_flower_gape.png",
		"sprite": "res://assets/sprites/chomp_flower_gape.png",
		"caption": "Said once",
		"note": "Things the garden says exactly once, the frame each becomes true, and then never again. A player watching the board instead of the message row lost them for good — so they are written out here, greyed and prefixed until the game has really said one.",
		"hint_page": 0,
	},
	{
		"kind": KIND_HINTS,
		"plant": &"",
		# The SECOND hints page (plant-tower-defense-lven). Three rows fit a page and the
		# fourth hint did not; hints_capacity()'s block above records why the pitch could
		# not simply drop.
		#
		# A THIRD page existed from cycle 151 to cycle 179, ordered rather than discovered
		# by that cycle's budget audit. It went when the two hints it carried went -- the
		# deferred-road bar and the sole-cover rings were removed from the game, not from
		# the notebook. The alarm still works in the direction that matters: adding a
		# seventh hint fails three tests at once, naming the count and the missing row.
		#
		# Byte-distinct from every other drawing, which the uniqueness check across PAGES
		# requires. A bramble chewed through to two stubs is the picture for the page that
		# now carries the road rule: the plant whose whole existence contradicts "nothing
		# goes on the road" is the one whose hint pushed this page into two.
		"drawing": "res://assets/sprites/bramble_ragged.png",
		"sprite": "res://assets/sprites/bramble_ragged.png",
		"caption": "Said once, continued",
		"note": "The list outgrew one page at the fourth entry. Same rules as the facing side: each is said the frame it becomes true, once, and is written here greyed until then.",
		"hint_page": 1,
	},
]

var _page: int = 0
var _paper: NotebookPage
var _drawing_rect: TextureRect
var _drawing_pane_label: Label
var _spec: Label
var _shelf: Control
var _hints: Control
var _legend: CueLegend
var _sprite_rect: TextureRect
var _caption: Label
## The page's own note, which is `NoteLabel` and NOT OverlayScreen's `Note` — the
## other two overlays have one line that changes and this one has a paragraph per
## page. Named apart because the node names are apart, and a field called `_note`
## here would shadow the base's.
var _page_note: Label
var _source: Label
var _page_label: Label
var _next_button: Button


## The one overlay whose paper is NOT re-centred on the live canvas, and the
## exception is recorded rather than left to be discovered
## (plant-tower-defense-nrup).
##
## `PANEL.position.x` is 76 for a 1000-wide paper, which is `(1152 - 1000) / 2` —
## the same design-width centring `OptionsScreen.PANEL` and
## `KeyBindingScreen.panel_rect()` carry, and both of those now go through
## `paper_left()`. This one cannot follow them yet, because this screen's content
## is placed in ABSOLUTE viewport coordinates rather than as offsets from the
## paper: `PAGE_SPLIT` (576), `LEFT_CENTRE` (358), `RIGHT_CENTRE` (858) and
## `BACK_AT` are all authored against a paper at x=76. Centring the paper alone
## would slide it out from under every one of them — a worse screen on a wide
## window than an off-centre one.
##
## Converting those constants to paper-relative offsets is the follow-up. Until
## then the Notebook is design-centred, and only the covering layer above it
## (OverlayScreen's root rect and Backdrop) tracks the window.
func panel_rect() -> Rect2:
	return PANEL


## Carries NODE_NAME from the moment it is constructed, whoever constructs it.
##
## The two siblings do this in a static `build()` and their callers go through it.
## This screen has no `build()` — it is `NotebookScreen.new()` at two sites that
## then set `open_at`, `process_mode` and the signal differently — so the name is
## attached here instead, which is strictly stronger: a THIRD construction site
## cannot forget it, and the two that already assign the same string outright are
## left agreeing rather than being the only reason it is true.
##
## `_init` rather than `_ready`: OverlayScreen's header says a subclass `_ready`
## silently replaces the base one and loses the backdrop, so this class does not
## define one at all.
func _init() -> void:
	name = NODE_NAME


## The one overlay whose paper is not a Panel: a ruled two-page spread that draws
## its own margins and the pager dots, which is why this overrides rather than
## takes OverlayScreen's.
func _add_paper() -> void:
	_paper = NotebookPage.new()
	_paper.name = PAPER_NAME
	_paper.position = PANEL.position
	_paper.size = PANEL.size
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_paper)
	_paper.page_count = PAGES.size()


func _build_contents() -> void:
	_build_header()
	_build_left_page()
	_build_right_page()
	_build_footer()
	go_to(open_at)


## Next, not Back. This screen is opened to be read, and the first thing a reader
## reaches for is the next page — the other overlays open on their way out because
## the thing they are for is the row you came to change.
func _focus_default() -> void:
	_next_button.grab_focus()


func _build_header() -> void:
	add_heading("Designer's Notebook", 52.0)

	var subhead := Label.new()
	subhead.name = "Subheading"
	# Counted from PAGES, not written out. The hard-coded "Six pages" outlived
	# the sixth page by about four minutes — and "N pages of pencil" outlived its
	# own accuracy the moment a plant that was never on paper got a page, so the
	# split between the two kinds is counted here too.
	#
	# Keep this SHORT. The subheading's rect is the full panel width and its
	# bottom edge sits 5px below PANE_LABEL_Y, so the only thing holding it off
	# the two pane labels is that the centred text is narrower than the panel.
	# The long form of this sentence filled all 382px and reached 12px into
	# "The drawing" — SUBHEAD_MAX_WIDTH is the budget, and a test measures it.
	var drawn: int = drawing_pages().size()
	subhead.text = "%d pages — %d of pencil, %d never on paper." % [
		PAGES.size(), drawn, PAGES.size() - drawn,
	]
	subhead.position = Vector2(PANEL.position.x, 94.0)
	subhead.size = Vector2(PANEL.size.x, 22.0)
	subhead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subhead.add_theme_font_size_override("font_size", 14)
	subhead.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.6))
	add_child(subhead)

	add_back_button(BACK_AT, BACK_SIZE)


func _build_left_page() -> void:
	# Kept as a field: its text is the one word that tells a reader which kind of
	# page they are on, so go_to() rewrites it rather than it being fixed.
	_drawing_pane_label = _pane_label("DrawingPaneLabel", "The drawing", LEFT_CENTRE)
	add_child(_drawing_pane_label)

	# A matte behind the photo. The drawings are photographs of white paper on
	# cream stock, so without a frame the two whites bleed into each other and
	# the drawing has no edge at all.
	var frame := Panel.new()
	frame.name = "DrawingFrame"
	frame.position = DRAWING_FRAME.position
	frame.size = DRAWING_FRAME.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_box := StyleBoxFlat.new()
	frame_box.bg_color = Color(1.0, 0.996, 0.98)
	frame_box.set_border_width_all(2)
	frame_box.border_color = Color(GardenTheme.INK, 0.55)
	frame_box.shadow_color = Color(0, 0, 0, 0.22)
	frame_box.shadow_size = 8
	frame_box.shadow_offset = Vector2(0, 4)
	frame.add_theme_stylebox_override("panel", frame_box)
	add_child(frame)

	# EXPAND_IGNORE_SIZE, not EXPAND_FIT_WIDTH_PROPORTIONAL: the latter makes
	# the control's own resolved size follow the texture's aspect against
	# whatever it thinks its available width is, which outside a Container
	# blew this up to fill most of the screen rather than respecting the
	# explicit box below (caught by a live screenshot, not any test).
	_drawing_rect = TextureRect.new()
	_drawing_rect.name = "Drawing"
	_drawing_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drawing_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drawing_rect.position = DRAWING_BOX.position
	_drawing_rect.size = DRAWING_BOX.size
	_drawing_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drawing_rect)

	# The other thing the left page can hold. Exactly one of Drawing and SpecLabel
	# is visible at a time — they share the matte on purpose — so the pair is
	# never an occlusion, and the two are swapped in go_to() rather than a page
	# rebuilding half of itself.
	_spec = Label.new()
	_spec.name = "SpecLabel"
	_spec.position = SPEC_BOX.position
	_spec.size = SPEC_BOX.size
	_spec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 15, not the note's 14: this is the left page, where a drawing would be, and
	# a card of four short facts set at body size reads as a caption that lost its
	# picture. It is still small enough that the longest card is ~10 wrapped lines
	# in a box that holds 13 — see test_the_notebook_plant_pages_fit_their_card.
	_spec.add_theme_font_size_override("font_size", 15)
	_spec.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.82))
	# Same budget rule as NoteLabel: the box is what there is, and a card that
	# outgrows it is trimmed rather than allowed to run off the matte.
	_spec.clip_text = true
	_spec.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_spec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spec.visible = false
	add_child(_spec)

	_build_shelf()
	_build_hints()
	_build_legend()

	_source = Label.new()
	_source.name = "SourceLabel"
	_source.position = Vector2(LEFT_CENTRE - TEXT_WIDTH / 2.0, SOURCE_Y)
	_source.size = Vector2(TEXT_WIDTH, 20.0)
	_source.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_source.add_theme_font_size_override("font_size", 13)
	_source.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.45))
	add_child(_source)


## The third thing the left page can hold: one row per entry in Milestones.TABLE,
## in table order, earned or not.
##
## A plain Control and not a VBoxContainer, for the reason the file header gives
## and one more: a Container would own its children's positions, and the pip's
## whole job is to sit at a size the row's own text does not decide. Read once,
## here — the notebook is rebuilt by TitleScreen._open_notebook every time it is
## opened, and nothing can earn a milestone while it is up.
func _build_shelf() -> void:
	_shelf = Control.new()
	_shelf.name = "Shelf"
	_shelf.position = DRAWING_BOX.position
	_shelf.size = DRAWING_BOX.size
	_shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shelf.visible = false
	add_child(_shelf)

	var text_width: float = DRAWING_BOX.size.x - SHELF_TEXT_X - 4.0
	for i: int in Milestones.TABLE.size():
		var id: String = String(Milestones.TABLE[i]["id"])
		var earned: bool = RunConfig.has_milestone(id)
		var y: float = SHELF_ROW_TOP + float(i) * SHELF_ROW_PITCH

		var pip := ColorRect.new()
		pip.name = "ShelfPip_%s" % id
		var side: float = SHELF_PIP_EARNED if earned else SHELF_PIP_UNEARNED
		# Centred in the earned pip's slot, so the two sizes share a centre line
		# and the column reads as one column rather than as ragged left edges.
		var inset: float = (SHELF_PIP_EARNED - side) / 2.0
		pip.position = Vector2(SHELF_PIP_X + inset, y + 5.0 + inset)
		pip.size = Vector2(side, side)
		pip.color = GardenTheme.LEAF_DARK if earned else Color(GardenTheme.INK, 0.35)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shelf.add_child(pip)

		var title := Label.new()
		title.name = "ShelfTitle_%s" % id
		title.text = Milestones.title_of(id)
		title.position = Vector2(SHELF_TEXT_X, y)
		title.size = Vector2(text_width, SHELF_TITLE_HEIGHT)
		title.add_theme_font_size_override("font_size", SHELF_TITLE_FONT_SIZE)
		title.add_theme_color_override("font_color",
			GardenTheme.LEAF_DARK if earned else Color(GardenTheme.INK, 0.38))
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shelf.add_child(title)

		var note := Label.new()
		note.name = "ShelfNote_%s" % id
		note.text = shelf_note_text(id, earned)
		note.position = Vector2(SHELF_TEXT_X, y + SHELF_TITLE_HEIGHT - 1.0)
		note.size = Vector2(text_width, SHELF_NOTE_HEIGHT)
		note.add_theme_font_size_override("font_size", SHELF_NOTE_FONT_SIZE)
		note.add_theme_color_override("font_color",
			Color(GardenTheme.INK, 0.7 if earned else 0.32))
		note.clip_text = true
		note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shelf.add_child(note)



## The fourth thing the left page can hold: one row per id in `RunConfig.HINTS`, in
## that list's order, shown or not (plant-tower-defense-ei83).
##
## Off `Hud.hint_ids()` and NOT off `Hud.HINT_CARDS`: `HINTS` is the set `spend_hint`
## guards, so it is what decides what a hint IS, and a page rendered off the card table
## would happily print a row for an id the persistence layer no longer knows about.
## `hint_title` falls back to the raw id, so a hint with no card shows up here as an
## untitled row rather than silently missing from a list whose whole job is completeness.
##
## Read once, here, for the reason `_build_shelf` gives: the notebook is rebuilt every
## time it is opened, and nothing can spend a hint while it is up.
## Which hint page `_build_hints` is currently drawing. Set by `_show_page` before the
## rebuild, because the rows are positioned from their index ON THE PAGE.
var _hints_page: int = 0


func _build_hints() -> void:
	# Rebuilt rather than built once, since which rows belong here depends on the page.
	# Cheap: the notebook is opened by hand and holds at most hints_capacity() rows.
	if _hints != null and is_instance_valid(_hints):
		# remove_child + free(), NOT queue_free(). queue_free is deferred, so the old pane
		# would still be in the tree when the new one is added -- Godot renames the
		# newcomer to "Hints2" and every `get_node("Hints")` keeps returning the stale
		# page. That is exactly how this presented: page two built correctly and the test
		# read page one's pane, reporting "a hint with no row" for a row that existed.
		remove_child(_hints)
		_hints.free()
	_hints = Control.new()
	_hints.name = "Hints"
	_hints.position = DRAWING_BOX.position
	_hints.size = DRAWING_BOX.size
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints.visible = false
	add_child(_hints)

	var text_width: float = DRAWING_BOX.size.x - SHELF_TEXT_X - 4.0
	# The slice for THIS page, not the whole list (plant-tower-defense-lven). `i` is the row
	# on the page rather than the index in the list, so a hint on page two draws at the top
	# of page two rather than 294 px down an invisible one.
	var ids: Array[String] = hints_on_page(_hints_page)
	for i: int in ids.size():
		var id: String = ids[i]
		# The same read the message row's guard makes. `spend_hint` writes into
		# `earned_milestones`, so "has the player been shown this" is `has_milestone`
		# — there is no second store, which is what lets this page be honest.
		var shown: bool = RunConfig.has_milestone(id)
		var y: float = SHELF_ROW_TOP + float(i) * HINT_ROW_PITCH

		var pip := ColorRect.new()
		pip.name = "HintPip_%s" % id
		var side: float = SHELF_PIP_EARNED if shown else SHELF_PIP_UNEARNED
		var inset: float = (SHELF_PIP_EARNED - side) / 2.0
		pip.position = Vector2(SHELF_PIP_X + inset, y + 5.0 + inset)
		pip.size = Vector2(side, side)
		pip.color = GardenTheme.LEAF_DARK if shown else Color(GardenTheme.INK, 0.35)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hints.add_child(pip)

		var title := Label.new()
		title.name = "HintTitle_%s" % id
		title.text = Hud.hint_title(id)
		title.position = Vector2(SHELF_TEXT_X, y)
		title.size = Vector2(text_width, SHELF_TITLE_HEIGHT)
		title.add_theme_font_size_override("font_size", SHELF_TITLE_FONT_SIZE)
		title.add_theme_color_override("font_color",
			GardenTheme.LEAF_DARK if shown else Color(GardenTheme.INK, 0.38))
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hints.add_child(title)

		var note := Label.new()
		note.name = "HintNote_%s" % id
		note.position = Vector2(SHELF_TEXT_X, y + SHELF_TITLE_HEIGHT - 1.0)
		# Size THEN autowrap, and no clip_text -- copied from _page_note (the facing
		# page's wrapped note), which is the one shape in this file proven to wrap.
		note.size = Vector2(text_width, HINT_NOTE_HEIGHT)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", HINT_NOTE_FONT_SIZE)
		# An UNSHOWN hint's note is drawn at the same 0.7 a shown one is, not the
		# shelf's 0.32. A greyed milestone is a thing you have not done and reads fine
		# as a whisper; an unshown hint is the one row on this page a player most needs
		# to be able to read. The pip size and the "Not shown yet — " prefix carry the
		# state, so nothing is hidden behind not having seen it.
		note.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.7))
		# NO clip_text and NO overrun trim, unlike the shelf's notes and unlike the
		# title above. A clipped Label is single-line by definition, so it cancels the
		# autowrap two lines up -- the note measured 848px wide in a 360px pane and hung
		# 510px off the page onto the facing art, ellipsising the instruction this page
		# exists to carry. The wrap IS the overrun policy here; the height budget
		# (HINT_NOTE_HEIGHT, gated by the tests) is what stops it running long.
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hints.add_child(note)
		# TEXT LAST, and this is the mechanism -- not the property order above it.
		# A Label's size is clamped up to its own minimum, and an autowrapping Label
		# with text already in it reports the UNWRAPPED width as that minimum. Assigned
		# first, the three notes came out 848, 607 and 726 px wide in a 360px pane,
		# each exactly as wide as its own sentence, hanging over the facing page's art.
		#
		# _page_note (the facing note) never hit this because _build_page_note sizes it
		# EMPTY and go_to() fills it afterwards. Same trick, made deliberate here.
		note.text = Hud.hint_note_text(id, shown)


## "1 of 3 seen", the hints page's provenance line — the same slot the shelf's score
## sits in, and counted the same way: off `Hud.hint_ids()`, which is `RunConfig.HINTS`,
## so an id in an older save that is no longer a hint cannot push the total past the
## rows the page actually drew.
static func hints_progress_text() -> String:
	var ids: Array[String] = Hud.hint_ids()
	var shown: int = 0
	for id: String in ids:
		if RunConfig.has_milestone(id):
			shown += 1
	return "%d of %d seen" % [shown, ids.size()]


## The legend pane, on the same matte as a photograph and the shelf. Mirrors
## `_build_shelf` exactly — one Control the size of DRAWING_BOX, hidden until its page
## comes up — so the four kinds share a geometry and only one of them is ever visible.
func _build_legend() -> void:
	_legend = CueLegend.new()
	_legend.name = "CueLegend"
	_legend.position = DRAWING_BOX.position
	_legend.size = DRAWING_BOX.size
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend.visible = false
	add_child(_legend)


## The legend page's note, with its row count filled in from the table rather than
## written out. Static and pure so the wording is assertable without building the
## screen — the same reason shelf_note_text() below is static.
##
## Spelled rather than printed as a digit because the sentence is prose a player reads,
## not a readout: "the 6 here are worth more than 6 facts" is a different register from
## every other note on the screen. count_word() falls back to the digit above twelve,
## which is well past the point where the page stops fitting (game/cue_legend.gd:242
## prices the seventh row).
static func legend_note_text() -> String:
	var word: String = count_word(CueLegend.row_count())
	return String(PAGES[page_for_kind(KIND_LEGEND)]["note"]) % [word, word]


## An English number word for 1-12, the digit beyond that. Small on purpose: this exists
## for prose that must agree with a table, and a table that reaches thirteen has a layout
## problem long before it has a spelling one.
static func count_word(n: int) -> String:
	const WORDS: Array[String] = [
		"zero", "one", "two", "three", "four", "five", "six",
		"seven", "eight", "nine", "ten", "eleven", "twelve",
	]
	if n < 0 or n >= WORDS.size():
		return str(n)
	return WORDS[n]


## What a shelf row's second line says. The prefix is the channel that survives
## being printed in one colour: "Cleared it without an escape" and "Not yet —
## cleared it without an escape" are the same fact in two tenses, and a player who
## cannot tell the greyed rows from the earned ones by hue can still read which is
## which. Static, so the wording is assertable without building the screen.
static func shelf_note_text(id: String, earned: bool) -> String:
	var note: String = Milestones.note_of(id)
	if earned or note.is_empty():
		return note
	return "Not yet — %s%s" % [note.substr(0, 1).to_lower(), note.substr(1)]


## "3 of 7 earned", the count the shelf's provenance line carries. Counted off
## Milestones.TABLE rather than off earned_milestones.size(), so an id from a
## newer build sitting in the save cannot push the total past the shelf's rows.
static func shelf_progress_text() -> String:
	var earned: int = 0
	for row: Dictionary in Milestones.TABLE:
		if RunConfig.has_milestone(String(row["id"])):
			earned += 1
	return "%d of %d earned" % [earned, Milestones.TABLE.size()]


## Which page is the shelf, or -1. Same shape as page_for_plant(): the index is
## derived from the table rather than written down, so appending a page above it
## cannot silently point a test at a drawing.
static func shelf_page() -> int:
	return page_for_kind(KIND_SHELF)


func _build_right_page() -> void:
	add_child(_pane_label("SpritePaneLabel", "In the game", RIGHT_CENTRE))

	_sprite_rect = TextureRect.new()
	_sprite_rect.name = "Sprite"
	_sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# STRETCH_SCALE, not KEEP_ASPECT_CENTERED: the control is resized to a whole
	# multiple of the texture by _fit_sprite() below, so there is nothing left
	# for the stretch mode to letterbox and a fractional scale can never sneak
	# back in through a rounding difference between the two.
	_sprite_rect.stretch_mode = TextureRect.STRETCH_SCALE
	# The sprites are 64px art shown here at ~200px. Bilinear filtering at that
	# ratio turns the outlines — which the style contract in art_src/STYLE.md
	# defines as a darker shade of the fill, one pixel wide — into a smear.
	_sprite_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite_rect.position = SPRITE_BOX.position
	_sprite_rect.size = SPRITE_BOX.size
	_sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sprite_rect)

	_caption = Label.new()
	_caption.name = "Caption"
	_caption.position = Vector2(RIGHT_CENTRE - TEXT_WIDTH / 2.0, PLANT_HEADING_Y)
	_caption.size = Vector2(TEXT_WIDTH, 30.0)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.add_theme_color_override("font_color", GardenTheme.LEAF_DARK)
	add_child(_caption)

	_page_note = Label.new()
	_page_note.name = "NoteLabel"
	_page_note.position = NOTE_RECT.position
	_page_note.size = NOTE_RECT.size
	_page_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_note.add_theme_font_size_override("font_size", 14)
	_page_note.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.8))
	# The notes vary in length by ~80 characters. Without this the longest one
	# runs past the bottom of the page and over the pager; the box is the
	# budget, and text that will not fit gets an ellipsis rather than the paper.
	_page_note.clip_text = true
	_page_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_page_note)


func _pane_label(node_name: String, text: String, centre_x: float) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = Vector2(centre_x - TEXT_WIDTH / 2.0, PANE_LABEL_Y)
	label.size = Vector2(TEXT_WIDTH, 20.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.5))
	return label


func _build_footer() -> void:
	var prev_button := Button.new()
	prev_button.name = "PrevButton"
	prev_button.text = "‹ Prev"
	prev_button.position = Vector2(PAGE_SPLIT - PAGER_WIDTH - 80.0, FOOTER_Y)
	prev_button.size = Vector2(PAGER_WIDTH, FOOTER_HEIGHT)
	prev_button.pressed.connect(func() -> void: go_to(_page - 1))
	add_child(prev_button)

	_page_label = Label.new()
	_page_label.name = "PageLabel"
	_page_label.position = Vector2(PAGE_SPLIT - 80.0, FOOTER_Y + 8.0)
	_page_label.size = Vector2(160.0, 24.0)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.7))
	add_child(_page_label)

	_next_button = Button.new()
	_next_button.name = "NextButton"
	_next_button.text = "Next ›"
	_next_button.position = Vector2(PAGE_SPLIT + 80.0, FOOTER_Y)
	_next_button.size = Vector2(PAGER_WIDTH, FOOTER_HEIGHT)
	_next_button.pressed.connect(func() -> void: go_to(_page + 1))
	add_child(_next_button)


## Left/Right turn the page and Escape closes, which is what anyone reading six
## pages will reach for first.
##
## Handled in `_input` rather than `_unhandled_input` on purpose: a focused
## Button consumes `ui_left`/`ui_right` for focus navigation, so by the time
## unhandled input runs the arrow keys are already gone. Only the three keys
## below are swallowed; Tab and Enter still reach the buttons normally.
func _input(event: InputEvent) -> void:
	# Both shapes a verb can arrive in — see Game._unhandled_input for why the
	# InputEventKey-only narrowing that used to be here made these three
	# unreachable from the devtools bridge.
	if not (event is InputEventKey or event is InputEventAction):
		return
	# Actions rather than keycodes — KeyBindings.SCOPE_NOTEBOOK is where these
	# three are defined and where the settings screen rebinds them. The shadowing
	# above is still the point: `garden_page_prev` ships on the same key as
	# `ui_left`, and only being in `_input` is what gets it there first.
	if event.is_action_pressed(KeyBindings.ACTION_PAGE_PREV):
		go_to(_page - 1)
	elif event.is_action_pressed(KeyBindings.ACTION_PAGE_NEXT):
		go_to(_page + 1)
	elif event.is_action_pressed(KeyBindings.ACTION_BACK):
		back_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()


## The pages that show a photograph of paper. Counted rather than assumed, so the
## subheading and every test that wants "the original five" stay right when a
## sixth drawing turns up.
##
## A loop and not `PAGES.filter(...)`: Array.filter hands back an untyped Array,
## which returning as Array[Dictionary] is a runtime error rather than anything
## the static checkers see.
static func drawing_pages() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in PAGES:
		if String(entry.get("kind", KIND_DRAWING)) == KIND_DRAWING:
			out.append(entry)
	return out


## Which page is about `id`, or -1 if the notebook never mentions it. The one
## question worth asking of this table from outside: a plant with no page is a
## plant the game's only explanatory screen leaves out, which is exactly how both
## tier-2 plants got missed.
static func page_for_plant(id: StringName) -> int:
	for i: int in PAGES.size():
		if StringName(PAGES[i].get("plant", &"")) == id:
			return i
	return -1


## The index card on the left half of a KIND_PLANT page.
##
## Built out of PlantCatalog rather than written into PAGES, so a re-priced or
## re-tiered plant corrects its own page. That is the compensation for having no
## drawing: a drawing page is a fixed historical fact and this one cannot go stale.
static func plant_spec(id: StringName) -> String:
	if not PlantCatalog.has(id):
		return ""
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Costs %d seeds." % PlantCatalog.cost(id))
	if PlantCatalog.unlocked_at_start(id):
		lines.append("Tier %d, and on the bar from the first frame." % PlantCatalog.tier(id))
	else:
		lines.append("Tier %d, and locked until a packet hands it over." % PlantCatalog.tier(id))
	var reach: float = PlantCatalog.reach(id)
	if reach <= 0.0:
		lines.append("Reaches nothing — it is not pointed at the lane.")
	else:
		lines.append("Reaches %d px, about %.1f cells." % [int(roundf(reach)), reach / float(Board.CELL)])
	lines.append("")
	lines.append(PlantCatalog.blurb(id))
	return "\n".join(lines)


## Wraps, so Prev on page 0 and Next on the last page both stay useful instead
## of dead-ending.
##
## The content is applied synchronously and only then animated. A turn that
## swapped the texture in a tween callback would leave `go_to()` returning with
## the old page still on screen — invisible to a player, fatal to a test, and
## exactly the class of bug GardenTheme.animations_enabled() exists to prevent.
func go_to(page: int) -> void:
	var previous: int = _page
	_page = ((page % PAGES.size()) + PAGES.size()) % PAGES.size()
	var entry: Dictionary = PAGES[_page]
	var kind: String = String(entry.get("kind", KIND_DRAWING))
	var drawn: bool = kind == KIND_DRAWING
	var spec: bool = kind == KIND_PLANT
	var file: String = String(entry["drawing"]).get_file()
	# Loaded on every kind of page even though two of them keep it hidden: a
	# Drawing left holding a null texture is a node every layout check has to
	# special-case, and the load is a cached one either way.
	_drawing_rect.texture = load(String(entry["drawing"])) as Texture2D
	# Exactly one of the five is up at a time; they share the matte on purpose.
	_drawing_rect.visible = drawn
	_spec.visible = spec
	_shelf.visible = kind == KIND_SHELF
	if kind == KIND_HINTS:
		# Rebuild for THIS page's slice before showing it. The page index rides on the
		# PAGES entry rather than being derived from the page number, so the two hint
		# pages do not have to be adjacent in the book.
		var want: int = int(entry.get("hint_page", 0))
		if want != _hints_page or _hints == null or not is_instance_valid(_hints):
			_hints_page = want
			_build_hints()
	_hints.visible = kind == KIND_HINTS
	_legend.visible = kind == KIND_LEGEND
	_spec.text = plant_spec(StringName(entry.get("plant", &""))) if spec else ""
	_drawing_pane_label.text = pane_label_for(kind)
	# The provenance line, which is the whole difference between the kinds of
	# page: a drawing page names the photograph it is showing, a plant page says
	# outright that there is no photograph and names the file that exists
	# instead, and the shelf has no artefact at all — it has a score.
	if drawn:
		_source.text = file
	elif spec:
		_source.text = "%s — never on paper" % file
	elif kind == KIND_LEGEND:
		# The provenance line's job on every other kind is to name the artefact. A legend
		# has no artefact; what it has is a scope, and saying five-of-ten out loud is the
		# honest version — a player who counts more shapes on the board than the page
		# lists should be told that is expected rather than left to doubt the page.
		_source.text = "%d of the board's %d marks — the ones you meet first" % [
			CueLegend.row_count(), OVERLAY_GRAMMAR_SHAPES]
	elif kind == KIND_HINTS:
		# A score, like the shelf's, and deliberately not read as one: "1 of 3 seen" is
		# not progress a player can go and make. It says how much of this page is a
		# reminder and how much is news, which is the only thing the number is for here.
		_source.text = hints_progress_text()
	else:
		_source.text = shelf_progress_text()
	_sprite_rect.texture = load(GardenTheme.retina_path(String(entry["sprite"]))) as Texture2D
	_fit_sprite()
	_caption.text = String(entry["caption"])
	# The legend's note is a template (see its PAGES entry); every other page's is final.
	_page_note.text = legend_note_text() if kind == KIND_LEGEND else String(entry["note"])
	_page_label.text = "%d / %d" % [_page + 1, PAGES.size()]
	_paper.current_page = _page
	if previous != _page:
		_play_turn(_direction(previous, _page))


## Size the sprite to a whole multiple of its texture and centre that inside
## SPRITE_BOX. The control's own rect changes per page, so the invariant worth
## asserting is enclosure and integer scale, not a fixed size — see
## test_notebook_images_stay_inside_their_box.
func _fit_sprite() -> void:
	var texture: Texture2D = _sprite_rect.texture
	if texture == null:
		return
	var source := Vector2(texture.get_width(), texture.get_height())
	var factor: float = floorf(minf(SPRITE_BOX.size.x / source.x, SPRITE_BOX.size.y / source.y))
	factor = clampf(factor, 1.0, MAX_SPRITE_ZOOM)
	var drawn: Vector2 = source * factor
	_sprite_rect.size = drawn
	# Floored, so the control lands on whole pixels. Half a pixel of offset is
	# what puts a seam through point-sampled art.
	_sprite_rect.position = (SPRITE_BOX.position + (SPRITE_BOX.size - drawn) / 2.0).floor()


## +1 for a forward turn, -1 for a backward one, following the shorter way
## round so wrapping 6 -> 1 still nudges forwards.
static func _direction(from_page: int, to_page: int) -> float:
	var forward: int = posmod(to_page - from_page, PAGES.size())
	return 1.0 if forward <= PAGES.size() / 2 else -1.0


func _play_turn(direction: float) -> void:
	if not GardenTheme.animations_enabled():
		return
	var tween := create_tween()
	tween.set_parallel(true)
	# `_hints` is here because `_shelf` is: they are the same pane built twice, and a
	# left page that stayed still while the right one turned would read as a stuck
	# screen. (`_legend` is the one left out, and predates this — CueLegend draws itself
	# in `_draw`, so nudging its position:x mid-turn is a repaint per frame rather than
	# a moved child. Not changed here; it is not this page's to decide.)
	for node: Control in [_drawing_rect, _spec, _shelf, _hints, _sprite_rect, _caption,
			_page_note, _source]:
		tween.tween_property(node, "modulate:a", 1.0, TURN_SECONDS).from(TURN_START_ALPHA)
		tween.tween_property(node, "position:x", node.position.x, TURN_SECONDS) \
			.from(node.position.x + TURN_NUDGE * direction) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)
