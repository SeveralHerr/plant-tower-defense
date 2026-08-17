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
signal next_wave_requested
signal upgrade_requested
signal uproot_requested

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
const NEXT_WAVE_BUTTON_SIZE := Vector2(216, 40)

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
## The stats row's font size, hoisted out of the four _add_stat calls so a budget
## measured against it cannot be measured at a different one. The compost readout
## is deliberately smaller and says so at its own call site.
const STAT_FONT_SIZE: int = 26

const SEEDS_LABEL_WIDTH: float = 171.0
const WAVE_LABEL_WIDTH: float = 312.0
const LIVES_LABEL_WIDTH: float = 146.0
const COMPOST_LABEL_WIDTH: float = 198.0

## The longest string each readout can ever hold. Budgets are only meaningful
## against these, and a clipped Label fails *silently* — it just renders
## "Seeds  4…" and nothing complains, which is exactly how the first pass at
## these numbers shipped a 130px seeds slot that could not hold a 3-digit
## total. `test_no_readout_clips_its_own_worst_case` measures each of these
## against its budget in the real theme font.
const WORST_CASE_TEXT: Dictionary = {
	"SeedsLabel": "Seeds  99999",
	# Weather is deliberately NOT here, and the number is why: the base string
	# measures 302px in a 312px slot, so the tightest tag that could carry a weather
	# state -- a bare "*" -- needs 317. Every option overflowed, which is the budget
	# system saying the top bar is not weather's home. See plant-tower-defense-saaw.
	"WaveLabel": "Wave  9999 ∞   threat 99",
	"LivesLabel": "Garden  10",
	# Includes the husk suffix. Leaving it out is what let a clipped readout ship:
	# the widest string this label can hold is not the widest one anyone wrote down.
	"CompostLabel": "Compost  9999  +99",
}

## The bar is two rows. Keeping them as named constants is what makes the gap
## between them checkable instead of implied by four scattered literals.
const STATS_ROW_Y: float = 4.0
const STATS_ROW_HEIGHT: float = 40.0
const MESSAGE_ROW_Y: float = 47.0
const MESSAGE_ROW_HEIGHT: float = 20.0

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


## Where the packet button for the `index`th tier sits, in the side panel's own
## space. Pure, so the rack's fit is arithmetic rather than a rendering check.
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
const MESSAGE_NORMAL: int = 0
const MESSAGE_IMPORTANT: int = 1
## How long a line is guaranteed on screen before an equal-priority one may
## replace it. Roughly the time to read a short sentence.
const MESSAGE_MIN_READABLE: float = 1.2
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
## A GridContainer, not a VBox: it runs one column until a fifth plant would
## push the buttons under the touch minimum, then two. See plant_bar_layout.
var _plant_bar: GridContainer
## tier -> its Button. A Dictionary rather than one named field per tier, which is
## what the pair of fields here became the moment there were three of them.
var _packet_buttons: Dictionary = {}
var _next_wave_button: Button
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
var _banner_left: float = 0.0
var _message_left: float = 0.0
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
	var bar := ColorRect.new()
	bar.name = "TopBar"
	bar.color = INK
	bar.position = Vector2.ZERO
	bar.size = Vector2(get_viewport_width(), BAR_HEIGHT)
	root.add_child(bar)

	var stats := HBoxContainer.new()
	stats.name = "StatsRow"
	stats.position = Vector2(20, STATS_ROW_Y)
	stats.size = Vector2(get_viewport_width() - 40, STATS_ROW_HEIGHT)
	stats.add_theme_constant_override("separation", STATS_SEPARATION)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(stats)

	_seeds_label = _add_stat(stats, "SeedsLabel", STAT_FONT_SIZE, PAPER, SEEDS_LABEL_WIDTH)
	_wave_label = _add_stat(stats, "WaveLabel", STAT_FONT_SIZE, PAPER, WAVE_LABEL_WIDTH)
	_lives_label = _add_stat(stats, "LivesLabel", STAT_FONT_SIZE, PAPER, LIVES_LABEL_WIDTH)
	_compost_label = _add_stat(stats, "CompostLabel", 20, COMPOST, COMPOST_LABEL_WIDTH)

	# The one element that absorbs slack. Without it the readouts spread across
	# the whole bar; with it they stay left-grouped and the button stays right.
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_child(spacer)

	_next_wave_button = Button.new()
	_next_wave_button.name = "NextWaveButton"
	_next_wave_button.text = "Grow the next wave"
	_next_wave_button.custom_minimum_size = NEXT_WAVE_BUTTON_SIZE
	_next_wave_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_next_wave_button.pressed.connect(func() -> void: next_wave_requested.emit())
	stats.add_child(_next_wave_button)

	# Second row, outside the container: it is a full-width status line, not a
	# stat competing for space with the others.
	_message_label = _make_label("MessageLabel", 15, LEAF)
	_message_label.position = Vector2(20, MESSAGE_ROW_Y)
	_message_label.size = Vector2(get_viewport_width() - 276, MESSAGE_ROW_HEIGHT)
	_message_label.clip_text = true
	_message_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(_message_label)

	_prep_bar = ColorRect.new()
	_prep_bar.name = "PrepBar"
	_prep_bar.position = Vector2(0, float(BAR_HEIGHT) - PREP_BAR_HEIGHT)
	_prep_bar.size = Vector2(get_viewport_width(), PREP_BAR_HEIGHT)
	_prep_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prep_bar.visible = false
	bar.add_child(_prep_bar)


