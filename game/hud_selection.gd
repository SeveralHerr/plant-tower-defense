extends RefCounted

## THE SELECTION-PANEL DETAIL SUBSYSTEM, extracted out of `game/hud.gd`
## (plant-tower-defense-tar5, the hud.gd split, following game.gd's own -2dlh split).
## Everything the selection panel's second line can say about a plant -- the per-plant
## detail sentences (`corn_detail`, `sunflower_detail`, `idle_detail`, ... ), the two
## corpora that sweep them (`selection_detail_corpus`, `selection_level_names`,
## `selection_corpus`), and the panel's own layout arithmetic (`selection_room_below`,
## `wrapped_rows`, `selection_panel_budget`) -- everything `game_budget.gd`'s
## `_budget_hud_selection_panel` reads through `Hud.selection_corpus()` and
## `Hud.selection_panel_budget()`.
##
## WHY THIS GROUP AND WHY A PLAIN RefCounted, not a new autoload. Every function here
## is `static` already and none of them reads `self` -- they take plant numbers in and
## hand sentences or measurements back, which is exactly the shape that made
## `game_budget.gd` safe to cut first. Nothing here depends on being on the same object
## as the top bar, the message queue, or the banner; `Hud` still OWNS this the same way
## `Game` owns `GameBudget` -- a plain object every `Hud` call forwards into, not a
## second public type.
##
## DELIBERATELY NO `class_name`, for the reason `game_budget.gd`'s own header gives:
## `test_every_game_class_is_at_least_named_somewhere_in_the_test_suite`
## (`test/unit/test_selftest.gd`) requires every `class_name` under `game/` to be named
## literally by some test, and teaching a test a name that exists only to be forwarded
## would satisfy the letter of that rule for the wrong reason. `preload` keeps this file
## exactly what it is: private to `hud.gd`.
##
## THE PUBLIC SURFACE ON `Hud` DID NOT MOVE. Every symbol `game/game_budget.gd`,
## `test/unit/*.gd` and any other caller reference as `Hud.selection_corpus()`,
## `Hud.selection_panel_budget(...)`, `Hud.corn_detail(...)` and so on is still there,
## as a one-line delegating wrapper -- see the "-- selection panel detail (see
## game/hud_selection.gd) --" block in `hud.gd` where this group used to live.
##
## NOT MOVED, on purpose: `HEALTH_ROW_HEIGHT`, `SELECTION_BUTTON_HEIGHT`,
## `BAR_HEIGHT`, `SELECTION_BOX_Y`, `SELECTION_LABEL_FONT_SIZE`,
## `SELECTION_LABEL_MIN_HEIGHT` and `SELECTION_SEPARATION` stay declared on `Hud`
## itself and are read here as `Hud.CONST_NAME` -- they are layout constants the top
## bar and the side panel builders (`_build_side_panel`) also read directly, so moving
## them would split one number across two files for no reason. `Hud` keeps its
## `class_name`, so referencing it from a `preload`-only helper resolves exactly the
## way `game_budget.gd` already resolves `Hud.SELECTION_BOX_WIDTH` and
## `Hud.PACKET_BUTTON_FONT_SIZE` today.


## What the panel's DETAIL slot says while a plant is being moved
## (plant-tower-defense-jvnm's move-hint line). See `hud.gd`'s own header on the
## call site this feeds for why it rides the detail slot instead of a new row.
static func move_hint_detail(cost: int) -> String:
	return "Click a spot to move it (%d)" % cost


## The upgrade button's face: the price, and what the price buys
## (plant-tower-defense-jvnm).
##
## `gain` EMPTY FALLS BACK TO THE BARE PRICE, which is what a plant at its top rung and a
## plant with no ladder both hand back. No branch at the call site.
##
## The separator is a middle dot rather than a dash: the gain phrases contain "→" and a
## dash beside an arrow reads as a range.
static func upgrade_button_text(cost: int, gain: String) -> String:
	if gain == "":
		return "Upgrade (%d)" % cost
	return "Upgrade (%d) · %s" % [cost, gain]


static func selection_line(display: String, level_name: String, detail: String) -> String:
	if level_name == "":
		return "%s\n%s" % [display, detail]
	return "%s — %s\n%s" % [display, level_name, detail]


