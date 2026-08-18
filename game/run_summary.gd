class_name RunSummary
extends Control

## The post-mortem. What a finished run actually amounted to, on a card that
## stays until the player dismisses it.
##
## This replaces a banner plus a 30-second message. Every number below was
## already computed and had nowhere to live: the seed total went into a two-line
## banner, and the per-cell reading — the single most useful thing the run
## produced — went into `Hud.show_message(..., 30.0)`, a one-line clipped Label
## that erases itself while the player is still reading the banner above it.
##
## The backdrop is deliberately not opaque. `Board.show_run_pressure()` paints
## the run's whole damage map onto the road at the same moment this appears, and
## that map is the visual half of the same post-mortem — so the screen floats
## over it rather than replacing it.
##
## The BACKDROP is what floats. The card is not: `GardenTheme.paper_panel()` is
## opaque PAPER, and CARD covers screen x 128..768, y 96..552. Measured against
## the road PATH_CORNERS traces (board local, offset by Hud.BAR_HEIGHT = 72),
## that hides 19 of the 32 road cells outright, leaves 9 showing only their
## bottom halves along row 7, and leaves exactly 4 fully visible: (0,1), (1,1),
## (12,7) and the exit (13,7). So "the row naming a cell has that actual cell
## tinted behind it" — which this comment used to claim — is false for most of
## the board, and the one cell a player can always see is the exit.
##
## The map and the cell-naming row are deliberately not the same reading. The
## map is every pest that left the road, escapes included, so its reddest cell is
## the exit on a run that bled out; the row counts only the pests a cell stopped
## for good. See _stop_cell_text — they agreed until the exit started winning a
## row headed "weakest ground" with pests it had never touched.
##
## Put those two facts together and the player of a losing run sees one red
## corner, bottom right, and a card naming a cell they cannot even look at. Both
## halves are correct and both are wanted; nothing said they were two questions.
## `map_legend_text` is the sentence that says so, and it is deliberately printed
## on the board below the card rather than added as an eighth row — it captions a
## picture, so it belongs beside the picture, and the strip it sits in is right
## next to the only red the player can reliably see.
##
## Node names are a contract, same as the HUD's: the devtools bridge presses
## these buttons by path and test_selftest.gd reads these labels.

signal replay_requested
signal gate_requested

## Card rect in viewport coordinates. Centred on the *board*, not the window —
## the board occupies x < 896 and the side panel owns the rest, so centring on
## the window would sit the card visibly off to the right of the thing it is
## describing.
const CARD := Rect2(128.0, 96.0, 640.0, 456.0)
const ROW_HEIGHT: float = 34.0
const ROW_INSET: float = 36.0
const FIRST_ROW_Y: float = 186.0
## Gap between rows. 4, not the 8 this started at: the card grew from five rows to
## seven when the run learned to count what it defeated, and at 8 the last row ran
## to y=472 against buttons at 476 — four pixels, measured live. Not an overlap,
## but the same flush-boundary shape that put the selection panel's foot exactly on
## the panel edge two cycles ago, and BUTTON_CLEARANCE now refuses it.
const ROW_GAP: float = 4.0
## Minimum space the last row must leave above the buttons.
const BUTTON_CLEARANCE: float = 16.0

## Alpha of the backdrop. Lower than the notebook's 0.88 on purpose: this screen
## has something worth seeing behind it.
const BACKDROP_ALPHA: float = 0.55

const BUTTON_SIZE := Vector2(232.0, 44.0)
const BUTTON_Y: float = 476.0

## The milestone ribbon: what this run did for the first time ever, listed BESIDE
## the card rather than on it.
##
## Beside, because the card has no room and the arithmetic saying so is already
## written down twice in this file — _compost_text and beds_text both fold a second
## number into an existing row rather than add an eighth, because rows step by
## ROW_HEIGHT + ROW_GAP = 38 from FIRST_ROW_Y and an eighth would foot at 486,
## below the buttons at 476. A milestone list is variable-length, so it could not
## take one row even if one were free.
##
## The space it uses is real estate the post-mortem already owns and has never
## drawn in: the backdrop covers the whole viewport, and CARD ends at x = 768 while
## the viewport runs to 1152. 792 leaves a 24px gutter off the card's edge and
## another 24 off the right of the screen. Vertically it starts level with the
## card and grows downward; at the full seven milestones it foots at 438, which
## clears the card's own foot at 552 and is nowhere near MAP_LEGEND_Y = 588 — and
## `test_the_milestone_ribbon_clears_the_card_and_the_map_legend` measures exactly
## that rather than trusting this paragraph.
##
## Nothing is drawn at all when the run earned nothing new, same rule as the map
## legend: an empty Panel is what `validate-ui` reports as a zero-content Control,
## and "no first-times this run" is the common case, not an error state.
const RIBBON_X: float = 792.0
const RIBBON_WIDTH: float = 336.0
const RIBBON_TOP: float = 96.0
const RIBBON_PAD: float = 14.0
const RIBBON_HEADING_HEIGHT: float = 26.0
const RIBBON_HEADING_GAP: float = 8.0
const RIBBON_ROW_HEIGHT: float = 40.0
const RIBBON_TITLE_FONT_SIZE: int = 17
const RIBBON_NOTE_FONT_SIZE: int = 12
const RIBBON_HEADING_FONT_SIZE: int = 15

## The map legend's strip, in viewport coordinates. Every number here is measured
## against something that would break it, so none of them is a taste call:
##
##   - the card's paper foots at 552 and its StyleBoxFlat shadow (size 14, offset
##     (0, 6)) reaches 572, so anything above 572 sits in the drop shadow;
##   - the road's last row is board row 7, which is screen y 520..584 once
##     Hud.BAR_HEIGHT is added — a caption overlapping THAT would cover the very
##     tint it is captioning, which is the one failure this label must not have;
##   - the viewport is 648 tall.
##
## 588 clears both (4px under the road, 16 under the shadow) and 588 + 22 = 610
## leaves 38px at the bottom. The width is the board's, not the card's, because
## the sentence is about the board.
const MAP_LEGEND_Y: float = 588.0
const MAP_LEGEND_HEIGHT: float = 22.0
const MAP_LEGEND_WIDTH: int = Board.COLS * Board.CELL
const MAP_LEGEND_FONT_SIZE: int = 13

