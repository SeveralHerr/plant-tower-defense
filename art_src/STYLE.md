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
