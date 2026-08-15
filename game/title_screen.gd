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

const GAME_SCENE := "res://game/game.tscn"

const INK := Color(0.12, 0.15, 0.13)
const PAPER := Color(0.925, 0.863, 0.722)
const LEAF := Color(0.180, 0.800, 0.443)
const GOLD := Color(0.78, 0.62, 0.38)

var _start_button: Button
var _endless_button: Button


func _ready() -> void:
	# Explicit position+size, not an anchor preset: this Control is the scene
	# root added straight under the Viewport with no sized CanvasLayer/Control
	# ancestor to anchor against, so PRESET_FULL_RECT silently resolved to a
	# 0x0 rect — invisible on the bare title screen (INK is nearly the
	# viewport's own clear colour) but very visible once the Notebook overlay
	# tried to use the same trick to hide the buttons underneath it.
	position = Vector2.ZERO
	size = Vector2(get_viewport_width(), get_viewport_height())
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = INK
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(get_viewport_width(), get_viewport_height())
	add_child(backdrop)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Plant Tower Defense"
	title.position = Vector2(0, 150)
	title.size = Vector2(get_viewport_width(), 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", PAPER)
	add_child(title)

	var subtitle := Label.new()
	subtitle.name = "SubtitleLabel"
	subtitle.text = "Plants fight bugs. One free plant to start."
	subtitle.position = Vector2(0, 214)
	subtitle.size = Vector2(get_viewport_width(), 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", LEAF)
	add_child(subtitle)

	var score := Label.new()
	score.name = "HighScoreLabel"
	score.text = "Best endless run: %d seeds grown" % RunConfig.high_score
	score.position = Vector2(0, 254)
	score.size = Vector2(get_viewport_width(), 26)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 15)
	score.add_theme_color_override("font_color", GOLD)
	add_child(score)

	_start_button = Button.new()
	_start_button.name = "StartButton"
	_start_button.text = "Start (8 waves)"
	_start_button.position = Vector2(get_viewport_width() / 2.0 - 130, 330)
	_start_button.size = Vector2(260, 48)
	_start_button.pressed.connect(_start_campaign)
	add_child(_start_button)

	_endless_button = Button.new()
	_endless_button.name = "EndlessButton"
	_endless_button.text = "Endless mode"
	_endless_button.position = Vector2(get_viewport_width() / 2.0 - 130, 388)
	_endless_button.size = Vector2(260, 48)
	_endless_button.pressed.connect(_start_endless)
	add_child(_endless_button)

	var notebook_button := Button.new()
	notebook_button.name = "NotebookButton"
	notebook_button.text = "Designer's Notebook"
	notebook_button.position = Vector2(get_viewport_width() / 2.0 - 130, 446)
	notebook_button.size = Vector2(260, 40)
	notebook_button.pressed.connect(_open_notebook)
	add_child(notebook_button)


func _open_notebook() -> void:
	var notebook := NotebookScreen.new()
	notebook.name = "Notebook"
	notebook.back_requested.connect(func() -> void: notebook.queue_free())
	add_child(notebook)


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
