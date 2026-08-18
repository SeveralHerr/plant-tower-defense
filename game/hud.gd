class_name Hud
extends CanvasLayer

## Everything the player reads or clicks. Built in code rather than as a .tscn so
## the layout numbers sit next to the board's own constants and cannot drift apart
## silently.
##
## Node names are part of the contract: the devtools bridge presses these buttons
## by path (`press --node .../PlantBar/Button_corn_cobbler`), so renaming one
## breaks a test rather than nothing.

signal plant_selected(id: StringName)
signal packet_requested(tier: StringName)

## The cursor arrived on (or left, with &"") a plant's shop entry. Hover and not
## press, for the reason _on_packet_hover already gives: "where would this plant be
## useless" is a question asked BEFORE buying, and a cue you only get by spending
## seeds is not a cue. Fires on a DISABLED button too, which is the case that
## matters most -- a plant you have not unlocked is exactly the one you are pricing
## up (plant-tower-defense-tzz7).
signal plant_hovered(id: StringName)
signal next_wave_requested
signal upgrade_requested
signal uproot_requested

## The player asked the garden to run at a different speed. `Game` owns the
## clock; the HUD only reports the press, exactly as it does for the wave.
signal speed_requested

const BAR_HEIGHT: int = 72
const PANEL_WIDTH: int = 256

## Horizontal gap between the readouts in the top row.
##
## Trimmed from 14 (plant-tower-defense-73y): the four separations funded most
## of the redistribution below without touching a single readout's clip
## budget downward. Still a clearly visible gap at four labels plus a button —
## nothing here reads as cramped, and `cmd budgets`' hud_stats_row entry is the
## check that says so if a future pass disagrees.
const STATS_SEPARATION: int = 10

## Level 1 is wave 1 by definition, and a player does not need telling that
## wave 1 is as hard as wave 1.
const THREAT_SHOW_FROM: int = 2
## The wave button never shrinks below this, however long the readouts get.
## The 40px height is a floor, not a preference: `findings` raises
## `Interactive control ... below minimum 40x40` under it, and it was right to
## when a first pass at this layout trimmed the button to 34 to make the rows
## fit. The rows had to give instead.
##
## The width is 120 measured + the same flat +10px margin every readout above
## carries. It was 216 for "Grow the next wave", which measured 202 and left the
## button 14px of its own slot -- the row's tightest element by far, and the only
## discretionary number in `stats_row_budget`. The speed toggle
## (plant-tower-defense-03t6) needed 67px the row did not have, so the label
## shortened to "Next wave" rather than the readouts giving up the +10 margin
## they were re-proportioned to carry (plant-tower-defense-73y). Net effect: the
## row's headroom went UP, 19px to 38, while gaining a control.
const NEXT_WAVE_BUTTON_SIZE := Vector2(130, 40)

## Every readout gets a clipped width budget, so the row can never overflow
## however long a counter grows. They are listed together because what matters
## is the SUM: these plus the separations plus the button must stay inside the
## bar, and that is the invariant `test_the_stats_row_budget_fits_the_bar`
## pins. The wave slot is the widest because it carries the threat level too.
##
## Measured, not guessed. In the real theme font the worst-case strings need
## 161 / 302 / 136 / 188. The previous pass gave each of these its requirement
## plus about seven pixels and left the row itself eight — both `cmd budgets`
## entries "tight" by the verb's own <15% threshold, and coupled: any one
## readout's slack is paid out of the row's, so a lopsided +7/+8/+8/+8 spent
## almost all of it while still leaving Seeds the single tightest number in
## the whole table (plant-tower-defense-73y).
##
## Re-proportioned to one flat number instead: every readout now carries the
## SAME +10px margin, funded by trimming STATS_SEPARATION rather than by
## taking room back from any label (a redistribution that improved one budget
## by shrinking another would not be a fix, just a different tight spot). The
## row's own headroom nearly triples, 8px to 19, and Seeds — the readout that
## started this — gains 3px it did not have before.
## The stats row's font sizes, hoisted out of the readout table below so a budget
## measured against one cannot be measured at a different one.
##
## THREE sizes now, not two, and the ladder IS the row's hierarchy rather than a set of
## separate preferences. Until plant-tower-defense-6tmf the row ran 26/26/26/20 — four
## strings of near-identical weight on one flat slab, so a player scanning for the
## number that changed had nothing to land on.
##
## Size is the cheapest channel available here, and cheap in the one sense this row
## cares about: a step DOWN spends no width at all. Every readout is clipped to a slot
## that was measured at the larger size (`_add_stat`), so shrinking a readout can only
## leave it more room than it had, never less.
const STAT_FONT_SIZE: int = 26
## The wave readout takes the middle rung, and it is the one of the four that can
## afford to. It is by far the most redundantly announced thing in this game: the wave
## banner names it, the prep note names it again, the prep strip times it, and this
## readout itself carries the live threat tint. Nothing else in the row is said four
## ways.
##
## The slot stays 312px on purpose — see STAT_READOUTS' `width` column. At 24px the
## declared worst case draws ~279 rather than ~302, so the wave readout now sits on
## ~33px of internal headroom instead of ~10. That headroom is NOT reclaimed into the
## row's own 19px of slack in this pass: doing so means retyping a measured constant
## against a font measurement nobody has taken, and an over-tight slot fails silently
## by clipping. Reclaiming it is a measurement, not an edit.
const WAVE_FONT_SIZE: int = 24
## Compost is the smallest, and it is the one stat that is not a resource you spend.
## `_make_label` sets VERTICAL_ALIGNMENT_CENTER so the 20px text still sits on the same
## baseline as the 26px text beside it.
const COMPOST_FONT_SIZE: int = 20

## The stroke weight a readout is drawn at: a font OUTLINE in the label's own colour,
## so the glyphs thicken rather than gain a halo. This is the second half of the
## hierarchy above, and it exists because size alone cannot separate the two readouts
## that both have to stay at full size.
##
## Why an outline rather than a bold face: this project ships one font, so a bold
## variant would be a new asset. An outline is a theme constant on a Label — no asset,
## and, the part that actually decides it, NO WIDTH. Layout in this row comes from
## `custom_minimum_size` (every readout sets `clip_text`), so an outline changes what
## is drawn and not what is measured.
##
## What it does change is how far the drawn glyphs REACH: a weight of N puts N px
## either side of the text. That is why the worst-case guard in `test_placement.gd`
## measures `worst_case + 2 * weight` against the slot rather than the bare string —
## `test_no_readout_clips_its_own_worst_case` and `cmd budgets` both measure the string
## alone and would not see an outline pushing a full-width readout into its ellipsis.
const READOUT_WEIGHT_HEAVY: int = 2
const READOUT_WEIGHT_MEDIUM: int = 1
const READOUT_WEIGHT_PLAIN: int = 0

## THE FOUR READOUTS, and the only place any one of them is described.
##
## This was THREE hand-lists of the same four names: a `WORST_CASE_TEXT` dictionary,
## four `SEEDS`/`WAVE`/`LIVES`/`COMPOST_LABEL_WIDTH` constants that
## `stats_row_budget()` summed, and four `_add_stat()` calls in `_build_top_bar`. Nothing tied
## any pair of them together until cycle 51 bolted two equality assertions across the
## gaps, and both gaps were real: a readout could be added to the row and be invisible
## to the worst-case table, or declared there and invisible to the width sum. One
## table removes the class rather than the two instances -- `_build_top_bar` lays it out
## by walking this, `stats_row_budget()` sums these same rows, and `WORST_CASE_TEXT`
## below is a projection of it, so a fifth readout is one entry and cannot be
## half-added.
##
## THE COLUMNS, and why each is a column rather than a constant somewhere else:
##
##   name        the Label's node name. Part of the contract -- the devtools bridge
##               reads these by path -- and the key both `WORST_CASE_TEXT` and the
##               `hud_readouts` budget are written against.
##   member      the `_x_label` field the rest of this file reads. Assigned through
##               `set()` in `_build_top_bar` so this table stays the only enumeration
##               four; four hand-written assignments after the loop would just be a
##               new third list wearing different clothes.
##   width       the clipped slot in px, from the block above.
##   font_size   One of the three sizes above. Carried per row because the difference
##               IS information: a table that dropped it would be three lists collapsed
##               into one plus an exception.
##   weight      The stroke weight, as a font outline in the row's own colour. The other
##               half of the same information, and a separate column rather than a
##               function of `font_size` because two readouts share a size and must not
##               share a treatment. See READOUT_WEIGHT_HEAVY.
##   colour      PAPER for the three resources, COMPOST for the gold one. The wave
##               readout's is also its ramp's base -- `threat_color_on` returns PAPER
##               below THREAT_SHOW_FROM and `_ease_threat_tint` eases from there
##               toward the warm/hot stops (and their colourblind-safe twins).
##   worst_case  the longest string this readout can ever hold, and the value
##               `WORST_CASE_TEXT` projects out.
##   shapes      every format string the code assigns to this readout -- base branches
##               and `+=` suffixes alike. `tools/readout_shape_check.py` ties this
##               column to the real `_x_label.text =` assignments in BOTH directions.
##               It exists because `worst_case` structurally cannot: one string is an
##               instance of exactly ONE branch, and the wave readout has two.
##
## THE HIERARCHY, and how it is ranked (plant-tower-defense-6tmf). These are four
## different kinds of thing — a currency you spend, a clock you cannot stop, a life
## total, a bankable surplus — and until this pass they were four near-identical
## strings. `font_size` x `weight` now gives each of them its own treatment:
##
##   Garden   26 / heavy    The only readout whose change cannot be undone, and the
##                          rarest to change. It has to catch an eye that is on the
##                          board, so it is the one the row shouts with.
##   Seeds    26 / medium   The number every decision is priced against, and the one
##                          scanned most often. It needs LEGIBILITY, not alarm.
##   Wave     24 / plain    A clock. It owns a channel none of the others has — the
##                          live threat tint — and it is announced three further ways
##                          (banner, prep note, prep strip), so it gives up a rung.
##   Compost  20 / plain    A surplus that can wait, and the row's pre-existing step
##                          down. Gold, and the only readout that is.
##
## **No two rows share a `(font_size, weight)` pair**, which is the property that makes
## this a hierarchy rather than four settings; `test_placement.gd` asserts it off this
## table rather than against a hand-list, so a fifth readout that copied an existing
## treatment fails instead of quietly rejoining the undifferentiated line.
##
## Both channels survive the colour being thrown away — required here, not optional:
## `game/OVERLAY_GRAMMAR.md`'s two-channel rule is project-wide, and the wave readout's
## tint is precisely the channel a greyscale reader loses.
const STAT_READOUTS: Array[Dictionary] = [
	{
		"name": "SeedsLabel",
		"member": "_seeds_label",
		"width": 171.0,
		"font_size": STAT_FONT_SIZE,
		"weight": READOUT_WEIGHT_MEDIUM,
		"colour": PAPER,
		"worst_case": "Seeds  99999",
		"shapes": ["Seeds  %d"],
	},
	{
		# Weather is deliberately NOT a fifth readout, and the number is why: the base
		# string measures 302px in a 312px slot, so the tightest tag that could carry
		# a weather state -- a bare "*" -- needs 317. Every option overflowed, which
		# is the budget system saying the top bar is not weather's home. See
		# plant-tower-defense-saaw.
		#
		# TWO base shapes and one worst case, which is the thing `shapes` exists to
		# say out loud. "Wave  %d / %d" is the fixed campaign, bounded by
		# WaveDirector.WAVES at 22 waves with a single-digit threat level there; the
		# endless branch spends four digits on the wave and two on the threat, so it
		# is the wider of the two. That was an unwritten assumption until cycle 108 --
		# the declared worst case was one string somebody wrote out, and nothing tied
		# it to the branches the formatter can actually build.
		"name": "WaveLabel",
		"member": "_wave_label",
		"width": 312.0,
		"font_size": WAVE_FONT_SIZE,
		# Plain on purpose, and it is the one row where that is a constraint rather than
		# a choice: this label's colour is rewritten every frame of a threat ease, and an
		# outline is drawn in a colour of its own. `_ease_threat_tint` keeps the two in
		# step so a future weight here cannot strand a cream outline on a red number --
		# but the cheapest way to be sure is to spend a different channel, and the tint
		# already IS this readout's channel.
		"weight": READOUT_WEIGHT_PLAIN,
		"colour": PAPER,
		"worst_case": "Wave  9999 ∞   threat 99",
		"shapes": ["Wave  %d ∞", "Wave  %d / %d", "   threat %d"],
	},
	{
		"name": "LivesLabel",
		"member": "_lives_label",
		"width": 146.0,
		"font_size": STAT_FONT_SIZE,
		"weight": READOUT_WEIGHT_HEAVY,
		"colour": PAPER,
		"worst_case": "Garden  10",
		"shapes": ["Garden  %d"],
	},
	{
		# The husk suffix is part of the worst case, not an extra on top of it.
		# Leaving it out is what let a clipped readout ship: the table declared only
		# "Compost  9999" while the formatter appended "  +N", and the width test has
		# only ever measured the string the table names.
		"name": "CompostLabel",
		"member": "_compost_label",
		"width": 198.0,
		"font_size": COMPOST_FONT_SIZE,
		"weight": READOUT_WEIGHT_PLAIN,
		"colour": COMPOST,
		"worst_case": "Compost  9999  +99",
		"shapes": ["Compost  %d", "  +%d"],
	},
]

## The longest string each readout can ever hold, keyed by node name. Budgets are only
## meaningful against these, and a clipped Label fails *silently* -- it just renders
## "Seeds  4..." and nothing complains, which is exactly how the first pass at these
## numbers shipped a 130px seeds slot that could not hold a 3-digit total.
## `test_no_readout_clips_its_own_worst_case` measures each of these against its
## budget in the real theme font.
##
## A PROJECTION of STAT_READOUTS, not a table of its own. `Game`'s `hud_readouts`
## budget, the `budgets` verb and three tests are all written against this shape and
## there is no reason to make them walk a seven-column row to reach one cell. A
## `static var` rather than a `const` because a const cannot be computed: it is filled
## once when the script loads, and the payoff is that it cannot disagree with the rows
## it describes.
static var WORST_CASE_TEXT: Dictionary = _worst_case_text()

## The top bar's page rules: the notebook's own ruled lines, drawn on the ink band.
##
## The bar was a flat slab of INK with four default-font Labels on it — the one
## surface in the game carrying none of the paper the playfield, the packets, the
## pause card and the notebook are all drawn on. These marks are the cheapest way
## back into that language, and they are cheap in the sense that matters here:
## **they cost the stats row no width at all.** The row has ~19px of slack in a
## budget (`stats_row_budget`) that has already had one occlusion bug, so anything
## that took a slot in it would be spending the last of that.
##
## Both are drawn as `ColorRect`s, and that is a test fact as much as a drawing
## one: the suite's `_hud_rects` skips Containers and ColorRects, so decoration
## added this way cannot make the top bar's pair-overlap checks report a collision
## between two things that were never laid out against each other.
##
## PAPER_RULE, not a new shade — it is literally the blue of the ruled lines on the
## notebook stock in image1-image6, already declared in GardenTheme and already
## drawn on the notebook page. `separation(PAPER_RULE, INK)` is 0.56, four and a
## half times the palette's own legibility floor.
const MARGIN_RULE_X: float = 12.0
const MARGIN_RULE_WIDTH: float = 2.0
## The rule under each readout, anchored to that readout's own bottom edge. Washed
## back because it is the paper the number is written on, not a second reading:
## at full strength four of them across the bar compete with the readouts they are
## supposed to be under.
const READOUT_RULE_HEIGHT: float = 2.0
const READOUT_RULE_ALPHA: float = 0.45

## The bar is two rows. Keeping them as named constants is what makes the gap
## between them checkable instead of implied by four scattered literals.
const STATS_ROW_Y: float = 4.0
const STATS_ROW_HEIGHT: float = 40.0
const MESSAGE_ROW_Y: float = 47.0
const MESSAGE_ROW_HEIGHT: float = 20.0

## The page margin either side of the top row. It was the literal `20` in the
## row's x and the literal `40` in its width, which is the same number written
## twice with nothing saying so -- and it is a term in `min_viewport_width()`,
## so it had to become a name before that arithmetic could be checked.
const STATS_ROW_MARGIN: float = 20.0

## How much of the bar's width the message line gives up on the right. Same
## number as the literal `276` it replaces, derived rather than typed: the line
## starts at the page margin and stops where the side panel's column begins, so
## a change to either end moves it instead of leaving it stale.
const MESSAGE_ROW_RIGHT_INSET: float = STATS_ROW_MARGIN + float(PANEL_WIDTH)

## The palette: aliases, not copies. Every value below is declared once, in
## GardenTheme, so the title screen, the Designer's Notebook and the post-mortem
## card can reach the same shades — most of all the red, which is the one colour
## in this game that carries a meaning rather than a mood.
##
## Aliasing the colours is NOT the same as wearing `GardenTheme.build()`, and the
## HUD still refuses that Theme on purpose: it builds and sizes every Control it
## owns in code against the board's own constants, and a Theme applied at the root
## would restyle its Buttons out from under that layout. Sharing a jar of paint,
## not a uniform.
##
## The local names stay because each one says what the colour is *for* here, and
## that is information GardenTheme cannot carry.
const INK := GardenTheme.INK
const PAPER := GardenTheme.PAPER
const PAPER_DARK := GardenTheme.PAPER_DARK
const LEAF := GardenTheme.LEAF
## The top bar's page rules. The notebook stock's own blue ruled line, aliased for
## the same reason every shade above is: one place the value is written down.
##
## Deliberately NOT the notebook's red margin line, which is the other half of that
## stock. GardenTheme's DANGER header says the HUD's one red is UPROOT_ARMED — a
## font colour on a Button, backed by a rewritten label and a sound — and that "a
## red on this screen means this costs you something". A decorative red hairline
## across the top of the HUD would be a second sentence in the same word.
const PAGE_RULE := GardenTheme.PAPER_RULE
## The compost readout, the one stat that is not a resource you spend. It was the
## last inline literal in this file — a hand-typed copy of GardenTheme.GOLD that
## no grep for `const` would ever have found.
const COMPOST := GardenTheme.GOLD
## The one warning red in the HUD: an armed Uproot, and nothing else. The same
## value the in-world health bar draws — `Plant.health_bar_color_on` reads its
## bleeding end straight out of `health_color_on` below rather than keeping a
## third copy — so a red on this screen always means "this costs you something",
## and a player on the safe ramp gets the safe red on all three bars at once.
const UPROOT_ARMED := GardenTheme.DANGER

## The threat ramp on the wave readout. Starts at the bar's own cream so an early
## run looks like nothing is wrong, warms through amber, and ends on the same red
## as UPROOT_ARMED and HEALTH_LOW — every red in this HUD means the same thing,
## and now that is enforced by all three naming one constant rather than by three
## identical literals and a comment asking you to keep them that way.
const THREAT_WARM := GardenTheme.AMBER
const THREAT_HOT := GardenTheme.DANGER
## The same two stops on the colourblind-safe ramp, chosen by
## `RunConfig.colorblind_safe`. See GardenTheme.SAFE_GOOD for why the pair is
## blue/orange and why these two bars are outside the board's solid-vs-broken rule.
const THREAT_WARM_SAFE := GardenTheme.SAFE_MID
const THREAT_HOT_SAFE := GardenTheme.SAFE_BAD
## Threat level at which the tint is fully red.
##
## 12, not the ~25 a long endless run reaches: threat_level is a logarithm, so the
## back half of that range costs hundreds of waves to cross and a ramp stretched
## across it would be indistinguishable from cream for the entire fixed campaign,
## which tops out under 10. Saturating here means the campaign actually uses the
## colour, and endless simply stays pinned at red — which is the correct reading.
const THREAT_TINT_MAX: int = 12

## The prep countdown, drawn as a draining strip along the foot of the top bar.
##
## Not a fifth readout and not text on the wave button: the stats row's budget is
## 815px of labels plus 70px of separations plus a 216px button against a 1112px
## row — eleven pixels of slack — so anything that widens by a character breaks
## `test_the_stats_row_budget_fits_the_bar`. A strip costs no width at all.
##
## It takes the tint of the wave that is *coming*, not the one that just ended, so
## the same colour language answers "how bad" and "how long" at once.
const PREP_BAR_HEIGHT: float = 4.0

