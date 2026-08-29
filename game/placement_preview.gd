class_name PlacementPreview
extends SelectionMarker
## The drawn-overlay grammar this cue belongs to is `game/OVERLAY_GRAMMAR.md`
## — what a solid ring, a dashed ring, a filled dot and a doubled width each
## mean, and the two places the grammar does not hold. Read it before adding a
## cue; its mechanical half is pinned by
## test_the_overlay_grammar_holds_where_it_is_mechanical.

## "This is where the plant you picked would go, and this is what it would
## cover." A sibling Node2D under Entities, drawn on its own, positioned at the
## hovered cell's centre.
##
## Subclasses SelectionMarker rather than reimplementing it: the brackets are
## deliberately the *same shape* the plant will wear once placed and selected,
## only dimmer and a size larger, so the hover cue reads as a promise of that
## state. Reusing the node also inherits the reason it exists at all — a cue
## drawn from a Plant's own _draw() is silently dropped by every subclass that
## overrides _draw() without chaining, which is how the Chomp Flower shipped
## with no selection feedback.
##
## The range ring is the part the flat cursor rect could never show. Coverage
## was previously invisible until *after* the seeds were spent and the plant
## selected — the one piece of information that decides where a Corn Cobbler
## should go was the one piece you could not see while deciding.
##
## Drawing that ring with equal confidence everywhere was itself a lie, though:
## 11 of the board's 94 buildable cells cover no road at a Corn Cobbler's reach
## and 36 cover none at a Chomp Flower's, and the ring looked identical on all
## of them. (Those were 15 and 34 until the road grew its climb in cycle 53 —
## the counts are re-derived in test_the_real_route_strands_exactly_the_cells_it
## _was_measured_to_strand, and they moved in opposite directions.) Seeds could be spent on a plant that would never fire once, with
## nothing saying so before the click or after it. See covers_road().

## A size larger than the selection brackets so the two are distinguishable
## when a preview hovers over an already-selected plant's cell.
const PREVIEW_HALF: float = 27.0
const PREVIEW_ARM: float = 9.0

## Dim relative to SelectionMarker.MARKER_COLOR: a hover is a suggestion, and
## it should not compete with the marker on the plant actually selected.
##
## Derived from the palette rather than hand-typed, which is the last pair the
## GardenTheme merge missed. They were `Color(0.55, 0.95, 0.62, 0.75)` and
## `Color(0.95, 0.42, 0.36, 0.75)` — close to these, but independently chosen:
## the old blocked red was *more* saturated in the red channel than DANGER
## itself, so it was not a lightening of anything and no amount of reading the
## constant would have told you it was meant to be the same red.
##
## They stay literals because they have to: `Color.lightened()` is a method
## call, and a GDScript `const` initialiser must be a constant expression, so
## `Color(GardenTheme.DANGER.lightened(0.25), 0.75)` is a hard parse error —
## which cascades into every script that depends on this one.
##
## So the tie to the palette is enforced by a test instead of by the compiler:
## test_the_placement_brackets_come_from_the_palette_and_still_look_the_same
## asserts each of these is within a small tolerance of the palette colour it
## belongs to, lightened. Change DANGER without changing this and the suite
## says so. `lightened` rather than the raw palette value because the dimming
## is the point — a hover is a suggestion, and the marker on the plant the
## player actually selected has to stay the loudest thing on the board.
const OK_COLOR := Color(0.55, 0.95, 0.62, 0.75)
## DARKENED SINCE CYCLE 163, AND IT WAS LIGHTENED (plant-tower-defense-wovu). The
## paragraph above argues that dimming a hover is the point, and it was right about the
## intent and wrong about the direction: `Color(0.95, 0.42, 0.36)` sits at luminance
## 0.528 against GROUND_DIRT's 0.534 — a separation of **0.006**, which is the road's own
## luminance, and 0.004 as drawn. In greyscale a blocked bracket on a road cell was gone.
## On grass it was 0.086, also under the 0.12 floor.
##
## THE ASYMMETRY IS WHAT MADE IT A DEFECT RATHER THAN A DIM CUE: OK_COLOR clears both
## grounds (0.149 and 0.230 as drawn) and BLOCKED cleared neither, so the cue that says
## YES read and the cue that says NO did not — on the state a player meets by hovering
## the road with anything but a Bramble selected.
##
## AND UN-LIGHTENING IS NOT ENOUGH, which is the measurement that decided the value. Raw
## `GardenTheme.DANGER` is 0.375 and still fails dirt at 0.119. Both grounds sit in the
## MIDDLE of the range, so a mark must leave the middle in one direction or the other,
## and lightening walks it toward them. This is DANGER darkened by 0.15: 0.242 on grass
## and 0.161 on dirt, both clear.
##
## The quiet the paragraph above wants is still there and is carried by ALPHA, which has
## not moved — a hover stays at 0.75 against the selection marker, and that ordering is
## what the test asserts. Quiet is not the same as unreadable.
const BLOCKED_COLOR := Color(0.72, 0.21, 0.19, 0.75)
## Dimmer still — the ring covers a large area, so at bracket alpha it would
## dominate the board.
const RING_ALPHA: float = 0.30
const RING_WIDTH: float = 1.5

## The hungry-pest warning. Amber, not the blocked red — the cell is legal and
## the player may well want it anyway; this is a risk, not a refusal.
##
## DEEP AMBER SINCE CYCLE 153, AND IT USED TO BE A BRIGHT ONE
## (plant-tower-defense-pt8p turned up that nothing had ever asked about it).
## `Color(1.0, 0.72, 0.20)` sits at luminance 0.742 against GROUND_GRASS's 0.643 — a
## separation of 0.100 against a floor of 0.12, and 0.085 at the alpha it ships with.
## `_draw_risk_ring` runs on the hovered cell and hovering only reaches buildable
## ground, so grass is the only ground this ring lands on and it failed there.
##
## The hue is unchanged in kind and the value is what moved: deep amber still reads as
## neither the blocked red nor the placeable green, which is the whole job of the
## colour, and it now clears BOTH grounds — 0.237 on grass and 0.144 on dirt, as drawn.
##
## BOTH, and the first attempt priced only grass. The reasoning was that hovering only
## reaches buildable ground, which is true of the CELL and false of the RING: at
## `RISK_RADIUS` 30 against a 64 px cell, a ring centred one cell from the lane spills
## onto it, and the live capture that was supposed to confirm the colour showed the
## lower arc lying across dirt. A cue whose geometry leaves the cell it is anchored to
## does not inherit that cell's ground.
##
## THIS RING IS ALSO DASHED AND THIN (`RISK_WIDTH` 2.0, `RISK_DASHES` 8), which is why
## the floor is the wrong thing to shave. A thin broken stroke has less ink to carry
## the contrast than the solid bars do, so if anything it wants more margin than a bar,
## not less.
const RISK_COLOR := Color(0.66, 0.31, 0.03, 0.85)
const RISK_RADIUS: float = 30.0
const RISK_WIDTH: float = 2.0
const RISK_DASHES: int = 8

