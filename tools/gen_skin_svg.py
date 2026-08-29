#!/usr/bin/env python3
r"""gen_skin_svg.py - derive every `art_src/<plant>_skin_<family>.svg` from its parent,
and check that the committed ones are still what the derivation produces.

A SKIN is what a plant wears when the player has bought one in the Petal shop. Skins
began life as a `modulate` tint, which is a cue that survives exactly as long as nobody
looks at two of them side by side: a tint multiplies a hue over art already carrying its
own, and three deliberate families come out as one muddy one. So a skin is a DRAWING --
its own SVG, its own PNG, rendered by `tools/render_svg.gd` like everything else.

Seventeen plant frames times three families is fifty-one drawings, which is fifty-one
chances to drift from `art_src/STYLE.md` in a way only a rasteriser several minutes later
would notice. So they are DERIVED, exactly as `tools/gen_sport_svg.py` derives the mutant
sports, and this file is that tool's sibling. Read it first; the colour rule, the
regex-not-ElementTree discipline and the check-by-default contract are all argued there
and only the differences are argued here.

TWO CHANGES TO THE PARENT, AND THE SECOND IS THE POINT
------------------------------------------------------
A sport is its parent's geometry byte for byte with only the paint moved, and that single
decision buys every geometric clause of the contract for free. A skin cannot make that
trade, because a recolour is precisely what the feature is NOT: the user asked for skins
that are more than recoloured sprites, so a skin has to change the silhouette.

  1. PAINT is remapped onto the family's eight-rung ramp -- luminance-nearest,
     order-preserving, nothing collapsing, achromatic paint untouched. Identical rule to
     `gen_sport_svg.mutate_map`, and it reuses that file's `assign()` rather than
     restating it. One difference: a sport splits its colours across TWO ramps by hue and
     a skin puts all of them on ONE, so the ramp has to seat every chromatic shade in the
     drawing at once. The widest plant (Corn Cobbler, Sunflower, the Chomp's late eating
     frame) carries eight, which is why the ramps are eight rungs and not six.

  2. A family MOTIF is appended as real geometry, in a single `<g>` before `</svg>`,
     drawn in that family's own ramp anchors. Because the motif is APPENDED after the
     substitution pass, its anchors are never themselves remapped -- they are already
     ramp entries, and running them through the map would push the sprite's colour count
     past eight for no gain.

     Every motif is mirror-symmetric about x = 32 and lives inside x, y in [3, 61].
     Neither is taste. `test_content_is_bilaterally_centred` allows 1.0 px of midline
     error and `test_content_stays_inside_the_canvas` wants a 1 px transparent margin on
     all four sides; a motif drawn freehand fails both, and it fails them fifty-one times
     at once. Mirroring about x = 32 is what makes the first free: a shape at SVG x = u is
     matched by one at 64 - u, pixel column c by column 63 - c, so the union bounding box
     is symmetric and its midline is exactly 32 whatever the parent's bounds were.

     The motifs also have to sit in tile margins the parents leave EMPTY, or the skin
     buries the plant it is decorating. Those margins were measured, not guessed: the
     opaque coverage of all seventeen rendered parents was unioned and the free rows are
     y <= 5 and y >= 58 at full width, x <= 5 and x >= 58 at full height, plus both top
     corners out to about (14, 15). Every motif below is placed against that map, and the
     places it deliberately overlaps (the crown's band clipping the Sunflower's topmost
     petal, the frost crystal resting on the Chomp's head) are the two or three parents
     that reach highest, by design -- an ornament that never touches the plant is an
     ornament floating beside it.

---------------------------------------------------------------------------
WHICH GATE WOULD HAVE CAUGHT THIS, AND WHY IT DOES NOT

This is a house checker in the sense `.claude/skills/house-static-checker` means it, so
it owes that paragraph. The defect class is "a committed `_skin_*.svg` is no longer the
function of its parent and its family ramp that it claims to be" -- a leaf hand-edited, a
parent edited and its three skins left behind, a motif nudged off the midline, or a
fifty-second skin file for a family that does not exist.

`test_sprite_style.gd` holds every sprite to STYLE.md, so a hand-edited skin that used
legal ramp colours passes it: the raster gate has no idea the file was supposed to be a
function of another file. `tools/svg_style_check.py` has the same blind spot for the same
reason. `gen_sport_svg.py` reads parents and sports and would not look at a skin at all.
Nothing else in the repo compares two SVGs, so without this the derivation is a claim in a
docstring.

The one thing this adds over its sibling: it also fails on an EXTRA file. A stray
`art_src/foo_skin_gilt.svg` would be picked up by the gate's `_declared()` derivation,
which grants it its parent's canvas row, so "which generated files may exist" has to be
somebody's question and it is this one's.

---------------------------------------------------------------------------
THE RAMPS

Three, eight rungs each, one hue apiece: golden 45 degrees, frost 200, ember 15. Each
anchor derives its THIRD channel from the other two so the whole ramp sits at one hue --
`_warm_anchor` and `_cool_anchor` below -- which is what lets `check_outline`'s hue clause
("every rim is the object's own hue, darkened") survive a remap that knows nothing about
it. The spread within a family is a spread in VALUE, never in hue.

Both end rungs stop short of white and black, and the pale end is the constraint that
matters: `svg_style_check.check_outline` warns when a saturated stroke rims a GREY fill
and it decides grey at saturation 0.12. The mutant ramp's first draft put its top anchor
at saturation 0.090 and drew that warning on five shapes of the Aloe at once. Every top
anchor here sits at 0.26 or above.

The ramps are the source of truth for `SKIN_PALETTES` in `test/unit/test_sprite_style.gd`;
`--palette` prints that block rather than leaving it to be retyped, and a bare run fails
when the two disagree, in both directions.

---------------------------------------------------------------------------
WHY REGEX AND NOT ElementTree

Same discipline as `gen_sport_svg.py`, and the same reasons: structure is never matched,
only `#rrggbb` tokens are, and only after `<!-- -->` spans have been blanked so a hex
quoted in a comment about the PARENT's palette is not rewritten into a lie about the
skin's. Spans come from the blanked text; the substitution is applied to the raw text at
those offsets, right to left, so applying one never moves the ones not yet applied.

Note the hard constraint on the banner: XML forbids `--` inside a comment, so no double
hyphen appears in any generated text. Godot's SVG loader accepts a malformed one happily;
`svg_style_check.py` parses with ElementTree and refuses it. That disagreement is what
found the bug the first time.

---------------------------------------------------------------------------
fixture:   `python tools/gen_skin_svg.py --fixture`. KEPT, not written and deleted --
           the mutations below are what you re-run after every edit to this file.
           Builds a miniature project in a temp dir (a catalogue, a plant script, a
           gate with SKIN_PALETTES, one parent SVG and its three derived skins) and
           asserts WHICH findings come back, not how many. Cases 1-6: three missing
           skins / a freshly written tree is clean / one skin hand-edited, named and
           its siblings not / an extra skin for a family nobody declared / a gate block
           that disagrees with the ramps / no gate block at all is COULD NOT RUN.
           Cases 7-8 test the two TRANSFORMS on hand-written inputs, and they are the
           point: everything in 1-6 is self-consistency (the fixture writes with this
           code and compares with this code), so a derivation that is uniformly WRONG
           agrees with itself and passes all six.
mutations: 5, all RED, measured 2026-08-29; baseline and restore both 0 failure(s).
           `if current == text: continue` -> `if True: continue`
                                             -> RED, 5 named failures. Case 2 reports
                                                three unwritten files and case 3 names
                                                the write that never happened, rather
                                                than dying in a FileNotFoundError --
                                                which is the guard that keeps "did not
                                                apply" and "survived" from looking the
                                                same
           `to_hex(ramp[i])` -> `to_hex(ramp[0])`
                                             -> RED on case 8 only, three times: "golden
                                                collapsed 4 shades into 1". SURVIVED
                                                every one of cases 1-6, which is why
                                                cases 7 and 8 exist at all
           drop the extra-file scan          -> RED, naming "an unknown-family file was
                                                accepted"; the finding COUNT also moves,
                                                which is why the assertion is by name
           `gate != ramp_block()` -> `gate == ...`
                                             -> RED, naming the desync case
           `_warm_anchor`'s `(hue_deg / 60.0)` -> a flat `0.5`
                                             -> RED, 16 named failures: "golden anchor
                                                #462504 sits at hue 30.0, not 45". This
                                                one exists because the hue is otherwise
                                                only ever WRITTEN, never read back -- a
                                                constant used once in a construction is a
                                                constant nothing can check
"""

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# The sibling this file is a variant of. Imported, never copied: `plant_stems` is the
# derivation of WHICH seventeen stems exist (the catalogue plus every `extends Plant`
# script), `assign` is the luminance-nearest anchor map with its two repair passes, and
# `blank_comments` / `HEX_RE` are the regex discipline. A second copy of any of them is a
# copy that will disagree with the original the first time either is corrected.
import gen_sport_svg as sport

