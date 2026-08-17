#!/usr/bin/env python3
"""Resolve every `path:LINE` citation in a markdown file and print what it lands on.

WHY THIS EXISTS (plant-tower-defense-a4hk). This project's workflow requires every
backlog entry to cite a `file:line` for the claim it makes about the code as it is now.
The citations are written by hand and the code moves under them -- twice a citation was
wrong at the moment it was committed, because the *same edit* that added it shifted the
lines it pointed at. The six-line script that catches that has been retyped in seven
separate cycles; this is that script, once.

The point is not convenience. Run over a whole file rather than the paragraph being
edited, it is an audit nobody has done: `kanban.md` is 2700+ lines, says at its own top
that roughly half is stale, and every citation inside a stale entry is a candidate for
having drifted silently.

WHICH GATE WOULD HAVE CAUGHT THIS AND WHY IT DOES NOT. None. Lint and the test suite
never read markdown. `name_check.py` resolves GDScript identifiers, not prose. A citation
that points at the wrong line is invisible to every engine gate by construction, because
nothing about it is code.

READ THE OUTPUT, NOT THE EXIT CODE. This resolves citations; it cannot tell you whether
the landed line SUPPORTS the claim around it. Cycles 68 and 76 both wrote a citation that
resolved cleanly to a doc-comment line one above the constant it meant.

Usage:
    python tools/citation_check.py [FILE ...]         # default kanban.md
    python tools/citation_check.py --quiet FILE       # findings only, no landed lines
    python tools/citation_check.py --baseline PATH FILE
    python tools/citation_check.py --baseline-write PATH FILE

Exit 0 clean, 1 findings, 2 could not run.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_FILES = ["kanban.md"]

# A citation is a backticked path with at least one directory part, a colon, a line, and
# optionally a `-` and an end line. The directory part is what keeps `Vector2(1.0, 1.0)`
# and prose like `9:00` out of the match.
CITATION = re.compile(
    r"`([A-Za-z0-9_./-]+/[A-Za-z0-9_.-]+\.(?:gd|py|md|json|tscn|tres|gdshader))"
    r":(\d+)(?:-(\d+))?`"
)


def citations(text: str) -> list[tuple[int, str, int, int]]:
    """(markdown_line, path, start, end) for every citation, in file order."""
    out: list[tuple[int, str, int, int]] = []
    for lineno, line in enumerate(text.splitlines(), start=1):
        for m in CITATION.finditer(line):
            start = int(m.group(2))
            end = int(m.group(3)) if m.group(3) else start
            out.append((lineno, m.group(1), start, end))
    return out


def key(path: str, start: int, end: int) -> str:
    return "%s:%d-%d" % (path, start, end)


def _printable(s: str) -> str:
    """Drop what this console cannot encode, rather than dying on it.

    Source lines here are full of em-dashes and arrows. On a Windows console defaulting
    to cp1252, printing one raises `UnicodeEncodeError` and the whole run dies with a
    traceback — a checker taken out by its own output. Found by running the tool WITHOUT
    `--quiet`, which is the mode that prints source and therefore the mode the first three
    runs of it never used.
    """
    enc = (sys.stdout.encoding or "utf-8")
    return s.encode(enc, errors="replace").decode(enc, errors="replace")


def uncited_entries(text: str) -> tuple[int, int]:
    """(entries, entries carrying no citation) for markdown top-level bullets.

    The denominator that matters. A first run over `kanban.md` reported 130 citations,
    all 130 resolving, which reads as a clean file -- and is really a statement about the
    half of it written since the cite-a-file:line rule landed in cycle 30. The other half
    makes claims with no coordinates at all and is invisible to this checker, to every
    other checker, and to anything that could ever be automated. A checker that says
    "0 findings" without saying that is the exact failure `house-static-checker` calls a
    clean result over an empty input set.

    An entry is a top-level `- ` bullet plus its indented continuation lines.
    """
    entries = 0
    uncited = 0
    current: list[str] = []

    def flush() -> None:
        nonlocal entries, uncited
        if not current:
            return
        entries += 1
        if not CITATION.search("\n".join(current)):
            uncited += 1

    for line in text.splitlines():
        if line.startswith("- "):
            flush()
            current = [line]
        elif current and (line.startswith("  ") or line.startswith("\t")):
            current.append(line)
        elif current and not line.strip():
            current.append(line)
        else:
            flush()
            current = []
    flush()
    return entries, uncited


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("files", nargs="*", default=None)
    ap.add_argument("--quiet", action="store_true",
                    help="findings only; do not print the landed line for each citation")
    ap.add_argument("--baseline", metavar="PATH",
                    help="split findings into NEW and PRE-EXISTING against a snapshot")
    ap.add_argument("--baseline-write", metavar="PATH",
                    help="write the current findings as a snapshot and exit 0")
    args = ap.parse_args(argv[1:])

    targets = [Path(f) for f in (args.files or DEFAULT_FILES)]
    missing = [t for t in targets if not (ROOT / t).is_file() and not t.is_file()]
    if missing:
        print("citation_check: cannot read %s"
              % ", ".join(str(m) for m in missing), file=sys.stderr)
        return 2

    baseline: set[str] = set()
    if args.baseline:
        bp = Path(args.baseline)
        if bp.is_file():
            try:
                baseline = set(json.loads(bp.read_text(encoding="utf-8")))
            except ValueError as exc:
                print("citation_check: baseline %s is not readable JSON: %s" % (bp, exc),
                      file=sys.stderr)
                return 2
        else:
            print("citation_check: baseline %s does not exist -- every finding will "
                  "report as NEW, which is a statement about the baseline rather than "
                  "about the file." % bp, file=sys.stderr)

    total = 0
    files_seen = 0
    entries_total = 0
    entries_uncited = 0
    findings: list[tuple[str, str]] = []   # (key, message)
    resolved = 0

    for target in targets:
        path = target if target.is_file() else ROOT / target
        text = path.read_text(encoding="utf-8", errors="replace")
        found = citations(text)
        files_seen += 1
        total += len(found)
        e, u = uncited_entries(text)
        entries_total += e
        entries_uncited += u
        for md_line, cited, start, end in found:
            src = ROOT / cited
            k = key(cited, start, end)
            if not src.is_file():
                findings.append((k, "FINDING: %s:%d cites %s -- no such file.\n"
                                    "  fix: the file was renamed or removed; find where "
                                    "the claim lives now, or delete the entry.\n"
                                    "  waive: none."
                                 % (path.name, md_line, k)))
                continue
            try:
                lines = src.read_text(encoding="utf-8", errors="replace").splitlines()
            except OSError as exc:
                # Exists but will not open. The contract says a checker that could not
                # look is a 2, never a clean 0 -- found by mutating the branch above and
                # watching this line traceback instead.
                print("citation_check: %s is present but unreadable: %s" % (cited, exc),
                      file=sys.stderr)
                return 2
            if start < 1 or end > len(lines) or end < start:
                findings.append((k, "FINDING: %s:%d cites %s -- out of range; %s has %d "
                                    "line(s).\n  fix: re-derive the line number; an edit "
                                    "that ADDS lines above a citation moves it silently.\n"
                                    "  waive: none."
                                 % (path.name, md_line, k, cited, len(lines))))
                continue
            resolved += 1
            if not args.quiet:
                body = _printable(" | ".join(l.strip()[:60] for l in lines[start - 1:end]))
                print("  %-34s %s" % (k, body))

    if args.baseline_write:
        Path(args.baseline_write).write_text(
            json.dumps(sorted(k for k, _ in findings), indent=2) + "\n", encoding="utf-8")
        print("citation_check: wrote %d finding(s) to %s as a baseline."
              % (len(findings), args.baseline_write))
        return 0

    new = [(k, m) for k, m in findings if k not in baseline]
    pre = [(k, m) for k, m in findings if k in baseline]

    print("citation_check: %d citation(s) across %d file(s), %d resolved, %d finding(s)"
          % (total, files_seen, resolved, len(findings))
          + (" (%d NEW, %d pre-existing)" % (len(new), len(pre)) if baseline else ""))
    if entries_total:
        print("             %d of %d entr%s carry NO citation at all -- invisible to this "
              "check and to every other one. A clean result above is a statement about the "
              "%d that do."
              % (entries_uncited, entries_total, "y" if entries_total == 1 else "ies",
                 entries_total - entries_uncited))
    if total == 0:
        print("NOTE: no citations found at all. That is a clean result only if you "
              "expected a file with none -- the pattern needs a backticked path with a "
              "directory part, so `plant.gd:12` alone does not match by design.")
    for _, message in (new if baseline else findings):
        print(message)
    if baseline and pre:
        print("PRE-EXISTING (in the baseline, not gating): %d" % len(pre))
    print("NOT COVERED: this resolves citations; it cannot tell you whether the landed "
          "line SUPPORTS the claim around it -- cycles 68 and 76 each wrote a citation "
          "that resolved cleanly to a doc comment one line above the constant it meant. "
          "Read the printed lines, not the exit code. It also cannot see a citation "
          "written without a directory part, or one that has drifted onto a DIFFERENT but "
          "still-valid line, which is the common case and the one nothing can automate.")
    return 1 if new else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