## The reach note: the one sentence that says covered ground and fought ground are
## not the same thing. See reach_note_text() for what it says and why the card
## itself could not take it.
##
## WHERE, and the measurement that moved it. The obvious home was a second strip
## under `map_legend_text`, and it does not survive the entrance. `_play_entrance`
## drops every child by RISE_OFFSET_WIN = 32 and tweens it back up, so the real
## bottom budget on this screen is not the 648-tall viewport — it is 648 - 32 = 616,
## and the legend already foots at 610. There are six pixels down there, not the
## thirty-eight the legend's own comment counts, because that comment measures the
## resting position and the rise happens before it. A second 20px line would have
## hung 14px off the bottom of the screen for the whole 0.2s of a winning card's
## rise, on precisely the runs a player replays.
##
## So it goes in the column the ribbon opened — beside the card, where the same
## comment already argues the post-mortem owns real estate it has never drawn in.
## Vertically it follows the ribbon rather than sitting at a fixed y, which is what
## `reach_note_top` is for: at the full seven milestones the ribbon foots at 438,
## this clears it by REACH_NOTE_GAP and foots at 550, level with the card's own foot
## at 552 and 66px inside the rise budget. With no milestones — the common case — it
## takes the top of the column instead of leaving a hole above itself.
##
## RE-MEASURED for plant-tower-defense-q8db, which added an eighth possible row (the
## first record, see `ribbon_entries`). At `worst_ribbon_rows()` = 8 the ribbon foots at
## 478, the note starts at 494 and foots at 590 — still inside the 616 rise budget, by
## 26px rather than 66. That is the whole of the slack this change spent, and it is
## spent in the side column, not on the stats row. A NINTH row would foot at 630 and
## hang off the bottom during the rise, so this column is now full:
## `test_the_widest_ribbon_this_game_can_draw_still_clears_the_rise` is what says so.
##
## A Panel and not a bare Label, unlike the legend. The legend sits over dark road
## for its whole width; this column straddles the seam at x = 896 where the board
## ends and the side panel begins, so a bare label would be legible over one half
## and not the other. Its box is the ribbon's ink WITHOUT the gold: gold is what this
## game spends on compost and on firsts, which is to say on something you got, and
## this is a note about what went wrong.
const REACH_NOTE_GAP: float = 16.0
const REACH_NOTE_HEIGHT: float = 96.0
const REACH_NOTE_PAD: float = 14.0
const REACH_NOTE_FONT_SIZE: int = 13

## Entrance rise, matching the title screen's idiom. Gated on
## GardenTheme.animations_enabled() — headless never pumps the tween, so the
## card must already be correct before it runs.
##
## Win and loss no longer share one motion. _build_heading already picks a
## different heading text and colour for the two outcomes ("The garden
## holds!" in LEAF_DARK against "The garden is eaten" in DANGER); a rise that
## could not tell them apart was the one place left where the card's motion
## disagreed with what it says. A win rises fast and a little further, with
## TRANS_BACK's small overshoot, so it lands like a flourish; a loss rises
## slower and shorter, with the same TRANS_CUBIC every other entrance in this
## game uses, so it settles rather than snaps -- heavier, not more decorated.
const RISE_SECONDS_WIN: float = 0.2
const RISE_OFFSET_WIN: float = 32.0
const RISE_SECONDS_LOSS: float = 0.42
const RISE_OFFSET_LOSS: float = 18.0

var _rows: Array[Label] = []


## `stats` is Game.state() plus the end-of-run extras; see Game._end_run.
static func build(stats: Dictionary) -> RunSummary:
	var screen := RunSummary.new()
	screen.name = "RunSummary"
	screen._stats = stats
	return screen


var _stats: Dictionary = {}


func _ready() -> void:
	# Explicit position+size rather than PRESET_FULL_RECT: this Control is added
	# with add_child() outside any layout pass, where the preset resolves to 0x0
	# and leaves the whole card invisible. Same reason as TitleScreen._ready().
	position = Vector2.ZERO
	size = Vector2(_viewport_width(), _viewport_height())
	theme = GardenTheme.build()

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(GardenTheme.INK, BACKDROP_ALPHA)
	backdrop.position = Vector2.ZERO
	backdrop.size = size
	# MOUSE_FILTER_STOP: the run is over, and the side panel underneath still has
	# live plant and packet buttons that would otherwise stay clickable.
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var card := Panel.new()
	card.name = "Card"
	card.position = CARD.position
	card.size = CARD.size
	card.add_theme_stylebox_override("panel", GardenTheme.paper_panel())
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)

	_build_heading()
	_build_rows()
	_build_milestone_ribbon()
	_build_map_legend()
	_build_reach_note()
	_build_buttons()

	if GardenTheme.animations_enabled():
		_play_entrance()


func _build_heading() -> void:
	var won: bool = bool(_stats.get("victory", false))

	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "The garden holds!" if won else "The garden is eaten"
	heading.position = Vector2(CARD.position.x, CARD.position.y + 28.0)
	heading.size = Vector2(CARD.size.x, 44.0)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color",
		# DANGER, not PAPER_MARGIN. That one is the notebook page's printed
		# margin rule -- paper stock chosen for a different screen's look -- and
		# it is the softer of the two reds. "The garden is eaten" is the loudest
		# "this cost you something" line in the game and should wear the colour
		# that means exactly that everywhere else.
		GardenTheme.LEAF_DARK if won else GardenTheme.DANGER)
	add_child(heading)

	var sub := Label.new()
	sub.name = "Subheading"
	sub.text = _score_line()
	sub.position = Vector2(CARD.position.x, CARD.position.y + 78.0)
	sub.size = Vector2(CARD.size.x, 26.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.7))
	add_child(sub)


