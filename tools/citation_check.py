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

import repo_walk

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_FILES = ["kanban.md"]

# The bead export. A PASSIVE EXPORT and not the source of truth -- CLAUDE.md's beads block
# says so and bead_prose_check.py's NOT COVERED line says it again -- so a bead updated but
# not exported is invisible here, and the output says that rather than implying live
# coverage.
BEADS_EXPORT = ".beads/issues.jsonl"

# The fields that carry prose a person wrote. `close_reason` is included because a close is
# where this project puts its evidence, and a close citing a line that has since moved is
# exactly as misleading as a description doing it -- more so, because a close is read as a
# record of what was verified.
BEAD_PROSE_FIELDS = ("description", "close_reason")

# A bead that says its citation is deliberately dead -- one about DELETING the thing it
# cites, or one recording a line that has since moved. Same waiver mechanism
# bead_prose_check.py uses: the correction note IS the waiver, so an issue that records the
# problem stops being reported for it.
BEAD_WAIVER = "citation-check: ok"

# ...but the marker must OPEN ITS OWN LINE, and this is not a nicety. The very first bead
# closed by this feature quoted the marker mid-sentence -- "the marker `citation-check: ok`
# anywhere in the bead's prose drops the whole bead" -- and thereby waived itself: the bead
# count went 468 -> 467 and three citations vanished from the denominator. A waiver a bead
# can trip by DESCRIBING the waiver is worse than no waiver, because it fires exactly on the
# beads that discuss citation checking. Found by re-running the checker over its own close.
BEAD_WAIVER_LINE = re.compile(r"^[ \t>*+-]*" + re.escape(BEAD_WAIVER), re.MULTILINE)

# A citation is a backticked path with at least one directory part, a colon, a line, and
# optionally a `-` and an end line. The directory part is what keeps `Vector2(1.0, 1.0)`
# and prose like `9:00` out of the match.
CITATION = re.compile(
    r"`([A-Za-z0-9_./-]*[A-Za-z0-9_.-]+\.(?:gd|py|md|json|tscn|tres|gdshader))"
    r":(\d+)(?:-(\d+))?`"
)

# A citation with no directory part resolves against the CITING FILE's own directory
# first, then the repo root. `game/OVERLAY_GRAMMAR.md` lives in `game/` and cites its
# neighbours as `chomp_flower.gd:164` — twelve citations in the one file whose entire
# content is citations, and the first version of this checker (which demanded a `/`)
# could see none of them. That is the cycle-77 lesson arriving again on a different
# file: a convention a document grows is invisible to a tool written from the outside.



# The continuation form this project's entries actually use:
# "(`game/sfx.gd:86`, `:91`, `:106`)". A bare `:NN` inherits the last full path cited
# earlier in the same top-level entry. 44 of these live in kanban.md and the first version
# of this checker could not see any of them -- a third again on top of the 130 it did see,
# in a convention the project invented for itself.
BARE = re.compile(r"`:(\d+)(?:-(\d+))?`")

# BEAD PROSE IS NOT MARKDOWN. `bd`'s description and close_reason are plain text -- nothing
# renders them, so nothing rewards backticks, and the hand that writes `game/hud.gd:806`
# inside kanban.md writes game/hud.gd:806 bare inside a bead. Measured at the moment this
# mode was added: 95 backticked against 495 unbackticked. Requiring the backticks would have
# reported "468 bead(s) ... 0 finding(s)" while reading one citation in six -- a clean run
# over an input set that was 84% invisible, which is the exact failure the NOT COVERED
# contract exists to prevent, arriving through the front door of a new feature.
#
# This is cycle 77's lesson a third time, and the comment above BARE already states it: a
# convention a document grows is invisible to a tool written from the outside. Applied only
# to bead sources -- in markdown the backticks ARE the convention and loosening it there
# would start matching prose.
PLAIN = re.compile(
    r"(?<![`\w./-])([A-Za-z0-9_./-]*[A-Za-z0-9_.-]+\.(?:gd|py|md|json|tscn|tres|gdshader))"
    r":(\d+)(?:-(\d+))?(?![`\w])"
)


