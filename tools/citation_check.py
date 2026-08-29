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

--SYMBOL (plant-tower-defense-nalv), AND WHY --AGAINST CANNOT REPLACE IT. --against
compares the TEXT a citation lands on before and after THIS cycle's own edits -- a
citation already pointing at the wrong line when the snapshot was taken has its wrong
text recorded as the baseline and compares clean forever, so an already-stale citation
in a file nobody touches this cycle is invisible to it permanently. Cycle 139 found
eleven such citations into game/pest.gd -- wrong by roughly eight hundred lines, every
one of them green under every existing mode -- only because an unrelated edit happened
to move the lines under them.

A citation that additionally NAMES the symbol it means -- `Pest._gait` (`game/pest.gd:
1527`), or in bead prose (unbackticked, same convention as PLAIN below) `_gait
(game/pest.gd:1527)` -- needs no snapshot at all: the named symbol's own
func/const/var/signal declaration either falls inside the cited range or it does not,
checked fresh every run against the CURRENT file. This is strictly narrower than
--against (most citations name no symbol at all -- see the printed "N of M ... name a
symbol" denominator) but it is the only mode that can fire on a citation that went
stale three cycles ago in a file nobody has touched since.

SCOPE HONESTY: a symbol-checked citation is a citation whose TARGET is verified, never
its argument. It says the symbol really is where the citation claims; it says nothing
about whether the prose around the citation is still a true description of that symbol.
See symbol_check()'s own NOT COVERED line for the rest, including the deliberate
precision/recall trade the unbackticked (bead-prose) form makes.

Usage:
    python tools/citation_check.py [FILE ...]         # default kanban.md
    python tools/citation_check.py --quiet FILE       # findings only, no landed lines
    python tools/citation_check.py --baseline PATH FILE
    python tools/citation_check.py --baseline-write PATH FILE
    python tools/citation_check.py --symbol [--beads] [FILE ...]
    python tools/citation_check.py --self-check       # proves --beads and --symbol can fail

Exit 0 clean, 1 findings, 2 could not run.

# fixture:   --self-check's cases 8-13 build a throwaway .gd file (tempfile) with a
#            known signal, const, func, static func and a multi-line const array,
#            then citation text that cites the right symbol at the right line, the
#            right symbol at the WRONG range, a symbol that does not exist in the
#            file at all, a plain lowercase name once backticked, a citation into a
#            multi-line declaration's own CONTINUATION line, a builtin engine type
#            name that must never be treated as a symbol, and (unbackticked, as
#            bead prose writes it) an ordinary English word next to a citation that
#            must NOT be mistaken for a symbol name.
# mutations: drop the "falls inside the cited range" check and always accept the
#              first declaration found -> the wrong-range fixture must go red
#            loosen PLAIN_SYMBOL_PREFIX to accept any bare word              -> the
#              "for no good reason (file.gd:12)" fixture must go red
#            drop the Class./call() qualifiers and require ONLY a leading underscore
#              -> the Class.member and name() fixture cases must go red
#            revert _decl_spans() to a single header line, not a body/literal span
#              -> the multi-line-continuation fixture must go red (this is not
#              hypothetical: it is what the real kanban.md run first reported as
#              two false findings, `RunConfig.HINTS` and `CompostMeter.lifetime_for`)
#            drop the BUILTIN_TYPES filter                                   -> the
#              `String` fixture must go red, reporting a builtin as "no such symbol"
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
import re

import repo_walk

ROOT = Path(__file__).resolve().parent.parent
# No default markdown target since kanban.md was retired: run bare it checks
# bead prose (with --beads) and any file named on the command line.
DEFAULT_FILES: list[str] = []

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
#
# `res://` IS CONSUMED, NOT EXCLUDED, and the difference is a whole citation. Bead prose
# quotes engine paths verbatim -- a GDScript backtrace says `res://test/unit/foo.gd:10561`
# -- and without the prefix in the pattern the match started after `res:`, producing the
# finding `cites //test/unit/test_selftest.gd -- no such file`. Merely excluding a leading
# `:` would have silenced that and lost the citation, which is the failure mode this whole
# mode exists to stop. So the prefix is matched and dropped, and the path resolves at the
# repo root like any other. Found on the first run over a bead that quoted a backtrace.
PLAIN = re.compile(
    r"(?<![`\w.:/-])(?:res://)?"
    r"([A-Za-z0-9_./-]*[A-Za-z0-9_.-]+\.(?:gd|py|md|json|tscn|tres|gdshader))"
    r":(\d+)(?:-(\d+))?(?![`\w])"
)


# ---------------------------------------------------------------------------------
# --symbol (plant-tower-defense-nalv): a citation that additionally NAMES the
# symbol it means, checked against the symbol's own declaration rather than
# against a snapshot. See the module docstring's own paragraph on this mode for
# what it buys over --against and what it still cannot see.
# ---------------------------------------------------------------------------------

# The identifier as this project's own prose already writes it immediately before a
# citation: optionally `Class.`-qualified, optionally a bare call `name()`. Used
# ONLY inside backticks (the FILE form below) -- the backticks are the author's own
# "this is code" signal, so no further restriction is needed on top of them.
SYMBOL_NAME = r"(?:[A-Za-z_][A-Za-z0-9_]*\.)?[A-Za-z_][A-Za-z0-9_]*(?:\(\))?"

# `` `Pest._gait` (`game/pest.gd:1527`) `` -- the symbol and the citation each in
# their own backticks, immediately adjacent but for the parenthesis and a space.
# Anchored with `$` and searched against the text BEFORE the citation match, so it
# only fires when the symbol sits directly against the citation's own opening
# paren, not merely somewhere earlier in the sentence.
FILE_SYMBOL_PREFIX = re.compile(r"`(%s)`\s*\($" % SYMBOL_NAME)

# Bead prose is UNBACKTICKED, same reasoning as PLAIN vs CITATION above: nothing
# renders a `bd` description, so nothing rewards backticks. Without them, a bare
# identifier immediately before "(file:line)" is indistinguishable BY SHAPE from an
# ordinary English word doing the same thing -- measured on the real export, that
# shape is 315 wide and a sample of it reads as prose: "reason (run_sim.gd:13-19)",
# "zero (game.gd:519-521)", "writes (game/run_config.gd:751)", "awaits
# (test_combat.gd:4512-4518)" -- none of those name a symbol. So the unbackticked
# form is accepted only when it carries a signal an English word essentially never
# does: a `Class.member`/`Class.CONST` dot, a `_leading_underscore`, `ALL_CAPS`, or
# an explicit `name()` call -- all four attested in the same export ("Board.
# is_buildable", "Game.UPROOT_CONFIRM_SECONDS", "_adjacent_plant",
# "get_viewport_height()"). This is a real narrowing, not a formality: it correctly
# drops a genuine symbol like "neighbour_interval_scale (game/game.gd:3003)" that
# carries none of the four signals, in exchange for never mistaking "reason" for a
# citation's subject. NOT COVERED restates this; it is the tool being honest about
# a precision/recall trade it made on purpose.
PLAIN_SYMBOL_PREFIX = re.compile(
    r"(?<![A-Za-z0-9_])"
    r"([A-Z][A-Za-z0-9]*\.[A-Za-z_][A-Za-z0-9_]*"         # Class.member / Class.CONST
    r"|_[A-Za-z0-9_]*"                                     # _private
    r"|[A-Z][A-Z0-9_]+"                                    # ALL_CAPS (2+ chars)
    r"|[A-Za-z_][A-Za-z0-9_]*\(\))"                         # name()
    r"\s*\($"
)


# Godot/GDScript BUILT-IN type names. A closed set fixed by the ENGINE, not a
# hand-curated business-logic list -- none of these can ever be a func/const/var/
# signal declaration in ANY GDScript file, in this repo or any other, so a
# citation that happens to land right after one ("`Pest.mutation` is a single
# `StringName` (`game/pest.gd:284`)") is never claiming StringName itself lives at
# that line; it is describing a TYPE, and the citation's real subject is the
# earlier, unadjacent `Pest.mutation`. Without this a symbol whose only backticked
# neighbour is its own type annotation reports "no such symbol", which is true and
# useless -- the entry never claimed a declaration there. Kept short and closed on
# purpose: the moment a name here IS legitimately declared somewhere (a project
# defining its own class named `Node`, say), this stops applying, but that has
# never been true of Godot's actual reserved builtins.
BUILTIN_TYPES = frozenset((
    "String", "StringName", "NodePath", "int", "float", "bool", "void",
    "Array", "Dictionary", "PackedStringArray", "PackedInt32Array",
    "PackedFloat32Array", "PackedByteArray", "PackedVector2Array",
    "Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Rect2", "Rect2i",
    "Transform2D", "Transform3D", "Basis", "Quaternion", "Plane", "AABB",
    "Color", "Callable", "Signal", "Variant", "Object", "RefCounted", "Resource",
    "Node", "Node2D", "Node3D", "Control", "CanvasItem",
))


def _strip_symbol(raw: str) -> str:
    """`Pest._gait` -> `_gait`, `husk_multiplier()` -> `husk_multiplier`. The Class
    qualifier and the call parens are context for a human reader; the declaration
    search below wants the bare name a `func`/`const`/`var`/`signal` line carries."""
    name = raw.rsplit(".", 1)[-1]
    if name.endswith("()"):
        name = name[:-2]
    return name


def symbol_citations(text: str, plain: bool = False) -> list[dict]:
    """Every citation in `text` immediately preceded by a qualifying symbol name --
    [{"line", "raw", "name", "path", "start", "end"}, ...].

    DELIBERATELY mirrors citations()'s own loop -- same CITATION/BARE(+PLAIN)
    pattern objects, same context-reset-on-entry-boundary rule, same bare-`:NN`-
    continuation binding -- rather than calling citations() and re-deriving spans
    from its output, because citations() does not expose WHERE on the line a match
    sat and a second implementation of the SAME rule is how two tools drift apart
    silently. self_check() cross-checks the (line, path, start, end) this produces
    against citations() on the same text so they can never quietly disagree.
    """
    out: list[dict] = []
    context: str | None = None
    prefix_re = PLAIN_SYMBOL_PREFIX if plain else FILE_SYMBOL_PREFIX
    for lineno, line in enumerate(text.splitlines(), start=1):
        if line.startswith("- ") or line.startswith("#"):
            context = None
        forms = list(CITATION.finditer(line)) + list(BARE.finditer(line))
        if plain:
            forms += list(PLAIN.finditer(line))
        for m in sorted(forms, key=lambda mm: mm.start()):
            if m.re is CITATION or m.re is PLAIN:
                context = m.group(1)
                start = int(m.group(2))
                end = int(m.group(3)) if m.group(3) else start
                path = context
            elif context is not None:
                start = int(m.group(1))
                end = int(m.group(2)) if m.group(2) else start
                path = context
            else:
                continue
            sm = prefix_re.search(line[:m.start()])
            if not sm:
                continue
            raw_symbol = sm.group(1)
            name = _strip_symbol(raw_symbol)
            if name in BUILTIN_TYPES:
                continue
            out.append({"line": lineno, "raw": raw_symbol, "name": name,
                        "path": path, "start": start, "end": end})
    return out


# GDScript's declaration grammar -- one keyword, an optional `static`, the name,
# then punctuation (`(`, `:`, `=`, or end of line for a bare `signal name`) -- is
# predictable enough that a regex is the right tool here, per house-static-
# checker's own convention ("a regex-based structural search is fine -- this is
# GDScript, not something you need a real parser for"). Not a parser: a name that
# also appears in a doc comment above its own declaration, or a local variable
# shadowing it inside another function, is invisible to this distinction -- see
# the mode's own NOT COVERED line.
def _decl_body_end(lines: list[str], header_idx: int) -> int:
    """0-based index of the LAST line belonging to the declaration whose header
    sits at `header_idx` -- the header itself for a one-line `const`/`signal`,
    further for a `func` body or a bracketed literal continued over several lines.

    Heuristic, not a bracket-matcher: GDScript's block structure is indentation,
    same as Python's, so "belongs to this declaration" is read the same way a
    person reads it -- every following line that is blank or indented STRICTLY
    MORE than the header, until the first line back at the header's own
    indentation or less. Found necessary, not merely tidy: `const HINTS: Array
    [String] = [` continues onto an indented element line before its closing
    `]` returns to column 0, and a check comparing the citation against ONLY the
    `const` line itself reported a citation to that element line as "outside the
    cited range" -- correct about the text, wrong about the claim, on a citation
    that had not drifted at all.
    """
    header_line = lines[header_idx]
    header_indent = len(header_line) - len(header_line.lstrip(" \t"))
    end = header_idx
    i = header_idx + 1
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue
        indent = len(line) - len(line.lstrip(" \t"))
        if indent <= header_indent:
            break
        end = i
        i += 1
    return end


# GDScript's declaration grammar -- one keyword, an optional `static`, the name,
# then punctuation (`(`, `:`, `=`, or end of line for a bare `signal name`) -- is
# predictable enough that a regex is the right tool here, per house-static-
# checker's own convention ("a regex-based structural search is fine -- this is
# GDScript, not something you need a real parser for"). Not a parser: a name that
# also appears in a doc comment above its own declaration, or a local variable
# shadowing it inside another function, is invisible to this distinction -- see
# the mode's own NOT COVERED line.
def _decl_spans(path: Path, name: str) -> list[tuple[int, int]]:
    """(start, end) 1-based line spans where `path` declares func/const/var/signal
    NAME -- the header line through the end of its own body/literal, per
    `_decl_body_end`. A citation is verified against the whole span, not just the
    header line, because a citation into a function's BODY or a multi-line
    literal's own continuation is citing that same declaration, not a different
    one three lines away."""
    pat = re.compile(r"^\s*(?:static\s+)?(?:func|const|var|signal)\s+"
                     + re.escape(name) + r"\b")
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return []
    return [(i + 1, _decl_body_end(lines, i) + 1)
            for i, ln in enumerate(lines) if pat.match(ln)]


def symbol_check(sources: list[tuple[str, str, bool, bool]]) -> int:
    """--symbol mode: verify each citation that NAMES a symbol against that
    symbol's own declaration. Prints "N of M citation(s) name a symbol; K
    verified, J finding(s)" and returns 0/1/2 per the house contract.
    """
    total = 0
    named = 0
    verified = 0
    findings: list[str] = []
    non_gating: list[str] = []

    for label, text, is_file, gating in sources:
        total += len(citations(text, plain=not is_file))
        for c in symbol_citations(text, plain=not is_file):
            named += 1
            loc = "%s:%d" % (label, c["line"])
            cite = key(c["path"], c["start"], c["end"])
            sink = findings if gating else non_gating
            src, ambiguous = _resolve(ROOT / "CLAUDE.md", c["path"])
            if ambiguous:
                sink.append(_printable(
                    "FINDING: %s names `%s` at %s -- that bare name matches %s.\n"
                    "  fix: write the path out so it names one of them.\n"
                    "  waive: none."
                    % (loc, c["raw"], cite,
                       " and ".join(str(a.relative_to(ROOT)) for a in ambiguous))))
                continue
            if src is None:
                sink.append(_printable(
                    "FINDING: %s names `%s` at %s -- no such file.\n"
                    "  fix: the file was renamed or removed; re-cite it or delete "
                    "the entry.\n  waive: none." % (loc, c["raw"], cite)))
                continue
            try:
                nlines = len(src.read_text(encoding="utf-8",
                                           errors="replace").splitlines())
            except OSError as exc:
                print("citation_check: %s is present but unreadable: %s"
                      % (c["path"], exc), file=sys.stderr)
                return 2
            if c["start"] < 1 or c["end"] > nlines or c["end"] < c["start"]:
                sink.append(_printable(
                    "FINDING: %s names `%s` at %s -- out of range; %s has %d "
                    "line(s).\n  fix: re-derive the line number.\n  waive: none."
                    % (loc, c["raw"], cite, c["path"], nlines)))
                continue
            spans = _decl_spans(src, c["name"])
            if not spans:
                sink.append(_printable(
                    "FINDING: %s claims `%s` is at %s, but no func/const/var/signal "
                    "declares `%s` anywhere in %s.\n"
                    "  fix: the symbol was renamed or removed; find its real name "
                    "or delete the claim.\n  waive: none."
                    % (loc, c["raw"], cite, c["name"], c["path"])))
                continue
            # OVERLAP, not containment either way: a citation may be a sub-range of
            # a multi-line declaration (one element of a literal, one line of a
            # function body) or may fully bracket it -- both are the same claim.
            if any(c["start"] <= d_end and c["end"] >= d_start
                   for d_start, d_end in spans):
                verified += 1
                continue
            span_text = "/".join(
                "%d" % s if s == e else "%d-%d" % (s, e) for s, e in spans)
            sink.append(_printable(
                "FINDING: %s claims `%s` is at %s, but `%s` is declared at %s:%s, "
                "outside the cited range.\n"
                "  fix: re-cite %s:%s (or widen the range to include it).\n"
                "  waive: none."
                % (loc, c["raw"], cite, c["name"], c["path"], span_text,
                   c["path"], span_text)))

    print("citation_check --symbol: %d of %d citation(s) name a symbol; %d "
          "verified, %d finding(s)%s"
          % (named, total, verified, len(findings),
             (" (+%d in CLOSED beads, advisory)" % len(non_gating))
             if non_gating else ""))
    if total == 0:
        print("NOTE: no citations found at all. That is a clean result only if you "
              "expected a file with none.")
    for m in findings:
        print(m)
    if non_gating:
        print("CLOSED BEADS (%d finding(s), advisory -- a closed bead is a record "
              "of what was true when it closed):" % len(non_gating))
        for m in non_gating:
            print("  " + m.replace("\n", "\n  "))
    print("NOT COVERED by --symbol: this only checks a citation immediately "
          "preceded by a symbol name -- most citations carry no symbol at all (see "
          "the 'entries carry NO citation at all' line printed by the default mode "
          "for how few entries carry any citation, and of those most name no "
          "symbol either). It verifies the citation's TARGET -- that the named "
          "symbol really is declared where the citation says -- never whether the "
          "surrounding prose's CLAIM about that symbol is still true, the same "
          "limit plain mode's own NOT COVERED line states. Detection is a regex "
          "over declaration lines, not a parser: a name that also appears in a doc "
          "comment, or is shadowed by a local variable inside another function, is "
          "invisible to it. And the unbackticked (bead-prose) form is accepted "
          "only when the name is `Class.member`-qualified, `_leading_underscore`, "
          "`ALL_CAPS`, or written as an explicit `name()` call -- an ordinary bare "
          "lowercase word before a citation is deliberately NOT treated as a "
          "symbol, because measured on the real bead export that shape is "
          "overwhelmingly prose ('reason (file.gd:12)'), not a claim about code. "
          "AND: a citation naming a symbol only to give a RELATED line -- an "
          "assignment site, a usage, a distance the symbol supplies -- reads "
          "IDENTICALLY to a declaration claim and is checked as one. Two real "
          "cases found running this over kanban.md: '...drawn ... out to "
          "`FAN_LENGTH` (`game/corn_cobbler.gd:367`)' cites where the constant is "
          "USED, not declared, and '...restores it by assigning `_message_text` "
          "(`game/hud.gd:1780`)' cites the ASSIGNMENT, not the `var` line -- both "
          "report as findings that are really about a different, unchecked "
          "question. A known, small class (2 of 84 findings in that same run); "
          "read a finding before re-citing it.")
    return 1 if findings else 0


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


# A landed line carrying no information about what was cited. Not "wrong" -- unverifiable,
# which is a different and worse thing, because every check this file performs will report it
# clean forever.
WEAK_LINES = frozenset(["", "#", "##", "###", "}", "]", ")", "},", "],", "],", "})",
                        "return", "pass", "else:", "continue", "break"])

## How many times a line may repeat in its file before a citation to it stops meaning
## anything. Five is a guess and is meant to be tuned against the printed list rather than
## defended -- the case that motivated it had 114 identical candidates, which no threshold in
## this range would miss.
WEAK_REPEAT_MAX = 5

_line_counts: dict[str, dict[str, int]] = {}


def weakness(landed_text: str, src: Path) -> str | None:
    """Why this citation cannot be checked by comparing text, or None if it can.

    THE POINT, because it is easy to read this as pedantry. `--against` compares the text a
    citation lands on. A citation landing on a blank line matches a blank line ANYWHERE, so
    when an edit moves it, restoring it by offset satisfies the drift check while pointing at
    something else entirely. Measured across cycles 129-131: ten citations found wrong by
    hand, every one of them landing somewhere like this, and two had drifted in SUBSTANCE
    rather than position -- a count written out in prose, and a function that no longer
    exists at all.

    Advisory by construction. These are citations to READ, not citations that are wrong.
    """
    lines = [l.strip() for l in landed_text.split("\n")]
    if all(l in WEAK_LINES for l in lines):
        return "lands on %s" % ("nothing" if not any(lines) else "only " + repr(lines[0]))
    key = str(src)
    if key not in _line_counts:
        counts: dict[str, int] = {}
        try:
            for raw in src.read_text(encoding="utf-8", errors="replace").splitlines():
                stripped = raw.strip()
                counts[stripped] = counts.get(stripped, 0) + 1
        except OSError:
            counts = {}
        _line_counts[key] = counts
    counts = _line_counts[key]
    # Only single-line citations: a multi-line span is distinctive even when each of its
    # lines is not, which is the whole reason ranges are worth writing.
    if len(lines) == 1:
        n = counts.get(lines[0], 0)
        if n > WEAK_REPEAT_MAX:
            return "lands on a line that appears %d times in %s" % (n, src.name)
    return None


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

    (Cases 8-11, added for --symbol, temporarily repoint the module-level ROOT at a
    throwaway directory -- declared `global` here, at function top, because Python
    requires that before ANY use of the name in a function that later assigns it.)

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
    global ROOT
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
    # Case 7: the --weak classifier, both directions. A rule that calls everything weak is
    # as useless as one that calls nothing weak, and the second failure is the silent one --
    # it prints "0 of 937" and reads exactly like a corpus with no problem in it.
    probe_src = ROOT / "tools" / "citation_check.py"
    if weakness("", probe_src) is None:
        problems.append("a blank landing was not called weak")
    if weakness("##", probe_src) is None:
        problems.append("a bare '##' landing was not called weak")
    if weakness("BEAD_WAIVER = \"citation-check: ok\"", probe_src) is not None:
        problems.append("a distinctive one-line landing was called weak; the rule is too "
                        "broad and the list it prints will not be read")
    # A multi-line span is distinctive even when its lines are not -- that is what ranges
    # are for, and calling them weak would flood the list with the citations most worth
    # writing.
    if weakness("\n".join(["##", "##"]), probe_src) is None:
        problems.append("a span of nothing but comment markers was not called weak")

    # Case 6: an engine path quoted verbatim from a backtrace. Bead prose does this whenever
    # it quotes a GDScript error, and the first version matched from after `res:`, reporting
    # `cites //test/unit/foo.gd -- no such file` against a citation that was perfectly good.
    engine = citations("SCRIPT ERROR at res://tools/citation_check.py:%d" % past_end,
                       plain=True)
    if not engine:
        problems.append("a res:// path was not seen at all")
    elif engine[0][1] != "tools/citation_check.py":
        problems.append("a res:// path resolved to %r, not the repo-relative path -- the "
                        "prefix must be consumed, not split" % engine[0][1])

    # And the detection itself, on the unbackticked form.
    for lbl, prose, _ in got:
        if not citations(prose, plain=True):
            problems.append("%s: no citation extracted from unbackticked prose -- this is "
                            "the 95-of-590 bug returning" % lbl)
        if citations(prose, plain=False):
            problems.append("%s: extracted an unbackticked citation with plain=False, so "
                            "the markdown path has been loosened too" % lbl)
    # Case 8-11: --symbol (plant-tower-defense-nalv). A throwaway .gd file with
    # known declarations, never vendored into the repo, so the fixture proves the
    # RULES fire without depending on any real file's current line numbers.
    with tempfile.TemporaryDirectory() as td:
        fake_gd = Path(td) / "fixture_symbol.gd"
        fake_gd.write_text(
            "extends Node\n"                    # 1
            "class_name FixtureSymbol\n"         # 2
            "\n"                                 # 3
            "signal escaped(x)\n"                # 4
            "const HUSK_MULTIPLIER := 2\n"       # 5
            "\n"                                 # 6
            "func _gait(delta: float) -> void:\n"  # 7
            "    pass\n"                          # 8
            "\n"                                  # 9
            "static func gait_stretch(w: float) -> float:\n"  # 10
            "    return w\n"                                   # 11
            "\n"                                                # 12
            "const HINTS: Array[String] = [\n"                  # 13
            "\tHINT_A, HINT_B,\n"                                # 14
            "]\n",                                               # 15
            encoding="utf-8")
        relpath = "fixture_symbol.gd"

        # 8a: a symbol cited exactly where it is declared -> verified, 0 findings.
        good_md = "- `FixtureSymbol._gait` (`%s:7`) is fine.\n" % relpath
        # 8b: the SAME symbol, cited at a range that does not contain line 7 --
        # the fixture the bead itself asks for: a real, gating failure.
        bad_md = "- `FixtureSymbol._gait` (`%s:1-3`) is wrong.\n" % relpath
        # 8c: a symbol that does not exist anywhere in the file.
        missing_md = "- `_no_such_symbol` (`%s:7`) is invented.\n" % relpath
        # 8d: the backtick-permissive FILE form accepts a plain lowercase name a
        # human clearly meant as code (it is backticked) -- `gait_stretch` has no
        # underscore/ALL_CAPS/dot signal and would be REJECTED under the stricter
        # PLAIN rule; the FILE form must still accept it because the backticks
        # themselves are the signal there.
        plain_shaped_md = "- `gait_stretch` (`%s:10`) is fine too.\n" % relpath
        # 8e: THE MULTI-LINE-DECLARATION FIX ITSELF. `HINTS` headers at line 13; its
        # own continuation line 14 is a real citation into that SAME declaration,
        # not a different one -- exactly the `RunConfig.HINTS`-shaped citation this
        # cycle's real kanban.md run showed reported as a false "outside the cited
        # range" finding before spans replaced single header lines.
        span_md = "- `HINTS` (`%s:14`) is fine, it's the continuation line.\n" % relpath
        # 8f: a builtin TYPE mention, not a symbol -- `game/pest.gd:2502` in the
        # real corpus reads "`Pest.mutation` is a single `StringName`
        # (`game/pest.gd:284`)", where the backticked word immediately before the
        # citation describes mutation's TYPE, not a declaration at that line. Must
        # not be counted as a named symbol at all (a "no such symbol" finding
        # about `String` would be true and useless).
        builtin_md = ("- `Pest.mutation` is a single `String` (`%s:5`), unrelated.\n"
                     % relpath)

        def _one(md_text, is_file=True, plain=False):
            return symbol_check([("fixture.md", md_text, is_file, True)])

        import io, contextlib
        # symbol_check() resolves every source as if it were a root-level document
        # (`_resolve(ROOT / "kanban.md", cited)` -- see bead_sources()'s own
        # rationale for why: every source shares one resolver). The fixture file
        # therefore has to sit BESIDE a `kanban.md`-shaped citing path for the
        # SAME reason citation_relocate.py's own self-test puts its fixture files
        # beside ITS synthetic root: `_resolve`'s first, and here only, successful
        # branch is `citing.parent / cited`. Swapped back in `finally` no matter
        # what -- a checker's own tests must not leave the module pointed at a
        # temp directory that is about to be deleted.
        real_root = ROOT
        ROOT = Path(td)
        try:
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc_good = _one(good_md)
            if rc_good != 0:
                problems.append("a symbol cited exactly at its own declaration must "
                                "exit 0 -- got %d, output: %r" % (rc_good, buf.getvalue()))
            if "1 verified, 0 finding" not in buf.getvalue():
                problems.append("the correct symbol citation was not reported as "
                                "verified: %r" % buf.getvalue())

            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc_bad = _one(bad_md)
            out = buf.getvalue()
            if rc_bad != 1:
                problems.append("THE REQUIRED FIXTURE: a symbol cited outside its own "
                                "declaration's range must exit 1 -- got %d" % rc_bad)
            if "_gait" not in out or "outside the cited range" not in out:
                problems.append("the out-of-range finding did not NAME the symbol: %r"
                                % out)

            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc_missing = _one(missing_md)
            if (rc_missing != 1
                    or "no func/const/var/signal declares" not in buf.getvalue()):
                problems.append("a symbol with no declaration anywhere in the cited "
                                "file must be a finding, not a silent pass: rc=%d %r"
                                % (rc_missing, buf.getvalue()))

            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc_plain_shaped = _one(plain_shaped_md)
            if rc_plain_shaped != 0 or "1 verified" not in buf.getvalue():
                problems.append("the backtick FILE form must accept a plain lowercase "
                                "name (the backticks are the signal, not the casing): "
                                "rc=%d %r" % (rc_plain_shaped, buf.getvalue()))

            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc_span = _one(span_md)
            if rc_span != 0 or "1 verified" not in buf.getvalue():
                problems.append("THE MULTI-LINE-DECLARATION FIX: a citation into a "
                                "multi-line const's own continuation line must "
                                "verify against the declaration's whole SPAN, not "
                                "just its header line: rc=%d %r"
                                % (rc_span, buf.getvalue()))

            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc_builtin = _one(builtin_md)
            out = buf.getvalue()
            if rc_builtin != 0 or "0 of 1" not in out:
                problems.append("a builtin TYPE name (`String`) immediately before "
                                "a citation must NOT be counted as a named symbol "
                                "at all: rc=%d %r" % (rc_builtin, out))
        finally:
            ROOT = real_root

        # Case 9: the UNBACKTICKED (bead-prose) form must reject an ordinary
        # English word and accept the four qualifying shapes -- this is the
        # measured 315-was-mostly-prose finding from the real export, reproduced
        # as a positive control that can actually fail.
        prose_word = "for no good reason (%s:7)" % relpath
        prose_dotted = "FixtureSymbol._gait (%s:7)" % relpath
        prose_underscore = "_gait (%s:7)" % relpath
        prose_allcaps = "HUSK_MULTIPLIER (%s:5)" % relpath
        prose_call = "gait_stretch() (%s:10)" % relpath
        if symbol_citations(prose_word, plain=True):
            problems.append("an ordinary English word before a plain citation was "
                            "treated as a symbol -- the 'reason (file.gd:12)' "
                            "false positive this mode exists to avoid: %r"
                            % symbol_citations(prose_word, plain=True))
        for label, prose in (("Class.member", prose_dotted),
                             ("_leading_underscore", prose_underscore),
                             ("ALL_CAPS", prose_allcaps),
                             ("name()", prose_call)):
            if not symbol_citations(prose, plain=True):
                problems.append("the %s plain-prose form was not recognised as a "
                                "symbol citation: %r" % (label, prose))

        # Case 10: symbol_citations() must never invent a (path, start, end) that
        # citations() itself does not also report -- a symbol citation is always A
        # citation first. Cross-checked on real repo text (kanban.md), not just
        # the synthetic fixture, so a drift between the two loops over messy real
        # input cannot hide behind a clean synthetic case.
        real_text = (ROOT / "CLAUDE.md").read_text(encoding="utf-8", errors="replace")
        base_set = {(ln, p, s, e) for ln, p, s, e in citations(real_text, plain=False)}
        for c in symbol_citations(real_text, plain=False):
            if (c["line"], c["path"], c["start"], c["end"]) not in base_set:
                problems.append("symbol_citations() reported %r as a citation that "
                                "citations() itself does not see -- the two loops "
                                "have drifted apart" % c)
                break

    for p in problems:
        print("SELF-CHECK FAILED: %s" % p)
    if problems:
        return 1
    print("citation_check --self-check: 13 case(s) OK -- an open bead's dead citation "
          "gates, the same defect in a closed bead does not, the unbackticked form is "
          "seen, and a line-initial %r waives a bead while a mid-sentence mention of it "
          "does not, a res:// path quoted from a backtrace resolves repo-relative, "
          "--weak calls a blank landing weak while leaving a distinctive one alone, "
          "and --symbol verifies a correctly-cited declaration, FAILS (exit 1, naming "
          "the symbol) on one cited outside its own range, fails on a symbol that "
          "does not exist in the file, accepts a plain lowercase name once it is "
          "backticked, verifies a citation into a multi-line declaration's own "
          "continuation line (not just its header), never counts a builtin engine "
          "type name as a symbol, and on the unbackticked "
          "(bead-prose) form rejects an ordinary English word while accepting "
          "Class.member, _leading_underscore, ALL_CAPS and name() shapes. NOT "
          "COVERED by this fixture: whether the real export parses, and whether a "
          "landed line supports its claim." % BEAD_WAIVER)
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
    ap.add_argument("--weak", action="store_true",
                    help="list RESOLVED citations whose landed line carries no information "
                         "-- blank, a bare brace or comment marker, or a line repeated "
                         "throughout its file. ADVISORY: these are citations to READ, not "
                         "citations that are wrong. They are the ones --against can never "
                         "check, because a blank line matches a blank line anywhere")
    ap.add_argument("--symbol", action="store_true",
                    help="check citations of the form `Symbol.name` (`file:line`) -- "
                         "verify the named symbol's own func/const/var/signal "
                         "declaration falls inside the cited range. Needs no "
                         "snapshot, unlike --against, so it catches a citation that "
                         "went stale before this cycle ever touched the file")
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
    # key -> why it cannot be checked by comparing text. Populated only under --weak.
    weak_seen: dict[str, str] = {}
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

    if args.symbol:
        if args.beads and beads_note:
            # Checked HERE, not deferred to the bottom of the default-mode print
            # block like the other early-return modes currently do (--weak,
            # --snapshot, --against) -- an unreadable export silently dropping its
            # citations from THIS mode's denominator would be exactly the "clean
            # run over an unread input" shape the house contract exists to catch.
            print("citation_check: --beads read NOTHING (%s). No bead was checked; "
                  "the count above is files only." % beads_note, file=sys.stderr)
            return 2
        return symbol_check(sources)

    for label, text, is_file, gating in sources:
        # Every source resolves as a root-level document. For a file that is what it
        # already did (`targets` are repo-root paths); for a bead there is no other
        # sensible base, and sharing one keeps ONE resolver rather than a second copy.
        path = ROOT / "CLAUDE.md"
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
            if args.weak and k not in weak_seen:
                why = weakness(landed[k], src)
                if why is not None:
                    weak_seen[k] = why
            if gating:
                gating_keys.add(k)
            # First writer wins: a target cited from two entries collapses to one key, and
            # the first is as good a place to start as the second.
            cited_at.setdefault(k, "%s:%d" % (label, md_line))
            if not args.quiet:
                body = _printable(" | ".join(l.strip()[:60] for l in lines[start - 1:end]))
                print("  %-34s %s" % (k, body))

    if args.weak:
        # THE COUNT IS THE RESULT, which is why it prints before the list. Nobody knew how
        # many of this project's citations land somewhere no text comparison can check; the
        # sample that motivated this was ten wrong out of ten read, across three cycles.
        print("")
        print("citation_check --weak: %d of %d resolved citation(s) land somewhere that "
              "carries no information -- %.0f%%."
              % (len(weak_seen), resolved,
                 (100.0 * len(weak_seen) / resolved) if resolved else 0.0))
        for k in sorted(weak_seen):
            print("  %-38s %s" % (k, weak_seen[k]))
            print("      %-36s written at %s" % ("", cited_at.get(k, "?")))
        print("ADVISORY, exit 0 always. These are citations to READ, not citations that are "
              "wrong -- a `return out` really is the line somebody meant often enough. What "
              "they share is that `--against` can never check them: it compares TEXT, and a "
              "blank line matches a blank line anywhere, so relocating one by offset after "
              "an edit satisfies the drift check while pointing at something else.")
        print("NOT COVERED by --weak: a citation landing on a DISTINCTIVE line that is "
              "nonetheless the wrong one. Two of the ten found by hand were that -- a count "
              "written out in prose, and a function that no longer exists at all -- and no "
              "rule over the landed text can see either. This narrows the reading list; it "
              "does not replace the reading.")
        return 0

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
