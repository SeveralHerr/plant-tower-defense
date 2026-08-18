class_name ScreenMetrics
extends RefCounted

## How big the screen is — asked as the TWO different questions it always was.
##
## ## Why this file exists (plant-tower-defense-nrup)
##
## Six places in `game/` read
## `ProjectSettings.display/window/size/viewport_width|height` and called the
## result "the viewport": `Hud`, `TitleScreen`, `OverlayScreen` and `PauseScreen`
## each declared their own getter pair, and `KeyBindingScreen.panel_rect()` and
## `OptionsScreen.rows_capacity()` inlined the read a seventh and eighth time.
## Cycle 105 fixed the copy in `Hud` (plant-tower-defense-0jye) and could not
## touch the rest.
##
## The proximate cause was copy-paste. The structural cause is that ONE NAME WAS
## ANSWERING TWO QUESTIONS, and only one of them has `ProjectSettings` for an
## honest source:
##
## 1. **"How big is the screen I have to cover?"** — the live canvas. Under
##    `stretch/mode=canvas_items` with `stretch/aspect="expand"` this is NOT the
##    project setting: `expand` shows MORE canvas on whichever axis the window has
##    spare, so a 21:9 window is 1536x648 canvas units and a 4:3 one is 1152x864.
##    A root Control sized from the setting stops short of the window on one axis,
##    and the backdrop under an overlay stops with it — which on `PauseScreen`,
##    whose backdrop is `MOUSE_FILTER_STOP` precisely so the board underneath
##    cannot be played through a pause, means a strip of live, clickable board.
##
## 2. **"How big is the canvas this surface was composed on?"** — the design size.
##    Every row budget in this game is a statement about it: `OptionsScreen`'s six
##    rows, `KeyBindingScreen`'s nine verbs, `TitleScreen.menu_capacity()`,
##    `RunSummary.rows_capacity()`. So are `TitleScreen.PLANT_X`'s hand-placed
##    lawn slots. Those numbers must NOT follow the window, and the reason is
##    stronger than taste: `expand` never yields a canvas SMALLER than the design
##    size on either axis, so the design size is the WORST CASE a budget has to
##    survive. A budget measured against the live viewport gets a bigger allowance
##    on every window that is not exactly 16:9 — including the 64x64 headless one,
##    where the canvas comes out 1152x1152 and a "the surface is exactly full"
##    tripwire goes slack while still reporting green.
##
## Half the callers are `static` on purpose — `TitleScreen.button_rect()`,
## `menu_capacity()`, `PauseScreen.card_rect()`, `OptionsScreen.rows_capacity()`
## exist so a test can ask "would a seventh destination fit" without building the
## screen. **A static function has no `get_viewport()`.** That is what made the
## `ProjectSettings` read the only implementation anyone could write, and once it
## existed the instance callers took it too. Naming the two questions apart is the
## fix; deleting the `ProjectSettings` read would break every static caller.
##
## So: `design_*` for a budget or a composition coordinate, `live_*` for anything
## that has to reach the edge of the window. Both live here, once.

## The size this game is composed at. The project setting, under a name that says
## which question it answers.
##
## The defaults match Godot's own for these settings, so this returns 1152x648 on
## a project that never wrote them down — which is this one (`project.godot` sets
## only `stretch/mode` and `stretch/aspect`).
static func design_width() -> int:
	return int(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))


static func design_height() -> int:
	return int(ProjectSettings.get_setting("display/window/size/viewport_height", 648))


static func design_size() -> Vector2:
	return Vector2(float(design_width()), float(design_height()))


## The canvas `node` is actually being drawn on, in the units it is laid out in.
##
## `get_visible_rect()` rather than `Window.size`: the former respects the
## content-scale override `stretch/mode=canvas_items` installs and returns CANVAS
## units, which is what every `Control.position` on the surface is in. `Window.size`
## returns physical pixels and would be wrong for all of them.
##
## Falls back to the design size twice over, and both fallbacks are load-bearing:
##
## - **no viewport** — a screen constructed outside a tree. `PauseScreen.build()`
##   and `KeyBindingScreen.build()` hand back an unparented node, and a couple of
##   tests read a screen's geometry without ever hosting it.
## - **a zero-size viewport** — reports (0, 0) before its first layout pass, and
##   laying a surface out against zero collapses every rect on it into something
##   `findings`' own `ui_zero_size` check would then report. The design size is the
##   honest answer to "how big is the screen" before there is one.
static func live_size(node: Node) -> Vector2:
	if node == null or not is_instance_valid(node):
		return design_size()
	var vp: Viewport = node.get_viewport()
	if vp == null:
		return design_size()
	var live: Vector2 = vp.get_visible_rect().size
	if live.x <= 0.0 or live.y <= 0.0:
		return design_size()
	return live


static func live_width(node: Node) -> int:
	return int(live_size(node).x)


static func live_height(node: Node) -> int:
	return int(live_size(node).y)


## The left edge that centres a `width`-wide composition on `node`'s live canvas.
##
## The idiom four surfaces had each written out: `KeyBindingScreen.panel_rect()`
## computed `(viewport - width) / 2.0`, and `OptionsScreen.PANEL.x` (226 for a
## 700-wide paper) and `NotebookScreen.PANEL.x` (76 for a 1000-wide one) are the
## same sum with the design width already substituted in. Identical at 1152 —
## which is why the two baked constants never looked wrong — and a rigid
## translation of the whole composition at any other width, so every offset
## measured from the paper's left edge survives it untouched.
##
## Floored to a whole pixel: a paper on a half-pixel puts every Label on the
## surface on one, and the theme's 1px panel border is where that shows.
static func centred_left(node: Node, width: float) -> float:
	return floorf(maxf(0.0, (live_size(node).x - width) / 2.0))
