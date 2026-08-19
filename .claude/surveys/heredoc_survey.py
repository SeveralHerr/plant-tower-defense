#!/usr/bin/env python3
"""Sweep this repo's whole git history for the two signatures of heredoc damage.

plant-tower-defense-hb43. Run from the repo root:

    python <this file>

THIS SCRIPT WAS DAMAGED BY THE THING IT MEASURES, TWICE, WHILE BEING WRITTEN.

  1. A first version scanned diff LINES and reported 554 hits, every one false: a
     prose comment in which a quoted phrase wrapped across two `#` lines. Counting
     quotes per line cannot tell a broken string from a sentence.
  2. A second version was edited through `python - <<'PY'` and the heredoc ate the
     backslash in every "\\n", turning the escape into a literal newline inside a
     string literal -- an unterminated string, at the exact line the patch touched.
     That is the cycle-97 shape (a Python script in a heredoc, a second escaping
     layer) reproduced by the person surveying how often it happens.

Both are recorded here rather than quietly fixed, because a survey that reports 554
non-findings and a survey that reports 0 findings look equally like work -- and
because incident 2 IS data for the bead.

SIGNATURE A -- a GDScript string literal containing a literal newline.
  Asked of `gdsource.literal_spans`, which is the same scanner pass that does the
  blanking, so it cannot disagree with it about where a literal begins and ends. A
  hand-rolled `(?<!\\)"` regex does NOT know that `\\\\` is an escaped backslash, and
  reported every `if c == "\\\\":` in the suite as a broken string.

SIGNATURE B -- a comment block whose leading '#' is missing.
  The four incidents CLAUDE.md names all had this shape: prose sitting at statement
  position with no marker. Almost all are hard parse errors, which is why they were
  caught the same day -- so the question is whether any ever SURVIVED into a commit.

  THE ANSWER IS NO, AND THE DETECTOR WAS REWRITTEN ANYWAY (plant-tower-defense-n228).
  History reports 0 hits over every .gd version in it -- 1048 when this was written, and
  that count only grows -- both BEFORE the rewrite and AFTER it, over the same corpus.
  Nothing of this shape has ever reached a commit, because lint catches it the same day.
  So SIGNATURE B earns its place in --worktree mode ONLY -- the pre-commit window,
  and the parallel fan-out where lint cannot run because two engine gates at once
  corrupt each other's `.godot/`. In history mode it is a null result being re-confirmed.

  The first detector could not have found the incident it was written for. It asked
  two questions of a line, and this repo's comments fail both:

      PROSE      required the line to START with a capitalised word -- but a wrapped
                 comment continues mid-sentence, which is exactly the cycle-125 line
                 ("reason Hud.selection_level_names() is ...").
      CODE_TOKEN excluded any line containing a paren, colon, bracket or arrow --
                 and this codebase's comments cite function names constantly.

  Measured against a corpus DERIVED rather than imagined: take every one of this
  repo's 27,755 prose-shaped comment lines and delete its marker, which is precisely
  the damage. The old rule found 6.3% of them (1,742). The leading-capital test alone
  discarded 70.4%; CODE_TOKEN alone discarded 30.9%. A detector with 6% recall reports
  0 for the same reason an unplugged smoke alarm does.

  What replaced it asks one question instead, and it is a fact about the GRAMMAR
  rather than a guess about English: GDScript has no production in which two bare
  identifiers sit side by side separated only by whitespace. Every such construct in
  the language spells one side as a keyword -- `var x`, `func f`, `a and b`, `x is Node`,
  `await sig`, `class_name Foo`, `for i in`. Prose is made of nothing else. So a line
  at statement position holding an adjacent pair of non-keyword words cannot be
  GDScript, whatever punctuation it also contains.

  Recall 97.1% (26,949 of 27,755), against the old rule's 6.3% (1,742) over the same
  corpus. The 806 misses are honest and mostly quote-heavy: a comment line that is
  largely a `{ "key": String }` shape has its literals erased and little prose left.
  `Do not touch` is missed too -- three words, and `not` is a keyword.

  False positives, on every corpus that exists:

      0 of    47,143 statement lines in the working tree
      0 of 2,074,810 statement lines across every historical .gd version
      0 of        22 hand-written awkward-but-valid lines in the controls file,
                     including the Godot 3 spellings (`setget`, `export(int) var`)

  The old rule is a strict subset: 0 of the 1,742 lines it caught are missed by the
  new one, so nothing was traded away to buy the recall.

  `heredoc_survey_controls.py` re-measures all of this on every run and fails on a
  single false positive, so these numbers are a check rather than a claim.
"""
import argparse
import io
import re
import subprocess
import sys

