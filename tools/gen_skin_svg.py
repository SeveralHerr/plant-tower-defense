#!/usr/bin/env python3
r"""gen_skin_svg.py - RE-DRAW every `art_src/<plant>_skin_<family>.svg` from its parent in
that family's own art style, and check that the committed ones are still what the
re-drawing produces.

A SKIN is what a plant wears when the player has bought one in the Petal shop. Skins began
life as a `modulate` tint; the version before this one made them a DRAWING, but a drawing
that was its parent's geometry byte for byte with the paint moved onto a ramp and a small
motif appended. A player who owned all three owned one plant painted three colours and
wearing three hats. The brief is now explicit, and it is the whole of this file: **a skin
is its parent RE-DRAWN, not its parent recoloured.** One family is one STYLE.

  plate     Ink botanical plate.  Fills drop out to tinted paper; every shape carries an
                                  inked rim and hatching whose DENSITY carries the value.
                                  A Victorian seed catalogue engraving.
  cutpaper  Cut paper collage.    Every shape becomes a STACK of three: a pale cut edge
                                  offset towards the light, a shadow ply offset away from
                                  it, and a saturated construction paper face over both,
                                  each layer jittered by a deterministic hand.
  sampler   Embroidery on linen.  Fills become a linen ground carrying directional stitch
                                  rows; rims become a round capped running stitch. Shapes
                                  read apart by GRAIN, not by hue.

The motif system is gone. It existed to make a recolour into more than a recolour, and
three real styles do that work; a crown bolted onto an engraving is a crown bolted onto an
engraving.

---------------------------------------------------------------------------
WHAT THE RENDERER ACTUALLY SUPPORTS, AND WHY THAT DECIDES THE DESIGN

Godot 4.7.1 rasterises SVG through ThorVG, which supports a subset of SVG nobody has
written down, and **a feature it does not support renders as NOTHING: no error, no
warning, a perfectly valid PNG.** These were probed on this machine by rendering and
LOOKING, and they are the ground rules every element below is emitted under:

  * `<pattern>` fill renders fully transparent.  A hatch has to be real geometry.
  * `clip-path` on a stroked `<line>` makes the line VANISH; the identical hatch written
    `<path d="M x1 y1 L x2 y2">` clips correctly. So **this file never emits `<line>`.**
  * paint inherited from a parent `<g>` onto generated children DID NOT RENDER. So
    **every element emitted here carries its own `fill` / `stroke` / `stroke-width`**, and
    the only thing a `<g>` is ever used for is a transform. One silently unpainted shape
    would be invisible across all seventeen parents at once.
  * `clip-path` on a filled `<rect>` / `<path>`, one `clipPath` id shared by several
    elements, and a `clipPath` whose child carries a `transform` all work. Probed again
    here before this file was written: a `clipPath` child that is a rotated `<ellipse>`,
    one that is a `<circle>`, and one that is a `<path>` under `translate(...) rotate(...)`
    all clip correctly, and `stroke-dasharray` with `stroke-linecap="round"` renders as a
    row of stitches both on a rim and on a clipped hatch line.

Everything the three styles do is built out of exactly those primitives.

---------------------------------------------------------------------------
THE ARCHITECTURE: ONE SHAPE WALKER, THREE INDEPENDENT STYLES

The previous version's core was "remap the paint", which is the right core when the output
is the input with one attribute changed. It is the wrong core here: none of these three
styles is a paint transform, and two of them emit more elements than they consume.

What is shared is the READ, not the write. `walk_parent` returns, for every drawable
element in the parent and in paint order, its tag, its geometry attributes, its RESOLVED
fill/stroke/stroke-width (inherited through every `<g>` the parent nests), its resolved
TRANSFORM CHAIN as a list of the literal transform attributes, and its exact canvas space
bounding box. That last pair is what makes the styles possible at all: the chain can be
copied verbatim into a `clipPath` child so a hatch is clipped to the shape it belongs to,
and the box bounds the hatch so the emitted geometry never leaves the shape it fills.

Each style is then an independent function over that list. They share `Emitter` (id
minting, number formatting, "put the paint on the element") and nothing else. Three
independent transforms over one shared read.

The geometry itself is not re-implemented: `svg_style_check.py` already composes affine
transforms, solves bezier extrema and does rotated ellipse extents in closed form, and it
is the tool that will be asked whether the output is centred and inside the canvas. Using
its arithmetic here means the generator and the checker cannot disagree about where a
shape is -- and it means this file can REFUSE to write a drawing that would fail them.

---------------------------------------------------------------------------
HOW EACH STYLE EARNS THE CANVAS CLAUSES IT NO LONGER GETS FOR FREE

A sport copies its parent's geometry byte for byte, and that one decision buys bilateral
centring, the 1 px margin and in canvas bounds for nothing. These skins copy geometry and
then add to it: hatch (bounded by the shape, so it adds nothing), a running stitch rim
(half a stroke wider than the parent's), and a cut paper ply (offset by over a pixel, and
jittered). None of the three clauses survives that on its own.

So they are MEASURED and CORRECTED rather than inherited. Every skin is rendered twice:

  1. rendered with no correction, then walked again with the same arithmetic
     `svg_style_check.py` uses, giving the exact stroke expanded content box;
  2. a single affine correction `p -> s*p + T` is chosen from that box so that the
     content midline lands on x = 32 EXACTLY and every side keeps MARGIN_TARGET px, and
     the drawing is rendered again with that correction baked into every element's
     transform chain, clip path children included;
  3. the result is walked a third time and the two clauses are ASSERTED. A drawing that
     still fails is a FINDING, never a file.

Baked into each element rather than wrapped in one `<g>` on purpose: a `clipPath` child is
interpreted in the user space of the element that references it, so a wrapper group would
work only if ThorVG implements that clause of the spec, and a feature that fails here
fails silently. Prepending the correction to both the hatch and its clip child needs no
such assumption.

`test_content_is_bilaterally_centred` allows 1.0 px of midline error against the RASTER's
opaque pixels, which are strictly tighter than the geometric box measured here, so a
geometric midline pinned to 32.00 is comfortably inside it.

---------------------------------------------------------------------------
WHICH GATE WOULD HAVE CAUGHT THIS, AND WHY IT DOES NOT

This is a house checker in the sense `.claude/skills/house-static-checker` means it, so it
owes that paragraph. The defect class is "a committed `_skin_*.svg` is no longer the
function of its parent and its style that it claims to be" -- a leaf hand edited, a parent
edited and its three skins left behind, or a fifty-second skin file for a family that does
not exist.

`test_sprite_style.gd` holds every sprite to STYLE.md, so a hand edited skin painted in
legal palette entries passes it: the raster gate has no idea the file was supposed to be a
function of another file. `tools/svg_style_check.py` has the same blind spot for the same
reason. `gen_sport_svg.py` reads parents and sports and would not look at a skin at all.
Nothing else in the repo compares two SVGs, so without this the re-drawing is a claim in a
docstring.

The one thing this adds over its sibling: it also fails on an EXTRA file. A stray
`art_src/foo_skin_gilt.svg` would be picked up by the gate's `_declared()` derivation,
which grants it its parent's canvas row, so "which generated files may exist" has to be
somebody's question and it is this one's. It also fails on an UNUSED palette entry: a
shade the gate carries that no drawing emits silently widens what a skin may be painted
in, because conformance is "near the segment between two palette entries".

---------------------------------------------------------------------------
WHY ElementTree HERE AND REGEX IN THE SIBLING

`gen_sport_svg.py` matches `#rrggbb` with a regex and never touches structure, because its
output is its input with tokens replaced and re-serialising through ElementTree would drop
every comment and reflow the file. That argument does not transfer: nothing here is copied
text. The parent is READ as a tree and the output is WRITTEN from scratch, so parsing is
the honest operation and there is no serialisation round trip to lose anything in.

The one rule that does transfer is the banner's: XML forbids `--` inside a comment, Godot's
SVG loader accepts a malformed one happily and `svg_style_check.py` parses with ElementTree
and refuses it. No double hyphen appears in any generated text.

---------------------------------------------------------------------------
THE PALETTES, AND WHICH GATE RULES EACH STYLE BREAKS

Each family has its own palette and the gate hands a `_skin_<family>` stem ONLY its own
family's entries, so a sampler shade in a plate sprite is still a finding. The palettes are
not ramps any more: a ramp existed to seat every chromatic shade of the widest parent, and
none of these styles maps a parent shade to a shade. `plate` uses four tones whatever it is
drawing, `sampler` four, `cutpaper` fifteen (five paper stocks, each a light face, a dark
face and a ply).

Rules broken, per style, all scoped to `_skin_` stems in `svg_style_check.py`:

  * `outline`'s HUE clause ("a rim is a darker shade of its fill's own hue") -- broken by
    `sampler` only, and deliberately: an indigo running stitch on flax linen is a rim in a
    different MEDIUM, not a darkening of the ground. `plate` does NOT break it, because its
    four tones are derived at one hue (32 degrees) by the same third channel trick the
    mutant ramps use, so ink on paper passes the clause unmodified. `cutpaper` never
    reaches it: a paper face carries no stroke at all.
  * `outline`'s GREY clause is scoped with it, for the same reason and because flax sits
    near the 0.12 saturation line where "grey" is decided.
  * `outline_width` (max 2.0) -- not broken. Every rim emitted here is under 1.5 px.
  * `black_fill` -- not broken. Every emitted element names its own fill, `none` included.
  * `flat_paint` -- NOT BROKEN AND NOT NEGOTIABLE. No gradient, no pattern, no sub 1
    opacity anywhere. Hatching is geometry.

---------------------------------------------------------------------------
fixture:   `python tools/gen_skin_svg.py --fixture`. KEPT, not written and deleted -- the
           mutations below are what you re-run after every edit to this file. Builds a
           miniature project in a temp dir (a catalogue, a plant script, a gate with
           SKIN_PALETTES, one parent SVG and its three derived skins) and asserts WHICH
           findings come back, not how many.
           Cases 1-6 are self consistency: three missing skins / a freshly written tree is
           clean / one skin hand edited, named and its siblings not / an extra skin for a
           family nobody declared / a gate block that disagrees with the palettes / no
           gate block at all is COULD NOT RUN.
           Cases 7-11 test the TRANSFORMS on a hand written input, and they are the point:
           everything in 1-6 is the fixture writing with this code and comparing with this
           code, so a re-drawing that is uniformly WRONG agrees with itself and passes all
           six. 7 asserts each style's own signature geometry is present (a clipPath and a
           hatch for plate, one cut edge AND one ply per face for cutpaper with the two
           offset in opposite directions, a dasharray rim and stitch rows for sampler). 8 asserts every emitted colour is in that family's palette and no
           other's. 9 asserts every drawable element carries its own paint and no `<line>`
           is ever emitted. 10 asserts the measured content box is centred within 0.05 px
           and keeps the margin. 11 asserts the three styles differ from each other and
           from the parent, and that a second derivation is byte identical (the jitter is
           deterministic or a bare run reports drift forever).
mutations: 8, all RED, measured 2026-08-29; baseline and restore both 0 failure(s).
           `if current == text: continue` -> `if True: continue`
                                       -> RED, 5 named failures. Cases 2 and 3 report the
                                          write that never happened rather than dying in a
                                          FileNotFoundError, which is the guard that keeps
                                          "did not apply" and "survived" apart
           `correct()` returns IDENTITY  -> RED on case 10 for cutpaper: "midline is
                                          x=32.61". Nothing in cases 1-9 moves, which is
                                          why 10 exists at all
           drop the extra-file scan      -> RED, naming "an unknown-family file was
                                          accepted"
           `gate != palette_map()` -> `==`
                                       -> RED, naming the desync case
           `hatch_lines` spacing ignores
             luminance (flat 3.0)        -> RED on case 7: the dark shape and the light
                                          shape emit the same hatch count. Density IS the
                                          value in an engraving, and a flat hatch is a
                                          drawing that passes every colour check
           `_jitter` seeded by `id()`
             instead of the shape key    -> RED on case 11, "a second derivation differs".
                                          A generator whose output moves between runs
                                          reports drift on a tree nobody edited
           drop the cutpaper cut edge
             layer                       -> RED on case 7, "0 core(s) and 4 plies under 4
                                          faces". This mutation exists because the FIRST
                                          version of that style shipped without the layer
                                          and passed every gate in the repo; what caught
                                          it was a person looking at a 64px tile on grass
                                          and being unable to name the style
           `CORE_DX, CORE_DY` made
             positive                    -> RED on case 7, "cut edge and shadow are on the
                                          same side". A doubled shadow is a valid drawing
                                          and not a piece of paper
"""

