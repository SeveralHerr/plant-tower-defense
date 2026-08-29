#!/usr/bin/env python3
r"""script_entry_check.py - a `--script` entry point that names a game class does not run.

WHY THIS EXISTS (found the hard way in cycle 179, writing `tools/playtest.gd`).

`godot --headless --path . --script res://tools/playtest.gd` compiles the script BEFORE
it registers the project's autoload singletons. So a compile-time reference from an entry
point to a project `class_name` whose own code names an autoload -- which, in this
project, is almost every class in `game/` -- fails to resolve the singleton, and the whole
dependency chain fails to compile. Verbatim, from the first run of playtest.gd:

    SCRIPT ERROR: Compile Error: Identifier not found: RunConfig
       at: GDScript::reload (res://game/game.gd:364)
    SCRIPT ERROR: Compile Error: Failed to compile depended scripts.
       at: GDScript::reload (res://tools/playtest.gd:0)
    ERROR: Failed to load script "res://tools/playtest.gd" with error "Compilation failed".

**And then the script ran anyway and exited 0.** `_initialize()` was never called, the
tool printed its own summary line over an empty result set, and the process exit code was
0. That is the shape this repo cares about most: a gate that reports success having
verified nothing. The fix is four characters of indirection -- `load("res://…")` inside
the function, after the first frames -- and it is invisible to anyone who has not been
bitten, because the broken form is the obvious one to write.

WHICH EXISTING GATE WOULD HAVE CAUGHT THIS, AND WHY IT DOES NOT.

None of them.

  * `name_check.py` resolves `RunSim` and `Game` correctly -- they ARE declared, and it
    has no concept of when a singleton is registered. It printed `errors: 0`.
  * `lint_project.gd` `load()`s scripts from a normal SceneTree run, where the autoloads
    exist. It printed `0 error(s), 0 warning(s)`.
  * `import_check.py` registers global class names; the entry point compiles fine in that
    context too.
  * `run_tests.py` never loads `tools/*.gd` at all -- they are not under `test_dir`.

The failure is a property of ONE launch mode, and nothing else in the toolchain uses that
mode against these files. `tools/run_tests.gd` already sidesteps it (it `load()`s its test
scripts at run time), which is why the suite has never hit this -- the sidestep is
undocumented and was rediscovered from the crash rather than read.

WHAT IT CHECKS.

For every `.gd` that `extends SceneTree` (a `--script` entry point by construction), every
identifier resolving to a project `class_name` whose transitive closure names an autoload
singleton is a finding. A direct reference to a singleton is a finding too. `class_name`s
that reach no singleton are fine and are counted separately, because they are the reason
this cannot be "never name a class here".

Usage:
    python tools/script_entry_check.py [--quiet] [--verbose]

Exit 0 clean, 1 findings, 2 could not run.

# fixture (8 files, written and deleted; baseline 6 entry points / 0 findings):
#            an entry naming an autoload directly, one naming a class two hops from one,
#            one naming an untainted class (Glyphs), one naming Game in a COMMENT, one
#            naming it in a STRING (the `load("res://game/game.gd")` this tool recommends),
#            one waived with a reason, one waived without, one not an entry at all.
#            -> 13 entries, 1 waived, exactly 3 findings: direct, indirect, bare waiver.
# mutations (run against that fixture; NOT-APPLIED is not SURVIVED -- the third needle
#            missed on its first attempt through a shell heredoc's escaping and had to be
#            re-run before it meant anything):
#            `strip_comments(...)` -> `text`   -> RED: 3 -> 14 findings, tainted 36 -> 50.
#                                                 Every doc-comment mention of RunConfig
#                                                 counts, which is 14 classes' worth.
#            `changed = True` -> `False`       -> RED: 3 -> 2 findings, tainted 36 -> 10.
#                                                 The indirect case vanishes and the direct
#                                                 one still fires, which is the whole point
#                                                 of closing to a fixed point.
#            `extends\s+SceneTree` -> `\w+`    -> RED: 6 -> 76 entry points, 305 findings.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

import gdsource
import repo_walk

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# A `--script` entry point is exactly a script Godot can install as the main loop, and in
# practice in this repo that is `extends SceneTree`. Matched on the blanked source so a
# docstring quoting the phrase (this one does not, but `playtest.gd`'s header nearly did)
# cannot enrol a file.
ENTRY_RE = re.compile(r"^\s*extends\s+SceneTree\b", re.M)
CLASS_RE = re.compile(r"^\s*class_name\s+(\w+)", re.M)
IDENT_RE = re.compile(r"\b[A-Z]\w*\b")

# REQUIRED to say why, the same rule settle_read_check.py enforces: a waiver that says
# only "ok" silences the check and records nothing about the judgement behind it.
WAIVER_RE = re.compile(r"#+[ \t]*script-entry-check:\s*ok\b\s*[-:]\s*\S")
ANY_WAIVER_RE = re.compile(r"#+[ \t]*script-entry-check:\s*ok\b")

CONTRACT = "NOT COVERED:"


def _autoload_names(root):
    """The singleton names from `project.godot`'s [autoload] block.

    Read rather than listed: an autoload added tomorrow taints its dependents that day.
    Godot's own leading `*` (the "run as singleton" marker) is on the VALUE, not the key,
    so the key needs no cleaning -- but the block ends at the next `[section]`, and a file
    with no `[autoload]` at all is a project with no singletons, which is a real answer
    and not an error.
    """
    path = os.path.join(root, "project.godot")
    if not os.path.exists(path):
        return None
    names = []
    inside = False
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            stripped = line.strip()
            if stripped.startswith("["):
                inside = stripped == "[autoload]"
                continue
            if not inside or "=" not in stripped:
                continue
            names.append(stripped.split("=", 1)[0].strip())
    return names


def _gd_files(root):
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        repo_walk.prune(dirpath, dirnames, root)
        for name in filenames:
            if name.endswith(".gd"):
                out.append(os.path.join(dirpath, name))
    return sorted(out)


def _read(path):
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        return handle.read()


def _code(text):
    """Comments blanked and string BODIES blanked, offsets preserved.

    Both, because both have already produced a false positive in this repo's history: a
    class named in the prose explaining why it must not be named, and a class named inside
    a `load("res://game/game.gd")` path -- which is the very fix this tool recommends and
    would otherwise be reported as the defect.
    """
    return gdsource.strip_comments(text, strings=gdsource.BLANK)


def _tainted(classes, singletons, verbose=False):
    """class_name -> the singleton chain that taints it, for every class that reaches one.

    Closed to a fixed point rather than stopping at depth 1. `RunSim` names `Game`, `Game`
    names `RunConfig`; a depth-1 check sees `RunSim` as clean and the entry point that
    names it as safe, which is exactly the case that shipped broken.
    """
    direct = {}
    for name, (path, code) in classes.items():
        for ident in set(IDENT_RE.findall(code)):
            if ident in singletons:
                direct[name] = [ident]
                break
    chains = dict(direct)
    changed = True
    while changed:
        changed = False
        for name, (path, code) in classes.items():
            if name in chains:
                continue
            for ident in set(IDENT_RE.findall(code)):
                if ident != name and ident in chains:
                    chains[name] = [ident] + chains[ident]
                    changed = True
                    break
    if verbose:
        for name in sorted(chains):
            print("  taint  %-22s %s" % (name, " -> ".join(chains[name])))
    return chains


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--quiet", action="store_true", help="findings only")
    parser.add_argument("--verbose", action="store_true",
                        help="print every taint chain and every entry point scanned")
    args = parser.parse_args(argv)

    singletons = _autoload_names(ROOT)
    if singletons is None:
        print("script_entry_check: no project.godot at %s -- nothing was checked" % ROOT,
              file=sys.stderr)
        return 2
    singletons = set(singletons)

    files = _gd_files(ROOT)
    if not files:
        print("script_entry_check: no .gd files found under %s -- nothing was checked"
              % ROOT, file=sys.stderr)
        return 2

    classes = {}
    entries = []
    for path in files:
        text = _read(path)
        code = _code(text)
        match = CLASS_RE.search(code)
        if match:
            classes[match.group(1)] = (path, code)
        if ENTRY_RE.search(code):
            entries.append((path, text, code))

    chains = _tainted(classes, singletons, verbose=args.verbose)

    findings = []
    waived = 0
    for path, text, code in entries:
        rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
        if WAIVER_RE.search(text):
            waived += 1
            continue
        if ANY_WAIVER_RE.search(text):
            findings.append((rel, 0, "carries a `script-entry-check: ok` waiver that does "
                             "not say why",
                             "write `# script-entry-check: ok - <reason>`"))
            continue
        seen = {}
        for match in IDENT_RE.finditer(code):
            ident = match.group(0)
            if ident in seen:
                continue
            line = code.count("\n", 0, match.start()) + 1
            if ident in singletons:
                seen[ident] = True
                findings.append((rel, line,
                    "names the autoload singleton `%s` at compile time" % ident,
                    "reach it as `get_node(\"/root/%s\")` from inside a function, after "
                    "the first frame" % ident))
            elif ident in chains:
                seen[ident] = True
                findings.append((rel, line,
                    "names `%s` at compile time, and %s reaches the autoload `%s` (%s)"
                    % (ident, ident, chains[ident][-1],
                       " -> ".join([ident] + chains[ident])),
                    "load it at run time instead: `var s := load(\"res://…\") as GDScript` "
                    "inside the function, after `await process_frame`. Worked example: "
                    "tools/playtest.gd's RUN_SIM/GAME pair"))

    if args.verbose:
        for path, _unused_text, _unused_code in entries:
            print("  entry  %s" % os.path.relpath(path, ROOT).replace(os.sep, "/"))

    for rel, line, what, fix in findings:
        print("FINDING: %s:%d %s" % (rel, line, what))
        print("  fix: %s" % fix)
        print("  waive: add `# script-entry-check: ok - <reason>` in the file.")

    reachable = len(chains)
    print("script_entry_check: %d --script entry point(s), %d project class_name(s), "
          "%d of them reach an autoload, %d singleton(s), %d waived, %d finding(s)"
          % (len(entries), len(classes), reachable, len(singletons), waived, len(findings)))
    if not entries:
        print("  NOTE: nothing to check -- no .gd in this repo `extends SceneTree`, so no "
              "file can be a `--script` entry point. That is a clean result only if you "
              "expected none.")
    if not singletons:
        print("  NOTE: project.godot declares no [autoload] singletons, so no class can be "
              "tainted and this check can never fire. Clean here means the project has no "
              "autoloads, not that the entry points were verified.")
    if not args.quiet:
        print("  NOTE: %d of %d class_name(s) reach no singleton and are safe to name from "
              "an entry point -- this is not `never name a class here`. --verbose prints "
              "every taint chain." % (len(classes) - reachable, len(classes)))
    print("  " + CONTRACT + " this reads source and never launches Godot, so it cannot "
          "confirm that a flagged entry point actually fails to compile, nor that a clean "
          "one runs. It reasons about ONE launch mode (`--script`); a script reached any "
          "other way is unaffected and is not scanned. Taint is computed over "
          "capitalised identifiers, so a singleton reached only through a string "
          "(`get_node(\"/root/RunConfig\")`) is correctly NOT counted as taint -- which is "
          "the whole point, but it means a class using that form to touch a singleton at "
          "compile time would be missed. And it says nothing about whether the entry "
          "point's own exit code is honest, which is the OTHER half of the failure it was "
          "written for: playtest.gd compiled to nothing and still exited 0.")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
