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

Two shades are extrapolated along an existing hue because the kit has no darker
member and a readable feature needed one — both are noted where used:
`#8A6D00` (corn face features), `#8C2D24` / `#7A2820` (chomp maw interior).

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
