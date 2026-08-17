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
| **Solid full ring**, plant-sized, centred on a plant | a REACH — "this is how far it acts" | `corn_cobbler.gd:149`, `dandelion.gd:377`, `dandelion.gd:381` (the bomb's blast radius), `placement_preview.gd:231` (the reach it *would* have) |
| **Dashed ring** (an arc loop, not a full circle) | a REMARK about the thing inside it | `placement_preview.gd:314` (at risk), `sole_cover_marks.gd:150` (nothing depends on this plant) |
| **Partial arc** at a fixed radius, sweeping closed | TIME REMAINING on a clock that is already running | `husk_layer.gd:69-77` (a husk's rot timer), `chomp_flower.gd:164-165` (a chew) |
| **Small solid ring**, cell-sized, centred on a ROAD CELL | a MARKED CELL — "this one, specifically" | `sole_cover_marks.gd:154` |
| **Filled dot**, cell-sized, on a road cell | a CELL YOU WOULD GAIN | `placement_preview.gd:268` |
| **Straight line through a box** | a STATE, legible with colour discarded | `placement_preview.gd:322` (dead ground), `:331-332` (redundant patch) |
| **Corner brackets** | the SUBJECT — "this is the thing being talked about" | `selection_marker.gd:100-101`, and `PlacementPreview` inherits them one size larger and dimmer, so a hover reads as a promise of selection |
| **Scattered short marks**, much smaller than a cell, not aligned to the grid | the WEATHER, a property of the whole garden | `weather_overlay.gd:97-98` (drought, flat dashes), `weather_overlay.gd:103-104` (rain, slanted streaks) |
| **Doubled line width** | ARMED — a destructive action is one click away | `SelectionMarker.WARNING_LINE_WIDTH`, `SoleCoverMarks.WARNING_RING_WIDTH` |
| **A row of small pips** inside a drawn shape | HOW MANY TIMES OVER — a magnitude the shape's own size and brightness have already saturated on | `husk_layer.gd:117-124` (a husk worth more than `CompostMeter.FULL_VALUE`) |

## Where the grammar does NOT hold, and why that is tolerable

Two solid rings are not reaches, and a reader applying the table naively would misread them:

- **`sole_cover_marks.gd:154`** draws a small solid ring on a road cell. It is a mark, not a
  radius. What disambiguates it is **size and centre**, not shape: 9 px on a cell versus
  176 px on a plant. That is a real distinction on screen and a weak one in a table, so it
  gets its own row above rather than an exception note.
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

**A cue must be legible when its colour is discarded**, and every entry above obeys it by
shape, position, or line weight. If a proposed cue can only be distinguished by hue, it is
not finished — that is the check the two-channel rule exists to force, and it is the reason
the armed state doubles a width instead of only going red.

## How this was derived

`grep -n "draw_arc(\|draw_circle(\|draw_line(\|draw_rect(" game/*.gd` returns 55 calls
across 15 files. Most are sprites drawing themselves (`sunflower.gd`, `seed_glyph.gd`,
`title_backdrop.gd`, `notebook_page.gd`) and are not cues. The cue files are
`placement_preview.gd`, `selection_marker.gd`, `sole_cover_marks.gd`,
`lane_pressure_overlay.gd`, `husk_layer.gd`, and the range rings inside the four plants.

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
