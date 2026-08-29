extends Node

## HOLD-TO-REVEAL, extracted out of `game/hud.gd` the same way `hud_selection.gd`
## was (plant-tower-defense-crj9). Every plant/packet button already carries its
## description in `tooltip_text` (plant_button_tooltip/packet_tooltip) and a mouse
## reveals it for free via the engine's native tooltip popup -- but native
## `tooltip_text` never fires from a touch press, so a touch player has no way to
## read a blurb before spending seeds on it. This is the touch half: hold a button
## past HOLD_THRESHOLD_SEC and its own `tooltip_text` appears in a small popup
## anchored to it, exactly as a mouse hover would show.
##
## DELIBERATELY NO `class_name`, for the same reason `hud_selection.gd` gives:
## nothing outside `hud.gd` needs to name this type, and giving it one would only
## exist to satisfy the class-name-in-a-test rule for the wrong reason. `Hud` owns
## one instance and forwards to it; the pure decision (`consume_suppressed`) is
## covered by the test suite through that instance instead of a static function,
## since it is measuring state that changes over calls, not a computation.

## Below this, a press-and-release is an ordinary click. At or above it, the press
## reveals a description instead of acting on the button -- see `consume_suppressed`.
const HOLD_THRESHOLD_SEC := 0.45

## How far below (or, if that runs off the top, above) the held button the popup
## sits.
const POPUP_GAP := 8.0

var _timer: Timer
var _popup: PanelContainer
var _label: Label
var _held: BaseButton
## Buttons whose current press already passed the hold threshold. The purchase
## handler consumes this once per press so the SAME hold that revealed the
## description does not also spend on it: a player reading "30 seeds" before
## deciding is the point, not a race against their own finger.
var _suppressed: Dictionary = {}


func _init() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_hold_timeout)
	add_child(_timer)

	_popup = PanelContainer.new()
	_popup.name = "LongPressPopup"
	_popup.visible = false
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_theme_stylebox_override("panel", GardenTheme.paper_panel())
	_popup.custom_minimum_size = Vector2(220, 0)
	add_child(_popup)

	_label = Label.new()
	_label.name = "Text"
	_label.add_theme_color_override("font_color", GardenTheme.INK)
	_label.add_theme_font_size_override("font_size", 14)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup.add_child(_label)


## Wires one button into hold-to-reveal. The popup always shows the button's OWN
## `tooltip_text` at reveal time, not a copy taken here -- refresh() rewrites
## tooltips as unlocks change, and reading it live keeps the hold in step with the
## same text a mouse hover already shows.
func watch(button: BaseButton) -> void:
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))


## True, and cleared, exactly once for a button whose most recent press was held
## past the threshold. Call this before acting on that button's `pressed`.
func consume_suppressed(button: BaseButton) -> bool:
	return _suppressed.erase(button)


func _on_button_down(button: BaseButton) -> void:
	_held = button
	_timer.start(HOLD_THRESHOLD_SEC)


func _on_button_up(button: BaseButton) -> void:
	_timer.stop()
	_popup.visible = false
	if _held == button:
		_held = null


func _on_hold_timeout() -> void:
	if _held == null or not is_instance_valid(_held):
		return
	var text := _held.tooltip_text
	if text == "":
		return
	_suppressed[_held] = true
	_reveal(_held, text)


func _reveal(button: BaseButton, text: String) -> void:
	_label.text = text
	_popup.visible = true
	_popup.size = Vector2.ZERO   # shrink back to content before measuring below
	var button_rect := button.get_global_rect()
	var viewport_size := button.get_viewport_rect().size
	var popup_size := _popup.get_combined_minimum_size()
	var pos := Vector2(button_rect.position.x, button_rect.position.y - popup_size.y - POPUP_GAP)
	if pos.y < 0:
		pos.y = button_rect.position.y + button_rect.size.y + POPUP_GAP
	pos.x = clampf(pos.x, 0, maxf(0, viewport_size.x - popup_size.x))
	_popup.position = pos
