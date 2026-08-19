#!/usr/bin/env python3
r"""Rank open beads by how much UNRESOLVED absence claim they carry.

An absence claim is a sentence asserting the repo does NOT do something --
"nothing calls this", "there is no test", "the boss has no sprite". It is the
class of claim that rots, because the repo moves every cycle and the bead does
not, and it rots in the most expensive direction: an implementer reads it at
face value and spends the first hour building something that already exists.

WHY THIS EXISTS (plant-tower-defense-htnt, from -g1o4's close reason). Cycle 104
ran a throwaway scratchpad scan of this shape and found 139 open beads carrying
at least one absence claim. Sixteen were resolved by hand. 123 were not reached,
and the scan was deleted with the scratchpad. Two of the sixteen had premises
that were entirely false and were closed without a line of code written -- one
would have had somebody building a boss that already has 80 health, two sprites
and 26 wave appearances. That is the payoff, and it is why the scan had to stop
being a throwaway.

WHICH EXISTING GATE WOULD HAVE CAUGHT THIS, AND WHY IT DOESN'T. None, and the
reason is structural rather than an oversight. Every engine gate reads `game/`,
`test/` and `tools/` -- source. Bead prose lives in a Dolt DB exported to
`.beads/issues.jsonl`, which only `bead_prose_check.py` has ever opened, and
that tool asks a different question: whether the shell ate a word on the way in,
never whether the surviving sentence is still true. `citation_check.py` resolves
`file:line` citations, but only in markdown files handed to it, and a resolving
citation says nothing about whether the line supports the claim beside it. The
defect here is a true sentence that stopped being true, which no compiler, no
linter and no test can see.

ADVISORY BY DESIGN, exit 0 always. The correct response to most of these is "yes,
still true" -- so a gate would be permanently red, and a permanently red gate
teaches people to skip the check. See house-static-checker's own section. Use
`--strict` when you want the run to gate.

RANK, DO NOT FILTER. The value is working the densest bead first and being able
to say how many were not reached. Filtering to a shortlist reproduces the cycle
104 outcome, where 16 were handled and 123 vanished with the tooling.

THE WAIVER IS THE RESOLUTION NOTE -- the same mechanism `bead_prose_check.py`
uses for its correction notes, and deliberately not a second convention. A bead
whose prose records a verdict against the code stops being listed, and the
verdict stays where the next reader will find it. The notes cycle 104 already
wrote read `ABSENCE CLAIM RESOLVED (cycle 104 sweep, -g1o4): STILL TRUE.`;
13 open beads carry one and this recognises all 13.

THE NEEDLE SET IS A TASTE CALL, AND IS TREATED AS ONE. `.claude/skills/
derive-the-list/SKILL.md` step 1: there is no generating rule for "every English
phrasing that asserts absence", so this list cannot be derived and must not
pretend to be. What it gets instead is the treatment that skill prescribes for a
taste-call list -- it is recorded, and the PROPERTY it claims is asserted.

TWO GUARDS, AND ONE OF THEM IS WEAK ON PURPOSE AND SAYS SO. The first is the
positive control: every bead a PAST sweep judged to carry an absence claim must
still match a needle today, outside its own resolution note. I expected deleting
one needle to trip it. It does not -- mutation B took `nothing` out, dropped 83
real claims, and the control still read 13 of 13, because the needle set is
redundant over prose this dense. That is the "positive control that cannot fail"
house-static-checker warns about, caught by mutating rather than by reading. It
is kept, because it does fire on a two-needle collapse (mutation B3, naming
-fjqp), and it now prints its own STRENGTH -- the smallest number of distinct
classes any waived bead relies on, currently 2 -- so nobody reads it as a
guarantee. The second guard is the one that skill actually prescribes in its
place: `--self-test`, 14 hand-written known-in/known-out cases over the transform
itself. It goes red on 7 of the 9 mutations, including the one the real corpus
cannot see at all (G).

DELIBERATELY EXCLUDED NEEDLES, with the counts that decided it (open beads, this
corpus): `is not` / `isn't` / `aren't` (71 hits over 48 beads) and `cannot` /
`can't` (56 over 41). Both are absence-shaped English and both are dominated
here by prescription ("the fix is not to widen the rule") and by tool blind-spot
prose ("this cannot see a claim phrased without its needles"), which is
this repo's house style in a NOT COVERED line rather than a claim about the game.
Adding either roughly doubles the corpus and makes the ranking noise. `without`
(35/30) and `the only` (30/26) were excluded on the same grounds. They are named
here so the next reader knows they were considered, not missed.

# fixture:   tools/_fixture_claims.jsonl, since deleted -- 12 lines, rebuildable
#            from this list. MUST FIRE: five needle classes and no citation /
#            two claims and all three citation shapes (`game/hud.gd:76`,
#            `` `game/sfx.gd:86` ``, `(:91)`) / a claim only in `notes` / a claim
#            only in the TITLE / `exactly 80 health` twice (the -lk0n shape).
#            MUST NOT FIRE: a CLOSED bead dense with claims / a bead carrying an
#            `ABSENCE CLAIM RESOLVED` note / a bead whose only "no" is `no
#            longer` + `no matter` + `No doubt` / a bead whose only phrasings are
#            the deliberately excluded ones (`is not`, `cannot`, `without`, `the
#            only`) / a plain request with no needle. Plus `9:00`, `1:2` and
#            `Vector2(1, 2)`, which must score ZERO citations, and one
#            deliberately malformed JSON line, which must be COUNTED not dropped.
#            Baseline over it: 11 parsed +1 malformed, 10 open, 1 closed, 7 carry
#            a claim, 1 waived, 6 unresolved / 12 claims / 3 citations / 5 cite
#            nothing.
#
#            The fixture found three bugs that reading the code did not. (1) The
#            bare `:NN` pattern matched the `9:00` in `9:00 am` because the
#            lookbehind allowed a digit. (2) Overlapping needles ("there is no
#            test") were counted three times because spans were not merged --
#            inflating exactly the beads the ranking puts on top. (3) Two
#            must-NOT-fire cases fired, on their own TITLES, because a bead
#            *about* absence claims uses the vocabulary of one. That third one is
#            not fixable and is now in the NOT COVERED line; it is why -htnt,
#            -thoj and -9vq6 rank high on the real corpus.
#
#            The fixture's durable replacement is `--self-test`: 14 hand-written
#            known-in/known-out cases over the transform itself, which ship in
#            this file and cannot be deleted with a scratch directory.
#
# mutations: measured 2026-08-17. Three corpora each time -- the REAL export
#            (436 issues / 164 open), the fixture, and `--self-test`. The real
#            baseline is `143 of 164 open carry a claim, 13 waived, 130
#            unresolved carrying 360 claims and 194 citations, 76 cite nothing,
#            control 13/13 (strength 2, -qewq)`, exit 0. Restore was re-run last
#            and matched it exactly.
#
#   A. `waived = bool(WAIVER.search(...))` -> `False`
#        REAL 13 -> 0 waived, 130 -> 143 unresolved, 360 -> 465 claims, 194 ->
#        252 citations. All 13 cycle-104 beads rejoin and -qdsi enters the top 3
#        at 15 claims. SELF-TEST SURVIVES, correctly: the waiver is policy, not
#        transform, and only the corpus run can see it.
#   B. delete the `nothing` needle
#        REAL 143 -> 128 carry, 130 -> 115 unresolved, 360 -> 277 claims.
#        THE POSITIVE CONTROL SURVIVED AT 13 of 13, against my prediction, and
#        that is the most useful thing in this block: the needle set is redundant
#        over prose this dense, so "does a waived bead still match anything" is
#        nearly unfailable. It is why the control now prints its own STRENGTH
#        (which does move here, 2 -> 1) and why `--self-test` exists. SELF-TEST
#        RED: `'Nothing calls it.' claims 0/1`.
#   B2. B, plus `if field != "notes"` -> `if True` in the control
#        Every REAL number identical to B. So excluding `notes` from the control
#        is NOT what keeps it alive -- redundancy is. Kept because the exclusion
#        is still correct, but it is not load-bearing on its own.
#   B3. delete `nothing` AND `never`
#        CONTROL GOES RED, naming plant-tower-defense-fjqp -- the weakest waived
#        bead, which relies on exactly those two classes. REAL 143 -> 117 carry,
#        130 -> 105 unresolved, 360 -> 244 claims. Exit stays 0 throughout, which
#        is the point: an advisory exit code cannot see a needle set shrinking,
#        and every count moves DOWN, which reads exactly like progress.
#        SELF-TEST RED, 2 failures.
#   C. drop span merging (`merge` returns `sorted(spans)`)
#        REAL 360 -> 390 claims; fixture 12 -> 17. The top three keep their order
#        (I predicted a reorder and was wrong) but every count inflates by however
#        many synonymous needles a bead happens to trip. SELF-TEST RED and it
#        names the mechanism outright: `'There is no test for the shop screen.'`
#        -> 3 claims for one sentence, `'The boss has no sprite.'` -> 2.
#   D. `FIELDS` -> `("description",)`
#        REAL 143 -> 142 carry, 360 -> 378 claims, 194 -> 214 citations -- both UP,
#        because this ALSO silently disables the waiver (13 -> 0), the resolution
#        notes living in `notes`. Two mutations for the price of one; noted rather
#        than split, because it is the real coupling: the waiver needs `notes`
#        read. SELF-TEST SURVIVES (field selection is not the transform).
#   E. `CITE_BARE` -> a never-matching pattern
#        REAL 194 -> 154 citations, i.e. 40 of 194 are the bare `:NN`
#        continuation form; fixture 3 -> 2. Beads-citing-nothing does not move on
#        the real corpus, so the exit code and headline count both survive and
#        only the citation column knows. SELF-TEST RED.
#   F. `\bno (?!longer\b|matter\b|doubt\b)` -> `\bno `
#        REAL 360 -> 364. Four `no longer` hits, every one prose about the code
#        HAVING changed -- the opposite of an absence claim. Fixture is the loud
#        one: 6 -> 7 unresolved beads as fx-nolonger joins. SELF-TEST RED.
#   G. `CITE_BARE` lookbehind removed entirely
#        REAL 194 -> 194: SURVIVED on the real corpus, which contains no
#        `9:00`-shaped prose. Fixture 3 -> 5 and SELF-TEST RED. Kept precisely
#        because it is the mutation the real corpus cannot see -- the argument for
#        having a fixture and a self-test at all, in one line.
"""

