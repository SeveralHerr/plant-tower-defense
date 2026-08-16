#!/usr/bin/env python3
"""svg_style_check.py - hold `art_src/*.svg` to `art_src/STYLE.md` without a renderer.

Why this exists: the style contract in `art_src/STYLE.md` was measured out of the Kenney
"Tower Defense" kit, and the only thing that currently enforces it is
`test/unit/test_sprite_style.gd` -- which reads the *rendered* PNGs, so it needs
`tools/render_svg.gd` to have run, which needs Godot, which opens `.godot/`. That makes
sprite conformance the one question a fan-out agent cannot ask: `.godot/` is a
single-writer resource, so only `name_check.py` and `coverage_check.py` are safe to run
concurrently, and neither of them has ever looked at a sprite. Authoring a sprite under
those conditions means reasoning about palette conformance and anti-aliased three-hue
junctions by hand, and finding out whether you were right several minutes and one
serialised Godot run later.

Most of that contract is decidable from the SVG source. A `fill="#2ECC71"` is a palette
entry or it is not; a `stroke` is darker than the fill it outlines or it is not; a
`<circle cx cy r>` under `translate(32,32) rotate(60)` has an exact bounding box that
arithmetic can produce and a rasteriser only approximates. So this tool parses the SVGs
as XML (never with a regex) and checks what the source can answer, with no engine, no
project, no `.godot/`, and nothing outside the standard library -- the same properties
`name_check.py` has, and for the same reason: N agents can run it at once on one
checkout, and it works in a git worktree that has never been imported.

It is a *pre*-flight check, not a replacement for the gate. `test_sprite_style.gd` reads
what Godot's rasteriser actually produced; this reads what the author actually wrote.
Those disagree exactly where the interesting bugs live (see LIMITS below), so the design
rule here is that a finding this tool calls an `error` must be one the raster gate would
also fail. Everything softer is a `warning` or `advisory`.

WHERE THE CONTRACT COMES FROM
-----------------------------
Nothing about the palette or the canvas sizes is duplicated into this file. Both are
read at runtime:

  * canvas sizes  <- `EXPECTED_SIZE` in `test/unit/test_sprite_style.gd`. Sizes are
                     per-sprite, not global: everything the kit ships is 64, and
                     `corn_kernel` is deliberately 16 because it is a projectile, not a
                     tile-sized object.
  * palette       <- `PALETTE` in the same file (the authoritative list the gate
                     enforces), cross-read against `STYLE.md`'s palette table for the
                     *family* grouping (Foliage green / Gold / Red / ...), which is what
                     makes "the outline is a darker shade of the fill" decidable.

If the gate's palette gains an entry STYLE.md never documents, that is reported as an
advisory rather than silently absorbed -- the document and the gate drifting apart is
the failure this whole pair of files exists to prevent.

WHAT IT CHECKS
--------------
  canvas          declared width/height/viewBox is square, unscaled (viewBox maps 1:1 to
                  px, or a `stroke-width="2"` no longer means 2px), and equals this
                  sprite's `EXPECTED_SIZE`.
  declared        every `art_src/*.svg` has an `EXPECTED_SIZE` row and vice versa. An
                  undeclared sprite renders, ships, and is ungated.
  palette         every resolved `fill` and `stroke` -- inherited through `<g>`, read out
                  of `style=` as well as the presentation attribute -- against the kit
                  palette. Exact match is clean. Off-palette is measured with the gate's
                  own metric (shortest distance to the segment between any two palette
                  entries) so this tool and the gate cannot disagree about how far off a
                  colour is.
  flat_paint      no gradient, pattern, filter or `url(#...)` paint. STYLE.md: "never a
                  gradient". Also flags sub-1 opacity, which composites against the
                  transparent background into colours that are on no palette segment.
  outline         for every shape that has both a fill and a stroke: the stroke is darker
                  than the fill (luminance), and shares its hue. STYLE.md: "no black, no
                  grey outlines -- every rim is the object's own hue, darkened". Read
                  literally, that is a statement about HUE, so it is checked as one --
                  measured across every rim/fill pair in the corpus, the worst legitimate
                  pair differs by 0.66 degrees, and the nearest cross-material pair the
                  palette allows (Dirt rim on Gold fill) by 17.4.
  black_fill      a closed shape that never names a `fill` anywhere up its ancestry
                  inherits SVG's initial `fill: black` and renders BLACK. That is
                  invisible in a diff and forbidden outright by STYLE.md.
  outline_width   outline strokes are <= 2px. STYLE.md: "2 px at 64x64 (1 px on small
                  details)". Strokes on `fill="none"` shapes are *lines* (legs,
                  antennae, seams), not outlines, and are not capped.
  content         at least one shape actually paints something, and every path's `d`
                  parses. A malformed `d` renders as a fully transparent PNG: the texture
                  loads, the sprite node is there, the screen is empty.
  centred         the content bounding box is centred on the vertical axis, computed
                  exactly (affine transforms composed; bezier extrema solved, not
                  approximated by the control hull; rotated-ellipse extents in closed
                  form) and expanded by half the stroke width.
  margin          content stays inside the canvas.

WHAT IT DELIBERATELY DOES NOT CHECK  (LIMITS)
---------------------------------------------
  * `retina copy` -- `test_sprite_style.gd` asserts a `@2x` PNG exists at exactly double.
    Nothing in the SVG source declares that; `render_svg.gd` writes both from one source.
    Unreproducible here, by construction.
  * `blank render` -- the gate asserts the *rasterised* image is not invisible and has
    real coverage. This can only assert that the source contains drawable, painted,
    parseable geometry. A renderer that produces nothing from valid source (or a shape
    entirely hidden under another) still needs the gate.
  * anti-aliased junctions -- the gate's real teeth. Where three hues meet in one pixel,
    the blended result lies on no two-colour segment and fails the palette test even
    though every declared colour was on-palette. Deciding that requires knowing which
    shapes overlap after rasterisation, i.e. rasterising. This tool cannot see it and
    does not pretend to; it is the single most likely reason a sprite passes here and
    fails the gate.
  * "3 values per material, max" -- `material` is not something the SVG declares, and
    grouping by palette family gives the wrong answer on a correct sprite (Chomp Flower
    legitimately uses four reds: maw rim, maw base, maw interior, and the meal). Checking
    it would cry wolf, so it is not checked.
  * anything about how the sprite reads at 64px, which is the actual point of the
    contract and is not a property of any file.

CONSERVATISM
------------
A linter that cries wolf on a correct sprite gets switched off, at which point it is
worse than not existing. Every threshold here is set from measurements over the current
corpus, which is green under the raster gate, so any error it raises on those twelve
sprites is a bug in this file.

Two consequences worth knowing about:

  * The geometric bounds computed here are *stroke-expanded outer* bounds, strictly
    larger than the opaque-pixel bounds the gate measures (an anti-aliased edge feathers
    out below the gate's alpha threshold). So the computed margin is strictly smaller
    than the gate's and the computed midline can sit slightly further off centre. The
    margin error threshold is therefore "geometry crosses the canvas edge", not "within
    1px of it", and the centring error threshold is 1.5px against the gate's 1.0 --
    `corn_kernel` is a deliberately asymmetric "D" whose geometric midline is 0.62 off
    and whose rasterised midline the gate passes.
  * A shape whose fill region encloses no area (an open two-point path, a `<line>`) is
    not checked for its fill colour at all. Half the corpus draws legs and X-eyes as
    stroked open paths inside a group that names no `fill`, so they resolve to SVG's
    initial black -- and paint nothing, because there is no area to paint. Flagging
    those would be the loudest false positive this tool could produce.

Exit codes follow the harness convention (`name_check.py`, `coverage_check.py`,
`lint_project.gd`, `run_tests.gd`):
    0  scanned clean (no errors; no warnings either, under --strict)
    1  findings that count -- errors, plus warnings under --strict
    2  could not run: no art_src/, no SVGs, an unreadable STYLE.md or gate file, or a
       --only that selected nothing

Usage:
    python tools/svg_style_check.py                    # check every art_src/*.svg
    python tools/svg_style_check.py --only sundew      # substring filter on the stem
    python tools/svg_style_check.py --strict           # warnings gate too
    python tools/svg_style_check.py --json             # machine-readable
    python tools/svg_style_check.py --quiet            # findings and totals only
    python tools/svg_style_check.py -p ../other-game
"""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import sys
import xml.etree.ElementTree as ET