## The message row's font size, hoisted out of its one call site so a width measured
## against it cannot be measured at a different one -- the same reason
## STAT_FONT_SIZE exists. test_the_prep_note_says_what_the_next_wave_is_worth
## measures against this, and hardcoding 18 there (a guess) is what prompted it.
const MESSAGE_FONT_SIZE: int = 15

## Below this many seconds left, the strip stops only shrinking and starts
## pulsing too (plant-tower-defense-7mi). PREP_SECONDS is roughly 18-20s of
## calm shrink; the last two are the one stretch of the window where a player
## who has stopped watching the strip most needs it to say so without being
## read.
const PREP_BAR_URGENT_SECONDS: float = 2.0
## Half a pulse cycle -- bright to dim or back. Quick enough to read as urgency
## rather than a slow breathing effect; two full cycles fit inside the last
## two seconds it runs for.
const PREP_BAR_PULSE_SECONDS: float = 0.24
const PREP_BAR_PULSE_DIM: float = 0.45

## How far this wave's stopping depth has to move off the run's average before
## the prep line calls it a change rather than noise.
##
## Five points of a ~40-cell road is two cells. Below that the number wobbles on
## a single pest dying one tile later, and a line that says "deeper" every wave
## says nothing at all. Inside the band the line reports "the run's usual depth",
## which is a genuine reading — "you held where you always hold" is the answer
## that means don't spend — and not a shrug.
const PREP_DEPTH_BAND: float = 0.05

## The longest line `wave_cleared_line(prep_depth_note(...))` can build.
##
## Same contract as WORST_CASE_TEXT above and for the same reason: MessageLabel
## sets clip_text with OVERRUN_TRIM_ELLIPSIS, so a line that outgrows the row
## renders trimmed and nothing complains. "shallower" is the long branch, and it
## cannot co-occur with a 100% reading of its own — being shallower than the run
## requires being under it by the band — so 95 against 100 is the real ceiling
## rather than the 100 against 100 that eyeballing the format string produces.
## `test_the_wave_cleared_line_fits_the_status_row` pins this to the formatters
## themselves rather than trusting the literal.
const PREP_NOTE_WORST_CASE: String = "Wave 9999 cleared. Pests got 95% down the road — shallower than the run's 100%."

## The plant bar's box. It runs from PLANT_BAR_Y down to PLANT_BAR_BOTTOM, which
## is 8px clear of the packet button below it — hard numbers rather than a size
## picked to suit exactly four plants, because the catalogue grows and the bar
## used to be a 240px VBox of 56px buttons that fit four with 8px to spare and
## overlapped the packet button at five.
const PLANT_BAR_Y: float = 44.0
## 260, down from 292, with the separation cut from 8 to 4. A third packet tier
## arrived (SeedBank.PACKET_ORDER) and the 92px between the old bar foot and
## SelectionBox could not hold three 40px buttons — 40 is the touch minimum
## `findings` gates at, so neither the plant buttons nor the packet buttons could
## give up height. The panel is now genuinely full, and the arithmetic is worth
## writing down because the next plant runs into it:
##
##   44 (bar top) + 5*40 (plants) + 3*40 (packets) = 364, against SelectionBox at
##   392. That leaves 28px for seven gaps — four inside the bar, two inside the
##   packet rack, one between them — and this file spends 4/2/4 of it.
##
## THE FIRST THING TRIED WAS TWO COLUMNS, AND IT DOES NOT WORK. `findings` caught
## it live: a plant button's own minimum width is 158px (icon plus the longest
## label), so two of them plus a separation need 324px in a 232px bar. The
## GridContainer does not shrink to fit — it grows, and the whole side panel ran
## 42px past the right edge of the viewport. What paid for the fifth plant instead
## was the button TEXT, which used to be two lines ("Chomp Flower\n15 seeds", 54px
## of intrinsic height) and is now one (31px). See _refresh.
const PLANT_BAR_BOTTOM: float = 260.0
const PLANT_BAR_SEPARATION: int = 4
## Below this a button stops being a touch target; `findings` gates interactive
## Controls at 40x40 and was right to when an earlier pass trimmed one to 34.
const PLANT_BUTTON_MIN_HEIGHT: float = 40.0

## How many plant buttons sit side by side once the catalogue outgrows one column.
##
## Two, and it is bounded by WIDTH rather than by taste: the bar is PANEL_WIDTH - 24 = 232px,
## so two buttons plus a separation give each 114px. A button is an icon at its own height
## plus a price, which measures under that; three columns would give 74px and put the price
## against the icon.
const PLANT_BAR_COLUMNS: int = 2
## Below this many plants the bar stays a single column, because a two-column grid of two or
## three plants reads as a half-empty shelf rather than as a rack. The number is the count
## that filled the old single column exactly.
const PLANT_BAR_SINGLE_COLUMN_MAX: int = 5

## The packet rack: one full-width button per SeedBank.PACKET_ORDER entry, stacked
## between the plant bar and the selection box.
##
## Positions are derived rather than typed out, which they were not before —
## `Vector2(12, 300)` and `Vector2(12, 344)` were two hand-picked numbers, and a
## third tier meant either a third magic number or the discovery that there was no
## room for one. There was no room for one: see PLANT_BAR_BOTTOM for where the
## 128px came from. The rack now foots at 388, four pixels clear of SelectionBox
## at 392, and test_the_packet_rack_fits_between_the_plant_bar_and_the_selection_box
## fails on a fourth tier rather than quietly drawing it under the panel.
const PACKET_ROW_Y: float = 264.0
const PACKET_ROW_HEIGHT: float = 40.0
const PACKET_ROW_PITCH: float = 42.0
## Where the selection panel starts, and therefore the floor the rack must clear.
## Named because two things now depend on it rather than one.
const SELECTION_BOX_Y: float = 392.0

## What a plant button that cannot be bought right now is tinted — locked, or
## unlocked and unaffordable. Extracted from the literal it was, because a second
## reader (plant_button_tint) now has to return exactly the same value the rest
## state has always used.
const PLANT_BUTTON_DIM: Color = Color(1, 1, 1, 0.55)
## And what one lifts to while the cursor is on a packet that could still hand it
## over. Full alpha carries the cue on its own; the warm cast is the second
## channel, matching the seed packet's own paper rather than any threat colour —
## nothing here is a warning.
const PACKET_HINT_TINT: Color = Color(1.0, 0.94, 0.62, 1.0)


## Where the packet button for the `index`th tier sits, in the side panel's own
## space. Pure, so the rack's fit is arithmetic rather than a rendering check.
##
## `index` is the tier's index in SeedBank.PACKET_ORDER and NOT its index among
## the tiers that still have stock — a spent packet keeps its row rather than
## collapsing out of the rack. That was considered and rejected twice over:
##
##   - A rack that reflows mid-run moves the OTHER buttons under a cursor that is
##     already over one. A tier empties on a purchase, which is a click, which is
##     the exact moment the player's pointer is resting on this rack — so the row
##     that slides up under it is the one they are about to click again.
##   - The rows are addressed by position by things that are not the player:
##     test_selftest presses "Root/SidePanel/PacketButton" and the devtools bridge
##     does the same. A rack whose row index depends on run state makes every one
##     of those a different button depending on when it is called.
##
## The information a collapse would have carried is carried by the label instead —
## see packet_button_text. A spent packet reading "Common — Empty" in its own row
## says more than an absent one does, because an absent button cannot explain
## itself.
static func packet_row_rect(index: int) -> Rect2:
	return Rect2(
		Vector2(12.0, PACKET_ROW_Y + PACKET_ROW_PITCH * float(index)),
		Vector2(float(PANEL_WIDTH - 24), PACKET_ROW_HEIGHT))


## The node name a tier's button carries.
##
## The common tier keeps the bare "PacketButton" it has always had, and every
## other tier is "<Tier>PacketButton". That asymmetry is deliberate and is not
## worth tidying: `test_selftest.gd` and the devtools bridge both press these by
## path, so renaming the oldest one to match a scheme would break the callers to
## make a string prettier.
static func packet_button_name(tier: StringName) -> String:
	if tier == &"common":
		return "PacketButton"
	# `.capitalize()` puts a space in front of every word, which is fine for a
	# label and wrong for a node name — a `super_rare` tier would become
	# "Super Rare" and its NodePath would need quoting. Stripped here rather than
	# relied upon not to happen.
	return "%sPacketButton" % String(tier).capitalize().replace(" ", "")


## What a packet button SAYS, given how many plants its tier can still hand over.
##
## Two states, and they are not the same disabled button. `_refresh_packet_button`
## greys a packet for two unrelated reasons — "you cannot afford this yet" and
## "this tier is spent for the rest of the run" — and until this existed the only
## place they differed was `tooltip_text`, which is to say: nowhere a player who
## does not hover ever sees. A wait and a dead end drawn identically teach neither.
##
## So the PRICE SLOT carries the state. A packet you could buy quotes what it will
## charge; a packet with nothing left quotes no number at all, because there is no
## longer a price — the same language the plant buttons already speak (see
## plant_button_label: a number means you may buy it, no number means it is not for
## sale). "Empty" is there because the absence of a number alone is the cue this
## bead was filed against being too quiet.
##
## THE SPENT FORM DROPS THE WORD "Packet", and that is width rather than style.
## The row is 232px (packet_row_rect) and the icon plus the button's margins eat
## roughly 50 of them, leaving ~180px of text. The measured datum for this font is
## `findings`' own button_text_overflow report: "Common (20)", 11 characters, drew
## 99px — about 9px a character. "Common Packet — Empty" is 21 characters, ~189px,
## and would have overflowed the row it was added to fix. "Common — Empty" is 14,
## ~126px, and the packet icon beside it is what still says "packet".
##
## `stock` is packet_pool(tier).size() — derived, never a flag someone has to
## remember to set, so a tier that empties mid-run cannot forget to say so.
static func packet_button_text(tier: StringName, stock: int) -> String:
	var spec: Dictionary = SeedBank.PACKET_TIERS.get(tier, {}) as Dictionary
	if spec.is_empty():
		return ""
	if stock > 0:
		return "%s (%d)" % [String(spec["display"]), int(spec["cost"])]
	# trim_suffix, not a second table of short names: the short form is derived
	# from the display name, so a tier renamed in PACKET_TIERS renames here too,
	# and a display name that never said "Packet" is left exactly as it is.
	return "%s — Empty" % String(spec["display"]).trim_suffix(" Packet")


## The resting tooltip per packet tier, counted from the catalogue rather than
## written out.
##
## It used to be two hard-coded sentences, and the rare one read "the only
## reliable way to a Seed Sunflower" — true when the Sunflower was the only tier-2
## plant, false the moment a fourth plant shipped, and false silently: nothing
## fails when a tooltip stops describing the thing it points at. Naming a specific
## plant is what made it perishable, so this names none.
##
## Derived rather than constant so that adding a plant cannot make it wrong again.
static func packet_tooltip(tier: StringName) -> String:
	var spec: Dictionary = SeedBank.PACKET_TIERS.get(tier, {}) as Dictionary
	if spec.is_empty():
		return ""
	var cap: int = int(spec["max_tier"])
	var within: int = 0
	var beyond: int = 0
	for id: StringName in PlantCatalog.ids():
		if PlantCatalog.tier(id) <= cap:
			within += 1
		else:
			beyond += 1
	if beyond > 0:
		var rarer: String = ("1 rarer seed is out of its reach." if beyond == 1
			else "%d rarer seeds are out of its reach." % beyond)
		return "Holds one seed you do not have yet, from the %d that grow at tier %d or below. %s" % [
			within, cap, rarer,
		]
	return ("Costlier, and the only packet that reaches every seed in the garden — "
		+ "all %d of them, including the %d no cheaper packet can hold.") % [
			within, _plants_above_tier(_best_cap_under(tier)),
		]


static func _plants_above_tier(cap: int) -> int:
	var count: int = 0
	for id: StringName in PlantCatalog.ids():
		if PlantCatalog.tier(id) > cap:
			count += 1
	return count


## The furthest up the catalogue any packet CHEAPER than `tier` can reach.
##
## This used to be the common packet's cap, spelled out, which was the same
## number while common and rare were the only two tiers and stopped being it the
## moment `epic` was added: the sentence would then have counted the three seeds
## a *common* packet cannot hold while claiming they were the ones no cheaper
## packet can, and a Rare Packet holds two of them. Derived from `cost` so a
## re-priced or re-capped tier moves this with it.
##
## 0 when nothing is cheaper — every plant is then above the cap, which is the
## right answer for a configuration with exactly one packet in it.
static func _best_cap_under(tier: StringName) -> int:
	var mine: int = int((SeedBank.PACKET_TIERS[tier] as Dictionary)["cost"])
	var best: int = 0
	for other: StringName in SeedBank.PACKET_ORDER:
		var spec: Dictionary = SeedBank.PACKET_TIERS[other] as Dictionary
		if int(spec["cost"]) >= mine:
			continue
		best = maxi(best, int(spec["max_tier"]))
	return best

## Message priorities. NORMAL is ambient colour — a husk collected, a wave
## cleared. IMPORTANT is anything the player must act on or has just been asked
## to confirm, and it may cut a NORMAL line short.
##
## DEADLINE is not "more important than IMPORTANT" — it is **expires**. A line at
## this rung is describing a window that is already counting down somewhere else
## in the game, so deferring it does not delay the message, it shortens it. There
## is exactly one such line today (the armed-uproot prompt, `game/game.gd:1330`)
## and it is the reason the rung exists: two IMPORTANT lines defer each other for
## up to `5.0 - MESSAGE_MIN_READABLE` seconds, and the prompt's whole window is
## `Game.UPROOT_CONFIRM_SECONDS` = 4.0. Measured in cycle 69 by
## `test_an_armed_prompt_outranks_a_line_that_is_merely_important`, which failed
## against the old priority reading the packet reveal's text.
##
## **Before adding a second DEADLINE producer, note that they cannot defer each
## other either** — two of these on screen at once is a design problem the queue
## cannot solve, because whichever waits is wrong by construction.
const MESSAGE_NORMAL: int = 0
const MESSAGE_IMPORTANT: int = 1
const MESSAGE_DEADLINE: int = 2
## How long a line is guaranteed on screen before an equal-priority one may
## replace it. Roughly the time to read a short sentence.
const MESSAGE_MIN_READABLE: float = 1.2

## WHAT AN IMPORTANT LINE LOOKS LIKE (plant-tower-defense-xvub).
##
## The three rungs above controlled queue PRIORITY and nothing else, so the armed-uproot
## prompt — a four-second irreversible decision — was drawn exactly like "Composted a
## husk for 3 seeds." A player learns to skim a row where most of what appears is
## ambient, and the one line that must be read was styled identically to the ones that
## need not be.
##
## TWO channels, and NEITHER of them is colour. That is `game/OVERLAY_GRAMMAR.md`'s
## two-channel rule, which is project-wide and is this bead's stated acceptance: the
## distinction has to survive the screen being read in greyscale. It is met here in the
## strongest available form — a stressed line and an ambient one are drawn in the SAME
## colour (LEAF), so there is no hue difference to throw away in the first place.
##
##   WEIGHT     the row's own text thickens, drawn as a font outline in the text's own
##              colour. One pixel, not two: the message row is 15px and a 2px outline
##              starts closing the counters of an `e` at that size.
##   A MARK     a solid tick in the page margin beside the line, present for a stressed
##              line and absent for an ambient one. Presence/absence is the cleanest
##              greyscale channel there is, and marking an important line in the margin
##              is what this game's whole notebook idiom already does on paper.
##
## Both are FREE in width, which is the constraint that ruled out the obvious answers.
## The outline changes what is drawn and not what is measured; the mark is a ColorRect
## child of the Label — the same trick `_readout_rule` uses — living in the 6px of
## gutter between MARGIN_RULE_X's rule and the text at STATS_ROW_MARGIN, which is space
## nothing was using. Neither is an option the row's budget could otherwise afford.
##
## Rejected: the bead's third suggestion, a brief HOLD before the queue advances. It is
## the cheapest of the three in pixels and the most expensive in risk — it changes the
## row's timing, which `show_message`, `_queue_message`, `queue_outcome`,
## `line_was_read` and their tests all reason about, to buy a channel the two above
## already carry.
const MESSAGE_STRESS_OUTLINE: int = 1
## The margin tick's box, and where it sits. Anchored to the MessageLabel's left edge
## with NEGATIVE offsets, so it is drawn outside the label's own rect and inside the
## bar: STATS_ROW_MARGIN (20) - GAP (2) - WIDTH (4) puts its left edge at 14, exactly
## where MarginRule's own 12+2 ends. It touches the page rule and never overlaps it.
const MESSAGE_MARK_WIDTH: float = 4.0
const MESSAGE_MARK_GAP: float = 2.0


## Whether a line that has been on the row for `total - left` seconds has had long enough to
## have been read.
##
## Reuses `MESSAGE_MIN_READABLE` rather than inventing a threshold, and the reuse is the
## point: `show_message`'s wait branch already treats that constant as "long enough to have
## been read" when deciding whether an equal-rung arrival may stomp. This is the same
## question asked about the same row, so a second number would be a second opinion.
##
## Static and pure so the rule can be asserted without a live row, and named because it is a
## DECISION -- the pre-empt branch reads it to choose between bringing a displaced line back
## and retiring it, and those are different things to do to a player.
static func line_was_read(total_seconds: float, seconds_left: float) -> bool:
	return (total_seconds - seconds_left) >= MESSAGE_MIN_READABLE
const MESSAGE_QUEUE_MAX: int = 3

## The wave banner. Two events, two named callers, one surface.
##
## This node used to be a generic `show_banner(text)` that the end-of-run screen
## drove; RunSummary replaced that and left the surface with no callers at all.
## It is kept — rather than deleted — because the game has beats the status row
## cannot carry: a wave starting, and — since plant-tower-defense-d2a — a wave
## being survived. Both compete on MessageLabel with husk chatter, refused
## purchases, the uproot confirmation and the mute toggle, in 15px, clipped, on
## a row so oversubscribed it needed a priority queue. Getting through a wave
## intact is at least as loud a beat as one arriving, and was getting the same
## 15px as "Composted a husk for 3 seeds" while the wave that was about to
## attack got a 48px banner and a bell.
##
## The reason this does not become a second oversubscribed channel is the API,
## not the pixels: `announce_wave(number, pests, note)` and
## `announce_wave_cleared(number, pests)` each name their one event. There is
## no generic setter to dump a third kind of line into, and neither event can
## fire more than roughly once every PREP_SECONDS, so the surface can never be
## contended between them — a wave cannot start and clear in the same breath.
## If a third event ever wants a banner, that is a decision to make on purpose —
## it should have to add a method here, not reuse one.
##
## Two Labels rather than one two-line Label. That is a real fix, not a style
## choice: `validate-ui` measures a Label's text as ONE joined line, so the old
## two-line banner reported "text: 1052px, label: 896px" permanently and could
## only be silenced by baselining a genuine-looking finding. Two single-line
## Labels make the check's measurement and the rendered width the same number.
const BANNER_Y: float = 236.0
## 72, not the 62 this was written as. A Label does not render at its declared
## size — a 48px font produces a 67px line box, so the headline ran to y=303 while
## the note, positioned at BANNER_Y + BANNER_HEIGHT, started at 298 and the two
## overlapped by five pixels. Caught by the banner's own occlusion test, which is
## the only kind of check that compares a pair of siblings rather than measuring
## each against its own box.
const BANNER_HEIGHT: float = 72.0
const BANNER_NOTE_HEIGHT: float = 26.0
const BANNER_FONT_SIZE: int = 48
const BANNER_NOTE_FONT_SIZE: int = 20

## Total time a banner is on screen, of which the last BANNER_FADE_SECONDS is
## spent fading. It sits over the board, so it has to leave on its own — the old
## `hide_banner()` had no callers either, which is how a banner shown at wave
## start would have stayed up for the whole wave.
const BANNER_HOLD_SECONDS: float = 2.8
const BANNER_FADE_SECONDS: float = 0.5