## The dead-zone cue: legal cell, but this plant's reach touches no road, so it
## would stand there for the whole run and never fire once.
##
## Told apart from every other state by *shape*, not hue — this project just
## shipped mutation cues built on the same rule. The mark is a PADLOCK, and no
## other preview state draws a closed body with an arc standing on it: `at_risk`
## is a dashed circle with no straight edges anywhere, `placeable` is brackets
## plus one solid circle, blocked is brackets alone. In greyscale the lock is
## still the only thing on screen sitting inside the cell.
##
## IT WAS A SINGLE STRAIGHT BAR AT DEAD_BAR_ANGLE UNTIL plant-tower-defense-uqer,
## and the argument above was true of that bar as well — which is the point worth
## keeping. Distinctness inside the preview's own vocabulary was never the thing
## that failed. What failed is that a 45-degree slash on a lawn is a shape a tile
## seam makes too, so the cue was distinct from every other CUE and not distinct
## from the board's own noise. A player read it as a rendering defect and
## reported it as one. See the block at LOCK_BODY_HALF_W.
##
## The reach ring is still drawn, dimmed to the same slate, because "how far it
## would reach" is exactly the evidence for the claim — the player can see the
## circle falling short of the road rather than being told so.
##
## DARK SLATE SINCE CYCLE 152, AND IT USED TO BE A PALE ONE (plant-tower-defense-3h0s).
## The paragraph above claims the bar survives colour being thrown away. It did not:
## `Color(0.70, 0.73, 0.80)` sits at luminance 0.729 against GROUND_GRASS's 0.643, a
## separation of **0.086 against a floor of 0.12** — so the mark failed
## `GardenTheme.reads_on_ground` at full opacity, on the only ground it is ever drawn
## on, while the header argued it was legible in greyscale. Composited at
## `BOARD_DEAD_ALPHA` it was 0.029, a quarter of the floor.
##
## Nobody had pointed the gate at it. `reads_on_ground` exists precisely because a mark
## vanished into this lawn once, and this cue had no test naming it. The two failures
## compound: the gate was alpha-blind and said so, and alpha is the dominant term for
## every board mark.
##
## WHY DARK RATHER THAN A BRIGHTER PALE. `GardenTheme.reads_on_at`'s header carries the
## arithmetic: separation scales by exactly alpha, grass is bright at 0.643, and clearing
## the floor at a third of an alpha from the pale side needs a luminance above 1.0. Pale
## on this lawn is not a value that was chosen slightly wrong; it is a direction with no
## room in it. `OVERLAY_GRAMMAR.md` defines row 6 by its CHANNEL, and this bar is that
## row's one instance: it is told apart from everything else by the ground it lands on
## and by its shape, which is exactly what `Hud.dead_ground_tip` tells the player.
## (It said "by its angle" while the mark was a bar; the slate is unchanged by
## plant-tower-defense-uqer and every number above still holds, because alpha and
## luminance do not care what the stroke traces.)
const DEAD_COLOR := Color(0.24, 0.27, 0.36, 0.80)
const DEAD_BAR_WIDTH: float = 3.0
## Bar length is the bracket box, not the ring: a Corn Cobbler's ring is 176 px,
## and a 352 px diagonal slashed across the playfield reads as a board-wide
## overlay rather than as a note about one cell.
##
## THE DEAD-GROUND CUE NO LONGER DRAWS AT THIS ANGLE (plant-tower-defense-uqer).
## It is `dead_lock_points()` below. What still uses this constant is the
## REDUNDANT-patch pair, which is why it is still here and still named for a bar.
const DEAD_BAR_ANGLE: float = -PI * 0.25

# =============================================================================
# THE DEAD-GROUND GLYPH: A PADLOCK (plant-tower-defense-uqer)
#
# WHY THE SHAPE CHANGED, AND IT IS THE ONLY REASON. It was one straight stroke at
# DEAD_BAR_ANGLE, and a player looking straight at it reported it as a rendering
# defect -- "some weird diagonal lines on the corner of the map, in the grass
# area" -- with a screenshot of the board's own bottom-right corner. That is the
# whole finding. The cue was legible, it was contrast-checked, it was on the
# board from the opening screen, and it did not read as a cue at all, because a
# 45-degree slash on a lawn is a shape a tile seam or a texture bleed also makes.
# A padlock is not a shape anything else on this board makes by accident.
#
# WHAT IT DOES NOT FIX, stated because the temptation is to close the hint with
# it: a lock says "you cannot do this here" on sight and says nothing about WHY
# or about the counter-play. `Hud.dead_ground_tip` still carries "plant it closer
# to the road" and is still spent the same way. The icon fixes the report --
# a mark misread as an artifact -- and not the sentence.
#
# WHY IT IS STILL ONE POLYLINE. `Board.mark_dead_ground` paints `Line2D`
# children, for the reason board.gd's own header gives: a headless run paints no
# frame, so a `_draw()` there is a cue no gate can see. One `Line2D` per marked
# cell keeps that, keeps the pool's index-per-cell pairing, and keeps the board
# mark and the hover mark provably the SAME geometry -- both read
# `dead_lock_points()`, which is what
# test_the_board_mark_and_the_hover_bar_are_one_stroke_not_two asserts.
#
# HOW A PADLOCK IS ONE UNICURSAL PATH. It is not, quite: the body is a closed
# rectangle and the shackle is an arc standing on the middle of that rectangle's
# top edge, and no single stroke covers both without repeating something. The
# path below starts at the shackle's left foot, runs the arc over to its right
# foot, goes right along the top edge to the body's top-right corner, down, back
# along the bottom, up the left side, and then RETRACES the top edge from the
# body's top-left corner to its top-right. The retraced piece is drawn twice over
# identical pixels, which is invisible; the alternative is two nodes per cell,
# which breaks the pool's one-mark-per-cell index and the tests that pair against
# it. The order is chosen so the repeated run is the shorter one.
## Half-width of the lock's body. A fraction of the bracket box rather than a
## typed px, so a glyph is still inside its brackets if PREVIEW_HALF moves --
## test_the_dead_lock_fits_inside_the_bracket_box is the gate on that.
const LOCK_BODY_HALF_W: float = PREVIEW_HALF * 0.42
## Radius of the shackle arc, whose centre is the middle of the body's top edge.
## About 0.71 of the body's half-width, and the ratio was set by LOOKING at the
## running board rather than by arithmetic. At 0.26/0.48 (body 1.85x the shackle)
## the glyph read as a handbag in a screenshot of the corner it was drawn for; a
## real padlock's shackle is a larger fraction of its body than it feels like.
## Much narrower than this and it reads as a keyhole instead.
const LOCK_SHACKLE_RADIUS: float = PREVIEW_HALF * 0.30
## Half the glyph's total height, shackle crown to body base. Smaller than the
## 54 px stroke it replaces on purpose: a slash is read as a direction and can be
## long, an icon is read as a shape and has to sit inside one cell to be one.
const LOCK_HALF_HEIGHT: float = PREVIEW_HALF * 0.48
## Segments in the shackle's half-turn. Eight is where the crown stops reading as
## a chamfer at this radius; ten is cheap and leaves margin if the radius grows.
const LOCK_ARC_SEGMENTS: int = 10

## The redundancy cue (plant-tower-defense-3lu): legal cell, real road under the
## reach — and every one of those road cells is already inside a patch of the
## same plant that is standing there now. A Sticky Sundew's slow does not stack
## (StickySundew.META_SOURCES says why), so a second patch over exactly the same
## road costs thirty seeds and multiplies the crossing time by
## StickySundew.added_crossing_time_multiplier(1), which is 1.0. Nothing.
##
## Drawn in DEAD_COLOR, the same slate as dead ground, on purpose: the two are
## the same KIND of statement — "you may put it here, and it will do nothing" —
## so telling them apart is the *shape's* job, which is the rule the dead mark was
## built on in the first place. Dead ground is a padlock; redundant ground is two
## parallel bars at DEAD_BAR_ANGLE. That pairing used to be one-bar-versus-two,
## and plant-tower-defense-uqer ended it: see `_draw_redundant_bars` for what is
## carrying this cue now that it is no longer counted against a single bar. An
## equals sign laid over the cell:
## "the same as the patch you already have". Countable at a glance, legible with
## the colour thrown away, and still nothing but straight strokes, which no other
## preview state draws outside the four corner arms.
##
## The evidence is already on screen and needs no extra drawing: a Sundew's dew
## beads are always on (see StickySundew.DROPLETS), so the rim of the patch that
## makes this one redundant is visible right next to the ring being previewed.
const REDUNDANT_BAR_GAP: float = 8.0

## Reach of the plant being previewed, from PlantCatalog.reach(). 0.0 draws no
## ring at all, which is correct for the Sunflower rather than a missing case.
var reach: float = 0.0