import argparse
import math
import os
import re
import sys
import xml.etree.ElementTree as ET
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# The sibling this file is a variant of. Imported, never copied: `plant_stems` is the
# derivation of WHICH seventeen stems exist (the catalogue plus every `extends Plant`
# script) and the colour helpers are one implementation of luminance/hue/saturation shared
# with the sport ramps. A second copy of any of them is a copy that will disagree with the
# original the first time either is corrected.
import gen_sport_svg as sport

# The checker that will be asked whether these drawings are centred and in canvas. Its
# affine composition, bezier extrema and rotated ellipse extents are used HERE so the two
# cannot disagree about where a shape is -- and so this file can refuse to write a drawing
# that would fail it. Imported for arithmetic only; nothing below runs its checks.
import svg_style_check as ssc

SRC_DIR = sport.SRC_DIR
GATE_SCRIPT = sport.GATE_SCRIPT

## The infix that makes a stem a skin's. Also what `Skins.SKIN_SUFFIX` spells and what
## `test_sprite_style.gd` keys `SKIN_PALETTES` off -- one spelling, three readers, so it
## is named here and asserted there rather than typed three times.
SKIN_SUFFIX = "_skin_"

## Order matters: it is the order `--palette` prints and the order the gate block is
## compared in, so a reordering is a finding rather than a silent no-op. These ids are
## the STYLE, not a colour, which is the whole point of the rename from golden/frost/ember.
FAMILIES = ("plate", "cutpaper", "sampler")

## Geometric margin the correction aims for, in px. The raster gate wants 1 px of
## transparent border; geometric bounds are stroke expanded and therefore strictly wider
## than the opaque pixel bounds it measures, so aiming a quarter pixel over gives the
## rasteriser room without visibly shrinking anything.
MARGIN_TARGET = 1.25

## What the third pass is allowed to be off by before it is a finding rather than a file.
CENTRE_EPSILON = 0.05

BANNER = (
    "  <!-- GENERATED by tools/gen_skin_svg.py from %s, family %s. Do not edit by hand:\n"
    "       run `python tools/gen_skin_svg.py` and it reports any edit the parent and the\n"
    "       %s style do not explain. This is not the parent recoloured: every shape is\n"
    "       redrawn in the style, and what survives of the parent is its geometry and the\n"
    "       VALUE of its paint. -->\n"
)


# --------------------------------------------------------------------------
# The palettes
#
# Not ramps. A ramp existed to seat every chromatic shade of the widest parent on eight
# monotone rungs; none of these styles maps a parent shade to a shade, so a ramp would be
# eight entries where four are used. Each palette below is exactly the set of tones its
# style emits, and a bare run FAILS on an entry no drawing uses -- an unused entry silently
# widens what a skin may be painted in, because conformance is "near the segment between
# any two palette entries".
# --------------------------------------------------------------------------

def _warm_anchor(hue_deg, r, b):
    """A tone at `hue_deg` in [0, 60), from its red and blue channels.

    For a warm colour the max channel is R and the min is B, so HSV hue is
    60 * (G - B) / (R - B) and G = B + (hue/60) * (R - B) puts the tone on the nose
    whatever its value. Deriving rather than typing is what keeps the plate's four tones
    within half a degree of each other, which is what lets `check_outline`'s hue clause
    pass for ink on paper with no exception at all -- the ONE gate rule this style would
    otherwise have to break, bought by four lines of arithmetic.
    """
    return (r, int(round(b + (hue_deg / 60.0) * (r - b))), b)


## The plate's own hue, named once and read twice: the tones are built from it and the
## fixture asserts every one lands within 0.6 degrees of it. A hue written into a
## construction and nowhere else is a hue nothing can check.
PLATE_HUE = 32.0

## (R, B) pairs; G is derived. Deepest first, which is the order `--palette` prints.
_PLATE = [_warm_anchor(PLATE_HUE, r, b) for r, b in
          [(42, 18), (96, 40), (200, 150), (238, 196)]]
PLATE_INK, PLATE_INK_MID, PLATE_PAPER_SHADE, PLATE_PAPER = [sport.to_hex(c) for c in _PLATE]

## Flax linen and indigo floss. Two thread values and two ground values: the sampler
## separates shapes by GRAIN, so it does not need, and must not have, a tone per material.
## The linen sits at saturation 0.165, comfortably clear of the 0.12 line at which
## `check_outline` starts calling a fill grey.
SAMPLER_THREAD = "2E4258"
SAMPLER_THREAD_MID = "5C7B99"
SAMPLER_LINEN_SHADE = "CDBF9C"
SAMPLER_LINEN = "E6DCC0"

## Five paper stocks, each a light face, a dark face and a ply. Chosen by the SOURCE
## colour's hue family so the collage keeps the parent's material reading (leaves are one
## stock, the cob another) while looking nothing like it -- the tones are matte and chalky,
## which is what construction paper is and what the kit palette is not.
##
## The bucket edges are 60/170/280 rather than the sport tool's 60/200. Moved deliberately:
## the kit's blue greys sit at hue 184, and Mint and Sundew are drawn in them precisely
## BECAUSE they are not green (art_src/mint.svg records the finding that a green plant on
## #2ECC71 grass disappears). A 200 degree edge puts them in the moss stock and undoes that
## decision three times over.
##
## Each stock is THREE tones and that is the style, not a decoration. A cut paper collage
## reads by four things: matte flat colour, a hard edge, visible LAYERING, and a shadow
## separating one piece from the piece behind it. The first draft of this family had the
## first one and half of the third -- one face over one barely offset ply -- and at 64 px
## on grass it read as "the parent, desaturated" rather than as paper. Named honestly:
## that made cutpaper and plate closer to each other than either was to the parent, which
## is the one thing three families must never be.
##
## So every piece is a stack of three, and the two extra layers are geometry rather than
## strokes:
##
##   `core`  the pale cut edge, offset UP AND LEFT and drawn first, so all that survives
##           of it is a sliver along the lit side. Real cut paper shows a lighter core
##           where the blade went through, and that sliver is the single strongest cue
##           that the shape is a physical piece rather than a filled outline.
##   `face`  the piece itself, at the parent's own position.
##   `ply`   the shadow, offset DOWN AND RIGHT and drawn between the two, so all that
##           survives of IT is a sliver along the shaded side.
##
## Drawn as three offset FILLS and never as a rim, deliberately. A pale cut edge written
## as `stroke` would be a lighter rim around a fill, which `check_outline` calls an error
## in the words "a lighter rim reads as a glow, and the kit has none" -- and it would be
## right, because a rim runs all the way round and a cut edge does not. An offset layer
## shows only on the side the light is on, which is both the correct look and a shape no
## gate has to be argued out of.
##
## The tones are saturated construction paper, not the kit's shades and not the plate's
## sepia band. That is the second half of the same finding: plate is monochrome because an
## engraving is, and cut paper is the opposite of monochrome.
##
## Each stock declares as many FACES as the corpus actually asks it for, darkest first.
## That asymmetry is measured, not designed: every red a plant is drawn in is a midtone or
## darker (the palest, #D24536, is luminance 98), every blue grey used as a FILL is light
## (#89A4A6 is 159; #758C8E appears only as a rim, and a paper face carries no rim), and
## the only achromatic plant fill in the corpus is the Chomp's white teeth. Declaring the
## faces nobody uses would be more colours the gate legalises for every sprite in the
## family, plus every blend between them and everything else -- which is what
## `unused_findings` exists to refuse, and it refused exactly three of them when they were
## here.
##
## A tenth plant drawn in a bright red is therefore a LOUD failure ("cutpaper used
## #xxxxxx, which is not in its palette") and not a silent one; the fix is a second entry
## in that stock's `faces`, here, and a re-run of `--palette`.
PAPER_STOCKS = {
    "moss":   {"ply": "244A22", "faces": ["3F7A3A", "6FB24A"], "core": "A6D585"},
    "straw":  {"ply": "7A4A0F", "faces": ["C8871F", "F0B93A"], "core": "F9DC93"},
    "brick":  {"ply": "6B1E13", "faces": ["B03A28"], "core": "E28C70"},
    "slate":  {"ply": "2C4E68", "faces": ["5A93B8"], "core": "A6CBE2"},
    "oat":    {"ply": "9A9086", "faces": ["E7DECC"], "core": "F8F4EA"},
}
## Order is the order `--palette` prints and the gate compares in.
STOCK_ORDER = ("moss", "straw", "brick", "slate", "oat")

