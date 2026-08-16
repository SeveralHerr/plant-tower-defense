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
const SUBTITLE_Y: float = 158.0
const SCORE_Y: float = 190.0
const BUTTON_TOP: float = 236.0
const BUTTON_WIDTH: float = 300.0
const BUTTON_HEIGHT: float = 56.0
const BUTTON_GAP: float = 12.0
const HINT_Y: float = 428.0

## Where a decorative plant's stem meets the ground, and how much bigger than
## its 64px board size it is drawn here.
const PLANT_BASE_Y: float = 514.0
const PLANT_SCALE: float = 1.7
## Decorations, as {sprite, x}. Kept clear of the centre column the buttons
## occupy (x 426-726 at 1152 wide).
const PLANTS: Array[Dictionary] = [
	{"sprite": "res://assets/sprites/sunflower.png", "x": 132.0},
	{"sprite": "res://assets/sprites/corn_cobbler.png", "x": 272.0},
	{"sprite": "res://assets/sprites/chomp_flower.png", "x": 884.0},
	{"sprite": "res://assets/sprites/corn_cobbler.png", "x": 1020.0},
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
var _notebook: NotebookScreen = null

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

	var backdrop := TitleBackdrop.new()
	backdrop.name = "Backdrop"
	backdrop.position = Vector2.ZERO
	backdrop.size = size
	# The scenery is scenery. Without this it is a full-screen Control sitting
	# over every button, and `reachable-ui` is right to call them blocked.
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	_build_scenery()
	_build_text()
	_build_buttons()
	_play_entrance()


func _build_text() -> void:
	var width: float = float(get_viewport_width())

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Plant Tower Defense"
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

	var hint := Label.new()
	hint.name = "HintLabel"
	hint.text = "Up / Down to choose  ·  Enter to grow"
	hint.position = Vector2(0, HINT_Y)
	hint.size = Vector2(width, 22)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(GardenTheme.PAPER, 0.55))
	add_child(hint)


## Zero is not a score, it is the absence of one, and "Best endless run: 0 seeds
## grown" reads like a bug on a first launch. Separated out so the wording is
## assertable without building the screen.
static func high_score_text() -> String:
	if RunConfig.high_score <= 0:
		return "No endless run on record yet."
	return "Best endless run: %d seeds grown" % RunConfig.high_score


func _build_buttons() -> void:
	var left: float = float(get_viewport_width()) / 2.0 - BUTTON_WIDTH / 2.0
	var y: float = BUTTON_TOP

	# What each mode is goes in the label, not in a tooltip.
	#
	# A first pass put it in `tooltip_text` and that was wrong twice over. A
	# title screen is the one place a player has not learned to hover yet, so
	# the difference between the two modes was hidden behind a gesture nobody
	# makes on a menu. And the tooltip outlives the button: pressing Designer's
	# Notebook while its own tooltip is up leaves that tooltip floating over the
	# notebook, because the popup belongs to the Viewport rather than to the
	# button the overlay covered.
	_start_button = _make_button("StartButton", "Start  ·  8 waves", left, y, BUTTON_HEIGHT)
	_start_button.pressed.connect(_start_campaign)
	y += BUTTON_HEIGHT + BUTTON_GAP

	_endless_button = _make_button("EndlessButton", "Endless  ·  no finish line", left, y, BUTTON_HEIGHT)
	_endless_button.pressed.connect(_start_endless)
	y += BUTTON_HEIGHT + BUTTON_GAP

	_notebook_button = _make_button("NotebookButton", "Designer's Notebook", left, y, 46.0)
	_notebook_button.pressed.connect(_open_notebook)

	# Explicit wrap-around, so Down off the last button returns to the first
	# instead of dead-ending — the geometric default only ever walks the list.
	_link_focus([_start_button, _endless_button, _notebook_button])
	_start_button.grab_focus()


func _make_button(node_name: String, label: String, x: float, y: float, height: float) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.position = Vector2(x, y)
	button.size = Vector2(BUTTON_WIDTH, height)
	add_child(button)
	return button


func _link_focus(buttons: Array[Button]) -> void:
	for i: int in buttons.size():
		var above: Button = buttons[(i - 1 + buttons.size()) % buttons.size()]
		var below: Button = buttons[(i + 1) % buttons.size()]
		buttons[i].focus_neighbor_top = above.get_path()
		buttons[i].focus_neighbor_bottom = below.get_path()
		buttons[i].focus_previous = above.get_path()
		buttons[i].focus_next = below.get_path()


## Sprite2D, not TextureRect, for every decoration.
##
## These move, and two of them walk off the edge of the screen on purpose. As
## Controls that would be a steady stream of `validate-ui` findings about
## offscreen and out-of-parent Controls — findings that would be correct about
## Controls and meaningless about scenery. A Node2D is simply not what those
## checks look at, which is the honest way to say "this is not UI".
func _build_scenery() -> void:
	for entry: Dictionary in PLANTS:
		var sprite := _make_sprite(String(entry["sprite"]), PLANT_SCALE)
		sprite.name = "Plant_%d" % _plants.size()
		# Origin at the base of the stem, art shifted up above it. `offset` is
		# in texture pixels (applied before `scale`), and putting the node's own
		# origin in the soil is what makes the sway below a lean rather than a
		# slide — a Sprite2D rotates about its position, not about its picture.
		sprite.offset = Vector2(0.0, -sprite.texture.get_height() / 2.0)
		sprite.position = Vector2(float(entry["x"]), PLANT_BASE_Y)
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
		# Each plant is given its own phase, or four plants sway as one object.
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
		_start_button, _endless_button, _notebook_button,
		get_node("HintLabel") as Control,
	]
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
	if _notebook != null and is_instance_valid(_notebook):
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


func _set_menu_active(active: bool) -> void:
	var mode: Control.FocusMode = Control.FOCUS_ALL if active else Control.FOCUS_NONE
	# Mouse filter as well as focus. The notebook's Backdrop swallows clicks, so
	# the buttons cannot be *pressed* through it — but the Backdrop is 0.88
	# alpha, so a button still tracking the mouse underneath lights up in its
	# hover colour and that glow shows through the paper. An ignored Control
	# never receives the enter event at all.
	var filter: Control.MouseFilter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	for button: Button in [_start_button, _endless_button, _notebook_button]:
		button.focus_mode = mode
		button.mouse_filter = filter


func get_viewport_width() -> int:
	return ProjectSettings.get_setting("display/window/size/viewport_width", 1152)


func get_viewport_height() -> int:
	return ProjectSettings.get_setting("display/window/size/viewport_height", 648)


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