# ---------------------------------------------------------------------------
# Where the contract lives. Nothing here is a copy of it -- these are paths.
# ---------------------------------------------------------------------------

SRC_DIR = os.path.join("art_src")
STYLE_DOC = os.path.join("art_src", "STYLE.md")
GATE_SCRIPT = os.path.join("test", "unit", "test_sprite_style.gd")

# Mirrors BLEND_TOLERANCE in test_sprite_style.gd: an anti-aliased edge between two flat
# fills lands on the line between them in RGB, so "conformant" is "within this of some
# palette-pair segment". A source colour should be exact; anything between exact and this
# will still pass the raster gate, so it is a warning, not an error.
BLEND_TOLERANCE = 12.0

# STYLE.md: outline is "2 px at 64x64 (1 px on small details)". Interior detail is
# 1-1.5px. Nothing in the kit outlines a filled shape thicker than 2.
MAX_OUTLINE_WIDTH = 2.0

# Below this HSV saturation a colour is "grey" for the purpose of STYLE.md's
# "no black, no grey outlines". #5E5E5E is 0.0; the palest kit colour that is meant to
# read as a hue, #ECDCB8, is 0.22.
GREY_SATURATION = 0.12

# "every rim is the object's own hue, darkened" -- how far the rim's hue may sit from the
# fill's, in degrees. Measured over every rim/fill pair in the corpus the worst is 0.66
# (#89A4A6 rimmed with #758C8E); the closest cross-material pair the palette permits is
# 17.4 (Dirt against Gold). 12 sits between the two with room on both sides.
HUE_TOLERANCE = 12.0

# The raster gate allows the content midline to sit within 1.0px of the canvas centre.
# Geometric bounds run wider than opaque-pixel bounds, so a sprite the gate passes can
# measure slightly further off here: corn_kernel's deliberately asymmetric "D" is 0.62.
# Warn at the gate's own number, gate at a margin over it.
CENTRE_ERROR = 1.5
CENTRE_WARN = 1.0

# The raster gate requires a 1px margin of transparent pixels. Geometric bounds are
# larger than opaque-pixel bounds, so gate at 0 and warn at 1.
MARGIN_WARN = 1.0

SVG_NS = "http://www.w3.org/2000/svg"

# Shapes that paint. Anything drawable outside this set makes the geometry checks
# unreliable, so they are skipped for that sprite rather than guessed at.
SHAPE_TAGS = {"path", "rect", "circle", "ellipse", "line", "polygon", "polyline"}
# Structural elements that are walked but do not paint.
CONTAINER_TAGS = {"svg", "g", "a", "switch"}
# Elements whose subtree is never rendered directly.
SKIP_SUBTREE_TAGS = {"defs", "title", "desc", "metadata", "symbol", "clipPath", "mask",
                     "marker", "style", "script"}

# The handful of CSS colour keywords worth recognising. Anything else is reported as an
# unrecognised paint rather than guessed at -- none of them would be on the palette.
NAMED_COLOURS = {
    "black": (0, 0, 0),
    "white": (255, 255, 255),
    "red": (255, 0, 0),
    "green": (0, 128, 0),
    "blue": (0, 0, 255),
    "grey": (128, 128, 128),
    "gray": (128, 128, 128),
    "silver": (192, 192, 192),
    "yellow": (255, 255, 0),
    "orange": (255, 165, 0),
}

NUM_RE = re.compile(r"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")


# ---------------------------------------------------------------------------
# Findings
# ---------------------------------------------------------------------------

ERROR, WARNING, ADVISORY = "error", "warning", "advisory"

# Every check this tool knows how to run. Printed as a denominator, because a check that
# vanished from a consolidated report is indistinguishable from a check that passed.
CHECKS = [
    "declared",
    "canvas",
    "palette",
    "flat_paint",
    "outline",
    "outline_width",
    "black_fill",
    "content",
    "centred",
    "margin",
]


class Finding:
    def __init__(self, severity, check, sprite, message, detail=""):
        self.severity = severity
        self.check = check
        self.sprite = sprite
        self.message = message
        self.detail = detail

    def as_dict(self):
        return {
            "severity": self.severity,
            "check": self.check,
            "sprite": self.sprite,
            "message": self.message,
            "detail": self.detail,
        }


# ---------------------------------------------------------------------------
# Colour
# ---------------------------------------------------------------------------

def parse_hex(text):
    """`#RGB` / `#RRGGBB` -> (r, g, b), else None."""
    t = text.strip()
    if not t.startswith("#"):
        return None
    body = t[1:]
    if len(body) == 3 and all(c in "0123456789abcdefABCDEF" for c in body):
        return tuple(int(c * 2, 16) for c in body)
    if len(body) == 6 and all(c in "0123456789abcdefABCDEF" for c in body):
        return tuple(int(body[i:i + 2], 16) for i in (0, 2, 4))
    return None


def parse_paint(text):
    """Resolve a paint value.

    Returns (kind, value):
      ("none", None)      -- explicitly not painted
      ("rgb", (r, g, b))  -- a concrete colour
      ("ref", "url(#x)")  -- a gradient/pattern reference
      ("unknown", text)   -- something this tool will not guess at
    """
    if text is None:
        return ("none", None)
    t = text.strip()
    low = t.lower()
    if low in ("none", "transparent"):
        return ("none", None)
    if low.startswith("url("):
        return ("ref", t)
    rgb = parse_hex(t)
    if rgb is not None:
        return ("rgb", rgb)
    if low in NAMED_COLOURS:
        return ("rgb", NAMED_COLOURS[low])
    m = re.match(r"rgba?\(([^)]*)\)", low)
    if m:
        parts = [p.strip() for p in m.group(1).replace("/", ",").split(",")]
        try:
            vals = []
            for p in parts[:3]:
                if p.endswith("%"):
                    vals.append(int(round(float(p[:-1]) * 2.55)))
                else:
                    vals.append(int(round(float(p))))
            if len(vals) == 3:
                return ("rgb", tuple(max(0, min(255, v)) for v in vals))
        except ValueError:
            pass
    return ("unknown", t)


def to_hex(rgb):
    return "#%02X%02X%02X" % rgb


def luminance(rgb):
    """sRGB-weighted relative brightness, 0-255. Only ever compared, never absolute."""
    r, g, b = rgb
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def saturation(rgb):
    mx, mn = max(rgb), min(rgb)
    return 0.0 if mx == 0 else (mx - mn) / float(mx)


def hue(rgb):
    """Degrees 0-360, or None for a greyscale colour."""
    r, g, b = [c / 255.0 for c in rgb]
    mx, mn = max(r, g, b), min(r, g, b)
    d = mx - mn
    if d == 0:
        return None
    if mx == r:
        h = 60.0 * (((g - b) / d) % 6.0)
    elif mx == g:
        h = 60.0 * (((b - r) / d) + 2.0)
    else:
        h = 60.0 * (((r - g) / d) + 4.0)
    return h % 360.0


def hue_distance(a, b):
    d = abs(a - b) % 360.0
    return min(d, 360.0 - d)


