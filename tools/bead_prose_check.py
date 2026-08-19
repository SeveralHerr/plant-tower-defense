#!/usr/bin/env python3
r"""Find bead prose that the shell ate on its way into the tracker.

WHY THIS EXISTS. `bd create -d "..."`, `bd close --reason "..."` and
`bd update --notes "..."` all pass prose through the shell, where backticks are
command substitution. Three failure shapes, in increasing order of nastiness:

  1. LOUD   -- the backticked word is not a command. It vanishes, the shell
               prints `foo: command not found` on stderr, and the prose is left
               with a gap. Easy to miss beside beads' own export chatter, but at
               least something was printed.
  2. SILENT -- the backticked word IS a command (`date`, `time`, `pwd`, `find`,
               `whoami`): its OUTPUT lands in the field. Nothing is printed and
               the field still reads like prose.
  3. MUTE   -- the command produces no output at all (`test`, `true`, `false`,
               `:`). Indistinguishable from shape 1 in the finished text.

WHICH EXISTING GATE WOULD HAVE CAUGHT THIS, AND WHY IT DOESN'T. None of them,
and not by accident. `name_check.py` and the ten house checkers all read
`game/`, `test/` and `tools/` -- source. Bead prose lives in a Dolt DB exported
to `.beads/issues.jsonl`, which no gate has ever opened. Nor could a linter
help: the damage happens in the shell BEFORE `bd` is invoked, so `bd` receives a
well-formed string and stores it faithfully. The corruption is complete and
consistent by the time any tool downstream can see it. Only the text's own shape
gives it away.

WHY A CHECKER RATHER THAN A NOTE. `.claude/skills/cycle/SKILL.md` step 6 has
told this project not to pass prose as a shell argument since cycle 83. It was
then broken in cycles 76, 78, 83 and 91 -- the last one *after* the rule was
written, in a close reason about being careful. A note ignored four times is the
wrong countermeasure; this is the right one.

THE WAIVER IS THE CORRECTION NOTE. The bead that asked for this
(plant-tower-defense-lbmk) requires that anything found is "corrected with a
note rather than silently rewritten, so the record of the mistake survives". So
that is exactly the waiver: an issue carrying a correction note in any of its
prose fields is waived, and its damaged text is left standing as the record.
There is no hand-maintained waiver list to drift.

# fixture:   eaten word between two lowercase words / eaten word after an
#            article / `date` output mid-sentence / a Git-Bash `pwd` path / a
#            space before a comma  ... and, as the must-NOT-fire half: house
#            `:1331` citation shorthand, a padded measurement literal
#            ('Wave  9999 infinity   threat 99'), a DELIBERATE Windows path
#            (log.md's real location), two-spaces-after-a-period house style,
#            an already-corrected issue, and a closed issue.
#            The fixture found two bugs in this tool that reading it did not:
#            the Git-Bash pattern matched nothing at all, and the `  +` quantifier
#            flagged the padded literal.
#
# mutations: numbers below are OBSERVED against .beads/issues.jsonl at 419
#            issues / 1166 prose fields, whose clean baseline is
#            `0 gating, 4 advisory (closed), 3 waived` and exit 0.
#
#   A. `is_waived = False`                      -> RED. 0 -> 1 gating, 4 -> 6
#        advisory, 3 -> 0 waived, exit 0 -> 1. The three historical incidents
#        (-e1u3, -a4hk, -b3nt) come back, which is the point of the waiver.
#   B. add `:` to the space-before-comma class  -> RED, but only 0 -> 2 gating.
#        NOTE THE NUMBER: I predicted ~150 and was wrong, because the house
#        citation shorthand is `at :1331` -- space, colon, DIGIT -- and this
#        pattern requires a space AFTER the punctuation too. The rule that
#        actually had to be killed was an earlier `\S +[.,;:)]` with no
#        lookahead, which produced 155 findings of which ~150 were the citation
#        shorthand and the repo's own `.claude/` and `.github/` paths. Both
#        mutations are worth keeping: B as written proves the lookahead is
#        load-bearing, and the 155 is why the naive rule is not in this file.
#   C. `  (?! )` -> `  +` in both GAP patterns  -> RED on the fixture
#        (6 -> 7 gating: the padded literal). On the real corpus it moves
#        4 -> 5 advisory (-saaw's 'Wave  9999 infinity   threat 99') and leaves
#        gating at 0 and the exit code at 0 -- i.e. the regression is REAL and
#        the exit code cannot see it. That is the argument for the fixture in
#        one line: a mutation this tool's own gate reports as clean.
"""

