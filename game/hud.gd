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
const STATS_SEPARATION: int = 14

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
const SEEDS_LABEL_WIDTH: float = 180.0
const WAVE_LABEL_WIDTH: float = 315.0
const LIVES_LABEL_WIDTH: float = 150.0
const COMPOST_LABEL_WIDTH: float = 170.0

## The longest string each readout can ever hold. Budgets are only meaningful
## against these, and a clipped Label fails *silently* — it just renders
## "Seeds  4…" and nothing complains, which is exactly how the first pass at
## these numbers shipped a 130px seeds slot that could not hold a 3-digit
## total. `test_no_readout_clips_its_own_worst_case` measures each of these
## against its budget in the real theme font.
const WORST_CASE_TEXT: Dictionary = {
	"SeedsLabel": "Seeds  99999",
	"WaveLabel": "Wave  9999 ∞   threat 99",
	"LivesLabel": "Garden  10",
	"CompostLabel": "Compost  9999",
}

## The bar is two rows. Keeping them as named constants is what makes the gap
## between them checkable instead of implied by four scattered literals.
const STATS_ROW_Y: float = 4.0
const STATS_ROW_HEIGHT: float = 40.0
const MESSAGE_ROW_Y: float = 47.0
const MESSAGE_ROW_HEIGHT: float = 20.0

const INK := Color(0.12, 0.15, 0.13)
const PAPER := Color(0.925, 0.863, 0.722)
const PAPER_DARK := Color(0.851, 0.788, 0.659)
const LEAF := Color(0.180, 0.800, 0.443)
## The one warning red in the HUD: an armed Uproot, and nothing else. Same hue
## the in-world health bar and the lane-pressure overlay already use, so a red on
## this screen always means "this costs you something".
const UPROOT_ARMED := Color(0.85, 0.25, 0.22)

## The selection panel's health bar. Green at full, through amber, to the same
## warning red as UPROOT_ARMED at nearly-dead — so the two reds in the panel mean
## the same thing, and a plant worth replanting says so without being read.
const HEALTH_ROW_HEIGHT: float = 14.0
const HEALTH_BACK := Color(0.12, 0.15, 0.13, 0.35)
const HEALTH_FULL := Color(0.180, 0.800, 0.443)
const HEALTH_LOW := Color(0.85, 0.25, 0.22)

var _seeds_label: Label
var _wave_label: Label
var _lives_label: Label
var _compost_label: Label
var _message_label: Label
var _plant_bar: VBoxContainer
var _packet_button: Button
var _rare_packet_button: Button
var _next_wave_button: Button
var _selection_box: VBoxContainer
var _selection_label: Label
var _upgrade_button: Button
var _uproot_button: Button
var _health_row: ColorRect
var _health_fill: ColorRect
var _health_text: Label
var _banner: Label

var _plant_buttons: Dictionary = {}
var _message_left: float = 0.0


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

	_seeds_label = _add_stat(stats, "SeedsLabel", 26, PAPER, SEEDS_LABEL_WIDTH)
	_wave_label = _add_stat(stats, "WaveLabel", 26, PAPER, WAVE_LABEL_WIDTH)
	_lives_label = _add_stat(stats, "LivesLabel", 26, PAPER, LIVES_LABEL_WIDTH)
	_compost_label = _add_stat(stats, "CompostLabel", 20, Color(0.78, 0.62, 0.38), COMPOST_LABEL_WIDTH)

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

	_plant_bar = VBoxContainer.new()
	_plant_bar.name = "PlantBar"
	_plant_bar.position = Vector2(12, 44)
	_plant_bar.size = Vector2(PANEL_WIDTH - 24, 240)
	_plant_bar.add_theme_constant_override("separation", 8)
	panel.add_child(_plant_bar)

	for id: StringName in PlantCatalog.ids():
		var button := Button.new()
		button.name = "Button_%s" % String(id)
		button.custom_minimum_size = Vector2(0, 56)
		button.icon = load(PlantCatalog.texture_path(id)) as Texture2D
		button.expand_icon = true
		button.tooltip_text = PlantCatalog.blurb(id)
		button.pressed.connect(_on_plant_button.bind(id))
		_plant_bar.add_child(button)
		_plant_buttons[id] = button

	# Stacked full-width, not side-by-side: two 112px-wide buttons with an icon
	# plus "Common (20)" had no room left for the text (findings caught this —
	# button_text_overflow, 99px of text in less than that of actual space).
	_packet_button = Button.new()
	_packet_button.name = "PacketButton"
	_packet_button.text = "Common Packet (%d)" % SeedBank.PACKET_TIERS[&"common"]["cost"]
	_packet_button.icon = load("res://assets/sprites/seed_packet.png") as Texture2D
	_packet_button.expand_icon = true
	_packet_button.position = Vector2(12, 300)
	_packet_button.size = Vector2(PANEL_WIDTH - 24, 40)
	_packet_button.tooltip_text = "A packet holds one plant you do not have yet, tier 1 only. Which one is up to the packet."
	_packet_button.pressed.connect(func() -> void: packet_requested.emit(&"common"))
	panel.add_child(_packet_button)

	_rare_packet_button = Button.new()
	_rare_packet_button.name = "RarePacketButton"
	_rare_packet_button.text = "Rare Packet (%d)" % SeedBank.PACKET_TIERS[&"rare"]["cost"]
	_rare_packet_button.icon = load("res://assets/sprites/seed_packet.png") as Texture2D
	_rare_packet_button.expand_icon = true
	_rare_packet_button.position = Vector2(12, 344)
	_rare_packet_button.size = Vector2(PANEL_WIDTH - 24, 40)
	_rare_packet_button.tooltip_text = "Costlier, but the odds reach past tier 1 — the only reliable way to a Seed Sunflower."
	_rare_packet_button.pressed.connect(func() -> void: packet_requested.emit(&"rare"))
	panel.add_child(_rare_packet_button)

	_selection_box = VBoxContainer.new()
	_selection_box.name = "SelectionBox"
	_selection_box.position = Vector2(12, 392)
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
	_health_fill.color = HEALTH_FULL
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