def citations(text: str, plain: bool = False) -> list[tuple[int, str, int, int]]:
    """(markdown_line, path, start, end) for every citation, in file order.

    Bare `:NN` continuations resolve against the last full citation in the same entry, and
    are DROPPED when there is none — an orphan continuation is a formatting mistake rather
    than a claim about a file, and inventing a path for it would report a finding against
    whatever happened to be cited last.
    """
    out: list[tuple[int, str, int, int]] = []
    context: str | None = None
    for lineno, line in enumerate(text.splitlines(), start=1):
        if line.startswith("- ") or line.startswith("#"):
            context = None          # new entry: a continuation may not reach across it
        # Interleave every form in source order so `foo.gd:1`, `:2` binds left to right.
        forms = list(CITATION.finditer(line)) + list(BARE.finditer(line))
        if plain:
            forms += list(PLAIN.finditer(line))
        for m in sorted(forms, key=lambda mm: mm.start()):
            if m.re is CITATION or m.re is PLAIN:
                context = m.group(1)
                start = int(m.group(2))
                end = int(m.group(3)) if m.group(3) else start
                out.append((lineno, context, start, end))
            elif context is not None:
                start = int(m.group(1))
                end = int(m.group(2)) if m.group(2) else start
                out.append((lineno, context, start, end))
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


def bead_sources(export: Path | None = None) -> tuple[list[tuple[str, str, bool]],
                                                      str | None]:
    """[(label, prose, gating)] read from the bead export, plus a reason it is empty.

    A bead is a ROOT-LEVEL document as far as the resolver is concerned -- its citations
    use the same three conventions kanban.md's do, because the same hand writes both in the
    same cycle -- so each source is handed `ROOT/kanban.md` as its citing path and gets
    identical resolution. There is no fourth convention to teach it.

    Gating follows `status`: an OPEN bead's citations are read by whoever picks the work up
    next and a stale one sends them to the wrong line. A CLOSED bead is a record of what was
    true when it closed, so its drift is advisory -- worth printing, not worth failing a
    cycle over. Closing a bead would otherwise silently convert its citations into future
    gate failures nobody can fix without rewriting history.
    """
    export = export or (ROOT / BEADS_EXPORT)
    if not export.is_file():
        return [], "no export at %s" % export
    out: list[tuple[str, str, bool]] = []
    for raw in export.read_text(encoding="utf-8", errors="replace").splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            issue = json.loads(raw)
        except ValueError:
            # One malformed line is not a reason to report zero beads checked. It IS a
            # reason to say so, which the caller's count does by coming up short.
            continue
        if not isinstance(issue, dict) or not issue.get("id"):
            continue
        prose = "\n".join(str(issue.get(f) or "") for f in BEAD_PROSE_FIELDS)
        if BEAD_WAIVER_LINE.search(prose):
            continue
        closed = str(issue.get("status", "")).lower() in ("closed", "done")
        out.append(("bead %s%s" % (issue["id"], " (closed)" if closed else ""),
                    prose, not closed))
    return out, None