import argparse
import json
import re
import sys
from pathlib import Path

# This tool's whole job is to print prose written by someone else, and that
# prose is full of em-dashes and smart quotes. citation_check.py shipped after
# three --quiet runs and died on its first plain one with a UnicodeEncodeError,
# on a cp1252 console, in the mode a human actually uses when investigating.
# Same exposure here, so: never let the console encoding take the tool out.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(errors="replace")

DEFAULT_JSONL = Path(".beads") / "issues.jsonl"

# Every prose field a shell argument can reach.
FIELDS = ("title", "description", "design", "notes", "acceptance_criteria", "close_reason")

# ---------------------------------------------------------------------------
# Shape 1 / 3: a hole where a word was.
#
# The naive "space before punctuation" rule is USELESS on this corpus. The house
# citation shorthand writes `the confirmation at :1331`, and repo paths start
# with a dot (`.claude/skills/`, `.github/workflows/`). Both are a space before
# punctuation and both are correct. So `:` is excluded outright, and `.` counts
# only when it ends a sentence -- never when it opens a path segment.
GAP_PATTERNS = [
    # A double space BETWEEN two lowercase words is the shape an eaten `word`
    # leaves behind: cycle 91's close reason read "whose  MEANT one kind".
    # Excluded: after `.`/`:`/`)`/`]`, which is deliberate house style or a
    # citation, and single letters, which appear in aligned tables.
    #
    # EXACTLY TWO SPACES, never more. The shell deletes the backticked token and
    # leaves the space on either side of it, so the hole is always two wide.
    # Three or more is alignment or padding -- the fixture's
    # 'Wave  9999 infinity   threat 99' measurement literal is a real corpus
    # entry (-saaw) that a `  +` pattern flags and a `  (?! )` pattern does not.
    (re.compile(r"(?<![.:)\]])\b([a-z]{2,})  (?! )([a-z]{2,})\b"),
     "double space between two words"),
    # An article or preposition with a hole after it is the loudest shape there
    # is: "if the harness ever grows a  flag on an entry point".
    (re.compile(r"\b(the|a|an|whose|which|its|of|to|in|with|from|every)  (?! )\S"),
     "gap after article/preposition"),
    (re.compile(r"\S +[,;](?= )"), "space before comma/semicolon"),
    (re.compile(r"[a-z] +\.(?= [A-Z]|$)", re.M), "space before sentence-ending period"),
]

# Shape 2: command output that landed in prose. These are what the LOUD shape
# cannot show you, and the reason a scan was worth running at all.
OUTPUT_PATTERNS = [
    (re.compile(r"\b(Mon|Tue|Wed|Thu|Fri|Sat|Sun) "
                r"(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) [ 0-9]"),
     "`date` output"),
    (re.compile(r"\b\d{2}:\d{2}:\d{2}\b"), "clock time (`date` output)"),
    # Git-Bash renders C:\Users as /c/Users, and WSL as /mnt/c/Users. The first
    # draft of this pattern was `/(c|mnt)/[A-Za-z]/Users/`, which matches
    # NEITHER -- it expects a drive letter after /c/. The fixture caught it; no
    # amount of reading did.
    (re.compile(r"(^|[\s(])/(mnt/)?[a-z]/Users/", re.I), "Git-Bash absolute path (`pwd`)"),
    (re.compile(r"\breal\s+\dm[\d.]+s\b"), "`time` output"),
    (re.compile(r"\btotal \d+\ndrwx", re.M), "`ls -l` output"),
]