import argparse
import json
import re
import sys
from pathlib import Path

# This tool prints prose written by someone else, and that prose is full of
# em-dashes and smart quotes. citation_check.py shipped after three --quiet runs
# and died on its first plain one with a UnicodeEncodeError on a cp1252 console,
# in the mode a human actually uses when investigating. Same exposure here.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(errors="replace")

DEFAULT_JSONL = Path(".beads") / "issues.jsonl"

# Every prose field a claim about the code can live in. `close_reason` is absent
# on purpose: only closed issues carry one and closed issues are out of scope.
# Mutation D is the evidence that all five are worth reading.
FIELDS = ("title", "description", "design", "acceptance_criteria", "notes")

# ---------------------------------------------------------------------------
# The needle set. MOST SPECIFIC FIRST -- overlapping matches are merged into one
# claim and take the label of the first pattern in this list that produced them,
# so `there is no test` is one `no_test` claim and not three of anything.
NEEDLES = [
    ("no_test", re.compile(r"\bno (?:unit |bridge |automated |real )?tests?\b", re.I)),
    ("there_is_no", re.compile(r"\bthere (?:is|are|was|were) (?:currently |presently )?no\b", re.I)),
    ("has_no", re.compile(r"\b(?:has|have|had) (?:no|none)\b", re.I)),
    ("no_way_to", re.compile(r"\bno way to\b", re.I)),
    # The canonical absence shape, and the highest-yield needle after `nothing`.
    # `no longer` / `no matter` / `no doubt` are the only three non-claims this
    # corpus produces (mutation F), so they are excluded by name rather than by
    # narrowing the rule until it stops working.
    ("no_X", re.compile(r"\bno (?!longer\b|matter\b|doubt\b)[a-z][a-z-]+\b", re.I)),
    ("nothing", re.compile(r"\bnothing\b", re.I)),
    ("nowhere", re.compile(r"\bnowhere\b", re.I)),
    ("none", re.compile(r"\bnone\b", re.I)),
    ("never", re.compile(r"\bnever\b", re.I)),
    ("does_not", re.compile(r"\b(?:does|do|did)\s*n[o’']?t\b", re.I)),
    ("not_built", re.compile(
        r"\b(?:unbuilt|not (?:implemented|built|wired|written|hooked|connected"
        r"|used|called|covered|tested|reachable|exercised))\b", re.I)),
    # Written as three alternatives rather than `\black(s|ing)?\b`: `\block\b`
    # is what that abbreviates to under a typo and it matches the word "lock".
    ("lacks", re.compile(r"\black\b|\blacks\b|\blacking\b", re.I)),
    ("absent", re.compile(r"\babsent\b", re.I)),
    # A count claim rots exactly like a negation and for the same reason -- the
    # -lk0n boss had "exactly" a number of something, and the number had moved.
    ("exactly_N", re.compile(
        r"\bexactly (?:a|one|two|three|four|five|six|seven|eight|nine|ten|\d+)\b", re.I)),
    ("only_N", re.compile(
        r"\bonly (?:one|two|three|four|five|six|seven|eight|nine|ten|\d+)\b", re.I)),
]

