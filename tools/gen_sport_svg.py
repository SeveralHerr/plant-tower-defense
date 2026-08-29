#!/usr/bin/env python3
"""gen_sport_svg.py - derive every `art_src/<plant>_sport.svg` from its parent, and
check that the committed ones are still what the derivation produces.

A sport (`PlantMutation`) is what a plant becomes when two of its kind throw one into
the cell beside them. Until this tool it wore its parent's own sprite with a 12% violet
multiplied into `modulate`, which is a cue you can only read by holding a sport next to
its own parent. The fix is its own art -- but "its own art" for nine plants is seventeen
drawings once the frame-swapping kinds are counted (Bramble x3, Chomp x4, Dandelion x4),
and seventeen hand-drawn recolours is seventeen chances to drift from `art_src/STYLE.md`
in a way only a rasteriser several minutes later would notice.

So the mutant art is DERIVED, not drawn. Geometry is copied byte for byte and only paint
is remapped, which buys every geometric clause of the contract for free: canvas size,
retina doubling, bilateral centring and in-canvas bounds all hold for the sport exactly
because they hold for the parent. What is left to get right is colour, and colour is what
this file is.

---------------------------------------------------------------------------
WHICH GATE WOULD HAVE CAUGHT THIS, AND WHY IT DOES NOT

`--check` is a house checker in the sense `.claude/skills/house-static-checker` means it,
so it owes that paragraph. The defect class is "a committed `_sport.svg` no longer matches
the parent it claims to be derived from" -- a leaf edited by hand, or a parent edited and
its sport left behind. `test_sprite_style.gd` holds every sprite to STYLE.md, so it would
still pass: a hand-edited sport that used palette colours correctly is a perfectly
conformant sprite. It has no idea the file was supposed to be a function of another file.
`svg_style_check.py` has the same blind spot for the same reason. Nothing else in the repo
reads two SVGs and compares them, so without this the derivation is a claim in a docstring.

---------------------------------------------------------------------------
THE COLOUR RULE

Two mutant ramps, picked by the SOURCE colour's hue:

  * hue in [60, 200) -- the kit's foliage greens (145 degrees) and its blue-greys (184) --
    becomes TOXIC, an acid yellow-green at hue 78.
  * everything else -- gold (48), sand (42), dirt (30), orange (25), red (6) -- becomes
    MUTAGEN, a hot magenta at hue 310.
  * achromatic paint is left exactly alone. The Chomp Flower's teeth are the only grey in
    any plant sprite and they are bone; a mutation recolours living tissue.

The split is at 60 rather than at "warm/cool" because gold sits at 48 degrees and has to
land with the reds it shares a sprite with, not with the leaves behind it. Every fill and
its own stroke in every plant sprite is a same-family pair, which is not a coincidence --
`svg_style_check.check_outline` already refuses a stroke more than HUE_TOLERANCE from the
fill it outlines, so a cross-family pair could not have shipped. That is what makes a
per-family remap safe: a pair that was legal before is a pair inside one ramp after.

WITHIN a ramp, a sprite's own distinct colours of that family are sorted by luminance and
spread across the ramp's anchors by their normalised position in that range, pushed apart
where two land on the same anchor. Three consequences, and each is load-bearing:

  * ORDER IS PRESERVED. The map is monotone in luminance and the ramp is monotone in
    luminance, so a stroke darker than its fill before is darker than its fill after --
    which is the whole of the outline contract.
  * NOTHING COLLAPSES. n distinct colours get n distinct anchors, so a detail drawn as one
    shade against another is still two shades. A rank-collapsing map would have quietly
    flattened the Chomp's maw, which is three reds deep.
  * EVERY EMITTED COLOUR IS A RAMP ANCHOR, i.e. a literal palette entry. That matters for
    the palette gate specifically: it accepts a pixel within BLEND_TOLERANCE of the segment
    between two palette entries, so an anti-aliased edge between two anchors lands on a
    palette-pair segment exactly as the parent's edges do. Emitting interpolated colours
    would have put every feathered edge in the sprite off every segment at once.

The anchors themselves are constant-hue by construction (`_ramp` derives the third channel
from the other two), so the spread within a family is a spread in VALUE, never in hue --
which is why the outline check's hue clause survives a remap it knows nothing about.

The ramps are the source of truth for `MUTANT_PALETTE` in `test/unit/test_sprite_style.gd`;
`--palette` prints that block rather than leaving it to be retyped.

---------------------------------------------------------------------------
WHY REGEX AND NOT ElementTree

Structure is never matched here -- only `#rrggbb` tokens are, and only after `<!-- -->`
spans have been blanked, so a hex quoted in a comment about the PARENT's palette is not
rewritten into a lie about the sport's. Re-serialising through ElementTree would drop
every comment in the file and reflow the rest, which turns a reviewable one-line-per-shape
diff into a whole-file rewrite. The discipline is the one
`.claude/skills/house-static-checker` states for tools that need both views: spans come
from the blanked text, and the substitution is applied to the raw text at those offsets.
"""