## Which plant is being previewed, when the caller happens to know. Optional, and
## the default is deliberately the useless-but-harmless one: left &"" the kind is
## inferred from `reach` instead, because a Sticky Sundew is the only catalogue
## entry whose reach is StickySundew.SAP_RADIUS. That inference is what lets the
## cue work with no change at Game._update_preview's call site at all.
##
## Set it if you would rather not lean on that — one line, next to the existing
## `_preview.reach = PlantCatalog.reach(selected_plant)`:
##
##     _preview.plant_id = selected_plant
##
## The day a second plant is priced at the same radius, the inference starts
## warning about the wrong one and that line becomes required rather than
## preferable.
##
## SINCE THE GHOST IT IS ALSO WHAT THE PLAYER SEES. Setting this swaps the translucent
## plant drawn under the brackets (see `GHOST_ALPHA`), so the inference above is now the
## fallback for the CUE's shape as well as for the warning's wording. Game sets it on
## every `_update_preview`, so the assignment is on the hover path and the setter is
## guarded to reload the texture only when the id actually changes.
var plant_id: StringName = &"":
	set(value):
		if plant_id == value:
			return
		plant_id = value
		_refresh_ghost()
## False for a cell that is road, off-board, occupied, or unaffordable. Only
## recolours; a blocked preview still draws, because "you cannot put it here"
## is the thing worth showing.
##
## Game sets it from Game.would_plant_at(), which is the same predicate
## Game._click_at consults before it lets anything else have the click — so true
## here is a promise that the click plants, not a hint that it might.
var placeable: bool = true

## The cell is legal, but a hungry pest walking past can reach whatever stands
## here — and this plant cannot fight back. Draws a dashed warning ring at one
## cell's reach, which is exactly how far a hungry pest can lunge.
##
## Only meaningful for a plant with no reach of its own: a Corn Cobbler beside
## the road is the entire point of a Corn Cobbler, and warning about it would
## train the player to ignore the cue. A Sunflower there is one hungry mutation
## away from losing the run's economy, and nothing on screen said so.
var at_risk: bool = false

## The board the hovered cell belongs to, used to answer "does this reach any
## road at all". Optional: left null it is resolved from the preview's own
## siblings — Game builds the board and the preview as children of the same
## Entities node — so the cue works with no change at the call site. Assign it
## explicitly if you would rather not rely on that.
var board: Board = null

## The road cells some standing plant already has in range, as a set. Pushed by
## Game._update_preview from covered_road_cells(); empty means "nothing is
## covered yet" AND, honestly, "nobody has told me". Both read the same here and
## that is fine — with an empty set every road cell in reach is marked new, which
## is exactly right on an empty garden and harmless before the first push.
var covered_now: Dictionary = {}

## Radius of the dot marking a road cell this purchase would newly defend. Small
## on purpose: the marks sit INSIDE the range ring and must not compete with it,
## and there can be nine of them at a Corn Cobbler's reach.
const NEW_COVER_DOT: float = 4.0

## The node name the ghost wears, so a test (or `scene-tree` on a running game) can find
## it by name rather than by index among the preview's children.
const GHOST_NODE_NAME := "Ghost"

## Node names for the three cues converted off `_draw()` onto real children
## (plant-tower-defense-vlpg) -- the reach ring, the dead-ground lock and the
## redundant-coverage bars. Same reason GHOST_NODE_NAME exists: a test or
## `scene-tree` on a running game finds them by name rather than by index.
const REACH_RING_NODE_NAME := "ReachRing"
const DEAD_LOCK_NODE_NAME := "DeadLockMark"
const REDUNDANT_BAR_A_NODE_NAME := "RedundantBarA"
const REDUNDANT_BAR_B_NODE_NAME := "RedundantBarB"

## How solid the previewed plant is drawn under the brackets (plant-tower-defense-bmis).
##
## THE CUE IS THE PLANT ITSELF, which no drawn shape can substitute for. Everything else
## this node paints answers a question the player already knew to ask -- how far does it
## reach, is this legal, would it be wasted. The ghost answers the one they should not
## have to ask on a phone, where a fingertip covers most of a 64 px cell: *which plant am
## I about to buy, and where exactly does it land*. The bar's icon is 40 px of art behind
## a finger that has already moved on.
##
## HALF-VISIBLE ON PURPOSE, and this is the number that decides whether the cue is honest.
## At 1.0 a preview is pixel-identical to a plant already standing there, and a board with
## a hover on it would read as a board with an extra plant on it -- including in a
## screenshot, where nothing moves to give the game away. At 0.45 the ground and the road
## read straight through it, which is exactly the difference between "this is here" and
## "this would be here".
##
## THE GHOST NEVER CARRIES A VERDICT. It is one channel -- alpha -- and
## `OVERLAY_GRAMMAR.md`'s two-channel rule would be broken the moment placeable-vs-blocked
## was tinted into it, because the tint would be the only signal and a greyscale reader
## would lose it. The brackets already carry that verdict in colour AND in the ring they
## do or do not draw, and they keep the whole of it: this sprite is drawn the same on a
## legal cell and on a refused one. What tells you a cell is refused is the red around the
## plant, not the plant.
const GHOST_ALPHA: float = 0.45

var _resolved_board: Board = null

## The plant itself, drawn where it would stand. Built in `_init` and kept for the life
## of the node rather than made and freed per hover: this is on the mouse-motion path.
var _ghost: Sprite2D = null

## The reach ring, the dead-ground lock and the redundant-coverage bars, as real
## Line2D children rather than `draw_*()` calls inside `_draw()`
## (plant-tower-defense-vlpg). Built once in `_init` and kept for the node's whole
## life, same as `_ghost` above and for the same reason board.gd's own header
## gives at DEAD_GROUND_LAYER: a headless run paints no frame at all, so a cue
## that only exists inside `_draw()` is a cue no gate can ever see. A Line2D
## carries real `points` a test can read with no frame drawn -- see
## `refresh_cue_nodes()` and the three accessors below it.
var _reach_ring: Line2D = null
var _dead_lock_mark: Line2D = null
var _redundant_bar_a: Line2D = null
var _redundant_bar_b: Line2D = null


func _init() -> void:
	half = PREVIEW_HALF
	arm = PREVIEW_ARM
	_ghost = Sprite2D.new()
	_ghost.name = GHOST_NODE_NAME
	# BEHIND THE BRACKETS, and `show_behind_parent` rather than a negative `z_index`.
	# A Node2D paints its own `_draw` before its children, so at any z of 0 a 64 px
	# sprite would sit on top of the four corner arms it is supposed to be inside.
	# `z_index = -1` would fix that and break something worse: z is compared against
	# this node's SIBLINGS under Entities -- the Board's tiles among them -- so a -1
	# ghost is drawn under the lawn and is invisible on every cell. This flag reorders
	# the pair without touching where either sits against the rest of the board.
	_ghost.show_behind_parent = true
	# One channel, and it is alpha; see GHOST_ALPHA for why it never carries a verdict.
	_ghost.modulate = Color(1.0, 1.0, 1.0, GHOST_ALPHA)
	_ghost.visible = false
	add_child(_ghost)
	_refresh_ghost()
	_reach_ring = _new_cue_line(REACH_RING_NODE_NAME)
	_reach_ring.closed = true
	_dead_lock_mark = _new_cue_line(DEAD_LOCK_NODE_NAME)
	_redundant_bar_a = _new_cue_line(REDUNDANT_BAR_A_NODE_NAME)
	_redundant_bar_b = _new_cue_line(REDUNDANT_BAR_B_NODE_NAME)


## One Line2D built the way every converted cue in this file wants it: rounded
## joints so the padlock's corners and the ring's own closing seam do not show a
## miter spike, `show_behind_parent` so the cue stays under the brackets and the
## new-cover dots the way its `_draw()`-painted ancestor was (see `_draw()`'s own
## call order for the ring, dead lock and redundant bars it replaces), and
## invisible until the first `refresh_cue_nodes()` has an opinion.
func _new_cue_line(node_name: String) -> Line2D:
	var line := Line2D.new()
	line.name = node_name
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.show_behind_parent = true
	line.visible = false
	add_child(line)
	return line


