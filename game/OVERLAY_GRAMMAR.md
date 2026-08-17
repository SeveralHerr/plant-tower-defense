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
| **Small solid ring**, cell-sized, centred on a ROAD CELL | a MARKED CELL — "this one, specifically" | `sole_cover_marks.gd:154` |
| **Filled dot**, cell-sized, on a road cell | a CELL YOU WOULD GAIN | `placement_preview.gd:268` |
| **Straight line through a box** | a STATE, legible with colour discarded | `placement_preview.gd:322` (dead ground), `:331-332` (redundant patch) |
| **Corner brackets** | the SUBJECT — "this is the thing being talked about" | `selection_marker.gd:100-101`, and `PlacementPreview` inherits them one size larger and dimmer, so a hover reads as a promise of selection |
| **Doubled line width** | ARMED — a destructive action is one click away | `SelectionMarker.WARNING_LINE_WIDTH`, `SoleCoverMarks.WARNING_RING_WIDTH` |

## Where the grammar does NOT hold, and why that is tolerable

Two solid rings are not reaches, and a reader applying the table naively would misread them:

- **`sole_cover_marks.gd:154`** draws a small solid ring on a road cell. It is a mark, not a
  radius. What disambiguates it is **size and centre**, not shape: 9 px on a cell versus
  176 px on a plant. That is a real distinction on screen and a weak one in a table, so it
  gets its own row above rather than an exception note.
- **`chomp_flower.gd:138`** draws a solid ring whose radius SHRINKS as a chew completes. It
  is a progress bar in ring form, and it is the only animated-radius ring in the game.

Neither is worth changing. They are listed because a fifth cue that copied "solid ring" from
either of them would inherit the wrong meaning.

## The one rule with teeth

**A cue must be legible when its colour is discarded**, and every entry above obeys it by
shape, position, or line weight. If a proposed cue can only be distinguished by hue, it is
not finished — that is the check the two-channel rule exists to force, and it is the reason
the armed state doubles a width instead of only going red.

## How this was derived

`grep -n "draw_arc(\|draw_circle(\|draw_line(\|draw_rect(" game/*.gd` returns 55 calls
across 15 files. Most are sprites drawing themselves (`sunflower.gd`, `husk_layer.gd`,
`seed_glyph.gd`, `title_backdrop.gd`, `notebook_page.gd`) and are not cues. The cue files
are `placement_preview.gd`, `selection_marker.gd`, `sole_cover_marks.gd`,
`lane_pressure_overlay.gd`, and the range rings inside the four plants.

Re-run that grep before trusting this table. It was written in cycle 68 against 55 calls, and its line numbers moved once
before the ink dried when this file's own pointers were added to three cue headers,
and a table about consistency is exactly the kind of document that stops being true without
anybody noticing — which is what `kanban-staleness-audit` exists for and what happened to
three sections of `kanban.md` over sixty-four cycles.