def distance_to_palette_blend(rgb, palette):
    """Shortest distance (0-255 scale) from `rgb` to the segment between any two palette
    entries -- the set of colours an anti-aliased edge can legitimately produce.

    This is a straight port of `_distance_to_palette_blend` in test_sprite_style.gd. It
    is ported rather than reimplemented on purpose: if the two ever measure "how far off"
    differently, a sprite can be clean here and fail the gate with a number that does not
    match anything this tool printed.
    """
    px, py, pz = rgb
    best = float("inf")
    n = len(palette)
    for i in range(n):
        ax, ay, az = palette[i]
        for j in range(i, n):
            bx, by, bz = palette[j]
            abx, aby, abz = bx - ax, by - ay, bz - az
            len_sq = abx * abx + aby * aby + abz * abz
            if len_sq == 0.0:
                t = 0.0
            else:
                t = ((px - ax) * abx + (py - ay) * aby + (pz - az) * abz) / len_sq
                t = max(0.0, min(1.0, t))
            dx = px - (ax + abx * t)
            dy = py - (ay + aby * t)
            dz = pz - (az + abz * t)
            d = math.sqrt(dx * dx + dy * dy + dz * dz)
            if d < best:
                best = d
                if best == 0.0:
                    return 0.0
    return best


# ---------------------------------------------------------------------------
# Contract loading -- STYLE.md and the raster gate
# ---------------------------------------------------------------------------

class Contract:
    def __init__(self):
        self.sizes = {}          # stem -> int
        self.palette = {}        # "RRGGBB" -> (r, g, b)
        self.families = {}       # family name -> [hex, ...]
        self.family_of = {}      # "RRGGBB" -> family name
        self.inferred = {}       # "RRGGBB" -> family name (assigned by hue, not read)
        self.notes = []          # advisory notes about the contract itself


def read_text(path):
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read()


def load_gate_constants(path):
    """Pull EXPECTED_SIZE and PALETTE out of test_sprite_style.gd.

    Regex over GDScript, not over SVG -- the source of truth for both is a const block in
    a file this tool must never edit, and re-declaring either here would guarantee they
    drift.
    """
    text = read_text(path)
    sizes = {}
    m = re.search(r"const\s+EXPECTED_SIZE\s*:?=?\s*\{(.*?)\}", text, re.S)
    if m:
        for name, val in re.findall(r'"([A-Za-z0-9_]+)"\s*:\s*(\d+)', m.group(1)):
            sizes[name] = int(val)
    palette = []
    m = re.search(r"const\s+PALETTE[^\[]*\[(.*?)\]", text, re.S)
    if m:
        palette = [h.upper() for h in re.findall(r'"([0-9a-fA-F]{6})"', m.group(1))]
    return sizes, palette


def load_style_families(path):
    """Parse STYLE.md's palette table into families, plus the extrapolated shades its
    prose documents underneath it."""
    families = {}
    loose = []
    in_table = False
    for line in read_text(path).splitlines():
        stripped = line.strip()
        if stripped.startswith("|") and "Dark rim" in stripped and "Base" in stripped:
            in_table = True
            continue
        if in_table:
            if not stripped.startswith("|"):
                in_table = False
            else:
                cells = [c.strip() for c in stripped.strip("|").split("|")]
                if not cells or set(cells[0]) <= set("-: "):
                    continue
                role = cells[0]
                hexes = []
                for cell in cells[1:]:
                    rgb = parse_hex(cell.strip("` "))
                    if rgb is not None:
                        hexes.append(to_hex(rgb)[1:])
                if role and hexes:
                    families[role] = hexes
                continue
        # Extrapolated shades are documented in prose, not in the table.
        if not in_table:
            for token in re.findall(r"`#([0-9a-fA-F]{6})`", line):
                loose.append(token.upper())
    return families, loose


def assign_family(hex6, families):
    """Best family for a palette entry the STYLE.md table does not list.

    Grey goes to the nearest grey family by luminance; a hue goes to the nearest family
    by hue angle. Straight RGB distance gets this wrong in a way that matters: #8A6D00
    (the extrapolated dark gold for the corn faces) is nearer to the Dirt row than to the
    Gold row in RGB, and 17 degrees of hue away from Dirt against 0.2 from Gold.

    Used only to put a readable material name in a message. Nothing gates on it: the two
    foliage rows in STYLE.md's table are 0.01 degrees of hue apart and are freely mixed
    (Corn Cobbler rims a #2ABB67 leaf with #1F8A4C), so family *membership* is the wrong
    thing to enforce and the hue check in check_outline is the right one.
    """
    rgb = parse_hex("#" + hex6)
    is_grey = saturation(rgb) < GREY_SATURATION
    best, best_d = None, float("inf")
    for name, members in families.items():
        for member in members:
            mrgb = parse_hex("#" + member)
            mgrey = saturation(mrgb) < GREY_SATURATION
            if is_grey != mgrey:
                continue
            if is_grey:
                d = abs(luminance(rgb) - luminance(mrgb))
            else:
                d = hue_distance(hue(rgb), hue(mrgb))
            if d < best_d:
                best_d, best = d, name
    return best


def load_contract(root):
    """Assemble the contract, or raise RuntimeError with the reason it could not."""
    c = Contract()
    gate_path = os.path.join(root, GATE_SCRIPT)
    style_path = os.path.join(root, STYLE_DOC)
    if not os.path.isfile(gate_path):
        raise RuntimeError("no %s -- the canvas sizes and palette live there" % GATE_SCRIPT)
    if not os.path.isfile(style_path):
        raise RuntimeError("no %s -- the style contract lives there" % STYLE_DOC)

    sizes, palette_hexes = load_gate_constants(gate_path)
    if not sizes:
        raise RuntimeError("could not read EXPECTED_SIZE out of %s" % GATE_SCRIPT)
    if not palette_hexes:
        raise RuntimeError("could not read PALETTE out of %s" % GATE_SCRIPT)
    c.sizes = sizes
    for h in palette_hexes:
        c.palette[h] = parse_hex("#" + h)

    families, loose = load_style_families(style_path)
    if not families:
        raise RuntimeError("could not read the palette table out of %s" % STYLE_DOC)
    c.families = families
    for name, members in families.items():
        for member in members:
            c.family_of[member] = name

    documented = set(c.family_of) | set(loose)
    undocumented = [h for h in palette_hexes if h not in documented]
    for h in palette_hexes:
        if h in c.family_of:
            continue
        fam = assign_family(h, families)
        if fam:
            c.family_of[h] = fam
            c.inferred[h] = fam
    if undocumented:
        c.notes.append(
            "the gate's PALETTE carries %d entr%s STYLE.md does not document: %s"
            % (len(undocumented), "y" if len(undocumented) == 1 else "ies",
               ", ".join("#" + h for h in undocumented)))
    for h in loose:
        if h not in c.palette:
            c.notes.append("STYLE.md documents #%s but the gate's PALETTE does not "
                           "carry it -- a sprite using it would fail the gate" % h)
    return c


# ---------------------------------------------------------------------------
# Affine transforms  (a c e / b d f / 0 0 1)
# ---------------------------------------------------------------------------

IDENTITY = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)


def mat_mul(m, n):
    a1, b1, c1, d1, e1, f1 = m
    a2, b2, c2, d2, e2, f2 = n
    return (
        a1 * a2 + c1 * b2,
        b1 * a2 + d1 * b2,
        a1 * c2 + c1 * d2,
        b1 * c2 + d1 * d2,
        a1 * e2 + c1 * f2 + e1,
        b1 * e2 + d1 * f2 + f1,
    )


def mat_apply(m, x, y):
    a, b, c, d, e, f = m
    return (a * x + c * y + e, b * x + d * y + f)


def mat_scale(m):
    """Uniform-ish scale factor, used to scale stroke widths. sqrt(|det|) is exact for
    the rotations and translations these sprites use."""
    a, b, c, d, _, _ = m
    return math.sqrt(abs(a * d - b * c)) or 1.0


