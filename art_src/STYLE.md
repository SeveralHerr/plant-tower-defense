# Art style contract — Kenney "Tower Defense" (2D)

Measured from `Kenney Game Assets All-in-1 3.6.0/2D assets/Tower Defense/`,
not assumed. Every new sprite in `assets/sprites/` must satisfy this.

## Geometry

| Property | Value | How it was measured |
|---|---|---|
| Canvas | **64 x 64 px**, exactly | all 299 `PNG/Default size/*.png` are 64x64 |
| Retina | **128 x 128 px** (`@2x`) | `PNG/Retina/` mirrors it 1:1 (299 files) |
| Projection | **top-down** | tanks/planes in `Sample.png` are seen from above |
| Anchor | sprite centred in the tile; loose objects use ~40–56 px of the 64 | tile134 (palm) is 56 px across, tile131 (bush) 30 px |
| Facing | **up-screen (−Y)** for anything directional | matches the kit's planes/turrets |
| Source format | SVG (Kenney ships `Vector/towerDefense_vector.svg`) | — |
| Edges | anti-aliased, no pixel-art snapping | sampled sprite edges are AA'd |

## Shading

Kenney's kit uses **fill-only paths, `stroke="none"`** (a Flash export artifact) —
the "outline" is a separate darker filled shape. We get the identical look with a
`stroke` of the **darker shade of the shape's own fill**, so:

- outline = darker shade of the fill, **2 px** at 64x64 (1 px on small details)
- **no black, no grey outlines** — every rim is the object's own hue, darkened
- interior detail (facets, seams, veins) = the same darker shade, 1–1.5 px
- one lighter shade may be used as a flat highlight facet — never a gradient
- 3 values per material, max: `dark rim / base / light facet`

## Palette

Extracted by frequency from the kit's own PNGs. Use these verbatim.

| Role | Dark rim | Base | Light facet |
|---|---|---|---|
| Foliage green | `#1F8A4C` | `#2ECC71` | `#31D978` |
| Foliage mid | `#229C56` | `#2ABB67` | — |
| Gold / corn | `#C29A00` | `#FFCC00` | `#FFD73A` |
| Red / pest | `#AF392D` | `#E74C3C` | `#D24536` |
| Stone / carapace | `#727272` | `#939393` | `#AAAAAA` |
| Blue-grey | `#758C8E` | `#89A4A6` | `#A3C3C6` |
| Sand / paper | `#A69B81` | `#ECDCB8` | `#FFEDC6` |
| Dirt / seed | `#A8723B` | `#C48647` | `#D9944E` |
| Orange (fx) | `#C25000` | `#FF6600` | `#FF9C3C` |
| White | — | `#FFFFFF` | — |

Five shades are extrapolated along an existing hue because the kit has no member
at that value and a readable feature needed one. All five are in the gate's
`PALETTE`, so a sprite may use them; they are listed here so a sprite author
reading this page sees the same palette the build enforces.

| Extrapolated | Along | Used for |
|---|---|---|
| `#8A6D00` | Gold / corn, darker than the rim | corn face features |
| `#8C2D24` | Red / pest, darker than the rim | chomp maw interior |
| `#7A2820` | Red / pest, darker still | chomp maw interior, deepest |
| `#5E5E5E` | Stone / carapace, darker than the rim | beetle leg and seam strokes |
| `#D7C9A8` | Sand / paper, between rim and base | seed packet's torn top |

This list drifted once already: `#5E5E5E` and `#D7C9A8` were in the gate and in
two shipped sprites while this page said nothing about them, and the count said
"two" while three were named. An author reading the contract saw a 30-colour
palette that the build enforced as 32. `tools/svg_style_check.py` now cross-checks
the two and reports the difference as an advisory, so the next drift is noticed
rather than discovered.

## The mutant ramps — sports only

A sport (`PlantMutation`) wears its own drawing: `<plant>_sport.svg`, generated from the
parent by `tools/gen_sport_svg.py`. Geometry is copied byte for byte, so every measurement
above holds for a sport because it holds for its parent. **Only the paint moves**, onto one
of two ramps picked by the source colour's hue — foliage and blue-grey (60–200°) go acid
green, everything warm goes hot magenta, and achromatic paint is left alone.