def self_check() -> int:
    """Prove the --beads mode can FAIL, and that a closed bead cannot make it fail.

    A run reporting "468 bead(s) ... 0 finding(s)" is indistinguishable from a run whose
    extraction silently matched nothing -- and that is not hypothetical here: the FIRST
    version of this mode did exactly that, reading 95 of 590 bead citations because it
    demanded markdown backticks in a plain-text field, and printed a clean sweep. The
    denominator caught it (10 new citations from 468 beads is not a plausible number), but
    a denominator is a thing a reader has to notice. This is the thing that notices.

    Four cases, three of which are about the ROUTING rather than the detection:
      1. an OPEN bead citing a line past the end of a real file          -> gates
      2. the SAME defect in a CLOSED bead                                 -> advisory, no gate
      3. an unbackticked citation, the form bead prose actually uses      -> seen at all
      4. a bead carrying the waiver marker                                -> skipped entirely
    """
    import tempfile
    probe = ROOT / "tools" / "citation_check.py"
    past_end = len(probe.read_text(encoding="utf-8", errors="replace").splitlines()) + 5000
    rows = [
        {"id": "SELFCHECK-open", "status": "open",
         "description": "unbackticked, past the end: tools/citation_check.py:%d" % past_end},
        {"id": "SELFCHECK-closed", "status": "closed",
         "close_reason": "same defect, closed: tools/citation_check.py:%d" % past_end},
        {"id": "SELFCHECK-waived", "status": "open",
         "description": "citation-check: ok -- tools/citation_check.py:%d" % past_end},
        # The bead that TALKS ABOUT the waiver must not BE waived. Case 5 is here because
        # the first bead this feature ever closed did exactly that to itself.
        {"id": "SELFCHECK-mentions", "status": "open",
         "description": "the marker `citation-check: ok` mentioned mid-sentence must not "
                        "waive: tools/citation_check.py:%d" % past_end},
    ]
    with tempfile.TemporaryDirectory() as td:
        fake = Path(td) / "issues.jsonl"
        fake.write_text("\n".join(json.dumps(r) for r in rows) + "\n", encoding="utf-8")
        got, why = bead_sources(fake)
    if why is not None:
        print("SELF-CHECK FAILED: could not read the synthetic export: %s" % why)
        return 1
    labels = [lbl for lbl, _, _ in got]
    problems: list[str] = []
    if len(got) != 3:
        problems.append("expected 3 sources (only the line-initial waiver dropped), got "
                        "%d: %s" % (len(got), labels))
    if any("SELFCHECK-waived" in l for l in labels):
        problems.append("the line-initial waiver marker did not suppress SELFCHECK-waived")
    if not any("SELFCHECK-mentions" in l for l in labels):
        problems.append("a bead MENTIONING the marker mid-sentence was waived -- this is "
                        "the self-waiving close returning; the marker must open its line")
    gating = {lbl: g for lbl, _, g in got}
    for lbl, want in ((("SELFCHECK-open"), True), (("SELFCHECK-closed"), False)):
        hit = [g for l, g in gating.items() if lbl in l]
        if not hit:
            problems.append("%s missing from the sources entirely" % lbl)
        elif hit[0] is not want:
            problems.append("%s gating=%s, expected %s" % (lbl, hit[0], want))
    # And the detection itself, on the unbackticked form.
    for lbl, prose, _ in got:
        if not citations(prose, plain=True):
            problems.append("%s: no citation extracted from unbackticked prose -- this is "
                            "the 95-of-590 bug returning" % lbl)
        if citations(prose, plain=False):
            problems.append("%s: extracted an unbackticked citation with plain=False, so "
                            "the markdown path has been loosened too" % lbl)
    for p in problems:
        print("SELF-CHECK FAILED: %s" % p)
    if problems:
        return 1
    print("citation_check --self-check: 5 case(s) OK -- an open bead's dead citation gates, "
          "the same defect in a closed bead does not, the unbackticked form is seen, and "
          "a line-initial %r waives a bead while a mid-sentence mention of it does not. NOT COVERED by this fixture: whether the real "
          "export parses, and whether a landed line supports its claim." % BEAD_WAIVER)
    return 0