SRC_DIR = sport.SRC_DIR
GATE_SCRIPT = sport.GATE_SCRIPT

## The infix that makes a stem a skin's. Also what `Skins.SKIN_SUFFIX` spells and what
## `test_sprite_style.gd` keys `SKIN_PALETTES` off -- one spelling, three readers, so it
## is named here and asserted there rather than typed three times.
SKIN_SUFFIX = "_skin_"

## Order matters: it is the order `--palette` prints and the order the gate block is
## compared in, so a reordering is a finding rather than a silent no-op.
FAMILIES = ("golden", "frost", "ember")

HEX_RE = sport.HEX_RE
GREY_SATURATION = sport.GREY_SATURATION

BANNER = (
    "  <!-- GENERATED by tools/gen_skin_svg.py from %s, family %s. Do not edit by hand:\n"
    "       run `python tools/gen_skin_svg.py` and it reports any edit the parent and the\n"
    "       %s ramp do not explain. Parent geometry is copied verbatim, paint is remapped\n"
    "       onto the ramp, and the family motif is the appended group at the end. -->\n"
)


# --------------------------------------------------------------------------
# The ramps
# --------------------------------------------------------------------------

def _warm_anchor(hue_deg, r, b):
    """An anchor at `hue_deg` in [0, 60), from its red and blue channels.

    For a warm colour the max channel is R and the min is B, so HSV hue is
    60 * (G - B) / (R - B) and G = B + (hue/60) * (R - B) puts the anchor on the nose
    whatever its value. Deriving rather than typing is what keeps eight anchors within
    half a degree of each other, which is what lets `check_outline`'s hue clause pass for
    any two of them.
    """
    return (r, int(round(b + (hue_deg / 60.0) * (r - b))), b)