## Same contract as WORST_CASE_TEXT above, for the same reason: the banner is a
## fixed-width box whose text is built from runtime numbers, and a Label that
## overruns it fails silently. `test_the_wave_banner_fits_its_own_worst_case`
## measures both of these in the real theme font against the real box.
## "9999 pests" is well past anything a wave produces and every escalation note
## WaveDirector can emit is a subset of "tougher, faster and stranger".
##
## Both rows are shared between announce_wave and announce_wave_cleared now, so
## each entry is the longer of the two events' text rather than either one
## alone. `wave_cleared_headline(9999)` — "Wave 9999 cleared" — is longer than
## `wave_headline(9999)` and is what actually sets Banner's high-water mark;
## `wave_cleared_note(9999)` — "9999 pests turned back." — stays well short of
## the escalation sentence below it, so BannerNote's mark is still set by
## announce_wave's own worst case.
const BANNER_WORST_CASE_TEXT: Dictionary = {
	"Banner": "Wave 9999 cleared",
	"BannerNote": "9999 pests — tougher, faster and stranger than the last",
}

## The selection panel's health bar. Green at full, through amber, to the same
## warning red as UPROOT_ARMED at nearly-dead — so the two reds in the panel mean
## the same thing, and a plant worth replanting says so without being read.
## Motion. Every one of these layers on top of an already-correct final state and
## is gated on GardenTheme.animations_enabled(), because headless pumps no frames:
## a tween that starts a node at alpha 0 and relies on a frame to finish the job
## leaves it invisible, in a way no assertion about size or node paths would catch.
const THREAT_FADE_SECONDS: float = 0.45
const PANEL_RISE: float = 10.0
const PANEL_RISE_SECONDS: float = 0.16

## The readout punch: seeds, lives and compost snapping straight to a new
## number on every change while _ease_threat_tint eases the one label beside
## them. 1.22, not something louder — TitleScreen's ENTRANCE_RISE and
## RunSummary's RISE_OFFSET both keep their motion small, and this row redraws
## far more often than either of those screens builds once, so a punch loud
## enough to notice on its own would be a row that never stops moving.
##
## Scale, not position: these three Labels are direct children of StatsRow, an
## HBoxContainer, and a Container only ever writes its children's `position`
## and `size` during sort — never `scale` or `rotation` — so a scale tween
## survives a refresh() landing mid-punch in a way a position tween would not.
const READOUT_PUNCH_SCALE: float = 1.22
const READOUT_PUNCH_SECONDS: float = 0.16

## THE SEEDS ROLL. The punch above says "this number moved" and stops there, so a
## 45-seed purchase and a 2-seed pest payout look identical: one pop, and a total that
## is simply different afterwards. Seeds is the readout that moves most often in this
## game and the one every decision is priced against, and it was the one number on
## screen with no way to see HOW FAR it went (plant-tower-defense-r3e8).
##
## The pattern is `TitleScreen._arm_record_ratchet`'s, deliberately, down to the rule
## that makes it safe: **the label already holds the final text before the roll runs.**
## Headless pumps no frames, so a tween responsible for ARRIVING at the right value
## leaves the right value unreachable in every test; this one only ever overwrites a
## correct string with an intermediate one and then puts it back.
##
## FASTER AND COARSER THAN THE RECORD'S, and both of those are because of how often it
## fires. The record rolls once, at the end of a run, over 0.8s; this can fire several
## times in a wave, and a roll still running when the next one starts is a readout that
## never settles. 0.35s lands well inside the gap between two pest payouts.
const SEED_ROLL_SECONDS: float = 0.35
## Stepped, not continuous, and this is the half the record ratchet declares
## (`RATCHET_STEPS`) and then does not use. A counter that renders a different four-digit
## number on all 21 frames of a 0.35s roll is noise: nothing is legible, so the roll
## reads as a flicker rather than as travel. Ten stops is what the player actually sees.
const SEED_ROLL_STEPS: int = 10
## Below this the number SNAPS, and the punch alone carries it. Rolling +2 for a pest
## kill would put the busiest readout in the game in permanent motion for a change a
## player can read at a glance — and the roll exists to make a big jump legible, which
## is a claim about big jumps.
##
## 5 is the smallest single seed payout in the game that is worth watching arrive; every
## plant price and every wave bonus clears it by a wide margin.
const SEED_ROLL_MIN_JUMP: int = 5

## The denial shake: rotation, not position. The plant bar's buttons are
## GridContainer children, and a Container's sort pass writes `position` and
## `size` on every child every time it runs — which a refresh() landing mid-shake
## would trigger by simply re-setting a button's own text. `rotation` is never
## touched by a sort pass, on a GridContainer child or the packet buttons' plain
## ColorRect parent alike, so one shake implementation is safe on both.
const DENIAL_SHAKE_SECONDS: float = 0.28
const DENIAL_SHAKE_DEGREES: float = 6.0

const HEALTH_ROW_HEIGHT: float = 14.0
## A wash of the bar's own INK rather than a fifth grey: the alpha is the whole
## difference, so it is derived from the shared value instead of retyping the
## three channels with a 0.35 on the end.
const HEALTH_BACK := Color(GardenTheme.INK, 0.35)
const HEALTH_FULL := GardenTheme.LEAF
const HEALTH_LOW := GardenTheme.DANGER
## And its colourblind-safe counterpart. HEALTH_LOW_SAFE is deliberately the same
## value as THREAT_HOT_SAFE, exactly as HEALTH_LOW is the same value as THREAT_HOT:
## whichever ramp is on, one colour still means "this costs you something".
const HEALTH_FULL_SAFE := GardenTheme.SAFE_GOOD
const HEALTH_LOW_SAFE := GardenTheme.SAFE_BAD

var _seeds_label: Label
var _wave_label: Label
var _lives_label: Label
var _compost_label: Label
var _message_label: Label
## The margin tick beside an important line. See MESSAGE_STRESS_OUTLINE — it is a child
## of `_message_label` so it costs the row nothing and follows the label's rect.
var _message_mark: ColorRect
## A GridContainer, not a VBox: it runs one column until a fifth plant would
## push the buttons under the touch minimum, then two. See plant_bar_layout.
var _plant_bar: GridContainer
## tier -> its Button. A Dictionary rather than one named field per tier, which is
## what the pair of fields here became the moment there were three of them.
var _packet_buttons: Dictionary = {}
var _next_wave_button: Button
var _speed_button: Button
var _selection_box: VBoxContainer
var _selection_label: Label
var _upgrade_button: Button
var _uproot_button: Button
var _health_row: ColorRect
var _health_fill: ColorRect
var _health_text: Label
var _banner: Label
var _banner_note: Label
## Last child of `root`, so anything added here draws over every panel and
## button — where a travelling seed glyph belongs. See fly_seed_glyph().
var _fx_layer: Container

var _plant_buttons: Dictionary = {}
## Which plant button the cursor is on, &"" for none. Needed because two adjacent
## buttons in the GridContainer can fire mouse_exited(A) AFTER mouse_entered(B),
## which with a bare &"" on exit would blank a hover that had just started.
var _hovered_plant: StringName = &""
## The packet tier the cursor is currently resting on, or &"" for none. Drives the
## plant bar's hint tint — see plant_button_tint.
var _packet_hint_tier: StringName = &""
## tier -> the ids that tier could still hand over, snapshotted at the last
## refresh(). A snapshot rather than a live SeedBank reference on purpose: the HUD
## holds no copy of the truth (see refresh's header), and hover is the one event
## that arrives without a state push behind it. Refreshed on every state change,
## which includes every purchase and every unlock, so the snapshot cannot be older
## than the last thing that could have changed it.
var _packet_hint_pools: Dictionary = {}
## id -> the tint that button wears when nothing is being hovered. Written by
## refresh(), read by _apply_plant_hints(), so hover has one job (lift or restore)
## and does not need to re-derive affordability without a bank in hand.
var _plant_rest_tint: Dictionary = {}
var _banner_left: float = 0.0
var _message_left: float = 0.0
## The two claims on the message row, and `_paint_message_row()` is the only thing
## that resolves them onto the Label.
##
## **This is one owner and two claims, and it replaced three writers.** `show_message`,
## `_advance_message_queue` and `_refresh_prep_note` each used to set
## `_message_label.text` directly and each had to answer "is the line currently on the
## row MINE?" -- which they did by comparing the Label's text against what they
## expected to find there. Both of the defects in the standing note were seams between
## those three conventions, and the comparison is wrong on its own terms: a message
## whose text happens to equal the note is indistinguishable from the note.
##
## Now each writer sets its own claim and asks for a repaint. Nothing reads the Label
## to decide what the Label should say.
var _message_text: String = ""
## What the row says when nothing else is speaking. The ONE piece of game state this
## class keeps, and narrowly: a rendered sentence computed from `state` on the last
## refresh, not a copy of `state`. The header's "no second copy of the truth here"
## rule is about the game's numbers, and a rendered line goes stale exactly as fast as
## the row it is written into.
var _idle_message: String = ""
var _message_priority: int = MESSAGE_NORMAL
var _message_queue: Array[Dictionary] = []
var _prep_bar: ColorRect
var _prep_bar_pulse: Tween = null
## Edge-detected rather than re-read from `left` every call: refresh() runs
## every frame while the strip is up, and starting a new kill-and-restart
## tween each of those frames would never let one advance past its first
## step -- the same reason _ease_threat_tint below gates on the target
## actually changing instead of re-tweening to the same colour every call.
var _prep_bar_urgent: bool = false
var _threat_tween: Tween = null
var _threat_tint_target: Color = PAPER

## Label -> its live punch Tween, killed and restarted the same way
## _threat_tween is — a fresh Tween per refresh() would stack dozens of them
## onto one label's scale during a busy wave.
var _readout_tweens: Dictionary = {}
## Control -> its live shake Tween. Same reason as _readout_tweens: a button
## denied twice in quick succession must restart its shake, not race two.
var _shake_tweens: Dictionary = {}
## False until refresh() has run once. Guards the very first call: every
## readout's text goes from "" to its real value on that call, which is the
## screen appearing, not a change the player made — see refresh().
var _readouts_seeded: bool = false
## The seed total the readout was last told to show. The roll needs somewhere to count
## FROM, and the Label's own text is not it: parsing a number back out of "Seeds  120"
## would read whatever intermediate value a roll already in flight had just written.
var _seeds_shown: int = 0
## The live seeds roll, killed and restarted rather than raced — the same rule
## `_readout_tweens` exists for one member up. A second roll armed while the first is
## mid-count would have two tweens writing the same Label from two different `from`s.
var _seeds_roll: Tween

## The three surfaces whose geometry comes from the viewport rather than from a
## constant. Held as members for one reason: `_apply_viewport_layout()` has to be
## able to rewrite them long after `_ready()` returned, and a local `var bar` in
## the builder is unreachable from a signal handler.
var _top_bar: ColorRect
var _stats_row: HBoxContainer
var _side_panel: ColorRect

## The prep strip's width is a FRACTION of the viewport, not a px count, so a
## resize mid-countdown has to re-multiply rather than keep the old pixels.
## Stored here because `_refresh_prep_bar` is driven by `state` and a resize is
## not: without it the strip would freeze at its pre-resize width until the next
## refresh(), which on a paused tree is never.
var _prep_fraction: float = 0.0

## Edge-detected so the warning below fires on the CROSSING, not once per resize
## event -- a window dragged narrower emits `size_changed` every frame.
var _too_narrow: bool = false


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_top_bar(root)
	_build_side_panel(root)
	_build_banner(root)

	# Added last, so its children paint over the panels and buttons above —
	# a travelling glyph hidden behind the side panel would defeat the point.
	#
	# A bare Control here was two contradictory findings at once. Full-rect
	# and zero-size are the only two shapes tried: full-rect reads to
	# _hud_rects (test_selftest.gd) and to a human as a giant pane that
	# "overlaps" every panel and button on the bar, since neither knows this
	# one is never meant to be a surface; zero-size dodges that but then
	# reads to devtools findings' own ui_zero_size check as a visible Control
	# nobody sized — the exact shape of "the game forgot this exists" it is
	# built to catch, without a waiver list to say otherwise.
	#
	# Container (base class, not a layout subclass) is full-rect and passes
	# ui_zero_size, and _hud_rects skips it by class rather than by
	# guessing intent — the same reason it already skips ColorRect. Base
	# Container does no auto-layout of its own; that behaviour belongs to its
	# subclasses (VBoxContainer, GridContainer, ...), so a SeedGlyph's own
	# `position`, set once in SeedGlyph.launch(), is left alone.
	_fx_layer = Container.new()
	_fx_layer.name = "FxLayer"
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fx_layer)

	# The builders above create nodes and set everything that is a CONSTANT. Every
	# number that comes from the viewport is written here instead, once, and again
	# on every resize -- so there is exactly one function to read to know what this
	# HUD does at a different window shape.
	var vp: Viewport = get_viewport()
	if vp != null and not vp.size_changed.is_connected(_apply_viewport_layout):
		vp.size_changed.connect(_apply_viewport_layout)
	_apply_viewport_layout()


## Every size and position on this HUD that depends on the viewport, in one
## place, re-runnable.
##
## This is the fix for plant-tower-defense-0jye. `get_viewport_width()` used to
## name the project SETTING, and every caller believed it named the screen; with
## `stretch/mode=canvas_items` and `stretch/aspect="expand"` the two genuinely
## differ, because `expand` shows MORE canvas on whichever axis the window has
## spare (Godot divides the window size by min(window/base) per axis, so the
## viewport is the base size on the constraining axis and larger on the other).
## A 21:9 window is 1536x648 canvas units, not 1152x648, and every number below
## was stale from the moment the window stopped being 16:9.
##
## Re-derived rather than anchored, deliberately. The top row's widths are a
## budget that has to add up (`stats_row_budget`), the side panel's column is a
## constant the plant bar is sized against, and the banner is centred on the
## board's half rather than the window's -- an anchor preset expresses none of
## that, and a HUD half in anchors and half in arithmetic is worse than either.
## What this HUD needed was not anchors; it was for its arithmetic to be run
## more than once.
func _apply_viewport_layout() -> void:
	# `size_changed` can outlive the build (a viewport resized while this HUD is
	# mid-teardown), so the guard is real rather than defensive dressing. The
	# banner's second row is the LAST thing `_ready()` builds, so it is the one
	# that means "everything below exists".
	if _top_bar == null or _banner_note == null:
		return
	var w: float = float(get_viewport_width())
	var h: float = float(get_viewport_height())

	_top_bar.position = Vector2.ZERO
	_top_bar.size = Vector2(w, float(BAR_HEIGHT))

	_stats_row.position = Vector2(STATS_ROW_MARGIN, STATS_ROW_Y)
	_stats_row.size = Vector2(maxf(0.0, w - STATS_ROW_MARGIN * 2.0), STATS_ROW_HEIGHT)

	_message_label.position = Vector2(STATS_ROW_MARGIN, MESSAGE_ROW_Y)
	_message_label.size = Vector2(maxf(0.0, w - MESSAGE_ROW_RIGHT_INSET), MESSAGE_ROW_HEIGHT)

	_prep_bar.position = Vector2(0.0, float(BAR_HEIGHT) - PREP_BAR_HEIGHT)
	_prep_bar.size = Vector2(w * _prep_fraction, PREP_BAR_HEIGHT)

	_side_panel.position = Vector2(w - float(PANEL_WIDTH), float(BAR_HEIGHT))
	_side_panel.size = Vector2(float(PANEL_WIDTH), maxf(0.0, h - float(BAR_HEIGHT)))

	# The banner spans the board's half of the screen, stopping exactly where the
	# side panel's column starts -- that abutment is what
	# `test_the_wave_banner_shares_no_pixels_with_the_rest_of_the_hud` pins, and
	# it is the one pair on this HUD a resize could push into an overlap.
	var banner_width: float = maxf(0.0, w - float(PANEL_WIDTH))
	_banner.position = Vector2(0.0, BANNER_Y)
	_banner.size = Vector2(banner_width, BANNER_HEIGHT)
	_banner_note.position = Vector2(0.0, BANNER_Y + BANNER_HEIGHT)
	_banner_note.size = Vector2(banner_width, BANNER_NOTE_HEIGHT)

	_report_if_too_narrow(w)


## The top row is the one part of this HUD that a narrow viewport BREAKS rather
## than merely reshapes, and it breaks silently, so it gets said out loud.
##
## `Control.size` is clamped up to `get_combined_minimum_size()`, and an
## HBoxContainer's minimum is the sum of its children. So asking the StatsRow for
## less width than `stats_row_budget()` does not squeeze it -- the assignment
## appears to succeed, the row keeps its full width, and the wave button simply
## ends up past the right edge of the screen with nothing anywhere reporting it.
## That is the exact failure `test_an_absurdly_long_readout_pushes_rather_than_underlaps`
## already caught once at a fixed width; a live viewport is a second way to reach it.
##
## Today it cannot happen: `stretch/aspect="expand"` never yields a canvas
## SMALLER than the design size on either axis, so `design_width()` is the
## narrowest the top row is ever laid out in, and
## `test_the_top_row_fits_the_narrowest_viewport_the_stretch_mode_can_produce`
## is what keeps that true if the aspect setting or the base size ever changes.
## This warning is what a SubViewport-hosted HUD, or that settings change, gets
## instead of a wave button quietly off screen.
func _report_if_too_narrow(width: float) -> void:
	var narrow: bool = stats_row_shortfall_at(width) > 0.0
	if narrow == _too_narrow:
		return
	_too_narrow = narrow
	if narrow:
		push_warning(("Hud: the top row needs %.0fpx of viewport width and has %.0f. "
			+ "The StatsRow will hold its minimum size and the wave button will sit "
			+ "%.0fpx off the right edge.") % [
				min_viewport_width(_stats_row_separations()), width,
				stats_row_shortfall_at(width),
			])


## How many separations the live top row carries -- one fewer than its children,
## which is the argument `stats_row_budget()` actually wants. Read off the row so
## a control added to the bar later is priced without anyone updating a literal.
func _stats_row_separations() -> int:
	if _stats_row == null:
		return 0
	return maxi(0, _stats_row.get_child_count() - 1)


## The narrowest viewport the top row can be laid out in: its contents plus the
## page margin either side. Static and pure so the suite can compare it against
## `design_width()` without building a HUD.
static func min_viewport_width(separations: int) -> float:
	return stats_row_budget(separations) + STATS_ROW_MARGIN * 2.0


## How many px of viewport width the top row is short of at `width`, or 0.0 when
## it fits. The legible form of the silent clamp `_report_if_too_narrow`
## describes -- a number a test can assert instead of a geometry bug to notice.
func stats_row_shortfall_at(width: float) -> float:
	return maxf(0.0, min_viewport_width(_stats_row_separations()) - width)


## The same question about the viewport this HUD is actually in.
func stats_row_shortfall() -> float:
	return stats_row_shortfall_at(float(get_viewport_width()))