## Whether this run set the garden's FIRST record, rather than beat an earlier one
## (plant-tower-defense-q8db).
##
## `previous_best` is the number the record just beat, and 0 means there was nothing
## there — the mode had never been scored. `TitleScreen._arm_record_ratchet` reads the
## same 0 and refuses to roll, correctly: counting up from a zero the player never held
## would tell someone who has just set their first score that they climbed out of it.
## But refusing the roll was the whole treatment, so the most significant record a
## player will ever set ended up with strictly LESS than a later, smaller one. This is
## the flag the card uses to give it something else instead.
##
## DEFAULTS TO -1, NOT 0, and the difference is the whole safety of it. `previous_best`
## is a key `Game.summary_stats` does not write yet; absent must mean "unknown", which
## reads as "not a first" and leaves the card saying exactly what it says today. A 0
## default would call every record on every card a first — including on the pause exits,
## which build a card from a stats dict assembled elsewhere.
func first_record() -> bool:
	if not bool(_stats.get("new_record", false)):
		return false
	return int(_stats.get("previous_best", -1)) == 0


## The seed total against the persisted best. Pulled out as its own builder so a
## test can assert every branch of it without standing up a Control — the same
## shape TitleScreen.high_score_text() uses for the same reason.
func _score_line() -> String:
	return score_line_at(int(_stats.get("seeds_earned_total", 0)),
		bool(_stats.get("new_record", false)), first_record(),
		int(_stats.get("high_score", 0)), bool(_stats.get("endless", false)))


## The same line for GIVEN numbers, static and pure, which is what lets the suite assert
## all three branches without a save file or a played run — the shape
## `TitleScreen.high_score_text_at` already uses next door for the same reason.
##
## "this garden's first record" and not "a new best". A first record is not a better
## number than the one before it; there was no number before it, and "a new best" quietly
## claims a comparison that did not happen. Naming it as a first is also the channel that
## survives colour being discarded — it is the WORDS that differ, not a tint.
static func score_line_at(earned: int, new_record: bool, first: bool, best: int,
		endless: bool) -> String:
	if first:
		return "%d seeds grown — this garden's first record" % earned
	if new_record:
		return "%d seeds grown — a new best" % earned
	# "your best" is now the record for the mode just played, not a single number
	# shared between the eight-wave campaign and an unbounded endless run.
	var mode: String = "endless" if endless else "campaign"
	return "%d seeds grown — your best %s is %d" % [earned, mode, best]


## Every row is `label: value`, built from one table so the order is readable in
## one place and a new stat cannot be added without deciding where it sits.
## How many stat rows fit above the buttons.
##
## Computed rather than stated. The comment on `beds_text()` does these sums in prose --
## rows step ROW_HEIGHT + ROW_GAP = 38 from FIRST_ROW_Y, the seventh foots at 448 against
## BUTTON_Y 476, an eighth would foot at 486 -- and is correct. This is the same sums as a
## number, so the next row to be proposed is a lookup rather than a re-derivation.
##
## The floor keeps BUTTON_CLEARANCE, which is this card's equivalent of
## OverlayScreen.FOOTER_GAP: a row flush against the buttons overlaps nothing and reads
## wrong.
static func rows_capacity() -> int:
	return OverlayScreen.rows_that_fit(FIRST_ROW_Y, ROW_HEIGHT + ROW_GAP, ROW_HEIGHT,
		BUTTON_Y - BUTTON_CLEARANCE)


func summary_rows() -> Array:
	var rows: Array = [
		["Waves survived", _waves_text()],
		["Pests defeated", "%d" % int(_stats.get("pests_defeated", 0))],
		["Time in the garden", _duration_text()],
		["Seeds spent", spend_text()],
		["Garden lost", beds_text()],
		["Compost swept", _compost_text()],
		["Where you held them", _stop_cell_text()],
	]
	return rows


## Waves, with the threat scale folded in — the subject the row "Threat reached"
## used to hold on its own, and the reason this card could afford a new seventh
## subject without growing an eighth row.
##
## The fold is free of information loss in the strict sense, not merely the
## convenient one. `Game.summary_stats` writes `threat_level` as
## `WaveDirector.threat_level(current_wave)` — a pure function of the wave number
## this very row already prints. The two rows were one measurement stated twice,
## once raw and once scaled, and the card was paying a whole row for the second
## copy. Every other fold on this card (see _compost_text, beds_text) had to argue
## that a second number was worth crowding a row; this one only has to point out
## that the second number was already there.
##
## Height is why it had to happen at all: rows step ROW_HEIGHT + ROW_GAP = 38 from
## FIRST_ROW_Y, rows_capacity() is 7, and ROW_GAP has already been cut once (8 to
## 4) to fit the seventh. An eighth row foots at 486 against buttons at 476 — below
## them, not merely inside BUTTON_CLEARANCE. So a new subject on this card is
## always a swap, never an addition, and the row to give up is the one whose number
## another row can already be read off.
##
## Level 1 prints no threat clause, matching the HUD's own rule for the same
## number: `test_the_threat_readout_hides_itself_at_wave_one` pins the readout
## hiding itself at wave one because "threat level 1" is the scale's floor and
## says nothing. A post-mortem is not a live readout, but the number is the same
## number and it is no more informative here.
##
## Width: the longest this row gets is a deep endless run, "137 — threat level 9"
## at 20 characters, against the beds row's "5 of 10 beds — 4 walked in untouched"
## at 36, which sets the card's value-column high-water mark. Nowhere near it.
func _waves_text() -> String:
	var wave: int = int(_stats.get("wave", 0))
	var endless: bool = bool(_stats.get("endless", false))
	var waves: String = "%d" % wave if endless else "%d of %d" % [wave, int(_stats.get("wave_count", 0))]
	var level: int = int(_stats.get("threat_level", 1))
	if level <= 1:
		return waves
	return "%s — threat level %d" % [waves, level]