PALETTES = {
    "plate": [PLATE_INK, PLATE_INK_MID, PLATE_PAPER_SHADE, PLATE_PAPER],
    "cutpaper": [h for s in STOCK_ORDER
                 for h in ([PAPER_STOCKS[s]["ply"]] + PAPER_STOCKS[s]["faces"]
                           + [PAPER_STOCKS[s]["core"]])],
    "sampler": [SAMPLER_THREAD, SAMPLER_THREAD_MID, SAMPLER_LINEN_SHADE, SAMPLER_LINEN],
}


def face_of(stock, rgb):
    """Which face of `stock` a source colour is cut from.

    Light stock at or above STOCK_LIGHT_FLOOR, dark below, clamped to however many faces
    this stock actually declares -- see PAPER_STOCKS for why three of the five declare one.
    """
    faces = PAPER_STOCKS[stock]["faces"]
    i = 1 if sport.luminance(rgb) >= STOCK_LIGHT_FLOOR else 0
    return faces[min(i, len(faces) - 1)]


def stock_of(rgb):
    """Which paper stock a source colour is cut from.

    Achromatic paint gets oatmeal rather than being left alone, which is the one place
    this file departs from its sibling's rule. A sport is a coat over living tissue and
    leaves the Chomp's bone teeth bone; a collage is CUT OUT OF PAPER and there is no such
    thing as a piece of it that is still the original drawing.
    """
    if sport.saturation(rgb) < sport.GREY_SATURATION:
        return "oat"
    h = sport.hue(rgb)
    if h is None:
        return "oat"
    if 60.0 <= h < 170.0:
        return "moss"
    if 170.0 <= h < 280.0:
        return "slate"
    if 20.0 <= h < 60.0:
        return "straw"
    return "brick"


# --------------------------------------------------------------------------
# The shape walker
#
# The one thing all three styles share. Everything a style needs to redraw one element of
# the parent, and nothing about how it will be redrawn.
# --------------------------------------------------------------------------

## Which attributes carry the GEOMETRY of each shape, so paint and transform can be
## dropped and re-supplied. `<line>` is deliberately absent as a target: rule one of the
## renderer facts is that a clipped `<line>` vanishes, so a source `<line>` is converted to
## a `<path>` on the way in and this file emits none.
GEOM_ATTRS = {
    "path": ("d",),
    "circle": ("cx", "cy", "r"),
    "ellipse": ("cx", "cy", "rx", "ry"),
    "rect": ("x", "y", "width", "height", "rx", "ry"),
    "polygon": ("points",),
    "polyline": ("points",),
}


class Src:
    """One drawable element of the parent, resolved."""

    __slots__ = ("index", "tag", "attrs", "chain", "mat", "fill", "stroke",
                 "stroke_w", "linecap", "linejoin", "fills_area", "box")

    def __init__(self, index, tag, attrs, chain, mat, fill, stroke, stroke_w,
                 linecap, linejoin, fills_area, box):
        self.index = index
        self.tag = tag
        self.attrs = attrs
        self.chain = chain
        self.mat = mat
        self.fill = fill
        self.stroke = stroke
        self.stroke_w = stroke_w
        self.linecap = linecap
        self.linejoin = linejoin
        self.fills_area = fills_area
        self.box = box

    def key(self):
        """A stable identity for this element, for seeding deterministic jitter.

        Its geometry and its place in the walk, never its `id()` or its position in a
        dict: a jitter seeded by anything that moves between runs makes a bare run report
        drift on a tree nobody edited, forever.
        """
        return "%d|%s|%s|%s" % (self.index, self.tag,
                                " ".join(self.chain),
                                ";".join("%s=%s" % kv for kv in sorted(self.attrs.items())))

    def span(self):
        """The larger of the shape's two canvas space dimensions, or 0."""
        if self.box.empty():
            return 0.0
        return max(self.box.x1 - self.box.x0, self.box.y1 - self.box.y0)


def _num(attrs, name, default=0.0):
    v = attrs.get(name)
    if v is None:
        return default
    nums = ssc.NUM_RE.findall(v)
    return float(nums[0]) if nums else default


def walk_parent(text, name):
    """Every drawable element of one parent SVG, in paint order, resolved.

    Resolved means: paint inherited through every `<g>` is collapsed onto the element, the
    transform CHAIN is collected as the literal attribute strings (so it can be copied into
    a `clipPath` child verbatim) alongside the composed matrix, and the exact canvas space
    bounding box is computed with `svg_style_check`'s own arithmetic.

    Raises RuntimeError on anything this tool cannot measure. That is deliberate and it is
    the difference between a generator and a guesser: a `<use>` or a `<text>` in a parent
    would be silently dropped from all three of its skins otherwise.
    """
    try:
        root = ET.fromstring(text)
    except ET.ParseError as exc:
        raise RuntimeError("%s is not well formed XML: %s" % (name, exc))
    if ssc.local_tag(root) != "svg":
        raise RuntimeError("%s root element is <%s>, not <svg>" % (name, ssc.local_tag(root)))
    w = _num(root.attrib, "width", -1.0)
    h = _num(root.attrib, "height", -1.0)
    if w <= 0 or h <= 0:
        raise RuntimeError("%s declares no canvas size" % name)
    vb = [float(n) for n in ssc.NUM_RE.findall(root.attrib.get("viewBox", ""))]
    if len(vb) == 4 and (vb[0] != 0 or vb[1] != 0 or vb[2] != w or vb[3] != h):
        raise RuntimeError("%s viewBox does not map 1:1 to its canvas" % name)

    out = []

    def walk(elem, mat, chain, style):
        tag = ssc.local_tag(elem)
        if tag in ssc.SKIP_SUBTREE_TAGS:
            return
        raw = elem.attrib.get("transform")
        try:
            mat2 = ssc.mat_mul(mat, ssc.parse_transform(raw))
        except ValueError as exc:
            raise RuntimeError("%s: %s" % (name, exc))
        chain2 = chain + ([" ".join(raw.split())] if raw else [])
        style2 = ssc.element_style(elem, style)
        if tag in GEOM_ATTRS or tag == "line":
            out.append(_make_src(len(out), tag, elem, chain2, mat2, style2, name))
            return
        if tag in ssc.CONTAINER_TAGS:
            for child in elem:
                walk(child, mat2, chain2, style2)
            return
        raise RuntimeError("%s contains <%s>, which this tool cannot redraw" % (name, tag))

    walk(root, ssc.IDENTITY, [], dict(ssc.INITIAL_STYLE))
    if not out:
        raise RuntimeError("%s has no drawable elements" % name)
    return out


def _make_src(index, tag, elem, chain, mat, style, name):
    attrs = {}
    if tag == "line":
        # Converted on the way in. A clipped `<line>` vanishes in this renderer and the
        # identical `<path>` does not, so no style downstream ever has to remember it.
        x1, y1 = _num(elem.attrib, "x1"), _num(elem.attrib, "y1")
        x2, y2 = _num(elem.attrib, "x2"), _num(elem.attrib, "y2")
        tag = "path"
        attrs["d"] = "M%s %s L%s %s" % (_n(x1), _n(y1), _n(x2), _n(y2))
    else:
        for key in GEOM_ATTRS[tag]:
            if key in elem.attrib:
                attrs[key] = " ".join(elem.attrib[key].split())

    fill_kind, fill_val = ssc.parse_paint(style.get("fill"))
    stroke_kind, stroke_val = ssc.parse_paint(style.get("stroke"))
    if fill_kind not in ("rgb", "none") or stroke_kind not in ("rgb", "none"):
        raise RuntimeError("%s: a paint this tool cannot resolve (%s / %s)"
                           % (name, style.get("fill"), style.get("stroke")))
    try:
        stroke_w = float(ssc.NUM_RE.findall(style.get("stroke-width", "1"))[0])
    except (IndexError, ValueError):
        stroke_w = 1.0

    try:
        area = ssc.shape_fill_area(tag, attrs) > 1e-6
    except ssc.UnsupportedGeometry as exc:
        raise RuntimeError("%s: %s" % (name, exc))
    try:
        box = ssc.shape_bbox(tag, attrs, mat)
    except ssc.UnsupportedGeometry as exc:
        raise RuntimeError("%s: %s" % (name, exc))

    # A shape that encloses area and names no fill anywhere up its ancestry inherits SVG's
    # initial `fill: black` and renders BLACK. `svg_style_check` keeps that case
    # distinguishable all the way down (INITIAL_STYLE deliberately omits `fill`), and so
    # does this: treating it as unfilled would DROP the shape from all three of its skins,
    # which is the silent-loss failure this whole file is written against.
    if fill_kind == "none" and style.get("fill") is None and area:
        raise RuntimeError("%s: a shape encloses area and names no fill anywhere up its "
                           "ancestry, so the parent renders it black" % name)

    return Src(index, tag, attrs, chain, mat,
               fill_val if fill_kind == "rgb" else None,
               stroke_val if stroke_kind == "rgb" else None,
               stroke_w,
               style.get("stroke-linecap", "butt"),
               style.get("stroke-linejoin", "miter"),
               area, box)