# A claim carrying coordinates is checkable in seconds; one without is not. Two
# forms, because this project writes both and a tool that saw only the first
# would report most of the corpus as uncheckable.
CITE_FULL = re.compile(
    r"[A-Za-z0-9_./-]*[A-Za-z0-9_-]\.(?:gd|py|md|json|tscn|tres|gdshader)"
    r":\d+(?:-\d+)?")
# The continuation form: "(`game/sfx.gd:86`, `:91`, `:106`)" and "at :448".
# The lookbehind is load-bearing -- without it `9:00` and `Vector2(1, 2):3` are
# citations. It must be a space, an opening bracket or a backtick.
CITE_BARE = re.compile(r"(?<=[\s(\[`]):\d+(?:-\d+)?\b")

# The waiver: the bead already records a verdict reached against the code. Cycle
# 104's notes are the first form; the other two are what a human writing one
# freehand tends to produce.
#
# ANCHORED TO THE START OF A LINE. citation_check.py shipped this same waiver idea as
# a bare substring and the FIRST bead its --beads mode closed waived ITSELF, because
# the close reason explaining the waiver contained the marker: 468 beads became 467,
# three citations left the denominator, exit code stayed 0, nothing said a word.
#
# The exposure here is the same one and arguably sharper, because this checker's own
# NOT COVERED line already admits the neighbouring version of it: "it cannot tell a
# claim from a QUOTATION of one: a bead about absence claims uses their vocabulary".
# A bead about the RESOLUTION convention quotes the resolution vocabulary, and
# unanchored that quotation removed the bead from the denominator entirely -- which is
# strictly worse than the over-counting the NOT COVERED line describes, because an
# extra claim is visible in the ranking and a missing bead is not.
#
# MEASURED before changing it, against .beads/issues.jsonl at 479 issues: TWELVE
# matches, and every single one sits at column 0. Anchoring moves nothing -- the
# waived set, the positive control and the control STRENGTH line are all unchanged --
# it only closes the door. SELF_TEST_WAIVER's last three cases are the guard.
WAIVER_BODY = (r"ABSENCE CLAIMS? (?:RE)?(?:SOLVED|CHECKED|VERIFIED)"
               r"|CLAIMS? (?:RE)?VERIFIED AGAINST THE CODE"
               r"|CLAIMS? RE-?CHECKED AGAINST THE (?:CODE|REPO)")