## Damage per volley, rate, and kernels — the three numbers an upgrade actually moves.
static func corn_detail(damage_per_volley: float, interval: float, kernels: int) -> String:
	return "%.1f dmg / %.2fs, %d kernel(s)" % [damage_per_volley, interval, kernels]


static func sunflower_detail(seeds: int, seconds: float) -> String:
	return "Next %d seeds in %.0fs" % [seeds, seconds]


static func dandelion_armed_detail(fluff: int, damage: float) -> String:
	return "%d seed(s) up, %.0f dmg a burst." % [fluff, damage]


static func dandelion_regrowing_detail(fluff: int, fluff_max: int, seconds: float) -> String:
	return "Regrowing — %d/%d fluff, armed in %.1fs." % [fluff, fluff_max, seconds]


static func chomp_chewing_detail(percent: int) -> String:
	return "Chewing — %d%% through this one." % percent


static func sundew_detail(pests: int, percent: int) -> String:
	return "Slowing %d pest(s) to %d%% speed." % [pests, percent]


## What a plant with nothing to say says. A zero-argument PRODUCER and not a `const`,
## for the reason `flight_tip()` gives beside `message_corpus()`: a const reference is
## invisible to a corpus sweep, and this is the line seven of the eight plants show.
static func idle_detail() -> String:
	return "Idle — waiting for a pest."


## The two support plants, which were showing `idle_detail()` and should never have been.
## ZERO-ARGUMENT, like `idle_detail`, and that is a deliberate limit rather than an
## oversight -- see `hud.gd`'s history (plant-tower-defense-tar5's split moved the fuller
## comment along with the code it was written beside; grep the git log for `mint_detail`
## if the full reasoning is needed).
static func mint_detail() -> String:
	return "Quickening the beds beside it — never the lane."


static func aloe_detail() -> String:
	return "Mending the beds beside it, slowly."


## What a plant that RESISTS says: how long the health it has now will actually last.
## SECONDS, not a multiplier -- see `selection_line`'s callers for why this rides the
## existing `detail` slot instead of a second line.
static func resisting_detail(seconds_left: float) -> String:
	return "Holds %ds against one pest." % int(round(seconds_left))


## Every second line the panel can draw, each at the widest its own data allows.
##
## Derived, never typed. Corn sweeps its ladder, so a retune moves this number; the
## rest are priced at the constants that bound them — FLUFF_MAX, SEED_DAMAGE, the
## Sunflower's whole INTERVAL (the clock counts down from it, so it is the widest
## the "%.0fs" can read), a full regrow, a chew at 100%, and a Sundew holding a road
## filled to WaveDirector.SIMULTANEOUS_PEST_CEILING. That last one is another budget's
## ceiling on purpose: the two are coupled, and pricing the Sundew's line at "9 pests"
## would be this budget quietly assuming the road's.
static func selection_detail_corpus() -> Array[String]:
	var out: Array[String] = []
	for level: Dictionary in CornCobbler.LEVELS:
		out.append(corn_detail(
			float(level.get("damage", 0.0)) * float(int(level.get("kernels", 0))),
			float(level.get("interval", 0.0)), int(level.get("kernels", 0))))
	out.append(sunflower_detail(Sunflower.YIELD, Sunflower.INTERVAL))
	out.append(dandelion_armed_detail(Dandelion.FLUFF_MAX, Dandelion.SEED_DAMAGE))
	out.append(dandelion_regrowing_detail(Dandelion.FLUFF_MAX, Dandelion.FLUFF_MAX,
		Dandelion.REGROW_DELAY + float(Dandelion.FLUFF_MAX) * Dandelion.FLUFF_REGROW_SECONDS))
	out.append(chomp_chewing_detail(100))
	out.append(sundew_detail(WaveDirector.SIMULTANEOUS_PEST_CEILING,
		int(round(StickySundew.SLOW_FACTOR * 100.0))))
	# The armed move hint (plant-tower-defense-28un), priced at a cost far wider than the
	# game can reach: move_cost() is a quarter of base plus upgrade spend, so three digits
	# needs an investment no ladder allows. Same over-pricing this corpus already does by
	# crossing every plant with every detail.
	out.append(move_hint_detail(999))
	# Priced at the widest the FORMAT can read, not at what a Bramble actually shows.
	# `Bramble.hold_seconds(1)` is 11s today, which is two digits; the budget has to
	# survive a retune that makes it three, and `int(round())` on a float has no natural
	# ceiling. 999 is the widest a sane balance can reach and is deliberately wider than
	# the game — the same over-pricing this corpus already does by crossing every plant
	# with every detail.
	out.append(mint_detail())
	out.append(aloe_detail())
	out.append(resisting_detail(999.0))
	out.append(idle_detail())
	return out