## Swaps the ghost onto whatever `plant_id` now names, or hides it when that is nothing.
##
## `PlantCatalog.texture_path` rather than a table of our own -- the same load
## `Hud`'s plant-bar buttons do for their icons, so a plant whose art is replaced is
## replaced in three places at once and cannot be replaced in two.
##
## An unknown or empty id hides the ghost rather than drawing a blank: `plant_id` is
## documented as optional (see its own block), and the brackets, the ring and every
## warning still work without it. A cue that half-appears is worse than one that does not.
func _refresh_ghost() -> void:
	if _ghost == null:
		return
	var path: String = PlantCatalog.texture_path(plant_id) if PlantCatalog.has(plant_id) else ""
	if path == "":
		_ghost.texture = null
		_ghost.visible = false
		return
	_ghost.texture = load(path) as Texture2D
	_ghost.visible = _ghost.texture != null


## The ghost node, for tests and for anything that needs to ask what is being shown
## rather than infer it from `plant_id`. Never null after `_init`.
func ghost() -> Sprite2D:
	return _ghost


## Precedence, stated in one place, because three cues over one cell is how a
## preview stops meaning anything:
##
## 1. Illegal (road, off-board, occupied, unaffordable) wins outright. Red
##    brackets and nothing else — no ring, no risk dashes, no dead-ground lock. A
##    cell that already refuses the click is not also told why the plant it
##    refuses would have been useless there.
## 2. `at_risk` (a defenceless plant beside the road) — only reachable by a
##    plant with no reach of its own.
## 3. Dead zone (reach > 0, and it covers no road) — only reachable by a plant
##    that does have reach.
## 4. Redundant coverage (reach > 0, it covers road, and every road cell it
##    covers is already inside an existing patch of the same non-stacking
##    plant) — only reachable by a plant that does have reach.
##
## 2 is mutually exclusive with 3 and 4 by construction rather than by an `elif`:
## it tests the opposite side of `reach > 0.0`, so no cell can draw 2 alongside
## either. 3 and 4 are mutually exclusive with each other the same way, on
## opposite sides of "does it cover any road at all": dead ground covers none, so
## covering_patch_count() answers 0 there and rule 3 keeps the cell to itself.
## And 1 outranks all three in one place: `placeable` is a term in every one of
## shows_dead_zone(), shows_redundant_patch_coverage() and the `at_risk` branch below,
## so a refusal is never annotated with a critique.
##
## There is deliberately no fifth state for "a husk will take this click". It
## cannot happen — see husk_click_budget() for the 32 - 28 = 4 px that says so,
## and for how much of that allowance a road or a sweep radius costs — and it is
## the one thing here that would be *transient*: the three states above are facts
## about the board and the plant, stable until something is planted, while a husk
## rots on a 4.5-10 s timer and this node is only redrawn on mouse motion, on a
## plant being picked, and after a click. A cue nobody moves the mouse to refresh
## is a cue that goes on claiming something for seconds after it stopped being
## true. Game._click_at carries that rule as precedence instead.
## THE RING, THE LOCK AND THE REDUNDANT BARS ARE NODES NOW, NOT DRAW CALLS
## (plant-tower-defense-vlpg). `refresh_cue_nodes()` below carries what this
## function used to compute and paint inline -- `dead`, `redundant`, the ring's
## colour -- and a headless test calls it directly with no frame ever drawn,
## the same way board.gd's `mark_dead_ground()` is called with none. The stacking
## order this function used to guarantee with call sequence (brackets under the
## ring under the lock/bars under the dots) is now guaranteed by
## `_new_cue_line()`'s `show_behind_parent = true`: every converted cue sits
## behind this function's own draw calls, so brackets and the new-cover dots
## still land on top exactly as they did when the ring was a literal
## `draw_arc()` here.
func _draw() -> void:
	marker_color = OK_COLOR if placeable else BLOCKED_COLOR
	_draw_brackets()
	# Before the coverage ring, so a plant with both never has the warning
	# painted over. Only on a cell you could actually use — warning about a
	# cell that already refuses the click is noise on top of noise.
	if at_risk and placeable:
		_draw_risk_ring()
	refresh_cue_nodes()
	# No ring on a blocked cell: a coverage circle centred somewhere the plant
	# cannot go is an answer to a question the player is not asking.
	if reach <= 0.0 or not placeable:
		return
	# Last, so the dots sit over the ring rather than under it. Skipped on dead
	# ground for the same reason the risk ring is: there is nothing new to cover
	# there and a second mark on a cell already carrying a warning is noise.
	if not shows_dead_zone():
		_draw_new_cover_dots()


## Recomputes the three cues that used to be painted inline above -- the reach
## ring, the dead-ground lock and the redundant-coverage bars -- as real Line2D
## state instead of `draw_*()` calls. Called from `_draw()` so the live game
## still updates on every real frame (`_draw()` only ever runs when one is
## painted), and public so a test can call it directly on a fresh preview with
## `reach`/`placeable`/`covered_now`/etc. set by hand and no frame drawn at all
## -- see test_the_reach_ring_is_a_real_line2d_carrying_the_radius and its two
## siblings for the lock and the bars.
##
## Hides all three and returns early on the same guard `_draw()` used to return
## on: a blocked cell or a plant with no reach gets no ring, no lock and no
## bars, because a coverage cue centred somewhere the plant cannot go is an
## answer to a question the player is not asking.
func refresh_cue_nodes() -> void:
	if reach <= 0.0 or not placeable:
		_hide_cue_nodes()
		return
	var dead: bool = shows_dead_zone()
	var redundant: bool = shows_redundant_patch_coverage()
	var base: Color = DEAD_COLOR if dead or redundant else marker_color
	_refresh_reach_ring(Color(base.r, base.g, base.b, RING_ALPHA))
	_refresh_dead_lock(dead)
	_refresh_redundant_bars(redundant)


func _hide_cue_nodes() -> void:
	if _reach_ring != null:
		_reach_ring.visible = false
	_refresh_dead_lock(false)
	_refresh_redundant_bars(false)


## The reach ring's own state: a closed Line2D loop at `reach` px, same 48
## segments `draw_arc()` used to be called with so the converted node draws the
## same silhouette the arc did. `ring_points()` is the pure half a test can hold
## against `reach` with no node at all; this is the impure half that pushes the
## answer onto the node a running game actually paints.
func _refresh_reach_ring(colour: Color) -> void:
	if _reach_ring == null:
		return
	_reach_ring.points = ring_points(reach)
	_reach_ring.width = RING_WIDTH
	_reach_ring.default_color = colour
	_reach_ring.visible = true


## The padlock's state, or hidden when the cell is not dead ground.
func _refresh_dead_lock(dead: bool) -> void:
	if _dead_lock_mark == null:
		return
	if not dead:
		_dead_lock_mark.visible = false
		return
	_dead_lock_mark.points = dead_lock_points()
	_dead_lock_mark.width = DEAD_BAR_WIDTH
	_dead_lock_mark.default_color = DEAD_COLOR
	_dead_lock_mark.visible = true


## The redundant-coverage bars' state, or hidden when the cell is not
## redundant. Two Line2D children rather than one, because a Line2D always
## connects its points in order and the equals-sign reading needs two
## disjoint strokes -- see `redundant_bar_points()` for why they are computed
## together.
func _refresh_redundant_bars(redundant: bool) -> void:
	if _redundant_bar_a == null or _redundant_bar_b == null:
		return
	if not redundant:
		_redundant_bar_a.visible = false
		_redundant_bar_b.visible = false
		return
	var bars: Array[PackedVector2Array] = redundant_bar_points()
	_redundant_bar_a.points = bars[0]
	_redundant_bar_b.points = bars[1]
	for bar: Line2D in [_redundant_bar_a, _redundant_bar_b]:
		bar.width = DEAD_BAR_WIDTH
		bar.default_color = DEAD_COLOR
		bar.visible = true