## The top row is an HBoxContainer, not four labels at hand-picked x positions.
##
## It used to be the latter, and the counters grow at runtime: once the compost
## readout reached "Compost 0 (11 ready)" it ran underneath the wave button,
## because a Label at a fixed x=760 has no idea a Button starts at x=916. That
## bug also proved the checks cannot catch this shape — `findings` reported
## `0 finding(s) across 5 of 5 checks` over the broken frame, since every
## Control fits its own box and only the *pair* is wrong. So the fix has to be
## a layout that cannot produce the collision, not better numbers.
##
## Two elements do that work: an expanding Spacer that keeps the readouts left
## and the button right, and a clipped width budget on the compost label. The
## budget is not optional — the first version had only the spacer, and an
## over-long counter simply shoved the button 97px off the right edge of the
## bar instead of overlapping it. A collision traded for an off-screen button
## is not a fix; `test_an_absurdly_long_readout_pushes_rather_than_underlaps`
## now pins both halves.
func _build_top_bar(root: Control) -> void:
	# Position and size come from `_apply_viewport_layout()`, here and for every
	# other viewport-derived rect in this file. Written once at the end of
	# `_ready()` and again on every `size_changed`.
	var bar := ColorRect.new()
	bar.name = "TopBar"
	bar.color = INK
	root.add_child(bar)
	_top_bar = bar

	# The page's gutter. It lives in the 20px the StatsRow already leaves empty on
	# the left, so it is drawn in space nothing was using rather than bought out of
	# a budget -- see MARGIN_RULE_X for why that distinction is the whole design of
	# this pass.
	var margin_rule := ColorRect.new()
	margin_rule.name = "MarginRule"
	margin_rule.color = PAGE_RULE
	margin_rule.position = Vector2(MARGIN_RULE_X, 0.0)
	# Stops short of the prep strip rather than running to the bar's foot. Both
	# halves of that are deliberate. Visually the gutter is the page's, not the
	# countdown's. Structurally it is what the occlusion audit asked for: PrepBar
	# is a full-width opaque strip drawn after this one, so a rule running the whole
	# height would share 2x4px with it -- 5.6% of this rule's own area, past the
	# audit's 4% floor -- and be reported as one opaque control covering another.
	# The suite's own `_hud_rects` skips ColorRects and would never have said so.
	margin_rule.size = Vector2(MARGIN_RULE_WIDTH, float(BAR_HEIGHT) - PREP_BAR_HEIGHT)
	margin_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(margin_rule)

	var stats := HBoxContainer.new()
	stats.name = "StatsRow"
	stats.add_theme_constant_override("separation", STATS_SEPARATION)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(stats)
	_stats_row = stats

	# The readouts, laid out by walking STAT_READOUTS rather than by four hand-written
	# calls. That is what makes the row and the budget the same list: a fifth entry
	# shows up on screen and in stats_row_budget() from one edit, and a Label in this
	# row that no entry describes cannot exist -- which is what the two cycle-51
	# assertions were bolted on to check from the outside.
	for readout: Dictionary in STAT_READOUTS:
		var colour: Color = readout["colour"]
		var member: String = String(readout["member"])
		var label: Label = _add_stat(stats, String(readout["name"]),
			int(readout["font_size"]), int(readout["weight"]), colour,
			float(readout["width"]))
		# The field the rest of this file reads. Through set() so the table stays the
		# only enumeration of the four; a `member` naming nothing would otherwise leave
		# the field null and not say so until the first refresh().
		set(member, label)
		if get(member) != label:
			push_error("Hud: STAT_READOUTS entry %s names no member `%s`"
				% [readout["name"], member])

	# The one element that absorbs slack. Without it the readouts spread across
	# the whole bar; with it they stay left-grouped and the button stays right.
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_child(spacer)

	# The garden's playback speed. LEFT of the wave button, not right: the wave
	# button is the row's right anchor and the Spacer above exists to keep it
	# there. Its size comes from GameSpeed rather than a constant here, so the
	# labels it has to hold and the box that holds them cannot be edited apart.
	_speed_button = Button.new()
	_speed_button.name = "SpeedButton"
	_speed_button.text = GameSpeed.label()
	_speed_button.tooltip_text = GameSpeed.button_tooltip()
	_speed_button.custom_minimum_size = GameSpeed.button_size()
	_speed_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	GardenTheme.style_paper_button(_speed_button)
	_speed_button.pressed.connect(func() -> void: speed_requested.emit())
	stats.add_child(_speed_button)

	_next_wave_button = Button.new()
	_next_wave_button.name = "NextWaveButton"
	_next_wave_button.text = "Next wave"
	_next_wave_button.custom_minimum_size = NEXT_WAVE_BUTTON_SIZE
	_next_wave_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# The notebook's own button rather than Godot's grey slab, applied as per-node
	# overrides so the HUD keeps refusing the shared Theme (which would repaint the
	# plant and packet buttons it sizes in code). The order matters: the budgeted
	# 216x40 slot is set FIRST and the styling sets no size, so a stylebox's content
	# margins can never widen this out of the row's sum. That is checked, not
	# assumed -- test_the_wave_buttons_text_fits_its_budgeted_slot.
	GardenTheme.style_paper_button(_next_wave_button)
	_next_wave_button.pressed.connect(func() -> void: next_wave_requested.emit())
	stats.add_child(_next_wave_button)

	# Second row, outside the container: it is a full-width status line, not a
	# stat competing for space with the others.
	_message_label = _make_label("MessageLabel", MESSAGE_FONT_SIZE, LEAF)
	_message_label.clip_text = true
	_message_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# The stressed line's weight, in the text's own colour so the strokes thicken rather
	# than gaining a halo. The SIZE is toggled per line by `_apply_message_stress`; the
	# colour is written once here, and writing it once is what keeps the two states the
	# same hue — the whole point of MESSAGE_STRESS_OUTLINE's two channels.
	_message_label.add_theme_color_override("font_outline_color", LEAF)
	_message_label.add_theme_constant_override("outline_size", 0)
	bar.add_child(_message_label)

	# The margin tick. A child of the Label rather than of the bar: it then follows the
	# message row's rect through every `_apply_viewport_layout()` without a second copy
	# of that arithmetic, exactly as `_readout_rule` does upstairs.
	_message_mark = ColorRect.new()
	_message_mark.name = "MessageMark"
	_message_mark.color = PAPER
	_message_mark.anchor_left = 0.0
	_message_mark.anchor_right = 0.0
	_message_mark.anchor_top = 0.0
	_message_mark.anchor_bottom = 1.0
	_message_mark.offset_left = -(MESSAGE_MARK_GAP + MESSAGE_MARK_WIDTH)
	_message_mark.offset_right = -MESSAGE_MARK_GAP
	_message_mark.offset_top = 0.0
	_message_mark.offset_bottom = 0.0
	_message_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ambient until something says otherwise. The row's resting state is the prep note,
	# which is MESSAGE_NORMAL by construction.
	_message_mark.visible = false
	_message_label.add_child(_message_mark)

	_prep_bar = ColorRect.new()
	_prep_bar.name = "PrepBar"
	_prep_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prep_bar.visible = false
	bar.add_child(_prep_bar)


func _build_side_panel(root: Control) -> void:
	var panel := ColorRect.new()
	panel.name = "SidePanel"
	panel.color = PAPER_DARK
	root.add_child(panel)
	_side_panel = panel

	var heading := _make_label("Heading", 20, INK)
	heading.position = Vector2(14, 12)
	heading.text = "Garden"
	panel.add_child(heading)

	var layout: Dictionary = plant_bar_layout(PlantCatalog.ids().size())
	_plant_bar = GridContainer.new()
	_plant_bar.name = "PlantBar"
	_plant_bar.columns = int(layout["columns"])
	_plant_bar.add_theme_constant_override("v_separation", PLANT_BAR_SEPARATION)
	_plant_bar.add_theme_constant_override("h_separation", PLANT_BAR_SEPARATION)
	_plant_bar.position = Vector2(12, PLANT_BAR_Y)
	_plant_bar.size = Vector2(PANEL_WIDTH - 24, PLANT_BAR_BOTTOM - PLANT_BAR_Y)
	panel.add_child(_plant_bar)

	for id: StringName in PlantCatalog.ids():
		var button := Button.new()
		button.name = "Button_%s" % String(id)
		button.custom_minimum_size = Vector2(0, float(layout["height"]))
		# A VBoxContainer stretched its children across the panel for free; a
		# GridContainer does not, and without this the buttons render at their
		# icon's natural 128px instead of the 232px the bar is. Caught live -- the
		# layout tests assert heights and positions, and a half-width button is
		# correct on both.
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.icon = load(PlantCatalog.texture_path(id)) as Texture2D
		button.expand_icon = true
		# Leads with the NAME because the button no longer shows it -- see the label
		# comment in _refresh. The blurb follows, which is what this used to be alone.
		# No packet line yet: which packet holds this plant is a question about the
		# run's unlocks, and there is no bank here. refresh() adds it and takes it
		# away again as the answer changes.
		button.tooltip_text = plant_button_tooltip(id, &"")
		button.pressed.connect(_on_plant_button.bind(id))
		button.mouse_entered.connect(_on_plant_hover.bind(id, false))
		button.mouse_exited.connect(_on_plant_hover.bind(id, true))
		_plant_bar.add_child(button)
		_plant_buttons[id] = button

	# Stacked full-width, not side-by-side: two 112px-wide buttons with an icon
	# plus "Common (20)" had no room left for the text (findings caught this —
	# button_text_overflow, 99px of text in less than that of actual space).
	#
	# Built from SeedBank.PACKET_ORDER rather than written out one tier at a time,
	# which is what the third tier is paying for: two hand-placed buttons was a
	# shape that worked exactly twice, and the epic packet would have been a third
	# copy of twelve lines plus a third magic y. Now a tier is a row in one table
	# and the rack lays itself out — see packet_row_rect().
	var packet_icon := load("res://assets/sprites/seed_packet.png") as Texture2D
	for index: int in SeedBank.PACKET_ORDER.size():
		var tier: StringName = SeedBank.PACKET_ORDER[index]
		var rect: Rect2 = packet_row_rect(index)
		var packet := Button.new()
		packet.name = packet_button_name(tier)
		# The buyable form, because no run starts with a spent tier and the panel
		# is built before any bank is in hand. The first refresh() rewrites it from
		# the real pool, so a hypothetical spent-at-birth tier is wrong for one
		# frame rather than forever.
		packet.text = packet_button_text(tier, 1)
		packet.icon = packet_icon
		packet.expand_icon = true
		packet.position = rect.position
		packet.size = rect.size
		packet.tooltip_text = packet_tooltip(tier)
		# `tier` is bound, not captured: a bare closure over the loop variable is
		# the one mistake this rewrite could make that two hand-written buttons
		# could not, and it would wire every button to the last tier.
		packet.pressed.connect(_on_packet_button.bind(tier))
		# Hover, not press: the question "what is in this packet" is asked before
		# buying, and a cue you only get by spending 90 seeds is not a cue. These
		# fire on a DISABLED button too, which is the case that matters most — a
		# packet you cannot afford yet is exactly the one you are pricing up.
		packet.mouse_entered.connect(_on_packet_hover.bind(tier))
		packet.mouse_exited.connect(_on_packet_hover.bind(&""))
		panel.add_child(packet)
		_packet_buttons[tier] = packet

	_selection_box = VBoxContainer.new()
	_selection_box.name = "SelectionBox"
	_selection_box.position = Vector2(12, SELECTION_BOX_Y)
	_selection_box.size = Vector2(PANEL_WIDTH - 24, 152)
	_selection_box.add_theme_constant_override("separation", 6)
	_selection_box.visible = false
	panel.add_child(_selection_box)

	# 56, down from 76. The old height existed to fit the Chomp Flower's 86-character
	# blurb at four wrapped lines — reference text the player has already read off the
	# plant button's tooltip, which still carries it. Every branch below now spends
	# those two lines on live state instead, and the 20px this frees is exactly what
	# the health row costs, so SelectionBox's damaged height is unchanged at 168 and
	# its foot stays 16px clear of the panel bottom.
	_selection_label = _make_label("SelectionLabel", 15, INK)
	_selection_label.custom_minimum_size = Vector2(0, 56)
	_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection_box.add_child(_selection_label)

	# Hidden until the plant has actually been bitten, matching the in-world bar on
	# the plant itself (Plant._health_back). A full bar on every selection would be
	# 232px of panel saying "nothing is wrong", and the whole point of the readout is
	# that it only ever appears when there is a decision to make.
	_health_row = ColorRect.new()
	_health_row.name = "HealthRow"
	_health_row.color = HEALTH_BACK
	_health_row.custom_minimum_size = Vector2(0, HEALTH_ROW_HEIGHT)
	_health_row.visible = false
	_health_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_box.add_child(_health_row)

	_health_fill = ColorRect.new()
	_health_fill.name = "HealthFill"
	# health_color(1.0), not HEALTH_FULL: the row is hidden until a plant is bitten,
	# so this value is only ever seen for the frame between showing the row and the
	# first _refresh_health -- and on the safe ramp a hard-coded LEAF would make that
	# frame the one place the green survives.
	_health_fill.color = health_color(1.0)
	_health_fill.position = Vector2.ZERO
	_health_fill.size = Vector2(PANEL_WIDTH - 24, HEALTH_ROW_HEIGHT)
	_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_row.add_child(_health_fill)

	# The numbers ride ON the bar rather than in SelectionLabel. As a third label
	# line they cost a whole 24px text row, which pushed SelectionBox's foot to
	# exactly 648 — flush with the panel edge, no margin at all. Measured live;
	# the headless box-fits test passed it because a foot exactly on the boundary
	# satisfies `<=`.
	_health_text = _make_label("HealthText", 11, PAPER)
	_health_text.position = Vector2.ZERO
	_health_text.size = Vector2(PANEL_WIDTH - 24, HEALTH_ROW_HEIGHT)
	_health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_row.add_child(_health_text)

	_upgrade_button = Button.new()
	_upgrade_button.name = "UpgradeButton"
	_upgrade_button.text = "Upgrade"
	_upgrade_button.custom_minimum_size = Vector2(0, 40)
	_upgrade_button.pressed.connect(func() -> void: upgrade_requested.emit())
	_selection_box.add_child(_upgrade_button)

	_uproot_button = Button.new()
	_uproot_button.name = "UprootButton"
	_uproot_button.text = "Uproot"
	_uproot_button.custom_minimum_size = Vector2(0, 40)
	_uproot_button.pressed.connect(func() -> void: uproot_requested.emit())
	_selection_box.add_child(_uproot_button)


## The wave banner, centred over the board rather than the window: the side
## panel owns x >= viewport - PANEL_WIDTH, so a window-centred banner would sit
## visibly off to the right of the thing it is announcing — the same reasoning
## RunSummary.CARD is built on.
##
## The two Labels are siblings, not a parent Control with children. A sized
## wrapper would share pixels with everything inside it, which is a real finding
## for the pairwise occlusion checks and would have to be explained away forever.
func _build_banner(root: Control) -> void:
	_banner = _make_banner_label("Banner", BANNER_FONT_SIZE, PAPER)
	root.add_child(_banner)

	# Stacked directly under the headline, sharing no pixels with it: the two
	# rects abut at BANNER_Y + BANNER_HEIGHT rather than overlapping.
	# Both rows' rects are written by `_apply_viewport_layout()`.
	_banner_note = _make_banner_label("BannerNote", BANNER_NOTE_FONT_SIZE, PAPER)
	root.add_child(_banner_note)