def _resolve(citing: Path, cited: str) -> tuple[Path | None, list[Path]]:
    """(the file, ambiguous candidates) — beside the citing file, then the repo root,
    then a unique basename anywhere under it.

    Three conventions live in this repo's markdown and a human reader follows all three
    without noticing: a full repo path (`game/plant.gd:1`), a neighbour of the citing file
    (`chomp_flower.gd:164` inside `game/OVERLAY_GRAMMAR.md`), and a bare name in a
    root-level document meaning "the obvious file" (`husk_layer.gd:69` in `kanban.md`).
    Searching for the third is what a reader does; refusing to would have meant rewriting
    42 correct references to suit the tool, which is the tail wagging the dog.
    """
    beside = citing.parent / cited
    if beside.is_file():
        return beside, []
    at_root = ROOT / cited
    if at_root.is_file():
        return at_root, []
    if "/" in cited:
        return None, []
    # `.claude/worktrees/` holds one full checkout per fan-out lane, INSIDE the
    # repo (it is gitignored, but rglob does not read .gitignore). Without this
    # exclusion every bare citation in kanban.md resolves to N+1 copies of the
    # same file and is reported ambiguous -- so running a parallel cycle makes
    # this checker report findings that vanish when the lanes are cleaned up,
    # and a lane running it inside its own worktree sees none of them. Measured
    # while adopting worktree isolation (plant-tower-defense-l638): five lanes
    # turned one clean run into six ambiguous matches per citation.
    #
    # The rule now lives in repo_walk, shared with the other rooted walkers
    # (plant-tower-defense-tfnv) -- this file is where it was first needed, not
    # where it belongs. Note this stays a per-MATCH filter, not a prune: rglob
    # offers no hook to stop descending, which is why repo_walk has both shapes.
    matches = [m for m in ROOT.rglob(cited) if not repo_walk.excluded(m, ROOT)]
    if len(matches) == 1:
        return matches[0], []
    if len(matches) > 1:
        return None, sorted(matches)
    return None, []


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("files", nargs="*", default=None)
    ap.add_argument("--quiet", action="store_true",
                    help="findings only; do not print the landed line for each citation")
    ap.add_argument("--baseline", metavar="PATH",
                    help="split findings into NEW and PRE-EXISTING against a snapshot")
    ap.add_argument("--baseline-write", metavar="PATH",
                    help="write the current findings as a snapshot and exit 0")
    # DRIFT, and note these are NOT --baseline. That pair snapshots FINDINGS, so it answers
    # "which broken citations are new". This pair snapshots the text every RESOLVED citation
    # landed on, so it answers "did a citation that still resolves stop pointing at what it
    # pointed at". Different questions, and overloading one flag with both would make a
    # clean --baseline run read as evidence about drift, which it is not.
    ap.add_argument("--snapshot", metavar="PATH",
                    help="record what every RESOLVED citation currently lands on, and exit "
                         "0. Take this BEFORE editing code you are also citing")
    ap.add_argument("--against", metavar="PATH",
                    help="report citations that still resolve but no longer land on the "
                         "text --snapshot recorded. Citations absent from the snapshot are "
                         "reported as NEW, never as drifted")
    ap.add_argument("--beads", action="store_true",
                    help="also read citations out of bead prose (%s -- description and "
                         "close_reason). Open beads gate, closed ones are advisory"
                         % BEADS_EXPORT)
    ap.add_argument("--self-check", action="store_true",
                    help="run the synthetic bead fixture and exit; proves --beads can fail")
    args = ap.parse_args(argv[1:])

    if args.self_check:
        return self_check()

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
    # Findings from CLOSED beads. Printed under their own heading, never counted into the
    # exit code -- see bead_sources() for why closing a bead must not arm a gate.
    non_gating: list[tuple[str, str]] = []
    advisories: list[str] = []
    # key -> the normalised text that key currently lands on. Only RESOLVED citations get an
    # entry: an unresolved one is already a finding and has no landing to compare.
    landed: dict[str, str] = {}
    # key -> "kanban.md:412", where the citation is WRITTEN. Not snapshotted (it moves for
    # its own reasons); kept for this run so a DRIFTED line can say where to go and fix it.
    # Without it the report names `game/game.gd:1464` and leaves you grepping a 4000-line
    # markdown file for a bare `:1464` that appears three times -- which is most of the cost
    # of acting on a drift report, and it was paid in full the first cycle this ran.
    cited_at: dict[str, str] = {}
    # Keys reached from at least one GATING source. A target cited by both an open bead and
    # a closed one is the open one's problem; a target only ever cited by closed beads is a
    # record, and its drift is advisory in --against for the same reason its findings are.
    # This is not symmetry for its own sake: cycle-log.md grows ~25 lines at its TOP every
    # cycle, so every citation into it from a closed bead drifts every cycle, forever. Five
    # did on the run that added this. A gate that is red every cycle for reasons nobody can
    # fix is the permanently-red gate house-static-checker calls worse than no gate.
    gating_keys: set[str] = set()
    resolved = 0

    # (label, text, is_file, gating). Files first so their line numbers keep their old
    # meaning in the output; beads carry no file so their `label:N` is a line WITHIN the
    # bead's prose, which the label makes unmistakable.
    sources: list[tuple[str, str, bool, bool]] = [
        (t.name, (t if t.is_file() else ROOT / t).read_text(encoding="utf-8",
                                                            errors="replace"), True, True)
        for t in targets]
    beads_note: str | None = None
    beads_seen = 0
    if args.beads:
        bs, why = bead_sources()
        beads_note = why
        beads_seen = len(bs)
        sources += [(lbl, prose, False, gating) for lbl, prose, gating in bs]

    for label, text, is_file, gating in sources:
        # Every source resolves as a root-level document. For a file that is what it
        # already did (`targets` are repo-root paths); for a bead there is no other
        # sensible base, and sharing one keeps ONE resolver rather than a second copy.
        path = ROOT / "kanban.md"
        found = citations(text, plain=not is_file)
        if is_file:
            files_seen += 1
            e, u = uncited_entries(text)
            entries_total += e
            entries_uncited += u
        total += len(found)
        for md_line, cited, start, end in found:
            src, ambiguous = _resolve(path, cited)
            k = key(cited, start, end)
            # A closed bead's citations are recorded, printed and compared -- but routed to
            # a sink that does not gate. Same evidence, different consequence.
            sink = findings if gating else non_gating
            if ambiguous:
                sink.append((k, "FINDING: %s:%d cites %s -- that bare name matches %s.\n"
                                    "  fix: write the path out so it names one of them.\n"
                                    "  waive: none."
                                 % (label, md_line, k,
                                    " and ".join(str(a.relative_to(ROOT)) for a in ambiguous))))
                continue
            if src is None:
                if "/" in cited:
                    sink.append((k, "FINDING: %s:%d cites %s -- no such file.\n"
                                        "  fix: the file was renamed or removed; find where "
                                        "the claim lives now, or delete the entry.\n"
                                        "  waive: none."
                                     % (label, md_line, k)))
                else:
                    # A BARE name resolving nowhere is as likely to be prose as a broken
                    # citation: CLAUDE.md's harness section writes "reading `player.gd:40-60`"
                    # as an EXAMPLE of a cheaper alternative, and there is no player.gd here.
                    # Advisory, so the gate does not cry wolf about a sentence.
                    advisories.append("ADVISORY: %s:%d has `%s`, which matches no file. "
                                      "Either a broken citation or prose shaped like one; "
                                      "writing the path out would settle it."
                                      % (label, md_line, k))
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
                sink.append((k, "FINDING: %s:%d cites %s -- out of range; %s has %d "
                                    "line(s).\n  fix: re-derive the line number; an edit "
                                    "that ADDS lines above a citation moves it silently.\n"
                                    "  waive: none."
                                 % (label, md_line, k, cited, len(lines))))
                continue
            resolved += 1
            # NORMALISED: leading whitespace stripped, because indentation moves for reasons
            # that have nothing to do with the claim (a block re-indented under a new `if`
            # is not a citation going stale). Everything else is kept, including trailing
            # comments -- a line whose comment changed is a line worth re-reading.
            landed[k] = "\n".join(l.strip() for l in lines[start - 1:end])
            if gating:
                gating_keys.add(k)
            # First writer wins: a target cited from two entries collapses to one key, and
            # the first is as good a place to start as the second.
            cited_at.setdefault(k, "%s:%d" % (label, md_line))
            if not args.quiet:
                body = _printable(" | ".join(l.strip()[:60] for l in lines[start - 1:end]))
                print("  %-34s %s" % (k, body))

    if args.snapshot:
        Path(args.snapshot).write_text(
            json.dumps(landed, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        # BOTH numbers, because they differ and the difference is not a bug. `landed` is
        # keyed by file:start-end, so the same target cited from two entries collapses to
        # one -- today 310 distinct targets from 351 citations. Printing only the smaller
        # one next to a default run that says 351 reads as 41 citations gone missing.
        print("citation_check: snapshotted %d distinct target(s) from %d resolved "
              "citation(s) to %s. Re-run with --against that path AFTER the code edits land."
              % (len(landed), resolved, args.snapshot))
        return 0

    if args.against:
        sp = Path(args.against)
        if not sp.is_file():
            # A missing snapshot is exit 2, not a clean run. Reporting "0 drifted" against
            # a file that does not exist is the shape every NOT COVERED line in this repo
            # exists to prevent: it is indistinguishable from having checked.
            print("citation_check: no snapshot at %s -- nothing to compare against, so "
                  "nothing was checked. Take one with --snapshot BEFORE the code edits."
                  % sp, file=sys.stderr)
            return 2
        try:
            before: dict[str, str] = json.loads(sp.read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            print("citation_check: snapshot %s is not readable JSON: %s" % (sp, exc),
                  file=sys.stderr)
            return 2
        all_drift = [(k, before[k], landed[k]) for k in sorted(landed)
                     if k in before and before[k] != landed[k]]
        drifted = [d for d in all_drift if d[0] in gating_keys]
        drift_record = [d for d in all_drift if d[0] not in gating_keys]
        fresh = sorted(k for k in landed if k not in before)
        gone = sorted(k for k in before if k not in landed)
        print("")
        print("citation_check --against %s: %d distinct target(s) from %d resolved "
              "citation(s), %d drifted, %d new, %d no longer resolving%s"
              % (sp.name, len(landed), resolved, len(drifted), len(fresh), len(gone),
                 (", %d drifted in CLOSED beads (advisory)" % len(drift_record))
                 if drift_record else ""))
        for k, was, now in drifted:
            print("DRIFTED: %s   (written at %s)" % (k, cited_at.get(k, "?")))
            print("    was: %s" % _printable(was.replace("\n", " | ")[:100]))
            print("    now: %s" % _printable(now.replace("\n", " | ")[:100]))
        if drift_record:
            print("DRIFTED IN A CLOSED BEAD (%d, advisory -- the citation is part of a "
                  "record, and the file it points into moved for its own reasons):"
                  % len(drift_record))
            for k, _, _ in drift_record:
                print("    %-34s (written at %s)" % (k, cited_at.get(k, "?")))
        if fresh:
            # NEW is not a finding and must never be one: a citation written this cycle has
            # nothing to compare against. Printed so the denominator adds up.
            print("NEW (no snapshot entry, not drifted): %s" % ", ".join(fresh[:8])
                  + (" ... and %d more" % (len(fresh) - 8) if len(fresh) > 8 else ""))
        if gone:
            print("NO LONGER RESOLVING (a finding above, not a drift): %s"
                  % ", ".join(gone[:8]))
        print("NOT COVERED by --against: it compares TEXT, so a citation whose target line "
              "was edited IN PLACE reports as drifted when the claim may be fine, and one "
              "that moved onto a line with identical text (two `return \"\"` lines) reports "
              "as clean. It says the line is not the line you cited; whether the claim "
              "still holds is a read, same as always.")
        return 1 if drifted else 0

    if args.baseline_write:
        Path(args.baseline_write).write_text(
            json.dumps(sorted(k for k, _ in findings), indent=2) + "\n", encoding="utf-8")
        print("citation_check: wrote %d finding(s) to %s as a baseline."
              % (len(findings), args.baseline_write))
        return 0

    new = [(k, m) for k, m in findings if k not in baseline]
    pre = [(k, m) for k, m in findings if k in baseline]

    # NAME THE SOURCES (plant-tower-defense-9vq6). "across 1 file(s)" was the whole gap:
    # a clean run read as "the citations are checked" when the tool had read kanban.md and
    # nothing else, immediately after twenty fresh citations were written into three BEAD
    # descriptions -- three of which were wrong. A reader could not tell a clean run from an
    # empty one without opening the script.
    print("citation_check: %d citation(s) across %d file(s) [%s]%s, %d resolved, "
          "%d finding(s)"
          % (total, files_seen, ", ".join(t.name for t in targets),
             (" + %d bead(s)" % beads_seen) if args.beads else "",
             resolved, len(findings))
          + (" (%d NEW, %d pre-existing)" % (len(new), len(pre)) if baseline else ""))
    if args.beads:
        if beads_note:
            # Could not read the export. Not a clean bead result -- an unread one, and the
            # difference is the whole contract.
            print("citation_check: --beads read NOTHING (%s). No bead was checked; the "
                  "count above is files only." % beads_note, file=sys.stderr)
            return 2
        print("             bead prose read from %s, which is a PASSIVE EXPORT: a bead "
              "edited since the last export is not in it, so this says the exported "
              "prose is clean, not that the tracker is. Fields read: %s."
              % (BEADS_EXPORT, ", ".join(BEAD_PROSE_FIELDS)))
    elif (ROOT / BEADS_EXPORT).is_file():
        print("             NOT read: bead prose (%s). Citations written into bead "
              "descriptions and close reasons are unchecked unless --beads is passed."
              % BEADS_EXPORT)
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
    for message in advisories:
        print(message)
    if baseline and pre:
        print("PRE-EXISTING (in the baseline, not gating): %d" % len(pre))
    if non_gating:
        print("CLOSED BEADS (%d finding(s), advisory -- a closed bead records what was "
              "true when it closed, and rewriting its prose would falsify the record. "
              "Worth reading before you trust one as evidence):" % len(non_gating))
        for _, message in non_gating:
            print("  " + message.replace("\n", "\n  "))
    print("NOT COVERED: this resolves citations; it cannot tell you whether the landed "
          "line SUPPORTS the claim around it -- cycles 68 and 76 each wrote a citation "
          "that resolved cleanly to a doc comment one line above the constant it meant. "
          "Read the printed lines, not the exit code. Nor does THIS mode see a citation "
          "that has drifted onto a DIFFERENT but still-valid line, which is the common "
          "case -- `--snapshot` before your edits and `--against` after is what sees that, "
          "and it is not run here. (This sentence used to end \"the one nothing can "
          "automate\", which was half right and stayed on the page for two cycles after "
          "drift bit twice: whether a line SUPPORTS a claim cannot be automated, whether "
          "it is the SAME line is a string comparison.) A bare filename resolves beside "
          "the citing file, "
          "then at the repo root, then by unique basename anywhere under it -- so it "
          "follows the reader rather than the letter, and a name matching two files is "
          "reported as ambiguous rather than guessed at. A bare name matching NOTHING is "
          "an ADVISORY and does not gate: prose in these files legitimately says things "
          "like `player.gd:40-60` as an example.")
    return 1 if new else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