## Where the run's seeds went: breadth against depth, as two numbers and no verdict.
##
## This is the row cycle 101 bought. Two campaigns, same economy, same map, no
## cheats, differing in one policy bit — whether a surplus bought another plant or
## another level on one already planted. Breadth-first reached eleven level-1
## plants and died at wave 10. Depth-first won all 22 waves and lost no lives. The
## losing run was not ignorant of the Upgrade button; it spent the seeds elsewhere.
## That is why the one-shot hint teaching that the button exists — see
## `Game._maybe_teach_upgrading` — cannot reach this player: it answers a question
## they had already answered, and one line on a live message row cannot carry a
## policy anyway. This card can, because it is the moment the player is asking.
##
## NUMBERS, NOT A SENTENCE, and that is the whole design. Every phrasing that
## explains the comparison also grades the player for it, and a card that says
## "you spread yourself thin" to someone who just lost their garden is a worse
## screen than one that says nothing. Two totals side by side state the policy and
## leave the conclusion where it belongs. The row is also placed fourth, in the
## middle of the card among the run's shape rather than down among the damage, so
## it reads as a fact about the run and not as a cause of death.
##
## SEEDS, not purchase counts — argued at length on `Game.seeds_on_plants`. Short
## version: a plant and an upgrade cost different amounts, so counts of them are
## not comparable quantities, and it was the seeds that cycle 101 varied.
##
## No sentinel branch, unlike _compost_text. That one needs `-1` because an absent
## denominator and a perfect sweep would otherwise read alike. Here they do not:
## `Game.summary_stats` writes both keys on every run, so "0 on plants" is a run
## that really did spend nothing on breadth — the free starter is free, so a run
## that planted only its one free cob and died genuinely reads 0, correctly.
##
## Not a ledger, and phrased so it never claims to be one. Packets are a third
## sink and are in neither total; the row names two destinations rather than
## partitioning a total, so nothing here has to be true of `seeds_earned_total`
## minus the purse. Widest realistic string is a long endless run's "8421 on
## plants, 4210 on upgrades" at 32 characters, inside the beds row's 36-character
## high-water mark for this column.
func spend_text() -> String:
	var plants: int = int(_stats.get("seeds_on_plants", 0))
	var upgrades: int = int(_stats.get("seeds_on_upgrades", 0))
	return "%d on plants, %d on upgrades" % [plants, upgrades]


## The beds row — the run's escape count, and now the only place the card says
## anything about *how* they were lost.
##
## The escapes were the one event on this card carrying no evidence at all.
## Board._run_escapes has exactly one key in every run by design (every escape is
## filed against exit_cell(), because the pest is off the board by then), so the
## spatial half of an escape is a constant and there is nothing there to read.
## What is not constant is whether anything ever reached the pest on its way
## down. Corn is the only damage in the game, so an untouched arrival means more
## plants and a fought one means a bigger plant — the two things a player buys.
##
## The stronger version of that claim was measured and is FALSE. This used to say
## an untouched arrival "means the road it walked had no coverage over it". It
## does not: across 14 driven waves and 439 pests, all 68 untouched escapes had
## walked at least one covered cell. What holds is the weaker direction — every
## one of them had ALSO walked ground the map marks `unaimed`, so the hole is
## real and the map named it in advance; the pest simply did not spend its whole
## walk outside coverage. See the same correction on Game._escapes_untouched.
##
## Folded into this row rather than given an eighth, for the reason _compost_text
## spells out at length: rows step by ROW_HEIGHT + ROW_GAP = 38 from FIRST_ROW_Y,
## the seventh foots at 448 against BUTTON_Y = 476, and an eighth would foot at
## 486 — below the buttons rather than merely inside BUTTON_CLEARANCE. This is
## already the row that counts escapes, so it is the row their evidence belongs
## on. It does cost the width it saves in height: this row now sets the card's
## value-column high-water mark, which the held-ground row used to.
##
## Three branches, and the third is the one that matters. `escapes_recorded` is
## how many escapes the run could read a pest off — Game._on_pest_escaped
## tolerates a null pest and several callers hand it one — so a run that observed
## none of its escapes falls back to the bare bed count it always printed rather
## than announcing "all were fought" about pests nothing ever looked at.
func beds_text() -> String:
	var beds: String = "%d of %d beds" % [int(_stats.get("lives_lost", 0)), Game.LIVES]
	var read: int = int(_stats.get("escapes_recorded", 0))
	if read <= 0:
		return beds
	var untouched: int = int(_stats.get("escapes_untouched", 0))
	if untouched <= 0:
		return "%s — all were fought" % beds
	return "%s — %d walked in untouched" % [beds, untouched]


## Compost as a fraction, not a bare tally: "12 of 19", the seeds swept against
## the seeds that were there to sweep. Every other row on this card is a total or
## a bound; "Compost swept 12" was the one number with no scale behind it, and a
## player cannot tell a clean run from an ignored lane by reading it.
##
## Folded into the existing row rather than given an eighth one. Height is the
## binding constraint: rows step by ROW_HEIGHT + ROW_GAP = 38, the seventh ends
## at 186 + 6*38 + 34 = 448 against buttons at 476, so there are 28px of slack
## and BUTTON_CLEARANCE wants 16 of them. An eighth row would foot at 486 — ten
## pixels *below* the top of the buttons, not merely inside the clearance — and
## ROW_GAP has already been cut once (8 to 4) to fit the seventh. Width is not
## the constraint: the value column is CARD.size.x * 0.58 - ROW_INSET = 335px,
## and "127 of 214" is shorter than the "3 of 5 beds" the Garden lost row above
## already renders, never mind the row that sets the real width high-water mark —
## which was the stopping-point row and is now beds_text(), since that row learned
## to say how the beds went. So the fraction is free and this row costs what it
## always did.
##
## `total_resolved()` is the denominator, so a husk still on the ground when the
## run ended is in neither half — see CompostMeter.total_resolved for why.
func _compost_text() -> String:
	var swept: int = int(_stats.get("compost_total", 0))
	# -1, not `swept`: an absent denominator and a perfect sweep must not read the
	# same. A stats dictionary that predates the denominator degrades to the bare
	# numerator it always showed, rather than claiming a "12 of 12" it cannot know.
	var resolved: int = int(_stats.get("compost_resolved", -1))
	if resolved < swept or resolved <= 0:
		return "%d" % swept
	return "%d of %d" % [swept, resolved]