# The waiver: the issue already records that the shell ate something here.
#
# ANCHORED TO THE START OF A LINE, and the reason is an incident rather than a taste.
# citation_check.py shipped the same idea as a bare substring, and the FIRST bead its
# --beads mode ever closed waived ITSELF: the close reason explaining the waiver
# contained the marker. 468 beads became 467, three citations left the denominator,
# and the exit code stayed 0. This checker is more exposed than that one, not less --
# its waiver is not a deliberate marker but ORDINARY ENGLISH about shell damage, and
# the documents most likely to contain that English are beads about shell damage.
# Unanchored, a bead filed to report this failure mode waives itself while reporting
# it, which is the shape the whole cycle is about.
#
# MEASURED before changing it, against .beads/issues.jsonl at 479 issues: six matches
# over three beads (-qdsi, -a4hk, -b3nt). Every one of the three is waived by a
# `CORRECTION:` sitting at column 0. The other three matches are the freehand phrases
# ("...lost two words to shell backticks", columns 71, 16 and 36) INSIDE those same
# notes, and they waive nothing the anchored `CORRECTION:` does not already waive.
# So this is a pure tightening: the waived set does not move, and the self-waive is
# gone. If that ever stops being true, --self-check case 3 is the one that will say so.
#
# The bracket class matches citation_check.py's BEAD_WAIVER_LINE deliberately: leading
# whitespace, a markdown bullet, or a quote marker may precede the note, because that
# is how a note gets written inside a list. Nothing else may.
WAIVER_BODY = (r"CORRECTION:|eaten by (the )?shell|shell backticks"
               r"|words? (were|was) eaten")
WAIVER = re.compile(r"^[ \t>*+-]*(?:" + WAIVER_BODY + r")", re.I | re.M)