## The reach ring, for a test (or `scene-tree` on a running game) that wants
## the node itself rather than `ring_points()`'s pure answer. Never null after
## `_init`.
func reach_ring() -> Line2D:
	return _reach_ring


## The dead-ground lock, same contract as `reach_ring()`.
func dead_lock_mark() -> Line2D:
	return _dead_lock_mark


## The redundant-coverage bars, same contract as `reach_ring()`. Always both
## nodes, whether or not either is currently visible.
func redundant_bars() -> Array[Line2D]:
	return [_redundant_bar_a, _redundant_bar_b]


## A dot on every road cell inside the ring that NOTHING standing already covers
## — "this is the road this purchase newly defends" (plant-tower-defense-ivoq).
##
## WHY NOT ON THE ROAD ITSELF, which is where the bead asked for it. The road's
## permanent paint is out of channels and says so: `lane_pressure_overlay.gd`
## spends hue on DANGER, alpha on how much pressure a cell took, and orientation
## on aimed-versus-unaimed, and argues explicitly that a density or a second hue
## would cost the property the hatch was built for — that the cursor's flat wash
## still reads over an off-aim cell. This is a hover-time mark on a transient
## node, so it spends none of that.
##
## AND WHY IT IS NOT A REDUNDANCY WARNING. `shows_redundant_patch_coverage()`
## above warns that a second Sundew PATCH on the same road buys nothing, which is
## true of a field effect and of nothing else. It is FALSE of a Corn Cobbler: a
## cob engages one pest at a time, so a second cob over identical cells is worth
## real money — measured in cycle 54 (test_combat.gd, commit a00ada2) as the
## difference between a five-cob garden that reaches all 32 road cells and lets a
## pest through, and a seven-cob garden over that same road that does not. So no
## dots is not a warning
## here. It means "you are buying depth rather than reach", which on a thin
## stretch is the right purchase and on a thick one is not, and the player can
## see which because the dots show where the road is bare.
func _draw_new_cover_dots() -> void:
	var on_board: Board = _board()
	if on_board == null:
		return
	for cell: Vector2i in new_cover_cells():
		# cell_to_GLOBAL: to_local() measures from the viewport, and cell_to_world is
		# board-local, so this drew every gained-cell dot 72 px high -- the same defect
		# as the sole-cover rings had (removed in cycle 179), in the same shape, found
		# by enumerating cell_to_world's callers after a screenshot caught that one.
		draw_circle(to_local(on_board.cell_to_global(cell)), NEW_COVER_DOT, marker_color)


## The road cells this purchase would newly defend: inside the reach, and not
## already covered by anything standing.
##
## A predicate rather than logic inside `_draw()`, for the reason the rest of this
## file already follows — `shows_dead_zone()` and `covering_patch_count()` are
## both readable without a canvas. A cue that can only be checked by looking at
## pixels is a cue that gets checked once.
##
## Empty means one of two very different things and the caller must not conflate
## them: the plant covers no road at all (`shows_dead_zone()` is the predicate for
## that, and `_draw()` skips these dots entirely when it is true), or every cell it
## reaches is already covered — the "buying depth, not reach" case, which is a
## legitimate purchase and is why no mark is drawn for it.
func new_cover_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var on_board: Board = _board()
	# `placeable` for the same reason shows_dead_zone() checks it: an illegal cell
	# answers false however much road it would reach. Without this the predicate
	# happily reports newly-defended cells for a cell the click already refuses --
	# `_draw()` never gets that far, so the only thing such an answer could do is
	# mislead a reader or a test into thinking the cue fires there.
	if on_board == null or reach <= 0.0 or not placeable:
		return out
	for cell: Vector2i in covered_road_cell_list(on_board, _hovered_cell(on_board), reach):
		if not covered_now.has(cell):
			out.append(cell)
	return out


## The cell this preview is sitting on, back out of its own world position —
## Game sets `position`, not a cell, and the coverage helpers take a cell.
func _hovered_cell(on_board: Board) -> Vector2i:
	return on_board.world_to_cell(position)


## Dashes rather than a solid ring, drawn as evenly spaced arc segments — a
## second solid circle would read as a second range, which is the opposite of
## what it means. Called from _draw() before the coverage ring so a plant with
## both never has the warning hidden underneath.
func _draw_risk_ring() -> void:
	var step: float = TAU / float(RISK_DASHES * 2)
	for i: int in range(RISK_DASHES):
		var from: float = float(i) * step * 2.0
		draw_arc(Vector2.ZERO, RISK_RADIUS, from, from + step, 4, RISK_COLOR, RISK_WIDTH, true)


## THE PADLOCK IS A LINE2D NOW, NOT A `draw_polyline()` CALL HERE
## (plant-tower-defense-vlpg). `_refresh_dead_lock()` pushes `dead_lock_points()`
## -- the same points the board's ambient marks carry, per that function's own
## header -- onto `_dead_lock_mark`, at full DEAD_COLOR rather than
## BOARD_DEAD_ALPHA, which is still why the hovered one reads louder than the
## board's. This function name is kept as a comment anchor for the history above
## rather than as a symbol: nothing calls it any more.

## THE REDUNDANT BARS ARE TWO LINE2DS NOW, NOT TWO `draw_line()` CALLS HERE
## (plant-tower-defense-vlpg). `_refresh_redundant_bars()` pushes
## `redundant_bar_points()` below onto `_redundant_bar_a`/`_redundant_bar_b`.
##
## TWO PARALLEL BARS, AND THEY NO LONGER CONTRAST WITH THE DEAD MARK. This cue
## was built as "dead ground is one straight bar; redundant ground is two
## parallel bars on that same angle", so it was counted against a shape that is
## now a padlock (plant-tower-defense-uqer). The pair is unchanged and the
## argument for it is not: what makes it legible is no longer that you can count
## it against a single bar, it is that it is the only straight-stroke state left
## in a preview. That is a weaker claim than the one this cue shipped with, and
## it is written down rather than quietly inherited — the equals-sign reading
## ("the same as the patch you already have") is what is carrying it now.
##
## Pure and static, the same reason `dead_lock_points()` is: headless never
## runs `_draw()`, so a composition that lives only inside a paint call is one a
## test can assert the existence of and nothing more. Two disjoint strokes come
## back as two separate PackedVector2Arrays rather than one, because a Line2D
## always connects its own points in order and cannot draw a gap.
static func redundant_bar_points() -> Array[PackedVector2Array]:
	var along: Vector2 = dead_bar_arm()
	var across: Vector2 = along.orthogonal().normalized() * (REDUNDANT_BAR_GAP * 0.5)
	var out: Array[PackedVector2Array] = []
	out.append(PackedVector2Array([-along + across, along + across]))
	out.append(PackedVector2Array([-along - across, along - across]))
	return out


## The reach ring's own points, at `radius` px around the origin, `segments`
## evenly spaced same as `draw_arc()` was always called with (48). Pure and
## static for the reason every other converted cue's geometry function is:
## headless never runs `_draw()`, so a test holds this against `reach` with no
## node, no frame and no board at all — `_refresh_reach_ring()` is the only
## caller that pushes the answer onto a live node.
static func ring_points(radius: float, segments: int = 48) -> PackedVector2Array:
	var out := PackedVector2Array()
	if radius <= 0.0 or segments <= 0:
		return out
	for i: int in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		out.append(Vector2(cos(angle), sin(angle)) * radius)
	return out


## Will the player actually see the dead-zone mark? The precedence rule above,
## as one predicate — geometry *and* legality, where covers_road() below is only
## the geometry. An illegal cell answers false however dead it is: red brackets
## already refused the click, and a second overlapping warning on top of a
## refusal is what this cue is meant to avoid becoming.
func shows_dead_zone() -> bool:
	return placeable and reach > 0.0 and not covers_road()