## Minutes and seconds. A bare float of seconds is a number the player has to
## convert, and "413.7" is not a thing anyone recognises about their own run.
func _duration_text() -> String:
	var total: int = int(round(float(_stats.get("run_seconds", 0.0))))
	return "%d:%02d" % [total / 60, total % 60]


## The chokepoint, named as a chokepoint.
##
## This row used to be headed "Weakest ground" over `worst_cell` — the cell where
## the most pests left the road, killed or escaped alike. In almost every run
## that is the cell holding the player's best turret, so the post-mortem's one
## piece of spatial advice named the strongest ground in the garden and told the
## player it was the weakest. A player acting on it dismantles the thing that was
## working. The row is not merely useless when it is wrong; it is inverted.
##
## Two things changed. The number is now `stop_cell_stops` — losses with the
## escapes taken back out, so the exit cell cannot bid for the row with pests it
## never touched (Board.worst_stop_cell). And the heading states what is measured
## instead of interpreting it: "where you held them" is true of a chokepoint and
## true of a last-ditch stand at the exit, and neither reading recommends tearing
## anything down.
##
## The weakness half of the post-mortem is not missing, it is on the two rows
## that measure it directly — "Garden lost N of 10 beds" is the escape count, and
## the road underneath this card is still painted with the full mixed map, whose
## reddest cell IS the exit on a run that bled out. So the card carries both
## readings, in the two media each is honest in: a number for what stopped them,
## a picture for where they got to.
##
## The row wears "held", not "stopped", and that is the third change rather than
## a synonym. "Stopped" is already the mixed map's own word for its own reading —
## Board.depth_of documents `losses` as "every pest that STOPPED there, not every
## pest that hurt you", kills and escapes alike. A row headed "Where they
## stopped" therefore described the tint at least as well as it described this
## number, which is exactly the collision that made a player read the number as a
## caption for the picture. "Held" is true of a kill and false of an escape, so
## it cannot be read off the tint at all. See map_legend_text for the other side.
func _stop_cell_text() -> String:
	var cell: Vector2i = _stats.get("stop_cell", Vector2i(-1, -1))
	if cell.x < 0:
		# Not "nothing got past you", which is what this said before. That is a
		# claim about escapes, made from an empty measurement of kills: the run
		# that reaches this branch hardest is the one that stopped nothing at all
		# anywhere, and it read as the compliment for a flawless run.
		#
		# And note which run reaches it: one where every pest walked out. The road
		# behind the card is at its reddest in exactly that run, so this branch and
		# the tint are at their furthest apart here. map_legend_text still fires.
		return "nowhere — no ground held them"
	return "column %d, row %d — %d held" % [
		cell.x + 1, cell.y + 1, int(_stats.get("stop_cell_stops", 0)),
	]


## The caption for the picture. This is the whole of the fix for "the post-mortem
## names a cell the road under it may not be reddest at".
##
## The two readings are not collapsed, because a player wants both: "how far did
## they get" is the tint, "where did my ground actually do work" is the row. What
## was missing was any statement that they are two questions. An unlabelled
## picture next to a number reads as a picture the number captions.
##
## On a run that bleeds out they are guaranteed to disagree, not merely likely to:
## Game._on_pest_escaped files every one of the LIVES escapes against
## Board.exit_cell(), so the exit accumulates 10 losses without stopping anything,
## and worst_run_cell() goes to the one cell in the run that did the least. That
## is the run this sentence exists for.
##
## Reads `worst_cell`, which summary_stats has always exported and no part of this
## card has ever displayed — it is stored precisely because the paint is made from
## it. So the legend names the reddest cell out of the same value the tint peaks
## at, and the two cannot drift.
##
## Returns "" when nothing was lost anywhere: Board.show_run_pressure() early-
## returns on an empty loss map, so there is no red road, and a legend for it
## would be describing paint that was never applied.
func map_legend_text() -> String:
	var reddest: Vector2i = _stats.get("worst_cell", Vector2i(-1, -1))
	if reddest.x < 0:
		return ""
	if reddest == _stats.get("stop_cell", Vector2i(-1, -1)):
		# The agreeing case still gets a caption. Saying "these are the same cell"
		# is a reading; saying nothing leaves the player to assume it, and the
		# assumption is wrong on the next run.
		return "Red road: how far they got, escapes and all. Reddest at the very cell the card above names."
	# Kept short deliberately. The strip is MAP_LEGEND_WIDTH = 896px at font size
	# 13 with no autowrap, and this is the longest string the screen draws; see
	# test_the_map_legend_clears_the_card_the_road_and_the_bottom_of_the_screen,
	# which measures it through the resolved font rather than trusting the count.
	return ("Red road: how far they got, escapes and all. Reddest at column %d, row %d"
		+ " — the card above counts only what held.") % [reddest.x + 1, reddest.y + 1]


