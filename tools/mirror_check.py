#!/usr/bin/env python3
"""mirror_check.py - CLAUDE.md and AGENTS.md carry the same Workflow block, and it
has now been silently deleted from AGENTS.md twice.

WHY THIS EXISTS, and what was actually wrong.

The two files are independent (not symlinked, not sharing an inode) and both are
loaded as instructions, by different tools. The Workflow block is meant to be
identical in both. Its own note says so:

    > This Workflow block is mirrored verbatim in `AGENTS.md`. The two files are
    > independent (not symlinked), and a sync that only knows about one of them
    > silently deleted this section once already - keep both copies in step.

That note is inside the block it protects, which is the whole problem. Commit
727765d rewrote the workflow in CLAUDE.md and dropped the entire section from
AGENTS.md, leaving the warning about the deletion sitting above nothing - the
second occurrence, committed by the change that wrote the warning. AGENTS.md's copy
of the block was 19 characters against CLAUDE.md's 8816 and nothing noticed for a
cycle, because nothing in the loop ever opens AGENTS.md.

A prose warning inside the thing it warns about is not a check. This is the check.

Nothing else in the toolchain can see it:

  * every other gate here reads `.gd`, `.tscn`, `.svg` or `.py`. Two markdown files
    disagreeing is not a defect any of them has a category for.
  * `name_check.py` / `lint_project.gd` / the suite: instructions are not code.
  * a human reading either file sees a complete, coherent document. That is exactly
    what makes the failure survive - the surviving copy looks fine, and the gutted
    one looks like a file that simply does not carry that section.

The rule: the text between the block's start marker and its end marker must be
byte-identical in both files, after normalising line endings (this checkout is CRLF
via core.autocrlf, and a raw compare would report drift on every line of two
identical files - the same trap /verify's own drift check documents).

Parallel-safe by construction: opens no project, writes nothing to `.godot/`, takes
no lock. Exit codes follow the house contract: 0 clean, 1 findings, 2 could not run.
"""

from __future__ import annotations

import argparse
import difflib
import os
import sys

# Where the mirrored block starts in each file, and what ends it. The start marker
# is the block's own heading; the end is the next top-level section, which is NOT
# mirrored (each file has its own tail).
START = "# workflow"
# Tried in order: the first one present ends the block. CLAUDE.md has the project
# section after it; AGENTS.md's tail begins at its first horizontal rule.
ENDS = ("# Project Instructions for AI Agents", "\n---\n")
FILES = ("CLAUDE.md", "AGENTS.md")


def read_block(path: str) -> tuple[str | None, str]:
    """(block text, reason it is missing). Line endings normalised to \\n.

    Normalising is not cosmetic: with core.autocrlf this checkout has CRLF on disk,
    and a byte compare of two identical blocks reports every line as different.

    `newline=""` disables Python's universal-newline translation on purpose, so the
    normalisation below is the thing actually doing it. Without it the open() call
    silently did the same job and this line was dead code with a comment claiming it
    was load-bearing -- found by mutating it out and watching the CRLF fixture pass
    anyway, which is the whole argument for mutating a checker rather than only
    feeding it bad input. A transform nobody can turn off is a transform nobody has
    tested.
    """
    try:
        with open(path, "r", encoding="utf-8", newline="") as fh:
            text = fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        return None, "cannot read %s (%s)" % (path, exc)
    text = text.replace("\r\n", "\n")
    start = text.find(START)
    if start < 0:
        return None, "%s has no %r heading at all" % (path, START)
    end = -1
    for marker in ENDS:
        at = text.find(marker, start + len(START))
        if at >= 0 and (end < 0 or at < end):
            end = at
    if end < 0:
        end = len(text)
    return text[start:end].rstrip("\n"), ""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="project root (default: cwd)")
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--show-diff", action="store_true",
                    help="print a unified diff of the two blocks when they differ")
    args = ap.parse_args()

    root = os.path.abspath(args.root)
    blocks: dict[str, str] = {}
    for name in FILES:
        path = os.path.join(root, name)
        if not os.path.isfile(path):
            print("mirror_check: no %s at %s - cannot run." % (name, root), file=sys.stderr)
            return 2
        block, why = read_block(path)
        if block is None:
            # A missing heading is a FINDING, not a "cannot run": that is precisely
            # the failure this tool exists for, and reporting it as an infrastructure
            # problem would hide the defect behind an exit code nobody gates on.
            if why.startswith("cannot read"):
                print("mirror_check: %s - cannot run." % why, file=sys.stderr)
                return 2
            print("mirror_check: 0 of 2 file(s) carry the mirrored block")
            print("  FINDING: %s. The Workflow block has been deleted from it before "
                  "-- twice -- and the warning against doing so lives INSIDE the block, "
                  "so it goes with it.\n"
                  "    fix: copy the block from the other file verbatim. Generate it "
                  "rather than retyping it, so the two are identical by construction "
                  "rather than by care." % why)
            return 1

        blocks[name] = block

    a, b = blocks[FILES[0]], blocks[FILES[1]]
    lines_a = a.count("\n") + 1
    lines_b = b.count("\n") + 1

    if not args.quiet:
        print("mirror_check: %s %d line(s)/%d chars, %s %d line(s)/%d chars, %s"
              % (FILES[0], lines_a, len(a), FILES[1], lines_b, len(b),
                 "identical" if a == b else "DIFFERENT"))
        if len(a) < 200:
            print("  NOTE: the block is only %d characters. That is small enough to be "
                  "a stub rather than the workflow -- a mirror of two empty things is "
                  "identical and means nothing." % len(a))
        print("  NOT COVERED: this compares one named block in two named files. It says "
              "nothing about whether the block's CONTENT is correct, whether the rest of "
              "either file agrees with it, or whether any other prose in the repo has "
              "drifted. It cannot tell which copy is the good one when they differ -- "
              "read the diff. And a block deleted from BOTH files at once compares "
              "equal: see the character-count note above, which is the only guard "
              "against that.")

    if a == b:
        return 0

    detail = ""
    if args.show_diff:
        detail = "\n" + "\n".join(
            "      " + line for line in difflib.unified_diff(
                a.splitlines(), b.splitlines(), FILES[0], FILES[1], lineterm="", n=1))
    print("  FINDING: the Workflow block differs between %s (%d lines) and %s (%d lines).\n"
          "    This has happened twice by silent deletion, once committed by the very "
          "change that wrote the note warning about it -- and that note lives inside the "
          "block, so it is removed along with what it protects.\n"
          "    fix: decide which copy is current (usually %s, where the loop is edited), "
          "then GENERATE the other from it rather than retyping -- identical by "
          "construction beats identical by care. Re-run with --show-diff to see what "
          "moved.%s" % (FILES[0], lines_a, FILES[1], lines_b, FILES[0], detail))
    return 1


if __name__ == "__main__":
    sys.exit(main())
