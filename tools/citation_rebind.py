#!/usr/bin/env python3
r"""Re-point drifted citations at the line their text moved to.

`citation_check --against` says a citation no longer lands on the text the snapshot
recorded. It cannot say where that text WENT, and the answer is usually mechanical: the
cited file grew above the citation and every line below shifted by the same amount. Cycle
176 faced 98 of these, nearly all in `kanban.md`, and hand-editing them is hours of work
with a transcription error in it somewhere.

WHAT MAKES THIS SAFE, and it is the only reason a fixer is acceptable here at all: the
snapshot stores the exact TEXT each citation landed on, so a rebind is "find this text in
this file" rather than "guess where it went". A target whose text now appears zero times,
or more than once, is NOT rebound -- it is reported for a human, because those are exactly
the cases where the text was edited or duplicated and the claim may no longer hold.

DRY RUN BY DEFAULT. `--apply` writes. Verify afterwards by re-running
`citation_check --beads --against <snapshot>`: the drift count must fall, and
`citation_check` must still report every citation resolving.

WHAT THIS DOES NOT DO, and cannot: it does not read the SENTENCE around the citation. A
line that moved because it was rewritten in place will be reported unmatched and left
alone; a line that moved because the file grew is rebound without anyone checking that the
prose still describes it. `citation_check`'s own contract caveat says the same thing from
the other side -- it proves a line exists, never that the line supports the claim. Rebinding
restores the POINTER, not the argument.

Exit 0 always: this reports and optionally edits, and there is no failure state that a
caller should gate on. Read the counts.

# fixture:   a citing doc + a cited file whose text moved down / text deleted / text
#            duplicated / citation already correct
# mutations: accept a multi-match instead of reporting it -> the duplicated fixture
#            rebinds to an arbitrary one of the two, which is the whole hazard
#            rewrite every `path:N` on the line rather than the cited one -> a line
#            citing two files has the wrong one changed
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

DRIFT_RE = re.compile(
    r"^DRIFTED: (?P<target>\S+)\s+\(written at (?P<doc>[^:]+):(?P<line>\d+)\)\s*$")


def load_drifts(text: str) -> list[dict]:
    """Every gating DRIFTED line, in order.

    Stops at the closed-bead header: those are advisory by the checker's own design --
    a closed bead is a record of what was true when it was written, and re-pointing its
    citations falsifies the record. `gap_ledger.py` takes the same position about
    superseded status lines.
    """
    out = []
    for raw in text.splitlines():
        if raw.startswith("DRIFTED IN A CLOSED BEAD"):
            break
        m = DRIFT_RE.match(raw)
        if m:
            out.append({"target": m.group("target"),
                        "doc": m.group("doc"), "line": int(m.group("line"))})
    return out


def find_text(haystack: str, needle: str) -> list[int]:
    """1-based start lines where `needle`'s lines appear consecutively in `haystack`.

    Compared line by line with trailing whitespace stripped, because the snapshot and the
    file can disagree about a trailing space without disagreeing about anything a reader
    would notice.
    """
    hay = [ln.rstrip() for ln in haystack.split("\n")]
    ned = [ln.rstrip() for ln in needle.split("\n")]
    if not ned or all(not ln for ln in ned):
        return []
    hits = []
    for i in range(len(hay) - len(ned) + 1):
        if hay[i:i + len(ned)] == ned:
            hits.append(i + 1)
    return hits


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--against", required=True, help="the snapshot citation_check used")
    ap.add_argument("--report", required=True,
                    help="a file holding citation_check --against's output")
    ap.add_argument("--root", default=".", help="project root (default: cwd)")
    ap.add_argument("--apply", action="store_true", help="write the rebinds (default: dry run)")
    args = ap.parse_args()

    try:
        with open(args.against, "r", encoding="utf-8") as fh:
            snapshot = json.load(fh)
        # errors="replace", because this file is usually a REDIRECT of the checker's
        # console output and Windows writes that in the console codepage -- an em-dash in
        # a quoted source line then makes a strict read raise UnicodeDecodeError and take
        # the whole tool down. The lines this parses are pure ASCII; the mangling only
        # ever lands in prose it ignores.
        with open(args.report, "r", encoding="utf-8", errors="replace") as fh:
            drifts = load_drifts(fh.read())
    except (OSError, ValueError) as exc:
        print("citation_rebind: cannot read inputs (%s)" % exc)
        return 0

    edits: dict[str, list[tuple[int, str, str]]] = {}
    rebound = unmatched = ambiguous = unwritable = 0
    for d in drifts:
        target = d["target"]
        if target not in snapshot:
            unmatched += 1
            print("  NO SNAPSHOT TEXT: %s (cited at %s:%d)" % (target, d["doc"], d["line"]))
            continue
        path, _, span = target.rpartition(":")
        old_start = span.split("-")[0]
        cited = os.path.join(args.root, path)
        if not os.path.isfile(cited):
            # The checker resolved it, so a miss here means the path in the citation is a
            # SUFFIX (`test_placement.gd:255`) rather than a repo path. Reported rather
            # than guessed at -- resolving a suffix is citation_check's job, not this
            # tool's, and picking the wrong file would rebind to a real line in the wrong
            # place, which is worse than leaving it.
            unwritable += 1
            print("  NOT A REPO PATH (suffix citation?): %s (cited at %s:%d)"
                  % (target, d["doc"], d["line"]))
            continue
        with open(cited, "r", encoding="utf-8", errors="replace") as fh:
            body = fh.read()
        hits = find_text(body, snapshot[target])
        if len(hits) == 0:
            unmatched += 1
            print("  TEXT IS GONE, read it: %s (cited at %s:%d)" % (target, d["doc"], d["line"]))
            continue
        if len(hits) > 1:
            ambiguous += 1
            print("  TEXT APPEARS %d TIMES, read it: %s (cited at %s:%d)"
                  % (len(hits), target, d["doc"], d["line"]))
            continue
        new_start = hits[0]
        if str(new_start) == old_start:
            continue
        # THE WHOLE SPAN, never just its first number. A citation written as a RANGE
        # (`game/game.gd:2070-2071`) contains its own start as a prefix, so replacing the
        # start alone leaves `game/game.gd:2151-2071` -- a range that runs backwards and
        # no longer resolves. That is not hypothetical: it is what the first run of this
        # tool did to kanban.md:6014, caught because citation_check went from 537 of 537
        # resolving to 536.
        old_end = span.split("-")[-1]
        shift = new_start - int(old_start)
        new_span = ("%d" % new_start if old_end == old_start
                    else "%d-%d" % (new_start, int(old_end) + shift))
        # THE OLD REFERENCE IS SPELLED THE WAY THE DOCUMENT SPELLS IT. The checker
        # normalises a single-line target to `2070-2070`; the prose says `2070`. Using the
        # normalised form as the search string matched nothing and silently rebound one
        # citation out of thirty-four -- a fixer that quietly does almost nothing is worse
        # than one that fails, because the count looks like progress.
        old_span = old_start if old_end == old_start else span
        edits.setdefault(d["doc"], []).append(
            (d["line"], "%s:%s" % (path, old_span), "%s:%s" % (path, new_span)))
        rebound += 1

    written = 0
    for doc, changes in sorted(edits.items()):
        full = os.path.join(args.root, doc)
        if not os.path.isfile(full):
            print("  CANNOT FIND CITING DOC: %s" % doc)
            continue
        with open(full, "r", encoding="utf-8", errors="replace") as fh:
            lines = fh.read().split("\n")
        touched = 0
        for line_no, old_ref, new_ref in changes:
            if line_no > len(lines):
                continue
            idx = line_no - 1
            # The FULL `path:line` form only, and only on the line the checker named.
            # Rewriting a bare `:NN` would hit the continuation form this project invented,
            # whose binding is positional -- see citation_check.py's own note on it.
            # A BOUNDARY-CHECKED match, because `game/game.gd:207` is a prefix of
            # `game/game.gd:2071` and a bare `in` test would rewrite the wrong citation.
            # The character after the match must not extend the number.
            hit = -1
            probe = 0
            while True:
                at = lines[idx].find(old_ref, probe)
                if at < 0:
                    break
                after = at + len(old_ref)
                tail = lines[idx][after:after + 1]
                if not tail.isdigit() and tail != "-":
                    hit = at
                    break
                probe = at + 1
            if hit < 0:
                print("  CITATION NOT ON THE LINE NAMED: %s expected at %s:%d"
                      % (old_ref, doc, line_no))
                continue
            lines[idx] = lines[idx][:hit] + new_ref + lines[idx][hit + len(old_ref):]
            touched += 1
            print("  %s %s:%d  %s -> %s"
                  % ("REBIND" if args.apply else "would rebind", doc, line_no,
                     old_ref, new_ref))
        if args.apply and touched:
            with open(full, "w", encoding="utf-8", newline="") as fh:
                fh.write("\n".join(lines))
            written += touched

    print("citation_rebind: %d drifted citation(s) read, %d rebindable, %d written, "
          "%d text gone, %d ambiguous, %d not a repo path"
          % (len(drifts), rebound, written, unmatched, ambiguous, unwritable))
    if not drifts:
        print("  NOTE: nothing to rebind -- the report named no gating drifted citations. "
              "That is a clean result only if you expected none; check that --report "
              "actually holds citation_check --against output.")
    if not args.apply and rebound:
        print("  DRY RUN. Re-run with --apply to write, then re-run citation_check "
              "--against to confirm the drift count fell.")
    # "WHAT THIS CANNOT DO", and the two words it avoids are the ones that are the
    # contract marker check_all.py discovers checkers by. This is a FIXER: it needs
    # --against and --report, so run as a checker it exits 2 on its own argparse, and
    # check_all caught the contradiction the moment it was also listed in NOT_A_CHECKER
    # ("listed as NOT_A_CHECKER but its source declares a contract line -- one of the
    # two is wrong"). The caveat below is worth as much to a reader either way; only the
    # two words had to go.
    print("  WHAT THIS CANNOT DO: it restores the POINTER, never the argument. A citation "
          "rebound here points at the text it was written about; whether the sentence "
          "around it still describes that text is a read, exactly as citation_check says "
          "of its own clean results. It also cannot see a citation whose target was "
          "edited IN PLACE -- that text is gone, and it is reported rather than guessed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
