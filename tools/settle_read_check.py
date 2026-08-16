#!/usr/bin/env python3
"""settle_read_check.py - a test that reads a settle-volatile value straight after
`_T.instantiate_scene()` is asserting against however many frames the harness
happened to pump, which is a number no test states and no doc promises.

WHY THIS EXISTS.

`_T.instantiate_scene` pumps `UI_SETTLE_FRAMES` frames (currently 2, in
tools/run_tests.gd) and then returns. Anything in the hosted tree that acts on
entering the tree has therefore ALREADY ACTED by the time the test body's first
line runs - a loaded CornCobbler has fired a volley, a Pest has walked, a clock
has advanced. The frame count is an implementation detail of the harness; no test
declares a dependency on it, and nothing checks one.

`test_hosting_a_loaded_cob_puts_kernels_in_the_group_before_the_test_acts` is the
worked case. It asserted the volley had landed BY THE TIME instantiate_scene
returned. It passed alone and in the suite for two cycles, then went red when four
unrelated tests were appended and the timing shifted - which is precisely the
accident that test had been written to document. It now awaits a bounded
condition instead (test/unit/test_board.gd:739-748), and that is the fix this tool
names.

WHAT COUNTS AS SETTLE-VOLATILE, AND WHAT DOES NOT.

Not every read after hosting is exposed, and a tool that says so is noise. Three
classes are volatile, and each is DERIVED from game/ rather than hardcoded, so it
tracks the game instead of this docstring:

  A. a tree-global group census - `get_nodes_in_group()` is populated by whatever
     is in the tree, including nodes this test's own hosting spawned during the
     settle frames.
  B. an ACCUMULATOR - a member `+=`/`-=`'d inside the transitive `_process` /
     `_physics_process` closure of a game script (`run_seconds`, `_prep_left`,
     `_elapsed`...). An accumulator never converges: one more frame is always a
     different value.
  C. a physics-driven transform - `.position` / `.global_position` on a variable
     typed as a class whose `_physics_process` writes its own position (Kernel,
     Pest). Same reason: it never stops.

Deliberately NOT volatile, and the distinction is the whole point of the tool:

  * `Control.size`, `.position` on a Control, `.text`, `.visible`. Layout
     CONVERGES, and pumping it to convergence is exactly what UI_SETTLE_FRAMES
     exists to do. Reading a Control's size after instantiate_ui is the harness's
     documented contract, not a defect. Flagging it would have produced 106
     findings here, none of them real.
  * `Array.size()`. `plants.size()` is not `Control.size`.
  * constants, static function results, and a declared property the test set
     itself.

WHAT COUNTS AS A GUARD.

An `await` is NOT automatically a fix, and this tool refuses to treat one as such.
`await tree.process_frame` is still a guessed frame count - just a different guess
from the harness's. Only a BOUNDED CONDITION - loop until the thing you are
waiting for is true, with a counter cap - is a guard, because it states what it is
waiting for instead of how long. Five forms are accepted, all five already in use
in this repo:

  1. bounded condition await - `while cond and n < N: await ...`  (the preferred
     fix; test_board.gd:741)
  2. exact pin - `assert_eq(pests.size(), 1)`, `assert_float_eq(k.position.x, x)`.
     Not provenance, but a LOUD guard: if a settle frame moved the value the test
     goes red rather than measuring a stranger. Only EXACT equality counts;
     `assert_gt(size, 0)` is refused on the same grounds group_leak_check refuses
     it, namely that it was true every single time the original defect was green.
     (test_board.gd:658, test_combat.gd:1603, test_combat.gd:3865)
  3. baseline capture - read the value into a local and assert on the DELTA
     against a later read. A shifted frame count moves both sides equally.
     (test_combat.gd:167, test_economy.gd:332, and the instance-id diffs)
  4. test-assigned - the test writes the member itself before reading it, so
     whatever the settle frames did is overwritten. (test_selftest.gd:3200)
  5. exclusion diff - a loop over the group that steps over a node the test is
     HOLDING (`for p in ...: if p != early: late = p`). `!= null` does NOT count:
     a null check skips nothing the settle frames put there.
     (test_selftest.gd:173, test_selftest.gd:1291)

A whole-set `for` that never carries the loop variable out is not judged at all: a
stranger the settle frames added can only make an existence flag MORE true, so
`saw_pest_bar` is monotone in the group's size. Whether that stranger should be
there at all is group_leak_check's question, not this one.

Nothing else in the toolchain can see this:

  * `name_check.py` resolves identifiers. `get_nodes_in_group` resolves; WHEN it
    was called relative to a pumped frame is not a name question.
  * `lint_project.gd` / `import_check.py` type-check. Both sides of the bad read
    are correctly typed.
  * `group_leak_check.py` is the closest neighbour and is a different rule: it
    asks whether a test can say WHICH node it got out of a group. This asks
    whether the value was even settled when it was read - and it fires on
    accumulators and transforms, where no group is involved at all.
  * `run_tests.gd` catches a VACUOUS pass. This is the opposite: every assertion
    ran and passed, against a value that happened to have settled that time.
  * a runtime run cannot help. The defect IS that the run passes; it only shows
    up when an unrelated test shifts the timing, months later.

Parallel-safe by construction: opens no project, writes nothing to `.godot/`,
takes no lock. Exit codes follow the house contract: 0 clean, 1 findings, 2 could
not run.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

FUNC_RE = re.compile(r"^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
CLASS_RE = re.compile(r"^class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
EXTENDS_RE = re.compile(r"^extends\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
MEMBER_RE = re.compile(r"^\s*(?:static\s+)?var\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
CALL_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\(")

# `_prep_left -= delta`, `run_seconds += delta`. A plain `=` is excluded on
# purpose: assigning a computed layout value converges, incrementing never does.
INCREMENT_RE = re.compile(r"^\s*(?:self\.)?([A-Za-z_][A-Za-z0-9_]*)\s*(?:\+|-)=", re.M)
# `position += _velocity * delta` inside _physics_process makes the CLASS a mover.
MOVER_RE = re.compile(r"^\s*(?:self\.)?(?:global_position|position)\s*(?:\+|-)?=", re.M)

HOSTING_RE = re.compile(r"\b(?:instantiate_scene|instantiate_ui)\s*\(")
GROUP_RE = re.compile(
    r"\b(?:get_nodes_in_group|get_first_node_in_group)\s*\(\s*(?:\"([^\"]*)\"|'([^']*)')?")

# A guard, form 1. `while <cond>` (or `for`) whose body awaits: the loop states
# WHAT it waits for. A bare `await tree.process_frame` matches nothing here, by
# design - it is a guessed frame count, not a condition.
BOUNDED_AWAIT_RE = re.compile(
    r"^([ \t]*)(?:while|for)\b[^\n]*:[ \t]*\n(?:[^\n]*\n){0,20}?\1[ \t]+[^\n]*\bawait\b", re.M)
# Bare awaits, counted and reported but NEVER accepted as a guard.
BARE_AWAIT_RE = re.compile(r"\bawait\b[^\n]*")

# Escape hatch for a body whose settling this regex cannot follow.
WAIVER_RE = re.compile(r"settle-read-check:\s*ok\b")

# Typed locals, for form C. `var k := Kernel.new()` and `var p: Pest = _pest(...)`.
DECL_INFER_RE = re.compile(
    r"\bvar\s+([A-Za-z_][A-Za-z0-9_]*)\s*:=\s*([A-Za-z_][A-Za-z0-9_]*)\s*\.\s*new\s*\(")
DECL_TYPED_RE = re.compile(
    r"\bvar\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z_][A-Za-z0-9_]*)\s*=")


def strip_comments(text: str) -> str:
    """Comments removed, string bodies blanked, line count preserved.

    Both halves matter. Comments go because this repo has already shipped a check
    that matched the prose explaining why a token was absent - and the docstrings
    on the very tests this tool judges say `get_nodes_in_group` out loud while
    explaining that they do not do the bad thing.

    String BODIES are blanked rather than kept, unlike group_leak_check, because
    this rule never needs a string's contents: an assertion message reading
    "position after the wave" must not register as a read of `.position`. The
    quotes are kept so the blanked span is still visibly a string, and the span is
    padded to its original width so every column index still lines up.

    Escapes are handled. A blanker that does not understand `\\"` reads the tail of
    an escaped string as live code, which is an error a good-file/bad-file fixture
    cannot surface because it corrupts both files identically.
    """
    out = []
    for line in text.splitlines():
        buf = []
        in_s = None
        i = 0
        n = len(line)
        while i < n:
            c = line[i]
            if in_s is not None:
                if c == "\\" and i + 1 < n:
                    buf.append("  ")
                    i += 2
                    continue
                if c == in_s:
                    in_s = None
                    buf.append(c)
                else:
                    buf.append(" ")
                i += 1
                continue
            if c in "\"'":
                in_s = c
                buf.append(c)
                i += 1
                continue
            if c == "#":
                # Padded, not truncated. Every offset into the stripped text must
                # index the same character in the raw text, because the raw text is
                # where the group-name literal still exists to be reported. A
                # truncating stripper made this tool's first output read
                # `get_nodes_in_group("     ")`.
                buf.append(" " * (n - i))
                break
            buf.append(c)
            i += 1
        out.append("".join(buf))
    return "\n".join(out)


def split_functions(code: str, raw: str) -> list[tuple[str, int, str, str]]:
    """[(name, 1-based start line, stripped body, raw body)].

    Function-scoped, not file-scoped: a bounded await in one test must not excuse
    a naked read in the next, and one waiver must not silence a whole file. Both
    bodies are returned because the rule is judged on the stripped one (so prose
    can never satisfy it) while the waiver is a COMMENT and survives only in the
    raw one. strip_comments preserves the line count, so one slice indexes both.
    """
    lines = code.splitlines()
    raw_lines = raw.splitlines()
    starts: list[tuple[str, int]] = []
    for idx, line in enumerate(lines):
        m = FUNC_RE.match(line)
        if m:
            starts.append((m.group(1), idx))
    out = []
    for i, (name, idx) in enumerate(starts):
        end = starts[i + 1][1] if i + 1 < len(starts) else len(lines)
        out.append((name, idx + 1, "\n".join(lines[idx:end]),
                    "\n".join(raw_lines[idx:end])))
    return out


def gd_files(root: str) -> list[str]:
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in (".godot", ".git", ".beads")]
        for fn in sorted(filenames):
            if fn.endswith(".gd"):
                found.append(os.path.join(dirpath, fn))
    return sorted(found)


def volatile_vocabulary(game_root: str) -> tuple[set[str], set[str], list[str]]:
    """(accumulator member names, mover class names, notes).

    Derived from the game, never hardcoded, so a new countdown or a new projectile
    is covered the day it is written rather than the day someone remembers to edit
    this file. Walks the transitive self-call closure of every `_process` /
    `_physics_process` in `game_root`.
    """
    notes: list[str] = []
    if not os.path.isdir(game_root):
        return set(), set(), ["no game tree at %s" % game_root]

    scripts: dict[str, dict] = {}
    for path in gd_files(game_root):
        try:
            with open(path, "r", encoding="utf-8") as fh:
                code = strip_comments(fh.read())
        except (OSError, UnicodeDecodeError) as exc:
            notes.append("unreadable %s (%s)" % (path, exc))
            continue
        cm = CLASS_RE.search(code)
        em = EXTENDS_RE.search(code)
        funcs = {n: b for n, _, b, _ in split_functions(code, code)}
        scripts[path] = {
            "cls": cm.group(1) if cm else None,
            "base": em.group(1) if em else None,
            "funcs": funcs,
            "members": set(m.group(1) for m in MEMBER_RE.finditer(code)),
        }

    accumulators: set[str] = set()
    movers: set[str] = set()
    for data in scripts.values():
        funcs = data["funcs"]
        work = [n for n in ("_process", "_physics_process") if n in funcs]
        if not work:
            continue
        seen: set[str] = set()
        is_mover = False
        while work:
            name = work.pop()
            if name in seen:
                continue
            seen.add(name)
            body = funcs.get(name, "")
            for m in INCREMENT_RE.finditer(body):
                # Only DECLARED members. A local `var gained` incremented in a
                # helper is not something a test can read off a node, and letting
                # locals in is what turned `position` into a global accumulator
                # and produced a wall of false positives on Control layout.
                if m.group(1) in data["members"]:
                    accumulators.add(m.group(1))
            if MOVER_RE.search(body):
                is_mover = True
            for m in CALL_RE.finditer(body):
                if m.group(1) in funcs:
                    work.append(m.group(1))
        if is_mover and data["cls"]:
            movers.add(data["cls"])

    # Subclasses of a mover move too.
    changed = True
    while changed:
        changed = False
        for data in scripts.values():
            if data["cls"] and data["cls"] not in movers and data["base"] in movers:
                movers.add(data["cls"])
                changed = True

    if not accumulators:
        notes.append("no accumulator found in any _process closure under %s" % game_root)
    if not movers:
        notes.append("no class moves itself in _physics_process under %s" % game_root)
    return accumulators, movers, notes


def typed_locals(body: str, wanted: set[str]) -> set[str]:
    """Local variables declared as one of `wanted`."""
    out: set[str] = set()
    for m in DECL_INFER_RE.finditer(body):
        if m.group(2) in wanted:
            out.add(m.group(1))
    for m in DECL_TYPED_RE.finditer(body):
        if m.group(2) in wanted:
            out.add(m.group(1))
    return out


def _block_after(region: str, offset: int) -> str:
    """The indented block belonging to the line at `offset` (a `for` body)."""
    lines = region[:offset].split("\n")
    head_idx = len(lines) - 1
    all_lines = region.split("\n")
    head = all_lines[head_idx]
    indent = len(head) - len(head.lstrip())
    out = []
    for line in all_lines[head_idx + 1:]:
        if line.strip() and (len(line) - len(line.lstrip())) <= indent:
            break
        out.append(line)
    return "\n".join(out)


def _group_use(region: str, m: "re.Match[str]") -> str:
    """How this group read is USED: "census", "selection", or "" (iteration only).

    The distinction decides whether the read is settle-volatile at all. A count or
    an index depends on exactly what the settle frames put in the group. A plain
    `for` over the whole set does not: a stranger the settle frames added can only
    make an existence claim MORE true, never less, so `saw_pest_bar` is monotone
    in the group's size. (Whether that stranger should be there at all is
    group_leak_check's question, not this one - keeping the two scopes apart is
    what lets both be trusted.)
    """
    line_start = region.rfind("\n", 0, m.start()) + 1
    line_end = region.find("\n", m.start())
    line = region[line_start:line_end if line_end != -1 else len(region)]
    tail = region[m.end():m.end() + 200]

    fm = re.match(r"^\s*for\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::[^\n]*?)?\s+in\b", line)
    if fm:
        body = _block_after(region, m.start())
        loop_var = fm.group(1)
        # A loop that carries the LOOP VARIABLE out to an outer name is picking one
        # node out of the set, and which one it picks depends on what the settle
        # frames put there. `saw_pest_bar = true` is not that: it is an existence
        # flag, and a stranger the settle frames added can only make an existence
        # claim more true. Requiring the loop variable on the right-hand side is
        # what separates the two.
        if re.search(r"^\s+[A-Za-z_][A-Za-z0-9_.]*\s*=(?!=)[^\n]*\b%s\b"
                     % re.escape(loop_var), body, re.M):
            return "selection"
        return ""
    if re.search(r"^\s*\)?\s*\.\s*size\s*\(", tail) or re.search(r"^\s*\)?\s*\[", tail):
        return "census"
    am = re.search(r"\bvar\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::[^=\n]*)?:?=[^\n]*$", line)
    if am:
        var = am.group(1)
        rest = region[m.end():]
        if re.search(r"\b%s\s*\.\s*size\s*\(" % re.escape(var), rest):
            return "census"
        if re.search(r"\b%s\s*\[" % re.escape(var), rest):
            return "census"
    return ""


def volatile_reads(region: str, raw_region: str, accumulators: set[str],
                   movers_vars: set[str]) -> list[tuple[int, int, str, str]]:
    """[(offset, end, kind, expression)] - every settle-volatile READ in `region`.

    `end` is the offset just past the matched expression. It exists because the
    baseline-capture guard searches the text AFTER the read for a second read of
    the same value, and searching from `offset + 1` let `k.position` find its own
    `.position` one character later and declare itself baselined. That silently
    cleared every mover-transform finding; the fixture caught it.

    A read, not a write: `game._prep_left = 9.0` is the test setting the value and
    must not be reported as reading it.

    `raw_region` is only ever used to NAME the group in the report. strip_comments
    blanks string bodies, so the literal is gone from `region` - and reporting
    `get_nodes_in_group("     ")` was the first thing this tool got wrong. It
    preserves column widths, so the same offset indexes both.
    """
    found: list[tuple[int, str, str]] = []
    for m in GROUP_RE.finditer(region):
        use = _group_use(region, m)
        if not use:
            continue
        rm = GROUP_RE.match(raw_region, m.start())
        lit = None
        if rm is not None:
            lit = rm.group(1) if rm.group(1) is not None else rm.group(2)
        found.append((m.start(), m.end(), "group " + use,
                      "get_nodes_in_group(%s)" % (('"%s"' % lit) if lit else "<expr>")))
    for prop in sorted(accumulators):
        for m in re.finditer(r"\.(%s)\b(?!\s*(?:\+|-|\*|/)?=(?!=))" % re.escape(prop), region):
            found.append((m.start(), m.end(), "accumulator", ".%s" % prop))
    for var in sorted(movers_vars):
        pat = r"\b%s\s*\.\s*(global_position|position)\b(?!\s*(?:\+|-|\*|/)?=(?!=))" % re.escape(var)
        for m in re.finditer(pat, region):
            found.append((m.start(), m.end(), "transform", "%s.%s" % (var, m.group(1))))
    found.sort()
    return found


def guard_for(region: str, upto: int, end: int, kind: str, expr: str) -> str:
    """Name the guard covering the read at `upto`, or "" if there is none."""
    before = region[:upto]
    # Form 1: a bounded condition await ANYWHERE in the function after hosting -
    # not merely before the read. The canonical fix reads the value first and then
    # loops until it is what the test is waiting for (test_board.gd:739-748), so a
    # before-only search never fires on the very pattern it exists to bless. The
    # mutation harness proved that: disabling this guard changed nothing, because
    # the one fixture case it should have cleared was being cleared by baseline
    # capture instead.
    if BOUNDED_AWAIT_RE.search(region):
        return "bounded condition await"
    # Form 4: the test assigned this member itself before reading it.
    if kind == "accumulator":
        prop = expr.lstrip(".")
        if re.search(r"\.%s\s*(?:\+|-|\*|/)?=(?!=)" % re.escape(prop), before):
            return "test-assigned before the read"
    if kind == "transform":
        var, prop = expr.split(".", 1)
        if re.search(r"\b%s\s*\.\s*%s\s*(?:\+|-|\*|/)?=(?!=)"
                     % (re.escape(var), re.escape(prop)), before):
            return "test-assigned before the read"
    # Form 5: exclusion diff - the loop skips a node the test itself holds, so
    # whatever the settle frames put in the group is stepped over by name.
    # `for p in ...: if p != early: late = p`
    if kind == "group selection":
        body = _block_after(region, upto)
        # `!= null` is a null check, not an exclusion: it steps over nothing the
        # settle frames put there. Only a comparison against a name the test is
        # HOLDING is provenance. The mutation harness caught this by forcing every
        # whole-set loop to count as a selection and finding the fixture STILL
        # clean - because `if node != null` was reading as a diff.
        for em in re.finditer(r"\bif\b[^\n]*!=\s*([A-Za-z_][A-Za-z0-9_]*)", body):
            if em.group(1) not in ("null", "true", "false"):
                return "exclusion diff (loop skips a node the test holds)"
        if re.search(r"\bhas\s*\([^\n]*get_instance_id", body) or "get_instance_id" in body:
            return "exclusion diff (instance-id diff)"
    # Form 3: baseline capture - the same volatile value is read again later, so
    # the assertion is a delta and a shifted frame count moves both sides equally.
    tail = region[end:]
    if kind.startswith("group"):
        if GROUP_RE.search(tail):
            return "baseline capture (group read twice, delta or id diff)"
    else:
        needle = expr if kind == "accumulator" else "." + expr.split(".", 1)[1]
        if re.search(re.escape(needle) + r"\b", tail):
            return "baseline capture (value read twice)"
    # Form 2: an exact pin within the next few lines. `assert_eq(x, <literal>)`
    # goes RED if a settle frame moved the value, so it cannot pass on a stranger.
    # Only EXACT equality counts. assert_gt / assert_true are refused on the same
    # grounds group_leak_check refuses assert_gt(size, 0): "more than zero" was
    # true every single time the original defect was green.
    # The window starts at the beginning of the READ'S OWN LINE, not at the read.
    # `return _T.assert_float_eq(k.position.x, ...)` puts the assert call name to
    # the LEFT of the read, so a window starting at the read cannot see what is
    # asserting on it - which made the pin silently unmatchable for transforms.
    win_start = region.rfind("\n", 0, upto) + 1
    window = region[win_start:upto + 400]
    if re.search(r"assert_eq\s*\([^\n]*?\.\s*size\s*\(\s*\)\s*,\s*-?\d+", window):
        return "exact pin (assert_eq on an exact count)"
    if kind == "accumulator":
        prop = re.escape(expr.lstrip("."))
        if re.search(r"assert(?:_float)?_eq\s*\([^,\n]*\.%s\s*,\s*[-\w.\"']+" % prop, window):
            return "exact pin (assert_eq on an exact value)"
    if kind == "transform":
        var, prop = expr.split(".", 1)
        # `assert_float_eq(kernel.position.x, from.x, 0.001)` is a loud guard: if a
        # settle frame moved the node the test goes red, which is exactly what
        # test_combat.gd:3865 is asserting on purpose. Missing this made the tool's
        # only other real-repo finding a false positive.
        if re.search(r"assert(?:_float)?_eq\s*\(\s*%s\s*\.\s*%s\b"
                     % (re.escape(var), re.escape(prop)), window):
            return "exact pin (assert_eq on an exact position)"
    return ""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="project root (default: cwd)")
    ap.add_argument("--tests", default="test", help="test tree to scan (default: test)")
    ap.add_argument("--game", default="game",
                    help="game tree the volatile vocabulary is derived from")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    root = os.path.abspath(args.root)
    if not os.path.isfile(os.path.join(root, "project.godot")):
        print("settle_read_check: no project.godot at %s - cannot run." % root,
              file=sys.stderr)
        return 2

    test_root = os.path.join(root, args.tests)
    if not os.path.isdir(test_root):
        print("settle_read_check: no test tree at %s - cannot run." % test_root,
              file=sys.stderr)
        return 2

    paths = gd_files(test_root)
    if not paths:
        print("settle_read_check: no .gd files under %s - cannot run. Nothing was "
              "checked; this is not a pass." % test_root, file=sys.stderr)
        return 2

    accumulators, movers, notes = volatile_vocabulary(os.path.join(root, args.game))
    if not accumulators and not movers:
        print("settle_read_check: derived NO volatile vocabulary from %s (%s) - the "
              "group rule would still run but two of three rules would be silently "
              "empty, which reads as a pass. Cannot run."
              % (os.path.join(root, args.game), "; ".join(notes) or "no reason given"),
              file=sys.stderr)
        return 2

    scripts = 0
    fns_total = 0
    fns_hosting = 0
    fns_reading = 0
    guarded: dict[str, int] = {}
    waived = 0
    bare_await_only = 0
    findings: list[str] = []

    for path in paths:
        try:
            with open(path, "r", encoding="utf-8") as fh:
                raw = fh.read()
        except (OSError, UnicodeDecodeError) as exc:
            print("settle_read_check: cannot read %s (%s) - cannot run." % (path, exc),
                  file=sys.stderr)
            return 2
        scripts += 1
        rel = os.path.relpath(path, root).replace("\\", "/")
        code = strip_comments(raw)

        for fname, start_line, body, raw_body in split_functions(code, raw):
            fns_total += 1
            host = HOSTING_RE.search(body)
            if host is None:
                continue
            fns_hosting += 1
            region = body[host.end():]
            raw_region = raw_body[host.end():]
            movers_vars = typed_locals(body, movers)
            reads = volatile_reads(region, raw_region, accumulators, movers_vars)
            if not reads:
                continue
            fns_reading += 1

            if WAIVER_RE.search(raw_body):
                waived += 1
                continue

            offset, end, kind, expr = reads[0]
            guard = guard_for(region, offset, end, kind, expr)
            if guard:
                guarded[guard] = guarded.get(guard, 0) + 1
                continue

            if BARE_AWAIT_RE.search(region[:offset]):
                bare_await_only += 1
                extra = (" It does `await` first, but only a bare one: that is a "
                         "guessed frame count, not a condition, and it is not "
                         "accepted here as a guard.")
            else:
                extra = ""

            line_no = start_line + region[:offset].count("\n") + body[:host.end()].count("\n")
            findings.append(
                "%s:%d %s() reads %s (%s) after _T.instantiate_scene with nothing "
                "waiting for it to settle. instantiate_scene pumps UI_SETTLE_FRAMES "
                "frames and returns; anything hosted that acts on entering the tree "
                "has already acted, and the value read is whatever that undeclared "
                "frame count produced.%s\n"
                "    fix: await a BOUNDED CONDITION instead of a frame count - "
                "`while <not yet true> and waited < 30: await tree.physics_frame`. "
                "The worked example is test/unit/test_board.gd:739-748. Or guard it: "
                "pin an exact value with assert_eq (test_board.gd:658), capture a "
                "baseline and assert the delta (test_combat.gd:167), or assign the "
                "member yourself first (test_selftest.gd:3200).\n"
                "    waive: add `# settle-read-check: ok - <reason>` in the body."
                % (rel, line_no, fname, expr, kind, extra))

    if not args.quiet:
        print("settle_read_check: %d test script(s), %d function(s), %d host a scene, "
              "%d of those read a settle-volatile value, %d guarded, %d waived, "
              "%d finding(s)"
              % (scripts, fns_total, fns_hosting, fns_reading,
                 sum(guarded.values()), waived, len(findings)))
        print("  Vocabulary derived from %s/: %d accumulator(s) %s | %d mover class(es) %s"
              % (args.game, len(accumulators), sorted(accumulators),
                 len(movers), sorted(movers)))
        if fns_hosting == 0:
            print("  NOTE: nothing to check -- no function under %s calls "
                  "instantiate_scene/instantiate_ui at all. A zero denominator looks "
                  "exactly like a pass and is not one." % args.tests)
        elif fns_reading == 0:
            print("  NOTE: %d function(s) host a scene but NONE of them reads a group, "
                  "an accumulator or a mover's transform afterwards. Clean, but the "
                  "rule never fired -- that is a statement about the corpus, not about "
                  "the tool." % fns_hosting)
        for g in sorted(guarded):
            print("    guarded by %s: %d" % (g, guarded[g]))
        for n in notes:
            print("  NOTE: %s" % n)
        if bare_await_only:
            print("  NOTE: %d finding(s) below do await before the read, but only a "
                  "bare `await`. One process_frame is a guessed frame count too; it is "
                  "counted here and never accepted as a guard." % bare_await_only)
    # Outside the --quiet guard on purpose. The blind spots are the reason a
    # weaker tool can be trusted at all, so they print on EVERY run - a quiet
    # clean result that never says what it could not see is the failure mode this
    # line exists to prevent.
    if True:
        print("  NOT COVERED: this reads source, not a running tree. It cannot see a "
              "read made inside a helper it does not inline (a `_pest_at(game, ...)` "
              "that touches position is invisible), a volatile value reached through a "
              "Dictionary or an untyped var, or a group named by an expression. It "
              "judges only the FIRST volatile read after hosting, so a guarded read "
              "followed by a naked one is reported clean. Its bounded-await guard is "
              "function-scoped and structural: it accepts a `while`/`for` containing "
              "an `await` without checking that the loop condition names the value "
              "the assertion is about, so a bounded loop waiting for one thing "
              "excuses a naked read of another in the same test. It cannot tell a converging "
              "value from a diverging one beyond the three derived classes above -- "
              "notably it says nothing about Control layout, which settles on purpose. "
              "Nor does it compile anything -- only import_check.py and "
              "lint_project.gd do that, and neither is parallel-safe.")
    for f in findings:
        print("  FINDING: %s" % f)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
