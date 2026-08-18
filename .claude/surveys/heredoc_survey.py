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
"""
import argparse
import io
import re
import subprocess
import sys

sys.path.insert(0, "tools")
import gdsource  # noqa: E402

PROSE = re.compile(r"^[ \t]*[A-Z][a-z]+(?: [A-Za-z,'-]+){2,}[.:,]?[ \t]*$")
CODE_TOKEN = re.compile(r"[=(){}\[\]:;]|->|\bfunc\b|\bvar\b|\bconst\b|\breturn\b")
NEWLINE = chr(10)

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
        for start, end, kind in gdsource.literal_spans(text):
            body = text[start:end]
            if kind != "string":
                continue
            if body.startswith('"""') or body.startswith("'''"):
                continue
            if NEWLINE in body:
                n = text.count(NEWLINE, 0, start) + 1
                a_hits.append((sha, subject, path, n, body.strip()[:100]))
        code = gdsource.strip_comments(text, gdsource.KEEP)
        for n, line in enumerate(code.splitlines(), 1):
            if line.strip() and PROSE.match(line) and not CODE_TOKEN.search(line):
                b_hits.append((sha, subject, path, n, line.strip()[:100]))

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