## Will the player see the redundancy mark? Same shape of question as
## shows_dead_zone(), and it obeys the same rule 1: an illegal cell answers false
## however redundant the ground under it is.
##
## PATCH IS IN THE NAME BECAUSE THE ANSWER IS THE OPPOSITE FOR EVERYTHING ELSE.
## This is not a general "you already cover that road" cue and must never be
## reached for as one. It asks one question about one family of plant — patches,
## whose effect is a field on the ground and therefore does not stack. Stacking a
## Corn Cobbler over identical cells is VALUABLE, not redundant: a cob engages
## only the furthest-along pest in range (CornCobbler._furthest_along_in_range),
## so a second cob over the same road is a second gun, not a second copy of the
## same gun. Cycle 54 measured exactly that (plant-tower-defense-m9u2, commit
## a00ada2): a greedy set cover found FIVE cobs that reach all 32 road cells,
## the same road the recorded SEVEN reach — and the five-cob garden lets a pest
## through where the seven-cob garden does not. Coverage was identical; firepower
## was not. A redundancy warning painted over that purchase would be telling the
## player to buy the losing garden. See test_combat.gd's _whole_road_garden() for
## the recorded seven and why they are recorded rather than derived.
##
## So the sibling predicates say "patch" for the same reason this one now does —
## covering_patch_count() and previewing_non_stacking_patch() below are the gate
## that keeps this cue off a cob at all.
##
## The condition is not spelled out again here. It is read straight off the
## plant's own value model: the mark fires exactly when one more patch would
## multiply the crossing time of the road it covers by 1.0. If the balance ever
## changes so that a second patch is worth something, that constant moves and
## this cue stops firing on its own, rather than going on warning about a
## purchase that has become worth making.
func shows_redundant_patch_coverage() -> bool:
	if not placeable or reach <= 0.0:
		return false
	var added: float = StickySundew.added_crossing_time_multiplier(covering_patch_count())
	return is_equal_approx(added, 1.0)


## How many patches already on the board cover every road cell a patch placed on
## the hovered cell would cover.
##
## 0 whenever this hover would put dew on road that nothing is sticky on yet —
## and 0, benignly, in every case where the question does not apply: a plant that
## is not a patch, a board that cannot be resolved, and dead ground, where there
## is no covered road to be redundant about and rule 3 owns the cell.
func covering_patch_count() -> int:
	if not previewing_non_stacking_patch():
		return 0
	var on_board: Board = _board()
	if on_board == null:
		return 0
	var mine: Array[Vector2i] = covered_road_cell_list(on_board,
		on_board.world_to_cell(position), reach)
	if mine.is_empty():
		return 0
	var already: Dictionary = {}
	var sharing: int = 0
	for patch: StickySundew in _existing_patches():
		var theirs: Array[Vector2i] = covered_road_cell_list(on_board,
			on_board.world_to_cell(patch.position), StickySundew.SAP_RADIUS)
		var shares: bool = false
		for road: Vector2i in theirs:
			already[road] = true
			if mine.has(road):
				shares = true
		if shares:
			sharing += 1
	for road: Vector2i in mine:
		if not already.has(road):
			# One cell of new road is enough. The second patch is then buying a
			# stretch of lane the first never touched, which is the whole
			# legitimate use of a second Sundew.
			return 0
	return sharing


## Is the plant being previewed one whose effect does not stack — one where a
## second copy over the same road is worth nothing? Today the Sticky Sundew, and
## only it. See `plant_id` for why this can answer without being told.
func previewing_non_stacking_patch() -> bool:
	if plant_id != &"":
		return plant_id == PlantCatalog.SUNDEW
	return reach > 0.0 and is_equal_approx(reach, StickySundew.SAP_RADIUS)


## The patches standing on the board right now, found the same way the Board is:
## Game adds every plant as a sibling of this preview under Entities. A patch a
## hungry pest has already killed does not count — its dew comes off the board
## with it (StickySundew._on_destroyed), so a cell it used to cover is real
## ground again.
func _existing_patches() -> Array[StickySundew]:
	var out: Array[StickySundew] = []
	var parent: Node = get_parent()
	if parent == null:
		return out
	for sibling: Node in parent.get_children():
		var patch := sibling as StickySundew
		if patch != null and is_instance_valid(patch) and not patch.is_destroyed():
			out.append(patch)
	return out


## Does the plant being previewed reach any road from the cell it is hovering?
##
## True — "it is fine" — is also the answer when the board cannot be resolved or
## the plant has no reach at all. Both are cases where the question is
## unanswerable or meaningless, and a warning nobody can act on is worse than
## no warning. A Sunflower is never dead-zoned: it is not supposed to fire.
func covers_road() -> bool:
	if reach <= 0.0:
		return true
	var on_board: Board = _board()
	if on_board == null:
		return true
	return covered_road_cells(on_board, on_board.world_to_cell(position), reach) > 0


## How many road cells a plant of `reach_px` standing on `cell` can touch.
##
## Measured centre to centre, and that is the definition rather than an
## approximation of one: Board.route() is literally one waypoint per road cell
## centre, so a road cell whose centre is inside the circle is a road cell the
## pest walking it is inside the circle at. Static, because the number is a
## property of the board and the reach and needs no live preview node — which is
## what lets the tests pin it across the whole grid.
static func covered_road_cells(on_board: Board, cell: Vector2i, reach_px: float) -> int:
	return covered_road_cell_list(on_board, cell, reach_px).size()


## Which road cells those are, rather than how many. The redundancy rule needs
## the cells themselves: "does this patch cover any road the patches already down
## do not" is a question about identity, and two patches covering three cells
## each can easily be three different cells.
static func covered_road_cell_list(on_board: Board, cell: Vector2i,
		reach_px: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if on_board == null or reach_px <= 0.0:
		return out
	# Forces the path build if the board has not had its _ready() yet — is_path()
	# on an unbuilt board answers false for every cell, which would report the
	# whole field dead rather than reporting that it could not tell.
	if on_board.path_cell_count() <= 0:
		return out
	var origin: Vector2 = on_board.cell_to_world(cell)
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var road := Vector2i(x, y)
			if not on_board.is_path(road):
				continue
			if origin.distance_to(on_board.cell_to_world(road)) <= reach_px:
				out.append(road)
	return out


## How much clearance there is between a husk and ground a plant may stand on —
## the measurement behind this class saying nothing at all about husks.
##
## A husk claims a 56 px-wide sweep target (CompostMeter.COLLECT_RADIUS is 28) on
## a 64 px cell, which reads like a click a preview ought to warn about. It is
## not, and the reason is geometry rather than luck: pests only ever walk
## Board.route(), which is one point per road cell centre, so a husk's centre is
## always at least CELL / 2 = 32 px from the nearest buildable cell — four clear
## of the sweep. No click that sweeps a husk can land on ground a plant could have
## gone into, so the green brackets never lie about one, and Game._click_at can
## put placement first without ever making a husk hard to reach.
##
## Returned as a float rather than a bool because the number is the interesting
## part: it is 4.0 today, and a wider COLLECT_RADIUS, a pest that gets knocked off
## the lane, or a road drawn along the board edge all eat into it. At <= 0.0 the
## conflict becomes real and this class needs a husk state after all.
##
## A subtraction, and only the difference comes back here. The two terms it is a
## difference OF are in husk_click_budget() — read that one when the question is
## "how much of this budget am I about to spend", which is the question a designer
## moving PATH_CORNERS or COLLECT_RADIUS is actually asking.
##
## 0.0 is also what an unmeasurable board answers, which is deliberately the value
## that fails the gate rather than a value that passes it. husk_click_budget()
## tells the two apart with a `measured` flag; this signature cannot.
static func husk_click_margin(on_board: Board) -> float:
	var clearance: float = lane_to_buildable_distance(on_board)
	if clearance < 0.0:
		return 0.0
	return clearance - CompostMeter.COLLECT_RADIUS


## The first term of that subtraction: how close the pests' lane — and so the
## husk of anything that dies on it — ever gets to a cell a plant may stand on.
## 32.0 today, which is CELL / 2, because route() is one point per road cell
## centre and a road cell centre is half a cell from the road cell's edge.
##
## -1.0, never 0.0, when the board cannot be walked at all: a real distance of
## zero would mean the lane touches buildable ground, which is the exact defect
## this measures, so an unmeasurable board must not be able to impersonate one.
##
## Exact, not sampled: every route segment is axis-aligned, so a segment's own
## bounding box is the segment, and box-to-box distance is the true distance.
static func lane_to_buildable_distance(on_board: Board) -> float:
	if on_board == null or on_board.path_cell_count() <= 0:
		return -1.0
	var route: PackedVector2Array = on_board.route()
	if route.size() < 2:
		return -1.0
	var closest: float = INF
	for i: int in range(route.size() - 1):
		var a: Vector2 = route[i]
		var b: Vector2 = route[i + 1]
		var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y))
		var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
		for y: int in range(Board.ROWS):
			for x: int in range(Board.COLS):
				var cell := Vector2i(x, y)
				if not on_board.is_buildable(cell):
					continue
				var corner := Vector2(float(cell.x * Board.CELL), float(cell.y * Board.CELL))
				var far: Vector2 = corner + Vector2(float(Board.CELL), float(Board.CELL))
				var dx: float = maxf(maxf(lo.x - far.x, corner.x - hi.x), 0.0)
				var dy: float = maxf(maxf(lo.y - far.y, corner.y - hi.y), 0.0)
				closest = minf(closest, Vector2(dx, dy).length())
	if is_inf(closest):
		return -1.0
	return closest