sys.path.insert(0, "tools")
import gdsource  # noqa: E402

NEWLINE = chr(10)

# Every GDScript word that may legally stand beside a bare identifier. This is the whole
# detector: a pair of adjacent words NEITHER of which is in here cannot be GDScript.
#
# It is hand-written, which .claude/skills/derive-the-list warns about -- so here is the
# tripwire that makes a forgotten entry cheap. A missing keyword does not cause a silent
# miss; it causes a FALSE POSITIVE on the very next run, because --worktree scans every
# tracked .gd file in full and history scans two million statement lines. Both currently
# report 0. A keyword left out of this set would be sitting in that output, named, with
# its file and line number. The failure mode points at itself.
#
# The Godot 3 spellings are here because history contains them and a file copied in from
# a 3.x project would too. `setget set_thing, get_thing` is the one that bites: both
# words are bare identifiers to a scanner that does not know 3.x.
GD_KEYWORDS = frozenset([
    "if", "elif", "else", "for", "while", "match", "when", "break", "continue",
    "pass", "return", "breakpoint",
    "func", "static", "var", "const", "enum", "signal", "class", "class_name",
    "extends", "abstract", "trait", "namespace",
    "and", "or", "not", "in", "is", "as", "await", "yield",
    "self", "super", "true", "false", "null", "void", "assert", "preload",
    "tool", "export", "onready", "setget", "remote", "remotesync", "sync",
    "master", "mastersync", "puppet", "puppetsync", "slave",
])

ADJACENT_WORDS = re.compile(r"([A-Za-z_][A-Za-z_0-9]*)[ \t]+([A-Za-z_][A-Za-z_0-9]*)")


def bare_word_pairs(line):
    """Every (left, right) identifier pair separated by whitespace and NOTHING else.

    Overlapping on purpose. `an instance virtual` must yield both (an, instance) and
    (instance, virtual); re.finditer consumes the shared token and would report half the
    pairs in a sentence, which matters because a single keyword in the middle of a line
    would then blank out its neighbour's pair as well.

    Anything between the two words other than spaces and tabs -- a dot, a comma, a paren,
    a colon, an operator -- means they are not adjacent and no pair is produced. That is
    what keeps `Hud.selection_level_names()` and `a, b` out of the count.
    """
    out, pos = [], 0
    while True:
        m = ADJACENT_WORDS.search(line, pos)
        if m is None:
            return out
        out.append((m.group(1), m.group(2)))
        pos = m.start(2)


def prose_at_statement_position(line):
    """True when a line of BLANKED GDScript cannot be GDScript at all.

    The caller must pass a line from `gdsource.strip_comments(text, gdsource.ERASE)`:
    comments blanked, string bodies AND their quotes gone. ERASE rather than KEEP is
    load-bearing -- with the literals left in, `print("hello world")` is two adjacent
    bare words and this returns True on working code. That is the 554-false-positive
    family the header records, and passing the wrong mode brings it straight back.
    """
    if not line.strip():
        return False
    return any(a not in GD_KEYWORDS and b not in GD_KEYWORDS
               for a, b in bare_word_pairs(line))

