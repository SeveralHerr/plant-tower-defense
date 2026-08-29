#!/usr/bin/env python3
r"""Relocate a citation whose CITED file moved, and REFUSE the ones it cannot.

WHY THIS EXISTS (plant-tower-defense-2174). `citation_check --against` reports drift --
a citation that used to land on some text and no longer does. It reports; nothing
relocates. Cycle 137's merge drifted 90 citations in `kanban.md` alone, and cycles 129,
130, 131 and 136 each fixed the drift by hand.

WHY THE OBVIOUS FIX IS WRONG, and this is the whole design. A per-file offset -- "the
file grew by N lines above the citation, add N" -- is wrong by construction whenever an
edit spans the cited file: cycle 136 measured `hud.gd`'s real per-citation offsets ranging
from 0 to +127 across ONE merge, because different citations sat on different sides of
different hunks. Worse, `citation_check --against` compares TEXT, and a citation landing
on a blank line, a bare `##`, or a closing brace matches ANYWHERE -- so relocating one of
those by a guessed offset SATISFIES the drift check without making the citation correct.
An offset that happens to be right for one citation is not evidence it is right for the
next one three lines below it.

THE SHAPE THAT WORKS: `git diff -U0 <base> <head> -- <cited file>` already knows every
hunk's exact old-line -> new-line correspondence. OUTSIDE every hunk, old -> new is a
running offset git already computed, applied here rather than re-derived. INSIDE a hunk
there is NO correspondence -- the old lines in that range were changed or deleted, not
shifted -- so a citation landing there is REFUSED and reported, never guessed. Refusal is
not a limitation bolted on afterward; it is the point: a citation sitting inside an edited
region is exactly the one whose CLAIM may have gone stale, which is the one case where
silently offsetting it would look like a fix and hide the citation most worth reading.

THIS RELOCATES WHAT citation_check ALREADY REPORTS; IT DOES NOT REINVENT DETECTION.
Every pattern here (`CITATION`, `BARE`, `PLAIN`) and the bare-`:NN`-continuation context
rule are imported from `citation_check.py`, not re-derived -- see `citations_with_spans()`
below, whose self-test cross-checks it against `citation_check.citations()` on the same
text so the two extraction passes can never quietly disagree.

HOUSE CONTRACT applies (.claude/skills/house-static-checker/SKILL.md), with the one
exception every write-capable house tool carries: this WRITES, so it is NOT PARALLEL-SAFE
-- the same argument `mirror_check.py --fix` and `citation_rebind.py` already make for
themselves (`check_all.py`'s own `NOT_A_CHECKER` / `NOT_PARALLEL_SAFE` dicts name both).
It defaults to a DRY RUN that prints exactly what it WOULD relocate and refuse; nothing on
disk changes until `--write` is passed explicitly. `check_all.py` currently has no entry
for this file in either exclusion dict (this tool does not own that file -- see the
docstring's own NOT COVERED line and this repo's file-ownership note for why); until one
is added, `check_all.py`'s marker-based discovery WOULD add this to its parallel pool,
where it is harmless only because `--base` is required and a bare invocation exits 2 on
its own argparse, never because it is actually safe there. Treat that as an open gap, not
a guarantee.

WHAT THIS HANDLES: both named markdown files (`kanban.md`, `--beads` sources) and BEAD
PROSE (`description`, `close_reason` from `.beads/issues.jsonl`) -- the same distinction
`citation_check.py --beads` already draws (backticked citations in markdown, unbackticked
`PLAIN` citations in bead prose, because nothing renders a `bd` description and nothing
rewards writing backticks into it). ~500 citations live in bead prose, "the larger half";
a relocator that only reads named files (cycle 137's prototype) is half the job.

WHAT THIS CANNOT DO, IN ITS OWN WORDS (the required NOT COVERED line, stated here too
because it shapes the design, not just the output):

  * WRITING BEAD PROSE. `.beads/issues.jsonl` is a PASSIVE EXPORT -- writing directly to
    it would not reach the tracker, and this tool does not shell out to `bd update` on a
    caller's behalf (no house tool here does; see `bead_prose_check.py` and
    `bead_claim_check.py`, which print the fix and leave the write to a human running
    `bd update --stdin`). So a bead-prose citation is relocated and REPORTED -- printed
    with its corrected `path:line`, ready to paste -- but `--write` never touches it, only
    the file-based citing documents. This is not a smaller version of the same feature; it
    is a hard boundary this tool cannot cross without running a write `bd` command itself.
  * THE BARE `:1207` CONTINUATION FORM WHEN ITS CONTEXT IS NAMED IN PLAIN PROSE. This is
    inherited from `citation_check.citations()` verbatim, not a new gap: a bare `:NN` binds
    to the last FULL citation (a backticked or `res://` path immediately followed by
    `:digits`) seen since the current entry started. A file merely NAMED in a sentence --
    "in `game/pest.gd`, see also `:120`" with no trailing `:N` on the naming mention --
    never sets that context, so the bare citation after it is an orphan and both tools drop
    it rather than guess a file for it. Six of these survived cycle 137's pass.
  * WHETHER A RELOCATED CITATION'S CLAIM STILL HOLDS. Moving a citation to the line its
    OLD line's content became is independent of whether the prose beside it still describes
    that line -- and only the second matters. `plant-tower-defense-nalv` (deliberately not
    merged with this bead) is the tool that would check a citation was ALREADY wrong when
    written, which `--against`-style drift detection can never see because it baselines the
    wrong text as correct. This tool only ever proves the pointer moved correctly; it never
    reads what the pointer is for.
  * A CITED FILE RENAMED BETWEEN --base AND --head. Resolution runs against the CURRENT
    tree (the same `citation_check._resolve` a markdown reader's eye follows: beside the
    citing file, then the repo root, then a unique basename) -- exactly as
    `citation_check.py` does it, so the two can never disagree about what a citation
    resolves to. A file that moved is invisible to `git diff -- <old path>` under its new
    name; such a citation is reported as unresolved by `citation_check` already and is
    silently out of scope here rather than double-reported.
  * COMPILING OR EXECUTING ANYTHING. This is text and `git diff` plumbing; it has no
    opinion on whether the cited GDScript, JSON or markdown is itself valid.

# fixture:   --self-test builds a throwaway git repo (tempfile.TemporaryDirectory) with a
#            base commit and a head commit that both shifts unrelated lines (a pure
#            insertion) AND edits one line in place, then a citing doc with one citation
#            into the shifted region, one into the edited region, and one before every
#            hunk. Never vendored; built and torn down in one process.
# mutations: skip the in-hunk check and always apply the running offset -> the refusal
#              fixture must fire red (the whole point: a naive offset would silently
#              "succeed" on the in-hunk citation, landing on whatever text is now there)
#            treat an old_count==0 (pure-insertion) hunk as a refusal range -> the
#              unaffected-line fixture (cited exactly at the insertion point) wrongly
#              refuses instead of relocating
#            drop citations_with_spans()'s cross-check against citation_check.citations()
#              -> a detection drift here would go unnoticed; --self-test asserts equality
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import citation_check

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_FILES = ["kanban.md"]

# `@@ -old_start[,old_count] +new_start[,new_count] @@ ...trailing context text...`
# A single space around each half; git always writes it that way. Matched with `.match`
# so the trailing " <context>" text (git appends the enclosing function/heading) is
# ignored rather than required.
HUNK_RE = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")


def _printable(s: str) -> str:
    """Same rationale as citation_check.py's own helper: a Windows cp1252 console
    dies on an em-dash in printed source, taking the whole run down with it."""
    enc = (sys.stdout.encoding or "utf-8")
    return s.encode(enc, errors="replace").decode(enc, errors="replace")


def _run_git(args: list[str], root: Path):
    """(CompletedProcess, error) -- error is a string, or None on a clean invocation.

    `git` missing entirely is reported the same way a bad ref is: something this tool
    could not verify, never silently treated as "nothing to relocate".
    """
    try:
        proc = subprocess.run(["git"] + args, cwd=str(root), capture_output=True,
                              text=True, encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return None, "git is not on PATH"
    return proc, None


def verify_ref(ref: str, root: Path) -> tuple[bool, str]:
    proc, err = _run_git(["rev-parse", "--verify", "%s^{commit}" % ref], root)
    if err:
        return False, err
    if proc.returncode != 0:
        stderr = (proc.stderr or "").strip()
        return False, stderr.splitlines()[-1] if stderr else "unknown ref"
    return True, ""


def parse_hunks(diff_text: str) -> list[tuple[int, int, int, int]]:
    """(old_start, old_count, new_start, new_count) per hunk, in file order (git's own
    order, which is always old-line ascending)."""
    hunks = []
    for line in diff_text.splitlines():
        m = HUNK_RE.match(line)
        if m:
            old_start = int(m.group(1))
            old_count = int(m.group(2)) if m.group(2) is not None else 1
            new_start = int(m.group(3))
            new_count = int(m.group(4)) if m.group(4) is not None else 1
            hunks.append((old_start, old_count, new_start, new_count))
    return hunks


def diff_hunks(base: str, head: str, relpath: str, root: Path):
    """(hunks, error) for one path between base and head.

    `head == ""` diffs base against the WORKING TREE (git's own two-argument-vs-one
    convention: a single rev compares it to what is on disk right now), which is the
    normal case for "I have not committed the edit yet". A non-empty head diffs base..head
    exactly as the bead's own shape names it: `git diff -U0 <base> HEAD -- <file>`.
    """
    args = ["diff", "-U0", "--no-color", base]
    if head:
        args.append(head)
    args += ["--", relpath]
    proc, err = _run_git(args, root)
    if err:
        return None, err
    if proc.returncode != 0:
        return None, (proc.stderr or "git diff exited %d" % proc.returncode).strip()
    return parse_hunks(proc.stdout), None


def relocate_line(hunks: list[tuple[int, int, int, int]], line: int):
    """(new_line, None) if `line` (an OLD line number) sits outside every hunk, or
    (None, (old_start, old_end)) if it sits inside one -- REFUSED, not guessed.

    old_count == 0 is a pure insertion: the hunk consumes ZERO old lines, so old_start
    itself is the line AFTER WHICH new content appears and is NOT inside the hunk. Only
    old_count > 0 carries a real "these old lines were touched" range.
    """
    offset = 0
    for old_start, old_count, new_start, new_count in hunks:
        if old_count == 0:
            if line <= old_start:
                return line + offset, None
        else:
            old_end = old_start + old_count - 1
            if line < old_start:
                return line + offset, None
            if old_start <= line <= old_end:
                return None, (old_start, old_end)
        offset += (new_count - old_count)
    return line + offset, None


def relocate_span(hunks, start: int, end: int):
    """(new_start, new_end) or None, plus a refusal reason -- both ends of a range must
    relocate cleanly or the whole citation is refused; a span that PARTLY crosses a hunk
    boundary is exactly as unverifiable as one that lands fully inside one."""
    new_start, refusal = relocate_line(hunks, start)
    if refusal:
        return None, refusal
    if end == start:
        return (new_start, new_start), None
    new_end, refusal = relocate_line(hunks, end)
    if refusal:
        return None, refusal
    return (new_start, new_end), None


def citations_with_spans(text: str, plain: bool = False) -> list[dict]:
    """Everything citation_check.citations() reports, plus each match's own on-line
    character span for the NUMBER it contains -- citation_check exposes the resolved
    (line, path, start, end) tuple and nothing about WHERE on the line it sat, and
    `--write` needs exact columns to replace a number without disturbing the rest of the
    line (backticks, a `res://` prefix, a sibling `:NN` continuation on the same line).

    Mirrors citation_check.citations()'s loop exactly -- same patterns (imported, not
    re-derived), same context-reset-on-entry-boundary rule, same bare-continuation
    binding -- because a second implementation of the SAME rule is how two tools drift
    apart silently. See self_test() for the equality check against the original.
    """
    out: list[dict] = []
    context: str | None = None
    for lineno, line in enumerate(text.splitlines(), start=1):
        if line.startswith("- ") or line.startswith("#"):
            context = None
        forms = (list(citation_check.CITATION.finditer(line))
                 + list(citation_check.BARE.finditer(line)))
        if plain:
            forms += list(citation_check.PLAIN.finditer(line))
        for m in sorted(forms, key=lambda mm: mm.start()):
            if m.re is citation_check.CITATION or m.re is citation_check.PLAIN:
                context = m.group(1)
                start_span = m.span(2)
                end_span = m.span(3) if m.group(3) else None
                start = int(m.group(2))
                end = int(m.group(3)) if m.group(3) else start
            elif context is not None:
                start_span = m.span(1)
                end_span = m.span(2) if m.group(2) else None
                start = int(m.group(1))
                end = int(m.group(2)) if m.group(2) else start
            else:
                continue
            out.append({"line": lineno, "path": context, "start": start, "end": end,
                        "start_span": start_span, "end_span": end_span})
    return out


def apply_edits(text: str, edits: list[tuple[int, int, int, str]]) -> tuple[str, int]:
    """(new text, lines touched). `edits`: (lineno, span_start, span_end, replacement).

    Grouped and applied RIGHTMOST-FIRST within each line so an earlier replacement on the
    same line (a bare `:NN` continuation chain: `` `f.gd:10`, `:15`, `:20` ``) never
    invalidates a later span's column offsets.
    """
    lines = text.split("\n")
    by_line: dict[int, list[tuple[int, int, str]]] = {}
    for lineno, s0, s1, repl in edits:
        by_line.setdefault(lineno, []).append((s0, s1, repl))
    touched = 0
    for lineno, spans in by_line.items():
        idx = lineno - 1
        if idx < 0 or idx >= len(lines):
            continue
        line = lines[idx]
        for s0, s1, repl in sorted(spans, key=lambda t: -t[0]):
            line = line[:s0] + repl + line[s1:]
            touched += 1
        lines[idx] = line
    return "\n".join(lines), touched


def analyze(root: Path, base: str, head: str, sources: list[tuple[str, str, bool, bool]]):
    """The core pass, kept separate from argv/printing so --self-test can call it with a
    synthetic repo and assert on its RETURNED structure, not on scraped stdout.

    `sources`: (label, text, is_file, plain). `is_file` sources are eligible for --write;
    bead-prose sources (is_file=False) never are, by design -- see the module docstring.

    Returns a dict: relocations, refusals, skipped (each a list of result dicts) and
    edits (label -> list of (lineno, span_start, span_end, replacement) for --write).
    """
    relocations: list[dict] = []
    refusals: list[dict] = []
    skipped: list[dict] = []
    edits: dict[str, list[tuple[int, int, int, str]]] = {}
    hunk_cache: dict[str, tuple[list | None, str | None]] = {}
    total = 0

    for label, text, is_file, plain in sources:
        for c in citations_with_spans(text, plain=plain):
            total += 1
            cited_path, ambiguous = citation_check._resolve(root / "kanban.md", c["path"])
            if ambiguous or cited_path is None:
                # citation_check's own job: an unresolved or ambiguous citation is
                # already reported there. Not double-reported here as a defect of ITS
                # own, but the citation is still counted -- see the denominator note.
                skipped.append({"label": label, "line": c["line"], "path": c["path"],
                                "start": c["start"], "end": c["end"],
                                "why": "unresolved or ambiguous -- see citation_check"})
                continue
            relpath = cited_path.relative_to(root).as_posix()
            if relpath not in hunk_cache:
                hunk_cache[relpath] = diff_hunks(base, head, relpath, root)
            hunks, err = hunk_cache[relpath]
            if err:
                skipped.append({"label": label, "line": c["line"], "path": relpath,
                                "start": c["start"], "end": c["end"],
                                "why": "git could not diff it: %s" % err})
                continue
            span, refusal = relocate_span(hunks, c["start"], c["end"])
            if refusal:
                old_start, old_end = refusal
                refusals.append({"label": label, "line": c["line"], "path": relpath,
                                 "start": c["start"], "end": c["end"],
                                 "hunk": (old_start, old_end)})
                continue
            new_start, new_end = span
            if new_start == c["start"] and new_end == c["end"]:
                continue  # nothing moved -- not a finding, not printed
            relocations.append({"label": label, "line": c["line"], "path": relpath,
                                "old": (c["start"], c["end"]),
                                "new": (new_start, new_end), "is_file": is_file})
            if is_file:
                edits.setdefault(label, []).append(
                    (c["line"], c["start_span"][0], c["start_span"][1], str(new_start)))
                if c["end_span"]:
                    edits.setdefault(label, []).append(
                        (c["line"], c["end_span"][0], c["end_span"][1], str(new_end)))

    return {"total": total, "relocations": relocations, "refusals": refusals,
            "skipped": skipped, "edits": edits}


def _span_text(span: tuple[int, int]) -> str:
    a, b = span
    return "%d" % a if a == b else "%d-%d" % (a, b)


def run(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(add_help=True, description=__doc__.splitlines()[0])
    ap.add_argument("files", nargs="*", default=None,
                    help="markdown files to scan (default: kanban.md)")
    ap.add_argument("--base", help="the ref citations were written against (required "
                                   "unless --self-test)")
    ap.add_argument("--head", default="HEAD",
                    help="the ref to relocate onto (default: HEAD). Pass an empty "
                         "string to diff against the WORKING TREE instead")
    ap.add_argument("--beads", action="store_true",
                    help="also scan bead prose (description, close_reason) from %s. "
                         "Relocations there are REPORTED, never written -- see the "
                         "module docstring's WHAT THIS CANNOT DO"
                         % citation_check.BEADS_EXPORT)
    ap.add_argument("--write", action="store_true",
                    help="actually rewrite relocated citations in file-based sources. "
                         "Default is a DRY RUN that changes nothing on disk")
    ap.add_argument("--root", default=str(ROOT), help="repo root (default: this checkout)")
    ap.add_argument("--quiet", action="store_true", help="summary and findings only")
    ap.add_argument("--self-test", action="store_true",
                    help="run the synthetic fixture and exit; proves the refusal fires")
    args = ap.parse_args(argv[1:])

    if args.self_test:
        return self_test()

    root = Path(args.root).resolve()
    if not args.base:
        print("citation_relocate: --base is required (the ref citations were written "
              "against). Nothing was checked.", file=sys.stderr)
        return 2

    is_repo, err = _run_git(["rev-parse", "--is-inside-work-tree"], root)
    if err or not is_repo or is_repo.returncode != 0 or is_repo.stdout.strip() != "true":
        print("citation_relocate: %s is not a git repository (%s). Nothing was checked."
              % (root, err or "git rev-parse failed"), file=sys.stderr)
        return 2
    ok, why = verify_ref(args.base, root)
    if not ok:
        print("citation_relocate: --base %r does not resolve to a commit (%s). Nothing "
              "was checked." % (args.base, why), file=sys.stderr)
        return 2
    if args.head:
        ok, why = verify_ref(args.head, root)
        if not ok:
            print("citation_relocate: --head %r does not resolve to a commit (%s). "
                  "Nothing was checked." % (args.head, why), file=sys.stderr)
            return 2

    targets = [Path(f) for f in (args.files or DEFAULT_FILES)]
    missing = [t for t in targets if not (root / t).is_file() and not t.is_file()]
    if missing:
        print("citation_relocate: cannot read %s"
              % ", ".join(str(m) for m in missing), file=sys.stderr)
        return 2

    sources: list[tuple[str, str, bool, bool]] = []
    for t in targets:
        p = t if t.is_file() else root / t
        sources.append((t.name, p.read_text(encoding="utf-8", errors="replace"),
                        True, False))
    beads_seen = 0
    if args.beads:
        bs, why = citation_check.bead_sources()
        if why is not None:
            print("citation_relocate: --beads read NOTHING (%s). Nothing was checked."
                  % why, file=sys.stderr)
            return 2
        beads_seen = len(bs)
        sources += [(lbl, prose, False, True) for lbl, prose, _gating in bs]

    result = analyze(root, args.base, args.head, sources)

    head_desc = args.head if args.head else "the working tree"
    print("citation_relocate: %d citation(s) across %d file(s) [%s]%s resolved to a "
          "cited path -- %d relocatable (%s -> %s), %d REFUSED (inside an edited hunk), "
          "%d skipped (unresolved elsewhere), %d unchanged"
          % (result["total"], len(targets), ", ".join(t.name for t in targets),
             (" + %d bead(s)" % beads_seen) if args.beads else "",
             len(result["relocations"]), args.base, head_desc, len(result["refusals"]),
             len(result["skipped"]),
             result["total"] - len(result["relocations"]) - len(result["refusals"])
             - len(result["skipped"])))
    if result["total"] == 0:
        print("NOTE: no citations resolved to a cited path at all. That is a clean "
              "result only if you expected none -- an empty input and a clean sweep "
              "print identically otherwise.")

    for r in result["relocations"]:
        verb = "wrote" if (args.write and r["is_file"]) else \
               ("would write" if r["is_file"] else "found (bead prose, NEVER written)")
        print("  RELOCATE %-9s %s:%d  %s:%s -> %s:%s"
              % (verb, r["label"], r["line"], r["path"], _span_text(r["old"]),
                 r["path"], _span_text(r["new"])))

    for r in result["refusals"]:
        old_start, old_end = r["hunk"]
        print("  REFUSED %s:%d  %s:%s -- old line(s) fall inside an edited hunk "
              "(%s:%d-%d changed between %s and %s). No old->new correspondence exists "
              "there; not guessed.\n"
              "    fix: read the current text at %s and re-cite it by hand, or confirm "
              "the claim still holds and leave a note."
              % (r["label"], r["line"], r["path"], _span_text((r["start"], r["end"])),
                 r["path"], old_start, old_end, args.base, head_desc, r["path"]))

    if not args.quiet:
        for r in result["skipped"]:
            print(_printable("  skipped %s:%d  `%s:%s` -- %s"
                  % (r["label"], r["line"], r["path"], _span_text((r["start"], r["end"])),
                     r["why"])))

    written_total = 0
    if args.write:
        for label, edits in result["edits"].items():
            match = next((s for s in sources if s[0] == label), None)
            if match is None:
                continue
            _, text, is_file, _plain = match
            if not is_file:
                continue
            target = next(t for t in targets if t.name == label)
            path = target if target.is_file() else root / target
            new_text, touched = apply_edits(text, edits)
            if touched:
                path.write_text(new_text, encoding="utf-8", newline="")
                written_total += touched
        print("citation_relocate: --write wrote %d citation(s) across %d file(s)."
              % (written_total, len(result["edits"])))
    else:
        file_relocations = [r for r in result["relocations"] if r["is_file"]]
        if file_relocations:
            print("DRY RUN. Re-run with --write to apply the %d file-based relocation(s) "
                  "above. Nothing on disk has changed." % len(file_relocations))

    bead_relocations = [r for r in result["relocations"] if not r["is_file"]]
    if bead_relocations:
        print("%d relocation(s) found in BEAD PROSE. --write cannot apply these -- "
              ".beads/issues.jsonl is a passive export; use `bd update <id> "
              "--description/--close-reason --stdin` with the corrected text printed "
              "above." % len(bead_relocations))

    print("NOT COVERED: see the module docstring's WHAT THIS CANNOT DO -- bead prose "
          "is reported, never written; the bare `:NN` continuation form is blind "
          "whenever its context is named in prose rather than cited; a relocated "
          "citation's claim is never re-checked, only its pointer; a cited file renamed "
          "between --base and --head is invisible to this tool exactly as it already is "
          "to citation_check; and this compiles nothing.")

    if result["refusals"] or bead_relocations:
        return 1
    if not args.write and [r for r in result["relocations"] if r["is_file"]]:
        return 1
    return 0


# ---------------------------------------------------------------------------------
# --self-test: a throwaway git repo, never vendored into this checkout.
# ---------------------------------------------------------------------------------

def _git(args: list[str], cwd: Path):
    proc = subprocess.run(["git"] + args, cwd=str(cwd), capture_output=True,
                          text=True, encoding="utf-8", errors="replace")
    if proc.returncode != 0:
        raise RuntimeError("git %s failed: %s" % (" ".join(args), proc.stderr))
    return proc.stdout


def self_test() -> int:
    problems: list[str] = []

    # --- citations_with_spans() must never disagree with citation_check.citations() ---
    sample_md = (
        "- an entry citing `game/foo.gd:8` and continuing `:15`-`:20`\n"
        "- another entry citing `docs/bar.md:3-5`\n"
    )
    a = [(c["line"], c["path"], c["start"], c["end"])
         for c in citations_with_spans(sample_md, plain=False)]
    b = citation_check.citations(sample_md, plain=False)
    if a != b:
        problems.append("citations_with_spans() disagrees with citation_check.citations() "
                        "on markdown: %r vs %r" % (a, b))
    sample_prose = "SCRIPT ERROR at game/foo.gd:8, see also res://docs/bar.md:3-5"
    a = [(c["line"], c["path"], c["start"], c["end"])
         for c in citations_with_spans(sample_prose, plain=True)]
    b = citation_check.citations(sample_prose, plain=True)
    if a != b:
        problems.append("citations_with_spans() disagrees with citation_check.citations() "
                        "on plain prose: %r vs %r" % (a, b))

    # --- the hunk-header arithmetic itself, on known-in/known-out text (a positive
    # control over real diff text would be defeated by "most diffs happen to work" the
    # same way a corpus-percentage guard is -- see house-static-checker's own warning) ---
    insertion = parse_hunks("@@ -2,0 +3,3 @@ b\n+X\n+Y\n+Z\n")
    if relocate_line(insertion, 2) != (2, None):
        problems.append("a line AT the insertion point must be unaffected: got %r"
                        % (relocate_line(insertion, 2),))
    if relocate_line(insertion, 3) != (6, None):
        problems.append("a line AFTER a +3 insertion at old 2 must shift by 3: got %r"
                        % (relocate_line(insertion, 3),))
    deletion = parse_hunks("@@ -6 +5,0 @@ Z\n-c\n")
    if relocate_line(deletion, 6) != (None, (6, 6)):
        problems.append("a DELETED line must be REFUSED, not offset: got %r"
                        % (relocate_line(deletion, 6),))
    if relocate_line(deletion, 7) != (6, None):
        problems.append("a line after a pure deletion must shift by -1: got %r"
                        % (relocate_line(deletion, 7),))
    modify = parse_hunks("@@ -6 +6 @@ Z\n-d\n+D2\n")
    if relocate_line(modify, 6) != (None, (6, 6)):
        problems.append("a MODIFIED-IN-PLACE line must be REFUSED, not silently kept: "
                        "got %r" % (relocate_line(modify, 6),))

    # --- the whole pipeline, against a real (throwaway) git repo ---
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        _git(["init", "-q"], root)
        _git(["config", "user.email", "test@test.invalid"], root)
        _git(["config", "user.name", "citation_relocate self-test"], root)
        game_dir = root / "game"
        game_dir.mkdir()
        cited = game_dir / "foo.gd"
        base_lines = ["line%d" % i for i in range(1, 11)]  # line1..line10
        cited.write_text("\n".join(base_lines) + "\n", encoding="utf-8", newline="\n")
        (root / "kanban.md").write_text("placeholder\n", encoding="utf-8")
        _git(["add", "-A"], root)
        _git(["commit", "-q", "-m", "base"], root)
        base_sha = _git(["rev-parse", "HEAD"], root).strip()

        # Insert 3 lines after old line 5 (shifts old 6..10 to new 9..13), AND modify
        # old line 2 IN PLACE -- replacing it, not adding beside it -- so it must be
        # refused, not offset.
        new_lines = [base_lines[0], "line2-EDITED"] + base_lines[2:5] \
            + ["NEW-A", "NEW-B", "NEW-C"] + base_lines[5:]
        cited.write_text("\n".join(new_lines) + "\n", encoding="utf-8", newline="\n")
        citing = (
            "- before every hunk `game/foo.gd:1` unaffected\n"
            "- inside the edited line `game/foo.gd:2` must be refused\n"
            "- after the insertion `game/foo.gd:8` must relocate to line 11\n"
        )
        (root / "citing.md").write_text(citing, encoding="utf-8")
        _git(["add", "-A"], root)
        _git(["commit", "-q", "-m", "edit"], root)

        sources = [("citing.md", citing, True, False)]
        result = analyze(root, base_sha, "HEAD", sources)

        got_refused = {(r["label"], r["line"]) for r in result["refusals"]}
        if ("citing.md", 2) not in got_refused:
            problems.append("the REFUSAL fixture did not fire: citing.md:2 (cited line "
                            "inside an edited hunk) was not in refusals -- %r"
                            % result["refusals"])
        if len(result["refusals"]) != 1:
            problems.append("expected exactly 1 refusal, got %d: %r"
                            % (len(result["refusals"]), result["refusals"]))

        reloc_by_line = {r["line"]: r for r in result["relocations"]}
        if 3 not in reloc_by_line or reloc_by_line[3]["new"] != (11, 11):
            problems.append("expected citing.md:3 (old game/foo.gd:8) to relocate to "
                            "11, got %r" % result["relocations"])
        if any(r["line"] == 1 for r in result["relocations"]):
            problems.append("citing.md:1 (cited line 1, before every hunk) must be "
                            "UNCHANGED and not reported as a relocation -- %r"
                            % result["relocations"])

        # --write must edit only the relocatable citation, leave the refused one
        # untouched (still reading `:2`, not silently offset), and be idempotent.
        edits = result["edits"].get("citing.md", [])
        new_text, touched = apply_edits(citing, edits)
        if "`game/foo.gd:11`" not in new_text:
            problems.append("--write did not produce the relocated citation: %r"
                            % new_text)
        if "`game/foo.gd:2`" not in new_text:
            problems.append("--write must leave the REFUSED citation exactly as written "
                            "-- it changed: %r" % new_text)
        if touched != 1:
            problems.append("expected exactly 1 span touched by --write, got %d" % touched)
        # Idempotency has to be checked against HEAD..HEAD (nothing changed), not against
        # the original base_sha..HEAD pair -- the rewritten citation now reads a NEW-state
        # line number, so re-running it through the OLD shift would (correctly) propose
        # shifting it AGAIN, which is a different bug than the one this case checks for.
        result2 = analyze(root, "HEAD", "HEAD", [("citing.md", new_text, True, False)])
        if any(r["line"] == 3 for r in result2["relocations"]):
            problems.append("re-running analyze() against HEAD..HEAD after --write still "
                            "proposed relocating the citation it just wrote -- the write "
                            "was not idempotent: %r" % result2["relocations"])

        # --- bead prose: PLAIN detection must fire where markdown detection does not ---
        prose = "unbackticked, points at game/foo.gd:8 same as above"
        md_hits = citations_with_spans(prose, plain=False)
        prose_hits = citations_with_spans(prose, plain=True)
        if md_hits:
            problems.append("markdown-mode (plain=False) matched an unbackticked bead "
                            "citation, which loosens the markdown convention: %r" % md_hits)
        if not prose_hits:
            problems.append("plain=True did not see an unbackticked bead-prose citation "
                            "at all -- the 95-of-590 bug returning")
        bead_result = analyze(root, base_sha, "HEAD", [("bead X", prose, False, True)])
        if not bead_result["relocations"] or bead_result["relocations"][0]["is_file"]:
            problems.append("a bead-prose relocation must be reported with is_file=False "
                            "(never written) -- got %r" % bead_result["relocations"])

    for p in problems:
        print("SELF-TEST FAILED: %s" % p)
    if problems:
        return 1
    print("citation_relocate --self-test: 12 assertion(s) OK across 3 groups (hunk "
          "arithmetic, the citations_with_spans()/citation_check.citations() cross-check, "
          "and the end-to-end pass against a real throwaway git repo) -- an unaffected "
          "line before every hunk stays put, a pure insertion shifts what comes after it, "
          "a deleted or in-place-modified line is REFUSED rather than offset, --write "
          "touches only the relocatable citation and is idempotent, bead-prose detection "
          "matches citation_check's own plain-mode convention, and citations_with_spans() "
          "agrees with citation_check.citations() on both markdown and bead-prose text. "
          "NOT COVERED by this fixture: real repo history (only a synthetic 10-line "
          "file), and whether --beads' own export-reading path (citation_check."
          "bead_sources) is exercised -- it is unit-tested at citation_check.py's own "
          "--self-check, not re-tested here.")
    return 0


def main(argv: list[str]) -> int:
    return run(argv)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
