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
WAIVER = re.compile(
    r"CORRECTION:|eaten by (the )?shell|shell backticks|words? (were|was) eaten",
    re.I,
)


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


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("jsonl", nargs="?", default=str(DEFAULT_JSONL),
                    help="beads export to scan (default %s)" % DEFAULT_JSONL)
    ap.add_argument("--all", action="store_true",
                    help="gate on closed issues too (default: report them as PRE)")
    args = ap.parse_args(argv)

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