def parse_transform(text):
    """Compose an SVG `transform` attribute. Unknown functions raise ValueError rather
    than being ignored -- silently dropping a transform moves geometry."""
    if not text:
        return IDENTITY
    m = IDENTITY
    for name, args in re.findall(r"([a-zA-Z]+)\s*\(([^)]*)\)", text):
        vals = [float(v) for v in NUM_RE.findall(args)]
        name = name.strip()
        if name == "translate":
            tx = vals[0] if vals else 0.0
            ty = vals[1] if len(vals) > 1 else 0.0
            m = mat_mul(m, (1.0, 0.0, 0.0, 1.0, tx, ty))
        elif name == "scale":
            sx = vals[0] if vals else 1.0
            sy = vals[1] if len(vals) > 1 else sx
            m = mat_mul(m, (sx, 0.0, 0.0, sy, 0.0, 0.0))
        elif name == "rotate":
            ang = math.radians(vals[0] if vals else 0.0)
            cos, sin = math.cos(ang), math.sin(ang)
            rot = (cos, sin, -sin, cos, 0.0, 0.0)
            if len(vals) >= 3:
                cx, cy = vals[1], vals[2]
                m = mat_mul(m, (1.0, 0.0, 0.0, 1.0, cx, cy))
                m = mat_mul(m, rot)
                m = mat_mul(m, (1.0, 0.0, 0.0, 1.0, -cx, -cy))
            else:
                m = mat_mul(m, rot)
        elif name == "matrix" and len(vals) >= 6:
            m = mat_mul(m, tuple(vals[:6]))
        elif name == "skewX":
            m = mat_mul(m, (1.0, 0.0, math.tan(math.radians(vals[0])), 1.0, 0.0, 0.0))
        elif name == "skewY":
            m = mat_mul(m, (1.0, math.tan(math.radians(vals[0])), 0.0, 1.0, 0.0, 0.0))
        else:
            raise ValueError("unsupported transform function: %s()" % name)
    return m


# ---------------------------------------------------------------------------
# Bounding boxes
# ---------------------------------------------------------------------------

class Box:
    __slots__ = ("x0", "y0", "x1", "y1")

    def __init__(self):
        self.x0 = self.y0 = float("inf")
        self.x1 = self.y1 = float("-inf")

    def add(self, x, y):
        if x < self.x0:
            self.x0 = x
        if x > self.x1:
            self.x1 = x
        if y < self.y0:
            self.y0 = y
        if y > self.y1:
            self.y1 = y

    def grow(self, amount):
        if not self.empty():
            self.x0 -= amount
            self.y0 -= amount
            self.x1 += amount
            self.y1 += amount

    def union(self, other):
        if other.empty():
            return
        self.add(other.x0, other.y0)
        self.add(other.x1, other.y1)

    def empty(self):
        return self.x1 < self.x0

    def copy(self):
        b = Box()
        b.x0, b.y0, b.x1, b.y1 = self.x0, self.y0, self.x1, self.y1
        return b


def quad_extrema(p0, p1, p2):
    """Parameters in (0,1) where a quadratic bezier turns, per axis."""
    out = []
    for i in (0, 1):
        denom = p0[i] - 2.0 * p1[i] + p2[i]
        if abs(denom) > 1e-12:
            t = (p0[i] - p1[i]) / denom
            if 0.0 < t < 1.0:
                out.append(t)
    return out


def cubic_extrema(p0, p1, p2, p3):
    out = []
    for i in (0, 1):
        A = p1[i] - p0[i]
        B = p2[i] - p1[i]
        C = p3[i] - p2[i]
        a = A - 2.0 * B + C
        b = 2.0 * (B - A)
        c = A
        if abs(a) < 1e-12:
            if abs(b) > 1e-12:
                t = -c / b
                if 0.0 < t < 1.0:
                    out.append(t)
            continue
        disc = b * b - 4.0 * a * c
        if disc < 0.0:
            continue
        rt = math.sqrt(disc)
        for t in ((-b + rt) / (2.0 * a), (-b - rt) / (2.0 * a)):
            if 0.0 < t < 1.0:
                out.append(t)
    return out


def quad_point(p0, p1, p2, t):
    u = 1.0 - t
    return (u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
            u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1])


def cubic_point(p0, p1, p2, p3, t):
    u = 1.0 - t
    return (u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
            u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1])


class UnsupportedGeometry(Exception):
    """Raised for source this tool will not guess the bounds of.

    `malformed` separates the two very different reasons that happens. A `d` attribute
    that does not tokenize is broken source -- Godot renders it as a fully transparent
    PNG, the texture loads, the sprite node is there, and the screen is empty -- so it is
    an error. An elliptical arc or a `<use>` is perfectly valid SVG that this tool simply
    cannot measure, so the geometry checks are reported as SKIPPED for that sprite, never
    folded into a clean result.
    """

    def __init__(self, message, malformed=False):
        Exception.__init__(self, message)
        self.malformed = malformed


def tokenize_path(d):
    """Split a `d` attribute into (command, [numbers]) pairs."""
    tokens = re.findall(r"[MmZzLlHhVvCcSsQqTtAa]|" + NUM_RE.pattern, d)
    if not tokens:
        raise UnsupportedGeometry("empty or unparseable path data", malformed=True)
    counts = {"M": 2, "L": 2, "H": 1, "V": 1, "C": 6, "S": 4, "Q": 4, "T": 2, "A": 7, "Z": 0}
    out = []
    i = 0
    cmd = None
    while i < len(tokens):
        t = tokens[i]
        if t.isalpha():
            cmd = t
            i += 1
        elif cmd is None:
            raise UnsupportedGeometry("path data starts with a number, not a command",
                                      malformed=True)
        elif cmd.upper() == "M":
            cmd = "L" if cmd == "M" else "l"   # a repeated moveto is an implicit lineto
        n = counts[cmd.upper()]
        if n and i + n > len(tokens):
            raise UnsupportedGeometry("path command %s is missing arguments" % cmd,
                                      malformed=True)
        args = [float(x) for x in tokens[i:i + n]]
        i += n
        out.append((cmd, args))
    return out


def path_bbox(d, mat):
    """Exact bounding box of a path's outline (no stroke), under `mat`.

    Bezier extrema are solved rather than approximated by the control hull. The control
    hull would over-estimate, which reads as a smaller margin than the sprite really has
    -- exactly the false positive this tool must not produce.
    """
    box = Box()
    cur = (0.0, 0.0)
    start = (0.0, 0.0)
    prev_quad_ctrl = None
    prev_cubic_ctrl = None

    def put(pt):
        box.add(*mat_apply(mat, pt[0], pt[1]))

    for cmd, args in tokenize_path(d):
        upper = cmd.upper()
        rel = cmd.islower()
        if upper == "A":
            raise UnsupportedGeometry("elliptical arc (A/a) segments")
        if upper == "M":
            cur = (cur[0] + args[0], cur[1] + args[1]) if rel else (args[0], args[1])
            start = cur
            put(cur)
            prev_quad_ctrl = prev_cubic_ctrl = None
        elif upper == "L":
            cur = (cur[0] + args[0], cur[1] + args[1]) if rel else (args[0], args[1])
            put(cur)
            prev_quad_ctrl = prev_cubic_ctrl = None
        elif upper == "H":
            cur = (cur[0] + args[0], cur[1]) if rel else (args[0], cur[1])
            put(cur)
            prev_quad_ctrl = prev_cubic_ctrl = None
        elif upper == "V":
            cur = (cur[0], cur[1] + args[0]) if rel else (cur[0], args[0])
            put(cur)
            prev_quad_ctrl = prev_cubic_ctrl = None
        elif upper in ("Q", "T"):
            if upper == "Q":
                c = (cur[0] + args[0], cur[1] + args[1]) if rel else (args[0], args[1])
                end = (cur[0] + args[2], cur[1] + args[3]) if rel else (args[2], args[3])
            else:
                c = cur if prev_quad_ctrl is None else (2 * cur[0] - prev_quad_ctrl[0],
                                                        2 * cur[1] - prev_quad_ctrl[1])
                end = (cur[0] + args[0], cur[1] + args[1]) if rel else (args[0], args[1])
            put(cur)
            put(end)
            for t in quad_extrema(cur, c, end):
                put(quad_point(cur, c, end, t))
            prev_quad_ctrl = c
            prev_cubic_ctrl = None
            cur = end
        elif upper in ("C", "S"):
            if upper == "C":
                c1 = (cur[0] + args[0], cur[1] + args[1]) if rel else (args[0], args[1])
                c2 = (cur[0] + args[2], cur[1] + args[3]) if rel else (args[2], args[3])
                end = (cur[0] + args[4], cur[1] + args[5]) if rel else (args[4], args[5])
            else:
                c1 = cur if prev_cubic_ctrl is None else (2 * cur[0] - prev_cubic_ctrl[0],
                                                          2 * cur[1] - prev_cubic_ctrl[1])
                c2 = (cur[0] + args[0], cur[1] + args[1]) if rel else (args[0], args[1])
                end = (cur[0] + args[2], cur[1] + args[3]) if rel else (args[2], args[3])
            put(cur)
            put(end)
            for t in cubic_extrema(cur, c1, c2, end):
                put(cubic_point(cur, c1, c2, end, t))
            prev_cubic_ctrl = c2
            prev_quad_ctrl = None
            cur = end
        elif upper == "Z":
            cur = start
            prev_quad_ctrl = prev_cubic_ctrl = None
    return box


