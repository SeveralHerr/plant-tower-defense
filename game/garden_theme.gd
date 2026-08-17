class_name GardenTheme
extends RefCounted

## One palette, one Button look, one set of motion rules — shared by the title
## screen, the Designer's Notebook and the in-game HUD.
##
## Both of those screens used to paint themselves out of locally-declared INK /
## PAPER / LEAF constants and then leave every Button on Godot's default theme,
## which is grey-on-grey. The result was a cream-and-green screen with three
## slate-grey slabs bolted to it: the two halves had no relationship at all.
## Colour lives here so there is exactly one place a shade can be changed, and
## `build()` is what stops a Button from opting out of the palette by default.
##
## The palette is shared with the HUD; `build()` is not.
##
## That distinction is the whole of the arrangement, and the two halves used to be
## conflated into one blanket "nothing here touches the HUD". `Hud` builds every
## Control it owns in code, sized and coloured against the board's own constants,
## and applying this Theme to it would repaint its Buttons out from under that
## layout — so it deliberately never calls `build()`, and
## `test_the_hud_still_refuses_the_shared_theme` pins that it never starts.
##
## Its *colours* are a different question, and the answer changed when the HUD's
## private half outgrew the shared one. Four duplicated shades were a rounding
## error; ten — with the only red in the game among them — meant the post-mortem
## card could not reach the colour that says "this cost you something" without
## declaring an eleventh copy of it. The HUD now aliases the constants below,
## which keeps its local, semantic names (`UPROOT_ARMED`, `HEALTH_LOW`) while
## leaving exactly one place each value is written down.

## The dark green-black everything sits on. Aliased by the HUD as `Hud.INK`.
const INK := Color(0.12, 0.15, 0.13)
## One step up from INK, for hairlines and dividers that must not read as black.
const INK_SOFT := Color(0.22, 0.26, 0.23)
const PAPER := Color(0.925, 0.863, 0.722)
const PAPER_DARK := Color(0.851, 0.788, 0.659)
## The blue rule on the notebook paper in image1-image6. Reused literally.
const PAPER_RULE := Color(0.612, 0.714, 0.808)
## And the red margin line down the left of those same pages.
const PAPER_MARGIN := Color(0.847, 0.412, 0.412)
const LEAF := Color(0.180, 0.800, 0.443)
const LEAF_DARK := Color(0.106, 0.463, 0.267)
const GOLD := Color(0.78, 0.62, 0.38)
const SOIL := Color(0.361, 0.243, 0.157)

## The one warning red anywhere in the game: an armed Uproot, a plant nearly
## chewed through, a wave whose threat has run away, and — once it is folded in —
## a lane under pressure.
##
## One constant rather than one per site, because the design intent is that a red
## on any surface means the same thing: "this costs you something". That intent is
## only true for as long as there is one value. The HUD held three copies of it
## (UPROOT_ARMED, THREAT_HOT, HEALTH_LOW) and `Plant.HEALTH_BAR_HURT` a fourth, at
## which point "the same red everywhere" was a comment rather than a fact.
## Semantic names still belong at each site; they alias this.
##
## The fourth is gone: a *constant* alias is only half the job once a colourblind
## ramp exists, because the alias pins the red and says nothing about which ramp
## is on. The in-world bar now calls `Hud.health_color_on(0.0, safe)` rather than
## naming a colour at all, which is the shape anything reaching for this constant
## as a "bad" cue should copy — name the ramp end, not the paint.
##
## What one value cannot do is say *which* sentence a given red is saying, and on
## the board there are two: a live warning ("this costs you something right now" —
## the hover cursor over a cell you may not build on, a plant being chewed) and a
## record ("this already happened" — lane pressure). Both are DANGER, both are
## painted over 64px cells, and the two are routinely stacked on the same pixels.
##
## So the board carries a **second channel that is not hue, and exactly one rule
## for it: a solid red surface is a live warning, a broken one is not.** Lane
## pressure is hatched (LanePressureOverlay.HATCH_SPACING), a bleeding plant's
## health bar is solid and a regrowing one is notched (Plant.HEALTH_BAR_SEGMENTS).
## Anything new that reaches for this constant owes an answer to "solid or broken",
## and adding a fifth red is not one — the player this rule exists for cannot see
## the difference between any two of them.
##
## The HUD is deliberately outside the rule. Its one red (Hud.UPROOT_ARMED) is on a
## Button's font, not on a surface, and it is already the best-separated cue in the
## game: the label rewrites itself to "Really uproot? (+N)" and Sfx.UPROOT_ARMED
## plays. Text and sound are two channels that are not colour, so it needs no third.
const DANGER := Color(0.85, 0.25, 0.22)
## The midpoint of that warning ramp. It exists because cream straight to DANGER
## passes through a muddy pink that reads as neither safe nor dangerous, so any
## surface ramping toward a warning wants this stop in the middle.
const AMBER := Color(0.93, 0.72, 0.30)