## Shared build for the banner's two rows. Both are single-line and clipped:
## BANNER_WORST_CASE_TEXT plus its test say the text always fits, and the clip is
## what makes a future regression render as a trimmed line instead of 48px text
## running off the board and over the side panel.
func _make_banner_label(node_name: String, font_size: int, colour: Color) -> Label:
	var label := _make_label(node_name, font_size, colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# Drawn over the board, whose greens and browns are close enough to PAPER to
	# swallow it without a shadow.
	label.add_theme_color_override("font_shadow_color", INK)
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	return label


## One readout in the top row: a clipped, fixed-budget Label.
##
## Clipping is what stops the row overflowing, and it is not optional. An
## HBoxContainer will not shrink a child below its minimum size, and a Label's
## minimum size is its full text — so an unbudgeted readout does not get
## squeezed, it shoves everything after it, and the wave button ends up off the
## right edge of the screen. Every readout is budgeted rather than just the
## long one, so adding a fifth later is a matter of finding room in the sum
## instead of rediscovering this.
##
## `weight` is the readout's stroke weight, drawn as a font outline in the readout's
## OWN colour so the glyphs thicken instead of gaining a halo — see
## READOUT_WEIGHT_HEAVY for why an outline rather than a bold face, and STAT_READOUTS'
## hierarchy block for which readout gets which. The outline colour is set even at
## weight 0: it costs nothing, and it means a row that later takes a weight is already
## drawn in the right colour rather than in Godot's default black.
func _add_stat(row: HBoxContainer, node_name: String, font_size: int, weight: int,
		colour: Color, width: float) -> Label:
	var label := _make_label(node_name, font_size, colour)
	label.add_theme_constant_override("outline_size", weight)
	label.add_theme_color_override("font_outline_color", colour)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2(width, 0)
	label.add_child(_readout_rule(node_name))
	row.add_child(label)
	return label


## The ruled line a readout is written on.
##
## A child of the Label, not a fifth thing in the row, and that is the whole reason
## this shape was chosen: the row's widths are a budgeted sum with ~19px of slack
## left in it, so a decoration holding a slot would be spending the last of the
## budget on ornament. As a child it costs zero width, and `_hud_rects` skips
## ColorRects, so it also cannot be mistaken for a Control overlapping its
## neighbour by the pair checks that guard this bar.
##
## Anchored rather than sized. A readout's box is not known until the HBoxContainer
## has sorted its children, so a width written here would be a second copy of the
## budget constant that could silently disagree with the first -- and a hand-picked
## number in the top bar is exactly what `_make_label`'s header says produced the
## original overlap bug. `show_behind_parent` so the rule is paper under the text
## rather than a line struck through it.
func _readout_rule(node_name: String) -> ColorRect:
	var rule := ColorRect.new()
	rule.name = "%sRule" % node_name
	rule.color = Color(PAGE_RULE, READOUT_RULE_ALPHA)
	rule.anchor_left = 0.0
	rule.anchor_right = 1.0
	rule.anchor_top = 1.0
	rule.anchor_bottom = 1.0
	rule.offset_left = 0.0
	rule.offset_right = 0.0
	rule.offset_top = -READOUT_RULE_HEIGHT
	rule.offset_bottom = 0.0
	rule.show_behind_parent = true
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


## The widths above are only safe as a sum. Anything that adds a readout, widens
## one, or grows the button has to keep this true, and the unit test calls it
## rather than re-deriving the arithmetic.
## A packet button, disabled for the reason that actually applies, and saying so.
##
## The tooltip is rewritten rather than left static because the two reasons a
## packet is unbuyable are not interchangeable: "come back with more seeds" is a
## wait, and "this tier has nothing left for you" is a redirect to the other
## packet. A single greyed button that means either one teaches neither.
##
## The LABEL now carries the same distinction, because the tooltip carried it
## alone and a tooltip is only read by a player who already suspects there is
## something to read. See packet_button_text: a spent tier stops quoting a price
## and says "Empty" instead, so the two greys are told apart at a glance rather
## than on hover.
func _refresh_packet_button(button: Button, bank: SeedBank, tier: StringName) -> void:
	var spec: Dictionary = SeedBank.PACKET_TIERS[tier] as Dictionary
	var cost: int = int(spec["cost"])
	var stock: int = bank.packet_pool(tier).size()
	var spent: bool = stock == 0
	button.disabled = spent or bank.seeds < cost
	button.text = packet_button_text(tier, stock)
	if spent:
		button.tooltip_text = "Nothing left in a %s — every plant it can hold is already in your garden." % String(spec["display"])
	elif bank.seeds < cost:
		button.tooltip_text = "A %s costs %d seeds. You have %d." % [String(spec["display"]), cost, bank.seeds]
	else:
		button.tooltip_text = packet_tooltip(tier)


## The prep strip: how long until the next wave arrives on its own, and — in its
## colour — how bad that wave will be.
##
## Hidden while a wave is live and once the waves run out, because an empty strip
## and a full one would otherwise be the same picture: a bar that is always there
## says nothing by being there.
func _refresh_prep_bar(state: Dictionary) -> void:
	var total: float = float(state.get("prep_total", 0.0))
	var live: bool = bool(state.get("wave_live", false))
	if live or total <= 0.0 or not bool(state.get("more_waves", false)):
		_prep_bar.visible = false
		_set_prep_bar_urgent(false)
		return
	var left: float = clampf(float(state.get("prep_left", 0.0)), 0.0, total)
	_prep_bar.visible = true
	# The FRACTION is the state; the px width is derived from it and the live
	# viewport, so a resize mid-countdown re-multiplies instead of keeping the
	# pixels the old window bought.
	_prep_fraction = left / total
	_prep_bar.size = Vector2(float(get_viewport_width()) * _prep_fraction, PREP_BAR_HEIGHT)
	# The wave that is coming, not the one that just finished — the strip is a
	# warning about the next thing, so it wears the next thing's colour.
	_prep_bar.color = threat_color(int(state.get("next_threat_level", 1)))
	# left > 0.0: at exactly 0 the strip is a frame from disappearing under
	# `live` above, and starting a pulse nothing will see is wasted motion.
	_set_prep_bar_urgent(left <= PREP_BAR_URGENT_SECONDS and left > 0.0)


## Starts or stops the final-seconds pulse, once per crossing rather than once
## per refresh() -- see _prep_bar_urgent's own comment for why that guard is
## load-bearing here and not merely tidy.
func _set_prep_bar_urgent(urgent: bool) -> void:
	if urgent == _prep_bar_urgent:
		return
	_prep_bar_urgent = urgent
	if _prep_bar_pulse != null and _prep_bar_pulse.is_valid():
		_prep_bar_pulse.kill()
	# Reset first, gate second: a run that leaves the urgent zone (or a
	# headless run that never had a Tween) must not freeze the strip dim.
	_prep_bar.modulate = Color.WHITE
	if not urgent or not GardenTheme.animations_enabled():
		return
	_prep_bar_pulse = create_tween().set_loops()
	_prep_bar_pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_prep_bar_pulse.tween_property(_prep_bar, "modulate", Color(1, 1, 1, PREP_BAR_PULSE_DIM), PREP_BAR_PULSE_SECONDS)
	_prep_bar_pulse.tween_property(_prep_bar, "modulate", Color.WHITE, PREP_BAR_PULSE_SECONDS)


## How the plant bar arranges `count` plants: one column while they still clear
## the 40px touch minimum, two once they do not.
##
## Two columns is available here only because plant buttons are icon-only. The
## packet buttons below are stacked full-width for a documented reason — two
## 112px buttons could not fit "Common Packet (20)" and `findings` caught the
## overflow — but that is a constraint on *text*, and these carry none.
##
## Pure and static so the arithmetic is assertable without building a HUD, and so
## a future catalogue size can be checked without adding the plant.
## What a plant button says. Pure, because it is the whole reason two columns fit and a
## test should be able to ask it without a HUD.
##
## Three states in two symbols: a price you can read, "free" for the starter, and NOTHING
## for a plant that is not for sale yet. The empty string is deliberate rather than lazy --
## it is the state with no number, which is exactly what "you cannot buy this yet" means,
## and it costs the button no width at all.
static func plant_button_label(unlocked: bool, price: int) -> String:
	if not unlocked:
		return ""
	return "free" if price == 0 else str(price)


## THE UPROOT BUTTON'S RESTING LABEL, and the half of the trade it used to leave out.
##
## It said `Uproot (+12)` — what you GET BACK — and nothing anywhere said what putting
## a plant back on that bed costs. Both numbers are known: the refund slides with the
## plant's health (`Plant.uproot_refund`), the replant price is `SeedBank.placement_cost`
## for the same `kind`, and the decision the player is actually making is the DIFFERENCE
## between them, on a four-second confirm timer (plant-tower-defense-eupm).
##
## So the button does the subtraction. `Uproot (+12, net -8)` reads: twelve seeds come
## back, and you end the round trip eight down.
##
## WHY THE NET AND NOT "replant 20". Two bare numbers side by side is the same
## arithmetic in one more character; the bead's acceptance is that the NET COST is
## visible while deciding, and a player mid-timer should not be subtracting. The
## replant price is still reachable in words — see `uproot_button_tooltip`, which costs
## no width at all.
##
## THE SIGN IS THE SECOND CHANNEL, and it has to be, because `net` genuinely goes both
## ways: while the free starter is unspent `placement_cost` returns 0, so uprooting a
## Corn Cobbler and replanting it is pure profit and the button says `+6`. A colour
## would have been the obvious way to separate those two cases and it is exactly the
## channel `game/OVERLAY_GRAMMAR.md` forbids as a sole signal; a leading `-` or `+`
## survives greyscale, and this button already spends its one colour override on ARMED.
##
## THE ARMED LABEL IS DELIBERATELY UNCHANGED. `Really uproot? (+99)` is the longest
## string this button has ever held and the width argument below is that nothing may
## exceed it; more to the point, once the confirm is armed the decision is made and the
## question on screen is "destroy this?", not "is the trade worth it?".
##
## Pure and static so the wording and the arithmetic are assertable without a HUD, and
## so `test_the_uproot_buttons_worst_case_fits_the_selection_box` can measure the widest
## string this can build rather than one somebody typed out.
static func uproot_net(refund: int, replant: int) -> int:
	return refund - replant


## The net, signed. `%d` prints a loss as "-8" but a gain as a bare "8", so the two
## directions would be told apart only by the reader knowing which one is normal; the
## explicit `+` is the channel that survives the colour being thrown away.
static func uproot_net_text(net: int) -> String:
	return "+%d" % net if net > 0 else "%d" % net


static func uproot_button_text(refund: int, replant: int) -> String:
	return "Uproot (+%d, net %s)" % [refund, uproot_net_text(uproot_net(refund, replant))]


## The armed label. Same shape it has always had — see the block above for why this one
## does NOT gain the net.
static func uproot_armed_text(refund: int) -> String:
	return "Really uproot? (+%d)" % refund


## The widest string this button can be asked to hold, and the value the fit test
## measures. Two digits on both numbers because the catalogue tops out at 45 seeds
## (`PlantCatalog`) and a refund can never exceed the cost it is a fraction of — the
## third digit is headroom, not a reachable state.
## A PLUS in the net, not a minus, and 15 rather than 99.
##
## The obvious worst case is the biggest numbers with the sign that looks heaviest,
## and it is wrong on both counts. `net` is positive exactly once — the free starter,
## where placement_cost is 0 and the trade pays — and in this theme's font `+` is
## wider than `-`, so "Uproot (+15, net +15)" measures 171px against the 99s' 167.
## The 15 is not free either: the refund is a fraction of a real catalogue price, so
## 99 is not a string the game can build, and the widest it can is the dearest plant.
##
## Found by this constant's own test on its first real run, which is what that test
## is for — the string was declared from the shape of the format and never measured.
const UPROOT_WORST_CASE_TEXT: String = "Uproot (+15, net +15)"
## And the armed branch's, which is the string every earlier pass measured this button
## against. Both are measured against the 232px box by
## `test_the_uproot_buttons_worst_case_fits_the_selection_box`, which also checks the
## constant above is a real ceiling over every string the CATALOGUE can build — the two
## are not ranked against each other, because which of them draws wider is a font
## question and neither this comment nor that test needs an answer to it.
const UPROOT_ARMED_WORST_CASE_TEXT: String = "Really uproot? (+99)"


## The trade in words, on hover. This is where the replant PRICE lives: a tooltip is
## the one surface in the side panel with no width budget at all, so the number the
## button had to compress into a net is still available in full to anyone who asks.
static func uproot_button_tooltip(plant_name: String, refund: int, replant: int) -> String:
	var net: int = uproot_net(refund, replant)
	if net >= 0:
		return ("Digging up your %s pays %d seeds back. Planting another costs %d, "
			+ "so the round trip leaves you %d up.") % [plant_name, refund, replant, net]
	return ("Digging up your %s pays %d seeds back. Planting another costs %d, "
		+ "so the round trip costs you %d.") % [plant_name, refund, replant, -net]


## What a plant button is tinted, in the three states it can be in.
##
## `hinted` is the packet rack talking to the plant bar: while the cursor rests on
## a packet button, every locked plant that packet could still hand over lifts out
## of the dim. The two surfaces sit 40px apart on the same panel and, before h6ek,
## shared no cue at all — a locked plant showed an empty label and a grey icon, and
## nothing anywhere said which of the three packets was the one to buy for it.
##
## A tint rather than a badge, and this is a layout decision. A badge on a plant
## button costs width, and width is exactly what the two-column plant bar has none
## of: the bar gets 114px a column, a button's minimum was 195px until the NAME was
## taken off it, and `findings` last caught this as the side panel sitting 167px off
## the right edge. `modulate` costs nothing and is already the channel these buttons
## speak in.
##
## The lift is brightness first and hue second — a locked button sits at 55% alpha,
## a hinted one at 100% — because a hue-only cue is the one a colourblind player
## does not get. See GardenTheme's own note on the threat ramp for the same argument.
static func plant_button_tint(unlocked: bool, affordable: bool, hinted: bool) -> Color:
	if hinted:
		return PACKET_HINT_TINT
	return Color.WHITE if (unlocked and affordable) else PLANT_BUTTON_DIM


## What a plant button says on hover: its name, its blurb, and — for a plant still
## in a packet — WHICH packet, priced.
##
## `from_tier` is SeedBank.cheapest_packet_for(id) and is &"" for a plant already
## unlocked. Passed in rather than looked up here so that this stays pure and the
## derivation has exactly one home; a Hud that computed the mapping itself would be
## a second answer to a question SeedBank already answers.
##
## The packet is named by reading PACKET_TIERS, never by spelling "Rare Packet" into
## this string. That is the mistake the old tooltip made — see packet_tooltip's
## header — and the reason the counting tooltip refuses to name plants at all. It is
## safe in this direction because the name comes out of the table at draw time.
static func plant_button_tooltip(id: StringName, from_tier: StringName) -> String:
	var tip: String = "%s — %s" % [PlantCatalog.display_name(id), PlantCatalog.blurb(id)]
	var spec: Dictionary = SeedBank.PACKET_TIERS.get(from_tier, {}) as Dictionary
	if spec.is_empty():
		return tip
	return "%s\nStill in a packet: a %s (%d) can hand it over." % [
		tip, String(spec["display"]), int(spec["cost"]),
	]


static func plant_bar_layout(count: int) -> Dictionary:
	var span: float = PLANT_BAR_BOTTOM - PLANT_BAR_Y
	# This function only reasons about HEIGHT, and that is a real limit rather than
	# an oversight: a plant button's minimum WIDTH is 158px (icon plus the longest
	# label), so the two-column branch below already cannot be rendered at
	# PANEL_WIDTH — the GridContainer grows instead of shrinking and pushes the
	# side panel off the viewport. It stays because the vertical arithmetic is what
	# this answers and what the sweep test checks; a catalogue that actually
	# reaches for it needs shorter labels first. See PLANT_BAR_BOTTOM, where that
	# was found live rather than reasoned about.
	# TWO COLUMNS, and this is the third answer this function has given. It was one
	# column, then a one-column-or-two that returned a two-column layout its own header
	# called unrenderable, then one column only (cycle 98, after `findings` reported the
	# panel 167px off the right edge). It is two now because the BUTTONS changed, not
	# because the arithmetic did: they carry an icon and a price and no longer a name, so
	# a button's minimum width fell from 195px to something that fits 114.
	#
	# That is the order the fix had to happen in. Two columns was never a layout problem
	# to be solved by layout -- it was a content problem, and every previous attempt tried
	# to divide 232px by two without changing what had to fit inside it.
	var columns: int = PLANT_BAR_COLUMNS if count > PLANT_BAR_SINGLE_COLUMN_MAX else 1
	var rows: int = maxi(1, int(ceil(float(count) / float(columns))))
	var fitted: float = (span - float(PLANT_BAR_SEPARATION * (rows - 1))) / float(rows)
	if fitted >= PLANT_BUTTON_MIN_HEIGHT:
		return {"columns": columns, "height": fitted, "rows": rows, "overflows": false}
	# Below the touch floor. Report the floor and say the bar must scroll rather than
	# silently returning a button too small to hit -- `findings` gates an interactive
	# Control at 40x40 and is right to.
	return {
		"columns": columns,
		"height": PLANT_BUTTON_MIN_HEIGHT,
		"rows": rows,
		"overflows": true,
	}


## WORST_CASE_TEXT's initialiser: name -> worst case, projected off STAT_READOUTS.
##
## Not a second table and not a cache -- it runs once, when the script loads, and its
## whole reason for existing is that a `const` cannot be computed. Every caller that
## wants a worst case wants exactly this shape.
static func _worst_case_text() -> Dictionary:
	var table: Dictionary = {}
	for readout: Dictionary in STAT_READOUTS:
		table[String(readout["name"])] = String(readout["worst_case"])
	return table


## The row's four slots plus its separations plus its two buttons.
##
## The widths are summed off STAT_READOUTS rather than off four named constants, which
## is the half of that table's point that faces the budget: a readout added to the row
## is added to this sum in the same edit, so `hud_stats_row` can no longer report a row
## narrower than the one on screen.
static func stats_row_budget(readouts: int) -> float:
	var widths: float = 0.0
	for readout: Dictionary in STAT_READOUTS:
		widths += float(readout["width"])
	return (widths + float(STATS_SEPARATION * readouts) + NEXT_WAVE_BUTTON_SIZE.x
		+ GameSpeed.button_size().x)


## No position argument: every caller either puts the label in a container that
## positions it, or sets `position` itself right after. Passing a hand-picked
## x/y here is what produced the top bar's overlap bug, so the parameter is
## gone rather than merely unused.
func _make_label(node_name: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	# Mixed font sizes on one row: without this the 20px compost text sits on a
	# different baseline from the 26px stats beside it.
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


## Colour for a threat level, cream through amber to red — or through the
## colourblind-safe ramp, if the player has asked for it.
##
## Static and pure so the whole ramp is assertable without a HUD — and so the
## devtools `curve` verb can sweep it as data rather than it being judged by eye
## off a screenshot. The flag is the one thing it reads from outside itself;
## `threat_color_on` is the half with no reads at all, which is what the ramp
## tests drive so that they cannot be changed by a setting an earlier test left on.
static func threat_color(level: int) -> Color:
	return threat_color_on(level, RunConfig.colorblind_safe)


static func threat_color_on(level: int, safe: bool) -> Color:
	if level < THREAT_SHOW_FROM:
		# Both ramps start at the bar's own cream. That is not a shared stop by
		# accident: "nothing is wrong yet" should look like the bar, not like a
		# colour, on either palette.
		return PAPER
	var span: float = float(THREAT_TINT_MAX - THREAT_SHOW_FROM)
	var t: float = clampf(float(level - THREAT_SHOW_FROM) / span, 0.0, 1.0)
	var warm: Color = THREAT_WARM_SAFE if safe else THREAT_WARM
	var hot: Color = THREAT_HOT_SAFE if safe else THREAT_HOT
	# Two segments rather than one lerp: cream straight to red passes through a
	# muddy pink that reads as neither safe nor dangerous, and the amber midpoint
	# is the whole point of a three-stop warning ramp.
	if t < 0.5:
		return PAPER.lerp(warm, t * 2.0)
	return warm.lerp(hot, (t - 0.5) * 2.0)


## Colour for a plant's health fill at `fraction` of full.
##
## Pulled out of `_refresh_health` for the reason `threat_color` was pulled out of
## `refresh`: it is the other bar a player reads by hue alone, and it was the only
## one of the two that could not be swept as data. Now both go through one switch,
## so a build cannot end up with a colourblind-safe threat readout above a
## green-to-red health bar.
static func health_color(fraction: float) -> Color:
	return health_color_on(fraction, RunConfig.colorblind_safe)


static func health_color_on(fraction: float, safe: bool) -> Color:
	var low: Color = HEALTH_LOW_SAFE if safe else HEALTH_LOW
	var full: Color = HEALTH_FULL_SAFE if safe else HEALTH_FULL
	return low.lerp(full, clampf(fraction, 0.0, 1.0))


## The width of the canvas this HUD is actually laid out on, in the units it is
## laid out in.
##
## It used to be `ProjectSettings.display/window/size/viewport_width` -- the
## DESIGN width, which is a different number from the live one on any window
## that is not 16:9 (plant-tower-defense-0jye). `get_visible_rect()` is the read
## that respects the content-scale override `stretch/mode=canvas_items` installs,
## so this returns canvas units (1536 on a 21:9 window) rather than physical
## pixels; `Window.size` would return the latter and be wrong for every Control
## on this layer.
##
## Falls back to the design size when there is no viewport to ask -- a HUD built
## outside a tree, which is how a couple of budget probes construct screens.
func get_viewport_width() -> int:
	return int(_live_viewport_size().x)


func get_viewport_height() -> int:
	return int(_live_viewport_size().y)


func _live_viewport_size() -> Vector2:
	var fallback := Vector2(float(design_width()), float(design_height()))
	var vp: Viewport = get_viewport()
	if vp == null:
		return fallback
	var live: Vector2 = vp.get_visible_rect().size
	# A viewport with no size yet reports (0, 0), and laying the HUD out against
	# zero would collapse every rect on it into something `findings`' own
	# ui_zero_size check would then report. The design size is the honest answer
	# to "how big is the screen" before there is one.
	if live.x <= 0.0 or live.y <= 0.0:
		return fallback
	return live


## The size this HUD was DESIGNED at -- the project setting, under a name that
## says so. Kept because it is the reference the width budget is measured
## against (`min_viewport_width`), and because `stretch/aspect="expand"` never
## produces a canvas smaller than it, which is what makes the budget safe.
static func design_width() -> int:
	return ScreenMetrics.design_width()


static func design_height() -> int:
	return ScreenMetrics.design_height()


func _on_plant_button(id: StringName) -> void:
	plant_selected.emit(id)


## Order-independent: an exit only clears the hover if it is the button that
## currently owns it, so entering B before leaving A cannot blank B.
func _on_plant_hover(id: StringName, leaving: bool) -> void:
	if leaving:
		if _hovered_plant != id:
			return
		_hovered_plant = &""
	else:
		_hovered_plant = id
	plant_hovered.emit(_hovered_plant)


func _on_packet_button(tier: StringName) -> void:
	packet_requested.emit(tier)


## The cursor arrived on (or left, with &"") a packet button.
##
## Applied straight away rather than left for the next refresh(): refresh is driven
## by Game._refresh(), which fires on state CHANGES — a purchase, a wave, a seed
## earned — and a mouse crossing a button changes no state at all. Waiting for one
## would mean the rack lights the plant bar only when something else happens to
## happen, which is indistinguishable from a bug.
func _on_packet_hover(tier: StringName) -> void:
	if tier == _packet_hint_tier:
		return
	_packet_hint_tier = tier
	_apply_plant_hints()


## Paints every plant button: the hint tint for the ones the hovered packet can
## still hand over, their resting tint for everyone else.
##
## The ONE writer of `modulate` on these buttons, which is why refresh() routes
## through it rather than assigning directly. Two writers is how a hover cue gets
## silently erased by the next unrelated state push, and that push happens on every
## seed earned.
func _apply_plant_hints() -> void:
	var hinted: Array = _packet_hint_pools.get(_packet_hint_tier, [])
	for id: StringName in _plant_buttons:
		var button: Button = _plant_buttons[id]
		if hinted.has(id):
			button.modulate = PACKET_HINT_TINT
		else:
			button.modulate = _plant_rest_tint.get(id, Color.WHITE) as Color


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_advance_message_queue()
	if _banner_left > 0.0:
		_fade_banner(delta)


## The one call the Game makes every time anything changes. Passing the whole
## state in keeps the HUD stateless — there is no second copy of the truth here
## that can go stale.
func refresh(state: Dictionary) -> void:
	var bank: SeedBank = state["bank"]
	var seeds_text: String = "Seeds  %d" % bank.seeds
	# The final text goes on FIRST and the roll is armed after it — see SEED_ROLL_SECONDS.
	# `_seeds_shown`, not the Label, is what the roll counts from: a roll already in
	# flight has the Label holding an intermediate value.
	var seeds_moved: bool = _readouts_seeded and seeds_text != _seeds_label.text
	var seeds_from: int = _seeds_shown
	_seeds_label.text = seeds_text
	_seeds_shown = bank.seeds
	if seeds_moved:
		_punch_readout(_seeds_label)
		_arm_seeds_roll(seeds_from, bank.seeds)
	if bool(state.get("endless", false)):
		# "∞" rather than "— endless": at wave 509 with a threat level appended,
		# the spelled-out version measured 397px against a 320px budget and was
		# being ellipsised away. Caught by `findings` on the live bar, not here.
		_wave_label.text = "Wave  %d ∞" % state["wave"]
	else:
		_wave_label.text = "Wave  %d / %d" % [state["wave"], state["wave_count"]]
	# Threat rides with the wave number rather than taking a slot of its own:
	# it is a property of the wave, and the bar has no room for a fifth stat.
	# The level, not the raw multiple — see WaveDirector.threat_level for why
	# "threat x897" was the first thing the live run threw out.
	var level: int = int(state.get("threat_level", 1))
	if level >= THREAT_SHOW_FROM:
		_wave_label.text += "   threat %d" % level
	# Weather rides here too, and for the same reason threat does: it is a property
	# of the wave, and the bar has no room for a fifth stat. The banner is the beat
	# and it fades; this is the state, and it is what answers "why is my corn slow"
	# for the player who looked away. Clear says nothing -- a readout that is present
	# and empty eleven waves out of twelve is a readout people stop reading.
	# The whole readout takes the tint, not just the number after it. A Label
	# cannot colour part of its own text, and the two alternatives both cost more
	# than they are worth: a fifth StatsRow child has to be bought out of a bar
	# that has already had one occlusion bug, and a RichTextLabel breaks every
	# `as Label` cast the existing tests make. Tinting all of it is also honest —
	# the wave and its threat are one fact, so "wave 14" going red is the message.
	_ease_threat_tint(threat_color(level))
	var lives_text: String = "Garden  %d" % state["lives"]
	if _readouts_seeded and lives_text != _lives_label.text:
		_punch_readout(_lives_label)
	_lives_label.text = lives_text

	var husks: int = int(state.get("husks_on_ground", 0))
	var compost_text: String = "Compost  %d" % int(state.get("compost_total", 0))
	if husks > 0:
		# "+N", not " (N ready)". The long form measured 198px in a 170px box and
		# the player saw a cut string -- and it had been that way since husks were
		# added, because WORST_CASE_TEXT declared only "Compost  9999" and the
		# width test has only ever measured the string the table names, not the
		# string the formatter can build.
		compost_text += "  +%d" % husks
	if _readouts_seeded and compost_text != _compost_label.text:
		_punch_readout(_compost_label)
	_compost_label.text = compost_text
	_readouts_seeded = true

	# What each packet could still hand over, refreshed before the plant bar reads
	# it. Snapshotted per state push rather than read live on hover, because hover
	# arrives with no bank behind it — see _packet_hint_pools.
	_packet_hint_pools.clear()
	for tier: StringName in SeedBank.PACKET_ORDER:
		_packet_hint_pools[tier] = bank.packet_pool(tier)

	var selected: StringName = state["selected_plant"]
	for id: StringName in _plant_buttons:
		var button: Button = _plant_buttons[id]
		var unlocked: bool = bank.is_unlocked(id)
		var price: int = bank.placement_cost(id)
		# One line, not two, and that is a layout decision rather than a style one:
		# a two-line button has 54px of intrinsic height and five of them plus
		# three packet buttons do not fit the panel (see PLANT_BAR_BOTTOM). One
		# line is 31px, which is what makes a fifth plant fit at all. The price
		# loses the word "seeds" with it — the seed count at the top of the screen
		# is the only currency there is, and the icon beside it says so.
		# THE NAME IS GONE FROM THE BUTTON, and that is what buys the second column.
		# A button's minimum width was 195px with the name on it, against the 114px a
		# two-column bar can give -- so every attempt to fit six plants by dividing the
		# bar failed on content rather than on arithmetic. See PLANT_BAR_COLUMNS.
		#
		# What is left is the icon and the price, which are the two things a player reads
		# when deciding whether to plant something. The NAME moves to the tooltip (set in
		# the builder, and now leading with it) and is on the selection panel the moment
		# the plant is chosen. The icon is what this game's art contract exists to make
		# distinguishable -- art_src/STYLE.md sizes and colours every plant for exactly
		# this reading.
		#
		# A LOCKED plant shows NO price rather than the word "locked". That is the same
		# distinction in one fewer channel: a number means you may buy it, no number means
		# it is not for sale yet, and the greyed modulate below carries "cannot afford"
		# separately. The tooltip says which in words for anyone who wants certainty.
		#
		# WHICH PACKET UNLOCKS IT is the one thing the button could not say. The
		# plant bar and the packet rack sit 40px apart on this panel and shared no
		# cue at all: a locked plant was a grey icon with no label, and the rack
		# below it counted its contents without naming them. Two answers now, both
		# read out of SeedBank.cheapest_packet_for() rather than written down --
		# this tooltip names the packet and its price, and hovering the packet
		# lights the plants it can hand over (see _apply_plant_hints).
		button.text = plant_button_label(unlocked, price)
		button.disabled = not unlocked
		var tip: String = plant_button_tooltip(id, bank.cheapest_packet_for(id))
		# Only on change: a tooltip already on screen is not re-read when its text
		# is reassigned, and rewriting it on every seed earned is churn for nothing.
		if button.tooltip_text != tip:
			button.tooltip_text = tip
		# Recorded, not applied -- _apply_plant_hints() below is the only writer of
		# `modulate` here, so a live packet-hover cue survives this refresh instead
		# of being erased by the next seed the player earns.
		_plant_rest_tint[id] = plant_button_tint(unlocked, bank.can_afford(id), false)
		button.button_pressed = unlocked and id == selected
	_apply_plant_hints()

	# Per tier, not just "is anything locked". A common packet caps at tier 1, so
	# once the Chomp is out of its packet there is nothing left it may hand over
	# even though the tier-2 Sunflower is still locked. Before this the button
	# stayed lit and every click bought a refusal message — which is what a lit
	# button that does nothing always is.
	for tier: StringName in SeedBank.PACKET_ORDER:
		var packet := _packet_buttons.get(tier) as Button
		if packet != null:
			_refresh_packet_button(packet, bank, tier)
	_next_wave_button.disabled = not bool(state["can_start_wave"])
	# Rendered from state like every other readout — the HUD keeps no second copy
	# of the speed, so the button cannot disagree with the engine or read 1x
	# behind a pause card that is holding the clock.
	_speed_button.text = String(state.get("game_speed_label", "1x"))
	_speed_button.tooltip_text = String(state.get("game_speed_tooltip", ""))
	_refresh_prep_bar(state)
	_refresh_prep_note(state)
	_refresh_selection(state)
	# A run can end mid-hold — the last life goes while the wave banner is still
	# up. RunSummary's backdrop is deliberately translucent so the board's damage
	# map reads through it, which means a leftover "Wave 12" would read through
	# it too, in 48px, across the post-mortem. The banner is about the wave that
	# just started; once the run is over there is no such wave.
	if bool(state.get("game_over", false)) or bool(state.get("victory", false)):
		hide_banner()


func _refresh_selection(state: Dictionary) -> void:
	var plant: Plant = state["selected_placed"] as Plant
	if plant == null or not is_instance_valid(plant):
		_selection_box.visible = false
		return
	var was_hidden: bool = not _selection_box.visible
	_selection_box.visible = true
	if was_hidden:
		_play_panel_entrance()
	var corn := plant as CornCobbler
	var sunflower := plant as Sunflower
	if corn != null:
		# The kernel count alone stopped being the story. Past ~80px most of a
		# bunch's five kernels sail past the pest it aimed at, so what an upgrade
		# actually buys is damage and rate — and for a while it bought neither,
		# which is how a 45-seed upgrade ended up worse than a 20-seed one.
		# Two lines, not three. The first draft spelled out kernels, damage and
		# interval and wrapped to a third line, which pushed SelectionBox's foot to
		# exactly the panel's own 648 — caught by the 8px clearance test written
		# three cycles ago for the same overflow. Damage per volley is the number
		# that actually changed and the one the upgrade is bought for.
		_selection_label.text = "%s — %s\n%.1f dmg / %.2fs, %d kernel(s)" % [
			PlantCatalog.display_name(plant.kind), corn.level_name(),
			corn.kernel_damage() * float(corn.kernels_per_shot()),
			corn.fire_interval(), corn.kernels_per_shot(),
		]
	elif sunflower != null:
		_selection_label.text = "%s\nNext %d seeds in %.0fs" % [
			PlantCatalog.display_name(plant.kind), Sunflower.YIELD, sunflower.seconds_until_next_yield(),
		]
	else:
		var chomp := plant as ChompFlower
		var sundew := plant as StickySundew
		var dandelion := plant as Dandelion
		var busy: String = "Idle — waiting for a pest."
		if dandelion != null:
			# The fluff count is already on the sprite — this is the half the
			# drawing cannot carry: how long until the head is armed again. A
			# player watching a bald Dandelion has no other way to tell a plant
			# that is reloading from one that has nothing to shoot at.
			if dandelion.is_volley_open() and dandelion.fluff() > 0:
				busy = "%d seed(s) up, %.0f dmg a burst." % [
					dandelion.fluff(), Dandelion.SEED_DAMAGE,
				]
			else:
				busy = "Regrowing — %d/%d fluff, armed in %.1fs." % [
					dandelion.fluff(), Dandelion.FLUFF_MAX, dandelion.seconds_until_armed(),
				]
		elif chomp != null and chomp.is_busy():
			busy = "Chewing — %d%% through this one." % int(round(chomp.chew_progress() * 100.0))
		elif sundew != null:
			# A Sundew is never busy and never idle — it is always working, and the
			# only question is how many pests are in the patch. "Idle" was simply
			# the wrong word for the one plant that cannot be.
			busy = "Slowing %d pest(s) to %d%% speed." % [
				sundew.stuck_count(), int(round(StickySundew.SLOW_FACTOR * 100.0)),
			]
		# A plant that grows says which rung it is on, the way the cob's line does.
		# Asked of the plant rather than of `chomp != null`, so the third plant with
		# a ladder needs no branch here.
		if plant.has_upgrades():
			_selection_label.text = "%s — %s\n%s" % [
				PlantCatalog.display_name(plant.kind), plant.level_name(), busy,
			]
		else:
			_selection_label.text = "%s\n%s" % [PlantCatalog.display_name(plant.kind), busy]
	# One decision for every plant, outside the per-class branches that describe
	# them. The three `visible =` assignments this replaces were the reason a second
	# upgradable plant could not be reached: two of them said `false` unconditionally
	# and the third was gated on `as CornCobbler`.
	_upgrade_button.visible = plant.has_upgrades()
	if plant.has_upgrades():
		if plant.is_max_level():
			_upgrade_button.text = "Fully grown"
			_upgrade_button.disabled = true
		else:
			_upgrade_button.text = "Upgrade (%d)" % plant.upgrade_cost()
			_upgrade_button.disabled = (state["bank"] as SeedBank).seeds < plant.upgrade_cost()
	_refresh_health(plant)
	# Armed, the button says what the next click does rather than what the action
	# is called. It stays the same node at the same size — the devtools bridge and
	# the tests press UprootButton by path, and a second button would not fit under
	# SelectionBox anyway (the VBox already runs to within 16px of the panel foot).
	#
	# RESTING, the button now says both halves of the trade — see `uproot_button_text`.
	# The replant price comes off the same SeedBank the panel is already holding, so the
	# free starter's 0 is honoured rather than a flat catalogue price being quoted at a
	# player who would not pay it.
	var refund: int = plant.uproot_refund()
	var replant: int = (state["bank"] as SeedBank).placement_cost(plant.kind)
	if bool(state.get("uproot_armed", false)):
		_uproot_button.text = uproot_armed_text(refund)
		_uproot_button.add_theme_color_override("font_color", UPROOT_ARMED)
	else:
		_uproot_button.text = uproot_button_text(refund, replant)
		_uproot_button.remove_theme_color_override("font_color")
	# Set unconditionally, resting and armed alike: an armed button is the one moment a
	# player most wants the sentence spelled out, and the tooltip is the only place the
	# replant PRICE (rather than the net) is written.
	var tip: String = uproot_button_tooltip(
		PlantCatalog.display_name(plant.kind), refund, replant)
	# Only on change, the same rule the plant buttons follow: a tooltip already on screen
	# is not re-read when its text is reassigned, and this runs on every state push.
	if _uproot_button.tooltip_text != tip:
		_uproot_button.tooltip_text = tip


## The bar under the selection blurb. Appears only once a plant has been bitten,
## and reports the same number the in-world bar draws.
##
## The fill is sized against PANEL_WIDTH - 24 rather than the row's own `size`,
## because a Container child measures 0 wide until the layout pass lands and the
## first refresh after a selection happens before it — reading `_health_row.size.x`
## here drew every freshly-selected plant a zero-width bar for one frame.
func _refresh_health(plant: Plant) -> void:
	var fraction: float = clampf(plant.health / Plant.MAX_HEALTH, 0.0, 1.0)
	if fraction >= 1.0:
		_health_row.visible = false
		return
	_health_row.visible = true
	var full_width: float = float(PANEL_WIDTH - 24)
	_health_fill.size = Vector2(full_width * fraction, HEALTH_ROW_HEIGHT)
	_health_fill.color = health_color(fraction)
	_health_text.text = "Health %d/%d" % [int(ceil(plant.health)), int(Plant.MAX_HEALTH)]


## Puts a line on the status row. Higher `priority` wins ties and can cut a
## lower-priority line short; equal or lower priority waits its turn.
##
## This used to be two assignments, which meant every message destroyed the one
## before it the instant it arrived. The uproot gate made the cost concrete: its
## "click again" instruction is a 4-second read, and any pest dying in that window
## replaced it with a 2-second husk line, leaving the player with an armed button
## and no explanation of why. A message the player cannot finish reading is the
## same as no message.
## Eases the wave readout toward its threat colour instead of snapping.
##
## The tint is reapplied on every refresh — which is many times a second while a
## wave is running — so a fresh Tween per call would stack dozens of them onto one
## property. The live tween is kept and killed, and a target already reached is a
## no-op, which is the common case.
##
## Writes the OUTLINE colour alongside the fill on every step. The wave readout carries
## READOUT_WEIGHT_PLAIN today, so nothing is drawn from it — but a readout's outline is
## its own colour by construction (`_add_stat`), and this is the only label in the row
## whose colour moves at runtime. Keeping the pair in step here is what stops a future
## weight on this row from stranding a cream outline around a red number.
func _ease_threat_tint(target: Color) -> void:
	if not GardenTheme.animations_enabled():
		_tint_wave_label(target)
		return
	if target.is_equal_approx(_threat_tint_target):
		return
	_threat_tint_target = target
	if _threat_tween != null and _threat_tween.is_valid():
		_threat_tween.kill()
	var from: Color = _wave_label.get_theme_color("font_color")
	_threat_tween = create_tween()
	_threat_tween.tween_method(
		func(c: Color) -> void: _tint_wave_label(c),
		from, target, THREAT_FADE_SECONDS)


## The wave readout's fill and its outline, always together. See _ease_threat_tint.
func _tint_wave_label(c: Color) -> void:
	_wave_label.add_theme_color_override("font_color", c)
	_wave_label.add_theme_color_override("font_outline_color", c)


## Carries a swept husk's payout across the screen: a SeedGlyph.launch() from
## `from_screen` (the husk's position, already translated to screen space by
## the caller — see Game._on_husk_collected) to the Seeds label, sized off
## `HuskLayer.radius_for(value)` so the disc reads as the husk it came from.
##
## No-op with animations off, and the no-op is total — the node is never
## created, not created-and-left-static the way an entrance tween's gate
## works elsewhere. This effect has no "final state" to reach: the seeds are
## already banked and the husk already erased by the time the signal that
## calls this fires (CompostMeter.collect_at), so a game that skips the
## flourish loses nothing a player could point at.
func fly_seed_glyph(from_screen: Vector2, value: int) -> void:
	if not GardenTheme.animations_enabled():
		return
	if _fx_layer == null or _seeds_label == null:
		return
	var glyph := SeedGlyph.new()
	_fx_layer.add_child(glyph)
	glyph.launch(from_screen, _seeds_label.get_global_rect().get_center(),
		HuskLayer.radius_for(value))


## The payout / loss / sweep punch: seeds, lives and compost jump to
## READOUT_PUNCH_SCALE and ease back to 1.0, the same killed-and-restarted
## shape _ease_threat_tint already uses for the wave label beside them.
##
## pivot_offset is set on every call rather than once: these three Labels are
## clipped to a fixed width but not a fixed text length, so their rendered
## size can still change between punches and a stale pivot would scale the
## text off-centre.
func _punch_readout(label: Label) -> void:
	if not GardenTheme.animations_enabled():
		return
	var live: Tween = _readout_tweens.get(label)
	if live != null and live.is_valid():
		live.kill()
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE * READOUT_PUNCH_SCALE
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, READOUT_PUNCH_SECONDS)
	_readout_tweens[label] = tween


## THE VALUE THE SEEDS READOUT SHOWS `t` OF THE WAY THROUGH A ROLL.
##
## Pure and static, and that is the whole reason this function exists as something other
## than three lines inside a lambda: **a Tween does not run headless**, so every check
## written against the roll would be a check that never executes. The interpolation is
## the part with a decision in it, so the interpolation is the part that is assertable
## without a HUD, a frame, or a renderer — the same split
## `TitleScreen.high_score_text_at` makes for the record ratchet.
##
## `ceilf` rather than `floorf`, which is the one non-obvious line here: with `floorf`
## the counter sits on `from_value` for the first tenth of the roll, and a readout that
## does not move for 35ms after a purchase reads as a dropped frame rather than as the
## start of a count. With `ceilf` the first step has already landed.
##
## Endpoints are exact by construction: `t <= 0` gives `from_value`, `t >= 1` gives
## `to_value`, and the caller does not have to trust a float to land on 1.0.
##
## SIGNED, and that is the difference from the record. A record only ever climbs, so
## `_arm_record_ratchet` never had to decide what a fall looks like. Seeds fall on every
## purchase — and the purchase is the case the bead was filed about — so this lerps in
## whichever direction the pair points and the count runs DOWN for a spend. A roll that
## only ever went up would animate the payouts and leave every price the player pays
## snapping, which is backwards: the payout is expected and the spend is the decision.
static func seeds_roll_value(from_value: int, to_value: int, t: float) -> int:
	var steps: float = float(SEED_ROLL_STEPS)
	var stepped: float = ceilf(clampf(t, 0.0, 1.0) * steps) / steps
	return int(round(lerpf(float(from_value), float(to_value), stepped)))


## Is this change big enough to be worth watching arrive? See SEED_ROLL_MIN_JUMP.
## Symmetric in the two directions on purpose — a 45-seed spend and a 45-seed payout are
## the same size of event.
static func seeds_roll_is_worth_showing(from_value: int, to_value: int) -> bool:
	return absi(to_value - from_value) >= SEED_ROLL_MIN_JUMP


## Counts the seeds readout from its old total to the one it already displays.
##
## Layered on top of an already-correct Label, gated on `animations_enabled()`, and
## restored by a callback rather than by trusting the last interpolation step — a tween
## interrupted mid-count (a scene change, another purchase) never runs its final step,
## and the readout would keep whatever number it was passing through.
func _arm_seeds_roll(from_value: int, to_value: int) -> void:
	if not GardenTheme.animations_enabled() or _seeds_label == null:
		return
	# Killed before the size test, not after: a small change arriving mid-roll must STOP
	# the roll rather than let it keep counting toward a total that is already stale.
	if _seeds_roll != null and _seeds_roll.is_valid():
		_seeds_roll.kill()
	_seeds_roll = null
	if not seeds_roll_is_worth_showing(from_value, to_value):
		return
	var settled: String = "Seeds  %d" % to_value
	var roll := func(t: float) -> void:
		if not is_instance_valid(_seeds_label):
			return
		var rolled: String = "Seeds  %d" % seeds_roll_value(from_value, to_value, t)
		_seeds_label.text = rolled
	var restore := func() -> void:
		if is_instance_valid(_seeds_label):
			_seeds_label.text = settled
	var tween := create_tween()
	var counting: MethodTweener = tween.tween_method(roll, 0.0, 1.0, SEED_ROLL_SECONDS)
	counting.set_trans(Tween.TRANS_CUBIC)
	counting.set_ease(Tween.EASE_OUT)
	tween.tween_callback(restore)
	_seeds_roll = tween


## A refused plant placement, shaking the bar slot the player picked it from —
## not the board cell they clicked, which is where the refusal actually fired
## (see Game._click_at). The slot is what the player is looking at when a
## click on the board comes back with nothing: the seeds it would have cost,
## the lock icon, whatever made this one unaffordable right now.
func shake_plant_button(id: StringName) -> void:
	_shake_control(_plant_buttons.get(id) as Control)


## A refused packet buy, shaking the actual button the player clicked.
##
## Keyed rather than branched. The old form — `rare ? rare_button : common_button`
## — had no way to be wrong with two tiers and exactly one way to be wrong with
## three: an epic refusal would have shaken the common button, which is a cue
## pointing at the wrong purchase.
func shake_packet_button(tier: StringName) -> void:
	_shake_control(_packet_buttons.get(tier) as Control)


## A refused plant upgrade, shaking the Upgrade button itself — unlike a plant
## placement refusal (see shake_plant_button), the control the player reached
## for and the control that answers "no" are the same one here.
func shake_upgrade_button() -> void:
	_shake_control(_upgrade_button)


## The denial cue itself: a few degrees left, right, and back to rest. See
## DENIAL_SHAKE_SECONDS for why this animates `rotation` and not `position`.
func _shake_control(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	if not GardenTheme.animations_enabled():
		return
	var live: Tween = _shake_tweens.get(control)
	if live != null and live.is_valid():
		live.kill()
	control.pivot_offset = control.size / 2.0
	control.rotation = 0.0
	var rad: float = deg_to_rad(DENIAL_SHAKE_DEGREES)
	var beat: float = DENIAL_SHAKE_SECONDS / 4.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "rotation", -rad, beat)
	tween.tween_property(control, "rotation", rad, beat)
	tween.tween_property(control, "rotation", -rad * 0.5, beat)
	tween.tween_property(control, "rotation", 0.0, beat)
	_shake_tweens[control] = tween


## A short rise as the selection panel opens.
##
## Scale is deliberately not touched: SelectionBox is a VBoxContainer child of a
## ColorRect, and Godot re-applies a container's layout every frame, which silently
## resets a scaled child — the documented trap in this project's own notes. Position
## on a non-container child is safe, and modulate is safe anywhere.
func _play_panel_entrance() -> void:
	if not GardenTheme.animations_enabled():
		return
	var rest: Vector2 = _selection_box.position
	_selection_box.position = rest + Vector2(0, PANEL_RISE)
	_selection_box.modulate = Color(1, 1, 1, 0)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_selection_box, "position", rest, PANEL_RISE_SECONDS)
	tween.tween_property(_selection_box, "modulate", Color.WHITE, PANEL_RISE_SECONDS)