def polygon_area(points):
    """Shoelace. Sign is irrelevant here; only zero-vs-nonzero is asked."""
    a = 0.0
    n = len(points)
    for i in range(n):
        x0, y0 = points[i]
        x1, y1 = points[(i + 1) % n]
        a += x0 * y1 - x1 * y0
    return abs(a) * 0.5


def path_fill_area(d):
    """Approximate area the path's fill would cover, in user units squared.

    Only ever compared against ~0, to answer "does the `fill` on this element paint
    anything at all". Beziers contribute their control points, which over-states area --
    the right direction, since over-stating can only keep a fill check switched ON.

    This matters because SVG's initial `fill` is BLACK. Legs, antennae, kernel seams and
    X-eyes are all open stroked paths inside groups that never name a fill, so they
    resolve to black -- and paint nothing, because a line encloses no area.
    """
    area = 0.0
    sub = []
    cur = (0.0, 0.0)
    start = (0.0, 0.0)

    def flush():
        if len(sub) >= 3:
            return polygon_area(sub)
        return 0.0

    for cmd, args in tokenize_path(d):
        upper = cmd.upper()
        rel = cmd.islower()
        if upper == "A":
            raise UnsupportedGeometry("elliptical arc (A/a) segments")
        if upper == "M":
            area += flush()
            del sub[:]
            cur = (cur[0] + args[0], cur[1] + args[1]) if rel else (args[0], args[1])
            start = cur
            sub.append(cur)
        elif upper == "Z":
            area += flush()
            del sub[:]
            cur = start
            sub.append(cur)
        else:
            pts = []
            for i in range(0, len(args) - 1, 2):
                if upper == "H":
                    pts.append((cur[0] + args[i], cur[1]) if rel else (args[i], cur[1]))
                elif upper == "V":
                    pts.append((cur[0], cur[1] + args[i]) if rel else (cur[0], args[i]))
                else:
                    pts.append((cur[0] + args[i], cur[1] + args[i + 1]) if rel
                               else (args[i], args[i + 1]))
            if upper in ("H", "V"):
                pts = pts[:1] or [cur]
            sub.extend(pts)
            if pts:
                cur = pts[-1]
    area += flush()
    return area


def shape_fill_area(tag, attrs):
    """Area the element's fill would cover. `<line>` is never filled per the SVG spec."""
    def f(name, default=0.0):
        v = attrs.get(name)
        if v is None:
            return default
        nums = NUM_RE.findall(v)
        return float(nums[0]) if nums else default

    if tag == "line":
        return 0.0
    if tag == "circle":
        return math.pi * max(0.0, f("r")) ** 2
    if tag == "ellipse":
        return math.pi * max(0.0, f("rx")) * max(0.0, f("ry"))
    if tag == "rect":
        return max(0.0, f("width")) * max(0.0, f("height"))
    if tag in ("polygon", "polyline"):
        nums = [float(n) for n in NUM_RE.findall(attrs.get("points", ""))]
        pts = [(nums[i], nums[i + 1]) for i in range(0, len(nums) - 1, 2)]
        return polygon_area(pts) if len(pts) >= 3 else 0.0
    if tag == "path":
        d = attrs.get("d")
        if d is None:
            raise UnsupportedGeometry("<path> with no d attribute", malformed=True)
        return path_fill_area(d)
    raise UnsupportedGeometry("<%s>" % tag)


def ellipse_bbox(cx, cy, rx, ry, mat):
    """Exact bbox of an axis-aligned ellipse under an affine map.

    The extent along x of the image of the ellipse is sqrt((a*rx)^2 + (c*ry)^2) -- closed
    form, so a rotated petal ring is measured, not sampled.
    """
    a, b, c, d, _, _ = mat
    ex = math.hypot(a * rx, c * ry)
    ey = math.hypot(b * rx, d * ry)
    px, py = mat_apply(mat, cx, cy)
    box = Box()
    box.add(px - ex, py - ey)
    box.add(px + ex, py + ey)
    return box


def shape_bbox(tag, attrs, mat):
    """Geometric bbox of one shape, stroke NOT included."""
    def f(name, default=0.0):
        v = attrs.get(name)
        if v is None:
            return default
        nums = NUM_RE.findall(v)
        return float(nums[0]) if nums else default

    if tag == "circle":
        r = f("r")
        if r <= 0:
            return Box()
        return ellipse_bbox(f("cx"), f("cy"), r, r, mat)
    if tag == "ellipse":
        rx, ry = f("rx"), f("ry")
        if rx <= 0 or ry <= 0:
            return Box()
        return ellipse_bbox(f("cx"), f("cy"), rx, ry, mat)
    if tag == "rect":
        w, h = f("width"), f("height")
        if w <= 0 or h <= 0:
            return Box()
        x, y = f("x"), f("y")
        box = Box()
        for px, py in ((x, y), (x + w, y), (x, y + h), (x + w, y + h)):
            box.add(*mat_apply(mat, px, py))
        return box
    if tag == "line":
        box = Box()
        box.add(*mat_apply(mat, f("x1"), f("y1")))
        box.add(*mat_apply(mat, f("x2"), f("y2")))
        return box
    if tag in ("polygon", "polyline"):
        nums = [float(n) for n in NUM_RE.findall(attrs.get("points", ""))]
        box = Box()
        for i in range(0, len(nums) - 1, 2):
            box.add(*mat_apply(mat, nums[i], nums[i + 1]))
        return box
    if tag == "path":
        d = attrs.get("d")
        if d is None:
            raise UnsupportedGeometry("<path> with no d attribute", malformed=True)
        return path_bbox(d, mat)
    raise UnsupportedGeometry("<%s>" % tag)


# ---------------------------------------------------------------------------
# SVG walk
# ---------------------------------------------------------------------------

INHERITED = ("fill", "stroke", "stroke-width", "opacity", "fill-opacity",
             "stroke-opacity", "stroke-linecap", "stroke-linejoin")

# SVG's initial values. `fill` is deliberately absent rather than set to its initial
# "#000000": a shape that never names a fill anywhere up its ancestry renders BLACK,
# which STYLE.md forbids outright and which is invisible in a diff, so the two cases have
# to stay distinguishable all the way down to the check.
INITIAL_STYLE = {"stroke": "none", "stroke-width": "1",
                 "opacity": "1", "fill-opacity": "1", "stroke-opacity": "1"}
INITIAL_FILL = "#000000"


def local_tag(elem):
    tag = elem.tag
    if isinstance(tag, str) and tag.startswith("{"):
        return tag.split("}", 1)[1]
    return tag if isinstance(tag, str) else ""