## Every rung name the panel's first line can carry, plus `""` for a plant with no
## ladder.
##
## The two `LEVELS` arrays are named here the same way `message_corpus()` names them,
## and for the same unglamorous reason: `upgrade_ladder()` is an instance virtual, so
## there is no static registry of ladders to sweep. Adding a third upgradable plant
## means adding its ladder here — and `test_every_ladder_in_the_game_is_priced_by_the_
## selection_corpus` in test_selftest.gd fails until someone does, which is the point
## of writing it down rather than deriving it from nothing.
static func selection_level_names() -> Array[String]:
	var out: Array[String] = [""]
	for level: Dictionary in CornCobbler.LEVELS:
		out.append(String(level["name"]))
	for level: Dictionary in ChompFlower.LEVELS:
		out.append(String(level["name"]))
	# The Barrier Bramble's rungs (plant-tower-defense-4u74). Added here because this list
	# is hand-maintained ON PURPOSE -- upgrade_ladder() is an instance virtual, so there is
	# no static registry to sweep -- and test_every_ladder_in_the_game_is_priced_by_the
	# _selection_corpus fails until a new ladder arrives here.
	for level: Dictionary in Bramble.LEVELS:
		out.append(String(level["name"]))
	return out


## Every string SelectionLabel can be asked to hold, at its widest.
##
## Every plant crossed with every rung and every detail. That is deliberately wider
## than the game can actually reach — a Sunflower never shows a chew percentage — and
## it is the same over-pricing `message_corpus()` does when it gives every plant an
## `upgrade_tip`. A budget is about the worst case the FORMAT allows, and a corpus
## that reasons about which plant can reach which line is a corpus that will be wrong
## the first time a plant gains a behaviour.
static func selection_corpus() -> Array[String]:
	var out: Array[String] = []
	var details: Array[String] = selection_detail_corpus()
	var levels: Array[String] = selection_level_names()
	for id: StringName in PlantCatalog.ids():
		# BOTH names for every plant: the one on the packet and the one a sport of it
		# wears (`PlantMutation`). Neither is derivable from the other and either can
		# be the wider — "Popcorn Cobbler" is longer than "Corn Cobbler", "Wild Mint"
		# shorter than "Garden Mint" — so pricing one would leave this budget wrong in
		# a direction that depends on which plant the player selected.
		for display: String in [PlantCatalog.display_name(id), PlantMutation.display_name(id)]:
			for level_name: String in levels:
				for detail: String in details:
					out.append(selection_line(display, level_name, detail))
	return out


## The fixed rows under SelectionLabel, in VBox order: the health bar and the two
## buttons. Damaged AND upgradable is the tallest the box ever gets, and it is the
## only case worth budgeting — priced on the common case, this budget would read
## clean right up until a plant was bitten.
static func selection_rows_below_label() -> Array[float]:
	var rows: Array[float] = [
		Hud.HEALTH_ROW_HEIGHT, Hud.SELECTION_BUTTON_HEIGHT, Hud.SELECTION_BUTTON_HEIGHT,
	]
	return rows


## How much panel there is under SelectionBox's top edge — the height the whole
## stack has to fit inside.
##
## Measured against the DESIGN canvas, not the live one, and that is the whole
## point of the number. `stretch/aspect="expand"` never yields a canvas SHORTER
## than the design size, so the design height is the worst case this budget has to
## survive; reading `_side_panel.size.y` instead would hand the panel a bigger
## allowance on every window that is not exactly 16:9 — including the 64x64
## headless one, where the canvas comes out 1152x1152 and this budget would report
## 504px of room it does not have. ScreenMetrics' own header makes this argument at
## length; this is a caller of it.
static func selection_room_below() -> float:
	return float(ScreenMetrics.design_height()) - float(Hud.BAR_HEIGHT) - Hud.SELECTION_BOX_Y


