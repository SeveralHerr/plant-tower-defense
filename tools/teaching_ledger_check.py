#!/usr/bin/env python3
r"""The cue-legend ledger's TAUGHT/untaught column, checked against the surfaces.

`game/cue_legend.gd` carries a hand-maintained table, one line per numbered
`OVERLAY_GRAMMAR.md` row, marking each TAUGHT or `untaught`. It is not decoration: the
verdict block directly beneath it is where every "should this cue get a legend row"
decision in this project has been made and re-read, and cycle 148 closed a bead by
reading it.

IT HAS DRIFTED TWICE, BOTH TIMES IN THE SAME DIRECTION — a row reading `untaught` for
cycles after a hint had already taught it, and cycle 151 read that block while shipping
one of them. **A wrong `untaught` invites work that has already been done**, which is
the expensive direction: cycle 148 nearly spent a cycle on it.

A THIRD DIRECTION THIS DOES NOT CHECK, added to the record by cycle 179: a row can go
UNDRAWN. The sole-cover rings and the deferred-road bars were removed on a player's
report, and the ledger's TAUGHT/`untaught` axis has no value for "nothing draws this
any more". Both ends of the mapping below are about TEACHING SURFACES; neither is about
whether the cue exists.

BOTH ENDS ARE ENUMERABLE, which is why this is checkable and its sibling
(`plant-tower-defense-snhb`, the same class for notebook CARDS) is not. A card's claim
is prose about a mechanic and only a human can read it; this is a mapping between two
lists:

  * the ledger's own numbered rows and their TAUGHT/`untaught` marking;
  * `CueLegend.ROWS`, six entries each carrying a `shape`, and `Hud.HINT_CARDS`, whose
    `grammar_row` key says which numbered row each hint teaches (0 for a hint about a
    RULE rather than a mark — four of the five).

That `grammar_row` key was added for this checker, and it is the whole reason the
interesting direction is checkable at all. Without it a tool can confirm that a row
claiming TAUGHT names something real, and cannot confirm that a row claiming `untaught`
is unclaimed — because nothing else in the codebase records which row a hint teaches.

WHICH GATE WOULD HAVE CAUGHT THIS: none. The ledger is a comment. `name_check` blanks
it, lint never reads it, and no test asserts over prose. It is exactly the shape this
repo builds house checkers for.

GATING, not advisory, and deliberately: unlike a coverage ratio, every finding here has
one correct response — change the word, or change the surface. There is no legitimate
"leave it alone" case, so a red run is always actionable and can never become permanent.

# fixture:   a ledger row marked untaught that a hint's grammar_row claims / a row
#            marked TAUGHT that nothing claims and no legend row covers / a row
#            correctly TAUGHT via a legend shape / a row correctly untaught
# mutations: stop reading grammar_row          -> the untaught-but-claimed finding
#                                                 vanishes, which is the only direction
#                                                 that has ever actually drifted here
#            treat a 0 grammar_row as a claim  -> four rule-hints start claiming row 0
#            keep comment text when blanking   -> the verdict block's prose below the
#                                                 table starts matching as ledger rows
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gdsource

LEDGER = "game/cue_legend.gd"
CARDS = "game/hud.gd"

# `#   6  straight line in a box  untaught         hover dead bar, ...`
ROW_RE = re.compile(r"^#\s{2,}(\d{1,2})\s{2,}(\S.*?)\s{2,}(TAUGHT|untaught)\b", re.M)
CARD_ID_RE = re.compile(r'"id":\s*"([a-z_]+)"\s*,\s*\n\s*"grammar_row":\s*(\d+)')
SHAPE_RE = re.compile(r'"shape":\s*([A-Z_][A-Z0-9_]*)')


def read(path, root):
    full = os.path.join(root, path)
    if not os.path.isfile(full):
        return None
    with open(full, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read()


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", default=".")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    ledger_src = read(LEDGER, args.root)
    cards_src = read(CARDS, args.root)
    if ledger_src is None or cards_src is None:
        print("teaching_ledger_check: COULD NOT RUN -- %s or %s is missing. Nothing was "
              "checked; this is not a clean result." % (LEDGER, CARDS))
        return 2

    # The ledger lives in COMMENTS, so unlike every other checker here the comment text
    # is the input rather than the noise. What must be blanked instead is the code below
    # it -- otherwise `ROWS`'s own entries and the verdict block's prose can match. The
    # table is bounded by its two known neighbours rather than scanned whole.
    start = ledger_src.find("# THE DIFF, one line per grammar row")
    end = ledger_src.find("# THE PRICE OF A ROW", start) if start >= 0 else -1
    if end < 0:
        end = ledger_src.find("# THE VERDICT, per untaught cue", start) if start >= 0 else -1
    if start < 0 or end < 0:
        print("teaching_ledger_check: COULD NOT RUN -- the ledger's start or end marker "
              "is missing from %s, so the region measured would be a fragment. A region "
              "that can silently shrink is the mirror_check failure; refusing instead."
              % LEDGER)
        return 2
    table = ledger_src[start:end]

    rows = {}
    for m in ROW_RE.finditer(table):
        rows[int(m.group(1))] = (m.group(2).strip(), m.group(3) == "TAUGHT")
    if not rows:
        print("teaching_ledger_check: COULD NOT RUN -- the ledger region was found and "
              "held no parsable rows. Zero rows over a %d-character region is a parser "
              "failure, not a clean table." % len(table))
        return 2

    # Which rows a HINT claims. 0 means "this hint teaches a rule, not a mark".
    code = gdsource.strip_comments(cards_src, strings=gdsource.KEEP)
    claims = {}
    for m in CARD_ID_RE.finditer(code):
        row = int(m.group(2))
        if row:
            claims.setdefault(row, []).append(m.group(1))
    cards_seen = len(CARD_ID_RE.findall(code))

    # Which rows the LEGEND covers. Its six entries carry a shape, and the ledger names
    # its own rows by that shape's phrasing, so the count is what is checked here rather
    # than a per-row mapping -- see NOT COVERED.
    legend_src = gdsource.strip_comments(ledger_src, strings=gdsource.KEEP)
    legend_shapes = len(set(SHAPE_RE.findall(legend_src)))

    findings = []
    for n in sorted(rows):
        label, taught = rows[n]
        claimed = claims.get(n, [])
        if claimed and not taught:
            findings.append(
                "%s: row %d (%s) is marked `untaught`, but %s claims it via "
                "`grammar_row`.\n"
                "  fix: change the word to TAUGHT and name the surface beside it, as "
                "rows 4 and 6 already do.\n"
                "  why it matters: a wrong `untaught` invites work that has already "
                "shipped -- this exact drift nearly cost cycle 148 a whole cycle."
                % (LEDGER, n, label, " and ".join("`%s`" % c for c in claimed)))
    unclaimed_taught = [n for n in sorted(rows)
                        if rows[n][1] and n not in claims]

    print("teaching_ledger_check: %d ledger row(s), %d marked TAUGHT; %d hint card(s) "
          "carry a grammar_row and %d of them claim a row (%d teach a RULE and claim "
          "none); the legend covers %d shape(s); %d finding(s)"
          % (len(rows), sum(1 for n in rows if rows[n][1]), cards_seen,
             sum(len(v) for v in claims.values()),
             cards_seen - sum(len(v) for v in claims.values()),
             legend_shapes, len(findings)))
    if not args.quiet:
        for f in findings:
            print("FINDING: %s" % f)
        if unclaimed_taught:
            print("  NOTE: %d row(s) are TAUGHT with no hint claiming them (%s). That is "
                  "the normal case -- a legend row teaches them -- and is printed rather "
                  "than checked, because the ledger names its rows in prose and the "
                  "legend names them by SHAPE const, and matching those is the human "
                  "judgement this tool deliberately does not make."
                  % (len(unclaimed_taught),
                     ", ".join(str(n) for n in unclaimed_taught)))
    print("  NOT COVERED: this checks ONE direction rigorously -- a row called `untaught` "
          "that a hint claims. The other direction is only counted, not matched: a row "
          "called TAUGHT is trusted, because the ledger names its rows in prose ('small "
          "solid ring') and CueLegend.ROWS names them by SHAPE const, and deciding those "
          "are the same row is a judgement rather than a lookup. It also cannot tell "
          "whether a `grammar_row` is the RIGHT row -- a hint pointed at row 3 by mistake "
          "reads as clean here and would be wrong everywhere. And it reads source, not a "
          "running game, so it says nothing about whether a hint ever actually fires.")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