def element_style(elem, inherited):
    """Resolve presentation attributes for one element, `style=` overriding attributes."""
    style = dict(inherited)
    for key in INHERITED:
        if key in elem.attrib:
            style[key] = elem.attrib[key]
    css = elem.attrib.get("style")
    if css:
        for decl in css.split(";"):
            if ":" not in decl:
                continue
            k, v = decl.split(":", 1)
            k = k.strip()
            if k in INHERITED:
                style[k] = v.strip()
    return style


class Shape:
    """One painted element with its resolved paint and its place in the file."""

    def __init__(self, tag, attrs, style, mat, where):
        self.tag = tag
        self.attrs = attrs
        self.style = style
        self.mat = mat
        self.where = where


def collect_shapes(root_elem, base_mat):
    """Walk the tree, returning (shapes, defs_tags, transform_errors)."""
    shapes = []
    defs_tags = []
    problems = []

    def walk(elem, mat, style):
        tag = local_tag(elem)
        if tag in SKIP_SUBTREE_TAGS:
            for sub in elem.iter():
                st = local_tag(sub)
                if st.endswith("Gradient") or st in ("pattern", "filter"):
                    defs_tags.append(st)
            return
        if tag.endswith("Gradient") or tag in ("pattern", "filter"):
            defs_tags.append(tag)
            return
        try:
            mat = mat_mul(mat, parse_transform(elem.attrib.get("transform")))
        except ValueError as exc:
            problems.append(str(exc))
            return
        style = element_style(elem, style)
        if tag in SHAPE_TAGS:
            where = describe(elem, tag)
            shapes.append(Shape(tag, dict(elem.attrib), style, mat, where))
            return
        if tag in CONTAINER_TAGS:
            for child in elem:
                walk(child, mat, style)
            return
        if tag in ("use", "text", "tspan", "image", "foreignObject"):
            problems.append("<%s> is not something this tool can measure" % tag)
            return
        # Anything else with children is walked; anything else without is ignored.
        for child in elem:
            walk(child, mat, style)

    walk(root_elem, base_mat, dict(INITIAL_STYLE))
    return shapes, defs_tags, problems


def describe(elem, tag):
    """A short, human-findable handle for an element -- enough to grep for."""
    for key in ("d", "points"):
        if key in elem.attrib:
            v = " ".join(elem.attrib[key].split())
            if len(v) > 34:
                v = v[:31] + "..."
            return '<%s %s="%s">' % (tag, key, v)
    bits = []
    for key in ("cx", "cy", "r", "rx", "ry", "x", "y", "width", "height", "x1", "y1"):
        if key in elem.attrib:
            bits.append('%s="%s"' % (key, elem.attrib[key]))
        if len(bits) >= 3:
            break
    return "<%s %s>" % (tag, " ".join(bits)) if bits else "<%s>" % tag


# ---------------------------------------------------------------------------
# The checks
# ---------------------------------------------------------------------------

class SpriteResult:
    def __init__(self, stem):
        self.stem = stem
        self.size = None
        self.box = None
        self.geometry_ok = False
        self.skipped = []
        self.findings = []


def parse_length(text):
    if text is None:
        return None
    nums = NUM_RE.findall(text)
    return float(nums[0]) if nums else None