def _cool_anchor(hue_deg, r, b):
    """An anchor at `hue_deg` in [180, 240), from its red and blue channels.

    There the max channel is B and the min is R, so hue = 60 * (4 + (R - G) / (B - R))
    and G = R + (4 - hue/60) * (B - R). Same derivation, different pair of channels,
    because which channel is the odd one out is a property of the hue sector.
    """
    return (r, int(round(r + (4.0 - hue_deg / 60.0) * (b - r))), b)


## Eight anchors per ramp, monotone in luminance and spanning the range a plant sprite
## uses. Eight because a skin puts EVERY chromatic shade of its parent on ONE ramp and the
## widest parents carry eight -- a bare run fails loudly rather than flattening a sprite
## that outgrows the ramp, which is the failure a tenth plant would hit.
##
## The pairs below are (R, B); the middle channel is derived. Reading them as a table:
## the dark end keeps a little blue so it is a shade and not soot, and the pale end keeps
## saturation at or above 0.26 so the outline check never mistakes a fill for bare paper.
## The one hue each family sits at, named once and read twice: the ramps are built from
## it, and the fixture asserts every anchor lands within 0.6 degrees of it. A hue written
## into the construction and nowhere else is a hue nothing can check.
FAMILY_HUE = {"golden": 45.0, "frost": 200.0, "ember": 15.0}

RAMPS = {
    "golden": [_warm_anchor(FAMILY_HUE["golden"], r, b) for r, b in
               [(70, 4), (105, 6), (140, 9), (175, 14), (208, 24), (232, 55),
                (245, 110), (252, 170)]],
    "frost": [_cool_anchor(FAMILY_HUE["frost"], r, b) for r, b in
              [(5, 70), (8, 105), (12, 140), (20, 175), (40, 205), (80, 228),
               (135, 242), (185, 250)]],
    "ember": [_warm_anchor(FAMILY_HUE["ember"], r, b) for r, b in
              [(72, 4), (108, 8), (144, 12), (180, 16), (214, 26), (236, 64),
               (248, 124), (253, 181)]],
}