# Built by joining, not by embedding escapes. THE THIRD TIME THIS FILE HAS BEEN DAMAGED BY
# THE THING IT MEASURES: the header records two, and writing this very constant through a
# shell heredoc turned every "\n" into a real newline inside a string literal -- an
# unterminated string, at exactly the lines the patch touched, which is SIGNATURE A. Joining
# a list of plain lines has no escape to eat.
NOT_COVERED = NEWLINE.join([
    "NOT COVERED: two signatures, and neither of them is a parse. SIGNATURE A asks",
    "             gdsource for string literals and reports one containing a newline;",
    "             SIGNATURE B looks for comment prose that lost its leading '#'. A heredoc",
    "             that ate a backslash somewhere else -- a regex, a path, a format string",
    "             -- produces neither signature and is invisible here. Nor does this",
    "             compile: only import_check.py and lint_project.gd do that, and neither is",
    "             parallel-safe.",
    "             HISTORY mode cannot see an uncommitted defect at all, and --worktree",
    "             cannot see one already committed and since fixed. They answer different",
    "             questions and neither subsumes the other.",
    "             SIGNATURE B covers 97.1% of this repo's comment lines with the marker",
    "             deleted (26,949 of 27,755), 0 false positives over 2,121,953 statement",
    "             lines. What it misses: prose whose every adjacent word pair holds a",
    "             GDScript keyword ('Do not touch'), and quote-heavy lines whose literals",
    "             are erased before the scan. A one- or two-word comment ('# TODO',",
    "             '# why?') has no adjacent pair at all and is invisible by construction.",
    "             SIGNATURE B has never once fired on history: 0 in every .gd version,",
    "             before the widening and after it. Every instance was a hard parse error",
    "             lint caught the same day. Its value is --worktree only: the window",
    "             before a commit, and a parallel fan-out where lint cannot run.",
])



def gd_versions():
    """Every (sha, subject, path) where a commit changed a .gd file."""
    out = subprocess.run(
        ["git", "log", "--all", "--no-merges", "--name-only",
         "--format=%x00%H%x00%s", "--", "*.gd"],
        capture_output=True, text=True, errors="replace", check=True,
    ).stdout
    sha = subject = ""
    for line in out.splitlines():
        if line.startswith("\x00"):
            _, sha, subject = line.split("\x00", 2)
        elif line.strip().endswith(".gd"):
            yield sha, subject, line.strip()


def blobs(pairs):
    """Batch-read every (sha, path) blob in one git cat-file process."""
    req = "".join("%s:%s%s" % (s, p, NEWLINE) for s, p in pairs)
    proc = subprocess.run(["git", "cat-file", "--batch"], input=req.encode(),
                          capture_output=True)
    data, i, out = proc.stdout, 0, []
    for _ in pairs:
        nl = data.index(NEWLINE.encode(), i)
        header = data[i:nl].decode(errors="replace").split()
        if len(header) < 3:                      # "missing"
            out.append(None)
            i = nl + 1
            continue
        size = int(header[2])
        out.append(data[nl + 1:nl + 1 + size].decode("utf-8", errors="replace"))
        i = nl + 1 + size + 1
    return out


def worktree_versions():
    """Every tracked .gd file as it is ON DISK right now.

    plant-tower-defense-h613. The history sweep above reads BLOBS, so it cannot see a
    defect that has not been committed -- and the defect this survey exists for is
    introduced while editing, which is precisely before the commit. Cycle 111 broke a
    string literal, ran this survey, and got `SIGNATURE A: 0 hit(s)` over a live parse
    error; only lint caught it, and lint is not parallel-safe.

    Same tuple shape as gd_versions() so main() consumes either without branching, with
    the sha slot reading "worktree" -- a place a sha would go, filled with what is
    actually true, rather than a blank that reads as a missing value.
    """
    out = subprocess.run(["git", "ls-files", "*.gd"],
                         capture_output=True, text=True, errors="replace",
                         check=True).stdout
    for path in out.splitlines():
        path = path.strip()
        if path:
            yield "worktree", "(uncommitted working tree)", path