## The colourblind-safe alternative to the LEAF -> AMBER -> DANGER ramp, switched
## on by `RunConfig.colorblind_safe`.
##
## The rule above ("a second channel that is not hue") is a rule about the BOARD,
## and the two bars a player watches hardest in combat are not on it. A plant's
## health fill is `HEALTH_LOW.lerp(HEALTH_FULL, fraction)` and the wave readout is
## `Hud.threat_color(level)`; both are a solid block of colour that carries its
## whole meaning in hue, with nothing else to read them by. Green-to-red is the
## single worst pair to say that in — the two ends of it are the two ends of the
## channel deuteranopia and protanopia flatten, so the "everything is fine" fill
## and the "this plant is nearly gone" fill land on each other.
##
## Blue against orange is the conventional replacement and it is not merely a
## different pair of hues: the ends differ in LIGHTNESS as well, so the ramp still
## reads as a ramp in greyscale, which is the property red-green never had. The
## threat ramp keeps PAPER at its calm end for the reason threat_color documents —
## an early run should look like nothing is wrong — and warms toward the same
## orange the health bar spends on "bad", so the two bars say bad the same way.
##
## Three stops, deliberately mirroring the three above rather than inventing a
## second structure: SAFE_GOOD replaces LEAF, SAFE_MID replaces AMBER, SAFE_BAD
## replaces DANGER.
##
## The exact values are pinned by measurement, not by taste, and the first pick
## failed it. A mid blue against a mid orange is the picture everyone has of this
## fix, and `test_the_safe_ramp_separates_its_ends_in_more_than_the_red_green_channel`
## reported it as 0.157 of luminance between the ends against the green/red ramp's
## own 0.267 — a "colourblind-safe" pair that was HARDER to tell apart in greyscale
## than the one it replaced, and that would have shipped looking perfectly correct.
## So SAFE_GOOD is a dark blue and SAFE_BAD a bright orange: 0.33 against 0.69, a
## gap of 0.36, with the red-green distance between them less than half the green/
## red ramp's. SAFE_MID sits between the two in lightness so the threat ramp is
## still monotonic in the channel that survives.
const SAFE_GOOD := Color(0.114, 0.353, 0.678)
const SAFE_MID := Color(0.976, 0.780, 0.451)
const SAFE_BAD := Color(0.976, 0.647, 0.196)

## Radius/border used by every button and panel, so a screen cannot half-adopt
## the look.
const CORNER: int = 6
const BORDER: int = 2

## The two grounds the board is actually tiled with — the colours anything drawn
## ON the playfield will be seen against.
##
## Not new paint. `Board`'s header derives the whole tile set by sampling the
## midpoint of every edge of all 299 kit PNGs and grouping them by whether that
## edge is dirt `#BB8044` or grass `#2ECC71`, and `#2ECC71` is `LEAF` to three
## decimal places — the lawn's hue was already in this file, with nothing
## anywhere saying so. That silence is how a plant once shipped drawn in LEAF and
## vanished into the grass it was standing on: no gate in this project compares a
## mark against the ground under it, and none can while the ground's colour is
## only written down inside a PNG.
##
## GROUND_GRASS aliases LEAF rather than restating it, so a change to the palette
## cannot leave the two disagreeing about what the lawn is. GROUND_DIRT is
## `#BB8044` rounded to the three decimals the rest of this file is written at.
const GROUND_GRASS := LEAF
const GROUND_DIRT := Color(0.733, 0.502, 0.267)

## The floor a mark drawn on the board must clear against both grounds.
##
## 0.12 is a sixth of the game's full luminance span — INK measures 0.142 and
## PAPER 0.866, so the whole palette spans 0.724 — and it is a floor, not a
## target. Measured against what is on the board today: the page frame's cream
## clears it by 0.224 against grass and 0.332 against dirt, its ink hairline by
## 0.393 and 0.285, and DANGER — the hatch on the road, the tightest real pair in
## the game — by 0.267 against grass and **0.159 against dirt**, which is only a
## third clear of this floor. That last number is the one to know: the gate has
## one mark sitting close to it rather than a comfortable margin everywhere, so a
## new red-brown mark is where it will bite first.
const GROUND_SEPARATION_MIN: float = 0.12


## How far apart two colours are in the one channel that survives colour being
## thrown away.
##
## Luminance, because that is what "survives" means: `OVERLAY_GRAMMAR.md`'s two-
## channel rule is stated as a greyscale test, and the existing
## `test_the_safe_ramp_separates_its_ends_in_more_than_the_red_green_channel`
## already measures exactly this by hand. This is that measurement given a name so
## the next site does not roll a third copy of it.
static func separation(a: Color, b: Color) -> float:
	return absf(a.get_luminance() - b.get_luminance())