func _build_side_panel(root: Control) -> void:
	var panel := ColorRect.new()
	panel.name = "SidePanel"
	panel.color = PAPER_DARK
	panel.position = Vector2(get_viewport_width() - PANEL_WIDTH, BAR_HEIGHT)
	panel.size = Vector2(PANEL_WIDTH, get_viewport_height() - BAR_HEIGHT)
	root.add_child(panel)

	var heading := _make_label("Heading", 20, INK)
	heading.position = Vector2(14, 12)
	heading.text = "Garden"
	panel.add_child(heading)

	var layout: Dictionary = plant_bar_layout(PlantCatalog.ids().size())
	_plant_bar = GridContainer.new()
	_plant_bar.name = "PlantBar"
	_plant_bar.columns = int(layout["columns"])
	_plant_bar.position = Vector2(12, PLANT_BAR_Y)
	_plant_bar.size = Vector2(PANEL_WIDTH - 24, PLANT_BAR_BOTTOM - PLANT_BAR_Y)
	_plant_bar.add_theme_constant_override("v_separation", PLANT_BAR_SEPARATION)
	_plant_bar.add_theme_constant_override("h_separation", PLANT_BAR_SEPARATION)
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
		button.tooltip_text = PlantCatalog.blurb(id)
		button.pressed.connect(_on_plant_button.bind(id))
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
		var spec: Dictionary = SeedBank.PACKET_TIERS[tier] as Dictionary
		var rect: Rect2 = packet_row_rect(index)
		var packet := Button.new()
		packet.name = packet_button_name(tier)
		packet.text = "%s (%d)" % [spec["display"], int(spec["cost"])]
		packet.icon = packet_icon
		packet.expand_icon = true
		packet.position = rect.position
		packet.size = rect.size
		packet.tooltip_text = packet_tooltip(tier)
		# `tier` is bound, not captured: a bare closure over the loop variable is
		# the one mistake this rewrite could make that two hand-written buttons
		# could not, and it would wire every button to the last tier.
		packet.pressed.connect(_on_packet_button.bind(tier))
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
	var width: float = float(get_viewport_width() - PANEL_WIDTH)

	_banner = _make_banner_label("Banner", BANNER_FONT_SIZE, PAPER)
	_banner.position = Vector2(0, BANNER_Y)
	_banner.size = Vector2(width, BANNER_HEIGHT)
	root.add_child(_banner)

	# Stacked directly under the headline, sharing no pixels with it: the two
	# rects abut at BANNER_Y + BANNER_HEIGHT rather than overlapping.
	_banner_note = _make_banner_label("BannerNote", BANNER_NOTE_FONT_SIZE, PAPER)
	_banner_note.position = Vector2(0, BANNER_Y + BANNER_HEIGHT)
	_banner_note.size = Vector2(width, BANNER_NOTE_HEIGHT)
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
func _add_stat(row: HBoxContainer, node_name: String, font_size: int, colour: Color, width: float) -> Label:
	var label := _make_label(node_name, font_size, colour)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2(width, 0)
	row.add_child(label)
	return label


