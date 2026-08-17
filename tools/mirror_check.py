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

    fixture:   identical / block deleted from AGENTS.md (the historical failure) /
               one-line drift / CRLF on one side only / block gutted on BOTH sides
    mutations: drop the CRLF normalisation -> the CRLF fixture must go red.
               It did NOT the first time this was tried, because `open()` in text mode
               was silently doing the same job and the normalisation was dead code
               carrying a comment that claimed it mattered. That is what the mutation
               found, and it is why these two lines are kept rather than re-derived.

--fix (added later) generates AGENTS.md's block from CLAUDE.md's, because the FINDING
message had been telling the reader to do exactly that since this file was written and
nobody could act on it without this function. Its fixture and mutation set:

    fixture:   identical (no write) / one-line drift (repaired, and a SECOND run is
               byte-identical) / CRLF destination stays CRLF / inter-block whitespace
               preserved / AGENTS.md heading gone (refuse, explain) / CLAUDE.md heading
               gone (refuse, do not propagate a deletion) / a block containing `---` /
               write_mirror called directly on two matching files
    mutations: all six go red -- drop the CRLF restore, take the inter-block whitespace
               from the source instead of the destination, remove either refusal, neuter
               the truncation guard, skip the post-write re-read.

The `---` case is the one that paid. It was written expecting the post-write re-check to
catch a bad write; instead it exposed a defect in the ORIGINAL tool that had nothing to
do with --fix. See truncation_warning() below. Two fixture cases (the `---` block, and
the direct write_mirror call) exist specifically because a mutation survived without
them -- an untested guard is the thing this file's own history warns about.
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


def truncation_warning(path: str) -> str:
    """"" if the block ends where it should, else why the comparison is untrustworthy.

    ENDS carries `\\n---\\n` as AGENTS.md's terminator, and a horizontal rule is
    ordinary markdown. Put one inside the Workflow block and it ends the block early
    -- in BOTH files, equally -- so the two truncated stubs compare identical and this
    tool reports clean over a comparison that covered a fraction of the text. Found by
    the --fix fixture, which fed it a block containing `---` expecting the post-write
    re-check to catch it; instead both sides truncated to 21 characters and agreed.

    The signal is order: ENDS is listed most-specific first, so if a LATER (more
    generic) marker won while an earlier one also exists further down the file, the
    generic one matched something inside the block rather than after it.
    """
    try:
        with open(path, "r", encoding="utf-8", newline="") as fh:
            text = fh.read().replace("\r\n", "\n")
    except (OSError, UnicodeDecodeError):
        return ""
    span = _span(text)
    if span is None:
        return ""
    hits = [(text.find(m, span[0] + len(START)), i) for i, m in enumerate(ENDS)]
    hits = [(at, i) for at, i in hits if at >= 0]
    if not hits:
        return ""
    at, which = min(hits)
    later_specific = [i for a, i in hits if i < which and a > at]
    if not later_specific:
        return ""
    return ("%s: the block was ended by %r at offset %d, but %r -- which is more "
            "specific and listed first -- appears LATER in the same file. That means "
            "the generic marker matched INSIDE the block (a horizontal rule in the "
            "workflow text), so only the first %d characters are being compared and "
            "everything after them is unchecked in both files."
            % (path, ENDS[which], at, ENDS[later_specific[0]], at - span[0]))


def _span(text: str) -> tuple[int, int] | None:
    """(start, end) of the block in ALREADY-NORMALISED text, or None if no heading.

    `end` is the offset of the end marker (or EOF), NOT the end of the block's own
    text -- the newlines between them belong to the destination file's formatting
    and are preserved by write_mirror() rather than regenerated. Splicing without
    that distinction is how a hand-run sync left a stray blank line before the
    horizontal rule in AGENTS.md, which is a whitespace-churn diff pretending to be
    a content sync.
    """
    start = text.find(START)
    if start < 0:
        return None
    end = -1
    for marker in ENDS:
        at = text.find(marker, start + len(START))
        if at >= 0 and (end < 0 or at < end):
            end = at
    return start, (len(text) if end < 0 else end)


