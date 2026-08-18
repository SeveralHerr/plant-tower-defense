#!/usr/bin/env python3
"""save_persist_check.py - a test that reaches RunConfig._save() through the game's
own code writes the developer's real user://highscore.save, and no existing check
can see it.

WHY THIS EXISTS, and what was actually wrong.

`test/unit/test_selftest.gd` already carries
`test_no_test_persists_through_the_players_own_save`, a source scan with a
hand-written list of needles: `RunConfig.record_score`, `RunConfig.set_mute_sfx`,
and five more. A test whose body contains one of those must assign
`RunConfig.save_path` in the same function. That rule is right and the list is the
problem - it only names RunConfig's OWN methods, so it sees a test that persists
directly and is structurally blind to a test that persists through the game:

    test_quitting_a_run_through_pause_still_files_the_score
        -> Game.bank_score() -> RunConfig.record_score() -> _save()

    test_toggling_the_option_repaints_the_bars_already_on_the_board
        -> Game._unhandled_input() -> toggle_colorblind_safe() -> _save()

Both were caught by instrumenting `_save` with `get_stack()` during a real suite
run, long after the guard had been written and had been reporting clean. The first
staged both high scores at 0 and filed 320 over this machine's actual campaign
record; the second toggled the flag twice, so it wrote the same bytes back and only
the file's mtime moved. Only the SECOND one running after the first is what put the
real numbers back - the developer's save survived by suite order, not by design.

The rule here is the same rule with the list DERIVED instead of typed, and moved up
one level, from the function to the file:

    a test SCRIPT any of whose functions can reach RunConfig._save() - through any
    chain of calls in this project's own scripts - must redirect RunConfig.save_path
    in its own setup(), which run_tests.gd calls before every test method in it.

The set is computed by walking callers backwards from `_save()` to a fixpoint over
every non-test script, so a new game method that happens to persist joins the set
the moment it is written, with nobody to remember to add it.

**Why the file and not the function**, which is where the first draft of this tool
put it and got 62 findings over a suite that provably writes nothing. Every write
along these chains is conditional - `record_score` writes only above the record,
`record_milestones` only on a fresh one, the setters only on an actual change - so
"reaches `_save()`" is not the same as "writes", and a per-function rule fires on
every test that hosts `game.tscn` at all. Which condition holds is not statically
decidable, and a checker that flags 62 true-but-harmless call sites teaches people
to waive it. A per-file `setup()` redirect makes the question moot instead of
answering it: the path is wrong for the whole run, so no chain, conditional or not,
can reach the player's file. One rule, one place, one finding per script that
forgets - and the fix is inherited by every test the script ever grows.

Nothing else in the toolchain can see this:

  * the existing GDScript guard: covered above. It is kept - it enforces the same
    rule at runtime alongside the rest of the suite, and it is what this tool was
    written from - but its needle list cannot grow by itself.
  * `name_check.py` resolves identifiers. `game.bank_score()` resolves fine; where
    it eventually writes is not a name question.
  * `lint_project.gd` / `import_check.py` type-check and compile. A call that
    persists is as well-typed as one that does not.
  * `run_tests.gd` counts assertions and catches a VACUOUS pass. Here every
    assertion ran and passed; the damage was in a file no assertion mentions.
  * `run_tests.py`'s user:// reporter DOES see the write, after the fact, on the
    machine that ran it - it is what reported `changed: highscore.save` and started
    this. It cannot say which test did it, and it only fires once the developer's
    own save has already been overwritten.

Parallel-safe by construction: opens no project, writes nothing to `.godot/`, takes
no lock. Exit codes follow the house contract: 0 clean, 1 findings, 2 could not run.

    fixture:   a test reaching the writer three hops deep / one with a setup() redirect /
               one waived / one naming the writer only in prose and in a string literal,
               including an escaped \" inside it
    mutations: `return text` from strip_comments -> the prose-only file fires
               keep string bodies instead of blanking them -> the same file fires
               (this is what proves the escape handling, which no example file can)
               remove the closure, seeding only `_save` -> exit 2, "the derivation
               broke", rather than a clean pass over a one-element set
"""

from __future__ import annotations

import argparse
import os
import re
import sys

import gdsource
import repo_walk

