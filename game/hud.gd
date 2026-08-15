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
signal packet_requested
signal next_wave_requested
signal upgrade_requested
signal uproot_requested

const BAR_HEIGHT: int = 72
const PANEL_WIDTH: int = 256

const INK := Color(0.12, 0.15, 0.13)
const PAPER := Color(0.925, 0.863, 0.722)
const PAPER_DARK := Color(0.851, 0.788, 0.659)
const LEAF := Color(0.180, 0.800, 0.443)

var _seeds_label: Label
var _wave_label: Label
var _lives_label: Label
var _message_label: Label
var _plant_bar: VBoxContainer
var _packet_button: Button
var _next_wave_button: Button
var _selection_box: VBoxContainer
var _selection_label: Label
var _upgrade_button: Button
var _uproot_button: Button
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


func _build_top_bar(root: Control) -> void:
	var bar := ColorRect.new()
	bar.name = "TopBar"
	bar.color = INK
	bar.position = Vector2.ZERO
	bar.size = Vector2(get_viewport_width(), BAR_HEIGHT)
	root.add_child(bar)

	_seeds_label = _make_label("SeedsLabel", Vector2(20, 18), 26, PAPER)
	bar.add_child(_seeds_label)
	_wave_label = _make_label("WaveLabel", Vector2(300, 18), 26, PAPER)
	bar.add_child(_wave_label)
	_lives_label = _make_label("LivesLabel", Vector2(560, 18), 26, PAPER)
	bar.add_child(_lives_label)

	_message_label = _make_label("MessageLabel", Vector2(20, 46), 15, LEAF)
	_message_label.size = Vector2(760, 22)
	bar.add_child(_message_label)

	_next_wave_button = Button.new()
	_next_wave_button.name = "NextWaveButton"
	_next_wave_button.text = "Grow the next wave"
	_next_wave_button.position = Vector2(get_viewport_width() - 236, 16)
	_next_wave_button.size = Vector2(216, 40)
	_next_wave_button.pressed.connect(func() -> void: next_wave_requested.emit())
	bar.add_child(_next_wave_button)


func _build_side_panel(root: Control) -> void:
	var panel := ColorRect.new()
	panel.name = "SidePanel"
	panel.color = PAPER_DARK
	panel.position = Vector2(get_viewport_width() - PANEL_WIDTH, BAR_HEIGHT)
	panel.size = Vector2(PANEL_WIDTH, get_viewport_height() - BAR_HEIGHT)
	root.add_child(panel)

	var heading := _make_label("Heading", Vector2(14, 12), 20, INK)
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

	_packet_button = Button.new()
	_packet_button.name = "PacketButton"
	_packet_button.text = "Seed packet (%d)" % SeedBank.PACKET_COST
	_packet_button.icon = load("res://assets/sprites/seed_packet.png") as Texture2D
	_packet_button.expand_icon = true
	_packet_button.position = Vector2(12, 300)
	_packet_button.size = Vector2(PANEL_WIDTH - 24, 48)
	_packet_button.tooltip_text = "A packet holds one plant you do not have yet. Which one is up to the packet."
	_packet_button.pressed.connect(func() -> void: packet_requested.emit())
	panel.add_child(_packet_button)

	_selection_box = VBoxContainer.new()
	_selection_box.name = "SelectionBox"
	_selection_box.position = Vector2(12, 364)
	_selection_box.size = Vector2(PANEL_WIDTH - 24, 180)
	_selection_box.add_theme_constant_override("separation", 6)
	_selection_box.visible = false
	panel.add_child(_selection_box)

	_selection_label = _make_label("SelectionLabel", Vector2.ZERO, 15, INK)
	_selection_label.custom_minimum_size = Vector2(0, 76)
	_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection_box.add_child(_selection_label)

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


func _make_label(node_name: String, at: Vector2, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
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
	_wave_label.text = "Wave  %d / %d" % [state["wave"], state["wave_count"]]
	_lives_label.text = "Garden  %d" % state["lives"]

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

	_packet_button.disabled = bank.locked_plants().is_empty() or bank.seeds < SeedBank.PACKET_COST
	_next_wave_button.disabled = not bool(state["can_start_wave"])
	_refresh_selection(state)


func _refresh_selection(state: Dictionary) -> void:
	var plant: Plant = state["selected_placed"] as Plant
	if plant == null or not is_instance_valid(plant):
		_selection_box.visible = false
		return
	_selection_box.visible = true
	var corn := plant as CornCobbler
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
	else:
		_selection_label.text = "%s\n%s" % [PlantCatalog.display_name(plant.kind), PlantCatalog.blurb(plant.kind)]
		_upgrade_button.visible = false
	_uproot_button.text = "Uproot (+%d)" % plant.uproot_refund()


func show_message(text: String, seconds: float = 3.0) -> void:
	_message_label.text = text
	_message_left = seconds


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true


func hide_banner() -> void:
	_banner.visible = false