def read_worktree(paths):
    """Read each path off disk, None for one that will not open."""
    out = []
    for p in paths:
        try:
            out.append(io.open(p, encoding="utf-8", errors="replace").read())
        except OSError:
            out.append(None)
    return out


def signature_a(text):
    """Yield (line_number, excerpt) for every string literal holding a real newline.

    A function rather than a loop inside main() so heredoc_survey_controls.py can assert
    THIS code instead of a second copy of it. The controls file used to carry its own
    transcription of both detectors; a control that tests a copy stops being a control
    the moment the copy drifts, and it drifts silently because both halves still pass.
    """
    for start, end, kind in gdsource.literal_spans(text):
        body = text[start:end]
        if kind != "string":
            continue
        if body.startswith('"""') or body.startswith("'''"):
            continue
        if NEWLINE in body:
            yield text.count(NEWLINE, 0, start) + 1, body.strip()[:100]


def signature_b(text):
    """Yield (line_number, excerpt) for every line of prose sitting at statement position."""
    raw_lines = text.splitlines()
    code = gdsource.strip_comments(text, gdsource.ERASE)
    for n, line in enumerate(code.splitlines(), 1):
        if prose_at_statement_position(line):
            # Report the RAW line, not the blanked one. strip_comments is exactly length-
            # and newline-preserving, so index n-1 is the same line in both; an operator
            # handed `tr(          )` cannot tell what he is looking at.
            shown = raw_lines[n - 1] if n <= len(raw_lines) else line
            yield n, shown.strip()[:100]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--worktree", action="store_true",
                    help="scan tracked .gd files AS THEY ARE ON DISK instead of sweeping "
                         "history -- the mode that can see a defect you have not committed")
    args = ap.parse_args(argv)

    if args.worktree:
        versions = list(worktree_versions())
        print("scanning %d tracked .gd file(s) in the WORKING TREE (uncommitted changes "
              "included)" % len(versions))
        texts = read_worktree([p for _, _, p in versions])
    else:
        versions = list(dict.fromkeys(gd_versions()))
        print("scanning %d (commit, .gd file) version(s) from HISTORY -- this cannot see "
              "an uncommitted defect; use --worktree for that" % len(versions))
        texts = blobs([(s, p) for s, _, p in versions])

    a_hits, b_hits, scanned = [], [], 0
    for (sha, subject, path), text in zip(versions, texts):
        if text is None:
            continue
        scanned += 1
        for n, shown in signature_a(text):
            a_hits.append((sha, subject, path, n, shown))
        for n, shown in signature_b(text):
            b_hits.append((sha, subject, path, n, shown))

    print("scanned %d file version(s)" % scanned)
    if scanned == 0:
        # A zero denominator says so in words. "0 hits" over nothing looks
        # exactly like "0 hits" over everything.
        print("NOTHING WAS SCANNED -- no .gd file version was readable.")
        print("That is not a clean result; it is an empty one.")
        return 2
    for name, hits in (("SIGNATURE A  string literal broken across a newline", a_hits),
                       ("SIGNATURE B  comment prose with no leading #", b_hits)):
        print("")
        print("=== %s: %d hit(s)" % (name, len(hits)))
        for sha, subject, path, n, line in hits[:25]:
            print("  %s  %s:%d" % (sha[:9], path, n))
            print("      %s" % line)
            print("      in: %s" % subject[:88])
        if len(hits) > 25:
            print("  ... and %d more" % (len(hits) - 25))
    print(NOT_COVERED)
    # EXIT CODE DEPENDS ON THE MODE, and conflating them would produce the permanently-red
    # gate .claude/skills/house-static-checker warns about.
    #
    # A hit in HISTORY is a defect that already happened and was already fixed -- the very
    # first version of this survey documents two of them, in itself. Gating on those means a
    # red run forever, which teaches its operator to skip the check and then it is not there
    # for the one that matters.
    #
    # A hit in the WORKING TREE is a live defect in a file on disk right now. That gates.
    if args.worktree:
        return 1 if (a_hits or b_hits) else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