def write_mirror(src_path: str, dst_path: str) -> tuple[bool, str]:
    """Generate dst's block from src's. Returns (changed, message).

    This exists because the FINDING message has told the reader to "GENERATE the
    other from it rather than retyping" since this tool was written, and nobody
    could act on that advice without writing this function -- so every cycle that
    touched the Workflow block retyped the edit by hand, and one of them desynced
    the files again on the very commit that added a rule about being careful.

    Two traps, both paid for by doing it manually first:
      * the "\\n---\\n" end marker cannot match raw CRLF text, so the search must
        happen on normalised text and the convention be restored on write;
      * the two files' end markers sit at different offsets, so the inter-block
        whitespace must be carried from the DESTINATION, not from the source.
    """
    def load(path: str) -> tuple[str, bool]:
        with open(path, "r", encoding="utf-8", newline="") as fh:
            raw = fh.read()
        return raw.replace("\r\n", "\n"), ("\r\n" in raw)

    src, _ = load(src_path)
    dst, dst_crlf = load(dst_path)
    s_span, d_span = _span(src), _span(dst)
    # Refuse rather than invent. A source with no block would propagate a deletion;
    # a destination with no heading gives nowhere to put one, and guessing an
    # insertion point is how a tool turns a reported defect into a silent edit.
    if s_span is None:
        return False, ("%s has no %r heading -- refusing to generate FROM a file that "
                       "carries no block. Restore it there first." % (src_path, START))
    if d_span is None:
        return False, ("%s has no %r heading -- refusing to guess where the block "
                       "belongs. Paste the heading back, then re-run --fix." % (dst_path, START))
    block = src[s_span[0]:s_span[1]].rstrip("\n")
    tail_ws = dst[d_span[0]:d_span[1]][len(dst[d_span[0]:d_span[1]].rstrip("\n")):]
    out = dst[:d_span[0]] + block + tail_ws + dst[d_span[1]:]
    if out == dst:
        return False, "%s already matches %s -- nothing written." % (dst_path, src_path)
    if dst_crlf:
        out = out.replace("\n", "\r\n")
    with open(dst_path, "w", encoding="utf-8", newline="") as fh:
        fh.write(out)
    return True, ("generated %s's block from %s (%d chars, %s line endings)"
                  % (dst_path, src_path, len(block), "CRLF" if dst_crlf else "LF"))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="project root (default: cwd)")
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--show-diff", action="store_true",
                    help="print a unified diff of the two blocks when they differ")
    ap.add_argument("--fix", action="store_true",
                    help="generate %s's block from %s, then re-check. Writes a file; "
                         "the only flag here that does. Idempotent -- a second run is "
                         "a no-op." % (FILES[1], FILES[0]))
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
            if args.fix:
                # The heading is gone entirely, so there is no span to replace and
                # --fix cannot help. Say that here rather than letting write_mirror's
                # refusal read like a bug in the flag.
                print("    --fix cannot repair this: it replaces a block between "
                      "markers, and the %r heading is missing, so there is nowhere to "
                      "put one. Paste the heading back and re-run --fix." % START)
            return 1

        blocks[name] = block

    # Before comparing, check the comparison is over the whole block. Two truncated
    # stubs compare identical, which is a clean report over nothing -- the same
    # empty-denominator failure the house checker contract exists to prevent.
    truncated = [w for w in (truncation_warning(os.path.join(root, n)) for n in FILES) if w]
    if truncated:
        print("mirror_check: the mirrored block is TRUNCATED -- not comparing what you think")
        for w in truncated:
            print("  FINDING: %s\n"
                  "    fix: remove the horizontal rule from the Workflow block, or give "
                  "%s a terminator that cannot occur inside it." % (w, FILES[1]))
        return 1

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

    if args.fix:
        changed, message = write_mirror(
            os.path.join(root, FILES[0]), os.path.join(root, FILES[1]))
        print("  --fix: %s" % message)
        if not changed:
            return 1
        # Re-read from disk rather than trusting the write. The point of generating
        # is to be identical by construction, and a --fix that reports success
        # without re-checking is exactly the "identical by care" it replaces.
        again_a, _ = read_block(os.path.join(root, FILES[0]))
        again_b, _ = read_block(os.path.join(root, FILES[1]))
        if again_a is not None and again_a == again_b:
            print("  --fix: re-checked from disk, the blocks are now identical.")
            return 0
        print("  --fix: WROTE THE FILE AND THE BLOCKS STILL DIFFER. Do not trust the "
              "write -- inspect %s by hand." % FILES[1], file=sys.stderr)
        return 1

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