def ramp_hexes(family):
    return [sport.to_hex(c) for c in RAMPS[family]]


# --------------------------------------------------------------------------
# The motifs
#
# Placed against a measured map of where all seventeen parents leave the tile empty --
# see the module docstring. Every coordinate below is mirror-symmetric about x = 32 and
# every drawn edge, half its own stroke included, lands inside [3, 61].
#
# `%(c1)s` .. `%(c8)s` are that family's ramp anchors, rung 1 deepest. Fills sit high on
# the ramp and rims three rungs below them, which is STYLE.md's "outline = darker shade of
# the fill" expressed the only way a generated file can express it: as an index offset.
# --------------------------------------------------------------------------

MOTIFS = {
    # A wheat and laurel crown arcing over the top of the tile, and a narrow band at the
    # base. The band's outer curve peaks at y = 4.5, which is above every parent except
    # the Sunflower's topmost petal tip and the Chomp's crown -- those two it deliberately
    # rests on. The wheat ears hang in the left and right margins, which no parent uses.
    "golden": """  <g id="skin_motif_golden" stroke-linejoin="round" stroke-linecap="round">
    <path d="M 6 19 Q 32 -10 58 19 L 55 20.8 Q 32 -4.8 9 20.8 Z"
          fill="#%(c6)s" stroke="#%(c3)s" stroke-width="1.6"/>
    <g fill="#%(c7)s" stroke="#%(c4)s" stroke-width="1">
      <ellipse cx="11.2" cy="13.8" rx="3.2" ry="1.9" transform="rotate(-38 11.2 13.8)"/>
      <ellipse cx="52.8" cy="13.8" rx="3.2" ry="1.9" transform="rotate(38 52.8 13.8)"/>
      <ellipse cx="16.9" cy="9.4" rx="3.2" ry="1.9" transform="rotate(-24 16.9 9.4)"/>
      <ellipse cx="47.1" cy="9.4" rx="3.2" ry="1.9" transform="rotate(24 47.1 9.4)"/>
      <ellipse cx="22.6" cy="6.4" rx="3.2" ry="1.9" transform="rotate(-12 22.6 6.4)"/>
      <ellipse cx="41.4" cy="6.4" rx="3.2" ry="1.9" transform="rotate(12 41.4 6.4)"/>
    </g>
    <g fill="#%(c8)s" stroke="#%(c4)s" stroke-width="1">
      <ellipse cx="7" cy="22.6" rx="2.4" ry="1.7" transform="rotate(-35 7 22.6)"/>
      <ellipse cx="57" cy="22.6" rx="2.4" ry="1.7" transform="rotate(35 57 22.6)"/>
      <ellipse cx="7" cy="26.2" rx="2.4" ry="1.7" transform="rotate(-35 7 26.2)"/>
      <ellipse cx="57" cy="26.2" rx="2.4" ry="1.7" transform="rotate(35 57 26.2)"/>
      <ellipse cx="7" cy="29.8" rx="2.4" ry="1.7" transform="rotate(-35 7 29.8)"/>
      <ellipse cx="57" cy="29.8" rx="2.4" ry="1.7" transform="rotate(35 57 29.8)"/>
    </g>
    <rect x="11.5" y="58.5" width="41" height="2" rx="1"
          fill="#%(c7)s" stroke="#%(c3)s" stroke-width="1"/>
  </g>
""",
    # Three ice shards standing at the base and one hexagonal crystal above. The flanking
    # shards stand in the left and right margins where only the Bramble reaches; the
    # centre shard is the SHORT one, which is backwards for ice and forwards for this
    # tile, because the centre of the lower half is the busiest region every parent has.
    # The crystal floats in the top strip and clips the two tallest heads by about 2 px.
    "frost": """  <g id="skin_motif_frost" stroke-linejoin="round" stroke-linecap="round">
    <g fill="#%(c7)s" stroke="#%(c3)s" stroke-width="1.4">
      <path d="M 5.4 60 L 9 46 L 12.6 60 Z"/>
      <path d="M 51.4 60 L 55 46 L 58.6 60 Z"/>
      <path d="M 28.4 60 L 32 52 L 35.6 60 Z"/>
    </g>
    <g fill="none" stroke="#%(c5)s" stroke-width="1">
      <path d="M 9 49 L 9 58"/>
      <path d="M 55 49 L 55 58"/>
      <path d="M 32 54.5 L 32 58"/>
    </g>
    <path d="M 32 3.8 L 34.8 5.35 L 34.8 8.45 L 32 10 L 29.2 8.45 L 29.2 5.35 Z"
          fill="#%(c8)s" stroke="#%(c4)s" stroke-width="1.2"/>
    <path d="M 32 4.4 L 32 9.4" fill="none" stroke="#%(c6)s" stroke-width="1"/>
  </g>
""",
    # A scorch crescent at the base and three ember flecks rising from it. The crescent
    # tapers to a point at (7, 52) and (57, 52) and bellies down to y = 60, so its body
    # lives entirely in the bottom strip no parent uses; the flecks rise off its two tips
    # into the lower corners, which only the Bramble and the Aloe reach into at all.
    #
    # It is 4.25 px thick at the centre rather than the 3 it was first drawn at. Measured:
    # the first draft put 116 opaque pixels on the tile against the frost motif's 174 and
    # the crown's 440, which is the one family whose ornament a player could plausibly
    # miss. Thickening the belly and pushing the tips out to x = 7 and 57 is the change
    # that costs nothing -- the whole crescent still sits in rows no parent paints.
    "ember": """  <g id="skin_motif_ember" stroke-linejoin="round" stroke-linecap="round">
    <path d="M 7 52 Q 32 68 57 52 Q 32 59.5 7 52 Z"
          fill="#%(c3)s" stroke="#%(c1)s" stroke-width="1.2"/>
    <g fill="#%(c7)s" stroke="#%(c4)s" stroke-width="1">
      <path d="M 8 44 Q 11 47.5 8 51 Q 5 47.5 8 44 Z"/>
      <path d="M 56 44 Q 59 47.5 56 51 Q 53 47.5 56 44 Z"/>
      <path d="M 32 50.5 Q 34.6 54 32 57.5 Q 29.4 54 32 50.5 Z"/>
    </g>
    <g fill="#%(c8)s">
      <ellipse cx="8" cy="47.6" rx="1.1" ry="1.5"/>
      <ellipse cx="56" cy="47.6" rx="1.1" ry="1.5"/>
      <ellipse cx="32" cy="54.2" rx="1" ry="1.4"/>
    </g>
  </g>
""",
}