## How many rows `line` occupies once the label has wrapped it to `box_width`.
##
## Greedy word wrap, which is what AUTOWRAP_WORD_SMART does for every string this
## panel can produce. The one case it under-counts is a single WORD wider than the
## box, which WORD_SMART breaks mid-word and this returns 1 for — noted rather than
## handled, because no plant name or detail in the corpus comes close and a budget
## that mis-priced it would be reporting a string the game cannot build.
static func wrapped_rows(line: String, font: Font, font_size: int, box_width: float) -> int:
	if font == null or box_width <= 0.0:
		return 1
	var words: PackedStringArray = line.split(" ", false)
	if words.is_empty():
		return 1
	var rows: int = 1
	var current: String = ""
	for word: String in words:
		var candidate: String = word if current == "" else current + " " + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= box_width:
			current = candidate
			continue
		rows += 1
		current = word
	return rows


## Price `lines` against the selection panel's box: the widest single line it can be
## asked to draw, and where the whole stack's foot lands.
##
## TWO numbers, because there are two questions and they have different answers.
##
##   * `width_left` — how much room the WIDEST single line has in the box. This label
##     AUTOWRAPS, so a line wider than the box is drawn, not clipped. It is the number
##     a person needs before adding a word.
##   * `height_left` — how much panel is left under the stack's foot once the label has
##     grown to hold every row the wrap produced. THIS is the one that breaks: a
##     VBoxContainer pushes Upgrade and Uproot down by the extra row, out through the
##     panel's foot, where they are still pressable by path and invisible to a player.
##     Nothing overflows its own box at any point, which is why no per-Control check
##     sees it.
##
## `label_height` is `rows * (font height + line_spacing) - line_spacing` — Label's own
## arithmetic, not an approximation of it.
##
## `lines` is a parameter rather than a call to `selection_corpus()` so a test can hand
## this a corpus worsened on purpose and watch the number go negative. A budget nobody
## has ever seen fail is a budget nobody has any reason to believe.
##
## Measured through ONE detached Label, resolving exactly the font
## `GardenTheme.measure` resolves — see its header for why a detached Label rather
## than a Font loaded by path. Batched because the corpus is hundreds of strings and
## a probe per string would be a UI built and thrown away for each one.
static func selection_panel_budget(lines: Array[String], box_width: float,
		room_below: float) -> Dictionary:
	var probe := Label.new()
	probe.add_theme_font_size_override("font_size", Hud.SELECTION_LABEL_FONT_SIZE)
	var font: Font = probe.get_theme_font("font")
	var font_size: int = probe.get_theme_font_size("font_size")
	var line_spacing: float = float(probe.get_theme_constant("line_spacing"))
	var row_height: float = 0.0
	if font != null:
		row_height = font.get_height(font_size) + line_spacing
	probe.free()

	var widest_line: String = ""
	var widest_px: float = 0.0
	var tallest_text: String = ""
	var tallest_rows: int = 0
	var physical_lines: int = 0
	for text: String in lines:
		var rows: int = 0
		for physical: String in text.split("\n"):
			physical_lines += 1
			var drawn: float = 0.0
			if font != null:
				drawn = font.get_string_size(physical, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if drawn > widest_px:
				widest_px = drawn
				widest_line = physical
			rows += wrapped_rows(physical, font, font_size, box_width)
		if rows > tallest_rows:
			tallest_rows = rows
			tallest_text = text
	# Label's own formula: the gap between rows is spent between them, not after the
	# last. Getting this wrong by one `line_spacing` is a 3px error that would have put
	# the shipped panel 3px past its own foot in the report and nowhere in the game.
	var label_height: float = maxf(Hud.SELECTION_LABEL_MIN_HEIGHT,
		float(tallest_rows) * row_height - line_spacing)
	var stack_height: float = label_height
	for row: float in selection_rows_below_label():
		stack_height += float(Hud.SELECTION_SEPARATION) + row
	return {
		# The denominator, not the verdict. A corpus that swept nothing and a font
		# that failed to resolve both produce a tidy zero-width worst case, which is
		# indistinguishable from a panel with room to spare.
		"measured": font != null and physical_lines > 0 and box_width > 0.0,
		"texts": lines.size(),
		"physical_lines": physical_lines,
		"widest_line": widest_line,
		"widest_px": widest_px,
		"box_width": box_width,
		"width_left": box_width - widest_px,
		"row_height": row_height,
		"line_spacing": line_spacing,
		"rows": tallest_rows,
		"tallest_text": tallest_text,
		"label_height": label_height,
		"stack_height": stack_height,
		"room_below": room_below,
		"height_left": room_below - stack_height,
	}