def snippet(text, at, width=76):
    lo = max(0, at - width // 2)
    hi = min(len(text), at + width // 2)
    return text[lo:hi].replace("\n", " / ")


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


def scan(issues):
    findings = []
    fields_scanned = 0
    waived = 0

    for obj in issues:
        iid = obj.get("id", "?")
        status = obj.get("status", "?")
        prose = {f: obj.get(f) for f in FIELDS}
        whole = "\n".join(v for v in prose.values() if isinstance(v, str))
        is_waived = bool(WAIVER.search(whole))

        for field, text in prose.items():
            if not isinstance(text, str) or not text.strip():
                continue
            fields_scanned += 1
            hits = []
            for pat, why in GAP_PATTERNS + OUTPUT_PATTERNS:
                for m in pat.finditer(text):
                    hits.append((why, snippet(text, m.start())))
            if not hits:
                continue
            if is_waived:
                waived += len(hits)
                continue
            for why, snip in hits:
                findings.append((iid, status, field, why, snip))

    return fields_scanned, findings, waived


# ---------------------------------------------------------------------------
# The waiver's own known-in / known-out table.
#
# This tool had no fixture of any kind before this: the `# fixture:` block at the top
# of the file describes one that was run by hand once and never again, and the
# mutations beside it are numbers a past session observed rather than anything a
# later run re-checks. So the waiver -- the one rule here that can REMOVE findings
# from the denominator, silently, with the exit code unchanged -- was the least
# guarded rule in the file.
#
# Every case is written as prose a human would actually type, never assembled from
# WAIVER's own pattern; copying the pattern in would make the table a tautology.
SELF_CHECK_WAIVER = [
    # (text, waived?, what this case is for)
    ("CORRECTION: two words were eaten by shell backticks when this was filed.",
     True, "the note as -b3nt actually writes it, at column 0"),
    ("  - CORRECTION: the sentence should read 'resolving every path-colon-line'.",
     True, "the same note inside a markdown bullet -- the bracket class earns its keep"),
    ("This bead is about the waiver itself: any bead whose prose says CORRECTION: "
     "anywhere at all is dropped from the count, which is how -9vq6 waived itself.",
     False, "THE INCIDENT. A bead DESCRIBING the marker must not be waived by it. "
            "Unanchor WAIVER and this case goes red."),
    ("The close reason was mangled because two words were eaten by the shell, and "
     "nothing said so.",
     False, "the freehand phrase mid-sentence: a report of the damage, not a "
            "correction note. Unanchor WAIVER and this case goes red."),
    ("`bd close --reason` passes prose through shell backticks, which is the whole "
     "problem.",
     False, "prose explaining the mechanism, quoting the phrase mid-line"),
    ("The description reads fine and nothing was lost.",
     False, "no waiver anywhere -- the ordinary case"),
    ("", False, "an empty field waives nothing"),
]


def self_check():
    """Return the number of failures, printing each.

    Exit 2 if any fail, matching bead_claim_check.py: a broken waiver means every
    `waived` number this tool has ever printed is unverified, and unlike a broken
    finding rule it fails QUIET -- findings leave the denominator and the exit code
    does not move.
    """
    fails = 0
    for text, want, why in SELF_CHECK_WAIVER:
        got = bool(WAIVER.search(text))
        ok = got == want
        if not ok:
            fails += 1
        print("  %-6s waiver %-5s/%-5s  %s" % ("ok" if ok else "FAIL", got, want, why))
    print("self-check: %d case(s), %d failure(s) -- this tests the WAIVER transform, "
          "not the corpus. Three of the cases are prose ABOUT the waiver and must not "
          "be waived by it; replacing WAIVER with the unanchored "
          "`re.compile(WAIVER_BODY, re.I)` turns those three red and is the intended "
          "way to prove this table is not decorative."
          % (len(SELF_CHECK_WAIVER), fails))
    return fails


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("jsonl", nargs="?", default=str(DEFAULT_JSONL),
                    help="beads export to scan (default %s)" % DEFAULT_JSONL)
    ap.add_argument("--all", action="store_true",
                    help="gate on closed issues too (default: report them as PRE)")
    ap.add_argument("--self-check", action="store_true",
                    help="run the waiver's known-in/known-out table and exit; "
                         "proves the waiver can reject prose that merely mentions it")
    args = ap.parse_args(argv)

    if args.self_check:
        return 2 if self_check() else 0

    path = Path(args.jsonl)
    if not path.exists():
        print("bead_prose_check: CANNOT RUN -- %s does not exist. Run `bd list` once to "
              "force an export, or pass the path explicitly." % path)
        return 2

    issues, parse_errors = load(path)
    if not issues:
        print("bead_prose_check: CANNOT RUN -- parsed 0 issues out of %s (%d malformed "
              "line(s)). An empty scan is not a clean scan." % (path, parse_errors))
        return 2

    fields_scanned, findings, waived = scan(issues)
    open_issues = [i for i in issues if i.get("status") != "closed"]

    gating = [f for f in findings if args.all or f[1] != "closed"]
    pre = [f for f in findings if not args.all and f[1] == "closed"]

    print("bead_prose_check: %d issue(s) (%d open), %d prose field(s) scanned across %s"
          % (len(issues), len(open_issues), fields_scanned, "/".join(FIELDS)))
    print("                  %d finding(s) gating, %d in closed issues (advisory), "
          "%d waived by a correction note already on the issue"
          % (len(gating), len(pre), waived))
    if parse_errors:
        print("                  WARNING: %d line(s) in the export did not parse and were "
              "NOT scanned." % parse_errors)
    if fields_scanned == 0:
        print("NOTE: nothing to check -- every issue's prose fields were empty. That is a "
              "clean result only if you expected no prose.")

    for iid, status, field, why, snip in gating + pre:
        tag = "FINDING" if (args.all or status != "closed") else "PRE"
        print("%s: %s [%s] %s -- %s" % (tag, iid, status, field, why))
        print("         ...%s..." % snip)
        print("  fix: do NOT silently rewrite the field. Add a correction note recording "
              "what the shell ate and what the sentence should say -- see "
              "plant-tower-defense-b3nt's notes for the worked example. Write the "
              "replacement prose to a FILE and pass it with `bd update --stdin` / "
              "`--body-file` / `--design-file`, never as a shell argument.")
        print("  waive: the correction note IS the waiver -- once the issue carries one, "
              "this stops firing and the damaged text stands as the record.")

    print("NOT COVERED: this reads the JSONL export, not the Dolt DB, and it reads TEXT. "
          "A substitution whose output happened to read like prose is invisible to it. So "
          "is a token eaten from between two spaces that then collapse, leaving no gap. It "
          "cannot distinguish an author's deliberate double space from an eaten word -- "
          "every finding needs a human read. And it says nothing about whether the prose "
          "that DID survive is true; that is citation_check.py's job, and citation_check "
          "only proves a line exists, never that it supports the claim.")

    return 1 if gating else 0


if __name__ == "__main__":
    sys.exit(main())