import argparse
import os
import re
import sys

# --------------------------------------------------------------------------
# Layout
# --------------------------------------------------------------------------

SRC_DIR = os.path.join("art_src")
GAME_DIR = os.path.join("game")
CATALOG = os.path.join("game", "plant_catalog.gd")

## The suffix that makes a stem a sport. Also what `PlantMutation.sport_texture_path`
## appends, and what `test_sprite_style.gd` keys MUTANT_PALETTE off -- one spelling, three
## readers, so it is named here and asserted there rather than typed three times.
SPORT_SUFFIX = "_sport"

SPRITE_RE = re.compile(r'res://assets/sprites/([A-Za-z0-9_]+)\.png')
HEX_RE = re.compile(r"#([0-9A-Fa-f]{6})\b")
COMMENT_RE = re.compile(r"<!--.*?-->", re.S)

BANNER = (
    "  <!-- GENERATED by tools/gen_sport_svg.py from %s. Do not edit by hand:\n"
    "       `python tools/gen_sport_svg.py --check` fails on any edit this file's\n"
    "       parent does not explain. Geometry is copied verbatim; only paint moves. -->\n"
)


# --------------------------------------------------------------------------
# Colour
# --------------------------------------------------------------------------

def parse_hex(text):
    return (int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16))


def to_hex(rgb):
    return "%02X%02X%02X" % rgb


def luminance(rgb):
    """Rec.709 relative luminance on 0..255. The quantity the outline contract is
    actually about -- `svg_style_check.check_outline` asks whether a stroke is DARKER
    than its fill, and this is the number that answers it."""
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]


def saturation(rgb):
    hi, lo = max(rgb), min(rgb)
    return 0.0 if hi == 0 else (hi - lo) / float(hi)


def hue(rgb):
    """HSV hue in degrees, or None for achromatic paint."""
    r, g, b = rgb
    hi, lo = max(rgb), min(rgb)
    delta = hi - lo
    if delta == 0:
        return None
    if hi == r:
        h = 60.0 * (((g - b) / float(delta)) % 6.0)
    elif hi == g:
        h = 60.0 * (((b - r) / float(delta)) + 2.0)
    else:
        h = 60.0 * (((r - g) / float(delta)) + 4.0)
    return h % 360.0


## Below this, paint is grey and gets no ramp. Same threshold `svg_style_check.py` uses to
## decide a colour has no meaningful hue, and for the same reason: hue of a near-grey is
## numerically wild, so bucketing on it would send the Chomp's white teeth somewhere.
GREY_SATURATION = 0.12

## The hue window that means "the plant's own living green", widened to take the kit's
## blue-greys with it. See the module docstring for why the low edge is 60 and not 90.
TOXIC_HUE_LO = 60.0
TOXIC_HUE_HI = 200.0

TOXIC = "toxic"
MUTAGEN = "mutagen"