# --------------------------------------------------------------------------
# Emission
# --------------------------------------------------------------------------

def _n(v):
    """A number, short, and never `-0`.

    Rounded to three places so the output is byte stable: the jitter and the correction
    are float arithmetic, and a generator whose seventeenth decimal place moves between
    Python builds reports drift on a tree nobody edited.
    """
    if abs(v) < 5e-4:
        v = 0.0
    s = "%.3f" % v
    if "." in s:
        s = s.rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def _jitter(seed, lo, hi):
    """A deterministic value in [lo, hi] from a text seed.

    CRC32 rather than `hash()`: `hash()` of a str is salted per process, so the same tree
    would derive differently on every run. Same input, same output, forever, which is what
    a check-by-default generator requires of anything random looking.
    """
    n = zlib.crc32(seed.encode("utf-8")) & 0xFFFFFFFF
    return lo + (hi - lo) * (n / 4294967295.0)


class Emitter:
    """Somewhere for a style to put elements, and the two rules every element obeys.

    One: paint goes on the element that draws. Two: the correction transform is prepended
    to every chain, `clipPath` children included, rather than wrapped around the document
    in a `<g>` -- see HOW EACH STYLE EARNS THE CANVAS CLAUSES.
    """

    def __init__(self, correction=""):
        self.correction = correction
        self.defs = []
        self.body = []
        self.used = set()
        self._clips = {}

    # -- transforms ------------------------------------------------------
    def _transform(self, chain, prefix=()):
        parts = ([self.correction] if self.correction else []) + list(prefix) + list(chain)
        parts = [p for p in parts if p]
        return ' transform="%s"' % " ".join(parts) if parts else ""

    def _geom(self, src):
        return " ".join('%s="%s"' % (k, src.attrs[k])
                        for k in GEOM_ATTRS[src.tag] if k in src.attrs)

    # -- clips -----------------------------------------------------------
    def clip_for(self, src):
        """Mint (or reuse) a `clipPath` whose child is this shape, transform and all.

        The child carries the shape's own resolved chain, which is the fact the probe
        session cost a render to learn: a rotated clip shape clips a rotated parent
        correctly, so a hatch drawn in flat canvas space lands inside a petal that lives
        under `translate(32,32) rotate(150)`.
        """
        key = src.key()
        if key in self._clips:
            return self._clips[key]
        cid = "c%d" % (len(self._clips) + 1)
        self._clips[key] = cid
        self.defs.append('    <clipPath id="%s"><%s %s%s/></clipPath>'
                         % (cid, src.tag, self._geom(src), self._transform(src.chain)))
        return cid

    # -- elements --------------------------------------------------------
    def shape(self, src, fill=None, stroke=None, width=None, prefix=(), extra=""):
        """Re-emit one source shape with new paint. `fill`/`stroke` are hex without `#`."""
        bits = [' fill="%s"' % ("#" + fill if fill else "none")]
        if stroke:
            bits.append(' stroke="#%s"' % stroke)
            bits.append(' stroke-width="%s"' % _n(width if width is not None else 1.0))
            self.used.add(stroke)
        if fill:
            self.used.add(fill)
        self.body.append("  <%s %s%s%s%s%s/>"
                         % (src.tag, self._geom(src), "".join(bits), extra,
                            self._transform(src.chain, prefix), ""))

    def segment(self, x1, y1, x2, y2, stroke, width, clip=None, extra=""):
        """A straight stroked `<path>`, never a `<line>`. Canvas space, so the only
        transform it ever carries is the correction."""
        self.used.add(stroke)
        self.body.append(
            '  <path d="M%s %s L%s %s" fill="none" stroke="#%s" stroke-width="%s"%s%s%s/>'
            % (_n(x1), _n(y1), _n(x2), _n(y2), stroke, _n(width),
               ' clip-path="url(#%s)"' % clip if clip else "", extra,
               self._transform([])))

    def document(self, parent_name, family):
        head = ('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" '
                'viewBox="0 0 64 64">\n')
        out = [head, BANNER % (parent_name, family, family)]
        if self.defs:
            out.append("  <defs>\n" + "\n".join(self.defs) + "\n  </defs>\n")
        out.append("\n".join(self.body) + "\n")
        out.append("</svg>\n")
        return "".join(out)


# --------------------------------------------------------------------------
# Hatching
# --------------------------------------------------------------------------

## No shape gets more than this many hatch lines. A cap rather than a taste: the Chomp's
## open maw is a 38 px circle and its throat is the darkest thing in the corpus, which at
## the tightest spacing is fifty lines in one shape and several hundred in the drawing.
## The cap is well above what any real shape asks for; it exists so a future parent with a
## full tile shape cannot turn one sprite into a megabyte.
HATCH_MAX = 44


def hatch_lines(box, angle_deg, spacing, phase=0.0):
    """Parallel segments crossing `box` at `angle_deg`, clipped to `box`.

    Clipped to the SHAPE'S OWN BOX rather than drawn across the tile, which is what keeps
    the emitted geometry inside the shape it belongs to. That matters twice: the drawing
    stays measurable (`svg_style_check` measures a hatch line unclipped, because it cannot
    know what `clip-path` will do to it, so a hatch drawn tile wide would report the whole
    tile as content and fail the margin check on every sprite at once), and the file stays
    small.
    """
    if box.empty() or spacing <= 0:
        return []
    a = math.radians(angle_deg)
    ux, uy = math.cos(a), math.sin(a)
    nx, ny = -uy, ux
    corners = [(box.x0, box.y0), (box.x1, box.y0), (box.x0, box.y1), (box.x1, box.y1)]
    projections = [x * nx + y * ny for x, y in corners]
    lo, hi = min(projections), max(projections)
    start = math.ceil((lo - phase) / spacing) * spacing + phase
    out = []
    c = start
    while c <= hi and len(out) < HATCH_MAX:
        seg = _clip_to_box(c * nx, c * ny, ux, uy, box)
        if seg is not None:
            out.append(seg)
        c += spacing
    return out


def _clip_to_box(px, py, ux, uy, box):
    """The part of the line `p + t*u` inside `box`, or None. Slab method, two axes."""
    t0, t1 = -1e9, 1e9
    for p, u, lo, hi in ((px, ux, box.x0, box.x1), (py, uy, box.y0, box.y1)):
        if abs(u) < 1e-9:
            if p < lo or p > hi:
                return None
            continue
        a, b = (lo - p) / u, (hi - p) / u
        if a > b:
            a, b = b, a
        t0, t1 = max(t0, a), min(t1, b)
    if t1 - t0 <= 0.35:
        return None
    return (px + t0 * ux, py + t0 * uy, px + t1 * ux, py + t1 * uy)


# --------------------------------------------------------------------------
# Style 1: ink botanical plate
# --------------------------------------------------------------------------

## Above this source luminance a shape gets NO hatch at all: it is the highlight, and the
## paper is the highlight. This is the top of the density ramp and the reason an engraving
## does not read as a flat silhouette.
PLATE_HATCH_CEILING = 210.0
## Below this, the shape is dark enough that one direction of hatch cannot carry it and it
## is cross hatched -- the classic second pass, and the only thing in the idiom that can
## make a throat read as deeper than a maw.
PLATE_CROSS_FLOOR = 72.0
## Below this the shape's paper is the shaded stock rather than the bright one. Four tones
## and no more: value is carried by DENSITY here, and a second paper is only needed where
## even the tightest hatch runs out of range.
PLATE_SHADE_FLOOR = 70.0
## A stroke thicker than this in the parent is a BODY drawn as a stroke (the Bramble's
## canes are 4.6 px of `stroke` with `fill="none"`), not a detail line, and is redrawn as
## an inked and papered band rather than as a line.
BODY_STROKE = 2.6


def _plate_hatch_spacing(lum):
    """Hatch spacing in px from the source colour's luminance.

    THE whole engraving idiom, in one line: value is density. A near black source gets
    1.5 px spacing and a pale one 4.5, and above PLATE_HATCH_CEILING nothing. Linear
    rather than perceptual on purpose -- the quantity being matched is INK PER AREA, which
    is linear in the number of lines, and a gamma corrected version of this made the
    midtones muddy and the darks identical to each other.
    """
    return 1.5 + 3.0 * min(max(lum, 0.0), 255.0) / 255.0