## The ONE place `_message_label.text` is assigned. A transient message wins while it
## has time left; the standing note is the floor.
## Every Control on this HUD a player can reach, in one place
## (plant-tower-defense-csrc).
##
## Collected rather than listed: the plant bar and the packet bar are built from
## catalogue tables, so a plant added to `PlantCatalog.PLANTS` arrives here without
## anyone remembering to add it to a list of buttons to disable.
func interactive_controls() -> Array[Button]:
	var out: Array[Button] = []
	for button: Variant in _plant_buttons.values():
		if button is Button:
			out.append(button)
	for button: Variant in _packet_buttons.values():
		if button is Button:
			out.append(button)
	for button: Button in [_next_wave_button, _speed_button, _upgrade_button, _uproot_button]:
		if button != null and is_instance_valid(button):
			out.append(button)
	return out


## Makes the whole HUD inert while something is open over it, and live again after.
##
## **Focus and the mouse are two channels and both have to go.** The overlays that
## open over this HUD all carry a full-viewport MOUSE_FILTER_STOP backdrop, so a
## player cannot CLICK a plant button through the pause card -- and Tab or an arrow
## key walks straight onto one, because focus does not care what is drawn on top.
## That is the same hazard `OverlayScreen`'s class header documents, and the same fix
## `PauseScreen._set_card_active` and `TitleScreen._set_menu_active` already apply to
## their own buttons. Nothing applied it to the HUD, which is a different CanvasLayer
## and therefore nobody's child.
##
## The mouse filter goes too, for the reason TitleScreen gives: the backdrops are 0.88
## alpha, so a button still tracking the cursor underneath lights up in its hover
## colour and the glow shows through the paper.
##
## Found by `findings` reporting `interactive_overlap` between this HUD's buttons and
## an overlay's, after an unrelated change widened that overlay by 14px. The overlap
## was the symptom; this was the defect, and it was several cycles old.
func set_active(active: bool) -> void:
	var mode: Control.FocusMode = Control.FOCUS_ALL if active else Control.FOCUS_NONE
	var filter: Control.MouseFilter = (Control.MOUSE_FILTER_STOP if active
		else Control.MOUSE_FILTER_IGNORE)
	for button: Button in interactive_controls():
		button.focus_mode = mode
		button.mouse_filter = filter


