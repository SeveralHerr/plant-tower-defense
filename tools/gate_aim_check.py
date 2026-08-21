#!/usr/bin/env python3
r"""Which sites is a gate actually POINTED AT, out of the sites it could speak about.

`coverage_check.py` answers a different question and answers it well: which defect
CLASSES does this project ask about at all. It would have reported the colour-legibility
class covered, correctly, for every cycle in which `PlacementPreview.DEAD_COLOR` sat
**below** `GardenTheme.GROUND_SEPARATION_MIN` on the only ground it is ever drawn on --
because `GardenTheme.reads_on_ground` existed, and a test named the deferred bar with it.
One of two marks in one grammar row was asked. The other was not, for many cycles, and
nothing counted that.

So this is the sibling question, per gate rather than per class: **enumerate what the gate
COULD be pointed at, enumerate what actually points at it, print the ratio.** A gate's
coverage is the set of call sites somebody remembered to write, and until that set has a
denominator it cannot be read.

WHICH GATE THIS DOES SUPPORT, AND WHY ONLY ONE. The `reads_on` family
(`reads_on_ground` / `reads_on` / `reads_on_at` in `game/garden_theme.gd`) is the one
whose denominator is derivable: a colour that reaches a `draw_*` call in a WORLD-SPACE
script is drawn on the playfield, and that is exactly the population those functions ask
about. `contained-in` and the budget helpers are the same idea over sets this cannot
derive from source, so they are deliberately absent rather than half-covered -- see
NOT COVERED, which names them.

ADVISORY: exit 0 always. A drawn colour that nothing asks about is very often correct --
a cue over a sprite, or one whose legibility rests on motion rather than contrast, is
outside `reads_on_ground`'s stated scope and needs a sentence, not an assertion. A gate
that goes red for those would be permanently red, and a permanently-red gate teaches
people to skip the check. `--strict` exits 1 on any unasked site for a caller that wants
the harder reading.

WHICH GATE WOULD HAVE CAUGHT WHAT THIS CATCHES: none. `name_check` resolves the symbols
happily; lint compiles them; the unit suite asserts whatever it was told to assert. The
defect is an ABSENCE of an assertion, which is invisible to every tool that reads what is
there.

# fixture:   a world script declaring one asked and one unasked colour and drawing both /
#            a SCREEN-space script declaring one (must not count) / a colour declared only
#            inside a comment, only inside a one-line literal, and only inside a
#            LINE-LEADING multi-line literal (only the last of those three can be caught)
# mutations: drop the world/screen split              -> 3 becomes 4, HUD_COLOR appears
#            keep string bodies instead of blanking   -> 3 becomes 4, HEREDOC_COLOR appears
#              ...but ONLY against a line-leading declaration inside a triple-quoted
#              literal.
#              The first two attempts at this mutation SURVIVED, and the reason is a
#              finding about the code rather than a weak fixture: `decl_re` is `^`-anchored
#              under re.M, so a declaration returned inside a ONE-LINE literal cannot
#              match however the strings are treated. Blanking earns its place for
#              exactly one shape, which is worth knowing before widening it.
#            scan game/ for gate calls too         -> gate-call count 11 -> 17, ratio
#              UNCHANGED at 2/35. A near-equivalent mutant, recorded as one: the six extra
#              calls are GardenTheme's own definitions and they name no world-declared
#              colour, so the tests-only scoping defends the REPORT's honesty rather than
#              the verdict -- on today's corpus. It would stop being equivalent the moment
#              a game script called a gate on one of its own colours.
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gdsource
from world_control_check import CLASSNAME_RE, EXTENDS_RE, resolve_space

# The gate family. Every name here is a static function on GardenTheme that answers
# "would this colour be visible where it is drawn"; a test naming ANY of them is asking
# about the colour it passes.
GATE_FUNCS = ("reads_on_ground", "reads_on_at", "reads_on")
GATE_CALL_RE = re.compile(r"\b(?:reads_on_ground|reads_on_at|reads_on)\s*\(")

# Where a colour actually lands on the playfield. `default_color` is the Line2D path,
# which this project uses deliberately for board marks so a headless run can assert their
# points -- see Board's own "WHY Line2D AND NOT A _draw()" block. A sweep that only knew
# about draw_* would miss every one of them, which is most of the marks that matter.
DRAW_RE = re.compile(
    r"\b(?:draw_line|draw_circle|draw_arc|draw_rect|draw_polyline|draw_polygon"
    r"|draw_colored_polygon|draw_texture|draw_texture_rect|draw_char|draw_string"
    r"|draw_multiline|draw_set_transform|draw_dashed_line)\s*\(")
DEFAULT_COLOR_RE = re.compile(r"\.default_color\s*=|^\s*default_color\s*=", re.M)

# A colour SYMBOL: a SCREAMING_CASE const, or a snake_case getter whose name ends in
# `color`/`colour`. Matching the symbol rather than the expression is the whole trick --
# `Color(PIP_RIM_COLOR, PIP_RIM_COLOR.a * fade)` is one symbol wearing an alpha, and a
# test asking about PIP_RIM_COLOR has asked about it.
CONST_SYM_RE = re.compile(r"\b([A-Z][A-Z0-9_]{2,})\b")
GETTER_SYM_RE = re.compile(r"\b([a-z_][a-z0-9_]*_colou?r)\s*\(")
# Anything whose name says colour. A const called SWATCH_RADIUS is on a draw call too.
COLOURISH = re.compile(r"(COLOR|COLOUR|_INK|INK_|TINT|_HUE)")


def call_span(code, start):
    """The text of one call's arguments, from its open paren to the matching close."""
    i = code.index("(", start)
    depth = 0
    for j in range(i, len(code)):
        if code[j] == "(":
            depth += 1
        elif code[j] == ")":
            depth -= 1
            if depth == 0:
                return code[i + 1:j]
    return code[i + 1:]