## The same 4 px, shown as the subtraction it is rather than as its answer.
##
## The whole point of this function is that a bare "4.0" teaches nobody anything.
## A designer dragging PATH_CORNERS one cell nearer the board edge, or nudging
## CompostMeter.COLLECT_RADIUS up because husks feel fiddly to click, is spending
## a budget that no number anywhere told them existed — they find out when
## test_no_husk_the_game_can_drop_lands_within_a_click_of_buildable_ground goes
## red, with nothing saying that four pixels was the entire allowance. So this
## reports both terms and their difference together: 32 - 28 = 4, and the reader
## can see which of the two they just moved.
##
## `margin` is not recomputed here — it is husk_click_margin() called, so the
## readout cannot drift away from the value the gate actually asserts on. That
## costs a second walk of the lane, which is free at the once-per-devtools-call
## rate this is used at and is the cheapest possible guarantee that the number a
## designer reads and the number a test fails on are the same number.
##
## Keys: measured (bool), lane_to_buildable (float, -1.0 when unmeasured),
## collect_radius (float), margin (float), summary (String). All JSON-safe
## scalars, because this crosses the devtools bus in `board_info`.
static func husk_click_budget(on_board: Board) -> Dictionary:
	var clearance: float = lane_to_buildable_distance(on_board)
	var radius: float = CompostMeter.COLLECT_RADIUS
	var margin: float = husk_click_margin(on_board)
	if clearance < 0.0:
		return {
			"measured": false,
			"lane_to_buildable": -1.0,
			"collect_radius": radius,
			"margin": margin,
			"summary": ("husk click budget: UNMEASURED — no board, or a board with no route. "
				+ "margin reads %.1f because that is what an unmeasurable board is worth, "
				+ "not because anything was measured.") % margin,
		}
	return {
		"measured": true,
		"lane_to_buildable": clearance,
		"collect_radius": radius,
		"margin": margin,
		"summary": ("husk click budget: lane comes within %.1f px of buildable ground, "
			+ "husk sweeps at %.1f px, %.1f px clear. At 0.0 a click could sweep a husk "
			+ "while standing on plantable ground and the preview would need a husk state.")
			% [clearance, radius, margin],
	}


## The board to measure against: the one handed in, else the sibling Game put
## next to this node. Cached, and re-resolved if it is ever freed.
func _board() -> Board:
	if board != null and is_instance_valid(board):
		return board
	if _resolved_board != null and is_instance_valid(_resolved_board):
		return _resolved_board
	_resolved_board = null
	var parent: Node = get_parent()
	if parent == null:
		return null
	for sibling: Node in parent.get_children():
		var found := sibling as Board
		if found != null:
			_resolved_board = found
			break
	return _resolved_board


# =============================================================================
# BEGIN plant-tower-defense-tzz7 / plant-tower-defense-g8kc
#   tzz7: surface dead ground BEFORE the player is holding a plant
#   g8kc: mark ground no plant the player owns can use
#
# ONE CUE, NOT TWO, and the reason is a measurement rather than a preference.
#
# `covers_road()` is monotone in reach: a cell whose nearest road centre is
# further away than a long reach is further away than every shorter reach too.
# So the dead sets are strictly NESTED, and on this road they are
# (test_the_dead_sets_are_nested_so_the_two_cues_can_never_be_two_marks):
#
#   mint      64.0 px -> 36 of 94 buildable cells
#   chomp     73.6    -> 36
#   aloe      96.0    -> 30
#   nettle   112.0    -> 30
#   sundew   118.4    -> 30
#   corn     176.0    -> 11
#   dandelion192.0    ->  3
#   sunflower  0.0    ->  0   (no reach, so never dead ground -- see covers_road)
#
# g8kc's set is therefore a SUBSET of tzz7's set for every plant the player
# owns, always, by construction. Two overlapping marks on the same cell would
# not be an occasional accident here; it would be the guaranteed case. Two locks
# on one cell is a smear rather than a sentence -- and until
# plant-tower-defense-uqer it was worse, because two marks on one cell at
# DEAD_BAR_ANGLE is _draw_redundant_bars(), the cue that means "you already have
# a patch covering this". The overlap used to be a different sentence; it is now
# only illegible. The mode below is what stops either.
#
# The resolution is a MODE, not a union. The board answers one question at a
# time: with a shop entry hovered it shows dead ground for THAT plant; with
# nothing hovered it shows dead ground for the longest reach the player has
# unlocked. g8kc is not a second cue. It is this cue's resting state, and that
# is the whole reason these two beads are one change.
#
# WHY NOT A TINT, which is the word g8kc uses. OVERLAY_GRAMMAR.md's one rule
# with teeth is that a cue must be legible with its colour discarded, and a
# ground tint has no channel but colour. The mark is `_draw_dead_lock()` above --
# same glyph, same width, same slate, drawn from the same dead_lock_points().
#
# WHICH GRAMMAR ROW, and this paragraph is out of date twice over. It read the
# existing "straight line through a box = A STATE" row and said no row was added
# to the grammar. plant-tower-defense-uqer added one: the padlock is a shape
# OVERLAY_GRAMMAR.md did not have, so it is row 13 there and a row of its own in
# CueLegend's ledger. `CueLegend.ROWS` -- the six lines actually printed in the
# notebook -- is still untouched, so
# test_the_legend_names_as_many_shapes_as_the_grammar_documents is still
# unaffected. The grammar table and the printed legend are not the same list.
#
# WHAT THE RESTING STATE HONESTLY CLAIMS, because the bead's wording claims more.
# "Ground no plant in the catalogue can use" is FALSE of these cells. A Seed
# Sunflower has no reach, is never dead-zoned, and its own blurb says "plant it
# somewhere the lane doesn't need" -- the three cells dead for the whole
# catalogue's longest reach are the best Sunflower ground on the board. Mint and
# Aloe reach over PLANTS rather than over the road (PlantCatalog.reach() says so
# at both branches), so their dead-ground answer is already a known
# approximation. The set below is therefore "dead for every unlocked plant whose
# dead-ground cue can fire at all", i.e. every unlocked plant with reach > 0 --
# which is exactly the population the hover cue already speaks for, and nothing
# wider. Named accordingly.
# =============================================================================