func _paint_message_row() -> void:
	_message_label.text = _message_text if _message_left > 0.0 else _idle_message
	# The one place a line's LOOK is decided, for the same reason this is the one place
	# its text is. Three writers of `_message_label.text` was the bug this function
	# replaced; three writers of its emphasis would be that bug again in a new channel.
	_apply_message_stress(message_is_stressed(_message_left, _message_priority))


## Whether the line the row is showing right now is one the player must read.
##
## Static and pure so the rule is assertable without a live row — the same shape
## `line_was_read` above takes, and for the same reason. The `seconds_left > 0.0` half
## is not decoration: with no transient line the row falls through to `_idle_message`,
## and the standing prep note is ambient however important the line it replaced was.
##
## MESSAGE_DEADLINE is stressed too, and deliberately by `>=` rather than by naming the
## two rungs. DEADLINE is the armed-uproot prompt — the line this whole bead is about —
## and a fourth rung added above it would be stressed by default, which is the right
## default for a rung somebody thought was worth adding above DEADLINE.
static func message_is_stressed(seconds_left: float, priority: int) -> bool:
	return seconds_left > 0.0 and priority >= MESSAGE_IMPORTANT


## Applies the two non-colour channels of MESSAGE_STRESS_OUTLINE. Never touches
## `font_color`: the whole claim is that these two states are told apart in greyscale,
## and a hue difference here would be the thing that lets the claim rot.
func _apply_message_stress(stressed: bool) -> void:
	_message_label.add_theme_constant_override("outline_size",
		MESSAGE_STRESS_OUTLINE if stressed else 0)
	if _message_mark != null:
		_message_mark.visible = stressed


## Returns whether `text` is ON THE ROW when this call returns — false when it was
## queued behind something, and false when the queue was full and dropped it.
##
## The return value exists because a caller could not previously tell those apart. Of
## the 17 call sites under `game/`, 15 ignore it and are right to; the two that must
## not are one-shot HINTS,
## which is spent on the player having SEEN something. `_queue_message` drops the
## lowest-priority entry when the queue is full and drops the NEW one if it is the
## lowest — silently, and this method returned void. So "I called show_message" and
## "the player read it" were the same expression, which is cycle 79's bug one level
## further down: that one spent a hint on the game deciding to show a tip, and a later
## change displaced the sentence.
##
## Deliberately false for a queued message rather than optimistic about it. A queued
## line can still be dropped later by a fuller queue, so a hint spent on "it will
## appear" is a hint that can still be lost. False means the caller keeps the hint owed
## and offers it again next time the moment comes round, which is the behaviour a
## one-shot the player is owed should have.
## Whether the row would SHOW a line posted right now, rather than queueing it behind
## something the player is still reading.
##
## Exists because of a defect this nearly shipped (plant-tower-defense-gz53), and the
## distinction it draws is between two kinds of caller rather than two kinds of message.
## `show_message` returns false while the current line is still readable — but it QUEUES
## the arriving text rather than dropping it. An EDGE-triggered caller is fine with that:
## `_on_flight_ignored` fires once per winged pest and a queued copy is the line it meant.
##
## A LEVEL-triggered caller is not. The upgrade tip is offered from `Game._refresh`, which
## runs on every purchase, uproot, plant death and wave change, so a `false` return
## followed by another refresh stacks a SECOND copy into the queue, then a third, until
## `MESSAGE_QUEUE_MAX` refuses the rest — a one-shot hint shown four times, which is the
## wallpaper the whole one-shot mechanism exists to prevent.
##
## So a level-triggered hint asks this first, and a busy row means "not this refresh"
## rather than "spend the hint". The queue is checked as well as the row: a line waiting
## behind the current one will take the row next, and posting into that is the same
## stacking one step later.
func row_is_quiet() -> bool:
	return _message_left <= 0.0 and _message_queue.is_empty()


func show_message(text: String, seconds: float = 3.0, priority: int = MESSAGE_NORMAL) -> bool:
	if _message_left > 0.0:
		if priority > _message_priority:
			messages_preempted += 1
			if line_was_read(_message_total, _message_left):
				# Retired rather than queued. See line_was_read.
				messages_retired += 1
			else:
				_queue_message(_message_text, _message_left, _message_priority)
		elif _message_left > MESSAGE_MIN_READABLE or priority < _message_priority:
			# The line on screen has not been up long enough to have been read, or
			# outranks this one. Wait rather than stomp.
			_queue_message(text, seconds, priority)
			return false
	_message_text = text
	_message_left = seconds
	_message_total = seconds
	_message_priority = priority
	_paint_message_row()
	return true


## The queue is deliberately short. Messages describe things happening now, and a
## backlog long enough to outlive its own subject is worse than a dropped line —
## it puts stale narration over a board that has moved on. When it is full the
## lowest-priority entry is dropped, so an important line still gets in.
## What a full queue does with an arriving message. Three outcomes and two of them lose a
## line, which is the whole reason this is named rather than left inline.
const QUEUE_ACCEPTED := "accepted"
const QUEUE_EVICTED := "evicted"
const QUEUE_REFUSED := "refused"


## Which of the three happens when a message of `arriving` priority reaches a queue already
## holding `queued`.
##
## Pure and static so the rule can be asserted without staging four messages through a live
## HUD — and because the interesting cases are the ones a live HUD makes hardest to reach.
## Note the `>=`: on a TIE the arriving message is refused, which matters more here than
## anywhere else because 14 of the game's 17 `show_message` call sites pass no priority at
## all and therefore all tie. (The three that do: `Hud.MESSAGE_DEADLINE` on the armed
## uproot, and `Hud.MESSAGE_IMPORTANT` on both halves of the packet reveal.)
static func queue_outcome(queued: Array[int], arriving: int) -> String:
	if queued.size() < MESSAGE_QUEUE_MAX:
		return QUEUE_ACCEPTED
	return QUEUE_REFUSED if _lowest_of(queued) >= arriving else QUEUE_EVICTED


static func _lowest_of(queued: Array[int]) -> int:
	var lowest: int = queued[0]
	for p: int in queued:
		if p < lowest:
			lowest = p
	return lowest


## Lines the row never showed, split by which way they were lost. Read with `get-state`;
## `cmd budgets` prices what the row can HOLD and these count what it actually dropped.
##
## Two counters and not one, because they are different failures with different fixes. A
## REFUSED message is one the caller just posted and the player will never see — the caller
## thinks it said something. An EVICTED one was already waiting and got pushed out by
## something more urgent, which is the queue working as designed right up until the evicted
## line was the one that mattered.
var messages_refused: int = 0
var messages_evicted: int = 0

## Times a line already ON the row was displaced by something more urgent and pushed back
## into the queue. The upper bound on how often a player can see the same sentence twice,
## which is the question `-gtne` is about — a resumed line is restored by assigning
## `_message_text` (`_advance_message_queue`) and marked in no way, so it is indistinguishable
## from the same event happening again.
##
## Counted separately from `messages_refused` because a pre-emption is not a loss: the line
## comes back, with the time it had left. It is only a *problem* when the player had already
## read it, and this counter is what says whether that situation arises at all.
var messages_preempted: int = 0

## Displaced lines the row deliberately did NOT bring back, because the player had already
## had `MESSAGE_MIN_READABLE` seconds with them. A subset of `messages_preempted`.
##
## This is a discard and it is counted like every other one this row makes -- but unlike
## `messages_refused` it is not a loss, it is a decision. Bringing back the tail of a line
## the player has read teaches nothing and makes the same sentence appear twice, which reads
## as two events rather than one.
var messages_retired: int = 0

## How long the line currently on the row was given. Paired with `_message_left` so
## `line_was_read` can be asked; there is no other way to know, since the row stores only a
## countdown.
var _message_total: float = 0.0


func _queue_message(text: String, seconds: float, priority: int) -> void:
	var queued: Array[int] = []
	for entry: Dictionary in _message_queue:
		queued.append(int(entry["priority"]))
	match queue_outcome(queued, priority):
		QUEUE_REFUSED:
			messages_refused += 1
			return
		QUEUE_EVICTED:
			messages_evicted += 1
			_message_queue.remove_at(queued.find(_lowest_of(queued)))
	_message_queue.append({"text": text, "seconds": seconds, "priority": priority})


## What the next wave is worth, shown in the message row for the whole prep gap
## (plant-tower-defense-arkk).
##
## The prep gap is where the player decides what to buy, and the decision is "can I
## afford to be wrong". Until now the only thing describing the coming wave was the
## prep strip's colour, which answers "how much" and not "in what way" -- and the
## wave-cleared banner, which fades.
##
## **It goes in the message row rather than on a new readout**, for two reasons. The
## top bar is measurably full (10px in the wave slot, 19 in the row -- see
## `WORST_CASE_TEXT`), and this line is a message: "here is what is coming" is the
## same kind of thing as "composted a husk for 6 seeds". It is the row's IDLE state,
## so any real message still wins for as long as it lasts and the note comes back
## when the queue drains.
func _refresh_prep_note(state: Dictionary) -> void:
	if bool(state.get("wave_live", false)) or not bool(state.get("more_waves", false)):
		# Drop the claim and repaint. This used to have to ask whether the line on the
		# row was OURS -- by comparing the Label's text against `_idle_message` -- and
		# that question is gone: a claim nobody holds cannot be painted, and a message
		# that happens to read the same as the note is no longer indistinguishable
		# from it.
		_idle_message = ""
		_paint_message_row()
		return
	_idle_message = next_wave_note(
		int(state.get("wave", 0)) + 1,
		int(state.get("next_wave_pests", 0)),
		bool(state.get("next_wave_boss", false)),
		StringName(state.get("next_weather", WaveDirector.WEATHER_CLEAR)),
		bool(state.get("next_wave_is_last", false)))
	# The painter decides whether this reaches the row: a real message outranks the
	# standing note for as long as it lasts. `_advance_message_queue` repaints when
	# the queue drains, which is the path this function cannot cover -- `refresh()` is
	# called on state CHANGES and a message expiring is not one.
	_paint_message_row()


## Pure, so the wording is assertable without building a HUD.
##
## Says the pest count only when it is known: past the fixed table the next wave's
## schedule does not exist yet (`pests_in_wave` returns 0 there), and "0 pests" would
## be a confident lie about the hardest waves in the game rather than an absence.
##
## Names the boss and the weather because those are what change the SHAPE of a wave --
## the threat number already on the prep strip answers how much, and a player deciding
## between damage and coverage needs to know a boss is coming, not that the number
## went up.
static func next_wave_note(number: int, pests: int, boss: bool, weather: StringName,
		last: bool = false) -> String:
	var parts: PackedStringArray = []
	# Finality first. It is the one fact here that changes what the whole run is
	# about, and a player skimming a line reads its front.
	if last:
		parts.append("the last one")
	if pests > 0:
		parts.append("%d pests" % pests)
	if boss:
		# "a boss", not "a queen", since plant-tower-defense-gsai: waves 17 and 19 carry a
		# Nurse Beetle and `wave_carries_boss` is derived from a `boss` flag on the species
		# row now, so naming the Queen here was a sentence that had become false on two
		# waves. Narrower than the old text, so no width budget moves.
		parts.append("a boss")
	if weather == WaveDirector.WEATHER_RAIN:
		# The gift named where the player can still act on it
		# (plant-tower-defense-kmjp). The banner says it too, but the banner fires
		# from Game._on_wave_started -- AFTER the seeds are spent. This is the
		# surface they read while deciding, and until now it said "rain" and nothing
		# else, which made the only free upside in the game the only one nobody was
		# told about in time to use it. Twenty characters against the drought
		# clause's twenty-four, so no width budget moves and the corpus sample below
		# is still the worst case.
		parts.append("rain · beds mend %d%%"
			% int(round(WaveDirector.WEATHER_RAIN_HEAL_FRACTION * 100.0)))
	elif weather == WaveDirector.WEATHER_DROUGHT:
		# The bonus is named here because a payout the player cannot see is not a
		# rule, it is a coincidence they might notice (plant-tower-defense-4c1l).
		# The banner says what a drought COSTS; the prep note is where they decide
		# what to buy, so it is where the compensation belongs.
		parts.append("drought · pests pay %d%%"
			% int(round(WaveDirector.WEATHER_DROUGHT_SEED_BONUS * 100.0)))
	if parts.is_empty():
		return "Wave %d next." % number
	return "Wave %d next — %s." % [number, " · ".join(parts)]


func _advance_message_queue() -> void:
	if _message_queue.is_empty():
		# Drop the transient claim and repaint, which falls through to the standing
		# note. Found in the running game: the note was correct on every `refresh()`
		# and the row went empty seconds later, because `refresh()` is driven by state
		# CHANGES and a message expiring is not one.
		_message_text = ""
		_message_priority = MESSAGE_NORMAL
		_paint_message_row()
		return
	# Highest priority first, earliest among equals — not simply the front. A
	# strict FIFO left an urgent line waiting behind whatever ambient chatter
	# happened to queue ahead of it, which is the same failure as stomping it,
	# only slower.
	var pick: int = 0
	for i: int in range(_message_queue.size()):
		if int(_message_queue[i]["priority"]) > int(_message_queue[pick]["priority"]):
			pick = i
	var next: Dictionary = _message_queue[pick]
	_message_queue.remove_at(pick)
	_message_text = String(next["text"])
	_message_left = float(next["seconds"])
	# The restored line keeps its REMAINING time as its whole allowance, so "how long
	# has this been up" stays answerable for a line that has already been interrupted
	# once. Without this a twice-interrupted line would look freshly posted.
	_message_total = float(next["seconds"])
	_message_priority = int(next["priority"])
	_paint_message_row()


## What is on the status row and what is waiting behind it. Read by the tests —
## a queue whose contents cannot be inspected can only be checked by watching a
## Label over time, which is exactly the kind of check that never gets written.
func pending_messages() -> int:
	return _message_queue.size()


## The headline half of a wave banner. Static and pure so every branch is
## assertable without standing up a HUD — same reason `threat_color` is.
static func wave_headline(number: int) -> String:
	return "Wave %d" % number


## The detail half. `note` is WaveDirector.escalation_note(), which is empty
## inside the fixed table where the table itself is the escalation.
static func wave_note(pests: int, note: String) -> String:
	if note == "":
		return "%d pests" % pests
	return "%d pests — %s than the last" % [pests, note]


## The headline half of the wave-cleared banner. A distinct string from
## wave_headline rather than the same one twice — a player glancing up mid-fade
## needs to tell "here it comes" from "you held it" without reading the note
## underneath, and the two headings this mirrors (RunSummary's win/loss text)
## make the same distinction for the same reason.
static func wave_cleared_headline(number: int) -> String:
	return "Wave %d cleared" % number


## The detail half. Bounded the same way wave_note() is — `pests` is a wave's
## own pest count, and BANNER_WORST_CASE_TEXT pins "9999" as the ceiling both
## budgets are measured against.
static func wave_cleared_note(pests: int) -> String:
	return "%d pests turned back." % pests