## The widths above are only safe as a sum. Anything that adds a readout, widens
## one, or grows the button has to keep this true, and the unit test calls it
## rather than re-deriving the arithmetic.
## A packet button, disabled for the reason that actually applies, and saying so.
##
## The tooltip is rewritten rather than left static because the two reasons a
## packet is unbuyable are not interchangeable: "come back with more seeds" is a
## wait, and "this tier has nothing left for you" is a redirect to the other
## packet. A single greyed button that means either one teaches neither.
func _refresh_packet_button(button: Button, bank: SeedBank, tier: StringName) -> void:
	var spec: Dictionary = SeedBank.PACKET_TIERS[tier] as Dictionary
	var cost: int = int(spec["cost"])
	var spent: bool = bank.packet_pool(tier).is_empty()
	button.disabled = spent or bank.seeds < cost
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
	_prep_bar.size = Vector2(float(get_viewport_width()) * (left / total), PREP_BAR_HEIGHT)
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
	for columns: int in [1, 2]:
		var rows: int = int(ceil(float(count) / float(columns)))
		if rows <= 0:
			continue
		var height: float = (span - float(PLANT_BAR_SEPARATION * (rows - 1))) / float(rows)
		if height >= PLANT_BUTTON_MIN_HEIGHT:
			return {"columns": columns, "height": height, "rows": rows}
	# Past what two columns can hold at a legible size. Report the two-column
	# floor rather than silently shrinking below the touch minimum: whoever adds
	# that plant needs to make the bar scroll, and a test says so.
	var rows_max: int = int(ceil(float(count) / 2.0))
	return {
		"columns": 2,
		"height": PLANT_BUTTON_MIN_HEIGHT,
		"rows": rows_max,
		"overflows": true,
	}


static func stats_row_budget(readouts: int) -> float:
	var widths: float = SEEDS_LABEL_WIDTH + WAVE_LABEL_WIDTH + LIVES_LABEL_WIDTH + COMPOST_LABEL_WIDTH
	return widths + float(STATS_SEPARATION * readouts) + NEXT_WAVE_BUTTON_SIZE.x


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


func get_viewport_width() -> int:
	return ProjectSettings.get_setting("display/window/size/viewport_width", 1152)


func get_viewport_height() -> int:
	return ProjectSettings.get_setting("display/window/size/viewport_height", 648)


func _on_plant_button(id: StringName) -> void:
	plant_selected.emit(id)