## Would `mark` still be visible if it were painted straight onto the playfield?
##
## WHAT THIS DOES NOT CHECK, because a helper that answers a narrower question
## than its name suggests is worse than no helper. It measures `mark` against the
## two BASE tile hues and nothing else: not the kit tiles' own speckle and shading,
## not the lane-pressure hatch, not the blocked-cell wash, not a sprite the mark
## happens to land on, and not opacity — a colour that clears this at alpha 1.0
## can still disappear at 0.05. It answers one question — "is this the lawn's own
## hue, or near enough to it" — which is the question that has actually gone wrong
## here, and it answers it in greyscale so it holds for a colourblind player too.
static func reads_on_ground(mark: Color) -> bool:
	return separation(mark, GROUND_GRASS) >= GROUND_SEPARATION_MIN \
		and separation(mark, GROUND_DIRT) >= GROUND_SEPARATION_MIN


## A Theme applied to a screen's root Control, inherited by every descendant —
## which is why the Notebook, added as a child of the title screen at runtime,
## does not have to ask for it.
static func build() -> Theme:
	var theme := Theme.new()
	theme.set_stylebox("normal", "Button", _button_box(PAPER, INK))
	theme.set_stylebox("hover", "Button", _button_box(PAPER.lightened(0.12), LEAF))
	theme.set_stylebox("pressed", "Button", _button_box(PAPER_DARK, LEAF_DARK))
	theme.set_stylebox("disabled", "Button", _button_box(Color(PAPER, 0.35), Color(INK, 0.35)))
	# Focus is drawn *over* the state box, so it has to be transparent inside or
	# it repaints the fill and cancels the hover colour out.
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.set_corner_radius_all(CORNER)
	focus.set_border_width_all(3)
	focus.border_color = GOLD
	focus.set_expand_margin_all(2)
	theme.set_stylebox("focus", "Button", focus)

	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_focus_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", Color(INK, 0.45))
	theme.set_font_size("font_size", "Button", 18)
	return theme


static func _button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(CORNER)
	box.set_border_width_all(BORDER)
	box.border_color = border
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


## The notebook's page stock: cream, softly rounded, with an ink hairline so it
## reads as a sheet lying on the dark rather than a hole cut out of it.
static func paper_panel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER
	box.set_corner_radius_all(10)
	box.set_border_width_all(BORDER)
	box.border_color = INK_SOFT
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 14
	box.shadow_offset = Vector2(0, 6)
	return box


## Entrance tweens, hover pops and page cross-fades all ask this first.
##
## Headless has no renderer and pumps frames only when a test explicitly awaits
## one, so an entrance that starts a node at `modulate.a = 0` and relies on a
## Tween to finish the job leaves that node invisible — and, worse, leaves it
## invisible in a way no assertion about `size` or node paths would ever catch.
## Every animation in these screens is therefore an enhancement layered on top
## of an already-correct final state, gated here.
static func animations_enabled() -> bool:
	return DisplayServer.get_name() != "headless"


## Swaps a 1x sprite path for its 2x sibling when one exists.
##
## The notebook blows a 64x64 sprite up to a ~200px box, where the 1x source
## turns to mush under bilinear filtering. `assets/sprites/retina/<name>@2x.png`
## is already generated for every sprite by `tools/render_svg.gd`; this is what
## makes the notebook actually use it.
static func retina_path(sprite_path: String) -> String:
	var base: String = sprite_path.get_file().get_basename()
	var retina: String = "res://assets/sprites/retina/%s@2x.png" % base
	return retina if ResourceLoader.exists(retina) else sprite_path


## How wide `text` will draw in a Label carrying `font_size`.
##
## The one primitive every "does this text fit its box" question in this project
## needs, and it lives here because the answer depends on the theme — which is what
## this class is. Three screens now size themselves from it and four tests assert
## against it.
##
## **Why a detached Label rather than a Font loaded by path.** The width that matters
## is the one the real Label will draw at, and a Label resolves its font through the
## theme chain, not through any path this file could name. Asking a Label is the only
## way to get the same answer the Label will get. It is detached because the callers
## are static — `PauseScreen.card_width()` answers before any instance exists — and
## that is sound *in this project* because no custom theme is set in project.godot,
## so an off-tree Label resolves the same font as an in-tree one.
##
## That last clause is a fact about this project rather than about Godot, so it is
## asserted rather than trusted: see
## test_the_cards_own_measurement_agrees_with_the_labels_it_builds, which compares
## this against `_T.text_width` on real, in-tree, rendered rows. If a custom theme is
## ever added, that test fails and this function is where the fix goes.
##
## Returns 0.0 rather than erroring when no font resolves — a measurement of "I do not
## know" that reads as "fits anything" would be the wrong failure, so callers that
## floor a width against a minimum (all of them) get the minimum.
static func measure(text: String, font_size: int) -> float:
	var probe := Label.new()
	probe.add_theme_font_size_override("font_size", font_size)
	var font: Font = probe.get_theme_font("font")
	var width: float = 0.0
	if font != null:
		width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			probe.get_theme_font_size("font_size")).x
	probe.free()
	return width