## "Covered" is not "fought", said once, in the player's own units.
##
## THE MECHANIC. A Corn Cobbler shoots only the pest furthest along, so a cob whose
## ring sits over eight road cells is busy with one pest and the other seven get
## nothing while it reloads. Measured three times and never once told to the
## player: the coverage block in `game.gd` records 3,909 of 4,664 stays on covered
## ground — 84% — passing with nothing touching the pest, and 82% of that is a cob
## that fired at a DIFFERENT pest during the stay. The board paints those cells as
## aimed at, correctly; the player loses beds on them anyway and is left to infer
## why from having lost.
##
## The two numbers are the two halves of that sentence and BOTH are already the
## game's own, neither recomputed here:
##
##   - `road_aimed` / `road_cells` is `Game.covered_road_cells()` against
##     `Board.road_cells()` — the same derived map the placement cue and the lane
##     overlay read, so the card cannot disagree with the board about which ground
##     was aimed at.
##   - `escapes_untouched` is `Pest._ever_engaged` counted at the exit, the flag
##     that already separates "you had no answer" from "your answer was not enough"
##     — see `Game._note_escape`, and `beds_text` above, which prints the same
##     number as the second half of its own row.
##
## WHY A SENTENCE AND NOT A ROW. There is no room for a row and the arithmetic
## saying so is `rows_capacity()`, which returns 7 against the 7 rows
## `summary_rows()` builds: an eighth foots at 486 against buttons at 476. There is
## no room in a fold either — `beds_text` already sets the card's value-column
## high-water mark and the width gate in test_combat measures every other row
## against it. And a fold would not do the job anyway: the ACCEPTANCE is that the
## card names the distinction, and two numbers three rows apart are a juxtaposition,
## not a statement. So it goes beside the card, in the column the milestone ribbon
## opened; the constants block above carries that argument and the measurement that
## ruled out the strip under the legend.
##
## LENGTH is the constraint out there, and it is a height rather than a width: the
## box is 308px of text at font 13 in a 68px-tall well, the sentence wraps, and the
## worst case — a road that grew to four digits, every cell of it aimed at, every
## bed lost untouched — is 110 characters. How many lines that comes to is a
## question about the resolved theme font and is therefore measured rather than
## counted here: `get_visible_line_count() == get_line_count()`, which is a wrapped
## Label's own report of whether it lost lines off the bottom. NOT `_T.text_width`,
## which measures the unwrapped string and cannot see a wrap at all, and not
## `get_minimum_size()`, which is the wrong answer on every Label this screen draws.
##
## THREE SILENCES, and each is a different run rather than a defensive default:
##
##   - `road_cells <= 0`: the stats Dictionary was not handed the coverage. That is
##     a card built by a test, or by a `Game` that predates the wiring — and the
##     honest output for "nobody told me" is nothing, never a fabricated 0 of 0.
##   - `aimed <= 0`: nothing in the garden could touch any road. Real, and the
##     opposite lesson: there is no covered ground for "covered" to contrast with,
##     and a player with no garden is not being taught a targeting rule.
##   - `untouched <= 0` (or no escape was readable at all): every pest that got out
##     had been fought, so the mechanic did not bite this run. Same rule as
##     `map_legend_text`'s empty branch — a caption for something that did not
##     happen is worse than no caption.
func reach_note_text() -> String:
	var total: int = int(_stats.get("road_cells", 0))
	if total <= 0:
		return ""
	var aimed: int = clampi(int(_stats.get("road_aimed", 0)), 0, total)
	if aimed <= 0:
		return ""
	if int(_stats.get("escapes_recorded", 0)) <= 0:
		return ""
	var untouched: int = int(_stats.get("escapes_untouched", 0))
	if untouched <= 0:
		return ""
	return ("%d of %d road cells were aimed at, and %d still walked in untouched"
		+ " — a cob fires at the furthest pest only.") % [aimed, total, untouched]


## The ids this run earned for the first time, as `Game._end_run` filed them.
##
## Read through a method rather than inline so the whole ribbon — height, contents
## and whether it exists at all — is assertable off a plain stats Dictionary with
## no Control built, the same way summary_rows() is.
func new_milestones() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in (_stats.get("new_milestones", []) as Array):
		var text: String = String(id)
		if not text.is_empty():
			out.append(text)
	return out


## The node-name suffix and id for the first-record row. Not a milestone id and
## deliberately not in `Milestones.TABLE` — it is not a thing the shelf can display,
## because the shelf's rows are the fixed achievement list and this is a fact about a
## number. See `ribbon_entries`.
const FIRST_RECORD_ID := "first_record"


## EVERY row the ribbon draws — milestones, plus the first record when there is one
## (plant-tower-defense-q8db).
##
## The bead asked what a FIRST record should get instead of the roll a later one gets,
## and the answer was already on this card: the ribbon's heading is literally "First
## time", it is drawn in GOLD because gold is the colour this game spends on "something
## you got", and it is the one surface here that exists to say *this run did a thing for
## the first time ever*. A garden's first recorded score is exactly that and was the only
## such event not listed on it.
##
## So a first record is not celebrated with a bigger number or a louder colour — it is
## admitted to the list of firsts, which is the treatment the card already reserves for
## them. That also fixes the ordering complaint directly: a later record gets a roll on
## the title screen and one subheading, a first record gets a subheading that names it
## as a first AND a gold ribbon row. More, not less.
##
## FIRST IN THE LIST, above the milestones. When a run earns both, the record is the
## rarer event — a garden opens its record book once, and can clear the campaign in any
## run that reaches the end.
##
## The row is synthesised rather than looked up because there is no table to look it up
## in, and adding one to `Milestones.TABLE` would put a score on the achievement shelf
## and break the shelf's earned count, which is deliberately taken off TABLE
## (`notebook_screen.gd:650`) so a foreign id cannot push the total past its rows.
func ribbon_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if first_record():
		out.append({
			"id": FIRST_RECORD_ID,
			"title": "The record book opens",
			# The number is in the row because the row is the only place it is a
			# FIRST. The subheading says the same seeds as a total; here it is the
			# score the garden will be measured against from now on.
			"note": ("%d seeds — the first score this garden has kept"
				% int(_stats.get("seeds_earned_total", 0))),
		})
	for id: String in new_milestones():
		out.append({
			"id": id,
			"title": Milestones.title_of(id),
			"note": Milestones.note_of(id),
		})
	return out


## How tall the ribbon is for `count` entries. A function rather than a literal
## because the count is a runtime number and the clearance test has to be able to
## ask about the worst case without staging a run that earns it.
##
## THE WORST CASE IS `Milestones.TABLE.size() + 1`, not TABLE.size(), since
## plant-tower-defense-q8db: `ribbon_entries()` prepends a first-record row, so the
## tallest ribbon is every milestone at once on the run that also opened the record
## book. `RunSummary.worst_ribbon_rows()` is that number — use it rather than
## `Milestones.TABLE.size()`, which now understates the ribbon by one row and will
## therefore measure a case that is not the worst one.
static func ribbon_height(count: int) -> float:
	if count <= 0:
		return 0.0
	return (RIBBON_PAD + RIBBON_HEADING_HEIGHT + RIBBON_HEADING_GAP
		+ float(count) * RIBBON_ROW_HEIGHT + RIBBON_PAD)


