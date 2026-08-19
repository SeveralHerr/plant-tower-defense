#!/usr/bin/env python3
r"""readout_shape_check.py - every string a top-bar readout is ASSIGNED is declared.

WHY THIS EXISTS.

`Hud.STAT_READOUTS` gives each top-bar readout a `worst_case` string, and the row's
whole width budget is priced against those four strings: `test_no_readout_clips_its_
own_worst_case` measures each one in the real theme font, and `cmd budgets`'
`hud_readouts` entry reports the tightest. Cycle 51 tied the SET of readouts to the
Labels in the row, both directions. Nothing tied the declared STRING to the strings the
formatter can actually build.

That is the `scope-vs-claim` shape exactly: a name claiming more than its body. The
worst case is one string somebody wrote out, and the code that fills the readout is
three branches and a suffix:

    _wave_label.text = "Wave  %d oo" % state["wave"]          # endless
    _wave_label.text = "Wave  %d / %d" % [...]                # the fixed campaign
    _wave_label.text += "   threat %d" % level                # rides on either

and the compost readout shipped clipped for several cycles for precisely this reason --
the table declared "Compost  9999" while the formatter appended "  +N", so the width
test measured a string the game never renders and reported headroom that was not there.

So `STAT_READOUTS` grew a `shapes` column: every format string the code assigns to that
readout, base branches and `+=` suffixes alike. This checker is what makes that column
true, in BOTH directions, and it adds the rule the column cannot state for itself --
that the declared `worst_case` must be an instance of a base branch with EVERY suffix
applied, because a suffix is always wider than no suffix.

Nothing else can see any of it:

  * lint / name_check / import_check   every one of these assignments RESOLVES. A
                                       readout rendering "Wave  22 /..." is a correct
                                       program.
  * the suite                          `test_no_readout_clips_its_own_worst_case`
                                       measures the string the TABLE names. A branch
                                       the table has never heard of is invisible to it
                                       by construction -- that is the defect, not an
                                       oversight in the test.
  * the budget                         `hud_readouts` sweeps the same table and
                                       therefore inherits the same blind spot. A budget
                                       over a subset always reports more headroom than
                                       exists.

Parallel-safe by construction: opens no project, writes nothing to `.godot/`, takes no
lock. Exit codes follow the house contract: 0 clean, 1 findings, 2 could not run.

THE FOUR RULES.

  R1 undeclared shape   a format string assigned to `_x_label.text` that is not in that
                        readout's `shapes`. Waivable on the assignment's own line.
  R2 stale declaration  a `shapes` entry no assignment produces. The sign flipped, and
                        the one `derive-the-list` names: a recorded list with a
                        one-directional test grows entries pointing at nothing, and here
                        an entry pointing at nothing is a branch somebody THINKS is
                        priced.
  R3 worst case misses  the declared `worst_case` is not an instance of any base shape
     a suffix           with every suffix appended. This is the compost bug, as a rule.
  R4 unresolved         an assignment whose text this cannot follow. Reported rather
                        than skipped: a step-over that says nothing is how a checker
                        reports clean over the one case it cannot see. Waivable.

    fixture:   12 cases -- all declared / an undeclared shape / a stale declaration /
               a worst case missing the `+=` suffix / an RHS that cannot be resolved /
               no STAT_READOUTS at all (exit 2) / an empty table (exit 2, BY ITS
               MESSAGE) / a table with no `member` column (exit 2) / a shape reached
               through a one-hop local variable / two base branches sharing one worst
               case (clean, the wave case) / a shape mentioned only in a COMMENT inside
               the table / a waived assignment
    mutations: 11, all RED, restore clean. `python tools/readout_shape_check.py
               --mutate`, which drives tools/mutate.py as a library rather than adding a
               target to it. Read the COUNT beside each, not the verdict:

               blanking off (both views raw)      -> 1 of 12. The comment case, which is
                 the only one where prose can be mistaken for a declaration.
               the const's type annotation kept   -> 10 of 12. `const STAT_READOUTS:
                 Array[Dictionary] = [` carries a `[` before the array literal opens, and
                 this checker's FIRST run took that one: zero rows, "the table is empty",
                 a clean-looking exit 2 over a table sitting right there.
               literals read from the BLANKED view-> 9 of 12. Every shape hollows to "".
               R1 / R2 / R3 / R4 dropped          -> 1 of 12 each, by construction: each
                 rule's case is written so only that rule can move it. R4's first draft
                 was NOT -- it left the declared shape unproduced, so R2 fired instead
                 and the mutation survived while looking killed.
               one-hop local resolution removed   -> 4 of 12
               the waiver ignored                 -> 1 of 12
               empty-table guard removed          -> 1 of 12, and only because the case
                 asserts the MESSAGE. On the exit code alone the no-member guard below
                 catches the same input and this mutation survives.
               no-member-column guard removed     -> 1 of 12

               The first run of this sweep is itself worth recording: five NOT-APPLIED
               and one SURVIVED, because a file that mutates itself makes every needle
               occur twice. The survivor was a STALE needle matching only its own copy in
               the mutation list, so the experiment edited a string constant and changed
               no behaviour -- "did not apply" and "survived" wearing each other's
               clothes, which is the whole reason mutate.py separates them. Addressed by
               `# rsc-mutation:<tag>` comment now.

WHAT IT STEPS OVER is printed on every run as the NOT COVERED line, and the two worth
knowing before you trust a clean result: it compares SHAPE and never WIDTH -- a shape
can be perfectly declared and still overflow its slot, which is the budget's job -- and
it cannot tell which of two declared branches is the wider one, because it does not
measure a font. The wave readout's "the endless branch is wider than the finite one" is
an argument written into the table, not a fact this tool checked.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

import gdsource
import repo_walk

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        try:
            _stream.reconfigure(errors="replace")
        except (OSError, ValueError):
            pass

TABLE = "STAT_READOUTS"
# AUDITED against the cycle-126 self-waive incident (plant-tower-defense-vvww) and
# recorded as NOT EXPOSED. citation_check.py's --beads waiver was a bare substring and
# the first bead it closed waived ITSELF on the sentence explaining the waiver. Three
# things already stop that here: `#` is required, so the marker inside a STRING
# literal is not a waiver (a real shape -- `test/unit/test_selftest.gd:7612` holds
# `["suite-reach-check: ok", ...]` inside a test method); the scan set is
# `--sources game`, `.gd` only, while every document that discusses this marker is
# markdown or the beads export; and the waiver is read from the SCORED LINE ONLY
# (`raw_lines[line - 1]` at the call site below), which is the narrowest waiver span
# in tools/. Nothing was changed here. Same verdict for message_corpus_check.py and
# sfx_call_check.py; group_leak, save_persist, settle_read and suite_reach required
# none of this and were anchored instead.
WAIVER = re.compile(r"#\s*readout-shape-check:\s*ok\b")

# The mutation tag, assembled and never written whole -- see run_mutations() for why a
# needle spelled out in one piece cannot work in a file that mutates itself.
_MTAG = "rsc-mutation" + ":"


def _tag(name: str) -> str:
    return _MTAG + name

# A GDScript double-quoted literal, escapes included.
STRING_LIT = re.compile(r'"((?:[^"\\]|\\.)*)"')
LEADING_LIT = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"')
IDENT_ONLY = re.compile(r"^\s*([A-Za-z_]\w*)\s*$")
FUNC = re.compile(r"^(?:static\s+)?func\s+([A-Za-z_]\w*)", re.M)
# `_x_label.text =` or `_x_label.text +=`. The `(?!=)` is what keeps `.text ==` out;
# `.text !=` never matches at all, because `!` is neither whitespace nor `+`.
ASSIGN = re.compile(r"\b(_[A-Za-z_]\w*)\.text\s*(\+?=)(?!=)")
# The `=` that assigns a const, as opposed to the `[` of its type annotation.
ASSIGN_EQ = re.compile(r"(?<![=!<>])=(?!=)")

OPENERS, CLOSERS = "([{", ")]}"


def read(path: str) -> str:
    with open(path, "r", encoding="utf-8", newline="") as fh:
        return fh.read().replace("\r\n", "\n")


def views(raw: str) -> tuple[str, str]:
    """(structure, content) -- the two blanked views of the same source, offset-aligned.

    STRUCTURE is `gdsource.BLANK`: comments blanked, string BODIES blanked, quotes kept.
    Bracket matching and statement scanning run over this, because a `{` or a `,` inside
    a string literal is still a `{` to a raw scan -- the bug message_corpus_check shipped.

    CONTENT is `gdsource.KEEP`: comments blanked, strings intact. Every literal this tool
    READS comes from here, because a literal read out of the blanked view is hollowed to
    `""` and the table collapses to four empty shapes -- the OTHER bug message_corpus_check
    shipped, on the same day, in the opposite direction.

    Both modes are exactly length-preserving, so an index into one indexes the same
    character of the other and of the raw source.
    """
    return gdsource.strip_comments(raw, gdsource.BLANK), gdsource.strip_comments(raw, gdsource.KEEP)  # rsc-mutation:blank


def line_of(text: str, pos: int) -> int:
    return text.count("\n", 0, pos) + 1


def close_at(text: str, at: int) -> int:
    """Index of the bracket closing the one at `at`, or -1. Must be given STRUCTURE."""
    depth = 0
    for i in range(at, len(text)):
        ch = text[i]
        if ch in OPENERS:
            depth += 1
        elif ch in CLOSERS:
            depth -= 1
            if depth == 0:
                return i
    return -1


def statement_end(text: str, start: int) -> int:
    """End of the statement beginning at `start`: the first newline at bracket depth 0.

    A continued expression -- an array literal or a call split over lines -- is one
    statement, so the scan cannot stop at the first newline it sees. Must be given
    STRUCTURE, or a newline inside a triple-quoted literal ends the statement early.
    """
    depth = 0
    for i in range(start, len(text)):
        ch = text[i]
        if ch in OPENERS:
            depth += 1
        elif ch in CLOSERS:
            depth -= 1
        elif ch == "\n" and depth <= 0:
            return i
    return len(text)


# --------------------------------------------------------------------------- the table

def row_at(content_row: str, line: int) -> dict:
    row = {"line": line, "shapes": []}
    for key in ("name", "member", "worst_case"):
        m = re.search(r'"%s"\s*:\s*"((?:[^"\\]|\\.)*)"' % key, content_row)
        row[key] = m.group(1) if m else ""
    m = re.search(r'"shapes"\s*:\s*\[(.*?)\]', content_row, re.S)
    if m:
        row["shapes"] = STRING_LIT.findall(m.group(1))
    return row


def readouts_from(structure: str, content: str) -> tuple[list[dict], str]:
    """([row, ...], reason it could not be read).

    The rows are found by bracket depth over STRUCTURE and read out of CONTENT at the
    same offsets. A row commented out is not a row: comments are blanked in both views,
    so it is not there to be found.
    """
    at = structure.find("const %s" % TABLE)
    if at < 0:
        return [], "no `const %s` in the HUD source" % TABLE
    # Past the TYPE ANNOTATION first. `const STAT_READOUTS: Array[Dictionary] = [`
    # carries a `[` before the array literal ever opens, and taking the first one found
    # zero rows and reported the table empty -- a clean-looking exit 2 over a table that
    # was sitting right there. The assignment `=` is the boundary; `:=` reaches it too.
    eq = ASSIGN_EQ.search(structure, at)  # rsc-mutation:typeann
    if eq is None:
        return [], "`const %s` has no assignment" % TABLE
    open_at = structure.find("[", eq.end())
    if open_at < 0:
        return [], "`const %s` is not an array literal" % TABLE
    end = close_at(structure, open_at)
    if end < 0:
        return [], "`const %s`'s array literal is never closed" % TABLE
    rows: list[dict] = []
    i = open_at + 1
    while i < end:
        if structure[i] == "{":
            j = close_at(structure, i)
            if j < 0 or j > end:
                return [], "a row in `%s` is never closed" % TABLE
            rows.append(row_at(content[i:j + 1], line_of(structure, i)))  # rsc-mutation:content
            i = j + 1
        else:
            i += 1
    return rows, ""


# ---------------------------------------------------------------- the assignments

def functions(structure: str) -> list[tuple[str, int, int]]:
    """[(name, start, end)] over STRUCTURE. Scoped by function, per the house rule: a
    local variable resolved in one function must not resolve an assignment in another."""
    marks = [(m.group(1), m.start()) for m in FUNC.finditer(structure)]
    out = []
    for k, (name, start) in enumerate(marks):
        end = marks[k + 1][1] if k + 1 < len(marks) else len(structure)
        out.append((name, start, end))
    return out


def literal_at(structure: str, content: str, start: int, end: int) -> str | None:
    """The literal a statement's right-hand side OPENS with, or None.

    The span comes from STRUCTURE (which proves a literal is there and where it ends)
    and the text from CONTENT at the same offsets (which is what it says).
    """
    if LEADING_LIT.match(structure[start:end]) is None:
        return None
    m = LEADING_LIT.match(content[start:end])
    return m.group(1) if m else None


def variable_shapes(structure: str, content: str, lo: int, hi: int,
                    name: str) -> tuple[list[str], list[str], int]:
    """(bases, suffixes, unresolved count) for a local built inside [lo, hi).

    ONE hop, deliberately. `_seeds_label.text = seeds_text` where `seeds_text` was built
    from a literal is the shape this file is actually written in, three times out of
    four. A variable assigned from another variable is NOT followed -- it is reported as
    unresolved instead, because a checker that quietly gives up on the case it cannot
    handle reports clean over exactly the assignments nobody has looked at.
    """
    bases: list[str] = []
    suffixes: list[str] = []
    unresolved = 0
    pat = re.compile(r"^[\t ]*(?:var\s+)?%s\b[^=\n]*?(\+?=)(?!=)" % re.escape(name), re.M)
    for m in pat.finditer(structure[lo:hi]):
        start = lo + m.end()
        end = statement_end(structure, start)
        shape = literal_at(structure, content, start, end)
        if shape is None:
            unresolved += 1
        elif m.group(1) == "+=":
            suffixes.append(shape)
        else:
            bases.append(shape)
    return bases, suffixes, unresolved


class Assignment:
    def __init__(self, path, line, member, kind, shape, via, snippet, waived=False):
        self.path = path
        self.line = line
        self.member = member
        self.kind = kind           # "base" or "suffix"
        self.shape = shape         # None when it could not be resolved
        self.via = via             # "" for a literal, the variable name otherwise
        self.snippet = snippet
        self.waived = waived


def assignments_in(path: str, raw: str, members: set[str]) -> list[Assignment]:
    structure, content = views(raw)
    raw_lines = raw.split("\n")
    out: list[Assignment] = []
    for _fname, lo, hi in functions(structure):
        for m in ASSIGN.finditer(structure[lo:hi]):
            member = m.group(1)
            if member not in members:
                continue
            at = lo + m.start()
            start = lo + m.end()
            end = statement_end(structure, start)
            line = line_of(structure, at)
            waived = bool(WAIVER.search(raw_lines[line - 1])) if line <= len(raw_lines) else False  # rsc-mutation:waiver
            snippet = content[at:end].strip().replace("\n", " ")[:70]
            kind = "suffix" if m.group(2) == "+=" else "base"
            shape = literal_at(structure, content, start, end)
            if shape is not None:
                out.append(Assignment(path, line, member, kind, shape, "", snippet))
                continue
            ident = IDENT_ONLY.match(structure[start:end])
            if ident is None:
                out.append(Assignment(path, line, member, kind, None, "", snippet, waived))
                continue
            var = ident.group(1)  # rsc-mutation:hop
            bases, suffixes, unresolved = variable_shapes(structure, content, lo, hi, var)
            for shape in bases:
                # A variable's base becomes the LABEL's base only when the label
                # assignment is itself a `=`. `label.text += name` appends whatever the
                # variable holds, so every one of its parts is a suffix on the label.
                out.append(Assignment(path, line, member,
                                      "base" if kind == "base" else "suffix",
                                      shape, var, snippet))
            for shape in suffixes:
                out.append(Assignment(path, line, member, "suffix", shape, var, snippet))
            if unresolved or not (bases or suffixes):
                out.append(Assignment(path, line, member, kind, None, var, snippet, waived))
    return out


# ---------------------------------------------------------------------------- the rules

def covers(worst_case: str, base: str, suffixes: list[str]) -> bool:
    """Is `worst_case` an instance of `base` with EVERY suffix applied?

    Shape comparison through `gdsource.normalise_literal`, the same collapse the message
    corpus uses: `%d` and a digit run both become one placeholder and whitespace runs
    collapse, so "Compost  %d  +%d" and "Compost  9999  +99" are the same shape and
    "Compost  9999" is not. Every suffix is REQUIRED because a suffix is always wider
    than no suffix -- that is the whole of the compost bug, expressed as a rule.
    """
    return gdsource.normalise_literal(base + "".join(suffixes)) == \
        gdsource.normalise_literal(worst_case)


def findings_for(rows: list[dict], assigns: list[Assignment]) -> list[tuple]:
    """[(kind, line-or-path, message, fix)] -- every rule, over every readout."""
    out = []
    by_member: dict[str, list[Assignment]] = {}
    for a in assigns:
        by_member.setdefault(a.member, []).append(a)

    for row in rows:
        mine = by_member.get(row["member"], [])
        declared = list(row["shapes"])
        seen = [a.shape for a in mine if a.shape]

        # R4: an assignment this could not follow. First, because every rule below is
        # over a set this one says may be incomplete.
        for a in mine:
            if a.shape is None and not a.waived:  # rsc-mutation:r4
                out.append((
                    "unresolved", "%s:%d" % (a.path, a.line),
                    "the text assigned to %s cannot be followed to a literal -- `%s`"
                    % (a.member, a.snippet),
                    "assign a format literal here, or build it in a local this can see "
                    "(`var t: String = \"...\" %% x` then `%s.text = t`). Nothing is "
                    "known about this branch, which is not the same as it being fine."
                    % a.member))

        # R1: assigned but not declared.
        for a in mine:
            if a.shape and a.shape not in declared:  # rsc-mutation:r1
                out.append((
                    "undeclared", "%s:%d" % (a.path, a.line),
                    "%s is assigned the %s shape %r, which is not in %s's `shapes`"
                    % (a.member, a.kind, a.shape, row["name"]),
                    "add %r to that row's `shapes` in Hud.%s. If it is the widest thing "
                    "the readout can hold, make `worst_case` an instance of it too; if "
                    "it is narrower, say so in the row's comment -- \"narrower, and here "
                    "is why\" is checkable and an omission is not." % (a.shape, TABLE)))

        # R2: declared but nothing produces it. Suppressed for a readout that carries a
        # WAIVED assignment: the waiver says "this branch is beyond static reach", and a
        # shape the waived branch produces would be reported stale by a rule that went on
        # regardless. Absence of evidence, not evidence of absence.
        for shape in (declared if not any(a.waived for a in mine) else []):
            if shape not in seen:  # rsc-mutation:r2
                out.append((
                    "stale", "game/hud.gd:%d" % row["line"],
                    "%s declares the shape %r and no assignment produces it"
                    % (row["name"], shape),
                    "delete it, or find the branch that was removed. A shape nothing "
                    "assigns is a branch somebody thinks is priced."))

        # R3: the worst case must be a base plus EVERY suffix.
        bases = [a.shape for a in mine if a.shape and a.kind == "base"]
        suffixes = [a.shape for a in mine if a.shape and a.kind == "suffix"]
        if bases and not any(covers(row["worst_case"], b, suffixes) for b in bases):  # rsc-mutation:r3
            out.append((
                "worst-case", "game/hud.gd:%d" % row["line"],
                "%s's worst case %r is not any of its base shapes %r with every suffix "
                "%r applied" % (row["name"], row["worst_case"], bases, suffixes),
                "rewrite `worst_case` as one base branch filled to its widest with every "
                "suffix on the end -- and then re-run the width test, because a longer "
                "worst case is a wider readout. This is the compost readout's own bug: "
                "the table said \"Compost  9999\" while the formatter appended \"  +N\"."))
    return out


# ---------------------------------------------------------------------------------- run

def check(root: str, hud_rel: str, sources: str, quiet: bool = False) -> int:
    hud_path = os.path.join(root, hud_rel)
    if not os.path.isfile(hud_path):
        print("readout_shape_check: no %s - cannot run." % hud_rel, file=sys.stderr)
        return 2
    try:
        hud_raw = read(hud_path)
    except (OSError, UnicodeDecodeError) as exc:
        print("readout_shape_check: cannot read %s (%s)" % (hud_path, exc), file=sys.stderr)
        return 2
    rows, why = readouts_from(*views(hud_raw))
    if why:
        print("readout_shape_check: %s - cannot run." % why, file=sys.stderr)
        return 2
    # An empty table matches nothing, so every assignment would be a finding -- which
    # reads like a catastrophe rather than like a broken checker, and is the single most
    # confusing way for this tool to fail. Say it plainly instead.
    if not rows:  # rsc-mutation:empty
        print("readout_shape_check: Hud.%s is empty - cannot run. It declares no "
              "readouts, so there is nothing to check assignments against." % TABLE,
              file=sys.stderr)
        return 2
    members = {r["member"] for r in rows if r["member"]}
    if not members:  # rsc-mutation:member
        print("readout_shape_check: no row in Hud.%s carries a `member` - cannot run. "
              "That column is how an assignment is matched to a readout." % TABLE,
              file=sys.stderr)
        return 2

    src_root = os.path.join(root, sources)
    files = []
    for dirpath, dirnames, filenames in os.walk(src_root):
        repo_walk.prune(dirpath, dirnames, src_root)
        files.extend(os.path.join(dirpath, f) for f in sorted(filenames) if f.endswith(".gd"))

    assigns: list[Assignment] = []
    for path in sorted(files):
        try:
            raw = read(path)
        except (OSError, UnicodeDecodeError):
            continue
        assigns.extend(assignments_in(os.path.relpath(path, root).replace("\\", "/"),
                                      raw, members))

    findings = findings_for(rows, assigns)
    via_var = sum(1 for a in assigns if a.via)
    unresolved = sum(1 for a in assigns if a.shape is None)
    waived = sum(1 for a in assigns if a.waived)
    print("readout_shape_check: %d readout(s) in Hud.%s declaring %d shape(s); %d .gd "
          "file(s) under %s; %d `.text` assignment shape(s) resolved (%d through a "
          "local variable), %d unresolved (%d waived); %d finding(s)"
          % (len(rows), TABLE, sum(len(r["shapes"]) for r in rows), len(files), sources,
             len(assigns) - unresolved, via_var, unresolved, waived, len(findings)))
    if not assigns:
        print("  NOTE: nothing to check -- not one `_x_label.text =` assignment was "
              "found for any declared `member`. That is a clean result only if the "
              "readouts are genuinely never written to; if they are, the scan is "
              "looking in the wrong place (--sources) or the `member` column is stale.")
    if not quiet:
        for row in rows:
            print("  %-14s %-16s worst case %-26r %d declared shape(s)"
                  % (row["name"], row["member"], row["worst_case"], len(row["shapes"])))
    for kind, where, message, fix in findings:
        print("FINDING: %s %s -- %s" % (where, kind, message))
        print("  fix: %s" % fix)
        if kind in ("undeclared", "unresolved"):
            print("  waive: add `# readout-shape-check: ok - <reason>` on the "
                  "assignment's own line -- for text assembled from data no static "
                  "reader can reach.")
    print("  NOT COVERED: this reads source, not a running tree, and it compares SHAPE "
          "and never WIDTH -- a shape can be perfectly declared and still overflow its "
          "slot, which is what the budget and test_no_readout_clips_its_own_worst_case "
          "are for. It cannot tell which of two declared branches is the wider one, "
          "because it measures no font: \"the endless branch beats the finite one\" is "
          "an argument written into the table, not a fact checked here. It follows a "
          "local variable exactly ONE hop and reports anything further as unresolved. "
          "It matches `_x_label.text =` only, so text reached another way -- "
          "`get_node(\"SeedsLabel\").text`, a Label handed to another object, a `set()` "
          "-- is invisible to it, as is any string built at runtime from data. Nor does "
          "it compile anything: only import_check.py and lint_project.gd do that, and "
          "neither is parallel-safe.")
    return 1 if findings else 0


# ------------------------------------------------------------------------------ fixture

FIXTURE_HEAD = '''class_name FixtureHud
extends CanvasLayer

const STAT_FONT_SIZE: int = 26
const PAPER := Color.WHITE

const STAT_READOUTS: Array[Dictionary] = [
%s]


var _seeds_label: Label
var _wave_label: Label


func refresh(state: Dictionary) -> void:
%s'''


def _row_src(name, member, worst, shapes, comment=""):
    quoted = ", ".join('"%s"' % s for s in shapes)
    return ('\t{\n%s\t\t"name": "%s",\n\t\t"member": "%s",\n\t\t"width": 100.0,\n'
            '\t\t"font_size": STAT_FONT_SIZE,\n\t\t"colour": PAPER,\n'
            '\t\t"worst_case": "%s",\n\t\t"shapes": [%s],\n\t},\n'
            % (comment, name, member, worst, quoted))


SEEDS_ROW = _row_src("SeedsLabel", "_seeds_label", "Seeds  99999", ["Seeds  %d"])
SEEDS_BODY = '\tvar seeds_text: String = "Seeds  %d" % state["seeds"]\n\t_seeds_label.text = seeds_text\n'


def _hud(rows, body):
    return FIXTURE_HEAD % ("".join(rows), body)


class _Cases:
    """The fixture's own denominator. `N case(s), M failure(s)` is the number a mutation
    has to move; a fixture reporting "ok" without saying over how many cases is the
    empty-denominator failure the house contract exists to prevent."""

    def __init__(self, name):
        self.name = name
        self.total = 0
        self.failures = []

    def check(self, label, fn):
        self.total += 1
        try:
            ok, detail = fn()
        except Exception as exc:  # noqa: BLE001 - a raising case IS a failure
            ok, detail = False, "raised %s: %s" % (type(exc).__name__, exc)
        if not ok:
            self.failures.append((label, detail))

    def report(self) -> int:
        for label, detail in self.failures:
            print("  FAILED: %s -- %s" % (label, detail))
        print("%s fixture: %d case(s), %d failure(s)"
              % (self.name, self.total, len(self.failures)))
        return 1 if self.failures else 0


def run_fixture() -> int:
    import contextlib
    import io
    import shutil
    import tempfile

    root = tempfile.mkdtemp(prefix="readout_shape_")
    cases = _Cases("readout_shape")

    def run(source):
        game = os.path.join(root, "game")
        os.makedirs(game, exist_ok=True)
        with open(os.path.join(game, "hud.gd"), "w", encoding="utf-8", newline="") as fh:
            fh.write(source)
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            code = check(root, os.path.join("game", "hud.gd"), "game", quiet=True)
        return code, buf.getvalue()

    def expect(source, want_code, must_say="", must_not_say=""):
        code, out = run(source)
        if code != want_code:
            return False, "expected exit %d, got %d -- %s" % (want_code, code, out.strip()[:300])
        if must_say and must_say not in out:
            return False, "expected %r in the output, got: %s" % (must_say, out.strip()[:300])
        if must_not_say and must_not_say in out:
            return False, "did NOT expect %r in the output: %s" % (must_not_say, out.strip()[:300])
        return True, ""

    def case_clean():
        return expect(_hud([SEEDS_ROW], SEEDS_BODY), 0)

    def case_undeclared():
        body = '\t_seeds_label.text = "Seeds  %d!!" % state["seeds"]\n'
        return expect(_hud([SEEDS_ROW], body), 1, must_say="is not in SeedsLabel's `shapes`")

    def case_stale():
        row = _row_src("SeedsLabel", "_seeds_label", "Seeds  99999",
                       ["Seeds  %d", "Seeds  %d (gone)"])
        return expect(_hud([row], SEEDS_BODY), 1, must_say="and no assignment produces it")

    def case_worst_case_misses_suffix():
        # The compost bug, as a rule: a `+=` suffix the declared worst case omits.
        row = _row_src("SeedsLabel", "_seeds_label", "Seeds  99999",
                       ["Seeds  %d", "  +%d"])
        body = SEEDS_BODY + '\t_seeds_label.text += "  +%d" % state["husks"]\n'
        return expect(_hud([row], body), 1, must_say="with every suffix")

    def case_unresolved():
        # The declared shape IS produced, on purpose. Without that first assignment the
        # stale-declaration rule fires too, and then dropping R4 entirely leaves the case
        # red for the wrong reason -- the mutation survives while looking killed. An
        # assertion has to be made in a case where only the rule it names can move it.
        body = SEEDS_BODY + '\t_seeds_label.text = _compose(state)\n'
        return expect(_hud([SEEDS_ROW], body), 1, must_say="cannot be followed to a literal")

    def case_no_table():
        source = "class_name FixtureHud\nextends CanvasLayer\n\nvar _seeds_label: Label\n"
        return expect(source, 2)

    def case_empty_table():
        # The MESSAGE, not just the code: an empty table has no members either, so the
        # guard below catches the same input and a bare exit-2 assertion cannot tell the
        # two apart -- which made removing this guard a survivor.
        return expect(_hud([], "\tpass\n"), 2, must_say="declares no readouts")

    def case_no_member_column():
        row = ('\t{\n\t\t"name": "SeedsLabel",\n\t\t"worst_case": "Seeds  99999",\n'
               '\t\t"shapes": ["Seeds  %d"],\n\t},\n')
        return expect(_hud([row], SEEDS_BODY), 2, must_say="carries a `member`")

    def case_one_hop_variable():
        # The positive control for the hop itself: the shape only resolves through
        # `seeds_text`, so a checker that stopped following locals goes red here.
        return expect(_hud([SEEDS_ROW], SEEDS_BODY), 0, must_not_say="FINDING")

    def case_two_bases_one_worst_case():
        row = _row_src("WaveLabel", "_wave_label", "Wave  9999 oo   threat 99",
                       ["Wave  %d oo", "Wave  %d / %d", "   threat %d"])
        body = ('\tif state["endless"]:\n\t\t_wave_label.text = "Wave  %d oo" % state["wave"]\n'
                '\telse:\n\t\t_wave_label.text = "Wave  %d / %d" % [state["wave"], 22]\n'
                '\t_wave_label.text += "   threat %d" % state["threat"]\n')
        return expect(_hud([row], body), 0)

    def case_shape_only_in_a_comment():
        # Comments are blanked in BOTH views. A shape named only in prose is not a shape,
        # and a checker reading raw source would report it stale.
        row = _row_src("SeedsLabel", "_seeds_label", "Seeds  99999", ["Seeds  %d"],
                       comment='\t\t# was "Seeds  %d (old)", "shapes": ["Nope  %d"]\n')
        return expect(_hud([row], SEEDS_BODY), 0)

    def case_waived():
        body = '\t_seeds_label.text = _compose(state)  # readout-shape-check: ok - built from a save\n'
        return expect(_hud([SEEDS_ROW], body), 0)

    try:
        cases.check("a fully declared readout is clean", case_clean)
        cases.check("an assigned shape absent from `shapes`", case_undeclared)
        cases.check("a declared shape nothing assigns", case_stale)
        cases.check("a worst case missing a `+=` suffix", case_worst_case_misses_suffix)
        cases.check("an RHS that cannot be followed to a literal", case_unresolved)
        cases.check("no STAT_READOUTS at all is exit 2", case_no_table)
        cases.check("an empty STAT_READOUTS is exit 2, and says so", case_empty_table)
        cases.check("a table with no `member` column is exit 2", case_no_member_column)
        cases.check("a shape reached one hop through a local", case_one_hop_variable)
        cases.check("two base branches sharing one worst case", case_two_bases_one_worst_case)
        cases.check("a shape named only in a comment is not a shape", case_shape_only_in_a_comment)
        cases.check("a waived assignment", case_waived)
    finally:
        shutil.rmtree(root, ignore_errors=True)
    return cases.report()


# ---------------------------------------------------------------------------- mutations

def run_mutations() -> int:
    """Drive tools/mutate.py as a library against this file's own fixture.

    A library call rather than a `TARGETS` entry in mutate.py, because that file belongs
    to nobody in particular and this list belongs beside the code it breaks -- the same
    argument its own docstring makes for keeping a fixture rather than deleting it. It is
    the harness's documented library mode; see "USING IT AS A LIBRARY" there.

    ADDRESSED BY TAG, and it cannot be otherwise: this file mutates ITSELF, so a needle
    written out verbatim below would occur twice in the source -- once in the code and
    once here -- and mutate.py's exactly-once guard would correctly refuse it. That is
    not hypothetical; the first run of this sweep reported five NOT-APPLIED and one
    SURVIVED, and the survivor was a stale needle matching only its own copy in this
    list, so the "mutation" edited a string constant and changed no behaviour at all.
    The tag is assembled at runtime from two pieces for the same reason.
    """
    from mutate import Mutation, run_sweep

    here = os.path.abspath(__file__)
    command = [sys.executable, here, "--fixture"]

    def line(label, tag, replacement, **kw):
        return Mutation(label, _tag(tag), replacement, scope="line", **kw)

    mutations = [
        line("comment/string blanking off (both views raw)", "blank",
             replacement="    return raw, raw  # mutated: nothing blanked"),
        line("the const's type annotation is not skipped", "typeann",
             replacement="    eq = re.compile(\"\").search(structure, at)  # mutated"),
        line("table literals read from the BLANKED view", "content",
             replacement="            rows.append(row_at(structure[i:j + 1], "
                         "line_of(structure, i)))  # mutated"),
        line("R1 dropped: an undeclared shape is accepted", "r1",
             replacement="            if False:  # mutated: R1 dropped"),
        line("R2 dropped: a stale declaration is accepted", "r2",
             replacement="            if False:  # mutated: R2 dropped"),
        line("R3 dropped: the worst case need not carry a suffix", "r3",
             replacement="        if False:  # mutated: R3 dropped"),
        line("R4 dropped: an unresolved assignment is silence", "r4",
             replacement="            if False:  # mutated: R4 dropped"),
        line("the one-hop local resolution removed", "hop",
             replacement="            var = \"__no_such_local__\"  # mutated"),
        line("the waiver is ignored", "waiver",
             replacement="            waived = False  # mutated: waiver ignored"),
        line("the empty-table guard removed", "empty",
             replacement="    if False:  # mutated: empty-table guard removed"),
        line("the no-member-column guard removed", "member",
             replacement="    if False:  # mutated: member guard removed"),
    ]
    report = run_sweep(here, mutations, command, cwd=os.path.dirname(os.path.dirname(here)),
                       show_output=False)
    print("  %d of %d declared mutation(s) ran" % (len(report.results), len(mutations)))
    print("NOT PROVEN: a RED says the fixture's result MOVED when that line changed -- "
          "not that the change was semantically meaningful, and not which case caught "
          "it. Read the case count beside each verdict.")
    return report.exit_code()


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".")
    ap.add_argument("--hud", default=os.path.join("game", "hud.gd"))
    ap.add_argument("--sources", default="game")
    ap.add_argument("--quiet", action="store_true",
                    help="the denominator, the findings and the NOT COVERED line only")
    ap.add_argument("--fixture", action="store_true",
                    help="run the synthetic fixture: 11 hand-written HUDs, good and bad")
    ap.add_argument("--mutate", action="store_true",
                    help="break each stage of this checker in turn and confirm the "
                         "fixture goes red. Writes this file and puts it back, so it is "
                         "NOT parallel-safe -- run it by hand, never in the pool")
    args = ap.parse_args(argv)

    if args.fixture:
        return run_fixture()
    if args.mutate:
        return run_mutations()
    return check(os.path.abspath(args.root), args.hud, args.sources, quiet=args.quiet)


if __name__ == "__main__":
    sys.exit(main())