## What the prep window says about the run, in the one place the board cannot.
##
## The tint on the road is a recency map: the last wave that drew blood at full
## strength over the faded remains of the ones before it. That answers "where did
## it break", and during prep it is the right thing to be staring at. What it
## structurally cannot answer is whether this wave was *worse than usual* —
## because it is one alpha channel, on one road, at 64px a cell, and a second
## ramp of the same DANGER red over the same cells is a blend no eye can
## decompose back into two readings. That comparison is one number against one
## number, so it belongs in text rather than in paint.
##
## Depth rather than a cell name: this board has a single road (see
## Board.depth_of), so "which lane" is not a question it can pose, and "column
## 10, row 2" names a spot the player has no reason to think of as a place.
##
## Empty when either reading is absent — Board.depth_of returns -1.0 for
## "nothing recorded", which is not the same as a wave killed dead on the entry
## cell at 0%.
static func prep_depth_note(last_wave: float, run: float) -> String:
	if last_wave < 0.0 or run < 0.0:
		return ""
	var now: int = int(round(clampf(last_wave, 0.0, 1.0) * 100.0))
	var usual: int = int(round(clampf(run, 0.0, 1.0) * 100.0))
	if last_wave > run + PREP_DEPTH_BAND:
		return "Pests got %d%% down the road — deeper than the run's %d%%." % [now, usual]
	if last_wave < run - PREP_DEPTH_BAND:
		return "Pests got %d%% down the road — shallower than the run's %d%%." % [now, usual]
	return "Pests got %d%% down the road, the run's usual depth." % now


## The four messages whose length is DATA rather than prose
## (plant-tower-defense-m1el).
##
## Every other line this row shows is a fixed literal: it is as long as it will ever
## be, and anyone can see it. These four interpolate a plant's display name or a corn
## level's name, so they grow when the CONTENT grows -- a plant added with a long name
## silently clips a message nobody re-measured, in a Label with `clip_text` set.
##
## They live here rather than at their call sites in `game.gd` for one reason: a test
## can then sweep the whole catalogue through them and measure the result.
## `test_no_message_clips_for_any_plant_in_the_catalogue` does exactly that, so the
## budget is checked against every name the game can actually produce rather than
## against a worst case someone typed out and hoped was still the worst.
## Every string this row can be asked to hold, at its widest, in ONE place.
##
## `_budget_hud_message_row` used to enumerate this by reading `show_message()`
## call sites, and got it wrong in three consecutive cycles — each time adding
## only the producer that happened to be in view, and each time leaving behind a
## comment stating a call-site count that was already false. The count it last
## claimed was eight; there are fourteen. A corpus recovered by grep is a corpus
## that will be recovered again, differently, by whoever greps next.
##
## So it lives here, beside the producers it names, and the budget reads it. The
## bare literals are copied rather than referenced because `show_message("...")`
## takes a literal at the call site and there is nothing else to point at — which
## is precisely why `tools/message_corpus_check.py` exists to compare the two.
## Format strings go in filled to their widest ("%d" -> "99999"); that checker
## compares shapes, not text.
##
## NOT in here, and deliberately:
##   * purchase refusals (`SeedBank.purchase_failed`) and placement refusals —
##     their text is assembled from data no static caller can reach;
##   * the `"...%s?"` packet flash, whose width is a plant name already bounded
##     by `packet_message()` and three characters.
## Both are waived at their call sites with a reason, because a corpus that
## quietly omits something is the defect this function exists to end.
static func message_corpus() -> Array[String]:
	var out: Array[String] = []
	for id: StringName in PlantCatalog.PLANTS:
		var display: String = PlantCatalog.display_name(id)
		out.append(eaten_message(display))
		# BOTH forms of the armed prompt. The tip is shown once per save and the
		# bare warning every time after, so both reach this row and both have to be
		# priced — a corpus holding only the short one would report the row as
		# roomier than it is on the single most important message in the game, and
		# only for the first player who ever arms an uproot.
		# THREE forms since cycle 79, not four: bare, with the tip, and with the
		# forfeit clause — the last two cannot co-occur (see uproot_armed_message,
		# where the budget is what decided that). Priced at the LADDER'S maximum via
		# `CornCobbler.upgrade_spend(LEVELS.size())`, because a budget is about the
		# worst case the format allows, and because a hand-typed 65 here would be the
		# second source of truth `upgrade_spend` exists to avoid.
		out.append(uproot_armed_message(display, false))
		out.append(uproot_armed_message(display, true))
		# The widest forfeit across every ladder in the game, not the cob's. The
		# Chomp Flower's full climb is 70 against the cob's 65, so pricing corn alone
		# would leave the row's budget five seeds' worth of glyphs short of the
		# longest line it can actually be asked to show.
		out.append(uproot_armed_message(display, false,
			maxi(Plant.ladder_spend(CornCobbler.LEVELS, CornCobbler.LEVELS.size()),
				Plant.ladder_spend(ChompFlower.LEVELS, ChompFlower.LEVELS.size()))))
		out.append(packet_message(display))
		# The upgrade hint, priced per plant name and at a cost the ladders cannot
		# reach. Every plant gets a row because the tip names whichever plant on the
		# board is cheapest to upgrade, and that is a fact about the player's garden
		# rather than about the catalogue — any name in PLANTS can appear here.
		out.append(upgrade_tip(display, 99999))
	for level: Dictionary in CornCobbler.LEVELS:
		out.append(upgrade_message(PlantCatalog.display_name(PlantCatalog.CORN), String(level["name"])))
	for level: Dictionary in ChompFlower.LEVELS:
		out.append(upgrade_message(PlantCatalog.display_name(PlantCatalog.CHOMP), String(level["name"])))
	# Every field at its maximum: a wave number nothing will reach and a pest
	# count the table cannot produce. A budget is about the worst case the FORMAT
	# allows, not the worst the game is expected to reach.
	# message-corpus-check: ok - both bools only ever parts.append(), never substitute
	# or shorten, so (boss, last) = (true, true) strictly dominates the other three
	# combinations and pricing them would add three shorter strings for nothing.
	# Checked in the body above rather than assumed: `if last: parts.append("the last
	# one")` and `if boss: parts.append("a boss")`. If either flag ever CHANGES a
	# clause instead of adding one, delete this waiver — the checker will then be
	# right and this comment will be the reason it was ever wrong.
	out.append(next_wave_note(999, 9999, true, WaveDirector.WEATHER_DROUGHT, true))
	out.append(wave_cleared_line(999, wave_cleared_note(9999)))
	# The literals, from their call sites in game.gd.
	out.append("Plant your free Corn Cobbler on the grass, then grow the first wave.")
	out.append("That upgrade costs 99999 seeds.")
	out.append("Uproot cancelled.")
	out.append("Composted a husk for 99999 seeds.")
	# Both halves of the ternary at game.gd:1484. "off." is the wider of the two,
	# but the checker reads the LEADING literal of a ternary, so a corpus holding
	# only the wider one reports the call site as uncovered. Carry both.
	out.append("Colourblind-safe bars off.")
	out.append("Colourblind-safe bars on.")
	out.append(flight_tip())
	return out


## Said once ever, the first time a Chomp is walked over by something it cannot catch.
##
## A zero-argument PRODUCER rather than a `const`, which is not a style choice: the
## corpus mechanism resolves producer calls and literals, and `message_corpus_check`
## reported a bare `out.append(FLIGHT_TIP)` as a call site calling none of the corpus's
## producers. A const reference is invisible to the row's budget — the thing four cycles
## went into measuring — and the alternative was pasting the sentence into the corpus as
## a second copy. Six producers already sit beside this one; the outlier was the const.
##
## The plant is deliberately unnamed:
## the player is looking at the plant, and "your Chomp Flower" would spend width on the
## half they can already see to say less about the half they cannot.
##
## "flies over" and not "cannot be caught": the first says what the bug is doing, which
## is the observable the player has in front of them and the thing the wing markers on
## its silhouette (`Pest.MARKER_WINGS`) already point at. Corn is named because the
## sentence is useless without the answer — a rule with no counter-play is a
## complaint — and Corn genuinely takes winged pests (`chomp_flower.gd:83-85` names
## exactly that).
static func flight_tip() -> String:
	return "That pest flies over Chomp Flowers. Corn Cobblers can still hit it."


## Said once ever, the first time the player can actually afford an upgrade on their
## own board (plant-tower-defense-gz53).
##
## The plant IS named here, where `flight_tip` above deliberately does not name one,
## and the difference is what the player is looking at. The flight tip fires while
## they watch a specific bug walk over a specific mouth; this one fires on a bank
## balance, with nothing highlighted and seven plants possibly down. "Your plant can
## be upgraded" would leave them hunting.
##
## "Click it on the board" and not "select it": the button appears only while a
## PLACED plant is selected, and the thing a player does not know is that a plant
## already in the ground is clickable at all. The plant bar on the side panel is the
## only clicking the opening tutorial teaches, so the sentence has to say where.
##
## The price is here because it is the half that makes it a decision rather than an
## instruction — a player holding 40 seeds reads "25" and knows they can do this AND
## still buy something.
static func upgrade_tip(plant_name: String, cost: int) -> String:
	return "Your %s can be upgraded. Click it on the board — %d seeds." % [plant_name, cost]


## THE HINT CARDS: the same three interactions the one-shot tips teach, written for a
## reader who is not in the moment (plant-tower-defense-ei83).
##
## Every id in `RunConfig.HINTS` is shown exactly once per save and then never again,
## which is right — a tip that becomes wallpaper is worse than no tip. The cost of that
## rule is that a player who was looking at the board when the row posted has no route
## back to it, and `spend_hint` makes the loss permanent by design. This table is the
## route back. It is the CONTENT half only: the surface that renders it is the
## notebook's, and building a second one in the HUD would spend the row this project
## has measured for four cycles on a thing the player is not currently doing.
##
## HERE, beside `flight_tip` and `upgrade_tip`, rather than in a `game/hints.gd` of its
## own mirroring `game/milestones.gd`. The milestone parallel is real and a separate
## file is the tidier shape, but these are two renderings of ONE fact each, and the
## failure that matters is the two disagreeing — a notebook that teaches a rule the row
## states differently is worse than either alone. The sentences the row says are in this
## file, so the sentences the notebook says are too, and a change to one has the other
## in the same diff.
##
## The card is NOT the tip's own sentence. `flight_tip()` is written for a player
## watching a specific bug walk over a specific mouth and leans on that; a notebook
## reader has no bug in front of them. Same rule, two audiences, so two strings — the
## suite asserts they agree about the mechanic, not that they match.
##
## Ids are literals here for the reason `Milestones.TABLE`'s are: `RunConfig` is an
## autoload with no `class_name`, so `RunConfig.HINT_MOVE_PREVIEW` is an instance read
## and cannot initialise a `const`. The drift that buys is closed by the gate rather
## than by the compiler — `test_every_hint_has_a_notebook_card` walks `RunConfig.HINTS`
## and fails on an id with no card AND on a card with no id, so a fourth hint added to
## the list arrives here or fails the suite.
const HINT_CARDS: Array[Dictionary] = [
	{
		"id": "seen_move_tip",
		"title": "Compare before you dig",
		"note": "With Uproot armed, hover another bed to see what the plant would reach there. Confirming still only uproots.",
	},
	{
		"id": "seen_flight_tip",
		"title": "Some pests fly over",
		"note": "A winged pest passes a Chomp Flower untouched. Corn Cobblers can still hit it.",
	},
	{
		"id": "seen_upgrade_tip",
		"title": "Plants already down can grow",
		"note": "Click a plant on the board to select it, then Upgrade. Climbing one plant beats adding another.",
	},
]


## Every hint id, in `RunConfig.HINTS` order — which is the list's order and not this
## table's, deliberately. `HINTS` is what `spend_hint` guards against, so it is the set
## that decides what a hint IS; a page rendered off `HINT_CARDS` instead would happily
## show a card for an id the persistence layer no longer knows about.
## Built element by element rather than returned as `RunConfig.HINTS.duplicate()`:
## `duplicate()` is declared `-> Array`, so handing it back as `Array[String]` leans on
## an implicit conversion this project has no compile gate running to confirm.
static func hint_ids() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in RunConfig.HINTS:
		out.append(String(id))
	return out


## The card row for `id`, or an empty Dictionary. Shaped like `Milestones.entry()` so a
## caller that already renders milestone rows needs no second idiom.
static func hint_entry(id: String) -> Dictionary:
	for row: Dictionary in HINT_CARDS:
		if String(row["id"]) == id:
			return row
	return {}


## Falls back to the raw id rather than to "", exactly as `Milestones.title_of` does: a
## hint with no card must be VISIBLE on the page as an untitled row, not silently absent
## from a list whose whole job is completeness.
static func hint_title(id: String) -> String:
	var row: Dictionary = hint_entry(id)
	return String(row["title"]) if row.has("title") else id


## What a hint row's second line says, and whether the game has spent it yet.
##
## Mirrors `NotebookScreen.shelf_note_text` down to the prefix, for the same reason it
## has one: the state has to survive the colour being thrown away. "A winged pest passes
## a Chomp Flower untouched" and "Not shown yet — a winged pest passes a Chomp Flower
## untouched" are the same fact in two tenses, so a greyed row is legible as greyed
## without hue.
##
## The note reads in full in BOTH states, which is the entire bead: the shelf hides
## nothing behind earning, and a hint the player never saw must be as readable as one
## they did. The prefix says who has seen it, never what it is.
static func hint_note_text(id: String, shown: bool) -> String:
	var row: Dictionary = hint_entry(id)
	var note: String = String(row["note"]) if row.has("note") else ""
	if shown or note.is_empty():
		return note
	return "Not shown yet — %s%s" % [note.substr(0, 1).to_lower(), note.substr(1)]


static func eaten_message(plant_name: String) -> String:
	return "A hungry pest ate your %s!" % plant_name


## The armed prompt, and the only thing that tells a player the move preview
## exists (plant-tower-defense-j80m).
##
## "Hover elsewhere to compare" and NOT "hover to move it": while the window is
## open the hover shows what this plant would reach at another cell, which is a
## comparison. Confirming still only uproots — whether a move should be a single
## action, and what it should cost, is an open decision
## (plant-tower-defense-h5w6). A prompt promising a move the game cannot perform
## would be worse than the silence it replaces.
##
## The warning survives the addition, and has to: this is the sentence standing
## between a player and an irreversible act. It leads with the destructive verb
## and keeps "it will not grow back" rather than trading that away for the tip.
## `forfeited` is seeds already spent upgrading this plant, which `uproot_refund()` does
## not pay back — it scales the plant's BASE cost (`game/plant.gd:541-544`). Said only
## when there is something to forfeit: on a fresh plant the clause would be noise on the
## row this project has spent four cycles measuring, and on an upgraded one it is the
## difference between a plausible number and an informed decision.
##
## **The forfeit and the tip are mutually exclusive, and the budget decided that, not
## taste.** Both together on the longest plant name measured 1064 px against the row's
## 876 — `check_budgets` refused the build with 188 px of overrun and named the exact
## string. So the row carries at most one extra clause, and the one about money wins: the
## tip is a courtesy shown once per save, the forfeit is a fact about the irreversible
## click the player is being asked to make right now.
static func uproot_armed_message(plant_name: String, with_tip: bool = false,
		forfeited: int = 0) -> String:
	var warning: String = ("Click Uproot again to dig up your %s — it will not grow back."
		% plant_name)
	if forfeited > 0:
		return warning + " Its %d upgrade seeds are not refunded." % forfeited
	if uproot_shows_tip(with_tip, forfeited):
		return warning + " Hover to compare a new spot."
	return warning


## Whether the armed prompt will actually carry the move tip.
##
## The precedence lives in one function because **two callers need it**: this file to
## compose the sentence, and `Game.arm_uproot` to decide whether to spend the one-shot
## milestone that gates it. Cycle 79 had `Game` re-derive it — it recorded
## `HINT_MOVE_PREVIEW` whenever the player had not seen the tip, and cycle 79's own forfeit
## clause then displaced the tip, so a first-ever uproot on an upgraded plant burned the
## hint without ever showing it. Permanently, and on the *likely* path: uprooting something
## cheap is not a decision worth a four-second prompt, so a player's first real uproot is
## disproportionately an expensive one.
##
## A predicate rather than a comment, because the two call sites are in different files and
## a rule stated twice is a rule that drifts.
static func uproot_shows_tip(with_tip: bool, forfeited: int) -> bool:
	return with_tip and forfeited <= 0


static func packet_message(plant_name: String) -> String:
	return "The packet held a %s!" % plant_name


## Takes the plant's name now that more than one plant grows. The Chomp Flower's
## rungs are nouns ("bud", "toothy maw", "gaping maw") so this one sentence reads
## for both ladders without a per-plant phrasing.
static func upgrade_message(plant_name: String, level_name: String) -> String:
	return "%s is now a %s." % [plant_name, level_name]


## The line the prep window opens with. `note` is prep_depth_note()'s output or
## Game's countdown fallback; an empty one leaves the sentence alone rather than
## trailing a space nobody can see and every width measurement counts.
static func wave_cleared_line(number: int, note: String) -> String:
	if note == "":
		return "Wave %d cleared." % number
	return "Wave %d cleared. %s" % [number, note]


## The wave-starting half of this surface. Named for its event on purpose: see
## the BANNER_* block above for why there is no generic `show_banner(text)`.
func announce_wave(number: int, pests: int, note: String) -> void:
	_show_banner(wave_headline(number), wave_note(pests, note))


## What the weather did, said once as the wave opens
## (plant-tower-defense-q3lx).
##
## Through the same banner as the wave announcement rather than a new readout, and
## AFTER it, so the two do not race for the same two lines -- the wave banner fires
## from Game._on_wave_started immediately after _apply_weather, so this one is the
## overwritten half. That is deliberate and it is why weather has a status line too
## (`weather_note()`): the banner is the beat, the status row is the state.
##
## Clear weather says nothing at all. A banner that reads "Clear" on eleven waves
## out of twelve teaches the player to stop reading banners.
func show_weather(weather: StringName) -> void:
	if weather == WaveDirector.WEATHER_CLEAR:
		return
	_show_banner(weather_headline(weather), weather_note(weather))


## Pure, and static, so the suite asserts the words without building a HUD -- the
## same split every other headline/note pair on this class already uses.
static func weather_headline(weather: StringName) -> String:
	match weather:
		WaveDirector.WEATHER_RAIN:
			return "Rain"
		WaveDirector.WEATHER_DROUGHT:
			return "Drought"
		_:
			return ""


static func weather_note(weather: StringName) -> String:
	match weather:
		WaveDirector.WEATHER_RAIN:
			return "The garden drinks. Every bed grows back a little."
		WaveDirector.WEATHER_DROUGHT:
			return "Dry ground. Everything shoots half as often — and every pest pays %d%%." % int(
				round(WaveDirector.WEATHER_DROUGHT_SEED_BONUS * 100.0))
		_:
			return ""


## The wave-clearing half, added by plant-tower-defense-d2a so surviving a wave
## gets a beat comparable to the one that opens it rather than a single line on
## the status row. Same mechanism, same weight, its own event and its own text.
func announce_wave_cleared(number: int, pests: int) -> void:
	_show_banner(wave_cleared_headline(number), wave_cleared_note(pests))


## The mechanism both events above drive. Not itself a generic setter — it is
## private, and every caller still has to go through a method named for its own
## event; see the BANNER_* block above for why that restriction is the point.
func _show_banner(headline: String, note: String) -> void:
	_banner.text = headline
	_banner_note.text = note
	# Correct before any fade touches it — the alpha ramp below only ever runs
	# down from here, so a frame that never arrives cannot leave this invisible.
	_banner.modulate = Color.WHITE
	_banner_note.modulate = Color.WHITE
	_banner.visible = true
	_banner_note.visible = true
	_banner_left = BANNER_HOLD_SECONDS


func hide_banner() -> void:
	_banner_left = 0.0
	if not _banner.visible and not _banner_note.visible:
		return
	_banner.visible = false
	_banner_note.visible = false
	_banner.modulate = Color.WHITE
	_banner_note.modulate = Color.WHITE


## The fade is a pure function of the time left, not a Tween.
##
## A Tween here would need the usual GardenTheme.animations_enabled() gate and
## would own the hide in its finished callback, which puts the banner's
## visibility inside something headless never runs. Deriving alpha from the same
## countdown that hides it means the banner is in a correct state on every frame
## including the ones that never happen.
func _fade_banner(delta: float) -> void:
	_banner_left -= delta
	if _banner_left <= 0.0:
		hide_banner()
		return
	var alpha: float = minf(_banner_left / BANNER_FADE_SECONDS, 1.0)
	_banner.modulate = Color(1, 1, 1, alpha)
	_banner_note.modulate = Color(1, 1, 1, alpha)
