#!/usr/bin/env python3
"""group_leak_check.py - a test that picks one node out of a tree-global group
picks whichever node the engine lists first, which is not necessarily the one
the test just created.

WHY THIS EXISTS, and what was actually wrong.

`test_kernels_launch_from_the_cob_on_an_offset_layer` read
`get_nodes_in_group("kernels")[0]` and asserted that kernel started at the cob. It
was green for months, then turned red when four unrelated tests were appended and
shifted the suite order. The comment left on the fix blames a previous test leaking
kernels into the group. That diagnosis is wrong, and the wrong diagnosis matters,
because it points the fix at the wrong place.

Measured, at HEAD, over a full 355-test run with a tree-global group census taken
after every single test method: ZERO groups grew across ANY test boundary. Final
census identical to the baseline, `{}`. `_T.free_ui` frees through `target.free()`,
not `queue_free` - synchronously, before the call returns - so a hosted scene and
everything it spawned is out of every group by the time the test returns. Nothing
leaks across tests. There is no cross-test leak to detect.

The stranger is fired by the SAME TEST. `instantiate_scene()` pumps two settle
frames, and a `CornCobbler` enters the tree already loaded: hosting it beside a pest
fires a volley during those frames. So by the time the test calls `corn._act()`, the
group ALREADY holds a kernel - measured: 1 before `_act`, 2 after - and
`kernels[0]` is the settle-frame one, already moved off the launch point. Same
shape, same false green, different origin: it is the test's own setup, not its
neighbour.

Which is why the rule this tool enforces is about PROVENANCE, not about leaks:

    a test that selects ONE node from a tree-global group must be able to say
    which node it got.

Two ways to say it, both already used in this repo and both accepted here:

  * diff the group around the action - snapshot instance ids (or just `.size()`)
    before, take what is new after. `_spawn_and_take` in test_selftest.gd and the
    two landed fixes in test_combat.gd all do this.
  * assert the group's EXACT cardinality - `assert_eq(pests.size(), 1)` makes
    `pests[0]` unambiguous by construction. test_board.gd does this.

`assert_gt(pests.size(), 0)` is NOT provenance. It proves the group is not empty,
which is precisely the thing that was true every time the kernel test lied.

Nothing else in the toolchain can see this:

  * `name_check.py` resolves identifiers. `get_nodes_in_group` resolves; which node
    index 0 refers to is not a name question.
  * `lint_project.gd` / `import_check.py` type-check. `Array[Node][0]` is a Node.
  * `run_tests.gd` counts assertions and catches a VACUOUS pass - a test that
    executed none of its assertions. This is the opposite failure: every assertion
    ran, against the wrong node, and passed.
  * a runtime census cannot help either. It was run; it is clean; the defect is
    invisible to it because the contamination and the read happen inside one test.

Parallel-safe by construction: opens no project, writes nothing to `.godot/`, takes
no lock. Exit codes follow the house contract: 0 clean, 1 findings, 2 could not run.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

GROUP_CALL_RE = re.compile(r"\bget_nodes_in_group\s*\(\s*(?:\"([^\"]*)\"|'([^']*)')?")
FIRST_CALL_RE = re.compile(r"\bget_first_node_in_group\s*\(\s*(?:\"([^\"]*)\"|'([^']*)')?")
# `var pests: Array[Node] = game.get_tree().get_nodes_in_group("pests")`
ASSIGN_RE = re.compile(
    r"\bvar\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::[^=]*)?=\s*[^\n]*?\bget_nodes_in_group\s*\("
)
# `get_nodes_in_group("kernels")[0]` with no variable in between.
INLINE_INDEX_RE = re.compile(r"\bget_nodes_in_group\s*\([^)]*\)\s*\[")
# Escape hatch for a body that establishes provenance some way this regex cannot follow.
WAIVER_RE = re.compile(r"group-leak-check:\s*ok\b")

# Selecting ONE node out of the array. `.size()`, `.is_empty()` and a plain `for`
# over the whole array are NOT selection - they read the set, not a member.
SELECTORS = ("front(", "back(", "pop_front(", "pop_back(", "pick_random(", "max(", "min(")

FUNC_RE = re.compile(r"^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)


def strip_comments(text: str) -> str:
    """Comments removed, string bodies kept.

    String bodies are kept on purpose: the group name is a string literal and the
    rule needs it. Comments are removed on purpose: this repo has already been
    bitten by a source-scanning check that matched the prose explaining why a
    token was absent - and the very docstring that mis-describes this defect
    contains `get_nodes_in_group` three times.
    """
    out = []
    for line in text.splitlines():
        cut = None
        in_s = None
        i = 0
        while i < len(line):
            c = line[i]
            if in_s:
                if c == "\\":
                    i += 2
                    continue
                if c == in_s:
                    in_s = None
            elif c in "\"'":
                in_s = c
            elif c == "#":
                cut = i
                break
            i += 1
        out.append(line[:cut] if cut is not None else line)
    return "\n".join(out)


def split_functions(code: str, raw: str) -> list[tuple[str, int, str, str]]:
    """[(name, 1-based start line, stripped body, raw body)].

    A top-level `func` ends the previous one. Function-scoped rather than
    file-scoped because provenance is established inside one body: a file-wide
    search would let a diff in one test excuse a bare `[0]` in another, which is
    exactly the false clean this tool must not print - and it would let ONE waiver
    anywhere in a file silence every finding in it, which is how the first draft of
    this tool passed a fixture written to make it fail.

    Both bodies are returned because they answer different questions. The rule is
    judged on the stripped body, so prose can never satisfy it. The waiver is a
    COMMENT, so it can only be found in the raw one. strip_comments preserves the
    line count, so the same slice indexes both.
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


