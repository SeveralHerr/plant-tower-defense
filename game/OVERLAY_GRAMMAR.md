# Drawn-overlay grammar

The cues drawn in code — not the sprites, which are `art_src/STYLE.md`'s subject. Four
of them arrived one cycle at a time between cycles 55 and 58, each with its own reasoning,
and they turned out mostly consistent. This is that grammar, **derived from the draw calls
rather than remembered**, with the places it does not hold named rather than smoothed over.

Read this before adding a fifth cue. `test_the_overlay_grammar_holds_where_it_is_mechanical`
in `test/unit/test_selftest.gd` pins the parts of it that are numbers; the rest is prose and
will rot unless someone re-derives it, so the derivation is written down below too.

## The two-channel rule comes first

**Colour is never the only signal.** This is project-wide, older than these overlays, and it
is why the armed state doubles a line width as well as changing hue: a player with the
colourblind ramp on, or a screenshot read in greyscale, still gets the message. Any new cue
must survive its colour being thrown away.

## What each shape means

| Shape | Means | Instances |
|---|---|---|
| **Solid full ring**, plant-sized, centred on a plant | a REACH — "this is how far it acts" | **one implementation**, `Plant.draw_reach_ring`, called by Corn, Chomp, Dandelion and Sundew and inherited by Mint, Nettle and Aloe; plus `dandelion.gd` (the bomb's blast radius, the one instance that keeps a fill — see that file) and `placement_preview.gd:231` (the reach it *would* have) |
| **Dashed ring** (an arc loop, not a full circle) | a REMARK about the thing inside it | `placement_preview.gd` (at risk), `pest.gd` (a pest that has been fought) |
| **Partial arc** at a fixed radius, sweeping closed | TIME REMAINING on a clock that is already running | `husk_layer.gd:113-122` (a husk's rot timer), `chomp_flower.gd:486-487` (a chew), `selection_marker.gd:206-208` (the uproot confirm window) |
| **Small solid ring**, cell-sized, centred on a ROAD CELL | a MARKED CELL — "this one, specifically" | **none.** The sole-cover road rings were the only instance and cycle 179 removed them; the row is kept because the CHANNEL is still reserved — a new cell-sized ring means "this cell" and nothing else |
| **Filled dot**, cell-sized, on a road cell | a CELL YOU WOULD GAIN | `placement_preview.gd:274` |
| **Straight line through a box** | a STATE, legible with colour discarded | `placement_preview.gd:328` (dead ground), `:337-338` (redundant patch) |
| **Corner brackets** | the SUBJECT — "this is the thing being talked about" | `selection_marker.gd:100-101`, and `PlacementPreview` inherits them one size larger and dimmer, so a hover reads as a promise of selection |
| **Scattered short marks**, much smaller than a cell, not aligned to the grid | the WEATHER, a property of the whole garden | `weather_overlay.gd:97-98` (drought, flat dashes), `weather_overlay.gd:103-104` (rain, slanted streaks) |
| **Doubled line width** | ARMED — a destructive action is one click away | `SelectionMarker.WARNING_LINE_WIDTH` |
| **A row of small pips** inside a drawn shape | HOW MANY TIMES OVER — a magnitude the shape's own size and brightness have already saturated on | `husk_layer.gd:117-124` (a husk worth more than `CompostMeter.FULL_VALUE`) |
| **Hatched stripes filling a road cell**, at one of two mirrored angles | TWO readings of the same cell at once — the ALPHA is how much pressure it took, the ANGLE is whether anything currently aims at it | `lane_pressure_overlay.gd:92-96` |

### The last row is the board-drawn one, and that is the axis it turns on

Every other row above is a mark **on a node** — centred on a plant, on a cell, on a
mouth — and it means something about that node. The hatch is painted **on the board**,
by a `Node2D` added as Board's last child, and it means something about a *place* that
may hold nothing at all. That difference buys it a channel the node-drawn cues do not
have: it fills an area rather than marking a point, so it can carry **texture and
orientation** on top of the alpha it was already spending.

It is the most sophisticated cue in the game — two independent readings on one mark —
and it was the last one written down, because "it is drawn on the board rather than on
a node" felt like a reason to leave it out of a table of node marks. That is a real
difference and a bad reason. **A grammar that omits its best example teaches less than
one that explains why that example is different.**

Why an angle and not a second colour, in one line (`lane_pressure_overlay.gd`'s header
argues it at length): `GardenTheme.DANGER` is already spent three times over and the
alpha channel is already carrying magnitude, so texture and orientation were the only
free channels left on a 64 px cell — and orientation is the one that costs no extra ink.
`mirror_x()` is a reflection, not a redraw, so both angles ink exactly the same 57% and
leave exactly the same 43% bare. The blocked-cell cursor wash still reads identically
over an aimed cell and an off-aim one, which is the property a density or a second hue
would have spent.

**And it is the one cue that teaches itself without the legend** — coverage is derived
from the plants standing now, so a player who drops a Corn Cobbler over the leaking
stretch watches the stripes under it rotate, in the prep window, with the pressure map
still on screen. Placing the plant IS the tutorial. That is why it can afford to be
untaught (see below), and it is not a licence for the next board-drawn cue to be.

## Which of these the game actually TEACHES

Six of the eleven, on the notebook's cue-legend page (`CueLegend.ROWS`, reachable from the
title screen and opened directly by the pause card). This section exists because for ten
cycles the table above was a document for developers only, and a player met a dashed ring
with nothing to check it against.

**The list is not repeated here on purpose** — a second copy would be the thing that
diverges. `CueLegend.ROWS` is the authority, and two tests hold the pair together:
`test_the_legend_names_as_many_shapes_as_the_grammar_documents` parses this very table and
fails when it grows without `NotebookScreen.OVERLAY_GRAMMAR_SHAPES` following, and
`test_every_legend_row_has_a_shape_the_legend_can_draw` derives the drawable set from the
source rather than a hand-list.

So: **adding a row to the table above will fail the suite until someone decides whether it
is taught.** That is the intended cost. The five currently untaught are untaught because a
player meets them late or rarely, not because they are less real — and the ARMED row was in
that group until cycle 95, which is the wrong place for the only cue guarding an action that
cannot be undone.

**The hatch is untaught for a different reason, and it is the only row that gets one.**
Cycle 109 priced a seventh legend row and found the page exactly full: six rows occupy
294 of the 300 px the legend has, and a seventh lands at 340 px — unbuyable by tightening
the pitch, because one row's ink alone is 50 px against the 39.3 px pitch seven rows would
need. So the page could not take the hatch even if it wanted to. What makes that tolerable
rather than a debt is the paragraph above: the hatch is the one cue that demonstrates
itself on placement. If a future cue needs a legend row, it is buying width from those
six, and this is the note saying the width is not lying around.

## Where the grammar does NOT hold, and why that is tolerable

Two solid rings were not reaches, and a reader applying the table naively would have
misread them:

- ~~**`sole_cover_marks.gd`** drew a small solid ring on a road cell. It was a mark, not a
  radius, disambiguated by **size and centre** rather than by shape: 9 px on a cell versus
  176 px on a plant.~~ **REMOVED in cycle 179** — a player read the rings as artifacts in
  the lanes rather than as a cue. The row above survives it because the argument that
  earned it was about the CHANNEL, not about that one mark.
- ~~**`chomp_flower.gd`** draws a solid ring whose radius SHRINKS as a chew completes.~~
  **RESOLVED in cycle 78**, and the resolution is the useful part. It is now a partial arc at
  a fixed 22 px sweeping closed (`chomp_flower.gd:164`), which is not an exception at all —
  it is the second instance of the *partial arc = time remaining* row above, the first being
  a husk's rot timer. The exception existed because this table was derived one cycle after
  `husk_layer.gd` had been filed under "sprites drawing themselves" and excluded from the
  derivation; once the husk's arc was counted as a cue, the Chomp had somewhere to belong.
  **An exception in a grammar is often a missing row**, and the way to tell is to ask what
  else in the game already does the thing you are about to call unique.

So one exception remains rather than two. It is listed because a fifth cue that copied
"solid ring" from it would inherit the wrong meaning.

## What is deliberately NOT in this vocabulary

**Weather marks are sized out of it rather than shaped out of it.** Every row above is
cell-sized or plant-sized and means something about ONE thing — this cell, this plant, this
mouth. Weather is about all of them at once, so its marks are a quarter of a cell at most,
scattered, and deliberately unaligned to the grid: nothing about them invites a reader to
ask which cell they belong to. `test_drought_and_rain_are_different_textures_before_they_are_different_colours`
pins the size bound, which is the part that would rot first if someone enlarged them.

## The one rule with teeth

**A cue must be legible when its colour is discarded.** If a proposed cue can only be
distinguished by hue, it is not finished — that is the check the two-channel rule exists to
force, and it is the reason the armed state doubles a width instead of only going red.

This section used to say "and every entry above obeys it by shape, position, or line weight"
and stop there. That is a claim about **all ten rows** supported by no enumeration, in a
document whose whole argument is that patterns get derived rather than remembered. Here is
the derivation, one row at a time — **the channel named is the one that survives the colour
being thrown away**:

| Shape | The channel that is not colour |
|---|---|
| Solid full ring, plant-sized | SIZE and CENTRE. Nothing else in the game draws a 176 px ring centred on a plant. |
| Dashed ring | The DASHES. A broken loop and a closed one differ in greyscale. |
| Partial arc sweeping closed | The SWEEP ANGLE, and it MOVES — a clock is the one cue whose channel is time. |
| Small solid ring, cell-sized, on a road cell | SIZE and CENTRE again, and this is the row the exceptions section already argues: 9 px on a cell versus 176 px on a plant. |
| Filled dot | FILL. A disc and an outline ring are different marks before they are different colours. |
| Straight line through a box | Its own Means column says so outright: "legible with colour discarded". |
| Corner brackets | The SHAPE. Four detached corners look like nothing else here. |
| Scattered short marks | SIZE and SCATTER, argued at length in the section below — a quarter of a cell, unaligned to the grid. |
| Doubled line width | WIDTH, and it is the only row whose channel is asserted mechanically: `SelectionMarker.WARNING_LINE_WIDTH` is pinned strictly above its base in `test_selftest.gd`. |
| A row of small pips | COUNT. Cycle 88 added pips precisely BECAUSE radius and brightness had both saturated — a magnitude that colour could no longer carry. |
| Hatched stripes at one of two mirrored angles | ORIENTATION, and it is the only row carrying TWO readings on one mark. Alpha is spent on magnitude and `GardenTheme.DANGER` is spent three times over, so the second reading had to live somewhere that was not hue — and a mirror inks the identical 57%, so discarding colour costs the angle nothing. |

**No two rows share a channel value**, which is the property that matters: the exceptions
section below names the one place where two rows share a *shape* (solid ring), and resolves
it by size and centre rather than by hue. So the rule holds for all eleven, and it holds
*without* any cue reading `RunConfig.colorblind_safe` — none of them does, deliberately.
`SelectionMarker`'s own header spells that out: the flag "exists precisely because a hue is
not a reliable carrier, so the brackets get heavier as well as redder". The flag changes the
HUD's ramps; the board's cues never needed it because they were built to survive without it.

## How this was derived

`grep -n "draw_arc(\|draw_circle(\|draw_line(\|draw_rect(" game/*.gd` returns **80 calls
across 20 files** (it said 55 across 15 when this was written).

**AND THAT GREP IS BLIND TO A CUE ON THIS PAGE.** `Board.mark_dead_ground` paints
`Line2D` children rather than calling `draw_*`, which `board.gd`'s own header explains was
deliberate: "a `_draw()` here would be a cue no gate could ever see" headlessly. So the
recipe misses precisely the mark that was built to be checkable, and a survey run from it
would report the board as drawing fewer cues than it does. **Grep `Line2D.new()` as well.** Found by plant-tower-defense-wenx while
pricing a seventh legend row; the full diff is in `game/cue_legend.gd`'s audit block.

~~Also unrecorded here: `lane_pressure_overlay.gd`'s hatch matches none of the ten shapes
above.~~ **Given its row in cycle 110**, along with the board-drawn-versus-node-drawn note
that says why it was missing. It was the last cue outside the table, and the reason it sat
outside was that the derivation's filter — the one part done by judgement rather than by
grep — asked "is this a mark on a node" when the question was "does this mark carry state".
That is the same mistake as `husk_layer.gd` below, made a second time, forty cycles later.
**Both times the filter was the wrong shape and the grep was fine.**

Most of what the grep turns up are sprites drawing themselves (`sunflower.gd`, `seed_glyph.gd`,
`title_backdrop.gd`, `notebook_page.gd`) and are not cues. The cue files are
`placement_preview.gd`, `selection_marker.gd`, `lane_pressure_overlay.gd`,
`husk_layer.gd`, and the range rings inside the four plants.

**`husk_layer.gd` was in the sprite list until cycle 78 and that was the derivation's one
real mistake.** It draws an arc whose sweep is a husk's remaining life — a mark carrying
state, which is this table's own definition of a cue — and excluding it is why the Chomp's
ring looked like a lone exception rather than the second instance of a row. The filter was
the one part of the derivation done by judgement rather than by grep, and it is the part
that was wrong.

Re-run that grep before trusting this table. It was written in cycle 68 against 55 calls, and its line numbers moved once
before the ink dried when this file's own pointers were added to three cue headers,
and a table about consistency is exactly the kind of document that stops being true without
anybody noticing — which is what `kanban-staleness-audit` exists for and what happened to
three sections of `kanban.md` over sixty-four cycles.