WAIVER = re.compile(r"^[ \t>*+-]*(?:" + WAIVER_BODY + r")", re.I | re.M)


def merge(spans):
    """Merge OVERLAPPING (start, end, rank, label) spans, keeping the label of the
    first contributor in NEEDLES order. Adjacent-but-disjoint spans stay separate:
    "nothing calls it and nothing writes it" is two claims, and should be.

    Without this, `there is no test` is a `no_test` hit, a `there_is_no` hit and
    a `no_X` hit -- three claims for one sentence, and it inflates precisely the
    beads the ranking puts on top (mutation C).
    """
    out = []
    for start, end, rank, label in sorted(spans):
        if out and start < out[-1][1]:
            prev_start, prev_end, prev_rank, prev_label = out[-1]
            if rank < prev_rank:
                prev_rank, prev_label = rank, label
            out[-1] = (prev_start, max(prev_end, end), prev_rank, prev_label)
        else:
            out.append((start, end, rank, label))
    return out


def claims_in(text):
    """Return merged (start, end, rank, label) claim spans for one field."""
    spans = []
    for rank, (label, pat) in enumerate(NEEDLES):
        for m in pat.finditer(text):
            spans.append((m.start(), m.end(), rank, label))
    return merge(spans)


def citations_in(text):
    spans = [(m.start(), m.end(), 0, "full") for m in CITE_FULL.finditer(text)]
    spans += [(m.start(), m.end(), 1, "bare") for m in CITE_BARE.finditer(text)]
    return merge(spans)