def family_of(rgb):
    """Which ramp this source colour goes to, or None to leave it alone."""
    if saturation(rgb) < GREY_SATURATION:
        return None
    h = hue(rgb)
    if h is None:
        return None
    return TOXIC if TOXIC_HUE_LO <= h < TOXIC_HUE_HI else MUTAGEN


def _ramp_green(g, b):
    """An anchor on the toxic ramp: R is derived so the hue is 78 degrees regardless of
    how light the anchor is. hue = 60 * (2 + (B-R)/(G-B)), so R = B + 0.7*(G-B) puts it
    at 60 * 1.3 = 78. Deriving rather than typing is what keeps the eight anchors within
    half a degree of each other, which is what lets `check_outline`'s hue clause pass for
    any two of them."""
    return (int(round(b + 0.7 * (g - b))), g, b)


def _ramp_magenta(r, g):
    """An anchor on the mutagen ramp: B derived so the hue is 310 degrees.
    hue = 60 * (6 + (G-B)/(R-G)), so B = G + 0.8333*(R-G) puts it at 60 * 5.1667."""
    return (r, g, int(round(g + (5.0 / 6.0) * (r - g))))


## Eight anchors per ramp, monotone in luminance and spanning the full range a sprite can
## use. Eight because the Barrier Bramble carries eight distinct warm colours in one
## drawing and nothing may collapse -- `--check` fails loudly rather than flattening a
## sprite that outgrows the ramp, which is the failure a tenth plant would hit.
RAMPS = {
    TOXIC: [_ramp_green(g, b) for g, b in
            [(58, 5), (90, 8), (122, 11), (154, 14), (186, 18), (214, 24), (236, 90),
             (252, 182)]],
    MUTAGEN: [_ramp_magenta(r, g) for r, g in
              [(70, 6), (105, 8), (145, 12), (185, 26), (222, 52), (245, 110), (252, 176),
               (255, 232)]],
}