def render_plate(em, srcs, stem):
    for src in srcs:
        if src.fill is not None and src.fills_area:
            lum = sport.luminance(src.fill)
            paper = PLATE_PAPER_SHADE if lum < PLATE_SHADE_FLOOR else PLATE_PAPER
            rim = 1.3 if src.span() >= 9.0 else 0.95
            em.shape(src, fill=paper, stroke=PLATE_INK, width=rim,
                     extra=' stroke-linejoin="round"')
            if lum <= PLATE_HATCH_CEILING:
                clip = em.clip_for(src)
                ink = PLATE_INK if lum < 120.0 else PLATE_INK_MID
                spacing = _plate_hatch_spacing(lum)
                for x1, y1, x2, y2 in hatch_lines(src.box, 45.0, spacing):
                    em.segment(x1, y1, x2, y2, ink, 0.62, clip=clip)
                if lum < PLATE_CROSS_FLOOR:
                    for x1, y1, x2, y2 in hatch_lines(src.box, 135.0, spacing):
                        em.segment(x1, y1, x2, y2, ink, 0.62, clip=clip)
        if src.stroke is None or src.stroke_w <= 0:
            continue
        cap = ' stroke-linecap="%s"' % src.linecap if src.linecap != "butt" else ""
        if src.fill is None and src.stroke_w >= BODY_STROKE:
            # A body drawn as a stroke. Inked under, papered over, stippled along: the
            # rim is a WIDER ink stroke beneath the paper one rather than an outline
            # around it, because there is no closed shape here to outline.
            em.shape(src, stroke=PLATE_INK, width=src.stroke_w + 1.1, extra=cap)
            em.shape(src, stroke=PLATE_PAPER, width=src.stroke_w, extra=cap)
            em.shape(src, stroke=PLATE_INK, width=max(0.6, src.stroke_w * 0.18),
                     extra=' stroke-linecap="round" stroke-dasharray="0.1 2.2"')
        elif src.fill is None:
            em.shape(src, stroke=PLATE_INK, width=min(src.stroke_w, 1.3), extra=cap)


# --------------------------------------------------------------------------
# Style 2: cut paper collage
# --------------------------------------------------------------------------

## Where the ply and the cut edge sit relative to their face, before jitter. Down and to
## the right for the shadow, up and to the left for the lit cut edge: one light source
## across the whole collage, which is what makes a pile of pieces read as a pile.
##
## These are 1.6/1.9 rather than the 1.15/1.45 they started at, and the smaller pair is
## why the first draft did not read. At 64 px a 1.15 px offset survives anti-aliasing as
## about one darker pixel on a curved edge, which is indistinguishable from the edge
## itself. The margin cost is real and it is paid by `correction_for`, not by keeping the
## offset small -- which is the whole reason the correction pass exists.
PLY_DX, PLY_DY = 1.6, 1.9
CORE_DX, CORE_DY = -0.75, -0.9
## Half ranges for the deterministic hand. The FACE is jittered too, not only the ply:
## plies alone jittering under perfectly regular faces reads as a printing misregistration,
## which is a different and much worse look than paper cut with scissors.
PLY_JITTER = 0.35
PLY_ROTATE = 3.5
FACE_JITTER = 0.25
FACE_ROTATE = 1.2
## Above this source luminance the face is cut from the light stock, below it the dark one.
STOCK_LIGHT_FLOOR = 150.0


def _cut(src, seed, shift, spin, dx=0.0, dy=0.0):
    """The transform prefix for one piece of paper: a jittered offset and a jittered turn
    about the piece's own centre, in CANVAS space.

    Prepended to the shape's chain rather than appended, so it is applied to the shape
    where the parent already put it. Appending would rotate the petal about the origin of
    whatever local frame it was drawn in, which for `translate(32,32) rotate(150)` is the
    middle of the tile and would fling it off the canvas.
    """
    cx = (src.box.x0 + src.box.x1) * 0.5
    cy = (src.box.y0 + src.box.y1) * 0.5
    ox = dx + _jitter(seed + "|x", -shift, shift)
    oy = dy + _jitter(seed + "|y", -shift, shift)
    angle = _jitter(seed + "|r", -spin, spin)
    return ["translate(%s,%s)" % (_n(ox), _n(oy)),
            "rotate(%s %s %s)" % (_n(angle), _n(cx), _n(cy))]


def render_cutpaper(em, srcs, stem):
    for src in srcs:
        seed = "%s|cutpaper|%s" % (stem, src.key())
        if src.fill is not None and src.fills_area:
            name = stock_of(src.fill)
            stock = PAPER_STOCKS[name]
            face = face_of(name, src.fill)
            # Three layers, in this order and no other: the cut edge is UNDER the face
            # and offset towards the light, the shadow is under it and offset away, and
            # the face covers the middle of both. Reordered, the face would bury one of
            # them and the piece would go back to reading as a filled outline.
            em.shape(src, fill=stock["core"],
                     prefix=_cut(src, seed + "|core", FACE_JITTER, FACE_ROTATE,
                                 CORE_DX, CORE_DY))
            em.shape(src, fill=stock["ply"],
                     prefix=_cut(src, seed + "|ply", PLY_JITTER, PLY_ROTATE, PLY_DX, PLY_DY))
            em.shape(src, fill=face,
                     prefix=_cut(src, seed + "|face", FACE_JITTER, FACE_ROTATE))
        if src.stroke is None or src.stroke_w <= 0:
            continue
        cap = ' stroke-linecap="%s"' % src.linecap if src.linecap != "butt" else ""
        if src.fill is None:
            stock = PAPER_STOCKS[stock_of(src.stroke)]
            if src.stroke_w >= BODY_STROKE:
                # A cane: a strip of paper, stacked the same three ways a face is.
                em.shape(src, stroke=stock["core"], width=src.stroke_w, extra=cap,
                         prefix=_cut(src, seed + "|score", FACE_JITTER, FACE_ROTATE,
                                     CORE_DX, CORE_DY))
                em.shape(src, stroke=stock["ply"], width=src.stroke_w, extra=cap,
                         prefix=_cut(src, seed + "|sply", PLY_JITTER, PLY_ROTATE,
                                     PLY_DX, PLY_DY))
                em.shape(src, stroke=face_of(stock_of(src.stroke), src.stroke),
                         width=src.stroke_w, extra=cap,
                         prefix=_cut(src, seed + "|sface", FACE_JITTER, FACE_ROTATE))
            else:
                # A vein or a seam. One narrow strip in the ply tone: an interior line in
                # a collage is a cut, and a cut shows the layer under it.
                em.shape(src, stroke=stock["ply"], width=src.stroke_w, extra=cap,
                         prefix=_cut(src, seed + "|line", FACE_JITTER, FACE_ROTATE))


# --------------------------------------------------------------------------
# Style 3: embroidery on linen
# --------------------------------------------------------------------------

## The running stitch: a dash pattern with round caps, which the probe session measured as
## the thing that actually renders as stitches rather than as a dotted line.
STITCH_RIM_DASH = "1.7 1.3"
STITCH_ROW_DASH = "1.5 1.15"
STITCH_RIM_WIDTH = 1.35
STITCH_ROW_WIDTH = 1.0
## Rows this far apart. Coarser than the plate's hatch because a stitch is a chunky mark
## and rows any closer read as a solid block of floss.
STITCH_SPACING = 2.3
## Below this source luminance the ground is the shaded linen and the floss is the dark
## thread; above it, bright linen and the mid thread. Two steps, because the sampler
## separates shapes by GRAIN and a per material tone would undo that.
LINEN_SHADE_FLOOR = 130.0


def _grain(index):
    """The stitch angle for the shape at `index` in the walk.

    Derived from the shape's place in the parent's paint order, which is stable across
    runs because the walk is a deterministic pre-order of the file. Two adjacent shapes
    are always 31 degrees apart, so a ring of twelve identically coloured sunflower petals
    reads as twelve pieces of needlework rather than as one gold disc -- which is the
    whole claim of this style, that shapes separate by grain and not by hue.

    31 and not 30: 180/30 is 6, so a six petal ring would give every petal the same angle
    as its opposite number. 31 is coprime with 180 and repeats after 180 shapes, which is
    more than any parent has.
    """
    return (25 + 31 * index) % 180


def render_sampler(em, srcs, stem):
    for src in srcs:
        if src.fill is not None and src.fills_area:
            lum = sport.luminance(src.fill)
            dark = lum < LINEN_SHADE_FLOOR
            linen = SAMPLER_LINEN_SHADE if dark else SAMPLER_LINEN
            floss = SAMPLER_THREAD if dark else SAMPLER_THREAD_MID
            em.shape(src, fill=linen, stroke=SAMPLER_THREAD, width=STITCH_RIM_WIDTH,
                     extra=' stroke-linecap="round" stroke-dasharray="%s"' % STITCH_RIM_DASH)
            clip = em.clip_for(src)
            for x1, y1, x2, y2 in hatch_lines(src.box, _grain(src.index), STITCH_SPACING):
                em.segment(x1, y1, x2, y2, floss, STITCH_ROW_WIDTH, clip=clip,
                           extra=' stroke-linecap="round" stroke-dasharray="%s"'
                                 % STITCH_ROW_DASH)
        if src.stroke is None or src.stroke_w <= 0:
            continue
        if src.fill is None and src.stroke_w >= BODY_STROKE:
            # A cane: couched. A solid thread under a linen band, with a running stitch
            # down the middle holding it on -- which is literally how couching works and
            # is the only way a 4.6 px band reads as needlework rather than as a bar.
            em.shape(src, stroke=SAMPLER_THREAD_MID, width=src.stroke_w + 0.9,
                     extra=' stroke-linecap="round"')
            em.shape(src, stroke=SAMPLER_LINEN, width=src.stroke_w,
                     extra=' stroke-linecap="round"')
            em.shape(src, stroke=SAMPLER_THREAD, width=max(0.9, src.stroke_w * 0.28),
                     extra=' stroke-linecap="round" stroke-dasharray="%s"' % STITCH_ROW_DASH)
        elif src.fill is None:
            em.shape(src, stroke=SAMPLER_THREAD, width=min(src.stroke_w, 1.6),
                     extra=' stroke-linecap="round" stroke-dasharray="%s"' % STITCH_ROW_DASH)