def load(path):
    """Return (issues, parse_errors). Never silently drop a malformed line."""
    issues, errors = [], 0
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            errors += 1
            continue
        if obj.get("_type") == "issue":
            issues.append(obj)
    return issues, errors


def examine(obj):
    """(claims, citations, classes, waived, snippet, control_classes) for one issue.

    `control_classes` is the set of needle classes matched OUTSIDE `notes`, and
    both halves of that were forced by a mutation.

    Excluding `notes`: a resolution note is itself prose about absence -- "STILL
    TRUE, nothing in the HUD reads it" -- so counting it meant a waived bead
    matched a needle because of the WAIVER rather than because of the claim the
    waiver resolved.

    Counting CLASSES rather than claims: even excluding notes, mutation B
    (delete the `nothing` needle) left the control reading 13 of 13, because the
    needle set is redundant over prose this dense. A control that survives losing
    a needle is the "positive control that cannot fail" house-static-checker
    warns about. It is kept -- it does fire on a broad collapse -- but its
    STRENGTH is now printed beside it as the smallest number of distinct classes
    any waived bead relies on, so a reader can see how weak it is. The strong
    guard is `--self-test`, which is the direct known-in/known-out test of the
    transform that the skill prescribes instead.
    """
    prose = {f: obj.get(f) for f in FIELDS}
    whole = "\n".join(v for v in prose.values() if isinstance(v, str))
    waived = bool(WAIVER.search(whole))

    claims, citations, classes, sample = 0, 0, {}, None
    control_classes = set()
    for field, text in prose.items():
        if not isinstance(text, str) or not text.strip():
            continue
        found = claims_in(text)
        for start, end, _rank, label in found:
            claims += 1
            classes[label] = classes.get(label, 0) + 1
            if field != "notes":
                control_classes.add(label)
            if sample is None:
                lo = max(0, start - 34)
                hi = min(len(text), end + 42)
                sample = (field, text[lo:hi].replace("\n", " / ").strip())
        citations += len(citations_in(text))
    return claims, citations, classes, waived, sample, control_classes