## The ambient version of DEAD_COLOR: the same slate at a third of the alpha.
##
## Dimmer than the hover bar and deliberately the opposite way round from
## OK_COLOR's relationship to SelectionMarker. There, a hover is the quiet
## suggestion under a loud selection. Here the board-wide marks are the ambient
## statement -- up to 36 of them at once -- and the hovered cell's own bar is the
## focused one, so the ambient set has to be the quieter of the two or the board
## reads as covered in warnings.
##
## 0.40 SINCE CYCLE 152, up from 0.34, and the six hundredths are margin rather than
## volume. At the new dark slate the composited separation on grass is 0.372 x alpha:
## 0.127 at 0.34, which clears `GROUND_SEPARATION_MIN` by six thousandths and would be
## re-broken by any nudge to either constant; 0.149 at 0.40, which clears it by a
## quarter. The argument above is unchanged and still holds — 0.40 is half the hover
## bar's 0.80, so the ambient set is still the quieter of the two.
const BOARD_DEAD_ALPHA: float = 0.40


## The half-arm of the REDUNDANT bar: one endpoint of the stroke, measured from
## the cell centre. The other is its negation.
##
## It was the dead-ground bar's arm too until plant-tower-defense-uqer moved that
## cue to `dead_lock_points()`. The name is kept because `_draw_redundant_bars()`
## is still built out of it and still draws bars; what is gone is the second
## caller, so this is no longer the place the two dead cues are held together.
## `dead_lock_points()` is.
static func dead_bar_arm() -> Vector2:
	return Vector2.from_angle(DEAD_BAR_ANGLE) * PREVIEW_HALF


## The padlock, as one closed-ish polyline centred on the cell's own centre.
##
## Extracted so the board-wide mark and the hovered-cell mark are provably the
## SAME glyph rather than two glyphs that happen to agree -- `Board` gives its
## `Line2D` marks these points translated to each cell, `_draw_dead_lock()`
## draws them at the origin, and
## test_the_board_mark_and_the_hover_bar_are_one_stroke_not_two asserts the two
## point lists coincide. That test predates the lock and is the reason the shape
## could be changed in one place at all.
##
## Point order, and why it ends where it does: shackle left foot, over the crown,
## shackle right foot, top-right corner, down, along the bottom, up the left
## side, then the full top edge left-to-right. Only the top edge's right-hand
## stretch (LOCK_SHACKLE_RADIUS to LOCK_BODY_HALF_W, ~6 px) is covered twice. See
## the block at LOCK_BODY_HALF_W for why one polyline and not two nodes.
static func dead_lock_points() -> PackedVector2Array:
	var top_y: float = -LOCK_HALF_HEIGHT + LOCK_SHACKLE_RADIUS
	var base_y: float = LOCK_HALF_HEIGHT
	var w: float = LOCK_BODY_HALF_W
	var points := PackedVector2Array()
	# The shackle: a half turn from PI to TAU, so it rises over the top edge
	# rather than hanging under it (screen Y grows downward).
	for i: int in range(LOCK_ARC_SEGMENTS + 1):
		var t: float = float(i) / float(LOCK_ARC_SEGMENTS)
		var angle: float = PI + t * PI
		points.append(Vector2(cos(angle), sin(angle)) * LOCK_SHACKLE_RADIUS
			+ Vector2(0.0, top_y))
	points.append(Vector2(w, top_y))
	points.append(Vector2(w, base_y))
	points.append(Vector2(-w, base_y))
	points.append(Vector2(-w, top_y))
	points.append(Vector2(w, top_y))
	return points


## DEAD_COLOR at BOARD_DEAD_ALPHA. A function rather than a const because a
## GDScript const initialiser cannot call Color's (Color, float) constructor --
## the same limitation OK_COLOR's header spells out at length.
static func board_dead_color() -> Color:
	return Color(DEAD_COLOR, BOARD_DEAD_ALPHA)


## Every buildable cell on which a plant of `reach_px` would stand for the whole
## run and never fire once -- the hover cue's own question, asked of the whole
## board at once instead of one cell at a time.
##
## Row-major, so the order is deterministic without a sort and a test can compare
## two answers element by element.
##
## EMPTY is the answer for reach <= 0.0, and that is the same judgement
## covers_road() already makes rather than a missing case: a Sunflower is not
## supposed to fire, so no ground is dead for it. Empty is also the answer for a
## null or unbuilt board, for the reason covered_road_cell_list() gives -- an
## unbuilt board would otherwise report the entire field dead.
static func dead_ground_cells(on_board: Board, reach_px: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if on_board == null or reach_px <= 0.0:
		return out
	if on_board.path_cell_count() <= 0:
		return out
	for y: int in range(Board.ROWS):
		for x: int in range(Board.COLS):
			var cell := Vector2i(x, y)
			if not on_board.is_buildable(cell):
				continue
			if covered_road_cells(on_board, cell, reach_px) == 0:
				out.append(cell)
	return out


## Those of `ids` that have a reach at all -- the plants the dead-ground cue can
## say anything about. A Sunflower is dropped here, and that is the honest half
## of g8kc: see this block's header.
##
## An id that is not in the catalogue is dropped too, so a caller holding a stale
## unlock list gets a smaller answer rather than a wrong one.
static func reaching_ids(ids: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ids:
		if PlantCatalog.has(id) and PlantCatalog.reach(id) > 0.0:
			out.append(id)
	return out


## The longest reach among `ids`, 0.0 for an empty or reachless set.
##
## Derived from PlantCatalog rather than recorded, which is g8kc's own
## requirement: the number moves the day a longer-reach plant is added, and a
## recorded 192.0 would go on being wrong quietly.
static func longest_reach(ids: Array[StringName]) -> float:
	var best: float = 0.0
	for id: StringName in reaching_ids(ids):
		best = maxf(best, PlantCatalog.reach(id))
	return best


## g8kc's set: the cells dead for EVERY plant in `ids` that has a reach.
##
## A genuine intersection, one plant at a time, rather than the one-line
## `dead_ground_cells(board, longest_reach(ids))` that the nesting makes
## equivalent. The shortcut is the faster answer and it is also the answer that
## stops being true the moment a reach stops being a plain radius -- a cone, a
## line-of-sight check, a plant that only reaches cells of its own colour. The
## intersection is what the cue actually claims, so it is what runs; the
## shortcut's equality with it is a TEST
## (test_the_dead_sets_are_nested_so_the_two_cues_can_never_be_two_marks), which
## is where a load-bearing coincidence belongs.
static func dead_for_every_reaching_plant(on_board: Board,
		ids: Array[StringName]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var reaching: Array[StringName] = reaching_ids(ids)
	if on_board == null or reaching.is_empty():
		return out
	out = dead_ground_cells(on_board, PlantCatalog.reach(reaching[0]))
	for i: int in range(1, reaching.size()):
		var theirs: Array[Vector2i] = dead_ground_cells(on_board,
			PlantCatalog.reach(reaching[i]))
		var kept: Array[Vector2i] = []
		for cell: Vector2i in out:
			if theirs.has(cell):
				kept.append(cell)
		out = kept
		if out.is_empty():
			break
	return out


## The one set the board draws, mode selected by what the cursor is on.
##
## `hovered` is a catalogue id while the cursor is over that plant's shop entry,
## and &"" the rest of the time. With an id the board answers about that plant --
## tzz7, "what would this purchase be unable to do", asked before the purchase.
## With &"" it answers about the garden the player already owns -- g8kc.
##
## One set, so one mark per cell, so the two cues can never stack into the
## redundancy cue's two bars. That is enforced here by returning a single list
## rather than by a rule a caller has to remember.
##
## Deliberately NOT a union of the two. Hovering a plant you cannot yet afford --
## or have not unlocked, which is exactly when a shop entry gets hovered longest
## -- can name a LONGER reach than anything you own, and its dead set is then a
## proper subset of the resting one. Unioning would answer the resting question
## while the player is plainly asking the hover one, and would mark 11 cells dead
## for a Bomb Dandelion that is dead on only 3 of them.
static func board_dead_cells(on_board: Board, hovered: StringName,
		unlocked: Array[StringName]) -> Array[Vector2i]:
	if PlantCatalog.has(hovered):
		return dead_ground_cells(on_board, PlantCatalog.reach(hovered))
	return dead_for_every_reaching_plant(on_board, unlocked)

# END plant-tower-defense-tzz7 / plant-tower-defense-g8kc
# =============================================================================