def assign(colours, slots):
    """colour -> ramp index, for the colours of ONE family in ONE sprite.

    `colours` arrives as (luminance, hex) pairs, sorted. The index each one WANTS is its
    normalised luminance position in that sprite's own range, so a family whose shades are
    bunched dark stays bunched dark rather than being fanned out evenly across the ramp.

    Two passes then make the result usable, and both are needed. Forward guarantees the
    indices strictly increase, which is the property the outline contract rests on.
    Backward pulls the tail back inside the ramp when forward overran it: the last index
    is clamped to the ramp's end and every earlier one is pushed below its successor. The
    Corn Cobbler is the case that needs it -- its five warm shades want 0,3,6,6,7, forward
    makes that 0,3,6,7,8, and eight slots stop at 7; the backward pass lands them on
    0,3,5,6,7. Spreading by RANK instead would never overflow, but it would also throw
    away the fact that four of those five shades are light, which is most of what makes
    the drawing read as a cob.

    The two passes cannot fail while n <= slots: forward leaves idx[i] >= i, backward
    leaves idx[i] <= slots - 1 - (n - 1 - i), and those brackets are non-empty exactly
    when n <= slots -- which the caller has already checked.
    """
    n = len(colours)
    if n > slots:
        raise ValueError("%d colour(s) for %d ramp slot(s)" % (n, slots))
    if n == 0:
        return {}
    if n == 1:
        return {colours[0][1]: slots // 2}
    lo, hi = colours[0][0], colours[-1][0]
    span = hi - lo
    idx = []
    for lum, _hex in colours:
        pos = 0.0 if span <= 0 else (lum - lo) / span
        idx.append(int(pos * (slots - 1) + 0.5))
    for i in range(1, n):
        if idx[i] <= idx[i - 1]:
            idx[i] = idx[i - 1] + 1
    idx[-1] = min(idx[-1], slots - 1)
    for i in range(n - 2, -1, -1):
        if idx[i] >= idx[i + 1]:
            idx[i] = idx[i + 1] - 1
    if idx[0] < 0:
        raise ValueError("ramp of %d slot(s) cannot seat %d colour(s)" % (slots, n))
    return {colours[i][1]: idx[i] for i in range(n)}


def mutate_map(hexes):
    """source hex (upper, no '#') -> mutant hex, for every colour in one sprite.

    Achromatic paint maps to itself, which keeps it out of the ramps AND out of the
    per-family counts -- eight slots is eight coloured shades, not eight tokens.
    """
    by_family = {TOXIC: [], MUTAGEN: []}
    out = {}
    for h in sorted(set(hexes)):
        rgb = parse_hex(h)
        fam = family_of(rgb)
        if fam is None:
            out[h] = h
            continue
        by_family[fam].append((luminance(rgb), h))
    for fam, members in by_family.items():
        members.sort()
        ramp = RAMPS[fam]
        for h, i in assign(members, len(ramp)).items():
            out[h] = to_hex(ramp[i])
    return out


# --------------------------------------------------------------------------
# Which sprites are a plant's
# --------------------------------------------------------------------------

def read_text(path):
    with open(path, "r", encoding="utf-8") as fh:
        return fh.read()


def blank_comments(text):
    """The same text with every `<!-- -->` span replaced by spaces of equal length.

    Equal length on purpose: every offset in the returned string is the same offset in
    the original, which is what lets a match found here be applied there.
    """
    return COMMENT_RE.sub(lambda m: " " * len(m.group(0)), text)


def plant_stems(root):
    """Every sprite stem a PLANT wears, derived rather than listed.

    The catalogue's `texture` gives the nine standing drawings; each plant SCRIPT gives
    the frames that plant swaps to (`Bramble.DAMAGE_TEXTURES`, `Dandelion.FLUFF_TEXTURES`,
    `ChompFlower`'s three eating frames). A plant script is one that `extends Plant`, so a
    tenth plant is picked up by existing here rather than by being added to a list --
    which is the point: a hand-kept list of seventeen stems is the thing this tool exists
    to not have. Projectiles are excluded by construction, since `corn_kernel.png` is
    named in `kernel.gd` and `dandelion_seed.png` in the seed's own script, neither of
    which extends Plant.
    """
    stems = set()
    catalog = os.path.join(root, CATALOG)
    if not os.path.isfile(catalog):
        raise RuntimeError("no %s -- the nine plant textures are named there" % CATALOG)
    stems.update(SPRITE_RE.findall(read_text(catalog)))
    game = os.path.join(root, GAME_DIR)
    if not os.path.isdir(game):
        raise RuntimeError("no %s/ -- the frame-swapping plants' scripts live there" % GAME_DIR)
    scripts = 0
    for name in sorted(os.listdir(game)):
        if not name.endswith(".gd"):
            continue
        text = read_text(os.path.join(game, name))
        if not re.search(r"^extends Plant\s*$", text, re.M):
            continue
        scripts += 1
        stems.update(SPRITE_RE.findall(text))
    if not stems:
        raise RuntimeError("found no plant sprite path in %s or %s/" % (CATALOG, GAME_DIR))
    return sorted(s for s in stems if not s.endswith(SPORT_SUFFIX)), scripts


# --------------------------------------------------------------------------
# Generation
# --------------------------------------------------------------------------

def derive(source_text, parent_name):
    """The sport SVG for one parent, and the map it used.

    Substitution runs right-to-left over spans found in the BLANKED text, so applying one
    never moves the offsets of the ones not yet applied and a hex inside a comment is
    never touched.
    """
    masked = blank_comments(source_text)
    spans = [(m.start(1), m.end(1), m.group(1).upper()) for m in HEX_RE.finditer(masked)]
    mapping = mutate_map([s[2] for s in spans])
    out = source_text
    for start, end, h in reversed(spans):
        out = out[:start] + mapping[h] + out[end:]
    banner = BANNER % (parent_name)
    at = out.find(">", out.find("<svg"))
    if at < 0:
        raise RuntimeError("%s has no <svg> element" % parent_name)
    out = out[:at + 1] + "\n" + banner.rstrip("\n") + out[at + 1:]
    changed = {k: v for k, v in mapping.items() if k != v}
    return out, changed


def palette_block():
    """The MUTANT_PALETTE const block for test/unit/test_sprite_style.gd."""
    lines = ["const MUTANT_PALETTE: PackedStringArray = ["]
    for fam in (TOXIC, MUTAGEN):
        row = ", ".join('"%s"' % to_hex(c) for c in RAMPS[fam])
        lines.append("\t%s," % row)
    lines.append("]")
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="project root (default: .)")
    ap.add_argument("--check", action="store_true",
                    help="do not write; exit 1 if a committed sport SVG differs")
    ap.add_argument("--palette", action="store_true",
                    help="print the MUTANT_PALETTE const block and exit")
    args = ap.parse_args(argv)

    if args.palette:
        print(palette_block())
        return 0

    root = args.root
    try:
        stems, scripts = plant_stems(root)
    except RuntimeError as exc:
        print("gen_sport_svg: could not run -- %s" % exc)
        return 2

    src = os.path.join(root, SRC_DIR)
    if not os.path.isdir(src):
        print("gen_sport_svg: could not run -- no %s/" % SRC_DIR)
        return 2

    findings = []
    written = 0
    remapped = 0
    missing = 0
    for stem in stems:
        parent = os.path.join(src, "%s.svg" % stem)
        if not os.path.isfile(parent):
            missing += 1
            findings.append(
                "FINDING: %s names res://assets/sprites/%s.png but %s/%s.svg does not exist\n"
                "  fix: draw the source, or stop naming a sprite that has none.\n"
                "  waive: none -- a sprite with no source cannot have a derived sport."
                % (CATALOG, stem, SRC_DIR, stem))
            continue
        dest_name = "%s%s.svg" % (stem, SPORT_SUFFIX)
        dest = os.path.join(src, dest_name)
        try:
            text, changed = derive(read_text(parent), "%s.svg" % stem)
        except (ValueError, RuntimeError) as exc:
            findings.append(
                "FINDING: %s/%s.svg cannot be derived -- %s\n"
                "  fix: widen the ramp in RAMPS (both ramps stay the same length), or\n"
                "       reduce the sprite to as many shades per family as the ramp seats.\n"
                "  waive: none -- collapsing two shades into one is the defect."
                % (SRC_DIR, stem, exc))
            continue
        remapped += len(changed)
        current = read_text(dest) if os.path.isfile(dest) else None
        if current == text:
            continue
        if args.check:
            why = "does not exist" if current is None else "differs from its parent's derivation"
            findings.append(
                "FINDING: %s/%s %s\n"
                "  fix: run `python tools/gen_sport_svg.py`, then re-render with\n"
                "       `godot --headless --path . --script res://tools/render_svg.gd`.\n"
                "  waive: none -- a sport is a function of its parent or it is not derived."
                % (SRC_DIR, dest_name, why))
            continue
        with open(dest, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        written += 1

    print("gen_sport_svg: %d plant sprite stem(s) from %s and %d plant script(s), "
          "%d colour substitution(s), %d written, %d finding(s)"
          % (len(stems), CATALOG, scripts, remapped, written, len(findings)))
    if not stems:
        print("NOTE: nothing to check -- no plant sprite stem was derived. That is a clean\n"
              "      result only if this project has no plants.")
    print("NOT COVERED: this reads SVG text, not rendered pixels. It cannot see whether the\n"
          "             mutant colours are legible against the board they land on, nor\n"
          "             whether Godot's rasteriser agrees with the geometry it copied --\n"
          "             test_sprite_style.gd reads the PNGs and is the gate for both. It\n"
          "             does not compile anything; only import_check.py and lint_project.gd\n"
          "             do that, and neither is parallel-safe.")
    for f in findings:
        print(f)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
