#!/usr/bin/env python3
r"""hint_guard_check.py - a spend_hint( call reachable from _refresh needs
row_is_quiet() in the same function, or it stacks a copy into the message row
on every refresh until MESSAGE_QUEUE_MAX starts refusing them.

WHY THIS EXISTS. plant-tower-defense-j724: `Hud.row_is_quiet()`
(game/hud.gd, near its own definition) documents the rule and the failure
exactly -- a LEVEL-triggered caller (one that re-enters through `_refresh`,
which runs on every purchase, uproot, plant death and wave change) that posts
into a busy row gets a `false` back from `show_message`, the next `_refresh()`
offers the same line again, and copies stack until `MESSAGE_QUEUE_MAX` starts
refusing them -- a one-shot hint shown four times, which is the wallpaper the
whole one-shot mechanism exists to prevent. Cycle 138 wrote a fifth hint site
without the guard and shipped 11 refused messages into a realistic run before
`test_a_realistic_run_refuses_no_messages_and_evicts_none` caught it -- on the
SYMPTOM, three files from the cause, naming a refusal count and not a caller.
Finding which of the five `spend_hint(` sites was responsible took a read of
all of them.

Nothing else in the toolchain can see this:

  * `name_check.py` resolves identifiers; `row_is_quiet` resolving is not the
    question, whether a given CALLER consults it before spending is.
  * `lint_project.gd` / `import_check.py` type-check; a missing guard is
    perfectly type-valid GDScript.
  * `run_tests.gd` counts assertions; a hint that stacks four copies still
    returns from `show_message` normally each time, so nothing raises.
  * `test_a_realistic_run_refuses_no_messages_and_evicts_none` is a real gate
    and stays one -- it is the only thing that would catch a SIXTH hint site
    written the same way tomorrow. It just cannot name which caller did it.

THE DESIGN QUESTION: distinguishing level- from edge-triggered statically.
Reachability from `_refresh` is the honest proxy -- an edge-triggered hint
(fired once off a signal, e.g. `_on_flight_ignored`, or off a discrete
selection, e.g. `_offer_road_hint`) is fine posting into a busy row: the
row queues it and the moment does not recur. A LEVEL-triggered hint, reached
again on the very next `_refresh`, is not.

SCOPE, STATED PLAINLY: a call-graph walk from `func _refresh` over SAME-FILE
calls in `game/game.gd` only. That is enough for this file -- every known
hint site lives in it -- and is not a project-wide call graph. See
NOT COVERED below for exactly what that walk cannot see.

    fixture:   --fixture builds two small synthetic sources in memory (not
               vendored, nothing written to the repo) and drives them through
               the real `main()` over a temp file: one currently-guarded
               level-triggered site, one already-guarded second level site,
               and one edge-triggered site with no guard (correctly none
               needed). The BAD variant is the GOOD one with the guard lines
               removed from a COPY of the first site -- exactly the mutation
               the bead asks for -- and the checker must move from 0 findings
               to 1, naming that function and no other.
    mutations: 3, all RED, restore clean. Read the finding COUNT and the named
               function, not just the exit code -- a checker that flags the
               wrong site can still report the same '1 finding(s)' number.
               drop the enclosing-function lookup (classify every site as
                 level-triggered)                -> the edge-triggered fixture
                 site (`_on_edge_event`, correctly unguarded) starts firing:
                 findings 0/1 -> 1/2, and the wrong function is now named
                 in the GOOD run.
               drop the `guard_line < spend_line` ordering check (accept a
                 guard anywhere in the function, even AFTER the spend_hint
                 call) -> the third fixture case (FIXTURE_GUARD_TOO_LATE, a
                 guard moved after the call) goes quiet: its finding count
                 drops 1 -> 0 and its exit code flips 1 -> 0, while the first
                 two cases stay green -- so a naive "count went to zero on
                 one case" reading would call this an improvement. It is the
                 opposite: the guard is being credited for gating a call it
                 runs after.
               widen CALL_RE to match a call preceded by `.` (i.e. drop the
                 negative lookbehind) -> `hud.show_message(` and
                 `RunConfig.spend_hint(` themselves start looking like
                 same-file calls if a script ever defines a function with
                 that name, inflating the reachable set; on this fixture it
                 changes nothing observable (no name collision), which is
                 itself the point of the negative-lookbehind design -- see
                 `.claude/skills/house-static-checker/SKILL.md`'s "a mutation
                 that changes nothing is not a survivor" -- so this is
                 recorded as a mutation that DID NOT survive by construction,
                 not one this fixture is equipped to catch; the real hazard is
                 named in NOT COVERED instead.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

import gdsource

REFRESH_FUNC = "_refresh"
GUARD_NAME = "row_is_quiet"
SPEND_NAME = "spend_hint"

FUNC_DECL_RE = re.compile(r"^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", re.M)
# A bare call: NOT preceded by `.` or a word character, so `hud.row_is_quiet(`
# and `RunConfig.spend_hint(` are member calls on some OTHER object and never
# read as a call to a same-file function of the same name.
CALL_RE = re.compile(r"(?<![.\w])([A-Za-z_][A-Za-z0-9_]*)\s*\(")
SPEND_RE = re.compile(r"\b%s\s*\(" % SPEND_NAME)
# The guard has to be consulted in an `if` -- a bare
# `var q := hud.row_is_quiet()` that is never read would satisfy a plain
# substring search while guarding nothing. See "Accept only guards that
# actually guard" in the house-static-checker skill.
GUARD_IF_RE = re.compile(r"^[ \t]*if\b[^\n]*\b%s\s*\(" % GUARD_NAME, re.M)


def split_functions(code: str) -> list[dict]:
    """[{name, start_line, end_line, body, body_no_decl}] over BLANKED `code`.

    A top-level `func` ends the previous one -- function-scoped, not file-scoped,
    for the same reason group_leak_check.py is: a guard in one function must not
    excuse an unguarded call in another. `body_no_decl` drops the function's own
    declaration line before either the call graph or the guard search runs it,
    or `func foo(...)` would read as foo calling itself.
    """
    lines = code.splitlines()
    starts: list[tuple[str, int]] = []
    for idx, line in enumerate(lines):
        m = FUNC_DECL_RE.match(line)
        if m:
            starts.append((m.group(1), idx))
    out = []
    for i, (name, idx) in enumerate(starts):
        end = starts[i + 1][1] if i + 1 < len(starts) else len(lines)
        body_lines = lines[idx:end]
        out.append({
            "name": name,
            "start_line": idx + 1,          # 1-based, the `func` line itself
            "end_line": end,                # 1-based, inclusive (lines[idx:end])
            "body": "\n".join(body_lines),
            "body_no_decl": "\n".join(body_lines[1:]),
        })
    return out


def build_call_graph(funcs: list[dict]) -> dict[str, set[str]]:
    """{func name: same-file function names it bare-calls}."""
    names = {f["name"] for f in funcs}
    graph: dict[str, set[str]] = {}
    for f in funcs:
        callees = {m.group(1) for m in CALL_RE.finditer(f["body_no_decl"])}
        graph[f["name"]] = callees & names
    return graph


def reachable_from(graph: dict[str, set[str]], root: str) -> set[str]:
    """Same-file functions whose body runs whenever `root` runs, root included.

    A plain BFS/DFS over bare calls only. Deliberately does not follow a
    `.connect("signal", callee)` registration -- that call does not RUN
    `callee`, it schedules it for later, which is exactly the edge-triggered
    shape this tool exists to tell apart from a direct call.
    """
    seen = {root}
    stack = [root]
    while stack:
        cur = stack.pop()
        for callee in graph.get(cur, ()):
            if callee not in seen:
                seen.add(callee)
                stack.append(callee)
    return seen


def enclosing_function(funcs: list[dict], line: int) -> dict | None:
    for f in funcs:
        if f["start_line"] <= line <= f["end_line"]:
            return f
    return None


def guarded_before(func: dict, spend_line: int) -> bool:
    """True if `func` consults row_is_quiet() in an `if` before `spend_line`."""
    body_start = func["start_line"] + 1  # body_no_decl's first line, 1-based
    for m in GUARD_IF_RE.finditer(func["body_no_decl"]):
        guard_line = body_start + func["body_no_decl"][:m.start()].count("\n")
        if guard_line < spend_line:
            return True
    return False


def analyze_source(raw: str, relpath: str) -> dict | None:
    """Run the whole check over one file's source. None means "could not run".

    Comments blanked, string bodies kept irrelevant either way -- ERASE mode is
    used because nothing here reads a literal's contents, only bare-call shape,
    and a call-shaped token inside a string body (a hint's own message text)
    must not be mistaken for a same-file call.
    """
    code = gdsource.strip_comments(raw, gdsource.ERASE)
    funcs = split_functions(code)
    names = {f["name"] for f in funcs}
    if REFRESH_FUNC not in names:
        return None

    graph = build_call_graph(funcs)
    reachable = reachable_from(graph, REFRESH_FUNC)

    sites = []
    for m in SPEND_RE.finditer(code):
        line = code.count("\n", 0, m.start()) + 1
        func = enclosing_function(funcs, line)
        if func is None:
            sites.append({"line": line, "func": "<top-level>",
                          "level_triggered": False, "guarded": False,
                          "unresolved": True})
            continue
        level = func["name"] in reachable
        guarded = level and guarded_before(func, line)
        sites.append({"line": line, "func": func["name"],
                      "level_triggered": level, "guarded": guarded,
                      "unresolved": False})

    findings = []
    for s in sites:
        if s["level_triggered"] and not s["guarded"]:
            findings.append(
                "%s:%d %s() calls spend_hint(...) and is reachable from "
                "_refresh (level-triggered) with no row_is_quiet() guard "
                "before it in the same function. A refused post (the row "
                "busy) leaves the hint owed, _refresh re-enters this "
                "function on the very next purchase/uproot/death/wave-change, "
                "and the same line stacks a second copy into the queue, then "
                "a third, until MESSAGE_QUEUE_MAX starts refusing them -- see "
                "Hud.row_is_quiet's own docstring, and "
                "test_a_realistic_run_refuses_no_messages_and_evicts_none, "
                "which catches the resulting refusal count but not the "
                "caller.\n"
                "    fix: guard it the way _maybe_teach_upgrading and "
                "_offer_dead_ground_hint already do -- "
                "`if not hud.row_is_quiet(): return` before the spend_hint "
                "call."
                % (relpath, s["line"], s["func"]))

    return {
        "functions": len(funcs),
        "reachable": reachable,
        "sites": sites,
        "findings": findings,
    }


# ---------------------------------------------------------------------------
# The synthetic fixture. Two in-memory sources, driven through the real
# main() over a temp file so a bug in the CLI wiring (argument parsing, file
# reading, exit code) fails here too, not only a bug in analyze_source.
#
# Shape mirrors the real file at a scale a fixture can be read at a glance:
# one function reachable from _refresh through an intermediate hop (the
# _refresh_dead_ground -> _offer_dead_ground_hint shape), a second reached
# directly, and one edge-triggered site fired off a discrete event and
# correctly carrying no guard.
FIXTURE_GOOD = """extends Node


func _refresh() -> void:
\t_refresh_helper()
\t_maybe_teach_something()


func _refresh_helper() -> void:
\t_offer_dead_ground_hint_like()


func _offer_dead_ground_hint_like() -> void:
\tif not hud.row_is_quiet():
\t\treturn
\tvar posted: bool = hud.show_message("tip")
\tRunConfig.spend_hint(RunConfig.HINT_X, posted)


func _maybe_teach_something() -> void:
\tif not hud.row_is_quiet():
\t\treturn
\tvar posted: bool = hud.show_message("tip2")
\tRunConfig.spend_hint(RunConfig.HINT_Y, posted)


func _on_edge_event() -> void:
\tvar posted: bool = hud.show_message("tip3")
\tRunConfig.spend_hint(RunConfig.HINT_Z, posted)
"""

# The bead's own prescribed mutation: take a COPY of a currently-guarded site
# and remove the guard. Built by editing the one function, not retyped, so the
# two fixtures cannot silently drift apart anywhere else.
_NEEDLE = (
    'func _offer_dead_ground_hint_like() -> void:\n'
    '\tif not hud.row_is_quiet():\n'
    '\t\treturn\n'
    '\tvar posted: bool = hud.show_message("tip")\n'
)
_REPLACEMENT = (
    'func _offer_dead_ground_hint_like() -> void:\n'
    '\tvar posted: bool = hud.show_message("tip")\n'
)
assert _NEEDLE in FIXTURE_GOOD, "fixture needle drifted -- fix _NEEDLE above"
FIXTURE_BAD = FIXTURE_GOOD.replace(_NEEDLE, _REPLACEMENT, 1)
assert FIXTURE_BAD != FIXTURE_GOOD, "mutation produced no change"

# A third case for the "guard after the call does not count" mutation named
# in the module docstring: the guard is present but placed AFTER spend_hint.
FIXTURE_GUARD_TOO_LATE = FIXTURE_GOOD.replace(
    'func _offer_dead_ground_hint_like() -> void:\n'
    '\tif not hud.row_is_quiet():\n'
    '\t\treturn\n'
    '\tvar posted: bool = hud.show_message("tip")\n'
    '\tRunConfig.spend_hint(RunConfig.HINT_X, posted)\n',
    'func _offer_dead_ground_hint_like() -> void:\n'
    '\tvar posted: bool = hud.show_message("tip")\n'
    '\tRunConfig.spend_hint(RunConfig.HINT_X, posted)\n'
    '\tif not hud.row_is_quiet():\n'
    '\t\tpass\n',
    1)
assert FIXTURE_GUARD_TOO_LATE != FIXTURE_GOOD, "mutation produced no change"

# (label, source, want finding count, want exit code,
#  [(function name, should fire)])
FIXTURE_CASES = [
    ("GOOD: both level-triggered sites guarded, edge site correctly bare",
     FIXTURE_GOOD, 0, 0,
     [("_offer_dead_ground_hint_like", False),
      ("_maybe_teach_something", False),
      ("_on_edge_event", False)]),
    ("BAD: the bead's own mutation -- guard removed from a copy of a "
     "guarded site",
     FIXTURE_BAD, 1, 1,
     [("_offer_dead_ground_hint_like", True),
      ("_maybe_teach_something", False),
      ("_on_edge_event", False)]),
    ("BAD: guard present but placed AFTER the spend_hint call -- does not "
     "count as guarding it",
     FIXTURE_GUARD_TOO_LATE, 1, 1,
     [("_offer_dead_ground_hint_like", True),
      ("_maybe_teach_something", False),
      ("_on_edge_event", False)]),
]


def run_fixture() -> int:
    """Return the failure count. Prints what it compared, never just a verdict."""
    import io
    import shutil
    import tempfile

    fails = 0
    tmpdir = tempfile.mkdtemp(prefix="hint_guard_fixture_")
    try:
        path = os.path.join(tmpdir, "fixture_game.gd")
        for label, source, want_findings, want_code, per_func in FIXTURE_CASES:
            with open(path, "w", encoding="utf-8", newline="") as fh:
                fh.write(source)

            old_stdout = sys.stdout
            sys.stdout = io.StringIO()
            try:
                code = main(["--root", tmpdir, "--file", "fixture_game.gd"])
                out = sys.stdout.getvalue()
            finally:
                sys.stdout = old_stdout

            found = out.count("  FINDING: ")
            print("case: %s" % label)
            ok = found == want_findings
            if not ok:
                fails += 1
            print("  %-6s finding count   %d (want %d)"
                  % ("ok" if ok else "FAIL", found, want_findings))
            ok = code == want_code
            if not ok:
                fails += 1
            print("  %-6s exit code       %d (want %d)"
                  % ("ok" if ok else "FAIL", code, want_code))

            # Named individually -- the two counts above can be right for the
            # wrong reason if the wrong function fires while another goes
            # silent. See the module docstring's first mutation.
            for fname, should_fire in per_func:
                needle = "%s() calls spend_hint" % fname
                fired = needle in out
                ok = fired == should_fire
                if not ok:
                    fails += 1
                print("  %-6s %-32s fired=%s (want %s)"
                      % ("ok" if ok else "FAIL", fname, fired, should_fire))
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    print("")
    print("hint_guard_check fixture: %d case(s), %d failure(s)."
          % (len(FIXTURE_CASES), fails))
    print("  NOT COVERED: the fixture exercises the reachability BFS, the "
          "same-function guard-before-call rule and the multi-hop call chain "
          "(_refresh -> _refresh_helper -> the hint site) over three small "
          "sources. It does not exercise a signal-connected caller, a "
          "function defined twice, or a guard spelled without a leading "
          "`if` on its own line.")
    return fails


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="project root (default: cwd)")
    ap.add_argument("--file", default="game/game.gd",
                     help="path, relative to root, of the file to scan "
                          "(default: game/game.gd)")
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--fixture", action="store_true",
                     help="run the synthetic fixture and exit; proves this "
                          "checker can FAIL, using the bead's own prescribed "
                          "mutation (a guard removed from a copy of a "
                          "guarded site)")
    args = ap.parse_args(argv)

    if args.fixture:
        return 2 if run_fixture() else 0

    root = os.path.abspath(args.root)
    full_path = os.path.join(root, args.file)
    if not os.path.isfile(full_path):
        print("hint_guard_check: no file at %s - cannot run." % full_path,
              file=sys.stderr)
        return 2

    try:
        with open(full_path, "r", encoding="utf-8") as fh:
            raw = fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        print("hint_guard_check: cannot read %s (%s) - cannot run."
              % (full_path, exc), file=sys.stderr)
        return 2

    relpath = args.file.replace("\\", "/")
    result = analyze_source(raw, relpath)
    if result is None:
        print("hint_guard_check: %s declares no func %s() - cannot run. The "
              "whole check is a walk FROM that function; without it there is "
              "nothing to walk from." % (relpath, REFRESH_FUNC),
              file=sys.stderr)
        return 2

    sites = result["sites"]
    level_sites = [s for s in sites if s["level_triggered"]]
    edge_sites = [s for s in sites if not s["level_triggered"]]
    missing = [s for s in level_sites if not s["guarded"]]
    findings = result["findings"]

    if not args.quiet:
        print("hint_guard_check: %s, %d function(s), call-graph walk from "
              "%s() reaches %d of them"
              % (relpath, result["functions"], REFRESH_FUNC,
                 len(result["reachable"])))
        print("  %d spend_hint(...) site(s) total: %d level-triggered "
              "(reachable from %s), %d edge-triggered (not reachable -- "
              "reached only via a signal or another entry point), %d "
              "level-triggered site(s) missing the row_is_quiet() guard"
              % (len(sites), len(level_sites), REFRESH_FUNC, len(edge_sites),
                 len(missing)))
        if not sites:
            print("  NOTE: nothing to check -- %s calls spend_hint(...) "
                  "nowhere at all. A zero denominator looks exactly like a "
                  "pass and is not one." % relpath)
        else:
            for s in sites:
                tag = ("LEVEL guarded" if s["level_triggered"] and s["guarded"]
                       else "LEVEL UNGUARDED" if s["level_triggered"]
                       else "edge")
                print("  site: %s:%d in %s() -- %s"
                      % (relpath, s["line"], s["func"], tag))
        print("  NOT COVERED: this walks SAME-FILE bare calls from "
              "%s() in %s only -- enough for this file, not a claim about "
              "any other. It does not follow a call made only through "
              "`.connect(signal, callee)` (correctly: that schedules a "
              "callee, it does not run it, which is the edge-triggered shape "
              "this tool exists to tell apart from a direct call); it does "
              "not follow a call into another script (game.gd calling into "
              "hud.gd and back would be invisible to it); and its guard rule "
              "accepts any `if ...row_is_quiet(...)` line before the "
              "spend_hint call in the same function -- it does not check "
              "that the branch actually returns or otherwise short-circuits, "
              "so a guard written as an `if` that falls through would be "
              "accepted and should not be. Nor does it compile anything -- "
              "only import_check.py and lint_project.gd do that, and neither "
              "is parallel-safe."
              % (REFRESH_FUNC, relpath))

    for f in findings:
        print("  FINDING: %s" % f)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