def check_sprite(path, stem, contract, findings):
    """Run every check over one SVG. Appends to `findings`; returns a SpriteResult."""
    res = SpriteResult(stem)

    try:
        tree = ET.parse(path)
    except ET.ParseError as exc:
        findings.append(Finding(ERROR, "canvas", stem, "not well-formed XML", str(exc)))
        return res
    root = tree.getroot()
    if local_tag(root) != "svg":
        findings.append(Finding(ERROR, "canvas", stem,
                                "root element is <%s>, not <svg>" % local_tag(root)))
        return res

    # ---- declared -------------------------------------------------------
    expected = contract.sizes.get(stem)
    if expected is None:
        findings.append(Finding(
            ERROR, "declared", stem,
            "no EXPECTED_SIZE row in %s" % GATE_SCRIPT,
            "an undeclared sprite renders, ships and is ungated -- and its PNG makes the "
            "gate's own 'every PNG is declared' count fail"))

    # ---- canvas ---------------------------------------------------------
    w = parse_length(root.attrib.get("width"))
    h = parse_length(root.attrib.get("height"))
    vb = [float(n) for n in NUM_RE.findall(root.attrib.get("viewBox", ""))]
    base = IDENTITY
    if w is None or h is None:
        findings.append(Finding(ERROR, "canvas", stem,
                                "no width/height on <svg>",
                                "render_svg.gd rasterises at the SVG's own size; without "
                                "one the output size is the renderer's guess"))
    else:
        res.size = (w, h)
        if w != h:
            findings.append(Finding(ERROR, "canvas", stem,
                                    "canvas is %gx%g, not square" % (w, h)))
        if expected is not None and (w != expected or h != expected):
            findings.append(Finding(
                ERROR, "canvas", stem,
                "canvas is %gx%g, EXPECTED_SIZE says %dx%d" % (w, h, expected, expected)))
    if len(vb) == 4:
        if vb[0] != 0 or vb[1] != 0:
            findings.append(Finding(WARNING, "canvas", stem,
                                    "viewBox origin is %g %g, not 0 0" % (vb[0], vb[1])))
        if w is not None and (abs(vb[2] - w) > 1e-9 or abs(vb[3] - h) > 1e-9):
            findings.append(Finding(
                ERROR, "canvas", stem,
                "viewBox %g %g %g %g does not map 1:1 to the %gx%g canvas"
                % (vb[0], vb[1], vb[2], vb[3], w, h),
                "a scaled viewBox means stroke-width=\"2\" is no longer 2px, and every "
                "measurement in STYLE.md is in px"))
        if vb[2] > 0 and vb[3] > 0 and w:
            base = mat_mul((w / vb[2], 0.0, 0.0, h / vb[3], 0.0, 0.0),
                           (1.0, 0.0, 0.0, 1.0, -vb[0], -vb[1]))
    elif root.attrib.get("viewBox"):
        findings.append(Finding(ERROR, "canvas", stem, "viewBox is not four numbers"))

    # ---- walk -----------------------------------------------------------
    shapes, defs_tags, problems = collect_shapes(root, base)
    for p in problems:
        res.skipped.append(p)

    if defs_tags:
        findings.append(Finding(
            ERROR, "flat_paint", stem,
            "declares %s" % ", ".join("<%s>" % t for t in sorted(set(defs_tags))),
            "STYLE.md: one lighter shade may be used as a flat highlight facet -- "
            "never a gradient"))

    # ---- paint (palette / flat_paint / outline) -------------------------
    palette_rgb = list(contract.palette.values())
    seen_colours = {}
    painted = 0
    content = Box()
    geometry_ok = True

    for shape in shapes:
        raw_fill = shape.style.get("fill")
        fill_declared = raw_fill is not None
        fill_kind, fill_val = parse_paint(raw_fill if fill_declared else INITIAL_FILL)
        stroke_kind, stroke_val = parse_paint(shape.style.get("stroke"))
        try:
            stroke_w = float(NUM_RE.findall(shape.style.get("stroke-width", "1"))[0])
        except (IndexError, ValueError):
            stroke_w = 1.0

        # A fill only exists if there is an area for it to cover. Legs, seams, antennae
        # and X-eyes are open stroked paths; the corpus writes fill="none" on most of
        # them and leaves it off some, and neither paints a pixel of fill.
        try:
            fills_something = shape_fill_area(shape.tag, shape.attrs) > 1e-6
        except UnsupportedGeometry as exc:
            if exc.malformed:
                findings.append(Finding(
                    ERROR, "content", stem, "unparseable geometry: %s" % exc,
                    "Godot renders this as a fully transparent PNG: the texture loads, "
                    "the sprite node is there, the screen is empty. %s" % shape.where))
            fills_something = True   # cannot tell -> keep the fill checks switched on
        if not fills_something:
            if fill_declared and fill_kind == "rgb":
                # Still a declared colour in the file; count it for the palette check,
                # but it is not an outline situation and not a black-fill situation.
                seen_colours.setdefault(fill_val, shape.where)
            fill_kind, fill_val = "none", None
        elif not fill_declared:
            findings.append(Finding(
                ERROR, "black_fill", stem,
                "no fill declared anywhere up its ancestry, so it renders black",
                "SVG's initial fill is #000000 and STYLE.md forbids black outright. "
                "Write fill=\"none\" if it is a line, or name the colour. %s"
                % shape.where))

        for kind, val, which in ((fill_kind, fill_val, "fill"),
                                 (stroke_kind, stroke_val, "stroke")):
            if kind == "ref":
                findings.append(Finding(ERROR, "flat_paint", stem,
                                        "%s is a paint reference (%s)" % (which, val),
                                        shape.where))
            elif kind == "unknown":
                findings.append(Finding(WARNING, "palette", stem,
                                        "%s=\"%s\" is a paint this tool cannot resolve"
                                        % (which, val), shape.where))
            elif kind == "rgb":
                seen_colours.setdefault(val, shape.where)

        for key in ("opacity", "fill-opacity", "stroke-opacity"):
            raw = shape.style.get(key, "1")
            try:
                v = float(raw)
            except ValueError:
                continue
            if v < 1.0:
                findings.append(Finding(
                    WARNING, "flat_paint", stem, "%s=\"%s\"" % (key, raw),
                    "a translucent shape composites against whatever is under it; the "
                    "result lands on no palette segment and fails the raster gate",
                ))

        # outline: this shape has both a fill and a rim
        if fill_kind == "rgb" and stroke_kind == "rgb" and stroke_w > 0:
            check_outline(stem, fill_val, stroke_val, shape.where, contract, findings)
            if stroke_w > MAX_OUTLINE_WIDTH + 1e-9:
                findings.append(Finding(
                    WARNING, "outline_width", stem,
                    "outline stroke-width is %g" % stroke_w,
                    "STYLE.md: outline = 2px at 64x64 (1px on small details). %s"
                    % shape.where))

        is_painted = fill_kind == "rgb" or (stroke_kind == "rgb" and stroke_w > 0)

        # ---- geometry ---------------------------------------------------
        if not geometry_ok:
            continue
        try:
            box = shape_bbox(shape.tag, shape.attrs, shape.mat)
        except UnsupportedGeometry as exc:
            # A malformed `d` already produced a content error above; do not say it twice.
            if not exc.malformed:
                res.skipped.append("%s (%s)" % (exc, shape.where))
            geometry_ok = False
            continue
        if box.empty():
            continue
        if is_painted:
            painted += 1
            if stroke_kind == "rgb" and stroke_w > 0:
                # Round caps and joins expand the outline by exactly half the stroke
                # width in every direction. Butt caps expand by less, so this is an
                # over-estimate -- deliberately, since it can only report a TIGHTER
                # margin than the sprite really has.
                box.grow(stroke_w * mat_scale(shape.mat) * 0.5)
            content.union(box)

    for rgb, where in sorted(seen_colours.items()):
        check_palette(stem, rgb, where, contract, palette_rgb, findings)

    # ---- content --------------------------------------------------------
    if not shapes:
        findings.append(Finding(ERROR, "content", stem, "no drawable elements",
                                "this renders as a fully transparent PNG: the texture "
                                "loads, the sprite node is there, the screen is empty"))
    elif painted == 0:
        findings.append(Finding(ERROR, "content", stem,
                                "%d shape(s), none of them painted" % len(shapes),
                                "every fill and stroke resolves to none"))

    # ---- centred / margin ----------------------------------------------
    res.geometry_ok = geometry_ok and not content.empty()
    if res.geometry_ok:
        res.box = content
        if w:
            mid = (content.x0 + content.x1) * 0.5
            off = abs(mid - w * 0.5)
            if off > CENTRE_ERROR:
                findings.append(Finding(
                    ERROR, "centred", stem,
                    "content midline is x=%.2f, canvas centre is %.1f (off by %.2f)"
                    % (mid, w * 0.5, off),
                    "the kit's units are symmetric about their vertical axis; an "
                    "off-centre sprite rotates about the wrong point the moment "
                    "anything aims. The raster gate's tolerance is %.1fpx" % CENTRE_ERROR))
            elif off > CENTRE_WARN:
                findings.append(Finding(
                    WARNING, "centred", stem,
                    "content midline is x=%.2f, off centre by %.2f" % (mid, off),
                    "inside the raster gate's %.1fpx tolerance, but only just"
                    % CENTRE_ERROR))
            margin = min(content.x0, content.y0, w - content.x1, h - content.y1)
            if margin < 0.0:
                findings.append(Finding(
                    ERROR, "margin", stem,
                    "content runs %.2fpx past the canvas edge (box %.2f,%.2f..%.2f,%.2f "
                    "in %gx%g)" % (-margin, content.x0, content.y0, content.x1,
                                   content.y1, w, h),
                    "clipping shows up as a flat cut on one side that reads as a "
                    "rendering bug rather than a drawing mistake"))
            elif margin < MARGIN_WARN:
                findings.append(Finding(
                    WARNING, "margin", stem,
                    "only %.2fpx of margin (box %.2f,%.2f..%.2f,%.2f in %gx%g)"
                    % (margin, content.x0, content.y0, content.x1, content.y1, w, h),
                    "the raster gate wants a clear 1px border of transparent pixels"))
    else:
        res.skipped.append("centred + margin (geometry could not be measured exactly)")

    return res


def check_palette(stem, rgb, where, contract, palette_rgb, findings):
    key = to_hex(rgb)[1:]
    if key in contract.palette:
        return
    dist = distance_to_palette_blend(rgb, palette_rgb)
    if dist <= BLEND_TOLERANCE:
        findings.append(Finding(
            WARNING, "palette", stem,
            "%s is not a kit colour (%.2f from the nearest palette blend)"
            % (to_hex(rgb), dist),
            "close enough that the raster gate's %.1f tolerance will pass it, but "
            "STYLE.md says use the palette verbatim. %s" % (BLEND_TOLERANCE, where)))
    else:
        findings.append(Finding(
            ERROR, "palette", stem,
            "%s is off the kit palette by %.2f (tolerance %.1f)"
            % (to_hex(rgb), dist, BLEND_TOLERANCE),
            where))


def check_outline(stem, fill, stroke, where, contract, findings):
    """STYLE.md: 'outline = darker shade of the fill'; 'no black, no grey outlines --
    every rim is the object's own hue, darkened'."""
    if fill == stroke:
        return
    fill_key = to_hex(fill)[1:]
    stroke_key = to_hex(stroke)[1:]

    if luminance(stroke) >= luminance(fill):
        findings.append(Finding(
            ERROR, "outline", stem,
            "outline %s is not darker than its fill %s" % (to_hex(stroke), to_hex(fill)),
            "STYLE.md: outline = darker shade of the fill. A lighter rim reads as a "
            "glow, and the kit has none. %s" % where))
        return

    if stroke == (0, 0, 0):
        findings.append(Finding(
            ERROR, "outline", stem, "outline is pure black",
            "STYLE.md: no black, no grey outlines -- every rim is the object's own "
            "hue, darkened. %s" % where))
        return

    fill_grey = saturation(fill) < GREY_SATURATION
    stroke_grey = saturation(stroke) < GREY_SATURATION
    if stroke_grey and not fill_grey:
        findings.append(Finding(
            ERROR, "outline", stem,
            "outline %s is grey on a coloured fill %s" % (to_hex(stroke), to_hex(fill)),
            "STYLE.md: no black, no grey outlines. %s" % where))
        return
    if fill_grey and stroke_grey:
        return   # a grey object's own hue, darkened, is grey

    def named(key, rgb):
        fam = contract.family_of.get(key)
        return "%s (%s)" % (to_hex(rgb), fam) if fam else to_hex(rgb)

    if fill_grey != stroke_grey:
        findings.append(Finding(
            WARNING, "outline", stem,
            "outline %s rims a %s fill" % (named(stroke_key, stroke),
                                           "grey" if fill_grey else "coloured"),
            "STYLE.md: every rim is the object's own hue, darkened. %s" % where))
        return

    d = hue_distance(hue(fill), hue(stroke))
    if d > HUE_TOLERANCE:
        findings.append(Finding(
            WARNING, "outline", stem,
            "outline %s rims a %s fill -- %.1f degrees of hue apart"
            % (named(stroke_key, stroke), named(fill_key, fill), d),
            "STYLE.md: every rim is the object's own hue, darkened. Across this corpus "
            "the worst legitimate rim/fill pair differs by 0.7 degrees. %s" % where))


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

