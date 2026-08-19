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

import gdsource
import repo_walk

GROUP_CALL_RE = re.compile(r"\bget_nodes_in_group\s*\(\s*(?:\"([^\"]*)\"|'([^']*)')?")
FIRST_CALL_RE = re.compile(r"\bget_first_node_in_group\s*\(\s*(?:\"([^\"]*)\"|'([^']*)')?")
# `var pests: Array[Node] = game.get_tree().get_nodes_in_group("pests")`
ASSIGN_RE = re.compile(
    r"\bvar\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::[^=]*)?=\s*[^\n]*?\bget_nodes_in_group\s*\("
)
# `get_nodes_in_group("kernels")[0]` with no variable in between.
INLINE_INDEX_RE = re.compile(r"\bget_nodes_in_group\s*\([^)]*\)\s*\[")
# Escape hatch for a body that establishes provenance some way this regex cannot follow.
# The marker must OPEN A COMMENT. Matched against the raw function body, so before
# this it also matched the marker inside a STRING LITERAL -- and a test that pins a
# checker's contract is exactly where such a literal appears:
# `test/unit/test_selftest.gd:7612` already holds
# `["suite-reach-check: ok", "the waiver, which has to be greppable to be usable"]`
# inside a test method. Write that test for THIS checker and the test function
# asserting the marker is greppable becomes a function this checker refuses to look
# at, silently, with the exit code unchanged. Same shape as cycle 126's
# citation_check.py incident, where a bead waived itself with the sentence explaining
# the waiver. `#` is documented in the `waive:` hint this tool already prints
# (`add \`# group-leak-check: ok - <reason>\` in the body`); this makes the parser
# agree with the hint. No waiver of this marker exists in the repo today, so nothing
# moves.
WAIVER_RE = re.compile(r"#+[ \t]*group-leak-check:\s*ok\b")

# Selecting ONE node out of the array. `.size()`, `.is_empty()` and a plain `for`
# over the whole array are NOT selection - they read the set, not a member.
SELECTORS = ("front(", "back(", "pop_front(", "pop_back(", "pick_random(", "max(", "min(")