def symbols_in(fragment):
    out = set()
    for m in CONST_SYM_RE.finditer(fragment):
        if COLOURISH.search(m.group(1)):
            out.add(m.group(1))
    for m in GETTER_SYM_RE.finditer(fragment):
        out.add(m.group(1))
    return out


def gd_files(root, sub):
    found = []
    base = os.path.join(root, sub)
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        for name in sorted(filenames):
            if name.endswith(".gd"):
                found.append(os.path.join(dirpath, name))
    return sorted(found)


def declared_classes(paths):
    out = {}
    for p in paths:
        with open(p, "r", encoding="utf-8", errors="replace") as fh:
            code = gdsource.strip_comments(fh.read(), strings=gdsource.BLANK)
        cn = CLASSNAME_RE.search(code)
        ex = EXTENDS_RE.search(code)
        if cn and ex:
            out[cn.group(1)] = ex.group(1)
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", default=".")
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--strict", action="store_true",
                    help="exit 1 when any drawn colour is unasked (default: advisory)")
    args = ap.parse_args(argv)

    game = gd_files(args.root, "game")
    tests = gd_files(args.root, os.path.join("test", "unit"))
    if not game:
        print("gate_aim_check: NOTHING TO CHECK -- no .gd files under game/. That is a "
              "clean result only if you expected none.")
        return 2

    declared = declared_classes(game)

    # --- the denominator: colour symbols DECLARED in a world-space script.
    #
    # NOT "symbols appearing inside a draw_* call", which is what the first draft used and
    # which measured the regex rather than the project. One of this repo's most-drawn
    # marks never appears at a draw site in its own file: `board_dead_color()` is handed
    # to `Board.mark_dead_ground`, which pushes it onto Line2D children one file away. A
    # denominator built from draw calls silently omits exactly the marks the gate exists
    # for.
    #
    # Declaration site is derivable, stable, and slightly generous -- a declared colour
    # nobody draws is counted. That over-count is reported rather than hidden (the
    # `not seen at a local draw site` number below), and a colour declared in a world
    # script and never drawn is worth a look on its own.
    drawn = {}          # symbol -> declaration site
    local_draw = set()  # symbols also seen at a draw call in their own file
    world_files = 0
    screen_files = 0
    decl_re = re.compile(
        r"^(?:const\s+([A-Z][A-Z0-9_]{2,})\s*:?=|"
        r"static\s+func\s+([a-z_][a-z0-9_]*_colou?r)\s*\(|"
        r"func\s+([a-z_][a-z0-9_]*_colou?r)\s*\()", re.M)
    for p in game:
        with open(p, "r", encoding="utf-8", errors="replace") as fh:
            raw = fh.read()
        # Strings BLANKED: a colour named inside a literal is prose, and this project has
        # already shipped a test that matched the comment explaining a token's absence.
        code = gdsource.strip_comments(raw, strings=gdsource.BLANK)
        ex = EXTENDS_RE.search(code)
        space = resolve_space(ex.group(1), declared) if ex else "unknown"
        if space != "world":
            screen_files += 1
            continue
        world_files += 1
        rel = os.path.relpath(p, args.root).replace("\\", "/")
        for m in decl_re.finditer(code):
            sym = m.group(1) or m.group(2) or m.group(3)
            if m.group(1) and not COLOURISH.search(sym):
                continue
            line = code.count("\n", 0, m.start()) + 1
            drawn.setdefault(sym, "%s:%d" % (rel, line))
        here = set()
        for m in DRAW_RE.finditer(code):
            here |= symbols_in(call_span(code, m.start()))
        for m in DEFAULT_COLOR_RE.finditer(code):
            nl = code.find("\n", m.end())
            here |= symbols_in(code[m.end():nl if nl > 0 else len(code)])
        local_draw |= here

    # --- the numerator: symbols named in a test FUNCTION that calls a gate.
    #
    # Function-scoped, not call-scoped, and that is the second thing the first draft got
    # wrong -- it reported 0 of 24 because tests bind to a local first
    # (`var dead: Color = PlacementPreview.DEAD_COLOR` ... `reads_on_at(dead, ...)`), so
    # the symbol is never inside the parentheses. Scoping to the function is how
    # `group_leak_check` reads this repo too, and the trade is stated in NOT COVERED: a
    # function that gates X while merely mentioning Y credits Y as asked.
    asked = {}
    gate_calls = 0
    func_re = re.compile(r"^(?:static\s+)?func\s+(\w+)\s*\(", re.M)
    for p in tests:
        with open(p, "r", encoding="utf-8", errors="replace") as fh:
            code = gdsource.strip_comments(fh.read(), strings=gdsource.BLANK)
        rel = os.path.relpath(p, args.root).replace("\\", "/")
        starts = [(m.start(), m.group(1)) for m in func_re.finditer(code)]
        bounds = [(s, starts[i + 1][0] if i + 1 < len(starts) else len(code), n)
                  for i, (s, n) in enumerate(starts)]
        for start, end, name in bounds:
            body = code[start:end]
            hits = list(GATE_CALL_RE.finditer(body))
            if not hits:
                continue
            gate_calls += len(hits)
            line = code.count("\n", 0, start) + 1
            for sym in symbols_in(body):
                asked.setdefault(sym, set()).add("%s:%d %s" % (rel, line, name))

    unasked = sorted(s for s in drawn if s not in asked)
    covered = sorted(s for s in drawn if s in asked)
    # Asked about but never found at a draw site here: not a defect, and worth printing.
    # It is usually a colour drawn from a .tscn or handed to an engine property this
    # cannot follow, and it is the honest counterweight to the ratio below.
    orphan_asks = sorted(s for s in asked if s not in drawn)

    total = len(drawn)
    if total == 0:
        print("gate_aim_check: NOTHING TO CHECK -- %d world-space script(s) and not one "
              "colour symbol reaching a draw call. That is a clean result only if you "
              "expected none; more likely the draw-call pattern needs widening."
              % world_files)
        return 2

    never_drawn = sorted(s for s in drawn if s not in local_draw)
    print("gate_aim_check: reads_on family -- %d of %d colour(s) declared in world-space "
          "scripts are named in a gate assertion (%d world-space script(s) of %d, %d gate "
          "call(s) across %d test file(s)); %d of the %d are not seen at a draw call in "
          "their own file -- handed to another node, or unused; %d asked-about symbol(s) "
          "are not declared in any world script"
          % (len(covered), total, world_files, world_files + screen_files,
             gate_calls, len(tests), len(never_drawn), total, len(orphan_asks)))

    if not args.quiet:
        for sym in unasked:
            print("  UNASKED  %-26s declared %-34s %s"
                  % (sym, drawn[sym],
                     "drawn here" if sym in local_draw else "not drawn in its own file"))
        for sym in covered:
            print("  asked    %-26s %s" % (sym, sorted(asked[sym])[0]))
        for sym in orphan_asks:
            print("  NOT DECLARED HERE (asked anyway)  %-16s %s"
                  % (sym, sorted(asked[sym])[0]))

    print("  NOT COVERED: this counts whether a colour is NAMED in a gate assertion. It "
          "does not check that the assertion was the right one, that it used the alpha "
          "the colour ships with, or that it named the ground the mark actually lands "
          "on -- a `reads_on_ground(X)` on a mark that only ever touches grass is "
          "counted here and is still the wrong question. It reads source, not a running "
          "tree, so a colour set from a .tscn or through a variable is invisible; those "
          "surface as `NOT DECLARED HERE (asked anyway)` when a test names them. And it "
          "supports "
          "ONE gate family: `contained-in` and the budget helpers have no denominator "
          "derivable from source and are absent rather than half-covered.")
    return 1 if (args.strict and unasked) else 0


if __name__ == "__main__":
    sys.exit(main())