def group_names(body: str) -> tuple[list[str], int]:
    """(literal group names read, count of reads whose group is not a literal)."""
    names: list[str] = []
    unresolved = 0
    for m in GROUP_CALL_RE.finditer(body):
        lit = m.group(1) if m.group(1) is not None else m.group(2)
        if lit is None:
            unresolved += 1
        else:
            names.append(lit)
    return names, unresolved


def selected_vars(body: str) -> list[str]:
    """Variables holding a group read that are then indexed or picked from."""
    out = []
    for m in ASSIGN_RE.finditer(body):
        var = m.group(1)
        rest = body[m.end():]
        indexed = re.search(r"\b%s\s*\[" % re.escape(var), rest)
        picked = any(("%s.%s" % (var, s)) in rest for s in SELECTORS)
        if indexed or picked:
            out.append(var)
    return out


def cardinality_pinned(body: str, var: str) -> bool:
    """`assert_eq(var.size(), N)` - exact, so index 0 is unambiguous.

    Deliberately does NOT accept assert_gt/assert_gte: "more than zero" is the
    condition under which the original defect was green every single time.
    """
    pat = r"assert_eq\s*\(\s*%s\s*\.\s*size\s*\(\s*\)\s*,\s*\d+" % re.escape(var)
    return re.search(pat, body) is not None