## The most rows the ribbon can ever hold: every achievement in `Milestones.TABLE`, plus
## the one synthesised row `ribbon_entries()` puts above them on a first record.
##
## Derived rather than written as 8, for the reason `shelf_capacity()` is derived rather
## than written as 7: the number moves when the table does, and the person who appends a
## milestone is not going to come back here and redo the arithmetic. Anything asking
## "does the tallest ribbon still clear the map legend" must ask THIS, because the
## honest worst case grew by a row and a test still measuring `Milestones.TABLE.size()`
## now passes on a ribbon 40px shorter than the one the game can draw.
static func worst_ribbon_rows() -> int:
	return Milestones.TABLE.size() + 1


func _build_milestone_ribbon() -> void:
	var earned: Array[Dictionary] = ribbon_entries()
	if earned.is_empty():
		return

	var panel := Panel.new()
	panel.name = "MilestoneRibbon"
	panel.position = Vector2(RIBBON_X, RIBBON_TOP)
	panel.size = Vector2(RIBBON_WIDTH, ribbon_height(earned.size()))
	panel.add_theme_stylebox_override("panel", _ribbon_box())
	# The backdrop is what stops clicks reaching the live side panel; nothing in
	# this ribbon may become the thing that eats one on the way there.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var heading := Label.new()
	heading.name = "MilestoneHeading"
	# Plural-agnostic on purpose: "1 first" and "3 firsts" both need a branch, and
	# a heading that names the count at all invites a test asserting the count off
	# the string instead of off the rows.
	heading.text = "First time"
	heading.position = Vector2(RIBBON_PAD, RIBBON_PAD)
	heading.size = Vector2(RIBBON_WIDTH - RIBBON_PAD * 2.0, RIBBON_HEADING_HEIGHT)
	heading.add_theme_font_size_override("font_size", RIBBON_HEADING_FONT_SIZE)
	heading.add_theme_color_override("font_color", GardenTheme.GOLD)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(heading)

	var y: float = RIBBON_PAD + RIBBON_HEADING_HEIGHT + RIBBON_HEADING_GAP
	for row: Dictionary in earned:
		var id: String = String(row["id"])
		var title := Label.new()
		title.name = "Milestone_%s" % id
		title.text = String(row["title"])
		title.position = Vector2(RIBBON_PAD, y)
		title.size = Vector2(RIBBON_WIDTH - RIBBON_PAD * 2.0, 22.0)
		title.add_theme_font_size_override("font_size", RIBBON_TITLE_FONT_SIZE)
		# PAPER, not INK: this sits on the INK backdrop, not on the card's paper.
		title.add_theme_color_override("font_color", GardenTheme.PAPER)
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(title)

		var note := Label.new()
		note.name = "MilestoneNote_%s" % id
		note.text = String(row["note"])
		note.position = Vector2(RIBBON_PAD, y + 20.0)
		note.size = Vector2(RIBBON_WIDTH - RIBBON_PAD * 2.0, 18.0)
		note.add_theme_font_size_override("font_size", RIBBON_NOTE_FONT_SIZE)
		note.add_theme_color_override("font_color", Color(GardenTheme.PAPER, 0.62))
		note.clip_text = true
		note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(note)

		y += RIBBON_ROW_HEIGHT


## Deliberately not GardenTheme.paper_panel(). That is the card's stock, and a
## second slab of the same cream beside it reads as a piece of the card that fell
## off. This is ink with a gold edge — the colour the game already spends on
## compost and on button focus, which is to say on "something you got".
func _ribbon_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(GardenTheme.INK, 0.9)
	box.set_corner_radius_all(10)
	box.set_border_width_all(GardenTheme.BORDER)
	box.border_color = GardenTheme.GOLD
	return box


func _build_map_legend() -> void:
	var text: String = map_legend_text()
	# No node at all rather than an empty one: a zero-content Label here is what
	# validate-ui reports as an offscreen/zero-size Control finding, and a run with
	# nothing painted has nothing to say.
	if text.is_empty():
		return
	var legend := Label.new()
	legend.name = "MapLegend"
	legend.text = text
	legend.position = Vector2(0.0, MAP_LEGEND_Y)
	legend.size = Vector2(float(MAP_LEGEND_WIDTH), MAP_LEGEND_HEIGHT)
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# The backdrop already stops every click; this label must not become the thing
	# that eats one on its way there.
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_theme_font_size_override("font_size", MAP_LEGEND_FONT_SIZE)
	# PAPER, not INK: this one sits on the INK backdrop over dark road, not on the
	# card's paper, and it is the only text on the screen that does.
	legend.add_theme_color_override("font_color", Color(GardenTheme.PAPER, 0.82))
	add_child(legend)


## Where the note's box starts, for a ribbon carrying `milestone_count` entries.
##
## A function rather than a constant for the same reason `ribbon_height` is one: the
## count is a runtime number, and the clearance test has to be able to ask about the
## worst case — every milestone in `Milestones.TABLE` at once — without staging a run
## that earns them.
static func reach_note_top(milestone_count: int) -> float:
	var above: float = ribbon_height(milestone_count)
	if above <= 0.0:
		return RIBBON_TOP
	return RIBBON_TOP + above + REACH_NOTE_GAP