def motif(family):
    """The family's `<g>`, with its ramp anchors substituted in."""
    hexes = ramp_hexes(family)
    return MOTIFS[family] % {("c%d" % (i + 1)): hexes[i] for i in range(len(hexes))}


# --------------------------------------------------------------------------
# Colour
# --------------------------------------------------------------------------

def is_chromatic(rgb):
    """Whether this source colour gets a ramp rung at all.

    A skin has ONE ramp, so unlike a sport there is no hue bucketing -- the only question
    is whether the paint has a hue to move. Achromatic paint is left exactly alone, same
    as a sport's and for the same reason: the Chomp Flower's teeth are the only grey in
    any plant sprite and they are bone. A skin is a coat, not a transplant.
    """
    if sport.saturation(rgb) < GREY_SATURATION:
        return False
    return sport.hue(rgb) is not None


def skin_map(hexes, family):
    """source hex (upper, no '#') -> skin hex, for every colour in one sprite.

    Achromatic paint maps to itself, which keeps it out of the ramp AND out of the count
    -- eight rungs is eight coloured shades, not eight tokens. Everything else goes
    through `gen_sport_svg.assign`, which is the luminance-nearest map with the forward
    and backward repair passes; see that docstring for why the alternative (normalising
    each sprite against its own luminance range) shipped once and made the Corn Cobbler
    grow one dark leaf and one nearly white one.
    """
    members = []
    out = {}
    for h in sorted(set(hexes)):
        rgb = sport.parse_hex(h)
        if not is_chromatic(rgb):
            out[h] = h
            continue
        members.append((sport.luminance(rgb), h))
    members.sort()
    ramp = RAMPS[family]
    for h, i in sport.assign(members, ramp).items():
        out[h] = sport.to_hex(ramp[i])
    return out