STYLES = {
    "plate": render_plate,
    "cutpaper": render_cutpaper,
    "sampler": render_sampler,
}


# --------------------------------------------------------------------------
# Measuring what was drawn, and correcting it
# --------------------------------------------------------------------------

def content_box(text, name):
    """The stroke expanded content box of a generated document.

    Walks the output with the SAME arithmetic `svg_style_check.check_sprite` uses on it,
    including the half-stroke growth, so the number here and the number the checker
    reports are the same number. A hatch line is measured UNCLIPPED, exactly as the checker
    measures it, which is why `hatch_lines` bounds itself to the shape's own box.
    """
    box = ssc.Box()
    for src in walk_parent(text, name):
        if src.fill is None and src.stroke is None:
            continue
        b = src.box.copy()
        if b.empty():
            continue
        if src.stroke is not None and src.stroke_w > 0:
            b.grow(src.stroke_w * ssc.mat_scale(src.mat) * 0.5)
        box.union(b)
    return box


def correction_for(box):
    """The affine `p -> s*p + T` that centres this box and gives it its margin.

    Scale first, about the canvas centre, and only when the drawing genuinely does not
    fit; then translate in x to pin the midline to exactly 32, and in y only as far as the
    margin demands. Vertical position is left alone otherwise, deliberately: the plants'
    painted BASES are a measured family (test_placement.gd's stem pivot check reads them
    off the PNGs), and a style that recentred every skin vertically would move its own
    plant's soil line for no reason anyone asked for.
    """
    if box.empty():
        return "", 1.0
    w, h = box.x1 - box.x0, box.y1 - box.y0
    room = 64.0 - 2.0 * MARGIN_TARGET
    s = min(1.0, room / max(w, h, 1e-6))
    tx = 32.0 - s * (box.x0 + box.x1) * 0.5
    ty = 32.0 - s * 32.0
    if s * box.y0 + ty < MARGIN_TARGET:
        ty = MARGIN_TARGET - s * box.y0
    if s * box.y1 + ty > 64.0 - MARGIN_TARGET:
        ty = 64.0 - MARGIN_TARGET - s * box.y1
    parts = []
    if abs(tx) > 5e-4 or abs(ty) > 5e-4:
        parts.append("translate(%s,%s)" % (_n(tx), _n(ty)))
    if abs(s - 1.0) > 5e-6:
        parts.append("scale(%s)" % ("%.6f" % s))
    return " ".join(parts), s


def derive(source_text, parent_name, family, stem):
    """The skin SVG for one parent and one family, and what it drew.

    Three passes, and the middle one is the whole reason this file can promise the canvas
    clauses at all: draw, measure, redraw corrected. See HOW EACH STYLE EARNS THE CANVAS
    CLAUSES. Returns (text, stats) or raises RuntimeError with the reason.
    """
    srcs = walk_parent(source_text, parent_name)
    render = STYLES[family]

    first = Emitter()
    render(first, srcs, stem)
    draft = first.document(parent_name, family)
    correction, _scale = correction_for(content_box(draft, parent_name))

    em = Emitter(correction)
    render(em, srcs, stem)
    text = em.document(parent_name, family)

    box = content_box(text, parent_name)
    if box.empty():
        raise RuntimeError("the %s re-drawing painted nothing" % family)
    mid = (box.x0 + box.x1) * 0.5
    if abs(mid - 32.0) > CENTRE_EPSILON:
        raise RuntimeError("the %s re-drawing is not bilaterally centred: midline x=%.2f"
                           % (family, mid))
    margin = min(box.x0, box.y0, 64.0 - box.x1, 64.0 - box.y1)
    if margin < 1.0:
        raise RuntimeError("the %s re-drawing keeps only %.2f px of margin" % (family, margin))
    unknown = sorted(em.used - set(PALETTES[family]))
    if unknown:
        raise RuntimeError("the %s re-drawing used %s, which is not in its palette"
                           % (family, ", ".join("#" + h for h in unknown)))
    return text, {"shapes": len(srcs), "elements": len(em.body), "clips": len(em.defs),
                  "used": set(em.used)}


def skin_stem(stem, family):
    return "%s%s%s" % (stem, SKIN_SUFFIX, family)


# --------------------------------------------------------------------------
# The gate's copy of the palettes
# --------------------------------------------------------------------------

SKIN_PALETTES_RE = re.compile(r"const\s+SKIN_PALETTES[^{]*\{(.*?)\n\}", re.S)
FAMILY_ROW_RE = re.compile(r'"([a-z_]+)"\s*:\s*\[([^\]]*)\]', re.S)


def gate_skin_palettes(root):
    """The SKIN_PALETTES block `test_sprite_style.gd` currently carries, as
    family -> [hex, ...] in the order it is written.

    Regex over GDScript rather than a second copy of the palettes there, for the reason
    `svg_style_check.load_gate_constants` gives for reading EXPECTED_SIZE the same way: a
    constant declared in two files is a constant that will disagree with itself. Returns
    None when the file or the block is missing, which is a `2` and not a finding -- an
    unreadable contract is not a clean one.
    """
    path = os.path.join(root, GATE_SCRIPT)
    if not os.path.isfile(path):
        return None
    m = SKIN_PALETTES_RE.search(sport.read_text(path))
    if not m:
        return None
    out = {}
    for family, body in FAMILY_ROW_RE.findall(m.group(1)):
        out[family] = [h.upper() for h in re.findall(r'"([0-9a-fA-F]{6})"', body)]
    return out


def palette_map():
    return {f: list(PALETTES[f]) for f in FAMILIES}


def palette_block():
    """The SKIN_PALETTES const block for test/unit/test_sprite_style.gd."""
    lines = ["const SKIN_PALETTES := {"]
    for family in FAMILIES:
        row = ", ".join('"%s"' % h for h in PALETTES[family])
        lines.append('\t"%s": [%s],' % (family, row))
    lines.append("}")
    return "\n".join(lines)


def describe_gate_difference(gate):
    """One line naming the first disagreement between the gate's block and the palettes."""
    want = list(FAMILIES)
    got = list(gate.keys())
    if got != want:
        return "families %s in the gate against %s here" % (got, want)
    for family in FAMILIES:
        mine = PALETTES[family]
        theirs = gate[family]
        for i in range(max(len(mine), len(theirs))):
            a = theirs[i] if i < len(theirs) else "(missing)"
            b = mine[i] if i < len(mine) else "(extra)"
            if a != b:
                return "%s entry %d: gate #%s vs palette #%s" % (family, i + 1, a, b)
    return "(none)"


# --------------------------------------------------------------------------
# The run
# --------------------------------------------------------------------------

def known_skin_files(src):
    """Every `*_skin_*.svg` actually on disk, as a set of stems."""
    out = set()
    if not os.path.isdir(src):
        return out
    for name in sorted(os.listdir(src)):
        if name.endswith(".svg") and SKIN_SUFFIX in name:
            out.add(name[:-4])
    return out


def unused_findings(used):
    """A finding per palette entry no drawing in the corpus emitted.

    The other direction of "which files may exist", and the one only this tool can ask. A
    palette entry nothing paints with is a colour the gate legalises for free -- and
    because conformance is "near the SEGMENT between any two entries", one unused entry
    legalises a whole line through the colour space for every sprite in that family.

    Deliberately NOT part of `check()`: it is a claim about the WHOLE corpus, and the
    fixture's corpus is one synthetic parent that cannot reach every branch of every
    style. `main()` runs it over the real seventeen; the fixture exercises it directly
    with a synthetic coverage map, so neither pretends to be the other.
    """
    out = []
    for family in FAMILIES:
        unused = [h for h in PALETTES[family] if h not in used.get(family, set())]
        if unused:
            out.append(
                "FINDING: SKIN_PALETTES[%s] carries %d entr%s no drawing emits: %s\n"
                "  fix: delete the entry, or find the shape that was supposed to use it.\n"
                "  waive: none -- conformance is 'near the segment between two palette\n"
                "         entries', so an unused entry widens every blend in the family."
                % (family, len(unused), "y" if len(unused) == 1 else "ies",
                   ", ".join("#" + h for h in unused)))
    return out