## Same no-node-at-all rule as the legend: an empty Panel here is exactly what
## validate-ui reports as a zero-content Control, and most runs have nothing to say
## on this subject — see the three silences on reach_note_text().
##
## AUTOWRAP, which is the one thing on this screen that is not clipped. Every value
## Label on the card sets `clip_text` so a width regression shows as a trimmed row;
## this is prose in a fixed box, where the same policy would silently delete the end
## of the sentence — and the end of this sentence is the half that names the rule.
## Wrapped, an over-long string overflows the box downward where the test can see it
## as `get_visible_line_count() < get_line_count()`.
##
## OVERLAY_GRAMMAR's two-channel rule is satisfied trivially and deliberately: this
## is plain prose, nothing in it means one thing in one colour and another in
## another, and it reads identically with every colour on the screen discarded.
func _build_reach_note() -> void:
	var text: String = reach_note_text()
	if text.is_empty():
		return

	var panel := Panel.new()
	panel.name = "ReachNote"
	# ribbon_entries(), not new_milestones(): the first-record row is a row the note
	# has to clear like any other, and reading the shorter list here would slide the
	# note up under the ribbon on exactly the run this cycle added a row for.
	panel.position = Vector2(RIBBON_X, reach_note_top(ribbon_entries().size()))
	panel.size = Vector2(RIBBON_WIDTH, REACH_NOTE_HEIGHT)
	panel.add_theme_stylebox_override("panel", _note_box())
	# The backdrop is what stops clicks reaching the live side panel underneath;
	# nothing added out here may become the thing that eats one on the way there.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var note := Label.new()
	note.name = "ReachNoteText"
	note.text = text
	note.position = Vector2(REACH_NOTE_PAD, REACH_NOTE_PAD)
	note.size = Vector2(RIBBON_WIDTH - REACH_NOTE_PAD * 2.0,
		REACH_NOTE_HEIGHT - REACH_NOTE_PAD * 2.0)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_theme_font_size_override("font_size", REACH_NOTE_FONT_SIZE)
	# PAPER, like the legend and the ribbon: this sits on ink, not on the card's
	# paper, and it is the only prose on the screen that is neither.
	note.add_theme_color_override("font_color", Color(GardenTheme.PAPER, 0.86))
	panel.add_child(note)


## The ribbon's ink without the ribbon's gold. `_ribbon_box` spends GOLD because a
## milestone is something the player earned; this box says the opposite kind of
## thing, and wearing the same edge would file it under the same heading.
func _note_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(GardenTheme.INK, 0.9)
	box.set_corner_radius_all(10)
	box.set_border_width_all(GardenTheme.BORDER)
	box.border_color = Color(GardenTheme.PAPER, 0.28)
	return box


func _build_rows() -> void:
	var y: float = FIRST_ROW_Y
	for row: Array in summary_rows():
		var key := Label.new()
		key.name = "Row_%s" % String(row[0]).replace(" ", "")
		key.text = String(row[0])
		key.position = Vector2(CARD.position.x + ROW_INSET, y)
		key.size = Vector2(CARD.size.x * 0.42, ROW_HEIGHT)
		key.add_theme_font_size_override("font_size", 17)
		key.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.62))
		add_child(key)

		var value := Label.new()
		value.name = "Value_%s" % String(row[0]).replace(" ", "")
		value.text = String(row[1])
		value.position = Vector2(CARD.position.x + CARD.size.x * 0.42, y)
		value.size = Vector2(CARD.size.x * 0.58 - ROW_INSET, ROW_HEIGHT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_font_size_override("font_size", 17)
		value.add_theme_color_override("font_color", GardenTheme.INK)
		# The stopping-point row is the longest and the one that used to get
		# ellipsised out of existence in the HUD message line. Clip rather than
		# overflow, so a regression shows as a trimmed row and not as text
		# running off the paper.
		value.clip_text = true
		value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		add_child(value)

		_rows.append(value)
		y += ROW_HEIGHT + ROW_GAP


func _build_buttons() -> void:
	var replay := Button.new()
	replay.name = "ReplayButton"
	replay.text = "Plant another garden"
	replay.position = Vector2(CARD.position.x + ROW_INSET, BUTTON_Y)
	replay.size = BUTTON_SIZE
	replay.pressed.connect(func() -> void: replay_requested.emit())
	add_child(replay)

	var gate := Button.new()
	gate.name = "GateButton"
	gate.text = "Back to the gate"
	gate.position = Vector2(CARD.position.x + CARD.size.x - ROW_INSET - BUTTON_SIZE.x, BUTTON_Y)
	gate.size = BUTTON_SIZE
	gate.pressed.connect(func() -> void: gate_requested.emit())
	add_child(gate)

	# Restarting was previously an undocumented R keypress that nothing on screen
	# ever mentioned. It still works; now there is also a button, and this says so.
	var hint := Label.new()
	hint.name = "KeyHint"
	hint.text = "or press R"
	hint.position = Vector2(CARD.position.x, BUTTON_Y + BUTTON_SIZE.y + 6.0)
	hint.size = Vector2(CARD.size.x, 20.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(GardenTheme.INK, 0.45))
	add_child(hint)

	replay.grab_focus()


func _play_entrance() -> void:
	var won: bool = bool(_stats.get("victory", false))
	var offset: float = RISE_OFFSET_WIN if won else RISE_OFFSET_LOSS
	var seconds: float = RISE_SECONDS_WIN if won else RISE_SECONDS_LOSS
	var trans: Tween.TransitionType = Tween.TRANS_BACK if won else Tween.TRANS_CUBIC
	for child: Node in get_children():
		var control := child as Control
		if control == null or control.name == "Backdrop":
			continue
		control.position.y += offset
		var tween := create_tween()
		tween.set_trans(trans).set_ease(Tween.EASE_OUT)
		tween.tween_property(control, "position:y", control.position.y - offset, seconds)


## The DESIGN size, deliberately, and this card is the one place that reading it is still
## the right answer rather than a leftover.
##
## `plant-tower-defense-nrup` collapsed eight copies of this pair into `ScreenMetrics`.
## Seven of them wanted the LIVE canvas and were silently reading the setting; this one is
## a fixed-size composition drawn over a held board, so its own geometry is a statement
## about the canvas it was composed on. Named through `ScreenMetrics.design_*` now, so the
## question it is asking is legible instead of inferable from a settings key.
##
## What is NOT done here, and is filed rather than hidden: the card does not yet re-centre
## on a wider window, the way `PauseScreen` now does. That is the same rigid translation,
## not a live number per constant — see the follow-up bead.
func _viewport_width() -> int:
	return ScreenMetrics.design_width()


func _viewport_height() -> int:
	return ScreenMetrics.design_height()