# --------------------------------------------------------------------------
# Generation
# --------------------------------------------------------------------------

def derive(source_text, parent_name, family):
    """The skin SVG for one parent and one family, and the map it used.

    Substitution runs right-to-left over spans found in the BLANKED text, so applying one
    never moves the offsets of the ones not yet applied and a hex inside a comment is
    never touched. The motif is appended AFTER that pass, which is what keeps its own
    anchors out of the colour count.
    """
    masked = sport.blank_comments(source_text)
    spans = [(m.start(1), m.end(1), m.group(1).upper()) for m in HEX_RE.finditer(masked)]
    mapping = skin_map([s[2] for s in spans], family)
    out = source_text
    for start, end, h in reversed(spans):
        out = out[:start] + mapping[h] + out[end:]

    at = out.find(">", out.find("<svg"))
    if at < 0:
        raise RuntimeError("%s has no <svg> element" % parent_name)
    banner = BANNER % (parent_name, family, family)
    out = out[:at + 1] + "\n" + banner.rstrip("\n") + out[at + 1:]

    close_at = out.rfind("</svg>")
    if close_at < 0:
        raise RuntimeError("%s has no closing </svg>" % parent_name)
    out = out[:close_at] + motif(family) + out[close_at:]
    return out, {k: v for k, v in mapping.items() if k != v}


def skin_stem(stem, family):
    return "%s%s%s" % (stem, SKIN_SUFFIX, family)


# --------------------------------------------------------------------------
# The gate's copy of the ramps
# --------------------------------------------------------------------------

SKIN_PALETTES_RE = re.compile(r"const\s+SKIN_PALETTES[^{]*\{(.*?)\n\}", re.S)
FAMILY_ROW_RE = re.compile(r'"([a-z_]+)"\s*:\s*\[([^\]]*)\]', re.S)


def gate_skin_palettes(root):
    """The SKIN_PALETTES block `test_sprite_style.gd` currently carries, as
    family -> [hex, ...] in the order it is written.

    Regex over GDScript rather than a second copy of the ramps there, for the reason
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


def palette_block():
    """The SKIN_PALETTES const block for test/unit/test_sprite_style.gd."""
    lines = ["const SKIN_PALETTES := {"]
    for family in FAMILIES:
        row = ", ".join('"%s"' % h for h in ramp_hexes(family))
        lines.append('\t"%s": [%s],' % (family, row))
    lines.append("}")
    return "\n".join(lines)


def describe_gate_difference(gate):
    """One line naming the first disagreement between the gate's block and the ramps."""
    want = list(FAMILIES)
    got = list(gate.keys())
    if got != want:
        return "families %s in the gate against %s here" % (got, want)
    for family in FAMILIES:
        mine = ramp_hexes(family)
        theirs = gate[family]
        for i in range(max(len(mine), len(theirs))):
            a = theirs[i] if i < len(theirs) else "(missing)"
            b = mine[i] if i < len(mine) else "(extra)"
            if a != b:
                return "%s rung %d: gate #%s vs ramp #%s" % (family, i + 1, a, b)
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