FUNC_RE = re.compile(r"^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
WAIVER_RE = re.compile(r"save-persist-check:\s*ok\b")
# The one thing that makes a persisting call safe: pointing the autoload somewhere
# else BEFORE it writes. Restoring afterwards is not a guard - that is precisely
# what hid both of the defects in the header.
REDIRECT_RE = re.compile(r"\bRunConfig\s*\.\s*save_path\s*=")
# Where `_save` itself lives. Everything is derived backwards from this one call.
SEED_FILE = "game/run_config.gd"
SEED_FUNC = "_save"
# What run_tests.gd calls before every test method in a script. The one place a
# redirect covers tests that have not been written yet.
SETUP_FUNC = "setup"
# Directories whose scripts are the GAME, i.e. the call graph a test reaches into.
# `test/` is excluded on purpose: a test helper that persists is judged by the same
# rule as the test that calls it, not treated as part of the game.
DEFAULT_SOURCES = ("game", "devtools_ext", "ui", "addons/godot_selftest")


# Comments blanked AND string bodies and their quotes blanked (gdsource.ERASE).
# Both, unlike group_leak_check.py, which keeps string bodies because the group name
# it needs IS a literal. Nothing here is read out of a literal, and this file's own
# docstring names `RunConfig.record_score()` and `_save()` several times - a scan that
# read its own explanation would report the checker itself. Offsets are preserved
# exactly so the same slice indexes the raw text, which is where the waiver comment
# has to be found. See tools/gdsource.py; `python tools/gdsource.py` is its test.


def split_functions(code: str, raw: str) -> list[tuple[str, int, str, str]]:
    """[(name, 1-based start line, stripped body, raw body)].

    Function-scoped, not file-scoped: a redirect in one test must not excuse a
    persisting call in another, and one waiver must not silence a whole file.
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


def calls_in(body: str) -> set[str]:
    """Every `name(` in the stripped body, minus the function's own signature line."""
    first_nl = body.find("\n")
    inner = body[first_nl + 1:] if first_nl >= 0 else ""
    return set(re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\(", inner))


def gd_files(root: str) -> list[str]:
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        # Called on test/ and each --sources dir, never the repo root, so no
        # nested checkout is under it today. Shared rule anyway; see repo_walk.
        repo_walk.prune(dirpath, dirnames, root)
        for fn in sorted(filenames):
            if fn.endswith(".gd"):
                found.append(os.path.join(dirpath, fn))
    return sorted(found)


def derive_persisting(root: str, sources: tuple[str, ...]) -> tuple[dict[str, str], int, int]:
    """({function name: the chain that reaches _save}, scripts read, functions read).

    Backwards closure from `_save()`. A function persists if its body calls
    anything that persists; iterated to a fixpoint, so the chain length is not
    capped and a method added three hops away joins the set with no edit here.

    Names are unqualified, because GDScript's receiver types are not knowable from
    a regex. That over-approximates: two classes with a same-named method share one
    entry, so a test calling the innocent one is judged as if it called the other.
    Deliberate - the finding prints the chain, a false positive is obvious on
    sight, and it takes a one-line waiver. Under-approximating writes a real save.
    """
    bodies: dict[str, set[str]] = {}
    scripts = 0
    funcs = 0
    for src in sources:
        d = os.path.join(root, src)
        if not os.path.isdir(d):
            continue
        for path in gd_files(d):
            with open(path, "r", encoding="utf-8") as fh:
                raw = fh.read()
            scripts += 1
            code = gdsource.strip_comments(raw, gdsource.ERASE)
            for fname, _line, body, _rawbody in split_functions(code, raw):
                funcs += 1
                bodies.setdefault(fname, set()).update(calls_in(body))

    chains: dict[str, str] = {SEED_FUNC: SEED_FUNC + "()"}
    changed = True
    while changed:
        changed = False
        for fname, called in bodies.items():
            if fname in chains:
                continue
            for target in sorted(called):
                if target in chains:
                    chains[fname] = "%s() -> %s" % (fname, chains[target])
                    changed = True
                    break
    return chains, scripts, funcs


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="project root (default: cwd)")
    ap.add_argument("--tests", default="test", help="test tree to scan (default: test)")
    ap.add_argument("--sources", default=",".join(DEFAULT_SOURCES),
                    help="comma-separated dirs holding the game's own scripts")
    ap.add_argument("--print-set", action="store_true",
                    help="print the derived persisting set and its chains, then exit 0")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    root = os.path.abspath(args.root)
    if not os.path.isfile(os.path.join(root, "project.godot")):
        print("save_persist_check: no project.godot at %s - cannot run." % root,
              file=sys.stderr)
        return 2
    if not os.path.isfile(os.path.join(root, SEED_FILE)):
        print("save_persist_check: no %s at %s - the whole set is derived from its "
              "%s(), so there is nothing to derive. Cannot run."
              % (SEED_FILE, root, SEED_FUNC), file=sys.stderr)
        return 2

    sources = tuple(s.strip() for s in args.sources.split(",") if s.strip())
    try:
        chains, src_scripts, src_funcs = derive_persisting(root, sources)
    except (OSError, UnicodeDecodeError) as exc:
        print("save_persist_check: cannot read a source script (%s) - cannot run." % exc,
              file=sys.stderr)
        return 2

    if len(chains) < 2:
        print("save_persist_check: only %s() itself reaches %s(). Nothing calls the "
              "writer, which means the derivation broke, not that the game never "
              "saves. Cannot run." % (SEED_FUNC, SEED_FUNC), file=sys.stderr)
        return 2

    if args.print_set:
        print("save_persist_check: %d function(s) reach %s(), derived from %d script(s):"
              % (len(chains), SEED_FUNC, src_scripts))
        for name in sorted(chains):
            print("  %s" % chains[name])
        return 0

    test_root = os.path.join(root, args.tests)
    if not os.path.isdir(test_root):
        print("save_persist_check: no test tree at %s - cannot run." % test_root,
              file=sys.stderr)
        return 2
    paths = gd_files(test_root)
    if not paths:
        print("save_persist_check: no .gd files under %s - cannot run. Nothing was "
              "checked; this is not a pass." % test_root, file=sys.stderr)
        return 2

    test_scripts = 0
    reaching_scripts = 0
    persisting_fns = 0
    waived = 0
    findings: list[str] = []

    for path in paths:
        try:
            with open(path, "r", encoding="utf-8") as fh:
                raw = fh.read()
        except (OSError, UnicodeDecodeError) as exc:
            print("save_persist_check: cannot read %s (%s) - cannot run." % (path, exc),
                  file=sys.stderr)
            return 2
        test_scripts += 1
        rel = os.path.relpath(path, root).replace("\\", "/")
        code = gdsource.strip_comments(raw, gdsource.ERASE)
        funcs = split_functions(code, raw)

        reaching: list[tuple[str, int, str]] = []
        setup_redirects = False
        for fname, start_line, body, _raw_body in funcs:
            called = calls_in(body)
            hits = sorted(called & set(chains))
            if fname == SETUP_FUNC and REDIRECT_RE.search(body):
                setup_redirects = True
            if hits:
                reaching.append((fname, start_line, chains[hits[0]]))
        if not reaching:
            continue
        reaching_scripts += 1
        persisting_fns += len(reaching)
        if setup_redirects:
            continue
        if WAIVER_RE.search(raw):
            waived += 1
            continue

        shown = reaching[:3]
        more = "" if len(reaching) <= 3 else " (and %d more)" % (len(reaching) - 3)
        examples = "; ".join("%s():%d" % (n, ln) for n, ln, _c in shown) + more
        findings.append(
            "%s has no setup() that assigns RunConfig.save_path, and %d of its "
            "function(s) can reach %s(), so a run of this script can write the "
            "developer's real user://highscore.save.\n"
            "    reaching: %s\n"
            "    chain: %s\n"
            "    fix: give this script a setup() that stashes RunConfig.save_path and "
            "points it at a scratch file, and a teardown() that puts it back and "
            "deletes the scratch -- run_tests.gd calls both around every test method, "
            "so the redirect covers tests this file has not been written yet. Restoring "
            "the in-memory scores afterwards is NOT a fix; that is what hid this.\n"
            "    waive: add `# save-persist-check: ok - <reason>` in the file."
            % (rel, len(reaching), SEED_FUNC, examples, shown[0][2]))

    if not args.quiet:
        print("save_persist_check: %d function(s) across %d source script(s) reach "
              "%s(); %d test script(s), %d of them reach it (%d function(s)), %d waived, "
              "%d finding(s)"
              % (len(chains), src_scripts, SEED_FUNC, test_scripts, reaching_scripts,
                 persisting_fns, waived, len(findings)))
        if src_funcs == 0:
            print("  NOTE: nothing to check -- no function was found in %s at all."
                  % ", ".join(sources))
        if reaching_scripts == 0:
            print("  NOTE: no test script calls anything that reaches %s(). A zero "
                  "denominator looks exactly like a pass and is not one -- run "
                  "--print-set to see what the rule is even looking for." % SEED_FUNC)
        print("  NOT COVERED: this reads source, not a running tree. Receiver types are "
              "not resolved, so the set is by bare method name and two classes sharing "
              "one name share one verdict -- which is safe in this direction, since the "
              "rule it triggers is one redirect per file. It cannot see a call made "
              "through a Callable, a signal connection, or a string passed to call(); it "
              "accepts any setup() that assigns save_path without checking WHERE it "
              "points or that teardown puts it back; and it says nothing about the other "
              "user:// files a suite may write. Nor does it compile anything -- only "
              "import_check.py and lint_project.gd do that, and neither is parallel-safe.")
    for f in findings:
        print("  FINDING: %s" % f)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