func _build_banner(root: Control) -> void:
	_banner = Label.new()
	_banner.name = "Banner"
	_banner.position = Vector2(0, 240)
	_banner.size = Vector2(get_viewport_width() - PANEL_WIDTH, 120)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 48)
	_banner.add_theme_color_override("font_color", PAPER)
	_banner.add_theme_color_override("font_shadow_color", INK)
	_banner.add_theme_constant_override("shadow_offset_x", 3)
	_banner.add_theme_constant_override("shadow_offset_y", 3)
	_banner.visible = false
	root.add_child(_banner)


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


func get_viewport_width() -> int:
	return ProjectSettings.get_setting("display/window/size/viewport_width", 1152)


func get_viewport_height() -> int:
	return ProjectSettings.get_setting("display/window/size/viewport_height", 648)


func _on_plant_button(id: StringName) -> void:
	plant_selected.emit(id)


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message_label.text = ""


## The one call the Game makes every time anything changes. Passing the whole
## state in keeps the HUD stateless — there is no second copy of the truth here
## that can go stale.
func refresh(state: Dictionary) -> void:
	var bank: SeedBank = state["bank"]
	_seeds_label.text = "Seeds  %d" % bank.seeds
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
	_lives_label.text = "Garden  %d" % state["lives"]
	var husks: int = int(state.get("husks_on_ground", 0))
	_compost_label.text = "Compost  %d" % int(state.get("compost_total", 0))
	if husks > 0:
		_compost_label.text += " (%d ready)" % husks

	var selected: StringName = state["selected_plant"]
	for id: StringName in _plant_buttons:
		var button: Button = _plant_buttons[id]
		var unlocked: bool = bank.is_unlocked(id)
		var price: int = bank.placement_cost(id)
		if not unlocked:
			button.text = "%s\nlocked" % PlantCatalog.display_name(id)
		elif price == 0:
			button.text = "%s\nfree" % PlantCatalog.display_name(id)
		else:
			button.text = "%s\n%d seeds" % [PlantCatalog.display_name(id), price]
		button.disabled = not unlocked
		button.modulate = Color.WHITE if (unlocked and bank.can_afford(id)) else Color(1, 1, 1, 0.55)
		button.button_pressed = unlocked and id == selected

	var locked_empty: bool = bank.locked_plants().is_empty()
	_packet_button.disabled = locked_empty or bank.seeds < int(SeedBank.PACKET_TIERS[&"common"]["cost"])
	_rare_packet_button.disabled = locked_empty or bank.seeds < int(SeedBank.PACKET_TIERS[&"rare"]["cost"])
	_next_wave_button.disabled = not bool(state["can_start_wave"])
	_refresh_selection(state)


func _refresh_selection(state: Dictionary) -> void:
	var plant: Plant = state["selected_placed"] as Plant
	if plant == null or not is_instance_valid(plant):
		_selection_box.visible = false
		return
	_selection_box.visible = true
	var corn := plant as CornCobbler
	var sunflower := plant as Sunflower
	if corn != null:
		_selection_label.text = "%s — %s\n%d kernel(s) per shot" % [
			PlantCatalog.display_name(plant.kind), corn.level_name(), corn.kernels_per_shot(),
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
		var busy: String = "Idle — waiting for a pest."
		if chomp != null and chomp.is_busy():
			busy = "Chewing — %d%% through this one." % int(round(chomp.chew_progress() * 100.0))
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
	_health_fill.color = HEALTH_LOW.lerp(HEALTH_FULL, fraction)
	_health_text.text = "Health %d/%d" % [int(ceil(plant.health)), int(Plant.MAX_HEALTH)]


func show_message(text: String, seconds: float = 3.0) -> void:
	_message_label.text = text
	_message_left = seconds


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true


func hide_banner() -> void:
	_banner.visible = false