These sixteen shades are legal in a `_sport` sprite and **nowhere else**. The gate scopes
them by stem (`test_sprite_style.gd`'s `_palette_rgb`), so the thirty-four hand-drawn
sprites are held to exactly the kit palette above, unwidened.

Do not hand-pick a shade from here: a sport is a function of its parent, and
`python tools/gen_sport_svg.py` fails on any edit the parent does not explain. The anchors
are derived too — each ramp's third channel is computed from the other two so all eight sit
at one hue, which is what lets the outline rule ("the rim is a darker shade of the fill's
own hue") survive a recolour that knows nothing about it.

| Ramp | 1 (deepest) | 2 | 3 | 4 | 5 | 6 | 7 | 8 (palest) |
|---|---|---|---|---|---|---|---|---|
| Toxic (78°) | `#2A3A05` | `#415A08` | `#597A0B` | `#709A0E` | `#88BA12` | `#9DD618` | `#C0EC5A` | `#E7FCB6` |
| Mutagen (310°) | `#46063B` | `#690859` | `#910C7B` | `#B91A9E` | `#DE34C2` | `#F56EDE` | `#FCB0EF` | `#FFCEF7` |

Eight rungs because the Barrier Bramble carries eight distinct warm shades in one drawing
and none of them may collapse into another. Both palest rungs stop short of white on
purpose: at saturation below 0.12 the outline check reads a fill as grey and warns that a
coloured rim is circling bare paper, which is what the first draft of rung 8 did to the
Aloe on five shapes at once.

`python tools/gen_sport_svg.py --palette` prints this list as the gate's `MUTANT_PALETTE`
block, and a bare run of that tool fails if the two disagree. This table is the third
reader and the only one a person reads, so it is checked too: `tools/svg_style_check.py`
reports any shade one carries and another does not.

## The three skin styles — bought skins only

A **skin** is what a plant wears when the player has bought one in the Petal shop, and it
is not a tint and not a recolour. `<plant>_skin_<family>.svg` is generated from the parent
by `tools/gen_skin_svg.py`, which RE-DRAWS it: the parent's geometry and the *value* of its
paint survive, and everything about how a shape is painted is the family's own.

One family is one STYLE, not one palette. A player who owns all three owns three visibly
unrelated renderings of the same plant.

| Family | Style | What it does to every shape |
|---|---|---|
| `plate` | Ink botanical plate | The fill becomes tinted paper, the shape gains an inked rim, and hatching clipped to the shape carries the value — tight where the parent's colour was dark, sparse where it was light, absent above luminance 210, cross-hatched below 72. A Victorian seed-catalogue engraving. |
| `cutpaper` | Cut paper collage | The shape becomes a stack of three: a pale cut edge offset up-left, a shadow ply offset down-right, and a saturated construction-paper face over both. Every layer is jittered by a deterministic hand so no two pieces are cut alike. |
| `sampler` | Embroidery on linen | The fill becomes a linen ground, the rim becomes a round-capped running stitch, and stitch rows clipped to the shape carry the texture. Shapes read apart by GRAIN — each shape's row angle is 31° from its neighbour's — and not by hue. |

The motif system these replaced is gone. It existed to make a recolour into more than a
recolour, and three real styles do that work.

### The canvas clauses, and how a re-drawing earns them

A sport copies its parent's geometry byte for byte, so canvas size, retina doubling,
bilateral centring and in-canvas bounds all hold for free. A skin does not: hatching,
stitch rims and paper plies all add geometry. So the generator **measures and corrects**.
Every skin is drawn once with no correction, walked with `tools/svg_style_check.py`'s own
affine/bezier arithmetic to get its exact stroke-expanded content box, and drawn again with
a single `p -> s*p + T` baked into every element (clip-path children included) that pins the
content midline to x = 32 exactly and keeps 1.25 px on every side. It is then walked a
third time and **refuses to write a drawing that still fails**. `test_content_is_bilaterally_centred`
and `test_content_stays_inside_the_canvas` re-check the raster.

### The palettes

Each family has its own, and the gate hands a `_skin_<family>` stem **only its own
family's** entries: `test_sprite_style.gd`'s `_palette_rgb` gives a `_skin_plate` stem the
plate tones and no others, so a sampler shade that leaked into a plate sprite is still a
finding. The thirty-four hand-drawn sprites stay held to exactly the kit palette above,
unwidened. A bare run of `gen_skin_svg.py` also fails on an entry **no drawing emits** —
conformance is "near the segment between two palette entries", so an unused entry legalises
a whole line through the colour space for free.

**Plate** — four tones, all derived at hue 32° by the same third-channel trick the mutant
ramps use, which is what lets the outline rule ("the rim is a darker shade of the fill's own
hue") pass for ink on paper with no exception at all.

| Ink | Light ink | Shaded paper | Paper |
|---|---|---|---|
| `#2A1F12` | `#604628` | `#C8B196` | `#EEDAC4` |

**Cut paper** — five stocks, chosen by the source colour's hue family (moss 60–170°, slate
170–280°, straw 20–60°, brick otherwise, oat for anything under saturation 0.12). Each is a
ply, one or two faces, and a cut-edge core. A stock declares as many faces as the corpus
actually asks it for: every red a plant is drawn in is a midtone or darker, every blue-grey
used as a *fill* is light, and the only achromatic plant fill is the Chomp's teeth.

| Stock | Ply | Face (dark) | Face (light) | Cut edge |
|---|---|---|---|---|
| Moss | `#244A22` | `#3F7A3A` | `#6FB24A` | `#A6D585` |
| Straw | `#7A4A0F` | `#C8871F` | `#F0B93A` | `#F9DC93` |
| Brick | `#6B1E13` | `#B03A28` | — | `#E28C70` |
| Slate | `#2C4E68` | `#5A93B8` | — | `#A6CBE2` |
| Oat | `#9A9086` | `#E7DECC` | — | `#F8F4EA` |

**Sampler** — flax linen and indigo floss. Two ground values and two thread values, and no
more: this style separates shapes by grain, so a tone per material would undo it.

| Thread | Light thread | Shaded linen | Linen |
|---|---|---|---|
| `#2E4258` | `#5C7B99` | `#CDBF9C` | `#E6DCC0` |

### Which contract rules each style breaks, and where the exception lives

Scoped to `_skin_` stems in `tools/svg_style_check.py`, so nothing here loosens the
contract the hand-drawn sprites are held to.

- **`outline`, the hue and grey clauses** — broken by `sampler` alone. An indigo running
  stitch on flax linen is a rim in a different MEDIUM, not a darkening of the ground, and
  the 167° between them is the whole read of the style. `check_outline` exempts a `_skin_`
  stem from those two clauses and from nothing else: a skin's rim is still checked for
  being darker than its fill and for not being black. `plate` does not need the exception
  (its tones are one hue by construction) and `cutpaper` never reaches it (a paper face
  carries no stroke at all).
- **`outline_width`** — not broken. Every rim any style emits is under 1.5 px.
- **`black_fill`** — not broken. Every generated element names its own fill, `none`
  included, and the generator refuses a parent shape that does not.
- **`flat_paint`** — not broken and not negotiable. No gradient, no pattern, no sub-1
  opacity anywhere; hatching and stitching are geometry. (A `<pattern>` fill would have
  been the obvious way to hatch and it renders as nothing at all in this rasteriser.)

One thing worth knowing before editing the cut-paper style: its pale cut edge is an offset
*filled layer*, never a stroke. A pale rim written as `stroke` would be a lighter outline
around a fill, which `check_outline` calls an error in the words "a lighter rim reads as a
glow" — and it would be right, because a rim runs all the way round and a cut edge only
shows on the side the light is on.

Do not hand-pick a shade from these tables, and do not edit a `_skin_*` file: a skin is a
function of its parent and its style, and `python tools/gen_skin_svg.py` fails on any edit
the two do not explain — including a fifty-second file for a family that does not exist.
`--palette` prints these as the gate's `SKIN_PALETTES` block, and `tools/svg_style_check.py`
reports any shade this page carries and the gate does not, or the reverse.

## Rendering

`art_src/*.svg` are the sources; they never ship. Godot rasterises them:

```bash
godot --headless --path . --script res://tools/render_svg.gd
```

Writes `assets/sprites/<name>.png` (64) and `assets/sprites/retina/<name>@2x.png`
(128). `art_src/` carries a `.gdignore` so Godot does not also import the SVGs as
textures and give every sprite two competing resources.

## Licence

Kit sprites in `assets/kenney/` are Kenney's, CC0 — `assets/kenney/License.txt`
travels with them. The sprites in `assets/sprites/` are ours, drawn to match.