def gd_files(root: str) -> list[str]:
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in (".godot", ".git", ".beads")]
        for fn in sorted(filenames):
            if fn.endswith(".gd"):
                found.append(os.path.join(dirpath, fn))
    return sorted(found)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="project root (default: cwd)")
    ap.add_argument("--tests", default="test", help="test tree to scan (default: test)")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    root = os.path.abspath(args.root)
    if not os.path.isfile(os.path.join(root, "project.godot")):
        print("group_leak_check: no project.godot at %s - cannot run." % root,
              file=sys.stderr)
        return 2

    test_root = os.path.join(root, args.tests)
    if not os.path.isdir(test_root):
        print("group_leak_check: no test tree at %s - cannot run." % test_root,
              file=sys.stderr)
        return 2

    paths = gd_files(test_root)
    if not paths:
        print("group_leak_check: no .gd files under %s - cannot run. Nothing was "
              "checked; this is not a pass." % test_root, file=sys.stderr)
        return 2

    scripts = 0
    fns_reading = 0
    fns_selecting = 0
    unresolved_reads = 0
    waived = 0
    findings: list[str] = []

    for path in paths:
        try:
            with open(path, "r", encoding="utf-8") as fh:
                raw = fh.read()
        except (OSError, UnicodeDecodeError) as exc:
            print("group_leak_check: cannot read %s (%s) - cannot run." % (path, exc),
                  file=sys.stderr)
            return 2
        scripts += 1
        rel = os.path.relpath(path, root).replace("\\", "/")
        code = strip_comments(raw)

        for fname, start_line, body, raw_body in split_functions(code, raw):
            waived_here = WAIVER_RE.search(raw_body) is not None
            names, unresolved = group_names(body)
            firsts = list(FIRST_CALL_RE.finditer(body))
            if not names and not unresolved and not firsts:
                continue
            fns_reading += 1
            unresolved_reads += unresolved

            # get_first_node_in_group is selection by definition - there is no
            # index to drop and no set to diff. It is only safe under a waiver.
            for m in firsts:
                fns_selecting += 1
                lit = m.group(1) if m.group(1) is not None else m.group(2)
                if waived_here:
                    waived += 1
                    continue
                findings.append(
                    "%s:%d %s() calls get_first_node_in_group(%s). That is "
                    "\"whichever one the engine lists first\" by definition - there is "
                    "no index to drop. Diff the group around the action instead, or "
                    "hold the node the test itself created."
                    % (rel, start_line, fname, ("\"%s\"" % lit) if lit else "<non-literal>"))

            sel_vars = selected_vars(body)
            inline = INLINE_INDEX_RE.search(body)
            if not sel_vars and not inline:
                continue
            fns_selecting += 1

            if waived_here:
                waived += 1
                continue

            # Provenance A: the same group is read twice in this body -> before/after diff.
            diffed = any(names.count(n) >= 2 for n in set(names))
            if diffed:
                continue

            # Provenance B: exact cardinality asserted on the selected variable.
            if sel_vars and all(cardinality_pinned(body, v) for v in sel_vars):
                continue

            target = ", ".join(sel_vars) if sel_vars else "an inline index"
            gname = names[0] if names else "<non-literal>"
            findings.append(
                "%s:%d %s() selects one node out of the tree-global \"%s\" group (%s) "
                "with neither a before/after diff of that group nor an exact "
                "assert_eq(x.size(), N). The group can already hold nodes this test's "
                "own hosting created - instantiate_scene() pumps settle frames, and a "
                "loaded CornCobbler fires a volley during them - so index 0 is not "
                "necessarily the node under test.\n"
                "    fix: snapshot instance ids before the action and take what is new "
                "after (see _spawn_and_take in test/unit/test_selftest.gd), or pin the "
                "count with assert_eq(%s.size(), 1).\n"
                "    waive: add `# group-leak-check: ok - <reason>` in the body."
                % (rel, start_line, fname, gname, target,
                   sel_vars[0] if sel_vars else "x"))

    if not args.quiet:
        print("group_leak_check: %d test script(s), %d function(s) read a tree-global "
              "group, %d of those select a single node, %d waived, %d finding(s)"
              % (scripts, fns_reading, fns_selecting, waived, len(findings)))
        if fns_reading == 0:
            print("  NOTE: nothing to check -- no function under %s reads a tree-global "
                  "group at all. A zero denominator looks exactly like a pass and is "
                  "not one." % args.tests)
        elif fns_selecting == 0:
            print("  NOTE: %d function(s) read a group but none selects a single node "
                  "out of one. Clean, but the rule never fired." % fns_reading)
        if unresolved_reads:
            print("  NOTE: %d group read(s) name their group through an expression "
                  "rather than a string literal. Those cannot be paired into a "
                  "before/after diff by a regex and were not judged."
                  % unresolved_reads)
        print("  NOT COVERED: this reads source, not a running tree. It cannot see a "
              "selection made inside a helper it does not inline, one that reaches the "
              "group through a variable holding the name, or a node picked out of an "
              "array the test built from a group read several statements earlier. It "
              "also says nothing about whether nodes actually leak: measured at HEAD, "
              "no group grows across any test boundary, and this tool would not notice "
              "if that changed. Nor does it compile anything -- only import_check.py "
              "and lint_project.gd do that, and neither is parallel-safe.")
    for f in findings:
        print("  FINDING: %s" % f)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