SEV_ORDER = {ERROR: 0, WARNING: 1, ADVISORY: 2}


def wrap_detail(text, indent):
    out = []
    line = ""
    for word in text.split():
        if line and len(line) + 1 + len(word) > 92 - len(indent):
            out.append(indent + line)
            line = word
        else:
            line = word if not line else line + " " + word
    if line:
        out.append(indent + line)
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(
        prog="svg_style_check.py",
        description="Check art_src/*.svg against art_src/STYLE.md without a renderer. "
                    "Pure stdlib, opens no Godot project, safe to run in parallel.",
        epilog="exit 0 clean | 1 findings that gate | 2 could not run")
    ap.add_argument("-p", "--project", default=".",
                    help="project root holding art_src/ (default: .)")
    ap.add_argument("--only", metavar="NAME",
                    help="only sprites whose stem contains NAME")
    ap.add_argument("--strict", action="store_true",
                    help="warnings gate as well as errors")
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    ap.add_argument("--quiet", action="store_true",
                    help="findings and totals only, no per-sprite table")
    args = ap.parse_args(argv)

    root = os.path.abspath(args.project)
    src = os.path.join(root, SRC_DIR)
    if not os.path.isdir(src):
        print("COULD NOT RUN: no %s under %s" % (SRC_DIR, root), file=sys.stderr)
        return 2

    try:
        contract = load_contract(root)
    except (RuntimeError, OSError) as exc:
        print("COULD NOT RUN: %s" % exc, file=sys.stderr)
        return 2

    names = sorted(f for f in os.listdir(src) if f.lower().endswith(".svg"))
    if not names:
        print("COULD NOT RUN: no .svg files in %s" % SRC_DIR, file=sys.stderr)
        return 2
    discovered = len(names)
    if args.only:
        names = [n for n in names if args.only in os.path.splitext(n)[0]]
        if not names:
            print("COULD NOT RUN: --only %s selected nothing of %d discovered"
                  % (args.only, discovered), file=sys.stderr)
            return 2

    findings = []
    results = []
    for name in names:
        stem = os.path.splitext(name)[0]
        results.append(check_sprite(os.path.join(src, name), stem, contract, findings))

    # A gate row with no source is the mirror of an undeclared sprite: the gate will look
    # for a PNG nothing renders. Only meaningful over the full set.
    if not args.only:
        stems = {r.stem for r in results}
        for declared in sorted(contract.sizes):
            if declared not in stems:
                findings.append(Finding(
                    ERROR, "declared", declared,
                    "EXPECTED_SIZE declares it but there is no %s/%s.svg"
                    % (SRC_DIR, declared),
                    "the raster gate will look for a PNG that nothing renders"))

    for note in contract.notes:
        findings.append(Finding(ADVISORY, "palette", "(contract)", note))

    errors = [f for f in findings if f.severity == ERROR]
    warnings = [f for f in findings if f.severity == WARNING]
    advisory = [f for f in findings if f.severity == ADVISORY]

    if args.json:
        print(json.dumps({
            "findings": [f.as_dict() for f in findings],
            "errors": len(errors), "warnings": len(warnings), "advisory": len(advisory),
            "sprites": [{
                "stem": r.stem,
                "size": r.size,
                "box": None if not r.box else [r.box.x0, r.box.y0, r.box.x1, r.box.y1],
                "geometry_measured": r.geometry_ok,
                "skipped": r.skipped,
            } for r in results],
            "checked": len(results), "discovered": discovered,
        }, indent=2))
    else:
        report(results, findings, contract, discovered, args)

    if errors:
        return 1
    if args.strict and warnings:
        return 1
    return 0


def report(results, findings, contract, discovered, args):
    print("svg_style_check: %s against %s" % (SRC_DIR, STYLE_DOC))
    print()
    print("contract sources (nothing below is declared in this file):")
    print("  canvas sizes   %-34s EXPECTED_SIZE, %d entr%s"
          % (GATE_SCRIPT, len(contract.sizes),
             "y" if len(contract.sizes) == 1 else "ies"))
    print("  palette        %-34s PALETTE, %d colour(s)"
          % (GATE_SCRIPT, len(contract.palette)))
    print("  families       %-34s palette table, %d famil%s"
          % (STYLE_DOC, len(contract.families),
             "y" if len(contract.families) == 1 else "ies"))
    print()

    if not args.quiet:
        for r in sorted(results, key=lambda r: r.stem):
            sev = "ok  "
            for f in findings:
                if f.sprite == r.stem and f.severity == ERROR:
                    sev = "ERR "
                    break
            else:
                for f in findings:
                    if f.sprite == r.stem and f.severity == WARNING:
                        sev = "warn"
                        break
            size = "%gx%g" % r.size if r.size else "  ?  "
            if r.box and r.size:
                w = r.size[0]
                mid = (r.box.x0 + r.box.x1) * 0.5
                margin = min(r.box.x0, r.box.y0, w - r.box.x1, r.size[1] - r.box.y1)
                geo = ("content %5.2f..%5.2f x %5.2f..%5.2f  mid %6.2f  margin %5.2f"
                       % (r.box.x0, r.box.x1, r.box.y0, r.box.y1, mid, margin))
            else:
                geo = "geometry not measured"
            print("  %s %-26s %-7s %s" % (sev, r.stem, size, geo))
        print()

    for sev in (ERROR, WARNING, ADVISORY):
        rows = [f for f in findings if f.severity == sev]
        if not rows:
            continue
        for f in sorted(rows, key=lambda f: (f.sprite, f.check)):
            print("  %-9s %-15s %s: %s" % (sev.upper(), f.check, f.sprite, f.message))
            if f.detail:
                for line in wrap_detail(f.detail, " " * 12):
                    print(line)
        print()

    by_check = {c: 0 for c in CHECKS}
    for f in findings:
        if f.check in by_check:
            by_check[f.check] += 1
    print("By check:  " + "  ".join("%s %d" % (c, by_check[c]) for c in CHECKS))

    skipped = []
    for r in results:
        for s in r.skipped:
            skipped.append("%s: %s" % (r.stem, s))
    print("Checked:   %d of %d sprite(s) discovered | %d check(s) run per sprite"
          % (len(results), discovered, len(CHECKS)))
    errors = sum(1 for f in findings if f.severity == ERROR)
    warns = sum(1 for f in findings if f.severity == WARNING)
    advs = sum(1 for f in findings if f.severity == ADVISORY)
    print("Findings:  %d error(s), %d warning(s), %d advisory" % (errors, warns, advs))
    if skipped:
        print("Skipped:")
        for s in skipped:
            print("  " + s)
    print("NOT COVERED by this tool, and only the raster gate can answer them:")
    print("  retina copy    render_svg.gd writes the @2x pair; the source never declares it")
    print("  blank render   source is checked for drawable painted geometry, not for what")
    print("                 the rasteriser actually produced")
    print("  AA junctions   where three hues meet in one pixel the blend is on no")
    print("                 two-colour segment and fails the palette test even though")
    print("                 every declared colour here was clean. Requires rasterising.")
    print("  A clean run here means the SOURCE conforms. Run test_sprite_style.gd for the")
    print("  rendered truth.")


if __name__ == "__main__":
    sys.exit(main())