def check(root, write):
    """(findings, stats). Findings are strings; stats is what the denominator prints."""
    findings = []
    stats = {"stems": 0, "scripts": 0, "expected": 0, "written": 0,
             "shapes": 0, "elements": 0}
    used = {f: set() for f in FAMILIES}

    stems, scripts = sport.plant_stems(root)
    stats["stems"] = len(stems)
    stats["scripts"] = scripts

    src = os.path.join(root, SRC_DIR)
    expected = set()
    for stem in stems:
        parent = os.path.join(src, "%s.svg" % stem)
        if not os.path.isfile(parent):
            findings.append(
                "FINDING: a plant names res://assets/sprites/%s.png but %s/%s.svg does not exist\n"
                "  fix: draw the source, or stop naming a sprite that has none.\n"
                "  waive: none -- a sprite with no source cannot have a derived skin."
                % (stem, SRC_DIR, stem))
            continue
        source_text = sport.read_text(parent)
        for family in FAMILIES:
            dest_name = "%s.svg" % skin_stem(stem, family)
            expected.add(skin_stem(stem, family))
            dest = os.path.join(src, dest_name)
            try:
                text, drew = derive(source_text, "%s.svg" % stem, family, stem)
            except RuntimeError as exc:
                findings.append(
                    "FINDING: %s/%s cannot be drawn -- %s\n"
                    "  fix: the style is what is wrong, not the parent. Read the %s\n"
                    "       section of tools/gen_skin_svg.py.\n"
                    "  waive: none -- a skin that fails its own canvas clauses fails the\n"
                    "         raster gate too, several minutes later."
                    % (SRC_DIR, dest_name, exc, family))
                continue
            stats["shapes"] += drew["shapes"]
            stats["elements"] += drew["elements"]
            used[family] |= drew["used"]
            current = sport.read_text(dest) if os.path.isfile(dest) else None
            if current == text:
                continue
            if not write:
                why = ("does not exist" if current is None
                       else "differs from its parent's re-drawing")
                findings.append(
                    "FINDING: %s/%s %s\n"
                    "  fix: run `python tools/gen_skin_svg.py --write`, then re-render with\n"
                    "       `godot --headless --path . --script res://tools/render_svg.gd`.\n"
                    "  waive: none -- a skin is a function of its parent and its style,\n"
                    "         or it is not derived."
                    % (SRC_DIR, dest_name, why))
                continue
            with open(dest, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(text)
            stats["written"] += 1
    stats["expected"] = len(expected)

    # The half `gen_sport_svg.py` does not have. `_declared()` in the gate grants any
    # `<parent>_skin_<family>.svg` on disk its PARENT's canvas row, so a file nobody
    # derived would be handed a contract row it never earned. Which generated files may
    # exist has to be somebody's question; it is this one's.
    for stray in sorted(known_skin_files(src) - expected):
        findings.append(
            "FINDING: %s/%s.svg is not a skin this derivation produces\n"
            "  fix: delete it, or add its family to FAMILIES and its palette to PALETTES.\n"
            "  waive: none -- the gate derives an EXPECTED_SIZE row for any file matching\n"
            "         this pattern, so a stray one is a sprite that ships ungated."
            % (SRC_DIR, stray))

    stats["used"] = used

    gate = gate_skin_palettes(root)
    if gate != palette_map():
        findings.append(
            "FINDING: SKIN_PALETTES in %s is not this file's PALETTES -- %s\n"
            "  fix: `python tools/gen_skin_svg.py --palette`, paste the block over it.\n"
            "  waive: none -- a skin painted in a colour the gate does not carry fails\n"
            "         test_every_colour_is_kit_palette_or_a_blend_of_two, and an entry the\n"
            "         gate carries that no style emits silently widens what a skin may use."
            % (GATE_SCRIPT, describe_gate_difference(gate)))
    return findings, stats


# --------------------------------------------------------------------------
# Fixture
# --------------------------------------------------------------------------

FIXTURE_CATALOG = '''extends RefCounted
const PLANTS := [
\t{"id": &"poppy", "texture": "res://assets/sprites/poppy.png"},
]
'''

FIXTURE_PLANT = '''extends Plant
const FRAMES := ["res://assets/sprites/poppy.png"]
'''

## Every branch the three styles have, in one 64x64 tile. Four filled shapes chosen by
## LUMINANCE rather than by looking nice: #1F8A4C is 111 (plate hatches it in the deep
## ink), #C48647 is 143 (the light ink, which is the only thing that proves the two-ink
## branch exists), #7A2820 is 41 (the shaded paper AND the cross hatch), #FFEDC6 is 238
## (above the ceiling, so no hatch at all). Plus a thin stroked detail and a thick stroked
## BODY, which is the Bramble's cane case and the one every style has to special-case.
FIXTURE_PARENT = (
    '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">\n'
    '  <g transform="translate(32,32)" fill="#1F8A4C" stroke="#1F8A4C" stroke-width="2">\n'
    '    <g transform="rotate(20)"><circle cx="0" cy="-8" r="9"/></g>\n'
    '  </g>\n'
    '  <ellipse cx="22" cy="40" rx="9" ry="6" fill="#C48647" stroke="#A8723B"'
    ' stroke-width="2"/>\n'
    '  <circle cx="42" cy="40" r="6" fill="#7A2820" stroke="#8C2D24" stroke-width="1.4"/>\n'
    '  <ellipse cx="32" cy="50" rx="11" ry="5" fill="#FFEDC6" stroke="#A69B81"'
    ' stroke-width="2"/>\n'
    '  <path d="M20 55 Q 32 52 44 55" fill="none" stroke="#A8723B" stroke-width="1.4"/>\n'
    '  <path d="M14 24 Q 32 12 50 24" fill="none" stroke="#ECDCB8" stroke-width="4.6"'
    ' stroke-linecap="round"/>\n'
    '</svg>\n'
)


def _fixture_gate(block):
    return 'extends Node\n\nconst EXPECTED_SIZE := {\n\t"poppy": 64,\n}\n\n%s\n' % block


def run_fixture():
    """Build a miniature project and assert WHICH findings come back.

    Per finding, never by count: a rule that fell silent while another double-fired leaves
    the total where it was, and that is exactly the result a count cannot see.
    """
    import shutil
    import tempfile

    root = tempfile.mkdtemp(prefix="gen_skin_fixture_")
    failures = []
    try:
        os.makedirs(os.path.join(root, "game"))
        os.makedirs(os.path.join(root, SRC_DIR))
        os.makedirs(os.path.join(root, "test", "unit"))

        def write(rel, text):
            with open(os.path.join(root, rel), "w", encoding="utf-8", newline="\n") as fh:
                fh.write(text)

        write(os.path.join("game", "plant_catalog.gd"), FIXTURE_CATALOG)
        write(os.path.join("game", "poppy.gd"), FIXTURE_PLANT)
        write(os.path.join(SRC_DIR, "poppy.svg"), FIXTURE_PARENT)
        write(GATE_SCRIPT, _fixture_gate(palette_block()))

        def findings_now():
            return check(root, False)[0]

        # Case 1: nothing derived yet. Three missing files, and nothing else.
        got = findings_now()
        for family in FAMILIES:
            if not any("poppy_skin_%s.svg does not exist" % family in f for f in got):
                failures.append("missing-file case did not name poppy_skin_%s" % family)
        if len(got) != 3:
            failures.append("missing-file case: %d finding(s), wanted 3" % len(got))

        # Case 2: written, then clean.
        check(root, True)
        got = findings_now()
        if got:
            failures.append("a freshly written tree is not clean: %s" % got)

        # Case 3: one leaf hand-edited. Named, and only it.
        edited = os.path.join(root, SRC_DIR, "poppy_skin_cutpaper.svg")
        if not os.path.isfile(edited):
            # A named failure, never a traceback. "the write never happened" and "the
            # drift check is not load-bearing" are opposite results and a stack trace
            # cannot tell them apart -- see .claude/skills/house-static-checker.
            failures.append("--write produced no poppy_skin_cutpaper.svg to hand-edit")
        else:
            write(os.path.join(SRC_DIR, "poppy_skin_cutpaper.svg"),
                  sport.read_text(edited).replace('rx="9"', 'rx="8.5"'))
            got = findings_now()
            if not any("poppy_skin_cutpaper.svg differs" in f for f in got):
                failures.append("hand-edited leaf was not reported")
            if any("poppy_skin_sampler.svg" in f for f in got):
                failures.append("hand-edited leaf implicated a sibling")
            check(root, True)

        # Case 4: a file for a family that does not exist.
        write(os.path.join(SRC_DIR, "poppy_skin_gilt.svg"), FIXTURE_PARENT)
        got = findings_now()
        if not any("poppy_skin_gilt.svg is not a skin this derivation produces" in f
                   for f in got):
            failures.append("an unknown-family file was accepted")
        os.remove(os.path.join(root, SRC_DIR, "poppy_skin_gilt.svg"))

        # Case 5: the gate's block and the palettes disagree.
        write(GATE_SCRIPT, _fixture_gate(palette_block().replace(PLATE_INK, "010203")))
        got = findings_now()
        if not any("SKIN_PALETTES" in f and "plate entry 1" in f for f in got):
            failures.append("a desynced SKIN_PALETTES block was accepted")

        # Case 6: no block at all is COULD NOT RUN, not a clean tree.
        write(GATE_SCRIPT, 'extends Node\n\nconst EXPECTED_SIZE := {\n\t"poppy": 64,\n}\n')
        if gate_skin_palettes(root) is not None:
            failures.append("a gate with no SKIN_PALETTES block read as present")
        write(GATE_SCRIPT, _fixture_gate(palette_block()))

        # -------- Cases 7-11: the TRANSFORMS, on a hand-written input.
        #
        # Everything above is self-consistency -- the fixture writes with this code and
        # compares with this code -- so a re-drawing that is uniformly WRONG agrees with
        # itself and passes all six. These do not.
        drawn = {}
        for family in FAMILIES:
            try:
                drawn[family] = derive(FIXTURE_PARENT, "poppy.svg", family, "poppy")[0]
            except RuntimeError as exc:
                failures.append("%s could not draw the fixture parent: %s" % (family, exc))

        # 7: each style's own signature geometry is present, and the plate's hatch density
        # actually tracks luminance. A flat hatch passes every colour and geometry check
        # in this repo and is not an engraving.
        if "plate" in drawn:
            text = drawn["plate"]
            if "<clipPath" not in text:
                failures.append("plate emitted no clipPath, so nothing is hatched")
            dark = _fixture_hatch_count(text, PLATE_INK)
            light = _fixture_hatch_count(text, PLATE_INK_MID)
            if dark < 4:
                failures.append("plate hatched the dark shapes with %d line(s)" % dark)
            if light < 1:
                failures.append("plate hatched the midtone with %d line(s), so the two "
                                "ink branch is dead" % light)
            if PLATE_PAPER_SHADE not in text:
                failures.append("plate gave the darkest shape the bright paper")
            if _plate_hatch_spacing(40.0) >= _plate_hatch_spacing(200.0):
                failures.append("plate hatch density does not tighten as the source darkens")
        if "cutpaper" in drawn:
            text = drawn["cutpaper"]
            plies = sum(text.count('fill="#%s"' % PAPER_STOCKS[s]["ply"])
                        for s in STOCK_ORDER)
            faces = sum(text.count('fill="#%s"' % h)
                        for s in STOCK_ORDER for h in PAPER_STOCKS[s]["faces"])
            cores = sum(text.count('fill="#%s"' % PAPER_STOCKS[s]["core"])
                        for s in STOCK_ORDER)
            # Three layers per piece, not one and not two. The first draft of this style
            # drew a face over a barely-offset ply and read as the parent desaturated;
            # the cut edge is what makes it paper, and a count is the only thing that can
            # tell "the layer is there" from "the layer was quietly dropped".
            if plies < 2 or plies != faces or cores != faces:
                failures.append("cutpaper drew %d core(s) and %d ply/plies under %d face(s)"
                                % (cores, plies, faces))
            # And they have to be offset in OPPOSITE directions, or both slivers land on
            # the same side and the piece has a doubled shadow instead of a lit edge.
            if PLY_DX <= 0 or PLY_DY <= 0 or CORE_DX >= 0 or CORE_DY >= 0:
                failures.append("cutpaper's cut edge and its shadow are on the same side")
        if "sampler" in drawn:
            text = drawn["sampler"]
            if "stroke-dasharray" not in text:
                failures.append("sampler emitted no dashed stroke, so nothing is stitched")
            if text.count("clip-path") < 2:
                failures.append("sampler emitted %d stitch row(s)" % text.count("clip-path"))
            if len({_grain(i) for i in range(4)}) != 4:
                failures.append("sampler gives adjacent shapes the same grain")

        # 8: every emitted colour is in that family's palette and in no other's.
        for family, text in drawn.items():
            emitted = {h.upper() for h in re.findall(r'"#([0-9a-fA-F]{6})"', text)}
            stray = emitted - set(PALETTES[family])
            if stray:
                failures.append("%s emitted %s, which is not its own palette"
                                % (family, sorted(stray)))
            for other in FAMILIES:
                if other == family:
                    continue
                leaked = emitted & (set(PALETTES[other]) - set(PALETTES[family]))
                if leaked:
                    failures.append("%s emitted %s's %s" % (family, other, sorted(leaked)))

        # 9: the two renderer rules. Every drawable element carries its own paint, and no
        # `<line>` is ever emitted -- a clipped one vanishes, silently, in every sprite.
        for family, text in drawn.items():
            if "<line" in text:
                failures.append("%s emitted a <line>, which vanishes when clipped" % family)
            # The BODY only. A `clipPath` child legitimately carries no paint -- it is a
            # region, not a drawing -- and scanning the whole document reports every one
            # of them, which is a checker that cries wolf on correct output.
            body = text.split("</defs>")[-1]
            for m in re.finditer(r"<(path|circle|ellipse|rect|polygon|polyline)\b[^>]*>",
                                 body):
                elem = m.group(0)
                if 'fill="' not in elem:
                    failures.append("%s emitted an element with no fill of its own: %s"
                                    % (family, elem[:60]))
                    break

        # 10: the canvas clauses, measured. `derive` refuses to return a drawing that
        # fails these, so a failure here is `derive` having stopped checking.
        for family, text in drawn.items():
            box = content_box(text, "poppy.svg")
            mid = (box.x0 + box.x1) * 0.5
            if abs(mid - 32.0) > CENTRE_EPSILON:
                failures.append("%s midline is x=%.2f" % (family, mid))
            margin = min(box.x0, box.y0, 64.0 - box.x1, 64.0 - box.y1)
            if margin < 1.0:
                failures.append("%s keeps %.2f px of margin" % (family, margin))

        # 11: the three are three, and the jitter is deterministic.
        texts = list(drawn.values())
        if len(set(texts)) != len(texts):
            failures.append("two families produced the same drawing")
        for family, text in drawn.items():
            if text == FIXTURE_PARENT:
                failures.append("%s returned its parent unchanged" % family)
            again = derive(FIXTURE_PARENT, "poppy.svg", family, "poppy")[0]
            if again != text:
                failures.append("%s: a second derivation differs from the first" % family)

        # 12: the plate's four tones sit at one hue, which is what lets ink on paper pass
        # `check_outline`'s hue clause with no exception. A hue used once in a construction
        # and never read back is a constant nothing can check.
        for tone in _PLATE:
            got_hue = sport.hue(tone)
            if got_hue is None or abs(got_hue - PLATE_HUE) > 0.6:
                failures.append("plate tone #%s sits at hue %s, not %g"
                                % (sport.to_hex(tone), got_hue, PLATE_HUE))
            if sport.saturation(tone) < sport.GREY_SATURATION:
                failures.append("plate tone #%s reads as grey to the outline check"
                                % sport.to_hex(tone))

        # 13: the unused-entry rule, exercised directly rather than through the corpus.
        # It is a claim about all seventeen parents and the fixture has one, so calling it
        # with a synthetic coverage map is the only way to assert it fires AND that it
        # stays silent on full coverage -- an always-red rule is a rule that gets deleted.
        if unused_findings({f: set(PALETTES[f]) for f in FAMILIES}):
            failures.append("the unused-entry rule fired on a fully covered palette")
        partial = {f: set(PALETTES[f]) for f in FAMILIES}
        partial["sampler"] = partial["sampler"] - {SAMPLER_THREAD_MID}
        got = unused_findings(partial)
        if not any("SKIN_PALETTES[sampler]" in f and SAMPLER_THREAD_MID in f for f in got):
            failures.append("an unused sampler entry was accepted")
        if len(got) != 1:
            failures.append("unused-entry rule: %d finding(s), wanted 1" % len(got))
    finally:
        shutil.rmtree(root, ignore_errors=True)

    print("gen_skin_svg fixture: 13 case(s) over 1 synthetic parent x %d famil%s, "
          "%d failure(s)"
          % (len(FAMILIES), "y" if len(FAMILIES) == 1 else "ies", len(failures)))
    for f in failures:
        print("  FAIL: %s" % f)
    print("NOT COVERED by the fixture: it proves the RULES fire on synthetic bytes. It "
          "says nothing\n             about whether the real corpus parses, whether the "
          "three styles are\n             TELLABLE APART by a person, or whether Godot "
          "rasterises any of it --\n             a clipped hatch that this renderer "
          "refuses comes back as a valid,\n             empty PNG. Render and look.")
    return bool(failures)


def _fixture_hatch_count(text, ink):
    return len(re.findall(r'<path d="M[^"]*" fill="none" stroke="#%s"[^>]*clip-path' % ink,
                          text))


# --------------------------------------------------------------------------

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="project root (default: .)")
    # Checking is the DEFAULT and writing is the flag, which is backwards for a generator
    # and deliberate for this one: `check_all.py` discovers every tools/*.py carrying a
    # NOT COVERED line and runs it bare, in parallel, on whatever tree the agent happens
    # to have. A generator that wrote by default would silently rewrite fifty-one
    # committed files as a side effect of running the checkers.
    ap.add_argument("--write", action="store_true",
                    help="regenerate the skin SVGs (default: report drift, write nothing)")
    ap.add_argument("--palette", action="store_true",
                    help="print the SKIN_PALETTES const block and exit")
    ap.add_argument("--fixture", action="store_true",
                    help="run the synthetic fixture and exit; proves this tool can fail")
    args = ap.parse_args(argv)

    if args.palette:
        print(palette_block())
        return 0
    if args.fixture:
        return 2 if run_fixture() else 0

    root = args.root
    if not os.path.isdir(os.path.join(root, SRC_DIR)):
        print("gen_skin_svg: could not run -- no %s/" % SRC_DIR)
        return 2
    if gate_skin_palettes(root) is None:
        print("gen_skin_svg: could not run -- no SKIN_PALETTES block in %s. That block\n"
              "              is the palettes' only other reader; without it nothing is checked."
              % GATE_SCRIPT)
        return 2
    try:
        findings, stats = check(root, args.write)
    except RuntimeError as exc:
        print("gen_skin_svg: could not run -- %s" % exc)
        return 2
    # Only over the real corpus, and only once every drawing was actually produced: a run
    # that already failed to draw something would report its own missing tones as unused.
    if stats["expected"] and not findings:
        findings.extend(unused_findings(stats["used"]))

    print("gen_skin_svg: %d plant sprite stem(s) from %s and %d plant script(s) x %d "
          "style(s) = %d skin drawing(s), %d parent shape(s) read, %d element(s) drawn, "
          "%d written, %d finding(s)"
          % (stats["stems"], sport.CATALOG, stats["scripts"], len(FAMILIES),
             stats["expected"], stats["shapes"], stats["elements"],
             stats["written"], len(findings)))
    if stats["expected"] == 0:
        print("NOTE: nothing to check -- no skin drawing was derived at all. That is a\n"
              "      clean result only if this project has no plants.")
    print("NOT COVERED: this reads and writes SVG text, not rendered pixels. It measures\n"
          "             its own geometry with svg_style_check's arithmetic and refuses a\n"
          "             drawing that is off centre or out of canvas, but it cannot see\n"
          "             whether Godot's rasteriser DREW any of it -- a primitive ThorVG\n"
          "             does not support renders as nothing, silently, into a valid PNG.\n"
          "             Nor can it see whether the three styles are tellable apart by a\n"
          "             person, or whether any of them is legible against the board it\n"
          "             lands on. test_sprite_style.gd reads the PNGs and is the gate for\n"
          "             the colours; NOTHING but a person looking at the sprites answers\n"
          "             the rest. It does not compile anything; only import_check.py and\n"
          "             lint_project.gd do that, and neither is parallel-safe.")
    for f in findings:
        print(f)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