func _on_packet_button(tier: StringName) -> void:
	packet_requested.emit(tier)


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
	if _readouts_seeded and seeds_text != _seeds_label.text:
		_punch_readout(_seeds_label)
	_seeds_label.text = seeds_text
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
		if not unlocked:
			button.text = "%s — locked" % PlantCatalog.display_name(id)
		elif price == 0:
			button.text = "%s — free" % PlantCatalog.display_name(id)
		else:
			button.text = "%s — %d" % [PlantCatalog.display_name(id), price]
		button.disabled = not unlocked
		button.modulate = Color.WHITE if (unlocked and bank.can_afford(id)) else Color(1, 1, 1, 0.55)
		button.button_pressed = unlocked and id == selected

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
	_refresh_prep_bar(state)
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
		_upgrade_button.visible = true
		if corn.is_max_level():
			_upgrade_button.text = "Fully grown"
			_upgrade_button.disabled = true
		else:
			_upgrade_button.text = "Upgrade (%d)" % corn.upgrade_cost()
			_upgrade_button.disabled = (state["bank"] as SeedBank).seeds < corn.upgrade_cost()
	elif sunflower != null:
		_selection_label.text = "%s\nNext %d seeds in %.0fs" % [
			PlantCatalog.display_name(plant.kind), Sunflower.YIELD, sunflower.seconds_until_next_yield(),
		]
		_upgrade_button.visible = false
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
		_selection_label.text = "%s\n%s" % [PlantCatalog.display_name(plant.kind), busy]
		_upgrade_button.visible = false
	_refresh_health(plant)
	# Armed, the button says what the next click does rather than what the action
	# is called. It stays the same node at the same size — the devtools bridge and
	# the tests press UprootButton by path, and a second button would not fit under
	# SelectionBox anyway (the VBox already runs to within 16px of the panel foot).
	if bool(state.get("uproot_armed", false)):
		_uproot_button.text = "Really uproot? (+%d)" % plant.uproot_refund()
		_uproot_button.add_theme_color_override("font_color", UPROOT_ARMED)
	else:
		_uproot_button.text = "Uproot (+%d)" % plant.uproot_refund()
		_uproot_button.remove_theme_color_override("font_color")


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
func _ease_threat_tint(target: Color) -> void:
	if not GardenTheme.animations_enabled():
		_wave_label.add_theme_color_override("font_color", target)
		return
	if target.is_equal_approx(_threat_tint_target):
		return
	_threat_tint_target = target
	if _threat_tween != null and _threat_tween.is_valid():
		_threat_tween.kill()
	var from: Color = _wave_label.get_theme_color("font_color")
	_threat_tween = create_tween()
	_threat_tween.tween_method(
		func(c: Color) -> void: _wave_label.add_theme_color_override("font_color", c),
		from, target, THREAT_FADE_SECONDS)


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


func show_message(text: String, seconds: float = 3.0, priority: int = MESSAGE_NORMAL) -> void:
	if _message_left > 0.0:
		if priority > _message_priority:
			_queue_message(_message_label.text, _message_left, _message_priority)
		elif _message_left > MESSAGE_MIN_READABLE or priority < _message_priority:
			# The line on screen has not been up long enough to have been read, or
			# outranks this one. Wait rather than stomp.
			_queue_message(text, seconds, priority)
			return
	_message_label.text = text
	_message_left = seconds
	_message_priority = priority


## The queue is deliberately short. Messages describe things happening now, and a
## backlog long enough to outlive its own subject is worse than a dropped line —
## it puts stale narration over a board that has moved on. When it is full the
## lowest-priority entry is dropped, so an important line still gets in.
func _queue_message(text: String, seconds: float, priority: int) -> void:
	if _message_queue.size() >= MESSAGE_QUEUE_MAX:
		var lowest: int = 0
		for i: int in range(_message_queue.size()):
			if int(_message_queue[i]["priority"]) < int(_message_queue[lowest]["priority"]):
				lowest = i
		if int(_message_queue[lowest]["priority"]) >= priority:
			return
		_message_queue.remove_at(lowest)
	_message_queue.append({"text": text, "seconds": seconds, "priority": priority})


func _advance_message_queue() -> void:
	if _message_queue.is_empty():
		_message_label.text = ""
		_message_priority = MESSAGE_NORMAL
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
	_message_label.text = String(next["text"])
	_message_left = float(next["seconds"])
	_message_priority = int(next["priority"])


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
			return "Dry ground. Everything you planted shoots half as often."
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