FUNC_RE = re.compile(r"^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)


# Comments blanked, string bodies KEPT (gdsource.KEEP). Both halves are deliberate.
# The group name is a string literal and this rule needs to read it, so bodies stay.
# Comments go because this repo has already been bitten by a source-scanning check
# that matched the prose explaining why a token was absent - and the very docstring
# that mis-describes this defect contains `get_nodes_in_group` three times.
#
# This used to be a local `strip_comments` that TRUNCATED the comment rather than
# padding it, and reset its quote state at every newline. tools/gdsource.py pads (so
# every offset still indexes the raw source) and understands triple-quoted blocks and
# the &"" prefix. It is one implementation for six checkers, with its own
# known-in/known-out test: `python tools/gdsource.py`.


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
        # Called on test/ only, so a nested .claude/worktrees/ checkout cannot be
        # under it today. Shared rule anyway: the immunity is a property of the
        # CALLER's argument, not of this function, and --root can be given.
        repo_walk.prune(dirpath, dirnames, root)
        for fn in sorted(filenames):
            if fn.endswith(".gd"):
                found.append(os.path.join(dirpath, fn))
    return sorted(found)


# ---------------------------------------------------------------------------
# The synthetic fixture. This tool shipped without one, so the rule that can REMOVE
# findings -- the waiver -- was the least guarded thing in the file, and a waiver
# fails quiet: findings leave the denominator and the exit code does not move.
#
# Driven through the real main() over a temp project rather than by poking WAIVER_RE,
# so deleting the `WAIVER_RE.search(...)` call site fails here even with the regex
# intact. The house contract wants a fixture that proves the checker can FAIL; the
# first case is the one that does that.
FIXTURE_SOURCE = '''extends Node


func test_bad_naked_index() -> String:
\tvar pests: Array = get_tree().get_nodes_in_group("pests")
\tvar pest = pests[0]
\treturn _T.assert_true(pest != null, "got one")


func test_good_waived() -> String:
\t# group-leak-check: ok - this fixture's tree holds exactly the one node it made.
\tvar pests: Array = get_tree().get_nodes_in_group("pests")
\tvar pest = pests[0]
\treturn _T.assert_true(pest != null, "got one")


func test_bad_marker_named_in_a_string_is_not_a_waiver() -> String:
\tvar needles: Array = ["group-leak-check: ok - the marker, quoted not meant"]
\tvar pests: Array = get_tree().get_nodes_in_group("pests")
\tvar pest = pests[0]
\treturn _T.assert_true(pest != null and needles.size() == 1, "got one")
'''

# (findings, waived, exit code). Three functions, three different results.
FIXTURE_EXPECT = (2, 1, 1)


def run_fixture() -> int:
    """Return the failure count. Prints what it compared, never just a verdict."""
    import io
    import shutil
    import tempfile

    root = tempfile.mkdtemp(prefix="group_leak_fixture_")
    fails = 0
    try:
        with open(os.path.join(root, "project.godot"), "w", encoding="utf-8") as fh:
            fh.write("config_version=5\n")
        os.makedirs(os.path.join(root, "test"))
        with open(os.path.join(root, "test", "test_fixture.gd"), "w",
                  encoding="utf-8", newline="") as fh:
            fh.write(FIXTURE_SOURCE)

        old_argv, old_stdout = sys.argv, sys.stdout
        sys.argv = ["group_leak_check.py", "--root", root]
        sys.stdout = io.StringIO()
        try:
            code = main()
            out = sys.stdout.getvalue()
        finally:
            sys.argv, sys.stdout = old_argv, old_stdout

        found = out.count("  FINDING: ")
        m = re.search(r"(\d+) of those select a single node, (\d+) waived", out)
        waived = int(m.group(2)) if m else -1
        want_found, want_waived, want_code = FIXTURE_EXPECT

        for label, got, want in (("finding(s)", found, want_found),
                                 ("waived", waived, want_waived),
                                 ("exit code", code, want_code)):
            ok = got == want
            if not ok:
                fails += 1
            print("  %-6s %-12s %s (want %s)" % ("ok" if ok else "FAIL", label, got, want))

        # Named individually, because the counts above can be right for the wrong
        # reasons -- two findings is also what you get if the waiver stops working and
        # a real finding is lost at the same time.
        for fname, should_fire in (("test_bad_naked_index", True),
                                   ("test_good_waived", False),
                                   ("test_bad_marker_named_in_a_string_is_not_a_waiver",
                                    True)):
            fired = fname in out
            ok = fired == should_fire
            if not ok:
                fails += 1
            print("  %-6s %-52s fired=%s (want %s)"
                  % ("ok" if ok else "FAIL", fname, fired, should_fire))
    finally:
        shutil.rmtree(root, ignore_errors=True)

    print("group_leak_check fixture: %d synthetic function(s), %d failure(s). The third "
          "case is cycle 126's incident in GDScript: citation_check.py's waiver was a "
          "bare substring and the first bead it closed waived ITSELF on the sentence "
          "explaining the waiver. `test/unit/test_selftest.gd:7612` already holds "
          "`[\"suite-reach-check: ok\", ...]` inside a test method, so a marker quoted "
          "in a string is a real thing in this repo's test tree -- which is the tree "
          "this checker scans. Drop the `#+[ \\t]*` from WAIVER_RE and that case goes "
          "red." % (len(FUNC_RE.findall(FIXTURE_SOURCE)), fails))
    print("  NOT COVERED: the fixture exercises the selection rule and the waiver over "
          "three hand-written functions. It says nothing about this repo's real tests, "
          "and a clean fixture is a statement about the rule, not about the corpus.")
    return fails


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="project root (default: cwd)")
    ap.add_argument("--tests", default="test", help="test tree to scan (default: test)")
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--fixture", action="store_true",
                    help="run the synthetic fixture and exit; proves this checker can "
                         "FAIL, and that a marker quoted in a string does not waive")
    args = ap.parse_args()

    if args.fixture:
        return 2 if run_fixture() else 0

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
        code = gdsource.strip_comments(raw, gdsource.KEEP)

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