# ---------------------------------------------------------------------------
# The direct test of the transform. Known-in, known-out, written by hand.
# house-static-checker: "Nine lines of known-in, known-out beats any statistic
# over the real corpus." Every expectation below was PREDICTED before it was
# run; the two that were wrong are marked, because a self-test whose answers
# were copied from the output it is testing proves nothing.
SELF_TEST = [
    # text,                                                claims, first class, cites
    ("Nothing calls it.",                                       1, "nothing",     0),
    ("There is no test for the shop screen.",                   1, "no_test",     0),
    ("The boss has no sprite.",                                 1, "has_no",      0),
    ("The old rule is no longer applied, no matter what.",      0, None,          0),
    ("It does not reset (game/hud.gd:76).",                     1, "does_not",    1),
    ("See `game/sfx.gd:86` (:91) and (:106).",                  0, None,          3),
    ("Meet at 9:00 with Vector2(1, 2) at a 1:2 ratio.",         0, None,          0),
    ("The boss has exactly 80 health.",                         1, "exactly_N",   0),
    ("It cannot ship without the only fix, which is not done.", 0, None,          0),
    ("It is nowhere, and it never ran.",                        2, "nowhere",     0),
]

SELF_TEST_WAIVER = [
    ("ABSENCE CLAIM RESOLVED (cycle 104 sweep, -g1o4): STILL TRUE.", True),
    ("Claims re-checked against the code: all four stand.",          True),
    ("  - ABSENCE CLAIMS VERIFIED: two of three still stand.",       True),
    ("There is no absence claim on this bead at all.",               False),
    ("",                                                             False),
    # The incident, restated as a case. citation_check.py's --beads waiver was a bare
    # substring and the first bead it closed waived itself on the sentence explaining
    # the waiver. These three are prose ABOUT the resolution convention -- exactly
    # what a bead filed to change that convention contains -- and none of them is a
    # verdict reached against the code. Unanchor WAIVER (drop the `^[ \t>*+-]*` and
    # re.M) and all three go red; nothing else in this file moves.
    ("The waiver is any note reading ABSENCE CLAIM RESOLVED, which is why a bead "
     "describing it drops out of the denominator.",                  False),
    ("Cycle 104 wrote 13 notes; a bead saying its claims re-checked against the code "
     "mid-sentence is not one of them.",                             False),
    ("Acceptance: the close reason says CLAIMS VERIFIED AGAINST THE CODE somewhere "
     "in a paragraph, and the bead vanishes from the count.",        False),
]