def check(root, write):
    """(findings, stats). Findings are strings; stats is what the denominator prints."""
    findings = []
    stats = {"stems": 0, "scripts": 0, "expected": 0, "written": 0, "remapped": 0}

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
                text, changed = derive(source_text, "%s.svg" % stem, family)
            except (ValueError, RuntimeError) as exc:
                findings.append(
                    "FINDING: %s/%s cannot be derived -- %s\n"
                    "  fix: widen the %s ramp in RAMPS (every ramp stays the same length),\n"
                    "       or reduce the parent to as many chromatic shades as a ramp seats.\n"
                    "  waive: none -- collapsing two shades into one is the defect."
                    % (SRC_DIR, dest_name, exc, family))
                continue
            stats["remapped"] += len(changed)
            current = sport.read_text(dest) if os.path.isfile(dest) else None
            if current == text:
                continue
            if not write:
                why = ("does not exist" if current is None
                       else "differs from its parent's derivation")
                findings.append(
                    "FINDING: %s/%s %s\n"
                    "  fix: run `python tools/gen_skin_svg.py --write`, then re-render with\n"
                    "       `godot --headless --path . --script res://tools/render_svg.gd`.\n"
                    "  waive: none -- a skin is a function of its parent and its ramp,\n"
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
            "  fix: delete it, or add its family to FAMILIES and its ramp to RAMPS.\n"
            "  waive: none -- the gate derives an EXPECTED_SIZE row for any file matching\n"
            "         this pattern, so a stray one is a sprite that ships ungated."
            % (SRC_DIR, stray))

    gate = gate_skin_palettes(root)
    if gate != {f: ramp_hexes(f) for f in FAMILIES}:
        findings.append(
            "FINDING: SKIN_PALETTES in %s is not this file's RAMPS -- %s\n"
            "  fix: `python tools/gen_skin_svg.py --palette`, paste the block over it.\n"
            "  waive: none -- a skin painted in a colour the gate does not carry fails\n"
            "         test_every_colour_is_kit_palette_or_a_blend_of_two, and an entry the\n"
            "         gate carries that no ramp emits silently widens what a skin may use."
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

FIXTURE_PARENT = (
    '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">\n'
    '  <circle cx="32" cy="32" r="20" fill="#2ECC71" stroke="#1F8A4C" stroke-width="2"/>\n'
    '  <circle cx="32" cy="26" r="6" fill="#FFCC00" stroke="#C29A00" stroke-width="2"/>\n'
    '</svg>\n'
)


def _fixture_gate(block):
    return 'extends Node\n\nconst EXPECTED_SIZE := {\n\t"poppy": 64,\n}\n\n%s\n' % block


def run_fixture():
    """Build a miniature project and assert WHICH findings come back.

    Per finding, never by count: a rule that fell silent while another double-fired
    leaves the total where it was, and that is exactly the result a count cannot see.
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
        edited = os.path.join(root, SRC_DIR, "poppy_skin_frost.svg")
        if not os.path.isfile(edited):
            # A named failure, never a traceback. "the write never happened" and "the
            # drift check is not load-bearing" are opposite results and a stack trace
            # cannot tell them apart -- see .claude/skills/house-static-checker.
            failures.append("--write produced no poppy_skin_frost.svg to hand-edit")
        else:
            write(os.path.join(SRC_DIR, "poppy_skin_frost.svg"),
                  sport.read_text(edited).replace('r="20"', 'r="19"'))
            got = findings_now()
            if not any("poppy_skin_frost.svg differs" in f for f in got):
                failures.append("hand-edited leaf was not reported")
            if any("poppy_skin_ember.svg" in f for f in got):
                failures.append("hand-edited leaf implicated a sibling")
            check(root, True)

        # Case 4: a file for a family that does not exist.
        write(os.path.join(SRC_DIR, "poppy_skin_gilt.svg"), FIXTURE_PARENT)
        got = findings_now()
        if not any("poppy_skin_gilt.svg is not a skin this derivation produces" in f
                   for f in got):
            failures.append("an unknown-family file was accepted")
        os.remove(os.path.join(root, SRC_DIR, "poppy_skin_gilt.svg"))

        # Case 5: the gate's block and the ramps disagree.
        write(GATE_SCRIPT, _fixture_gate(palette_block().replace("053046", "050046")))
        got = findings_now()
        if not any("SKIN_PALETTES" in f and "frost rung 1" in f for f in got):
            failures.append("a desynced SKIN_PALETTES block was accepted")

        # Case 6: no block at all is COULD NOT RUN, not a clean tree.
        write(GATE_SCRIPT, 'extends Node\n\nconst EXPECTED_SIZE := {\n\t"poppy": 64,\n}\n')
        if gate_skin_palettes(root) is not None:
            failures.append("a gate with no SKIN_PALETTES block read as present")

        # Cases 7 and 8 test the two TRANSFORMS directly, on inputs written out by hand,
        # because everything above is self-consistency: the fixture writes with this code
        # and compares with this code, so a derivation that is uniformly WRONG agrees with
        # itself and passes every one of them. Mutating `to_hex(ramp[i])` to
        # `to_hex(ramp[0])` -- which collapses every shade of a sprite into one flat
        # colour -- survived all six, and these two are what kill it.
        for family in FAMILIES:
            # 7: the anchors are where the derivation claims they are.
            for anchor in RAMPS[family]:
                got_hue = sport.hue(anchor)
                want_hue = FAMILY_HUE[family]
                if got_hue is None or abs(got_hue - want_hue) > 0.6:
                    failures.append("%s anchor #%s sits at hue %s, not %g"
                                    % (family, sport.to_hex(anchor), got_hue, want_hue))
                if sport.saturation(anchor) < GREY_SATURATION:
                    failures.append("%s anchor #%s reads as grey to the outline check"
                                    % (family, sport.to_hex(anchor)))
            # 8: four distinct source shades come out four distinct anchors of THIS
            # family, in the same luminance order, and the white is untouched.
            # Distinctness is the property the whole map exists to preserve: a
            # rank-collapsing map flattens a maw drawn three reds deep, and every other
            # gate in this repo passes the flattened sprite.
            # Listed here in the order their OWN luminance puts them, which is what makes
            # the order assertion below mean something: 1F8A4C is 105, C29A00 150,
            # 2ECC71 164, FFCC00 200. Written in any other order the check compares the
            # output against an order nothing claimed and fails on correct code.
            source = ["1F8A4C", "C29A00", "2ECC71", "FFCC00", "FFFFFF"]
            mapped = skin_map(source, family)
            anchors = set(ramp_hexes(family))
            moved = [mapped[h] for h in source if h != "FFFFFF"]
            if len(set(moved)) != 4:
                failures.append("%s collapsed 4 shades into %d: %s"
                                % (family, len(set(moved)), moved))
            if not set(moved) <= anchors:
                failures.append("%s emitted %s, which is not one of its own anchors"
                                % (family, sorted(set(moved) - anchors)))
            if mapped["FFFFFF"] != "FFFFFF":
                failures.append("%s recoloured achromatic paint" % family)
            lums = [sport.luminance(sport.parse_hex(m)) for m in moved]
            if lums != sorted(lums):
                failures.append("%s did not preserve luminance order: %s" % (family, moved))
    finally:
        shutil.rmtree(root, ignore_errors=True)

    print("gen_skin_svg fixture: 8 case(s) over 1 synthetic parent x %d famil%s, "
          "%d failure(s)"
          % (len(FAMILIES), "y" if len(FAMILIES) == 1 else "ies", len(failures)))
    for f in failures:
        print("  FAIL: %s" % f)
    print("NOT COVERED by the fixture: it proves the RULES fire on synthetic bytes. It "
          "says nothing\n             about whether the real corpus parses, whether the "
          "motifs clear the real\n             parents, or whether Godot rasterises any "
          "of it -- render and look.")
    return bool(failures)


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
              "              is the ramps' only other reader; without it nothing is checked."
              % GATE_SCRIPT)
        return 2
    try:
        findings, stats = check(root, args.write)
    except RuntimeError as exc:
        print("gen_skin_svg: could not run -- %s" % exc)
        return 2

    print("gen_skin_svg: %d plant sprite stem(s) from %s and %d plant script(s) x %d "
          "famil%s = %d skin drawing(s), %d colour substitution(s), %d written, "
          "%d finding(s)"
          % (stats["stems"], sport.CATALOG, stats["scripts"], len(FAMILIES),
             "y" if len(FAMILIES) == 1 else "ies", stats["expected"],
             stats["remapped"], stats["written"], len(findings)))
    if stats["expected"] == 0:
        print("NOTE: nothing to check -- no skin drawing was derived at all. That is a\n"
              "      clean result only if this project has no plants.")
    print("NOT COVERED: this reads SVG text, not rendered pixels. It cannot see whether a\n"
          "             motif buries the plant it decorates, whether the skin colours are\n"
          "             legible against the board they land on, or whether Godot's\n"
          "             rasteriser agrees with the geometry -- test_sprite_style.gd reads\n"
          "             the PNGs and is the gate for the last two, and NOTHING but a\n"
          "             person looking at the sprite answers the first. It does not\n"
          "             compile anything; only import_check.py and lint_project.gd do\n"
          "             that, and neither is parallel-safe.")
    for f in findings:
        print(f)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