def self_test():
    """Return the number of failures, printing each. Exit 2 if any fail: a
    broken transform means every number the tool printed is unverified."""
    fails = 0
    for text, want_claims, want_first, want_cites in SELF_TEST:
        got = claims_in(text)
        cites = len(citations_in(text))
        first = got[0][3] if got else None
        ok = (len(got) == want_claims and first == want_first and cites == want_cites)
        if not ok:
            fails += 1
        print("  %-6s %-56s claims %d/%d  first %-11s/%-11s  cites %d/%d"
              % ("ok" if ok else "FAIL", repr(text)[:56], len(got), want_claims,
                 first, want_first, cites, want_cites))
    for text, want in SELF_TEST_WAIVER:
        got = bool(WAIVER.search(text))
        ok = got == want
        if not ok:
            fails += 1
        print("  %-6s waiver %-52s %s/%s"
              % ("ok" if ok else "FAIL", repr(text)[:52], got, want))
    print("self-test: %d case(s), %d failure(s) -- this tests the TRANSFORM "
          "(needle matching, span merging, citation shapes, the waiver), not the "
          "corpus. A clean corpus run over a broken transform is the failure this "
          "exists to make impossible."
          % (len(SELF_TEST) + len(SELF_TEST_WAIVER), fails))
    return fails


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("jsonl", nargs="?", default=str(DEFAULT_JSONL),
                    help="beads export to scan (default %s)" % DEFAULT_JSONL)
    ap.add_argument("--top", type=int, default=10,
                    help="how many ranked beads to print (default 10, a cycle's worth; "
                         "0 = all). The denominator lines always describe ALL of them, "
                         "and the tail line says how many were not printed -- that "
                         "number is the one cycle 104 lost.")
    ap.add_argument("--quiet", action="store_true",
                    help="denominators and the NOT COVERED line only, no ranking")
    ap.add_argument("--strict", action="store_true",
                    help="exit 1 when any open bead carries an unresolved claim "
                         "(default is advisory, exit 0)")
    ap.add_argument("--self-test", action="store_true",
                    help="run the known-in/known-out test of the transform and stop")
    args = ap.parse_args(argv)

    if args.self_test:
        return 2 if self_test() else 0

    path = Path(args.jsonl)
    if not path.exists():
        print("bead_claim_check: CANNOT RUN -- %s does not exist. Run `bd list` once "
              "to force an export, or pass the path explicitly." % path)
        return 2

    issues, parse_errors = load(path)
    if not issues:
        print("bead_claim_check: CANNOT RUN -- parsed 0 issues out of %s (%d malformed "
              "line(s)). An empty scan is not a clean scan." % (path, parse_errors))
        return 2

    open_issues = [i for i in issues if i.get("status") != "closed"]
    if not open_issues:
        print("bead_claim_check: CANNOT RUN -- %d issue(s) parsed and every one of them "
              "is closed. This tool ranks OPEN beads; a corpus with none is not a clean "
              "result, it is the wrong input." % len(issues))
        return 2

    rows, waived_rows, control_misses = [], [], []
    weakest = None
    for obj in open_issues:
        claims, cites, classes, waived, sample, control = examine(obj)
        row = (claims, cites, classes, obj.get("id", "?"),
               obj.get("priority", 9), obj.get("title", ""), sample)
        if waived:
            waived_rows.append(row)
            # The positive control: a past sweep judged this bead to carry an
            # absence claim. If today's needle set cannot find one OUTSIDE the
            # resolution note, the needle set has narrowed -- and the finding
            # count alone will never say so, because it only ever goes down.
            if not control:
                control_misses.append(obj.get("id", "?"))
            elif weakest is None or len(control) < weakest[0]:
                weakest = (len(control), obj.get("id", "?"))
        elif claims:
            rows.append(row)

    # Rank: density first, then priority (P0 before P3), then id for stability.
    rows.sort(key=lambda r: (-r[0], _prio(r[4]), r[3]))

    carrying = len(rows) + len([r for r in waived_rows if r[0]])
    total_claims = sum(r[0] for r in rows)
    total_cites = sum(r[1] for r in rows)
    uncited = [r for r in rows if r[1] == 0]

    print("bead_claim_check: %d issue(s) parsed from %s -- %d open, %d closed and NOT "
          "scanned" % (len(issues), path, len(open_issues), len(issues) - len(open_issues)))
    print("                  %d of %d open bead(s) carry at least one absence claim; "
          "%d waived by a resolution note already on the bead"
          % (carrying, len(open_issues), len([r for r in waived_rows if r[0]])))
    print("                  %d UNRESOLVED bead(s) carry %d claim(s) and %d citation(s); "
          "%d of them cite nothing at all"
          % (len(rows), total_claims, total_cites, len(uncited)))
    if parse_errors:
        print("                  WARNING: %d line(s) in the export did not parse and were "
              "NOT scanned." % parse_errors)

    if carrying == 0:
        print("NOTE: nothing to rank -- not one of the %d open beads matched any of the "
              "%d needle classes. That is a clean result only if you expected this "
              "tracker to make no claims about what the repo lacks, which for a backlog "
              "would be extraordinary. Suspect the needle set before believing it."
              % (len(open_issues), len(NEEDLES)))
    elif not rows:
        print("NOTE: %d open bead(s) carry claims and EVERY ONE is waived by a resolution "
              "note. Nothing is unresolved. Check the notes are recent -- a waiver here "
              "never expires." % carrying)

    # The control, WITH its own strength printed beside it. Bare, it reads like a
    # guarantee; the second half says how many needle classes would have to be
    # lost before it could notice, which on this corpus is 2. `--self-test` is
    # the guard that does not depend on the corpus at all.
    print("                  positive control: %d of %d waived bead(s) still match at "
          "least one needle outside their resolution note%s"
          % (len(waived_rows) - len(control_misses), len(waived_rows),
             "" if not control_misses else " -- FAILED"))
    if weakest and not control_misses:
        print("                  control STRENGTH: the weakest waived bead (%s) relies on "
              "%d distinct needle class(es), so this line cannot go red until that many "
              "are lost at once. Run --self-test for the guard that does not depend on "
              "the corpus." % (weakest[1], weakest[0]))
    if control_misses:
        print("CONTROL FAILED: a past sweep recorded a resolved absence claim on %s, and "
              "today's needle set finds no claim there at all. The needle set has "
              "narrowed: a phrasing it used to catch, it no longer does. Fix the needles "
              "before trusting any count above -- every one of them only ever goes DOWN "
              "when a needle is lost, which looks exactly like progress."
              % ", ".join(sorted(control_misses)))

    if not args.quiet and rows:
        shown = rows if args.top <= 0 else rows[:args.top]
        print("")
        print("RANKED (densest first, ties by priority). claims/cites:")
        for claims, cites, classes, iid, prio, title, sample in shown:
            klass = " ".join("%s x%d" % (k, v) for k, v in
                             sorted(classes.items(), key=lambda kv: -kv[1]))
            flag = "  <-- NO CITATION" if cites == 0 else ""
            print("  %3d claims / %3d cites  P%s  %s%s" % (claims, cites, prio, iid, flag))
            print("        %s" % title[:96])
            print("        classes: %s" % klass)
            if sample:
                print("        [%s] ...%s..." % (sample[0], sample[1]))
        if args.top > 0 and len(rows) > args.top:
            print("  ... and %d more unresolved bead(s) not printed. They are counted in "
                  "the denominator above; use --top 0 to see all of them. THIS IS THE "
                  "NUMBER CYCLE 104 LOST: 123 beads that were never reached."
                  % (len(rows) - args.top))
        print("")
        print("  fix: read the bead's absence claims against the code as it is NOW, then "
              "record the verdict ON THE BEAD as a note beginning `ABSENCE CLAIM "
              "RESOLVED (cycle N sweep): STILL TRUE` / `REFUTED` / `PARTLY OVERTAKEN`, "
              "the way the 13 cycle-104 notes do. Write it to a FILE and pass it with "
              "`bd update --stdin` / `--body-file`, never as a shell argument -- see "
              "bead_prose_check.py for what the shell does to backticked prose.")
        print("  waive: that note IS the waiver. There is no second convention and no "
              "waiver list to drift.")

    print("NOT COVERED: this finds the SHAPE of an absence claim in prose. It cannot tell "
          "you whether the claim is TRUE -- that is a human reading the code, and it is "
          "the entire remaining cost. It cannot see a claim phrased without one of its %d "
          "needle classes ('the shop screen is still a stub', 'we only ever got as far as "
          "the sprite', 'TODO: wire this up' -- all real absence claims, all invisible "
          "here), and `is not`, `cannot`, `without` and `the only` are excluded on purpose "
          "as too noisy on this corpus, so anything phrased only that way is missed too. "
          "It cannot tell a claim from a QUOTATION of one: a bead about absence claims "
          "uses their vocabulary, which is why -htnt, -thoj and -9vq6 rank high here and "
          "why two of this tool's own must-not-fire fixture cases fired on their titles. "
          "It COUNTS citation shapes and does not resolve them -- a bead may cite "
          "`game/hud.gd:900` in a 300-line file and still score a citation; "
          "citation_check.py resolves citations but only in markdown files handed to it, "
          "and nothing in this repo resolves a citation living in bead prose. The waiver "
          "never expires, so a verdict reached in cycle 104 silences a bead forever. And "
          "it reads the JSONL export, not the Dolt DB: a bead updated since the last "
          "export is scanned as it was." % len(NEEDLES))

    if args.strict and rows:
        return 1
    return 0


def _prio(value):
    """Sort key for a priority that may be an int, a 'P2', or missing."""
    if isinstance(value, int):
        return value
    text = str(value)
    digits = re.sub(r"[^0-9]", "", text)
    return int(digits) if digits else 9


if __name__ == "__main__":
    sys.exit(main())
